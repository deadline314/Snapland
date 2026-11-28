extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 花粉拓印: the greenhouse craft table. Behind it the shared
## greenhouse backdrop (glass, shelves of pots, sun shafts and drifting dust);
## across the top a timber beam with ivy swaying from it and a brass hook,
## from which a cord swings a big wooden flower stamp. On the plank table a
## long sheet of grained paper with a dashed pink frame, a row of ink jars and
## a pot of flowers; the island traveller (arcade_hero) leans in at the far end.
## Prints are pink five-petal flowers in speckled ink. A miss sends the stamp
## flying up to thump the traveller's forehead, which keeps a pink flower.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Greenhouse = preload("res://game/minigames/arcade/greenhouse_backdrop.gd")
const TABLE_TOP := 400.0
const PAPER := Rect2(150, 424, 980, 122)
const PAPER_Y := 485.0
const SLIDE := 900.0
const HERO_AT := Vector2(1148, 428)
const HERO_SCALE := 3.2
const WOOD := Color("#9a7048")
const DYE := Color("#e0587a")
const CREAM_PAPER := Color("#f6eedb")
const LEAF := Color("#5f9e4f")
const BRASS := Color("#d9a64e")
const MORNING := Color(1.0, 0.98, 0.94)

var _stamp: ImageTexture
var _print: ImageTexture
var _smudge: ImageTexture
var _paper: ImageTexture
var _beam: ImageTexture
var _ivy: ImageTexture
var _jar: Array[ImageTexture] = []
var _pot: ImageTexture
var _brow: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _ready() -> void:
	_stamp = Pixels.bake("flower-stamp", Vector2i(16, 22), _paint_stamp)
	_print = Pixels.bake("flower-print", Vector2i(19, 19), _paint_print.bind(false))
	_smudge = Pixels.bake("flower-print-smudge", Vector2i(19, 19), _paint_print.bind(true))
	_paper = _tile(Vector2i(40, 34), _paint_paper)
	_beam = Pixels.bake("craft-beam", Vector2i(320, 6), _paint_beam)
	_ivy = Pixels.bake("craft-ivy", Vector2i(9, 30), _paint_ivy)
	for tone: Color in [Color("#e0587a"), Color("#f2b93a"), Color("#6f9ad8")]:
		_jar.append(Pixels.bake("ink-jar|%s" % tone.to_html(), Vector2i(9, 11), _paint_jar.bind(tone)))
	_pot = Pixels.bake("craft-pot", Vector2i(20, 24), _paint_pot)
	_brow = Pixels.bake("brow-flower", Vector2i(9, 9), _paint_small_print)


## A seamless repeating tile (no outline).
func _tile(size: Vector2i, paint: Callable) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			image.set_pixel(x, y, paint.call(x, y))
	return ImageTexture.create_from_image(image)


func _draw_backdrop() -> void:
	Greenhouse.draw(self, now, reduced_motion)
	# The timber beam the stamp hangs from, with ivy swaying off it.
	stamp(_beam, Vector2(0, 118), TEXEL, MORNING)
	for vine in 6:
		var x := 70.0 + vine * 230.0 + (vine % 2) * 40.0
		var sway := 0.0 if reduced_motion else 0.06 * sin(now * 0.9 + vine * 1.7)
		draw_set_transform(Vector2(x, 140), sway, Vector2.ONE)
		stamp(_ivy, Vector2(-18, 0), TEXEL * (0.8 + 0.2 * (vine % 3)), MORNING)
		draw_set_transform(Vector2.ZERO)
	vignette(0.28)


func _draw_scene() -> void:
	if not state.has("frame"):
		return
	var bonked := _bonked()
	_draw_hero(bonked)
	_draw_table()
	_draw_sheet()
	_draw_stamp(bonked)
	_draw_props()


# --- The table and paper --------------------------------------------------------

