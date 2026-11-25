extends "res://game/world/park_world.gd"

const TrainScript := preload("res://game/world/toy_train.gd")
const Backdrop := preload("res://game/world/nightmarket_skyline.gdshader")
const WorkshopApron := preload("res://game/world/toy_workshop_apron.gdshader")
const RegionalVisit := preload("res://game/story/regional_visit.gd")
const WORKSHOP_ART := "res://assets/world/toy-clockwork-yard.webp"
const GROUND_Y := 0.20
const BOUNDS := Rect2(-12.1, -10.8, 24.2, 20.3)
const ENTRY := Vector3(0, GROUND_Y, 7.65)
const BLOCKS := Vector3(-8.0, GROUND_Y, 2.2)
const SWITCH := Vector3(6.3, GROUND_Y, 2.25)
const TRAIN := Vector3(9.5, GROUND_Y, 2.25)
const REPAIR := Vector3(-7.6, GROUND_Y, -6.95)
const TOWER := Vector3(0, GROUND_Y, -7.6)
const STORY_POINT := Vector3(5.55, GROUND_Y, 5.22)
const STORY_HOST := Vector3(5.19, GROUND_Y, 4.15)
const STORY_GUEST := Vector3(10.73, GROUND_Y, 4.15)
const STATION_ORIGIN := Vector3(8.1, GROUND_Y, -0.85)
const STATION_STATUS_AT := STATION_ORIGIN + Vector3(0, 1.43, -2.50)
const STATION_STATUS_WIDTH := 2.64
const RAIL_TABLE := Rect2(5.42, -3.11, 5.36, 4.52)
const AREAS: Array[Dictionary] = [
	{"id": "entry", "label": "玩具城入口", "rect": Rect2(-4.35, 4.7, 8.7, 4.8), "tile": 4, "tint": Color("#aea18c")},
	{"id": "blocks", "label": "積木街", "rect": Rect2(-12.1, -3.8, 7.75, 12.0), "tile": 0, "tint": Color("#af9381")},
	{"id": "tower", "label": "發條鐘樓", "rect": Rect2(-4.35, -10.8, 8.7, 15.5), "tile": 0, "tint": Color("#989784")},
	{"id": "station", "label": "車站岔道", "rect": Rect2(4.35, -3.8, 7.75, 12.0), "tile": 4, "tint": Color("#879e95")},
	{"id": "repair", "label": "維修台", "rect": Rect2(-10.9, -10.8, 6.55, 7.0), "tile": 1, "tint": Color("#ad8d72")},
]
const INK := Color("#343b42")
const BRASS := Color("#b58954")
const PARCHMENT := Color("#ffe1b2")
const STATION_TEAL := Color("#567f77")
const RED := Color("#ad6356")
const TIMBER := Color("#654b44")
const STORAGE_BLUE := Color("#46545a")
const STORAGE_WOOD := Color("#6c6052")
const STORAGE_METAL := Color("#8a765b")
const HOUSE_TONES := [Color("#886649"), Color("#64887a"), Color("#886c5b")]
const POOL_SPECS := [
	{"position": Vector3(-8.9, 2.75, -6.25), "color": Color("#ffcf9a"), "range": 7.25},
	{"position": Vector3(8.1, 3.30, 0.55), "color": Color("#e5c7a9"), "range": 6.80},
]

var _train: TrainScript
var _backdrop: ShaderMaterial
var _apron: ShaderMaterial
var _pools: Array[OmniLight3D] = []
var _mesh_cache: Dictionary = {}
var _paints: Dictionary = {}
var _tracks: Array[PackedVector2Array] = []
var _station_label: Label3D
var _control_lever: MeshInstance3D
var _clock_hour: Node3D
var _clock_minute: Node3D
var _story_photo_camera: Camera3D
var _story_host_sprite: Sprite3D
var _story_host_name: Label3D
var _story_host_rest: Texture2D
var _story_host_greeting: Texture2D
var _story_host_anchor_y := 0.0
var _story_player_visible := true
var _story_station_status_visible := false
var _story_hidden_labels: Array[Label3D] = []


