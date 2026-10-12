extends Control

## Deterministic native-input acceptance fixture for RibbonRhythmView and its real model.
## It creates no Main/Session, save writes, score assignment, or model-state shortcuts.
const ModelScript := preload("res://game/minigames/ribbon_rhythm_model.gd")
const ViewScript := preload("res://game/minigames/ribbon_rhythm_view.gd")
const AvatarRenderer := preload("res://game/world/avatar_renderer.gd")
const NORMAL_TIME_SCALE := 1.0
const QUARTER_TIME_SCALE := 0.25
const CUE_LEAD := 0.018
const WAIT_GUARD_MS := 8000

var _model: RefCounted
var _view: Control
var _status: Label
var _reduced_motion := false
var _failed := false
var _finish_captured := false
var _normal_seen := false
var _quarter_seen := false
var _dispatch_source := "fixture"
var _active_route := ""
var _resolved_events: Array[Dictionary] = []
var _finish_ledger: Dictionary = {}
var _retry_zero_capture: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_start_review")

func _process(delta: float) -> void:
	if _model == null or _view == null:
		return
	if is_equal_approx(Engine.time_scale, NORMAL_TIME_SCALE):
		_normal_seen = true
	elif is_equal_approx(Engine.time_scale, QUARTER_TIME_SCALE):
		_quarter_seen = true
	_model.step(delta)
	_view.update_frame(_model.snapshot(), _model.time_phase, _reduced_motion)
	_capture_finish_if_needed("elapsed")

func _start_review() -> void:
	if not _native_guard():
		_fail("native review needs a windowed host plus an absolute isolated SNAPLAND_SAVE_PATH; refusing to silently skip")
		return
	Engine.time_scale = NORMAL_TIME_SCALE
	_model = ModelScript.new()
	_model.reset(false, "noon")
	_view = ViewScript.new()
	_view.name = "RibbonRhythmReviewSurface"
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.configure_avatar(AvatarRenderer.DEFAULT_APPEARANCE, {"outfit": "outfit-tide", "hat": "hat-none"})
	_view.action_pressed.connect(_on_action_pressed)
	_view.action_released.connect(_on_action_released)
	add_child(_view)
	_status = Label.new()
	_status.name = "ReviewStatus"
	_status.position = Vector2(260.0, 126.0)
	_status.size = Vector2(760.0, 16.0)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color("#fff0d7"))
	_status.add_theme_color_override("font_shadow_color", Color("#172238"))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	_status.text = "原生驗收自動輸入：鍵盤＋指標｜正常／輔助｜1×／0.25×"
	add_child(_status)
	view_update()
	await _frames(2)
	_view.grab_focus()
	var initial: Dictionary = _model.snapshot()
	if not _view.avatar_assets_ready() or initial.upcoming.size() != 2 or int(initial.gesture_count) != 8:
		_fail("authored avatar actions, eight-gesture phrase, or two-step preview did not initialize")
		return
	if _view.companion_identity() != "imp" or _view.companion_display_name() != "小角" or not _view.companion_assets_ready() or _view.companion_idle_frame_count() != 7 or _view.companion_dance_frame_count() != 7:
		_fail("authored 小角 idle/dance frames did not load as the stage partner")
		return
	await RenderingServer.frame_post_draw
	if not _capture_companion_view(".review/native-ribbon-companion-opening.png"):
		_fail("could not capture the real stage and 小角's opening pose")
		return
	print("RIBBON_NATIVE_READY: preview=" + JSON.stringify(initial.upcoming) + " assets=" + str(_view.avatar_assets_ready()) + " companion=小角/imp idle=7 dance=7")
	if not await _run_unassisted_error_route():
		return
	if not await _retry_through_r_input():
		return
	if not await _run_unassisted_devil_route():
		return
	if not await _run_assisted_reduced_quarter_route():
		return
	Engine.time_scale = NORMAL_TIME_SCALE
	print("PASS: native RibbonRhythmView keyboard/pointer Input.parse_input_event paths, eight gestures and both sustained holds, wrong-input ordinary result, R retry exact-zero, unassisted devil result at 1x, assisted reduced-motion result at 0.25x")
	print("RIBBON_NATIVE_REPORT: " + JSON.stringify({"retry_zero": _retry_zero_capture, "unassisted_devil": _finish_ledger, "normal_seen": _normal_seen, "quarter_seen": _quarter_seen}))
	get_tree().quit(0)

