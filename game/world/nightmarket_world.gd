extends "res://game/world/park_world.gd"

const RegionalVisit = preload("res://game/story/regional_visit.gd")
const Atmosphere = preload("res://game/world/nightmarket_atmosphere.gd")
const BOUNDS := Rect2(-12, -14.1, 24, 23.6)
const GROUND_Y := 0.20
const SCENT_ENTRY := Vector3(-5.65, GROUND_Y, -4.35)
const COIN_ENTRY := Vector3(-9.15, GROUND_Y, -2.18)
const ROOF_Y := 0.92
const LANTERN_ENTRY := Vector3(4.12, ROOF_Y, -10.58)
const ENTRY := Vector3(0, GROUND_Y, 7.55)
const STORY_POINT := Vector3(4.35, GROUND_Y, 7.55)
const STORY_HOST := Vector3(6.0, GROUND_Y, 7.23)
const RAMP := Rect2(-2.2, -9.4, 4.4, 4.0)
const ROOF := Rect2(-5.6, -14.1, 11.2, 4.7)
const AWNING := Rect2(-1.95, -2.55, 3.9, 7.15)
const LAND: Array[Rect2] = [
	Rect2(-12, -6.0, 24, 3.2), Rect2(-12, -3.08, 4.5, 8.11),
	Rect2(7.5, -3.08, 4.5, 8.11), Rect2(-12, 4.8, 24, 4.7),
	Rect2(-2.2, -3.08, 4.4, 8.11), RAMP, ROOF,
]
const FLOOR_COLORS := [Color("#8093aa"), Color("#73819b"), Color("#73819b"), Color("#8196ab"), Color("#698f95")]
const SKYLINE := "res://assets/world/nightmarket-skyline.webp"
const INK := Color("#292943")
const STALL := Color("#584160")
const CORAL_NEON := Color("#ff937a")
const MINT_NEON := Color("#7df0db")
const PAPER_LIGHT := Color("#fff0cd")
const STALL_ACCENTS := [Color("#c87372"), Color("#5aa899"), Color("#a08ec0")]
const STALL_ROOFS := [Color("#7d465e"), Color("#395f68"), Color("#645177")]
var _operating := true
var _status_label: Label3D
var _stall_lights: Array[MeshInstance3D] = []
var _rain: Array[CPUParticles3D] = []
var _lit_material: StandardMaterial3D
var _dim_material: StandardMaterial3D
var _sign_materials: Dictionary = {}
var _trim_meshes: Dictionary = {}
var _atmosphere: Node3D
var _story_photo_camera: Camera3D
var _story_photo_origin: Vector3
var _story_photo_facing := "front"
var _story_name_label: Label3D
var _story_host_sprite: Sprite3D
var _story_rest_pose: Texture2D
var _story_photo_pose: Texture2D

func _build_region_geometry() -> void:
	_build_atmosphere()
	_build_street_foundations()
	_build_neighboring_shops()
	for index in FLOOR_COLORS.size():
		var area := LAND[index]
		var center := area.get_center()
		var floor_mesh := _box(Vector3(center.x, GROUND_Y - 0.24, center.y), Vector3(area.size.x, 0.48, area.size.y), FLOOR_COLORS[index], true)
		floor_mesh.name = "MarketWalk%d" % index
		_set_registered_surface(floor_mesh, _atmosphere.paving_material())
	_build_roof()
	_build_stalls()
	_build_awning()
	_build_route_markers()
	_add_rain()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("nightmarket:trade", "攤街燈牌 · 切換營業", Vector3(-4.0, GROUND_Y, 6.65))
	_point("nightmarket:shelter", "雨棚巷 · 看遮雨方式", Vector3(0, GROUND_Y, 0.7))
	_point("nightmarket:rooftop", "屋頂餐桌 · 看夜市", Vector3(0, ROOF_Y, -11.65))
	_point("nightmarket:signs", "招牌維修台 · 看營業燈", Vector3(9.6, GROUND_Y, -0.2))
	_point("nightmarket:reset", "安全返回夜市入口", Vector3(-9.6, GROUND_Y, 1.0))
	_point("game-037", "雨棚快遞 · 撐傘送熱餐", Vector3(0, GROUND_Y, 2.85))
	_point("game-038", "炭火串燒 · 翻面收火", Vector3(9.15, GROUND_Y, 3.27))
	_build_courier_stand()
	_build_skewer_stand()
	_point("game-039", "燈籠繩渡 · 屋頂掛燈", LANTERN_ENTRY)
	_build_lantern_stand()
	_point("game-040", "銅板借彈 · 西街桌檯", COIN_ENTRY)
	_build_coin_stand()
	_point("game-041", "香氣尋攤 · 北街聞香亭", SCENT_ENTRY)
	_build_scent_stand()
	_npc(STORY_HOST, CORAL_NEON, "阿浪")
	_sign("夜市迎賓", STORY_HOST + Vector3(0, 1.10, -0.75), CORAL_NEON)
	_point(RegionalVisit.NIGHTMARKET_POINT, "夜市迎賓 · 和阿浪合照", STORY_POINT)
	_sync_operating()
	current_area = _area_at_position(ENTRY)

