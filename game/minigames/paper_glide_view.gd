extends Control

signal command(action: int, pressed: bool, source: String)
signal pointer_cancelled

const Model = preload("res://game/minigames/paper_glide_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const BACKDROP := "res://assets/minigames/paper-glide-workshop.webp"
const COURSE := Rect2(34, 191, 872, 323)
const RADAR := Rect2(928, 191, 316, 323)
const INK := Color("#ecf3de")
const TEAL := Color("#91eace")
const GOLD := Color("#ffd687")
const PINK := Color("#f5a9a0")
const MUTED := Color("#77939e")
enum { WIDE, NARROW, LESS, MORE, LEFT, RIGHT, THROW, AI }
const LABELS := ["寬翼 · 1", "窄翼 · 2", "減投力 · S", "加投力 · W", "摺左翼 · A", "摺右翼 · D", "投出 · Space", "摺翼 AI · R"]
const HINTS := ["較慢、下沉少，翼尖需要更多窗寬", "較快、下沉多，能穿較窄空間", "降低紙機的初速", "增加紙機的初速",
	"沿已選折線摺左翼", "沿已選折線摺右翼", "雙翼摺好後投出", "按一側後，AI 沿同一折線摺另一翼"]

var _pointers: Dictionary = {}
var _buttons: Array[Button] = []
var _state: Dictionary = {}
var _font: Font
var _texture: Texture2D
var _scale := 1.0

static func button_rect(slot: int) -> Rect2:
	if slot < 0 or slot >= LABELS.size():
		return Rect2()
	return Rect2(35 + (slot % 4) * 306, 533 if slot < 4 else 617, 288, 74)

static func hit_slot(point: Vector2) -> int:
	if point.is_finite():
		for index in LABELS.size():
			if button_rect(index).has_point(point):
				return index
	return -1

static func is_active(slot: int, state: Dictionary) -> bool:
	match int(state.get("phase", Model.FINISHED)):
		Model.SETUP: return slot >= 0 and slot < LABELS.size()
		Model.FLIGHT: return slot == LEFT or slot == RIGHT or (slot == THROW and state.assisted)
		Model.MISSED: return slot == THROW
	return false

static func pointer_source(event: InputEvent) -> String:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if not is_active(slot, _state):
		return ""
	if _state.phase == Model.SETUP:
		return HINTS[slot]
	match slot:
		LEFT: return "按住向左轉，放開回正"
		RIGHT: return "按住向右轉，放開回正"
		THROW: return "收回紙機後可重摺或改投力"
	return ""

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if ResourceLoader.exists(BACKDROP):
		_texture = load(BACKDROP)
	var normal := Paper.button_box(Color("#24434b"), Color("#79a5a3"))
	var selected := Paper.button_box(Color("#375762"), GOLD)
	for index in LABELS.size():
		var button := Button.new()
		button.clip_text = true
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_color_override("font_color", INK)
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
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if mouse_filter != Control.MOUSE_FILTER_IGNORE and handle_pointer(event, event.position):
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
	if not is_active(slot, _state) or _pointers.has(source):
		return false
	_pointers[source] = slot
	command.emit(slot, true, source)
	return true

func clear_pointers() -> void:
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
	for index in _buttons.size():
		_buttons[index].visible = is_active(index, _state)
	var setup: bool = _state.phase == Model.SETUP
	var flying: bool = _state.phase == Model.FLIGHT
	_buttons[LEFT].text = LABELS[LEFT] if setup else "左舵 · A"
	_buttons[RIGHT].text = LABELS[RIGHT] if setup else "右舵 · D"
	_buttons[THROW].text = LABELS[THROW] if setup else "收回重摺 · Space"
	for index in [WIDE, NARROW]:
		_buttons[index].text = LABELS[index]
		_buttons[index].set_pressed_no_signal(_state.fold == index)
	for index in [LESS, MORE, AI]:
		_buttons[index].text = LABELS[index]
	_buttons[AI].set_pressed_no_signal(_state.helper)
	_buttons[LEFT].set_pressed_no_signal((setup and (_state.folded & Model.LEFT) != 0) or (flying and _state.steer < 0.0))
	_buttons[RIGHT].set_pressed_no_signal((setup and (_state.folded & Model.RIGHT) != 0) or (flying and _state.steer > 0.0))
	queue_redraw()

static func _project(point: Vector3) -> Vector2:
	# A fixed oblique camera keeps altitude and depth readable at the same scale on retries.
	return Vector2(86.0 + point.z * 22.9 + point.x * 8.2, 465.0 - point.y * 40.0 + point.x * 10.0)

static func _overhead(point: Vector3) -> Vector2:
	return Vector2(1086.0 + point.x * 26.0, 484.0 - point.z * 4.8)

func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(34, 166), _state.feedback, GOLD, 19)
	draw_rect(COURSE.grow(2), MUTED)
	draw_rect(COURSE, Color("#1a363c"))
	if _texture != null:
		draw_texture_rect(_texture, COURSE, false)
	_draw_course()
	_draw_radar()
	if _state.phase == Model.SETUP:
		_draw_fold_preview()

