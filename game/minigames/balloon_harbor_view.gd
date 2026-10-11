extends Control
class_name BalloonHarborView

## A reusable 3D miniature that projects onto the balloon game's 1280×720
## design plane. Geometry and materials are created once; present() only updates
## transforms, visibility, and the existing lighting resources.

const HARBOR_FONT: FontFile = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const MAILBOX_DESIGN_POINTS: Array[Vector2] = [Vector2(520.0, 305.0), Vector2(820.0, 480.0), Vector2(1080.0, 320.0)]
const CAMERA_ORTHO_SIZE := 28.0
const VIEW_SCALE := CAMERA_ORTHO_SIZE / DESIGN_SIZE.y
const VIEW_ELEVATION := 0.78539816339
const Z_SCALE := VIEW_SCALE / cos(VIEW_ELEVATION)

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _balloon: Node3D
var _envelope_pivot: Node3D
var _canopy: MeshInstance3D
var _wind_streams: Array[Node3D] = []
var _harbor_flags: Array[Node3D] = []
var _night_lanterns: Array[Node3D] = []
var _mailbox_beacons: Array[MeshInstance3D] = []
var _mailbox_lights: Array[OmniLight3D] = []
var _water_shader_material: ShaderMaterial
var _dock_rings: Array[MeshInstance3D] = []
var _dock_lights: Array[Array] = []
var _delivery_stamps: Array[MeshInstance3D] = []
var _delivery_bags: Array[Node3D] = []
var _current_wind: Node3D
var _forecast_wind: Node3D
var _brake_glow: MeshInstance3D
var _urchin: Node3D
var _hazard_ring: MeshInstance3D
var _initialized := false
var _last_delivered := 0
var _last_delivery_index := -1
var _delivery_event_started_at := -1.0
var _last_phase := ""

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.name = "HarborViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_world = Node3D.new()
	_world.name = "HarborWorld"
	_viewport.add_child(_world)
	_build_environment()
	_build_harbor()
	_build_mailboxes()
	_build_balloon()
	_build_wind_arrows()
	_build_hazard()
	_apply_phase("noon")

func present(position: Vector2, velocity: Vector2, wind: Vector2, forecast: Vector2, mailbox_index: int, dock_hold: float, braking: bool, elapsed: float, reduced: bool, phase: String, delivered: int, hazard_position: Vector2 = Vector2(-1.0, -1.0), hazard_radius: float = 65.0) -> void:
	if not _initialized:
		initialize()
	var design_point := Vector2(clampf(position.x, 0.0, DESIGN_SIZE.x), clampf(position.y, 0.0, DESIGN_SIZE.y))
	var world_point := _design_to_world(design_point)
	_balloon.position = Vector3(world_point.x, 2.45, world_point.z)
	var sway := sin(elapsed * 1.9) * 0.035 if not reduced else 0.0
	_envelope_pivot.rotation.z = clampf(velocity.x / 420.0, -0.09, 0.09) + sway if not reduced else 0.0
	_envelope_pivot.rotation.x = clampf(-velocity.y / 520.0, -0.07, 0.07) if not reduced else 0.0
	_brake_glow.visible = braking
	_set_wind_heading(_current_wind, wind)
	_set_wind_heading(_forecast_wind, forecast)
	var flag_vector := wind if wind.length_squared() > 0.01 else forecast
	var flag_heading := _wind_heading(flag_vector) if flag_vector.length_squared() > 0.01 else 0.0
	for flag in _harbor_flags:
		flag.rotation.y = flag_heading
	for stream_index in _wind_streams.size():
		var stream := _wind_streams[stream_index]
		var vector := wind if stream_index == 0 else forecast
		stream.rotation.y = _wind_heading(vector) if vector.length_squared() > 0.01 else 0.0
		stream.visible = vector.length_squared() > 0.01
	if _water_shader_material != null:
		_water_shader_material.set_shader_parameter("wave_time", 0.0 if reduced else elapsed)
	var active_index := clampi(mailbox_index, 0, _dock_rings.size() - 1)
	for i in _dock_rings.size():
		var active := i == active_index
		_dock_rings[i].visible = active
		var lights: Array = _dock_lights[i]
		var lit_count := int(round(clampf(dock_hold / 0.5, 0.0, 1.0) * lights.size())) if active else 0
		for light_index in lights.size():
			(lights[light_index] as MeshInstance3D).visible = light_index < lit_count
	var completed := clampi(delivered, 0, _delivery_bags.size())
	if completed > _last_delivered:
		_last_delivery_index = completed - 1
		_delivery_event_started_at = elapsed
	for i in _delivery_bags.size():
		_delivery_bags[i].visible = i < completed
		_delivery_stamps[i].visible = i < completed
		var is_arriving := i == _last_delivery_index and elapsed - _delivery_event_started_at < 0.42 and not reduced
		if i < completed:
			var bag_rest_y := 0.92
			if is_arriving:
				var age := clampf((elapsed - _delivery_event_started_at) / 0.42, 0.0, 1.0)
				_delivery_bags[i].position.y = lerpf(3.1, bag_rest_y, age)
				var pulse := 1.0 + 0.42 * (1.0 - age)
				_delivery_stamps[i].scale = Vector3.ONE * pulse
			else:
				_delivery_bags[i].position.y = bag_rest_y
				_delivery_stamps[i].scale = Vector3.ONE
	_last_delivered = completed
	_update_hazard(hazard_position, hazard_radius)
	_apply_phase(phase)

func texture() -> Texture2D:
	return _viewport.get_texture() if _initialized and is_instance_valid(_viewport) else null

func design_to_screen(point: Vector2) -> Vector2:
	if not _initialized:
		initialize()
	return _camera.unproject_position(_design_to_world(point))

func screen_to_design(point: Vector2) -> Vector2:
	if not _initialized:
		initialize()
	var ray_origin := _camera.project_ray_origin(point)
	var ray_direction := _camera.project_ray_normal(point)
	var intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return Vector2(-1.0, -1.0)
	var world_point: Vector3 = intersection
	return Vector2(world_point.x / VIEW_SCALE + DESIGN_SIZE.x * 0.5, world_point.z / Z_SCALE + DESIGN_SIZE.y * 0.5)