func begin_story_photo() -> bool:
	if is_instance_valid(_story_photo_camera) or not is_instance_valid(player):
		return false
	var actor := _npc_record_for_role("announcer")
	if actor.is_empty():
		return false
	_story_photo_origin = player.position
	_story_photo_facing = facing
	_set_story_host_pose(_story_photo_pose)
	_story_name_label = actor.get("name_label") as Label3D
	if is_instance_valid(_story_name_label):
		_story_name_label.hide()
	player.position = STORY_POINT
	player.velocity = Vector3.ZERO
	_sync_external_avatar_reposition()
	facing = "front"
	avatar_action = ""
	avatar_action_remaining = 0.0
	avatar_action_elapsed = 0.0
	_refresh_avatar_texture(0)
	var center := STORY_POINT.lerp(STORY_HOST, 0.5) + Vector3(0, 1.45, 0)
	_story_photo_camera = Camera3D.new()
	_story_photo_camera.name = "NightmarketGroupPhotoCamera"
	_story_photo_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_story_photo_camera.size = 6.4
	_story_photo_camera.far = camera.far
	_story_photo_camera.position = center + Vector3(-1.70, 3.05, 9.0)
	add_child(_story_photo_camera)
	_story_photo_camera.look_at(center)
	_story_photo_camera.make_current()
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, -0.85, -6.0)
	fill.light_color = Color("#ffdfb1")
	fill.light_energy = 0.69
	fill.omni_range = 5.9
	fill.shadow_enabled = false
	_story_photo_camera.add_child(fill)
	return true

func end_story_photo() -> void:
	if not is_instance_valid(_story_photo_camera):
		return
	camera.make_current()
	_story_photo_camera.queue_free()
	_story_photo_camera = null
	if is_instance_valid(_story_name_label):
		_story_name_label.show()
	_story_name_label = null
	_set_story_host_pose(_story_rest_pose)
	player.position = _story_photo_origin
	player.velocity = Vector3.ZERO
	facing = _story_photo_facing
	_sync_external_avatar_reposition()
	_refresh_avatar_texture(0)

func _interaction_markers_allowed() -> bool:
	return not is_instance_valid(_story_photo_camera)

func _build_street_foundations() -> void:
	# Join the stalls and walkways on one city block, with curbs marking the safe routes.
	var foundation := _box(Vector3(0, -0.46, -1.7), Vector3(26.4, 0.60, 25.9), Color("#446079"))
	foundation.name = "MarketBlock"
	_set_registered_surface(foundation, _coastal_surface(0, 6.8, Color("#536681")))
	for side in [-1.0, 1.0]:
		var x: float = side * 11.88
		_box(Vector3(x, 0.30, -0.1), Vector3(0.20, 0.24, 19.1), Color("#8794a5"))
		_box(Vector3(side * 4.82, 0.28, 0.85), Vector3(5.14, 0.47, 8.0), Color("#42374e"))
		_box(Vector3(side * 8.66, 0.19, -8.29), Vector3(6.15, 0.60, 4.15), Color("#4e4a67"))
		_box(Vector3(side * 8.90, 0.64, -9.95), Vector3(5.24, 1.20, 0.29), Color("#665a7f"))
	for x in [-4.8, 4.8]:
		_box(Vector3(x, 0.27, 9.39), Vector3(8.00, 0.19, 0.21), Color("#8794a5"))
		_box(Vector3(x, 0.18, 9.65), Vector3(8.00, 0.12, 0.27), Color("#4a6178"))

