extends Node3D
## Afternoon shower (an IslandEvents event). The sky greys over and rain falls
## around the camera; a handful of puddles open on the ground near the walker
## and splash when walked through (three splashes is the goal). Residents
## nearby open umbrellas. When the rain stops a rainbow rises behind the
## walker's view and can be photographed; with the goal met the photo becomes
## the souvenir sticker. Everything here is freed when the shower ends.

const WorldAmbience = preload("res://game/world/world_ambience.gd")
const PUDDLE_SHADER := "res://game/world/puddle.gdshader"
const RAINBOW_SHADER := "res://game/world/rainbow.gdshader"

enum Stage { RAIN, CLEARING, RAINBOW, FADING, DONE }

const RAIN_SECONDS := 58.0
const CLEAR_SECONDS := 4.0
const RAINBOW_SECONDS := 34.0
const FADE_SECONDS := 3.0
const GATHER_SECONDS := 4.0
const SPLASH_GOAL := 3
const PUDDLES := 6
const PUDDLE_SIZE := Vector2(2.4, 1.7)
const PUDDLE_REACH := 0.95
const PUDDLE_LIFT := 0.035
const PUDDLE_SPACING := 2.4
## A puddle farther than this from the walker reopens closer by, ahead of them.
const PUDDLE_LEASH := 11.0
const UMBRELLAS := 4
const UMBRELLA_REACH := 40.0
const RAIN_AMOUNT := 90
const RAIN_SAVER := 36
const DROPLETS := 10
const RAINBOW_WIDTH := 26.0
const AIR := {"sky": Color("#8394a6"), "ambient": Color("#b4c3d4"), "ambient_scale": 0.82, "sun_scale": 0.32, "saturation_scale": 0.84}
const UMBRELLA_TONES := [Color("#e8735e"), Color("#4fa7a0"), Color("#e9b44c"), Color("#8d7fd0")]

var participation := 0
var stage := Stage.RAIN
var photographed := false
var puddles: Array[MeshInstance3D] = []
var umbrellas: Array[Dictionary] = []
var rain: CPUParticles3D
var droplets: CPUParticles3D
var rainbow: MeshInstance3D

var _director: Node3D
var _world: Node3D
var _clock := 0.0
var _stage_time := 0.0
var _cover := -1.0
var _air: Dictionary = AIR.duplicate()
var _puddle_material: ShaderMaterial
var _rainbow_material: ShaderMaterial
var _splash_age: Array[float] = []
var _inside: Array[bool] = []
var _last_player := Vector3.INF
var _heading := Vector3.FORWARD
var _reduced := false
var _leash_check := 0.0


func begin(director: Node3D, player: Vector3) -> void:
	_director = director
	_world = director.world
	_build_puddles(player)
	_build_umbrellas(player)
	_build_rainbow()
	if director.can_draw_particles():
		rain = WorldAmbience.make_emitter("rain", RAIN_AMOUNT)
		if rain != null: add_child(rain)
		droplets = WorldAmbience.make_emitter("droplet", DROPLETS)
		if droplets != null:
			droplets.one_shot = true
			droplets.explosiveness = 1.0
			droplets.preprocess = 0.0
			add_child(droplets)
	_last_player = player
	director.say("午後陣雨來了！踩踩水窪，濺出三朵水花吧。")
	director.note(1)


func step(delta: float, player: Vector3) -> bool:
	_stage_time += delta
	if not _reduced: _clock += delta
	var moved := player - _last_player if _last_player.is_finite() else Vector3.ZERO
	moved.y = 0.0
	if moved.length() > 0.02: _heading = moved.normalized()
	var speed := moved.length() / maxf(delta, 0.0001)
	_last_player = player
	match stage:
		Stage.RAIN:
			_set_cover(minf(1.0, _stage_time / GATHER_SECONDS))
			_check_splashes(player, speed)
			_leash_check -= delta
			if _leash_check <= 0.0:
				_leash_check = 1.0
				_keep_puddles_near(player)
			if _stage_time >= RAIN_SECONDS: _next(Stage.CLEARING)
		Stage.CLEARING:
			var t := _stage_time / CLEAR_SECONDS
			_set_cover(1.0 - t)
			_check_splashes(player, speed)
			if t >= 1.0:
				_next(Stage.RAINBOW)
				_director.say("雨停了，天邊出現彩虹！按 E 或 P 拍下來。" if participation >= SPLASH_GOAL else "雨停了，天邊出現彩虹！")
		Stage.RAINBOW:
			if _stage_time >= RAINBOW_SECONDS: _next(Stage.FADING)
		Stage.FADING:
			if _stage_time >= FADE_SECONDS: _next(Stage.DONE)
	_update_rain(player)
	_update_puddles(delta)
	_update_umbrellas()
	_update_rainbow(player)
	return stage != Stage.DONE


