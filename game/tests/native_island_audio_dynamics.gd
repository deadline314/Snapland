extends Node

const TestSaveGuard := preload("res://game/core/test_save_guard.gd")
const AUDIO_CATALOG_PATH := "res://assets/audio/cc0/catalog.json"
const REQUIRED_PHASE_SECONDS := 3.05
const SETTLE_SECONDS := 0.95
const MAX_CAPTURE_SECONDS := 25.0
const MAX_STARTUP_SECONDS := 12.0
const MUTE_EDGE_GUARD_USEC := 100000

var _main: Node
var _output_dir := ""
var _recorder: AudioEffectRecord
var _master_bus_index := -1
var _recorder_index := -1
var _audio_driver := ""
var _started_usec := 0
var _scenario_started_usec := 0
var _recording_started_usec := 0
var _failures: Array[String] = []
var _events: Array[Dictionary] = []
var _windows: Array[Dictionary] = []
var _screenshots: Array[String] = []
var _dialogue_beep_edges := 0
var _native_audio := false
var _capture_timing_valid := false
var _pcm_has_signal := false
var _phase_pcm_windows_verified := false
var _silence_verified := false
var _recording_path := ""
var _recording_duration := 0.0
var _recording_stopped_usec := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_preflight_fail("A GPU-backed display is required for the native Main PCM capture; headless is not evidence.")
		return
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	var save_error := TestSaveGuard.validate_save_path(save_path, OS.get_user_data_dir())
	if not save_error.is_empty():
		_preflight_fail(save_error)
		return
	if FileAccess.file_exists(save_path) or DirAccess.dir_exists_absolute(save_path):
		_preflight_fail("Refusing to reuse an existing isolated save path: %s" % save_path)
		return
	_output_dir = _read_output_argument()
	if _output_dir.is_empty() or not _output_dir.is_absolute_path() or _output_dir.contains("://"):
		_preflight_fail("Pass --audio-output followed by a new absolute filesystem directory.")
		return
	_output_dir = _output_dir.simplify_path()
	if DirAccess.dir_exists_absolute(_output_dir) or FileAccess.file_exists(_output_dir):
		_preflight_fail("Refusing to reuse an existing audio output path: %s" % _output_dir)
		return
	var output_error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if output_error != OK:
		_preflight_fail("Could not create the new audio output directory: %s" % error_string(output_error))
		return
	var progress := get_tree().root.get_node_or_null("Progress")
	if progress == null:
		_preflight_fail("Progress autoload is missing.")
		return
	progress.reset_progress()
	progress.settings["time_phase"] = "noon"
	progress.intro_seen = true
	if not progress.save_progress():
		_preflight_fail("Could not initialize the isolated test save profile.")
		return
	if not _start_recording():
		_preflight_fail("Could not attach an active AudioEffectRecord to the Master bus.")
		return
	_started_usec = Time.get_ticks_usec()
	_audio_driver = AudioServer.get_driver_name()
	_native_audio = _audio_driver.to_lower() != "dummy"
	Engine.max_fps = 60
	if not _native_audio:
		_fail("Godot selected the Dummy audio driver; any PCM result is inconclusive, not a pass.")

	var packed := load("res://game/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load the real Main scene.")
		_finish()
		return
	_main = packed.instantiate()
	get_tree().root.add_child(_main)
	await _frames(8)
	if not is_instance_valid(_main.audio) or not is_instance_valid(_main.world):
		_fail("Main did not become ready with its real World and AudioDirector.")
		_finish()
		return
	_scenario_started_usec = Time.get_ticks_usec()
	var startup_seconds: float = float(_scenario_started_usec - _recording_started_usec) / 1000000.0
	if startup_seconds > MAX_STARTUP_SECONDS:
		_fail("Main startup exceeded its separate %.1fs bound (%.3fs)." % [MAX_STARTUP_SECONDS, startup_seconds])
	_main.world.player.velocity = Vector3.ZERO
	_main.world.player.position.z = 13.0
	if not await _wait_for_area("海風碼頭", 90):
		_fail("Physical player relocation did not trigger Main's harbor area_changed route.")
	await _duration(SETTLE_SECONDS)
	await _phase_window("harbor_noon", "harbor", "noon", "harbor-noon")

	if await _select_phase("night"):
		await _duration(SETTLE_SECONDS)
		await _phase_window("harbor_night", "harbor", "night", "harbor-night")
	_main._close()
	_main.world.player.velocity = Vector3.ZERO
	_main.world.player.position.z = 0.0
	if not await _wait_for_area("中央廣場", 90):
		_fail("Physical player relocation did not trigger Main's plaza area_changed route.")
	await _duration(SETTLE_SECONDS)
	await _phase_window("plaza_night", "plaza", "night", "plaza-night")
	if await _select_phase("noon"):
		await _duration(SETTLE_SECONDS)
		await _phase_window("plaza_noon", "plaza", "noon", "")

	var dialogue_text := "你好，歡迎來到海風島。票票準備好了！"
	_main._start_dialogue([{"speaker": "票票", "text": dialogue_text}], Callable())
	await _capture_png("dialogue-open")
	var dialogue_started := _mark("main_dialogue_opened")
	var dialogue_started_at_usec := Time.get_ticks_usec()
	var dialogue_deadline := dialogue_started_at_usec + 1600000
	var observed_playing := false
	while Time.get_ticks_usec() < dialogue_deadline:
		await get_tree().process_frame
		var beep_playing: bool = bool(_main.audio._dialogue_beep_player.playing)
		if beep_playing and not observed_playing:
			_dialogue_beep_edges += 1
		observed_playing = beep_playing
	var dialogue_closed := Time.get_ticks_usec()
	_main._finish_dialogue()
	_mark("main_dialogue_closed")
	_windows.append({"id": "dialogue", "start_usec": dialogue_started, "end_usec": dialogue_closed, "observed_beep_play_edges": _dialogue_beep_edges})
	_check(not _main.audio.is_dialogue_active() and _main.modal_kind == "", "Main's real dialogue close restores the dialogue audio state")
	_check(_dialogue_beep_edges > 0, "Main's actual ticket text reveal starts generated dialogue beep playback")
	_check(_main.audio._dialogue_beep_player.stream is AudioStreamWAV and _main.audio._dialogue_beep_player.stream.data.size() > 0, "dialogue beep stream contains generated PCM")
	await _duration(SETTLE_SECONDS)

	var master_before_mute := float(Progress.settings.get("master_volume", 0.7))
	Progress.set_setting("master_volume", 0.0)
	await _duration(0.12)
	var muted_start := _mark("main_settings_master_muted")
	await _duration(1.05)
	var muted_end := _mark("main_settings_master_mute_window_end")
	_windows.append({"id": "master_mute", "start_usec": muted_start, "end_usec": muted_end})
	_check(is_zero_approx(float(_main.audio._settings.master)), "Main setting change applies absolute master mute")
	Progress.set_setting("master_volume", master_before_mute)
	await _duration(SETTLE_SECONDS)
	_mark("main_settings_master_restored")

	_main._show_pause()
	var pause_start := _mark("main_pause_opened")
	await _duration(0.4)
	var pause_end := _mark("main_pause_held")
	_windows.append({"id": "paused", "start_usec": pause_start, "end_usec": pause_end})
	_check(bool(_main.audio._paused) and _main.modal_kind == "pause", "Main pause menu pauses audio playback")
	_main._close()
	_mark("main_pause_resumed")
	_check(not bool(_main.audio._paused) and _main.modal_kind == "", "Main pause menu close resumes audio playback")
	await _duration(0.45)

	_mark("main_audio_shutdown")
	_main.audio.shutdown()
	_check(_main.audio._active_context.is_empty() and not _main.audio.is_dialogue_active(), "AudioDirector shutdown clears context and dialogue state")
	await _duration(0.2)
	_main.queue_free()
	await _frames(3)
	var elapsed_seconds: float = float(Time.get_ticks_usec() - _scenario_started_usec) / 1000000.0
	if elapsed_seconds > MAX_CAPTURE_SECONDS:
		_fail("Measured Main interaction scenario exceeded its %0.1fs bound (%.3fs)." % [MAX_CAPTURE_SECONDS, elapsed_seconds])
	_finish()


