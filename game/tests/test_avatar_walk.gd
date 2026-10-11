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

	call_deferred("_probe_world_travel")

func _probe_world_travel() -> void:
	var world := ParkWorld.new()
	root.add_child(world)
	await physics_frame
	var initial_phase: float = world.walk_distance_phase
	Input.action_press("move_right")
	for _step in range(7): await physics_frame
	Input.action_release("move_right")
	assert(world.walk_distance_phase > initial_phase, "world increments its phase from post-slide horizontal displacement while moving")
	assert(world.facing == "right", "world uses the measured displacement for its authored facing")
	assert(world.avatar.texture != null, "world presents a cached authored walk texture")
	world.blocked = true
	var blocked_phase: float = world.walk_distance_phase
	for _step in range(3): await physics_frame
	assert(is_equal_approx(world.walk_distance_phase, blocked_phase), "modal blocking stops distance-driven gait advancement")
	world.queue_free()
	print("PASS: eight-direction avatar walk checks")
	quit(0)
