extends RefCounted
## Everything in the candy factory district that never moves on its own: the pink
## lawn, the syrup river and canal, tiled floors, the factory halls, machines and
## planting. Built once through the scenery kit; it keeps the few parts that the
## time of day changes and tells candy_life where the moving parts go.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/candy_props.gd")
const LAWN := preload("res://game/world/candy_lawn.gdshader")
const SYRUP := preload("res://game/world/syrup_flow.gdshader")
const LAWN_Y := 0.12
const YARD_Y := 0.15
const SYRUP_Y := -0.14
## The lawn reaches this far from the centre, well past anything the camera shows.
const FIELD := 66.0
const HALL_FACE_Z := -12.9
const HALL_WEST := -36.0
const HALL_EAST := 12.6
const HALL_HEIGHT := 6.2
const HALL_DEPTH := 11.4
const ANNEX_EAST := -25.6
const ANNEX_FACE_Z := 3.0
const ANNEX_HEIGHT := 5.0
## Floor edges: from (x, z), to (x, z), outward (x, z), 1 for a cane fence or 0 for a kerb only.
const EDGES := [
	[-13, -5, -4, -5, 0, -1, 1], [-13, -5, -13, 5, -1, 0, 1], [-13, 5, -4, 5, 0, 1, 1],
	[-4, 5, -4, 12, -1, 0, 0], [-4, 12, -1.9, 12, 0, 1, 1], [1.9, 12, 13, 12, 0, 1, 1],
	[13, 5, 13, 12, 1, 0, 1], [4, 5, 8, 5, 0, -1, 1], [10, 5, 13, 5, 0, -1, 1],
	[4, 0, 4, 5, 1, 0, 1], [4, 0, 8, 0, 0, 1, 1], [10, 0, 13, 0, 0, 1, 1],
	[13, -9, 13, 0, 1, 0, 1], [4, -9, 13, -9, 0, -1, 1], [4, -12, 4, -9, 1, 0, 1],
	[-4, -12, -4, -5, -1, 0, 0], [8, 0, 8, 5, -1, 0, 1], [10, 0, 10, 5, 1, 0, 1],
]
## Paved yards beside the floors: centre x, z, size x, z.
const YARDS := [
	[-8.5, -8.8, 9.0, 7.6], [8.5, -10.8, 9.0, 3.6], [0.0, -12.45, 8.0, 0.9],
	[-18.7, -2.3, 11.4, 20.6], [-5.2, 12.6, 2.4, 10.8],
]
## Eight cane lamps: x, z, side the crook leans to. All stay lit.
const LAMPS := [
	[3.5, 11.3, -1], [-3.5, 0.6, 1], [3.5, -11.2, -1], [-12.4, 4.3, 1],
	[-9.75, -4.5, 1], [12.4, -4.8, -1], [12.4, 10.6, -1], [10.45, 2.5, -1],
]
const CONVEYOR_X := -5.0
const BELT_Y := 0.85
## Each line: first z, last z, where products appear, where they vanish.
const BAKING_LINE := [-12.3, -5.8, -12.0, -6.2]
const PACKING_LINE := [8.2, 17.0, 9.0, 16.45]
const PRESS_Z := -9.3
const GUMBALL_AT := Vector3(-9.2, YARD_Y, -8.7)
const DISPENSER_AT := Vector3(-3.55, 0.2, 8.4)
const WHEEL_AT := Vector3(5.1, 0.0, 2.5)
const BASIN_AT := Vector3(11.1, 0.2, 7.0)
const WORKBENCH_AT := Vector3(-11.3, 0.2, 0.0)
## Kettles: x, z, syrup colour.
const VATS := [[5.9, -10.9, "#f08fb0"], [8.5, -10.9, "#d98a3a"], [11.1, -10.9, "#9fe0c6"]]
## Silos in the storage yard: x, z, radius, height, tone.
const SILOS := [[-21.5, -9.6, 1.35, 4.6, "#a3dfc8"], [-18.2, -10.3, 1.35, 5.2, "#f4a3bb"], [-15.2, -9.5, 1.15, 4.2, "#f9da7c"]]
## Loading bays in the storage yard: x, z, 0 for sugar sacks or 1 for crates.
const BAYS := [
	[-15.6, -4.6, 0], [-18.9, -4.6, 1], [-22.2, -4.6, 0], [-15.6, 0.2, 1], [-18.9, 0.2, 0], [-22.2, 0.2, 1],
	[-15.6, 5.0, 0], [-18.9, 5.0, 1], [-22.2, 5.0, 0],
]
## Loose stacks elsewhere: x, z, 0 for sugar sacks or 1 for crates.
const STACKS := [[-11.9, -11.0, 0], [-12.2, -6.6, 1], [-9.0, 14.6, 0], [-7.6, -11.6, 1], [5.2, -12.1, 1], [-2.9, 16.2, 1]]
## Candy trees: 0 lollipop or 1 cotton candy, x, z, height. Anything south of the
## floors stays low enough, or far enough away, not to hide the walkways.
const TREES := [
	[0, -9.0, 20.5, 3.6], [0, 6.2, 19.6, 3.4], [1, 10.8, 22.5, 4.0], [1, -4.6, 23.5, 3.8], [0, 3.6, 26.5, 4.2],
	[1, -11.5, 27.0, 4.4], [0, 12.5, 28.5, 4.0], [0, -18.0, 22.0, 4.2], [1, -24.0, 25.5, 4.5], [0, -2.6, 31.0, 4.0],
	[1, -28.0, 7.5, 4.4], [0, -32.0, 11.5, 4.0], [1, -23.5, 13.0, 4.2], [0, -29.0, 17.5, 4.3], [0, -20.0, 11.5, 3.6],
	[1, -33.5, 21.0, 4.4], [1, 20.0, -14.5, 4.2], [0, 24.5, -2.5, 4.0], [0, 21.0, 3.6, 3.6], [1, 26.0, 8.0, 4.4],
	[0, 20.3, 11.0, 3.4], [1, 24.0, 17.0, 4.2], [1, 29.0, -9.5, 4.4], [0, 30.0, 2.0, 4.0], [1, 19.6, 22.5, 4.0],
	[0, 28.0, 24.0, 4.2], [1, 22.5, 29.5, 4.3], [0, 21.5, -27.0, 4.0], [1, 23.0, -22.0, 4.4], [0, 27.0, -17.5, 4.1],
	[1, 31.5, -26.0, 4.5], [0, 33.0, 12.0, 4.2], [1, 21.0, 33.0, 4.2], [0, -14.0, 32.5, 4.0], [1, 7.0, 33.5, 4.4],
	[0, -26.0, 31.0, 4.2], [1, 33.5, 30.0, 4.4], [0, -34.0, 28.5, 4.0],
]
## Gumdrop hedges: from x, z to x, z.
const HEDGES := [
	[-12.6, 12.6, -6.9, 12.6], [-12.9, 5.9, -12.9, 12.2], [4.4, 13.3, 12.6, 13.3], [-24.2, 8.7, -13.4, 8.7],
	[18.4, -6.0, 18.9, 1.5], [18.6, 6.0, 18.2, 12.0],
]
## Flower clusters: x, z, count.
const FLOWERS := [
	[-10.5, 7.2, 6], [-8.2, 10.2, 7], [-5.4, 6.1, 5], [-11.4, 10.6, 5], [7.0, 14.9, 6], [-3.7, 15.4, 6], [4.8, 21.4, 7], [-3.4, 26.0, 6],
	[8.5, 15.5, 7], [20.0, -4.5, 6], [22.5, 6.0, 7], [19.4, 15.0, 6], [-16.5, 14.5, 7], [-27.0, 12.0, 6], [25.5, -13.0, 6],
	[-21.5, 18.5, 6], [14.2, 20.5, 6], [27.5, 13.5, 6],
]
## Painted billboards: kind, x, ground y, z, height.
const PLANTS := [
	["shrub", -8.6, LAWN_Y, 8.4, 1.25], ["shrub", 19.3, LAWN_Y, 8.6, 1.3], ["shrub", -15.0, LAWN_Y, 10.4, 1.3],
	["planter", -3.3, 0.2, -11.3, 1.6], ["planter", 5.3, 0.2, 11.4, 1.6], ["planter", -12.3, 0.2, -1.9, 1.6],
]