func _build_region_geometry() -> void:
	_build_yard_foundation()
	for area in AREAS:
		var rect: Rect2 = area.rect
		var center := rect.get_center()
		var floor_mesh := _box(Vector3(center.x, GROUND_Y - 0.15, center.y),
			Vector3(rect.size.x, 0.30, rect.size.y), area.tint, true)
		floor_mesh.name = "ToyFloor_" + String(area.id)
		_set_registered_surface(floor_mesh, _coastal_surface(area.tile, 4.20, area.tint))
	_build_foyer()
	_build_block_street()
	_build_station()
	_build_repair()
	_build_clock_tower()
	_build_lighting_pools()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("toy:blocks", "積木街 · 看街屋", BLOCKS)
	_point("toy:switch", "岔道開關 · 換線", SWITCH)
	_point("toy:train", "列車控制 · 走停／逐站", TRAIN)
	_point("toy:repair", "維修台 · 重置列車", REPAIR)
	_point("toy:tower", "發條鐘樓 · 查看時鐘", TOWER)
	_npc(STORY_HOST, STATION_TEAL, RegionalVisit.host_name(RegionalVisit.TOY))
	_point(RegionalVisit.TOY_POINT, "玩具城迎賓 · 和阿浪合照", STORY_POINT)
	_sync_station_controls()
	current_area = _area_at_position(ENTRY)


func _build_yard_foundation() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(84.0, 84.0)
	_apron = ShaderMaterial.new()
	_apron.shader = WorkshopApron
	var base := _mesh(ground, Vector3(0, -0.48, -1), _apron)
	base.name = "ToyWorkshopApron"
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var slab := _box(Vector3(0, -0.235, -0.70), Vector3(28.2, 0.35, 23.3), Color("#77756e"))
	slab.name = "ToyWorkshopFoundation"
	_set_registered_surface(slab, _coastal_surface(0, 5.6, Color("#696962")))
	for sign in [-1, 1]:
		var x: float = float(sign) * 13.34
		var frame := _box(Vector3(x, 0.0, -1), Vector3(0.13, 0.11, 21.6), TIMBER)
		_set_registered_surface(frame, _coastal_surface(3, 2.72, TIMBER))
		for z in [-9.9, -4.9, 0.1, 5.1]:
			var anchor := Vector3(x, -0.06, z)
			_box(anchor + Vector3(0, 0.18, 0), Vector3(0.61, 0.34, 0.56), INK)
			_box(anchor + Vector3(0, 1.18, 0), Vector3(0.24, 2.04, 0.25), TIMBER)
			_emblem(anchor + Vector3(0, 2.19, 0), Vector3(0.36, 0.13, 0.32), BRASS)
			_box(anchor + Vector3(sign * 0.38, 0.86, -0.90), Vector3(0.26, 1.43, 1.64), Color("#556063"))
	for x in [-8.6, 8.6]:
		_box(Vector3(x, 0.0, 10.03), Vector3(9.70, 0.11, 0.21), TIMBER)
		_emblem(Vector3(x, 0.059, 10.05), Vector3(9.45, 0.052, 0.053), BRASS.darkened(0.28))
	_build_workshop_storage()
	var texture := load(WORKSHOP_ART) as Texture2D if ResourceLoader.exists(WORKSHOP_ART) else null
	if texture == null:
		return
	var panel := QuadMesh.new()
	panel.size = Vector2(42.0, 18.57)
	_backdrop = ShaderMaterial.new()
	_backdrop.shader = Backdrop
	_backdrop.set_shader_parameter("skyline_texture", texture)
	var wall := _mesh(panel, Vector3(2.5, 4.15, -12.8), _backdrop)
	wall.name = "ToyWorkshopMural"
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_workshop_storage() -> void:
	_storage_crate(Vector3(16.65, -0.48, 7.55), Vector3(2.04, 1.24, 1.46), STORAGE_BLUE)
	_storage_crate(Vector3(18.63, -0.48, 8.12), Vector3(1.26, 0.77, 1.10), STORAGE_WOOD)
	_storage_crate(Vector3(1.65, -0.48, 13.36), Vector3(3.42, 1.05, 1.64), STORAGE_WOOD)
	var wheel_at := Vector3(17.44, 1.08, -0.65)
	_box(Vector3(wheel_at.x, -0.24, wheel_at.z - 0.13), Vector3(3.5, 0.46, 1.28), STORAGE_BLUE)
	var wheel := _cylinder(wheel_at, 1.04, 0.26, STORAGE_WOOD)
	wheel.rotation.x = PI * 0.5
	var hub := _cylinder(wheel_at + Vector3(0, 0, 0.19), 0.35, 0.14, STORAGE_BLUE)
	hub.rotation.x = PI * 0.5
	var axle := _cylinder(wheel_at + Vector3(0, 0, 0.29), 0.13, 0.11, STORAGE_METAL)
	axle.rotation.x = PI * 0.5
	for index in 10:
		var angle := TAU * float(index) / 10.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tooth := _box(wheel_at + radial * 1.08, Vector3(0.30, 0.30, 0.25), STORAGE_WOOD)
		tooth.rotation.z = angle


