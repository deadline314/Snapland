extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 根系蓄水: a long potting bench across the greenhouse with a
## conveyor of wooden slats over rollers and a gear at each end. Tapered
## terracotta pots with rolled rims and moss stains ride the slats, each with a
## seedling in its soil and a clear glazed gauge strip down the front showing
## the soil, the roots and the water rising, with a chalk line and a little
## leaf tab on either side. The island traveller (arcade_hero) stands
## behind the bench holding a green watering can over the pot at the station;
## pouring tips the can and a stream of drops falls in, the water darkening the
## soil from below. Spot-on pots sprout a fresh shoot. Leaky pots are patched
## and drip; growing pots wear a striped band and pop bigger. A spill runs
## over the rim into a puddle and the traveller tumbles into the pot, feet up.
## Baked pixel art over the shared greenhouse backdrop.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Greenhouse = preload("res://game/minigames/arcade/greenhouse_backdrop.gd")
const BENCH_TOP := 520.0
const HERO_X := 530.0
const HERO_SCALE := 3.5
## Pots, the can and the sprout are drawn half again as big as other sprites so
## the water level reads at a glance.
const POT_SCALE := 7.0
const GROW := POT_SCALE / TEXEL
## Pot sizes in texels: small, medium, big.
const POT_SIZES: Array[Vector2i] = [Vector2i(18, 13), Vector2i(23, 17), Vector2i(28, 21)]
const CLAY := Color("#c0673f")
const SOIL := Color("#4a3426")
const ROOT := Color("#d9c08a")
const WATER := Color("#4fa3d9")
const CHALK := Color("#f6f1e2")
const LEAF := Color("#6fb04f")
const CAN := Color("#4f8f6a")
const WOOD := Color("#8a6640")
const MORNING := Color(1.0, 0.98, 0.94)

var _shell: Array[ImageTexture] = []
var _band: Array[ImageTexture] = []
var _patched: Array[ImageTexture] = []
var _soil: Array[ImageTexture] = []
var _can: ImageTexture
var _sprout: ImageTexture
var _roller: ImageTexture
var _slat: ImageTexture
var _gear: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)


func _ready() -> void:
	for size in POT_SIZES.size():
		var texels := POT_SIZES[size]
		_shell.append(Pixels.bake("pot-shell|%d" % size, texels, _paint_shell.bind(texels, "plain")))
		_band.append(Pixels.bake("pot-band|%d" % size, texels, _paint_shell.bind(texels, "grow")))
		_patched.append(Pixels.bake("pot-patched|%d" % size, texels, _paint_shell.bind(texels, "leaky")))
		_soil.append(Pixels.bake("pot-soil|%d" % size, texels, _paint_soil.bind(texels)))
	_can = Pixels.bake("water-can", Vector2i(22, 13), _paint_can)
	_sprout = Pixels.bake("pot-sprout", Vector2i(9, 9), _paint_sprout)
	_roller = Pixels.bake("bench-roller", Vector2i(5, 5), _paint_roller)
	_slat = Pixels.bake("belt-slat", Vector2i(11, 3), _paint_slat)
	_gear = Pixels.bake("belt-gear", Vector2i(11, 11), _paint_gear)


func _draw_backdrop() -> void:
	Greenhouse.draw(self, now, reduced_motion)
	vignette(0.25)


func _draw_scene() -> void:
	if not state.has("pots"):
		return
	var slip: Dictionary = state.get("slip", {})
	var slipping := not slip.is_empty() and age(float(slip.at)) < float(state.slip_seconds)
	if not slipping:
		_draw_hero()
	_draw_bench()
	var station := _station_pot()
	for pot: Dictionary in state.pots:
		_draw_pot(pot, slipping and pot == station)
	if not slipping:
		_draw_can(station)
	else:
		_draw_puddle(age(float(slip.at)))


# --- Placement ----------------------------------------------------------------

func _station_pot() -> Dictionary:
	for pot: Dictionary in state.pots:
		if pot.phase == "under":
			return pot
	return {}


## Pot size in design pixels.
func _pot_px(pot: Dictionary) -> Vector2:
	return Vector2(POT_SIZES[int(pot.size)]) * POT_SCALE


