extends RefCounted
## Everything in the candy factory that moves: dough and wrapped sweets riding the two
## conveyor lines, the cookie press, gears, the canal paddle wheel, kettle bubbles,
## tumbling gumballs, the bubbles over the mooring and a sample dispenser that pops a
## sweet when the player walks up. Nothing here is saved or scored, and the
## reduced-motion pose is one still frame.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/candy_props.gd")
const Scenery := preload("res://game/world/candy_scenery.gd")
const BELT_SPEED := 0.55
const SLAT_SPACING := 0.42
const DOUGH_SPACING := 1.15
const SWEET_SPACING := 0.8
const PRESS_LIFT := 0.72
const PRESS_REACH := 0.24
const DISPENSER_REACH := 2.4
## The player has to step this far away before the dispenser pops again.
const DISPENSER_REARM := 3.4
const POP_SECONDS := 1.1
const POP_HEIGHT := 1.3
const GUMBALL_COUNT := 46
const GUMBALL_NOTICE := 6.5
## Gears: x, y, z, diameter, radians per second, tint. Neighbours mesh.
const GEARS := [
	[-5.75, 2.4, Scenery.HALL_FACE_Z + 0.22, 1.4, 0.7, "#c98d5e"], [-4.72, 3.05, Scenery.HALL_FACE_Z + 0.22, 0.85, -1.15, "#f9da7c"],
	[-5.4, 3.5, Scenery.PRESS_Z + 0.35, 0.75, 1.3, "#c98d5e"], [-4.72, 3.42, Scenery.PRESS_Z + 0.35, 0.5, -1.95, "#a3dfc8"],
	[-5.35, 1.0, -5.4, 0.62, 1.1, "#f9da7c"], [-4.75, 0.82, -5.4, 0.46, -1.48, "#c98d5e"],
	[-5.4, 1.2, 17.9, 0.7, -1.0, "#c98d5e"], [-4.7, 0.98, 17.9, 0.5, 1.4, "#f4a3bb"],
]
## Marshmallows drifting down the river: start z, lane across the stream (0 to 1), tint.
const RAFTS := [[-26.0, 0.3, "#ffffff"], [-17.0, 0.7, "#ffd9e4"], [-8.0, 0.45, "#ffffff"], [1.0, 0.75, "#fff0c2"], [9.0, 0.3, "#ffd9e4"], [17.0, 0.6, "#ffffff"], [26.0, 0.4, "#d9f2ff"]]
const RAFT_SPEED := 0.45
const RAFT_FROM := -34.0
const RAFT_SPAN := 70.0
## Bubbles over the mooring: offset from the basin, radius.
const FLOATERS := [[0.0, 1.5, 0.0, 0.62], [0.75, 2.2, 0.15, 0.48], [-0.6, 2.5, -0.25, 0.4], [0.2, 3.1, 0.3, 0.3]]

var world: Node3D
var scenery: Scenery
## How many times the dispenser has popped since the district was built.
var pops := 0
var press_head: MeshInstance3D
var paddle_wheel: MeshInstance3D
var sample: MeshInstance3D
var gumballs: MultiMeshInstance3D
var _slats: MultiMesh
var _dough: MultiMesh
var _sweets: MultiMesh
var _gears: MultiMesh
var _bubbles: MultiMesh
var _floaters: MultiMesh
var _rafts: MultiMesh
var _baking_count := 0
var _dough_count := 0
var _dough_raw := Color("#f6e2b8").srgb_to_linear()
var _dough_baked := Color("#dba765").srgb_to_linear()
var _press_rest := Vector3.ZERO
var _pop_elapsed := -1.0
var _armed := true
var _tumble := 0.0
var _tumble_speed := 0.0
var _posed_still := false

func _init(owner: Node3D, candy_scenery: Scenery) -> void:
	world = owner
	scenery = candy_scenery

