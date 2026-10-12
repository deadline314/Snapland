extends Control
class_name FountainJumpView

## Close orthographic fountain court for fountain_timing. The host owns game
## rules; this view consumes the same phase/attempt/jump-start snapshot.

const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const DESIGN_SIZE := Vector2i(1280, 720)
const CONTENT_BOUNDS := Rect2(142.0, 130.0, 996.0, 550.0)
const PERIOD := 1.35
const FIRST_BEAT := 1.0
const HIT_HEIGHT_BASE := 42.0
const HIT_HEIGHT_SWING := 132.0
const WATER_PIXELS_TO_WORLD := 5.4 / 720.0
const JUMP_DURATION := 8.0 / 12.0
const JUMP_LIFT_PIXELS := 48.0
const FEET_BASELINE := 346.0
const CANVAS_HEIGHT := 360.0
const AVATAR_PIXEL_SIZE := 0.0045
const DAY_PHASES := ["noon", "dusk", "night", "dawn"]

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _fill_light: OmniLight3D
var _fountain_light: OmniLight3D
var _lantern_light: OmniLight3D
var _hero_light: OmniLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _renderer: RefCounted
var _avatar: Sprite3D
var _avatar_textures: Array[Texture2D] = []
var _avatar_idle: Texture2D
var _avatar_available := false
var _warned_avatar := false
var _last_avatar_pose := ""
var _jet_nodes: Array[MeshInstance3D] = []
var _jet_mist_nodes: Array[MeshInstance3D] = []
var _jet_thread_nodes: Array[Array] = []
var _jet_materials: Array[StandardMaterial3D] = []
var _ornament_nodes: Array[MeshInstance3D] = []
var _lantern_glass_material: StandardMaterial3D
var _water_glaze_material: StandardMaterial3D
var _initialized := false
var _reduced_motion := false
var _last_phase := "noon"

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.name = "FountainCourtViewport"
	_viewport.size = DESIGN_SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_world = Node3D.new()
	_world.name = "FountainCourtWorld"
	_viewport.add_child(_world)
	_build_environment()
	_build_stage()
	_build_avatar()
	_apply_time_phase("noon")

func configure_avatar(appearance: Dictionary, equipped: Dictionary) -> void:
	if not _initialized:
		initialize()
	_avatar_textures.clear()
	_avatar_idle = null
	_avatar_available = false
	_renderer = AvatarRendererScript.new()
	if not is_instance_valid(_avatar) or _renderer == null:
		_warn_avatar_once("AvatarRenderer or billboard target is unavailable; the court remains operable without a character sprite.")
		return
	_avatar_idle = _renderer.texture(appearance, equipped, "front", 0, "idle")
	if _avatar_idle != null:
		_avatar_textures.append(_avatar_idle)
	if _renderer.has_authored_action("jump", "front"):
		var count: int = _renderer.authored_frame_count("jump", "front")
		for index in count:
			var pose: Texture2D = _renderer.texture(appearance, equipped, "front", index, "jump")
			if pose != null:
				_avatar_textures.append(pose)
	_avatar_available = _avatar_idle != null
	if _avatar_available:
		_avatar.texture = _avatar_idle
		_avatar.visible = true
		_last_avatar_pose = "idle"
	else:
		_avatar.visible = false
		_warn_avatar_once("AvatarRenderer returned no idle texture; hiding the sprite instead of inventing a pose.")

