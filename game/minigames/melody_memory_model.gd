extends RefCounted
class_name MelodyMemoryModel

## Three fixed, finite seaside phrases. Their pitches and rhythms are authored,
## not generated, so a repeat always means the same thing on every retry.
const PHRASES: Array[Array] = [
	[0, 2, 1],
	[3, 1, 0, 2, 1],
	[2, 2, 0, 3, 1, 0, 2],
]
## Seconds between note starts, including short and held notes.
const RHYTHMS: Array[Array] = [
	[0.0, 0.50, 0.88],
	[0.0, 0.86, 0.43, 0.43, 0.86],
	[0.0, 0.43, 0.86, 0.43, 0.86, 0.43, 0.43],
]
const MAX_DELTA := 0.25
const MAX_SLICE := 0.025
const FIRST_NOTE_DELAY := 0.55
const LISTEN_TAIL := 0.68
const READY_PAUSE := 1.15
const WRONG_PAUSE := 0.65
const REPLAY_LIMIT := 2
const PRECISE_WINDOW := 0.22
const ACCEPT_WINDOW := 0.70
const ASSISTED_ACCEPT_WINDOW := 1.00
const MIN_INPUT_INTERVAL := 0.12
const PHRASE_COUNT := 3
const PRECISE_SCORE := 20
const CLOSE_SCORE := 12
## After phrases 1 and 2 the stage plays the finished phrase back once as a full
## ensemble before the next demonstration; the final phrase's encore is staged
## by the Session before the result so the model can settle immediately.
const ENCORE_DELAY := 0.35
const ENCORE_TAIL := 0.75

var assisted := false
var time_phase := "noon"
var phase := "listen"
var phrase_index := 0
var input_index := 0
var replay_count := 0
var completed_phrases := 0
var error_count := 0
var precise_notes := 0
var score := 0
var elapsed := 0.0
var phase_elapsed := 0.0
var cue_index := -1
var note_start_serial := 0
var current_cue := -1
var last_event := ""
var ended := false
var success := false
var devil_success := false
var _phrase_precise := true
var _input_clock := 0.0
var _last_input_time := 0.0
var _expected_input_time := 0.0
var _has_input_anchor := false
var _listen_index := 0
var _next_note_time := FIRST_NOTE_DELAY
var _pending_return_to_active := false
var _heard_notes: Array[int] = []
var _replays: Array[int] = []
var _snapshot_cache: Dictionary = {}
var _encore_phrase := -1
var _encore_index := 0
var _next_encore_time := 0.0
## Phrase that earned the most recent note score (for per-phrase result rows).
var last_scored_phrase := -1
## Grade of the latest played note: "precise", "close", "off_time" or "wrong".
var last_note_grade := ""

func reset(p_assisted: bool = false, p_time_phase: String = "noon") -> void:
	assisted = p_assisted
	time_phase = p_time_phase if p_time_phase in ["dawn", "noon", "dusk", "night"] else "noon"
	phase = "listen"
	phrase_index = 0
	input_index = 0
	replay_count = 0
	completed_phrases = 0
	error_count = 0
	precise_notes = 0
	score = 0
	elapsed = 0.0
	phase_elapsed = 0.0
	cue_index = -1
	note_start_serial = 0
	current_cue = -1
	last_event = "聽第一句海邊樂譜"
	ended = false
	success = false
	devil_success = false
	_phrase_precise = true
	_input_clock = 0.0
	_last_input_time = 0.0
	_expected_input_time = 0.0
	_has_input_anchor = false
	_listen_index = 0
	_next_note_time = FIRST_NOTE_DELAY
	_pending_return_to_active = false
	_encore_phrase = -1
	_encore_index = 0
	_next_encore_time = 0.0
	last_scored_phrase = -1
	last_note_grade = ""
	_heard_notes.clear()
	_replays.clear()
	for _phrase in PHRASE_COUNT:
		_replays.append(0)
	_snapshot_cache.clear()
	_refresh_snapshot()

func set_time_phase(p_time_phase: String) -> Dictionary:
	time_phase = p_time_phase if p_time_phase in ["dawn", "noon", "dusk", "night"] else "noon"
	_refresh_snapshot()
	return snapshot()

func step(delta: float) -> Dictionary:
	if ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_DELTA)
	while remaining > 0.000001 and not ended:
		var dt := minf(remaining, MAX_SLICE)
		remaining -= dt
		_step_slice(dt)
	_refresh_snapshot()
	return snapshot()

