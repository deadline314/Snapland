extends RefCounted
class_name CrowdTrafficModel

## Deterministic two-queue pedestrian signal controller for SG-19.
## Lane 0 is horizontal, lane 1 is vertical. Time only advances through step().

const ARRIVAL_TIMES: Array[float] = [0.75, 1.5, 2.4, 3.1, 5.1, 7.1]
const WALK_DURATION := 1.5
const CLEARANCE_DURATION := 0.35
const ALL_RED_DURATION := 0.25
const NORMAL_PATIENCE := 5.5
const RESCUE_PATIENCE := 3.5
const ARRIVAL_LANES: Array[int] = [0, 0, 1, 0, 1, 1]
const ARRIVAL_PEOPLE: Array[int] = [2, 3, 2, 4, 2, 3]
const RESCUE_INDEX := 3
const DEVIL_SCORE := 430

var assisted := false
var elapsed := 0.0
var arrival_index := 0
var safe_count := 0
var missed_count := 0
var mistakes := 0
var score := 0
var devil_progress := 0
var desired_lane := -1
var signal_lane := -1
var phase := "red" # red, walk, clearance, all_red, finished
var phase_time := 0.0
var active_group: Dictionary = {}
var active_progress := 0.0
var queues: Array = [[], []]
var groups: Array[Dictionary] = []
var events: Array[Dictionary] = []
var finished := false
var _snapshot_cache: Dictionary = {}
var _snapshot_queues: Array = [[], []]
var _snapshot_active: Dictionary = {}
var _snapshot_group_views: Dictionary = {}
var _snapshot_revision := 0

func _init() -> void:
	_snapshot_cache = {
		"elapsed": 0.0, "assisted": false, "phase": "red", "phase_time": 0.0,
		"signal_lane": -1, "desired_lane": -1, "queues": _snapshot_queues,
		"active": _snapshot_active, "active_progress": 0.0, "arrival_index": 0,
		"safe_count": 0, "missed_count": 0, "mistakes": 0, "score": 0,
		"devil_progress": 0, "finished": false, "success": false, "devil": false,
		"events": events, "revision": 0
	}

func reset(is_assisted: bool = false) -> void:
	assisted = is_assisted
	elapsed = 0.0
	arrival_index = 0
	safe_count = 0
	missed_count = 0
	mistakes = 0
	score = 0
	devil_progress = 0
	desired_lane = -1
	signal_lane = -1
	phase = "red"
	phase_time = 0.0
	active_group.clear()
	active_progress = 0.0
	queues = [[], []]
	groups.clear()
	events.clear()
	finished = false
	_snapshot_queues[0].clear()
	_snapshot_queues[1].clear()
	_snapshot_active.clear()
	_snapshot_group_views.clear()
	_snapshot_revision += 1
	_refresh_snapshot()

func request_lane(lane: int) -> bool:
	if (lane != 0 and lane != 1) or finished:
		return false
	# Re-selecting the current direction is intentionally idempotent.
	if desired_lane == lane:
		return true
	desired_lane = lane
	_record("request", {"lane": lane, "phase": phase})
	if phase == "red":
		_try_start_walk()
	return true

func step(delta: float) -> void:
	if finished or delta <= 0.0:
		return
	var remaining := delta
	# Consume exact event boundaries so large frames cannot skip clearances or patience.
	while remaining > 0.000001 and not finished:
		var slice := _next_slice(remaining)
		if slice <= 0.000001:
			_process_boundaries()
			continue
		elapsed += slice
		remaining -= slice
		phase_time += slice
		active_progress += slice if phase == "walk" else 0.0
		_process_boundaries()

## Returns a stable, read-only-by-contract view. Consumers must not mutate it.
## Group/queue/event containers are reused; timer fields are refreshed in place.
func snapshot() -> Dictionary:
	_refresh_snapshot()
	return _snapshot_cache

