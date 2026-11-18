extends Control
class_name ChocolateEtchingView

signal input_requested(event: InputEvent, design_point: Vector2)
signal clear_requested

const Paper = preload("res://game/ui/paper_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const BOARD_SIZE := Vector2(720, 440)
const BOARD_PANEL := Rect2(24, 242, 880, 390)
const COMMAND_PANEL := Rect2(916, 242, 340, 390)
const BOARD_SCALE := BOARD_PANEL.size.y / BOARD_SIZE.y
const WORKSPACE := Rect2(BOARD_PANEL.position + (BOARD_PANEL.size - BOARD_SIZE * BOARD_SCALE) / 2.0, BOARD_SIZE * BOARD_SCALE)
const COMMANDS := ["left", "right", "up", "down", "select", "shallow", "deep", "tool", "fold", "phase", "undo", "helper"]
const KEYS := {
	KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right",
	KEY_W: "up", KEY_UP: "up", KEY_S: "down", KEY_DOWN: "down",
	KEY_TAB: "select", KEY_Q: "shallow", KEY_E: "deep", KEY_SPACE: "tool",
	KEY_F: "fold", KEY_M: "phase", KEY_X: "undo", KEY_R: "helper"
}
const KEY_LABELS := ["A / ←", "D / →", "W / ↑", "S / ↓", "Tab", "Q", "E", "Space", "F", "M", "X", "R"]
const ACTION_LABELS := ["左移", "右移", "上移", "下移", "換輪", "淺切", "深切", "下刀", "折料", "試裝", "撤銷", "AI夾持"]
const TOOLTIPS := {
	"tool": "在畫布內放開提交，外側放開取消",
	"shallow": "淺切可重描保料",
	"phase": "挑戰小惡魔時，先折出惰輪再試轉",
	"undo": "撤銷不回時間",
	"helper": "AI 只夾持"
}
const BENCH := Color("#1e3c44")
const GRID := Color("#30525a")
const COCOA := Color("#804a38")
const EDGE := Color("#332422")
const PART_COLORS := [Color("#d59864"), Color("#daac75"), Color("#bd835a"), Color("#8ac9a8")]

var _state: Dictionary = {}
var _labels: Dictionary = {}
var _buttons: Dictionary = {}
var _part_labels: Array[Label] = []
var _normal_style: StyleBoxFlat
var _held_style: StyleBoxFlat
var _font: Font
var _text_scale := 0.0
var _canvas: Node2D

static func key_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode else event.keycode

static func pointer_source(event: InputEvent) -> String:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventMouseMotion:
		return "mouse"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d" % event.index
	return ""

static func button_rect(command: String) -> Rect2:
	var index := COMMANDS.find(command)
	if index < 0:
		return Rect2()
	var cell := COMMAND_PANEL.size / Vector2(3, 4)
	return Rect2(COMMAND_PANEL.position + Vector2(index % 3, floori(index / 3.0)) * cell + Vector2(4, 4), cell - Vector2(8, 8))

static func command_at(design_point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(design_point):
			return command
	return ""

static func command_center(command: String) -> Vector2:
	return button_rect(command).get_center()

static func board_to_design(board_point: Vector2) -> Vector2:
	return WORKSPACE.position + board_point * BOARD_SCALE

static func design_to_board(design_point: Vector2) -> Vector2:
	return (design_point - WORKSPACE.position) / BOARD_SCALE

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_exited.connect(clear_requested.emit)
	var clip := Control.new()
	clip.name = "ClippedWorkspace"
	clip.position = WORKSPACE.position
	clip.size = WORKSPACE.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_canvas = Node2D.new()
	_canvas.name = "BoardCanvas"
	_canvas.scale = Vector2.ONE * BOARD_SCALE
	_canvas.draw.connect(_draw_board)
	clip.add_child(_canvas)
	_normal_style = Paper.button_box(Paper.FRAME, GRID)
	_held_style = Paper.button_box(Color("#4b4c3b"), Paper.GOLD)
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var button := Button.new()
		button.name = command.capitalize()
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.add_theme_stylebox_override("normal", _normal_style)
		button.add_theme_stylebox_override("pressed", _held_style)
		button.add_theme_color_override("font_color", Paper.PAPER)
		button.add_theme_color_override("font_pressed_color", Paper.GOLD)
		add_child(button)
		button.position = button_rect(command).position
		button.size = button_rect(command).size
		_buttons[command] = button
	_add_label("Mode", Rect2(40, 146, 580, 44), 29, Paper.PAPER)
	_add_label("Stock", Rect2(40, 186, 760, 27), 18, Paper.TEAL)
	_add_label("Instruction", Rect2(40, 211, 1200, 28), 18, Paper.PAPER)
	_add_label("Time", Rect2(840, 149, 396, 33), 22, Paper.GOLD)
	_add_label("Progress", Rect2(790, 186, 446, 27), 18, Paper.TEAL)
	_labels.Time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_labels.Progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_label("Guide", Rect2(36, 258, 102, 34), 18, Paper.GOLD)
	_add_label("Legend", Rect2(796, 258, 100, 34), 18, Paper.TEAL)
	_add_label("Margin", Rect2(36, 572, 102, 38), 16, Paper.PAPER)
	_add_label("Route", Rect2(796, 572, 100, 38), 16, Paper.PAPER)
	_add_label("Feedback", Rect2(40, 638, 1200, 33), 22, Paper.GOLD)
	_add_label("Scoring", Rect2(40, 672, 1200, 39), 17, Paper.PAPER)
	for i in 4:
		var label := _add_label("Gear%d" % (i + 1), Rect2(0, 0, 20, 22), 16, Paper.PAPER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = str(i + 1)
		_part_labels.append(label)
	_apply_snapshot()
	grab_focus()

func _add_label(label_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.set_meta("base_font", font_size)
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	_labels[label_name] = label
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree()):
		clear_requested.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not KEYS.has(key_code(event)):
			return
	elif pointer_source(event).is_empty():
		return
	var point: Vector2 = Vector2.ZERO if event is InputEventKey else event.position
	input_requested.emit(event, point)
	accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	if WORKSPACE.has_point(at_position) and _state.get("phase") == "craft":
		return TOOLTIPS.tool
	return TOOLTIPS.get(command_at(at_position), "")

func present(state: Dictionary, _time_phase: String, _reduced_motion: bool) -> void:
	_state = state
	if is_node_ready():
		_apply_snapshot()
		_canvas.queue_redraw()
	queue_redraw()

func _apply_snapshot() -> void:
	if _state.is_empty():
		return
	var font := Paper.font()
	var text_scale := Paper.text_scale()
	if _font != font or _text_scale != text_scale:
		_font = font
		_text_scale = text_scale
		for label: Label in _labels.values():
			label.add_theme_font_override("font", _font)
			label.add_theme_font_size_override("font_size", roundi(label.get_meta("base_font") * _text_scale))
		for button: Button in _buttons.values():
			button.add_theme_font_override("font", _font)
			button.add_theme_font_size_override("font_size", roundi(18.0 * _text_scale))
	var craft: bool = _state.phase == "craft"
	var part: Dictionary = _state.parts[_state.selected]
	var assist := " · 輔助吸附" if _state.assisted else ""
	var helper := "AI 關"
	if _state.helper:
		helper = "AI 已夾持" if _state.helper_clamp != null else "AI 無夾點"
	_labels.Mode.text = "巧克力蝕刻  ／  " + ("工藝板" if craft else "試裝板")
	_labels.Stock.text = "板材 %s  ·  %d 號%s  ·  %d 齒  ·  %s%s" % [
		"A" if _state.variant == 0 else "B", _state.selected + 1, "惰輪" if _state.selected == 3 else "主輪", part.teeth, helper, assist]
	_labels.Time.text = "%d 秒   ·   %d 分" % [ceili(_state.remaining), _state.score]
	_labels.Instruction.text = "拖曳或按住空白配方向鍵描線。畫布內放開提交，外側取消。淺切沿原線重描，切透一圈再折料。" if craft else "拖曳放置，或移游標後按 F。原位按 F 取下。對準兩軸及中心距，按住空白讓出口轉滿一圈。"
	var direction := "靜止" if is_zero_approx(_state.output_omega) else ("順時針" if _state.output_omega > 0.0 else "逆時針")
	_labels.Progress.text = ("切深 %.2f  ·  %d / 8 筆" % [_state.depth, _state.selected_strokes.size()]) if craft else ("出口 %d%%  ·  %s" % [roundi(100.0 * _state.output_travel / TAU), direction])
	_labels.Guide.text = "切線引導" if craft else "接觸線"
	_labels.Legend.text = "深度熱線" if craft else "放置預覽"
	_labels.Margin.text = "主輪 %d / 3" % _state.get("main_freed", 0) if craft else "金圈入軸"
	_labels.Route.text = "剩料惰輪" if craft else "綠圈出軸"
	_labels.Feedback.text = str(_state.feedback)
	if _state.success:
		_labels.Feedback.text = "出口已轉滿一圈，剩料惰輪也在傳動路徑中" if _state.devil else "出口已轉滿一圈"
	elif not is_zero_approx(_state.output_omega):
		_labels.Feedback.text = "出口正在轉動。繼續按住轉動，直到出口轉滿一圈。"
	_labels.Scoring.text = "可撤銷最近 8 次熱線、折料或放置，時間照走。AI 只夾持，輔助可吸附。乾淨三輪 400 分，剩料惰輪串入 500 分。"
	for i in 4:
		var gear: Dictionary = _state.parts[i]
		var label := _part_labels[i]
		label.visible = not gear.freed if craft else gear.mounted
		var center: Vector2 = gear.source_center if craft else gear.position
		label.position = board_to_design(center) - Vector2(10, 11)
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var action: String = ACTION_LABELS[i]
		if not craft:
			match command:
				"tool": action = "轉動"
				"fold": action = "放／取"
				"phase": action = "工藝"
		var button: Button = _buttons[command]
		button.text = KEY_LABELS[i] + "\n" + action
		button.set_pressed_no_signal(command in _state.get("held_commands", []) or (command == "tool" and (_state.cutting or _state.driving)))

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 573), Paper.DEEP)
	draw_rect(Rect2(24, 140, 1232, 98), Paper.DEEP_TEAL)
	draw_rect(Rect2(24, 140, 4, 98), Paper.TEAL)
	draw_rect(BOARD_PANEL, Color("#122d37"))
	draw_rect(COMMAND_PANEL, Paper.DEEP_TEAL)
	draw_rect(Rect2(24, 636, 1232, 36), Paper.DEEP_TEAL)
	if _state.is_empty():
		return
	var craft: bool = _state.phase == "craft"
	if craft:
		draw_dashed_line(Vector2(37, 300), Vector2(125, 300), Paper.GOLD, 2, 7, true)
		draw_dashed_line(Vector2(37, 310), Vector2(125, 310), Paper.TEAL, 2, 7, true)
		draw_line(Vector2(798, 300), Vector2(888, 300), Paper.CORAL.lerp(Paper.GOLD, _state.depth), 4, true)
	else:
		draw_line(Vector2(37, 300), Vector2(125, 300), Paper.TEAL, 2, true)
		draw_dashed_line(Vector2(798, 300), Vector2(888, 300), Paper.TEAL, 2, 7, true)
		var gauge := Rect2(40, 613, 90, 6)
		draw_rect(gauge, GRID)
		draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * _state.output_travel / TAU, gauge.size.y)), Paper.TEAL)

