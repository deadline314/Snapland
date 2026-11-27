extends RefCounted
## Everything in the tidal harbor that moves: boats and buoys riding the tide, the
## ferry at its berth, fish, the lighthouse beam, the tide bell and the crabs that
## scuttle away from the player. Gulls come from the shared world ambience. Nothing here is saved or scored, and the
## reduced-motion pose is one still frame.

const Props := preload("res://game/world/harbor_props.gd")
const Scenery := preload("res://game/world/harbor_scenery.gd")
const AFLOAT := -9.0
## A hull left on a sand flat rests this high: the flat's top plus the hull's draught.
const AGROUND := Scenery.FLAT_TOP + 0.14
## Ferry berths as x, z, yaw; index 0 is the shore side.
const FERRY_BERTHS := [[-7.5, 5.4, 0.0], [-2.0, 5.8, PI * 0.5]]
const SLOOP := [-5.6, 15.0, PI]
## Rowboats: x, z, yaw, resting height, tint.
const ROWBOATS := [
	[17.6, 4.75, 1.45, AFLOAT, "#ffa08c"], [7.3, 6.3, 0.5, AGROUND, "#f7b267"],
	[-7.4, -6.6, 2.2, AGROUND, "#ffd884"], [6.7, -5.7, -0.4, AFLOAT, "#ffffff"],
	[-16.3, 9.7, 0.25, AGROUND, "#b4c8ff"], [4.8, 12.95, 1.62, AFLOAT, "#f4f0e0"], [-17.3, 0.9, 0.15, AFLOAT, "#9fd6c8"],
]
## Buoys: x, z, tint.
const BUOYS := [
	[-5.3, 4.4, "#e8604c"], [6.9, 1.4, "#e8604c"], [19.5, -6.5, "#e8604c"], [-21.0, -3.0, "#f0c060"],
	[3.5, 17.6, "#e8604c"], [-11.5, -17.0, "#f0c060"], [22.5, 11.0, "#e8604c"], [11.5, 16.8, "#f0c060"],
]
## Crabs: home x, surface height, home z, and the patch of ground they stay on.
const CRABS := [
	[1.6, Scenery.FLAT_TOP, 4.4, 0], [-2.2, Scenery.FLAT_TOP, 4.4, 0], [5.0, Scenery.FLAT_TOP, 1.9, 1], [5.0, Scenery.FLAT_TOP, -2.0, 1],
	[-6.2, 0.2, 1.0, 2], [-7.5, 0.2, -0.9, 2], [-5.9, 0.2, 10.9, 3], [-2.4, 0.2, 11.2, 3],
]
## Islet beach south and east strips, the sandbar, and the boardwalk by the crab stall.
const CRAB_PATCHES: Array[Rect2] = [
	Rect2(-3.6, 4.15, 7.4, 0.4), Rect2(4.2, -3.2, 1.0, 6.4), Rect2(-8.8, -1.3, 4.6, 2.6), Rect2(-8.6, 9.3, 8.0, 2.4),
]
const SANDBAR_PATCH := 2
const CRAB_ALARM_DISTANCE := 2.6
const CRAB_FLIGHT := 1.7
## Fish circling in the lagoon: centre x, z, radius x, z, radians per second, phase.
const FISH := [
	[7.7, -0.6, 0.8, 3.4, 0.33, 0.0], [7.7, -0.6, 0.8, 3.4, 0.33, 0.5], [7.7, -0.6, 0.65, 3.1, 0.33, 1.1], [7.7, -0.6, 0.9, 3.5, 0.33, 3.4],
	[3.0, 6.25, 2.0, 0.55, -0.4, 0.0], [3.0, 6.25, 1.8, 0.45, -0.4, 0.6], [3.0, 6.25, 2.1, 0.6, -0.4, 2.9],
]

var world: Node3D
var scenery: Scenery
var ferry: MeshInstance3D
var _ferry_berth := 0
var _sloop: MeshInstance3D
var _rowboats: MultiMesh
var _buoys: MultiMesh
var _crabs: MultiMesh
var _crab_offsets := PackedVector2Array()
var _fish: MultiMesh
var _foam_rings := PackedFloat32Array()
var _water_y := 0.0
var _bell_ringing := 0.0
var _posed_still := false

