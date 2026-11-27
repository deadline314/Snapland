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
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
## The shared minigame drawing kit; the helpers below are thin wrappers over it.
const Props = preload("res://game/ui/pixel_props.gd")
const Collage = preload("res://game/ui/collage_kit.gd")
const DESIGN := Vector2(1280, 720)
## Dusky plum the circus sprites' shadows lean toward.
const SPRITE_SHADE := Color(0.05, 0.02, 0.09)
const INK := Color("#1b1626")
const CREAM := Color("#fff5dc")
const GOLD := Color("#ffd166")
const MINT := Color("#70e1c1")
const ROSE := Color("#ff6f7d")
## Dark lacquer, gilt and velvet for the shared overlays.
const LACQUER := Color("#3a2433")
const GILT := Color("#c9953e")
const VELVET := Color("#5c2440")
## The HUD covers the canvas above this line.
const PLAY_TOP := 122.0
const STRIP := Rect2(410, 130, 460, 12)
const WORD_SECONDS := 0.95
## Screen pixels per texel of a baked sprite.
const TEXEL := 4.0

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
	var rows := int((DESIGN.y - top) / TEXEL) + 1
	var boards := Pixels.bake("stage|%s|%s|%d" % [wood.to_html(), seam.to_html(), rows], Vector2i(320, rows), func(x: int, y: int) -> Color:
		return Pixels.stage_boards(wood, seam, x, y))
	stamp(boards, Vector2(0, top))
	# A moulded skirting board where the boards meet the wall.
	panel(Rect2(-8, top - 14.0, DESIGN.x + 16.0, 18), "planks", wood.lightened(0.06))
	draw_rect(Rect2(0, top + 4.0, DESIGN.x, 8), Color(0.08, 0.03, 0.1, 0.3))


## A baked material (see Pixels.surface) stretched over `rect`, outline included.
func panel(rect: Rect2, kind: String, base: Color, trim := Color(0, 0, 0, 0), texel := TEXEL, tint := Color.WHITE) -> void:
	Props.surface(self, rect, kind, base, trim, texel, tint)


## A chipped gilt frame `border` design pixels wide around `rect`'s edge.
func gilt_frame(rect: Rect2, border: float, base := GILT, texel := TEXEL, tint := Color.WHITE) -> void:
	Props.gilt_frame(self, rect, border, base, texel, tint)


## A highlight sweeping across something round and shiny every `period` seconds.
func glint(center: Vector2, radius: float, period := 3.0, offset := 0.0) -> void:
	if not reduced_motion:
		Props.glint(self, center, radius, fposmod(now + offset, period) / 0.45)


## A slanted band of light crossing `rect` as `phase` runs from 0 to 1, drawn
## in texel rows so it stays pixel art.
func sheen(rect: Rect2, phase: float, width: float, alpha := 0.18, slant := 0.6) -> void:
	if not reduced_motion:
		Props.sheen(self, rect, phase, width, alpha, slant, TEXEL)


## Dust kicked up where something lands; `elapsed` counts from the impact.
func dust_puffs(at: Vector2, elapsed: float, spread := 60.0) -> void:
	if not reduced_motion:
		Props.dust_puffs(self, at, elapsed, spread)


## Draw a baked sprite (arcade_pixels.gd) so texel (0, 0) of its shape lands on `at`.
func stamp(texture: Texture2D, at: Vector2, scale_factor := TEXEL, tint := Color.WHITE) -> void:
	Props.stamp(self, texture, at, scale_factor, tint)


## The shadow a hung or standing sprite throws on whatever is behind it.
func cast_shadow(texture: Texture2D, at: Vector2, offset := Vector2(10, 14), scale_factor := TEXEL, strength := 0.3) -> void:
	Props.sprite_shadow(self, texture, at, offset, scale_factor, strength, SPRITE_SHADE)


## Darkened side edges keep the eye on the middle and sink sprites into the painting.
func vignette(strength := 0.5) -> void:
	Props.vignette(self, Rect2(0, PLAY_TOP, DESIGN.x, DESIGN.y - PLAY_TOP), strength, Color(0.04, 0.02, 0.07))


