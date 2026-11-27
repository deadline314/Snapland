extends "res://game/world/field/field_game.gd"
## A dockside crane swings a crate back and forth over a moored boat. Press
## interact to let go: land it on the stack and the pile grows, miss and it
## splashes into the lagoon. The crane swings faster as the pile grows, and a
## pile that leans too far topples into the water. Three splashes end the day.

enum { CARRY, DROP, RELOAD }

const CRATE := 0.62
## A crate stays on the pile when it lands within this much of the top crate.
const LAND_REACH := 0.4
## Past this lean from the boat's middle the whole pile topples.
const LEAN_LIMIT := 0.55
const SWING := 1.45
const SLOW_SWING := 1.6
const FAST_SWING := 3.6
const HOOK_HEIGHT := 4.4
const FALL_SECONDS := 0.38
const RELOAD_SECONDS := 0.55
const SPLASHES := 3
const MAX_PILE := 8
const DECK_HEIGHT := 0.35
const CRATE_COLORS := [Color("#d9a066"), Color("#c9805a"), Color("#b4925f"), Color("#e2b36e")]

var mode := CARRY
var pile := PackedFloat32Array()
var swing := 0.0
var splashes := 0
var topples := 0
var hook_x := 0.0

var _boat := Vector3.ZERO
var _hull: Node3D
var _hook: Node3D
var _crate: MeshInstance3D
var _stack: MultiMesh
var _drop_from := Vector3.ZERO
var _drop_to := Vector3.ZERO
var _clock := 0.0
var _landed := false
var _show := 0.0
var _sunk := false


func build() -> void:
	var middle := centre()
	var offset: Vector2 = spec.get("boat", Vector2(5, 0))
	_boat = Vector3(middle.x + offset.x, middle.y - 0.25, middle.z + offset.y)
	# The crane: a post on the boardwalk and a boom out over the water.
	var foot := Vector3(_boat.x - 3.2, middle.y, _boat.z - 0.9)
	var posts: Array[Vector3] = [foot]
	Kit.posts(world, self, posts, HOOK_HEIGHT + 0.4, Color("#da705c"), 0.12)
	var boom := Kit.box(self, Vector3(_boat.x - 1.3, middle.y + HOOK_HEIGHT + 0.5, foot.z), Vector3(4.4, 0.2, 0.22), world._wood_material(Color("#8a6a48")))
	boom.rotation.z = 0.04
	_hull = Node3D.new()
	_hull.position = _boat
	add_child(_hull)
	var hull := CylinderMesh.new()
	hull.top_radius = 0.75
	hull.bottom_radius = 0.75
	hull.height = 2.6
	hull.radial_segments = 14
	hull.rings = 1
	var body := Kit.mesh(_hull, hull, Vector3(0, 0, 0), world._coastal_surface(Kit.TILE_RED_BOARD, 0.8))
	body.rotation.z = PI * 0.5
	body.scale = Vector3(0.45, 1.0, 1.0)
	Kit.box(_hull, Vector3(0, DECK_HEIGHT - 0.04, 0), Vector3(2.3, 0.08, 1.2), world._coastal_surface(Kit.TILE_PLANK, 0.6))
	var bow := Kit.cylinder(_hull, Vector3(1.55, 0.02, 0), 0.34, 0.6, world._coastal_surface(Kit.TILE_RED_BOARD, 0.8), 0.0, 10)
	bow.rotation.z = -PI * 0.5
	bow.scale = Vector3(1.0, 1.0, 1.6)
	var crate := BoxMesh.new()
	crate.size = Vector3(CRATE, CRATE, CRATE)
	var wood: Material = world._coastal_surface(Kit.TILE_PLANK, 0.5, Color("#e6c79a"))
	var hidden: Array[Transform3D] = []
	for index in range(MAX_PILE):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_stack = Kit.batch(_hull, crate, hidden, wood).multimesh
	_hook = Node3D.new()
	add_child(_hook)
	var rope := Kit.cylinder(_hook, Vector3(0, 0.9, 0), 0.02, 1.8, world._mat(Color("#d9c9a3")), -1.0, 5)
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.ball(_hook, Vector3(0, 0.02, 0), 0.07, world._coastal_surface(Kit.TILE_BRASS, 0.4))
	_crate = Kit.mesh(self, crate, Vector3.ZERO, wood)


