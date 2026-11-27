extends "res://game/world/field/field_toy.gd"
## A giant dandelion clock. Blow on it and its seeds drift off on the breeze,
## leaving a bare stalk until a new clock grows back.

const HEIGHT := 1.2
const SEEDS := 10
const FLY_SECONDS := 3.0
const REGROW_SECONDS := 7.0

var _head: MeshInstance3D
var _stalk: Node3D
var _seeds: MultiMesh
var _crown := Vector3.ZERO


func build() -> void:
	Kit.cylinder(self, ground + Vector3(0, 0.04, 0), 0.4, 0.08, world._stone_finish(Color("#6a5040")), 0.34, 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stalk = Node3D.new()
	_stalk.position = ground
	add_child(_stalk)
	var green: Material = world._mat(Color("#6f9a52"))
	Kit.cylinder(_stalk, Vector3(0, HEIGHT * 0.5, 0), 0.035, HEIGHT, green, 0.025, 6)
	for side: float in [-1.0, 1.0]:
		var leaf := Kit.ball(_stalk, Vector3(side * 0.22, 0.12, 0.05), 0.16, green)
		leaf.scale = Vector3(1.6, 0.3, 0.6)
	_head = Kit.ball(_stalk, Vector3(0, HEIGHT + 0.12, 0), 0.24, Kit.clear_material(world, Color(0.98, 0.98, 0.95, 0.75)))
	Kit.ball(_stalk, Vector3(0, HEIGHT + 0.12, 0), 0.06, world._mat(Color("#c9b77a")))
	_crown = ground + Vector3(0, HEIGHT + 0.12, 0)
	var fluff := SphereMesh.new()
	fluff.radius = 0.05
	fluff.height = 0.1
	fluff.radial_segments = 6
	fluff.rings = 3
	var hidden: Array[Transform3D] = []
	for index in range(SEEDS):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), _crown))
	var seeds := Kit.batch(self, fluff, hidden, Kit.clear_material(world, Color(1.0, 1.0, 0.97, 0.9), 0.3))
	seeds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seeds.multimesh.custom_aabb = AABB(_crown - Vector3(2, 2, 2), Vector3(8, 6, 4))
	_seeds = seeds.multimesh
	item["marker"] = 2.0


func poke() -> void:
	note(3)
	note(1)


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	var bare := t < REGROW_SECONDS
	var grow := 1.0 if not bare else (0.0 if still else smoothstep(REGROW_SECONDS - 1.5, REGROW_SECONDS, t))
	_head.scale = Vector3.ONE * maxf(grow, 0.01)
	_head.visible = grow > 0.01
	_stalk.rotation.z = 0.0 if still or t > 1.5 else sin(t * 9.0) * 0.12 * (1.0 - t / 1.5)
	for index in range(SEEDS):
		if still or t > FLY_SECONDS:
			_seeds.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), _crown))
			continue
		var start := index * 0.06
		var age := maxf(0.0, t - start)
		var angle := index * 2.4
		var drift := Vector3(age * (1.1 + fposmod(index * 0.3, 0.6)), age * 0.6 + sin(age * 3.0 + index) * 0.15, cos(angle) * 0.25 * age)
		var home := _crown + Vector3(cos(angle) * 0.2, sin(angle) * 0.2, 0)
		_seeds.set_instance_transform(index, Transform3D(Basis.IDENTITY, home + drift))
