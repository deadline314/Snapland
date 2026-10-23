extends Node
## GPU review of the first-island flow from a new save, using real key/mouse
## events: arrival dialogue, signposts, all three characters, quest hand-off,
## time-of-day changes and a saved-profile continue. Positions are reached by
## walking; nothing assigns progress, rewards or conversation choices.
##
## Env: SNAPLAND_SAVE_PATH (isolated), SNAPLAND_REVIEW_DIR (absolute output dir).
## Optional --write-movie captures video+PCM; the report lists every revealed
## dialogue glyph with its frame so beeps in the PCM can be matched to text.

const MAIN_SCENE := preload("res://game/main.tscn")
const MOVE_KEYS := {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S}
const ARRIVE_RADIUS := 0.35
const MAX_WALK_FRAMES := 1800
const LINE_HOLD_FRAMES := 24
# Standing spots beside each character/sign and fountain-safe routes between them.
const PLAZA_SIGN_STAND := Vector2(0.0, 5.6)
const TICKET_STAND := Vector2(-3.8, 5.9)
const IMP_STAND := Vector2(-4.1, -6.4)
const ANNOUNCER_STAND := Vector2(3.0, -2.8)
const ANNOUNCER_TO_PLAZA_SIGN := [Vector2(4.2, -2.8), Vector2(4.2, 5.6), PLAZA_SIGN_STAND]
const PLAZA_SIGN_TO_ANNOUNCER := [Vector2(4.2, 5.6), Vector2(4.2, -2.8), ANNOUNCER_STAND]

var _main: Node
var _progress: Node
var _out := ""
var _held: Dictionary = {}
var _report := {
	"status": "running", "human_played": false,
	"scripted_input": "Input.parse_input_event keyboard/mouse events; walking only, no teleport",
	"walk": [], "conversations": [], "signposts": [], "screenshots": [], "glyphs": [], "phases": [], "volume_segments": [],
}
var _glyph_watch_enabled := true
var _last_visible := -1
var _last_line_key := ""

func _ready() -> void:
	_out = OS.get_environment("SNAPLAND_REVIEW_DIR").strip_edges()
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty() or _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native island flow review needs a GPU display, SNAPLAND_SAVE_PATH and SNAPLAND_REVIEW_DIR.")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_report["first_frame"] = Engine.get_process_frames()
	_report["capture_fps"] = int(OS.get_environment("SNAPLAND_REVIEW_FPS")) if OS.get_environment("SNAPLAND_REVIEW_FPS").is_valid_int() else 0
	call_deferred("_run")

func _process(_delta: float) -> void:
	_watch_glyphs()

