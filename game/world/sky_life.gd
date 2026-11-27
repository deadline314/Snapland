extends RefCounted
## Everything in the Cloud Park that moves: the ferris wheel turning slowly
## with its cabins hanging level (a push spins it faster and sets them
## swinging), kites riding the wind on their strings above the terrace, the
## tethered hot-air balloon bobbing over the islands, clouds drifting past at
## and below walkway height, the puff of cloud that catches a step off a deck
## and the photo point's flash. Built once; nothing here is saved, and the
## reduced-motion pose is one still frame.

const Scenery := preload("res://game/world/sky_scenery.gd")
const Kit := preload("res://game/world/scenery_kit.gd")
const GLOW_PAINT := preload("res://game/world/sky_glow_paint.gdshader")
const CABINS := 12
const CABIN_TINTS := [Color("#ff8a6b"), Color("#ffd35c"), Color("#8fe0c4"), Color("#7cc4ec"), Color("#b9a9f0"), Color("#ffb3c7")]
## One turn of the wheel takes this long; a push makes it several times faster.
const TURN_SECONDS := 80.0
## Kites: how far downwind of its reel and how high each one flies.
const KITES := [[5.4, 5.6], [6.6, 6.8], [5.0, 4.8], [6.0, 6.2]]
const KITE_TINTS := [Color("#ff8a6b"), Color("#ffd35c"), Color("#7cc4ec"), Color("#8fe0c4")]
const DRIFT_CLOUDS := 14
## Drifting clouds travel this far downwind before they start again.
const DRIFT_SPAN := 58.0
const CATCH_SECONDS := 0.7
const FLASH_SECONDS := 0.3

var world: Node3D
var scenery: Scenery
var glow_paint: ShaderMaterial
var wheel: MeshInstance3D
var balloon: MeshInstance3D
var catch_puff: MeshInstance3D
var flash_bulb: MeshInstance3D
var _cabins: MultiMesh
var _kites: MultiMesh
var _strings: MultiMesh
var _ropes: MultiMesh
var _clouds: MultiMesh
var _cloud_specs: Array[Dictionary] = []
## Where each cabin, kite and cloud is now (multimesh data stays on the GPU).
var _cabin_spots: Array[Vector3] = []
var _kite_spots: Array[Vector3] = []
var _cloud_spots: Array[Vector3] = []
var _angle := 0.0
var _push := 0.0
var _climb := 0.0
var _tug := 0.0
var _catch := 0.0
var _flash := 0.0
var _posed_still := false

func _init(owner: Node3D, sky_scenery: Scenery) -> void:
	world = owner
	scenery = sky_scenery

