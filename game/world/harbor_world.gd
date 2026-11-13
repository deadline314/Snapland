extends "res://game/world/park_world.gd"
## A local tide preview: permanent shore and bridge surround the lighthouse waterway.
const BOUNDS := Rect2(-15, -12, 30, 24)
const LAND: Array[Rect2] = [
	Rect2(-15, -12, 6, 24), Rect2(9, -12, 6, 24),
	Rect2(-9, -12, 18, 4), Rect2(-9, 8, 18, 4),
	Rect2(-4, -4, 8, 8), Rect2(-1, -8, 2, 4),
]
const SANDBAR := Rect2(-9, -1.5, 5, 3)
const SHORE_DOCK := Vector3(-12, 0.2, 9)
const LIGHTHOUSE_DOCK := Vector3(-2, 0.2, 2)
const GROUND_Y := 0.2
var _high_tide := false
var _sandbar_mesh: MeshInstance3D
var _sandbar_body: StaticBody3D
var _tide_label: Label3D

func _build_region_geometry() -> void:
	sea_material = ShaderMaterial.new()
	sea_material.shader = WATER
	var sea := PlaneMesh.new()
	sea.size = Vector2(180, 180)
	_mesh(sea, Vector3(0, -0.25, 0), sea_material)
	for index in range(LAND.size()):
		var shore := _terrain(LAND[index], _coastal_surface(0 if index < 5 else 1, 2.0, Color("#d4c4a0")))
		shore.name = "HarborShore%d" % index
	_sandbar_mesh = _terrain(SANDBAR, _coastal_surface(4, 2.5, Color("#eed29a")))
	_sandbar_mesh.name = "LowTideSandbar"
	_sandbar_body = _sandbar_mesh.get_child(0) as StaticBody3D
	# Deck finishes share the same collision top as the shore beneath them.
	for dock in [SHORE_DOCK, LIGHTHOUSE_DOCK]:
		var deck := _box(dock - Vector3(0, 0.05, 0), Vector3(3.6, 0.1, 3.6), Color("#9b784f"))
		_set_registered_surface(deck, _coastal_surface(1, 1.4))
		for offset in [-1.7, 1.7]:
			_cylinder(dock + Vector3(offset, 0.32, 1.5), 0.12, 0.64, TEAL)
	# The tower sits clear of the island's boarding and bridge approaches.
	var lighthouse := _cylinder(Vector3(2.4, 2.9, -2.4), 0.8, 5.4, CREAM, 0.55, true)
	lighthouse.name = "HarborLighthouse"
	_set_registered_surface(lighthouse, _stone_finish(CREAM))
	_cylinder(Vector3(2.4, 4.0, -2.4), 0.68, 0.5, CORAL)
	_cylinder(Vector3(2.4, 5.85, -2.4), 0.95, 0.45, TEAL)
	_cylinder(Vector3(2.4, 6.35, -2.4), 0.55, 0.6, GOLD)
	_cone(Vector3(2.4, 7.1, -2.4), CORAL)
	# A moored boat is scenery; boarding is the explicit, always-free ferry point.
	var boat := _box(Vector3(-7, -0.02, 5.6), Vector3(2.5, 0.45, 1.3), TEAL)
	_set_registered_surface(boat, _coastal_surface(2, 1.0))
	_box(Vector3(-7, 0.4, 5.6), Vector3(1.0, 0.65, 1.0), CREAM)
	_box(Vector3(-7, 0.8, 5.6), Vector3(1.5, 0.15, 1.4), CORAL)
	_sign("返回迎賓大道", Vector3(-12, 0.2, 6.4))
	_sign("免費渡船 ↔ 燈塔", Vector3(-12, 0.2, 10.8))
	_sign("免費渡船 ↔ 岸邊", Vector3(-2, 0.2, 3.8))
	_sign("環岸步道 → 燈塔", Vector3(-11.8, 0.2, -8.5))
	_sign("浪間小艇 · 空白鍵拿取／交貨", Vector3(12, 0.2, -2.3))
	_box(Vector3(13.4, 0.8, -0.4), Vector3(1.0, 1.2, 1.0), TEAL)
	_box(Vector3(13.4, 1.5, -0.4), Vector3(1.5, 0.2, 1.5), CORAL)
	_tide_label = _sign("退潮 · 沙洲可通行", Vector3(-12, 0.2, -3.0))
	_cylinder(Vector3(-13.8, 1.35, -3), 0.48, 0.16, GOLD).rotation_degrees.x = 90
	_box(Vector3(-13.8, 0.75, -3), Vector3(0.14, 1.5, 0.14), TEAL)
	_point("region:welcome", "返回迎賓大道", Vector3(-12, GROUND_Y, 5))
	_point("harbor:tide", "潮汐鐘 · 預覽漲退潮", Vector3(-12, GROUND_Y, -1))
	_point("harbor:ferry:shore", "免費渡船 · 前往燈塔", SHORE_DOCK)
	_point("harbor:ferry:lighthouse", "免費渡船 · 返回岸邊", LIGHTHOUSE_DOCK)
	_point("harbor:info:lighthouse", "燈塔與環形水路", Vector3(0, GROUND_Y, -2))
	_point("game-013", "浪間小艇 · 免費遊玩", Vector3(12, GROUND_Y, 0))
	_sign("潮汐沙路 · 空白鍵插路標", Vector3(12, 0.2, 3.4))
	_box(Vector3(13.4, 0.8, 5.4), Vector3(1.0, 1.2, 1.0), CORAL)
	_box(Vector3(13.4, 1.5, 5.4), Vector3(1.5, 0.2, 1.5), GOLD)
	_point("game-014", "潮汐沙路 · 免費遊玩", Vector3(12, GROUND_Y, 5.6))
	# The prism miniature sits beside the lighthouse it borrows its beam from.
	_sign("燈塔折光 · 轉鏡點亮航標", Vector3(2.4, 0.2, 1.4))
	_point("game-015", "燈塔折光 · 免費遊玩", Vector3(1.2, GROUND_Y, -0.6))
	_sign("繩結拖船 · 掛鉤拖浮台", Vector3(12, 0.2, -6.4))
	_box(Vector3(13.4, 0.8, -4.6), Vector3(1.0, 1.2, 1.0), TEAL)
	_box(Vector3(13.4, 1.5, -4.6), Vector3(1.5, 0.2, 1.5), CREAM)
	_point("game-016", "繩結拖船 · 免費遊玩", Vector3(12, GROUND_Y, -4.6))
	_sign("蟹洞彈珠 · 蓄力撞開蟹門", Vector3(-4, 0.2, 8.6))
	_box(Vector3(-5.6, 0.8, 10.4), Vector3(1.0, 1.2, 1.0), CORAL)
	_box(Vector3(-5.6, 1.5, 10.4), Vector3(1.5, 0.2, 1.5), CREAM)
	_point("game-017", "蟹洞彈珠 · 免費遊玩", Vector3(-4, GROUND_Y, 10.2))
	_sign("船艙配重 · 搬箱壓穩船身", Vector3(0, 0.2, 8.6))
	_box(Vector3(1.6, 0.8, 10.4), Vector3(1.0, 1.2, 1.0), TEAL)
	_box(Vector3(1.6, 1.5, 10.4), Vector3(1.5, 0.2, 1.5), GOLD)
	_point("game-018", "船艙配重 · 免費遊玩", Vector3(0, GROUND_Y, 10.2))
	_sign("其餘六款遊戲準備中", Vector3(12, 0.2, 9.4))
	current_area = "潮汐碼頭"

