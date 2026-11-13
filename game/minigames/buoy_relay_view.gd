extends Control
class_name BuoyRelayView

## 2.5D side-view sea: whole authored figures stand on the stations, the camera pans
## to the active station, and tubes, ring and rope come straight from the snapshot.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/buoy_relay_model.gd")
const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1086, 222, 158, 336)
const COMMANDS := ["action"]
const BUTTON_LABELS := ["按住空白（或W）蓄力投擲／拉繩，放開出手"]
const HELPER_APPEARANCE := {"skin": "bronze", "hair": "curly", "hair_color": "chestnut", "face": "cheerful"}
const SPRITE_HEIGHT := 1.5
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _pointer_owners: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _materials: Dictionary = {}
var _figures: Array[Sprite3D] = []
var _tubes: Dictionary = {}
var _ring: MeshInstance3D
var _rope: MeshInstance3D
var _landing: MeshInstance3D
var _lock: Label3D
var _station_labels: Array[Label3D] = []

static func button_rect(command: String) -> Rect2:
	return Rect2(28, 590, 1224, 56) if command == "action" else Rect2()

static func command_at(point: Vector2) -> String:
	return "action" if button_rect("action").has_point(point) else ""

static func pointer_source(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if not event.pressed:
		if not _pointer_owners.has(source):
			return false
		var command: String = _pointer_owners[source]
		_pointer_owners.erase(source)
		command_requested.emit(command, false, source)
		queue_redraw()
		return true
	if not point.is_finite():
		return false
	var command := command_at(point)
	if command.is_empty():
		return false
	if not _pointer_owners.has(source):
		_pointer_owners[source] = command
		command_requested.emit(command, true, source)
		queue_redraw()
	return true

func clear_pointer_input(emit_releases: bool = true) -> void:
	if emit_releases:
		for source in _pointer_owners:
			command_requested.emit(_pointer_owners[source], false, source)
	_pointer_owners.clear()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_pointer_input(false)
		command_requested.emit("clear", false, "lifecycle")

func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		point = event.position
	if handle_pointer(event, point):
		accept_event()

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not _snapshot.is_empty():
		_create_stage()
		_apply_snapshot()

func present(state: Dictionary, time_phase: String, reduced_motion: bool) -> void:
	_snapshot = state
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if _world == null and is_inside_tree() and not state.is_empty():
		_create_stage()
	if _world != null:
		_apply_snapshot()
	queue_redraw()

func _material(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.85
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _mesh(node_name: String, mesh: Mesh, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _box(node_name: String, size: Vector3, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(node_name, mesh, at, parent, material)

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
	return label

func _create_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "SpatialStage"
	container.position = STAGE.position
	container.size = STAGE.size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.show_behind_parent = true
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "RelayViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "RelaySea"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#d6e2dc")
	_environment.ambient_light_energy = 0.6
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "RelaySun"
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "RelayCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 6.0
	_camera.rotation_degrees = Vector3(-12, 0, 0)
	_world.add_child(_camera)
	_camera.current = true
	for item in [["sea", "#3e8197"], ["deep", "#2b5f72"], ["sand", "#e3cf9c"], ["post", "#6d5236"], ["deck", "#b48a5c"], ["tube", "#d9543f"],
			["cap", "#f2e3b8"], ["ring", "#ff8a3d"], ["rope", "#f0e2b8"], ["landing", "#ffd36a"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_box("Sea", Vector3(60, 8.0, 4.0), Vector3(10, -4.05, -0.4), _world, _materials.sea)
	_box("SeaBack", Vector3(60, 3.0, 0.2), Vector3(10, 0.0, -3.0), _world, _materials.deep)
	_box("Beach", Vector3(6.0, 0.8, 4.0), Vector3(-3.4, -0.2, -0.4), _world, _materials.sand)
	var renderer = AvatarRendererScript.new()
	var progress := get_node_or_null("/root/Progress")
	var appearance: Dictionary = progress.appearance if progress != null and progress.get("appearance") is Dictionary else AvatarRendererScript.DEFAULT_APPEARANCE
	var equipped: Dictionary = progress.equipped if progress != null and progress.get("equipped") is Dictionary else {"outfit": "outfit-tide", "hat": "hat-none"}
	var hero: Texture2D = renderer.texture(appearance, equipped, "right", 0, "idle")
	var helper: Texture2D = renderer.texture(HELPER_APPEARANCE, {"outfit": "outfit-tide", "hat": "hat-none"}, "front", 0, "idle")
	for index in Model.STATIONS.size():
		var x: float = Model.STATIONS[index]
		if index > 0:
			_box("Platform%d" % index, Vector3(1.2, 0.2, 1.0), Vector3(x, 0.2, 0), _world, _materials.deck)
			_box("Float%d" % index, Vector3(0.9, 0.4, 0.8), Vector3(x, -0.05, 0), _world, _materials.ring)
		var sprite := Sprite3D.new()
		sprite.name = "Figure%d" % index
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = false
		sprite.pixel_size = SPRITE_HEIGHT / float(AvatarRendererScript.CANVAS_SIZE.y)
		sprite.texture = helper
		sprite.set_meta("hero", hero)
		sprite.set_meta("helper", helper)
		var feet := float(AvatarRendererScript.CANVAS_SIZE.y) * 0.5 - float(AvatarRendererScript.CANVAS_SIZE.y - AvatarRendererScript.FEET_BASELINE)
		sprite.position = Vector3(x, 0.3 + feet * sprite.pixel_size, 0.1)
		_world.add_child(sprite)
		_figures.append(sprite)
		_station_labels.append(_label3d(Model.STATION_NAMES[index], Vector3(x, 2.2, 0.2), _world, 30))
	for tube: Dictionary in _snapshot.tubes:
		var node := Node3D.new()
		node.name = "Tube%d" % tube.id
		_world.add_child(node)
		var body := CylinderMesh.new()
		body.top_radius = 0.18
		body.bottom_radius = 0.18
		body.height = 0.7
		_mesh("Body", body, Vector3(0, 0.15, 0), node, _materials.tube)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.2
		cap.bottom_radius = 0.2
		cap.height = 0.1
		_mesh("Cap", cap, Vector3(0, 0.52, 0), node, _materials.cap)
		_tubes[tube.id] = node
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.3
	_ring = _mesh("Ring", torus, Vector3.ZERO, _world, _materials.ring)
	_rope = _box("Rope", Vector3(1, 0.035, 0.035), Vector3.ZERO, _world, _materials.rope)
	var marker := CylinderMesh.new()
	marker.top_radius = Model.CATCH_RADIUS
	marker.bottom_radius = Model.CATCH_RADIUS
	marker.height = 0.02
	_landing = _mesh("LandingMarker", marker, Vector3.ZERO, _world, _materials.landing)
	_lock = _label3d("鎖定！", Vector3.ZERO, _world, 40)
	_lock.modulate = Paper.GOLD

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	var station := int(_snapshot.station)
	# The camera eases toward whichever station the player now controls, keeping the sea in frame.
	var focus: float = float(Model.STATIONS[station]) * 0.5 + 5.6
	_camera.position = Vector3(focus, 3.0, 12.0)
	for index in _figures.size():
		_figures[index].texture = _figures[index].get_meta("hero") if index == station else _figures[index].get_meta("helper")
		_station_labels[index].text = Model.STATION_NAMES[index] + ("（你）" if index == station else "")
	var time := float(_snapshot.elapsed)
	for tube: Dictionary in _snapshot.tubes:
		var node: Node3D = _tubes[tube.id]
		node.visible = tube.state != "delivered"
		var bob := 0.0 if _reduced_motion else float(tube.wobble) * 0.12
		var x: float = tube.x
		if tube.state == "held":
			x = Model.STATIONS[station] + 0.5
		node.position = Vector3(x, (0.35 if tube.state == "held" else bob), 0.15)
		node.rotation.z = 0.0 if _reduced_motion else float(tube.wobble) * 0.35
	var ring: Dictionary = _snapshot.ring
	_ring.visible = not ring.is_empty()
	var origin := Vector3(Model.STATIONS[station], 0.9, 0.2)
	var end := origin
	if not ring.is_empty():
		_ring.position = Vector3(float(ring.x), float(ring.height) + 0.05, 0.2)
		end = _ring.position
	elif _snapshot.phase == "reeling" and not _snapshot.held.is_empty():
		end = _tubes[_snapshot.held[0]].position
	_rope.visible = not end.is_equal_approx(origin)
	if _rope.visible:
		_rope.position = (origin + end) * 0.5
		_rope.scale = Vector3(maxf(0.01, origin.distance_to(end)), 1, 1)
		_rope.rotation = Vector3(0, 0, atan2(end.y - origin.y, end.x - origin.x))
		var strain := clampf(float(_snapshot.strain), 0.0, 1.0)
		(_rope.material_override as StandardMaterial3D).albedo_color = Color("#f0e2b8").lerp(Color("#ff6a4d"), strain)
	var preview := float(_snapshot.throw_preview)
	_landing.visible = _snapshot.show_landing and is_finite(preview)
	if _landing.visible:
		_landing.position = Vector3(preview, 0.02, 0.2)
	var lock := int(_snapshot.lock)
	_lock.visible = lock >= 0
	if _lock.visible:
		_lock.position = Vector3(Model.STATIONS[lock], 2.8, 0.2)
	var night := _time_phase == "night"
	_environment.background_color = Color("#1b2c3a") if night else Color("#bcd4d4")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.7 if night else 1.1
	_sun.rotation_degrees = Vector3(-40, -30, 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var phase: String = {"aim_catch": "投環套郵筒", "ring_flight": "浮環飛行", "ring_float": "等郵筒漂進圈", "reeling": "拉繩", "aim_pass": "拋給下一站",
		"pass_flight": "郵筒飛行", "pass_return": "拉回郵筒"}.get(_snapshot.phase, "")
	var charge := "　蓄力 %d%%" % roundi(float(_snapshot.power) * 100) if _snapshot.charging else ""
	return "站點：%s   |   %s%s   |   送達 %d / 3   |   %s" % [Model.STATION_NAMES[int(_snapshot.station)], phase, charge, _snapshot.delivered, _snapshot.variant_name]

func rope_text() -> String:
	if _snapshot.is_empty():
		return ""
	if _snapshot.phase == "reeling":
		return "繩子%s　晃動 %+.2f　按住拉、晃到高點先放手" % ["吃緊" if float(_snapshot.strain) > 0.4 else "穩定", _snapshot.bundle_wobble]
	if _snapshot.phase == "aim_pass":
		return "拋到中繼浮標較穩，直接上岸可省一次交接；%s" % ("鎖定！放手夥伴就會接住" if int(_snapshot.lock) >= 0 else "落點對準站點才會出現鎖定")
	return "浮環落水後，郵筒漂進圈內就會套住；同時套住兩個郵筒算一環雙筒"

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), rope_text(), 1200, 17, Paper.GOLD if int(_snapshot.lock) >= 0 else Paper.PAPER)
		_draw_meter()
	var rect := button_rect("action")
	var held := not _pointer_owners.is_empty()
	draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
	draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
	_text(rect.position + Vector2(14, 34), BUTTON_LABELS[0], rect.size.x - 24, 18)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "蓄力越久丟越遠；郵筒晃到高點時硬拉會滑脫。鏡頭會切到你接手的浮標，郵筒不會掉。", 1210, 17)

## Charge bar and rope strain, each with a number.
func _draw_meter() -> void:
	draw_rect(METER, Color(Paper.DEEP, 0.86))
	draw_rect(METER, Paper.TEAL, false, 2)
	_text(METER.position + Vector2(10, 22), "力道／繩力", 140, 16, Paper.GOLD)
	var top := METER.position.y + 40
	var bottom := METER.end.y - 40
	for column in 2:
		var value := float(_snapshot.power) if column == 0 else clampf(float(_snapshot.strain), 0.0, 1.0)
		var bar := Rect2(METER.position.x + 22 + column * 64, top, 36, bottom - top)
		draw_rect(bar, Color("#22404a"))
		draw_rect(Rect2(bar.position.x, bottom - value * bar.size.y, bar.size.x, value * bar.size.y), Color("#ffe27a") if column == 0 else Color("#ff8a6a"))
		_text(Vector2(bar.position.x - 2, bottom + 24), "%d%%" % roundi(value * 100), 60, 14)
