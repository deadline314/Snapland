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
	_check(_visible_markers(world).is_empty(), "new regions start with no leftover active glyphs")
	await physics_frame
	await physics_frame
	_check(not world.avatar_motion_available and world.avatar_motion_rig==null,"the production world avoids allocating an unused hero gait rig")
	_check(world.avatar.visible,"normal on-foot idle uses the authored source Sprite")
	var avatar_material := world.avatar.material_override as ShaderMaterial
	_check(avatar_material!=null and float(avatar_material.get_shader_parameter("motion"))==0.0,"authored full-body cels are not displaced by the actor shader")
	_check(int(world.component_motion.statistics().get("by_profile",{}).get("character_hero",0))==0,"authored hero idle has no procedural phase registration")
	_check(_visible_markers(world).size() <= 1, "world interaction glyphs are limited to the one currently reachable point")
	await _check_interaction_marker_selection(world)
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
		_check(world.avatar_renderer.animation_library.has_action("traveller","idle",DIRECTIONS[index]),"%s keeps its dedicated authored idle sequence" % DIRECTIONS[index])
		var expected_idle: Texture2D = world.avatar_renderer.texture(world.avatar_appearance, world.avatar_equipped, DIRECTIONS[index], world.last_avatar_frame, "idle")
		_check(world.avatar.texture == expected_idle, "%s stop displays its dedicated full-body idle source" % DIRECTIONS[index])
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
	for side in ["left", "right"]:
		world.facing = side
		world.play_action("wave")
		_check(world.facing == side and world.last_avatar_direction == side and world.last_avatar_source_action == "wave", "the authored wave retains its side facing")
		_check(is_equal_approx(world.avatar_action_remaining, 0.8), "each side plays the entire greeting")
		world.play_action("photo")
		_check(world.facing == side and world.last_avatar_direction == side and world.last_avatar_source_action == "photograph", "photography retains its authored side facing")
		_check(is_equal_approx(world.avatar_action_remaining, 1.06), "each side plays the entire photographic action")
	world.avatar_action=""
	world.avatar_action_remaining=0.0
	world._refresh_avatar_texture(0)
	_check(world.avatar_motion_rig==null and world.avatar.visible,"the source Sprite remains the walk and idle presenter after the gesture")
	await _check_walking_gesture_requests(world)
	await _check_settles(world)
	await _check_slow_profile_stop(world)
	await _check_departures(world)
	await _check_reversals(world)
	await _check_side_pivot(world)
	await _check_camera_idle(world)
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
	_check(not ride_point.marker.visible and world.nearest.get("marker") == null,
		"boarding immediately replaces the station glyph with the exit interaction")
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

func _visible_markers(world: ParkWorld) -> Array[Label3D]:
	var visible: Array[Label3D] = []
	for point in world.points:
		var marker: Label3D = point.get("marker")
		if is_instance_valid(marker) and marker.visible:
			visible.append(marker)
	return visible

func _check_interaction_marker_selection(world: ParkWorld) -> void:
	# Keep the cutoff assertions independent of new scenery interactions.
	var original_points := world.points.duplicate()
	world.points.clear()
	var anchor := Vector3(0.0, 0.0, -22.0)
	anchor.y = ParkWorld._ground_surface_y(anchor)
	world.player.position = anchor
	var first := world._label("◇", anchor, 14)
	var second := world._label("◇", anchor, 14)
	var first_point := world._register_interaction_point("test:first", "First", anchor + Vector3.RIGHT, first)
	var second_point := world._register_interaction_point("test:second", "Second", anchor + Vector3.RIGHT, second)
	_check(not first.visible and not second.visible, "newly registered points stay hidden before selection")
	await physics_frame
	await physics_frame
	_check(world.nearest.get("id") == "test:first" and _visible_markers(world) == [first],
		"equal-distance points keep the first registration order")
	second_point.position = anchor + Vector3.RIGHT * 0.25
	await physics_frame
	await physics_frame
	_check(world.nearest.get("id") == "test:second" and _visible_markers(world) == [second],
		"moving points are selected while the traveller stays still")
	world.points.erase(second_point)
	second.free()
	await physics_frame
	await physics_frame
	_check(world.nearest.get("id") == "test:first" and _visible_markers(world) == [first],
		"removing the active point and freeing its marker leaves the next available glyph")
	first_point.position = world.player.position + Vector3.RIGHT * 2.41
	await physics_frame
	await physics_frame
	_check(world.nearest.is_empty() and _visible_markers(world).is_empty(), "points beyond the 2.4 m reach stay hidden")
	first_point.position = world.player.position + Vector3.RIGHT * 2.39
	await physics_frame
	await physics_frame
	_check(world.nearest.get("id") == "test:first" and _visible_markers(world) == [first],
		"points just within the 2.4 m reach become interactive")
	first_point.position = world.player.position + Vector3.UP * 2.41
	await physics_frame
	await physics_frame
	_check(world.nearest.is_empty() and _visible_markers(world).is_empty(), "vertical distance counts towards interaction reach")
	world.points.assign(original_points)
	first.queue_free()