func _terrain(rect: Rect2, material: Material) -> MeshInstance3D:
	var center := rect.get_center()
	var surface := _box(Vector3(center.x, GROUND_Y - 0.3, center.y), Vector3(rect.size.x, 0.6, rect.size.y), CREAM, true)
	_set_registered_surface(surface, material)
	return surface

func _sign(text: String, at: Vector3) -> Label3D:
	var board := _box(at + Vector3(0, 1.05, 0), Vector3(2.9, 0.8, 0.16), TEAL)
	_set_registered_surface(board, _coastal_surface(2, 1.5))
	_box(at + Vector3(0, 0.4, 0), Vector3(0.14, 0.8, 0.14), TEAL)
	return _local_label(text, at + Vector3(0, 1.1, 0.15), 16, CREAM)

func _build_region_activities() -> void:
	pass

func _register_npc_activity() -> void:
	pass

func _build_player_floor() -> void:
	pass

func _player_spawn_position() -> Vector3:
	return SHORE_DOCK

func update_collection(_photos: Dictionary) -> void:
	pass

func ground_surface_y(position: Vector3) -> float:
	return GROUND_Y if _is_land(Vector2(position.x, position.z)) else -0.4

func _is_land(point: Vector2) -> bool:
	for rect in LAND:
		if rect.has_point(point): return true
	return not _high_tide and SANDBAR.has_point(point)

func _safe_footing(position: Vector3) -> bool:
	var center := Vector2(position.x, position.z)
	for offset in [Vector2(-0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3)]:
		if not _is_land(center + offset): return false
	return true

func _constrain_player(previous_position: Vector3) -> bool:
	if player.position.y < -1.0 or not _safe_footing(previous_position):
		player.position = SHORE_DOCK
		player.velocity = Vector3.ZERO
		return true
	if not _safe_footing(player.position):
		player.position = previous_position
		player.velocity = Vector3.ZERO
	return false

func _area_at_position(_position: Vector3) -> String:
	return "潮汐碼頭"

func set_tide(high: bool) -> void:
	if high == _high_tide: return
	if high and is_instance_valid(player) and SANDBAR.grow(0.3).has_point(Vector2(player.position.x, player.position.z)):
		_relocate(SHORE_DOCK)
	_high_tide = high
	if is_instance_valid(_sandbar_mesh):
		_sandbar_mesh.visible = not high
		_sandbar_body.collision_layer = 0 if high else 1
		_tide_label.text = "漲潮 · 沙洲封閉" if high else "退潮 · 沙洲可通行"

func is_high_tide() -> bool:
	return _high_tide

func take_ferry(point_id: String) -> bool:
	if not is_instance_valid(player): return false
	match point_id:
		"harbor:ferry:shore": _relocate(LIGHTHOUSE_DOCK)
		"harbor:ferry:lighthouse": _relocate(SHORE_DOCK)
		_: return false
	return true

func _relocate(destination: Vector3) -> void:
	player.position = destination
	player.velocity = Vector3.ZERO
	_sync_external_avatar_reposition()
	_update_sprite_grounding()

func map_snapshot() -> Dictionary:
	var map_points: Array[Dictionary] = []
	for point in points:
		map_points.append({"id": point.id, "label": point.label, "position": point.position})
	return {"bounds": BOUNDS, "land": LAND.duplicate(), "sandbar": SANDBAR, "points": map_points, "player": player.position, "high_tide": _high_tide}