var world: Node3D
var kit: Kit
## Glossy sweets: one merged mesh with a low-roughness finish.
var gloss := Kit.Sculpt.new()
var syrup_material: ShaderMaterial
var vat_surfaces: Array[Vector3] = []
var globe_centre := Vector3.ZERO
var globe_radius := 1.0
var sample_cup := Vector3.ZERO
var needle_pivot := Vector3.ZERO
var _ground_y: float

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit
	_ground_y = owner.GROUND_Y

static func river_left(z: float) -> float:
	if z < -10.0: return 13.0 + 0.9 * (1.0 - cos((-10.0 - z) * 0.21))
	if z > 12.0: return 13.0 + 1.6 * sin((z - 12.0) * 0.13) * minf(1.0, (z - 12.0) / 6.0)
	return 13.0

static func river_right(z: float) -> float:
	return river_left(z) + 3.7 + 0.8 * sin(z * 0.19 + 1.0)

## True over the syrup river or the canal that feeds it.
static func is_syrup(point: Vector2) -> bool:
	if point.x > 4.0 and point.x < 13.0 and point.y > 0.0 and point.y < 5.0: return true
	return point.x > river_left(point.y) and point.x < river_right(point.y)

func build() -> void:
	_build_ground()
	_build_floors()
	_build_hall()
	_build_annex_and_yard()
	_build_lines()
	_build_kitchen()
	_build_gallery_and_canal()
	_build_lab()
	_build_gate()
	_build_planting()
	for lamp: Array in LAMPS:
		Props.cane_lamp(kit, Vector3(float(lamp[0]), _ground_y, float(lamp[1])), float(lamp[2]))
	var sweets: MeshInstance3D = world._mesh(gloss.mesh(), Vector3.ZERO, world._vertex_color_material("candy-gloss", 0.22))
	sweets.name = "CandyGloss"

## Windows and lanterns follow the region's lamp level; the syrup carries a faint glow.
func apply_time_of_day(lamp_level: float) -> void:
	kit.set_glow(lamp_level * 2.4)
	syrup_material.set_shader_parameter("glow", lamp_level * 0.22)

func _biscuit() -> Material:
	return Props.biscuit(world)

func _paving() -> Material:
	return Props.toned(world, 0, 1.8, Color("#d7b0b9"))

func _roofing() -> Material:
	return Props.toned(world, 2, 1.5, Color("#8fd3c0"))

