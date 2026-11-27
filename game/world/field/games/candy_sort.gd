extends "res://game/world/field/field_game.gd"
## Candies roll down a chute to a flap that sends them left or right. Stand
## on the left or right pedal to hold the flap over, so each candy drops into
## the bin of its own colour; off the pedals the flap springs back and the
## candy spills on the grass. They come faster and faster, and a candy in the
## wrong bin gets spat straight back out at you.

enum { IDLE, CHUTE, DROP, SPAT }

const POOL := 6
const PAD_REACH := 0.55
const SLOW_ROLL := 1.9
const FAST_ROLL := 1.1
const SLOW_GAP := 1.9
const FAST_GAP := 1.15
const DROP_SECONDS := 0.45
const SPAT_SECONDS := 0.8
const CANDY_RADIUS := 0.17
## Left bin, right bin.
const COLORS := [Color("#ef7fa8"), Color("#7fd0c4")]

var state := PackedInt32Array()
var color := PackedInt32Array()
var side := PackedInt32Array()
var clock := PackedFloat32Array()
var span := PackedFloat32Array()
## 0 sends candies left, 1 right, -1 (nobody on a pedal) spills them.
var flap := -1
var sorted := 0
var wrong := 0
var spilled := 0

var _pads: Array[Vector3] = []
var _bins: Array[Vector3] = []
var _top := Vector3.ZERO
var _fork := Vector3.ZERO
var _candies: MultiMesh
var _flap: Node3D
var _pad_glow: Array[MeshInstance3D] = []
var _spawn_in := 0.0
var _flood := false
var _show := 0.0
var _target := Vector3.ZERO


func build() -> void:
	var layout: Array = spec.get("layout", [])
	_pads = [spot(layout[0]), spot(layout[1])]
	_bins = [spot(layout[2]), spot(layout[3])]
	_top = spot(layout[4]) + Vector3(0, 1.5, 0)
	_fork = (_bins[0] + _bins[1]) * 0.5 + Vector3(0, 1.15, -0.1)
	# The chute: a painted trough on a post, sloping down to the flap.
	var trough := Kit.box(self, (_top + _fork) * 0.5, Vector3(0.42, 0.08, _top.distance_to(_fork) + 0.2), Kit.finish(world, Color("#f4d6e2"), Vector3(0.42, 0.08, 2.0)))
	trough.look_at_from_position(trough.position, _fork, Vector3.UP)
	var rails := Kit.box(trough, Vector3(0.24, 0.08, 0), Vector3(0.05, 0.12, _top.distance_to(_fork) + 0.2), world._mat(Color("#e0525a")))
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.box(trough, Vector3(-0.24, 0.08, 0), Vector3(0.05, 0.12, _top.distance_to(_fork) + 0.2), world._mat(Color("#e0525a")))
	var holders: Array[Vector3] = [Vector3(_top.x, centre().y, _top.z), Vector3(_fork.x, centre().y, _fork.z - 0.25)]
	Kit.posts(world, self, holders, 1.45, Color("#fff3ec"), 0.07)
	Kit.cylinder(self, Vector3(_top.x, _top.y + 0.25, _top.z), 0.32, 0.5, world._coastal_surface(Kit.TILE_BRASS, 0.5, Color("#ffd1e0")), 0.24, 12)
	_flap = Node3D.new()
	_flap.position = _fork
	add_child(_flap)
	Kit.box(_flap, Vector3(0, -0.25, 0), Vector3(0.08, 0.5, 0.36), world._coastal_surface(Kit.TILE_RED_BOARD, 0.6))
	for index in range(2):
		var bin := _bins[index]
		var tone: Color = COLORS[index]
		Kit.cylinder(self, bin + Vector3(0, 0.05, 0), 0.5, 0.1, world._wood_material(Color("#8a6a48")), -1.0, 14)
		Kit.cylinder(self, bin + Vector3(0, 0.45, 0), 0.46, 0.7, Kit.finish(world, tone, Vector3(0.9, 0.7, 0.9)), 0.4, 14)
		Kit.cylinder(self, bin + Vector3(0, 0.83, 0), 0.5, 0.07, world._mat(Color("#fff3ec")), -1.0, 14)
		var pad := _pads[index]
		Kit.cylinder(self, pad + Vector3(0, 0.03, 0), 0.5, 0.06, world._wood_material(Color("#7a5a3c")), -1.0, 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var top := Kit.cylinder(self, pad + Vector3(0, 0.07, 0), 0.38, 0.04, world._mat(tone), -1.0, 12)
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pad_glow.append(top)
		Kit.label(self, "←" if index == 0 else "→", pad + Vector3(0, 0.5, 0), 40, Color("#fff6de"))
	var candy := SphereMesh.new()
	candy.radius = CANDY_RADIUS
	candy.height = CANDY_RADIUS * 1.6
	candy.radial_segments = 8
	candy.rings = 4
	var hidden: Array[Transform3D] = []
	for index in range(POOL):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), _top))
	var batch := Kit.batch(self, candy, hidden, world._vertex_color_material("field-candies", 0.4), [Color.WHITE])
	_candies = batch.multimesh
	_candies.custom_aabb = AABB(centre() - Vector3(6, 1, 6), Vector3(12, 6, 12))
	state.resize(POOL)
	color.resize(POOL)
	side.resize(POOL)
	clock.resize(POOL)
	span.resize(POOL)


