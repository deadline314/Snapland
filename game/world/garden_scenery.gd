extends RefCounted
## Everything in the moss-light greenhouse that stands still: the woodland floor, the
## iron-and-glass house, its water, furniture and planting. Built once through the
## scenery kit; it keeps only the parts that the time of day changes.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/garden_props.gd")
const Paving := preload("res://game/world/garden_paving.gdshader")
const Ground := preload("res://game/world/garden_ground.gdshader")
const Glass := preload("res://game/world/garden_glass.gdshader")
const Water := preload("res://game/world/garden_water.gdshader")
const Plant := preload("res://game/world/garden_plant.gdshader")
const Shaft := preload("res://game/world/garden_light_shaft.gdshader")
const CANOPY_ART := "res://assets/world/garden-canopy-foliage.webp"
enum Style { PAVERS, BOARDS, PLAIN, BRICK, HEDGE, ROCK }
const TERRAIN_Y := 0.12
const WATER_Y := -0.06
## Outer face of the walls, which stand just outside the walkable floor.
const HOUSE := Rect2(-12.5, -12.2, 25.0, 22.05)
const WALL_X := 12.25
const NORTH_Z := -11.95
const SOUTH_Z := 9.6
const PLINTH := 0.9
const TRANSOM := 2.3
const EAVE := 3.4
const RIDGE := 6.0
## The roof is whole over the north end and cut away towards the camera: full arches,
## then stubs that only spring from the side walls.
const FULL_ARCHES: Array[float] = [-11.95, -7.6, -3.3]
const STUB_ARCHES: Array[float] = [1.0, 5.3, 9.6]
const STUB_REACH := 9.4
const DOOR_HALF := 3.0
const POND := Vector3(0.0, 0.2, -3.4)
const POND_RADIUS := 1.3
const POND_SURFACE := 0.58
const ISLET := Vector3(-10.7, 0.1, -2.2)
const RIDGE_END := Vector3(0, RIDGE, -3.3)
const WHIRLIGIG := Vector3(-8.7, TERRAIN_Y + 1.5, 15.2)
## Garden path to the welcome avenue (x, z).
const PATH: Array[Vector2] = [Vector2(0, 9.6), Vector2(0.2, 13.0), Vector2(1.4, 17.5), Vector2(0.2, 22.0), Vector2(-1.8, 27.0), Vector2(-0.6, 34.0), Vector2(0, 52.0)]
## Hedged flower beds either side of the path.
const PARTERRES: Array[Rect2] = [Rect2(-10.2, 12.4, 7.6, 4.2), Rect2(2.9, 12.4, 7.6, 4.2)]
## Hanging baskets: hook x, y, z.
const BASKETS: Array[Vector3] = [
	Vector3(-11.3, 3.0, -7.6), Vector3(-11.3, 3.0, -3.3), Vector3(-11.3, 3.0, 1.0), Vector3(-11.3, 3.0, 5.3),
	Vector3(11.3, 3.0, -7.6), Vector3(11.3, 3.0, -3.3), Vector3(11.3, 3.0, 1.0), Vector3(11.3, 3.0, 5.3),
	Vector3(-8.75, 3.1, -11.45), Vector3(-1.75, 3.1, -11.45), Vector3(1.75, 3.1, -11.45), Vector3(8.75, 3.1, -11.45),
]
## Trees the player sees up close cast their own silhouettes: kind, x, z, height.
const NEAR_TREES := [
	["oak", -16.6, -6.4, 5.3], ["pine", -16.0, 3.6, 4.7], ["ginkgo", 16.4, -9.2, 5.0], ["oak", 17.0, 1.8, 5.5],
	["pine", 16.2, 12.6, 4.6], ["oak", -14.6, 20.2, 5.6], ["ginkgo", 13.4, 21.4, 5.2], ["pine", -15.4, 12.4, 4.4],
	["oak", -6.5, -17.2, 6.0], ["pine", 4.0, -16.6, 5.4], ["oak", 12.5, -16.9, 5.8],
]
## Shrubs and planters near the walls: kind, x, z, height.
const NEAR_PLANTS := [
	["shrub", -14.4, -2.3, 1.3], ["shrub", -14.4, 5.4, 1.2], ["shrub", 14.4, -2.3, 1.3], ["shrub", 14.4, 5.4, 1.25],
	["shrub", -15.9, 9.6, 1.2], ["shrub", 16.0, 9.4, 1.2], ["shrub", -13.9, -12.6, 1.3], ["shrub", 13.8, -12.4, 1.3],
	["planter", -6.4, 14.5, 1.6], ["planter", 6.7, 14.5, 1.6],
]
const LAMPS: Array[Vector3] = [Vector3(-2.3, TERRAIN_Y, 18.6), Vector3(3.6, TERRAIN_Y, 24.0), Vector3(-13.2, TERRAIN_Y, 16.6), Vector3(13.0, TERRAIN_Y, 17.2)]

var world: Node3D
var kit: Kit
## Pieces in front of the regional portrait camera; the world hides them for the photo.
var story_front: Array[Node3D] = []
var doorway: MeshInstance3D
var vane: MeshInstance3D
var whirligig: MeshInstance3D
var wetland_water: ShaderMaterial
var lily_pads: Kit.Batch
var night_glow := Kit.Sculpt.new()
var _glazing: ShaderMaterial
var _clear_glazing: ShaderMaterial
var _shafts: ShaderMaterial
var _shaded: Array[ShaderMaterial] = []


func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit


func build() -> void:
	_build_terrain()
	_build_house()
	_build_doorway()
	_build_water()
	_build_furniture()
	_build_indoor_planting()
	_build_forecourt()
	_build_woodland()
	_build_light()
	var glow: MeshInstance3D = world._mesh(night_glow.mesh(), Vector3.ZERO, world._buds)
	glow.name = "GardenNightGlow"
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Lanterns, glazing, light shafts and leaf shade follow the time of day.
func apply_time_of_day(phase: String, lamp_level: float) -> void:
	var evening := phase in ["dusk", "night"]
	kit.set_glow(lamp_level * 2.6)
	_glazing.set_shader_parameter("glass_light", {"dawn": Color("#e7cdb4"), "noon": Color("#c8dcc0"), "dusk": Color("#d59c7c"), "night": Color("#5c7f97")}[phase])
	_glazing.set_shader_parameter("glass_dark", {"dawn": Color("#8f9c86"), "noon": Color("#7d9479"), "dusk": Color("#5a6a70"), "night": Color("#27405a")}[phase])
	_clear_glazing.set_shader_parameter("glass_light", {"dawn": Color("#ffe6cf"), "noon": Color("#eaf6e6"), "dusk": Color("#ffc59c"), "night": Color("#8fb4d6")}[phase])
	_clear_glazing.set_shader_parameter("glass_dark", {"dawn": Color("#c9b9a5"), "noon": Color("#b5cdb4"), "dusk": Color("#a98a86"), "night": Color("#46627f")}[phase])
	_shafts.set_shader_parameter("intensity", {"dawn": 0.34, "noon": 0.3, "dusk": 0.3, "night": 0.1}[phase])
	_shafts.set_shader_parameter("shaft_color", {"dawn": Color("#ffd9b0"), "noon": Color("#fff0c0"), "dusk": Color("#ffb070"), "night": Color("#9ec8ff")}[phase])
	for material in _shaded:
		material.set_shader_parameter("leaf_shade", (0.35 if evening else 1.0) * float(material.get_meta("shade", 0.0)))


func surface(key: String, tint: Color, style: Style, moss := 0.3, shade := 0.0, tile := Vector2(1.3, 0.84)) -> ShaderMaterial:
	var cache_key := "garden:" + key
	if world.material_cache.has(cache_key): return world.material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = Paving
	material.set_shader_parameter("finish_tone", tint)
	material.set_shader_parameter("finish_style", style)
	material.set_shader_parameter("moss", moss)
	material.set_shader_parameter("tile_size", tile)
	material.set_meta("shade", shade)
	if shade > 0.0: _shaded.append(material)
	world.material_cache[cache_key] = material
	return material


