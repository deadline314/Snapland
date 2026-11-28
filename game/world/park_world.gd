extends Node3D
## Original modular island scenery. All interactions remain data driven.
##
## Districts. A region world (any script that extends this one) runs in one of
## two modes:
## - standalone: it owns the walker, the camera, the sun and the Environment.
##   Tests build regions this way, and so does a region that is not on the
##   island yet.
## - embedded: `embedded_in` is the island world and `district` its region id;
##   DistrictHost sets both and adds it as a child at its site (DistrictSites).
##   It then builds only its own geometry, shares the host's walker, camera,
##   sun, Environment, lamp list, ground-contact lists, occlusion controller
##   and material cache, and leaves movement, lamp choice and the sky to the
##   host. Its interaction points are also listed in the host, in world space.
## For a region script to work in both modes it must:
## 1. read and move the walker with player_spot() and place_player() (its own
##    coordinates in either mode), never player.position;
## 2. end its own "is this floor" test with `or _open_ground(point)`, and
##    answer is_walkable(position) in its own coordinates;
## 3. describe its light as data in _air(phase, island) instead of writing the
##    Environment or the sun;
## 4. keep dressing beyond its floors inside dress_rect(...) and filter
##    scattered pieces with dresses(point), so the island supplies the
##    surroundings when it is embedded.
signal interaction_requested(id: String, label: String)
signal area_changed(label: String)
## The district the walker stands in changed ("welcome" for the island itself).
signal district_changed(region: String)
## A sticker gate opened while playing.
signal gate_opened(region: String)
## The walker raised the camera (the photo key) while free to walk.
signal photo_snapped
const DistrictSites = preload("res://game/world/district_sites.gd")
const DistrictHostScript = preload("res://game/world/district_host.gd")
const DistrictBand = preload("res://game/world/district_band.gd")
const SceneryKit = preload("res://game/world/scenery_kit.gd")
const CoastalCircuit = preload("res://game/world/coastal_circuit.gd")
const CoastalPlay = preload("res://game/world/coastal_play.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const IslandLayout = preload("res://game/world/island_layout.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
## Meta on a Label3D that is a sign's title; it prints in the display face (ART-75).
const SIGN_TITLE := &"sign_title"
const IslandScenery = preload("res://game/world/island_scenery.gd")
const WelcomeFerry = preload("res://game/world/welcome_ferry.gd")
const WATER = preload("res://game/world/water.gdshader")
const WELCOME_BAY_WATER = preload("res://game/world/welcome_bay_water.gdshader")
const WELCOME_DOCK_CENTER := Vector3(0, 0, 21)
const WELCOME_DOCK_SIZE := Vector3(5, 0.3, 13)
const STONE = preload("res://game/world/stone.gdshader")
const WOOD = preload("res://game/world/wood.gdshader")
const GRASS = preload("res://game/world/grass.gdshader")
const PAINTED_FINISH = preload("res://game/world/painted_finish.gdshader")
const SceneStandards = preload("res://game/world/scene_standards.gd")
const SAND = preload("res://game/world/sand.gdshader")
const LIVING_SPRITE = preload("res://game/world/living_sprite.gdshader")
const ComponentAnimationScript = preload("res://game/world/component_animation.gd")
const NpcActivityScript = preload("res://game/world/npc_activity.gd")
const StoryLandmarksScript = preload("res://game/world/story_landmarks.gd")
const OcclusionControllerScript = preload("res://game/world/occlusion_controller.gd")
const WorldAmbienceScript = preload("res://game/world/world_ambience.gd")
const AmbienceProfiles = preload("res://game/world/ambience_profiles.gd")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const ActorShadowSilhouette = preload("res://game/world/actor_shadow_silhouette.gd")
const AvatarHairRig = preload("res://game/world/avatar_hair_rig.gd")
const TimeOfDayScript = preload("res://game/core/time_of_day.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")
const IslandAttractionsScript = preload("res://game/world/island_attractions.gd")
const FieldGamesScript = preload("res://game/world/field/field_games.gd")
const CoastalMaterialShader = preload("res://game/world/coastal_material.gdshader")
const COASTAL_MATERIAL_ATLAS := "res://assets/world/coastal-materials-v1.png"
const IDENTITY_ATLAS_PATH := "res://assets/characters/identities-v3.png"
const IDENTITY_REGIONS := {
	"imp": Rect2i(642,350,295,294),
	"ticket": Rect2i(374,667,188,343),
	"announcer": Rect2i(675,642,207,369),
}
const ZONE_ICONS := ["⚓","✿","☼","✦","⚙","❀","⬡","◉","◇","☆"]
## The final zone's line on its gate and map entry (park.json gives it no theme).
const FINAL_THEME := "幕幕劇團的地底首演：整本相冊就是今晚的節目。"
const CREAM = Color("#edddb8")
const TEAL = Color("#246c6c")
const CORAL = Color("#da705c")
const GOLD = Color("#edbb65")
# Semantic events may share an already authored clip. Dedicated event art
# takes priority; missing shared art retains the original complete fallback.
const AVATAR_SHARED_ACTIONS := {"celebrate": "jump"}
const AVATAR_CAMERA_IDLE_DELAY := 18.0
const AVATAR_CAMERA_IDLE_ACTION := "idle_gesture"
const AVATAR_STOP_ACTION := "settle"
const AVATAR_DEPARTURE_ACTION := "depart"
const AVATAR_PIVOT_ACTION := "pivot"
const AVATAR_DEPTH_PIVOT_ACTION := "pivot_depth"
const AVATAR_PIVOT_SECONDS := 0.12
const AVATAR_DEPTH_PIVOT_SECONDS := 0.15
const AVATAR_PIVOT_HEADINGS := ["back_left", "back", "back_right"]
const AVATAR_DEPTH_PIVOT_HEADINGS := ["front", "front_left", "left", "back_left", "back"]
const AVATAR_PIVOT_WALK_CELS := {
	"right": {3: [3, 4], 4: [4], 5: [5, 6], 7: [7]},
	"left": {3: [3], 4: [4, 5], 5: [5], 7: [7]},
}
const AVATAR_DEPTH_PIVOT_WALK_CELS := {"back": {5: [5, 6], 6: [6]}, "front": {5: [5], 6: [6]}}
const AVATAR_DEPARTURE_TO_WALK_CELS := {
	"front": [0, 1, 2, 3, 6, 7],
	"front_right": [0, 1, 3, 4, 5, 7],
	"right": [0, 2, 6],
	"back_right": [0, 4],
	"back": [0, 1, 2, 3, 4, 5, 6, 7],
	"back_left": [0, 4],
	"left": [0, 3, 4, 5, 7],
	"front_left": [0, 1, 2, 3, 4, 5, 6],
}
# Each listed approach cel was reviewed against its planted stop pose.
const AVATAR_STOP_FROM_WALK_CELS := {
	"front": [0, 2, 3, 4, 5, 6, 7],
	"front_right": [1, 2, 5, 6, 7],
	"right": [0, 1, 2, 3, 4, 6],
	"back_right": [1, 2, 3, 5, 6, 7],
	"back": [0, 1, 2, 3, 4, 5, 6, 7],
	"back_left": [1, 2, 3, 5, 6, 7],
	"left": [0, 1, 3, 4, 5, 7],
	"front_left": [2, 6],
}
var player: CharacterBody3D
var avatar: Sprite3D
var avatar_renderer: RefCounted
var avatar_hair_rig: SubViewport
var avatar_hair_motion_enabled := true
var avatar_motion_rig
var avatar_motion_available := false
var avatar_run_requested := false
var avatar_appearance: Dictionary = {"skin":"warm","species":"human","gender":"neutral","hair":"windswept","hair_color":"ink","face":"curious"}
var avatar_equipped: Dictionary = {"outfit":"outfit-tide","hat":"hat-none"}
var avatar_action := ""
var avatar_action_remaining := 0.0
var avatar_action_elapsed := 0.0
var _avatar_action_on_stop := ""
var _avatar_departure_remaining := 0.0
var _avatar_pivot_remaining := 0.0
var _avatar_pivot_target := ""
var _warned_missing_avatar_actions: Dictionary = {}
var last_avatar_direction := ""
var last_avatar_frame := -1
var last_avatar_action := ""
var last_avatar_source_action := ""
var _avatar_idle_started_at := 0.0
var _avatar_camera_idle_available := true
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var points: Array[Dictionary] = []
var district_labels: Array[Label3D] = []
var local_sign_labels: Array[Label3D] = []
var daily_pick_ribbons: Array[Label3D] = []
var component_motion: Node
var npc_activity: Node
var story_landmarks: Node3D
var occlusion_controller: Node
var ambience: Node3D
var pending_npc_interaction: Dictionary = {}
var _last_label_font: Font
var lamps: Array[Light3D] = []
const ACTIVE_LAMP_LIMIT := 8
const SHADOW_LAMP_LIMIT := 2
const RenderQuality = preload("res://game/world/render_quality.gd")
## Lamp budgets for the current picture quality; never above the limits.
var active_lamp_budget := ACTIVE_LAMP_LIMIT
var shadow_lamp_budget := SHADOW_LAMP_LIMIT
var render_quality := ""
const LAMP_SELECTION_INTERVAL := 0.4
var active_lamp_indices: Array[int] = []
var shadow_lamp_indices: Array[int] = []
var lamp_candidate_distances: Array[float] = []
var lamp_selection_elapsed := 0.0
var lamp_selection_player_position := Vector3(INF, INF, INF)
var lamp_energy_for_phase := 0.0
var _wayfinding_trim: StandardMaterial3D
var sprite_frames: Array[Texture2D] = []
var material_cache: Dictionary = {}
var coastal_atlas: Texture2D
var coastal_atlas_warning_shown := false
var shoreline_rock_count := 0
var character_frames: Dictionary = {}
var character_sprites: Array[Dictionary] = []
var sprite_ground_anchors: Array[Dictionary] = []
const SPRITE_FOOT_GUARD_PIXELS := 2.0
var avatar_ground_anchor: Node3D
var avatar_contact_shadow: MeshInstance3D
var identity_atlas: Texture2D
var identity_textures: Dictionary = {}
var identity_warnings: Dictionary = {}
var bubble_material: StandardMaterial3D
var foliage_textures: Dictionary = {}
var foliage_atlas_loaded := false
var foliage_warnings: Dictionary = {}
var foliage_materials: Array[ShaderMaterial] = []
var foliage_shadow_casters: Array[ActorShadowSilhouette] = []
var _foliage_contact_transforms: Array[Transform3D] = []
var facing := "front"
## Phase span of one walk cycle. Real travel per cycle comes from the measured artwork
## (walk_stride_for), so the planted foot keeps pace with the body instead of gliding.
const WALK_STRIDE_DISTANCE := 2.8
const WALK_STRIDE_CALIBRATION_PATH := "res://assets/characters/walk-stride-calibration.json"
## Used only if the calibration file is missing or invalid: the measured side stride, rounded.
const FALLBACK_WALK_STRIDE := 1.0
const WALK_STRIDE_LIMITS := Vector2(0.3, 3.0)
const WALK_DIRECTION_HYSTERESIS := deg_to_rad(5.0)
const WALK_DISTANCE_EPSILON := 0.0005
const CAMERA_OFFSET := Vector3(3.5,16.5,25.0)
const FOLLOW_CADENCE_TICKS := 30
const FOLLOW_INTERPOLATION_START_RATIO := 1.50
const FOLLOW_INTERPOLATION_STOP_RATIO := 1.23
const AVATAR_WALK_SPEED := 0.55
## Default brisk pace. The authored art is a walk (about 1 world unit per two steps), so
## 1.5 keeps it near three steps a second; faster would read as a frantic walk, not a run.
const AVATAR_RUN_SPEED := 1.5
const AVATAR_ACCELERATION_SECONDS := 0.16
const AVATAR_EXTERNAL_REPOSITION_THRESHOLD := 0.20
var avatar_motion_speed_limit := AVATAR_WALK_SPEED
var _avatar_careful_braking := false
var avatar_last_physics_position := Vector3.ZERO
var avatar_last_physics_position_valid := false
var allow_follow_interpolation := false
var _follow_interpolation_active := false
var _follow_previous_root_mode := Node.PHYSICS_INTERPOLATION_MODE_INHERIT
var _follow_sample_tick := -1
var _follow_sample_frame := 0
var walk_distance_phase := 0.0
var walk_strides: Dictionary = {}
var avatar_is_walking := false
var mesh_count := 0
var blocked := false
var npc_dialogue_hold := false
var npc_activity_paused := false
var reduced_motion := false
var night := false
var time := 0.0
var current_area := ""
var nearest: Dictionary = {}
var _visible_interaction_marker: Label3D
var fountain_water: ShaderMaterial
var sea_material: ShaderMaterial
var welcome_sea_material: ShaderMaterial
var ferry_window_glow: StandardMaterial3D
var active_time_phase := TimeOfDayScript.DEFAULT_PHASE
var contact_shadow_material: StandardMaterial3D
var contact_shadows: Array[Dictionary] = []
var actor_shadow_proxies: Array[Dictionary] = []
var coastal_rotors: Array[Node3D] = []
var coastal_play: Node3D
var island_attractions: Node
## Instant map games and toys; null in regions that have none.
var field_games: Node3D
## Raises only the avatar's picture (a hop); the body, shadow and footing stay put.
var avatar_visual_lift := 0.0
## Embedded mode (see the district notes at the top of this file).
var embedded_in: Node3D
var district := ""
var district_ready := false
## Set by the host to spread an embedded build over frames (see build_pause).
var build_in_steps := false
var build_steps := 0
var longest_step_usec := 0
var _step_started_usec := 0
## An embedded build finished (it may span several frames).
signal district_built
## The island world's keeper of embedded districts; null in a region world.
var district_host: Node
## The sky, sun and air this world wants in the current phase (see environment_target).
var air_target: Dictionary = {}
var _air_blend: Dictionary = {}
var _site: Dictionary = {}
var _gate_leaves: Dictionary = {}
var _gate_leaf_mesh: ArrayMesh

func _ready() -> void:
	if embedded_in != null:
		_ready_embedded()
		return
	active_lamp_indices.resize(ACTIVE_LAMP_LIMIT)
	lamp_candidate_distances.resize(ACTIVE_LAMP_LIMIT)
	shadow_lamp_indices.resize(SHADOW_LAMP_LIMIT)
	for index in range(ACTIVE_LAMP_LIMIT):
		active_lamp_indices[index] = -1
		lamp_candidate_distances[index] = INF
	for index in range(SHADOW_LAMP_LIMIT):
		shadow_lamp_indices[index] = -1
	if ResourceLoader.exists(COASTAL_MATERIAL_ATLAS):
		coastal_atlas = load(COASTAL_MATERIAL_ATLAS) as Texture2D
	else:
		push_warning("Coastal material atlas is missing; using simple fallback albedos.")
		coastal_atlas_warning_shown = true
	component_motion=ComponentAnimationScript.new()
	component_motion.name="ComponentAnimation"
	add_child(component_motion)
	occlusion_controller=OcclusionControllerScript.new()
	occlusion_controller.name="OcclusionController"
	add_child(occlusion_controller)
	_load_foliage_atlas()
	_load_identity_atlas()
	_build_lighting()
	await _build_region_geometry()
	_build_player()
	_build_region_activities()
	field_games = FieldGamesScript.attach(self)
	_build_fitting_batches()
	_build_camera()
	_update_sprite_grounding()
	occlusion_controller.configure(player,camera)
	occlusion_controller.set_reveal_visual(avatar)
	_register_npc_activity()
	interaction_requested.connect(_on_interaction_requested)
	component_motion.finish_registration()
	ambience = WorldAmbienceScript.new()
	ambience.name = "WorldAmbience"
	add_child(ambience)
	ambience.configure(self, _ambience_profile())
	print("[park_world] scenery meshes: %d, nodes: %d" % [mesh_count, find_children("*", "Node", true, false).size()+1])
	set_time_of_day(TimeOfDayScript.DEFAULT_PHASE)


func _build_region_geometry() -> void:
	_batch_fittings = true
	_build_land()
	_build_shoreline()
	_build_dock()
	_build_plaza()
	_build_avenue()
	_build_gates()
	_build_wayfinding()
	CoastalCircuit.build(self)
	_build_foliage_contact_shadows()
	story_landmarks = StoryLandmarksScript.new()
	add_child(story_landmarks)
	story_landmarks.configure(self)

## Cloud shade, air motes and small animals for this region; override to
## supply a custom table instead of the shared one keyed by region.
func _ambience_profile() -> Dictionary:
	return AmbienceProfiles.profile(AmbienceProfiles.region_for(self))

# --- Districts -------------------------------------------------------------

## State an embedded district takes from its host by reference instead of
## building its own.
const SHARED_WITH_HOST := [
	"player", "avatar", "avatar_renderer", "avatar_contact_shadow", "camera", "sun", "environment",
	"occlusion_controller", "lamps", "material_cache", "coastal_atlas", "contact_shadow_material",
	"foliage_textures", "foliage_atlas_loaded", "foliage_materials", "foliage_shadow_casters",
	"sprite_ground_anchors", "contact_shadows", "actor_shadow_proxies",
	"identity_atlas", "identity_textures", "character_frames", "avatar_appearance", "avatar_equipped",
]

func _ready_embedded() -> void:
	_step_started_usec = Time.get_ticks_usec()
	_site = DistrictSites.SITES[district]
	for shared: String in SHARED_WITH_HOST:
		set(shared, embedded_in.get(shared))
	component_motion = ComponentAnimationScript.new()
	component_motion.name = "ComponentAnimation"
	add_child(component_motion)
	await _build_region_geometry()
	await build_pause()
	DistrictBand.new().build(self)
	await build_pause()
	_build_fitting_batches()
	await build_pause()
	_register_npc_activity()
	# Its instant games and toys join before its markers start to bob.
	if is_instance_valid(embedded_in.field_games): embedded_in.field_games.add_district(self)
	component_motion.finish_registration()
	# The island already shades the ground with clouds; a district adds only its own air.
	var air := _ambience_profile().duplicate()
	air["clouds"] = 0.0
	ambience = WorldAmbienceScript.new()
	ambience.name = "WorldAmbience"
	add_child(ambience)
	ambience.configure(self, air)
	_update_npc_name_labels(true)
	if build_in_steps: longest_step_usec = maxi(longest_step_usec, Time.get_ticks_usec() - _step_started_usec)
	district_ready = true
	district_built.emit()

## Embedded and built over several frames (see DistrictHost): wait for the next
## frame so no single frame does too much. Otherwise returns at once.
func build_pause() -> Variant:
	if embedded_in == null or not build_in_steps or not is_inside_tree(): return null
	var now := Time.get_ticks_usec()
	longest_step_usec = maxi(longest_step_usec, now - _step_started_usec)
	build_steps += 1
	await get_tree().process_frame
	_step_started_usec = Time.get_ticks_usec()
	return null

## The world that owns the walker and the camera: the host, or this world itself.
func _host() -> Node3D:
	return embedded_in if embedded_in != null else self

## The walker's position in this world's own coordinates.
func player_spot() -> Vector3:
	return to_local(player.global_position) if embedded_in != null else player.position

## Stand the walker at a spot given in this world's own coordinates and let the
## camera and pose catch up with the move.
func place_player(spot: Vector3) -> void:
	_set_player_spot(spot)
	player.velocity = Vector3.ZERO
	_host()._sync_external_avatar_reposition()

## Move the walker only; movement limits use this every tick.
func _set_player_spot(spot: Vector3) -> void:
	if embedded_in != null: player.global_position = to_global(spot)
	else: player.position = spot

## Drop any pose or stride in progress and frame the walker where it now stands.
func settle_avatar() -> void:
	avatar_is_walking = false
	walk_distance_phase = 0.0
	avatar_action = ""
	avatar_action_remaining = 0.0
	avatar_action_elapsed = 0.0
	if is_instance_valid(avatar_hair_rig): avatar_hair_rig.reset_motion()
	if is_instance_valid(camera):
		camera.position = player.position + CAMERA_OFFSET
		camera.look_at(player.position + Vector3(0, 1, 0))
	_refresh_avatar_texture(0)
	_update_sprite_grounding()

## Embedded only. True where a spot outside this district's own floors can still
## be stood on: its approach strip once its gate is open, and anywhere beyond
## its claim that the island allows.
func _open_ground(spot: Vector2) -> bool:
	if embedded_in == null: return false
	if (_site.approach as Rect2).has_point(spot): return embedded_in.district_host.gate_is_open(district)
	if (_site.claim as Rect2).has_point(spot): return false
	return embedded_in.island_walkable(spot + Vector2(position.x, position.z))

## True where this world should place a scattered piece of dressing. Embedded,
## pieces outside the claim thin out across the transition band and keep to
## open island lawn.
func dresses(spot: Vector2) -> bool:
	if embedded_in == null or (_site.claim as Rect2).has_point(spot): return true
	var at := spot + Vector2(position.x, position.z)
	return DistrictSites.ground_weight(district, at) > DistrictSites.chance(at) and DistrictSites.holds(district, at) and embedded_in.band_site_clear(at)

## How far this world's own ground reaches: `authored` standalone, the claim embedded.
func dress_rect(authored: Rect2) -> Rect2:
	return authored if embedded_in == null else authored.intersection(_site.claim)

## True where fixed dressing belongs: anywhere standalone, inside the claim embedded.
func in_dress_reach(spot: Vector2) -> bool:
	return embedded_in == null or (_site.claim as Rect2).has_point(spot)

## Ground height at a spot in this district's own coordinates, for the host.
func district_ground_y(spot: Vector3) -> float:
	if (_site.approach as Rect2).has_point(Vector2(spot.x, spot.z)): return float(_site.approach_y)
	return ground_surface_y(spot)

## True on island ground a walker may stand on, ignoring districts.
func island_walkable(spot: Vector2) -> bool:
	return IslandLayout.DOCK_WALK.has_point(spot) or (IslandShape.contains(spot, IslandShape.WALK_MARGIN) and not IslandLayout.in_pond(spot))

## True on open island lawn where a district may stand a transition-band prop.
func band_site_clear(spot: Vector2) -> bool:
	return IslandShape.on_lawn(spot, IslandLayout.TREE_SHORE_MARGIN) and not IslandLayout.on_path(spot, IslandLayout.TREE_PATH_MARGIN) \
		and not IslandLayout.keeps_clear(spot) and not DistrictSites.claims(spot)

const AIR_KEYS := ["sky", "fog", "ambient", "ambient_energy", "sun", "sun_energy", "glow", "saturation"]
const AIR_GLOW := {"dawn": 0.025, "noon": 0.025, "dusk": 0.045, "night": 0.08}

## What this world wants the shared sky, sun and air to be in `phase`: the
## island's daylight with this region's own changes (_air) laid over it.
func environment_target(phase: String) -> Dictionary:
	var profile: Dictionary = TimeOfDayScript.phase_for_id(phase)
	var sky: Color = profile.sky_color
	var ambient: Color = profile.ambient_color
	var target := {
		"sky": sky, "fog": sky.lerp(ambient, 0.28), "ambient": ambient, "ambient_energy": float(profile.ambient_energy) * 0.58,
		"sun": profile.key_color, "sun_energy": float(profile.key_energy), "glow": float(AIR_GLOW[phase]), "saturation": 1.08,
	}
	target.merge(_air(phase, target), true)
	return target

## A region's own light for `phase`: any of AIR_KEYS, given the island's values.
func _air(_phase: String, _island: Dictionary) -> Dictionary:
	return {}

func _write_air(target: Dictionary) -> void:
	var cover := float(event_air.get("amount", 0.0))
	var sky: Color = target.sky
	var fog: Color = target.fog
	var ambient: Color = target.ambient
	var sun_color: Color = target.sun
	if cover > 0.0:
		sky = sky.lerp(event_air.sky, cover)
		fog = fog.lerp(event_air.sky, cover)
		ambient = ambient.lerp(event_air.ambient, cover)
		sun_color = sun_color.lerp(event_air.ambient, cover * 0.5)
	environment.background_color = sky
	environment.fog_light_color = fog
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = float(target.ambient_energy) * lerpf(1.0, float(event_air.get("ambient_scale", 1.0)), cover) + float(event_air.get("flash", 0.0))
	environment.glow_intensity = target.glow
	environment.adjustment_saturation = float(target.saturation) * lerpf(1.0, float(event_air.get("saturation_scale", 1.0)), cover)
	sun.light_color = sun_color
	sun.light_energy = float(target.sun_energy) * lerpf(1.0, float(event_air.get("sun_scale", 1.0)), cover)

## An island event's sky laid over the blended air (see IslandEvents): rain
## cloud ("amount" toward "sky"/"ambient", sun and light scaled) or a firework
## "flash" of ambient light. Empty leaves the phase's own air untouched.
var event_air: Dictionary = {}

func set_event_air(air: Dictionary) -> void:
	event_air = air
	blend_air()

## Repaint the shared sky and sun from this world's target and whatever share of
## each district's target reaches the walker.
func blend_air() -> void:
	if air_target.is_empty(): return
	for key: String in AIR_KEYS:
		_air_blend[key] = air_target[key]
	if is_instance_valid(district_host): district_host.blend_air(_air_blend, AIR_KEYS)
	_write_air(_air_blend)

## Lawn tint toward every district, and holes in the lawn and beach where a
## built district sinks its own water below ground.
func bind_district_ground(built: Array) -> void:
	var holes: Array[Vector4] = []
	for region: String in built:
		for hole: Rect2 in DistrictSites.SITES[region].cutouts:
			var corner := DistrictSites.to_world(region, Vector3(hole.position.x, 0, hole.position.y))
			holes.append(Vector4(corner.x, corner.z, corner.x + hole.size.x, corner.z + hole.size.y))
	var count := mini(holes.size(), 8)
	holes.resize(8)
	for key: String in ["welcome-lawn", "welcome-beach"]:
		var ground := material_cache.get(key) as ShaderMaterial
		if ground == null: continue
		ground.set_shader_parameter("cutouts", holes)
		ground.set_shader_parameter("cutout_count", count)
	var lawn := material_cache.get("welcome-lawn") as ShaderMaterial
	if lawn == null: return
	lawn.set_shader_parameter("district_tint", IslandShape.district_tint())
	lawn.set_shader_parameter("tint_origin", IslandShape.sdf_origin())
	lawn.set_shader_parameter("tint_inverse_size", IslandShape.sdf_inverse_size())
	lawn.set_shader_parameter("district_blend", true)

## Share of the light and air at the walker: one entry per district plus the
## island's own under "welcome"; the shares sum to 1.
func district_weights() -> Dictionary:
	var shares := {"welcome": 1.0}
	if is_instance_valid(district_host):
		shares.merge(district_host.weights)
		shares["welcome"] = district_host.island_share()
	return shares

## Fast travel home sets the walker down on the plaza's south edge, facing the fountain.
const PLAZA_ARRIVAL := Vector3(0, 0.3, 6.5)

## Where fast travel sets the walker down for `region`, in world space; the
## district is built first if needed. Vector3.INF when it cannot be reached.
func arrival_point(region: String) -> Vector3:
	if region == "welcome": return PLAZA_ARRIVAL
	if not is_instance_valid(district_host): return Vector3.INF
	# A district still being built is finished within a few frames; set the walker down meanwhile.
	if not district_host.is_building(region) and district_host.ensure(region) == null: return Vector3.INF
	return DistrictSites.arrival(region)

## The built district for `region`, or this world for "welcome" and for a
## region world that stands alone.
func region_world(region: String) -> Node3D:
	var node: Node3D = district_host.built(region) if is_instance_valid(district_host) else null
	return node if node != null else self

## Stand the walker where a save left it: at `saved` while that is still ground
## it may stand on, otherwise at `region`'s arrival point. A save from before
## the island was continuous has no position and lands at the arrival point.
func restore_walker(saved: Vector3, region: String) -> void:
	if not is_instance_valid(district_host): return
	var spot := Vector3.INF
	if saved.is_finite() and saved.y > -1.0 and saved.y < 6.0:
		district_host.ensure(DistrictSites.ruling(Vector2(saved.x, saved.z)))
		if is_walkable(saved): spot = saved
	if not spot.is_finite() and region != "welcome": spot = arrival_point(region)
	if spot.is_finite():
		place_player(spot + Vector3(0, 0.05, 0))
		settle_avatar()
	refresh_standing()

## Work out again which district the walker stands in, after it was moved.
func refresh_standing() -> void:
	if is_instance_valid(district_host): district_host.track(player.position, 0.0)

## The district the walker stands in, or "welcome".
func standing_region() -> String:
	return district_host.standing if is_instance_valid(district_host) else "welcome"

## Hand the sticker count to the gates (see DistrictHost.set_sticker_count).
func set_sticker_count(count: int) -> void:
	if is_instance_valid(district_host): district_host.set_sticker_count(count)

func _build_region_activities() -> void:
	district_host = DistrictHostScript.new()
	district_host.name = "DistrictHost"
	add_child(district_host)
	district_host.configure(self)
	bind_district_ground([])
	coastal_play=CoastalPlay.new()
	coastal_play.name="CoastalFreePlay"
	add_child(coastal_play)
	coastal_play.configure(self)
	island_attractions = IslandAttractionsScript.new()
	island_attractions.name = "IslandAttractions"
	add_child(island_attractions)
	island_attractions.configure(self, player, Vector3(-6.7, 0.26, 11.2))


func _exit_tree() -> void:
	if embedded_in != null:
		if is_instance_valid(npc_activity): npc_activity.release()
		return
	_stop_follow_interpolation()
	if is_instance_valid(island_attractions):
		island_attractions.end_ride()
	if is_instance_valid(npc_activity):
		npc_activity.release()
	if is_instance_valid(occlusion_controller):
		occlusion_controller.release()

func _load_foliage_atlas() -> void:
	const ATLAS_PATH := "res://assets/world/tidal-foliage-v2.png"
	const REGIONS_PATH := "res://assets/world/foliage-regions.json"
	if not ResourceLoader.exists(ATLAS_PATH):
		_warn_foliage_once("atlas", "World foliage resource %s is unavailable; using procedural geometry fallback" % ATLAS_PATH)
		return
	var atlas := load(ATLAS_PATH) as Texture2D
	if atlas == null:
		_warn_foliage_once("atlas", "World foliage resource %s did not load as a Texture2D; using procedural geometry fallback" % ATLAS_PATH)
		return
	if not FileAccess.file_exists(REGIONS_PATH):
		_warn_foliage_once("regions", "World foliage region file %s is missing; using procedural geometry fallback" % REGIONS_PATH)
		return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGIONS_PATH))
	if parsed is not Dictionary:
		_warn_foliage_once("regions", "World foliage region file %s is invalid; using procedural geometry fallback" % REGIONS_PATH)
		return
	foliage_atlas_loaded=true
	for key in parsed:
		var rect: Variant=parsed[key]
		if rect is not Array or rect.size()!=4:
			_warn_foliage_once(str(key), "World foliage item '%s' in %s must contain x, y, width and height" % [key,REGIONS_PATH])
			continue
		var numeric := true
		for value in rect:
			if typeof(value)!=TYPE_INT and typeof(value)!=TYPE_FLOAT:
				numeric=false
				break
		if not numeric:
			_warn_foliage_once(str(key), "World foliage item '%s' in %s has nonnumeric rectangle values" % [key,REGIONS_PATH])
			continue
		var x := float(rect[0])
		var y := float(rect[1])
		var width := float(rect[2])
		var height := float(rect[3])
		if not is_finite(x) or not is_finite(y) or not is_finite(width) or not is_finite(height) or x<0.0 or y<0.0 or width<=0.0 or height<=0.0 or x+width>atlas.get_width() or y+height>atlas.get_height():
			_warn_foliage_once(str(key), "World foliage item '%s' rectangle %s exceeds %s bounds (%d x %d)" % [key,str(rect),ATLAS_PATH,atlas.get_width(),atlas.get_height()])
			continue
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(x,y,width,height)
		foliage_textures[str(key)] = texture
	if foliage_textures.is_empty():
		foliage_atlas_loaded=false
		_warn_foliage_once("regions", "World foliage file %s has no valid atlas regions; using procedural geometry fallback" % REGIONS_PATH)

