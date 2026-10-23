extends "res://game/tests/native_review.gd"

const Model = preload("res://game/minigames/melody_memory_model.gd")
const View = preload("res://game/minigames/melody_memory_view.gd")
var _latched_result: Dictionary = {}
var _latched_result_session_id := -1
var _pause_evidence: Dictionary = {}
var _retry_evidence: Dictionary = {}
var _formal_collection: Dictionary = {}
var _practice_before: Dictionary = {}
var _listen_capture_done := false
var _active_capture_done := false
var _phase_capture_completed := false
var _review_deadline := 0

func _process(_delta: float) -> void:
	if _review_deadline > 0 and Time.get_ticks_msec() >= _review_deadline:
		_review_deadline = 0
		push_error("Native melody review exceeded its scaled finite watchdog deadline")
		if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
		get_tree().quit(1)
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	_review_deadline = _wall_deadline(180.0)
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native melody review requires a GPU display and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Progress autoload is missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _launch_melody(false): return
	var formal_id: int = main.session.get_instance_id()
	main.session.finished.connect(_capture_result.bind(formal_id), CONNECT_ONE_SHOT)
	if not await _pause_resume_retry(formal_id): return
	_listen_capture_done = false
	_active_capture_done = false
	if not await _play_observed_phrase_keys(formal_id): return
	if not bool(_latched_result.get("success", false)) or not bool(_latched_result.get("devil", false)) or bool(_latched_result.get("practice", true)):
		await _fail("Observed 3-phrase 1-4 keyboard play did not reach its natural formal devil result: " + str(_latched_result))
		return
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1:
		await _fail("Formal melody clear did not create its single natural ordinary/devil photos")
		return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-melody-memory-formal-result.png"):
		await _fail("Could not capture the natural formal Melody result")
		return
	_formal_collection = _progress_subset()
	if not await _activate_main_button("返回遊園", "return from formal melody result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "return to park after formal melody"): return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _launch_melody(true): return
	var practice_id: int = main.session.get_instance_id()
	if not await _enter_practice(practice_id): return
	_latched_result.clear()
	_latched_result_session_id = -1
	main.session.finished.connect(_capture_result.bind(practice_id), CONNECT_ONE_SHOT)
	_listen_capture_done = true
	_active_capture_done = true
	if not await _play_observed_phrase_pointer(practice_id): return
	if not bool(_latched_result.get("success", false)) or bool(_latched_result.get("devil", true)) or not bool(_latched_result.get("practice", false)) or not bool(_latched_result.get("assisted", false)):
		await _fail("Assisted reduced-motion pointer play did not reach its ordinary-only practice result")
		return
	if _progress_subset() != _formal_collection:
		await _fail("Melody practice changed progression, achievements, mission or pending reward state")
		return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-melody-memory-practice.png"):
		await _fail("Could not capture the natural melody practice result")
		return
	print("PASS: Main station launch, observed keyboard melody, pause/resume/retry, and assisted reduced-motion pointer practice; formal collection unchanged by practice")
	await main._quit_game()

func _launch_melody(assisted_run: bool) -> bool:
	for point in main.world.points:
		if point.id == "game-012":
			main.world.player.position = point.position + Vector3(0, 0.3, 0)
			break
	var deadline := _wall_deadline(4.0)
	while main.world.nearest.get("id", "") != "game-012" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if main.world.nearest.get("id", "") != "game-012":
		await _fail("Game-012 is not reachable as the live nearest station")
		return false
	_key(KEY_E)
	deadline = _wall_deadline(3.0)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if main.modal_kind != "game_info":
		await _fail("Native E input did not open game-012 station details")
		return false
	if not await _activate_main_button("開始遊玩", "start game-012 melody memory"): return false
	deadline = _wall_deadline(3.5)
	while main.session == null and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if main.session == null or main.session.game_id != "game-012":
		await _fail("Main did not launch the real game-012 session")
		return false
	if main.session.assisted != assisted_run or main.session.reduced_motion != assisted_run:
		await _fail("Game-012 accessibility settings did not reach the launched session")
		return false
	return true

func _pause_resume_retry(session_id: int) -> bool:
	if not await _wait_until(func() -> bool: return _session_by_id(session_id) != null and float(_session_by_id(session_id).melody_snapshot.phase_elapsed) > 0.12, "live melody model"): return false
	var session := _session_by_id(session_id)
	if session == null: return false
	var pause_button: BaseButton = session.minigame_hud.find_child("PauseButton", true, false)
	_pause_evidence.clear()
	pause_button.pressed.connect(_capture_pause_state.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(pause_button, "pause melody"): return false
	session = _session_by_id(session_id)
	if session == null or int(_pause_evidence.get("session_id", -1)) != session_id or not bool(_pause_evidence.get("paused", false)):
		await _fail("Pause callback did not latch the melody clock after the live pause handler")
		return false
	var before_elapsed := float(_pause_evidence.get("elapsed", -1.0))
	var before_phase_elapsed := float(_pause_evidence.get("phase_elapsed", -1.0))
	var before_serial := int(_pause_evidence.get("note_start_serial", -1))
	for _frame in 3: await get_tree().physics_frame
	session = _session_by_id(session_id)
	var paused_state: Dictionary = session.melody_model.snapshot() if session != null else {}
	if session == null or not session.paused or float(paused_state.elapsed) != before_elapsed or float(paused_state.phase_elapsed) != before_phase_elapsed or int(paused_state.note_start_serial) != before_serial:
		await _fail("Paused melody model state advanced after the post-pressed clock latch")
		return false
	if not await _native_click_button(session.minigame_hud.find_child("ResumeButton", true, false), "resume melody"): return false
	session = _session_by_id(session_id)
	if session == null or session.paused: return false
	if not await _native_click_button(session.minigame_hud.find_child("PauseButton", true, false), "pause before melody retry"): return false
	if not await _native_click_button(session.minigame_hud.find_child("RetryButton", true, false), "open melody retry confirmation"): return false
	var confirm: BaseButton = session.minigame_hud.find_child("ConfirmAction", true, false)
	_retry_evidence.clear()
	confirm.pressed.connect(_capture_retry_state.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm, "confirm melody retry"): return false
	session = _session_by_id(session_id)
	if session == null or int(_retry_evidence.get("session_id", -1)) != session_id or int(_retry_evidence.get("phrase_index", -1)) != 0 or int(_retry_evidence.get("note_start_serial", -1)) != 0 or float(_retry_evidence.get("elapsed", -1.0)) != 0.0 or int(_retry_evidence.get("score", -1)) != 0 or bool(_retry_evidence.get("paused", true)):
		await _fail("Confirmed retry did not reset the same melody session")
		return false
	return true

func _play_observed_phrase_keys(session_id: int) -> bool:
	return await _play_phrases(session_id, false)

func _play_observed_phrase_pointer(session_id: int) -> bool:
	return await _play_phrases(session_id, true)

func _play_phrases(session_id: int, pointer: bool) -> bool:
	var deadline := _wall_deadline(55.0)
	var phrase_notes: Array[int] = []
	var played_phrase := -1
	while Time.get_ticks_msec() < deadline and _latched_result_session_id != session_id:
		await get_tree().physics_frame
		if _latched_result_session_id == session_id and not _latched_result.is_empty(): break
		var session := _session_by_id(session_id)
		if session == null:
			await _fail("Melody session disappeared without a matching latched natural result")
			return false
		var state: Dictionary = session.melody_model.snapshot()
		var phrase_index := int(state.phrase_index)
		if str(state.phase) == "listen":
			if not _listen_capture_done:
				if not await _capture_live_phase(session_id, "listen", ".review/native-melody-memory-formal-listen.png"): return false
				_listen_capture_done = _phase_capture_completed
			var observed: Array = state.heard_notes
			if observed.size() >= phrase_notes.size():
				for i in range(phrase_notes.size(), observed.size()): phrase_notes.append(int(observed[i]))
		if str(state.phase) != "active" or phrase_index == played_phrase: continue
		if not _active_capture_done:
			if not await _capture_live_phase(session_id, "active", ".review/native-melody-memory-formal-active.png"): return false
			_active_capture_done = _phase_capture_completed
		if phrase_notes.size() != Model.PHRASES[phrase_index].size():
			await _fail("Phrase driver did not observe the complete finite cue before input")
			return false
		played_phrase = phrase_index
		await get_tree().create_timer(0.18).timeout
		for note_index in phrase_notes.size():
			if pointer:
				if not await _pointer_note(session_id, int(phrase_notes[note_index])): return false
			else:
				_key(KEY_1 + phrase_notes[note_index])
			await get_tree().create_timer(maxf(0.18, float(Model.RHYTHMS[phrase_index][note_index + 1]) if note_index + 1 < phrase_notes.size() else 0.18)).timeout
		phrase_notes.clear()
	if _latched_result_session_id != session_id or _latched_result.is_empty():
		await _fail("Observed-note driver timed out before natural model completion")
		return false
	return true

func _pointer_note(session_id: int, note: int) -> bool:
	var session := _session_by_id(session_id)
	if session == null or session.presentation == null:
		await _fail("Pointer note had no live Melody session or presentation before input")
		return false
	var view: View = session.presentation as View
	var design: Vector2 = view.INSTRUMENT_CENTERS[note]
	var local: Vector2 = design * view.size / View.DESIGN_SIZE
	var point: Vector2 = get_viewport().get_final_transform() * (view.get_global_transform_with_canvas() * local)
	_click(point)
	await get_tree().process_frame
	if _latched_result_session_id == session_id and not _latched_result.is_empty(): return true
	if _session_by_id(session_id) == null:
		await _fail("Pointer note freed the Melody session without a matching natural finished result")
		return false
	return true

func _capture_live_phase(session_id: int, expected_phase: String, path: String) -> bool:
	_phase_capture_completed = false
	await RenderingServer.frame_post_draw
	var session := _session_by_id(session_id)
	if session == null:
		if _latched_result_session_id == session_id and not _latched_result.is_empty(): return true
		await _fail("Melody session disappeared while capturing the %s phase" % expected_phase)
		return false
	var state: Dictionary = session.melody_model.snapshot()
	if str(state.phase) != expected_phase:
		return true # The capture request landed on a phase boundary; the live driver will retry.
	if not main._capture(path):
		await _fail("Could not capture Melody's actual %s phase" % expected_phase)
		return false
	_phase_capture_completed = true
	return true

func _enter_practice(session_id: int) -> bool:
	var session := _session_by_id(session_id)
	if session == null: return false
	if not await _native_click_button(session.minigame_hud.find_child("PauseButton", true, false), "pause before melody practice"): return false
	if not await _native_click_button(session.minigame_hud.find_child("PracticeButton", true, false), "restart as melody practice"): return false
	session = _session_by_id(session_id)
	if session == null or not session.practice_mode or not session.assisted or not session.reduced_motion or int(session.melody_model.snapshot().phrase_index) != 0:
		await _fail("Practice action did not preserve assist/reduced settings and reset the melody")
		return false
	_practice_before = _progress_subset()
	return true

func _capture_result(result: Dictionary, session_id: int) -> void:
	var candidate: Object = instance_from_id(session_id)
	if not (candidate is Control) or not is_instance_valid(candidate): return
	var session := candidate as Control
	_latched_result = result.duplicate(true)
	_latched_result["model"] = session.melody_model.snapshot().duplicate(true)
	_latched_result["ledger"] = session.score_events.duplicate(true)
	_latched_result_session_id = session_id

func _capture_pause_state(session_id: int) -> void:
	var session := _session_by_id(session_id)
	if session == null: return
	var state: Dictionary = session.melody_model.snapshot()
	_pause_evidence = {
		"session_id": session_id,
		"elapsed": float(state.elapsed),
		"phase_elapsed": float(state.phase_elapsed),
		"note_start_serial": int(state.note_start_serial),
		"paused": session.paused,
	}

func _capture_retry_state(session_id: int) -> void:
	var session := _session_by_id(session_id)
	if session == null: return
	var state: Dictionary = session.melody_model.snapshot()
	_retry_evidence = {
		"session_id": session_id,
		"phrase_index": int(state.phrase_index),
		"note_start_serial": int(state.note_start_serial),
		"elapsed": float(state.elapsed),
		"score": int(session.score),
		"paused": session.paused,
	}

func _session_by_id(session_id: int) -> Control:
	var session: Object = instance_from_id(session_id)
	if session is Control and is_instance_valid(session) and is_instance_valid(main) and main.session == session:
		return session as Control
	return null

func _progress_subset() -> Dictionary:
	return {
		"photos": progress.photos.duplicate(true),
		"achievements": progress.achievements.duplicate(true),
		"quests": progress.quests.duplicate(true),
		"pending": progress.platform_pending_achievements.duplicate(true),
		"wardrobe": progress.wardrobe_rewarded_games.duplicate(true),
		"coins": progress.coins,
	}

func _wait_until(predicate: Callable, label: String) -> bool:
	var deadline := _wall_deadline(5.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not predicate.call():
		await _fail("Timed out: " + label)
		return false
	return true

func _activate_main_button(needle: String, context: String) -> bool:
	var button: Button = _find(main.overlay, needle)
	if button == null:
		await _fail("Missing Main button for " + context)
		return false
	return await _native_click_button(button, context)

## Engine slowdown extends wall-clock budgets, never gameplay windows or inputs.
## A 0.05 floor and one-hour ceiling keep every wait finite even at zero scale.
func _wall_deadline(game_seconds: float) -> int:
	var wall_ms := mini(3600000, int(ceil(game_seconds * 1000.0 * _fixed_clock_slack() / maxf(Engine.time_scale, 0.05))))
	return Time.get_ticks_msec() + wall_ms

## Hang guards only: a fixed-FPS (or Movie Maker) run on a loaded host renders far
## slower than real time, so wall budgets stretch there; gameplay windows do not.
func _fixed_clock_slack() -> float:
	return 40.0 if not Engine.get_write_movie_path().is_empty() or OS.get_cmdline_args().has("--fixed-fps") else 1.0
