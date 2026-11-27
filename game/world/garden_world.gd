extends "res://game/world/park_world.gd"

const Louvers = preload("res://game/world/garden_louvers.gd")
const Glass = preload("res://game/world/garden_glass.gdshader")
const Water = preload("res://game/world/garden_water.gdshader")
const Paving = preload("res://game/world/garden_paving.gdshader")
const RegionalVisit = preload("res://game/story/regional_visit.gd")
const CANOPY_ART := "res://assets/world/garden-canopy-foliage.webp"
const GROUND_Y := 0.20
const LOWER_Y := 0.86
const UPPER_Y := 1.12
const ENTRY := Vector3(0, GROUND_Y, 7.8)
const SWITCH := Vector3(0, GROUND_Y, 3.45)
const STORY_POINT := Vector3(2.80, GROUND_Y, 5.56)
const STORY_HOST := Vector3(2.82, GROUND_Y, 4.78)
const STORY_PORTRAIT_HOST := STORY_HOST + Vector3(0.40, 0, 0)
const STORY_GUEST := Vector3(-2.05, GROUND_Y, 4.78)
const WETLAND := Vector3(-7.2, GROUND_Y, 0.05)
const VINE := Vector3(7.13, UPPER_Y, -6.15)
const BUDS := Vector3(0, GROUND_Y, -9.55)
const BOUNDS := Rect2(-12.0, -11.7, 24.0, 21.05)
const SUN_FLOOR := Rect2(-4.2, -7.85, 8.4, 17.2)
const WETLAND_ROOM := Rect2(-12.0, -7.85, 7.8, 17.2)
const VINE_FLOOR := Rect2(4.2, -7.85, 7.8, 17.2)
const BUD_COURT := Rect2(-12.0, -11.7, 24.0, 3.85)
const WETLAND_WATER := Rect2(-12.0, -4.55, 7.8, 8.15)
const WEST_SOUTH := Rect2(-12.0, 3.60, 7.8, 5.75)
const WEST_NORTH := Rect2(-12.0, -7.85, 7.8, 3.30)
const BOARDWALK := Rect2(-8.60, -4.75, 2.80, 8.58)
const RAMP := Rect2(5.15, -1.80, 4.10, 5.80)
const LOWER := Rect2(5.15, -4.10, 4.10, 2.30)
const LINK := Rect2(5.15, -4.90, 4.10, 0.80)
const UPPER := Rect2(5.15, -7.85, 4.10, 2.95)
const LAND: Array[Rect2] = [SUN_FLOOR, VINE_FLOOR, BUD_COURT, WEST_SOUTH, WEST_NORTH, BOARDWALK]
const AREAS: Array[Dictionary] = [
	{"id": "sun", "label": "日照窗", "rect": SUN_FLOOR},
	{"id": "wetland", "label": "濕地床", "rect": WETLAND_ROOM},
	{"id": "vine", "label": "藤蔓層", "rect": VINE_FLOOR},
	{"id": "buds", "label": "夜芽庭", "rect": BUD_COURT},
]
const IRON := Color("#38534e")
const DEEP_IRON := Color("#263c38")
const BRASS := Color("#ab945e")
const GARDEN_STONE := Color("#92a18c")
const IVORY := Color("#c1ad88")
const TIMBER := Color("#938064")
const FERN := Color("#638478")
enum Finish { STONE, PLANKS, GROUND }
const FOOTPRINT: Array[Vector2] = [Vector2(-0.30, -0.30), Vector2(-0.30, 0.30), Vector2(0.30, -0.30), Vector2(0.30, 0.30)]

var _louvers: Louvers
var _water: ShaderMaterial
var _glazing: ShaderMaterial
var _buds: StandardMaterial3D
var _bud_pool: OmniLight3D
var _last_safe := ENTRY
var _recoveries := 0
var _foyer_sign: Array[MeshInstance3D] = []
var _story_camera: Camera3D
var _story_host_root: Node3D
var _story_host_sprite: Sprite3D
var _story_host_label: Label3D
var _story_host_still: Texture2D
var _story_host_greeting: Texture2D
var _story_host_anchor_y := 0.0
var _story_host_rest_at := Vector3.ZERO
var _story_player_was_visible := true
var _story_hidden_features: Array[Node3D] = []