func _build_ground() -> void:
	# A chocolate bed lies under everything, so no gap can ever show the sky colour.
	# On the island the island's own ground lies there instead.
	if world.embedded_in == null:
		var bed := PlaneMesh.new()
		bed.size = Vector2(110, 110)
		var backdrop: MeshInstance3D = world._mesh(bed, Vector3(0, -0.65, 0), world._mat(Color("#53313e")))
		backdrop.name = "ChocolateBackdrop"
		backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var field: Rect2 = world.dress_rect(Rect2(-FIELD, -FIELD, FIELD * 2.0, FIELD * 2.0))
	var rows: Array[float] = []
	for z in range(int(field.position.y), int(field.end.y) + 1, 2):
		rows.append(float(z))
		if z == 4: rows.append(5.0)
	# The lawn stops at the river banks and leaves the canal open.
	var lawn := SurfaceTool.new()
	lawn.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var bank_north: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var bank_south: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var bank_east: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	for index in range(rows.size()):
		var z := rows[index]
		left.append(Vector3(river_left(z), SYRUP_Y, z))
		right.append(Vector3(river_right(z), SYRUP_Y, z))
		bank_east[0].append(Vector3(river_right(z), SYRUP_Y - 0.03, z))
		bank_east[1].append(Vector3(river_right(z) + 0.9, LAWN_Y + 0.015, z))
		if z <= -12.0 or z >= 12.0:
			var bank := bank_north if z < 0.0 else bank_south
			bank[0].append(Vector3(river_left(z) - 0.9, LAWN_Y + 0.015, z))
			bank[1].append(Vector3(river_left(z), SYRUP_Y - 0.03, z))
		if index == rows.size() - 1: continue
		var next := rows[index + 1]
		var canal := z >= 0.0 and next <= 5.0
		_lawn_quad(lawn, field.position.x, 4.0 if canal else river_left(z) - 0.5, z, field.position.x, 4.0 if canal else river_left(next) - 0.5, next)
		_lawn_quad(lawn, river_right(z) + 0.5, field.end.x, z, river_right(next) + 0.5, field.end.x, next)
	var lawn_material := ShaderMaterial.new()
	lawn_material.shader = LAWN
	world.material_cache["candy-lawn"] = lawn_material
	var meadow: MeshInstance3D = world._mesh(lawn.commit(), Vector3(0, LAWN_Y, 0), lawn_material)
	meadow.name = "CandyLawn"
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	syrup_material = ShaderMaterial.new()
	syrup_material.shader = SYRUP
	world.material_cache["candy-syrup"] = syrup_material
	world.component_motion.register_shader(syrup_material)
	var river: MeshInstance3D = world._mesh(Kit.ribbon_mesh(left, right), Vector3.ZERO, syrup_material)
	river.name = "SyrupRiver"
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The canal runs east from the main aisle into the river.
	var south_wall := PackedVector3Array()
	var north_wall := PackedVector3Array()
	for x: float in [4.0, 7.0, 10.0, 13.3]:
		south_wall.append(Vector3(x, SYRUP_Y + 0.004, 5.0))
		north_wall.append(Vector3(x, SYRUP_Y + 0.004, 0.0))
	var canal_surface: MeshInstance3D = world._mesh(Kit.ribbon_mesh(south_wall, north_wall), Vector3.ZERO, syrup_material)
	canal_surface.name = "SyrupCanal"
	canal_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var banks := SurfaceTool.new()
	banks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bank: Array[PackedVector3Array] in [bank_north, bank_south, bank_east]:
		banks.append_from(Kit.ribbon_mesh(bank[0], bank[1]), 0, Transform3D.IDENTITY)
	# The path home winds south from the gate across the lawn.
	var path_left := PackedVector3Array()
	var path_right := PackedVector3Array()
	for step in range(19):
		var z := 12.0 + 3.0 * float(step)
		if z > field.end.y + 1.0: break
		var centre := 0.9 * sin((z - 12.0) * 0.11) * minf(1.0, (z - 12.0) / 5.0)
		path_left.append(Vector3(centre - 1.9, LAWN_Y + 0.03, z))
		path_right.append(Vector3(centre + 1.9, LAWN_Y + 0.03, z))
		if step > 0 and step < 8:
			for side: float in [-1.0, 1.0]:
				Props.gumdrop(gloss, Vector3(centre + side * 2.15, LAWN_Y, z - 1.4 + 0.3 * side), 0.17, Props.SWEETS[(step + int(side) + 6) % Props.SWEETS.size()])
	banks.append_from(Kit.ribbon_mesh(path_left, path_right), 0, Transform3D.IDENTITY)
	var edging: MeshInstance3D = world._mesh(banks.commit(), Vector3.ZERO, _biscuit())
	edging.name = "CandyBanks"
	edging.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if world.embedded_in != null:
		# The river enters and leaves the factory grounds through a culvert in a low biscuit wall.
		for z: float in [field.position.y, field.end.y]:
			var middle := (river_left(z) + river_right(z)) * 0.5
			kit.surface(_biscuit()).add(Vector3(middle, 0.42, z), Vector3(7.4, 1.0, 0.7))
			kit.detail.box(Vector3(middle, 0.02, z), Vector3(3.3, 0.44, 0.76), Color("#3a2430"))
			kit.surface(_roofing()).add(Vector3(middle, 0.98, z), Vector3(7.8, 0.14, 0.95))

## One lawn quad between the row at `z` and the row at `next_z`.
func _lawn_quad(lawn: SurfaceTool, west: float, east: float, z: float, west_next: float, east_next: float, next_z: float) -> void:
	for corner: Vector3 in [Vector3(east, 0, z), Vector3(east_next, 0, next_z), Vector3(west_next, 0, next_z), Vector3(east, 0, z), Vector3(west_next, 0, next_z), Vector3(west, 0, z)]:
		lawn.set_normal(Vector3.UP)
		lawn.add_vertex(corner)