func _box(pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	if solid:
		return super._box(pos, size, color, true)
	var mesh := _trim_meshes.get(size) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_trim_meshes[size] = mesh
	return _mesh(mesh, pos, _mat(color))

func _build_neighboring_shops() -> void:
	# These facades extend the district beyond the playable street without adding collision.
	var wall := Color("#4b435e")
	var eaves := Color("#3d3857")
	var shutter := Color("#654f64")
	var window := _unshaded(Color("#bf8a7e"))
	for at: Vector3 in [Vector3(-14.65, -0.14, -5.7), Vector3(14.4, -0.14, -7.8),
			Vector3(-15.55, -0.14, 5.1), Vector3(15.2, -0.14, 4.7)]:
		_box(at + Vector3(0, 1.42, 0), Vector3(3.68, 2.84, 4.15), wall)
		for side in [-1.0, 1.0]:
			var panel := _box(at + Vector3(side * 1.01, 2.97, 0), Vector3(2.16, 0.23, 4.52), eaves)
			panel.rotation.z = -side * 0.25
		var face := at + Vector3(0, 1.57, 2.12)
		_box(face, Vector3(2.88, 1.26, 0.16), shutter)
		for x in [-0.93, 0.0, 0.93]:
			var pane := _box(face + Vector3(x, 0.17, 0.10), Vector3(0.54, 0.64, 0.08), PAPER_LIGHT)
			pane.material_override = window
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(face + Vector3(0, -0.56, 0.43), Vector3(3.20, 0.13, 0.90), eaves)

func _build_atmosphere() -> void:
	var base := PlaneMesh.new()
	base.size = Vector2(112, 112)
	var paving := _mesh(base, Vector3(0, -0.18, 0), _mat(INK))
	paving.name = "RainyHorizonBase"
	_set_registered_surface(paving, _coastal_surface(0, 6.1, Color("#404859")))
	_atmosphere = Atmosphere.new()
	_atmosphere.name = "NightmarketAtmosphere"
	add_child(_atmosphere)
	var image := load(SKYLINE) as Texture2D if ResourceLoader.exists(SKYLINE) else null
	_atmosphere.setup(environment, sun, image, coastal_atlas, AWNING)

func _build_roof() -> void:
	var rise := ROOF_Y - GROUND_Y
	var angle := atan2(rise, RAMP.size.y)
	var ramp_center := RAMP.get_center()
	var rotation := Basis(Vector3.RIGHT, angle)
	var thickness := 0.28
	var top := Vector3(ramp_center.x, GROUND_Y + rise * 0.5, ramp_center.y)
	var slope := _box(top - rotation.y * thickness * 0.5,
		Vector3(RAMP.size.x, thickness, Vector2(rise, RAMP.size.y).length()), Color("#75729b"), true)
	slope.name = "RoofRamp"
	slope.basis = rotation
	_set_registered_surface(slope, _atmosphere.paving_material(true))
	var center := ROOF.get_center()
	var roof := _box(Vector3(center.x, ROOF_Y - 0.54, center.y), Vector3(ROOF.size.x, 1.08, ROOF.size.y), Color("#6a688d"), true)
	roof.name = "RoofDiningDeck"
	_set_registered_surface(roof, _atmosphere.paving_material(true))
	var railing := Color("#a195b4")
	_box(Vector3(0, ROOF_Y + 0.56, -13.96), Vector3(11.16, 0.18, 0.18), railing)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 5.49, ROOF_Y + 0.56, center.y), Vector3(0.17, 0.18, 4.54), railing)
		_box(Vector3(side * 3.92, ROOF_Y + 0.56, -9.53), Vector3(3.30, 0.18, 0.17), railing)
		for z in [-13.94, -11.80, -9.53]:
			_box(Vector3(side * 5.48, ROOF_Y + 0.24, z), Vector3(0.20, 0.64, 0.20), STALL)
	for x in [-3.2, 3.2]:
		var tabletop := _cylinder(Vector3(x, ROOF_Y + 0.72, -11.7), 0.83, 0.16, Color("#bd8d7e"))
		_cylinder(tabletop.position + Vector3(0, 0.09, 0), 0.40, 0.04, Color("#7e5572"))
		_cylinder(Vector3(x, ROOF_Y + 0.34, -11.7), 0.45, 0.68, INK, 0.29, true)
		_market_lantern(Vector3(x, ROOF_Y + 0.97, -11.7), PAPER_LIGHT, 0.13)
		for dz in [-1.02, 1.02]:
			_box(Vector3(x, ROOF_Y + 0.21, -11.7 + dz), Vector3(0.94, 0.42, 0.42), STALL)
	_sign("屋頂餐桌", Vector3(0.0, ROOF_Y, -13.3), CORAL_NEON)

