extends RefCounted
## Everything in the clockwork toy town that never moves on its own: the lawn and
## its hills, the paved yard and its block kerbs, the block street, the workshop,
## the clock tower, the railway yard and the town that carries on beyond the yard.
## Built once through the scenery kit; it keeps the few parts that the world and
## toy_life turn afterwards.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/toy_props.gd")
const LAWN_Y := 0.05
## Grass banks: top rectangle x, z, width, depth, then top height, skirt and wobble
## seed. The first is the ridge behind the clock tower.
const KNOLLS := [
	[-15.0, -27.0, 30.0, 9.0, 2.8, 5.4, 0.7], [-27.5, -20.5, 7.0, 6.0, 1.7, 3.6, 2.9], [19.0, -22.5, 8.5, 7.0, 2.1, 4.2, 4.1],
	[-31.0, -4.0, 6.5, 9.0, 1.2, 3.6, 5.3], [24.5, 1.5, 7.0, 10.0, 1.3, 3.8, 1.9], [-25.0, 17.5, 8.0, 7.0, 0.9, 3.4, 3.3], [16.5, 19.5, 9.0, 7.0, 1.0, 3.4, 6.1],
]
## Yard outline as kerb runs: from x, z, to x, z, outward x, z. The last two edge the road home.
const KERBS := [
	[-10.9, -10.8, 4.35, -10.8, 0, -1], [4.35, -10.8, 4.35, -6.3, 1, 0], [12.1, -3.8, 12.1, 4.1, 1, 0], [12.1, 7.7, 12.1, 8.2, 1, 0],
	[4.35, 8.2, 12.1, 8.2, 0, 1], [4.35, 8.2, 4.35, 9.5, 1, 0], [2.2, 9.5, 4.35, 9.5, 0, 1], [-4.35, 9.5, -2.2, 9.5, 0, 1],
	[-4.35, 8.2, -4.35, 9.5, -1, 0], [-12.1, 8.2, -4.35, 8.2, 0, 1], [-12.1, -3.8, -12.1, 8.2, -1, 0], [-12.1, -3.8, -10.9, -3.8, 0, -1],
	[-10.9, -10.8, -10.9, -3.8, -1, 0], [-2.2, 9.5, -2.2, 31.0, -1, 0], [2.2, 9.5, 2.2, 31.0, 1, 0],
]
## Houses of the block street, north to south: z, height, body, roof, roof kind, windows, wind-up key.
const STREET_X := -10.78
const STREET := [
	[-2.75, 3.3, Props.BLUE, Props.RED, "gable", 2, true], [-0.15, 2.6, Props.YELLOW, Props.GREEN, "flat", 2, false], [2.45, 1.95, Props.PINK, Props.TEAL, "gable", 2, true],
]
## The town beyond the yard: x, z, width, depth, height, body, roof, roof kind, windows, chimney, wind-up key.
const TOWN := [
	[-15.2, -7.6, 2.4, 2.0, 2.7, Props.GREEN, Props.RED, "gable", 2, true, true], [-18.9, -2.4, 2.8, 2.0, 3.3, Props.PINK, Props.BLUE, "gable", 3, false, false],
	[-15.4, 2.0, 2.0, 1.8, 2.3, Props.CREAM, Props.ORANGE, "cone", 1, false, false], [-19.6, 6.4, 2.6, 2.0, 2.5, Props.YELLOW, Props.GREEN, "gable", 2, true, false],
	[-27.6, 0.6, 2.2, 1.8, 2.0, Props.BLUE, Props.YELLOW, "flat", 2, false, false], [-23.5, -9.6, 2.4, 2.0, 2.4, Props.ORANGE, Props.PURPLE, "gable", 2, false, true],
	[15.4, -6.4, 2.5, 2.0, 2.9, Props.YELLOW, Props.RED, "gable", 2, true, true], [19.4, -1.6, 2.2, 1.9, 2.3, Props.TEAL, Props.ORANGE, "flat", 2, false, false],
	[18.9, 9.8, 2.6, 2.0, 2.6, Props.PINK, Props.PURPLE, "gable", 2, true, false], [15.4, 12.6, 2.3, 1.9, 2.1, Props.GREEN, Props.YELLOW, "gable", 2, false, false],
	[22.6, -8.4, 2.2, 2.0, 2.5, Props.BLUE, Props.RED, "cone", 1, false, false], [27.6, 6.2, 2.4, 2.0, 2.4, Props.CREAM, Props.RED, "gable", 2, true, false],
	[-11.6, -20.2, 2.4, 2.0, 2.4, Props.RED, Props.BLUE, "gable", 2, true, false], [-7.3, -20.4, 2.6, 2.0, 3.0, Props.YELLOW, Props.GREEN, "gable", 2, false, true],
	[-3.7, -20.0, 2.0, 1.8, 2.2, Props.CREAM, Props.RED, "cone", 1, false, false], [3.9, -20.2, 2.6, 2.0, 2.8, Props.BLUE, Props.ORANGE, "gable", 2, true, false],
	[8.2, -20.3, 2.2, 1.9, 2.2, Props.PINK, Props.TEAL, "flat", 2, false, false], [12.2, -20.4, 2.4, 2.0, 2.9, Props.GREEN, Props.RED, "gable", 2, false, true],
	[-9.5, -24.4, 2.6, 2.0, 3.6, Props.PURPLE, Props.YELLOW, "gable", 2, false, false], [-4.8, -24.6, 2.4, 2.0, 3.2, Props.TEAL, Props.RED, "cone", 2, false, false],
	[0.0, -24.5, 3.2, 2.2, 4.2, Props.ORANGE, Props.BLUE, "gable", 3, true, false], [5.4, -24.6, 2.4, 2.0, 3.3, Props.RED, Props.CREAM, "flat", 2, false, false],
	[10.2, -24.4, 2.6, 2.0, 3.7, Props.YELLOW, Props.PURPLE, "gable", 2, true, false], [-24.0, -17.4, 2.4, 2.0, 2.6, Props.CREAM, Props.GREEN, "gable", 2, true, false],
	[25.0, -19.0, 2.4, 2.0, 2.5, Props.YELLOW, Props.BLUE, "gable", 2, false, false], [-9.2, 14.8, 2.5, 2.0, 2.3, Props.RED, Props.YELLOW, "gable", 2, true, false],
	[9.4, 15.6, 2.4, 2.0, 2.5, Props.BLUE, Props.RED, "gable", 2, false, true], [-16.8, 13.0, 2.2, 1.8, 2.0, Props.YELLOW, Props.BLUE, "flat", 2, false, false],
	[-6.8, 21.8, 2.4, 2.0, 2.6, Props.GREEN, Props.ORANGE, "gable", 2, true, false], [7.4, 22.8, 2.6, 2.0, 2.4, Props.PINK, Props.BLUE, "cone", 1, false, false],
	[-21.0, 21.0, 2.4, 2.0, 2.4, Props.TEAL, Props.RED, "gable", 2, false, false], [21.0, 23.0, 2.4, 2.0, 2.6, Props.ORANGE, Props.GREEN, "gable", 2, true, false],
]
## Painted trees for the far corners, where the lawn runs on toward the neighbours: kind, x, z, height.
const WOODS := [["oak", -28.0, 11.5, 5.6], ["ginkgo", 28.5, -5.5, 5.2], ["pine", -30.0, -10.5, 5.0], ["oak", 26.5, 15.0, 5.4], ["ginkgo", -13.5, 25.5, 5.0], ["oak", 13.0, 27.0, 5.2], ["pine", 30.5, -14.0, 4.8]]
## Lamp posts on the yard. All eight stay lit; the nearest two cast shadows. None
## stands between the story portrait's camera and its two subjects.
const LAMP_POSTS: Array[Vector2] = [
	Vector2(-2.75, 9.25), Vector2(2.75, 9.25), Vector2(-9.1, -3.25), Vector2(-5.0, -10.3),
	Vector2(4.0, -10.3), Vector2(4.55, -3.3), Vector2(11.85, -1.4), Vector2(-4.1, -0.6),
]
const MARBLE_RUN_AT := Vector3(6.35, LAWN_Y, -9.0)
const CHEST_AT := Vector3(10.0, LAWN_Y, -8.1)
const CAROUSEL_AT := Vector3(16.4, LAWN_Y, 3.2)
## Far enough down the road that its towers and flags never reach across the entrance paving.
const GATE_AT := Vector3(0, LAWN_Y, 18.2)
const TOWER_AT := Vector3(0, 0.2, -9.9)
const GLASS_AT := Vector3(0, 0.2, -3.6)
## Kites: where the string is pegged, then where the kite flies from there.
const KITES := [[Vector3(-16.5, LAWN_Y, 10.5), Vector3(-3.5, 6.0, -2.5)], [Vector3(17.5, LAWN_Y, 12.0), Vector3(3.0, 5.5, -2.0)]]
## Pinwheels on the hills and the lawn: x, z, height of the wheel above the grass.
const PINWHEELS := [[-13.6, -19.2, 2.4], [1.9, -19.2, 2.2], [14.0, -21.6, 2.6], [-21.6, -15.6, 2.2], [-14.0, 4.6, 1.9], [22.6, -19.6, 2.3], [13.6, 12.2, 1.5], [-13.4, -10.6, 2.0]]
const JACK_AT := Vector3(-3.2, 0.2, 6.0)
const JACK_SIZE := 0.9
const TOP_AT := Vector3(2.9, 0.2, -0.4)
## Two paved bays kept clear for the minigame stands that later tickets add.
const STAND_BAYS: Array[Rect2] = [Rect2(-4.3, -10.75, 2.5, 1.9), Rect2(12.1, 4.15, 2.6, 3.5)]
## Rail yard bed; the tail siding reaches south between the two control desks.
const YARD_BED := Rect2(4.75, -6.2, 6.8, 7.35)
const YARD_TAIL := Rect2(7.5, 1.15, 1.2, 0.75)
const YARD_TOP := 0.26

