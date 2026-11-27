extends Control

signal input_requested(event: InputEvent, design_point: Vector2)

const Model = preload("res://game/minigames/ice_slide_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const STATUS_PLATE := Rect2(666, 164, 584, 86)
const ICONS := ["up", "left", "down", "right", "swap", "grab", "confirm", "less", "undo", "helper"]
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
	if STATUS_PLATE.has_point(point):
		return "暖格停冰，亮框是下一個模座；冰塊互擋也算數。"
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
	for index in COMMANDS.size():
		var button := Button.new()
		button.text = TITLES[index]
		button.clip_text = true
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		Props.skin_key(button, Color("#2f5a6e"), ICONS[index])
		button.add_theme_color_override("font_color", GLASS)
		button.add_theme_color_override("font_pressed_color", MINT)
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

## Frosted sugar-glass floor tile; `odd` is the slightly deeper checker.
static func _tile(odd: bool) -> ImageTexture:
	var base := Color("#3d6f8c") if odd else Color("#44799a")
	return Pixels.bake("ice-tile:%s" % odd, Vector2i(30, 30), func(x: int, y: int) -> Color:
		if x + y < 7 and (x + y) % 3 == 0:
			return Props.lighten(base, 0.35)
		if Pixels.noise(x / 3, y / 3, 5) > 0.9:
			return Props.lighten(base, 0.12)
		return Pixels.grainy(base, x, y, 0.08))

## Copper warming plate with glowing bars.
static func _warm_plate() -> ImageTexture:
	return Pixels.bake("ice-warm", Vector2i(30, 30), func(x: int, y: int) -> Color:
		if x < 3 or y < 3 or x > 26 or y > 26:
			return Pixels.metal(Color("#9a5a48"), x, y)
		if (y - 3) % 6 < 3:
			return Color("#ffb070") if (x + y) % 9 != 0 else Color("#ffd690")
		return Pixels.grainy(Color("#5a3438"), x, y, 0.1))

## A rock-sugar cube: lit top face, shaded right face and a crystal glint.
static func _cube(tint: Color) -> ImageTexture:
	return Pixels.bake("ice-cube:" + tint.to_html(false), Vector2i(22, 22), func(x: int, y: int) -> Color:
		if y >= 1 and y <= 4 and x >= 5 - y and x <= 22 - y:
			return Props.lighten(tint, 0.35) if (x + y) % 5 != 0 else Props.lighten(tint, 0.5)
		if x >= 18 and y >= 22 - x and y <= 38 - x:
			return Props.deepen(tint, 0.22)
		if x <= 17 and y >= 5:
			if x >= 2 and x <= 3 and y >= 7 and y <= 13:
				return Props.lighten(tint, 0.5)
			return Pixels.grainy(tint, x, y, 0.1)
		return Pixels.CLEAR)

func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	Props.block_shadow(self, GRID.grow(10), Vector2(8, 10), 0.4)
	Props.metal_plate(self, GRID.grow(10), Color("#8fa6b0"))
	for y in Model.BOARD.size.y:
		for x in Model.BOARD.size.x:
			var cell := Vector2i(x, y)
			var tile := Rect2(_origin(Vector2(cell)), Vector2.ONE * CELL).grow(-1)
			draw_texture_rect(_warm_plate() if cell in _state.warm else _tile((x + y) % 2 == 1), tile, false)
	for cell: Vector2i in _state.trail:
		Props.token(self, _origin(Vector2(cell) + Vector2(0.5, 0.5)), 5.0, Color("#cfeaf2"))
	for index in _state.molds.size():
		var mold: Vector2i = _state.molds[index]
		var center := _origin(Vector2(mold) + Vector2(0.5, 0.5))
		var color := MINT if index < _state.cooled else (AMBER if index == _state.cooled else GLASS)
		var rim := Rect2(center - Vector2(27, 27), Vector2(54, 54))
		# A pressed enamel candy mold: a dark well inside a coloured rim.
		draw_rect(rim.grow(2), Props.deepen(color, 0.5))
		draw_rect(rim, color)
		Props.surface(self, rim.grow(-6 if index == _state.cooled else -4), "groove", Props.deepen(color, 0.35))
		_label(Vector2(rim.position.x + 8, rim.position.y + 22), str(index + 1), color, 16)
	for cell: Vector2i in _state.hints:
		draw_arc(_origin(Vector2(cell) + Vector2(0.5, 0.5)), 17, 0, TAU, 24, MINT, 2, true)
	if _state.stopper != Model.EMPTY:
		var edge := Rect2(_origin(Vector2(_state.stopper)) + Vector2(8, 8), Vector2(50, 50))
		Props.block_shadow(self, edge, Vector2(4, 6), 0.4)
		Props.shaded_box(self, edge, PINK, 8.0)
		_label(edge.position + Vector2(13, 30), "擋", INK, 18)
	for index in _state.positions.size():
		var center := _origin(_state.positions[index] + Vector2(0.5, 0.5))
		var body := Rect2(center - Vector2(22, 22), Vector2(44, 44))
		var color := GLASS if index == 0 else MINT
		if index == _state.selected:
			draw_rect(body.grow(6), Color("#fff6d9"), false, 3)
		Props.contact_shadow(self, center + Vector2(4, 22), 50, 0.45)
		Props.stamp(self, _cube(color), body.position, 2.0)
		_label(center + Vector2(-9, 12), "A" if index == 0 else "B", INK, 21)
	if _state.cursor != Model.EMPTY:
		draw_rect(Rect2(_origin(Vector2(_state.cursor)) + Vector2(4, 4), Vector2(58, 58)), PINK, false, 3)
	_draw_status()

func _draw_status() -> void:
	var left := 684.0
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_TEAL, true)
	var mode := "選擋片格" if _state.cursor != Model.EMPTY else "推所選冰糖"
	_label(Vector2(left, 198), "模座 %d / 4  ·  冰糖 %s  ·  互擋%s  ·  %s" % [_state.cooled, "A" if _state.selected == 0 else "B", "已達成" if _state.ice_stop else "待完成", mode], GLASS, 18)
	_label(Vector2(left, 234), _state.feedback, AMBER, 17)
	if _state.assisted:
		_label(Vector2(left, 300), "輔助中 · 冰糖不融化", PINK, 17)
		return
	_label(Vector2(left, 300), "冰糖熱度", PINK, 17)
	for index in 2:
		var x := left + 100 + index * 230
		var heat: float = _state.heat[index] / Model.MELT_SECONDS
		_label(Vector2(x, 302), "A" if index == 0 else "B", GLASS, 16)
		Props.bar(self, Rect2(x + 24, 288, 170, 12), heat, PINK)

func _origin(cell: Vector2) -> Vector2:
	return GRID.position + cell * CELL

func _label(at: Vector2, value: String, color: Color, pixels: int) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * _scale), color)