func _storage_crate(foot: Vector3, size: Vector3, tint: Color) -> void:
	_box(foot + Vector3.UP * (size.y * 0.5), size, tint)
	_box(foot + Vector3.UP * (size.y + 0.025), Vector3(size.x + 0.09, 0.085, size.z + 0.09), STORAGE_BLUE)
	for side in [-1.0, 1.0]:
		var band := foot + Vector3(side * size.x * 0.37, size.y * 0.5, size.z * 0.5 + 0.015)
		_box(band, Vector3(0.10, size.y * 0.88, 0.032), STORAGE_METAL)


func _build_foyer() -> void:
	var runner := _box(Vector3(0, GROUND_Y + 0.024, 7.11), Vector3(5.5, 0.044, 4.4), Color("#627b69"))
	_set_registered_surface(runner, _coastal_surface(6, 6.70, Color("#6b8570")))
	for x in [-2.64, 2.64]:
		_emblem(Vector3(x, GROUND_Y + 0.055, 7.11), Vector3(0.06, 0.034, 4.2), BRASS)
	for x in [-3.60, 3.60]:
		_box(Vector3(x, GROUND_Y + 0.73, 8.84), Vector3(0.35, 1.44, 0.38), STATION_TEAL)
		_box(Vector3(x, GROUND_Y + 0.20, 8.84), Vector3(0.62, 0.40, 0.56), INK)
		_emblem(Vector3(x, GROUND_Y + 1.51, 8.84), Vector3(0.34, 0.17, 0.34), PARCHMENT)
	_plaque("發條玩具城", Vector3(2.08, GROUND_Y + 2.62, 8.64), 3.30, STATION_TEAL)


func _build_block_street() -> void:
	for index in 3:
		var at := Vector3(-10.52, GROUND_Y, -2.55 + float(index) * 2.61)
		_build_block_house(at, HOUSE_TONES[index], 1.70 + 0.20 * float(index % 2))
	for z in [0.65, 3.72, 5.42]:
		_box(Vector3(-5.52, GROUND_Y + 0.24, z), Vector3(0.30, 0.46, 0.30), STATION_TEAL)
		_emblem(Vector3(-5.52, GROUND_Y + 0.50, z), Vector3(0.31, 0.085, 0.31), BRASS)
	_plaque("積木街", Vector3(-8.02, GROUND_Y + 1.30, 0.66), 2.32, BRASS)


func _build_block_house(at: Vector3, tone: Color, height: float) -> void:
	var facade := _box(at + Vector3(0, height * 0.5, 0), Vector3(2.12, height, 1.60), tone, true)
	_set_registered_surface(facade, _coastal_surface(1, 2.3, tone))
	_box(at + Vector3(0, 0.14, 0), Vector3(2.24, 0.28, 1.70), INK)
	for side in [-1, 1]:
		var roof := _box(at + Vector3(float(side) * 0.57, height + 0.31, 0), Vector3(1.28, 0.14, 1.80), RED)
		roof.rotation.z = float(side) * -0.40
		_set_registered_surface(roof, _coastal_surface(3, 2.5, RED))
		_box(at + Vector3(float(side) * 0.64, height * 0.66, 0.843), Vector3(0.46, 0.64, 0.10), TIMBER)
		_emblem(at + Vector3(float(side) * 0.64, height * 0.66, 0.902), Vector3(0.31, 0.45, 0.038), PARCHMENT)
	_box(at + Vector3(0, height + 0.54, 0), Vector3(0.16, 0.13, 1.85), BRASS)
	_box(at + Vector3(0, 0.46, 0.841), Vector3(0.53, 0.91, 0.10), STATION_TEAL)