func _draw_table() -> void:
	bench(TABLE_TOP, WOOD)
	# A soft shadow under the paper and the paper itself, scrolling as sheets go by.
	draw_rect(Rect2(PAPER.position + Vector2(8, 10), PAPER.size), Color(Props.SHADOW, 0.28))
	var scroll := _scroll()
	var points := PackedVector2Array([PAPER.position, Vector2(PAPER.end.x, PAPER.position.y), PAPER.end, Vector2(PAPER.position.x, PAPER.end.y)])
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((point + Vector2(scroll, 0)) / (Vector2(_paper.get_size()) * TEXEL))
	draw_colored_polygon(points, MORNING, uvs, _paper)
	# Light falls from the upper left: bands of warm light fading into shade
	# toward the right, and a soft shade along the near edge.
	for band in 8:
		var x := PAPER.position.x + band * PAPER.size.x / 8.0
		var light := 0.1 - band * 0.022
		draw_rect(Rect2(x, PAPER.position.y, PAPER.size.x / 8.0, PAPER.size.y), Color(1, 1, 0.9, light) if light > 0.0 else Color(Props.SHADOW, -light))
	draw_rect(Rect2(PAPER.position.x, PAPER.end.y - 14.0, PAPER.size.x, 14), Color(Props.SHADOW, 0.1))
	draw_rect(Rect2(PAPER.position.x, PAPER.position.y, PAPER.size.x, 6), Color(1, 1, 1, 0.18))
	draw_rect(PAPER, DYE.darkened(0.7), false, 2.0)


## How far the paper has rolled along, in pixels.
func _scroll() -> float:
	var sheets := float(state.get("sheets", 0)) * SLIDE
	var leaving: Dictionary = state.leaving
	if not leaving.is_empty():
		sheets -= SLIDE * (1.0 - _slide(float(leaving.at)))
	return sheets


func _slide(at: float) -> float:
	return 1.0 if reduced_motion else ease(clampf(age(at) / float(state.slide_seconds), 0.0, 1.0), -2.0)


func _draw_sheet() -> void:
	var leaving: Dictionary = state.leaving
	if not leaving.is_empty() and _slide(float(leaving.at)) < 1.0:
		var away := -SLIDE * _slide(float(leaving.at))
		_draw_frame(leaving.frame, away)
		_draw_print(leaving.print, away)
	var frame: Dictionary = state.frame
	if frame.is_empty():
		return
	var arrive := SLIDE * (1.0 - _slide(float(frame.at)))
	_draw_frame(frame, arrive)
	var press: Dictionary = state.press
	if not press.is_empty() and str(press.result) != "":
		_draw_print(press, 0.0)


func _draw_frame(frame: Dictionary, shift: float) -> void:
	if frame.is_empty():
		return
	var centre := Vector2(float(frame.x) + shift, PAPER_Y)
	var size := Vector2(float(frame.w), 104)
	var box := Rect2(centre - size * 0.5, size)
	if centre.x < PAPER.position.x + 20.0 or centre.x > PAPER.end.x - 20.0:
		return
	box = box.intersection(PAPER.grow(-4.0))
	# A faint flower ghost shows where the print belongs.
	draw_circle(centre, 30.0, Color(DYE, 0.08))
	var dash := 0.0
	while dash < size.x:
		draw_rect(Rect2(box.position + Vector2(dash, 0), Vector2(minf(10.0, size.x - dash), 4)), Color(DYE, 0.85))
		draw_rect(Rect2(Vector2(box.position.x + dash, box.end.y - 4.0), Vector2(minf(10.0, size.x - dash), 4)), Color(DYE, 0.85))
		dash += 16.0
	dash = 0.0
	while dash < size.y:
		draw_rect(Rect2(box.position + Vector2(0, dash), Vector2(4, minf(10.0, size.y - dash))), Color(DYE, 0.85))
		draw_rect(Rect2(Vector2(box.end.x - 4.0, box.position.y + dash), Vector2(4, minf(10.0, size.y - dash))), Color(DYE, 0.85))
		dash += 16.0
	# Corner ticks and a centre mark.
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		draw_rect(Rect2(corner - Vector2(5, 5), Vector2(10, 10)), DYE.darkened(0.2))
	draw_rect(Rect2(centre - Vector2(2, 9), Vector2(4, 18)), Color(DYE, 0.4))
	draw_rect(Rect2(centre - Vector2(9, 2), Vector2(18, 4)), Color(DYE, 0.4))


