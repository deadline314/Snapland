extends "res://game/world/field/field_game.gd"
## Ducklings have wandered off across the lawn. Bump into one and it falls in
## behind you; lead your little parade into the pond where their mother waits.
## More ducklings come out, they wander faster, and later on the one at the
## back of a long line gets distracted and waddles off again.

enum { AWAY, WANDER, HOME, FOLLOW }

const DUCKS := 5
const POND_RADIUS := 1.05
const FIELD_RADIUS := 3.7
const PICK_REACH := 0.75
const SPACING := 0.55
const FOLLOW_SPEED := 2.2
const WANDER_SPEED := 0.35
const HOME_SECONDS := 1.0
const RESPAWN_SECONDS := 1.2
const DUCK_SIZE := 1.35

var duck := PackedVector2Array()
var state := PackedInt32Array()
var timer := PackedFloat32Array()
## Followers in order, nearest the visitor first.
var line := PackedInt32Array()
var homed := 0
var strays := 0

var _pond := Vector3.ZERO
var _middle := Vector3.ZERO
var _spawns: Array[Vector3] = []
var _sprites: Kit.SpriteBatch
var _wander := PackedVector2Array()
var _stray_in := 0.0
var _parade := false
var _show := 0.0


func build() -> void:
	_middle = centre()
	var layout: Array = spec.get("layout", [])
	_pond = spot(layout[0])
	for index in range(1, layout.size()):
		_spawns.append(spot(layout[index]))
	Kit.cylinder(self, _pond + Vector3(0, 0.03, 0), POND_RADIUS + 0.2, 0.06, world._stone_finish(Color("#8c8572")), -1.0, 18).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := Kit.cylinder(self, _pond + Vector3(0, 0.07, 0), POND_RADIUS, 0.03, Kit.clear_material(world, Color(0.42, 0.68, 0.82, 0.8), 0.1), -1.0, 18)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reed := CylinderMesh.new()
	reed.top_radius = 0.0
	reed.bottom_radius = 0.04
	reed.height = 0.6
	reed.radial_segments = 4
	reed.rings = 1
	var reeds: Array[Transform3D] = []
	for index in range(7):
		var angle := -0.6 - index * 0.28
		reeds.append(Transform3D(Basis(Vector3.FORWARD, sin(index) * 0.15), _pond + Vector3(cos(angle), 0, sin(angle)) * (POND_RADIUS + 0.1) + Vector3(0, 0.3, 0)))
	Kit.batch(self, reed, reeds, world._mat(Color("#6f9a52")))
	# A low hedge ring keeps the ducklings' lawn, open towards the path.
	var hedge := SphereMesh.new()
	hedge.radius = 0.5
	hedge.height = 1.0
	hedge.radial_segments = 8
	hedge.rings = 4
	var hedges: Array[Transform3D] = []
	for index in range(18):
		var angle := TAU * index / 18.0
		if absf(angle - PI * 0.5) < 0.4:
			continue
		hedges.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.36, 0.42)), _middle + Vector3(cos(angle), 0, sin(angle)) * (FIELD_RADIUS + 0.5) + Vector3(0, 0.14, 0)))
	Kit.batch(self, hedge, hedges, world._vertex_color_material("field-hedges"), [Color("#5f8f4e"), Color("#6a9a56")])
	_sprites = Kit.SpriteBatch.new(world, DUCKS + 1)
	add_child(_sprites)
	_sprites.tint(DUCKS, Color(1.25, 1.25, 1.2))
	duck.resize(DUCKS)
	state.resize(DUCKS)
	timer.resize(DUCKS)
	_wander.resize(DUCKS)


func reset() -> void:
	state.fill(AWAY)
	line.clear()
	_parade = false
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	homed = 0
	strays = 0
	state.fill(AWAY)
	timer.fill(0.0)
	line.clear()
	_stray_in = 6.0
	_hatch(0)
	_hatch(1)


func active_limit() -> int:
	return 2 + int(pace() * 3.5)


func _hatch(index: int) -> void:
	var from := _spawns[rng.randi_range(0, _spawns.size() - 1)]
	duck[index] = Vector2(from.x, from.z) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
	state[index] = WANDER
	_wander[index] = Vector2.from_angle(rng.randf() * TAU)


