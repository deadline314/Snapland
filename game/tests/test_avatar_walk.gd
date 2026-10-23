extends SceneTree

const ParkWorld = preload("res://game/world/park_world.gd")

func _initialize() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(), "avatar walk checks require an isolated SNAPLAND_SAVE_PATH")
	var expected := ["back", "back_right", "right", "front_right", "front", "front_left", "left", "back_left"]
	var vectors := [Vector2(0,-1), Vector2(1,-1), Vector2(1,0), Vector2(1,1), Vector2(0,1), Vector2(-1,1), Vector2(-1,0), Vector2(-1,-1)]
	for index in range(expected.size()):
		assert(ParkWorld.quantize_walk_direction(vectors[index]) == expected[index], "world heading maps each octant to its authored 45-degree view: %s" % expected[index])
	var upper_boundary := Vector2(sin(deg_to_rad(160.0)), -cos(deg_to_rad(160.0)))
	assert(ParkWorld.quantize_walk_direction(upper_boundary, "front") == "front", "heading hysteresis keeps the current front sector near its boundary")
	var beyond_boundary := Vector2(sin(deg_to_rad(150.0)), -cos(deg_to_rad(150.0)))
	assert(ParkWorld.quantize_walk_direction(beyond_boundary, "front") == "front_right", "heading changes after crossing the hysteresis margin")
	assert(ParkWorld.quantize_walk_direction(Vector2.ZERO, "back_left") == "back_left", "zero travel preserves the last heading")

	var partitioned := 0.0
	for distance in [0.12, 0.31, 0.07, 0.64, 0.22, 0.45]:
		partitioned = ParkWorld.advance_walk_phase(partitioned, distance)
	var combined := ParkWorld.advance_walk_phase(0.0, 1.81)
	assert(is_equal_approx(partitioned, combined), "equal travelled distance gives equal gait phase across different physics partitions")
	assert(is_equal_approx(ParkWorld.advance_walk_phase(0.83, 0.0), 0.83), "a blocked or stationary tick leaves gait phase unchanged")
	assert(is_equal_approx(ParkWorld.advance_walk_phase(0.4, ParkWorld.WALK_STRIDE_DISTANCE), 0.4), "one full stride wraps without resetting the carried phase")
	assert(ParkWorld.walk_frame_for_phase(0.0) == 0 and ParkWorld.walk_frame_for_phase(ParkWorld.WALK_STRIDE_DISTANCE * 0.999) == 7, "distance phase selects the full eight-frame loop")
	var phase8 := ParkWorld.WALK_STRIDE_DISTANCE / 16.0
	var reached8 := {}
	reached8[ParkWorld.walk_frame_for_phase(phase8,8)] = true
	for _step in range(8):
		phase8 = ParkWorld.advance_walk_phase(phase8,ParkWorld.WALK_STRIDE_DISTANCE / 8.0)
		reached8[ParkWorld.walk_frame_for_phase(phase8,8)] = true
	assert(reached8.size() == 8, "eight consecutive equal distance steps reach all eight authored walk frames")
	var phase16 := ParkWorld.WALK_STRIDE_DISTANCE / 32.0
	var reached16 := {}
	reached16[ParkWorld.walk_frame_for_phase(phase16,16)] = true
	for _step in range(16):
		phase16 = ParkWorld.advance_walk_phase(phase16,ParkWorld.WALK_STRIDE_DISTANCE / 16.0)
		reached16[ParkWorld.walk_frame_for_phase(phase16,16)] = true
	assert(reached16.size() == 16, "sixteen consecutive equal distance steps reach all sixteen authored walk frames")
	assert(ParkWorld.walk_frame_for_phase(ParkWorld.WALK_STRIDE_DISTANCE * 0.999,16) == 15, "sixteen-frame loop selects its last pose just before the stride boundary")
	for invalid_count in [0,7,9,12,17]:
		assert(ParkWorld.walk_frame_for_phase(0.0,invalid_count) == 0 and ParkWorld.walk_frame_for_phase(ParkWorld.WALK_STRIDE_DISTANCE * 0.999,invalid_count) == 7, "invalid frame count %d safely defaults to eight frames" % invalid_count)
	assert(ParkWorld.walk_frame_for_phase(-ParkWorld.WALK_STRIDE_DISTANCE / 16.0,16) == 15, "negative phase wraps into the final sixteen-frame pose")
	assert(ParkWorld.walk_frame_for_phase(-ParkWorld.WALK_STRIDE_DISTANCE,16) == 0, "negative whole-stride boundary wraps to frame zero")
	assert(ParkWorld.walk_frame_for_phase(ParkWorld.WALK_STRIDE_DISTANCE,16) == 0, "positive whole-stride boundary wraps to frame zero")

	# Calibrated strides: one measured stride of travel completes exactly one authored cycle,
	# so the planted foot keeps pace with the body (no gliding) in every direction.
	var strides := ParkWorld.load_walk_strides(ParkWorld.WALK_STRIDE_CALIBRATION_PATH)
	assert(strides.size() == 8, "every authored walk direction has a measured stride")
	for direction: String in expected:
		var stride := float(strides.get(direction, 0.0))
		assert(stride >= ParkWorld.WALK_STRIDE_LIMITS.x and stride <= ParkWorld.WALK_STRIDE_LIMITS.y, "%s stride %.3f is a plausible measured value" % [direction, stride])
		assert(is_equal_approx(ParkWorld.advance_walk_phase(0.4, stride, stride), 0.4), "%s: one measured stride of travel wraps one full cycle" % direction)
		var half := ParkWorld.advance_walk_phase(0.0, stride * 0.5, stride)
		assert(is_equal_approx(half, ParkWorld.WALK_STRIDE_DISTANCE * 0.5), "%s: half a stride reaches the opposite step" % direction)
		assert(ParkWorld.walk_frame_for_phase(ParkWorld.advance_walk_phase(0.0, stride * 0.125 + 0.0001, stride)) == 1, "%s: an eighth of the stride advances one of eight frames" % direction)
	assert(stride_ratio_ok(strides), "measured strides agree across directions within 25 percent")
	assert(ParkWorld.AVATAR_RUN_SPEED / float(strides["right"]) * 2.0 <= 3.3, "default pace keeps the authored walk at or under about three steps per second")
	assert(is_equal_approx(ParkWorld.advance_walk_phase(0.4, 1.0, 0.0), ParkWorld.advance_walk_phase(0.4, 1.0)), "an invalid stride falls back to the phase span instead of dividing by zero")
	assert(ParkWorld.load_walk_strides("res://missing-walk-strides.json").is_empty(), "a missing calibration file reports empty so the world uses its fallback stride")
	var partition_a := 0.0
	var partition_b := 0.0
	for distance in [0.12, 0.31, 0.07, 0.64]:
		partition_a = ParkWorld.advance_walk_phase(partition_a, distance, float(strides["front_left"]))
	partition_b = ParkWorld.advance_walk_phase(partition_b, 1.14, float(strides["front_left"]))
	assert(is_equal_approx(partition_a, partition_b), "calibrated phase is independent of physics partitioning")

	call_deferred("_probe_world_travel")

