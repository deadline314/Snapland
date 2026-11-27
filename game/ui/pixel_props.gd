extends RefCounted
## The minigame drawing kit: materials, forms and finishing touches a view
## paints instead of raw rectangles and circles. Every function draws onto the
## CanvasItem it is given, from inside that item's _draw(). Arcade views reach
## the same functions through the thin wrappers in arcade_view.gd.
##
## Texel work (baking a sprite, the per-texel material recipes, one shared
## texture cache and noise) lives in arcade_pixels.gd; this file is the canvas
## side. Shared rules, so props from different games sit in one park:
## - light comes from the top left; undersides and right edges are darker;
## - outlines are a deepened local colour, never black;
## - forms land on a 2 px grid (one art pixel = PIXEL design pixels);
## - textures are generated once and cached, so drawing allocates nothing.

const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const PIXEL := 2.0
const OAK := Color("#a9794c")
const DRIFTWOOD := Color("#8a7a66")
const BRASS := Color("#c9a45a")
const IRON := Color("#5f7480")
const HEMP := Color("#d9c08a")
## Harbour dusk blue: the default for shadows and shading under props.
const SHADOW := Color("#0b2233")
## Stained board that carries light text (status boards, meter boards).
const SIGN_TEAL := Color("#1f4c5a")
## Candy factory: plum enamel boards and keys, rose and mint enamel, biscuit,
## cream icing and the plum dusk that shades everything under the awnings.
const SIGN_PLUM := Color("#43283f")
const KEY_PLUM := Color("#6b3f5c")
const KEY_MINT := Color("#2f6a62")
const BISCUIT := Color("#d29a5e")
const ICING := Color("#fbead2")
const CANDY_SHADOW := Color("#2a1430")

