extends SceneTree

const ParkWorld = preload("res://game/world/park_world.gd")
const DIRECTIONS := ["back", "back_right", "right", "front_right", "front", "front_left", "left", "back_left"]
const INPUTS := [
	["move_up"], ["move_up", "move_right"], ["move_right"], ["move_down", "move_right"],
	["move_down"], ["move_down", "move_left"], ["move_left"], ["move_up", "move_left"],
]
const MOVE_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]
var _failures: Array[String] = []

func _initialize() -> void:
	_check(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(), "authored walk loop checks require an isolated SNAPLAND_SAVE_PATH")
	call_deferred("_run")

func _run() -> void:
	var world := ParkWorld.new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	if world.avatar_renderer == null:
		push_error("walk-loop fixture could not initialize its source renderer")
		world.queue_free()
		quit(1)
		return
	_check(world.avatar_renderer.has_walk_atlas(), "the real world renderer loads the authored walking atlas")
	_check(not world.avatar_motion_available and world.avatar_motion_rig == null, "production does not allocate the unused procedural hero gait rig")
	_check(world.avatar.visible and world.avatar_motion_rig == null, "on-foot idle presents the authored source Sprite without a procedural hero gait rig")
	var avatar_material := world.avatar.material_override as ShaderMaterial
	_check(avatar_material != null and float(avatar_material.get_shader_parameter("motion")) == 0.0, "authored full-body cels receive no shader-driven breathing, hair, or hem displacement")
	_check(int(world.component_motion.statistics().get("by_profile", {}).get("character_hero", 0)) == 0, "the authored hero Sprite has no registered procedural idle phase")
	world.player.position = Vector3(0.0, ParkWorld._ground_surface_y(Vector3.ZERO), 0.0)
	world.player.velocity = Vector3.ZERO
	for _tick in range(2): await physics_frame

	var changed_direction_count := 0
	for index in range(DIRECTIONS.size()):
		_release_movement()
		world.player.position = Vector3(0.0, ParkWorld._ground_surface_y(Vector3(0.0, 0.0, -15.0)), -15.0)
		world.player.velocity = Vector3.ZERO
		world.facing = "front"
		await physics_frame
		var start_position: Vector3 = world.player.global_position
		var start_phase := world.walk_distance_phase
		var seen_frames := {}
		for action in INPUTS[index]: Input.action_press(action)
		for _tick in range(42):
			await physics_frame
			_check(world.avatar.visible and world.avatar_motion_rig == null, "%s movement keeps the authored source Sprite visible without allocating the hero rig" % DIRECTIONS[index])
			if world.avatar_is_walking and world.last_avatar_action == "walk":
				_check(world.last_avatar_direction == DIRECTIONS[index], "actual %s travel selects its authored eight-direction atlas row (facing=%s)" % [DIRECTIONS[index], world.last_avatar_direction])
				seen_frames[world.last_avatar_frame] = true
		for action in INPUTS[index]: Input.action_release(action)
		var displacement := world.player.global_position - start_position
		_check(Vector2(displacement.x, displacement.z).length() > 0.16, "%s input moves the real world player" % DIRECTIONS[index])
		_check(world.walk_distance_phase != start_phase, "%s source animation phase advances from real traveled distance" % DIRECTIONS[index])
		_check(seen_frames.size() > 1, "%s walking changes among actual authored source cels" % DIRECTIONS[index])
		changed_direction_count += 1
		world.player.velocity = Vector3.ZERO
		await physics_frame
		_check(not world.avatar_is_walking and world.last_avatar_action == "idle", "%s stop resolves to an idle stance" % DIRECTIONS[index])
		if world.avatar_renderer.has_authored_action("idle", DIRECTIONS[index]):
			_check(world.avatar_renderer.animation_library.has_action("traveller", "idle", DIRECTIONS[index]), "%s stop retains its dedicated authored idle/breath/blink sequence" % DIRECTIONS[index])
		else:
			_check(world.last_avatar_frame == world.avatar_renderer.walk_idle_frame(DIRECTIONS[index]), "%s stop holds its authored direction's natural stance cel" % DIRECTIONS[index])
		var held_texture: Texture2D = world.avatar.texture
		var held_phase := world.walk_distance_phase
		for _tick in range(8):
			await physics_frame
			if world.avatar_renderer.has_authored_action("idle", DIRECTIONS[index]):
				_check(world.avatar.visible and world.avatar_motion_rig == null and world.last_avatar_action == "idle", "%s authored idle animation continues on the source Sprite without procedural rig motion" % DIRECTIONS[index])
			else:
				_check(world.avatar.texture == held_texture and world.walk_distance_phase == held_phase, "%s stopped stance holds without procedural leg motion" % DIRECTIONS[index])
	_check(changed_direction_count == 8, "the live world loop exercises all eight authored walking directions")

	world.reduced_motion = true
	for action in ["move_right"]: Input.action_press(action)
	for _tick in range(24): await physics_frame
	_check(world.avatar_is_walking and world.avatar.visible and world.avatar_motion_rig == null and world.last_avatar_action == "walk", "reduced-motion travel still uses authored walk cels and never allocates procedural gait")
	Input.action_release("move_right")
	world.player.velocity = Vector3.ZERO
	await physics_frame
	_check(not world.avatar_is_walking and world.last_avatar_action == "idle" and world.avatar_motion_rig == null, "reduced-motion stop returns to a stable source stance")
	world.reduced_motion = false

	_release_movement()
	world.player.position = Vector3(0.0, ParkWorld._ground_surface_y(Vector3(0.0, 0.0, -15.0)), -15.0)
	world.player.velocity = Vector3.ZERO
	world.facing = "front"
	await physics_frame
	Input.action_press("move_up")
	for _tick in range(36): await physics_frame
	Input.action_release("move_up")
	world.player.velocity = Vector3.ZERO
	for _tick in range(8): await physics_frame
	_check(world.facing == "back", "real authored back-direction walking leaves the avatar facing away before F/P actions")
	for action in ["wave", "photograph", "interact"]:
		var action_frames: int = world.avatar_renderer.authored_frame_count(action, "front")
		var action_fps: float = world.avatar_renderer.authored_action_fps(action, "front")
		_check(action_frames == 8 and action_fps > 0.0, "%s fixture resolves the full authored front sequence" % action)
		if action == "wave":
			var wave_key := InputEventKey.new()
			wave_key.keycode = KEY_F
			wave_key.pressed = true
			world._unhandled_key_input(wave_key)
		elif action == "photograph":
			var photo_key := InputEventKey.new()
			photo_key.keycode = KEY_P
			photo_key.pressed = true
			world._unhandled_key_input(photo_key)
		else:
			world.play_action(action)
		_check(world.facing == "front", "%s selects the authored front sequence from an unsupported back heading and keeps the front facing" % action)
		_check(world.last_avatar_direction == "front" and not world._warned_missing_avatar_actions.has(action), "%s displays its real front source without a missing-action warning" % action)
		var expected_duration: float = float(action_frames) / action_fps
		_check(is_equal_approx(world.avatar_action_remaining, expected_duration), "%s retains its complete authored duration, bounded by runtime policy" % action)
		var observed_frames := {}
		for tick in range(ceili(expected_duration * float(Engine.physics_ticks_per_second)) + 6):
			await physics_frame
			_check(world.avatar.visible and world.avatar_motion_rig == null, "%s continues on the original Sprite without procedural gait" % action)
			if world.last_avatar_action == action:
				_check(world.last_avatar_direction == "front", "%s observed source frame is registered to the selected front row" % action)
				observed_frames[world.last_avatar_frame] = true
			if world.avatar_action.is_empty(): break
			if action == "wave" and tick == 30:
				world.blocked = true
				var held_elapsed := world.avatar_action_elapsed
				var held_frame := world.last_avatar_frame
				for _pause_tick in range(8): await physics_frame
				_check(is_equal_approx(world.avatar_action_elapsed, held_elapsed) and world.last_avatar_frame == held_frame, "modal blocking pauses the selected authored gesture at its current cel")
				world.blocked = false
		_check(observed_frames.has(action_frames - 1), "%s reaches its authored final cel before the action clears" % action)
		_check(world.avatar_action.is_empty(), "%s clears only after its authored sequence duration" % action)
		_check(world.facing == "front", "%s completion keeps the newly selected front heading" % action)
	_check(not world.avatar_renderer.has_authored_action("celebrate", "back"), "celebrate has no falsely claimed authored back-direction coverage")
	world.facing = "back"
	world.play_action("celebrate")
	var fallback_frames := {}
	for _tick in range(ceili(world.avatar_action_remaining * float(Engine.physics_ticks_per_second)) + 4):
		await physics_frame
		if world.last_avatar_action == "celebrate": fallback_frames[world.last_avatar_frame] = true
		if world.avatar_action.is_empty(): break
	_check(world.facing == "back" and fallback_frames.size() > 1 and fallback_frames.size() <= 3, "whole-action absence uses a safely advancing maximum-three-frame fallback without changing facing")
	Input.action_press("move_left")
	for _tick in range(24): await physics_frame
	_check(world.avatar_is_walking and world.last_avatar_action == "walk" and world.avatar_motion_rig == null, "real travel cleanly returns from gesture to the authored walk loop")
	Input.action_release("move_left")
	world.player.velocity = Vector3.ZERO
	await physics_frame

	world.blocked = true
	var blocked_position: Vector3 = world.player.global_position
	var blocked_phase := world.walk_distance_phase
	Input.action_press("move_up")
	for _tick in range(8): await physics_frame
	_check(world.player.global_position.is_equal_approx(blocked_position) and world.walk_distance_phase == blocked_phase, "blocked input moves no distance and cannot advance the source loop")
	_check(world.avatar.visible and world.avatar_motion_rig == null and not world.avatar_is_walking, "blocked state retains the source idle Sprite without a procedural rig")
	Input.action_release("move_up")
	world.blocked = false

	var ride_point: Dictionary = world._point_by_id("ride-tide")
	world.player.global_position = ride_point.position
	_check(world.start_ride(), "the existing ride route remains available from its authored interaction point")
	_check(world.avatar.visible and world.avatar_motion_rig == null and world.last_avatar_action == "sit", "ride continues to use its existing seated Sprite pose")
	world.end_ride()
	_check(world.avatar.visible and world.avatar_motion_rig == null and world.last_avatar_action == "idle", "leaving the ride restores the authored front idle")

	_check_fallback_cache_direction()
	_check_repaired_source_hand(world.avatar_renderer)
	_release_movement()
	world.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error("authored walk-loop regression failed %d check(s): %s" % [_failures.size(), "; ".join(_failures)])
		quit(1)
		return
	print("PASS: real world avatar presents authored eight-direction walk cels, natural stance holds, and allocates no unused hero rig")
	quit(0)