func _build_floors() -> void:
	# Main aisle, material lab, pipe gallery, bubble mooring, canal bridge.
	var surfaces: Array[Material] = [
		Props.tile(world, "aisle", 0, Props.CREAM, Props.PINK.lightened(0.2), 1.0),
		Props.tile(world, "lab", 0, Props.CREAM, Props.MINT, 1.0),
		Props.tile(world, "gallery", 0, Props.CREAM, Props.LEMON, 1.0),
		Props.tile(world, "mooring", 0, Props.CREAM, Props.LILAC, 1.0),
		Props.toned(world, 1, 1.25, Props.WAFER),
	]
	for index in range(world.LAND.size()):
		var rect: Rect2 = world.LAND[index]
		var thickness := 0.26 if index == 4 else 0.6
		var slab: MeshInstance3D = world._box(Vector3(rect.get_center().x, _ground_y - thickness * 0.5, rect.get_center().y), Vector3(rect.size.x, thickness, rect.size.y), Props.CREAM, true)
		world._set_registered_surface(slab, surfaces[index])
		slab.name = "CandyFloor%d" % index
	# A mint runner marks the main aisle from the gate to the hall door.
	kit.surface(Props.tile(world, "runner", 0, Props.MINT, Props.WHITE, 0.5)).add(Vector3(0, _ground_y + 0.008, 0), Vector3(3.0, 0.016, 23.6))
	for side: float in [-1.0, 1.0]:
		kit.detail.box(Vector3(side * 1.56, _ground_y + 0.012, 0), Vector3(0.12, 0.024, 23.6), Props.LEMON.darkened(0.08))
	var paving := kit.surface(_paving())
	for yard: Array in YARDS:
		paving.add(Vector3(float(yard[0]), YARD_Y - 0.15, float(yard[1])), Vector3(float(yard[2]), 0.3, float(yard[3])))
	var kerb := kit.surface(_biscuit())
	for edge: Array in EDGES:
		var from := Vector2(float(edge[0]), float(edge[1]))
		var to := Vector2(float(edge[2]), float(edge[3]))
		var outward := Vector2(float(edge[4]), float(edge[5]))
		var middle := (from + to) * 0.5 - outward * 0.13
		var length := from.distance_to(to)
		kerb.add(Vector3(middle.x, _ground_y + 0.02, middle.y), Vector3(length, 0.07, 0.26) if is_zero_approx(outward.x) else Vector3(0.26, 0.07, length))
		if int(edge[6]) == 1:
			Props.cane_fence(kit, from - outward * 0.13, to - outward * 0.13, _ground_y + 0.05)
	# Syrup has stained the canal walls up to its high mark.
	kit.detail.box(Vector3(8.5, -0.04, 0.03), Vector3(9.0, 0.16, 0.06), Props.CARAMEL.darkened(0.25))
	kit.detail.box(Vector3(4.03, -0.04, 2.5), Vector3(0.06, 0.16, 5.0), Props.CARAMEL.darkened(0.25))
	# Sticky puddles on the yards.
	for puddle: Array in [[-7.0, -6.3, 0.7], [-10.9, -11.4, 0.5], [7.2, -9.5, 0.45], [-17.2, -7.4, 0.8], [-20.5, 2.6, 0.6], [-5.9, 9.2, 0.4]]:
		var at := Vector3(float(puddle[0]), YARD_Y + 0.01, float(puddle[1]))
		gloss.tube(at, float(puddle[2]), float(puddle[2]) * 0.9, 0.02, Props.CARAMEL, 9)
		gloss.tube(at + Vector3(float(puddle[2]) * 0.7, 0, 0.2), float(puddle[2]) * 0.45, float(puddle[2]) * 0.4, 0.02, Props.CARAMEL.lightened(0.1), 7)

## The factory hall closes the north side: board walls on a biscuit plinth, rows of
## windows, an icing cornice, a saw-tooth roof and two striped chimneys.
func _build_hall() -> void:
	var length := HALL_EAST - HALL_WEST
	var centre_x := (HALL_EAST + HALL_WEST) * 0.5
	var walls := kit.surface(Props.boards(world, Props.PINK))
	kit.surface(_biscuit()).add(Vector3(centre_x, 0.5, HALL_FACE_Z - 0.3), Vector3(length + 0.2, 1.0, 0.8))
	walls.add(Vector3(centre_x, 1.0 + (HALL_HEIGHT - 1.0) * 0.5, HALL_FACE_Z - 0.35), Vector3(length, HALL_HEIGHT - 1.0, 0.6))
	walls.add(Vector3(HALL_EAST - 0.3, HALL_HEIGHT * 0.5, HALL_FACE_Z - HALL_DEPTH * 0.5), Vector3(0.6, HALL_HEIGHT, HALL_DEPTH))
	var detail := kit.detail
	detail.box(Vector3(centre_x, HALL_HEIGHT + 0.12, HALL_FACE_Z - 0.2), Vector3(length + 0.4, 0.3, 0.9), Props.CREAM)
	# Icing drips from the cornice.
	for drip in range(int(length / 0.55)):
		var x := HALL_WEST + 0.3 + 0.55 * float(drip)
		var drop := 0.18 + 0.3 * fposmod(sin(float(drip) * 12.9898) * 43758.5453, 1.0)
		detail.box(Vector3(x, HALL_HEIGHT - drop * 0.5, HALL_FACE_Z + 0.02), Vector3(0.3, drop, 0.1), Props.CREAM)
		detail.ball(Vector3(x, HALL_HEIGHT - drop, HALL_FACE_Z + 0.02), 0.15, Props.CREAM, Color.TRANSPARENT, 6, 2, 1.0)
	for bay in range(8):
		var x := -33.0 + 6.0 * float(bay)
		detail.box(Vector3(x, 1.0 + (HALL_HEIGHT - 1.0) * 0.5, HALL_FACE_Z), Vector3(0.5, HALL_HEIGHT - 1.0, 0.3), Props.CREAM)
		detail.box(Vector3(x, 1.12, HALL_FACE_Z + 0.03), Vector3(0.66, 0.24, 0.4), Props.ROSE)
		if bay == 5 or bay == 7: continue
		for offset: float in [1.6, 4.4]:
			_window(Vector3(x + offset, 3.75, HALL_FACE_Z), 1.3, 1.6, bay % 2 == 0)
	# The aisle ends at a striped roller door under an awning.
	kit.surface(Props.tile(world, "shutter", 2, Props.CREAM, Props.PINK, 0.25, 0.7)).add(Vector3(0, 2.0, HALL_FACE_Z + 0.06), Vector3(4.4, 3.4, 0.14))
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 2.32, 2.0, HALL_FACE_Z + 0.1), Vector3(0.24, 3.6, 0.3), Props.CREAM)
	detail.box(Vector3(0, 3.82, HALL_FACE_Z + 0.1), Vector3(4.9, 0.24, 0.3), Props.CREAM)
	detail.box(Vector3(1.3, 1.25, HALL_FACE_Z + 0.15), Vector3(0.9, 1.9, 0.05), Props.PLUM)
	detail.ball(Vector3(1.6, 1.25, HALL_FACE_Z + 0.2), 0.06, Props.LEMON, Color.TRANSPARENT, 6, 2)
	_awning(Vector3(0, 4.25, HALL_FACE_Z), 5.6, Props.RED)
	_awning(Vector3(7.5, 5.0, HALL_FACE_Z), 3.6, Props.MINT.darkened(0.25))
	# The games board hangs over the door.
	Props.board(detail, Vector3(0, 5.3, HALL_FACE_Z + 0.2), 5.2, 0.86)
	Props.lettering(world, "工廠遊戲 %d／12" % preload("res://game/core/game_catalog.gd").definitions("candy").size(), Vector3(0, 5.3, HALL_FACE_Z + 0.32), 28)
	# Saw-tooth roof: each tooth climbs north to a ridge.
	var roof := kit.surface(_roofing())
	for tooth in range(3):
		var low_z := HALL_FACE_Z + 0.25 - 3.6 * float(tooth)
		roof.add(Vector3(centre_x, HALL_HEIGHT + 1.2, low_z - 1.9), Vector3(length + 0.6, 0.16, 4.2), Basis(Vector3.RIGHT, 0.485))
		detail.box(Vector3(centre_x, HALL_HEIGHT + 2.2, low_z - 3.72), Vector3(length + 0.7, 0.16, 0.24), Props.CREAM)
	var stripes := kit.rounds(Props.tile(world, "chimney", 2, Props.WHITE, Props.RED, 0.55, 0.75))
	for chimney: Array in [[-9.0, -18.5, 5.4], [5.5, -20.5, 4.6]]:
		var base := Vector3(float(chimney[0]), HALL_HEIGHT + 0.8, float(chimney[1]))
		var height := float(chimney[2])
		stripes.add(base + Vector3(0, height * 0.5, 0), Vector3(1.4, height, 1.4))
		detail.tube(base + Vector3(0, 0.3, 0), 1.0, 0.8, 0.6, Props.ROSE, 12)
		detail.tube(base + Vector3(0, height + 0.1, 0), 0.86, 0.86, 0.22, Props.CREAM, 12)
		detail.tube(base + Vector3(0, height + 0.18, 0), 0.6, 0.6, 0.1, Props.DARK, 10)