func _refresh_snapshot() -> void:
	_snapshot_cache["elapsed"] = elapsed
	_snapshot_cache["assisted"] = assisted
	_snapshot_cache["phase"] = phase
	_snapshot_cache["phase_time"] = phase_time
	_snapshot_cache["signal_lane"] = signal_lane
	_snapshot_cache["desired_lane"] = desired_lane
	_snapshot_cache["active_progress"] = clampf(active_progress / WALK_DURATION, 0.0, 1.0)
	_snapshot_cache["arrival_index"] = arrival_index
	_snapshot_cache["safe_count"] = safe_count
	_snapshot_cache["missed_count"] = missed_count
	_snapshot_cache["mistakes"] = mistakes
	_snapshot_cache["score"] = score
	_snapshot_cache["devil_progress"] = devil_progress
	_snapshot_cache["finished"] = finished
	_snapshot_cache["success"] = finished and safe_count == 6
	_snapshot_cache["devil"] = finished and safe_count == 6 and devil_progress == 6 and missed_count == 0 and score >= DEVIL_SCORE
	_snapshot_cache["revision"] = _snapshot_revision
	for lane in 2:
		for view_variant in _snapshot_queues[lane]:
			_update_group_view(view_variant)
	if not _snapshot_active.is_empty():
		_update_group_view(_snapshot_active)

func _update_group_view(view: Dictionary) -> void:
	var wait_elapsed := maxf(0.0, elapsed - float(view.get("arrived_at", elapsed)))
	view["wait_elapsed"] = wait_elapsed
	view["patience_remaining"] = maxf(0.0, float(view.get("patience", 0.0)) - wait_elapsed)

func _next_slice(limit: float) -> float:
	var until_boundary := limit
	if arrival_index < ARRIVAL_LANES.size():
		until_boundary = minf(until_boundary, maxf(0.0, ARRIVAL_TIMES[arrival_index] - elapsed))
	if phase == "walk":
		until_boundary = minf(until_boundary, maxf(0.0, WALK_DURATION - phase_time))
	elif phase == "clearance":
		until_boundary = minf(until_boundary, maxf(0.0, CLEARANCE_DURATION - phase_time))
	elif phase == "all_red":
		until_boundary = minf(until_boundary, maxf(0.0, ALL_RED_DURATION - phase_time))
	for lane in 2:
		for group_variant in queues[lane]:
			var group: Dictionary = group_variant
			until_boundary = minf(until_boundary, maxf(0.0, float(group.patience) - (elapsed - float(group.arrived_at))))
	return maxf(0.0, until_boundary)

func _process_boundaries() -> void:
	while arrival_index < ARRIVAL_LANES.size() and elapsed + 0.000001 >= ARRIVAL_TIMES[arrival_index]:
		_enqueue_arrival(arrival_index)
		arrival_index += 1
	# Expire waiting groups only. A group already in the crossing always clears safely.
	for lane in 2:
		var index: int = queues[lane].size() - 1
		while index >= 0:
			var group: Dictionary = queues[lane][index]
			if elapsed - float(group.arrived_at) + 0.000001 >= float(group.patience):
				queues[lane].remove_at(index)
				var view: Dictionary = _snapshot_group_views[int(group.id)]
				_snapshot_queues[lane].erase(view)
				missed_count += 1
				mistakes += 1
				devil_progress = 0
				group.status = "missed"
				group.wait = elapsed - float(group.arrived_at)
				view["status"] = "missed"
				view["wait"] = group.wait
				groups.append(group)
				_record("expired", {"id": group.id, "lane": lane, "rescue": group.rescue})
			index -= 1
	if phase == "walk" and phase_time + 0.000001 >= WALK_DURATION:
		_complete_active_group()
		phase = "clearance"
		phase_time = 0.0
		_record("clearance_started", {"lane": signal_lane})
		signal_lane = -1
	elif phase == "clearance" and phase_time + 0.000001 >= CLEARANCE_DURATION:
		phase = "all_red"
		phase_time = 0.0
		_record("all_red_started", {})
	elif phase == "all_red" and phase_time + 0.000001 >= ALL_RED_DURATION:
		phase = "red"
		phase_time = 0.0
		signal_lane = -1
		_record("all_red_ended", {})
		_try_start_walk()
	if phase == "red":
		_try_start_walk()
	_maybe_finish()

