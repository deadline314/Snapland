extends "res://game/tests/native_fountain_review.gd"

var _result_snapshot: Dictionary = {}
var _finish_state: Dictionary = {}
var _retry_snapshot: Dictionary = {}
var _confirmed_retry_snapshot: Dictionary = {}
var _wall_deadline_msec: int = 0

## GPU review fixture. Game progress comes from physical controls sent through
## the live park, HUD and session input paths; it never edits a result field.
func _run() -> void:
	_wall_deadline_msec = Time.get_ticks_msec() + 300000
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native sign balance review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(3)
	if not is_instance_valid(main): return
	if not await _launch_sign_balance(): return
	var practice_session: Control = main.session
	practice_session.finished.connect(_capture_result.bind(practice_session), CONNECT_ONE_SHOT)
	if not await _check_pointer_and_pause_retry(practice_session): return
	if not practice_session.practice_mode:
		await _fail("The actual practice action did not mark the restarted route as practice")
		return
	if not await _drive_seven_stages(practice_session, true): return
	if main.modal_kind != "result" or not bool(_result_snapshot.get("practice", false)) or not bool(_result_snapshot.get("success", false)):
		await _fail("Assisted reduced-motion route did not reach its real practice result")
		return
	if progress.normal_count() != 0 or progress.devil_count("welcome") != 0 or progress.photos.has("photo-welcome-game-8") or progress.photos.has("photo-welcome-devil-8"):
		await _fail("Practice result wrote a game-008 photo or collection count")
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(main): return
	if not main._capture(".review/native-sign-balance-practice-result.png"):
		await _fail("Could not capture the real assisted/reduced-motion practice result")
		return
	if not await _activate_main_button("返回遊園", "return from game-008 practice result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "practice result return to park"): return
	if not is_instance_valid(main): return
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	if not await _launch_sign_balance(): return
	var formal_session: Control = main.session
	_result_snapshot.clear()
	_finish_state.clear()
	formal_session.finished.connect(_capture_result.bind(formal_session), CONNECT_ONE_SHOT)
	if not await _drive_seven_stages(formal_session, false): return
	if main.modal_kind != "result" or not bool(_result_snapshot.get("success", false)) or not bool(_result_snapshot.get("devil", false)):
		await _fail("Seven actual precise stages did not produce the formal devil result: %s" % str(_result_snapshot))
		return
	if int(_result_snapshot.get("score", -1)) != 700 or int(_finish_state.get("precise_stages", -1)) != 7 or int(_finish_state.get("impacts", -1)) != 0:
		await _fail("Latched sign result differs from seven precise, impact-free model stages: result=%s model=%s" % [str(_result_snapshot), str(_finish_state)])
		return
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has("photo-welcome-game-8") or not progress.photos.has("photo-welcome-devil-8"):
		await _fail("Formal result did not persist exactly one game-008 ordinary and devil photo")
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(main): return
	if not main._capture(".review/native-sign-balance-formal-result-700.png"):
		await _fail("Could not capture naturally earned game-008 score summary")
		return
	print("PASS: game-008 park launch, live weight controls, pointer rail, pause/resume, confirmed retry reset, reduced-motion practice without awards, and seven-stage formal devil result")
	await main._quit_game()

func _launch_sign_balance() -> bool:
	var found := false
	for point in main.world.points:
		if point.id != "game-008": continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		await _fail("Sign balance station game-008 is missing from the real park")
		return false
	var deadline := _wall_deadline_ms(3000)
	while main.world.nearest.get("id", "") != "game-008" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not is_instance_valid(main): return false
	if main.world.nearest.get("id", "") != "game-008":
		await _fail("Sign balance station did not become the nearest interaction")
		return false
	_key(KEY_E)
	deadline = _wall_deadline_ms(2500)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not is_instance_valid(main): return false
	if main.modal_kind != "game_info":
		await _fail("Native E input did not open game-008 station details")
		return false
	if not await _activate_main_button("開始遊玩", "start sign balance"): return false
	if not is_instance_valid(main): return false
	deadline = _wall_deadline_ms(2500)
	while main.session == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not is_instance_valid(main): return false
	if main.session == null or main.session.game_id != "game-008":
		await _fail("Native Start click did not launch game-008")
		return false
	var spatial_presentation: Control = main.session.presentation
	var stage := spatial_presentation.find_child("SpatialStage", true, false) as SubViewportContainer
	var camera := spatial_presentation.find_child("StageCamera", true, false) as Camera3D
	var mass := spatial_presentation.find_child("Counterweight", true, false) as Node3D
	if stage == null or camera == null or mass == null or not camera.current:
		await _fail("Game-008 launch did not create its live 3D sign apparatus, camera and counterweight")
		return false
	await _frames(2)
	if not _live_session(main.session): return false
	return await _check_rendered_stage(main.session)

func _check_rendered_stage(session: Control) -> bool:
	# Inspect the same completed GPU frame in the source texture and final
	# composited viewport. Node/transform checks alone missed the opaque BG.
	await RenderingServer.frame_post_draw
	if not _live_session(session): return false
	var presentation: Control = session.presentation
	var stage := presentation.find_child("SpatialStage", true, false) as SubViewportContainer
	var hud: Control = session.minigame_hud
	if stage == null or stage.z_index != 0 or not stage.z_as_relative or not stage.show_behind_parent or stage.mouse_filter != Control.MOUSE_FILTER_IGNORE or presentation.z_index != session.z_index or hud.z_index != presentation.z_index or hud.get_parent() != presentation.get_parent() or presentation.get_index() >= hud.get_index():
		await _fail("Live canvas order must be session background, 3D stage, local paper overlays, then clickable HUD sibling")
		return false
	if not await _check_live_feedback_clearance(session): return false
	var source_viewport := stage.get_child(0) as SubViewport
	if source_viewport == null:
		await _fail("Live spatial stage has no SubViewport render target")
		return false
	var source_image: Image = source_viewport.get_texture().get_image()
	var final_image: Image = get_viewport().get_texture().get_image()
	if source_image == null or source_image.is_empty() or final_image == null or final_image.is_empty():
		await _fail("Completed sign GPU frame returned an empty source or final viewport texture")
		return false
	# These samples cover the mechanism below the transient HUD feedback bar
	# and above the paper controls; score/stage/forecast cards cannot pass it.
	var source_min := Vector3(INF, INF, INF)
	var source_max := Vector3(-INF, -INF, -INF)
	var final_min := Vector3(INF, INF, INF)
	var final_max := Vector3(-INF, -INF, -INF)
	var matched := 0
	var samples := 0
	for y in range(324, 490, 12):
		for x in range(420, 861, 12):
			var design_point := Vector2(x, y)
			var source_point := Vector2i(design_point / presentation.DESIGN_SIZE * Vector2(source_image.get_size()))
			var final_point := Vector2i(presentation.get_global_transform_with_canvas() * design_point)
			if not Rect2i(Vector2i.ZERO, source_image.get_size()).has_point(source_point) or not Rect2i(Vector2i.ZERO, final_image.get_size()).has_point(final_point):
				await _fail("Central mechanism render samples fell outside source/final viewport bounds")
				return false
			var source_color := source_image.get_pixelv(source_point)
			var final_color := final_image.get_pixelv(final_point)
			var source_rgb := Vector3(source_color.r, source_color.g, source_color.b)
			var final_rgb := Vector3(final_color.r, final_color.g, final_color.b)
			source_min = source_min.min(source_rgb)
			source_max = source_max.max(source_rgb)
			final_min = final_min.min(final_rgb)
			final_max = final_max.max(final_rgb)
			if source_rgb.distance_to(final_rgb) < 0.08: matched += 1
			samples += 1
	var source_range := source_max.distance_to(source_min)
	var final_range := final_max.distance_to(final_min)
	if source_range < 0.12 or final_range < 0.12 or float(matched) / float(samples) < 0.85:
		await _fail("3D sign must render nonflat pixels and reach the visible central viewport: source_range=%.3f final_range=%.3f matched=%d/%d" % [source_range, final_range, matched, samples])
		return false
	print("Sign balance rendered stage: source_range=%.3f final_range=%.3f matched=%d/%d" % [source_range, final_range, matched, samples])
	return true

func _check_live_feedback_clearance(session: Control) -> bool:
	var presentation: Control = session.presentation
	var feedback := session.minigame_hud.find_child("ContextFeedback", true, false) as Control
	if feedback == null:
		await _fail("Live contextual feedback node is missing")
		return false
	if not feedback.is_visible_in_tree(): return true
	var to_design := presentation.get_global_transform_with_canvas().affine_inverse()
	var feedback_rect := Rect2(to_design * feedback.get_global_rect().position, feedback.size * session.minigame_hud.scale / presentation.scale).grow(4.0)
	var camera := presentation.find_child("StageCamera", true, false) as Camera3D
	var title := presentation.find_child("SignTitle", true, false) as Label3D
	var mass := presentation.find_child("WeightForging", true, false) as MeshInstance3D
	var board_rect: Rect2 = presentation.projected_sign_bounds()
	var title_rect := _projected_geometry_bounds(camera, title)
	var weight_rect := _projected_geometry_bounds(camera, mass)
	if not is_equal_approx(feedback.size.x, 420.0) or feedback.position.y != 130.0 or feedback_rect.intersects(board_rect) or feedback_rect.intersects(title_rect) or feedback_rect.intersects(weight_rect) or feedback_rect.intersects(presentation.stage_card_bounds()) or feedback_rect.intersects(presentation.FORECAST_CARD_BOUNDS) or feedback_rect.intersects(presentation.controls_panel_bounds()):
		await _fail("Actual sign feedback must clear the live sign face/title, hanging weight and cards: feedback=%s sign=%s title=%s" % [str(feedback_rect), str(board_rect), str(title_rect)])
		return false
	print("Sign balance feedback clear: feedback=%s sign=%s title=%s" % [str(feedback_rect), str(board_rect), str(title_rect)])
	return true

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

func _check_pointer_and_pause_retry(session: Control) -> bool:
	if not await _wait_for_live_model(session, 0.15): return false
	var initial_balance := float(session.sign_model.snapshot().balance)
	var spatial_mass := session.presentation.find_child("Counterweight", true, false) as Node3D
	if spatial_mass == null:
		await _fail("Live spatial counterweight node is missing")
		return false
	var initial_mass_x: float = spatial_mass.position.x
	var rail: Rect2 = session.presentation.WEIGHT_RAIL
	var start_physical := _physical_design_point(session, Vector2(rail.position.x + rail.size.x * 0.60, rail.get_center().y))
	var drag_physical := _physical_design_point(session, Vector2(rail.position.x + rail.size.x * 0.82, rail.get_center().y))
	_motion(start_physical)
	Input.flush_buffered_events()
	if not _live_session(session): return false
	if get_viewport().gui_get_hovered_control() != session.presentation:
		await _fail("Actual pointer did not hover the game-008 play surface beneath the HUD sibling")
		return false
	var down := InputEventMouseButton.new()
	down.position = start_physical
	down.global_position = start_physical
	down.window_id = get_window().get_window_id()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	if not _live_session(session): return false
	var drag := InputEventMouseMotion.new()
	drag.position = drag_physical
	drag.global_position = drag_physical
	drag.window_id = get_window().get_window_id()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	if not _live_session(session): return false
	var up := InputEventMouseButton.new()
	up.position = drag_physical
	up.global_position = drag_physical
	up.window_id = get_window().get_window_id()
	up.button_index = MOUSE_BUTTON_LEFT
	up.button_mask = 0
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	if not _live_session(session): return false
	var after_pointer_balance := float(session.sign_model.snapshot().balance)
	if after_pointer_balance <= initial_balance:
		await _fail("Actual drag events did not reach the STOP play surface and move the physical counterweight: initial=%.3f final=%.3f" % [initial_balance, after_pointer_balance])
		return false
	await _frames(2)
	if not _live_session(session): return false
	if is_equal_approx(spatial_mass.position.x, initial_mass_x) or not is_equal_approx(spatial_mass.position.x, session.presentation.weight_rail_x(session.sign_model.snapshot())):
		await _fail("Real mouse drag changed the score model but not the visible 3D counterweight position")
		return false
	var pause_button: Button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "pause game-008"): return false
	if not _live_session(session) or not session.paused:
		await _fail("Actual pause button did not pause the live sign challenge")
		return false
	var resume_button: Button = session.minigame_hud.find_child("ResumeButton", true, false)
	if not await _native_click_button(resume_button, "resume game-008"): return false
	if not _live_session(session) or session.paused:
		await _fail("Actual resume button did not resume the live sign challenge")
		return false
	pause_button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "pause before confirmed retry"): return false
	if not _live_session(session) or not session.paused: return false
	var retry_button: Button = session.minigame_hud.find_child("RetryButton", true, false)
	if not await _native_click_button(retry_button, "request confirmed retry"): return false
	if not _live_session(session): return false
	var confirm_button: Button = session.minigame_hud.find_child("ConfirmAction", true, false)
	if confirm_button == null or not confirm_button.is_visible_in_tree():
		await _fail("Retry did not show its confirmation dialog")
		return false
	_retry_snapshot.clear()
	_confirmed_retry_snapshot.clear()
	session.minigame_hud.retry_requested.connect(_capture_retry_state.bind(session), CONNECT_ONE_SHOT)
	# ConfirmAction's existing pressed handler runs first and emits retry_requested;
	# this later listener captures the session's synchronous reset before any frame.
	confirm_button.pressed.connect(_capture_confirmed_retry_state.bind(session), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm_button, "confirm game-008 retry"): return false
	if not _live_session(session): return false
	if float(_retry_snapshot.get("elapsed", -1.0)) != 0.0 or int(_retry_snapshot.get("stage", -1)) != 0 or int(_retry_snapshot.get("score", -1)) != 0 or bool(_retry_snapshot.get("paused", true)):
		await _fail("Confirmed retry signal did not synchronously observe the fully reset model and session")
		return false
	if _confirmed_retry_snapshot.is_empty():
		await _fail("ConfirmAction pressed callback did not capture the synchronous retry reset")
		return false
	var callback_model: Dictionary = _confirmed_retry_snapshot.get("model", {})
	if float(callback_model.get("elapsed", -1.0)) != 0.0 or int(callback_model.get("stage", -1)) != 0 or int(callback_model.get("score", -1)) != 0 or int(_confirmed_retry_snapshot.get("score", -1)) != 0 or not _confirmed_retry_snapshot.get("score_events", [1]).is_empty() or bool(_confirmed_retry_snapshot.get("paused", true)) or bool(_confirmed_retry_snapshot.get("ended", true)) or bool(_confirmed_retry_snapshot.get("result_latched", true)):
		await _fail("ConfirmAction callback did not observe exact-zero reset state: %s" % str(_confirmed_retry_snapshot))
		return false
	var resumed_model: Dictionary = session.sign_model.snapshot().duplicate(true)
	if float(resumed_model.get("elapsed", -1.0)) < 0.0 or session.score != 0 or not session.score_events.is_empty() or session.paused or session.ended or main.modal_kind == "result":
		await _fail("Confirmed retry did not leave an active session without stale results or score events")
		return false
	pause_button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "pause before practice route"): return false
	if not _live_session(session) or not session.paused: return false
	var practice_button: Button = session.minigame_hud.find_child("PracticeButton", true, false)
	if not await _native_click_button(practice_button, "restart as practice"): return false
	if not _live_session(session) or not session.practice_mode or session.paused or session.score != 0:
		await _fail("Practice action did not synchronously reset the live challenge without awards")
		return false
	return true

