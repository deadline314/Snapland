extends "res://game/world/field/field_game.gd"
## A thirsty flower bed on a hot day. Flowers droop as they dry out; walk up
## to a drooping one and press interact to water it back to life. Watering a
## flower that is not thirsty is a waste of water, and one left too long
## flops flat for a while before a new bud comes up. It gets hotter and
## hotter as the round goes on.

const WATER_REACH := 1.0
const THIRSTY := 0.5
const SLOW_DRY := 0.06
const FAST_DRY := 0.15
const WILT_SECONDS := 2.5
const POUR_SECONDS := 0.5
const STEM := 0.62
const PETAL_COLORS := [Color("#ef7fa8"), Color("#f2c75a"), Color("#9fb8ef"), Color("#f4a6c6"), Color("#ffffff"), Color("#f08a5a")]

var water := PackedFloat32Array()
var thirst := PackedFloat32Array()
var wilted := PackedFloat32Array()
var saved := 0
var wasted := 0
var lost := 0

var _spots: Array[Vector3] = []
var _stems: Array[Node3D] = []
var _heads: Array[Node3D] = []
var _can: Node3D
var _drops: MultiMesh
var _pour := 0.0
var _pour_at := Vector3.ZERO
var _show := 0.0
var _droop_all := false


func build() -> void:
	var middle := centre()
	for offset: Vector2 in spec.get("layout", []):
		_spots.append(spot(offset))
	# A round bed of dark soil inside a stone kerb.
	Kit.cylinder(self, middle + Vector3(0, 0.03, 0), 2.9, 0.06, world._stone_finish(Color("#6a5040")), -1.0, 26).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stone := SphereMesh.new()
	stone.radius = 0.5
	stone.height = 1.0
	stone.radial_segments = 8
	stone.rings = 4
	var kerb: Array[Transform3D] = []
	for index in range(22):
		var angle := TAU * index / 22.0 + sin(index * 1.7) * 0.05
		var size := 0.22 + fposmod(index * 0.31, 0.1)
		kerb.append(Transform3D(Basis.from_euler(Vector3(0, index, 0)).scaled(Vector3(size * 1.4, size * 0.7, size)), middle + Vector3(cos(angle), 0, sin(angle)) * 3.0 + Vector3(0, 0.08, 0)))
	Kit.batch(self, stone, kerb, world._vertex_color_material("field-bed-stones"), [Color("#9a927e"), Color("#a59d86"), Color("#8c8572")])
	var leaf: Material = world._mat(Color("#5f9a52"))
	for index in range(_spots.size()):
		var stem := Node3D.new()
		stem.position = _spots[index]
		add_child(stem)
		Kit.cylinder(stem, Vector3(0, STEM * 0.5, 0), 0.03, STEM, leaf, 0.025, 6)
		for side: float in [-1.0, 1.0]:
			var blade := Kit.ball(stem, Vector3(side * 0.1, 0.2, 0), 0.09, leaf)
			blade.scale = Vector3(1.4, 0.4, 0.8)
		var head := Node3D.new()
		head.position = Vector3(0, STEM, 0)
		stem.add_child(head)
		var petals := Kit.cylinder(head, Vector3(0, 0, 0.02), 0.2, 0.05, world._mat(PETAL_COLORS[index % PETAL_COLORS.size()]), -1.0, 10)
		petals.rotation.x = PI * 0.5
		Kit.ball(head, Vector3(0, 0, 0.05), 0.08, world._mat(Color("#f2c75a")))
		_stems.append(stem)
		_heads.append(head)
	_can = Node3D.new()
	add_child(_can)
	Kit.cylinder(_can, Vector3.ZERO, 0.14, 0.24, world._coastal_surface(Kit.TILE_BRASS, 0.3, Color("#9fd8c4")), -1.0, 10)
	Kit.cylinder(_can, Vector3(0.2, 0.05, 0), 0.025, 0.3, world._coastal_surface(Kit.TILE_BRASS, 0.3, Color("#9fd8c4")), -1.0, 6).rotation.z = -1.0
	var drop := SphereMesh.new()
	drop.radius = 0.05
	drop.height = 0.1
	drop.radial_segments = 6
	drop.rings = 3
	var hidden: Array[Transform3D] = []
	for index in range(8):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), middle))
	var drops := Kit.batch(self, drop, hidden, Kit.clear_material(world, Color(0.7, 0.88, 1.0, 0.8), 0.2))
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drops.multimesh.custom_aabb = AABB(middle - Vector3(5, 1, 5), Vector3(10, 5, 10))
	_drops = drops.multimesh
	water.resize(_spots.size())
	thirst.resize(_spots.size())
	wilted.resize(_spots.size())


