extends SceneTree

const Model = preload("res://game/minigames/kite_flight_model.gd")
const FlightView = preload("res://game/minigames/kite_flight_view.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view = FlightView.new()
	view.size = Vector2(1280.0, 720.0)
	root.add_child(view)
	await process_frame
	var model = Model.new()
	model.reset()
	var live_snapshot: Dictionary = model.snapshot()
	view.update_frame(live_snapshot, "playing", false, "noon")
	_check(view.size == Vector2(1280.0, 720.0), "view uses the shared 1280x720 design plane")
	_check(view.field_rect() == Rect2(80.0, 155.0, 1110.0, 470.0), "side-flight field stays clear of the global top HUD and bottom instruments")
	_check(not view.field_rect().intersects(view.HUD_RECT), "playfield does not overlap the reserved global HUD")
	_check(is_equal_approx(view.kite_screen_center().x, 360.0), "camera scroll keeps the kite at its authored screen anchor")
	_check(is_equal_approx(view.kite_screen_center().y, view.height_to_screen_y(model.height)), "kite center uses the model height mapping")
	_check(is_equal_approx(view.height_to_screen_y(110.0), view.HEIGHT_TOP) and is_equal_approx(view.height_to_screen_y(650.0), view.HEIGHT_BOTTOM), "minimum and maximum model heights map to the flight plane bounds")
	_check(not view.kite_visual_bounds().intersects(view.HUD_RECT), "union of actual kite, tails, shadow and tether stays clear of the top HUD")
	_check(view.kite_visual_bounds().end.y < 637.0, "actual component union stays above the fixed instrument shelf")
	_check(view.kite_visual_bounds().encloses(_actual_kite_components_bounds(view)), "reported visual bounds enclose every actual drawn kite component")
	_check(view.ring_screen_center(0).x < view.ring_screen_center(4).x, "ring order follows the world route across the side camera")
	_check(view.geometry_revision() == view.GEOMETRY_REVISION, "static geometry cache is built for the current revision")
	var revision := view.geometry_revision()
	var first_markers: Array = live_snapshot.eventmarkers
	for ring_index in 5:
		var center: Vector2 = view.ring_screen_center(ring_index)
		var expected_x: float = 360.0 + (Model.RING_X[ring_index] - model.x) * view.WORLD_X_SCALE
		var expected_y: float = view.height_to_screen_y(Model.RING_HEIGHT[ring_index])
		var bounds: Rect2 = view.ring_visual_bounds(ring_index)
		_check(center.is_equal_approx(Vector2(expected_x, expected_y)), "ring %d projection matches world-plane coordinates" % ring_index)
		_check(view.field_rect().encloses(bounds), "ring %d full outer ellipse fits the playable field at route start" % ring_index)
	_check(view.ring_status(0) == "next" and view.ring_status(1) == "silhouette", "only the next unscored hoop receives the solid active treatment")
	var scroll_snapshot: Dictionary = live_snapshot.duplicate()
	scroll_snapshot["x"] = model.x + 250.0
	scroll_snapshot["height"] = 110.0
	view.update_frame(scroll_snapshot, "playing", false, "noon")
	_check(is_equal_approx(view.ring_screen_center(0).x, 360.0 + (Model.RING_X[0] - float(scroll_snapshot.x)) * view.WORLD_X_SCALE), "camera scroll moves hoops by the model world distance")
	_check(view.kite_visual_bounds().position.y >= view.HUD_RECT.end.y, "full kite envelope at minimum altitude clears global HUD")
	_check(view.kite_visual_bounds().encloses(_actual_kite_components_bounds(view)), "low-altitude bound encloses rendered parts and every tail flag")
	var upper_snapshot: Dictionary = scroll_snapshot.duplicate()
	upper_snapshot["height"] = 650.0
	view.update_frame(upper_snapshot, "playing", false, "noon")
	_check(view.kite_visual_bounds().end.y < 637.0, "high-altitude bound clears lower instruments")
	_check(view.kite_visual_bounds().encloses(_actual_kite_components_bounds(view)), "high-altitude bound encloses every rendered polygon and tether point")
	_check(is_equal_approx(view.kite_screen_center().y, view.HEIGHT_BOTTOM), "maximum numeric height maps to lower safe playfield band")
	_check(is_same(first_markers, model.snapshot().eventmarkers), "model event marker array is passed through without copying")

	_test_actual_extreme_geometry(view)
	_test_marker_and_legend_shapes(view)
	_test_actual_wind_environment(view)
	_test_time_phases_and_reduced_motion(view, live_snapshot)
	_test_caption_contrast(view, live_snapshot)
	_test_cache_revision(view, live_snapshot, revision)
	view.queue_free()
	await process_frame
	if failures == 0:
		print("Kite flight view: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Kite flight view: %d of %d checks failed" % [failures, checks])
		quit(1)

func _actual_kite_components_bounds(view: Control) -> Rect2:
	var components: Array[PackedVector2Array] = [view._kite_body, view._kite_panel_left, view._kite_panel_right, view._kite_panel_top, view._kite_shadow, view._tether_points, view._bridle_line, view._spool_disc, view._spool_ring]
	for flag in view._tail_flags:
		components.append(flag)
	var first := true
	var bounds := Rect2()
	for polygon in components:
		for point in polygon:
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	return bounds.grow(1.5)

func _test_actual_extreme_geometry(view: Control) -> void:
	for height in [110.0, 650.0]:
		for wind in [-185.0, 185.0]:
			for vy in [-205.0, 205.0]:
				var snapshot: Dictionary = {"x": 120.0, "height": height, "vy": vy, "actualwind": wind, "forecast": -wind, "tension": 0.95, "tension_warning": true, "tension_risk": 1.0, "eventmarkers": [], "nextRing": 0}
				view.update_frame(snapshot, "playing", false, "dusk")
				_check(view.kite_visual_bounds().encloses(_actual_kite_components_bounds(view)), "extreme actual geometry union contains height=%s wind=%s vy=%s" % [height, wind, vy])
				_check(view.kite_visual_bounds().position.y >= view.FIELD_RECT.position.y and view.kite_visual_bounds().end.y <= view.FIELD_RECT.end.y, "extreme kite body/tail/tether stays inside safe flight band")
				_check(not view.kite_visual_bounds().intersects(view.HUD_RECT) and view.kite_visual_bounds().end.y < 637.0, "extreme kite geometry avoids HUD and instrument shelf")
				_check(view.warning_triangle_bounds().position.is_equal_approx(Vector2(856.0, 646.0)), "warning indicator remains at its actual screen transform")
	view.update_frame({"x": 120.0, "height": 380.0, "vy": 0.0, "actualwind": 0.0, "forecast": 0.0, "eventmarkers": []}, "playing", true, "noon")
	_check(view._kite_roll == 0.0 and view.kite_visual_bounds().encloses(_actual_kite_components_bounds(view)), "reduced-motion extreme transitions preserve safe component bounds")

func _test_marker_and_legend_shapes(view: Control) -> void:
	var markers: Array[Dictionary] = [
		{"ring": 0, "kind": "center"},
		{"ring": 1, "kind": "edge"},
		{"ring": 2, "kind": "miss"},
		{"ring": 3, "kind": "line_snap"}
	]
	var event_snapshot: Dictionary = {"x": 120.0, "height": 380.0, "eventmarkers": markers, "nextRing": 4}
	view.update_frame(event_snapshot, "playing", false, "noon")
	_check(view.ring_status(0) == "center", "center marker is retained as a scored center result")
	_check(view.ring_status(1) == "edge", "edge marker has its own status")
	_check(view.ring_status(2) == "miss", "missed ring remains a failure status instead of a success color")
	_check(view.ring_status(3) == "line_snap", "line snap is visible as a distinct flight event")
	_check(view.legend_style("actual") == "solid_vertical_arrow", "current wind uses a solid directional arrow")
	_check(view.legend_style("forecast") == "dashed_open_vertical_arrow", "forecast wind uses a dashed hollow arrow")
	_check(view._actual_wind == 0.0 and view._forecast_wind == 0.0, "calm conditions preserve both actual and forecast readings")
	var windy: Dictionary = {"x": 120.0, "height": 380.0, "actualwind": -120.0, "forecast": 95.0, "forecast_seconds": 1.25, "eventmarkers": markers, "nextRing": 4}
	view.update_frame(windy, "playing", false, "noon")
	_check(view._actual_wind == -120.0 and view._forecast_wind == 95.0, "actual and future wind values remain separate in both legends")
	var origin := Vector2(468.0, 668.0)
	_check(view.wind_arrow_tip(origin, 95.0).y < origin.y and view.wind_arrow_tip(origin, -95.0).y > origin.y, "positive lift points upward and negative lift points downward in both wind legends")
	_check(view.wind_arrow_tip(origin, 185.0).y >= 637.0 and view.wind_arrow_tip(origin, -185.0).y <= 708.0, "full wind arrows stay inside the instrument shelf")
	_check(view.tail_wind_offset(95.0, 34.0) < 0.0 and view.tail_wind_offset(-95.0, 34.0) > 0.0, "tail flags respond vertically in the same direction as model wind force")
	_check(view.warning_triangle_bounds().position.is_equal_approx(Vector2(856.0, 646.0)), "tension warning triangle is transformed to its real instrument position")
	_check(view._event_markers.size() == 4, "markers are consumed directly from the supplied snapshot")

func _test_time_phases_and_reduced_motion(view: Control, source_snapshot: Dictionary) -> void:
	var motion_snapshot := source_snapshot.duplicate()
	motion_snapshot["vy"] = 80.0
	motion_snapshot["elapsed"] = 0.17
	var colors: Array[Color] = []
	var lights: Array[Vector2] = []
	for phase_name in ["dawn", "noon", "dusk", "night"]:
		view.update_frame(motion_snapshot, "playing", false, phase_name)
		colors.append(view._sky_color())
		lights.append(view._light_center)
	_check(colors.size() == 4 and colors[0] != colors[1] and colors[1] != colors[2] and colors[2] != colors[3], "four times of day have distinct sky and lighting palettes")
	_check(lights[0] != lights[1] and lights[1] != lights[2] and lights[2] != lights[3], "light source follows a plausible path through dawn, noon, dusk and night")
	view.update_frame(motion_snapshot, "playing", false, "dusk")
	var normal_roll: float = view._kite_roll
	var normal_tail_phase: float = view._tail_wave(0)
	view.update_frame(motion_snapshot, "playing", true, "dusk")
	_check(view._kite_roll == 0.0 and normal_roll != 0.0, "reduced motion keeps kite position while suppressing decorative tilt")
	_check(view._tail_wave(0) == 0.0 and normal_tail_phase != 0.0, "reduced motion removes tail flutter without hiding wind indicators")
	_check(view.legend_style("actual") == "solid_vertical_arrow" and view.legend_style("forecast") == "dashed_open_vertical_arrow", "reduced motion retains both distinct wind legends")

func _test_caption_contrast(view: Control, source_snapshot: Dictionary) -> void:
	var events: Array[String] = ["", "miss", "edge", "center", "line_snap"]
	var phases: Array[String] = ["playing", "paused", "result"]
	var night_readable := true
	var dusk_readable := true
	for time_phase in ["night", "dusk"]:
		view.update_frame(source_snapshot, "playing", false, time_phase)
		var sky: Color = view._sky_color()
		var backplate: Color = view._flight_caption_backplate_color(time_phase)
		var displayed_background := _composite_color(backplate, sky)
		for flight_phase in phases:
			for event in events:
				var foreground: Color = view._flight_caption_color(time_phase, flight_phase, event, _legacy_caption_tint(view, event))
				var readable := _contrast_ratio(foreground, displayed_background) >= 4.5
				if time_phase == "night": night_readable = night_readable and readable
				else: dusk_readable = dusk_readable and readable
	_check(night_readable, "night generic, four event and result captions reach 4.5 contrast after sky/backplate compositing")
	_check(dusk_readable, "dusk generic, four event and result captions reach 4.5 contrast after sky/backplate compositing")
	var daytime_parity := true
	for time_phase in ["dawn", "noon"]:
		for flight_phase in phases:
			for event in events:
				var actual: Color = view._flight_caption_color(time_phase, flight_phase, event, _legacy_caption_tint(view, event))
				daytime_parity = daytime_parity and actual == _legacy_caption_tint(view, event)
			daytime_parity = daytime_parity and view._flight_caption_backplate_color(time_phase).a == 0.0
	_check(daytime_parity, "dawn/noon generic, event and result captions plus background remain byte-equivalent")
	view.update_frame(source_snapshot, "result", false, "night")
	var result_tint: Color = view._flight_caption_color("night", view._phase, "", _legacy_caption_tint(view, ""))
	var result_background := _composite_color(view._flight_caption_backplate_color("night"), view._sky_color())
	_check(_contrast_ratio(result_tint, result_background) >= 4.5, "actual singular result phase keeps the generic caption readable at night")

func _legacy_caption_tint(view: Control, event: String) -> Color:
	match event:
		"miss", "line_snap": return view.CORAL
		"edge": return view.OCHRE
		"center": return view.SEA_GLASS
		_: return Color(view.INK, 0.8)

func _composite_color(foreground: Color, background: Color) -> Color:
	var inverse_alpha := 1.0 - foreground.a
	return Color(
		foreground.r * foreground.a + background.r * inverse_alpha,
		foreground.g * foreground.a + background.g * inverse_alpha,
		foreground.b * foreground.a + background.b * inverse_alpha,
		1.0
	)

func _contrast_ratio(foreground: Color, background: Color) -> float:
	var foreground_luminance := _relative_luminance(foreground)
	var background_luminance := _relative_luminance(background)
	var lighter := maxf(foreground_luminance, background_luminance)
	var darker := minf(foreground_luminance, background_luminance)
	return (lighter + 0.05) / (darker + 0.05)

func _relative_luminance(color: Color) -> float:
	var red := _linear_channel(color.r)
	var green := _linear_channel(color.g)
	var blue := _linear_channel(color.b)
	return red * 0.2126 + green * 0.7152 + blue * 0.0722

func _linear_channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)

