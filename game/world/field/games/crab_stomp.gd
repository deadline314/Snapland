extends "res://game/world/field/field_game.gd"
## Crabs pop out of holes in a sand pit; run onto one to bonk it back in.
## They come faster and hide sooner as the round goes on. Standing still
## summons the big red crab under your feet, and it pinches.

enum { HIDDEN, RUMBLE, UP, BONKED }

const BONK_REACH := 0.6
const PINCH_REACH := 0.8
const STILL_SPEED := 0.3
const CAMP_SECONDS := 1.0
const RUMBLE_SECONDS := 0.6
const STUN_SECONDS := 1.1
const RED_TINT := Color(1.25, 0.5, 0.52)
const PIT_RADIUS := 3.3
## Drawn a little over life size so a crab reads at a glance from the park camera.
const CRAB_SIZE := 1.35
const RED_SIZE := 1.75

var holes := PackedVector3Array()
var state := PackedInt32Array()
var timer := PackedFloat32Array()
var red := -1
var pinches := 0
var stunned := 0.0

var _crabs: Kit.SpriteBatch
var _spawn_in := 0.0
var _still := 0.0
var _last_player := Vector3.ZERO
var _combo := 0
var _party := false
var _show_clock := 0.0


func build() -> void:
	var middle := centre()
	var pit := Kit.cylinder(self, middle + Vector3(0, 0.025, 0), PIT_RADIUS, 0.05, Kit.sand_material(world), -1.0, 28)
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A low timber kerb keeps the sand off the lawn.
	var kerb := BoxMesh.new()
	kerb.size = Vector3(0.78, 0.14, 0.16)
	var kerbs: Array[Transform3D] = []
	for index in range(28):
		var angle := TAU * index / 28.0
		kerbs.append(Transform3D(Basis.from_euler(Vector3(0, -angle + PI * 0.5, 0)), middle + Vector3(cos(angle) * PIT_RADIUS, 0.07, sin(angle) * PIT_RADIUS)))
	Kit.batch(self, kerb, kerbs, world._wood_material(Color("#9b7a52")))
	var burrow := CylinderMesh.new()
	burrow.top_radius = 0.33
	burrow.bottom_radius = 0.33
	burrow.height = 0.012
	burrow.radial_segments = 10
	burrow.rings = 1
	var burrows: Array[Transform3D] = []
	for offset: Vector2 in spec.get("layout", []):
		var hole := spot(offset)
		hole.y = middle.y + 0.05
		holes.append(hole)
		burrows.append(Transform3D(Basis.IDENTITY, hole + Vector3(0, 0.004, 0)))
	Kit.batch(self, burrow, burrows, world._mat(Color("#7a6644"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	state.resize(holes.size())
	timer.resize(holes.size())
	_crabs = Kit.SpriteBatch.new(world, holes.size())
	add_child(_crabs)


func reset() -> void:
	state.fill(HIDDEN)
	timer.fill(0.0)
	red = -1
	stunned = 0.0
	_party = false
	_draw()


func begin() -> void:
	pinches = 0
	_combo = 0
	_still = 0.0
	_spawn_in = 0.35
	_last_player = Vector3(INF, 0, INF)


func step(delta: float, player: Vector3) -> void:
	var speed := 0.0 if _last_player.x == INF else flat_distance(player, _last_player) / maxf(delta, 0.0001)
	_last_player = player
	stunned = maxf(0.0, stunned - delta)
	_still = _still + delta if speed < STILL_SPEED else 0.0
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = lerpf(1.1, 0.5, pace())
		_pop(_free_hole(player), lerpf(2.6, 1.4, pace()))
	if _still >= CAMP_SECONDS and red < 0 and stunned <= 0.0:
		_call_red(player)
	for index in range(holes.size()):
		if state[index] == HIDDEN:
			continue
		timer[index] -= delta
		var near := flat_distance(player, holes[index])
		match state[index]:
			RUMBLE:
				if timer[index] <= 0.0:
					state[index] = UP
					timer[index] = 1.7
					if near < PINCH_REACH and speed < STILL_SPEED:
						_pinch()
			UP:
				if near < BONK_REACH and stunned <= 0.0:
					_bonk(index)
				elif timer[index] <= 0.0:
					_hide(index)
			BONKED:
				if timer[index] <= 0.0:
					_hide(index)
	_draw()


func _free_hole(player: Vector3) -> int:
	# Never under the player's feet: a free point would not be a stomp.
	var start := rng.randi_range(0, holes.size() - 1)
	for step_index in range(holes.size()):
		var index := (start + step_index) % holes.size()
		if state[index] == HIDDEN and flat_distance(player, holes[index]) > 1.0:
			return index
	return -1


func _pop(index: int, stay: float) -> void:
	if index < 0:
		return
	state[index] = UP
	timer[index] = stay


func _call_red(player: Vector3) -> void:
	var nearest := -1
	var best := INF
	for index in range(holes.size()):
		var near := flat_distance(player, holes[index])
		if state[index] == HIDDEN and near < best:
			best = near
			nearest = index
	if nearest < 0:
		return
	red = nearest
	state[nearest] = RUMBLE
	timer[nearest] = RUMBLE_SECONDS
	_still = 0.0


func _pinch() -> void:
	pinches += 1
	stunned = STUN_SECONDS
	_combo = 0
	hop(0.45, STUN_SECONDS, 3)
	feedback("miss")
	field.say("被夾到了！", 1.0)


func _bonk(index: int) -> void:
	state[index] = BONKED
	timer[index] = 0.35
	add_score(1)
	note(_combo)
	_combo += 1
	feedback("hit")


func _hide(index: int) -> void:
	state[index] = HIDDEN
	if index == red:
		red = -1


func conclude(medal: int) -> void:
	# With no medal every crab comes out to gloat.
	_party = medal == 0
	_show_clock = 0.0
	if not _party:
		state.fill(HIDDEN)
		red = -1
	_draw()


func show_step(delta: float, _player: Vector3) -> void:
	_show_clock += delta
	_draw()


func _draw() -> void:
	# The red crab is drawn a step toward the camera so the avatar never hides it.
	var front: Vector3 = world.camera.global_basis.z * 0.45 if is_instance_valid(world.camera) else Vector3.ZERO
	front.y = 0.0
	for index in range(holes.size()):
		var big := index == red
		_crabs.tint(index, RED_TINT if big else Color.WHITE)
		var size := RED_SIZE if big else CRAB_SIZE
		if _party:
			var wave := 2 if reduced() or fmod(_show_clock * 3.0 + index * 0.37, 1.0) < 0.5 else 1
			_crabs.put(index, holes[index], "crab", wave, index % 2 == 0, CRAB_SIZE)
			continue
		match state[index]:
			HIDDEN:
				_crabs.hide_item(index)
			RUMBLE:
				var shake := 0.0 if reduced() else sin(timer[index] * 60.0) * 0.04
				_crabs.put(index, holes[index] + front + Vector3(shake, 0, 0), "crab", 0, false, size)
			UP:
				var claws := big or (not reduced() and fmod(timer[index] * 2.5, 1.0) < 0.4)
				_crabs.put(index, holes[index] + (front if big else Vector3.ZERO), "crab", 2 if claws else 1, index % 2 == 0, size)
			BONKED:
				_crabs.put(index, holes[index], "crab", 3, false, size)
