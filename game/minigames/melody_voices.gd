extends Node
class_name MelodyVoices

## Four synthesized instrument voices for 迎賓大合奏 (project-original CC0 output,
## no samples). Each keeps the established pitch of its slot (C5, E5, G5, C6) but
## sounds like the drawn instrument: shell reed = plucked kalimba, glass bell =
## inharmonic bell partials, driftwood board = woody log tone, harbor drum = tuned
## membrane with a pitch drop. Encore notes add a soft harmony a sixth below.
const RATE := 22050
const PITCHES: Array[int] = [72, 76, 79, 84]
const HARMONY_OFFSET := -8
const KINDS: Array[String] = ["shell_reed", "glass_bell", "wood_block", "harbor_drum"]

static var _cached: Array[AudioStreamWAV] = []
static var _cached_harmony: Array[AudioStreamWAV] = []

var _players: Array[AudioStreamPlayer] = []
var _harmony_player: AudioStreamPlayer
var _paused := false

func _ready() -> void:
	var streams := voice_streams()
	for index in streams.size():
		var player := AudioStreamPlayer.new()
		player.name = "Voice_%s" % KINDS[index]
		player.stream = streams[index]
		player.max_polyphony = 3
		add_child(player)
		_players.append(player)
	_harmony_player = AudioStreamPlayer.new()
	_harmony_player.name = "Harmony"
	_harmony_player.max_polyphony = 3
	add_child(_harmony_player)

static func voice_streams() -> Array[AudioStreamWAV]:
	if _cached.is_empty():
		for index in PITCHES.size():
			_cached.append(_render_voice(index, PITCHES[index]))
		for index in PITCHES.size():
			_cached_harmony.append(_render_harmony(PITCHES[index] + HARMONY_OFFSET))
	return _cached

## Plays one instrument; `with_harmony` adds the soft encore harmony under it.
func play(index: int, with_harmony: bool = false) -> bool:
	if index < 0 or index >= _players.size() or _paused:
		return false
	_players[index].play()
	if with_harmony and index < _cached_harmony.size():
		_harmony_player.stream = _cached_harmony[index]
		_harmony_player.play()
	return true

func set_paused(value: bool) -> void:
	_paused = value
	for player in _players:
		player.stream_paused = value
	if _harmony_player != null:
		_harmony_player.stream_paused = value

func stop_all() -> void:
	for player in _players:
		player.stop()
	if _harmony_player != null:
		_harmony_player.stop()

func set_volume_linear(value: float) -> void:
	var db := linear_to_db(value) if value > 0.000001 else -80.0
	for player in _players:
		player.volume_db = db
	if _harmony_player != null:
		_harmony_player.volume_db = db - 9.0

static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)

static func _render_voice(index: int, midi: int) -> AudioStreamWAV:
	var frequency := _hz(midi)
	var seconds: float = [0.95, 1.5, 0.6, 0.5][index]
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	var noise := RandomNumberGenerator.new()
	noise.seed = 4100 + index
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var attack := minf(1.0, t / 0.003)
		var value := 0.0
		match index:
			0:
				# Plucked shell reed: bright tine that settles to its fundamental.
				value = (sin(TAU * frequency * t) + 0.45 * sin(TAU * frequency * 3.01 * t) * exp(-t * 9.0)) * exp(-t * 3.2)
			1:
				# Glass bell: inharmonic partials with longer low ring.
				value = sin(TAU * frequency * t) * exp(-t * 2.2) + 0.5 * sin(TAU * frequency * 2.76 * t) * exp(-t * 3.5) + 0.25 * sin(TAU * frequency * 5.40 * t) * exp(-t * 6.0) + 0.12 * sin(TAU * frequency * 8.93 * t) * exp(-t * 9.0)
			2:
				# Driftwood board: short woody body plus a soft mallet click.
				value = (sin(TAU * frequency * t) + 0.3 * sin(TAU * frequency * 4.0 * t) * exp(-t * 22.0)) * exp(-t * 7.5) + noise.randf_range(-1.0, 1.0) * 0.18 * exp(-t * 90.0)
			3:
				# Tuned harbor drum: membrane drops into pitch with a skin slap.
				phase += TAU * frequency * lerpf(1.45, 1.0, minf(1.0, t / 0.04)) / RATE
				value = sin(phase) * exp(-t * 8.5) + noise.randf_range(-1.0, 1.0) * 0.32 * exp(-t * 38.0)
		samples[i] = value * attack
	return _to_stream(samples, 0.62)

static func _render_harmony(midi: int) -> AudioStreamWAV:
	var frequency := _hz(midi)
	var samples := PackedFloat32Array()
	samples.resize(int(0.7 * RATE))
	for i in samples.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.04) * exp(-t * 3.0)
		samples[i] = (sin(TAU * frequency * t) + 0.3 * sin(TAU * frequency * 2.0 * t)) * env
	return _to_stream(samples, 0.42)

static func _to_stream(samples: PackedFloat32Array, peak_target: float) -> AudioStreamWAV:
	var peak := 0.0001
	for value in samples:
		peak = maxf(peak, absf(value))
	var gain := peak_target / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
