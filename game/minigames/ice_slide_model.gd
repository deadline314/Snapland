extends RefCounted

const BOARD := Rect2i(0, 0, 9, 7)
const DIRECTIONS := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
const STARTS := [Vector2i(0, 1), Vector2i(8, 4)]
const MOLDS := [Vector2i(5, 1), Vector2i(5, 4), Vector2i(2, 4), Vector2i(2, 6)]
const WARM := [Vector2i(5, 4), Vector2i(1, 5), Vector2i(7, 3)]
const EMPTY := Vector2i(-1, -1)
const CELL_SECONDS := 0.095
const MELT_SECONDS := 9.0
const ROUND_SECONDS := 90.0
const ASSISTED_ROUND_SECONDS := 110.0

var _layout := 0
var _assisted := false
var _helper := false
var _ice: Array[Vector2i] = []
var _molds: Array[Vector2i] = []
var _warm: Array[Vector2i] = []
var _heat := Vector2.ZERO
var _selected := 0
var _cursor := EMPTY
var _stopper := EMPTY
var _cooled := 0
var _moved := false
var _ice_stop := false
var _melts := 0
var _time := 0.0
var _ended := false
var _feedback := ""
var _route: Array[Vector2i] = []
var _route_index := 0
var _cell_time := 0.0
var _stop_reason := ""
var _trail: Array[Vector2i] = []
var _last_turn: Dictionary = {}

static func orient(cell: Vector2i, layout: int) -> Vector2i:
	return Vector2i(BOARD.size.x - 1 - cell.x, cell.y) if layout == 1 else cell

func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, 2)
	_helper = false
	_ice.assign(STARTS.map(func(cell: Vector2i) -> Vector2i: return orient(cell, _layout)))
	_molds.assign(MOLDS.map(func(cell: Vector2i) -> Vector2i: return orient(cell, _layout)))
	_warm.assign(WARM.map(func(cell: Vector2i) -> Vector2i: return orient(cell, _layout)))
	if _layout == 1:
		_molds[3].y = 0
		_warm[1] = Vector2i(6, 2)
	_heat = Vector2.ZERO
	_selected = 0
	_cursor = EMPTY
	_stopper = EMPTY
	_cooled = 0
	_moved = false
	_ice_stop = false
	_melts = 0
	_time = 0.0
	_ended = false
	_route.clear()
	_trail.clear()
	_last_turn.clear()
	_feedback = "先找亮起的模座。暖格會停冰，擋片會在前一格擋停。"

func select_ice(index: int) -> void:
	if _can_act() and index >= 0 and index < _ice.size():
		_selected = index

func swap_ice() -> void:
	select_ice(1 - _selected)

func toggle_placement() -> void:
	if not _can_act():
		return
	_cursor = _ice[_selected] if _cursor == EMPTY else EMPTY
	_feedback = "方向鍵選擋片格，Enter 放置。也可點棋盤。" if _cursor != EMPTY else "回到推冰。"

func confirm_placement() -> void:
	choose_cell(_cursor)

func choose_cell(cell: Vector2i) -> void:
	if not _can_act() or not BOARD.has_point(cell):
		return
	if _cursor == EMPTY:
		select_ice(_ice.find(cell))
	elif cell == _stopper:
		recall_stopper()
	elif cell in _ice or cell in _molds:
		_feedback = "冰糖和模座上不能放擋片。"
	else:
		_remember_turn()
		_stopper = cell
		_cursor = EMPTY
		_feedback = "擋片已放好，冰糖會停在它前一格。"

func recall_stopper() -> void:
	if _can_act() and _stopper != EMPTY:
		_remember_turn()
		_stopper = EMPTY
		_cursor = EMPTY
		_feedback = "已收回擋片。"

func toggle_helper() -> void:
	if _can_act():
		_helper = not _helper
		_feedback = "AI 標出四個方向的預計停點。" if _helper else "已關閉停點預覽。"

func push(direction: Vector2i) -> void:
	if not _can_act() or direction not in DIRECTIONS:
		return
	if _cursor != EMPTY:
		_cursor = (_cursor + direction).clamp(BOARD.position, BOARD.end - Vector2i.ONE)
		return
	var trace := _trace(direction)
	if trace.cells.is_empty():
		_feedback = "前方被擋住，試另一個方向。"
		return
	_remember_turn()
	_route.assign(trace.cells)
	_route_index = 0
	_cell_time = 0.0
	_stop_reason = trace.reason
	_trail.assign([_ice[_selected]])
	_feedback = "冰糖滑行中。"

