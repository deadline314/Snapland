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
	_test_time_phases_and_reduced_motion(view, live_snapshot)
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
