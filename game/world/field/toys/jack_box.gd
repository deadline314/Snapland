extends "res://game/world/field/field_toy.gd"
## A jack-in-the-box. Turn the crank: it plays a little tune, then the lid
## flies open and a clown head boings out on its spring.

const CRANK_SECONDS := 1.0
const OUT_SECONDS := 4.5

var _crank: Node3D
var _lid: Node3D
var _jack: Node3D
var _spring: MeshInstance3D
var _played := 4


func build() -> void:
	var box := Vector3(0.7, 0.62, 0.7)
	Kit.box(self, ground + Vector3(0, 0.04, 0), Vector3(0.82, 0.08, 0.82), world._wood_material(Color("#7a5a3c")))
	Kit.box(self, ground + Vector3(0, 0.08 + box.y * 0.5, 0), box, world._coastal_surface(Kit.TILE_RED_BOARD, 0.5, Color("#9fb8ef")))
	Kit.box(self, ground + Vector3(0, 0.08 + box.y * 0.5, 0.36), Vector3(0.4, 0.4, 0.02), world._mat(Color("#f2c75a")))
	_lid = Node3D.new()
	_lid.position = ground + Vector3(0, 0.08 + box.y, -box.z * 0.5)
	add_child(_lid)
	Kit.box(_lid, Vector3(0, 0.03, box.z * 0.5), Vector3(0.74, 0.06, 0.74), world._coastal_surface(Kit.TILE_RED_BOARD, 0.5, Color("#e0525a")))
	_crank = Node3D.new()
	_crank.position = ground + Vector3(box.x * 0.5 + 0.04, 0.4, 0)
	add_child(_crank)
	Kit.box(_crank, Vector3(0.04, 0.12, 0), Vector3(0.04, 0.28, 0.05), world._coastal_surface(Kit.TILE_BRASS, 0.3))
	Kit.ball(_crank, Vector3(0.08, 0.24, 0), 0.05, world._mat(Color("#e0525a")))
	_jack = Node3D.new()
	_jack.position = ground + Vector3(0, 0.08 + box.y * 0.5, 0)
	add_child(_jack)
	var coil := PackedVector3Array()
	for index in range(41):
		var turn := index / 40.0
		coil.append(Vector3(cos(turn * TAU * 5.0) * 0.1, turn, sin(turn * TAU * 5.0) * 0.1))
	_spring = Kit.mesh(_jack, Kit.tube(coil, 0.018, Vector3.RIGHT), Vector3.ZERO, world._coastal_surface(Kit.TILE_BRASS, 0.3), false)
	var head := Kit.ball(_jack, Vector3(0, 0.0, 0), 0.2, world._mat(Color("#fbf0e0")))
	head.name = "Head"
	Kit.ball(head, Vector3(0, -0.02, 0.19), 0.06, world._mat(Color("#e0525a")))
	Kit.cylinder(head, Vector3(0, 0.25, 0), 0.14, 0.26, world._mat(Color("#7fd0c4")), 0.0, 8)
	Kit.ball(head, Vector3(0, 0.4, 0), 0.05, world._mat(Color("#f2c75a")))
	item["marker"] = 1.9


func poke() -> void:
	_played = 0


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	while _played < 4 and t >= _played * 0.25:
		note(_played)
		_played += 1
		if _played == 4:
			feedback("success")
	_crank.rotation.x = 0.0 if still else (-t * TAU * 2.0 if t < CRANK_SECONDS else 0.0)
	var out := t >= CRANK_SECONDS and t < OUT_SECONDS
	if still:
		out = t < OUT_SECONDS
	_lid.rotation.x = -1.9 if out else 0.0
	var stretch := 0.0
	if out:
		var since_pop := t - CRANK_SECONDS
		stretch = 0.75 if still else 0.75 + 0.35 * sin(since_pop * 14.0) * exp(-since_pop * 2.0)
		stretch *= 1.0 - smoothstep(OUT_SECONDS - 0.5, OUT_SECONDS, t)
	_jack.visible = stretch > 0.05
	_spring.scale = Vector3(1.0, maxf(stretch, 0.01), 1.0)
	(_jack.get_node("Head") as Node3D).position = Vector3(0, stretch + 0.15, 0)
	_jack.rotation.z = 0.0 if still or not out else sin(t * 6.0) * 0.15 * exp(-(t - CRANK_SECONDS))
