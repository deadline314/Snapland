extends "res://game/world/park_world.gd"

const ProjectionScript = preload("res://game/world/circus_projection.gd")
const Backdrop = preload("res://game/world/nightmarket_skyline.gdshader")
const VelvetShader = preload("res://game/world/circus_velvet.gdshader")
const RegionalVisit = preload("res://game/story/regional_visit.gd")
const CURTAIN_ART := "res://assets/world/circus-tent.webp"
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
## Stands 1.2 m clear of the cabinet and the foyer lamp post.
const PHOTO_BOOTH_POINT := Vector3(-2.50, GROUND_Y, 7.85)
const BOUNDS := Rect2(-12.25, -12.0, 24.5, 21.5)
const AREAS: Array[Dictionary] = [
	{"id": "entry", "label": "馬戲團入口", "rect": Rect2(-4, 4.8, 8, 4.7), "tile": 0, "tint": Color("#827686")},
	{"id": "mirrors", "label": "鏡廊", "rect": Rect2(-12.25, -5.2, 8.25, 11.10), "tile": 0, "tint": Color("#7e959e")},
	{"id": "auditorium", "label": "觀眾席", "rect": Rect2(-4, -5.2, 8, 10.0), "tile": 1, "tint": Color("#a67177")},
	{"id": "shadow", "label": "影子台", "rect": Rect2(4, -5.2, 8.25, 11.10), "tile": 1, "tint": Color("#98798a")},
	{"id": "mats", "label": "砲彈安全墊", "rect": Rect2(-8.8, -12.0, 17.6, 6.8), "tile": 0, "tint": Color("#7b9194")},
]
const INK := Color("#29263e")
const BRASS := Color("#bb905d")
const PARCHMENT := Color("#ffe0ab")
const VELVET := Color("#723e51")
const GLASS := Color("#759ea7")
const POOL_SPECS := [
	{"position": Vector3(-8.35, 2.75, -1.30), "color": Color("#b4d9f2"), "radius": 6.4},
	{"position": Vector3(7.15, 2.64, -0.48), "color": Color("#ffd2a0"), "radius": 6.2},
]

var _projection: ProjectionScript
var _backdrop_material: ShaderMaterial
var _pools: Array[OmniLight3D] = []
var _trim_meshes: Dictionary = {}
var _accent_materials: Dictionary = {}
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
	_build_backdrop()
	_build_tent_framing()
	for area in AREAS:
		var rect: Rect2 = area.rect
		var center := rect.get_center()
		var floor_mesh := _box(Vector3(center.x, GROUND_Y - 0.15, center.y),
			Vector3(rect.size.x, 0.30, rect.size.y), area.tint, true)
		floor_mesh.name = "CircusFloor_" + String(area.id)
		_set_registered_surface(floor_mesh, _coastal_surface(area.tile, 3.9, area.tint))
	_build_foyer()
	_build_mirrors()
	_build_auditorium()
	_build_shadow_stage()
	_build_rehearsal()
	_build_local_lights()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("circus:mirrors", "鏡廊 · 看鏡像角標", MIRRORS)
	_point("circus:auditorium", "觀眾席 · 走中央通道", AUDITORIUM)
	_point("circus:shadow", "影子台 · 切換左／右燈", SHADOW_STAGE)
	_point("circus:mats", "砲彈安全墊 · 看練習區", MATS)
	_npc(STORY_HOST, VELVET, "小角")
	_point(RegionalVisit.CIRCUS_POINT, "馬戲團迎賓 · 和小角合照", STORY_POINT)
	_build_photo_booth()
	_point("game-049", "哈哈鏡大頭貼 · 按一下停一格", PHOTO_BOOTH_POINT)
	current_area = _area_at_position(ENTRY)