## 9 x 9 control icons, drawn in one colour. '#' is ink.
const ICONS := {
	"left": ["....#....", "...##....", "..###....", ".########", "#########", ".########", "..###....", "...##....", "....#...."],
	"right": ["....#....", "....##...", "....###..", "########.", "#########", "########.", "....###..", "....##...", "....#...."],
	"up": ["....#....", "...###...", "..#####..", ".#######.", "#########", "...###...", "...###...", "...###...", "...###..."],
	"down": ["...###...", "...###...", "...###...", "...###...", "#########", ".#######.", "..#####..", "...###...", "....#...."],
	"turn_left": ["..#......", ".##......", "#######..", ".##...##.", "..#....##", ".......##", ".......##", "......##.", "..#####.."],
	"turn_right": ["......#..", "......##.", "..#######", ".##...##.", "##....#..", "##.......", "##.......", ".##......", "..#####.."],
	"grab": ["..#.#.#..", "..#.#.#.#", "..#.#.#.#", "#.#######", "#########", "#########", ".#######.", "..#####..", "..#####.."],
	"hook": ["...###...", "...#.#...", "...###...", "....#....", "....#....", "#...#....", "#...#....", "##.##....", ".###....."],
	"anchor": ["...###...", "...#.#...", "...###...", ".#######.", "....#....", "#...#...#", "#...#...#", "##.###.##", ".#######."],
	"oar": ["......###", ".....####", ".....###.", "....##...", "...##....", "..##.....", ".##......", "##.......", "#........"],
	"sail": ["....#....", "....##...", "....###..", "....####.", "....#####", "....#....", "#########", ".#######.", "..#####.."],
	"wait": ["#########", ".#.....#.", "..#####..", "...###...", "....#....", "...#.#...", "..#.#.#..", ".#######.", "#########"],
	"confirm": [".........", "........#", ".......##", "#.....##.", "##...##..", ".##.##...", "..###....", "...#.....", "........."],
	"undo": ["...#.....", "..##.....", ".#######.", "..##...##", "...#....#", "........#", "........#", ".......##", "..######."],
	"lamp": ["....#....", "#...#...#", ".#.....#.", "...###...", "..#####..", "..#####..", "...###...", "...###...", "...###..."],
	"gate": ["#########", "#.#.#.#.#", "#.#.#.#.#", "#.#.#.#.#", "#########", "....#....", "...###...", "....#....", "....#...."],
	"wave": [".........", "..##.....", ".#..#...#", "#....#.#.", "......#..", "..##.....", ".#..#...#", "#....#.#.", "......#.."],
	"wing": [".........", "###......", ".####....", "..#####.#", "...######", "....####.", ".....##..", ".........", "........."],
	"more": ["...###...", "...###...", "...###...", "#########", "#########", "#########", "...###...", "...###...", "...###..."],
	"less": [".........", ".........", ".........", "#########", "#########", "#########", ".........", ".........", "........."],
	"power": ["....##...", "...##....", "..##.....", ".######..", "...####..", "....##...", "...##....", "..##.....", ".##......"],
	"shell": [".........", "...###...", "..#.#.#..", ".#.#.#.#.", "#.#.#.#.#", "#.#.#.#.#", ".#######.", "...###...", "....#...."],
	"strap": [".........", "#########", "#########", "...###...", "...#.#...", "...###...", "#########", "#########", "........."],
	"helper": ["....#....", ".#######.", ".#.....#.", ".#.#.#.#.", ".#.....#.", ".#######.", "...###...", ".#######.", "##.....##"],
	"swap": ["..#......", ".##......", "#######..", ".##......", "..#...#..", "......##.", "..#######", "......##.", "......#.."],
	# Night market keys.
	"umbrella": ["...###...", ".#######.", "#########", "#.#.#.#.#", "....#....", "....#....", "....#....", "..#.#....", "...#....."],
	"stop": ["..#####..", ".#######.", "#########", "#.......#", "#########", "#########", ".#######.", "..#####..", "........."],
	"flame": ["....#....", "...##....", "...###...", "..####.#.", ".######..", ".###.###.", "###...##.", ".##...##.", "..#####.."],
	"coin": ["..#####..", ".##...##.", "#...#...#", "#..###..#", "#...#...#", "#..###..#", "#...#...#", ".##...##.", "..#####.."],
	"funnel": ["#########", "#########", ".#######.", "..#####..", "...###...", "...###...", "...###...", "...###...", "....#...."],
	"ladle": ["......###", ".....##..", "....##...", "...##....", "#######..", "#######..", ".#####...", "..###....", "........."],
	"layers": ["....#....", "..##.##..", "##.....##", "..##.##..", "#...#...#", "##.....##", "..##.##..", "....#....", "........."],
	"awning": ["#########", "#.#.#.#.#", ".#.#.#.#.", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#"],
	"walk": ["......##.", "......##.", ".......#.", "..##.....", "..##.....", "...#..##.", "......##.", ".......#.", "........."],
	"reset": ["..####...", ".#....#.#", "#......##", "#.....###", "#........", "#.......#", ".#.....#.", "..#####..", "........."],
	# Welcome photo and music keys.
	"camera": ["..##.....", "#########", "#.......#", "#..###..#", "#.#...#.#", "#.#...#.#", "#..###..#", "#.......#", "#########"],
	"replay": ["...###.#.", ".##...##.", "#....###.", "#........", "#........", "#.......#", ".#.....#.", "..#####..", "........."],
	# Menu keepsakes (collage menus).
	"map": ["##..##...", "#.##..###", "#.#.#.#.#", "#.#..##.#", "#.#.#.#.#", "#..##.#.#", "#.#.#.#.#", "###..##.#", "...##..##"],
	"ticket": [".........", "#########", "#.#.....#", "...#.##..", "#.#.....#", "...#.##..", "#.#.....#", "#########", "........."],
	"album": ["#########", "#.......#", "#.##....#", "#.##..#.#", "#....###.", "#..#####.", "#.#######", "#########", "........."],
	"gear": ["...#.#...", ".#######.", ".##...##.", "###.#.###", ".#.###.#.", "###.#.###", ".##...##.", ".#######.", "...#.#..."],
	"hat": [".........", "...###...", "..#####..", "..#####..", "..#####..", "..#...#..", "#########", ".#######.", "........."],
	"task": [".#######.", ".#.....#.", ".#.##..#.", ".#.....#.", ".#.###.#.", ".#.....#.", ".#.##..#.", ".#.....#.", ".#######."],
	"clock": ["..#####..", ".#..#..#.", "#...#...#", "#...#...#", "#...###.#", "#.......#", "#.......#", ".#.....#.", "..#####.."],
	"book": [".........", "###...###", "#..#.#..#", "#..#.#..#", "#..#.#..#", "#..#.#..#", "####.####", "....#....", "........."],
	"door": ["..#####..", ".##...##.", ".#.....#.", ".#.....#.", ".#...#.#.", ".#.....#.", ".#.....#.", ".#.....#.", "#########"],
	"play": ["#........", "###......", "#####....", "#######..", "#########", "#######..", "#####....", "###......", "#........"],
	"pause": [".........", ".##...##.", ".##...##.", ".##...##.", ".##...##.", ".##...##.", ".##...##.", ".##...##.", "........."],
	"help": ["..#####..", ".##...##.", ".##...##.", ".....##..", "....##...", "...##....", ".........", "...##....", "...##...."],
	"star": ["....#....", "....#....", "...###...", "#########", ".#######.", "..#####..", "..##.##..", ".##...##.", "#.......#"],
}

# --- colour -------------------------------------------------------------------

## Snaps a position or size to the art-pixel grid.
static func snap(value: Vector2) -> Vector2:
	return (value / PIXEL).round() * PIXEL

static func snap_rect(rect: Rect2) -> Rect2:
	var from := snap(rect.position)
	return Rect2(from, snap(rect.end) - from)

## Outline and deep-shade tone: darker, a little richer, leaning to the cool
## shadow side. Clamped so no outline ever reaches black.
static func deepen(color: Color, amount := 0.45) -> Color:
	return Color.from_hsv(fposmod(color.h + (0.03 if color.h > 0.12 and color.h < 0.6 else -0.02), 1.0), minf(1.0, color.s * 1.18 + 0.06), maxf(0.16, color.v * (1.0 - amount)), color.a)

## Lit tone: lighter and slightly warmer, like a face turned to the sun.
static func lighten(color: Color, amount := 0.2) -> Color:
	return Color.from_hsv(color.h, color.s * (1.0 - amount * 0.55), minf(1.0, color.v + (1.0 - color.v) * amount + 0.04), color.a)

static func has_icon(icon_name: String) -> bool:
	return ICONS.has(icon_name)

# --- forms --------------------------------------------------------------------

## A solid block: lit top and left edge, a darker underside `lip` px tall and a
## deepened outline. With `pressed` the block sinks onto its lip.
static func shaded_box(canvas: CanvasItem, rect: Rect2, color: Color, lip := 6.0, pressed := false) -> void:
	var box := snap_rect(rect)
	var sink := lip - PIXEL if pressed else 0.0
	var face := Rect2(box.position + Vector2(0, sink), box.size - Vector2(0, lip))
	canvas.draw_rect(Rect2(box.position.x, face.end.y - PIXEL, box.size.x, box.end.y - face.end.y + PIXEL), deepen(color, 0.3))
	canvas.draw_rect(face, color)
	_bevel(canvas, face, lighten(color), deepen(color, 0.16))
	_outline(canvas, Rect2(box.position + Vector2(0, sink), box.size - Vector2(0, sink)), deepen(color))

## Planked wood with seams, grain and butt joints, inside a bevelled frame.
## `calm` lowers the grain contrast for boards that carry text.
static func wood_panel(canvas: CanvasItem, rect: Rect2, tone := OAK, calm := false) -> void:
	var box := snap_rect(rect)
	_tile(canvas, _wood(tone, 0.35 if calm else 1.0), box)
	_bevel(canvas, box, Color(lighten(tone, 0.3), 0.7), Color(deepen(tone, 0.3), 0.8))
	_outline(canvas, box, deepen(tone))

## A lacquered sign board with a gilt pinstripe and brass corner studs: a calm
## face for readouts that carry a lot of text (night market stalls).
static func lacquer_board(canvas: CanvasItem, rect: Rect2, tone: Color) -> void:
	var box := snap_rect(rect)
	# Four posterised bands, lit at the top, so the face is never one flat colour
	# yet stays calm behind text.
	var band := snappedf(box.size.y / 4.0, PIXEL)
	for step in 4:
		var top := box.position.y + band * step
		var height := box.end.y - top if step == 3 else band
		canvas.draw_rect(Rect2(box.position.x, top, box.size.x, height), lighten(tone, 0.08) if step == 0 else (tone if step < 3 else deepen(tone, 0.12)))
	_bevel(canvas, box, lighten(tone, 0.3), deepen(tone, 0.3))
	var inner := box.grow(-6.0)
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, PIXEL)), Color(BRASS, 0.55))
	canvas.draw_rect(Rect2(inner.position.x, inner.end.y - PIXEL, inner.size.x, PIXEL), Color(deepen(BRASS, 0.3), 0.55))
	canvas.draw_rect(Rect2(inner.position, Vector2(PIXEL, inner.size.y)), Color(BRASS, 0.55))
	canvas.draw_rect(Rect2(inner.end.x - PIXEL, inner.position.y, PIXEL, inner.size.y), Color(deepen(BRASS, 0.3), 0.55))
	for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
		rivet(canvas, corner, BRASS)
	_outline(canvas, box, deepen(tone))

