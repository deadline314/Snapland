extends "res://game/tests/native_island_animation_acceptance.gd"
## Observe the production patrol without moving NPC roots or replacing sources.

func _observe_authored_patrol(role: String) -> void:
	if _actor != role:
		_fail("patrol review requires --actor=" + role)
		return
	var start := _simulated_seconds
	var seen := {"right": {}, "left": {}}
	var positions := {}
	var all_consistent := true
	var settled := false
	var samples: Array[Dictionary] = []
	while _simulated_seconds - start < 22.0 and _within_budget():
		await RenderingServer.frame_post_draw
		var record := _npc_record(role)
		if String(record.get("action", "")) == "walk":
			var direction := String(record.direction)
			var index := _current_frame_index()
			var consistent := index >= 0 and _npc_sprite_source_consistent(index)
			all_consistent = all_consistent and consistent
			positions[JSON.stringify(_actor_anchor())] = true
			if direction in seen and consistent and not seen[direction].has(index):
				seen[direction][index] = true
				samples.append({"direction":direction, "frame":index, "anchor":_actor_anchor(), "phase":record.authored_patrol.phase, "simulation_seconds":_simulated_seconds})
				var capture := get_viewport().get_texture().get_image()
				_store_capture("walk-%s-%d" % [direction,index], capture)
		elif seen.right.size() == 4 and seen.left.size() == 4:
			settled = true
			break
	var complete: bool = seen.right.size() == 4 and seen.left.size() == 4 and positions.size() > 8 and settled and all_consistent
	var observation := {"seen":seen, "samples":samples, "distinct_positions":positions.size(), "settled":settled, "source_consistent":all_consistent, "simulation_seconds":_simulated_seconds-start, "npc_root_repositioned":false}
	_report["grounded_%s_patrol" % role] = observation
	await _record_action("grounded-%s-patrol" % role, "walk", "right", "authored", _actor_anchor(), complete, observation)
	await _capture("settled")
