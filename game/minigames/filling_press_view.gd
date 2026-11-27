extends Control

signal pressed_input(command: int, pressed: bool, source: String)
signal input_cancelled

const Model = preload("res://game/minigames/filling_press_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const BACKDROP_PATH := "res://assets/minigames/filling-press-workbench.webp"
const PANEL := Rect2(36, 208, 792, 312)
const TRACK := Rect2(54, 555, 756, 10)
const COMMANDS := [Model.LEFT, Model.BOTH, Model.RIGHT, 0]
const TITLES := ["左模 · A", "雙模 · Space", "右模 · D", "AI · R"]
const ICONS := ["left", "grab", "right", "helper"]
const HINTS := ["按住左模，在放開線鬆手", "一起壓左右模", "按住右模，在放開線鬆手", "跟隨左模，在合模時補壓右模"]
const CREAM := Color("#fff0da")
const GOLD := Color("#ffd88f")
const RED := Color("#ffa99e")
const MINT := Color("#a5e7c7")

var _pointers: Dictionary = {}
var _buttons: Array[Button] = []
var _state: Dictionary = {}
var _font: Font
var _backdrop: Texture2D
var _scale := 0.0

static func button_rect(index: int) -> Rect2:
	if index < 0 or index >= COMMANDS.size():
		return Rect2()
	return Rect2(36 + index * 307, 609, 287, 75)

static func button_at(point: Vector2) -> int:
	for index in COMMANDS.size():
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

func _get_tooltip(point: Vector2) -> String:
	var index := button_at(point)
	if index == -1:
		if PANEL.has_point(point) and not _state.is_empty():
			return "點一次壓住，再點放開" if _state.assisted else "按住合模，到點放開"
		return ""
	if _state.get("assisted", false) and index < 3:
		return "點一次壓住，再點放開。回彈時點單側。"
	return HINTS[index]

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if ResourceLoader.exists(BACKDROP_PATH):
		_backdrop = load(BACKDROP_PATH)
	for index in COMMANDS.size():
		var button := Button.new()
		button.text = TITLES[index]
		button.clip_text = true
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		Props.skin_key(button, Props.KEY_PLUM, ICONS[index])
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_pressed_color", GOLD)
		add_child(button)
		button.position = button_rect(index).position
		button.size = button_rect(index).size
		_buttons.append(button)
	_refresh()

func _input(event: InputEvent) -> void:
	var source := pointer_source(event)
	if _pointers.has(source) and (not event.pressed or event.is_canceled()) and handle_pointer(event, Vector2.ZERO):
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if mouse_filter != Control.MOUSE_FILTER_IGNORE and handle_pointer(event, event.position if event is InputEventMouse or event is InputEventScreenTouch else Vector2.ZERO):
		accept_event()

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		if not _pointers.has(source):
			return false
		input_cancelled.emit()
		return true
	if not event.pressed:
		if not _pointers.has(source):
			return false
		var command: int = _pointers[source]
		_pointers.erase(source)
		pressed_input.emit(command, false, source)
		return true
	var index := button_at(point) if point.is_finite() else -1
	if index < 0 or _pointers.has(source):
		return false
	_pointers[source] = COMMANDS[index]
	pressed_input.emit(COMMANDS[index], true, source)
	return true

func clear_pointer_input() -> void:
	_pointers.clear()

func present(state: Dictionary) -> void:
	_state = state
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if _state.is_empty():
		return
	if _scale != Paper.text_scale() or _font != Paper.font():
		_scale = Paper.text_scale()
		_font = Paper.font()
		for button in _buttons:
			button.add_theme_font_override("font", _font)
			button.add_theme_font_size_override("font_size", roundi(19.0 * _scale))
	for index in 3:
		var command: int = COMMANDS[index]
		_buttons[index].set_pressed_no_signal((_state.held & command) == command)
	_buttons[3].set_pressed_no_signal(_state.helper)
	queue_redraw()

func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(36, 184), _state.feedback, GOLD, 20)
	Props.metal_plate(self, PANEL.grow(6), Props.BRASS, false)
	draw_rect(PANEL, Color("#302539"))
	if _backdrop != null:
		draw_texture_rect(_backdrop, PANEL, false)
	_draw_press()
	_draw_recipe()
	_draw_timing()

## Wafer with a pressed waffle grid, lit from the top left.
static func _wafer(color: Color) -> ImageTexture:
	return Pixels.bake("filling-wafer:" + color.to_html(false), Vector2i(72, 7), func(x: int, y: int) -> Color:
		if (x == 0 or x == 71) and (y == 0 or y == 6):
			return Pixels.CLEAR
		var tone := color
		if x % 6 == 0 or y == 3:
			tone = Props.deepen(color, 0.18)
		elif x % 6 == 1 or y == 0:
			tone = Props.lighten(color, 0.2)
		return Pixels.grainy(tone, x, y, 0.1))

## Soft filling that bulges between the wafers, with a glossy stripe.
static func _cream(color: Color) -> ImageTexture:
	return Pixels.bake("filling-cream:" + color.to_html(false), Vector2i(46, 5), func(x: int, y: int) -> Color:
		var bulge := 1 if x < 3 or x > 42 else 0
		if y < bulge or y > 4 - bulge:
			return Pixels.CLEAR
		if y == bulge:
			return Props.lighten(color, 0.35) if (x / 5) % 3 != 0 else Props.lighten(color, 0.15)
		return Props.deepen(color, 0.12) if y == 4 - bulge else color)

