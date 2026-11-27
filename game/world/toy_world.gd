extends "res://game/world/park_world.gd"
## Clockwork Toy Town: a paved yard of block houses, a railway and a clock tower on
## the hill north of the welcome plaza. This script owns what the player can do here
## (walkable areas, the train controls, the story portrait, every interaction
## point); toy_scenery builds the place, toy_life animates it and toy_train runs the
## railway.

## Notes for the floor piano and the jack-in-the-box; main plays them like the coast's toys.
signal note_requested(note: int)

const Kit := preload("res://game/world/scenery_kit.gd")
const Scenery := preload("res://game/world/toy_scenery.gd")
const Life := preload("res://game/world/toy_life.gd")
const TrainScript := preload("res://game/world/toy_train.gd")
const RegionalVisit := preload("res://game/story/regional_visit.gd")
const ArcadeStands := preload("res://game/world/arcade_stands.gd")
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
## The status board hangs from the signal gantry over the two branches.
const STATION_STATUS_AT := Vector3(8.1, GROUND_Y + 1.43, -3.35)
const STATION_STATUS_WIDTH := 2.64
## The railway keeps its own small units; the yard shows it at this size, with the
## sleepers bedded in the ballast.
const RAIL_ORIGIN := Vector3(8.1, 0.19, -2.64)
const RAIL_SCALE := 1.3
const RAIL_TABLE := Rect2(4.75, -6.2, 6.8, 8.1)
const AREAS: Array[Dictionary] = [
	{"id": "entry", "label": "玩具城入口", "rect": Rect2(-4.35, 4.7, 8.7, 4.8), "tile": 4, "tint": Color("#f0e2c6")},
	{"id": "blocks", "label": "積木街", "rect": Rect2(-12.1, -3.8, 7.75, 12.0), "tile": 4, "tint": Color("#f3d3bd")},
	{"id": "tower", "label": "發條鐘樓", "rect": Rect2(-4.35, -10.8, 8.7, 15.5), "tile": 0, "tint": Color(1.5, 1.42, 1.3)},
	{"id": "station", "label": "車站岔道", "rect": Rect2(4.35, -3.8, 7.75, 12.0), "tile": 4, "tint": Color("#d4e6d6")},
	{"id": "repair", "label": "維修台", "rect": Rect2(-10.9, -10.8, 6.55, 7.0), "tile": 1, "tint": Color("#f2dfc0")},
]
const STATION_TEAL := Color("#567f77")

var _train: TrainScript
var _kit: Kit
var _scenery: Scenery
var _life: Life
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
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	await _scenery.build()
	await build_pause()
	_station_label = _scenery.station_label
	_control_lever = _scenery.lever
	_clock_hour = _scenery.clock_hour
	_clock_minute = _scenery.clock_minute
	_train = TrainScript.new()
	_train.name = "ToyRailDemonstration"
	_train.position = RAIL_ORIGIN
	_train.scale = Vector3.ONE * RAIL_SCALE
	add_child(_train)
	_tracks = _train.map_tracks()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("toy:blocks", "積木街 · 看街屋", BLOCKS)
	_point("toy:switch", "岔道開關 · 換線", SWITCH)
	_point("toy:train", "列車控制 · 走停／逐站", TRAIN)
	_point("toy:repair", "維修台 · 重置列車", REPAIR)
	_point("toy:tower", "發條鐘樓 · 上發條看時間", TOWER)
	_npc(STORY_HOST, STATION_TEAL, RegionalVisit.host_name(RegionalVisit.TOY))
	_point(RegionalVisit.TOY_POINT, "玩具城迎賓 · 和阿浪合照", STORY_POINT)
	ArcadeStands.build(self, "toy")
	_life = Life.new(self, _scenery)
	_life.build()
	await build_pause()
	_kit.finish()
	_sync_station_controls()
	current_area = _area_at_position(ENTRY)


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
	_story_photo_camera.look_at(to_global(center))
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
	guest.global_position = to_global(STORY_GUEST) + Vector3.UP * sprite_ground_anchor_y(STORY_GUEST.y, STORY_GUEST.y,
		0.0, AvatarRenderer.FEET_BASELINE, AvatarRenderer.CANVAS_SIZE.y, guest.pixel_size, camera_up)
	_set_living_sprite_material(guest, 1, 0.0, 0.0, 0, false)
	if is_instance_valid(avatar_contact_shadow):
		var contact := avatar_contact_shadow.duplicate(0) as MeshInstance3D
		contact.top_level = true
		_story_photo_camera.add_child(contact)
		contact.global_transform = Transform3D(avatar_contact_shadow.global_basis, to_global(STORY_GUEST) + Vector3.UP * 0.008)

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
	var at := Vector2(position.x, position.z)
	return GROUND_Y if _on_yard(at) else Scenery.lawn_height(at)


