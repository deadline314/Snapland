extends Node

const MUSIC_PATHS := {
	"plaza": "res://assets/audio/cc0/plaza.ogg",
	"game": "res://assets/audio/cc0/game.ogg",
	"harbor": "res://assets/audio/cc0/harbor.ogg",
}
const SFX_PATHS := {
	"ui_click": "res://assets/audio/ui_click.wav",
	"photo_shutter": "res://assets/audio/photo_shutter.wav",
	"quest_complete": "res://assets/audio/quest_complete.wav",
	"soft_error": "res://assets/audio/soft_error.wav",
	"game_hit": "res://assets/audio/cc0/game_hit.wav",
}
const SFX_ALIASES := {
	"ui_click": "ui_click",
	"interact": "ui_click",
	"tap": "ui_click",
	"photo_shutter": "photo_shutter",
	"shutter": "photo_shutter",
	"quest_complete": "quest_complete",
	"success": "quest_complete",
	"soft_error": "soft_error",
	"miss": "soft_error",
	"hit": "game_hit",
}
const AMBIENCE_PATH := "res://assets/audio/plaza_ambience.wav"
const FADE_SECONDS := 0.85
const ISLAND_MUSIC_PHASE_GAIN := {"dawn": 0.9, "noon": 1.0, "dusk": 0.84, "night": 0.66}
const ISLAND_WAVE_PHASE_GAIN := {"dawn": 0.62, "noon": 0.72, "dusk": 0.56, "night": 0.38}
const ISLAND_WAVE_AREA_GAIN := {"harbor": 1.0, "plaza": 0.36}
const DIALOGUE_MUSIC_GAIN := 0.82
const SFX_REPEAT_GATE_MSEC := 40
const SILENCE_DB := -INF
const DEFAULT_SETTINGS := {"master": 1.0, "music": 0.8, "sfx": 0.9}
const DIALOGUE_BEEP_SAMPLE_RATE := 22050
const DIALOGUE_BEEP_SECONDS := 0.024
const DIALOGUE_BEEP_PITCH_HZ := {"票票": 760.0, "小角": 910.0, "阿浪": 620.0, "主角": 700.0}
const DIALOGUE_BEEP_INTERVAL_MSEC := {"票票": 54, "小角": 42, "阿浪": 50, "主角": 48}
const DIALOGUE_PUNCTUATION := "，。！？；：、…—,.!?;:·"
const SETTING_KEYS := {
	"master": "master_volume",
	"music": "music_volume",
	"sfx": "sfx_volume",
}

var _music_players: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _notes: AudioStreamPlayer
var _note_streams: Array[AudioStreamWAV] = []
var _dialogue_beep_player: AudioStreamPlayer
var _dialogue_beep_streams: Dictionary = {}
var _last_dialogue_beep_msec := -100000
var _active_music := -1
var _active_context := ""
var _settings := DEFAULT_SETTINGS.duplicate(true)
var _fade_tween: Tween
var _fade_tween_paused := false
var _ambience_tween: Tween
var _ambience_tween_paused := false
var _music_gain := 1.0
var _music_player_gains: Array[float] = [0.0, 0.0]
var _ambience_gain := 0.0
var _music_scene_gain := 1.0
var _ambience_scene_gain := 1.0
var _island_area := ""
var _time_phase := ""
var _dialogue_active := false
var _paused := false
var _last_sfx_msec: Dictionary = {}
var _scene_tween: Tween
var _scene_tween_paused := false
## True while a minigame plays its own beat-locked track (see set_music_suppressed).
var _music_suppressed := false