## Brushed metal plate with a raised rim and, when there is room, corner rivets.
static func metal_plate(canvas: CanvasItem, rect: Rect2, tone := BRASS, rivets := true) -> void:
	var box := snap_rect(rect)
	_tile(canvas, _metal(tone), box)
	_bevel(canvas, box, lighten(tone, 0.35), deepen(tone, 0.22))
	_outline(canvas, box, deepen(tone))
	if rivets and box.size.x >= 28.0 and box.size.y >= 28.0:
		for corner: Vector2 in [Vector2(8, 8), Vector2(box.size.x - 8, 8), Vector2(8, box.size.y - 8), Vector2(box.size.x - 8, box.size.y - 8)]:
			rivet(canvas, box.position + corner, tone)

static func rivet(canvas: CanvasItem, center: Vector2, tone := BRASS) -> void:
	var at := snap(center) - Vector2(PIXEL, PIXEL)
	canvas.draw_rect(Rect2(at, Vector2(PIXEL * 2, PIXEL * 2)), deepen(tone, 0.3))
	canvas.draw_rect(Rect2(at, Vector2(PIXEL, PIXEL)), lighten(tone, 0.5))

## Twisted rope between two points.
static func rope(canvas: CanvasItem, from: Vector2, to: Vector2, thickness := 6.0, tone := HEMP) -> void:
	_strand(canvas, _rope(tone), from, to, thickness)

## Chain of alternating links between two points.
static func chain(canvas: CanvasItem, from: Vector2, to: Vector2, thickness := 8.0, tone := IRON) -> void:
	_strand(canvas, _chain(tone), from, to, thickness)

## Rounded enamel token (a marble, a button cap, a buoy seen from above).
static func token(canvas: CanvasItem, center: Vector2, radius: float, color: Color, pressed := false) -> void:
	var texture := _token(maxi(3, roundi(radius / PIXEL)), color)
	var at := snap(center) - texture.get_size() * 0.5 + (Vector2(0, PIXEL) if pressed else Vector2.ZERO)
	canvas.draw_texture(texture, at, Color(0.86, 0.86, 0.9) if pressed else Color.WHITE)

## A glass tube filled from the bottom to `fraction`, for meters.
static func gauge(canvas: CanvasItem, rect: Rect2, fraction: float, fill: Color, frame := BRASS) -> void:
	var box := snap_rect(rect)
	canvas.draw_rect(box.grow(PIXEL * 2), deepen(frame))
	canvas.draw_rect(box.grow(PIXEL), frame)
	canvas.draw_rect(Rect2(box.position - Vector2(PIXEL, PIXEL), Vector2(box.size.x + PIXEL * 2, PIXEL)), lighten(frame, 0.4))
	canvas.draw_rect(box, Color("#12303c"))
	var level := snappedf(clampf(fraction, 0.0, 1.0) * box.size.y, PIXEL)
	if level > 0.0:
		var liquid := Rect2(box.position.x, box.end.y - level, box.size.x, level)
		canvas.draw_rect(liquid, fill)
		canvas.draw_rect(Rect2(liquid.position, Vector2(liquid.size.x, PIXEL)), lighten(fill, 0.45))
		canvas.draw_rect(Rect2(liquid.end.x - PIXEL * 2, liquid.position.y, PIXEL * 2, liquid.size.y), deepen(fill, 0.2))
	canvas.draw_rect(Rect2(box.position.x + PIXEL, box.position.y, PIXEL * 2, box.size.y), Color(1, 1, 1, 0.16))

