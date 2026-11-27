extends RefCounted
## Deterministic simulation of pooled ambience animals. It owns no nodes: the
## ambience layer reads the public arrays once per frame and writes them into
## two batches. Every array is sized in setup(); advance() allocates nothing.

const Profiles = preload("res://game/world/ambience_profiles.gd")
const Sprites = preload("res://game/world/ambience_sprites.gd")

enum Behavior { GROUND_BIRD, GLIDER, FLUTTER }
enum State { IDLE, PECK, HOP, FLEE, AWAY, RETURN }

const BEHAVIORS := {"ground_bird": Behavior.GROUND_BIRD, "glider": Behavior.GLIDER, "flutter": Behavior.FLUTTER}
const FRAME_STAND := 0
const FRAME_PECK := 1
const FRAME_WING_UP := 2
const FRAME_WING_DOWN := 3
const HOP_SPEED := 0.9
const HOP_LENGTH := 0.2
const HOP_HEIGHT := 0.06
const FLAP_RATE := 5.5
const SEED := 20261127


class Flock:
	var kind := ""
	var behavior := Behavior.GROUND_BIRD
	var first := 0
	var count := 0
	var center := Vector3.ZERO
	var spread := 1.0
	var ground := 0.0
	var phases: Array = []
	var active := true
	var flee_radius_squared := 0.0
	var return_radius_squared := 0.0
	var fly_speed := 6.0
	var spec: Dictionary = {}
	var definition: Dictionary = {}


var count := 0
var flocks: Array[Flock] = []
# Read by the ambience layer every frame.
var position := PackedVector3Array()
var ground := PackedFloat32Array()
var visible_scale := PackedFloat32Array()
var frame := PackedInt32Array()
var mirrored := PackedByteArray()
# Fixed per critter after setup().
var size := PackedVector2Array()
var sprite_row := PackedInt32Array()
var tint := PackedColorArray()
var shadow_width := PackedFloat32Array()
var state := PackedInt32Array()

var _world: Node
var _water_y := -INF
var _reduced_motion := false
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _spot := PackedVector3Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _clock := PackedFloat32Array()
var _span := PackedFloat32Array()
var _phase := PackedFloat32Array()


func setup(region_profile: Dictionary, world: Node) -> void:
	_world = world
	_water_y = float(region_profile.get("water_y", -INF))
	_rng.seed = SEED
	for group: Dictionary in region_profile.get("critters", []):
		var kind := String(group.get("kind", ""))
		if not Profiles.CRITTER_KINDS.has(kind):
			push_warning("Ambience critter kind '%s' is not defined; the group was skipped." % kind)
			continue
		var definition: Dictionary = Profiles.CRITTER_KINDS[kind]
		var flock := Flock.new()
		flock.kind = kind
		flock.spec = group
		flock.definition = definition
		flock.behavior = int(BEHAVIORS.get(definition.get("behavior", "ground_bird"), Behavior.GROUND_BIRD))
		flock.first = count
		flock.count = int(group.get("count", 0))
		flock.center = group.get("at", Vector3.ZERO)
		flock.spread = float(group.get("spread", 1.0))
		flock.ground = _ground_under(flock.center)
		flock.center.y = flock.ground
		flock.phases = group.get("phases", definition.get("phases", Profiles.ALWAYS))
		flock.flee_radius_squared = pow(float(definition.get("flee_radius", 2.5)), 2.0)
		flock.return_radius_squared = pow(float(definition.get("return_radius", 5.0)), 2.0)
		flock.fly_speed = float(definition.get("fly_speed", 6.0))
		flocks.append(flock)
		count += flock.count
	_resize(count)
	for flock in flocks:
		var definition := flock.definition
		var group := flock.spec
		var density := float(definition.get("pixels_per_metre", Profiles.PIXELS_PER_METRE))
		var tints: Array = group.get("tints", definition.get("tints", [Color.WHITE]))
		for index in range(flock.first, flock.first + flock.count):
			size[index] = Vector2(Sprites.CELL) / density
			sprite_row[index] = Sprites.critter_row(String(definition.get("sprite", flock.kind)))
			tint[index] = tints[index % tints.size()]
			shadow_width[index] = float(definition.get("shadow", 0.2))
			_phase[index] = _rng.randf()
			ground[index] = flock.ground
			visible_scale[index] = 1.0
			match flock.behavior:
				Behavior.GROUND_BIRD:
					_spot[index] = _random_spot(flock)
					position[index] = _spot[index]
					mirrored[index] = int(_rng.randf() < 0.5)
					_rest(index)
				Behavior.GLIDER:
					var height := float(group.get("height", 4.5)) + _rng.randf_range(-0.6, 0.6)
					var reach := flock.spread * _rng.randf_range(0.6, 1.0)
					_spot[index] = flock.center + Vector3(_rng.randf_range(-1.5, 1.5), height, _rng.randf_range(-1.5, 1.5))
					# x/z are the loop radii, y the gentle bob.
					_from[index] = Vector3(reach, 0.3, reach * _rng.randf_range(0.5, 0.75))
					_span[index] = flock.fly_speed / reach * (1.0 if index % 2 == 0 else -1.0)
					_clock[index] = _phase[index] * TAU
				Behavior.FLUTTER:
					_spot[index] = _random_spot(flock) + Vector3(0, float(group.get("height", 0.75)), 0)
					_span[index] = _rng.randf_range(0.55, 0.95)
					position[index] = _spot[index]
	advance(0.0, Vector3(INF, 0, INF))


