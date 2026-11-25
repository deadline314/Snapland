extends "res://game/ui/minigame_hold_controls.gd"

signal board_command(action: int)

const Model = preload("res://game/minigames/cart_passing_model.gd")
const ALLEY_PATH := "res://assets/minigames/cart-passing-alley.webp"
const BOARD := Rect2(35, 189, 1206, 324)
const GRID_ORIGIN := Vector2(113, 251)
const CELL := Vector2(62, 62)
const INK := Color("#ffedcf")
const PALE := Color("#b7cdca")
const NIGHT := Color("#101e24")
const EDGE := Color("#48636a")
const GOLD := Color("#ffd197")
const MINT := Color("#aaf0d0")
const CORAL := Color("#ffad9f")
const PALETTE := [Color("#8cc6ba"), Color("#e1aecd"), Color("#e6b276")]
const CART_NAMES := ["A 茶車", "B 點心車", "C 木箱車"]
const CART_CODES := ["A", "B", "C"]
const RESTART_GUIDE := "再按一次重置才回起點。本局仍可取得普通拍貼。"

enum { SELECT, WEST, NORTH, EAST, UNLOAD, UNDO, SOUTH, RESTART }

const CART_ACTION := 8
const POCKET_ACTION := CART_ACTION + Model.CART_COUNT
const STEPS := {WEST:Vector2i.LEFT, NORTH:Vector2i.UP, EAST:Vector2i.RIGHT, SOUTH:Vector2i.DOWN}
const LABELS := [
	"換車 · Q", "向左 · ←", "往上進出側袋 · ↑", "向右 · →",
	"卸貨 · 空白", "撤回 · Z", "往下進出側袋 · ↓", "重置 · R",
]
const NAMES := [
	"CartPassingSelect", "CartPassingWest", "CartPassingNorth", "CartPassingEast",
	"CartPassingUnload", "CartPassingUndo", "CartPassingSouth", "CartPassingRestart",
]
const HINTS := [
	"換下一輛未卸貨的車", "向左移一格，按住可連續移動", "整輛車要有空間才能往上移", "向右移一格，按住可連續移動",
	"到指定卸貨口後卸貨", "還原上一個移動或卸貨", "整輛車要有空間才能往下移", "再按一次才重置。本局只計普通拍貼。",
]
const BLOCK_GUIDES := {
	&"blocked_edge":"車身已到巷口邊緣。",
	&"blocked_wall":"這一步會撞牆。請先把整輛車對準側袋。",
	&"blocked_length":"車身還沒完整對準側袋。看看格數，再沿巷調整。",
	&"blocked_cart":"前方有車占位。先移開擋路的車。",
	&"no_unload":"整輛車要進入自己的卸貨口才能卸貨。",
	&"already_parked":"車已停在側袋。",
}

var _state: Dictionary = {}
var _alley: Texture2D
var _hover_slot := -1
var _reduced_motion := false
var _phase := ""
var _font_style := ""
var _locale := ""
var _paint: Array = []
var _controls: Array = []


static func action_available(action: int, state: Dictionary) -> bool:
	if state.get("status", &"ended") != &"live":
		return false
	if action == UNDO:
		return state.get("assisted", false) and int(state.get("undo_count", 0)) > 0
	if action == UNLOAD:
		return state.get("unload_kind", &"none") != &"none"
	return action >= SELECT and action <= RESTART


static func hit_board_command(point: Vector2, state: Dictionary) -> int:
	if not point.is_finite() or state.get("status", &"ended") != &"live":
		return -1
	for cart: Dictionary in state.carts:
		if not cart.delivered and _grid_rect(_cart_cells(cart, state)).has_point(point):
			return CART_ACTION + int(cart.id)
	if state.assisted:
		for pocket: Dictionary in state.pockets:
			if _grid_rect(Rect2(pocket.rect)).has_point(point):
				return POCKET_ACTION + int(pocket.id)
	return -1