func stride_ratio_ok(strides: Dictionary) -> bool:
	var values: Array = strides.values()
	return float(values.max()) / float(values.min()) <= 1.25

func _probe_world_travel() -> void:
	var world := ParkWorld.new()
	root.add_child(world)
	await physics_frame
	var initial_phase: float = world.walk_distance_phase
	Input.action_press("move_right")
	for _step in range(3): await physics_frame
	var right_phase: float = world.walk_distance_phase
	var right_start: Vector3 = world.player.global_position
	for _step in range(4): await physics_frame
	Input.action_release("move_right")
	assert(world.walk_distance_phase > initial_phase, "world increments its phase from post-slide horizontal displacement while moving")
	assert(world.facing == "right", "world uses the measured displacement for its authored facing")
	var right_travel := Vector2(world.player.global_position.x - right_start.x, world.player.global_position.z - right_start.z).length()
	var expected_right := ParkWorld.advance_walk_phase(right_phase, right_travel, world.walk_stride_for("right"))
	assert(absf(wrapf(world.walk_distance_phase - expected_right, -1.4, 1.4)) < 0.002, "world advances the cycle by real travel over the measured right stride")
	assert(not is_equal_approx(world.walk_stride_for("right"), ParkWorld.WALK_STRIDE_DISTANCE), "world uses the calibrated stride, not the phase span")
	assert(world.avatar.texture != null, "world presents a cached authored walk texture")
	# Slow starts (a quarter time scale gives a tiny first acceleration step) must still move.
	Engine.time_scale = 0.25
	world.player.velocity = Vector3.ZERO
	for _step in range(4): await physics_frame
	var slow_start: Vector3 = world.player.global_position
	Input.action_press("move_left")
	for _step in range(24): await physics_frame
	Input.action_release("move_left")
	Engine.time_scale = 1.0
	assert(slow_start.distance_to(world.player.global_position) > 0.01, "a quarter time scale still accelerates the avatar instead of reading it as standing still")
	world.blocked = true
	var blocked_phase: float = world.walk_distance_phase
	for _step in range(3): await physics_frame
	assert(is_equal_approx(world.walk_distance_phase, blocked_phase), "modal blocking stops distance-driven gait advancement")
	world.queue_free()
	print("PASS: eight-direction avatar walk checks")
	quit(0)