func _trace(direction: Vector2i) -> Dictionary:
	var current := _ice[_selected]
	var cells: Array[Vector2i] = []
	while true:
		current += direction
		if not BOARD.has_point(current):
			return {"cells": cells, "reason": "edge"}
		if current == _ice[1 - _selected]:
			return {"cells": cells, "reason": "ice"}
		if current == _stopper:
			return {"cells": cells, "reason": "stopper"}
		cells.append(current)
		if current in _warm:
			return {"cells": cells, "reason": "warm"}
	return {}

func undo() -> void:
	if not _can_act() or _last_turn.is_empty() or not _assisted:
		return
	_ice.assign(_last_turn.ice)
	_stopper = _last_turn.stopper
	_selected = _last_turn.selected
	_cooled = _last_turn.cooled
	_ice_stop = _last_turn.ice_stop
	_cursor = EMPTY
	_heat = Vector2.ZERO
	_trail.clear()
	_last_turn.clear()
	_feedback = "已撤銷上一步。剩餘時間照常。"

func _remember_turn() -> void:
	if _assisted:
		_last_turn = {"ice": _ice.duplicate(), "stopper": _stopper, "selected": _selected, "cooled": _cooled, "ice_stop": _ice_stop}

func _can_act() -> bool:
	return not _ended and _route.is_empty()

func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(minf(delta, 0.25), _duration() - _time)
	_time = minf(_time + delta, _duration())
	if not _route.is_empty():
		_cell_time += delta
		while not _route.is_empty() and _cell_time >= CELL_SECONDS:
			_cell_time -= CELL_SECONDS
			_reach_cell()
	if not _assisted and _cooled < _molds.size():
		_update_heat(delta)
	if _time >= _duration():
		_route.clear()
		_ended = true

func _reach_cell() -> void:
	var cell := _route[_route_index]
	_moved = true
	_ice[_selected] = cell
	_trail.append(cell)
	_route_index += 1
	var hit_mold := _cooled < _molds.size() and cell == _molds[_cooled]
	if hit_mold:
		_cooled += 1
	if _route_index < _route.size():
		return
	_route.clear()
	_ice_stop = _ice_stop or _stop_reason == "ice"
	match _stop_reason:
		"ice": _feedback = "另一塊冰糖擋住了滑行！"
		"stopper": _feedback = "擋片讓冰糖停在前一格。"
		"warm": _feedback = "暖格讓冰糖停下。離開可降溫。"
		_: _feedback = "冰糖滑到邊界。"
	if hit_mold:
		_feedback = "冷卻模座 %d / %d。 " % [_cooled, _molds.size()] + _feedback
	_ended = _cooled == _molds.size()

func _update_heat(delta: float) -> void:
	for index in _ice.size():
		if not _route.is_empty() and index == _selected:
			continue
		if _ice[index] in _warm:
			_heat[index] += delta
		else:
			_heat[index] = maxf(0.0, _heat[index] - 2.0 * delta)
	if _heat.x < MELT_SECONDS and _heat.y < MELT_SECONDS:
		return
	_melts += 1
	_ice.assign(STARTS.map(func(cell: Vector2i) -> Vector2i: return orient(cell, _layout)))
	_heat = Vector2.ZERO
	_cursor = EMPTY
	if _stopper in _ice:
		_stopper = EMPTY
	_route.clear()
	_trail.clear()
	_feedback = "冰糖融化，已送回起點。模座進度保留。"

func _duration() -> float:
	return ASSISTED_ROUND_SECONDS if _assisted else ROUND_SECONDS

func snapshot() -> Dictionary:
	var positions := [Vector2(_ice[0]), Vector2(_ice[1])]
	if not _route.is_empty():
		positions[_selected] = positions[_selected].lerp(Vector2(_route[_route_index]), _cell_time / CELL_SECONDS)
	var hints: Array[Vector2i] = []
	if _helper and _can_act() and _cursor == EMPTY:
		for direction in DIRECTIONS:
			var trace := _trace(direction)
			if not trace.cells.is_empty():
				hints.append(trace.cells.back())
	var success := _cooled == _molds.size()
	var bonus := success and _ice_stop
	return {"ice": _ice.duplicate(), "positions": positions, "molds": _molds.duplicate(), "warm": _warm.duplicate(),
		"layout": _layout, "selected": _selected, "stopper": _stopper, "cursor": _cursor, "trail": _trail.duplicate(), "hints": hints,
		"heat": _heat, "cooled": _cooled, "helper": _helper, "ice_stop": _ice_stop, "assisted": _assisted,
		"undo_available": _assisted and not _last_turn.is_empty(), "sliding": not _route.is_empty(), "feedback": _feedback,
		"elapsed": _time, "remaining": maxf(0.0, _duration() - _time), "ended": _ended,
		"success": success, "devil": bonus, "ordinary_eligible": _ended and _moved,
		"score": maxi(0, 130 * _cooled + 100 * int(bonus) - 25 * _melts), "mistakes": _melts}