func set_look(reduced: bool, saver: bool) -> void:
	_reduced = reduced
	if rain != null:
		rain.amount = RAIN_SAVER if saver else RAIN_AMOUNT
		_update_rain(_last_player)
	if droplets != null: droplets.amount = DROPLETS / 2 if saver else DROPLETS


func resume() -> void:
	_cover = -1.0


func prompt(_player: Vector3) -> String:
	return "拍下彩虹" if stage == Stage.RAINBOW and not photographed and rainbow_strength() > 0.6 else ""


func shutter(_player: Vector3) -> void:
	photographed = true
	if participation >= SPLASH_GOAL and _director.earn("shower"):
		_director.say("拍到雨後彩虹！獲得紀念拍貼「午後陣雨」。")
	elif participation >= SPLASH_GOAL:
		_director.say("拍到雨後彩虹！")
	else:
		_director.say("拍到彩虹了！下次陣雨時踩出三朵水花，就能留下紀念拍貼。")


func close() -> void:
	_world.set_event_air({})


func rainbow_strength() -> float:
	match stage:
		Stage.RAINBOW: return minf(1.0, _stage_time / 3.0)
		Stage.FADING: return 1.0 - minf(1.0, _stage_time / FADE_SECONDS)
	return 0.0


func raining() -> bool:
	return stage == Stage.RAIN or stage == Stage.CLEARING


func _next(next_stage: Stage) -> void:
	stage = next_stage
	_stage_time = 0.0


func _set_cover(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if amount == _cover or (absf(amount - _cover) < 0.01 and amount > 0.0 and amount < 1.0): return
	_cover = amount
	_air["amount"] = amount
	_world.set_event_air(_air)


# --- puddles -------------------------------------------------------------------

func _build_puddles(player: Vector3) -> void:
	if not ResourceLoader.exists(PUDDLE_SHADER):
		push_warning("Puddle shader is missing; the shower has no puddles.")
		return
	_puddle_material = ShaderMaterial.new()
	_puddle_material.shader = load(PUDDLE_SHADER)
	var mesh := PlaneMesh.new()
	mesh.size = PUDDLE_SIZE
	var placed: Array = []
	for index in range(PUDDLES):
		var spot: Vector3 = _director.spot_near(player, 2.0, 7.5, placed, PUDDLE_SPACING)
		if not spot.is_finite(): continue
		placed.append(spot)
		var puddle := MeshInstance3D.new()
		puddle.name = "Puddle%d" % index
		puddle.mesh = mesh
		puddle.material_override = _puddle_material
		puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puddle)
		puddle.global_position = spot + Vector3(0, PUDDLE_LIFT, 0)
		puddle.rotation.y = _director.rng().randf() * TAU
		puddle.set_instance_shader_parameter("seed", _director.rng().randf())
		puddle.set_instance_shader_parameter("fill", 0.0)
		puddles.append(puddle)
		_splash_age.append(9.0)
		_inside.append(false)


func _check_splashes(player: Vector3, speed: float) -> void:
	for index in range(puddles.size()):
		var at := puddles[index].global_position
		var inside := Vector2(at.x - player.x, at.z - player.z).length() < PUDDLE_REACH
		if inside and not _inside[index] and speed > 0.3 and _splash_age[index] > 0.8:
			_splash(index)
		_inside[index] = inside


func _splash(index: int) -> void:
	_splash_age[index] = 0.0
	participation += 1
	_director.note(mini(participation + 1, 7))
	if droplets != null and not _reduced:
		droplets.global_position = puddles[index].global_position
		droplets.restart()
	if participation < SPLASH_GOAL:
		_director.say("啪沙！水花 %d / %d" % [participation, SPLASH_GOAL])
	elif participation == SPLASH_GOAL:
		_director.sfx("success")
		_director.say("濺出三朵水花！雨停後找找彩虹，拍下來當紀念。")


