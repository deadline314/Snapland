extends Node3D
## One small unscored toy of a kind that has its own script (toys/<kind>.gd).
## FieldToys owns the row, the interaction point, the cooldown and the clock:
## `item.t` counts seconds since the last poke (large means at rest) and
## `item.pokes` how often it was poked. A toy builds its nodes once, answers
## a poke, and animates from that clock; under reduced motion it shows a held
## pose instead of moving.

const Kit = preload("res://game/world/field/field_kit.gd")

var world: Node3D
var field: Node3D
var item: Dictionary
var ground := Vector3.ZERO


func setup(owner_world: Node3D, owner_field: Node3D, row_item: Dictionary) -> void:
	world = owner_world
	field = owner_field
	item = row_item
	ground = item.ground
	build()
	advance(0.0, Vector3(INF, 0, INF), true)


## Create every node the toy will ever need; set item.marker for its glyph height.
func build() -> void:
	pass


## The visitor pressed interact (the cooldown has already passed).
func poke() -> void:
	pass


func advance(_delta: float, _player: Vector3, _still: bool) -> void:
	pass


func since() -> float:
	return float(item.t)


func note(index: int) -> void:
	field.note_requested.emit(posmod(index, 4))


func feedback(kind: String) -> void:
	field.feedback_requested.emit(kind)


func near(player: Vector3, reach: float) -> bool:
	return Vector2(player.x - ground.x, player.z - ground.z).length() < reach
