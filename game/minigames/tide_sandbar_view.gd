extends Control
class_name TideSandbarView

## HD-2D sandbar: a small 3D diorama whose water plane rises over the sand corridors,
## with whole authored traveller frames as billboards. The model is the only simulation.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/tide_sandbar_model.gd")
const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const GAUGE := Rect2(1058, 222, 186, 336)
const COMMANDS := ["left", "up", "down", "right", "run", "mark", "tide_pause"]
const BUTTON_LABELS := ["A / ← 左", "W / ↑ 上", "S / ↓ 下", "D / → 右", "Shift 跑步", "空白／E 路標", "T 水位暫停"]
const OCTANTS := ["right", "front_right", "front", "front_left", "left", "back_left", "back", "back_right"]
const SPRITE_HEIGHT := 1.35
const HELPER_APPEARANCE := {"skin": "bronze", "hair": "curly", "hair_color": "chestnut", "face": "cheerful"}
const HELPER_EQUIPPED := {"outfit": "outfit-tide", "hat": "hat-none"}
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _pointer_owners: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _water: MeshInstance3D
var _water_material: StandardMaterial3D
var _anchor_nodes: Dictionary = {}
var _flags: Dictionary = {}
var _anchor_labels: Dictionary = {}
var _corridor_nodes: Dictionary = {}
var _warnings: Dictionary = {}
var _corridor_labels: Dictionary = {}
var _safe_ring: MeshInstance3D
var _player: Sprite3D
var _helper: Sprite3D
var _rope: MeshInstance3D
var _materials: Dictionary = {}
var _renderer: RefCounted
var _appearance: Dictionary = AvatarRendererScript.DEFAULT_APPEARANCE
var _equipped: Dictionary = {"outfit": "outfit-tide", "hat": "hat-none"}
var _walk_frames: Dictionary = {}
var _idle_frames: Dictionary = {}
var _layout_variant := -1

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 176, 590, 168, 56)

static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""