## A mold block: riveted iron frame round a copper die that glows when pressed.
func _mold(plate: Rect2, pressing: bool, label: String) -> void:
	Props.block_shadow(self, plate, Vector2(6, 8), 0.4)
	Props.metal_plate(self, plate, Color("#a87560"))
	var die := plate.grow(-16)
	Props.surface(self, die, "groove", Color("#c17e6b") if pressing else Color("#9d6b60"))
	_text(plate.position + Vector2(48, 70), label, CREAM, 23)

func _draw_press() -> void:
	var pressure: Vector2 = _state.pressure
	var center := Vector2(432, 362)
	var flatten := (pressure.x + pressure.y) * 0.5
	var width := 292.0 - 24.0 * flatten
	var filling_center := center.x + float(_state.offset) * 95.0
	var crust := Color("#e2a06b")
	var crisp := Color("#f6c38d")
	var fill_color := MINT if _state.phase == Model.REBOUND and absf(_state.offset) <= Model.CENTER_LIMIT else RED
	Props.contact_shadow(self, Vector2(center.x + 6, center.y + 56), width * 0.9, 0.45)
	draw_texture_rect(_wafer(crisp), Rect2(center.x - width / 2, center.y + 12 - flatten * 4, width, 28), false)
	draw_texture_rect(_cream(fill_color), Rect2(filling_center - 94, center.y - 11, 188, 22 - flatten * 7), false)
	draw_texture_rect(_wafer(crust), Rect2(center.x - width / 2, center.y - 44 + flatten * 8, width, 28), false)
	draw_line(Vector2(center.x, center.y - 55), Vector2(center.x, center.y - 25), CREAM, 2)
	draw_line(Vector2(center.x, center.y + 33), Vector2(center.x, center.y + 55), CREAM, 2)
	for index in 2:
		var shift: float = pressure[index] * 38.0
		var x: float = 141 + shift if index == 0 else 599 - shift
		var plate := Rect2(x, center.y - 59, 124, 116)
		# The piston rod that drives each mold in from the frame.
		var rod_from := PANEL.position.x + 4.0 if index == 0 else plate.end.x
		Props.shaded_box(self, Rect2(rod_from, center.y - 12, (plate.position.x if index == 0 else PANEL.end.x - 4.0) - rod_from, 22), Props.deepen(Color("#b4704f"), 0.2), 4.0)
		_mold(plate, pressure[index] > 0.0, "左" if index == 0 else "右")
	for index in range(_state.layers.size()):
		var x := 288.0 + 100.0 * index
		var filling_height: float = 6.0 + 12.0 * _state.layers[index]
		Props.contact_shadow(self, Vector2(x + 46, 470 + filling_height + 14), 92, 0.4)
		draw_texture_rect(_wafer(crust), Rect2(x, 461, 88, 8), false)
		draw_texture_rect(_cream(RED), Rect2(x + 2, 467, 84, filling_height), false)
		draw_texture_rect(_wafer(crisp), Rect2(x, 465 + filling_height, 88, 8), false)

func _draw_recipe() -> void:
	Props.wood_panel(self, Rect2(852, 208, 398, 392), Props.SIGN_PLUM, true)
	_text(Vector2(875, 248), "薄脆配方" if _state.layout == 0 else "厚餡配方", CREAM, 22)
	for index in range(_state.recipe.size()):
		var y := 272 + 66 * index
		var row := Rect2(869, y, 364, 54)
		var done: bool = index < _state.layers.size()
		var active: bool = index == _state.layers.size()
		Props.shaded_box(self, row, Color("#6b4558") if active else Color("#4a3448"), 6.0, done)
		if active:
			draw_rect(Rect2(row.position + Vector2(2, 2), Vector2(row.size.x - 4, 2)), GOLD)
		var kind := "薄餡 · 1 拍" if _state.recipe[index] == 1 else "厚餡 · 2 拍"
		_text(Vector2(885, y + (36 if done else 32)), "第 %d 層  %s" % [index + 1, kind], MINT if done else CREAM, 18)
	_text(Vector2(875, 500), "回彈置中  " + ("已達成" if _state.centered else "待完成"), MINT, 17)

func _draw_timing() -> void:
	var target: float = _state.target
	var range_end: float = target + _state.window
	var position := clampf(_state.clock / range_end, 0.0, 1.0)
	var label := "空拍 · 留空"
	Props.bar(self, TRACK, position, GOLD)
	if _state.phase == Model.PRESS:
		_marker(_state.start, range_end, "合模", MINT)
		_marker(target, range_end, "放開", CREAM)
		if _state.clock >= _state.start - _state.window:
			label = "放開" if _state.clock >= target - _state.window else ("保持按壓" if _state.held != 0 else "合模")
	elif _state.phase == Model.REBOUND:
		_marker(target, range_end, "回彈", MINT)
		if absf(_state.offset) > Model.CENTER_LIMIT:
			label = "回彈 · 輕壓%s側" % ("右" if _state.offset > 0.0 else "左")
		else:
			label = "餡已置中"
	_text(Vector2(875, 578), label, GOLD, 20)

func _marker(cue: float, range_end: float, label: String, color: Color) -> void:
	var x := TRACK.position.x + cue * TRACK.size.x / range_end
	var active: bool = absf(_state.clock - cue) <= _state.window
	draw_line(Vector2(x, 544), Vector2(x, 571), color, 5 if active else 2)
	_text(Vector2(x - 25, 597), label, color, 18 if active else 16)

func _text(at: Vector2, value: String, color: Color, size: int) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * _scale), color)
