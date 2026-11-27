extends Control
## Shared picture for arcade minigames on the 1280 x 720 design canvas.
##
## A game view extends this and overrides `_draw_backdrop()` and `_draw_scene()`.
## The base then lays the medal strip, the ready banner, feedback words, the
## closing card and one control-hint line on top; there is no button panel.
## The whole picture is a pure function of the driver state (`now` is the
## driver clock), so pausing freezes it and reduced motion only removes easing.

const Medal = preload("res://game/ui/arcade_medal.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const DESIGN := Vector2(1280, 720)
const INK := Color("#1b1626")
const CREAM := Color("#fff5dc")
const GOLD := Color("#ffd166")
const MINT := Color("#70e1c1")
const ROSE := Color("#ff6f7d")
## The HUD covers the canvas above this line.
const PLAY_TOP := 122.0
const STRIP := Rect2(410, 130, 460, 12)
const WORD_SECONDS := 0.95

var state: Dictionary = {}
var reduced_motion := false
## Driver clock in seconds; every animation is derived from it.
var now := 0.0
## Where feedback words pop; a game may move it next to the action.
var word_anchor := Vector2(640, 236)
var _font: Font


func _init() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func present(next_state: Dictionary, reduced: bool) -> void:
	state = next_state
	reduced_motion = reduced
	now = float(state.get("clock", 0.0))
	queue_redraw()


func _draw() -> void:
	if state.is_empty():
		return
	_font = Paper.font()
	_draw_backdrop()
	_draw_scene()
	draw_set_transform(Vector2.ZERO)
	_draw_medal_strip()
	_draw_hint()
	_draw_word()
	var stage := str(state.get("stage", "play"))
	if stage == "ready":
		_draw_ready_banner()
	elif stage != "play":
		_draw_closing_card()


# --- Hooks ------------------------------------------------------------------

## Far layers: sky, walls, floor.
func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b2440"))


## Everything the player watches and acts on.
func _draw_scene() -> void:
	pass


# --- Helpers for game views -------------------------------------------------

## Put a painted picture behind the pixel layer with smooth filtering, cropped
## to `region` and stretched over the canvas. Call once from `_ready()`.
func use_backdrop_art(path: String, region: Rect2, tint := Color.WHITE) -> bool:
	var art := load(path) as Texture2D if ResourceLoader.exists(path) else null
	if art == null:
		push_warning("Arcade view: backdrop %s is missing; drawing a flat wall instead." % path)
		return false
	var crop := AtlasTexture.new()
	crop.atlas = art
	crop.region = region
	var picture := TextureRect.new()
	picture.name = "BackdropArt"
	picture.texture = crop
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.size = DESIGN
	picture.modulate = tint
	picture.show_behind_parent = true
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return true


## Stage boards from `top` to the bottom edge, with haze where they meet the wall.
func stage_floor(top: float, wood: Color, seam: Color) -> void:
	for band in 4:
		draw_rect(Rect2(0, top - 96.0 + band * 24.0, DESIGN.x, 24), Color(0.09, 0.05, 0.14, 0.14 + band * 0.12))
	draw_rect(Rect2(0, top, DESIGN.x, DESIGN.y - top), seam)
	var y := top
	for row in 4:
		var height := 30.0 + row * 14.0
		var tone := wood.darkened(0.42 - row * 0.07)
		draw_rect(Rect2(0, y, DESIGN.x, height - 3.0), tone)
		draw_rect(Rect2(0, y, DESIGN.x, 2), tone.lightened(0.14))
		var step := 150.0 + row * 44.0
		var x := -fmod(row * 97.0, step)
		while x < DESIGN.x:
			draw_rect(Rect2(x, y, 3, height - 3.0), seam)
			x += step
		y += height
	draw_rect(Rect2(0, top - 4.0, DESIGN.x, 5), wood.lightened(0.32))

## Seconds since a moment the driver stamped with its clock.
func age(stamp: float) -> float:
	return now - stamp


## 0 -> 1 with a small overshoot; things arriving on screen.
func pop_in(elapsed: float, seconds := 0.26) -> float:
	var t := clampf(elapsed / seconds, 0.0, 1.0)
	if reduced_motion:
		return 1.0
	t -= 1.0
	return t * t * (2.7 * t + 1.7) + 1.0


## Squash-and-stretch right after an impact: wide and flat, then settling.
func squash(elapsed: float, strength := 0.22, seconds := 0.34) -> Vector2:
	if reduced_motion or elapsed < 0.0 or elapsed >= seconds:
		return Vector2.ONE
	var t := elapsed / seconds
	var push := strength * (1.0 - t) * cos(t * TAU * 1.5)
	return Vector2(1.0 + push, 1.0 - push)


## A looping 0..1..0 pulse; still when motion is reduced.
func pulse(rate := 1.0, offset := 0.0) -> float:
	return 0.5 if reduced_motion else 0.5 + 0.5 * sin((now * rate + offset) * TAU)


## Soft contact shadow so objects sit on the floor instead of floating.
func ground_shadow(center: Vector2, radii: Vector2, strength := 0.34) -> void:
	for ring in 3:
		var grow := 1.0 - ring * 0.22
		draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
		draw_circle(Vector2.ZERO, radii.x * grow, Color(0.05, 0.02, 0.09, strength * 0.42))
	draw_set_transform(Vector2.ZERO)


## Centred text with a dark pixel outline; `scale_factor` pops it around its
## centre. Pass `outlined` false for dark ink on a light plate.
func label(center: Vector2, content: String, font_size: int, color := CREAM, scale_factor := 1.0, alpha := 1.0, outlined := true) -> void:
	if _font == null or content.is_empty():
		return
	var extent := _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	var origin := Vector2(-extent.x * 0.5, extent.y * 0.32)
	if outlined:
		draw_string_outline(_font, origin, content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, clampi(int(font_size * 0.22), 3, 12), Color(INK, alpha))
	draw_string(_font, origin, content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)


func label_width(content: String, font_size: int) -> float:
	return _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if _font != null else 0.0


## A chunky pixel plate: outline, face and a darker lower edge.
func plate(rect: Rect2, face: Color, edge: Color, outline := INK) -> void:
	draw_rect(rect.grow(3.0), outline)
	draw_rect(rect, edge)
	draw_rect(Rect2(rect.position, rect.size - Vector2(0, 5)), face)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), face.lightened(0.25))


