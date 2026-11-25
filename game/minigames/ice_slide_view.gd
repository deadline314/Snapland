extends Control

signal input_requested(event: InputEvent, design_point: Vector2)

const Model = preload("res://game/minigames/ice_slide_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const CELL := 66.0
const GRID := Rect2(38, 172, 594, 462)
const COMMANDS := ["up", "left", "down", "right", "swap", "mark", "place", "recall", "undo", "helper"]
const TITLES := ["上 ↑", "左 ←", "下 ↓", "右 →", "換冰 · Q", "選格 · F", "放片 · Enter", "收片 · X", "撤銷 · Z", "停點 · R"]
const TIPS := ["向上推冰或移游標", "向左推冰或移游標", "向下推冰或移游標", "向右推冰或移游標",
	"切換 A、B 冰糖", "選擋片位置，再按 Enter", "在選取格放置或收回擋片",
	"收回目前擋片", "輔助可撤銷上一步", "AI 標出預計停點"]
const INK := Color("#16364c")
const GLASS := Color("#b7e8f1")
const MINT := Color("#9cf2d1")
const AMBER := Color("#ffcd83")
const PINK := Color("#ffadc5")
const VISUAL_KEYS := ["layout", "ice", "positions", "molds", "warm", "heat", "selected", "stopper", "cursor", "trail", "hints", "cooled", "helper", "ice_stop", "assisted", "undo_available", "sliding", "feedback"]

var _state: Dictionary = {}
var _buttons: Array[Button] = []
var _scale := 0.0
var _font: Font

static func button_rect(index: int) -> Rect2:
	if index < 0 or index >= COMMANDS.size():
		return Rect2()
	if index < 4:
		return Rect2(670 + index * 146, 427, 136, 74)
	return Rect2(670 + (index - 4) % 3 * 194, 509 + floori((index - 4) / 3.0) * 81, 184, 74)

static func button_at(point: Vector2) -> int:
	for index in COMMANDS.size():
		if button_rect(index).has_point(point):
			return index
	return -1

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point - GRID.position) / CELL).floor()) if GRID.has_point(point) else Model.EMPTY

func _get_tooltip(point: Vector2) -> String:
	var index := button_at(point)
	if index >= 0:
		return TIPS[index]
	var cell := cell_at(point)
	if _state.is_empty() or cell == Model.EMPTY:
		return ""
	if cell in _state.ice:
		return "點此選取冰糖"
	if cell == _state.stopper:
		return "擋片會停住來冰，可收回"
	if cell in _state.warm:
		return "暖格會停冰" if _state.assisted else "暖格停冰，久留會融化"
	if cell in _state.molds:
		return "冰糖接觸亮起的模座即可冷卻"
	if cell in _state.hints:
		return "AI 預計停點"
	return "冰面會持續滑行"

func _gui_input(event: InputEvent) -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if GRID.has_point(event.position) or button_at(event.position) >= 0:
			input_requested.emit(event, event.position)
			accept_event()

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var normal := Paper.button_box(Color("#24455e"), Color("#6b9db3"))
	var selected := Paper.button_box(Color("#356b7e"), MINT)
	for index in COMMANDS.size():
		var button := Button.new()
		button.text = TITLES[index]
		button.clip_text = true
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_color_override("font_color", GLASS)
		add_child(button)
		button.position = button_rect(index).position
		button.size = button_rect(index).size
		_buttons.append(button)
	_refresh()

func present(state: Dictionary) -> void:
	var dirty := _scale != Paper.text_scale()
	for key in VISUAL_KEYS:
		dirty = dirty or state.get(key) != _state.get(key)
	_state = state
	if is_node_ready() and dirty:
		_refresh()

func _refresh() -> void:
	if _state.is_empty():
		return
	if _scale != Paper.text_scale():
		_scale = Paper.text_scale()
		_font = Paper.font()
		for button in _buttons:
			button.add_theme_font_override("font", _font)
			button.add_theme_font_size_override("font_size", roundi(18.0 * _scale))
	_buttons[5].set_pressed_no_signal(_state.cursor != Model.EMPTY)
	_buttons[6].disabled = _state.cursor == Model.EMPTY
	_buttons[7].disabled = _state.stopper == Model.EMPTY
	_buttons[8].disabled = not _state.undo_available
	_buttons[9].set_pressed_no_signal(_state.helper)
	queue_redraw()

