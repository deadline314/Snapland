extends RefCounted
class_name RibbonRhythmModel

## A fixed eight-count stage phrase. The verb changes between directional steps,
## jumps, and sustained ribbon sweeps; it is not eight copies of one tap.
const GESTURES: Array[Dictionary] = [
	{"action": "left", "pose": "walk_left", "hold": 0.0, "strong": true, "ribbon": "low_left", "label": "左步"},
	{"action": "right", "pose": "walk_right", "hold": 0.0, "strong": false, "ribbon": "low_right", "label": "右步"},
	{"action": "jump", "pose": "jump_front", "hold": 0.0, "strong": false, "ribbon": "jump_loop", "label": "跳起"},
	{"action": "left", "pose": "wave_front", "hold": 0.34, "strong": true, "ribbon": "high_left_sweep", "label": "左側留拍"},
	{"action": "right", "pose": "walk_right", "hold": 0.0, "strong": false, "ribbon": "low_right", "label": "右步"},
	{"action": "jump", "pose": "jump_front", "hold": 0.0, "strong": true, "ribbon": "jump_loop", "label": "重拍躍起"},
	{"action": "right", "pose": "wave_front", "hold": 0.40, "strong": false, "ribbon": "high_right_sweep", "label": "右側留拍"},
	{"action": "left", "pose": "walk_left", "hold": 0.0, "strong": true, "ribbon": "low_left", "label": "收步"},
]

const BEAT_INTERVAL := 0.94
const FIRST_BEAT_TIME := 1.02
const MAX_DELTA := 0.25
const PRECISE_WINDOW := 0.105
const ACCEPT_WINDOW := 0.27
const ASSISTED_WINDOW := 0.46
const HOLD_TOLERANCE := 0.13
const ASSISTED_HOLD_TOLERANCE := 0.24
const MIN_PRESS_INTERVAL := 0.13
const PERFECT_POINTS := 100
const GOOD_POINTS := 60
const STRONG_BONUS := 25
const ORDINARY_SUCCESS_HITS := 6

var assisted := false
var time_phase := "noon"
var elapsed := 0.0
var phase := "active"
var gesture_index := 0
var correct_count := 0
var precise_count := 0
var missed_count := 0
var error_count := 0
var score := 0
var ended := false
var success := false
var devil_success := false
var note_played_serial := 0
var last_grade := ""
var last_event := "看向前方兩拍預告，依節奏踩步、躍起或按住揮帶"

var _cue_times: Array[float] = []
var _played_cues: Dictionary = {}
var _held_action := ""
var _held_started_at := 0.0
var _held_index := -1
var _last_press_at := -1000.0
var _last_pressed_action := ""
var _errors_for_gesture: Dictionary = {}
var _trail: Array[Dictionary] = []
var _snapshot_cache: Dictionary = {}

func reset(p_assisted: bool = false, p_time_phase: String = "noon") -> void:
	assisted = p_assisted
	time_phase = p_time_phase if p_time_phase in ["dawn", "noon", "dusk", "night"] else "noon"
	elapsed = 0.0
	phase = "active"
	gesture_index = 0
	correct_count = 0
	precise_count = 0
	missed_count = 0
	error_count = 0
	score = 0
	ended = false
	success = false
	devil_success = false
	note_played_serial = 0
	last_grade = ""
	last_event = "看向前方兩拍預告，依節奏踩步、躍起或按住揮帶"
	_cue_times.clear()
	for index in range(GESTURES.size()):
		_cue_times.append(FIRST_BEAT_TIME + float(index) * BEAT_INTERVAL)
	_played_cues.clear()
	_held_action = ""
	_held_started_at = 0.0
	_held_index = -1
	_last_press_at = -1000.0
	_last_pressed_action = ""
	_errors_for_gesture.clear()
	_trail.clear()
	_snapshot_cache.clear()
	_refresh_snapshot()

func retry() -> void:
	reset(assisted, time_phase)

func step(delta: float) -> Dictionary:
	if ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	elapsed += minf(delta, MAX_DELTA)
	_update_audio_cues()
	_resolve_expired_gesture()
	_refresh_snapshot()
	return snapshot()

func press_action(action: String) -> Dictionary:
	if ended or not ["left", "right", "jump"].has(action):
		return snapshot()
	if _held_action == action:
		return snapshot()
	if action == _last_pressed_action and elapsed - _last_press_at < MIN_PRESS_INTERVAL:
		return snapshot()
	_last_press_at = elapsed
	_last_pressed_action = action
	if gesture_index >= GESTURES.size():
		return snapshot()
	if not _held_action.is_empty():
		_register_error("先放開上一個動作")
		_refresh_snapshot()
		return snapshot()
	var cue: Dictionary = GESTURES[gesture_index]
	if action != str(cue.action):
		_register_error("方向不符，下一拍再試")
		_refresh_snapshot()
		return snapshot()
	var offset := elapsed - _cue_times[gesture_index]
	if offset < -_timing_window():
		_register_error("太早起步，留意前方領拍")
		_refresh_snapshot()
		return snapshot()
	if offset > _timing_window():
		_register_miss("慢拍，彩帶落在地板上")
		_refresh_snapshot()
		return snapshot()
	if float(cue.hold) > 0.0:
		_held_action = action
		_held_started_at = elapsed
		_held_index = gesture_index
		last_event = "按住，讓彩帶走過整個弧線"
		_refresh_snapshot()
		return snapshot()
	_complete_gesture(absf(offset), 0.0)
	_refresh_snapshot()
	return snapshot()

