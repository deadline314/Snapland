extends RefCounted
## Everything in the mirror circus that moves: stage spots that sweep the ring and
## find whoever steps into it, the drum that rolls for them, the trapeze and hoops
## overhead, balloon bunches that lean away from a passer-by, and the walker the
## funhouse mirrors reflect. Nothing here is saved or scored, and the
## reduced-motion pose is one still frame.

const Props := preload("res://game/world/circus_props.gd")
const Scenery := preload("res://game/world/circus_scenery.gd")
const LIGHT_BEAM := preload("res://game/world/light_beam.gdshader")
const SPOT_POOL := preload("res://game/world/spot_pool.gdshader")
const BEAM_LENGTH := 12.0
## Stage spots: the king pole that carries it and its colour.
const SPOTS := [[0, "#ffd98a"], [1, "#ff9ac0"], [2, "#8fe3ff"]]
const SPOT_HEIGHT := 8.5
const TRAPEZE_AT := Vector3(0, 8.5, -8.75)
## Aerial hoops: z along the centre line, rope length, colour.
const HOOPS := [[-10.4, 2.9, "#e88aa0"], [-7.1, 3.6, "#8fc8d8"]]
## Balloon bunches: where the strings are tied, then how many balloons.
const BALLOONS := [
	[Vector3(-4.45, 2.6, 10.65), 4], [Vector3(4.45, 2.6, 10.65), 4], [Vector3(7.0, 2.95, 10.3), 3], [Vector3(-10.25, 2.4, 3.45), 3],
	[Vector3(-2.75, 2.75, -16.4), 3], [Vector3(2.75, 2.75, -16.4), 3], [Vector3(7.0, 2.7, -6.3), 5],
]
const BALLOON_REACH := 2.8
const STRING_LENGTH := 1.2

var world: Node3D
var scenery: Scenery
var in_ring := false
var drum_roll := 0.0
var _rotors: Array[Node3D] = []
var _pools: Array[MeshInstance3D] = []
var _beams: Array[ShaderMaterial] = []
var _pool_materials: Array[ShaderMaterial] = []
var _targets: Array[Vector3] = []
var _trapeze: MeshInstance3D
var _hoops: Array[MeshInstance3D] = []
var _sticks: MeshInstance3D
var _balloons: MultiMesh
var _balloon_bunch := PackedInt32Array()
var _lean := PackedVector2Array()
var _walker := Vector3.INF
var _walker_sprite: Texture2D
var _posed_still := false

func _init(owner: Node3D, circus_scenery: Scenery) -> void:
	world = owner
	scenery = circus_scenery

