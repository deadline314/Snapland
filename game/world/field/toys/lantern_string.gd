extends "res://game/world/field/field_toy.gd"
## A string of paper lanterns between two posts. Give it a shake and the
## lanterns swing one after another and flare up brighter for a moment.

const HEIGHT := 2.4
const LANTERNS := 5
const SPAN := 2.6
const GLOW_SECONDS := 2.2

var _lanterns: Array[Node3D] = []
var _bodies: Array[MeshInstance3D] = []
var _dim: Material
var _bright: Material


func build() -> void:
	var a := ground + Vector3(-SPAN * 0.5, 0, 0)
	var b := ground + Vector3(SPAN * 0.5, 0, 0)
	var legs: Array[Vector3] = [a, b]
	Kit.posts(world, self, legs, HEIGHT, Color("#e8674f"), 0.08)
	var cord := PackedVector3Array()
	for index in range(11):
		var along := index / 10.0
		cord.append(Vector3((along - 0.5) * SPAN, -sin(along * PI) * 0.35, 0))
	Kit.mesh(self, Kit.tube(cord, 0.018), ground + Vector3(0, HEIGHT + 0.15, 0), world._mat(Color("#3a2a2e")), false)
	_dim = world._mat(Color("#e0603e"), true)
	_bright = world._mat(Color("#ffd27a"), true)
	var tones := [Color("#e0603e"), Color("#f2a85a"), Color("#e0603e"), Color("#f2a85a"), Color("#e0603e")]
	for index in range(LANTERNS):
		var along := (index + 1.0) / (LANTERNS + 1.0)
		var pivot := Node3D.new()
		pivot.position = ground + Vector3((along - 0.5) * SPAN, HEIGHT + 0.15 - sin(along * PI) * 0.35, 0)
		add_child(pivot)
		var body := Kit.ball(pivot, Vector3(0, -0.32, 0), 0.19, world._mat(tones[index], true))
		body.scale = Vector3(1.0, 1.25, 1.0)
		Kit.cylinder(pivot, Vector3(0, -0.08, 0), 0.08, 0.06, world._mat(Color("#3a2a2e")), -1.0, 8)
		Kit.cylinder(pivot, Vector3(0, -0.56, 0), 0.08, 0.05, world._mat(Color("#3a2a2e")), -1.0, 8)
		_lanterns.append(pivot)
		_bodies.append(body)
	item["marker"] = 3.2


func poke() -> void:
	note(0)
	note(2)


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	for index in range(LANTERNS):
		var since_this := t - index * 0.12
		var swing := 0.0
		if still:
			swing = 0.2 if t < 4.0 else 0.0
		elif since_this > 0.0 and since_this < 4.0:
			swing = 0.45 * sin(since_this * 6.0) * exp(-since_this * 0.9)
		_lanterns[index].rotation.z = swing
		var glowing := since_this > 0.0 and since_this < GLOW_SECONDS
		var want: Material = _bright if glowing else (_dim if index % 2 == 0 else world._mat(Color("#f2a85a"), true))
		if _bodies[index].material_override != want:
			_bodies[index].material_override = want