func _ready() -> void:
	if _music_players.is_empty():
		for index in 2:
			var player := AudioStreamPlayer.new()
			player.name = "MusicPlayer%d" % index
			add_child(player)
			_music_players.append(player)
	if not is_instance_valid(_ambience):
		_ambience = AudioStreamPlayer.new()
		_ambience.name = "PlazaAmbience"
		add_child(_ambience)
	if not is_instance_valid(_sfx):
		_sfx = AudioStreamPlayer.new()
		_sfx.name = "SFXPlayer"
		_sfx.max_polyphony = 4
		add_child(_sfx)
	if not is_instance_valid(_notes):
		_notes = AudioStreamPlayer.new()
		_notes.max_polyphony = 4
		add_child(_notes)
	if not is_instance_valid(_dialogue_beep_player):
		_dialogue_beep_player = AudioStreamPlayer.new()
		_dialogue_beep_player.name = "DialogueBeepPlayer"
		_dialogue_beep_player.max_polyphony = 4
		add_child(_dialogue_beep_player)
	_dialogue_beep_streams.clear()
	for speaker: String in DIALOGUE_BEEP_PITCH_HZ:
		_dialogue_beep_streams[speaker] = _make_dialogue_beep(float(DIALOGUE_BEEP_PITCH_HZ[speaker]))
	_note_streams.clear()
	for index in range(4):
		var note_path := "res://assets/audio/note_%d.wav" % index
		var note_stream: AudioStreamWAV
		if ResourceLoader.exists(note_path):
			note_stream = load(note_path) as AudioStreamWAV
		if note_stream == null:
			push_warning("Unable to load note stream at %s" % note_path)
		_note_streams.append(note_stream)
	apply_settings(_settings)

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	if _fade_tween and _fade_tween.is_valid(): _fade_tween.kill()
	if _ambience_tween and _ambience_tween.is_valid(): _ambience_tween.kill()
	if _scene_tween and _scene_tween.is_valid(): _scene_tween.kill()
	for player in _music_players:
		player.stop()
		player.stream = null
	if _ambience:
		_ambience.stop()
		_ambience.stream = null
	if _sfx:
		_sfx.stop()
		_sfx.stream = null
	if _notes:
		_notes.stop()
		_notes.stream = null
	if _dialogue_beep_player:
		_dialogue_beep_player.stop()
		_dialogue_beep_player.stream = null
	_dialogue_beep_streams.clear()
	_note_streams.clear()
	_active_context = ""
	_active_music = -1
	_music_gain = 0.0
	_music_player_gains = [0.0, 0.0]
	_ambience_gain = 0.0
	_music_scene_gain = 1.0
	_ambience_scene_gain = 1.0
	_island_area = ""
	_time_phase = ""
	_dialogue_active = false
	_scene_tween_paused = false
	_last_sfx_msec.clear()
	_last_dialogue_beep_msec = -100000
	_paused = false

func play_context(name: String) -> void:
	if not MUSIC_PATHS.has(name):
		push_warning("Unknown audio context: %s" % name)
		return
	if name == _active_context and _active_music >= 0 and _music_players[_active_music].stream != null:
		return
	var music_path: String = MUSIC_PATHS[name]
	if not ResourceLoader.exists(music_path):
		push_warning("Unable to load music stream at %s" % music_path)
		return
	var loaded_music := load(music_path)
	if not loaded_music is AudioStreamOggVorbis:
		push_warning("Music stream is unavailable or not Ogg Vorbis at %s" % music_path)
		return
	var incoming_stream := loaded_music as AudioStreamOggVorbis
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween_paused = false
	var target := 0 if _active_music != 0 else 1
	if _active_music < 0:
		target = 0
	var source := _active_music
	var incoming := _music_players[target]
	incoming.stop()
	incoming.stream = incoming_stream
	incoming_stream.loop = true
	incoming.volume_db = SILENCE_DB
	_music_player_gains[target] = 0.0
	incoming.play()
	incoming.stream_paused = _paused
	_active_music = target
	_active_context = name
	_music_gain = 0.0
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_method(_set_music_player_gain.bind(target), 0.0, 1.0, FADE_SECONDS)
	if source >= 0:
		_fade_tween.tween_method(_set_music_player_gain.bind(source), _music_player_gains[source], 0.0, FADE_SECONDS)
		_fade_tween.chain().tween_callback(_stop_music_player.bind(source))
	if _paused:
		_fade_tween.pause()
		_fade_tween_paused = true
	_set_ambience_enabled(name == "plaza" or name == "harbor")

func set_island_state(area: String, phase: String) -> void:
	var safe_area := area if ISLAND_WAVE_AREA_GAIN.has(area) else "plaza"
	var safe_phase := phase if ISLAND_MUSIC_PHASE_GAIN.has(phase) else "noon"
	if safe_area != area:
		push_warning("Unknown audio area '%s'; using plaza mix" % area)
	if safe_phase != phase:
		push_warning("Unknown audio phase '%s'; using noon mix" % phase)
	if safe_area == _island_area and safe_phase == _time_phase:
		return
	_island_area = safe_area
	_time_phase = safe_phase
	_retarget_scene_gains()

func set_dialogue_active(active: bool) -> void:
	if _dialogue_active == active:
		return
	_dialogue_active = active
	_retarget_scene_gains()

## A minigame with its own beat-locked music (彩帶節拍) asks the shared track to
## fade out so two tempos never play at once; false restores the normal mix.
func set_music_suppressed(suppressed: bool) -> void:
	if _music_suppressed == suppressed:
		return
	_music_suppressed = suppressed
	_retarget_scene_gains()

func is_music_suppressed() -> bool:
	return _music_suppressed

