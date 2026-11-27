extends RefCounted
## Everything in the Yoyo Hotel that never moves on its own: the floors and the
## veranda, the back wall with its attic and clock tower, the sloped partitions
## of the cut-away rooms, the lobby desk and key wall, the folding-page walls,
## the lost-property shelves, the dream room's moon bed, the room-number
## signposts, the sheet-covered stand sites and the garden around them. Built
## once through the scenery kit; the floating and drifting things are hotel_life.

const Kit := preload("res://game/world/scenery_kit.gd")
const PAINTED := preload("res://game/world/painted_finish.gdshader")
const GRASS := preload("res://game/world/grass.gdshader")
const IslandShape := preload("res://game/world/island_shape.gd")
const WALL_Z := -13.55
const WALL_DEPTH := 0.3
const WALL_HEIGHT := 4.2
const DOOR_FROM := -10.8
const DOOR_TO := -7.2
const DOOR_HEIGHT := 2.9
## The clock tower stands over the reception, off the line from the gate to the
## door, so a visitor at the gate stays in view above the roof line.
const TOWER_FROM := -16.4
const TOWER_TO := -11.6
const TOWER_TOP := 7.4
## Partitions between rooms (and the two end walls): x, front z.
const PARTITIONS := [[-16.8, -3.0], [-5.2, -3.0], [2.0, -3.4], [9.0, -3.4], [16.8, -2.4]]
const PARTITION_BACK := 4.2
const PARTITION_FRONT := 1.3
## The two folding-page walls of the corridor: x of their centre line.
const PAGE_WALLS := [-4.45, 1.25]
const PAGE_FROM := -12.9
const PAGE_TO := -3.0
const PAGE_FOLDS := 12
const PAGE_AMPLITUDE := 0.32
## Veranda edge, west to east: the railing follows it.
const RAIL := [Vector2(-16.5, -3.0), Vector2(-16.5, 7.9), Vector2(-5.2, 7.9), Vector2(-5.2, 10.5), Vector2(2.0, 10.5), Vector2(2.0, 8.9),
	Vector2(9.0, 8.9), Vector2(9.0, 9.5), Vector2(16.5, 9.5), Vector2(16.5, -2.4)]
const LAMP_POSTS: Array[Vector2] = [Vector2(-16.0, 7.3), Vector2(1.5, 10.0), Vector2(8.5, 8.4), Vector2(16.0, 9.0)]
## Planting outside the floors: kind, x, z, height.
const PLANTS := [
	["pine", -16.3, -14.5, 5.6], ["oak", 16.4, -14.4, 5.2], ["ginkgo", 3.6, -14.6, 4.8],
	["planter", -12.6, 9.2, 1.5], ["shrub", -8.4, 9.4, 1.3], ["shrub", -15.4, 9.6, 1.2], ["planter", 4.6, 10.4, 1.5],
	["shrub", 7.8, 10.6, 1.25], ["shrub", 11.2, 11.0, 1.3], ["planter", 14.6, 11.1, 1.5], ["shrub", -1.0, 12.2, 1.2],
]
const PLUM := Color("#5b3f74")
const LILAC := Color("#b7a3df")
const ROSE := Color("#e79bb6")
const CREAM := Color("#f4ecd8")
const GOLD := Color("#d9b45c")
const WOOD := Color("#7a5638")
const DARK_WOOD := Color("#4f3826")
const TEAL := Color("#4f8f99")
const INK := Color("#6a5a8e")
const MOON := Color("#ffe6a8")
const SHEET := Color("#f3eefb")

var world: Node3D
var kit: Kit
## Large painted pieces: partitions, furniture, shelves, the page arch.
var structure := Kit.Sculpt.new()
var painted: ShaderMaterial
var pages: ShaderMaterial
var hotel_sign: Label3D
var site_tags: Array[Label3D] = []

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit

func build() -> void:
	painted = world.material_cache.get("hotel:painted")
	if painted == null:
		painted = ShaderMaterial.new()
		painted.shader = PAINTED
		painted.set_shader_parameter("vertex_tint", true)
		world.material_cache["hotel:painted"] = painted
	pages = kit.cloth_material("hotel-pages", 0.03)
	_build_ground()
	await world.build_pause()
	_build_facade()
	await world.build_pause()
	_build_partitions()
	_build_lobby()
	await world.build_pause()
	_build_corridor()
	await world.build_pause()
	_build_lost_room()
	_build_dream_room()
	await world.build_pause()
	_build_veranda()
	_build_sites()
	_build_garden()
	await world.build_pause()
	_commit()

## Lanterns, dormer windows and the dream room's stars light up with the lamps.
func apply_time_of_day(lamp_level: float) -> void:
	kit.set_glow(0.1 + lamp_level * 2.6)

# --- Ground ------------------------------------------------------------------

func _build_ground() -> void:
	if world.embedded_in == null:
		# Standing alone the hotel brings its own lawn past anything the camera shows.
		var lawn := ShaderMaterial.new()
		lawn.shader = GRASS
		world.material_cache["hotel:lawn"] = lawn
		var plane := PlaneMesh.new()
		plane.size = Vector2(240, 240)
		var ground: MeshInstance3D = world._mesh(plane, Vector3(0, world.LAWN_Y, 0), lawn)
		ground.name = "HotelLawn"
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for area: Dictionary in world.AREAS:
		var room: Rect2 = area.room
		var floor_mesh := _slab(room, world.GROUND_Y, 0.3, int(area.tile), 2.4, area.tint)
		floor_mesh.name = "HotelFloor_" + String(area.id)
		var deck := _slab(area.terrace, world.GROUND_Y, 0.3, 1, 1.8, Color("#eadfce"))
		deck.name = "HotelVeranda_" + String(area.id)
	# A stone path from the gate to the front door.
	var path_rect: Rect2 = Rect2(-11.2, -25.0, 4.4, 11.8) if world.embedded_in == null else world._site.approach
	var stone: Material = world._coastal_surface(4, 1.4, Color("#ddd2ea"))
	kit.mound(path_rect, 0.18, 0.06, 0.7, stone, 1.3).name = "HotelFrontPath"
	# A plum runner with gold diamonds leads from the door along the whole veranda.
	_runner(Vector2(-9.0, -13.3), Vector2(-9.0, 1.1), 1.4)
	_runner(Vector2(-16.2, 1.1), Vector2(16.2, 1.1), 1.5)
	# A low plum skirting hides the slab edge where the veranda meets the lawn.
	for index in RAIL.size() - 1:
		var from: Vector2 = RAIL[index]
		var to: Vector2 = RAIL[index + 1]
		var middle := (from + to) * 0.5
		var along_x := absf(to.x - from.x) > absf(to.y - from.y)
		var length := from.distance_to(to) + 0.2
		structure.box(Vector3(middle.x, 0.07, middle.y), Vector3(length, 0.26, 0.24) if along_x else Vector3(0.24, 0.26, length), PLUM.lightened(0.1))

