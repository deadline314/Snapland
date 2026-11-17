extends "res://game/tests/native_layout_review.gd"

const NpcRoles := ["ticket", "imp", "announcer"]
const Guard := preload("res://game/core/test_save_guard.gd")
const Timing := preload("res://game/world/character_animation_timing.gd")
const Release := preload("res://game/tests/audio_playback_release.gd")
var records: Dictionary = {}
var _npc_output := ""
var _npc_sequences: Dictionary = {}
var _npc_report := {"status": "RUNNING", "human_played": false, "roles": [], "captures": [],
	"staging": "Camera follow disabled; hero positioned offscreen at (15,0.4,-24.5); noon close cameras. NPC roots, actions, textures and clocks are never assigned."}

func _run() -> void:
	if DisplayServer.get_name() == "headless" or not _prepare_npc_output():
		await _npc_finish("Native NPC review requires GPU, fresh isolated absolute save and empty native-npc-review output")
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _npc_finish("Native NPC review has no Progress autoload")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		await _npc_finish("Native NPC review could not instantiate Main")
		return
	get_tree().root.add_child(main)
	await _frames(8)
	var controller: Node = main.world.npc_activity
	if controller == null:
		await _npc_finish("Native world has no authored NPC activity controller")
		return
	var stats: Dictionary = controller.statistics()
	if int(stats.get("registration_count", 0)) != 3 or not bool(stats.get("playing", false)):
		await _npc_finish("Native NPC activity is not playing exactly three authored roles: " + str(stats))
		return
	for record: Dictionary in controller._records:
		if bool(record.get("active", false)): records[str(record.role)] = record
	for role in NpcRoles:
		if not records.has(role) or int(stats.get("by_role", {}).get(role, 0)) != 1:
			await _npc_finish("Native authored NPC role is missing/duplicated: " + role)
			return
	# Freeze camera follow for clear, close views; animation playback remains live.
	# Fixture placement is not player-input walking evidence.
	main.world.set_physics_process(false)
	main.world.player.position = Vector3(15, 0.4, -24.5)
	main.world.set_time_of_day("noon")
	for role in NpcRoles:
		if not await _review_role(role): return
	main.world.apply_settings({"reduced_motion": true})
	var reduced_textures: Dictionary = {}
	var reduced_positions: Dictionary = {}
	var reduced_points: Dictionary = {}
	var reduced_clock: float = controller._action_clock
	for role in NpcRoles:
		var sprite := _sprite(role)
		var anchor := _anchor(role)
		reduced_textures[role] = sprite.texture
		reduced_positions[role] = anchor.position
		reduced_points[role] = records[role].point.position
	await get_tree().create_timer(0.4).timeout
	if bool(controller.statistics().get("playing", true)) or controller._action_clock != reduced_clock:
		await _npc_finish("Reduced motion did not pause authored NPC playback/time")
		return
	for role in NpcRoles:
		var record: Dictionary = records[role]
		var material := _sprite(role).material_override as ShaderMaterial
		var frames: Array = _formal_npc_sequence(role, "stand", "front").get("frames", [])
		var expected := frames[0].texture as Texture2D if not frames.is_empty() else null
		if role == "announcer" and expected != null: expected = controller._costume_texture(role, expected)
		if record.action != "stand" or record.direction != "front" or not is_zero_approx(float(record.action_elapsed)) or expected == null or _formal_npc_pose(role) < 0 or _sprite(role).texture != reduced_textures[role] or _anchor(role).position != reduced_positions[role] or _anchor(role).position != record.baseline_anchor_position or record.point.position != reduced_points[role] or record.point.position != record.original_point_position or _sprite(role).texture != expected or material == null or material.get_shader_parameter("texture_albedo") != _sprite(role).texture or material.get_shader_parameter("uv_rect") != Vector4(0,0,1,1):
			await _npc_finish("Reduced motion did not retain stable synchronized formal standing/root/point: " + role)
			return
	_npc_report["reduced_standing"] = true
	main.world.apply_settings({"reduced_motion": false})
	await get_tree().create_timer(0.4).timeout
	if not bool(controller.statistics().get("playing", false)) or controller._action_clock <= reduced_clock:
		await _npc_finish("NPC activity did not resume after reduced-motion fixture")
		return
	for role in NpcRoles:
		if _formal_npc_pose(role) < 0:
			await _npc_finish("NPC formal source/material did not resume: " + role)
			return
	_npc_report["resumed"] = true
	await _npc_finish()