func is_dialogue_active() -> bool:
	return _dialogue_active

func _retarget_scene_gains() -> void:
	if _scene_tween and _scene_tween.is_valid():
		_scene_tween.kill()
	_scene_tween_paused = false
	var music_target := float(ISLAND_MUSIC_PHASE_GAIN.get(_time_phase, 1.0)) * (DIALOGUE_MUSIC_GAIN if _dialogue_active else 1.0) * (0.0 if _music_suppressed else 1.0)
	var ambience_target := float(ISLAND_WAVE_PHASE_GAIN.get(_time_phase, 0.72)) * float(ISLAND_WAVE_AREA_GAIN.get(_island_area, 0.36))
	_scene_tween = create_tween().set_parallel(true)
	_scene_tween.tween_method(_set_music_scene_gain, _music_scene_gain, music_target, FADE_SECONDS)
	_scene_tween.tween_method(_set_ambience_scene_gain, _ambience_scene_gain, ambience_target, FADE_SECONDS)
	if _paused:
		_scene_tween.pause()
		_scene_tween_paused = true

func _set_music_scene_gain(value: float) -> void:
	_music_scene_gain = clampf(value, 0.0, 1.0)
	_set_active_music_volume()

func _set_ambience_scene_gain(value: float) -> void:
	_ambience_scene_gain = clampf(value, 0.0, 1.0)
	_set_ambience_volume()

func play_sfx(name: String) -> void:
	var asset_name: String = SFX_ALIASES.get(name, "")
	if asset_name.is_empty():
		push_warning("Unknown sound effect: %s" % name)
		return
	if _paused or _settings.master * _settings.sfx <= 0.000001:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx_msec.get(asset_name, -100000)) < SFX_REPEAT_GATE_MSEC:
		return
	var path: String = SFX_PATHS[asset_name]
	if not ResourceLoader.exists(path):
		push_warning("Unable to load sound effect at %s" % path)
		return
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		push_warning("Unable to load sound effect at %s" % path)
		return
	_last_sfx_msec[asset_name] = now
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_sfx.stream = stream
	_sfx.volume_db = _sfx_volume_db()
	_sfx.play()
	_sfx.stream_paused = _paused

func play_gameplay_feedback(name: String) -> void:
	play_sfx("hit" if name == "success" else name)

func apply_settings(settings: Dictionary) -> void:
	for name in ["master", "music", "sfx"]:
		var progress_key: String = SETTING_KEYS[name]
		if settings.has(progress_key):
			_settings[name] = clampf(float(settings[progress_key]), 0.0, 1.0)
		elif settings.has(name):
			# Keep the short names available for callers that used the initial API.
			_settings[name] = clampf(float(settings[name]), 0.0, 1.0)
	_set_active_music_volume()
	_set_ambience_volume()
	if _sfx:
		_sfx.volume_db = _sfx_volume_db()
	if _notes:
		_notes.volume_db = _sfx_volume_db()
	if _dialogue_beep_player:
		_dialogue_beep_player.volume_db = _sfx_volume_db() - 8.0

func play_note(note: int) -> void:
	if note < 0 or note >= _note_streams.size() or _note_streams[note] == null: return
	_notes.stream = _note_streams[note]
	_notes.volume_db = _sfx_volume_db()
	_notes.play()
	_notes.stream_paused = _paused

func play_dialogue_beep(speaker: String, character: String) -> bool:
	if not _dialogue_beep_streams.has(speaker) or not _is_dialogue_beep_glyph(character):
		return false
	if _settings.master * _settings.sfx <= 0.000001 or _paused:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_dialogue_beep_msec < int(DIALOGUE_BEEP_INTERVAL_MSEC[speaker]):
		return false
	_last_dialogue_beep_msec = now
	_dialogue_beep_player.stream = _dialogue_beep_streams[speaker]
	_dialogue_beep_player.volume_db = _sfx_volume_db() - 8.0
	_dialogue_beep_player.play()
	return true

static func _is_dialogue_beep_glyph(character: String) -> bool:
	return not character.strip_edges().is_empty() and not DIALOGUE_PUNCTUATION.contains(character)

func _make_dialogue_beep(frequency: float) -> AudioStreamWAV:
	var sample_count := int(DIALOGUE_BEEP_SAMPLE_RATE * DIALOGUE_BEEP_SECONDS)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in range(sample_count):
		var time_seconds := float(index) / DIALOGUE_BEEP_SAMPLE_RATE
		var fade := minf(1.0, minf(time_seconds / 0.003, (DIALOGUE_BEEP_SECONDS - time_seconds) / 0.006))
		var sample := int(round(sin(TAU * frequency * time_seconds) * clampf(fade, 0.0, 1.0) * 7200.0))
		samples.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = DIALOGUE_BEEP_SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	return stream

