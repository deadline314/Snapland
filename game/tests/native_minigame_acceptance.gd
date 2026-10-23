extends "res://game/tests/native_review.gd"

## Shared helpers for per-game native acceptance routes (SG-18, SG-19, ...).
## Inputs go through Input.parse_input_event or real button clicks; the routes
## never write score, grade or completion fields. All waits count rendered
## frames instead of wall-clock time, so a --write-movie run (fixed 60 FPS game
## clock) stays deterministic even when the machine renders slower than real time.

const DEFAULT_WAIT_FRAMES := 600
var capture_dir := ".review/native-acceptance"
var captured: Array[String] = []
var _frame_budget := 0
## --video-only: record just the formal standard round for a short normal-speed movie.
var video_only := false

## Reads --capture-dir=<res-relative folder> and --frame-budget=<frames> user arguments.
func _read_arguments(default_dir: String, default_budget: int) -> void:
	capture_dir = default_dir
	_frame_budget = default_budget
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.get_slice("=", 1)
		elif argument == "--video-only":
			video_only = true
		elif argument.begins_with("--frame-budget=") and argument.get_slice("=", 1).is_valid_int():
			_frame_budget = argument.get_slice("=", 1).to_int()

## Fresh isolated profile with every tutorial already seen (the first-entry
## tutorial route is covered by native_tutorial_lifecycle_review).
func _start_main() -> bool:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native acceptance requires a GPU window and an isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return false
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return false
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return false
	get_tree().root.add_child(main)
	await _frames(60)
	return true

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
		_frame_budget -= 1
		if _frame_budget == 0:
			await _fail("Native acceptance exceeded its frame budget")
			return

func _wait_frames_until(predicate: Callable, context: String, max_frames := DEFAULT_WAIT_FRAMES) -> bool:
	for _index in max_frames:
		if predicate.call(): return true
		await _frames(1)
	if predicate.call(): return true
	await _fail("Timed out after %d frames waiting for %s; modal=%s session=%s" % [max_frames, context, str(main.modal_kind), "live" if main.session != null else "none"])
	return false

## A key queued now is handled on the following frame, after one more frame of
## round time. Waiting until phase + 1.5 frames reaches `target` therefore lands
## the input within half a frame of the target (measured: +17 ms without it).
func _wait_for_session_phase(session: Control, target: float, max_frames := 1200) -> bool:
	var lead := 1.5 / 60.0
	return await _wait_frames_until(func() -> bool: return is_instance_valid(session) and float(session.phase) + lead >= target, "session phase %.3f" % target, max_frames)

func _set_settings(assisted: bool, reduced: bool, time_phase: String) -> bool:
	progress.settings["assist"] = assisted
	progress.settings["reduced_motion"] = reduced
	if not main._select_time_phase(time_phase):
		await _fail("Main rejected time phase " + time_phase)
		return false
	return true

## Walks to a real park station, opens it with E and clicks the given start button.
func _launch_station(game_id: String, start_label: String) -> Control:
	var found := false
	for point in main.world.points:
		if point.id != game_id: continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		await _fail("Station %s is missing from the real park" % game_id)
		return null
	if not await _wait_frames_until(func() -> bool: return main.world.nearest.get("id", "") == game_id, "station %s to become nearest" % game_id, 240): return null
	_key(KEY_E)
	if not await _wait_frames_until(func() -> bool: return main.modal_kind != "", "station %s details" % game_id, 240): return null
	if not await _click_overlay(start_label, "start " + game_id): return null
	if not await _wait_frames_until(func() -> bool: return main.session != null and main.session.game_id == game_id, "session %s to start" % game_id, 240): return null
	return main.session

func _click_overlay(label: String, context: String) -> bool:
	await _frames(3)
	var button: Button = _find(main.overlay, label)
	if button == null:
		await _fail("Could not find overlay button '%s' to %s" % [label, context])
		return false
	return await _native_click_button(button, context)

func _click_hud(session: Control, node_name: String, context: String) -> bool:
	await _frames(2)
	var button := session.minigame_hud.find_child(node_name, true, false) as BaseButton
	if button == null:
		await _fail("Could not find HUD button %s to %s" % [node_name, context])
		return false
	return await _native_click_button(button, context)

## Real pause → frozen clock → resume, then pause → retry → confirm resets the round.
func _pause_resume_retry(session: Control, freeze_frames := 30) -> bool:
	if not await _click_hud(session, "PauseButton", "pause"): return false
	var frozen := float(session.phase)
	await _frames(freeze_frames)
	if not session.paused or not is_equal_approx(float(session.phase), frozen):
		await _fail("Pause did not freeze the round clock: paused=%s phase=%.3f frozen=%.3f" % [session.paused, session.phase, frozen])
		return false
	if not await _click_hud(session, "ResumeButton", "resume"): return false
	if not await _wait_frames_until(func() -> bool: return not session.paused and float(session.phase) > frozen, "round clock to resume", 120): return false
	if not await _click_hud(session, "PauseButton", "pause before retry"): return false
	if not await _click_hud(session, "RetryButton", "ask to retry"): return false
	if not await _click_hud(session, "ConfirmAction", "confirm retry"): return false
	if not await _wait_frames_until(func() -> bool: return not session.paused and float(session.phase) < 0.25 and int(session.score) == 0, "retry to reset the round", 120): return false
	return true

func _capture(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var relative := capture_dir.path_join(name)
	if not main._capture(relative):
		await _fail("Could not capture " + relative)
		return false
	captured.append(relative)
	print("CAPTURE: ", relative)
	return true

func _persistent_snapshot() -> Dictionary:
	return {
		"photos": progress.photos.keys(),
		"achievements": progress.achievements.duplicate(true),
		"quests": progress.quests.duplicate(true),
		"appearance": progress.appearance.duplicate(true),
		"equipped": progress.equipped.duplicate(true),
		"owned_clothes": progress.owned_clothes.duplicate(true),
		"coins": progress.coins,
		"platform_pending_achievements": progress.platform_pending_achievements.duplicate(true),
	}

## Result modal text must contain every needle (qualification, score line, ...).
func _result_shows(needles: Array) -> bool:
	if main.modal_kind != "result": return false
	var text := _visible_text(main.overlay)
	for needle in needles:
		if not text.contains(str(needle)): return false
	return true

func _visible_text(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is Label and (node as Label).is_visible_in_tree(): parts.append((node as Label).text)
	if node is Button and (node as Button).is_visible_in_tree(): parts.append((node as Button).text)
	for child in node.get_children():
		var nested := _visible_text(child)
		if not nested.is_empty(): parts.append(nested)
	return "\n".join(parts)

## Connect before play; the returned dictionary fills when the session finishes.
func _latch_result(session: Control) -> Dictionary:
	var latched := {}
	session.finished.connect(func(result: Dictionary): latched.merge(result, true), CONNECT_ONE_SHOT)
	return latched

func _wait_result(latched: Dictionary, max_frames := 600) -> Dictionary:
	if not await _wait_frames_until(func() -> bool: return not latched.is_empty() and main.modal_kind == "result", "minigame result", max_frames): return {}
	await _frames(4)
	return latched

func _return_to_park() -> bool:
	if not await _click_overlay("返回遊園", "return to the park"): return false
	return await _wait_frames_until(func() -> bool: return main.session == null and main.modal_kind == "", "return to the park", 240)