func build() -> void:
	var paint: Material = world._vertex_color_material("scenery-detail")
	var glaze: Material = world._vertex_color_material("candy-gloss", 0.22)
	var baking: Array = Scenery.BAKING_LINE
	var packing: Array = Scenery.PACKING_LINE
	_baking_count = roundi((float(baking[3]) - float(baking[2])) / SLAT_SPACING)
	var packing_count := roundi((float(packing[3]) - float(packing[2])) / SLAT_SPACING)
	_slats = _batch(Props.slat_mesh(1.0), _plain(_baking_count + packing_count), paint, "ConveyorSlats").multimesh
	_dough_count = roundi((float(baking[3]) - float(baking[2])) / DOUGH_SPACING)
	_dough = _batch(Props.dough_mesh(), _plain(_dough_count), paint, "ConveyorDough").multimesh
	var wrappers: Array[Color] = []
	for index in range(roundi((float(packing[3]) - float(packing[2])) / SWEET_SPACING)):
		wrappers.append(Props.SWEETS[(index * 5) % Props.SWEETS.size()])
	_sweets = _batch(Props.sweet_mesh(), wrappers, glaze, "ConveyorSweets").multimesh
	var gear_tints: Array[Color] = []
	for gear: Array in GEARS:
		gear_tints.append(Color(str(gear[5])))
	_gears = _batch(Props.gear_mesh(), gear_tints, paint, "FactoryGears").multimesh
	_press_rest = Vector3(Scenery.CONVEYOR_X, Scenery.BELT_Y + 0.2, Scenery.PRESS_Z)
	press_head = world._mesh(Props.press_head_mesh(), _press_rest, paint)
	press_head.name = "CookiePressHead"
	paddle_wheel = world._mesh(_wheel_mesh(), Scenery.WHEEL_AT + Vector3(0, 0.62, 0), paint)
	paddle_wheel.name = "CanalPaddleWheel"
	# Three bubbles swell and burst on each kettle.
	var froth: Array[Color] = []
	for vat: Array in Scenery.VATS:
		for bubble in range(3):
			froth.append(Color(str(vat[2])).lightened(0.3))
	var dome := Kit.Sculpt.new()
	dome.ball(Vector3.ZERO, 0.5, Color.WHITE, Color.TRANSPARENT, 8, 3, 0.9, true)
	_bubbles = _batch(dome.mesh(), froth, glaze, "KettleBubbles").multimesh
	var ball := Kit.Sculpt.new()
	ball.ball(Vector3.ZERO, 0.2, Color.WHITE, Color.TRANSPARENT, 8, 4)
	var gumball_tints: Array[Color] = []
	var gumball_spots: Array[Transform3D] = []
	var inner := scenery.globe_radius - 0.24
	for index in range(GUMBALL_COUNT):
		var height := lerpf(-0.86, 0.12, float(index) / float(GUMBALL_COUNT - 1)) * inner
		var reach := sqrt(inner * inner - height * height) * sqrt(_scatter(float(index) * 3.7))
		gumball_spots.append(Transform3D(Basis.IDENTITY, Basis(Vector3.UP, 2.4 * float(index)) * Vector3(reach, height, 0)))
		gumball_tints.append(Props.SWEETS[index % Props.SWEETS.size()].srgb_to_linear())
	gumballs = world._multi_mesh(ball.mesh(), scenery.globe_centre, gumball_spots, gumball_tints, glaze)
	gumballs.name = "GumballTumble"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var floaters := _batch(sphere, _plain(FLOATERS.size()), world._bubble_material(), "MooringBubbles")
	floaters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floaters = floaters.multimesh
	var raft_tints: Array[Color] = []
	for raft: Array in RAFTS:
		raft_tints.append(Color(str(raft[2])))
	_rafts = _batch(Props.marshmallow_mesh(), raft_tints, paint, "RiverMarshmallows").multimesh
	sample = world._mesh(Props.sweet_mesh(Props.RED), scenery.sample_cup, glaze)
	sample.scale = Vector3.ONE * 1.35
	sample.name = "DispenserSample"

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	_pop_elapsed = -1.0
	if not _posed_still: _pose(true)

func animate(delta: float) -> void:
	_pose(false)
	_react(delta)

## How far the dispenser's sample is above its cup right now.
func sample_height() -> float:
	return sample.position.y - scenery.sample_cup.y