func _design_to_world(point: Vector2) -> Vector3:
	return Vector3((point.x - DESIGN_SIZE.x * 0.5) * VIEW_SCALE, 0.0, (point.y - DESIGN_SIZE.y * 0.5) * Z_SCALE)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Environment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.tonemap_exposure = 1.0
	_environment.ambient_light_sky_contribution = 0.22
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("#83bdc2")
	_sky_material.sky_horizon_color = Color("#f4d3a1")
	_sky_material.ground_bottom_color = Color("#315969")
	_sky_material.ground_horizon_color = Color("#83a99f")
	sky.sky_material = _sky_material
	_environment.sky = sky
	world_environment.environment = _environment
	_world.add_child(world_environment)
	_key_light = DirectionalLight3D.new()
	_key_light.name = "KeyLight"
	_key_light.shadow_enabled = true
	_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key_light.directional_shadow_max_distance = 70.0
	_key_light.shadow_opacity = 0.62
	_key_light.shadow_blur = 1.5
	_world.add_child(_key_light)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.position = Vector3(0.0, 28.0, 28.0)
	_camera.attributes = CameraAttributesPractical.new()
	_world.add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.current = true

func _build_harbor() -> void:
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(76.0, 58.0)
	_world.add_child(_mesh_node("SeaGlassWater", sea_mesh, _water_material(), Vector3(0.0, -0.42, 0.0)))
	var foam_material := _material("#69bdb3", 0.76)
	var glint_material := _material("#c5e8d8", 0.7)
	var coral_material := _material("#db5b42", 0.74)
	var ochre_material := _material("#d5a349", 0.7)
	var roof_material := _material("#aa4434", 0.82)
	var pale_material := _material("#f1deba", 0.78)
	var deep_material := _material("#183e4a", 0.86)
	var wood_material := _material("#a7774e", 0.9)
	var plank_materials: Array[StandardMaterial3D] = [_material("#c89865", 0.9), _material("#bd8758", 0.9), _material("#d2a572", 0.92)]
	# Asymmetric, tapered ribbons never intersect into a technical grid.
	var crest_points: Array[Vector2] = [Vector2(135, 340), Vector2(355, 185), Vector2(685, 205), Vector2(960, 170), Vector2(175, 600), Vector2(280, 480), Vector2(1100, 610), Vector2(975, 465), Vector2(640, 645), Vector2(1210, 390)]
	for wave_index in crest_points.size():
		var wave_p := _design_to_world(crest_points[wave_index])
		var wave := _mesh_node("SeaCrest%d" % wave_index, _wave_ribbon(2.6 + float(wave_index % 4) * 0.8, 0.11, 0.065), glint_material if wave_index % 3 == 0 else foam_material, wave_p + Vector3(0.0, -0.365, 0.0))
		wave.rotation.y = -0.12 + float(wave_index % 3) * 0.11
		_world.add_child(wave)
	for i in MAILBOX_DESIGN_POINTS.size():
		var p := _design_to_world(MAILBOX_DESIGN_POINTS[i])
		var base_mesh: Mesh = _box(Vector3(9.0, 0.5, 7.0)) if i == 0 else (_cylinder(3.7, 0.56) if i == 1 else _boat_hull_mesh())
		_world.add_child(_mesh_node("RooftopIsland%d" % i, base_mesh, deep_material, Vector3(p.x, -0.06, p.z)))
		var ledge_mesh: Mesh = _box(Vector3(8.8, 0.16, 6.8)) if i == 0 else (_cylinder(3.61, 0.16) if i == 1 else _box(Vector3(7.3, 0.13, 3.0)))
		_world.add_child(_mesh_node("QuayLedge%d" % i, ledge_mesh, pale_material, Vector3(p.x, 0.205, p.z)))
		var deck_mesh: Mesh = _box(Vector3(8.5, 0.2, 6.5)) if i == 0 else (_cylinder(3.5, 0.20) if i == 1 else _box(Vector3(6.8, 0.20, 2.7)))
		_world.add_child(_mesh_node("RoofCap%d" % i, deck_mesh, wood_material if i != 1 else pale_material, Vector3(p.x, 0.31, p.z)))
		if i != 1:
			for plank_index in (16 if i == 0 else 13):
				var plank_x := -4.0 + float(plank_index) * 0.52 if i == 0 else -3.12 + float(plank_index) * 0.52
				_world.add_child(_mesh_node("DockPlank%d_%d" % [i, plank_index], _box(Vector3(0.49, 0.035, 6.43 if i == 0 else 2.63)), plank_materials[plank_index % 3], Vector3(p.x + plank_x, 0.432, p.z)))
		if i == 0:
			# An open counter, expressive gable, and exposed posts belong only to the postal stop.
			var c := Vector3(p.x - 2.15, 1.22, p.z - 2.05)
			_world.add_child(_mesh_node("ShedBody0", _box(Vector3(2.7, 1.4, 2.1)), pale_material, c))
			for side in 2:
				var roof := _mesh_node("ShedRoofLeft0" if side == 0 else "ShedRoofRight0", _box(Vector3(1.75, 0.18, 2.85)), coral_material if side == 0 else roof_material, c + Vector3(-0.65 if side == 0 else 0.65, 1.05, 0.0))
				roof.rotation.z = 0.46 if side == 0 else -0.46
				_world.add_child(roof)
			_world.add_child(_mesh_node("PostalRoofBeam", _box(Vector3(3.2, 0.16, 0.17)), wood_material, c + Vector3(0, 0.64, 1.37)))
			_world.add_child(_mesh_node("PostalCounter", _box(Vector3(2.05, 0.15, 0.56)), ochre_material, c + Vector3(0, -0.18, 1.28)))
			_world.add_child(_mesh_node("PostalServiceOpening", _box(Vector3(1.9, 0.58, 0.06)), deep_material, c + Vector3(0, 0.16, 1.07)))
			for post_index in 2:
				_world.add_child(_mesh_node("PostalPorchPost%d" % post_index, _box(Vector3(0.12, 1.75, 0.14)), wood_material, c + Vector3(-1.32 if post_index == 0 else 1.32, 0.05, 1.37)))
				_add_window("ShedWindow0_%d" % post_index, c + Vector3(-0.57 + float(post_index) * 1.14, 0.23, 1.11), Vector3(0.65, 0.42, 0.055), pale_material)
			_world.add_child(_mesh_node("PostOfficeFascia", _box(Vector3(2.12, 0.38, 0.13)), coral_material, c + Vector3(0, 0.73, 1.44)))
			_world.add_child(_mesh_node("PostOfficeSeal", _box(Vector3(0.63, 0.29, 0.05)), pale_material, c + Vector3(0, 0.73, 1.53)))
			for fold_side in 2:
				var fold := _mesh_node("PostOfficeEnvelopeFold%d" % fold_side, _box(Vector3(0.37, 0.035, 0.025)), roof_material, c + Vector3(-0.11 + float(fold_side) * 0.22, 0.76, 1.57))
				fold.rotation.z = -0.54 if fold_side == 0 else 0.54
				_world.add_child(fold)
			for rail_side in 2:
				var rail_z := p.z + (-3.0 if rail_side == 0 else 3.0)
				for post_index in 5:
					var post_x := p.x - 3.8 + float(post_index) * 1.9
					_world.add_child(_mesh_node("QuayRailPost0_%d_%d" % [rail_side, post_index], _cylinder(0.10, 1.15), deep_material, Vector3(post_x, 0.89, rail_z)))
				_world.add_child(_beam("QuayRope0_%d" % rail_side, Vector3(p.x-3.8, 1.2, rail_z), Vector3(p.x+3.8, 1.2, rail_z), 0.055, pale_material))
			for support_index in 4:
				_world.add_child(_mesh_node("DockPiling%d" % support_index, _cylinder(0.19, 1.18), wood_material, p + Vector3(-3.65 + float(support_index) * 2.4, -0.08, 3.03)))
			_world.add_child(_mesh_node("PostalParcelStack", _box(Vector3(0.64, 0.64, 0.56)), ochre_material, c + Vector3(1.98,-0.44,0.8)))
		elif i == 1:
			var c := Vector3(p.x + 1.4, 0.0, p.z - 1.65)
			_world.add_child(_mesh_node("LighthouseBase", _cylinder(1.13, 0.3), deep_material, c + Vector3(0,0.55,0)))
			var tower_mesh := _cylinder(0.77, 4.4)
			tower_mesh.top_radius = 0.56
			_world.add_child(_mesh_node("LighthouseTower", tower_mesh, pale_material, c + Vector3(0,2.78,0)))
			for band_index in 3:
				var radius := 0.748 - float(band_index) * 0.045
				_world.add_child(_mesh_node("LighthouseBand%d" % band_index, _cylinder(radius,0.36), coral_material, c + Vector3(0,1.15+float(band_index)*1.24,0)))
			_world.add_child(_mesh_node("LighthouseDoor", _box(Vector3(0.47,0.91,0.12)), deep_material, c + Vector3(0,1.14,0.76)))
			for side in 2:
				_add_window("ShedWindow1_%d" % side, c + Vector3(-0.15 + float(side)*0.3,3.27,0.67),Vector3(0.17,0.40,0.08),ochre_material)
			_world.add_child(_mesh_node("LighthouseBalconyDeck", _cylinder(1.02,0.14), deep_material,c + Vector3(0,4.98,0)))
			_world.add_child(_mesh_node("LighthouseBalcony", _torus(1.00,0.055), pale_material,c + Vector3(0,5.48,0)))
			for rail_index in 10:
				var angle := TAU * float(rail_index)/10.0
				_world.add_child(_mesh_node("LighthouseRailPost%d" % rail_index,_cylinder(0.045,0.48),pale_material,c+Vector3(cos(angle),5.24,sin(angle))))
			var glass := _material("#ffd78b",0.32)
			glass.emission_enabled = true
			glass.emission = Color("#ffc475")
			glass.emission_energy_multiplier = 0.22
			_world.add_child(_mesh_node("LighthouseLanternRoom",_cylinder(0.59,0.74),glass,c+Vector3(0,5.47,0)))
			for frame_index in 6:
				var angle := TAU * float(frame_index)/6.0
				_world.add_child(_mesh_node("LanternFrame%d" % frame_index,_cylinder(0.035,0.85),deep_material,c+Vector3(cos(angle)*0.59,5.46,sin(angle)*0.59)))
			_world.add_child(_mesh_node("LighthouseRoof",_cone(0.91,0.82),roof_material,c+Vector3(0,6.24,0)))
			_world.add_child(_mesh_node("LighthouseFinial",_sphere(0.12),ochre_material,c+Vector3(0,6.72,0)))
			# Stone seams and two low perimeter rails keep the circular apron distinct.
			for stone_index in 12:
				var angle := TAU * float(stone_index)/12.0
				_world.add_child(_beam("ApronJoint%d" % stone_index,p+Vector3(cos(angle)*2.35,0.423,sin(angle)*2.35),p+Vector3(cos(angle)*3.44,0.423,sin(angle)*3.44),0.015,wood_material))
		else:
			# A long pointed hull and two full sails replace the third roof-house.
			_world.add_child(_mesh_node("ParcelBoatHull",_boat_hull_mesh(),deep_material,p+Vector3(0,-0.03,0)))
			var mast := p + Vector3(1.1,0.0,-0.90)
			_world.add_child(_mesh_node("ParcelBoatMast",_cylinder(0.09,5.5),wood_material,mast+Vector3(0,3.12,0)))
			_world.add_child(_beam("ParcelBoatBoom",mast+Vector3(-3.2,1.18,0),mast+Vector3(0,1.18,0),0.07,wood_material))
			var cloth := _material("#f7e6c7",0.92)
			cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
			_world.add_child(_mesh_node("ParcelBoatSail",_cloth_mesh(Vector3(0,5.75,0),Vector3(-3.15,1.32,0),Vector3(0,1.32,0),0.4),cloth,mast))
			_world.add_child(_mesh_node("ParcelBoatJib",_cloth_mesh(Vector3(0.16,5.3,0),Vector3(0.16,1.45,0),Vector3(2.6,1.45,0),0.28),cloth,mast))
			_world.add_child(_beam("BoatStandingRig",mast+Vector3(0,5.8,0),p+Vector3(3.75,0.59,0),0.025,pale_material))
			_world.add_child(_beam("BoatMooringRope",p+Vector3(-3.6,0.67,0.5),p+Vector3(-4.15,-0.1,2.0),0.045,pale_material))
			_world.add_child(_mesh_node("BoatMooringBuoy",_sphere(0.26),coral_material,p+Vector3(-4.15,-0.16,2.0)))
			_world.add_child(_beam("BoatBowRail",p+Vector3(2.8,0.65,1.15),p+Vector3(4.35,0.72,0),0.09,coral_material))
			_world.add_child(_beam("BoatPortRail",p+Vector3(-3.3,0.66,-1.28),p+Vector3(3.0,0.66,-1.15),0.07,pale_material))
			_world.add_child(_beam("BoatStarboardRail",p+Vector3(-3.3,0.66,1.28),p+Vector3(2.8,0.66,1.15),0.07,pale_material))
			_world.add_child(_mesh_node("BoatCabin",_box(Vector3(1.0,0.65,1.28)),coral_material,p+Vector3(-2.15,0.8,-0.1)))
			for side in 2:
				_add_window("ShedWindow2_%d" % side,p+Vector3(-2.36+float(side)*0.43,0.9,0.56),Vector3(0.27,0.25,0.06),pale_material)
			_world.add_child(_mesh_node("BoatCabinCap",_box(Vector3(1.13,0.12,1.38)),pale_material,p+Vector3(-2.15,1.18,-0.1)))
			_world.add_child(_mesh_node("BoatPennant",_triangle_sail_mesh(),coral_material,mast+Vector3(0,5.8,0)))
	# Small low-poly reef groups frame the route instead of reading as scattered dark disks.
	var rock_materials: Array[StandardMaterial3D] = [_material("#526d68", 0.91), _material("#607d74", 0.94), _material("#46656a", 0.88)]
	var reef_centers: Array[Vector2] = [Vector2(160, 250), Vector2(370, 570), Vector2(1080, 575), Vector2(1150, 200)]
	for reef_index in reef_centers.size():
		var reef_point := _design_to_world(reef_centers[reef_index])
		for stone_index in 3:
			var stone := _mesh_node("TideRock%d_%d" % [reef_index, stone_index], _sphere(1.0), rock_materials[stone_index], Vector3(reef_point.x + (float(stone_index) - 1.0) * 0.36, -0.20 + float(stone_index % 2) * 0.035, reef_point.z + (float(stone_index % 2) - 0.5) * 0.52))
			stone.scale = Vector3(0.32 + float((reef_index + stone_index) % 3) * 0.10, 0.18 + float(stone_index % 2) * 0.045, 0.27 + float((reef_index + stone_index) % 2) * 0.10)
			_world.add_child(stone)
	# Pennants follow the supplied wind even when reduced motion is active.
	for landmark_index in 3:
		var design := Vector2(245.0 + float(landmark_index) * 330.0, 235.0 + float(landmark_index % 2) * 210.0)
		var p := _design_to_world(design)
		var mast := _mesh_node("HarborMast%d" % landmark_index, _cylinder(0.12, 3.7), ochre_material, Vector3(p.x, 1.5, p.z))
		_world.add_child(mast)
		var mast_top := _mesh_node("MastCap%d" % landmark_index, _sphere(0.26), coral_material, Vector3(p.x, 3.4, p.z))
		_world.add_child(mast_top)
		var flag_rig := Node3D.new()
		flag_rig.name = "MastFlag%d" % landmark_index
		flag_rig.position = Vector3(p.x, 2.92, p.z)
		var flag_material := coral_material if landmark_index == 0 else (foam_material if landmark_index == 1 else ochre_material)
		flag_rig.add_child(_mesh_node("Pennant", _triangle_sail_mesh(), flag_material, Vector3(0.0, 0.0, 0.08)))
		_world.add_child(flag_rig)
		_harbor_flags.append(flag_rig)
	var pier_center := _design_to_world(Vector2(655.0, 555.0))
	var pier_shadow := _mesh_node("PierShadow", _box(Vector3(16.2, 0.18, 3.8)), deep_material, pier_center + Vector3(0.0, -0.37, 0.0))
	_world.add_child(pier_shadow)
	var pier := _mesh_node("Pier", _box(Vector3(15.0, 0.42, 2.8)), roof_material, pier_center + Vector3(0.0, -0.05, 0.0))
	_world.add_child(pier)
	for board_index in 8:
		var board := _mesh_node("PierDeckBoard%d" % board_index, _box(Vector3(1.82, 0.025, 2.72)), plank_materials[board_index % 3], pier.position + Vector3(-6.7 + float(board_index) * 1.9, 0.225, 0.0))
		_world.add_child(board)
	for post_index in 5:
		var point := pier.position + Vector3(-6.0 + post_index * 3.0, 0.52, 0.0)
		_world.add_child(_mesh_node("PierPost%d" % post_index, _cylinder(0.19, 1.45), ochre_material, point))
		var cap := _mesh_node("PierPostCap%d" % post_index, _sphere(0.22), coral_material, point + Vector3(0.0, 0.78, 0.0))
		_world.add_child(cap)
		var lantern := Node3D.new()
		lantern.name = "PierLantern%d" % post_index
		var lantern_glass := _material("#ffd68e", 0.24)
		lantern_glass.emission_enabled = true
		lantern_glass.emission = Color("#ffb75d")
		lantern_glass.emission_energy_multiplier = 1.8
		lantern.add_child(_mesh_node("Glass", _sphere(0.22), lantern_glass, Vector3.ZERO))
		var frame := _mesh_node("Frame", _box(Vector3(0.42, 0.08, 0.42)), deep_material, Vector3(0.0, -0.25, 0.0))
		lantern.add_child(frame)
		lantern.position = point + Vector3(0.0, 1.02, 0.0)
		lantern.visible = false
		_world.add_child(lantern)
		var point_light := OmniLight3D.new()
		point_light.name = "Glow"
		point_light.light_color = Color("#ffb85f")
		point_light.light_energy = 0.45
		point_light.omni_range = 3.5
		point_light.shadow_enabled = false
		lantern.add_child(point_light)
		_night_lanterns.append(lantern)
	# Directional surface lanes reuse meshes and rotate only when wind input changes.
	for lane_index in 2:
		var lane := Node3D.new()
		lane.name = "WindLane%d" % lane_index
		var lane_mat := _material("#c2dbbd" if lane_index == 0 else "#d8bc89", 0.48, 0.03)
		for dash_index in 4:
			var dash := _mesh_node("Dash%d" % dash_index, _box(Vector3(2.0 + float(dash_index % 2), 0.025, 0.07)), lane_mat, Vector3(-4.5 + float(dash_index) * 3.0, -0.34, float(lane_index) * 1.2))
			lane.add_child(dash)
		var lane_tip := _mesh_node("DirectionTip", _cone(0.18, 0.38), lane_mat, Vector3(6.2, -0.34, float(lane_index) * 1.2))
		lane_tip.rotation.z = -PI * 0.5
		lane.add_child(lane_tip)
		lane.position = Vector3(-3.0, 0.0, 0.0) if lane_index == 0 else Vector3(4.0, 0.0, 0.0)
		lane.visible = false
		_world.add_child(lane)
		_wind_streams.append(lane)

