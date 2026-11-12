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
	_check(controller._has_sequence("ticket", "walk", "right") and controller._has_sequence("ticket", "walk", "left"), "ticket uses the new complete side sources rather than its old front candidate")
	_check(controller._has_sequence("imp", "walk", "right") and controller._has_sequence("imp", "walk", "left"), "imp has independently drawn two-contact walking sources in both directions")
	_check(controller._records[_record_index(controller, "imp")].get("authored_patrol") != null, "validated imp sources enable grounded distance-driven patrol")
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
	var announcer_previous_position: Vector3 = announcer_start
	var announcer_settle_seen := {"right": {}, "left": {}}
	var ticket_persona := false
	var imp_persona := false
	var moved_right := false
	var moved_left := false
	var imp_directions := {}
	var imp_seen := {"right": {}, "left": {}}
	var imp_settle_seen := {"right": {}, "left": {}}
	var imp_previous_position: Vector3 = anchors.imp.position
	var ticket_seen := {"right": {}, "left": {}}
	var ticket_settle_seen := {"right": {}, "left": {}}
	var ticket_previous_position: Vector3 = anchors.ticket.position
	var departures := {"ticket":{"right":{},"left":{}}, "imp":{"right":{},"left":{}}}
	var previous_positions := {"ticket":ticket_start,"imp":imp_start}
	var tick_count := ceili(CYCLE_SECONDS * 2.0 / TICK_SECONDS)
	for _tick in range(tick_count):
		# Advance the authored route track and the controller explicitly. No scene
		# playback or waiting is needed; this is the same data-time progression.
		controller._player.advance(TICK_SECONDS)
		controller._process(TICK_SECONDS)
		for role in departures:
			var departing_record: Dictionary = controller._records[int(role_indices[role])]
			if String(departing_record.action) == "depart":
				_check(anchors[role].position == previous_positions[role], "%s turns in place before travelling" % role)
				var departure: Dictionary = departing_record.action_sequence
				var departure_index := Library.AnimationTiming.frame_at_time(departure, float(departing_record.action_elapsed))
				departures[role][String(departing_record.direction)][departure_index] = true
				_check(actors[role].texture == departure.frames[departure_index].texture, "%s departure displays its complete shared source pose" % role)
			previous_positions[role] = anchors[role].position
		var ticket_record: Dictionary = controller._records[int(role_indices.ticket)]
		if String(ticket_record.action) == "settle":
			_check(anchors.ticket.position == ticket_previous_position, "ticket root remains planted throughout the authored turn")
			var turn_sequence: Dictionary = ticket_record.action_sequence
			var turn_index: int = Library.AnimationTiming.frame_at_time(turn_sequence, float(ticket_record.action_elapsed))
			ticket_settle_seen[String(ticket_record.direction)][turn_index] = true
			_check(actors.ticket.texture == turn_sequence.frames[turn_index].texture, "ticket turn uses the complete source at its authored time")
		ticket_previous_position = anchors.ticket.position
		_check(anchors.ticket.position.x >= ticket_start.x - 0.00001 and anchors.ticket.position.x <= ticket_start.x + 1.20001 and is_equal_approx(anchors.ticket.position.z, ticket_start.z), "ticket patrol stays on the plaza side of its starting point")
		if String(ticket_record.action) == "walk":
			var heading := String(ticket_record.direction)
			var sequence: Dictionary = ticket_record.action_sequence
			var index: int = Library.AnimationTiming.frame_at_time(sequence, float(ticket_record.action_elapsed))
			_check(actors.ticket.texture == sequence.frames[index].texture, "ticket uses its actual distance-selected complete side pose")
			ticket_seen[heading][index] = true
		var imp_record: Dictionary = controller._records[int(role_indices.imp)]
		if String(imp_record.action) == "settle":
			_check(anchors.imp.position == imp_previous_position, "imp root remains planted throughout the authored turn")
			var turn_sequence: Dictionary = imp_record.action_sequence
			var turn_index: int = Library.AnimationTiming.frame_at_time(turn_sequence, float(imp_record.action_elapsed))
			imp_settle_seen[String(imp_record.direction)][turn_index] = true
			_check(actors.imp.texture == turn_sequence.frames[turn_index].texture, "turn uses the complete source at its authored time")
		imp_previous_position = anchors.imp.position
		_check(absf(anchors.imp.position.x - imp_start.x) <= 0.30001 and is_equal_approx(anchors.imp.position.z, imp_start.z), "imp remains inside its grounded route pocket")
		if String(imp_record.action) == "walk":
			var heading := String(imp_record.direction)
			var sequence: Dictionary = imp_record.action_sequence
			var index: int = Library.AnimationTiming.frame_at_time(sequence, float(imp_record.action_elapsed))
			_check(actors.imp.texture == sequence.frames[index].texture, "imp displays the distance-selected complete source pose")
			imp_directions[heading] = true
			imp_seen[heading][index] = true
		var right_record: Dictionary = controller._records[int(role_indices.announcer)]
		if String(right_record.action) == "settle":
			_check(anchors.announcer.position.is_equal_approx(announcer_previous_position), "announcer root stays planted throughout the authored stop turn")
			var turn_sequence: Dictionary = right_record.action_sequence
			var turn_index: int = Library.AnimationTiming.frame_at_time(turn_sequence, float(right_record.action_elapsed))
			announcer_settle_seen[String(right_record.direction)][turn_index] = true
			_check(actors.announcer.texture == controller._costume_texture("announcer", turn_sequence.frames[turn_index].texture), "announcer stop turn retains its complete source and costume")
		announcer_previous_position = anchors.announcer.position
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
		if String(controller._records[int(role_indices.ticket)].action) not in ["stand", "idle", "walk", "settle", "depart"]:
			ticket_persona = true
		if String(controller._records[int(role_indices.imp)].action) not in ["stand", "idle", "walk", "settle", "depart"]:
			imp_persona = true

	_check(ticket_seen.right.size() == 4 and ticket_seen.left.size() == 4, "ticket naturally shows all eight side poses on a complete outbound and return path")
	_check(ticket_settle_seen.right.size() == 4 and ticket_settle_seen.left.size() == 4, "ticket naturally settles through all four complete turn poses from both sides")
	_check(imp_directions.size() == 2 and imp_seen.right.size() == 4 and imp_seen.left.size() == 4, "imp patrol reaches both directions and all eight source poses")
	_check(imp_settle_seen.right.size() == 4 and imp_settle_seen.left.size() == 4, "imp naturally settles through all four full turn poses from both sides")
	_check(ticket_persona and imp_persona, "ticket and imp naturally play persona actions during the two route cycles")
	for role in departures:
		_check(departures[role].right.size() == 4 and departures[role].left.size() == 4, "%s naturally presents both complete front-to-side departures" % role)
	_check(moved_right and moved_left, "announcer naturally moves in both directions while its route plays authored frames")
	_check(announcer_settle_seen.right.size() == 4 and announcer_settle_seen.left.size() == 4, "announcer naturally shows all eight side-to-front stop poses")
	_check(anchors.announcer.position.distance_to(announcer_start) < 0.001, "announcer returns to its route origin after complete cycles")
	for direction in ["right", "left"]:
		var seen: Dictionary = announcer_sequences[direction].seen
		_check(seen.size() == 4, "announcer %s route naturally displays all four complete source cels" % direction)
	_check(actors.announcer.visible and controller._records[int(role_indices.announcer)].get("motion") == null, "announcer retains the full authored Sprite with no gait rig")
	for damaged_role in ["imp", "ticket"]:
		var damaged_library := Library.new()
		damaged_library.manifest.actors[damaged_role].walk.left.frames[3].region = [99999,0,10,10]
		var guard := NpcActivity.new()
		guard._animation_library = damaged_library
		scene.add_child(guard)
		var guarded_root := Node3D.new()
		scene.add_child(guarded_root)
		var guarded_sprite := Sprite3D.new()
		var fallback := NpcActivity.load_action_frames(damaged_role)
		guarded_sprite.texture = fallback[0]
		guarded_root.add_child(guarded_sprite)
		_check(guard.register_actor(guarded_sprite,damaged_role,fallback,guarded_root), "%s retains complete fallback registration" % damaged_role)
		guard.finish_registration()
		guard.configure_motion(camera, Callable(self,"_ground_height"), false)
		_check(guard._records[0].get("authored_patrol") == null, "%s damaged later source cel prevents the entire two-direction patrol" % damaged_role)
		for _tick in range(120): guard._process(TICK_SECONDS)
		_check(guarded_root.position == Vector3.ZERO and guarded_sprite.texture != null, "%s unusable walk sources retain a stationary complete actor" % damaged_role)
		guard.release()
	controller.release()
	scene.queue_free()
	if not _failures.is_empty():
		_finish_failed()
		return
	print("PASS: all three authored NPC routes display complete side poses and preserve independent personality actions")
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
