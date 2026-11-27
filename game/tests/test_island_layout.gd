extends SceneTree

const NpcActivity = preload("res://game/world/npc_activity.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const IslandLayout = preload("res://game/world/island_layout.gd")
const IslandScenery = preload("res://game/world/island_scenery.gd")
const CoastalCircuit = preload("res://game/world/coastal_circuit.gd")
const IslandMapPanel = preload("res://game/ui/island_map_panel.gd")

## Scene budget for the Welcome island (design/runtime/scene-building-standards.md).
const NODE_BUDGET := 2600
## Nodes that exist only with a GPU (air particles, cloud shade, hair viewport
## parts); this headless count must leave room for them.
const GPU_ONLY_NODES := 60

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
	_check_welcome_water(world)
	_check_ground_layers(world)
	_check_ferry(world)
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
	_check(_spatial_spread(positions), "game entries are spread across the whole island, each in a place of its own")
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
	_check_reachability(world)
	for quest_id in ["quest-001", "quest-002"]:
		var quest_position: Vector3 = world._point_by_id(quest_id).get("position", Vector3.INF)
		var quest_transform := Transform3D(world.player.global_basis, quest_position + Vector3(0.0,0.3,0.0))
		_check(quest_position.is_finite() and quest_position.z > -11.0, "%s character stands in front of the avenue arch beam" % quest_id)
		_check(not world.player.test_move(quest_transform, Vector3(0.0, 0.0, 0.7)), "%s character talking space remains open" % quest_id)
	_check_wayfinding(world)
	_check_illuminated_guides(world)
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
	var lookout_start := IslandLayout.district_point("lookout", Vector3(6.2,0.35,-36.2))
	var lookout_top_x := IslandLayout.district_point("lookout", Vector3(10.2,0,0)).x
	world.player.position=lookout_start
	for i in 12: await physics_frame
	var right:=InputEventKey.new()
	right.keycode=KEY_D; right.physical_keycode=KEY_D; right.pressed=true
	Input.parse_input_event(right); Input.flush_buffered_events()
	_check(world.player.floor_constant_speed,"avatar keeps its ground speed on ramps instead of slowing uphill")
	# Budget the measured distance at the configured default pace, then include the
	# 0.16 s acceleration and 40 frames for continuous ramp/deck contact settling.
	var climb_ticks := ceili((lookout_top_x-world.player.position.x)/world_script.AVATAR_RUN_SPEED*60.0)+ceili(world_script.AVATAR_ACCELERATION_SECONDS*60.0)+40
	for i in climb_ticks: await physics_frame
	right=InputEventKey.new()
	right.keycode=KEY_D; right.physical_keycode=KEY_D; right.pressed=false
	Input.parse_input_event(right); Input.flush_buffered_events()
	await physics_frame
	_check(world.player.position.x>lookout_top_x and world.player.position.y>0.43,"real physics walking climbs continuously from lawn onto lookout deck without a vertical ledge (reached x=%.2f y=%.2f after %d jog ticks)" % [world.player.position.x,world.player.position.y,climb_ticks])
	# Character and arrival markers float above head height so they never cover a face.
	var character_sprite_height := 2.4
	for point_id in ["arrival", "guide", "quest-001", "quest-002"]:
		var marker_point: Dictionary = {}
		for point in world.points:
			if str(point.get("id", "")) == point_id: marker_point = point
		var marker := marker_point.get("marker") as Label3D
		_check(marker != null and marker.global_position.y - Vector3(marker_point.position).y > character_sprite_height + 0.3, "%s marker clears the character's head" % point_id)
	await _check_coastal_extension(world)
	_check_map_chart(world)
	var nodes: int = world.find_children("*", "Node", true, false).size() + 1
	_check(nodes + GPU_ONLY_NODES <= NODE_BUDGET, "the larger island stays inside the Welcome node budget (%d headless, %d allowed with a GPU)" % [nodes, NODE_BUDGET])
	world.queue_free()
	await process_frame
	_finish()

func _spatial_spread(positions: Array[Vector3]) -> bool:
	if positions.size() != 12:
		return false
	var extent := Rect2(Vector2(positions[0].x, positions[0].z), Vector2.ZERO)
	var nearest := INF
	var places := {}
	for index in positions.size():
		var spot := Vector2(positions[index].x, positions[index].z)
		extent = extent.expand(spot)
		places[IslandShape.area_at(spot)] = true
		_check(IslandShape.area_at(spot) == str(IslandLayout.GAME_ENTRIES[index].place), "game-%03d stands in the place its table row names" % (index + 1))
		for other in range(index + 1, positions.size()):
			nearest = minf(nearest, spot.distance_to(Vector2(positions[other].x, positions[other].z)))
	_check(nearest >= IslandLayout.MIN_ENTRY_SPACING, "any two game entries stand at least %.0f m apart (nearest pair %.1f m)" % [IslandLayout.MIN_ENTRY_SPACING, nearest])
	_check(places.size() == 12, "every game entry stands in a differently named place (%d names)" % places.size())
	# Counter-example: the former avenue packed all twelve into about 24 x 24 m.
	return extent.size.x >= 100.0 and extent.size.y >= 80.0

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
func _check_welcome_water(world: Node) -> void:
	var bay := world.get_node_or_null("WelcomeBayWater") as MeshInstance3D
	_check(bay != null and bay.mesh is PlaneMesh, "the Welcome bay remains a single sea plane")
	if bay == null or not bay.mesh is PlaneMesh:
		return
	var material := bay.material_override as ShaderMaterial
	_check(material != null and material.shader != null and material == world.welcome_sea_material and material != world.sea_material
		and material.shader.resource_path.ends_with("/welcome_bay_water.gdshader"),
		"shore effects use a shader specific to the outdoor Welcome bay")
	if material == null or material.shader == null:
		return
	_check(bay.mesh.size == IslandScenery.SEA_SIZE and bay.mesh.get_surface_count() == 1
		and is_equal_approx(bay.position.y, IslandScenery.SEA_Y), "one sea draw at the existing water level")
	var sea := Rect2(Vector2(bay.position.x, bay.position.z) - bay.mesh.size * 0.5, bay.mesh.size)
	_check(sea.grow(-60.0).encloses(IslandShape.bounds()), "the sea reaches well past every shore, so no view from the island shows its edge")
	_check(material.get_shader_parameter("shore_distance") == IslandShape.sdf_texture()
		and material.get_shader_parameter("sdf_origin") == IslandShape.sdf_origin()
		and material.get_shader_parameter("sdf_inverse_size") == IslandShape.sdf_inverse_size()
		and material.get_shader_parameter("dock_center") == Vector2(0, 21)
		and material.get_shader_parameter("dock_half_size") == Vector2(2.5, 6.5),
		"surf and shallows are measured from the island's real coastline and the dock")
	_check(not material.shader.code.contains("land_half_size"), "the bay no longer assumes a rectangular island")
	var pools := 0
	var sea_draws := 0
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override == world.sea_material and mesh.mesh is CylinderMesh: pools += 1
		if mesh.material_override == material: sea_draws += 1
	_check(sea_draws == 1 and pools == 5 + IslandLayout.PONDS.size() and world.sea_material.shader == world.fountain_water.shader,
		"four pools, the bubbler, the ponds and the fountain keep the original shared water shader")
	var initial_phase: String = world.active_time_phase
	var initial_motion: bool = world.reduced_motion
	world.set_time_of_day("noon")
	_check(is_zero_approx(float(material.get_shader_parameter("dock_glow"))),
		"noon contributes no artificial dock glints")
	world.set_time_of_day("dusk")
	var dusk_glow: float = material.get_shader_parameter("dock_glow")
	world.set_time_of_day("night")
	_check(dusk_glow > 0.0 and float(material.get_shader_parameter("dock_glow")) > dusk_glow,
		"local reflected illumination follows the existing night and dusk lamp budget")
	for reduced: bool in [true, false]:
		world.apply_settings({"reduced_motion":reduced})
		var expected := 0.0 if reduced else 1.0
		_check(float(material.get_shader_parameter("motion")) == expected
			and float(world.sea_material.get_shader_parameter("motion")) == expected
			and float(world.fountain_water.get_shader_parameter("motion")) == expected,
			"changing motion settings reaches the bay, pool, and fountain material")
	world.set_time_of_day(initial_phase)
	world.apply_settings({"reduced_motion":initial_motion})

## Ground layers nest from the bottom up (water, beach, lawn, paving) along the
## whole coast: the lawn never reaches the water, the beach slopes under it, and
## rocks, walkways and planting each keep to their own layer.
func _check_ground_layers(world: Node) -> void:
	var lawn := world.get_node_or_null("WelcomeLawn") as MeshInstance3D
	var beach := world.get_node_or_null("WelcomeBeach") as MeshInstance3D
	var bay := world.get_node_or_null("WelcomeBayWater") as MeshInstance3D
	_check(lawn != null and beach != null and bay != null, "the Welcome shore keeps separate water, beach and lawn layers")
	if lawn == null or beach == null or bay == null: return
	_check(not beach.mesh is PrimitiveMesh and not lawn.mesh is PrimitiveMesh, "beach and lawn are cut to the coastline, not stock boxes")
	var beach_material := beach.material_override as ShaderMaterial
	_check(beach_material != null and beach_material.get_shader_parameter("shore_distance") == IslandShape.sdf_texture()
		and int(beach_material.get_shader_parameter("beach_count")) == IslandShape.BEACHES.size(), "wet sand and the turf fringe follow the same coastline and beaches")
	# Beach: a flat top just inside the waterline whose rim slopes below the sea.
	var beach_vertices: PackedVector3Array = beach.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var beach_top := -INF
	var beach_foot := INF
	for vertex in beach_vertices:
		beach_top = maxf(beach_top, vertex.y)
		beach_foot = minf(beach_foot, vertex.y)
	_check(is_equal_approx(beach_top, IslandLayout.BEACH_TOP_Y) and beach_top - bay.position.y >= 0.02, "the water surface stays below the beach")
	_check(beach_foot < bay.position.y - 0.1, "the beach slopes under the water instead of ending in a visible edge")
	var top_inside := true
	var foot_wet := true
	for vertex in beach_vertices:
		var shore := IslandShape.distance_to_coast(Vector2(vertex.x, vertex.z))
		if is_equal_approx(vertex.y, beach_top) and shore < 0.3: top_inside = false
		if is_equal_approx(vertex.y, beach_foot) and shore > 0.0: foot_wet = false
	_check(top_inside, "the flat beach keeps inside the waterline all the way round")
	_check(foot_wet, "the foot of the beach slope lies under the sea all the way round")
	# Lawn: a clear step above the sand and never within the sand width of the water.
	_check(lawn.global_position.y - beach_top >= 0.02 and is_equal_approx(world._ground_surface_y(Vector3(20, 0, -10)), lawn.global_position.y), "the lawn sits a clear step above the sand without coplanar flicker")
	var lawn_arrays := lawn.mesh.surface_get_arrays(0)
	var rim: PackedVector3Array = lawn_arrays[Mesh.ARRAY_VERTEX]
	var faces: PackedInt32Array = lawn_arrays[Mesh.ARRAY_INDEX]
	var narrowest_sand := INF
	var loosest := 0.0
	for vertex in rim:
		var point := lawn.to_global(vertex)
		narrowest_sand = minf(narrowest_sand, IslandShape.distance_to_coast(Vector2(point.x, point.z)))
		loosest = maxf(loosest, absf(IslandShape.lawn_inset(Vector2(point.x, point.z))))
	_check(rim.size() > 300 and narrowest_sand >= 0.3 and narrowest_sand >= IslandShape.SAND_WIDTH - 0.25, "grass stops a sand's width short of the water on every shore (narrowest sand %.2f m)" % narrowest_sand)
	_check(loosest <= 0.3, "the drawn lawn edge is the edge planting and ground height rely on (%.2f m apart at worst)" % loosest)
	var facing_up := true
	for index in range(0, faces.size(), 3):
		if (rim[faces[index + 2]] - rim[faces[index]]).cross(rim[faces[index + 1]] - rim[faces[index]]).y <= 0.0: facing_up = false
	_check(faces.size() > 900 and facing_up, "every lawn triangle faces up, so the grass takes sunlight and shadows")
	_check(is_equal_approx(world._ground_surface_y(Vector3(62, 0, -50)), IslandLayout.BEACH_TOP_Y) and is_equal_approx(world._ground_surface_y(Vector3(0, 0, -30)), IslandLayout.PATH_TOP_Y),
		"feet stand on sand at the beach and on paving along the promenade")
	# Counter-examples the old rectangle would have passed.
	_check(IslandShape.distance_to_coast(Vector2(35.9, -29)) > 20.0 and not IslandShape.contains(Vector2(0, -170)), "the old east rim is now deep inland and the far sea is still sea")
	var rocks := world.find_children("ShoreRock*", "Node3D", true, false)
	_check(rocks.size() == world.shoreline_rock_count and rocks.size() >= 12, "every tide-pool rock is a named shoreline prop (%d)" % rocks.size())
	for rock: Node3D in rocks:
		var spot := Vector2(rock.global_position.x, rock.global_position.z)
		_check(IslandShape.distance_to_coast(spot) >= 0.3 and IslandShape.lawn_inset(spot) <= -0.2, "%s rests on sand, clear of both grass and open water" % rock.name)
		_check(world._ground_surface_y(rock.global_position) <= IslandLayout.LAWN_Y + 0.001, "%s is not placed on a paved path or deck" % rock.name)
		var sprite := rock as Sprite3D
		if sprite != null:
			var base := sprite.global_position.y - sprite.pixel_size * sprite.texture.get_height() * 0.5
			_check(absf(base - beach_top) <= 0.05, "%s sits on the sand surface instead of floating or sinking" % rock.name)
	_check_walkways(world)
	_check_planting(world)

## Walkways are curved ribbons that follow the layout's lines and stay on land.
func _check_walkways(world: Node) -> void:
	var ribbons := 0
	for surface: String in IslandScenery.SURFACE_TOP:
		var mesh := world.get_node_or_null("IslandWalkway_" + surface) as MeshInstance3D
		_check(mesh != null and not mesh.mesh is PrimitiveMesh, "%s walkways are one drawn ribbon mesh, not slabs" % surface)
		if mesh == null: continue
		ribbons += 1
		var top := 0.0
		var wet := 0
		for vertex: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, vertex.y)
			if vertex.y > 0.1 and IslandShape.distance_to_coast(Vector2(vertex.x, vertex.z)) < 0.3: wet += 1
		_check(wet == 0, "%s paving stays on land, clear of the waterline (%d vertices too close)" % [surface, wet])
		_check(is_equal_approx(top, float(IslandScenery.SURFACE_TOP[surface])) and top - IslandLayout.LAWN_Y >= 0.02, "%s paving sits a clear step above the lawn" % surface)
	_check(ribbons == 3, "paving, trails and the boardwalk are three draws for the whole island")
	var tops: Array = IslandScenery.SURFACE_TOP.values()
	tops.append(IslandScenery.CLEARING_TOP)
	tops.sort()
	for index in range(1, tops.size()):
		_check(float(tops[index]) - float(tops[index - 1]) >= 0.005, "overlapping walkway layers never share a plane")
	var curved := 0
	var total := 0.0
	for path in IslandLayout.paths():
		var line: PackedVector2Array = path.line
		var length := 0.0
		var turning := 0.0
		var off_paving := 0
		for index in range(1, line.size()):
			length += line[index].distance_to(line[index - 1])
			if index + 1 < line.size():
				turning += absf(angle_difference((line[index] - line[index - 1]).angle(), (line[index + 1] - line[index]).angle()))
			var spot := line[index]
			if world._ground_surface_y(Vector3(spot.x, 0, spot.y)) < IslandLayout.PATH_TOP_Y - 0.04: off_paving += 1
		total += length
		if length > 25.0 and turning > deg_to_rad(25.0): curved += 1
		_check(off_paving == 0, "%s keeps sprite soles on its paving along its whole length (%d samples off)" % [path.id, off_paving])
		_check(length < 25.0 or turning > deg_to_rad(12.0), "%s bends instead of running dead straight (%.0f m, %.0f degrees of turning)" % [path.id, length, rad_to_deg(turning)])
	_check(IslandLayout.paths().size() >= 16 and curved >= 12 and total > 1500.0, "the island has a branching network of curved walkways (%d paths, %d curved, %.0f m)" % [IslandLayout.paths().size(), curved, total])
	var route := IslandLayout.coast_route()
	var hugging := 0
	for spot in route:
		if IslandShape.distance_to_coast(spot) <= 16.0: hugging += 1
	_check(float(hugging) / float(route.size()) >= 0.9, "the coastal loop follows the new shore (%d of %d samples within 16 m of the water)" % [hugging, route.size()])
	_check(world.find_children("*", "MeshInstance3D", true, false).all(func(mesh: MeshInstance3D) -> bool: return not mesh.has_meta("coastal_trail")), "the old box-segment trail is gone")

