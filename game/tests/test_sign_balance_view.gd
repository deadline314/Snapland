extends SceneTree

const Model = preload("res://game/minigames/sign_balance_model.gd")
const View = preload("res://game/minigames/sign_balance_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model = Model.new()
	model.reset()
	var state: Dictionary = model.snapshot().duplicate(true)
	var view = View.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_size(View.DESIGN_SIZE)
	get_root().add_child(view)
	view.update_frame(state, "noon", false)
	_test_layout_and_actual_angle(view, state)
	_test_forecast_and_target_band(view, state)
	_test_time_palette_and_reduced_motion(view, state)
	if failures == 0:
		print("Sign balance view: %d checks passed" % checks)
		view.queue_free()
		quit(0)
	else:
		push_error("Sign balance view: %d check(s) failed" % failures)
		view.queue_free()
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_layout_and_actual_angle(view, state: Dictionary) -> void:
	var bounds: Rect2 = view.scene_bounds()
	var hud: Rect2 = view.hud_safe_rect()
	var sign_bounds: Rect2 = view.projected_sign_bounds(state)
	var gauge: Rect2 = view.target_zone_bounds()
	var panel: Rect2 = view.controls_panel_bounds()
	var stage_card: Rect2 = view.stage_card_bounds()
	_expect(view.pivot_position() == View.BOARD_CENTER, "sign, axle caps, support and angle gauge share one visible pivot")
	_expect(bounds.position.y > hud.end.y and bounds.end.x <= View.DESIGN_SIZE.x and bounds.end.y <= View.DESIGN_SIZE.y, "illustration occupies the 1280x720 area beneath the HUD")
	_expect(not sign_bounds.intersects(hud) and bounds.encloses(sign_bounds), "large pivoted sign stays inside the safe portrait bounds above and below its full rotation")
	_expect(sign_bounds == Rect2(344.0, 232.0, 592.0, 202.0), "projected bounds include the 14px backing, both side pivot caps, and antialias fringe")
	_expect(bounds.encloses(gauge) and not gauge.intersects(hud), "visible level-angle target band remains inside the gameplay area")
	_expect(bounds.encloses(panel) and panel.has_point(View.WEIGHT_RAIL.position) and panel.has_point(View.WEIGHT_RAIL.end), "paper control panel contains the complete draggable counterweight rail")
	_expect(bounds.encloses(stage_card) and stage_card.end.y < View.BOARD_CENTER.y - View.BOARD_SIZE.y * 0.5, "stage and forecast text sit on a dedicated plate above the sign")
	_expect(not View.STATUS_LINE_BOUNDS.intersects(View.WEIGHT_RAIL) and not View.INPUT_HELP_BOUNDS.intersects(View.WEIGHT_RAIL) and panel.encloses(View.INPUT_HELP_BOUNDS), "status copy and the two-direction input hint have separate clear rows")
	var chinese_title := View.FONT.get_string_size("潮汐花園", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var english_title := View.FONT.get_string_size("HARBOR GARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_expect(chinese_title <= 320.0 and english_title <= 220.0, "the two-line sign title fits its carved face without truncation")
	model_angle_update(view, state, 0.42)
	_expect(is_equal_approx(view.visual_angle(state), 0.42 * 0.43), "sign angle stays linearly tied to the model's physical pivot angle")
	_expect(is_equal_approx(view.shadow_offset(state).x, 0.42 * 72.0), "ground shadow displacement follows the same angle sign and magnitude")
	state["angle"] = Model.IMPACT_ANGLE
	var edge_sign: Rect2 = view.projected_sign_bounds(state)
	_expect(bounds.encloses(edge_sign) and not edge_sign.intersects(hud), "sign remains clipped safely at the recoverable outer angle")

func model_angle_update(view, state: Dictionary, angle: float) -> void:
	state["angle"] = angle
	view.update_frame(state, "noon", false)

func _test_forecast_and_target_band(view, state: Dictionary) -> void:
	state["wind_direction"] = -1
	state["forecast_visible"] = true
	state["forecast_torque"] = -0.18
	state["target_angle"] = 0.035
	state["safe_limit"] = 0.13
	view.update_frame(state, "day", false)
	var band: Vector2 = view.safe_angle_bounds(state)
	_expect(view.wind_glyph(state) == "←", "forecast direction uses an arrow, not color alone")
	_expect(view.wind_arrow_visible(state) and view.wind_display_label(state) == "預告風", "forecast arrow uses the upcoming force and is labelled separately from active wind")
	_expect(is_equal_approx(band.x, -0.095) and is_equal_approx(band.y, 0.165), "drawn safety band is centered on the active target and has the model's exact tolerance")
	state["wind_direction"] = 1
	_expect(view.wind_glyph(state) == "→", "rightward gust uses the matching right arrow")
	state["forecast_visible"] = false
	state["wind_torque"] = 0.0
	_expect(not view.wind_arrow_visible(state) and view.wind_display_label(state) == "靜風", "a spent gust is explicitly calm instead of showing a stale rightward arrow")
	state["wind_torque"] = -0.12
	_expect(view.wind_arrow_visible(state) and view.wind_display_label(state) == "當前風", "active arrow direction and strength come from actual signed torque")

func _test_time_palette_and_reduced_motion(view, state: Dictionary) -> void:
	state["angle"] = -0.31
	view.update_frame(state, "noon", false)
	var day_sky: Color = view.sky_color()
	view.update_frame(state, "dawn", false)
	var dawn_sky: Color = view.sky_color()
	view.update_frame(state, "dusk", false)
	var angle_normal: float = view.visual_angle(state)
	var glyph_normal: String = view.wind_glyph(state)
	var dusk_sky: Color = view.sky_color()
	_expect(view.palette_phase() == "dusk", "dusk selects the warm harbor palette")
	_expect(day_sky != dusk_sky and dawn_sky != day_sky and dawn_sky != dusk_sky, "dawn, noon and dusk use materially distinct harbor palettes")
	_expect(view.physical_motion_enabled() and view.decorative_motion_enabled(), "normal mode retains physical sign response and decorative motion")
	view.update_frame(state, "night", true)
	_expect(view.palette_phase() == "night", "night phase changes palette independently of physical state")
	_expect(view.sky_color() != dusk_sky, "night has its own readable palette rather than a dark overlay on dusk")
	_expect(_contrast_ratio(View.PALETTE_NIGHT[2], View.PALETTE_NIGHT[6]) > 7.0, "night control labels retain strong contrast on the dedicated pale paper panel")
	_expect(_contrast_ratio(View.PALETTE_NIGHT[2], View.PALETTE_NIGHT[6]) > 7.0, "night stage and forecast labels retain strong contrast on their pale plate")
	_expect(view.visual_angle(state) == angle_normal and view.wind_glyph(state) == glyph_normal, "reduced motion preserves real board angle and essential wind direction")
	_expect(view.physical_motion_enabled() and not view.decorative_motion_enabled(), "reduced motion suppresses decoration but leaves core physical angle visible")

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