func _build_station() -> void:
	var at := STATION_ORIGIN
	var table := _box(at + Vector3(0, 0.265, 0), Vector3(5.36, 0.53, 4.52), TIMBER, true)
	table.name = "ToyRailPlatform"
	_set_registered_surface(table, _coastal_surface(1, 4.6, Color("#756c5d")))
	var top := _box(at + Vector3(0, 0.542, 0), Vector3(5.18, 0.046, 4.36), Color("#686d69"))
	_set_registered_surface(top, _coastal_surface(0, 3.2, Color("#666961")))
	for x in [-2.55, 2.55]:
		_box(at + Vector3(x, 0.64, 0), Vector3(0.16, 0.18, 4.47), STATION_TEAL)
		_emblem(at + Vector3(x, 0.74, 0), Vector3(0.085, 0.033, 4.42), BRASS)
	_box(at + Vector3(0, 0.64, -2.21), Vector3(5.14, 0.19, 0.16), STATION_TEAL)
	_box(at + Vector3(0, 0.60, 2.23), Vector3(5.14, 0.085, 0.12), STATION_TEAL)
	_train = TrainScript.new()
	_train.name = "ToyRailDemonstration"
	_train.position = at + Vector3(0, 0.563, 0)
	add_child(_train)
	_tracks = _train.map_tracks()
	for x in [-0.94, 0.94]:
		_box(at + Vector3(x, 0.65, -2.54), Vector3(0.11, 1.27, 0.13), TIMBER)
	_station_label = _plaque("", STATION_STATUS_AT, STATION_STATUS_WIDTH, BRASS)
	_station_label.position.z += 0.13
	_desk_control(Vector3(SWITCH.x, GROUND_Y, 1.50), RED)
	_desk_control(Vector3(TRAIN.x, GROUND_Y, 1.50), STATION_TEAL)
	_control_lever = _box(Vector3(SWITCH.x, GROUND_Y + 1.02, 1.50), Vector3(0.095, 0.46, 0.077), BRASS)
	_floor_brackets(SWITCH, RED)
	_floor_brackets(TRAIN, STATION_TEAL)


func _desk_control(at: Vector3, paint: Color) -> void:
	_box(at + Vector3(0, 0.40, 0), Vector3(0.92, 0.76, 0.58), INK)
	_box(at + Vector3(0, 0.83, 0), Vector3(1.07, 0.15, 0.70), paint)
	_emblem(at + Vector3(0, 0.889, 0.219), Vector3(0.21, 0.083, 0.15), PARCHMENT)


func _build_repair() -> void:
	var at := Vector3(-8.00, GROUND_Y, -8.80)
	for x in [-1.36, 1.36]:
		_box(at + Vector3(x, 0.42, 0), Vector3(0.25, 0.82, 1.02), TIMBER)
	var desk := _box(at + Vector3(0, 0.86, 0), Vector3(3.24, 0.18, 1.26), BRASS, true)
	_set_registered_surface(desk, _coastal_surface(1, 3.0, Color("#98795e")))
	_box(at + Vector3(0, 1.43, -0.51), Vector3(3.18, 1.16, 0.12), STATION_TEAL)
	var cog := _cylinder(at + Vector3(-0.92, 1.52, -0.419), 0.34, 0.075, BRASS)
	cog.rotation.x = PI * 0.5
	for index in 10:
		var angle := TAU * float(index) / 10.0
		var tooth_at := at + Vector3(-0.92 + cos(angle) * 0.34, 1.52 + sin(angle) * 0.34, -0.399)
		var tooth := _box(tooth_at, Vector3(0.13, 0.13, 0.068), BRASS)
		tooth.rotation.z = angle
	for x in [0.20, 0.58, 0.96]:
		_emblem(at + Vector3(x, 1.43, -0.41), Vector3(0.11, 0.58, 0.059), Color("#b7b2a0"))
	_plaque("維修台 · 重置", at + Vector3(0, 2.20, -0.43), 3.03, BRASS)
	_floor_brackets(REPAIR, BRASS)