## Planting keeps off the wet sand line, the walkways and the places: every
## painted plant stands at least 1.5 m from the water and trees on open lawn.
func _check_planting(world: Node) -> void:
	var world_script: GDScript = world.get_script()
	var trees := 0
	var kinds := {}
	for kind in ["oak", "ginkgo", "palm", "pine", "shrub", "planter"]:
		if not world.foliage_textures.has(kind): continue
		for sprite: Sprite3D in world.find_children("*", "Sprite3D", true, false):
			if sprite.texture != world.foliage_textures[kind]: continue
			var height := sprite.pixel_size * sprite.texture.get_height()
			var anchor := sprite.global_position - Vector3(0, height * 0.5, 0)
			_check(IslandShape.distance_to_coast(Vector2(anchor.x, anchor.z)) >= 1.5, "%s at %s keeps 1.5 m back from the waterline" % [kind, anchor])
			if kind in ["shrub", "planter"]: continue
			trees += 1
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			_check(world_script.tree_site_clear(anchor), "%s at %s stands on open lawn, off paths, courts and the beach" % [kind, anchor])
	_check(trees >= 120 and trees <= 190, "groves and path-side trees cover the larger island without crowding it (%d trees)" % trees)
	_check(kinds.size() == 4, "each part of the island has its own canopy (%s)" % str(kinds))
	_check(not world_script.tree_site_clear(Vector3(-2, 0, 22)) and not world_script.tree_site_clear(Vector3(0, 0, -30)) and not world_script.tree_site_clear(Vector3(-41, 0, -30))
		and not world_script.tree_site_clear(Vector3(62, 0, -50)) and not world_script.tree_site_clear(Vector3(-15, 0, -48)) and world_script.tree_site_clear(Vector3(20, 0, -12.5)),
		"the planting rule rejects the bay, a walkway, a pond, a beach and a court, and accepts open lawn")
	for meadow: Vector3 in IslandLayout.MEADOWS:
		_check(IslandShape.on_lawn(Vector2(meadow.x, meadow.y), 2.0), "the meadow at (%.0f, %.0f) lies on the lawn" % [meadow.x, meadow.y])
	for pond: Vector3 in IslandLayout.PONDS:
		_check(IslandShape.on_lawn(Vector2(pond.x, pond.y), pond.z + 1.5), "the pond at (%.0f, %.0f) and its bank lie wholly on the lawn" % [pond.x, pond.y])
	for index in IslandLayout.PONDS.size():
		var water := world.get_node_or_null("IslandPond%d" % index) as MeshInstance3D
		var bank := world.get_node_or_null("IslandPondBank%d" % index) as MeshInstance3D
		_check(water != null and bank != null, "pond %d has water and a bank" % index)
		if water == null or bank == null: continue
		var bank_top := -INF
		for vertex: Vector3 in bank.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			bank_top = maxf(bank_top, vertex.y)
		var water_top := water.position.y + (water.mesh as CylinderMesh).height * 0.5
		_check(bank_top - water_top >= 0.02 and water_top - IslandLayout.LAWN_Y >= 0.02, "pond %d: the bank stands above the water and the lawn never touches it" % index)
	for spot: Vector2 in IslandLayout.PARASOLS:
		_check(IslandShape.contains(spot, 1.5) and IslandShape.lawn_inset(spot) <= -0.8, "the parasol at %s stands on the beach, off the grass and out of the water" % spot)
	for site: Vector2 in IslandLayout.RIDGES:
		var crowded := false
		for step in 12:
			if IslandLayout.on_path(site + Vector2.from_angle(TAU * float(step) / 12.0) * 5.5, 0.5): crowded = true
		for entry: Dictionary in IslandLayout.GAME_ENTRIES:
			if site.distance_to(Vector2(entry.position.x, entry.position.z)) < 10.0: crowded = true
		_check(IslandShape.on_lawn(site, 6.0) and not crowded and not IslandLayout.in_pond(site, 7.0), "the ridge at %s stands on open lawn clear of walkways and places" % site)
	for spot: Vector2 in IslandLayout.LAMPPOSTS + IslandLayout.PLANTERS:
		_check(IslandShape.contains(spot, 2.0) and not IslandLayout.on_path(spot, 0.3) and not IslandLayout.in_pond(spot, 0.8), "the prop at %s stands beside a walkway, not on it" % spot)
	for spot: Vector2 in IslandLayout.BENCHES:
		_check(IslandShape.on_lawn(spot, 2.0) and not IslandLayout.on_path(spot, 1.2) and not IslandLayout.in_pond(spot, 1.6), "the bench at %s stands on the lawn with its whole seat off the walkway" % spot)
	# After dark every game entry has a lamp of its own close by.
	for index in IslandLayout.GAME_ENTRIES.size():
		var entry: Vector3 = IslandLayout.GAME_ENTRIES[index].position
		var nearest := INF
		for lamp: Light3D in world.lamps:
			nearest = minf(nearest, Vector2(lamp.global_position.x - entry.x, lamp.global_position.z - entry.z).length())
		_check(nearest <= 7.0, "game-%03d has a lamp within 7 m for the night (%.1f m)" % [index + 1, nearest])