func _build_stalls() -> void:
	_lit_material = _unshaded(CORAL_NEON)
	_dim_material = _unshaded(Color("#76546b"))
	for side in [-1, 1]:
		for index in 3:
			var x: float = side * 6.1
			var z := -3.1 + index * 3.07
			_build_stall(Vector3(x, GROUND_Y, z), side, (index + int(side > 0)) % STALL_ACCENTS.size())
	_status_label = _sign("", Vector3(-4.2, GROUND_Y, 5.62), MINT_NEON)
	_sign("招牌維修台", Vector3(10.0, GROUND_Y, -1.5), CORAL_NEON)

func _build_stall(at: Vector3, side: int, style: int) -> void:
	var accent: Color = STALL_ACCENTS[style]
	_box(at + Vector3(0, 0.56, 0), Vector3(2.08, 1.12, 2.38), STALL).name = "MarketBooth"
	_box(at + Vector3(0, 1.18, 0), Vector3(2.27, 0.15, 2.53), Color("#bd8b73"))
	for x in [-0.95, 0.95]:
		for z in [-1.04, 1.04]:
			_box(at + Vector3(x, 1.65, z), Vector3(0.14, 0.99, 0.14), Color("#75485c"))
	for tile in [-1.0, 1.0]:
		var panel := _box(at + Vector3(tile * 0.60, 2.35, 0), Vector3(1.27, 0.14, 2.69), STALL_ROOFS[style])
		panel.rotation.z = -tile * 0.27
		_box(at + Vector3(tile * 1.16, 2.19, 0), Vector3(0.11, 0.12, 2.72), accent)
	_box(at + Vector3(0, 2.55, 0), Vector3(0.17, 0.11, 2.77), accent)
	_box(at + Vector3(0, 0.57, 1.21), Vector3(1.71, 0.66, 0.07), accent)
	for x in [-0.53, 0.0, 0.53]:
		_box(at + Vector3(x, 0.58, 1.25), Vector3(0.07, 0.63, 0.07), Color("#5d4156"))
		var serving := _cylinder(at + Vector3(x, 1.31, 0.69), 0.19, 0.12, Color("#d59c69"))
		serving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var strip := _box(at + Vector3(side * 1.14, 1.13, 0), Vector3(0.08, 0.13, 2.41), accent)
	strip.material_override = _unshaded(accent)
	var lantern := _market_lantern(at + Vector3(side * 0.85, 1.94, 1.17), CORAL_NEON, 0.16)
	_stall_lights.append(lantern)

