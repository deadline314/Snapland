extends SceneTree

const ParkWorld = preload("res://game/world/park_world.gd")

var interaction_ids: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := ParkWorld.new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var rig: Node3D = world.avatar_motion_rig
	assert(world.avatar_motion_available and rig!=null,"valid eight-direction source records enable the on-foot world-space rig")
	assert(rig.source_records.size()==8 and world.motion_sources_ready(rig.source_records),"the integrated rig uses eight validated source records")
	assert(rig.visible and not world.avatar.visible,"normal on-foot idle uses the real-space avatar rig")
	assert(rig.ground_height_provider.is_valid(),"the rig samples the island ground provider")
	assert(rig.projection_basis.is_equal_approx(world.camera.global_basis),"the rig shares the actual world camera projection basis")
	assert(absf(rig.global_position.y-ParkWorld._ground_surface_y(world.player.global_position))<0.001,"the rig origin remains at the current ground surface")
	var visible_markers := 0
	for point in world.points:
		var marker := point.get("marker") as Label3D
		if is_instance_valid(marker) and marker.visible: visible_markers+=1
	assert(visible_markers<=1,"world interaction glyphs are limited to the one currently reachable point")
	assert(world.district_labels.size()==4,"the four local district titles are cached for bounded visibility updates")
	for label in world.district_labels:
		var label_position: Vector3=label.global_position
		world.player.position=Vector3(label_position.x,ParkWorld._ground_surface_y(label_position),label_position.z)
		world.camera.position=world.player.position+Vector3(3.5,16.5,25.0)
		world.camera.look_at(world.player.position+Vector3(0,1,0))
		await physics_frame
		assert(Vector2(world.player.position.x-label.global_position.x,world.player.position.z-label.global_position.z).length()<=10.0 and label.visible,"district title is visible within 10m of the player even with the offset camera")
		assert(world.camera.global_position.distance_to(label.global_position)>25.0,"the visibility check covers normal offset-camera separation")
		world.player.position=Vector3(0,0.3,23.2)
		world.camera.position=world.player.position+Vector3(3.5,16.5,25.0)
		world.camera.look_at(world.player.position+Vector3(0,1,0))
		await physics_frame
		assert(not label.visible,"district titles are hidden when the player is farther than 10m")

	Input.action_press("move_right")
	await physics_frame
	var start_position: Vector3 = world.player.global_position
	var start_travel: float = rig.travel
	for _tick in range(20): await physics_frame
	var careful_displacement := Vector2(world.player.global_position.x-start_position.x,world.player.global_position.z-start_position.z).length()
	var careful_phase_delta: float = rig.travel-start_travel
	assert(careful_displacement>0.08 and absf(careful_displacement-careful_phase_delta)<0.025,"walk phase advances by the player's post-collision world displacement exactly once")
	assert(rig.speed>1.75 and rig.speed<2.2 and rig.running and rig.direction=="right","default comfortable jog settles near 2 m/s in the measured travel direction")
	assert(rig.position.x==0.0 and rig.position.z==0.0,"the rig never translates the player a second time")
	Input.action_release("move_right")
	var shift_down := InputEventKey.new()
	shift_down.keycode=KEY_SHIFT
	shift_down.physical_keycode=KEY_SHIFT
	shift_down.pressed=true
	Input.parse_input_event(shift_down)
	Input.action_press("move_right")
	for _tick in range(35): await physics_frame
	assert(not rig.running and rig.speed>0.45 and rig.speed<0.66,"Shift selects the careful 0.55 m/s walk without stretching the gait")
	Input.action_release("move_right")
	var shift_up := InputEventKey.new()
	shift_up.keycode=KEY_SHIFT
	shift_up.physical_keycode=KEY_SHIFT
	shift_up.pressed=false
	Input.parse_input_event(shift_up)
	for _tick in range(20): await physics_frame
	assert(rig.speed<0.08 and rig.blend<0.08,"acceleration and deceleration settle the rig cleanly into idle")

	world.blocked=true
	Input.action_press("move_right")
	await physics_frame
	var blocked_position: Vector3 = world.player.global_position
	var blocked_travel: float = rig.travel
	for _tick in range(8): await physics_frame
	assert(world.player.global_position.is_equal_approx(blocked_position),"modal blocking freezes actual player translation")
	assert(is_equal_approx(rig.travel,blocked_travel) and rig.speed==0.0,"blocked motion cannot advance gait phase")
	Input.action_release("move_right")
	world.blocked=false

	world.play_action("wave")
	assert(not rig.visible and world.avatar.visible and world.avatar_action=="wave","the existing billboard remains the gesture presenter")
	world.avatar_action_remaining=0.0
	world._refresh_avatar_texture(0)
	assert(rig.visible and not world.avatar.visible,"the 3D rig resumes after the gesture")
	var changed_appearance := {"skin":"deep","species":"elf","gender":"neutral","hair":"curly","hair_color":"ink","face":"curious"}
	var changed_equipment := {"outfit":"outfit-tide","hat":"hat-none"}
	world.set_avatar_look(changed_appearance,changed_equipment)
	assert(rig.appearance==changed_appearance and rig.equipment==changed_equipment,"wardrobe changes reach the rig without changing the world API")
	assert(world.avatar.texture!=null,"the existing sprite texture remains available for actions and ride fallback")

	world.blocked=true
	world.player.position=Vector3(8.0,0.44,-36.2)
	await physics_frame
	var ramp_y := ParkWorld._ground_surface_y(world.player.global_position)
	assert(absf(rig.global_position.y-ramp_y)<0.001,"terrain/ramp motion keeps the rig anchored to the sampled ground height")
	assert(absf(rig.foot_world[0].y-ramp_y)<0.04 and absf(rig.foot_world[1].y-ramp_y)<0.04,"both idle soles use the same terrain ground provider")
	var teleported_x := world.player.position.x+4.0
	world.player.position.x=teleported_x
	await physics_frame
	assert(rig.travel==0.0 and rig.speed==0.0,"an external teleport cancels stale planted contacts")
	assert(world.camera.position.distance_to(world.player.position+ParkWorld.CAMERA_OFFSET)<0.4,"an external teleport snaps the follow camera before its ordinary follow lerp")
	assert(rig.global_position.distance_to(rig._last_global_position)<0.001,"the rig's motion baseline is synchronized after the external reposition")
	world.blocked=false

	var ride_point: Dictionary = world._point_by_id("ride-tide")
	assert(not ride_point.is_empty(),"the existing ride interaction point remains registered")
	var ride_position: Vector3=ride_point.position
	var boarding_position := ride_position+Vector3(-1.5,0.0,0.3)
	boarding_position.y=ParkWorld._ground_surface_y(boarding_position)
	world.player.position=boarding_position
	await physics_frame
	assert(world.player.global_position.distance_to(ride_position)<2.4,"ride marker check starts at the actual registered point's reachable approach")
	assert(world.nearest.get("id","")=="ride-tide" and ride_point.marker.visible,"the actionable point keeps its marker visible while in range")
	world.interaction_requested.connect(_record_interaction)
	world.interact()
	assert(not interaction_ids.is_empty() and interaction_ids.back()=="ride-tide","nearby ride interaction remains reachable at the existing distance threshold")
	assert(world.start_ride(),"the existing ride entry remains available")
	assert(world.is_riding() and not rig.visible and world.avatar.visible,"riding returns to the seated Sprite presentation")
	await physics_frame
	for point in world.points:
		var marker := point.get("marker") as Label3D
		assert(not is_instance_valid(marker) or not marker.visible,"the ride's synthetic nearest entry does not leave a distant world glyph visible")
	world.end_ride()
	world._refresh_avatar_texture(0)
	assert(not world.is_riding() and rig.visible,"leaving the ride restores the 3D on-foot rig")

	assert(not ParkWorld.motion_sources_ready({}),"missing direction metadata keeps the original sprite fallback enabled")
	assert(not ParkWorld.motion_sources_ready({"front":{"valid":false}}),"partially invalid source metadata cannot activate a partial 3D rig")
	Input.action_release("move_right")
	world.queue_free()
	await process_frame
	print("PASS: integrated avatar motion world checks")
	quit(0)

func _record_interaction(id: String, _label: String) -> void:
	interaction_ids.append(id)