func set_paused(paused: bool) -> void:
	_paused = paused
	if _fade_tween and _fade_tween.is_valid():
		if paused:
			if _fade_tween.is_running():
				_fade_tween.pause()
				_fade_tween_paused = true
		elif _fade_tween_paused:
			_fade_tween.play()
			_fade_tween_paused = false
	else:
		_fade_tween_paused = false
	if _scene_tween and _scene_tween.is_valid():
		if paused:
			if _scene_tween.is_running():
				_scene_tween.pause()
				_scene_tween_paused = true
		elif _scene_tween_paused:
			_scene_tween.play()
			_scene_tween_paused = false
	else:
		_scene_tween_paused = false
	for player in _music_players:
		player.stream_paused = paused
	if _ambience:
		_ambience.stream_paused = paused
	if _ambience_tween and _ambience_tween.is_valid():
		if paused:
			if _ambience_tween.is_running():
				_ambience_tween.pause()
				_ambience_tween_paused = true
		elif _ambience_tween_paused:
			_ambience_tween.play()
			_ambience_tween_paused = false
	else:
		_ambience_tween_paused = false
	if _sfx:
		_sfx.stream_paused = paused
	if _notes:
		_notes.stream_paused = paused
	if _dialogue_beep_player:
		_dialogue_beep_player.stream_paused = paused

func _set_ambience_enabled(enabled: bool) -> void:
	if _ambience_tween and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween_paused = false
	if enabled:
		var was_playing := _ambience.playing
		if not _ambience.playing and _ambience.stream == null:
			if not ResourceLoader.exists(AMBIENCE_PATH):
				push_warning("Unable to load ambience stream at %s" % AMBIENCE_PATH)
				return
			var ambience_stream := load(AMBIENCE_PATH) as AudioStreamWAV
			if ambience_stream == null:
				push_warning("Unable to load ambience stream at %s" % AMBIENCE_PATH)
				return
			# Loop points are sample frames, including for compressed imports such as QOA.
			ambience_stream.loop_begin = 0
			ambience_stream.loop_end = roundi(ambience_stream.get_length() * ambience_stream.mix_rate)
			ambience_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_ambience.stream = ambience_stream
		if not _ambience.playing:
			_ambience.play()
		_ambience.stream_paused = _paused
		if not was_playing:
			_ambience_gain = 0.0
			_set_ambience_volume()
		_ambience_tween = create_tween()
		_ambience_tween.tween_method(_set_ambience_gain, _ambience_gain, 1.0, FADE_SECONDS)
		if _paused:
			_ambience_tween.pause()
			_ambience_tween_paused = true
	else:
		_ambience_tween = create_tween()
		_ambience_tween.tween_method(_set_ambience_gain, _ambience_gain, 0.0, FADE_SECONDS)
		_ambience_tween.tween_callback(_ambience.stop)
		if _paused:
			_ambience_tween.pause()
			_ambience_tween_paused = true

func _set_music_gain(value: float) -> void:
	_music_gain = clampf(value, 0.0, 1.0)
	if _active_music >= 0:
		_set_music_player_gain(_music_gain, _active_music)

func _set_music_player_gain(value: float, index: int) -> void:
	if index < 0 or index >= _music_players.size():
		return
	_music_player_gains[index] = clampf(value, 0.0, 1.0)
	if index == _active_music:
		_music_gain = _music_player_gains[index]
	_music_players[index].volume_db = _linear_to_db(_settings.master * _settings.music * _music_player_gains[index] * _music_scene_gain)

func _stop_music_player(index: int) -> void:
	if index >= 0 and index < _music_players.size():
		_music_players[index].stop()
		_music_player_gains[index] = 0.0

func _set_ambience_gain(value: float) -> void:
	_ambience_gain = clampf(value, 0.0, 1.0)
	_set_ambience_volume()

func _set_active_music_volume() -> void:
	for index in range(_music_players.size()):
		_music_players[index].volume_db = _linear_to_db(_settings.master * _settings.music * _music_player_gains[index] * _music_scene_gain)

func _set_ambience_volume() -> void:
	if _ambience:
		_ambience.volume_db = _linear_to_db(_settings.master * _settings.music * 0.35 * _ambience_gain * _ambience_scene_gain)

func _sfx_volume_db() -> float:
	return _linear_to_db(_settings.master * _settings.sfx)

func _linear_to_db(value: float) -> float:
	if value <= 0.000001:
		return SILENCE_DB
	return linear_to_db(value)
