extends RefCounted
## Collage layer for the main menus: options are travel keepsakes (luggage tags,
## ticket stubs, postage stamps, taped notes and photos) slapped onto a journal
## sheet at small angles, under a huge stamped headline.
##
## Rules this layer keeps:
## * Hit areas stay the real, axis-aligned Buttons that the menus already lay
##   out; the art is a child `Item` drawn a little larger than its button, so
##   tilted paper never shrinks what can be clicked.
## * Items draw through draw_set_transform only, so containers never fight the
##   tilt, and an item that is not animating costs no redraws.
## * Tilt is small (under 3 degrees) and the focused item straightens, lifts and
##   gains a brass rim, so the active choice always reads level and obvious.
## * Paper grain and halftone tiles are generated once (pixel_props and
##   arcade_pixels caches); motion goes through paper_motion, so reduced motion
##   and headless runs show the settled layout at once.

const Paper = preload("res://game/ui/paper_ui.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

## Menu kinds the shared modal shell dresses as a collage.
const KINDS := ["pause", "ticket", "album", "result"]
const CREAM := Color("#f6ecd0")
const INK := Color("#12303b")
const RIM := Color("#ffc66d")
const SEA := Color("#6fc7b7")
const NIGHT_SHEET := Color("#14323d")
const MARKET_SHEET := Color("#231d3b")
## Park palette swatches, one per option in reading order.
const SWATCHES := [Color("#2f9a8d"), Color("#f08f73"), Color("#dfa458"), Color("#4f9fc4"), Color("#8a5a86"), Color("#7cc46a")]
const TILTS := [-2.6, 1.8, -1.3, 2.5, -2.1, 1.1, 2.8, -2.4, 1.5, -0.9]
## Paper stocks the keepsakes are cut from; INK reads above 9:1 on each.
const PAPERS := [Color("#f6ecd0"), Color("#fbf7ec"), Color("#ecd5a4"), Color("#f4ddd2"), Color("#e4efe0")]
## Ink that stays readable on cream paper (all at or above 4.5:1).
const INK_TEAL := Color("#1d5a5e")
const INK_CORAL := Color("#8d3c33")
const INK_BRASS := Color("#6e4614")

const FLY_SECONDS := 0.3
const LIFT_SECONDS := 0.14


static func swatch(index: int) -> Color:
	return SWATCHES[posmod(index, SWATCHES.size())]


static func tilt(index: int) -> float:
	return TILTS[posmod(index, TILTS.size())]


## Dress a laid-out Button as a keepsake. `kind`: tag, stub or stamp. The button
## keeps its text (tests, tooltips, accessibility); only its own drawing hides.
static func dress(button: Button, kind: String, index: int, icon_name := "", tone := Color(0, 0, 0, 0)) -> Item:
	var item := Item.new()
	item.name = "CollageArt"
	item.kind = kind
	item.icon_name = icon_name
	item.swatch = tone if tone.a > 0.0 else swatch(index)
	item.tilt = tilt(index)
	item.salt = index * 7 + 3
	item.paper = PAPERS[posmod(index * 3 + 1, PAPERS.size())]
	# Edges stick out by uneven amounts, so the column never lines up like a grid.
	item.reach = Vector2(4.0 + roundf(Pixels.noise(index, 2, 41) * 6.0) * 2.0, 4.0 + roundf(Pixels.noise(index, 3, 43) * 5.0) * 2.0)
	item.button = button
	var face := StyleBoxEmpty.new()
	item.face = face
	item._fit_face()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state, face)
	for ink in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(ink, Color(0, 0, 0, 0))
	button.add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_entered.connect(item._set_hovered.bind(true))
	button.mouse_exited.connect(item._set_hovered.bind(false))
	button.focus_entered.connect(item._set_focused.bind(true))
	button.focus_exited.connect(item._set_focused.bind(false))
	button.button_down.connect(item._stamp)
	button.resized.connect(item.queue_redraw)
	button.theme_changed.connect(item._fit_face)
	item.fly_in(PaperMotion.stagger(index))
	return item


