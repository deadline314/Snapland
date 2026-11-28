extends RefCounted
## Builds the Welcome island's ground and soft scenery from IslandShape and
## IslandLayout: sea, beach, lawn, walkways, ponds, planting and small place
## dressing. Repeated pieces are batched; nothing here runs after the build.

const IslandShape = preload("res://game/world/island_shape.gd")
const IslandLayout = preload("res://game/world/island_layout.gd")
const SceneryKit = preload("res://game/world/scenery_kit.gd")

const SEA_SIZE := Vector2(480, 480)
const SEA_Y := -0.42
## The flat beach stops this far inside the waterline, then slopes under the sea.
const BEACH_RIM := 0.7
const BEACH_FOOT_Y := -0.61
const PATH_SKIRT := 0.16
## Trails sit a hair under the main paving and clearings a hair over it, so
## overlapping walkways never share a plane.
const SURFACE_TOP := {"paving": 0.18, "trail": 0.17, "boardwalk": 0.186}
const CLEARING_TOP := 0.192
const POND_WATER_Y := 0.12
const ROCK_CLUSTER_SPACING := 80.0
const TREE_SPACING := 3.4
const PATH_TREE_INTERVAL := 15.0

static var _sites: Array[Vector3] = []

static func build_ground(world: Node3D) -> void:
	_build_sea(world)
	_build_beach(world)
	_build_lawn(world)
	_build_paving(world)
	_build_ponds(world)

static func _build_sea(world: Node3D) -> void:
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = SEA_SIZE
	# Centred on the land, so the sea stays wide on every side as the island grows.
	var middle := IslandShape.bounds().get_center()
	world._mesh(sea_mesh, Vector3(middle.x, SEA_Y, middle.y), world.welcome_sea_material).name = "WelcomeBayWater"

static func _build_beach(world: Node3D) -> void:
	# The beach is the land itself: a flat top just under the lawn whose rim
	# slopes below the water, so the bay's foam meets wet sand all the way round.
	var top := _largest(Geometry2D.offset_polygon(IslandShape.coast(), -BEACH_RIM, Geometry2D.JOIN_ROUND))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	_add_flat_polygon(top, IslandLayout.BEACH_TOP_Y, vertices, normals, indices)
	var count := top.size()
	var slope := BEACH_RIM + 0.3
	for index in count:
		var outward := -(top[(index + 1) % count] - top[(index - 1 + count) % count]).normalized().orthogonal()
		if not Geometry2D.is_polygon_clockwise(top): outward = -outward
		var foot := top[index] + outward * slope
		var normal := Vector3(outward.x * (IslandLayout.BEACH_TOP_Y - BEACH_FOOT_Y), slope, outward.y * (IslandLayout.BEACH_TOP_Y - BEACH_FOOT_Y)).normalized()
		vertices.append(Vector3(top[index].x, IslandLayout.BEACH_TOP_Y, top[index].y))
		vertices.append(Vector3(foot.x, BEACH_FOOT_Y, foot.y))
		normals.append(normal)
		normals.append(normal)
	var skirt := vertices.size() - count * 2
	for index in count:
		var here := skirt + index * 2
		var next := skirt + ((index + 1) % count) * 2
		_add_quad(vertices, indices, here, next, next + 1, here + 1)
	var beach: MeshInstance3D = world._mesh(_array_mesh(vertices, normals, indices), Vector3.ZERO, world._beach_material())
	beach.name = "WelcomeBeach"
	beach.set_meta("top_outline", top)

