extends Node3D
## The toy railway: one dock, a fork and two spurs. The routing, speeds and stops
## are plain numbers in this node's own space, so the world may place and scale the
## whole layout without touching how the train runs.

const Kit := preload("res://game/world/scenery_kit.gd")
const DOCK := Vector3(0, 0.10, 1.62)
const FORK := Vector3(0, 0.10, 0.58)
const SPEED := 1.24
const END_HOLD := 0.42
const EPSILON := 0.001
const SPURS := [
	[Vector3(-0.33, 0.10, 0.00), Vector3(-1.14, 0.10, -0.72), Vector3(-1.67, 0.10, -1.58)],
	[Vector3(0.40, 0.10, 0.02), Vector3(1.24, 0.10, -0.63), Vector3(1.84, 0.10, -1.85)],
]
const BRASS := Color("#c99b50")
const IRON := Color("#2b3440")
const STEEL := Color("#b0a99b")
const WOOD := Color("#6b5143")
const RED := Color("#c9503f")
const GREEN := Color("#3f8f7f")
const PANE := Color("#ffe9ae")
## Wagons follow this far behind the engine; at the dock they stand on the tail siding.
const WAGON_OFFSETS := [0.8, 1.38]
const TAIL_LENGTH := 1.76
const RAIL_Y := 0.032
const WHEEL_RADIUS := 0.088
const DRIVE_WHEELS := [-0.26, -0.02, 0.22]
const CRANK := 0.045
const PUFF_COUNT := 5
const PUFF_SIZE := 0.27

var branch := 0
var running := false
var reduced_motion := false
var outbound := true
var distance := 0.0
var _hold_remaining := 0.0
var _curves: Array[Curve3D] = []
var _waypoints: Array[PackedFloat32Array] = []
var _branch_rails: Array[MeshInstance3D] = []
var _train: MeshInstance3D
var _wagons: Array[MeshInstance3D] = []
var _rods: Array[MeshInstance3D] = []
var _wheels: MultiMesh
## Per wheel: vehicle (-1 is the engine), rest position on it and size.
var _wheel_rests: Array[Array] = []
var _puffs: MultiMesh
var _puff_clock := 0.0
var _materials: Dictionary = {}
var _selected_rails: StandardMaterial3D
var _idle_rails: StandardMaterial3D


func _ready() -> void:
	_selected_rails = _material(Color("#ffe09e"))
	_idle_rails = _material(STEEL)
	for stops in SPURS:
		var path := _make_path(stops)
		_curves.append(path)
		_waypoints.append(PackedFloat32Array([0.0, path.get_closest_offset(FORK), path.get_closest_offset(stops[1]), path.get_baked_length()]))
	var common := PackedVector3Array([DOCK + Vector3(0, 0, TAIL_LENGTH), FORK])
	_build_rails("SharedRails", common, _material(BRASS))
	for index in _curves.size():
		var route := PackedVector3Array([FORK])
		for location in _curves[index].get_baked_points():
			if location.z < FORK.z - EPSILON:
				route.append(location)
		_branch_rails.append(_build_rails("BranchRails%d" % index, route, _idle_rails))
	_build_sleepers()
	_build_train()
	reset()


func _make_path(stops: Array) -> Curve3D:
	var anchors: Array[Vector3] = [DOCK, FORK]
	anchors.append_array(stops)
	var path := Curve3D.new()
	path.bake_interval = 0.09
	for index in anchors.size():
		var location := anchors[index]
		if index == 0 or index == anchors.size() - 1:
			path.add_point(location)
			continue
		var prev := location - anchors[index - 1]
		var follow := anchors[index + 1] - location
		var direction := Vector3.FORWARD if index == 1 else (prev.normalized() + follow.normalized()).normalized()
		var handle := direction * minf(prev.length(), follow.length()) * 0.25
		path.add_point(location, -handle, handle)
	return path


func _build_rails(label: String, points: PackedVector3Array, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rail in [-0.18, 0.18]:
		for index in range(1, points.size()):
			var first := points[index - 1]
			var last := points[index]
			var delta := last - first
			if delta.length_squared() < EPSILON * EPSILON:
				continue
			var across := delta.normalized().cross(Vector3.UP)
			var left := across * (float(rail) - 0.032)
			var right := across * (float(rail) + 0.032)
			for point: Vector3 in [first + left, last + left, last + right, first + left, last + right, first + right]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(point)
	var rail_mesh := _mesh(self, label, surface.commit(), Vector3.ZERO, material)
	rail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return rail_mesh


func _build_sleepers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.58, 0.052, 0.12)
	var rests: Array[Transform3D] = []
	for index in _curves.size():
		var route := _curves[index]
		var start := 0.17 if index == 0 else route.get_closest_offset(FORK) + 0.22
		var limit := route.get_baked_length()
		for sleeper in ceili((limit - start) / 0.31):
			var path_to_sleeper := start + float(sleeper) * 0.31
			var at := route.sample_baked(path_to_sleeper)
			at.y = 0.057
			var heading := _heading(route, path_to_sleeper)
			rests.append(Transform3D(Basis(Vector3.UP, heading), at))
	for sleeper in range(ceili(TAIL_LENGTH / 0.31)):
		rests.append(Transform3D(Basis.IDENTITY, Vector3(DOCK.x, 0.057, DOCK.z + 0.14 + 0.31 * float(sleeper))))
	var bolts := _crowd("WoodSleepers", mesh, rests.size(), _material(WOOD))
	for index in rests.size():
		bolts.set_instance_transform(index, rests[index])