func _build_mailboxes() -> void:
	var post_materials: Array[StandardMaterial3D] = [
		_material("#cf765f", 0.68),
		_material("#d3b26f", 0.68),
		_material("#558f86", 0.68),
	]
	var slot_material := _material("#594b4a", 0.92)
	var ring_material := _material("#f0c477", 0.48, 0.08)
	var stamp_material := _material("#73b5a0", 0.7)
	for index in MAILBOX_DESIGN_POINTS.size():
		var p := _design_to_world(MAILBOX_DESIGN_POINTS[index])
		var ring := _mesh_node("DockRing%d" % index, _torus(1.75, 0.12), ring_material, Vector3(p.x, 0.59, p.z))
		ring.visible = false
		_dock_rings.append(ring)
		_world.add_child(ring)
		var marker_lights: Array[MeshInstance3D] = []
		for light_index in 8:
			var angle := TAU * float(light_index) / 8.0
			var light_pos := Vector3(p.x + cos(angle) * 2.0, 0.66, p.z + sin(angle) * 2.0)
			var marker := _mesh_node("DockLight%d_%d" % [index, light_index], _sphere(0.16), stamp_material, light_pos)
			marker.visible = false
			marker_lights.append(marker)
			_world.add_child(marker)
		_dock_lights.append(marker_lights)
		var mailbox := _mesh_node("Mailbox%d" % index, _box(Vector3(0.9, 0.82, 0.72)), post_materials[index], Vector3(p.x, 0.94, p.z))
		_world.add_child(mailbox)
		var roof_material := _material("#f1d49e" if index != 1 else "#cf765f", 0.72)
		var roof := _mesh_node("MailboxRoof%d" % index, _box(Vector3(1.18, 0.18, 0.92)), roof_material, Vector3(p.x, 1.43, p.z))
		_world.add_child(roof)
		var slot := _mesh_node("MailboxSlot%d" % index, _box(Vector3(0.47, 0.09, 0.04)), slot_material, Vector3(p.x, 1.08, p.z + 0.38))
		_world.add_child(slot)
		var number := _mesh_node("MailboxNumber%d" % index, _sphere(0.2), _material("#f8e9bd", 0.55), Vector3(p.x, 0.61, p.z + 0.40))
		_world.add_child(number)
		var beacon_material := _material("#f2dc9a", 0.32)
		beacon_material.emission_enabled = true
		beacon_material.emission = Color("#ffd17a")
		beacon_material.emission_energy_multiplier = 0.0
		var beacon := _mesh_node("MailboxBeacon%d" % index, _sphere(0.17), beacon_material, Vector3(p.x, 1.86, p.z + 0.06))
		_mailbox_beacons.append(beacon)
		_world.add_child(beacon)
		var mailbox_light := OmniLight3D.new()
		mailbox_light.name = "MailboxLight%d" % index
		mailbox_light.position = Vector3(p.x, 1.9, p.z + 0.06)
		mailbox_light.light_color = Color("#ffd17a")
		mailbox_light.light_energy = 0.0
		mailbox_light.omni_range = 3.0
		mailbox_light.shadow_enabled = false
		_world.add_child(mailbox_light)
		_mailbox_lights.append(mailbox_light)
		var stamp := _mesh_node("DeliveryStamp%d" % index, _cylinder(0.35, 0.12), stamp_material, Vector3(p.x + 1.3, 0.57, p.z))
		stamp.visible = false
		_delivery_stamps.append(stamp)
		_world.add_child(stamp)
		var bag := Node3D.new()
		bag.name = "DeliveredBag%d" % index
		bag.position = Vector3(p.x + 1.3, 0.92, p.z + 0.85)
		bag.visible = false
		var bag_mesh := _mesh_node("BagBody", _box(Vector3(0.48, 0.56, 0.38)), _material("#bf795c", 0.82), Vector3.ZERO)
		bag.add_child(bag_mesh)
		var bag_fold := _mesh_node("BagFold", _box(Vector3(0.35, 0.12, 0.4)), _material("#e2b779", 0.78), Vector3(0.0, 0.26, 0.0))
		bag.add_child(bag_fold)
		var bag_seal := _mesh_node("BagSeal", _sphere(0.09), _material("#f1d99c", 0.66), Vector3(0.0, 0.02, -0.22))
		bag.add_child(bag_seal)
		_delivery_bags.append(bag)
		_world.add_child(bag)

