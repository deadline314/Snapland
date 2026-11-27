extends RefCounted
## Short interface transitions shared by every panel, button and readout.
##
## Rules every effect follows:
## * State first, decoration second. Callers change visibility, focus and data
##   before calling in; nothing here delays or owns game state.
## * With reduced motion, or without a display (headless checks), each call
##   leaves the control in its final resting state immediately.
## * Effects only touch draw properties (modulate, self_modulate, scale and the
##   position of controls that no Container manages), so layout is unchanged.

const ENTER_SECONDS := 0.16
const FLASH_SECONDS := 0.18
const POP_SECONDS := 0.24
const RISE_SECONDS := 1.1
const STATIC_NOTE_SECONDS := 1.6
const HOVER_TINT := Color(1.16, 1.14, 1.08)
const PRESS_TINT := Color(0.8, 0.82, 0.86)
const GAIN_TINT := Color(1.35, 1.25, 0.9)

const _ENTER_TWEEN := &"paper_motion_enter"
const _ENTER_REST := &"paper_motion_enter_rest"
const _FLASH_TWEEN := &"paper_motion_flash"
const _POP_TWEEN := &"paper_motion_pop"

static var _reduced := false


static func set_reduced(value: bool) -> void:
	_reduced = value


static func has_display() -> bool:
	return DisplayServer.get_name() != "headless"


## True when animated transitions should play.
static func enabled() -> bool:
	return not _reduced and has_display()


static func _stop(node: Node, key: StringName) -> void:
	if not node.has_meta(key):
		return
	var running: Variant = node.get_meta(key)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	node.remove_meta(key)


static func _start(node: Node, key: StringName) -> Tween:
	_stop(node, key)
	var tween := node.create_tween()
	node.set_meta(key, tween)
	return tween


## Fade and slide a control into its resting place. Only for controls whose
## position no Container manages (full-rect layers, anchored HUD pieces).
static func enter(control: Control, from_offset := Vector2(0.0, 14.0), seconds := ENTER_SECONDS) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var rest: Vector2 = control.get_meta(_ENTER_REST, control.position)
	_stop(control, _ENTER_TWEEN)
	control.position = rest
	control.modulate.a = 1.0
	if not enabled():
		return
	control.set_meta(_ENTER_REST, rest)
	control.position = rest + from_offset
	control.modulate.a = 0.0
	var tween := _start(control, _ENTER_TWEEN).set_parallel(true)
	tween.tween_property(control, "position", rest, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, seconds * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(control.remove_meta.bind(_ENTER_REST))


## Fade a layer in without moving it.
static func fade_in(item: CanvasItem, seconds := ENTER_SECONDS) -> void:
	if not is_instance_valid(item) or not item.is_inside_tree():
		return
	_stop(item, _ENTER_TWEEN)
	item.modulate.a = 1.0
	if not enabled():
		return
	item.modulate.a = 0.0
	_start(item, _ENTER_TWEEN).tween_property(item, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Brief tint that settles back to the untinted face (hover, focus, press).
static func flash(item: CanvasItem, tint := HOVER_TINT, seconds := FLASH_SECONDS) -> void:
	if not is_instance_valid(item) or not item.is_inside_tree():
		return
	_stop(item, _FLASH_TWEEN)
	item.self_modulate = Color.WHITE
	if not enabled():
		return
	item.self_modulate = tint
	_start(item, _FLASH_TWEEN).tween_property(item, "self_modulate", Color.WHITE, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Springy size pulse around the control's centre, for values that just changed.
static func pop(control: Control, peak := 1.18, seconds := POP_SECONDS) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	_stop(control, _POP_TWEEN)
	control.scale = Vector2.ONE
	if not enabled():
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * peak
	_start(control, _POP_TWEEN).tween_property(control, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Let a short-lived note rise and fade, then free it. With reduced motion the
## note stays still for a moment instead; without a display it is freed at once.
static func rise_and_free(note: Control, distance := 30.0, seconds := RISE_SECONDS) -> void:
	if not is_instance_valid(note) or not note.is_inside_tree():
		return
	if not has_display():
		note.queue_free()
		return
	var tween := note.create_tween()
	if _reduced:
		tween.tween_interval(STATIC_NOTE_SECONDS)
	else:
		tween.set_parallel(true)
		tween.tween_property(note, "position:y", note.position.y - distance, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(note, "modulate:a", 0.0, seconds * 0.45).set_delay(seconds * 0.55)
		tween.chain()
	tween.tween_callback(note.queue_free)


## Give a button hover, focus and press feedback. Safe to call once per button.
static func attach_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta(&"paper_motion_bound"):
		return
	button.set_meta(&"paper_motion_bound", true)
	button.mouse_entered.connect(_button_flash.bind(button, HOVER_TINT))
	button.focus_entered.connect(_button_flash.bind(button, HOVER_TINT))
	button.button_down.connect(_button_flash.bind(button, PRESS_TINT))


static func _button_flash(button: BaseButton, tint: Color) -> void:
	if is_instance_valid(button) and not button.disabled:
		flash(button, tint)