var world: Node3D
var kit: Kit
var shapes: Props.Blocks
var clock_hour: MeshInstance3D
var clock_minute: MeshInstance3D
var pendulum_at := Vector3.ZERO
var clock_face_at := Vector3.ZERO
var station_label: Label3D
var lever: MeshInstance3D
## Signal arms over the left and right branch.
var signals: Array[MeshInstance3D] = []
## Where wind-up keys turn (each key's shaft runs along the pose's Z), and how big they are.
var keys: Array[Transform3D] = []
var key_sizes := PackedFloat32Array()
var marble_path := PackedVector3Array()
var pinwheels: Array[Vector3] = []
var flags: Kit.Batch
var _ground_y: float
var _footprints: Array[Rect2] = []

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit
	_ground_y = owner.GROUND_Y
	shapes = Props.blocks(owner, scenery_kit)

func build() -> void:
	flags = kit.batch("flags", Kit.cloth_mesh(Vector2(0.9, 0.5), 5, 1, false), kit.cloth_material("flag", 0.18))
	_build_ground()
	await world.build_pause()
	_build_kerbs()
	await world.build_pause()
	_build_block_street()
	await world.build_pause()
	_build_workshop()
	await world.build_pause()
	_build_clock_tower()
	await world.build_pause()
	_build_station()
	await world.build_pause()
	_build_plaza()
	await world.build_pause()
	_build_back_lot()
	await world.build_pause()
	_build_gate()
	await world.build_pause()
	_build_town()
	await world.build_pause()
	_build_planting()
	await world.build_pause()

## Windows, lantern bodies and the clock face follow the region's lamp level.
func apply_time_of_day(lamp_level: float) -> void:
	kit.set_glow(lamp_level * 2.4)

## Height of the grass at a point off the yard: a knoll's flat top or the lawn.
static func lawn_height(point: Vector2) -> float:
	for knoll: Array in KNOLLS:
		if Rect2(knoll[0], knoll[1], knoll[2], knoll[3]).has_point(point): return float(knoll[4])
	return LAWN_Y

## True on a knoll's sloping skirt, where nothing can stand level.
static func on_slope(point: Vector2) -> bool:
	for knoll: Array in KNOLLS:
		var top := Rect2(knoll[0], knoll[1], knoll[2], knoll[3])
		if top.grow(float(knoll[5]) * 1.25).has_point(point) and not top.grow(-1.2).has_point(point): return true
	return false

func _lawn(x: float, z: float) -> Vector3:
	return Vector3(x, lawn_height(Vector2(x, z)), z)

## Repeatable 0..1 scatter value, so the town is identical on every visit.
func _scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)

func _claim(center: Vector3, width: float, depth: float) -> void:
	_footprints.append(Rect2(center.x - width * 0.5, center.z - depth * 0.5, width, depth))

func _add_key(pose: Transform3D, size := 1.0) -> void:
	if not pose.origin.is_finite(): return
	keys.append(pose)
	key_sizes.append(size)

## Name board on a wall or hanging from a beam.
func _board(text: String, at: Vector3, width: float, paint: Color, font_size := 26) -> Label3D:
	shapes.box.add(at, Vector3(width, 0.46, 0.1), Basis.IDENTITY, paint.darkened(0.45))
	for edge: float in [-1.0, 1.0]:
		kit.detail.box(at + Vector3(0, edge * 0.24, 0.01), Vector3(width + 0.08, 0.05, 0.14), Props.CREAM)
	var label: Label3D = world._local_label(text, at + Vector3(0, 0.0, 0.2), font_size, Props.CREAM)
	label.pixel_size = 0.0131
	return label

func _build_ground() -> void:
	# On the island the knolls rise out of the island's own lawn, tint and all.
	var grass: ShaderMaterial = world.material_cache.get("welcome-lawn") if world.embedded_in != null else null
	if grass == null:
		grass = ShaderMaterial.new()
		grass.shader = world.GRASS
		var plane := PlaneMesh.new()
		plane.size = Vector2(220, 220)
		var lawn: MeshInstance3D = world._mesh(plane, Vector3(0, LAWN_Y, 0), grass)
		lawn.name = "ToyLawn"
		lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.material_cache["toy:lawn"] = grass
	for knoll: Array in KNOLLS:
		kit.mound(Rect2(knoll[0], knoll[1], knoll[2], knoll[3]), float(knoll[4]), float(knoll[4]) - LAWN_Y + 0.12, float(knoll[5]), grass, float(knoll[6]))
	for area: Dictionary in world.AREAS:
		var rect: Rect2 = area.rect
		var floor_mesh: MeshInstance3D = world._box(Vector3(rect.get_center().x, _ground_y - 0.15, rect.get_center().y), Vector3(rect.size.x, 0.3, rect.size.y), area.tint, true)
		floor_mesh.name = "ToyFloor_" + str(area.id)
		world._set_registered_surface(floor_mesh, world._coastal_surface(area.tile, 2.4, area.tint))
	# The road home runs south through the castle gate and on toward the welcome avenue.
	var road: Dictionary = world.AREAS[0]
	var way: Rect2 = Rect2(-2.2, 9.5, 4.4, 32.5) if world.embedded_in == null else world._site.approach
	kit.surface(world._coastal_surface(road.tile, 2.4, road.tint)).add(Vector3(way.get_center().x, _ground_y - 0.16, way.get_center().y), Vector3(way.size.x, 0.3, way.size.y))
	for bay in STAND_BAYS:
		if world._on_yard(bay.get_center()): continue
		kit.surface(world._coastal_surface(4, 2.4, Color("#e6d7b6"))).add(Vector3(bay.get_center().x, _ground_y - 0.16, bay.get_center().y), Vector3(bay.size.x, 0.3, bay.size.y))

