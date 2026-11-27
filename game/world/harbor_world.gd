extends "res://game/world/park_world.gd"
## Tidal Harbor: a stone and timber quay ring around a tidal lagoon and its lighthouse
## islet. This script owns what the player can do here (walkable land, the tide, the
## free ferry, every interaction point); harbor_scenery builds the place and
## harbor_life animates it.
const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/harbor_props.gd")
const Scenery := preload("res://game/world/harbor_scenery.gd")
const Life := preload("res://game/world/harbor_life.gd")
const BOUNDS := Rect2(-15, -12, 30, 24)
## West quay, east boardwalk, north quay, south boardwalk, lighthouse islet, bridge.
const LAND: Array[Rect2] = [
	Rect2(-15, -12, 6, 24), Rect2(9, -12, 6, 24),
	Rect2(-9, -12, 18, 4), Rect2(-9, 8, 18, 4),
	Rect2(-4, -4, 8, 8), Rect2(-1, -8, 2, 4),
]
const SANDBAR := Rect2(-9, -1.5, 5, 3)
const SHORE_DOCK := Vector3(-12, 0.2, 9)
const LIGHTHOUSE_DOCK := Vector3(-2, 0.2, 2)
const GROUND_Y := 0.2
const LOW_WATER := -0.36
const HIGH_WATER := -0.04
const TIDE_SECONDS := 1.6
## Minigame entries: id, title, interaction point (x, z), stall placement, awning tint
## and rooftop emblem. "N" stalls stand behind the point facing the camera, "D" stalls
## stand diagonally behind it on the east boardwalk, and "" has no stall.
const GAMES := [
	["game-013", "浪間小艇", 12.0, 0.0, "D", "#8fd0c8", "boat"],
	["game-014", "潮汐沙路", 12.0, 5.6, "D", "#f0907a", "flags"],
	["game-015", "燈塔折光", 1.2, -0.6, "", "", ""],
	["game-016", "繩結拖船", 12.0, -4.6, "D", "#f5cd7a", "rope"],
	["game-017", "蟹洞彈珠", -4.0, 10.2, "N", "#f0907a", "crab"],
	["game-018", "船艙配重", 0.0, 10.2, "N", "#8fd0c8", "crates"],
	["game-019", "浮標接力", 4.0, 10.2, "N", "#f5cd7a", "buoy"],
	["game-020", "帆影追逐", -4.0, -10.2, "N", "#8fd0c8", "sail"],
	["game-021", "貝殼聽潮", 0.0, -10.2, "N", "#f0907a", "shell"],
	["game-022", "錨鏈穿礁", 4.0, -10.2, "N", "#f5cd7a", "anchor"],
	["game-023", "海鳥借風", 12.0, -10.2, "N", "#f0907a", "gull"],
	["game-024", "潮鐘合閘", 12.0, 10.2, "D", "#8fd0c8", "bell"],
]
## A stall keeps this far from its interaction point, which leaves 1.25 m clear.
const STALL_REACH := 1.85
var _high_tide := false
var _tide_blend := 0.0
var _kit: Kit
var _scenery: Scenery
var _life: Life

func _build_region_geometry() -> void:
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	_scenery.build()
	_build_entries()
	_life = Life.new(self, _scenery)
	_life.build()
	_kit.finish()
	_apply_tide()
	_life.hold_still()
	current_area = "潮汐碼頭"

func _build_entries() -> void:
	_point("region:welcome", "返回迎賓大道", Vector3(-12, GROUND_Y, 5))
	_point("harbor:tide", "潮汐鐘 · 預覽漲退潮", Vector3(-12, GROUND_Y, -1))
	_point("harbor:ferry:shore", "免費渡船 · 前往燈塔", SHORE_DOCK)
	_point("harbor:ferry:lighthouse", "免費渡船 · 返回岸邊", LIGHTHOUSE_DOCK)
	_point("harbor:info:lighthouse", "燈塔與環形水路", Vector3(0, GROUND_Y, -2))
	var rows := {"north": [], "south": []}
	for index in range(GAMES.size()):
		var game: Array = GAMES[index]
		var at := Vector3(float(game[2]), GROUND_Y, float(game[3]))
		_point(game[0], "%s · 免費遊玩" % game[1], at)
		if game[4] == "": continue
		var diagonal: bool = game[4] == "D"
		var yaw := -PI * 0.25 if diagonal else 0.0
		var stall_at := at - Basis(Vector3.UP, yaw) * Vector3(0, 0, STALL_REACH)
		if not diagonal:
			# Row stalls stand on their own timber bays that reach out over the water.
			stall_at.y += 0.03
			_kit.surface(_scenery.deck()).add(stall_at + Vector3(0, -0.3, -0.15), Vector3(2.5, 0.6, 1.7))
			for side: float in [-1.0, 1.0]:
				_kit.piles().add(Vector3(stall_at.x + side * 1.2, -0.3, stall_at.z - 0.95), Vector3(0.26, 1.2, 0.26))
			rows["north" if stall_at.z < 0.0 else "south"].append(stall_at + Vector3(0, 3.1, -0.5))
		Props.stall(self, _kit, stall_at, yaw, game[1], Color(str(game[5])), game[6], index)
	# Garlands run from sign to sign along the north and south rows.
	for row: Array in rows.values():
		row.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
		for index in range(row.size() - 1):
			var inset: Vector3 = (row[index + 1] - row[index]).normalized() * 0.95
			_kit.bunting(row[index] + inset, row[index + 1] - inset, Scenery.PENNANT_COLORS, 0.3)

func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	if _scenery != null:
		_scenery.apply_time_of_day(lamp_energy_for_phase, environment.background_color)

func _process(delta: float) -> void:
	super._process(delta)
	var target := 1.0 if _high_tide else 0.0
	if not is_equal_approx(_tide_blend, target):
		_tide_blend = target if reduced_motion else move_toward(_tide_blend, target, delta / TIDE_SECONDS)
		_apply_tide()
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta)

func _apply_tide() -> void:
	var eased := smoothstep(0.0, 1.0, _tide_blend)
	var water_y := lerpf(LOW_WATER, HIGH_WATER, eased)
	_scenery.apply_tide(eased, water_y)
	_life.set_water_level(water_y)

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
	# The islet out to sea is ground too, though nobody can walk to it.
	var at := Vector2(position.x, position.z)
	return GROUND_Y if _is_land(at) or Scenery.ISLET.has_point(at) else -0.4

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
	if _scenery != null and is_instance_valid(_scenery.sandbar_body):
		_scenery.sandbar_body.collision_layer = 0 if high else 1
		_scenery.tide_label.text = "漲潮 · 沙洲封閉" if high else "退潮 · 沙洲可通行"
		_life.ring_bell()

func is_high_tide() -> bool:
	return _high_tide

func take_ferry(point_id: String) -> bool:
	if not is_instance_valid(player): return false
	match point_id:
		"harbor:ferry:shore":
			_relocate(LIGHTHOUSE_DOCK)
			_life.moor_ferry(1)
		"harbor:ferry:lighthouse":
			_relocate(SHORE_DOCK)
			_life.moor_ferry(0)
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
