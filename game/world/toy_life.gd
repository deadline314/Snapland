extends RefCounted
## Everything in the clockwork toy town that moves apart from the train: meshing
## gears, the tower pendulum, wind-up keys, the spinning top, the carousel, kites,
## marbles, and the toys that notice the player (tin soldiers who salute, the
## jack-in-the-box that pops, the floor piano). Nothing here is saved or scored, and
## the reduced-motion pose is one still frame.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/toy_props.gd")
const Scenery := preload("res://game/world/toy_scenery.gd")
## Gear trains. "wall" trains face +Z and "floor" trains lie under the glass; every
## gear is [teeth, parent index, degrees from its parent's centre] and meshes with
## that parent, so one phase drives the whole train.
const TRAINS := [
	{"at": Vector3(-9.5, 2.05, -10.26), "plane": "wall", "size": 0.62, "gears": [[16, -1, 0], [12, 0, 18], [8, 1, -38], [12, 2, 24]]},
	{"at": Scenery.TOWER_AT + Vector3(-0.17, 2.52, 0.872), "plane": "wall", "size": 0.36, "gears": [[12, -1, 0], [8, 0, -30]]},
	{"at": Scenery.GLASS_AT + Vector3(-0.4, 0.05, -0.35), "plane": "floor", "size": 0.5, "gears": [[16, -1, 0], [12, 0, -20], [8, 0, -110], [12, 2, -35], [8, 1, -80]]},
]
const GEAR_SPEED := 0.42
const WIND_SECONDS := 4.0
## Tin soldiers: post x and z, then how far a patrol marches either side (0 stands guard).
const SOLDIERS := [[-3.7, 10.2, 0.0], [3.7, 10.2, 0.0], [-2.75, 19.4, 0.0], [2.75, 19.4, 0.0], [-8.3, 10.6, 2.7], [8.3, 10.6, 2.7]]
const SALUTE_DISTANCE := 4.8
const SALUTE_ANGLE := -2.88
const SHOULDER := Vector3(-0.26, 0.97, 0)
const MARCH_SPEED := 0.7
const JACK_NEAR := 3.3
const JACK_FAR := 4.6
const JACK_REACH := 0.6
## Floor piano: seven keys across the main walk; each plays one of the four notes.
const PIANO := Rect2(-2.45, 2.2, 4.9, 1.0)
const PIANO_NOTES := [0, 1, 2, 3, 2, 1, 0]
const MARBLE_SPEED := 1.5

var world: Node3D
var scenery: Scenery
var _phase := 0.0
var _wind := 0.0
var _gear_batches: Dictionary = {}
## Per gear: [multimesh, slot, plane basis, position, size, ratio, offset].
var _gears: Array[Array] = []
var _keys: MultiMesh
var _pinwheels: MultiMesh
var _pendulum: MeshInstance3D
var _second_hand: MeshInstance3D
var _top: MeshInstance3D
var _top_lean := 0.0
var _carousel: MeshInstance3D
var _kites: Array[MeshInstance3D] = []
var _marbles: MultiMesh
var _marble_lengths := PackedFloat32Array()
var _soldier_bodies: MultiMesh
var _soldier_arms: MultiMesh
var _salute := PackedFloat32Array()
var _march := PackedFloat32Array()
var _yaw := PackedFloat32Array()
var _jack_lid: MeshInstance3D
var _jack_spring: MeshInstance3D
var _jack_head: MeshInstance3D
var _jack := 0.0
var _jack_velocity := 0.0
var _jack_out := false
var _piano: MultiMesh
var _piano_press := PackedFloat32Array()
var _piano_key := -1
var _posed_still := false

func _init(owner: Node3D, toy_scenery: Scenery) -> void:
	world = owner
	scenery = toy_scenery