func build() -> void:
	glow_paint = world.material_cache.get("sky:glow-paint")
	if glow_paint == null:
		glow_paint = ShaderMaterial.new()
		glow_paint.shader = GLOW_PAINT
		world.material_cache["sky:glow-paint"] = glow_paint
	var hub: Vector3 = world.WHEEL + Vector3(0, Scenery.HUB_HEIGHT, 0)
	wheel = world._mesh(_wheel_mesh(), hub, glow_paint)
	wheel.name = "SkyWheel"
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	for index in CABINS:
		transforms.append(Transform3D(Basis.IDENTITY, hub))
		tints.append((CABIN_TINTS[index % CABIN_TINTS.size()] as Color).srgb_to_linear())
	var cabins: MultiMeshInstance3D = world._multi_mesh(_cabin_mesh(), Vector3.ZERO, transforms, tints, glow_paint)
	cabins.name = "SkyWheelCabins"
	_cabins = cabins.multimesh
	_cabins.custom_aabb = AABB(hub - Vector3(6.5, 7.0, 1.5), Vector3(13.0, 13.0, 3.0))
	scenery.kit.lamp_light(hub + Vector3(0, -3.2, 2.4), 9.0, Color("#ffe0a8"))
	var paint: Material = world._vertex_color_material("scenery-detail")
	transforms.clear()
	tints.clear()
	for index in KITES.size():
		transforms.append(Transform3D.IDENTITY)
		tints.append((KITE_TINTS[index] as Color).srgb_to_linear())
	var kites: MultiMeshInstance3D = world._multi_mesh(_kite_mesh(), Vector3.ZERO, transforms, tints, paint)
	kites.name = "SkyKites"
	kites.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kites = kites.multimesh
	_kites.custom_aabb = AABB(Vector3(-22, 0, 4), Vector3(36, 16, 26))
	var line := _line_mesh()
	var line_tints: Array[Color] = []
	for index in KITES.size(): line_tints.append(Color("#f2f2f2"))
	var strings: MultiMeshInstance3D = world._multi_mesh(line, Vector3.ZERO, transforms, line_tints, paint)
	strings.name = "SkyKiteStrings"
	strings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strings = strings.multimesh
	_strings.custom_aabb = _kites.custom_aabb
	balloon = world._mesh(_balloon_mesh(), world.BALLOON, paint)
	balloon.name = "SkyBalloon"
	var rope_places: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var rope_tints: Array[Color] = [Color("#d9c59a").srgb_to_linear(), Color("#d9c59a").srgb_to_linear()]
	var ropes: MultiMeshInstance3D = world._multi_mesh(line, Vector3.ZERO, rope_places, rope_tints, paint)
	ropes.name = "SkyBalloonRopes"
	_ropes = ropes.multimesh
	_ropes.custom_aabb = AABB(world.BALLOON - Vector3(3, 0, 3), Vector3(6, 9, 6))
	_build_clouds()
	_cabin_spots.resize(CABINS)
	_kite_spots.resize(KITES.size())
	_cloud_spots.resize(DRIFT_CLOUDS)
	var puff := Kit.Sculpt.new()
	Scenery.cloud(puff, Vector3.ZERO, 0.45, 0.4)
	catch_puff = world._mesh(puff.mesh(), Vector3.ZERO, Scenery.puff_material(world))
	catch_puff.name = "SkyCatchPuff"
	catch_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	catch_puff.visible = false
	var bulb := SphereMesh.new()
	bulb.radius = 0.16
	bulb.height = 0.32
	bulb.radial_segments = 8
	bulb.rings = 4
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.98, 0.9)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.95, 0.85)
	flash_material.emission_energy_multiplier = 4.0
	world.material_cache["sky:flash"] = flash_material
	flash_bulb = world._mesh(bulb, Vector3(8.0, world.pad("photo").y + 1.68, 8.75), flash_material)
	flash_bulb.name = "SkyCameraFlash"
	flash_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_bulb.visible = false

func _build_clouds() -> void:
	var bounds: Rect2 = world.BOUNDS
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var across := Vector2(-Scenery.WIND.y, Scenery.WIND.x)
	for index in DRIFT_CLOUDS:
		var lane := (fposmod(float(index) * 0.618, 1.0) - 0.5) * 2.0
		# Most drift low over the cloud sea; a few pass at the walkways' height.
		var high := index % 3 == 0
		var spec := {
			"lane": bounds.get_center() + across * lane * 21.0,
			"offset": fposmod(float(index) * 0.377, 1.0) * DRIFT_SPAN,
			"speed": 0.35 + fposmod(float(index) * 0.29, 1.0) * 0.3,
			"height": (1.9 + fposmod(float(index) * 0.53, 1.0) * 1.4) if high else (0.35 + fposmod(float(index) * 0.71, 1.0) * 0.7),
			"size": (0.7 + fposmod(float(index) * 0.43, 1.0) * 0.4) if high else (1.0 + fposmod(float(index) * 0.83, 1.0) * 0.8),
			"yaw": fposmod(float(index) * 0.91, 1.0) * TAU,
		}
		_cloud_specs.append(spec)
		transforms.append(Transform3D.IDENTITY)
		tints.append(Color.WHITE)
	var shape := Kit.Sculpt.new()
	Scenery.cloud(shape, Vector3.ZERO, 1.0, 0.7)
	var drift: MultiMeshInstance3D = world._multi_mesh(shape.mesh(), Vector3.ZERO, transforms, tints, Scenery.puff_material(world))
	drift.name = "SkyDriftClouds"
	drift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds = drift.multimesh
	_clouds.custom_aabb = AABB(Vector3(bounds.position.x - 12, 0, bounds.position.y - 12), Vector3(bounds.size.x + 24, 6, bounds.size.y + 24))

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if _posed_still: return
	_push = 0.0
	_climb = 0.0
	_tug = 0.0
	_catch = 0.0
	_flash = 0.0
	catch_puff.visible = false
	flash_bulb.visible = false
	_pose(0.0, true)
	_posed_still = true

