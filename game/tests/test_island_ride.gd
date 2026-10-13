extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running island ride checks.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var world_script := load("res://game/world/park_world.gd") as GDScript
	if world_script == null or not world_script.can_instantiate():
		push_error("ParkWorld failed to compile for island ride checks.")
		quit(1)
		return
	var world: Node = world_script.new()
	root.add_child(world)
	await process_frame
	var deck := world.island_attractions.find_child("TideBoardwalkDeck",true,false) as MeshInstance3D
	var approach := world.island_attractions.find_child("TideBoardwalkApproach",true,false) as MeshInstance3D
	var walk_surface_body := deck.find_child("TideBoardwalkWalkSurfaceBody",true,false) as StaticBody3D if deck != null else null
	var walk_surface_shape := walk_surface_body.find_child("CollisionShape3D",true,false) as CollisionShape3D if walk_surface_body != null else null
	_check(deck != null and approach != null and walk_surface_body != null and walk_surface_shape != null and walk_surface_shape.shape is ConvexPolygonShape3D, "Tide deck and approach share a real continuous convex collision surface")
	if deck != null and walk_surface_shape != null:
		var high_edge := deck.to_global(Vector3(3.9,0.1,0.0))
		var low_edge := deck.to_global(Vector3(5.4,0.02,0.0))
		_check(absf(high_edge.x+5.7)<0.01 and absf(high_edge.y-0.26)<0.002, "exposed incline joins the visible flat boardwalk edge")
		_check(absf(low_edge.x+4.2)<0.01 and absf(low_edge.y-0.18)<0.002, "incline meets the authored avenue surface")
	var sampler_low: float = world._ground_surface_y(Vector3(-4.2,0.0,10.0))
	var sampler_high: float = world._ground_surface_y(Vector3(-5.7,0.0,10.0))
	_check(is_equal_approx(world._ground_surface_y(Vector3(-3.8,0.0,10.0)),0.18), "the immediate avenue approach matches its authored surface")
	_check(is_equal_approx(sampler_low,0.18) and is_equal_approx(sampler_high,0.26), "ground sampler matches the physical avenue and boardwalk endpoints")
	_check(is_equal_approx(world._ground_surface_y(Vector3(-6.3,0.0,10.0)),0.26), "the flat deck remains the highest visible surface through its landward edge")
	var prior_sample := sampler_low
	for x in [-4.7,-5.0,-5.3,-5.6]:
		var sample_y: float = world._ground_surface_y(Vector3(x,0.0,10.0))
		_check(sample_y > prior_sample and sample_y < sampler_high, "ground sample rises smoothly toward deck at x=%.1f" % x)
		prior_sample = sample_y
	await _exercise_tide_ramp(world)
	_check(world.has_method("start_ride"), "world exposes ride start contract")
	_check(world.has_method("end_ride"), "world exposes ride cancellation contract")
	_check(world.has_method("is_riding"), "world exposes ride state contract")
	_check(world._point_by_id("ride-tide").size() > 0, "tide carousel is discoverable as ride-tide")
	if not world.has_method("start_ride") or not world.has_method("end_ride") or not world.has_method("is_riding"):
		world.queue_free()
		await process_frame
		_finish()
		return
	world.blocked = true
	_check(not bool(world.call("start_ride")), "blocked player cannot board")
	world.blocked = false
	var attraction: Node3D = world.island_attractions
	var seat: Node3D = attraction._seat_marker.get_parent()
	var cushion := seat.find_child("OpenSeatCushion",true,false) as MeshInstance3D
	_check(cushion != null,"rider gondola owns its visible cushion")
	_check(attraction._ride_pivot.find_child("CarouselFoundation",true,false) != null,"carousel geometry is rooted at the actual boardwalk ride position")
	var overhead := attraction._ride_pivot.find_child("OverheadGondolaRing",true,false) as MeshInstance3D
	_check(overhead != null and overhead.position.y>=2.25,"gondola overhead ring clears the seated rider's head")
	for index in range(4):
		var shell_seat := attraction._ride_pivot.find_child("ShellSeat%d" % (index+1),true,false) as Node3D
		for side in ["Left","Right"]:
			var support := attraction._ride_pivot.find_child("GondolaRearSupport%d_%s" % [index+1,side],true,false) as MeshInstance3D
			_check(support != null and shell_seat != null,"each shell seat has both named rear supports")
			if support != null and shell_seat != null:
				var support_in_seat := shell_seat.to_local(support.global_position)
				_check(support_in_seat.z<=-0.5 and absf(support_in_seat.x)>=0.45,"rear supports stand behind and outside the rider's seat volume")
	if cushion != null:
		_check(cushion.global_position.distance_to(attraction._seat_marker.global_position) < 0.7,"seat cushion and rider anchor occupy the same gondola")
	var ride_point: Dictionary = world._point_by_id("ride-tide")
	var ride_position: Vector3 = ride_point.get("position", Vector3.ZERO)
	var guide_position: Vector3 = world._point_by_id("guide").get("position", Vector3.ZERO)
	var carousel: Node3D = attraction._ride_pivot
	var boardwalk := attraction.find_child("TideBoardwalkDeck",true,false) as MeshInstance3D
	var foundation := attraction.find_child("CarouselFoundation",true,false) as MeshInstance3D
	var spindle := attraction.find_child("ShellCarouselSpindle",true,false) as MeshInstance3D
	_check(absf(ride_position.x+6.7)<0.01 and absf(ride_position.z-11.2)<0.01, "ride interaction sits at the open outer boardwalk approach")
	var ramp_toe := Vector2(-4.2,11.2)
	_check(Vector2(guide_position.x,guide_position.z).distance_to(ramp_toe)>3.0, "guide interaction is clear of the ramp toe")
	_check(ride_position.distance_to(guide_position) > 3.0, "ride boarding point is separated from the welcome guide interaction")
	_check(Vector2(ride_position.x-carousel.global_position.x,ride_position.z-carousel.global_position.z).length()>2.9, "boarding point clears the carousel foundation and leaves approach room")
	_check(boardwalk != null and absf(boardwalk.global_position.z-10.0)<0.01 and (boardwalk.mesh as BoxMesh).size.z>=6.8, "wider deck carries the full rail and boarding approach")
	var foundation_body := foundation.find_child("CarouselFoundationCollision",true,false) as StaticBody3D if foundation != null else null
	var spindle_body := spindle.find_child("CarouselSpindleCollision",true,false) as StaticBody3D if spindle != null else null
	var rail_body := attraction.find_child("TideBoardwalkHandrailCollision",true,false) as StaticBody3D
	_check(foundation_body != null and spindle_body != null and rail_body != null, "foundation, spindle, and handrails have local physical colliders")
	world.player.global_position=Vector3(-13.0,0.1,10.0)
	await physics_frame
	_check(world.player.test_move(world.player.global_transform,Vector3(4.0,0.0,0.0)), "solid carousel foundation blocks walking through the ride base")
	world.player.global_position=Vector3(-10.0,0.1,13.8)
	await physics_frame
	_check(world.player.test_move(world.player.global_transform,Vector3(0.0,0.0,-2.0)), "boardwalk handrail blocks walking through the rail")
	await _walk_tide_ramp(world,-3.8,-6.7,0.55,true,"careful walk reaches ride entrance",11.2)
	world.player.global_position = ride_position
	Input.action_press("interact")
	_check(bool(world.call("start_ride")), "player can board from ride interaction point")
	_check(bool(world.call("is_riding")), "ride reports active after boarding")
	world._physics_process(1.0 / 60.0)
	_check(bool(world.call("is_riding")), "boarding E input does not immediately cancel on the next physics tick")
	_check(world.last_avatar_action == "sit" and world.avatar.texture != null, "ride switches the player to the authored seated front pose")
	Input.action_release("interact")
	world.island_attractions.set_reduced_motion(true)
	world.island_attractions._process(4.0)
	_check(absf(world.island_attractions._ride_pivot.rotation.y) < 0.001, "reduced motion holds the carousel still")
	var seated_position: Vector3 = world.player.global_position
	world._physics_process(1.0 / 60.0)
	_check(world.player.global_position.distance_to(seated_position) < 0.02, "ride locks walking without moving the player through the seat")
	world.call("interact")
	_check(not bool(world.call("is_riding")), "explicit cancel ends the ride")
	_check(world.player.global_position.distance_to(ride_position) < 0.35, "cancel restores player to a safe boarding point")
	_check(bool(world.call("start_ride")), "ride can be boarded again")
	world.blocked = true
	world._physics_process(1.0 / 60.0)
	_check(not bool(world.call("is_riding")), "blocking/pause safely ends the ride")
	_check(world.player.global_position.distance_to(ride_position) < 0.35, "pause exit restores a safe player position")
	world.blocked = false
	_check(bool(world.call("start_ride")), "ride can restart after pause")
	world._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not bool(world.call("is_riding")), "application focus loss safely cancels motion")
	_check(world.player.global_position.distance_to(ride_position) < 0.35, "focus loss restores a safe player position")
	_check(bool(world.call("start_ride")), "ride can start before world removal")
	root.remove_child(world)
	_check(not bool(world.call("is_riding")), "leaving the world tree cancels the ride")
	_check(world.player.position.distance_to(ride_position) < 0.35, "leaving the tree restores a safe player position")
	world.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _exercise_tide_ramp(world: Node) -> void:
	await _walk_tide_ramp(world,-3.8,-6.3,0.55,true,"careful uphill")
	await _walk_tide_ramp(world,-6.3,-3.8,0.55,true,"careful downhill")
	await _walk_tide_ramp(world,-3.8,-6.3,2.0,false,"jog uphill")
	await _walk_tide_ramp(world,-6.3,-3.8,2.0,false,"jog downhill")

