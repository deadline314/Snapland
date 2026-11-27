extends "res://game/world/park_world.gd"
## Candy factory district: tiled factory floors between a syrup river and the pastel
## halls. This script owns what the player can do here (walkable land, the temperature
## bench, the free return, every interaction point); candy_scenery builds the place and
## candy_life animates it. Local material observation never grants progress or rewards.
const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/candy_props.gd")
const Scenery := preload("res://game/world/candy_scenery.gd")
const Life := preload("res://game/world/candy_life.gd")
const BOUNDS := Rect2(-13, -12, 26, 24)
## Main aisle, material lab, pipe gallery, bubble mooring and the canal bridge.
const LAND: Array[Rect2] = [
	Rect2(-4, -12, 8, 24), Rect2(-13, -5, 9, 10),
	Rect2(4, -9, 9, 9), Rect2(4, 5, 9, 7),
	Rect2(8, 0, 2, 5),
]
const GROUND_Y := 0.2
const ENTRY := Vector3(0, GROUND_Y, 9)
const TEMPERATURE_LABELS := ["冷 · 糖塊挺立，黏度高", "溫 · 糖團柔軟，可以拉伸", "熱 · 糖漿攤開，流動較快"]
const TEMPERATURE_SIGN_LABELS := ["冷｜硬糖塊", "溫｜可拉伸", "熱｜糖漿流"]
const TEMPERATURE_SCALES := [Vector3(0.65, 1.1, 0.65), Vector3(1, 0.65, 1), Vector3(1.5, 0.2, 1.5)]
## The sample rests on the hot plate of the lab bench.
const SAMPLE_AT := Vector3(-11, 1.66, 0)
const SAMPLE_RADIUS := 0.55
var _temperature := 0
var _temperature_display: MeshInstance3D
var _temperature_label: Label3D
var _temperature_needle: MeshInstance3D
var _temperature_materials: Array[Material] = []
var _kit: Kit
var _scenery: Scenery
var _life: Life

func _build_region_geometry() -> void:
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	_scenery.build()
	_build_temperature_bench()
	_build_entries()
	_life = Life.new(self, _scenery)
	_life.build()
	_kit.finish()
	_life.hold_still()
	current_area = "糖果工廠"

## The sample changes shape and colour with the temperature; a needle on the bench dial follows.
func _build_temperature_bench() -> void:
	for tone: Color in Props.TEMPERATURE_TONES:
		_temperature_materials.append(_finish(tone, Vector3.ONE * 2.0))
	_temperature_display = _sphere(SAMPLE_AT, SAMPLE_RADIUS, CREAM)
	_temperature_display.name = "TemperatureSample"
	var needle := Kit.Sculpt.new()
	needle.box(Vector3(0, 0.17, 0), Vector3(0.06, 0.4, 0.02), Props.DARK)
	needle.box(Vector3(0, 0.38, 0), Vector3(0.12, 0.1, 0.02), Props.RED)
	_temperature_needle = _mesh(needle.mesh(), _scenery.needle_pivot, _vertex_color_material("scenery-detail"))
	_temperature_needle.name = "TemperatureNeedle"
	_temperature_label = Props.signboard(self, _kit, Vector3(-7.3, GROUND_Y, -4.62), TEMPERATURE_SIGN_LABELS[0], 32)
	_apply_temperature()

func _build_entries() -> void:
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
	_point("game-035", "汽泡升降梯 · 踩泵運桶跨熱槽", Vector3(2.6, GROUND_Y, -7.0))
	_point("game-036", "熔糖抽絲 · 控溫拉出三段糖絲", Vector3(2.6, GROUND_Y, 2.8))

func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	if _scenery != null:
		_scenery.apply_time_of_day(lamp_energy_for_phase)

func _process(delta: float) -> void:
	super._process(delta)
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta)

## Sign boards are physical here, so their lettering never switches off with distance.
func _update_district_label_visibility() -> void:
	pass

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
	var at := Vector2(position.x, position.z)
	if _is_land(at): return GROUND_Y
	return Scenery.SYRUP_Y if Scenery.is_syrup(at) else Scenery.LAWN_Y

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
	_temperature_display.position.y = SAMPLE_AT.y + SAMPLE_RADIUS * _temperature_display.scale.y
	_temperature_needle.rotation.z = 1.0 - float(_temperature)
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
