extends SceneTree

const AudioDirector := preload("res://game/audio/audio_director.gd")

func _initialize() -> void:
	var audio := AudioDirector.new()
	root.add_child(audio)
	await process_frame
	for required_method in ["set_island_state", "set_dialogue_active", "is_dialogue_active"]:
		if not audio.has_method(required_method):
			push_error("AudioDirector is missing required dynamics API: %s" % required_method)
			quit(1)
			return
	audio.apply_settings({"master_volume": 1.0, "music_volume": 0.8, "sfx_volume": 0.9})
	audio.call("set_island_state", "harbor", "noon")
	audio.play_context("harbor")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	var music: AudioStreamPlayer = audio._music_players[audio._active_music]
	var noon_music := music.volume_linear
	var noon_waves := audio._ambience.volume_linear
	assert(noon_music > 0.0)
	assert(is_equal_approx(noon_waves, 0.8 * 0.35 * 0.72))

	# A phase transition changes music and surf together while night is quieter.
	audio.call("set_island_state", "harbor", "night")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(music.volume_linear, noon_music * 0.66))
	assert(audio._ambience.volume_linear < noon_waves)
	var night_music := music.volume_linear
	audio.play_context("game")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	var night_game_music: AudioStreamPlayer = audio._music_players[audio._active_music]
	assert(is_equal_approx(night_game_music.volume_linear, 0.8 * 0.66))
	audio.play_context("harbor")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	music = audio._music_players[audio._active_music]

	# Invalid phase falls back safely to noon without changing the selected track.
	audio.call("set_island_state", "harbor", "not-a-phase")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(music.volume_linear > night_music)
	assert(music.stream.resource_path == "res://assets/audio/cc0/harbor.ogg")

	# Dialogue duck is a single idempotent state transition, then restores.
	var before_dialogue := music.volume_linear
	audio.call("set_dialogue_active", true)
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(music.volume_linear, before_dialogue * 0.82))
	var ducked := music.volume_linear
	audio.call("set_dialogue_active", true)
	await create_timer(0.1).timeout
	assert(is_equal_approx(music.volume_linear, ducked))
	audio.call("set_dialogue_active", false)
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(music.volume_linear, before_dialogue))

	# A dialogue state change while paused resumes cleanly; mute stays absolute.
	audio.set_paused(true)
	audio.call("set_dialogue_active", true)
	await create_timer(0.1).timeout
	assert(is_equal_approx(music.volume_linear, before_dialogue))
	audio.set_paused(false)
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(music.volume_linear, before_dialogue * 0.82))
	audio.apply_settings({"master_volume": 0.0})
	assert(music.volume_linear == 0.0)
	audio.call("set_dialogue_active", false)
	audio.apply_settings({"master_volume": 1.0})
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(music.volume_linear, before_dialogue))

	# Returning from game uses the latest island state and its phase mix.
	audio.play_context("game")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	audio.call("set_island_state", "plaza", "dusk")
	audio.play_context("plaza")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(audio._active_context == "plaza")
	assert(music.stream.resource_path == "res://assets/audio/cc0/plaza.ogg")
	assert(is_equal_approx(music.volume_linear, 0.8 * 0.84))
	assert(audio._ambience.volume_linear < noon_waves)

	audio.shutdown()
	assert(not audio.call("is_dialogue_active"))
	assert(audio._active_context.is_empty())
	assert(audio._island_area.is_empty() and audio._time_phase.is_empty())
	await create_timer(0.15).timeout
	var player_count := audio._music_players.size()
	audio.request_ready()
	root.remove_child(audio)
	root.add_child(audio)
	await process_frame
	assert(audio._music_players.size() == player_count)
	audio.call("set_island_state", "harbor", "noon")
	audio.play_context("harbor")
	await create_timer(AudioDirector.FADE_SECONDS + 0.1).timeout
	assert(is_equal_approx(audio._ambience.volume_linear, 0.8 * 0.35 * 0.72))
	assert(audio._active_context == "harbor")
	audio.shutdown()
	await create_timer(0.15).timeout
	audio.free()
	await process_frame

	print("PASS: phase-aware island audio dynamics and dialogue duck")
	quit(0)