func _warn_foliage_once(key: String, message: String) -> void:
	if foliage_warnings.has(key): return
	foliage_warnings[key]=true
	push_warning(message)

func _foliage_has(key: String) -> bool:
	if foliage_textures.has(key): return true
	if foliage_atlas_loaded:
		_warn_foliage_once(key, "World foliage item '%s' is absent from %s; using procedural geometry fallback for this item" % [key,"res://assets/world/foliage-regions.json"])
	return false

func _build_lighting() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9bc9d9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d4c7aa")
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Keep the phase key-light contract, but reduce the final scene exposure so
	# warm albedo differences survive instead of washing out on sunlit surfaces.
	environment.tonemap_exposure = 0.84
	environment.glow_enabled = true
	environment.glow_intensity = 0.10
	# A light grade after tonemapping: sprites and scenery share it, so the
	# picture gains depth without the pixel art drifting from the world palette.
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08
	environment.ssao_enabled = true
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 0.65
	environment.ssao_power = 1.2
	environment.fog_enabled = true
	environment.fog_density = 0.0007
	environment.fog_light_color = Color("#9bc9d9")
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -145, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_color = Color("#f4e4c3")
	sun.light_energy = 1.08
	sun.light_cull_mask &= ~SCENERY_RENDER_LAYER
	add_child(sun)
	contact_shadow_material = _make_contact_shadow_material()

func _make_contact_shadow_material() -> StandardMaterial3D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(16.0, 16.0)) / 16.0
			var edge := clampf(1.0 - p.length(), 0.0, 1.0)
			image.set_pixel(x, y, Color(0.12, 0.19, 0.20, edge * edge * 0.34))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material_cache["contact_shadow"] = material
	return material

func _add_contact_shadow(anchor: Node3D, local_ground_offset: Vector3, dimensions: Vector2) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	shadow.mesh = plane
	shadow.material_override = contact_shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = local_ground_offset
	anchor.add_child(shadow)
	contact_shadows.append({"node": shadow, "anchor": anchor, "ground_offset": local_ground_offset})
	mesh_count += 1
	return shadow

func _add_actor_shadow_proxy(actor: Node3D, role: String, ground_offset_y: float, source_sprite: Sprite3D) -> Node3D:
	# Keep collision-free coarse volumes as a safe fallback for unsupported
	# texture layouts. Normally only the final composed alpha silhouette casts.
	var proportions := {
		"hero": Vector3(0.30, 1.20, 0.32),
		"ticket": Vector3(0.25, 1.05, 0.28),
		"imp": Vector3(0.34, 0.95, 0.37),
		"announcer": Vector3(0.29, 1.12, 0.31),
	}
	var shape: Vector3 = proportions.get(role, proportions["hero"])
	var proxy := Node3D.new()
	proxy.name = "%sShadowOnlyProxy" % role.capitalize()
	proxy.position.y = ground_offset_y
	actor.add_child(proxy)
	var shadow_material := _mat(Color("#ffffff"))
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = shape.x
	torso_mesh.height = shape.y
	var torso := MeshInstance3D.new()
	torso.name = "TorsoShadowVolume"
	torso.mesh = torso_mesh
	torso.position.y = shape.y * 0.5
	torso.material_override = shadow_material
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = shape.z
	head_mesh.height = shape.z * 2.0
	var head := MeshInstance3D.new()
	head.name = "HeadShadowVolume"
	head.mesh = head_mesh
	head.position.y = shape.y + shape.z * 0.55
	head.material_override = shadow_material
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.add_child(head)
	var silhouette := ActorShadowSilhouette.new()
	silhouette.upright = true
	proxy.add_child(silhouette)
	var fallback: Array[GeometryInstance3D] = [torso, head]
	silhouette.configure(source_sprite, camera, fallback)
	actor_shadow_proxies.append({"node": proxy, "actor": actor, "role": role, "silhouette": silhouette})
	mesh_count += 3
	return proxy

static func sprite_ground_anchor_y(
	ground_y: float,
	parent_world_y: float,
	sprite_local_y: float,
	feet_row: float,
	canvas_height: float,
	pixel_size: float,
	camera_up_y: float
) -> float:
	var feet_from_center := (feet_row - canvas_height * 0.5) * pixel_size
	return ground_y - parent_world_y - sprite_local_y + feet_from_center * camera_up_y

func ground_surface_y(world_position: Vector3) -> float:
	if is_instance_valid(district_host):
		var rules: Node3D = district_host.ruling(world_position)
		if rules != null: return rules.district_ground_y(rules.to_local(world_position))
	return _ground_surface_y(world_position)

static func _ground_surface_y(world_position: Vector3) -> float:
	# Match the tops of the raised boardwalk, the courts and the walkways; open
	# ground is lawn, or sand where the shore and the beaches leave no grass.
	if world_position.z >= 8.4 and world_position.z <= 11.6 and world_position.x >= -5.7 and world_position.x <= -3.2:
		return lerpf(0.26,0.18,clampf(inverse_lerp(-5.7,-4.2,world_position.x),0.0,1.0))
	if world_position.x >= -13.5 and world_position.x <= -5.7 and world_position.z >= 7.2 and world_position.z <= 13.0:
		return 0.26
	var spot := Vector2(world_position.x,world_position.z)
	var court := IslandLayout.district_surface_y(spot)
	if court >= 0.0:
		return court
	if absf(world_position.x) <= 2.46 and world_position.z >= 14.825 and world_position.z <= 26.975:
		return 0.22
	if IslandLayout.PLAZA.has_point(spot) or IslandLayout.STEM.has_point(spot) or IslandLayout.on_path(spot):
		return IslandLayout.PATH_TOP_Y
	return IslandLayout.LAWN_Y if IslandShape.on_lawn(spot) else IslandLayout.BEACH_TOP_Y

func coast_description(id: String) -> Dictionary:
	return CoastalCircuit.description(id)

func _register_sprite_ground_anchor(sprite: Sprite3D, anchor: Node3D, parent: Node3D, ground_y: float, feet_row: float, canvas_height: float) -> void:
	# Preserve the bottom pixel's entire area, including the one-pixel variation
	# between authored poses. The guard is less than a centimetre in world space.
	feet_row += SPRITE_FOOT_GUARD_PIXELS
	# NPC gait grounding may request a small extra vertical clearance when the
	# billboard's projected foot silhouette straddles a terrain-height boundary.
	sprite.set_meta("npc_world_ground_anchor_managed",true)
	sprite.set_meta("npc_foot_clearance_y",0.0)
	sprite_ground_anchors.append({
		"sprite": sprite,
		"anchor": anchor,
		"parent": parent,
		"ground_y": ground_y,
		"feet_row": feet_row,
		"canvas_height": canvas_height,
	})

func _update_sprite_grounding() -> void:
	if embedded_in != null:
		embedded_in._update_sprite_grounding()
		return
	if not is_instance_valid(camera):
		return
	var camera_up_y := camera.global_basis.y.y
	for record in sprite_ground_anchors:
		var sprite := record.get("sprite") as Sprite3D
		var anchor := record.get("anchor") as Node3D
		var parent := record.get("parent") as Node3D
		if not is_instance_valid(sprite) or not is_instance_valid(anchor) or not is_instance_valid(parent):
			continue
		var ground_y := float(record.ground_y)
		if parent == player:
			ground_y = ground_surface_y(player.global_position) + avatar_visual_lift
		var desired_y := sprite_ground_anchor_y(
			ground_y,
			parent.global_position.y,
			sprite.position.y,
			float(record.feet_row),
			float(record.canvas_height),
			sprite.pixel_size,
			camera_up_y
		)
		desired_y += float(sprite.get_meta("npc_foot_clearance_y",0.0))
		if absf(anchor.position.y - desired_y) > 0.0005:
			anchor.position.y = desired_y
	for index in range(contact_shadows.size()):
		var record: Dictionary = contact_shadows[index]
		var shadow := record.get("node") as Node3D
		var anchor := record.get("anchor") as Node3D
		if not is_instance_valid(shadow) or not is_instance_valid(anchor): continue
		var shadow_y := ground_surface_y(anchor.global_position) - anchor.global_position.y + 0.005
		if absf(shadow.position.y - shadow_y) > 0.0005:
			shadow.position.y = shadow_y
		var ground_offset: Vector3 = record.get("ground_offset", Vector3.ZERO)
		ground_offset.y = shadow_y
		record["ground_offset"] = ground_offset
		contact_shadows[index] = record
	for proxy_record in actor_shadow_proxies:
		var proxy := proxy_record.get("node") as Node3D
		var actor := proxy_record.get("actor") as Node3D
		if not is_instance_valid(proxy) or not is_instance_valid(actor): continue
		var proxy_y := 0.0 if actor == player and is_riding() else ground_surface_y(actor.global_position) - actor.global_position.y
		if not is_equal_approx(proxy.position.y, proxy_y):
			proxy.position.y = proxy_y
		var silhouette = proxy_record.get("silhouette")
		if is_instance_valid(silhouette):
			if silhouette.scene_camera != camera:
				silhouette.scene_camera = camera
			silhouette.refresh()

func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(true), str(emissive)]
	if material_cache.has(key): return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.65
	material_cache[key] = material
	return material

func _wood_material(color: Color) -> ShaderMaterial:
	var key := "wood:" + color.to_html(true)
	if material_cache.has(key): return material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = WOOD
	material.set_shader_parameter("base_color",color)
	material_cache[key]=material
	return material

func _stone_finish(color: Color) -> ShaderMaterial:
	var key := "stone:" + color.to_html(true)
	if material_cache.has(key): return material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = STONE
	material.set_shader_parameter("base_color", color)
	material_cache[key] = material
	return material

func _coastal_surface(tile_index: int, world_tile_size: float, tint := Color.WHITE) -> Material:
	if coastal_atlas == null:
		if not coastal_atlas_warning_shown:
			push_warning("Coastal material atlas failed to load; using simple fallback albedos.")
			coastal_atlas_warning_shown = true
		var fallback_tints: Array[Color] = [Color("#958064"),Color("#9b784f"),Color("#385d60"),Color("#a45c48"),Color("#ac9875"),Color("#417e82"),Color("#b6a57d"),Color("#8c774f")]
		var fallback_color: Color = tint if tint != Color.WHITE else fallback_tints[clampi(tile_index,0,7)]
		if tile_index == 0 or tile_index == 4:
			return _stone_finish(fallback_color)
		if tile_index == 1 or tile_index == 2 or tile_index == 3 or tile_index == 6:
			return _wood_material(fallback_color)
		return _mat(fallback_color)
	var key := "coastal:%d:%.2f:%s" % [tile_index,world_tile_size,tint.to_html(true)]
	if material_cache.has(key): return material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = CoastalMaterialShader
	material.set_shader_parameter("atlas_texture",coastal_atlas)
	material.set_shader_parameter("tile_index",clampi(tile_index,0,7))
	material.set_shader_parameter("world_tile_size",maxf(0.1,world_tile_size))
	material.set_shader_parameter("tint",tint)
	material_cache[key] = material
	return material

func _set_registered_surface(target: GeometryInstance3D, surface_material: Material) -> void:
	if is_instance_valid(occlusion_controller) and occlusion_controller.replace_registered_surface(target, surface_material):
		return
	target.material_override = surface_material