## Bottom centre of a pot on the bench.
func _pot_foot(pot: Dictionary) -> Vector2:
	return Vector2(float(pot.x) * DESIGN.x, BENCH_TOP - 10.0)


## The glazed gauge strip down the front of a pot, in texels.
static func gauge(texels: Vector2i) -> Rect2i:
	var width := maxi(6, int(texels.x * 0.44))
	return Rect2i((texels.x - width) / 2, 5, width, texels.y - 8)


# --- The bench ------------------------------------------------------------------

func _draw_bench() -> void:
	bench(BENCH_TOP, WOOD)
	# The conveyor: wooden slats riding over a row of rollers, with a gear at
	# each end. Slats and gears move only while a pot is sliding.
	var moving := false
	for pot: Dictionary in state.pots:
		moving = moving or pot.phase != "under"
	var run := not reduced_motion and moving
	draw_rect(Rect2(28, BENCH_TOP - 2.0, DESIGN.x - 56.0, 10), Color("#3a2a1e"))
	var x := 34.0 - (fposmod(now * 24.0, 24.0) if run else 0.0)
	while x < DESIGN.x - 34.0:
		if x > 28.0:
			stamp(_roller, Vector2(x, BENCH_TOP + 2.0), TEXEL, MORNING)
		x += 24.0
	var belt := Rect2(40, BENCH_TOP - 12.0, DESIGN.x - 80.0, 12)
	draw_rect(belt.grow(2.0), INK)
	var slat := belt.position.x - (fposmod(now * 60.0, 48.0) if run else 0.0)
	while slat < belt.end.x:
		if slat >= belt.position.x - 2.0 and slat + 44.0 <= belt.end.x + 2.0:
			stamp(_slat, Vector2(slat, belt.position.y), TEXEL, MORNING)
		slat += 48.0
	for end: float in [belt.position.x, belt.end.x]:
		var turn := -now * 2.4 if run else 0.0
		draw_set_transform(Vector2(end, BENCH_TOP - 4.0), turn, Vector2.ONE)
		stamp(_gear, Vector2(-24, -24), TEXEL, MORNING)
		draw_set_transform(Vector2.ZERO)


# --- The pots -----------------------------------------------------------------

func _draw_pot(pot: Dictionary, with_hero: bool) -> void:
	var size := int(pot.size)
	var px := _pot_px(pot)
	var foot := _pot_foot(pot)
	# A growing pot pops up a size with a squash.
	var grown := age(float(pot.grown_at))
	var squish := squash(grown, 0.3, 0.4) if grown >= 0.0 and grown < 0.5 else Vector2.ONE
	var origin := foot - Vector2(px.x * 0.5 * squish.x, px.y * squish.y)
	ground_shadow(foot + Vector2(8, 2), Vector2(px.x * 0.55, 8), 0.35)
	# Inside the pot everything is drawn in texel units, scaled up by GROW.
	draw_set_transform(origin, 0.0, squish * GROW)
	stamp(_soil[size], Vector2.ZERO, TEXEL, MORNING)
	var strip := gauge(POT_SIZES[size])
	var window := Rect2(Vector2(strip.position) * TEXEL, Vector2(strip.size) * TEXEL)
	# Water darkens the soil from the bottom up, with a bright surface line.
	var level := clampf(float(pot.level), 0.0, 1.0)
	if level > 0.0:
		var depth := roundf(window.size.y * level / TEXEL) * TEXEL
		var wet := Rect2(window.position.x, window.end.y - depth, window.size.x, depth)
		draw_rect(wet, Color(WATER, 0.62))
		var shimmer := 0.0 if reduced_motion else 0.15 * sin(now * 9.0 + float(pot.x) * 20.0)
		draw_rect(Rect2(wet.position, Vector2(wet.size.x, TEXEL)), Color(WATER.lightened(0.45), 0.75 + shimmer))
	if pot.result == "perfect":
		# The roots drink and glow a little.
		draw_rect(window, Color(LEAF.lightened(0.3), 0.14 * clampf(1.0 - age(float(pot.result_at)), 0.0, 1.0)))
	if with_hero:
		_draw_hero_in_pot(Rect2(origin + window.position * squish * GROW, window.size * squish * GROW), origin, squish * GROW)
	var shells := _band if pot.kind == "grow" else (_patched if pot.kind == "leaky" else _shell)
	stamp(shells[size], Vector2.ZERO, TEXEL, MORNING)
	_draw_line(window, float(pot.line))
	draw_set_transform(Vector2.ZERO)
	if pot.kind == "leaky" and level > 0.0 and pot.phase != "out":
		_draw_drips(foot, px)
	if not with_hero:
		_draw_seedling(pot, foot, px)
	if bool(pot.spilled):
		# Water sheets over the rim on both sides.
		for side: float in [-1.0, 1.0]:
			var lip := foot + Vector2(side * px.x * 0.5, -px.y)
			draw_rect(Rect2(lip + Vector2(-6 if side < 0.0 else 0.0, 0), Vector2(12, px.y)), Color(WATER, 0.55))


