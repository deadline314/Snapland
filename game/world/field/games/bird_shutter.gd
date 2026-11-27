extends "res://game/world/field/field_game.gd"
## Flocks of gulls cross a viewfinder hanging in the air. There are three
## frames of film: press interact when the most birds are inside. Flocks get
## faster, and some are strung out too far to fit, so waiting is a gamble.

const POOL := 8
const FILM := 3
const SLOW_FLIGHT := 2.3
const FAST_FLIGHT := 4.4
const RUN_UP := 3.2
const RELOAD_SECONDS := 0.7
const LAST_LOOK_SECONDS := 0.9
const FLASH_SECONDS := 0.12
const FLOCK_SIZES := [3, 5, 2, 6, 4, 7, 3, 6]
const BIRD_SIZE := 1.4
const BIRD_HALF_HEIGHT := 0.28

var film := FILM
var shots: Array[int] = []
## Bird positions relative to the middle of the frame (x along the flight).
var bird_x := PackedFloat32Array()
var bird_y := PackedFloat32Array()
var flock := 0

var _frame_at := Vector3.ZERO
var _half := Vector2.ONE
var _birds: Kit.SpriteBatch
var _frame: MultiMeshInstance3D
var _flash: MeshInstance3D
var _direction := 1.0
var _lead := 0.0
var _gap := PackedFloat32Array()
var _wave := 0
var _bag: Array[int] = []
var _reload := 0.0
var _closing := -1.0
var _flash_time := 0.0
var _wing := 0.0
var _active := false


func build() -> void:
	var size: Vector2 = spec.frame_size
	_half = size * 0.5
	_frame_at = centre() + (spec.frame as Vector3)
	# Corner brackets and thin edges: a viewfinder, not a solid window.
	var bar := BoxMesh.new()
	bar.size = Vector3.ONE
	var bars: Array[Transform3D] = []
	for corner_x: float in [-1.0, 1.0]:
		for corner_y: float in [-1.0, 1.0]:
			var corner := Vector3(corner_x * _half.x, corner_y * _half.y, 0)
			bars.append(Transform3D(Basis.from_scale(Vector3(0.8, 0.1, 0.06)), corner - Vector3(corner_x * 0.4, 0, 0)))
			bars.append(Transform3D(Basis.from_scale(Vector3(0.1, 0.8, 0.06)), corner - Vector3(0, corner_y * 0.4, 0)))
	for side: float in [-1.0, 1.0]:
		bars.append(Transform3D(Basis.from_scale(Vector3(size.x, 0.035, 0.03)), Vector3(0, side * _half.y, 0)))
		bars.append(Transform3D(Basis.from_scale(Vector3(0.035, size.y, 0.03)), Vector3(side * _half.x, 0, 0)))
	_frame = Kit.batch(self, bar, bars, world._mat(Color("#fff6de"), true))
	_frame.position = _frame_at
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sheet := QuadMesh.new()
	sheet.size = size
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.albedo_color = Color(1, 1, 1, 0.55)
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flash = Kit.mesh(self, sheet, _frame_at, light, false)
	_birds = Kit.SpriteBatch.new(world, POOL, 40.0)
	add_child(_birds)
	for index in range(POOL):
		_birds.tint(index, Color(1.5, 1.5, 1.46))
	bird_x.resize(POOL)
	bird_y.resize(POOL)
	_gap.resize(POOL)
	_build_tripod()


