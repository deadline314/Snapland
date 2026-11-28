extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 葉舟搬家: a greenhouse stream seen from above, running up the
## screen between mossy banks dotted with ferns and pebbles. The traveller
## sits in a curled green leaf with a little paddle that dips on the side of
## each stroke; ants that climb aboard ride along the leaf's edge. Pink
## petals float by with ants waving on them; mossy rocks wear a ring of foam;
## whirlpools spin in dashed rings around a dark eye. Long islands split the
## stream. A capsize leaves the leaf floating upside down while a column of
## ants carries the soaked traveller off to the bank on their heads.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const WATER := Color("#3f8fa8")
const DEEP := Color("#2c6f86")
const FOAM := Color("#e8f6f4")
const MOSS := Color("#5f8a4a")
const LEAF := Color("#5fa04a")
const PETAL := Color("#f2a7b8")
const ANT := Color("#2a2020")
const ROCK := Color("#7f8a8c")
const MORNING := Color(1.0, 0.98, 0.94)
const ROW := 8.0
## The leaf is drawn bigger than other sprites so its passengers read.
const BOAT_SCALE := 5.5

var _water: ImageTexture
var _bank: ImageTexture
var _stone: ImageTexture
var _leaf: ImageTexture
var _flipped: ImageTexture
var _petal: ImageTexture
var _ant: ImageTexture
var _rock: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _ready() -> void:
	_water = _tile(Vector2i(32, 32), _paint_water)
	_bank = _tile(Vector2i(32, 32), _paint_bank)
	_stone = Pixels.bake("bank-stone", Vector2i(6, 5), _paint_stone)
	_leaf = Pixels.bake("leaf-boat", Vector2i(15, 24), _paint_leaf.bind(false))
	_flipped = Pixels.bake("leaf-boat-flipped", Vector2i(15, 24), _paint_leaf.bind(true))
	_petal = Pixels.bake("ant-petal", Vector2i(12, 9), _paint_petal)
	_ant = Pixels.bake("ant", Vector2i(7, 5), _paint_ant)
	_rock = Pixels.bake("stream-rock", Vector2i(13, 11), _paint_rock)


## A seamless repeating tile (no outline, unlike Pixels.bake sprites).
func _tile(size: Vector2i, paint: Callable) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			image.set_pixel(x, y, paint.call(x, y))
	return ImageTexture.create_from_image(image)


func _draw_backdrop() -> void:
	if not state.has("travel"):
		draw_rect(Rect2(Vector2.ZERO, DESIGN), DEEP)
		return
	var scroll := float(state.travel) * DESIGN.y
	var flow := 0.0 if reduced_motion else now * 18.0
	_tile_rect(Rect2(Vector2.ZERO, DESIGN), _water, Vector2(0, -scroll - flow))
	_draw_banks(scroll)
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("things"):
		return
	for thing: Dictionary in state.things:
		if float(thing.taken_at) >= 0.0 and thing.kind != "ants":
			continue
		match thing.kind:
			"whirl": _draw_whirl(thing)
			"rock": _draw_rock(thing)
			"ants": _draw_petal(thing)
	_draw_boat()


# --- Placement ----------------------------------------------------------------

## Screen y of a distance along the stream.
func _sy(y: float) -> float:
	return float(state.boat_screen) * DESIGN.y - (y - float(state.travel)) * DESIGN.y


## Distance along the stream at a screen y.
func _wy(sy: float) -> float:
	return float(state.travel) + (float(state.boat_screen) * DESIGN.y - sy) / DESIGN.y


func _banks(y: float) -> Vector2:
	return (state.bank_at as Callable).call(y)


# --- Water and banks ----------------------------------------------------------

## Fill `rect` with a repeating baked tile, shifted by `offset` pixels.
func _tile_rect(rect: Rect2, tile: Texture2D, offset: Vector2) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	_tile_polygon(points, tile, offset)


func _tile_polygon(points: PackedVector2Array, tile: Texture2D, offset: Vector2) -> void:
	var span := Vector2(tile.get_size()) * TEXEL
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((point + offset) / span)
	draw_colored_polygon(points, MORNING, uvs, tile)