func animate(delta: float) -> void:
	_posed_still = false
	_push = move_toward(_push, 0.0, delta / 6.0)
	_climb = move_toward(_climb, 0.0, delta / 9.0)
	_tug = move_toward(_tug, 0.0, delta / 2.4)
	_angle = fposmod(_angle + delta * TAU / TURN_SECONDS * (1.0 + _push * 5.0), TAU)
	if _catch > 0.0:
		_catch = maxf(_catch - delta / CATCH_SECONDS, 0.0)
		var age := 1.0 - _catch
		catch_puff.scale = Vector3.ONE * (0.4 + sin(age * PI) * 0.9)
		catch_puff.visible = _catch > 0.0
	if _flash > 0.0:
		_flash = maxf(_flash - delta / FLASH_SECONDS, 0.0)
		flash_bulb.scale = Vector3.ONE * (0.5 + _flash * 1.6)
		flash_bulb.visible = _flash > 0.0
	_pose(world.time, false)

func push_wheel() -> void:
	_push = 1.0

func fly_kites() -> void:
	_climb = 1.0

func tug_balloon() -> void:
	_tug = 1.0

func flash() -> void:
	_flash = 1.0
	flash_bulb.visible = not world.reduced_motion

## A step over a deck's edge: a puff of cloud bursts where the foot was caught.
func catch_step(at: Vector3) -> void:
	if _catch > 0.3 or world.reduced_motion: return
	_catch = 1.0
	catch_puff.position = Vector3(at.x, world.ground_surface_y(at) - 0.05, at.z)
	catch_puff.scale = Vector3.ONE * 0.4
	catch_puff.visible = true

func apply_time_of_day(lamp_level: float) -> void:
	glow_paint.set_shader_parameter("glow", lamp_level * 3.2)

func wheel_angle() -> float:
	return _angle

func kite_position(index: int) -> Vector3:
	return _kite_spots[index]

func cloud_position(index: int) -> Vector3:
	return _cloud_spots[index]

func balloon_position() -> Vector3:
	return balloon.position

func cabin_position(index: int) -> Vector3:
	return _cabin_spots[index]

func catching() -> bool:
	return catch_puff.visible

