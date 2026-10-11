extends SceneTree

const NpcActivityScript := preload("res://game/world/npc_activity.gd")

class MockAnimationLibrary:
	extends RefCounted
	var sequences: Dictionary = {}

	func get_sequence(actor: String, action: String, direction: String) -> Dictionary:
		return sequences.get("%s/%s/%s" % [actor, action, direction], {})

	func has_action(actor: String, action: String, direction: String) -> bool:
		return sequences.has("%s/%s/%s" % [actor, action, direction])

	func coverage_report() -> Dictionary:
		var coverage := {}
		for key in sequences.keys():
			var parts := String(key).split("/")
			var actor := String(parts[0])
			var action := String(parts[1])
			var direction := String(parts[2])
			if not coverage.has(actor): coverage[actor] = {}
			if not coverage[actor].has(action): coverage[actor][action] = []
			coverage[actor][action].append(direction)
		return coverage


var _controller: Node
var _root: Node3D
var _actor: Sprite3D
var _imp: Sprite3D
var _imp_baseline: Texture2D
var _announcer: Sprite3D
var _announcer_root: Node3D
var _announcer_point: Dictionary
var _stand: Array[Texture2D] = []
var _greet: Array[Texture2D] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	_root = Node3D.new()
	root.add_child(_root)
	_controller = NpcActivityScript.new()
	_root.add_child(_controller)
	var library := MockAnimationLibrary.new()
	_controller._animation_library = library
	_actor = Sprite3D.new()
	_actor.texture = _texture(Color.WHITE)
	_actor.pixel_size = 0.01
	_root.add_child(_actor)
	var baseline := _actor.texture
	var baseline_size := _actor.pixel_size
	var no_legacy_frames: Array[Texture2D] = []
	assert(_controller.register_actor(_actor, "ticket", no_legacy_frames, _root, {}, 0.0), "ticket registers")
	_imp = Sprite3D.new()
	_imp_baseline = _texture(Color.WHITE)
	_imp.texture = _imp_baseline
	_root.add_child(_imp)
	var legacy_frames: Array[Texture2D] = [_texture(Color.PURPLE), _texture(Color.FUCHSIA), _texture(Color.PINK), _texture(Color.MAGENTA)]
	assert(_controller.register_actor(_imp, "imp", legacy_frames, _root, {}, 0.0), "imp registers its legacy routine only as fallback")
	_announcer_root = Node3D.new()
	_announcer_root.position = Vector3(4, 0, -10)
	_root.add_child(_announcer_root)
	_announcer = Sprite3D.new()
	_announcer.texture = _texture(Color.WHITE)
	_announcer_root.add_child(_announcer)
	_announcer_point = {"position": _announcer_root.global_position}
	assert(_controller.register_actor(_announcer, "announcer", no_legacy_frames, _announcer_root, _announcer_point, 0.55), "announcer registers")
	_stand = [_texture(Color.BLUE), _texture(Color.DARK_BLUE)]
	_greet = [_texture(Color.RED), _texture(Color.ORANGE), _texture(Color.YELLOW)]
	library.sequences["ticket/stand/front"] = _sequence(_stand, 2.0, true)
	library.sequences["ticket/greet/front"] = _sequence(_greet, 4.0, false)
	library.sequences["ticket/interact/front"] = _sequence(_greet, 4.0, false)
	library.sequences["ticket/idle_adjust_uniform/front"] = _sequence(_greet, 4.0, false)
	library.sequences["announcer/stand/front"] = _sequence(_stand, 2.0, true)
	library.sequences["announcer/stand/right"] = _sequence(_stand, 2.0, true)
	library.sequences["announcer/stand/left"] = _sequence(_stand, 2.0, true)
	library.sequences["announcer/walk/right"] = _sequence(_greet, 4.0, true)
	library.sequences["announcer/walk/left"] = _sequence(_greet, 4.0, true)
	_controller.finish_registration()
	assert(_controller.request_action(_actor, "stand", "front"), "authored stand loads")
	assert(_actor.texture == _stand[0], "stand starts on its first authored frame")
	assert(_controller.greet(_actor), "greet API starts authored action")
	assert(_actor.texture == _greet[0], "greeting begins at its first frame")
	_controller._process(0.26)
	assert(_actor.texture == _greet[1], "action advances from elapsed time at authored FPS")
	_controller._process(0.26)
	_controller._process(0.26)
	assert(_actor.texture == _stand[0], "finite greeting returns to the actor's authored stand")
	assert(_controller.request_action(_actor, "greet", "front"), "greeting can be restarted")
	_controller._process(0.1)
	assert(_controller.interact(_actor), "interact interrupts an active action when authored")
	_controller._process(0.26)
	assert(_actor.texture == _greet[1], "interrupted action still advances on its new timeline")
	var record: Dictionary = _controller._records[0]
	var elapsed_before_pause := float(record.action_elapsed)
	_controller.set_activity_paused(true)
	_controller._process(5.0)
	assert(is_equal_approx(float(_controller._records[0].action_elapsed), elapsed_before_pause), "pause freezes animation time without catch-up")
	_controller.set_activity_paused(false)
	_controller._process(0.15)
	assert(_actor.texture == _greet[1], "resume advances by only the new elapsed time")
	assert(not _controller.request_action(_actor, "walk", "back_left"), "missing direction/action is reported unavailable")
	assert(_actor.texture == baseline and String(_controller._records[0].action) == "stand", "missing sequence returns to the original safe standing visual")
	var ticket_idle: Dictionary = _controller._records[0]
	ticket_idle.idle_due = _controller._action_clock
	_controller._records[0] = ticket_idle
	_controller._process(0.01)
	assert(String(_controller._records[0].action) == "idle_adjust_uniform", "ticket's delayed personality idle selects its authored gesture")
	_controller._process(0.75)
	assert(String(_controller._records[0].action) == "stand", "personality idle returns to the authored standing loop")
	_controller.set_reduced_motion(true)
	assert(_actor.texture == baseline and is_equal_approx(_actor.pixel_size, baseline_size), "reduced motion restores the original texture and pixel size")
	_controller.set_reduced_motion(false)
	assert(_controller.statistics().playing, "motion resumes after reduced motion")
	assert(float(_controller._records[0].idle_due) >= 5.0 and float(_controller._records[1].idle_due) >= 5.0 and not is_equal_approx(float(_controller._records[0].idle_due), float(_controller._records[1].idle_due)), "actors receive independent delayed idle-event offsets")
	assert(_controller.request_action(_imp, "special"), "legacy imp routine remains available for explicit special action")
	assert(not bool(_controller._records[1].action_sequence.loop), "legacy four-frame dance fallback plays once instead of endlessly")
	assert(_controller.coverage_report().missing_requests.imp.size() > 0, "legacy fallback remains marked as incomplete authored coverage")
	_controller._process(1.21)
	assert(_imp.texture == _imp_baseline, "legacy special action safely returns to the original stand")
	var announcer_start := _announcer_root.position
	_controller._player.seek(0.0, true)
	_controller._player.advance(1.2)
	_controller._action_clock = 0.0
	_controller._process(0.0)
	assert(absf(_announcer_root.position.x - announcer_start.x - 0.6) < 0.001, "authored two-direction walk enables the bounded announcer route")
	assert(_announcer.texture == _greet[0] and _announcer.texture == (_controller._records[2].action_sequence.frames[0].texture), "announcer uses the authored right-facing walk sequence, without sprite mirroring")
	assert(is_equal_approx(float(_announcer_point.position.x), _announcer_root.global_position.x), "authored route keeps the interaction point on the moving root")
	_actor.queue_free()
	_imp.queue_free()
	_announcer.queue_free()
	await process_frame
	assert(_controller.statistics().registration_count == 0, "freed actor is removed from scheduler")
	_controller.release()
	assert(_controller.statistics().registration_count == 0, "release clears all scheduler state")
	_root.queue_free()
	await process_frame
	print("PASS: NPC animation state progression, interruption, pause, fallback, and cleanup")
	quit(0)


func _sequence(textures: Array[Texture2D], fps: float, loop: bool) -> Dictionary:
	var frames: Array[Dictionary] = []
	for texture in textures:
		frames.append({"texture": texture, "anchors": {"feet": Vector2(160, 448)}, "layers": []})
	return {"available": true, "fps": fps, "loop": loop, "frames": frames}


func _texture(color: Color) -> Texture2D:
	var image := Image.create(320, 460, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
