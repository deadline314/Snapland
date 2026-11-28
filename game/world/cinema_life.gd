extends RefCounted
## Everything in the Starlight Cinema that moves: the film on the big screen
## and the projector's dusty beam (a new reel brings up the countdown leader),
## the projector's turning reels, two searchlights sweeping the night sky from
## the premiere palace, the paparazzi's flashes popping along the red carpet
## (a walk down it sets them all off and swings the gold doors open), the
## camera crane drifting over the sound stage (a call of "action" sends it
## swooping and flares the studio lamps), the castle flat that topples and
## rewinds, and the splash that catches a step off a sandbar. Built once;
## nothing here is saved, and the reduced-motion pose is one still frame.

const Scenery := preload("res://game/world/cinema_scenery.gd")
const Kit := preload("res://game/world/scenery_kit.gd")
const FILM := preload("res://game/world/cinema_film.gdshader")
const BEAM := preload("res://game/world/cinema_beam.gdshader")
const SEARCHLIGHT_LENGTH := 26.0
const SWEEP_SECONDS := 9.0
const LEADER_SECONDS := 1.2
const FLASH_SECONDS := 0.14
const TOPPLE_SECONDS := 2.2
const ACTION_SECONDS := 3.2
const CARPET_SECONDS := 3.0
const CATCH_SECONDS := 0.7
const CRANE_REACH := 3.4

var world: Node3D
var scenery: Scenery
var film: ShaderMaterial
var beam_material: ShaderMaterial
var search_material: ShaderMaterial
var screen: MeshInstance3D
var beam: MeshInstance3D
var searchlights: Array[MeshInstance3D] = []
var reels: Array[MeshInstance3D] = []
var crane: Node3D
var rewind_flat: Node3D
var doors: Array[Node3D] = []
var splash: MeshInstance3D
var _flashes: MultiMesh
## Every bulb the flashes can pop: the paparazzi's guns, then the two studio lamps.
var _flash_spots: Array[Vector3] = []
var _flash_left := PackedFloat32Array()
var _flash_wait := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _leader := 0.0
var _topple := 0.0
var _action := 0.0
var _carpet := 0.0
var _catch := 0.0
var _crane_yaw := 0.0
var _posed_still := false

func _init(owner: Node3D, cinema_scenery: Scenery) -> void:
	world = owner
	scenery = cinema_scenery

func build() -> void:
	_rng.seed = 6801
	_build_screen()
	_build_beams()
	_build_projector_reels()
	_build_crane()
	_build_rewind_flat()
	_build_doors()
	_build_flashes()
	_build_splash()

# --- Screen and beams ---------------------------------------------------------------

func _build_screen() -> void:
	film = world.material_cache.get("cinema:film")
	if film == null:
		film = ShaderMaterial.new()
		film.shader = FILM
		world.material_cache["cinema:film"] = film
		world.component_motion.register_shader(film)
	var quad := QuadMesh.new()
	quad.size = Vector2(Scenery.SCREEN_WIDTH, Scenery.SCREEN_HEIGHT)
	var base: Vector3 = world.SCREEN
	screen = world._mesh(quad, base + Vector3(0, Scenery.SCREEN_BOTTOM + Scenery.SCREEN_HEIGHT * 0.5, 0.0), film)
	screen.name = "CinemaScreen"
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The projector's throw, a frustum from the lens to the picture, and two
## searchlight cones that stand on the palace roof.
func _build_beams() -> void:
	beam_material = _beam_material("cinema:beam", Color(1.0, 0.94, 0.78), 0.8)
	var base: Vector3 = world.SCREEN
	var half := Scenery.SCREEN_WIDTH * 0.5
	var low := base.y + Scenery.SCREEN_BOTTOM
	var high := low + Scenery.SCREEN_HEIGHT
	var near := PackedVector3Array()
	var far := PackedVector3Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		near.append(Scenery.LENS + Vector3(corner.x * 0.08, corner.y * 0.06, -0.05))
		far.append(Vector3(base.x + corner.x * half, low if corner.y < 0.0 else high, base.z + 0.05))
	beam = world._mesh(_beam_mesh(near, far), Vector3.ZERO, beam_material)
	beam.name = "CinemaProjectorBeam"
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	search_material = _beam_material("cinema:search", Color(0.86, 0.92, 1.0), 0.55)
	var ring_near := PackedVector3Array()
	var ring_far := PackedVector3Array()
	for index in 12:
		var angle := TAU * float(index) / 12.0
		ring_near.append(Vector3(cos(angle) * 0.22, 0.0, sin(angle) * 0.22))
		ring_far.append(Vector3(cos(angle) * 2.2, SEARCHLIGHT_LENGTH, sin(angle) * 2.2))
	var cone := _beam_mesh(ring_near, ring_far)
	var doors_at: Vector3 = world.DOORS
	for side: float in [-1.0, 1.0]:
		var light: MeshInstance3D = world._mesh(cone, Vector3(doors_at.x + side * 2.3, doors_at.y + 5.25, doors_at.z - 0.65), search_material)
		light.name = "CinemaSearchlight%d" % searchlights.size()
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		searchlights.append(light)
		var head := Kit.Sculpt.new()
		head.tube(Vector3(0, 0.1, 0), 0.34, 0.28, 0.5, Color("#3a3640"), 10)
		head.tube(Vector3(0, 0.37, 0), 0.3, 0.3, 0.05, Color(1.0, 0.96, 0.84, 0.5), 10)
		_child_mesh(light, head.mesh(), world._vertex_color_material("scenery-detail")).name = "SearchlightHead"