func reset() -> void:
	state.fill(IDLE)
	flap = -1
	_flood = false
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	sorted = 0
	wrong = 0
	spilled = 0
	flap = -1
	_spawn_in = 0.3


## The candy that will reach the flap next, or -1.
func next_candy() -> int:
	var best := -1
	for index in range(POOL):
		if state[index] == CHUTE and (best < 0 or clock[index] / span[index] > clock[best] / span[best]):
			best = index
	return best


func pad(index: int) -> Vector3:
	return _pads[index]


func step(delta: float, player: Vector3) -> void:
	var held := -1
	for index in range(2):
		if flat_distance(player, _pads[index]) < PAD_REACH:
			held = index
	if held != flap:
		flap = held
		if held >= 0:
			note(held + 1)
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = lerpf(SLOW_GAP, FAST_GAP, pace())
		var free := state.find(IDLE)
		if free >= 0:
			state[free] = CHUTE
			color[free] = rng.randi_range(0, 1)
			clock[free] = 0.0
			span[free] = lerpf(SLOW_ROLL, FAST_ROLL, pace())
	for index in range(POOL):
		if state[index] == IDLE:
			continue
		clock[index] += delta
		match state[index]:
			CHUTE:
				if clock[index] >= span[index]:
					state[index] = DROP
					side[index] = flap
					clock[index] = 0.0
			DROP:
				if clock[index] >= DROP_SECONDS:
					_sort(index, player)
			SPAT:
				if clock[index] >= SPAT_SECONDS:
					state[index] = IDLE
	_draw(player)


func _sort(index: int, player: Vector3) -> void:
	if side[index] < 0:
		spilled += 1
		state[index] = IDLE
		feedback("miss")
		field.say("撒了一地！", 0.6)
		return
	if side[index] == color[index]:
		sorted += 1
		add_score(1)
		note(sorted)
		feedback("hit")
		state[index] = IDLE
		return
	wrong += 1
	state[index] = SPAT
	clock[index] = 0.0
	_target = player
	feedback("miss")
	field.say("噗！", 0.6)
	hop(0.3, 0.4)


func conclude(medal: int) -> void:
	# No medal: the machine empties itself over the visitor.
	_flood = medal == 0
	_show = 0.0
	if not _flood:
		state.fill(IDLE)


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(player: Vector3) -> void:
	_flap.rotation.z = 0.0 if flap < 0 else (0.5 if flap == 0 else -0.5)
	for index in range(2):
		_pad_glow[index].position.y = _pads[index].y + (0.04 if flap == index else 0.07)
	for index in range(POOL):
		var at := Vector3.ZERO
		if _flood and player.is_finite():
			var fall := fmod(_show * 1.5 + index * 0.17, 1.0) if not reduced() else 0.5
			at = player + Vector3((index - 2.5) * 0.18, 2.6 - fall * 2.0, 0.1)
			_candies.set_instance_color(index, COLORS[index % 2])
		else:
			match state[index]:
				IDLE:
					_candies.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), _top))
					continue
				CHUTE:
					at = _top.lerp(_fork, clampf(clock[index] / span[index], 0.0, 1.0)) + Vector3(0, 0.12, 0)
				DROP:
					var along := clampf(clock[index] / DROP_SECONDS, 0.0, 1.0)
					var land := _bins[side[index]] + Vector3(0, 0.7, 0) if side[index] >= 0 else Vector3(_fork.x, centre().y + CANDY_RADIUS, _fork.z + 0.4)
					at = _fork.lerp(land, along) + Vector3(0, sin(along * PI) * 0.3, 0)
				SPAT:
					var along := clampf(clock[index] / SPAT_SECONDS, 0.0, 1.0)
					at = (_bins[side[index]] + Vector3(0, 0.8, 0)).lerp(_target + Vector3(0, 1.6, 0), along) + Vector3(0, sin(along * PI) * 1.4, 0)
			_candies.set_instance_color(index, COLORS[color[index]])
		_candies.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