func _check_walking_gesture_requests(world: ParkWorld) -> void:
	world.player.position = Vector3(0, ParkWorld._ground_surface_y(Vector3(0, 0, -15)), -15)
	Input.action_press("move_up")
	for _tick in range(35): await physics_frame
	_check(world.avatar_is_walking and world.facing == "back", "gesture regression starts on the real back walk cycle")
	for key in [KEY_F, KEY_P]:
		var old_frame := world.last_avatar_frame
		var old_texture := world.avatar.texture
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		world._unhandled_key_input(event)
		_check(world.facing == "back" and world.last_avatar_direction == "back" and world.last_avatar_frame == old_frame and world.avatar.texture == old_texture,
			"walking key %d preserves direction, stride cel and texture before physics" % key)
		for _tick in range(3): await physics_frame
		_check(world.last_avatar_action == "walk" and world.avatar_action.is_empty(), "continued travel discards the planted gesture")

	world.nearest = {"id":"test-gesture-stop", "label":"Gesture stop regression"}
	world.interaction_requested.connect(func(_id: String, _label: String): world.blocked = true, CONNECT_ONE_SHOT)
	var approach_texture := world.avatar.texture
	world.interact()
	_check(world.blocked and world.avatar.texture == approach_texture and world.facing == "back", "a reachable interaction opens immediately without replacing its moving pose")
	Input.action_release("move_up")
	for _tick in range(3): await physics_frame
	_check(not world.avatar_is_walking and world.last_avatar_action == "interact" and world.facing == "front" and world.avatar_action_elapsed == 0.0,
		"the first stationary tick prepares the whole interaction and preserves the modal pause")
	world.blocked = false
	world.avatar_action = ""
	world.avatar_action_remaining = 0.0

func _check_settles(world: ParkWorld) -> void:
	for index in range(DIRECTIONS.size()):
		var direction: String = DIRECTIONS[index]
		var movement: Array = INPUTS[index]
		var observed := false
		for travel_ticks in [21, 29, 39, 18, 24, 31, 47, 54]:
			world.player.position = Vector3(0, ParkWorld._ground_surface_y(Vector3(0, 0, -15)), -15)
			for _tick in range(2): await physics_frame
			for action in movement: Input.action_press(action)
			for _tick in range(travel_ticks): await physics_frame
			for action in movement: Input.action_release(action)
			for _tick in range(18):
				await physics_frame
				if world.last_avatar_action != ParkWorld.AVATAR_STOP_ACTION: continue
				observed = true
				var at_rest := world.player.global_position
				var phase := world.walk_distance_phase
				var expected: Texture2D = world.avatar_renderer.texture(world.avatar_appearance, world.avatar_equipped, direction, 0, ParkWorld.AVATAR_STOP_ACTION)
				_check(world.avatar.texture == expected and world.facing == direction and not world.avatar_is_walking, "the %s stop displays its planted art after physical deceleration" % direction)
				if direction != "right":
					for _hold in range(8): await physics_frame
					_check(world.last_avatar_action == "idle" and world.last_avatar_frame == 0 and world.player.global_position.is_equal_approx(at_rest) and world.walk_distance_phase == phase,
						"the planted stop returns to the same-direction neutral pose without advancing the stride")
				else:
					world.apply_settings({"reduced_motion":true})
					_check(world.last_avatar_action == "idle" and world.avatar_action_remaining == 0.0, "reduced motion immediately restores the neutral pose")
					world.apply_settings({"reduced_motion":false})
				break
			if observed: break
		_check(observed, "real %s movement reaches the reviewed stop" % direction)