func _slab(rect: Rect2, top: float, thickness: float, tile: int, tile_size: float, tint: Color) -> MeshInstance3D:
	var center := rect.get_center()
	var slab: MeshInstance3D = world._box(Vector3(center.x, top - thickness * 0.5, center.y), Vector3(rect.size.x, thickness, rect.size.y), tint, true)
	world._set_registered_surface(slab, world._coastal_surface(tile, tile_size, tint))
	return slab

func _runner(from: Vector2, to: Vector2, width: float) -> void:
	var along := (to - from).normalized()
	var across := Vector2(-along.y, along.x)
	var length := from.distance_to(to)
	var y: float = world.GROUND_Y + 0.006
	var corner := func(at: Vector2, side: float, height: float) -> Vector3:
		var spot := at + across * side
		return Vector3(spot.x, height, spot.y)
	var edge := width * 0.5
	_flat_quad(corner.call(from, -edge, y), corner.call(to, -edge, y), corner.call(to, edge, y), corner.call(from, edge, y), PLUM)
	y += 0.006
	for side: float in [-1.0, 1.0]:
		_flat_quad(corner.call(from, side * (edge - 0.1), y), corner.call(to, side * (edge - 0.1), y), corner.call(to, side * (edge - 0.2), y), corner.call(from, side * (edge - 0.2), y), GOLD)
	var count := int(length / 1.1)
	for index in count:
		var at := from + along * ((float(index) + 0.5) * length / float(count))
		var tip := 0.32
		var a := at + along * tip
		var b := at + across * tip * 0.7
		var c := at - along * tip
		var d := at - across * tip * 0.7
		_flat_quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), ROSE if index % 2 == 0 else GOLD.lightened(0.15))

## A flat quad facing up, whatever order its corners come in.
func _flat_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri_out(structure, a, b, c, Vector3.UP, color)
	_tri_out(structure, a, c, d, Vector3.UP, color)

static func _tri_out(s: Kit.Sculpt, a: Vector3, b: Vector3, c: Vector3, toward: Vector3, color: Color) -> void:
	if (c - a).cross(b - a).dot(toward) > 0.0: s.tri(a, b, c, color)
	else: s.tri(a, c, b, color)

## A convex block from four floor corners and the four corners above them.
static func _prism(s: Kit.Sculpt, low: Array[Vector3], high: Array[Vector3], color: Color) -> void:
	var centre := Vector3.ZERO
	for corner: Vector3 in low + high: centre += corner / 8.0
	var faces: Array = [[low[0], low[1], low[2], low[3]], [high[0], high[1], high[2], high[3]]]
	for index in 4:
		var next := (index + 1) % 4
		faces.append([low[index], low[next], high[next], high[index]])
	for face: Array in faces:
		var middle: Vector3 = (face[0] + face[1] + face[2] + face[3]) / 4.0
		var out := middle - centre
		_tri_out(s, face[0], face[1], face[2], out, color)
		_tri_out(s, face[0], face[2], face[3], out, color)

# --- Back wall, attic and tower ---------------------------------------------