func _capture_companion_view(relative_path: String) -> bool:
	var target := ProjectSettings.globalize_path(relative_path)
	var directory := target.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK and not DirAccess.dir_exists_absolute(directory):
		return false
	var image := get_viewport().get_texture().get_image()
	return image != null and image.save_png(target) == OK

func _native_guard() -> bool:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	return not path.is_empty() and path.is_absolute_path() and DisplayServer.get_name() != "headless"

func _input(event: InputEvent) -> void:
	# Retry is itself exercised as an actual native input event. Its reset and
	# scalar capture occur synchronously in this input callback, before a frame.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_retry_and_capture_zero()

func _run_unassisted_error_route() -> bool:
	Engine.time_scale = NORMAL_TIME_SCALE
	_active_route = "unassisted_error_ordinary"
	_update_status("1/3：1× 未輔助；先經 View 注入一個錯方向，再演奏完整八拍")
	var before: Dictionary = _model.snapshot().duplicate(true)
	_dispatch_source = "keyboard"
	_send_key(KEY_RIGHT, true)
	_send_key(KEY_RIGHT, false)
	await _frames(1)
	_dispatch_source = "fixture"
	var after: Dictionary = _model.snapshot()
	if int(after.error_count) != int(before.error_count) + 1 or int(after.gesture_index) != 0 or int(after.score) != 0:
		_fail("wrong direction did not become a real model error without advancing or scoring")
		return false
	if _view.companion_is_dancing():
		_fail("a wrong input or unfinished phrase triggered the companion finale")
		return false
	await RenderingServer.frame_post_draw
	if not _capture_companion_view(".review/native-ribbon-companion-unfinished.png"):
		_fail("could not capture 小角 remaining at idle before the eighth hit")
		return false
	if not await _play_eight_gestures("ordinary-after-error", false, 0):
		return false
	var result: Dictionary = _model.snapshot()
	if not bool(result.ended) or not bool(result.success) or bool(result.devil_success) or int(result.correct_count) != 8 or int(result.error_count) != 1 or int(result.missed_count) != 0 or int(result.precise_count) != 8:
		_fail("real eight-gesture route after one wrong input should earn ordinary success but not devil: %s" % JSON.stringify(_scalar_state(result)))
		return false
	if not _route_used_both_inputs(false):
		_fail("ordinary route did not traverse both keyboard and pointer View signals")
		return false
	_freeze_route("unassisted_error_ordinary", result)
	if not _view.companion_is_dancing():
		_fail("real successful eighth hit did not start the authored imp dance")
		return false
	await RenderingServer.frame_post_draw
	if not _capture_companion_view(".review/native-ribbon-companion-eighth-hit.png"):
		_fail("could not capture 小角's actual eighth-hit dance frame")
		return false
	var opening_dance_frame: int = _view.companion_frame_index()
	await _frames(10)
	if not _view.companion_is_dancing() or _view.companion_frame_index() == opening_dance_frame:
		_fail("小角's authored one-shot dance did not visibly advance on the live native route")
		return false
	await RenderingServer.frame_post_draw
	if not _capture_companion_view(".review/native-ribbon-companion-dance-progress.png"):
		_fail("could not capture the advancing authored dance sequence")
		return false
	print("RIBBON_NATIVE_ORDINARY: " + JSON.stringify(_finish_ledger))
	return true

func _retry_through_r_input() -> bool:
	# The actual R event goes through Window/Control input parsing. No frame is
	# awaited between parse_input_event and validation of the zero capture.
	_send_key(KEY_R, true)
	if _retry_zero_capture.is_empty():
		# Some display backends deliver parsed input on the following frame. The
		# capture itself still occurs in the R input callback before model stepping.
		await get_tree().process_frame
		if _retry_zero_capture.is_empty():
			_fail("R InputEvent did not call retry and freeze the exact-zero snapshot synchronously in its callback")
			return false
	_send_key(KEY_R, false)
	var zero := _retry_zero_capture
	if int(zero.correct) != 0 or int(zero.precise) != 0 or int(zero.missed) != 0 or int(zero.errors) != 0 or int(zero.score) != 0 or int(zero.gesture_index) != 0 or int(zero.ledger_size) != 0 or bool(zero.ended) or bool(zero.success) or bool(zero.devil_success):
		_fail("R retry did not retain exact zero scalars before another frame: %s" % JSON.stringify(zero))
		return false
	print("RIBBON_NATIVE_RETRY_ZERO_BEFORE_FRAME: " + JSON.stringify(zero))
	return true

