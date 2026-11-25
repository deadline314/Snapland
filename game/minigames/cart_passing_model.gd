extends RefCounted

const BOARD_SIZE := Vector2i(17, 3)
const LANE_Y := 1
const CART_COUNT := 3
const DELIVERY_POINTS := 150
const CHALLENGE_POINTS := 100
const TIME_LIMIT := 100.0
const UNDO_LIMIT := 16
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NO_PAD := Vector2i(-1, -1)
const ALL_CARTS := (1 << CART_COUNT) - 1
const LENGTHS := [3, 2, 5]
const LAYOUTS := [
	{
		"starts": [Vector2i(7, 1), Vector2i(10, 1), Vector2i(12, 1)],
		"exits": [Rect2i(14, 1, 3, 1), Rect2i(1, 1, 2, 1), Rect2i(0, 1, 5, 1)],
		"travel": [1, -1, -1],
		"pockets": [Rect2i(5, 0, 3, 1), Rect2i(8, 2, 4, 1)],
		"tail_pads": [NO_PAD, NO_PAD, NO_PAD],
	},
	{
		"starts": [Vector2i(0, 1), Vector2i(4, 1), Vector2i(6, 1)],
		"exits": [Rect2i(14, 1, 3, 1), Rect2i(15, 1, 2, 1), Rect2i(0, 1, 4, 1)],
		"travel": [1, 1, -1],
		"pockets": [Rect2i(8, 2, 4, 1), Rect2i(3, 0, 3, 1)],
		"tail_pads": [NO_PAD, NO_PAD, Vector2i(12, 1)],
	},
]


class Undo:
	var cells: Array[Vector2i]
	var lengths: PackedInt32Array
	var approaches: PackedInt32Array
	var selected: int
	var delivered_mask: int
	var pass_mask: int
	var pocket_entries: int
	var moves: int


var _layout := 0
var _board: Dictionary = LAYOUTS[0]
var _assisted := false
var _pockets: Array[Dictionary] = []
var _cells: Array[Vector2i] = []
var _lengths := PackedInt32Array()
var _approaches := PackedInt32Array()
var _history: Array[Undo] = []
var _selected := 0
var _delivered_mask := 0
var _pass_mask := 0
var _required_pass_mask := 0
var _pocket_entries := 0
var _moves := 0
var _restarts := 0
var _elapsed := 0.0
var _status: StringName = &"live"
var _feedback: StringName = &"ready"
var _revision := 0
var _snapshot_revision := -1
var _snapshot_cache: Dictionary = {}


func _init() -> void:
	reset()


func reset(assisted: bool = false, layout: int = 0) -> void:
	_layout = posmod(layout, LAYOUTS.size())
	_board = LAYOUTS[_layout]
	_assisted = assisted
	_restarts = 0
	_required_pass_mask = 0
	for first in CART_COUNT:
		for second in range(first + 1, CART_COUNT):
			if _opposed(first, second):
				_required_pass_mask |= _pair_bit(first, second)
	_pockets = []
	for id in _board.pockets.size():
		_pockets.append({"id":id, "rect":_board.pockets[id]})
	_clear_route()
	_changed(&"ready")


func _clear_route() -> void:
	_cells.assign(_board.starts)
	_lengths = PackedInt32Array(LENGTHS)
	_approaches.resize(CART_COUNT)
	_approaches.fill(0)
	_history.clear()
	_selected = 0
	_delivered_mask = 0
	_pass_mask = 0
	_pocket_entries = 0
	_moves = 0
	_elapsed = 0.0
	_status = &"live"


func select(cart: int) -> bool:
	if _status != &"live" or not _active(cart):
		return false
	if _selected != cart:
		_selected = cart
		_changed(&"selected")
	return true


func cycle_selection(direction: int = 1) -> bool:
	if _status != &"live" or direction == 0:
		return false
	for distance in range(1, CART_COUNT + 1):
		if select(posmod(_selected + signi(direction) * distance, CART_COUNT)):
			return true
	return false


## The anchor is the leftmost occupied tile. A lateral step needs space for the entire body.
func move(direction: Vector2i) -> bool:
	if _status != &"live" or not DIRECTIONS.has(direction):
		return false
	var cart := _selected
	var before := _cells[cart]
	var after := before + direction
	var reason := _move_reason(cart, after)
	if reason != &"":
		_blocked(reason)
		return false
	_remember()
	_cells[cart] = after
	_moves += 1
	if before.y == LANE_Y and after.y == LANE_Y:
		_changed(&"passed" if _observe_longitudinal_step(cart, before) else &"moved")
	else:
		_refresh_approaches(cart, after.y != LANE_Y)
		if before.y == LANE_Y:
			_pocket_entries += 1
			_changed(&"parked")
		else:
			_changed(&"merged" if after.y == LANE_Y else &"moved")
	return true