## Where dough ball `index` is along the baking line and whether the press has flattened it.
func dough_state(index: int) -> Dictionary:
	var z := _along(Scenery.BAKING_LINE, index, _dough_count, (0.0 if _posed_still else float(world.time)) * BELT_SPEED)
	return {"z": z, "pressed": z > Scenery.PRESS_Z}

## How far the press head has come down from its raised position.
func press_drop() -> float:
	return _press_rest.y + PRESS_LIFT - press_head.position.y

func _plain(count: int) -> Array[Color]:
	var colors: Array[Color] = []
	colors.resize(count)
	colors.fill(Color.WHITE)
	return colors

## One multimesh whose instances are posed every frame; tints are sRGB swatches.
func _batch(mesh: Mesh, tints: Array[Color], material: Material, node_name: String) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for tint in tints:
		transforms.append(Transform3D.IDENTITY)
		colors.append(tint.srgb_to_linear())
	var instance: MultiMeshInstance3D = world._multi_mesh(mesh, Vector3.ZERO, transforms, colors, material)
	instance.name = node_name
	# Instances are posed far from where the batch was created.
	instance.custom_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 16, 80))
	return instance

## Position along a line for item `index` of `count`; items wrap from the far hood to the near one.
func _along(line: Array, index: int, count: int, travel: float) -> float:
	var span := float(line[3]) - float(line[2])
	return float(line[2]) + fposmod(travel + span * float(index) / float(count), span)

func _pose(still: bool) -> void:
	_posed_still = still
	var time: float = 0.0 if still else float(world.time)
	var travel := time * BELT_SPEED
	var baking: Array = Scenery.BAKING_LINE
	var packing: Array = Scenery.PACKING_LINE
	var slat_count := _slats.instance_count
	for index in range(slat_count):
		var slat_z := _along(baking, index, _baking_count, travel) if index < _baking_count else _along(packing, index - _baking_count, slat_count - _baking_count, travel)
		_slats.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(Scenery.CONVEYOR_X, Scenery.BELT_Y - 0.01, slat_z)))
	var nearest := INF
	for index in range(_dough_count):
		var dough_z := _along(baking, index, _dough_count, travel)
		var pressed := dough_z > Scenery.PRESS_Z
		nearest = minf(nearest, absf(dough_z - Scenery.PRESS_Z))
		var shape := Vector3(1.4, 0.32, 1.4) if pressed else Vector3.ONE
		_dough.set_instance_transform(index, Transform3D(Basis(Vector3.UP, 1.3 * float(index)).scaled(shape), Vector3(Scenery.CONVEYOR_X, Scenery.BELT_Y + 0.02, dough_z)))
		_dough.set_instance_color(index, _dough_baked if pressed else _dough_raw)
	# The head comes down as each ball of dough passes under it.
	var drop := 0.0 if still else 1.0 - smoothstep(0.0, PRESS_REACH, nearest)
	press_head.position.y = _press_rest.y + PRESS_LIFT * (1.0 - drop)
	var sweet_count := _sweets.instance_count
	for index in range(sweet_count):
		var sweet_z := _along(packing, index, sweet_count, travel)
		_sweets.set_instance_transform(index, Transform3D(Basis(Vector3.UP, 0.9 * float(index) + 0.4), Vector3(Scenery.CONVEYOR_X + 0.18 * sin(float(index) * 2.1), Scenery.BELT_Y + 0.15, sweet_z)))
	for index in range(GEARS.size()):
		var gear: Array = GEARS[index]
		var gear_size := float(gear[3])
		_gears.set_instance_transform(index, Transform3D(Basis(Vector3.BACK, time * float(gear[4]) + float(index)).scaled(Vector3(gear_size, gear_size, 1.0)), Vector3(float(gear[0]), float(gear[1]), float(gear[2]))))
	paddle_wheel.rotation.z = -time * 0.9
	for index in range(_bubbles.instance_count):
		var surface: Vector3 = scenery.vat_surfaces[floori(float(index) / 3.0)]
		var life := 0.45 if still else fposmod(time * (0.42 + 0.07 * float(index % 3)) + 0.37 * float(index), 1.0)
		var bubble_size := (0.12 + 0.3 * smoothstep(0.0, 0.75, life)) * (1.0 if life < 0.8 else 0.0)
		var spot := Basis(Vector3.UP, 2.1 * float(index)) * Vector3(0.48, 0, 0)
		_bubbles.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * bubble_size * 2.0), surface + spot))
	for index in range(FLOATERS.size()):
		var floater: Array = FLOATERS[index]
		var bob := 0.0 if still else sin(time * 0.8 + 1.7 * float(index)) * 0.14
		var sway := 0.0 if still else sin(time * 0.5 + 2.3 * float(index)) * 0.1
		_floaters.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * float(floater[3]) * 2.0), Scenery.BASIN_AT + Vector3(float(floater[0]) + sway, float(floater[1]) + bob, float(floater[2]))))
	for index in range(RAFTS.size()):
		var raft: Array = RAFTS[index]
		var raft_z := RAFT_FROM + fposmod(float(raft[0]) - RAFT_FROM + time * RAFT_SPEED, RAFT_SPAN)
		var lane := float(raft[1]) + (0.0 if still else 0.08 * sin(time * 0.4 + float(index)))
		var bob := 0.0 if still else 0.02 * sin(time * 1.4 + 2.0 * float(index))
		_rafts.set_instance_transform(index, Transform3D(Basis(Vector3.UP, time * 0.3 + float(index)), Vector3(lerpf(Scenery.river_left(raft_z), Scenery.river_right(raft_z), lane), Scenery.SYRUP_Y + bob, raft_z)))
	if still:
		_tumble = 0.0
		_tumble_speed = 0.0
		gumballs.rotation.y = 0.0
		sample.position = scenery.sample_cup
		sample.rotation = Vector3.ZERO