func _build_facade() -> void:
	# The whole back wall, attic and tower open together when the walker is behind them.
	world.occlusion_controller.begin_building()
	var top: float = world.GROUND_Y + WALL_HEIGHT
	var pieces: Array = []
	for area: Dictionary in world.AREAS:
		var room: Rect2 = area.room
		var from := room.position.x - (0.2 if area.id == "lobby" else 0.0)
		var to := room.end.x + (0.2 if area.id == "dream" else 0.0)
		var spans: Array[Vector2] = [Vector2(from, to)]
		if area.id == "lobby": spans = [Vector2(from, DOOR_FROM), Vector2(DOOR_TO, to)]
		for span: Vector2 in spans:
			var wall: MeshInstance3D = world._box(Vector3((span.x + span.y) * 0.5, world.GROUND_Y + WALL_HEIGHT * 0.5, WALL_Z), Vector3(span.y - span.x, WALL_HEIGHT, WALL_DEPTH), area.paper[1], true)
			world._set_registered_surface(wall, world._coastal_surface(int(area.paper[0]), 1.8, area.paper[1]))
			wall.name = "HotelWall_" + String(area.id)
			pieces.append(wall)
		# Wainscot and a picture rail in the room's own darker tone.
		var tone: Color = (area.paper[1] as Color).darkened(0.35)
		structure.box(Vector3((from + to) * 0.5, world.GROUND_Y + 0.5, WALL_Z + 0.19), Vector3(to - from, 1.0, 0.08), tone)
		kit.detail.box(Vector3((from + to) * 0.5, world.GROUND_Y + 1.02, WALL_Z + 0.24), Vector3(to - from, 0.07, 0.1), GOLD.darkened(0.2))
		kit.detail.box(Vector3((from + to) * 0.5, world.GROUND_Y + 3.55, WALL_Z + 0.2), Vector3(to - from, 0.06, 0.06), tone.lightened(0.2))
	var lintel: MeshInstance3D = world._box(Vector3((DOOR_FROM + DOOR_TO) * 0.5, (world.GROUND_Y + DOOR_HEIGHT + top) * 0.5, WALL_Z), Vector3(DOOR_TO - DOOR_FROM, top - world.GROUND_Y - DOOR_HEIGHT, WALL_DEPTH), Color("#f6cfb4"), true)
	world._set_registered_surface(lintel, world._coastal_surface(6, 1.8, Color("#f6cfb4")))
	# Attic: a shingled mansard band with dormers along the whole roof line.
	var attic: MeshInstance3D = world._box(Vector3(0, top + 0.6, WALL_Z - 0.12), Vector3(33.8, 1.2, 0.5), LILAC)
	world._set_registered_surface(attic, world._coastal_surface(2, 1.2, Color("#a58fd6")))
	attic.name = "HotelAttic"
	var tower: MeshInstance3D = world._box(Vector3((TOWER_FROM + TOWER_TO) * 0.5, (top + TOWER_TOP) * 0.5, WALL_Z - 0.1), Vector3(TOWER_TO - TOWER_FROM, TOWER_TOP - top, 0.7), Color("#ead9f2"))
	world._set_registered_surface(tower, world._coastal_surface(4, 1.4, Color("#ecdff4")))
	tower.name = "HotelTower"
	world.occlusion_controller.finish_building((pieces[0] as MeshInstance3D).get_child(0))
	var detail := kit.detail
	detail.box(Vector3(0, top + 0.04, WALL_Z + 0.12), Vector3(33.9, 0.14, 0.62), CREAM)
	detail.box(Vector3(0, top + 1.24, WALL_Z - 0.1), Vector3(33.9, 0.12, 0.6), PLUM)
	for x: float in [-14.4, -2.2, 0.8, 5.5, 12.8]:
		_dormer(Vector3(x, top + 0.55, WALL_Z + 0.16))
	# The tower: a sign board, a moon clock and a peaked roof with a ghost weathervane.
	var face := WALL_Z + 0.27
	var mid := (TOWER_FROM + TOWER_TO) * 0.5
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(mid + side * 2.33, (top + TOWER_TOP) * 0.5, face - 0.02), Vector3(0.18, TOWER_TOP - top, 0.14), CREAM)
	structure.box(Vector3(mid, top + 1.0, face), Vector3(4.1, 0.92, 0.12), PLUM)
	detail.box(Vector3(mid, top + 1.49, face + 0.04), Vector3(4.2, 0.07, 0.1), GOLD)
	detail.box(Vector3(mid, top + 0.51, face + 0.04), Vector3(4.2, 0.07, 0.1), GOLD)
	hotel_sign = world._label("幽幽旅館", Vector3(mid, top + 1.0, face + 0.36), 44, CREAM)
	hotel_sign.outline_modulate = Color("#2c2548")
	hotel_sign.visibility_range_end = 0.0
	hotel_sign.name = "HotelSign"
	var clock := Vector3(mid, top + 2.32, face)
	var dial := Basis(Vector3.RIGHT, PI * 0.5)
	structure.tube(clock, 0.68, 0.68, 0.12, GOLD.darkened(0.1), 16, dial)
	kit.glow.tube(clock + Vector3(0, 0, 0.07), 0.56, 0.56, 0.03, MOON, 16, dial)
	detail.box(clock + Vector3(0, 0.17, 0.1), Vector3(0.05, 0.36, 0.03), INK)
	detail.box(clock + Vector3(0.13, 0.02, 0.1), Vector3(0.28, 0.05, 0.03), INK, Basis(Vector3.BACK, 0.4))
	for hour in 12:
		var angle := TAU * float(hour) / 12.0
		detail.box(clock + Vector3(sin(angle) * 0.46, cos(angle) * 0.46, 0.1), Vector3(0.05, 0.05, 0.02), INK)
	var roof_base: float = TOWER_TOP
	structure.tube(Vector3(mid, roof_base + 0.08, WALL_Z - 0.1), 3.7, 3.7, 0.16, CREAM, 4, Basis.from_scale(Vector3(1.0, 1.0, 0.28)) * Basis(Vector3.UP, PI * 0.25))
	structure.tube(Vector3(mid, roof_base + 1.15, WALL_Z - 0.1), 3.5, 0.05, 2.0, Color("#7d64ad"), 4, Basis.from_scale(Vector3(1.0, 1.0, 0.3)) * Basis(Vector3.UP, PI * 0.25))
	detail.tube(Vector3(mid, roof_base + 2.4, WALL_Z - 0.1), 0.03, 0.03, 0.6, DARK_WOOD, 5)
	_tiny_ghost(detail, Vector3(mid, roof_base + 2.85, WALL_Z - 0.1), 0.26)
	# The front door: a cream arch with a glowing fanlight.
	var arch_mid := (DOOR_FROM + DOOR_TO) * 0.5
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(arch_mid + side * 1.92, world.GROUND_Y + DOOR_HEIGHT * 0.5, WALL_Z + 0.2), Vector3(0.22, DOOR_HEIGHT, 0.16), CREAM)
	detail.box(Vector3(arch_mid, world.GROUND_Y + DOOR_HEIGHT + 0.08, WALL_Z + 0.2), Vector3(4.1, 0.18, 0.18), CREAM)
	for ray in 7:
		var angle := PI * float(ray + 1) / 8.0
		kit.glow.box(Vector3(arch_mid + cos(angle) * 0.9, world.GROUND_Y + DOOR_HEIGHT + 0.2 + sin(angle) * 0.42, WALL_Z + 0.18), Vector3(0.32, 0.07, 0.05), MOON, Basis(Vector3.BACK, angle))
	# Both door leaves stand open against the lobby, welcoming whoever comes in.
	for side: float in [-1.0, 1.0]:
		var hinge := Vector3(arch_mid + side * 1.72, world.GROUND_Y, WALL_Z + 0.2)
		var swing := Basis(Vector3.UP, side * 1.25)
		var centre := hinge + swing * Vector3(-side * 0.8, DOOR_HEIGHT * 0.47, 0)
		structure.box(centre, Vector3(1.6, DOOR_HEIGHT * 0.94, 0.08), PLUM, swing)
		for pane in 2:
			kit.detail.box(centre + swing * Vector3(0, 0.55 - float(pane) * 1.0, 0.05), Vector3(1.1, 0.7, 0.02), GOLD.darkened(0.25), swing)
		kit.detail.box(centre + swing * Vector3(side * 0.6, -0.15, 0.08), Vector3(0.06, 0.18, 0.06), GOLD, swing)

func _dormer(at: Vector3) -> void:
	structure.box(at, Vector3(1.1, 0.9, 0.4), CREAM.darkened(0.05))
	for side: float in [-1.0, 1.0]:
		structure.box(at + Vector3(side * 0.3, 0.64, 0.02), Vector3(0.8, 0.09, 0.5), Color("#7d64ad"), Basis(Vector3.BACK, -side * 0.62))
	kit.glow.box(at + Vector3(0, -0.05, 0.21), Vector3(0.6, 0.55, 0.03), Color("#ffd98f"))
	kit.detail.box(at + Vector3(0, -0.05, 0.24), Vector3(0.05, 0.55, 0.03), PLUM)
	kit.detail.box(at + Vector3(0, -0.05, 0.24), Vector3(0.6, 0.05, 0.03), PLUM)

## A tiny sheet ghost for signs and the weathervane.
static func _tiny_ghost(s: Kit.Sculpt, at: Vector3, size: float) -> void:
	s.ball(at + Vector3(0, size * 0.35, 0), size * 0.6, SHEET, Color.TRANSPARENT, 8, 4)
	s.tube(at - Vector3(0, size * 0.1, 0), size * 0.62, size * 0.6, size * 0.9, SHEET, 8)
	for eye: float in [-1.0, 1.0]:
		s.box(at + Vector3(eye * size * 0.2, size * 0.42, size * 0.55), Vector3(size * 0.12, size * 0.18, 0.02), INK)

# --- Partitions ----------------------------------------------------------------

