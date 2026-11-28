extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 蜂巢調音: a raised flower bed in the greenhouse seen from a
## little above. A wooden beehive with a striped roof stands against the
## back wall; flower clumps dot the soil; honeybees zip about with flapping
## wings and the grumpy contrary bee wears a red stripe and a frown. The
## island traveller (arcade_hero) shoos with an outstretched arm. A sting
## blows their face up into a round pink balloon. Baked pixel art over the
## shared greenhouse backdrop.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Greenhouse = preload("res://game/minigames/arcade/greenhouse_backdrop.gd")
const BED := Rect2(130, 300, 1020, 330)
const HERO_SCALE := 2.0
const SOIL := Color("#5a4330")
const RIM := Color("#8a6640")
const HONEY := Color("#e0a83a")
const STRIPE := Color("#2a2020")
const RED := Color("#c8483e")
const WING := Color("#e8f4ff")
const SKIN := Color("#f3c9a8")
const BLOOMS: Array[Color] = [Color("#f2a7b8"), Color("#ffd166"), Color("#bfa2e8"), Color("#fff2dc")]
const MORNING := Color(1.0, 0.98, 0.94)

var _bed: ImageTexture
var _hive: ImageTexture
var _bee: Array[ImageTexture] = []
var _grump: Array[ImageTexture] = []
var _clump: Array[ImageTexture] = []
var _balloon: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 196)


func _ready() -> void:
	var size := Vector2i(int(BED.size.x / TEXEL), int(BED.size.y / TEXEL))
	_bed = Pixels.bake("bee-bed|%d" % size.x, size, _paint_bed.bind(size))
	_hive = Pixels.bake("bee-hive", Vector2i(24, 26), _paint_hive)
	for frame in 2:
		_bee.append(Pixels.bake("bee|%d" % frame, Vector2i(9, 7), _paint_bee.bind(frame, false)))
		_grump.append(Pixels.bake("bee-grump|%d" % frame, Vector2i(9, 7), _paint_bee.bind(frame, true)))
	for kind in BLOOMS.size():
		_clump.append(Pixels.bake("bee-clump|%d" % kind, Vector2i(16, 11), _paint_clump.bind(BLOOMS[kind])))
	_balloon = Pixels.bake("bee-balloon", Vector2i(24, 24), _paint_balloon)


func _draw_backdrop() -> void:
	Greenhouse.draw(self, now, reduced_motion)
	bench(BED.end.y + 10.0, RIM.darkened(0.1))
	# The raised bed: its shadow, then the soil in its timber frame.
	draw_rect(Rect2(BED.position + Vector2(10, 14), BED.size), Color(Props.SHADOW, 0.3))
	stamp(_bed, BED.position, TEXEL, MORNING)
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("bees"):
		return
	_draw_hive()
	for index in state.flowers.size():
		var at := _screen(state.flowers[index])
		stamp(_clump[index % _clump.size()], at - Vector2(32, 30), TEXEL, MORNING)
	# Everything on the bed is drawn back to front.
	var actors: Array = []
	for bee: Dictionary in state.bees:
		actors.append({"y": float(bee.pos.y), "bee": bee})
	actors.append({"y": float(state.hero.y), "hero": true})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	for actor: Dictionary in actors:
		if actor.has("hero"):
			_draw_hero()
		else:
			_draw_bee(actor.bee)
	_draw_homed()


# --- Placement ----------------------------------------------------------------

func _screen(at: Vector2) -> Vector2:
	return BED.position + Vector2(at.x * BED.size.x, at.y * BED.size.y)


# --- The hive and the bees ---------------------------------------------------------

func _draw_hive() -> void:
	var door := _screen(state.hive)
	var size := Vector2(24, 26) * TEXEL
	ground_shadow(door + Vector2(10, 10), Vector2(56, 10), 0.4)
	stamp(_hive, door - Vector2(size.x * 0.5, size.y - 14.0), TEXEL, MORNING)
	# The door glows a little when bees are near, as if humming along.
	var hum := 0.0
	for bee: Dictionary in state.bees:
		hum = maxf(hum, 1.0 - Vector2(bee.pos).distance_to(state.hive) / 0.3)
	draw_rect(Rect2(door - Vector2(18, 6), Vector2(36, 10)), Color("#2a1a10"))
	if hum > 0.0:
		draw_rect(Rect2(door - Vector2(18, 6), Vector2(36, 10)), Color(HONEY, 0.5 * hum))


