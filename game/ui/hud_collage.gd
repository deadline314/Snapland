extends Control
## Collage art behind one group of the minigame HUD: the title is a luggage tag
## with the round's medal pinned on, score and time are ticket stubs, the
## feedback line is a taped note.
##
## The host keeps its labels, layout, tooltips and hit areas; the art hides the
## labels' ink and prints the same words on the tilted paper. Shapes are cached
## per size, so the piece only redraws when its text, geometry or one of its
## short animations (all under half a second) changes.

const Kit = preload("res://game/ui/collage_kit.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Medal = preload("res://game/ui/arcade_medal.gd")

const ENTER_SECONDS := 0.32
const STAMP_SECONDS := 0.4
const SHAKE_SECONDS := 0.3
const BUMP_SECONDS := 0.28
## Width of the coloured band at the tag's eyelet end.
const TAG_BAND := 30.0
## Room the pinned medal takes at the tag's right end.
const MEDAL_ROOM := 44.0
const NOTE := Color("#17414b")
## The clock's last seconds: pink paper and deep red print (7.9:1), a red band
## under a cream caption (5.5:1).
const ALARM_PAPER := Color("#ffd9cf")
const ALARM_BAND := Color("#b8322a")
const ALARM_CAPTION := Kit.CREAM
const ALARM_INK := Color("#7a1f1a")
## Ink per print role; every pair reads at 4.5:1 or better on its paper.
const CAPTION_INK := Kit.INK
const DIGIT_INK := Kit.INK
const STAMP_INK := Kit.INK_CORAL

var kind := "title"
var tilt := -3.0
var swatch := Paper.CORAL
## Labels this piece prints, keyed by role (title, progress, score_caption,
## score, time_caption, time, badge).
var prints: Dictionary = {}
## For a ticket: the score and time groups the stubs wrap.
var score_group: Control
var time_group: Control
## -1 hides the medal pin; 0 is an empty slot; 1..3 bronze, silver, gold.
var medal := -1
var alarm := false
var enter := 1.0:
	set(value):
		enter = value
		modulate.a = clampf(value * 2.0, 0.0, 1.0)
		queue_redraw()
var bump := 0.0:
	set(value):
		bump = value
		queue_redraw()
var shake := 0.0:
	set(value):
		shake = value
		queue_redraw()
var stamp := 0.0:
	set(value):
		stamp = value
		queue_redraw()
var _shapes: Dictionary = {}
var _closed: Dictionary = {}
var _fitted: Dictionary = {}


## Put a piece of `kind` art behind `host`, printing `labels` (role -> Label).
static func attach(host: Control, art_kind: String, angle: float, labels: Dictionary = {}, delay := 0.0) -> Control:
	var piece: Control = (load("res://game/ui/hud_collage.gd") as GDScript).new()
	piece.name = "CollageArt"
	piece.kind = art_kind
	piece.tilt = angle
	piece.prints = labels
	for label: Label in labels.values():
		label.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	host.add_child(piece)
	host.move_child(piece, 0)
	if host is Container:
		(host as Container).sort_children.connect(piece.queue_redraw)
	host.resized.connect(piece.queue_redraw)
	PaperMotion.ease_property(piece, &"enter", 1.0, ENTER_SECONDS, delay, Tween.TRANS_BACK, 0.0)
	return piece


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The score went up: the stub springs.
func bump_score() -> void:
	PaperMotion.swing(self, &"bump", 1.0, BUMP_SECONDS)


## Last seconds of the round: the clock stub turns red; each new second shakes it.
func set_alarm(value: bool, new_second: bool) -> void:
	if alarm != value:
		alarm = value
		queue_redraw()
	if alarm and new_second:
		PaperMotion.swing(self, &"shake", 1.0, SHAKE_SECONDS)


## A newly earned medal is stamped down onto the tag.
func set_medal(value: int) -> void:
	if value == medal:
		return
	var earned := value > medal and value > 0 and medal >= 0
	medal = value
	queue_redraw()
	if earned:
		PaperMotion.ease_property(self, &"stamp", 0.0, STAMP_SECONDS, 0.0, Tween.TRANS_BACK, 1.0)


func _draw() -> void:
	var host := get_parent_control()
	if host == null:
		return
	# Draw in host space: a container fits this piece to its content box only.
	var body := Rect2(-position, host.size)
	match kind:
		"title":
			_draw_title(body)
		"ticket":
			_draw_ticket()
		"note":
			_draw_note(body)
	draw_set_transform(Vector2.ZERO)


func _drop() -> Vector2:
	return Vector2(0.0, -46.0 * (1.0 - enter))


func _swing() -> float:
	return deg_to_rad(9.0 * (1.0 - enter))


# --- title tag ------------------------------------------------------------

func _draw_title(host_rect: Rect2) -> void:
	# The tag is cut to its words, so a short title leaves more of the play area.
	var words := maxf(_text_width("title"), _text_width("progress"))
	var reach := position.x + words + 22.0 + (MEDAL_ROOM if medal >= 0 else 0.0)
	var body := Rect2(host_rect.position, Vector2(minf(host_rect.size.x, maxf(180.0, ceilf(reach / 4.0) * 4.0)), host_rect.size.y))
	var pivot := body.get_center()
	var angle := deg_to_rad(tilt) + _swing()
	var local := Rect2(-body.size * 0.5, body.size)
	var tag: PackedVector2Array = _shape("tag", local.size, func() -> PackedVector2Array: return tag_shape(local, 12.0, 23, false))
	_paper(tag, pivot + _drop(), angle, Kit.CREAM)
	# Coloured band, eyelet and a loop of string at the hanging end.
	draw_set_transform(pivot + _drop(), angle)
	# The host's text margin leaves room for the band (narrower when compact).
	var band_width := maxf(10.0, position.x - 10.0)
	var band: PackedVector2Array = _shape("tag_band", local.size + Vector2(band_width, 0), func() -> PackedVector2Array: return tag_shape(Rect2(local.position, Vector2(band_width, local.size.y)), 12.0, 23, false, true))
	draw_colored_polygon(band, swatch)
	Kit.fill(self, band, Kit.halftone(1), Color(Props.deepen(swatch, 0.4), 0.45))
	var eyelet := Vector2(local.position.x + maxf(9.0, band_width * 0.5), 0.0)
	for knot in 6:
		draw_rect(Rect2(eyelet + Vector2(-6.0 - knot * 4.0, -4.0 - knot * 5.0), Vector2(4, 3)), Props.HEMP)
	_disc(eyelet, 6.0, Props.BRASS)
	_disc(eyelet, 3.0, Kit.INK)
	_print("title", DIGIT_INK, pivot)
	_print("progress", Kit.INK_TEAL, pivot)
	if medal >= 0:
		_draw_medal(Vector2(local.end.x - MEDAL_ROOM * 0.5 - 4.0, 4.0), pivot, angle)
	draw_set_transform(Vector2.ZERO)


func _draw_medal(at: Vector2, pivot: Vector2, angle: float) -> void:
	var centre := pivot + _drop() + at.rotated(angle)
	if medal == 0:
		# An empty slot waiting for the first medal: a faint dashed ring.
		draw_set_transform(centre, angle)
		for dash in 10:
			draw_arc(Vector2.ZERO, 13.0, dash * TAU / 10.0, dash * TAU / 10.0 + 0.36, 3, Color(Kit.INK, 0.4), 2.0)
		return
	# Stamped down: big, turned and inky first, then settled under its pin.
	var grow := 1.0 + 0.9 * stamp
	draw_set_transform(centre, angle * 0.4 - 0.5 * stamp, Vector2(grow, grow))
	Medal.paint(self, Vector2(0, 6), 2.0, medal)
	_disc(Vector2(0, -21), 4.0, Kit.INK_CORAL)
	_disc(Vector2(-1, -22), 2.0, Paper.CORAL)
	if stamp > 0.02:
		draw_set_transform(centre, 0.0)
		draw_arc(Vector2(0, 4), 18.0 + 10.0 * (1.0 - stamp), 0.0, TAU, 20, Color(Kit.INK_CORAL, 0.7 * stamp), 3.0)


# --- score and time stubs ---------------------------------------------------

func _draw_ticket() -> void:
	var score_rect := _union(["score_caption", "score"]).grow_individual(10, 6, 10, 6)
	var time_rect := _union(["time_caption", "time"]).grow_individual(10, 6, 8, 6)
	if score_rect.size.x > 20.0:
		var pivot := score_rect.get_center()
		var angle := deg_to_rad(tilt + 4.0 * bump) + _swing()
		var grow := 1.0 + 0.14 * bump
		var local := Rect2(-score_rect.size * 0.5, score_rect.size)
		var stub: PackedVector2Array = _shape("score", local.size, func() -> PackedVector2Array: return stub_shape(local, 7.0))
		_paper(stub, pivot + _drop(), angle, Kit.CREAM, Vector2(grow, grow))
		_caption_band("score_caption", local, pivot, angle, Vector2(grow, grow), Paper.CORAL)
		_print("score_caption", CAPTION_INK, pivot)
		_print("score", DIGIT_INK, pivot)
	if time_rect.size.x > 20.0:
		var pivot := time_rect.get_center() + Vector2(3.0 * shake, 0.0)
		var angle := deg_to_rad(-tilt + 6.0 * shake) + _swing()
		var local := Rect2(-time_rect.size * 0.5, time_rect.size)
		var tag: PackedVector2Array = _shape("time", local.size, func() -> PackedVector2Array: return tag_shape(local, 10.0, 31, true))
		_paper(tag, pivot + _drop(), angle, ALARM_PAPER if alarm else Kit.CREAM)
		_caption_band("time_caption", local, pivot, angle, Vector2.ONE, ALARM_BAND if alarm else Kit.SEA)
		_print("time_caption", ALARM_CAPTION if alarm else CAPTION_INK, pivot)
		_print("time", ALARM_INK if alarm else DIGIT_INK, pivot)
	var badge: Label = prints.get("badge")
	if badge != null and badge.is_visible_in_tree() and not badge.text.is_empty():
		# The practice/assist mark: a red rubber stamp on a scrap of paper.
		var line := _rect_of(badge)
		var words := _text_width("badge")
		var rect := Rect2(line.position.x + (line.size.x - words) * 0.5, line.position.y, words, line.size.y).grow_individual(10, 2, 10, 3)
		var pivot := rect.get_center()
		var angle := deg_to_rad(2.0) + _swing()
		var local := Rect2(-rect.size * 0.5, rect.size)
		var scrap: PackedVector2Array = _shape("badge", local.size, func() -> PackedVector2Array: return Kit.torn(local, 37, 1.5, 7.0))
		_paper(scrap, pivot + _drop(), angle, Kit.CREAM)
		draw_set_transform(pivot + _drop(), angle)
		draw_rect(local.grow(-3.0), Color(STAMP_INK, 0.85), false, 2.0)
		_print("badge", STAMP_INK, pivot)


## The caption end of a stub in a colour band (left of the caption's right edge).
func _caption_band(role: String, local: Rect2, pivot: Vector2, angle: float, grow: Vector2, tone: Color) -> void:
	var caption: Label = prints.get(role)
	var reach := 8.0
	if caption != null and caption.is_visible_in_tree():
		# The band stops just past the caption, short of the digits beside it.
		reach = _rect_of(caption).end.x - pivot.x - local.position.x + 1.0
	draw_set_transform(pivot + _drop(), angle, grow)
	var band := Rect2(local.position + Vector2(2, 2), Vector2(reach, local.size.y - 4.0))
	draw_rect(band, tone)
	draw_texture_rect(Kit.halftone(0), band, true, Color(Props.deepen(tone, 0.4), 0.4))
	# A torn-off perforation where the band meets the paper.
	var y := band.position.y + 2.0
	while y < band.end.y - 2.0:
		draw_rect(Rect2(band.end.x + 1.0, y, 2, 2), Color(Kit.INK, 0.4))
		y += 5.0


# --- feedback note -------------------------------------------------------

func _draw_note(body: Rect2) -> void:
	var pivot := body.get_center()
	var angle := deg_to_rad(tilt)
	var local := Rect2(-body.size * 0.5, body.size)
	var note: PackedVector2Array = _shape("note", local.size, func() -> PackedVector2Array: return Kit.torn(local, 41, 2.0, 9.0))
	_paper(note, pivot, angle, NOTE, Vector2.ONE, Paper.OUTLINE)
	draw_set_transform(Vector2.ZERO)
	Kit.tape(self, pivot + Vector2(0, local.position.y + 1.0).rotated(angle), minf(64.0, body.size.x * 0.3), angle - 0.08)


# --- shared --------------------------------------------------------------

## Shadow, paper grain and a darker cut edge for one shape at `centre`.
func _paper(points: PackedVector2Array, centre: Vector2, angle: float, tone: Color, grow := Vector2.ONE, edge := Color(0, 0, 0, 0)) -> void:
	draw_set_transform(centre + Vector2(5, 7), angle, grow)
	draw_colored_polygon(points, Color(Paper.SHADOW, 0.5))
	draw_set_transform(centre, angle, grow)
	Kit.fill(self, points, Props.material_tile("paper", tone), Color.WHITE)
	# One closed line (cached with its shape) draws the edge in a single call.
	if not _closed.has(points):
		var closed := points.duplicate()
		closed.append(points[0])
		_closed[points] = closed
	draw_polyline(_closed[points], edge if edge.a > 0.0 else Props.deepen(tone, 0.55), 2.0)


## Print a label's text where its layout put it, in the current paper's frame.
func _print(role: String, ink: Color, pivot: Vector2) -> void:
	var label: Label = prints.get(role)
	if label == null or not label.is_visible_in_tree() or label.text.is_empty():
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var rect := _rect_of(label)
	rect.position -= pivot
	var shown := _fit_text(label.text, font, font_size, rect.size.x)
	var width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var align := 0.5 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else (1.0 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	var baseline := rect.position.y + (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * align, baseline), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## How wide a label's text prints (never wider than the label).
func _text_width(role: String) -> float:
	var label: Label = prints.get(role)
	if label == null or not label.is_visible_in_tree():
		return 0.0
	return minf(label.size.x, label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x)


## The text a trimmed label shows (with an ellipsis), remembered per width.
func _fit_text(text: String, font: Font, font_size: int, room: float) -> String:
	var key := "%s|%d|%d" % [text, font_size, int(room)]
	if _fitted.has(key):
		return _fitted[key]
	var shown := text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room + 0.5:
		var keep := text.length()
		while keep > 0 and font.get_string_size(text.left(keep) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
			keep -= 1
		shown = text.left(keep) + "…"
	if _fitted.size() > 16:
		_fitted.clear()
	_fitted[key] = shown
	return shown


## A label's (or group's) rectangle in this piece's space.
func _rect_of(node: Control) -> Rect2:
	var at := Vector2.ZERO
	var walk := node
	var host := get_parent_control()
	while walk != null and walk != host:
		at += walk.position
		walk = walk.get_parent_control()
	return Rect2(at - position, node.size)


func _union(roles: Array) -> Rect2:
	var merged := Rect2()
	for role: String in roles:
		var label: Label = prints.get(role)
		if label == null or not label.is_visible_in_tree():
			continue
		var rect := _rect_of(label)
		merged = rect if merged.size == Vector2.ZERO else merged.merge(rect)
	return merged


## Shape `shape_name` at size `extent`, built once by `build`.
func _shape(shape_name: String, extent: Vector2, build: Callable) -> PackedVector2Array:
	var key := "%s|%s" % [shape_name, str(extent)]
	if not _shapes.has(key):
		if _shapes.size() > 24:
			_shapes.clear()
			_closed.clear()
		_shapes[key] = build.call()
	return _shapes[key]


func _disc(centre: Vector2, radius: float, color: Color) -> void:
	draw_rect(Rect2(centre - Vector2(radius, radius * 0.5), Vector2(radius * 2.0, radius)), color)
	draw_rect(Rect2(centre - Vector2(radius * 0.5, radius), Vector2(radius, radius * 2.0)), color)


## Luggage tag: chamfered corners at the eyelet end, a torn far edge. `flip`
## puts the eyelet on the right; `band_only` keeps the far edge straight.
static func tag_shape(rect: Rect2, cut: float, salt: int, flip: bool, band_only := false) -> PackedVector2Array:
	var points := PackedVector2Array([rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y)])
	var steps := maxi(2, int(rect.size.y / 6.0))
	for step in range(1, steps):
		var jitter := 0.0 if band_only else (Kit.Pixels.noise(step, 5, salt) - 0.5) * 6.0
		points.append(Vector2(rect.end.x + jitter, rect.position.y + rect.size.y * step / steps))
	points.append(rect.end)
	points.append(Vector2(rect.position.x + cut, rect.end.y))
	points.append(Vector2(rect.position.x, rect.end.y - cut))
	points.append(Vector2(rect.position.x, rect.position.y + cut))
	if flip:
		var mirror := rect.position.x + rect.end.x
		for index in points.size():
			points[index].x = mirror - points[index].x
		points.reverse()
	return points


## Ticket stub: straight edges with a half-moon notch bitten from each side.
static func stub_shape(rect: Rect2, notch: float) -> PackedVector2Array:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	var middle := rect.get_center().y
	for step in 7:
		var turn := PI * 0.5 - PI * step / 6.0
		points.append(Vector2(rect.end.x - cos(turn) * notch, middle - sin(turn) * notch))
	points.append(rect.end)
	points.append(Vector2(rect.position.x, rect.end.y))
	for step in 7:
		var turn := -PI * 0.5 + PI * step / 6.0
		points.append(Vector2(rect.position.x + cos(turn) * notch, middle - sin(turn) * notch))
	return points