## Batched plant surface: `flex` is how far it bends, `fold` makes it shy of the walker.
func plant(key: String, flex: float, fold := 0.0) -> ShaderMaterial:
	var cache_key := "garden-plant:" + key
	if world.material_cache.has(cache_key): return world.material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = Plant
	material.set_shader_parameter("flex", flex)
	material.set_shader_parameter("fold", fold)
	world.material_cache[cache_key] = material
	return material


func brick() -> ShaderMaterial:
	return surface("brick", Color("#b06a4c"), Style.BRICK, 0.5)


func coping() -> ShaderMaterial:
	return surface("coping", Color("#b9b6a0"), Style.ROCK, 0.35)


## Depth of every side-wall column, north to south.
static func _columns() -> Array[float]:
	var columns: Array[float] = []
	columns.append_array(FULL_ARCHES)
	columns.append_array(STUB_ARCHES)
	return columns


## Height of the roof arch over `x`.
static func arch_y(x: float) -> float:
	return EAVE + (RIDGE - EAVE) * sqrt(maxf(0.0, 1.0 - pow(x / WALL_X, 2.0)))


static func _terrain_quad(tool: SurfaceTool, rect: Rect2) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(corners[index].x, 0.0, corners[index].y))


func _build_terrain() -> void:
	# One ring of ground around the house; it runs well past what the camera can see.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reach: Rect2 = world.dress_rect(Rect2(-58, -54, 116, 110))
	_terrain_quad(tool, Rect2(reach.position.x, reach.position.y, reach.size.x, HOUSE.position.y - reach.position.y))
	_terrain_quad(tool, Rect2(reach.position.x, HOUSE.end.y, reach.size.x, reach.end.y - HOUSE.end.y))
	_terrain_quad(tool, Rect2(reach.position.x, HOUSE.position.y, HOUSE.position.x - reach.position.x, HOUSE.size.y))
	_terrain_quad(tool, Rect2(HOUSE.end.x, HOUSE.position.y, reach.end.x - HOUSE.end.x, HOUSE.size.y))
	var floor_material := ShaderMaterial.new()
	floor_material.shader = Ground
	floor_material.set_shader_parameter("clearing", Vector4(0.0, 1.5, 15.5, 15.5))
	var path := PackedVector2Array(PATH)
	path.resize(8)
	floor_material.set_shader_parameter("path_points", path)
	floor_material.set_shader_parameter("path_count", PATH.size())
	floor_material.set_meta("shade", 0.75)
	_shaded.append(floor_material)
	world.material_cache["garden:woodland-floor"] = floor_material
	var ground: MeshInstance3D = world._mesh(tool.commit(), Vector3(0, TERRAIN_Y, 0), floor_material)
	ground.name = "GardenContinuousApron"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_house() -> void:
	var walls := kit.surface(brick())
	var caps := kit.surface(coping())
	var detail := kit.detail
	var depth := HOUSE.size.y
	var middle_z := HOUSE.get_center().y
	# Brick plinths reach below the pool so no gap opens under them.
	walls.add(Vector3(0, PLINTH * 0.5 - 0.15, NORTH_Z), Vector3(HOUSE.size.x, PLINTH + 0.3, 0.5))
	caps.add(Vector3(0, PLINTH + 0.04, NORTH_Z), Vector3(HOUSE.size.x + 0.12, 0.08, 0.64))
	for side: float in [-1.0, 1.0]:
		walls.add(Vector3(side * WALL_X, PLINTH * 0.5 - 0.15, middle_z), Vector3(0.5, PLINTH + 0.3, depth))
		caps.add(Vector3(side * WALL_X, PLINTH + 0.04, middle_z), Vector3(0.64, 0.08, depth + 0.12))
		# The front wall is only knee high, so the garden stays open to view.
		var front := (WALL_X + 0.25 + DOOR_HALF + 0.3) * 0.5
		walls.add(Vector3(side * front, 0.2, SOUTH_Z), Vector3(WALL_X + 0.25 - DOOR_HALF - 0.3, 0.7, 0.5))
		caps.add(Vector3(side * front, 0.59, SOUTH_Z), Vector3(WALL_X + 0.25 - DOOR_HALF - 0.3, 0.08, 0.64))
		detail.box(Vector3(side * front, 0.7, SOUTH_Z), Vector3(WALL_X - DOOR_HALF - 0.6, 0.04, 0.04), Props.IRON)
		for spike in range(12):
			var x := side * (DOOR_HALF + 0.9 + 0.72 * float(spike))
			detail.box(Vector3(x, 0.72, SOUTH_Z), Vector3(0.04, 0.2, 0.04), Props.IRON)
			detail.tube(Vector3(x, 0.86, SOUTH_Z), 0.04, 0.0, 0.1, Props.BRASS, 4)
		# Side walls: a column under every arch, a transom and the eaves beam.
		for z: float in _columns():
			detail.box(Vector3(side * WALL_X, (PLINTH + EAVE) * 0.5, z), Vector3(0.16, EAVE - PLINTH, 0.16), Props.IRON)
			detail.box(Vector3(side * WALL_X, EAVE - 0.06, z), Vector3(0.26, 0.12, 0.26), Props.BRASS)
			detail.box(Vector3(side * WALL_X, PLINTH + 0.14, z), Vector3(0.24, 0.12, 0.24), Props.IRON_LIGHT)
		detail.box(Vector3(side * WALL_X, TRANSOM, middle_z - 0.12), Vector3(0.08, 0.08, SOUTH_Z - NORTH_Z), Props.IRON)
		detail.box(Vector3(side * WALL_X, EAVE + 0.06, middle_z - 0.12), Vector3(0.18, 0.14, SOUTH_Z - NORTH_Z + 0.3), Props.IRON)
		# Purlins tie the arches together; the outer one runs the whole length.
		detail.box(Vector3(side * STUB_REACH, arch_y(STUB_REACH) + 0.02, middle_z - 0.12), Vector3(0.1, 0.1, SOUTH_Z - NORTH_Z), Props.IRON_LIGHT)
		detail.box(Vector3(side * 5.0, arch_y(5.0) + 0.02, (FULL_ARCHES[0] + FULL_ARCHES[2]) * 0.5), Vector3(0.1, 0.1, FULL_ARCHES[2] - FULL_ARCHES[0]), Props.IRON_LIGHT)
		for z: float in STUB_ARCHES:
			_arch(z, side * WALL_X, side * STUB_REACH)
			detail.tube(Vector3(side * STUB_REACH, arch_y(STUB_REACH) - 0.14, z), 0.07, 0.0, 0.2, Props.BRASS, 5)
	for z: float in FULL_ARCHES:
		_arch(z, -WALL_X, WALL_X)
	# Ridge beam with a brass cresting and the weather vane's mast at its open end.
	detail.box(Vector3(0, RIDGE + 0.04, (FULL_ARCHES[0] + FULL_ARCHES[2]) * 0.5), Vector3(0.16, 0.16, FULL_ARCHES[2] - FULL_ARCHES[0] + 0.2), Props.IRON)
	for crest in range(12):
		detail.tube(Vector3(0, RIDGE + 0.22, FULL_ARCHES[0] + 0.4 + 0.72 * float(crest)), 0.07, 0.0, 0.22, Props.BRASS, 4)
	detail.tube(RIDGE_END + Vector3(0, 0.55, 0), 0.05, 0.04, 1.0, Props.IRON, 6)
	detail.tube(RIDGE_END + Vector3(0, 0.6, 0), 0.12, 0.12, 0.1, Props.BRASS, 8)
	for arm in range(2):
		detail.box(RIDGE_END + Vector3(0, 0.85, 0), Vector3(0.7, 0.04, 0.04), Props.IRON, Basis(Vector3.UP, PI * 0.5 * float(arm)))
	# North wall: seven bays of glazing up into the gable.
	var painted := SurfaceTool.new()
	painted.begin(Mesh.PRIMITIVE_TRIANGLES)
	detail.box(Vector3(0, TRANSOM, NORTH_Z), Vector3(WALL_X * 2.0, 0.08, 0.1), Props.IRON)
	detail.box(Vector3(0, EAVE, NORTH_Z), Vector3(WALL_X * 2.0, 0.1, 0.12), Props.IRON)
	for bay in range(8):
		var x := -WALL_X + 3.5 * float(bay)
		var top := arch_y(x)
		detail.box(Vector3(x, (PLINTH + top) * 0.5, NORTH_Z), Vector3(0.14, top - PLINTH, 0.14), Props.IRON)
		if bay == 7: break
		var from := x + 0.09
		var to := x + 3.41
		for half in range(2):
			# Two lights per bay, split by a thin glazing bar.
			var left := lerpf(from, to, 0.5 * float(half)) + 0.03
			var right := lerpf(from, to, 0.5 * float(half + 1)) - 0.03
			_pane(painted, Vector3(left, PLINTH + 0.1, NORTH_Z), Vector3(right, PLINTH + 0.1, NORTH_Z), Vector3(right, TRANSOM - 0.05, NORTH_Z), Vector3(left, TRANSOM - 0.05, NORTH_Z))
			_pane(painted, Vector3(left, TRANSOM + 0.05, NORTH_Z), Vector3(right, TRANSOM + 0.05, NORTH_Z), Vector3(right, EAVE - 0.06, NORTH_Z), Vector3(left, EAVE - 0.06, NORTH_Z))
			_pane(painted, Vector3(left, EAVE + 0.06, NORTH_Z), Vector3(right, EAVE + 0.06, NORTH_Z), Vector3(right, maxf(EAVE + 0.08, arch_y(right) - 0.08), NORTH_Z), Vector3(left, maxf(EAVE + 0.08, arch_y(left) - 0.08), NORTH_Z))
		detail.box(Vector3(x + 1.75, (PLINTH + EAVE) * 0.5, NORTH_Z), Vector3(0.05, EAVE - PLINTH, 0.06), Props.IRON_LIGHT)
	_glazing = ShaderMaterial.new()
	_glazing.shader = Glass
	_glazing.set_shader_parameter("clarity", 0.42)
	world.material_cache["garden:glazing"] = _glazing
	var back: MeshInstance3D = world._mesh(painted.commit(), Vector3.ZERO, _glazing)
	back.name = "GardenGlazing"
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Clear panes: both side walls and the roof over the north end.
	var clear := SurfaceTool.new()
	clear.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := _columns()
	for side: float in [-1.0, 1.0]:
		var x := side * WALL_X
		for index in range(columns.size() - 1):
			var from := columns[index] + 0.1
			var to := columns[index + 1] - 0.1
			_pane(clear, Vector3(x, PLINTH + 0.1, to), Vector3(x, PLINTH + 0.1, from), Vector3(x, TRANSOM - 0.05, from), Vector3(x, TRANSOM - 0.05, to))
			_pane(clear, Vector3(x, TRANSOM + 0.05, to), Vector3(x, TRANSOM + 0.05, from), Vector3(x, EAVE - 0.06, from), Vector3(x, EAVE - 0.06, to))
	for bay in range(FULL_ARCHES.size() - 1):
		for step in range(10):
			var from_x := -WALL_X + 2.45 * float(step) + 0.06
			var to_x := -WALL_X + 2.45 * float(step + 1) - 0.06
			_pane(clear, Vector3(from_x, arch_y(from_x), FULL_ARCHES[bay + 1] - 0.08), Vector3(to_x, arch_y(to_x), FULL_ARCHES[bay + 1] - 0.08),
				Vector3(to_x, arch_y(to_x), FULL_ARCHES[bay] + 0.08), Vector3(from_x, arch_y(from_x), FULL_ARCHES[bay] + 0.08))
			detail.box(Vector3(from_x - 0.06, arch_y(from_x - 0.06) + 0.02, (FULL_ARCHES[bay] + FULL_ARCHES[bay + 1]) * 0.5), Vector3(0.04, 0.04, FULL_ARCHES[bay + 1] - FULL_ARCHES[bay]), Props.IRON_LIGHT)
	_clear_glazing = ShaderMaterial.new()
	_clear_glazing.shader = Glass
	_clear_glazing.set_shader_parameter("clarity", 1.0)
	world.material_cache["garden:clear-glazing"] = _clear_glazing
	var panes: MeshInstance3D = world._mesh(clear.commit(), Vector3.ZERO, _clear_glazing)
	panes.name = "GardenClearGlazing"
	panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One glass pane; corners run bottom-left, bottom-right, top-right, top-left.