func _draw_bee(bee: Dictionary) -> void:
	var at := _screen(bee.pos)
	var frame := 0 if reduced_motion else int(now * 14.0 + float(bee.wander) * 3.0) % 2
	var contrary := bool(bee.contrary)
	var sprite: ImageTexture = (_grump if contrary else _bee)[frame]
	var size := Vector2(sprite.get_size()) * TEXEL
	var hover := 0.0 if reduced_motion else roundf(3.0 * sin(now * 7.0 + float(bee.wander)))
	ground_shadow(at + Vector2(4, 12), Vector2(12, 3), 0.3)
	var facing := -1.0 if float(Vector2(bee.vel).x) < 0.0 else 1.0
	draw_set_transform(at + Vector2(0, -14.0 + hover), 0.0, Vector2(facing, 1.0))
	stamp(sprite, -size * 0.5, TEXEL, MORNING)
	draw_set_transform(Vector2.ZERO)


func _draw_homed() -> void:
	for bee: Dictionary in state.homed:
		var since := age(float(bee.at))
		if since < 0.0 or since > 1.0:
			continue
		var door := _screen(state.hive)
		label(door + Vector2(0, -60.0 - 30.0 * since), "♪", 26, HONEY, 1.0, 1.0 - since)


# --- The traveller ----------------------------------------------------------------

func _draw_hero() -> void:
	var feet := _screen(state.hero) + Vector2(0, 18)
	var swell: Dictionary = state.get("swell", {})
	var since := age(float(swell.get("at", -99.0))) if not swell.is_empty() else 99.0
	var total := float(state.get("swell_seconds", 1.9))
	var swollen := since >= 0.0 and since < total + 0.6
	var moving: Vector2 = state.get("hero_v", Vector2.ZERO)
	var pose := &"idle"
	if not swollen and moving.length() > 0.08:
		pose = &"left" if moving.x < 0.0 else &"right"
	var mood := "sorry" if swollen else "plain"
	ground_shadow(feet + Vector2(6, 2), Vector2(40, 10), 0.4)
	var origin := feet - Vector2(20, 46) * HERO_SCALE
	stamp(Hero.texture(pose, moving.y > 0.05 or swollen or moving.length() < 0.08, mood), origin, HERO_SCALE, MORNING)
	if not swollen:
		return
	# The stung face puffs up into a round pink balloon with a shine and a pout.
	var grow := pop_in(since, 0.35)
	var bob := 0.0 if reduced_motion else 4.0 * sin(since * 6.0)
	var head := feet + Vector2(0, -34 * HERO_SCALE - 22.0 * grow + bob)
	var puff := TEXEL * lerpf(0.4, 1.0, grow)
	var radius := 12.0 * puff
	stamp(_balloon, head - Vector2(13, 13) * puff, puff, MORNING)
	# The culprits circling.
	for orbit in 3:
		var angle := orbit * TAU / 3.0 + (0.0 if reduced_motion else since * 5.0)
		stamp(_bee[0], head + Vector2(cos(angle) * (radius + 26.0), sin(angle) * 18.0 - radius) - Vector2(18, 14), TEXEL, MORNING)


# --- Texel painters ---------------------------------------------------------------