func _run_unassisted_devil_route() -> bool:
	Engine.time_scale = NORMAL_TIME_SCALE
	_active_route = "unassisted_devil"
	_reduced_motion = false
	_model.reset(false, _model.time_phase)
	_reset_capture_for_next_route()
	view_update()
	_update_status("2/3：1× 未輔助乾淨重演；輸入依預告拍點，鍵盤與指標交替")
	if not await _play_eight_gestures("unassisted-devil", false, 1):
		return false
	var result: Dictionary = _model.snapshot()
	if not bool(result.ended) or not bool(result.success) or not bool(result.devil_success) or int(result.correct_count) != 8 or int(result.precise_count) != 8 or int(result.error_count) != 0 or int(result.missed_count) != 0 or int(result.score) != 900:
		_fail("unassisted input route did not earn the model's eight-precise devil result: %s" % JSON.stringify(_scalar_state(result)))
		return false
	if not _route_used_both_inputs(true):
		_fail("unassisted devil route did not traverse both keyboard and pointer View signals")
		return false
	if not _verify_authored_strong_beats(result):
		return false
	_freeze_route("unassisted_devil", result)
	print("RIBBON_NATIVE_DEVIL: " + JSON.stringify(_finish_ledger))
	return true

func _run_assisted_reduced_quarter_route() -> bool:
	Engine.time_scale = QUARTER_TIME_SCALE
	_active_route = "assisted_reduced_quarter"
	_reduced_motion = true
	_model.reset(true, _model.time_phase)
	_reset_capture_for_next_route()
	view_update()
	var initial: Dictionary = _model.snapshot()
	var cues: Dictionary = _view.visual_cue_state(initial)
	if not bool(initial.assisted) or bool(initial.ended) or int(initial.score) != 0 or int(initial.correct_count) != 0 or initial.upcoming.size() != 2 or bool(cues.motion_enabled):
		_fail("assisted reduced-motion route did not begin empty with both static preview cues")
		return false
	_update_status("3/3：0.25× 輔助＋減少動態；靜態預告照常，模型仍需八次真實輸入")
	if not await _play_eight_gestures("assisted-reduced-quarter", true, 0):
		return false
	var result: Dictionary = _model.snapshot()
	if not bool(result.ended) or not bool(result.assisted) or not bool(result.success) or bool(result.devil_success) or int(result.correct_count) != 8 or int(result.precise_count) != 8 or int(result.error_count) != 0 or int(result.missed_count) != 0 or int(result.score) != 900:
		_fail("assisted route did not record eight real precise inputs as ordinary-only success: %s" % JSON.stringify(_scalar_state(result)))
		return false
	if not _route_used_both_inputs(true):
		_fail("assisted route did not traverse both keyboard and pointer View signals")
		return false
	if not _view.companion_is_dancing() or _view.companion_frame_index() != 6:
		_fail("reduced motion should preserve a static distinct imp finale without cycling frames")
		return false
	_freeze_route("assisted_reduced_quarter", result)
	await RenderingServer.frame_post_draw
	if not _capture_companion_view(".review/native-ribbon-companion-reduced-finale.png"):
		_fail("could not capture the reduced-motion static imp finale")
		return false
	print("RIBBON_NATIVE_ASSISTED: " + JSON.stringify(_finish_ledger))
	return true

