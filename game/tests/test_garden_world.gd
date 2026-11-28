extends SceneTree

const World = preload("res://game/world/garden_world.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const ArcadeStands = preload("res://game/world/arcade_stands.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SceneStandards = preload("res://game/world/scene_standards.gd")
## Scene-building standards, section 8: nodes and draws for a region other than Welcome.
const DRAW_BUDGET := 800
## How far the fixed camera sees past the player along the ground, plus the 12 m the standards ask for.
const VIEW_MARGIN := Vector2(18.7, 19.2) + Vector2(12.0, 12.0)
const LANDMARKS := ["GardenDoorway", "GardenGlazing", "GardenClearGlazing", "GardenLilyPond", "GardenRills", "GardenWetlandWater",
	"GardenWeatherVane", "GardenWhirligig", "GardenFrogs", "GardenDrips", "GardenNightGlow", "GardenSunbeams", "GardenSunRack/GardenSunShaft"]
const MOVES := ["move_left", "move_right", "move_up", "move_down"]

var _world: World
var _errors: Array[String] = []
var _checks := 0
var _interaction := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Greenhouse test requires a private save.")
		quit(1)
		return
	_world = World.new()
	root.add_child(_world)
	_world.interaction_requested.connect(_on_interact)
	await _frames(5)
	_check(_world.current_area == "日照窗" and _world.player.is_on_floor() and _world.nearest.get("id") == "region:welcome",
		"a grounded Garden arrival offers the actual free return")
	_check(_world.npc_activity == null and _world.coastal_play == null, "only local Garden activity is built")
	_check_budget()
	await _check_arcade_stands()
	await _reach([Vector2(0, 3.45)], "garden:louvers", "日照窗")
	await _check_louvers()
	await _reach([Vector2(0, 4.65), Vector2(-7.2, 4.65), Vector2(-7.2, 0.05)], "garden:wetland", "濕地床")
	await _check_life()
	await _check_recovery("move_left", "wetland edge", World.GROUND_Y)
	await _check_terraces()
	_check_map()
	await _reach([Vector2(0, -6.15), Vector2(4.0, -6.15), Vector2(4.0, 4.65), Vector2(0, 4.65), Vector2(0, 7.8)],
		"region:welcome", "日照窗")
	_world.interact()
	_check(_interaction == "region:welcome", "interacting at the free entrance emits the route signal")
	_world.free()
	await _frames(2)
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: garden rooms, physical terraces, louver illumination, safe footing and truthful map")
	print("Garden: %d checks, %d failures" % [_checks, _errors.size()])
	quit(int(not _errors.is_empty()))


## Every delivered game has a stand the visitor can walk up to; coordinates live in the stand table.
## Stands beyond the fountain are walked to along the east side of the sun floor, as visitors do.
const STAND_ROUTES := {
	"game-077": [Vector2(0, 4.65), Vector2(4.0, 4.65), Vector2(4.0, -6.15)],
	"game-080": [Vector2(0, 4.65), Vector2(4.0, 4.65), Vector2(4.0, -6.15)],
	"game-076": [Vector2(0, 4.65), Vector2(-7.2, 4.65), Vector2(-7.2, -5.4)],
	"game-078": [Vector2(0, 4.65), Vector2(7.2, 4.65), Vector2(7.2, -4.6)],
	"game-081": [Vector2(0, 4.65), Vector2(7.2, 4.65), Vector2(7.2, -1.6)],
	"game-082": [Vector2(0, 4.65), Vector2(7.2, 4.65), Vector2(7.2, -4.6)],
	"game-083": [Vector2(0, 4.65), Vector2(4.0, 4.65), Vector2(4.0, -6.15), Vector2(0, -6.15), Vector2(0, -9.0), Vector2(-8.3, -9.0)],
	"game-075": [Vector2(0, 4.65), Vector2(4.0, 4.65), Vector2(4.0, -6.15), Vector2(4.0, -9.3)],
}


func _check_arcade_stands() -> void:
	var delivered: Array = Catalog.definitions("garden")
	_check(ArcadeStands.rows("garden").size() == delivered.size(), "one entry stand per delivered Garden game")
	for definition: Dictionary in delivered:
		var point: Dictionary = _world._point_by_id(definition.id)
		var stand := _world.get_node_or_null("ArcadeStand_" + str(definition.id)) as MeshInstance3D
		_check(not point.is_empty() and stand != null and stand.find_children("*", "CollisionShape3D", true, false).size() == 1,
			str(definition.id) + " has a solid stand and an interaction point")
		if point.is_empty():
			continue
		var at: Vector3 = point.position
		_check(_world._safe_standing(at) and str(point.label).contains(str(definition.name)), str(definition.id) + " is entered from safe ground and named on its prompt")
		var route: Array = STAND_ROUTES.get(definition.id, [Vector2(at.x, World.ENTRY.z)])
		var walked := true
		var stuck := ""
		for waypoint: Vector2 in route + [Vector2(at.x, at.z)]:
			if walked and not await _walk(waypoint):
				walked = false
				stuck = " (stopped at %s on the way to %s)" % [_world.player.position, waypoint]
		_check(walked
			and _world.nearest.get("id") == definition.id and Catalog.identity(str(_world.nearest.get("id"))).zone == "garden",
			str(definition.id) + " is reachable on foot and its prompt opens that game" + stuck)
		var back := route.duplicate()
		back.reverse()
		for waypoint: Vector2 in back:
			await _walk(waypoint)
	_check(await _walk(Vector2(0, World.ENTRY.z)), "the way back to the entrance stays open")


func _check_budget() -> void:
	var locals := _world.find_children("*", "OmniLight3D", true, false)
	_check(locals.size() == 2 and locals.all(func(light: OmniLight3D) -> bool: return not light.shadow_enabled),
		"the light experiment and bud court use only two shadowless local fills")
	_check(_world.lamps.is_empty(), "lanterns glow without adding lights to the lamp budget")
	var batches := _world.find_children("*", "MultiMeshInstance3D", true, false).size()
	var meshes := _world.find_children("*", "MeshInstance3D", true, false).size() + batches
	var nodes := _world.find_children("*", "", true, false).size() + 1
	_check(meshes <= DRAW_BUDGET and nodes <= SceneStandards.DEFAULT_NODE_BUDGET and batches >= 20,
		"full region stays inside the district budget with repeated props batched: %d mesh instances (%d batches) and %d nodes" % [meshes, batches, nodes])
	print("Garden scene budget: %d mesh instances, %d nodes" % [meshes, nodes])
	var found := SceneStandards.audit(_world, "garden")
	for rule in SceneStandards.RULES:
		_check((found[rule] as Array).is_empty(), "the rebuilt greenhouse has no '%s' debt" % rule)
	for landmark: String in LANDMARKS:
		_check(_world.get_node_or_null(landmark) is GeometryInstance3D, "landmark %s is built" % landmark)
	var apron := _world.get_node_or_null("GardenContinuousApron") as MeshInstance3D
	var ground := Rect2()
	if apron != null:
		var box := apron.global_transform * apron.get_aabb()
		ground = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	_check(ground.encloses(World.BOUNDS.grow_individual(VIEW_MARGIN.x, VIEW_MARGIN.y, VIEW_MARGIN.x, VIEW_MARGIN.y))
		and absf(_world.ground_surface_y(Vector3(20, 0, 20)) - apron.position.y) < 0.001 and apron.position.y < World.GROUND_Y - 0.02,
		"natural ground runs past everything the camera can show from any reachable spot")
	var west := _world.get_node_or_null("GardenCanopyWest") as Sprite3D
	var east := _world.get_node_or_null("GardenCanopyEast") as Sprite3D
	if _canopy_is_exterior(west) and _canopy_is_exterior(east):
		var west_crop := west.texture as AtlasTexture
		var east_crop := east.texture as AtlasTexture
		_check(west_crop.atlas == east_crop.atlas and west_crop.region != east_crop.region,
			"the two shadowless exterior silhouettes use different regions of one atlas")
	else:
		_check(false, "both atlas silhouettes are mounted without collision beyond the walking boundary")

func _canopy_is_exterior(canopy: Sprite3D) -> bool:
	if canopy == null or not canopy.texture is AtlasTexture:
		return false
	return not World.BOUNDS.has_point(Vector2(canopy.position.x, canopy.position.z)) \
		and canopy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
		and canopy.get_child_count() == 0


func _check_louvers() -> void:
	var rack := _world.get_node("GardenSunRack")
	var blade := rack.get_node("GardenSlat_0") as MeshInstance3D
	var light := rack.get_node("GardenSunPool") as OmniLight3D
	var plant: StandardMaterial3D = rack._plants[0]
	var sun_basis := _world.sun.global_basis
	var west := _world.sun_patch_center()
	_check(_world.louver_detent() == 0 and _world.illuminated_bed() == 0 and is_equal_approx(west.x, -2.75),
		"west detent starts over the actual diamond-leaf bed")
	_check(_sun_level_reads(rack, 0), "first sun level opens only the west bed's flowers and lands its shaft there")
	_check(is_equal_approx(blade.rotation.z, _world.louver_angle()) and is_equal_approx(light.global_position.x, west.x)
		and plant.emission_energy_multiplier > rack._plants[1].emission_energy_multiplier,
		"physical blade, local light, and leaf response all use the west angle")
	_world.interact()
	_check(_interaction == "garden:louvers" and _world.louver_detent() == 1 and _world.louver_is_moving(),
		"actual louver contact selects the rounded leaf bed and begins one transition")
	await _frames(9)
	var travelled := _world.sun_patch_center()
	_check(travelled.x > west.x + 0.10 and travelled.x < -0.10 and is_equal_approx(travelled.z, west.z)
		and is_equal_approx(blade.rotation.z, _world.louver_angle()), "slats and pattern move continuously through the same physical interval")
	_world.blocked = true
	await _frames(30)
	_check(_world.louver_is_moving() and _world.sun_patch_center() == travelled, "blocked world freezes all louver geometry")
	_world.blocked = false
	await _frames(30)
	_check(not _world.louver_is_moving() and _world.illuminated_bed() == 1 and absf(_world.sun_patch_center().x) < 0.01
		and rack._plants[1].emission_energy_multiplier > plant.emission_energy_multiplier,
		"center detent settles over the real center crop without residual light on the previous crop")
	_check(_sun_level_reads(rack, 1), "second sun level opens only the centre bed's flowers and lands its shaft there")
	_world.interact()
	_world.apply_settings({"reduced_motion": true})
	_check(not _world.louver_is_moving() and _world.illuminated_bed() == 2 and is_equal_approx(_world.sun_patch_center().x, 2.75),
		"turning on reduced motion settles the same east target immediately")
	_check(_sun_level_reads(rack, 2) and is_zero_approx(rack._shaft.get_shader_parameter("motion")),
		"third sun level opens only the east bed's flowers, and reduced motion stills the dust in its shaft")
	_world.interact()
	_check(not _world.louver_is_moving() and _world.louver_detent() == 0 and _world.illuminated_bed() == 0
		and _world.sun_patch_center().is_equal_approx(west) and _world.sun.global_basis.is_equal_approx(sun_basis),
		"reduced cycling restores the exact west arrangement while the park sun keeps its direction")
	var day_emission: float = _world._buds.emission_energy_multiplier
	_world.set_time_of_day("night")
	_check(_world._buds.emission_energy_multiplier > day_emission and _world._water.get_shader_parameter("reduced_motion")
		and _world.material_cache["garden:rill-water"].get_shader_parameter("reduced_motion")
		and _world.material_cache["garden:pond-water"].get_shader_parameter("reduced_motion"),
		"night buds respond to actual time of day and every reduced water surface stays static")


## The lit bed is the only one in flower, and the light shaft's foot stands on it.
func _sun_level_reads(rack: Node3D, lit: int) -> bool:
	for bed in 3:
		if (rack.bloom(bed) > 0.95) != (bed == lit) or (bed != lit and rack.bloom(bed) > 0.05):
			return false
	return is_equal_approx(rack._shaft.get_shader_parameter("foot_shift"), rack.BED_X[lit])


## Ambient motion and the frogs, which leap from whoever walks up the boardwalk.
## The louver check leaves reduced motion on, so stillness is measured first.
func _check_life() -> void:
	var vane := _world.get_node("GardenWeatherVane") as Node3D
	var whirligig := _world.get_node("GardenWhirligig") as Node3D
	var near: Array[int] = []
	for index in _world.frog_count():
		if _flat_distance(_world.frog_home(index), _world.player.position) < 2.5:
			near.append(index)
	_check(_world.frog_count() >= 5 and near.size() >= 2, "frogs sit within reach of the boardwalk stop")
	var still_vane := vane.rotation.y
	var still_spin := whirligig.rotation.z
	var nodes := _world.find_children("*", "", true, false).size()
	var materials: int = _world.material_cache.size()
	await _frames(40)
	_check(vane.rotation.y == still_vane and whirligig.rotation.z == still_spin and near.all(_world.frog_is_out),
		"reduced motion holds the weather vane, the whirligig and every frog still")
	_world.apply_settings({"reduced_motion": false})
	await _frames(50)
	_check(vane.rotation.y != still_vane and whirligig.rotation.z != still_spin, "the weather vane and whirligig turn again with motion on")
	_check(not near.any(_world.frog_is_out), "frogs beside the walker leap into the water")
	var far: Array[int] = []
	for index in _world.frog_count():
		if _flat_distance(_world.frog_home(index), _world.player.position) > 3.2:
			far.append(index)
	_check(far.size() >= 3 and far.all(_world.frog_is_out), "frogs out of reach keep their lily pads")
	_world.blocked = true
	var frozen := vane.rotation.y
	await _frames(20)
	_check(vane.rotation.y == frozen, "a blocked world pauses the garden's motion")
	_world.blocked = false
	_world.apply_settings({"reduced_motion": true})
	await _frames(3)
	_check(near.all(_world.frog_is_out) and _world.find_children("*", "", true, false).size() == nodes
		and _world.material_cache.size() == materials, "reduced motion returns the frogs at once and nothing is created by any of it")


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _check_terraces() -> void:
	var before := _world.safe_reset_count()
	for waypoint in [Vector2(-7.2, 0.05), Vector2(-7.2, 4.65), Vector2(0, 4.65), Vector2(7.13, 4.65), Vector2(7.13, -2.9)]:
		_check(await _walk(waypoint), "continuous supported route reaches " + str(waypoint))
	_check(absf(_foot_height(_world.player.position.y) - World.LOWER_Y) < 0.08, "the shallow incline reaches the real lower leaf deck")
	await _reach([Vector2(7.13, -6.15)], "garden:vine", "藤蔓層")
	_check(absf(_foot_height(_world.player.position.y) - World.UPPER_Y) < 0.08 and _world.safe_reset_count() == before,
		"the gentle second link reaches a distinct raised surface without safety resets")
	await _check_recovery("move_up", "upper deck north edge", World.UPPER_Y)
	before = _world.safe_reset_count()
	await _reach([Vector2(7.13, -2.9), Vector2(7.13, 4.65), Vector2(10.65, 4.65), Vector2(10.65, -9.55), Vector2(0, -9.55)],
		"garden:buds", "夜芽庭")
	_check(_world.safe_reset_count() == before and absf(_foot_height(_world.player.position.y) - World.GROUND_Y) < 0.08,
		"wide eastern bypass reaches the north court along the actual ground without recovery")


func _check_recovery(action: String, description: String, height: float) -> void:
	var previous := _world.safe_reset_count()
	Input.action_press(action)
	for tick in range(120):
		if _world.safe_reset_count() > previous:
			break
		await physics_frame
	Input.action_release(action)
	var witness: Vector3 = _world.last_safe_position()
	_check(_world.safe_reset_count() == previous + 1 and _world.player.position.is_equal_approx(witness)
	and _world.player.velocity == Vector3.ZERO and absf(_foot_height(witness.y) - height) < 0.067,
		description + " restores the nearest stable foothold and zeroes residual movement")
	await _frames(3)


func _check_map() -> void:
	var snapshot := _world.map_snapshot()
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("GardenMapLocations", true, false)
	var status := map.find_child("GardenMapStatus", true, false) as Label
	_check(snapshot.region == "garden" and snapshot.areas.size() == 4 and snapshot.points.size() == 6 + ArcadeStands.rows("garden").size()
		and snapshot.player == _world.player.position and snapshot.area == "夜芽庭" and locations != null
		and locations.get_child_count() == snapshot.points.size() and status != null and status.text.contains("西植床")
		and map.find_child("GardenMapTerrain", true, false) != null, "map reports its four physical rooms, local light, traveler, and six real pins")
	var water_only := Vector2(-10, 0)
	_check(snapshot.water.has_point(water_only) and not snapshot.land.any(func(rect: Rect2) -> bool: return rect.has_point(water_only))
		and snapshot.boardwalk.has_point(Vector2(-7.2, 0.05)) and snapshot.terraces[1].has_point(Vector2(7.13, -6.15))
		and World.BUDS.z < World.ENTRY.z, "map distinguishes impassable water, the actual boardwalk, north court and elevated leaf deck")
	snapshot.areas[0].label = "changed"
	_check(_world.map_snapshot().areas[0].label == "日照窗", "map snapshot is independent of the live terrain data")
	map.free()


func _on_interact(id: String, _text: String) -> void:
	_interaction = id
	if id == "garden:louvers":
		_world.switch_louvers()

func _foot_height(origin: float) -> float:
	for child in _world.player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			return origin + child.position.y - child.shape.height * 0.5
	return INF


func _reach(sequence: Array[Vector2], expected: String, area: String) -> void:
	for waypoint in sequence:
		_check(await _walk(waypoint), "physical route reaches " + str(waypoint))
	_check(_world.current_area == area and _world.nearest.get("id") == expected, "physical position exposes the exact local interaction for " + area)


func _walk(destination: Vector2) -> bool:
	var start := _world.player.position
	var limit := ceili(Vector2(start.x, start.z).distance_to(destination) / World.AVATAR_RUN_SPEED * 60.0) + 100
	for tick in limit:
		var at := _world.player.position
		var offset := destination - Vector2(at.x, at.z)
		if offset.length() < 0.22:
			break
		var direction := offset.normalized()
		var strengths := [maxf(-direction.x, 0.0), maxf(direction.x, 0.0), maxf(-direction.y, 0.0), maxf(direction.y, 0.0)]
		for index in MOVES.size():
			if strengths[index] > 0.0:
				Input.action_press(MOVES[index], strengths[index])
			else:
				Input.action_release(MOVES[index])
		await physics_frame
	for action in MOVES:
		Input.action_release(action)
	await _frames(9)
	var at := _world.player.position
	return _world.player.is_on_floor() and Vector2(at.x, at.z).distance_to(destination) < 0.47


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