## The parts that answer the player: the gumballs tumble faster when someone comes to
## look, and the dispenser pops a sample for whoever walks up to it.
func _react(delta: float) -> void:
	var player: Node3D = world.player
	if not is_instance_valid(player): return
	var spot: Vector3 = world.player_spot()
	var here := Vector2(spot.x, spot.z)
	var watched := here.distance_to(Vector2(scenery.globe_centre.x, scenery.globe_centre.z)) < GUMBALL_NOTICE
	_tumble_speed = move_toward(_tumble_speed, 1.5 if watched else 0.12, delta * 1.2)
	_tumble += _tumble_speed * delta
	gumballs.rotation.y = _tumble
	var distance := here.distance_to(Vector2(Scenery.DISPENSER_AT.x, Scenery.DISPENSER_AT.z))
	if _pop_elapsed < 0.0:
		if distance > DISPENSER_REARM:
			_armed = true
		elif _armed and distance < DISPENSER_REACH:
			_armed = false
			_pop_elapsed = 0.0
			pops += 1
		return
	_pop_elapsed += delta
	var flight := minf(_pop_elapsed / POP_SECONDS, 1.0)
	sample.position = scenery.sample_cup + Vector3(0, POP_HEIGHT * 4.0 * flight * (1.0 - flight), 0)
	sample.rotation = Vector3(flight * TAU * 2.0, flight * TAU, 0)
	if flight >= 1.0:
		_pop_elapsed = -1.0
		sample.rotation = Vector3.ZERO

func _wheel_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(Vector3.ZERO, 0.12, 0.12, 1.7, Props.STEEL, 8, face_on)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(0, 0, side * 0.5), 0.9, 0.9, 0.08, Props.PINK, 12, face_on)
		sculpt.tube(Vector3(0, 0, side * 0.53), 0.66, 0.66, 0.06, Props.CREAM, 12, face_on)
		sculpt.tube(Vector3(0, 0, side * 0.55), 0.2, 0.2, 0.06, Props.RED, 8, face_on)
	for paddle in range(8):
		var turn := Basis(Vector3.BACK, TAU * float(paddle) / 8.0)
		sculpt.box(turn * Vector3(0, 0.8, 0), Vector3(0.07, 0.4, 0.94), Props.WAFER if paddle % 2 == 0 else Props.CREAM, turn)
	return sculpt.mesh()

func _scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)