## Painted block kerbs frame the yard and the road, so the paving meets the grass with a toy edge.
func _build_kerbs() -> void:
	const STEP := 0.62
	var paints: Array[Color] = [Props.RED, Props.YELLOW, Props.BLUE, Props.GREEN]
	var runs: Array = KERBS.duplicate()
	var bay := STAND_BAYS[1]
	runs.append_array([[bay.position.x, bay.position.y, bay.end.x, bay.position.y, 0, -1], [bay.end.x, bay.position.y, bay.end.x, bay.end.y, 1, 0], [bay.position.x, bay.end.y, bay.end.x, bay.end.y, 0, 1]])
	var laid := 0
	for run: Array in runs:
		var from := Vector2(float(run[0]), float(run[1]))
		var to := Vector2(float(run[2]), float(run[3]))
		var outward := Vector2(float(run[4]), float(run[5]))
		var count := maxi(1, roundi(from.distance_to(to) / STEP))
		var along_x := is_zero_approx(outward.x)
		for index in range(count):
			var at := from.lerp(to, (float(index) + 0.5) / float(count)) + outward * 0.14
			var length := from.distance_to(to) / float(count) - 0.03
			var paint := Props.CREAM.darkened(0.06) if laid % 2 == 0 else paints[(laid / 2) % 4].lerp(Props.CREAM, 0.2)
			shapes.box.add(Vector3(at.x, LAWN_Y + 0.12, at.y), Vector3(length, 0.26, 0.26) if along_x else Vector3(0.26, 0.26, length), Basis.IDENTITY, paint)
			laid += 1

func _build_block_street() -> void:
	for index in range(STREET.size()):
		var row: Array = STREET[index]
		var at := Vector3(STREET_X, _ground_y, float(row[0]))
		_add_key(Props.house(shapes, at, {"w": 2.3, "d": 1.6, "h": float(row[1]), "body": row[2], "roof": row[3], "roof_kind": row[4], "windows": row[5], "chimney": index == 0, "key": row[6], "door": 0.0}))
	kit.blocker(Vector3(-10.83, 1.2, -0.2), Vector3(2.55, 2.4, 7.2))
	Props.signpost(world, shapes, Vector3(-9.15, _ground_y, 3.95), "積木街", 1.5, Props.GREEN)
	# The ball pit fills the street's south corner.
	var pit := Rect2(-11.95, 4.75, 2.5, 3.25)
	var pit_center := Vector3(pit.get_center().x, _ground_y, pit.get_center().y)
	kit.detail.box(pit_center + Vector3(0, 0.02, 0), Vector3(pit.size.x, 0.04, pit.size.y), Props.TEAL.darkened(0.25))
	for side: float in [-1.0, 1.0]:
		shapes.box.add(pit_center + Vector3(side * pit.size.x * 0.5, 0.27, 0), Vector3(0.22, 0.54, pit.size.y + 0.22), Basis.IDENTITY, Props.BLUE if side < 0.0 else Props.YELLOW)
		shapes.box.add(pit_center + Vector3(0, 0.27, side * pit.size.y * 0.5), Vector3(pit.size.x - 0.22, 0.54, 0.22), Basis.IDENTITY, Props.RED if side < 0.0 else Props.GREEN)
		for corner: float in [-1.0, 1.0]:
			shapes.ball.add(pit_center + Vector3(side * pit.size.x * 0.5, 0.64, corner * pit.size.y * 0.5), Vector3.ONE * 0.3, Basis.IDENTITY, Props.CREAM)
	for ball in range(96):
		var seed_value := float(ball) * 3.7 + 1.3
		var size := 0.26 + 0.08 * _scatter(seed_value + 2.0)
		var at := pit_center + Vector3((_scatter(seed_value) - 0.5) * (pit.size.x - 0.5), 0.16 + 0.26 * _scatter(seed_value + 4.0), (_scatter(seed_value + 1.0) - 0.5) * (pit.size.y - 0.5))
		shapes.ball.add(at, Vector3.ONE * size, Basis.IDENTITY, Props.RAINBOW[ball % Props.RAINBOW.size()])
	kit.blocker(pit_center + Vector3(0, 0.7, 0), Vector3(pit.size.x + 0.3, 1.4, pit.size.y + 0.3))