## Read-only inputs: phase, fountain_attempts, fountain_jump_started. Aliases
## accept the model-facing `attempt` and `jump_started` fields as well.
func update_frame(snapshot: Dictionary, time_phase: String = "noon", reduced_motion: bool = false) -> void:
	if not _initialized:
		initialize()
	_reduced_motion = reduced_motion
	_apply_time_phase(time_phase)
	var phase_value: Variant = snapshot.get("phase", 0.0)
	var attempt_value: Variant = snapshot.get("fountain_attempts", snapshot.get("attempt", 0))
	var jump_value: Variant = snapshot.get("fountain_jump_started", snapshot.get("jump_started", -1.0))
	var phase := _finite_or(phase_value, 0.0)
	var attempt := clampi(int(attempt_value) if _is_finite_number(attempt_value) else 0, 0, 3)
	var jump_started := _finite_or(jump_value, -1.0)
	for index in _jet_nodes.size():
		var height_pixels: float
		if index == 2 and attempt < 3:
			var beat := FIRST_BEAT + float(attempt) * PERIOD
			var offset := phase - beat
			height_pixels = 108.0 if reduced_motion else HIT_HEIGHT_BASE + HIT_HEIGHT_SWING * (0.5 + 0.5 * cos(PI * offset / (PERIOD * 0.5)))
		else:
			height_pixels = 78.0 if reduced_motion else HIT_HEIGHT_BASE + absf(sin(phase * 2.3 + float(index) * 0.7)) * HIT_HEIGHT_SWING
		var height := clampf(height_pixels * WATER_PIXELS_TO_WORLD, 0.18, 1.42)
		_set_jet_height(index, height)
		var near_cue := index == 2 and attempt < 3 and absf(phase - (FIRST_BEAT + float(attempt) * PERIOD)) <= 0.44
		var grade_ready: bool = bool(snapshot.get("beat_window", false)) and near_cue
		var water_color := Color("#fff3c1") if grade_ready else Color("#e6c773") if near_cue else Color("#75d2d1")
		_jet_materials[index].albedo_color = Color(water_color, 0.72 if grade_ready else 0.52)
		_jet_materials[index].emission = water_color.lightened(0.08)
		_jet_materials[index].emission_energy_multiplier = 0.36 if grade_ready else 0.22 if near_cue else 0.13
	_update_avatar(phase, jump_started, reduced_motion)

func get_texture() -> Texture2D:
	return _viewport.get_texture() if _initialized and is_instance_valid(_viewport) else null

func content_bounds() -> Rect2:
	return CONTENT_BOUNDS

func camera() -> Camera3D:
	return _camera if _initialized and is_instance_valid(_camera) else null

func sub_viewport() -> SubViewport:
	return _viewport if _initialized and is_instance_valid(_viewport) else null

func world_root() -> Node3D:
	return _world if _initialized and is_instance_valid(_world) else null

func avatar_available() -> bool:
	return _avatar_available

func avatar_sprite() -> Sprite3D:
	return _avatar if _initialized and is_instance_valid(_avatar) else null

func timed_jet_height_pixels(phase: float, attempt: int, reduced_motion: bool = false) -> float:
	if not is_finite(phase):
		return 108.0 if reduced_motion else HIT_HEIGHT_BASE
	var safe_attempt := clampi(attempt, 0, 2)
	if reduced_motion:
		return 108.0
	var beat := FIRST_BEAT + float(safe_attempt) * PERIOD
	var offset := phase - beat
	return HIT_HEIGHT_BASE + HIT_HEIGHT_SWING * (0.5 + 0.5 * cos(PI * offset / (PERIOD * 0.5)))

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Environment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#c6d8cc")
	_environment.ambient_light_energy = 0.72
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("#557f87")
	_sky_material.sky_horizon_color = Color("#e3bd83")
	_sky_material.ground_bottom_color = Color("#254b55")
	_sky_material.ground_horizon_color = Color("#78928a")
	sky.sky_material = _sky_material
	_environment.sky = sky
	world_environment.environment = _environment
	_world.add_child(world_environment)
	_key_light = DirectionalLight3D.new()
	_key_light.name = "SunAndStageKey"
	_key_light.shadow_enabled = true
	_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key_light.directional_shadow_max_distance = 12.0
	_key_light.shadow_opacity = 0.68
	_key_light.shadow_blur = 1.0
	_key_light.position = Vector3(-3.8, 6.2, -4.8)
	_world.add_child(_key_light)
	_fill_light = OmniLight3D.new()
	_fill_light.name = "WaterBounce"
	_fill_light.position = Vector3(-1.9, 2.3, -0.5)
	_fill_light.light_color = Color("#78d9d2")
	_fill_light.light_energy = 1.45
	_fill_light.omni_range = 6.2
	_fill_light.position = Vector3(0.55, 2.2, -1.75)
	_fill_light.shadow_enabled = false
	_world.add_child(_fill_light)
	_fountain_light = OmniLight3D.new()
	_fountain_light.name = "BasinWaterGlow"
	_fountain_light.position = Vector3(0.0, 1.35, 0.25)
	_fountain_light.light_color = Color("#71d9d1")
	_fountain_light.light_energy = 0.58
	_fountain_light.omni_range = 3.4
	_fountain_light.shadow_enabled = false
	_world.add_child(_fountain_light)
	_lantern_light = OmniLight3D.new()
	_lantern_light.name = "StageLanternLight"
	_lantern_light.position = Vector3(-2.68, 1.58, 1.28)
	_lantern_light.light_color = Color("#ffd18b")
	_lantern_light.light_energy = 0.38
	_lantern_light.omni_range = 3.0
	_lantern_light.shadow_enabled = false
	_world.add_child(_lantern_light)
	_hero_light = OmniLight3D.new()
	_hero_light.name = "HeroLanternBounce"
	_hero_light.position = Vector3(1.30, 1.45, -3.55)
	_hero_light.light_color = Color("#ffd39a")
	_hero_light.light_energy = 0.18
	_hero_light.omni_range = 2.8
	_hero_light.shadow_enabled = false
	_world.add_child(_hero_light)
	_camera = Camera3D.new()
	_camera.name = "CloseThreeQuarterCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 5.4
	_camera.position = Vector3(0.0, 4.15, -9.6)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.20, 0.0), Vector3.UP)
	_camera.current = true

