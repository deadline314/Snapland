extends "res://game/world/field/field_game.gd"
## A round dolly track on a film set. The star runs laps of it; the camera
## dolly only moves when you push it from behind. Keep the star between the
## dolly's two yellow frame flags: every half second in frame is a point. Push
## too hard and you ram the star (NG!); push too little and the star runs out
## of shot. The star speeds up, stops dead and sprints as the take goes on.

const PUSH_GAP := 0.9
const PUSH_BAND := 0.95
const FRAME_NEAR := 1.3
const FRAME_FAR := 3.6
const BUMP := 0.75
const START_GAP := 2.3
const SLOW_RUN := 0.55
const FAST_RUN := 1.3
const SPRINT := 1.15
const POINT_SECONDS := 0.5
const NG_SECONDS := 1.0
## Where the track starts: due south of the middle, facing the camera.
const START_ANGLE := PI * 0.5

var dolly_s := 0.0
var actor_s := 0.0
var actor_speed := 0.0
var framed_time := 0.0
var bumps := 0

var _middle := Vector3.ZERO
var _radius := 3.2
var _mood := 1.0
var _mood_left := 0.0
var _ng := 0.0
var _dolly: Node3D
var _actor: Node3D
var _legs: Array[Node3D] = []
var _rec: MeshInstance3D
var _flags: Array[Node3D] = []
var _rec_on: Material
var _rec_off: Material
var _show := 0.0
var _wrapped := false
var _took_bow := false


func build() -> void:
	_middle = centre()
	_radius = float(spec.get("track_radius", 3.2))
	# Two rails and the sleepers under them.
	for offset: float in [-0.32, 0.32]:
		var ring := PackedVector3Array()
		for index in range(65):
			var angle := TAU * float(index) / 64.0
			ring.append(_middle + Vector3(cos(angle), 0, sin(angle)) * (_radius + offset) + Vector3(0, 0.1, 0))
		Kit.mesh(self, Kit.tube(ring, 0.035, Vector3.UP, 5), Vector3.ZERO, world._coastal_surface(Kit.TILE_BRASS, 0.3), false)
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(0.95, 0.06, 0.16)
	var sleepers: Array[Transform3D] = []
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		sleepers.append(Transform3D(Basis(Vector3.UP, -angle), _middle + Vector3(cos(angle), 0, sin(angle)) * _radius + Vector3(0, 0.05, 0)))
	Kit.batch(self, sleeper, sleepers, world._vertex_color_material("field-sleepers"), [Color("#6e4c32"), Color("#7a5638")])
	_build_dolly()
	_build_actor()
	_build_flags()


func _build_dolly() -> void:
	_dolly = Node3D.new()
	add_child(_dolly)
	Kit.box(_dolly, Vector3(0, 0.3, 0), Vector3(0.62, 0.22, 0.9), world._coastal_surface(Kit.TILE_RED_BOARD, 0.4, Color("#b8c6d8")))
	for corner: Vector2 in [Vector2(-0.32, -0.34), Vector2(0.32, -0.34), Vector2(-0.32, 0.34), Vector2(0.32, 0.34)]:
		var wheel := Kit.cylinder(_dolly, Vector3(corner.x, 0.17, corner.y), 0.1, 0.06, world._mat(Color("#2e2a33")), -1.0, 10)
		wheel.rotation.z = PI * 0.5
	Kit.cylinder(_dolly, Vector3(0, 0.75, 0.05), 0.04, 0.7, world._mat(Color("#6d7380")), -1.0, 6)
	Kit.box(_dolly, Vector3(0, 1.18, 0.05), Vector3(0.3, 0.26, 0.44), world._mat(Color("#2e2a33")))
	var lens := Kit.cylinder(_dolly, Vector3(0, 1.18, -0.24), 0.08, 0.16, world._mat(Color("#41455a")), 0.1, 8)
	lens.rotation.x = PI * 0.5
	for reel: float in [-0.04, 0.16]:
		var spool := Kit.cylinder(_dolly, Vector3(0, 1.4, reel), 0.1, 0.04, world._mat(Color("#9aa1ab")), -1.0, 10)
		spool.rotation.z = PI * 0.5
	Kit.box(_dolly, Vector3(0, 0.62, 0.36), Vector3(0.3, 0.06, 0.24), world._mat(Color("#a8243a")))
	_rec_on = world._mat(Color("#ff5a4a"), true)
	_rec_off = world._mat(Color("#5a3a3a"))
	_rec = Kit.ball(_dolly, Vector3(0.12, 1.34, -0.1), 0.04, _rec_off)


## The star: legs that run, a striped costume, a big head in sunglasses and a beret.
func _build_actor() -> void:
	_actor = Node3D.new()
	add_child(_actor)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.09, 0.5, 0)
		_actor.add_child(hip)
		Kit.box(hip, Vector3(0, -0.24, 0), Vector3(0.1, 0.48, 0.12), world._mat(Color("#2f3a5a")))
		_legs.append(hip)
	Kit.cylinder(_actor, Vector3(0, 0.78, 0), 0.2, 0.6, world._coastal_surface(Kit.TILE_CANVAS, 0.25, Color("#ffd8d0")), 0.16, 10)
	Kit.ball(_actor, Vector3(0, 1.26, 0), 0.22, world._mat(Color("#f2c9a0")))
	Kit.box(_actor, Vector3(0, 1.28, -0.19), Vector3(0.3, 0.07, 0.05), world._mat(Color("#2e2a33")))
	Kit.cylinder(_actor, Vector3(0, 1.45, 0), 0.2, 0.06, world._mat(Color("#a8243a")), 0.18, 10)
	Kit.box(_actor, Vector3(0.12, 0.98, -0.18), Vector3(0.12, 0.3, 0.04), world._mat(Color("#f2c75a")))