func _draw_banks(scroll: float) -> void:
	var left := PackedVector2Array([Vector2(-4, -4)])
	var right := PackedVector2Array([Vector2(DESIGN.x + 4.0, -4)])
	var sy := -ROW
	while sy <= DESIGN.y + ROW:
		var edge := _banks(_wy(sy)) * DESIGN.x
		left.append(Vector2(roundf(edge.x / TEXEL) * TEXEL, sy))
		right.append(Vector2(roundf(edge.y / TEXEL) * TEXEL, sy))
		sy += ROW
	left.append(Vector2(-4, DESIGN.y + 4.0))
	right.append(Vector2(DESIGN.x + 4.0, DESIGN.y + 4.0))
	for side in [left, right]:
		# A wet dark rim first, then the mossy bank over it.
		var rim := PackedVector2Array()
		for point: Vector2 in side:
			rim.append(point + Vector2(8 if side == left else -8, 0) if point.x > 0.0 and point.x < DESIGN.x else point)
		draw_colored_polygon(rim, Color(DEEP.darkened(0.3), 0.6))
		_tile_polygon(side, _bank, Vector2(0, -scroll))
	for fork: Dictionary in state.forks:
		_draw_island(fork, scroll)
	# Pebbles along both edges, fixed to the stream so they scroll with it.
	var step := 0.04
	var y := floorf(_wy(DESIGN.y + 20.0) / step) * step
	while _sy(y) > -20.0:
		var edge := _banks(y) * DESIGN.x
		var at := _sy(y)
		var wobble := 6.0 * sin(y * 37.0)
		stamp(_stone, Vector2(edge.x - 14.0 + wobble, at - 10.0), TEXEL, MORNING)
		stamp(_stone, Vector2(edge.y - 10.0 - wobble, at - 10.0), TEXEL, MORNING)
		y += step


func _draw_island(fork: Dictionary, scroll: float) -> void:
	var outline := PackedVector2Array()
	var back := PackedVector2Array()
	for step in 17:
		var y := lerpf(float(fork.y0), float(fork.y1), step / 16.0)
		var half := 0.11 * sin(step / 16.0 * PI)
		outline.append(Vector2((float(fork.centre) - half) * DESIGN.x, _sy(y)))
		back.append(Vector2((float(fork.centre) + half) * DESIGN.x, _sy(y)))
	back.reverse()
	outline.append_array(back)
	_tile_polygon(outline, _bank, Vector2(0, -scroll))
	draw_polyline(outline + PackedVector2Array([outline[0]]), Color(DEEP.darkened(0.3), 0.7), 4.0)
	for point in outline:
		stamp(_stone, point - Vector2(12, 10), TEXEL, MORNING)


# --- Things on the stream -------------------------------------------------------

func _draw_petal(thing: Dictionary) -> void:
	var taken := age(float(thing.taken_at)) if float(thing.taken_at) >= 0.0 else -1.0
	if taken > 0.4:
		return
	var at := Vector2(float(thing.x) * DESIGN.x, _sy(float(thing.y)))
	var bob := 0.0 if reduced_motion else 2.0 * sin(now * 3.0 + float(thing.y) * 9.0)
	var size := Vector2(_petal.get_size()) * TEXEL
	ground_shadow(at + Vector2(6, 10), Vector2(size.x * 0.45, 8), 0.25)
	stamp(_petal, at - size * 0.5 + Vector2(0, bob), TEXEL, MORNING)
	for ant in int(thing.count):
		var hop := 0.0 if taken < 0.0 else -40.0 * taken
		var wave := 0.0 if reduced_motion else 2.0 * sin(now * 10.0 + ant * 2.0)
		stamp(_ant, at + Vector2(-26.0 + ant * 18.0, -14.0 + bob + wave + hop), TEXEL, MORNING)


func _draw_rock(thing: Dictionary) -> void:
	var at := Vector2(float(thing.x) * DESIGN.x, _sy(float(thing.y)))
	var size := Vector2(_rock.get_size()) * TEXEL
	# A ring of foam where the water parts round the rock.
	var froth := 0.0 if reduced_motion else 3.0 * sin(now * 6.0 + float(thing.y) * 5.0)
	draw_rect(Rect2(at + Vector2(-size.x * 0.6, size.y * 0.25), Vector2(size.x * 1.2, 8 + froth)), Color(FOAM, 0.7))
	draw_rect(Rect2(at + Vector2(-size.x * 0.45, -size.y * 0.55), Vector2(size.x * 0.9, 6)), Color(FOAM, 0.5))
	stamp(_rock, at - size * 0.5, TEXEL, MORNING)


