extends "res://game/world/field/field_toy.gd"
## A painted rocking horse. Every push rocks it harder; left alone it rocks
## itself back to rest, mane flapping.

var _rocker: Node3D
var _mane: Node3D
var _swing := 0.0


func build() -> void:
	_rocker = Node3D.new()
	_rocker.position = ground
	add_child(_rocker)
	# Curved rockers: a shallow arc of tube on each side.
	for side: float in [-0.22, 0.22]:
		var arc := PackedVector3Array()
		for index in range(13):
			var along := (index / 12.0 - 0.5) * 1.5
			arc.append(Vector3(along, 0.06 + along * along * 0.22, side))
		Kit.mesh(_rocker, Kit.tube(arc, 0.04, Vector3.FORWARD), Vector3.ZERO, world._wood_material(Color("#7a5a3c")))
	var legs := BoxMesh.new()
	legs.size = Vector3(0.07, 0.36, 0.07)
	var feet: Array[Transform3D] = []
	for x: float in [-0.3, 0.3]:
		for z: float in [-0.2, 0.2]:
			feet.append(Transform3D(Basis(Vector3.FORWARD, x * 0.4), Vector3(x, 0.26, z)))
	Kit.batch(_rocker, legs, feet, world._wood_material(Color("#e6d9b8")))
	var body := Kit.cylinder(_rocker, Vector3(0, 0.52, 0), 0.17, 0.78, world._wood_material(Color("#f4e8d0")), 0.15, 10)
	body.rotation.z = PI * 0.5
	Kit.box(_rocker, Vector3(0.02, 0.7, 0), Vector3(0.3, 0.05, 0.36), world._mat(Color("#d9454e")))
	var neck := Kit.cylinder(_rocker, Vector3(-0.38, 0.75, 0), 0.09, 0.4, world._wood_material(Color("#f4e8d0")), 0.08, 8)
	neck.rotation.z = -0.6
	var head := Kit.box(_rocker, Vector3(-0.55, 0.95, 0), Vector3(0.3, 0.16, 0.15), world._wood_material(Color("#f4e8d0")))
	head.rotation.z = 0.35
	Kit.ball(head, Vector3(-0.05, 0.03, 0.08), 0.022, world._mat(Color("#2a2730")))
	_mane = Node3D.new()
	_mane.position = Vector3(-0.4, 0.9, 0)
	_rocker.add_child(_mane)
	Kit.box(_mane, Vector3(0.06, 0.05, 0), Vector3(0.24, 0.1, 0.05), world._mat(Color("#c9644a")))
	var tail := Kit.cylinder(_rocker, Vector3(0.46, 0.55, 0), 0.05, 0.3, world._mat(Color("#c9644a")), 0.02, 6)
	tail.rotation.z = -0.9
	item["marker"] = 1.7


func poke() -> void:
	_swing = minf(0.5, _swing + 0.22)
	note(2 if _swing > 0.4 else 1)


func advance(delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	if still:
		_swing = 0.0
		_rocker.rotation.z = 0.2 if t < 1.0 else 0.0
		_mane.rotation.z = 0.0
		return
	_swing *= exp(-0.45 * delta)
	if _swing < 0.005:
		_swing = 0.0
	_rocker.rotation.z = _swing * sin(t * 4.2)
	_mane.rotation.z = _swing * 0.8 * sin(t * 8.4 + 0.5)
