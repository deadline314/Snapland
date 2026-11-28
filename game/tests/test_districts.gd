extends SceneTree
## The themed districts embedded in the one island world: building, gates,
## walking reach, mechanics, light blending, streaming and the saved position.

const FieldRegistry = preload("res://game/world/field/field_registry.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")
const IslandLayout = preload("res://game/world/island_layout.gd")
const SceneryKit = preload("res://game/world/scenery_kit.gd")
## Per-district cost ceilings (MAIN-64), about 15% over what each builds
## today: nodes, drawn geometry (one draw each in the main pass), shadow casters
## (one draw per sun cascade and lamp) and merged-mesh vertices. A district
## without its own row (a new one) gets DEFAULT_BUDGET. Raise a row only with
## a measured reason in its ticket.
const DEFAULT_BUDGET := {"nodes": 450, "drawn": 320, "casters": 160, "vertices": 270000}
const DISTRICT_BUDGETS := {
	"harbor": {"nodes": 300, "drawn": 210, "casters": 110, "vertices": 60000},
	"candy": {"nodes": 240, "drawn": 190, "casters": 110, "vertices": 266000},
	"garden": {"nodes": 425, "drawn": 315, "casters": 155, "vertices": 87000},
	"nightmarket": {"nodes": 365, "drawn": 255, "casters": 135, "vertices": 186000},
	"toy": {"nodes": 355, "drawn": 257, "casters": 140, "vertices": 144000},
	"circus": {"nodes": 415, "drawn": 270, "casters": 145, "vertices": 181000},
}
const GRID := 0.5
const REACH := 2.0

var failures: Array[String] = []
var opened: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running district checks.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_check_sculpt_release()
	var world: Node3D = (load("res://game/world/park_world.gd") as GDScript).new()
	root.add_child(world)
	await process_frame
	var host: Node = world.district_host
	_check(host != null, "the island world keeps a district host")
	world.gate_opened.connect(func(region: String) -> void: opened.append(region))
	await _check_gates(world, host)
	_check_builds(world, host)
	_check_bands(host)
	_check_closed_built(world)
	_check_reach(world, host)
	_check_mechanics(world, host)
	_check_blend(world, host)
	_check_streaming(world, host)
	_check_saved_position(world, host)
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: districts build, gate, connect, blend, stream and restore")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

## Below the threshold a gate is shut, its approach cannot be walked and you
## still see in through the bars; reaching it opens the gate for good.
func _check_gates(world: Node3D, host: Node) -> void:
	world.set_sticker_count(5)
	for region: String in DistrictSites.regions():
		var gate := DistrictSites.gate_position(region)
		_check(not host.gate_is_open(region) and is_zero_approx(world.gate_leaf_angle(region)), "%s gate is shut below its threshold" % region)
		_check(not world.is_walkable(_approach_middle(region)), "%s approach is closed below its threshold" % region)
		var leaves: Array = world._gate_leaves.get(region, [])
		_check(leaves.size() == 2 and _gate_is_bars(leaves), "%s gate is two barred leaves you can see through" % region)
		_check(Vector2(gate.x, gate.z).distance_to(_nearest_road_end(region)) < 4.0, "%s gate stands at the end of its road" % region)
	_check(opened.is_empty(), "loading a save opens nothing and celebrates nothing")
	world.set_sticker_count(6)
	for region: String in DistrictSites.regions():
		var due := 6 >= RegionRoutes.threshold(region)
		_check(host.gate_is_open(region) == due, "%s gate opens exactly at %d stickers" % [region, RegionRoutes.threshold(region)])
		_check(opened.has(region) == due, "%s gate celebrates only when it opens during play" % region)
	world.set_sticker_count(60)
	# The leaves swing open with a little celebration.
	await create_timer(1.2).timeout
	for region: String in DistrictSites.regions():
		_check(host.gate_is_open(region) and world.gate_leaf_angle(region) > 1.0, "%s gate stands open at 60 stickers" % region)

