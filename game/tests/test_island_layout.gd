extends SceneTree

const Motion = preload("res://game/world/npc_walk_motion.gd")

var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running island layout checks.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var world_script := load("res://game/world/park_world.gd") as GDScript
	if world_script == null or not world_script.can_instantiate():
		push_error("ParkWorld failed to compile for island layout checks.")
		quit(1)
		return
	var world: Node = world_script.new()
	root.add_child(world)
	await process_frame
	var paving_material: Material = world.call("_coastal_surface",0,7.5,Color("#b9b5a8"))
	_check(paving_material is ShaderMaterial, "walkways use the tiled coastal material shader when the atlas is available")
	_check(world.coastal_atlas != null and world.coastal_atlas.get_width() == 1774, "the authored 4x2 coastal swatch atlas loads as source texture data")
	_check(world.environment.tonemap_exposure < 0.9 and world.environment.ambient_light_energy < 1.0, "noon fill and exposure preserve albedo contrast")
	var projected_player: Vector2 = world.camera.unproject_position(world.player.global_position)
	var player_screen_y: float = projected_player.y / world.get_viewport().get_visible_rect().size.y
	_check(player_screen_y > 0.47 and player_screen_y < 0.61, "camera places the avatar's ground point near the lower center instead of under the prompt")
	_check(world.shoreline_rock_count <= 30, "shoreline rocks use separated clusters rather than a continuous perimeter row")
	var game_points: Dictionary = {}
	for point in world.points:
		var point_id := String(point.get("id", ""))
		if point_id.begins_with("game-"):
			game_points[point_id] = point.get("position")
	_check(game_points.size() == 12, "all twelve stable game point IDs remain registered")
	var positions: Array[Vector3] = []
	for index in range(12):
		var point_id := "game-%03d" % (index + 1)
		var position: Vector3 = game_points.get(point_id, Vector3.INF)
		positions.append(position)
		_check(position.x != INF, "%s has a placed point" % point_id)
	_check(_spatial_spread(positions), "game locations occupy distinct side courts and elevations rather than a repeated two-column row")
	_check(world._point_by_id("guide").size() > 0, "welcome guide point remains registered")
	_check(world._point_by_id("quest-001").size() > 0 and world._point_by_id("quest-002").size() > 0, "both story quest points remain registered")
	for point_id in ["arrival", "album", "settings", "clock", "explore-001", "explore-002", "explore-003", "rift"]:
		_check(world._point_by_id(point_id).size() > 0, "%s remains registered" % point_id)
	var zones: Array = world.park_data().get("zones", [])
	for zone_index in range(1, zones.size()):
		var gate_id := "gate:" + str(zones[zone_index].get("id", ""))
		_check(world._point_by_id(gate_id).size() > 0, "%s gate remains registered" % gate_id)
	for npc_role in ["ticket", "imp", "announcer"]:
		_check(not world._npc_record_for_role(npc_role).is_empty(), "%s character remains in the world" % npc_role)
	var announcer_record: Dictionary = world._npc_record_for_role("announcer")
	var announcer_root := announcer_record.get("activity_root") as Node3D
	var announcer_activity_record: Dictionary={}
	for activity_record in world.npc_activity._records:
		if String(activity_record.role)=="announcer":
			announcer_activity_record=activity_record
			break
	var authored_anchor: Vector3=announcer_activity_record.get("baseline_anchor_position",Vector3.INF)
	var announcer_route_origin: Vector3=announcer_root.get_parent().to_global(authored_anchor) if is_instance_valid(announcer_root) and not announcer_activity_record.is_empty() else Vector3.INF
	_check(Vector2(announcer_route_origin.x-3.4,announcer_route_origin.z+4.0).length()<0.01, "announcer authored route remains in the open center-plaza foreground")
	var announcer_route_clear := true
	for route_x in [announcer_route_origin.x-0.6,announcer_route_origin.x,announcer_route_origin.x+0.6]:
		for lamp in world.lamps:
			var horizontal_clearance := Vector2(route_x-lamp.global_position.x,announcer_route_origin.z-lamp.global_position.z).length()
			if horizontal_clearance<2.6: announcer_route_clear=false
	_check(announcer_route_clear, "announcer side-step route stays clear of plaza flower lamps")
	await physics_frame
	var announcer_live_position: Vector3=announcer_root.global_position if is_instance_valid(announcer_root) else Vector3.INF
	_check(absf(announcer_live_position.x-announcer_route_origin.x)<=0.61 and absf(announcer_live_position.z-announcer_route_origin.z)<0.01, "announcer live root remains within its authored lateral route and fixed Z")
	var announcer_motion: Variant=announcer_activity_record.get("motion")
	var announcer_sprite := announcer_record.get("sprite") as Sprite3D
	_check(is_instance_valid(announcer_motion) and announcer_motion.supported, "announcer measured motion adapter remains available for projected-foot checks")
	if is_instance_valid(announcer_motion) and announcer_sprite!=null:
		for route_x in [announcer_route_origin.x-0.6,announcer_route_origin.x,announcer_route_origin.x+0.6]:
			_check_projected_npc_feet(world,announcer_motion,announcer_sprite,Vector3(route_x,announcer_route_origin.y,announcer_route_origin.z),"announcer full route x=%.2f" % route_x)
		var announcer_rig: Node=announcer_motion.rig
		if is_instance_valid(announcer_rig):
			for foot_index in range(announcer_rig.foot_world.size()):
				var foot: Vector3=announcer_rig.foot_world[foot_index]
				_check(foot.y+0.002>=world._ground_surface_y(foot),"announcer live gait foot %d clears its actual sampled terrain" % foot_index)
	_check(Vector2(announcer_route_origin.x-9.0,announcer_route_origin.z+5.0).length()>5.0, "announcer full authored route remains visually separate from the day/night clock")
	# Probe lateral clearance at authored surface heights. This does not prove a
	# character can climb a ramp; the actual physics traversal below checks that.
	for index in range(12):
		var point_id := "game-%03d" % (index + 1)
		var position: Vector3 = game_points.get(point_id, Vector3.ZERO)
		var step_direction := -1.0 if position.x > 0.0 else 1.0
		var target_x := 4.1 if step_direction < 0.0 else -4.1
		var clear_route := true
		while absf(target_x - position.x) > 0.12:
			var step := minf(0.22, absf(target_x - position.x)) * step_direction
			var surface_y: float = world._ground_surface_y(position) + 0.3
			var transform := Transform3D(world.player.global_basis, Vector3(position.x, surface_y, position.z))
			if world.player.test_move(transform, Vector3(step, 0.0, 0.0)):
				clear_route = false
				break
			position.x += step
		_check(clear_route, "%s has a physically clear approach to the central promenade" % point_id)
	for quest_id in ["quest-001", "quest-002"]:
		var quest_position: Vector3 = world._point_by_id(quest_id).get("position", Vector3.INF)
		var quest_transform := Transform3D(world.player.global_basis, quest_position + Vector3(0.0,0.3,0.0))
		_check(quest_position.is_finite() and quest_position.z > -11.0, "%s character stands in front of the avenue arch beam" % quest_id)
		_check(not world.player.test_move(quest_transform, Vector3(0.0, 0.0, 0.7)), "%s character talking space remains open" % quest_id)
	var landmark_count := 0
	for node in world.find_children("*", "Node3D", true, false):
		if String(node.name).begins_with("GameFeature"):
			landmark_count += 1
	_check(landmark_count == 12, "every game point has a distinct themed landmark instead of only a floating marker")
	_check(world._point_by_id("ride-tide").size() > 0, "ride point remains part of the island layout")
	var districts := world.get_node_or_null("AttractionDistricts")
	_check(districts != null, "the avenue is replaced with authored attraction destinations")
	if districts != null:
		_check(districts.get_child_count() == 4, "four attraction districts establish distinct destinations")
		var seen_ids: Dictionary = {}
		for district in districts.get_children():
			var ids: Variant = district.get_meta("game_ids", [])
			_check(ids is Array and ids.size() >= 2, "%s has activities associated with it" % district.name)
			if ids is Array:
				for point_id in ids:
					seen_ids[String(point_id)] = true
		_check(seen_ids.size() == 12, "all stable game IDs are assigned to a district")
	_check(_has_semantic_landmarks(world), "the island retains named authored landmark silhouettes")
	var distant_labels_are_limited := true
	for label in world.find_children("*", "Label3D", true, false):
		if label.visibility_range_end > 34.01:
			distant_labels_are_limited = false
	_check(distant_labels_are_limited, "park names and attraction signs are range-limited instead of filling distant sightlines")
	world.player.position=Vector3(6.2,0.35,-36.2)
	for i in 12: await physics_frame
	var right:=InputEventKey.new()
	right.keycode=KEY_D; right.physical_keycode=KEY_D; right.pressed=true
	Input.parse_input_event(right); Input.flush_buffered_events()
	# Budget the measured distance at the configured 2 m/s jog, then include the
	# 0.16 s acceleration and 40 frames for continuous ramp/deck contact settling.
	var climb_ticks := ceili((10.2-world.player.position.x)/world_script.AVATAR_RUN_SPEED*60.0)+ceili(world_script.AVATAR_ACCELERATION_SECONDS*60.0)+40
	for i in climb_ticks: await physics_frame
	right=InputEventKey.new()
	right.keycode=KEY_D; right.physical_keycode=KEY_D; right.pressed=false
	Input.parse_input_event(right); Input.flush_buffered_events()
	await physics_frame
	_check(world.player.position.x>10.2 and world.player.position.y>0.43,"real physics walking climbs continuously from lawn onto lookout deck without a vertical ledge (reached x=%.2f y=%.2f after %d jog ticks)" % [world.player.position.x,world.player.position.y,climb_ticks])
	world.queue_free()
	await process_frame
	_finish()

