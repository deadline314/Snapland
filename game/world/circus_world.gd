extends "res://game/world/park_world.gd"
## Mirror Circus: a camp in a woodland clearing with a cut-away big top, a hall of
## funhouse mirrors and a shadow theatre. This script owns what the player can do
## here (the five floors, every interaction point, the reversible shadow projection
## and the welcome photo); circus_scenery builds the place and circus_life animates it.

const Kit := preload("res://game/world/scenery_kit.gd")
const Scenery := preload("res://game/world/circus_scenery.gd")
const Life := preload("res://game/world/circus_life.gd")
const ProjectionScript = preload("res://game/world/circus_projection.gd")
const RegionalVisit = preload("res://game/story/regional_visit.gd")
const GROUND_Y := 0.20
const ENTRY := Vector3(0, GROUND_Y, 7.8)
const STORY_POINT := Vector3(-0.95, GROUND_Y, 5.15)
const STORY_HOST := Vector3(-1.82, GROUND_Y, 5.32)
const STORY_GUEST := Vector3(0.10, GROUND_Y, 5.32)
const MIRRORS := Vector3(-8.1, GROUND_Y, 0.85)
const AUDITORIUM := Vector3(0, GROUND_Y, 0.20)
const SHADOW_STAGE := Vector3(8.1, GROUND_Y, 0.75)
const MATS := Vector3(0, GROUND_Y, -8.8)
const PHOTO_BOOTH := Vector3(-3.30, GROUND_Y, 6.25)
## Stands 1.2 m clear of the cabinet.
const PHOTO_BOOTH_POINT := Vector3(-2.50, GROUND_Y, 7.85)
const REFLECTION_STAND := Vector3(-10.90, GROUND_Y, 3.20)
const REFLECTION_POINT := Vector3(-10.90, GROUND_Y, 4.85)
const BOUNDS := Rect2(-12.25, -12.0, 24.5, 21.5)
## `tile` is a surface from the shared material atlas; -1 is the ring's sawdust.
const AREAS: Array[Dictionary] = [
	{"id": "entry", "label": "馬戲團入口", "rect": Rect2(-4, 4.8, 8, 4.7), "tile": 4, "tint": Color("#f0dfc0")},
	{"id": "mirrors", "label": "鏡廊", "rect": Rect2(-12.25, -5.2, 8.25, 11.10), "tile": 4, "tint": Color("#cdbfe6")},
	{"id": "auditorium", "label": "觀眾席", "rect": Rect2(-4, -5.2, 8, 10.0), "tile": 1, "tint": Color("#e6cfaa")},
	{"id": "shadow", "label": "影子台", "rect": Rect2(4, -5.2, 8.25, 11.10), "tile": 1, "tint": Color("#caa7b4")},
	{"id": "mats", "label": "砲彈安全墊", "rect": Rect2(-8.8, -12.0, 17.6, 6.8), "tile": -1, "tint": Color("#dcbd88")},
]
## Empty pitches kept for the district's next games. Each is where a stand goes;
## its interaction point belongs PITCH_REACH further south, which leaves the usual
## clearance. A stand here hides nothing the player can walk behind, or as little
## as the two delivered cabinets do.
const PITCHES: Array[Vector3] = [
	Vector3(-8.3, GROUND_Y, -11.35), Vector3(-6.4, GROUND_Y, -11.35), Vector3(6.4, GROUND_Y, -11.35), Vector3(8.3, GROUND_Y, -11.35),
	Vector3(-10.9, GROUND_Y, -4.45), Vector3(11.5, GROUND_Y, -4.45), Vector3(-6.4, GROUND_Y, 3.2),
	Vector3(6.4, GROUND_Y, 3.6), Vector3(10.6, GROUND_Y, 3.6), Vector3(3.3, GROUND_Y, 6.25),
]
const PITCH_REACH := 1.65
## Delivered games that took a pitch: the cabinet replaces the pitch's mat and the
## interaction point sits PITCH_REACH south of it. `topper` names the little act
## on the canopy (circus_scenery.gd).
const PITCH_GAMES: Array[Dictionary] = [
	{"pitch": 9, "id": "game-052", "title": "接飛碟", "prompt": "接飛碟 · 飛碟到圈裡就按", "body": Color("#b8553f"), "shape": "oval", "topper": "plates"},
]
const VELVET := Color("#723e51")
const POOL_SPECS := [
	{"position": Vector3(-8.35, 2.75, -1.30), "color": Color("#b4d9f2"), "radius": 6.4},
	{"position": Vector3(7.15, 2.64, -0.48), "color": Color("#ffd2a0"), "radius": 6.2},
]