func _release_movement() -> void:
	for action in MOVE_ACTIONS: Input.action_release(action)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	_failures.append(label)
	push_error("AUTHORED WALK LOOP: " + label)

func _check_fallback_cache_direction() -> void:
	# A fresh renderer is the oracle: cache warming must never choose a different
	# hat view. Missing authored celebration remains an explicit fallback.
	var renderer = preload("res://game/world/avatar_renderer.gd").new()
	var equipment := {"outfit": "outfit-tide", "hat": "hat-straw"}
	var first: Texture2D = renderer.texture({}, equipment, "front", 0, "celebrate")
	var saw_direction_difference := false
	for direction in DIRECTIONS:
		var reference = preload("res://game/world/avatar_renderer.gd").new()
		for frame in range(3):
			var warmed: Texture2D = renderer.texture({}, equipment, direction, frame, "celebrate")
			var cold: Texture2D = reference.texture({}, equipment, direction, frame, "celebrate")
			_check(warmed != null and cold != null, "celebration fallback produces a complete texture")
			if warmed == null or cold == null: continue
			_check(warmed.get_image().get_data() == cold.get_image().get_data(), "%s/%d fallback is independent of previously rendered directions" % [direction, frame])
			_check(renderer.texture({}, equipment, direction, frame, "celebrate") == warmed, "same fallback request reuses its own cached texture")
			if frame == 0 and first.get_image().get_data() != cold.get_image().get_data(): saw_direction_difference = true
	_check(saw_direction_difference, "cache oracle includes genuinely different direction-specific hat pixels")