func _build_train() -> void:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.6
	_train = _mesh(self, "ClockworkLocomotive", _locomotive_mesh(), Vector3.ZERO, paint)
	_train.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for side: float in [-1.0, 1.0]:
		var rod := Kit.Sculpt.new()
		rod.box(Vector3.ZERO, Vector3(0.016, 0.03, 0.52), STEEL)
		_rods.append(_mesh(_train, "ConnectingRod", rod.mesh(), Vector3(side * 0.246, WHEEL_RADIUS, DRIVE_WHEELS[1]), paint))
	for index in range(WAGON_OFFSETS.size()):
		_wagons.append(_mesh(self, "CargoWagon%d" % index, _wagon_mesh(index), Vector3.ZERO, paint))
		_wagons[index].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for z: float in DRIVE_WHEELS:
		for side: float in [-1.0, 1.0]:
			_wheel_rests.append([-1, Vector3(side * 0.2, WHEEL_RADIUS, z), 1.0])
	for index in range(WAGON_OFFSETS.size()):
		for z: float in [-0.15, 0.15]:
			for side: float in [-1.0, 1.0]:
				_wheel_rests.append([index, Vector3(side * 0.2, WHEEL_RADIUS * 0.8, z), 0.8])
	_wheels = _crowd("TrainWheels", _wheel_mesh(), _wheel_rests.size(), paint)
	var cloud := SphereMesh.new()
	cloud.radius = PUFF_SIZE * 0.5
	cloud.height = PUFF_SIZE
	cloud.radial_segments = 8
	cloud.rings = 4
	var steam := StandardMaterial3D.new()
	steam.albedo_color = Color("#fff8ea")
	steam.roughness = 1.0
	_puffs = _crowd("FunnelPuffs", cloud, PUFF_COUNT, steam)
	_hide_puffs()


## Clockwork tank engine facing -Z: boiler, funnel and dome, cab with its wind-up key.
func _locomotive_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var lengthwise := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.box(Vector3(0, 0.16, 0), Vector3(0.44, 0.06, 0.88), IRON)
	sculpt.box(Vector3(0, 0.1, -0.5), Vector3(0.42, 0.06, 0.16), RED, Basis(Vector3.RIGHT, -0.5))
	sculpt.tube(Vector3(0, 0.37, -0.16), 0.175, 0.175, 0.48, GREEN, 12, lengthwise)
	for band: float in [-0.3, -0.06]:
		sculpt.tube(Vector3(0, 0.37, band), 0.182, 0.182, 0.035, BRASS, 12, lengthwise)
	sculpt.tube(Vector3(0, 0.37, -0.42), 0.18, 0.15, 0.05, IRON, 12, lengthwise)
	sculpt.box(Vector3(0, 0.37, -0.452), Vector3(0.09, 0.09, 0.02), PANE)
	sculpt.tube(Vector3(0, 0.6, -0.3), 0.05, 0.075, 0.16, IRON, 8)
	sculpt.tube(Vector3(0, 0.69, -0.3), 0.09, 0.09, 0.03, BRASS, 8)
	sculpt.tube(Vector3(0, 0.575, -0.08), 0.075, 0.03, 0.09, BRASS, 8)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.2, 0.3, -0.14), Vector3(0.06, 0.16, 0.44), GREEN.darkened(0.18))
		sculpt.box(Vector3(side * 0.226, 0.5, 0.24), Vector3(0.012, 0.14, 0.16), PANE)
		sculpt.box(Vector3(side * 0.12, 0.5, 0.064), Vector3(0.1, 0.12, 0.012), PANE)
	sculpt.box(Vector3(0, 0.4, 0.24), Vector3(0.44, 0.4, 0.34), RED)
	sculpt.box(Vector3(0, 0.625, 0.24), Vector3(0.52, 0.05, 0.42), IRON)
	sculpt.box(Vector3(0, 0.66, 0.24), Vector3(0.4, 0.03, 0.36), IRON.lightened(0.12))
	sculpt.box(Vector3(0, 0.5, 0.412), Vector3(0.26, 0.14, 0.012), PANE)
	# The key that drives it sticks out of the cab's back wall.
	sculpt.tube(Vector3(0, 0.33, 0.44), 0.025, 0.025, 0.08, BRASS, 6, lengthwise)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(side * 0.07, 0.33, 0.48), 0.06, 0.06, 0.02, BRASS, 8, lengthwise)
	sculpt.box(Vector3(0, 0.15, 0.47), Vector3(0.08, 0.05, 0.08), IRON)
	return sculpt.mesh()