## Every interaction point can be walked to from the dock: over walkable ground
## with nothing solid in the way, and for destinations along paving alone.
func _check_reachability(world: Node) -> void:
	var bounds := IslandShape.bounds().grow(2.0).expand(IslandLayout.DOCK_WALK.end)
	bounds.position = bounds.position.floor()
	var columns := int(bounds.size.x) + 2
	var rows := int(bounds.size.y) + 2
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	# Fatter than the walker, so a thin post between two cells closes both.
	var body := CapsuleShape3D.new()
	body.radius = 0.6
	body.height = 1.5
	probe.shape = body
	probe.collision_mask = 1
	probe.exclude = [world.player.get_rid()]
	var open := PackedByteArray()
	open.resize(columns * rows)
	var paved := PackedByteArray()
	paved.resize(columns * rows)
	_cell_heights.resize(columns * rows)
	var walkable_cells := 0
	for row in rows:
		for column in columns:
			var spot := bounds.position + Vector2(column, row)
			if not (IslandShape.contains(spot, IslandShape.WALK_MARGIN) or IslandLayout.DOCK_WALK.has_point(spot)): continue
			walkable_cells += 1
			var ground: float = world._ground_surface_y(Vector3(spot.x, 0, spot.y))
			_cell_heights[row * columns + column] = ground
			# Stand the capsule on the visible surface, clear of the floor slab.
			probe.transform = Transform3D(Basis.IDENTITY, Vector3(spot.x, maxf(ground, 0.2) + 0.15 + 0.85, spot.y))
			if not space.intersect_shape(probe, 1).is_empty(): continue
			open[row * columns + column] = 1
			if ground > IslandLayout.LAWN_Y + 0.05: paved[row * columns + column] = 1
	_check(walkable_cells >= 24622, "walkable ground is at least four times the former 6155 m2 (%d m2)" % walkable_cells)
	var start := Vector2i((Vector2(0, 5) - bounds.position).round())
	var reached := _flood(open, columns, rows, start)
	var by_paving := _flood(paved, columns, rows, start)
	var free := 0
	var reachable := 0
	for index in open.size():
		free += open[index]
		reachable += reached[index]
	_check(free > 0 and float(reachable) / float(free) >= 0.985, "nearly all open ground is one connected walk from the plaza (%d of %d m2)" % [reachable, free])
	var zones: Array = world.park_data().get("zones", [])
	var destinations: Array[String] = ["arrival", "guide", "album", "settings", "clock", "quest-001", "quest-002", "explore-001", "explore-002", "explore-003", "rift", "ride-tide", "play:recall"]
	for index in 12: destinations.append("game-%03d" % (index + 1))
	for zone_index in range(1, zones.size()): destinations.append("gate:" + str(zones[zone_index].get("id", "")))
	for stop_id: String in IslandLayout.COAST_STOPS: destinations.append("coast:" + stop_id)
	for index in IslandLayout.WINDMILL_PADS.size(): destinations.append("play:wind-%d" % index)
	_check(destinations.size() == 44, "the walk covers every fixed interaction point (%d)" % destinations.size())
	for point_id in destinations:
		var point: Dictionary = world._point_by_id(point_id)
		_check(not point.is_empty(), "%s is registered" % point_id)
		if point.is_empty(): continue
		var position: Vector3 = point.position
		var spot := Vector2(position.x, position.z)
		_check(IslandLayout.DOCK_WALK.has_point(spot) or IslandShape.contains(spot, IslandShape.WALK_MARGIN + 0.3), "%s lies inside the walkable island with room to spare" % point_id)
		_check(_near(reached, columns, rows, spot - bounds.position, 1.5), "%s can be walked to from the plaza" % point_id)
		_check(_near(by_paving, columns, rows, spot - bounds.position, 3.2), "%s is reached by an unbroken paved way from the plaza" % point_id)
		if point_id.begins_with("gate:"):
			_check(IslandShape.distance_to_coast(spot) <= 16.0 and spot.length() >= 45.0, "%s stands at the island's edge, far from the plaza (%.0f m out, %.0f m from the water)" % [point_id, spot.length(), IslandShape.distance_to_coast(spot)])
	# Counter-examples: open sea and a pond are never reached.
	_check(not _near(reached, columns, rows, Vector2(0, -175) - bounds.position, 1.5) and not _near(reached, columns, rows, Vector2(-41, -30) - bounds.position, 1.5), "the walk does not cross open water or a pond")
	# The lookout deck is a ledge: the only way up is its ramp from the west.
	var deck_cell := Vector2i((Vector2(IslandLayout.GAME_ENTRIES[9].position.x, IslandLayout.GAME_ENTRIES[9].position.z) - bounds.position).round())
	var beside_cell := deck_cell + Vector2i(0, -3)
	_check(open[beside_cell.y * columns + beside_cell.x] == 1 and absf(_cell_heights[beside_cell.y * columns + beside_cell.x] - _cell_heights[deck_cell.y * columns + deck_cell.x]) > STEP_LIMIT, "the walk treats the lookout deck's edge as a ledge, not a step")
	# Walk the capsule itself from the dock to every destination along the open
	# cells: no step may collide, and the shore limit may never move the walker.
	var route_start := Vector2i((Vector2(0, 23) - bounds.position).round())
	var parents := _flood_parents(open, columns, rows, route_start)
	var blocked_steps := 0
	var limited_steps := 0
	var walked := 0.0
	var initial_position: Vector3 = world.player.position
	for point_id in destinations:
		var point: Dictionary = world._point_by_id(point_id)
		if point.is_empty(): continue
		var cell := _nearest_open(reached, columns, rows, Vector2(point.position.x, point.position.z) - bounds.position, 1.5)
		if cell.x < 0: continue
		while parents[cell.y * columns + cell.x] >= 0:
			var parent_index := parents[cell.y * columns + cell.x]
			var parent := Vector2i(parent_index % columns, parent_index / columns)
			var from := bounds.position + Vector2(parent)
			var to := bounds.position + Vector2(cell)
			var from_y := maxf(world._ground_surface_y(Vector3(from.x, 0, from.y)), 0.2) + 0.15
			var to_y := maxf(world._ground_surface_y(Vector3(to.x, 0, to.y)), 0.2) + 0.15
			if world.player.test_move(Transform3D(world.player.global_basis, Vector3(from.x, from_y, from.y)), Vector3(to.x - from.x, to_y - from_y, to.y - from.y)): blocked_steps += 1
			world.player.position = Vector3(to.x, to_y, to.y)
			world._constrain_player(world.player.position)
			if Vector2(world.player.position.x, world.player.position.z).distance_to(to) > 0.001: limited_steps += 1
			walked += from.distance_to(to)
			cell = parent
	world.player.position = initial_position
	_check(walked > 2500.0, "the walk from the dock covers every destination (%.0f m)" % walked)
	_check(blocked_steps == 0, "the walker's own body passes every step of the way (%d blocked steps)" % blocked_steps)
	_check(limited_steps == 0, "the shore limit never moves a walker who keeps to open ground (%d corrected steps)" % limited_steps)

