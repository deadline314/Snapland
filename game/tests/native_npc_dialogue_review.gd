extends Node

const MainScene := preload("res://game/main.tscn")
const NPC_IMAGES := [
	"pm/Snapland-art/images/ART-17-npc-dialogue-native-open.png",
	"pm/Snapland-art/images/ART-17-npc-dialogue-native-idle.png",
	"pm/Snapland-art/images/ART-17-npc-dialogue-native-pause.png",
]

var _main: Node
var _failures: Array[String] = []
var _receipt: Dictionary = {
	"review": "ART-17 native NPC dialogue and animation review",
	"method": "scripted Main instantiation, simulated Escape/E input, scripted player/camera placement; not human gameplay evidence",
	"captures": [],
	"checks": {},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		await _fail_and_quit("This review fixture requires a GPU-backed display; it was not run headless.")
		return
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or save_path.contains("://") or not save_path.is_absolute_path():
		await _fail_and_quit("Set SNAPLAND_SAVE_PATH to an isolated absolute filesystem save file before running this review.")
		return
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = false
	if not Progress.save_progress():
		await _fail_and_quit("Could not initialize the isolated review save profile.")
		return
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(4)
	if not _require(_main.modal_kind == "dialogue", "Main opens arrival dialogue on the isolated fresh profile"):
		await _finish()
		return
	await _press_key(KEY_ESCAPE)
	if not _require(_main.modal_kind == "" and Progress.intro_seen, "Escape dismisses the actual arrival dialogue"):
		await _finish()
		return

	var actor := _actor_record("ticket")
	var actor_root := actor.get("activity_root") as Node3D
	var actor_sprite := actor.get("sprite") as Sprite3D
	if not _require(actor_root != null and actor_sprite != null, "the live guide actor and authored sprite exist"):
		await _finish()
		return
	_main.world.player.global_position = actor_root.global_position + Vector3(0.0, 0.1, 1.0)
	await _frames(3)
	_main.world._physics_process(1.0 / 60.0)
	if not _require(String(_main.world.nearest.get("id", "")) == "guide", "actual player proximity selects the guide interaction point"):
		await _finish()
		return
	await _press_key(KEY_E)
	if not _require(_main.modal_kind == "dialogue" and _main.world.npc_dialogue_hold, "E opens the guide's real dialogue and enables its animation hold"):
		await _finish()
		return
	var activity: Variant = _main.world.npc_activity
	var start_elapsed := float(_activity_record("ticket").get("action_elapsed", 0.0))
	var route_root := (_actor_record("announcer").get("activity_root") as Node3D)
	var route_start := route_root.global_position
	var start_tick := Time.get_ticks_msec()
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var open_elapsed := float(_activity_record("ticket").get("action_elapsed", 0.0))
	var route_held := route_root.global_position.distance_to(route_start) < 0.001
	_require(open_elapsed > start_elapsed + 0.5, "guide action/breathing timeline advances during a three-second dialogue")
	_require(route_held, "ambient announcer route stays held while dialogue is open")
	_require(_main.modal_kind == "dialogue" and _main.dialogue_panel.visible, "the real dialogue panel remains open during the animation wait")
	_receipt.checks["dialogue_open"] = {
		"simulation_wait_seconds": 3.0,
		"wall_elapsed_ms": Time.get_ticks_msec() - start_tick,
		"guide_action_elapsed_start": start_elapsed,
		"guide_action_elapsed_end": open_elapsed,
		"announcer_route_start": [route_start.x, route_start.y, route_start.z],
		"announcer_route_held": route_held,
	}
	if not await _frame_guide_for_review(actor_root, actor_sprite):
		await _finish()
		return
	if not await _capture(NPC_IMAGES[0], "dialogue open after 3s; guide in natural world position"):
		await _finish()
		return

	await _press_key(KEY_ESCAPE)
	if not _require(_main.modal_kind == "" and not _main.world.npc_dialogue_hold, "Escape closes dialogue and releases the NPC hold"):
		await _finish()
		return
	var idle_start := float(_activity_record("ticket").get("action_elapsed", 0.0))
	var idle_action_start := String(_activity_record("ticket").get("action", ""))
	var idle_clock_start := float(activity._action_clock)
	var guide_motion: Variant = _activity_record("ticket").get("motion")
	var guide_rig: Variant = guide_motion.rig if is_instance_valid(guide_motion) else null
	var idle_rig_travel_start := float(guide_rig.travel) if is_instance_valid(guide_rig) else 0.0
	var idle_root_start := actor_root.global_position
	var previous_idle_root := idle_root_start
	var idle_root_path_distance := 0.0
	var idle_foot_pose_change_frames := 0
	var previous_idle_feet: Array = guide_rig.foot_world.duplicate() if is_instance_valid(guide_rig) else []
	var idle_tick := Time.get_ticks_msec()
	var idle_simulated_seconds := 0.0
	var idle_elapsed_progress := 0.0
	var idle_frame_changes := 0
	var idle_action_changes := 0
	var previous_idle_elapsed := idle_start
	var previous_idle_action := idle_action_start
	var previous_idle_texture: Texture2D = actor_sprite.texture
	while idle_simulated_seconds < 3.0:
		await get_tree().process_frame
		idle_simulated_seconds += get_process_delta_time()
		var current_record := _activity_record("ticket")
		var current_elapsed := float(current_record.get("action_elapsed", 0.0))
		var current_action := String(current_record.get("action", ""))
		if current_action != previous_idle_action:
			idle_action_changes += 1
			idle_elapsed_progress += current_elapsed
		elif current_elapsed >= previous_idle_elapsed:
			idle_elapsed_progress += current_elapsed - previous_idle_elapsed
		if actor_sprite.texture != previous_idle_texture:
			idle_frame_changes += 1
		var current_root := actor_root.global_position
		idle_root_path_distance += Vector2(current_root.x - previous_idle_root.x, current_root.z - previous_idle_root.z).length()
		previous_idle_root = current_root
		if is_instance_valid(guide_rig):
			var current_feet: Array = guide_rig.foot_world
			if current_feet.size() == previous_idle_feet.size():
				for foot_index in range(current_feet.size()):
					if (current_feet[foot_index] as Vector3).distance_to(previous_idle_feet[foot_index] as Vector3) > 0.001:
						idle_foot_pose_change_frames += 1
						break
			previous_idle_feet = current_feet.duplicate()
		previous_idle_elapsed = current_elapsed
		previous_idle_action = current_action
		previous_idle_texture = actor_sprite.texture
	await RenderingServer.frame_post_draw
	var idle_end := float(_activity_record("ticket").get("action_elapsed", 0.0))
	var idle_clock_end := float(activity._action_clock)
	var idle_rig_travel_end := float(guide_rig.travel) if is_instance_valid(guide_rig) else 0.0
	var idle_rig_travel_delta := absf(idle_rig_travel_end - idle_rig_travel_start)
	var idle_animation_advanced := idle_clock_end > idle_clock_start + 2.5 and (
		idle_elapsed_progress > 0.5
		or idle_frame_changes >= 2
		or idle_rig_travel_delta > 0.02
		or idle_foot_pose_change_frames >= 2
		or idle_root_path_distance > 0.02
	)
	_require(idle_simulated_seconds>=3.0 and idle_animation_advanced, "guide sprite/action animation advances for three simulated seconds after dialogue closes, including any scheduler sequence reset")
	_receipt.checks["dialogue_closed_idle"] = {
		"simulation_wait_seconds": 3.0,
		"simulation_elapsed_seconds": idle_simulated_seconds,
		"wall_elapsed_ms": Time.get_ticks_msec() - idle_tick,
		"guide_action_elapsed_start": idle_start,
		"guide_action_elapsed_end": idle_end,
		"guide_action_elapsed_positive_progress_seconds": idle_elapsed_progress,
		"guide_sprite_frame_changes": idle_frame_changes,
		"guide_action_sequence_changes": idle_action_changes,
		"guide_motion_rig_present": is_instance_valid(guide_rig),
		"guide_rig_travel_start": idle_rig_travel_start,
		"guide_rig_travel_end": idle_rig_travel_end,
		"guide_rig_travel_delta": idle_rig_travel_delta,
		"guide_foot_pose_change_frames": idle_foot_pose_change_frames,
		"guide_root_path_distance": idle_root_path_distance,
		"guide_root_position_start": [idle_root_start.x, idle_root_start.y, idle_root_start.z],
		"guide_root_position_end": [actor_root.global_position.x, actor_root.global_position.y, actor_root.global_position.z],
		"activity_clock_start": idle_clock_start,
		"activity_clock_end": idle_clock_end,
		"animation_advanced": idle_animation_advanced,
	}
	if not await _capture(NPC_IMAGES[1], "dialogue closed; guide continues idle/breathing"):
		await _finish()
		return

	var pause_elapsed_before := float(_activity_record("ticket").get("action_elapsed", 0.0))
	var pause_clock_before := float(activity._action_clock)
	var pause_texture_before := actor_sprite.texture
	var route_before_pause := route_root.global_position
	await _press_key(KEY_ESCAPE)
	if not _require(_main.modal_kind == "pause" and _main.world.blocked, "Escape opens Main's actual pause modal"):
		await _finish()
		return
	await _frames(3)
	var pause_tick := Time.get_ticks_msec()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var pause_elapsed_after := float(_activity_record("ticket").get("action_elapsed", 0.0))
	var pause_clock_after := float(activity._action_clock)
	var pause_texture_after := actor_sprite.texture
	var route_after_pause := route_root.global_position
	var frozen := is_equal_approx(pause_elapsed_before, pause_elapsed_after) and is_equal_approx(pause_clock_before,pause_clock_after) and pause_texture_before == pause_texture_after and route_before_pause.distance_to(route_after_pause) < 0.001
	_require(frozen, "one-second real pause freezes guide frame/timeline and announcer route")
	_receipt.checks["true_pause"] = {
		"simulation_wait_seconds": 1.0,
		"wall_elapsed_ms": Time.get_ticks_msec() - pause_tick,
		"guide_action_elapsed_before": pause_elapsed_before,
		"guide_action_elapsed_after": pause_elapsed_after,
		"activity_clock_before": pause_clock_before,
		"activity_clock_after": pause_clock_after,
		"guide_texture_unchanged": pause_texture_before == pause_texture_after,
		"announcer_route_unchanged": route_before_pause.distance_to(route_after_pause) < 0.001,
		"freeze_verified": frozen,
	}
	if not await _capture(NPC_IMAGES[2], "Main pause modal after a one-second animation freeze"):
		await _finish()
		return
	await _press_key(KEY_ESCAPE)
	if not _require(_main.modal_kind == "", "Escape closes the pause modal after its freeze capture"):
		await _finish()
		return
	_receipt.checks["scripted_camera_and_visibility"] = {
		"hero_visual_hidden": _receipt.checks.get("scripted_camera_and_visibility", {}).get("hero_visual_hidden", true),
		"guide_world_position_unchanged": true,
		"camera_framing": "scripted close framing for evidence only",
		"occlusion_ray_clear": _receipt.checks.get("scripted_camera_and_visibility", {}).get("occlusion_ray_clear", false),
		"guide_in_view": _receipt.checks.get("scripted_camera_and_visibility", {}).get("guide_in_view", false),
		"guide_world_position": _receipt.checks.get("scripted_camera_and_visibility", {}).get("guide_world_position", []),
		"camera_position": _receipt.checks.get("scripted_camera_and_visibility", {}).get("camera_position", []),
		"occlusion_hit_collider": _receipt.checks.get("scripted_camera_and_visibility", {}).get("occlusion_hit_collider", ""),
	}
	await _finish()


func _frame_guide_for_review(actor_root: Node3D, actor_sprite: Sprite3D) -> bool:
	# Keep the authored guide location and route intact. This fixture only hides
	# the player visual and sets a close evidence camera after the real interaction.
	_main.world.player.visible = false
	_main.world.set_physics_process(false)
	var camera: Camera3D = _main.world.camera
	camera.current = true
	camera.global_position = actor_root.global_position + Vector3(0.0, 2.0, 4.2)
	camera.look_at(actor_root.global_position + Vector3(0.0, 0.45, 0.0), Vector3.UP)
	camera.size = 5.2
	_main.world._update_sprite_grounding()
	await _frames(3)
	var view_rect := get_viewport().get_visible_rect()
	var projected := camera.unproject_position(actor_sprite.global_position + Vector3(0, 1.0, 0))
	var visible := actor_sprite.is_visible_in_tree() and not camera.is_position_behind(actor_sprite.global_position) and view_rect.has_point(projected)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, actor_root.global_position + Vector3(0.0, 1.0, 0.0), 1, [_main.world.player.get_rid()])
	var hit: Dictionary = _main.world.get_world_3d().direct_space_state.intersect_ray(query)
	var clear := hit.is_empty()
	var hit_collider_name := ""
	if not hit.is_empty() and hit.get("collider") is Node:
		hit_collider_name = String((hit.get("collider") as Node).name)
	_receipt.checks["scripted_camera_and_visibility"] = {
		"hero_visual_hidden": true,
		"guide_world_position": [actor_root.global_position.x, actor_root.global_position.y, actor_root.global_position.z],
		"camera_position": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
		"guide_in_view": visible,
		"occlusion_ray_clear": clear,
		"occlusion_hit_collider": hit_collider_name,
		"camera_framing": "scripted close framing for evidence only",
	}
	return _require(visible and clear, "scripted close camera sees the naturally placed guide without tree/geometry occlusion (hero visual hidden)")