## A wooden bench or shelf from `top` to the bottom edge: grained boards, a lit
## front lip, and dusk gathering where it meets the wall.
func bench(top: float, wood: Color) -> void:
	for band in 4:
		draw_rect(Rect2(0, top - 72.0 + band * 18.0, DESIGN.x, 18), Color(0.09, 0.05, 0.14, 0.1 + band * 0.1))
	var rows := int((DESIGN.y - top) / TEXEL) + 1
	var boards := Pixels.bake("bench|%s|%d" % [wood.to_html(), rows], Vector2i(320, rows), func(x: int, y: int) -> Color:
		if y < 2:
			return Pixels.grainy(wood.lightened(0.24), x, y, 0.1)
		if y == 2:
			return wood.darkened(0.5)
		return Pixels.wood(wood.darkened(minf(0.5, 0.1 + 0.012 * y)), x, y - 3, 11, false))
	stamp(boards, Vector2(0, top))


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
	Props.oval_shadow(self, center, radii, strength, SPRITE_SHADE)


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


## A lacquered pixel plate with a gilt pinstripe and rivets, casting a shadow.
func plate(rect: Rect2, face: Color, edge: Color, _outline := INK) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 7), rect.size), Color(edge.darkened(0.4), 0.55))
	panel(rect.grow(3.0), "lacquer", face, GILT, 3.0)


## A keyboard key cap centred on `center`; returns its width.
func key_cap(center: Vector2, content: String, pressed := false, font_size := 20) -> float:
	var width := maxf(44.0, label_width(content, font_size) + 26.0)
	var height := font_size + 18.0
	var drop := 4.0 if pressed else 0.0
	var rect := Rect2(center.x - width * 0.5, center.y - height * 0.5 + drop, width, height)
	# An ivory key top on a deeper skirt that shrinks as the key goes down.
	panel(Rect2(rect.position + Vector2(-3, 2), rect.size + Vector2(6, 9.0 - drop)), "lacquer", Color("#8a7660"), Color(0, 0, 0, 0), 3.0)
	panel(rect.grow(3.0), "key", GOLD if pressed else CREAM, Color(0, 0, 0, 0), 3.0)
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
	# A lacquer rail with brass end caps around a recessed groove.
	panel(track.grow(8.0), "lacquer", LACQUER, GILT, 2.0)
	panel(track.grow(2.0), "groove", Color("#2a1d33"), Color(0, 0, 0, 0), 2.0)
	var earned := int(state.get("medal", 0))
	var fill_color: Color = Medal.FACES[earned] if earned > 0 else MINT
	var filled := track.size.x * clampf(float(score) / full, 0.0, 1.0)
	if filled >= 4.0:
		var liquid := Pixels.surface("liquid", Vector2i(int(track.size.x / 2.0) - 2, 4), fill_color.darkened(0.1))
		var shown := filled / track.size.x
		draw_texture_rect_region(liquid, Rect2(track.position, Vector2(filled, track.size.y)), Rect2(Vector2.ZERO, Vector2(liquid.get_width() * shown, liquid.get_height())))
		if not reduced_motion:
			var sweep := fposmod(now * 160.0, filled + 160.0) - 80.0
			if sweep > 0.0 and sweep < filled - 8.0:
				draw_rect(Rect2(track.position.x + sweep, track.position.y + 2.0, 6, track.size.y - 5.0), Color(1, 1, 1, 0.3))
	for side: float in [0.0, 1.0]:
		var cap := Vector2(track.position.x - 12.0 + side * (track.size.x + 24.0), track.get_center().y)
		draw_circle(cap, 9.0, GILT.darkened(0.66))
		draw_circle(cap, 7.0, GILT)
		draw_circle(cap + Vector2(1, 1), 4.0, GILT.darkened(0.22))
		draw_rect(Rect2(cap - Vector2(4, 4), Vector2(3, 3)), GILT.lightened(0.45))
	for index in 3:
		var at := Vector2(track.position.x + track.size.x * float(lines[index]) / full, track.get_center().y)
		var lit := earned > index
		Medal.paint(self, at + Vector2(0, 2), 2.0, index + 1, lit)
		if lit:
			glint(at + Vector2(0, 2), 12.0, 3.2, index * 0.4)
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
	panel(Rect2(x - 24.0, y - 28.0, width + 48.0, 58.0), "lacquer", LACQUER, GILT, 3.0, Color(1, 1, 1, 0.94))
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
		panel(Rect2(24.0, y - 24.0, chip_width + 8.0, 48.0), "lacquer", LACQUER, GILT, 3.0, Color(1, 1, 1, 0.94))
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
	var face := GOLD if good else ROSE
	var grow := pop_in(elapsed, 0.2)
	# Darker copies underneath give the word a chunky, extruded body.
	for depth: float in [6.0, 3.0]:
		label(word_anchor + Vector2(0, rise + depth * grow), word, 58, face.darkened(0.5).lerp(Pixels.SHADOW_HUE, 0.3), grow, fade)
	label(word_anchor + Vector2(0, rise), word, 58, face, grow, fade)


