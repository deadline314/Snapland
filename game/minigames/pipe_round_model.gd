extends RefCounted
## Pure state for the three flower-bed water orders.

const FLOW_SECONDS := 1.15
const ROUND_SECONDS := 60.0
const GRID_SIDE := 4
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const BITS: Array[int] = [1, 2, 4, 8]

const DEFAULT_ORDERS: Array[Dictionary] = [
	{"id":"south_single", "brief":"南側單花床", "start_cells":[10,0,0,0,9,10,6,0,0,0,5,0,0,0,3,6], "source":[0,0], "targets":[[15,2]], "turn_par":4, "witness_routes":[[0,4,5,6,10,14,15]], "solution_cells":[5,0,0,0,3,10,12,0,0,0,5,0,0,0,3,12]},
	{"id":"northeast_southwest_split", "brief":"東北＋西南雙花床", "start_cells":[11,5,5,12,10,0,0,0,10,0,0,0,10,0,0,0], "source":[0,0], "targets":[[3,0],[12,2]], "turn_par":7, "witness_routes":[[0,1,2,3],[0,4,8,12]], "solution_cells":[7,10,10,9,5,0,0,0,5,0,0,0,5,0,0,0]},
	{"id":"east_south_split", "brief":"東側＋南側雙花床", "start_cells":[9,5,7,5,0,0,10,0,0,0,10,0,0,0,9,6], "source":[0,0], "targets":[[3,1],[15,2]], "turn_par":8, "witness_routes":[[0,1,2,3],[0,1,2,6,10,14,15]], "solution_cells":[3,10,14,10,0,0,5,0,0,0,5,0,0,0,3,12]}
]

var orders: Array[Dictionary] = []
var cells: Array[int] = []
var order_index := 0
var cursor := 0
var elapsed := 0.0
var total_turns := 0
var order_turns: Array[int] = []
var completed_beds := 0
var connected := false
var flow_remaining := 0.0
var ended := false
var success := false
var timed_out := false
var board_revision := 0
var network_revision := 0
var order_revision := 0

var _snapshot_cache: Dictionary = {}
var _snapshot_cells: Array[int] = []
var _snapshot_turns: Array[int] = []
var _snapshot_source: Array[int] = []
var _snapshot_targets: Array = []
var _reachable_cache: Dictionary = {}
var _reachable_cells_cache: Array[int] = []
var _flow_edges_cache: Array[Array] = []

func reset(order_data: Array = []) -> void:
	orders = _validated_orders(order_data if not order_data.is_empty() else DEFAULT_ORDERS)
	order_index = 0
	cursor = 0
	elapsed = 0.0
	total_turns = 0
	order_turns.clear()
	for _order in orders:
		order_turns.append(0)
	completed_beds = 0
	connected = false
	flow_remaining = 0.0
	ended = false
	success = false
	timed_out = false
	_load_order()
	_snapshot_cache.clear()
	_snapshot_turns = _readonly_int_array(order_turns)
	_refresh_snapshot_board()
	_refresh_snapshot_order()
	_refresh_network_snapshot()
	_refresh_snapshot_scalars()

func rotate(index: int) -> Dictionary:
	if ended or connected or index < 0 or index >= GRID_SIDE * GRID_SIDE or cells.size() != GRID_SIDE * GRID_SIDE:
		return snapshot()
	cursor = index
	cells[index] = ((cells[index] << 1) & 15) | (cells[index] >> 3)
	total_turns += 1
	order_turns[order_index] += 1
	board_revision += 1
	_rebuild_network_cache()
	connected = _all_targets_reached()
	if connected:
		flow_remaining = FLOW_SECONDS
	_snapshot_turns = _readonly_int_array(order_turns)
	_refresh_snapshot_board()
	_refresh_snapshot_scalars()
	return snapshot()

func step(delta: float) -> Dictionary:
	if ended or delta <= 0.0:
		return snapshot()
	elapsed = minf(ROUND_SECONDS, elapsed + delta)
	if elapsed >= ROUND_SECONDS:
		ended = true
		success = false
		timed_out = true
		connected = false
		flow_remaining = 0.0
		_refresh_snapshot_scalars()
		return snapshot()
	if connected:
		flow_remaining = maxf(0.0, flow_remaining - delta)
		if flow_remaining <= 0.0:
			completed_beds += 1
			if order_index == orders.size() - 1:
				ended = true
				success = true
			else:
				order_index += 1
				_load_order()
				_refresh_snapshot_board()
				_refresh_snapshot_order()
				_refresh_network_snapshot()
	_refresh_snapshot_scalars()
	return snapshot()