func _drive_seven_stages(session: Control, use_practice_result: bool) -> bool:
	var held_key := 0
	var captures := {2: "initial", 5: "middle"}
	var deadline := _wall_deadline_ms(35000)
	while _result_snapshot.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not _result_snapshot.is_empty(): break
		if not _live_session(session): return false
		var state: Dictionary = session.sign_model.snapshot().duplicate(true)
		var sign_assembly := session.presentation.find_child("SignAssembly", true, false) as Node3D
		var spatial_mass := session.presentation.find_child("Counterweight", true, false) as Node3D
		if sign_assembly == null or spatial_mass == null or not is_equal_approx(sign_assembly.rotation.z, session.presentation.visual_angle(state)) or not is_equal_approx(spatial_mass.position.x, session.presentation.weight_rail_x(state)):
			await _fail("Live sign angle or counterweight transform diverged from the existing model snapshot")
			return false
		if captures.has(int(state.stage)) and not captures[int(state.stage)].is_empty():
			var label: String = captures[int(state.stage)]
			captures[int(state.stage)] = ""
			if not await _check_rendered_stage(session): return false
			if not main._capture(".review/native-sign-balance-%s-stage-%02d.png" % ["practice" if use_practice_result else "formal", int(state.stage) + 1]):
				await _fail("Could not capture live sign state at stage %s" % label)
				return false
		if session.ended: break
		var target := float(state.target_angle)
		var error := float(state.angle) - target
		var torque := float(state.wind_torque)
		if bool(state.forecast_visible): torque = float(state.forecast_torque)
		var desired_accel := -8.0 * error - 4.0 * float(state.angular_velocity)
		var restoring: float = -session.sign_model.RESTORE_TORQUE * error
		var desired_balance := clampf((desired_accel - torque - restoring + session.sign_model.ANGULAR_DAMPING * float(state.angular_velocity)) / session.sign_model.COUNTERWEIGHT_TORQUE, -1.0, 1.0)
		var next_key := KEY_RIGHT if desired_balance > float(state.balance) + 0.025 else (KEY_LEFT if desired_balance < float(state.balance) - 0.025 else 0)
		if next_key != held_key:
			if held_key != 0: _held_key(held_key, false)
			if next_key != 0: _held_key(next_key, true)
			held_key = next_key
	if held_key != 0: _held_key(held_key, false)
	if _result_snapshot.is_empty():
		await _fail("Sign balance route did not reach its natural result before the review deadline")
		return false
	return true