func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	_progress = get_tree().root.get_node_or_null("Progress")
	_progress.reset_progress()
	_progress.intro_seen = false
	_progress.settings["reduced_motion"] = false
	_progress.save_progress()
	_main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(_main)
	await _frames(10)
	if _main.modal_kind != "dialogue":
		_fail("new save did not open the arrival dialogue")
		return
	# Loading frames can be long enough to finish line one; then use line two,
	# which always starts from zero after E.
	if not _main.dialogue_panel.is_revealing():
		await _press(KEY_E)
	while _main.dialogue_panel.is_revealing() and _main.dialogue_label.visible_characters < 4:
		await get_tree().process_frame
	var line_index: int = _main.dialogue_index
	var mid_reveal := {"line": line_index, "visible": _main.dialogue_label.visible_characters, "length": _main.dialogue_label.text.length(), "button": _main.dialogue_panel.advance_button.text, "speaker": _main.dialogue_panel.speaker_label.text, "revealing": _main.dialogue_panel.is_revealing()}
	_report["arrival_mid_reveal"] = mid_reveal
	if not bool(mid_reveal.revealing) or str(mid_reveal.button) != _main.dialogue_panel.ADVANCE_REVEAL_TEXT:
		_fail("arrival line is not mid-reveal with the show-whole-line control")
		return
	await _shot("arrival-typewriter")
	if not _main.dialogue_panel.is_revealing():
		_fail("line finished during the screenshot frame; cannot test completing it with E")
		return
	# E while revealing finishes the line in place; the next E moves on.
	await _press(KEY_E)
	_report["arrival_after_first_e"] = {"line": _main.dialogue_index, "visible": _main.dialogue_label.visible_characters, "button": _main.dialogue_panel.advance_button.text}
	if _main.dialogue_panel.is_revealing() or _main.dialogue_index != line_index:
		_fail("first E did not complete the current line in place")
		return
	await _shot("arrival-line-complete")
	await _record_conversation("arrival", true)
	if not _progress.intro_seen or _main.modal_kind != "":
		_fail("arrival dialogue did not return to the park")
		return

	await _walk_path("dock-sign", [Vector2(1.6, 16.2)])
	if not _ok(): return
	await _signpost_shot("dock", "sign-dock-noon")
	await _walk_path("plaza-sign", [Vector2(0.0, 12.0), PLAZA_SIGN_STAND])
	if not _ok(): return
	await _signpost_shot("plaza", "sign-plaza-before")
	await _walk_path("ticket", [TICKET_STAND])
	await _talk("guide", "ticket-first")
	if not _ok(): return
	if not _progress.photos.has("photo-welcome-story-1"):
		_fail("first 票票 conversation did not grant the story photo")
		return
	await _walk_path("imp", [Vector2(-4.2, -4.2), IMP_STAND])
	await _talk("quest-001", "imp-request")
	if not _ok(): return
	if _main.modal_kind != "quest" or int(_progress.quests.get("quest-001", 0)) != 1:
		_fail("小角 conversation did not hand over the request card")
		return
	await _shot("imp-quest-card")
	await _press(KEY_ESCAPE)
	await _walk_path("announcer", [Vector2(-4.2, -4.4), Vector2(2.2, -4.4), ANNOUNCER_STAND])
	await _talk("quest-002", "announcer-request")
	if not _ok(): return
	if _main.modal_kind != "quest" or int(_progress.quests.get("quest-002", 0)) != 1:
		_fail("阿浪 conversation did not hand over the request card")
		return
	await _press(KEY_ESCAPE)
	await _walk_path("plaza-sign-return", ANNOUNCER_TO_PLAZA_SIGN)
	if not _ok(): return
	await _signpost_shot("plaza", "sign-plaza-after-requests")
	await _walk_path("ticket-again", [TICKET_STAND])
	await _talk("guide", "ticket-underway")
	await _walk_path("avenue-sign", [Vector2(-4.2, -4.2), Vector2(-1.6, -9.0), Vector2(0.0, -18.0)])
	if not _ok(): return
	await _signpost_shot("avenue", "sign-avenue-noon")
	await _walk_path("avenue-return", [Vector2(3.0, -13.0), Vector2(3.0, -9.0), Vector2(2.2, -4.6), ANNOUNCER_STAND])
	if not _ok(): return

	for phase_id in ["night", "dusk", "dawn"]:
		await _select_phase(phase_id)
		if str(_main.world.nearest.get("id", "")) != "quest-002":
			await _walk_path("announcer-%s" % phase_id, PLAZA_SIGN_TO_ANNOUNCER)
		await _talk("quest-002", "announcer-%s" % phase_id)
		if not _ok(): return
		if _main.modal_kind == "quest":
			await _press(KEY_ESCAPE)
		await _walk_path("plaza-sign-%s" % phase_id, ANNOUNCER_TO_PLAZA_SIGN)
		if not _ok(): return
		await _signpost_shot("plaza", "sign-plaza-%s" % phase_id)
	await _walk_path("announcer-volume", PLAZA_SIGN_TO_ANNOUNCER)
	await _volume_check()
	if not _ok(): return

	# Continue from the saved profile in a fresh Main: no arrival replay, same state.
	_progress.save_progress()
	var before := {"quests": _progress.quests.duplicate(true), "photos": _progress.photos.keys().size(), "coins": _progress.coins}
	_main.queue_free()
	await _frames(4)
	_progress.load_progress()
	_main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(_main)
	await _frames(12)
	var after := {"quests": _progress.quests.duplicate(true), "photos": _progress.photos.keys().size(), "coins": _progress.coins}
	_report["continue"] = {"before": before, "after": after, "modal_after_load": _main.modal_kind}
	if _main.modal_kind != "" or str(before) != str(after):
		_fail("continuing the saved profile replayed arrival or changed progress")
		return
	await _walk("continue-plaza", Vector2(0.0, 5.6))
	await _signpost_shot("plaza", "sign-plaza-continue")
	_report.status = "passed"
	_write_report()
	print("PASS: native island flow review (%d conversations, %d signpost views)" % [_report.conversations.size(), _report.signposts.size()])
	await _main._quit_game()