func _check_repaired_source_hand(renderer: RefCounted) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/walk_stability/repairs/manifest.json"))
	var repair: Dictionary = manifest.repairs[0]
	var reference_path := ProjectSettings.globalize_path("res://" + str(repair.runtime_reference))
	_check(FileAccess.get_sha256(reference_path) == repair.runtime_reference_png_sha256, "source repair's independent runtime reference is unchanged")
	var before := Image.load_from_file(reference_path)
	before.convert(Image.FORMAT_RGBA8)
	var source: Image = renderer._walk_pose_image("front_right", 3)
	for name in repair.protected_regions:
		var box: Array = repair.protected_regions[name]
		var region := Rect2i(int(box[0]), int(box[1]), int(box[2]), int(box[3]))
		_check(source.get_region(region).get_data() == before.get_region(region).get_data(), "source repair retains original " + name + " RGBA")
	var owned := Rect2i(68, 218, 37, 47)
	var outside_changed := 0
	for y in 360:
		for x in 280:
			if owned.has_point(Vector2i(x, y)): continue
			var old := before.get_pixel(x, y)
			var actual := source.get_pixel(x, y)
			if old.a != actual.a or (old.a >= 0.5 and old != actual): outside_changed += 1
	_check(outside_changed == 0, "source repair changes no visible original pixel outside its approved rectangle")
	_check(renderer.has_head_material_owner(source), "corrected whole cel retains reviewed hair ownership")
	for style in ["windswept", "bob", "curly"]:
		var appearance: Dictionary = renderer.DEFAULT_APPEARANCE.duplicate()
		appearance.hair = style
		var texture: Texture2D = renderer.texture(appearance, {"outfit": "outfit-tide", "hat": "hat-none"}, "front_right", 3, "walk")
		var ghost := texture.get_image().get_pixel(82, 248)
		_check(ghost.a < 0.5 or ghost.r <= ghost.b, "actual " + style + " texture has no warm extra hand behind the backpack")
