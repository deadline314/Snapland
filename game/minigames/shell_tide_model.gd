extends RefCounted
class_name ShellTideModel

## Call and response on a beat grid. Each phrase is demonstrated, then echoed;
## events are [shell 0–3 or -1 rest, length in beats]. Judgement uses real time.
const ROUND_SECONDS := 150.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 120.0
const WINDOW := 0.15
const ASSIST_WINDOW := 0.25
const PERFECT := 0.06
const LONG_HOLD := 0.8
const COUNT_IN_BEATS := 2
const LONG_WAVE_BEATS := 4
const SLOW_TEMPO := 1.25
const PASS_RATIO := 0.75
const ATTEMPTS := 2
const MAX_OFFSET := 0.15
const OFFSET_STEP := 0.01
const HIT_POINTS := 50
const PERFECT_POINTS := 25
const PHRASE_POINTS := 100
const SHORT_WAVE_POINTS := 50
## Retries alternate the tide tempo and where the silences fall.
const VARIANTS := [
	{"name": "緩潮", "beat": 0.5, "phrases": [
		[[0, 1], [1, 1], [-1, 1], [2, 1]],
		[[3, 1], [1, 2], [-1, 1], [0, 1], [2, 1]],
		[[1, 1], [2, 1], [-1, 1], [3, 2], [-1, 1], [0, 1], [1, 2]]]},
	{"name": "急潮", "beat": 0.45, "phrases": [
		[[2, 1], [-1, 1], [3, 1], [1, 1]],
		[[0, 2], [2, 1], [-1, 1], [3, 1], [1, 1]],
		[[3, 1], [-1, 1], [0, 2], [1, 1], [-1, 1], [2, 1], [3, 2]]]},
]

var _assisted := false
var _variant := 0
var _beat := 0.5
var _elapsed := 0.0
var _phase := "demo"
var _phase_time := 0.0
var _phrase := 0
var _attempt := 0
var _slow := false
var _offset := 0.0
var _events: Array[Dictionary] = []
var _held: Dictionary = {}
var _passed: Array[bool] = []
var _short_passes := 0
var _rest_presses := 0
var _wrong := 0
var _hits := 0
var _perfects := 0
var _notes: Array[int] = []
var _last_judgement := {}
var _ended := false
var _success := false
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, VARIANTS.size())
	_beat = float(VARIANTS[_variant].beat)
	_elapsed = 0.0
	_phrase = 0
	_attempt = 0
	_offset = 0.0
	_held.clear()
	_passed.clear()
	_short_passes = 0
	_rest_presses = 0
	_wrong = 0
	_hits = 0
	_perfects = 0
	_notes.clear()
	_last_judgement = {}
	_ended = false
	_success = false
	_start_demo()

func _start_demo() -> void:
	_phase = "demo"
	_phase_time = 0.0
	_slow = false
	_build_events()
	_feedback = "聽第 %d 段潮聲：看波紋先後與寬窄" % (_phrase + 1)

func _tempo() -> float:
	return _beat * (SLOW_TEMPO if _slow else 1.0)

func _window() -> float:
	return (ASSIST_WINDOW if _assisted else WINDOW) * (1.2 if _slow else 1.0)

func _build_events() -> void:
	_events.clear()
	var time := 0.0
	for row: Array in VARIANTS[_variant].phrases[_phrase]:
		_events.append({"shell": int(row[0]), "beats": int(row[1]), "start": time, "duration": float(row[1]) * _tempo(),
			"judged": false, "hit": false, "pressed_at": -1.0, "error": 0.0, "complete": false, "demo_played": false})
		time += float(row[1]) * _tempo()

func _phrase_length() -> float:
	var last: Dictionary = _events[-1]
	return last.start + last.duration

## Before the echo starts, W waits one long wave: slower beat and wider windows.
func wait_long_wave() -> void:
	if _ended or _phase != "ready" or _slow:
		return
	_slow = true
	_build_events()
	_phase_time = 0.0
	_feedback = "等一道長浪：放慢節奏再回應"

func calibrate(step: int) -> void:
	if _ended:
		return
	if not _assisted:
		_feedback = "延遲校準只在輔助模式提供"
		return
	_offset = clampf(_offset + signi(step) * OFFSET_STEP, -MAX_OFFSET, MAX_OFFSET)
	_feedback = "延遲校準 %+d 毫秒" % roundi(_offset * 1000.0)