func _build_stage() -> void:
	var stone := _mat("#737b73", 0.91)
	var limestone := _mat("#c6b38d", 0.84)
	var dark_stone := _mat("#3c5f63", 0.88)
	var brick := _mat("#b96e55", 0.86)
	var brass := _mat("#c99b50", 0.38, 0.62)
	var teal := _mat("#418d89", 0.5, 0.16)
	var water := _mat("#75c5c0", 0.24, 0.12)
	water.emission_enabled = true
	water.emission = Color("#70c9c6")
	water.emission_energy_multiplier = 0.16
	var stage_floor := _mesh_node("CourtFloor", _box(Vector3(7.6, 0.32, 5.7)), stone, Vector3(0, -0.18, 0))
	_world.add_child(stage_floor)
	var inset := _mesh_node("OctagonalTile", _cylinder(2.75, 0.055), dark_stone, Vector3(0, 0.015, 0.12))
	inset.rotation.y = PI / 8.0
	_world.add_child(inset)
	var drain := _mesh_node("DrainMedallion", _cylinder(0.4, 0.025), dark_stone, Vector3(-1.65, 0.055, -0.6))
	_world.add_child(drain)
	for spoke in 8:
		var angle := TAU * float(spoke) / 8.0
		var point := Vector3(-1.65 + cos(angle) * 0.25, 0.075, -0.6 + sin(angle) * 0.25)
		var mark := _mesh_node("DrainCut%d" % spoke, _box(Vector3(0.07, 0.016, 0.17)), brass if spoke % 2 == 0 else teal, point)
		mark.rotation.y = angle
		_world.add_child(mark)
		_ornament_nodes.append(mark)
	# Framed stage piers: stepped plinths, inset teal panels, and gilt capitals
	# make the canopy read as a small civic pavilion rather than two bare posts.
	for side in 2:
		var x := -3.05 if side == 0 else 3.05
		var pier := _mesh_node("StagePier%d" % side, _box(Vector3(0.39, 1.68, 0.38)), brick if side == 0 else teal, Vector3(x, 0.91, 1.92))
		_world.add_child(pier)
		var plinth := _mesh_node("PierPlinth%d" % side, _box(Vector3(0.62, 0.22, 0.56)), dark_stone, Vector3(x, 0.13, 1.92))
		_world.add_child(plinth)
		var pier_panel := _mesh_node("PierInset%d" % side, _box(Vector3(0.17, 1.00, 0.055)), limestone if side == 0 else brick, Vector3(x, 0.89, 1.716))
		_world.add_child(pier_panel)
		var pier_flute := _mesh_node("PierFlute%d" % side, _box(Vector3(0.045, 1.16, 0.065)), brass, Vector3(x + (0.10 if side == 0 else -0.10), 0.88, 1.67))
		_world.add_child(pier_flute)
		var capital := _mesh_node("PierCapital%d" % side, _box(Vector3(0.63, 0.16, 0.5)), brass, Vector3(x, 1.82, 1.92))
		_world.add_child(capital)
	var lintel := _mesh_node("StageLintel", _box(Vector3(6.18, 0.24, 0.38)), dark_stone, Vector3(0, 1.97, 1.92))
	_world.add_child(lintel)
	_world.add_child(_mesh_node("GiltCanopyEdge", _box(Vector3(6.42, 0.065, 0.43)), brass, Vector3(0, 2.13, 1.88)))
	_world.add_child(_mesh_node("CanopyCrown", _box(Vector3(4.25, 0.09, 0.37)), brick, Vector3(0, 2.23, 1.92)))
	for scallop in 7:
		var x := -2.55 + float(scallop) * 0.85
		var hanging := _mesh_node("CanopyScallop%d" % scallop, _cylinder(0.18, 0.08), brick if scallop % 2 == 0 else teal, Vector3(x, 1.83, 1.76))
		hanging.rotation.z = PI * 0.5
		_world.add_child(hanging)
	# Layered circular basin; the waterline has narrow brass and glaze bands.
	_world.add_child(_mesh_node("BasinFoot", _cylinder(1.45, 0.28), dark_stone, Vector3(0.0, 0.22, 0.25)))
	_world.add_child(_mesh_node("BasinBody", _cylinder(1.72, 0.38), teal, Vector3(0.0, 0.48, 0.25)))
	_world.add_child(_mesh_node("OuterLip", _torus(1.68, 0.10), brass, Vector3(0.0, 0.69, 0.25)))
	_world.add_child(_mesh_node("InnerGlaze", _torus(1.48, 0.07), limestone, Vector3(0.0, 0.72, 0.25)))
	_water_glaze_material = water.duplicate() as StandardMaterial3D
	_water_glaze_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_glaze_material.albedo_color = Color("#75c5c0", 0.78)
	_water_glaze_material.emission_enabled = true
	_water_glaze_material.emission = Color("#70c9c6")
	_water_glaze_material.emission_energy_multiplier = 0.1
	var pool := _mesh_node("StillWater", _cylinder(1.48, 0.035), _water_glaze_material, Vector3(0.0, 0.68, 0.25))
	_world.add_child(pool)
	var shell_material := _mat("#dfc89a", 0.52, 0.16)
	var wave_material := _mat("#72c9bc", 0.39, 0.12)
	for ornament in 6:
		var angle := TAU * float(ornament) / 6.0
		var radius := 1.59
		var shell := _mesh_node("BasinShell%d" % ornament, _shell_mesh(), shell_material, Vector3(cos(angle) * radius, 0.73, 0.25 + sin(angle) * radius))
		shell.rotation.y = -angle
		_world.add_child(shell)
		var wave_mark := _mesh_node("BasinWaveInlay%d" % ornament, _wave_carve_mesh(), wave_material, Vector3(cos(angle) * 1.42, 0.752, 0.25 + sin(angle) * 1.42))
		wave_mark.rotation.y = -angle
		_world.add_child(wave_mark)
	var pedestal := _mesh_node("NozzlePedestal", _cylinder(0.37, 0.47), limestone, Vector3(0.0, 0.87, 0.25))
	_world.add_child(pedestal)
	var pedestal_cap := _mesh_node("NozzleBrassCap", _cylinder(0.46, 0.075), brass, Vector3(0.0, 1.12, 0.25))
	_world.add_child(pedestal_cap)
	# Five flowing, translucent water bundles. Ribbons are triangulated once and
	# stretched upward from their submerged nozzles; there are no solid cones or balls.
	for index in 5:
		var x := -1.14 + float(index) * 0.57
		var base := Vector3(x, 0.74, 0.25)
		var flowing_water := water.duplicate() as StandardMaterial3D
		flowing_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flowing_water.albedo_color = Color("#72d7d5", 0.48)
		flowing_water.cull_mode = BaseMaterial3D.CULL_DISABLED
		flowing_water.emission_enabled = true
		flowing_water.emission = Color("#49c0c4")
		flowing_water.emission_energy_multiplier = 0.14
		flowing_water.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		var jet := _mesh_node("WaterJet%d" % index, _flow_surface_mesh(0.066, 0.085, float(index) * 0.71, 1.0), flowing_water, base)
		jet.scale = Vector3.ONE
		_world.add_child(jet)
		_jet_nodes.append(jet)
		_jet_materials.append(flowing_water)
		var threads: Array[MeshInstance3D] = []
		for thread_index in 2:
			var thread_material := flowing_water.duplicate() as StandardMaterial3D
			thread_material.albedo_color = Color("#c5f5eb", 0.54 if thread_index == 0 else 0.39)
			thread_material.emission = Color("#76e0d8")
			thread_material.emission_energy_multiplier = 0.19 if thread_index == 0 else 0.12
			var thread := _mesh_node("WaterThread%d_%d" % [index, thread_index], _flow_surface_mesh(0.019 if thread_index == 0 else 0.012, 0.035 + float(thread_index) * 0.027, float(index) * 0.91 + float(thread_index) * 2.1, -0.045 if thread_index == 0 else 0.045), thread_material, base + Vector3(0, 0, -0.025))
			_world.add_child(thread)
			threads.append(thread)
		_jet_thread_nodes.append(threads)
		var mist := _mesh_node("JetCrest%d" % index, _torus(0.082, 0.014), _mat("#d9f5dc", 0.28), base + Vector3(0, 0.31, 0))
		_world.add_child(mist)
		mist.scale = Vector3(1.42, 0.48, 0.58)
		_jet_mist_nodes.append(mist)
		var collar := _mesh_node("NozzleCollar%d" % index, _torus(0.13, 0.035), brass, base + Vector3(0, 0.07, 0))
		_world.add_child(collar)
	# Tile chips and inlaid compass points are sparse and remain outside the timing lane.
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var tile := _mesh_node("CompassTile%d" % index, _box(Vector3(0.24, 0.024, 0.11)), brick if index % 2 == 0 else teal, Vector3(cos(angle) * 2.45, 0.06, 0.25 + sin(angle) * 2.05))
		tile.rotation.y = angle
		_world.add_child(tile)
		_ornament_nodes.append(tile)
	var lantern_case := _mesh_node("StageLanternCase", _box(Vector3(0.30, 0.35, 0.24)), dark_stone, Vector3(-2.68, 1.58, 1.56))
	_world.add_child(lantern_case)
	var lantern_glass := _mesh_node("StageLanternPane", _box(Vector3(0.19, 0.22, 0.055)), _mat("#e8c774", 0.28), Vector3(-2.68, 1.58, 1.417))
	_lantern_glass_material = lantern_glass.material_override as StandardMaterial3D
	_lantern_glass_material.emission_enabled = true
	_lantern_glass_material.emission = Color("#ffd88f")
	_lantern_glass_material.emission_energy_multiplier = 0.25
	_world.add_child(lantern_glass)
	for bar in [-1.0, 1.0]:
		_world.add_child(_mesh_node("LanternGuard%s" % str(bar), _box(Vector3(0.035, 0.28, 0.06)), brass, Vector3(-2.68 + bar * 0.115, 1.58, 1.365)))
	var brass_bell := _mesh_node("WaterClockBell", _flared_cup(0.17, 0.24), brass, Vector3(-2.68, 1.28, 1.79))
	_world.add_child(brass_bell)
	var bell_hanger := _mesh_node("BellStem", _cylinder(0.045, 0.30), dark_stone, Vector3(-2.68, 1.06, 1.79))
	_world.add_child(bell_hanger)
	_world.add_child(_mesh_node("BellBail", _torus(0.058, 0.012), brass, Vector3(-2.68, 1.43, 1.79)))
	_world.add_child(_mesh_node("BellClapper", _cylinder(0.023, 0.12), dark_stone, Vector3(-2.68, 1.18, 1.79)))
	# Front stair treads join the court to the pavilion and anchor the visitor.
	for step in 3:
		var depth := 0.38 + float(step) * 0.34
		var tread := _mesh_node("FrontStep%d" % step, _box(Vector3(2.3 + float(step) * 0.48, 0.14, depth)), limestone if step == 0 else stone, Vector3(0.0, -0.025 - float(step) * 0.045, -1.95 - float(step) * 0.28))
		_world.add_child(tread)
		var nosing := _mesh_node("StepBrassNosing%d" % step, _box(Vector3(2.33 + float(step) * 0.48, 0.035, 0.065)), brass, Vector3(0.0, 0.065 - float(step) * 0.045, -2.1 - float(step) * 0.28 - depth * 0.5))
		_world.add_child(nosing)
	# A real low-angle light throws stage and fountain shadows across the court.
	_apply_time_phase("noon")