func _beam_material(key: String, tint: Color, fade: float) -> ShaderMaterial:
	var material: ShaderMaterial = world.material_cache.get(key)
	if material != null: return material
	material = ShaderMaterial.new()
	material.shader = BEAM
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("fade_power", fade)
	world.material_cache[key] = material
	world.component_motion.register_shader(material)
	return material

## The sides of a beam between two loops of the same size; UV.y runs 0 at
## `near` to 1 at `far`, UV.x round the loop.
static func _beam_mesh(near: PackedVector3Array, far: PackedVector3Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := near.size()
	var centre := Vector3.ZERO
	for point in near + far: centre += point
	centre /= float(count * 2)
	for index in count:
		var next := (index + 1) % count
		var u0 := float(index) / float(count)
		var u1 := float(index + 1) / float(count)
		var outward := ((near[index] + near[next] + far[index] + far[next]) * 0.25 - centre)
		var normal := (far[next] - near[index]).cross(far[index] - near[next]).normalized()
		if normal.dot(outward) < 0.0: normal = -normal
		for corner: Array in [[near[index], Vector2(u0, 0)], [far[index], Vector2(u0, 1)], [far[next], Vector2(u1, 1)],
				[near[index], Vector2(u0, 0)], [far[next], Vector2(u1, 1)], [near[next], Vector2(u1, 0)]]:
			tool.set_normal(normal)
			tool.set_uv(corner[1])
			tool.add_vertex(corner[0])
	return tool.commit()

## Two reels on top of the projector, turning in film-strip time.
func _build_projector_reels() -> void:
	var reel := Kit.Sculpt.new()
	reel.tube(Vector3.ZERO, 0.34, 0.34, 0.05, Color("#9aa1ab"), 16, Basis(Vector3.RIGHT, PI * 0.5))
	for hole in 4:
		var angle := TAU * float(hole) / 4.0
		reel.box(Vector3(cos(angle), sin(angle), 0) * 0.17 + Vector3(0, 0, 0.03), Vector3(0.1, 0.24, 0.02), Color("#3a3640"), Basis(Vector3.BACK, angle + PI * 0.5))
	reel.tube(Vector3(0, 0, 0.03), 0.06, 0.06, 0.04, Color("#e8b54f"), 8, Basis(Vector3.RIGHT, PI * 0.5))
	var shape := reel.mesh()
	var at: Vector3 = world.PROJECTOR
	for offset: Vector3 in [Vector3(-0.32, 1.78, 0.0), Vector3(0.36, 1.72, 0.0)]:
		var spinning: MeshInstance3D = world._mesh(shape, at + offset, world._vertex_color_material("scenery-detail"))
		spinning.name = "CinemaProjectorReel%d" % reels.size()
		reels.append(spinning)

# --- Crane, flat and doors ---------------------------------------------------------

## The camera crane's arm: counterweights at the back, a lattice boom and the
## camera with its hood at the tip, on a pivot that turns and dips.
func _build_crane() -> void:
	crane = Node3D.new()
	crane.name = "CinemaCraneArm"
	crane.position = world.CRANE + Vector3(0, 1.7, 0)
	world.add_child(crane)
	var s := Kit.Sculpt.new()
	s.box(Vector3(CRANE_REACH * 0.5 - 0.6, 0, 0), Vector3(CRANE_REACH + 1.2, 0.12, 0.14), Color("#4b4552"))
	s.box(Vector3(CRANE_REACH * 0.5 - 0.6, 0.22, 0), Vector3(CRANE_REACH + 0.9, 0.06, 0.08), Color("#6d7380"))
	for strut in 8:
		var x := -0.4 + float(strut) * (CRANE_REACH + 0.2) / 7.0
		s.box(Vector3(x, 0.11, 0), Vector3(0.04, 0.26, 0.06), Color("#6d7380"), Basis(Vector3.BACK, 0.6 if strut % 2 == 0 else -0.6))
	for weight in 3:
		s.box(Vector3(-0.95 - float(weight) * 0.16, -0.12, 0), Vector3(0.14, 0.42, 0.36), Color("#e8b54f") if weight == 1 else Color("#3a3640"))
	var tip := Vector3(CRANE_REACH, -0.2, 0)
	s.box(tip + Vector3(0, -0.08, 0), Vector3(0.08, 0.3, 0.08), Color("#3a3640"))
	s.box(tip + Vector3(0, -0.36, 0), Vector3(0.52, 0.34, 0.3), Color("#2e2a33"))
	s.tube(tip + Vector3(0.36, -0.36, 0), 0.12, 0.15, 0.24, Color("#41455a"), 8, Basis(Vector3.BACK, PI * 0.5))
	for reel: float in [-0.1, 0.16]:
		s.tube(tip + Vector3(reel, -0.06, 0), 0.13, 0.13, 0.05, Color("#9aa1ab"), 12, Basis(Vector3.RIGHT, PI * 0.5))
	s.ball(tip + Vector3(-0.12, -0.24, 0.17), 0.04, Color(1.0, 0.25, 0.2, 0.5), Color.TRANSPARENT, 6, 3)
	_child_mesh(crane, s.mesh(), world.material_cache["cinema:painted"]).name = "CraneBoom"

## The castle tower flat: painted stone, an arched window cut through it,
## crenellations and a pennant. It hinges on its foot so it can fall on its
## face and rewind.
func _build_rewind_flat() -> void:
	rewind_flat = Node3D.new()
	rewind_flat.name = "CinemaRewindFlat"
	var at: Vector3 = world.REWIND_FLAT
	rewind_flat.position = Vector3(at.x, at.y, Scenery.FLAT_Z)
	world.add_child(rewind_flat)
	var s := Kit.Sculpt.new()
	var stone := Color("#b8b4c8")
	var mortar := Color("#8e8aa2")
	var width := 2.2
	var height := 3.6
	# Face round an arched window hole.
	s.quad(Vector3(-width * 0.5, 0, 0.02), Vector3(width * 0.5, 0, 0.02), Vector3(width * 0.5, 1.9, 0.02), Vector3(-width * 0.5, 1.9, 0.02), stone)
	s.quad(Vector3(-width * 0.5, 2.8, 0.02), Vector3(width * 0.5, 2.8, 0.02), Vector3(width * 0.5, height, 0.02), Vector3(-width * 0.5, height, 0.02), stone)
	for side: float in [-1.0, 1.0]:
		s.quad(Vector3(side * width * 0.5, 1.9, 0.02), Vector3(side * 0.35, 1.9, 0.02), Vector3(side * 0.35, 2.8, 0.02), Vector3(side * width * 0.5, 2.8, 0.02), stone)
	s.box(Vector3(0, 1.88, 0.05), Vector3(0.84, 0.08, 0.08), mortar)
	for brick in 5:
		var angle := PI * float(brick) / 4.0
		s.box(Vector3(cos(angle) * 0.38, 2.62 + sin(angle) * 0.22, 0.05), Vector3(0.18, 0.12, 0.08), mortar, Basis(Vector3.BACK, angle - PI * 0.5))
	for course in 6:
		s.box(Vector3(0, 0.3 + float(course) * 0.6, 0.04), Vector3(width - 0.1, 0.035, 0.02), mortar)
		for joint in 3:
			s.box(Vector3(-0.7 + float(joint) * 0.7 + 0.35 * float(course % 2), 0.6 + float(course) * 0.6, 0.04), Vector3(0.035, 0.6, 0.02), mortar)
	for merlon in 4:
		s.box(Vector3(-width * 0.5 + 0.28 + float(merlon) * (width - 0.56) / 3.0, height + 0.2, 0.0), Vector3(0.34, 0.4, 0.08), stone)
	s.box(Vector3(0, height * 0.5, -0.04), Vector3(width, height, 0.04), Color("#c9a273"))
	s.box(Vector3(0.6, height + 0.9, 0), Vector3(0.04, 1.2, 0.04), Color("#6e4c32"))
	s.sheet(Vector3(0.62, height + 1.45, 0), Vector3(0.62, height + 1.1, 0), Vector3(1.2, height + 1.28, 0), Color("#e2795e"))
	_child_mesh(rewind_flat, s.mesh(), world.material_cache["cinema:painted"]).name = "CastleFace"

## The palace's gold double doors, hinged at their outer edges.
func _build_doors() -> void:
	var at: Vector3 = world.DOORS
	var s := Kit.Sculpt.new()
	s.box(Vector3(0.43, 1.22, 0), Vector3(0.86, 2.44, 0.08), Color("#e8b54f"))
	for panel in 3:
		s.box(Vector3(0.43, 0.45 + float(panel) * 0.75, 0.05), Vector3(0.6, 0.55, 0.02), Color("#c99a45"))
	s.ball(Vector3(0.74, 1.2, 0.08), 0.05, Color("#fff1d6"), Color.TRANSPARENT, 6, 3)
	var leaf := s.mesh()
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "CinemaDoor%d" % doors.size()
		hinge.position = Vector3(at.x + side * 0.88, at.y + 0.04, at.z - 0.1)
		# The right leaf is the left one mirrored, so both show their panels.
		hinge.scale.x = side * -1.0
		world.add_child(hinge)
		_child_mesh(hinge, leaf, world.material_cache["cinema:painted"])
		doors.append(hinge)

## A mesh that moves with a pivot of its own.
func _child_mesh(parent: Node3D, shape: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	parent.add_child(instance)
	return instance

# --- Flashes and splash ------------------------------------------------------------

## One batch of bright bulbs that pop: the paparazzi's flash guns and the
## studio lamps' faces.
func _build_flashes() -> void:
	_flash_spots.assign(scenery.flash_spots)
	for index in range(scenery.stage_lamps_from, scenery.lamp_faces.size()):
		_flash_spots.append(scenery.lamp_faces[index])
	var bulb := SphereMesh.new()
	bulb.radius = 0.5
	bulb.height = 1.0
	bulb.radial_segments = 8
	bulb.rings = 4
	var material: StandardMaterial3D = world.material_cache.get("cinema:flash")
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.98, 0.9)
		world.material_cache["cinema:flash"] = material
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot in _flash_spots:
		transforms.append(Transform3D(Basis.from_scale(Vector3.ZERO), spot))
		tints.append(Color.WHITE)
	var batch: MultiMeshInstance3D = world._multi_mesh(bulb, Vector3.ZERO, transforms, tints, material)
	batch.name = "CinemaFlashes"
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flashes = batch.multimesh
	_flashes.custom_aabb = AABB(Vector3(-2, -1, -16), Vector3(22, 6, 30))
	_flash_left.resize(_flash_spots.size())
	_flash_wait.resize(_flash_spots.size())
	for index in _flash_spots.size():
		_flash_wait[index] = 0.8 + _rng.randf() * 4.0 if index < scenery.flash_spots.size() else INF

## A ring of white water where a step off a sandbar is caught.
func _build_splash() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.32
	ring.outer_radius = 0.5
	ring.rings = 16
	ring.ring_segments = 4
	var material: StandardMaterial3D = world.material_cache.get("cinema:splash")
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(0.93, 0.97, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		world.material_cache["cinema:splash"] = material
	splash = world._mesh(ring, Vector3.ZERO, material)
	splash.name = "CinemaSplash"
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.visible = false

# --- Running the show --------------------------------------------------------------

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if _posed_still: return
	_leader = 0.0
	_topple = 0.0
	_action = 0.0
	_carpet = 0.0
	_catch = 0.0
	_flash_left.fill(0.0)
	splash.visible = false
	film.set_shader_parameter("leader", 0.0)
	_pose(0.0, true)
	_posed_still = true

func animate(delta: float) -> void:
	_posed_still = false
	_leader = maxf(_leader - delta / LEADER_SECONDS, 0.0)
	film.set_shader_parameter("leader", smoothstep(0.0, 0.3, _leader))
	_topple = maxf(_topple - delta / TOPPLE_SECONDS, 0.0)
	_action = maxf(_action - delta / ACTION_SECONDS, 0.0)
	_carpet = maxf(_carpet - delta / CARPET_SECONDS, 0.0)
	for index in _flash_spots.size():
		_flash_left[index] = maxf(_flash_left[index] - delta, 0.0)
		_flash_wait[index] -= delta
		if _flash_wait[index] <= 0.0:
			_flash_left[index] = FLASH_SECONDS
			var busy := 0.25 if _carpet > 0.0 else 1.0
			_flash_wait[index] = (1.5 + _rng.randf() * 4.5) * busy if index < scenery.flash_spots.size() else INF
	if _catch > 0.0:
		_catch = maxf(_catch - delta / CATCH_SECONDS, 0.0)
		var age := 1.0 - _catch
		splash.scale = Vector3(0.5 + age * 1.6, 1.0, 0.5 + age * 1.6)
		splash.visible = _catch > 0.0
	_pose(world.time, false)

func change_reel(index: int) -> void:
	film.set_shader_parameter("reel", index)
	_leader = 0.0 if world.reduced_motion else 1.0

func flash_carpet() -> void:
	_carpet = 1.0
	for index in scenery.flash_spots.size():
		_flash_wait[index] = 0.06 + float(index) * 0.07

func topple_flat() -> void:
	if not world.reduced_motion: _topple = 1.0

func call_action() -> void:
	if world.reduced_motion: return
	_action = 1.0
	for index in range(scenery.flash_spots.size(), _flash_spots.size()):
		_flash_left[index] = 0.5

## A step over a sandbar's edge: a ring of white water where the foot was caught.
func catch_step(at: Vector3) -> void:
	if _catch > 0.3 or world.reduced_motion: return
	_catch = 1.0
	splash.position = Vector3(at.x, world.WATER_Y + 0.03, at.z)
	splash.scale = Vector3(0.5, 1.0, 0.5)
	splash.visible = true

## The screen glows brighter, and the beams show, as the light goes.
func apply_time_of_day(lamp_level: float, _phase: String) -> void:
	film.set_shader_parameter("brightness", lerpf(0.62, 1.18, lamp_level))
	beam_material.set_shader_parameter("strength", lerpf(0.05, 0.3, lamp_level))
	search_material.set_shader_parameter("strength", lamp_level * 0.32)
	for light in searchlights:
		light.visible = lamp_level > 0.05

func catching() -> bool:
	return splash.visible

func crane_yaw() -> float:
	return crane.rotation.y

func flat_tilt() -> float:
	return rewind_flat.rotation.x

func searchlight_tilt(index: int) -> Vector3:
	return searchlights[index].rotation

func reel_angle() -> float:
	return reels[0].rotation.z

func door_angle() -> float:
	return absf(doors[0].rotation.y)

func flashes_lit() -> int:
	var lit := 0
	for left in _flash_left: lit += int(left > 0.0)
	return lit

func _pose(time: float, still: bool) -> void:
	# Projector reels.
	for index in reels.size():
		reels[index].rotation.z = 0.0 if still else -time * (2.6 + 0.4 * float(index))
	# Searchlights lean out and sweep in slow figure-eights, never in step.
	for index in searchlights.size():
		var side := -1.0 if index == 0 else 1.0
		var phase := time * TAU / SWEEP_SECONDS + float(index) * 1.9
		var lean := 0.42 + (0.0 if still else 0.16 * sin(phase * 0.7))
		var turn := side * 0.5 + (0.0 if still else sin(phase) * 1.1)
		searchlights[index].rotation = Vector3(-lean, turn, 0.0)
	# The crane drifts; called to action it swoops over the stage and back.
	var swoop := sin((1.0 - _action) * PI) if _action > 0.0 else 0.0
	_crane_yaw = -2.2 + (0.0 if still else 0.5 * sin(time * 0.23)) + swoop * 1.2
	crane.rotation = Vector3(0, _crane_yaw, 0.0 if still else 0.12 * sin(time * 0.37) - swoop * 0.35)
	# The flat: falls on its face, lies a moment, then rewinds upright.
	var fall := 0.0
	if _topple > 0.0:
		var age := (1.0 - _topple) * TOPPLE_SECONDS
		if age < 0.55: fall = pow(age / 0.55, 2.0)
		elif age < 0.95: fall = 1.0 - 0.04 * sin((age - 0.55) * 24.0) * (0.95 - age)
		elif age < 1.7: fall = 1.0 - smoothstep(0.95, 1.7, age) + 0.02 * sin(age * 90.0)
		else: fall = -0.05 * sin((age - 1.7) * 18.0) * (TOPPLE_SECONDS - age)
	rewind_flat.rotation.x = fall * PI * 0.5
	# The doors swing open while the carpet is walked.
	var open := 0.0 if still else smoothstep(0.0, 0.15, _carpet) * 1.4
	for index in doors.size():
		doors[index].rotation.y = open if index == 0 else -open
	# Flash bulbs: a quick bright pop, then nothing.
	for index in _flash_spots.size():
		var left: float = _flash_left[index]
		var size := 0.0
		if not still and left > 0.0:
			size = (0.55 + left * 2.4) if index < scenery.flash_spots.size() else 0.5
		_flashes.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * size), _flash_spots[index]))