func _draw_course() -> void:
	for lane in [-3.5, 0.0, 3.5]:
		draw_line(_project(Vector3(lane, 0, 0)), _project(Vector3(lane, 0, 33)), Color("#47626c"), 2.0)
	for index in _state.windows.size():
		var window: Dictionary = _state.windows[index]
		var color := TEAL if index < int(_state.passed) else GOLD
		var center: Vector3 = window.center
		var width: float = window.half_width
		var height: float = window.half_height
		var corners := PackedVector2Array()
		for offset in [Vector2(-width, -height), Vector2(-width, height), Vector2(width, height), Vector2(width, -height)]:
			corners.append(_project(center + Vector3(offset.x, offset.y, 0)))
		var fill := color
		fill.a = 0.20
		draw_colored_polygon(corners, fill)
		corners.append(corners[0])
		draw_polyline(corners, color, 4.0, true)
		_text(_project(center + Vector3(0, height, 0)) + Vector2(16, 11), "風窗 %d" % (index + 1), color, 15)
	var basket := _project(_state.basket)
	draw_rect(Rect2(basket - Vector2(24, 2), Vector2(48, 28)), Color("#8d6940"))
	draw_line(basket - Vector2(28, 2), basket + Vector2(28, -2), GOLD, 4)
	_text(basket + Vector2(-27, 48), "包裝籃", INK, 16)
	var bell := _project(_state.bell)
	draw_line(bell, bell + Vector2(0, -25), PINK, 2)
	draw_circle(bell, 8, TEAL if _state.braked else PINK)
	_text(bell + Vector2(-28, -31), "減速鈴", PINK, 15)
	if _state.phase == Model.SETUP and _state.assisted:
		for point: Vector3 in _state.preview:
			draw_circle(_project(point), 3, TEAL)
	_draw_paper()

func _draw_paper() -> void:
	var center: Vector3 = _state.position
	var base := _project(center + Vector3(0, -0.08, -0.55))
	var nose := _project(center + Vector3(0, 0.10, 1.07))
	var offset := Model.wing_offset(_state.fold, _state.bank)
	for side in [-1.0, 1.0]:
		var tip := _project(center + side * offset)
		draw_colored_polygon(PackedVector2Array([base, nose, tip]), INK if side < 0.0 else TEAL)
		draw_circle(tip, 3.5, GOLD)
	draw_line(base, nose, Color("#497c7f"), 2.0)

func _draw_radar() -> void:
	draw_rect(RADAR, Color("#183747"))
	draw_rect(RADAR, MUTED, false, 2)
	_text(Vector2(947, 223), "%s · %s" % [_state.course_name, "寬翼" if _state.fold == 0 else "窄翼"], INK, 19)
	_text(Vector2(947, 255), "投力 %d/3   側風向%s" % [int(_state.power) + 1, "右" if _state.wind > 0.0 else "左"], GOLD, 17)
	_text(Vector2(947, 284), "● 翼尖位置  ▬ 風窗", INK, 15)
	draw_rect(Rect2(952, 309, 268, 178), Color("#142e3a"))
	draw_line(Vector2(1086, 311), Vector2(1086, 487), Color("#425a67"), 2.0)
	for index in _state.windows.size():
		var window: Dictionary = _state.windows[index]
		var mid := _overhead(window.center)
		var span: float = window.half_width * 26.0
		draw_line(mid - Vector2(span, 0), mid + Vector2(span, 0), TEAL if index < int(_state.passed) else GOLD, 5.0)
		draw_string(_font, mid + Vector2(span + 8, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * _scale), INK)
	var basket := _overhead(_state.basket)
	draw_rect(Rect2(basket - Vector2(28, 5), Vector2(56, 10)), GOLD, false, 2)
	draw_circle(_overhead(_state.bell), 5, TEAL if _state.braked else PINK)
	var center: Vector3 = _state.position
	var side := Model.wing_offset(_state.fold, _state.bank)
	draw_line(_overhead(center - side), _overhead(center + side), INK, 3.0)
	draw_circle(_overhead(center - side), 4, TEAL)
	draw_circle(_overhead(center + side), 4, TEAL)
	if _state.phase == Model.FLIGHT:
		_text(Vector2(947, 505), "速度 %.1f%s" % [_state.speed, " · 已擦鈴" if _state.braked else " · 按住調舵"], INK, 16)
	elif _state.assisted and _state.phase == Model.SETUP:
		_text(Vector2(947, 505), "綠點為首段預估路線", TEAL, 16)

func _draw_fold_preview() -> void:
	var card := Rect2(53, 353, 203, 144)
	draw_rect(card, Color("#243d49"))
	draw_rect(card, MUTED, false, 2)
	_text(Vector2(67, 384), "摺翼 %d / 2" % (int((_state.folded & Model.LEFT) != 0) + int((_state.folded & Model.RIGHT) != 0)), INK, 16)
	var inset := Vector2(155, 443)
	var span := 71.0 if _state.fold == 0 else 46.0
	var nose := inset - Vector2(0, 40)
	for side in [-1, 1]:
		var folded: bool = (_state.folded & (Model.LEFT if side < 0 else Model.RIGHT)) != 0
		var tip := inset + Vector2(side * (span if folded else 79.0), 22)
		var edge := inset + Vector2(0, 34)
		draw_colored_polygon(PackedVector2Array([nose, tip, edge]), TEAL if folded else Color("#a9b6a6"))
		draw_dashed_line(nose, edge + Vector2(side * span * 0.42, -14), Color("#305a62"), 2.0, 5)

func _text(at: Vector2, value: String, color: Color, size: int) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * _scale), color)
