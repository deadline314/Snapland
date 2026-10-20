extends Node3D
## Optional, scene-owned toys: manual optics and a garden that responds to water.
## No score, quest event, item, timer pressure or persistent reward.
var world: Node3D
const RAY_LENGTH := 11.5
var controlling := false
var lens_angle := -0.72
var lens_origin := Vector3(-31, 6.65, -45)
var lens: Node3D
var beam: MeshInstance3D
var beacon_light: SpotLight3D
var receivers: Array[MeshInstance3D] = []
var receiver_angles := [-0.72, 0.0, 0.72]
var receiver_active := -1
var garden_open := false
var garden_growth := 0.0
var flowers: Array[Node3D] = []
var droplets: Array[MeshInstance3D] = []
var garden_handle: MeshInstance3D
var _clock := 0.0
var _cooldown := 0.0

func configure(owner_world: Node3D) -> void:
	world = owner_world
	_build_optics()
	_build_garden()
	_update_optics()
	_update_garden()

func _build_optics() -> void:
	lens = Node3D.new()
	lens.name = "PlayerLighthouseLens"
	lens.position = lens_origin
	add_child(lens)
	var housing: MeshInstance3D = world._cylinder(lens_origin, 0.42, 0.34, Color("#bb955c"))
	housing.reparent(lens)
	housing.rotation.z = PI * 0.5
	# This registered light shares the existing eight-light/two-shadow budget.
	beacon_light = SpotLight3D.new()
	beacon_light.name = "CoastalSteerableBeacon"
	beacon_light.position = lens_origin
	beacon_light.spot_range = 21.0
	beacon_light.spot_angle = 8.0
	beacon_light.light_color = Color("#ffe5a3")
	beacon_light.light_energy = 0.0
	world.add_child(beacon_light)
	world.lamps.append(beacon_light)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.10
	cone.bottom_radius = 0.84
	cone.height = RAY_LENGTH
	cone.radial_segments = 12
	beam = MeshInstance3D.new()
	beam.name = "LighthouseLightShaft"
	beam.mesh = cone
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var haze := StandardMaterial3D.new()
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.albedo_color = Color(1.0, 0.86, 0.52, 0.065)
	beam.material_override = haze
	add_child(beam)
	for angle in receiver_angles:
		var direction := Vector3(-cos(angle), -0.42, sin(angle)).normalized()
		var p := lens_origin + direction * RAY_LENGTH
		world._cylinder(Vector3(p.x, 0.0, p.z), 0.13, p.y * 2.0, Color("#52776f"))
		world._cylinder(Vector3(p.x, 0.1, p.z), 0.55, 0.22, Color("#a98c5b"))
		var reflector: MeshInstance3D = world._sphere(p, 0.48, Color("#668b86"))
		reflector.name = "SeaSignalReflector%d" % receivers.size()
		reflector.material_override = reflector.material_override.duplicate()
		receivers.append(reflector)
	# The low wheel is beside the reachable trail, not on the inaccessible tower.
	world._cylinder(Vector3(-27.9, 0.7, -45), 0.12, 1.2, Color("#755d40"))
	var wheel: MeshInstance3D = world._cylinder(Vector3(-27.9, 1.25, -45), 0.37, 0.10, Color("#c49d62"))
	wheel.rotation.x = PI * 0.5
	world._box(Vector3(-27.9, 1.25, -44.9), Vector3(0.60, 0.08, 0.08), Color("#486c68"))

