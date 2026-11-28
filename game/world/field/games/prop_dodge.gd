extends "res://game/world/field/field_game.gd"
## An outdoor film set under a lighting truss. The crew up top keep dropping
## foam props (boulders, sandbags, cardboard stars) on the spot where you
## stand: a shadow grows where each one will land. Step off the shadow and the
## prop bounces harmlessly, a point; stay put and it bonks you. Drops come
## faster as the take goes on, and later a stray prop falls alongside the
## aimed one.

const SceneryKit = preload("res://game/world/scenery_kit.gd")
const PROPS := 4
const DROP_RADIUS := 2.6
const HIT_REACH := 0.7
const TRUSS_HEIGHT := 4.2
const SLOW_GAP := 1.5
const FAST_GAP := 0.72
const SLOW_WARN := 1.05
const FAST_WARN := 0.72
const STRAY_CLEARANCE := 1.7
const BOUNCE_SECONDS := 0.6
const KINDS := 3

## Per prop: 0 idle, 1 falling, 2 bouncing on the floor.
var state := PackedByteArray()
var target := PackedVector3Array()
var clock := PackedFloat32Array()
var span := PackedFloat32Array()
var aimed := PackedByteArray()
var kind := PackedInt32Array()
var dodged := 0
var hits := 0

var _middle := Vector3.ZERO
var _next := 0.0
var _drops := 0
var _props: Array[MeshInstance3D] = []
var _shadows: Array[MeshInstance3D] = []
var _shapes: Array[Mesh] = []
var _show := 0.0
var _buried := false


func build() -> void:
	_middle = centre()
	# The lighting truss on four towers outside the play floor.
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var foot := _middle + Vector3(corner.x * 3.05, 0, corner.y * 3.05)
		foot.y = world.ground_surface_y(foot)
		corners.append(foot)
	Kit.posts(world, self, corners, TRUSS_HEIGHT, Color("#e8b54f"), 0.09)
	var beam := BoxMesh.new()
	beam.size = Vector3(6.1, 0.12, 0.12)
	var beams: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		beams.append(Transform3D(Basis.IDENTITY, _middle + Vector3(0, TRUSS_HEIGHT + 0.18, side * 3.05)))
		beams.append(Transform3D(Basis(Vector3.UP, PI * 0.5), _middle + Vector3(side * 3.05, TRUSS_HEIGHT + 0.18, 0)))
		beams.append(Transform3D(Basis.IDENTITY, _middle + Vector3(0, TRUSS_HEIGHT - 0.12, side * 3.05)))
	Kit.batch(self, beam, beams, world._vertex_color_material("field-truss"), [Color("#6d7380")])
	# Lamps clamped to the truss, pointing down.
	var lamp := CylinderMesh.new()
	lamp.top_radius = 0.12
	lamp.bottom_radius = 0.17
	lamp.height = 0.34
	lamp.radial_segments = 8
	lamp.rings = 1
	var lamps: Array[Transform3D] = []
	for index in range(6):
		var x := -2.4 + float(index % 3) * 2.4
		lamps.append(Transform3D(Basis(Vector3.RIGHT, 0.4 if index < 3 else -0.4), _middle + Vector3(x, TRUSS_HEIGHT - 0.32, -3.05 if index < 3 else 3.05)))
	Kit.batch(self, lamp, lamps, world._vertex_color_material("field-truss-lamps"), [Color("#2e2a33")])
	_shapes = [_boulder(), _sandbag(), _star()]
	for index in range(PROPS):
		_shadows.append(Kit.blob(world, self, Vector2(1.0, 1.0)))
		var prop := Kit.mesh(self, _shapes[0], Vector3.ZERO, world._vertex_color_material("field-foam-props"), false)
		_props.append(prop)
	state.resize(PROPS)
	target.resize(PROPS)
	clock.resize(PROPS)
	span.resize(PROPS)
	aimed.resize(PROPS)
	kind.resize(PROPS)


## A lumpy grey foam boulder.
func _boulder() -> Mesh:
	var s := SceneryKit.Sculpt.new()
	s.ball(Vector3.ZERO, 0.36, Color("#a49c96"), Color("#8f8780"), 7, 4, 0.8)
	s.ball(Vector3(0.14, 0.12, 0.08), 0.2, Color("#b8b0a8"), Color.TRANSPARENT, 6, 3)
	s.ball(Vector3(-0.16, -0.04, -0.1), 0.18, Color("#8f8780"), Color.TRANSPARENT, 6, 3)
	return s.mesh()


## A sandbag with a tied neck.
func _sandbag() -> Mesh:
	var s := SceneryKit.Sculpt.new()
	s.ball(Vector3.ZERO, 0.3, Color("#c9a873"), Color("#b8955e"), 8, 4, 0.7)
	s.tube(Vector3(0, 0.26, 0), 0.08, 0.05, 0.14, Color("#8a6a48"), 6)
	return s.mesh()


