extends Node

const MainScene := preload("res://game/main.tscn")
const Release = preload("res://game/tests/audio_playback_release.gd")
const Library = preload("res://game/world/character_animation_library.gd")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before the NPC dialogue-hold test.")
		get_tree().quit(1)
		return
	Progress.intro_seen = true
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)
	var world: Node = main.world
	var activity: Variant = world.npc_activity
	var actor := _actor_record(main,"ticket")
	var actor_root := actor.get("activity_root") as Node3D
	var sprite := actor.get("sprite") as Sprite3D
	var route_actor := _actor_record(main,"announcer").get("activity_root") as Node3D
	_check(actor_root != null and sprite != null and route_actor != null and activity._player.is_playing(), "Main starts the NPC route before dialogue")
	if actor_root == null or sprite == null:
		await _finish(main)
		return

	world.player.global_position = actor_root.global_position + Vector3(0.0,0.1,1.0)
	await _frames(2)
	world._physics_process(1.0 / 60.0)
	_check(String(world.nearest.get("id","")) == "guide", "player proximity selects the guide interaction")
	if String(world.nearest.get("id","")) != "guide":
		await _finish(main)
		return
	var route_origin: Vector3 = route_actor.global_position
	world.interact()
	_check(main.modal_kind == "dialogue" and world.blocked, "the actual NPC interaction opens a blocking dialogue")
	_check(world.npc_dialogue_hold and activity.statistics().dialogue_hold, "Main activates the dialogue-specific NPC hold")
	_check(activity.statistics().activity_paused == false and not activity._player.is_playing(), "dialogue pauses the route track while retaining actor frame processing")
	_check(String(_activity_record(main,"ticket").action) == "greet", "the selected guide begins its actual greeting action")
	var dialogue_start_elapsed: float = float(_activity_record(main,"ticket").action_elapsed)
	var dialogue_start_texture: Texture2D = sprite.texture
	var route_time: float = activity._player.get_current_animation_position()
	await get_tree().create_timer(0.45).timeout
	var dialogue_elapsed: float = float(_activity_record(main,"ticket").action_elapsed)
	_check(dialogue_elapsed > dialogue_start_elapsed + 0.15, "authored NPC frames advance in real time during dialogue")
	_check(sprite.texture != dialogue_start_texture, "the NPC displays a later authored interaction frame during dialogue")
	_check(route_actor.global_position.distance_to(route_origin) < 0.001, "the announcer route position is held during dialogue")
	_check(is_equal_approx(activity._player.get_current_animation_position(),route_time), "the route animation timeline is held during dialogue")
	await get_tree().create_timer(0.9).timeout
	var resting_record := _activity_record(main,"ticket")
	_check(String(resting_record.action) in ["stand","idle"], "completed interaction settles to an idle pose while dialogue remains open")
	_check(bool(resting_record.action_sequence.get("loop",false)), "the held NPC returns to a looping idle/breathing sequence")
	var route_frozen_position: Vector3 = route_actor.global_position
	_check(route_frozen_position.distance_to(route_origin) < 0.001, "longer dialogue still does not advance the NPC route")
	main._cancel_dialogue()
	await _frames(2)
	_check(not world.npc_dialogue_hold and not world.blocked, "cancelling the dialogue releases the special hold")
	_check(activity._player.is_playing(), "cancelling dialogue resumes the announcer route")
	var post_close_start: Dictionary = _activity_record(main,"ticket")
	var post_close_elapsed: float = float(post_close_start.action_elapsed)
	var post_close_texture: Texture2D = sprite.texture
	await get_tree().create_timer(0.8).timeout
	var post_close_end: Dictionary = _activity_record(main,"ticket")
	_check(float(post_close_end.action_elapsed) > post_close_elapsed + 0.15, "idle/breathing animation keeps advancing after dialogue closes")
	_check(sprite.texture != post_close_texture, "the idle/breathing pose shows a later authored frame after close")

	var modal_pause_elapsed := float(_activity_record(main,"ticket").action_elapsed)
	var modal_pause_texture: Texture2D = sprite.texture
	var modal_pause_route: Vector3 = route_actor.global_position
	await _press_key(KEY_ESCAPE)
	_check(main.modal_kind == "pause" and world.blocked, "Escape opens Main's real pause modal")
	await _frames(3)
	await get_tree().create_timer(0.25).timeout
	_check(is_equal_approx(float(_activity_record(main,"ticket").action_elapsed),modal_pause_elapsed), "Main pause modal freezes the guide action timeline")
	_check(sprite.texture == modal_pause_texture, "Main pause modal freezes the guide's authored frame")
	_check(route_actor.global_position.distance_to(modal_pause_route) < 0.001, "Main pause modal freezes the announcer route")
	_check(bool(activity.statistics().activity_paused), "Main pause modal pauses the NPC activity controller")
	await _press_key(KEY_ESCAPE)
	_check(main.modal_kind == "" and not world.blocked, "Escape closes Main's pause modal")
	await _frames(2)
	_check(activity._player.is_playing(), "closing Main's pause modal resumes NPC activity")

	# Retain this lower-level blocked-flag check separately from Main's modal path.
	world.blocked = true
	await _frames(2)
	var paused_elapsed: float = float(_activity_record(main,"ticket").action_elapsed)
	await get_tree().create_timer(0.25).timeout
	_check(is_equal_approx(float(_activity_record(main,"ticket").action_elapsed),paused_elapsed), "a true non-dialogue modal pause stops NPC frames")
	world.blocked = false
	await _frames(2)
	world.apply_settings({"reduced_motion":true})
	var reduced_elapsed: float = float(_activity_record(main,"ticket").action_elapsed)
	await get_tree().create_timer(0.25).timeout
	_check(is_equal_approx(float(_activity_record(main,"ticket").action_elapsed),reduced_elapsed), "reduced motion stops NPC frames after dialogue")
	world.apply_settings({"reduced_motion":false})
	print("DIALOGUE-HOLD measured: greeting %.3f→%.3f s; idle after close %.3f→%.3f s; announcer route remained at %s" % [dialogue_start_elapsed,dialogue_elapsed,post_close_elapsed,float(post_close_end.action_elapsed),str(route_origin)])
	await _check_approaches(main)
	await _finish(main)