## Cut-away side walls: full height at the back, sloping down toward the veranda.
func _build_partitions() -> void:
	var back := WALL_Z + WALL_DEPTH * 0.5
	for spec: Array in PARTITIONS:
		var x := float(spec[0])
		var front := float(spec[1])
		var half := 0.13
		var low: Array[Vector3] = [Vector3(x - half, 0.2, back), Vector3(x + half, 0.2, back), Vector3(x + half, 0.2, front), Vector3(x - half, 0.2, front)]
		var high: Array[Vector3] = [Vector3(x - half, 0.2 + PARTITION_BACK, back), Vector3(x + half, 0.2 + PARTITION_BACK, back),
			Vector3(x + half, 0.2 + PARTITION_FRONT, front), Vector3(x - half, 0.2 + PARTITION_FRONT, front)]
		_prism(structure, low, high, Color("#e9dcc8"))
		# A plum cap rail along the slope and a turned post at the front.
		var rise := PARTITION_BACK - PARTITION_FRONT
		var run := front - back
		var slope := Basis(Vector3.RIGHT, atan2(rise, run))
		kit.detail.box(Vector3(x, 0.2 + (PARTITION_BACK + PARTITION_FRONT) * 0.5 + 0.04, (back + front) * 0.5), Vector3(0.34, 0.08, sqrt(rise * rise + run * run)), PLUM, slope)
		kit.detail.box(Vector3(x, 0.2 + 0.45, (back + front) * 0.5), Vector3(0.3, 0.9, run), PLUM.lightened(0.25))
		structure.tube(Vector3(x, 0.2 + PARTITION_FRONT * 0.5 + 0.1, front), 0.17, 0.15, PARTITION_FRONT + 0.2, GOLD.darkened(0.15), 8)
		structure.ball(Vector3(x, 0.2 + PARTITION_FRONT + 0.28, front), 0.17, GOLD, Color.TRANSPARENT, 8, 4)
		kit.blocker(Vector3(x, 1.2, (back + front) * 0.5), Vector3(0.3, 2.4, run + 0.1))

# --- Lobby ---------------------------------------------------------------------

func _build_lobby() -> void:
	var desk: Vector3 = world.DESK
	# The counter: a plinth, a panelled front, a brass-edged top and a raised back shelf.
	structure.box(desk + Vector3(0, 0.08, 0), Vector3(3.8, 0.16, 1.0), DARK_WOOD)
	structure.box(desk + Vector3(0, 0.6, 0), Vector3(3.6, 0.9, 0.86), Color("#9b5a4c"))
	for panel in 3:
		structure.box(desk + Vector3(-1.15 + float(panel) * 1.15, 0.6, 0.44), Vector3(0.92, 0.62, 0.03), Color("#b9705e"))
		kit.detail.box(desk + Vector3(-1.15 + float(panel) * 1.15, 0.6, 0.465), Vector3(0.5, 0.06, 0.02), GOLD)
	structure.box(desk + Vector3(0, 1.1, 0), Vector3(3.9, 0.1, 1.04), WOOD)
	kit.detail.box(desk + Vector3(0, 1.1, 0.53), Vector3(3.92, 0.05, 0.03), GOLD)
	structure.box(desk + Vector3(0, 1.3, -0.4), Vector3(3.6, 0.3, 0.24), DARK_WOOD)
	# Guest book, a desk lamp with a green shade and the "櫃檯" plate.
	structure.box(desk + Vector3(-0.9, 1.19, 0.12), Vector3(0.5, 0.06, 0.36), CREAM)
	kit.detail.box(desk + Vector3(-0.9, 1.225, 0.12), Vector3(0.02, 0.02, 0.36), INK)
	kit.detail.tube(desk + Vector3(-1.55, 1.45, -0.05), 0.03, 0.03, 0.6, GOLD, 5)
	kit.glow.tube(desk + Vector3(-1.55, 1.8, 0.0), 0.08, 0.22, 0.18, Color("#7fd0a8"), 8)
	kit.lamp_light(desk + Vector3(-1.5, 1.75, 0.3), 6.0)
	var plate: Label3D = world._local_label("櫃檯", desk + Vector3(0.9, 0.62, 0.52), 22, MOON)
	plate.pixel_size = 0.012
	# Key wall: a board of numbered keys and a moon clock above it.
	var board := Vector3(desk.x, 2.4, WALL_Z + 0.2)
	structure.box(board, Vector3(2.9, 1.5, 0.08), DARK_WOOD)
	for row in 3:
		for column in 4:
			var hook := board + Vector3(-1.05 + float(column) * 0.7, 0.42 - float(row) * 0.45, 0.06)
			kit.detail.box(hook, Vector3(0.05, 0.05, 0.06), GOLD)
			kit.detail.box(hook + Vector3(0, -0.12, 0.02), Vector3(0.05, 0.16, 0.02), GOLD.lightened(0.1))
			kit.detail.box(hook + Vector3(0, -0.26, 0.02), Vector3(0.12, 0.1, 0.02), [ROSE, TEAL, LILAC, MOON][(row + column) % 4])
	var clock := Vector3(desk.x, 3.62, WALL_Z + 0.22)
	structure.tube(clock, 0.5, 0.5, 0.08, GOLD, 14, Basis(Vector3.RIGHT, PI * 0.5))
	kit.glow.tube(clock + Vector3(0, 0, 0.05), 0.4, 0.4, 0.02, MOON, 14, Basis(Vector3.RIGHT, PI * 0.5))
	kit.detail.box(clock + Vector3(-0.08, 0.1, 0.08), Vector3(0.22, 0.22, 0.02), Color("#2c2548"), Basis(Vector3.BACK, 0.4))
	# The lounge: a round rug, two velvet armchairs, a tea table and a gramophone.
	var lounge := Vector3(-14.4, world.GROUND_Y, -5.6)
	structure.tube(lounge + Vector3(0, 0.012, 0), 1.9, 1.9, 0.024, Color("#c4706a"), 18, Basis.from_scale(Vector3(1.0, 1.0, 0.7)))
	structure.tube(lounge + Vector3(0, 0.02, 0), 1.5, 1.5, 0.024, Color("#e2b48a"), 18, Basis.from_scale(Vector3(1.0, 1.0, 0.7)))
	for side: float in [-1.0, 1.0]:
		_armchair(lounge + Vector3(side * 1.25, 0, -0.2), side)
	structure.tube(lounge + Vector3(0, 0.3, -0.1), 0.08, 0.1, 0.6, DARK_WOOD, 6)
	structure.tube(lounge + Vector3(0, 0.62, -0.1), 0.42, 0.42, 0.06, WOOD, 12)
	kit.detail.tube(lounge + Vector3(0.08, 0.7, -0.1), 0.07, 0.06, 0.1, CREAM, 8)
	_gramophone(Vector3(-15.7, world.GROUND_Y, -11.9))
	# A brass luggage cart by the door, still loaded.
	var cart := Vector3(-6.4, world.GROUND_Y, -7.6)
	structure.box(cart + Vector3(0, 0.3, 0), Vector3(1.3, 0.08, 0.8), GOLD.darkened(0.2))
	for side: float in [-1.0, 1.0]:
		kit.detail.tube(cart + Vector3(side * 0.6, 0.95, -0.3), 0.03, 0.03, 1.3, GOLD, 5)
		kit.detail.tube(cart + Vector3(side * 0.55, 0.12, 0.3), 0.1, 0.1, 0.06, DARK_WOOD, 8, Basis(Vector3.BACK, PI * 0.5))
	kit.detail.box(cart + Vector3(0, 1.6, -0.3), Vector3(1.26, 0.05, 0.05), GOLD)
	structure.box(cart + Vector3(-0.15, 0.55, 0.0), Vector3(0.9, 0.42, 0.55), TEAL)
	structure.box(cart + Vector3(0.1, 0.9, 0.0), Vector3(0.7, 0.3, 0.45), ROSE)
	structure.box(cart + Vector3(0.0, 1.13, 0.05), Vector3(0.5, 0.18, 0.35), LILAC)
	kit.blocker(cart + Vector3(0, 1.0, 0), Vector3(1.3, 2.0, 0.9))
	kit.blocker(desk + Vector3(0, 1.0, 0), Vector3(3.8, 2.0, 1.0))
	kit.blocker(lounge + Vector3(0, 1.0, -0.2), Vector3(3.6, 2.0, 1.1))
	kit.billboard("planter", Vector3(-16.0, world.GROUND_Y, -3.6), 1.6)
	kit.billboard("planter", Vector3(-10.9, world.GROUND_Y, -12.8), 1.5)