## The same glass meter on its side, filled from the left to `fraction`.
static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, fill: Color, frame := BRASS) -> void:
	var box := snap_rect(rect)
	canvas.draw_rect(box.grow(PIXEL * 2), deepen(frame))
	canvas.draw_rect(box.grow(PIXEL), frame)
	canvas.draw_rect(Rect2(box.position - Vector2(PIXEL, PIXEL), Vector2(box.size.x + PIXEL * 2, PIXEL)), lighten(frame, 0.4))
	canvas.draw_rect(box, Color("#2a1f30"))
	var level := snappedf(clampf(fraction, 0.0, 1.0) * box.size.x, PIXEL)
	if level > 0.0:
		canvas.draw_rect(Rect2(box.position, Vector2(level, box.size.y)), fill)
		canvas.draw_rect(Rect2(box.position, Vector2(level, PIXEL)), lighten(fill, 0.45))
		if box.size.y > PIXEL * 3:
			canvas.draw_rect(Rect2(box.position.x, box.end.y - PIXEL, level, PIXEL), deepen(fill, 0.2))
	canvas.draw_rect(Rect2(box.position.x, box.position.y + PIXEL, box.size.x, PIXEL), Color(1, 1, 1, 0.12))

## Dithered oval where an object touches the ground.
static func contact_shadow(canvas: CanvasItem, center: Vector2, width: float, strength := 0.5) -> void:
	var size := snap(Vector2(width, maxf(PIXEL * 2, width * 0.3)))
	canvas.draw_texture_rect(_blob(), Rect2(snap(center) - size * 0.5, size), false, Color(1, 1, 1, strength))

## Soft ringed oval under a standing figure (smooth, for large sprites).
static func oval_shadow(canvas: CanvasItem, center: Vector2, radii: Vector2, strength := 0.34, shade := SHADOW) -> void:
	for ring in 3:
		var grow := 1.0 - ring * 0.22
		canvas.draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
		canvas.draw_circle(Vector2.ZERO, radii.x * grow, Color(shade, strength * 0.42))
	canvas.draw_set_transform(Vector2.ZERO)

## Shadow a raised block throws down and to the right.
static func block_shadow(canvas: CanvasItem, rect: Rect2, offset := Vector2(4, 6), strength := 0.3) -> void:
	var box := snap_rect(rect)
	canvas.draw_rect(Rect2(box.position + offset + Vector2(PIXEL, 0), box.size - Vector2(PIXEL * 2, 0)), Color(SHADOW, strength))
	canvas.draw_rect(Rect2(box.position + offset + Vector2(0, PIXEL), box.size - Vector2(0, PIXEL * 2)), Color(SHADOW, strength * 0.6))

## Control icon centred on `center`; `scale` is design pixels per icon pixel.
static func icon(canvas: CanvasItem, icon_name: String, center: Vector2, color := Color("#f0f0d8"), scale := 2.0) -> void:
	if not ICONS.has(icon_name):
		return
	var texture := _icon(icon_name)
	var size := texture.get_size() * scale / PIXEL
	var at := snap(center - size * 0.5)
	canvas.draw_texture_rect(texture, Rect2(at + Vector2(0, scale), size), false, Color(SHADOW, 0.55))
	canvas.draw_texture_rect(texture, Rect2(at, size), false, color)

## A physical control key: a wooden cap on a dark lip that sinks when held, with a
## brass edge when it is the active choice. The caller draws the icon and label.
static func key_cap(canvas: CanvasItem, rect: Rect2, held: bool, enabled := true, tone := Color("#2f6470")) -> void:
	var box := snap_rect(rect)
	block_shadow(canvas, box, Vector2(0, 4), 0.35)
	var body := tone if enabled else tone.lerp(Color("#22323a"), 0.7)
	shaded_box(canvas, box, lighten(body, 0.12) if held else body, 8.0, held)
	if held:
		canvas.draw_rect(Rect2(box.position + Vector2(PIXEL, 8.0), Vector2(box.size.x - PIXEL * 2, PIXEL)), Color(BRASS, 0.95))

## A whole control key: cap, icon on the left and a short label. The label keeps
## the caller's font so it follows the player's text settings.
static func control_key(canvas: CanvasItem, rect: Rect2, held: bool, icon_name: String, label: String, font: Font, font_size: int, enabled := true, tone := Color("#2f6470")) -> void:
	key_cap(canvas, rect, held, enabled, tone)
	var sink := Vector2(0, 6.0 if held else 0.0)
	var ink := Color("#ffc66d") if held else (Color("#80e6c2") if enabled else Color("#5d7f86"))
	var text_from := 14.0
	if ICONS.has(icon_name):
		icon(canvas, icon_name, rect.position + Vector2(24, (rect.size.y - 8.0) * 0.5) + sink, ink)
		text_from = 44.0
	var room := rect.size.x - text_from - 6.0
	var size := font_size
	while size > 12 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 1
	canvas.draw_string(font, rect.position + Vector2(text_from, (rect.size.y - 8.0) * 0.5 + size * 0.36) + sink, label, HORIZONTAL_ALIGNMENT_LEFT, room, size, Color("#f0f0d8") if enabled else Color("#8fa6a8"))

