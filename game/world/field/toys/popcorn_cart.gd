extends "res://game/world/field/field_toy.gd"
## A red-and-white popcorn cart with a glass case. Poke it: the kettle tips,
## a burst of popcorn pops up against the glass and tumbles down onto the
## pile, which slowly settles back for the next show.

const KERNELS := 18
const CASE_Y := 0.92
const CASE_SIZE := Vector3(0.7, 0.62, 0.5)
const POP_SECONDS := 1.6
const SETTLE_SECONDS := 6.0

var _kettle: Node3D
var _kernels: MultiMesh
var _flights: Array[Vector3] = []
var _rests: Array[Vector3] = []
var _popped := true


func build() -> void:
	var red: Material = world._coastal_surface(Kit.TILE_RED_BOARD, 0.5, Color("#ffd0c8"))
	Kit.box(self, ground + Vector3(0, 0.42, 0), Vector3(0.82, 0.6, 0.6), red)
	Kit.box(self, ground + Vector3(0, 0.74, 0), Vector3(0.88, 0.05, 0.66), world._coastal_surface(Kit.TILE_BRASS, 0.3))
	for side: float in [-1.0, 1.0]:
		var wheel := Kit.cylinder(self, ground + Vector3(side * 0.36, 0.16, 0.32), 0.16, 0.06, world._mat(Color("#2e2a33")), -1.0, 12)
		wheel.rotation.x = PI * 0.5
	Kit.box(self, ground + Vector3(0, 0.09, -0.2), Vector3(0.06, 0.18, 0.06), world._mat(Color("#2e2a33")))
	Kit.box(self, ground + Vector3(0, CASE_Y + CASE_SIZE.y * 0.5, 0), CASE_SIZE, Kit.clear_material(world, Color(0.92, 0.98, 1.0, 0.25)))
	var roof := PrismMesh.new()
	roof.size = Vector3(0.9, 0.24, 0.62)
	Kit.mesh(self, roof, ground + Vector3(0, CASE_Y + CASE_SIZE.y + 0.12, 0), world._coastal_surface(Kit.TILE_RED_BOARD, 0.4, Color("#fff0ea")))
	Kit.ball(self, ground + Vector3(0, CASE_Y + CASE_SIZE.y + 0.3, 0), 0.06, world._coastal_surface(Kit.TILE_BRASS, 0.3))
	var sign := Kit.label(self, "爆米花", ground + Vector3(0, 0.46, 0.31), 26, Color("#fff3c4"))
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.outline_modulate = Color("#7a1f2a")
	_kettle = Node3D.new()
	_kettle.position = ground + Vector3(0, CASE_Y + CASE_SIZE.y - 0.12, 0)
	add_child(_kettle)
	Kit.cylinder(_kettle, Vector3(0, -0.06, 0), 0.13, 0.12, world._coastal_surface(Kit.TILE_BRASS, 0.3), 0.1, 10)
	Kit.box(_kettle, Vector3(0, 0.04, 0), Vector3(0.02, 0.16, 0.02), world._mat(Color("#6d7380")))
	var puff := SphereMesh.new()
	puff.radius = 0.045
	puff.height = 0.08
	puff.radial_segments = 6
	puff.rings = 3
	var spots: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4211
	for index in range(KERNELS):
		var rest := ground + Vector3(rng.randf_range(-0.28, 0.28), CASE_Y + 0.05 + rng.randf() * 0.12, rng.randf_range(-0.18, 0.18))
		_rests.append(rest)
		_flights.append(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(1.6, 2.6), rng.randf_range(-0.3, 0.3)))
		spots.append(Transform3D(Basis.IDENTITY, rest))
	var batch := Kit.batch(self, puff, spots, world._vertex_color_material("field-popcorn", 0.8), [Color("#fff4d6"), Color("#ffe8a8"), Color("#fffaf0")])
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kernels = batch.multimesh
	_kernels.custom_aabb = AABB(ground + Vector3(-0.6, 0, -0.6), Vector3(1.2, 2.2, 1.2))
	item["marker"] = 2.1


func poke() -> void:
	_popped = false
	note(0)


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	var popping := not still and t < POP_SECONDS
	_kettle.rotation.z = (sin(minf(t, POP_SECONDS) / POP_SECONDS * PI) * 0.6) if popping else 0.0
	var top := CASE_Y + CASE_SIZE.y - 0.05
	for index in range(KERNELS):
		var rest := _rests[index]
		var at := rest
		if popping:
			# Each kernel pops a moment after the last, bounces off the glass roof and falls back.
			var own := t - float(index) * 0.05
			if own > 0.0:
				var flight := _flights[index]
				var height := rest.y + flight.y * own - 4.9 * own * own
				var x := clampf(rest.x + flight.x * own, ground.x - CASE_SIZE.x * 0.45, ground.x + CASE_SIZE.x * 0.45)
				var z := clampf(rest.z + flight.z * own, ground.z - CASE_SIZE.z * 0.45, ground.z + CASE_SIZE.z * 0.45)
				at = Vector3(x, clampf(height, rest.y, ground.y + top), z)
		_kernels.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
	if not _popped and t >= POP_SECONDS:
		_popped = true
		feedback("success")
