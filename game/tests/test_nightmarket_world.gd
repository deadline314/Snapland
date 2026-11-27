extends SceneTree

const World = preload("res://game/world/nightmarket_world.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Routes = preload("res://game/core/region_routes.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const Scenery = preload("res://game/world/nightmarket_scenery.gd")
const Life = preload("res://game/world/nightmarket_life.gd")
const Atmosphere = preload("res://game/world/nightmarket_atmosphere.gd")
const NODE_BUDGET := 900
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
	check(Routes.supports("nightmarket") and Routes.threshold("nightmarket") == 6 and not Routes.supports("cinema"),
		"same-batch access uses six cards and preserves later gates")
	check(baseline.region == "nightmarket" and baseline.operating and baseline.points.size() == 7 + Catalog.definitions("nightmarket").size()
		and baseline.land.size() == 7 and not baseline.covered, "world declares its real terrain and uses a stable set of points")
	check(baseline.points.any(func(point: Dictionary) -> bool: return point.id == "game-038"), "real skewer stand appears on east street chart")
	_check_paving()
	_check_scenery()
	await _check_life()
	var grill_stop := Vector2(9.15, 3.27)
	var coin_stop := Vector2(World.COIN_ENTRY.x, World.COIN_ENTRY.z)
	var scent_stop := Vector2(World.SCENT_ENTRY.x, World.SCENT_ENTRY.z)
	var banner_stop := Vector2(World.BANNER_ENTRY.x, World.BANNER_ENTRY.z)
	var cart_stop := Vector2(World.CART_PASS_ENTRY.x, World.CART_PASS_ENTRY.z)
	var soup_stop := Vector2(World.SOUP_ENTRY.x, World.SOUP_ENTRY.z)
	var pancake_stop := Vector2(World.PANCAKE_ENTRY.x, World.PANCAKE_ENTRY.z)
	for position in [soup_stop, Vector2(-9.6, 7.2), coin_stop, Vector2(-9.6, -4.3), pancake_stop, scent_stop, banner_stop, Vector2(9.6, -4.3), grill_stop, Vector2(9.6, 7.2), cart_stop, Vector2(0, 7.2), Vector2(0, 0.7)]:
		check(await walk_to(position), "real walker reaches %s without falling" % position)
		if position == cart_stop:
			check(_world.nearest.get("id") == "game-046", "southeast cart loading lane is reachable and selected on foot")
		if position == soup_stop:
			check(_world.nearest.get("id") == "game-045", "southwest soup stand is reachable and selected on foot")
		if position == pancake_stop:
			check(_world.nearest.get("id") == "game-043", "pancake stand is reachable on the north-west walkway")
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
	var umbrella_stop := Vector2(World.UMBRELLA_ENTRY.x, World.UMBRELLA_ENTRY.z)
	check(await walk_to(umbrella_stop) and _world.nearest.get("id") == "game-044", "west rooftop umbrella is reachable on foot")
	var sugar_stop := Vector2(World.SUGAR_LANTERN_ENTRY.x, World.SUGAR_LANTERN_ENTRY.z)
	check(await walk_to(sugar_stop) and _world.nearest.get("id") == "game-047", "east rooftop sugar craft is a distinct real destination")
	check(await walk_to(Vector2(0, lantern_stop.y)) and await walk_to(Vector2(0, -4.3)), "physical ramp also supports the descent")
	var loadout_stop := Vector2(World.STALL_LOADOUT_ENTRY.x, World.STALL_LOADOUT_ENTRY.z)
	check(await walk_to(Vector2(0, 7.91)) and await walk_to(loadout_stop) and _world.nearest.get("id") == "game-048",
		"closing-time cart is reachable from the actual south walkway")
	var node_count: int = _world.find_children("*", "", true, false).size()
	var lanterns: ShaderMaterial = _world._scenery.props.lantern_material
	var neon: ShaderMaterial = _world._scenery.props.neon_material
	var open_lanterns: float = lanterns.get_shader_parameter("energy")
	var open_neon: float = neon.get_shader_parameter("energy")
	check(open_lanterns > 0.5 and open_neon > 0.5, "an open market keeps its lanterns and signs lit")
	var paving: ShaderMaterial = _world._atmosphere.paving_material()
	var open_reflection: float = paving.get_shader_parameter("reflection_energy")
	for cycle in 20:
		_world.cycle_market()
		var snapshot: Dictionary = _world.map_snapshot()
		check(snapshot.operating == (cycle % 2 == 1), "operating state is reversible")
		var share := Scenery.CLOSED_GLOW if cycle % 2 == 0 else 1.0
		check(is_equal_approx(lanterns.get_shader_parameter("energy"), open_lanterns * share) and is_equal_approx(neon.get_shader_parameter("energy"), open_neon * share)
			and _world._scenery.props.lantern_material == lanterns and _world._scenery.props.neon_material == neon,
			"each operation dims or relights the existing lanterns and signs")
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

## Landmarks, light budget and ground cover of the rebuilt quarter.
func _check_scenery() -> void:
	for landmark in ["MarketNeon", "Scenery_lanterns", "Scenery_parasols", "Scenery_pennants", "Scenery_banners", "CoveredAlleyAwning", "LuckyCatArm", "MarketRotisserie", "MarketParasol", "MarketFan0", "ValleyFloor", "SceneryDetail"]:
		check(_world.has_node(landmark), "the market keeps its %s" % landmark)
	var boards: Array[String] = []
	for label: Label3D in _world._scenery.props.sign_labels:
		boards.append(label.text.replace("\n", ""))
		check(label.visible and is_zero_approx(label.visibility_range_end), "signboards read from across the market")
	for stand: Array in World.STANDS:
		check(boards.has(World.STAND_SIGNS[stand[0]]) and Scenery.Props.EMBLEMS.has(stand[3]) and _world._point_by_id(stand[0]).position == stand[2],
			"%s keeps its signboard text, a pixel emblem and its entry point" % stand[0])
	check((_world.get_node("Scenery_lanterns") as MultiMeshInstance3D).multimesh.instance_count >= 30, "paper lanterns hang all over the market as one batch")
	check(_world.lamps.size() == Scenery.LAMPS.size() and _world.lamps.size() + Atmosphere.POOLS.size() <= World.ACTIVE_LAMP_LIMIT,
		"every market light fits the lit budget together with the three lantern pools")
	for phase in ["dawn", "noon", "dusk", "night"]:
		_world.set_time_of_day(phase)
		var lit: int = _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.light_energy > 0.0).size()
		var shadowed: int = _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.shadow_enabled).size()
		check(lit == _world.lamps.size() and shadowed <= World.SHADOW_LAMP_LIMIT, "lanterns stay lit at %s within the shadow budget" % phase)
		check(float(_world._scenery.props.neon_material.get_shader_parameter("energy")) >= 1.0, "neon carries the mood at %s" % phase)
	# The fixed camera sees about 19 m of ground beyond the player in every direction.
	var valley: MeshInstance3D = _world.get_node("ValleyFloor")
	var reach := (valley.mesh as PlaneMesh).size * 0.5
	check(reach.x >= World.BOUNDS.end.x + 31.0 and reach.y >= World.BOUNDS.end.y + 31.0 and reach.y >= -World.BOUNDS.position.y + 31.0,
		"ground continues past the camera's view on every side")
	check(_world.ground_surface_y(Vector3(-20, 0, -20)) == Scenery.QUARTER_Y and _world.ground_surface_y(Vector3(40, 0, 0)) == Scenery.VALLEY_Y
		and Scenery.QUARTER_Y < World.GROUND_Y and Scenery.VALLEY_Y < Scenery.QUARTER_Y, "the street sits on the paved quarter, which sits on the valley floor")
	check(_world.find_children("*", "Node", true, false).size() + 1 <= NODE_BUDGET, "the market stays inside its node budget")