## Every pot holds a little seedling: pale and droopy while it waits, a
## bright fresh shoot once watered spot on, browning if left dry or drowned.
func _draw_seedling(pot: Dictionary, foot: Vector2, px: Vector2) -> void:
	var tint := Color(0.86, 0.9, 0.62)
	var grow := 0.55
	match str(pot.result):
		"perfect":
			tint = MORNING
			grow = lerpf(0.55, 1.0, pop_in(age(float(pot.result_at)), 0.35))
		"dry", "soggy", "spilled":
			tint = Color(0.78, 0.62, 0.4)
	var scale_factor := POT_SCALE * grow
	stamp(_sprout, foot - Vector2(4.5 * scale_factor, px.y + 8.0 * scale_factor - POT_SCALE), scale_factor, tint)


func _draw_line(window: Rect2, line: float) -> void:
	# A dashed chalk line across the glass and a leaf tab sticking out each side.
	var y := window.end.y - roundf(window.size.y * line / TEXEL) * TEXEL
	var x := window.position.x
	while x < window.end.x:
		draw_rect(Rect2(x, y - TEXEL * 0.5, TEXEL * 2.0, TEXEL), CHALK)
		x += TEXEL * 3.0
	for side: float in [-1.0, 1.0]:
		var tab := Vector2(window.position.x - 4.0 * TEXEL if side < 0.0 else window.end.x + 2.0 * TEXEL, y - TEXEL)
		draw_rect(Rect2(tab, Vector2(2.0 * TEXEL, 2.0 * TEXEL)), INK)
		draw_rect(Rect2(tab + Vector2(1, 1), Vector2(2.0 * TEXEL - 2.0, 2.0 * TEXEL - 2.0)), LEAF)


func _draw_drips(foot: Vector2, px: Vector2) -> void:
	for hole in 2:
		var spot := foot + Vector2((-0.3 + 0.6 * hole) * px.x, -px.y * 0.25)
		var fall := 0.0 if reduced_motion else fposmod(now * 1.6 + hole * 0.5, 1.0)
		draw_rect(Rect2(spot + Vector2(-3, fall * 40.0), Vector2(POT_SCALE, POT_SCALE * 1.5)), Color(WATER.lightened(0.2), 1.0 - fall * 0.6))


# --- The traveller and the can -------------------------------------------------

func _draw_hero() -> void:
	# The traveller stands on an upturned crate behind the bench.
	var feet := Vector2(HERO_X, BENCH_TOP - 40.0)
	panel(Rect2(HERO_X - 66.0, feet.y - 6.0, 132, 52), "planks", WOOD.darkened(0.18))
	ground_shadow(feet + Vector2(6, -4), Vector2(50, 8), 0.3)
	var pouring := bool(state.get("pouring", false))
	stamp(Hero.texture(&"right", true, "plain"), feet - Vector2(21, 47) * HERO_SCALE + Vector2(0, -2.0 if pouring else 0.0), HERO_SCALE, MORNING)