static func _build_lawn(world: Node3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for outline in IslandShape.lawns():
		_add_flat_polygon(outline, 0.0, vertices, normals, indices)
	var grass := ShaderMaterial.new()
	grass.shader = world.GRASS
	world.material_cache["welcome-lawn"] = grass
	world._mesh(_array_mesh(vertices, normals, indices), Vector3(0, IslandLayout.LAWN_Y, 0), grass).name = "WelcomeLawn"

static func _build_paving(world: Node3D) -> void:
	var stone: Material = world._coastal_surface(4, 3.0, Color("#ddd8c8"))
	for slab: Rect2 in [IslandLayout.STEM, IslandLayout.PLAZA]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(slab.size.x, 0.12, slab.size.y)
		world._mesh(mesh, Vector3(slab.get_center().x, 0.12, slab.get_center().y), stone)
	var materials := {
		"paving": stone,
		"trail": world._coastal_surface(4, 3.8, Color("#c9c4ac")),
		"boardwalk": world._coastal_surface(1, 1.8, Color("#ead8b4")),
	}
	for surface: String in materials:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		for path in IslandLayout.paths():
			if path.surface == surface:
				_add_ribbon(path.line, float(path.width), float(SURFACE_TOP[surface]), vertices, normals, indices)
		var ribbons: MeshInstance3D = world._mesh(_array_mesh(vertices, normals, indices), Vector3.ZERO, materials[surface])
		ribbons.name = "IslandWalkway_" + surface
		ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0 + PATH_SKIRT * 0.4
	disc.height = 1.0
	disc.radial_segments = 28
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var depth := CLEARING_TOP - IslandLayout.LAWN_Y
	for clearing in IslandLayout.clearings():
		transforms.append(Transform3D(Basis().scaled(Vector3(clearing.z, depth, clearing.z)), Vector3(clearing.x, CLEARING_TOP - depth * 0.5, clearing.y)))
		colors.append(Color.WHITE)
	var clearings: MultiMeshInstance3D = world._multi_mesh(disc, Vector3.ZERO, transforms, colors, stone)
	clearings.name = "IslandClearings"
	clearings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _build_ponds(world: Node3D) -> void:
	var bank_material: Material = world._coastal_surface(0, 1.8, Color("#cbb995"))
	var stone_mesh := SphereMesh.new()
	stone_mesh.radial_segments = 8
	stone_mesh.rings = 4
	var reed_mesh := BoxMesh.new()
	var stones: Array[Transform3D] = []
	var stone_colors: Array[Color] = []
	var reeds: Array[Transform3D] = []
	var reed_colors: Array[Color] = []
	for pond_index in IslandLayout.PONDS.size():
		var pond: Vector3 = IslandLayout.PONDS[pond_index]
		var center := Vector3(pond.x, 0, pond.y)
		var radius := pond.z
		var water := CylinderMesh.new()
		water.top_radius = radius
		water.bottom_radius = radius
		water.height = 0.06
		water.radial_segments = 32
		var surface: MeshInstance3D = world._mesh(water, center + Vector3(0, POND_WATER_Y - 0.03, 0), world.sea_material)
		surface.name = "IslandPond%d" % pond_index
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A sloped stone bank keeps the lawn off the water and stands above it.
		world._mesh(_bank_mesh(radius - 0.05, radius + 1.0, POND_WATER_Y + 0.05, IslandLayout.LAWN_Y + 0.004), center, bank_material).name = "IslandPondBank%d" % pond_index
		var body := StaticBody3D.new()
		body.name = "IslandPondEdge%d" % pond_index
		body.position = center + Vector3(0, 0.75, 0)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius - 0.15
		cylinder.height = 1.5
		shape.shape = cylinder
		body.add_child(shape)
		world.add_child(body)
		for index in 15:
			var angle := TAU * float(index) / 15.0 + _hash(pond_index * 31 + index) * 0.3
			var size := 0.22 + _hash(pond_index * 57 + index * 3) * 0.2
			var spot := center + Vector3(cos(angle), 0, sin(angle)) * (radius + 0.25 + _hash(index * 7 + pond_index) * 0.4)
			stones.append(Transform3D(Basis().rotated(Vector3.UP, angle * 1.7).scaled(Vector3(size * 1.4, size * 0.55, size)), spot + Vector3(0, 0.16, 0)))
			stone_colors.append([Color("#897f6a"), Color("#9b927c"), Color("#70877a")][index % 3])
			if index % 3 != 0: continue
			for blade in 4:
				var lean := (float(blade) - 1.5) * 0.16
				var foot := center + Vector3(cos(angle + 0.2), 0, sin(angle + 0.2)) * (radius - 0.45) + Vector3(float(blade) * 0.11, 0, 0)
				var height := 0.7 + _hash(index * 13 + blade) * 0.45
				reeds.append(Transform3D(Basis().rotated(Vector3.FORWARD, lean).scaled(Vector3(0.07, height, 0.05)), foot + Vector3(0, POND_WATER_Y + height * 0.5, 0)))
				reed_colors.append(Color("#557961") if blade % 2 == 0 else Color("#6f8f5f"))
	world._multi_mesh(stone_mesh, Vector3.ZERO, stones, stone_colors, world._vertex_color_material("pond-bank-stones", 0.9, true)).name = "IslandPondStones"
	world._multi_mesh(reed_mesh, Vector3.ZERO, reeds, reed_colors, world._vertex_color_material("pond-reeds", 0.9, true)).name = "IslandPondReeds"

## Tide-pool rocks in loose groups on the sand all round the coast, except
## beside the dock and where a district dresses its own shore, with tufts of
## sea grass between some of them (all the tufts are two batched draws).
static func build_shore_rocks(world: Node3D) -> void:
	var coast := IslandShape.coast()
	var blades: Array[Transform3D] = []
	var blade_colors: Array[Color] = []
	var buds: Array[Transform3D] = []
	var bud_colors: Array[Color] = []
	var travelled := ROCK_CLUSTER_SPACING * 0.4
	var cluster := 0
	for index in coast.size():
		var here := coast[index]
		var next := coast[(index + 1) % coast.size()]
		travelled += here.distance_to(next)
		if travelled < ROCK_CLUSTER_SPACING: continue
		travelled = 0.0
		var along := (next - here).normalized()
		var inland := IslandShape.inland_direction(here)
		if absf(here.x) < 12.0 and here.y > 12.0: continue
		if IslandShape.DistrictSites.dresses_shore(here): continue
		var rocks := 2 + cluster % 2
		for rock in rocks:
			var spot := here + inland * (1.25 + _hash(cluster * 11 + rock) * 0.25) + along * (float(rock) - float(rocks - 1) * 0.5) * 1.1
			if IslandShape.distance_to_coast(spot) < 0.6 or IslandShape.lawn_inset(spot) > -0.3 or IslandLayout.on_path(spot): continue
			world._add_shore_rock(Vector3(spot.x, 0, spot.y), cluster * 5 + rock)
		if cluster % 3 == 1:
			var tuft := here + inland * 1.7 + along * 1.6
			if IslandShape.lawn_inset(tuft) < -0.2 and IslandShape.distance_to_coast(tuft) > 0.8 and not IslandLayout.on_path(tuft):
				var foot := Vector3(tuft.x, IslandLayout.BEACH_TOP_Y, tuft.y)
				for blade in 3:
					blades.append(Transform3D(Basis(Vector3.BACK, float(blade - 1) * 0.22).scaled(Vector3(0.09, 0.82, 0.07)), foot + Vector3(float(blade - 1) * 0.12, 0.4, 0)))
					blade_colors.append(Color("#557961"))
				if cluster % 2 == 0:
					buds.append(Transform3D(Basis().scaled(Vector3.ONE * 0.24), foot + Vector3(0, 0.82, 0)))
					bud_colors.append(Color("#da705c"))
		cluster += 1
	_dress_sand_spit(blades, blade_colors, buds, bud_colors)
	_build_sand_castle(world)
	var blade_mesh := BoxMesh.new()
	var bud_mesh := SphereMesh.new()
	bud_mesh.radial_segments = 8
	bud_mesh.rings = 4
	world._multi_mesh(blade_mesh, Vector3.ZERO, blades, blade_colors, world._vertex_color_material("sea-grass", 0.9, true)).name = "IslandSeaGrass"
	world._multi_mesh(bud_mesh, Vector3.ZERO, buds, bud_colors, world._vertex_color_material("sea-grass", 0.9, true)).name = "IslandSeaGrassBuds"

const LAWN_SHRUBS := [Vector2(51, -13), Vector2(55, -10), Vector2(67, -12), Vector2(64, -8), Vector2(47, -3)]

## The lagoon's sand spit: the widest bare sand on the island (ART-71).
const SAND_SPIT := Vector3(80, -135, 14)
const CASTLE_SPOTS := [Vector2(76, -132), Vector2(72, -133), Vector2(79, -131), Vector2(70, -140)]

static func _on_open_sand(spot: Vector2) -> bool:
	return IslandShape.lawn_inset(spot) < -0.3 and IslandShape.distance_to_coast(spot) > 0.8 and not IslandLayout.on_path(spot, 0.6) 		and IslandLayout.district_surface_y(spot) < 0.0 and not IslandLayout.keeps_clear(spot) and not IslandShape.DistrictSites.claims(spot)

## Beachcombing on the spit: shells, bleached driftwood and sea-grass tufts,
## added to the shore's two batched draws instead of new nodes.
static func _dress_sand_spit(blades: Array[Transform3D], blade_colors: Array[Color], buds: Array[Transform3D], bud_colors: Array[Color]) -> void:
	var shells: Array[Color] = [Color("#f4e6d2"), Color("#e89a86"), Color("#e2c48f"), Color("#c9705f")]
	var attempts := 90
	for index in attempts:
		var angle := float(index) * 2.39996
		var spot := Vector2(SAND_SPIT.x, SAND_SPIT.y) + Vector2.from_angle(angle) * SAND_SPIT.z * sqrt((float(index) + 0.5) / float(attempts))
		if not _on_open_sand(spot): continue
		var foot := Vector3(spot.x, IslandLayout.BEACH_TOP_Y, spot.y)
		var turn := Basis(Vector3.UP, angle * 1.7)
		match index % 6:
			0, 2, 4:
				var size := 0.8 + _hash(index * 5) * 0.6
				buds.append(Transform3D(turn.scaled(Vector3(0.32, 0.09, 0.24) * size), foot + Vector3(0, 0.04, 0)))
				bud_colors.append(shells[index % shells.size()])
			1:
				var length := 1.3 + _hash(index * 13) * 1.0
				blades.append(Transform3D(turn.rotated(Vector3.FORWARD, 0.05).scaled(Vector3(length, 0.16, 0.2)), foot + Vector3(0, 0.08, 0)))
				blade_colors.append(Color("#8b7355"))
			3:
				for blade in 3:
					blades.append(Transform3D(Basis(Vector3.BACK, float(blade - 1) * 0.25).scaled(Vector3(0.08, 0.6, 0.06)), foot + Vector3(float(blade - 1) * 0.11, 0.3, 0)))
					blade_colors.append(Color("#5f7f52"))

## A half-finished sand castle someone left by the water: one small draw that
## gives the spit something to walk over and look at.
static func _build_sand_castle(world: Node3D) -> void:
	for spot: Vector2 in CASTLE_SPOTS:
		if not _on_open_sand(spot): continue
		var castle := SceneryKit.Sculpt.new()
		var sand := Color("#e2c48a")
		var wet := Color("#c9a46b")
		castle.tube(Vector3(0, 0.08, 0), 1.05, 0.95, 0.16, wet, 12)
		castle.box(Vector3(0, 0.36, 0), Vector3(0.9, 0.44, 0.9), sand)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var at := Vector3(corner.x * 0.48, 0, corner.y * 0.48)
			castle.tube(at + Vector3(0, 0.36, 0), 0.24, 0.2, 0.56, sand, 8)
			castle.tube(at + Vector3(0, 0.74, 0), 0.2, 0.0, 0.2, wet, 8)
		# Battlements: two merlons on each side of the keep's top.
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			for step in [-0.18, 0.18]:
				var along: Vector2 = Vector2(-side.y, side.x) * float(step)
				castle.box(Vector3(side.x * 0.4 + along.x, 0.63, side.y * 0.4 + along.y), Vector3(0.12, 0.1, 0.12), sand)
		# A driftwood stick and a coral rag for a flag on the keep.
		castle.box(Vector3(0, 0.88, 0), Vector3(0.04, 0.6, 0.04), Color("#8a6f52"))
		castle.sheet(Vector3(0.02, 1.16, 0), Vector3(0.36, 1.08, 0), Vector3(0.02, 0.98, 0), Color("#e0705c"))
		var foot := Vector3(spot.x, IslandLayout.BEACH_TOP_Y, spot.y)
		var mesh: MeshInstance3D = world._mesh(castle.mesh(), foot, world._vertex_color_material("sand-castle"))
		mesh.name = "SpitSandCastle"
		mesh.rotation.y = 0.5
		return

## Groves, trees beside the walkways and flower meadows. Every site is checked
## against paths, courts, ponds and the shore, so the tables can stay loose.
static func build_planting(world: Node3D) -> void:
	for site in _tree_sites():
		world._tree(Vector3(site.x, 0, site.y), int(site.z), true)
	_build_meadows(world)
	# Flowering shrubs give the open lawn east of the plaza something to walk between (ART-71).
	for spot: Vector2 in LAWN_SHRUBS:
		if IslandLayout.tree_site_clear(spot): world._shrub_cluster(Vector3(spot.x, IslandLayout.LAWN_Y, spot.y), spot.x * 0.37)

## Every tree as x, z, seed. The search runs once per process: the tables and
## the shore never change, so every Welcome world plants the same trees.
static func _tree_sites() -> Array[Vector3]:
	if not _sites.is_empty(): return _sites
	var taken := {}
	for grove_index in IslandLayout.GROVES.size():
		var grove: Vector4 = IslandLayout.GROVES[grove_index]
		var planted := 0
		var tries := int(grove.w) * 4
		for attempt in tries:
			if planted >= int(grove.w): break
			var angle := float(attempt) * 2.39996 + float(grove_index) * 0.7
			var spot := Vector2(grove.x, grove.y) + Vector2.from_angle(angle) * grove.z * sqrt((float(attempt) + 0.5) / float(tries))
			if _claim_site(taken, spot, grove_index * 17 + attempt): planted += 1
	for path_index in IslandLayout.paths().size():
		var path: Dictionary = IslandLayout.paths()[path_index]
		var line: PackedVector2Array = path.line
		var travelled := PATH_TREE_INTERVAL * (0.3 + _hash(path_index) * 0.5)
		var side := 1.0 if path_index % 2 == 0 else -1.0
		for index in range(1, line.size()):
			travelled += line[index].distance_to(line[index - 1])
			if travelled < PATH_TREE_INTERVAL: continue
			travelled = _hash(path_index * 41 + index) * 5.0
			var across := (line[index] - line[index - 1]).normalized().orthogonal()
			_claim_site(taken, line[index] + across * side * (float(path.width) * 0.5 + 2.7 + _hash(index * 5 + path_index) * 1.6), path_index * 19 + index)
			side = -side
	# The palms that frame the plaza keep their places.
	for side: float in [-1.0, 1.0]:
		for row in [8, 9, 11, 12, 13]:
			_claim_site(taken, Vector2(side * (16.0 + sin(float(row) * 1.2) * 1.8), -44.0 + float(row) * 4.5), row)
	return _sites

## Accepts `spot` when it is open lawn and no other tree stands within
## TREE_SPACING. `taken` buckets the accepted sites by spacing-sized cell.
static func _claim_site(taken: Dictionary, spot: Vector2, seed_value: int) -> bool:
	var cell := Vector2i((spot / TREE_SPACING).floor())
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var other: Variant = taken.get(cell + Vector2i(dx, dz))
			if other != null and (other as Vector2).distance_squared_to(spot) < TREE_SPACING * TREE_SPACING: return false
	if not IslandLayout.tree_site_clear(spot): return false
	taken[cell] = spot
	_sites.append(Vector3(spot.x, spot.y, seed_value))
	return true

static func _build_meadows(world: Node3D) -> void:
	var blade_mesh := BoxMesh.new()
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.13
	flower_mesh.height = 0.26
	flower_mesh.radial_segments = 8
	flower_mesh.rings = 4
	var blades: Array[Transform3D] = []
	var blade_colors: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var palette: Array[Color] = [Color("#d98768"), Color("#e6ce8f"), Color("#f0e6d2"), Color("#c98fb0"), Color("#8fb6d8")]
	for meadow_index in IslandLayout.MEADOWS.size():
		var meadow: Vector3 = IslandLayout.MEADOWS[meadow_index]
		var count := int(meadow.z * meadow.z * 0.55)
		for index in count:
			var angle := float(index) * 2.39996 + float(meadow_index)
			var spot := Vector2(meadow.x, meadow.y) + Vector2.from_angle(angle) * meadow.z * sqrt((float(index) + 0.5) / float(count)) + Vector2(_hash(index * 3 + meadow_index) - 0.5, _hash(index * 7 + meadow_index) - 0.5) * 0.9
			if not IslandShape.on_lawn(spot, 0.6) or IslandLayout.on_path(spot) or IslandLayout.in_pond(spot, 1.2) or IslandLayout.district_surface_y(spot) >= 0.0: continue
			var height := 0.26 + _hash(index * 11 + meadow_index * 5) * 0.2
			var base := Vector3(spot.x, IslandLayout.LAWN_Y, spot.y)
			blades.append(Transform3D(Basis().rotated(Vector3.UP, angle).rotated(Vector3.FORWARD, (_hash(index) - 0.5) * 0.3).scaled(Vector3(0.06, height, 0.05)), base + Vector3(0, height * 0.5, 0)))
			blade_colors.append(Color("#547a58") if index % 2 == 0 else Color("#76905c"))
			var bloom := 0.55 + _hash(index * 17 + meadow_index) * 0.5
			flowers.append(Transform3D(Basis().scaled(Vector3(bloom, bloom * 0.55, bloom)), base + Vector3(0, height + 0.03, 0)))
			flower_colors.append(palette[(index + meadow_index * 2 + int(_hash(index * 29) * 2.0)) % palette.size()])
	var stems: MultiMeshInstance3D = world._multi_mesh(blade_mesh, Vector3.ZERO, blades, blade_colors, world._vertex_color_material("coastal-pocket-leaves", 0.9, true))
	stems.name = "IslandMeadowStems"
	stems.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blooms: MultiMeshInstance3D = world._multi_mesh(flower_mesh, Vector3.ZERO, flowers, flower_colors, world._vertex_color_material("coastal-pocket-flowers", 0.9, true))
	blooms.name = "IslandMeadowFlowers"
	blooms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A sign frame behind every free-standing game entry holds its floating emblem,
## so the entry reads as a little station instead of a marker over bare grass.
static func build_entry_frames(world: Node3D) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for entry: Dictionary in IslandLayout.GAME_ENTRIES:
		if entry.has("district"): continue
		var origin: Vector3 = entry.position + Vector3(0, IslandLayout.LAWN_Y, -1.9)
		for side: float in [-1.0, 1.0]:
			transforms.append(Transform3D(Basis().scaled(Vector3(0.34, 0.3, 0.34)), origin + Vector3(side * 1.25, 0.15, 0)))
			transforms.append(Transform3D(Basis().scaled(Vector3(0.13, 2.55, 0.13)), origin + Vector3(side * 1.25, 1.5, 0)))
			transforms.append(Transform3D(Basis().scaled(Vector3(0.3, 0.1, 0.3)), origin + Vector3(side * 1.25, 2.82, 0)))
		transforms.append(Transform3D(Basis().scaled(Vector3(3.0, 0.14, 0.16)), origin + Vector3(0, 2.62, 0)))
	colors.resize(transforms.size())
	colors.fill(Color.WHITE)
	world._multi_mesh(BoxMesh.new(), Vector3.ZERO, transforms, colors, world._wood_material(Color("#8a6a48"))).name = "IslandEntryFrames"

static func _largest(outlines: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	for outline: PackedVector2Array in outlines:
		if outline.size() > best.size(): best = outline
	return best

static func _hash(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898 + 4.1) * 43758.5453, 1.0)

static func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Godot's front faces wind clockwise; every triangle added here faces up.
static func _add_triangle(vertices: PackedVector3Array, indices: PackedInt32Array, a: int, b: int, c: int) -> void:
	var up := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).y > 0.0
	indices.append(a)
	indices.append(b if up else c)
	indices.append(c if up else b)