func _build_balloon() -> void:
	_balloon = Node3D.new()
	_balloon.name = "Balloon"
	_world.add_child(_balloon)
	# The balloon root is also the sway pivot, preserving the public Ballon/Canopy path.
	_envelope_pivot = _balloon
	var canopy_material := _material("#e76448", 0.76)
	var stripe_material := _material("#197f83", 0.74)
	var crown_material := _material("#f1d59a", 0.64)
	_canopy = _mesh_node("Canopy", _sphere(1.0), canopy_material, Vector3(0.0, 2.05, 0.0))
	_canopy.scale = Vector3(1.7, 2.0, 1.36)
	_envelope_pivot.add_child(_canopy)
	var canopy_band := _mesh_node("CanopyBand", _sphere(1.0), stripe_material, Vector3(0.0, 1.88, 0.0))
	canopy_band.scale = Vector3(1.73, 0.18, 1.39)
	_envelope_pivot.add_child(canopy_band)
	var crown := _mesh_node("EnvelopeCrown", _sphere(0.28), crown_material, Vector3(0.0, 4.03, 0.0))
	_envelope_pivot.add_child(crown)
	for panel_index in 4:
		var angle := TAU * float(panel_index) / 4.0
		var panel := _mesh_node("EnvelopePanel%d" % panel_index, _envelope_panel_mesh(angle), stripe_material, Vector3(0.0,2.05,0.0))
		_envelope_pivot.add_child(panel)
	var rope_material := _material("#f1d5a3", 0.86)
	for rope_index in 4:
		var x_offset := -0.42 if rope_index % 2 == 0 else 0.42
		var z_offset := -0.28 if rope_index < 2 else 0.28
		var rope := _mesh_node("BasketRope%d" % rope_index, _cylinder(0.035, 0.72), rope_material, Vector3(x_offset, 0.28, z_offset))
		rope.rotation.z = -0.12 if x_offset < 0.0 else 0.12
		_envelope_pivot.add_child(rope)
	var basket := _mesh_node("WickerBasket", _box(Vector3(0.88, 0.48, 0.72)), _material("#ad7650", 0.9), Vector3(0.0, -0.32, 0.0))
	_envelope_pivot.add_child(basket)
	_brake_glow = _mesh_node("BrakeGlow", _torus(0.74, 0.09), _material("#e7cc83", 0.45, 0.08), Vector3(0.0, 0.0, 0.0))
	_brake_glow.visible = false
	_envelope_pivot.add_child(_brake_glow)
	var wicker := _material("#d2a878", 0.86)
	for weave in 3:
		var band := _mesh_node("BasketWeave%d" % weave, _box(Vector3(0.91, 0.045, 0.025)), wicker, Vector3(0.0, -0.47 + weave * 0.14, 0.37))
		_envelope_pivot.add_child(band)