func _build_region_geometry() -> void:
	_build_foundation()
	_build_exterior()
	_build_glasshouse()
	_build_wetland()
	_build_terraces()
	_build_bud_court()
	_louvers = Louvers.new()
	_louvers.name = "GardenSunRack"
	add_child(_louvers)
	_coordinate_lighting()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("garden:louvers", "日照窗 · 轉動百葉", SWITCH)
	_point("garden:wetland", "濕地床 · 靠木棧道走", WETLAND)
	_point("garden:vine", "藤蔓層 · 看葉臺", VINE)
	_point("garden:buds", "夜芽庭 · 看夜芽", BUDS)
	_npc(STORY_HOST, IRON, RegionalVisit.host_name(RegionalVisit.GARDEN))
	_point(RegionalVisit.GARDEN_POINT, "溫室迎賓 · 和票票合照", STORY_POINT)
	current_area = _area_at_position(ENTRY)


func _build_foundation() -> void:
	var base := _box(Vector3(0, -0.46, -1.16), Vector3(25.05, 0.44, 22.30), DEEP_IRON)
	_set_registered_surface(base, _paving(Color("#778477")))
	_floor(SUN_FLOOR, GROUND_Y, 0.31, IVORY, "GardenSunFloor")
	_floor(VINE_FLOOR, GROUND_Y, 0.31, FERN, "GardenVineFloor")
	_floor(BUD_COURT, GROUND_Y, 0.31, Color("#84938a"), "GardenBudFloor")
	_floor(WEST_SOUTH, GROUND_Y, 0.31, GARDEN_STONE, "GardenSouthBridge")
	_floor(WEST_NORTH, GROUND_Y, 0.31, GARDEN_STONE, "GardenNorthBridge")
	_floor(BOARDWALK, GROUND_Y, 0.25, TIMBER, "GardenWetlandBoardwalk", Finish.PLANKS)
	for x in [-3.93, 3.93]:
		_box(Vector3(x, GROUND_Y + 0.012, 1.18), Vector3(0.079, 0.025, 15.2), BRASS)
	for side in [-1.0, 1.0]:
		var x: float = side * 2.73
		_box(Vector3(x, GROUND_Y + 0.44, 8.78), Vector3(0.34, 0.87, 0.34), IRON)
		_box(Vector3(x, GROUND_Y + 0.91, 8.78), Vector3(0.46, 0.10, 0.43), BRASS)
	_foyer_sign = _sign("苔光溫室", Vector3(-2.04, 1.48, 8.74), 1.83)
	_brackets(ENTRY, BRASS)
	_brackets(SWITCH, Color("#8b9864"))


func _build_exterior() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(92.0, 84.0)
	var apron := _mesh(ground, Vector3(0, -0.67, -1.16), _paving(Color("#76856c"), Finish.GROUND))
	apron.name = "GardenContinuousApron"
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bed := SphereMesh.new()
	bed.radial_segments = 14
	bed.rings = 4
	var art := load(CANOPY_ART) as Texture2D if ResourceLoader.exists(CANOPY_ART) else null
	var has_canopy := art != null and art.get_width() == art.get_height() * 2
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 9.87, -0.64, 11.31 - 0.36 * side)
		var berm := _mesh(bed, at, _mat(Color("#68775c")))
		berm.scale = Vector3(7.1, 0.27, 2.52)
		berm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var outer: Array[Vector3] = []
		var fronds: Array[Vector3] = []
		for index in range(6):
			var spread := (float(index) - 2.50) * 0.84
			var tuft := at + Vector3(spread, 0.19 + 0.10 * float(index % 3), 0.42 * sin(index * 1.4))
			outer.append(tuft)
			if not has_canopy and index % 2 == 0:
				fronds.append(tuft + Vector3(side * -0.23, 0.53, -0.28))
		_leaf_cluster("GardenApronGroundcover", outer, Color("#778a61"), Vector3(1.20, 0.17, 0.83))
		if has_canopy:
			_canopy_silhouette(art, at, side)
		else:
			_leaf_cluster("GardenApronFronds", fronds, Color("#64846d"), Vector3(0.96, 0.82, 0.60))


