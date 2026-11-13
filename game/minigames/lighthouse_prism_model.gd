extends RefCounted
class_name LighthousePrismModel

## Grid optics: the lamp beam travels in eight 45-degree directions (y grows south).
## Mirrors and the splitter have four line orientations (0 —, 1 \, 2 |, 3 /);
## reflection is (2 * orientation - direction) mod 8 and a parallel beam passes.
const ROUND_SECONDS := 120.0
const MAX_FRAME_DELTA := 0.25
const SIZE := Vector2i(11, 7)
const SOURCE := Vector2i(0, 3)
const SOURCE_DIRECTION := 0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const MIRROR_LOSS := 0.92
const SPLIT_SHARE := 0.5
const BEACON_PASS := 0.8
const FOG_CROSSING := 0.75
const FOG_ALONG := 0.95
const THRESHOLD := 0.2
const MIN_POWER := 0.02
const MAX_SEGMENTS := 64
const UNDO_LIMIT := 32
const BEACON_POINTS := 100
const HIDDEN_POINTS := 50
const ELEMENTS := [
	{"id": "p1", "kind": "splitter", "name": "分光稜鏡", "cell": Vector2i(3, 3)},
	{"id": "m1", "kind": "mirror", "name": "東鏡", "cell": Vector2i(8, 3)},
	{"id": "m2", "kind": "mirror", "name": "東南鏡", "cell": Vector2i(8, 6)},
	{"id": "m3", "kind": "mirror", "name": "西南鏡", "cell": Vector2i(1, 6)},
	{"id": "m4", "kind": "mirror", "name": "西北鏡", "cell": Vector2i(1, 0)},
	{"id": "m5", "kind": "mirror", "name": "北鏡", "cell": Vector2i(3, 0)},
	{"id": "g1", "kind": "shutter", "name": "西遮光板", "cell": Vector2i(1, 4)},
	{"id": "g2", "kind": "shutter", "name": "南遮光板", "cell": Vector2i(2, 6)},
]
const BEACONS := [
	{"id": "north", "name": "北航標", "cell": Vector2i(5, 0), "hidden": false},
	{"id": "far", "name": "遠航標", "cell": Vector2i(9, 0), "hidden": false},
	{"id": "south", "name": "南航標", "cell": Vector2i(5, 6), "hidden": false},
	{"id": "side", "name": "隱藏側標", "cell": Vector2i(0, 6), "hidden": true},
]
## Retries alternate which fog band thins vertical (crossing) beams.
const FOG_LAYOUTS := [
	{"name": "北霧帶", "cells": [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]},
	{"name": "西霧帶", "cells": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]},
]

var _assisted := false
var _variant := 0
var _fog: Dictionary = {}
var _states: Dictionary = {}
var _selected := 0
var _undo: Array[Dictionary] = []
var _armed := ""
var _elapsed := 0.0
var _moves := 0
var _ended := false
var _success := false
var _devil := false
var _trace: Dictionary = {}
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, FOG_LAYOUTS.size())
	_fog.clear()
	for cell: Vector2i in FOG_LAYOUTS[_variant].cells:
		_fog[cell] = true
	_states.clear()
	for element: Dictionary in ELEMENTS:
		_states[element.id] = 0
	_selected = 0
	_undo.clear()
	_armed = ""
	_elapsed = 0.0
	_moves = 0
	_ended = false
	_success = false
	_devil = false
	_feedback = "選鏡面轉向，把燈塔光送到三座航標"
	_retrace()

func select_next(step: int) -> void:
	if _ended or step == 0:
		return
	_selected = posmod(_selected + signi(step), ELEMENTS.size())
	_armed = ""
	_feedback = "已選%s" % ELEMENTS[_selected].name

func select_element(element_id: String) -> bool:
	for index in ELEMENTS.size():
		if ELEMENTS[index].id == element_id:
			if not _ended:
				_selected = index
				_armed = ""
			return not _ended
	return false

## Rotates the selected mirror/prism by one 45-degree step, or toggles a shutter.
func operate(step: int = 1) -> void:
	if _ended:
		return
	var element: Dictionary = ELEMENTS[_selected]
	if element.kind != "shutter" and _trace.locked.has(element.id) and _armed != element.id:
		_armed = element.id
		_feedback = "夥伴鎖住%s：它正照亮航標，再按一次才轉" % element.name
		return
	_armed = ""
	_undo.append(_states.duplicate())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	if element.kind == "shutter":
		_states[element.id] = 1 - int(_states[element.id])
		_feedback = "%s%s" % [element.name, "打開" if _states[element.id] == 1 else "關上"]
	else:
		_states[element.id] = posmod(int(_states[element.id]) + (1 if step >= 0 else -1), 4)
		_feedback = "%s轉到%s" % [element.name, ["—", "\\", "|", "/"][_states[element.id]]]
	_moves += 1
	_retrace()

func undo() -> void:
	if _ended:
		return
	if not _assisted:
		_feedback = "回復上一鏡位只在輔助模式提供"
		return
	if _undo.is_empty():
		_feedback = "沒有可回復的鏡位"
		return
	_states = _undo.pop_back()
	_armed = ""
	_feedback = "已回復上一鏡位"
	_retrace()

## Settles the round. With beacons still dark the first press only warns.
func settle() -> void:
	if _ended:
		return
	if _trace.main_lit < 3 and _armed != "settle":
		_armed = "settle"
		_feedback = "還有航標未達門檻；再按一次就以目前燈況結束"
		return
	_finish()

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	# Assistance removes the time limit; the clock still records elapsed time.
	_elapsed += minf(delta, MAX_FRAME_DELTA)
	if not _assisted and _elapsed >= ROUND_SECONDS:
		_elapsed = ROUND_SECONDS
		_finish()
	return snapshot()

