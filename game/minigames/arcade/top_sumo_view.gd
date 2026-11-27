extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 陀螺相撲: a pressed-tin dish on the workshop bench, ringed by a
## straw rope that creeps inward as the round goes on; painted wooden tops that
## spin, wobble as they slow and lie down rolling when they leave the dish; a
## spin gauge for your top. Every object is baked pixel art (arcade_pixels.gd)
## in the backdrop's dusky palette.

const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const FLOOR_TOP := 236.0
## The flat dish seen at an angle: screen = CENTER + flat * SQUASH.
const CENTER := Vector2(640, 452)
const SQUASH := Vector2(1.45, 0.7)
const DISH_TEXELS := Vector2i(196, 98)
const TOP_SIZE := Vector2i(17, 20)
## Texel of a top sprite that sits on its point.
const TOP_TIP := Vector2(8.5, 20)
const SPIN_FRAMES := 4
const GAUGE := Rect2(64, 182, 220, 26)
const WOOD := Color("#7a5238")
const TIN := Color("#8c7f74")
const ROPE := Color("#c9a35c")
const BRASS := Color("#c9953e")
const PAPER := Color("#e9d8b0")
const DARK := Color("#2b2440")
const RED := Color("#ad4a3c")
## Body and stripe colours: your top first, then the rivals' three.
const LOOKS: Array = [
	[Color("#b8483a"), Color("#efd9a8")], [Color("#4f8a7e"), Color("#e2cf9c")],
	[Color("#7c5f93"), Color("#e6c88a")], [Color("#c4904a"), Color("#6b4a36")],
]
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _dish: ImageTexture
var _rope: ImageTexture
var _gauge_fill: ImageTexture
## Look index -> spin frames.
var _tops: Array = []
var _lying: Array[ImageTexture] = []