func _draw_ready_banner() -> void:
	var stage_time := float(state.get("stage_time", 0.0))
	var total := float(state.get("ready_seconds", 2.4))
	var enter := 1.0 if reduced_motion else smoothstep(0.0, 0.18, stage_time)
	# The banner sits low so the scene above it doubles as the opening demo.
	var band := Rect2(0, 540.0 + 40.0 * (1.0 - enter), 1280, 112)
	# A velvet valance in a chipped gilt frame.
	var fade := Color(1, 1, 1, enter)
	draw_rect(Rect2(band.position + Vector2(0, 12), band.size), Color(0.06, 0.02, 0.08, 0.4 * enter))
	panel(band, "velvet", VELVET, Color(0, 0, 0, 0), TEXEL, fade)
	gilt_frame(Rect2(band.position - Vector2(16, 0), band.size + Vector2(32, 0)), 16.0, GILT, TEXEL, fade)
	label(Vector2(560, band.position.y + 42.0), str(state.get("verb", "")), 38, CREAM, pop_in(stage_time, 0.3))
	var variant_label := str(state.get("variant_label", ""))
	if not variant_label.is_empty():
		label(Vector2(560, band.position.y + 86.0), "本回合變奏：" + variant_label, 20, GOLD)
	# Three even beats, then play begins.
	var beat := total / 3.0
	var count := clampi(3 - int(stage_time / beat), 1, 3)
	var beat_age := fmod(stage_time, beat)
	var disc := Vector2(1090, band.get_center().y)
	_medallion(disc, 58.0)
	label(disc, str(count), 64, CREAM, 0.7 + 0.3 * pop_in(beat_age, 0.22))