func _init(owner: Node3D, harbor_scenery: Scenery) -> void:
	world = owner
	scenery = harbor_scenery

func build() -> void:
	var paint: Material = world._vertex_color_material("scenery-detail")
	ferry = world._mesh(Props.ferry_mesh(), Vector3.ZERO, paint)
	ferry.name = "HarborFerry"
	_sloop = world._mesh(Props.sloop_mesh(), Vector3.ZERO, paint)
	_rowboats = _fleet(Props.rowboat_mesh(), ROWBOATS, 4, paint).multimesh
	_buoys = _fleet(Props.buoy_mesh(), BUOYS, 2, paint).multimesh
	_crabs = _fleet(Props.crab_mesh(), CRABS, -1, paint).multimesh
	_crab_offsets.resize(CRABS.size())
	_fish = _fleet(Props.fish_mesh(), FISH, -1, paint).multimesh
	# Hulls draw foam where they sit in the sea: the ferry first, then the moored boats.
	_foam_rings.resize(72)
	var next := _hull_rings(3, SLOOP[0], SLOOP[1], SLOOP[2], 3.6, 1.3, 3)
	for boat: Array in ROWBOATS:
		next = _hull_rings(next, boat[0], boat[1], boat[2], 2.5, 1.05, 2)
	world.sea_material.set_shader_parameter("ring_count", next)
	moor_ferry(0)

## The ferry waits wherever the player last landed.
func moor_ferry(berth: int) -> void:
	_ferry_berth = berth
	var at: Array = FERRY_BERTHS[berth]
	_hull_rings(0, at[0], at[1], at[2], 4.4, 1.8, 3)
	world.sea_material.set_shader_parameter("foam_rings", _foam_rings)
	_posed_still = false

func ring_bell() -> void:
	_bell_ringing = 2.0

func set_water_level(water_y: float) -> void:
	_water_y = water_y
	_posed_still = false

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if not _posed_still: _pose(true)

func animate(delta: float) -> void:
	_bell_ringing = maxf(0.0, _bell_ringing - delta)
	_pose(false)
	_scuttle_crabs(delta)

## Where a crab is on the ground right now (x, z).
func crab_position(index: int) -> Vector2:
	return Vector2(float(CRABS[index][0]), float(CRABS[index][2])) + _crab_offsets[index]

## One multimesh whose instances are posed every frame; `tint_column` picks the tint.
func _fleet(mesh: Mesh, table: Array, tint_column: int, material: Material) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for row: Array in table:
		transforms.append(Transform3D.IDENTITY)
		colors.append(Color(str(row[tint_column])).srgb_to_linear() if tint_column >= 0 else Color.WHITE)
	return world._multi_mesh(mesh, Vector3.ZERO, transforms, colors, material)

## Writes foam circles along a hull into the sea's ring list; returns the next free slot.
func _hull_rings(slot: int, x: float, z: float, yaw: float, length: float, beam: float, count: int) -> int:
	for index in range(count):
		var along := (float(index) / float(count - 1) - 0.5) * (length - beam)
		_foam_rings[slot * 3] = x + sin(yaw) * along
		_foam_rings[slot * 3 + 1] = z + cos(yaw) * along
		_foam_rings[slot * 3 + 2] = beam * 0.5
		slot += 1
	return slot

