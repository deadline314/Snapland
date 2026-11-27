extends "res://game/world/field/field_toy.gd"
## A big wooden spinning top. Give it a whirl: it spins up, wanders around
## in a little loop, wobbles as it slows, topples over, and a while later is
## stood back up.

const SPIN_SECONDS := 4.0
const LIE_SECONDS := 6.0

var _top: Node3D
var _body: Node3D


func build() -> void:
	Kit.cylinder(self, ground + Vector3(0, 0.02, 0), 0.9, 0.04, world._coastal_surface(Kit.TILE_CANVAS, 0.9, Color("#e6d9b8")), -1.0, 18).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_top = Node3D.new()
	_top.position = ground + Vector3(0, 0.04, 0)
	add_child(_top)
	_body = Node3D.new()
	_top.add_child(_body)
	Kit.cylinder(_body, Vector3(0, 0.2, 0), 0.32, 0.36, world._wood_material(Color("#d9454e")), 0.02, 12)
	Kit.cylinder(_body, Vector3(0, 0.42, 0), 0.34, 0.1, world._mat(Color("#f2c75a")), 0.32, 12)
	Kit.cylinder(_body, Vector3(0, 0.6, 0), 0.06, 0.3, world._wood_material(Color("#7a5a3c")), 0.04, 8)
	Kit.box(_body, Vector3(0.2, 0.42, 0), Vector3(0.14, 0.11, 0.05), world._mat(Color("#7fc4f2")))
	item["marker"] = 1.6


func poke() -> void:
	note(0)
	note(1)


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	var spinning := t < SPIN_SECONDS
	var lying := t >= SPIN_SECONDS and t < SPIN_SECONDS + LIE_SECONDS
	if still:
		_body.rotation.y = 0.6 if spinning else 0.0
		_top.position = ground + Vector3(0, 0.04, 0)
		_top.rotation = Vector3(0, 0, 1.35 if lying else 0.0)
		return
	if spinning:
		var slow := t / SPIN_SECONDS
		_body.rotation.y = t * 26.0 * (1.0 - slow * 0.6)
		var loop := t * 1.6
		_top.position = ground + Vector3(sin(loop) * 0.35 * (1.0 - slow), 0.04, (cos(loop) - 1.0) * 0.25 * (1.0 - slow))
		var wobble := smoothstep(0.5, 1.0, slow) * 0.35
		_top.rotation = Vector3(cos(t * 9.0) * wobble, 0, sin(t * 9.0) * wobble)
	elif lying:
		var fall := clampf((t - SPIN_SECONDS) / 0.3, 0.0, 1.0)
		_top.rotation = Vector3(0, 0, fall * 1.35)
		_top.position = ground + Vector3(0, 0.04 + fall * 0.12, 0)
	else:
		_top.rotation = Vector3.ZERO
		_top.position = ground + Vector3(0, 0.04, 0)