func _armchair(at: Vector3, side: float) -> void:
	var velvet := Color("#6f4a8e")
	var turn := Basis(Vector3.UP, side * 0.5)
	structure.box(at + Vector3(0, 0.25, 0), Vector3(0.9, 0.3, 0.8), velvet, turn)
	structure.box(at + turn * Vector3(0, 0.7, -0.33), Vector3(0.9, 0.75, 0.18), velvet.darkened(0.1), turn)
	for arm: float in [-1.0, 1.0]:
		structure.box(at + turn * Vector3(arm * 0.42, 0.5, 0), Vector3(0.14, 0.32, 0.8), velvet.lightened(0.1), turn)
	structure.box(at + Vector3(0, 0.44, 0.04), Vector3(0.7, 0.1, 0.62), ROSE.darkened(0.1), turn)

## A gramophone with its big horn: the hotel listens to everything.
func _gramophone(at: Vector3) -> void:
	structure.box(at + Vector3(0, 0.42, 0), Vector3(0.7, 0.84, 0.6), DARK_WOOD)
	structure.box(at + Vector3(0, 0.95, 0), Vector3(0.62, 0.22, 0.54), WOOD)
	kit.detail.tube(at + Vector3(0, 1.07, 0), 0.24, 0.24, 0.02, Color("#2c2548"), 12)
	var lean := Basis(Vector3.BACK, -0.6) * Basis(Vector3.RIGHT, 0.3)
	kit.detail.tube(at + Vector3(0.1, 1.3, 0.0), 0.04, 0.05, 0.5, GOLD.darkened(0.1), 6, lean)
	structure.tube(at + Vector3(0.45, 1.75, 0.15), 0.06, 0.55, 0.7, GOLD, 12, lean)
	structure.tube(at + Vector3(0.58, 1.95, 0.2), 0.52, 0.56, 0.04, MOON, 12, lean)
	kit.blocker(at + Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.7))

# --- Folding-page corridor ---------------------------------------------------

func _build_corridor() -> void:
	# Two zig-zag paper walls folded like the pages of a book; the cloth shader lets
	# their top edges ripple, and hotel_life rustles them as the walker passes.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for wall in PAGE_WALLS.size():
		var x := float(PAGE_WALLS[wall])
		var corners: Array[Vector3] = []
		for fold in PAGE_FOLDS + 1:
			var t := float(fold) / float(PAGE_FOLDS)
			var z := lerpf(PAGE_FROM, PAGE_TO, t)
			var offset := PAGE_AMPLITUDE * (1.0 if fold % 2 == 0 else -1.0)
			corners.append(Vector3(x + offset, lerpf(3.2, 2.2, t), z))
		for fold in PAGE_FOLDS:
			_page(tool, corners[fold], corners[fold + 1], fold + wall)
		kit.blocker(Vector3(x, 1.2, (PAGE_FROM + PAGE_TO) * 0.5), Vector3(PAGE_AMPLITUDE * 2.0 + 0.2, 2.4, PAGE_TO - PAGE_FROM))
		# Brass feet under every fold.
		for corner: Vector3 in corners:
			kit.detail.tube(Vector3(corner.x, 0.24, corner.z), 0.06, 0.08, 0.08, GOLD.darkened(0.2), 6)
	tool.generate_normals()
	var walls: MeshInstance3D = world._mesh(tool.commit(), Vector3.ZERO, pages)
	walls.name = "HotelPageWalls"
	# The giant open book at the end of the corridor, its spine upright.
	var spine := Vector3(-1.6, 0.2, -13.0)
	for side: float in [-1.0, 1.0]:
		var feet: Array[Vector3] = []
		var tops: Array[Vector3] = []
		for step in 9:
			var t := float(step) / 8.0
			var foot := spine + Vector3(side * t * 2.4, 0, sin(t * PI) * 0.7)
			feet.append(foot)
			tops.append(foot + Vector3(0, lerpf(3.9, 3.0, t) + sin(t * PI) * 0.25, 0))
		for step in 8:
			var colour := CREAM.darkened(0.04 * float(step % 2))
			structure.sheet(feet[step], feet[step + 1], tops[step + 1], colour)
			structure.sheet(feet[step], tops[step + 1], tops[step], colour)
			# Ink lines across each page.
			var span := feet[step + 1] - feet[step]
			for line in 6:
				var y := 0.6 + float(line) * 0.42
				kit.detail.box((feet[step] + feet[step + 1]) * 0.5 + Vector3(0, y, 0.03), Vector3(span.length() * 0.8, 0.04, 0.01), INK.lightened(0.25), Basis(Vector3.UP, -atan2(span.z, span.x)))
	structure.tube(spine + Vector3(0, 2.0, 0.05), 0.12, 0.12, 4.0, PLUM, 6)
	# A paper moon lantern above the book lights the corridor at night.
	# It hangs from an iron bracket on the back wall, in front of the book's spine.
	kit.detail.box(Vector3(spine.x, 4.42, -12.75), Vector3(0.06, 0.06, 1.3), Color("#3d3348"))
	kit.detail.box(Vector3(spine.x, 4.18, -13.32), Vector3(0.06, 0.5, 0.06), Color("#3d3348"))
	kit.detail.box(Vector3(spine.x, 4.2, -12.1), Vector3(0.02, 0.44, 0.02), DARK_WOOD)
	kit.glow.ball(Vector3(spine.x, 3.62, -12.1), 0.5, MOON, MOON.lightened(0.1), 10, 5)
	kit.lamp_light(spine + Vector3(0, 3.0, 2.4), 7.5, Color("#ffe2b0"))
	# Paper cranes on threads across the corridor.
	for row: float in [-10.2, -7.0, -4.6]:
		var top := 0.2 + lerpf(3.2, 2.2, inverse_lerp(PAGE_FROM, PAGE_TO, row)) - 0.15
		var from := Vector3(PAGE_WALLS[0] + 0.1, top, row)
		var to := Vector3(PAGE_WALLS[1] - 0.1, top - 0.1, row)
		kit.detail.box((from + to) * 0.5, Vector3(from.distance_to(to), 0.015, 0.015), DARK_WOOD)
		for index in 3:
			var hang := from.lerp(to, (float(index) + 1.0) / 4.0) - Vector3(0, 0.3 + 0.12 * float(index % 2), 0)
			kit.detail.box(hang + Vector3(0, 0.15, 0), Vector3(0.01, 0.3, 0.01), DARK_WOOD)
			_crane(kit.detail, hang, [ROSE, MOON, TEAL.lightened(0.3)][index])
	kit.billboard("planter", Vector3(-4.6, world.GROUND_Y, -2.4), 1.4)

