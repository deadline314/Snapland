extends "res://game/world/park_world.gd"
## Neon night market: a lantern-lit street quarter under big trees, always in dusk
## or night light with rain in the air. This script owns what the player can do here
## (walkable land, the covered alley, the roof terrace, opening hours and every
## interaction point); nightmarket_scenery builds the place and nightmarket_life
## animates it.

const RegionalVisit = preload("res://game/story/regional_visit.gd")
const Atmosphere = preload("res://game/world/nightmarket_atmosphere.gd")
const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/nightmarket_props.gd")
const Scenery := preload("res://game/world/nightmarket_scenery.gd")
const Life := preload("res://game/world/nightmarket_life.gd")
const BOUNDS := Rect2(-12, -14.1, 24, 23.6)
const GROUND_Y := 0.20
const PANCAKE_ENTRY := Vector3(-8.82, GROUND_Y, -4.38)
const BANNER_ENTRY := Vector3(6.05, GROUND_Y, -4.38)
const SCENT_ENTRY := Vector3(-5.65, GROUND_Y, -4.35)
const COIN_ENTRY := Vector3(-9.15, GROUND_Y, -2.18)
const ROOF_Y := 0.92
const LANTERN_ENTRY := Vector3(4.12, ROOF_Y, -10.58)
const UMBRELLA_ENTRY := Vector3(-3.95, ROOF_Y, -12.44)
const SUGAR_LANTERN_ENTRY := Vector3(4.35, ROOF_Y, -12.95)
const SOUP_ENTRY := Vector3(-7.18, GROUND_Y, 6.52)
const CART_PASS_ENTRY := Vector3(8.65, GROUND_Y, 6.46)
const STALL_LOADOUT_ENTRY := Vector3(10.62, GROUND_Y, 8.02)
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
const CORAL_NEON := Color("#ff937a")
const MINT_NEON := Color("#7df0db")
const PAPER_LIGHT := Color("#fff0cd")
const TERRACE_Y := Scenery.TERRACE_Y
const WEST := PI * 0.5
const EAST := -PI * 0.5
## Game stands, in map order: id, label, entry point, emblem, stand position, yaw
## (0 faces the camera), stand kind, awning stripe, sign kind, sign position and
## sign accent. A "tall" sign stands on a pole at its position, so it hides little of
## the lane behind it; a "roof" board rides on struts above the stand's awning and a
## "wall" board is fixed flat to whatever is behind it.
const STANDS := [
	["game-037", "雨棚快遞 · 撐傘送熱餐", Vector3(0, GROUND_Y, 2.85), "umbrella", Vector3(2.77, TERRACE_Y, 2.87), EAST, "parcels", Color(1.25, 0.5, 0.42), "tall", Vector3(3.3, TERRACE_Y, 1.8), CORAL_NEON],
	["game-038", "炭火串燒 · 翻面收火", Vector3(9.15, GROUND_Y, 3.27), "skewer", Vector3(10.58, GROUND_Y, 3.28), EAST, "grill", Color(1.3, 0.95, 0.45), "tall", Vector3(10.9, GROUND_Y, 1.95), Color("#ffd28e")],
	["game-039", "燈籠繩渡 · 屋頂掛燈", LANTERN_ENTRY, "lantern", Vector3(5.13, ROOF_Y, -10.41), 0.0, "rope", Color.WHITE, "tall", Vector3(5.2, ROOF_Y, -11.55), Color("#f7bd8a")],
	["game-044", "紙傘轉燈 · 西側屋頂", UMBRELLA_ENTRY, "parasol", Vector3(-4.16, ROOF_Y, -13.50), 0.0, "parasol", Color.WHITE, "tall", Vector3(-5.15, ROOF_Y, -13.6), PAPER_LIGHT],
	["game-047", "糖畫牽線 · 東側屋頂糖燈", SUGAR_LANTERN_ENTRY, "sugar", Vector3(4.26, ROOF_Y, -13.74), 0.0, "sugar", Color(1.3, 0.95, 0.45), "roof", Vector3(4.26, ROOF_Y + 2.85, -14.14), PAPER_LIGHT],
	["game-040", "銅板借彈 · 西街桌檯", COIN_ENTRY, "coin", Vector3(-10.66, GROUND_Y, -2.30), WEST, "coins", Color(0.95, 0.6, 1.3), "tall", Vector3(-10.9, GROUND_Y, -3.6), Color("#f4c38b")],
	["game-041", "香氣尋攤 · 北街聞香亭", SCENT_ENTRY, "scent", Vector3(-5.65, GROUND_Y, -5.45), 0.0, "jars", Color(0.55, 1.15, 1.0), "roof", Vector3(-5.65, 3.05, -5.85), PAPER_LIGHT],
	["game-042", "招幌避碰 · 北街推車", BANNER_ENTRY, "banner", Vector3(6.06, GROUND_Y, -5.40), 0.0, "banner", Color.WHITE, "wall", Vector3(6.06, 3.0, -6.2), PAPER_LIGHT],
	["game-043", "煎餅畫圓 · 西北煎台", PANCAKE_ENTRY, "pancake", Vector3(-8.82, GROUND_Y, -5.44), 0.0, "griddle", Color(1.25, 0.5, 0.42), "roof", Vector3(-8.82, 3.05, -5.84), PAPER_LIGHT],
	["game-045", "湯碗擺渡 · 西南湯攤", SOUP_ENTRY, "soup", SOUP_ENTRY + Vector3(-0.15, 0, -1.14), 0.0, "pot", Color(1.3, 0.95, 0.45), "tall", Vector3(-5.85, GROUND_Y, 4.95), PAPER_LIGHT],
	["game-046", "攤車會車 · 東南卸貨巷", CART_PASS_ENTRY, "cart", Vector3(9.96, GROUND_Y, 5.46), 0.0, "cargo", Color.WHITE, "tall", Vector3(11.45, GROUND_Y, 5.15), PAPER_LIGHT],
	["game-048", "收攤套疊 · 東南收攤台", STALL_LOADOUT_ENTRY, "stack", STALL_LOADOUT_ENTRY + Vector3(0.08, 0, 0.88), 0.0, "nest", Color.WHITE, "wall", Vector3(13.5, 1.12, 10.05), PAPER_LIGHT],
]
## Signboard text for each stand (the labels players already know).
const STAND_SIGNS := {
	"game-037": "雨棚快遞", "game-038": "炭火串燒", "game-039": "燈籠繩渡", "game-044": "紙傘轉燈", "game-047": "糖畫牽線", "game-040": "銅板借彈",
	"game-041": "北街聞香", "game-042": "招幌推車", "game-043": "西北煎台", "game-045": "西南湯攤", "game-046": "東南卸貨巷", "game-048": "收攤套疊",
}
## The lanterns here stay lit all day; the district is always in dusk or night light.
const LAMP_LEVELS := {"dawn": 2.4, "noon": 2.2, "dusk": 3.2, "night": 3.8}
## Under the canopy the trees are dark shapes whatever the hour.
const FOLIAGE_GRADE := {"dawn": Color(0.72, 0.78, 0.95), "noon": Color(0.78, 0.84, 0.98), "dusk": Color(0.7, 0.72, 0.95), "night": Color(0.6, 0.7, 0.98)}
var _operating := true
var _status_label: Label3D
var _rain: Array[CPUParticles3D] = []
var _atmosphere: Node3D
var _kit: Kit
var _scenery: Scenery
var _life: Life
var _story_photo_camera: Camera3D
var _story_photo_origin: Vector3
var _story_photo_facing := "front"
var _story_name_label: Label3D
var _story_host_sprite: Sprite3D
var _story_rest_pose: Texture2D
var _story_photo_pose: Texture2D