func _read_output_argument() -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--audio-output":
			return arguments[index + 1].strip_edges()
	return ""


func _start_recording() -> bool:
	_master_bus_index = AudioServer.get_bus_index("Master")
	if _master_bus_index < 0:
		return false
	_recorder = AudioEffectRecord.new()
	_recorder_index = AudioServer.get_bus_effect_count(_master_bus_index)
	AudioServer.add_bus_effect(_master_bus_index, _recorder)
	_recorder.set_recording_active(true)
	_recording_started_usec = Time.get_ticks_usec()
	return _recorder.is_recording_active()


func _select_phase(phase_id: String) -> bool:
	if _main.modal_kind != "time":
		_main._show_time_panel()
	await _frames(2)
	var button := _main.overlay.find_child("TimePhase_%s" % phase_id, true, false) as Button
	if button == null or button.disabled:
		_fail("The actual Main time picker has no enabled %s phase action." % phase_id)
		return false
	button.emit_signal("pressed")
	await _frames(2)
	_check(str(Progress.settings.get("time_phase", "")) == phase_id, "TimePanel button selects %s through Main" % phase_id)
	return true


func _phase_window(label: String, area: String, phase: String, screenshot: String) -> void:
	_check(_main.audio._island_area == area and _main.audio._time_phase == phase, "%s reports the expected Main area and phase" % label)
	_check(_main.audio._active_context == area, "%s uses the expected Main music context" % label)
	var expected_music_gain := 0.66 if phase == "night" else 1.0
	var expected_wave_gain := (0.38 if phase == "night" else 0.72) * (0.36 if area == "plaza" else 1.0)
	_check(is_equal_approx(float(_main.audio._music_scene_gain), expected_music_gain), "%s applies the expected phase music gain" % label)
	_check(is_equal_approx(float(_main.audio._ambience_scene_gain), expected_wave_gain), "%s applies the expected phase and area wave gain" % label)
	if screenshot != "":
		await _capture_png(screenshot)
	var start_usec := _mark(label + "_stable_start")
	await _duration(REQUIRED_PHASE_SECONDS)
	var end_usec := _mark(label + "_stable_end")
	_windows.append({"id": label, "start_usec": start_usec, "end_usec": end_usec, "required_seconds": REQUIRED_PHASE_SECONDS})