func set_phase(phase: String) -> void:
	for flock in flocks:
		var active := flock.phases.has(phase)
		if active and not flock.active and flock.behavior == Behavior.GROUND_BIRD:
			_settle(flock)
		flock.active = active
		for index in range(flock.first, flock.first + flock.count):
			if not active:
				visible_scale[index] = 0.0
			elif flock.behavior != Behavior.GROUND_BIRD or state[index] <= State.HOP:
				visible_scale[index] = 1.0


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if not value:
		return
	# Nothing may dart about once motion is reduced: birds are simply perched.
	for flock in flocks:
		if flock.behavior == Behavior.GROUND_BIRD:
			_settle(flock)


## A flock is "home" while every bird is on the ground.
func flock_is_home(flock_index: int) -> bool:
	var flock := flocks[flock_index]
	for index in range(flock.first, flock.first + flock.count):
		if state[index] > State.HOP:
			return false
	return true


func advance(delta: float, player: Vector3) -> void:
	if _reduced_motion:
		return
	_time += delta
	for flock in flocks:
		if not flock.active:
			continue
		match flock.behavior:
			Behavior.GROUND_BIRD: _advance_ground_birds(flock, delta, player)
			Behavior.GLIDER: _advance_gliders(flock, delta)
			Behavior.FLUTTER: _advance_flutter(flock)


func _advance_ground_birds(flock: Flock, delta: float, player: Vector3) -> void:
	var last := flock.first + flock.count
	# One startled bird lifts the whole flock.
	var alarmed := false
	for index in range(flock.first, last):
		if state[index] <= State.HOP and _flat_distance_squared(position[index], player) < flock.flee_radius_squared:
			alarmed = true
			break
	var calm := _flat_distance_squared(flock.center, player) > flock.return_radius_squared
	for index in range(flock.first, last):
		match state[index]:
			State.IDLE, State.PECK, State.HOP:
				if alarmed:
					_take_off(index, flock, player)
				else:
					_advance_grounded(index, flock, delta)
			State.FLEE:
				if _advance_flight(index, delta, true):
					state[index] = State.AWAY
					visible_scale[index] = 0.0
					_clock[index] = 0.0
					_span[index] = _rng.randf_range(1.4, 3.4)
			State.AWAY:
				_clock[index] = _clock[index] + delta if calm else 0.0
				if _clock[index] >= _span[index]:
					_fly_home(index, flock, player)
			State.RETURN:
				if _flat_distance_squared(_to[index], player) < flock.flee_radius_squared:
					_take_off(index, flock, player)
				elif _advance_flight(index, delta, false):
					position[index] = _to[index]
					_spot[index] = _to[index]
					visible_scale[index] = 1.0
					_rest(index)