## The repair workshop: a plank wall carrying the big gears, the bench in front of
## it and a row of toys waiting their turn down the west side.
func _build_workshop() -> void:
	var wall := Vector3(-7.85, _ground_y, -10.45)
	kit.surface(world._coastal_surface(1, 2.0, Color("#e9cfa6"))).add(wall + Vector3(0, 1.35, 0), Vector3(5.7, 2.7, 0.3))
	shapes.box.add(wall + Vector3(0, 0.13, 0.04), Vector3(5.84, 0.26, 0.4), Basis.IDENTITY, Props.DARK_WOOD)
	shapes.roof.add(wall + Vector3(0, 2.98, 0.05), Vector3(0.9, 0.56, 5.96), Basis(Vector3.UP, PI * 0.5), Props.RED)
	for post: float in [-2.85, 2.85]:
		shapes.column.add(wall + Vector3(post, 1.35, 0.16), Vector3(0.2, 2.7, 0.2), Basis.IDENTITY, Props.TEAL)
	# Tool board on the east end of the wall.
	var tools := wall + Vector3(2.05, 1.5, 0.16)
	kit.detail.box(tools, Vector3(1.3, 1.2, 0.03), Props.CREAM.darkened(0.1))
	kit.detail.box(tools + Vector3(-0.4, 0.05, 0.03), Vector3(0.07, 0.8, 0.03), Props.STEEL)
	kit.detail.box(tools + Vector3(-0.4, 0.42, 0.03), Vector3(0.24, 0.14, 0.03), Props.STEEL)
	kit.detail.box(tools + Vector3(-0.05, -0.05, 0.03), Vector3(0.07, 0.62, 0.03), Props.DARK_WOOD)
	kit.detail.box(tools + Vector3(-0.05, 0.3, 0.03), Vector3(0.3, 0.16, 0.04), Props.INK.lightened(0.15))
	kit.detail.box(tools + Vector3(0.3, 0.1, 0.03), Vector3(0.05, 0.7, 0.03), Props.RED)
	kit.detail.box(tools + Vector3(0.3, -0.34, 0.03), Vector3(0.09, 0.22, 0.04), Props.YELLOW)
	for peg in range(3):
		kit.detail.tube(tools + Vector3(-0.35 + 0.33 * float(peg), -0.45, 0.04), 0.09, 0.09, 0.03, [Props.BRASS, Props.COPPER, Props.STEEL][peg], 8, Basis(Vector3.RIGHT, PI * 0.5))
	_board("維修台 · 重置", wall + Vector3(-1.9, 0.58, 0.24), 2.5, Props.TEAL, 24)
	# The bench, with a robot's missing arm and a few loose parts on it.
	var bench := Vector3(-6.7, _ground_y, -9.55)
	kit.surface(world._coastal_surface(1, 1.4, Color("#f0d9ae"))).add(bench + Vector3(0, 0.88, 0), Vector3(2.9, 0.12, 0.9))
	for leg: float in [-1.25, 1.25]:
		shapes.box.add(bench + Vector3(leg, 0.41, 0), Vector3(0.24, 0.82, 0.8), Basis.IDENTITY, Props.BLUE if leg < 0.0 else Props.RED)
	kit.detail.box(bench + Vector3(0, 0.3, 0.02), Vector3(2.3, 0.06, 0.7), Props.DARK_WOOD)
	kit.detail.box(bench + Vector3(-0.8, 1.02, 0.1), Vector3(0.7, 0.16, 0.2), Color("#7fa9b8"), Basis(Vector3.UP, 0.3))
	kit.detail.box(bench + Vector3(-0.42, 1.02, -0.02), Vector3(0.16, 0.18, 0.22), Props.RED, Basis(Vector3.UP, 0.3))
	kit.detail.tube(bench + Vector3(0.2, 0.98, 0.1), 0.2, 0.2, 0.07, Props.BRASS, 10)
	kit.detail.tube(bench + Vector3(0.2, 1.03, 0.1), 0.07, 0.07, 0.06, Props.BRASS.darkened(0.3), 6)
	kit.detail.tube(bench + Vector3(0.75, 1.07, -0.1), 0.1, 0.13, 0.26, Props.RED, 8)
	kit.detail.tube(bench + Vector3(0.75, 1.25, -0.1), 0.02, 0.05, 0.12, Props.STEEL, 6)
	kit.detail.box(bench + Vector3(1.1, 0.97, 0.2), Vector3(0.4, 0.05, 0.07), Props.YELLOW, Basis(Vector3.UP, -0.5))
	kit.blocker(Vector3(-8.05, 1.3, -9.9), Vector3(5.7, 2.6, 1.8))
	# Waiting their turn: a tin robot, a pile of spare gears and a stack of cubes.
	_add_key(Transform3D(Basis.IDENTITY, Props.tin_robot(shapes, Vector3(-10.2, _ground_y, -8.1))), 0.7)
	var spares := Vector3(-10.15, _ground_y, -6.3)
	for disc in range(5):
		var radius := 0.52 - 0.06 * float(disc)
		shapes.column.add(spares + Vector3(0.08 * sin(float(disc) * 2.1), 0.07 + 0.14 * float(disc), 0.06 * cos(float(disc) * 1.7)), Vector3(radius * 2.0, 0.13, radius * 2.0), Basis.IDENTITY, [Props.BRASS, Props.COPPER, Props.STEEL][disc % 3])
	Props.cube_stack(shapes, Vector3(-10.15, _ground_y, -4.7), ["A", "B", "C"], 0.82, 0)
	kit.blocker(Vector3(-10.2, 1.3, -6.4), Vector3(1.4, 2.6, 5.2))
	kit.bunting(wall + Vector3(2.9, 3.0, 0.3), TOWER_AT + Vector3(-1.2, 3.5, 0.9), Props.RAINBOW, 0.45)

## Clock tower of stacked blocks: stepped plinth, a shaft with the pendulum behind
## glass, the clock head and a cone roof. The hands and the pendulum are separate
## meshes so the world and toy_life can turn them.
func _build_clock_tower() -> void:
	var at := TOWER_AT
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	var paint: Material = world._vertex_color_material("scenery-detail")
	shapes.box.add(at + Vector3(0, 0.25, 0), Vector3(3.3, 0.5, 2.1), Basis.IDENTITY, Props.CREAM.darkened(0.12))
	shapes.box.add(at + Vector3(0, 0.68, 0), Vector3(2.9, 0.36, 2.0), Basis.IDENTITY, Props.ORANGE)
	shapes.box.add(at + Vector3(0, 2.06, 0), Vector3(2.3, 2.4, 1.7), Basis.IDENTITY, Props.TEAL)
	for side: float in [-1.0, 1.0]:
		shapes.column.add(at + Vector3(side * 1.12, 2.06, 0.82), Vector3(0.3, 2.4, 0.3), Basis.IDENTITY, Props.CREAM)
	shapes.box.add(at + Vector3(0, 3.36, 0), Vector3(2.8, 0.2, 2.1), Basis.IDENTITY, Props.YELLOW)
	shapes.box.add(at + Vector3(0, 4.56, 0), Vector3(2.5, 2.2, 1.9), Basis.IDENTITY, Props.RED)
	shapes.box.add(at + Vector3(0, 5.76, 0), Vector3(2.9, 0.2, 2.2), Basis.IDENTITY, Props.CREAM)
	shapes.cone.add(at + Vector3(0, 6.66, 0), Vector3(3.1, 1.6, 3.1), Basis.IDENTITY, Props.BLUE)
	shapes.ball.add(at + Vector3(0, 7.5, 0), Vector3.ONE * 0.26, Basis.IDENTITY, Props.YELLOW)
	kit.detail.tube(at + Vector3(0, 7.95, 0), 0.03, 0.03, 0.9, Props.DARK_WOOD, 6)
	flags.add(at + Vector3(0.03, 8.36, 0), Vector3.ONE, Basis.IDENTITY, Props.RED)
	# Clock face: brass rim, a pale dial that glows after dark, twelve marks.
	var face := at + Vector3(0, 4.56, 0.95)
	clock_face_at = face
	kit.detail.tube(face + Vector3(0, 0, 0.03), 1.0, 1.0, 0.07, Props.BRASS, 20, facing)
	kit.glow.tube(face + Vector3(0, 0, 0.06), 0.86, 0.86, 0.03, Color("#fff4d6"), 20, facing)
	for mark in range(12):
		var turn := Basis(Vector3.BACK, TAU * float(mark) / 12.0)
		kit.detail.box(face + turn * Vector3(0, 0.7, 0) + Vector3(0, 0, 0.08), Vector3(0.05 if mark % 3 != 0 else 0.09, 0.16, 0.02), Props.INK, turn)
	clock_hour = world._mesh(Props.hand_mesh(0.42, 0.09, Props.INK), face + Vector3(0, 0, 0.11), paint)
	clock_hour.name = "ToyClockHourHand"
	clock_minute = world._mesh(Props.hand_mesh(0.62, 0.055, Props.RED), face + Vector3(0, 0, 0.14), paint)
	clock_minute.name = "ToyClockMinuteHand"
	for hand: MeshInstance3D in [clock_hour, clock_minute]:
		hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.detail.tube(face + Vector3(0, 0, 0.17), 0.07, 0.07, 0.04, Props.BRASS, 8, facing)
	# The pendulum case: a dark recess in the shaft with a cream frame.
	var case := at + Vector3(0, 2.0, 0.852)
	kit.detail.box(case, Vector3(0.96, 1.9, 0.02), Color("#2b3038"))
	for edge: float in [-1.0, 1.0]:
		kit.detail.box(case + Vector3(edge * 0.52, 0, 0.03), Vector3(0.09, 2.02, 0.08), Props.CREAM)
		kit.detail.box(case + Vector3(0, edge * 0.98, 0.03), Vector3(1.12, 0.09, 0.08), Props.CREAM)
	pendulum_at = at + Vector3(0, 2.88, 0.93)
	_add_key(Transform3D(Basis.IDENTITY, at + Vector3(0.84, 1.3, 0.86)), 1.25)
	_board("發條鐘樓", at + Vector3(0, 0.72, 1.04), 2.3, Props.BLUE, 26)
	kit.blocker(at + Vector3(0, 1.5, 0), Vector3(3.4, 3.0, 2.1))
	# Cubes and a tall pencil keep the tower company on its east side.
	Props.cube_stack(shapes, Vector3(3.15, _ground_y, -10.05), ["1", "2", "3"], 0.9, 1)
	kit.blocker(Vector3(3.15, 1.3, -10.05), Vector3(1.0, 2.6, 1.0))

