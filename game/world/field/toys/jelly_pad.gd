extends "res://game/world/field/field_toy.gd"
## A big wobbly jelly block. Step on it (or poke it) and it squashes flat,
## bounces you up, and wobbles for a while afterwards.

const SIZE := Vector3(1.3, 0.34, 1.3)
const REACH := 0.7

var _jelly: MeshInstance3D
var _inside := false


func build() -> void:
	Kit.cylinder(self, ground + Vector3(0, 0.03, 0), 0.95, 0.06, world._wood_material(Color("#c98a5a")), -1.0, 16).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var block := BoxMesh.new()
	block.size = SIZE
	_jelly = Kit.mesh(self, block, ground + Vector3(0, SIZE.y * 0.5 + 0.06, 0), Kit.clear_material(world, Color(0.95, 0.45, 0.6, 0.72), 0.25))
	Kit.ball(_jelly, Vector3(0.2, SIZE.y * 0.5 + 0.08, -0.15), 0.12, world._mat(Color("#e0525a")))
	item["marker"] = 1.5


func poke() -> void:
	note(2)
	feedback("tap")
	if near(world.player.global_position, REACH):
		field.hop(0.9, 0.7)


func advance(_delta: float, player: Vector3, still: bool) -> void:
	var inside := near(player, REACH)
	if inside and not _inside and since() > 1.0:
		_step_on()
	_inside = inside
	var t := since()
	var wobble := 0.0
	if t < 2.5:
		wobble = -0.3 if still else -0.45 * cos(t * 13.0) * exp(-t * 2.2)
	_jelly.scale = Vector3(1.0 - wobble * 0.5, 1.0 + wobble, 1.0 - wobble * 0.5)
	_jelly.position.y = ground.y + 0.06 + SIZE.y * 0.5 * (1.0 + wobble)


## Stepping on counts as a poke: same clock, same reaction.
func _step_on() -> void:
	item.t = 0.0
	item.pokes = int(item.pokes) + 1
	poke()