func _check_approaches(main: Node) -> void:
	var world: Node = main.world
	var activity: Variant = world.npc_activity
	var approaches := {
		"front": Vector3(0,0,1), "front_right": Vector3(1,0,1),
		"right": Vector3(1,0,0), "back_right": Vector3(1,0,-1),
		"back": Vector3(0,0,-1), "back_left": Vector3(-1,0,-1),
		"left": Vector3(-1,0,0), "front_left": Vector3(-1,0,1),
	}
	for role in ["ticket", "imp", "announcer"]:
		var point_id := "guide" if role == "ticket" else ("quest-001" if role == "imp" else "quest-002")
		var action := "greet" if role == "ticket" else "interact"
		var actor := _actor_record(main, role)
		var actor_root := actor.get("activity_root") as Node3D
		var sprite := actor.get("sprite") as Sprite3D
		for approach in approaches:
			var label := "%s/%s" % [role, approach]
			await _approach(main, actor_root, approaches[approach])
			_check(String(world.nearest.get("id", "")) == point_id, label + " real physics proximity selects its NPC")
			var held_roots := {}
			var held_points := {}
			for other in world.character_sprites:
				held_roots[other.role] = other.activity_root.global_position
				held_points[other.role] = world._point_by_id("guide" if other.role == "ticket" else ("quest-001" if other.role == "imp" else "quest-002")).position
			world.interact()
			_check(main.modal_kind == "dialogue" and world.blocked and world.npc_dialogue_hold and activity.statistics().dialogue_hold, label + " actual interaction opens held Main dialogue")
			var record := _activity_record(main, role)
			var sequence: Dictionary = record.action_sequence
			_check(String(record.action) == action and String(record.direction) == "front" and bool(sequence.get("available", false)) and not bool(sequence.get("loop", true)) and sequence.get("frames", []).size() >= 7, label + " selects the complete finite front action")
			_check(sprite.visible and sprite.texture.get_size() == Vector2(activity.ACTION_CANVAS_SIZE), label + " displays a complete authored action canvas")
			var start_elapsed := float(record.action_elapsed)
			var start_texture := sprite.texture
			# Advance the actual selected sequence; keep the original real-time checks above.
			activity._process(0.24)
			record = _activity_record(main, role)
			_check(float(record.action_elapsed) > start_elapsed + 0.2 and sprite.texture != start_texture, label + " held action advances to a later authored frame")
			activity._process(activity._sequence_seconds(sequence) + 0.05)
			record = _activity_record(main, role)
			_check(String(record.action) in ["stand", "idle"] and bool(record.action_sequence.get("loop", false)) and sprite.texture != null and main.modal_kind == "dialogue", label + " action ends in complete looping standing during dialogue")
			for other in world.character_sprites:
				var point: Dictionary = world._point_by_id("guide" if other.role == "ticket" else ("quest-001" if other.role == "imp" else "quest-002"))
				_check(other.activity_root.global_position.distance_to(held_roots[other.role]) < 0.001 and point.position.distance_to(held_points[other.role]) < 0.001, label + " preserves " + String(other.role) + " root and interaction point")
			main._cancel_dialogue()
			await _frames(2)
			_check(main.modal_kind == "" and not world.blocked and not world.npc_dialogue_hold and not activity.statistics().dialogue_hold and activity._player.is_playing(), label + " cancellation safely releases Main hold and resumes the route")
		await _check_unavailable_action(main, role, point_id, action, actor_root, sprite)
	print("APPROACH coverage: 3 roles × 8 distinct geometric offsets; real physics nearest/interact/Main dialogue; direct missing direction and damaged front source per role")


