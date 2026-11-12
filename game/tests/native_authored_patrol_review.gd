extends "res://game/tests/native_island_animation_acceptance.gd"
## Observe the production patrol without moving NPC roots or replacing sources.

func _observe_authored_patrol(role: String, observe_settle := false, observe_departure := false) -> void:
	if _actor != role:
		_fail("patrol review requires --actor=" + role)
		return
	var start := _simulated_seconds
	var seen := {"right": {}, "left": {}}
	var settle_seen := {"right": {}, "left": {}}
	var depart_seen := {"right": {}, "left": {}}
	var departure_root := Vector3.ZERO
	var departure_active := false
	var maximum_departure_drift := 0.0
	var positions := {}
	var all_consistent := true
	var settled := false
	var samples: Array[Dictionary] = []
	while _simulated_seconds - start < 22.0 and _within_budget():
		await RenderingServer.frame_post_draw
		var record := _npc_record(role)
		var action := String(record.get("action", ""))
		if observe_departure and action == "depart":
			var anchor := _actor_anchor()
			var position := Vector3(float(anchor.x), float(anchor.y), float(anchor.z))
			if not departure_active: departure_root = position
			departure_active = true
			maximum_departure_drift = maxf(maximum_departure_drift, departure_root.distance_to(position))
		else:
			departure_active = false
		if String(record.get("action", "")) == "walk":
			var direction := String(record.direction)
			var index := _current_frame_index()
			var consistent := index >= 0 and _npc_sprite_source_consistent(index)
			all_consistent = all_consistent and consistent
			positions[JSON.stringify(_actor_anchor())] = true
			if direction in seen and consistent and not seen[direction].has(index):
				seen[direction][index] = true
				var patrol: RefCounted = record.get("authored_patrol")
				samples.append({"direction":direction, "frame":index, "anchor":_actor_anchor(), "phase":patrol.phase if patrol != null else null, "motion_driver":"distance-patrol" if patrol != null else "authored-route-track", "simulation_seconds":_simulated_seconds})
				var capture := get_viewport().get_texture().get_image()
				_store_capture("walk-%s-%d" % [direction,index], capture)
		elif observe_departure and action == "depart":
			var direction := String(record.direction)
			var index := _current_frame_index()
			var consistent := index >= 0 and _npc_sprite_source_consistent(index)
			all_consistent = all_consistent and consistent
			if direction in depart_seen and consistent and not depart_seen[direction].has(index):
				depart_seen[direction][index] = true
				_store_capture("depart-%s-%d" % [direction,index], get_viewport().get_texture().get_image())
		elif observe_settle and String(record.get("action", "")) == "settle":
			var direction := String(record.direction)
			var index := _current_frame_index()
			var consistent := index >= 0 and _npc_sprite_source_consistent(index)
			all_consistent = all_consistent and consistent
			if direction in settle_seen and consistent and not settle_seen[direction].has(index):
				settle_seen[direction][index] = true
				_store_capture("settle-%s-%d" % [direction,index], get_viewport().get_texture().get_image())
		elif seen.right.size() == 4 and seen.left.size() == 4 and String(record.get("action", "")) in ["stand", "idle"] and String(record.direction) == "front" and (not observe_settle or (settle_seen.right.size() == 4 and settle_seen.left.size() == 4)):
			if observe_departure and (depart_seen.right.size() != 4 or depart_seen.left.size() != 4): continue
			settled = true
			break
	var complete: bool = seen.right.size() == 4 and seen.left.size() == 4 and positions.size() > 8 and settled and all_consistent and maximum_departure_drift <= 0.00001
	var observation := {"seen":seen, "settle_seen":settle_seen, "depart_seen":depart_seen, "departure_sources":"approved settle poses in reverse; no new drawings" if observe_departure else "not requested", "maximum_departure_root_drift":maximum_departure_drift, "samples":samples, "distinct_positions":positions.size(), "settled":settled, "source_consistent":all_consistent, "simulation_seconds":_simulated_seconds-start, "npc_root_repositioned":false}
	_report["grounded_%s_patrol" % role] = observation
	await _record_action("grounded-%s-patrol" % role, "walk", "right", "authored", _actor_anchor(), complete, observation)
	await _capture("settled")