func _build_clock_tower() -> void:
	var at := Vector3(0, GROUND_Y, -9.90)
	var body := _box(at + Vector3(0, 1.67, 0), Vector3(2.55, 3.34, 1.80), STATION_TEAL, true)
	_set_registered_surface(body, _coastal_surface(1, 3.36, STATION_TEAL))
	for x in [-1.18, 1.18]:
		_box(at + Vector3(x, 1.69, 0.956), Vector3(0.135, 3.21, 0.16), BRASS)
	_box(at + Vector3(0, 0.19, 0), Vector3(2.75, 0.38, 1.94), INK)
	_box(at + Vector3(0, 3.37, 0), Vector3(2.94, 0.24, 2.02), TIMBER)
	_box(at + Vector3(0, 3.62, 0), Vector3(2.3, 0.28, 1.70), RED)
	_box(at + Vector3(0, 3.84, 0), Vector3(1.78, 0.24, 1.33), RED)
	_cylinder(at + Vector3(0, 4.09, 0), 0.19, 0.31, BRASS)
	var face_at := at + Vector3(0, 2.45, 0.98)
	var rim := _cylinder(face_at, 0.94, 0.15, BRASS)
	rim.rotation.x = PI * 0.5
	var face := _cylinder(face_at + Vector3(0, 0, 0.08), 0.81, 0.09, PARCHMENT)
	face.rotation.x = PI * 0.5
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var marker := _box(face_at + Vector3(cos(angle) * 0.69, sin(angle) * 0.69, 0.138), Vector3(0.16, 0.044, 0.035), INK)
		marker.rotation.z = angle
	_clock_hour = _clock_hand(face_at + Vector3(0, 0, 0.162), 0.41, 0.072, INK)
	_clock_minute = _clock_hand(face_at + Vector3(0, 0, 0.183), 0.59, 0.047, RED)
	_plaque("發條鐘樓", at + Vector3(0, 1.09, 1.02), 2.48, BRASS)


func _clock_hand(at: Vector3, length: float, width: float, tint: Color) -> Node3D:
	var hand := Node3D.new()
	hand.position = at
	add_child(hand)
	var box := BoxMesh.new()
	box.size = Vector3(width, length, 0.030)
	var pointer := MeshInstance3D.new()
	pointer.mesh = box
	pointer.position = Vector3(0, length * 0.50, 0)
	pointer.material_override = _mat(tint)
	pointer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(pointer)
	return hand


func _build_lighting_pools() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for spec in POOL_SPECS:
		var pool := OmniLight3D.new()
		pool.position = spec.position
		pool.light_color = spec.color
		pool.omni_range = spec.range
		pool.omni_attenuation = 1.51
		pool.light_specular = 0.13
		pool.shadow_enabled = false
		add_child(pool)
		_pools.append(pool)


