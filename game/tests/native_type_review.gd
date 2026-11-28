extends Node
## Native before/after review of every kind of text surface (ART-64): park HUD,
## pause menu, dialogue, island map, album, tutorial, settings, an arcade round
## with its funny fail caption and score, and the arcade closing card.
## It saves pictures only; it asserts nothing about play quality.
## Usage: python tools/run_native_capture.py res://game/tests/native_type_review.tscn --out <dir>

const TestSaveGuard = preload("res://game/core/test_save_guard.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const MainScene = preload("res://game/main.tscn")
const Session = preload("res://game/minigames/session.gd")

var main: Node
var output_dir := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var guard_error := TestSaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir())
	if not guard_error.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Type review needs a display and an isolated save: " + guard_error)
		get_tree().quit(1)
		return
	output_dir = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://build/type-review")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var size_arg := ""
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--prefix="):
			size_arg = str(argument).trim_prefix("--prefix=")
	Progress.reset_progress()
	Progress.intro_seen = true
	Progress.prologue_seen = true
	main = MainScene.instantiate()
	add_child(main)
	await _settle(1.2)
	await _snap(size_arg + "01-park-hud")
	main._show_pause()
	await _settle(0.5)
	await _snap(size_arg + "02-pause")
	main._close()
	main._show_settings()
	await _settle(0.5)
	await _snap(size_arg + "03-settings")
	main._close()
	var lines: Array = main.story.intro_lines()
	main._start_dialogue(lines, Callable(self, "_noop"), Callable(self, "_noop"))
	await _settle(0.35)
	main.set_process(false)
	await _snap(size_arg + "04-dialogue")
	main.set_process(true)
	main._cancel_dialogue()
	main._close()
	main.modal_kind = ""
	main._show_island_map()
	await _settle(0.6)
	await _snap(size_arg + "05-island-map")
	main._close()
	main._show_album()
	await _settle(0.6)
	await _snap(size_arg + "06-album")
	main._close()
	main._open_tutorial("game-085", "park")
	await _settle(0.6)
	await _snap(size_arg + "07-tutorial")
	if is_instance_valid(main.tutorial_panel):
		main.tutorial_panel.queue_free()
	await _settle(0.2)
	await _arcade(size_arg)
	print("PASS: type review captures saved to " + output_dir)
	if is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _arcade(prefix: String) -> void:
	var session := Session.new()
	main.ui.add_child(session)
	session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session.theme = Paper.theme()
	main.hud.hide()
	main.world.hide()
	session.start("game-085", false)
	var driver: RefCounted = session.active_driver
	if driver == null:
		push_warning("Type review: no arcade driver for game-085")
		return
	session.set_process(false)
	session.set_paused(false)
	var step := 1.0 / 60.0
	for _frame in int(2.6 / step):
		session._process(step)
	for points in [180, 160, 180]:
		driver.touched = true
		driver.add_score(points, "+%d" % points)
		for _frame in 20:
			session._process(step)
	driver.funny_fail("夾成書籤了！")
	session._process(step)
	# Freeze the round and move only the picture's clock, so the game's own
	# later beats cannot replace the caption being reviewed.
	var view: Control = driver._view
	var frozen: Dictionary = driver.snapshot().duplicate()
	var stamped := float(frozen.get("word_at", 0.0))
	for shot: Array in [[0.1, "08-arcade-fail-caption"], [0.5, "09-arcade-fail-settled"]]:
		frozen.clock = stamped + float(shot[0])
		view.present(frozen, false)
		await _settle(0.05, false)
		await _snap(prefix + str(shot[1]))
	frozen.word = "剛好！+180"
	frozen.word_good = true
	frozen.clock = stamped + 0.5
	view.present(frozen, false)
	await _settle(0.05, false)
	await _snap(prefix + "09b-arcade-good-settled")
	driver.play_time = driver.round_seconds - 0.01
	for _frame in int(1.0 / step):
		session._process(step)
	await _settle(0.05, false)
	await _snap(prefix + "10-arcade-closing")


func _settle(seconds: float, real := true) -> void:
	if real:
		await get_tree().create_timer(seconds).timeout
	for _frame in 3:
		await get_tree().process_frame


func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output_dir.path_join(file_name + ".png")
	if image.is_empty() or image.save_png(path) != OK:
		push_error("Type review could not save " + path)


func _noop() -> void:
	pass