## Two little yellow flags on the rail ahead of the dolly: the edges of the shot.
func _build_flags() -> void:
	for index in range(2):
		var flag := Node3D.new()
		add_child(flag)
		Kit.box(flag, Vector3(0, 0.45, 0), Vector3(0.04, 0.9, 0.04), world._mat(Color("#6e4c32")))
		Kit.box(flag, Vector3(0, 0.8, 0.12), Vector3(0.02, 0.18, 0.24), world._mat(Color("#f2c75a")))
		_flags.append(flag)


func reset() -> void:
	dolly_s = 0.0
	actor_s = START_GAP
	actor_speed = 0.0
	_ng = 0.0
	_wrapped = false
	_took_bow = false
	_draw(0.0)


func begin() -> void:
	dolly_s = 0.0
	actor_s = START_GAP
	framed_time = 0.0
	bumps = 0
	_mood = 1.0
	_mood_left = 1.5
	_ng = 0.0


## A point on the track `s` metres round from the start.
func track_point(s: float) -> Vector3:
	var angle := START_ANGLE + s / _radius
	var at := _middle + Vector3(cos(angle), 0, sin(angle)) * _radius
	at.y = world.ground_surface_y(at)
	return at


func circumference() -> float:
	return TAU * _radius


## How far round the track `point` lies (0 up to one lap), and how far it is from the rail.
func track_s(point: Vector3) -> float:
	var angle := atan2(point.z - _middle.z, point.x - _middle.x)
	return wrapf(angle - START_ANGLE, 0.0, TAU) * _radius


## How far `point` is from the middle of the rails.
func rail_offset(point: Vector3) -> float:
	return absf(Vector2(point.x - _middle.x, point.z - _middle.z).length() - _radius)


func in_frame() -> bool:
	var gap := actor_s - dolly_s
	return gap >= FRAME_NEAR and gap <= FRAME_FAR


func step(delta: float, player: Vector3) -> void:
	_run_actor(delta)
	# A push from behind rolls the dolly on.
	if rail_offset(player) < PUSH_BAND:
		var behind := fposmod(dolly_s - track_s(player), circumference())
		if behind < PUSH_GAP:
			dolly_s += PUSH_GAP - behind
	_ng = maxf(_ng - delta, 0.0)
	var gap := actor_s - dolly_s
	if gap < BUMP and _ng <= 0.0:
		# Rammed: the star tumbles forward and the take is spoiled for a moment.
		bumps += 1
		_ng = NG_SECONDS
		actor_s += 1.2
		feedback("miss")
		field.say("NG！撞到主角了", 0.8)
	elif in_frame() and _ng <= 0.0:
		var before := int(framed_time / POINT_SECONDS)
		framed_time += delta
		if int(framed_time / POINT_SECONDS) > before:
			add_score(1)
			if score % 8 == 0:
				note(score / 8)
	_draw(delta)


## The star's pace: faster as the take goes on, with sudden stops and sprints.
func _run_actor(delta: float) -> void:
	_mood_left -= delta
	if _mood_left <= 0.0:
		var roll := rng.randf()
		if pace() > 0.15 and roll < 0.2:
			_mood = 0.0
			_mood_left = 0.7
		elif pace() > 0.3 and roll < 0.45:
			_mood = SPRINT
			_mood_left = 1.4
		else:
			_mood = 1.0
			_mood_left = rng.randf_range(1.6, 2.8)
	actor_speed = lerpf(SLOW_RUN, FAST_RUN, pace()) * _mood
	actor_s += actor_speed * delta


func conclude(medal: int) -> void:
	_wrapped = medal > 0
	_show = 0.0
	_took_bow = false


func show_step(delta: float, _player: Vector3) -> void:
	_show += delta
	if not _wrapped and not reduced():
		# No medal: the star runs off the set and the camera droops.
		actor_s += 2.2 * delta
	_draw(delta)


func _draw(delta: float) -> void:
	_place(_dolly, dolly_s, 0.0)
	if not _wrapped and _show > 0.0 and not reduced():
		_dolly.rotation.x = -minf(_show, 0.4)
	_place(_actor, actor_s, 0.0)
	var running := actor_speed > 0.05 and not reduced() and _ng <= 0.0
	var stride := 0.0
	if running:
		stride = sin(elapsed * 14.0 * maxf(actor_speed, 0.4)) * 0.6
	for index in _legs.size():
		_legs[index].rotation.x = stride * (1.0 if index == 0 else -1.0)
	_actor.position.y += absf(stride) * 0.06
	if _ng > 0.0 and not reduced():
		_actor.rotation.x = -sin((NG_SECONDS - _ng) / NG_SECONDS * PI) * 1.2
	if _wrapped and _show > 0.0 and not reduced():
		_actor.rotation.x = -sin(minf(_show * 2.0, PI)) * 0.6
	_place(_flags[0], dolly_s + FRAME_NEAR, 0.42)
	_place(_flags[1], dolly_s + FRAME_FAR, 0.42)
	_rec.material_override = _rec_on if in_frame() else _rec_off


## Stands `node` on the track at `s`, facing along it, `side` metres outward.
func _place(node: Node3D, s: float, side: float) -> void:
	var angle := START_ANGLE + s / _radius
	var at := _middle + Vector3(cos(angle), 0, sin(angle)) * (_radius + side)
	at.y = world.ground_surface_y(at)
	node.position = at
	# Facing along the direction of travel (increasing angle).
	var ahead := Vector3(-sin(angle), 0, cos(angle))
	node.rotation = Vector3(0, atan2(-ahead.x, -ahead.z), 0)