## A box camera on a tripod beside the stand: legs, body, lens.
func _build_tripod() -> void:
	var layout: Array = spec.get("layout", [])
	if layout.is_empty():
		return
	var foot := spot(layout[0])
	var leg := CylinderMesh.new()
	leg.top_radius = 0.025
	leg.bottom_radius = 0.035
	leg.height = 1.25
	leg.radial_segments = 6
	leg.rings = 1
	var legs: Array[Transform3D] = []
	for index in range(3):
		var angle := TAU * index / 3.0 + 0.5
		var lean := Basis(Vector3(sin(angle), 0, -cos(angle)), 0.3)
		legs.append(Transform3D(lean, foot + Vector3(cos(angle) * 0.19, 0.6, sin(angle) * 0.19)))
	Kit.batch(self, leg, legs, world._wood_material(Color("#8a6a48")))
	var body := Kit.box(self, foot + Vector3(0, 1.36, 0), Vector3(0.44, 0.32, 0.3), world._coastal_surface(Kit.TILE_BRASS, 0.5, Color("#f1dfb4")))
	# The lens looks at the viewfinder.
	var aim := _frame_at - body.position
	body.rotation.y = atan2(aim.x, aim.z)
	var lens := Kit.cylinder(body, Vector3(0, 0, 0.2), 0.1, 0.14, world._mat(Color("#2f4a52")), 0.085, 10)
	lens.rotation.x = PI * 0.5


func reset() -> void:
	_active = false
	_frame.visible = false
	_flash.visible = false
	for index in range(POOL):
		_birds.hide_item(index)


func ready_up() -> void:
	_frame.visible = true


func begin() -> void:
	film = FILM
	shots.clear()
	_reload = 0.0
	_closing = -1.0
	_flash_time = 0.0
	_wave = 0
	_bag.assign(FLOCK_SIZES)
	for index in range(_bag.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := _bag[index]
		_bag[index] = _bag[other]
		_bag[other] = held
	_direction = 1.0 if rng.randf() < 0.5 else -1.0
	_active = true
	_frame.visible = true
	_launch()


func _launch() -> void:
	flock = _bag[_wave % _bag.size()]
	_wave += 1
	_direction = -_direction
	_lead = -(_half.x + RUN_UP)
	var behind := 0.0
	# Some flocks fly wing to wing, others trail out longer than the frame.
	var loose := rng.randf_range(0.42, 1.05)
	for index in range(POOL):
		_gap[index] = behind
		behind += loose * rng.randf_range(0.75, 1.25)
		bird_y[index] = rng.randf_range(-0.8, 0.8) * _half.y
	_place()


func _place() -> void:
	for index in range(POOL):
		bird_x[index] = (_lead - _gap[index]) * _direction if index < flock else INF


func action_label() -> String:
	return "按快門" if film > 0 else ""


func birds_in_frame() -> int:
	var count := 0
	for index in range(flock):
		if absf(bird_x[index]) < _half.x and absf(bird_y[index]) < _half.y:
			count += 1
	return count


func press() -> void:
	if film <= 0 or _reload > 0.0:
		return
	film -= 1
	_reload = RELOAD_SECONDS
	var caught := birds_in_frame()
	shots.append(caught)
	add_score(caught)
	feedback("shutter")
	world.play_action("photograph")
	_flash_time = FLASH_SECONDS
	if caught == 0:
		field.say("只拍到尾巴…", 1.2)
	elif caught >= 5:
		field.say("大合照！%d 隻" % caught, 1.2)
	else:
		field.say("喀嚓！%d 隻" % caught, 1.2)
	if film == 0:
		_closing = LAST_LOOK_SECONDS


func step(delta: float, _player: Vector3) -> void:
	_wing += delta
	_reload = maxf(0.0, _reload - delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	if _closing >= 0.0:
		_closing -= delta
		if _closing < 0.0:
			finish()
	_lead += lerpf(SLOW_FLIGHT, FAST_FLIGHT, pace()) * delta
	if _lead - _gap[flock - 1] > _half.x + RUN_UP:
		_launch()
	_place()
	_draw()


func conclude(_medal: int) -> void:
	_active = false
	_flash_time = 0.0
	_draw()


func _draw() -> void:
	_flash.visible = _flash_time > 0.0 and not reduced()
	for index in range(POOL):
		if not _active or index >= flock:
			_birds.hide_item(index)
			continue
		var flap := 0 if reduced() else (1 if fmod(_wing * 3.4 + index * 0.21, 1.0) < 0.5 else 2)
		_birds.put(index, _frame_at + Vector3(bird_x[index], bird_y[index] - BIRD_HALF_HEIGHT, 0), "gull", flap, _direction < 0.0, BIRD_SIZE)
