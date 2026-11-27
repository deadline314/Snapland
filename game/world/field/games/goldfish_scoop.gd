extends "res://game/world/field/field_game.gd"
## A night-market goldfish tub. Walk round the rim and press interact to dip
## the paper net where you stand. A fish under the net is yours, but every
## dip soaks the paper and a soggy net tears; you get a fresh one after a
## moment. The fish swim faster later, a gold
## one is worth three, and the big black one goes straight through the paper.

const FISH := 7
const TUB_RADIUS := 1.45
## The net dips this far in from the rim on the visitor's side.
const NET_IN := 0.95
const NET_REACH := 0.42
const PAPER := 4
const TEAR_SECONDS := 1.5
const DIP_SECONDS := 0.6
const RESPAWN_SECONDS := 1.4
const GOLD := 5
const BLACK := 6
const FISH_COLORS := [Color("#f0703a"), Color("#f58a3c"), Color("#e8563a"), Color("#f7a04a"), Color("#f0703a"), Color("#ffd04a"), Color("#2c2a33")]

var orbit := PackedFloat32Array()
var angle := PackedFloat32Array()
var speed := PackedFloat32Array()
var away := PackedFloat32Array()
var paper := PAPER
var caught := 0
var tears := 0
var dips := 0

var _middle := Vector3.ZERO
var _bodies: MultiMesh
var _tails: MultiMesh
var _hoop: Node3D
var _paper: MeshInstance3D
var _dip := 0.0
var _torn := 0.0
var _splash := false
var _show := 0.0


func build() -> void:
	_middle = centre()
	Kit.cylinder(self, _middle + Vector3(0, 0.05, 0), TUB_RADIUS + 0.25, 0.1, world._wood_material(Color("#5a3e2c")), -1.0, 24)
	Kit.cylinder(self, _middle + Vector3(0, 0.3, 0), TUB_RADIUS + 0.12, 0.42, Kit.finish(world, Color("#d9525e"), Vector3(3.0, 0.42, 3.0)), TUB_RADIUS + 0.18, 24)
	var water := Kit.cylinder(self, _middle + Vector3(0, 0.5, 0), TUB_RADIUS, 0.04, Kit.clear_material(world, Color(0.45, 0.75, 0.9, 0.6), 0.15), -1.0, 24)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rim := TorusMesh.new()
	rim.inner_radius = TUB_RADIUS
	rim.outer_radius = TUB_RADIUS + 0.14
	rim.rings = 28
	rim.ring_segments = 6
	Kit.mesh(self, rim, _middle + Vector3(0, 0.52, 0), world._mat(Color("#f2e6cf")))
	# A paper lantern on a post lights the tub.
	var lamp: Array[Vector3] = [_middle + Vector3(-TUB_RADIUS - 0.6, 0, -0.6)]
	Kit.posts(world, self, lamp, 1.8, Color("#e8674f"), 0.06)
	Kit.ball(self, lamp[0] + Vector3(0, 2.25, 0), 0.24, world._mat(Color("#f2a85a"), true))
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	body.radial_segments = 8
	body.rings = 4
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.5
	tail.height = 0.6
	tail.radial_segments = 3
	tail.rings = 1
	var hidden: Array[Transform3D] = []
	for index in range(FISH):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), _middle))
	var colors: Array[Color] = []
	colors.assign(FISH_COLORS)
	var fish_mat: Material = world._vertex_color_material("field-goldfish", 0.35)
	var bodies := Kit.batch(self, body, hidden, fish_mat, colors)
	bodies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bodies = bodies.multimesh
	var tails := Kit.batch(self, tail, hidden, fish_mat, colors)
	tails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tails = tails.multimesh
	_hoop = Node3D.new()
	add_child(_hoop)
	var hoop := TorusMesh.new()
	hoop.inner_radius = NET_REACH - 0.06
	hoop.outer_radius = NET_REACH
	hoop.rings = 16
	hoop.ring_segments = 4
	Kit.mesh(_hoop, hoop, Vector3.ZERO, world._mat(Color("#e8674f")), false)
	var sheet := CylinderMesh.new()
	sheet.top_radius = NET_REACH - 0.04
	sheet.bottom_radius = NET_REACH - 0.04
	sheet.height = 0.01
	sheet.radial_segments = 14
	sheet.rings = 1
	_paper = Kit.mesh(_hoop, sheet, Vector3.ZERO, Kit.clear_material(world, Color(1.0, 0.98, 0.92, 0.7)), false)
	Kit.cylinder(_hoop, Vector3(0, 0.05, NET_REACH + 0.3), 0.035, 0.6, world._mat(Color("#e8674f")), -1.0, 5).rotation.x = PI * 0.5
	orbit.resize(FISH)
	angle.resize(FISH)
	speed.resize(FISH)
	away.resize(FISH)
	for index in range(FISH):
		_seat(index, 0.4 + index * 0.13, index * 0.9)