func _draw_print(press: Dictionary, shift: float) -> void:
	if press.is_empty() or str(press.result) == "":
		return
	var miss := str(press.result) == "miss"
	var texture := _smudge if miss else _print
	var size := Vector2(texture.get_size()) * TEXEL
	var at := Vector2(float(press.x) + shift, PAPER_Y + (10.0 if miss else 0.0))
	if at.x < PAPER.position.x + 30.0 or at.x > PAPER.end.x - 30.0:
		return
	draw_set_transform(at, 0.35 if miss else 0.0, Vector2.ONE)
	stamp(texture, -size * 0.5, TEXEL, Color(1, 1, 1, 0.92))
	draw_set_transform(Vector2.ZERO)
	if str(press.result) == "centre" and shift == 0.0:
		glint(at + Vector2(24, -24), 10.0, 1.2)


# --- The stamp -----------------------------------------------------------------

func _stamp_spot(bonked: float) -> Vector2:
	var hang := Vector2(float(state.stamp_x), float(state.pivot.y) + float(state.cord))
	var press: Dictionary = state.press
	if bonked >= 0.0:
		# Up, over and down onto the traveller's forehead, then back.
		var head := HERO_AT + Vector2(-8, -40 * HERO_SCALE)
		var start := Vector2(float(press.get("x", hang.x)), PAPER_Y - 40.0)
		var out := clampf(bonked / 0.35, 0.0, 1.0)
		var back := clampf((bonked - 1.0) / 0.5, 0.0, 1.0)
		var arc := start.lerp(head + Vector2(0, -60), ease(out, -2.0)) + Vector2(0, -90.0 * sin(out * PI))
		return arc.lerp(hang, ease(back, -2.0))
	if press.is_empty():
		return hang
	var since := age(float(press.at))
	var down := float(state.drop_seconds)
	var reach := PAPER_Y - 40.0 - hang.y
	if since < down:
		return hang + Vector2(0, reach * ease(since / down, 2.0))
	var up := clampf((since - down) / float(state.lift_seconds), 0.0, 1.0)
	return hang + Vector2(0, reach * (1.0 - ease(up, -2.0)))


func _draw_stamp(bonked: float) -> void:
	var spot := _stamp_spot(bonked)
	var size := Vector2(_stamp.get_size()) * TEXEL
	# Its shadow on the paper tightens as it comes down.
	var height := clampf((PAPER_Y - 40.0 - spot.y) / 160.0, 0.0, 1.0)
	if bonked < 0.0:
		ground_shadow(Vector2(spot.x + 8.0, PAPER_Y + 6.0), Vector2(lerpf(34.0, 60.0, height), lerpf(10.0, 16.0, height)), lerpf(0.45, 0.18, height))
	# The cord from the brass hook.
	var hook := Vector2(float(state.pivot.x), float(state.pivot.y))
	draw_rect(Rect2(hook - Vector2(10, 22), Vector2(20, 18)), BRASS.darkened(0.2))
	draw_rect(Rect2(hook - Vector2(7, 19), Vector2(14, 6)), BRASS.lightened(0.3))
	if bonked < 0.0:
		draw_line(hook, spot + Vector2(0, -size.y * 0.5), Color("#5a4632"), 4.0)
		draw_line(hook + Vector2(1, 0), spot + Vector2(1, -size.y * 0.5), Color("#8a6a48"), 2.0)
	var tilt := 0.0 if bonked >= 0.0 else -float(state.angle) * 0.35
	if bonked >= 0.0:
		tilt = -2.6 if bonked > 0.3 and bonked < 1.0 else 0.0
	draw_set_transform(spot, tilt, Vector2.ONE)
	stamp(_stamp, -size * 0.5, TEXEL, MORNING)
	draw_set_transform(Vector2.ZERO)


# --- The traveller and props -------------------------------------------------------

func _bonked() -> float:
	var bonk: Dictionary = state.bonk
	if bonk.is_empty():
		return -1.0
	var since := age(float(bonk.at))
	return since if since < float(state.bonk_seconds) else -1.0


