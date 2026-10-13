extends Node

const MainScene := preload("res://game/main.tscn")

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

	_activity_record(main,"ticket")["route_phase"]=0.0
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

	# Both route halves must keep the authored idle sequence when side walk
	# coverage is absent; the measured driver still consumes actual movement.
	for route_phase in [0.0,1.0]:
		var record := _activity_record(main,"ticket")
		record.route_clock=0.0
		record.route_phase=route_phase
		var before: float=record.action_elapsed
		var anchor_before: Vector3=actor_root.global_position
		await get_tree().create_timer(0.2).timeout
		var after := _activity_record(main,"ticket")
		_check(float(after.action_elapsed)>before+0.1 and not after.action_sequence.is_empty(), "missing side walk retains authored idle timeline on route half %s"%route_phase)
		_check(actor_root.global_position.distance_to(anchor_before)>0.001, "measured route still moves without authored side walk")
	_check(_activity_record(main,"ticket").missing_actions.has("walk/right") and _activity_record(main,"ticket").missing_actions.has("walk/left"), "missing coverage records both real side directions")
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
	await _finish(main)


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
	main.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("PASS: missing authored side walk preserves idle lifecycle and measured route after dialogue")
		get_tree().quit(0)
	else:
		push_error("NPC dialogue hold failures: " + "; ".join(_failures))
		get_tree().quit(1)