## One folded page between two fold corners, in four rows so its top can ripple.
func _page(tool: SurfaceTool, a: Vector3, b: Vector3, salt: int) -> void:
	const ROWS := 4
	var paper := CREAM if salt % 2 == 0 else Color("#efe3f6")
	for row in ROWS:
		var low := float(row) / float(ROWS)
		var high := float(row + 1) / float(ROWS)
		var colour := paper.darkened(0.07) if row % 2 == 1 else paper
		var corners := [[a, low], [b, low], [b, high], [a, low], [b, high], [a, high]]
		for corner: Array in corners:
			var top: Vector3 = corner[0]
			var h := float(corner[1])
			tool.set_color(colour.srgb_to_linear())
			tool.set_uv(Vector2(h, 0.0))
			tool.set_uv2(Vector2(h * h, 0.0))
			tool.add_vertex(Vector3(top.x, 0.2 + (top.y) * h, top.z))

static func _crane(s: Kit.Sculpt, at: Vector3, paper: Color) -> void:
	var fold := paper.darkened(0.18)
	s.sheet(at + Vector3(-0.12, 0, 0), at + Vector3(0.12, 0, 0), at + Vector3(0, 0.08, 0.04), paper)
	s.sheet(at + Vector3(-0.04, 0.05, 0), at + Vector3(0.05, 0.05, 0), at + Vector3(-0.1, 0.24, -0.12), paper)
	s.sheet(at + Vector3(-0.04, 0.05, 0), at + Vector3(0.05, 0.05, 0), at + Vector3(0.09, 0.22, 0.12), fold)
	s.sheet(at + Vector3(0.09, 0, 0), at + Vector3(0.12, 0.02, 0), at + Vector3(0.22, 0.2, 0.01), paper)
	s.sheet(at + Vector3(-0.09, 0, 0), at + Vector3(-0.12, 0.02, 0), at + Vector3(-0.22, 0.18, 0.0), fold)

# --- Lost-property room ------------------------------------------------------

func _build_lost_room() -> void:
	# Shelving across the back wall, crammed with what guests left behind.
	var shelf_z := WALL_Z + 0.5
	for x: float in [2.5, 5.5, 8.5]:
		structure.box(Vector3(x, 0.2 + 1.8, shelf_z), Vector3(0.12, 3.6, 0.7), DARK_WOOD)
	for level in 4:
		var y := 0.2 + 0.08 + float(level) * 1.12
		structure.box(Vector3(5.5, y, shelf_z), Vector3(6.2, 0.08, 0.72), WOOD)
		if level == 3: continue
		var x := 2.75
		var item := level * 5
		while x < 8.2:
			var width := 0.42 + fposmod(float(item) * 0.37, 1.0) * 0.5
			var height := 0.3 + fposmod(float(item) * 0.53, 1.0) * 0.55
			var tone: Color = [ROSE, TEAL, LILAC, Color("#c98d5a"), MOON, Color("#8fb0d8")][item % 6]
			if absf(x + width * 0.5 - 5.5) > 0.2:
				match item % 3:
					0:
						structure.box(Vector3(x + width * 0.5, y + 0.04 + height * 0.5, shelf_z), Vector3(width, height, 0.5), tone)
						kit.detail.box(Vector3(x + width * 0.5, y + 0.04 + height + 0.04, shelf_z), Vector3(0.16, 0.05, 0.05), GOLD)
					1:
						structure.tube(Vector3(x + width * 0.5, y + 0.04 + height * 0.4, shelf_z), width * 0.48, width * 0.48, height * 0.8, tone, 10)
						kit.detail.tube(Vector3(x + width * 0.5, y + 0.06 + height * 0.8, shelf_z), width * 0.5, width * 0.5, 0.05, tone.darkened(0.25), 10)
					_:
						structure.ball(Vector3(x + width * 0.5, y + 0.04 + 0.22, shelf_z), 0.22, tone, tone.lightened(0.15), 8, 4)
						structure.ball(Vector3(x + width * 0.5, y + 0.04 + 0.5, shelf_z), 0.15, tone, Color.TRANSPARENT, 8, 4)
			x += width + 0.12
			item += 1
	kit.blocker(Vector3(5.5, 1.2, shelf_z), Vector3(6.4, 2.4, 0.8))
	# "失物招領" on a hanging board, and a coat stand with forgotten hats.
	var board := Vector3(5.5, 4.1, WALL_Z + 0.24)
	structure.box(board, Vector3(2.6, 0.56, 0.08), TEAL.darkened(0.2))
	kit.detail.box(board + Vector3(0, 0.3, 0.02), Vector3(2.7, 0.05, 0.06), GOLD)
	var lost_sign: Label3D = world._local_label("失物招領", board + Vector3(0, 0, 0.18), 28, CREAM)
	lost_sign.pixel_size = 0.0125
	var stand := Vector3(8.3, world.GROUND_Y, -7.0)
	structure.tube(stand + Vector3(0, 0.05, 0), 0.32, 0.36, 0.1, DARK_WOOD, 8)
	structure.tube(stand + Vector3(0, 1.0, 0), 0.05, 0.05, 1.9, WOOD, 6)
	for hook in 3:
		var turn := Basis(Vector3.UP, TAU * float(hook) / 3.0)
		structure.tube(stand + Vector3(0, 1.7 + float(hook) * 0.08, 0) + turn * Vector3(0.18, 0, 0), 0.2, 0.13, 0.22, [ROSE, TEAL, LILAC][hook], 10)
	kit.blocker(stand + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.7))
	# The heap the floating tower rises from.
	var heap: Vector3 = world.LOST_TOWER
	for index in 6:
		var turn := Basis(Vector3.UP, float(index) * 1.3)
		var spot := heap + turn * Vector3(0.55 + 0.1 * float(index % 2), 0, 0)
		structure.box(spot + Vector3(0, 0.18 + 0.05 * float(index % 3), 0), Vector3(0.7, 0.34, 0.46), [TEAL, ROSE, Color("#c98d5a"), LILAC][index % 4], turn)
	structure.box(heap + Vector3(0, 0.55, 0), Vector3(0.9, 0.5, 0.56), DARK_WOOD.lightened(0.15))
	kit.detail.box(heap + Vector3(0, 0.82, 0), Vector3(0.94, 0.05, 0.6), GOLD)
	kit.blocker(heap + Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 1.8))
	kit.lamp_light(Vector3(5.5, 3.6, -7.6), 6.5)
	kit.detail.box(Vector3(5.5, 4.05, -7.6), Vector3(0.02, 0.5, 0.02), DARK_WOOD)
	kit.glow.ball(Vector3(5.5, 3.72, -7.6), 0.2, Color("#ffd98f"), Color.TRANSPARENT, 8, 4)
	kit.detail.tube(Vector3(5.5, 3.9, -7.6), 0.05, 0.28, 0.16, TEAL, 10)