func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	draw_rect(GRID.grow(8), Color("#34576d"))
	for y in Model.BOARD.size.y:
		for x in Model.BOARD.size.x:
			var cell := Vector2i(x, y)
			var tile := Rect2(_origin(Vector2(cell)), Vector2.ONE * CELL).grow(-2)
			draw_rect(tile, Color("#294c68") if (x + y) % 2 == 0 else Color("#28445f"))
			if cell in _state.warm:
				draw_rect(tile, Color("#744e4a"))
				for line in 3:
					var point := tile.position + Vector2(8 + line * 12, 44)
					draw_line(point, point + Vector2(10, 10), AMBER, 2, true)
	for cell: Vector2i in _state.trail:
		draw_circle(_origin(Vector2(cell) + Vector2(0.5, 0.5)), 4, Color("#a5d7ed"))
	for index in _state.molds.size():
		var mold: Vector2i = _state.molds[index]
		var center := _origin(Vector2(mold) + Vector2(0.5, 0.5))
		var color := MINT if index < _state.cooled else (AMBER if index == _state.cooled else GLASS)
		var rim := Rect2(center - Vector2(27, 27), Vector2(54, 54))
		draw_rect(rim, color, false, 4 if index == _state.cooled else 2)
		_label(Vector2(rim.position.x + 4, rim.position.y + 20), str(index + 1), color, 16)
	for cell: Vector2i in _state.hints:
		draw_arc(_origin(Vector2(cell) + Vector2(0.5, 0.5)), 17, 0, TAU, 24, MINT, 2, true)
	if _state.stopper != Model.EMPTY:
		var edge := Rect2(_origin(Vector2(_state.stopper)) + Vector2(8, 8), Vector2(50, 50))
		draw_rect(edge, PINK)
		draw_rect(edge.grow(-5), Color("#8d516a"), false, 2)
		_label(edge.position + Vector2(11, 32), "擋", INK, 18)
	for index in _state.positions.size():
		var center := _origin(_state.positions[index] + Vector2(0.5, 0.5))
		var body := Rect2(center - Vector2(22, 22), Vector2(44, 44))
		var color := GLASS if index == 0 else MINT
		if index == _state.selected:
			draw_rect(body.grow(4), Color("#fff6d9"), false, 3)
		draw_rect(body, color)
		draw_line(body.position + Vector2(4, 5), body.position + Vector2(39, 5), Color.WHITE, 2)
		_label(center + Vector2(-8, 8), "A" if index == 0 else "B", INK, 21)
	if _state.cursor != Model.EMPTY:
		draw_rect(Rect2(_origin(Vector2(_state.cursor)) + Vector2(4, 4), Vector2(58, 58)), PINK, false, 3)
	_draw_status()

func _draw_status() -> void:
	var left := 677.0
	_label(Vector2(left, 192), "模座  %d / 4    ·    冰糖 %s" % [_state.cooled, "A" if _state.selected == 0 else "B"], GLASS, 23)
	_label(Vector2(left, 230), "冰塊互擋  " + ("已達成" if _state.ice_stop else "待完成"), MINT, 19)
	_label(Vector2(left, 266), _state.feedback, AMBER, 17)
	_label(Vector2(left, 305), "暖格停冰   ｜   亮框是下一個模座", GLASS, 17)
	_label(Vector2(left, 342), "輔助中 · 冰糖不融化" if _state.assisted else "冰糖熱度", PINK, 17)
	if not _state.assisted:
		for index in 2:
			var x := left + index * 204
			var heat: float = _state.heat[index] / Model.MELT_SECONDS
			_label(Vector2(x, 374), "A" if index == 0 else "B", GLASS, 16)
			draw_rect(Rect2(x + 28, 362, 154, 10), Color("#432b4d"))
			draw_rect(Rect2(x + 28, 362, 154 * clampf(heat, 0.0, 1.0), 10), PINK)
	_label(Vector2(left, 402), "選擋片格" if _state.cursor != Model.EMPTY else "推所選冰糖", GLASS, 18)

func _origin(cell: Vector2) -> Vector2:
	return GRID.position + cell * CELL

func _label(at: Vector2, value: String, color: Color, pixels: int) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * _scale), color)