## A decoration drawn behind `host` (a taped note under a panel, a photo frame
## behind a portrait). It fills the host and bleeds `bleed` pixels past it.
static func backing(host: Control, kind: String, index := 0, tone := CREAM, bleed := 0.0) -> Item:
	var item := Item.new()
	item.name = "CollageBacking"
	item.kind = kind
	item.swatch = tone
	item.tilt = tilt(index) * 0.7
	item.salt = index * 11 + 5
	item.bleed = bleed
	item.show_behind_parent = true
	host.add_child(item)
	host.move_child(item, 0)
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.fly_in(PaperMotion.stagger(index))
	return item


## Turn a Label into a huge stamped headline. The label keeps its text and
## layout height; the art draws the last " · " part big and the rest, plus
## `eyebrow`, as small stickers.
static func headline(label: Label, eyebrow: Label, market := false) -> Item:
	var item := Item.new()
	item.name = "CollageHeadline"
	item.kind = "headline"
	var parts := label.text.split(" · ")
	item.text = parts[parts.size() - 1].strip_edges()
	item.note = parts[0].strip_edges() if parts.size() > 1 else ""
	item.caption = eyebrow.text if eyebrow != null else ""
	item.swatch = Color("#c26a8a") if market else Color("#f08f73")
	item.tilt = -4.0
	item.salt = 17
	item.label = label
	label.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	if eyebrow != null:
		eyebrow.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	label.add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.resized.connect(item.queue_redraw)
	item.fly_in(0.04)
	return item


## The journal sheet behind a whole menu: torn edge, halftone wash, washi tape.
static func sheet(panel: PanelContainer, market := false) -> Item:
	var face := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", face)
	var item := Item.new()
	item.name = "CollageSheet"
	item.kind = "sheet"
	item.swatch = MARKET_SHEET if market else NIGHT_SHEET
	item.salt = 29
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(item)
	panel.move_child(item, 0)
	return item


## Halftone dots, `level` 0 (fine) to 3 (heavy), one cached 8 px tile each.
static func halftone(level: int) -> ImageTexture:
	var radius: float = [0.9, 1.4, 2.0, 2.7][clampi(level, 0, 3)]
	return Pixels.cached("collage|dots:%d" % level, func() -> Image:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				# Two dots per tile on a diagonal grid, like a print screen.
				var a := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(2, 2))
				var b := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(6, 6))
				if minf(a, b) <= radius:
					image.set_pixel(x, y, Color.WHITE)
		return image)


## Rectangle outline with a hand-torn edge, rounded to the 2 px art grid.
static func torn(rect: Rect2, salt: int, depth := 2.0, step := 6.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side in 4:
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[(side + 1) % 4]
		var count := maxi(1, int(from.distance_to(to) / step))
		var outward := (to - from).normalized().orthogonal()
		for step_index in count:
			var jitter := (Pixels.noise(step_index, side, salt) - 0.5) * 2.0 * depth
			points.append(Props.snap(from.lerp(to, float(step_index) / count) + outward * jitter))
	return points


## Postage stamp: a zigzag perforated edge all round.
static func stamp_shape(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side in 4:
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[(side + 1) % 4]
		var count := maxi(2, int(from.distance_to(to) / 8.0))
		var inward := -(to - from).normalized().orthogonal()
		for step_index in count:
			var along := from.lerp(to, float(step_index) / count)
			points.append(along + (inward * 3.0 if step_index % 2 == 1 else Vector2.ZERO))
	return points


## Spiky burst behind a headline.
static func burst_shape(center: Vector2, radii: Vector2, spikes: int, salt: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in spikes * 2:
		var angle := TAU * index / (spikes * 2)
		var reach := 1.0 if index % 2 == 0 else 0.62 + Pixels.noise(index, 1, salt) * 0.14
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * reach)
	return points


static func fill(canvas: CanvasItem, points: PackedVector2Array, tile: Texture2D, tint: Color) -> void:
	Props.fill_polygon(canvas, points, tile, tint)


static func outline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width := 2.0) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, color, width)