func _flood(cells: PackedByteArray, columns: int, rows: int, start: Vector2i) -> PackedByteArray:
	var parents := _flood_parents(cells, columns, rows, start)
	var reached := PackedByteArray()
	reached.resize(cells.size())
	for index in parents.size():
		reached[index] = 1 if parents[index] != -2 else 0
	return reached

## Ground height under each cell of the last reachability grid.
var _cell_heights := PackedFloat32Array()
## A walker steps between neighbouring cells only where the ground rises this
## little; anything taller is a ledge and needs its ramp.
const STEP_LIMIT := 0.2

## Breadth-first walk over set cells. Each reached cell stores the index it was
## reached from (-1 for the start); unreached cells hold -2.
func _flood_parents(cells: PackedByteArray, columns: int, rows: int, start: Vector2i) -> PackedInt32Array:
	var parents := PackedInt32Array()
	parents.resize(cells.size())
	parents.fill(-2)
	var first := _nearest_open(cells, columns, rows, Vector2(start), 3.0)
	if first.x < 0: return parents
	var queue: Array[int] = [first.y * columns + first.x]
	parents[queue[0]] = -1
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var column := index % columns
		var row := index / columns
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_column := column + step.x
			var next_row := row + step.y
			if next_column < 0 or next_row < 0 or next_column >= columns or next_row >= rows: continue
			var next := next_row * columns + next_column
			if cells[next] == 0 or parents[next] != -2 or absf(_cell_heights[next] - _cell_heights[index]) > STEP_LIMIT: continue
			parents[next] = index
			queue.append(next)
	return parents