func _market_lantern(at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	_cylinder(at + Vector3(0, radius, 0), radius * 0.83, 0.10, STALL)
	var lantern := _cylinder(at, radius, radius * 1.85, color)
	lantern.material_override = _unshaded(color)
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lantern

func _build_awning() -> void:
	for end in [-2.75, 0.97, 4.69]:
		for x in [-1.98, 1.98]:
			_box(Vector3(x, 1.88, end), Vector3(0.15, 3.35, 0.15), Color("#658e89"), true)
			_box(Vector3(x, 0.44, end), Vector3(0.33, 0.46, 0.33), Color("#527176"))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.29, 0.49, 0.52, 0.32)
	glass.roughness = 0.50
	var canopy := _box(Vector3(0, 3.59, 0.97), Vector3(3.38, 0.08, 7.31), MINT_NEON)
	canopy.name = "CoveredAlleyAwning"
	canopy.material_override = glass
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		var frame := _box(Vector3(side * 1.88, 3.52, 0.97), Vector3(0.42, 0.17, 7.4), Color("#518582"))
		frame.rotation.z = -side * 0.15
	for z in [-2.70, -0.78, 1.10, 2.99, 4.62]:
		_box(Vector3(0, 3.66, z), Vector3(4.18, 0.09, 0.07), Color("#6d9590"))
	var edge_color := Color("#70b6b4")
	for z in [-2.55, 4.51]:
		var edge := _box(Vector3(0, 3.50, z), Vector3(4.20, 0.13, 0.08), edge_color)
		edge.material_override = _unshaded(edge_color)
	_sign("雨棚巷", Vector3(0, GROUND_Y, 4.78), MINT_NEON)

func _build_courier_stand() -> void:
	var at := Vector3(2.77, GROUND_Y, 2.87)
	_box(at + Vector3(0, 0.43, 0), Vector3(1.42, 0.86, 1.17), STALL)
	_box(at + Vector3(0, 0.92, 0), Vector3(1.55, 0.13, 1.27), Color("#b78579"))
	for x in [-0.44, 0.0, 0.44]:
		_box(at + Vector3(x, 1.11, 0.09), Vector3(0.36, 0.24, 0.54), Color("#cb976b"))
	_market_lantern(at + Vector3(0, 1.39, 0), PAPER_LIGHT, 0.11)
	_sign("雨棚快遞", at + Vector3(0, 0.13, -0.44), CORAL_NEON)

func _build_skewer_stand() -> void:
	var at := Vector3(10.58, GROUND_Y, 3.28)
	var copper := Color("#c48056")
	_box(at + Vector3(0, 0.48, 0), Vector3(1.79, 0.94, 1.31), Color("#453039"))
	_box(at + Vector3(0, 1.00, 0), Vector3(1.86, 0.17, 1.39), copper)
	_box(at + Vector3(-0.12, 1.16, 0), Vector3(1.42, 0.17, 1.05), INK)
	var embers := _unshaded(Color("#da643f"))
	for index in 5:
		var x := -0.66 + index * 0.27
		var ember := _box(at + Vector3(x, 1.24, -0.08), Vector3(0.14, 0.08, 0.34), copper)
		ember.material_override = embers
		_box(at + Vector3(x, 1.33, 0), Vector3(0.045, 0.065, 0.86), Color("#9b8990"))
	_market_lantern(at + Vector3(0.71, 1.40, 0.49), PAPER_LIGHT, 0.12)
	_sign("炭火串燒", at + Vector3(0, 0.18, -0.52), Color("#ffd28e"))


func _build_lantern_stand() -> void:
	var at := Vector3(5.13, ROOF_Y, -10.41)
	var wood := Color("#805a63")
	_box(at + Vector3(0.02, 0.11, 0), Vector3(0.48, 0.20, 2.07), STALL)
	for z in [-0.86, 0.69]:
		_box(at + Vector3(0, 0.79, z), Vector3(0.14, 1.51, 0.13), wood)
		_box(at + Vector3(0, 1.29, z), Vector3(0.28, 0.28, 0.22), CORAL_NEON)
	var rail := _box(at + Vector3(0, 1.49, -0.08), Vector3(0.16, 0.12, 1.83), wood)
	rail.rotation.x = -0.09
	for z in [-0.58, -0.11, 0.36]:
		_market_lantern(at + Vector3(0, 1.22, z), PAPER_LIGHT, 0.12)
	_sign("燈籠繩渡", at + Vector3(-0.76, 0.04, -0.45), Color("#f7bd8a"))