func _init() -> void:
	super()
	word_anchor = Vector2(640, 214)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(0, 0, 1157, 560), Color(0.58, 0.52, 0.58))
	_dish = Pixels.bake("sumo-dish", DISH_TEXELS, _paint_dish)
	_rope = Pixels.bake("sumo-rope", Vector2i(5, 4), func(x: int, y: int) -> Color:
		return Pixels.grainy(ROPE.darkened(0.25) if (x + y) % 3 == 0 else ROPE, x, y, 0.12))
	_gauge_fill = Pixels.surface("liquid", Vector2i(int(GAUGE.size.x / TEXEL) - 2, int(GAUGE.size.y / TEXEL) - 2), Color("#d9a63e"))
	for look in LOOKS.size():
		var frames: Array[ImageTexture] = []
		for frame in SPIN_FRAMES:
			frames.append(Pixels.bake("sumo-top|%d|%d" % [look, frame], TOP_SIZE, _paint_top.bind(LOOKS[look][0], LOOKS[look][1], frame)))
		_tops.append(frames)
		_lying.append(frames[0])


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(FLOOR_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	var tops: Array = state.get("tops", [])
	var rim := float(state.get("rim", 250.0))
	var start := float(state.get("rim_start", 250.0))
	# The dish, its shadow and the straw rope at the current edge.
	ground_shadow(CENTER + Vector2(14, 24), Vector2(start * SQUASH.x + 30.0, start * SQUASH.y + 18.0), 0.5)
	var dish_size := Vector2(DISH_TEXELS) * TEXEL
	stamp(_dish, CENTER - dish_size * 0.5, TEXEL, DUSK)
	_draw_shrink(rim, start)
	_draw_rope(rim, true)
	# Far tops first so nearer ones overlap them.
	var order := tops.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for top: Dictionary in order:
		_draw_top(top, rim)
	_draw_rope(rim, false)
	_draw_ram()
	_draw_gauge(tops)


func _screen(flat: Vector2) -> Vector2:
	return CENTER + flat * SQUASH


# --- Dish -------------------------------------------------------------------

## Tin outside the rope darkens as the ring closes in, so the safe floor reads at a glance.
func _draw_shrink(rim: float, start: float) -> void:
	if rim >= start - 2.0:
		return
	var points := PackedVector2Array()
	for step in 49:
		points.append(_screen(Vector2.from_angle(step * TAU / 48.0) * start * 0.97))
	for step in range(48, -1, -1):
		points.append(_screen(Vector2.from_angle(step * TAU / 48.0) * rim))
	draw_colored_polygon(points, Color(0.12, 0.06, 0.1, 0.32 * clampf((start - rim) / 30.0, 0.0, 1.0)))


## The straw rope ring in braided segments; the far half is drawn under the tops, the near half over them.
func _draw_rope(rim: float, far: bool) -> void:
	var count := 64
	for step in count:
		var angle := step * TAU / count
		var flat := Vector2.from_angle(angle) * rim
		if (flat.y < 0.0) != far:
			continue
		var at := _screen(flat)
		stamp(_rope, at - Vector2(10, 8), TEXEL, DUSK.darkened(0.15 if far else 0.0))
	if not far:
		for knot in 4:
			var at := _screen(Vector2.from_angle(PI * 0.25 + knot * PI * 0.5) * rim)
			if at.y > CENTER.y:
				draw_rect(Rect2(at - Vector2(7, 10), Vector2(14, 20)), RED.darkened(0.35))
				draw_rect(Rect2(at - Vector2(5, 8), Vector2(10, 16)), RED)


# --- Tops -------------------------------------------------------------------

func _look(top: Dictionary) -> int:
	return 0 if str(top.kind) == "hero" else 1 + int(top.get("tint", 0)) % 3


func _draw_top(top: Dictionary, rim: float) -> void:
	var look := _look(top)
	var kind := str(top.kind)
	var mode := str(top.state)
	var unit := TEXEL * (1.5 if kind == "big" else 1.1 if kind == "hero" else 1.0)
	var since := age(float(top.at))
	var foot := _screen(top.pos)
	if mode == "drop":
		var t := clampf(since / 0.5, 0.0, 1.0)
		ground_shadow(foot, Vector2(30, 10) * unit / TEXEL * (0.4 + 0.6 * t), 0.3)
		var fall := 0.0 if reduced_motion else -260.0 * (1.0 - t * t)
		_stamp_top(look, foot + Vector2(0, fall), unit, 0.0, Vector2.ONE, int(now * 20.0))
		return
	if mode == "out" or mode == "topple":
		_draw_fallen(top, look, unit, since, foot, rim)
		return
	var spin := float(top.spin)
	ground_shadow(foot + Vector2(4, 2), Vector2(32, 11) * unit / TEXEL, 0.38)
	# Spinning fast it stands straight; slowing down it wobbles wider and wider.
	var wobble := 0.0 if reduced_motion else sin(now * (9.0 + 6.0 * spin) + float(top.phase) * TAU) * (1.0 - spin) * 0.55
	var frame := 0 if reduced_motion else int(now * (6.0 + 30.0 * spin) + float(top.phase) * 4.0)
	var hit := age(float(top.get("hit", -99.0)))
	_stamp_top(look, foot, unit, wobble, squash(hit, 0.18, 0.25), frame)
	if kind == "hero":
		var bob := 4.0 * pulse(1.5)
		var mark := foot + Vector2(0, -TOP_SIZE.y * unit - 26.0 - bob)
		draw_colored_polygon(PackedVector2Array([mark + Vector2(-14, -12), mark + Vector2(14, -12), mark + Vector2(0, 6)]), DARK)
		draw_colored_polygon(PackedVector2Array([mark + Vector2(-9, -9), mark + Vector2(9, -9), mark + Vector2(0, 1)]), GOLD)
		label(mark + Vector2(0, -26), "你", 20, GOLD)
		if spin < 0.3:
			label(foot + Vector2(0, 26), "快沒力了！", 18, ROSE, 1.0 + 0.1 * pulse(3.0))


func _stamp_top(look: int, foot: Vector2, unit: float, turn: float, stretch: Vector2, frame: int) -> void:
	var sprite: ImageTexture = _tops[look][posmod(frame, SPIN_FRAMES)]
	draw_set_transform(foot, turn, stretch)
	stamp(sprite, -TOP_TIP * unit, unit, DUSK)
	draw_set_transform(Vector2.ZERO)


## Down on its side, rolling across the tin and off over the bench with a cloud of dust.
func _draw_fallen(top: Dictionary, look: int, unit: float, since: float, foot: Vector2, rim: float) -> void:
	var lean := clampf(since / 0.25, 0.0, 1.0) if not reduced_motion else 1.0
	var outward: Vector2 = top.pos.normalized() if top.pos.length() > 1.0 else Vector2.DOWN
	var side := 1.0 if outward.x >= 0.0 else -1.0
	var roll := 0.0 if reduced_motion else sin(since * 12.0) * 0.18 * maxf(0.0, 1.0 - since * 0.6)
	var fade := 1.0 - clampf((since - 1.3) / 0.5, 0.0, 1.0)
	ground_shadow(foot + Vector2(0, 2), Vector2(40, 10) * unit / TEXEL, 0.3 * fade)
	draw_set_transform(foot + Vector2(0, -8.0 * lean), side * lean * PI * 0.5 + roll, Vector2.ONE)
	stamp(_lying[look], -TOP_TIP * unit, unit, Color(DUSK, fade))
	draw_set_transform(Vector2.ZERO)
	dust_puffs(_screen(outward * rim), since, 70.0)
	dust_puffs(foot, since - 0.6, 50.0)
	if str(top.kind) == "hero" and since < 1.4:
		label(foot + Vector2(0, -70), "咕嚕咕嚕…", 20, PAPER, 1.0, fade)


func _draw_ram() -> void:
	var since := age(float(state.get("ram_at", -99.0)))
	if since < 0.0 or since > 0.3:
		return
	var at := _screen(state.get("ram_point", Vector2.ZERO)) - Vector2(0, 30)
	var reach := 18.0 + since * 160.0
	for spark in 8:
		var dir := Vector2.from_angle(spark * TAU / 8.0 + 0.2)
		var size := 8.0 * (1.0 - since / 0.3) + 2.0
		draw_rect(Rect2(at + dir * reach - Vector2(size, size) * 0.5, Vector2(size, size)), Color(1.0, 0.86, 0.5, 1.0 - since / 0.3))
	glint(at, 26.0, 99.0, -since)


## Your top's spin, in a brass-trimmed groove: a ram fills it back up.
func _draw_gauge(tops: Array) -> void:
	if tops.is_empty():
		return
	var hero: Dictionary = tops[0]
	var spin := float(hero.spin) if str(hero.state) == "spin" or str(hero.state) == "drop" else 0.0
	panel(GAUGE.grow(8.0), "lacquer", Color("#3a2433"), BRASS)
	panel(GAUGE, "groove", Color("#241726"))
	var size := Vector2(_gauge_fill.get_size())
	var shown := roundf(size.x * spin)
	if shown > 0.0:
		draw_texture_rect_region(_gauge_fill, Rect2(GAUGE.position, Vector2(shown * TEXEL, GAUGE.size.y)), Rect2(Vector2.ZERO, Vector2(shown, size.y)), Color(1, 1, 1) if spin >= 0.3 else Color(1.0, 0.6, 0.55))
	label(Vector2(GAUGE.position.x + 46.0, GAUGE.position.y - 22.0), "你的轉速", 18, PAPER)
	if age(float(state.get("ram_at", -99.0))) < 0.5:
		label(GAUGE.end + Vector2(26, -12), "+轉", 20, GOLD)


# --- Texel painters ---------------------------------------------------------

func _paint_dish(x: int, y: int) -> Color:
	var flat := (Vector2(x + 0.5, y + 0.5) - Vector2(DISH_TEXELS) * 0.5) / (Vector2(DISH_TEXELS) * 0.5)
	var reach := flat.length()
	if reach > 1.0:
		return Pixels.CLEAR
	# A rolled lip with rivets, pressed rings, and a painted sun in the middle.
	if reach > 0.94:
		var angle := fposmod(flat.angle(), TAU)
		if reach < 0.975 and int(angle / TAU * 48.0) % 2 == 0 and absf(fmod(angle / TAU * 48.0, 1.0) - 0.5) < 0.2:
			return BRASS.lightened(0.1)
		return Pixels.rounded(TIN.lightened(0.05), Vector2(flat.x, flat.y) * 0.6)
	if reach > 0.9:
		return TIN.darkened(0.45)
	var ring := fmod(reach * 9.0, 1.0)
	var tone := Pixels.metal(TIN.darkened(0.05 + 0.18 * maxf(0.0, flat.y)), x, y)
	if ring < 0.08:
		tone = tone.darkened(0.2)
	elif ring < 0.16:
		tone = tone.lightened(0.08)
	if reach < 0.22:
		var spoke := int((flat.angle() + PI) / TAU * 12.0) % 2
		return Pixels.grainy(RED.lightened(0.1) if spoke == 0 else PAPER.darkened(0.08), x, y, 0.1)
	if reach < 0.25:
		return RED.darkened(0.4)
	# Scuffs where tops have skidded.
	if Pixels.noise(x / 3, y, 5) > 0.93:
		tone = tone.lightened(0.12)
	return tone


func _paint_top(x: int, y: int, body: Color, stripe: Color, frame: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# Knob on top, a fat painted body, a brass collar and a steel point.
	if y < 4:
		return Pixels.wood(WOOD.lightened(0.15), x, y, 3) if absf(at.x - 8.5) < 1.6 else Pixels.CLEAR
	if y == 4:
		return BRASS if absf(at.x - 8.5) < 3.0 else Pixels.CLEAR
	var bulge := (at - Vector2(8.5, 10.0)) / Vector2(8.5, 5.5)
	if bulge.length() <= 1.0:
		var band := posmod(x + frame * 2, 8)
		var tone: Color = stripe if band < 2 else body
		if y == 10 or y == 11:
			tone = BRASS.darkened(0.1) if band % 4 != 0 else BRASS.lightened(0.2)
		return Pixels.rounded(tone, bulge)
	var spike := absf(at.x - 8.5)
	if y > 14 and spike < (20.0 - at.y) * 0.9:
		return Pixels.metal(Color("#8f8a86"), x, y) if y > 17 else Pixels.wood(body.darkened(0.3), x, y, 4)
	return Pixels.CLEAR