func _box(at: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	if solid:
		return super._box(at, size, color, true)
	var mesh := _mesh_cache.get(size) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_mesh_cache[size] = mesh
	return _mesh(mesh, at, _mat(color))


func _emblem(at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var piece := _box(at, size, tint)
	var paint := _paints.get(tint) as StandardMaterial3D
	if paint == null:
		paint = StandardMaterial3D.new()
		paint.albedo_color = tint
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_paints[tint] = paint
	piece.material_override = paint
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


func _plaque(title: String, at: Vector3, width: float, edge: Color) -> Label3D:
	_box(at, Vector3(width, 0.43, 0.14), INK)
	_emblem(at + Vector3(0, -0.198, 0.086), Vector3(width, 0.050, 0.045), edge)
	var label := _local_label(title, at + Vector3(0, 0.014, 0.115), 28, PARCHMENT)
	label.pixel_size = 0.0131
	return label


func _floor_brackets(at: Vector3, tint: Color) -> void:
	for x in [-0.29, 0.29]:
		_emblem(at + Vector3(x, 0.014, 0), Vector3(0.060, 0.024, 0.71), tint)
	for z in [-0.33, 0.33]:
		_emblem(at + Vector3(0, 0.014, z), Vector3(0.55, 0.024, 0.060), tint)


func _build_region_activities() -> void:
	pass


func _register_npc_activity() -> void:
	var actor := _npc_record_for_role("announcer")
	_story_host_sprite = actor.get("sprite") as Sprite3D
	_story_host_name = actor.get("name_label") as Label3D
	if _story_host_sprite == null or avatar_renderer == null:
		return
	_story_host_rest = _story_host_sprite.texture
	var library: RefCounted = avatar_renderer.animation_library
	var greeting := library.texture("announcer", "greet", "front", 4) as Texture2D
	_story_host_greeting = _fit_npc_rest_texture(greeting) if greeting != null else _story_host_rest


func begin_story_photo() -> bool:
	if is_instance_valid(_story_photo_camera) or not is_instance_valid(player) or not is_instance_valid(_story_host_sprite) or avatar_renderer == null:
		return false
	var pose := avatar_renderer.texture(avatar_appearance, avatar_equipped, "front", 0, "photograph") as Texture2D
	if pose == null:
		return false
	var center := Vector3(8.0, 1.035, 1.92)
	_story_photo_camera = Camera3D.new()
	_story_photo_camera.name = "ToyStationPhotoCamera"
	_story_photo_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_story_photo_camera.size = 7.40
	_story_photo_camera.far = camera.far
	_story_photo_camera.position = center + Vector3(0.36, 4.40, 9.90)
	add_child(_story_photo_camera)
	_story_photo_camera.look_at(center)
	_stage_story_people(pose)
	_set_interaction_marker(null)
	_story_photo_camera.make_current()
	return true


func _stage_story_people(pose: Texture2D) -> void:
	var camera_up := _story_photo_camera.global_basis.y.y
	var guest := Sprite3D.new()
	guest.name = "ToyStoryGuest"
	guest.texture = pose
	guest.pixel_size = avatar.pixel_size
	guest.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guest.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	guest.shaded = true
	guest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guest.top_level = true
	_story_photo_camera.add_child(guest)
	guest.global_position = STORY_GUEST + Vector3.UP * sprite_ground_anchor_y(STORY_GUEST.y, STORY_GUEST.y,
		0.0, AvatarRenderer.FEET_BASELINE, AvatarRenderer.CANVAS_SIZE.y, guest.pixel_size, camera_up)
	_set_living_sprite_material(guest, 1, 0.0, 0.0, 0, false)
	if is_instance_valid(avatar_contact_shadow):
		var contact := avatar_contact_shadow.duplicate(0) as MeshInstance3D
		contact.top_level = true
		_story_photo_camera.add_child(contact)
		contact.global_transform = Transform3D(avatar_contact_shadow.global_basis, STORY_GUEST + Vector3.UP * 0.008)

	var host_anchor := _story_host_sprite.get_parent() as Node3D
	_story_host_anchor_y = host_anchor.position.y
	host_anchor.position.y = sprite_ground_anchor_y(STORY_HOST.y, STORY_HOST.y, _story_host_sprite.position.y,
		NpcActivityScript.ACTION_FEET_ROW, NpcActivityScript.ACTION_CANVAS_SIZE.y, _story_host_sprite.pixel_size, camera_up)
	_set_story_host_pose(_story_host_greeting)
	_story_player_visible = player.visible
	player.hide()
	for label in local_sign_labels:
		if label != _station_label:
			_hide_story_label(label)
	_story_station_status_visible = _station_label.visible
	_station_label.show()
	_hide_story_label(_story_host_name)


func _hide_story_label(label: Label3D) -> void:
	if is_instance_valid(label) and label.visible:
		_story_hidden_labels.append(label)
		label.hide()


func end_story_photo() -> void:
	if not is_instance_valid(_story_photo_camera):
		return
	camera.make_current()
	_story_photo_camera.hide()
	_story_photo_camera.queue_free()
	_story_photo_camera = null
	player.visible = _story_player_visible
	_station_label.visible = _story_station_status_visible
	_set_story_host_pose(_story_host_rest)
	(_story_host_sprite.get_parent() as Node3D).position.y = _story_host_anchor_y
	for label in _story_hidden_labels:
		if is_instance_valid(label):
			label.show()
	_story_hidden_labels.clear()


func _set_story_host_pose(texture: Texture2D) -> void:
	if texture == null or not is_instance_valid(_story_host_sprite):
		return
	_story_host_sprite.texture = texture
	var material := _story_host_sprite.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("texture_albedo", texture)
		material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))


