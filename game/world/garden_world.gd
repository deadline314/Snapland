extends "res://game/world/park_world.gd"

## Moss-light greenhouse: an iron-and-glass house in a wooded clearing. This script
## owns what the player can do here (the floor plan, the louvred sunlight, safe
## footing, the regional portrait, every interaction point); garden_scenery builds
## the place and garden_life animates it.
const Kit = preload("res://game/world/scenery_kit.gd")
const Scenery = preload("res://game/world/garden_scenery.gd")
const Life = preload("res://game/world/garden_life.gd")
const Louvers = preload("res://game/world/garden_louvers.gd")
const RegionalVisit = preload("res://game/story/regional_visit.gd")
const ArcadeStands = preload("res://game/world/arcade_stands.gd")
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
const IVORY := Color("#c1ad88")
const FOOTPRINT: Array[Vector2] = [Vector2(-0.30, -0.30), Vector2(-0.30, 0.30), Vector2(0.30, -0.30), Vector2(0.30, 0.30)]

var _kit: Kit
var _scenery: Scenery
var _life: Life
var _louvers: Louvers
var _water: ShaderMaterial
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
	# One glowing surface for night buds, moss and mushrooms; it brightens after dusk.
	_buds = StandardMaterial3D.new()
	_buds.vertex_color_use_as_albedo = true
	_buds.roughness = 0.7
	_buds.emission_enabled = true
	_buds.emission = Color("#4fe08c")
	material_cache["garden:night-glow"] = _buds
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	_build_floors()
	await _scenery.build()
	await build_pause()
	_water = _scenery.wetland_water
	_foyer_sign = [_scenery.doorway]
	_louvers = Louvers.new()
	_louvers.name = "GardenSunRack"
	add_child(_louvers)
	_bud_pool = OmniLight3D.new()
	_bud_pool.name = "GardenBudPool"
	_bud_pool.position = Vector3(0.26, 2.04, -10.53)
	_bud_pool.light_color = Color("#bedfab")
	_bud_pool.omni_range = 5.25
	_bud_pool.shadow_enabled = false
	add_child(_bud_pool)
	_life = Life.new(self, _scenery)
	_life.build()
	await build_pause()
	_kit.finish()
	_coordinate_lighting()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("garden:louvers", "日照窗 · 轉動百葉", SWITCH)
	_point("garden:wetland", "濕地床 · 靠木棧道走", WETLAND)
	_point("garden:vine", "藤蔓層 · 看葉臺", VINE)
	_point("garden:buds", "夜芽庭 · 看夜芽", BUDS)
	_npc(STORY_HOST, IRON, RegionalVisit.host_name(RegionalVisit.GARDEN))
	_point(RegionalVisit.GARDEN_POINT, "溫室迎賓 · 和票票合照", STORY_POINT)
	ArcadeStands.build(self, "garden")
	current_area = _area_at_position(ENTRY)