func _pose(time: float, still: bool) -> void:
	var hub: Vector3 = world.WHEEL + Vector3(0, Scenery.HUB_HEIGHT, 0)
	wheel.rotation = Vector3(0, 0, _angle)
	for index in CABINS:
		var around := _angle + TAU * float(index) / float(CABINS)
		var pivot := hub + Vector3(cos(around), sin(around), 0) * Scenery.WHEEL_RADIUS
		var swing := 0.0 if still else sin(time * 1.6 + float(index) * 0.9) * (0.03 + 0.22 * _push)
		_cabins.set_instance_transform(index, Transform3D(Basis(Vector3.BACK, swing), pivot))
		_cabin_spots[index] = pivot
	var wind := Vector3(Scenery.WIND.x, 0, Scenery.WIND.y)
	var side := Vector3(-Scenery.WIND.y, 0, Scenery.WIND.x)
	for index in KITES.size():
		var reel: Vector3 = scenery.kite_reels[index] if index < scenery.kite_reels.size() else Vector3.ZERO
		var spec: Array = KITES[index]
		var sway := 0.0 if still else sin(time * (0.5 + 0.13 * float(index)) + float(index) * 1.7)
		var bob := 0.0 if still else sin(time * 0.9 + float(index) * 2.3) * 0.35
		var reach := float(spec[0]) * (1.0 + 0.25 * _climb)
		var kite := reel + wind * reach + side * sway * 1.1 + Vector3(0, float(spec[1]) * (1.0 + 0.35 * _climb) + bob, 0)
		var roll := sway * 0.35
		var basis := Basis(Vector3.UP, 0.14) * Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.BACK, roll)
		_kites.set_instance_transform(index, Transform3D(basis, kite))
		_kite_spots[index] = kite
		_strings.set_instance_transform(index, _span(reel, kite))
	var stake: Vector3 = world.BALLOON
	var lift := 0.0 if still else sin(time * 0.6) * 0.25 - sin(_tug * PI) * 0.9
	var drift := Vector3(0.7, 0, 0.4) + (Vector3.ZERO if still else wind * sin(time * 0.35) * 0.3)
	balloon.position = stake + drift + Vector3(0, lift, 0)
	balloon.rotation = Vector3(0, 0.0 if still else sin(time * 0.25) * 0.2, 0.0 if still else sin(time * 0.5) * 0.04)
	var basket := balloon.position + Vector3(0, 2.6, 0)
	_ropes.set_instance_transform(0, _span(stake + Vector3(-0.08, 0.9, 0), basket + Vector3(-0.25, 0, 0)))
	_ropes.set_instance_transform(1, _span(stake + Vector3(0.08, 0.9, 0), basket + Vector3(0.25, 0, 0.1)))
	var walker: Vector3 = world.player_spot() if is_instance_valid(world.player) else Vector3.INF
	for index in _cloud_specs.size():
		var spec: Dictionary = _cloud_specs[index]
		var travelled := fposmod(float(spec.offset) + (0.0 if still else time * float(spec.speed)), DRIFT_SPAN)
		var along := travelled - DRIFT_SPAN * 0.5
		var lane: Vector2 = spec.lane
		var at := Vector3(lane.x, float(spec.height), lane.y) + wind * along
		# Clouds swell in at the start of their run and thin away at its end.
		var fade := smoothstep(0.0, 6.0, travelled) * (1.0 - smoothstep(DRIFT_SPAN - 6.0, DRIFT_SPAN, travelled))
		# A cloud at the walker's height thins out as it passes, so it never hides them.
		if walker.is_finite() and at.y > walker.y - 0.4:
			fade *= smoothstep(1.6, 4.0, Vector2(at.x - walker.x, at.z - walker.z).length())
		var size := float(spec.size) * maxf(fade, 0.001)
		_clouds.set_instance_transform(index, Transform3D(Basis(Vector3.UP, float(spec.yaw)).scaled(Vector3.ONE * size), at))
		_cloud_spots[index] = at

## A thin line from `from` to `to`, as a transform of the unit line mesh.
static func _span(from: Vector3, to: Vector3) -> Transform3D:
	var span := to - from
	var length := maxf(span.length(), 0.001)
	return Transform3D(Basis.looking_at(span / length, Vector3.UP if absf(span.y / length) < 0.99 else Vector3.BACK) * Basis.from_scale(Vector3(1, 1, length)), (from + to) * 0.5)

# --- Meshes ----------------------------------------------------------------------