func _gate_is_bars(leaves: Array) -> bool:
	var leaf: MeshInstance3D = leaves[0]
	var box := leaf.mesh.get_aabb()
	# Six thin bars over a 1 m leaf: the solid part is a small share of the face.
	return box.size.x < 1.2 and box.size.y > 1.5 and leaf.mesh.get_faces().size() <= 8 * 36

func _approach_middle(region: String) -> Vector3:
	var strip: Rect2 = DistrictSites.world_rect(region, "approach")
	var middle := strip.get_center()
	return Vector3(middle.x, 0.2, middle.y)

func _nearest_road_end(region: String) -> Vector2:
	for path: Dictionary in IslandLayout.PATHS:
		if path.id == region: return path.points[-1]
	return Vector2.INF

func _check_builds(world: Node3D, host: Node) -> void:
	# A district that cannot be built keeps its gate shut and the world running.
	var points_before: int = world.points.size()
	_check(host._build("toy", "res://game/world/missing_district.gd") == null and host.failed.has("toy") and not host.gate_is_open("toy")
		and world.find_child("GateStatus_toy", false, false).text.contains("暫停"), "a district that fails to build is skipped, its gate shut with a notice")
	_check(world.points.size() == points_before and host.built("toy") == null, "a failed district leaves no points behind")
	host.failed.erase("toy")
	for region: String in DistrictSites.regions():
		var started := Time.get_ticks_msec()
		var district: Node3D = host.ensure(region)
		_check(district != null and district.district_ready, "%s builds embedded in the island" % region)
		if district == null: continue
		print("[district] %s: %d ms, %d nodes" % [region, Time.get_ticks_msec() - started, district.find_children("*", "Node", true, false).size() + 1])
		_check(district.position == DistrictSites.origin(region), "%s stands at its site" % region)
		_check(world.is_walkable(_approach_middle(region)), "%s approach is walkable once open" % region)
		_check(district.camera == world.camera and district.sun == world.sun and district.environment == world.environment and district.player == world.player,
			"%s shares the island's walker, camera, sun and sky" % region)
		_check(district.find_children("*", "Camera3D", true, false).is_empty() and district.find_children("*", "DirectionalLight3D", true, false).is_empty()
			and district.find_children("*", "WorldEnvironment", true, false).is_empty(), "%s builds no camera, sun or sky of its own" % region)
		_check_budget(region, district)
		# Instant games and toys inside a claim carry the district's name on the
		# island but stay off the district's own list (see FieldGames.add_district).
		var field_ids: Array = FieldRegistry.games(region).map(func(row: Dictionary) -> String: return FieldRegistry.point_id(row)) 			+ FieldRegistry.toys(region).map(func(row: Dictionary) -> String: return FieldRegistry.point_id(row, true))
		var own_points: Array = world.points.filter(func(point: Dictionary) -> bool:
			return point.get("region", "") == region and not field_ids.has(String(point.id)))
		_check(own_points.size() == district.points.size() and not own_points.is_empty(), "%s lists every interaction point in the island" % region)
		for row: Dictionary in FieldRegistry.games(region) + FieldRegistry.toys(region):
			var inside := DistrictSites.claims(Vector2(DistrictSites.to_world(region, row.at).x, DistrictSites.to_world(region, row.at).z))
			var island_point: Dictionary = world._point_by_id(FieldRegistry.point_id(row, not row.has("script")))
			_check(not island_point.is_empty() and (String(island_point.get("region", "")) == region) == inside, "%s field row %s carries the district's name only inside its claim" % [region, row.id])
		_check(district.points.any(func(point: Dictionary) -> bool: return point.id == "region:welcome"), "%s keeps its free return to the plaza" % region)
		for point: Dictionary in own_points:
			var local: Dictionary = district._point_by_id(point.id)
			_check(Vector3(point.position).is_equal_approx(district.to_global(local.position)), "%s point %s sits at its world position" % [region, point.id])