func _build_coin_stand() -> void:
	var at := Vector3(-10.66, GROUND_Y, -2.30)
	var lacquer := Color("#89545a")
	var felt := Color("#425e67")
	_box(at + Vector3(0, 0.44, 0), Vector3(1.66, 0.87, 1.38), STALL)
	_box(at + Vector3(0, 0.91, 0), Vector3(1.82, 0.15, 1.56), lacquer)
	_box(at + Vector3(0, 1.00, -0.05), Vector3(1.57, 0.06, 1.33), felt)
	for index in 3:
		var x := -0.49 + float(index) * 0.47
		_cylinder(at + Vector3(x, 1.05, -0.33), 0.145, 0.043, Color("#a97759"))
		_cylinder(at + Vector3(x, 1.075, -0.33), 0.101, 0.017, INK)
	var left := _box(at + Vector3(-0.43, 1.10, 0.28), Vector3(0.52, 0.11, 0.055), MINT_NEON)
	left.rotation.y = 0.54
	var right := _box(at + Vector3(0.27, 1.10, 0.18), Vector3(0.56, 0.11, 0.055), CORAL_NEON)
	right.rotation.y = -0.46
	_market_lantern(at + Vector3(-0.72, 1.38, 0.5), PAPER_LIGHT, 0.13)
	_sign("銅板借彈", at + Vector3(0.11, 0.14, -0.53), Color("#f4c38b"))


func _build_scent_stand() -> void:
	var at := Vector3(-5.65, GROUND_Y, -5.45)
	var jade := Color("#3b695e")
	_box(at + Vector3(0, 0.39, 0), Vector3(1.62, 0.78, 0.78), STALL)
	_box(at + Vector3(0, 0.81, 0), Vector3(1.75, 0.10, 0.90), jade)
	for index in 3:
		var x := -0.51 + float(index) * 0.46
		var glaze: Color = [MINT_NEON, PAPER_LIGHT, CORAL_NEON][index]
		_cylinder(at + Vector3(x, 0.94, 0.10), 0.15, 0.17, jade)
		_cylinder(at + Vector3(x, 1.05, 0.10), 0.11, 0.06, glaze)
	var cloth := _box(at + Vector3(0, 1.46, -0.30), Vector3(1.64, 0.32, 0.10), Color("#734b65"))
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sign("北街聞香", at + Vector3(0, 1.40, -0.21), PAPER_LIGHT)


func _build_route_markers() -> void:
	_sign("霓虹夜市", Vector3(-0.25, GROUND_Y, 6.25), CORAL_NEON)
	_sign("免費返回", Vector3(0.0, GROUND_Y, 8.75), PAPER_LIGHT)
	for x in [-9.75, 0.0, 9.75]:
		for z in [-4.7, 5.65, 7.0]:
			_box(Vector3(x, GROUND_Y + 0.012, z), Vector3(0.8, 0.025, 0.14), MINT_NEON)
	for x in [-11.6, 11.6]:
		for z in [-4.8, 0.0, 4.9, 8.4]:
			_box(Vector3(x, GROUND_Y + 0.54, z), Vector3(0.12, 1.08, 0.12), STALL)
			var cap := _box(Vector3(x, GROUND_Y + 1.12, z), Vector3(0.23, 0.17, 0.24), PAPER_LIGHT)
			cap.material_override = _unshaded(PAPER_LIGHT)

func _sign(text: String, at: Vector3, accent: Color) -> Label3D:
	var frame := _box(at + Vector3(0, 1.82, 0), Vector3(2.90, 0.70, 0.14), INK)
	var edge := _box(frame.position + Vector3(0, -0.29, 0.08), Vector3(2.85, 0.075, 0.10), accent)
	edge.material_override = _unshaded(accent)
	var label := _local_label(text, at + Vector3(0, 1.84, 0.09), 29, PAPER_LIGHT)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.pixel_size = 0.018
	return label

func _unshaded(color: Color) -> StandardMaterial3D:
	if _sign_materials.has(color):
		return _sign_materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sign_materials[color] = material
	return material

func _add_rain() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var streak := BoxMesh.new()
	streak.size = Vector3(0.015, 0.31, 0.015)
	streak.material = _unshaded(Color("#a9add1"))
	for side in [-1, 1]:
		var emitter := CPUParticles3D.new()
		emitter.position = Vector3(side * 7.2, 6.2, 0.5)
		emitter.amount = 45
		emitter.lifetime = 0.83
		emitter.preprocess = 0.85
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(4.5, 0.7, 7.4)
		emitter.direction = Vector3(0.08, -1.0, 0)
		emitter.spread = 7
		emitter.initial_velocity_min = 6.0
		emitter.initial_velocity_max = 7.0
		emitter.gravity = Vector3.ZERO
		emitter.mesh = streak
		emitter.emitting = not reduced_motion
		add_child(emitter)
		_rain.append(emitter)