func _build_avatar() -> void:
	_avatar = Sprite3D.new()
	_avatar.name = "AuthoredFullBodyAvatar"
	_avatar.centered = true
	_avatar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_avatar.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_avatar.shaded = true
	_avatar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_avatar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_avatar.pixel_size = AVATAR_PIXEL_SIZE
	_avatar.position = Vector3(1.36, (FEET_BASELINE - CANVAS_HEIGHT * 0.5) * AVATAR_PIXEL_SIZE + 0.02, -2.42)
	_world.add_child(_avatar)

func _update_avatar(phase: float, jump_started: float, reduced: bool) -> void:
	if not _avatar_available or _avatar_textures.is_empty() or not is_instance_valid(_avatar):
		return
	var jump_age := phase - jump_started
	var airborne := jump_started >= 0.0 and jump_age >= 0.0 and jump_age < JUMP_DURATION
	var progress := clampf(jump_age / JUMP_DURATION, 0.0, 1.0) if airborne else 0.0
	var texture := _avatar_idle
	var pose_key := "idle"
	var lift := 0.0
	if airborne and _avatar_textures.size() > 1:
		var jump_count := _avatar_textures.size() - 1
		var frame_index := 0 if reduced else clampi(floori(progress * jump_count), 0, jump_count - 1)
		texture = _avatar_textures[frame_index + 1]
		pose_key = "jump_%d" % frame_index
		if not reduced:
			lift = JUMP_LIFT_PIXELS * sin(PI * progress) * WATER_PIXELS_TO_WORLD
	if texture != _avatar.texture:
		_avatar.texture = texture
	_avatar.position.y = (FEET_BASELINE - CANVAS_HEIGHT * 0.5) * AVATAR_PIXEL_SIZE + 0.02 + lift
	_last_avatar_pose = pose_key