func play_note(index: int) -> Dictionary:
	if ended or phase != "active" or index < 0 or index > 3:
		return snapshot()
	if _has_input_anchor and _input_clock - _last_input_time < MIN_INPUT_INTERVAL:
		return snapshot()
	var expected: int = PHRASES[phrase_index][input_index]
	current_cue = index
	cue_index = index
	note_start_serial += 1
	var timing_error := absf(_input_clock - _expected_input_time)
	var timing_window := ASSISTED_ACCEPT_WINDOW if assisted else ACCEPT_WINDOW
	var late := _input_clock > _expected_input_time + timing_window
	var early := _input_clock < _expected_input_time - timing_window
	var correct := index == expected
	last_scored_phrase = phrase_index
	last_note_grade = "wrong" if not correct else ("off_time" if late or early else ("precise" if timing_error <= PRECISE_WINDOW else "close"))
	if not correct:
		_register_error("音符錯了，樂句從頭再聽一次")
		_begin_listen(WRONG_PAUSE, false)
	elif late or early:
		_register_error("節奏偏早／偏晚，音符正確，繼續演奏")
		_advance_input(false)
	elif timing_error <= PRECISE_WINDOW:
		precise_notes += 1
		score += PRECISE_SCORE
		last_event = "音高與節奏都準確"
		_advance_input(true)
	else:
		_phrase_precise = false
		score += CLOSE_SCORE
		last_event = "音高正確，節奏接近"
		_advance_input(false)
	_refresh_snapshot()
	return snapshot()

static func score_rule_text() -> String:
	return "音高與節奏準確 +%d，節奏接近 +%d；錯音或節奏超出容許範圍不加分。" % [PRECISE_SCORE, CLOSE_SCORE]

## Ordinary/devil eligibility of a finished formal round with its real counts.
static func qualification_text(state: Dictionary) -> String:
	var total := int(state.get("total_notes", 0))
	var precise := int(state.get("precise_notes", 0))
	var errors := int(state.get("error_count", 0))
	if not bool(state.get("success", false)):
		return "普通拍貼需完成三句（本次 %d / 3）。" % int(state.get("completed_phrases", 0))
	if bool(state.get("assisted", false)):
		return "三句合奏完成，取得普通拍貼；輔助回合不取得小惡魔拍貼。"
	if bool(state.get("devil_success", false)):
		return "三句全對、零失誤且每音都踩準拍點，已達成小惡魔條件。"
	return "三句合奏完成，取得普通拍貼。小惡魔需零失誤且每音踩準（本次精準 %d / %d、失誤 %d）。" % [precise, total, errors]

func replay_phrase() -> Dictionary:
	if ended or phase != "active" or replay_count >= REPLAY_LIMIT:
		return snapshot()
	replay_count += 1
	_replays[phrase_index] = replay_count
	input_index = 0
	_has_input_anchor = false
	_phrase_precise = true
	last_event = "重聽第 %d 句（%d/%d）" % [phrase_index + 1, replay_count, REPLAY_LIMIT]
	_begin_listen(0.25, true)
	_refresh_snapshot()
	return snapshot()

func snapshot() -> Dictionary:
	return _snapshot_cache

func _step_slice(dt: float) -> void:
	elapsed += dt
	phase_elapsed += dt
	if phase == "listen":
		if _listen_index < PHRASES[phrase_index].size() and phase_elapsed >= _next_note_time:
			var notes: Array = PHRASES[phrase_index]
			var rhythm: Array = RHYTHMS[phrase_index]
			current_cue = int(notes[_listen_index])
			cue_index = current_cue
			note_start_serial += 1
			_heard_notes.append(current_cue)
			_listen_index += 1
			if _listen_index < notes.size():
				_next_note_time += float(rhythm[_listen_index])
			else:
				_next_note_time += LISTEN_TAIL
		elif _listen_index >= PHRASES[phrase_index].size() and phase_elapsed >= _next_note_time:
			phase = "ready"
			phase_elapsed = 0.0
			current_cue = -1
			cue_index = -1
			_heard_notes.clear()
			last_event = "換你照著節奏演奏"
	elif phase == "ready" and phase_elapsed >= READY_PAUSE:
		phase = "active"
		phase_elapsed = 0.0
		_input_clock = 0.0
		_expected_input_time = 0.0
		input_index = 0
		_has_input_anchor = false
		last_event = "第 %d 句：開始" % (phrase_index + 1)
	elif phase == "wrong_pause" and phase_elapsed >= WRONG_PAUSE:
		phase = "listen"
		phase_elapsed = 0.0
		_listen_index = 0
		_next_note_time = FIRST_NOTE_DELAY
		_heard_notes.clear()
		current_cue = -1
		cue_index = -1
	elif phase == "active":
		_input_clock += dt
	elif phase == "encore":
		var encore_notes: Array = PHRASES[_encore_phrase]
		if _encore_index < encore_notes.size() and phase_elapsed >= _next_encore_time:
			current_cue = int(encore_notes[_encore_index])
			cue_index = current_cue
			note_start_serial += 1
			_heard_notes.append(current_cue)
			_encore_index += 1
			_next_encore_time += float(RHYTHMS[_encore_phrase][_encore_index]) if _encore_index < encore_notes.size() else ENCORE_TAIL
		elif _encore_index >= encore_notes.size() and phase_elapsed >= _next_encore_time:
			_begin_next_phrase()