func _check_slow_profile_stop(world: ParkWorld) -> void:
	var point := Vector3(-2.6, 0.0, -5.5)
	point.y = world.ground_surface_y(point)
	world.player.position = point
	var time_scale := Engine.time_scale
	Engine.time_scale = 0.25
	for _tick in range(8): await physics_frame
	Input.action_press("move_left")
	for _tick in range(84): await physics_frame
	Input.action_release("move_left")
	var observed := false
	var trace: Array = []
	for _tick in range(76):
		await physics_frame
		observed = observed or world.last_avatar_action == ParkWorld.AVATAR_STOP_ACTION
		trace.append([world.last_avatar_action, world.last_avatar_frame, world.player.velocity.x])
	Engine.time_scale = time_scale
	_check(observed and world.last_avatar_action == "idle" and world.facing == "left",
		"quarter-speed deceleration plays the reviewed stop and returns to left idle: %s" % [trace.slice(30, 55)])

func _check_departures(world: ParkWorld) -> void:
	var original_scale := Engine.time_scale
	for speed: float in [1.0, 0.25]:
		Engine.time_scale = speed
		for index in range(DIRECTIONS.size()):
			var direction: String = DIRECTIONS[index]
			var movement: Array = INPUTS[index]
			var point := Vector3(-2.6 if index % 2 == 0 else -0.6, 0.0, -5.5)
			point.y = world.ground_surface_y(point)
			world.player.position = point
			world.facing = direction
			for _tick in range(4): await physics_frame
			var before := world.player.global_position
			for action in movement: Input.action_press(action)
			var takeoff_ticks := 0
			var continued := false
			var expected: Texture2D = world.avatar_renderer.texture(world.avatar_appearance, world.avatar_equipped, direction, 0, "depart")
			for _tick in range(40 if speed < 1.0 else 12):
				await physics_frame
				if world.last_avatar_source_action == "depart":
					takeoff_ticks += 1
					_check(world.avatar.texture == expected and world.last_avatar_action == "walk" and world.player.global_position != before,
						"takeoff uses its own artwork while the normal physics body moves")
				elif takeoff_ticks > 0:
					continued = world.last_avatar_source_action == "walk" and world.last_avatar_frame == 0
					break
			_check(takeoff_ticks >= (19 if speed < 1.0 else 5) and continued and world.facing == direction,
				"%s scale %s takeoff enters the reviewed walk cel without stalling motion or changing heading (%d ticks)" % [direction, speed, takeoff_ticks])
			for action in movement: Input.action_release(action)
	Engine.time_scale = original_scale
	world.player.position = Vector3(-2.6, world.ground_surface_y(Vector3(-2.6,0,-5.5)), -5.5)
	world.facing = "left"
	for _tick in range(4): await physics_frame
	Input.action_press("move_left")
	for _tick in range(2): await physics_frame
	_check(world.last_avatar_source_action == "depart", "starts a left takeoff before a settings interruption")
	world.apply_settings({"reduced_motion":true})
	_check(world.last_avatar_source_action == "walk" and world._avatar_departure_remaining == 0.0,
		"reduced motion drops the takeoff and keeps walking")
	world.apply_settings({"reduced_motion":false})
	await physics_frame
	_check(world.last_avatar_source_action == "walk", "reenabling motion during travel does not replay takeoff")
	Input.action_release("move_left")
	for _tick in range(23): await physics_frame
	var library: RefCounted = world.avatar_renderer.animation_library
	var incomplete: RefCounted = library.get_script().new()
	incomplete.manifest.actors.traveller.depart.right.frames[0].source = "res://assets/characters/missing-departure.png"
	world.avatar_renderer.animation_library = incomplete
	world.player.position = Vector3(-0.6, world.ground_surface_y(Vector3(-0.6, 0, -5.5)), -5.5)
	world.facing = "right"
	for _tick in range(4): await physics_frame
	Input.action_press("move_right")
	for _tick in range(3): await physics_frame
	_check(world.last_avatar_source_action == "walk" and world._avatar_departure_remaining == 0.0 and world.avatar_is_walking,
		"missing takeoff art falls back to the existing movement and walk source")
	Input.action_release("move_right")
	world.avatar_renderer.animation_library = library
	for _tick in range(23): await physics_frame