func build() -> void:
	var paint: Material = world._vertex_color_material("scenery-detail")
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 1.15
	cone.height = BEAM_LENGTH
	cone.radial_segments = 12
	cone.cap_top = false
	cone.cap_bottom = false
	var disc := QuadMesh.new()
	disc.size = Vector2(2.9, 2.9)
	disc.orientation = PlaneMesh.FACE_Y
	for spec: Array in SPOTS:
		var tint := Color(str(spec[1]))
		var pole: Vector3 = Scenery.KING_POLES[int(spec[0])]
		var rotor := Node3D.new()
		rotor.name = "CircusSpot%d" % _rotors.size()
		rotor.position = Vector3(pole.x, SPOT_HEIGHT, pole.z)
		world.add_child(rotor)
		var beam_material := ShaderMaterial.new()
		beam_material.shader = LIGHT_BEAM
		beam_material.set_shader_parameter("beam_length", BEAM_LENGTH)
		beam_material.set_shader_parameter("beam_color", tint)
		world.material_cache["circus:beam%d" % _rotors.size()] = beam_material
		# The cone's narrow end sits on the lamp and its axis follows the rotor's aim.
		var beam := MeshInstance3D.new()
		beam.mesh = cone
		beam.material_override = beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation.x = PI * 0.5
		beam.position.z = -BEAM_LENGTH * 0.5
		rotor.add_child(beam)
		world.mesh_count += 1
		var light := SpotLight3D.new()
		light.light_color = tint
		light.spot_range = 16.0
		light.spot_angle = 11.0
		light.spot_attenuation = 0.5
		light.light_energy = 0.0
		rotor.add_child(light)
		world.lamps.append(light)
		var pool_material := ShaderMaterial.new()
		pool_material.shader = SPOT_POOL
		pool_material.set_shader_parameter("pool_color", tint)
		world.material_cache["circus:pool%d" % _rotors.size()] = pool_material
		var pool: MeshInstance3D = world._mesh(disc, Vector3.ZERO, pool_material)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The lamp housing on the pole is part of the static trim.
		scenery.kit.detail.box(rotor.position, Vector3(0.34, 0.3, 0.34), Props.IRON)
		scenery.kit.glow.box(rotor.position - Vector3(0, 0.18, 0), Vector3(0.22, 0.08, 0.22), tint)
		_rotors.append(rotor)
		_pools.append(pool)
		_beams.append(beam_material)
		_pool_materials.append(pool_material)
		_targets.append(rest_target(_rotors.size() - 1))
	_trapeze = world._mesh(Props.trapeze_mesh(3.9), TRAPEZE_AT, paint)
	_trapeze.name = "CircusTrapeze"
	for spec: Array in HOOPS:
		var hoop: MeshInstance3D = world._mesh(Props.hoop_mesh(float(spec[1]), Color(str(spec[2]))), Vector3(0, TRAPEZE_AT.y, float(spec[0])), paint)
		hoop.name = "CircusHoop%d" % _hoops.size()
		_hoops.append(hoop)
	_sticks = world._mesh(Props.sticks_mesh(), Scenery.DRUM + Vector3(0.1, 0.92, 0.42), paint)
	_sticks.name = "CircusDrumSticks"
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	for bunch in range(BALLOONS.size()):
		for index in range(int(BALLOONS[bunch][1])):
			transforms.append(Transform3D.IDENTITY)
			tints.append(Props.PARTY[(bunch * 2 + index) % 4].lightened(0.1).srgb_to_linear())
			_balloon_bunch.append(bunch)
	_lean.resize(BALLOONS.size())
	var balloons: MultiMeshInstance3D = world._multi_mesh(Props.balloon_mesh(), Vector3.ZERO, transforms, tints, paint)
	balloons.name = "CircusBalloons"
	_balloons = balloons.multimesh
	# Balloons lean out of their first bounds, so give the batch the whole district.
	_balloons.custom_aabb = AABB(Vector3(-20, 0, -22), Vector3(40, 9, 36))

## Beams are faint by day and bright at night; the ground discs follow them.
func apply_time_of_day(lamp_level: float) -> void:
	for index in range(_beams.size()):
		_beams[index].set_shader_parameter("intensity", 0.1 + lamp_level * 0.36)
		_pool_materials[index].set_shader_parameter("intensity", 0.24 + lamp_level * 0.36)

## The mirrors reflect the walker's own sprite, so they need to know where the
## walker is and which frame is showing. This is not animation: it runs under
## reduced motion too.
func track_walker() -> void:
	var player: Node3D = world.player
	var avatar: Sprite3D = world.avatar
	if not is_instance_valid(player) or not is_instance_valid(avatar): return
	var feet := player.global_position
	if not feet.is_equal_approx(_walker):
		_walker = feet
		scenery.mirror_material.set_shader_parameter("walker", feet)
	if avatar.texture != _walker_sprite and avatar.texture != null:
		_walker_sprite = avatar.texture
		scenery.mirror_material.set_shader_parameter("walker_sprite", _walker_sprite)
		var size := Vector2(_walker_sprite.get_size()) * avatar.pixel_size
		scenery.mirror_material.set_shader_parameter("walker_canvas", Vector3(size.x, size.y, float(world.AvatarRenderer.FEET_BASELINE) / float(world.AvatarRenderer.CANVAS_SIZE.y)))

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if _posed_still: return
	in_ring = false
	drum_roll = 0.0
	for index in range(_rotors.size()):
		_aim(index, rest_target(index))
	for bunch in range(_lean.size()):
		_lean[bunch] = Vector2.ZERO
	_pose(0.0, true)
	_posed_still = true