static func guide(state: Dictionary) -> String:
	if state.get("restarts", 0) > 0 and state.get("feedback") == &"restart":
		return "已回起點。本局仍可卸完三輛車取得普通拍貼。"
	var feedback: StringName = state.get("feedback", &"ready")
	if feedback == &"blocked_length":
		var cart: Dictionary = state.carts[state.selected]
		if cart.tail_pad != Model.NO_PAD and not cart.tail_unloaded:
			return "長車多占一格。把尾箱對準卸尾台再卸貨。"
	if BLOCK_GUIDES.has(feedback):
		return BLOCK_GUIDES[feedback]
	match feedback:
		&"won": return "三輛車都已卸貨。"
		&"time_up": return "時間到，保留已完成的卸貨得分。"
		&"parked": return "側袋已停妥。換對向車，讓整個車身通過。"
		&"passed": return "一組對向車已完整通過。"
		&"tail": return "尾箱已卸，長車少占一格。"
		&"undo": return "已還原上一步與交會紀錄。"
	if state.get("unload_kind") == &"tail": return "尾箱已對準卸尾台，可先卸下一格。"
	if state.get("unload_kind") == &"final": return "這輛車已到自己的卸貨口。"
	return "選車後沿格子移動。先退進側袋，給對向車讓出整條巷。"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_alley = load(ALLEY_PATH) as Texture2D
	build_controls(LABELS, Color("#243a41"), Color("#626044"), EDGE, GOLD)
	for id in NAMES.size():
		_buttons[id].name = NAMES[id]
	_refresh()


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	_state = state
	_reduced_motion = reduced_motion
	_phase = phase
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _state.is_empty():
		return
	var font_changed := _scale != Paper.text_scale() or _font_style != Paper.font_style() or _locale != TranslationServer.get_locale()
	if font_changed:
		refresh_font()
		_font_style = Paper.font_style()
		_locale = TranslationServer.get_locale()
	var controls := [_state.revision, _state.get("control_mask", 0), _state.get("restart_armed", false)]
	if controls != _controls or font_changed:
		_controls = controls
		_refresh_controls()
	var paint := [
		_state.revision, _state.get("attempted_action", -1), _state.get("restart_armed", false),
		_state.get("slide_cart", -1), _state.get("slide_weight", 0.0), _hover_slot, _phase, _reduced_motion,
	]
	if paint != _paint or font_changed:
		_paint = paint
		queue_redraw()


func _refresh_controls() -> void:
	var mask: int = _state.get("control_mask", 0)
	for id in _buttons.size():
		var button := _buttons[id]
		button.disabled = not action_available(id, _state)
		button.set_pressed_no_signal(bool(mask & (1 << id)))
		button.modulate = PALE if STEPS.has(id) and not _option(id).get("allowed", false) else Color.WHITE
	_buttons[SELECT].text = "%s · Q" % CART_NAMES[_state.selected]
	_buttons[UNLOAD].text = "卸尾箱 · 空白" if _state.unload_kind == &"tail" else LABELS[UNLOAD]
	_buttons[RESTART].text = "再次按下重置 · R" if _state.get("restart_armed", false) else LABELS[RESTART]


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover_slot >= 0:
		_hover_slot = -1
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var slot := hit_slot(event.position)
		var next := slot if STEPS.has(slot) else -1
		if _hover_slot != next:
			_hover_slot = next
			queue_redraw()
	super._gui_input(event)


func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	if super.handle_pointer(event, point):
		return true
	if pointer_source(event).is_empty() or event.is_canceled() or not event.pressed:
		return false
	var action := hit_board_command(point, _state)
	if action < 0:
		return false
	board_command.emit(action)
	return true


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == UNLOAD and _state.get("unload_kind") == &"tail":
		return "卸下尾箱，讓長車少占一格"
	if slot == UNDO and not _state.get("assisted", false):
		return "開啟輔助後可撤回"
	if slot >= 0:
		return HINTS[slot]
	var action := hit_board_command(point, _state)
	if action >= POCKET_ACTION:
		return "朝這個側袋試移一格"
	if action >= CART_ACTION:
		return "選取%s" % CART_NAMES[action - CART_ACTION]
	return ""


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_draw_heading()
	draw_rect(BOARD.grow(2), EDGE)
	draw_rect(BOARD, NIGHT)
	if _alley != null:
		draw_texture_rect(_alley, BOARD, false, Color.WHITE if _phase == "night" else Color(1.0, 0.95, 0.87))
	_draw_lane()
	_draw_destinations()
	for cart: Dictionary in _state.carts:
		if not cart.delivered:
			_draw_cart(cart)
	_draw_move_options()
	_text(Vector2(37, 713), "十字鍵移車 · X 換車 · A 卸貨 · Y 撤回" if _state.assisted else "十字鍵移車 · X 換車 · A 卸貨", PALE, 14, 850)
	if _state.assisted:
		_text(Vector2(976, 713), "可點側袋試移一格", PALE, 14, 266)


func _draw_heading() -> void:
	var warming: bool = BLOCK_GUIDES.has(_state.feedback) or _state.get("restart_armed", false)
	var instruction := RESTART_GUIDE if _state.get("restart_armed", false) else guide(_state)
	_text(Vector2(35, 173), instruction, CORAL if warming else INK, 21, 845)
	var mask: int = _state.pass_mask
	var witnessed := int(bool(mask & 1)) + int(bool(mask & 2)) + int(bool(mask & 4))
	var line := "進袋 %d 次  ·  交會 %d / 2" % [_state.pocket_entries, witnessed]
	_text(Vector2(923, 173), line, GOLD if _state.pocket_entries <= 1 else PALE, 19, 318)


