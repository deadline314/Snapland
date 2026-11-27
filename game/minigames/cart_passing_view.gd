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
## Lacquered stall wood, wet alley setts and the bays' deck boards.
const LACQUER := Color("#3f2726")
const SETT := Color("#3d4a47")
const DECK := Color("#7a5a3e")
const RESTART_GUIDE := "再按一次重置才回起點。本局仍可取得普通拍貼。"

enum { SELECT, WEST, NORTH, EAST, UNLOAD, UNDO, SOUTH, RESTART }

const CART_ACTION := 8
const POCKET_ACTION := CART_ACTION + Model.CART_COUNT
const STEPS := {WEST:Vector2i.LEFT, NORTH:Vector2i.UP, EAST:Vector2i.RIGHT, SOUTH:Vector2i.DOWN}
const LABELS := [
	"換車 · Q", "向左 · ←", "往上進出側袋 · ↑", "向右 · →",
	"卸貨 · 空白", "撤回 · Z", "往下進出側袋 · ↓", "重置 · R",
]
const KEY_ICONS := ["swap", "left", "up", "right", "grab", "undo", "down", "reset"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_alley = load(ALLEY_PATH) as Texture2D
	build_controls(LABELS, Color("#243a41"), Color("#626044"), EDGE, GOLD)
	for id in NAMES.size():
		_buttons[id].name = NAMES[id]
	use_key_caps(KEY_ICONS, KEY_TONE)
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
	if action < 0 and BOARD.has_point(point):
		return "十字鍵移車 · X 換車 · A 卸貨" + (" · Y 撤回；可點側袋試移一格" if _state.get("assisted", false) else "")
	if action >= POCKET_ACTION:
		return "朝這個側袋試移一格"
	if action >= CART_ACTION:
		return "選取%s" % CART_NAMES[action - CART_ACTION]
	return ""


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_draw_heading()
	Props.wood_panel(self, BOARD.grow(8), LACQUER)
	draw_rect(BOARD, NIGHT)
	if _alley != null:
		draw_texture_rect(_alley, BOARD, false, Color.WHITE if _phase == "night" else Color(1.0, 0.95, 0.87))
	_draw_lane()
	_draw_destinations()
	for cart: Dictionary in _state.carts:
		if not cart.delivered:
			_draw_cart(cart)
	_draw_move_options()


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
	var setts := Props.material_tile("cobble", SETT)
	# Bays first, so the lane's kerb stones run across their mouths.
	for pocket: Dictionary in _state.pockets:
		var source: Rect2i = pocket.rect
		var bay := _grid_rect(Rect2(source))
		Props.block_shadow(self, bay, Vector2(4, 6), 0.45)
		Props.wood_panel(self, bay, DECK)
		draw_rect(bay, Color(0.06, 0.08, 0.12, 0.28))
		for column in source.size.x:
			_draw_tile(Rect2(bay.position + Vector2(column * CELL.x, 0), CELL))
		var label_y := bay.position.y - 9 if source.position.y < Model.LANE_Y else bay.end.y + 24
		var badge := Rect2(bay.position.x, label_y - 21, minf(bay.size.x, 190), 26)
		Props.shaded_box(self, badge.grow_individual(0, 0, 0, 4), LACQUER, 4.0)
		_text(Vector2(badge.position.x + 8, label_y), "側袋  %d 格" % source.size.x, GOLD, 17, badge.size.x - 10)
	Props.fill_polygon(self, _corners(lane), setts, Color(0.82, 0.84, 0.9))
	for edge_y: float in [lane.position.y - 4.0, lane.end.y]:
		Props.fill_polygon(self, _corners(Rect2(lane.position.x, edge_y, lane.size.x, 4.0)), Props.material_tile("cobble", Props.lighten(SETT, 0.3)))
	Props.vignette(self, lane, 0.35, Color("#0a0d14"))
	for column in Model.BOARD_SIZE.x:
		_draw_tile(Rect2(lane.position + Vector2(column * CELL.x, 0), CELL))


## Chalked stall marks keep the grid readable on stone and deck alike.
func _draw_tile(tile: Rect2) -> void:
	var chalk := Color(0.93, 0.9, 0.8, 0.34)
	for corner: Vector2 in [Vector2(4, 4), Vector2(CELL.x - 10, 4), Vector2(4, CELL.y - 6), Vector2(CELL.x - 10, CELL.y - 6)]:
		draw_rect(Rect2(tile.position + corner, Vector2(6, 2)), chalk)


static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


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
	Props.block_shadow(self, chassis, Vector2(4, 7), 0.6)
	Props.shaded_box(self, chassis, Color("#5a3a28"), 8.0)
	# The bed is painted planking in the cart's colour.
	var roof := Rect2(chassis.position + Vector2(4, 4), chassis.size - Vector2(8, 14))
	Props.surface(self, roof, "planks", color.darkened(0.38))
	for fraction in [0.13, 0.87]:
		var axle := Vector2(lerpf(chassis.position.x, chassis.end.x, fraction), chassis.end.y - 2)
		Props.contact_shadow(self, axle + Vector2(2, 6), 22.0, 0.7)
		Props.token(self, axle, 8.0, Color("#4a3226"))
		Props.token(self, axle, 3.0, Props.BRASS)
	for column in range(cart.length):
		var tile := Rect2(footprint.position + Vector2(column * CELL.x, 0), CELL).grow(-9)
		_draw_load(tile, cart, column, color)
	var nose_x := roof.end.x - 15 if cart.travel_sign > 0 else roof.position.x + 15
	var nose := Vector2(nose_x, roof.get_center().y)
	Props.shaded_box(self, Rect2(nose - Vector2(10, 12), Vector2(20, 26)), LACQUER, 4.0)
	_arrow(nose, Vector2(float(cart.travel_sign), 0.0), INK, 6)
	# A small hanging tag, so the load on the bed stays in view.
	var label_width := _font.get_string_size(CART_NAMES[cart.id], HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * _scale)).x + 14.0
	var name_rect := Rect2(footprint.get_center().x - label_width * 0.5, chassis.position.y - 12, label_width, 20)
	Props.shaded_box(self, name_rect.grow_individual(0, 0, 0, 4), LACQUER, 4.0)
	_text(Vector2(name_rect.position.x + 7, name_rect.position.y + 15), CART_NAMES[cart.id], INK, 14, label_width)
	if selected:
		_brackets(footprint.grow(-1), GOLD)