func _build_backdrop() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(82.0, 82.0)
	var apron := _mesh(ground, Vector3(0, -0.49, 0), _coastal_surface(1, 5.5, Color("#40374c")))
	apron.name = "CircusMatteApron"
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foundation := _box(Vector3(0, -0.25, -1.22), Vector3(29.70, 0.32, 23.6), Color("#514052"))
	foundation.name = "CircusFoundation"
	_set_registered_surface(foundation, _coastal_surface(0, 6.15, Color("#555064")))
	var art := load(CURTAIN_ART) as Texture2D if ResourceLoader.exists(CURTAIN_ART) else null
	if art == null:
		return
	var panel := QuadMesh.new()
	panel.size = Vector2(44.0, 19.5)
	_backdrop_material = ShaderMaterial.new()
	_backdrop_material.shader = Backdrop
	_backdrop_material.set_shader_parameter("skyline_texture", art)
	var wall := _mesh(panel, Vector3(0, 6.1, -13.4), _backdrop_material)
	wall.name = "CircusTentBackdrop"
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_tent_framing() -> void:
	var panel := QuadMesh.new()
	panel.size = Vector2(3.24, 3.54)
	var curtain := ShaderMaterial.new()
	curtain.shader = VelvetShader
	curtain.set_shader_parameter("velvet", Color("#654059"))
	curtain.set_shader_parameter("hem", Color("#a67c64"))
	var frame := Color("#5b435c")
	for side in [-1.0, 1.0]:
		var x: float = 14.0 * side
		var edge := _box(Vector3(x, -0.041, -1.40), Vector3(0.42, 0.105, 21.3), frame)
		_set_registered_surface(edge, _coastal_surface(3, 3.15, frame))
		for z in [-9.15, -3.73, 1.69, 7.11]:
			var at := Vector3(x, -0.09, z)
			_box(at + Vector3(0, 0.18, 0), Vector3(0.74, 0.36, 0.70), frame)
			var pole := _box(at + Vector3(0, 1.96, 0), Vector3(0.23, 3.55, 0.22), Color("#796073"))
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(at + Vector3(0, 0.45, 0), Vector3(0.42, 0.08, 0.34), BRASS.darkened(0.24))
			_box(at + Vector3(0, 3.54, 0), Vector3(0.45, 0.10, 0.40), BRASS.darkened(0.24))
			var drape := _mesh(panel, at + Vector3(side * 1.03, 1.83, -1.12), curtain)
			drape.rotation.y = -side * 0.88
			drape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var threshold := Color("#6b5261")
	for x in [-9.22, 9.22]:
		_box(Vector3(x, -0.026, 10.38), Vector3(10.75, 0.12, 0.20), threshold)
		for z in [9.95, 10.74]:
			_box(Vector3(x, -0.04, z), Vector3(10.75, 0.059, 0.07), BRASS.darkened(0.42))


func _build_foyer() -> void:
	_box(Vector3(0, GROUND_Y + 0.018, 7.12), Vector3(5.8, 0.031, 4.36), Color("#764458"))
	for x in [-2.83, 2.83]:
		_emblem_strip(Vector3(x, GROUND_Y + 0.040, 7.12), Vector3(0.075, 0.022, 4.1), BRASS)
	for x in [-3.75, 3.75]:
		_box(Vector3(x, GROUND_Y + 0.29, 8.90), Vector3(0.58, 0.58, 0.48), VELVET)
		_box(Vector3(x, GROUND_Y + 1.05, 8.90), Vector3(0.29, 1.55, 0.30), Color("#4f3551"))
		_lamp_cap(Vector3(x, GROUND_Y + 1.88, 8.90), BRASS)
	_plaque("鏡之馬戲團", Vector3(2.35, GROUND_Y + 2.63, 8.75), 3.25, BRASS)


## Entry stand of game-049. Self-contained so the foyer can be restyled around it.
func _build_photo_booth() -> void:
	var at := PHOTO_BOOTH
	var canopy := _box(at + Vector3(0, 2.02, 0.12), Vector3(1.36, 0.12, 1.12), BRASS.darkened(0.25))
	# The canopy leans out over the mirror so the stand is not a plain box.
	canopy.rotation.x = 0.16
	var gleam := _emblem_strip(at + Vector3(-0.12, 1.28, 0.47), Vector3(0.07, 0.70, 0.012), Color("#e2f6f6"))
	gleam.rotation.z = -0.2
	var parts: Array[Node3D] = [
		_box(at + Vector3(0, 0.09, 0), Vector3(1.30, 0.18, 0.98), Color("#4f3551")),
		_box(at + Vector3(0, 1.03, 0), Vector3(1.10, 1.70, 0.80), Color("#8a3f58"), true),
		canopy,
		_box(at + Vector3(0, 1.25, 0.41), Vector3(0.80, 0.98, 0.06), BRASS),
		_emblem_strip(at + Vector3(0, 1.25, 0.45), Vector3(0.66, 0.84, 0.03), Color("#a9dbe2")),
		gleam,
		_box(at + Vector3(0, 0.56, 0.42), Vector3(0.46, 0.06, 0.05), INK),
		_emblem_strip(at + Vector3(0, 0.42, 0.44), Vector3(0.30, 0.22, 0.03), PARCHMENT),
	]
	# The stand steps out of the welcome group photo, like the plaques do.
	_story_photo_signs.append_array(parts)
	_plaque("哈哈鏡大頭貼", at + Vector3(0, 2.44, 0.30), 2.05, BRASS)