func _walk_tide_ramp(world: Node, start_x: float, target_x: float, speed: float, careful: bool, label: String, z := 10.0) -> void:
	var direction := 1.0 if target_x > start_x else -1.0
	var key := KEY_D if direction > 0.0 else KEY_A
	var movement := InputEventKey.new()
	movement.keycode=key; movement.physical_keycode=key; movement.pressed=true
	var shift := InputEventKey.new()
	shift.keycode=KEY_SHIFT; shift.physical_keycode=KEY_SHIFT; shift.pressed=careful
	world.blocked=false
	world.player.velocity=Vector3.ZERO
	var start_floor_y: float=maxf(world._ground_surface_y(Vector3(start_x,0.0,z)),0.20)
	world.player.global_position=Vector3(start_x,start_floor_y-0.1,z)
	for _settle_frame in 18: await physics_frame
	Input.parse_input_event(movement)
	if careful: Input.parse_input_event(shift)
	Input.flush_buffered_events()
	var previous_foot_y: float=world.player.global_position.y+0.1
	var max_foot_step := 0.0
	var max_ground_error := 0.0
	var frames := ceili(absf(target_x-start_x)/speed*60.0)+50
	for _frame in frames:
		await physics_frame
		var foot_y: float=world.player.global_position.y+0.1
		max_foot_step=maxf(max_foot_step,absf(foot_y-previous_foot_y))
		previous_foot_y=foot_y
		var expected_y: float=world._ground_surface_y(world.player.global_position)
		max_ground_error=maxf(max_ground_error,absf(foot_y-expected_y))
		if (target_x-world.player.global_position.x)*direction <= 0.0:
			break # Finish the measured ramp crossing instead of walking beyond its destination.
	var end_x: float=world.player.global_position.x
	if target_x < start_x:
		_check(end_x<target_x+0.2, "%s reaches the upper deck under CharacterBody collision (x=%.2f)" % [label,end_x])
	else:
		_check(end_x>target_x-0.2, "%s reaches the lawn under CharacterBody collision (x=%.2f)" % [label,end_x])
	_check(max_foot_step<0.045, "%s traversal has continuous foot height (max step %.3fm)" % [label,max_foot_step])
	_check(max_ground_error<0.045, "%s feet stay aligned to the shared terrain sampler (max offset %.3fm)" % [label,max_ground_error])
	movement.pressed=false
	Input.parse_input_event(movement)
	if careful:
		shift.pressed=false
		Input.parse_input_event(shift)
	Input.flush_buffered_events()
	await physics_frame

func _finish() -> void:
	if failures.is_empty():
		print("PASS: island ride lifecycle")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