func release_action(action: String) -> Dictionary:
	if ended or _held_action.is_empty() or action != _held_action or _held_index != gesture_index:
		return snapshot()
	var cue: Dictionary = GESTURES[gesture_index]
	var held_for := maxf(0.0, elapsed - _held_started_at)
	var required := float(cue.hold)
	_held_action = ""
	_held_index = -1
	if held_for < required - 0.04:
		_register_miss("彩帶還沒走完就放開")
	elif absf(held_for - required) > _hold_tolerance():
		_register_miss("彩帶留拍長度不準")
	else:
		_complete_gesture(absf(_held_started_at - _cue_times[gesture_index]), absf(held_for - required))
	_refresh_snapshot()
	return snapshot()

func snapshot() -> Dictionary:
	return _snapshot_cache

func _timing_window() -> float:
	return ASSISTED_WINDOW if assisted else ACCEPT_WINDOW

func _hold_tolerance() -> float:
	return ASSISTED_HOLD_TOLERANCE if assisted else HOLD_TOLERANCE

func _update_audio_cues() -> void:
	for index in range(GESTURES.size()):
		if elapsed >= _cue_times[index] and not _played_cues.has(index):
			_played_cues[index] = true
			note_played_serial += 1

func _resolve_expired_gesture() -> void:
	if ended or gesture_index >= GESTURES.size():
		return
	var cue: Dictionary = GESTURES[gesture_index]
	var expires_at := _cue_times[gesture_index] + _timing_window() + float(cue.hold) + _hold_tolerance()
	if elapsed > expires_at:
		_held_action = ""
		_held_index = -1
		_register_miss("這一拍錯過了")

func _complete_gesture(timing_error: float, hold_error: float) -> void:
	if gesture_index >= GESTURES.size():
		return
	var cue: Dictionary = GESTURES[gesture_index]
	var precise := timing_error <= PRECISE_WINDOW and hold_error <= HOLD_TOLERANCE * 0.5
	correct_count += 1
	if precise:
		precise_count += 1
		last_grade = "精準"
		score += PERFECT_POINTS
		last_event = "踩中拍心，彩帶織出俐落弧線"
	else:
		last_grade = "合拍"
		score += GOOD_POINTS
		last_event = "動作合拍，彩帶接上下一道弧線"
	if bool(cue.strong):
		score += STRONG_BONUS
		last_event += "｜重拍落點"
	_trail.append({"index": gesture_index, "ribbon": str(cue.ribbon), "grade": last_grade, "strong": bool(cue.strong)})
	if _errors_for_gesture.has(gesture_index):
		# Earlier mistakes remain in the ledger and prevent devil qualification.
		pass
	gesture_index += 1
	_finish_if_complete()

func _register_miss(message: String) -> void:
	if gesture_index >= GESTURES.size():
		return
	missed_count += 1
	_register_error(message)
	last_grade = "失拍"
	gesture_index += 1
	_held_action = ""
	_held_index = -1
	_finish_if_complete()

func _register_error(message: String) -> void:
	error_count += 1
	_errors_for_gesture[gesture_index] = true
	last_grade = "失拍"
	last_event = message

func _finish_if_complete() -> void:
	if gesture_index < GESTURES.size():
		return
	ended = true
	phase = "complete"
	success = correct_count >= ORDINARY_SUCCESS_HITS
	devil_success = success and precise_count == GESTURES.size() and error_count == 0 and not assisted
	last_event = "八拍完成，舞台謝幕" if success else "八拍演出完成，再試一次把節奏接起來"
	if devil_success:
		last_event += "｜八拍全精準"

func _refresh_snapshot() -> void:
	var current: Dictionary = GESTURES[gesture_index].duplicate(true) if gesture_index < GESTURES.size() else {}
	var upcoming: Array[Dictionary] = []
	for offset in [1, 2]:
		var index := gesture_index + int(offset)
		if index < GESTURES.size():
			var cue := GESTURES[index].duplicate(true)
			cue["time"] = _cue_times[index]
			cue["index"] = index
			upcoming.append(cue)
	if not current.is_empty():
		current["time"] = _cue_times[gesture_index]
		current["index"] = gesture_index
	_snapshot_cache["assisted"] = assisted
	_snapshot_cache["time_phase"] = time_phase
	_snapshot_cache["phase"] = phase
	_snapshot_cache["elapsed"] = elapsed
	_snapshot_cache["gesture_index"] = gesture_index
	_snapshot_cache["gesture_count"] = GESTURES.size()
	_snapshot_cache["current_gesture"] = current
	_snapshot_cache["gestures"] = GESTURES
	_snapshot_cache["upcoming"] = upcoming
	_snapshot_cache["cue_times"] = _cue_times
	_snapshot_cache["timing_window"] = _timing_window()
	_snapshot_cache["precise_window"] = PRECISE_WINDOW
	_snapshot_cache["hold_action"] = _held_action
	_snapshot_cache["hold_elapsed"] = maxf(0.0, elapsed - _held_started_at) if not _held_action.is_empty() else 0.0
	_snapshot_cache["hold_required"] = float(current.get("hold", 0.0))
	_snapshot_cache["correct_count"] = correct_count
	_snapshot_cache["precise_count"] = precise_count
	_snapshot_cache["missed_count"] = missed_count
	_snapshot_cache["error_count"] = error_count
	_snapshot_cache["score"] = score
	_snapshot_cache["note_played_serial"] = note_played_serial
	_snapshot_cache["last_grade"] = last_grade
	_snapshot_cache["last_event"] = last_event
	_snapshot_cache["ribbon_trail"] = _trail
	_snapshot_cache["ended"] = ended
	_snapshot_cache["success"] = success
	_snapshot_cache["devil_success"] = devil_success
	_snapshot_cache["ordinary_success_hits"] = ORDINARY_SUCCESS_HITS
	_snapshot_cache["strong_beats"] = [0, 3, 5, 7]