func _play_eight_gestures(route: String, assisted: bool, input_offset: int) -> bool:
	for phrase_index in range(8):
		var state: Dictionary = _model.snapshot()
		if bool(state.ended) or int(state.gesture_index) != phrase_index or bool(state.assisted) != assisted:
			_fail("%s expected gesture %d but model shows %s" % [route, phrase_index, JSON.stringify(_scalar_state(state))])
			return false
		var cue: Dictionary = state.current_gesture.duplicate(true)
		var index := int(cue.get("index", -1))
		var action := str(cue.get("action", ""))
		var cue_time := float(cue.get("time", INF))
		var held_for := float(cue.get("hold", 0.0))
		if index != phrase_index or not ["left", "right", "jump"].has(action) or not is_finite(cue_time):
			_fail("%s received an invalid authored current cue: %s" % [route, JSON.stringify(cue)])
			return false
		if not await _wait_until(cue_time - CUE_LEAD):
			_fail("%s could not reach visible cue %d at engine scale %.2f" % [route, index, Engine.time_scale])
			return false
		var use_pointer := posmod(index + input_offset, 2) == 1
		await _press_action(action, use_pointer)
		if held_for > 0.0:
			var holding: Dictionary = _model.snapshot()
			if str(holding.get("hold_action", "")) != action or int(holding.get("gesture_index", -1)) != index:
				_fail("%s gesture %d hold press was not accepted through its View signal" % [route, index])
				return false
			var release_time := float(holding.get("elapsed", 0.0)) + held_for
			if not await _wait_until(release_time):
				_fail("%s did not reach the authored %.2fs hold duration" % [route, held_for])
				return false
			await _release_action(action, use_pointer)
		else:
			await _release_action(action, use_pointer)
		var after: Dictionary = _model.snapshot()
		if int(after.get("gesture_index", -1)) != index + 1 or int(after.get("correct_count", 0)) != index + 1:
			_fail("%s gesture %d failed actual input judgement (model=%s)" % [route, index, JSON.stringify(_scalar_state(after))])
			return false
		if int(after.get("precise_count", 0)) != index + 1:
			_fail("%s gesture %d missed the model's precision boundary at offset %.4f" % [route, index, float(after.get("elapsed", 0.0)) - cue_time])
			return false
	return true

func _wait_until(target_time: float) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_GUARD_MS
	while float(_model.snapshot().get("elapsed", 0.0)) < target_time:
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true

func _press_action(action: String, pointer: bool) -> void:
	_dispatch_source = "pointer" if pointer else "keyboard"
	if pointer:
		_send_pointer(action, true)
	else:
		_send_key(_key_for_action(action), true)
	await get_tree().process_frame
	_dispatch_source = "fixture"

func _release_action(action: String, pointer: bool) -> void:
	_dispatch_source = "pointer" if pointer else "keyboard"
	if pointer:
		_send_pointer(action, false)
	else:
		_send_key(_key_for_action(action), false)
	await get_tree().process_frame
	_dispatch_source = "fixture"

func _key_for_action(action: String) -> Key:
	match action:
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"jump": return KEY_SPACE
	return KEY_NONE

func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.window_id = get_window().get_window_id()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _send_pointer(action: String, pressed: bool) -> void:
	var local: Vector2 = _view.design_to_screen(_view.control_center(action))
	var screen: Vector2 = _view.get_global_transform_with_canvas() * local
	if pressed:
		var motion := InputEventMouseMotion.new()
		motion.window_id = get_window().get_window_id()
		motion.position = screen
		motion.global_position = screen
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
	var event := InputEventMouseButton.new()
	event.window_id = get_window().get_window_id()
	event.position = screen
	event.global_position = screen
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _on_action_pressed(action: String) -> void:
	var before: Dictionary = _model.snapshot().duplicate(true)
	_model.press_action(action)
	_record_signal("press", action, before, _model.snapshot())
	view_update()
	_capture_finish_if_needed("press")

func _on_action_released(action: String) -> void:
	var before: Dictionary = _model.snapshot().duplicate(true)
	_model.release_action(action)
	_record_signal("release", action, before, _model.snapshot())
	view_update()
	_capture_finish_if_needed("release")

## Snapshot before and after each real View signal; only scalar copies survive.
func _record_signal(kind: String, action: String, before: Dictionary, state: Dictionary) -> void:
	var cue: Dictionary = before.get("current_gesture", {}).duplicate(true)
	_resolved_events.append({
		"kind": kind,
		"action": action,
		"source": _dispatch_source,
		"index_before": int(before.get("gesture_index", 0)),
		"index_after": int(state.get("gesture_index", 0)),
		"expected": str(cue.get("action", "")),
		"hold_required": float(cue.get("hold", 0.0)),
		"elapsed": float(state.get("elapsed", 0.0)),
		"scale": Engine.time_scale,
		"score": int(state.get("score", 0)),
		"correct": int(state.get("correct_count", 0)),
		"precise": int(state.get("precise_count", 0)),
		"missed": int(state.get("missed_count", 0)),
		"errors": int(state.get("error_count", 0)),
		"assisted": bool(state.get("assisted", false)),
	})

