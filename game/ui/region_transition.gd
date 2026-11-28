extends Control
## Covers the screen while a region is swapped, then opens onto the new place.
##
## The swap itself blocks the main thread, so the cover must be fully drawn
## before the caller starts it: wait for `covered`, swap, then call `reveal()`.

signal covered
signal revealed

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const IRIS_SHADER := preload("res://game/ui/region_transition.gdshader")
const CLOSE_SECONDS := 0.34
const OPEN_SECONDS := 0.46
const FADE_SECONDS := 0.14

var _iris: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _busy := false


func _init() -> void:
	name = "RegionTransition"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# The cover carries no words: a place is named by its own gate, the HUD
	# nameplate and, on a first visit, the arrival stamp (ART-66).
	_iris = ColorRect.new()
	_iris.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = IRIS_SHADER
	_iris.material = _material
	add_child(_iris)


## True from the start of the cover until the reveal has finished.
func busy() -> bool:
	return _busy


## Close over the current view. `covered` fires once the screen is hidden.
func cover(ink: Color, accent: Color) -> void:
	_stop()
	_busy = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_material.set_shader_parameter("ink", ink)
	_material.set_shader_parameter("accent", accent)
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_tween = create_tween()
	if PaperMotion.enabled():
		_set_closed(0.0)
		_material.set_shader_parameter("plain_fade", false)
		_tween.tween_method(_set_closed, 0.0, 1.0, CLOSE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		_material.set_shader_parameter("plain_fade", true)
		_set_closed(0.0)
		_tween.tween_method(_set_closed, 0.0, 1.0, FADE_SECONDS)
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
		_tween.tween_interval(0.08)
		_tween.tween_method(_set_closed, 1.0, 0.0, OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_method(_set_closed, 1.0, 0.0, FADE_SECONDS)
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