## A keyboard key cap centred on `center`; returns its width.
func key_cap(center: Vector2, content: String, pressed := false, font_size := 20) -> float:
	var width := maxf(44.0, label_width(content, font_size) + 26.0)
	var height := font_size + 18.0
	var drop := 4.0 if pressed else 0.0
	var rect := Rect2(center.x - width * 0.5, center.y - height * 0.5 + drop, width, height)
	draw_rect(rect.grow(3.0), INK)
	draw_rect(Rect2(rect.position + Vector2(0, 6.0 - drop), rect.size), Color("#9a8f7a"))
	draw_rect(rect, GOLD if pressed else CREAM)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color.WHITE)
	if _font != null:
		var extent := _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(_font, Vector2(center.x - extent.x * 0.5, center.y + drop + extent.y * 0.32), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	return width


# --- Shared layers ----------------------------------------------------------

func _draw_medal_strip() -> void:
	var lines: Array = state.get("thresholds", [])
	if lines.size() != 3:
		return
	var score := int(state.get("score", 0))
	var full := float(lines[2]) * 1.12
	var track := STRIP
	draw_rect(track.grow(4.0), Color(INK, 0.9))
	draw_rect(track, Color("#3a3447"))
	var earned := int(state.get("medal", 0))
	var fill_color: Color = Medal.FACES[earned] if earned > 0 else MINT
	var filled := track.size.x * clampf(float(score) / full, 0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(filled, track.size.y)), fill_color)
	draw_rect(Rect2(track.position, Vector2(filled, 3)), fill_color.lightened(0.35))
	for index in 3:
		var at := Vector2(track.position.x + track.size.x * float(lines[index]) / full, track.get_center().y)
		var lit := earned > index
		Medal.paint(self, at + Vector2(0, 2), 2.0, index + 1, lit)
		label(at + Vector2(36, -14), str(lines[index]), 15, Medal.FACES[index + 1] if lit else Color("#b9b2c8"))