## Puddles left far behind reopen ahead of the walker, so a walk in the rain
## always has some to stomp through.
func _keep_puddles_near(player: Vector3) -> void:
	if stage != Stage.RAIN: return
	var others: Array = []
	for puddle in puddles: others.append(puddle.global_position)
	for index in range(puddles.size()):
		var at := puddles[index].global_position
		if Vector2(at.x - player.x, at.z - player.z).length() < PUDDLE_LEASH: continue
		var ahead := player + _heading * 5.0
		var spot: Vector3 = _director.spot_near(ahead, 0.0, 3.5, others, PUDDLE_SPACING)
		if not spot.is_finite(): continue
		puddles[index].global_position = spot + Vector3(0, PUDDLE_LIFT, 0)
		puddles[index].set_instance_shader_parameter("fill", 0.0)
		others[index] = spot
		return


func _update_puddles(delta: float) -> void:
	if _puddle_material == null: return
	_puddle_material.set_shader_parameter("clock", _clock)
	_puddle_material.set_shader_parameter("rain", _cover if raining() and not _reduced else 0.0)
	# Pools fill while it rains and dry out over the rainbow.
	var target := 1.0 if raining() else maxf(0.0, 1.0 - _stage_time / 12.0) if stage == Stage.RAINBOW else 0.0
	for index in range(puddles.size()):
		_splash_age[index] += delta
		var puddle := puddles[index]
		var fill := float(puddle.get_instance_shader_parameter("fill"))
		var next := move_toward(fill, target, delta * 0.5)
		if next != fill: puddle.set_instance_shader_parameter("fill", next)
		if _splash_age[index] < 1.2: puddle.set_instance_shader_parameter("splash_age", _splash_age[index])
		elif _splash_age[index] < 1.3: puddle.set_instance_shader_parameter("splash_age", 9.0)


# --- rain ----------------------------------------------------------------------

func _update_rain(player: Vector3) -> void:
	if rain == null: return
	var falling := raining() and not _reduced and _cover > 0.3
	if rain.emitting != falling: rain.emitting = falling
	rain.visible = raining() and not _reduced
	if player.is_finite(): rain.global_position = player + Vector3(0, 8.5, 0)


# --- residents -----------------------------------------------------------------

## Story residents near the walker open umbrellas: the island has no crowd of
## its own, so they are the ones seen sheltering from the rain.
func _build_umbrellas(player: Vector3) -> void:
	var people: Array[Dictionary] = []
	for host: Node3D in _resident_worlds():
		for record: Dictionary in host.character_sprites:
			var root := record.get("activity_root") as Node3D
			if not is_instance_valid(root) or not root.is_visible_in_tree(): continue
			var gap := Vector2(root.global_position.x - player.x, root.global_position.z - player.z).length()
			if gap <= UMBRELLA_REACH: people.append({"root": root, "gap": gap, "height": _body_height(record)})
	people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap < b.gap)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.75
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in range(mini(UMBRELLAS, people.size())):
		var umbrella := MeshInstance3D.new()
		umbrella.name = "ResidentUmbrella%d" % index
		umbrella.mesh = _umbrella_mesh(UMBRELLA_TONES[index % UMBRELLA_TONES.size()])
		umbrella.material_override = material
		umbrella.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		umbrella.visible = false
		add_child(umbrella)
		umbrellas.append({"node": umbrella, "root": people[index].root, "open": 0.0, "height": float(people[index].height)})


## How tall a resident's drawn body is; an unmeasured one counts as an adult.
static func _body_height(record: Dictionary) -> float:
	var height := float(record.get("name_body_height", 0.0))
	return height if height > 0.8 else 2.4


func _resident_worlds() -> Array[Node3D]:
	var hosts: Array[Node3D] = [_world]
	if is_instance_valid(_world.district_host):
		for region: String in _world.district_host.districts:
			var district: Node3D = _world.district_host.districts[region]
			if is_instance_valid(district): hosts.append(district)
	return hosts