func _prepare_npc_output() -> bool:
	var save := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if not Guard.validate_save_path(save, OS.get_user_data_dir()).is_empty() or FileAccess.file_exists(save) or DirAccess.dir_exists_absolute(save): return false
	var project := Guard._normalized_path(ProjectSettings.globalize_path("res://"))
	var output := save.get_base_dir().path_join("native-npc-review")
	var normalized := Guard._normalized_path(output)
	if Guard._path_is_inside(Guard._normalized_path(save), project) or Guard._path_is_inside(normalized, project) or Guard._path_is_inside(project, normalized): return false
	if FileAccess.file_exists(output): return false
	if DirAccess.dir_exists_absolute(output):
		var directory := DirAccess.open(output)
		if directory == null or not directory.get_files().is_empty() or not directory.get_directories().is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(output) != OK: return false
	_npc_output = output
	_npc_report["display"] = DisplayServer.get_name()
	return true

func _npc_finish(failure: String = "") -> void:
	if is_instance_valid(main):
		main.quitting = true
		var playbacks := Release.capture(main.audio)
		main.audio.shutdown()
		main.queue_free()
		await _frames(2)
		if not await Release.wait_for_release(get_tree(), playbacks): failure += " Audio playbacks did not release before exit."
		main = null
	_npc_report["status"] = "PASS" if failure.is_empty() else "FAIL"
	_npc_report["failure"] = failure
	if not _npc_output.is_empty():
		_npc_report["source_sha256"] = FileAccess.get_sha256("res://game/tests/native_npc_review.gd")
		var receipt := FileAccess.open(_npc_output.path_join("receipt.json"), FileAccess.WRITE)
		if receipt == null: failure += " Could not open native NPC receipt."
		else:
			receipt.store_string(JSON.stringify(_npc_report, "\t"))
			receipt.flush()
			if receipt.get_error() != OK: failure += " Could not write native NPC receipt."
			receipt.close()
	if failure.is_empty():
		print("PASS: native NPC formal-source playback, bounded patrol, labels, interaction points and reduced standing")
		get_tree().quit(0)
	else:
		push_error(failure)
		get_tree().quit(1)

func _formal_npc_sequence(role: String, action: String, direction: String) -> Dictionary:
	var key := "%s/%s/%s" % [role, action, direction]
	if not _npc_sequences.has(key):
		var controller: Node = main.world.npc_activity
		if controller._animation_library == null: return {}
		var sequence := {}
		for candidate in (["stand", "idle", "idle_stand"] if action == "stand" else [action]):
			sequence = controller._normalize_sequence(controller._animation_library.get_sequence(role, candidate, direction))
			if bool(sequence.get("available", false)): break
		_npc_sequences[key] = sequence
	return _npc_sequences[key]

func _formal_npc_pose(role: String) -> int:
	var record: Dictionary = records[role]
	var live: Dictionary = record.action_sequence
	var formal := _formal_npc_sequence(role, record.action, record.direction)
	var frames: Array = formal.get("frames", [])
	var actual: Array = live.get("frames", [])
	if not Timing.is_valid(live) or not bool(formal.get("available", false)) or bool(live.get("legacy_fallback", false)) or frames.is_empty() or frames.size() != actual.size() or not _texture_synced(_sprite(role)): return -1
	for field in ["fps", "loop", "frame_durations"]:
		if live.get(field) != formal.get(field): return -1
	var pose := -1
	for index in frames.size():
		var source := frames[index].texture as Texture2D
		if source == null or source.get_size() != Vector2(320,460) or actual[index].get("texture") != source: return -1
		var expected := source
		if role == "announcer":
			# Playback already decorated this cel; inspect its bounded cache without rerendering pixels.
			expected = main.world.npc_activity._npc_costume._cache.get(source.get_instance_id(), {}).get("texture") as Texture2D
		if expected != null and _sprite(role).texture == expected: pose = index
	return pose

func _sprite(role: String) -> Sprite3D:
	return records[role].target.get_ref() as Sprite3D

func _anchor(role: String) -> Node3D:
	return records[role].anchor.get_ref() as Node3D

func _texture_synced(sprite: Sprite3D) -> bool:
	var material := sprite.material_override as ShaderMaterial
	return sprite.texture != null and material != null and material.get_shader_parameter("texture_albedo") == sprite.texture and material.get_shader_parameter("uv_rect") == Vector4(0, 0, 1, 1)