## Open wagon with a cargo of toy blocks; `variation` picks the load.
func _wagon_mesh(variation: int) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var paints: Array[Color] = [Color("#4d8fc6"), Color("#f2c84f"), RED, Color("#69ad6a")]
	var planks := Color("#c88c58")
	sculpt.box(Vector3(0, 0.15, 0), Vector3(0.42, 0.05, 0.5), IRON)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.2, 0.24, 0), Vector3(0.03, 0.14, 0.5), planks)
		sculpt.box(Vector3(0, 0.24, side * 0.24), Vector3(0.4, 0.14, 0.03), planks)
		sculpt.box(Vector3(0, 0.15, side * 0.29), Vector3(0.07, 0.04, 0.08), IRON)
	if variation % 2 == 0:
		sculpt.box(Vector3(-0.08, 0.3, -0.1), Vector3(0.19, 0.19, 0.19), paints[0], Basis(Vector3.UP, 0.3))
		sculpt.box(Vector3(0.09, 0.29, 0.1), Vector3(0.17, 0.17, 0.17), paints[1], Basis(Vector3.UP, -0.2))
		sculpt.box(Vector3(0.0, 0.47, 0.0), Vector3(0.15, 0.15, 0.15), paints[2], Basis(Vector3.UP, 0.6))
	else:
		sculpt.tube(Vector3(-0.07, 0.31, 0.08), 0.085, 0.085, 0.2, paints[3], 10)
		sculpt.tube(Vector3(0.08, 0.27, -0.1), 0.1, 0.0, 0.2, paints[2], 8)
		sculpt.tube(Vector3(0.0, 0.3, -0.02), 0.07, 0.07, 0.34, paints[1], 8, Basis(Vector3.BACK, PI * 0.5))
	return sculpt.mesh()


## Spoked wheel around its local X axis; unit radius so one mesh serves every size.
func _wheel_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var across := Basis(Vector3.BACK, PI * 0.5)
	sculpt.tube(Vector3.ZERO, 1.0, 1.0, 0.5, RED.darkened(0.25), 12, across)
	sculpt.tube(Vector3.ZERO, 0.72, 0.72, 0.54, IRON, 10, across)
	for spoke in range(3):
		sculpt.box(Vector3.ZERO, Vector3(0.58, 1.56, 0.2), Color("#f6ead0"), Basis(Vector3.RIGHT, PI * float(spoke) / 3.0))
	sculpt.tube(Vector3.ZERO, 0.3, 0.3, 0.64, BRASS, 8, across)
	return sculpt.mesh()


func at_dock() -> bool:
	return distance <= EPSILON and not running


func branch_label() -> String:
	return "左線" if branch == 0 else "右線"


func select_next_branch() -> bool:
	if not at_dock():
		return false
	branch = 1 - branch
	_refresh_rails()
	_place_train()
	return true


func operate() -> String:
	if reduced_motion:
		return _step()
	running = not running
	return "列車開始走" if running else "列車暫停"


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	if value:
		running = false
		_hold_remaining = 0.0
		_hide_puffs()


func reset() -> void:
	branch = 0
	running = false
	outbound = true
	distance = 0.0
	_hold_remaining = 0.0
	_refresh_rails()
	_place_train()


## Returns true only when the locomotion status changes.
func advance(delta: float) -> bool:
	if not running or delta <= 0.0:
		return false
	if _hold_remaining > 0.0:
		_hold_remaining = maxf(0.0, _hold_remaining - delta)
		return false
	var length := _curves[branch].get_baked_length()
	distance = move_toward(distance, length if outbound else 0.0, delta * SPEED)
	_place_train()
	if outbound and is_equal_approx(distance, length):
		outbound = false
		_hold_remaining = END_HOLD
		return true
	if not outbound and is_zero_approx(distance):
		outbound = true
		running = false
		return true
	return false


