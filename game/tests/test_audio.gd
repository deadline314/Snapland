extends SceneTree

const AudioDirector = preload("res://game/audio/audio_director.gd")
const NativeAudioReview = preload("res://game/tests/native_cc0_audio_review.gd")

func _initialize() -> void:
	var audio := AudioDirector.new()
	root.add_child(audio)
	await process_frame

	audio.apply_settings(Progress.DEFAULT_SETTINGS)
	assert(is_equal_approx(audio._settings.master, Progress.DEFAULT_SETTINGS.master_volume))
	assert(is_equal_approx(audio._settings.music, Progress.DEFAULT_SETTINGS.music_volume))
	assert(is_equal_approx(audio._settings.sfx, Progress.DEFAULT_SETTINGS.sfx_volume))
	audio.play_context("plaza")
	var plaza_player: AudioStreamPlayer = audio._music_players[audio._active_music]
	assert(plaza_player.stream is AudioStreamOggVorbis)
	assert((plaza_player.stream as AudioStreamOggVorbis).loop)
	assert(plaza_player.stream.resource_path == "res://assets/audio/cc0/plaza.ogg")
	await create_timer(0.2).timeout
	audio.apply_settings({"master_volume": 0.4, "music_volume": 0.5, "sfx_volume": 0.25})
	assert(is_equal_approx(audio._settings.master, 0.4))
	assert(is_equal_approx(audio._music_players[audio._active_music].volume_db, linear_to_db(0.4 * 0.5 * audio._music_gain)))
	assert(is_equal_approx(audio._sfx.volume_db, linear_to_db(0.4 * 0.25)))
	assert(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	assert(is_equal_approx(audio._settings.music, 0.5))
	assert(is_equal_approx(audio._settings.sfx, 0.25))
	assert(is_equal_approx(plaza_player.volume_db, linear_to_db(0.4 * 0.5 * audio._music_gain)))
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(audio._music_gain, 1.0))
	assert(is_equal_approx(plaza_player.volume_db, linear_to_db(0.2)))

	audio.play_context("game")
	var game_player: AudioStreamPlayer = audio._music_players[audio._active_music]
	assert(audio._active_context == "game")
	assert(game_player.stream is AudioStreamOggVorbis)
	assert((game_player.stream as AudioStreamOggVorbis).loop)
	assert(game_player.stream.resource_path == "res://assets/audio/cc0/game.ogg")
	audio.apply_settings({"master": 0.8, "music": 0.6, "sfx": 0.5})
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(game_player.volume_db, linear_to_db(0.8 * 0.6)))
	assert(plaza_player.volume_db == AudioDirector.SILENCE_DB)

	# Rapid context changes should reuse the two players without leaving the old fade active.
	audio.play_context("harbor")
	var harbor_player: AudioStreamPlayer = audio._music_players[audio._active_music]
	assert(harbor_player.stream.resource_path == "res://assets/audio/cc0/harbor.ogg")
	assert(audio._ambience.playing)
	await create_timer(0.1).timeout
	audio.play_context("plaza")
	var fast_plaza_player: AudioStreamPlayer = audio._music_players[audio._active_music]
	assert(fast_plaza_player.stream.resource_path == "res://assets/audio/cc0/plaza.ogg")
	audio.apply_settings({"master": 0.0, "music": 1.0, "sfx": 1.0})
	for player: AudioStreamPlayer in [audio._sfx, audio._notes, audio._dialogue_beep_player, audio._ambience]:
		assert(player.volume_linear == 0.0)
	for player: AudioStreamPlayer in audio._music_players:
		assert(player.volume_db == AudioDirector.SILENCE_DB)
		assert(player.volume_linear == 0.0)
	await create_timer(0.1).timeout
	for player: AudioStreamPlayer in audio._music_players:
		assert(player.volume_db == AudioDirector.SILENCE_DB)
		assert(player.volume_linear == 0.0)
	audio.apply_settings({"master": 0.8, "music": 0.6, "sfx": 0.5})

	# Pausing freezes the music fade so it cannot finish silently and resume at full volume.
	audio.set_paused(true)
	var gain_before_pause := audio._music_gain
	await create_timer(0.1).timeout
	assert(is_equal_approx(audio._music_gain, gain_before_pause))
	audio.set_paused(false)
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(audio._music_gain, 1.0))

	# Switching contexts while a fade is paused kills its tween and resumes the replacement.
	audio.play_context("game")
	await create_timer(0.1).timeout
	audio.set_paused(true)
	var paused_fade: Tween = audio._fade_tween
	audio.play_context("harbor")
	assert(not paused_fade.is_valid())
	audio.set_paused(false)
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(audio._active_context == "harbor")
	assert(is_equal_approx(audio._music_gain, 1.0))
	assert(is_equal_approx(audio._music_players[audio._active_music].volume_db, linear_to_db(0.8 * 0.6)))
	assert(audio._ambience.playing)

	# Observe uninterrupted playback for longer than a complete ambience cycle.
	var ambience_stream := audio._ambience.stream as AudioStreamWAV
	assert(ambience_stream != null)
	assert(ambience_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(ambience_stream.loop_begin == 0)
	assert(ambience_stream.loop_end == roundi(ambience_stream.get_length() * ambience_stream.mix_rate))
	assert(ambience_stream.loop_end > 0)
	var cycle_seconds := ambience_stream.get_length()
	assert(cycle_seconds > 0.0 and cycle_seconds < 30.0)
	var loop_check_started := Time.get_ticks_msec()
	var loop_check_msec := ceili((cycle_seconds + 0.3) * 1000.0)
	while Time.get_ticks_msec() - loop_check_started <= loop_check_msec:
		await create_timer(0.1).timeout
		assert(audio._ambience.playing)
	print("PASS: ambience remained playing beyond full cycle: %.3fs, %d frames, format %d" % [cycle_seconds, ambience_stream.loop_end, ambience_stream.format])

	audio.set_paused(true)
	assert(audio._paused)
	audio.set_paused(false)
	assert(not audio._paused)

	audio.play_sfx("interact")
	assert(audio._sfx.stream.resource_path == "res://assets/audio/ui_click.wav")
	audio.play_sfx("success")
	assert(audio._sfx.stream.resource_path == "res://assets/audio/quest_complete.wav")
	audio.play_sfx("miss")
	assert(audio._sfx.stream.resource_path == "res://assets/audio/soft_error.wav")
	audio.play_sfx("shutter")
	assert(audio._sfx.stream.resource_path == "res://assets/audio/photo_shutter.wav")
	assert(is_equal_approx(audio._sfx.volume_db, linear_to_db(0.8 * 0.5)))
	var ui_click_time := int(audio._last_sfx_msec["ui_click"])
	var current_sfx_stream: AudioStream = audio._sfx.stream
	audio.play_sfx("ui_click")
	assert(audio._sfx.stream == current_sfx_stream)
	assert(int(audio._last_sfx_msec["ui_click"]) == ui_click_time)
	await create_timer(float(AudioDirector.SFX_REPEAT_GATE_MSEC + 10) / 1000.0).timeout
	audio.play_sfx("interact")
	assert(int(audio._last_sfx_msec["ui_click"]) > ui_click_time)
	audio.play_gameplay_feedback("success")
	assert(audio._sfx.stream.resource_path == "res://assets/audio/cc0/game_hit.wav")
	var last_sfx_stream: AudioStream = audio._sfx.stream
	audio.apply_settings({"master": 0.0, "sfx": 1.0})
	audio.play_sfx("ui_click")
	assert(audio._sfx.stream == last_sfx_stream)
	audio.apply_settings({"master": 0.8, "sfx": 0.5})
	audio.set_paused(true)
	audio.play_sfx("ui_click")
	assert(audio._sfx.stream == last_sfx_stream)
	audio.set_paused(false)
	for note in range(4):
		audio.play_note(note)
		assert(audio._notes.stream.resource_path == "res://assets/audio/note_%d.wav" % note)
		assert(is_equal_approx(audio._notes.volume_db, linear_to_db(0.8 * 0.5)))
	audio.set_paused(true)
	assert(audio._notes.stream_paused)
	audio.set_paused(false)
	assert(not audio._notes.stream_paused)
	await create_timer(0.7).timeout

	audio.shutdown()
	for player: AudioStreamPlayer in audio._music_players:
		assert(player.stream == null)
	assert(audio._ambience.stream == null)
	assert(audio._sfx.stream == null)
	assert(audio._notes.stream == null)
	assert(audio._dialogue_beep_player.stream == null)
	assert(audio._active_context.is_empty())
	assert(audio._active_music == -1)
	assert(is_zero_approx(audio._music_gain))
	assert(audio._last_sfx_msec.is_empty())
	await create_timer(0.15).timeout
	audio.free()
	await process_frame
	var native_review := NativeAudioReview.new()
	native_review._mark("mute_json_test")
	assert(native_review.timeline[0].volume_db == "-inf")
	assert(native_review.timeline[0].volume_linear == 0.0)
	var parsed_timeline: Variant = JSON.parse_string(JSON.stringify(native_review.timeline))
	assert(parsed_timeline is Array)
	assert(parsed_timeline[0].volume_db == "-inf")
	assert(parsed_timeline[0].volume_linear == 0.0)
	native_review.free()
	print("PASS: audio runtime checks")
	quit(0)
