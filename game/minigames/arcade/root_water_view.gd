extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 根系蓄水: a long potting bench across the greenhouse with
## rollers along its front edge. Terracotta pots ride the rollers; each has a
## glass side showing dark soil threaded with roots, and a chalk line with a
## little leaf tab on either side. The island traveller (arcade_hero) stands
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
	return Vector2(float(pot.x) * DESIGN.x, BENCH_TOP + 2.0)


## The glass window of a pot (soil area), in design pixels.
func _window(pot: Dictionary) -> Rect2:
	var px := _pot_px(pot)
	var top_left := _pot_foot(pot) - Vector2(px.x * 0.5, px.y)
	return Rect2(top_left + Vector2(4, 3) * POT_SCALE, px - Vector2(8, 5) * POT_SCALE)


# --- The bench ------------------------------------------------------------------

func _draw_bench() -> void:
	bench(BENCH_TOP, WOOD)
	# Rollers along the lip turn while a pot is moving.
	var moving := false
	for pot: Dictionary in state.pots:
		moving = moving or pot.phase != "under"
	var turn := 0.0 if reduced_motion or not moving else fposmod(now * 40.0, 24.0)
	var x := -turn
	while x < DESIGN.x:
		stamp(_roller, Vector2(x, BENCH_TOP + 6.0), TEXEL, MORNING)
		x += 24.0


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
	var window := Rect2(Vector2(4, 3) * TEXEL, Vector2(POT_SIZES[size] - Vector2i(8, 5)) * TEXEL)
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
	if pot.result == "perfect":
		var shoot := pop_in(age(float(pot.result_at)), 0.35)
		stamp(_sprout, foot - Vector2(27, px.y + 50.0 * shoot), POT_SCALE * shoot, MORNING)
	if bool(pot.spilled):
		# Water sheets over the rim on both sides.
		for side: float in [-1.0, 1.0]:
			var lip := foot + Vector2(side * px.x * 0.5, -px.y)
			draw_rect(Rect2(lip + Vector2(-6 if side < 0.0 else 0.0, 0), Vector2(12, px.y)), Color(WATER, 0.55))


func _draw_line(window: Rect2, line: float) -> void:
	# A dashed chalk line across the glass and a leaf tab sticking out each side.
	var y := window.end.y - roundf(window.size.y * line / TEXEL) * TEXEL
	var x := window.position.x
	while x < window.end.x:
		draw_rect(Rect2(x, y - TEXEL * 0.5, TEXEL * 2.0, TEXEL), CHALK)
		x += TEXEL * 3.0
	for side: float in [-1.0, 1.0]:
		var tab := Vector2(window.position.x - 3.0 * TEXEL if side < 0.0 else window.end.x + TEXEL, y - TEXEL)
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
		var window := _window(station)
		bottom = window.end.y - window.size.y * clampf(float(station.level), 0.0, 1.0)
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
	# A terracotta pot: a thick rim on top, sides tapering in, and a glass
	# window cut into the front (left clear so the soil shows through).
	var taper := int(floor(float(y - 3) / texels.y * 3.0)) if y >= 3 else -1
	var left := 0 if y < 3 else 1 + taper
	var right := texels.x - 1 - left
	if x < left or x > right:
		return Pixels.CLEAR
	var tone := CLAY
	if y < 3:
		tone = CLAY.lightened(0.12)
		return Pixels.lit(tone, 0.4 - y * 0.3, x, y)
	var inside := x >= 4 and x <= texels.x - 5 and y >= 3 and y <= texels.y - 3
	if inside:
		# The glass: clear in the middle, a glint along one edge.
		if x == 4 or y == 3:
			return Color(1, 1, 1, 0.0)
		return Pixels.CLEAR
	if kind == "grow" and y >= texels.y - 5 and y <= texels.y - 4:
		return LEAF if (x / 2) % 2 == 0 else Color("#ffd166")
	if kind == "leaky" and (x == 2 and y == texels.y - 4 or x == texels.x - 3 and y == texels.y - 6):
		return Color("#3a2418")
	if kind == "leaky" and x <= 3 and y >= 6 and y <= 8:
		return Color("#d9c08a")
	var shade := float(x - left) / maxf(1.0, right - left)
	return Pixels.grainy(Pixels.lit(tone, 0.35 - shade * 0.7, x, y), x, y, 0.06)


func _paint_soil(x: int, y: int, texels: Vector2i) -> Color:
	# The inside seen through the glass: crumbly soil with pale roots winding down.
	if x < 3 or x > texels.x - 4 or y < 3 or y > texels.y - 2:
		return Pixels.CLEAR
	var root := absf(sin(float(y) * 0.55 + float(x) * 0.18) * 3.0 + texels.x * 0.5 - x) < 0.8 and y > 4
	var side_root := absf(sin(float(y) * 0.7 + 2.0) * 2.5 + texels.x * 0.32 - x) < 0.7 and y > 6
	if root or side_root:
		return ROOT.darkened(0.1 * float(y) / texels.y)
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


func _paint_roller(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5 - 2.5) / 2.5, (y + 0.5 - 2.5) / 2.5)
	if at.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.rounded(Color("#8a8f99"), at) if x != 2 else Color("#5a5f69")