var _kit: Kit
var _scenery: Scenery
var _life: Life
var _projection: ProjectionScript
var _pools: Array[OmniLight3D] = []
var _lamp_plaque: Label3D
var _story_photo_camera: Camera3D
var _story_photo_origin: Vector3
var _story_photo_facing := "front"
var _story_host_sprite: Sprite3D
var _story_photo_signs: Array[Node3D] = []
var _story_photo_sign_visibility: Dictionary[Node3D, bool] = {}
var _story_rest_pose: Texture2D
var _story_photo_pose: Texture2D


func _build_region_geometry() -> void:
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	_scenery.build()
	_projection = ProjectionScript.new()
	_projection.name = "CircusProjection"
	_projection.position = Vector3(SHADOW_STAGE.x, GROUND_Y, 0)
	add_child(_projection)
	_lamp_plaque = _scenery.lamp_plaque
	_lamp_plaque.text = _projection_label()
	_build_local_lights()
	_life = Life.new(self, _scenery)
	_life.build()
	_kit.finish()
	_life.hold_still()
	# Everything the welcome photo would catch in front of its two subjects.
	_story_photo_signs.append_array(_scenery.photo_clutter)
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("circus:mirrors", "鏡廊 · 走近看看自己", MIRRORS)
	_point("circus:auditorium", "觀眾席 · 走中央通道", AUDITORIUM)
	_point("circus:shadow", "影子台 · 切換左／右燈", SHADOW_STAGE)
	_point("circus:mats", "砲彈安全墊 · 站上表演圈", MATS)
	_npc(STORY_HOST, VELVET, "小角")
	_point(RegionalVisit.CIRCUS_POINT, "馬戲團迎賓 · 和小角合照", STORY_POINT)
	_point("game-049", "哈哈鏡大頭貼 · 按一下停一格", PHOTO_BOOTH_POINT)
	_point("game-050", "誰是假倒影 · 擺姿勢抓假的", REFLECTION_POINT)
	for stand: Dictionary in PITCH_GAMES:
		_point(stand.id, stand.prompt, PITCHES[stand.pitch] + Vector3(0, 0, PITCH_REACH))
	current_area = _area_at_position(ENTRY)


func _build_local_lights() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for spec in POOL_SPECS:
		var light := OmniLight3D.new()
		light.position = spec.position
		light.light_color = spec.color
		light.omni_range = spec.radius
		light.omni_attenuation = 1.4
		light.light_specular = 0.16
		light.shadow_enabled = false
		add_child(light)
		_pools.append(light)


func _build_region_activities() -> void:
	pass


func _register_npc_activity() -> void:
	# The host stays at the welcome station. Use the same authored cels as the island imp.
	var actor := _npc_record_for_role("imp")
	_story_host_sprite = actor.get("sprite") as Sprite3D
	var name_label := actor.get("name_label") as Label3D
	if is_instance_valid(name_label):
		_story_photo_signs.append(name_label)
	if not is_instance_valid(_story_host_sprite) or avatar_renderer == null:
		return
	_story_rest_pose = _story_host_sprite.texture
	var library: RefCounted = avatar_renderer.animation_library
	var idle := library.texture("imp", "idle", "front", 0) as Texture2D
	var greeting := library.texture("imp", "greet", "front", 4) as Texture2D
	if idle != null:
		_story_rest_pose = _fit_npc_rest_texture(idle)
	_story_photo_pose = _fit_npc_rest_texture(greeting) if greeting != null else _story_rest_pose
	_set_story_host_pose(_story_rest_pose)
	actor["name_body_height"] = _visible_body_height(_story_host_sprite)


func begin_story_photo() -> bool:
	if is_instance_valid(_story_photo_camera) or not is_instance_valid(player) or not is_instance_valid(_story_host_sprite):
		return false
	_story_photo_origin = player.position
	_story_photo_facing = facing
	_set_story_host_pose(_story_photo_pose)
	for sign in _story_photo_signs:
		if is_instance_valid(sign):
			_story_photo_sign_visibility[sign] = sign.visible
			sign.hide()
	_position_story_guest(STORY_GUEST, "front")
	_set_interaction_marker(null)
	# Eye-level framing looks down the aisle, past the stalls, to the ring and the big top.
	var center := STORY_HOST.lerp(STORY_GUEST, 0.5) + Vector3(0, 1.13, 0)
	_story_photo_camera = Camera3D.new()
	_story_photo_camera.name = "CircusGroupPhotoCamera"
	_story_photo_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_story_photo_camera.size = 5.35
	_story_photo_camera.far = camera.far
	_story_photo_camera.position = center + Vector3(-0.38, 0.92, 8.9)
	add_child(_story_photo_camera)
	_story_photo_camera.look_at(center)
	_story_photo_camera.make_current()
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.32, -0.52, -5.35)
	fill.light_color = Color("#ffe4cf")
	fill.light_energy = 0.87
	fill.omni_range = 6.4
	fill.shadow_enabled = false
	_story_photo_camera.add_child(fill)
	return true