## Strip of washi tape, centred on `at`, `length` long, tilted by `angle`.
static func tape(canvas: CanvasItem, at: Vector2, length: float, angle: float, tone := Color(0.98, 0.93, 0.78, 0.78)) -> void:
	canvas.draw_set_transform(at, angle)
	var strip := Rect2(-length * 0.5, -7.0, length, 14.0)
	var points := PackedVector2Array()
	for step in 5:
		points.append(Vector2(strip.position.x + (2.0 if step % 2 == 1 else 0.0), strip.position.y + step * 3.5))
	for step in 5:
		points.append(Vector2(strip.end.x - (2.0 if step % 2 == 0 else 0.0), strip.end.y - step * 3.5))
	canvas.draw_colored_polygon(points, tone)
	canvas.draw_rect(Rect2(strip.position.x + 3, -2, length - 6, 2), Color(1, 1, 1, 0.35))
	canvas.draw_set_transform(Vector2.ZERO)


## One piece of collage art. Everything is drawn from `_draw` through a single
## transform composed of the resting tilt and four animated values.
class Item extends Control:
	const Kit = preload("res://game/ui/collage_kit.gd")

	var kind := "tag"
	var text := ""
	var note := ""
	var caption := ""
	var icon_name := ""
	var swatch := Color("#2f9a8d")
	var paper := CREAM
	## How far the paper reaches past the button's left and right edges.
	var reach := Vector2(4, 4)
	var tilt := 0.0
	var salt := 0
	var bleed := 0.0
	var button: Button
	var label: Label
	var face: StyleBoxEmpty
	var focused := false
	var hovered := false
	## A chosen tab sits level and carries a cancellation mark.
	var chosen := false
	## 0 = still off to the side, 1 = settled; overshoots past 1 on the way in.
	var enter := 1.0:
		set(value):
			enter = value
			modulate.a = clampf(value * 1.8, 0.0, 1.0)
			queue_redraw()
	## 0 = resting, 1 = lifted, straightened and enlarged (hover / focus).
	var lift := 0.0:
		set(value):
			lift = value
			queue_redraw()
	var wiggle := 0.0:
		set(value):
			wiggle = value
			queue_redraw()
	var squash := 0.0:
		set(value):
			squash = value
			queue_redraw()
	## Remaining strength of the ink stamp and age of the dust after a press.
	var ink := 0.0:
		set(value):
			ink = value
			queue_redraw()
	var dust := 1.0:
		set(value):
			dust = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	## Band, icon and margins follow the adapted text size, so compact windows
	## and large text keep the same proportions.
	func unit() -> float:
		if button == null:
			return 1.0
		return clampf(button.get_theme_font_size("font_size") / 20.0, 1.0, 2.5)

	func _fit_face() -> void:
		if face == null:
			return
		var k := unit()
		var left := roundf((62.0 if kind == "tag" else (56.0 if kind == "stub" else 22.0)) * k)
		# Writing a margin re-themes the button, which calls back here: only
		# write when the value really changes.
		if is_equal_approx(face.content_margin_left, left):
			return
		face.content_margin_left = left
		face.content_margin_right = roundf(16.0 * k)
		face.content_margin_top = 10.0
		face.content_margin_bottom = 12.0
		queue_redraw()

	func fly_in(delay: float) -> void:
		var from := 0.0
		PaperMotion.ease_property(self, &"enter", 1.0, FLY_SECONDS, delay, Tween.TRANS_BACK, from)

	func set_chosen(value: bool) -> void:
		if chosen != value:
			chosen = value
			queue_redraw()

	func _set_hovered(value: bool) -> void:
		hovered = value
		_sync_lift()

	func _set_focused(value: bool) -> void:
		focused = value
		_sync_lift()

	func _sync_lift() -> void:
		var raised := (focused or hovered) and button != null and not button.disabled
		var target := 1.0 if raised else 0.0
		if is_equal_approx(target, lift):
			return
		z_index = 1 if raised else 0
		PaperMotion.ease_property(self, &"lift", target, LIFT_SECONDS, 0.0, Tween.TRANS_BACK)
		if raised:
			PaperMotion.swing(self, &"wiggle", 2.6)

	func _stamp() -> void:
		if button == null or button.disabled:
			return
		PaperMotion.swing(self, &"squash", 1.0, 0.18)
		PaperMotion.ease_property(self, &"ink", 0.0, 0.45, 0.0, Tween.TRANS_SINE, 1.0)
		PaperMotion.ease_property(self, &"dust", 0.55, 0.5, 0.0, Tween.TRANS_LINEAR, 0.0)

	func _pose() -> Array:
		var away := 1.0 - enter
		# Long pieces tilt less, so their ends never swing far into a neighbour.
		var resting := 0.0 if chosen else tilt * clampf(320.0 / maxf(size.x, 1.0), 0.55, 1.0)
		var angle := deg_to_rad(lerpf(resting, 0.0, lift) + wiggle + 12.0 * away)
		var grow := 1.0 + 0.05 * lift + 0.2 * away
		var size_scale := Vector2(grow * (1.0 + 0.05 * squash), grow * (1.0 - 0.08 * squash))
		var centre := (size * 0.5 + Vector2(70.0, 26.0) * away + Vector2(0.0, -3.0 * lift + 2.0 * squash)).round()
		return [centre, angle, size_scale]

	func _draw() -> void:
		match kind:
			"tag", "stub", "stamp":
				_draw_keepsake()
			"note", "photo":
				_draw_backing()
			"headline":
				_draw_headline()
			"sheet":
				_draw_sheet()

	## How far the outline steps in from the left and right at row `y` (pixels
	## from the top of `rect`): chamfered tag corners, half-moon stub notches or
	## perforated stamp sides, on the 2 px art grid.
	func _edge(rect: Rect2, y: float) -> Vector2:
		match kind:
			"tag":
				var cut := Props.snap(Vector2(minf(14.0, rect.size.y * 0.32), 0)).x
				return Vector2(maxf(0.0, cut - minf(y, rect.size.y - y - 2.0)), 0.0)
			"stub":
				var notch := minf(8.0, rect.size.y * 0.2)
				var from_middle := absf(y + 1.0 - rect.size.y * 0.5)
				var bite := Props.snap(Vector2(sqrt(maxf(0.0, notch * notch - from_middle * from_middle)), 0)).x
				return Vector2(bite, bite)
		var tooth := 4.0 if int(y / 4.0) % 2 == 1 else 0.0
		return Vector2(tooth, tooth)

	## The shape as a few stacked rectangles (rows with the same edges merge), so
	## the whole keepsake draws as batched rects instead of separate polygons.
	func _spans(rect: Rect2, band_end := INF) -> Array[Rect2]:
		var spans: Array[Rect2] = []
		var y := 0.0
		while y < rect.size.y - 0.5:
			var edges := _edge(rect, y)
			var zig := 0.0 if band_end == INF else (2.0 if int(y / 4.0) % 2 == 1 else -2.0)
			var tall := 2.0
			while y + tall < rect.size.y - 0.5 and _edge(rect, y + tall) == edges and (band_end == INF or int((y + tall) / 4.0) == int(y / 4.0)):
				tall += 2.0
			var right := rect.end.x - edges.y if band_end == INF else band_end + zig
			spans.append(Rect2(rect.position.x + edges.x, rect.position.y + y, right - rect.position.x - edges.x, minf(tall, rect.size.y - y)))
			y += tall
		return spans

	func _fill_spans(spans: Array[Rect2], color: Color, offset := Vector2.ZERO) -> void:
		for span in spans:
			draw_rect(Rect2(span.position + offset, span.size), color)

	func _pixel_disc(centre: Vector2, radius: float, color: Color) -> void:
		draw_rect(Rect2(centre - Vector2(radius, radius * 0.5), Vector2(radius * 2.0, radius)), color)
		draw_rect(Rect2(centre - Vector2(radius * 0.5, radius), Vector2(radius, radius * 2.0)), color)

	## One transform, nearly all rects: a keepsake costs a handful of batches.
	func _draw_keepsake() -> void:
		var pose := _pose()
		var half := size * 0.5
		var body := Props.snap_rect(Rect2(-half - Vector2(reach.x, 4), size + Vector2(reach.x + reach.y, 8)))
		var spans := _spans(body)
		var stock := swatch if kind == "stamp" else paper
		var muted := button != null and button.disabled
		var band_end := body.position.x + Props.snap(Vector2((52.0 if kind == "tag" else 46.0) * unit(), 0)).x
		var centre_y := Props.snap(body.get_center()).y
		draw_set_transform(pose[0], pose[1], pose[2])
		# Shadow grows and drifts as the keepsake lifts off the sheet.
		_fill_spans(spans, Color(Paper.SHADOW, 0.42 + 0.12 * lift), Props.snap(Vector2(4, 4) + Vector2(4, 6) * lift))
		if focused and not muted:
			# Brass rim plus a coral pointer: unmistakable even at a glance.
			var rim := body.grow(6.0)
			_fill_spans(_spans(rim.grow(2.0)), Props.deepen(RIM, 0.55))
			_fill_spans(_spans(rim), RIM)
			var tip := Vector2(rim.position.x - 4.0, centre_y)
			for step in 4:
				var reach_y := 10.0 - step * 3.0
				draw_rect(Rect2(tip + Vector2(-18.0 + step * 4.0, -reach_y - 2.0), Vector2(4, reach_y * 2.0 + 4.0)), INK_CORAL)
				draw_rect(Rect2(tip + Vector2(-16.0 + step * 4.0, -reach_y), Vector2(4, reach_y * 2.0)), Paper.CORAL)
		_fill_spans(_spans(body.grow(2.0)), Props.deepen(stock, 0.55))
		_fill_spans(spans, stock if not muted else stock.darkened(0.25))
		draw_rect(Rect2(body.position.x + 12.0, body.position.y + 2.0, body.size.x - 18.0, 2.0), Color(1, 1, 1, 0.32))
		var band: Array[Rect2] = []
		if kind == "stamp":
			var frame := body.grow(-8.0)
			for side in [Rect2(frame.position, Vector2(frame.size.x, 2)), Rect2(frame.position.x, frame.end.y - 2.0, frame.size.x, 2), Rect2(frame.position, Vector2(2, frame.size.y)), Rect2(frame.end.x - 2.0, frame.position.y, 2, frame.size.y)]:
				draw_rect(side, Color(CREAM, 0.85))
		else:
			band = _spans(body, band_end)
			_fill_spans(band, swatch)
			if kind == "tag":
				var eyelet := Vector2(body.position.x + Props.snap(Vector2(12.0 * unit(), 0)).x, centre_y)
				for knot in 5:
					draw_rect(Rect2(eyelet + Vector2(-4.0 - knot * 4.0, -2.0 - knot * 3.0), Vector2(4, 2)), Props.HEMP)
				_pixel_disc(eyelet, 5.0, Props.BRASS)
				draw_rect(Rect2(eyelet - Vector2(2, 2), Vector2(4, 4)), INK)
			else:
				var y := body.position.y + 6.0
				while y < body.end.y - 6.0:
					draw_rect(Rect2(band_end + 6.0, y, 2, 2), Color(INK, 0.45))
					y += 6.0
		if chosen:
			var seal := Vector2(body.end.x - 6.0, body.position.y + 6.0)
			_pixel_disc(seal, 11.0, CREAM)
			_pixel_disc(seal, 9.0, INK)
		if ink > 0.01:
			var mark := Vector2(body.end.x - minf(34.0, body.size.x * 0.2), centre_y)
			draw_arc(mark, 15.0, 0.0, TAU, 18, Color(INK_CORAL, 0.75 * ink), 3.0)
			draw_arc(mark, 9.0, 0.3, TAU - 0.3, 12, Color(INK_CORAL, 0.6 * ink), 2.0)
		# Textured last: print dots on the band, glyphs and icons.
		var dots := Kit.halftone(1)
		for span in band:
			draw_texture_rect_region(dots, span, span, Color(Props.deepen(swatch, 0.4), 0.45))
		_draw_label(body, band_end if kind != "stamp" else body.position.x + 12.0)
		if not icon_name.is_empty() and kind != "stamp":
			var at := Vector2(body.position.x + roundf((32.0 if kind == "tag" else 24.0) * unit()), centre_y)
			Props.icon(self, icon_name, at, CREAM, maxf(2.0, roundf(2.0 * unit())))
		if chosen:
			Props.icon(self, "confirm", Vector2(body.end.x - 6.0, body.position.y + 6.0), CREAM, 2.0)
		draw_set_transform(Vector2.ZERO)
		if dust < 0.5:
			Props.dust_puffs(self, Vector2(size.x * 0.5, size.y + 2.0), dust, size.x * 0.45, Color(0.94, 0.88, 0.74))

	func _draw_label(body: Rect2, left: float) -> void:
		if button == null:
			return
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var shown := button.text
		var width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var room := body.end.x - 8.0 - left
		var x := left + maxf(0.0, (room - width) * 0.5)
		var baseline := body.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		var ink_color := INK
		if button.disabled:
			ink_color = Color(INK, 0.6)
		draw_string(font, Vector2(x, baseline).round(), shown, HORIZONTAL_ALIGNMENT_LEFT, room, font_size, ink_color)

	func _draw_backing() -> void:
		var pose := _pose()
		var half := size * 0.5
		var body := Rect2(-half - Vector2(bleed, bleed), size + Vector2(bleed, bleed) * 2.0)
		var points: PackedVector2Array = Kit.torn(body, salt, 2.0 if kind == "note" else 1.0, 8.0)
		draw_set_transform(pose[0] + Vector2(4, 6), pose[1], Vector2.ONE)
		draw_colored_polygon(points, Color(Paper.SHADOW, 0.45))
		draw_set_transform(pose[0], pose[1], Vector2.ONE)
		Kit.fill(self, points, Props.material_tile("paper", swatch), Color.WHITE)
		if kind == "photo":
			# Polaroid: a sky window the portrait stands in, deeper margin below.
			var window := Rect2(body.position + Vector2(8, 8), body.size - Vector2(16, 30))
			draw_rect(window, Color("#9fd8d0"))
			Kit.fill(self, PackedVector2Array([window.position, Vector2(window.end.x, window.position.y), window.end, Vector2(window.position.x, window.end.y)]), Kit.halftone(0), Color(1, 1, 1, 0.35))
			draw_rect(Rect2(window.position.x, window.end.y - 10, window.size.x, 10), Color("#7cc46a"))
		Kit.outline(self, points, Props.deepen(swatch, 0.55), 2.0)
		if kind == "note" and body.size.y > 320.0:
			# A spare postage stamp stuck in the empty corner of the note.
			var stamp_rect := Rect2(body.end.x - 74.0, body.end.y - 78.0, 52.0, 60.0)
			draw_set_transform(pose[0] + stamp_rect.get_center(), pose[1] + deg_to_rad(8.0), Vector2.ONE)
			var face := Rect2(-stamp_rect.size * 0.5, stamp_rect.size)
			var edge: PackedVector2Array = Kit.stamp_shape(face)
			draw_colored_polygon(edge, Paper.CORAL)
			Kit.outline(self, edge, INK_CORAL, 2.0)
			draw_rect(face.grow(-8.0), Color(CREAM, 0.9), false, 2.0)
			Props.icon(self, "shell", Vector2.ZERO, CREAM, 3.0)
		draw_set_transform(Vector2.ZERO)
		Kit.tape(self, Vector2(size.x * 0.5, -bleed + 1.0), minf(70.0, size.x * 0.4), deg_to_rad(-6.0 + tilt))

	func _draw_headline() -> void:
		if label == null:
			return
		var font := label.get_theme_font("font")
		# Without the eyebrow row above (compact windows) there is less room to
		# grow upward before the sheet's edge.
		var base := label.get_theme_font_size("font_size")
		var big := roundi(base * (2.1 if label.position.y > 4.0 else 1.6))
		var small := maxi(12, roundi(base * 0.62))
		# Long titles shrink until title and stickers fit the header's width.
		var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + 30.0
		for words in [note, caption]:
			if not words.is_empty():
				total += font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 40.0
		if total > size.x and size.x > 0.0:
			var fit := size.x / total
			big = maxi(base, floori(big * fit))
			small = maxi(12, floori(small * fit))
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		# Rising to the right must stay below the top of the window.
		var room := label.get_global_rect().end.y - 6.0
		var needed := text_size.y * 0.95 + text_size.x * sin(deg_to_rad(absf(tilt)))
		if needed > room and room > 0.0:
			big = maxi(base, floori(big * room / needed))
			text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		var away := 1.0 - enter
		# Pivot on the lower-left corner: the title rises to the right and never
		# drops into the content under the header.
		var origin := Vector2(6.0, size.y - 2.0)
		var slam := 1.0 + 0.7 * away
		var angle := deg_to_rad(tilt)
		draw_set_transform(origin, angle, Vector2(slam, slam))
		var tall := text_size.y
		# Halftone burst and a cut-paper strip behind the letters.
		var burst: PackedVector2Array = Kit.burst_shape(Vector2(text_size.x * 0.78, -tall * 0.65), Vector2(text_size.x * 0.62, tall * 1.05), 11, salt)
		Kit.fill(self, burst, Kit.halftone(2), Color(SEA, 0.5))
		var strip: PackedVector2Array = Kit.torn(Rect2(-14.0, -tall * 0.62, text_size.x + 30.0, tall * 0.66), salt, 3.0, 7.0)
		draw_colored_polygon(strip, swatch)
		Kit.fill(self, strip, Kit.halftone(0), Color(Props.deepen(swatch, 0.35), 0.5))
		var baseline := Vector2(0.0, -tall * 0.12)
		draw_string(font, baseline + Vector2(4, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(INK, 0.85))
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, 8, INK)
		draw_string(font, baseline + Vector2(-2, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, SEA)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, CREAM)
		# Small stickers: the place name and the eyebrow line, slapped on askew.
		var sticker_x := text_size.x + 26.0
		for entry in [[note, RIM, -3.0], [caption, CREAM, 2.5]]:
			var words: String = entry[0]
			if words.is_empty():
				continue
			var extent := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
			draw_set_transform(origin + Vector2(sticker_x, -tall * 0.55).rotated(angle) * slam, deg_to_rad(float(entry[2])), Vector2(slam, slam))
			var box := Rect2(Vector2(0, -extent.y * 0.5 - 4.0), extent + Vector2(14, 8))
			draw_rect(Rect2(box.position + Vector2(3, 3), box.size), Color(Paper.SHADOW, 0.45))
			draw_rect(box, entry[1])
			draw_string(font, Vector2(7, box.position.y + 4.0 + font.get_ascent(small)), words, HORIZONTAL_ALIGNMENT_LEFT, -1, small, INK)
			sticker_x += extent.x + 26.0
		draw_set_transform(Vector2.ZERO)

	func _draw_sheet() -> void:
		var body := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var points: PackedVector2Array = Kit.torn(body, salt, 3.0, 10.0)
		draw_set_transform(Vector2(8, 10))
		draw_colored_polygon(points, Color(Paper.SHADOW, 0.55))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(points, swatch)
		Kit.fill(self, points, Props.material_tile("paper", swatch), Color(1, 1, 1, 0.35))
		# A halftone wash darkening toward the lower right, in diagonal bands.
		for level: int in [1, 3]:
			var reach := 0.62 - level * 0.12
			var band := PackedVector2Array([
				Vector2(body.end.x, body.end.y - body.size.y * (reach + 0.5)),
				Vector2(body.end.x, body.end.y),
				Vector2(body.end.x - body.size.x * (reach + 0.12), body.end.y)])
			Kit.fill(self, band, Kit.halftone(level), Color(SEA, 0.1))
		# A torn sea-green strip runs diagonally behind the header.
		draw_set_transform(Vector2(body.position.x + body.size.x * 0.32, body.position.y + 34.0), deg_to_rad(-3.5))
		var strip: PackedVector2Array = Kit.torn(Rect2(-body.size.x * 0.36, -26.0, body.size.x * 0.82, 52.0), salt + 1, 3.0, 9.0)
		draw_colored_polygon(strip, Color("#1f5f66"))
		Kit.fill(self, strip, Kit.halftone(1), Color(SEA, 0.18))
		draw_set_transform(Vector2.ZERO)
		Kit.outline(self, points, Paper.OUTLINE, 3.0)
		_draw_postmark(Vector2(body.position.x + body.size.x * 0.47, body.end.y - 58.0))
		Kit.tape(self, body.position + Vector2(18, 10), 76.0, deg_to_rad(-38.0))
		Kit.tape(self, Vector2(body.end.x - 18.0, body.position.y + 10.0), 76.0, deg_to_rad(36.0))

	## Faint cancellation mark printed on the sheet: ring, star and bars.
	func _draw_postmark(at: Vector2) -> void:
		var ink_tone := Color(SEA, 0.2)
		draw_arc(at, 34.0, 0.0, TAU, 28, ink_tone, 3.0)
		draw_arc(at, 26.0, 0.0, TAU, 24, ink_tone, 2.0)
		Props.icon(self, "star", at, ink_tone, 3.0)
		# Cancellation bars beside the ring (rects batch together).
		for line in 4:
			draw_rect(Rect2(at + Vector2(44.0, -16.0 + line * 10.0), Vector2(110.0, 2.0)), ink_tone)