func _build_mirrors() -> void:
	for index in 3:
		var x := -10.72 + 2.48 * float(index)
		var at := Vector3(x, GROUND_Y, -2.85)
		_box(at + Vector3(0, 1.23, 0), Vector3(2.03, 2.46, 0.30), INK, true)
		_box(at + Vector3(0, 1.22, 0.18), Vector3(1.83, 2.27, 0.10), BRASS)
		_emblem_strip(at + Vector3(0, 1.23, 0.251), Vector3(1.60, 2.03, 0.045), Color("#414f6d"))
		_emblem_strip(at + Vector3(0, 1.90, 0.279), Vector3(1.59, 0.53, 0.019), Color("#637991"))
		var gleam := _emblem_strip(at + Vector3(-0.28, 1.32, 0.291), Vector3(0.092, 1.70, 0.018), GLASS)
		gleam.rotation.z = -0.23
		var seam := _emblem_strip(at + Vector3(0.10, 1.23, 0.292), Vector3(0.032, 1.65, 0.016), Color("#9aaeae"))
		seam.rotation.z = gleam.rotation.z
		_box(at + Vector3(0, 0.09, 0.27), Vector3(2.20, 0.18, 0.68), Color("#514d65"))
		_emblem_strip(at + Vector3(0.56, 0.37, 0.29), Vector3(0.29, 0.17, 0.035), PARCHMENT)
	_plaque("鏡廊 · 鏡像示意", Vector3(-8.20, GROUND_Y + 2.77, -2.51), 3.10, GLASS)
	_deck_inlay(Vector3(-8.12, GROUND_Y, 0.80), GLASS)


func _build_auditorium() -> void:
	_box(Vector3(0, GROUND_Y + 0.025, -0.30), Vector3(1.73, 0.045, 7.62), Color("#6b3b51"))
	for x in [-0.79, 0.79]:
		_emblem_strip(Vector3(x, GROUND_Y + 0.05, -0.30), Vector3(0.040, 0.018, 7.58), BRASS)
	for x in [-2.41, 2.41]:
		for z in [-3.1, -1.32, 0.46, 2.24]:
			var at := Vector3(x, GROUND_Y, z)
			_box(at + Vector3(0, 0.30, 0), Vector3(2.20, 0.57, 0.66), Color("#54404d"), true)
			_box(at + Vector3(0, 0.61, 0.04), Vector3(2.02, 0.18, 0.62), VELVET)
			_box(at + Vector3(0, 0.76, -0.27), Vector3(2.18, 0.58, 0.14), Color("#864c61"))
			for offset in [-0.70, 0.0, 0.70]:
				_emblem_strip(at + Vector3(offset, 0.65, 0.35), Vector3(0.046, 0.05, 0.032), BRASS)
	_plaque("觀眾席", Vector3(0, GROUND_Y + 1.36, -4.78), 2.15, BRASS)


func _build_shadow_stage() -> void:
	var origin := Vector3(SHADOW_STAGE.x, GROUND_Y, 0)
	_box(origin + Vector3(0, 0.108, -2.85), Vector3(5.6, 0.21, 2.64), INK)
	_box(origin + Vector3(0, 1.52, -4.02), Vector3(4.58, 2.91, 0.20), VELVET, true)
	for x in [-2.42, 2.42]:
		_box(origin + Vector3(x, 1.56, -3.88), Vector3(0.29, 3.05, 0.31), VELVET, true)
		_box(origin + Vector3(x, 1.59, -3.62), Vector3(0.085, 2.84, 0.10), BRASS)
		_lamp_cap(origin + Vector3(x, 0.53, -1.40), BRASS)
	_box(origin + Vector3(0, 2.99, -3.88), Vector3(5.15, 0.30, 0.42), VELVET)
	_emblem_strip(origin + Vector3(0, 2.99, -3.64), Vector3(4.77, 0.072, 0.05), BRASS)
	_box(origin + Vector3(0, 0.32, -1.05), Vector3(2.96, 0.26, 0.29), Color("#503a4a"))
	_emblem_strip(origin + Vector3(0, 0.44, -0.95), Vector3(2.77, 0.056, 0.09), BRASS)
	_projection = ProjectionScript.new()
	_projection.name = "CircusProjection"
	_projection.position = origin
	add_child(_projection)
	_plaque("影子台", origin + Vector3(0, 3.42, -3.63), 2.05, BRASS)
	_lamp_plaque = _plaque("", origin + Vector3(0, 0.78, -0.84), 2.45, BRASS)
	_lamp_plaque.text = _projection_label()
	_deck_inlay(SHADOW_STAGE, BRASS)