func _build_wind_arrows() -> void:
	_current_wind = _make_wind_arrow("CurrentWind", Color("#62c3b0"))
	_forecast_wind = _make_wind_arrow("ForecastWind", Color("#efbd71"))
	_world.add_child(_current_wind)
	_world.add_child(_forecast_wind)
	_current_wind.position = _design_to_world(Vector2(187.0,611.0)) + Vector3(0,0.12,0)
	_forecast_wind.position = _design_to_world(Vector2(187.0,671.0)) + Vector3(0,0.12,0)
	# This pooled legend remains in the play area for every legal balloon position.
	var legend := Panel.new()
	legend.name = "WindLegend"
	legend.position = Vector2(24,568)
	legend.size = Vector2(256,134)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.02,0.09,0.13,0.20)
	border.border_color = Color(0.73,0.82,0.78,0.40)
	border.set_border_width_all(1)
	border.set_corner_radius_all(10)
	legend.add_theme_stylebox_override("panel",border)
	_viewport.add_child(legend)
	for row in 2:
		var caption := Label.new()
		caption.name = "CurrentCaption" if row == 0 else "ForecastCaption"
		caption.text = "現在風向" if row == 0 else "預報風向"
		caption.position = Vector2(15,26 + row*60)
		caption.add_theme_font_override("font",HARBOR_FONT)
		caption.add_theme_font_size_override("font_size",18)
		caption.add_theme_color_override("font_color",Color("#e9dfc5"))
		caption.add_theme_color_override("font_shadow_color",Color("#173e4a"))
		caption.add_theme_constant_override("shadow_offset_x",1)
		caption.add_theme_constant_override("shadow_offset_y",1)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(caption)