## Framed window with a sill; its panes are lantern glass and light up after dark.
func _window(at: Vector3, width: float, height: float, shade: bool) -> void:
	var detail := kit.detail
	detail.box(at + Vector3(0, 0, 0.04), Vector3(width + 0.24, height + 0.24, 0.1), Props.CREAM)
	kit.glow.box(at + Vector3(0, 0, 0.08), Vector3(width, height, 0.06), Color("#f3e3bd"))
	detail.box(at + Vector3(0, 0, 0.11), Vector3(0.07, height, 0.04), Props.CREAM)
	detail.box(at + Vector3(0, height * 0.12, 0.11), Vector3(width, 0.07, 0.04), Props.CREAM)
	detail.box(at + Vector3(0, -height * 0.5 - 0.16, 0.12), Vector3(width + 0.4, 0.1, 0.28), Props.ROSE)
	if shade:
		for scallop in range(4):
			detail.ball(at + Vector3(-width * 0.375 + width * 0.25 * float(scallop), height * 0.5 + 0.1, 0.1), width * 0.14, Props.PINK if scallop % 2 == 0 else Props.WHITE, Color.TRANSPARENT, 6, 2, 0.9, true)

## Striped canvas sloping out from a wall, with a scalloped valance.
func _awning(at: Vector3, width: float, tone: Color) -> void:
	var key := "awning:" + tone.to_html(false)
	kit.surface(Props.tile(world, key, 1, Props.WHITE, tone, 0.4, 0.85)).add(at + Vector3(0, -0.28, 0.7), Vector3(width, 0.07, 1.5), Basis(Vector3.RIGHT, 0.38))
	var scallops := int(width / 0.4)
	for index in range(scallops):
		kit.detail.box(at + Vector3((float(index) + 0.5) * 0.4 - float(scallops) * 0.2, -0.66, 1.4), Vector3(0.38, 0.2 if index % 2 == 0 else 0.14, 0.04), Props.WHITE if index % 2 == 0 else tone)
	for side: float in [-1.0, 1.0]:
		Props.pipe(kit.detail, at + Vector3(side * (width * 0.5 - 0.1), -0.9, 0.05), at + Vector3(side * (width * 0.5 - 0.1), -0.56, 1.36), 0.025, Props.DARK, 5)

