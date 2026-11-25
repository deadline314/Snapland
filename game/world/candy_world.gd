extends "res://game/world/park_world.gd"
## Local material observation: static sample shapes never grant progress or rewards.
const BOUNDS := Rect2(-13, -12, 26, 24)
const LAND: Array[Rect2] = [
	Rect2(-4, -12, 8, 24), Rect2(-13, -5, 9, 10),
	Rect2(4, -9, 9, 9), Rect2(4, 5, 9, 7),
]
const GROUND_Y := 0.2
const ENTRY := Vector3(0, GROUND_Y, 9)
const TEMPERATURE_LABELS := ["冷 · 糖塊挺立，黏度高", "溫 · 糖團柔軟，可以拉伸", "熱 · 糖漿攤開，流動較快"]
const TEMPERATURE_SIGN_LABELS := ["冷｜硬糖塊", "溫｜可拉伸", "熱｜糖漿流"]
const TEMPERATURE_SCALES := [Vector3(0.65, 1.1, 0.65), Vector3(1, 0.65, 1), Vector3(1.5, 0.2, 1.5)]
const SUGAR_PINK := Color("#c15b8c")
const SUGAR_PLUM := Color("#664369")
var _temperature := 0
var _temperature_display: MeshInstance3D
var _temperature_label: Label3D
var _temperature_materials: Array[Material] = []

