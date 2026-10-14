extends SceneTree

const ParkWorld = preload("res://game/world/park_world.gd")
const DIRECTIONS := ["back", "back_right", "right", "front_right", "front", "front_left", "left", "back_left"]
const INPUTS := [["move_up"], ["move_up", "move_right"], ["move_right"], ["move_down", "move_right"], ["move_down"], ["move_down", "move_left"], ["move_left"], ["move_up", "move_left"]]

var interaction_ids: Array[String] = []
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := ParkWorld.new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	_check(not world.avatar_motion_available and world.avatar_motion_rig==null,"the production world avoids allocating an unused hero gait rig")
	_check(world.avatar.visible,"normal on-foot idle uses the authored source Sprite")
	var avatar_material := world.avatar.material_override as ShaderMaterial
	_check(avatar_material!=null and float(avatar_material.get_shader_parameter("motion"))==0.0,"authored full-body cels are not displaced by the actor shader")
	_check(int(world.component_motion.statistics().get("by_profile",{}).get("character_hero",0))==0,"authored hero idle has no procedural phase registration")
	var visible_markers := 0
	for point in world.points:
		var marker := point.get("marker") as Label3D
		if is_instance_valid(marker) and marker.visible: visible_markers+=1
	_check(visible_markers<=1,"world interaction glyphs are limited to the one currently reachable point")
	_check(world.district_labels.size()==4,"the four local district titles are cached for bounded visibility updates")
	for label in world.district_labels:
		var label_position: Vector3=label.global_position
		world.player.position=Vector3(label_position.x,ParkWorld._ground_surface_y(label_position),label_position.z)
		world.camera.position=world.player.position+Vector3(3.5,16.5,25.0)
		world.camera.look_at(world.player.position+Vector3(0,1,0))
		await physics_frame
		_check(Vector2(world.player.position.x-label.global_position.x,world.player.position.z-label.global_position.z).length()<=10.0 and label.visible,"district title is visible within 10m of the player even with the offset camera")
		_check(world.camera.global_position.distance_to(label.global_position)>25.0,"the visibility check covers normal offset-camera separation")
		world.player.position=Vector3(0,0.3,23.2)
		world.camera.position=world.player.position+Vector3(3.5,16.5,25.0)
		world.camera.look_at(world.player.position+Vector3(0,1,0))
		await physics_frame
		_check(not label.visible,"district titles are hidden when the player is farther than 10m")

	for index in range(DIRECTIONS.size()):
		_release_movement()
		world.player.position=Vector3(0.0,ParkWorld._ground_surface_y(Vector3(0.0,0.0,-15.0)),-15.0)
		world.player.velocity=Vector3.ZERO
		world.facing="front"
		await physics_frame
		var start_position: Vector3=world.player.global_position
		var start_phase: float=world.walk_distance_phase
		var observed_frames := {}
		var observed_textures := {}
		for action in INPUTS[index]: Input.action_press(action)
		for _tick in range(42):
			await physics_frame
			_check(world.avatar_motion_rig==null and world.avatar.visible,"live %s travel stays on the source Sprite without a procedural rig" % DIRECTIONS[index])
			if world.avatar_is_walking and world.last_avatar_action=="walk":
				_check(world.last_avatar_direction==DIRECTIONS[index],"real %s motion selects its authored direction row" % DIRECTIONS[index])
				observed_frames[world.last_avatar_frame]=true
				observed_textures[world.avatar.texture.get_instance_id()]=true
		for action in INPUTS[index]: Input.action_release(action)
		var displacement: Vector3=world.player.global_position-start_position
		var travelled := Vector2(displacement.x,displacement.z).length()
		var phase_delta := fposmod(world.walk_distance_phase-start_phase,ParkWorld.WALK_STRIDE_DISTANCE)
		_check(travelled>0.16 and phase_delta>0.0,"%s input moves the real player and advances distance phase" % DIRECTIONS[index])
		_check(observed_frames.size()>1 and observed_textures.size()>1,"%s route changes actual authored cels and Sprite textures" % DIRECTIONS[index])
		world.player.velocity=Vector3.ZERO
		for _tick in range(8): await physics_frame
		_check(not world.avatar_is_walking and world.last_avatar_action=="idle","%s stop returns to an idle source stance" % DIRECTIONS[index])
		if DIRECTIONS[index]=="front":
			_check(world.avatar_renderer.animation_library.has_action("traveller","idle","front"),"front keeps its authored idle sequence")
		else:
			_check(world.last_avatar_frame==world.avatar_renderer.walk_idle_frame(DIRECTIONS[index]),"%s idle holds its authored stance cel" % DIRECTIONS[index])
	Input.action_release("move_right")
	var shift_down := InputEventKey.new()
	shift_down.keycode=KEY_SHIFT
	shift_down.physical_keycode=KEY_SHIFT
	shift_down.pressed=true
	Input.parse_input_event(shift_down)
	world.player.position=Vector3(0.0,ParkWorld._ground_surface_y(Vector3(0.0,0.0,-15.0)),-15.0)
	world.player.velocity=Vector3.ZERO
	for _tick in range(2): await physics_frame
	Input.action_press("move_right")
	for _tick in range(35): await physics_frame
	_check(not world.avatar_run_requested and world.avatar_is_walking and world.avatar_motion_rig==null and world.avatar.visible,"Shift selects the careful walk while retaining un-stretched authored Sprite cels")
	Input.action_release("move_right")
	var shift_up := InputEventKey.new()
	shift_up.keycode=KEY_SHIFT
	shift_up.physical_keycode=KEY_SHIFT
	shift_up.pressed=false
	Input.parse_input_event(shift_up)
	for _tick in range(20): await physics_frame
	_check(not world.avatar_is_walking and world.last_avatar_action=="idle" and world.avatar_motion_rig==null and world.avatar.visible,"deceleration returns to the authored idle stance without procedural settling")

	world.blocked=true
	Input.action_press("move_right")
	await physics_frame
	var blocked_position: Vector3 = world.player.global_position
	var blocked_travel: float = world.walk_distance_phase
	for _tick in range(8): await physics_frame
	_check(world.player.global_position.is_equal_approx(blocked_position),"modal blocking freezes actual player translation")
	_check(is_equal_approx(world.walk_distance_phase,blocked_travel) and not world.avatar_is_walking and world.avatar_motion_rig==null,"blocked motion cannot advance authored walk phase")
	Input.action_release("move_right")
	world.blocked=false

	world.play_action("wave")
	_check(world.avatar_motion_rig==null and world.avatar.visible and world.avatar_action=="wave","the source Sprite remains the gesture presenter")
	world.avatar_action_remaining=0.0
	world._refresh_avatar_texture(0)
	_check(world.avatar_motion_rig==null and world.avatar.visible,"the source Sprite remains the walk and idle presenter after the gesture")
	var changed_appearance := {"skin":"deep","species":"elf","gender":"neutral","hair":"curly","hair_color":"ink","face":"curious"}
	var changed_equipment := {"outfit":"outfit-tide","hat":"hat-none"}
	world.set_avatar_look(changed_appearance,changed_equipment)
	_check(world.avatar_motion_rig==null and world.avatar_appearance==changed_appearance and world.avatar_equipped==changed_equipment,"wardrobe changes update the authored source renderer without a redundant rig")
	_check(world.avatar.texture!=null,"the existing sprite texture remains available for actions and ride fallback")

	world.blocked=true
	world.player.position=Vector3(8.0,0.44,-36.2)
	await physics_frame
	var teleported_x := world.player.position.x+4.0
	world.player.position.x=teleported_x
	await physics_frame
	_check(world.avatar_motion_rig==null,"external repositioning never creates a procedural hero gait rig")
	_check(world.camera.position.distance_to(world.player.position+ParkWorld.CAMERA_OFFSET)<0.4,"an external teleport snaps the follow camera before its ordinary follow lerp")
	world.blocked=false

	var ride_point: Dictionary = world._point_by_id("ride-tide")
	_check(not ride_point.is_empty(),"the existing ride interaction point remains registered")
	var ride_position: Vector3=ride_point.position
	var boarding_position := ride_position+Vector3(-1.5,0.0,0.3)
	boarding_position.y=ParkWorld._ground_surface_y(boarding_position)
	world.player.position=boarding_position
	await physics_frame
	_check(world.player.global_position.distance_to(ride_position)<2.4,"ride marker check starts at the actual registered point's reachable approach")
	_check(world.nearest.get("id","")=="ride-tide" and ride_point.marker.visible,"the actionable point keeps its marker visible while in range")
	world.interaction_requested.connect(_record_interaction)
	world.interact()
	_check(not interaction_ids.is_empty() and interaction_ids.back()=="ride-tide","nearby ride interaction remains reachable at the existing distance threshold")
	_check(world.start_ride(),"the existing ride entry remains available")
	_check(world.is_riding() and world.avatar_motion_rig==null and world.avatar.visible,"riding retains the seated Sprite presentation")
	await physics_frame
	for point in world.points:
		var marker := point.get("marker") as Label3D
		_check(not is_instance_valid(marker) or not marker.visible,"the ride's synthetic nearest entry does not leave a distant world glyph visible")
	world.end_ride()
	world._refresh_avatar_texture(0)
	_check(not world.is_riding() and world.avatar_motion_rig==null and world.avatar.visible,"leaving the ride restores the authored source Sprite")

	_check(not ParkWorld.motion_sources_ready({}),"optional rig source validation rejects missing directional metadata")
	_check(not ParkWorld.motion_sources_ready({"front":{"valid":false}}),"optional rig source validation rejects partial directional metadata")
	Input.action_release("move_right")
	world.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error("avatar motion world integration failed %d check(s): %s" % [_failures.size(), "; ".join(_failures)])
		quit(1)
		return
	print("PASS: integrated avatar motion world checks")
	quit(0)

func _record_interaction(id: String, _label: String) -> void:
	interaction_ids.append(id)

func _release_movement() -> void:
	for action in ["move_up","move_down","move_left","move_right"]:
		Input.action_release(action)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	_failures.append(label)
	push_error("AVATAR MOTION WORLD: " + label)