func _finish() -> void:
	_ended = true
	_success = _trace.main_lit == 3
	_devil = _success and _trace.hidden_lit and _trace.splits == 1
	_armed = ""
	if _success:
		_feedback = "三座航標同時點亮" + ("，隱藏側標也亮了" if _trace.hidden_lit else "")
	else:
		_feedback = "結束：點亮 %d / 3 座航標" % _trace.main_lit

func _element_at(cell: Vector2i) -> Dictionary:
	for element: Dictionary in ELEMENTS:
		if element.cell == cell:
			return element
	return {}

func _beacon_at(cell: Vector2i) -> Dictionary:
	for beacon: Dictionary in BEACONS:
		if beacon.cell == cell:
			return beacon
	return {}

## Bounded, cycle-safe beam trace. Each beam carries the rotatable elements it
## came through so the helper can lock exactly what feeds a lit beacon.
func _retrace() -> void:
	var received: Dictionary = {}
	var lineage_hits: Dictionary = {}
	for beacon: Dictionary in BEACONS:
		received[beacon.id] = 0.0
		lineage_hits[beacon.id] = []
	var segments: Array[Dictionary] = []
	var splits := 0
	var seen: Dictionary = {}
	var stack: Array = [[SOURCE, SOURCE_DIRECTION, 1.0, []]]
	while not stack.is_empty() and segments.size() < MAX_SEGMENTS:
		var beam: Array = stack.pop_back()
		var cell: Vector2i = beam[0]
		var direction: int = beam[1]
		var power: float = beam[2]
		var lineage: Array = beam[3]
		var start := cell
		var start_power := power
		while true:
			var next := cell + DIRS[direction]
			if not Rect2i(Vector2i.ZERO, SIZE).has_point(next) or power < MIN_POWER:
				segments.append({"from": start, "to": next, "power": start_power, "end_power": power, "exits": true})
				break
			cell = next
			var key := Vector3i(cell.x, cell.y, direction)
			if seen.has(key):
				segments.append({"from": start, "to": cell, "power": start_power, "end_power": power, "exits": false})
				break
			seen[key] = true
			if _fog.has(cell):
				power *= FOG_CROSSING if direction % 4 == 2 else FOG_ALONG
			var beacon := _beacon_at(cell)
			if not beacon.is_empty():
				received[beacon.id] += power
				lineage_hits[beacon.id].append(lineage)
				power *= BEACON_PASS
				continue
			var element := _element_at(cell)
			if element.is_empty():
				continue
			var state: int = _states[element.id]
			if element.kind == "shutter":
				if state == 0:
					segments.append({"from": start, "to": cell, "power": start_power, "end_power": power, "exits": false})
					break
				continue
			var reflected := posmod(2 * state - direction, 8)
			if reflected == direction:
				continue
			segments.append({"from": start, "to": cell, "power": start_power, "end_power": power, "exits": false})
			var through: Array = lineage + [element.id]
			if element.kind == "mirror":
				power *= MIRROR_LOSS
				direction = reflected
				lineage = through
			else:
				splits += 1
				stack.append([cell, reflected, power * SPLIT_SHARE, through])
				power *= SPLIT_SHARE
				lineage = through
			start = cell
			start_power = power
	var locked: Dictionary = {}
	var main_lit := 0
	var hidden_lit := false
	for beacon: Dictionary in BEACONS:
		var lit: bool = received[beacon.id] >= THRESHOLD
		if lit:
			for path: Array in lineage_hits[beacon.id]:
				for id: String in path:
					locked[id] = true
			if beacon.hidden:
				hidden_lit = true
			else:
				main_lit += 1
	_trace = {"received": received, "segments": segments, "splits": splits, "locked": locked, "main_lit": main_lit, "hidden_lit": hidden_lit}

func snapshot() -> Dictionary:
	var elements: Array = []
	for index in ELEMENTS.size():
		var row: Dictionary = ELEMENTS[index].duplicate()
		row.state = _states[row.id]
		row.selected = index == _selected
		row.locked = _trace.locked.has(row.id)
		elements.append(row)
	var beacons: Array = []
	for beacon: Dictionary in BEACONS:
		var row: Dictionary = beacon.duplicate()
		row.received = _trace.received[beacon.id]
		row.lit = row.received >= THRESHOLD
		beacons.append(row)
	var score: int = _trace.main_lit * BEACON_POINTS + (HIDDEN_POINTS if _trace.hidden_lit else 0)
	return {
		"assisted": _assisted, "variant": _variant, "fog_name": FOG_LAYOUTS[_variant].name, "fog": _fog.keys(),
		"elapsed": _elapsed, "remaining": INF if _assisted else maxf(0.0, ROUND_SECONDS - _elapsed), "timed": not _assisted,
		"ended": _ended, "success": _success, "devil": _devil, "devil_success": _devil, "ordinary_eligible": _ended,
		"score": score, "mistakes": 0, "moves": _moves, "size": SIZE, "source": SOURCE, "source_direction": SOURCE_DIRECTION,
		"elements": elements, "selected": ELEMENTS[_selected].id, "beacons": beacons, "segments": _trace.segments.duplicate(true),
		"splits": _trace.splits, "main_lit": _trace.main_lit, "hidden_lit": _trace.hidden_lit, "threshold": THRESHOLD,
		"undo_available": _assisted and not _undo.is_empty(), "armed": _armed, "feedback": _feedback, "last_event": _feedback,
	}

## Test/solver helper: element ids in board order (public data, no state writes).
static func element_ids() -> Array:
	var ids: Array = []
	for element: Dictionary in ELEMENTS:
		ids.append(element.id)
	return ids