func _build_region_geometry() -> void:
	_build_atmosphere()
	_build_terrain()
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	await _scenery.build()
	await build_pause()
	_build_entries()
	_life = Life.new(self, _scenery)
	_scenery.finish()
	await build_pause()
	_kit.finish()
	_add_rain()
	_sync_operating()
	_life.hold_still()
	current_area = _area_at_position(ENTRY)

func _build_atmosphere() -> void:
	_atmosphere = Atmosphere.new()
	_atmosphere.name = "NightmarketAtmosphere"
	add_child(_atmosphere)
	var image := load(SKYLINE) as Texture2D if ResourceLoader.exists(SKYLINE) else null
	_atmosphere.setup(image, coastal_atlas, AWNING)

## Walkable ground with collision: the wet streets, the ramp and the roof terrace.
func _build_terrain() -> void:
	for index in FLOOR_COLORS.size():
		var area := LAND[index]
		var center := area.get_center()
		var floor_mesh := _box(Vector3(center.x, GROUND_Y - 0.24, center.y), Vector3(area.size.x, 0.48, area.size.y), FLOOR_COLORS[index], true)
		floor_mesh.name = "MarketWalk%d" % index
		_set_registered_surface(floor_mesh, _atmosphere.paving_material())
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

func _build_entries() -> void:
	var props := _scenery.props
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("nightmarket:trade", "攤街燈牌 · 切換營業", Vector3(-4.0, GROUND_Y, 6.65))
	_point("nightmarket:shelter", "雨棚巷 · 看遮雨方式", Vector3(0, GROUND_Y, 0.7))
	_point("nightmarket:rooftop", "屋頂餐桌 · 看夜市", Vector3(0, ROOF_Y, -11.65))
	_point("nightmarket:signs", "招牌維修台 · 看營業燈", Vector3(9.6, GROUND_Y, -0.2))
	_point("nightmarket:reset", "安全返回夜市入口", Vector3(-9.6, GROUND_Y, 1.0))
	for index in range(STANDS.size()):
		var stand: Array = STANDS[index]
		_point(stand[0], stand[1], stand[2])
		_build_stand(stand, index)
	_status_label = props.tall_sign(market_status(), Vector3(-5.2, TERRACE_Y, 4.55), MINT_NEON)
	props.tall_sign("雨棚巷", Vector3(-2.32, GROUND_Y, 4.9), MINT_NEON, "", 1.6)
	_build_sign_bench()
	_npc(STORY_HOST, CORAL_NEON, "阿浪")
	props.sign("夜市迎賓", STORY_HOST + Vector3(0, 2.92, -0.75), CORAL_NEON)
	_point(RegionalVisit.NIGHTMARKET_POINT, "夜市迎賓 · 和阿浪合照", STORY_POINT)
	props.fit_stacked_labels()

