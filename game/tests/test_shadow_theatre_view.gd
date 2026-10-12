extends SceneTree

const View = preload("res://game/minigames/shadow_theatre_view.gd")
const HUD = preload("res://game/ui/minigame_hud.gd")
const Model = preload("res://game/minigames/shadow_theatre_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = View.new()
	root.add_child(view)
	await process_frame
	_test_real_3d_shadow_stage(view)
	_test_formula_marker_and_frame(view)
	_test_input_and_design_mapping(view)
	_test_palette_and_static_geometry(view)
	await _test_pause_focus_restoration(view)
	await _test_native_shift_precision(view)
	await _test_feedback_strip(view)
	_test_clear_causal_theatre(view)
	view.queue_free()
	await process_frame
	if failures == 0:
		print("Shadow theatre view: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Shadow theatre view: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_real_3d_shadow_stage(view: Control) -> void:
	var viewport: SubViewport = view.sub_viewport()
	var camera: Camera3D = view.camera()
	var light: SpotLight3D = view.lamp_light()
	var puppet: MeshInstance3D = view.puppet_mesh()
	var emitter: MeshInstance3D = view.visible_emitter()
	var lettering := view.sub_viewport().get_node_or_null("PaperTheatre/TheatreLettering") as Label3D
	_expect(viewport != null and viewport.size == Vector2i(1280, 720), "miniature theatre renders through its own 1280x720 SubViewport")
	print("SHADOW_RENDER_SETUP: own_world=%s atlas=%d quadrant0=%d" % [viewport.own_world_3d, viewport.positional_shadow_atlas_size, viewport.positional_shadow_atlas_quad_0])
	_expect(viewport.own_world_3d and viewport.find_world_3d() != root.find_world_3d(), "theatre lighting and receiver live in an isolated 3D world")
	_expect(viewport.positional_shadow_atlas_size == 2048 and viewport.positional_shadow_atlas_size <= 2048 and viewport.positional_shadow_atlas_quad_0 == Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1, "bounded 2048 positional atlas reserves one 1024 shadow map for the actual spot light")
	var wall := viewport.get_node("PaperTheatre/PrintedPaperWall") as MeshInstance3D
	var receiver := wall.material_override as StandardMaterial3D
	_expect(receiver != null and receiver.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not receiver.disable_receive_shadows and not receiver.disable_ambient_light and receiver.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque shaded paper receives physical spot shadows with restrained indirect fill")
	_expect(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.current, "SubViewport has its own fixed composition Camera3D")
	_expect(light != null and light.shadow_enabled and light.spot_angle < 89.0, "one point-source SpotLight3D casts a real-time shadow in the supported cone range")
	_expect(puppet != null and puppet.mesh != null and puppet.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, "fixed hand-cut puppet is an extruded two-sided 3D shadow caster")
	_expect(emitter != null and emitter.global_position.distance_to(light.global_position) < 0.00001, "visible glowing bulb occupies the exact actual spot-light source point")
	var reflector := viewport.get_node("PaperTheatre/MovingBrassLamp/ReflectorBell") as MeshInstance3D
	_expect(reflector != null and reflector.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and emitter.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "decorative closed reflector caps and bulb never eclipse the causal spot source")
	_expect(light.light_size > 0.0 and light.shadow_normal_bias < 0.2, "small point size softens penumbra while keeping the precise cast close to the cutout")
	_expect(lettering != null and lettering.text == "TIDE THEATRE  /  SHADOW STUDY" and lettering.global_basis.z.normalized().dot(camera.global_basis.z.normalized()) > 0.99, "nameplate lettering's front face points toward the theatre camera and reads without backside mirroring")
	_expect(view.geometry_build_count >= 20 and view.target_marker(0).mesh != null, "finite timber, brass, paper and marker geometry is built during initialization")
	_expect(view.texture() != null, "view exposes its active SubViewport texture to a parent scene")
	var shadow_lights: Array[Light3D] = []
	_collect_shadow_lights(view.sub_viewport(), shadow_lights)
	_expect(shadow_lights.size() == 1 and shadow_lights[0] == light, "the miniature keeps one causal shadow light; readability fill comes from WorldEnvironment")
	var shutter: Button = view.shutter_button()
	var shutter_rect := shutter.get_rect() if shutter != null else Rect2()
	_expect(shutter != null and shutter.name == "ShadowShutterButton" and shutter.text == "定影　Space" and shutter_rect.position.y >= view.hud_safe_rect().end.y and shutter_rect.end.x <= view.size.x and shutter_rect.end.y <= view.size.y, "click shutter is legible and stays inside the playfield below the HUD-safe band")
	var shutter_events: Array[bool] = []
	view.shutter_requested.connect(func() -> void: shutter_events.append(true))
	if shutter != null:
		shutter.emit_signal("pressed")
	_expect(shutter_events.size() == 1, "the on-screen brass shutter button routes through the same shutter signal as Space")

func _test_formula_marker_and_frame(view: Control) -> void:
	var model = Model.new()
	view.present_state(model.snapshot(), "noon", false)
	var marker: MeshInstance3D = view.target_marker(0)
	var line_vertices: PackedVector3Array = marker.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var target: PackedVector2Array = model.snapshot().target_vertices
	_expect(line_vertices.size() == target.size() * 6, "fixed wall marker builds a filled ribbon across every formula-projected edge")
	var edge_center := Vector2((line_vertices[0].x + line_vertices[1].x) * 0.5, (line_vertices[0].y + line_vertices[1].y) * 0.5)
	_expect(edge_center.distance_to(target[0]) < 0.0001, "printed wall outline is centered on the model's point-source projection")
	_expect(Vector2(line_vertices[0].x, line_vertices[0].y).distance_to(Vector2(line_vertices[1].x, line_vertices[1].y)) >= View.TARGET_OUTER_WIDTH - 0.0001, "outer target ink has a readable authored world-space stroke")
	var accent := marker.get_node("InnerRegistrationInk") as MeshInstance3D
	_expect(accent != null and accent.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == target.size() * 6, "double-ink registration line has its own static contrasting material layer")
	var initial_mesh_count: int = view.geometry_build_count
	model.setlamp_target(model.round_solution(0) + Vector2(0.28, 0.25))
	view.present_state(model.snapshot(), "dusk", false)
	_expect(view.geometry_build_count == initial_mesh_count, "lamp movement and phase changes reuse all cached finite geometry")
	_expect(view.cast_shadow_screen_bounds().size.x > 0.0 and view.target_marker_bounds().size.x > 0.0, "actual and target vertex sets project into visible camera space")
	var stage_bounds: Rect2 = view.projected_geometry_bounds()
	_expect(stage_bounds.position.y >= view.hud_safe_rect().end.y and stage_bounds.end.y <= 720.0, "full projected stage and lamp bounds stay below HUD safe area and inside 720 pixels")
	_expect(view.cast_shadow_screen_bounds().position.y >= 130.0 and view.cast_shadow_screen_bounds().end.y <= 720.0, "every calculated shadow vertex remains in the playable screen area")
	_expect(view.target_marker_bounds().position.y >= 130.0 and view.target_marker_bounds().end.y <= 720.0, "every printed target vertex remains visible below the HUD")
	var extreme_bounds: Rect2 = view.projected_geometry_bounds()
	_expect(extreme_bounds.position.x >= 0.0 and extreme_bounds.end.x <= 1280.0 and extreme_bounds.position.y >= 130.0 and extreme_bounds.end.y <= 720.0, "projected puppet, marker, frame, bulb and all four rail extremes fit the HUD-safe output")
	var lamp_source: Vector3 = view.lamp_light().global_position
	var lamp_model: Vector2 = model.snapshot().lamp_position
	_expect(lamp_source.distance_to(Vector3(lamp_model.x, Model.LAMP_Y, lamp_model.y)) < 0.00001, "moving model lamp and physical 3D point source remain at the same XYZ coordinates")
	var puppet_vertices: PackedVector2Array = model.puppet_vertices()
	var physical_local := Vector3(puppet_vertices[0].x, puppet_vertices[0].y, -View.PUPPET_HALF_DEPTH)
	var physical_world: Vector3 = view.puppet_mesh().global_transform * physical_local
	_expect(absf(physical_world.z - Model.PUPPET_Z) < 0.00001, "actual light-facing cutout surface is precisely the model's projection plane")
	var physical_factor := (Model.WALL_Z - lamp_source.z) / (physical_world.z - lamp_source.z)
	var physical_projection := lamp_source + (physical_world - lamp_source) * physical_factor
	var formula_projection: PackedVector2Array = model.projection_for(lamp_model, PackedVector2Array([puppet_vertices[0]]))
	_expect(Vector2(physical_projection.x, physical_projection.y).distance_to(formula_projection[0]) < 0.00001, "actual 3D cast vertex ray intersects the model's same wall point")

func _test_input_and_design_mapping(view: Control) -> void:
	var axes: Array[Vector2] = []
	var lamps: Array[Vector2] = []
	var shutter_events: Array[int] = []
	view.axis_requested.connect(func(x: float, depth: float) -> void: axes.append(Vector2(x, depth)))
	view.lamp_target_requested.connect(func(target: Vector2) -> void: lamps.append(target))
	view.shutter_requested.connect(func() -> void: shutter_events.append(1))
	_expect(view.screen_to_design(view.size * 0.5) == Vector2(640.0, 360.0), "pointer maps local coordinates into 1280x720 design space")
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	view._gui_input(right)
	view._process(0.016)
	var release := InputEventKey.new()
	release.keycode = KEY_RIGHT
	release.pressed = false
	view._gui_input(release)
	_expect(not axes.is_empty() and axes[0] == Vector2.RIGHT, "right key emits a continuous horizontal lamp-control axis")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	view._gui_input(space)
	_expect(shutter_events.size() == 1, "Space sends the real shutter request")
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = view.size * 0.5
	view._gui_input(pointer)
	_expect(lamps.size() == 1 and lamps[0].is_finite(), "mouse press maps to a finite lamp position request")
	_expect(lamps[0].x > Model.LAMP_X_MIN and lamps[0].x < Model.LAMP_X_MAX, "pointer center addresses the center of the physical lamp rail")

func _test_palette_and_static_geometry(view: Control) -> void:
	view.present_state({"round": 0, "lamp_position": Vector2(-0.8, -2.4), "cast_vertices": Model.new().snapshot().cast_vertices, "target_vertices": Model.new().snapshot().target_vertices}, "dawn", false)
	var ambient_dawn: Color = view.ambient_environment().ambient_light_color
	var lamp_dawn: Color = view.lamp_light().light_color
	view.present_state({"round": 1, "lamp_position": Vector2(0.4, -2.1), "cast_vertices": Model.new().snapshot().cast_vertices, "target_vertices": Model.new().snapshot().target_vertices}, "night", true)
	var ambient_night: Color = view.ambient_environment().ambient_light_color
	var night_fill: float = view.ambient_environment().ambient_light_energy
	_expect(ambient_dawn != ambient_night and lamp_dawn == Color("#ffd5a3") and view.lamp_light().light_color == Color("#ffe0a6"), "four time phases alter ambient fill and the actual main lamp color")
	_expect(night_fill >= 0.32 and night_fill <= 0.40, "night uses restrained indirect fill without changing the single point source or shadow geometry")
	var stage: Node3D = view.sub_viewport().get_node("PaperTheatre") as Node3D
	var wall := stage.get_node("PrintedPaperWall") as MeshInstance3D
	var wood := stage.get_node("TopTimberRail") as MeshInstance3D
	var curtain := stage.get_node("LeftSeaGlassWing") as MeshInstance3D
	var curtain_folds := stage.find_children("CurtainFold*", "MeshInstance3D", false, false)
	var fold := curtain_folds[0] as MeshInstance3D if not curtain_folds.is_empty() else null
	var face := view.puppet_mesh().get_node("OtterWarmFace") as MeshInstance3D
	var bib := view.puppet_mesh().get_node("TidecoatBib") as MeshInstance3D
	var boot := view.puppet_mesh().get_node("LeftDeckBoot") as MeshInstance3D
	var wall_color: Color = (wall.material_override as StandardMaterial3D).albedo_color
	var face_color: Color = (face.material_override as StandardMaterial3D).albedo_color
	var bib_color: Color = (bib.material_override as StandardMaterial3D).albedo_color
	var wall_rgb := Vector3(wall_color.r, wall_color.g, wall_color.b)
	var face_rgb := Vector3(face_color.r, face_color.g, face_color.b)
	var bib_rgb := Vector3(bib_color.r, bib_color.g, bib_color.b)
	_expect(wall_rgb.distance_to(face_rgb) > 0.18 and wall_rgb.distance_to(bib_rgb) > 0.24 and boot.mesh != null, "warm paper backdrop separates the face, coat, and deck boots through actual matte color regions")
	var wood_color: Color = (wood.material_override as StandardMaterial3D).albedo_color
	var curtain_color: Color = (curtain.material_override as StandardMaterial3D).albedo_color
	var fold_color: Color = (fold.material_override as StandardMaterial3D).albedo_color
	var wood_rgb := Vector3(wood_color.r, wood_color.g, wood_color.b)
	var curtain_rgb := Vector3(curtain_color.r, curtain_color.g, curtain_color.b)
	var fold_rgb := Vector3(fold_color.r, fold_color.g, fold_color.b)
	_expect(wood_rgb.distance_to(curtain_rgb) > 0.30 and curtain_rgb.distance_to(fold_rgb) > 0.12, "carved timber and raised sea-glass curtain folds use distinct tactile color layers")
	_expect(view.target_marker(0).visible == false and view.target_marker(1).visible == true, "each round selects its fixed corresponding wall registration outline")
	_expect(view.puppet_mesh().cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, "reduced-motion presentation retains the physical static shadow caster")

func _collect_shadow_lights(node: Node, lights: Array[Light3D]) -> void:
	if node is Light3D and (node as Light3D).shadow_enabled:
		lights.append(node as Light3D)
	for child in node.get_children():
		_collect_shadow_lights(child, lights)

func _test_pause_focus_restoration(view: Control) -> void:
	var hud_button := Button.new()
	hud_button.text = "Resume"
	root.add_child(hud_button)
	view.set_process(false)
	view.present_state(Model.new().snapshot())
	hud_button.grab_focus()
	await process_frame
	_expect(root.gui_get_focus_owner() == hud_button, "disabled theatre leaves pause control keyboard focus alone")
	view.set_process(true)
	view.present_state(Model.new().snapshot())
	await process_frame
	await process_frame
	_expect(root.gui_get_focus_owner() == view, "resumed theatre restores keyboard focus after the HUD retry/resume route")
	var event := InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.physical_keycode = KEY_RIGHT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	_expect(bool(view.get("_right_down")), "actual right-key input reaches the restored theatre rather than the pause button")
	event = InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.physical_keycode = KEY_RIGHT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	hud_button.queue_free()

func _test_native_shift_precision(view: Control) -> void:
	var movement_model := Model.new()
	movement_model.reset(false)
	var start_x: float = movement_model.snapshot().lamp_position.x
	var observed: Array[Vector2] = []
	var on_axis := func(x: float, depth: float) -> void:
		observed.append(Vector2(x, depth))
		movement_model.continuous_axis(x, depth, 1.0 / 60.0)
	view.axis_requested.connect(on_axis)
	for code in [KEY_SHIFT, KEY_RIGHT]:
		var press := InputEventKey.new()
		press.keycode = code
		press.physical_keycode = code
		press.pressed = true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
	await process_frame
	await process_frame
	_expect(not observed.is_empty() and observed.back() == Vector2(0.25, 0.0), "native Shift plus right emits quarter-speed fine control without changing the target")
	var fine_distance: float = movement_model.snapshot().lamp_position.x - start_x
	_expect(not observed.is_empty() and absf(fine_distance - float(observed.size()) * Model.LAMP_SPEED / 60.0 * 0.25) < 0.000002, "actual fine axes move the finite lamp model by quarter-size steps, never snap to its solution")
	var release := InputEventKey.new()
	release.keycode = KEY_SHIFT
	release.physical_keycode = KEY_SHIFT
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	_expect(not observed.is_empty() and observed.back() == Vector2.RIGHT, "releasing actual Shift restores the ordinary continuous movement speed")
	release = InputEventKey.new()
	release.keycode = KEY_RIGHT
	release.physical_keycode = KEY_RIGHT
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	view.axis_requested.disconnect(on_axis)

func _test_feedback_strip(view: Control) -> void:
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_feedback_at("影形吻合並完成定影", Vector2(640, 230))
	await process_frame
	var feedback := hud.find_child("ContextFeedback", true, false) as Control
	var model := Model.new()
	var clear := feedback != null
	for index in 3:
		model.setlamp_target(model.round_solution(index))
		view.present_state(model.snapshot())
		clear = clear and not feedback.get_rect().intersects(view.cast_shadow_screen_bounds()) and not feedback.get_rect().intersects(view.target_marker_bounds())
		model.capture()
	_expect(clear, "actual HUD toast at the upper strip avoids all three physical projection and target bounds")
	hud.queue_free()

func _test_clear_causal_theatre(view: Control) -> void:
	var casters: Array[GeometryInstance3D] = []
	_collect_shadow_casters(view.sub_viewport(), casters)
	_expect(casters.size() == 1 and casters[0] == view.puppet_mesh(), "only the intended puppet casts; receiver, frame, curtain, deck and lamp decoration cannot add stripes")
	_expect(view.lamp_light().light_energy >= 1.0 and view.lamp_light().light_energy <= 1.8 and view.ambient_environment().ambient_light_energy >= 0.25 and view.ambient_environment().ambient_light_energy <= 0.40, "bounded direct and indirect light preserve material color without pitch-black-only illumination")
	var model := Model.new()
	var separated := true
	for index in 3:
		model.setlamp_target(model.round_solution(index))
		view.present_state(model.snapshot())
		var puppet_rect: Rect2 = view.puppet_screen_bounds()
		var lamp_rect: Rect2 = view.lamp_body_screen_bounds()
		separated = separated and not puppet_rect.intersects(view.cast_shadow_screen_bounds()) and not puppet_rect.intersects(lamp_rect)
		model.capture()
	_expect(separated, "camera parallax separates the real puppet from all three wall casts and foreground lamp housing")

func _collect_shadow_casters(node: Node, casters: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		casters.append(node as GeometryInstance3D)
	for child in node.get_children(): _collect_shadow_casters(child, casters)
