extends "res://game/world/field/field_game.gd"
## A spotlight wanders around a sawdust ring and the crowd only cheers for
## whoever stands in it. Every half second in the light is a point. It drifts
## faster and shrinks as the show goes on, and now and then it darts off.
## Stay out of it too long and the crowd starts to boo.

const STAGE_RADIUS := 3.1
const PATH_RADIUS := 2.2
const WIDE := 1.05
const NARROW := 0.72
const SLOW_DRIFT := 0.55
const FAST_DRIFT := 1.0
const DART_SECONDS := 0.5
const DART_SPEED := 1.9
const POINT_SECONDS := 0.5
const BOO_AFTER := 1.6

var light := Vector2.ZERO
var lit_time := 0.0
var dark_time := 0.0
var boos := 0

var _middle := Vector3.ZERO
var _phase := Vector2.ZERO
var _turn := 0.0
var _dart := 0.0
var _dart_in := 0.0
var _dart_to := Vector2.ZERO
var _pool: MeshInstance3D
var _beam: MeshInstance3D
var _cheer: Label3D
var _show := 0.0
var _flop := false


func build() -> void:
	_middle = centre()
	var ring := Kit.cylinder(self, _middle + Vector3(0, 0.025, 0), STAGE_RADIUS + 0.3, 0.05, Kit.sand_material(world), -1.0, 30)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var kerb := BoxMesh.new()
	kerb.size = Vector3(0.7, 0.22, 0.2)
	var kerbs: Array[Transform3D] = []
	for index in range(30):
		var angle := TAU * index / 30.0
		kerbs.append(Transform3D(Basis.from_euler(Vector3(0, -angle + PI * 0.5, 0)), _middle + Vector3(cos(angle), 0, sin(angle)) * (STAGE_RADIUS + 0.4) + Vector3(0, 0.11, 0)))
	Kit.batch(self, kerb, kerbs, world._vertex_color_material("field-ring-kerb"), [Color("#d9454e"), Color("#fff3ec")])
	# The lamp on its tall mast, pointing down into the ring.
	var mast: Array[Vector3] = [_middle + Vector3(-STAGE_RADIUS - 0.9, 0, -1.4)]
	Kit.posts(world, self, mast, 3.6, Color("#f2c75a"), 0.1)
	Kit.cylinder(self, mast[0] + Vector3(0.25, 3.75, 0), 0.22, 0.4, world._coastal_surface(Kit.TILE_BRASS, 0.4), 0.14, 10).rotation.z = 0.9
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	_pool = Kit.mesh(self, disc, Vector3.ZERO, Kit.clear_material(world, Color(1.0, 0.93, 0.6, 0.5), 1.1), false)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 16
	cone.rings = 1
	_beam = Kit.mesh(self, cone, Vector3.ZERO, Kit.clear_material(world, Color(1.0, 0.95, 0.7, 0.12), 0.6), false)
	_cheer = Kit.label(self, "", _middle + Vector3(0, 3.4, -STAGE_RADIUS), 48, Color("#f2c75a"))


func reset() -> void:
	light = Vector2.ZERO
	_flop = false
	_pool.visible = false
	_beam.visible = false
	_cheer.text = ""


func begin() -> void:
	lit_time = 0.0
	dark_time = 0.0
	boos = 0
	_phase = Vector2(rng.randf() * TAU, rng.randf() * TAU)
	_turn = 0.0
	_dart = 0.0
	_dart_in = 5.0
	light = Vector2.ZERO
	_pool.visible = true
	_beam.visible = true


func radius() -> float:
	return lerpf(WIDE, NARROW, pace())


## The centre of the light on the ground.
func light_at() -> Vector3:
	return Vector3(_middle.x + light.x, _middle.y, _middle.z + light.y)


func step(delta: float, player: Vector3) -> void:
	_move(delta)
	var inside := flat_distance(player, light_at()) < radius()
	if inside:
		var before := int(lit_time / POINT_SECONDS)
		lit_time += delta
		dark_time = 0.0
		if int(lit_time / POINT_SECONDS) > before:
			add_score(1)
			if score % 10 == 0:
				note(score / 10)
	else:
		dark_time += delta
		if dark_time >= BOO_AFTER and dark_time - delta < BOO_AFTER:
			boos += 1
			feedback("miss")
			field.say("噓～", 0.8)
	_draw(inside)


func _move(delta: float) -> void:
	_dart_in -= delta
	if _dart > 0.0:
		_dart -= delta
		light = light.move_toward(_dart_to, DART_SPEED * delta)
		return
	if _dart_in <= 0.0 and pace() > 0.2:
		# A sudden dash across the ring.
		_dart = DART_SECONDS
		_dart_in = lerpf(4.5, 2.6, pace())
		_dart_to = -light.normalized() * PATH_RADIUS * 0.7 if light.length() > 0.3 else Vector2(PATH_RADIUS * 0.7, 0)
		return
	_turn += delta * lerpf(SLOW_DRIFT, FAST_DRIFT, pace()) / PATH_RADIUS
	var wanted := Vector2(cos(_turn + _phase.x) * PATH_RADIUS, sin(_turn * 1.7 + _phase.y) * PATH_RADIUS * 0.75)
	light = light.move_toward(wanted, lerpf(SLOW_DRIFT, FAST_DRIFT, pace()) * 1.3 * delta)


func conclude(medal: int) -> void:
	_flop = medal == 0
	_show = 0.0
	_cheer.text = "全場打瞌睡…" if _flop else "安可！"


func show_step(delta: float, _player: Vector3) -> void:
	_show += delta
	if _flop and not reduced():
		# The light gives up on you and wanders off to the empty seats.
		light = light.move_toward(Vector2(0, -PATH_RADIUS - 2.0), 1.2 * delta)
	_draw(false)


func _draw(inside: bool) -> void:
	var at := light_at()
	var size := radius()
	_pool.position = at + Vector3(0, 0.06, 0)
	_pool.scale = Vector3(size, 1.0, size)
	var flicker := 1.0 if reduced() or not _flop else 0.7 + 0.3 * absf(sin(_show * 17.0))
	_pool.scale *= Vector3(flicker, 1.0, flicker)
	var height := 4.2
	_beam.position = at + Vector3(0, height * 0.5, 0)
	_beam.scale = Vector3(size, height, size)
	if not _flop and _show <= 0.0:
		Kit.write(_cheer, "哇～！" if inside and score > 0 else "", Color("#f2c75a"))