func _build_stand(stand: Array, variation: int) -> void:
	var props := _scenery.props
	var at: Vector3 = stand[4]
	var frame := Transform3D(Basis(Vector3.UP, float(stand[5])), at)
	var kind := str(stand[6])
	var board: Vector3 = stand[9]
	match kind:
		"rope": _build_lantern_rope(at)
		"parasol": _build_parasol_stand(at)
		"banner": _build_banner_cart(frame)
		"cargo", "nest": props.cart(frame, stand[7], kind, variation, false)
		_: props.cart(frame, stand[7], kind, variation)
	if stand[8] == "tall":
		props.tall_sign(STAND_SIGNS[stand[0]], board, stand[10], str(stand[3]))
		return
	props.sign(STAND_SIGNS[stand[0]], board, stand[10], str(stand[3]), board.y)
	if stand[8] == "roof":
		var foot := at.y + 2.1
		for side: float in [-1.0, 1.0]:
			_kit.detail.box(Vector3(at.x + side * 0.45, (board.y - 0.36 + foot) * 0.5, board.z - 0.06), Vector3(0.05, board.y - 0.36 - foot, 0.05), Props.IRON)

## Two posts and a rope of paper lanterns to ferry across the terrace.
func _build_lantern_rope(at: Vector3) -> void:
	var props := _scenery.props
	_kit.detail.box(at + Vector3(0, 0.08, -0.08), Vector3(0.5, 0.16, 2.1), Props.PLUM)
	for z: float in [-0.86, 0.69]:
		_kit.piles().add(at + Vector3(0, 1.2, z), Vector3(0.13, 2.4, 0.13))
		_kit.detail.box(at + Vector3(0, 2.44, z), Vector3(0.22, 0.1, 0.22), Props.BRASS)
	props.wire(at + Vector3(0, 2.36, -0.86), at + Vector3(0, 2.36, 0.69), 0.14, Color("#c9b58a"))
	for hung in range(3):
		props.lantern(at + Vector3(0, 2.26, -0.5 + 0.43 * float(hung)), Props.LANTERN_COLORS[hung], 0.62)