func _draw_board() -> void:
	if _state.is_empty():
		return
	_canvas.draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), BENCH)
	for x in range(20, 720, 20):
		_canvas.draw_line(Vector2(x, 0), Vector2(x, 440), GRID)
	for y in range(20, 440, 20):
		_canvas.draw_line(Vector2(0, y), Vector2(720, y), GRID)
	if _state.phase == "craft":
		_draw_material()
	else:
		_draw_assembly()
	var cursor: Vector2 = _state.cursor
	_canvas.draw_arc(cursor, 8, 0, TAU, 20, Paper.GOLD, 1.5, true)
	_canvas.draw_line(cursor - Vector2(11, 0), cursor + Vector2(11, 0), Paper.GOLD, 1.4, true)
	_canvas.draw_line(cursor - Vector2(0, 11), cursor + Vector2(0, 11), Paper.GOLD, 1.4, true)
	_canvas.draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Paper.FRAME, false, 2)

func _draw_material() -> void:
	var board: Rect2 = _state.source_board
	_canvas.draw_rect(Rect2(board.position + Vector2(0, 5), board.size), EDGE)
	_canvas.draw_rect(board, COCOA)
	_canvas.draw_rect(board, Color("#e2a47c"), false, 1.8)
	for x in range(90, 650, 40):
		_canvas.draw_line(Vector2(x, 71), Vector2(x, 399), Color("#955b45"))
	for y in range(100, 400, 40):
		_canvas.draw_line(Vector2(61, y), Vector2(649, y), Color("#955b45"))
	for i in 4:
		var part: Dictionary = _state.parts[i]
		if part.freed:
			_canvas.draw_colored_polygon(part.removed_outline, BENCH)
			_contour(part.removed_outline, EDGE, 3)
			_contour(part.outline, Color("#87918b"), 1.2, true)
		else:
			_canvas.draw_circle(part.source_center, 12, EDGE, true, -1, true)
	var selected: Dictionary = _state.parts[_state.selected]
	if not selected.freed:
		_contour(_state.selected_guides[0], Paper.GOLD, 1.3, true)
		_contour(_state.selected_guides[1], Paper.TEAL, 1.1, true)
		for stroke: Dictionary in _state.selected_strokes:
			if stroke.points.size() >= 2:
				_canvas.draw_polyline(stroke.points, EDGE, stroke.width + 1, true)
				_canvas.draw_polyline(stroke.points, Paper.CORAL.lerp(Paper.GOLD, stroke.depth), stroke.width, true)
		if _state.current_stroke.size() >= 2:
			var width: float = 2.0 + 6.0 * _state.depth * _state.depth
			_canvas.draw_polyline(_state.current_stroke, Paper.GOLD, width, true)
	_clamp_mark(Vector2(80, 90), Paper.GOLD)
	if _state.helper_clamp != null:
		_clamp_mark(_state.helper_clamp, Paper.TEAL)