func _near(cells: PackedByteArray, columns: int, rows: int, local: Vector2, reach: float) -> bool:
	return _nearest_open(cells, columns, rows, local, reach).x >= 0

func _nearest_open(cells: PackedByteArray, columns: int, rows: int, local: Vector2, reach: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := reach
	var span := ceili(reach)
	var centre := Vector2i(local.round())
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dz)
			if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows or cells[cell.y * columns + cell.x] == 0: continue
			var distance := Vector2(cell).distance_to(local)
			if distance <= best_distance:
				best_distance = distance
				best = cell
	return best

## The travel map draws the real coastline and puts every marker inside it.
func _check_map_chart(world: Node) -> void:
	var chart: Control = IslandMapPanel.MapSurface.new()
	chart.size = Vector2(900, 520)
	chart.dock = world._point_by_id("arrival").get("position", Vector3.INF)
	chart.arrange(1.0, 220.0, 170.0)
	var outline: PackedVector2Array = chart.terrain_outline()
	var frame := Rect2(outline[0], Vector2.ZERO)
	for corner in outline:
		frame = frame.expand(corner)
	_check(outline.size() == IslandShape.coast().size() and chart.walk_chart.encloses(frame), "the chart draws the whole coastline inside its panel")
	_check(frame.size.x > 150.0 and frame.size.y > 150.0, "the island fills the chart at a readable size (%s px)" % frame.size)
	var misplaced := 0
	var placed := 0
	for point: Dictionary in world.points:
		var id := str(point.id)
		if id == "play:ball": continue
		var marker: Vector2 = chart.project(point.position)
		placed += 1
		if id == "arrival":
			_check(chart.walk_chart.has_point(marker) and not Geometry2D.is_point_in_polygon(marker, outline) and marker.y > frame.get_center().y, "the dock marker sits on the pier, south of the shore")
		elif not Geometry2D.is_point_in_polygon(marker, outline):
			misplaced += 1
	_check(placed >= 44 and misplaced == 0, "every map marker falls inside the drawn island (%d of %d outside)" % [misplaced, placed])
	var here: Vector2 = chart.project(Vector3(-94, 0, -61))
	_check(Geometry2D.is_point_in_polygon(here, outline) and here.x < frame.get_center().x, "a walker on the west cape is drawn on the island's west side")
	_check(not Geometry2D.is_point_in_polygon(chart.project(Vector3(0, 0, -175)), outline), "a position out at sea is drawn off the island")
	chart.free()