## A large oil-paper umbrella turns slowly on its stand.
func _build_parasol_stand(at: Vector3) -> void:
	_kit.detail.tube(at + Vector3(0, 0.18, 0), 0.44, 0.38, 0.36, Props.PLUM, 10)
	_kit.detail.tube(at + Vector3(0, 1.1, 0), 0.05, 0.05, 1.6, Props.BRASS, 6)
	var spinner := _mesh(Props.parasol_mesh(Color("#ffb09a"), PAPER_LIGHT), at + Vector3(0, 2.05, 0), _vertex_color_material("scenery-detail"))
	spinner.scale = Vector3.ONE * 1.6
	spinner.name = "MarketParasol"
	_scenery.parasol_spinner = spinner
	_scenery.props.neon.tube(at + Vector3(0.72, 0.92, 0.0), 0.14, 0.14, 0.28, Props.AMBER, 8)
	_kit.detail.tube(at + Vector3(0.72, 0.4, 0.0), 0.04, 0.04, 0.8, Props.IRON, 6)

## Hand cart carrying a tall cloth banner that stirs in the air.
func _build_banner_cart(frame: Transform3D) -> void:
	var detail := _kit.detail
	_scenery.props.cart(frame, Color.WHITE, "", 1, false)
	detail.frame = frame
	detail.box(Vector3(-0.3, 2.1, 0), Vector3(0.08, 2.4, 0.08), Props.DARK_WOOD)
	detail.box(Vector3(0.12, 3.24, 0), Vector3(1.0, 0.06, 0.06), Props.DARK_WOOD)
	detail.frame = Transform3D.IDENTITY
	var banners := _kit.batch("banners", Kit.cloth_mesh(Vector2(0.86, 1.7), 4, 6, true), _kit.cloth_material("banner", 0.07))
	banners.add(frame * Vector3(-0.24, 3.2, 0.02), Vector3.ONE, frame.basis, Color("#b0607f"))

## The sign repair bench: spare tubes, a ladder and one sign that will not stay lit.
func _build_sign_bench() -> void:
	var props := _scenery.props
	var detail := _kit.detail
	var at := Vector3(10.9, GROUND_Y, -1.45)
	_kit.surface(props.wood(Color("#8d7a8a"))).add(at + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.7))
	_kit.surface(props.wood(Color("#d9b9a6"))).add(at + Vector3(0, 0.93, 0), Vector3(1.72, 0.06, 0.8))
	detail.box(at + Vector3(-0.45, 1.05, 0.05), Vector3(0.4, 0.2, 0.26), Color("#b5484a"))
	for tube in range(3):
		props.neon.box(at + Vector3(0.1 + 0.2 * float(tube), 1.0, 0.1 - 0.12 * float(tube)), Vector3(0.05, 0.05, 0.6), Props.buzzing(Props.NEON_COLORS[tube + 1], float(tube)), Basis(Vector3.UP, 0.3 * float(tube)))
	for rail: float in [-0.22, 0.22]:
		detail.box(at + Vector3(0.95 + rail, 1.1, -0.2), Vector3(0.05, 2.3, 0.05), Props.BAMBOO, Basis(Vector3.RIGHT, -0.2))
	for rung in range(5):
		detail.box(at + Vector3(0.95, 0.35 + 0.4 * float(rung), -0.02 - 0.08 * float(rung)), Vector3(0.44, 0.04, 0.04), Props.BAMBOO)
	props.tall_sign("招牌維修台", Vector3(11.7, GROUND_Y, -2.0), CORAL_NEON)
	_kit.blocker(at + Vector3(0, 0.95, 0), Vector3(1.6, 1.9, 0.7))