func animate(delta: float) -> void:
	_posed_still = false
	var time: float = world.time
	var player: Node3D = world.player
	var walker := player.global_position if is_instance_valid(player) else Vector3.INF
	in_ring = Vector2(walker.x - Scenery.RING.x, walker.z - Scenery.RING.z).length() < Scenery.RING_RADIUS
	drum_roll = move_toward(drum_roll, 1.0 if in_ring else 0.0, delta * 3.0)
	for index in range(_rotors.size()):
		# In the ring every spot swings onto the walker; otherwise they wander.
		var wanted := Vector3(walker.x, Scenery.RING.y, walker.z) if in_ring else Scenery.RING + Vector3(cos(time * 0.37 + 2.1 * float(index)) * 2.0, 0, sin(time * 0.29 + 1.3 * float(index)) * 1.7)
		_aim(index, _targets[index].lerp(wanted, 1.0 - exp(-delta * (5.0 if in_ring else 1.5))))
	for bunch in range(_lean.size()):
		var tie: Vector3 = BALLOONS[bunch][0]
		var away := Vector2(tie.x - walker.x, tie.z - walker.z)
		var push := away.normalized() * (1.0 - smoothstep(0.6, BALLOON_REACH, away.length())) * 0.75
		_lean[bunch] = _lean[bunch].move_toward(push, delta * 2.2)
	_pose(time, false)

func spot_target(index: int) -> Vector3:
	return _targets[index]

func balloon_lean(bunch: int) -> Vector2:
	return _lean[bunch]

func trapeze_angle() -> float:
	return _trapeze.rotation.z

func rest_target(index: int) -> Vector3:
	return Scenery.RING + Vector3(cos(2.1 * float(index)) * 2.0, 0, sin(1.3 * float(index)) * 1.7)

func _aim(index: int, target: Vector3) -> void:
	_targets[index] = target
	_rotors[index].look_at(target, Vector3.BACK)
	_pools[index].position = target + Vector3(0, 0.035 + 0.004 * float(index), 0)

func _pose(time: float, still: bool) -> void:
	_trapeze.rotation.z = 0.0 if still else sin(time * 1.2) * 0.32
	for index in range(_hoops.size()):
		_hoops[index].rotation = Vector3.ZERO if still else Vector3(sin(time * 0.9 + 2.0 * float(index)) * 0.14, time * (0.5 if index == 0 else -0.36), 0)
	_sticks.rotation.x = sin(time * 34.0) * 0.4 * drum_roll
	_sticks.position.y = Scenery.DRUM.y + 0.92 + absf(sin(time * 17.0)) * 0.08 * drum_roll
	for index in range(_balloon_bunch.size()):
		var bunch := _balloon_bunch[index]
		var tie: Vector3 = BALLOONS[bunch][0]
		# Each balloon splays a little from its neighbours and bobs on its string.
		var splay := Vector3(sin(2.4 * float(index)), 0, cos(1.7 * float(index) + 0.6)) * 0.32
		var bob := Vector3.ZERO if still else Vector3(sin(time * 0.9 + 1.9 * float(index)), 0, cos(time * 0.7 + 1.1 * float(index))) * 0.06
		var up := (Vector3.UP + splay + bob + Vector3(_lean[bunch].x, 0, _lean[bunch].y)).normalized()
		var size := 0.95 + 0.2 * fposmod(0.37 * float(index), 1.0)
		var basis := Basis(Quaternion(Vector3.UP, up)).scaled(Vector3.ONE * size)
		_balloons.set_instance_transform(index, Transform3D(basis, tie + up * STRING_LENGTH * size))
