extends "res://game/tests/native_layout_review.gd"

const CatalogScript = preload("res://game/ui/tutorial_catalog.gd")
const SCREENSHOT_DIR := "pm/Snapland-art/images/ART-24-tutorial-refresh"
const SCRIPTED_RESULT_FLAGS := {
	"game-001": {"success": true, "devil": false},
	"game-002": {"success": true, "devil": true},
	"game-003": {"success": true, "devil": false},
	"game-004": {"success": false, "devil": false},
	"game-005": {"success": true, "devil": true},
	"game-006": {"success": true, "devil": true},
	"game-007": {"success": true, "devil": false},
	"game-008": {"success": false, "devil": false},
	"game-009": {"success": true, "devil": true},
	"game-010": {"success": true, "devil": true},
	"game-011": {"success": true, "devil": false},
	"game-012": {"success": true, "devil": false},
}

var _capture_count := 0
var _include_scripted_results := false

func _run() -> void:
	_include_scripted_results = OS.get_cmdline_user_args().has("--include-scripted-results")
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or not save_path.is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("Native tutorial asset refresh requires a GPU window and an absolute isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	var catalog: RefCounted = CatalogScript.new()
	var report: Dictionary = catalog.validation_report()
	if not bool(report.get("ok", false)) or int(report.get("lesson_count", 0)) != 13:
		push_error("Tutorial asset refresh requires all 13 source lessons: %s" % str(report))
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	if not await _resize_window(Vector2i(1280, 720)):
		return
	if not await _capture_park_examples():
		return
	var preserved_source_count := 0
	for lesson_id in catalog.lesson_ids():
		if lesson_id == "park":
			continue
		var lesson: Dictionary = catalog.get_lesson(lesson_id)
		var result := await _capture_game_examples(lesson_id, lesson)
		preserved_source_count += int(result.preserved)
		if not bool(result.ok):
			return
	print("PASS: native tutorial refresh candidates captured=%d; unmatched/result assets preserved=%d; source tutorial PNGs were read-only" % [_capture_count, preserved_source_count])
	main.world.blocked = true
	main.world.set_process(false)
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0)

func _capture_park_examples() -> bool:
	main._close()
	main.world.blocked = false
	main.world.show()
	main.world.set_process(true)
	main.world.player.position = Vector3(0, 0.4, -24)
	main.world.camera.size = 11.0
	_held_key(KEY_W, true)
	await get_tree().create_timer(0.45).timeout
	_held_key(KEY_W, false)
	await _frames(2)
	if not await _capture_candidate("park", 1, "live park path with movement and HUD"):
		return false
	var point: Dictionary = _find_station("game-001")
	if point.is_empty():
		await _fail("Park tutorial fixture could not find the real first station")
		return false
	main.world.player.position = point.get("position", Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_E)
	await _frames(3)
	if main.modal_kind != "game_info":
		await _fail("Park interaction example did not use the real station interaction")
		return false
	if not await _capture_candidate("park", 2, "live station interaction/details modal"):
		return false
	_key(KEY_ESCAPE)
	await _frames(2)
	_key(KEY_M)
	await _frames(3)
	if main.modal_kind != "ticket":
		await _fail("Park tools example did not open the real voyage ticket")
		return false
	return await _capture_candidate("park", 3, "live voyage ticket and park tools")

func _capture_game_examples(lesson_id: String, lesson: Dictionary) -> Dictionary:
	main._launch_game(lesson_id, false, true)
	await _frames(10)
	var session: Control = main.session
	if session == null or session.game_id != lesson_id or session.minigame_hud == null:
		await _fail("Live session/MinigameHUD failed to initialize for " + lesson_id)
		return {"ok": false, "preserved": 0}
	var preserved := 0
	var steps: Array = lesson.get("steps", [])
	for step_index in range(steps.size()):
		var step: Dictionary = steps[step_index]
		var step_id := str(step.get("id", ""))
		if step_id == "result":
			if not _include_scripted_results:
				preserved += 1
				print("KEEP_SOURCE lesson=%s step=%02d title=%s reason=--include-scripted-results was not supplied" % [lesson_id, step_index + 1, str(step.get("title", step_id))])
				continue
			if not await _capture_scripted_result(lesson_id, step_index + 1, str(step.get("title", step_id))):
				return {"ok": false, "preserved": preserved}
			continue
		var context := await _stage_lesson_step(lesson_id, step_id)
		if context.is_empty():
			preserved += 1
			print("KEEP_SOURCE lesson=%s step=%02d title=%s reason=live presentation does not expose a representative state safely" % [lesson_id, step_index + 1, str(step.get("title", step_id))])
			continue
		if not await _capture_candidate(lesson_id, step_index + 1, "%s｜%s" % [str(step.get("title", step_id)), context]):
			return {"ok": false, "preserved": preserved}
	main._cancel_game()
	await _frames(3)
	return {"ok": true, "preserved": preserved}