## The packing hall and its storage yard fill the west: silos, sacks and a cane fence.
func _build_annex_and_yard() -> void:
	var width := ANNEX_EAST - HALL_WEST
	var centre_x := (ANNEX_EAST + HALL_WEST) * 0.5
	var depth := ANNEX_FACE_Z - HALL_FACE_Z
	var walls := kit.surface(Props.boards(world, Color("#f7df9c")))
	kit.surface(_biscuit()).add(Vector3(centre_x, 0.5, ANNEX_FACE_Z - 0.3), Vector3(width + 0.2, 1.0, 0.8))
	walls.add(Vector3(centre_x, 1.0 + (ANNEX_HEIGHT - 1.0) * 0.5, ANNEX_FACE_Z - 0.35), Vector3(width, ANNEX_HEIGHT - 1.0, 0.6))
	walls.add(Vector3(ANNEX_EAST - 0.3, ANNEX_HEIGHT * 0.5, ANNEX_FACE_Z - depth * 0.5), Vector3(0.6, ANNEX_HEIGHT, depth))
	var detail := kit.detail
	detail.box(Vector3(centre_x, ANNEX_HEIGHT + 0.1, ANNEX_FACE_Z - 0.2), Vector3(width + 0.4, 0.26, 0.9), Props.CREAM)
	for index in range(3):
		_window(Vector3(HALL_WEST + 1.9 + 3.3 * float(index), 3.2, ANNEX_FACE_Z), 1.3, 1.5, true)
	detail.box(Vector3(ANNEX_EAST - 1.4, 1.35, ANNEX_FACE_Z + 0.05), Vector3(1.2, 2.3, 0.1), Props.ROSE)
	detail.box(Vector3(ANNEX_EAST - 1.4, 1.35, ANNEX_FACE_Z + 0.02), Vector3(1.44, 2.5, 0.1), Props.CREAM)
	_awning(Vector3(ANNEX_EAST - 1.4, 3.1, ANNEX_FACE_Z), 2.2, Props.ROSE)
	var roof := kit.surface(_roofing())
	for tooth in range(4):
		var low_z := ANNEX_FACE_Z + 0.25 - 3.95 * float(tooth)
		roof.add(Vector3(centre_x, ANNEX_HEIGHT + 1.1, low_z - 2.05), Vector3(width + 0.6, 0.16, 4.5), Basis(Vector3.RIGHT, 0.44))
		detail.box(Vector3(centre_x, ANNEX_HEIGHT + 2.05, low_z - 4.05), Vector3(width + 0.7, 0.16, 0.24), Props.CREAM)
	for silo: Array in SILOS:
		Props.silo(world, kit, Vector3(float(silo[0]), YARD_Y, float(silo[1])), float(silo[2]), float(silo[3]), Color(str(silo[4])))
	# Feed pipes drop from the hall wall into each silo.
	for silo: Array in SILOS:
		var top := Vector3(float(silo[0]), YARD_Y + 1.0 + float(silo[3]) + float(silo[2]) * 0.6, float(silo[1]))
		Props.pipe_run(detail, [Vector3(top.x, top.y + 0.5, HALL_FACE_Z), Vector3(top.x, top.y + 0.5, top.z), top], 0.11, Props.COPPER)
	for index in range(BAYS.size() + STACKS.size()):
		var stack: Array = BAYS[index] if index < BAYS.size() else STACKS[index - BAYS.size()]
		var at := Vector3(float(stack[0]), LAWN_Y if float(stack[1]) > 12.0 else YARD_Y, float(stack[1]))
		if int(stack[2]) == 0:
			Props.sacks(kit, at, index)
		else:
			Props.crates(kit, at, index)
		if index >= BAYS.size(): continue
		# Painted bay outline on the paving.
		for side: float in [-1.0, 1.0]:
			detail.box(at + Vector3(side * 1.4, 0.008, 0.1), Vector3(0.08, 0.016, 2.6), Props.CREAM)
			detail.box(at + Vector3(0, 0.008, 0.1 + side * 1.3), Vector3(2.88, 0.016, 0.08), Props.CREAM)
	Props.cane_fence(kit, Vector2(-24.4, 8.0), Vector2(-13.3, 8.0), YARD_Y)
	Props.cane_fence(kit, Vector2(-24.4, 3.3), Vector2(-24.4, 8.0), YARD_Y)