func end_story_photo() -> void:
	if not is_instance_valid(_story_photo_camera):
		return
	camera.make_current()
	_story_photo_camera.queue_free()
	_story_photo_camera = null
	for sign in _story_photo_sign_visibility:
		if is_instance_valid(sign):
			sign.visible = _story_photo_sign_visibility[sign]
	_story_photo_sign_visibility.clear()
	_set_story_host_pose(_story_rest_pose)
	_position_story_guest(_story_photo_origin, _story_photo_facing)


func _position_story_guest(at: Vector3, direction: String) -> void:
	player.position = at
	player.velocity = Vector3.ZERO
	_sync_external_avatar_reposition()
	facing = direction
	avatar_action = ""
	avatar_action_remaining = 0.0
	avatar_action_elapsed = 0.0
	_refresh_avatar_texture(0)


func _set_story_host_pose(texture: Texture2D) -> void:
	if not is_instance_valid(_story_host_sprite) or texture == null:
		return
	_story_host_sprite.texture = texture
	var material := _story_host_sprite.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("texture_albedo", texture)
		material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))


func _interaction_markers_allowed() -> bool:
	return not is_instance_valid(_story_photo_camera)


func _update_district_label_visibility() -> void:
	if not is_instance_valid(_story_photo_camera):
		super._update_district_label_visibility()


func _build_player_floor() -> void:
	pass


func update_collection(_photos: Dictionary) -> void:
	pass


func _player_spawn_position() -> Vector3:
	return ENTRY


func _area_at_position(position: Vector3) -> String:
	var point := Vector2(position.x, position.z)
	for area in AREAS:
		if area.rect.has_point(point):
			return area.label
	return "馬戲團入口"


func _on_floor_plan(point: Vector2) -> bool:
	for area in AREAS:
		if area.rect.has_point(point):
			return true
	return false


func ground_surface_y(position: Vector3) -> float:
	# Outside the five floors the yard and the meadow carry the camp's props.
	return GROUND_Y if _on_floor_plan(Vector2(position.x, position.z)) else Scenery.MEADOW_Y


func _safe_footing(position: Vector3) -> bool:
	var at := Vector2(position.x, position.z)
	return (_on_floor_plan(at + Vector2(-0.30, -0.30))
		and _on_floor_plan(at + Vector2(0.30, -0.30))
		and _on_floor_plan(at + Vector2(-0.30, 0.30))
		and _on_floor_plan(at + Vector2(0.30, 0.30)))


func _constrain_player(previous_position: Vector3) -> bool:
	if player.position.y < -1.0 or not _safe_footing(previous_position):
		return _reset_to_entry()
	if not _safe_footing(player.position):
		player.position = previous_position
		player.velocity = Vector3.ZERO
	return false


func _reset_to_entry() -> bool:
	player.position = ENTRY
	player.velocity = Vector3.ZERO
	_sync_external_avatar_reposition()
	avatar_is_walking = false
	walk_distance_phase = 0.0
	avatar_action = ""
	avatar_action_remaining = 0.0
	avatar_action_elapsed = 0.0
	if is_instance_valid(avatar_hair_rig):
		avatar_hair_rig.reset_motion()
	if is_instance_valid(camera):
		camera.position = ENTRY + CAMERA_OFFSET
		camera.look_at(ENTRY + Vector3(0, 1, 0))
	_refresh_avatar_texture(0)
	_update_sprite_grounding()
	return true


func switch_projection() -> String:
	_projection.toggle(reduced_motion)
	var label := _projection_label()
	_lamp_plaque.text = label
	return label


func projection_side() -> int:
	return _projection.side


func projection_is_moving() -> bool:
	return _projection.is_moving()


func projection_shadow_center() -> Vector3:
	return _projection.shadow_center()


func _projection_label() -> String:
	return "左燈 · 影子向右" if projection_side() == 0 else "右燈 · 影子向左"


func _process(delta: float) -> void:
	super._process(delta)
	if not blocked and _projection.is_moving():
		_projection.advance(delta)
	_life.track_walker()
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta)


func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	if reduced_motion and is_instance_valid(_projection) and _projection.is_moving():
		_projection.finish_transition()


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	var evening := active_time_phase in ["dusk", "night"]
	for pool in _pools:
		pool.light_energy = 1.02 if evening else 0.36
	if _scenery != null:
		_scenery.apply_time_of_day(lamp_energy_for_phase, environment.background_color)
		_life.apply_time_of_day(lamp_energy_for_phase)


func map_snapshot() -> Dictionary:
	var land: Array[Rect2] = []
	var areas: Array[Dictionary] = []
	for area in AREAS:
		land.append(area.rect)
		areas.append({"id": area.id, "label": area.label, "rect": area.rect})
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var at: Vector3 = player.position if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": land, "areas": areas, "points": stops, "player": at, "area": _area_at_position(at), "region": "circus"}