func _draw_closing_card() -> void:
	var elapsed := float(state.get("stage_time", 0.0)) if str(state.get("stage", "")) == "closing" else 9.0
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(INK, 0.5 * (1.0 if reduced_motion else smoothstep(0.0, 0.25, elapsed))))
	# A torn journal card is slapped down at a slight angle and taped in place.
	var settle := pop_in(elapsed, 0.3)
	var angle := deg_to_rad(-2.5 + 9.0 * (1.0 - settle))
	var centre := Vector2(640, 375) + Vector2(0, 70.0 * (1.0 - settle))
	var face := Rect2(Vector2(-240, -130), Vector2(480, 260))
	var edge: PackedVector2Array = Collage.torn(face, 13, 3.0, 10.0)
	draw_set_transform(centre + Vector2(10, 14), angle)
	draw_colored_polygon(edge, Color(0.06, 0.02, 0.08, 0.45))
	draw_set_transform(centre, angle)
	draw_colored_polygon(edge, Collage.CREAM)
	Collage.outline(self, edge, Props.deepen(Collage.CREAM, 0.55), 3.0)
	var strip: PackedVector2Array = Collage.torn(Rect2(-70, -114, 270, 58), 7, 3.0, 8.0)
	draw_colored_polygon(strip, Paper.CORAL)
	var earned := int(state.get("medal", 0))
	var seal: PackedVector2Array = Collage.stamp_shape(Rect2(26, -40, 190, 64))
	draw_colored_polygon(seal, Medal.FACES[earned].lightened(0.45))
	Collage.outline(self, seal, Props.deepen(Medal.FACES[earned], 0.5), 2.0)
	draw_line(Vector2(36, 92), Vector2(206, 88), Color(Paper.CORAL, 0.8), 3.0)
	draw_set_transform(Vector2.ZERO)
	for side: float in [-1.0, 1.0]:
		Collage.tape(self, centre + Vector2(side * 196.0, -128.0).rotated(angle), 92.0, angle + side * 0.55)
	_card_text(centre, angle, Vector2(64, -84), "時間到！", 40, CREAM, pop_in(elapsed, 0.24), true)
	_card_text(centre, angle, Vector2(121, -7), Medal.NAMES[earned], 30, INK, 1.0, false)
	# The score counts up once the card has landed.
	var shown := int(state.get("score", 0))
	if not reduced_motion:
		shown = roundi(shown * smoothstep(0.35, 0.8, elapsed))
	_card_text(centre, angle, Vector2(121, 62), "%d 分" % shown, 34, INK, 1.0, false)
	# The medal drops in after a beat and squashes as it lands.
	var drop_age := elapsed - 0.3
	var fall := 0.0 if reduced_motion else -220.0 * (1.0 - smoothstep(0.0, 0.26, drop_age))
	if drop_age >= 0.0 or reduced_motion:
		var landed := squash(drop_age - 0.26, 0.3)
		var at := centre + Vector2(-130, 40).rotated(angle) + Vector2(0, fall)
		draw_set_transform(at, 0.0, landed)
		Medal.paint(self, Vector2(0, 0), 6.0, earned)
		draw_set_transform(Vector2.ZERO)
		dust_puffs(centre + Vector2(-130, 84).rotated(angle), drop_age - 0.26, 70.0)
		if earned > 0 and drop_age > 0.7:
			glint(at, 38.0, 2.4, -0.96)


## Text on the tilted closing card, centred on `offset` in card space.
func _card_text(centre: Vector2, angle: float, offset: Vector2, content: String, font_size: int, color: Color, scale_factor: float, outlined: bool) -> void:
	if _font == null:
		return
	var extent := _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_set_transform(centre + offset.rotated(angle), angle, Vector2.ONE * scale_factor)
	var origin := Vector2(-extent.x * 0.5, extent.y * 0.32)
	if outlined:
		draw_string_outline(_font, origin, content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, clampi(int(font_size * 0.22), 3, 12), INK)
	draw_string(_font, origin, content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_set_transform(Vector2.ZERO)


## A brass medallion: bevelled rim, ten rivets and a glossy enamel centre.
func _medallion(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(5, 7), radius, Color(0.06, 0.02, 0.08, 0.45))
	draw_circle(center, radius, GILT.darkened(0.66))
	draw_circle(center, radius - 3.0, GILT.darkened(0.3))
	draw_circle(center + Vector2(-2, -2), radius - 5.0, GILT.lightened(0.3))
	draw_circle(center, radius - 8.0, GILT)
	for rivet in 10:
		var spot := (center + Vector2.from_angle(rivet * TAU / 10.0) * (radius - 5.0)).round()
		draw_rect(Rect2(spot - Vector2(2, 2), Vector2(3, 3)), GILT.lightened(0.5))
		draw_rect(Rect2(spot + Vector2(1, 1), Vector2(2, 2)), GILT.darkened(0.55))
	draw_circle(center, radius - 13.0, LACQUER.darkened(0.6))
	draw_circle(center + Vector2(1, 2), radius - 15.0, LACQUER.darkened(0.25))
	draw_circle(center, radius - 17.0, LACQUER)
	draw_arc(center, radius - 21.0, PI * 1.05, PI * 1.45, 8, Color(1, 0.92, 0.8, 0.35), 4.0)