func unload() -> bool:
	if _status != &"live":
		return false
	var cart := _selected
	var kind := _unload_kind(cart)
	if kind == &"none":
		_blocked(&"no_unload")
		return false
	_remember()
	_moves += 1
	_refresh_approaches(cart, false)
	if kind == &"tail":
		# Detach the rear load without shifting the front of the cart.
		if _board.travel[cart] > 0:
			_cells[cart].x += 1
		_lengths[cart] -= 1
		_changed(&"tail")
		return true
	_delivered_mask |= 1 << cart
	if _delivered_mask == ALL_CARTS:
		_status = &"won"
		_changed(&"won")
	else:
		for offset in range(1, CART_COUNT):
			var next := posmod(cart + offset, CART_COUNT)
			if _active(next):
				_selected = next
				break
		_changed(&"delivered")
	return true


## The helper is one ordinary step toward the player-selected pocket. Collision and length still apply.
func assist_toward_pocket(pocket: int) -> bool:
	if not _assisted or _status != &"live" or pocket < 0 or pocket >= _pockets.size():
		return false
	var cart := _selected
	var rect: Rect2i = _pockets[pocket].rect
	var position := _cells[cart]
	if position.y != LANE_Y or _lengths[cart] > rect.size.x:
		_blocked(&"blocked_length" if _lengths[cart] > rect.size.x else &"already_parked")
		return false
	var target_x := clampi(position.x, rect.position.x, rect.end.x - _lengths[cart])
	if target_x != position.x:
		return move(Vector2i(signi(target_x - position.x), 0))
	return move(Vector2i(0, signi(rect.position.y - LANE_Y)))


func undo() -> bool:
	if _status != &"live" or not _assisted or _history.is_empty():
		return false
	var saved: Undo = _history.pop_back()
	_cells = saved.cells
	_lengths = saved.lengths
	_approaches = saved.approaches
	_selected = saved.selected
	_delivered_mask = saved.delivered_mask
	_pass_mask = saved.pass_mask
	_pocket_entries = saved.pocket_entries
	_moves = saved.moves
	_changed(&"undo")
	return true


func restart() -> bool:
	if _status != &"live":
		return false
	_restarts += 1
	_clear_route()
	_changed(&"restart")
	return true


func step(delta: float) -> void:
	if _status != &"live" or _assisted or delta <= 0.0 or not is_finite(delta):
		return
	_elapsed = minf(TIME_LIMIT, _elapsed + delta)
	if _elapsed >= TIME_LIMIT:
		_status = &"time_up"
		_changed(&"time_up")


func snapshot() -> Dictionary:
	if _snapshot_revision != _revision:
		_snapshot_cache = _snapshot_board()
		_snapshot_revision = _revision
	var result := _snapshot_cache.duplicate()
	result["elapsed"] = _elapsed
	result["time_remaining"] = 0.0 if _assisted else TIME_LIMIT - _elapsed
	return result


func _snapshot_board() -> Dictionary:
	var carts: Array[Dictionary] = []
	var deliveries := 0
	for cart in CART_COUNT:
		var delivered := not _active(cart)
		if delivered: deliveries += 1
		var footprint := _footprint(cart, _cells[cart])
		carts.append({
			"id":cart, "x":footprint.position.x, "y":footprint.position.y, "rect":footprint,
			"length":_lengths[cart], "loaded_length":LENGTHS[cart], "exit":_board.exits[cart],
			"travel_sign":_board.travel[cart], "delivered":delivered, "tail_pad":_board.tail_pads[cart],
			"tail_unloaded":_lengths[cart] < LENGTHS[cart],
		})
	var options: Array[Dictionary] = []
	for direction: Vector2i in DIRECTIONS:
		var target := _cells[_selected] + direction
		var reason := _move_reason(_selected, target) if _status == &"live" else &"ended"
		options.append({"direction":direction, "allowed":reason == &"", "reason":reason, "rect":_footprint(_selected, target)})
	var qualified := _status == &"won" and _pocket_entries == 1 and _restarts == 0 and _pass_mask == _required_pass_mask
	return {
		"layout":_layout, "size":BOARD_SIZE, "lane_y":LANE_Y, "pockets":_pockets, "carts":carts,
		"selected":_selected, "move_options":options, "unload_kind":_unload_kind(_selected) if _status == &"live" else &"none",
		"moves":_moves, "pocket_entries":_pocket_entries, "pass_mask":_pass_mask, "required_pass_mask":_required_pass_mask,
		"deliveries":deliveries, "restarts":_restarts, "assisted":_assisted, "undo_count":_history.size(),
		"time_limit":0.0 if _assisted else TIME_LIMIT, "status":_status, "feedback":_feedback,
		"score":deliveries * DELIVERY_POINTS + (CHALLENGE_POINTS if qualified else 0),
		"qualified":qualified, "revision":_revision,
	}


