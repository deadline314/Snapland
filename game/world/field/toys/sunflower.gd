extends "res://game/world/field/field_toy.gd"
## A tall sunflower that turns its face to follow whoever walks past. Say
## hello and it nods back happily while a butterfly flutters round its head.

const HEIGHT := 1.9
const WATCH_REACH := 5.0
const NOD_SECONDS := 2.0

var _face: Node3D
var _turn := 0.0
var _flutter: Kit.SpriteBatch


func build() -> void:
	Kit.cylinder(self, ground + Vector3(0, 0.08, 0), 0.38, 0.16, world._wood_material(Color("#9b7a52")), 0.32, 10)
	var green: Material = world._mat(Color("#5f8f4e"))
	Kit.cylinder(self, ground + Vector3(0, HEIGHT * 0.5, 0), 0.05, HEIGHT, green, 0.035, 6)
	for index in range(3):
		var leaf := Kit.ball(self, ground + Vector3((-1.0 if index % 2 == 0 else 1.0) * 0.22, 0.5 + index * 0.4, 0), 0.15, green)
		leaf.scale = Vector3(1.6, 0.35, 0.7)
	_face = Node3D.new()
	_face.position = ground + Vector3(0, HEIGHT + 0.1, 0)
	add_child(_face)
	var petals := Kit.cylinder(_face, Vector3(0, 0, 0.03), 0.42, 0.06, world._mat(Color("#f2c75a")), -1.0, 14)
	petals.rotation.x = PI * 0.5
	var middle := Kit.cylinder(_face, Vector3(0, 0, 0.07), 0.22, 0.06, world._stone_finish(Color("#6a4a2e")), -1.0, 12)
	middle.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		Kit.ball(_face, Vector3(side * 0.07, 0.05, 0.11), 0.025, world._mat(Color("#2a2730")))
	Kit.box(_face, Vector3(0, -0.06, 0.11), Vector3(0.1, 0.02, 0.02), world._mat(Color("#2a2730")))
	_flutter = Kit.SpriteBatch.new(world, 1)
	add_child(_flutter)
	_flutter.tint(0, Color(1.3, 0.85, 1.1))
	item["marker"] = 2.9


func poke() -> void:
	note(2)
	note(0)


func advance(delta: float, player: Vector3, still: bool) -> void:
	var t := since()
	# Follows the walker while near; drifts back to face the camera side otherwise.
	var wanted := 0.0
	if player.is_finite() and near(player, WATCH_REACH):
		wanted = clampf(atan2(player.x - ground.x, player.z - ground.z), -1.2, 1.2)
	_turn = wanted if still else lerpf(_turn, wanted, minf(1.0, delta * 3.0))
	_face.rotation.y = _turn
	var nodding := t < NOD_SECONDS
	_face.rotation.x = (0.3 if nodding else 0.0) if still else (0.35 * absf(sin(t * 7.0)) * (1.0 - t / NOD_SECONDS) if nodding else 0.0)
	if not nodding or still:
		_flutter.hide_item(0)
		return
	var loop := t * 4.0
	var spot := _face.position + Vector3(cos(loop) * 0.6, 0.2 + sin(loop * 2.0) * 0.15, sin(loop) * 0.4)
	_flutter.put(0, spot, "butterfly", int(t * 10.0) % 3, cos(loop) < 0.0, 1.2)
