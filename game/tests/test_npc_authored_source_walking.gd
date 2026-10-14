extends SceneTree

const NpcActivity = preload("res://game/world/npc_activity.gd")
const Library = preload("res://game/world/character_animation_library.gd")

const TICK_SECONDS := 1.0 / 30.0
const CYCLE_SECONDS := 8.6
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var controller := NpcActivity.new()
	scene.add_child(controller)
	var actors: Dictionary = {}
	var anchors: Dictionary = {}
	for role in ["ticket", "imp", "announcer"]:
		var anchor := Node3D.new()
		anchor.position = Vector3(float(actors.size()) * 2.0, 0.0, -3.0)
		scene.add_child(anchor)
		var sprite := Sprite3D.new()
		var fallback: Array[Texture2D] = NpcActivity.load_action_frames(role)
		_check(not fallback.is_empty(), "%s has a safe source texture for actor registration" % role)
		if fallback.is_empty():
			anchor.queue_free()
			continue
		sprite.texture = fallback[0]
		anchor.add_child(sprite)
		_check(controller.register_actor(sprite, role, fallback, anchor), "%s actor registers" % role)
		actors[role] = sprite
		anchors[role] = anchor
	controller.finish_registration()
	var camera := Camera3D.new()
	scene.add_child(camera)
	controller.configure_motion(camera, Callable(self, "_ground_height"), false)
	_check(not controller.motion_report().enabled, "production source-cel path leaves measured gait disabled")
	if actors.size() != 3:
		_check(false, "all three NPC actors are available before route sampling")
		controller.release()
		scene.queue_free()
		await process_frame
		_finish_failed()
		return

	var library := Library.new()
	var ticket_candidate: Dictionary = library.get_sequence("ticket", "walk_candidate", "front")
	_check(bool(ticket_candidate.get("available", false)) and ticket_candidate.get("frames", []).size() == 8, "ticket exploratory row exists but remains separately named and is not accepted as walk")
	_check(not controller._has_sequence("ticket", "walk", "right") and not controller._has_sequence("ticket", "walk", "left"), "ticket candidate does not satisfy a directional walk route")
	_check(not controller._has_sequence("imp", "walk", "right") and not controller._has_sequence("imp", "walk", "left"), "imp has no accepted directional walk source")
	_check(controller._has_sequence("announcer", "walk", "right") and controller._has_sequence("announcer", "walk", "left"), "announcer's validated directional source cels select its route")
	if not is_instance_valid(controller._animation_library):
		_check(false, "NPC animation library is available before sequence sampling")
		controller.release()
		scene.queue_free()
		await process_frame
		_finish_failed()
		return
	var announcer_sequences: Dictionary = {}
	var valid_announcer_sequences := true
	for direction in ["right", "left"]:
		var sequence: Dictionary = controller._animation_library.get_sequence("announcer", "walk", direction)
		var frames: Array = sequence.get("frames", [])
		var sequence_valid := bool(sequence.get("available", false)) and frames.size() == 4 and float(sequence.get("fps", 0.0)) > 0.0
		_check(sequence_valid, "announcer %s sequence has four validated source cels" % direction)
		if not sequence_valid:
			valid_announcer_sequences = false
			continue
		var expected: Array[Texture2D] = []
		for frame: Dictionary in frames:
			expected.append(controller._costume_texture("announcer", frame.texture))
		announcer_sequences[direction] = {"fps": float(sequence.fps), "textures": expected, "seen": {}}
	if not valid_announcer_sequences or announcer_sequences.size() != 2:
		controller.release()
		scene.queue_free()
		await process_frame
		_finish_failed()
		return
	var role_indices := {
		"ticket": _record_index(controller, "ticket"),
		"imp": _record_index(controller, "imp"),
		"announcer": _record_index(controller, "announcer"),
	}
	var valid_records := true
	for role in role_indices:
		if int(role_indices[role]) < 0:
			_check(false, "%s controller record exists before sampling" % role)
			valid_records = false
	if not valid_records:
		controller.release()
		scene.queue_free()
		await process_frame
		_finish_failed()
		return

	var ticket_start: Vector3 = anchors.ticket.position
	var imp_start: Vector3 = anchors.imp.position
	var announcer_start: Vector3 = anchors.announcer.position
	var ticket_persona := false
	var imp_persona := false
	var moved_right := false
	var moved_left := false
	var tick_count := ceili(CYCLE_SECONDS * 2.0 / TICK_SECONDS)
	for _tick in range(tick_count):
		# Advance the authored route track and the controller explicitly. No scene
		# playback or waiting is needed; this is the same data-time progression.
		controller._player.advance(TICK_SECONDS)
		controller._process(TICK_SECONDS)
		var right_record: Dictionary = controller._records[int(role_indices.announcer)]
		if String(right_record.action) == "walk":
			var direction := String(right_record.direction)
			if not announcer_sequences.has(direction):
				_check(false, "announcer route uses a validated directional source sequence")
				continue
			var current_position: Vector3 = anchors.announcer.position
			var route_data: Dictionary = announcer_sequences[direction]
			var index: int = int(floor(float(right_record.action_elapsed) * float(route_data.fps))) % 4
			var expected_frames: Array = route_data.textures
			if expected_frames.size() != 4 or index < 0 or index >= expected_frames.size():
				_check(false, "announcer route frame index remains inside its validated source cels")
				continue
			_check(actors.announcer.texture == expected_frames[index], "announcer displays the complete authored %s source cel" % direction)
			var seen: Dictionary = route_data.seen
			seen[index] = true
			route_data.seen = seen
			announcer_sequences[direction] = route_data
			if direction == "right" and current_position.distance_to(announcer_start) > 0.01:
				moved_right = true
			if direction == "left" and current_position.distance_to(announcer_start) > 0.01:
				moved_left = true
		if String(controller._records[int(role_indices.ticket)].action) not in ["stand", "idle"]:
			ticket_persona = true
		if String(controller._records[int(role_indices.imp)].action) not in ["stand", "idle"]:
			imp_persona = true

	_check(anchors.ticket.position.is_equal_approx(ticket_start), "ticket remains in place without validated walk frames")
	_check(anchors.imp.position.is_equal_approx(imp_start), "imp remains in place without validated walk frames")
	_check(ticket_persona and imp_persona, "ticket and imp naturally play persona actions during the two route cycles")
	_check(moved_right and moved_left, "announcer naturally moves in both directions while its route plays authored frames")
	_check(anchors.announcer.position.distance_to(announcer_start) < 0.001, "announcer returns to its route origin after complete cycles")
	for direction in ["right", "left"]:
		var seen: Dictionary = announcer_sequences[direction].seen
		_check(seen.size() == 4, "announcer %s route naturally displays all four complete source cels" % direction)
	_check(actors.announcer.visible and controller._records[int(role_indices.announcer)].get("motion") == null, "announcer retains the full authored Sprite with no gait rig")
	controller.release()
	scene.queue_free()
	if not _failures.is_empty():
		_finish_failed()
		return
	print("PASS: two data-time cycles route announcer through complete source cels; unsupported ticket/imp actors remain in place and animate persona")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("NPC AUTHORED SOURCE WALKING: " + message)

func _finish_failed() -> void:
	push_error("NPC authored source walking test failed with %d failed check(s)." % _failures.size())
	quit(1)

func _record_index(controller: NpcActivity, role: String) -> int:
	for index in range(controller._records.size()):
		if String(controller._records[index].role) == role:
			return index
	return -1

func _ground_height(_position: Vector2) -> float:
	return 0.0
