extends Control

signal command(action: int, pressed: bool, source: String)
signal pointer_cancelled

const Paper = preload("res://game/ui/paper_ui.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const CONTROL_COUNT := 8
## Room left of the label for the key's icon, and how far a held cap sinks.
const KEY_ICON_ROOM := 46.0
const KEY_SINK := 6.0
var _buttons: Array[Button] = []
var _pointers: Dictionary = {}
var _font: Font
var _scale := 0.0

static func button_rect(slot: int) -> Rect2:
	if slot < 0 or slot >= CONTROL_COUNT:
		return Rect2()
	return Rect2(35 + (slot % 4) * 306, 533 if slot < 4 else 617, 288, 74)

static func hit_slot(point: Vector2) -> int:
	if point.is_finite():
		for index in CONTROL_COUNT:
			if button_rect(index).has_point(point):
				return index
	return -1

static func pointer_source(event: InputEvent) -> String:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

func build_controls(labels: Array, normal: Color, active: Color, edge: Color, accent: Color) -> void:
	assert(labels.size() <= CONTROL_COUNT and _buttons.is_empty())
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var normal_box := Paper.button_box(normal, edge)
	var active_box := Paper.button_box(active, accent)
	for index in labels.size():
		var button := Button.new()
		button.text = labels[index]
		button.clip_text = true
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", normal_box)
		button.add_theme_stylebox_override("pressed", active_box)
		button.add_theme_color_override("font_color", Color("#fff1de"))
		add_child(button)
		button.position = button_rect(index).position
		button.size = button_rect(index).size
		_buttons.append(button)
	refresh_font()

## Paints the buttons as physical key caps with an icon each (the shared pixel
## kit). Every Button stays as it was (name, rect, text, state); only its frame is
## replaced by a cap drawn underneath, so tests and input are unaffected.
func use_key_caps(icons: Array, tone: Color) -> void:
	assert(not _buttons.is_empty() and icons.size() == _buttons.size())
	var bed := KeyBed.new()
	bed.name = "KeyBed"
	bed.buttons = _buttons
	bed.icons = icons
	bed.tone = tone
	add_child(bed)
	move_child(bed, 0)
	for button in _buttons:
		for style in ["normal", "hover", "focus", "disabled"]:
			button.add_theme_stylebox_override(style, _key_text_box(false))
		for style in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(style, _key_text_box(true))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for colour in ["font_color", "font_hover_color", "font_focus_color"]:
			button.add_theme_color_override(colour, Color("#f6ecd8"))
		for colour in ["font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(colour, Color("#ffe3a8"))
		button.add_theme_color_override("font_disabled_color", Color("#a3968c"))

static func _key_text_box(held: bool) -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = KEY_ICON_ROOM
	box.content_margin_right = 8.0
	box.content_margin_top = KEY_SINK if held else 0.0
	box.content_margin_bottom = 8.0 - (KEY_SINK if held else 0.0)
	return box

func refresh_font() -> void:
	var font := Paper.font()
	var scale := Paper.text_scale()
	if _scale == scale and _font == font:
		return
	_scale = scale
	_font = font
	for button in _buttons:
		button.add_theme_font_override("font", _font)
		button.add_theme_font_size_override("font_size", roundi(19.0 * scale))

func _input(event: InputEvent) -> void:
	var source := pointer_source(event)
	if _pointers.has(source) and (not event.pressed or event.is_canceled()) and handle_pointer(event, Vector2.ZERO):
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and mouse_filter != Control.MOUSE_FILTER_IGNORE:
		if handle_pointer(event, event.position):
			accept_event()

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		if not _pointers.has(source):
			return false
		pointer_cancelled.emit()
		return true
	if not event.pressed:
		if not _pointers.has(source):
			return false
		var slot: int = _pointers[source]
		_pointers.erase(source)
		command.emit(slot, false, source)
		return true
	var slot := hit_slot(point)
	if slot < 0 or slot >= _buttons.size() or not _buttons[slot].visible or _buttons[slot].disabled or _pointers.has(source):
		return false
	_pointers[source] = slot
	command.emit(slot, true, source)
	return true

func clear_pointers() -> void:
	_pointers.clear()


## Draws the caps under the buttons and repaints only when a button's pressed,
## disabled or visible state changes (one int compared per frame).
class KeyBed extends Control:
	var buttons: Array[Button] = []
	var icons: Array = []
	var tone := Color("#5a3a34")
	var _signature := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _process(_delta: float) -> void:
		var signature := 0
		for index in buttons.size():
			var button := buttons[index]
			signature |= (int(button.button_pressed) | int(button.disabled) << 1 | int(button.visible) << 2) << (index * 3)
		if signature != _signature:
			_signature = signature
			queue_redraw()

	func _draw() -> void:
		for index in buttons.size():
			var button := buttons[index]
			if not button.visible:
				continue
			var rect := Rect2(button.position, button.size)
			var held := button.button_pressed and not button.disabled
			# A spent key sinks into the stall's shadow instead of turning harbour grey.
			Props.key_cap(self, rect, held, true, tone if not button.disabled else tone.lerp(Color("#1c1216"), 0.55))
			var ink := Color("#ffc66d") if held else (Color("#f2d9a6") if not button.disabled else Color("#8c7f78"))
			Props.icon(self, str(icons[index]), rect.position + Vector2(25, (rect.size.y - 8.0) * 0.5 + (KEY_SINK if held else 0.0)), ink)