func _check_reversals(world: ParkWorld) -> void:
	var original_scale := Engine.time_scale
	for speed: float in [1.0, 0.25]:
		Engine.time_scale = speed
		for index in range(4):
			var from: int = index * 2
			var to := (from + 4) % DIRECTIONS.size()
			var point := Vector3(-2.5 if index % 2 == 0 else -0.5, 0.0, -14.5)
			point.y = world.ground_surface_y(point)
			world.player.global_position = point
			for _tick in range(5): await physics_frame
			Input.action_press(INPUTS[from][0])
			for _tick in range(108 if speed < 1.0 else 27): await physics_frame
			_check(world.facing == DIRECTIONS[from] and world.last_avatar_source_action == "walk",
				"reversal begins from real travel in %s" % DIRECTIONS[from])
			var previous := world.player.global_position
			var phase := world.walk_distance_phase
			Input.action_release(INPUTS[from][0])
			Input.action_press(INPUTS[to][0])
			var idle_ticks := 0
			var tiny_ticks := 0
			var phase_held := true
			for _tick in range(76 if speed < 1.0 else 20):
				await physics_frame
				var position := world.player.global_position
				var travelled := Vector2(position.x - previous.x, position.z - previous.z).length()
				if travelled > 0.0 and travelled <= ParkWorld.WALK_DISTANCE_EPSILON:
					tiny_ticks += 1
					phase_held = phase_held and world.walk_distance_phase == phase
				if world.last_avatar_action == "idle": idle_ticks += 1
				previous = position
				phase = world.walk_distance_phase
			_check(idle_ticks == 0 and world.facing == DIRECTIONS[to] and world.last_avatar_source_action == "walk",
				"%s to %s at scale %.2f stays in the walk loop (%d idle ticks)" % [DIRECTIONS[from], DIRECTIONS[to], speed, idle_ticks])
			_check(phase_held and (speed == 1.0 or tiny_ticks > 0), "the real reversal preserves stride phase during tiny displacement")
			Input.action_release(INPUTS[to][0])
	Engine.time_scale = original_scale
	for _tick in range(23): await physics_frame

func _check_side_pivot(world: ParkWorld) -> void:
	var original_scale := Engine.time_scale
	for speed: float in [1.0, 0.25]:
		Engine.time_scale = speed
		for left_to_right: bool in [true, false]:
			var point := Vector3(-2.5 if left_to_right else -0.5, 0.0, -14.5)
			point.y = world.ground_surface_y(point)
			world.player.global_position = point
			for _tick in range(5): await physics_frame
			var start := "left" if left_to_right else "right"
			var goal := "right" if left_to_right else "left"
			Input.action_press("move_" + start)
			var approach_ticks := 27 if left_to_right else 24
			for _tick in range(approach_ticks * (4 if speed < 1.0 else 1)): await physics_frame
			Input.action_release("move_" + start)
			Input.action_press("move_" + goal)
			var headings: Array[String] = []
			for _tick in range(88 if speed < 1.0 else 23):
				await physics_frame
				if world._avatar_pivot_remaining <= 0.0: continue
				var direction := world.last_avatar_direction
				if headings.is_empty() or headings[-1] != direction: headings.append(direction)
				var expected_action := "depart" if direction == "back_left" else "pivot"
				var expected: Texture2D = world.avatar_renderer.texture(world.avatar_appearance, world.avatar_equipped, direction, 0, expected_action)
				_check(world.last_avatar_action == "walk" and world.avatar.texture == expected,
					"side pivot uses the full source cel while physics continues")
			var expected_headings := ["back_left", "back", "back_right"] if left_to_right else ["back_right", "back", "back_left"]
			_check(headings == expected_headings and world.facing == goal and world.last_avatar_source_action == "walk",
				"%s to %s at scale %.2f plays the three pivot poses then resumes travel, observed %s" % [start, goal, speed, headings])
			Input.action_release("move_" + goal)
	Engine.time_scale = original_scale
	for _tick in range(23): await physics_frame