func reset() -> void:
	water.fill(1.0)
	wilted.fill(0.0)
	_pour = 0.0
	_droop_all = false
	_can.visible = false
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	saved = 0
	wasted = 0
	lost = 0
	for index in range(_spots.size()):
		# Each flower starts a little differently, so they do not all droop at once.
		water[index] = 0.75 + rng.randf() * 0.25
		thirst[index] = 0.7 + rng.randf() * 0.6
	_can.visible = true


func action_label() -> String:
	return "澆水" if _pour <= 0.0 else ""


func flower(index: int) -> Vector3:
	return _spots[index]


func step(delta: float, player: Vector3) -> void:
	_pour = maxf(0.0, _pour - delta)
	var dry := lerpf(SLOW_DRY, FAST_DRY, pace())
	for index in range(_spots.size()):
		if wilted[index] > 0.0:
			wilted[index] -= delta
			if wilted[index] <= 0.0:
				water[index] = 0.8
			continue
		water[index] -= dry * thirst[index] * delta
		if water[index] <= 0.0:
			water[index] = 0.0
			wilted[index] = WILT_SECONDS
			lost += 1
			feedback("miss")
	_draw(player)


func press() -> void:
	if _pour > 0.0:
		return
	var player: Vector3 = world.player.global_position
	_pour = POUR_SECONDS
	_pour_at = player
	var helped := false
	for index in range(_spots.size()):
		if wilted[index] > 0.0 or flat_distance(player, _spots[index]) > WATER_REACH:
			continue
		if water[index] < THIRSTY:
			saved += 1
			add_score(1)
			helped = true
		water[index] = 1.0
	if helped:
		note(saved)
		feedback("hit")
	else:
		wasted += 1
		feedback("miss")
		field.say("還不渴啦", 0.6)


func conclude(medal: int) -> void:
	_droop_all = medal == 0
	_show = 0.0
	_can.visible = false


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(player: Vector3) -> void:
	for index in range(_spots.size()):
		var droop := 0.0
		if _droop_all or wilted[index] > 0.0:
			droop = 1.0
		elif water[index] < THIRSTY:
			droop = 1.0 - water[index] / THIRSTY
		var sway := 0.0 if reduced() else sin(world.time * 2.0 + index) * 0.05
		_stems[index].rotation.z = droop * 0.5 + sway
		_heads[index].rotation.x = droop * 1.2
		_heads[index].scale = Vector3.ONE * (0.55 if wilted[index] > 0.0 else 1.0)
	if _can.visible and player.is_finite():
		var tip := 0.0 if reduced() and _pour <= 0.0 else (0.9 if _pour > 0.0 else 0.0)
		_can.position = player + Vector3(0.42, 1.05, 0.12)
		_can.rotation.z = -tip
	for index in range(_drops.instance_count):
		if _pour <= 0.0 or reduced():
			_drops.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), _pour_at))
			continue
		var age := fmod((POUR_SECONDS - _pour) * 2.5 + index * 0.13, 1.0)
		var out := Vector3(0.6 + index * 0.04, 1.1 - age * 1.1, 0.12 + sin(index * 2.3) * 0.15)
		_drops.set_instance_transform(index, Transform3D(Basis.IDENTITY, _pour_at + out))