func _draw_hint() -> void:
	var pairs: Array = state.get("hint", [])
	if pairs.is_empty() or _font == null:
		return
	var font_size := 20
	var width := 0.0
	for pair: Array in pairs:
		width += maxf(44.0, label_width(str(pair[0]), font_size) + 26.0) + 12.0 + label_width(str(pair[1]), font_size) + 34.0
	width -= 34.0
	var x := 640.0 - width * 0.5
	var y := 690.0
	draw_rect(Rect2(x - 22.0, y - 26.0, width + 44.0, 52.0), Color(INK, 0.72))
	var tapping := str(state.get("stage", "")) == "ready" and pulse(1.8) > 0.62
	for pair: Array in pairs:
		var cap := maxf(44.0, label_width(str(pair[0]), font_size) + 26.0)
		key_cap(Vector2(x + cap * 0.5, y - 3.0), str(pair[0]), tapping, font_size)
		x += cap + 12.0
		var words := label_width(str(pair[1]), font_size)
		label(Vector2(x + words * 0.5, y), str(pair[1]), font_size)
		x += words + 34.0
	var variant_label := str(state.get("variant_label", ""))
	if not variant_label.is_empty():
		var chip := "變奏・" + variant_label
		var chip_width := label_width(chip, 17) + 28.0
		draw_rect(Rect2(28.0, y - 20.0, chip_width, 40.0), Color(INK, 0.72))
		draw_rect(Rect2(28.0, y - 20.0, 5.0, 40.0), GOLD)
		label(Vector2(28.0 + chip_width * 0.5 + 2.0, y), chip, 17, GOLD)
	if bool(state.get("assisted", false)):
		label(Vector2(1180.0, y), "輔助中", 17, MINT)


func _draw_word() -> void:
	var word := str(state.get("word", ""))
	var elapsed := age(float(state.get("word_at", -99.0)))
	if word.is_empty() or elapsed < 0.0 or elapsed > WORD_SECONDS:
		return
	var good := bool(state.get("word_good", true))
	var fade := 1.0 - smoothstep(WORD_SECONDS - 0.25, WORD_SECONDS, elapsed)
	var rise := 0.0 if reduced_motion else -26.0 * smoothstep(0.0, WORD_SECONDS, elapsed)
	label(word_anchor + Vector2(0, rise), word, 58, GOLD if good else ROSE, pop_in(elapsed, 0.2), fade)


func _draw_ready_banner() -> void:
	var stage_time := float(state.get("stage_time", 0.0))
	var total := float(state.get("ready_seconds", 2.4))
	var enter := 1.0 if reduced_motion else smoothstep(0.0, 0.18, stage_time)
	# The banner sits low so the scene above it doubles as the opening demo.
	var band := Rect2(0, 540.0 + 40.0 * (1.0 - enter), 1280, 112)
	draw_rect(band, Color(INK, 0.88 * enter))
	draw_rect(Rect2(band.position, Vector2(1280, 5)), GOLD)
	draw_rect(Rect2(0, band.end.y - 5.0, 1280, 5), GOLD)
	label(Vector2(560, band.position.y + 42.0), str(state.get("verb", "")), 38, CREAM, pop_in(stage_time, 0.3))
	var variant_label := str(state.get("variant_label", ""))
	if not variant_label.is_empty():
		label(Vector2(560, band.position.y + 86.0), "本回合變奏：" + variant_label, 20, GOLD)
	# Three even beats, then play begins.
	var beat := total / 3.0
	var count := clampi(3 - int(stage_time / beat), 1, 3)
	var beat_age := fmod(stage_time, beat)
	var disc := Vector2(1090, band.get_center().y)
	draw_circle(disc, 58.0, INK)
	draw_circle(disc, 52.0, GOLD)
	draw_circle(disc, 44.0, Color("#3a2433"))
	label(disc, str(count), 64, CREAM, 0.7 + 0.3 * pop_in(beat_age, 0.22))


func _draw_closing_card() -> void:
	var elapsed := float(state.get("stage_time", 0.0)) if str(state.get("stage", "")) == "closing" else 9.0
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(INK, 0.5 * (1.0 if reduced_motion else smoothstep(0.0, 0.25, elapsed))))
	var card := Rect2(410, 250, 460, 250)
	plate(card, Color("#3a2433"), Color("#241726"))
	draw_rect(Rect2(card.position + Vector2(10, 10), card.size - Vector2(20, 25)), GOLD, false, 3.0)
	label(Vector2(640, card.position.y + 48.0), "時間到！", 40, CREAM, pop_in(elapsed, 0.24))
	var earned := int(state.get("medal", 0))
	# The medal drops in after a beat and squashes as it lands.
	var drop_age := elapsed - 0.3
	var fall := 0.0 if reduced_motion else -220.0 * (1.0 - smoothstep(0.0, 0.26, drop_age))
	if drop_age >= 0.0 or reduced_motion:
		var landed := squash(drop_age - 0.26, 0.3)
		var at := Vector2(540, card.position.y + 158.0 + fall)
		draw_set_transform(at, 0.0, landed)
		Medal.paint(self, Vector2(0, 0), 6.0, earned)
		draw_set_transform(Vector2.ZERO)
	label(Vector2(730, card.position.y + 128.0), Medal.NAMES[earned], 34, Medal.FACES[earned].lightened(0.2))
	label(Vector2(730, card.position.y + 178.0), "%d 分" % int(state.get("score", 0)), 30)