## Returns a stable cached Dictionary. Callers must treat it and all nested arrays as read-only.
func snapshot() -> Dictionary:
	return _snapshot_cache

func _load_order() -> void:
	cells.clear()
	if orders.is_empty():
		orders = _validated_orders(DEFAULT_ORDERS)
	var source: Array = orders[order_index].start_cells
	for value in source:
		cells.append(int(value))
	connected = false
	flow_remaining = 0.0
	cursor = 0
	board_revision += 1
	order_revision += 1
	_rebuild_network_cache()

func _all_targets_reached() -> bool:
	if cells.size() != GRID_SIDE * GRID_SIDE:
		return false
	var order: Dictionary = orders[order_index]
	var source: Array = order.source
	var source_cell := int(source[0])
	var source_port := int(source[1])
	if cells[source_cell] & BITS[source_port] == 0:
		return false
	var reached: Dictionary = _reachable_cache
	for target in order.targets:
		var cell := int(target[0])
		var port := int(target[1])
		if not reached.has(cell) or cells[cell] & BITS[port] == 0:
			return false
	return true

func _rebuild_network_cache() -> void:
	network_revision += 1
	_reachable_cache = {}
	_reachable_cells_cache = []
	_flow_edges_cache = []
	if cells.size() != GRID_SIDE * GRID_SIDE or order_index < 0 or order_index >= orders.size():
		return
	var order: Dictionary = orders[order_index]
	var source: Array = order.source
	var source_cell := int(source[0])
	var source_port := int(source[1])
	if source_cell < 0 or source_cell >= cells.size() or source_port < 0 or source_port > 3 or cells[source_cell] & BITS[source_port] == 0:
		return
	_reachable_cache[source_cell] = true
	var queue: Array[int] = [source_cell]
	var edge_keys: Dictionary = {}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var x := current % GRID_SIDE
		var y := int(current / GRID_SIDE)
		for direction in range(4):
			if cells[current] & BITS[direction] == 0:
				continue
			var nx := x + DIRS[direction].x
			var ny := y + DIRS[direction].y
			if nx < 0 or nx >= GRID_SIDE or ny < 0 or ny >= GRID_SIDE:
				continue
			var neighbor := ny * GRID_SIDE + nx
			var opposite := (direction + 2) % 4
			if cells[neighbor] & BITS[opposite] == 0:
				continue
			var edge_key := mini(current, neighbor) * 16 + maxi(current, neighbor)
			if not edge_keys.has(edge_key):
				edge_keys[edge_key] = true
				var edge: Array[int] = [current, neighbor]
				edge.make_read_only()
				_flow_edges_cache.append(edge)
			if not _reachable_cache.has(neighbor):
				_reachable_cache[neighbor] = true
				queue.append(neighbor)
	for cell in _reachable_cache:
		_reachable_cells_cache.append(int(cell))
	_reachable_cells_cache.sort()
	_flow_edges_cache.make_read_only()
	_reachable_cells_cache.make_read_only()
	_refresh_network_snapshot()

func _refresh_snapshot_board() -> void:
	_snapshot_cells = _readonly_int_array(cells)
	_snapshot_cache["cells"] = _snapshot_cells
	_snapshot_cache["board_revision"] = board_revision

func _refresh_snapshot_order() -> void:
	if orders.is_empty() or order_index < 0 or order_index >= orders.size():
		return
	var order: Dictionary = orders[order_index]
	_snapshot_source = _readonly_int_array(order.source)
	_snapshot_targets = _readonly_pairs(order.targets)
	_snapshot_cache["order_index"] = order_index
	_snapshot_cache["order_count"] = orders.size()
	_snapshot_cache["order_id"] = str(order.id)
	_snapshot_cache["brief"] = str(order.brief)
	_snapshot_cache["source"] = _snapshot_source
	_snapshot_cache["targets"] = _snapshot_targets
	_snapshot_cache["turn_par"] = int(order.turn_par)
	_snapshot_cache["order_revision"] = order_revision

func _refresh_network_snapshot() -> void:
	if _snapshot_cache.is_empty():
		return
	_snapshot_cache["reachable_cells"] = _reachable_cells_cache
	_snapshot_cache["flow_edges"] = _flow_edges_cache
	_snapshot_cache["network_revision"] = network_revision