# --- Dream guest room ----------------------------------------------------------

func _build_dream_room() -> void:
	var bed: Vector3 = world.BED
	# The moon bed: a crescent headboard, a quilted mattress, two nightstands.
	_crescent(Vector3(bed.x - 0.3, 2.1, WALL_Z + 0.26), 1.55, Color("#f1d48a"))
	structure.box(bed + Vector3(0, 0.25, 0), Vector3(2.4, 0.3, 3.0), Color("#7d64ad"))
	structure.box(bed + Vector3(0, 0.52, 0.05), Vector3(2.3, 0.24, 2.9), CREAM)
	structure.box(bed + Vector3(0, 0.67, 0.45), Vector3(2.36, 0.08, 2.1), Color("#9d86d6"))
	for row in 3:
		kit.detail.box(bed + Vector3(0, 0.715, -0.3 + float(row) * 0.7), Vector3(2.36, 0.02, 0.04), Color("#c8b8f0"))
	structure.box(bed + Vector3(0, 0.2 + 0.32, 1.52), Vector3(2.4, 0.64, 0.12), Color("#7d64ad"))
	for side: float in [-1.0, 1.0]:
		var stand := bed + Vector3(side * 1.75, 0, -1.25)
		structure.box(stand + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.6), WOOD)
		kit.detail.box(stand + Vector3(0, 0.45, 0.31), Vector3(0.3, 0.05, 0.02), GOLD)
	var lamp := bed + Vector3(1.75, 0.95, -1.25)
	kit.detail.tube(lamp, 0.04, 0.04, 0.5, GOLD, 5)
	kit.glow.ball(lamp + Vector3(0, 0.38, 0), 0.24, Color("#d8ccff"), Color.TRANSPARENT, 8, 4)
	kit.lamp_light(lamp + Vector3(-0.6, 0.9, 1.4), 8.0, Color("#c3b4ff"))
	kit.blocker(bed + Vector3(0, 1.0, 0), Vector3(4.2, 2.0, 3.1))
	# Stars sprinkled on the dream wallpaper glow after dark.
	for index in 22:
		var x := 9.4 + fposmod(float(index) * 0.618, 1.0) * 7.0
		var y := 1.4 + fposmod(float(index) * 0.414 + 0.2, 1.0) * 2.8
		if absf(x - (bed.x - 0.3)) < 1.7 and y < 3.8: continue
		_star(kit.glow, Vector3(x, y, WALL_Z + 0.17), 0.07 + 0.06 * fposmod(float(index) * 0.27, 1.0), MOON if index % 3 else Color("#d8ccff"))
	# A round starry rug in front of the bed.
	structure.tube(Vector3(bed.x, 0.212, -5.6), 1.4, 1.4, 0.024, Color("#3f3466"), 18, Basis.from_scale(Vector3(1.0, 1.0, 0.65)))
	_star(structure, Vector3(bed.x, 0.226, -5.6), 0.5, MOON, Vector3.UP)
	# Puffy cloud cushions on the dream veranda.
	for spot: Vector3 in [Vector3(9.9, 0.2, -12.0), Vector3(10.0, 0.2, 8.6), Vector3(15.8, 0.2, 7.1)]:
		for puff in 4:
			var turn := Basis(Vector3.UP, float(puff) * 1.7)
			structure.ball(spot + turn * Vector3(0.28 * float(mini(puff, 1)), 0.26 + 0.08 * float(puff % 2), 0), 0.36 - 0.04 * float(puff), SHEET if puff % 2 == 0 else Color("#e3dafa"), Color.TRANSPARENT, 8, 4, 0.75)
		kit.blocker(spot + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0))

## A crescent moon cut from a disc, standing against the wall.
func _crescent(centre: Vector3, radius: float, color: Color) -> void:
	const STEPS := 14
	var inner_centre := centre + Vector3(radius * 0.42, radius * 0.18, 0)
	var inner_radius := radius * 0.86
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for step in STEPS + 1:
		var angle := lerpf(PI * 0.32, PI * 1.68, float(step) / float(STEPS))
		var direction := Vector3(cos(angle), sin(angle), 0)
		outer.append(centre + direction * radius)
		var t := float(step) / float(STEPS)
		var tip := absf(t - 0.5) * 2.0
		inner.append((centre + direction * radius).lerp(inner_centre + direction * inner_radius, 1.0 - tip * tip))
	for step in STEPS:
		structure.sheet(outer[step], outer[step + 1], inner[step + 1], color)
		structure.sheet(outer[step], inner[step + 1], inner[step], color.darkened(0.05))
		kit.detail.box((outer[step] + outer[step + 1]) * 0.5 + Vector3(0, 0, 0.02), Vector3(outer[step].distance_to(outer[step + 1]), 0.06, 0.03), GOLD, Basis(Vector3.BACK, atan2(outer[step + 1].y - outer[step].y, outer[step + 1].x - outer[step].x)))