func _canopy_silhouette(art: Texture2D, at: Vector3, side: float) -> void:
	var pixels := art.get_height()
	var tile := AtlasTexture.new()
	tile.atlas = art
	tile.region = Rect2(0 if side < 0.0 else pixels, 0, pixels, pixels)
	tile.filter_clip = true
	var canopy := Sprite3D.new()
	canopy.name = "GardenCanopyWest" if side < 0.0 else "GardenCanopyEast"
	canopy.texture = tile
	canopy.pixel_size = 2.94 / float(pixels)
	canopy.position = at + Vector3(side * 1.04, 1.56, 0.08)
	canopy.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	canopy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	canopy.shaded = true
	canopy.modulate = Color(0.88, 0.91, 0.84)
	canopy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	canopy.alpha_scissor_threshold = 0.61
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canopy)


func _build_glasshouse() -> void:
	_glazing = ShaderMaterial.new()
	_glazing.shader = Glass
	var pane := QuadMesh.new()
	pane.size = Vector2(3.74, 2.52)
	for bay in range(6):
		var x := -10.0 + float(bay) * 4.0
		var glass := _mesh(pane, Vector3(x, 1.87, -11.62), _glazing)
		glass.name = "GardenGlazedPane_%d" % bay
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(x, 0.32, -11.63), Vector3(3.91, 0.64, 0.27), IRON)
		_box(Vector3(x, 2.35, -11.48), Vector3(3.92, 0.081, 0.10), IRON)
	for column in range(7):
		_box(Vector3(-12.0 + float(column) * 4.0, 1.80, -11.56), Vector3(0.18, 3.44, 0.27), DEEP_IRON)
	_box(Vector3(0, 3.19, -11.54), Vector3(24.22, 0.17, 0.25), DEEP_IRON)
	_box(Vector3(0, 3.29, -11.51), Vector3(24.12, 0.06, 0.19), BRASS)
	for z in [-10.95, -6.0, -0.88, 4.12]:
		for side in [-1.0, 1.0]:
			var x: float = side * 11.80
			_box(Vector3(x, 0.29, z), Vector3(0.50, 0.57, 0.53), IRON)
			_box(Vector3(x, 1.71, z), Vector3(0.17, 2.48, 0.21), DEEP_IRON)
			_box(Vector3(x, 2.96, z), Vector3(0.30, 0.16, 0.28), BRASS)
			var brace := _box(Vector3(side * 11.38, 3.20, z), Vector3(1.0, 0.11, 0.17), IRON)
			brace.rotation.z = side * -0.41
			if z < -5.0:
				var roof_rib := _box(Vector3(side * 6.00, 4.01, z), Vector3(12.1, 0.10, 0.14), IRON)
				roof_rib.rotation.z = side * -0.142
	for x in [-11.8, 11.8]:
		_box(Vector3(x, 3.0, -3.45), Vector3(0.18, 0.10, 15.05), IRON)


func _build_wetland() -> void:
	var plane := PlaneMesh.new()
	plane.size = WETLAND_WATER.size
	_water = ShaderMaterial.new()
	_water.shader = Water
	var hit := WETLAND_WATER.get_center()
	var surface := _mesh(plane, Vector3(hit.x, -0.18, hit.y), _water)
	surface.name = "GardenWetlandWater"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-8.58, -5.82]:
		_box(Vector3(x, 0.229, -0.46), Vector3(0.083, 0.065, 8.40), BRASS)
		for z in [-4.39, -2.31, -0.23, 1.85, 3.46]:
			_box(Vector3(x, 0.25, z), Vector3(0.17, 0.12, 0.20), IRON)
	for z in [-4.44, 3.49]:
		_box(Vector3(-8.1, 0.246, z), Vector3(7.7, 0.085, 0.115), IRON)
	var pads: Array[Vector3] = []
	for x in [-10.88, -9.56, -4.99]:
		for index in range(5):
			pads.append(Vector3(x + 0.18 * sin(index * 1.9 + x), -0.14, -3.79 + float(index) * 1.55 + 0.17 * cos(x + index)))
	_leaf_cluster("GardenLilyPads", pads, Color("#6eaa7c"), Vector3(0.45, 0.06, 0.35))
	_brackets(WETLAND, BRASS)
	_sign("濕地床", Vector3(-10.31, 0.82, 4.16), 1.50)