func _clamp_mark(at: Vector2, tint: Color) -> void:
	_canvas.draw_rect(Rect2(at - Vector2(13, 7), Vector2(26, 14)), Paper.DEEP)
	_canvas.draw_rect(Rect2(at - Vector2(13, 7), Vector2(26, 14)), tint, false, 2)
	_canvas.draw_line(at - Vector2(0, 7), at + Vector2(0, 7), tint, 2)

func _draw_assembly() -> void:
	for i in 4:
		var part: Dictionary = _state.parts[i]
		if not part.mounted:
			continue
		var shape := _placed_outline(part, part.position)
		_canvas.draw_colored_polygon(shape, PART_COLORS[i])
		_contour(shape, EDGE, 2)
		_canvas.draw_arc(part.position, part.pitch_radius, 0, TAU, 50, Color("#593f31"), 1.4, true)
		var spoke: Vector2 = part.position + Vector2.from_angle(part.angle) * (part.pitch_radius - 12)
		_canvas.draw_line(part.position, spoke, EDGE, 3, true)
		_canvas.draw_circle(part.position, 11, EDGE, true, -1, true)
	for pair: Vector2i in _state.connections:
		var a: Dictionary = _state.parts[pair.x]
		var b: Dictionary = _state.parts[pair.y]
		var axis: Vector2 = (b.position - a.position).normalized()
		var contact: Vector2 = (a.position + axis * a.pitch_radius + b.position - axis * b.pitch_radius) * 0.5
		_canvas.draw_line(a.position + axis * 19, b.position - axis * 19, Color(Paper.TEAL, 0.65), 1.5, true)
		_canvas.draw_circle(contact, 4, Paper.TEAL, true, -1, true)
	for i in 2:
		var pin: Vector2 = _state.pins[i]
		var tint: Color = Paper.GOLD if i == 0 else Paper.TEAL
		_canvas.draw_arc(pin, 17, 0, TAU, 30, tint, 2, true)
	var selected: Dictionary = _state.parts[_state.selected]
	if selected.freed and not _state.driving and not _state.ended:
		_contour(_placed_outline(selected, _state.cursor), Paper.TEAL, 2.2, true)
	if not is_zero_approx(_state.output_omega):
		var part: Dictionary = _state.parts[2]
		var radius: float = part.pitch_radius + 16.0
		var direction: float = signf(_state.output_omega)
		var end := -PI / 2.0 + direction * PI / 2.0
		_canvas.draw_arc(part.position, radius, -PI / 2.0, end, 24, Paper.TEAL, 2, true)
		var tip: Vector2 = part.position + Vector2.from_angle(end) * radius
		var back := Vector2.from_angle(end + direction * PI / 2.0) * -9
		_canvas.draw_line(tip, tip + back.rotated(0.55), Paper.TEAL, 2, true)
		_canvas.draw_line(tip, tip + back.rotated(-0.55), Paper.TEAL, 2, true)

func _placed_outline(part: Dictionary, center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var source: Vector2 = part.source_center
	for point: Vector2 in part.outline:
		points.append((point - source).rotated(part.angle) + center)
	return points

func _contour(points: PackedVector2Array, color: Color, width: float, dashed := false) -> void:
	for i in points.size():
		var next := points[(i + 1) % points.size()]
		if dashed:
			_canvas.draw_dashed_line(points[i], next, color, width, 4.0, true, true)
		else:
			_canvas.draw_line(points[i], next, color, width, true)