func _set_jet_height(index: int, height: float) -> void:
	var jet := _jet_nodes[index]
	jet.scale.y = height
	jet.position.y = 0.74
	for thread in _jet_thread_nodes[index]:
		(thread as MeshInstance3D).scale.y = height
		(thread as MeshInstance3D).position.y = 0.74
	var crest := _jet_mist_nodes[index]
	crest.position.y = 0.74 + height
	var crest_scale := 0.72 + height * 0.25
	crest.scale = Vector3(1.42 * crest_scale, 0.48 * crest_scale, 0.58 * crest_scale)

func _apply_time_phase(phase: String) -> void:
	var safe_phase := phase if DAY_PHASES.has(phase) else "noon"
	_last_phase = safe_phase
	if _key_light == null or _environment == null or _sky_material == null:
		return
	var palettes := {
		"noon": {"ambient": Color("#c6d8cc"), "top": Color("#557f87"), "horizon": Color("#e3bd83"), "energy": 1.12, "fill": 1.0, "well": 0.30, "lantern": 0.08, "hero": 0.18},
		"dusk": {"ambient": Color("#9c8390"), "top": Color("#403b5a"), "horizon": Color("#d17f68"), "energy": 0.82, "fill": 1.35, "well": 0.62, "lantern": 0.48, "hero": 0.82},
		"night": {"ambient": Color("#71809a"), "top": Color("#172849"), "horizon": Color("#596477"), "energy": 0.68, "fill": 2.6, "well": 1.28, "lantern": 0.92, "hero": 2.3},
		"dawn": {"ambient": Color("#b0c0b5"), "top": Color("#647e8c"), "horizon": Color("#edc793"), "energy": 0.91, "fill": 1.08, "well": 0.46, "lantern": 0.18, "hero": 0.35},
	}
	var palette: Dictionary = palettes[safe_phase]
	_environment.ambient_light_color = palette["ambient"]
	_environment.ambient_light_energy = float(palette["energy"])
	_sky_material.sky_top_color = palette["top"]
	_sky_material.sky_horizon_color = palette["horizon"]
	_key_light.light_energy = float(palette["energy"])
	_key_light.light_color = Color("#ffe1ad") if safe_phase in ["noon", "dusk"] else Color("#a9c2ff")
	_key_light.rotation = Vector3(-0.92, -0.43, -0.18) if safe_phase == "noon" else Vector3(-0.62, 0.85, 0.1) if safe_phase in ["dusk", "dawn"] else Vector3(-0.52, -1.1, 0.0)
	_fill_light.light_energy = float(palette["fill"])
	_fill_light.light_color = Color("#ffe0ad") if safe_phase != "night" else Color("#bdd4ff")
	_fountain_light.light_energy = float(palette["well"])
	_fountain_light.light_color = Color("#91ebe0") if safe_phase != "night" else Color("#8bc7e7")
	_lantern_light.light_energy = float(palette["lantern"])
	_hero_light.light_energy = float(palette["hero"])
	_lantern_glass_material.emission_energy_multiplier = 0.32 if safe_phase != "night" else 1.15
	_water_glaze_material.emission_energy_multiplier = 0.12 if safe_phase != "night" else 0.42

