extends "res://game/world/field/field_game.gd"
## Fish leap out of the sea and land on the sand. A ring shows where each will
## come down: stand in it to catch the fish in your net. They come faster and
## two at a time later on, and now and then a puffer comes over: catch that
## one and it puffs up in your face.

enum { IDLE, FLYING, FLOPPING }

const POOL := 4
const CATCH_REACH := 0.7
const LEAP_HEIGHT := 2.4
const SLOW_LEAP := 1.7
const FAST_LEAP := 1.05
const SLOW_GAP := 1.45
const FAST_GAP := 0.7
const FLOP_SECONDS := 1.1
const STUN_SECONDS := 1.0
## Fish leave the water this far out to sea from the landing spot.
const SEA_REACH := 6.0
const PUFFER_FROM := 0.35
const PUFFER_TINT := Color(1.45, 1.05, 0.55)
const FISH_SIZE := 2.6

var spots := PackedVector3Array()
var state := PackedInt32Array()
var target := PackedInt32Array()
var clock := PackedFloat32Array()
var span := PackedFloat32Array()
var puffer := PackedByteArray()
var caught := 0
var puffed := 0
var flopped := 0
var stunned := 0.0

var _sea := Vector3.RIGHT
var _fish: Kit.SpriteBatch
var _rings: MultiMesh
var _net: MeshInstance3D
var _tally: Label3D
var _spawn_in := 0.0
var _last_spot := -1
var _party := false
var _show := 0.0
var _net_fish := 0.0


func build() -> void:
	var middle := centre()
	var direction: Vector2 = spec.get("sea", Vector2.RIGHT)
	_sea = Vector3(direction.x, 0, direction.y).normalized()
	var patch := Kit.cylinder(self, middle + Vector3(0, 0.02, 0), 2.7, 0.04, Kit.sand_material(world), -1.0, 24)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for offset: Vector2 in spec.get("layout", []):
		spots.append(spot(offset) + Vector3(0, 0.05, 0))
	# One flat ring per fish in the air, drawn as a single batch.
	var ring := TorusMesh.new()
	ring.inner_radius = CATCH_REACH - 0.2
	ring.outer_radius = CATCH_REACH
	ring.rings = 16
	ring.ring_segments = 4
	var hidden: Array[Transform3D] = []
	for index in range(POOL):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), middle))
	var rings := Kit.batch(self, ring, hidden, Kit.clear_material(world, Color(1.0, 0.92, 0.55, 0.95), 0.9), [Color.WHITE])
	rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings = rings.multimesh
	# A fish crate beside the stand keeps the tally.
	var crate_at := middle - _sea * 2.2 + Vector3(0, 0.22, 1.2)
	Kit.box(self, crate_at, Vector3(0.8, 0.44, 0.52), world._coastal_surface(Kit.TILE_PLANK, 0.7, Color("#d9c09a")))
	_tally = Kit.label(self, "", crate_at + Vector3(0, 0.75, 0), 40, Color("#fff6de"))
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.26
	hoop.outer_radius = 0.32
	hoop.rings = 14
	hoop.ring_segments = 5
	_net = Kit.mesh(self, hoop, Vector3.ZERO, world._wood_material(Color("#8a6a48")), false)
	var mesh_net := CylinderMesh.new()
	mesh_net.top_radius = 0.28
	mesh_net.bottom_radius = 0.06
	mesh_net.height = 0.3
	mesh_net.radial_segments = 10
	mesh_net.rings = 1
	Kit.mesh(_net, mesh_net, Vector3(0, -0.15, 0), Kit.clear_material(world, Color(0.95, 0.93, 0.85, 0.55)), false)
	Kit.cylinder(_net, Vector3(0.45, 0.25, 0), 0.025, 0.9, world._wood_material(Color("#8a6a48")), -1.0, 5).rotation.z = 1.1
	state.resize(POOL)
	target.resize(POOL)
	clock.resize(POOL)
	span.resize(POOL)
	puffer.resize(POOL)
	_fish = Kit.SpriteBatch.new(world, POOL + 1)
	add_child(_fish)


func reset() -> void:
	state.fill(IDLE)
	_party = false
	_net.visible = false
	_tally.visible = false
	_net_fish = 0.0
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	caught = 0
	puffed = 0
	flopped = 0
	stunned = 0.0
	_spawn_in = 0.4
	_last_spot = -1
	_net.visible = true
	_tally.visible = true