## The moored ferry reads as a boat (tapered bow, tucked stern, detailed
## parts), bobs only while motion is allowed, lights through the shared lamp
## budget, and keeps the footprint, name, deck marker and replay point it had.
func _check_ferry(world: Node) -> void:
	var ferry := world.get_node_or_null("WelcomeFerry") as Node3D
	var body := world.get_node_or_null("WelcomeFerry/FerryRoll") as Node3D
	var hull := world.get_node_or_null("WelcomeFerry/FerryRoll/FerryHull") as MeshInstance3D
	var deck := world.get_node_or_null("WelcomeFerry/FerryRoll/FerryDeck") as MeshInstance3D
	_check(ferry != null and body != null and hull != null and deck != null, "the ferry is built as hull, deck and fittings under one moored body")
	if ferry == null or body == null or hull == null or deck == null: return
	var collision := world.get_node_or_null("FerryCollision") as StaticBody3D
	var footprint: BoxShape3D = (collision.get_child(0) as CollisionShape3D).shape as BoxShape3D if collision != null and collision.get_child_count() == 1 else null
	_check(footprint != null and collision.position == Vector3(5.5, 0, 25) and footprint.size == Vector3(5, 0.8, 8), "the ferry keeps its dockside collision footprint")
	var arrival: Dictionary = world._point_by_id("arrival")
	_check(arrival.get("position") == Vector3(0, 0, 24) and arrival.get("label") == "重播上島導覽", "the arrival replay point beside the ferry is unchanged")
	var names := 0
	for label: Label3D in ferry.find_children("*", "Label3D", true, false):
		if label.text == "晚風號" and world.local_sign_labels.has(label): names += 1
	_check(names == 1, "the ferry carries its name once, as a nearby-only sign")
	# Silhouette: measure the hull's breadth near the bow, amidships and at the stern.
	_check(not hull.mesh is PrimitiveMesh, "the hull is a modelled shape, not a stock box or cylinder")
	var vertices: PackedVector3Array = hull.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = hull.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var bounds := hull.mesh.get_aabb()
	var breadth := {"bow": 0.0, "middle": 0.0, "stern": 0.0}
	var paints := {}
	for index in vertices.size():
		var along := (vertices[index].z - bounds.position.z) / bounds.size.z
		var zone := "bow" if along < 0.06 else ("middle" if absf(along - 0.6) < 0.06 else ("stern" if along > 0.97 else ""))
		if zone != "": breadth[zone] = maxf(float(breadth[zone]), absf(vertices[index].x))
		paints[colors[index].to_html(false).substr(0, 4)] = true
	_check(bounds.size.z > 8.0 and float(breadth.middle) > 2.2 and float(breadth.bow) < float(breadth.middle) * 0.35, "the hull narrows to a bow (%.2f m against %.2f m amidships)" % [breadth.bow, breadth.middle])
	_check(float(breadth.stern) < float(breadth.middle) - 0.2 and float(breadth.stern) > float(breadth.middle) * 0.6, "the stern tucks in without coming to a point")
	_check(paints.size() >= 6, "hull planking is painted in several strakes rather than one flat colour")
	_check(absf(deck.global_position.y - 1.0) < 0.001 and deck.material_override is ShaderMaterial, "the deck is planked at the height the prologue stands on")
	var marker := world.get_node_or_null("FerryDeckStageAnchor") as Marker3D
	_check(marker != null and marker.position == Vector3(5.5, 1.04, 22.65) and marker.get_parent() == world, "the prologue deck marker stays put on the world, not on the bobbing hull")
	var marker_local := deck.to_local(marker.global_position) if marker != null else Vector3.INF
	var deck_bounds := deck.mesh.get_aabb()
	_check(marker != null and Rect2(deck_bounds.position.x, deck_bounds.position.z, deck_bounds.size.x, deck_bounds.size.z).grow(-0.4).has_point(Vector2(marker_local.x, marker_local.z)), "the prologue marker stands on open deck")
	# Standards: no large part is a single flat-coloured stock shape; small trims
	# and thin lines are exempt.
	var parts := 0
	for part: GeometryInstance3D in ferry.find_children("*", "GeometryInstance3D", true, false):
		parts += 1
		var instance := part as MeshInstance3D
		if instance == null or not instance.mesh is PrimitiveMesh: continue
		var flat := instance.material_override as StandardMaterial3D
		if instance.material_override == null: flat = (instance.mesh as PrimitiveMesh).material as StandardMaterial3D
		if flat == null or flat.albedo_texture != null or flat.vertex_color_use_as_albedo: continue
		var extent := instance.mesh.get_aabb().size * instance.global_transform.basis.get_scale()
		var sides: Array[float] = [extent.x, extent.y, extent.z]
		sides.sort()
		_check(sides[2] <= 1.0 or sides[1] <= 0.1, "%s is not a large flat-coloured block" % instance.name)
	_check(parts >= 20 and ferry.find_children("*", "Node", true, false).size() <= 60, "the ferry is detailed within a bounded node count (%d visual parts)" % parts)
	for required in ["FerryRoof", "FerryFunnel", "FerryWindows", "FerryLifeRing", "FerryLantern"]:
		_check(ferry.find_child(required, true, false) != null, "%s is part of the ferry" % required)
	# Bobbing follows the ambient animation and rests exactly when motion is reduced.
	var initial_motion: bool = world.reduced_motion
	var initial_phase: String = world.active_time_phase
	world.apply_settings({"reduced_motion": false})
	var ambient: AnimationPlayer = world.component_motion.get_node("AmbientAnimationPlayer")
	var heave := 0.0
	var roll := 0.0
	for moment: float in [1.0, 2.2, 3.7, 5.1, 7.4]:
		ambient.seek(moment, true)
		heave = maxf(heave, absf(ferry.position.y))
		roll = maxf(roll, absf(body.rotation.z))
	_check(ambient.is_playing() and heave > 0.005 and heave <= 0.05 and roll > 0.001 and roll <= 0.03, "the hull heaves and rolls gently on the water (%.3f m, %.3f rad)" % [heave, roll])
	world.apply_settings({"reduced_motion": true})
	_check(not ambient.is_playing() and ferry.position == Vector3(5.5, 0, 25) and body.rotation == Vector3.ZERO, "reduced motion leaves the ferry at rest")
	world.apply_settings({"reduced_motion": initial_motion})
	# The lantern is one of the world's budgeted lamps; windows glow only after dark.
	var lantern := world.get_node_or_null("FerryLanternLight") as OmniLight3D
	_check(lantern != null and world.lamps.has(lantern), "the stern lantern joins the shared lamp list")
	var shade := ferry.find_child("FerryLantern", true, false) as MeshInstance3D
	_check(shade != null and (shade.material_override as StandardMaterial3D).emission_enabled, "the lantern light has a glowing lamp body")
	var previous_position: Vector3 = world.player.position
	world.player.position = Vector3(0, 0.3, 24)
	world.set_time_of_day("noon")
	var glow: StandardMaterial3D = world.ferry_window_glow
	_check(lantern != null and is_zero_approx(lantern.light_energy) and is_zero_approx(glow.emission_energy_multiplier), "by day the lantern and cabin windows are dark")
	world.set_time_of_day("night")
	var lit := 0
	var shadowed := 0
	for lamp: Light3D in world.lamps:
		if lamp.light_energy > 0.0: lit += 1
		if lamp.shadow_enabled: shadowed += 1
	_check(lantern != null and lantern.light_energy > 0.0 and glow.emission_energy_multiplier > 0.5, "at night the lantern and cabin windows glow for a player on the dock")
	_check(lit <= world.ACTIVE_LAMP_LIMIT and shadowed <= world.SHADOW_LAMP_LIMIT, "the ferry lantern stays inside the lamp budget (%d lit, %d shadowed)" % [lit, shadowed])
	world.player.position = previous_position
	world.set_time_of_day(initial_phase)