func _advance_input(precise: bool) -> void:
	if not precise:
		_phrase_precise = false
	_has_input_anchor = true
	_last_input_time = _input_clock
	input_index += 1
	if input_index < PHRASES[phrase_index].size():
		_expected_input_time = _last_input_time + float(RHYTHMS[phrase_index][input_index])
	if input_index >= PHRASES[phrase_index].size():
		completed_phrases += 1
		last_event = "第 %d 句完成" % (phrase_index + 1)
		if _phrase_precise:
			last_event += "：精準演奏"
		phrase_index += 1
		if phrase_index >= PHRASE_COUNT:
			ended = true
			success = completed_phrases == PHRASE_COUNT
			devil_success = success and error_count == 0 and not assisted and precise_notes == _total_notes()
			phase = "complete"
			last_event = "三句合奏完成" if success else "合奏未完成"
			if devil_success:
				last_event += "：零失誤精準演奏"
		else:
			# Ensemble encore of the phrase just completed, then the next demonstration.
			phase = "encore"
			_encore_phrase = phrase_index - 1
			_encore_index = 0
			_next_encore_time = ENCORE_DELAY
			phase_elapsed = 0.0
			_heard_notes.clear()
			current_cue = -1
			cue_index = -1

func _begin_next_phrase() -> void:
	phase = "listen"
	_encore_phrase = -1
	input_index = 0
	replay_count = 0
	_replays[phrase_index] = 0
	_phrase_precise = true
	_listen_index = 0
	_next_note_time = FIRST_NOTE_DELAY
	phase_elapsed = 0.0
	_input_clock = 0.0
	_expected_input_time = 0.0
	_has_input_anchor = false
	_heard_notes.clear()
	current_cue = -1
	cue_index = -1

func _register_error(message: String) -> void:
	error_count += 1
	_phrase_precise = false
	last_event = message

func _begin_listen(delay: float, is_manual_replay: bool) -> void:
	phase = "listen"
	phase_elapsed = 0.0
	_listen_index = 0
	_next_note_time = delay
	input_index = 0
	_heard_notes.clear()
	current_cue = -1
	cue_index = -1
	_input_clock = 0.0
	_expected_input_time = 0.0
	_has_input_anchor = false
	if not is_manual_replay:
		phase = "wrong_pause"
		phase_elapsed = 0.0

func _total_notes() -> int:
	var total := 0
	for phrase: Array in PHRASES:
		total += phrase.size()
	return total

func _refresh_snapshot() -> void:
	_snapshot_cache["assisted"] = assisted
	_snapshot_cache["time_phase"] = time_phase
	_snapshot_cache["phase"] = phase
	_snapshot_cache["phrase_index"] = phrase_index
	_snapshot_cache["phrase_number"] = mini(phrase_index + 1, PHRASE_COUNT)
	_snapshot_cache["phrase_count"] = PHRASE_COUNT
	_snapshot_cache["input_index"] = input_index
	_snapshot_cache["phrase_length"] = PHRASES[mini(phrase_index, PHRASE_COUNT - 1)].size()
	_snapshot_cache["replay_count"] = replay_count
	_snapshot_cache["replay_limit"] = REPLAY_LIMIT
	_snapshot_cache["replays"] = _replays
	_snapshot_cache["completed_phrases"] = completed_phrases
	_snapshot_cache["error_count"] = error_count
	_snapshot_cache["precise_notes"] = precise_notes
	_snapshot_cache["total_notes"] = _total_notes()
	_snapshot_cache["score"] = score
	_snapshot_cache["elapsed"] = elapsed
	_snapshot_cache["phase_elapsed"] = phase_elapsed
	_snapshot_cache["cue_index"] = cue_index
	_snapshot_cache["current_cue"] = current_cue
	_snapshot_cache["note_start_serial"] = note_start_serial
	_snapshot_cache["heard_notes"] = _heard_notes
	_snapshot_cache["rhythm"] = RHYTHMS[mini(phrase_index, PHRASE_COUNT - 1)] if phase == "listen" else (RHYTHMS[_encore_phrase] if phase == "encore" and _encore_phrase >= 0 else [])
	_snapshot_cache["last_event"] = last_event
	_snapshot_cache["ended"] = ended
	_snapshot_cache["success"] = success
	_snapshot_cache["devil_success"] = devil_success
	_snapshot_cache["timing_window"] = ASSISTED_ACCEPT_WINDOW if assisted else ACCEPT_WINDOW
	_snapshot_cache["precise_window"] = PRECISE_WINDOW
	_snapshot_cache["replay_available"] = phase == "active" and replay_count < REPLAY_LIMIT
	_snapshot_cache["encore_phrase"] = _encore_phrase
	_snapshot_cache["last_scored_phrase"] = last_scored_phrase
	_snapshot_cache["last_note_grade"] = last_note_grade
