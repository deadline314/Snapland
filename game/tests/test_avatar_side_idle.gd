extends SceneTree
## Production stops use dedicated fixed-head breathing and blinking cels.
const ParkWorld = preload("res://game/world/park_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ParkWorld.quantize_walk_direction(Vector2(0.0008, 0.0), "left") == "right", "slow nonzero rightward movement cannot retain a leftward stride")
	_check(ParkWorld.quantize_walk_direction(Vector2(-0.0008, 0.0), "right") == "left", "slow nonzero leftward movement cannot retain a rightward stride")
	var world := ParkWorld.new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	var library = world.avatar_renderer.animation_library
	for direction in ["left", "right", "front_left", "front_right", "back_left", "back", "back_right"]:
		_check(library.has_action("traveller", "idle", direction), direction + " has dedicated full-body idle")
		if not library.has_action("traveller", "idle", direction): continue
		world.facing = direction
		world.avatar_is_walking = false
		world.avatar_action_remaining = 0.0
		var cases := [[0.0, 0], [1.95, 1], [2.25, 2], [2.31, 2], [2.33, 3], [2.5, 3], [2.9, 0], [-1.0, 0]]
		for sample in cases:
			world.time = float(sample[0])
			world.last_avatar_frame = -1
			world._refresh_avatar_texture(7)
			_check(world.last_avatar_frame == int(sample[1]), direction + " uses dedicated idle timing on fixed ground")
			var expected = world.avatar_renderer.texture(world.avatar_appearance, world.avatar_equipped, direction, int(sample[1]), "idle")
			_check(world.avatar.texture == expected, direction + " stop displays dedicated stable idle")
		world.reduced_motion = true
		world.time = 2.25
		world.last_avatar_frame = -1
		world._refresh_avatar_texture(7)
		_check(world.last_avatar_frame == 0, "reduced motion uses open-eye neutral side stance")
		world.reduced_motion = false
	var left_entry: Dictionary = library.manifest.actors.traveller.idle.left
	left_entry["loop"] = false
	_check(library.frame_for_time("traveller", "idle", "left", 20.0) == 3, "non-looping explicit durations hold final pose")
	left_entry["loop"] = true
	var original_durations: Array = left_entry.frame_durations.duplicate()
	for invalid in [[1.9, 0.3], [1.9, 0.3, 0.0, 0.5], [1.9, 0.3, "blink", 0.5], [1.9, 0.3, NAN, 0.5]]:
		left_entry["frame_durations"] = invalid
		_check(not library.has_action("traveller", "idle", "left"), "malformed explicit timing cannot select an authored action")
	left_entry["frame_durations"] = original_durations
	_check(world.avatar_motion_rig == null, "dedicated side idle keeps procedural gait disabled")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: dedicated stable idle timing, source diagnostics, and reduced-motion stance")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("SIDE IDLE: " + message)