func _draw_lane() -> void:
	var lane := _grid_rect(Rect2(0, Model.LANE_Y, Model.BOARD_SIZE.x, 1))
	draw_rect(lane, Color(0.035, 0.11, 0.13, 0.83))
	draw_rect(lane, Color("#8e8271"), false, 2)
	for column in Model.BOARD_SIZE.x:
		var cell := Rect2(lane.position + Vector2(column * CELL.x, 0), CELL)
		_draw_tile(cell)
	for pocket: Dictionary in _state.pockets:
		var source: Rect2i = pocket.rect
		var bay := _grid_rect(Rect2(source))
		draw_rect(bay, Color(0.12, 0.19, 0.18, 0.9))
		draw_rect(bay, Color("#b89872"), false, 2)
		for column in source.size.x:
			_draw_tile(Rect2(bay.position + Vector2(column * CELL.x, 0), CELL))
		var label_y := bay.position.y - 9 if source.position.y < Model.LANE_Y else bay.end.y + 24
		var badge := Rect2(bay.position.x, label_y - 21, minf(bay.size.x, 190), 26)
		draw_rect(badge, Color(0.07, 0.15, 0.16, 0.92))
		_text(Vector2(badge.position.x + 7, label_y), "側袋  %d 格" % source.size.x, GOLD, 17, badge.size.x - 10)


func _draw_tile(tile: Rect2) -> void:
	draw_rect(tile.grow(-3), Color(0.56, 0.73, 0.69, 0.21), false, 1.2)
	for depth in [14.0, 48.0]:
		var at := tile.position + Vector2(0, depth)
		draw_line(at, at + Vector2(CELL.x, 0), Color(0.57, 0.66, 0.65, 0.31), 1.25)


func _draw_destinations() -> void:
	for cart: Dictionary in _state.carts:
		var rect := _grid_rect(Rect2(cart.exit))
		var tone: Color = PALETTE[cart.id]
		var strip_y := rect.position.y - 7 - float(cart.id) * 8.0
		var strip := Rect2(rect.position.x + 2, strip_y, rect.size.x - 4, 5)
		draw_rect(strip, tone.darkened(0.34) if cart.delivered else tone)
		if cart.id == _state.selected and not cart.delivered:
			draw_rect(rect.grow(-3), Color(tone, 0.23))
			_brackets(rect.grow(-4), tone)
			_badge(Vector2(rect.get_center().x, rect.end.y + 20), "%s 卸貨口" % CART_CODES[cart.id], tone)
		if cart.tail_pad != Model.NO_PAD and not cart.tail_unloaded:
			var pad := _grid_rect(Rect2(Vector2(cart.tail_pad), Vector2.ONE))
			_brackets(pad.grow(-5), GOLD)
			_badge(Vector2(pad.get_center().x, pad.end.y + 48), "卸尾台", GOLD)


func _draw_move_options() -> void:
	if _state.status != &"live" or _state.get("slide_cart", -1) >= 0:
		return
	var hovered := _hover_slot
	var attempted: int = _state.get("attempted_action", -1)
	if hovered < 0 and STEPS.has(attempted) and BLOCK_GUIDES.has(_state.feedback):
		hovered = attempted
	var chosen: Rect2i = _state.carts[_state.selected].rect
	for option: Dictionary in _state.move_options:
		var direction: Vector2i = option.direction
		if STEPS.get(hovered) == direction:
			var target: Rect2i = option.rect
			_preview(chosen, target, option.allowed)
		elif option.allowed and hovered < 0:
			var area := _grid_rect(Rect2(chosen))
			var offset := (area.size * 0.5 + Vector2(9, 9)) * Vector2(direction)
			_arrow(area.get_center() + offset, Vector2(direction), MINT, 6.0)


func _preview(chosen: Rect2i, target: Rect2i, allowed: bool) -> void:
	var tone := MINT if allowed else CORAL
	for column in range(target.position.x, target.end.x):
		var next := Vector2i(column, target.position.y)
		if chosen.has_point(next):
			continue
		var tile := _grid_rect(Rect2(Vector2(next), Vector2.ONE)).grow(-4)
		draw_rect(tile, Color(tone, 0.27))
		_brackets(tile, tone)
		if not allowed:
			var middle := tile.get_center()
			draw_line(middle - Vector2(8, 8), middle + Vector2(8, 8), tone, 2.5, true)
			draw_line(middle - Vector2(-8, 8), middle + Vector2(-8, 8), tone, 2.5, true)