## A committed sculpt lets go of its SurfaceTool: kept, it held ~270 bytes per
## vertex, a second copy of every district's merged trim (MAIN-64).
func _check_sculpt_release() -> void:
	var sculpt := SceneryKit.Sculpt.new()
	sculpt.box(Vector3.ZERO, Vector3.ONE, Color.WHITE)
	var mesh := sculpt.mesh()
	var left: Array = sculpt._tool.commit_to_arrays()
	_check(mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) == 36, "a sculpt commits its shapes")
	_check(left.is_empty() or left[Mesh.ARRAY_VERTEX] == null or (left[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(), "a committed sculpt keeps no vertices in its tool")
	_check(sculpt.mesh() == mesh, "a sculpt commits once and returns the same mesh")

## Nodes, drawn geometry, shadow casters and merged vertices stay inside the
## district's budget; the numbers print so a change can be compared.
func _check_budget(region: String, district: Node3D) -> void:
	var budget: Dictionary = DISTRICT_BUDGETS.get(region, DEFAULT_BUDGET)
	var used := {"nodes": district.find_children("*", "Node", true, false).size() + 1, "drawn": 0, "casters": 0, "vertices": 0}
	var meshes := {}
	for node: Node in district.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		used.drawn += 1
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: used.casters += 1
		var mesh: Mesh = (geometry as MeshInstance3D).mesh if geometry is MeshInstance3D else null
		if mesh is ArrayMesh and not meshes.has(mesh):
			meshes[mesh] = true
			for surface in mesh.get_surface_count(): used.vertices += (mesh as ArrayMesh).surface_get_array_len(surface)
	print("[district budget] %s %s" % [region, used])
	for key: String in used:
		_check(int(used[key]) <= int(budget[key]), "%s stays inside its %s budget (%d > %d)" % [region, key, used[key], budget[key]])

## Every district strews its own props over the island side of its band: on
## open lawn or sand, outside every claim, never overlapping, and where two
## bands meet each prop stands on ground its own district holds.
func _check_bands(host: Node) -> void:
	var everything: Array = []
	for region: String in DistrictSites.regions():
		var district: Node3D = host.built(region)
		if district == null: continue
		var props: Array = district.get_meta(&"band_props", [])
		_check(props.size() >= 4 and district.find_child("BandProps", false, false) != null, "%s dresses its band with props (%d)" % [region, props.size()])
		for prop: Dictionary in props:
			var at: Vector2 = prop.at
			_check(not DistrictSites.claims(at) and not IslandLayout.on_path(at) and DistrictSites.holds(region, at),
				"%s band prop %s at %s stands on open island ground its district holds" % [region, prop.kind, at])
			prop.region = region
			everything.append(prop)
	for index in everything.size():
		for other in range(index + 1, everything.size()):
			var a: Dictionary = everything[index]
			var b: Dictionary = everything[other]
			_check((a.at as Vector2).distance_to(b.at) >= float(a.radius) + float(b.radius),
				"band props %s %s and %s %s overlap" % [a.region, a.kind, b.region, b.kind])

## Closed gates hold even once the district behind them is built.
func _check_closed_built(world: Node3D) -> void:
	world.set_sticker_count(0)
	for region: String in DistrictSites.regions():
		_check(not world.is_walkable(_approach_middle(region)), "%s approach stays shut behind a closed gate after it is built" % region)
	world.set_sticker_count(60)

## Every interaction point of every district can be reached on foot from the
## plaza, over ground the walking rules allow.
func _check_reach(world: Node3D, _host: Node) -> void:
	var bounds := IslandShape.bounds()
	var columns := int(bounds.size.x / GRID) + 1
	var rows := int(bounds.size.y / GRID) + 1
	var seen := PackedByteArray()
	seen.resize(columns * rows)
	var queue := PackedInt32Array()
	var start := Vector2i(((Vector2(world.PLAZA_ARRIVAL.x, world.PLAZA_ARRIVAL.z) - bounds.position) / GRID).round())
	_check(world.is_walkable(world.PLAZA_ARRIVAL), "the plaza arrival point is walkable")
	queue.append(start.y * columns + start.x)
	seen[start.y * columns + start.x] = 2
	var head := 0
	var started := Time.get_ticks_msec()
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var x := cell % columns
		var y := cell / columns
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + step.x
			var ny := y + step.y
			if nx < 0 or ny < 0 or nx >= columns or ny >= rows: continue
			var index := ny * columns + nx
			if seen[index] != 0: continue
			var at := bounds.position + Vector2(nx, ny) * GRID
			if world.is_walkable(Vector3(at.x, 0.2, at.y)):
				seen[index] = 2
				queue.append(index)
			else:
				seen[index] = 1
	print("[district] flood fill: %d walkable cells in %d ms" % [queue.size(), Time.get_ticks_msec() - started])
	for point: Dictionary in world.points:
		if not point.has("region"): continue
		var spot := Vector2(point.position.x, point.position.z)
		_check(_reached(seen, bounds, columns, rows, spot), "%s point %s can be reached on foot from the plaza" % [point.region, point.id])
	for region: String in DistrictSites.regions():
		var arrival := DistrictSites.arrival(region)
		_check(_reached(seen, bounds, columns, rows, Vector2(arrival.x, arrival.z)), "%s arrival point is on the walk from the plaza" % region)

func _reached(seen: PackedByteArray, bounds: Rect2, columns: int, rows: int, spot: Vector2) -> bool:
	var centre := Vector2i(((spot - bounds.position) / GRID).round())
	var span := int(ceil(REACH / GRID))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows: continue
			if Vector2(dx, dy).length() * GRID > REACH: continue
			if seen[cell.y * columns + cell.x] == 2: return true
	return false

## Each district's own mechanics still answer when embedded.
func _check_mechanics(world: Node3D, host: Node) -> void:
	var harbor: Node3D = host.built("harbor")
	var tide: bool = harbor.is_high_tide()
	harbor.set_tide(not tide)
	_check(harbor.is_high_tide() != tide, "harbor tide turns embedded")
	harbor.take_ferry("harbor:ferry:shore")
	_check(world.player.global_position.distance_to(harbor.to_global(harbor.LIGHTHOUSE_DOCK)) < 0.05, "harbor ferry carries the island walker to the lighthouse")
	var candy: Node3D = host.built("candy")
	var temperature: int = candy.map_snapshot().temperature
	candy.cycle_temperature()
	_check(candy.map_snapshot().temperature != temperature, "candy temperature cycles embedded")
	var garden: Node3D = host.built("garden")
	var detent: int = garden.louver_detent()
	garden.switch_louvers()
	_check(garden.louver_detent() != detent, "greenhouse louvers turn to the next sun level embedded")
	var toy: Node3D = host.built("toy")
	var branch: int = toy.train_state().branch
	toy.switch_tracks()
	_check(toy.train_state().branch != branch, "toy railway switches branch embedded")
	var market: Node3D = host.built("nightmarket")
	var status: String = market.market_status()
	market.cycle_market()
	_check(market.market_status() != status, "night market opens and closes embedded")
	var circus: Node3D = host.built("circus")
	var side: int = circus.projection_side()
	circus.switch_projection()
	_check(circus.projection_side() != side, "circus projection switches embedded")
	var hotel: Node3D = host.built("hotel")
	_check(hotel.ring_bell().contains("歡迎") and hotel._life._ring > 0.0, "the hotel desk bell rings embedded")
	var sky: Node3D = host.built("sky")
	_check(sky.push_wheel().contains("摩天輪") and sky._life._push > 0.0, "the sky park's wheel answers a push embedded")
	var cinema: Node3D = host.built("cinema")
	_check(cinema.walk_carpet().contains("紅毯") and cinema._life._carpet > 0.0, "the cinema's red carpet answers a walk embedded")
	world.place_player(DistrictSites.arrival("candy"))
	candy.reset_to_entry()
	_check(world.player.global_position.distance_to(candy.to_global(candy.ENTRY)) < 0.05, "candy reset returns the island walker to the factory entry")

## Light and air follow the district weights at the walker: shares sum to one,
## change monotonically across a band, and walking allocates nothing.
func _check_blend(world: Node3D, host: Node) -> void:
	world.set_time_of_day("noon")
	for region: String in DistrictSites.regions():
		var claim := DistrictSites.world_rect(region, "claim")
		var from := Vector2(claim.get_center().x, claim.end.y + DistrictSites.BAND + 4.0)
		var to := Vector2(claim.get_center().x, claim.end.y - 1.0)
		var last_share := -1.0
		var last_gap := INF
		var island_air: Dictionary = world.air_target
		var district_air: Dictionary = host.built(region).air_target
		var monotonic := true
		var nodes_before := world.find_children("*", "Node", true, false).size()
		var cache_before: int = world.material_cache.size()
		for step in range(41):
			var at := from.lerp(to, float(step) / 40.0)
			host.track(Vector3(at.x, 0.2, at.y), 0.0)
			var weights: Dictionary = world.district_weights()
			var total := 0.0
			for share: float in weights.values(): total += share
			_check(is_equal_approx(total, 1.0), "%s shares of light sum to one (%.3f)" % [region, total])
			var share := float(weights[region])
			var gap := _air_gap(world.environment, district_air)
			if share < last_share - 0.0001 or gap > last_gap + 0.0001: monotonic = false
			last_share = share
			last_gap = gap
		_check(monotonic, "%s sky, fog and fill change monotonically across its band" % region)
		_check(is_equal_approx(last_share, 1.0) and _air_gap(world.environment, district_air) < 0.01, "%s air is its own inside its claim" % region)
		_check(_air_gap_targets(island_air, district_air) > 0.03, "%s has its own air to blend toward" % region)
		_check(world.find_children("*", "Node", true, false).size() == nodes_before and world.material_cache.size() == cache_before, "walking into %s allocates no nodes or materials" % region)
	# The band is at least ten metres and wanders, so no edge is straight.
	_check(DistrictSites.BAND >= 10.0 and DistrictSites.EDGE_WOBBLE > 0.0, "transition bands are at least ten metres with a broken edge")
	var claim := DistrictSites.world_rect("candy", "claim")
	var edge_spread := 0.0
	for step in range(12):
		var probe := Vector2(claim.position.x + 4.0 + step * 4.0, claim.end.y + DistrictSites.BAND * 0.5)
		edge_spread = maxf(edge_spread, absf(DistrictSites.ground_weight("candy", probe) - DistrictSites.weight("candy", probe)))
	_check(edge_spread > 0.05, "ground and planting edges are noise-broken, not straight (%.2f)" % edge_spread)
	world.set_time_of_day("night")
	var market := DistrictSites.world_rect("nightmarket", "claim").get_center()
	host.track(Vector3(market.x, 0.2, market.y), 0.0)
	_check(_color_gap(world.environment.background_color, host.built("nightmarket").air_target.sky) < 0.01, "the night market keeps its own night sky inside its valley")
	world.set_time_of_day("noon")

func _air_gap(environment: Environment, target: Dictionary) -> float:
	return _color_gap(environment.background_color, target.sky) + _color_gap(environment.fog_light_color, target.fog) + _color_gap(environment.ambient_light_color, target.ambient)

func _air_gap_targets(a: Dictionary, b: Dictionary) -> float:
	return _color_gap(a.sky, b.sky) + _color_gap(a.fog, b.fog) + _color_gap(a.ambient, b.ambient) + absf(float(a.saturation) - float(b.saturation))

func _color_gap(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

## Far districts sleep (no process, no draw, no lamps); near ones wake; at night
## the lamp budget holds anywhere along a walk across a boundary.
func _check_streaming(world: Node3D, host: Node) -> void:
	world.set_time_of_day("night")
	var plaza: Vector3 = world.PLAZA_ARRIVAL
	host.track(plaza, DistrictSites.ACTIVE_RADIUS)
	for region: String in DistrictSites.regions():
		var gap := DistrictSites.distance(region, Vector2(plaza.x, plaza.z))
		var district: Node3D = host.built(region)
		if gap > DistrictSites.DORMANT_RADIUS:
			_check(district.process_mode == Node.PROCESS_MODE_DISABLED and not district.visible, "%s sleeps %.0f m from the plaza" % [region, gap])
	for region: String in DistrictSites.regions():
		var claim := DistrictSites.world_rect(region, "claim")
		var from := Vector2(claim.get_center().x, claim.end.y + 30.0)
		var to := claim.get_center()
		for step in range(16):
			var at := from.lerp(to, float(step) / 15.0)
			world.player.global_position = Vector3(at.x, 0.2, at.y)
			host.track(world.player.global_position, DistrictSites.ACTIVE_RADIUS)
			world._update_lamp_selection(true)
			var lit: int = host.steady_lights()
			var shadowed := 0
			for lamp: Light3D in world.lamps:
				if lamp.light_energy > 0.0 and lamp.is_visible_in_tree(): lit += 1
				if lamp.shadow_enabled: shadowed += 1
			_check(lit <= world.ACTIVE_LAMP_LIMIT and shadowed <= world.SHADOW_LAMP_LIMIT, "lamp budget holds walking into %s (%d lit, %d shadowed)" % [region, lit, shadowed])
		_check(host.is_awake(region), "%s wakes when the walker arrives" % region)
		for other: String in DistrictSites.regions():
			if DistrictSites.distance(other, to) > DistrictSites.DORMANT_RADIUS:
				_check(not host.is_awake(other), "%s sleeps while the walker is in %s" % [other, region])
	world.set_time_of_day("noon")

## The save keeps the walker's spot; a spot that is no longer ground, and an old
## save with no spot at all, land at the district's arrival point.
func _check_saved_position(world: Node3D, host: Node) -> void:
	var progress: Node = root.get_node("Progress")
	var spot := Vector3.INF
	for point: Dictionary in world.points:
		var at: Vector3 = point.position
		if point.get("region", "") == "garden" and world.is_walkable(at) and at.distance_to(DistrictSites.arrival("garden")) > 3.0:
			spot = at
			break
	_check(spot.is_finite(), "the greenhouse has a walkable spot away from its arrival point")
	progress.player_position = spot
	progress.current_region = "garden"
	_check(progress.save_progress(), "a save with a position is written")
	progress.player_position = Vector3.INF
	progress.load_progress()
	_check(progress.player_position.is_equal_approx(spot), "the saved position loads back")
	world.restore_walker(progress.player_position, "garden")
	_check(world.player.global_position.distance_to(spot) < 0.1 and world.standing_region() == "garden", "a valid saved spot is restored and the region follows it")
	var sea := Vector3(0, 0.2, 140.0)
	world.restore_walker(sea, "toy")
	_check(world.player.global_position.distance_to(DistrictSites.arrival("toy") + Vector3(0, 0.05, 0)) < 0.1 and world.standing_region() == "toy", "a spot in the sea lands at the district's arrival point")
	var file := FileAccess.open(progress._save_path(), FileAccess.READ)
	var payload: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	payload.erase("player_position")
	payload["current_region"] = "circus"
	progress._apply_save(payload)
	_check(not progress.player_position.is_finite() and progress.current_region == "circus", "an old save without a position loads as unknown")
	world.restore_walker(progress.player_position, progress.current_region)
	_check(world.player.global_position.distance_to(DistrictSites.arrival("circus") + Vector3(0, 0.05, 0)) < 0.1 and world.standing_region() == "circus", "an old save lands at its district's arrival point")
	for bad: Variant in [[1, 2], ["a", 1, 2], [INF, 0, 0], [5000, 0, 0], "x"]:
		_check(not progress._loaded_position(bad).is_finite(), "a malformed saved position %s is ignored" % str(bad))