## A two-line control key for narrow keys: icon and key name on top, the action
## underneath, both in the caller's font sizes so text stays legible.
static func labelled_key(canvas: CanvasItem, rect: Rect2, held: bool, icon_name: String, key_label: String, action: String, font: Font, key_size: int, action_size: int, enabled := true, tone := Color("#2f6470")) -> void:
	key_cap(canvas, rect, held, enabled, tone)
	var sink := Vector2(0, 6.0 if held else 0.0)
	var room := rect.size.x - 14.0
	var key_from := 10.0
	if ICONS.has(icon_name):
		icon(canvas, icon_name, rect.position + Vector2(18, 16) + sink, Color("#ffc66d") if held else Color("#f0e0b8"))
		key_from = 32.0
	canvas.draw_string(font, rect.position + Vector2(key_from, 22) + sink, key_label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - key_from - 6.0, key_size, Color("#ffc66d") if held else Color("#e8d8b0"))
	canvas.draw_string(font, rect.position + Vector2(8, rect.size.y - 18) + sink, action, HORIZONTAL_ALIGNMENT_LEFT, room, action_size, Color("#f0f0d8") if enabled else Color("#8fa6a8"))

## Skins a Button node as the same physical key: the cap sinks onto its lip and
## shows a brass edge while the button is pressed (a held or chosen toggle), the
## label sinks with it, and an optional icon sits left of the label.
static func skin_key(button: Button, tone := Color("#2f6470"), icon_name := "") -> void:
	var dull := tone.lerp(Color("#2a2a36"), 0.6)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var held := state.ends_with("pressed")
		var style := StyleBoxTexture.new()
		style.texture = _key_skin(dull if state == "disabled" else (lighten(tone, 0.08) if state == "hover" else tone), held)
		style.texture_margin_top = 10.0
		style.texture_margin_bottom = 12.0
		style.texture_margin_left = 6.0
		style.texture_margin_right = 6.0
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		style.content_margin_top = 12.0 if held else 4.0
		style.content_margin_bottom = 6.0 if held else 14.0
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new() if state == "focus" else style)
	if ICONS.has(icon_name):
		button.icon = _icon(icon_name)
		button.add_theme_constant_override("h_separation", 8)
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Color("#f0f0d8"))
	button.add_theme_color_override("icon_pressed_color", Color("#ffc66d"))
	button.add_theme_color_override("icon_hover_pressed_color", Color("#ffc66d"))
	button.add_theme_color_override("icon_disabled_color", Color(0.7, 0.7, 0.72, 0.5))

## 16 x 16 art-pixel cap for skin_key: outline, lit bevel, face, dark lip and a
## soft drop below; the held cap starts three rows lower and carries a brass edge.
static func _key_skin(tone: Color, held: bool) -> ImageTexture:
	return _cached("keyskin:%s:%s" % [tone.to_html(false), held], func() -> Image:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var top := 3 if held else 0
		var lip := 13 if held else 11
		for y in 16:
			for x in 16:
				var edge_x := x == 0 or x == 15
				var color := Color(0, 0, 0, 0)
				if y == 14 or y == 15:
					color = Color(CANDY_SHADOW, 0.32 if y == 14 else 0.16) if x > 0 and x < 15 else color
				elif y < top:
					pass
				elif y == top or y == 13 or edge_x:
					color = deepen(tone) if not ((y == top or y == 13) and edge_x) else Color(0, 0, 0, 0)
				elif y >= lip:
					color = deepen(tone, 0.3)
				elif held and y == top + 1:
					color = BRASS
				elif y == top + 1 or x == 1:
					color = lighten(tone, 0.22)
				elif y == lip - 1 or x == 14:
					color = deepen(tone, 0.16)
				else:
					color = lighten(tone, 0.06) if y < 5 else Pixels.grainy(tone, x, y, 0.1)
				image.set_pixel(x, y, color)
		return image)

# --- baked sprites and surfaces (arcade_pixels.gd textures) --------------------