func build() -> void:
	var paint: Material = world._vertex_color_material("scenery-detail")
	_build_gears(paint)
	_keys = _crowd(Props.key_mesh(), scenery.keys.size(), paint, "ToyWindUpKeys").multimesh
	_pinwheels = _crowd(Props.pinwheel_mesh(), scenery.pinwheels.size(), paint, "ToyPinwheels").multimesh
	_pendulum = _part(Props.pendulum_mesh(1.25), scenery.pendulum_at, paint, "ToyClockPendulum")
	_second_hand = _part(Props.hand_mesh(0.7, 0.025, Props.TEAL.darkened(0.2)), scenery.clock_face_at + Vector3(0, 0, 0.155), paint, "ToyClockSecondHand")
	_second_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_top = _part(Props.top_mesh(), Scenery.TOP_AT, paint, "ToySpinningTop")
	_carousel = _part(Props.carousel_rotor_mesh(), Scenery.CAROUSEL_AT + Vector3(0, 0.32, 0), paint, "ToyCarousel")
	for kite: Array in Scenery.KITES:
		_kites.append(_part(Props.kite_mesh(kite[1]), kite[0], paint, "ToyKite"))
	var marble := SphereMesh.new()
	marble.radius = 0.11
	marble.height = 0.22
	marble.radial_segments = 8
	marble.rings = 4
	_marbles = _crowd(marble, 3, paint, "ToyMarbles", [Props.BLUE, Props.RED, Props.YELLOW]).multimesh
	var travelled := 0.0
	_marble_lengths.append(0.0)
	for index in range(1, scenery.marble_path.size()):
		travelled += scenery.marble_path[index - 1].distance_to(scenery.marble_path[index])
		_marble_lengths.append(travelled)
	_soldier_bodies = _crowd(Props.soldier_mesh(), SOLDIERS.size(), paint, "ToySoldiers").multimesh
	_soldier_arms = _crowd(Props.soldier_arm_mesh(), SOLDIERS.size(), paint, "ToySoldierArms").multimesh
	_salute.resize(SOLDIERS.size())
	_march.resize(SOLDIERS.size())
	_yaw.resize(SOLDIERS.size())
	var box_top := Scenery.JACK_AT + Vector3(0, Scenery.JACK_SIZE, 0)
	_jack_lid = _part(Props.jack_lid_mesh(Scenery.JACK_SIZE), box_top + Vector3(0, 0, -Scenery.JACK_SIZE * 0.5), paint, "ToyJackLid")
	_jack_spring = _part(Props.jack_spring_mesh(), box_top + Vector3(0, -0.1, 0), paint, "ToyJackSpring")
	_jack_head = _part(Props.jack_head_mesh(), box_top, paint, "ToyJackHead")
	var key_colors: Array[Color] = []
	for key in range(PIANO_NOTES.size()):
		key_colors.append(Props.RAINBOW[key])
	_piano = _crowd(BoxMesh.new(), PIANO_NOTES.size(), paint, "ToyFloorPiano", key_colors).multimesh
	_piano_press.resize(PIANO_NOTES.size())
	_pose(true)

## The player cranked the clockwork: everything geared runs fast for a few seconds.
func wind() -> void:
	_wind = 1.0

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if not _posed_still: _pose(true)

func animate(delta: float) -> void:
	_wind = maxf(0.0, _wind - delta / WIND_SECONDS)
	_phase += delta * GEAR_SPEED * (1.0 + 3.0 * _wind)
	_react(delta)
	_pose(false)

## The floor piano sounds even when motion is reduced; only its keys stay put.
func step_piano() -> void:
	var player: Node3D = world.player
	if not is_instance_valid(player): return
	var at := Vector2(player.position.x, player.position.z)
	var key := int((at.x - PIANO.position.x) / PIANO.size.x * float(PIANO_NOTES.size())) if PIANO.has_point(at) else -1
	if key == _piano_key: return
	_piano_key = key
	if key < 0: return
	_piano_press[key] = 1.0
	_posed_still = false
	world.note_requested.emit(PIANO_NOTES[key])

## How far soldier `index` has raised his salute, 0 to 1.
func salute(index: int) -> float:
	return _salute[index]

## How far the jack-in-the-box is out of its box; about 1 when fully popped.
func jack_pop() -> float:
	return _jack

## The angle the gear trains have turned through.
func gear_phase() -> float:
	return _phase

## Where soldier `index` stands on the lawn right now.
func soldier_position(index: int) -> Vector3:
	return Vector3(_soldier_x(index), Scenery.LAWN_Y, float(SOLDIERS[index][1]))

func _part(mesh: Mesh, at: Vector3, material: Material, label: String) -> MeshInstance3D:
	var part: MeshInstance3D = world._mesh(mesh, at, material)
	part.name = label
	return part

## One multimesh whose instances are posed every frame.
func _crowd(mesh: Mesh, count: int, material: Material, label: String, tints: Array[Color] = []) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for index in range(count):
		transforms.append(Transform3D.IDENTITY)
		colors.append(tints[index % tints.size()].srgb_to_linear() if not tints.is_empty() else Color.WHITE)
	var crowd: MultiMeshInstance3D = world._multi_mesh(mesh, Vector3.ZERO, transforms, colors, material)
	crowd.name = label
	return crowd