func _retry_and_capture_zero() -> void:
	if _model == null or int(_model.snapshot().get("error_count", 0)) == 0:
		_fail("R retry arrived without the real wrong-input error that precedes it")
		return
	_model.retry()
	# Do not await, defer, or wait for the next frame before freezing this state.
	_retry_zero_capture = _scalar_state(_model.snapshot())
	_retry_zero_capture["ledger_size"] = _model.snapshot().get("ribbon_trail", []).size()
	if int(_retry_zero_capture.correct) != 0 or int(_retry_zero_capture.precise) != 0 or int(_retry_zero_capture.missed) != 0 or int(_retry_zero_capture.errors) != 0 or int(_retry_zero_capture.score) != 0 or int(_retry_zero_capture.gesture_index) != 0 or int(_retry_zero_capture.ledger_size) != 0 or bool(_retry_zero_capture.ended) or bool(_retry_zero_capture.success) or bool(_retry_zero_capture.devil_success):
		_fail("retry reset did not synchronously expose exact zero values: %s" % JSON.stringify(_retry_zero_capture))
		return
	_reset_capture_for_next_route()
	_reduced_motion = false
	view_update()
	print("RIBBON_NATIVE_RETRY_ZERO_BEFORE_FRAME: " + JSON.stringify(_retry_zero_capture))

func _reset_capture_for_next_route() -> void:
	_finish_captured = false
	_finish_ledger.clear()
	_resolved_events.clear()

func _capture_finish_if_needed(source: String) -> void:
	if _finish_captured or _model == null:
		return
	var state: Dictionary = _model.snapshot()
	if not bool(state.get("ended", false)):
		return
	_freeze_route(source, state)

## Freeze finished model scalars/trail synchronously inside signal or process callback.
func _freeze_route(source: String, state: Dictionary) -> void:
	if _finish_captured:
		return
	_finish_ledger = _scalar_state(state)
	_finish_ledger["route"] = _active_route if not _active_route.is_empty() else source
	_finish_ledger["finish_source"] = source
	_finish_ledger["ribbon_trail"] = state.get("ribbon_trail", []).duplicate(true)
	_finish_ledger["events"] = _resolved_events.duplicate(true)
	_finish_ledger["normal_seen"] = _normal_seen
	_finish_ledger["quarter_seen"] = _quarter_seen
	_finish_ledger["reduced_motion"] = _reduced_motion
	_finish_captured = true
	print("RIBBON_NATIVE_FINISH: " + JSON.stringify(_finish_ledger))

func _verify_authored_strong_beats(state: Dictionary) -> bool:
	var trail: Array = state.get("ribbon_trail", [])
	var strong_count := 0
	for index in trail.size():
		if bool(trail[index].get("strong", false)):
			strong_count += 1
	if trail.size() != 8 or strong_count != 4:
		_fail("devil trail should contain eight real gesture entries with four authored strong-beat bonuses")
		return false
	return true

func _route_used_both_inputs(require_finished_route: bool) -> bool:
	var keyboard := false
	var pointer := false
	for event in _resolved_events:
		if str(event.get("source", "")) == "keyboard": keyboard = true
		if str(event.get("source", "")) == "pointer": pointer = true
	return keyboard and pointer and (not require_finished_route or _finish_captured)

func _scalar_state(state: Dictionary) -> Dictionary:
	return {
		"gesture_index": int(state.get("gesture_index", 0)),
		"correct": int(state.get("correct_count", 0)),
		"precise": int(state.get("precise_count", 0)),
		"missed": int(state.get("missed_count", 0)),
		"errors": int(state.get("error_count", 0)),
		"score": int(state.get("score", 0)),
		"ordinary_success_hits": int(state.get("ordinary_success_hits", 6)),
		"success": bool(state.get("success", false)),
		"devil_success": bool(state.get("devil_success", false)),
		"assisted": bool(state.get("assisted", false)),
		"ended": bool(state.get("ended", false)),
		"phase": str(state.get("phase", "")),
		"time_phase": str(state.get("time_phase", "")),
	}

func _frames(count: int) -> void:
	for ignored in count:
		await get_tree().process_frame

func view_update() -> void:
	if _view != null and _model != null:
		_view.update_frame(_model.snapshot(), _model.time_phase, _reduced_motion)

func _update_status(message: String) -> void:
	if _status != null:
		_status.text = message

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	Engine.time_scale = NORMAL_TIME_SCALE
	push_error("Native RibbonRhythmView review: " + message)
	print("RIBBON_NATIVE_FAIL: " + JSON.stringify({"reason": message, "finish": _finish_ledger, "retry_zero": _retry_zero_capture}))
	get_tree().quit(1)
