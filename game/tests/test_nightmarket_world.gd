extends SceneTree

const World = preload("res://game/world/nightmarket_world.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Routes = preload("res://game/core/region_routes.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const MOVES := ["move_left", "move_right", "move_up", "move_down"]
var _world: Node3D
var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_world = World.new()
	root.add_child(_world)
	await frames(7)
	var entry_body_y: float = _world.player.position.y
	var baseline: Dictionary = _world.map_snapshot()
	check(Routes.supports("nightmarket") and Routes.threshold("nightmarket") == 6 and not Routes.supports("circus"),
		"same-batch access uses six cards and preserves later gates")
	check(baseline.region == "nightmarket" and baseline.operating and baseline.points.size() == 7 + Catalog.definitions("nightmarket").size()
		and baseline.land.size() == 7 and not baseline.covered, "world declares its real terrain and uses a stable set of points")
	check(baseline.points.any(func(point: Dictionary) -> bool: return point.id == "game-038"), "real skewer stand appears on east street chart")
	_check_paving()
	var grill_stop := Vector2(9.15, 3.27)
	var coin_stop := Vector2(World.COIN_ENTRY.x, World.COIN_ENTRY.z)
	var scent_stop := Vector2(World.SCENT_ENTRY.x, World.SCENT_ENTRY.z)
	var banner_stop := Vector2(World.BANNER_ENTRY.x, World.BANNER_ENTRY.z)
	for position in [Vector2(-9.6, 7.2), coin_stop, Vector2(-9.6, -4.3), scent_stop, banner_stop, Vector2(9.6, -4.3), grill_stop, Vector2(9.6, 7.2), Vector2(0, 7.2), Vector2(0, 0.7)]:
		check(await walk_to(position), "real walker reaches %s without falling" % position)
		if position == banner_stop:
			check(_world.nearest.get("id") == "game-042", "banner cart is reachable and selected on the north-east walkway")
		if position == scent_stop:
			check(_world.nearest.get("id") == "game-041", "scent stand is reachable and selected on the north walkway")
		if position == coin_stop:
			check(_world.nearest.get("id") == "game-040", "coin stand is reachable and selected on the west walkway")
		if position == grill_stop:
			check(_world.nearest.get("id") == "game-038", "skewer stall is the interactable destination on foot")
	check(_world.covered_at(_world.player.position) and _world.current_area == "雨棚巷", "central awning covers the actual walking area")
	check(await walk_to(Vector2(0, -5.3)) and await walk_to(Vector2(0, -11.62)), "raised roof is reachable on foot over the ramp")
	var climb: float = _world.player.position.y - entry_body_y
	check(absf(climb - (World.ROOF_Y - World.GROUND_Y)) < 0.06 and _world.current_area == "屋頂餐桌",
		"real collision supports the elevated roof deck")
	var lantern_stop := Vector2(World.LANTERN_ENTRY.x, World.LANTERN_ENTRY.z)
	check(await walk_to(lantern_stop) and _world.nearest.get("id") == "game-039", "accessible rooftop lantern stand is the real interaction target")
	check(await walk_to(Vector2(0, lantern_stop.y)) and await walk_to(Vector2(0, -4.3)), "physical ramp also supports the descent")
	var node_count: int = _world.find_children("*", "", true, false).size()
	var lit: Material = _world._stall_lights[0].material_override
	var paving: ShaderMaterial = _world._atmosphere.paving_material()
	var open_reflection: float = paving.get_shader_parameter("reflection_energy")
	for cycle in 20:
		_world.cycle_market()
		var snapshot: Dictionary = _world.map_snapshot()
		check(snapshot.operating == (cycle % 2 == 1), "operating state is reversible")
		check(_world._stall_lights[0].material_override != lit if cycle % 2 == 0 else _world._stall_lights[0].material_override == lit,
			"each operation changes existing lamp material")
		var actual: float = paving.get_shader_parameter("reflection_energy")
		var expected := open_reflection * 0.24 if cycle % 2 == 0 else open_reflection
		check(is_equal_approx(actual, expected) and _world._atmosphere.paving_material() == paving,
			"market reflections follow existing lamps without allocating a surface")
	check(_world.find_children("*", "", true, false).size() == node_count, "running the shop does not allocate terrain or lights")
	var map := MapPanel.new()
	map.setup(_world.map_snapshot())
	root.add_child(map)
	var status: Label = map.find_child("NightmarketMapStatus", true, false)
	check(status != null and status.text.contains("營業中") and map.find_child("NightmarketMapTerrain", true, false) != null,
		"shared map registers actual market status and land")
	var last := Vector3(0, World.GROUND_Y, 6.2)
	_world.player.position = Vector3(0, World.GROUND_Y, 10.8)
	_world._constrain_player(last)
	check(_world.player.position.is_equal_approx(last), "outer boundary returns to valid footing")
	_world.player.position = Vector3(15, -1.4, 18)
	_world._constrain_player(_world.player.position)
	check(_world.player.position.is_equal_approx(World.ENTRY) and _world.player.velocity == Vector3.ZERO,
		"invalid footing safely returns to the entry")
	map.free()
	_world.free()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: night market terrain, rain cover, rooftop, maps and safe routing")
	quit(int(not _errors.is_empty()))

func _check_paving() -> void:
	var paving: ShaderMaterial = _world._atmosphere.paving_material()
	var roof: ShaderMaterial = _world._atmosphere.paving_material(true)
	for index in range(5):
		var floor: MeshInstance3D = _world.get_node("MarketWalk%d" % index)
		check(floor.material_override == paving, "walkways reuse region-owned paving")
	var deck: MeshInstance3D = _world.get_node("RoofDiningDeck")
	var ramp: MeshInstance3D = _world.get_node("RoofRamp")
	check(deck.material_override == roof and ramp.material_override == roof and roof != paving and roof.get_shader_parameter("rooftop"),
		"the ramp and raised path share a dedicated drier finish")
	var awning: Rect2 = World.AWNING
	check(paving.get_shader_parameter("shelter_rect") == Vector4(awning.position.x, awning.position.y, awning.end.x, awning.end.y),
		"ground shelter follows actual canopy coverage")
	_world.set_time_of_day("noon")
	var noon_color: Color = paving.get_shader_parameter("reflected_sky")
	var noon_energy: float = paving.get_shader_parameter("reflection_energy")
	_world.set_time_of_day("night")
	check(paving.get_shader_parameter("reflected_sky") != noon_color and paving.get_shader_parameter("reflection_energy") > noon_energy,
		"night cools the reflected sky and strengthens lamp reflections")
	_world.apply_settings({"reduced_motion": true})
	check(not paving.get_shader_parameter("reflections_move") and not roof.get_shader_parameter("reflections_move")
		and not _world._atmosphere.is_processing(), "reduced motion freezes the ground and lamps")
	_world.apply_settings({"reduced_motion": false})
	check(paving.get_shader_parameter("reflections_move") and roof.get_shader_parameter("reflections_move"),
		"continuous glints resume with motion restored")

func walk_to(position: Vector2) -> bool:
	var start: Vector3 = _world.player.position
	var distance := Vector2(start.x, start.z).distance_to(position)
	var frame_limit := ceili(distance / World.AVATAR_RUN_SPEED * 60.0) + 90
	for tick in frame_limit:
		var actual: Vector3 = _world.player.position
		var delta := position - Vector2(actual.x, actual.z)
		if delta.length() < 0.25:
			break
		set_moves(delta.normalized())
		await physics_frame
	set_moves(Vector2.ZERO)
	await frames(8)
	var current: Vector3 = _world.player.position
	return Vector2(current.x, current.z).distance_to(position) < 0.49 and _world.player.is_on_floor()

func set_moves(value: Vector2) -> void:
	var strength := [maxf(-value.x, 0.0), maxf(value.x, 0.0), maxf(-value.y, 0.0), maxf(value.y, 0.0)]
	for index in MOVES.size():
		if strength[index] > 0.0:
			Input.action_press(MOVES[index], strength[index])
		else:
			Input.action_release(MOVES[index])

func frames(count: int) -> void:
	for tick in count:
		await physics_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
