extends Node

const MUSIC_PATHS := {
	"plaza": "res://assets/audio/plaza.wav",
	"game": "res://assets/audio/game.wav",
	"harbor": "res://assets/audio/harbor.wav",
}
const SFX_PATHS := {
	"ui_click": "res://assets/audio/ui_click.wav",
	"photo_shutter": "res://assets/audio/photo_shutter.wav",
	"quest_complete": "res://assets/audio/quest_complete.wav",
	"soft_error": "res://assets/audio/soft_error.wav",
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
}
const AMBIENCE_PATH := "res://assets/audio/plaza_ambience.wav"
const FADE_SECONDS := 0.85
const SILENCE_DB := -60.0
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
var _ambience_tween: Tween
var _music_gain := 1.0
var _ambience_gain := 0.0
var _paused := false

func _ready() -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % index
		add_child(player)
		_music_players.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "PlazaAmbience"
	add_child(_ambience)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SFXPlayer"
	_sfx.max_polyphony = 4
	add_child(_sfx)
	_notes = AudioStreamPlayer.new()
	_notes.max_polyphony = 4
	add_child(_notes)
	_dialogue_beep_player = AudioStreamPlayer.new()
	_dialogue_beep_player.name = "DialogueBeepPlayer"
	_dialogue_beep_player.max_polyphony = 4
	add_child(_dialogue_beep_player)
	for speaker: String in DIALOGUE_BEEP_PITCH_HZ:
		_dialogue_beep_streams[speaker] = _make_dialogue_beep(float(DIALOGUE_BEEP_PITCH_HZ[speaker]))
	for index in range(4):
		_note_streams.append(load("res://assets/audio/note_%d.wav" % index) as AudioStreamWAV)
	apply_settings(_settings)

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	if _fade_tween and _fade_tween.is_running(): _fade_tween.kill()
	if _ambience_tween and _ambience_tween.is_running(): _ambience_tween.kill()
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

func play_context(name: String) -> void:
	if not MUSIC_PATHS.has(name):
		push_warning("Unknown audio context: %s" % name)
		return
	if name == _active_context and _active_music >= 0 and _music_players[_active_music].stream != null:
		return
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	var target := 0 if _active_music != 0 else 1
	if _active_music < 0:
		target = 0
	var source := _active_music
	var incoming := _music_players[target]
	incoming.stop()
	incoming.stream = load(MUSIC_PATHS[name]) as AudioStreamWAV
	if incoming.stream is AudioStreamWAV:
		(incoming.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	incoming.volume_db = SILENCE_DB
	incoming.play()
	incoming.stream_paused = _paused
	_active_music = target
	_active_context = name
	_music_gain = 0.0
	_set_active_music_volume()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_method(_set_music_gain, 0.0, 1.0, FADE_SECONDS)
	if source >= 0:
		var outgoing := _music_players[source]
		_fade_tween.tween_property(outgoing, "volume_db", SILENCE_DB, FADE_SECONDS)
		_fade_tween.chain().tween_callback(outgoing.stop)
	_set_ambience_enabled(name == "plaza")

func play_sfx(name: String) -> void:
	var asset_name: String = SFX_ALIASES.get(name, "")
	if asset_name.is_empty():
		push_warning("Unknown sound effect: %s" % name)
		return
	var stream := load(SFX_PATHS[asset_name]) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_sfx.stream = stream
	_sfx.volume_db = _sfx_volume_db()
	_sfx.play()
	_sfx.stream_paused = _paused

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
	if note < 0 or note >= _note_streams.size(): return
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
	for player in _music_players:
		player.stream_paused = paused
	if _ambience:
		_ambience.stream_paused = paused
	if _sfx:
		_sfx.stream_paused = paused
	if _notes:
		_notes.stream_paused = paused
	if _dialogue_beep_player:
		_dialogue_beep_player.stream_paused = paused

func _set_ambience_enabled(enabled: bool) -> void:
	if _ambience_tween and _ambience_tween.is_running():
		_ambience_tween.kill()
	if enabled:
		if not _ambience.playing and _ambience.stream == null:
			_ambience.stream = load(AMBIENCE_PATH) as AudioStreamWAV
			if _ambience.stream is AudioStreamWAV:
				(_ambience.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		if not _ambience.playing:
			_ambience.play()
		_ambience.stream_paused = _paused
		_ambience_gain = 0.0
		_set_ambience_volume()
		_ambience_tween = create_tween()
		_ambience_tween.tween_method(_set_ambience_gain, 0.0, 1.0, FADE_SECONDS)
	else:
		_ambience_tween = create_tween()
		_ambience_tween.tween_method(_set_ambience_gain, _ambience_gain, 0.0, FADE_SECONDS)
		_ambience_tween.tween_callback(_ambience.stop)

func _set_music_gain(value: float) -> void:
	_music_gain = clampf(value, 0.0, 1.0)
	_set_active_music_volume()

func _set_ambience_gain(value: float) -> void:
	_ambience_gain = clampf(value, 0.0, 1.0)
	_set_ambience_volume()

func _set_active_music_volume() -> void:
	if _active_music >= 0 and _active_music < _music_players.size():
		_music_players[_active_music].volume_db = _linear_to_db(_settings.master * _settings.music * _music_gain)

func _set_ambience_volume() -> void:
	if _ambience:
		_ambience.volume_db = _linear_to_db(_settings.master * _settings.music * 0.35 * _ambience_gain)

func _sfx_volume_db() -> float:
	return _linear_to_db(_settings.master * _settings.sfx)

func _linear_to_db(value: float) -> float:
	if value <= 0.000001:
		return SILENCE_DB
	return linear_to_db(value)