func _build_garden() -> void:
	# Keep the four established pots and stems; add distinct buds and petals.
	for index in 4:
		var flower := Node3D.new()
		flower.name = "SeaGlassBloom%d" % index
		flower.position = Vector3(29.8 + float(index) * 0.8, 1.5, -49.35)
		add_child(flower)
		var color := Color("#edbd73") if index % 2 == 0 else Color("#d98283")
		var center: MeshInstance3D = world._sphere(flower.position, 0.13, Color("#e5d4a0"))
		center.reparent(flower)
		for petal in 5:
			var angle := TAU * float(petal) / 5.0
			var p: Vector3 = flower.position + Vector3(cos(angle) * 0.22, 0, sin(angle) * 0.22)
			var mesh: MeshInstance3D = world._sphere(p, 0.17, color)
			mesh.scale = Vector3(1.0, 0.40, 1.0)
			mesh.reparent(flower)
		flowers.append(flower)
	world._box(Vector3(29.7, 0.35, -50.5), Vector3(3.6, 0.12, 0.16), Color("#668d8b"))
	for index in 8:
		var drop: MeshInstance3D = world._sphere(Vector3(29.8 + float(index % 4) * 0.8, 1.9, -49.35), 0.035, Color("#a6ded7"))
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		droplets.append(drop)
	garden_handle = world._cylinder(Vector3(28.0, 1.0, -52), 0.3, 0.10, Color("#bd925a"))
	garden_handle.rotation.x = PI * 0.5

func activate(id: String) -> bool:
	if id not in ["coast:lighthouse", "coast:glass-garden"]: return false
	if not is_instance_valid(world) or world.blocked or not world.is_processing(): return false
	if id == "coast:lighthouse":
		controlling = not controlling
		return true
	if _cooldown > 0.0: return true
	_cooldown = 0.18
	garden_open = not garden_open
	_update_garden()
	return true

func prompt(id: String) -> String:
	if controlling: return "←／→ 或拖曳轉燈鏡 · E 離開"
	if id == "coast:lighthouse": return "轉動燈鏡，找海上的回光"
	if id == "coast:glass-garden": return "關閉灑水，留下花朵" if garden_open else "打開溫室灑水"
	return ""

func end_control() -> bool:
	var was_controlling := controlling
	controlling = false
	return was_controlling

func advance(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if controlling:
		if world.player.position.distance_to(Vector3(-27, 0.18, -45)) > 3.2:
			end_control()
		else:
			var axis := Input.get_axis("move_left", "move_right")
			if not is_zero_approx(axis): turn_lens(axis * delta * 0.8)
	if garden_open and garden_growth < 1.0:
		garden_growth = minf(1.0, garden_growth + delta / 3.0)
		_update_garden()
	if garden_open and not world.reduced_motion:
		for index in droplets.size():
			droplets[index].position.y = 2.1 - fposmod(_clock * 1.3 + float(index) * 0.23, 0.9)
	# The same full scene works in daylight. Haze follows the actual night light.
	beam.visible = beacon_light.light_energy > 0.0

func turn_lens(amount: float) -> void:
	lens_angle = clampf(lens_angle + amount, -0.9, 0.9)
	_update_optics()

func _update_optics() -> void:
	var direction := Vector3(-cos(lens_angle), -0.42, sin(lens_angle)).normalized()
	lens.look_at(lens_origin + direction)
	beacon_light.look_at(lens_origin + direction)
	# Cylinder's small top is at the real emitter; its wide base faces the sea.
	beam.position = lens_origin + direction * RAY_LENGTH * 0.5
	beam.quaternion = Quaternion(Vector3.UP, -direction)
	receiver_active = -1
	for index in receivers.size():
		var hit := absf(lens_angle - float(receiver_angles[index])) < 0.075
		var mat := receivers[index].material_override as StandardMaterial3D
		mat.emission_enabled = hit
		mat.emission = Color("#ffda89") if hit else Color.BLACK
		mat.albedo_color = Color("#ffe9b0") if hit else Color("#668b86")
		if hit: receiver_active = index

func _update_garden() -> void:
	garden_handle.rotation.z = PI * 0.5 if garden_open else 0.0
	for drop in droplets: drop.visible = garden_open
	for index in flowers.size():
		var progress := clampf((garden_growth - float(index) * 0.09) / 0.73, 0.0, 1.0)
		flowers[index].scale = Vector3.ONE * lerpf(0.08, 1.0, progress)

func _unhandled_input(event: InputEvent) -> void:
	if not controlling or world.blocked or not world.is_processing(): return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		turn_lens(event.relative.x * 0.005)
		get_viewport().set_input_as_handled()