func _talk(point_id: String, label: String) -> void:
	print("FLOW talk %s at %s" % [label, point_id])
	if str(_main.world.nearest.get("id", "")) != point_id:
		_fail("%s: nearest point is %s, not %s" % [label, str(_main.world.nearest.get("id", "")), point_id])
		return
	await _press(KEY_E)
	await _frames(2)
	if _main.modal_kind != "dialogue":
		_fail("%s: E did not open dialogue" % label)
		return
	await _frames(10)
	await _shot("talk-%s" % label)
	await _record_conversation(label, false)

## Lets each line reveal on its own (so beeps play), holds it, then presses E.
func _record_conversation(label: String, skip_first_reveal: bool) -> void:
	var record := {"label": label, "conversation_id": _main.last_conversation_id, "lines": [], "phase": str(_progress.settings.get("time_phase", "")), "frame": Engine.get_process_frames()}
	var guard := 0
	while _main.modal_kind == "dialogue" and guard < 40:
		guard += 1
		var waited := 0
		while _main.dialogue_panel != null and _main.dialogue_panel.is_revealing() and waited < 600:
			waited += 1
			await get_tree().process_frame
		if _main.dialogue_panel == null:
			break
		(record.lines as Array).append({"speaker": _main.dialogue_panel.speaker_label.text, "text": _main.dialogue_label.text, "button": _main.dialogue_panel.advance_button.text})
		await _frames(LINE_HOLD_FRAMES)
		await _press(KEY_E)
		await _frames(2)
	if skip_first_reveal:
		record["note"] = "first line was completed with E mid-reveal"
	(_report.conversations as Array).append(record)

func _walk(label: String, target: Vector2) -> void:
	print("FLOW walk %s -> %s (modal=%s)" % [label, str(target), _main.modal_kind])
	var start: Vector3 = _main.world.player.position
	var frames := 0
	var travelled := 0.0
	var previous := Vector2(start.x, start.z)
	while frames < MAX_WALK_FRAMES:
		var here := Vector2(_main.world.player.position.x, _main.world.player.position.z)
		var delta := target - here
		if delta.length() <= ARRIVE_RADIUS:
			break
		_hold("left", delta.x < -0.12)
		_hold("right", delta.x > 0.12)
		_hold("up", delta.y < -0.12)
		_hold("down", delta.y > 0.12)
		await get_tree().physics_frame
		frames += 1
		var now := Vector2(_main.world.player.position.x, _main.world.player.position.z)
		var step := now.distance_to(previous)
		if step > 0.5:
			_fail("%s: player jumped %.2fm in one frame" % [label, step])
			return
		travelled += step
		previous = now
	for direction in MOVE_KEYS:
		_hold(direction, false)
	await _frames(6)
	var end := Vector2(_main.world.player.position.x, _main.world.player.position.z)
	(_report.walk as Array).append({"label": label, "target": [target.x, target.y], "end": [snappedf(end.x, 0.01), snappedf(end.y, 0.01)], "metres": snappedf(travelled, 0.01), "frames": frames, "area": _main.world.current_area, "nearest": str(_main.world.nearest.get("id", ""))})
	if end.distance_to(target) > 0.6:
		_fail("%s: stopped %.2fm from target at %s" % [label, end.distance_to(target), str(end)])

func _signpost_shot(signpost_id: String, shot_name: String) -> void:
	await _frames(8)
	for record in _main.world.story_landmarks.signpost_report():
		if str(record.id) == signpost_id:
			(_report.signposts as Array).append({"id": signpost_id, "shot": shot_name, "lines": record.lines, "phase": str(_progress.settings.get("time_phase", ""))})
	await _shot(shot_name)

func _select_phase(phase_id: String) -> void:
	await _press(KEY_T)
	await _frames(6)
	var button := _main.overlay.find_child("TimePhase_%s" % phase_id, true, false) as Button
	if button == null:
		_fail("time panel has no %s button" % phase_id)
		return
	await _click(button)
	await _frames(6)
	await _press(KEY_T)
	await _frames(6)
	(_report.phases as Array).append({"phase": phase_id, "applied": str(_progress.settings.get("time_phase", "")), "modal_after": _main.modal_kind})
	if str(_progress.settings.get("time_phase", "")) != phase_id or _main.modal_kind != "":
		_fail("time panel did not apply %s and close" % phase_id)

func _walk_path(label: String, points: Array) -> void:
	for index in range(points.size()):
		if not _ok(): return
		await _walk("%s-%d" % [label, index], points[index])

