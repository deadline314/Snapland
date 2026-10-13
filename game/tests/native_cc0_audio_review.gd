extends Node

const MAIN_SCENE_PATH := "res://game/main.tscn"
const TestSaveGuard := preload("res://game/core/test_save_guard.gd")
const SilenceDb := -INF
const CAPTURE_SECONDS := 8.0

var main: Node
var output_dir := ""
var recorder: AudioEffectRecord
var master_bus_index := -1
var recorder_index := -1
var started_msec := 0
var timeline: Array[Dictionary] = []
var status_label: Label
var master_volume_before_mute := 1.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	var save_error := TestSaveGuard.validate_save_path(save_path, OS.get_user_data_dir())
	if not save_error.is_empty():
		await _fail(save_error)
		return
	if DisplayServer.get_name() == "headless":
		await _fail("Native audio render requires a display device; no gameplay or audition is performed")
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-review-output="):
			output_dir = argument.trim_prefix("--audio-review-output=").strip_edges()
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		await _fail("Pass --audio-review-output=<absolute directory>")
		return
	var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(output_dir):
		await _fail("Cannot create audio review output directory: %s" % output_dir)
		return
	var progress := get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Progress autoload is missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		await _fail("Could not load %s" % MAIN_SCENE_PATH)
		return
	main = packed.instantiate()
	get_tree().root.add_child(main)
	await _wait_frames(8)
	if main.audio == null or main.world == null:
		await _fail("Main did not become ready with World and Audio")
		return
	_add_status_label()
	if not _start_recording():
		await _fail("AudioServer recording effect could not start")
		return
	started_msec = Time.get_ticks_msec()
	_mark("main_ready_harbor")
	if not await _capture("harbor"):
		return
	await _duration(CAPTURE_SECONDS)
	main.audio.play_context("plaza")
	_mark("music_context_plaza")
	await _duration(0.9)
	if not await _capture("plaza"):
		return
	await _duration(CAPTURE_SECONDS - 0.9)
	main.audio.play_context("game")
	_mark("music_context_game")
	await _duration(0.9)
	if not await _capture("game"):
		return
	await _duration(CAPTURE_SECONDS - 0.9)
	main.audio.play_sfx("interact")
	_mark("sfx_interact")
	await _duration(0.3)
	main.audio.play_gameplay_feedback("success")
	_mark("gameplay_success_short_hit")
	await _duration(0.4)
	main.audio.play_sfx("miss")
	_mark("sfx_miss")
	await _duration(0.5)
	main.audio.play_sfx("shutter")
	_mark("sfx_shutter")
	await _duration(0.4)
	main.audio.play_sfx("quest_complete")
	_mark("sfx_quest_complete_full")
	await _duration(4.0)
	main.audio.play_dialogue_beep("票票", "歡")
	_mark("dialogue_beep")
	await _duration(0.8)
	master_volume_before_mute = float(main.audio._settings.master)
	main.audio.apply_settings({"master_volume": 0.0})
	_mark("master_mute_begin")
	if not _assert_muted():
		await _fail("Master mute did not set music and SFX players to silence")
		return
	if not await _capture("mute"):
		return
	await _duration(2.0)
	main.audio.apply_settings({"master_volume": master_volume_before_mute})
	_mark("master_mute_end")
	await _duration(0.3)
	if not await _finish_capture():
		return
	print("PASS: CC0 audio native render and mixed capture; audition pending")
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	main = null
	await _wait_frames(4)
	get_tree().quit(0)

func _start_recording() -> bool:
	master_bus_index = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return false
	recorder = AudioEffectRecord.new()
	recorder_index = AudioServer.get_bus_effect_count(master_bus_index)
	AudioServer.add_bus_effect(master_bus_index, recorder)
	recorder.set_recording_active(true)
	return recorder.is_recording_active()

func _finish_capture() -> bool:
	if recorder == null or not recorder.is_recording_active():
		await _fail("Master recording stopped before capture completed")
		return false
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	if recording == null or recording.data.is_empty() or recording.data.size() <= 50000 or not _recording_has_signal(recording.data):
		await _fail("Mixed audio recording is empty, unexpectedly small, or contains no nonzero PCM samples")
		return false
	var wav_path := output_dir.path_join("MIC-3-native-mix.wav")
	if recording.save_to_wav(wav_path) != OK:
		await _fail("Could not save mixed audio WAV")
		return false
	var report := {
		"method": "Audio-only technical test in the same native Main scene: direct audio context changes and scripted SFX calls; no traversal through three park areas or gameplay; native Master mix capture, audition pending",
		"duration_seconds": float(Time.get_ticks_msec() - started_msec) / 1000.0,
		"capture_bytes": recording.data.size(),
		"recording": wav_path,
		"events": timeline,
		"audition": "pending",
	}
	var file := FileAccess.open(output_dir.path_join("MIC-3-native-timeline.json"), FileAccess.WRITE)
	if file == null:
		await _fail("Could not write audio timeline JSON")
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if master_bus_index >= 0 and recorder_index >= 0:
		AudioServer.remove_bus_effect(master_bus_index, recorder_index)
		recorder = null
	return true

func _assert_muted() -> bool:
	for player: AudioStreamPlayer in [main.audio._sfx, main.audio._notes, main.audio._dialogue_beep_player, main.audio._ambience]:
		if player.volume_linear != 0.0:
			return false
	for player: AudioStreamPlayer in main.audio._music_players:
		if player.volume_linear != 0.0:
			return false
	return true

func _recording_has_signal(data: PackedByteArray) -> bool:
	for sample_byte in data:
		if sample_byte != 0:
			return true
	return false

func _capture(name: String) -> bool:
	status_label.text = "AUDIO FIXTURE  •  " + name
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output_dir.path_join("MIC-3-%s.png" % name)
	if image == null or image.save_png(path) != OK:
		await _fail("Could not save viewport evidence for %s" % name)
		return false
	_mark("screenshot_" + name)
	return true

func _mark(name: String) -> void:
	var active_path := ""
	var volume_db := SilenceDb
	var volume_linear := 0.0
	var paused := false
	if main != null and main.audio != null:
		var audio: Node = main.audio
		if audio._active_music >= 0 and audio._active_music < audio._music_players.size():
			var player: AudioStreamPlayer = audio._music_players[audio._active_music]
			if player.stream != null:
				active_path = player.stream.resource_path
			volume_db = player.volume_db
			volume_linear = player.volume_linear
			paused = player.stream_paused
	timeline.append({
			"event": name,
			"seconds": float(Time.get_ticks_msec() - started_msec) / 1000.0,
			"active_context": main.audio._active_context if main != null and main.audio != null else "",
			"active_stream_path": active_path,
			"volume_db": str(volume_db) if is_inf(volume_db) else volume_db,
			"volume_linear": volume_linear,
			"paused": paused,
		})

func _add_status_label() -> void:
	status_label = Label.new()
	status_label.name = "AudioReviewFixtureStatus"
	status_label.position = Vector2(18, 612)
	status_label.text = "AUDIO FIXTURE  •  audition pending"
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 1)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(status_label)

func _duration(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	push_error("Native CC0 audio review: " + message)
	if recorder != null:
		recorder.set_recording_active(false)
		if master_bus_index >= 0 and recorder_index >= 0:
			AudioServer.remove_bus_effect(master_bus_index, recorder_index)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
