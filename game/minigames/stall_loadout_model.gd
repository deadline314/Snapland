extends RefCounted

const DECK := Vector3i(7, 3, 5)
const POT := 0
const PIECE_COUNT := 5
const UNPLACED := Vector3i(-1, -1, -1)
const TIME_LIMIT := 110.0
const HISTORY_LIMIT := 16
const NAMES := ["湯鍋", "木架", "料盒", "食材箱", "疊盤"]
const STRAP_ROWS := [1, 3]
const FIRST_LAYOUT := [
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 0, 1),
	 Vector3i(2, 0, 1), Vector3i(0, 0, 2), Vector3i(2, 0, 2),
	 Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(2, 1, 0)],
	[Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)],
]
const SECOND_LAYOUT := [
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 0, 2)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 0, 1),
	 Vector3i(2, 0, 1), Vector3i(0, 0, 2), Vector3i(2, 0, 2),
	 Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(2, 1, 1)],
	[Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1),
	 Vector3i(2, 0, 0)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
]


class Arrangement:
	var anchors: Array[Vector3i] = []
	var angles := PackedInt32Array()

	func copy() -> Arrangement:
		var result := Arrangement.new()
		result.anchors.assign(anchors)
		result.angles = angles.duplicate()
		return result


var _layout := 0
var _assisted := false
var _shapes: Array = []
var _layout_state := Arrangement.new()
var _history: Array[Arrangement] = []
var _opening := Vector2i()
var _exit_direction := Vector3i.ZERO
var _elapsed := 0.0
var _moves := 0
var _mistakes := 0
var _secured := false
var _ended := false
var _success := false
var _devil := false
var _feedback: StringName = &"ready"
var _pot_path: Array[Vector3i] = []
var _straps: Array = []


func _init() -> void:
	reset()


func reset(assisted: bool = false, layout: int = 0) -> void:
	_layout = posmod(layout, 2)
	_assisted = assisted
	_exit_direction = Vector3i(0, 0, 1) if _layout == 0 else Vector3i(1, 0, 0)
	_opening = Vector2i(2, 4) if _layout == 0 else Vector2i(1, 4)
	_build_rotations(FIRST_LAYOUT if _layout == 0 else SECOND_LAYOUT)
	_layout_state = Arrangement.new()
	_layout_state.anchors.resize(PIECE_COUNT)
	_layout_state.anchors.fill(UNPLACED)
	_layout_state.angles.resize(PIECE_COUNT)
	_history.clear()
	_pot_path.clear()
	_straps.clear()
	_elapsed = 0.0
	_moves = 0
	_mistakes = 0
	_secured = false
	_ended = false
	_success = false
	_devil = false
	_feedback = &"ready"


func _build_rotations(source: Array) -> void:
	_shapes.clear()
	for piece in source:
		var rotations := []
		var cells: Array[Vector3i] = []
		cells.assign(piece)
		for _angle in 4:
			rotations.append(cells)
			var width := 0
			for cell in cells:
				width = maxi(width, cell.x + 1)
			var turned: Array[Vector3i] = []
			for cell in cells:
				turned.append(Vector3i(cell.z, cell.y, width - 1 - cell.x))
			cells = turned
		_shapes.append(rotations)


func shape(piece: int, angle: int) -> Array[Vector3i]:
	if piece < 0 or piece >= PIECE_COUNT:
		return []
	var result: Array[Vector3i] = _shapes[piece][posmod(angle, 4)]
	return result.duplicate()


func place_reason(piece: int, anchor: Vector3i, angle: int) -> StringName:
	if _ended or _secured or piece < 0 or piece >= PIECE_COUNT:
		return &"locked"
	if not _inside(anchor):
		return &"outside"
	var candidate := _layout_state.copy()
	candidate.anchors[piece] = anchor
	candidate.angles[piece] = posmod(angle, 4)
	return _arrangement_reason(candidate)


func place(piece: int, anchor: Vector3i, angle: int) -> bool:
	var reason := place_reason(piece, anchor, angle)
	if reason != &"":
		return _deny(reason)
	if _layout_state.anchors[piece] == anchor and _layout_state.angles[piece] == posmod(angle, 4):
		return false
	_record()
	_layout_state.anchors[piece] = anchor
	_layout_state.angles[piece] = posmod(angle, 4)
	_moves += 1
	_feedback = &"placed"
	return true


func _record() -> void:
	if _history.size() == HISTORY_LIMIT:
		_history.pop_front()
	_history.append(_layout_state.copy())


func undo() -> bool:
	if _ended or _secured or _history.is_empty():
		return false
	_layout_state = _history.pop_back()
	_feedback = &"undo"
	return true


func toggle_straps() -> bool:
	if _ended or _devil:
		return false
	if _secured:
		_straps.clear()
		_secured = false
		_feedback = &"unsecured"
		return true
	if _layout_state.anchors.has(UNPLACED):
		return _deny(&"incomplete")
	var band_profiles := _strap_profiles(_layout_state)
	if not _bands_contact(band_profiles):
		return _deny(&"strap_gap")
	_straps = band_profiles
	_secured = true
	_feedback = &"secured"
	return true