func _draw_hero(bonked: float) -> void:
	var hit := bonked >= 0.35 and bonked < 1.4
	var mood := "shocked" if hit else "plain"
	var wobble := 0.0 if reduced_motion or not hit else 0.12 * sin(bonked * 22.0)
	var texture := Hero.texture(&"left", true, mood)
	var origin := HERO_AT - Vector2(21, 47) * HERO_SCALE
	draw_set_transform(HERO_AT, wobble, Vector2.ONE)
	stamp(texture, origin - HERO_AT, HERO_SCALE, MORNING)
	draw_set_transform(Vector2.ZERO)
	# Flower prints collect on the forehead, one per miss.
	var brow := HERO_AT + Vector2(-26, -38 * HERO_SCALE)
	for flower in mini(int(state.forehead), 3):
		if flower == int(state.forehead) - 1 and bonked >= 0.0 and bonked < 0.35:
			continue
		stamp(_brow, brow + Vector2(flower * 16.0 - 4.0, (flower % 2) * 8.0), TEXEL, Color(1, 1, 1, 0.95))
	if hit:
		# Little stars spin round the stunned head.
		for star in 3:
			var turn := star * TAU / 3.0 + (0.0 if reduced_motion else bonked * 6.0)
			var at := brow + Vector2(20, -10) + Vector2(cos(turn) * 46.0, sin(turn) * 12.0 - 10.0)
			draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), GOLD)
			draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), DYE.darkened(0.6), false, 2.0)


func _draw_props() -> void:
	# Ink jars along the back of the table and a pot of flowers at the front.
	for jar in _jar.size():
		var at := Vector2(1010 + jar * 44, TABLE_TOP + 4.0)
		ground_shadow(at + Vector2(22, 44), Vector2(22, 6), 0.3)
		stamp(_jar[jar], at, TEXEL, MORNING)
	var pot := Vector2(1150, 560)
	ground_shadow(pot + Vector2(50, 118), Vector2(52, 10), 0.35)
	var sway := 0.0 if reduced_motion else 0.03 * sin(now * 1.1)
	draw_set_transform(pot + Vector2(40, 120), sway, Vector2.ONE)
	stamp(_pot, Vector2(-40, -120), TEXEL * 1.25, MORNING)
	draw_set_transform(Vector2.ZERO)


# --- Texel painters ---------------------------------------------------------------

func _paint_stamp(x: int, y: int) -> Color:
	# A wooden stamp: round knob, a turned neck, a square block and a pink
	# rubber flower on its foot.
	var mid := 7.5
	var off := absf(x + 0.5 - 8.0)
	if y < 5:
		var knob := Vector2((x + 0.5 - 8.0) / 3.5, (y + 0.5 - 2.5) / 2.5)
		return Pixels.rounded(WOOD.lightened(0.15), knob) if knob.length() <= 1.0 else Pixels.CLEAR
	if y < 9:
		return Pixels.lit(WOOD.darkened(0.05), 0.4 - (x - mid) * 0.12, x, y) if off < 1.6 else Pixels.CLEAR
	if y < 18:
		if off > 7.0:
			return Pixels.CLEAR
		return Pixels.wood(WOOD.lightened(0.05 if x < 8 else -0.1), x, y, 5, true)
	if off > 6.0:
		return Pixels.CLEAR
	return Pixels.lit(DYE, 0.3 - off * 0.08, x, y) if posmod(x + y, 3) != 0 else DYE.darkened(0.15)


func _paint_print(x: int, y: int, smudged: bool) -> Color:
	# A five-petal flower in speckled ink with a yellow heart.
	var at := Vector2(x + 0.5 - 9.5, y + 0.5 - 9.5)
	if smudged:
		at = Vector2(at.x * 0.8 + at.y * 0.3, at.y * 1.1)
	var reach := at.length()
	var petals := 6.5 + 2.5 * cos(at.angle() * 5.0)
	if reach > petals:
		return Pixels.CLEAR
	if reach < 2.6:
		return Color("#f2b93a") if Pixels.noise(x, y, 91) > 0.15 else Color("#e09a2a")
	if Pixels.noise(x, y, 97) > (0.8 if smudged else 0.9):
		return Pixels.CLEAR
	return DYE.darkened(0.12) if reach > petals - 1.2 else DYE