## Draw a baked sprite so texel (0, 0) of its shape lands on `at` (the bake adds
## a one-texel outline all round).
static func stamp(canvas: CanvasItem, texture: Texture2D, at: Vector2, texel := 4.0, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect(texture, Rect2(at - Vector2.ONE * texel, Vector2(texture.get_size()) * texel), false, tint)

## The shadow a hung or standing baked sprite throws on whatever is behind it.
static func sprite_shadow(canvas: CanvasItem, texture: Texture2D, at: Vector2, offset := Vector2(10, 14), texel := 4.0, strength := 0.3, shade := SHADOW) -> void:
	stamp(canvas, texture, at + offset, texel, Color(shade, strength))

## A baked material (Pixels.surface kinds: lacquer, velvet, enamel, glass,
## paper, key, liquid, groove, pole, photo, planks, planks_v) over `rect`.
static func surface(canvas: CanvasItem, rect: Rect2, kind: String, base: Color, trim := Color(0, 0, 0, 0), texel := 4.0, tint := Color.WHITE) -> void:
	var size := Vector2i(maxi(2, roundi(rect.size.x / texel) - 2), maxi(2, roundi(rect.size.y / texel) - 2))
	canvas.draw_texture_rect(Pixels.surface(kind, size, base, trim), rect, false, tint)

## A chipped gilt frame `border` design pixels wide around `rect`'s edge.
static func gilt_frame(canvas: CanvasItem, rect: Rect2, border: float, base: Color, texel := 4.0, tint := Color.WHITE) -> void:
	var size := Vector2i(maxi(4, roundi(rect.size.x / texel) - 2), maxi(4, roundi(rect.size.y / texel) - 2))
	canvas.draw_texture_rect(Pixels.frame(size, maxi(3, roundi(border / texel) - 1), base), rect, false, tint)

## A tileable material swatch for `fill_polygon`: wood (planks), metal, paper
## (oiled paper with fibres) or cobble (wet stone setts that catch lamp light).
static func material_tile(kind: String, tone: Color) -> ImageTexture:
	match kind:
		"wood":
			return _wood(tone)
		"metal":
			return _metal(tone)
		"paper":
			return _paper(tone)
		"cobble":
			return _cobble(tone)
	push_warning("pixel_props: unknown material tile " + kind)
	return _paper(tone)

## Fills any polygon with a material tile mapped in design pixels, so shapes
## that touch share one continuous grain. The canvas must have texture_repeat
## enabled; `tint` multiplies the swatch (shade a face by darkening it).
static func fill_polygon(canvas: CanvasItem, points: PackedVector2Array, tile: Texture2D, tint := Color.WHITE) -> void:
	var cell := tile.get_size()
	var uvs := PackedVector2Array()
	uvs.resize(points.size())
	for index in points.size():
		uvs[index] = points[index] / cell
	canvas.draw_colored_polygon(points, tint, uvs, tile)

# --- finishing touches ----------------------------------------------------------
# Time-based ones take a phase or elapsed time from the caller's own clock, so
# pausing freezes them; callers skip them under reduced motion.

## A highlight sweeping across something round and shiny; `phase` 0..1.
static func glint(canvas: CanvasItem, center: Vector2, radius: float, phase: float) -> void:
	if phase < 0.0 or phase >= 1.0:
		return
	var across := lerpf(-radius * 1.4, radius * 1.4, phase)
	var step := maxf(2.0, roundf(radius / 6.0))
	var y := -radius
	while y < radius:
		var point := Vector2(across + y * 0.5, y)
		if point.length() < radius * 0.82:
			canvas.draw_rect(Rect2(center + point - Vector2(step, step * 0.5), Vector2(step * 2.0, step)), Color(1, 0.97, 0.86, 0.7))
		y += step

## A slanted band of light crossing `rect` as `phase` runs 0..1, in texel rows.
static func sheen(canvas: CanvasItem, rect: Rect2, phase: float, width: float, alpha := 0.18, slant := 0.6, texel := 4.0) -> void:
	if phase < 0.0 or phase >= 1.0:
		return
	var travel := rect.size.x + rect.size.y * slant + width
	var y := rect.position.y
	while y < rect.end.y:
		var left := rect.position.x - width - rect.size.y * slant + phase * travel + (rect.end.y - y) * slant
		var from := maxf(left, rect.position.x)
		var to := minf(left + width, rect.end.x)
		if to > from:
			canvas.draw_rect(Rect2(from, y, to - from, minf(texel, rect.end.y - y)), Color(1, 0.98, 0.9, alpha))
		y += texel

## Dust or spray kicked up where something lands; `elapsed` counts from impact.
static func dust_puffs(canvas: CanvasItem, at: Vector2, elapsed: float, spread := 60.0, tone := Color(0.9, 0.82, 0.74)) -> void:
	if elapsed < 0.0 or elapsed > 0.5:
		return
	var t := elapsed / 0.5
	for side: float in [-1.0, 1.0]:
		for puff in 3:
			var reach := spread * (0.4 + puff * 0.3) * (1.0 - (1.0 - t) * (1.0 - t))
			var size := roundf((10.0 - puff * 2.0) * (1.0 - t * 0.5))
			var centre := (at + Vector2(side * reach, -puff * 4.0 - 10.0 * t)).round()
			canvas.draw_rect(Rect2(centre - Vector2(size, size * 0.6), Vector2(size * 2.0, size * 1.2)), Color(tone, 0.55 * (1.0 - t)))
			canvas.draw_rect(Rect2(centre - Vector2(size * 0.6, size), Vector2(size * 1.2, size * 0.5)), Color(tone.lightened(0.4), 0.45 * (1.0 - t)))

## Sky or water as posterised bands from `top` to `bottom` instead of one flat
## colour; `ease` > 1 keeps more of the top tone.
static func bands(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, steps := 8, ease := 1.0) -> void:
	var y := rect.position.y
	for band in steps:
		var next := roundf((rect.position.y + rect.size.y * float(band + 1) / steps) / PIXEL) * PIXEL
		canvas.draw_rect(Rect2(rect.position.x, y, rect.size.x, next - y), top.lerp(bottom, pow(float(band) / maxf(1.0, steps - 1.0), ease)))
		y = next

## The planked wood texture wood_panel tiles, for textured polygons (an oval
## tabletop, a slanted board): uvs = points / wood_texture().get_size().
static func wood_texture(tone := OAK, calm := false) -> ImageTexture:
	return _wood(tone, 0.35 if calm else 1.0)

## Neutral rock grain for textured polygons: draw_colored_polygon(points, tone,
## uvs, rock_grain()) with uvs = points / 64 on an item whose texture_repeat is
## enabled. Strata, chips and lit flecks stay at or below white, so `tone` shows.
static func rock_grain() -> ImageTexture:
	return _cached("rock_grain", func() -> Image:
		var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				# Wavy strata (periods divide 32, so the tile repeats cleanly),
				# chipped faces and a few lit flecks; no straight block joints.
				var wave := roundi(2.0 * sin(x * TAU / 32.0) + 1.0 * sin(x * TAU / 16.0 + 1.3))
				var stratum := posmod(y + wave + (y / 16) * 5, 16)
				var value := 0.9
				if stratum == 0:
					value = 0.7
				elif stratum == 1 or stratum == 2:
					value = 1.0
				elif stratum > 11:
					value = 0.84
				if Pixels.noise(x / 2 + (y / 3) * 17, 21) < 0.1:
					value -= 0.1
				elif Pixels.noise(x, y + 90) < 0.04:
					value = 1.0
				image.set_pixel(x, y, Color(value, value, value))
		return image)

## Darkened side edges of `area` keep the eye on the middle.
static func vignette(canvas: CanvasItem, area: Rect2, strength := 0.5, shade := SHADOW) -> void:
	for band in 5:
		var reach := 160.0 - band * 30.0
		var color := Color(shade, strength * 0.2)
		canvas.draw_rect(Rect2(area.position, Vector2(reach, area.size.y)), color)
		canvas.draw_rect(Rect2(area.end.x - reach, area.position.y, reach, area.size.y), color)

# --- shared strokes -------------------------------------------------------------

static func _outline(canvas: CanvasItem, box: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(box.position + Vector2(PIXEL, -PIXEL), Vector2(box.size.x - PIXEL * 2, PIXEL)), color)
	canvas.draw_rect(Rect2(box.position + Vector2(PIXEL, box.size.y), Vector2(box.size.x - PIXEL * 2, PIXEL)), color)
	canvas.draw_rect(Rect2(box.position + Vector2(-PIXEL, PIXEL), Vector2(PIXEL, box.size.y - PIXEL * 2)), color)
	canvas.draw_rect(Rect2(box.position + Vector2(box.size.x, PIXEL), Vector2(PIXEL, box.size.y - PIXEL * 2)), color)
	for corner: Vector2 in [Vector2.ZERO, Vector2(box.size.x - PIXEL, 0), Vector2(0, box.size.y - PIXEL), box.size - Vector2(PIXEL, PIXEL)]:
		canvas.draw_rect(Rect2(box.position + corner, Vector2(PIXEL, PIXEL)), color)

static func _bevel(canvas: CanvasItem, box: Rect2, light: Color, shade: Color) -> void:
	canvas.draw_rect(Rect2(box.position + Vector2(PIXEL, 0), Vector2(box.size.x - PIXEL * 2, PIXEL)), light)
	canvas.draw_rect(Rect2(box.position + Vector2(0, PIXEL), Vector2(PIXEL, box.size.y - PIXEL * 2)), light)
	canvas.draw_rect(Rect2(box.position.x + PIXEL, box.end.y - PIXEL, box.size.x - PIXEL * 2, PIXEL), shade)
	canvas.draw_rect(Rect2(box.end.x - PIXEL, box.position.y + PIXEL, PIXEL, box.size.y - PIXEL * 2), shade)

## Repeats a texture over a rect without relying on the item's repeat setting.
static func _tile(canvas: CanvasItem, texture: Texture2D, box: Rect2) -> void:
	var cell := texture.get_size()
	var y := 0.0
	while y < box.size.y:
		var height := minf(cell.y, box.size.y - y)
		var x := 0.0
		while x < box.size.x:
			var width := minf(cell.x, box.size.x - x)
			canvas.draw_texture_rect_region(texture, Rect2(box.position + Vector2(x, y), Vector2(width, height)), Rect2(0, 0, width, height))
			x += cell.x
		y += cell.y

static func _strand(canvas: CanvasItem, texture: Texture2D, from: Vector2, to: Vector2, thickness: float) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var cell := texture.get_size()
	var scale := thickness / cell.y
	canvas.draw_set_transform(from, from.angle_to_point(to), Vector2(scale, scale))
	_tile(canvas, texture, Rect2(0, -cell.y * 0.5, length / scale, cell.y))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- generated textures (cached in arcade_pixels.gd) ------------------------------

## Builds an art-pixel image once and enlarges it to design pixels.
static func _cached(key: String, build: Callable) -> ImageTexture:
	return Pixels.cached("props|" + key, func() -> Image:
		var image: Image = build.call()
		image.resize(image.get_width() * int(PIXEL), image.get_height() * int(PIXEL), Image.INTERPOLATE_NEAREST)
		return image)

static func _wood(tone: Color, grain := 1.0) -> ImageTexture:
	return _cached("wood:%s:%.2f" % [tone.to_html(false), grain], func() -> Image:
		var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			var plank := y / 8
			var row := y % 8
			var board := tone.lerp(lighten(tone, 0.3) if Pixels.noise(plank, 7) > 0.5 else deepen(tone, 0.2), Pixels.noise(plank, 3) * 0.45 * grain)
			var joint := int(Pixels.noise(plank, 11) * 60.0) + 2
			for x in 64:
				var color := board
				if row == 7:
					color = deepen(tone, 0.42 * grain)
				elif row == 0:
					color = lighten(board, 0.16 * grain)
				elif x == joint:
					color = deepen(tone, 0.36 * grain)
				elif Pixels.noise(x / 5 + plank * 17, row) < 0.16 * grain:
					color = deepen(board, 0.13)
				elif Pixels.noise(x / 7 + plank * 29, row + 40) < 0.07 * grain:
					color = lighten(board, 0.14)
				image.set_pixel(x, y, color)
		return image)

static func _metal(tone: Color) -> ImageTexture:
	return _cached("metal:" + tone.to_html(false), func() -> Image:
		var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			var streak := tone.lerp(lighten(tone, 0.3) if Pixels.noise(y, 5) > 0.55 else deepen(tone, 0.18), Pixels.noise(y, 9) * 0.35)
			for x in 32:
				var color := streak
				if Pixels.noise(x / 3, y + 20) < 0.08:
					color = lighten(streak, 0.2)
				elif Pixels.noise(x, y + 60) < 0.03:
					color = deepen(streak, 0.2)
				image.set_pixel(x, y, color)
		return image)

static func _rope(tone: Color) -> ImageTexture:
	return _cached("rope:" + tone.to_html(false), func() -> Image:
		var image := Image.create(6, 4, false, Image.FORMAT_RGBA8)
		var rows: Array[Color] = [lighten(tone, 0.35), tone, deepen(tone, 0.16), deepen(tone, 0.34)]
		for y in 4:
			for x in 6:
				image.set_pixel(x, y, deepen(tone, 0.42) if (x + y) % 3 == 0 and y > 0 and y < 3 else rows[y])
		return image)

static func _chain(tone: Color) -> ImageTexture:
	return _cached("chain:" + tone.to_html(false), func() -> Image:
		var rows := ["..####....", ".#....#.##", "#......#..", ".#....#.##", "..####...."]
		var image := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in 5:
			for x in 10:
				if rows[y][x] == "#":
					image.set_pixel(x, y, lighten(tone, 0.4) if y < 2 else (tone if y < 4 else deepen(tone, 0.3)))
		return image)

static func _blob() -> ImageTexture:
	return _cached("blob", func() -> Image:
		var image := Image.create(32, 12, false, Image.FORMAT_RGBA8)
		for y in 12:
			for x in 32:
				var reach := Vector2((x - 15.5) / 16.0, (y - 5.5) / 6.0).length()
				# Ordered dither keeps the falloff in whole pixels.
				var alpha := clampf(1.15 - reach, 0.0, 1.0) * 0.9
				if alpha > 0.25 + (0.3 if (x + y) % 2 == 0 else 0.0) * (1.0 - alpha):
					image.set_pixel(x, y, Color(SHADOW, minf(0.8, alpha)))
		return image)

static func _token(radius: int, color: Color) -> ImageTexture:
	return _cached("token:%d:%s" % [radius, color.to_html(false)], func() -> Image:
		var size := radius * 2 + 2
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var middle := Vector2(size * 0.5 - 0.5, size * 0.5 - 0.5)
		for y in size:
			for x in size:
				var offset := Vector2(x, y) - middle
				var reach := offset.length()
				if reach > radius + 0.4:
					continue
				var facing := offset.dot(Vector2(-0.6, -0.8)) / float(radius)
				var shade := color
				if reach > radius - 0.9:
					shade = deepen(color)
				elif (offset - Vector2(-0.34, -0.4) * radius).length() < maxf(1.0, radius * 0.16):
					shade = lighten(color, 0.75)
				elif facing > 0.3:
					shade = lighten(color, 0.3)
				elif facing < -0.45:
					shade = deepen(color, 0.24)
				image.set_pixel(x, y, shade)
		return image)

static func _icon(icon_name: String) -> ImageTexture:
	return _cached("icon:" + icon_name, func() -> Image:
		var rows: Array = ICONS[icon_name]
		var image := Image.create(9, 9, false, Image.FORMAT_RGBA8)
		for y in 9:
			for x in 9:
				if rows[y][x] == "#":
					image.set_pixel(x, y, Color.WHITE)
		return image)

static func _paper(tone: Color) -> ImageTexture:
	return _cached("paper:" + tone.to_html(false), func() -> Image:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 48:
				# Long thin fibres run across the sheet; a fine tooth fills between.
				var color := tone.lerp(lighten(tone, 0.1), Pixels.noise(x, y, 4) * 0.4)
				var fibre := Pixels.noise((x + y * 3) / 7, y, 9)
				if fibre > 0.96:
					color = deepen(tone, 0.08)
				elif fibre < 0.03:
					color = lighten(tone, 0.16)
				image.set_pixel(x, y, color)
		return image)

## Staggered rounded setts with dark joints, a lit top-left rim on each stone
## and the odd warm puddle glint.
static func _cobble(tone: Color) -> ImageTexture:
	return _cached("cobble:" + tone.to_html(false), func() -> Image:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			var row := y / 8
			var shift := 6 if row % 2 == 1 else 0
			for x in 48:
				var column := (x + shift) / 12
				var local := Vector2i((x + shift) % 12, y % 8)
				var stone := tone.lerp(deepen(tone, 0.25) if Pixels.noise(column, row, 5) > 0.5 else lighten(tone, 0.1), Pixels.noise(column, row, 8) * 0.55)
				var color := stone
				if local.y == 7 or local.x == 11:
					color = deepen(tone, 0.5)
				elif (local.y == 6 and local.x > 0) or local.x == 10:
					color = deepen(stone, 0.2)
				elif local.y == 0 or local.x == 0:
					color = lighten(stone, 0.18)
				elif Pixels.noise(x, y, 17) < 0.05:
					color = deepen(stone, 0.12)
				elif local.y == 2 and local.x > 2 and local.x < 6 and Pixels.noise(column, row, 21) > 0.62:
					color = lighten(stone, 0.4).lerp(Color("#ffd49a"), 0.35)
				image.set_pixel(x, y, color)
		return image)