## Distance from `point` to the nearest land edge: positive on land.
func _land_inset(land: Rect2, point: Vector2) -> float:
	return minf(minf(point.x - land.position.x, land.end.x - point.x), minf(point.y - land.position.y, land.end.y - point.y))

func _check_wayfinding(world: Node) -> void:
	var landmarks: Node = world.story_landmarks
	_check(landmarks != null, "story landmarks are built into the island")
	if landmarks == null: return
	world.set_story_progress({"story_photo": false, "steps": {"quest-001": 0, "quest-002": 0}, "next_steps": {}, "photos": {}})
	var report: Array = landmarks.signpost_report()
	var signpost_ids: Array = report.map(func(record: Dictionary) -> String: return str(record.id))
	_check(signpost_ids == ["dock", "plaza", "avenue", "crossroads", "meadow", "north", "west-fork", "east-fork"], "signposts stand at the dock, the plaza, the avenue and every major fork (%s)" % str(signpost_ids))
	var signed_games := {}
	for signpost: Dictionary in landmarks.wayfinding.signposts():
		for entry: Dictionary in signpost.entries:
			for game_id in entry.target.get("ids", []):
				signed_games[str(game_id)] = true
	_check(signed_games.size() == 12, "signposts between them point the way to all twelve games")
	for record in report:
		var base: Vector3 = record.position
		_check(IslandShape.contains(Vector2(base.x, base.z), IslandShape.WALK_MARGIN + 0.3), "%s signpost stands inside the walkable island" % record.id)
		_check(world._ground_surface_y(base) >= IslandLayout.PATH_TOP_Y - 0.001, "%s signpost stands on paving at a fork, not out on the grass" % record.id)
		for line in record.lines:
			_check(str(line).split("　").size() == 2 and not str(line).split("　")[1].strip_edges().is_empty(), "%s direction shows a live status: %s" % [record.id, line])
		_check(str(record.label_text) == "\n".join(record.lines) and (record.lines as Array).size() >= 2, "%s billboard shows every direction on its own line" % record.id)
		var facing := Transform3D(world.player.global_basis, base + Vector3(0.0, 0.35, 0.9))
		_check(world.player.test_move(facing, Vector3(0.0, 0.0, -1.2)), "%s signpost is a solid landmark, not a floating label" % record.id)
		for side in [-1.15, 1.15]:
			var beside := Transform3D(world.player.global_basis, base + Vector3(side, 0.35, 1.2))
			_check(not world.player.test_move(beside, Vector3(0.0, 0.0, -2.0)), "%s signpost leaves walking room on side %.2f" % [record.id, side])
	_check_wayfinding_focus(world, landmarks)
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

func _check_wayfinding_focus(world: Node, landmarks: Node) -> void:
	var paths := ["dock", "plaza", "avenue"]
	var labels: Array[Label3D] = []
	for id in paths:
		labels.append(landmarks.get_node_or_null("Signpost_%s/SignText" % id) as Label3D)
	if not labels.all(func(label: Label3D) -> bool: return is_instance_valid(label)):
		_check(false, "all three existing signposts retain a separate status label")
		return
	var visible_ids := func() -> Array[int]:
		var indices: Array[int] = []
		for index in labels.size():
			if labels[index].visible:
				indices.append(index)
		return indices
	var arrivals := [23.2, 10.55, 9.10, 10.82, 11.15, -22.0, -38.0]
	var expected := [[0], [0], [1], [1], [0], [2], []]
	for index in arrivals.size():
		landmarks.update_signpost_visibility(Vector3(0.0, 0.2, arrivals[index]))
		_check(visible_ids.call() == expected[index], "one local story sign and stable handoff at z%.2f" % arrivals[index])
	var changes: Array[bool] = []
	labels[1].visibility_changed.connect(func() -> void: changes.append(labels[1].visible))
	landmarks.update_signpost_visibility(Vector3(0.0, 0.2, 9.10))
	landmarks.update_signpost_visibility(Vector3(0.0, 0.2, 9.10))
	landmarks.update_signpost_visibility(Vector3(0.15, 0.2, 9.20))
	_check(changes == [true] and visible_ids.call() == [1] and labels[0].text.contains("海岸環線")
		and labels[1].text.contains("票票"), "standing and small local movement leave reading stable without losing hidden directions")
	landmarks.update_signpost_visibility(world.player.position)