func _draw_whirl(thing: Dictionary) -> void:
	var at := Vector2(float(thing.x) * DESIGN.x, _sy(float(thing.y)))
	var spin := 0.0 if reduced_motion else now * 2.2
	draw_circle(at, float(state.whirl_eye) * DESIGN.y * 0.8, Color(DEEP.darkened(0.45), 0.9))
	for ring in 3:
		var radius := float(state.whirl_eye) * DESIGN.y + ring * 28.0
		var dashes := 10 + ring * 4
		for dash in dashes:
			var angle := dash * TAU / dashes + spin * (1.6 - ring * 0.4)
			var spot := at + Vector2.from_angle(angle) * radius
			draw_rect(Rect2(spot.snappedf(TEXEL) - Vector2(TEXEL * 1.5, TEXEL * 0.5), Vector2(TEXEL * 3.0, TEXEL * 1.5)), Color(FOAM, 0.95 - ring * 0.2))


# --- The leaf and the traveller -------------------------------------------------

func _draw_boat() -> void:
	var flip: Dictionary = state.get("flip", {})
	var since := age(float(flip.get("at", -99.0)))
	var flipped := not flip.is_empty() and since >= 0.0 and since < float(state.flip_seconds)
	var size := Vector2(_leaf.get_size()) * BOAT_SCALE
	if flipped:
		_draw_rescue(flip, since)
		return
	var at := Vector2(float(state.x) * DESIGN.x, float(state.boat_screen) * DESIGN.y)
	var tilt := clampf(float(state.vx) * 0.9, -0.5, 0.5)
	# A wake trailing behind.
	for side: float in [-1.0, 1.0]:
		for puff in 3:
			draw_rect(Rect2(at + Vector2(side * (14.0 + puff * 10.0) - 3.0, size.y * 0.45 + puff * 12.0), Vector2(TEXEL * 1.5, TEXEL)), Color(FOAM, 0.6 - puff * 0.15))
	ground_shadow(at + Vector2(8, 12), Vector2(size.x * 0.5, size.y * 0.42), 0.3)
	draw_set_transform(at, tilt, Vector2.ONE)
	stamp(_leaf, -size * 0.5, BOAT_SCALE, MORNING)
	# Ants riding along the rim of the leaf.
	var riders := mini(int(state.ants), 12)
	for rider in riders:
		var side := -1.0 if rider % 2 == 0 else 1.0
		var row := float(rider / 2)
		stamp(_ant, Vector2(side * (size.x * 0.34) - 8.0, -size.y * 0.34 + row * 13.0), TEXEL * 0.55, MORNING)
	# The traveller, seen from behind, and the paddle dipping on the stroke side.
	var hero := Hero.texture(&"idle", false, "plain")
	stamp(hero, Vector2(-21, -30) * 1.7, 1.7, MORNING)
	var dip := clampf(1.0 - age(float(state.last_stroke)) / 0.35, 0.0, 1.0)
	var side := float(state.stroke_side) if int(state.stroke_side) != 0 else 1.0
	var blade := Vector2(side * (size.x * 0.5 + 10.0 + 8.0 * dip), -4.0 + 14.0 * dip)
	draw_line(Vector2(side * 10.0, -16.0), blade, Color("#8a6640"), 5.0)
	draw_rect(Rect2(blade - Vector2(6, 10), Vector2(12, 20)), Color("#b5884e"))
	draw_rect(Rect2(blade - Vector2(6, 10), Vector2(12, 20)).grow(1.0), INK, false, 2.0)
	if dip > 0.0:
		draw_rect(Rect2(blade + Vector2(-14, 10), Vector2(28, 6)), Color(FOAM, 0.7 * dip))
	draw_set_transform(Vector2.ZERO)


func _draw_rescue(flip: Dictionary, since: float) -> void:
	# The leaf floats upside down; a column of ants carries the soaked
	# traveller off toward the nearer bank on their heads.
	var start := Vector2(float(flip.x) * DESIGN.x, float(state.boat_screen) * DESIGN.y)
	var size := Vector2(_flipped.get_size()) * BOAT_SCALE
	var bob := 0.0 if reduced_motion else 4.0 * sin(since * 5.0)
	stamp(_flipped, start - size * 0.5 + Vector2(0, bob), BOAT_SCALE, MORNING)
	var edge := _banks(float(state.travel)) * DESIGN.x
	var home := edge.x - 40.0 if float(flip.x) < 0.5 else edge.y + 40.0
	var march := 1.0 if reduced_motion else smoothstep(0.35, float(state.flip_seconds), since)
	var carried := Vector2(lerpf(start.x, home, march), start.y - 40.0)
	for bearer in 4:
		var step := 0.0 if reduced_motion else 3.0 * sin(now * 16.0 + bearer * 1.7)
		stamp(_ant, carried + Vector2(-58.0 + bearer * 32.0, 24.0 + step), TEXEL, MORNING)
	var hero := Hero.texture(&"idle", true, "soaked")
	draw_set_transform(carried, -PI * 0.5, Vector2.ONE * 1.6)
	draw_texture(hero, -Vector2(hero.get_size()) * 0.5)
	draw_set_transform(Vector2.ZERO)
	# Drips falling off the soaked traveller.
	if not reduced_motion:
		for drip in 3:
			var fall := fposmod(now * 1.8 + drip * 0.33, 1.0)
			draw_rect(Rect2(carried + Vector2(-30.0 + drip * 30.0, 10.0 + fall * 30.0), Vector2(TEXEL, TEXEL * 1.5)), Color(WATER.lightened(0.4), 1.0 - fall))