## SFX volume through the real settings slider: full, half and zero while a line reveals.
func _volume_check() -> void:
	for level in [1.0, 0.5, 0.0]:
		if not _ok(): return
		await _press(KEY_ESCAPE)
		await _frames(6)
		var settings_button := _main.overlay.find_child("PauseSettingsButton", true, false) as Button
		if settings_button == null:
			_fail("pause menu has no settings button")
			return
		await _click(settings_button)
		await _frames(6)
		var audio_tab := _main.overlay.find_child("SettingsTab_audio", true, false) as Button
		if audio_tab != null:
			await _click(audio_tab)
			await _frames(4)
		var slider := _main.overlay.find_child("Value_sfx_volume", true, false) as HSlider
		var music := _main.overlay.find_child("Value_music_volume", true, false) as HSlider
		if slider == null or music == null:
			_fail("settings panel sliders were not reachable")
			return
		music.value = 0.0
		slider.value = level
		await _frames(4)
		await _press(KEY_ESCAPE)
		await _frames(4)
		while _main.modal_kind != "":
			await _press(KEY_ESCAPE)
			await _frames(4)
		var start_frame := Engine.get_process_frames()
		await _talk("quest-002", "volume-%.1f" % level)
		if _main.modal_kind == "quest":
			await _press(KEY_ESCAPE)
		(_report.volume_segments as Array).append({"sfx_volume": level, "saved_sfx": float(_progress.settings.get("sfx_volume", -1)), "start_frame": start_frame, "end_frame": Engine.get_process_frames()})

func _watch_glyphs() -> void:
	if not is_instance_valid(_main) or _main.modal_kind != "dialogue" or _main.dialogue_label == null:
		_last_visible = -1
		return
	var label: Label = _main.dialogue_label
	var key := "%d:%s" % [_main.dialogue_index, label.text]
	if key != _last_line_key:
		_last_line_key = key
		_last_visible = 0
	var shown := label.visible_characters if label.visible_characters >= 0 else label.text.length()
	if label.visible_characters < 0:
		# Completing with E reveals the rest at once; mark those glyphs as skipped.
		for index in range(maxi(_last_visible, 0), shown):
			(_report.glyphs as Array).append({"frame": Engine.get_process_frames(), "speaker": _main.dialogue_panel.speaker_label.text, "glyph": label.text.substr(index, 1), "skipped": true})
		_last_visible = shown
		return
	for index in range(maxi(_last_visible, 0), shown):
		(_report.glyphs as Array).append({"frame": Engine.get_process_frames(), "speaker": _main.dialogue_panel.speaker_label.text, "glyph": label.text.substr(index, 1), "skipped": false})
	_last_visible = shown

func _hold(direction: String, down: bool) -> void:
	if bool(_held.get(direction, false)) == down:
		return
	_held[direction] = down
	_key_event(MOVE_KEYS[direction], down)

func _press(keycode: Key) -> void:
	_key_event(keycode, true)
	await _frames(2)
	_key_event(keycode, false)
	await _frames(2)

func _key_event(keycode: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = down
	Input.parse_input_event(event)

func _click(control: Control) -> void:
	var viewport_point := control.get_global_rect().get_center()
	var window_point: Vector2 = get_viewport().get_screen_transform() * viewport_point
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = window_point
		event.global_position = window_point
		Input.parse_input_event(event)
		await _frames(2)

func _ok() -> bool:
	return _report.status == "running"

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join("ISLAND-FLOW-%02d-%s.png" % [(_report.screenshots as Array).size() + 1, shot_name])
	get_viewport().get_texture().get_image().save_png(path)
	(_report.screenshots as Array).append({"name": shot_name, "path": path.get_file(), "frame": Engine.get_process_frames(), "phase": str(_progress.settings.get("time_phase", "")), "player": [snappedf(_main.world.player.position.x, 0.01), snappedf(_main.world.player.position.z, 0.01)]})

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _fail(reason: String) -> void:
	if _report.status != "running":
		return
	_report.status = "failed"
	_report["failure"] = reason
	_write_report()
	push_error("FAIL: native island flow review: " + reason)
	get_tree().quit(1)

func _write_report() -> void:
	_report["fps"] = Engine.get_frames_per_second()
	_report["movie"] = OS.has_feature("movie")
	var file := FileAccess.open(_out.path_join("island-flow-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	file.close()