func _check_illuminated_guides(world: Node) -> void:
	var signs := world.get_node_or_null("WelcomeWayfinding") as Node3D
	_check(signs != null and signs.get_child_count() == 3 and signs.process_mode == Node.PROCESS_MODE_DISABLED,
		"three Welcome direction plaques have no processing")
	if signs == null: return
	var titles := {"Dock": "海風碼頭  ↓", "Avenue": "迎賓大道  ↑", "Nightmarket": "夜市入口  ↖"}
	var material: StandardMaterial3D
	for anchor: String in titles:
		var plaque := signs.get_node_or_null(anchor) as Node3D
		_check(plaque != null, "authored navigation plaque exists at " + anchor)
		if plaque == null: continue
		var label := plaque.get_node_or_null("Title") as Label3D
		var trim := plaque.get_node_or_null("Trim") as MeshInstance3D
		_check(label != null and label.text == titles[anchor], "visible route direction is correct at " + anchor)
		_check(trim != null and trim.material_override is StandardMaterial3D,
			"one lit strip identifies the board at " + anchor)
		if trim == null: continue
		if material == null:
			material = trim.material_override as StandardMaterial3D
		_check(trim.material_override == material, "the three boards share one time-phase material")
	_check(signs.find_children("*", "CollisionObject3D", true, false).is_empty()
		and signs.find_children("*", "Light3D", true, false).is_empty(),
		"guide plaques add no collision or dynamic light")
	var night_gate := world.get_node_or_null("GateStatus_nightmarket") as Label3D
	var toy_gate := world.get_node_or_null("GateStatus_toy") as Label3D
	var garden_gate := world.get_node_or_null("GateStatus_garden") as Label3D
	var future_gate := world.get_node_or_null("GateStatus_hotel") as Label3D
	_check(night_gate != null and night_gate.text == "6 張 · 不消耗", "open Nightmarket no longer reads as pending")
	_check(toy_gate != null and toy_gate.text == "30 張 · 不消耗", "Toy Town keeps its real 30-card gate")
	_check(garden_gate != null and garden_gate.text == "30 張 · 不消耗", "Garden uses the same real 30-card threshold")
	_check(future_gate != null and future_gate.text.contains("準備中"), "an unavailable gate still shows the future status")
	if material == null: return
	var previous_phase: String = world.active_time_phase
	var previous_reduction: bool = world.reduced_motion
	world.set_time_of_day("noon")
	_check(material.emission_energy_multiplier == 0.0 and world.lamp_energy_for_phase == 0.0,
		"noon uses no artificial guide trim or lamp output")
	world.set_time_of_day("dusk")
	var dusk_trim := material.emission_energy_multiplier
	var dusk_lamp: float = world.lamp_energy_for_phase
	_check(dusk_trim > 0.0 and dusk_lamp > 0.48, "dusk improves actual light energy and charges the shared guide trim")
	world.apply_settings({"reduced_motion": true})
	world.set_time_of_day("dusk")
	_check(is_equal_approx(material.emission_energy_multiplier, dusk_trim) and is_equal_approx(world.lamp_energy_for_phase, dusk_lamp),
		"reduced motion retains the same steady directions and light intensity")
	var active := 0
	var shadows := 0
	for lamp: Light3D in world.lamps:
		active += int(lamp.light_energy > 0.0)
		shadows += int(lamp.shadow_enabled)
	_check(active > 0 and active <= world.ACTIVE_LAMP_LIMIT and shadows <= world.SHADOW_LAMP_LIMIT,
		"dusk guidance preserves the existing active/shadow lamp budget")
	world.apply_settings({"reduced_motion": previous_reduction})
	world.set_time_of_day(previous_phase)


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
	_check(IslandLayout.COAST_STOPS.size() == CoastalCircuit.STOPS.size(), "every coastal landmark has a place on the loop")
	for stop_id: String in IslandLayout.COAST_STOPS:
		var plaque: Vector3 = CoastalCircuit.stop(stop_id).get("position", Vector3.INF)
		_check(plaque == world._point_by_id("coast:" + stop_id).get("position") and is_equal_approx(world._ground_surface_y(plaque), IslandLayout.PATH_TOP_Y) and IslandLayout.on_path(Vector2(plaque.x, plaque.z)), "%s plaque stands on the coastal trail" % stop_id)
		var landmark := CoastalCircuit.landmark(stop_id)
		_check(IslandShape.on_lawn(Vector2(landmark.x, landmark.z), 1.5) and not IslandLayout.on_path(Vector2(landmark.x, landmark.z), 1.0), "%s itself stands on the lawn beside the trail, clear of the sand" % stop_id)
	# Real movement input along the trail: the walker keeps going where the old
	# rectangle's west and north limits used to stop them.
	for walk: Array in [[Vector3(-60,0.35,20), "move_left", Vector3(-1,0,0)], [Vector3(2,0.35,-100), "move_up", Vector3(0,0,-1)]]:
		world.player.position=walk[0]
		world.player.velocity=Vector3.ZERO
		for index in 3: await physics_frame
		Input.action_press(walk[1])
		for index in 45: await physics_frame
		Input.action_release(walk[1])
		var travelled: float = (world.player.position - (walk[0] as Vector3)).dot(walk[2])
		_check(travelled > 0.9 and world.player.is_on_floor(), "real movement carries the walker along the trail at %s without a limit or a fall (%.2f m)" % [walk[0], travelled])
		for index in 6: await physics_frame
	# Walking into the sea stops at the shore without a jump.
	world.player.position=Vector3(-99.5,0.35,-52)
	world.player.velocity=Vector3.ZERO
	for index in 3: await physics_frame
	var before_wade: Vector3 = world.player.position
	Input.action_press("move_left")
	var largest_step := 0.0
	var previous: Vector3 = world.player.position
	for index in 240:
		await physics_frame
		largest_step = maxf(largest_step, world.player.position.distance_to(previous))
		previous = world.player.position
	Input.action_release("move_left")
	var shore_distance := IslandShape.distance_to_coast(Vector2(world.player.position.x, world.player.position.z))
	_check(world.player.position.x < before_wade.x - 0.5 and absf(shore_distance - IslandShape.WALK_MARGIN) < 0.15 and largest_step < 0.08 and world.player.is_on_floor(),
		"walking into the sea ends at the shore limit with no teleport (%.2f m from the water, largest step %.3f m)" % [shore_distance, largest_step])
	for index in 6: await physics_frame
	world.player.position=(CoastalCircuit.stop("lighthouse").position as Vector3)+Vector3(0,0.2,0)
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
	var route := IslandLayout.coast_route()
	var clear := true
	for index in route.size() - 1:
		var a := route[index]
		var b := route[index + 1]
		var tangent := (b-a).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		for offset in [-0.8,0.0,0.8]:
			var p := a+normal*float(offset)
			var transform := Transform3D(Basis.IDENTITY,Vector3(p.x,0.35,p.y))
			if world.player.test_move(transform,Vector3(b.x-a.x,0,b.y-a.y)):
				clear=false
				_check(false,"coastal trail corridor blocked near %s offset %.1f" % [p,offset])
	_check(clear,"actual player capsule clears the whole coastal trail with lateral walking room")