## A four-pointed star facing `toward` (+Z on walls, up on floors).
static func _star(s: Kit.Sculpt, at: Vector3, size: float, color: Color, toward := Vector3.BACK) -> void:
	var right := Vector3.RIGHT
	var up := Vector3.UP if toward != Vector3.UP else Vector3.FORWARD
	for point in 4:
		var angle := TAU * float(point) / 4.0
		var tip := at + (right * cos(angle) + up * sin(angle)) * size
		var side_a := at + (right * cos(angle + 0.785) + up * sin(angle + 0.785)) * size * 0.32
		var side_b := at + (right * cos(angle - 0.785) + up * sin(angle - 0.785)) * size * 0.32
		_tri_out(s, at, tip, side_a, toward, color)
		_tri_out(s, at, side_b, tip, toward, color)

# --- Veranda -------------------------------------------------------------------

func _build_veranda() -> void:
	# A low railing of turned posts along the veranda's edge.
	var posts := kit.posts()
	for index in RAIL.size() - 1:
		var from: Vector2 = RAIL[index]
		var to: Vector2 = RAIL[index + 1]
		var count := maxi(1, roundi(from.distance_to(to) / 1.2))
		for step in count + 1:
			var at := from.lerp(to, float(step) / float(count))
			posts.add(Vector3(at.x, 0.55, at.y), Vector3(0.1, 0.7, 0.1), Basis.IDENTITY, CREAM)
		var middle := (from + to) * 0.5
		var along_x := absf(to.x - from.x) > absf(to.y - from.y)
		var length := from.distance_to(to) + 0.08
		kit.detail.box(Vector3(middle.x, 0.92, middle.y), Vector3(length, 0.08, 0.12) if along_x else Vector3(0.12, 0.08, length), PLUM)
		kit.detail.box(Vector3(middle.x, 0.5, middle.y), Vector3(length, 0.04, 0.05) if along_x else Vector3(0.05, 0.04, length), PLUM.lightened(0.2))
	# Room-number signposts: a glowing plate and the room's name.
	for index in world.AREAS.size():
		var area: Dictionary = world.AREAS[index]
		var at: Vector3 = world.SIGNPOSTS[index]
		structure.box(at + Vector3(0, 0.08, 0), Vector3(0.42, 0.16, 0.42), PLUM)
		structure.tube(at + Vector3(0, 1.05, 0), 0.07, 0.06, 1.8, WOOD, 6)
		var plate := at + Vector3(0, 2.05, 0.05)
		var face := Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.7))
		structure.tube(plate, 0.54, 0.54, 0.08, GOLD, 16, face)
		kit.glow.tube(plate + Vector3(0, 0, 0.05), 0.45, 0.45, 0.02, MOON, 16, face)
		_tiny_ghost(kit.detail, plate + Vector3(0.48, 0.38, 0.06), 0.16)
		var number: Label3D = world._label(String(area.number), plate + Vector3(0, 0.02, 0.2), 38, PLUM)
		number.outline_modulate = MOON
		number.pixel_size = 0.0125
		number.visibility_range_end = 0.0
		number.name = "HotelRoomNumber_" + String(area.number)
		var title: Label3D = world._local_label(String(area.label), at + Vector3(0, 1.45, 0.12), 22, CREAM)
		title.pixel_size = 0.0115
		kit.blocker(at + Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45))
	for spot: Vector2 in LAMP_POSTS:
		kit.lamp_post(Vector3(spot.x, world.GROUND_Y, spot.y), 6.5)

## Kept stand sites: a low crate asleep under a dust sheet, with a "準備中" tag.
func _build_sites() -> void:
	var sheets: Array[Color] = [SHEET, Color("#e6dcf7"), Color("#dcefe9"), Color("#f7e3e8")]
	var index := 0
	for site: Dictionary in world.open_sites():
		var at: Vector3 = site.stand
		var cloth: Color = sheets[index % sheets.size()]
		var fold := cloth.darkened(0.12)
		var turn := Basis(Vector3.UP, (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.3)
		structure.box(at + Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 0.9), Color("#6e6478"), turn)
		structure.box(at + Vector3(0, 0.48, 0), Vector3(1.24, 0.72, 0.8), cloth, turn)
		structure.ball(at + Vector3(0, 0.84, 0), 0.66, cloth, cloth.darkened(0.04), 10, 3, 0.36, true)
		for crease in 4:
			structure.box(at + turn * Vector3(-0.42 + float(crease) * 0.28, 0.46, 0.41), Vector3(0.05, 0.62, 0.02), fold, turn)
		for hem in 5:
			structure.box(at + turn * Vector3(-0.5 + float(hem) * 0.25, 0.15, 0.42), Vector3(0.2, 0.1, 0.04), cloth if hem % 2 == 0 else fold, turn * Basis(Vector3.BACK, 0.3 * (1.0 if hem % 2 == 0 else -1.0)))
		# Sleepy eyes: the sheet dozes like a ghost until its game arrives.
		for eye: float in [-0.2, 0.2]:
			structure.box(at + turn * Vector3(eye, 0.72, 0.41), Vector3(0.16, 0.035, 0.02), INK, turn * Basis(Vector3.BACK, 0.25 * signf(eye)))
		var tag := at + turn * Vector3(0.45, 0, 0.62)
		structure.box(tag + Vector3(0, 0.36, 0), Vector3(0.05, 0.72, 0.05), WOOD)
		structure.box(tag + Vector3(0, 0.78, 0), Vector3(0.6, 0.3, 0.05), MOON.darkened(0.06))
		site_tags.append(world.StandSites.tag(world, tag + Vector3(0, 0.78, 0.08), PLUM, CREAM))
		kit.blocker(at + Vector3(0, 1.0, 0), world.ArcadeStands.FOOTPRINT)
		index += 1

func _build_garden() -> void:
	for spec: Array in PLANTS:
		var at := Vector2(float(spec[1]), float(spec[2]))
		if not _planted(at): continue
		kit.billboard(String(spec[0]), Vector3(at.x, world.LAWN_Y, at.y), float(spec[3]))
	# Low hedges and flower pots along the lawn south of the veranda.
	for index in 9:
		var x := -15.0 + float(index) * 3.7
		var z := 12.6 + sin(float(index) * 1.7) * 0.9
		var at := Vector2(x, z)
		if not _planted(at): continue
		kit.grove("shrub", Vector3(x, world.LAWN_Y, z), 1.0 + 0.2 * fposmod(float(index) * 0.37, 1.0))

## Planting stays inside the claim and, on the island, on lawn well clear of the water.
func _planted(at: Vector2) -> bool:
	if not world.in_dress_reach(at): return false
	return world.embedded_in == null or IslandShape.on_lawn(at + Vector2(world.position.x, world.position.z), 1.5)

func _commit() -> void:
	world._mesh(structure.mesh(), Vector3.ZERO, painted).name = "HotelStructure"