## The two conveyor lines beside the main aisle and the machines they run through.
func _build_lines() -> void:
	var baking_from := Vector3(CONVEYOR_X, YARD_Y, float(BAKING_LINE[0]))
	var baking_to := Vector3(CONVEYOR_X, YARD_Y, float(BAKING_LINE[1]))
	Props.conveyor(kit, baking_from, baking_to, BELT_Y)
	Props.hood(world, kit, Vector3(CONVEYOR_X, YARD_Y, -12.4), Vector3(1.7, 1.5, 0.9), Props.PINK)
	Props.hood(world, kit, Vector3(CONVEYOR_X, YARD_Y, -5.85), Vector3(1.6, 1.35, 0.8), Props.LEMON)
	Props.press_frame(world, kit, Vector3(CONVEYOR_X, YARD_Y, PRESS_Z))
	var machine := Props.gumball_machine(world, kit, gloss, GUMBALL_AT)
	globe_centre = machine.centre
	globe_radius = machine.radius
	var packing_from := Vector3(CONVEYOR_X, YARD_Y, float(PACKING_LINE[0]))
	var packing_to := Vector3(CONVEYOR_X, YARD_Y, float(PACKING_LINE[1]))
	Props.conveyor(kit, packing_from, packing_to, BELT_Y)
	Props.wrapping_station(world, kit, gloss, Vector3(CONVEYOR_X, YARD_Y, float(PACKING_LINE[0])))
	Props.hood(world, kit, Vector3(CONVEYOR_X, YARD_Y, 17.1), Vector3(1.9, 1.6, 1.5), Props.SKY)
	# Parcels wait beside the shipping hood.
	for parcel in range(4):
		var at := Vector3(CONVEYOR_X - 1.6 + 0.2 * float(parcel % 2), LAWN_Y + 0.25 + 0.5 * floorf(float(parcel) / 2.0), 16.4 + 0.6 * float(parcel % 2))
		kit.detail.box(at, Vector3(0.5, 0.5, 0.5), Props.WAFER.lightened(0.1), Basis(Vector3.UP, 0.3 * float(parcel)))
		kit.detail.box(at, Vector3(0.52, 0.52, 0.1), Props.SWEETS[parcel], Basis(Vector3.UP, 0.3 * float(parcel)))
	sample_cup = Props.dispenser(kit, gloss, DISPENSER_AT)
	kit.blocker(DISPENSER_AT + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
	# A chute feeds the dispenser from the packing line.
	Props.pipe_run(kit.detail, [Vector3(CONVEYOR_X + 0.8, 1.3, 8.4), Vector3(-3.9, 1.6, 8.4), Vector3(-3.6, 1.9, 8.4)], 0.07, Props.COPPER)

## Copper kettles along the hall wall, fed by an overhead manifold.
func _build_kitchen() -> void:
	var detail := kit.detail
	var manifold := Vector3(4.6, 3.5, HALL_FACE_Z + 0.5)
	Props.pipe(detail, manifold, manifold + Vector3(8.0, 0, 0), 0.14, Props.COPPER)
	for vat: Array in VATS:
		var at := Vector3(float(vat[0]), YARD_Y, float(vat[1]))
		vat_surfaces.append(Props.vat(world, kit, gloss, at, Color(str(vat[2]))))
		Props.pipe_run(detail, [Vector3(at.x, manifold.y, manifold.z), Vector3(at.x, manifold.y, at.z), Vector3(at.x, 2.75, at.z)], 0.09, Props.COPPER)
		Props.valve(detail, Vector3(at.x, manifold.y, at.z + 0.1))
	Props.gauge(detail, Vector3(4.9, 3.0, HALL_FACE_Z + 0.3), -0.4, 0.3)
	# A low header with valves and gauges runs behind the gallery fence.
	Props.pipe_run(detail, [Vector3(4.5, 0.95, -9.42), Vector3(12.7, 0.95, -9.42)], 0.1, Props.COPPER)
	for index in range(5):
		var x := 5.0 + 1.75 * float(index)
		detail.box(Vector3(x, 0.55, -9.42), Vector3(0.1, 0.8, 0.1), Props.DARK)
		if index % 2 == 0:
			Props.valve(detail, Vector3(x + 0.6, 0.95, -9.36))
		else:
			detail.box(Vector3(x + 0.6, 1.15, -9.42), Vector3(0.05, 0.3, 0.05), Props.STEEL)
			Props.gauge(detail, Vector3(x + 0.6, 1.42, -9.38), 0.5 - 0.4 * float(index), 0.17)
	# The last kettle overflows through a spout into the river.
	Props.pipe_run(detail, [Vector3(12.2, 0.85, -9.75), Vector3(13.35, 0.85, -9.75)], 0.14, Props.COPPER)
	var pour: MeshInstance3D = world._mesh(Kit.ribbon_mesh(PackedVector3Array([Vector3(13.2, 0.82, -9.6), Vector3(13.2, SYRUP_Y, -9.6)]), PackedVector3Array([Vector3(13.5, 0.82, -9.6), Vector3(13.5, SYRUP_Y, -9.6)])), Vector3.ZERO, syrup_material)
	pour.name = "SyrupPour"
	pour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Syrup tanks and pipes on the gallery, the canal bridge and the bubble mooring.
func _build_gallery_and_canal() -> void:
	var detail := kit.detail
	# The tanks stand against the north fence, so nobody can walk out of sight behind them.
	var tanks := [[11.9, -7.95, Props.PINK, 0.75], [9.9, -7.95, Props.LEMON, 0.45]]
	for tank: Array in tanks:
		var at := Vector3(float(tank[0]), _ground_y, float(tank[1]))
		Props.tank(world, kit, gloss, at, tank[2], float(tank[3]))
		kit.blocker(at + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 1.4))
		Props.pipe_run(detail, [at + Vector3(0, 3.5, 0), at + Vector3(0, 3.9, 0), Vector3(at.x, _ground_y + 3.9, HALL_FACE_Z)], 0.12, Props.COPPER)
	# A drain line drops from a standpipe and follows the canal wall to a spout by the aisle.
	detail.box(Vector3(12.55, _ground_y + 0.25, -0.5), Vector3(0.4, 0.5, 0.4), Props.DARK)
	Props.valve(detail, Vector3(12.55, 0.95, -0.42))
	Props.pipe_run(detail, [Vector3(12.55, 0.7, -0.5), Vector3(12.55, 0.7, 0.24), Vector3(12.55, 0.04, 0.24), Vector3(5.6, 0.04, 0.24)], 0.09, Props.COPPER)
	for bracket in range(4):
		detail.box(Vector3(6.6 + 1.7 * float(bracket), 0.04, 0.12), Vector3(0.08, 0.26, 0.24), Props.DARK)
	Props.signboard(world, kit, Vector3(6.6, _ground_y, -8.62), "糖漿管道")
	# Wafer bridge: chunky end posts with gumdrop caps, and a pier that carries a lamp.
	for corner_x: float in [7.92, 10.08]:
		for corner_z: float in [0.1, 4.9]:
			detail.box(Vector3(corner_x, _ground_y + 0.5, corner_z), Vector3(0.3, 1.0, 0.3), Props.WAFER.darkened(0.08))
			detail.box(Vector3(corner_x, _ground_y + 1.02, corner_z), Vector3(0.38, 0.06, 0.38), Props.CREAM)
			Props.gumdrop(gloss, Vector3(corner_x, _ground_y + 1.05, corner_z), 0.15, Props.RED if corner_z < 2.0 else Props.MINT)
	detail.box(Vector3(10.45, 0.0, 2.5), Vector3(0.7, 0.5, 0.9), Props.WAFER.darkened(0.1))
	for pier_z: float in [1.2, 3.8]:
		detail.box(Vector3(9.0, -0.12, pier_z), Vector3(2.3, 0.3, 0.5), Props.WAFER.darkened(0.16))
	# Paddle wheel base in the canal head; the wheel itself turns.
	for side: float in [-1.0, 1.0]:
		detail.box(WHEEL_AT + Vector3(0, 0.25, side * 0.75), Vector3(0.5, 0.9, 0.18), Props.PLUM)
		detail.box(WHEEL_AT + Vector3(0, 0.74, side * 0.75), Vector3(0.6, 0.08, 0.26), Props.CREAM)
	Props.bubble_basin(world, kit, gloss, BASIN_AT)
	kit.blocker(BASIN_AT + Vector3(0, 0.9, 0), Vector3(2.2, 1.8, 2.2))
	Props.signboard(world, kit, Vector3(11.45, _ground_y, 8.74), "泡泡停靠", 24, 0.64)

## The material lab in the west wing: bench, jar shelf, mould table and their signs.
func _build_lab() -> void:
	needle_pivot = Props.workbench(world, kit, gloss, WORKBENCH_AT)
	kit.blocker(WORKBENCH_AT + Vector3(0, 0.9, 0), Vector3(2.5, 1.8, 3.1))
	var shelf_at := Vector3(-11.5, _ground_y, -4.3)
	Props.shelf(world, kit, gloss, shelf_at)
	kit.blocker(shelf_at + Vector3(0, 0.9, -0.12), Vector3(2.3, 1.8, 0.6))
	Props.signboard(world, kit, shelf_at + Vector3(0, 0, -0.34), "材料工作台", 24, 2.5)
	var table_at := Vector3(-6.1, _ground_y, 0.3)
	Props.mold_table(kit, gloss, table_at)
	kit.blocker(table_at + Vector3(0, 0.9, 0), Vector3(1.3, 1.8, 0.9))
	Props.signboard(world, kit, table_at + Vector3(0, 0, -0.55), "餅乾翻模", 24, 1.75)