func _build_terraces() -> void:
	_slope(RAMP, GROUND_Y, LOWER_Y, "GardenLeafRamp")
	_floor(LOWER, LOWER_Y, 0.40, Color("#9a906e"), "GardenLowerLeafDeck", Finish.PLANKS)
	_slope(LINK, LOWER_Y, UPPER_Y, "GardenUpperLink")
	_floor(UPPER, UPPER_Y, 0.44, Color("#afa180"), "GardenUpperLeafDeck", Finish.PLANKS)
	for rect in [LOWER, UPPER]:
		var height := LOWER_Y if rect == LOWER else UPPER_Y
		var center: Vector2 = rect.get_center()
		for x in [rect.position.x + 0.07, rect.end.x - 0.07]:
			_box(Vector3(x, height + 0.023, center.y), Vector3(0.10, 0.088, rect.size.y), BRASS)
		for offset in [-0.90, 0.90]:
			_box(Vector3(center.x + offset, height - 0.33, center.y), Vector3(0.26, 0.64, rect.size.y * 0.62), DEEP_IRON)
	_box(Vector3(7.20, UPPER_Y + 0.029, UPPER.position.y + 0.06), Vector3(4.09, 0.098, 0.12), BRASS)
	var vines: Array[Vector3] = []
	for z in [3.16, 1.55, -0.43, -2.53, -3.72, -5.53, -6.89]:
		for side in [5.03, 9.35]:
			var at := Vector3(side, 0.49, z)
			_box(at - Vector3.UP * 0.16, Vector3(0.49, 0.30, 0.62), IRON)
			vines.append(at)
	_leaf_cluster("GardenTrellisFoliage", vines, Color("#739063"), Vector3(0.41, 0.17, 0.37))
	_brackets(VINE, Color("#e2c789"))
	_sign("藤蔓層", Vector3(9.93, 1.19, -5.16), 1.42)


func _build_bud_court() -> void:
	_buds = _mat(Color("#b7c5a9")).duplicate() as StandardMaterial3D
	_buds.emission_enabled = true
	_buds.emission = Color("#bce4b5")
	var bloom := SphereMesh.new()
	bloom.radial_segments = 12
	bloom.rings = 5
	var stems: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var border: float = side * 4.55
		_box(Vector3(border, 0.356, -10.83), Vector3(5.35, 0.32, 1.25), IRON)
		_box(Vector3(border, 0.523, -10.83), Vector3(5.16, 0.049, 1.08), Color("#526957"))
		for index in range(6):
			var at := Vector3(border + (float(index) - 2.50) * 0.69, 0.64, -10.77 + float(index % 2) * 0.18)
			var bud := _mesh(bloom, at + Vector3.UP * (0.13 + float(index % 3) * 0.11), _buds)
			bud.scale = Vector3(0.34, 0.38, 0.34)
			bud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stems.append(at)
	_leaf_cluster("GardenBudLeaves", stems, Color("#688c70"), Vector3(0.41, 0.11, 0.28))
	_brackets(BUDS, Color("#bfc794"))
	_sign("夜芽庭", Vector3(0, 1.13, -10.74), 1.57)
	_bud_pool = OmniLight3D.new()
	_bud_pool.name = "GardenBudPool"
	_bud_pool.position = Vector3(0.26, 2.04, -10.53)
	_bud_pool.light_color = Color("#bedfab")
	_bud_pool.omni_range = 5.25
	_bud_pool.shadow_enabled = false
	add_child(_bud_pool)