## Two white rims with spokes, ties for the cabins and a ring of bulbs, turning
## round its own origin (the hub) in the XY plane, facing the camera.
func _wheel_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	const SEGMENTS := 36
	var radius: float = Scenery.WHEEL_RADIUS
	for depth: float in [-0.36, 0.36]:
		for index in SEGMENTS:
			var a0 := TAU * float(index) / float(SEGMENTS)
			var a1 := TAU * float(index + 1) / float(SEGMENTS)
			var from := Vector3(cos(a0), sin(a0), 0) * radius
			var to := Vector3(cos(a1), sin(a1), 0) * radius
			var middle := (from + to) * 0.5 + Vector3(0, 0, depth)
			s.box(middle, Vector3(from.distance_to(to) + 0.04, 0.16, 0.12), Color.WHITE if index % 2 else Color("#e8f4fb"), Basis(Vector3.BACK, (a0 + a1) * 0.5 + PI * 0.5))
			# The inner ring, in sun yellow.
			s.box(middle * 0.42 + Vector3(0, 0, depth * 0.58), Vector3(from.distance_to(to) * 0.42 + 0.03, 0.1, 0.08), Color("#ffd35c"), Basis(Vector3.BACK, (a0 + a1) * 0.5 + PI * 0.5))
		for spoke in CABINS:
			var angle := TAU * float(spoke) / float(CABINS) + PI / float(CABINS)
			var tip := Vector3(cos(angle), sin(angle), 0) * radius
			s.box(tip * 0.5 + Vector3(0, 0, depth), Vector3(0.07, radius, 0.07), Color("#cfe3f2"), Basis(Vector3.BACK, angle - PI * 0.5))
	for tie in CABINS:
		var angle := TAU * float(tie) / float(CABINS)
		var at := Vector3(cos(angle), sin(angle), 0) * radius
		s.tube(at, 0.06, 0.06, 0.82, Color("#3d6fb0"), 6, Basis(Vector3.RIGHT, PI * 0.5))
	# Bulbs on the front rim (alpha marks them to glow after dark).
	var bulbs := [Color(1.0, 0.83, 0.36, 0.5), Color(1.0, 0.54, 0.42, 0.5), Color(0.56, 0.88, 0.77, 0.5), Color(0.49, 0.77, 0.93, 0.5)]
	for index in SEGMENTS:
		var angle := TAU * (float(index) + 0.5) / float(SEGMENTS)
		s.ball(Vector3(cos(angle), sin(angle), 0) * radius + Vector3(0, 0, 0.46), 0.07, bulbs[index % bulbs.size()], Color.TRANSPARENT, 6, 3)
	for index in CABINS:
		var angle := TAU * float(index) / float(CABINS) + PI / float(CABINS)
		s.ball(Vector3(cos(angle), sin(angle), 0) * radius * 0.42 + Vector3(0, 0, 0.3), 0.06, bulbs[(index + 1) % bulbs.size()], Color.TRANSPARENT, 6, 3)
	# The hub: a sun medallion.
	s.tube(Vector3(0, 0, 0.44), 0.7, 0.7, 0.1, Color("#ffd35c"), 16, Basis(Vector3.RIGHT, PI * 0.5))
	s.tube(Vector3(0, 0, 0.5), 0.46, 0.46, 0.04, Color(1.0, 0.95, 0.8, 0.5), 16, Basis(Vector3.RIGHT, PI * 0.5))
	for ray in 12:
		var angle := TAU * float(ray) / 12.0
		s.box(Vector3(cos(angle), sin(angle), 0) * 0.86 + Vector3(0, 0, 0.44), Vector3(0.26, 0.1, 0.06), Color("#ff8a6b"), Basis(Vector3.BACK, angle))
	return s.mesh()