func _stands_on(point: Vector2) -> bool:
	return _on_yard(point) or _open_ground(point)


func _safe_footing(position: Vector3) -> bool:
	var at := Vector2(position.x, position.z)
	return (_stands_on(at + Vector2(-0.30, -0.30))
		and _stands_on(at + Vector2(0.30, -0.30))
		and _stands_on(at + Vector2(-0.30, 0.30))
		and _stands_on(at + Vector2(0.30, 0.30)))


func is_walkable(position: Vector3) -> bool:
	return _safe_footing(position)


func _constrain_player(previous_position: Vector3) -> bool:
	if player_spot().y < -1.0 or not _safe_footing(previous_position):
		return _reset_to_entry()
	if not _safe_footing(player_spot()):
		_set_player_spot(previous_position)
		player.velocity = Vector3.ZERO
	return false


func _reset_to_entry() -> bool:
	place_player(ENTRY)
	_host().settle_avatar()
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


## Winding the tower's key reads the clock and, unless motion is reduced, sets
## every gear in town racing for a few seconds.
func wind_tower() -> String:
	if reduced_motion:
		return "發條鐘樓 · 現在是 " + tower_clock()
	_life.wind()
	return "發條上緊了 · 現在是 " + tower_clock()


func _sync_station_controls() -> void:
	_control_lever.rotation.z = -0.44 if _train.branch == 0 else 0.44
	# The raised arm shows which branch is set; the left arm reaches the other way.
	for index in range(_scenery.signals.size()):
		_scenery.signals[index].rotation = Vector3(0, PI if index == 0 else 0.0, 0.75 if index == _train.branch else 0.0)
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
	if blocked or is_instance_valid(_story_photo_camera):
		return
	if _train.advance(delta):
		_sync_station_controls()
	_life.step_piano()
	if reduced_motion:
		_life.hold_still()
	else:
		_life.animate(delta)
		_train.animate(delta)


func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	if is_instance_valid(_train):
		_train.set_reduced_motion(reduced_motion)
		_sync_station_controls()


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	if _scenery == null:
		return
	_scenery.apply_time_of_day(lamp_energy_for_phase)
	var parts := tower_clock().split(":")
	var hour := float(parts[0].to_int()) + float(parts[1].to_int()) / 60.0
	_clock_hour.rotation.z = -TAU * fposmod(hour, 12.0) / 12.0
	_clock_minute.rotation.z = -TAU * fposmod(hour, 1.0)


## Toy-box air: crisper colour, a clearer sky by day and a warm nursery fill.
func _air(phase: String, island: Dictionary) -> Dictionary:
	var day := phase in ["dawn", "noon"]
	return {
		"sky": (island.sky as Color).lerp(Color("#a8d8f4"), 0.22 if day else 0.0), "fog": (island.fog as Color).lerp(Color("#f4e6c6"), 0.2 if day else 0.05),
		"ambient": (island.ambient as Color).lerp(Color("#fff0d2"), 0.22), "saturation": 1.18,
	}

func map_snapshot() -> Dictionary:
	var land: Array[Rect2] = []
	var areas: Array[Dictionary] = []
	for area in AREAS:
		land.append(area.rect)
		areas.append({"id": area.id, "label": area.label, "rect": area.rect})
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var at: Vector3 = player_spot() if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": land, "areas": areas, "points": stops, "player": at, "area": _area_at_position(at),
		"region": "toy", "tracks": _tracks.duplicate(true), "rail_table": RAIL_TABLE, "train": train_state()}
