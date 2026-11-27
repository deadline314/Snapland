extends RefCounted
## Everything in the greenhouse that moves on its own or because of the player: frogs
## that leap off their lily pads when someone walks up, the weather vane, the
## whirligig and the water dripping from the fountain. Wind, water and dust move in
## shaders. Nothing here is saved or scored, and the reduced-motion pose is one still frame.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/garden_props.gd")
const Scenery := preload("res://game/world/garden_scenery.gd")
## Frogs: home x, z and the offset (x, z) of the leap into open water. The first two
## sit beside the boardwalk stop; the rest are out of its reach.
const FROGS := [
	[-9.25, 0.4, -0.9, 0.5], [-5.2, -0.4, 0.2, -1.1], [-9.5, -3.4, -0.9, 0.5],
	[-5.05, 2.9, 0.2, -1.0], [-9.6, 2.9, -0.9, -0.6], [-5.1, -3.3, 0.2, 1.1],
]
const FROG_ALARM := 2.6
const FROG_CALM := 4.2
const LEAP_SECONDS := 0.5
const AWAY_SECONDS := 3.5
const RISE_SECONDS := 0.6
enum Frog { SITTING, LEAPING, AWAY, RISING }
## Drips: radius from the fountain's axis, height they fall from and to.
const DRIPS := [[0.33, 1.56, 1.07], [0.33, 1.56, 1.07], [0.33, 1.56, 1.07], [0.67, 1.0, Scenery.POND_SURFACE], [0.67, 1.0, Scenery.POND_SURFACE], [0.67, 1.0, Scenery.POND_SURFACE]]

var world: Node3D
var scenery: Scenery
var vane: MeshInstance3D
var whirligig: MeshInstance3D
var _frogs: MultiMesh
var _frog_state := PackedInt32Array()
var _frog_clock := PackedFloat32Array()
var _drips: MultiMesh
var _splashes := PackedVector4Array()
var _next_splash := 0
var _splashing := false
var _posed_still := false


func _init(owner: Node3D, garden_scenery: Scenery) -> void:
	world = owner
	scenery = garden_scenery


func build() -> void:
	var paint: Material = world._vertex_color_material("scenery-detail")
	vane = world._mesh(Props.vane_mesh(), Scenery.RIDGE_END + Vector3(0, 0.95, 0), paint)
	vane.name = "GardenWeatherVane"
	whirligig = world._mesh(Props.whirligig_mesh(), Scenery.WHIRLIGIG, paint)
	whirligig.name = "GardenWhirligig"
	_frogs = _flock(Props.frog_mesh(), FROGS.size(), paint, "GardenFrogs")
	_frog_state.resize(FROGS.size())
	_frog_clock.resize(FROGS.size())
	for index in range(FROGS.size()):
		scenery.lily_pads.add(frog_home(index) - Vector3(0, 0.008, 0), Vector3(1.2, 1.0, 1.2), Basis(Vector3.UP, 1.3 * float(index)), Color("#5c9c62"))
	var drop := Kit.Sculpt.new()
	drop.tube(Vector3.ZERO, 0.035, 0.012, 0.14, Color("#c8f0ea"), 5)
	_drips = _flock(drop.mesh(), DRIPS.size(), paint, "GardenDrips")
	_splashes.resize(4)
	_splashes.fill(Vector4(0, 0, -1, 0))
	hold_still()


## Where a frog rests (world space).
func frog_home(index: int) -> Vector3:
	return Vector3(float(FROGS[index][0]), Scenery.WATER_Y + 0.02, float(FROGS[index][1]))


## True while the frog is sitting on its pad.
func frog_is_out(index: int) -> bool:
	return _frog_state[index] == Frog.SITTING


## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if _posed_still: return
	_posed_still = true
	vane.rotation.y = 0.6
	whirligig.rotation.z = 0.3
	for index in range(FROGS.size()):
		_frog_state[index] = Frog.SITTING
		_frog_clock[index] = 0.0
		_place_frog(index, frog_home(index), 1.0, 0.0)
	for index in range(DRIPS.size()):
		_drips.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_splashes.fill(Vector4(0, 0, -1, 0))
	scenery.wetland_water.set_shader_parameter("splashes", _splashes)
	_splashing = false