## A cardboard star on a stick.
func _star() -> Mesh:
	var s := SceneryKit.Sculpt.new()
	for point in range(5):
		var angle := TAU * float(point) / 5.0 + PI * 0.5
		var tip := Vector3(cos(angle), sin(angle), 0) * 0.42
		var left := Vector3(cos(angle - 0.63), sin(angle - 0.63), 0) * 0.17
		var right := Vector3(cos(angle + 0.63), sin(angle + 0.63), 0) * 0.17
		s.sheet(Vector3.ZERO, left, tip, Color("#f2c75a"))
		s.sheet(Vector3.ZERO, tip, right, Color("#e8b54f"))
	s.box(Vector3(0, -0.5, 0), Vector3(0.04, 0.5, 0.04), Color("#8a6a48"))
	return s.mesh()


func reset() -> void:
	state.fill(0)
	_buried = false
	for index in range(PROPS):
		_props[index].visible = false
		_shadows[index].visible = false


func begin() -> void:
	dodged = 0
	hits = 0
	_drops = 0
	_next = 0.6
	state.fill(0)


## The gap before the next aimed drop and how long its shadow warns.
func gap() -> float:
	return lerpf(SLOW_GAP, FAST_GAP, pace())


func warning() -> float:
	return lerpf(SLOW_WARN, FAST_WARN, pace())


## Where prop `index` will land, or INF while it is not falling.
func landing(index: int) -> Vector3:
	return target[index] if state[index] == 1 else Vector3(INF, 0, INF)


func time_left(index: int) -> float:
	return span[index] - clock[index] if state[index] == 1 else INF


func step(delta: float, player: Vector3) -> void:
	_next -= delta
	if _next <= 0.0:
		_next = gap()
		_drop(_clamped(player), true)
		# Later on a stray prop falls too, well clear of you.
		if pace() > 0.45 and _drops % 2 == 0:
			var spot := Vector3.ZERO
			for tries in range(8):
				var angle := rng.randf() * TAU
				spot = _clamped(_middle + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.6, DROP_RADIUS))
				if flat_distance(spot, player) >= STRAY_CLEARANCE: break
			if flat_distance(spot, player) >= STRAY_CLEARANCE:
				_drop(spot, false)
	for index in range(PROPS):
		if state[index] == 0:
			continue
		clock[index] += delta
		if state[index] == 1 and clock[index] >= span[index]:
			state[index] = 2
			clock[index] = 0.0
			if flat_distance(player, target[index]) < HIT_REACH:
				hits += 1
				feedback("miss")
				field.say("咚！", 0.5)
				hop(0.12, 0.2)
			elif aimed[index] == 1:
				dodged += 1
				add_score(1)
				note(dodged)
				feedback("hit")
		elif state[index] == 2 and clock[index] >= BOUNCE_SECONDS:
			state[index] = 0
	_draw()


func _drop(spot: Vector3, aim: bool) -> void:
	for index in range(PROPS):
		if state[index] != 0:
			continue
		state[index] = 1
		target[index] = spot
		clock[index] = 0.0
		span[index] = warning()
		aimed[index] = 1 if aim else 0
		kind[index] = _drops % KINDS
		_props[index].mesh = _shapes[kind[index]]
		_drops += 1
		return


## A ground spot inside the drop circle, as close as possible to `spot`.
func _clamped(spot: Vector3) -> Vector3:
	var offset := Vector2(spot.x - _middle.x, spot.z - _middle.z).limit_length(DROP_RADIUS)
	var at := Vector3(_middle.x + offset.x, 0, _middle.z + offset.y)
	at.y = world.ground_surface_y(at)
	return at


func conclude(medal: int) -> void:
	# No medal: the crew's biggest foam boulder lands on you and stays there.
	_buried = medal == 0
	_show = 0.0
	state.fill(0)


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw()
	if _buried and player.is_finite():
		var prop := _props[0]
		prop.visible = true
		prop.mesh = _shapes[0]
		var drop := 0.0 if reduced() else maxf(0.0, 1.0 - _show * 3.0) * 3.0
		prop.position = player + Vector3(0, 2.1 + drop, 0)
		prop.scale = Vector3(2.2, 1.6, 2.2)


func _draw() -> void:
	for index in range(PROPS):
		var prop := _props[index]
		var shade := _shadows[index]
		prop.visible = state[index] != 0
		shade.visible = state[index] == 1
		if state[index] == 0:
			continue
		var spot := target[index]
		if state[index] == 1:
			var along := clampf(clock[index] / span[index], 0.0, 1.0)
			prop.position = spot + Vector3(0, lerpf(TRUSS_HEIGHT - 0.4, 0.35, along * along), 0)
			prop.rotation = Vector3(0, along * 4.0, 0) if not reduced() else Vector3.ZERO
			prop.scale = Vector3.ONE
			var grow := 0.35 + 0.75 * along
			shade.position = spot + Vector3(0, 0.07, 0)
			shade.scale = Vector3(grow, 1.0, grow)
		else:
			# A squashy bounce, then it sinks away.
			var age := clock[index] / BOUNCE_SECONDS
			var bounce := 0.0 if reduced() else absf(sin(age * PI * 2.0)) * 0.35 * (1.0 - age)
			prop.position = spot + Vector3(0, 0.3 + bounce - age * 0.4, 0)
			var squash := 0.0 if reduced() else 0.25 * (1.0 - age)
			prop.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