func duck_at(index: int) -> Vector3:
	return Vector3(duck[index].x, _middle.y, duck[index].y)


func pond() -> Vector3:
	return _pond


func step(delta: float, player: Vector3) -> void:
	var me := Vector2(player.x, player.z)
	var hub := Vector2(_middle.x, _middle.z)
	var home := Vector2(_pond.x, _pond.z)
	var out := 0
	for index in range(DUCKS):
		out += int(state[index] != AWAY)
	for index in range(DUCKS):
		timer[index] = maxf(0.0, timer[index] - delta)
		match state[index]:
			AWAY:
				if timer[index] <= 0.0 and out < active_limit():
					_hatch(index)
					out += 1
			WANDER:
				_wander[index] = _wander[index].rotated(rng.randf_range(-2.0, 2.0) * delta)
				# Left alone they would rather play than go home.
				if duck[index].distance_to(home) < POND_RADIUS + 0.8:
					_wander[index] = (duck[index] - home).normalized()
				var next := duck[index] + _wander[index] * WANDER_SPEED * (1.0 + pace() * 1.5) * delta
				if next.distance_to(hub) > FIELD_RADIUS:
					next = hub + (next - hub).limit_length(FIELD_RADIUS)
					_wander[index] = (hub - next).normalized()
				duck[index] = next
				if next.distance_to(me) < PICK_REACH:
					state[index] = FOLLOW
					line.append(index)
					note(line.size())
					feedback("tap")
			HOME:
				duck[index] = duck[index].move_toward(home, 0.8 * delta)
				if timer[index] <= 0.0:
					state[index] = AWAY
					timer[index] = RESPAWN_SECONDS
	_lead(delta, me, home)
	if line.size() >= 2 and pace() > 0.35:
		_stray_in -= delta
		if _stray_in <= 0.0:
			_stray_in = lerpf(7.0, 4.0, pace())
			var last := line[line.size() - 1]
			line.remove_at(line.size() - 1)
			state[last] = WANDER
			_wander[last] = (duck[last] - me).normalized()
			strays += 1
			feedback("miss")
			field.say("有一隻跑去追蝴蝶了！", 0.9)
	_draw(player)


## Followers trail the visitor in a line; any that reach the pond swim home.
func _lead(delta: float, me: Vector2, home: Vector2) -> void:
	var ahead := me
	var index := 0
	while index < line.size():
		var follower := line[index]
		var gap := duck[follower] - ahead
		if gap.length() > SPACING:
			duck[follower] = duck[follower].move_toward(ahead + gap.normalized() * SPACING, FOLLOW_SPEED * delta)
		if duck[follower].distance_to(home) < POND_RADIUS - 0.1:
			line.remove_at(index)
			state[follower] = HOME
			timer[follower] = HOME_SECONDS
			homed += 1
			add_score(1)
			note(homed)
			feedback("hit")
			continue
		ahead = duck[follower]
		index += 1


func conclude(medal: int) -> void:
	# No medal: every duckling decides you are its mother.
	_parade = medal == 0
	_show = 0.0


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(player: Vector3) -> void:
	var t: float = world.time
	_sprites.put(DUCKS, _pond + Vector3(0.3, 0.04, -0.2), "duck", 3, false, DUCK_SIZE * 1.6)
	for index in range(DUCKS):
		var step_frame := 1 if not reduced() and fmod(t * 4.0 + index, 1.0) < 0.5 else 0
		if _parade and player.is_finite():
			_sprites.put(index, player + Vector3(0.55 + index * 0.45, 0.0, 0.25), "duck", step_frame, false, DUCK_SIZE)
			continue
		match state[index]:
			AWAY:
				_sprites.hide_item(index)
			WANDER:
				_sprites.put(index, duck_at(index), "duck", step_frame, _wander[index].x > 0.0, DUCK_SIZE)
			FOLLOW:
				var facing := player.x > duck[index].x if player.is_finite() else false
				_sprites.put(index, duck_at(index), "duck", step_frame, facing, DUCK_SIZE)
			HOME:
				_sprites.put(index, duck_at(index) + Vector3(0, 0.04, 0), "duck", 3, false, DUCK_SIZE)