## The railway yard: a ballast bed for toy_train's rails, a platform with a canopy,
## the signal gantry that carries the status board, a block tunnel, buffer stops and
## the two lever desks. The world owns the board's text and the levers' positions.
func _build_station() -> void:
	var gravel := Color("#c4b595")
	var bed: MeshInstance3D = world._box(Vector3(YARD_BED.get_center().x, (YARD_TOP - 0.15) * 0.5, YARD_BED.get_center().y), Vector3(YARD_BED.size.x, YARD_TOP + 0.15, YARD_BED.size.y), gravel)
	bed.name = "ToyRailPlatform"
	kit.surface(world._finish(gravel, Vector3.ONE * 2.0)).add(Vector3(YARD_TAIL.get_center().x, YARD_TOP - 0.1, YARD_TAIL.get_center().y), Vector3(YARD_TAIL.size.x, 0.2, YARD_TAIL.size.y))
	# Timber edging around the bed.
	for side: float in [-1.0, 1.0]:
		shapes.box.add(Vector3(YARD_BED.get_center().x + side * YARD_BED.size.x * 0.5, YARD_TOP - 0.02, YARD_BED.get_center().y), Vector3(0.14, 0.16, YARD_BED.size.y + 0.14), Basis.IDENTITY, Props.DARK_WOOD)
	shapes.box.add(Vector3(YARD_BED.get_center().x, YARD_TOP - 0.02, YARD_BED.position.y), Vector3(YARD_BED.size.x, 0.16, 0.14), Basis.IDENTITY, Props.DARK_WOOD)
	kit.blocker(Vector3(8.225, 1.0, -1.375), Vector3(7.75, 2.0, 5.05))
	kit.blocker(Vector3(YARD_TAIL.get_center().x, 1.0, 1.5), Vector3(YARD_TAIL.size.x, 2.0, 0.8))
	# Platform and canopy beside the departure track.
	var platform := Vector3(6.85, YARD_TOP, -0.28)
	kit.surface(world._coastal_surface(1, 1.3, Color("#f1dcb4"))).add(platform + Vector3(0, 0.15, 0), Vector3(1.5, 0.3, 2.65))
	kit.detail.box(platform + Vector3(0.72, 0.31, 0), Vector3(0.1, 0.02, 2.65), Props.YELLOW)
	var roof_tilt := Basis(Vector3.BACK, 0.1)
	var roof := platform + Vector3(0, 1.82, 0.7)
	shapes.box.add(roof, Vector3(1.9, 0.09, 1.3), roof_tilt, Props.RED)
	for corner_x: float in [-0.6, 0.6]:
		for corner_z: float in [0.2, 1.2]:
			kit.detail.tube(platform + Vector3(corner_x, 1.02, corner_z), 0.045, 0.045, 1.5, Props.TEAL, 6)
	for scallop in range(7):
		kit.detail.box(roof + roof_tilt * Vector3(-0.81 + 0.27 * float(scallop), -0.13, 0.65), Vector3(0.26, 0.2 if scallop % 2 == 0 else 0.14, 0.03), Props.CREAM if scallop % 2 == 0 else Props.RED, roof_tilt)
	for scallop in range(5):
		kit.detail.box(roof + roof_tilt * Vector3(0.95, -0.13, -0.52 + 0.26 * float(scallop)), Vector3(0.03, 0.2 if scallop % 2 == 0 else 0.14, 0.25), Props.CREAM if scallop % 2 == 0 else Props.RED, roof_tilt)
	# Bench, luggage and a platform clock.
	kit.detail.box(platform + Vector3(-0.3, 0.52, 0.5), Vector3(0.9, 0.05, 0.3), Props.WOOD)
	for leg: float in [-0.36, 0.36]:
		kit.detail.box(platform + Vector3(-0.3 + leg, 0.4, 0.5), Vector3(0.06, 0.22, 0.26), Props.INK)
	kit.detail.box(platform + Vector3(-0.3, 0.72, 0.36), Vector3(0.9, 0.24, 0.05), Props.WOOD)
	shapes.box.add(platform + Vector3(0.1, 0.5, -0.75), Vector3(0.5, 0.36, 0.3), Basis(Vector3.UP, 0.2), Props.BLUE)
	shapes.box.add(platform + Vector3(-0.38, 0.47, -0.9), Vector3(0.36, 0.32, 0.26), Basis(Vector3.UP, -0.3), Props.ORANGE)
	shapes.box.add(platform + Vector3(0.08, 0.8, -0.76), Vector3(0.34, 0.22, 0.24), Basis(Vector3.UP, 0.5), Props.YELLOW)
	var name_board: Label3D = world._local_label("玩具城站", roof + Vector3(0, -0.34, 0.72), 20, Props.CREAM)
	name_board.pixel_size = 0.0131
	kit.detail.box(roof + Vector3(0, -0.34, 0.64), Vector3(1.3, 0.3, 0.04), Props.TEAL.darkened(0.35))
	# Cargo waiting by the left terminus.
	Props.cube_stack(shapes, Vector3(5.25, YARD_TOP, -3.5), ["D", "E"], 0.5, 2)
	shapes.column.add(Vector3(5.2, YARD_TOP + 0.2, -2.75), Vector3(0.4, 0.4, 0.4), Basis.IDENTITY, Props.YELLOW)
	shapes.roof.add(Vector3(5.72, YARD_TOP + 0.2, -2.9), Vector3(0.44, 0.4, 0.4), Basis(Vector3.UP, 0.4), Props.RED)
	# Signal gantry over the two branches, carrying the status board.
	var board: Vector3 = world.STATION_STATUS_AT
	for leg: float in [-2.25, 2.25]:
		shapes.box.add(Vector3(board.x + leg, YARD_TOP + 1.0, board.z), Vector3(0.16, 2.0, 0.16), Basis.IDENTITY, Props.TEAL)
		shapes.box.add(Vector3(board.x + leg, YARD_TOP + 0.09, board.z), Vector3(0.36, 0.18, 0.36), Basis.IDENTITY, Props.INK.lightened(0.1))
	shapes.box.add(Vector3(board.x, YARD_TOP + 1.96, board.z), Vector3(4.7, 0.14, 0.18), Basis.IDENTITY, Props.TEAL.lightened(0.1))
	shapes.box.add(board, Vector3(world.STATION_STATUS_WIDTH, 0.43, 0.12), Basis.IDENTITY, Props.INK)
	kit.detail.box(board + Vector3(0, -0.2, 0.066), Vector3(world.STATION_STATUS_WIDTH, 0.05, 0.02), Props.BRASS)
	for hanger: float in [-1.1, 1.1]:
		kit.detail.box(board + Vector3(hanger, 0.3, 0), Vector3(0.04, 0.18, 0.04), Props.INK)
	station_label = world._local_label("", board + Vector3(0, 0.014, 0.245), 28, Color("#ffe1b2"))
	station_label.pixel_size = 0.0131
	var paint: Material = world._vertex_color_material("scenery-detail")
	for branch in range(2):
		var mast := Vector3(board.x + (-1.23 if branch == 0 else 1.47), YARD_TOP + 2.03, board.z)
		kit.detail.tube(mast + Vector3(0, 0.3, 0), 0.035, 0.035, 0.6, Props.INK, 6)
		kit.detail.box(mast + Vector3(0, 0.62, 0), Vector3(0.1, 0.06, 0.1), Props.BRASS)
		var arm_sculpt := Kit.Sculpt.new()
		arm_sculpt.box(Vector3(0.24, 0, 0), Vector3(0.5, 0.1, 0.03), Props.RED)
		arm_sculpt.box(Vector3(0.4, 0, 0.002), Vector3(0.08, 0.1, 0.03), Props.CREAM)
		arm_sculpt.tube(Vector3(-0.07, 0, 0), 0.07, 0.07, 0.035, Props.YELLOW, 8, Basis(Vector3.RIGHT, PI * 0.5))
		var arm: MeshInstance3D = world._mesh(arm_sculpt.mesh(), mast + Vector3(0, 0.5, 0.06), paint)
		arm.name = "ToySignalArm%d" % branch
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		signals.append(arm)
	# Block tunnel over the right branch, just before its terminus.
	var tunnel := Vector3(10.02, YARD_TOP, -4.09)
	var along := Basis(Vector3.UP, -0.455)
	shapes.arch.add(tunnel + Vector3(0, 0.8, 0), Vector3(1.45, 1.6, 1.1), along, Props.ORANGE)
	shapes.roof.add(tunnel + Vector3(0, 1.86, 0), Vector3(1.65, 0.52, 1.25), along, Props.GREEN)
	for pier: float in [-1.0, 1.0]:
		shapes.box.add(tunnel + along * Vector3(pier * 0.94, 0.3, 0), Vector3(0.44, 0.6, 0.9), along, Props.BLUE)
		shapes.column.add(tunnel + along * Vector3(pier * 0.94, 0.82, 0), Vector3(0.38, 0.44, 0.38), along, Props.YELLOW)
	# Buffer stops: both termini and the end of the tail siding.
	for stop: Array in [[5.53, -5.34, 0.55], [10.83, -5.73, -0.455], [8.1, 1.8, 0.0]]:
		var turn := Basis(Vector3.UP, float(stop[2]))
		var foot := Vector3(float(stop[0]), YARD_TOP, float(stop[1]))
		for post: float in [-0.3, 0.3]:
			kit.detail.box(foot + turn * Vector3(post, 0.22, 0), Vector3(0.09, 0.44, 0.09), Props.DARK_WOOD, turn)
		for stripe in range(5):
			kit.detail.box(foot + turn * Vector3(-0.32 + 0.16 * float(stripe), 0.38, 0.05), Vector3(0.16, 0.16, 0.05), Props.RED if stripe % 2 == 0 else Props.CREAM, turn)
	# Lever desks in front of the yard; the points lever is the part that moves.
	for desk: Array in [[world.SWITCH.x, Props.RED], [world.TRAIN.x, Props.TEAL]]:
		var at := Vector3(float(desk[0]), _ground_y, 1.5)
		var tone: Color = desk[1]
		shapes.box.add(at + Vector3(0, 0.36, 0), Vector3(0.9, 0.72, 0.54), Basis.IDENTITY, Props.INK.lightened(0.14))
		shapes.box.add(at + Vector3(0, 0.78, 0), Vector3(1.04, 0.14, 0.66), Basis.IDENTITY, tone)
		kit.detail.box(at + Vector3(0, 0.44, 0.276), Vector3(0.6, 0.34, 0.02), Props.CREAM)
		kit.detail.tube(at + Vector3(0, 0.44, 0.29), 0.11, 0.11, 0.02, tone, 10, Basis(Vector3.RIGHT, PI * 0.5))
		var pad: Vector3 = (world.SWITCH if tone == Props.RED else world.TRAIN) + Vector3(0, 0.01, 0)
		kit.detail.tube(pad, 0.5, 0.5, 0.016, tone.lerp(Props.CREAM, 0.45), 16)
		kit.detail.tube(pad + Vector3(0, 0.004, 0), 0.38, 0.38, 0.016, Props.CREAM, 16)
		kit.blocker(at + Vector3(0, 0.65, 0), Vector3(0.95, 1.3, 0.6))
	var lever_sculpt := Kit.Sculpt.new()
	lever_sculpt.box(Vector3(0, 0.25, 0), Vector3(0.07, 0.5, 0.06), Props.BRASS)
	lever_sculpt.tube(Vector3(0, 0.54, 0), 0.08, 0.08, 0.14, Props.RED, 8)
	lever = world._mesh(lever_sculpt.mesh(), Vector3(world.SWITCH.x, _ground_y + 0.84, 1.5), paint)
	lever.name = "ToyPointsLever"
	# A wind-up key on the train desk, and the desk's two buttons.
	_add_key(Transform3D(Basis.IDENTITY, Vector3(world.TRAIN.x + 0.24, _ground_y + 0.5, 1.78)), 0.55)
	for button: float in [-0.2, 0.2]:
		kit.detail.tube(Vector3(world.TRAIN.x + button, _ground_y + 0.88, 1.5), 0.09, 0.09, 0.06, Props.GREEN if button < 0.0 else Props.RED, 8)
	kit.bunting(roof + Vector3(0.9, 0.1, -0.7), Vector3(board.x - 2.25, YARD_TOP + 2.0, board.z), Props.RAINBOW, 0.3)