func _warn_avatar_once(message: String) -> void:
	if _warned_avatar:
		return
	_warned_avatar = true
	push_warning("FountainJumpView: " + message)

func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _finite_or(value: Variant, fallback: float) -> float:
	return float(value) if _is_finite_number(value) else fallback

func _mat(color: String, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
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

func _flow_surface_mesh(half_width: float, bend: float, phase_offset: float, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ROWS := 12
	for row in ROWS:
		var t0 := float(row) / float(ROWS)
		var t1 := float(row + 1) / float(ROWS)
		var x0 := bend * sin(t0 * PI * 1.35 + phase_offset) * sin(PI * t0 * 0.76)
		var x1 := bend * sin(t1 * PI * 1.35 + phase_offset) * sin(PI * t1 * 0.76)
		var width0 := half_width * (0.16 + 0.84 * pow(1.0 - t0, 0.72))
		var width1 := half_width * (0.16 + 0.84 * pow(1.0 - t1, 0.72))
		var z0 := depth + sin(t0 * TAU + phase_offset) * 0.012
		var z1 := depth + sin(t1 * TAU + phase_offset) * 0.012
		var left0 := Vector3(x0 - width0, t0, z0)
		var right0 := Vector3(x0 + width0, t0, z0)
		var left1 := Vector3(x1 - width1, t1, z1)
		var right1 := Vector3(x1 + width1, t1, z1)
		# Front-facing triangles for the camera at negative Z.
		surface.add_vertex(left0)
		surface.add_vertex(left1)
		surface.add_vertex(right0)
		surface.add_vertex(left1)
		surface.add_vertex(right1)
		surface.add_vertex(right0)
	surface.generate_normals()
	return surface.commit()

func _shell_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 12
	var center := Vector3(0.0, 0.0, -0.025)
	for index in SEGMENTS:
		var a0 := PI + PI * float(index) / float(SEGMENTS)
		var a1 := PI + PI * float(index + 1) / float(SEGMENTS)
		var p0 := Vector3(cos(a0) * 0.15, sin(float(index) / float(SEGMENTS) * PI) * 0.045, sin(a0) * 0.105)
		var p1 := Vector3(cos(a1) * 0.15, sin(float(index + 1) / float(SEGMENTS) * PI) * 0.045, sin(a1) * 0.105)
		surface.add_vertex(center)
		surface.add_vertex(p0)
		surface.add_vertex(p1)
	surface.generate_normals()
	return surface.commit()

func _wave_carve_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 18
	for index in SEGMENTS:
		var t0 := float(index) / float(SEGMENTS)
		var t1 := float(index + 1) / float(SEGMENTS)
		var x0 := lerpf(-0.19, 0.19, t0)
		var x1 := lerpf(-0.19, 0.19, t1)
		var z0 := sin(t0 * TAU) * 0.035
		var z1 := sin(t1 * TAU) * 0.035
		var a := Vector3(x0, 0.0, z0 - 0.012)
		var b := Vector3(x0, 0.0, z0 + 0.012)
		var c := Vector3(x1, 0.0, z1 - 0.012)
		var d := Vector3(x1, 0.0, z1 + 0.012)
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(b)
		surface.add_vertex(c)
		surface.add_vertex(d)
		surface.add_vertex(b)
	surface.generate_normals()
	return surface.commit()

func _flared_cup(top_radius: float, bottom_radius: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = 0.24
	mesh.radial_segments = 24
	return mesh

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	return mesh

func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.35
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh

func _torus(radius: float, thickness: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 40
	mesh.ring_segments = 8
	return mesh
