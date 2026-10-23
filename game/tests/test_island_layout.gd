extends SceneTree

const NpcActivity = preload("res://game/world/npc_activity.gd")

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
	_check(not is_instance_valid(announcer_motion) and announcer_sprite != null and announcer_sprite.visible, "announcer production route uses its complete authored sprite without allocating the rejected gait adapter")
	if announcer_sprite != null and is_instance_valid(announcer_root):
		var previous_position := announcer_root.global_position
		world.npc_activity.set_activity_paused(true)
		for route_x in [announcer_route_origin.x-0.6,announcer_route_origin.x,announcer_route_origin.x+0.6]:
			announcer_root.global_position = Vector3(route_x, previous_position.y, announcer_route_origin.z)
			world._update_sprite_grounding()
			_check_projected_npc_feet(world,announcer_sprite,"announcer full route x=%.2f" % route_x)
		var original_sprite_position := announcer_sprite.position
		announcer_sprite.position.y -= 0.2
		_check(_source_foot_clearance(world,announcer_sprite).get("minimum", INF) < 0.0, "projected-foot check rejects an intentionally submerged actual sprite")
		announcer_sprite.position = original_sprite_position
		announcer_root.global_position = previous_position
		world._update_sprite_grounding()
		world.npc_activity.set_activity_paused(false)
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
	_check_wayfinding(world)
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
	_check(world.player.floor_constant_speed,"avatar keeps its ground speed on ramps instead of slowing uphill")
	# Budget the measured distance at the configured default pace, then include the
	# 0.16 s acceleration and 40 frames for continuous ramp/deck contact settling.
	var climb_ticks := ceili((10.2-world.player.position.x)/world_script.AVATAR_RUN_SPEED*60.0)+ceili(world_script.AVATAR_ACCELERATION_SECONDS*60.0)+40
	for i in climb_ticks: await physics_frame
	right=InputEventKey.new()
	right.keycode=KEY_D; right.physical_keycode=KEY_D; right.pressed=false
	Input.parse_input_event(right); Input.flush_buffered_events()
	await physics_frame
	_check(world.player.position.x>10.2 and world.player.position.y>0.43,"real physics walking climbs continuously from lawn onto lookout deck without a vertical ledge (reached x=%.2f y=%.2f after %d jog ticks)" % [world.player.position.x,world.player.position.y,climb_ticks])
	await _check_coastal_extension(world)
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

func _check_projected_npc_feet(world: Node, sprite: Sprite3D, label: String) -> void:
	var measured := _source_foot_clearance(world,sprite)
	_check(int(measured.samples) > 0,"%s checks nonempty alpha-visible source-foot geometry" % label)
	_check(float(measured.minimum) >= -0.00001,"%s actual projected source-foot samples clear terrain" % label)

func _source_foot_clearance(world: Node, sprite: Sprite3D) -> Dictionary:
	var image := sprite.texture.get_image() if sprite.texture != null else null
	var result := {"samples": 0, "minimum": INF}
	if image == null or image.is_empty(): return result
	_check(image.get_size() == NpcActivity.ACTION_CANVAS_SIZE, "announcer visible source retains the complete registered canvas")
	var camera := world.camera as Camera3D
	var camera_up := camera.global_basis.y.normalized()
	var camera_right := camera.global_basis.x.normalized()
	for x in range(image.get_width()):
		for y in range(maxi(0,NpcActivity.ACTION_FEET_ROW-8),image.get_height()):
			if image.get_pixel(x,y).a < 0.5: continue
			var pixel := Vector2(float(x)+0.5-float(image.get_width())*0.5,float(image.get_height())*0.5-float(y)-0.5)
			var visible_foot := sprite.global_position+(camera_right*pixel.x+camera_up*pixel.y)*sprite.pixel_size
			result.samples += 1
			result.minimum = minf(float(result.minimum),visible_foot.y-world._ground_surface_y(visible_foot))
	return result

func _finish() -> void:
	if failures.is_empty():
		print("PASS: island layout contracts")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