func _leaf_cluster(label: String, origins: Array[Vector3], tone: Color, leaflet: Vector3) -> void:
	var geometry := SphereMesh.new()
	geometry.radial_segments = 8
	geometry.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = tone
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.79
	var transforms: Array[Transform3D] = []
	var shades: Array[Color] = []
	for index in origins.size():
		for side in range(3):
			var yaw := float(side) * TAU / 3.0 + float(index) * 1.33
			var shape := Basis.from_euler(Vector3(-0.15 - float(side) * 0.09, yaw, 0.18)).scaled(leaflet)
			var tip := Vector3(sin(yaw) * leaflet.x * 0.27, float(side) * leaflet.y * 0.24, cos(yaw) * leaflet.z * 0.27)
			transforms.append(Transform3D(shape, origins[index] + tip))
			shades.append(Color.WHITE.darkened(0.08 + float((index + side) % 4) * 0.07))
	var leaves := _multi_mesh(geometry, Vector3.ZERO, transforms, shades, material)
	leaves.name = label
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _floor(rect: Rect2, top: float, depth: float, tint: Color, label: String, finish: Finish = Finish.STONE) -> void:
	var center := rect.get_center()
	var floor_mesh := _box(Vector3(center.x, top - depth * 0.5, center.y), Vector3(rect.size.x, depth, rect.size.y), tint, true)
	floor_mesh.name = label
	_set_registered_surface(floor_mesh, _paving(tint, finish))


func _slope(rect: Rect2, bottom: float, top: float, label: String) -> void:
	var rise := top - bottom
	var rotation := Basis(Vector3.RIGHT, atan2(rise, rect.size.y))
	var center := rect.get_center()
	var surface := Vector3(center.x, (bottom + top) * 0.5, center.y)
	var thickness := 0.30
	var slope := _box(surface - rotation.y * thickness * 0.5,
		Vector3(rect.size.x, thickness, Vector2(rise, rect.size.y).length()), FERN, true)
	slope.name = label
	slope.basis = rotation
	_set_registered_surface(slope, _paving(Color("#a39777"), Finish.PLANKS))


func _paving(tint: Color, finish: Finish = Finish.STONE) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = Paving
	surface.set_shader_parameter("finish_tone", tint)
	surface.set_shader_parameter("finish_style", finish)
	if finish == Finish.PLANKS:
		surface.set_shader_parameter("tile_size", Vector2(1.92, 0.31))
	return surface


func _box(at: Vector3, size: Vector3, tint: Color, solid := false) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = size
	var instance := _mesh(geometry, at, _finish(tint, size))
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _sign(title: String, at: Vector3, width: float) -> Array[MeshInstance3D]:
	var plaque := _box(at, Vector3(width, 0.32, 0.075), DEEP_IRON)
	var trim := _box(at + Vector3(0, -0.145, 0.047), Vector3(width - 0.09, 0.028, 0.027), BRASS)
	var label := _local_label(title, at + Vector3(0, 0.015, 0.048), 22, Color("#f5e9b8"))
	label.outline_size = 1
	return [plaque, trim]


func _brackets(at: Vector3, tint: Color) -> void:
	for side in [-1.0, 1.0]:
		_box(at + Vector3(0.42 * side, 0.025, 0), Vector3(0.071, 0.041, 0.56), tint)


func _build_player_floor() -> void:
	pass


func _build_region_activities() -> void:
	pass


func _register_npc_activity() -> void:
	var actor := _npc_record_for_role("ticket")
	_story_host_root = actor.get("activity_root") as Node3D
	_story_host_sprite = actor.get("sprite") as Sprite3D
	_story_host_label = actor.get("name_label") as Label3D
	if not is_instance_valid(_story_host_sprite) or avatar_renderer == null:
		return
	_story_host_still = _story_host_sprite.texture
	var library: RefCounted = avatar_renderer.animation_library
	var greeting := library.texture("ticket", "greet", "front", 4) as Texture2D
	_story_host_greeting = _fit_npc_rest_texture(greeting) if greeting != null else _story_host_still