func _draw_can(station: Dictionary) -> void:
	var pouring := bool(state.get("pouring", false))
	var tilt := 0.55 if pouring else 0.0
	var grip := Vector2(HERO_X + 84.0, BENCH_TOP - 196.0)
	draw_set_transform(grip, tilt, Vector2.ONE * GROW)
	stamp(_can, Vector2(-30, -26), TEXEL, MORNING)
	draw_set_transform(Vector2.ZERO)
	if not pouring:
		return
	# The rose of the spout, then a stream of drops down to the soil.
	var spout := grip + (Vector2(58, -22) * GROW).rotated(tilt)
	var bottom := BENCH_TOP - 20.0
	if not station.is_empty():
		# The drops land on the soil just inside the rim.
		bottom = _pot_foot(station).y - _pot_px(station).y + POT_SCALE * 2.0
	var y := spout.y
	var step := 0
	while y < bottom:
		var jiggle := 0.0 if reduced_motion else 2.0 * sin(now * 30.0 + step)
		var drop := Rect2(spout + Vector2(-8.0 + jiggle + (step % 3) * 6.0, y - spout.y), Vector2(POT_SCALE, POT_SCALE * 1.5))
		draw_rect(drop, Color(WATER.lightened(0.35), 0.9))
		y += 10.0
		step += 1


## `window` is the pot's glass in screen space; `restore` puts the pot's own
## transform back afterwards.
func _draw_hero_in_pot(window: Rect2, origin: Vector2, squish: Vector2) -> void:
	# Seen through the glass: the traveller sits upside down in the soil with
	# their boots sticking out of the top, soaked.
	var since := age(float(state.slip.at))
	var drop := pop_in(since, 0.3)
	var centre := window.get_center() + Vector2(0, -window.size.y * (1.0 - drop) * 1.4 - 10.0)
	var wobble := 0.0 if reduced_motion else 0.12 * sin(since * 14.0) * (1.0 - clampf(since, 0.0, 1.0))
	var texture := Hero.texture(&"idle", true, "soaked")
	draw_set_transform(centre, PI + wobble, Vector2.ONE * 3.5)
	draw_texture(texture, -Vector2(texture.get_size()) * 0.5)
	draw_set_transform(origin, 0.0, squish)


func _draw_puddle(since: float) -> void:
	var spread := pop_in(since, 0.4)
	var at := Vector2(float(state.station) * DESIGN.x, BENCH_TOP + 14.0)
	# A sheet of water across the bench top, running down its front.
	draw_rect(Rect2(at - Vector2(150, 6) * Vector2(spread, 1.0), Vector2(300 * spread, 10)), Color(WATER, 0.55))
	draw_rect(Rect2(at - Vector2(100, 6) * Vector2(spread, 1.0), Vector2(90 * spread, 4)), Color(WATER.lightened(0.5), 0.7))
	for run in 4:
		var trickle := (12.0 + 18.0 * run) * spread
		draw_rect(Rect2(at + Vector2(-110 + 70 * run, 4), Vector2(POT_SCALE, trickle)), Color(WATER, 0.5))


# --- Texel painters ---------------------------------------------------------------

func _paint_shell(x: int, y: int, texels: Vector2i, kind: String) -> Color:
	# A tapered terracotta pot seen from the front: soil heaped just above a
	# rolled rim, the body narrowing to a foot, lit from the left, a moss stain
	# low down on the shady side and a clear glazed gauge strip down the middle.
	var w := texels.x
	var h := texels.y
	if y == 0:
		return Pixels.grainy(SOIL.lightened(0.12), x, y, 0.1) if x >= 3 and x <= w - 4 else Pixels.CLEAR
	if y <= 3:
		# The rolled rim: rounded ends, a lit top and a shaded underside.
		if (x == 0 or x == w - 1) and y != 2:
			return Pixels.CLEAR
		var light := 0.5 if y == 1 else (0.1 if y == 2 else -0.45)
		return Pixels.lit(CLAY.lightened(0.18), light - float(x) / w * 0.4, x, y)
	var inset := 1 + int(floor(float(y - 4) / maxf(1.0, h - 5) * w * 0.14))
	if y == h - 1:
		inset += 1
	if x < inset or x > w - 1 - inset:
		return Pixels.CLEAR
	var strip := gauge(texels)
	if strip.has_point(Vector2i(x, y)):
		return Pixels.CLEAR
	if strip.grow(1).has_point(Vector2i(x, y)):
		# The glaze around the gauge: a creamy ring, brighter on its lit side.
		return Color("#f4ead0") if x < strip.position.x or y < strip.position.y else Color("#d9cba8")
	var across := float(x - inset) / maxf(1.0, w - 1 - 2 * inset)
	var tone := CLAY
	if y == h - 1:
		tone = CLAY.darkened(0.25)
	if kind == "grow" and (y == 5 or y == 6):
		tone = LEAF if (x / 2) % 2 == 0 else Color("#ffd166")
	if kind == "leaky":
		if x >= inset + 1 and x <= inset + 3 and y >= 7 and y <= 9:
			return Color("#d9c08a") if (x + y) % 3 != 0 else Color("#a89048")
		if (x == w - 2 - inset and y == h - 5) or (x == inset + 2 and y == h - 3):
			return Color("#2a1810")
	# A greenish moss stain creeping up from the foot on the shady side.
	var low := float(y) / h
	if low > 0.55 and across > 0.55 and Pixels.noise(x, y, 53) > 1.25 - low:
		tone = tone.lerp(Color("#6f8a4a"), 0.65)
	return Pixels.grainy(Pixels.lit(tone, 0.45 - across * 0.9, x, y), x, y, 0.06)