func step(delta: float, player: Vector3) -> void:
	stunned = maxf(0.0, stunned - delta)
	_net_fish = maxf(0.0, _net_fish - delta)
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = lerpf(SLOW_GAP, FAST_GAP, pace())
		_leap()
	for index in range(POOL):
		if state[index] == IDLE:
			continue
		clock[index] += delta
		if state[index] == FLYING and clock[index] >= span[index]:
			_land(index, player)
		elif state[index] == FLOPPING and clock[index] >= FLOP_SECONDS:
			state[index] = IDLE
	_draw(player)


## Where the next fish will come down, for visitors and tests alike.
func landing(index: int) -> Vector3:
	return spots[target[index]]


func _leap() -> void:
	var free := state.find(IDLE)
	if free < 0:
		return
	var choice := rng.randi_range(0, spots.size() - 1)
	for tries in range(spots.size()):
		var taken := choice == _last_spot
		for other in range(POOL):
			taken = taken or (state[other] == FLYING and target[other] == choice)
		if not taken:
			break
		choice = (choice + 1) % spots.size()
	_last_spot = choice
	state[free] = FLYING
	target[free] = choice
	clock[free] = 0.0
	span[free] = lerpf(SLOW_LEAP, FAST_LEAP, pace())
	puffer[free] = int(pace() >= PUFFER_FROM and rng.randf() < 0.28)


func _land(index: int, player: Vector3) -> void:
	var inside := flat_distance(player, spots[target[index]]) < CATCH_REACH and stunned <= 0.0
	if inside and puffer[index] == 1:
		puffed += 1
		stunned = STUN_SECONDS
		state[index] = IDLE
		hop(0.5, STUN_SECONDS, 2)
		feedback("miss")
		field.say("河豚脹氣了！", 1.0)
	elif inside:
		caught += 1
		add_score(1)
		state[index] = IDLE
		_net_fish = 0.45
		note(caught)
		feedback("hit")
	else:
		if puffer[index] == 0:
			flopped += 1
		state[index] = FLOPPING
		clock[index] = 0.0


func conclude(medal: int) -> void:
	_party = medal == 0
	_show = 0.0
	if not _party:
		state.fill(IDLE)
	_net.visible = false


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(player: Vector3) -> void:
	var middle := centre()
	for index in range(POOL):
		_fish.tint(index, PUFFER_TINT if puffer[index] == 1 else Color(1.2, 1.2, 1.25))
		var size := FISH_SIZE * (1.35 if puffer[index] == 1 else 1.0)
		var hide_ring := true
		if _party:
			# Every fish flops about on the sand to celebrate your empty net.
			var flop := 0.0 if reduced() else absf(sin(_show * 7.0 + index * 1.3)) * 0.35
			_fish.put(index, spots[index % spots.size()] + Vector3(0, flop, 0), "fish", 2, index % 2 == 0, FISH_SIZE)
		elif state[index] == FLYING:
			var along := clampf(clock[index] / span[index], 0.0, 1.0)
			var land := spots[target[index]]
			var from := land + _sea * SEA_REACH - Vector3(0, 0.6, 0)
			var arc := from.lerp(land, along) + Vector3(0, sin(along * PI) * LEAP_HEIGHT, 0)
			_fish.put(index, arc, "fish", 1 if along < 0.6 else 0, _sea.x < 0.0, size)
			hide_ring = false
			var grow := 0.6 + 0.4 * along
			_rings.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(grow, 1.0, grow)), land + Vector3(0, 0.02, 0)))
			_rings.set_instance_color(index, Color(1.0, 0.55, 0.4) if puffer[index] == 1 else Color.WHITE)
		elif state[index] == FLOPPING:
			var bounce := 0.0 if reduced() else absf(sin(clock[index] * 14.0)) * 0.3 * (1.0 - clock[index] / FLOP_SECONDS)
			_fish.put(index, spots[target[index]] + Vector3(0, bounce, 0), "fish", 2, int(clock[index] * 8.0) % 2 == 0, size)
		else:
			_fish.hide_item(index)
		if hide_ring:
			_rings.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), middle))
	if _net.visible and player.is_finite():
		var dip := 0.0 if reduced() else _net_fish * 0.6
		_net.position = player + Vector3(0.38, 1.95 - dip, 0.12)
		_net.rotation.z = -0.35
	if _net_fish > 0.0 and player.is_finite():
		_fish.put(POOL, player + Vector3(0.38, 1.95, 0.14), "fish", 1, false, FISH_SIZE * 0.8)
	else:
		_fish.hide_item(POOL)
	if _tally.visible:
		Kit.write(_tally, "×%d" % caught, Color("#fff6de"))