func _enqueue_arrival(index: int) -> void:
	var lane := ARRIVAL_LANES[index]
	var group := {
		"id": index, "lane": lane, "people": ARRIVAL_PEOPLE[index],
		"arrived_at": elapsed, "patience": (RESCUE_PATIENCE if index == RESCUE_INDEX else NORMAL_PATIENCE) + (2.2 if assisted else 0.0),
		"rescue": index == RESCUE_INDEX, "status": "waiting", "wait": 0.0
	}
	queues[lane].append(group)
	var view: Dictionary = group.duplicate()
	view["wait_elapsed"] = 0.0
	view["patience_remaining"] = float(group.patience)
	_snapshot_group_views[int(group.id)] = view
	_snapshot_queues[lane].append(view)
	_record("arrived", {"id": index, "lane": lane, "people": group.people, "rescue": group.rescue})

func _try_start_walk() -> void:
	if phase != "red" or desired_lane < 0 or queues[desired_lane].is_empty():
		return
	# Keep each lane FIFO. Rescue priority is a deliberate signal choice between
	# lanes, never an automatic jump ahead of people already waiting in that lane.
	active_group = queues[desired_lane].pop_front()
	active_group.status = "crossing"
	active_group.wait = elapsed - float(active_group.arrived_at)
	var active_view: Dictionary = _snapshot_group_views[int(active_group.id)]
	_snapshot_queues[desired_lane].erase(active_view)
	_copy_group_view(active_view, active_group)
	_snapshot_active.merge(active_view, true)
	signal_lane = desired_lane
	active_progress = 0.0
	phase = "walk"
	phase_time = 0.0
	_record("walk_started", {"id": active_group.id, "lane": signal_lane, "wait": active_group.wait, "rescue": active_group.rescue})

func _complete_active_group() -> void:
	if active_group.is_empty():
		return
	var group := active_group
	var active_view: Dictionary = _snapshot_group_views[int(group.id)]
	group.status = "safe"
	var entry_wait := float(group.wait)
	var wait := elapsed - float(group.arrived_at)
	group.wait = wait
	active_view["status"] = "safe"
	active_view["wait"] = wait
	# Efficiency reflects queue wait until service begins, not the crossing time.
	var efficiency := 20 if entry_wait <= 2.2 else (10 if entry_wait <= 4.4 else 0)
	var earned := 50 + efficiency + (50 if bool(group.rescue) else 0)
	safe_count += 1
	score += earned
	devil_progress += 1
	groups.append(group)
	_record("safe", {"id": group.id, "lane": group.lane, "wait": wait, "entry_wait": entry_wait, "base": 50, "efficiency": efficiency, "rescue_bonus": 50 if group.rescue else 0, "score": earned})
	active_group.clear()
	_snapshot_active.clear()
	active_progress = 0.0

func _maybe_finish() -> void:
	if arrival_index < ARRIVAL_LANES.size() or not active_group.is_empty() or phase in ["walk", "clearance", "all_red"]:
		return
	if not queues[0].is_empty() or not queues[1].is_empty():
		return
	finished = true
	phase = "finished"
	_record("finished", {"success": safe_count == 6, "devil": safe_count == 6 and devil_progress == 6 and score >= DEVIL_SCORE})

func _copy_group_view(target: Dictionary, source: Dictionary) -> void:
	for key_variant in source:
		var key: String = key_variant
		target[key] = source[key]

func _record(kind: String, data: Dictionary) -> void:
	events.append({"kind": kind, "time": elapsed, "data": data.duplicate(true)})
	_snapshot_revision += 1