# --- Texel painters ---------------------------------------------------------------

func _paint_water(x: int, y: int) -> Color:
	# Deep teal water with lighter ripple streaks running along the flow.
	var tone := WATER.darkened(0.08 * sin(x * 0.4))
	if (y + int(4.0 * sin(x * 0.35))) % 9 == 0 and Pixels.noise(x / 3, y, 61) > 0.4:
		tone = WATER.lightened(0.25)
	return Pixels.grainy(tone, x, y, 0.06)


func _paint_bank(x: int, y: int) -> Color:
	# Mossy greenhouse bank: moss in two greens, fern tufts and a few pebbles.
	var tone := MOSS.lightened(0.08 * Pixels.noise(x / 2, y / 2, 63))
	if Pixels.noise(x / 4, y / 4, 67) > 0.7:
		tone = tone.darkened(0.15)
	var fern := posmod(x * 5 + y * 3, 11) == 0 and Pixels.noise(x / 5, y / 5, 71) > 0.5
	if fern:
		tone = Color("#7fb05a")
	if Pixels.noise(x, y, 73) > 0.97:
		tone = Color("#ffd166") if Pixels.noise(x, y, 79) > 0.5 else Color("#f2a7b8")
	return Pixels.grainy(tone, x, y, 0.08)


func _paint_stone(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5 - 3.0) / 3.0, (y + 0.5 - 2.5) / 2.5)
	if at.length() > 1.0:
		return Pixels.CLEAR
	var tone := ROCK if y > 1 else ROCK.lerp(MOSS, 0.6)
	return Pixels.rounded(tone, at)


func _paint_leaf(x: int, y: int, flipped: bool) -> Color:
	# A curled leaf pointing upstream: pointed tip, a midrib and side veins,
	# its rim curled up lighter. Upside down it shows the pale underside.
	var along := (y + 0.5) / 24.0
	var half := 7.4 * sin(minf(along * 1.15, 1.0) * PI) * (0.6 + 0.4 * along)
	var off := absf(x + 0.5 - 7.5)
	if off > half:
		return Pixels.CLEAR
	var tone := LEAF.lightened(0.25) if flipped else LEAF
	if off > half - 1.2:
		tone = tone.lightened(0.18)
	elif off < 0.8 or posmod(y - int(off * 1.2), 4) == 0:
		tone = tone.lightened(0.12) if flipped else tone.darkened(0.2)
	return Pixels.lit(tone, (x - 7.5) / -8.0 * 0.6, x, y)


func _paint_petal(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5 - 6.0) / 6.0, (y + 0.5 - 4.5) / 4.5)
	if at.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.rounded(PETAL if at.length() > 0.35 else Color("#ffd166"), at)


func _paint_ant(x: int, y: int) -> Color:
	# A little ant from above facing right: round head, a pinched waist and a
	# big abdomen, with three legs sticking out on each side.
	if y == 0 or y == 4:
		return ANT.lightened(0.3) if x == 2 or x == 3 or x == 5 else Pixels.CLEAR
	var head := x >= 5 and (y == 2 or x == 5)
	var waist := x == 4 and y == 2
	var abdomen := x <= 3 and not ((x == 0) and y != 2)
	if head or waist or abdomen:
		return ANT.lightened(0.25) if y == 1 and x != 4 else ANT
	return Pixels.CLEAR


func _paint_rock(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5 - 6.5) / 6.5, (y + 0.5 - 5.5) / 5.5)
	if at.length() > 1.0:
		return Pixels.CLEAR
	var tone := ROCK
	if at.y < -0.2 and Pixels.noise(x, y, 83) > 0.35:
		tone = MOSS.lightened(0.1)
	return Pixels.grainy(Pixels.rounded(tone, at), x, y, 0.08)