func _wait_for_area(expected: String, maximum_frames: int) -> bool:
	for _frame in range(maximum_frames):
		if _main.world.current_area == expected:
			return true
		await get_tree().process_frame
	return _main.world.current_area == expected


func _capture_png(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join("MIC-2-%s.png" % name)
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_fail("Could not save native UI evidence PNG %s." % name)
	else:
		_screenshots.append(path)


func _mark(name: String) -> int:
	var music_stream := ""
	var music_volume := 0.0
	var music_paused := false
	var ambience_stream := ""
	var ambience_volume := 0.0
	var beep_stream := ""
	var beep_playing := false
	if is_instance_valid(_main) and is_instance_valid(_main.audio):
		var audio: Node = _main.audio
		if audio._active_music >= 0 and audio._active_music < audio._music_players.size():
			var player: AudioStreamPlayer = audio._music_players[audio._active_music]
			if player.stream != null:
				music_stream = player.stream.resource_path
			music_volume = player.volume_linear
			music_paused = player.stream_paused
		if is_instance_valid(audio._ambience):
			if audio._ambience.stream != null:
				ambience_stream = audio._ambience.stream.resource_path
			ambience_volume = audio._ambience.volume_linear
		if is_instance_valid(audio._dialogue_beep_player):
			if audio._dialogue_beep_player.stream is Resource:
				beep_stream = "generated://dialogue_beep"
			beep_playing = bool(audio._dialogue_beep_player.playing)
	var event_usec := Time.get_ticks_usec()
	_events.append({
		"event": name,
		"seconds": float(event_usec - _started_usec) / 1000000.0,
		"active_context": _main.audio._active_context if is_instance_valid(_main) and is_instance_valid(_main.audio) else "",
		"active_music_path": music_stream,
		"music_player_gain": music_volume,
		"music_scene_gain": float(_main.audio._music_scene_gain) if is_instance_valid(_main) and is_instance_valid(_main.audio) else 0.0,
		"ambience_path": ambience_stream,
		"ambience_player_gain": ambience_volume,
		"ambience_scene_gain": float(_main.audio._ambience_scene_gain) if is_instance_valid(_main) and is_instance_valid(_main.audio) else 0.0,
		"area": str(_main.audio._island_area) if is_instance_valid(_main) and is_instance_valid(_main.audio) else "",
		"phase": str(_main.audio._time_phase) if is_instance_valid(_main) and is_instance_valid(_main.audio) else "",
		"dialogue_active": bool(_main.audio.is_dialogue_active()) if is_instance_valid(_main) and is_instance_valid(_main.audio) else false,
		"dialogue_beep_stream": beep_stream,
		"dialogue_beep_playing": beep_playing,
		"paused": bool(_main.audio._paused) if is_instance_valid(_main) and is_instance_valid(_main.audio) else false,
		"master_setting": float(_main.audio._settings.master) if is_instance_valid(_main) and is_instance_valid(_main.audio) else 0.0,
	})
	return event_usec


func _finish() -> void:
	var recording: AudioStreamWAV
	_recording_stopped_usec = Time.get_ticks_usec()
	if _recorder != null and _recorder.is_recording_active():
		_recorder.set_recording_active(false)
		recording = _recorder.get_recording()
	if recording == null or recording.data.is_empty():
		_fail("Master AudioEffectRecord returned no PCM samples.")
	else:
		_recording_path = _output_dir.path_join("MIC-2-main-master-mix.wav")
		if recording.save_to_wav(_recording_path) != OK:
			_fail("Could not save Master bus PCM capture.")
		else:
			_pcm_has_signal = _recording_has_signal(recording.data)
			var channel_count := 2 if recording.stereo else 1
			var pcm_frames := recording.data.size() / 2 / channel_count if recording.format == AudioStreamWAV.FORMAT_16_BITS else 0
			_recording_duration = float(pcm_frames) / float(maxi(1, recording.mix_rate))
			var wall_duration := float(_recording_stopped_usec - _recording_started_usec) / 1000000.0
			_capture_timing_valid = recording.format == AudioStreamWAV.FORMAT_16_BITS and absf(_recording_duration - wall_duration) <= maxf(0.75, wall_duration * 0.12)
			if not _pcm_has_signal:
				_fail("PCM capture contains no nonzero samples.")
			if not _capture_timing_valid:
				_fail("Recorded PCM duration does not align with native elapsed time; driver output cannot be treated as realtime evidence.")
			for window_index in range(_windows.size()):
				var window: Dictionary = _windows[window_index]
				var start_usec := int(window.start_usec)
				var end_usec := int(window.end_usec)
				var metric_start_usec: int = start_usec
				var metric_end_usec: int = end_usec
				if str(window.get("id", "")) == "master_mute":
					metric_start_usec += MUTE_EDGE_GUARD_USEC
					metric_end_usec -= MUTE_EDGE_GUARD_USEC
				var metrics := _pcm_window_metrics(recording, metric_start_usec, metric_end_usec, channel_count)
				window["pcm"] = metrics
				if str(window.get("id", "")) == "master_mute":
					window["pcm_verification_edge_guard_usec"] = MUTE_EDGE_GUARD_USEC
				_windows[window_index] = window
				if str(window.id) == "master_mute":
					_silence_verified = float(metrics.get("rms", 1.0)) <= 0.0001 and int(metrics.get("nonzero_samples", 1)) == 0
		var phase_signal := true
		var phase_window_count := 0
		for window in _windows:
			var window_id := str(window.get("id", ""))
			if window_id in ["harbor_noon", "harbor_night", "plaza_night", "plaza_noon"]:
				phase_window_count += 1
				var phase_metrics: Dictionary = window.get("pcm", {})
				if float(phase_metrics.get("rms", 0.0)) <= 0.0 or int(phase_metrics.get("sample_frames", 0)) <= 0:
					phase_signal = false
		_phase_pcm_windows_verified = phase_signal and phase_window_count == 4
		if not _silence_verified:
			_fail("The recorded master-mute interval was not digital silence at the stated threshold.")
		if not _phase_pcm_windows_verified:
			_fail("At least one island phase PCM interval is absent or silent.")
	var metadata := _cc0_catalog_evidence()
	var scenario_start_usec: int = _scenario_started_usec if _scenario_started_usec > 0 else _started_usec
	var total_seconds: float = float(Time.get_ticks_usec() - scenario_start_usec) / 1000000.0
	var startup_seconds: float = float(maxi(0, _scenario_started_usec - _recording_started_usec)) / 1000000.0
	var recording_wall_seconds: float = float(_recording_stopped_usec - _recording_started_usec) / 1000000.0
	var all_phases_verified := true
	for label in ["harbor_noon", "harbor_night", "plaza_night", "plaza_noon"]:
		var found := false
		for window in _windows:
			if str(window.get("id", "")) == label and float(window.get("required_seconds", 0.0)) >= 3.0:
				found = true
				break
		if not found:
			all_phases_verified = false
	var passed := _failures.is_empty() and _native_audio and _capture_timing_valid and _pcm_has_signal and _phase_pcm_windows_verified and _silence_verified and _dialogue_beep_edges > 0 and all_phases_verified and total_seconds <= MAX_CAPTURE_SECONDS
	var result := "PASS" if passed else ("INCONCLUSIVE" if not _native_audio or not _capture_timing_valid else "FAIL")
	var report := {
		"fixture": "MIC-2 Main-backed phase-aware island audio dynamics",
		"result": result,
		"human_listened": false,
		"audition_claim": false,
		"audio_driver": _audio_driver,
		"native_audio_driver": _native_audio,
		"native_master_pcm_capture": _recording_path,
		"pcm_format": "16-bit PCM" if recording != null and recording.format == AudioStreamWAV.FORMAT_16_BITS else "unsupported or unavailable",
		"pcm_mix_rate_hz": recording.mix_rate if recording != null else 0,
		"pcm_stereo": recording.stereo if recording != null else false,
		"pcm_bytes": recording.data.size() if recording != null else 0,
		"pcm_duration_seconds": _recording_duration,
		"wall_duration_seconds": recording_wall_seconds,
		"scenario_duration_seconds": total_seconds,
		"startup_seconds_excluded_from_scenario_bound": startup_seconds,
		"recording_wall_duration_seconds": recording_wall_seconds,
		"realtime_render_fps_cap": 60,
		"fixed_fps_mode": false,
		"capture_timing_valid": _capture_timing_valid,
		"pcm_has_nonzero_signal": _pcm_has_signal,
		"phase_pcm_windows_have_signal": _phase_pcm_windows_verified,
		"master_mute_digital_silence_verified": _silence_verified,
		"dialogue_beep_play_edges_during_real_main_text_reveal": _dialogue_beep_edges,
		"event_mix_state": _events,
		"pcm_windows": _windows,
		"cc0_active_asset_catalog_evidence": metadata,
		"evidence_screenshots": _screenshots,
		"failures": _failures,
		"limits": ["Scripted Main interactions; not a human playtest.", "Master-bus RMS is the combined game mix and does not isolate music from waves.", "Audio output measurements do not establish subjective sound quality; local audition remains pending."],
	}
	var report_path := _output_dir.path_join("MIC-2-audio-dynamics-report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write native audio report JSON.")
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	if _master_bus_index >= 0 and _recorder_index >= 0:
		AudioServer.remove_bus_effect(_master_bus_index, _recorder_index)
	_recorder = null
	if is_instance_valid(_main):
		_main.queue_free()
	if not _failures.is_empty() and result == "PASS":
		result = "FAIL"
	if result == "PASS":
		print("PASS: Main-backed MIC-2 native Master PCM dynamics capture; human audition pending: " + report_path)
	elif result == "INCONCLUSIVE":
		push_warning("INCONCLUSIVE: native output capture timing/driver was not verified: " + report_path)
		get_tree().quit(2)
		return
	else:
		push_error("FAIL: Main-backed MIC-2 native audio capture; see " + report_path)
	get_tree().quit(0 if result == "PASS" else 1)


func _pcm_window_metrics(recording: AudioStreamWAV, start_usec: int, end_usec: int, channels: int) -> Dictionary:
	if recording.format != AudioStreamWAV.FORMAT_16_BITS or recording.mix_rate <= 0 or end_usec <= start_usec:
		return {"rms": -1.0, "nonzero_samples": -1, "sample_frames": 0}
	var data: PackedByteArray = recording.data
	var start_seconds := maxf(0.0, float(start_usec - _recording_started_usec) / 1000000.0)
	var end_seconds := maxf(start_seconds, float(end_usec - _recording_started_usec) / 1000000.0)
	var start_frame: int = clampi(roundi(start_seconds * float(recording.mix_rate)), 0, data.size() / 2 / channels)
	var end_frame: int = clampi(roundi(end_seconds * float(recording.mix_rate)), start_frame, data.size() / 2 / channels)
	var sum_squares := 0.0
	var sample_count := 0
	var nonzero_count := 0
	for frame in range(start_frame, end_frame):
		for channel in range(channels):
			var sample := data.decode_s16((frame * channels + channel) * 2)
			if sample != 0:
				nonzero_count += 1
			sum_squares += pow(float(sample) / 32768.0, 2.0)
			sample_count += 1
	return {"rms": sqrt(sum_squares / float(sample_count)) if sample_count > 0 else -1.0, "nonzero_samples": nonzero_count, "sample_frames": end_frame - start_frame}


func _recording_has_signal(data: PackedByteArray) -> bool:
	for value in data:
		if value != 0:
			return true
	return false


func _cc0_catalog_evidence() -> Array[Dictionary]:
	if not FileAccess.file_exists(AUDIO_CATALOG_PATH):
		_fail("CC0 audio catalog is missing; cannot annotate audio provenance.")
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_CATALOG_PATH))
	if not parsed is Dictionary:
		_fail("CC0 audio catalog is malformed.")
		return []
	var catalog: Dictionary = parsed
	var source_lookup: Dictionary = {}
	var sources: Variant = catalog.get("sources", [])
	if sources is Array:
		for source_value in sources:
			if source_value is Dictionary:
				source_lookup[str(source_value.get("id", ""))] = source_value
	var result: Array[Dictionary] = []
	var assets: Variant = catalog.get("assets", [])
	if assets is Array:
		for asset_value in assets:
			if not asset_value is Dictionary or str(asset_value.get("id", "")) not in ["harbor", "plaza", "ambience"]:
				continue
			var asset: Dictionary = asset_value
			var source_id := str(asset.get("source_id", ""))
			result.append({
				"asset_id": asset.get("id", ""),
				"asset_path": asset.get("path", ""),
				"asset_sha256": asset.get("sha256", ""),
				"source_id": source_id,
				"source": source_lookup.get(source_id, {}),
				"selection_reason": asset.get("selection_reason", ""),
				"audition": asset.get("audition", "not recorded"),
			})
	var catalog_sources: Variant = catalog.get("sources", [])
	if catalog_sources is Array:
		for source_value in catalog_sources:
			if source_value is Dictionary and str(source_value.get("id", "")) == "snapland-generated":
				result.append({"procedural_source": source_value, "used_for": "dialogue speaker beep generated by audio_director.gd"})
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("MIC-2 native audio fixture: " + message)


func _preflight_fail(message: String) -> void:
	push_error("MIC-2 native audio fixture preflight: " + message)
	get_tree().quit(1)


func _duration(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