func _spatial_spread(positions: Array[Vector3]) -> bool:
	if positions.size() != 12:
		return false
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var left_count := 0
	var right_count := 0
	var unique_cells: Dictionary = {}
	for position in positions:
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
		min_z = minf(min_z, position.z)
		max_z = maxf(max_z, position.z)
		left_count += 1 if position.x < -0.1 else 0
		right_count += 1 if position.x > 0.1 else 0
		unique_cells[Vector2i(roundi(position.x / 3.0), roundi(position.z / 3.0))] = true
	return max_x - min_x >= 18.0 and max_z - min_z >= 20.0 and left_count >= 3 and right_count >= 6 and unique_cells.size() >= 8

func _has_semantic_landmarks(districts: Node) -> bool:
	var names: Array[String] = []
	for node in districts.find_children("*", "Node", true, false):
		names.append(String(node.name))
	for landmark in ["TideBoardwalkDeck", "TidepoolCourt", "CoastalLookoutDeck", "MoonshadowStage"]:
		if not names.has(landmark):
			return false
	return true

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _check_projected_npc_feet(world: Node, motion: Variant, sprite: Sprite3D, root_position: Vector3, label: String) -> void:
	var samples: PackedVector2Array=motion._build_foot_samples(sprite.texture)
	var camera := world.camera as Camera3D
	var camera_up := camera.global_basis.y.normalized()
	var camera_right := camera.global_basis.x.normalized()
	var ground_y: float=world._ground_surface_y(root_position)
	var foot_offset: float=(float(Motion.ACTIVITY_FEET_ROW)-float(Motion.ACTIVITY_CANVAS_SIZE.y)*0.5)*sprite.pixel_size
	var clearance := 0.0
	for sample in samples:
		var point := Vector3(root_position.x,ground_y,root_position.z)+camera_up*(foot_offset+sample.y*sprite.pixel_size)+camera_right*(sample.x*sprite.pixel_size)
		clearance=maxf(clearance,world._ground_surface_y(point)-point.y+Motion.FOOT_GUARD_PIXELS*sprite.pixel_size)
	clearance=maxf(0.0,clearance)
	var visible_origin := Vector3(root_position.x,ground_y,root_position.z)+camera_up*foot_offset+Vector3(0.0,sprite.pixel_size+clearance,0.0)
	for sample in samples:
		var visible_foot := visible_origin+camera_up*(sample.y*sprite.pixel_size)+camera_right*(sample.x*sprite.pixel_size)
		_check(visible_foot.y+0.00001>=world._ground_surface_y(visible_foot),"%s projected source-foot sample clears terrain" % label)
	_check(not samples.is_empty(),"%s checks nonempty alpha-visible source-foot geometry" % label)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: island layout contracts")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
