extends Node
class_name RibbonGroove

## Original backing groove for 彩帶節拍, synthesized once from the same beat chart
## the rules use (no samples, CC0 project output). The track starts with a spoken-
## free three-click count-in, then every scheduled gesture lands on a kick plus a
## pitched marimba note; held ribbon gestures get a rising swoosh for their exact
## hold length, and a short finale follows the eighth beat. The Session reads this
## player's audio clock so the visual beat, the music and the judgement share one
## time base.
const RibbonModel = preload("res://game/minigames/ribbon_rhythm_model.gd")
const RATE := 22050
const COUNT_IN_BEATS := 3
const PREROLL_SECONDS := COUNT_IN_BEATS * RibbonModel.BEAT_INTERVAL
const TAIL_SECONDS := 1.6
const ACTION_NOTES := {"left": 64, "right": 67, "jump": 72}
const BASS_ROOTS: Array[int] = [36, 33, 29, 31]
const FINALE_NOTES: Array[int] = [72, 76, 79, 84]
const PEAK := 0.82

static var _cached_stream: AudioStreamWAV

var player: AudioStreamPlayer
var _last_audio_time := -1.0
var _stalled_frames := 0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "RibbonGroovePlayer"
	player.stream = groove_stream()
	add_child(player)

## Seconds of music before model time zero (the count-in plus the model's own lead beat offset).
static func preroll_seconds() -> float:
	return PREROLL_SECONDS

## Groove-time of each count-in click; the last one is one beat before the first gesture.
static func count_in_times() -> Array[float]:
	var times: Array[float] = []
	var first_gesture := PREROLL_SECONDS + RibbonModel.FIRST_BEAT_TIME
	for beat in range(COUNT_IN_BEATS, 0, -1):
		times.append(first_gesture - float(beat) * RibbonModel.BEAT_INTERVAL)
	return times

## Groove-time of each scheduled gesture (model cue time + preroll).
static func gesture_times() -> Array[float]:
	var times: Array[float] = []
	for index in RibbonModel.GESTURES.size():
		times.append(PREROLL_SECONDS + RibbonModel.FIRST_BEAT_TIME + float(index) * RibbonModel.BEAT_INTERVAL)
	return times

static func total_seconds() -> float:
	return gesture_times()[-1] + TAIL_SECONDS

static func groove_stream() -> AudioStreamWAV:
	if _cached_stream == null:
		_cached_stream = _render()
	return _cached_stream

func play_from(groove_time: float) -> void:
	if player == null:
		return
	_last_audio_time = -1.0
	_stalled_frames = 0
	player.stream_paused = false
	player.play(clampf(groove_time, 0.0, total_seconds()))

func stop() -> void:
	if player != null:
		player.stop()
	_last_audio_time = -1.0

func set_paused(value: bool) -> void:
	if player != null and player.playing:
		player.stream_paused = value

func set_volume_linear(value: float) -> void:
	if player != null:
		player.volume_db = linear_to_db(value) if value > 0.000001 else -80.0

## Latency-compensated playback time, or -1 when the audio clock is not advancing
## (not playing, paused, or a driver that never mixes such as Dummy).
func audio_time() -> float:
	if player == null or not player.playing or player.stream_paused:
		return -1.0
	var position := player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	if _last_audio_time >= 0.0 and position <= _last_audio_time + 0.000001:
		_stalled_frames += 1
		if _stalled_frames > 6:
			return -1.0
	else:
		_stalled_frames = 0
	_last_audio_time = maxf(position, _last_audio_time)
	return maxf(0.0, _last_audio_time)

static func _render() -> AudioStreamWAV:
	var length := int(ceil(total_seconds() * RATE))
	var mix := PackedFloat32Array()
	mix.resize(length)
	var noise := RandomNumberGenerator.new()
	noise.seed = 20261023
	# Count-in: three dry woodblock clicks, the last one brighter.
	var clicks := count_in_times()
	for index in clicks.size():
		_add_woodblock(mix, clicks[index], 1.25 if index == clicks.size() - 1 else 1.0)
	var times := gesture_times()
	for index in RibbonModel.GESTURES.size():
		var gesture: Dictionary = RibbonModel.GESTURES[index]
		var at := times[index]
		var strong := bool(gesture.strong)
		_add_kick(mix, at, 0.62 if strong else 0.42)
		if strong:
			_add_clap(mix, at, noise)
		_add_marimba(mix, at, int(ACTION_NOTES.get(str(gesture.action), 67)), 0.30)
		_add_shaker(mix, at + RibbonModel.BEAT_INTERVAL * 0.5, noise)
		if float(gesture.hold) > 0.0:
			_add_swoosh(mix, at, float(gesture.hold), str(gesture.action) == "right")
		if index % 2 == 0:
			_add_bass(mix, at, BASS_ROOTS[(index >> 1) % BASS_ROOTS.size()], RibbonModel.BEAT_INTERVAL * 1.9)
	# Soft pad under the count-in so the tempo is felt before the first input.
	_add_bass(mix, clicks[0], BASS_ROOTS[0], PREROLL_SECONDS + RibbonModel.FIRST_BEAT_TIME - clicks[0])
	# Finale: a quick rising arpeggio and a chord that both finish inside the
	# Session's 1.3 s closing dance, before the result screen replaces the stage.
	var finale_start := times[-1] + RibbonModel.BEAT_INTERVAL * 0.25
	for index in FINALE_NOTES.size():
		_add_marimba(mix, finale_start + float(index) * RibbonModel.BEAT_INTERVAL * 0.125, FINALE_NOTES[index], 0.24)
	for note in [60, 64, 67]:
		_add_marimba(mix, finale_start + RibbonModel.BEAT_INTERVAL * 0.5, note, 0.16)
	_add_kick(mix, finale_start + RibbonModel.BEAT_INTERVAL * 0.5, 0.5)
	return _to_stream(mix)