func _build_gears(paint: Material) -> void:
	var metals: Array[Color] = [Props.BRASS, Props.COPPER, Props.STEEL, Props.BRASS.lightened(0.18)]
	var planned: Array[Array] = []
	var counts := {}
	for train: Dictionary in TRAINS:
		var plane := Basis.IDENTITY if train.plane == "wall" else Basis(Vector3.RIGHT, -PI * 0.5)
		var size: float = train.size
		var centers: Array[Vector2] = []
		var ratios: Array[float] = []
		var offsets: Array[float] = []
		for gear: Array in train.gears:
			var teeth := int(gear[0])
			var parent := int(gear[1])
			var center := Vector2.ZERO
			var ratio := 1.0
			var offset := 0.0
			if parent >= 0:
				var parent_teeth := int(train.gears[parent][0])
				var bearing := deg_to_rad(float(gear[2]))
				center = centers[parent] + Vector2(cos(bearing), sin(bearing)) * float(teeth + parent_teeth) * Props.GEAR_MODULE * 0.5 * size
				ratio = -ratios[parent] * float(parent_teeth) / float(teeth)
				offset = bearing + PI - PI / float(teeth) + (bearing - offsets[parent]) * float(parent_teeth) / float(teeth)
			centers.append(center)
			ratios.append(ratio)
			offsets.append(offset)
			var slot := int(counts.get(teeth, 0))
			counts[teeth] = slot + 1
			planned.append([teeth, slot, plane, train.at + plane * Vector3(center.x, center.y, 0), size, ratio, offset])
	for teeth: int in counts:
		var tints: Array[Color] = []
		for index in range(int(counts[teeth])):
			tints.append(metals[(index + teeth) % metals.size()])
		_gear_batches[teeth] = _crowd(Props.gear_mesh(teeth), int(counts[teeth]), paint, "ToyGears%d" % teeth, tints).multimesh
	for gear in planned:
		_gears.append([_gear_batches[gear[0]], gear[1], gear[2], gear[3], gear[4], gear[5], gear[6]])

## Soldiers, the jack-in-the-box and the piano keys answer the player.
func _react(delta: float) -> void:
	var player: Node3D = world.player
	if not is_instance_valid(player): return
	var at := Vector2(player.position.x, player.position.z)
	for index in range(SOLDIERS.size()):
		var post: Array = SOLDIERS[index]
		var stand := Vector2(_soldier_x(index), float(post[1]))
		var noticed := stand.distance_to(at) < SALUTE_DISTANCE
		_salute[index] = move_toward(_salute[index], 1.0 if noticed else 0.0, delta * (5.0 if noticed else 2.5))
		var reach := float(post[2])
		var heading := 0.0
		if _salute[index] > 0.02:
			heading = atan2(at.x - stand.x, at.y - stand.y)
		elif reach > 0.0:
			_march[index] = fposmod(_march[index] + delta * MARCH_SPEED / (4.0 * reach), 1.0)
			heading = -PI * 0.5 if _march[index] < 0.5 else PI * 0.5
		_yaw[index] = lerp_angle(_yaw[index], heading, minf(1.0, delta * 8.0))
	var jack_distance := Vector2(Scenery.JACK_AT.x, Scenery.JACK_AT.z).distance_to(at)
	if not _jack_out and jack_distance < JACK_NEAR:
		_jack_out = true
		world.note_requested.emit(3)
	elif _jack_out and jack_distance > JACK_FAR:
		_jack_out = false
	# A soft spring: it overshoots on the way out and settles with a wobble.
	_jack_velocity += ((1.0 if _jack_out else 0.0) - _jack) * 70.0 * delta - _jack_velocity * 6.5 * delta
	_jack = maxf(0.0, _jack + _jack_velocity * delta)
	if _jack == 0.0: _jack_velocity = maxf(0.0, _jack_velocity)
	_top_lean = move_toward(_top_lean, 1.0 if Vector2(Scenery.TOP_AT.x, Scenery.TOP_AT.z).distance_to(at) < 2.2 else 0.0, delta * 1.5)
	for key in range(_piano_press.size()):
		_piano_press[key] = maxf(0.0, _piano_press[key] - delta * 2.5)

func _soldier_x(index: int) -> float:
	var post: Array = SOLDIERS[index]
	return float(post[0]) + float(post[2]) * (4.0 * absf(_march[index] - 0.5) - 1.0)