## Signposts are solid landmarks at each fork, leave walking room on both sides,
## and every direction shows a status line once progress is applied.
func _check_wayfinding(world: Node) -> void:
	var landmarks: Node = world.story_landmarks
	_check(landmarks != null, "story landmarks are built into the island")
	if landmarks == null: return
	world.set_story_progress({"story_photo": false, "steps": {"quest-001": 0, "quest-002": 0}, "next_steps": {}, "photos": {}})
	var report: Array = landmarks.signpost_report()
	_check(report.size() == 3, "three wayfinding signposts stand at the dock, plaza and avenue forks")
	var bounds: Rect2 = preload("res://game/world/coastal_circuit.gd").WALK_BOUNDS
	for record in report:
		var base: Vector3 = record.position
		_check(bounds.has_point(Vector2(base.x, base.z)), "%s signpost stands inside the walkable island" % record.id)
		for line in record.lines:
			_check(str(line).split("　").size() == 2 and not str(line).split("　")[1].strip_edges().is_empty(), "%s direction shows a live status: %s" % [record.id, line])
		_check(str(record.label_text) == "\n".join(record.lines) and (record.lines as Array).size() >= 2, "%s billboard shows every direction on its own line" % record.id)
		var facing := Transform3D(world.player.global_basis, base + Vector3(0.0, 0.35, 0.9))
		_check(world.player.test_move(facing, Vector3(0.0, 0.0, -1.2)), "%s signpost is a solid landmark, not a floating label" % record.id)
		for side in [-1.15, 1.15]:
			var beside := Transform3D(world.player.global_basis, base + Vector3(side, 0.35, 1.2))
			_check(not world.player.test_move(beside, Vector3(0.0, 0.0, -2.0)), "%s signpost leaves walking room on side %.2f" % [record.id, side])
	var outcomes: Dictionary = landmarks.outcome_state()
	_check(not outcomes.ribbon_visible and not outcomes.entry_sign_corrected, "unfinished requests leave the arch and entry sign unchanged")
	world.set_story_progress({"story_photo": true, "steps": {"quest-001": 3, "quest-002": 3}, "next_steps": {}, "photos": {}})
	outcomes = landmarks.outcome_state()
	_check(outcomes.ribbon_visible and outcomes.entry_sign_corrected, "finished requests show the ribbon garland and corrected entry sign")
	for quest_id in ["quest-001", "quest-002"]:
		var quest_position: Vector3 = world._point_by_id(quest_id).get("position", Vector3.INF)
		var quest_transform := Transform3D(world.player.global_basis, quest_position + Vector3(0.0,0.3,0.0))
		_check(not world.player.test_move(quest_transform, Vector3(0.0, 0.0, 0.7)), "%s talking space stays open beside the story props" % quest_id)
	world.set_story_progress({"story_photo": false, "steps": {"quest-001": 0, "quest-002": 0}, "next_steps": {}, "photos": {}})

func _check_coastal_extension(world: Node) -> void:
	_check_coastal_clearance(world)
	var scenic_ids := ["sail-loft","storm-bell","lighthouse","star-court","glass-garden","tide-wheel"]
	for stop_id in scenic_ids:
		var point: Dictionary = world._point_by_id("coast:"+stop_id)
		_check(not point.is_empty(), "%s has a reachable discovery plaque" % stop_id)
		if point.is_empty(): continue
		var p: Vector3 = point.position
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*6,p-Vector3.UP*2,1)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() and absf((hit.get("position",Vector3.INF) as Vector3).y-0.2)<0.025, "%s has actual walkable ground under the plaque, rather than water or an overhead blocker" % stop_id)
		_check(str(world.coast_description("coast:"+stop_id).get("text","")).length()>20, "%s has its own readable observation" % stop_id)
	for ground_point in [Vector3(-22,0,-27),Vector3(21,0,-38)]:
		_check(is_equal_approx(world._ground_surface_y(ground_point),0.18), "mid-route return path keeps sprite soles on the visible paving at %s" % ground_point)
	world.player.position=Vector3(-18.1,0.35,-27)
	world.player.velocity=Vector3.ZERO
	for index in 3: await physics_frame
	Input.action_press("move_left")
	for index in 45: await physics_frame
	Input.action_release("move_left")
	_check(world.player.position.x < -19.0 and world.player.is_on_floor(), "real movement crosses the old west map clamp onto the coastal connector")
	world.player.position=Vector3(0,0.35,-43.1)
	world.player.velocity=Vector3.ZERO
	Input.action_press("move_up")
	for index in 45: await physics_frame
	Input.action_release("move_up")
	_check(world.player.position.z < -44.0 and world.player.is_on_floor(), "real movement crosses the old north map clamp without falling or respawning")
	world.player.position=Vector3(-27,0.35,-45)
	world.set_time_of_day("night")
	_check(world.lamps.any(func(lamp: Light3D): return lamp.position.distance_to(world.player.position)<8 and lamp.light_energy>0), "the distant lighthouse trail has a real active night light")
	_check(world.active_lamp_indices.size()==world.ACTIVE_LAMP_LIMIT and world.shadow_lamp_indices.size()==world.SHADOW_LAMP_LIMIT, "larger map retains the bounded active light/shadow budget")
	var rotor: Node3D = world.get_node_or_null("CoastalWaterwheelRotor")
	_check(rotor!=null, "waterwheel has its own assembled rotor")
	if rotor!=null:
		world.blocked=false
		world.reduced_motion=false
		var before:=rotor.rotation.z
		world._process(0.2)
		_check(rotor.rotation.z>before, "unpaused waterwheel turns around its axle")
		world.reduced_motion=true
		before=rotor.rotation.z
		world._process(0.2)
		_check(is_equal_approx(rotor.rotation.z,before), "reduced motion freezes the waterwheel without changing its shape")

func _check_coastal_clearance(world: Node) -> void:
	var circuit := preload("res://game/world/coastal_circuit.gd")
	var clear := true
	for index in range(circuit.ROUTE.size()-1):
		var a: Vector2 = circuit.ROUTE[index]
		var b: Vector2 = circuit.ROUTE[index+1]
		var tangent := (b-a).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		for sample in range(ceili(a.distance_to(b)*2.0)):
			for offset in [-0.8,0.0,0.8]:
				var p := a+tangent*minf(float(sample)*0.5,a.distance_to(b))+normal*float(offset)
				var transform := Transform3D(Basis.IDENTITY,Vector3(p.x,0.35,p.y))
				if world.player.test_move(transform,Vector3(tangent.x,0,tangent.y)*0.2):
					clear=false
					_check(false,"coastal trail corridor blocked near %s offset %.1f" % [p,offset])
	_check(clear,"actual player capsule clears the whole coastal trail with lateral walking room")