## Funnel puffs while the train is running; call on every frame that motion is allowed.
func animate(delta: float) -> void:
	if not running or _hold_remaining > 0.0:
		if _puff_clock != 0.0:
			_hide_puffs()
		return
	_puff_clock += delta
	var funnel := _train.transform * Vector3(0, 0.74, -0.3)
	var drift := _train.basis.z * (0.5 if outbound else -0.5)
	for index in range(PUFF_COUNT):
		var age := fposmod(_puff_clock * 0.9 + float(index) / float(PUFF_COUNT), 1.0)
		var size := lerpf(0.26, 1.0, age) * (1.0 - smoothstep(0.75, 1.0, age))
		_puffs.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * size), funnel + Vector3(0, 0.55 * age, 0) + drift * age))


func puffing() -> bool:
	return _puff_clock > 0.0


func _hide_puffs() -> void:
	_puff_clock = 0.0
	for index in range(PUFF_COUNT):
		_puffs.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))


func _step() -> String:
	var stops := _waypoints[branch]
	if outbound:
		for index in range(1, stops.size()):
			if stops[index] > distance + EPSILON:
				distance = stops[index]
				_place_train()
				if index == stops.size() - 1:
					outbound = false
					return "到達%s終點，再按一次倒車" % branch_label()
				return "到達岔口" if index == 1 else "沿%s前進" % branch_label()
	else:
		for index in range(stops.size() - 2, -1, -1):
			if stops[index] < distance - EPSILON:
				distance = stops[index]
				_place_train()
				if index == 0:
					outbound = true
					return "列車已回站"
				return "列車沿%s倒車" % branch_label()
	return "列車已停靠"


func _place_train() -> void:
	var engine := _vehicle_pose(distance)
	_train.transform = engine
	for index in range(_wagons.size()):
		_wagons[index].transform = _vehicle_pose(distance - float(WAGON_OFFSETS[index]))
	var roll := distance / WHEEL_RADIUS
	for index in range(_wheel_rests.size()):
		var rest: Array = _wheel_rests[index]
		var carrier: Transform3D = engine if int(rest[0]) < 0 else _wagons[int(rest[0])].transform
		var size := WHEEL_RADIUS * float(rest[2])
		_wheels.set_instance_transform(index, carrier * Transform3D(Basis(Vector3.RIGHT, -roll / float(rest[2])).scaled(Vector3(0.09, size, size)), rest[1]))
	for rod in _rods:
		rod.position.y = WHEEL_RADIUS + CRANK * cos(roll)
		rod.position.z = float(DRIVE_WHEELS[1]) - CRANK * sin(roll)


## Where a vehicle stands `travel` along the selected route; behind the dock it is on the tail siding.
func _vehicle_pose(travel: float) -> Transform3D:
	if travel < 0.0:
		return Transform3D(Basis.IDENTITY, DOCK + Vector3(0, RAIL_Y, -travel))
	var route := _curves[branch]
	return Transform3D(Basis(Vector3.UP, _heading(route, travel)), route.sample_baked(travel) + Vector3.UP * RAIL_Y)


func _heading(route: Curve3D, travel: float) -> float:
	var vector := route.sample_baked(minf(route.get_baked_length(), travel + 0.065)) - route.sample_baked(maxf(0.0, travel - 0.065))
	return atan2(-vector.x, -vector.z)


func _refresh_rails() -> void:
	for index in _branch_rails.size():
		_branch_rails[index].material_override = _selected_rails if index == branch else _idle_rails


func snapshot() -> Dictionary:
	return {"branch": branch, "running": running, "distance": distance, "length": _curves[branch].get_baked_length(),
		"position": _train.global_position, "at_dock": at_dock(), "outbound": outbound, "reduced_motion": reduced_motion}


func map_tracks() -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	for curve in _curves:
		var path := PackedVector2Array()
		var samples := curve.get_baked_points()
		for offset in range(0, samples.size(), 2):
			var at := to_global(samples[offset])
			path.append(Vector2(at.x, at.z))
		var terminal := to_global(curve.get_point_position(curve.point_count - 1))
		path.append(Vector2(terminal.x, terminal.z))
		lines.append(path)
	return lines


## Both ends of every route and the end of the tail siding, in world space.
func stops() -> PackedVector3Array:
	var ends := PackedVector3Array([to_global(DOCK), to_global(DOCK + Vector3(0, 0, TAIL_LENGTH))])
	for curve in _curves:
		ends.append(to_global(curve.get_point_position(curve.point_count - 1)))
	return ends


func _crowd(label: String, mesh: Mesh, count: int, material: Material) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	var holder := MultiMeshInstance3D.new()
	holder.name = label
	holder.multimesh = batch
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)
	return batch


func _mesh(parent: Node3D, label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece, true)
	return piece


func _material(tint: Color) -> StandardMaterial3D:
	var known := _materials.get(tint) as StandardMaterial3D
	if known != null:
		return known
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.63
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[tint] = material
	return material