func _capture_scripted_result(lesson_id: String, step_number: int, step_title: String) -> bool:
	if main.session == null or not SCRIPTED_RESULT_FLAGS.has(lesson_id):
		await _fail("Scripted result illustration requires the matching live session: " + lesson_id)
		return false
	var flags: Dictionary = SCRIPTED_RESULT_FLAGS[lesson_id]
	var illustrative_result := {
		"game_id": lesson_id,
		"success": bool(flags.get("success", false)),
		"devil": bool(flags.get("devil", false)),
		"score": int(main.session.score),
		"assisted": false,
		"practice": false,
		"mistakes": int(main.session.mistakes),
		"score_summary": main.session.score_summary(),
	}
	# This intentionally invokes the real result UI with fixture-selected status
	# flags. It illustrates layout only and must never be read as gameplay evidence.
	main._game_finished(illustrative_result)
	await _frames(4)
	if main.modal_kind != "result":
		await _fail("Main did not render the scripted result illustration for " + lesson_id)
		return false
	var outcome := "success=%s devil=%s" % [str(illustrative_result.success), str(illustrative_result.devil)]
	var disclaimer := "SYNTHETIC RESULT UI ILLUSTRATION — NOT AN ACTUAL WIN; " + outcome + "; " + step_title
	return await _capture_candidate(lesson_id, step_number, disclaimer)

func _stage_lesson_step(lesson_id: String, step_id: String) -> String:
	match lesson_id:
		"game-001":
			match step_id:
				"launch":
					await _hold_key_for(KEY_RIGHT, 0.4)
					return "live balloon practice with sustained directional steering; no result simulated"
				"brake":
					await _hold_chord_for([KEY_SPACE, KEY_RIGHT], 0.4)
					return "real brake-plus-steer input held before mailbox; no delivery asserted"
				"route":
					await _tap_key(KEY_ENTER)
					await get_tree().create_timer(0.5).timeout
					return "active first mailbox and live wind display; no delivery asserted"
		"game-002":
			match step_id:
				"height":
					await _hold_key_for(KEY_UP, 0.4)
					return "real sustained up input changes kite aim against the first ring"
				"rings":
					await _hold_key_for(KEY_SPACE, 0.25)
					await _hold_key_for(KEY_SHIFT, 0.25)
					return "live ring, boost and reel controls; no ring completion asserted"
		"game-003":
			match step_id:
				"read":
					if not await _wait_for_property(main.session, "beat_window", true, 2.0): return ""
					return "live fountain countdown and first illuminated timing window"
				"jump":
					if not await _wait_for_property(main.session, "beat_window", true, 2.0): return ""
					await _tap_key(KEY_SPACE)
					return "actual Space jump during a live beat window; no round result asserted"
		"game-004":
			match step_id:
				"read":
					await get_tree().create_timer(1.4).timeout
					return "actual left/right arrival queues after live simulation"
				"switch":
					await _tap_key(KEY_Q)
					return "actual Q signal selection with queue and selected lane visible"
		"game-005":
			match step_id:
				"move":
					await _hold_key_for(KEY_LEFT, 0.4)
					return "real sustained left movement toward the first falling hat"
				"catch":
					var caught_ready := await _wait_for_hat_contact(5.0)
					if not caught_ready:
						return ""
					await _tap_key(KEY_SPACE)
					return "short Space catch press at the falling hat's contact zone; outcome not claimed"
		"game-006":
			match step_id:
				"learn":
					if not await _advance_ribbon_to(0): return ""
					await _tap_key(KEY_LEFT)
					return "real first left cue response with the next-beat ribbon preview"
				"phrase":
					if not await _advance_ribbon_to(3): return ""
					_held_key(KEY_LEFT, true)
					await get_tree().create_timer(0.36).timeout
					_held_key(KEY_LEFT, false)
					return "real 0.36-second left ribbon hold at the sustained cue; no phrase completion"
		"game-007":
			match step_id:
				"select":
					await _tap_key(KEY_RIGHT)
					return "actual keyboard selection moves the pipe cursor to a flower bed"
				"rotate":
					await _tap_key(KEY_SPACE)
					return "actual Space rotates the selected pipe and updates the water network"
		"game-008":
			match step_id:
				"control":
					await _hold_key_for(KEY_LEFT, 0.4)
					return "sustained left input moves the live counterweight"
				"hold":
					await _hold_key_for(KEY_RIGHT, 0.4)
					return "sustained right correction with live angle and gust forecast"
		"game-009":
			match step_id:
				"move":
					await _hold_key_for(KEY_RIGHT, 0.4)
					return "sustained lamp movement changes the projected shadow"
				"align":
					await _hold_chord_for([KEY_SHIFT, KEY_RIGHT], 0.4)
					await _tap_key(KEY_SPACE)
					return "Shift fine-adjustment followed by the real Space freeze action"
		"game-010":
			match step_id:
				"aim":
					await _hold_key_for(KEY_E, 0.35)
					return "real E charge-release launches a bubble while the live frame follows"
				"shoot":
					await _hold_key_for(KEY_RIGHT, 0.2)
					if not await _wait_for_bubble_focus(2.0): return ""
					await _tap_key(KEY_SPACE)
					return "live frame adjustment and actual Space shutter; outcome not claimed"
		"game-011":
			match step_id:
				"select":
					await _tap_key(KEY_1)
					return "actual seat-one selection with current table rules visible"
				"solve":
					await _tap_key(KEY_2)
					return "actual seat-two selection or first exchange with rules still visible"
		"game-012":
			match step_id:
				"listen":
					if not await _wait_for_property(main.session.melody_model, "phase", "listen", 1.0): return ""
					return "real opening listen phrase with no player note input"
				"repeat":
					var melody_model: Object = main.session.melody_model
					# The authored three-note phrase takes about 3.8 seconds to play
					# before the model opens its actual active repeat phase.
					if not await _wait_for_property(melody_model, "phase", "active", 6.0): return ""
					await _tap_key(KEY_1)
					var repeat_state: Dictionary = melody_model.snapshot()
					if str(repeat_state.get("phase", "")) != "active" or int(repeat_state.get("input_index", 0)) < 1:
						return ""
					return "first actual note accepted in the live repeat phase after the authored demonstration; phrase not completed"
	return ""

