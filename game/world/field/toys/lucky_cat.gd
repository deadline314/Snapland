extends "res://game/world/field/field_toy.gd"
## A beckoning lucky cat on a red cushion. Pat it and its paw waves like mad
## while a lucky "福" floats up and away.

const PAW_SECONDS := 2.4

var _paw: Node3D
var _head: Node3D
var _luck: Label3D


func build() -> void:
	Kit.box(self, ground + Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.7), world._coastal_surface(Kit.TILE_RED_BOARD, 0.6))
	Kit.box(self, ground + Vector3(0, 0.27, 0), Vector3(0.8, 0.06, 0.6), world._coastal_surface(Kit.TILE_CANVAS, 0.5, Color("#f2c75a")))
	var fur: Material = world._mat(Color("#fbf6ec"))
	var body := Kit.ball(self, ground + Vector3(0, 0.6, 0), 0.3, fur)
	body.scale = Vector3(1.0, 1.1, 0.85)
	Kit.box(self, ground + Vector3(0, 0.5, 0.25), Vector3(0.22, 0.12, 0.04), world._mat(Color("#e0525a")))
	_head = Node3D.new()
	_head.position = ground + Vector3(0, 1.0, 0)
	add_child(_head)
	Kit.ball(_head, Vector3.ZERO, 0.24, fur)
	for side: float in [-1.0, 1.0]:
		var ear := Kit.cylinder(_head, Vector3(side * 0.13, 0.22, 0), 0.08, 0.14, fur, 0.0, 6)
		ear.rotation.z = -side * 0.3
		Kit.ball(_head, Vector3(side * 0.09, 0.03, 0.21), 0.03, world._mat(Color("#3a2a2e")))
	Kit.ball(_head, Vector3(0, -0.04, 0.23), 0.025, world._mat(Color("#e0525a")))
	_paw = Node3D.new()
	_paw.position = ground + Vector3(0.26, 0.82, 0.08)
	add_child(_paw)
	var arm := Kit.cylinder(_paw, Vector3(0, 0.16, 0), 0.07, 0.32, fur, -1.0, 8)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.ball(_paw, Vector3(0, 0.34, 0), 0.09, fur)
	_luck = Kit.label(self, "福", ground + Vector3(0, 1.6, 0), 48, Color("#f2c75a"))
	item["marker"] = 2.0


func poke() -> void:
	note(1)
	note(3)


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	var waving := t < PAW_SECONDS
	_paw.rotation.z = (-0.5 if waving else 0.0) if still else (-0.6 * absf(sin(t * 11.0)) if waving else -0.15 * absf(sin(world.time * 1.2)))
	_head.rotation.z = 0.0 if still or not waving else sin(t * 5.5) * 0.12
	_luck.visible = t < 1.6
	if _luck.visible:
		var rise := 0.4 if still else t / 1.6
		_luck.position = ground + Vector3(0, 1.6 + rise * 1.0, 0)
		_luck.modulate.a = 1.0 if still else 1.0 - smoothstep(0.6, 1.0, rise)