func _move_reason(cart: int, position: Vector2i) -> StringName:
	var area := _footprint(cart, position)
	if not Rect2i(Vector2i.ZERO, BOARD_SIZE).encloses(area):
		return &"blocked_edge"
	if position.y != LANE_Y:
		var fits := false
		var overlaps_pocket := false
		for pocket: Rect2i in _board.pockets:
			fits = fits or pocket.encloses(area)
			overlaps_pocket = overlaps_pocket or pocket.intersects(area)
		if not fits:
			return &"blocked_length" if overlaps_pocket else &"blocked_wall"
	for other in CART_COUNT:
		if other != cart and _active(other) and area.intersects(_footprint(other, _cells[other])):
			return &"blocked_cart"
	return &""


func _unload_kind(cart: int) -> StringName:
	if not _active(cart) or _cells[cart].y != LANE_Y:
		return &"none"
	var exit: Rect2i = _board.exits[cart]
	var area := _footprint(cart, _cells[cart])
	if exit.encloses(area):
		return &"final"
	if _lengths[cart] == LENGTHS[cart]:
		var tail := _cells[cart]
		if _board.travel[cart] < 0:
			tail.x += _lengths[cart] - 1
		if tail == _board.tail_pads[cart]:
			return &"tail"
	return &"none"


func _footprint(cart: int, position: Vector2i) -> Rect2i:
	return Rect2i(position, Vector2i(_lengths[cart], 1))


func _active(cart: int) -> bool:
	return cart >= 0 and cart < CART_COUNT and (_delivered_mask & (1 << cart)) == 0


func _opposed(first: int, second: int) -> bool:
	return _board.travel[first] != _board.travel[second]


func _pair_bit(first: int, second: int) -> int:
	return 1 << (first + second - 1)


## Progress cannot jump across a pocket from a side move, a change of body length or a moving waiting cart.
func _refresh_approaches(cart: int, waiting: bool) -> void:
	_approaches[cart] = 0
	for other in CART_COUNT:
		_approaches[other] &= ~(1 << cart)
		if waiting and other != cart and _active(other) and _opposed(cart, other) and _cells[other].y == LANE_Y:
			if _wholly_on_approach(other, _cells[other], cart):
				_approaches[cart] |= 1 << other


func _observe_longitudinal_step(cart: int, before: Vector2i) -> bool:
	var previous_mask := _pass_mask
	for parked in CART_COUNT:
		if not _active(parked) or _cells[parked].y == LANE_Y or not _opposed(cart, parked):
			continue
		if _wholly_on_approach(cart, before, parked) or _wholly_on_approach(cart, _cells[cart], parked):
			_approaches[parked] |= 1 << cart
		if (_approaches[parked] & (1 << cart)) == 0 or signi(_cells[cart].x - before.x) != _board.travel[cart]:
			continue
		var moving := _footprint(cart, _cells[cart])
		var waiting := _footprint(parked, _cells[parked])
		if (moving.position.x >= waiting.end.x if _board.travel[cart] > 0 else moving.end.x <= waiting.position.x):
			_pass_mask |= _pair_bit(cart, parked)
	return _pass_mask != previous_mask


func _wholly_on_approach(cart: int, position: Vector2i, parked: int) -> bool:
	var moving := _footprint(cart, position)
	var waiting := _footprint(parked, _cells[parked])
	return moving.end.x <= waiting.position.x if _board.travel[cart] > 0 else moving.position.x >= waiting.end.x


func _remember() -> void:
	if not _assisted:
		return
	var saved := Undo.new()
	saved.cells = _cells.duplicate()
	saved.lengths = _lengths.duplicate()
	saved.approaches = _approaches.duplicate()
	saved.selected = _selected
	saved.delivered_mask = _delivered_mask
	saved.pass_mask = _pass_mask
	saved.pocket_entries = _pocket_entries
	saved.moves = _moves
	if _history.size() == UNDO_LIMIT:
		_history.pop_front()
	_history.append(saved)


func _blocked(reason: StringName) -> void:
	if reason != _feedback:
		_changed(reason)


func _changed(feedback: StringName) -> void:
	_feedback = feedback
	_revision += 1