## The walkable floors keep their plan; each room has its own stone and moss.
func _build_floors() -> void:
	_floor(SUN_FLOOR, 0.31, "GardenSunFloor", _scenery.surface("sun-floor", Color("#b59a68"), Scenery.Style.PAVERS, 0.35, 0.45))
	_floor(VINE_FLOOR, 0.31, "GardenVineFloor", _scenery.surface("vine-floor", Color("#7d8d74"), Scenery.Style.PAVERS, 0.6, 0.8, Vector2(0.9, 0.9)))
	_floor(BUD_COURT, 0.31, "GardenBudFloor", _scenery.surface("bud-floor", Color("#6f807c"), Scenery.Style.PAVERS, 0.55, 0.9, Vector2(1.1, 0.7)))
	var bridge := _scenery.surface("bridge-floor", Color("#868f78"), Scenery.Style.PAVERS, 0.85, 0.8, Vector2(0.8, 0.8))
	_floor(WEST_SOUTH, 0.31, "GardenSouthBridge", bridge)
	_floor(WEST_NORTH, 0.31, "GardenNorthBridge", bridge)
	var boards := _scenery.surface("boards", Color("#94713f"), Scenery.Style.BOARDS, 0.0, 0.6, Vector2(1.92, 0.31))
	_floor(BOARDWALK, 0.25, "GardenWetlandBoardwalk", boards)
	var deck := _scenery.surface("deck", Color("#a17f4c"), Scenery.Style.BOARDS, 0.0, 0.7, Vector2(1.92, 0.31))
	_slope(RAMP, GROUND_Y, LOWER_Y, "GardenLeafRamp", deck)
	_floor(LOWER, 0.40, "GardenLowerLeafDeck", deck, LOWER_Y)
	_slope(LINK, LOWER_Y, UPPER_Y, "GardenUpperLink", deck)
	_floor(UPPER, 0.44, "GardenUpperLeafDeck", deck, UPPER_Y)
	# Brick piers carry the two leaf decks; a brass nosing marks each edge.
	for rect: Rect2 in [LOWER, UPPER]:
		var height := LOWER_Y if rect == LOWER else UPPER_Y
		var center := rect.get_center()
		for offset: float in [-1.4, 1.4]:
			_kit.surface(_scenery.brick()).add(Vector3(center.x + offset, (height - 0.4 + GROUND_Y) * 0.5, center.y), Vector3(0.5, height - 0.4 - GROUND_Y, rect.size.y * 0.8))
		for x: float in [rect.position.x + 0.07, rect.end.x - 0.07]:
			_kit.detail.box(Vector3(x, height + 0.02, center.y), Vector3(0.1, 0.05, rect.size.y), Scenery.Props.BRASS)
	_kit.detail.box(Vector3(7.20, UPPER_Y + 0.02, UPPER.position.y + 0.06), Vector3(4.09, 0.05, 0.12), Scenery.Props.BRASS)


func _floor(rect: Rect2, depth: float, label: String, finish: Material, top := GROUND_Y) -> void:
	var center := rect.get_center()
	var floor_mesh := _box(Vector3(center.x, top - depth * 0.5, center.y), Vector3(rect.size.x, depth, rect.size.y), IVORY, true)
	floor_mesh.name = label
	_set_registered_surface(floor_mesh, finish)


func _slope(rect: Rect2, bottom: float, top: float, label: String, finish: Material) -> void:
	var rise := top - bottom
	var rotation := Basis(Vector3.RIGHT, atan2(rise, rect.size.y))
	var center := rect.get_center()
	var surface := Vector3(center.x, (bottom + top) * 0.5, center.y)
	var thickness := 0.30
	var slope := _box(surface - rotation.y * thickness * 0.5,
		Vector3(rect.size.x, thickness, Vector2(rise, rect.size.y).length()), IVORY, true)
	slope.name = label
	slope.basis = rotation
	_set_registered_surface(slope, finish)


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
	_story_camera.look_at(to_global(center))
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
	# The portrait camera stands just outside the door, so the doorway steps aside.
	for piece in _scenery.story_front:
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
	guest.global_position = to_global(STORY_GUEST) + Vector3.UP * sprite_ground_anchor_y(STORY_GUEST.y, STORY_GUEST.y,
		0.0, AvatarRenderer.FEET_BASELINE, AvatarRenderer.CANVAS_SIZE.y, guest.pixel_size, _story_camera.global_basis.y.y)
	_set_living_sprite_material(guest, 1, 0.0, 0.0, 0, false)
	if is_instance_valid(avatar_contact_shadow):
		var contact := avatar_contact_shadow.duplicate(0) as MeshInstance3D
		contact.top_level = true
		_story_camera.add_child(contact)
		contact.global_transform = Transform3D(avatar_contact_shadow.global_basis, to_global(STORY_GUEST) + Vector3.UP * 0.008)


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
	return _open_ground(point)


func is_walkable(position: Vector3) -> bool:
	var at := Vector2(position.x, position.z)
	for offset in FOOTPRINT:
		if not _on_floor_plan(at + offset):
			return false
	return true


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
	var at := Vector2(position.x, position.z)
	return _height_at(at) if Scenery.HOUSE.has_point(at) else Scenery.TERRAIN_Y


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
	var current := player_spot()
	var support := ground_surface_y(current)
	if not _safe_standing(previous_position) or not _safe_standing(current) or previous_position.y > support + 0.40:
		return _restore_footing()
	if _can_record_footing(current, support):
		_last_safe = current
	return false


