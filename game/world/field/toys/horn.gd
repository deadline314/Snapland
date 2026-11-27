extends "res://game/world/field/field_toy.gd"
## A brass clown horn on a post. Squeeze the bulb: the bell wobbles, honks
## and blows a burst of confetti into the air.

const HEIGHT := 1.5
const CONFETTI := 12
const BURST_SECONDS := 1.8
const PAPER_COLORS := [Color("#e0525a"), Color("#f2c75a"), Color("#7fd0c4"), Color("#9fb8ef"), Color("#f4a6c6")]

var _bulb: MeshInstance3D
var _bell: Node3D
var _mouth := Vector3.ZERO
var _confetti: MultiMesh


func build() -> void:
	var post: Array[Vector3] = [ground]
	Kit.posts(world, self, post, HEIGHT, Color("#e0525a"), 0.07)
	_bell = Node3D.new()
	_bell.position = ground + Vector3(0, HEIGHT + 0.25, 0)
	add_child(_bell)
	var brass: Material = world._coastal_surface(Kit.TILE_BRASS, 0.4, Color("#ffd98a"))
	var tube := Kit.cylinder(_bell, Vector3(0.25, 0, 0), 0.05, 0.5, brass, -1.0, 8)
	tube.rotation.z = PI * 0.5
	var flare := Kit.cylinder(_bell, Vector3(0.62, 0.05, 0), 0.3, 0.32, brass, 0.06, 14)
	flare.rotation.z = PI * 0.5 + 0.2
	_bulb = Kit.ball(_bell, Vector3(-0.12, 0, 0), 0.16, world._mat(Color("#e0525a")))
	_mouth = _bell.position + Vector3(0.8, 0.12, 0)
	var paper := BoxMesh.new()
	paper.size = Vector3(0.09, 0.012, 0.06)
	var hidden: Array[Transform3D] = []
	for index in range(CONFETTI):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), _mouth))
	var colors: Array[Color] = []
	colors.assign(PAPER_COLORS)
	var burst := Kit.batch(self, paper, hidden, world._vertex_color_material("field-confetti"), colors)
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.multimesh.custom_aabb = AABB(_mouth - Vector3(3, 3, 3), Vector3(6, 5, 6))
	_confetti = burst.multimesh
	item["marker"] = 2.6


func poke() -> void:
	note(0)
	note(3)
	feedback("tap")


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	var squeeze := (0.4 if t < 1.0 else 0.0) if still else (sin(t / 0.4 * PI) * 0.45 if t < 0.4 else 0.0)
	_bulb.scale = Vector3(1.0 - squeeze * 0.6, 1.0 + squeeze * 0.3, 1.0 + squeeze * 0.3)
	_bell.rotation.z = 0.0 if still or t > 1.2 else sin(t * 20.0) * 0.12 * (1.0 - t / 1.2)
	for index in range(CONFETTI):
		if still or t > BURST_SECONDS:
			_confetti.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), _mouth))
			continue
		var spread := Vector3(1.2 + fposmod(index * 0.37, 0.8), 2.2 + fposmod(index * 0.53, 1.2), (fposmod(index * 0.71, 1.0) - 0.5) * 2.0)
		var at := _mouth + spread * t + Vector3(0, -2.4 * t * t, 0)
		var spin := Basis.from_euler(Vector3(t * (4.0 + index), t * 3.0, index))
		_confetti.set_instance_transform(index, Transform3D(spin, at))