func _capture_result(result: Dictionary, session: Control) -> void:
	_result_snapshot = result.duplicate(true)
	_finish_state = session.sign_model.snapshot().duplicate(true)

func _capture_retry_state(session: Control) -> void:
	_retry_snapshot = session.sign_model.snapshot().duplicate(true)
	_retry_snapshot["score"] = session.score
	_retry_snapshot["paused"] = session.paused

func _capture_confirmed_retry_state(session: Control) -> void:
	_confirmed_retry_snapshot = {
		"model": session.sign_model.snapshot().duplicate(true),
		"score": session.score,
		"score_events": session.score_events.duplicate(true),
		"paused": session.paused,
		"ended": session.ended,
		"result_latched": not _result_snapshot.is_empty(),
	}

func _physical_design_point(session: Control, design_point: Vector2) -> Vector2:
	var viewport_point: Vector2 = session.presentation.get_global_transform_with_canvas() * design_point
	return get_viewport().get_final_transform() * viewport_point

func _wait_for_live_model(session: Control, minimum_elapsed: float) -> bool:
	var deadline := _wall_deadline_ms(3000)
	while Time.get_ticks_msec() < deadline:
		if not _live_session(session): return false
		if float(session.sign_model.snapshot().elapsed) >= minimum_elapsed: return true
		await get_tree().physics_frame
		if not _live_session(session): return false
	await _fail("Live game-008 model did not advance to its first pointer check")
	return false

func _live_session(session: Control) -> bool:
	if is_instance_valid(main) and is_instance_valid(session) and main.session == session:
		return true
	if is_instance_valid(main):
		push_error("Native sign fixture lost the live game session while waiting")
	return false


func _process(_delta: float) -> void:
	if _wall_deadline_msec > 0 and Time.get_ticks_msec() >= _wall_deadline_msec:
		_wall_deadline_msec = 0
		push_error("Native sign balance review exceeded its 300-second wall-clock watchdog")
		get_tree().quit(1)