func _build_hazard() -> void:
	var warning_material := _material("#f0d089", 0.42, 0.06)
	warning_material.emission_enabled = true
	warning_material.emission = Color("#e6bc6e")
	warning_material.emission_energy_multiplier = 0.12
	_hazard_ring = _mesh_node("HazardAvoidanceRing", _torus(0.96, 0.045), warning_material, Vector3.ZERO)
	_hazard_ring.visible = false
	for tick_index in 8:
		var angle := TAU * float(tick_index) / 8.0
		var tick := _mesh_node("HazardTick%d" % tick_index, _box(Vector3(0.055, 0.035, 0.20)), warning_material, Vector3(cos(angle) * 0.82, 0.025, sin(angle) * 0.82))
		tick.rotation.y = -angle
		_hazard_ring.add_child(tick)
	_world.add_child(_hazard_ring)
	_urchin = Node3D.new()
	_urchin.name = "SeaUrchinHazard"
	_urchin.visible = false
	_world.add_child(_urchin)
	var body := _mesh_node("UrchinBody", _sphere(0.82), _material("#d97967", 0.58), Vector3(0.0, 1.42, 0.0))
	_urchin.add_child(body)
	var spine_materials: Array[StandardMaterial3D] = [_material("#31545d", 0.55), _material("#e1b96f", 0.68)]
	for spike_index in 12:
		var angle := TAU * float(spike_index) / 12.0
		var horizontal := Vector2(cos(angle), sin(angle))
		var spike := _mesh_node("Spine%d" % spike_index, _cone(0.16, 1.05), spine_materials[spike_index % 2], Vector3(horizontal.x * 0.53, 1.56 + (0.08 if spike_index % 2 == 0 else 0.0), horizontal.y * 0.53))
		spike.rotation.z = -horizontal.x * 0.72
		spike.rotation.x = horizontal.y * 0.72
		_urchin.add_child(spike)
	var eye_white := _material("#f2e4c3", 0.7)
	var pupil_material := _material("#263d48", 0.65)
	for eye_index in 2:
		var eye_x := -0.23 if eye_index == 0 else 0.23
		_urchin.add_child(_mesh_node("UrchinEye%d" % eye_index, _sphere(0.14), eye_white, Vector3(eye_x, 1.50, 0.69)))
		_urchin.add_child(_mesh_node("UrchinPupil%d" % eye_index, _sphere(0.065), pupil_material, Vector3(eye_x, 1.50, 0.81)))

