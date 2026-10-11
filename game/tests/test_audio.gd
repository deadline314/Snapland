extends SceneTree

const AudioDirector = preload("res://game/audio/audio_director.gd")

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
	assert(plaza_player.stream is AudioStreamWAV)
	assert((plaza_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
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
	assert(game_player.stream.resource_path == "res://assets/audio/game.wav")
	audio.apply_settings({"master": 0.8, "music": 0.6, "sfx": 0.5})
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(game_player.volume_db, linear_to_db(0.8 * 0.6)))
	assert(is_equal_approx(plaza_player.volume_db, AudioDirector.SILENCE_DB))

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
	for note in range(4):
		audio.play_note(note)
		assert(audio._notes.stream.resource_path == "res://assets/audio/note_%d.wav" % note)
		assert(is_equal_approx(audio._notes.volume_db, linear_to_db(0.8 * 0.5)))
	audio.set_paused(true)
	assert(audio._notes.stream_paused)
	audio.set_paused(false)
	assert(not audio._notes.stream_paused)
	await create_timer(0.7).timeout

	if audio._ambience_tween and audio._ambience_tween.is_running():
		audio._ambience_tween.kill()
	if audio._fade_tween and audio._fade_tween.is_running():
		audio._fade_tween.kill()
	audio.free()
	await process_frame
	print("PASS: audio runtime checks")
	quit(0)