func _mesh(mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	if is_instance_valid(occlusion_controller):
		occlusion_controller.register_geometry(instance,material)
	mesh_count += 1
	return instance

func _multi_mesh(mesh: Mesh, pos: Vector3, transforms: Array[Transform3D], colors: Array[Color], material: Material) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=mesh
	multi.instance_count=transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_color(i,colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh=multi
	instance.position=pos
	instance.material_override=material
	add_child(instance)
	if is_instance_valid(occlusion_controller):
		occlusion_controller.register_geometry(instance,material)
	mesh_count += 1
	return instance

## Colours from SceneryKit.Sculpt and the district batches arrive already linear.
## `srgb` is for batches fed swatch colours as written (the welcome island's
## leaves, flowers, stones and trims): the material converts them, so they keep
## their painted tone instead of washing out pale (ART-81).
func _vertex_color_material(cache_key: String, roughness := 0.9, srgb := false) -> StandardMaterial3D:
	var key := cache_key + (":srgb" if srgb else "")
	if material_cache.has(key): return material_cache[key]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=srgb
	material.roughness=roughness
	material_cache[key]=material
	return material

## Colour for a primitive of this size: faces large enough to read as a blank
## block get the painted surface instead of one flat colour.
func _finish(color: Color, size: Vector3) -> Material:
	if not SceneStandards.shows_flat_face(size):
		return _mat(color)
	var key := "painted:" + color.to_html(true)
	if material_cache.has(key): return material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = PAINTED_FINISH
	material.set_shader_parameter("tint", color)
	material_cache[key] = material
	return material

func _box(pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, pos, _finish(color, size))
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		instance.add_child(body)
	return instance

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, top := -1.0, solid := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance:=_mesh(mesh,pos,_finish(color,Vector3(maxf(radius,mesh.top_radius)*2.0,height,maxf(radius,mesh.top_radius)*2.0)))
	if solid:
		var body:=StaticBody3D.new()
		var shape:=CollisionShape3D.new()
		var cylinder:=CylinderShape3D.new()
		cylinder.radius=maxf(radius,mesh.top_radius)
		cylinder.height=height
		shape.shape=cylinder
		body.add_child(shape)
		instance.add_child(body)
	return instance

func _cone(pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=0.0
	mesh.bottom_radius=0.5
	mesh.height=1.0
	mesh.radial_segments=8
	return _mesh(mesh,pos,_mat(color))

func _sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	return _mesh(mesh, pos, _finish(color, Vector3.ONE * radius * 2.0))

func _label(text: String, pos: Vector3, size := 32, color := CREAM) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.015
	label.modulate = color
	label.outline_size = maxi(2, int(size / 8))
	label.outline_modulate = Color("#223f47")
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.visibility_range_end = 34.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(label)
	return label

func _local_label(text: String, pos: Vector3, size: int, color: Color = CREAM) -> Label3D:
	var label := _label(text,pos,size,color)
	label.visibility_range_end=0.0
	label.visible=false
	local_sign_labels.append(label)
	return label

func _district_label(text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	# District names are local wayfinding accents; the nearby physical gateway
	# carries the durable name, so these do not need to hang over the whole island.
	var label := _label(text,pos,size,color)
	label.set_meta(SIGN_TITLE, true)
	# The player-distance gate below owns locality. Disable camera-distance culling:
	# the offset camera can be ~30m from the player even when the title is nearby.
	label.visibility_range_end=0.0
	label.visible=false
	district_labels.append(label)
	return label

func _update_district_label_visibility() -> void:
	if not is_instance_valid(player): return
	var player_x := player.global_position.x
	var player_z := player.global_position.z
	for label in district_labels+local_sign_labels:
		if not is_instance_valid(label): continue
		var dx := label.global_position.x-player_x
		var dz := label.global_position.z-player_z
		label.visible=dx*dx+dz*dz<=100.0
	if is_instance_valid(story_landmarks):
		story_landmarks.update_signpost_visibility(player.position)
	if is_instance_valid(district_host):
		for region: String in district_host.districts:
			if district_host.is_awake(region): district_host.districts[region]._update_district_label_visibility()

## Interaction markers float above the 2.4-unit character sprites so they never cover a
## face; low attraction props pass their own smaller height.
const DEFAULT_MARKER_HEIGHT := 2.85
const NPC_ROLE_BY_POINT := {"guide":"ticket", "quest-001":"imp", "quest-002":"announcer"}

func _point(id: String, title: String, pos: Vector3, marker_height := DEFAULT_MARKER_HEIGHT) -> void:
	var marker := _label("◇", pos + Vector3(0,marker_height,0), 38, GOLD)
	_register_interaction_point(id, title, pos, marker)
	# Capture the marker's animation baseline after attaching it to the actor.
	# Its local bob stays independent while the actor owns all route movement.
	if NPC_ROLE_BY_POINT.has(id):
		var actor := _npc_record_for_role(String(NPC_ROLE_BY_POINT[id]))
		var anchor := actor.get("activity_root") as Node3D
		if is_instance_valid(anchor): marker.reparent(anchor, true)
	component_motion.register_component(marker,"marker",float(points.size())*0.7)

func _register_interaction_point(id: String, title: String, pos: Vector3, marker: Label3D) -> Dictionary:
	marker.hide()
	var point := {"id": id, "label": title, "position": pos, "marker": marker}
	points.append(point)
	if embedded_in != null:
		embedded_in.points.append({"id": id, "label": title, "position": to_global(pos), "marker": marker, "region": district})
	return point

func _register_npc_activity() -> void:
	npc_activity=NpcActivityScript.new()
	npc_activity.name="NpcActivity"
	add_child(npc_activity)
	var point_ids := {"ticket":"guide","imp":"quest-001","announcer":"quest-002"}
	for actor_record in character_sprites:
		var role := String(actor_record.role)
		var interaction_point := _point_by_id(String(point_ids.get(role,"")))
		if interaction_point.is_empty():
			push_warning("ParkWorld: missing interaction point for NPC role '%s'." % role)
			continue
		var sprite := actor_record.sprite as Sprite3D
		var activity_root := actor_record.activity_root as Node3D
		var frames: Array[Texture2D] = NpcActivityScript.load_action_frames(role)
		if not npc_activity.register_actor(sprite,role,frames,activity_root,interaction_point,0.0):
			push_warning("ParkWorld: could not register NPC role '%s' for ambient activity." % role)
	npc_activity.finish_registration()
	# Production island actors use their authored directional Sprite cels. The
	# measured leg rig remains available to explicit reviews, not as live gait.
	npc_activity.configure_motion(camera,_avatar_ground_height,false)
	for actor_record in character_sprites:
		for activity_record in npc_activity._records:
			if String(activity_record.role) == String(actor_record.role):
				var motion: Variant = activity_record.get("motion")
				if motion != null and motion.supported:
					actor_record["name_body_height"] = float(motion.target_body_height_px) * motion.rig.PIXEL_SIZE
	_update_npc_name_labels(true)
	npc_activity.set_activity_paused(blocked)
	npc_activity_paused=blocked

func _visible_body_height(sprite: Sprite3D) -> float:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return 1.7
	var source := sprite.texture.get_image()
	if source == null or source.is_empty():
		return 1.7
	var used := source.get_used_rect()
	return maxf(0.2,float(used.size.y) * sprite.pixel_size)

func _update_npc_name_labels(force := false) -> void:
	if not is_instance_valid(camera):
		return
	var up_y := maxf(0.2,camera.global_basis.y.normalized().y)
	for record in character_sprites:
		var label := record.get("name_label") as Label3D
		var actor_root := record.get("activity_root") as Node3D
		if not is_instance_valid(label) or not is_instance_valid(actor_root):
			continue
		if not force and absf(float(record.get("name_camera_up_y",-1.0))-up_y)<0.001:
			continue
		var body_height := float(record.get("name_body_height",0.0))
		if body_height <= 0.0:
			body_height = _visible_body_height(record.get("sprite") as Sprite3D)
			record["name_body_height"] = body_height
		var font_height := ThemeDB.fallback_font.get_height(label.font_size) * label.pixel_size
		var outline_height := float(label.outline_size * 2) * label.pixel_size
		var text_half_height := (font_height + outline_height) * 0.5
		const HAIR_GAP := 0.075
		label.position.y = (body_height + HAIR_GAP + text_half_height) / up_y
		record["name_camera_up_y"] = up_y

func _npc_name_projected_gap(role: String) -> float:
	var record := _npc_record_for_role(role)
	if record.is_empty():
		return -1.0
	var label := record.get("name_label") as Label3D
	var up := camera.global_basis.y.normalized()
	var body_height := float(record.get("name_body_height",0.0))
	var text_height := ThemeDB.fallback_font.get_height(label.font_size) * label.pixel_size + float(label.outline_size * 2) * label.pixel_size
	return up.dot(label.global_position - (record.activity_root as Node3D).global_position) - text_height * 0.5 - body_height

## Float a "today's pick" ribbon over each recommended booth in this world.
## Three labels are made on the first call and reused; extras stay hidden.
func mark_daily_picks(game_ids: Array) -> void:
	while daily_pick_ribbons.size() < 3:
		var made := _label("★今日推薦★", Vector3.ZERO, 44, Color("#ffd36b"))
		made.name = "DailyPickRibbon%d" % daily_pick_ribbons.size()
		if _last_label_font != null:
			made.font = _last_label_font
		made.outline_size = 14
		made.outline_modulate = Color("#7a2438")
		# A wayfinding tag: always readable over awnings and signs, like the HUD.
		made.no_depth_test = true
		# Only three exist; keep them visible across the whole region.
		made.visibility_range_end = 0.0
		made.render_priority = 4
		made.outline_render_priority = 3
		made.hide()
		daily_pick_ribbons.append(made)
	var shown := 0
	for id in game_ids:
		var point := _point_by_id(str(id))
		if point.is_empty() or shown >= daily_pick_ribbons.size():
			continue
		var marker := point.get("marker") as Node3D
		var top: Vector3 = to_local(marker.global_position) if is_instance_valid(marker) and marker.is_inside_tree() else point.position + Vector3(0, DEFAULT_MARKER_HEIGHT, 0)
		var ribbon := daily_pick_ribbons[shown]
		ribbon.position = top + Vector3(0, 1.3, 0)
		ribbon.show()
		shown += 1
	for index in range(shown, daily_pick_ribbons.size()):
		daily_pick_ribbons[index].hide()

func _point_by_id(point_id: String) -> Dictionary:
	for point in points:
		if String(point.get("id",""))==point_id:
			return point
	return {}

func _build_land() -> void:
	# The pools retain the shared material. Only the open Welcome bay knows the shore.
	sea_material = ShaderMaterial.new()
	sea_material.shader = WATER
	welcome_sea_material = ShaderMaterial.new()
	welcome_sea_material.shader = WELCOME_BAY_WATER
	_bind_shore(welcome_sea_material)
	welcome_sea_material.set_shader_parameter("dock_center", Vector2(WELCOME_DOCK_CENTER.x, WELCOME_DOCK_CENTER.z))
	welcome_sea_material.set_shader_parameter("dock_half_size", Vector2(WELCOME_DOCK_SIZE.x, WELCOME_DOCK_SIZE.z) * 0.5)
	IslandScenery.build_ground(self)
	IslandScenery.build_planting(self)
	# One low garden pocket per side keeps the promenade readable around guests.
	for side in [-1,1]:
		_flowerbed(Vector3(side*6.5,0,-6.4),side+1)
	# A few low, irregular pebbles soften the fountain court edge without a rigid ring of identical blocks.
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radial_segments = 8
	pebble_mesh.rings = 4
	var pebble_transforms: Array[Transform3D] = []
	var pebble_colors: Array[Color] = []
	for index in range(10):
		var angle := TAU * float(index) / 10.0 + sin(float(index) * 1.7) * 0.08
		var radius := 7.15 + sin(float(index) * 2.3) * 0.42
		var scale_value := 0.22 + fposmod(float(index) * 0.071, 0.13)
		var pebble_basis := Basis().rotated(Vector3.UP, angle).scaled(Vector3(scale_value * 1.35, 0.12, scale_value))
		pebble_transforms.append(Transform3D(pebble_basis, Vector3(cos(angle) * radius, 0.13, sin(angle) * radius)))
		pebble_colors.append([Color("#897f6a"), Color("#9b927c"), Color("#70877a")][index % 3])
	_multi_mesh(pebble_mesh, Vector3.ZERO, pebble_transforms, pebble_colors, _vertex_color_material("fountain-pebble-rim", 0.9, true))
	_build_coastal_planting_pockets()
	for side in [-1, 1]:
		var x: float = float(side) * 11.8
		_flowerbed(Vector3(x,0,-3.4),8+side)

func _build_coastal_planting_pockets() -> void:
	# Four loose edge pockets break up broad lawn patches; foliage is batched into two static multimeshes.
	var pocket_centers := [Vector3(-15.4,0,-31.8), Vector3(15.3,0,-23.8), Vector3(-15.1,0,-7.2), Vector3(15.2,0,4.0)]
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3.ONE
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.13
	flower_mesh.height = 0.26
	flower_mesh.radial_segments = 8
	flower_mesh.rings = 4
	var blade_transforms: Array[Transform3D] = []
	var blade_colors: Array[Color] = []
	var flower_transforms: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	for pocket_index in range(pocket_centers.size()):
		var center: Vector3 = pocket_centers[pocket_index]
		var pocket_radius := 0.5 + fposmod(float(pocket_index) * 0.19, 0.22)
		for blade_index in range(7):
			var angle := TAU * float(blade_index) / 7.0 + float(pocket_index) * 0.31
			var offset := Vector3(cos(angle) * pocket_radius, 0.28, sin(angle) * pocket_radius * 0.68)
			var tilt := Basis().rotated(Vector3.UP, angle).rotated(Vector3.FORWARD, sin(angle * 1.6) * 0.25)
			blade_transforms.append(Transform3D(tilt.scaled(Vector3(0.13, 0.58, 0.09)), center + offset))
			blade_colors.append(Color("#547a58") if blade_index % 2 == 0 else Color("#76905c"))
			if blade_index in [1, 4]:
				var flower_scale := 0.82 + fposmod(float(pocket_index + blade_index) * 0.17, 0.3)
				flower_transforms.append(Transform3D(Basis().scaled(Vector3.ONE * flower_scale), center + offset + Vector3(0,0.54,0)))
				flower_colors.append(Color("#d98768") if (pocket_index + blade_index) % 2 == 0 else Color("#e6ce8f"))
	_multi_mesh(blade_mesh, Vector3.ZERO, blade_transforms, blade_colors, _vertex_color_material("coastal-pocket-leaves", 0.9, true))
	_multi_mesh(flower_mesh, Vector3.ZERO, flower_transforms, flower_colors, _vertex_color_material("coastal-pocket-flowers", 0.9, true))

const BEACH_TOP_Y := IslandLayout.BEACH_TOP_Y

## Give a shore-aware shader the island's signed-distance field.
func _bind_shore(material: ShaderMaterial) -> void:
	material.set_shader_parameter("shore_distance", IslandShape.sdf_texture())
	material.set_shader_parameter("sdf_origin", IslandShape.sdf_origin())
	material.set_shader_parameter("sdf_inverse_size", IslandShape.sdf_inverse_size())

func _beach_material() -> Material:
	if material_cache.has("welcome-beach"): return material_cache["welcome-beach"]
	var material := ShaderMaterial.new()
	material.shader = SAND
	_bind_shore(material)
	material.set_shader_parameter("sand_width", IslandShape.SAND_WIDTH)
	material.set_shader_parameter("beaches", PackedVector3Array(IslandShape.BEACHES))
	material.set_shader_parameter("beach_count", IslandShape.BEACHES.size())
	material_cache["welcome-beach"] = material
	return material

func _build_shoreline() -> void:
	# Layered cut-paper rocks stay on the sand. The bay draws foam at the actual waterline.
	IslandScenery.build_shore_rocks(self)

func _add_shore_rock(pos: Vector3, seed_value: int) -> void:
	# Tide-pool rocks belong to the beach: they rest on the sand by the waterline.
	var scale_value := 0.72 + fposmod(float(seed_value)*0.17,0.32)
	var rock: Node3D
	if _foliage_has("rocks"):
		rock = _foliage_sprite("rocks",Vector3(pos.x,BEACH_TOP_Y-0.03,pos.z),scale_value)
	else:
		rock = _sphere(Vector3(pos.x,BEACH_TOP_Y+0.1,pos.z),scale_value,Color("#967e64") if seed_value%3==0 else Color("#b29a77"))
		rock.scale=Vector3(1.35,0.55,1.15)
		rock.rotation.y=fposmod(float(seed_value)*1.93,TAU)
	rock.name = "ShoreRock%02d" % shoreline_rock_count
	shoreline_rock_count += 1

static func tree_site_clear(pos: Vector3) -> bool:
	return IslandLayout.tree_site_clear(Vector2(pos.x,pos.z))

func _tree(pos: Vector3, seed_value: int, site_checked := false) -> void:
	if not site_checked and not tree_site_clear(pos): return
	# Each part of the island keeps a coherent canopy: palms by the sea and the
	# plaza, pines across the north-west, ginkgo scattered through the east.
	var key := "oak"
	var tree_height := 4.35
	if pos.z > -14.0 or IslandShape.distance_to_coast(Vector2(pos.x,pos.z)) < 15.0:
		key = "palm"
		tree_height = 4.15
	elif pos.z < -84.0 and pos.x < 12.0:
		key = "pine"
		tree_height = 4.6
	elif pos.x > 10.0 and seed_value % 3 == 0:
		key = "ginkgo"
		tree_height = 4.3
	tree_height *= 0.94 + fposmod(float(seed_value) * 0.137, 0.14)
	if _foliage_has(key):
		_foliage_sprite(key,pos,tree_height)
		return
	_cylinder(pos+Vector3(0,1.15,0),0.2,2.3,Color("#76583f"))
	for root in [-1,1]:
		var a: float = float(root) * TAU / 4.0 + 0.4
		var buttress := _box(pos+Vector3(cos(a)*0.33,0.25,sin(a)*0.33),Vector3(0.18,0.48,0.18),Color("#8a6948"))
		buttress.rotation.y = a
	for branch in [-1,1]:
		var arm := _box(pos+Vector3(branch*0.42,1.9,0),Vector3(0.13,1.0,0.14),Color("#76583f"))
		arm.rotation.z = branch * -0.58
	# Flat leaf clusters are batched per tree so the foliage stays crisp without
	# creating a separate mesh node for every printed leaf.
	var leaves: Array[Transform3D]=[]
	var leaf_colors: Array[Color]=[]
	var glints: Array[Transform3D]=[]
	var glint_colors: Array[Color]=[]
	for leaf in range(9):
		var a := float(leaf) * TAU / 9.0 + seed_value * 0.17
		var crown := Vector3(cos(a)*0.85,2.55+sin(leaf*2.4)*0.22,sin(a)*0.75)
		var basis := Basis().rotated(Vector3.UP,a).rotated(Vector3.FORWARD,sin(a)*0.18).scaled(Vector3(0.75,0.42,0.32))
		leaves.append(Transform3D(basis,crown))
		leaf_colors.append([Color("#3e7058"),Color("#54845d"),Color("#729365")][leaf%3])
		if leaf % 3 == 0:
			glints.append(Transform3D(Basis().rotated(Vector3.UP,a).scaled(Vector3(0.22,0.035,0.18)),crown+Vector3(0,0.23,0)))
			glint_colors.append(Color("#a1ad72"))
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size=Vector3.ONE
	_multi_mesh(leaf_mesh,pos,leaves,leaf_colors,_vertex_color_material("tree-leaves", 0.9, true))
	var glint_mesh := BoxMesh.new()
	glint_mesh.size=Vector3.ONE
	_multi_mesh(glint_mesh,pos,glints,glint_colors,_vertex_color_material("tree-glints", 0.9, true))
	if seed_value % 3 == 0:
		_lantern(pos+Vector3(0.4,2,0.7))

func _flowerbed(pos: Vector3, seed_value: int) -> void:
	if _foliage_has("planter"):
		var planter_height := 1.75+fmod(float(seed_value)*0.07,0.25)
		_foliage_sprite("planter",pos,planter_height)
		return
	_box(pos+Vector3(0,0.3,0),Vector3(1.7,0.5,1.3),Color("#ccba92"),true)
	_box(pos+Vector3(0,0.58,0),Vector3(1.5,0.12,1.1),Color("#425c42"))
	var leaves: Array[Transform3D]=[]
	var leaf_colors: Array[Color]=[]
	var petals: Array[Transform3D]=[]
	var petal_colors: Array[Color]=[]
	var centers: Array[Transform3D]=[]
	var center_colors: Array[Color]=[]
	for j in range(7):
		var offset := Vector3(sin(j*2.4)*0.55,0.78,cos(j*3.1)*0.37)
		var leaf_basis := Basis().rotated(Vector3.UP,j*0.8).rotated(Vector3.FORWARD,sin(j*1.7)*0.18).scaled(Vector3(0.16,0.42,0.1))
		leaves.append(Transform3D(leaf_basis,offset*0.72))
		leaf_colors.append(Color("#63865c") if j%2==0 else Color("#779463"))
		petals.append(Transform3D(Basis().rotated(Vector3.UP,j*0.43).scaled(Vector3(0.28,0.08,0.23)),offset))
		petal_colors.append(CORAL if (j+seed_value)%2==0 else GOLD)
		centers.append(Transform3D(Basis().scaled(Vector3(0.07,0.025,0.07)),offset+Vector3(0,0.07,0)))
		center_colors.append(Color("#fff0bd"))
	var blade := BoxMesh.new()
	blade.size=Vector3.ONE
	var petal := BoxMesh.new()
	petal.size=Vector3.ONE
	var center := BoxMesh.new()
	center.size=Vector3.ONE
	_multi_mesh(blade,pos,leaves,leaf_colors,_vertex_color_material("flower-leaves", 0.9, true))
	_multi_mesh(petal,pos,petals,petal_colors,_vertex_color_material("flower-petals", 0.9, true))
	_multi_mesh(center,pos,centers,center_colors,_vertex_color_material("flower-centers", 0.9, true))

func _foliage_sprite(kind: String, ground: Vector3, world_height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture=foliage_textures[kind]
	var region_height: float=foliage_textures[kind].region.size.y
	sprite.pixel_size=world_height/region_height
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded=true
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold=0.45
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.layers=SCENERY_RENDER_LAYER
	sprite.position=ground+Vector3(0,world_height*0.5,0)
	var phase := fposmod(ground.x * 0.713 + ground.z * 0.391, TAU)
	var material := _set_living_sprite_material(sprite, 0, phase, 0.72)
	material.set_shader_parameter("outline_soften",float(FOLIAGE_OUTLINE_SOFTEN.get(kind,FOLIAGE_OUTLINE_SOFTEN_DEFAULT)))
	material.set_shader_parameter("ground_blend",FOLIAGE_GROUND_BLEND)
	material.set_shader_parameter("saturation",FOLIAGE_SATURATION)
	foliage_materials.append(material)
	add_child(sprite)
	component_motion.register_component(sprite,"foliage",phase/TAU)
	_ground_foliage_sprite(kind,sprite,world_height)
	return sprite

## Painted scenery has its own render layer, which the key light skips: lit by
## it, a billboard would show its own silhouette card printed back across the
## paint whenever the sun or moon is in front of it. Ambient and lamp light still
## reach it, and this grade (applied once per phase) stands in for the key light.
const SCENERY_RENDER_LAYER := 1 << 1
const FOLIAGE_PHASE_TINT := {
	"dawn": Color(1.3, 1.18, 1.12),
	"noon": Color(1.0, 0.97, 0.90),
	"dusk": Color(1.55, 1.42, 1.22),
	"night": Color(1.5, 1.6, 1.8),
}
## The heavy atlas outline is lifted toward the neighbouring colour, and the base
## dissolves into the ground instead of ending in a cut line.
const FOLIAGE_OUTLINE_SOFTEN_DEFAULT := 0.85
## Wrought iron is meant to stay dark; only its hardest edge is eased.
const FOLIAGE_OUTLINE_SOFTEN := {"lamp": 0.15}
const FOLIAGE_GROUND_BLEND := 0.055
const FOLIAGE_SATURATION := 0.9
## Share of the sprite's width that touches the ground, for the contact shadow.
const FOLIAGE_BASE_WIDTH := {"lamp": 0.5, "planter": 0.7, "shrub": 0.85, "rocks": 0.9}
const FOLIAGE_TRUNK_BASE_WIDTH := 0.45
## The fixed follow camera's orientation; billboards and their shadows share it.
var _view_basis := Basis.looking_at(Vector3.UP - CAMERA_OFFSET)

func _ground_foliage_sprite(kind: String, sprite: Sprite3D, world_height: float) -> void:
	# A billboard leans back from the camera, so its painted base meets the ground
	# a little in front of its anchor. Both shadows start from that visible base;
	# the cast one is the sprite's own silhouette on a card that never processes.
	var bottom := sprite.position - _view_basis.y * world_height * 0.5
	var view_forward := -_view_basis.z
	var base := sprite.position
	# The surface under the visible base can differ from the one under the anchor.
	for refinement in 3:
		base = bottom + view_forward * ((_ground_surface_y(base) - bottom.y) / view_forward.y)
	var surface_y := base.y
	var caster := ActorShadowSilhouette.new()
	caster.name = "%sAlphaShadow" % kind.capitalize()
	add_child(caster)
	var cache_key := "foliage-shadow:" + kind
	# A vertical card must be taller than the tilted billboard to cover it on screen.
	if caster.configure_static(sprite, base, world_height / _view_basis.y.y, material_cache.get(cache_key)):
		material_cache[cache_key] = caster.silhouette_material
	foliage_shadow_casters.append(caster)
	mesh_count += 1
	var region: Rect2 = foliage_textures[kind].region
	var contact_width := world_height * region.size.x / region.size.y * float(FOLIAGE_BASE_WIDTH.get(kind, FOLIAGE_TRUNK_BASE_WIDTH))
	_foliage_contact_transforms.append(Transform3D(Basis().scaled(Vector3(contact_width, 1.0, contact_width * 0.5)), Vector3(base.x, surface_y + 0.012, base.z)))

func _build_foliage_contact_shadows() -> void:
	# One batched draw grounds every painted prop; nothing here updates per frame.
	if _foliage_contact_transforms.is_empty(): return
	var colors: Array[Color] = []
	colors.resize(_foliage_contact_transforms.size())
	colors.fill(Color.WHITE)
	var blob := PlaneMesh.new()
	blob.size = Vector2.ONE
	var contacts := _multi_mesh(blob, Vector3.ZERO, _foliage_contact_transforms, colors, contact_shadow_material)
	contacts.name = "FoliageContactShadows"
	contacts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _apply_foliage_phase() -> void:
	var tint: Color = FOLIAGE_PHASE_TINT[active_time_phase]
	for material in foliage_materials:
		material.set_shader_parameter("tint", tint)
	var light_travel := -sun.basis.z
	for caster in foliage_shadow_casters:
		caster.face_light(light_travel, _view_basis.x)


func _set_living_sprite_material(sprite: Sprite3D, kind: int, phase: float, breath_rate: float, idle_role := 0, animate_shader := true) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader=LIVING_SPRITE
	material.set_shader_parameter("motion_kind",kind)
	material.set_shader_parameter("idle_role",idle_role)
	material.set_shader_parameter("phase",phase)
	material.set_shader_parameter("breath_rate",breath_rate)
	material.set_shader_parameter("breath_pixels",0.65)
	material.set_shader_parameter("gesture_pixels",0.65)
	material.set_shader_parameter("motion",1.0 if animate_shader else 0.0)
	material.set_shader_parameter("tint",Color.WHITE)
	var texture_source: Texture2D=sprite.texture
	var uv_rect := Rect2(0.0,0.0,1.0,1.0)
	if texture_source is AtlasTexture and texture_source.atlas != null:
		var atlas_texture := texture_source as AtlasTexture
		var atlas_size := Vector2(atlas_texture.atlas.get_width(),atlas_texture.atlas.get_height())
		uv_rect=Rect2(atlas_texture.region.position/atlas_size,atlas_texture.region.size/atlas_size)
		texture_source=atlas_texture.atlas
	material.set_shader_parameter("texture_albedo",texture_source)
	material.set_shader_parameter("uv_rect",Vector4(uv_rect.position.x,uv_rect.position.y,uv_rect.size.x,uv_rect.size.y))
	sprite.material_override=material
	if animate_shader:
		component_motion.register_shader(material)
	return material

## Small repeated fittings (lantern holders, bench boards) that the Welcome
## island collects while it builds and draws as a few batches, not hundreds of nodes.
var _fitting_batches := {}
var _batch_fittings := false
## Where the piece being built will end up, for parts made at the origin and then set in place.
var _fitting_space := Transform3D.IDENTITY

## Adds one piece to a named batch. `shape` is "box", "cylinder" or "cone" at
## unit size; `placed` scales and positions it.
func _fitting(batch: String, shape: String, material: Material, placed: Transform3D, color := Color.WHITE) -> void:
	if not _fitting_batches.has(batch):
		var mesh: Mesh = BoxMesh.new()
		if shape != "box":
			var round_mesh := CylinderMesh.new()
			round_mesh.top_radius = 0.0 if shape == "cone" else 0.5
			round_mesh.bottom_radius = 0.5
			round_mesh.height = 1.0
			round_mesh.radial_segments = 8 if shape == "cone" else 16
			mesh = round_mesh
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		_fitting_batches[batch] = {"mesh": mesh, "material": material, "transforms": transforms, "colors": colors}
	_fitting_batches[batch].transforms.append(_fitting_space * placed)
	_fitting_batches[batch].colors.append(color)

func _build_fitting_batches() -> void:
	for batch: String in _fitting_batches:
		var record: Dictionary = _fitting_batches[batch]
		_multi_mesh(record.mesh, Vector3.ZERO, record.transforms, record.colors, record.material).name = "Fittings_" + batch
	_fitting_batches.clear()

func _lantern(pos: Vector3) -> void:
	if _batch_fittings:
		_fitting("lantern-holder","cylinder",_vertex_color_material("lantern-fittings"),Transform3D(Basis().scaled(Vector3(0.28,0.36,0.28)),pos),Color("#805b39"))
		_fitting("lantern-cap","cone",_vertex_color_material("lantern-fittings"),Transform3D(Basis().scaled(Vector3(0.2,0.12,0.2)),pos+Vector3(0,0.24,0)),Color("#7d6345"))
	else:
		_cylinder(pos,0.14,0.36,Color("#805b39"))
		var cap := _cone(pos+Vector3(0,0.24,0),Color("#7d6345"))
		cap.scale=Vector3(0.2,0.12,0.2)
	var shade := _box(pos+Vector3(0,0.05,0),Vector3(0.3,0.3,0.3),Color("#f6ca78"))
	shade.material_override = _mat(Color("#ffd68b"),true)
	component_motion.register_component(shade,"soft_scale",float(lamps.size())*0.23)
	if lamps.size() < 12:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color("#ffc276")
		light.omni_range = 4.2
		light.light_energy = 0.0
		add_child(light)
		lamps.append(light)
		# Keep local light output stable; animated lantern energy reads as flicker.

func _arch(pos: Vector3, title: String, color: Color, wide := 5.0) -> void:
	# Register the arch's opaque frame and its title's local visibility. Lanterns
	# keep their existing materials; the title hides only when it overlaps the mask.
	occlusion_controller.begin_building()
	var left_pillar := _box(pos+Vector3(-wide*0.5,1.65,0),Vector3(0.72,3.3,0.92),Color("#ac9875"),true)
	_set_registered_surface(left_pillar, _coastal_surface(4,1.7,Color("#e0cdaa")))
	var blocker := left_pillar.get_child(0) as StaticBody3D
	var right_pillar := _box(pos+Vector3(wide*0.5,1.65,0),Vector3(0.72,3.3,0.92),Color("#ac9875"),true)
	_set_registered_surface(right_pillar, _coastal_surface(4,1.7,Color("#e0cdaa")))
	var arch_beam := _box(pos+Vector3(0,3.35,0),Vector3(wide+1.1,0.86,0.98),color)
	_set_registered_surface(arch_beam, _coastal_surface(3,2.0,color.lightened(0.08)))
	var arch_cornice := _box(pos+Vector3(0,3.84,-0.02),Vector3(wide+1.5,0.22,1.2),Color("#315d60"))
	_set_registered_surface(arch_cornice, _coastal_surface(2,1.5,Color("#92a89a")))
	var arch_underside := _box(pos+Vector3(0,2.88,-0.03),Vector3(wide+0.95,0.18,0.92),Color("#7e5844"))
	_set_registered_surface(arch_underside, _coastal_surface(1,1.8,Color("#b99a6f")))
	for i in range(7):
		var flag := _box(pos+Vector3(-wide*0.45+i*wide*0.15,2.85,0),Vector3(0.4,0.35,0.04),CORAL if i%2==0 else GOLD)
		component_motion.register_component(flag,"flag",float(i)*0.6)
	# Painted on the beam's front face, below the cornice's overhang, so the
	# deeper cornice can never cover the name (ART-68).
	var arch_title := _label(title,pos+Vector3(0,3.32,0.51),30)
	arch_title.set_meta(SIGN_TITLE, true)
	arch_title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	occlusion_controller.register_visibility_label(arch_title)
	occlusion_controller.finish_building(blocker)
	for side in [-1,1]:
		_lantern(pos+Vector3(side*(wide*0.5-0.4),2.3,0))

func _build_dock() -> void:
	var dock_base := _box(WELCOME_DOCK_CENTER,WELCOME_DOCK_SIZE,Color("#8d6d4c"))
	dock_base.material_override = _coastal_surface(1,1.7)
	# Planks and their nails are two batched draws, not eighty-one nodes.
	var planks: Array[Transform3D] = []
	var nails: Array[Transform3D] = []
	for i in range(27):
		planks.append(Transform3D(Basis().scaled(Vector3(4.92,0.08,0.35)),Vector3(0,0.18,15+i*0.45)))
		for side in [-1,1]:
			nails.append(Transform3D(Basis().scaled(Vector3(0.07,0.025,0.07)),Vector3(side*2.18,0.25,15+i*0.45)))
	var plank_colors: Array[Color] = []
	plank_colors.resize(planks.size())
	plank_colors.fill(Color.WHITE)
	_multi_mesh(BoxMesh.new(),Vector3.ZERO,planks,plank_colors,_wood_material(Color("#9a7149"))).name = "DockPlanks"
	var nail_colors: Array[Color] = []
	nail_colors.resize(nails.size())
	nail_colors.fill(Color("#d2b47d"))
	var nail_mesh := CylinderMesh.new()
	nail_mesh.radial_segments = 8
	nail_mesh.height = 1.0
	var dock_nails := _multi_mesh(nail_mesh,Vector3.ZERO,nails,nail_colors,_vertex_color_material("dock-nails", 0.9, true))
	dock_nails.name = "DockNails"
	dock_nails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1,1]:
		for i in range(5):
			var z := 16.0+i*2.7
			_cylinder(Vector3(side*2.5,0.6,z),0.12,1.4,Color("#665d45"))
			if i<4:
				var rope := _box(Vector3(side*2.5,1.12,z+1.35),Vector3(0.07,0.08,2.7),Color("#ddcba0"))
				rope.rotation.x = 0.08
				if i % 2 == 0: _lantern(Vector3(side*2.5,1.45,z+1.35))
	_arch(Vector3(0,0,13.8),"SNAPLAND",TEAL,5.5)
	_box(Vector3(0,0.22,14.4),Vector3(6.6,0.18,0.28),Color("#d7bc8d"))
	for side in [-1,1]:
		_cylinder(Vector3(side*3.15,1.5,15.2),0.09,3.0,Color("#755b40"))
		var pennant := _box(Vector3(side*3.15,2.65,15.5),Vector3(0.8,0.65,0.06),CORAL if side<0 else GOLD)
		pennant.rotation.z = -0.15*side
	# A string of tiny warm bulbs frames the arrival arch after dusk.
	for i in range(9):
		var x := -2.8 + i * 0.7
		_box(Vector3(x,3.75,13.65),Vector3(0.035,0.3,0.035),Color("#6e563c"))
		_lantern(Vector3(x,3.55,13.65))
	WelcomeFerry.build(self)
	_point("arrival","重播上島導覽",Vector3(0,0,24))
	_local_label("碼頭  /  海風從這裡開始",Vector3(-4,1,19),24)

func _build_plaza() -> void:
	# Tiered fountain anchors the main area's visual silhouette.
	var fountain_base := _cylinder(Vector3(0,0.45,0),2.8,0.6,Color("#ac9875"))
	fountain_base.material_override = _coastal_surface(4,2.0,Color("#e1cfab"))
	var rim_tiles: Array[Transform3D] = []
	var rim_colors: Array[Color] = []
	for i in range(24):
		var a := i*TAU/24.0
		rim_tiles.append(Transform3D(Basis().rotated(Vector3.UP,-a).scaled(Vector3(0.47,0.07,0.2)),Vector3(cos(a)*2.57,0.79,sin(a)*2.57)))
		rim_colors.append([Color("#dfc99e"),Color("#e7d7b8")][i%2])
	_multi_mesh(BoxMesh.new(),Vector3.ZERO,rim_tiles,rim_colors,_vertex_color_material("fountain-rim-tiles", 0.9, true)).name = "FountainRimTiles"
	var fountain_rim := _cylinder(Vector3(0,0.78,0),2.5,0.13,Color("#7ac3c8"))
	fountain_rim.material_override = _coastal_surface(5,0.8,Color("#d9eee5"))
	fountain_water = ShaderMaterial.new()
	fountain_water.shader = WATER
	var disk := CylinderMesh.new()
	disk.top_radius=2.4
	disk.bottom_radius=2.4
	disk.height=0.07
	_mesh(disk,Vector3(0,0.86,0),fountain_water)
	var fountain_spire := _cylinder(Vector3(0,1.2,0),0.55,1.0,Color("#b89b70"))
	fountain_spire.material_override = _coastal_surface(4,1.25,Color("#ddc79f"))
	var fountain_cap := _cylinder(Vector3(0,1.8,0),1.5,0.25,Color("#ad936c"))
	fountain_cap.material_override = _coastal_surface(7,1.0,Color("#ceb27a"))
	_sphere(Vector3(0,2.2,0),0.42,GOLD)
	for i in range(8):
		var a := i*TAU/8.0
		var stream := _box(Vector3(cos(a)*1.15,1.38,sin(a)*1.15),Vector3(0.07,0.64,0.07),Color("#79cbd0"))
		stream.rotation.z=cos(a)*0.32
		stream.rotation.x=sin(a)*0.32
		_cylinder(Vector3(cos(a)*1.55,0.95,sin(a)*1.55),0.11,0.12,GOLD)
	for i in range(12):
		var a := i*TAU/12.0
		var bead := _sphere(Vector3(cos(a)*1.2,1.8,sin(a)*1.2),0.08,Color("#b3e4df"))
		component_motion.register_component(bead,"water",float(i)*0.5)
	for i in range(8):
		var a := i*TAU/8.0
		var lamp_post := Vector3(cos(a)*9.6,0,sin(a)*8.0)
		_lamppost(lamp_post)
	for i in range(4):
		var fan := _box(Vector3(-4.2+i*2.8,0.205,9.2),Vector3(1.0,0.03,0.16),Color("#c2ad84"))
		fan.rotation.y = (i%2)*0.25
		for j in range(3):
			var star := _box(Vector3(-4.2+i*2.8,0.23,8.8+j*0.3),Vector3(0.12,0.035,0.12),GOLD)
			star.rotation.y = j*0.8
	var collision := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius=2.8
	cylinder.height=1.5
	shape.shape=cylinder
	collision.add_child(shape)
	add_child(collision)
	_kiosk(Vector3(-8,0,5),"導覽亭",TEAL)
	# Keep the whole sprite on one ground level: the raised avenue starts at x=-4.5.
	_npc(Vector3(-3.8,0,5.0),CORAL,"票票")
	_point("guide","與票票合照",Vector3(-3.8,0,5.0))
	_kiosk(Vector3(8,0,5),"拍貼本",CORAL)
	_point("album","翻閱拍貼收藏",Vector3(8,0,7))
	_kiosk(Vector3(-9,0,-5),"借用道具",GOLD)
	_point("settings","設定與輔助",Vector3(-9,0,-3))
	_cylinder(Vector3(9,1.1,-5),0.45,2.2,TEAL)
	_sphere(Vector3(9,2.4,-5),0.7,CREAM)
	_local_label("日夜鐘",Vector3(9,3.5,-5),26)
	_point("clock","切換日夜",Vector3(9,0,-3))
	for side in [-1.0,1.0]:
		_bench(Vector3(side*12.0,0,5.5))
		_bench(Vector3(side*12.0,0,-8.0))
		_shrub_cluster(Vector3(side*14.0,0,2.0),side)
		_shrub_cluster(Vector3(side*14.0,0,-5.8),-side)
	_arch(Vector3(0,0,-11),"迎賓大道",CORAL,8)

func _bench(pos: Vector3) -> void:
	var wood := Color("#956d48")
	if _batch_fittings:
		for board in range(3):
			var tone := wood if board%2==0 else Color("#a77b50")
			_fitting("bench-" + tone.to_html(false),"box",_wood_material(tone),Transform3D(Basis().scaled(Vector3(2.0,0.09,0.13)),pos+Vector3(0,0.72,board*0.16-0.16)))
		for side in [-1.0,1.0]:
			_fitting("bench-iron","box",_vertex_color_material("bench-iron"),Transform3D(Basis().scaled(Vector3(0.11,0.7,0.12)),pos+Vector3(side*0.78,0.38,0)),Color("#5f5142"))
			_fitting("bench-iron","box",_vertex_color_material("bench-iron"),Transform3D(Basis().scaled(Vector3(0.12,1.05,0.12)),pos+Vector3(side*0.78,1.12,-0.26)),Color("#5f5142"))
			_fitting("bench-studs","cylinder",_vertex_color_material("bench-iron"),Transform3D(Basis().scaled(Vector3(0.26,0.12,0.26)),pos+Vector3(side*0.78,0.87,0.16)),GOLD)
		_fitting("bench-" + wood.to_html(false),"box",_wood_material(wood),Transform3D(Basis().scaled(Vector3(1.82,0.16,0.13)),pos+Vector3(0,1.17,-0.26)))
		return
	for board in range(3):
		var seat := _box(pos+Vector3(0,0.72,board*0.16-0.16),Vector3(2.0,0.09,0.13),wood if board%2==0 else Color("#a77b50"))
		seat.material_override=_wood_material(Color("#956d48") if board%2==0 else Color("#a77b50"))
	for side in [-1.0,1.0]:
		_box(pos+Vector3(side*0.78,0.38,0),Vector3(0.11,0.7,0.12),Color("#5f5142"))
		_box(pos+Vector3(side*0.78,1.12,-0.26),Vector3(0.12,1.05,0.12),Color("#5f5142"))
		_cylinder(pos+Vector3(side*0.78,0.87,0.16),0.13,0.12,GOLD)
	var back := _box(pos+Vector3(0,1.17,-0.26),Vector3(1.82,0.16,0.13),wood)
	back.material_override=_wood_material(wood)

func _shrub_cluster(pos: Vector3, seed_value: float) -> void:
	if _foliage_has("shrub"):
		_foliage_sprite("shrub",pos,2.05)
		return
	var branch := _cylinder(pos+Vector3(0,0.34,0),0.07,0.68,Color("#806143"))
	var leaves: Array[Transform3D]=[]
	var colors: Array[Color]=[]
	for i in range(7):
		var a := TAU*float(i)/7.0+seed_value
		var origin := Vector3(cos(a)*0.34,0.78+sin(i*2.1)*0.08,sin(a)*0.34)
		leaves.append(Transform3D(Basis().rotated(Vector3.UP,a).rotated(Vector3.FORWARD,sin(a)*0.32).scaled(Vector3(0.42,0.18,0.24)),origin))
		colors.append([Color("#385e49"),Color("#527952"),Color("#789563")][i%3])
	_multi_mesh(BoxMesh.new(),pos,leaves,colors,_vertex_color_material("shrub-leaves", 0.9, true))
	for side in [-1.0,1.0]:
		var blossom := _box(pos+Vector3(side*0.3,0.26,0.28),Vector3(0.18,0.12,0.15),CORAL if side<0 else GOLD)
		blossom.rotation.y=side*0.35

func _kiosk(pos: Vector3, title: String, color: Color) -> void:
	occlusion_controller.begin_building()
	var opaque_base := _box(pos+Vector3(0,0.7,0),Vector3(3.8,1.3,2.5),CREAM,true)
	var blocker := opaque_base.get_child(0) as StaticBody3D
	_box(pos+Vector3(0,0.48,1.28),Vector3(3.7,0.14,0.11),Color("#876843"))
	_box(pos+Vector3(0,1.25,1.31),Vector3(3.1,0.12,0.13),Color("#876843"))
	var product_transforms: Array[Transform3D]=[]
	var product_colors: Array[Color]=[]
	for i in range(5):
		product_transforms.append(Transform3D(Basis().scaled(Vector3(0.34,0.08,0.65)),Vector3(-1.1+i*0.55,1.45,0.7)))
		product_colors.append([CORAL,GOLD,TEAL,Color("#7abec3"),CORAL][i])
	_multi_mesh(BoxMesh.new(),pos,product_transforms,product_colors,_vertex_color_material("kiosk-products", 0.9, true))
	_box(pos+Vector3(0,1.7,0),Vector3(4.2,0.3,3),color)
	var support_transforms: Array[Transform3D]=[]
	var support_colors: Array[Color]=[]
	for side in [-1.0,1.0]:
		for row in range(2):
			support_transforms.append(Transform3D(Basis().scaled(Vector3(0.16 if row==0 else 0.12,1.4 if row==0 else 1.2,0.16 if row==0 else 0.12)),Vector3(side*(1.65 if row==0 else 1.87),1.85 if row==0 else 1.9,0.0 if row==0 else 0.8)))
			support_colors.append(TEAL if row==0 else Color("#9a7854"))
	_multi_mesh(BoxMesh.new(),pos,support_transforms,support_colors,_vertex_color_material("kiosk-supports", 0.9, true))
	# Two printed-paper roof planes make the stand read as a little harbor pavilion.
	var roof_left := _box(pos+Vector3(-1.08,2.62,0),Vector3(2.35,0.28,3.35),color)
	var roof_right := _box(pos+Vector3(1.08,2.62,0),Vector3(2.35,0.28,3.35),color)
	roof_left.rotation.z=0.18
	roof_right.rotation.z=-0.18
	_box(pos+Vector3(0,2.87,0),Vector3(0.22,0.32,3.45),Color("#866b47"))
	_box(pos+Vector3(0,2.48,1.69),Vector3(4.85,0.14,0.12),Color("#f1d9a9"))
	var scallop_transforms: Array[Transform3D]=[]
	var scallop_colors: Array[Color]=[]
	for i in range(9):
		var tilt := 0.04 if i%2==0 else -0.04
		scallop_transforms.append(Transform3D(Basis().rotated(Vector3.FORWARD,tilt).scaled(Vector3(0.45,0.38,0.13)),Vector3(-1.8+i*0.45,2.25,1.72)))
		scallop_colors.append(CREAM if i%2==0 else Color("#f1d9a9"))
	_multi_mesh(BoxMesh.new(),pos,scallop_transforms,scallop_colors,_vertex_color_material("kiosk-awning-fringe", 0.9, true))
	var plaque := _box(pos+Vector3(0,2.01,1.59),Vector3(2.7,0.54,0.12),Color("#755a3c"))
	_box(pos+Vector3(0,2.01,1.67),Vector3(2.55,0.4,0.06),color)
	_local_label(title,pos+Vector3(0,1.94,1.73),19).set_meta(SIGN_TITLE, true)
	# Small brass studs and roof tiles share batched meshes across each stand.
	var tile_transforms: Array[Transform3D]=[]
	var tile_colors: Array[Color]=[]
	for side in [-1.0,1.0]:
		for row in range(3):
			for col in range(5):
				var tile_basis := Basis().rotated(Vector3.FORWARD,-side*0.18).scaled(Vector3(0.32,0.035,0.58))
				tile_transforms.append(Transform3D(tile_basis,Vector3(side*(0.32+col*0.43),2.79-row*0.075,-1.0+row*0.8)))
				tile_colors.append(Color("#a96d55") if (col+row)%3==0 else color)
	_multi_mesh(BoxMesh.new(),pos,tile_transforms,tile_colors,_vertex_color_material("kiosk-roof-tiles", 0.9, true))
	var stud_transforms: Array[Transform3D]=[]
	var stud_colors: Array[Color]=[]
	for side in [-1.0,1.0]:
		stud_transforms.append(Transform3D(Basis().scaled(Vector3(0.1,0.1,0.06)),Vector3(side*1.9,1.95,1.73)))
		stud_colors.append(GOLD)
	_multi_mesh(BoxMesh.new(),pos,stud_transforms,stud_colors,_vertex_color_material("kiosk-studs", 0.9, true))
	occlusion_controller.finish_building(blocker)

func _lamppost(pos: Vector3) -> void:
	if _foliage_has("lamp"):
		_foliage_sprite("lamp",pos,2.85)
		var decorative_light := OmniLight3D.new()
		decorative_light.position=pos+Vector3(0,2.18,0)
		decorative_light.light_color=Color("#ffd79a")
		decorative_light.omni_range=5.2
		decorative_light.light_energy=0.0
		add_child(decorative_light)
		lamps.append(decorative_light)
		# Keep local light output stable; animated lantern energy reads as flicker.
		return
	_cylinder(pos+Vector3(0,1.2,0),0.09,2.4,Color("#554c3f"))
	_cylinder(pos+Vector3(0,2.25,0),0.28,0.12,Color("#92734c"))
	var glow := _box(pos+Vector3(0,2.55,0),Vector3(0.3,0.42,0.3),Color("#f4d292"))
	glow.material_override=_mat(Color("#ffe0a0"),true)
	for side in [-1,1]:
		_box(pos+Vector3(side*0.21,2.76,0),Vector3(0.06,0.48,0.06),Color("#554c3f"))
	_cylinder(pos+Vector3(0,2.98,0),0.19,0.08,Color("#554c3f"))
	var light := OmniLight3D.new()
	light.position=pos+Vector3(0,2.55,0)
	light.light_color=Color("#ffd79a")
	light.omni_range=5.2
	light.light_energy=0.0
	add_child(light)
	lamps.append(light)
	# Keep local light output stable; animated lantern energy reads as flicker.

func _build_avenue() -> void:
	var names := ["氣球快遞","風箏穿環","噴泉跳拍","人潮指揮","帽子救援","彩帶節拍","花壇拼圖","招牌平衡","影子捉迷藏","泡泡合照","長椅換位","迎賓大合奏"]
	# Each entry stands in its own place along the branching walkways; IDs stay stable.
	for i in range(12):
		var entry_position: Vector3 = IslandLayout.GAME_ENTRIES[i].position
		_point("game-%03d"%(i+1),names[i],entry_position,1.45)
		var feature_color: Color = [CORAL,TEAL,GOLD][i%3]
		var feature_start := get_child_count()
		occlusion_controller.begin_building()
		_game_feature(i,entry_position,feature_color)
		var feature_root := Node3D.new()
		feature_root.name = "GameFeature%03d" % (i+1)
		add_child(feature_root)
		_adopt_district_geometry(feature_root,feature_start)
		var feature_blocker := _district_occlusion_blocker(feature_root, "FeatureOcclusionBlocker")
		occlusion_controller.finish_building(feature_blocker)
	IslandScenery.build_entry_frames(self)
	_build_attraction_districts()
	_build_place_dressing()
	# Keep both story characters in the open foreground of the avenue arch, where
	# their whole billboards and ground anchors stay visible in the lowered camera.
	# Leave the complete imp silhouette clear of the foreground lamp planter.
	var imp_position := Vector3(-4.1,0,-7.5)
	_npc(imp_position,CORAL,"小角")
	_point("quest-001","吉祥物的尾巴危機",imp_position)
	_npc(Vector3(3.4,0,-4.0),TEAL,"阿浪")
	_point("quest-002","廣播即興救場",Vector3(3.4,0,-4.0))
	_point("explore-001","花壇會眨眼",Vector3(-3,0,-25))
	_flowerbed(Vector3(-4.6,0,-25.6),3)
	_point("explore-002","歡迎字樣的影子",Vector3(0.6,0,-31))
	var bench := _box(Vector3(-0.4,0.7,-37.4),Vector3(2,0.3,0.7),GOLD,true)
	bench.material_override = _wood_material(Color("#c9a25e"))
	_point("explore-003","長椅雙人份",Vector3(-0.4,0,-36.1))
	_arch(IslandLayout.district_point("stage",Vector3(0,0,-45)),"倒影大道",Color("#655178"),5)
	_point("rift","查看倒影大道",IslandLayout.district_point("stage",Vector3(0,0,-43)))
	_point("ride-tide","搭乘潮汐貝殼輪",Vector3(-6.7,0.26,11.2))

## Small dressing that turns the free-standing entries into places: a bandstand,
## beach parasols, a ring of planters, benches and the lamps that light the way.
func _build_place_dressing() -> void:
	_bandstand(Vector3(45.2,0,-31.4))
	var poles: Array[Transform3D] = []
	var canopies: Array[Transform3D] = []
	var towels: Array[Transform3D] = []
	for index in IslandLayout.PARASOLS.size():
		var spot: Vector2 = IslandLayout.PARASOLS[index]
		var base := Vector3(spot.x,BEACH_TOP_Y,spot.y)
		var lean := Basis().rotated(Vector3.FORWARD,0.12 if index%2==0 else -0.1)
		poles.append(Transform3D(lean.scaled(Vector3(0.07,2.3,0.07)),base+Vector3(0,1.15,0)))
		canopies.append(Transform3D(lean.scaled(Vector3(3.0,0.75,3.0)),base+lean*Vector3(0,2.45,0)))
		towels.append(Transform3D(Basis().rotated(Vector3.UP,0.4+float(index)*0.7).scaled(Vector3(0.95,0.03,1.9)),base+Vector3(-1.4,0.02,0.6)))
	var whites: Array[Color] = []
	whites.resize(poles.size())
	whites.fill(Color.WHITE)
	_multi_mesh(BoxMesh.new(),Vector3.ZERO,poles,whites,_wood_material(Color("#8a6a48"))).name = "BeachParasolPoles"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 10
	_multi_mesh(cone,Vector3.ZERO,canopies,whites,_coastal_surface(6,1.1,Color("#e9b8a0"))).name = "BeachParasolCanopies"
	_multi_mesh(BoxMesh.new(),Vector3.ZERO,towels,whites,_coastal_surface(6,0.9,Color("#a9cfc6"))).name = "BeachTowels"
	for index in IslandLayout.PLANTERS.size():
		var spot: Vector2 = IslandLayout.PLANTERS[index]
		_flowerbed(Vector3(spot.x,0,spot.y),index)
	for spot: Vector2 in IslandLayout.BENCHES:
		_bench(Vector3(spot.x,0,spot.y))
	for spot: Vector2 in IslandLayout.LAMPPOSTS:
		_lamppost(Vector3(spot.x,0,spot.y))

func _bandstand(pos: Vector3) -> void:
	occlusion_controller.begin_building()
	var plinth := _cylinder(pos+Vector3(0,0.2,0),2.9,0.3,Color("#ac9875"))
	plinth.name = "BandstandPlinth"
	_set_registered_surface(plinth,_coastal_surface(4,1.6,Color("#e1cfab")))
	var step := _cylinder(pos+Vector3(0,0.1,0),3.3,0.12,Color("#9c8a6a"))
	_set_registered_surface(step,_coastal_surface(0,1.4,Color("#cbb995")))
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	for index in 6:
		var angle := TAU*float(index)/6.0+PI/6.0
		var foot := Vector3(cos(angle)*2.5,0,sin(angle)*2.5)
		posts.append(Transform3D(Basis().scaled(Vector3(0.16,2.5,0.16)),foot+Vector3(0,1.6,0)))
		# The south side stays open as the way in.
		if index in [0,1]: continue
		var next_angle := angle+TAU/6.0
		var middle := (foot+Vector3(cos(next_angle)*2.5,0,sin(next_angle)*2.5))*0.5
		rails.append(Transform3D(Basis().rotated(Vector3.UP,-(angle+next_angle)*0.5-PI*0.5).scaled(Vector3(2.5,0.09,0.09)),middle+Vector3(0,1.05,0)))
	var post_colors: Array[Color] = []
	post_colors.resize(posts.size()+rails.size())
	post_colors.fill(Color.WHITE)
	_multi_mesh(BoxMesh.new(),pos,posts+rails,post_colors,_coastal_surface(1,1.2,Color("#bd9c6b")))
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.25
	roof_mesh.bottom_radius = 3.5
	roof_mesh.height = 1.5
	roof_mesh.radial_segments = 12
	var roof := _mesh(roof_mesh,pos+Vector3(0,3.6,0),_coastal_surface(3,1.6,Color("#e8b9a2")))
	roof.name = "BandstandRoof"
	var eave := _cylinder(pos+Vector3(0,2.9,0),3.55,0.12,Color("#f1d9a9"))
	_set_registered_surface(eave,_coastal_surface(7,0.9,Color("#d8bd84")))
	_sphere(pos+Vector3(0,4.5,0),0.24,GOLD)
	for index in 6:
		var angle := TAU*float(index)/6.0
		var pennant := _box(pos+Vector3(cos(angle)*3.3,2.62,sin(angle)*3.3),Vector3(0.34,0.4,0.04),[CORAL,GOLD,Color("#64b9bd")][index%3])
		pennant.rotation.y = -angle+PI*0.5
		component_motion.register_component(pennant,"flag",float(index)*0.5)
	var blocker := StaticBody3D.new()
	blocker.name = "BandstandOcclusionBlocker"
	blocker.collision_layer = 0
	blocker.collision_mask = 0
	blocker.position = pos
	add_child(blocker)
	occlusion_controller.finish_building(blocker)

func _build_attraction_districts() -> void:
	var districts := Node3D.new()
	districts.name = "AttractionDistricts"
	add_child(districts)
	# Each court is authored around its old avenue coordinates and then set down,
	# whole, where the layout table places it.
	var wind := _district(districts, "WindSailTerrace", "風帆工坊", ["game-001", "game-002", "game-003", "game-004"], "wind")
	var scenery_start := get_child_count()
	var wind_blocker := _district_occlusion_blocker(wind, "DistrictOcclusionBlocker")
	occlusion_controller.begin_building()
	_build_wind_sail_terrace(wind)
	_adopt_district_geometry(wind, scenery_start)
	occlusion_controller.finish_building(wind_blocker)
	var tide := _district(districts, "TidepoolCourt", "潮池廣場", ["game-005", "game-006", "game-007", "game-008"], "tide")
	scenery_start = get_child_count()
	var tide_blocker := _district_occlusion_blocker(tide, "DistrictOcclusionBlocker")
	occlusion_controller.begin_building()
	_build_tidepool_court(tide)
	_adopt_district_geometry(tide, scenery_start)
	occlusion_controller.finish_building(tide_blocker)
	var lens := _district(districts, "LighthouseLookout", "海風觀景台", ["game-009", "game-010"], "lookout")
	scenery_start = get_child_count()
	var lens_blocker := _district_occlusion_blocker(lens, "DistrictOcclusionBlocker")
	occlusion_controller.begin_building()
	_build_lighthouse_lookout(lens)
	_adopt_district_geometry(lens, scenery_start)
	occlusion_controller.finish_building(lens_blocker)
	var moon := _district(districts, "MoonshadowStage", "月影劇台", ["game-011", "game-012"], "stage")
	scenery_start = get_child_count()
	var moon_blocker := _district_occlusion_blocker(moon, "DistrictOcclusionBlocker")
	occlusion_controller.begin_building()
	_build_moonshadow_stage(moon)
	_adopt_district_geometry(moon, scenery_start)
	occlusion_controller.finish_building(moon_blocker)


func _district_occlusion_blocker(parent: Node3D, blocker_name: String) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.name = blocker_name
	blocker.collision_layer = 0
	blocker.collision_mask = 0
	parent.add_child(blocker)
	return blocker

func _adopt_district_geometry(district: Node3D, first_child_index: int) -> void:
	for child_index in range(get_child_count()-1, first_child_index-1, -1):
		var scenery := get_child(child_index)
		if not scenery is GeometryInstance3D and not scenery is Label3D:
			continue
		remove_child(scenery)
		district.add_child(scenery)

func _district(parent: Node3D, node_name: String, title: String, game_ids: Array[String], layout_id: String) -> Node3D:
	var district := Node3D.new()
	district.name = node_name
	district.position = IslandLayout.district_point(layout_id, Vector3.ZERO)
	district.set_meta("title", title)
	district.set_meta("game_ids", game_ids.duplicate())
	parent.add_child(district)
	return district

func _build_wind_sail_terrace(district: Node3D) -> void:
	# A little maker's court gives the four wind games a destination, not four lawn markers.
	var deck := _box(Vector3(-9.0,0.11,-20.5),Vector3(9.0,0.12,10.0),Color("#775b42"))
	deck.name = "WindWorkshopBoardwalk"
	deck.material_override = _coastal_surface(1,1.8,Color("#ead8b4"))
	var deck_seams: Array[Transform3D] = []
	var seam_colors: Array[Color] = []
	for plank_index in range(12):
		deck_seams.append(Transform3D(Basis().scaled(Vector3(0.035,0.012,9.85)),Vector3(-13.3 + plank_index*0.74,0.178,-20.5)))
		seam_colors.append(Color("#c3a16c"))
	var seams := _multi_mesh(BoxMesh.new(),Vector3.ZERO,deck_seams,seam_colors,_vertex_color_material("deck-seams", 0.9, true))
	seams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Narrow, separated canvas slats leave the kite and balloon silhouettes visible above the counter.
	for post_x in [-11.7,-6.7]:
		for post_z in [-21.65,-19.35]:
			var post := _box(Vector3(post_x,1.2,post_z),Vector3(0.18,2.4,0.18),Color("#594a3b"))
			post.material_override = _coastal_surface(1,1.2,Color("#bd9c6b"))
	for panel_index in range(5):
		var curve := (float(panel_index) - 2.0) / 2.0
		var panel := _box(Vector3(-9.2,2.36 + (1.0 - absf(curve)) * 0.16,-20.5 + curve * 0.66),Vector3(4.8,0.10,0.60),[Color("#3b7475"),Color("#b87864"),Color("#dcc99e")][panel_index % 3])
		panel.material_override = _coastal_surface(2,2.8,[Color("#a7b9a5"),Color("#c98c74"),Color("#e0cda5")][panel_index % 3])
		panel.rotation.x = -curve * 0.14
	var counter := _box(Vector3(-9.0,0.67,-20.4),Vector3(3.2,0.9,0.82),Color("#80583e"))
	counter.name = "WindWorkshopCounter"
	counter.material_override = _coastal_surface(1,1.2,Color("#bd9568"))
	var counter_lip := _box(Vector3(-9.0,1.16,-20.4),Vector3(3.38,0.12,0.96),Color("#d7ad6c"))
	counter_lip.material_override = _coastal_surface(7,0.8,Color("#cfac70"))
	_box(Vector3(-9.0,0.93,-19.97),Vector3(2.9,0.12,0.035),Color("#326e70"))
	# Split mast heights and offset sails make a readable windward profile around the first four points.
	for side: float in [-1.0, 1.0]:
		var x: float = side * 10.7
		var z: float = -20.4 if side < 0.0 else -17.6
		var mast := _box(Vector3(x, 2.15, z), Vector3(0.24, 4.3, 0.24), Color("#6e5b43"))
		mast.material_override = _coastal_surface(1,1.2,Color("#c4a171"))
		var sail := _box(Vector3(x + side*0.72, 3.05, z), Vector3(1.4, 1.9, 0.08), Color("#4c8488" if side < 0.0 else "#d88767"))
		sail.material_override = _coastal_surface(6,1.5,Color("#dcd0b6"))
		var sail_tip := _cone(Vector3(x + side*0.7, 4.25, z), Color("#f1d9a7"))
		sail_tip.rotation.z = -side*0.18
		sail_tip.scale = Vector3(0.88, 0.68, 0.16)
		var lower_sail := _box(Vector3(x - side*0.55, 1.75, z+0.08), Vector3(0.9, 1.15, 0.06), Color("#edbb65"))
		lower_sail.material_override = _coastal_surface(6,1.5,Color("#e0cda5"))
		lower_sail.rotation.z = side*0.14
		for j in range(3):
			var streamer := _box(Vector3(x + side*(0.22+j*0.2), 4.45+j*0.12, z+0.08), Vector3(0.04, 0.55, 0.035), Color("#fff0c8" if j%2==0 else "#e1a272"))
			streamer.rotation.z = -side*(0.08+j*0.06)
	var ridge := _box(Vector3(0, 0.205, -20.7), Vector3(22, 0.035, 0.1), Color("#c7a975"))
	ridge.material_override = _wood_material(Color("#c7a975"))
	_district_label("風向與飛行", Vector3(0, 3.8, -25.0), 24, Color("#e9d4a4"))

func _build_tidepool_court(district: Node3D) -> void:
	# Four shallow basins sit in the gaps between the east-court game points, leaving clear approaches around a low fountain.
	var court := _box(Vector3(9.0,0.105,-30.1),Vector3(9.4,0.09,7.35),Color("#526d67"))
	court.name = "TidepoolStoneCourt"
	court.material_override = _coastal_surface(0,1.8,Color("#cbb995"))
	var basin_centers := [Vector3(5.2,0.22,-29.8), Vector3(8.15,0.22,-27.5), Vector3(8.85,0.22,-32.5), Vector3(12.4,0.22,-29.9)]
	var basin_radii := [0.82, 0.78, 0.74, 0.86]
	for index in range(basin_centers.size()):
		var center: Vector3 = basin_centers[index]
		var radius: float = basin_radii[index]
		var plinth := _cylinder(center, radius + 0.22, 0.30, Color("#958064"))
		plinth.material_override = _coastal_surface(4,1.5,Color("#d2bf9a"))
		plinth.rotation.y = float(index)*0.21
		var pool_surface := _cylinder(center+Vector3(0,0.2,0), radius * 0.78, 0.12, Color("#438f8b"))
		pool_surface.material_override = sea_material
		var mosaic := _cylinder(center+Vector3(0,0.29,0), radius * 0.50, 0.07, Color("#418e8a"))
		mosaic.material_override = _coastal_surface(5,0.65)
		for shell_index in range(3):
			var angle := TAU * float(shell_index) / 3.0 + float(index) * 0.37
			var shell_pos := center + Vector3(cos(angle) * (radius + 0.04),0.43,sin(angle) * (radius + 0.04))
			var shell := _sphere(shell_pos,0.16,Color("#c5aa77") if (index + shell_index) % 2 == 0 else Color("#ca735b"))
			shell.scale=Vector3(1.35,0.62,0.82)
	# A modest shared bubbler gives the four pools one court landmark without filling their walkable gaps.
	var bubbler_base := _cylinder(Vector3(9.8,0.25,-30.0),0.68,0.20,Color("#87765d"))
	bubbler_base.material_override = _coastal_surface(4,1.1,Color("#b6a180"))
	var bubbler_rim := _cylinder(Vector3(9.8,0.39,-30.0),0.49,0.10,Color("#73aaa2"))
	bubbler_rim.material_override = _coastal_surface(5,0.7,Color("#b9d5c5"))
	var bubbler_water := _cylinder(Vector3(9.8,0.49,-30.0),0.34,0.06,Color("#438f8b"))
	bubbler_water.material_override = sea_material
	var bubbler_spout := _cylinder(Vector3(9.8,0.84,-30.0),0.12,0.64,Color("#c1a877"))
	bubbler_spout.material_override = _coastal_surface(7,0.7,Color("#c4aa79"))
	_sphere(Vector3(9.8,1.21,-30.0),0.12,Color("#87c8bf"))
	_district_label("潮池・拾光",Vector3(9.0, 2.2, -30.8), 22, Color("#d9e2c1"))

func _build_lighthouse_lookout(district: Node3D) -> void:
	# The narrow lantern tower and low open rail keep the view to the sea unobstructed.
	var tower_x := 11.4
	var tower_z := -36.2
	var deck := _box(Vector3(tower_x,0.48,tower_z),Vector3(4.8,0.2,4.2),Color("#ad9670"),true)
	deck.name = "CoastalLookoutDeck"
	deck.material_override = _coastal_surface(1,1.8,Color("#dfc79e"))
	var deck_body := deck.get_child(0) as StaticBody3D
	var deck_shape := deck_body.get_child(0) as CollisionShape3D
	var deck_box := BoxShape3D.new()
	deck_box.size=Vector3(4.8,0.2,4.2)
	deck_shape.shape=deck_box
	var promenade_link := _box(Vector3(5.45,0.10,tower_z),Vector3(2.1,0.20,2.8),Color("#8e7455"),true)
	promenade_link.name = "LookoutPromenadeLink"
	promenade_link.material_override = _coastal_surface(1,1.8,Color("#d2ba91"))
	# Finish the slope at the deck's front edge, with a small overlap above it.
	# Extending the old shallow ramp behind the deck left a 0.17m blocking lip.
	var ramp_angle:=atan(0.4/2.5)
	var ramp_length:=2.5/cos(ramp_angle)
	var ramp := _box(Vector3(7.75,0.37,tower_z),Vector3(ramp_length,0.06,3.2),Color("#92734f"),true)
	ramp.material_override = _coastal_surface(1,1.8,Color("#d6b98b"))
	ramp.rotation.z=ramp_angle
	var ramp_body := ramp.get_child(0) as StaticBody3D
	var ramp_shape := ramp_body.get_child(0) as CollisionShape3D
	var ramp_box := BoxShape3D.new()
	ramp_box.size=Vector3(ramp_length,0.06,3.2)
	ramp_shape.shape=ramp_box
	var treads: Array[Transform3D] = []
	var tread_colors: Array[Color] = []
	for index in range(8):
		var x := 6.6+index*0.35
		treads.append(Transform3D(Basis().rotated(Vector3.BACK,ramp_angle).scaled(Vector3(0.06,0.04,3.08)),Vector3(x,0.41+(x-7.75)*0.16,tower_z)))
		tread_colors.append(Color.WHITE)
	_multi_mesh(BoxMesh.new(),Vector3.ZERO,treads,tread_colors,_coastal_surface(7,0.45,Color("#c4a06e")))
	_cylinder(Vector3(tower_x,0.42,tower_z),1.55,0.32,Color("#685944"))
	var tower_wall := _cylinder(Vector3(tower_x,1.55,tower_z),0.65,2.0,Color("#b99a6c"),0.78,true)
	tower_wall.name="LighthouseWall"
	tower_wall.get_child(0).name="LighthouseWallCollision"
	tower_wall.material_override = _coastal_surface(4,1.8,Color("#ddcda8"))
	var tower_band := _cylinder(Vector3(tower_x,0.82,tower_z),0.72,0.18,Color("#3f7776"),0.84)
	for side: float in [-1.0,1.0]:
		var rail_post := _box(Vector3(tower_x+side*1.02,0.75,tower_z+0.35),Vector3(0.08,0.92,1.55),Color("#67503b"))
		rail_post.material_override = _wood_material(Color("#67503b"))
		_box(Vector3(tower_x+side*1.02,1.3,tower_z+0.35),Vector3(0.08,0.08,1.55),Color("#dfc89c"))
	for j in range(4):
		var y: float = 2.55+j*0.38
		var band := _cylinder(Vector3(tower_x,y,tower_z),1.0-j*0.12,0.16,Color("#5f8b8b") if j%2==0 else Color("#eed39e"))
		band.material_override = _coastal_surface(2 if j%2==0 else 7,0.75,Color("#acc0a8" if j%2==0 else "#cbb17c"))
		band.rotation.y=j*0.18
	var lantern := _sphere(Vector3(tower_x,4.05,tower_z),0.38,Color("#f4d78c"))
	lantern.material_override = _mat(Color("#f4d78c"),true)
	for side: float in [-1.0,1.0]:
		var beam := _box(Vector3(tower_x+side*1.4,4.05,tower_z),Vector3(1.35,0.05,0.05),Color("#e0cf9e"))
		beam.material_override = _coastal_surface(7,0.5,Color("#c2a16b"))
		beam.rotation.y=side*0.12
	_district_label("看見海面",Vector3(tower_x,4.65,tower_z),22,Color("#e5d9bd"))

func _build_moonshadow_stage(district: Node3D) -> void:
	# A crescent proscenium and stepped open seating give the final pair a stage silhouette.
	for side in [-1.0,1.0]:
		var pier := _box(Vector3(side*11.0,1.7,-40.1),Vector3(0.34,3.4,0.42),Color("#725e72"),true)
		var cap := _cone(Vector3(side*11.0,3.58,-40.1),Color("#c78368" if side<0.0 else "#d6b268"))
		cap.scale=Vector3(0.45,0.52,0.28)
	var proscenium := _box(Vector3(0,3.3,-40.1),Vector3(21.2,0.38,0.54),Color("#a45c48"))
	proscenium.material_override = _coastal_surface(3,1.8,Color("#f0d5bd"))
	var trim := _box(Vector3(0,3.53,-39.78),Vector3(20.7,0.08,0.11),Color("#ddba78"))
	trim.material_override = _coastal_surface(7,0.8,Color("#d0b274"))
	var crescent := _mesh(TorusMesh.new(),Vector3(0.0,2.15,-40.1),_mat(Color("#d9b768")))
	crescent.scale=Vector3(1.28,1.28,0.16)
	crescent.rotation_degrees.x=90
	# A shallow, broken canopy shades the rear seats without covering the crescent or stage face.
	for panel_index in range(5):
		var curve := (float(panel_index) - 2.0) / 2.0
		var shade_panel := _box(Vector3(curve * 1.35,2.34 + (1.0 - absf(curve)) * 0.20,-42.0),Vector3(1.20,0.10,2.15),[Color("#536e73"),Color("#6c5b74"),Color("#8c6d75")][panel_index % 3])
		shade_panel.material_override = _coastal_surface(6,2.2,[Color("#91aaa1"),Color("#ad95a6"),Color("#c39480")][panel_index % 3])
		shade_panel.rotation.z = -curve * 0.09
	for row in range(3):
		var bench := _box(Vector3(0,0.32+row*0.22,-41.2-row*0.75),Vector3(7.4-row*0.8,0.16,0.36),Color("#8e6c50" if row%2==0 else "#a17d58"))
		bench.material_override = _wood_material(Color("#8e6c50" if row%2==0 else "#a17d58"))
	var deck := _box(Vector3(0,0.105,-40.45),Vector3(14.0,0.10,6.6),Color("#73563e"))
	deck.name = "MoonshadowStageDeck"
	deck.material_override = _coastal_surface(1,1.7,Color("#d2b893"))
	var stage_seams: Array[Transform3D] = []
	var seam_colors: Array[Color] = []
	for plank_index in range(14):
		stage_seams.append(Transform3D(Basis().scaled(Vector3(13.7,0.018,0.035)),Vector3(0,0.16,-43.6 + plank_index*0.48)))
		seam_colors.append(Color.WHITE)
	var seams := _multi_mesh(BoxMesh.new(),Vector3.ZERO,stage_seams,seam_colors,_coastal_surface(7,0.7,Color("#ba9a64")))
	seams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_district_label("月影劇台",Vector3(0,4.05,-40.0),24,Color("#e2d2b0"))

func _game_feature(index: int, pos: Vector3, color: Color) -> void:
	# Each booth gets a large, readable silhouette of the activity on offer.
	match index:
		0: # Balloon delivery: cluster, threads and a small parcel basket.
			for j in range(3):
				var balloon := _sphere(pos+Vector3(-0.65+j*0.65,3.7+j*0.18,0),0.36,[CORAL,GOLD,Color("#77c7ce")][j])
				component_motion.register_component(balloon,"balloon",float(j))
				_box(pos+Vector3(-0.65+j*0.65,3.25,0),Vector3(0.025,0.38,0.025),CREAM)
			_box(pos+Vector3(0,3.02,0),Vector3(0.64,0.27,0.46),Color("#9a7149"))
		1: # Kite-ring course: paper kite tails and three target hoops.
			for j in range(3):
				var hoop := _mesh(TorusMesh.new(),pos+Vector3(-0.82+j*0.82,3.5-j*0.14,0),_mat([CORAL,GOLD,TEAL][j]))
				hoop.scale=Vector3(0.34,0.34,0.22)
				hoop.rotation_degrees.x=90
			var kite := _cone(pos+Vector3(0,4.05,-0.12),color)
			kite.rotation_degrees.z=45
			kite.scale=Vector3(0.58,0.7,0.16)
			for j in range(3): _box(pos+Vector3(0,3.25-j*0.2,0.12),Vector3(0.28,0.045,0.04),CORAL if j%2==0 else GOLD)
		2: # Fountain photo: scalloped basin and a crown of paper jets.
			_cylinder(pos+Vector3(0,3.05,0),0.95,0.25,CREAM)
			_cylinder(pos+Vector3(0,3.22,0),0.78,0.13,Color("#62b8c1"))
			_cylinder(pos+Vector3(0,3.48,0),0.18,0.58,Color("#d0b37d"))
			for j in range(6):
				var a := j*TAU/6.0
				var jet := _box(pos+Vector3(cos(a)*0.56,3.57,sin(a)*0.56),Vector3(0.07,0.64,0.07),Color("#7dcbd0"))
				jet.rotation.z=cos(a)*0.32
		3: # Crowd director: three arrow signs and a striped queue post.
			for j in range(3):
				var y := 3.3+j*0.37
				_box(pos+Vector3(0,y,0),Vector3(0.1,0.7,0.1),Color("#745b42"))
				var arrow := _box(pos+Vector3(-0.54+j*0.54,y+0.26,0),Vector3(0.74,0.28,0.13),[CORAL,GOLD,TEAL][j])
				arrow.rotation.z=0.08*(j-1)
				var tip := _cone(pos+Vector3(-0.15+j*0.54,y+0.26,0),[CORAL,GOLD,TEAL][j])
				tip.rotation_degrees.z=-90
				tip.scale=Vector3(0.2,0.3,0.12)
		4: # Hat rescue: oversized top hat above a striped hat stand.
			_cylinder(pos+Vector3(0,3.08,0),0.92,0.15,GOLD)
			_cylinder(pos+Vector3(0,3.48,0),0.52,0.72,Color("#514258"),0.58)
			_box(pos+Vector3(0,3.35,0.51),Vector3(0.58,0.11,0.05),CORAL)
		5: # Ribbon rhythm: three curling strips on a music staff.
			for j in range(3):
				var strip := _box(pos+Vector3(0,3.15+j*0.23,0),Vector3(2.1,0.09,0.16),[CORAL,GOLD,Color("#64b9bd")][j])
				strip.rotation.z=sin(j*2.1)*0.19
				_box(pos+Vector3(-0.8+j*0.8,3.7,0),Vector3(0.13,0.32,0.13),CREAM)
		6: # Flower puzzle: color tiles around a layered rosette.
			for j in range(8):
				var a := j*TAU/8.0
				var petal := _box(pos+Vector3(cos(a)*0.65,3.3,sin(a)*0.65),Vector3(0.42,0.11,0.26),[CORAL,GOLD,Color("#84aa69")][j%3])
				petal.rotation.y=-a
			_sphere(pos+Vector3(0,3.42,0),0.27,Color("#fff0bd"))
		7: # Sign balance: seesaw plank, brass fulcrum and two sign weights.
			var beam := _box(pos+Vector3(0,3.35,0),Vector3(2.3,0.18,0.34),Color("#9a7149"))
			beam.rotation.z=0.16
			var fulcrum := _cone(pos+Vector3(0,3.02,0),CORAL)
			fulcrum.scale=Vector3(0.45,0.42,0.35)
			for side in [-1,1]:
				_box(pos+Vector3(side*0.9,3.67,0),Vector3(0.62,0.45,0.12),TEAL if side<0 else GOLD)
		8: # Shadow hide-and-seek: moon, sun and a hinged shadow screen.
			var screen := _box(pos+Vector3(0,3.38,0),Vector3(1.85,1.25,0.12),Color("#423d58"))
			_box(pos+Vector3(0,2.72,0.08),Vector3(2.15,0.12,0.18),Color("#876843"))
			_sphere(pos+Vector3(-0.48,3.55,0.12),0.28,Color("#f1d48f"))
			_box(pos+Vector3(0.5,3.28,0.14),Vector3(0.6,0.65,0.09),Color("#7e8a96"))
		9: # Bubble portraits: hoop frame, shiny bubbles and a standing photo card.
			var ring := _mesh(TorusMesh.new(),pos+Vector3(0,3.56,0),_mat(Color("#b3e7df")))
			ring.scale=Vector3(0.76,0.92,0.18)
			ring.rotation_degrees.x=90
			for j in range(4):
				var bubble := _sphere(pos+Vector3(-0.58+(j%2)*1.15,3.18+(j/2)*0.64,0.22),0.22,Color("#a6dce0"))
				bubble.material_override=_bubble_material()
				_box(pos+Vector3(-0.44+(j%2)*1.15,3.24+(j/2)*0.64,0.41),Vector3(0.08,0.06,0.035),CREAM)
		10: # Bench swap: paired paper seats with contrasting cushions.
			for side in [-1,1]:
				_box(pos+Vector3(side*0.58,3.0,0),Vector3(0.88,0.15,0.55),GOLD if side<0 else CORAL)
				_box(pos+Vector3(side*0.58,3.48,-0.2),Vector3(0.88,0.76,0.14),Color("#9b7d5c"))
				for leg in [-1,1]: _box(pos+Vector3(side*0.58+leg*0.31,2.76,0),Vector3(0.08,0.46,0.08),Color("#654f3c"))
		11: # Welcome ensemble: little drums, brass chimes and a conductor's baton.
			for j in range(3):
				_cylinder(pos+Vector3(-0.78+j*0.78,3.1,0),0.36,0.5,[CORAL,GOLD,TEAL][j],0.31)
				_box(pos+Vector3(-0.78+j*0.78,3.38,0),Vector3(0.62,0.06,0.62),CREAM)
				_box(pos+Vector3(-0.78+j*0.78,3.85,0),Vector3(0.07,0.78,0.07),Color("#d6bc86"))
			_label("♫",pos+Vector3(0,4.28,0),42,GOLD)

func _bubble_material() -> StandardMaterial3D:
	if bubble_material == null:
		bubble_material=StandardMaterial3D.new()
		bubble_material.albedo_color=Color(0.62,0.85,0.88,0.55)
		bubble_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		bubble_material.roughness=0.12
		bubble_material.metallic=0.18
	return bubble_material

func park_data() -> Dictionary:
	var path := "res://design/01-park/park.json"
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is not Dictionary or value.get("zones") is not Array:
		push_warning("Invalid park data at "+path+"; entrances unavailable")
		return {"zones":[]}
	var zones: Array=[]
	for zone in value.zones:
		if zone is Dictionary and zone.get("id") is String and zone.get("name") is String and zone.get("theme") is String and zone.get("threshold") is float:
			zones.append(zone)
		else: push_warning("Invalid park zone at "+path+"; entry ignored")
	# The optional final zone has its own gate after the ten regions.
	var final: Variant = value.get("final")
	if final is Dictionary and final.get("id") is String and final.get("name") is String and final.get("normal_required") is float:
		zones.append({"id": final.id, "name": final.name, "theme": FINAL_THEME, "threshold": final.normal_required})
	return {"zones":zones}

func _build_wayfinding() -> void:
	var signs := Node3D.new()
	signs.name = "WelcomeWayfinding"
	signs.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(signs)
	_wayfinding_trim = StandardMaterial3D.new()
	_wayfinding_trim.albedo_color = Color("#a26d43")
	_wayfinding_trim.emission_enabled = true
	_wayfinding_trim.emission = Color("#ffd088")
	for entry in [
		["Dock", Vector2(3.6, 9.3), "海風碼頭  ↓"],
		["Avenue", Vector2(3.6, -7.2), "迎賓大道  ↑"],
		["Nightmarket", Vector2(-5.6, 7.35), "夜市入口  ↖"],
	]:
		var anchor: Vector2 = entry[1]
		var base := Vector3(anchor.x, 0.0, anchor.y)
		base.y = ground_surface_y(base)
		var plaque := Node3D.new()
		plaque.name = entry[0]
		signs.add_child(plaque)
		_wayfinding_mesh(plaque, base + Vector3(0, 0.39, 0), Vector3(0.16, 0.78, 0.16), Color("#76553d"))
		_wayfinding_mesh(plaque, base + Vector3(0, 0.99, 0), Vector3(3.70, 0.76, 0.13), Color("#18383d"))
		var trim := _wayfinding_mesh(plaque, base + Vector3(0, 0.66, 0.075), Vector3(3.52, 0.07, 0.04), GOLD)
		trim.name = "Trim"
		trim.material_override = _wayfinding_trim
		var label := _label(entry[2], base + Vector3(0, 1.04, 0.09), 38)
		label.name = "Title"
		label.set_meta(SIGN_TITLE, true)
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.reparent(plaque)

func _wayfinding_mesh(plaque: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := _box(position, size, color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = 34.0
	mesh.reparent(plaque)
	return mesh


func _build_gates() -> void:
	# Every region gate stands at the island's edge, at the end of the road that
	# heads toward its district. Each is built at the origin and then set in place.
	var zones: Array = park_data().get("zones",[])
	for i in range(1,zones.size()):
		var zone: Dictionary=zones[i]
		var region: String = zone["id"]
		if not IslandLayout.has_gate(region):
			push_warning("No gate site for region '%s'; gate omitted." % region)
			continue
		var gate := Node3D.new()
		gate.name = "Gate_" + region
		add_child(gate)
		gate.position = IslandLayout.gate_position(region)
		gate.rotation.y = IslandLayout.gate_yaw(region)
		_fitting_space = gate.transform
		# A gate facing away from the camera stands between it and the visitor at the
		# gate, so it opens like a building while someone stands behind it.
		var faces_away := cos(gate.rotation.y) < 0.0
		var see_through: StaticBody3D = _district_occlusion_blocker(gate, "GateOcclusionBlocker") if faces_away else null
		if faces_away: occlusion_controller.begin_building()
		var first_part := get_child_count()
		var zone_color: Color = [Color("#28737a"),Color("#e2795e"),Color("#e2ae4f"),Color("#725985"),Color("#47718a"),Color("#678858"),Color("#5295a0"),Color("#42638a"),Color("#865d71"),Color("#7a2238")][i-1]
		var pos := Vector3.ZERO
		var gate_floor := _box(pos+Vector3(0,0.18,0),Vector3(3.9,0.22,1.5),Color("#958064"))
		gate_floor.material_override = _coastal_surface(0,1.6,Color("#d8c39f"))
		for pillar_side in [-1,1]:
			var gate_pillar := _box(pos+Vector3(pillar_side*1.25,1.35,0),Vector3(0.42,2.7,0.5),Color("#ac9875"),true)
			gate_pillar.material_override = _coastal_surface(4,1.5,Color("#e0cdaa"))
			var gate_foot := _box(pos+Vector3(pillar_side*1.25,0.55,0),Vector3(0.8,0.32,0.75),Color("#a98d68"))
			gate_foot.material_override = _coastal_surface(7,0.7,Color("#c5a66f"))
			var gate_cap := _box(pos+Vector3(pillar_side*1.25,2.48,0),Vector3(0.76,0.26,0.72),zone_color)
			gate_cap.material_override = _coastal_surface(2,0.8,zone_color.lightened(0.14))
			_lantern(pos+Vector3(pillar_side*1.25,2.08,0.38))
		var gate_header := _box(pos+Vector3(0,2.8,0),Vector3(3.25,0.48,0.66),zone_color)
		gate_header.material_override = _coastal_surface(3,1.4,zone_color.lightened(0.12))
		_box(pos+Vector3(0,2.49,0),Vector3(2.65,0.12,0.8),Color("#f2d8a5"))
		_zone_crown(i,pos,zone_color)
		# A gate that faces away from the camera carries its words on the side the camera sees.
		var face := -1.0 if faces_away else 1.0
		_local_label(zone["name"],pos+Vector3(0,2.76,0.37*face),20).set_meta(SIGN_TITLE, true)
		_local_label(ZONE_ICONS[i-1],pos+Vector3(0,1.75,0.43*face),28,GOLD)
		_adopt_district_geometry(gate,first_part)
		if faces_away: occlusion_controller.finish_building(see_through)
		_fitting_space = Transform3D.IDENTITY
		if DistrictSites.has(region): _add_gate_leaves(gate, region)
		_point("gate:"+region,zone["name"],IslandLayout.gate_point(region))
		var open := RegionRoutes.supports(region)
		var required: int = RegionRoutes.threshold(region) if open else int(zone["threshold"])
		var status := "%d 張 · %s" % [required, "不消耗" if open else "準備中"]
		_local_label(status, gate.transform * Vector3(0,1.1,0.48*face), 19).name = "GateStatus_" + region
		# A gate far from the plaza needs its own light after dark; it joins the shared budget.
		var light := OmniLight3D.new()
		light.name = "GateLamp_" + region
		light.position = gate.transform * Vector3(0,2.3,1.2)
		light.light_color = Color("#ffd49a")
		light.omni_range = 6.5
		light.light_energy = 0.0
		add_child(light)
		lamps.append(light)

const GATE_OPEN_ANGLE := 1.75
const GATE_SWING_SECONDS := 0.9

## Two barred leaves between the pillars: shut until the district's sticker
## threshold is met, and you can see through them.
func _add_gate_leaves(gate: Node3D, region: String) -> void:
	if _gate_leaf_mesh == null:
		var bars := SurfaceTool.new()
		bars.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bar := BoxMesh.new()
		for index in 6:
			bars.append_from(bar, 0, Transform3D(Basis().scaled(Vector3(0.06, 1.62, 0.06)), Vector3(0.1 + float(index) * 0.17, 1.13, 0)))
		for rail: float in [0.36, 1.9]:
			bars.append_from(bar, 0, Transform3D(Basis().scaled(Vector3(1.0, 0.09, 0.08)), Vector3(0.52, rail, 0)))
		_gate_leaf_mesh = bars.commit()
	var leaves: Array[MeshInstance3D] = []
	for side: float in [-1.0, 1.0]:
		var leaf := MeshInstance3D.new()
		leaf.name = "GateLeaf"
		leaf.mesh = _gate_leaf_mesh
		leaf.material_override = _mat(Color("#2c4a4d"))
		# Hinged on its pillar; the right leaf is the left one turned round.
		leaf.position = Vector3(side * 1.04, 0, 0)
		leaf.rotation.y = 0.0 if side < 0.0 else PI
		leaf.set_meta("hinge", side)
		gate.add_child(leaf)
		leaves.append(leaf)
		mesh_count += 1
	_gate_leaves[region] = leaves

## Swing a district's gate open or shut and reword its sign.
func show_gate(region: String, open: bool, celebrate: bool) -> void:
	var status := find_child("GateStatus_" + region, false, false) as Label3D
	if status != null:
		if is_instance_valid(district_host) and district_host.failed.has(region): status.text = "整修中 · 暫停開放"
		elif open: status.text = "已開放 · 請進"
		elif RegionRoutes.counts_down(region) and is_instance_valid(district_host) and district_host.sticker_count() >= 0:
			status.text = "%d 張 · 還差 %d 張" % [RegionRoutes.threshold(region), RegionRoutes.threshold(region) - district_host.sticker_count()]
		else: status.text = "%d 張 · 不消耗" % RegionRoutes.threshold(region)
	for leaf: MeshInstance3D in _gate_leaves.get(region, []):
		var side: float = leaf.get_meta("hinge")
		var closed := 0.0 if side < 0.0 else PI
		var target := closed - (side * GATE_OPEN_ANGLE if open else 0.0)
		if celebrate and not reduced_motion and is_inside_tree():
			create_tween().tween_property(leaf, "rotation:y", target, GATE_SWING_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			leaf.rotation.y = target
	if celebrate: play_action("celebrate")

func gate_leaf_angle(region: String) -> float:
	var leaves: Array = _gate_leaves.get(region, [])
	return absf(float(leaves[0].rotation.y)) if not leaves.is_empty() else 0.0

func _zone_crown(index: int, pos: Vector3, color: Color) -> void:
	match index:
		1: # Lighthouse beacon, lantern room and cap.
			_cylinder(pos+Vector3(0,3.72,0),0.27,1.45,CREAM)
			_cylinder(pos+Vector3(0,4.52,0),0.4,0.2,GOLD)
			var beacon := _box(pos+Vector3(0,3.98,0),Vector3(0.42,0.45,0.42),Color("#f7d68f"))
			beacon.material_override=_mat(Color("#f7d68f"),true)
			var cap := _cone(pos+Vector3(0,4.68,0),color)
			cap.scale=Vector3(0.48,0.38,0.48)
		2: # Candy spool and wrapped sugar pinwheels.
			for side in [-1,1]:
				_cylinder(pos+Vector3(side*0.62,3.52,0),0.16,1.18,Color("#f1d6a8"))
				for row in range(3): _box(pos+Vector3(side*0.62,3.18+row*0.34,0.2),Vector3(0.34,0.12,0.09),CORAL if row%2==0 else CREAM)
			_cylinder(pos+Vector3(0,3.55,0),0.42,0.46,color)
			_cylinder(pos+Vector3(0,3.82,0),0.5,0.08,GOLD)
		3: # Night market pagoda roof and hanging lanterns.
			for row in range(2):
				var eave_size := Vector3(1.32-row*0.19,0.28,0.55)
				var eave := _mesh(CylinderMesh.new(),pos+Vector3(0,3.42+row*0.38,0),_finish(color if row==0 else Color("#8d4f4c"),eave_size))
				eave.scale=eave_size*Vector3(1,0.5,1)
			for side in [-1,1]: _lantern(pos+Vector3(side*0.88,3.45,0.5))
		4: # Circus tent peak and striped paper canopy.
			var tent := _cone(pos+Vector3(0,3.75,0),color)
			tent.scale=Vector3(1.25,1.15,0.62)
			_set_registered_surface(tent,_finish(color,tent.scale))
			for side in [-1,1]:
				var stripe := _box(pos+Vector3(side*0.38,3.4,0.31),Vector3(0.14,0.72,0.06),CREAM)
				stripe.rotation.z=side*0.24
		5: # Toy city clock tower with two visible hands.
			_box(pos+Vector3(0,3.7,0),Vector3(0.6,1.1,0.55),Color("#98714e"))
			_cylinder(pos+Vector3(0,4.22,0.32),0.34,0.1,CREAM)
			_box(pos+Vector3(0,4.38,0.4),Vector3(0.035,0.24,0.035),Color("#514858"))
			_box(pos+Vector3(0.08,4.29,0.4),Vector3(0.18,0.035,0.035),Color("#514858"))
			var turret := _cone(pos+Vector3(0,4.43,0),color)
			turret.scale=Vector3(0.44,0.36,0.44)
		6: # Greenhouse flower crown, leaf blades and paper blossoms.
			for side in [-1,1]:
				var leaf := _box(pos+Vector3(side*0.52,3.54,0),Vector3(0.65,0.17,0.24),Color("#78945d"))
				leaf.rotation.z=side*0.4
				_sphere(pos+Vector3(side*0.72,3.86,0.12),0.18,CORAL if side<0 else GOLD)
			_sphere(pos+Vector3(0,3.72,0),0.25,CREAM)
		7: # Science flask with a thick glass neck and colored contents.
			_cylinder(pos+Vector3(0,3.55,0),0.43,0.1,Color("#6a9b9c"),0.24)
			_cylinder(pos+Vector3(0,3.88,0),0.27,0.62,Color("#89c7c8"),0.13)
			_box(pos+Vector3(0,4.25,0),Vector3(0.42,0.09,0.42),GOLD)
			_sphere(pos+Vector3(0,3.55,0.18),0.16,Color("#eb9c6c"))
		8: # Planet model with a tilted paper ring.
			_sphere(pos+Vector3(0,3.67,0),0.42,Color("#df9870"))
			var orbit := _mesh(TorusMesh.new(),pos+Vector3(0,3.67,0),_mat(CREAM))
			orbit.scale=Vector3(0.82,0.36,0.3)
			orbit.rotation.z=0.32
			for side in [-1,1]: _box(pos+Vector3(side*0.72,4.0,0),Vector3(0.11,0.11,0.11),GOLD)
		10: # The final gate wears the theatre's devil mask over a velvet swag, as one piece.
			var mask := SceneryKit.Sculpt.new()
			mask.ball(Vector3.ZERO,0.42,color,color.lightened(0.1),10,4,0.85)
			for side in [-1.0,1.0]:
				mask.tube(Vector3(side*0.3,0.42,0),0.1,0.0,0.34,CREAM,6,Basis(Vector3.BACK,-side*0.4))
				mask.ball(Vector3(side*0.16,0.06,0.3),0.07,GOLD,Color.TRANSPARENT,6,3)
				mask.box(Vector3(side*0.85,-0.37,0.1),Vector3(0.5,0.5,0.06),color.darkened(0.2),Basis(Vector3.BACK,side*0.5))
			_mesh(mask.mesh(),pos+Vector3(0,3.62,0),_vertex_color_material("gate-mask"))
		9: # The last gate is a freestanding mirror oval with a key-like crest.
			var portal := _mesh(TorusMesh.new(),pos+Vector3(0,3.83,0),_mat(Color("#b9d9d8")))
			portal.scale=Vector3(0.72,1.05,0.22)
			portal.rotation_degrees.x=90
			_gate_mirror(pos+Vector3(0,3.8,-0.06))
			_cylinder(pos+Vector3(0,4.91,0),0.16,0.4,GOLD)

## An oval looking-glass with two diagonal glints, filling the cinema gate's portal.
func _gate_mirror(at: Vector3) -> void:
	var glass := SceneryKit.Sculpt.new()
	glass.tube(Vector3.ZERO,1.0,1.0,0.06,Color("#6f9aa2"),20,Basis.from_scale(Vector3(0.54,0.81,1.0))*Basis(Vector3.RIGHT,PI*0.5))
	for glint: Vector4 in [Vector4(-0.4,-0.1,0.14,0.5),Vector4(-0.18,-0.25,0.06,0.45)]:
		var a := Vector3(glint.x,glint.y,0.035)
		var rise := Vector3(glint.w,glint.w,0)
		glass.quad(a,a+rise,a+rise+Vector3(glint.z,0,0),a+Vector3(glint.z,0,0),Color("#d6ecea"))
	_mesh(glass.mesh(),at,_vertex_color_material("gate-mirror",0.25))

func _fit_npc_rest_texture(texture: Texture2D) -> Texture2D:
	var source := texture.get_image() if texture != null else null
	if source == null or source.is_empty(): return texture
	var used := source.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0: return texture
	var body := source.get_region(used)
	var scale := minf(float(NpcActivityScript.ACTION_MAX_HEIGHT)/used.size.y, float(NpcActivityScript.ACTION_CANVAS_SIZE.x-4)/used.size.x)
	body.resize(maxi(1,roundi(used.size.x*scale)),maxi(1,roundi(used.size.y*scale)),Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(NpcActivityScript.ACTION_CANVAS_SIZE.x,NpcActivityScript.ACTION_CANVAS_SIZE.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(body,Rect2i(Vector2i.ZERO,body.get_size()),Vector2i((canvas.get_width()-body.get_width())/2,NpcActivityScript.ACTION_FEET_ROW-body.get_height()+1))
	return ImageTexture.create_from_image(canvas)

func _npc(pos: Vector3, color: Color, title: String) -> void:
	var activity_root := Node3D.new()
	activity_root.name = "%sActivityRoot" % title
	activity_root.position = pos
	add_child(activity_root)
	var ground_anchor := Node3D.new()
	ground_anchor.name = "BillboardGroundAnchor"
	activity_root.add_child(ground_anchor)
	var sprite := Sprite3D.new()
	var role := "ticket"
	if title == "小角": role = "imp"
	elif title == "阿浪": role = "announcer"
	var identity_region: Rect2i = IDENTITY_REGIONS[role]
	if identity_textures.has(role):
		sprite.texture=identity_textures[role]
		sprite.pixel_size=2.4 / float(identity_region.size.y)
	else:
		sprite.texture=_character_texture(role,color,"front",0)
		sprite.pixel_size=0.05
	# Reduced motion restores this rest texture. It must use the same canvas and
	# foot row as activity frames, rather than an incompatible cropped identity.
	var rest_frames := NpcActivityScript.load_action_frames(role)
	if rest_frames.size() == 4:
		sprite.texture = rest_frames[0]
	else:
		sprite.texture = _fit_npc_rest_texture(sprite.texture)
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size=2.4/float(NpcActivityScript.ACTION_VISIBLE_HEIGHT)
	var feet_offset := float(NpcActivityScript.ACTION_FEET_ROW)-float(NpcActivityScript.ACTION_CANVAS_SIZE.y)*0.5
	sprite.position=Vector3(0.0,sprite.pixel_size*feet_offset,0.0)
	sprite.shaded=true
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var breath_rate := 0.74 if role=="ticket" else (1.23 if role=="imp" else 0.53)
	var phase := 0.45 if role=="ticket" else (1.9 if role=="imp" else 3.2)
	var idle_role := 1 if role=="ticket" else (2 if role=="imp" else 3)
	# NPC identity and action atlases already author each full-body pose. Keep
	# Sprite lighting, but do not displace those pixels a second time in shader.
	_set_living_sprite_material(sprite,1,phase,breath_rate,idle_role,false)
	ground_anchor.add_child(sprite)
	var ground_y := ground_surface_y(pos)
	_register_sprite_ground_anchor(sprite,ground_anchor,activity_root,ground_y,float(NpcActivityScript.ACTION_FEET_ROW),float(NpcActivityScript.ACTION_CANVAS_SIZE.y))
	_add_contact_shadow(activity_root,Vector3(0,ground_y-activity_root.global_position.y+0.005,0),Vector2(0.78,0.46))
	_add_actor_shadow_proxy(activity_root,role,ground_y-activity_root.global_position.y,sprite)
	var name_label := _label(title,pos+Vector3(0,2.65,0),22)
	name_label.reparent(activity_root,true)
	character_sprites.append({"sprite":sprite,"activity_root":activity_root,"name_label":name_label,"role":role,"color":color,"base_position":sprite.position,"idle_profile":"mascot" if role=="imp" else ("welcoming" if role=="ticket" else "announcer"),"name_body_height":_visible_body_height(sprite),"name_camera_up_y":-1.0})

func _load_identity_atlas() -> void:
	if not ResourceLoader.exists(IDENTITY_ATLAS_PATH):
		_warn_identity_once("atlas","Character identity atlas %s is missing; using built-in NPC fallback art." % IDENTITY_ATLAS_PATH)
		return
	identity_atlas=load(IDENTITY_ATLAS_PATH) as Texture2D
	if identity_atlas == null:
		_warn_identity_once("atlas","Character identity atlas %s could not be loaded; using built-in NPC fallback art." % IDENTITY_ATLAS_PATH)
		return
	for role: String in IDENTITY_REGIONS:
		var region: Rect2i=IDENTITY_REGIONS[role]
		if region.position.x<0 or region.position.y<0 or region.size.x<=0 or region.size.y<=0 or region.end.x>identity_atlas.get_width() or region.end.y>identity_atlas.get_height():
			_warn_identity_once(role,"Character identity '%s' region exceeds %s bounds; using built-in fallback art." % [role,IDENTITY_ATLAS_PATH])
			continue
		var texture := AtlasTexture.new()
		texture.atlas=identity_atlas
		texture.region=Rect2(region)
		identity_textures[role]=texture
	if identity_textures.is_empty():
		identity_atlas=null
		_warn_identity_once("regions","Character identity atlas has no valid regions; using built-in NPC fallback art.")

func _warn_identity_once(key: String, message: String) -> void:
	if identity_warnings.has(key): return
	identity_warnings[key]=true
	push_warning(message)

func _pixel_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for py in range(y,maxi(0,y+height)):
		for px in range(x,maxi(0,x+width)):
			if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
				image.set_pixel(px,py,color)

func _pixel_triangle(image: Image, x: int, y: int, width: int, height: int, color: Color, point_up := true) -> void:
	for row in range(height):
		var progress := float(row) / maxi(1,height-1)
		var span := maxi(1,roundi(width*(1.0-progress))) if point_up else maxi(1,roundi(width*progress))
		var left := x + (width-span)/2
		_pixel_rect(image,left,y+row,span,1,color)

func _pixel_line(image: Image, start: Vector2i, finish: Vector2i, color: Color, thickness := 1) -> void:
	var x := start.x
	var y := start.y
	var dx := absi(finish.x-start.x)
	var sx := 1 if start.x < finish.x else -1
	var dy := -absi(finish.y-start.y)
	var sy := 1 if start.y < finish.y else -1
	var error := dx+dy
	while true:
		_pixel_rect(image,x-thickness/2,y-thickness/2,thickness,thickness,color)
		if x == finish.x and y == finish.y: break
		var doubled := 2*error
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy

func _character_texture(role: String, accent: Color, direction: String, frame: int) -> Texture2D:
	var key := "%s|%s|%s|%d" % [role,accent.to_html(true),direction,frame%4]
	if character_frames.has(key): return character_frames[key]
	const INK := Color("#243c50")
	const SKIN := Color("#efc69e")
	const CREAM_PAPER := Color("#f3e4bd")
	const BOOT := Color("#654b3e")
	var img := Image.create(32,48,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var step := frame % 4
	# Four planted-foot poses stay pixel-snapped; frame zero doubles as the idle pose.
	var left_lift: int = [0,1,2,1][step]
	var right_lift: int = [0,-1,-2,-1][step]
	var boot_left := Color("#473e47") if role == "imp" else BOOT
	var boot_right := Color("#473e47") if role == "imp" else BOOT
	_pixel_rect(img,9,34+left_lift,6,9-left_lift,boot_left)
	_pixel_rect(img,18,34+right_lift,6,9-right_lift,boot_right)
	_pixel_rect(img,8,42+left_lift,8,4,Color("#463a39"))
	_pixel_rect(img,18,42+right_lift,8,4,Color("#463a39"))
	if role == "hero":
		# Narrow cream rain shorts with two dark seams.
		_pixel_rect(img,9,34+left_lift,5,6,CREAM_PAPER)
		_pixel_rect(img,19,34+right_lift,5,6,CREAM_PAPER)
		_pixel_line(img,Vector2i(16,35),Vector2i(16,39),Color("#c4ac82"))
	elif role == "imp":
		_pixel_rect(img,10,34+left_lift,4,6,accent.darkened(0.2))
		_pixel_rect(img,19,34+right_lift,4,6,accent.darkened(0.2))
	else:
		_pixel_rect(img,10,34+left_lift,4,6,Color("#315363"))
		_pixel_rect(img,19,34+right_lift,4,6,Color("#315363"))
	# Body silhouette is role-led: raincoat, mascot, guide uniform or announcer's jacket.
	_pixel_rect(img,8,20,16,16,INK)
	_pixel_rect(img,9,21,14,14,accent)
	if role == "hero":
		var raincoat := Color("#267e83")
		_pixel_rect(img,9,21,14,13,raincoat)
		_pixel_rect(img,8,25,3,7,raincoat.darkened(0.16))
		_pixel_rect(img,21,25,3,7,raincoat.darkened(0.16))
		_pixel_rect(img,8,30,4,3,Color("#df765d"))
		_pixel_rect(img,20,31,4,2,CREAM_PAPER)
		_pixel_rect(img,10,21,12,3,Color("#d7ece0"))
		# The ticket lanyard and paper boarding stub are only on the front.
		if direction != "back":
			_pixel_line(img,Vector2i(10,22),Vector2i(20,32),Color("#d9cfaa"),2)
			_pixel_rect(img,18,29,5,5,Color("#f5edcf"))
			_pixel_rect(img,19,30,3,1,Color("#d8ae68"))
			_pixel_rect(img,19,32,2,1,Color("#78a5a0"))
			# Brick-red box camera, worn brass side and pale blue lens.
			_pixel_rect(img,21,32,6,4,Color("#994f45"))
			_pixel_rect(img,22,31,4,2,Color("#bc7157"))
			_pixel_rect(img,26,33,2,2,Color("#e4c57d"))
			_pixel_rect(img,23,33,2,2,Color("#3e747b"))
		_pixel_rect(img,15,22,2,11,Color("#f1f0d8"))
		_pixel_rect(img,13,20,6,2,Color("#e4c27c"))
	elif role == "imp":
		# Soft mascot body, oversized trailing scarf and folded arrow-point tail.
		_pixel_triangle(img,9,22,14,13,accent)
		_pixel_rect(img,9,31,14,3,accent.darkened(0.13))
		_pixel_rect(img,8,23,4,2,accent.lightened(0.16))
		_pixel_rect(img,20,23,4,2,accent.lightened(0.16))
		_pixel_rect(img,10,21,12,4,Color("#2c8b8c"))
		_pixel_rect(img,17,23,5,10,Color("#2c8b8c"))
		_pixel_triangle(img,17,31,6,5,Color("#47a6a2"),false)
		# Tail points back from its turn; direction changes which edge it exits.
		if direction == "left":
			_pixel_line(img,Vector2i(10,29),Vector2i(4,32),Color("#b95051"),3)
			_pixel_triangle(img,2,30,5,5,Color("#b95051"))
			_pixel_rect(img,2,29,3,1,CREAM_PAPER)
		else:
			_pixel_line(img,Vector2i(22,29),Vector2i(28,32),Color("#b95051"),3)
			_pixel_triangle(img,26,30,5,5,Color("#b95051"),false)
			_pixel_rect(img,28,29,3,1,CREAM_PAPER)
	elif role == "ticket":
		_pixel_rect(img,9,21,14,13,Color("#34727a"))
		_pixel_rect(img,9,23,14,3,Color("#e1bd6a"))
		_pixel_rect(img,13,20,6,3,CREAM_PAPER)
		_pixel_rect(img,10,30,5,2,Color("#8f604e"))
		# Tiny brass ticket punch at the guide's hip.
		_pixel_rect(img,22,28,4,5,Color("#c88f4a"))
		_pixel_rect(img,23,29,2,1,Color("#f2dfa8"))
	elif role == "announcer":
		_pixel_rect(img,9,21,14,13,Color("#34566b"))
		_pixel_rect(img,9,22,14,3,Color("#d5ba7b"))
		_pixel_rect(img,15,25,2,9,Color("#283f52"))
		# Handheld loudhailer, held away from his face.
		_pixel_rect(img,22,27,4,3,Color("#d0a452"))
		_pixel_triangle(img,25,26,5,5,Color("#ebd8a8"),false)
	# Face, profile, hair and uniform headwear are drawn independently so the
	# imp never inherits a human silhouette and rear views never show facial gear.
	if role == "imp":
		# Irregular coral head with asymmetrical ears, a chipped short horn and a bent horn.
		_pixel_rect(img,10,9,12,12,Color("#da705c"))
		_pixel_rect(img,8,11,16,8,Color("#da705c"))
		_pixel_triangle(img,3,8,9,8,Color("#c85f58"),false)
		_pixel_triangle(img,21,8,8,9,Color("#e18168"))
		_pixel_triangle(img,10,4,5,6,CREAM_PAPER)
		_pixel_rect(img,10,3,3,2,Color("#d7c69c"))	# chipped horn tip
		_pixel_line(img,Vector2i(19,10),Vector2i(22,5),CREAM_PAPER,3)
		_pixel_line(img,Vector2i(22,5),Vector2i(23,2),CREAM_PAPER,2)
		if direction != "back":
			if direction == "left":
				_pixel_line(img,Vector2i(12,12),Vector2i(15,11),INK,1)
				_pixel_rect(img,12,14,2,2,Color("#ffd884"))
				_pixel_line(img,Vector2i(12,18),Vector2i(17,16),Color("#773f4c"),2)
			elif direction == "right":
				_pixel_line(img,Vector2i(17,11),Vector2i(20,12),INK,1)
				_pixel_rect(img,18,14,2,2,Color("#ffd884"))
				_pixel_line(img,Vector2i(15,16),Vector2i(20,18),Color("#773f4c"),2)
			else:
				_pixel_line(img,Vector2i(11,12),Vector2i(15,11),INK,1)
				_pixel_line(img,Vector2i(18,11),Vector2i(22,12),INK,1)
				_pixel_rect(img,12,14,2,2,Color("#ffd884"))
				_pixel_rect(img,19,14,2,2,Color("#ffd884"))
				_pixel_line(img,Vector2i(15,17),Vector2i(20,18),Color("#773f4c"),2)
				_pixel_rect(img,13,16,1,1,CREAM_PAPER)	# one tooth in the crooked grin
	else:
		if direction == "back":
			# Hair/cap back only; no skin, eyes, ticket or camera face markings.
			_pixel_rect(img,9,6,14,13,INK)
			_pixel_rect(img,7,10,3,6,INK)
			_pixel_rect(img,22,10,3,6,INK)
			if role == "hero":
				_pixel_rect(img,10,8,12,2,Color("#314d62"))
				_pixel_rect(img,9,21,14,12,Color("#24747b"))
				_pixel_line(img,Vector2i(16,23),Vector2i(16,31),Color("#76a8a0"))
			elif role == "ticket":
				_pixel_rect(img,8,7,16,5,Color("#e3bb65"))
				_pixel_rect(img,10,11,12,5,Color("#286776"))
			elif role == "announcer":
				_pixel_rect(img,7,5,18,5,Color("#273f58"))
				_pixel_rect(img,8,9,16,3,Color("#d2ad64"))
				_pixel_rect(img,7,11,4,5,Color("#263e52"))
				_pixel_rect(img,21,11,4,5,Color("#263e52"))
		else:
			_pixel_rect(img,8,7,16,12,INK)
			_pixel_rect(img,10,9,12,9,SKIN)
			if direction == "left":
				_pixel_rect(img,10,11,4,5,SKIN)
				_pixel_rect(img,12,12,2,2,INK)
			else:
				_pixel_rect(img,18,11,4,5,SKIN)
				_pixel_rect(img,18,12,2,2,INK)
			if role == "hero":
				# Short wind-tossed ink-blue hair and one cream forelock.
				_pixel_rect(img,8,6,15,4,Color("#243e55"))
				_pixel_rect(img,7,8,5,4,Color("#243e55"))
				_pixel_rect(img,11,5,5,3,Color("#243e55"))
				_pixel_triangle(img,18,4,5,5,Color("#243e55"),false)
				_pixel_rect(img,14,5,2,3,CREAM_PAPER)
			elif role == "ticket":
				_pixel_rect(img,7,7,18,3,Color("#d8b257"))
				_pixel_rect(img,9,4,14,4,Color("#2e6572"))
				_pixel_rect(img,12,4,8,1,CREAM_PAPER)
			elif role == "announcer":
				_pixel_rect(img,7,6,18,3,Color("#273e55"))
				_pixel_rect(img,9,3,14,4,Color("#263f56"))
				_pixel_rect(img,11,4,10,1,Color("#d6b363"))
				# Ear cups and the thin headset band.
				_pixel_rect(img,6,11,3,6,Color("#263e52"))
				_pixel_rect(img,23,11,3,6,Color("#263e52"))
				_pixel_line(img,Vector2i(24,16),Vector2i(26,18),Color("#e1bd76"))
			# Character-specific expressions.
			if role == "hero":
				_pixel_line(img,Vector2i(11,11),Vector2i(14,10),INK,1)
				_pixel_rect(img,12,13,2,2,INK)
				_pixel_rect(img,19,13,2,2,INK)
				_pixel_line(img,Vector2i(15,17),Vector2i(18,16),Color("#a85d58"))
			elif role == "ticket":
				_pixel_line(img,Vector2i(11,11),Vector2i(14,12),INK)
				_pixel_rect(img,12,14,2,2,INK)
				_pixel_rect(img,19,14,2,2,INK)
				_pixel_rect(img,15,17,3,1,Color("#aa5c53"))
			else:
				# Narrow eyes with worried, asymmetrical brows.
				_pixel_line(img,Vector2i(11,10),Vector2i(14,12),INK)
				_pixel_line(img,Vector2i(18,12),Vector2i(21,10),INK)
				_pixel_rect(img,12,14,3,1,INK)
				_pixel_rect(img,19,14,3,1,INK)
				_pixel_rect(img,15,17,3,2,Color("#984d4f"))
			if role == "hero":
				# Front-strap only: no pale face/camera marks leak onto the raincoat back.
				if direction != "back":
					_pixel_line(img,Vector2i(10,22),Vector2i(20,33),Color("#dfd7bd"),2)
					_pixel_rect(img,18,30,4,4,Color("#f4ecd2"))
					_pixel_rect(img,19,31,2,1,Color("#d3ae68"))
					_pixel_rect(img,21,33,6,3,Color("#934a43"))
					_pixel_rect(img,22,32,4,2,Color("#bb6c55"))
					_pixel_rect(img,23,34,2,1,Color("#91bcc0"))
					_pixel_rect(img,8,30,3,3,Color("#df765d"))
			elif role == "ticket":
				# A neat little waist badge and puncher catch the light.
				_pixel_rect(img,21,29,4,4,Color("#d9b463"))
				_pixel_rect(img,22,30,2,1,Color("#fff0c8"))
			elif role == "announcer":
				_pixel_rect(img,21,28,6,3,Color("#d0a452"))
				_pixel_triangle(img,25,27,5,5,Color("#ebd8a8"),false)
	var texture := ImageTexture.create_from_image(img)
	character_frames[key]=texture
	return texture

func _build_player() -> void:
	avatar_renderer=AvatarRenderer.new()
	player=CharacterBody3D.new()
	# Ramps keep the requested ground speed; otherwise gravity bleeds uphill travel and the
	# distance-driven walk cycle visibly slows mid-climb.
	player.floor_constant_speed=true
	player.position=_player_spawn_position()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.3
	capsule.height=1.5
	collision.shape=capsule
	collision.position.y=0.85
	player.add_child(collision)
	avatar=Sprite3D.new()
	avatar.pixel_size=2.4 / float(avatar_renderer.pose_height())
	avatar.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	avatar.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	avatar.position.y=1.15
	avatar.shaded=true
	avatar.position.y=1.2
	avatar.texture=avatar_renderer.texture(avatar_appearance,avatar_equipped,"front",0,"idle")
	avatar_hair_rig=AvatarHairRig.new()
	avatar_hair_rig.name="IslandHairViewport"
	add_child(avatar_hair_rig)
	avatar_hair_rig.set_motion_enabled(avatar_hair_motion_enabled and not reduced_motion and DisplayServer.get_name()!="headless")
	_set_living_sprite_material(avatar,1,0.18,0.72,0,false)
	avatar_ground_anchor=Node3D.new()
	avatar_ground_anchor.name="BillboardGroundAnchor"
	player.add_child(avatar_ground_anchor)
	avatar_ground_anchor.add_child(avatar)
	avatar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	avatar_contact_shadow=_add_contact_shadow(player,Vector3(0,0,0),Vector2(0.92,0.58))
	_add_actor_shadow_proxy(player,"hero",ground_surface_y(player.position)-player.position.y,avatar)
	_register_sprite_ground_anchor(avatar,avatar_ground_anchor,player,ground_surface_y(player.position),float(AvatarRenderer.FEET_BASELINE),float(AvatarRenderer.CANVAS_SIZE.y))
	add_child(player)
	# Production presentation uses the complete authored Sprite atlases directly.
	# The optional AvatarMotionRig remains available to isolated review scenes.
	avatar_motion_rig=null
	avatar_motion_available=false
	_build_player_floor()

func _player_spawn_position() -> Vector3:
	return Vector3(0,0.3,23.2)

func _build_player_floor() -> void:
	# One slab under the whole island and one under the dock. The shore itself is
	# kept by _constrain_player, so the slab only has to reach past every coast.
	var island := IslandShape.bounds().grow(4.0)
	for geometry in [Vector3(island.size.x,0.2,island.size.y),Vector3(5,0.2,13)]:
		var floor_body := StaticBody3D.new()
		floor_body.position=Vector3(island.get_center().x,0.1,island.get_center().y) if geometry.x>6 else Vector3(0,0.12,21)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=geometry
		shape.shape=box
		floor_body.add_child(shape)
		add_child(floor_body)

func _build_camera() -> void:
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=21.0
	camera.far=200
	camera.position=player.position+CAMERA_OFFSET
	add_child(camera)
	camera.look_at(player.position+Vector3(0,1,0))
	camera.current=true
	_sync_avatar_motion_camera()
	avatar_last_physics_position=player.global_position
	avatar_last_physics_position_valid=true

func _sync_avatar_motion_camera(discontinuous: bool = false) -> void:
	if not avatar_motion_available or not is_instance_valid(avatar_motion_rig) or not is_instance_valid(camera): return
	avatar_motion_rig.set_view_projection(camera.global_basis,atan2(camera.global_basis.z.x,camera.global_basis.z.z),discontinuous)

func _update_follow_interpolation(riding: bool) -> void:
	if not allow_follow_interpolation:
		return
	if reduced_motion or riding or avatar_motion_available:
		_stop_follow_interpolation()
		return
	if blocked:
		_follow_sample_tick = -1
		return
	var tick := Engine.get_physics_frames()
	if _follow_sample_tick < 0:
		_follow_sample_tick = tick
		_follow_sample_frame = Engine.get_process_frames()
		return
	var ticks := tick - _follow_sample_tick
	if ticks < FOLLOW_CADENCE_TICKS:
		return
	var frame := Engine.get_process_frames()
	var ratio := float(frame - _follow_sample_frame) / ticks
	_follow_sample_tick = tick
	_follow_sample_frame = frame
	if _follow_interpolation_active:
		if ratio <= FOLLOW_INTERPOLATION_STOP_RATIO: _stop_follow_interpolation()
	elif ratio >= FOLLOW_INTERPOLATION_START_RATIO:
		_start_follow_interpolation()

func _start_follow_interpolation() -> void:
	var tree := get_tree()
	# Respect configurations that already own physics interpolation.
	if tree.physics_interpolation:
		return
	_follow_previous_root_mode = tree.root.physics_interpolation_mode
	tree.root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	tree.physics_interpolation = true
	_follow_interpolation_active = true
	_reset_follow_interpolation()

func _stop_follow_interpolation() -> void:
	_follow_sample_tick = -1
	if not _follow_interpolation_active:
		return
	_follow_interpolation_active = false
	var tree := get_tree()
	tree.physics_interpolation = false
	if is_instance_valid(player): player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	if is_instance_valid(camera): camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	tree.root.physics_interpolation_mode = _follow_previous_root_mode

func _reset_follow_interpolation() -> void:
	if _follow_interpolation_active:
		player.reset_physics_interpolation()
		camera.reset_physics_interpolation()

func _sync_external_avatar_reposition() -> void:
	if embedded_in != null:
		embedded_in._sync_external_avatar_reposition()
		return
	if not is_instance_valid(player): return
	var current_position := player.global_position
	if not avatar_last_physics_position_valid:
		avatar_last_physics_position=current_position
		avatar_last_physics_position_valid=true
		return
	var externally_repositioned := current_position.distance_to(avatar_last_physics_position)>AVATAR_EXTERNAL_REPOSITION_THRESHOLD
	if externally_repositioned and not is_riding():
		if is_instance_valid(avatar_hair_rig): avatar_hair_rig.reset_motion()
		# Keep relocation handling independent from the optional gait rig: the
		# camera must snap and stale velocity must not turn a teleport into a walk.
		if is_instance_valid(camera):
			camera.position=player.position+CAMERA_OFFSET
			camera.look_at(player.position+Vector3(0,1,0))
			_reset_follow_interpolation()
		player.velocity=Vector3.ZERO
		avatar_is_walking=false
		_avatar_careful_braking = false
		_avatar_action_on_stop = ""
		_avatar_departure_remaining = 0.0
		_avatar_pivot_remaining = 0.0
		if avatar_action == AVATAR_STOP_ACTION:
			avatar_action = ""
			avatar_action_remaining = 0.0
			avatar_action_elapsed = 0.0
		walk_distance_phase=0.0
		if avatar_motion_available and is_instance_valid(avatar_motion_rig):
			avatar_motion_rig.position.y=ground_surface_y(player.global_position)-player.global_position.y
			_sync_avatar_motion_camera(true)
	avatar_last_physics_position=current_position

func _avatar_ground_height(point: Vector2) -> float:
	return ground_surface_y(Vector3(point.x,0.0,point.y))

static func motion_sources_ready(records: Dictionary) -> bool:
	const REQUIRED_DIRECTIONS := ["front","front_right","right","back_right","back","back_left","left","front_left"]
	if records.size()!=REQUIRED_DIRECTIONS.size(): return false
	for direction in REQUIRED_DIRECTIONS:
		var record: Variant=records.get(direction,{})
		if not record is Dictionary or not bool(record.get("valid",false)): return false
	return true

func _constrain_player(_previous_position: Vector3) -> bool:
	# The walker stays on the island or on the dock planks; whichever limit is
	# nearer wins, so stepping off the dock's side never jumps back to the beach.
	var spot := Vector2(player.position.x,player.position.z)
	if not IslandLayout.DOCK_WALK.has_point(spot) and not IslandShape.contains(spot,IslandShape.WALK_MARGIN):
		var ashore := IslandShape.clamp_inside(spot)
		var on_planks := spot.clamp(IslandLayout.DOCK_WALK.position,IslandLayout.DOCK_WALK.end)
		var kept := on_planks if spot.distance_squared_to(on_planks) < spot.distance_squared_to(ashore) else ashore
		player.position.x=kept.x
		player.position.z=kept.y
	if player.position.y < -1.0:
		player.position=Vector3(0,0.3,10)
		return true
	return false

## The walker stays on standable ground: inside a district its own floor plan
## decides, elsewhere the island does, and the two only meet on an approach.
func _constrain_walker(previous_position: Vector3) -> bool:
	var here := DistrictSites.ruling(Vector2(player.position.x, player.position.z)) if is_instance_valid(district_host) else ""
	if here.is_empty(): return _constrain_player(previous_position)
	var rules: Node3D = district_host.built(here)
	if rules != null and DistrictSites.ruling(Vector2(previous_position.x, previous_position.z)) == here:
		return rules._constrain_player(rules.to_local(previous_position))
	# Stepping in from the island: only onto ground the district lets a walker stand on.
	if rules == null or not rules.is_walkable(rules.to_local(player.position)):
		player.position.x = previous_position.x
		player.position.z = previous_position.z
		player.velocity = Vector3.ZERO
	return false

## True where the avatar can stand. Placement data asks this instead of
## assuming the island's current outline.
func is_walkable(position: Vector3) -> bool:
	var spot := Vector2(position.x,position.z)
	if is_instance_valid(district_host):
		var region := DistrictSites.ruling(spot)
		if not region.is_empty():
			var rules: Node3D = district_host.built(region)
			return rules != null and rules.is_walkable(rules.to_local(position))
	return island_walkable(spot)

func _area_at_position(position: Vector3) -> String:
	var spot := Vector2(position.x,position.z)
	if is_instance_valid(district_host):
		var region := DistrictSites.ruling(spot)
		var rules: Node3D = district_host.built(region)
		if rules != null and (rules._site.claim as Rect2).has_point(DistrictSites.to_local(region, spot)):
			return rules._area_at_position(rules.to_local(position))
		if district_host.standing != "welcome": return RegionRoutes.title(district_host.standing)
	return IslandShape.area_at(spot)

## True while a story photo is staged: the walker, its pose and the follow
## camera hold still. The island asks its districts; a region answers for itself.
func staging_photo() -> bool:
	if is_instance_valid(district_host):
		for region: String in district_host.districts:
			if district_host.districts[region].staging_photo(): return true
	return false

func _physics_process(delta: float) -> void:
	if embedded_in != null or not is_instance_valid(player) or staging_photo(): return
	_sync_external_avatar_reposition()
	_update_district_label_visibility()
	var riding := is_riding()
	_update_follow_interpolation(riding)
	if riding:
		if blocked:
			end_ride()
		else:
			player.velocity=Vector3.ZERO
			camera.position=camera.position.lerp(player.position+CAMERA_OFFSET,minf(1,delta*7))
			camera.look_at(player.position+Vector3(0,1,0))
			_update_sprite_grounding()
			_update_npc_name_labels()
			_refresh_avatar_texture(_ride_pose_frame())
			_set_ride_exit_interaction()
			avatar_last_physics_position=player.global_position
			return
	var operating_lens: bool = is_instance_valid(coastal_play) and is_instance_valid(coastal_play.discoveries) and coastal_play.discoveries.controlling
	var movement := Vector2.ZERO if blocked or operating_lens else Input.get_vector("move_left","move_right","move_up","move_down")
	# Default travel is a brisk walk; Shift keeps a slower, careful pace.
	avatar_run_requested = not blocked and not Input.is_key_pressed(KEY_SHIFT)
	var desired_speed := AVATAR_RUN_SPEED if avatar_run_requested else AVATAR_WALK_SPEED
	var previous_horizontal := Vector2(player.velocity.x,player.velocity.z)
	var was_coasting := movement == Vector2.ZERO and previous_horizontal != Vector2.ZERO
	var current_horizontal := Vector2.ZERO
	if blocked or operating_lens:
		_avatar_careful_braking = false
	else:
		current_horizontal = _steer_avatar_horizontal(previous_horizontal, movement, desired_speed, delta)
	# Gravity only while airborne; floor snapping keeps the feet down on ramps. A constant
	# downward pull while grounded made Godot's stop-on-slope rule read slow starts (for
	# example at a quarter time scale) as standing still and zero them every tick.
	player.velocity=Vector3(current_horizontal.x,0.0 if player.is_on_floor() else -4.0,current_horizontal.y)
	var previous_position: Vector3=player.position
	var previous_world_position: Vector3=player.global_position
	player.move_and_slide()
	var recovered := _constrain_walker(previous_position)
	if recovered:
		previous_position=player.position
		previous_world_position=player.global_position
	var actual_world_delta := player.global_position-previous_world_position
	var horizontal_delta := Vector2(actual_world_delta.x, actual_world_delta.z)
	var travelled := horizontal_delta.length()
	var reviewed_stop: bool = (
		was_coasting and player.is_on_floor() and not reduced_motion and not blocked and not operating_lens
		and last_avatar_action == "walk" and last_avatar_source_action == "walk" and last_avatar_direction == facing
		and last_avatar_frame in AVATAR_STOP_FROM_WALK_CELS.get(facing, [])
	)
	var advances_stride := travelled > WALK_DISTANCE_EPSILON
	var was_walking := avatar_is_walking
	# A slow reversal can pass through several updates below the stride threshold.
	var turning_in_stride := (
		not advances_stride and was_walking and movement != Vector2.ZERO and player.is_on_floor()
		and current_horizontal.length() * delta <= WALK_DISTANCE_EPSILON
		and (travelled > 0.0 or (current_horizontal == Vector2.ZERO and previous_horizontal.dot(movement) < 0.0))
		and quantize_walk_direction(movement, facing) != facing
	)
	avatar_is_walking = advances_stride or turning_in_stride or (reviewed_stop and travelled > 0.0)
	if advances_stride:
		facing = quantize_walk_direction(horizontal_delta, facing)
		walk_distance_phase = advance_walk_phase(walk_distance_phase, travelled, walk_stride_for(facing))
	if avatar_motion_available:
		avatar_motion_rig.position.y=ground_surface_y(player.global_position)-player.global_position.y
		camera.position=camera.position.lerp(player.position+CAMERA_OFFSET,minf(1,delta*7))
		camera.look_at(player.position+Vector3(0,1,0))
		_sync_avatar_motion_camera()
		avatar_motion_rig.set_direction(facing)
		avatar_motion_rig.visible=false
		avatar_motion_rig.cancel_motion()
	var walk_frame_count := int(avatar_renderer.walk_frame_count(facing)) if avatar_renderer != null else 8
	var frame := walk_frame_for_phase(walk_distance_phase, walk_frame_count)
	_update_avatar_pivot(movement, current_horizontal, delta, frame, walk_frame_count)
	if _avatar_departure_remaining > 0.0 or (advances_stride and not was_walking):
		var can_depart := advances_stride and movement != Vector2.ZERO and player.is_on_floor() and not reduced_motion and last_avatar_direction == facing
		if not can_depart or frame not in AVATAR_DEPARTURE_TO_WALK_CELS.get(facing, []):
			_avatar_departure_remaining = 0.0
		elif _avatar_departure_remaining > 0.0:
			_avatar_departure_remaining = maxf(0.0, _avatar_departure_remaining - delta)
		elif last_avatar_source_action == "idle" and _has_authored_avatar_action(AVATAR_DEPARTURE_ACTION, facing):
			# Leave room in the reviewed stride cel for the motion during takeoff.
			var duration: float = avatar_renderer.animation_library.sequence_duration("traveller", AVATAR_DEPARTURE_ACTION, facing)
			var projected_speed := current_horizontal.length() + desired_speed * (duration + delta) / (2.0 * AVATAR_ACCELERATION_SECONDS)
			var exit_phase := advance_walk_phase(walk_distance_phase, projected_speed * duration, walk_stride_for(facing))
			if walk_frame_for_phase(exit_phase, walk_frame_count) == frame and avatar_renderer.animation_library.original_frame_image("traveller", AVATAR_DEPARTURE_ACTION, facing, 0) != null:
				_avatar_departure_remaining = duration
	if not _avatar_action_on_stop.is_empty():
		var requested_action := _avatar_action_on_stop
		_avatar_action_on_stop = ""
		if not avatar_is_walking:
			play_action(requested_action)
	if avatar_action_remaining > 0.0:
		if avatar_is_walking:
			# Gestures never hold a planted pose while the player translates.
			avatar_action_remaining=0.0
			avatar_action=""
		else:
			# Modal overlays pause the current pose and resume at the same phase.
			if not blocked:
				avatar_action_elapsed += delta
				avatar_action_remaining=maxf(0.0,avatar_action_remaining-delta)
				if avatar_action_remaining == 0.0: avatar_action=""
	elif (
		reviewed_stop and current_horizontal == Vector2.ZERO and not avatar_is_walking
		and _has_authored_avatar_action(AVATAR_STOP_ACTION, facing)
		and avatar_renderer.animation_library.original_frame_image("traveller", AVATAR_STOP_ACTION, facing, 0) != null
	):
		avatar_action = AVATAR_STOP_ACTION
		avatar_action_remaining = _avatar_action_duration(AVATAR_STOP_ACTION, facing)
		avatar_action_elapsed = 0.0
	elif (
		_avatar_camera_idle_available and not reduced_motion and not blocked and not operating_lens
		and movement == Vector2.ZERO and not avatar_is_walking and player.is_on_floor()
		and facing == "front" and last_avatar_direction == facing
		and last_avatar_action == "idle" and last_avatar_frame == 0
		and time - _avatar_idle_started_at >= AVATAR_CAMERA_IDLE_DELAY
	):
		var sequence: Dictionary = avatar_renderer.animation_library.get_sequence("traveller", AVATAR_CAMERA_IDLE_ACTION, "front")
		_avatar_camera_idle_available = bool(sequence.available) and not bool(sequence.loop)
		if _avatar_camera_idle_available:
			play_action(AVATAR_CAMERA_IDLE_ACTION)
	_refresh_avatar_texture(frame)
	if is_instance_valid(avatar_hair_rig):
		var pixel_velocity := horizontal_delta / maxf(delta, 0.000001) / avatar.pixel_size
		avatar_hair_rig.advance(delta, pixel_velocity, blocked)
	if recovered and _follow_interpolation_active:
		camera.position = player.position + CAMERA_OFFSET
	else:
		camera.position=camera.position.lerp(player.position+CAMERA_OFFSET,minf(1,delta*7))
	camera.look_at(player.position+Vector3(0,1,0))
	if recovered: _reset_follow_interpolation()
	if avatar_motion_available: _sync_avatar_motion_camera()
	_update_sprite_grounding()
	_update_npc_name_labels()
	if is_instance_valid(district_host): district_host.track(player.position, delta)
	var area := _area_at_position(player.position)
	if area!=current_area:
		current_area=area
		area_changed.emit(area)
	avatar_last_physics_position=player.global_position
	nearest={}
	var best := 2.4
	for point in points:
		var dist := player.position.distance_to(point.position)
		if dist<best:
			best=dist
			nearest=point
	_set_interaction_marker(nearest.get("marker") if _interaction_markers_allowed() else null)

func _steer_avatar_horizontal(velocity: Vector2, movement: Vector2, speed: float, delta: float) -> Vector2:
	var desired := movement * speed
	if movement == Vector2.ZERO or speed == AVATAR_RUN_SPEED:
		_avatar_careful_braking = false
	elif avatar_motion_speed_limit == AVATAR_RUN_SPEED and velocity.length_squared() > AVATAR_WALK_SPEED * AVATAR_WALK_SPEED:
		_avatar_careful_braking = true
	if movement.length_squared() > 0.0001:
		avatar_motion_speed_limit = speed
	var acceleration := avatar_motion_speed_limit / AVATAR_ACCELERATION_SECONDS
	if not _avatar_careful_braking:
		return velocity.move_toward(desired, acceleration * delta)
	var brisk_brake := AVATAR_RUN_SPEED / AVATAR_ACCELERATION_SECONDS
	if velocity.dot(movement) < 0.0:
		# Finish braking the old heading before accelerating at the new pace.
		var stop_time := velocity.length() / brisk_brake
		if stop_time > delta:
			return velocity.move_toward(Vector2.ZERO, brisk_brake * delta)
		_avatar_careful_braking = false
		return Vector2.ZERO.move_toward(desired, acceleration * (delta - stop_time))
	var next := velocity.move_toward(desired, brisk_brake * delta)
	_avatar_careful_braking = next.length_squared() > AVATAR_WALK_SPEED * AVATAR_WALK_SPEED
	return next

func _interaction_markers_allowed() -> bool:
	# A district staging a story photo hides every glyph, the island's included.
	if is_instance_valid(district_host):
		for region: String in district_host.districts:
			if not district_host.districts[region]._interaction_markers_allowed(): return false
	return true

func _set_interaction_marker(candidate: Variant) -> void:
	if embedded_in != null:
		embedded_in._set_interaction_marker(candidate)
		return
	var marker: Label3D = candidate as Label3D if is_instance_valid(candidate) else null
	if is_instance_valid(_visible_interaction_marker) and _visible_interaction_marker != marker and _visible_interaction_marker.visible:
		_visible_interaction_marker.hide()
	_visible_interaction_marker = marker
	if marker != null and not marker.visible:
		marker.show()

func _set_ride_exit_interaction() -> void:
	nearest={"id":"ride-tide","label":"離開潮汐貝殼輪","position":player.global_position,"marker":null}
	_set_interaction_marker(null)

func _update_avatar_pivot(movement: Vector2, velocity: Vector2, delta: float, frame: int, frame_count: int) -> void:
	if movement == Vector2.ZERO or reduced_motion or not avatar_is_walking or not player.is_on_floor():
		_avatar_pivot_remaining = 0.0
		return
	if _avatar_pivot_remaining <= 0.0 and (
		last_avatar_source_action != "walk" or velocity.dot(movement) >= 0.0 or velocity.length_squared() > 0.34 * 0.34
	):
		return
	var target := quantize_walk_direction(movement, facing)
	var lateral := target == "left" or target == "right"
	var depth := target == "front" or target == "back"
	if not (lateral or depth):
		_avatar_pivot_remaining = 0.0
		return
	if _avatar_pivot_remaining > 0.0:
		_avatar_pivot_remaining = maxf(0.0, _avatar_pivot_remaining - delta) if target == _avatar_pivot_target else 0.0
		return
	var eligible_headings := ["left", "right"] if lateral else ["front", "back"]
	if facing not in eligible_headings or target == facing:
		return
	var exits := AVATAR_PIVOT_WALK_CELS if lateral else AVATAR_DEPTH_PIVOT_WALK_CELS
	var approved_exits: Array = exits[target].get(frame, [])
	if approved_exits.is_empty(): return
	# Keep the pivot inside the reviewed adjacent stride poses while movement continues.
	var duration := AVATAR_PIVOT_SECONDS if lateral else AVATAR_DEPTH_PIVOT_SECONDS
	var travel_ceiling := avatar_motion_speed_limit * duration * (duration + delta) / (2.0 * AVATAR_ACCELERATION_SECONDS)
	if depth:
		# The approach first slows to zero. Bound both sides of the crossing,
		# allowing a switch from slow walk to the maximum acceleration.
		var acceleration := AVATAR_RUN_SPEED / AVATAR_ACCELERATION_SECONDS
		var braking_seconds := velocity.length() / acceleration
		var departure_seconds := maxf(0.0, duration + delta - braking_seconds)
		travel_ceiling = 0.5 * acceleration * (braking_seconds * braking_seconds + departure_seconds * departure_seconds)
	var stride := minf(walk_stride_for(facing), walk_stride_for(target))
	var exit_phase := advance_walk_phase(walk_distance_phase, travel_ceiling, stride)
	var latest_exit := walk_frame_for_phase(exit_phase, frame_count)
	if latest_exit not in approved_exits: return
	if depth:
		# Check each reachable exit because the actual remaining reversal distance varies.
		if latest_exit < frame: return
		for next_frame in range(frame, latest_exit):
			if next_frame not in approved_exits: return
	for direction: String in AVATAR_PIVOT_HEADINGS if lateral else AVATAR_DEPTH_PIVOT_HEADINGS:
		var action := (AVATAR_DEPARTURE_ACTION if direction == "back_left" else AVATAR_PIVOT_ACTION) if lateral else AVATAR_DEPTH_PIVOT_ACTION
		if avatar_renderer.animation_library.original_frame_image("traveller", action, direction, 0) == null:
			return
	_avatar_pivot_target = target
	_avatar_pivot_remaining = duration

func _process(delta: float) -> void:
	if embedded_in != null:
		# The host owns the walker, the lamps and the dialogue; a district only keeps time.
		blocked = embedded_in.blocked
		if not blocked: time += delta
		return
	if not blocked:
		time+=delta
		if not reduced_motion:
			for rotor in coastal_rotors:
				rotor.rotate_z(delta*float(rotor.get_meta("play_speed",0.18)))
	if is_instance_valid(player):
		lamp_selection_elapsed += delta
		if lamp_selection_elapsed >= LAMP_SELECTION_INTERVAL and player.global_position.distance_squared_to(lamp_selection_player_position) >= 0.04:
			_update_lamp_selection()
	sync_activity_pause()
	if not blocked and not pending_npc_interaction.is_empty():
		_play_pending_npc_interaction()

func sync_activity_pause() -> void:
	var pause_activity := blocked and not npc_dialogue_hold
	if is_instance_valid(npc_activity) and npc_activity_paused!=pause_activity:
		npc_activity_paused=pause_activity
		npc_activity.set_activity_paused(pause_activity)

func set_dialogue_hold(held: bool) -> void:
	npc_dialogue_hold=held
	if not is_instance_valid(npc_activity): return
	npc_activity.set_dialogue_hold(held)
	if held:
		npc_activity_paused=false
		npc_activity.set_activity_paused(false)
		_play_pending_npc_interaction()

func _on_interaction_requested(id: String, _label: String) -> void:
	var role := String(NPC_ROLE_BY_POINT.get(id, ""))
	if role.is_empty(): return
	var action := "greet" if role == "ticket" else "interact"
	var actor_record := _npc_record_for_role(role)
	var sprite := actor_record.get("sprite") as Sprite3D
	if not is_instance_valid(sprite): return
	pending_npc_interaction = {"sprite": sprite, "action": action, "direction": "front"}

func _play_pending_npc_interaction() -> void:
	if pending_npc_interaction.is_empty() or not is_instance_valid(npc_activity): return
	var request := pending_npc_interaction
	pending_npc_interaction = {}
	var sprite := request.get("sprite") as Sprite3D
	if not is_instance_valid(sprite): return
	npc_activity.request_action(sprite, String(request.action), String(request.direction), npc_dialogue_hold)

## Updates signposts and quest results from saved progress (see StoryLandmarks).
func set_story_progress(snapshot: Dictionary) -> void:
	if is_instance_valid(story_landmarks):
		story_landmarks.apply_progress(snapshot)

## Plays a one-off authored reaction (for example a finished request) on an NPC.
func react_story_npc(role: String, action: String) -> bool:
	var sprite := _npc_record_for_role(role).get("sprite") as Sprite3D
	if not is_instance_valid(sprite) or not is_instance_valid(npc_activity):
		return false
	return npc_activity.request_action(sprite, action, "front")

## The sprite standing in for a story role here (null when the role is absent).
func story_actor(role: String) -> Node3D:
	var sprite: Variant = _npc_record_for_role(role).get("sprite")
	return sprite as Node3D if is_instance_valid(sprite) else null

var _story_pose_cache: Dictionary = {}
## A role's authored front key pose for an action, fitted to the NPC canvas
## (null when the role has no such action). Made once per role and action.
func story_pose(role: String, action: String) -> Texture2D:
	var key := role + ":" + action
	if not _story_pose_cache.has(key):
		var library: Variant = avatar_renderer.animation_library if avatar_renderer != null else null
		var frame: Variant = library.texture(role, action, "front", 4) if library != null else null
		_story_pose_cache[key] = _fit_npc_rest_texture(frame) if frame is Texture2D else null
	return _story_pose_cache[key]

func _npc_record_for_role(role: String) -> Dictionary:
	for actor_record in character_sprites:
		if String(actor_record.get("role", "")) == role:
			return actor_record
	return {}

static func quantize_walk_direction(world_delta: Vector2, previous_direction: String = "front") -> String:
	const COMPASS := ["back", "back_right", "right", "front_right", "front", "front_left", "left", "back_left"]
	if world_delta.length_squared() <= WALK_DISTANCE_EPSILON * WALK_DISTANCE_EPSILON: return previous_direction if COMPASS.has(previous_direction) else "front"
	var angle := fposmod(atan2(world_delta.x, -world_delta.y), TAU)
	var sector_width := TAU / float(COMPASS.size())
	var nearest := posmod(roundi(angle / sector_width), COMPASS.size())
	var previous := COMPASS.find(previous_direction)
	if previous >= 0:
		var previous_angle := float(previous) * sector_width
		var difference := absf(wrapf(angle - previous_angle, -PI, PI))
		if difference < sector_width * 0.5 + WALK_DIRECTION_HYSTERESIS:
			return previous_direction
	return COMPASS[nearest]

## `stride` is the world distance one full cycle covers in the current direction. The phase
## stays in WALK_STRIDE_DISTANCE units so turning keeps the same point of the step.
static func advance_walk_phase(phase: float, travelled: float, stride: float = WALK_STRIDE_DISTANCE) -> float:
	var safe_stride := stride if stride > 0.0 and is_finite(stride) else WALK_STRIDE_DISTANCE
	return fposmod(phase + maxf(0.0, travelled) * WALK_STRIDE_DISTANCE / safe_stride, WALK_STRIDE_DISTANCE)

## Reads per-direction strides measured from the walk artwork by tools/walk_stride_calibration.py.
static func load_walk_strides(path: String) -> Dictionary:
	var strides := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (parsed is Dictionary) or not (parsed.get("directions") is Dictionary):
		push_warning("Walk stride calibration is missing or invalid at %s; using %.2f for every direction" % [path, FALLBACK_WALK_STRIDE])
		return strides
	for direction: Variant in parsed.directions:
		var entry: Variant = parsed.directions[direction]
		var value: Variant = entry.get("stride_world") if entry is Dictionary else null
		if (value is float or value is int) and float(value) >= WALK_STRIDE_LIMITS.x and float(value) <= WALK_STRIDE_LIMITS.y:
			strides[str(direction)] = float(value)
		else:
			push_warning("Walk stride for '%s' is outside %s; using %.2f" % [str(direction), str(WALK_STRIDE_LIMITS), FALLBACK_WALK_STRIDE])
	return strides

func walk_stride_for(direction: String) -> float:
	if walk_strides.is_empty():
		walk_strides = load_walk_strides(WALK_STRIDE_CALIBRATION_PATH)
		if walk_strides.is_empty(): walk_strides = {"": FALLBACK_WALK_STRIDE}
	return float(walk_strides.get(direction, FALLBACK_WALK_STRIDE))

static func walk_frame_for_phase(phase: float, frame_count: int = 8) -> int:
	var normalized_phase := fposmod(phase, WALK_STRIDE_DISTANCE) / WALK_STRIDE_DISTANCE
	var safe_frame_count := frame_count if frame_count in [8, 16] else 8
	return clampi(floori(normalized_phase * float(safe_frame_count)), 0, safe_frame_count - 1)

func interact() -> void:
	if is_riding():
		end_ride()
		return
	# During an instant map game the key belongs to that game.
	if is_instance_valid(field_games) and field_games.press(): return
	if not blocked and not nearest.is_empty():
		play_action("interact")
		interaction_requested.emit(nearest.id,nearest.label)

func _unhandled_key_input(event: InputEvent) -> void:
	if embedded_in != null or blocked or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F:
		play_action("wave")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_P:
		play_action("photograph")
		photo_snapped.emit()
		get_viewport().set_input_as_handled()

func play_action(name: String) -> void:
	var action := "photograph" if name == "photo" else name
	if action not in ["wave", "photograph", "interact", "celebrate", AVATAR_CAMERA_IDLE_ACTION]: return
	if avatar_is_walking:
		# The next physics tick can stop the player when an interaction opens a modal.
		_avatar_action_on_stop = action
		return
	var action_direction := _authored_action_direction(action, facing)
	var new_wave := action == "wave" and (avatar_action != "wave" or avatar_action_remaining <= 0.0)
	if not action_direction.is_empty():
		# Face the authored pose before starting it, and keep that heading after
		# the sequence so the sprite does not snap back to an unsupported view.
		facing=action_direction
	else:
		_warn_missing_avatar_action_once(action)
	if avatar_motion_available and not is_riding():
		avatar_motion_rig.position.y=ground_surface_y(player.global_position)-player.global_position.y
		avatar_motion_rig.cancel_motion()
	avatar_action=action
	avatar_action_remaining=_avatar_action_duration(action, action_direction if not action_direction.is_empty() else facing)
	avatar_action_elapsed=0.0
	_refresh_avatar_texture(0)
	if new_wave and not blocked and not is_riding() and not action_direction.is_empty():
		var role := String(NPC_ROLE_BY_POINT.get(String(nearest.get("id", "")), ""))
		if not role.is_empty() and is_instance_valid(npc_activity):
			var sprite := _npc_record_for_role(role).get("sprite") as Sprite3D
			npc_activity.greet_stationary(sprite)

func _authored_action_direction(action: String, preferred_direction: String) -> String:
	if avatar_renderer == null:
		return ""
	if _has_authored_avatar_action(action, preferred_direction):
		return preferred_direction
	if _has_authored_avatar_action(action, "front"):
		return "front"
	for direction in AvatarRenderer.WALK_DIRECTIONS:
		if _has_authored_avatar_action(action, direction):
			return direction
	return ""

func _has_authored_avatar_action(action: String, direction: String) -> bool:
	if avatar_renderer == null:
		return false
	return avatar_renderer.has_authored_action(_avatar_source_action(action, direction), direction)

func _avatar_source_action(action: String, direction: String) -> String:
	if avatar_renderer == null or not AVATAR_SHARED_ACTIONS.has(action): return action
	if avatar_renderer.has_authored_action(action, direction):
		var sequence: Dictionary = avatar_renderer.animation_library.get_sequence("traveller", action, direction)
		if bool(sequence.available): return action
	var shared := str(AVATAR_SHARED_ACTIONS[action])
	return shared if avatar_renderer.has_authored_action(shared, direction) else ""

func _warn_missing_avatar_action_once(action: String) -> void:
	if _warned_missing_avatar_actions.has(action):
		return
	for direction in AvatarRenderer.WALK_DIRECTIONS:
		if _has_authored_avatar_action(action, direction):
			return
	_warned_missing_avatar_actions[action]=true
	push_warning("ParkWorld: traveller action '%s' has no authored direction in res://assets/characters/complete-animation-regions.json; using the three-frame built-in pose fallback." % action)

func _avatar_action_duration(action: String, direction: String = "front") -> float:
	if not _has_authored_avatar_action(action, direction):
		return 0.8
	var source_action := _avatar_source_action(action, direction)
	var duration: float = avatar_renderer.animation_library.sequence_duration("traveller", source_action, direction)
	if not is_finite(duration) or duration <= 0.0:
		return 0.8
	return clampf(duration, 0.1, 8.0)

func set_avatar_look(appearance: Dictionary, equipped: Dictionary) -> void:
	if embedded_in != null:
		avatar_appearance = appearance
		avatar_equipped = equipped
		return
	if is_instance_valid(district_host): district_host.set_avatar_look(appearance, equipped)
	if avatar_appearance == appearance and avatar_equipped == equipped: return
	var held_frame := maxi(0,last_avatar_frame)
	avatar_appearance=appearance.duplicate(true)
	avatar_equipped=equipped.duplicate(true)
	if avatar_motion_available:
		avatar_motion_rig.set_appearance(avatar_appearance,avatar_equipped)
	last_avatar_frame=-1
	_refresh_avatar_texture(held_frame)

func _refresh_avatar_texture(frame: int) -> void:
	if embedded_in != null:
		embedded_in._refresh_avatar_texture(frame)
		return
	if not is_instance_valid(avatar) or avatar_renderer == null: return
	var riding := is_riding()
	var action := "sit" if riding else (avatar_action if avatar_action_remaining > 0.0 and not avatar_is_walking else ("walk" if avatar_is_walking else "idle"))
	var direction := "front" if riding else facing
	if avatar_motion_available:
		avatar_motion_rig.visible=false
	avatar.visible=true
	var display_frame := _ride_pose_frame() if riding else frame
	var texture_action := action
	if action == "walk":
		if _avatar_pivot_remaining > 0.0:
			var depth := _avatar_pivot_target in ["front", "back"]
			var headings := AVATAR_DEPTH_PIVOT_HEADINGS if depth else AVATAR_PIVOT_HEADINGS
			var duration := AVATAR_DEPTH_PIVOT_SECONDS if depth else AVATAR_PIVOT_SECONDS
			var count := headings.size()
			var index := clampi(floori((1.0 - _avatar_pivot_remaining / duration) * count), 0, count - 1)
			direction = headings[index if _avatar_pivot_target in ["right","back"] else count - 1 - index]
			texture_action = AVATAR_DEPTH_PIVOT_ACTION if depth else (AVATAR_DEPARTURE_ACTION if direction == "back_left" else AVATAR_PIVOT_ACTION)
		elif _avatar_departure_remaining > 0.0:
			texture_action = AVATAR_DEPARTURE_ACTION
	if action == "idle":
		if avatar_renderer.has_authored_action("idle", direction):
			# Start settled instead of entering halfway through a breath or blink.
			if last_avatar_source_action != "idle" or last_avatar_direction != direction or reduced_motion:
				_avatar_idle_started_at = time
			display_frame = avatar_renderer.idle_frame_for_time(direction, time - _avatar_idle_started_at, reduced_motion)
		elif avatar_renderer.has_walk_atlas():
			# Missing idle art keeps the authored walk stance for this heading.
			display_frame = avatar_renderer.walk_idle_frame(direction)
			texture_action = "walk"
	if action != "walk" and action != "idle" and not riding:
		var animation_library = avatar_renderer.animation_library
		if _has_authored_avatar_action(action, direction):
			texture_action = _avatar_source_action(action, direction)
			display_frame=animation_library.frame_for_time("traveller", texture_action, direction, avatar_action_elapsed if action == avatar_action else time, reduced_motion)
		else:
			# The built-in fallback has only three authored-looking poses. Advance
			# those safely instead of leaving it on the unrelated walk phase.
			display_frame=0 if reduced_motion else mini(floori(maxf(0.0,avatar_action_elapsed)*3.0),2)
	if last_avatar_direction == direction and last_avatar_frame == display_frame and last_avatar_action == action and last_avatar_source_action == texture_action: return
	var source_frame := 0 if texture_action in [AVATAR_DEPARTURE_ACTION, AVATAR_PIVOT_ACTION, AVATAR_DEPTH_PIVOT_ACTION] else display_frame
	avatar.texture=avatar_renderer.texture(avatar_appearance,avatar_equipped,direction,source_frame,texture_action)
	if is_instance_valid(avatar_hair_rig):
		avatar.texture=avatar_hair_rig.sync_pose(avatar.texture,avatar_renderer,avatar_appearance,avatar_equipped,direction,source_frame,texture_action)
	var avatar_material := avatar.material_override as ShaderMaterial
	if avatar_material != null:
		avatar_material.set_shader_parameter("texture_albedo",avatar.texture)
	last_avatar_direction=direction
	last_avatar_frame=display_frame
	last_avatar_action=action
	last_avatar_source_action=texture_action

func _ride_pose_frame() -> int:
	if reduced_motion: return 0
	var moment := float(island_attractions.ride_elapsed()) if is_instance_valid(island_attractions) else 0.0
	if moment >= 2.0 and moment < 2.5: return 1
	if moment >= 5.0 and moment < 5.5: return 2
	if moment >= 5.5 and moment < 6.0: return 3
	return 0

func set_avatar_hair_motion_enabled(value: bool) -> void:
	var held_frame := maxi(0,last_avatar_frame)
	avatar_hair_motion_enabled=value
	if is_instance_valid(avatar_hair_rig): avatar_hair_rig.set_motion_enabled(value and not reduced_motion and DisplayServer.get_name()!="headless")
	last_avatar_frame=-1
	_refresh_avatar_texture(held_frame)

func set_night(value: bool) -> void:
	set_time_of_day("night" if value else "noon")

func set_time_of_day(phase_id: Variant) -> void:
	active_time_phase = TimeOfDayScript.normalize(phase_id)
	var profile: Dictionary = TimeOfDayScript.phase_for_id(active_time_phase)
	night = active_time_phase == "night"
	air_target = environment_target(active_time_phase)
	if embedded_in == null:
		sun.rotation_degrees = profile.key_rotation_degrees
		if is_instance_valid(district_host): district_host.set_phase(active_time_phase)
		blend_air()
	# Dawn lamps are still on at 05:30 but subdued; 0.18 left their pools almost
	# invisible on the newly sunlit paving, so they read as switched off.
	lamp_energy_for_phase = float({"dawn": 0.32, "noon": 0.0, "dusk": 0.48, "night": 0.82}[active_time_phase])
	if _wayfinding_trim != null:
		if active_time_phase == "dusk":
			lamp_energy_for_phase = 0.54
		_wayfinding_trim.emission_energy_multiplier = float({"dawn": 0.18, "noon": 0.0, "dusk": 0.52, "night": 0.72}[active_time_phase])
	if welcome_sea_material != null:
		welcome_sea_material.set_shader_parameter("dock_glow", lamp_energy_for_phase)
	if ferry_window_glow != null:
		ferry_window_glow.emission_energy_multiplier = lamp_energy_for_phase * 1.8
	var band_glow := material_cache.get(DistrictBand.GLOW_KEY) as StandardMaterial3D
	if band_glow != null: band_glow.emission_energy_multiplier = lamp_energy_for_phase * 2.4
	if is_instance_valid(ambience): ambience.set_phase(active_time_phase)
	# The host chooses lamps, grades painted scenery and grounds shadows for every district.
	if embedded_in != null: return
	_update_lamp_selection(true)
	_apply_foliage_phase()
	for record in contact_shadows:
		var shadow := record.get("node") as Node3D
		if not is_instance_valid(shadow): continue
		var ground_offset: Vector3 = record.get("ground_offset",Vector3.ZERO)
		shadow.position = ground_offset

func _update_lamp_selection(force := false) -> void:
	if embedded_in != null:
		embedded_in._update_lamp_selection(force)
		return
	if not is_instance_valid(player): return
	if not force and lamp_selection_elapsed < LAMP_SELECTION_INTERVAL: return
	lamp_selection_elapsed = 0.0
	lamp_selection_player_position = player.global_position
	for slot in range(ACTIVE_LAMP_LIMIT):
		active_lamp_indices[slot] = -1
		lamp_candidate_distances[slot] = INF
	for lamp_index in range(lamps.size()):
		var lamp := lamps[lamp_index]
		# A sleeping district's lamps are hidden with it and take no slot.
		if not is_instance_valid(lamp) or not lamp.is_visible_in_tree(): continue
		var distance := player.global_position.distance_squared_to(lamp.global_position)
		for slot in range(ACTIVE_LAMP_LIMIT):
			if distance >= lamp_candidate_distances[slot]: continue
			for shift in range(ACTIVE_LAMP_LIMIT - 1, slot, -1):
				active_lamp_indices[shift] = active_lamp_indices[shift - 1]
				lamp_candidate_distances[shift] = lamp_candidate_distances[shift - 1]
			active_lamp_indices[slot] = lamp_index
			lamp_candidate_distances[slot] = distance
			break
	for slot in range(SHADOW_LAMP_LIMIT): shadow_lamp_indices[slot] = -1
	var shadow_count := 0
	# Lights an awake district keeps burning on its own take places from the budget.
	var reserved: int = district_host.steady_lights() if is_instance_valid(district_host) else 0
	for slot in range(ACTIVE_LAMP_LIMIT):
		var lamp_index := active_lamp_indices[slot]
		if lamp_index < 0: continue
		var lamp := lamps[lamp_index]
		var level := _lamp_level(lamp)
		var enabled := level > 0.0 and slot < active_lamp_budget - reserved
		lamp.light_energy = level if enabled else 0.0
		lamp.shadow_enabled = false
	# A lamp that casts whatever the hour (a district's stage spot) takes a shadow
	# place first, by day too; the rest share what is left after dark, nearest first.
	for always in [true, false]:
		for slot in range(ACTIVE_LAMP_LIMIT):
			var lamp_index := active_lamp_indices[slot]
			if lamp_index < 0 or shadow_count >= shadow_lamp_budget: continue
			var lamp := lamps[lamp_index]
			if lamp.light_energy <= 0.0 or lamp.has_meta(&"always_shadow") != always: continue
			if not always and active_time_phase not in ["dusk", "night"]: continue
			lamp.shadow_enabled = true
			# Two shadow passes per lamp instead of six; these short-range lamps look the same.
			var omni := lamp as OmniLight3D
			if omni != null and omni.omni_shadow_mode != OmniLight3D.SHADOW_DUAL_PARABOLOID:
				omni.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
			shadow_lamp_indices[shadow_count] = lamp_index
			shadow_count += 1
	for lamp_index in range(lamps.size()):
		if active_lamp_indices.has(lamp_index): continue
		var lamp := lamps[lamp_index]
		lamp.light_energy = 0.0
		lamp.shadow_enabled = false

## How bright a lamp burns when chosen: its district decides for its own lamps.
func _lamp_level(lamp: Light3D) -> float:
	var keeper: Object = lamp.get_meta(&"district") if lamp.has_meta(&"district") else null
	if is_instance_valid(keeper): return keeper.lamp_level(lamp)
	# A lamp with a level of its own (one that burns whatever the hour) keeps it standing alone too.
	return lamp_level(lamp) if lamp.has_meta(&"level") else lamp_energy_for_phase

## Lights an embedded district keeps burning outside the shared lamp list
## (light pools, a glow over beds); the host counts them once it is built.
var steady_lights := 0

func steady_light_count() -> int:
	return steady_lights if is_visible_in_tree() else 0

## A district's brightness for one of its lamps in the current phase.
func lamp_level(_lamp: Light3D) -> float:
	return lamp_energy_for_phase

func apply_settings(settings: Dictionary) -> void:
	reduced_motion=bool(settings.get("reduced_motion",false))
	if embedded_in != null:
		_apply_motion_setting()
		return
	if is_instance_valid(district_host): district_host.apply_settings(settings)
	if reduced_motion:
		_stop_follow_interpolation()
		_avatar_departure_remaining = 0.0
		_avatar_pivot_remaining = 0.0
	if reduced_motion and avatar_action in [AVATAR_CAMERA_IDLE_ACTION, AVATAR_STOP_ACTION]:
		avatar_action = ""
		avatar_action_remaining = 0.0
		avatar_action_elapsed = 0.0
	set_avatar_hair_motion_enabled(avatar_hair_motion_enabled)
	_apply_motion_setting()
	if is_instance_valid(occlusion_controller): occlusion_controller.set_reduced_motion(reduced_motion)
	if is_instance_valid(island_attractions): island_attractions.set_reduced_motion(reduced_motion)
	_apply_render_quality(RenderQuality.normalize(settings.get("graphics_quality", RenderQuality.DEFAULT_LEVEL)))

## Reduced motion for the moving things this world built itself.
func _apply_motion_setting() -> void:
	var water_motion := 0.0 if reduced_motion else 1.0
	if sea_material != null: sea_material.set_shader_parameter("motion", water_motion)
	if welcome_sea_material != null: welcome_sea_material.set_shader_parameter("motion", water_motion)
	if fountain_water != null: fountain_water.set_shader_parameter("motion", water_motion)
	if is_instance_valid(component_motion): component_motion.set_reduced_motion(reduced_motion)
	if is_instance_valid(npc_activity): npc_activity.set_reduced_motion(reduced_motion)
	if is_instance_valid(ambience): ambience.set_reduced_motion(reduced_motion)

## Apply a picture-quality level once; repeated settings refreshes cost nothing.
func _apply_render_quality(level: String) -> void:
	if level == render_quality: return
	render_quality = level
	var profile := RenderQuality.profile(level)
	if environment != null:
		environment.ssao_enabled = bool(profile.ssao)
		environment.glow_enabled = bool(profile.glow)
	active_lamp_budget = mini(int(profile.active_lamps), ACTIVE_LAMP_LIMIT)
	shadow_lamp_budget = mini(int(profile.lamp_shadows), SHADOW_LAMP_LIMIT)
	if is_instance_valid(ambience): ambience.set_quality(bool(profile.cloud_shade), bool(profile.air_particles))
	if sun != null:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(profile.sun_splits) >= 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	trim_small_shadows(self)
	if is_instance_valid(district_host):
		for region: String in district_host.districts: trim_small_shadows(district_host.districts[region])
	RenderQuality.apply_renderer(profile)
	if is_inside_tree(): RenderQuality.apply_viewport(get_viewport(), profile)
	_update_lamp_selection(true)

## Props smaller than this (world-space bounding diagonal, metres) drop their
## shadow below "high": each caster costs a draw in every sun cascade and lamp
## for a few pixels of shade. Shadow-only proxies (actors' shadows) always cast.
const SMALL_CASTER_SPAN := 1.2

## Apply the level's small-prop shadow rule under `root`; switching back to
## "high" restores exactly the casters this switched off.
func trim_small_shadows(root: Node) -> void:
	var keep := bool(RenderQuality.profile(render_quality).small_shadows)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if keep:
			if geometry.has_meta(&"small_caster"):
				geometry.cast_shadow = geometry.get_meta(&"small_caster")
				geometry.remove_meta(&"small_caster")
			continue
		if geometry.cast_shadow in [GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY]: continue
		if not geometry.is_inside_tree() or (geometry.global_transform * geometry.get_aabb()).size.length() >= SMALL_CASTER_SPAN: continue
		geometry.set_meta(&"small_caster", geometry.cast_shadow)
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func start_ride() -> bool:
	if blocked or not is_instance_valid(island_attractions):
		return false
	var started: bool = island_attractions.start_ride()
	if started:
		_stop_follow_interpolation()
		avatar_is_walking=false
		_avatar_careful_braking = false
		avatar_action=""
		_avatar_action_on_stop = ""
		_avatar_departure_remaining = 0.0
		_avatar_pivot_remaining = 0.0
		avatar_action_remaining=0.0
		avatar_action_elapsed=0.0
		# The seat raises the player well above the ground; never solve ground
		# contacts while the 3D walk rig is hidden inside the ride pose.
		_refresh_avatar_texture(0)
		_set_ride_exit_interaction()
	return started

func end_ride() -> void:
	if is_instance_valid(island_attractions):
		island_attractions.end_ride()
	if avatar_motion_available:
		avatar_motion_rig.position.y=ground_surface_y(player.global_position)-player.global_position.y
		avatar_motion_rig.cancel_motion()
	avatar_is_walking=false
	avatar_action=""
	avatar_action_remaining=0.0
	avatar_action_elapsed=0.0
	_refresh_avatar_texture(0)

func is_riding() -> bool:
	return is_instance_valid(island_attractions) and bool(island_attractions.is_riding())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(island_attractions):
		island_attractions.end_ride()

func update_collection(photos: Dictionary) -> void:
	for point in points:
		# A district marks its own entries.
		if point.has("region"): continue
		var source := ""
		if point.id.begins_with("game-"):
			source="photo-welcome-game-%d"%int(point.id.trim_prefix("game-"))
		elif point.id.begins_with("explore-"):
			source="photo-welcome-explore-%d"%int(point.id.trim_prefix("explore-"))
		elif point.id.begins_with("quest-"):
			source="photo-welcome-quest-%d"%int(point.id.trim_prefix("quest-"))
		elif point.id=="guide": source="photo-welcome-story-1"
		var marker: Label3D=point.marker
		marker.text="✓" if not source.is_empty() and photos.has(source) else "◇"
		marker.modulate=Color("#83d3ae") if marker.text=="✓" else GOLD

func refresh_label_fonts(font: Font) -> void:
	if font == null or font == _last_label_font:
		return
	_last_label_font = font
	var display := FontProfiles.role_font("display")
	for node: Node in find_children("*", "Label3D", true, false):
		(node as Label3D).font = display if node.has_meta(SIGN_TITLE) else font