static func pointer_source(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

static func direction_name(facing: Vector2) -> String:
	if not facing.is_finite() or facing.is_zero_approx():
		return "front"
	return OCTANTS[posmod(roundi(facing.angle() / (PI / 4.0)), 8)]

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
		clear_pointer_input()
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
	var progress := get_node_or_null("/root/Progress")
	if progress != null and progress.get("appearance") is Dictionary and progress.get("equipped") is Dictionary:
		_appearance = progress.appearance
		_equipped = progress.equipped
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
	material.roughness = 0.9
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _mesh_node(node_name: String, mesh: Mesh, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _box(node_name: String, dimensions: Vector3, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh_node(node_name, mesh, at, parent, material)

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 40) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.011
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
	return label

func _sprite(node_name: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.pixel_size = SPRITE_HEIGHT / float(AvatarRendererScript.CANVAS_SIZE.y)
	_world.add_child(sprite)
	return sprite

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
	_viewport.name = "SandbarViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "Sandbar"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#d6e2d6")
	_environment.ambient_light_energy = 0.55
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "SandbarSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "SandbarCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Frames the whole sandbar left of the water gauge at a 35 degree HD-2D pitch.
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 7.4
	_camera.position = Vector3(1.25, 0.6, 0.2) + Vector3(0, sin(deg_to_rad(35.0)), cos(deg_to_rad(35.0))) * 30.0
	_world.add_child(_camera)
	_camera.look_at(Vector3(1.25, 0.6, 0.2))
	_camera.current = true
	for item in [["seabed", "#5e7468"], ["wet", "#b19669"], ["dry", "#e7d09b"], ["reef", "#8a9c95"], ["grass", "#8fb27a"],
			["camp", "#d9b783"], ["pole", "#4a3a2c"], ["flag", "#e8735a"], ["camp_flag", "#f2c45e"], ["warning", "#ff7b5c"],
			["safe", "#ffd36a"], ["rope", "#f0e2b8"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_water_material = _material(Color("#3d8ea3"), 0.6)
	_water_material.roughness = 0.25
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(44, 32)
	_mesh_node("SeaFloor", floor_mesh, Vector3(-1.5, -0.02, 0), _world, _materials.seabed)
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(44, 32)
	_water = _mesh_node("Water", water_mesh, Vector3(-1.5, 0.1, 0), _world, _water_material)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new()
	ring.inner_radius = 1.05
	ring.outer_radius = 1.22
	_safe_ring = _mesh_node("NextSafeRing", ring, Vector3.ZERO, _world, _materials.safe)
	_safe_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope = _box("Rope", Vector3(1, 0.05, 0.05), Vector3.ZERO, _world, _materials.rope)
	_rope.visible = false
	_player = _sprite("Traveller")
	_helper = _sprite("Helper")
	_renderer = AvatarRendererScript.new()
	_helper.texture = _renderer.texture(HELPER_APPEARANCE, HELPER_EQUIPPED, "front", 0, "idle")
	_build_layout()

## Anchors move between variants, so terrain is rebuilt only when the layout changes.
func _build_layout() -> void:
	_layout_variant = int(_snapshot.get("variant", 0))
	for group in [_anchor_nodes, _corridor_nodes]:
		for node: Node in group.values():
			# Detach now so rebuilt anchors keep their exact names.
			node.get_parent().remove_child(node)
			node.queue_free()
		group.clear()
	_flags.clear()
	_anchor_labels.clear()
	_warnings.clear()
	_corridor_labels.clear()
	for row: Dictionary in _snapshot.get("corridors", []):
		var from: Vector2 = row.from
		var to: Vector2 = row.to
		var node := Node3D.new()
		node.name = "Corridor_%s" % row.id
		node.position = Vector3((from.x + to.x) * 0.5, 0, (from.y + to.y) * 0.5)
		node.rotation.y = -(to - from).angle()
		_world.add_child(node)
		var length := from.distance_to(to)
		var elevation: float = row.elevation
		var sand: StandardMaterial3D = _material(_materials.wet.albedo_color.lerp(_materials.dry.albedo_color, clampf(elevation, 0.0, 1.0)))
		_box("Sand", Vector3(length, elevation, Model.CORRIDOR_HALF_WIDTH * 2.0), Vector3(0, elevation * 0.5, 0), node, sand)
		var outline := Node3D.new()
		outline.name = "FloodOutline"
		node.add_child(outline)
		for side in [-1, 1]:
			_box("Edge", Vector3(length, 0.06, 0.09), Vector3(0, elevation + 0.03, side * Model.CORRIDOR_HALF_WIDTH), outline, _materials.warning)
		_warnings[row.id] = outline
		_corridor_nodes[row.id] = node
		_corridor_labels[row.id] = _label3d("", Vector3(-length * 0.1, elevation + 0.3, 0), node, 30)
	for anchor: Dictionary in _snapshot.get("anchors", []):
		var node := Node3D.new()
		node.name = "Anchor_%s" % anchor.id
		node.position = Vector3(anchor.position.x, 0, anchor.position.y)
		_world.add_child(node)
		_anchor_nodes[anchor.id] = node
		var top := CylinderMesh.new()
		top.top_radius = Model.ANCHOR_RADIUS
		top.bottom_radius = Model.ANCHOR_RADIUS + 0.15
		top.height = Model.ANCHOR_HEIGHT
		top.radial_segments = 20
		var material: StandardMaterial3D = {"reef": _materials.reef, "highland": _materials.grass, "camp": _materials.camp}.get(anchor.kind, _materials.dry)
		_mesh_node("Ground", top, Vector3(0, Model.ANCHOR_HEIGHT * 0.5, 0), node, material)
		if anchor.kind == "camp":
			var tent := PrismMesh.new()
			tent.size = Vector3(0.9, 0.7, 0.8)
			_mesh_node("Tent", tent, Vector3(-0.35, Model.ANCHOR_HEIGHT + 0.35, -0.35), node, _materials.flag)
		var flag := Node3D.new()
		flag.name = "RouteFlag"
		flag.position = Vector3(0.45, Model.ANCHOR_HEIGHT, -0.25)
		node.add_child(flag)
		_box("Pole", Vector3(0.06, 1.0, 0.06), Vector3(0, 0.5, 0), flag, _materials.pole)
		_box("Cloth", Vector3(0.42, 0.26, 0.03), Vector3(0.22, 0.85, 0), flag, _materials.camp_flag if anchor.kind == "camp" else _materials.flag)
		_flags[anchor.id] = flag
		_anchor_labels[anchor.id] = _label3d("", Vector3(0, Model.ANCHOR_HEIGHT + 0.7, -0.55), node, 34)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.get("variant", 0)) != _layout_variant:
		_build_layout()
	var level: float = _snapshot.tide
	var shimmer := 0.0 if _reduced_motion else sin(float(_snapshot.elapsed) * 1.7) * 0.012
	_water.position.y = level + shimmer
	var marked: Array = _snapshot.marked
	for anchor: Dictionary in _snapshot.anchors:
		_flags[anchor.id].visible = marked.has(anchor.id)
		var suffix := " ✓" if marked.has(anchor.id) else (" ★" if anchor.kind == "reef" else "")
		_anchor_labels[anchor.id].text = str(anchor.name) + suffix
	for row: Dictionary in _snapshot.corridors:
		var outline: Node3D = _warnings[row.id]
		outline.visible = bool(row.warning) and (_reduced_motion or fposmod(float(_snapshot.elapsed), 0.8) < 0.55)
		var label: Label3D = _corridor_labels[row.id]
		if row.warning:
			label.text = "%.1f 秒後淹沒" % row.flood_in
			label.modulate = Color("#ffb39e")
		elif not row.dry:
			label.text = "淹沒 · %s" % ("%.0f 秒後露出" % row.dry_in if row.dry_in >= 0.0 else "暫停中")
			label.modulate = Color("#bfe6f0")
		else:
			label.text = ""
	var safe: Dictionary = _snapshot.next_safe
	for anchor: Dictionary in _snapshot.anchors:
		if anchor.id == safe.id:
			var pulse := 1.0 if _reduced_motion else 1.0 + sin(float(_snapshot.elapsed) * 4.0) * 0.05
			_safe_ring.position = Vector3(anchor.position.x, Model.ANCHOR_HEIGHT + 0.03, anchor.position.y)
			_safe_ring.scale = Vector3(pulse, 1, pulse)
	var position_2d: Vector2 = _snapshot.position
	var ground := Model.ANCHOR_HEIGHT if _on_anchor(position_2d) else _corridor_height(position_2d)
	_place(_player, position_2d, ground)
	_player.texture = _traveller_texture()
	# The helper hops straight to the guarded high point; it never wades across water.
	var helper_at: Vector2 = Vector2(_snapshot.helper_position) + Vector2(0.55, 0.35)
	_place(_helper, helper_at, Model.ANCHOR_HEIGHT)
	var rope: Dictionary = _snapshot.rope
	_rope.visible = not rope.is_empty()
	if not rope.is_empty():
		var from := Vector3(helper_at.x, Model.ANCHOR_HEIGHT + 0.7, helper_at.y)
		var to := Vector3(position_2d.x, maxf(level, ground) + 0.5, position_2d.y)
		var reach: Vector3 = from.lerp(to, float(rope.progress))
		_rope.position = (from + reach) * 0.5
		_rope.scale = Vector3(maxf(0.01, from.distance_to(reach)), 1, 1)
		_rope.look_at(reach if not reach.is_equal_approx(_rope.position) else _rope.position + Vector3.RIGHT, Vector3.UP)
		_rope.rotate_object_local(Vector3.UP, PI / 2.0)
	var night := _time_phase == "night"
	_environment.background_color = Color("#1b3042") if night else Color("#b8cdc8")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.8 if night else 1.15
	_sun.rotation_degrees = Vector3(-42, {"dawn": -70.0, "noon": -35.0, "dusk": 40.0, "night": 70.0}.get(_time_phase, -35.0), 0)

func _on_anchor(point: Vector2) -> bool:
	for anchor: Dictionary in _snapshot.anchors:
		if point.distance_to(anchor.position) <= Model.ANCHOR_RADIUS:
			return true
	return false

func _corridor_height(point: Vector2) -> float:
	var height := 0.0
	for row: Dictionary in _snapshot.corridors:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, row.from, row.to)) <= Model.CORRIDOR_HALF_WIDTH:
			height = maxf(height, row.elevation)
	return height

func _place(sprite: Sprite3D, at: Vector2, ground: float) -> void:
	var feet := float(AvatarRendererScript.CANVAS_SIZE.y) * 0.5 - float(AvatarRendererScript.CANVAS_SIZE.y - AvatarRendererScript.FEET_BASELINE)
	sprite.position = Vector3(at.x, ground + feet * sprite.pixel_size, at.y)

## Keeps only the current direction's whole authored frames; the renderer owns its cache.
func _traveller_texture() -> Texture2D:
	var direction := direction_name(_snapshot.facing)
	if _snapshot.moving and not _snapshot.rescuing:
		if not _walk_frames.has(direction):
			_walk_frames.clear()
			var frames: Array[Texture2D] = []
			for frame in _renderer.walk_frame_count(direction):
				var texture: Texture2D = _renderer.texture(_appearance, _equipped, direction, frame, "walk")
				if texture != null:
					frames.append(texture)
			_walk_frames[direction] = frames
		var frames: Array = _walk_frames[direction]
		if not frames.is_empty():
			var fps := 12.0 if _snapshot.running else 8.0
			return frames[int(float(_snapshot.elapsed) * fps) % frames.size()]
	if not _idle_frames.has(direction):
		_idle_frames[direction] = _renderer.texture(_appearance, _equipped, direction, 0, "idle")
	return _idle_frames[direction]

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var trend := "水位暫停" if _snapshot.tide_paused else ("漲潮中" if _snapshot.tide_rising else "退潮中")
	var safe: Dictionary = _snapshot.next_safe
	var reach := "站在高點上" if safe.seconds <= 0.0 else "跑 %.1f 秒%s" % [safe.seconds, "" if safe.safe else "（路會先淹）"]
	return "水位 %d%% %s · 下次低潮 %.0f 秒   |   下一安全高點：%s（%s）   |   礁 %d / 3" % [roundi(_snapshot.tide * 100), trend, _snapshot.next_low_in, safe.name, reach, _snapshot.reefs_marked]

func route_text() -> String:
	if _snapshot.is_empty():
		return ""
	var names: Array[String] = ["營地"]
	for marker: Dictionary in _snapshot.markers:
		for anchor: Dictionary in _snapshot.anchors:
			if anchor.id == marker.anchor_id:
				names.append(str(anchor.name))
	var helper := ""
	for anchor: Dictionary in _snapshot.anchors:
		if anchor.id == _snapshot.helper_anchor:
			helper = str(anchor.name)
	return "路標：%s　夥伴守在%s　回路%s　%s" % ["→".join(names), helper, "已留好" if _snapshot.return_prepared else ("未留" if _snapshot.first_reef_at >= 0.0 else "待標高地與沙丘"), "輔助：T 暫停水位" if _snapshot.assisted else ""]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), route_text(), 1200, 17)
		_draw_gauge()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held := _pointer_owners.values().has(command)
		var unavailable: bool = command == "tide_pause" and not _snapshot.get("assisted", false)
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else (Paper.DEEP if unavailable else Paper.TEAL), false, 2)
		_text(rect.position + Vector2(10, 34), BUTTON_LABELS[i] + ("（輔助）" if unavailable else ""), rect.size.x - 16, 16, Color(Paper.PAPER, 0.55) if unavailable else Paper.PAPER)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "按住方向走、Shift 跑；在沙丘或礁石中央插路標。紅框沙路即將淹沒，金圈是下一個安全高點。", 1210, 17)