func begin_story_photo() -> bool:
	if is_instance_valid(_story_photo_camera) or not is_instance_valid(player):
		return false
	var actor := _npc_record_for_role("announcer")
	if actor.is_empty():
		return false
	var host := _host()
	_story_photo_origin = player_spot()
	_story_photo_facing = host.facing
	_set_story_host_pose(_story_photo_pose)
	_story_name_label = actor.get("name_label") as Label3D
	if is_instance_valid(_story_name_label):
		_story_name_label.hide()
	place_player(STORY_POINT)
	host.facing = "front"
	host.avatar_action = ""
	host.avatar_action_remaining = 0.0
	host.avatar_action_elapsed = 0.0
	host._refresh_avatar_texture(0)
	var center := STORY_POINT.lerp(STORY_HOST, 0.5) + Vector3(0, 1.45, 0)
	_story_photo_camera = Camera3D.new()
	_story_photo_camera.name = "NightmarketGroupPhotoCamera"
	_story_photo_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_story_photo_camera.size = 6.4
	_story_photo_camera.far = camera.far
	_story_photo_camera.position = center + Vector3(-1.70, 3.05, 9.0)
	add_child(_story_photo_camera)
	_story_photo_camera.look_at(to_global(center))
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
	place_player(_story_photo_origin)
	_host().facing = _story_photo_facing
	_host()._refresh_avatar_texture(0)

func _interaction_markers_allowed() -> bool:
	return not is_instance_valid(_story_photo_camera)

func _add_rain() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var streak := BoxMesh.new()
	streak.size = Vector3(0.015, 0.31, 0.015)
	var streak_material := StandardMaterial3D.new()
	streak_material.albedo_color = Color("#a9add1")
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material = streak_material
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
	lamp_energy_for_phase = float(LAMP_LEVELS[active_time_phase])
	_update_lamp_selection(true)
	_scenery.apply_time_of_day(active_time_phase)

## Always dusk in the valley: its own haze, fill and key light, and neon bloom
## at every hour. On the island this is the air the walker meets in the market.
func _air(phase: String, _island: Dictionary) -> Dictionary:
	return Atmosphere.air(phase)

func steady_light_count() -> int:
	return _atmosphere.pool_count() if is_instance_valid(_atmosphere) and is_visible_in_tree() else 0

func refresh_label_fonts(font: Font) -> void:
	super.refresh_label_fonts(font)
	_scenery.props.fit_stacked_labels()

func _apply_foliage_phase() -> void:
	var tint: Color = FOLIAGE_GRADE[active_time_phase]
	for material in foliage_materials:
		material.set_shader_parameter("tint", tint)

func _process(delta: float) -> void:
	super._process(delta)
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta)

func cycle_market() -> void:
	_operating = not _operating
	_sync_operating()

func market_status() -> String:
	return "營業中" if _operating else "已收攤"

func _sync_operating() -> void:
	_atmosphere.set_market_open(_operating)
	_scenery.set_open(_operating)
	if is_instance_valid(_status_label):
		_status_label.text = Props.stacked(market_status())

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
	if _is_land(at):
		return GROUND_Y
	# Off the streets the quarter's paving, then the valley floor, is the ground.
	return Scenery.QUARTER_Y if Scenery.QUARTER.has_point(at) or (absf(at.x) < 2.5 and at.y > 0.0) else Scenery.VALLEY_Y

func _is_land(point: Vector2) -> bool:
	for rect in LAND:
		if rect.has_point(point):
			return true
	return _open_ground(point)

func is_walkable(position: Vector3) -> bool:
	return _safe_footing(position)

func _safe_footing(position: Vector3) -> bool:
	for offset in [Vector2(-0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3)]:
		if not _is_land(Vector2(position.x, position.z) + offset):
			return false
	return true

func _constrain_player(previous_position: Vector3) -> bool:
	if player_spot().y < -1.0 or not _safe_footing(previous_position):
		return reset_to_entry()
	if not _safe_footing(player_spot()):
		_set_player_spot(previous_position)
		player.velocity = Vector3.ZERO
	return false

func reset_to_entry() -> bool:
	if not is_instance_valid(player):
		return false
	place_player(ENTRY)
	_host().settle_avatar()
	return true

func map_snapshot() -> Dictionary:
	var map_points: Array[Dictionary] = []
	for point in points:
		map_points.append({"id": point.id, "label": point.label, "position": point.position})
	var at: Vector3 = player_spot() if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": LAND.duplicate(), "points": map_points, "player": at,
		"awning": AWNING, "roof": ROOF, "operating": _operating, "covered": covered_at(at), "region": "nightmarket"}
