extends Node
## Scripted native evidence through Main; never a claim of human play or listening.
const MainScene = preload("res://game/main.tscn")
var main: Node
var output_directory := ""
var requested_size := Vector2i(1280,720)
var failures: Array[String] = []
var report := {"scripted_fixture":true,"human_played":false,"captures":[],"appearance":{},"equipped":{}}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if DisplayServer.get_name() == "headless" or not path.is_absolute_path():
		push_error("Native boat review requires a GPU window and isolated absolute SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	var dimensions := OS.get_environment("SNAPLAND_BOAT_REVIEW_SIZE")
	if not dimensions.is_empty():
		var parts := dimensions.split("x")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			push_error("Boat review size must be WIDTHxHEIGHT")
			get_tree().quit(1)
			return
		requested_size = Vector2i(int(parts[0]),int(parts[1]))
	if requested_size.x < 800 or requested_size.y < 600:
		push_error("Boat review needs at least 800x600")
		get_tree().quit(1)
		return
	output_directory = OS.get_environment("SNAPLAND_BOAT_REVIEW_OUTPUT")
	if output_directory.is_empty(): output_directory = path.get_base_dir().path_join("native-boat-review")
	if not output_directory.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		push_error("Boat review output must be a writable absolute directory")
		get_tree().quit(1)
		return
	var appearance: Dictionary = Progress.appearance.duplicate(true)
	var equipped: Dictionary = Progress.equipped.duplicate(true)
	var owned: Array = Progress.owned_clothes.duplicate()
	Progress.reset_progress()
	Progress.appearance = appearance
	Progress.equipped = equipped
	Progress.owned_clothes.assign(owned)
	var scale_text := OS.get_environment("SNAPLAND_BOAT_REVIEW_TEXT_SCALE")
	var text_scale := 1.0 if scale_text.is_empty() else float(scale_text)
	if not text_scale in [1.0,1.25]:
		push_error("Boat review text scale must be 1 or 1.25")
		get_tree().quit(1)
		return
	Progress.settings["ui_scale"] = text_scale
	Progress.settings["reduced_motion"] = OS.get_environment("SNAPLAND_BOAT_REVIEW_REDUCED_MOTION") == "1"
	Progress.settings["fullscreen"] = false
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.content_scale_size = requested_size
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.size = requested_size
	await _frames(4)
	main = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	_check(window.size == requested_size and Vector2i(window.get_visible_rect().size) == requested_size,"actual window and viewport match requested size")
	report.merge({"appearance":appearance,"equipped":equipped,"text_scale":text_scale,"reduced_motion":Progress.settings.reduced_motion,"requested_size":str(requested_size),"window_size":str(window.size),"viewport_size":str(window.get_visible_rect().size),"content_scale_size":str(window.content_scale_size),"content_scale_mode":window.content_scale_mode},true)
	_check(main.boat_stage != null,"actual Main first run starts boat")
	if main.boat_stage == null:
		await _finish()
		return
	_check(main.boat_stage._appearance == appearance and main.boat_stage._equipped == equipped,"boat uses currently loaded complete appearance")
	for beat in range(5):
		_check(main.dialogue_index == beat and main.boat_stage.beat_index == beat,"Main presents expected beat")
		main.dialogue_panel.reveal_all()
		await get_tree().create_timer(0.3).timeout
		await _capture("first-run-beat-%d" % (beat+1))
		main.dialogue_panel.advance_button.pressed.emit()
	_check(Progress.prologue_seen and not Progress.intro_seen and main.boat_stage == null,"first-run finish continues to original arrival")
	main.dialogue_panel.reveal_all()
	await _capture("arrival")
	main.dialogue_panel.cancel_button.pressed.emit()
	await _frames(4)
	await _capture("return-to-island")
	main._show_pause()
	await _frames(5)
	await _capture("pause-replay-control")
	var replay: Button = main.overlay.find_child("PauseBoatPrologueButton",true,false)
	_check(replay != null,"pause provides actual replay button")
	if replay != null:
		_check(get_viewport().get_visible_rect().encloses(replay.get_global_rect()),"pause replay control fits actual viewport")
		var original: Transform3D = main.world.player.transform
		replay.pressed.emit()
		main.dialogue_panel.reveal_all()
		await _frames(5)
		await _capture("replay-controls")
		main.dialogue_panel.cancel_button.pressed.emit()
		_check(main.modal_kind == "" and main.boat_stage == null and main.world.player.transform == original,"replay skip returns to original location")
		await _frames(5)
		await _capture("replay-return")
	await _finish()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image.get_size() == requested_size,"saved image dimensions match requested size: " + label)
	var bounds := get_viewport().get_visible_rect()
	if is_instance_valid(main.dialogue_panel):
		for control in [main.dialogue_panel.advance_button,main.dialogue_panel.cancel_button,main.dialogue_label]:
			_check(bounds.encloses(control.get_global_rect()),"dialogue controls and subtitle fit: " + label)
	var file := output_directory.path_join(label + ".png")
	_check(image.save_png(file) == OK,"capture saves: " + label)
	report.captures.append({"label":label,"path":file,"image_size":str(image.get_size()),"boat_active":is_instance_valid(main.boat_stage),"action":main.boat_stage.action if is_instance_valid(main.boat_stage) else "","action_elapsed":main.boat_stage.action_elapsed if is_instance_valid(main.boat_stage) else 0.0})

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func _finish() -> void:
	if is_instance_valid(main):
		main.audio.shutdown()
		await get_tree().create_timer(0.25).timeout
		main.queue_free()
		await _frames(5)
	report["failures"] = failures
	var file := FileAccess.open(output_directory.path_join("report.json"),FileAccess.WRITE)
	_check(file != null,"review report opens")
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	for failure in failures: push_error("Boat review: " + failure)
	if failures.is_empty(): print("PASS: native Main boat first-run and replay captures ",requested_size,"; inspect images for visual acceptance")
	get_tree().quit(0 if failures.is_empty() else 1)