func _physics_process(delta: float) -> void:
	# Keep the live player's position, pose, follow camera and nearby target intact.
	if not is_instance_valid(_story_photo_camera):
		super._physics_process(delta)


func _build_player_floor() -> void:
	pass


func update_collection(_photos: Dictionary) -> void:
	pass


func _player_spawn_position() -> Vector3:
	return ENTRY


func _area_at_position(position: Vector3) -> String:
	var floor := Vector2(position.x, position.z)
	for area in AREAS:
		if area.rect.has_point(floor):
			return area.label
	return "玩具城入口"


func _on_yard(point: Vector2) -> bool:
	for area in AREAS:
		if area.rect.has_point(point):
			return true
	return false


func ground_surface_y(position: Vector3) -> float:
	return GROUND_Y if _on_yard(Vector2(position.x, position.z)) else -0.40


func _safe_footing(position: Vector3) -> bool:
	var at := Vector2(position.x, position.z)
	return (_on_yard(at + Vector2(-0.30, -0.30))
		and _on_yard(at + Vector2(0.30, -0.30))
		and _on_yard(at + Vector2(-0.30, 0.30))
		and _on_yard(at + Vector2(0.30, 0.30)))


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


func switch_tracks() -> String:
	if not _train.select_next_branch():
		return "列車回站後再切換岔道"
	_sync_station_controls()
	return "已切換" + _train.branch_label()


func operate_train() -> String:
	var feedback := _train.operate()
	_sync_station_controls()
	return feedback


func reset_train() -> String:
	_train.reset()
	_sync_station_controls()
	return "列車已回站，恢復左線"


func train_state() -> Dictionary:
	return _train.snapshot()


func tower_clock() -> String:
	return TimeOfDayScript.phase_for_id(active_time_phase).clock


func _sync_station_controls() -> void:
	_control_lever.rotation.z = -0.44 if _train.branch == 0 else 0.44
	var status: String
	if _train.reduced_motion:
		status = "逐站"
	elif _train.running:
		status = "行駛"
	else:
		status = "候車" if _train.at_dock() else "暫停"
	_station_label.text = "%s · %s" % [_train.branch_label(), status]


func _process(delta: float) -> void:
	super._process(delta)
	if not blocked and not is_instance_valid(_story_photo_camera) and _train.advance(delta):
		_sync_station_controls()


func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	if is_instance_valid(_train):
		_train.set_reduced_motion(reduced_motion)
		_sync_station_controls()


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	var evening := active_time_phase in ["dusk", "night"]
	var haze := Color("#302a36") if evening else Color("#4c4140")
	environment.background_color = haze
	environment.fog_light_color = haze
	environment.ambient_light_color = Color("#afbbc9") if evening else Color("#f2dcc0")
	environment.ambient_light_energy = 0.77 if evening else 0.83
	sun.light_color = Color("#e1d8d2") if evening else Color("#ffddad")
	sun.light_energy = 0.41 if evening else 0.64
	for pool in _pools:
		pool.light_energy = 0.95 if evening else 0.58
	if _apron != null:
		_apron.set_shader_parameter("near_tone", Color("#3f484c") if evening else Color("#535955"))
		_apron.set_shader_parameter("far_tone", Color("#283239") if evening else Color("#383f44"))
	if _backdrop != null:
		_backdrop.set_shader_parameter("haze", haze)
	if is_instance_valid(_clock_hour):
		var parts := tower_clock().split(":")
		var hour := float(parts[0].to_int()) + float(parts[1].to_int()) / 60.0
		_clock_hour.rotation.z = -TAU * fposmod(hour, 12.0) / 12.0
		_clock_minute.rotation.z = -TAU * fposmod(hour, 1.0)


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
	return {"bounds": BOUNDS, "land": land, "areas": areas, "points": stops, "player": at, "area": _area_at_position(at),
		"region": "toy", "tracks": _tracks.duplicate(true), "rail_table": RAIL_TABLE, "train": train_state()}