func begin_story_photo() -> bool:
	if is_instance_valid(_story_camera) or not is_instance_valid(player) or not is_instance_valid(_story_host_root) \
		or not is_instance_valid(_story_host_sprite) or avatar_renderer == null:
		return false
	var pose := avatar_renderer.texture(avatar_appearance, avatar_equipped, "front", 0, "photograph") as Texture2D
	if pose == null:
		return false
	var center := Vector3(0.18, 1.38, 3.40)
	_story_camera = Camera3D.new()
	_story_camera.name = "GardenVisitPhotoCamera"
	_story_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_story_camera.size = 8.12
	_story_camera.far = camera.far
	_story_camera.position = center + Vector3(-0.70, 3.70, 9.40)
	add_child(_story_camera)
	_story_camera.look_at(center)
	_mount_story_guest(pose)
	_story_host_rest_at = _story_host_root.position
	_story_host_root.position = STORY_PORTRAIT_HOST
	var anchor := _story_host_sprite.get_parent() as Node3D
	_story_host_anchor_y = anchor.position.y
	anchor.position.y = sprite_ground_anchor_y(STORY_HOST.y, STORY_HOST.y, _story_host_sprite.position.y,
		NpcActivityScript.ACTION_FEET_ROW, NpcActivityScript.ACTION_CANVAS_SIZE.y, _story_host_sprite.pixel_size, _story_camera.global_basis.y.y)
	_set_story_host_texture(_story_host_greeting)
	_story_player_was_visible = player.visible
	player.hide()
	for label in local_sign_labels:
		_hide_story_feature(label)
	for piece in _foyer_sign:
		_hide_story_feature(piece)
	_hide_story_feature(_story_host_label)
	_set_interaction_marker(null)
	_story_camera.make_current()
	return true


func _mount_story_guest(pose: Texture2D) -> void:
	# The portrait renders its own still actor, leaving the live pose and ground contact intact.
	var guest := Sprite3D.new()
	guest.name = "GardenStoryGuest"
	guest.texture = pose
	guest.pixel_size = avatar.pixel_size
	guest.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guest.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	guest.shaded = true
	guest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guest.top_level = true
	_story_camera.add_child(guest)
	guest.global_position = STORY_GUEST + Vector3.UP * sprite_ground_anchor_y(STORY_GUEST.y, STORY_GUEST.y,
		0.0, AvatarRenderer.FEET_BASELINE, AvatarRenderer.CANVAS_SIZE.y, guest.pixel_size, _story_camera.global_basis.y.y)
	_set_living_sprite_material(guest, 1, 0.0, 0.0, 0, false)
	if is_instance_valid(avatar_contact_shadow):
		var contact := avatar_contact_shadow.duplicate(0) as MeshInstance3D
		contact.top_level = true
		_story_camera.add_child(contact)
		contact.global_transform = Transform3D(avatar_contact_shadow.global_basis, STORY_GUEST + Vector3.UP * 0.008)


func _hide_story_feature(feature: Node3D) -> void:
	if is_instance_valid(feature) and feature.visible:
		_story_hidden_features.append(feature)
		feature.hide()


func _set_story_host_texture(texture: Texture2D) -> void:
	if texture == null or not is_instance_valid(_story_host_sprite):
		return
	_story_host_sprite.texture = texture
	var material := _story_host_sprite.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("texture_albedo", texture)
		material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))


func end_story_photo() -> void:
	if not is_instance_valid(_story_camera):
		return
	camera.make_current()
	_story_camera.hide()
	_story_camera.queue_free()
	_story_camera = null
	player.visible = _story_player_was_visible
	_set_story_host_texture(_story_host_still)
	if is_instance_valid(_story_host_root):
		_story_host_root.position = _story_host_rest_at
	if is_instance_valid(_story_host_sprite):
		(_story_host_sprite.get_parent() as Node3D).position.y = _story_host_anchor_y
	for feature in _story_hidden_features:
		if is_instance_valid(feature):
			feature.show()
	_story_hidden_features.clear()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_story_camera):
		super._physics_process(delta)


func update_collection(_photos: Dictionary) -> void:
	pass


func _player_spawn_position() -> Vector3:
	return ENTRY


func _area_at_position(position: Vector3) -> String:
	var at := Vector2(position.x, position.z)
	for area in AREAS:
		if area.rect.has_point(at):
			return area.label
	return "日照窗"


func _on_floor_plan(point: Vector2) -> bool:
	for rect in LAND:
		if rect.has_point(point):
			return true
	return false