func _paint_soil(x: int, y: int, texels: Vector2i) -> Color:
	# Seen through the gauge: crumbly soil with pale roots winding down.
	var strip := gauge(texels)
	if not strip.has_point(Vector2i(x, y)):
		return Pixels.CLEAR
	var middle := strip.position.x + strip.size.x * 0.5
	var root := absf(sin(float(y) * 0.6) * 1.2 + middle - 0.5 - x) < 0.7
	var side_root := absf(sin(float(y) * 0.8 + 2.0) * 1.0 + middle - 1.6 - x) < 0.6 and y > strip.position.y + 3
	if root or side_root:
		return ROOT.darkened(0.15 * float(y) / texels.y)
	var tone := SOIL.lightened(0.08 * (1.0 - float(y) / texels.y))
	if Pixels.noise(x, y, 41) > 0.9:
		tone = tone.lightened(0.18)
	return Pixels.grainy(tone, x, y, 0.08)


func _paint_can(x: int, y: int) -> Color:
	# A green watering can: round body, a handle loop on top, a long spout
	# to the right ending in a sprinkler rose.
	var body := Vector2((x + 0.5 - 7.0) / 6.5, (y + 0.5 - 8.0) / 4.8)
	if body.length() <= 1.0:
		return Pixels.rounded(CAN, body)
	if y <= 3 and x >= 3 and x <= 11 and (y == 0 or x == 3 or x == 11):
		return CAN.darkened(0.25)
	var spout_y := 9.0 - (x - 12) * 0.55
	if x >= 12 and x <= 19 and absf(y - spout_y) < 1.0:
		return CAN.darkened(0.12)
	if x >= 19 and y >= 2 and y <= 6:
		return Color("#c9b26a") if (x + y) % 2 == 0 else Color("#a89048")
	return Pixels.CLEAR


func _paint_sprout(x: int, y: int) -> Color:
	# Two round leaves on a short stem.
	if x == 4 and y >= 4:
		return LEAF.darkened(0.2)
	for side: float in [-1.0, 1.0]:
		var leaf := Vector2((x + 0.5 - 4.5 - side * 2.3) / 2.3, (y + 0.5 - 3.5) / 1.8)
		if leaf.length() <= 1.0:
			return Pixels.rounded(LEAF, leaf)
	return Pixels.CLEAR


func _paint_slat(x: int, y: int) -> Color:
	# One wooden slat of the conveyor, rounded at the ends.
	if (x == 0 or x == 10) and y != 1:
		return Pixels.CLEAR
	return Pixels.wood(WOOD.lightened(0.1 - y * 0.12), x, y, 3, false)


func _paint_gear(x: int, y: int) -> Color:
	# A small iron gear: a toothed ring around a dark hub.
	var at := Vector2(x + 0.5 - 5.5, y + 0.5 - 5.5)
	var reach := at.length()
	var teeth := sin(at.angle() * 8.0) > 0.0
	if reach > (5.4 if teeth else 4.2):
		return Pixels.CLEAR
	if reach < 1.3:
		return INK
	return Pixels.rounded(Color("#8a8f99"), at / 5.5) if reach > 2.2 else Color("#6a6f79")


func _paint_roller(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5 - 2.5) / 2.5, (y + 0.5 - 2.5) / 2.5)
	if at.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.rounded(Color("#8a8f99"), at) if x != 2 else Color("#5a5f69")