func _build_region_geometry() -> void:
	var chocolate := PlaneMesh.new()
	chocolate.size = Vector2(110, 110)
	var syrup_material := _mat(Color("#53313e"))
	syrup_material.roughness = 0.3
	_mesh(chocolate, Vector3(0, -0.65, 0), syrup_material).name = "ChocolateBackdrop"
	var floor_colors := [Color("#986478"), Color("#87618d"), Color("#467d6b"), Color("#4c7c87")]
	for index in range(LAND.size()):
		var rect := LAND[index]
		var center := rect.get_center()
		var floor_mesh := _box(Vector3(center.x, GROUND_Y - 0.3, center.y), Vector3(rect.size.x, 0.6, rect.size.y), floor_colors[index], true)
		_set_registered_surface(floor_mesh, _coastal_surface(0, 2.0, floor_colors[index]))
		floor_mesh.name = "CandyFloor%d" % index
	# The conveyor is flush with the walking floor, leaving the whole main aisle open.
	_box(Vector3(0, GROUND_Y + 0.002, 0), Vector3(3.4, 0.004, 23.6), SUGAR_PLUM).name = "MainConveyor"
	for z in range(-11, 12, 2):
		_box(Vector3(0, GROUND_Y + 0.006, z), Vector3(3.1, 0.004, 0.14), GOLD)
	for x in [-2.0, 2.0]:
		_box(Vector3(x, GROUND_Y + 0.004, 0), Vector3(0.14, 0.008, 23.6), SUGAR_PINK)
	# Peripheral work surfaces and overhead pipes keep the marked routes clear.
	_box(Vector3(-11, 0.8, 0), Vector3(2.6, 1.2, 3.3), SUGAR_PLUM).name = "MaterialWorkbench"
	_box(Vector3(-11, 1.45, 0), Vector3(2.9, 0.1, 3.6), CREAM)
	_box(Vector3(-11, 1.0, -3.8), Vector3(2.4, 1.6, 0.7), SUGAR_PINK)
	for x in [-11.8, -11.0, -10.2]:
		_cylinder(Vector3(x, 2.0, -3.8), 0.26, 0.55, GOLD)
	for z in [-7.0, -2.0]:
		_cylinder(Vector3(11.4, 1.7, z), 0.65, 3.0, SUGAR_PINK).name = "SyrupTank"
		_cylinder(Vector3(11.4, 3.3, z), 0.82, 0.2, CREAM)
	var pipe := _cylinder(Vector3(11.4, 3.0, -4.5), 0.17, 5.0, GOLD)
	pipe.rotation_degrees.x = 90
	for z in [-7.0, -2.0]:
		var inlet := _cylinder(Vector3(9.7, 3.0, z), 0.17, 3.4, GOLD)
		inlet.rotation_degrees.z = 90
		_cylinder(Vector3(8.0, 2.65, z), 0.17, 0.7, GOLD)
	_cylinder(Vector3(10.8, 0.3, 7.2), 1.4, 0.2, SUGAR_PLUM).name = "BubbleMooring"
	for offset in [Vector3(0, 0, 0), Vector3(0.7, 0.6, 0.1), Vector3(-0.5, 0.8, -0.3)]:
		var bubble := _sphere(Vector3(10.8, 1.3, 7.2) + offset, 0.65, CREAM)
		bubble.material_override = _bubble_material()
	for endpoints in [
		[Vector2(-4, -12), Vector2(4, -12)], [Vector2(-4, -12), Vector2(-4, -5)],
		[Vector2(-13, -5), Vector2(-4, -5)], [Vector2(-13, -5), Vector2(-13, 5)],
		[Vector2(-13, 5), Vector2(-4, 5)], [Vector2(-4, 5), Vector2(-4, 12)],
		[Vector2(-4, 12), Vector2(13, 12)], [Vector2(13, 5), Vector2(13, 12)],
		[Vector2(4, 5), Vector2(13, 5)], [Vector2(4, 0), Vector2(4, 5)],
		[Vector2(4, 0), Vector2(13, 0)], [Vector2(13, -9), Vector2(13, 0)],
		[Vector2(4, -9), Vector2(13, -9)], [Vector2(4, -12), Vector2(4, -9)],
	]:
		var start: Vector2 = endpoints[0]
		var end: Vector2 = endpoints[1]
		var center := (start + end) * 0.5
		_box(Vector3(center.x, 0.65, center.y), Vector3(maxf(absf(end.x - start.x), 0.12), 0.12, maxf(absf(end.y - start.y), 0.12)), SUGAR_PLUM)
		for endpoint in [start, end]:
			_cylinder(Vector3(endpoint.x, 0.65, endpoint.y), 0.1, 0.9, SUGAR_PINK)
	_temperature_materials = [_mat(Color("#98c9e1")), _mat(Color("#d98ba6")), _mat(Color("#eea849"))]
	_temperature_display = _sphere(Vector3(-11, 2.0, 0), 0.65, CREAM)
	_temperature_display.name = "TemperatureSample"
	_temperature_label = _sign("", Vector3(-8, GROUND_Y, -1.8))
	_apply_temperature()
	_sign("糖果工廠", Vector3(0, GROUND_Y, 6.5))
	_sign("免費返回", Vector3(0, GROUND_Y, 11.3))
	_sign("材料工作台", Vector3(-8, GROUND_Y, 4.3))
	_sign("糖漿管道", Vector3(9, GROUND_Y, -5.5))
	_sign("泡泡停靠", Vector3(9, GROUND_Y, 10.8))
	_sign("工廠遊戲 %d／12" % preload("res://game/core/game_catalog.gd").definitions("candy").size(), Vector3(0, GROUND_Y, -10.8))
	_sign("餅乾翻模", Vector3(-5.2, GROUND_Y, 0.5))
	_point("region:welcome", "返回迎賓大道 · 免費", Vector3(0, GROUND_Y, 10))
	_point("candy:temperature", "溫度觀察台 · 切換冷／溫／熱", Vector3(-8, GROUND_Y, 0))
	_point("candy:reset", "免費回到工廠入口", Vector3(9, GROUND_Y, 9))
	_point("candy:info:workbench", "材料工作台 · 不影響進度", Vector3(-8, GROUND_Y, 3))
	_point("candy:info:pipes", "糖漿管道與輸送廊", Vector3(9, GROUND_Y, -4))
	_point("game-025", "拉糖橋 · 抓端搭橋與運糖", Vector3(0, GROUND_Y, -9))
	_point("game-026", "餅乾翻模 · 鬆角翻轉與滑接", Vector3(-5, GROUND_Y, 2))
	_point("game-027", "糖漿分洪 · 冷熱切管與關閥", Vector3(7, GROUND_Y, -6))
	_point("game-028", "果凍彈床 · 蓄彈斜壓送高台", Vector3(7, GROUND_Y, -1))
	_point("game-029", "巧克力蝕刻 · 描線折料試轉", Vector3(10.5, GROUND_Y, -0.8))
	_point("game-030", "棉糖捲風 · 移棒轉收糖絲", Vector3(6.5, GROUND_Y, 10))
	_point("game-031", "糖豆蹺蹺板 · 移踏板讓雙豆落盤", Vector3(-2.2, GROUND_Y, -4.5))
	_point("game-032", "冰糖滑塊 · 擋停冰糖冷卻模座", Vector3(-9, GROUND_Y, -2.6))
	_point("game-033", "夾心壓奏 · 跟拍合模封口", Vector3(4.9, GROUND_Y, -3.8))
	_point("game-034", "糖紙滑翔 · 摺翼穿窗落籃", Vector3(-2.6, GROUND_Y, 6.55))
	current_area = "糖果工廠"