func _height_at(at: Vector2) -> float:
	if RAMP.has_point(at):
		return lerpf(LOWER_Y, GROUND_Y, inverse_lerp(RAMP.position.y, RAMP.end.y, at.y))
	if LOWER.has_point(at):
		return LOWER_Y
	if LINK.has_point(at):
		return lerpf(UPPER_Y, LOWER_Y, inverse_lerp(LINK.position.y, LINK.end.y, at.y))
	if UPPER.has_point(at):
		return UPPER_Y
	return GROUND_Y if _on_floor_plan(at) else -0.18


func ground_surface_y(position: Vector3) -> float:
	return _height_at(Vector2(position.x, position.z))


func _safe_standing(position: Vector3) -> bool:
	if not position.is_finite() or position.y < ground_surface_y(position) - 0.28:
		return false
	var at := Vector2(position.x, position.z)
	for offset in FOOTPRINT:
		if not _on_floor_plan(at + offset):
			return false
	return true


func _can_record_footing(position: Vector3, surface: float) -> bool:
	if not player.is_on_floor() or absf(position.y - surface) > 0.12:
		return false
	var at := Vector2(position.x, position.z)
	for offset in FOOTPRINT:
		if absf(_height_at(at + offset) - surface) > 0.19:
			return false
	return true


func _constrain_player(previous_position: Vector3) -> bool:
	var current := player.position
	var support := ground_surface_y(current)
	if not _safe_standing(previous_position) or not _safe_standing(current) or previous_position.y > support + 0.40:
		return _restore_footing()
	if _can_record_footing(current, support):
		_last_safe = current
	return false


func _restore_footing() -> bool:
	player.position = _last_safe
	player.velocity = Vector3.ZERO
	_recoveries += 1
	_sync_external_avatar_reposition()
	return true


func last_safe_position() -> Vector3:
	return _last_safe


func safe_reset_count() -> int:
	return _recoveries


func switch_louvers() -> String:
	_louvers.choose_next(reduced_motion)
	return Louvers.LABELS[louver_detent()]


func louver_detent() -> int:
	return _louvers.detent


func louver_angle() -> float:
	return _louvers.angle


func louver_is_moving() -> bool:
	return _louvers.moving()


func sun_patch_center() -> Vector3:
	return _louvers.patch_center()


func illuminated_bed() -> int:
	return _louvers.lit_bed()


func _process(delta: float) -> void:
	super._process(delta)
	if not blocked and not is_instance_valid(_story_camera) and _louvers.moving():
		_louvers.advance(delta)


func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	if is_instance_valid(_louvers) and reduced_motion and louver_is_moving():
		_louvers.settle()
	if _water != null:
		_water.set_shader_parameter("reduced_motion", reduced_motion)


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	_coordinate_lighting()


func _coordinate_lighting() -> void:
	var evening := active_time_phase in ["dusk", "night"]
	var haze := Color("#445e61") if evening else Color("#849e8a")
	environment.background_color = haze
	environment.fog_light_color = haze
	environment.ambient_light_color = Color("#b3c8c0") if evening else Color("#e3e6cf")
	environment.ambient_light_energy = 0.78 if evening else 0.85
	sun.light_color = Color("#dfebce")
	sun.light_energy = minf(sun.light_energy, 0.76)
	if not is_instance_valid(_louvers):
		return
	_louvers.set_light_gain(0.50 if evening else 0.68)
	_buds.emission_energy_multiplier = 0.64 if evening else 0.17
	_bud_pool.light_energy = 0.68 if evening else 0.26
	_glazing.set_shader_parameter("glass_light", Color("#829d98") if evening else Color("#c2d5b5"))
	_glazing.set_shader_parameter("glass_dark", Color("#3a6665") if evening else Color("#798d74"))


func map_snapshot() -> Dictionary:
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var at := player.position if is_instance_valid(player) else ENTRY
	var lit := illuminated_bed()
	return {"region": "garden", "bounds": BOUNDS, "land": LAND.duplicate(), "areas": AREAS.duplicate(true),
		"points": stops, "player": at, "area": _area_at_position(at), "water": WETLAND_WATER, "boardwalk": BOARDWALK,
		"ramp": RAMP, "terraces": [LOWER, UPPER], "upper_link": LINK, "beds": _louvers.bed_centers(),
		"light_center": sun_patch_center(), "lit_bed": lit, "light_label": Louvers.LABELS[lit] if lit >= 0 else "光斑移動中"}