func _check_camera_idle(world: ParkWorld) -> void:
	world.facing = "front"
	world._refresh_avatar_texture(0)
	world.time = world._avatar_idle_started_at + ParkWorld.AVATAR_CAMERA_IDLE_DELAY - 0.2
	for _tick in range(3): await physics_frame
	_check(world.last_avatar_action == "idle", "the camera check does not interrupt the ordinary early idle")
	world.blocked = true
	world.time = world._avatar_idle_started_at + ParkWorld.AVATAR_CAMERA_IDLE_DELAY
	for _tick in range(3): await physics_frame
	_check(world.last_avatar_action == "idle", "blocking the world prevents the idle camera check from starting")
	world.blocked = false
	for _tick in range(3): await physics_frame
	_check(world.last_avatar_source_action == ParkWorld.AVATAR_CAMERA_IDLE_ACTION and world.facing == "front", "a long front idle starts the authored camera check")
	var held_elapsed := world.avatar_action_elapsed
	world.blocked = true
	for _tick in range(3): await physics_frame
	_check(world.avatar_action_elapsed == held_elapsed, "the camera check holds its pose while blocked")
	world.blocked = false
	world.apply_settings({"reduced_motion": true})
	_check(world.last_avatar_action == "idle" and world.last_avatar_frame == 0 and world.avatar_action_remaining == 0.0, "reduced motion cancels the cosmetic cue at neutral")
	world.apply_settings({"reduced_motion": false})
	_check(world.last_avatar_action == "idle", "reenabling motion does not resume a discarded camera pose")

	world.time = world._avatar_idle_started_at + ParkWorld.AVATAR_CAMERA_IDLE_DELAY
	for _tick in range(3): await physics_frame
	world.play_action("wave")
	_check(world.last_avatar_source_action == "wave", "a manual gesture overrides the camera check")
	world.avatar_action_remaining = 0.0
	world._refresh_avatar_texture(0)
	world.time = world._avatar_idle_started_at + ParkWorld.AVATAR_CAMERA_IDLE_DELAY
	for _tick in range(3): await physics_frame
	var position := world.player.global_position
	var seen := {}
	for _tick in range(60):
		if world.last_avatar_source_action == ParkWorld.AVATAR_CAMERA_IDLE_ACTION:
			seen[world.last_avatar_frame] = true
		await physics_frame
	_check(seen.size() == 3 and world.last_avatar_action == "idle", "camera check displays its three cels once before returning to idle")
	_check(world.player.global_position.is_equal_approx(position), "automatic idle animation does not move the player")
	var original_library: RefCounted = world.avatar_renderer.animation_library
	var incomplete: RefCounted = original_library.get_script().new()
	var frames: Array = incomplete.manifest.actors.traveller.idle_gesture.front.frames
	frames.back().source = "res://assets/characters/missing-camera-check.png"
	world.avatar_renderer.animation_library = incomplete
	world.time = world._avatar_idle_started_at + ParkWorld.AVATAR_CAMERA_IDLE_DELAY
	for _tick in range(3): await physics_frame
	_check(not world._avatar_camera_idle_available and world.last_avatar_action == "idle", "a missing last cel disables the whole optional gesture")
	world.avatar_renderer.animation_library = original_library

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
