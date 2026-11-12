extends SceneTree

const Activity := preload("res://game/world/npc_activity.gd")
const Library := preload("res://game/world/character_animation_library.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for role in ["ticket", "imp"]:
		var fixture := _fixture(role)
		var controller: Node = fixture.controller
		var actor: Node3D = fixture.actor
		var sprite: Sprite3D = fixture.sprite
		for direction in ["right", "left"]:
			var original: Dictionary = controller._animation_library.get_sequence(role, "settle", direction)
			var before: int = controller._animation_library.cached_texture_count()
			var departure: Dictionary = controller._animation_library.get_sequence(role, "depart", direction)
			var neutral: Texture2D = controller._animation_library.texture(role, "idle", "front", 0)
			_check(original.frames[3].texture.get_image().get_data() == neutral.get_image().get_data(), "turn endpoint and departure beginning retain the exact existing neutral pixels")
			for frame in range(4):
				_check(departure.frames[frame].texture == original.frames[3-frame].texture and departure.frames[frame].anchors == original.frames[3-frame].anchors, "reverse playback shares the exact validated texture and its anchors")
			_check(controller._animation_library.cached_texture_count() == before, "departure does not allocate duplicate GPU canvases")
		_check(_until(controller, "depart"), "%s naturally starts an in-place departure" % role)
		var elapsed: float = controller._records[0].action_elapsed
		var picture := sprite.texture
		controller.set_activity_paused(true)
		controller._process(2.0)
		_check(controller._records[0].action_elapsed == elapsed and actor.position == Vector3.ZERO and sprite.texture == picture, "pause holds departure pose, root and time")
		controller.set_activity_paused(false)
		controller._process(0.12)
		_check(sprite.texture != picture and actor.position == Vector3.ZERO, "resumed pivot advances the source pose before moving")
		controller.set_dialogue_hold(true)
		controller.set_activity_paused(true)
		controller._process(1.0)
		_check(String(controller._records[0].action) in ["stand", "idle"] and actor.position == Vector3.ZERO, "a departure finishing in dialogue returns to front idle instead of walking in place")
		controller.set_dialogue_hold(false)
		controller.set_activity_paused(false)
		_check(_until(controller, "depart"), "closing dialogue starts a fresh orientation change")
		_check(controller.greet(sprite), "greeting interrupts the route departure")
		controller._process(0.2)
		_check(String(controller._records[0].action) == "greet" and actor.position == Vector3.ZERO, "no stale walking completion runs during a greeting")
		_check(_until(controller, "depart"), "finished greeting returns through a fresh departure")
		var phase: float = controller._records[0].action_elapsed
		controller.configure_motion(fixture.camera, _ground, false)
		_check(controller._records[0].action_elapsed == phase, "reapplying providers preserves an active pivot")
		_check(_until(controller, "walk"), "complete departure hands off to walking")
		_check(actor.position == Vector3.ZERO and controller._records[0].authored_patrol.phase == 0.0, "first walking contact begins at the planted root with a fresh stride")
		controller._process(1.0/60.0)
		_check(actor.position.x > 0.0 and controller._records[0].authored_patrol.phase > 0.0, "body and foot phase advance only when actual travel begins")
		controller.set_reduced_motion(true)
		controller._process(2.0)
		_check(actor.position == Vector3.ZERO and sprite.texture != null, "reduced motion restores a complete stationary actor")
		controller.set_reduced_motion(false)
		_check(_until(controller, "depart"), "motion resumes with a complete new pivot")
		controller.release()
		_check(controller.statistics().registration_count == 0, "release clears a pending departure")
		fixture.scene.free()
		for damage in ["missing", "last_frame", "loop", "duration", "return_direction"]:
			fixture = _fixture(role, damage)
			controller = fixture.controller
			_check(_until(controller, "walk") and fixture.actor.position.x > 0.0 and fixture.sprite.texture != null, "%s %s departure safely retains the original walking route" % [role, damage])
			controller.release()
			fixture.scene.free()
	if not failures.is_empty():
		push_error("NPC departure lifecycle failed: " + "; ".join(failures))
		quit(1)
		return
	print("PASS: planted NPC departure, pause, dialogue, interruption, stride restart, reduced motion and damaged-source fallback")
	quit(0)

func _fixture(role: String, damage := "") -> Dictionary:
	var scene := Node3D.new()
	root.add_child(scene)
	var library := Library.new()
	if not damage.is_empty():
		var sequence: Dictionary = library.manifest.actors[role].depart.right
		match damage:
			"missing": library.manifest.actors[role].depart.erase("right")
			"last_frame": sequence.frames[3].region = [99999,0,10,10]
			"loop": sequence.loop = true
			"duration": sequence.fps = 0.01
			"return_direction": sequence.return_direction = "front"
	var controller := Activity.new()
	controller._animation_library = library
	scene.add_child(controller)
	controller.set_process(false)
	var actor := Node3D.new()
	scene.add_child(actor)
	var sprite := Sprite3D.new()
	var fallback := Activity.load_action_frames(role)
	sprite.texture = fallback[0]
	actor.add_child(sprite)
	controller.register_actor(sprite, role, fallback, actor)
	controller.finish_registration()
	var camera := Camera3D.new()
	scene.add_child(camera)
	controller.configure_motion(camera, _ground, false)
	return {"scene":scene,"controller":controller,"actor":actor,"sprite":sprite,"camera":camera}

func _until(controller: Node, action: String) -> bool:
	for _step in range(1200):
		if String(controller._records[0].action) == action: return true
		controller._process(1.0/60.0)
	return false

func _ground(_point: Vector2) -> float:
	return 0.0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
