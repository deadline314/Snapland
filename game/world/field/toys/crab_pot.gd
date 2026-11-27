extends "res://game/world/field/field_toy.gd"
## A wicker crab pot on the beach. Lift the lid and three crabs scuttle out
## sideways, wave their claws, and scurry back in.

const CRABS := 3
const OUT_SECONDS := 3.2

var _lid: Node3D
var _crabs: Kit.SpriteBatch


func build() -> void:
	var wicker: Material = world._coastal_surface(Kit.TILE_CANVAS, 0.4, Color("#b99460"))
	Kit.cylinder(self, ground + Vector3(0, 0.05, 0), 0.5, 0.1, world._wood_material(Color("#7a5a3c")), -1.0, 12)
	Kit.cylinder(self, ground + Vector3(0, 0.38, 0), 0.46, 0.56, wicker, 0.36, 12)
	_lid = Node3D.new()
	_lid.position = ground + Vector3(-0.36, 0.68, 0)
	add_child(_lid)
	Kit.cylinder(_lid, Vector3(0.36, 0.03, 0), 0.4, 0.07, wicker, -1.0, 12)
	Kit.ball(_lid, Vector3(0.36, 0.1, 0), 0.06, world._mat(Color("#da705c")))
	_crabs = Kit.SpriteBatch.new(world, CRABS)
	add_child(_crabs)
	item["marker"] = 1.6


func poke() -> void:
	note(1)
	feedback("tap")


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	var open := t < OUT_SECONDS
	_lid.rotation.z = (1.1 if open else 0.0) if still else (1.1 * clampf(minf(t * 5.0, (OUT_SECONDS - t) * 3.0), 0.0, 1.0) if open else 0.0)
	for index in range(CRABS):
		if not open:
			_crabs.hide_item(index)
			continue
		var side := -1.0 if index == 0 else (1.0 if index == 1 else 0.0)
		var out := Vector3(side * 1.1, 0, 0.9 if index == 2 else 0.5)
		# Out in a hurry, a claw wave, then back in.
		var reach := 1.0 if still else clampf(minf(t * 2.2, (OUT_SECONDS - t) * 2.0), 0.0, 1.0)
		var claws := not still and fmod(t * 3.0 + index, 1.0) < 0.5
		_crabs.put(index, ground + out * reach, "crab", 2 if claws else 1, side > 0.0, 1.1)
