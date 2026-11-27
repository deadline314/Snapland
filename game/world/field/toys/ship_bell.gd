extends "res://game/world/field/field_toy.gd"
## An old ship's bell on a timber yoke: ring it and it swings, tolls three
## falling notes and sends a ring across the sand.

const HEIGHT := 2.2

var _bell: Node3D
var _ripple: MeshInstance3D
var _rung := 3


func build() -> void:
	var legs: Array[Vector3] = [ground + Vector3(-0.55, 0, 0), ground + Vector3(0.55, 0, 0)]
	Kit.posts(world, self, legs, HEIGHT, Color("#4b9b9c"), 0.08)
	Kit.box(self, ground + Vector3(0, HEIGHT + 0.25, 0), Vector3(1.4, 0.16, 0.18), world._wood_material(Color("#7a5a3c")))
	_bell = Node3D.new()
	_bell.position = ground + Vector3(0, HEIGHT + 0.16, 0)
	add_child(_bell)
	var brass: Material = world._coastal_surface(Kit.TILE_BRASS, 0.4, Color("#ffd98a"))
	Kit.cylinder(_bell, Vector3(0, -0.3, 0), 0.3, 0.46, brass, 0.16, 14)
	Kit.ball(_bell, Vector3(0, -0.08, 0), 0.17, brass)
	Kit.ball(_bell, Vector3(0, -0.6, 0), 0.07, world._mat(Color("#6b4a34")))
	Kit.cylinder(_bell, Vector3(0, -0.53, 0), 0.32, 0.05, brass, -1.0, 14)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 20
	ring.ring_segments = 4
	_ripple = Kit.mesh(self, ring, ground + Vector3(0, 0.04, 0), Kit.clear_material(world, Color(0.95, 0.93, 0.8, 0.6), 0.3), false)
	item["marker"] = 3.2


func poke() -> void:
	_rung = 0


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	while _rung < 3 and t >= _rung * 0.45:
		note(3 - _rung)
		_rung += 1
	_bell.rotation.z = (0.25 if t < 1.0 else 0.0) if still else 0.55 * sin(t * 7.0) * exp(-t * 1.3)
	_ripple.visible = t < 1.4
	if _ripple.visible:
		var grow := 0.6 if still else 0.4 + t * 1.6
		_ripple.scale = Vector3(grow, 1.0, grow)
