extends RefCounted

const LEFT := 1
const RIGHT := 2
const BOTH := LEFT | RIGHT
const RECIPES := [[1, 2, 1], [2, 1, 2]]
const BEATS := [0.60, 0.70]
const ROUND_SECONDS := 75.0
const START_BEAT := 2
const BASE_WINDOW := 0.14
const ASSIST_WINDOW := 0.23
const CENTER_LIMIT := 0.12
enum { PRESS, REBOUND, REST }

var _layout := 0
var _assisted := false
var _helper := false
var _phase := PRESS
var _clock := 0.0
var _elapsed := 0.0
var _last_beat := -1
var _held := 0
var _started := Vector2(-1, -1)
var _released := Vector2(-1, -1)
var _layers: Array[float] = []
var _offset := 0.0
var _centered := false
var _attempted_rebound := false
var _worked := false
var _mistakes := 0
var _ended := false
var _feedback := ""
var _notes: Array[int] = []

func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, RECIPES.size())
	_helper = false
	_elapsed = 0.0
	_layers.clear()
	_centered = false
	_worked = false
	_mistakes = 0
	_ended = false
	_held = 0
	_notes.clear()
	_open_layer()

func toggle_helper() -> void:
	if _ended or _held != 0:
		return
	_helper = not _helper
	_feedback = "AI 隨左模一起壓右模。" if _helper else "左右模由你操作。"

func set_pressed(mask: int) -> void:
	if _ended:
		return
	mask &= BOTH
	var changed := mask ^ _held
	if changed == 0:
		return
	var rising := changed & mask
	_held = mask
	if _phase == REBOUND:
		if rising != 0:
			_rebound(rising)
		return
	if _phase != PRESS:
		return
	for index in 2:
		var side := 1 << index
		if (changed & side) == 0:
			continue
		if (mask & side) != 0:
			if absf(_clock - _start_time()) > _window() or _started[index] >= 0.0:
				_miss("空拍提早壓模，等合模線再試。" if _clock < _start_time() else "合模太晚，下一輪再試。")
				return
			_started[index] = _clock
		else:
			if absf(_clock - _release_time()) > _window() or _started[index] < 0.0:
				_miss("放開太早，夾心溢出。" if _clock < _release_time() else "放開太晚，夾心溢出。")
				return
			_released[index] = _clock
	if _released.x >= 0.0 and _released.y >= 0.0:
		if absf(_started.x - _started.y) > _window() or absf(_released.x - _released.y) > _window():
			_miss("左右不同步，餡被擠偏。")
		else:
			_seal()

func clear_input() -> void:
	_held = 0
	_notes.clear()
	if not _ended and _phase == PRESS and (_started.x >= 0.0 or _started.y >= 0.0):
		_open_layer()

func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, minf(0.25, ROUND_SECONDS - _elapsed))
	_elapsed = minf(_elapsed + delta, ROUND_SECONDS)
	_clock += delta
	match _phase:
		PRESS:
			if _held == BOTH and _clock - maxf(_started.x, _started.y) >= 0.12:
				_worked = true
			var beat := floori(_clock / _beat())
			if beat != _last_beat:
				_last_beat = beat
				_note(3 if beat == START_BEAT else (5 if beat == START_BEAT + _beats_to_hold() else 0))
			if _clock > _release_time() + _window():
				_miss("放開太晚，夾心溢出。" if _held != 0 else "錯過這層的節拍。")
		REBOUND:
			if _clock >= _beat() and _last_beat == -1:
				_last_beat = 1
				_note(6)
			if _clock > _beat() + _window():
				if _layers.size() == RECIPES[_layout].size():
					_ended = true
				else:
					_rest("留空回彈，下一層即將開始。")
		REST:
			if _clock >= _beat() and _held == 0:
				_open_layer()
	if _elapsed >= ROUND_SECONDS:
		_ended = true

func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes

func _note(note: int) -> void:
	if _notes.size() < 8:
		_notes.append(note)

func _seal() -> void:
	_worked = true
	var holds := _released - _started
	_layers.append((holds.x + holds.y) * 0.5)
	var side := 1.0 if (_layers.size() + _layout) % 2 == 1 else -1.0
	_offset = side * 0.44 + clampf((holds.x - holds.y) * 0.35, -0.12, 0.12)
	_phase = REBOUND
	_attempted_rebound = false
	_clock = 0.0
	_last_beat = -1
	_feedback = "封口成功。可在回彈拍輕壓偏餡側。"

func _rebound(rising: int) -> void:
	if _attempted_rebound:
		return
	_attempted_rebound = true
	if absf(_clock - _beat()) > _window():
		_feedback = "回彈時機未到位。這層封口已保留。"
		return
	if rising == BOTH:
		_feedback = "回彈需要單側輕壓。"
		return
	var strength := 0.44 * (1.0 - 0.22 * absf(_clock - _beat()) / _window())
	_offset = clampf(_offset + (strength if rising == LEFT else -strength), -1.0, 1.0)
	if absf(_offset) <= CENTER_LIMIT:
		_centered = true
		_feedback = "回彈置中成功！"
	else:
		_feedback = "餡仍有偏移，留意應壓的方向。"

func _miss(message: String) -> void:
	_mistakes += 1
	_rest(message)

func _rest(message: String) -> void:
	_phase = REST
	_clock = 0.0
	_feedback = message

func _open_layer() -> void:
	_phase = PRESS
	_clock = 0.0
	_last_beat = -1
	_started = Vector2(-1, -1)
	_released = Vector2(-1, -1)
	_offset = 0.0
	_feedback = "空拍先留空。到合模線按住，再按配方放開。"

func _beat() -> float:
	return BEATS[_layout]

func _beats_to_hold() -> int:
	return RECIPES[_layout][mini(_layers.size(), RECIPES[_layout].size() - 1)]

func _start_time() -> float:
	return START_BEAT * _beat()

func _release_time() -> float:
	return _start_time() + _beats_to_hold() * _beat()

func _window() -> float:
	return ASSIST_WINDOW if _assisted else BASE_WINDOW

func is_pressing_phase() -> bool:
	return _phase == PRESS and not _ended

func snapshot() -> Dictionary:
	var target := _release_time() if _phase == PRESS else _beat()
	var success: bool = _layers.size() == RECIPES[_layout].size()
	var devil := success and _centered
	var pressure := Vector2.ZERO
	for index in 2:
		if (_held & (1 << index)) != 0:
			pressure[index] = clampf((_clock - _started[index]) / maxf(0.2, _beat()), 0.15, 1.0) if _phase == PRESS else 0.4
	return {"layout": _layout, "recipe": RECIPES[_layout].duplicate(), "assisted": _assisted, "helper": _helper,
		"phase": _phase, "clock": _clock, "target": target, "start": _start_time(), "beat": _beat(), "window": _window(),
		"offset": _offset, "pressure": pressure, "held": _held, "centered": _centered, "layers": _layers.duplicate(),
		"elapsed": _elapsed, "remaining": ROUND_SECONDS - _elapsed, "mistakes": _mistakes, "feedback": _feedback,
		"score": maxi(0, _layers.size() * 140 + 100 * int(devil) - 20 * _mistakes),
		"ended": _ended, "success": success, "devil": devil, "ordinary_eligible": _ended and _worked}
