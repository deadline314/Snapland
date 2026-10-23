extends SceneTree

const TrafficModel = preload("res://game/minigames/crowd_traffic_model.gd")
const CrossingView = preload("res://game/minigames/crowd_crossing_view.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_red_stop_and_safe_switch()
	_test_single_reward_and_completion()
	_test_fifo_strategy_can_miss_rescue()
	_test_assisted_priority_dispatch()
	_test_ordinary_efficiency_below_bonus()
	_test_patience_pause_reset_and_assist()
	_test_view_tracks_safety_state()
	_test_snapshot_reuse_and_initial_red()
	_test_planning_forecast_and_risk()
	if failures.is_empty():
		print("PASS: crowd traffic model (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("Crowd traffic model: " + failure)
		quit(1)

func _test_red_stop_and_safe_switch() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	model.step(0.75)
	var waiting: Dictionary = model.snapshot()
	_expect(waiting.phase == "red" and waiting.queues[0].size() == 1 and int(waiting.queues[0][0].id) == 0, "the first horizontal group arrives after the opening interval and queues behind a red signal")
	_expect(is_equal_approx(float(waiting.queues[0][0].arrived_at), 0.75) and is_equal_approx(float(waiting.queues[0][0].wait_elapsed), 0.0), "the opening interval leaves the first group at zero wait when it arrives")
	model.request_lane(0)
	model.step(0.2)
	var during_crossing: Dictionary = model.snapshot()
	_expect(during_crossing.phase == "walk" and during_crossing.active.lane == 0, "horizontal green begins a real crossing")
	model.request_lane(1)
	var event_count_before_repeat: int = model.events.size()
	for _request in 3:
		model.request_lane(1)
	_expect(model.events.size() == event_count_before_repeat, "repeated selected-lane inputs do not allocate redundant event records")
	_expect(model.phase == "walk" and int(model.snapshot().active.id) == 0, "repeated lane changes cannot interrupt or skip a crossing already in progress")
	var progress_before := float(model.snapshot().active_progress)
	model.step(1.3)
	var still_crossing: Dictionary = model.snapshot()
	_expect(still_crossing.phase == "clearance" and still_crossing.active.is_empty() and still_crossing.signal_lane == -1, "opposite request cannot interrupt a group already in the crossing, then both lanes go red")
	_expect(float(still_crossing.active_progress) == 0.0 and progress_before > 0.0, "crossing completion enters clearance only after real simulation time")
	_expect(model.safe_count == 1, "a completed crossing is awarded once")
	var score_after_one: int = model.score
	model.step(0.34)
	_expect(model.phase == "clearance", "the clearance interval cannot be skipped by another lane request")
	model.request_lane(1)
	model.step(0.01)
	_expect(model.phase == "all_red", "clearance must finish before the all-red interval begins")
	model.request_lane(1)
	model.step(0.24)
	_expect(model.phase == "all_red", "the all-red interval remains active until its full duration elapses")
	model.step(0.01)
	var before_release: Dictionary = model.snapshot()
	_expect(before_release.active.lane == 1 and before_release.phase == "walk" and before_release.signal_lane == 1 and before_release.queues[0].size() == 1, "the vertical group receives green only after transition while the next horizontal group stays queued")
	model.step(1.0)
	_expect(model.score == score_after_one, "clearance updates do not award the completed group twice")
	var after_release: Dictionary = model.snapshot()
	_expect(after_release.phase == "walk" and after_release.signal_lane == 1, "vertical green serves the queued group without changing its lane")
	model.reset(false)

func _test_single_reward_and_completion() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	_run_rescue_priority_dispatch(model)
	var result: Dictionary = model.snapshot()
	_expect(result.finished and result.success, "serving the earliest patience deadline safely reaches the ordinary result")
	_expect(result.safe_count == 6 and result.missed_count == 0, "ordinary success requires six actual safe crossings and no expired group")
	_expect(result.devil and result.devil_progress == 6, "a flawless legal schedule reaches the devil result")
	_expect(result.score == 430, "the real queue waits and rescue bonus produce 430 points on the six-group priority schedule")
	var safe_events := 0
	var expected_arrival_times: Array[float] = [0.75, 1.5, 2.4, 3.1, 5.1, 7.1]
	var checked_arrivals := 0
	for event_variant in result.events:
		if event_variant.kind == "safe": safe_events += 1
		if event_variant.kind == "arrived" and checked_arrivals < expected_arrival_times.size():
			_expect(is_equal_approx(float(event_variant.time), expected_arrival_times[checked_arrivals]), "group %d enters at its authored time" % checked_arrivals)
			checked_arrivals += 1
	_expect(safe_events == 6, "each group has exactly one safe completion event")
	_expect(checked_arrivals == expected_arrival_times.size(), "all six scheduled arrivals are represented by real model events")
	_expect(result.events.back().kind == "finished", "completion follows the real queue and crossing lifecycle")
	var opening_input: Variant = _event_for_group(result.events, "walk_started", 0)
	var rescue_start: Variant = _event_for_group(result.events, "walk_started", 3)
	var vertical_start: Variant = _event_for_group(result.events, "walk_started", 2)
	_expect(opening_input != null and is_equal_approx(float(opening_input.time), 0.95), "the first real lane request follows the 0.65-second intro and 0.30-second reaction window")
	_expect(rescue_start != null and is_equal_approx(float(rescue_start.time), 5.15), "the player explicitly keeps horizontal green queued to serve the short-patience rescue at its actual arrival")
	_expect(vertical_start != null and is_equal_approx(float(vertical_start.time), 7.25), "vertical service begins after rescue with the earliest vertical group still inside its patience window")

func _test_fifo_strategy_can_miss_rescue() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	model.step(0.95)
	model.request_lane(0)
	model.step(3.61)
	# At this decision, FIFO by arrival favors vertical group 2; the rescue's
	# deadline is earlier, so this genuine lane choice can lose the rescue.
	model.request_lane(1)
	model.step(7.1)
	var result: Dictionary = model.snapshot()
	_expect(result.finished and result.safe_count == 5 and result.missed_count == 1, "choosing the oldest arrival lane at the second decision lets the rescue expire")
	_expect(not result.devil and result.missed_count == 1, "a missed rescue invalidates flawless eligibility rather than granting an automatic rescue")
	var expired_rescue: Variant = _event_for_group(result.events, "expired", 3)
	_expect(expired_rescue != null and bool(expired_rescue.data.rescue), "the missed group is explicitly recorded as the rescue")

func _test_assisted_priority_dispatch() -> void:
	var model = TrafficModel.new()
	model.reset(true)
	_run_rescue_priority_dispatch(model)
	var result: Dictionary = model.snapshot()
	_expect(result.assisted and result.finished and result.success and result.safe_count == 6, "the same deliberate six-group strategy can complete in assisted mode")
	_expect(result.missed_count == 0 and result.score == 430, "assistance extends patience without auto-serving or changing earned event points")
	_expect(not result.devil, "an assisted round earns the ordinary photo only, like the other refined welcome games")

func _test_ordinary_efficiency_below_bonus() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	_run_rescue_priority_dispatch(model, 1.2)
	var result: Dictionary = model.snapshot()
	_expect(result.finished and result.success and result.safe_count == 6, "a slower but safe six-group route still earns ordinary completion")
	_expect(result.score < model.DEVIL_SCORE and not result.devil, "ordinary completion below the visible efficiency target does not grant devil qualification")

func _test_planning_forecast_and_risk() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	model.step(0.1)
	var opening: Dictionary = model.snapshot()
	_expect(opening.upcoming.size() == 2 and int(opening.upcoming[0].id) == 0 and int(opening.upcoming[0].lane) == 0 and is_equal_approx(float(opening.upcoming[0].eta), 0.65), "the arrival board announces the first group's lane and time before it arrives")
	_expect(float(opening.time_to_free) == 0.0 and int(opening.recommended_lane) == -1, "an empty red crossing is free and recommends nothing")
	model.step(0.85)
	model.request_lane(0)
	model.step(0.5)
	var walking: Dictionary = model.snapshot()
	_expect(is_equal_approx(float(walking.time_to_free), model.WALK_DURATION - 0.5 + model.CLEARANCE_DURATION + model.ALL_RED_DURATION), "while a group walks, the board reports when the crossing frees up")
	model.step(3.11)
	var competing: Dictionary = model.snapshot()
	var horizontal: Dictionary = competing.lane_risk[0]
	var vertical: Dictionary = competing.lane_risk[1]
	_expect(bool(horizontal.head_rescue) and int(vertical.waiting) == 1, "the rescue heads the horizontal queue while a vertical group waits")
	_expect(bool(horizontal.must_go_next) and not bool(vertical.must_go_next), "only the rescue would expire if the other side went first")
	_expect(int(competing.recommended_lane) == 0, "the recommendation follows the tighter real patience deadline")
	var head_deadline := INF
	for lane in 2:
		if not model.queues[lane].is_empty():
			head_deadline = minf(head_deadline, float(model.queues[lane][0].arrived_at) + float(model.queues[lane][0].patience))
	_expect(is_equal_approx(float(model.queues[0][0].arrived_at) + float(model.queues[0][0].patience), head_deadline), "the recommended lane owns the earliest head deadline")
	var reused: Dictionary = model.snapshot()
	_expect(reused.upcoming == competing.upcoming and reused.lane_risk == competing.lane_risk, "planning containers are refreshed in place")

func _run_rescue_priority_dispatch(model, opening_seconds: float = 0.95) -> void:
	# 0.65 s opening instruction plus 0.30 s of player reaction.
	model.step(opening_seconds)
	model.request_lane(0)
	# H0 and H1 are FIFO on their lane. When the rescue and V0 compete,
	# selecting horizontal gives the earlier patience deadline a real priority.
	model.step(3.61)
	var competing_queues: Dictionary = model.snapshot()
	_expect(competing_queues.queues[0].size() == 1 and bool(competing_queues.queues[0][0].rescue) and competing_queues.queues[1].size() == 1, "the rescue and earliest vertical group actually wait together before the lane choice")
	model.request_lane(0)
	model.step(2.10)
	model.request_lane(1)
	model.step(6.99)

func _event_for_group(events: Array, kind: String, group_id: int) -> Variant:
	for event_variant in events:
		if event_variant.kind == kind and int(event_variant.data.get("id", -1)) == group_id:
			return event_variant
	return null

func _test_patience_pause_reset_and_assist() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	model.step(0.75)
	var start: Dictionary = model.snapshot()
	var patience := float(start.queues[0][0].patience_remaining)
	model.request_lane(1)
	_expect(model.snapshot().active.is_empty(), "requesting a direction with no waiting group never starts green")
	model.reset(false)
	model.step(0.75)
	start = model.snapshot()
	patience = float(start.queues[0][0].patience_remaining)
	# A pause is represented by no calls to step; observed model time must not catch up.
	var paused_elapsed := float(model.snapshot().elapsed)
	var paused_state: Dictionary = model.snapshot()
	_expect(float(paused_state.elapsed) == paused_elapsed and float(paused_state.queues[0][0].patience_remaining) == patience, "omitting step while paused freezes queues and patience")
	model.step(5.5)
	var expired: Dictionary = model.snapshot()
	_expect(expired.missed_count == 1 and expired.mistakes == 1 and expired.safe_count == 0, "an unserved group expires as a miss, not a safe score")
	_expect(not _queue_has_id(expired.queues[0], 0) and int(expired.queues[0][0].id) == 1 and expired.score == 0, "the expired first group leaves its queue without reward while later demand remains waiting")
	model.reset(true)
	model.step(0.75)
	var assisted: Dictionary = model.snapshot()
	_expect(assisted.assisted and float(assisted.queues[0][0].patience_remaining) > patience, "assistance increases queue patience without auto-serving anyone")
	_expect(assisted.safe_count == 0 and assisted.score == 0, "assistance does not award safety points or progress")
	model.reset(false)
	var reset_state: Dictionary = model.snapshot()
	_expect(reset_state.elapsed == 0.0 and reset_state.arrival_index == 0 and reset_state.queues[0].is_empty(), "retry clears time, arrivals, queues, and phase state")

func _test_view_tracks_safety_state() -> void:
	var view: Control = CrossingView.new()
	root.add_child(view)
	var model = TrafficModel.new()
	model.reset(false)
	model.step(2.2)
	view.present_state(model.snapshot(), 2.2, false, "noon")
	var waiting_position: Vector2 = view._queue_person_position(0, 0, 0, 2)
	model.request_lane(0)
	model.step(0.4)
	view.present_state(model.snapshot(), model.elapsed, false, "noon")
	_expect(view._traffic_snapshot.phase == "walk" and view._traffic_snapshot.active.lane == 0, "view consumes the live walk signal and active lane")
	_expect(view._queue_person_position(0, 0, 0, 2) == waiting_position, "a red-queue pedestrian stays at the same stop-line position")
	var moving_progress: float = view._crossing_progress
	view.present_state(model.snapshot(), model.elapsed, true, "night")
	_expect(view._phase_id == "night" and view._crossing_progress == moving_progress, "reduced motion preserves meaningful crossing progress while disabling bobbing")
	_expect(view.pointerSignalAt(Vector2(520, 235)) == 0 and view.pointerSignalAt(Vector2(760, 235)) == 1, "both signal targets retain their lane mapping")
	view.queue_free()
	await process_frame

func _test_snapshot_reuse_and_initial_red() -> void:
	var model = TrafficModel.new()
	model.reset(false)
	var first: Dictionary = model.snapshot()
	var queue_reference: Array = first.queues
	var event_reference: Array = first.events
	model.step(2.2)
	var arrived: Dictionary = model.snapshot()
	_expect(is_same(first, arrived), "snapshot returns the same cached dictionary across frames")
	_expect(is_same(queue_reference, arrived.queues), "queue outer arrays remain stable across an arrival")
	_expect(is_same(event_reference, arrived.events), "event array remains stable and records only appended events")
	var group_view: Dictionary = arrived.queues[0][0]
	model.step(0.5)
	var waited: Dictionary = model.snapshot()
	_expect(is_same(group_view, waited.queues[0][0]) and is_equal_approx(float(group_view.wait_elapsed), 1.95), "waiting group dictionary is reused with timers updated in place")
	var view: Control = CrossingView.new()
	root.add_child(view)
	model.reset(false)
	view.present_state(model.snapshot(), 0.0, false, "noon")
	_expect(view._selected_lane == -1 and view._crossing_lane == -1, "the initial red wait highlights neither direction before a request")
	view.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _queue_has_id(queue: Array, group_id: int) -> bool:
	for group_variant in queue:
		if int(group_variant.id) == group_id:
			return true
	return false
