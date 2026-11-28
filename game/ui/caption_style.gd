extends RefCounted
## The shared feedback caption ("好燙！", "夾成書籤了！", "+180"): chunky rounded
## lettering with a two-tone outline (dark ink outside, a coloured rim inside),
## a top shine, a slight tilt, and letters that pop in one after another with a
## squash-bounce (PaperMotion.pop_squash). Spec: design/runtime/type-system.md.
##
## Pure drawing: call it from a CanvasItem's _draw() with the seconds since the
## caption appeared. With reduced motion, or without a display, it draws the
## settled caption on the first frame.

const FontProfiles = preload("res://game/ui/font_profiles.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")

const INK := Color("#1b1626")
## Sunny yellow with an orange rim for good beats.
const GOOD_FACE := Color("#ffe25c")
const GOOD_RIM := Color("#f07f1f")
## Cream with a coral rim for the funny fail: readable, warm, never scolding.
const FAIL_FACE := Color("#fff6e8")
const FAIL_RIM := Color("#ec4f63")
## Seconds between one letter's entrance and the next.
const STAGGER := 0.035
## Rest angle of the whole word, alternating by word so repeats look hand-placed.
const TILT_DEGREES := 4.5


## Draw `text` centred on `center`. `alpha` fades the whole caption.
static func draw(canvas: CanvasItem, center: Vector2, text: String, font_size: int, good: bool, elapsed: float, reduced: bool, alpha := 1.0) -> void:
	if text.is_empty() or alpha <= 0.0:
		return
	var font := FontProfiles.role_font("display")
	var face := GOOD_FACE if good else FAIL_FACE
	var rim := GOOD_RIM if good else FAIL_RIM
	var tilt := deg_to_rad(-TILT_DEGREES if absi(text.hash()) % 2 == 0 else TILT_DEGREES * 0.8)
	var outer := maxi(4, roundi(font_size * 0.26))
	var inner := maxi(2, roundi(font_size * 0.12))
	# Thick outlines need air between letters or neighbours merge into one blob.
	var tracking := font_size * 0.08
	var widths: Array[float] = []
	var total := 0.0
	for character in text:
		var width := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking
		widths.append(width)
		total += width
	# Letters stand on a shared baseline about a third of the size below centre.
	var baseline := font_size * 0.36
	var shadow := Vector2(0.0, maxf(3.0, font_size * 0.08))
	var shine := Vector2(0.0, -maxf(1.5, font_size * 0.04))
	var poses: Array = []
	var cursor := -total * 0.5
	for index in text.length():
		var width: float = widths[index]
		var scale := PaperMotion.pop_squash(elapsed - index * STAGGER, reduced)
		var foot := center + Vector2(cursor + width * 0.5, baseline).rotated(tilt)
		var lean := tilt + deg_to_rad(2.0 if index % 2 == 0 else -2.0)
		poses.append([foot, lean, scale, Vector2(-width * 0.5, 0.0)])
		cursor += width
	# Passes over every letter so no outline covers a neighbour's face.
	for layer in 5:
		for index in text.length():
			var pose: Array = poses[index]
			var scale: Vector2 = pose[2]
			if scale.x <= 0.0:
				continue
			var character := text[index]
			var origin: Vector2 = pose[3]
			canvas.draw_set_transform(pose[0], pose[1], scale)
			match layer:
				0:
					canvas.draw_string_outline(font, origin + shadow, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outer, Color(INK, 0.4 * alpha))
				1:
					canvas.draw_string_outline(font, origin, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outer, Color(INK, alpha))
				2:
					canvas.draw_string_outline(font, origin, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, inner, Color(rim, alpha))
				3:
					canvas.draw_string(font, origin + shine, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(face.lightened(0.6), alpha))
				4:
					canvas.draw_string(font, origin, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(face, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