## Small things on the open paving: the glass floor over the clockwork, the piano's
## base, the jack-in-the-box, the top's ring, jigsaw accents, lamps and the stand bays.
func _build_plaza() -> void:
	# Glass floor: a dark tray for toy_life's gears, a brass frame and the pane.
	kit.detail.box(GLASS_AT + Vector3(0, 0.008, 0), Vector3(2.6, 0.016, 2.6), Color("#2b3038"))
	for side: float in [-1.0, 1.0]:
		kit.detail.box(GLASS_AT + Vector3(side * 1.33, 0.06, 0), Vector3(0.12, 0.12, 2.78), Props.BRASS)
		kit.detail.box(GLASS_AT + Vector3(0, 0.06, side * 1.33), Vector3(2.78, 0.12, 0.12), Props.BRASS)
		for corner: float in [-1.0, 1.0]:
			kit.detail.tube(GLASS_AT + Vector3(side * 1.33, 0.13, corner * 1.33), 0.06, 0.06, 0.03, Props.BRASS.darkened(0.3), 6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.82, 0.9, 0.13)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.35
	glass.metallic_specular = 0.2
	world.material_cache["toy:glass"] = glass
	var pane_mesh := PlaneMesh.new()
	pane_mesh.size = Vector2(2.56, 2.56)
	var pane: MeshInstance3D = world._mesh(pane_mesh, GLASS_AT + Vector3(0, 0.115, 0), glass)
	pane.name = "ToyGlassFloor"
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Jack-in-the-box: the box is a block; toy_life owns the lid, spring and head.
	shapes.box.add(JACK_AT + Vector3(0, JACK_SIZE * 0.5, 0), Vector3.ONE * JACK_SIZE, Basis.IDENTITY, Props.RED)
	Props.stamp(kit.detail, "star", JACK_AT + Vector3(0, JACK_SIZE * 0.5, JACK_SIZE * 0.5 + 0.006), Vector3.RIGHT, Vector3.UP, 0.56, Props.YELLOW)
	kit.detail.tube(JACK_AT + Vector3(JACK_SIZE * 0.5 + 0.08, 0.5, 0.1), 0.035, 0.035, 0.18, Props.STEEL, 6, Basis(Vector3.BACK, PI * 0.5))
	kit.detail.box(JACK_AT + Vector3(JACK_SIZE * 0.5 + 0.17, 0.4, 0.1), Vector3(0.04, 0.24, 0.04), Props.STEEL)
	kit.detail.tube(JACK_AT + Vector3(JACK_SIZE * 0.5 + 0.22, 0.3, 0.1), 0.06, 0.06, 0.12, Props.YELLOW, 6, Basis(Vector3.BACK, PI * 0.5))
	kit.blocker(JACK_AT + Vector3(0, 0.65, 0), Vector3(JACK_SIZE, 1.3, JACK_SIZE))
	# The spinning top keeps to a painted ring.
	kit.detail.tube(TOP_AT + Vector3(0, 0.006, 0), 0.86, 0.86, 0.012, Props.CREAM, 20)
	kit.detail.tube(TOP_AT + Vector3(0, 0.01, 0), 0.72, 0.72, 0.012, Props.BLUE.lerp(Props.CREAM, 0.5), 20)
	kit.blocker(TOP_AT + Vector3(0, 0.65, 0), Vector3(0.9, 1.3, 0.9))
	# Jigsaw rugs: one welcomes visitors, the others mark the bays kept for new stands.
	var pastel: Array[Color] = [Props.PINK, Props.TEAL.lightened(0.3), Props.YELLOW.lerp(Props.CREAM, 0.3), Props.BLUE.lightened(0.3)]
	for piece in range(3):
		Props.jigsaw(kit.detail, Vector3(-1.02 + 1.02 * float(piece), _ground_y + 0.016, 8.55), 0.84, pastel[piece])
	for index in range(STAND_BAYS.size()):
		var center := STAND_BAYS[index].get_center()
		for piece in range(4):
			Props.jigsaw(kit.detail, Vector3(center.x - 0.42 + 0.86 * float(piece % 2), _ground_y + 0.016, center.y - 0.42 + 0.86 * float(piece >> 1)), 0.7, pastel[(piece + index) % 4])
	for post in LAMP_POSTS:
		kit.lamp_post(Vector3(post.x, _ground_y, post.y))
	Props.cube_stack(shapes, Vector3(-5.05, _ground_y, 7.55), ["heart", "star"], 0.5, 3)