## The lucky cat greets a visitor, the kitchen turns, and reduced motion stills it all.
func _check_life() -> void:
	var life: Life = _world._life
	var arm: MeshInstance3D = _world.get_node("LuckyCatArm")
	var spit: MeshInstance3D = _world.get_node("MarketRotisserie")
	var motion_shaders: Array[ShaderMaterial] = [_world._scenery.props.neon_material, _world._scenery.props.lantern_material,
		_world.material_cache["cloth:pennant"], _world.material_cache["cloth:banner"]]
	await frames(3)
	check(not life.cat_excited, "the lucky cat idles while the visitor is across the market")
	var idle_swing := await _swing(arm)
	var turned := spit.basis
	await frames(4)
	check(not spit.basis.is_equal_approx(turned), "the rotisserie turns")
	var home: Vector3 = _world.player.position
	_world.player.position = Vector3(-9.6, World.GROUND_Y, 7.2)
	await frames(3)
	check(life.cat_excited, "walking up to the shrine makes the lucky cat greet the visitor")
	check(await _swing(arm) > idle_swing * 1.5, "the greeting is a bigger wave than the idle beckon")
	var saved_count := FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH")).size()
	_world.apply_settings({"reduced_motion": true})
	await frames(2)
	turned = spit.basis
	check(is_zero_approx(await _swing(arm)) and is_equal_approx(arm.rotation.z, Life.CAT_GREETING) and spit.basis.is_equal_approx(turned),
		"reduced motion holds the kitchen still and the cat's paw raised")
	for material in motion_shaders:
		check(is_zero_approx(material.get_shader_parameter("motion")), "reduced motion stills neon, lanterns and cloth")
	_world.player.position = home
	await frames(2)
	check(not life.cat_excited and is_equal_approx(arm.rotation.z, Life.CAT_REST), "the cat lowers its paw once the visitor leaves, without animating")
	_world.apply_settings({"reduced_motion": false})
	for material in motion_shaders:
		check(is_equal_approx(material.get_shader_parameter("motion"), 1.0), "motion resumes when the setting is cleared")
	check(FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH")).size() == saved_count, "greeting the cat writes nothing to the save")
	await frames(3)

## How far the arm travels over a short while.
func _swing(arm: Node3D) -> float:
	var low := arm.rotation.z
	var high := low
	for tick in 40:
		await physics_frame
		low = minf(low, arm.rotation.z)
		high = maxf(high, arm.rotation.z)
	return high - low

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