static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)

static func _span(mix: PackedFloat32Array, at: float, duration: float) -> Vector2i:
	var first := clampi(int(round(at * RATE)), 0, mix.size())
	var last := clampi(int(round((at + duration) * RATE)), 0, mix.size())
	return Vector2i(first, last)

static func _add_kick(mix: PackedFloat32Array, at: float, amp: float) -> void:
	var span := _span(mix, at, 0.26)
	var phase := 0.0
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		phase += TAU * lerpf(118.0, 46.0, minf(1.0, t / 0.12)) / RATE
		mix[i] += sin(phase) * amp * exp(-t * 16.0)

static func _add_clap(mix: PackedFloat32Array, at: float, noise: RandomNumberGenerator) -> void:
	var span := _span(mix, at, 0.12)
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		mix[i] += noise.randf_range(-1.0, 1.0) * 0.16 * exp(-t * 34.0)

static func _add_shaker(mix: PackedFloat32Array, at: float, noise: RandomNumberGenerator) -> void:
	var span := _span(mix, at, 0.07)
	var previous := 0.0
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		var white := noise.randf_range(-1.0, 1.0)
		# A first-difference keeps only the bright top of the noise.
		mix[i] += (white - previous) * 0.05 * exp(-t * 60.0)
		previous = white

static func _add_woodblock(mix: PackedFloat32Array, at: float, brightness: float) -> void:
	var span := _span(mix, at, 0.09)
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		var env := exp(-t * 48.0)
		mix[i] += (sin(TAU * 1180.0 * brightness * t) * 0.32 + sin(TAU * 1770.0 * brightness * t) * 0.12) * env

static func _add_marimba(mix: PackedFloat32Array, at: float, midi: int, amp: float) -> void:
	var span := _span(mix, at, 0.7)
	var frequency := _hz(midi)
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		var attack := minf(1.0, t / 0.004)
		mix[i] += (sin(TAU * frequency * t) + 0.32 * sin(TAU * frequency * 4.0 * t) * exp(-t * 18.0)) * amp * attack * exp(-t * 5.5)

static func _add_bass(mix: PackedFloat32Array, at: float, midi: int, duration: float) -> void:
	var span := _span(mix, at, duration)
	var frequency := _hz(midi)
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		var env := minf(1.0, t / 0.03) * minf(1.0, (duration - t) / 0.12) * exp(-t * 0.9)
		mix[i] += (sin(TAU * frequency * t) + sin(TAU * frequency * 3.0 * t) / 9.0) * 0.20 * env

static func _add_swoosh(mix: PackedFloat32Array, at: float, duration: float, rising_high: bool) -> void:
	var span := _span(mix, at, duration + 0.08)
	var phase := 0.0
	var start_hz := 520.0 if rising_high else 460.0
	var end_hz := 1240.0 if rising_high else 1040.0
	for i in range(span.x, span.y):
		var t := float(i - span.x) / RATE
		var progress := clampf(t / duration, 0.0, 1.0)
		phase += TAU * lerpf(start_hz, end_hz, progress) / RATE
		var env := minf(1.0, t / 0.03) * (1.0 if t <= duration else maxf(0.0, 1.0 - (t - duration) / 0.08))
		mix[i] += (sin(phase) * 0.07 + sin(phase * 2.01) * 0.03) * env

static func _to_stream(mix: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for value in mix:
		peak = maxf(peak, absf(value))
	var gain := minf(1.0, PEAK / peak)
	var bytes := PackedByteArray()
	bytes.resize(mix.size() * 2)
	for i in mix.size():
		bytes.encode_s16(i * 2, int(clampf(mix[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
