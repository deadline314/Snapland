extends Node
## MIC-2 native evidence: launches every welcome game through Main's real launch path,
## records the Master mix and logs which track and feedback sounds each game used.
## Feedback events go through the session's real `feedback` signal connection; this is a
## technical routing/mix capture, not gameplay, and never an audition.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const TestSaveGuard := preload("res://game/core/test_save_guard.gd")
const AudioDirector := preload("res://game/audio/audio_director.gd")
const MUSIC_SETTLE_SECONDS := 2.4
const FEEDBACK_GAP_SECONDS := 0.5

var main: Node
var output_dir := ""
var recorder: AudioEffectRecord
var master_bus_index := -1
var recorder_index := -1
var started_msec := 0
var timeline: Array[Dictionary] = []
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_error := TestSaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges(), OS.get_user_data_dir())
	if not save_error.is_empty():
		await _fail(save_error)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-review-output="):
			output_dir = argument.trim_prefix("--audio-review-output=").strip_edges()
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		await _fail("Pass --audio-review-output=<absolute directory>")
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var progress := get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Progress autoload is missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _wait_frames(8)
	if main.audio == null:
		await _fail("Main did not create AudioDirector")
		return
	var profiles := AudioDirector.load_game_profiles(AudioDirector.GAME_AUDIO_PROFILES_PATH)
	var games: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/welcome_games.json"))
	if not (games is Array) or games.size() != 12:
		await _fail("Expected twelve welcome games")
		return
	if not _start_recording():
		await _fail("Master recording could not start")
		return
	started_msec = Time.get_ticks_msec()
	_mark("start", "")
	for game: Dictionary in games:
		var id := str(game.id)
		main._launch_game(id, false)
		await _wait_frames(2)
		if main.session == null:
			failures.append("%s did not open a session" % id)
			continue
		await _duration(MUSIC_SETTLE_SECONDS)
		var expected_music := str(profiles.get(id, {}).get("music", AudioDirector.MUSIC_PATHS.game))
		var playing := _active_music_path()
		_mark("music", id)
		if playing != expected_music:
			failures.append("%s plays %s instead of %s" % [id, playing, expected_music])
		await _screenshot(id)
		for kind: String in AudioDirector.GAME_AUDIO_FEEDBACK_KINDS:
			main.session.feedback.emit(kind)
			var expected_sfx := str(profiles.get(id, {}).get("sfx", {}).get(kind, ""))
			var sfx_path: String = main.audio._sfx.stream.resource_path if main.audio._sfx.stream != null else ""
			_mark("feedback_" + kind, id)
			if not expected_sfx.is_empty() and sfx_path != expected_sfx:
				failures.append("%s %s played %s instead of %s" % [id, kind, sfx_path, expected_sfx])
			await _duration(FEEDBACK_GAP_SECONDS)
		main._cancel_game()
		await _duration(0.9)
		_mark("left", id)
		if main.audio.active_game_profile_id() != "":
			failures.append("%s kept its game sounds after leaving" % id)
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	if recording == null or recording.data.size() <= 50000:
		failures.append("Master recording is empty or unexpectedly small")
	else:
		recording.save_to_wav(output_dir.path_join("game-audio-mix.wav"))
	AudioServer.remove_bus_effect(master_bus_index, recorder_index)
	var report := {
		"method": "Main._launch_game for all twelve welcome games; session.feedback signal emitted by the review script for interact/success/miss; Master bus AudioEffectRecord; no gameplay input, no audition",
		"audio_driver": AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "",
		"mix_rate": AudioServer.get_mix_rate(),
		"duration_seconds": float(Time.get_ticks_msec() - started_msec) / 1000.0,
		"events": timeline,
		"failures": failures,
		"audition": "pending",
	}
	var file := FileAccess.open(output_dir.path_join("game-audio-timeline.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	main.audio.shutdown()
	await _duration(0.15)
	main.queue_free()
	await _wait_frames(4)
	if failures.is_empty():
		print("PASS: twelve games launched with their own music and feedback routing; audition pending")
		get_tree().quit(0)
	else:
		push_error("Game audio review failures: %s" % str(failures))
		get_tree().quit(1)

func _active_music_path() -> String:
	var audio: Node = main.audio
	if audio._active_music < 0:
		return ""
	var player: AudioStreamPlayer = audio._music_players[audio._active_music]
	return player.stream.resource_path if player.stream != null else ""

func _start_recording() -> bool:
	master_bus_index = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return false
	recorder = AudioEffectRecord.new()
	recorder_index = AudioServer.get_bus_effect_count(master_bus_index)
	AudioServer.add_bus_effect(master_bus_index, recorder)
	recorder.set_recording_active(true)
	return recorder.is_recording_active()

func _screenshot(id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(output_dir.path_join("game-audio-%s.png" % id))

func _mark(event: String, game_id: String) -> void:
	timeline.append({
		"event": event,
		"game": game_id,
		"seconds": float(Time.get_ticks_msec() - started_msec) / 1000.0,
		"context": main.audio._active_context if main != null and main.audio != null else "",
		"music": _active_music_path() if main != null and main.audio != null else "",
		"sfx": main.audio._sfx.stream.resource_path if main != null and main.audio != null and main.audio._sfx.stream != null else "",
	})

func _duration(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	push_error("Native game audio review: " + message)
	if recorder != null and master_bus_index >= 0 and recorder_index >= 0:
		recorder.set_recording_active(false)
		AudioServer.remove_bus_effect(master_bus_index, recorder_index)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