func _draw_load(tile: Rect2, cart: Dictionary, column: int, color: Color) -> void:
	var center := tile.get_center()
	match int(cart.id):
		0:
			# Two glazed tea urns with brass lids.
			for offset_x in [-12.0, 11.0]:
				var at := center + Vector2(offset_x, 4)
				Props.contact_shadow(self, at + Vector2(2, 7), 20.0, 0.6)
				Props.token(self, at, 9.0, color.darkened(0.3))
				Props.token(self, at + Vector2(-1, -2), 4.0, Props.BRASS)
		1:
			# A paper-lined tray of buns.
			var tray := Rect2(tile.position + Vector2(4, 13), tile.size - Vector2(8, 23))
			Props.shaded_box(self, tray, Color("#b98a5e"), 4.0)
			for x in range(3):
				Props.token(self, tray.position + Vector2(8 + x * 10, 7), 4.0, Color("#f1d6c6"))
		2:
			# A slatted crate with a cross brace.
			var box := tile.grow(-4)
			Props.block_shadow(self, box, Vector2(3, 4), 0.45)
			Props.shaded_box(self, box, Color("#a2774a"), 6.0)
			draw_line(box.position + Vector2(5, 5), box.end - Vector2(5, 9), Props.deepen(Color("#a2774a"), 0.3), 3, true)
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
	Props.shaded_box(self, rect.grow_individual(0, 0, 0, 4), LACQUER, 4.0)
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
