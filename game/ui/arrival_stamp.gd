extends Control
## The passport stamp for a first arrival in a district (ART-66): a cream
## keepsake tag slides in under the voyage ticket, the district's stamp is
## pressed onto it with a squash and a small ink splash, it rests a moment and
## lifts away. Each district gets it once; the HUD nameplate names the place
## on every later visit. Reduced motion shows the stamped tag and fades it.

const Paper = preload("res://game/ui/paper_ui.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Collage = preload("res://game/ui/collage_kit.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")

const SIZE := Vector2(236, 124)
const TILT := -0.11
const SLIDE_SECONDS := 0.2
const PRESS_SECONDS := 0.16
const SETTLE_SECONDS := 0.12
const HOLD_SECONDS := 2.2
const LIFT_SECONDS := 0.42
const QUIET_SECONDS := 0.16
## Stamp ink per district, each at or above 4.5:1 on the cream tag.
const INKS := {
	"harbor": Color("#1d5a5e"), "candy": Color("#a3405f"), "nightmarket": Color("#5e3482"),
	"circus": Color("#9a3128"), "toy": Color("#2c5799"), "garden": Color("#356b33"),
	"hotel": Color("#563c80"), "sky": Color("#25688c"), "cinema": Color("#8d3c33"), "theatre": Color("#7a2238"),
}
const TAG := Color("#f6ecd0")
const TAG_EDGE := Color("#c8b78f")

var region := ""
var _title := ""
var _number := 0
var _ink := Color("#1d5a5e")
## Animated: the tag's slide (0 off to the right, 1 resting), the stamp's
## press (0 lifted, 1 pressed) and the whole piece's opacity.
var _slide := 0.0
var _press := 0.0
var _splash := 0.0
var _fade := 0.0
var _tween: Tween


func _init() -> void:
	name = "ArrivalStamp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -SIZE.x - 30.0
	offset_right = -30.0
	offset_top = 92.0
	offset_bottom = 92.0 + SIZE.y
	visible = false


## Press the stamp for `region` after `delay` seconds (a fast-travel cover is
## still opening). Replaces a stamp that is still showing.
func show_region(target: String, delay := 0.0) -> void:
	_stop()
	region = target
	_title = RegionRoutes.title(target)
	_number = maxi(RegionRoutes.ORDER.find(target), 0)
	_ink = INKS.get(target, Color("#1d5a5e"))
	visible = true
	_tween = create_tween()
	if delay > 0.0: _tween.tween_interval(delay)
	if PaperMotion.enabled():
		_set_state(0.0, 0.0, 0.0, 1.0)
		_tween.tween_method(_set_slide, 0.0, 1.0, SLIDE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_press, 0.0, 1.0, PRESS_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_method(_set_splash, 0.0, 1.0, SETTLE_SECONDS * 2.0)
		_tween.tween_interval(HOLD_SECONDS)
		_tween.tween_method(_set_fade, 1.0, 0.0, LIFT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		_set_state(1.0, 1.0, 1.0, 0.0)
		_tween.tween_method(_set_fade, 0.0, 1.0, QUIET_SECONDS)
		_tween.tween_interval(HOLD_SECONDS)
		_tween.tween_method(_set_fade, 1.0, 0.0, QUIET_SECONDS * 2.0)
	_tween.tween_callback(_finish)


func showing() -> bool:
	return visible


## Take the stamp away at once (a menu, a game or a new trip took over).
func dismiss() -> void:
	_stop()
	_finish()


func _finish() -> void:
	visible = false
	region = ""


func _stop() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null


func _set_state(slide: float, press: float, splash: float, fade: float) -> void:
	_slide = slide
	_press = press
	_splash = splash
	_set_fade(fade)


func _set_slide(value: float) -> void:
	_slide = value
	queue_redraw()


func _set_press(value: float) -> void:
	_press = value
	queue_redraw()


func _set_splash(value: float) -> void:
	_splash = value
	queue_redraw()


func _set_fade(value: float) -> void:
	_fade = value
	modulate.a = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _title.is_empty() or _fade <= 0.0: return
	var lift := (1.0 - _fade) * -18.0
	var centre := SIZE * 0.5 + Vector2((1.0 - _slide) * (SIZE.x + 60.0), lift)
	# The keepsake tag: torn cream card, a soft drop shadow and a strip of tape.
	draw_set_transform(centre + Vector2(4, 6), TILT)
	var card := Rect2(-SIZE * 0.5, SIZE)
	Collage.fill(self, Collage.torn(card, 66, 2.0, 7.0), Collage.halftone(1), Color(0.02, 0.07, 0.09, 0.32))
	draw_set_transform(centre, TILT)
	var edge := Collage.torn(card, 66, 2.0, 7.0)
	draw_colored_polygon(edge, TAG)
	Collage.outline(self, edge, TAG_EDGE, 2.0)
	draw_set_transform(Vector2.ZERO)
	Collage.tape(self, centre + Vector2(-SIZE.x * 0.36, -SIZE.y * 0.48), 58.0, -0.5)
	if _press <= 0.0: return
	# The stamp drops from above, lands a little squashed and settles.
	var squash := 1.0 + (1.0 - _press) * 0.55
	if _press >= 1.0: squash = 1.0 - 0.06 * sin(clampf(_splash, 0.0, 1.0) * PI)
	var ink := Color(_ink, lerpf(0.25, 0.92, _press))
	draw_set_transform(centre + Vector2(6, 2), TILT + 0.05, Vector2(squash, 2.0 - squash) * (1.0 + (1.0 - _press) * 0.25))
	var outer := Rect2(-96, -44, 192, 88)
	_ink_box(outer, ink, 4.0)
	_ink_box(outer.grow(-7.0), ink, 2.0)
	var font := Paper.font()
	draw_string(font, Vector2(-90, -24), "入　境", HORIZONTAL_ALIGNMENT_CENTER, 180, 14, ink)
	draw_string(font, Vector2(-90, 12), _title, HORIZONTAL_ALIGNMENT_CENTER, 180, 28, ink)
	draw_string(font, Vector2(-90, 34), "SNAPLAND  ·  No.%02d" % _number, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, ink)
	# Worn ink: a few paper-coloured flecks break up the lines.
	for index in 40:
		var spot := Vector2(lerpf(outer.position.x, outer.end.x, Pixels.noise(index, 3, 66)), lerpf(outer.position.y, outer.end.y, Pixels.noise(index, 7, 66)))
		draw_rect(Rect2(spot.floor(), Vector2(2, 2)), Color(TAG, 0.85))
	# A ring of ink spatter that spreads and fades as the stamp lands.
	if _splash > 0.0 and _splash < 1.0:
		var reach := 1.0 + _splash * 0.18
		var spatter := Color(_ink, (1.0 - _splash) * 0.5)
		for index in 12:
			var angle := TAU * index / 12.0 + Pixels.noise(index, 2, 9) * 0.4
			var at := Vector2(cos(angle) * 104.0, sin(angle) * 52.0) * reach
			draw_rect(Rect2(at.floor(), Vector2(3, 3)), spatter)
	draw_set_transform(Vector2.ZERO)


func _ink_box(rect: Rect2, ink: Color, width: float) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
	draw_polyline(points, ink, width)
