extends SceneTree

const ParkWorld = preload("res://game/world/park_world.gd")
const HarborWorld = preload("res://game/world/harbor_world.gd")
const COMMAND := "launch with --fixed-fps 120 or --fixed-fps 144"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await physics_frame
	var start_tick := Engine.get_physics_frames()
	var start_frame := Engine.get_process_frames()
	for _tick in range(60): await physics_frame
	var draw_ratio := float(Engine.get_process_frames() - start_frame) / (Engine.get_physics_frames() - start_tick)
	var rate := roundi(draw_ratio * Engine.physics_ticks_per_second)
	if not rate in [120, 144]:
		push_error("Welcome follow cadence regression: " + COMMAND)
		quit(1)
		return
	var world := ParkWorld.new()
	world.allow_follow_interpolation = true
	var initial_root_mode := root.physics_interpolation_mode
	root.add_child(world)
	for _tick in range(38): await physics_frame
	_check(physics_interpolation and root.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF
		and world.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON
		and world.player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON,
		"actual high render cadence opts in only the Welcome player and camera branches")
	var shadow := _avatar_shadow(world)
	_check(shadow != null and shadow.is_physics_interpolated() and world.avatar.is_physics_interpolated(),
		"the avatar silhouette and rendered sprite share the moving parent interpolation")
	_key(KEY_W, true)
	for _tick in range(36): await physics_frame
	var samples := await _walk_sample(world, shadow, rate)
	_check(samples.repeated <= 3 and samples.p95 < 0.31 and samples.hero_peak < 0.055
		and samples.shadow_peak < 0.06 and absf(samples.metres - 1.5) < 0.035,
		"engine presentation spreads the walk across frames and keeps actual hero and caster close to their current alignment")
	print("Welcome follow cadence ", JSON.stringify(samples))
	_key(KEY_W, false)
	for _tick in range(14): await physics_frame

	# Keep the real physics entry point responsible for discontinuities and settling.
	var landing := Vector3(0, 0.0, 11.5)
	var capsule := world.player.get_child(0) as CollisionShape3D
	landing.y = world.ground_surface_y(landing) - capsule.position.y + (capsule.shape as CapsuleShape3D).height * 0.5
	world.player.position = landing
	await physics_frame
	await physics_frame
	var teleport_gaps := Vector3(
		world.camera.position.distance_to(world.player.position + ParkWorld.CAMERA_OFFSET),
		world.camera.get_global_transform_interpolated().origin.distance_to(world.camera.global_position),
		world.player.get_global_transform_interpolated().origin.distance_to(world.player.global_position)
	)
	_check(teleport_gaps.x < 0.045 and teleport_gaps.y < 0.045 and teleport_gaps.z < 0.045,
		"external relocation clears both visual histories at the next authoritative follow tick (%s)" % teleport_gaps)
	world.player.position = Vector3(0, -1.4, 24.0)
	await physics_frame
	await physics_frame
	_check(world.player.position.z < 10.2 and world.camera.get_global_transform_interpolated().origin.distance_to(world.camera.global_position) < 0.06,
		"water recovery presents the safe position without a long camera streak")

	world.apply_settings({"reduced_motion":true})
	_check(not physics_interpolation and root.physics_interpolation_mode == initial_root_mode
		and world.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT,
		"reduced motion immediately restores the scoped original node modes")
	world.apply_settings({"reduced_motion":false})
	for _tick in range(35): await physics_frame
	_check(physics_interpolation, "returning to standard motion rechecks actual cadence")
	var previous_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = rate
	for _tick in range(66): await physics_frame
	_check(not physics_interpolation, "one render frame per simulation tick keeps direct publication")
	Engine.physics_ticks_per_second = previous_ticks
	for _tick in range(67): await physics_frame
	_check(physics_interpolation, "the scoped mode can return after cadence climbs")

	var docking: Vector3 = world._point_by_id("ride-tide").position
	world.player.position = docking + Vector3(-1.5, 0.3, 0.3)
	for _tick in range(4): await physics_frame
	_check(world.start_ride() and world.is_riding() and not physics_interpolation,
		"the authored ride controls its seated player at its existing cadence")
	world.end_ride()
	for _tick in range(37): await physics_frame
	_check(physics_interpolation, "on-foot camera reapplies safely after leaving the seat")
	world.free()
	await process_frame
	_check(not physics_interpolation and root.physics_interpolation_mode == initial_root_mode,
		"leaving Welcome restores the previous tree modes before regional replacement")
	var harbor := HarborWorld.new()
	root.add_child(harbor)
	for _tick in range(36): await physics_frame
	_check(not physics_interpolation and not harbor.allow_follow_interpolation,
		"another island retains its original presentation and timing")
	harbor.free()
	await process_frame
	if _failures.is_empty():
		print("PASS: welcome follow interpolation cadence")
	else:
		for failure in _failures: push_error(failure)
	quit(int(not _failures.is_empty()))


func _walk_sample(world: ParkWorld, shadow: MeshInstance3D, rate: int) -> Dictionary:
	var camera := world.camera
	var anchor := Vector3(-4.0, 0.18, 12.0)
	var start := world.player.position
	var step_distances := PackedFloat64Array()
	var repeated := 0
	var previous := camera.get_global_transform_interpolated()
	var hero_peak := 0.0
	var shadow_peak := 0.0
	for _frame in range(rate):
		await process_frame
		var next := camera.get_global_transform_interpolated()
		if next.is_equal_approx(previous): repeated += 1
		step_distances.append(_projection(anchor, next).distance_to(_projection(anchor, previous)))
		var visual_player := world.player.get_global_transform_interpolated().origin
		var logical_player := world.player.global_position
		var visual_avatar := world.avatar.get_global_transform_interpolated().origin
		hero_peak = maxf(hero_peak, (visual_avatar - visual_player).distance_to(world.avatar.global_position - logical_player))
		if is_instance_valid(shadow):
			var visual_shadow := shadow.get_global_transform_interpolated().origin
			shadow_peak = maxf(shadow_peak, (visual_shadow - visual_player).distance_to(shadow.global_position - logical_player))
		previous = next
	step_distances.sort()
	return {"repeated":repeated, "p95":step_distances[int(0.95 * (rate - 1))], "hero_peak":hero_peak,
		"shadow_peak":shadow_peak, "metres":start.distance_to(world.player.position)}


func _avatar_shadow(world: ParkWorld) -> MeshInstance3D:
	for record: Dictionary in world.actor_shadow_proxies:
		if record.get("actor") == world.player:
			return record.get("silhouette") as MeshInstance3D
	return null


func _projection(point: Vector3, pose: Transform3D) -> Vector2:
	var local := pose.affine_inverse() * point
	return Vector2(local.x, -local.y) * (720.0 / 21.0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
