extends SceneTree

const Patrol := preload("res://game/world/authored_npc_patrol.gd")
var _blocked := false
var _invalid_ground := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty())
	var actor := Node3D.new()
	root.add_child(actor)
	var patrol = Patrol.new()
	assert(patrol.configure(actor, _height, _path_clear))
	var directions := {}
	var moved := 0.0
	for _index in range(1500):
		var previous := actor.position
		var previous_phase: float = patrol.phase
		var sample: Dictionary = patrol.advance(1.0 / 60.0)
		var distance := previous.distance_to(actor.position)
		assert(absf(actor.position.x) <= Patrol.HALF_WIDTH + 0.00001 and is_zero_approx(actor.position.z), "patrol stays in its authored ground pocket")
		assert(is_equal_approx(float(sample.distance), distance), "reported gait distance is actual displacement")
		assert(is_equal_approx(patrol.phase, fposmod(previous_phase + distance / Patrol.STRIDE, 1.0)), "pose phase advances from real distance only")
		if bool(sample.moving): directions[sample.direction] = true
		moved += distance
	assert(directions.has("left") and directions.has("right") and moved > 1.5, "both directions include actual movement")
	var stationary := actor.position
	var phase: float = patrol.phase
	assert(patrol.configure(actor, _height, _path_clear) and patrol.phase == phase and actor.position == stationary, "reapplying providers preserves phase and the original patrol bounds")
	for delta in [0.0, -1.0, NAN, INF]:
		assert(not patrol.advance(delta).moving and actor.position == stationary and patrol.phase == phase, "invalid or zero delta cannot create a step")
	actor.position = Vector3(10, 0, -4)
	assert(not patrol.advance(1.0).moving and patrol.phase == 0.0 and actor.position == Vector3(10, 0, -4), "teleports rebase without catch-up feet")
	for _index in range(15): patrol.advance(0.1)
	stationary = actor.position
	patrol.advance(1000.0)
	assert(actor.position.distance_to(stationary) <= Patrol.SPEED * Patrol.MAX_STEP_SECONDS + 0.00001, "long frames cannot jump across the route")
	_blocked = true
	stationary = actor.position
	phase = patrol.phase
	for _index in range(30): patrol.advance(0.1)
	assert(actor.position == stationary and patrol.phase == phase and patrol.blocked_reason == "obstacle", "blocked motion cannot slide feet or accumulate steps")
	_blocked = false
	_invalid_ground = true
	for _index in range(30): patrol.advance(0.1)
	assert(actor.position == stationary and patrol.phase == phase and patrol.blocked_reason == "ground", "unavailable ground keeps the entire actor stationary")
	_invalid_ground = false
	root.remove_child(actor)
	assert(not patrol.advance(0.1).moving, "a detached actor has no world to patrol")
	assert(not patrol.configure(actor, _height, _path_clear), "configuration rejects detached actors without invalid global transforms")
	root.add_child(actor)
	actor.queue_free()
	await process_frame
	assert(not patrol.advance(0.1).moving, "a released actor cannot keep a route alive")
	var wall := StaticBody3D.new()
	wall.position = Vector3(1.06, 0.35, 0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.04, 0.7, 0.5)
	collision.shape = box
	wall.add_child(collision)
	root.add_child(wall)
	var physical_actor := Node3D.new()
	physical_actor.position = Vector3(1,0,0)
	root.add_child(physical_actor)
	await physics_frame
	await physics_frame
	var physical_patrol = Patrol.new()
	assert(physical_patrol.configure(physical_actor, _height))
	var saw_wall := false
	for _index in range(90):
		physical_patrol.advance(1.0/30.0)
		saw_wall = saw_wall or physical_patrol.blocked_reason == "obstacle"
		assert(physical_actor.position.x < 1.04, "actual physics rays stop the actor before a static wall")
	assert(saw_wall, "real PhysicsDirectSpaceState detects the blocking wall")
	physical_actor.queue_free()
	wall.queue_free()
	await process_frame
	print("PASS: authored NPC patrol bounds, distance phase, obstacle/ground rejection, teleport, long-frame and release")
	quit(0)

func _height(_position: Vector2) -> float:
	return NAN if _invalid_ground else 0.0

func _path_clear(_from: Vector3, _to: Vector3) -> bool:
	return not _blocked