func animate(delta: float) -> void:
	_posed_still = false
	var time: float = world.time
	# The vane hunts about the wind's heading; the whirligig just spins.
	vane.rotation.y = 0.53 + sin(time * 0.31) * 0.5 + sin(time * 0.83 + 1.0) * 0.16
	whirligig.rotation.z = time * 2.4
	for index in range(DRIPS.size()):
		var drip: Array = DRIPS[index]
		var fall := fposmod(time * 0.8 + 0.37 * float(index), 1.0)
		var around := Basis(Vector3.UP, 2.1 * float(index) + 0.4)
		var at := Vector3(Scenery.POND.x, lerpf(float(drip[1]), float(drip[2]), fall * fall), Scenery.POND.z) + around * Vector3(float(drip[0]), 0, 0)
		_drips.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
	_update_frogs(delta)
	if _splashing:
		_splashing = false
		for index in range(_splashes.size()):
			var ring := _splashes[index]
			if ring.z < 0.0: continue
			ring.z = ring.z + delta if ring.z < 1.6 else -1.0
			_splashes[index] = ring
			_splashing = _splashing or ring.z >= 0.0
		scenery.wetland_water.set_shader_parameter("splashes", _splashes)


func _update_frogs(delta: float) -> void:
	var player: Node3D = world.player
	if not is_instance_valid(player): return
	var walker := Vector2(player.position.x, player.position.z)
	for index in range(FROGS.size()):
		var home := frog_home(index)
		var distance := walker.distance_to(Vector2(home.x, home.z))
		var dive := home + Vector3(float(FROGS[index][2]), 0, float(FROGS[index][3]))
		_frog_clock[index] += delta
		match _frog_state[index]:
			Frog.SITTING:
				if distance < FROG_ALARM:
					_frog_state[index] = Frog.LEAPING
					_frog_clock[index] = 0.0
				else:
					# A slow breath now and then shows the frog is alive.
					_place_frog(index, home, 1.0 + 0.06 * maxf(0.0, sin(world.time * 2.2 + 1.7 * float(index))), 0.0)
			Frog.LEAPING:
				var leap := minf(1.0, _frog_clock[index] / LEAP_SECONDS)
				_place_frog(index, home.lerp(dive, leap) + Vector3(0, sin(leap * PI) * 0.55, 0), 1.0, leap)
				if leap >= 1.0:
					_frog_state[index] = Frog.AWAY
					_frog_clock[index] = 0.0
					_place_frog(index, dive, 0.0, 1.0)
					_splash(dive)
			Frog.AWAY:
				if _frog_clock[index] > AWAY_SECONDS and distance > FROG_CALM:
					_frog_state[index] = Frog.RISING
					_frog_clock[index] = 0.0
			Frog.RISING:
				var rise := minf(1.0, _frog_clock[index] / RISE_SECONDS)
				_place_frog(index, home + Vector3(0, -0.12 * (1.0 - rise), 0), rise, 0.0)
				if rise >= 1.0: _frog_state[index] = Frog.SITTING


## Frogs face the boardwalk at rest and their leap while they jump.
func _place_frog(index: int, at: Vector3, size: float, leap: float) -> void:
	var home := frog_home(index)
	var boardwalk: Rect2 = world.BOARDWALK
	var facing := Vector2(boardwalk.get_center().x - home.x, 0.0)
	if leap > 0.0: facing = Vector2(float(FROGS[index][2]), float(FROGS[index][3]))
	var basis := Basis(Vector3.UP, atan2(facing.x, facing.y)) * Basis(Vector3.RIGHT, -sin(leap * PI) * 0.6)
	_frogs.set_instance_transform(index, Transform3D(basis.scaled(Vector3.ONE * size * 1.5), at))


func _splash(at: Vector3) -> void:
	_splashes[_next_splash] = Vector4(at.x, at.z, 0.0, 0.0)
	_next_splash = (_next_splash + 1) % _splashes.size()
	_splashing = true


func _flock(mesh: Mesh, count: int, material: Material, label: String) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for index in range(count):
		transforms.append(Transform3D.IDENTITY)
		colors.append(Color.WHITE)
	var instance: MultiMeshInstance3D = world._multi_mesh(mesh, Vector3.ZERO, transforms, colors, material)
	instance.name = label
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance.multimesh