func _pose(still: bool) -> void:
	_posed_still = still
	if still:
		_phase = 0.0
		_wind = 0.0
		_jack = 0.0
		_jack_velocity = 0.0
		_jack_out = false
		_top_lean = 0.0
		_salute.fill(0.0)
		_march.fill(0.0)
		_yaw.fill(0.0)
		_piano_press.fill(0.0)
	var time: float = 0.0 if still else world.time
	for gear in _gears:
		var batch: MultiMesh = gear[0]
		var plane: Basis = gear[2]
		batch.set_instance_transform(gear[1], Transform3D(plane * Basis(Vector3.BACK, float(gear[6]) + float(gear[5]) * _phase).scaled(Vector3.ONE * float(gear[4])), gear[3]))
	for index in range(scenery.keys.size()):
		# A key turns, rests a moment, then turns again, each on its own beat.
		var beat := _phase * 1.6 + float(index) * 1.7
		var turned := floorf(beat / TAU) * TAU + minf(fposmod(beat, TAU) * 1.4, TAU)
		var pose := scenery.keys[index]
		_keys.set_instance_transform(index, Transform3D(pose.basis * Basis(Vector3.BACK, -turned).scaled(Vector3.ONE * scenery.key_sizes[index]), pose.origin))
	for index in range(scenery.pinwheels.size()):
		_pinwheels.set_instance_transform(index, Transform3D(Basis(Vector3.BACK, time * (3.2 + 0.7 * float(index % 3)) + float(index)), scenery.pinwheels[index]))
	_pendulum.rotation.z = 0.34 * sin(_phase * 5.2)
	# The second hand ticks once per pendulum swing.
	_second_hand.rotation.z = -TAU * floorf(_phase * 5.2 / PI) / 60.0
	_top.basis = Basis(Vector3.UP, time * 1.3) * Basis(Vector3.RIGHT, 0.08 + 0.2 * _top_lean + 0.03 * sin(time * 2.1)) * Basis(Vector3.UP, time * 9.0)
	_carousel.rotation.y = time * 0.45
	for index in range(_kites.size()):
		_kites[index].basis = Basis(Vector3.BACK, 0.07 * sin(time * 0.9 + float(index) * 2.0)) * Basis(Vector3.RIGHT, 0.05 * sin(time * 0.63 + float(index)))
	_pose_marbles(time)
	for index in range(SOLDIERS.size()):
		var marching := float(SOLDIERS[index][2]) > 0.0 and _salute[index] <= 0.02 and not still
		var step := time * 6.0 + float(index)
		var body := Transform3D(Basis(Vector3.UP, _yaw[index]) * Basis(Vector3.BACK, 0.05 * sin(step) if marching else 0.0),
			Vector3(_soldier_x(index), Scenery.LAWN_Y + (absf(sin(step)) * 0.035 if marching else 0.0), float(SOLDIERS[index][1])))
		var raised := smoothstep(0.0, 1.0, _salute[index])
		var arm := lerpf(0.5 * sin(step) if marching else 0.0, SALUTE_ANGLE, raised)
		_soldier_bodies.set_instance_transform(index, body)
		_soldier_arms.set_instance_transform(index, body * Transform3D(Basis(Vector3.RIGHT, arm), SHOULDER))
	var box_top := Scenery.JACK_AT.y + Scenery.JACK_SIZE
	_jack_lid.rotation.x = -2.1 * clampf(_jack * 1.6, 0.0, 1.0)
	_jack_head.position.y = lerpf(box_top - 0.75, box_top + JACK_REACH, _jack)
	_jack_head.scale = Vector3.ONE * lerpf(0.5, 1.0, clampf(_jack, 0.0, 1.0))
	_jack_head.rotation.z = 0.22 * sin(time * 7.0) * clampf(absf(_jack_velocity), 0.0, 1.0)
	_jack_spring.scale.y = maxf(0.02, _jack_head.position.y - _jack_spring.position.y)
	for key in range(_piano_press.size()):
		var x := PIANO.position.x + (float(key) + 0.5) * PIANO.size.x / float(_piano_press.size())
		_piano.set_instance_transform(key, Transform3D(Basis.from_scale(Vector3(0.64, 0.06, 0.9)), Vector3(x, Scenery.GLASS_AT.y + 0.04 - 0.025 * _piano_press[key], PIANO.get_center().y)))

## Marbles roll down the run one after another, vanish into the tray and start again.
func _pose_marbles(time: float) -> void:
	var total := _marble_lengths[_marble_lengths.size() - 1]
	var lap := total + 1.6
	for index in range(3):
		var travelled := fposmod(time * MARBLE_SPEED + lap * float(index) / 3.0, lap)
		if travelled >= total:
			_marbles.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), scenery.marble_path[0]))
			continue
		var leg := 1
		while _marble_lengths[leg] < travelled:
			leg += 1
		var share := inverse_lerp(_marble_lengths[leg - 1], _marble_lengths[leg], travelled)
		_marbles.set_instance_transform(index, Transform3D(Basis.IDENTITY, scenery.marble_path[leg - 1].lerp(scenery.marble_path[leg], share)))