func _advance_grounded(index: int, flock: Flock, delta: float) -> void:
	_clock[index] += delta
	match state[index]:
		State.IDLE:
			frame[index] = FRAME_STAND
			if _clock[index] >= _span[index]:
				_choose_ground_action(index, flock)
		State.PECK:
			frame[index] = FRAME_PECK if fmod(_clock[index], 0.38) < 0.22 else FRAME_STAND
			if _clock[index] >= _span[index]:
				_rest(index)
		State.HOP:
			var progress := minf(1.0, _clock[index] / _span[index])
			var from := _from[index]
			var to := _to[index]
			var hops := maxf(1.0, roundf(_span[index] * HOP_SPEED / HOP_LENGTH))
			position[index] = Vector3(lerpf(from.x, to.x, progress), from.y + absf(sin(progress * hops * PI)) * HOP_HEIGHT, lerpf(from.z, to.z, progress))
			frame[index] = FRAME_STAND
			if progress >= 1.0:
				position[index] = to
				_spot[index] = to
				_rest(index)


func _choose_ground_action(index: int, flock: Flock) -> void:
	var roll := _rng.randf()
	if roll < 0.45:
		state[index] = State.PECK
		_clock[index] = 0.0
		_span[index] = _rng.randf_range(0.7, 1.7)
		return
	if roll < 0.8:
		var target := _random_spot(flock)
		var distance := position[index].distance_to(target)
		if distance > 0.15:
			state[index] = State.HOP
			_from[index] = position[index]
			_to[index] = target
			_clock[index] = 0.0
			_span[index] = distance / HOP_SPEED
			mirrored[index] = int(target.x < position[index].x)
			return
	if roll > 0.9:
		mirrored[index] = 1 - mirrored[index]
	_rest(index)


func _take_off(index: int, flock: Flock, player: Vector3) -> void:
	var here := position[index]
	var away := Vector2(here.x - player.x, here.z - player.z)
	var distance := away.length()
	away = (away / distance if distance > 0.01 else Vector2.RIGHT).rotated(_rng.randf_range(-0.55, 0.55))
	var reach := _rng.randf_range(20.0, 25.0)
	_from[index] = here
	_to[index] = Vector3(here.x + away.x * reach, here.y + _rng.randf_range(6.0, 8.0), here.z + away.y * reach)
	_span[index] = reach / flock.fly_speed
	if state[index] == State.RETURN:
		_clock[index] = 0.0
	else:
		# Nearer birds notice first, so the flock lifts as a ripple instead of in unison.
		_clock[index] = -minf(0.3, distance * 0.07) - _rng.randf() * 0.08
		frame[index] = FRAME_STAND
	state[index] = State.FLEE


func _fly_home(index: int, flock: Flock, player: Vector3) -> void:
	var landing := _random_spot(flock)
	# Arrive from the side the player is not on.
	var away := Vector2(flock.center.x - player.x, flock.center.z - player.z)
	var distance := away.length()
	away = (away / distance if distance > 0.01 and is_finite(distance) else Vector2.RIGHT).rotated(_rng.randf_range(-0.6, 0.6))
	var reach := _rng.randf_range(18.0, 23.0)
	_from[index] = Vector3(landing.x + away.x * reach, landing.y + _rng.randf_range(6.0, 8.0), landing.z + away.y * reach)
	_to[index] = landing
	_span[index] = reach / flock.fly_speed
	_clock[index] = 0.0
	state[index] = State.RETURN