func reset() -> void:
	mode = CARRY
	pile.clear()
	swing = 0.0
	hook_x = _boat.x
	_sunk = false
	_show = 0.0
	_draw()


func begin() -> void:
	splashes = 0
	topples = 0
	pile.clear()
	mode = CARRY
	swing = rng.randf() * TAU


func action_label() -> String:
	return "放貨" if mode == CARRY else ""


## The x of the top of the pile (or of the deck), across the boat.
func top_x() -> float:
	return _boat.x + (pile[pile.size() - 1] if not pile.is_empty() else 0.0)


func step(delta: float, _player: Vector3) -> void:
	var speed := lerpf(SLOW_SWING, FAST_SWING, clampf(pace() * 0.6 + pile.size() / float(MAX_PILE) * 0.6, 0.0, 1.0))
	swing += delta * speed
	hook_x = _boat.x + sin(swing) * SWING
	_clock += delta
	match mode:
		DROP:
			if _clock >= FALL_SECONDS:
				_settle()
		RELOAD:
			if _clock >= RELOAD_SECONDS:
				mode = CARRY
	_draw()


func press() -> void:
	if mode != CARRY:
		return
	mode = DROP
	_clock = 0.0
	_drop_from = Vector3(hook_x, _boat.y + HOOK_HEIGHT - CRATE * 0.5, _boat.z)
	var offset := hook_x - top_x()
	_landed = absf(offset) <= LAND_REACH and pile.size() < MAX_PILE
	var height := DECK_HEIGHT + CRATE * (pile.size() + 0.5)
	_drop_to = Vector3(hook_x, _boat.y + (height if _landed else -0.8), _boat.z)


func _settle() -> void:
	mode = RELOAD
	_clock = 0.0
	if not _landed:
		splashes += 1
		feedback("miss")
		field.say("撲通！", 0.8)
		if splashes >= SPLASHES:
			finish()
		return
	pile.append(hook_x - _boat.x)
	add_score(1)
	note(pile.size())
	feedback("hit")
	if absf(pile[pile.size() - 1]) > LEAN_LIMIT or pile.size() >= MAX_PILE:
		# A leaning pile topples; a full one sails off to be unloaded.
		var full := pile.size() >= MAX_PILE and absf(pile[pile.size() - 1]) <= LEAN_LIMIT
		if not full:
			topples += 1
			feedback("miss")
		field.say("滿載出航！" if full else "整疊倒了！", 1.0)
		pile.clear()


func conclude(medal: int) -> void:
	_sunk = medal == 0
	_show = 0.0
	_draw()


func show_step(delta: float, _player: Vector3) -> void:
	_show += delta
	_draw()


func _draw() -> void:
	var bob := 0.0 if reduced() else sin(world.time * 1.6) * 0.05
	_hull.position = _boat + Vector3(0, bob, 0)
	_hull.rotation.x = 0.0 if reduced() else sin(world.time * 1.1) * 0.03
	if _sunk:
		# The boat lists and slips under, crate by crate.
		var sink := 0.0 if reduced() else minf(_show * 0.3, 0.9)
		_hull.position.y -= sink
		_hull.rotation.z = 0.0 if reduced() else minf(_show * 0.2, 0.35)
	else:
		_hull.rotation.z = 0.0
	for index in range(MAX_PILE):
		if index < pile.size():
			_stack.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(pile[index], DECK_HEIGHT + CRATE * (index + 0.5), 0)))
		else:
			_stack.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_hook.position = Vector3(hook_x, _boat.y + HOOK_HEIGHT, _boat.z)
	_hook.rotation.z = 0.0 if reduced() else cos(swing) * 0.12
	_crate.visible = mode != RELOAD
	match mode:
		CARRY:
			_crate.position = Vector3(hook_x, _boat.y + HOOK_HEIGHT - CRATE * 0.5, _boat.z)
			_crate.rotation = Vector3(0, 0, _hook.rotation.z)
		DROP:
			var along := clampf(_clock / FALL_SECONDS, 0.0, 1.0)
			_crate.position = _drop_from.lerp(_drop_to, along * along)
			_crate.rotation = Vector3.ZERO if _landed else Vector3(0, 0, along * 1.2)