func _approach(main: Node, actor_root: Node3D, offset: Vector3) -> void:
	main.world.player.global_position = actor_root.global_position + offset.normalized() * 1.6 + Vector3(0,0.1,0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _check_unavailable_action(main: Node, role: String, point_id: String, action: String, actor_root: Node3D, sprite: Sprite3D) -> void:
	var activity: Variant = main.world.npc_activity
	await _approach(main, actor_root, Vector3(-1,0,-1))
	_check(activity.request_action(sprite, action, "front"), role + " valid action can precede an unsupported direct direction")
	activity._process(0.24)
	_check(not activity.request_action(sprite, action, "back_left"), role + " unsupported direct direction remains unavailable")
	var record := _activity_record(main, role)
	_check(String(record.action) == "stand" and record.action_sequence.is_empty() and sprite.texture == record.baseline_texture and sprite.visible, role + " missing direct direction restores its complete standing baseline")
	_check(activity.coverage_report().missing_requests[role].has(action + "/back_left"), role + " missing direct direction remains explicitly reported")
	_check(activity.request_action(sprite, action, "front"), role + " valid gesture can precede a damaged front source")
	activity._process(0.24)
	var previous_library: Variant = activity._animation_library
	var damaged := Library.new()
	# Existing damaged-source mechanism: invalidate a later source cel before caching.
	damaged.manifest.actors[role][action].front.frames[-1].region = [99999,0,10,10]
	activity._animation_library = damaged
	_check(String(main.world.nearest.get("id", "")) == point_id, role + " damaged-source check retains real proximity selection")
	main.world.interact()
	record = _activity_record(main, role)
	_check(main.modal_kind == "dialogue" and main.world.npc_dialogue_hold, role + " damaged front source still opens actual Main dialogue")
	_check(String(record.action) == "stand" and record.action_sequence.is_empty() and sprite.texture == record.baseline_texture and sprite.visible, role + " damaged front source restores the complete actor instead of retaining a gesture")
	_check(activity.coverage_report().missing_requests[role].has(action + "/front"), role + " damaged front source remains explicitly reported")
	main._cancel_dialogue()
	activity._animation_library = previous_library
	await _frames(2)
	_check(main.modal_kind == "" and not main.world.blocked and not main.world.npc_dialogue_hold and activity._player.is_playing(), role + " damaged-source dialogue cancels and releases safely")


func _actor_record(main: Node, role: String) -> Dictionary:
	for record in main.world.character_sprites:
		if String(record.role) == role:
			return record
	return {}


func _activity_record(main: Node, role: String) -> Dictionary:
	for record in main.world.npc_activity._records:
		if String(record.role) == role:
			return record
	return {}


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish(main: Node) -> void:
	main.quitting = true
	var playbacks: Array[WeakRef] = Release.capture(main.audio)
	main.audio.shutdown()
	main.queue_free()
	await _frames(2)
	_check(await Release.wait_for_release(get_tree(), playbacks), "audio backend releases stopped playbacks before exit")
	if _failures.is_empty():
		print("PASS: Main NPC dialogue hold lifecycle")
		get_tree().quit(0)
	else:
		push_error("NPC dialogue hold failures: " + "; ".join(_failures))
		get_tree().quit(1)