func _paint_small_print(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5 - 4.5, y + 0.5 - 4.5)
	var petals := 3.2 + 1.2 * cos(at.angle() * 5.0)
	if at.length() > petals:
		return Pixels.CLEAR
	return Color("#f2b93a") if at.length() < 1.3 else DYE


func _paint_paper(x: int, y: int) -> Color:
	# Cream paper with visible fibres, faint ruled guide lines and light pencil
	# sketches of leaves left from earlier practice.
	var tone := CREAM_PAPER.darkened(0.07 * Pixels.noise(x, y, 101))
	if y % 10 == 9:
		tone = tone.darkened(0.07)
	if Pixels.noise(x / 3, y, 103) > 0.9:
		tone = tone.darkened(0.1)
	var sketch := Vector2(posmod(x, 20) - 10.0, posmod(y, 17) - 8.0)
	var leaf := absf(sketch.y - 0.25 * sketch.x * sketch.x * 0.1) < 0.6 and absf(sketch.x) < 6.0
	if leaf and (x / 20 + y / 17) % 3 == 1:
		tone = tone.darkened(0.16)
	return tone


func _paint_beam(x: int, y: int) -> Color:
	if y == 0:
		return WOOD.lightened(0.3)
	return Pixels.wood(WOOD.darkened(0.15 + 0.06 * y), x, y, 13, false)


func _paint_ivy(x: int, y: int) -> Color:
	# A trailing ivy strand: a thin stem with leaves alternating down it.
	var stem := 4.0 + 1.2 * sin(y * 0.45)
	if absf(x + 0.5 - stem) < 0.6:
		return LEAF.darkened(0.3)
	var side := -1.0 if (y / 5) % 2 == 0 else 1.0
	var leaf := Vector2((x + 0.5 - stem - side * 2.2) / 2.0, (posmod(y, 5) + 0.5 - 2.5) / 1.8)
	if leaf.length() <= 1.0 and y > 1:
		return Pixels.rounded(LEAF.lightened(0.05 * (y % 3)), leaf)
	return Pixels.CLEAR


func _paint_jar(x: int, y: int, tone: Color) -> Color:
	# A small glass ink jar with a cork, ink showing through the glass.
	if y < 2:
		return Pixels.wood(Color("#b5884e"), x, y, 3, false) if x >= 2 and x <= 6 else Pixels.CLEAR
	var at := Vector2((x + 0.5 - 4.5) / 4.5, (y + 0.5 - 6.5) / 4.5)
	if absf(at.x) > 1.0 or y > 10:
		return Pixels.CLEAR
	if y < 4:
		return Color("#cfe6ea") if x > 0 and x < 8 else Pixels.CLEAR
	return Pixels.rounded(tone, at) if x != 2 else tone.lightened(0.45)


func _paint_pot(x: int, y: int) -> Color:
	# A terracotta pot of daisies with leaves spilling over the rim.
	if y < 12:
		var bloom := Vector2(posmod(x, 6) + 0.5 - 3.0, posmod(y, 6) + 0.5 - 3.0)
		if (x / 6 + y / 6) % 2 == 0 and bloom.length() < 2.5:
			return Color("#ffd166") if bloom.length() < 1.0 else Color("#fff5dc")
		var leaf := Vector2((x + 0.5 - 10.0) / 10.0, (y + 0.5 - 9.0) / 9.0)
		return Pixels.rounded(LEAF, leaf) if leaf.length() <= 1.0 else Pixels.CLEAR
	var inset := (y - 12) / 4
	if x < 1 + inset or x > 18 - inset:
		return Pixels.CLEAR
	var tone := Color("#c0673f").lightened(0.15) if y < 14 else Color("#c0673f")
	return Pixels.grainy(Pixels.lit(tone, 0.4 - x * 0.05, x, y), x, y, 0.06)
