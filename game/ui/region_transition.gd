extends Control
## Covers the screen while a region is swapped, then opens onto the new place.
##
## The swap itself blocks the main thread, so the cover must be fully drawn
## before the caller starts it: wait for `covered`, swap, then call `reveal()`.

signal covered
signal revealed

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const IRIS_SHADER := preload("res://game/ui/region_transition.gdshader")
const CLOSE_SECONDS := 0.34
const OPEN_SECONDS := 0.46
const FADE_SECONDS := 0.14
const TITLE_HOLD_SECONDS := 0.9

var _iris: ColorRect
var _material: ShaderMaterial
var _title: Label
var _eyebrow: Label
var _tween: Tween
var _busy := false


func _init() -> void:
	name = "RegionTransition"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_iris = ColorRect.new()
	_iris.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = IRIS_SHADER
	_iris.material = _material
	add_child(_iris)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sit above the middle so the arrival title never covers the player.
	stack.offset_top = -190.0
	stack.offset_bottom = -110.0
	add_child(stack)
	_eyebrow = Label.new()
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.add_theme_font_size_override("font_size", 16)
	stack.add_child(_eyebrow)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	stack.add_child(_title)
	# The title lingers over the revealed scene for a moment, so it hangs on its
	# own signboard; the small line above it keeps an ink outline instead.
	var board := Paper.signboard()
	board.content_margin_left = 34
	board.content_margin_right = 34
	_title.add_theme_stylebox_override("normal", board)
	_eyebrow.add_theme_color_override("font_outline_color", Color("#06141c"))
	_eyebrow.add_theme_constant_override("outline_size", 8)


## True from the start of the cover until the reveal has finished.
func busy() -> bool:
	return _busy


## Close over the current view. `covered` fires once the screen is hidden.
func cover(title: String, eyebrow: String, ink: Color, accent: Color) -> void:
	_stop()
	_busy = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = title
	_eyebrow.text = eyebrow
	_title.add_theme_color_override("font_color", Color("#f0f0d8"))
	_eyebrow.add_theme_color_override("font_color", accent)
	_material.set_shader_parameter("ink", ink)
	_material.set_shader_parameter("accent", accent)
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_set_labels_alpha(0.0)
	_tween = create_tween()
	if PaperMotion.enabled():
		_set_closed(0.0)
		_material.set_shader_parameter("plain_fade", false)
		_tween.tween_method(_set_closed, 0.0, 1.0, CLOSE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		_material.set_shader_parameter("plain_fade", true)
		_set_closed(0.0)
		_tween.tween_method(_set_closed, 0.0, 1.0, FADE_SECONDS)
	_tween.tween_method(_set_labels_alpha, 0.0, 1.0, 0.08)
	# The swap blocks drawing; give the renderer one finished frame of the cover first.
	_tween.tween_interval(0.05)
	_tween.tween_callback(covered.emit)


## Open onto the new view and release input when done.
func reveal() -> void:
	_stop()
	if not visible:
		_finish()
		return
	_set_closed(1.0)
	_tween = create_tween()
	if PaperMotion.enabled():
		_tween.tween_interval(0.12)
		_tween.tween_method(_set_closed, 1.0, 0.0, OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_method(_set_labels_alpha, 1.0, 0.0, TITLE_HOLD_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	else:
		_tween.tween_method(_set_closed, 1.0, 0.0, FADE_SECONDS)
		_tween.parallel().tween_method(_set_labels_alpha, 1.0, 0.0, FADE_SECONDS)
	_tween.tween_callback(_finish)


## Drop the cover immediately (quit, or the swap was abandoned).
func cancel() -> void:
	_stop()
	_finish()


func _finish() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var was_busy := _busy
	_busy = false
	if was_busy:
		revealed.emit()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _set_closed(amount: float) -> void:
	_material.set_shader_parameter("closed", amount)


func _set_labels_alpha(alpha: float) -> void:
	_title.modulate.a = alpha
	_eyebrow.modulate.a = alpha