static func _add_quad(vertices: PackedVector3Array, indices: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	_add_triangle(vertices, indices, a, b, c)
	_add_triangle(vertices, indices, a, c, d)

static func _add_flat_polygon(outline: PackedVector2Array, y: float, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	var base := vertices.size()
	for point in outline:
		vertices.append(Vector3(point.x, y, point.y))
		normals.append(Vector3.UP)
	var triangles := Geometry2D.triangulate_polygon(outline)
	for index in range(0, triangles.size(), 3):
		_add_triangle(vertices, indices, base + triangles[index], base + triangles[index + 1], base + triangles[index + 2])

## A walkway strip along `line` with a short sloped edge on both sides and
## rounded ends, so a path never ends in a square cut.
static func _add_ribbon(line: PackedVector2Array, width: float, top: float, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	var count := line.size()
	var base := vertices.size()
	var half := width * 0.5
	var foot_y := IslandLayout.LAWN_Y + 0.004
	for index in count:
		var across := (line[mini(index + 1, count - 1)] - line[maxi(index - 1, 0)]).normalized().orthogonal()
		for column: Vector2 in [Vector2(-half - PATH_SKIRT, foot_y), Vector2(-half, top), Vector2(half, top), Vector2(half + PATH_SKIRT, foot_y)]:
			var point := line[index] + across * column.x
			vertices.append(Vector3(point.x, column.y, point.y))
			normals.append(Vector3.UP if column.y == top else Vector3(across.x * signf(column.x), 1.0, across.y * signf(column.x)).normalized())
	for index in count - 1:
		var here := base + index * 4
		for column in 3:
			_add_quad(vertices, indices, here + column, here + column + 1, here + column + 5, here + column + 4)
	for end: int in [0, count - 1]:
		var outward := (line[0] - line[1]).normalized() if end == 0 else (line[count - 1] - line[count - 2]).normalized()
		var centre := vertices.size()
		vertices.append(Vector3(line[end].x, top, line[end].y))
		normals.append(Vector3.UP)
		const STEPS := 6
		for step in STEPS + 1:
			var spoke := outward.rotated(-PI * 0.5 + PI * float(step) / STEPS) * half
			vertices.append(Vector3(line[end].x + spoke.x, top, line[end].y + spoke.y))
			normals.append(Vector3.UP)
		for step in STEPS:
			_add_triangle(vertices, indices, centre, centre + 1 + step, centre + 2 + step)

## A ring that slopes from `inner_y` at the water's edge down to `outer_y`.
static func _bank_mesh(inner: float, outer: float, inner_y: float, outer_y: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 32
	for step in SEGMENTS:
		var spoke := Vector2.from_angle(TAU * float(step) / SEGMENTS)
		vertices.append(Vector3(spoke.x * inner, inner_y, spoke.y * inner))
		vertices.append(Vector3(spoke.x * outer, outer_y, spoke.y * outer))
		var normal := Vector3(spoke.x * (inner_y - outer_y), outer - inner, spoke.y * (inner_y - outer_y)).normalized()
		normals.append(normal)
		normals.append(normal)
	for step in SEGMENTS:
		var here := step * 2
		var next := ((step + 1) % SEGMENTS) * 2
		_add_quad(vertices, indices, here, next, next + 1, here + 1)
	return _array_mesh(vertices, normals, indices)