## Moves one bird along its flight; true once it has arrived.
func _advance_flight(index: int, delta: float, leaving: bool) -> bool:
	_clock[index] += delta
	if _clock[index] < 0.0:
		return false
	var progress := minf(1.0, _clock[index] / _span[index])
	var from := _from[index]
	var to := _to[index]
	var along := progress
	var climb := progress
	if leaving:
		along = lerpf(progress, progress * progress, 0.5)
		climb = 1.0 - (1.0 - progress) * (1.0 - progress)
		visible_scale[index] = 1.0 - smoothstep(0.78, 1.0, progress)
	else:
		along = 1.0 - (1.0 - progress) * (1.0 - progress)
		climb = smoothstep(0.0, 1.0, progress)
		visible_scale[index] = smoothstep(0.0, 0.14, progress)
	position[index] = Vector3(lerpf(from.x, to.x, along), lerpf(from.y, to.y, climb), lerpf(from.z, to.z, along))
	frame[index] = FRAME_WING_UP if fmod(_clock[index] * FLAP_RATE + _phase[index], 1.0) < 0.5 else FRAME_WING_DOWN
	mirrored[index] = int(to.x < from.x)
	return progress >= 1.0


func _advance_gliders(flock: Flock, delta: float) -> void:
	for index in range(flock.first, flock.first + flock.count):
		_clock[index] += _span[index] * delta
		var angle := _clock[index]
		var radii := _from[index]
		var centre := _spot[index]
		position[index] = Vector3(
			centre.x + cos(angle) * radii.x,
			centre.y + sin(angle * 2.0 + _phase[index] * TAU) * radii.y,
			centre.z + sin(angle) * radii.z)
		mirrored[index] = int(sin(angle) * _span[index] > 0.0)
		# Mostly gliding, with a short burst of wingbeats now and then.
		if fposmod(_time * 0.17 + _phase[index], 1.0) < 0.22:
			frame[index] = 1 if fmod(_time * 3.6 + _phase[index], 1.0) < 0.5 else 2
		else:
			frame[index] = 0
		ground[index] = maxf(_ground_under(position[index]), _water_y)


func _advance_flutter(flock: Flock) -> void:
	for index in range(flock.first, flock.first + flock.count):
		var offset := _phase[index]
		var beat := _time * (0.8 + offset * 0.5) + offset * 40.0
		var reach := _span[index]
		var anchor := _spot[index]
		var previous_x := position[index].x
		position[index] = Vector3(
			anchor.x + sin(beat * 0.83 + offset * 9.0) * reach + sin(beat * 2.9) * 0.12,
			anchor.y + sin(beat * 1.37 + offset * 3.0) * 0.26 + sin(beat * 6.1) * 0.05,
			anchor.z + cos(beat * 0.61 + offset * 5.0) * reach * 0.75)
		mirrored[index] = int(position[index].x < previous_x)
		# Open, half, closed, half.
		var wing := fmod(_time * 9.0 + offset * 4.0, 4.0)
		frame[index] = 0 if wing < 1.0 else (2 if wing >= 2.0 and wing < 3.0 else 1)


func _settle(flock: Flock) -> void:
	for index in range(flock.first, flock.first + flock.count):
		if state[index] == State.RETURN:
			_spot[index] = _to[index]
		position[index] = _spot[index]
		visible_scale[index] = 1.0
		_rest(index)


func _rest(index: int) -> void:
	state[index] = State.IDLE
	frame[index] = FRAME_STAND
	_clock[index] = 0.0
	_span[index] = _rng.randf_range(0.5, 2.4)


func _random_spot(flock: Flock) -> Vector3:
	var angle := _rng.randf() * TAU
	var reach := sqrt(_rng.randf()) * flock.spread
	return Vector3(flock.center.x + cos(angle) * reach, flock.ground, flock.center.z + sin(angle) * reach)


func _ground_under(at: Vector3) -> float:
	return float(_world.ground_surface_y(at)) if is_instance_valid(_world) and _world.has_method("ground_surface_y") else 0.0


func _resize(total: int) -> void:
	position.resize(total)
	ground.resize(total)
	visible_scale.resize(total)
	frame.resize(total)
	mirrored.resize(total)
	size.resize(total)
	sprite_row.resize(total)
	tint.resize(total)
	shadow_width.resize(total)
	state.resize(total)
	_spot.resize(total)
	_from.resize(total)
	_to.resize(total)
	_clock.resize(total)
	_span.resize(total)
	_phase.resize(total)


static func _flat_distance_squared(a: Vector3, b: Vector3) -> float:
	var x := a.x - b.x
	var z := a.z - b.z
	return x * x + z * z