func _pose(still: bool) -> void:
	_posed_still = still
	var time: float = world.time
	var berth: Array = FERRY_BERTHS[_ferry_berth]
	ferry.transform = _float_pose(berth[0], AFLOAT, berth[1], berth[2], 0.4, still)
	_sloop.transform = _float_pose(SLOOP[0], AFLOAT, SLOOP[1], SLOOP[2], 2.2, still)
	for index in range(ROWBOATS.size()):
		var boat: Array = ROWBOATS[index]
		_rowboats.set_instance_transform(index, _float_pose(boat[0], boat[3], boat[1], boat[2], 1.7 * float(index), still))
	for index in range(BUOYS.size()):
		_buoys.set_instance_transform(index, _float_pose(BUOYS[index][0], AFLOAT, BUOYS[index][1], 0.0, 2.3 * float(index), still, 2.4))
	for index in range(FISH.size()):
		var fish: Array = FISH[index]
		var angle := float(fish[5]) + (0.0 if still else time * float(fish[4]))
		var heading := atan2(-sin(angle) * float(fish[2]), cos(angle) * float(fish[3])) + (PI if float(fish[4]) < 0.0 else 0.0)
		var wiggle := 0.0 if still else sin(time * 6.0 + float(index)) * 0.25
		_fish.set_instance_transform(index, Transform3D(Basis(Vector3.UP, heading + wiggle), Vector3(float(fish[0]) + cos(angle) * float(fish[2]), _water_y + 0.015, float(fish[1]) + sin(angle) * float(fish[3]))))
	scenery.beam_rotor.rotation.y = 0.6 if still else time * 0.5
	scenery.tide_bell.rotation.z = 0.0 if still else sin(_bell_ringing * 11.0) * 0.25 * _bell_ringing
	if still:
		for index in range(CRABS.size()):
			_crab_offsets[index] = Vector2.ZERO
			_place_crab(index, 0.0)

## A hull at rest on the water, or leaning on the sand when the tide has left it aground.
func _float_pose(x: float, rest_y: float, z: float, yaw: float, phase: float, still: bool, liveliness := 1.0) -> Transform3D:
	var time: float = world.time
	var basis := Basis(Vector3.UP, yaw)
	var y := maxf(rest_y, _water_y)
	if _water_y <= rest_y:
		basis *= Basis(Vector3.BACK, 0.14)
	elif not still:
		y += sin(time * 1.3 + phase) * 0.04 * liveliness
		basis *= Basis(Vector3.BACK, sin(time * 0.9 + phase * 2.0) * 0.05 * liveliness) * Basis(Vector3.RIGHT, cos(time * 1.1 + phase) * 0.03 * liveliness)
	return Transform3D(basis, Vector3(x, y, z))

func _scuttle_crabs(delta: float) -> void:
	var player: Node3D = world.player
	if not is_instance_valid(player): return
	var time: float = world.time
	var player_at := Vector2(player.position.x, player.position.z)
	for index in range(CRABS.size()):
		var crab: Array = CRABS[index]
		var home := Vector2(float(crab[0]), float(crab[2]))
		var offset := _crab_offsets[index]
		var away := home + offset - player_at
		var alarmed := away.length_squared() < CRAB_ALARM_DISTANCE * CRAB_ALARM_DISTANCE
		# Crabs run half sideways, so one cornered at the edge of its patch slips along it.
		var escape := away.normalized()
		var target := (escape + escape.orthogonal() * (0.7 if index % 2 == 0 else -0.7)) * CRAB_FLIGHT if alarmed else Vector2(sin(time * 0.5 + 2.1 * float(index)), cos(time * 0.37 + float(index))) * 0.22
		var patch := CRAB_PATCHES[int(crab[3])]
		_crab_offsets[index] = (home + offset.move_toward(target, (3.2 if alarmed else 0.35) * delta)).clamp(patch.position, patch.end) - home
		_place_crab(index, sin(time * 14.0 + float(index)) * 0.05 if alarmed else 0.0)

func _place_crab(index: int, wobble: float) -> void:
	var crab: Array = CRABS[index]
	var offset := _crab_offsets[index]
	var surface: float = scenery.sandbar_bank.position.y if int(crab[3]) == SANDBAR_PATCH else float(crab[1])
	# A crab the tide has covered is simply gone until the water drops again.
	var size := 0.0 if _water_y > surface + 0.02 else 1.0
	_crabs.set_instance_transform(index, Transform3D(Basis(Vector3.UP, 0.9 * float(index) + offset.x * 2.0 + wobble).scaled(Vector3.ONE * size), Vector3(float(crab[0]) + offset.x, surface, float(crab[2]) + offset.y)))
