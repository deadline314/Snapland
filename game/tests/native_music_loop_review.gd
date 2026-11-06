extends Node
## MIC-1 native evidence: records the Master mix while the shared game track loops past its
## end and while a context switch crossfades, then saves the PCM and the expected loop time
## for tools/analyze_loop_capture.py. A technical capture only, never an audition.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const TestSaveGuard := preload("res://game/core/test_save_guard.gd")
const AudioDirector := preload("res://game/audio/audio_director.gd")
const PAST_LOOP_SECONDS := 4.0
const SWITCH_HOLD_SECONDS := 3.0

var main: Node
var output_dir := ""
var recorder: AudioEffectRecord
var bus := -1
var effect_index := -1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_error := TestSaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges(), OS.get_user_data_dir())
	if not save_error.is_empty():
		await _fail(save_error)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--loop-review-output="):
			output_dir = argument.trim_prefix("--loop-review-output=").strip_edges()
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		await _fail("Pass --loop-review-output=<absolute directory>")
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
	for _i in 8: await get_tree().process_frame
	bus = AudioServer.get_bus_index("Master")
	recorder = AudioEffectRecord.new()
	effect_index = AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	var started := Time.get_ticks_usec()
	main.audio.play_context("game")
	var player: AudioStreamPlayer = main.audio._music_players[main.audio._active_music]
	var length := player.stream.get_length() if player.stream != null else 0.0
	if length <= 0.0 or not (player.stream as AudioStreamOggVorbis).loop:
		await _fail("Shared game track is missing or not looping")
		return
	var context_started := float(Time.get_ticks_usec() - started) / 1000000.0
	# Watch the real playback position: it jumps back to the start exactly when the loop wraps.
	var wrapped := false
	var wrap_seconds := -1.0
	var last_position := player.get_playback_position()
	var deadline := Time.get_ticks_usec() + int((length + PAST_LOOP_SECONDS) * 3.0 * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
		var position := player.get_playback_position()
		if not wrapped and position + 1.0 < last_position:
			wrapped = true
			wrap_seconds = float(Time.get_ticks_usec() - started) / 1000000.0
		last_position = position
		if wrapped and position >= PAST_LOOP_SECONDS:
			break
	var switch_at := float(Time.get_ticks_usec() - started) / 1000000.0
	main.audio.play_context("plaza")
	await get_tree().create_timer(SWITCH_HOLD_SECONDS).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	AudioServer.remove_bus_effect(bus, effect_index)
	effect_index = -1
	if recording == null or recording.data.size() < 100000:
		await _fail("Master recording is empty")
		return
	recording.save_to_wav(output_dir.path_join("music-loop-mix.wav"))
	var report := {
		"method": "Main AudioDirector context 'game' left playing past one full loop, then switched to 'plaza'; Master bus AudioEffectRecord; no gameplay, no audition",
		"audio_driver": AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "",
		"track": player.stream.resource_path, "track_seconds": length,
		"context_started_seconds": context_started, "expected_loop_seconds": context_started + length,
		"switch_seconds": switch_at, "crossfade_seconds": AudioDirector.FADE_SECONDS,
		"playback_wrapped": wrapped, "observed_wrap_seconds": wrap_seconds, "wall_seconds": float(Time.get_ticks_usec() - started) / 1000000.0,
	}
	var file := FileAccess.open(output_dir.path_join("music-loop-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	main.audio.shutdown()
	main.queue_free()
	for _i in 4: await get_tree().process_frame
	if not wrapped:
		push_error("Shared game track did not wrap during the capture")
		get_tree().quit(1)
		return
	print("PASS: shared game track looped past its end and switched context during capture; audition pending")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("Native music loop review: " + message)
	if recorder != null and bus >= 0 and effect_index >= 0:
		recorder.set_recording_active(false)
		AudioServer.remove_bus_effect(bus, effect_index)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1)