## Behind the yard: the marble run and the toy-chest warehouse on the grass, and a
## block stair climbing the ridge to the houses on top.
func _build_back_lot() -> void:
	_build_marble_run(MARBLE_RUN_AT)
	Props.toy_chest(shapes, CHEST_AT, 3.2)
	_claim(CHEST_AT + Vector3(0, 0, -1.0), 3.8, 2.6)
	_claim(MARBLE_RUN_AT, 3.4, 1.6)
	var ridge: Array = KNOLLS[0]
	for step in range(8):
		var top := LAWN_Y + (float(ridge[4]) - LAWN_Y) * float(step + 1) / 8.0
		shapes.box.add(Vector3(0, (top - 0.3) * 0.5, -12.05 - 0.74 * float(step)), Vector3(2.0, top + 0.3, 0.76), Basis.IDENTITY, Props.RAINBOW[step % Props.RAINBOW.size()].lerp(Props.CREAM, 0.25))
	_claim(Vector3(0, 0, -14.6), 2.6, 6.4)
	kit.bunting(TOWER_AT + Vector3(1.2, 3.5, 0.9), MARBLE_RUN_AT + Vector3(-1.35, 3.6, 0.1), Props.RAINBOW, 0.45)

## Zigzag marble run facing +Z; records the path the marbles follow.
func _build_marble_run(at: Vector3) -> void:
	const HALF := 1.15
	const LEVELS := 5
	shapes.box.add(at + Vector3(0, 0.12, 0.1), Vector3(2.9, 0.24, 1.0), Basis.IDENTITY, Props.WOOD.darkened(0.1))
	shapes.box.add(at + Vector3(0, 1.85, -0.22), Vector3(2.5, 3.3, 0.1), Basis.IDENTITY, Props.CREAM)
	for side: float in [-1.0, 1.0]:
		shapes.column.add(at + Vector3(side * (HALF + 0.2), 1.85, -0.1), Vector3(0.26, 3.5, 0.26), Basis.IDENTITY, Props.RED if side < 0.0 else Props.BLUE)
		shapes.ball.add(at + Vector3(side * (HALF + 0.2), 3.7, -0.1), Vector3.ONE * 0.36, Basis.IDENTITY, Props.YELLOW)
	shapes.box.add(at + Vector3(0, 3.52, -0.1), Vector3(2.9, 0.16, 0.3), Basis.IDENTITY, Props.YELLOW)
	for level in range(LEVELS):
		var high := -1.0 if level % 2 == 0 else 1.0
		var y := 3.02 - 0.56 * float(level)
		var tilt := Basis(Vector3.BACK, high * 0.13)
		var ramp := at + Vector3(0, y, 0.1)
		shapes.box.add(ramp, Vector3(HALF * 1.86, 0.07, 0.42), tilt, Props.RAINBOW[level])
		kit.detail.box(ramp + tilt * Vector3(0, 0.07, 0.2), Vector3(HALF * 1.86, 0.1, 0.035), Props.CREAM, tilt)
		marble_path.append(ramp + tilt * Vector3(high * HALF * 0.86, 0.15, 0))
		marble_path.append(ramp + tilt * Vector3(-high * HALF * 0.86, 0.15, 0))
	var last := marble_path[marble_path.size() - 1]
	marble_path.append(Vector3(last.x, at.y + 0.36, last.z))
	marble_path.append(at + Vector3(0, 0.36, 0.1))
	kit.detail.box(at + Vector3(0, 0.3, 0.52), Vector3(2.6, 0.12, 0.05), Props.CREAM)

## Castle gate on the road home, with its name board and the masts for its flags.
func _build_gate() -> void:
	var masts := Props.castle_gate(shapes, GATE_AT + Vector3(0, 0.1, 0))
	flags.add(masts[0], Vector3.ONE, Basis.IDENTITY, Props.YELLOW)
	flags.add(masts[1], Vector3.ONE, Basis.IDENTITY, Props.RED)
	_claim(GATE_AT, 9.0, 3.0)
	# The town's name stays readable from the entrance, well past the local sign range.
	var label: Label3D = world._label("發條玩具城", GATE_AT + Vector3(0, 3.1, 0.75), 30, Props.CREAM)
	label.visibility_range_end = 0.0
	shapes.box.add(GATE_AT + Vector3(0, 3.1, 0.58), Vector3(3.4, 0.56, 0.1), Basis.IDENTITY, Props.BLUE.darkened(0.3))
	kit.bunting(GATE_AT + Vector3(-2.4, 2.75, 0.5), GATE_AT + Vector3(2.4, 2.75, 0.5), Props.RAINBOW, 0.3)
	# Keep the soldiers' posts and patrol lanes, and the kite flyers' spots, free of trees.
	for lane: Array in [[-8.3, 10.6, 7.4, 1.6], [8.3, 10.6, 7.4, 1.6], [0.0, 10.4, 9.4, 1.6]]:
		_claim(Vector3(float(lane[0]), 0, float(lane[1])), float(lane[2]), float(lane[3]))
	for kite: Array in KITES:
		Props.crayon(shapes, kite[0], 0.7, Props.RED, Basis(Vector3.BACK, 0.25))
		_claim(kite[0], 2.0, 2.0)
	for wheel: Array in PINWHEELS:
		var foot := _lawn(float(wheel[0]), float(wheel[1]))
		kit.detail.tube(foot + Vector3(0, float(wheel[2]) * 0.5, 0), 0.035, 0.035, float(wheel[2]), Props.CREAM, 6)
		pinwheels.append(foot + Vector3(0, float(wheel[2]), 0.06))
		_claim(foot, 1.6, 1.6)