func _paint_bed(x: int, y: int, size: Vector2i) -> Color:
	# Raked soil in a timber frame: soft furrows running across, a few pebbles
	# and moss tufts, lighter toward the back where the sun falls.
	if x < 3 or y < 3 or x >= size.x - 3 or y >= size.y - 3:
		var edge := x < 3 or x >= size.x - 3
		return Pixels.wood(RIM, x, y, 9, edge)
	var tone := SOIL.lightened(0.1 * (1.0 - float(y) / size.y))
	# Furrows wobble a texel up or down every few columns, like a hand rake.
	var furrow := posmod(y - 3 + int(Pixels.noise(x / 5, y / 9, 31) * 2.0), 9)
	if furrow == 0:
		tone = tone.lightened(0.06)
	elif furrow >= 7:
		tone = tone.darkened(0.16)
	if Pixels.noise(x / 2, y / 2, 23) > 0.97:
		tone = tone.lightened(0.22)
	elif Pixels.noise(x / 2, y / 3, 29) > 0.975:
		tone = tone.lerp(Color("#6f9a52"), 0.55)
	return Pixels.grainy(tone, x, y, 0.05)


func _paint_hive(x: int, y: int) -> Color:
	# A skep-style wooden hive: striped roof, three boxes, a landing board.
	var at := Vector2(x + 0.5 - 12.0, y + 0.5)
	if y < 6:
		var half := 4.0 + y * 1.6
		if absf(at.x) > half:
			return Pixels.CLEAR
		return Pixels.lit(RED if (x / 3) % 2 == 0 else Color("#f4e6c4"), 0.4 - y * 0.08, x, y)
	if y < 22:
		if absf(at.x) > 10.0:
			return Pixels.CLEAR
		if (y - 6) % 5 == 4:
			return HONEY.darkened(0.45)
		return Pixels.wood(HONEY.darkened(0.12), x, y, 4, true)
	if absf(at.x) > 12.0 - (y - 22):
		return Pixels.CLEAR
	return Pixels.wood(Color("#8a6640"), x, y, 6, false)


func _paint_bee(x: int, y: int, frame: int, grumpy: bool) -> Color:
	# A round striped body with a dark head on the right and two wings.
	var body := Vector2((x + 0.5 - 4.0) / 3.6, (y + 0.5 - 4.5) / 2.4)
	var wing_y := 1.0 if frame == 0 else 2.0
	if y <= 2 and (x == 3 or x == 4 or x == 2) and absf(y - wing_y) < 1.2 and body.length() > 0.6:
		return WING
	if (Vector2(x + 0.5, y + 0.5) - Vector2(7.5, 4.5)).length() < 1.6:
		if grumpy and y == 3:
			return RED
		return STRIPE.lightened(0.15) if y == 4 and x == 8 else STRIPE
	if body.length() > 1.0:
		return Pixels.CLEAR
	if x % 3 == 0:
		return RED if grumpy else STRIPE
	return Pixels.rounded(HONEY, body)


func _paint_balloon(x: int, y: int) -> Color:
	# The swollen face: a round pink ball with a shine, squeezed-shut eyes, a
	# pout and the red sting bump.
	var at := Vector2((x + 0.5 - 12.0) / 12.0, (y + 0.5 - 12.0) / 12.0)
	if at.length() > 1.0:
		return Pixels.CLEAR
	if (at - Vector2(-0.38, -0.42)).length() < 0.16:
		return Color("#fff2ea")
	if (y == 10) and (x == 7 or x == 8 or x == 15 or x == 16):
		return Hero.INK
	if y == 16 and x >= 10 and x <= 13:
		return Hero.INK
	if y == 17 and x >= 11 and x <= 12:
		return Color("#ff7fa0")
	if (at - Vector2(0.5, 0.12)).length() < 0.13:
		return RED
	if y == 13 and (x == 5 or x == 6 or x == 17 or x == 18):
		return Color("#ff8f9a")
	return Pixels.lit(SKIN.lerp(Color("#f08c8c"), 0.4), -(at.x + at.y) * 0.5, x, y)


func _paint_clump(x: int, y: int, bloom: Color) -> Color:
	# A low clump of leaves with a few flower heads on top.
	var at := Vector2((x + 0.5 - 8.0) / 8.0, (y + 0.5 - 7.0) / 4.0)
	if y < 5 and posmod(x * 3 + y, 7) < 2 and absf(at.x) < 0.8:
		return Pixels.rounded(bloom, Vector2(0.2, -0.4))
	if at.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.lit(Color("#5f9e4f"), -at.y * 0.5, x, y)