func extract_pot() -> bool:
	if _ended or not _secured or _devil:
		return false
	var path := _exit_path()
	if path.is_empty():
		return _deny(&"exit_blocked")
	_pot_path = path
	_layout_state.anchors[POT] = UNPLACED
	_straps = _strap_profiles(_layout_state)
	_devil = true
	_feedback = &"extracted"
	return true


func finish() -> bool:
	if _ended or not _secured:
		return false
	_ended = true
	_success = true
	_feedback = &"finished"
	return true


func step(delta: float) -> bool:
	if _ended or _assisted or not is_finite(delta) or delta <= 0.0:
		return false
	_elapsed = minf(TIME_LIMIT, _elapsed + delta)
	if _elapsed >= TIME_LIMIT - 0.00001:
		if _secured:
			finish()
		else:
			_ended = true
			_feedback = &"time"
	return _ended


func elapsed() -> float:
	return _elapsed


func _deny(reason: StringName) -> bool:
	_mistakes += 1
	_feedback = reason
	return false


func _inside(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < DECK.x and cell.y < DECK.y and cell.z < DECK.z


func _arrangement_reason(arrangement: Arrangement) -> StringName:
	var occupied: Dictionary[Vector3i, int] = {}
	for piece in PIECE_COUNT:
		if arrangement.anchors[piece] == UNPLACED:
			continue
		for local: Vector3i in _shapes[piece][arrangement.angles[piece]]:
			var cell := arrangement.anchors[piece] + local
			if not _inside(cell):
				return &"outside"
			if occupied.has(cell):
				return &"collision"
			occupied[cell] = piece
	for cell in occupied:
		if cell.y > 0 and not occupied.has(cell - Vector3i.UP):
			return &"unsupported"
	return &""


func _occupied(arrangement: Arrangement) -> Dictionary[Vector3i, int]:
	var result: Dictionary[Vector3i, int] = {}
	for id in PIECE_COUNT:
		if arrangement.anchors[id] == UNPLACED:
			continue
		for cell: Vector3i in _shapes[id][arrangement.angles[id]]:
			result[arrangement.anchors[id] + cell] = id
	return result


func _strap_profiles(arrangement: Arrangement) -> Array:
	var result := []
	var occupied := _occupied(arrangement)
	for row: int in STRAP_ROWS:
		var heights := PackedInt32Array()
		heights.resize(DECK.x)
		for position in occupied:
			if position.z == row:
				heights[position.x] = maxi(heights[position.x], position.y + 1)
		result.append(heights)
	return result


func _bands_contact(profiles: Array) -> bool:
	for profile: PackedInt32Array in profiles:
		if profile.count(0) == profile.size():
			return false
	return true


func _exit_path() -> Array[Vector3i]:
	var anchor := _layout_state.anchors[POT]
	if anchor == UNPLACED or anchor.y != 0:
		return []
	var remaining := _layout_state.copy()
	remaining.anchors[POT] = UNPLACED
	if _arrangement_reason(remaining) != &"":
		return []
	# The loaded frame must still have contact with both bands once the sliding pot is out.
	if not _bands_contact(_strap_profiles(remaining)):
		return []
	var load := _occupied(remaining)
	var cells: Array[Vector3i] = _shapes[POT][_layout_state.angles[POT]]
	var path: Array[Vector3i] = [anchor]
	for _distance in range(maxi(DECK.x, DECK.z) + 1):
		anchor += _exit_direction
		var on_deck := false
		for local in cells:
			var position := anchor + local
			if _inside(position):
				if load.has(position):
					return []
				on_deck = true
			else:
				var cross := position.x if _exit_direction.z != 0 else position.z
				if cross < _opening.x or cross >= _opening.y:
					return []
		path.append(anchor)
		if not on_deck:
			return path
	return []


func snapshot() -> Dictionary:
	var pieces: Array[Dictionary] = []
	var placed := 0
	for id in PIECE_COUNT:
		var anchor := _layout_state.anchors[id]
		var angle := _layout_state.angles[id]
		if anchor != UNPLACED:
			placed += 1
		pieces.append({"id": id, "name": NAMES[id], "anchor": anchor, "angle": angle, "cells": shape(id, angle)})
	return {
		"layout": _layout, "assisted": _assisted, "pieces": pieces, "placed": placed, "opening": _opening,
		"exit_direction": _exit_direction, "straps": _straps.duplicate(true), "pot_path": _pot_path.duplicate(),
		"secured": _secured, "devil": _devil, "ended": _ended, "success": _success,
		"ordinary_eligible": _ended and (_success or _moves > 0), "mistakes": _mistakes,
		"score": 600 if _devil else (450 if _success else 0), "elapsed": _elapsed,
		"remaining": maxf(0.0, TIME_LIMIT - _elapsed), "can_undo": not _history.is_empty() and not _secured,
		"feedback": _feedback,
	}