func press(shell: int) -> void:
	if _ended or shell < 0 or shell > 3:
		return
	_held[shell] = true
	if _phase != "echo":
		return
	_notes.append(shell)
	var t := _phase_time - _offset
	var best := -1
	for index in _events.size():
		var event: Dictionary = _events[index]
		if event.judged or event.shell != shell:
			continue
		if absf(t - event.start) <= _window():
			best = index
			break
	if best >= 0:
		var event: Dictionary = _events[best]
		event.judged = true
		event.hit = true
		event.pressed_at = t
		event.error = t - event.start
		event.complete = event.beats == 1
		_hits += 1
		var perfect := absf(event.error) <= PERFECT
		if perfect:
			_perfects += 1
		_last_judgement = {"shell": shell, "error_ms": roundi(event.error * 1000.0), "perfect": perfect, "rest": false}
		_feedback = ("準！" if perfect else ("早 " if event.error < 0.0 else "晚 ")) + "%+d 毫秒" % roundi(event.error * 1000.0)
		return
	var in_rest := false
	for event: Dictionary in _events:
		if event.shell < 0 and t >= event.start - _window() * 0.5 and t <= event.start + event.duration - _window() * 0.5:
			in_rest = true
	if in_rest:
		_rest_presses += 1
		_feedback = "靜默拍不能敲！"
	else:
		_wrong += 1
		_feedback = "貝殼或時機不對"
	_last_judgement = {"shell": shell, "error_ms": 0, "perfect": false, "rest": in_rest}

func release(shell: int) -> void:
	if not _held.has(shell):
		return
	_held.erase(shell)
	if _phase != "echo":
		return
	var t := _phase_time - _offset
	for event: Dictionary in _events:
		if event.hit and event.beats > 1 and event.shell == shell and not event.complete and event.pressed_at >= 0.0:
			var held_for: float = t - event.pressed_at
			if held_for >= event.duration * LONG_HOLD:
				event.complete = true
				_feedback = "長音收得好"
			else:
				_feedback = "長音放太早"
			event.pressed_at = -1.0

func clear_input() -> void:
	for shell in _held.keys():
		release(shell)
	_held.clear()

func consume_notes() -> Array[int]:
	var notes := _notes.duplicate()
	_notes.clear()
	return notes

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, SUBSTEP)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	_phase_time += dt
	match _phase:
		"demo":
			for event: Dictionary in _events:
				if not event.demo_played and _phase_time >= event.start and event.shell >= 0:
					event.demo_played = true
					_notes.append(event.shell)
			if _phase_time >= _phrase_length() + _beat:
				_phase = "ready"
				_phase_time = 0.0
				_feedback = "短浪來了就回應，或按 W 等長浪放慢"
		"ready":
			var wait: float = (LONG_WAVE_BEATS if _slow else COUNT_IN_BEATS) * _tempo()
			if _phase_time >= wait:
				_phase = "echo"
				_phase_time = 0.0
				_feedback = "照波紋回應！"
		"echo":
			# Long notes held past their full length complete on their own.
			for event: Dictionary in _events:
				if event.hit and event.beats > 1 and not event.complete and event.pressed_at >= 0.0 and _phase_time - _offset - event.pressed_at >= event.duration * LONG_HOLD:
					event.complete = true
			if _phase_time >= _phrase_length() + _window() + 0.2:
				_finish_phrase()
	if not _ended and _elapsed >= ROUND_SECONDS:
		_ended = true
		_feedback = "時間到：完成 %d / 3 段" % _passed.count(true)

func _finish_phrase() -> void:
	var notes := 0
	var correct := 0
	for event: Dictionary in _events:
		if event.shell >= 0:
			notes += 1
			if event.hit and event.complete:
				correct += 1
	var passed := correct >= ceili(notes * PASS_RATIO)
	if passed:
		_passed.append(true)
		if not _slow:
			_short_passes += 1
		_feedback = "第 %d 段完成（%d / %d）" % [_phrase + 1, correct, notes]
	elif _attempt + 1 < ATTEMPTS:
		_attempt += 1
		_feedback = "第 %d 段只對 %d / %d，再聽一次" % [_phrase + 1, correct, notes]
		_start_demo()
		return
	else:
		_passed.append(false)
		_feedback = "第 %d 段沒接上，繼續下一段" % (_phrase + 1)
	_phrase += 1
	_attempt = 0
	if _phrase >= VARIANTS[_variant].phrases.size():
		_ended = true
		_success = not _passed.has(false)
		_feedback = "三段潮聲都回應了" if _success else "結束：完成 %d / 3 段" % _passed.count(true)
		return
	_start_demo()

func snapshot() -> Dictionary:
	var devil := _success and _rest_presses == 0
	var phrase_events: Array = []
	for event: Dictionary in _events:
		phrase_events.append(event.duplicate())
	var score := _hits * HIT_POINTS + _perfects * PERFECT_POINTS + _passed.count(true) * PHRASE_POINTS + _short_passes * SHORT_WAVE_POINTS
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": VARIANTS[_variant].name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil, "devil_success": devil,
		"ordinary_eligible": _ended, "score": score, "mistakes": _rest_presses + _wrong,
		"phase": _phase, "phase_time": _phase_time, "phrase": _phrase, "attempt": _attempt, "slow": _slow, "beat": _tempo(),
		"events": phrase_events, "window": _window(), "offset": _offset, "held": _held.keys(), "passed": _passed.duplicate(),
		"passed_count": _passed.count(true), "short_passes": _short_passes, "rest_presses": _rest_presses, "wrong": _wrong,
		"hits": _hits, "perfects": _perfects, "judgement": _last_judgement.duplicate(), "score_visible": _assisted or _phase != "echo",
		"feedback": _feedback, "last_event": _feedback,
	}