## South gate: a barrier across the path, the name arch beyond it and the far fence.
func _build_gate() -> void:
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		detail.tube(Vector3(side * 1.9, _ground_y + 0.5, 12.0), 0.16, 0.13, 1.0, Props.PLUM, 8)
		detail.ball(Vector3(side * 1.9, _ground_y + 1.08, 12.0), 0.17, Props.LEMON, Color.TRANSPARENT, 8, 3)
	for band in range(9):
		detail.box(Vector3(-1.6 + 0.4 * float(band), _ground_y + 0.72, 12.0), Vector3(0.4, 0.11, 0.07), Props.RED if band % 2 == 0 else Props.WHITE)
	Props.gate_arch(world, kit, Vector3(0.35, LAWN_Y, 18.6), "糖果工廠", "免費返回")
	kit.bunting(Vector3(-2.2, 3.3, 18.6), Vector3(-8.0, 2.3, 21.5), Props.SWEETS, 0.4)
	kit.bunting(Vector3(2.9, 3.3, 18.6), Vector3(7.2, 2.3, 20.4), Props.SWEETS, 0.4)
	detail.tube(Vector3(-8.0, LAWN_Y + 1.15, 21.5), 0.05, 0.04, 2.3, Props.WHITE, 6)
	detail.tube(Vector3(7.2, LAWN_Y + 1.15, 20.4), 0.05, 0.04, 2.3, Props.WHITE, 6)
	Props.cane_fence(kit, Vector2(-34.0, 27.6), Vector2(-3.4, 27.6), LAWN_Y, Props.MINT.darkened(0.3))
	Props.cane_fence(kit, Vector2(3.4, 27.6), Vector2(12.6, 27.6), LAWN_Y, Props.MINT.darkened(0.3))
	if world.in_dress_reach(Vector2(34.0, 27.6)): Props.cane_fence(kit, Vector2(19.4, 27.6), Vector2(34.0, 27.6), LAWN_Y, Props.MINT.darkened(0.3))

## Candy trees, gumdrop hedges, flowers and a cooling tower on the far bank.
func _build_planting() -> void:
	for index in range(TREES.size()):
		var tree: Array = TREES[index]
		var at := Vector3(float(tree[1]), LAWN_Y, float(tree[2]))
		if not world.dresses(Vector2(at.x, at.z)): continue
		if int(tree[0]) == 0:
			Props.lollipop_tree(kit, gloss, at, float(tree[3]), Props.SWEETS[index % Props.SWEETS.size()], Props.WHITE)
		else:
			Props.cotton_tree(kit, at, float(tree[3]), [Props.PINK, Props.SKY, Props.LILAC][index % 3], index)
	for hedge: Array in HEDGES:
		var from := Vector3(float(hedge[0]), LAWN_Y, float(hedge[1]))
		var to := Vector3(float(hedge[2]), LAWN_Y, float(hedge[3]))
		if not world.in_dress_reach(Vector2(to.x, to.z)): continue
		var count := int(from.distance_to(to) / 0.62)
		for index in range(count + 1):
			var seed_value := from.x * 3.1 + from.z * 1.7 + float(index) * 5.3
			Props.gumdrop(gloss, from.lerp(to, float(index) / float(count)) + Vector3(0.1 * _scatter(seed_value) - 0.05, 0, 0.1 * _scatter(seed_value + 1.0) - 0.05), 0.27 + 0.1 * _scatter(seed_value + 2.0), Props.SWEETS[(index * 2 + int(from.x)) % Props.SWEETS.size()].lerp(Props.MINT, 0.35))
	var flower_facing := kit.view_basis * Basis(Vector3.RIGHT, PI * 0.5)
	for cluster: Array in FLOWERS:
		if not world.dresses(Vector2(float(cluster[0]), float(cluster[1]))): continue
		for index in range(int(cluster[2])):
			var seed_value := float(cluster[0]) * 2.3 + float(cluster[1]) * 4.1 + float(index) * 7.7
			var at := Vector3(float(cluster[0]) + (_scatter(seed_value) * 2.0 - 1.0) * 1.1, LAWN_Y, float(cluster[1]) + (_scatter(seed_value + 1.0) * 2.0 - 1.0) * 0.9)
			var height := 0.35 + 0.3 * _scatter(seed_value + 2.0)
			kit.detail.box(at + Vector3(0, height * 0.5, 0), Vector3(0.035, height, 0.035), Props.MINT.darkened(0.3))
			gloss.tube(at + Vector3(0, height + 0.08, 0), 0.13, 0.13, 0.07, Props.SWEETS[index % Props.SWEETS.size()], 7, flower_facing)
			gloss.tube(at + Vector3(0, height + 0.08, 0) + kit.view_basis.z * 0.045, 0.06, 0.05, 0.03, Props.WHITE, 5, flower_facing)
	for plant: Array in PLANTS:
		if not world.in_dress_reach(Vector2(float(plant[1]), float(plant[3]))): continue
		kit.billboard(str(plant[0]), Vector3(float(plant[1]), float(plant[2]), float(plant[3])), float(plant[4]))
	var tower_at := Vector3(23.5, LAWN_Y, -8.5)
	Props.cooling_tower(kit, tower_at)
	Props.pipe_run(kit.detail, [tower_at + Vector3(-2.4, 0.5, 0.6), tower_at + Vector3(-4.2, 0.5, 0.6), tower_at + Vector3(-4.2, 0.1, 0.6)], 0.16, Props.COPPER)

## Repeatable 0..1 scatter value, so the scenery is identical on every visit.
func _scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)