func _wait_for_bubble_focus(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = main.session.bubble_model.snapshot()
		if bool(state.get("focus_available", false)):
			return true
		await get_tree().process_frame
	return false

func _wait_for_property(target: Object, property_name: String, expected: Variant, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if target.get(property_name) == expected:
			return true
		await get_tree().process_frame
	return false

func _wait_for_hat_contact(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = main.session.hat_model.snapshot()
		var hats: Array = state.get("hats", [])
		if not hats.is_empty() and bool(hats[0].get("active", false)) and float(hats[0].get("y", 0.0)) >= 480.0:
			return true
		await get_tree().process_frame
	return false

func _advance_ribbon_to(target_index: int) -> bool:
	var ribbon = main.session.ribbon_model
	var actions: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_LEFT]
	var start_index := int(ribbon.gesture_index)
	for index in range(start_index, target_index + 1):
		var cue_time := RibbonFirstBeat() + float(index) * RibbonBeatInterval()
		while float(ribbon.elapsed) < cue_time and not bool(ribbon.ended):
			await get_tree().process_frame
		if bool(ribbon.ended): return false
		if index == target_index:
			return true
		await _tap_key(actions[index])
	return true

func RibbonFirstBeat() -> float:
	return 1.02

func RibbonBeatInterval() -> float:
	return 0.94

func _capture_candidate(lesson_id: String, step: int, context: String) -> bool:
	if DisplayServer.get_name() == "headless":
		await _fail("Native capture was requested in headless mode: %s/%02d" % [lesson_id, step])
		return false
	await RenderingServer.frame_post_draw
	var path := "%s/%s-step-%02d.png" % [SCREENSHOT_DIR, lesson_id, step]
	if not main._capture(path):
		await _fail("Could not capture live tutorial refresh candidate: " + path)
		return false
	_capture_count += 1
	print("NATIVE TUTORIAL CANDIDATE lesson=%s step=%02d context=%s path=%s" % [lesson_id, step, context, path])
	return true

func _find_station(lesson_id: String) -> Dictionary:
	for point_value in main.world.points:
		if point_value is Dictionary and str(point_value.get("id", "")) == lesson_id:
			return point_value
	return {}

func _held_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _key(code: int) -> void:
	for pressed in [true, false]:
		_held_key(code, pressed)

func _tap_key(code: int) -> void:
	_key(code)
	await get_tree().process_frame

func _hold_key_for(code: int, duration: float) -> void:
	_held_key(code, true)
	await get_tree().create_timer(duration).timeout
	_held_key(code, false)
	await get_tree().process_frame

func _hold_chord_for(codes: Array, duration: float) -> void:
	for code in codes:
		_held_key(int(code), true)
	await get_tree().create_timer(duration).timeout
	for code in codes:
		_held_key(int(code), false)
	await get_tree().process_frame