func _update_hazard(position: Vector2, radius: float) -> void:
	var enabled := position.x >= 0.0 and position.y >= 0.0 and radius > 0.0
	_hazard_ring.visible = enabled
	_urchin.visible = enabled
	if not enabled:
		return
	var world_point := _design_to_world(position)
	_hazard_ring.position = Vector3(world_point.x, 0.29, world_point.z)
	# The torus outer radius is one world unit before scaling, so its projected
	# X/Z radii match the same 2D 65px collision circle in each design axis.
	_hazard_ring.scale = Vector3(radius * VIEW_SCALE, 1.0, radius * Z_SCALE)
	_urchin.position = Vector3(world_point.x, 0.0, world_point.z)

func _make_wind_arrow(node_name: String, color: Color) -> Node3D:
	var arrow := Node3D.new()
	arrow.name = node_name
	var mat := _material(color, 0.45, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if node_name == "CurrentWind":
		arrow.add_child(_mesh_node("Shaft", _box(Vector3(1.95,0.08,0.17)),mat,Vector3(0.52,0,0)))
	else:
		for dash_index in 3:
			arrow.add_child(_mesh_node("ForecastDash%d" % dash_index,_box(Vector3(0.43,0.08,0.17)),mat,Vector3(-0.25+float(dash_index)*0.62,0,0)))
	var point := _mesh_node("PennantTip", _cone(0.29, 0.52), mat, Vector3(1.42, 0.0, 0.0))
	point.rotation.z = -PI * 0.5
	arrow.add_child(point)
	return arrow

func _wind_heading(vector: Vector2) -> float:
	# Compensate for orthographic foreshortening so the screen arrow follows the 2D wind.
	return atan2(-vector.y * Z_SCALE, vector.x * VIEW_SCALE)

func _set_wind_heading(arrow: Node3D, vector: Vector2) -> void:
	var direction := vector
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	arrow.rotation.y = _wind_heading(direction)
	var size := 0.60 + 0.004 * minf(direction.length(), 60.0)
	arrow.scale = Vector3.ONE * size

func _apply_phase(phase: String) -> void:
	var id := phase.to_lower()
	if id in ["day", "daytime"]: id = "noon"
	if id not in ["dawn", "noon", "dusk", "night"]: id = "noon"
	if id == _last_phase:
		return
	_last_phase = id
	match id:
		"dawn":
			_key_light.light_color = Color("#ffd0a1"); _key_light.light_energy = 0.66
			_environment.ambient_light_color = Color("#afabb0"); _environment.ambient_light_energy = 0.36
			_sky_material.sky_top_color = Color("#91a9c3"); _sky_material.sky_horizon_color = Color("#e9b395")
		"noon":
			_key_light.light_color = Color("#fff0db"); _key_light.light_energy = 1.08
			_environment.ambient_light_color = Color("#88b3bd"); _environment.ambient_light_energy = 0.38
			_sky_material.sky_top_color = Color("#83bdc2"); _sky_material.sky_horizon_color = Color("#f4d3a1")
		"dusk":
			_key_light.light_color = Color("#ffad83"); _key_light.light_energy = 0.62
			_environment.ambient_light_color = Color("#a68a9e"); _environment.ambient_light_energy = 0.35
			_sky_material.sky_top_color = Color("#a86974"); _sky_material.sky_horizon_color = Color("#e5a073")
		"night":
			_key_light.light_color = Color("#b8ceff"); _key_light.light_energy = 0.30
			_environment.ambient_light_color = Color("#7186ad"); _environment.ambient_light_energy = 0.31
			_sky_material.sky_top_color = Color("#34415f"); _sky_material.sky_horizon_color = Color("#7b7896")
	_key_light.rotation_degrees = Vector3(-48.0, 34.0, -24.0) if id in ["dawn", "dusk"] else Vector3(-54.0, -38.0, -22.0)
	if _water_shader_material != null:
		_water_shader_material.set_shader_parameter("phase_tint", Color("#426f8e") if id == "night" else (Color("#b39696") if id == "dusk" else (Color("#bad1cd") if id == "dawn" else Color.WHITE)))
	for lantern in _night_lanterns:
		lantern.visible = id == "night"
	for index in _mailbox_beacons.size():
		var beacon_material := _mailbox_beacons[index].material_override as StandardMaterial3D
		beacon_material.emission_energy_multiplier = 0.9 if id == "night" else 0.0
		_mailbox_lights[index].light_energy = 0.35 if id == "night" else 0.0
	for shed_index in 3:
		for side in 2:
			var window_material := (_world.get_node("ShedWindow%d_%d" % [shed_index, side]) as MeshInstance3D).material_override as StandardMaterial3D
			if window_material != null:
				window_material.albedo_color = Color("#ffd48c") if id == "night" else Color("#214e5a")
				window_material.emission_enabled = id == "night"
				window_material.emission = Color("#ffb969")
				window_material.emission_energy_multiplier = 1.1 if id == "night" else 0.0

func _wave_ribbon(length: float, amplitude: float, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 28
	for index in segments + 1:
		var t := float(index) / float(segments)
		var x := (t - 0.5) * length
		var z := sin(t * TAU * 1.6) * amplitude + sin(t * TAU * 3.3) * amplitude * 0.18
		vertices.append(Vector3(x, 0.0, z - width * sin(t * PI) * 0.5))
		vertices.append(Vector3(x, 0.0, z + width * sin(t * PI) * 0.5))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for index in segments:
		var base := index * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform float wave_time = 0.0;
uniform vec4 phase_tint : source_color = vec4(1.0);
float swell(vec2 p) {
	return sin(p.x * 0.18 + p.y * 0.11) * 0.45 + sin(p.x * 0.31 - p.y * 0.23) * 0.25;
}
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(76.0, 58.0);
	float depth = smoothstep(-0.65, 0.6, swell(p));
	vec3 sea = mix(vec3(0.025, 0.18, 0.25), vec3(0.035, 0.39, 0.43), depth);
	float shoal = exp(-length((p - vec2(-4.67,-3.02)) / vec2(7.8,6.0))) + exp(-length((p - vec2(7.0,6.6)) / vec2(5.6,5.4))) + exp(-length((p - vec2(17.1,-2.2)) / vec2(6.8,3.9)));
	sea = mix(sea, vec3(0.075,0.47,0.46), clamp(shoal * 0.35,0.0,0.48));
	float band = sin(p.y * 1.9 + sin(p.x * 0.38) * 0.65 - wave_time * 0.48);
	float crest = smoothstep(0.965, 1.0, band);
	float breakage = smoothstep(0.2,0.74,sin(p.x * 1.23 + sin(p.y * 0.4) * 3.2) * 0.5 + 0.5);
	float sparkle = crest * breakage * (0.35 + depth * 0.28);
	ALBEDO = mix(sea, vec3(0.40,0.69,0.66), sparkle) * phase_tint.rgb;
}
"""
	_water_shader_material = ShaderMaterial.new()
	_water_shader_material.shader = shader
	_water_shader_material.set_shader_parameter("wave_time", 0.0)
	return _water_shader_material

func _add_window(node_name: String, point: Vector3, size: Vector3, trim: Material) -> void:
	_world.add_child(_mesh_node(node_name + "Frame", _box(size + Vector3(0.11,0.11,-0.005)),trim,point+Vector3(0,0,-0.015)))
	_world.add_child(_mesh_node(node_name,_box(size),_material("#214e5a",0.52),point))
	_world.add_child(_mesh_node(node_name + "Mullion",_box(Vector3(0.035,size.y,0.018)),trim,point+Vector3(0,0,0.04)))

func _beam(node_name: String, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var beam := _mesh_node(node_name,_cylinder(radius,start.distance_to(end)),material,(start+end)*0.5)
	beam.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
	return beam

func _faceted_mesh(triangles: PackedVector3Array) -> ArrayMesh:
	var normals := PackedVector3Array()
	for index in range(0,triangles.size(),3):
		var normal := (triangles[index+1]-triangles[index]).cross(triangles[index+2]-triangles[index]).normalized()
		normals.append_array(PackedVector3Array([normal,normal,normal]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = triangles
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _boat_hull_mesh() -> ArrayMesh:
	var outline := PackedVector3Array([Vector3(-3.65,0.60,-1.1),Vector3(2.65,0.60,-1.35),Vector3(4.45,0.60,0),Vector3(2.65,0.60,1.35),Vector3(-3.65,0.60,1.1)])
	var triangles := PackedVector3Array()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var low_a := Vector3(a.x*0.85,-0.47,a.z*0.48)
		var low_b := Vector3(b.x*0.85,-0.47,b.z*0.48)
		triangles.append_array(PackedVector3Array([a,b,low_a,b,low_b,low_a,Vector3(0,0.58,0),b,a]))
	return _faceted_mesh(triangles)

func _envelope_panel_mesh(heading: float) -> ArrayMesh:
	var triangles := PackedVector3Array()
	for row in 16:
		var lat_a := lerpf(-1.25,1.34,float(row)/16.0)
		var lat_b := lerpf(-1.25,1.34,float(row+1)/16.0)
		for column in 3:
			var angle_a := heading + lerpf(-0.16,0.16,float(column)/3.0)
			var angle_b := heading + lerpf(-0.16,0.16,float(column+1)/3.0)
			var a := Vector3(sin(angle_a)*cos(lat_a)*1.726,sin(lat_a)*2.025,cos(angle_a)*cos(lat_a)*1.388)
			var b := Vector3(sin(angle_b)*cos(lat_a)*1.726,sin(lat_a)*2.025,cos(angle_b)*cos(lat_a)*1.388)
			var c := Vector3(sin(angle_a)*cos(lat_b)*1.726,sin(lat_b)*2.025,cos(angle_a)*cos(lat_b)*1.388)
			var d := Vector3(sin(angle_b)*cos(lat_b)*1.726,sin(lat_b)*2.025,cos(angle_b)*cos(lat_b)*1.388)
			triangles.append_array(PackedVector3Array([a,b,c,b,d,c]))
	return _faceted_mesh(triangles)

func _cloth_mesh(top: Vector3, left: Vector3, right: Vector3, billow: float) -> ArrayMesh:
	var center := (top+left+right)/3.0 + Vector3(0,0,billow)
	return _faceted_mesh(PackedVector3Array([top,left,center,left,right,center,right,top,center]))

func _triangle_sail_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.75, 0.0), Vector3(1.25, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.04), Vector3(1.25, 0.0, 0.04), Vector3(0.0, 1.75, 0.04),
	])
	var normals := PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var indices := PackedInt32Array([0, 1, 2, 3, 4, 5])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _material(color: Variant, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color if color is Color else Color(str(color))
	material.roughness = roughness
	material.metallic = metallic
	return material

func _mesh_node(node_name: String, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = position
	return node

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh

func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh

func _torus(radius: float, thickness: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 8
	return mesh