func _refresh_snapshot_scalars() -> void:
	if _snapshot_cache.is_empty():
		_snapshot_cache = {
			"cells": _snapshot_cells, "order_turns": _snapshot_turns,
			"reachable_cells": _reachable_cells_cache, "flow_edges": _flow_edges_cache,
			"source": _snapshot_source, "targets": _snapshot_targets
		}
		_refresh_snapshot_order()
	_snapshot_cache["cursor"] = cursor
	_snapshot_cache["elapsed"] = elapsed
	_snapshot_cache["remaining"] = maxf(0.0, ROUND_SECONDS - elapsed)
	_snapshot_cache["total_turns"] = total_turns
	_snapshot_cache["order_turns"] = _snapshot_turns
	_snapshot_cache["completed_beds"] = completed_beds
	_snapshot_cache["score"] = maxi(0, 1000 * completed_beds - 20 * total_turns)
	_snapshot_cache["order_index"] = order_index
	_snapshot_cache["order_count"] = orders.size()
	_snapshot_cache["connected"] = connected
	_snapshot_cache["flow_remaining"] = flow_remaining
	_snapshot_cache["flow_progress"] = 1.0 - flow_remaining / FLOW_SECONDS if connected else 0.0
	_snapshot_cache["ended"] = ended
	_snapshot_cache["success"] = success
	_snapshot_cache["timed_out"] = timed_out
	_snapshot_cache["board_revision"] = board_revision
	_snapshot_cache["order_revision"] = order_revision
	_snapshot_cache["network_revision"] = network_revision

func _readonly_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	result.make_read_only()
	return result

func _readonly_pairs(values: Array) -> Array:
	var result: Array = []
	for pair in values:
		var read_only_pair := _readonly_int_array(pair)
		result.append(read_only_pair)
	result.make_read_only()
	return result

func _validated_orders(candidate: Array) -> Array[Dictionary]:
	var validation_error := _orders_error(candidate)
	var chosen := candidate if validation_error.is_empty() else DEFAULT_ORDERS
	if not validation_error.is_empty():
		push_warning("Pipe order data fallback: " + validation_error)
	var result: Array[Dictionary] = []
	for order in chosen:
		result.append(order.duplicate(true))
	return result

func _orders_error(candidate: Array) -> String:
	if candidate.size() != 3:
		return "order=all index=-1 field=orders: expected 3, got %d" % candidate.size()
	for order_index_in_data in range(candidate.size()):
		var item = candidate[order_index_in_data]
		if not item is Dictionary:
			return "order=%d index=%d field=order: expected Dictionary" % [order_index_in_data + 1, order_index_in_data]
		if not item.has("id") or not item.has("brief") or not item.has("start_cells") or not item.has("source") or not item.has("targets") or not item.has("turn_par") or not item.has("witness_routes"):
			for required_field in ["id", "brief", "start_cells", "source", "targets", "turn_par", "witness_routes"]:
				if not item.has(required_field):
					return "order=%d index=%d field=%s: required field missing" % [order_index_in_data + 1, order_index_in_data, required_field]
		if not item.start_cells is Array or item.start_cells.size() != 16 or not item.source is Array or item.source.size() != 2 or not item.targets is Array or item.targets.is_empty() or not item.witness_routes is Array:
			return "order=%d index=%d field=shape: invalid start_cells/source/targets/witness_routes" % [order_index_in_data + 1, order_index_in_data]
		for cell_index in range(item.start_cells.size()):
			var mask = item.start_cells[cell_index]
			if not mask is int or int(mask) < 0 or int(mask) > 15:
				return "order=%d index=%d field=start_cells: mask must be 0..15" % [order_index_in_data + 1, cell_index]
		var ports: Array = [item.source]
		ports.append_array(item.targets)
		for port_index in range(ports.size()):
			var pair = ports[port_index]
			if not pair is Array or pair.size() != 2 or not pair[0] is int or not pair[1] is int or int(pair[0]) < 0 or int(pair[0]) >= 16 or int(pair[1]) < 0 or int(pair[1]) > 3:
				var field_name := "source" if port_index == 0 else "targets"
				var data_index := 0 if port_index == 0 else port_index - 1
				return "order=%d index=%d field=%s: expected [cell 0..15, port 0..3]" % [order_index_in_data + 1, data_index, field_name]
		if int(item.turn_par) < 0:
			return "order=%d index=%d field=turn_par: must be non-negative" % [order_index_in_data + 1, order_index_in_data]
	return ""