func _seat(index: int, radius: float, start: float) -> void:
	orbit[index] = radius
	angle[index] = start
	var turn := 0.5 + fposmod(index * 0.37, 0.4)
	speed[index] = turn if index % 2 == 0 else -turn
	away[index] = 0.0


func reset() -> void:
	paper = PAPER
	_dip = 0.0
	_torn = 0.0
	_splash = false
	_hoop.visible = false
	for index in range(FISH):
		_seat(index, 0.4 + index * 0.13, index * 0.9)
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	caught = 0
	tears = 0
	dips = 0
	paper = PAPER
	_hoop.visible = true


func action_label() -> String:
	return "撈" if _torn <= 0.0 and _dip <= 0.0 else ""


## Where the net dips for a visitor standing at `player`.
func net_at(player: Vector3) -> Vector3:
	var out := Vector3(player.x - _middle.x, 0, player.z - _middle.z)
	if out.length() < 0.01:
		out = Vector3.BACK
	return _middle + out.normalized() * NET_IN + Vector3(0, 0.55, 0)


func fish_at(index: int) -> Vector3:
	return _middle + Vector3(cos(angle[index]) * orbit[index], 0.47, sin(angle[index]) * orbit[index])


## The fish a dip at `net` would catch, or -1.
func under(net: Vector3) -> int:
	var best := -1
	var gap := NET_REACH
	for index in range(FISH):
		var reach := flat_distance(fish_at(index), net)
		if away[index] <= 0.0 and reach < gap:
			gap = reach
			best = index
	return best


func step(delta: float, player: Vector3) -> void:
	var hurry := lerpf(1.0, 2.1, pace())
	for index in range(FISH):
		away[index] = maxf(0.0, away[index] - delta)
		angle[index] += speed[index] * hurry * delta
		# Each fish weaves in and out a little as it circles.
		orbit[index] = clampf(orbit[index] + sin(elapsed * 1.3 + index) * 0.15 * delta, 0.25, TUB_RADIUS - 0.2)
	_dip = maxf(0.0, _dip - delta)
	if _torn > 0.0:
		_torn -= delta
		if _torn <= 0.0:
			paper = PAPER
	_draw(player)


func press() -> void:
	if _torn > 0.0 or _dip > 0.0:
		return
	dips += 1
	_dip = DIP_SECONDS
	var fish := under(net_at(world.player.global_position))
	if fish == BLACK:
		_tear("大黑魚衝破紙網了！")
	elif fish >= 0:
		caught += 1
		add_score(3 if fish == GOLD else 1)
		note(caught)
		feedback("success" if fish == GOLD else "hit")
		away[fish] = RESPAWN_SECONDS
		angle[fish] += PI
	else:
		feedback("miss")
	paper -= 1
	if paper <= 0 and _torn <= 0.0:
		_tear("紙網破了！")


func _tear(line: String) -> void:
	tears += 1
	paper = 0
	_torn = TEAR_SECONDS
	feedback("miss")
	field.say(line, 1.0)


func conclude(medal: int) -> void:
	_splash = medal == 0
	_show = 0.0
	_hoop.visible = false


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	for index in range(FISH):
		angle[index] += speed[index] * delta
	_draw(player)


func _draw(player: Vector3) -> void:
	for index in range(FISH):
		var at := fish_at(index)
		var size := 0.26 if index == BLACK else 0.19
		if away[index] > 0.0:
			_bodies.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), at))
			_tails.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), at))
			continue
		if _splash and not reduced():
			# Fish leap out of the water to laugh at the empty net.
			at.y += absf(sin(_show * 5.0 + index * 0.8)) * 0.5
		var heading := Vector3(-sin(angle[index]), 0, cos(angle[index])) * signf(speed[index])
		var facing := Basis.looking_at(heading, Vector3.UP)
		_bodies.set_instance_transform(index, Transform3D(facing.scaled_local(Vector3(size * 0.7, size * 0.45, size * 1.1)), at))
		var tail_basis := facing * Basis.from_euler(Vector3(PI * 0.5, 0, 0))
		var flick := 0.0 if reduced() else sin(world.time * 12.0 + index) * 0.4
		tail_basis = Basis(Vector3.UP, flick) * tail_basis
		_tails.set_instance_transform(index, Transform3D(tail_basis.scaled_local(Vector3(size * 0.8, size * 0.6, size * 0.3)), at - heading * size * 0.75))
	if _hoop.visible and player.is_finite():
		var net := net_at(player)
		var dip := 0.0 if reduced() else sin(clampf(_dip / DIP_SECONDS, 0.0, 1.0) * PI) * 0.12
		_hoop.position = net + Vector3(0, 0.08 - dip, 0)
		_hoop.rotation.y = atan2(player.x - _middle.x, player.z - _middle.z)
		_paper.visible = _torn <= 0.0
		_paper.scale = Vector3.ONE * (0.4 + 0.6 * paper / float(PAPER))