func _update_umbrellas() -> void:
	var right: Vector3 = _director.camera_basis().x
	right.y = 0.0
	right = right.normalized()
	for record: Dictionary in umbrellas:
		var umbrella := record.node as MeshInstance3D
		var root := record.root as Node3D
		if not is_instance_valid(root):
			umbrella.visible = false
			continue
		var target := 1.0 if raining() and _cover > 0.2 else 0.0
		record.open = target if _reduced else move_toward(float(record.open), target, 1.0 / 30.0)
		var open := float(record.open)
		umbrella.visible = open > 0.01 and root.is_visible_in_tree()
		if not umbrella.visible: continue
		# Held in the right hand, the canopy over the head; it pops open from a furl.
		# The canopy rim sits just above the head, whatever the resident's height.
		umbrella.global_position = root.global_position + right * 0.42 + Vector3(0, float(record.height) - 1.12, 0)
		umbrella.scale = Vector3(lerpf(0.25, 1.0, open), 1.0, lerpf(0.25, 1.0, open))
		umbrella.rotation = Vector3(0, 0, -0.12)


## A striped eight-gore canopy with a scalloped rim, a shaft and a hooked handle.
static func _umbrella_mesh(tone: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(-0.42, 1.62, 0)
	var radius := 0.82
	var gores := 8
	var cream := Color("#f6ead2")
	for gore in range(gores):
		var colour: Color = tone if gore % 2 == 0 else cream
		var a0 := TAU * gore / gores
		var a1 := TAU * (gore + 1) / gores
		var mid := (a0 + a1) * 0.5
		var p0 := apex + Vector3(cos(a0) * radius, -0.34, sin(a0) * radius)
		var p1 := apex + Vector3(cos(a1) * radius, -0.34, sin(a1) * radius)
		# Each gore bellies out between its ribs and dips at its rim.
		var belly := apex + Vector3(cos(mid) * radius * 0.62, -0.12, sin(mid) * radius * 0.62)
		var dip := apex + Vector3(cos(mid) * radius * 0.92, -0.42, sin(mid) * radius * 0.92)
		for triangle: Array in [[apex, p0, belly], [apex, belly, p1], [p0, dip, belly], [belly, dip, p1]]:
			var normal := ((triangle[1] - triangle[0]) as Vector3).cross(triangle[2] - triangle[0]).normalized()
			if normal.y < 0.0: normal = -normal
			for vertex: Vector3 in triangle:
				tool.set_color(colour.darkened(0.12) if vertex == dip else colour)
				tool.set_normal(normal)
				tool.add_vertex(vertex)
	var wood := Color("#7a5338")
	_tube(tool, apex + Vector3(0, 0.12, 0), apex + Vector3(0, -1.15, 0), 0.022, wood)
	_tube(tool, apex + Vector3(0, -1.15, 0), apex + Vector3(0.10, -1.24, 0), 0.03, wood)
	_tube(tool, apex + Vector3(0.10, -1.24, 0), apex + Vector3(0.17, -1.13, 0), 0.03, wood)
	return tool.commit()


static func _tube(tool: SurfaceTool, from: Vector3, to: Vector3, width: float, colour: Color) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.FORWARD).normalized() * width
	var depth := along.cross(side).normalized() * width
	var ring := [side, depth, -side, -depth]
	for index in range(4):
		var a: Vector3 = ring[index]
		var b: Vector3 = ring[(index + 1) % 4]
		var normal := (a + b).normalized()
		for vertex: Vector3 in [from + a, to + a, to + b, from + a, to + b, from + b]:
			tool.set_color(colour)
			tool.set_normal(normal)
			tool.add_vertex(vertex)


# --- rainbow -------------------------------------------------------------------

func _build_rainbow() -> void:
	if not ResourceLoader.exists(RAINBOW_SHADER):
		push_warning("Rainbow shader is missing; the shower ends without one.")
		return
	_rainbow_material = ShaderMaterial.new()
	_rainbow_material.shader = load(RAINBOW_SHADER)
	var quad := QuadMesh.new()
	quad.size = Vector2(RAINBOW_WIDTH, RAINBOW_WIDTH * 0.5)
	rainbow = MeshInstance3D.new()
	rainbow.name = "Rainbow"
	rainbow.mesh = quad
	rainbow.material_override = _rainbow_material
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rainbow.visible = false
	add_child(rainbow)


func _update_rainbow(player: Vector3) -> void:
	if rainbow == null: return
	var strength := rainbow_strength()
	rainbow.visible = strength > 0.0
	if not rainbow.visible: return
	_rainbow_material.set_shader_parameter("strength", strength)
	# Faces the camera a few metres behind the walker; its arc foot sits low on screen.
	var basis: Basis = _director.camera_basis()
	rainbow.global_transform = Transform3D(basis, player - basis.z * 3.0 + basis.y * (RAINBOW_WIDTH * 0.25 - 3.0))