## Water gauge: every corridor elevation is a labelled tick, so the flood order reads without sound or color.
func _draw_gauge() -> void:
	draw_rect(GAUGE, Color(Paper.DEEP, 0.86))
	draw_rect(GAUGE, Paper.TEAL, false, 2)
	_text(GAUGE.position + Vector2(10, 22), "水位刻度", 160, 16, Paper.GOLD)
	var bar := Rect2(GAUGE.position.x + 14, GAUGE.position.y + 36, 22, GAUGE.size.y - 50)
	var to_y := func(height: float) -> float: return bar.end.y - clampf(height / Model.ANCHOR_HEIGHT, 0.0, 1.0) * bar.size.y
	draw_rect(bar, Color("#22404a"))
	var water_y: float = to_y.call(_snapshot.tide)
	draw_rect(Rect2(bar.position.x, water_y, bar.size.x, bar.end.y - water_y), Color("#4fa6bb"))
	draw_line(Vector2(bar.position.x - 6, water_y), Vector2(bar.end.x + 6, water_y), Paper.PAPER, 3)
	var arrow := "▲" if _snapshot.tide_rising else "▼"
	if _snapshot.tide_paused:
		arrow = "Ⅱ"
	_text(Vector2(bar.position.x - 2, water_y - 6), arrow, 30, 14, Paper.PAPER)
	# Ticks sit at true heights; labels stack downward so close elevations stay legible.
	var groups: Dictionary = {}
	for row: Dictionary in _snapshot.corridors:
		var group: Dictionary = groups.get(row.gauge, {"name": row.gauge, "elevation": row.elevation, "dry": true, "warning": false})
		group.dry = group.dry and row.dry
		group.warning = group.warning or row.warning
		groups[row.gauge] = group
	var rows: Array = groups.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.elevation > b.elevation)
	var spacing: float = 15.0 * Paper.text_scale()
	var label_y := -INF
	for group: Dictionary in rows:
		var y: float = to_y.call(group.elevation)
		label_y = maxf(y, label_y + spacing)
		var state := "淹" if not group.dry else ("危" if group.warning else "通")
		var color: Color = Color("#bfe6f0") if not group.dry else (Color("#ffb39e") if group.warning else Paper.PAPER)
		draw_line(Vector2(bar.end.x, y), Vector2(bar.end.x + 8, label_y), color, 2)
		_text(Vector2(bar.end.x + 12, label_y + 5), "%s %s" % [state, group.name], 128, 13, color)
