extends Node

const MainScene = preload("res://game/main.tscn")
var main: Node
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Boat integration needs an absolute isolated save path")
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--boat-save-failure-child"):
		await _save_failure_child()
		return
	Progress.reset_progress()
	main = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)
	_check(main.get("boat_stage") != null, "first run opens ferry before arrival")
	if main.get("boat_stage") == null:
		await _finish()
		return
	var original_stage: Node3D = main.boat_stage
	main._show_boat_prologue()
	_check(main.boat_stage == original_stage, "reentrant start retains one stage")
	var before := _snapshot()
	var camera: Transform3D = main.boat_stage._camera_transform
	for index in range(5):
		_check(main.dialogue_index == index and main.boat_stage.beat_index == index, "each line supplies its beat")
		main.dialogue_panel.reveal_all()
		main._next_dialogue()
	_check(Progress.prologue_seen and not Progress.intro_seen and main.boat_stage == null, "finish saves boat flag and starts original arrival")
	_check(main.dialogue == main.story.intro_lines(), "arrival text remains original")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Progress._save_path()))
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Progress._save_path() + ".bak"))
	_check(saved.prologue_seen and not backup.prologue_seen, "first-run completion saves flag once")
	_check(main.dialogue_panel.cancel_button.text == "結束對話", "ordinary cancel text stays unchanged")
	_check(main.world.camera.transform == camera and main.world.player.visible and main.world.is_physics_processing(), "finish restores stage exactly")
	main._cancel_dialogue()
	_check(Progress.intro_seen and main.modal_kind == "", "arrival skip opens free roam")
	_check(before == _snapshot(), "finish and arrival award nothing")
	await _dispose()

	# A seen boat flag (including legacy save migration) preserves arrival-only startup.
	Progress.intro_seen = false
	Progress.save_progress()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Progress._save_path()))
	legacy.erase("prologue_seen")
	var file := FileAccess.open(Progress._save_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	Progress.load_progress()
	await _spawn()
	_check(main.boat_stage == null and main.dialogue == main.story.intro_lines(), "seen and legacy profiles keep arrival-only path")
	main._cancel_dialogue()
	await _dispose()
	Progress.intro_seen = true
	Progress.prologue_seen = false
	await _spawn()
	_check(main.boat_stage == null and main.modal_kind == "", "seen arrival never forces a boat after update")
	var position: Transform3D = main.world.player.transform
	camera = main.world.camera.transform
	before = _snapshot()
	for repeat in range(3):
		main._show_pause()
		var replay: Button = main.overlay.find_child("PauseBoatPrologueButton", true, false)
		_check(replay != null, "pause offers boat replay outside a minigame")
		if replay == null: break
		position = main.world.player.transform
		camera = main.world.camera.transform
		replay.pressed.emit()
		_check(main.boat_stage != null and main.dialogue_panel.cancel_button.text == "直接下船", "replay starts contextual boat dialogue")
		_check(not main.dialogue_panel.cancel_button.tooltip_text.is_empty(), "boat skip has contextual help")
		_check(main.world.is_processing() and not main.audio._paused,"replay resumes world presentation and dialogue audio after pause")
		if repeat == 0:
			for index in range(5):
				main.dialogue_panel.reveal_all()
				main._next_dialogue()
		else: main._cancel_dialogue()
		main._cancel_dialogue()
		_check(main.modal_kind == "" and main.boat_stage == null and main.world.player.transform == position and main.world.camera.transform == camera and main.world.player.visible and main.world.is_physics_processing(), "repeat skip and duplicate completion return to exact free roam")
		await _frames(2)
		_check(main.world.find_children("FerryTravellerPreview", "Sprite3D", true, false).is_empty(), "replay frees its actor")
	_check(_snapshot() == before, "replay changes no rewards or appearance")
	main.session = main.Session.new()
	main._show_pause()
	_check(main.overlay.find_child("PauseBoatPrologueButton", true, false) == null, "session pause has no boat replay")
	main._show_boat_prologue()
	_check(main.boat_stage == null, "replay refuses a live minigame")
	main._close()
	main.session.free()
	main.session = null
	await _dispose()

	Progress.intro_seen = false
	Progress.prologue_seen = false
	await _spawn()
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	main._unhandled_input(escape)
	_check(Progress.prologue_seen and not Progress.intro_seen and main.dialogue == main.story.intro_lines(), "first-run skip still reaches arrival")
	main._cancel_dialogue()
	await _dispose()

	# Removal and replacement interrupt presentation without completing progress.
	for interruption in ["panel", "replacement", "scene"]:
		Progress.intro_seen = false
		Progress.prologue_seen = false
		await _spawn()
		var world: Node3D = main.world
		camera = main.boat_stage._camera_transform
		if interruption == "scene":
			get_tree().root.remove_child(main)
		else:
			if interruption == "panel": main.dialogue_panel.free()
			else: main._show_arrival()
		_check(not Progress.prologue_seen and not Progress.intro_seen, "interruption does not complete either intro: " + interruption)
		_check(main.boat_stage == null and world.player.visible and world.is_physics_processing() and world.camera.transform == camera, "interruption restores stage: " + interruption)
		if interruption == "panel": _check(main.hud.visible,"interrupted dialogue restores HUD")
		if interruption == "replacement": _check(main.dialogue_panel.cancel_button.text == "結束對話","replacement restores ordinary cancel text")
		await _dispose()

	# Optional story data or missing stage anchors safely use the original arrival.
	Progress.intro_seen = true
	await _spawn()
	main.story._story_data.erase("prologue_lines")
	main._show_boat_prologue(true)
	_check(main.boat_stage == null and main.dialogue == main.story.intro_lines(), "missing optional story falls back to arrival")
	main._cancel_dialogue()
	main.story = main.Story.new()
	main.world.get_node("FerryDeckStageAnchor").free()
	main._show_boat_prologue(true)
	_check(main.boat_stage == null and main.dialogue == main.story.intro_lines(), "failed stage preparation falls back to arrival")
	main._cancel_dialogue()
	await _dispose()
	_test_save_failure_process()
	await _finish()

func _test_save_failure_process() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var child_path := save_path.get_base_dir().path_join("failure-child/progress.json")
	OS.set_environment("SNAPLAND_SAVE_PATH",child_path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--audio-driver","Dummy","--rendering-method","gl_compatibility","res://game/tests/test_boat_prologue_integration.tscn","--","--boat-save-failure-child"],output,true)
	OS.set_environment("SNAPLAND_SAVE_PATH",save_path)
	var expected := "ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path
	var errors: Array[String] = []
	var passed := false
	var child_output := str(output[0] if not output.is_empty() else "")
	for line in child_output.split("\n"):
		var clean := line.strip_edges()
		if clean.contains("ERROR:"): errors.append(clean)
		if clean == "PASS: boat save-failure continues arrival without rewards": passed = true
	var details := "exit=%d passed=%s expected=%s errors=%s output_tail=%s" % [code,passed,expected.left(500),JSON.stringify(errors).left(1000),child_output.right(3000)]
	_check(code == 0 and passed and errors == [expected], "isolated real IO failure continues arrival; exactly one expected diagnostic and no hidden runtime errors; " + details)

func _save_failure_child() -> void:
	Progress.reset_progress()
	await _spawn()
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var saved := FileAccess.get_file_as_string(path)
	var before := _snapshot()
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "child blocks temporary write")
	main._cancel_dialogue()
	_check(not Progress.prologue_seen and not Progress.intro_seen and main.boat_stage == null and main.dialogue == main.story.intro_lines(), "failed save still starts original arrival without false completion")
	_check(main.world.player.visible and main.world.is_physics_processing() and _snapshot() == before and FileAccess.get_file_as_string(path) == saved, "failed save restores stage and preserves all durable rewards")
	DirAccess.remove_absolute(path + ".tmp")
	await _dispose()
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: boat save-failure continues arrival without rewards")
	get_tree().quit(0 if failures.is_empty() else 1)

func _snapshot() -> Dictionary:
	var result := {}
	for field in ["coins", "photos", "achievements", "quests", "appearance", "equipped", "owned_clothes", "_extra_fields"]:
		result[field] = Progress.get(field).duplicate(true) if Progress.get(field) is Dictionary or Progress.get(field) is Array else Progress.get(field)
	return result

func _spawn() -> void:
	main = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)

func _dispose() -> void:
	if not is_instance_valid(main): return
	# Match real quit so restored world physics cannot restart audio during the wait.
	main.quitting = true
	main.audio.shutdown()
	main.world.area_changed.emit("海風碼頭")
	await get_tree().create_timer(0.2).timeout
	_check(main.audio._active_context.is_empty(), "pending area event cannot restart audio during fixture teardown")
	main.free()
	main = null
	await _frames(3)

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func _finish() -> void:
	await _dispose()
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: boat prologue first-run, replay, interruption, and unchanged rewards")
	get_tree().quit(0 if failures.is_empty() else 1)
