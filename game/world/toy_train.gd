extends Node3D

const DOCK := Vector3(0, 0.10, 1.62)
const FORK := Vector3(0, 0.10, 0.58)
const SPEED := 1.24
const END_HOLD := 0.42
const EPSILON := 0.001
const SPURS := [
	[Vector3(-0.33, 0.10, 0.00), Vector3(-1.14, 0.10, -0.72), Vector3(-1.67, 0.10, -1.58)],
	[Vector3(0.40, 0.10, 0.02), Vector3(1.24, 0.10, -0.63), Vector3(1.84, 0.10, -1.85)],
]
const BRASS := Color("#b48754")
const IRON := Color("#2b3440")
const STEEL := Color("#b0a99b")
const WOOD := Color("#534044")
const RED := Color("#a95143")

var branch := 0
var running := false
var reduced_motion := false
var outbound := true
var distance := 0.0
var _hold_remaining := 0.0
var _curves: Array[Curve3D] = []
var _waypoints: Array[PackedFloat32Array] = []
var _branch_rails: Array[MeshInstance3D] = []
var _train: Node3D
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
	var common := PackedVector3Array([DOCK, FORK])
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
	var bolts := MultiMesh.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.58, 0.052, 0.12)
	bolts.mesh = mesh
	bolts.transform_format = MultiMesh.TRANSFORM_3D
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
	bolts.instance_count = rests.size()
	for index in rests.size():
		bolts.set_instance_transform(index, rests[index])
	var holders := MultiMeshInstance3D.new()
	holders.name = "WoodSleepers"
	holders.multimesh = bolts
	holders.material_override = _material(WOOD)
	holders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holders)


func _build_train() -> void:
	_train = Node3D.new()
	_train.name = "ClockworkLocomotive"
	add_child(_train)
	_box(_train, Vector3(0, 0.12, 0), Vector3(0.52, 0.14, 0.73), IRON)
	_box(_train, Vector3(0, 0.36, 0.14), Vector3(0.45, 0.41, 0.32), RED)
	_box(_train, Vector3(0, 0.58, 0.14), Vector3(0.56, 0.11, 0.41), IRON)
	_box(_train, Vector3(0, 0.41, 0.309), Vector3(0.28, 0.16, 0.025), Color("#f4d593"))
	for side in [-1.0, 1.0]:
		_box(_train, Vector3(float(side) * 0.234, 0.43, 0.14), Vector3(0.025, 0.15, 0.17), Color("#f4d593"))
	var boiler := _cylinder(_train, Vector3(0, 0.28, -0.19), 0.177, 0.42, Color("#4e7771"))
	boiler.rotation.x = PI * 0.5
	_cylinder(_train, Vector3(0, 0.52, -0.28), 0.075, 0.20, IRON)
	_cylinder(_train, Vector3(0, 0.61, -0.28), 0.097, 0.043, BRASS)
	for x in [-0.25, 0.25]:
		for z in [-0.23, 0.22]:
			var wheel := _cylinder(_train, Vector3(x, 0.081, z), 0.092, 0.053, IRON)
			wheel.rotation.z = PI * 0.5
			var cap := _cylinder(_train, Vector3(x + signf(x) * 0.033, 0.081, z), 0.054, 0.024, BRASS)
			cap.rotation.z = PI * 0.5


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
	var route := _curves[branch]
	_train.position = route.sample_baked(distance) + Vector3.UP * 0.032
	_train.rotation.y = _heading(route, distance)


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


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, "TrainPart", mesh, at, _material(color))


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _mesh(parent, "TrainPart", mesh, at, _material(color))


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