func _build_rehearsal() -> void:
	var center := MATS + Vector3(0, 0.054, 0)
	var mattress := _cylinder(center, 2.68, 0.11, Color("#4d7e83"), 2.56)
	mattress.name = "CircusPaddedLanding"
	_cylinder(center + Vector3(0, 0.06, 0), 2.16, 0.04, Color("#668f86"), 2.16)
	_cylinder(center + Vector3(0, 0.088, 0), 1.48, 0.025, Color("#416f75"), 1.46)
	for slot in 12:
		var angle := TAU * float(slot) / 12.0
		var offset := Vector3(cos(angle), 0, sin(angle)) * 2.35
		var stitch := _emblem_strip(center + offset + Vector3(0, 0.066, 0), Vector3(0.30, 0.020, 0.085), Color("#aed1bb"))
		stitch.rotation.y = -angle
	for x in [-4.9, 4.9]:
		_box(Vector3(x, GROUND_Y + 0.2, -9.92), Vector3(1.14, 0.39, 1.23), Color("#747185"))
		_box(Vector3(x, GROUND_Y + 0.43, -9.92), Vector3(1.03, 0.19, 1.18), Color("#aa7980"))
		_emblem_strip(Vector3(x, GROUND_Y + 0.57, -9.92), Vector3(0.88, 0.11, 1.06), Color("#d19791"))
	_plaque("砲彈安全墊", Vector3(0, GROUND_Y + 1.45, -11.15), 2.9, GLASS)


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


func _box(at: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	if solid:
		return super._box(at, size, color, true)
	var mesh := _trim_meshes.get(size) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_trim_meshes[size] = mesh
	return _mesh(mesh, at, _finish(color, size))


func _emblem_strip(at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var piece := _box(at, size, tint)
	var material := _accent_materials.get(tint) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = tint
		_accent_materials[tint] = material
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


func _lamp_cap(at: Vector3, tint: Color) -> void:
	_box(at - Vector3(0, 0.13, 0), Vector3(0.42, 0.16, 0.35), INK)
	_emblem_strip(at, Vector3(0.27, 0.19, 0.22), tint.lightened(0.32))
	_box(at + Vector3(0, 0.12, 0), Vector3(0.38, 0.10, 0.31), BRASS)


func _plaque(title: String, at: Vector3, width: float, accent: Color) -> Label3D:
	var board := _box(at, Vector3(width, 0.46, 0.13), INK)
	var trim := _emblem_strip(at + Vector3(0, -0.225, 0.085), Vector3(width, 0.045, 0.05), accent)
	var label := _local_label(title, at + Vector3(0, 0.014, 0.12), 29, PARCHMENT)
	_story_photo_signs.append_array([board, trim, label])
	label.pixel_size = 0.0134
	return label


func _deck_inlay(at: Vector3, tint: Color) -> void:
	for x in [-0.33, 0.33]:
		_emblem_strip(at + Vector3(x, 0.016, 0), Vector3(0.057, 0.024, 0.79), tint)
	for z in [-0.36, 0.36]:
		_emblem_strip(at + Vector3(0, 0.016, z), Vector3(0.64, 0.024, 0.058), tint)


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
	# Eye-level framing lets the rear tent fabric replace most of the rehearsal floor.
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
	return GROUND_Y if _on_floor_plan(Vector2(position.x, position.z)) else -0.40


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


func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	if reduced_motion and is_instance_valid(_projection) and _projection.is_moving():
		_projection.finish_transition()


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	var evening := active_time_phase in ["dusk", "night"]
	var haze := Color("#211d33") if evening else Color("#302b40")
	environment.background_color = haze
	environment.fog_light_color = haze
	environment.ambient_light_color = Color("#b3c0e8") if evening else Color("#ded2eb")
	environment.ambient_light_energy = 0.78 if evening else 0.82
	sun.light_color = Color("#e7d5ee")
	sun.light_energy = 0.37 if evening else 0.56
	for pool in _pools:
		pool.light_energy = 1.02 if evening else 0.72
	if _backdrop_material != null:
		_backdrop_material.set_shader_parameter("haze", haze)


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