func _review_role(role: String) -> bool:
	var sprite := _sprite(role)
	var anchor := _anchor(role)
	var record: Dictionary = records[role]
	var point: Dictionary = record.point
	var expected_point_id: String = {"ticket": "guide", "imp": "quest-001", "announcer": "quest-002"}[role]
	var expected_base: Vector3 = {"ticket": Vector3(-3.8, 0, 5), "imp": Vector3(-4.1, 0, -7.5), "announcer": Vector3(3.4, 0, -4)}[role]
	var expected_name: String = {"ticket": "票票", "imp": "小角", "announcer": "阿浪"}[role]
	var label: Label3D = null
	for child in anchor.get_children():
		if child is Label3D and child.text == expected_name: label = child
	if label == null or str(point.get("id", "")) != expected_point_id or Vector3(record.baseline_anchor_position).distance_to(expected_base) > 0.01:
		await _npc_finish("NPC label/root/interaction identity mismatch: %s point=%s root=%s" % [role, point, record.baseline_anchor_position])
		return false
	var marker := point.get("marker") as Label3D
	if marker == null or marker.get_parent() != anchor or marker.text != "◇":
		await _npc_finish("NPC interaction marker identity/parent mismatch: " + role)
		return false
	var marker_offset := marker.position
	var label_offset := label.position
	var profile: Dictionary = main.world.npc_activity.AuthoredPatrolScript._validated_profile(main.world.npc_activity.AUTHORED_PATROL_PROFILES[role])
	if profile.is_empty() or record.get("authored_patrol") == null:
		await _npc_finish("NPC has no validated grounded patrol: " + role)
		return false
	main.world.camera.size = 5.0
	main.world.camera.position = expected_base + Vector3(0, 3.8, 6.5)
	main.world.camera.look_at(expected_base + Vector3(0, 1.45, 0))
	main.world.camera.current = true
	main.world._update_sprite_grounding()
	var seen: Dictionary = {}
	var actions: Dictionary = {}
	var first_saved := false
	var second_saved := false
	var smallest_x := INF
	var largest_x := -INF
	var samples := 0
	var started := Time.get_ticks_msec()
	for sample in range(180):
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		var pose := _formal_npc_pose(role)
		samples += 1
		if pose < 0:
			await _npc_finish("Native formal NPC sprite/shader/source-frame mismatch: " + role)
			return false
		seen[sprite.texture.get_instance_id()] = true
		var action_key := "%s/%s" % [record.action, record.direction]
		if not actions.has(action_key): actions[action_key] = []
		if not actions[action_key].has(pose): actions[action_key].append(pose)
		smallest_x = minf(smallest_x, anchor.position.x)
		largest_x = maxf(largest_x, anchor.position.x)
		var offset: Vector3 = anchor.position - expected_base
		var point_error: float = Vector3(point.position).distance_to(anchor.global_position + Vector3(record.point_offset))
		if offset.x < float(profile.minimum_offset) - 0.001 or offset.x > float(profile.maximum_offset) + 0.001 or absf(offset.y) > 0.001 or absf(offset.z) > 0.001 or point_error > 0.035 or label.position.distance_to(label_offset) > 0.001 or absf(marker.position.x - marker_offset.x) > 0.001 or absf(marker.position.z - marker_offset.z) > 0.001:
			await _npc_finish("NPC root travel/label/marker/interaction point exceeded bounds: %s offset=%s point_error=%.4f" % [role, offset, point_error])
			return false
		if not await _check_npc_visible(sprite, label, role): return false
		if not first_saved:
			if not _save_npc_capture("%s-01.png" % role):
				await _npc_finish("NPC first native capture failed: " + role)
				return false
			first_saved = true
		elif not second_saved and seen.size() > 1:
			if not _save_npc_capture("%s-02.png" % role):
				await _npc_finish("NPC second authored-pose capture failed: " + role)
				return false
			second_saved = true
		if sample >= 69 and seen.size() > 1 and largest_x - smallest_x >= 0.8 * (float(profile.maximum_offset) - float(profile.minimum_offset)): break
	if seen.size() < 2 or not first_saved or not second_saved or largest_x - smallest_x < 0.8 * (float(profile.maximum_offset) - float(profile.minimum_offset)):
		await _npc_finish("NPC live playback did not demonstrate multiple formal poses/significant bounded patrol: %s poses=%d x_range=%.3f" % [role, seen.size(), largest_x - smallest_x])
		return false
	_npc_report.roles.append({"role": role, "point": point.id, "different_poses": seen.size(), "observed_action_direction_pose_indices": actions, "smallest_x": smallest_x, "largest_x": largest_x, "patrol_profile": profile, "samples": samples, "seconds": float(Time.get_ticks_msec() - started) / 1000.0})
	print("NATIVE NPC: ", role, " poses=", seen.size(), " x_range=", largest_x - smallest_x, " point=", point.id, " actions=", actions)
	return true

func _save_npc_capture(filename: String) -> bool:
	var path := _npc_output.path_join(filename)
	if FileAccess.file_exists(path): return false
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK: return false
	_npc_report.captures.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	return true

func _check_npc_visible(sprite: Sprite3D, label: Label3D, role: String) -> bool:
	var view: Rect2 = main.get_viewport().get_visible_rect()
	for target in [sprite, label]:
		var point: Vector3 = target.global_position
		if not target.is_visible_in_tree() or main.world.camera.is_position_behind(point) or not view.has_point(main.world.camera.unproject_position(point)):
			await _npc_finish("NPC body/name is not visible in the native framed view: " + role)
			return false
		var query := PhysicsRayQueryParameters3D.create(main.world.camera.global_position, point, 1, [main.world.player.get_rid()])
		var hit: Dictionary = main.world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			await _npc_finish("NPC body/name is blocked by park geometry: %s hit=%s" % [role, hit])
			return false
	return true