## A cabin hanging below its pivot: a rounded body in pale paint (each copy
## takes its own colour), a window band that glows at night, a striped roof.
func _cabin_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	s.box(Vector3(0, -0.28, 0), Vector3(0.06, 0.56, 0.06), Color("#3d6fb0"))
	s.ball(Vector3(0, -0.62, 0), 0.4, Color.WHITE, Color("#f0f0f0"), 10, 3, 0.55, true)
	s.tube(Vector3(0, -0.98, 0), 0.5, 0.5, 0.62, Color("#f4f4f4"), 10)
	s.tube(Vector3(0, -0.94, 0), 0.52, 0.52, 0.3, Color(1.0, 0.96, 0.82, 0.5), 10)
	for post in 5:
		var angle := TAU * float(post) / 5.0 + 0.3
		s.box(Vector3(cos(angle) * 0.5, -0.94, sin(angle) * 0.5), Vector3(0.06, 0.32, 0.06), Color("#d8d8d8"))
	s.tube(Vector3(0, -1.32, 0), 0.5, 0.36, 0.1, Color("#d0d0d0"), 10)
	return s.mesh()

## A diamond kite with cross spars and a tail of little bows, in pale paint.
func _kite_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	var top := Vector3(0, 0.62, 0)
	var bottom := Vector3(0, -0.86, 0)
	var left := Vector3(-0.52, 0.12, 0)
	var right := Vector3(0.52, 0.12, 0)
	var middle := Vector3(0, 0.12, 0.02)
	s.sheet(top, middle, left, Color.WHITE)
	s.sheet(top, right, middle, Color("#e4e4e4"))
	s.sheet(middle, bottom, left, Color("#e4e4e4"))
	s.sheet(middle, right, bottom, Color.WHITE)
	s.box(Vector3(0, -0.12, 0.03), Vector3(0.03, 1.48, 0.03), Color("#6e4c32"))
	s.box(Vector3(0, 0.12, 0.03), Vector3(1.04, 0.03, 0.03), Color("#6e4c32"))
	var tail := bottom
	for bow in 5:
		var next := tail + Vector3(0.12 * sin(float(bow) * 1.4), -0.32, 0.03)
		s.box((tail + next) * 0.5, Vector3(0.02, 0.33, 0.02), Color("#f2f2f2"))
		for wing: float in [-1.0, 1.0]:
			s.sheet(next, next + Vector3(wing * 0.16, 0.07, 0), next + Vector3(wing * 0.16, -0.07, 0), Color("#ffd35c") if bow % 2 == 0 else Color("#ff8a6b"))
		tail = next
	return s.mesh()

## A unit line along -Z for strings and ropes (scaled to length when placed).
func _line_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	s.box(Vector3.ZERO, Vector3(0.025, 0.025, 1.0), Color.WHITE)
	return s.mesh()

## A striped hot-air balloon above its basket; its origin is at the tether stake.
func _balloon_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	var centre := Vector3(0, 4.6, 0)
	s.ball(centre, 1.55, Color("#ff8a6b"), Color("#fff4de"), 12, 7, 1.12)
	s.ball(centre + Vector3(0, 0.55, 0), 1.2, Color("#ffd35c"), Color("#7cc4ec"), 12, 3, 1.12, true)
	s.tube(centre - Vector3(0, 1.62, 0), 0.62, 0.32, 0.4, Color("#ff8a6b").darkened(0.2), 12)
	for rope in 4:
		var angle := TAU * float(rope) / 4.0 + PI * 0.25
		var from := centre + Vector3(cos(angle) * 0.6, -1.7, sin(angle) * 0.6)
		var to := Vector3(cos(angle) * 0.36, 2.95, sin(angle) * 0.36)
		s.box((from + to) * 0.5, Vector3(0.025, from.distance_to(to), 0.025), Color("#6e4c32"))
	s.box(Vector3(0, 2.75, 0), Vector3(0.78, 0.5, 0.78), Color("#a87a4f"))
	s.box(Vector3(0, 3.0, 0), Vector3(0.84, 0.08, 0.84), Color("#6e4c32"))
	for band in 2:
		s.box(Vector3(0, 2.62 + float(band) * 0.22, 0), Vector3(0.8, 0.04, 0.8), Color("#c99d6a"))
	return s.mesh()