## Houses on the lawn and the hills, the carousel's drum and the ring stacker.
func _build_town() -> void:
	for row: Array in TOWN:
		var at := _lawn(float(row[0]), float(row[1]))
		# Houses stand a little askew, as a child would set them down.
		var yaw := (_scatter(float(row[0]) * 1.7 + float(row[1]) * 0.9) - 0.5) * 0.5
		_add_key(Props.house(shapes, at, {"w": float(row[2]), "d": float(row[3]), "h": float(row[4]), "body": row[5], "roof": row[6], "roof_kind": row[7], "windows": row[8], "chimney": row[9], "key": row[10], "yaw": yaw}))
		_claim(at, float(row[2]) + 1.0, float(row[3]) + 1.0)
	# Music-box carousel: the drum and its crank stand still, toy_life turns the rest.
	var drum := CAROUSEL_AT
	kit.detail.tube(drum + Vector3(0, 0.16, 0), 2.25, 2.15, 0.32, Props.CREAM, 20)
	kit.detail.tube(drum + Vector3(0, 0.12, 0), 2.28, 2.28, 0.1, Props.RED, 20)
	for bulb in range(14):
		var turn := Basis(Vector3.UP, TAU * float(bulb) / 14.0)
		kit.glow.box(drum + turn * Vector3(1.98, 0.36, 0), Vector3(0.12, 0.1, 0.12), Props.WINDOW, turn)
	kit.detail.tube(drum + Vector3(1.0, 0.2, 2.26), 0.05, 0.05, 0.3, Props.STEEL, 6, Basis(Vector3.RIGHT, PI * 0.5))
	kit.detail.box(drum + Vector3(1.0, 0.36, 2.42), Vector3(0.05, 0.36, 0.05), Props.STEEL)
	kit.detail.tube(drum + Vector3(1.0, 0.54, 2.5), 0.07, 0.07, 0.16, Props.YELLOW, 6, Basis(Vector3.RIGHT, PI * 0.5))
	_claim(drum, 5.4, 5.4)
	# Ring stacker on the north-east knoll.
	var stacker := _lawn(21.6, -18.6)
	shapes.column.add(stacker + Vector3(0, 0.1, 0), Vector3(2.3, 0.2, 2.3), Basis.IDENTITY, Props.WOOD)
	for ring in range(6):
		var radius := 1.0 - 0.1 * float(ring)
		shapes.column.add(stacker + Vector3(0, 0.42 + 0.44 * float(ring), 0), Vector3(radius * 2.0, 0.4, radius * 2.0), Basis.IDENTITY, Props.RAINBOW[ring])
	shapes.ball.add(stacker + Vector3(0, 3.06, 0), Vector3.ONE * 0.6, Basis.IDENTITY, Props.CREAM)
	_claim(stacker, 3.2, 3.2)

## Toy trees, hedges, flowers, the crayon fence and a few painted trees at the far
## corners. Anything south of the yard stays low enough not to cover the walker.
func _build_planting() -> void:
	# Crayon fence down the east side, pencils along the south, hedges to the west.
	var bay := STAND_BAYS[1]
	for index in range(15):
		var z := -3.45 + 0.82 * float(index)
		if z > bay.position.y - 0.4 and z < bay.end.y + 0.4: continue
		var lean := Basis(Vector3.RIGHT, (_scatter(float(index) * 2.1) - 0.5) * 0.16) * Basis(Vector3.BACK, (_scatter(float(index) * 5.3) - 0.5) * 0.12)
		Props.crayon(shapes, Vector3(12.62, LAWN_Y, z), 1.0 + 0.3 * _scatter(float(index) * 1.3), Props.RAINBOW[index % Props.RAINBOW.size()], lean)
	for index in range(7):
		var lean := Basis(Vector3.BACK, (_scatter(float(index) * 3.1) - 0.5) * 0.24)
		Props.crayon(shapes, Vector3(5.1 + 1.08 * float(index) + 0.3 * _scatter(float(index) * 7.7), LAWN_Y, 8.82), 0.52 + 0.2 * _scatter(float(index) * 4.3), Props.YELLOW, lean, true)
	shapes.box.add(Vector3(-8.5, LAWN_Y + 0.26, 8.98), Vector3(6.4, 0.52, 0.56), Basis.IDENTITY, Props.LEAF)
	for finial: float in [-11.9, -5.1]:
		shapes.ball.add(Vector3(finial, LAWN_Y + 0.42, 8.98), Vector3.ONE * 0.84, Basis.IDENTITY, Props.LEAF_LIGHT)
	shapes.box.add(Vector3(-12.72, LAWN_Y + 0.3, 6.2), Vector3(0.56, 0.6, 3.6), Basis.IDENTITY, Props.LEAF_DARK)
	# Toy trees on a jittered grid, skipping the yard, the road, slopes and buildings.
	var yard: Rect2 = world.BOUNDS.grow(1.5)
	var greens: Array[Color] = [Props.LEAF, Props.LEAF_DARK, Props.LEAF_LIGHT, Props.TEAL]
	for column in range(-10, 11):
		for row in range(-9, 10):
			var seed_value := float(column) * 7.3 + float(row) * 13.1
			if _scatter(seed_value) > 0.42: continue
			var spot := Vector2(float(column) * 3.0 + (_scatter(seed_value + 1.0) - 0.5) * 2.2, float(row) * 3.0 + (_scatter(seed_value + 2.0) - 0.5) * 2.2)
			if yard.has_point(spot) or (absf(spot.x) < 3.6 and spot.y > 8.0) or on_slope(spot): continue
			if _footprints.any(func(taken: Rect2) -> bool: return taken.grow(0.9).has_point(spot)): continue
			var height := 1.7 + 1.5 * _scatter(seed_value + 3.0)
			# South of the yard a tree must not reach up across the paving behind it.
			if spot.y > 8.0 and absf(spot.x) < 14.0:
				height = minf(height, (spot.y - 8.6) / 1.5)
			if height < 1.0: continue
			Props.toy_tree(shapes, _lawn(spot.x, spot.y), height, "ball" if _scatter(seed_value + 4.0) > 0.55 else "cone", greens[int(_scatter(seed_value + 5.0) * 3.99)])
			_claim(Vector3(spot.x, 0, spot.y), 1.0, 1.0)
	# Flowers dot the lawn near the yard.
	for flower in range(90):
		var seed_value := float(flower) * 4.9 + 0.7
		var spot := Vector2((_scatter(seed_value) - 0.5) * 44.0, (_scatter(seed_value + 1.0) - 0.5) * 40.0)
		if world.BOUNDS.grow(0.5).has_point(spot) or (absf(spot.x) < 2.8 and spot.y > 8.0) or on_slope(spot): continue
		if YARD_BED.grow(0.4).has_point(spot) or _footprints.any(func(taken: Rect2) -> bool: return taken.has_point(spot)): continue
		var at := _lawn(spot.x, spot.y)
		kit.posts().add(at + Vector3(0, 0.1, 0), Vector3(0.03, 0.2, 0.03), Basis.IDENTITY, Props.LEAF_DARK)
		kit.posts().add(at + Vector3(0, 0.22, 0), Vector3(0.17, 0.05, 0.17), Basis.IDENTITY, [Props.CREAM, Props.YELLOW, Props.PINK, Props.RED][flower % 4])
	for tree: Array in WOODS:
		if not world.dresses(Vector2(float(tree[1]), float(tree[2]))): continue
		kit.billboard(str(tree[0]), Vector3(float(tree[1]), LAWN_Y, float(tree[2])), float(tree[3]))