func _restore_footing() -> bool:
	_recoveries += 1
	place_player(_last_safe)
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
	var posing := is_instance_valid(_story_camera)
	if not blocked and not posing and _louvers.moving():
		_louvers.advance(delta)
	if reduced_motion:
		_life.hold_still()
	elif not blocked and not posing:
		_life.animate(delta)


## Frogs on the wetland bed, for the map and for checks: how many, and whether one is on its pad.
func frog_count() -> int:
	return Life.FROGS.size()


func frog_is_out(index: int) -> bool:
	return _life.frog_is_out(index)


func frog_home(index: int) -> Vector3:
	return _life.frog_home(index)


func apply_settings(settings: Dictionary) -> void:
	super.apply_settings(settings)
	if not is_instance_valid(_louvers):
		return
	if reduced_motion and louver_is_moving():
		_louvers.settle()
	_louvers.set_motion(not reduced_motion)
	for key: String in ["garden:wetland-water", "garden:pond-water", "garden:rill-water"]:
		material_cache[key].set_shader_parameter("reduced_motion", reduced_motion)


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	_coordinate_lighting()


const HAZE := {"dawn": Color("#93a48c"), "noon": Color("#849e8a"), "dusk": Color("#5f6c66"), "night": Color("#22363f")}
const AMBIENT := {"dawn": Color("#f1ddc6"), "noon": Color("#e6ead2"), "dusk": Color("#d9b8a2"), "night": Color("#8a9aa8")}
const AMBIENT_ENERGY := {"dawn": 0.5, "noon": 0.52, "dusk": 0.48, "night": 0.38}

## The greenhouse keeps the island's sun but filters it: greener air, a softer key
## light, and nights bright enough to read by the glow of the plants.
func _air(phase: String, island: Dictionary) -> Dictionary:
	return {
		"sky": HAZE[phase], "fog": HAZE[phase], "ambient": AMBIENT[phase], "ambient_energy": AMBIENT_ENERGY[phase],
		"sun": (island.sun as Color).lerp(Color("#dfebce"), 0.35), "sun_energy": minf(float(island.sun_energy), 1.05),
	}


## Louvre light, night buds and lanterns follow the time of day.
func _coordinate_lighting() -> void:
	var evening := active_time_phase in ["dusk", "night"]
	if not is_instance_valid(_louvers):
		return
	_louvers.set_light_gain(0.50 if evening else 0.68)
	_louvers.set_light_color({"dawn": Color("#ffd9a0"), "noon": Color("#ffd161"), "dusk": Color("#ffb060"), "night": Color("#b4d2ff")}[active_time_phase])
	_buds.emission_energy_multiplier = {"dawn": 0.2, "noon": 0.1, "dusk": 0.9, "night": 2.0}[active_time_phase]
	_bud_pool.light_energy = 0.68 if evening else 0.26
	_scenery.apply_time_of_day(active_time_phase, lamp_energy_for_phase)


## The bud pool burns whatever the hour, so on the island it holds one of the
## lamp budget's places while the greenhouse is awake.
func steady_light_count() -> int:
	return 1 if is_instance_valid(_bud_pool) and is_visible_in_tree() else 0


func map_snapshot() -> Dictionary:
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var at := player_spot() if is_instance_valid(player) else ENTRY
	var lit := illuminated_bed()
	return {"region": "garden", "bounds": BOUNDS, "land": LAND.duplicate(), "areas": AREAS.duplicate(true),
		"points": stops, "player": at, "area": _area_at_position(at), "water": WETLAND_WATER, "boardwalk": BOARDWALK,
		"ramp": RAMP, "terraces": [LOWER, UPPER], "upper_link": LINK, "beds": _louvers.bed_centers(),
		"light_center": sun_patch_center(), "lit_bed": lit, "light_label": Louvers.LABELS[lit] if lit >= 0 else "光斑移動中"}