static func _pane(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var corners: Array[Vector3] = [a, b, c, d]
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for index: int in [0, 3, 2, 0, 2, 1]:
		tool.set_uv(uvs[index])
		tool.add_vertex(corners[index])


## Iron rib following the roof arch at depth `z` between two x positions.
func _arch(z: float, from_x: float, to_x: float) -> void:
	var steps := maxi(3, int(absf(to_x - from_x) / 0.9))
	for step in range(steps):
		var a_x := lerpf(from_x, to_x, float(step) / float(steps))
		var b_x := lerpf(from_x, to_x, float(step + 1) / float(steps))
		var a := Vector3(a_x, arch_y(a_x), z)
		var b := Vector3(b_x, arch_y(b_x), z)
		var span := b - a
		kit.detail.box((a + b) * 0.5, Vector3(span.length() + 0.05, 0.13, 0.15), Props.IRON, Basis(Vector3.BACK, atan2(span.y, span.x)))


func _build_doorway() -> void:
	# Its own mesh, because the portrait camera stands just outside this door.
	var gate := Kit.Sculpt.new()
	var brick_tone := Color("#b06a4c")
	for side: float in [-1.0, 1.0]:
		var pier := Vector3(side * (DOOR_HALF + 0.3), 0, SOUTH_Z)
		gate.box(pier + Vector3(0, 1.2, 0), Vector3(0.66, 2.4, 0.66), brick_tone)
		for course in range(6):
			gate.box(pier + Vector3(0, 0.3 + 0.38 * float(course), 0), Vector3(0.69, 0.035, 0.69), Color("#c9b9a0") if course % 2 == 0 else brick_tone.darkened(0.2))
		gate.box(pier + Vector3(0, 2.46, 0), Vector3(0.86, 0.12, 0.86), Props.STONE)
		gate.tube(pier + Vector3(0, 2.66, 0), 0.2, 0.26, 0.28, Props.STONE.lightened(0.08), 8)
		gate.tube(pier + Vector3(0, 2.9, 0), 0.24, 0.02, 0.24, Props.STONE, 8)
		# The doors stand open into the forecourt.
		var leaf := Basis(Vector3.UP, side * -1.15)
		var hinge := Vector3(side * DOOR_HALF, 0, SOUTH_Z + 0.2)
		for rail: float in [0.3, 1.25, 2.2]:
			gate.box(hinge + leaf * Vector3(-side * 0.8, rail, 0), Vector3(1.6, 0.08, 0.06), Props.IRON, leaf)
		for stile in range(4):
			gate.box(hinge + leaf * Vector3(-side * 0.53 * float(stile), 1.25, 0), Vector3(0.06 if stile % 3 == 0 else 0.035, 1.9, 0.05), Props.IRON, leaf)
		gate.box(hinge + leaf * Vector3(-side * 0.8, 0.72, 0), Vector3(1.5, 0.76, 0.03), Props.IRON_LIGHT, leaf)
	# The name board stands on the west wall, clear of anyone walking through the door.
	var board := Vector3(-5.7, 1.62, SOUTH_Z)
	for side: float in [-1.0, 1.0]:
		gate.box(board + Vector3(side * 1.1, -0.5, 0), Vector3(0.07, 1.1, 0.07), Props.IRON)
		gate.tube(board + Vector3(side * 1.1, 0.12, 0), 0.06, 0.0, 0.16, Props.BRASS, 5)
		gate.box(board + Vector3(0, side * 0.26, 0.01), Vector3(2.5, 0.05, 0.1), Props.BRASS)
	gate.box(board, Vector3(2.4, 0.48, 0.07), Props.IRON.darkened(0.15))
	doorway = world._mesh(gate.mesh(), Vector3.ZERO, world._vertex_color_material("scenery-detail"))
	doorway.name = "GardenDoorway"
	story_front.append(doorway)
	world._local_label("苔光溫室", board + Vector3(0, 0, 0.2), 24, Color("#f5e9b8"))
	# Stone threshold between the two piers.
	kit.surface(coping()).add(Vector3(0, 0.1, SOUTH_Z), Vector3(DOOR_HALF * 2.0, 0.2, 0.5))


func _build_water() -> void:
	wetland_water = ShaderMaterial.new()
	wetland_water.shader = Water
	world.material_cache["garden:wetland-water"] = wetland_water
	var pool: Rect2 = world.WETLAND_WATER
	var plane := PlaneMesh.new()
	plane.size = pool.size
	var surface_mesh: MeshInstance3D = world._mesh(plane, Vector3(pool.get_center().x, WATER_Y, pool.get_center().y), wetland_water)
	surface_mesh.name = "GardenWetlandWater"
	surface_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caps := kit.surface(coping())
	caps.add(Vector3(pool.get_center().x, 0.215, pool.end.y + 0.14), Vector3(pool.size.x, 0.05, 0.3))
	caps.add(Vector3(pool.get_center().x, 0.215, pool.position.y - 0.14), Vector3(pool.size.x, 0.05, 0.3))
	caps.add(Vector3(pool.end.x + 0.14, 0.215, pool.get_center().y), Vector3(0.3, 0.05, pool.size.y + 0.56))
	var boardwalk: Rect2 = world.BOARDWALK
	for side: float in [-1.0, 1.0]:
		var edge := boardwalk.get_center().x + side * (boardwalk.size.x * 0.5 - 0.06)
		kit.detail.box(Vector3(edge, 0.24, boardwalk.get_center().y), Vector3(0.12, 0.08, boardwalk.size.y), Props.WOOD_DARK)
		for post in range(5):
			var z := boardwalk.position.y + 0.3 + (boardwalk.size.y - 0.6) * float(post) / 4.0
			kit.piles().add(Vector3(edge + side * 0.05, 0.14, z), Vector3(0.2, 0.74, 0.2))
			kit.detail.tube(Vector3(edge + side * 0.05, 0.54, z), 0.12, 0.12, 0.05, Props.BRASS, 8)
	# Lily pads, lotus and reeds; pads keep clear of the boardwalk.
	var pads := kit.batch("lily-pads", Props.lily_pad_mesh(), world._vertex_color_material("scenery-detail"))
	lily_pads = pads
	var lotus := kit.batch("lotus", Props.lotus_mesh(), world._vertex_color_material("scenery-detail"))
	var reeds := kit.batch("reeds", Props.reed_mesh(), plant("reeds", 0.05))
	for index in range(34):
		var west := index % 3 != 0
		var x := lerpf(-11.6, -9.0, Props.scatter(float(index) * 1.3)) if west else lerpf(-5.4, -4.6, Props.scatter(float(index) * 1.3))
		var z := lerpf(pool.position.y + 0.5, pool.end.y - 0.5, Props.scatter(float(index) * 2.9 + 4.0))
		if Vector2(x, z).distance_to(Vector2(ISLET.x, ISLET.z)) < 1.3: continue
		var size := 0.55 + 0.5 * Props.scatter(float(index) * 5.1)
		pads.add(Vector3(x, WATER_Y + 0.012, z), Vector3(size, 1.0, size), Basis(Vector3.UP, float(index) * 1.7), Color("#6fae6c").lerp(Color("#3f8a5a"), Props.scatter(float(index))))
		if index % 5 == 1:
			lotus.add(Vector3(x, WATER_Y + 0.02, z), Vector3.ONE * (1.1 + 0.4 * Props.scatter(float(index))), Basis(Vector3.UP, float(index)), Props.BLOOMS[0] if index % 2 == 0 else Props.BLOOMS[2])
	for index in range(16):
		var along := Props.scatter(float(index) * 3.3)
		var at := Vector3(-11.75 + 0.5 * Props.scatter(float(index) * 7.7), WATER_Y, lerpf(pool.position.y + 0.3, pool.end.y - 0.3, along))
		if index % 4 == 3: at = Vector3(lerpf(-11.4, -9.2, along), WATER_Y, pool.position.y + 0.35)
		reeds.add(at, Vector3.ONE * (0.9 + 0.5 * Props.scatter(float(index))), Basis(Vector3.UP, float(index)))
	# A mossy islet with a stone lantern, reached by stepping stones nobody walks on.
	kit.mound(Rect2(ISLET.x - 0.55, ISLET.z - 0.55, 1.1, 1.1), ISLET.y, 0.3, 0.5, surface("moss-bank", Color("#6f8f4a"), Style.ROCK, 0.85), 2.2)
	Props.stone_lantern(kit, ISLET + Vector3(0.1, -0.02, -0.1))
	var stones := kit.batch("flagstones", Props.flagstone_mesh(), world._vertex_color_material("scenery-detail"))
	for index in range(3):
		stones.add(Vector3(-9.05 - 0.42 * float(index), WATER_Y - 0.02, -1.85 - 0.1 * float(index)), Vector3(0.8, 1.6, 0.7), Basis(Vector3.UP, float(index) * 1.9), Color("#a9ab98").darkened(0.08 * float(index % 2)))
	# Round lily pond with a fountain; rills feed it from the terraces and drain to the wetland.
	var pond_top := Vector3(POND.x, POND_SURFACE, POND.z)
	kit.detail.tube(POND + Vector3(0, 0.17, 0), POND_RADIUS + 0.34, POND_RADIUS + 0.28, 0.34, Props.STONE_DARK, 16)
	for block in range(16):
		var around := Basis(Vector3.UP, TAU * float(block) / 16.0)
		kit.detail.box(POND + around * Vector3(POND_RADIUS + 0.14, 0.44, 0), Vector3(0.3, 0.22, 0.6), Props.STONE if block % 2 == 0 else Props.STONE.lightened(0.09), around)
		if block % 3 == 0:
			kit.detail.box(POND + around * Vector3(POND_RADIUS + 0.2, 0.57, 0.1), Vector3(0.22, 0.05, 0.3), Props.MOSS, around)
	var basin := ShaderMaterial.new()
	basin.shader = Water
	basin.set_shader_parameter("bank", 0.0)
	basin.set_shader_parameter("shallow_color", Color("#3f8a80"))
	world.material_cache["garden:pond-water"] = basin
	var disc := CylinderMesh.new()
	disc.top_radius = POND_RADIUS + 0.02
	disc.bottom_radius = POND_RADIUS + 0.02
	disc.height = 0.02
	disc.radial_segments = 16
	var pond_surface: MeshInstance3D = world._mesh(disc, pond_top, basin)
	pond_surface.name = "GardenLilyPond"
	pond_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Props.fountain(kit, pond_top - Vector3(0, 0.3, 0))
	for index in range(7):
		var around := Basis(Vector3.UP, 0.9 * float(index) + 0.3)
		var at := pond_top + around * Vector3(0.75 + 0.3 * Props.scatter(float(index)), 0.02, 0)
		pads.add(at, Vector3.ONE * (0.42 + 0.2 * Props.scatter(float(index) * 3.0)), around, Color("#6fae6c"))
		if index % 3 == 0: lotus.add(at + Vector3(0, 0.01, 0), Vector3.ONE * 0.9, around, Props.BLOOMS[0])
	kit.blocker(POND + Vector3(0, 0.8, 0), Vector3(2.9, 1.6, 2.9))
	var channel := ShaderMaterial.new()
	channel.shader = Water
	channel.set_shader_parameter("channel_flow", 0.55)
	channel.set_shader_parameter("shallow_color", Color("#5aa79a"))
	world.material_cache["garden:rill-water"] = channel
	var rills := SurfaceTool.new()
	rills.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Water runs west: from the terrace spout, through the pond, into the wetland bed.
	for run: Vector2 in [Vector2(5.1, POND.x + POND_RADIUS + 0.3), Vector2(POND.x - POND_RADIUS - 0.3, -4.2)]:
		var corners: Array[Vector3] = [Vector3(run.x, 0.212, POND.z - 0.17), Vector3(run.y, 0.212, POND.z - 0.17), Vector3(run.y, 0.212, POND.z + 0.17), Vector3(run.x, 0.212, POND.z + 0.17)]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(run.x - run.y, 0), Vector2(run.x - run.y, 1), Vector2(0, 1)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			rills.set_normal(Vector3.UP)
			rills.set_uv(uvs[index])
			rills.add_vertex(corners[index])
		for side: float in [-1.0, 1.0]:
			caps.add(Vector3((run.x + run.y) * 0.5, 0.213, POND.z + side * 0.24), Vector3(run.x - run.y, 0.03, 0.14))
	var rill: MeshInstance3D = world._mesh(rills.commit(), Vector3.ZERO, channel)
	rill.name = "GardenRills"
	rill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.detail.box(Vector3(5.08, 0.62, POND.z), Vector3(0.14, 0.5, 0.5), Props.STONE)
	kit.detail.tube(Vector3(4.96, 0.62, POND.z), 0.06, 0.05, 0.2, Props.BRASS, 6, Basis(Vector3.BACK, PI * 0.5))
	kit.detail.box(Vector3(4.86, 0.42, POND.z), Vector3(0.05, 0.4, 0.07), Color("#8fd3c8"))


## Signboard on two stakes; the label floats in front of it.
func _stake_sign(text: String, at: Vector3, width: float) -> void:
	for side: float in [-1.0, 1.0]:
		kit.detail.box(Vector3(at.x + side * (width * 0.5 - 0.1), (at.y + world.GROUND_Y) * 0.5, at.z - 0.04), Vector3(0.06, at.y - world.GROUND_Y + 0.3, 0.06), Props.WOOD_DARK)
	kit.detail.box(at, Vector3(width, 0.36, 0.07), Props.IRON.darkened(0.1))
	kit.detail.box(at + Vector3(0, -0.2, 0.01), Vector3(width + 0.06, 0.04, 0.09), Props.BRASS)
	kit.detail.box(at + Vector3(0, 0.2, 0.01), Vector3(width + 0.06, 0.04, 0.09), Props.BRASS)
	var label: Label3D = world._local_label(text, at + Vector3(0, 0.015, 0.06), 22, Color("#f5e9b8"))
	label.outline_size = 1


func _build_furniture() -> void:
	var detail := kit.detail
	# Brass inlays mark where each interaction happens.
	for spot: Vector3 in [world.ENTRY, world.SWITCH, world.WETLAND, world.VINE, world.BUDS]:
		for side: float in [-1.0, 1.0]:
			detail.box(spot + Vector3(0.42 * side, 0.02, 0), Vector3(0.07, 0.04, 0.56), Props.BRASS)
	for x: float in [-3.93, 3.93]:
		detail.box(Vector3(x, world.GROUND_Y + 0.008, 1.18), Vector3(0.08, 0.02, 15.2), Props.BRASS.darkened(0.1))
	_stake_sign("濕地床", Vector3(-10.31, 0.92, 4.16), 1.5)
	_stake_sign("藤蔓層", Vector3(9.93, 1.19, -5.16), 1.42)
	_stake_sign("夜芽庭", Vector3(0, 1.13, -10.74), 1.57)
	# Potting corner against the north wall, with the rain barrel under the downpipe.
	Props.potting_table(kit, Vector3(-9.6, 0.2, -11.15), 0.0)
	Props.rain_barrel(kit, Vector3(-11.3, 0.2, -11.05))
	detail.tube(Vector3(-11.75, 2.2, -11.45), 0.06, 0.06, 2.5, Props.IRON_LIGHT, 6)
	detail.box(Vector3(-11.55, 1.0, -11.3), Vector3(0.4, 0.08, 0.08), Props.IRON_LIGHT, Basis(Vector3.UP, 0.6))
	Props.watering_can(detail, Vector3(-8.2, 0.2, -11.0), 0.5)
	Props.watering_can(detail, Vector3(-10.85, 0.2, -10.3), -0.9, Color("#6fa39a"))
	kit.blocker(Vector3(-10.1, 1.0, -11.15), Vector3(3.6, 1.6, 0.9))
	# Staging benches of pots and seed trays in the south corners.
	Props.staging(kit, Vector3(-8.2, 0.2, 8.9), 0.0, 3.6, 1.0)
	kit.blocker(Vector3(-8.2, 1.0, 8.95), Vector3(3.7, 1.6, 0.7))
	Props.staging(kit, Vector3(-11.5, 0.2, 6.4), PI * 0.5, 2.6, 5.0)
	kit.blocker(Vector3(-11.5, 1.0, 6.4), Vector3(0.75, 1.6, 2.7))
	Props.staging(kit, Vector3(8.0, 0.2, 8.9), 0.0, 3.2, 9.0)
	kit.blocker(Vector3(8.0, 1.0, 8.95), Vector3(3.3, 1.6, 0.7))
	Props.garden_seat(kit, Vector3(11.45, 0.2, 7.3), -PI * 0.5)
	kit.blocker(Vector3(11.5, 1.0, 7.3), Vector3(0.8, 1.6, 1.7))
	Props.watering_can(detail, Vector3(5.9, 0.2, 8.8), 2.4)
	# Large pots frame the door and line the terrace ramp.
	for side: float in [-1.0, 1.0]:
		Props.pot(detail, Vector3(side * 3.75, 0.2, 8.95), 0.62, 0)
		Props.pot(detail, Vector3(side * 3.7, 0.2, -7.3), 0.5, 2, Props.BLOOMS[3])
	var slot := 0
	for z: float in [3.16, 1.55, -0.43, -2.53, -5.53, -6.89]:
		for x: float in [5.03, 9.38]:
			Props.pot(detail, Vector3(x, 0.2, z), 0.4 + 0.08 * float(slot % 2), slot, Props.BLOOMS[slot % Props.BLOOMS.size()])
			slot += 1
	# Sundial in the shady north-west bay.
	Props.sundial(kit, Vector3(-10.2, 0.2, -6.3))
	kit.blocker(Vector3(-10.2, 1.0, -6.3), Vector3(1.0, 1.6, 1.0))
	Props.wheelbarrow(kit, Vector3(-14.6, TERRAIN_Y, 7.4), 0.5)
	# Night buds in raised brick beds along the north wall.
	for side: float in [-1.0, 1.0]:
		var bed := Vector3(side * 4.55, 0, -10.83)
		kit.surface(brick()).add(bed + Vector3(0, 0.42, 0), Vector3(5.35, 0.44, 1.25))
		kit.surface(coping()).add(bed + Vector3(0, 0.66, 0), Vector3(5.47, 0.06, 1.37))
		kit.surface(surface("soil", Color("#4f3f2e"), Style.ROCK, 0.25)).add(bed + Vector3(0, 0.68, 0), Vector3(5.1, 0.05, 1.0))
		kit.blocker(bed + Vector3(0, 1.0, 0), Vector3(5.35, 1.6, 1.25))
		for index in range(7):
			var stem := bed + Vector3((float(index) - 3.0) * 0.7, 0.7, 0.1 * float(index % 2) - 0.05)
			var tall := 0.3 + 0.16 * float(index % 3)
			detail.box(stem + Vector3(0, tall * 0.5, 0), Vector3(0.05, tall, 0.05), Props.LEAF_DARK)
			for blade in range(4):
				var around := Basis(Vector3.UP, 1.57 * float(blade) + float(index))
				Props.leaf(detail, stem, stem + around * Vector3(0.3, 0.16, 0), 0.2, Props.LEAF if blade % 2 == 0 else Props.LEAF_DARK)
			night_glow.tube(stem + Vector3(0, tall + 0.13, 0), 0.07, 0.15, 0.2, Color("#bfeecd"), 6)
			night_glow.tube(stem + Vector3(0, tall + 0.29, 0), 0.15, 0.03, 0.14, Color("#e6fbe0"), 6)


func _build_indoor_planting() -> void:
	var detail := kit.detail
	var baskets := kit.batch("baskets", Props.basket_mesh(), plant("hanging", 0.09))
	for index in range(BASKETS.size()):
		var hook := BASKETS[index]
		baskets.add(hook, Vector3.ONE * 1.25, Basis(Vector3.UP, float(index) * 1.3), Props.BLOOMS[index % Props.BLOOMS.size()].lerp(Color.WHITE, 0.35))
		if absf(hook.x) > 10.0:
			detail.box(Vector3(signf(hook.x) * 11.8, hook.y + 0.04, hook.z), Vector3(1.0, 0.05, 0.05), Props.IRON)
			detail.box(Vector3(signf(hook.x) * 11.9, hook.y - 0.22, hook.z), Vector3(0.7, 0.04, 0.04), Props.IRON_LIGHT, Basis(Vector3.BACK, signf(hook.x) * 0.75))
		else:
			detail.box(hook + Vector3(0, 0.04, -0.25), Vector3(0.05, 0.05, 0.6), Props.IRON)
	# Trellis panels in the north corners and vines trailing from every transom.
	var vines := kit.batch("vines", Props.vine_mesh(), plant("vines", 0.05))
	for side: float in [-1.0, 1.0]:
		Props.trellis(detail, Vector3(side * 11.7, 0.2, NORTH_Z + 0.32), Vector3(side * 7.9, 0.2, NORTH_Z + 0.32), 3.0, Props.WOOD)
	for index in range(46):
		var x := -11.6 + 23.2 * Props.scatter(float(index) * 1.9)
		var corner := absf(x) > 7.9
		var top := 3.2 if corner else (EAVE if index % 2 == 0 else TRANSOM)
		vines.add(Vector3(x, top - 0.1 * Props.scatter(float(index)), NORTH_Z + (0.4 if corner else 0.12)), Vector3.ONE * (1.0 + 0.5 * Props.scatter(float(index) * 4.0)), Basis(Vector3.UP, float(index)))
	for side: float in [-1.0, 1.0]:
		for index in range(18):
			var z := lerpf(NORTH_Z + 0.5, SOUTH_Z - 0.6, Props.scatter(float(index) * 2.7 + side))
			vines.add(Vector3(side * (WALL_X - 0.14), TRANSOM if index % 3 != 0 else EAVE, z), Vector3.ONE * (0.9 + 0.6 * Props.scatter(float(index) * 5.0)), Basis(Vector3.UP, PI * 0.5 + float(index)))
		for z: float in STUB_ARCHES:
			for strand in range(3):
				vines.add(Vector3(side * (STUB_REACH + 0.5 * float(strand)), arch_y(STUB_REACH + 0.5 * float(strand)) - 0.05, z), Vector3.ONE * (1.1 + 0.3 * float(strand)), Basis(Vector3.UP, float(strand)))
	# Touch-me-nots ring the pond and stand by the door; ferns fill the shade.
	var shy := kit.batch("touch-me-not", Props.fern_mesh(), plant("touch-me-not", 0.03, 1.0))
	for index in range(14):
		var around := Basis(Vector3.UP, TAU * float(index) / 14.0 + 0.2)
		shy.add(POND + around * Vector3(POND_RADIUS + 0.62, 0.02, 0), Vector3.ONE * (0.75 + 0.25 * Props.scatter(float(index))), around)
	for at: Vector3 in [Vector3(-3.3, 0.2, 9.0), Vector3(3.25, 0.2, 9.05), Vector3(-9.5, 0.2, -5.8), Vector3(-10.9, 0.2, -6.7), Vector3(-10.4, 0.2, -5.6)]:
		shy.add(at, Vector3.ONE * 0.9, Basis(Vector3.UP, at.x))
	var ferns := kit.batch("ferns", Props.fern_mesh(), plant("ferns", 0.04))
	for index in range(26):
		var at := Vector3(lerpf(-11.7, -4.6, Props.scatter(float(index) * 1.7)), 0.2, lerpf(-7.7, -7.0, Props.scatter(float(index) * 3.1)))
		if index % 3 == 0: at = Vector3(-11.6 + 0.4 * Props.scatter(float(index)), 0.2, lerpf(-7.6, -4.9, Props.scatter(float(index) * 2.3)))
		if index % 3 == 1: at = Vector3(lerpf(9.6, 11.7, Props.scatter(float(index) * 2.1)), 0.2, lerpf(-7.7, -7.2, Props.scatter(float(index))))
		ferns.add(at, Vector3.ONE * (0.8 + 0.7 * Props.scatter(float(index) * 5.0)), Basis(Vector3.UP, float(index)))
	ferns.add(ISLET + Vector3(-0.3, 0, 0.3), Vector3.ONE * 1.1)
	# Toadstools in the damp corners, and glowing moss where the light never reaches.
	var toadstools := kit.batch("toadstools", Props.toadstool_mesh(), world._vertex_color_material("scenery-detail"))
	for index in range(18):
		var home := Vector3(-11.3, 0.2, -5.2) if index % 2 == 0 else Vector3(-11.2, 0.2, 4.4)
		if index % 5 == 4: home = Vector3(11.3, 0.2, -7.5)
		var at := home + Vector3(1.4 * Props.scatter(float(index) * 2.3), 0, 0.9 * Props.scatter(float(index) * 4.1) - 0.45)
		toadstools.add(at, Vector3.ONE * (0.8 + 0.9 * Props.scatter(float(index))), Basis(Vector3.UP, float(index)), Color("#d9573f") if index % 3 != 0 else Color("#e8c27a"))
	for index in range(40):
		var at := Vector3(-11.8 + 0.5 * Props.scatter(float(index) * 1.1), 0.21, lerpf(-11.4, 9.0, Props.scatter(float(index) * 3.7)))
		if index % 4 == 1: at = Vector3(11.8 - 0.5 * Props.scatter(float(index) * 1.1), 0.21, lerpf(-11.4, 5.8, Props.scatter(float(index) * 3.7)))
		if index % 4 == 2: at = Vector3(lerpf(-11.5, 11.5, Props.scatter(float(index) * 2.9)), 0.21, -11.55 + 0.3 * Props.scatter(float(index)))
		if index % 4 == 3: at = POND + Basis(Vector3.UP, float(index)) * Vector3(POND_RADIUS + 0.38, 0.01, 0)
		if world.WETLAND_WATER.has_point(Vector2(at.x, at.z)): at.y = WATER_Y + 0.02
		var size := 0.12 + 0.2 * Props.scatter(float(index) * 6.1)
		night_glow.tube(at, size, size * 0.5, 0.05, Color("#6fd08a") if index % 3 != 0 else Color("#5fc4cc"), 6)
	for index in range(9):
		var at := Vector3(-11.2 + 1.2 * Props.scatter(float(index) * 2.0), 0.2, -5.4 + 1.0 * Props.scatter(float(index) * 5.0))
		night_glow.tube(at + Vector3(0, 0.07, 0), 0.025, 0.02, 0.14, Color("#d8f0e0"), 4)
		night_glow.tube(at + Vector3(0, 0.17, 0), 0.1, 0.02, 0.09, Color("#6fd6e4"), 6)


func _build_forecourt() -> void:
	var detail := kit.detail
	var hedge := kit.surface(surface("hedge", Color("#3f7446"), Style.HEDGE))
	var flowers := kit.batch("flowers", Props.flower_mesh(), plant("flowers", 0.06))
	var stones := kit.batch("flagstones", Props.flagstone_mesh(), world._vertex_color_material("scenery-detail"))
	# Flagstones follow the path out to the welcome avenue, two abreast and uneven.
	for segment in range(PATH.size() - 1):
		var from := PATH[segment]
		var to := PATH[segment + 1]
		var steps := int(from.distance_to(to) / 0.85)
		for step in range(steps):
			for lane: float in [-1.0, 1.0]:
				var seed_value := float(segment) * 31.0 + float(step) * 2.0 + lane
				var across := (to - from).normalized().orthogonal() * lane * (0.42 + 0.14 * Props.scatter(seed_value))
				var at := from.lerp(to, (float(step) + 0.5 + 0.3 * lane * Props.scatter(seed_value + 5.0)) / float(steps)) + across
				if not world.in_dress_reach(at): continue
				var tone := 0.82 + 0.16 * Props.scatter(seed_value + 9.0)
				stones.add(Vector3(at.x, TERRAIN_Y - 0.02, at.y), Vector3(0.9 + 0.3 * Props.scatter(seed_value + 2.0), 1.0, 0.8 + 0.25 * Props.scatter(seed_value + 3.0)), Basis(Vector3.UP, seed_value), Color(tone * 0.6, tone * 0.62, tone * 0.54))
	# A paved apron in front of the door.
	for index in range(26):
		var at := Vector3(-4.6 + 9.2 * Props.scatter(float(index) * 1.9), TERRAIN_Y - 0.02, 10.2 + 1.9 * Props.scatter(float(index) * 4.3))
		if absf(at.x) < 1.1: continue
		var tone := 0.8 + 0.18 * Props.scatter(float(index))
		stones.add(at, Vector3(1.0, 1.0, 0.9), Basis(Vector3.UP, float(index)), Color(tone * 0.6, tone * 0.62, tone * 0.54))
	for index in range(PARTERRES.size()):
		var bed := PARTERRES[index]
		var center := bed.get_center()
		# Clipped hedge on all four sides, with taller corner blocks.
		for edge: float in [-1.0, 1.0]:
			hedge.add(Vector3(center.x, TERRAIN_Y + 0.3, center.y + edge * (bed.size.y * 0.5 - 0.25)), Vector3(bed.size.x, 0.6, 0.5))
			hedge.add(Vector3(center.x + edge * (bed.size.x * 0.5 - 0.25), TERRAIN_Y + 0.3, center.y), Vector3(0.5, 0.6, bed.size.y - 1.0))
			for corner: float in [-1.0, 1.0]:
				var at := Vector3(center.x + edge * (bed.size.x * 0.5 - 0.3), TERRAIN_Y, center.y + corner * (bed.size.y * 0.5 - 0.3))
				hedge.add(at + Vector3(0, 0.45, 0), Vector3(0.72, 0.9, 0.72))
				detail.tube(at + Vector3(0, 1.05, 0), 0.34, 0.1, 0.34, Color("#4c8650"), 6)
		kit.surface(surface("soil", Color("#4f3f2e"), Style.ROCK, 0.25)).add(Vector3(center.x, TERRAIN_Y + 0.03, center.y), Vector3(bed.size.x - 1.0, 0.06, bed.size.y - 1.0))
		for flower in range(70):
			var seed_value := float(index) * 100.0 + float(flower)
			var at := Vector3(lerpf(bed.position.x + 0.7, bed.end.x - 0.7, Props.scatter(seed_value * 1.3)), TERRAIN_Y + 0.06, lerpf(bed.position.y + 0.7, bed.end.y - 0.7, Props.scatter(seed_value * 2.9)))
			if Vector2(at.x, at.z).distance_to(center) < 0.9: continue
			# Drifts of one colour read better than confetti.
			var drift := int(floor((at.x - bed.position.x) / 1.6 + (at.z - bed.position.y) / 2.2))
			flowers.add(at, Vector3.ONE * (1.1 + 0.6 * Props.scatter(seed_value)), Basis(Vector3.UP, seed_value), Props.BLOOMS[posmod(drift + index, Props.BLOOMS.size())])
	# Loose flowers and ferns along the foot of the walls.
	var ferns := kit.batch("ferns", Props.fern_mesh(), plant("ferns", 0.04))
	for index in range(120):
		var seed_value := float(index) * 1.37
		var lap := Props.scatter(seed_value) * 4.0
		var along := Props.scatter(seed_value * 3.1)
		var out := 0.5 + 1.6 * Props.scatter(seed_value * 5.3)
		var at := Vector3(lerpf(HOUSE.position.x, HOUSE.end.x, along), TERRAIN_Y, HOUSE.position.y - out)
		if lap >= 3.0: at = Vector3(lerpf(HOUSE.position.x, HOUSE.end.x, along), TERRAIN_Y, HOUSE.end.y + out)
		elif lap >= 2.0: at = Vector3(HOUSE.end.x + out, TERRAIN_Y, lerpf(HOUSE.position.y, HOUSE.end.y, along))
		elif lap >= 1.0: at = Vector3(HOUSE.position.x - out, TERRAIN_Y, lerpf(HOUSE.position.y, HOUSE.end.y, along))
		if absf(at.x) < DOOR_HALF + 1.6 and at.z > 0.0: continue
		if index % 3 == 0:
			flowers.add(at, Vector3.ONE * (1.1 + 0.5 * Props.scatter(seed_value)), Basis(Vector3.UP, seed_value), Props.BLOOMS[index % Props.BLOOMS.size()])
		else:
			ferns.add(at, Vector3.ONE * (0.9 + 0.9 * Props.scatter(seed_value * 7.0)), Basis(Vector3.UP, seed_value))
	# Ferns, wild flowers and toadstools gather in drifts across the clearing.
	var toadstools := kit.batch("toadstools", Props.toadstool_mesh(), world._vertex_color_material("scenery-detail"))
	for index in range(420):
		var seed_value := float(index) * 0.731
		var spot := Vector2(lerpf(-21.0, 21.0, Props.scatter(seed_value)), lerpf(-20.0, 26.0, Props.scatter(seed_value * 3.7 + 1.0)))
		var drift := sin(spot.x * 0.55 + 1.3) * sin(spot.y * 0.47) + 0.5 * sin(spot.x * 1.3 - spot.y * 0.9)
		if drift < 0.25 or HOUSE.grow(0.4).has_point(spot) or _on_path(spot, 1.2) or _in_parterre(spot): continue
		var at := Vector3(spot.x, TERRAIN_Y, spot.y)
		match index % 7:
			0, 1: flowers.add(at, Vector3.ONE * (1.0 + 0.6 * Props.scatter(seed_value * 5.0)), Basis(Vector3.UP, seed_value), Props.BLOOMS[int(drift * 9.0) % Props.BLOOMS.size()])
			2: toadstools.add(at, Vector3.ONE * (0.9 + 0.9 * Props.scatter(seed_value * 2.0)), Basis(Vector3.UP, seed_value), Color("#d9573f") if index % 2 == 0 else Color("#e8c27a"))
			_: ferns.add(at, Vector3.ONE * (0.8 + 1.0 * Props.scatter(seed_value * 9.0)), Basis(Vector3.UP, seed_value))
	# Whirligig on a stake in the west bed.
	detail.box(WHIRLIGIG + Vector3(0, -0.72, -0.06), Vector3(0.05, 1.5, 0.05), Props.WOOD_DARK)
	# Hedges screen the side walls; mossy boulders sit at their ends.
	for side: float in [-1.0, 1.0]:
		for run: Vector2 in [Vector2(-10.8, -3.2), Vector2(-1.4, 4.6), Vector2(6.2, 9.0)]:
			hedge.add(Vector3(side * 14.4, TERRAIN_Y + 0.4, (run.x + run.y) * 0.5), Vector3(0.8, 0.8, run.y - run.x))
			hedge.add(Vector3(side * 14.4, TERRAIN_Y + 0.9, (run.x + run.y) * 0.5), Vector3(0.56, 0.22, run.y - run.x - 0.3))
	var boulders := kit.batch("boulders", kit.unit_boulder, surface("boulder", Color("#8f9486"), Style.ROCK, 0.7))
	for index in range(30):
		var seed_value := float(index) * 2.71
		var at := Vector3(lerpf(-30.0, 30.0, Props.scatter(seed_value)), TERRAIN_Y + 0.1, lerpf(-28.0, 30.0, Props.scatter(seed_value * 3.3)))
		if HOUSE.grow(1.2).has_point(Vector2(at.x, at.z)) or _on_path(Vector2(at.x, at.z), 1.8) or _in_parterre(Vector2(at.x, at.z)): continue
		var size := 0.5 + 0.9 * Props.scatter(seed_value * 5.0)
		boulders.add(at, Vector3(size * 1.3, size * 0.8, size), Basis(Vector3.UP, seed_value))
	for lamp in LAMPS:
		if kit.billboard("lamp", lamp, Kit.LAMP_HEIGHT) != null:
			kit.glow.box(kit.billboard_point(lamp, Kit.LAMP_HEIGHT, -0.105 * Kit.LAMP_HEIGHT, 0.2 * Kit.LAMP_HEIGHT), Vector3(0.2, 0.27, 0.06), Kit.WARM_GLOW, kit.view_basis)
	for plant_spot: Array in NEAR_PLANTS:
		kit.billboard(str(plant_spot[0]), Vector3(float(plant_spot[1]), TERRAIN_Y, float(plant_spot[2])), float(plant_spot[3]))
	# Painted fern clumps flank the door and soften the corners.
	var art := load(CANOPY_ART) as Texture2D if ResourceLoader.exists(CANOPY_ART) else null
	if art == null or art.get_width() != art.get_height() * 2:
		push_warning("Garden fern art is missing; the door is flanked by batched ferns only.")
		return
	# They stand beyond the corners so nobody inside is hidden behind them.
	_fern_clump(art, Vector3(-14.0, TERRAIN_Y, 11.7), 2.5, 0, "GardenCanopyWest")
	_fern_clump(art, Vector3(14.2, TERRAIN_Y, 11.9), 2.5, 1, "GardenCanopyEast")
	_fern_clump(art, Vector3(-15.6, TERRAIN_Y, -12.4), 2.4, 1, "GardenFernWest")
	_fern_clump(art, Vector3(15.6, TERRAIN_Y, -11.6), 2.3, 0, "GardenFernEast")
	_fern_clump(art, Vector3(-4.4, TERRAIN_Y, 17.6), 2.0, 1, "GardenFernPath")
	_fern_clump(art, Vector3(5.6, TERRAIN_Y, 19.8), 2.2, 0, "GardenFernBend")


## Painted fern clump standing on `ground`; `half` picks one of the two paintings.
func _fern_clump(art: Texture2D, ground: Vector3, height: float, half: int, label: String) -> void:
	var pixels := art.get_height()
	var tile := AtlasTexture.new()
	tile.atlas = art
	tile.region = Rect2(pixels * half, 0, pixels, pixels)
	tile.filter_clip = true
	var clump := Sprite3D.new()
	clump.name = label
	clump.texture = tile
	clump.pixel_size = height / float(pixels)
	# The painting has an empty margin below the lowest fronds.
	clump.position = ground + Vector3(0, height * 0.44, 0)
	clump.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	clump.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	clump.shaded = true
	clump.modulate = Color(0.88, 0.91, 0.84)
	clump.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	clump.alpha_scissor_threshold = 0.61
	clump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(clump)
	world._foliage_contact_transforms.append(Transform3D(Basis().scaled(Vector3(height * 0.7, 1.0, height * 0.3)), ground + Vector3(0, 0.012, 0.1)))


func _on_path(point: Vector2, margin: float) -> bool:
	for segment in range(PATH.size() - 1):
		var from := PATH[segment]
		var along := PATH[segment + 1] - from
		if point.distance_to(from + along * clampf((point - from).dot(along) / along.length_squared(), 0.0, 1.0)) < margin: return true
	return false


func _in_parterre(point: Vector2) -> bool:
	for bed in PARTERRES:
		if bed.grow(0.8).has_point(point): return true
	return false


func _build_woodland() -> void:
	for tree: Array in NEAR_TREES:
		if not world.in_dress_reach(Vector2(float(tree[1]), float(tree[2]))): continue
		kit.billboard(str(tree[0]), Vector3(float(tree[1]), TERRAIN_Y, float(tree[2])), float(tree[3]))
	# The wood beyond: a jittered grid, thinned around the clearing, the forecourt
	# and the path, so the same trees stand there on every visit.
	const SPACING := 4.3
	var clearing := HOUSE.grow_individual(6.5, 7.5, 6.5, 0.0)
	var forecourt := Rect2(-13.0, HOUSE.end.y, 26.0, 13.5)
	for row in range(26):
		for column in range(27):
			var seed_value := float(row) * 57.0 + float(column) * 13.0
			var at := Vector2(-56.0 + SPACING * (float(column) + 0.8 * Props.scatter(seed_value)), -53.0 + SPACING * (float(row) + 0.8 * Props.scatter(seed_value + 1.0)))
			if clearing.has_point(at) or forecourt.has_point(at) or _on_path(at, 3.4) or not world.dresses(at): continue
			var near_edge := clearing.grow(3.5).has_point(at) or forecourt.grow(3.0).has_point(at)
			var pick := Props.scatter(seed_value + 2.0)
			var ground := Vector3(at.x, TERRAIN_Y, at.y)
			if near_edge and pick < 0.45:
				kit.grove("shrub", ground, 1.1 + 0.5 * Props.scatter(seed_value + 3.0))
			else:
				var kind := "oak" if pick < 0.56 else ("pine" if pick < 0.93 else "ginkgo")
				kit.grove(kind, ground, 4.4 + 1.9 * Props.scatter(seed_value + 4.0))


func _build_light() -> void:
	# Sunbeams slant through the roof over the north end; dust drifts in them.
	_shafts = ShaderMaterial.new()
	_shafts.shader = Shaft
	world.material_cache["garden:shafts"] = _shafts
	world.component_motion.register_shader(_shafts)
	var beams := SurfaceTool.new()
	beams.begin(Mesh.PRIMITIVE_TRIANGLES)
	for beam: Array in [[-6.4, -8.6, 1.5], [1.2, -9.4, 1.9], [7.6, -8.2, 1.4], [-2.6, -5.4, 1.2]]:
		var foot := Vector3(float(beam[0]), 0.25, float(beam[1]))
		var source := foot + Vector3(-1.6, 5.0, -2.3)
		var half: float = beam[2] * 0.5
		var corners: Array[Vector3] = [source + Vector3(-half * 0.7, 0, 0), source + Vector3(half * 0.7, 0, 0), foot + Vector3(half, 0, 0), foot + Vector3(-half, 0, 0)]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			beams.set_uv(uvs[index])
			beams.add_vertex(corners[index])
	var shafts: MeshInstance3D = world._mesh(beams.commit(), Vector3.ZERO, _shafts)
	shafts.name = "GardenSunbeams"
	shafts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
