extends SceneTree

const Model = preload("res://game/minigames/sign_balance_model.gd")
const View = preload("res://game/minigames/sign_balance_view.gd")
const Session = preload("res://game/minigames/session.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model = Model.new()
	model.reset()
	var state: Dictionary = model.snapshot().duplicate(true)
	var fixture_viewport := SubViewport.new()
	fixture_viewport.size = Vector2i(1280, 720)
	fixture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(fixture_viewport)
	var view = View.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fixture_viewport.add_child(view)
	await process_frame
	view.update_frame(state, "noon", false)
	_test_real_spatial_scene(view)
	_test_snapshot_drives_mechanism(view, state)
	_test_seven_stage_visual_semantics(view, state)
	_test_input_and_layout_compatibility(view)
	_test_preserved_semantics(view, state)
	await _test_actual_session_feedback(view, fixture_viewport)
	if failures == 0:
		print("Sign balance view: %d checks passed" % checks)
		fixture_viewport.queue_free()
		quit(0)
	else:
		push_error("Sign balance spatial view: %d check(s) failed" % failures)
		fixture_viewport.queue_free()
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _test_real_spatial_scene(view: Control) -> void:
	var container := view.find_child("SpatialStage", true, false) as SubViewportContainer
	_expect(container != null, "presentation owns an embedded 3D stage, not only drawn polygons")
	_expect(container != null and container.z_index == 0 and container.z_as_relative and container.show_behind_parent and container.mouse_filter == Control.MOUSE_FILTER_IGNORE, "3D stage shares the session canvas Z and draws immediately behind its own overlay without intercepting pointers")
	var subviewport: SubViewport = container.get_child(0) as SubViewport if container != null and container.get_child_count() > 0 else null
	_expect(subviewport != null and subviewport.world_3d != null, "stage renders its own 3D world into a texture")
	_expect(subviewport != null and subviewport.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "embedded world renders only while its stage is visible")
	var camera := view.find_child("StageCamera", true, false) as Camera3D
	var assembly := view.find_child("SignAssembly", true, false) as Node3D
	var axle := view.find_child("Axle", true, false) as MeshInstance3D
	var rail := view.find_child("CounterweightRail", true, false) as MeshInstance3D
	var weight := view.find_child("Counterweight", true, false) as Node3D
	var chain := view.find_child("WeightChain", true, false) as Node3D
	var flag := view.find_child("WindPennant", true, false) as Node3D
	var platform := view.find_child("DockPlatform", true, false) as MeshInstance3D
	var sun := view.find_child("HarborSun", true, false) as DirectionalLight3D
	_expect(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "fixed low three-quarter camera frames the physical apparatus")
	_expect(assembly != null and axle != null and rail != null and weight != null and chain != null, "sign, axle, slider rail, hanging mass, and chain are actual 3D nodes")
	_expect(flag != null and platform != null, "wind pennant and dock platform are part of the same harbor-built scene")
	_expect(sun != null and sun.shadow_enabled, "sign and weight cast real scene shadows")
	_expect(view.decorative_node_count() >= 10, "apparatus has purposeful constructed hardware instead of a single flat mesh")
	var title := view.find_child("SignTitle", true, false) as Label3D
	var face := view.find_child("SignInlay", true, false) as MeshInstance3D
	_expect(title != null and title.text == "潮汐花園" and face != null, "the sign's real 3D title is attached to its inset face")
	if title != null and face != null:
		var title_bounds: AABB = title.get_aabb()
		var face_size: Vector3 = (face.mesh as BoxMesh).size
		_expect(title_bounds.size.x <= face_size.x and title_bounds.size.y <= face_size.y and absf(title.position.x) + title_bounds.size.x * 0.5 <= face_size.x * 0.5 and absf(title.position.y - 0.72) + title_bounds.size.y * 0.5 <= face_size.y * 0.5, "rendered title geometry fits within the inset sign face")

func _test_snapshot_drives_mechanism(view: Control, state: Dictionary) -> void:
	var assembly := view.find_child("SignAssembly", true, false) as Node3D
	var weight := view.find_child("Counterweight", true, false) as Node3D
	var rail := view.find_child("CounterweightRail", true, false) as MeshInstance3D
	var chain := view.find_child("WeightChain", true, false) as Node3D
	var flag := view.find_child("WindPennant", true, false) as Node3D
	var sun := view.find_child("HarborSun", true, false) as DirectionalLight3D
	if assembly == null or weight == null or rail == null or chain == null or flag == null or sun == null:
		return
	var node_count: int = view.spatial_node_count()
	var body_mesh_id := view.find_child("SignFace", true, false).get_instance_id() if view.find_child("SignFace", true, false) != null else 0
	state["angle"] = 0.42
	state["balance"] = -0.65
	state["wind_direction"] = -1
	state["forecast_visible"] = true
	state["forecast_torque"] = -0.18
	view.update_frame(state, "dusk", false)
	_expect(is_equal_approx(assembly.rotation.z, view.visual_angle(state)), "real sign mesh rotates by the same clamped model angle")
	_expect(is_equal_approx(weight.position.x, view.weight_rail_x(state)), "counterweight's actual local position follows snapshot balance along the visible rail")
	_expect(view.weight_chain_attached_to_mass(), "chain endpoint is recalculated from the mass transform")
	_expect(view.wind_glyph(state) == "←" and flag.rotation.z < 0.0, "wind direction and pennant orientation share the signed forecast")
	_expect(view.projected_sign_bounds(state).size.x > 360.0, "projected bounds come from the transformed sign mesh corners")
	var dusk_color: Color = sun.light_color
	var dusk_shadow_direction: Vector3 = sun.global_basis.z
	view.update_frame(state, "night", true)
	_expect(sun.light_color != dusk_color and sun.global_basis.z != dusk_shadow_direction, "day-phase changes real key-light color and cast-shadow direction")
	_expect(is_equal_approx(assembly.rotation.z, view.visual_angle(state)), "reduced motion keeps the model-driven board movement")
	_expect(not view.decorative_motion_enabled(), "reduced motion disables only decorative movement")
	var night_light: Color = sun.light_color
	var dawn_light: Color
	var noon_light: Color
	view.update_frame(state, "dawn", true)
	dawn_light = sun.light_color
	view.update_frame(state, "noon", true)
	noon_light = sun.light_color
	_expect(dawn_light != noon_light and noon_light != night_light and dawn_light != night_light, "dawn, noon and night use distinct actual 3D key-light colors")
	view.update_frame(state, "night", false)
	_expect(node_count == view.spatial_node_count(), "updates reuse the prebuilt scene nodes")
	_expect(body_mesh_id != 0 and body_mesh_id == view.find_child("SignFace", true, false).get_instance_id(), "updates reuse the same sign mesh instance")

func _test_seven_stage_visual_semantics(view: Control, state: Dictionary) -> void:
	state["forecast_visible"] = false
	state["wind_torque"] = 0.0
	state["target_angle"] = 0.035
	state["safe_limit"] = 0.13
	view.update_frame(state, "noon", false)
	var band: Vector2 = view.safe_angle_bounds(state)
	_expect(is_equal_approx(band.x, -0.095) and is_equal_approx(band.y, 0.165), "angle target band still uses the exact model tolerance")
	_expect(view.wind_glyph(state) == "←" and view.wind_display_label(state) == "靜風", "direction indicator retains its last signed wind while labeling a spent gust as calm")
	state["wind_torque"] = 0.12
	state["wind_direction"] = 1
	view.update_frame(state, "noon", false)
	_expect(view.wind_arrow_visible(state) and view.wind_glyph(state) == "→" and view.wind_display_label(state) == "當前風", "active wind remains readable through arrow, text, and the pennant")
	_expect(view.find_child("WindPennant", true, false).rotation.z > 0.0, "rightward wind turns the physical pennant in the opposite direction")
	state["wind_torque"] = -0.12
	state["wind_direction"] = -1
	view.update_frame(state, "noon", false)
	_expect(view.wind_arrow_visible(state) and view.wind_glyph(state) == "←" and view.wind_display_label(state) == "當前風", "negative active force keeps its sign and active-wind label")
	_expect(view.physical_motion_enabled(), "physical state remains visible in all settings")
	_expect(view.decorative_motion_enabled(), "normal mode retains its optional nonessential movement")

func _test_input_and_layout_compatibility(view: Control) -> void:
	var bounds: Rect2 = view.scene_bounds()
	var hud: Rect2 = view.hud_safe_rect()
	var panel: Rect2 = view.controls_panel_bounds()
	var playfield: Rect2 = view.playfield_bounds()
	_expect(bounds == View.SCENE_BOUNDS and bounds.end == View.DESIGN_SIZE, "presentation keeps the 1280x720 design coordinate contract")
	_expect(not playfield.intersects(hud) and bounds.encloses(playfield), "3D stage sits below the shared HUD safe area")
	_expect(bounds.encloses(panel) and panel.has_point(View.WEIGHT_RAIL.position) and panel.has_point(View.WEIGHT_RAIL.end), "original mouse rail and panel coordinates remain available")
	_expect(view._balance_from_x(View.WEIGHT_RAIL.position.x + 17.0) <= -0.99, "left pointer endpoint maps to minimum balance")
	_expect(view._balance_from_x(View.WEIGHT_RAIL.end.x - 17.0) >= 0.99, "right pointer endpoint maps to maximum balance")
	var emitted_balance: Array[float] = []
	view.balance_requested.connect(func(value: float) -> void: emitted_balance.append(value))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(View.WEIGHT_RAIL.position.x + 17.0, View.WEIGHT_RAIL.get_center().y)
	press.pressed = true
	view._gui_input(press)
	_expect(emitted_balance.size() == 1 and emitted_balance[0] <= -0.99, "actual rail press emits the same left endpoint value")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = Vector2(View.WEIGHT_RAIL.end.x - 17.0, View.WEIGHT_RAIL.get_center().y)
	view._gui_input(motion)
	_expect(emitted_balance.size() == 2 and emitted_balance[1] >= 0.99, "actual rail drag emits the right endpoint value")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	release.pressed = false
	view._gui_input(release)
	_expect(view.pivot_position().distance_to(view.projected_axle_position()) < 3.0, "reported pivot position matches the actual camera projection of the axle")
	var max_angle: Dictionary = {"angle": Model.IMPACT_ANGLE, "target_angle": 0.0, "safe_limit": 0.13}
	view.update_frame(max_angle, "noon", false)
	var projected: Rect2 = view.projected_sign_bounds(max_angle)
	_expect(not projected.intersects(view.stage_card_bounds()) and not projected.intersects(View.FORECAST_CARD_BOUNDS), "tilted sign mesh stays clear of the stage and wind cards: " + str(projected))
	_expect(not projected.intersects(view.controls_panel_bounds()), "maximum sign swing clears the fixed counterweight controls: " + str(projected))
	_expect(view.scene_bounds().encloses(projected) and not projected.intersects(view.hud_safe_rect()), "actual sign body remains in the viewport through maximum recoverable tilt: " + str(projected))

func _test_preserved_semantics(view: Control, state: Dictionary) -> void:
	var bounds: Rect2 = view.scene_bounds()
	var hud: Rect2 = view.hud_safe_rect()
	var gauge: Rect2 = view.target_zone_bounds()
	var panel: Rect2 = view.controls_panel_bounds()
	var projected: Rect2 = view.projected_sign_bounds(state)
	_expect(view.pivot_position().distance_to(view.projected_axle_position()) < 0.01, "reported pivot remains the projected world-space axle")
	_expect(bounds.encloses(gauge) and not gauge.intersects(hud), "angle target gauge stays below the shared HUD and inside the viewport")
	_expect(not View.STATUS_LINE_BOUNDS.intersects(View.WEIGHT_RAIL) and not View.INPUT_HELP_BOUNDS.intersects(View.WEIGHT_RAIL), "status and input copy keep distinct rows above/below the pointer rail")
	_expect(panel.encloses(View.STATUS_LINE_BOUNDS) and panel.encloses(View.INPUT_HELP_BOUNDS), "both explanation rows remain inside the paper controls panel")
	_expect(view.stage_card_bounds().position.y > hud.end.y and bounds.encloses(view.stage_card_bounds()), "stage card remains in the readable band below the shared HUD")
	var maximally_tilted: Dictionary = {"angle": Model.IMPACT_ANGLE, "target_angle": 0.0, "safe_limit": 0.13}
	view.update_frame(maximally_tilted, "noon", false)
	var impact_bounds: Rect2 = view.projected_sign_bounds(maximally_tilted)
	_expect(bounds.encloses(impact_bounds) and not impact_bounds.intersects(hud), "the real projected sign remains fully inside safe bounds at the recoverable limit")
	view.update_frame(state, "noon", false)
	state["angle"] = 0.42
	view.update_frame(state, "noon", false)
	_expect(is_equal_approx(view.visual_angle(state), 0.42 * 0.43), "displayed sign angle retains the original linear model mapping")
	_expect(is_equal_approx(view.shadow_offset(state).x, 0.42 * 72.0), "legacy shadow displacement helper retains its signed angle mapping")
	state["angle"] = -0.31
	state["wind_direction"] = -1
	state["forecast_visible"] = true
	state["forecast_torque"] = -0.18
	state["wind_torque"] = 0.0
	view.update_frame(state, "noon", false)
	_expect(view.wind_glyph(state) == "←" and view.wind_arrow_visible(state) and view.wind_display_label(state) == "預告風", "negative forecast direction remains explicit in both text and arrow")
	var expected_directions: Array[int] = [1, -1, 1, -1, -1, 1, -1]
	var expected_strengths: Array[float] = [0.22, 0.26, 0.19, 0.28, 0.23, 0.27, 0.21]
	for stage_index in range(Model.STAGE_COUNT):
		var torque: float = float(expected_directions[stage_index]) * expected_strengths[stage_index]
		var stage_state: Dictionary = {"stage": stage_index, "wind_direction": expected_directions[stage_index], "forecast_visible": true, "forecast_torque": torque, "wind_torque": 0.0}
		view.update_frame(stage_state, "noon", false)
		var pennant := view.find_child("WindPennant", true, false) as Node3D
		var expected_angle: float = (-1.0 if torque < 0.0 else 1.0) * lerpf(0.07, 0.24, clampf(absf(torque) / 0.28, 0.0, 1.0))
		_expect(view.wind_glyph(stage_state) == ("←" if torque < 0.0 else "→"), "stage %d forecast retains its actual signed direction" % (stage_index + 1))
		_expect(pennant != null and is_equal_approx(pennant.rotation.z, expected_angle), "stage %d pennant maps the model gust force to physical deflection" % (stage_index + 1))
	var calm_state: Dictionary = {"wind_direction": 1, "forecast_visible": false, "forecast_torque": 0.0, "wind_torque": 0.0}
	view.update_frame(calm_state, "noon", false)
	_expect(not view.wind_arrow_visible(calm_state) and view.wind_display_label(calm_state) == "靜風", "zero torque removes the arrow and labels the forecast calm")
	var noon_sun := view.find_child("HarborSun", true, false) as DirectionalLight3D
	var noon_key: Color = noon_sun.light_color
	var noon_direction: Vector3 = noon_sun.rotation_degrees
	view.update_frame(calm_state, "dusk", false)
	var dusk_key: Color = noon_sun.light_color
	var dusk_direction: Vector3 = noon_sun.rotation_degrees
	_expect(dusk_key != noon_key and dusk_direction != noon_direction, "dusk changes the actual 3D key light and shadow direction from noon")
	var dusk_sky: Color = view.sky_color()
	view.update_frame(calm_state, "dawn", false)
	var dawn_sky: Color = view.sky_color()
	view.update_frame(calm_state, "noon", false)
	var restored_noon_sky: Color = view.sky_color()
	view.update_frame(calm_state, "night", true)
	var night_sky: Color = view.sky_color()
	_expect(dusk_sky != dawn_sky and dawn_sky != restored_noon_sky and restored_noon_sky != night_sky, "dawn, noon, dusk and night retain distinct 3D scene palettes")
	_expect(view.physical_motion_enabled() and not view.decorative_motion_enabled(), "reduced motion removes decoration without removing apparatus feedback")
	var reduced_angle: float = view.visual_angle({"angle": -0.31})
	_expect(is_equal_approx(reduced_angle, -0.31 * 0.43) and view.wind_glyph({"wind_direction": -1}) == "←", "reduced motion preserves the actual angle and essential negative wind cue")
	var night_ink: Color = View.PALETTE_NIGHT[2]
	var night_control_paper: Color = View.PALETTE_NIGHT[6]
	var night_stage_paper: Color = View.PALETTE_NIGHT[6].darkened(0.03)
	var night_paper: Color = View.PALETTE_NIGHT[6].darkened(0.04)
	_expect(_contrast_ratio(night_ink, night_control_paper) >= 7.0, "actual night control-panel ink and paper retain strong text contrast")
	_expect(_contrast_ratio(night_ink, night_stage_paper) >= 7.0, "actual night stage-card ink and paper retain strong text contrast")
	_expect(_contrast_ratio(night_ink, night_paper) >= 7.0, "actual night forecast-card ink and paper retain strong text contrast")
	var dusk_ink: Color = View.PALETTE_DUSK[2]
	var dusk_paper: Color = View.PALETTE_DUSK[6].darkened(0.04)
	_expect(_contrast_ratio(dusk_ink, dusk_paper) >= 7.0, "actual dusk card ink and paper retain strong text contrast")
	view.update_frame(state, "noon", false)

func _test_actual_session_feedback(view: Control, fixture_viewport: SubViewport) -> void:
	var session := Session.new()
	session.size = View.DESIGN_SIZE
	fixture_viewport.add_child(session)
	session.start("game-008")
	session.set_process(false)
	view.reparent(session)
	session.presentation = view
	session.move_child(view, 0)
	session._layout_presentation()
	session._feedback("中心精準！", session.MINT)
	await process_frame
	await process_frame
	var feedback := session.minigame_hud.find_child("ContextFeedback", true, false) as Control
	_expect(feedback != null and feedback.is_visible_in_tree(), "actual session creates its visible contextual success feedback")
	if feedback == null: return
	var to_design := view.get_global_transform_with_canvas().affine_inverse()
	var feedback_rect := Rect2(to_design * feedback.get_global_rect().position, feedback.size * session.minigame_hud.scale / view.scale).grow(4.0)
	_expect(feedback.size.x <= 260.0 and feedback_rect.position.x > View.FORECAST_CARD_BOUNDS.position.x and feedback_rect.position.y > View.FORECAST_CARD_BOUNDS.end.y, "actual sign feedback occupies the right side below forecast and outside the apparatus sweep")
	_expect(not feedback_rect.intersects(view.stage_card_bounds()) and not feedback_rect.intersects(View.FORECAST_CARD_BOUNDS) and not feedback_rect.intersects(view.controls_panel_bounds()), "actual feedback including its shadow clears stage, forecast and counterweight-control cards")
	var camera := view.find_child("StageCamera", true, false) as Camera3D
	var title := view.find_child("SignTitle", true, false) as Label3D
	var mass := view.find_child("WeightForging", true, false) as MeshInstance3D
	for index in range(-27, 28):
		var angle := float(index) * 0.05
		view.update_frame({"angle": angle}, "noon", false)
		var board_rect: Rect2 = view.projected_sign_bounds()
		var title_rect := _projected_geometry_bounds(camera, title)
		var weight_rect := _projected_geometry_bounds(camera, mass)
		_expect(not feedback_rect.intersects(board_rect) and not feedback_rect.intersects(title_rect) and not feedback_rect.intersects(weight_rect), "actual success feedback leaves the sign, its title and hanging mass clear at angle %.3f: feedback=%s sign=%s title=%s" % [angle, str(feedback_rect), str(board_rect), str(title_rect)])
	session._refresh_hud(true)
	await process_frame
	await process_frame
	_expect(feedback.position.x >= 990.0 and feedback.position.y > View.FORECAST_CARD_BOUNDS.end.y, "later HUD refresh/layout preserves the side feedback anchor")

func _projected_geometry_bounds(camera: Camera3D, geometry: GeometryInstance3D) -> Rect2:
	geometry.force_update_transform()
	var bounds := geometry.get_aabb()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				var point := camera.unproject_position(geometry.global_transform * Vector3(x, y, z))
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)

func _contrast_ratio(first: Color, second: Color) -> float:
	var a := _relative_luminance(first)
	var b := _relative_luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)

func _relative_luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	for index in channels.size():
		var value: float = channels[index]
		channels[index] = value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