func _sign(text: String, at: Vector3) -> Label3D:
	_box(at + Vector3(0, 1.2, 0), Vector3(4.8, 1.2, 0.14), SUGAR_PLUM)
	_box(at + Vector3(0, 0.4, 0), Vector3(0.12, 0.8, 0.12), SUGAR_PINK)
	var label := _local_label(text, at + Vector3(0, 1.25, 0.14), 32, CREAM)
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	return label

func _build_region_activities() -> void:
	pass

func _register_npc_activity() -> void:
	pass

func _build_player_floor() -> void:
	pass

func update_collection(_photos: Dictionary) -> void:
	pass

func _player_spawn_position() -> Vector3:
	return ENTRY

func _area_at_position(_position: Vector3) -> String:
	return "糖果工廠"

func ground_surface_y(position: Vector3) -> float:
	return GROUND_Y if _is_land(Vector2(position.x, position.z)) else -0.4

func _is_land(point: Vector2) -> bool:
	for rect in LAND:
		if rect.has_point(point): return true
	return false

func _safe_footing(position: Vector3) -> bool:
	for offset in [Vector2(-0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3)]:
		if not _is_land(Vector2(position.x, position.z) + offset): return false
	return true

func _constrain_player(previous_position: Vector3) -> bool:
	if player.position.y < -1.0 or not _safe_footing(previous_position):
		reset_to_entry()
		return true
	if not _safe_footing(player.position):
		player.position = previous_position
		player.velocity = Vector3.ZERO
	return false

func cycle_temperature() -> void:
	_temperature = (_temperature + 1) % TEMPERATURE_LABELS.size()
	_apply_temperature()

func temperature_label() -> String:
	return TEMPERATURE_LABELS[_temperature]

func _apply_temperature() -> void:
	if not is_instance_valid(_temperature_display): return
	_temperature_display.scale = TEMPERATURE_SCALES[_temperature]
	_temperature_display.position.y = 1.5 + 0.65 * _temperature_display.scale.y
	_set_registered_surface(_temperature_display, _temperature_materials[_temperature])
	_temperature_label.text = TEMPERATURE_SIGN_LABELS[_temperature]

func reset_to_entry() -> bool:
	if not is_instance_valid(player): return false
	player.position = ENTRY
	player.velocity = Vector3.ZERO
	_sync_external_avatar_reposition()
	avatar_is_walking = false
	walk_distance_phase = 0.0
	avatar_action = ""
	avatar_action_remaining = 0.0
	avatar_action_elapsed = 0.0
	if is_instance_valid(avatar_hair_rig): avatar_hair_rig.reset_motion()
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
	return {"bounds": BOUNDS, "land": LAND.duplicate(), "points": map_points, "player": player.position if is_instance_valid(player) else ENTRY, "temperature": _temperature, "region": "candy"}