func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	_atmosphere.set_reduced_motion(reduced_motion)
	for emitter in _rain:
		emitter.emitting = not reduced_motion

func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	_atmosphere.apply_palette(active_time_phase)

func cycle_market() -> void:
	_operating = not _operating
	_sync_operating()

func market_status() -> String:
	return "營業中" if _operating else "已收攤"

func _sync_operating() -> void:
	_atmosphere.set_market_open(_operating)
	for lamp in _stall_lights:
		lamp.material_override = _lit_material if _operating else _dim_material
	if is_instance_valid(_status_label):
		_status_label.text = market_status()

func _build_region_activities() -> void:
	pass

func _register_npc_activity() -> void:
	# The host keeps a fixed welcome point and uses the authored front poses.
	var actor := _npc_record_for_role("announcer")
	_story_host_sprite = actor.get("sprite") as Sprite3D
	if not is_instance_valid(_story_host_sprite) or avatar_renderer == null:
		return
	_story_rest_pose = _story_host_sprite.texture
	var library: RefCounted = avatar_renderer.animation_library
	var idle := library.texture("announcer", "idle", "front", 0) as Texture2D
	var greeting := library.texture("announcer", "greet", "front", 4) as Texture2D
	if idle != null:
		_story_rest_pose = _fit_npc_rest_texture(idle)
	_story_photo_pose = _fit_npc_rest_texture(greeting) if greeting != null else _story_rest_pose
	_set_story_host_pose(_story_rest_pose)
	actor["name_body_height"] = _visible_body_height(_story_host_sprite)

func _set_story_host_pose(texture: Texture2D) -> void:
	if not is_instance_valid(_story_host_sprite) or texture == null:
		return
	_story_host_sprite.texture = texture
	var material := _story_host_sprite.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("texture_albedo", texture)
		material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))

func _build_player_floor() -> void:
	pass

func update_collection(_photos: Dictionary) -> void:
	pass

func _player_spawn_position() -> Vector3:
	return ENTRY

func covered_at(position: Vector3) -> bool:
	return AWNING.has_point(Vector2(position.x, position.z))

func _area_at_position(position: Vector3) -> String:
	var at := Vector2(position.x, position.z)
	if ROOF.has_point(at) or RAMP.has_point(at):
		return "屋頂餐桌"
	return "雨棚巷" if covered_at(position) else "霓虹夜市"

func ground_surface_y(position: Vector3) -> float:
	var at := Vector2(position.x, position.z)
	if ROOF.has_point(at):
		return ROOF_Y
	if RAMP.has_point(at):
		return lerpf(ROOF_Y, GROUND_Y, inverse_lerp(RAMP.position.y, RAMP.end.y, at.y))
	return GROUND_Y if _is_land(at) else -0.4

func _is_land(point: Vector2) -> bool:
	for rect in LAND:
		if rect.has_point(point):
			return true
	return false

func _safe_footing(position: Vector3) -> bool:
	for offset in [Vector2(-0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3)]:
		if not _is_land(Vector2(position.x, position.z) + offset):
			return false
	return true

func _constrain_player(previous_position: Vector3) -> bool:
	if player.position.y < -1.0 or not _safe_footing(previous_position):
		return reset_to_entry()
	if not _safe_footing(player.position):
		player.position = previous_position
		player.velocity = Vector3.ZERO
	return false

func reset_to_entry() -> bool:
	if not is_instance_valid(player):
		return false
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

func map_snapshot() -> Dictionary:
	var map_points: Array[Dictionary] = []
	for point in points:
		map_points.append({"id": point.id, "label": point.label, "position": point.position})
	var at: Vector3 = player.position if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": LAND.duplicate(), "points": map_points, "player": at,
		"awning": AWNING, "roof": ROOF, "operating": _operating, "covered": covered_at(at), "region": "nightmarket"}