func _test_actual_wind_environment(view: Control) -> void:
	var calm: Dictionary = {"x": 120.0, "height": 380.0, "vy": 0.0, "elapsed": 0.0, "actualwind": 0.0, "forecast": 0.0, "eventmarkers": [], "nextRing": 0}
	view.update_frame(calm, "playing", false, "noon")
	var calm_path: PackedVector2Array = view._wind_streamers[0].duplicate()
	var calm_pennant_y: float = view._beacon_pennant[1].y
	var streamer_array: Array[PackedVector2Array] = view._wind_streamers
	var positive: Dictionary = calm.duplicate(true)
	positive["actualwind"] = 90.0
	positive["forecast"] = -160.0
	view.update_frame(positive, "playing", false, "noon")
	var positive_lift: float = view._wind_streamer_lift(0)
	var positive_pennant_y: float = view._beacon_pennant[1].y
	_check(positive_lift < 0.0 and positive_pennant_y < calm_pennant_y, "positive actual lift curves the visible wind lane and beacon pennant upward")
	var wind_lanes_clear_hud := true
	for streamer in view._wind_streamers:
		for point in streamer:
			if point.y <= view.HUD_RECT.end.y or point.y >= view.FIELD_RECT.end.y:
				wind_lanes_clear_hud = false
	_check(wind_lanes_clear_hud, "wind lanes remain below the reserved HUD and inside the flight field")
	var strong_positive: Dictionary = positive.duplicate(true)
	strong_positive["actualwind"] = 185.0
	view.update_frame(strong_positive, "playing", false, "noon")
	_check(absf(view._wind_streamer_lift(0)) > absf(positive_lift), "stronger actual lift produces a visibly larger coastal flow bend")
	var negative: Dictionary = positive.duplicate(true)
	negative["actualwind"] = -90.0
	view.update_frame(negative, "playing", false, "noon")
	_check(view._wind_streamer_lift(0) > 0.0 and view._beacon_pennant[1].y > calm_pennant_y, "negative actual lift reverses the wind lane and pennant direction")
	var forecast_only: Dictionary = calm.duplicate(true)
	forecast_only["forecast"] = 185.0
	view.update_frame(forecast_only, "playing", false, "noon")
	_check(view._wind_streamers[0] == calm_path, "forecast-only change never moves the actual-wind scenery")
	var still_a: Dictionary = calm.duplicate(true)
	still_a["actualwind"] = 120.0
	still_a["elapsed"] = 1.25
	view.update_frame(still_a, "playing", true, "noon")
	var reduced_path: PackedVector2Array = view._wind_streamers[0].duplicate()
	var reduced_pennant: PackedVector2Array = view._beacon_pennant.duplicate()
	var reduced_flags: Array[PackedVector2Array] = []
	for flag in view._tail_flags:
		reduced_flags.append(flag.duplicate())
	var still_b: Dictionary = still_a.duplicate(true)
	still_b["elapsed"] = 8.75
	view.update_frame(still_b, "playing", true, "noon")
	_check(view._wind_streamers[0] == reduced_path and view._beacon_pennant == reduced_pennant, "reduced motion freezes wind decoration across elapsed-time changes")
	_check(view._tail_flags == reduced_flags, "reduced motion keeps each tail flag still")
	var reduced_negative: Dictionary = still_b.duplicate(true)
	reduced_negative["actualwind"] = -120.0
	view.update_frame(reduced_negative, "playing", true, "noon")
	_check(view._wind_streamer_lift(0) > 0.0, "reduced motion preserves the correct static direction for changed actual wind")
	_check(is_same(view._wind_streamers, streamer_array), "wind geometry container is reused instead of rebuilt per frame")
	_check(absf(view._parallax_offset(520.0, 0.17)) > absf(view._parallax_offset(520.0, 0.09)), "near cliff moves faster than far cliff to reinforce forward travel")
	_check(view._ring_color("next") != view._ring_color("silhouette"), "the solid current ring remains visually distinct from pale future rings")
	var compact_wind_paths: bool = view._wind_streamers.size() == 3
	for streamer in view._wind_streamers:
		if streamer.size() < 2 or streamer[-1].x - streamer[0].x > 260.0:
			compact_wind_paths = false
	_check(compact_wind_paths, "coastal wind is drawn as three compact traces instead of full-width parallel lines")
	var arch_peaks_clear_shelf: bool = view._cliff_arches.size() == 3
	for arch in view._cliff_arches:
		var peak_y: float = INF
		for point in arch:
			peak_y = minf(peak_y, point.y)
		if peak_y >= 637.0:
			arch_peaks_clear_shelf = false
	_check(arch_peaks_clear_shelf, "varied cliff-arch openings begin above the fixed instrument shelf")

func _test_cache_revision(view: Control, source_snapshot: Dictionary, revision: int) -> void:
	var cloud_cache: Array = view._clouds
	var wave_cache: Array = view._sea_wave_paths
	var landmark_body: PackedVector2Array = view._lighthouse_body
	for index in 48:
		view.update_frame(source_snapshot, "playing", index % 2 == 0, ["dawn", "noon", "dusk", "night"][index % 4])
	_check(view.geometry_revision() == revision, "repeated frames reuse geometry cache without revision churn")
	_check(is_same(view._clouds, cloud_cache) and is_same(view._sea_wave_paths, wave_cache) and is_same(view._lighthouse_body, landmark_body), "harbor print geometry arrays keep stable identity across repeated frames")
	_check(is_same(view._event_markers, source_snapshot.eventmarkers), "repeated frames keep the same marker array reference")
func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Kite flight view: " + message)