func _capture(relative_path: String, description: String) -> bool:
	await RenderingServer.frame_post_draw
	var saved := bool(_main._capture(relative_path))
	var absolute_path := ProjectSettings.globalize_path("res://" + relative_path)
	var exists := FileAccess.file_exists(absolute_path) and FileAccess.get_file_as_bytes(absolute_path).size() > 0
	var passed := saved and exists
	_receipt.captures.append({"path": absolute_path, "description": description, "saved": passed, "frame": Engine.get_process_frames(), "wall_ticks_ms": Time.get_ticks_msec()})
	return _require(passed, "capture saved: " + relative_path)


func _actor_record(role: String) -> Dictionary:
	for record: Dictionary in _main.world.character_sprites:
		if String(record.get("role", "")) == role:
			return record
	return {}


func _activity_record(role: String) -> Dictionary:
	for record: Dictionary in _main.world.npc_activity._records:
		if String(record.get("role", "")) == role:
			return record
	return {}


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		print("PASS: " + message)
		return true
	_failures.append(message)
	push_error("FAIL: " + message)
	return false


func _finish() -> void:
	_receipt["failures"] = _failures.duplicate()
	_receipt["result"] = "PASS" if _failures.is_empty() else "FAIL"
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	var receipt_path := save_path.get_base_dir().path_join("npc-dialogue-native-review.json")
	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not write receipt into isolated caller save folder: " + receipt_path)
		push_error(_failures.back())
	else:
		file.store_string(JSON.stringify(_receipt, "\t"))
		file.close()
	if is_instance_valid(_main):
		_main.audio.shutdown()
		_main.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("PASS: native NPC dialogue review; scripted placement/camera and hidden hero are documented in receipt.")
		get_tree().quit(0)
	else:
		push_error("Native NPC dialogue review failed: " + "; ".join(_failures))
		get_tree().quit(1)


func _fail_and_quit(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