func _draw_cart(cart: Dictionary) -> void:
	var footprint := _grid_rect(_cart_cells(cart, _state))
	var color: Color = PALETTE[cart.id]
	var selected: bool = cart.id == _state.selected
	var chassis := footprint.grow(-6)
	var shadow := Rect2(chassis.position + Vector2(2, 5), chassis.size)
	draw_rect(shadow, Color(0.01, 0.035, 0.03, 0.78))
	draw_rect(chassis, color.darkened(0.61))
	var roof := Rect2(chassis.position + Vector2(3, 3), chassis.size - Vector2(6, 12))
	draw_rect(roof, color.darkened(0.34))
	draw_rect(Rect2(roof.position, Vector2(roof.size.x, 3)), color.lightened(0.29))
	draw_rect(Rect2(roof.position.x, roof.end.y - 4, roof.size.x, 4), color.darkened(0.53))
	for fraction in [0.13, 0.87]:
		var axle := Vector2(lerpf(chassis.position.x, chassis.end.x, fraction), chassis.end.y - 3)
		draw_circle(axle, 6, NIGHT, true, -1, true)
		draw_circle(axle, 2.7, color.darkened(0.16), true, -1, true)
	for column in range(cart.length):
		var tile := Rect2(footprint.position + Vector2(column * CELL.x, 0), CELL).grow(-9)
		_draw_load(tile, cart, column, color)
	var nose_x := roof.end.x - 15 if cart.travel_sign > 0 else roof.position.x + 15
	var nose := Vector2(nose_x, roof.get_center().y)
	draw_rect(Rect2(nose - Vector2(10, 12), Vector2(20, 24)), NIGHT)
	_arrow(nose, Vector2(float(cart.travel_sign), 0.0), INK, 6)
	var name_rect := Rect2(footprint.get_center().x - 54, chassis.position.y + 11, 108, 25)
	draw_rect(name_rect, Color(0.025, 0.09, 0.1, 0.93))
	_text(Vector2(name_rect.position.x + 4, name_rect.position.y + 18), CART_NAMES[cart.id], INK, 16, 103)
	if selected:
		_brackets(footprint.grow(-1), GOLD)


func _draw_load(tile: Rect2, cart: Dictionary, column: int, color: Color) -> void:
	var center := tile.get_center()
	match int(cart.id):
		0:
			for offset_x in [-12.0, 11.0]:
				var at := center + Vector2(offset_x, 4)
				draw_circle(at, 8, color.darkened(0.61), true, -1, true)
				draw_circle(at, 5, color.lightened(0.17), false, 2, true)
		1:
			var tray := Rect2(tile.position + Vector2(4, 13), tile.size - Vector2(8, 23))
			draw_rect(tray, Color("#eacac0"))
			for x in range(3):
				draw_circle(tray.position + Vector2(8 + x * 10, 8), 3.3, color.darkened(0.53), true, -1, true)
		2:
			var box := tile.grow(-4)
			draw_rect(box, color.darkened(0.52))
			draw_rect(box, color.lightened(0.12), false, 2)
			draw_line(box.position + Vector2(4, 5), box.end - Vector2(4, 4), color.darkened(0.15), 3, true)
			if cart.tail_pad != Model.NO_PAD and not cart.tail_unloaded and column == cart.length - 1:
				_brackets(box.grow(1), GOLD)


func _brackets(rect: Rect2, color: Color) -> void:
	for axis: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var at := rect.get_center() - rect.size * 0.5 * axis
		draw_line(at, at + Vector2(axis.x * 9, 0), color, 2.5, true)
		draw_line(at, at + Vector2(0, axis.y * 9), color, 2.5, true)


func _arrow(at: Vector2, direction: Vector2, color: Color, extent: float) -> void:
	var across := Vector2(-direction.y, direction.x) * extent * 0.8
	draw_colored_polygon(PackedVector2Array([
		at + direction * extent, at - direction * extent + across, at - direction * extent - across,
	]), color)


func _badge(center: Vector2, face: String, color: Color) -> void:
	var rect := Rect2(center - Vector2(50, 12), Vector2(100, 24))
	draw_rect(rect, Color(0.055, 0.11, 0.12, 0.92))
	draw_string(_font, rect.position + Vector2(0, 18), face, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, roundi(14 * _scale), color)


func _option(action: int) -> Dictionary:
	for row: Dictionary in _state.move_options:
		if row.direction == STEPS.get(action):
			return row
	return {}


static func _cart_cells(cart: Dictionary, state: Dictionary) -> Rect2:
	var rect := Rect2(cart.rect)
	if state.get("slide_cart", -1) == cart.id:
		var remaining: float = state.get("slide_weight", 0.0)
		rect.position = rect.position.lerp(state.get("slide_from", rect.position), remaining * remaining * (3.0 - 2.0 * remaining))
	return rect


static func _grid_rect(cells: Rect2) -> Rect2:
	return Rect2(GRID_ORIGIN + cells.position * CELL, cells.size * CELL)


func _text(at: Vector2, value: String, color: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), color)
