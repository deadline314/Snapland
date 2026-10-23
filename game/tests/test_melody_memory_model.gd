extends SceneTree

const Model = preload("res://game/minigames/melody_memory_model.gd")
const Voices = preload("res://game/minigames/melody_voices.gd")
const Session = preload("res://game/minigames/session.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_finite_playback_and_cache()
	_test_clean_precise_route()
	_test_wrong_note_retry_and_timing_grade()
	_test_replay_cap_and_assist_policy()
	_test_rapid_chord_is_ignored()
	_test_encore_voices_and_qualification()
	_test_reported_score_grades()
	if failures == 0:
		print("Melody memory model: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Melody memory model: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_finite_playback_and_cache() -> void:
	var model = Model.new()
	model.reset(false, "dusk")
	var first := model.snapshot()
	_expect(is_same(first, model.snapshot()), "snapshot returns one stable cached dictionary")
	_expect(first.phase == "listen" and first.time_phase == "dusk" and first.phrase_count == 3, "reset begins the first authored phrase and keeps the requested time palette")
	model.set_time_phase("night")
	_expect(first.time_phase == "night" and is_same(first, model.snapshot()), "live time-of-day changes refresh the same cached snapshot without resetting the phrase")
	var serial := int(first.note_start_serial)
	_advance(model, 0.70)
	_expect(model.snapshot().note_start_serial == serial + 1 and model.snapshot().current_cue == Model.PHRASES[0][0], "first note starts with an incremented one-shot cue serial")
	_advance(model, 20.0)
	_expect(model.snapshot().phase == "active" and not model.snapshot().success and model.snapshot().completed_phrases == 0, "hearing every finite note and waiting never grants an unattended win")
	_expect(model.snapshot().heard_notes.is_empty(), "answer markers are cleared before the active attempt")

func _test_clean_precise_route() -> void:
	var model = Model.new()
	model.reset()
	for phrase_index in range(Model.PHRASES.size()):
		_expect(_wait_active(model), "each phrase reaches an active attempt after its listen and read pause")
		_play_phrase(model, phrase_index, false)
	_expect(model.ended and model.success and model.completed_phrases == 3, "three complete phrases earn ordinary success")
	_expect(model.devil_success and model.error_count == 0 and model.precise_notes == model.snapshot().total_notes, "only a clean precise unassisted full run earns the devil result: %s" % str(model.snapshot()))
	_expect(model.score == model.snapshot().total_notes * 20, "score rewards every accurately timed note consistently: %d / %d" % [model.score, model.snapshot().total_notes * 20])

func _test_reported_score_grades() -> void:
	var model = Model.new()
	model.reset()
	_expect(_wait_active(model), "score explanation witness reaches real active input")
	model.play_note(Model.PHRASES[0][0])
	var precise_delta: int = model.score
	_advance(model, float(Model.RHYTHMS[0][1]) + 0.35)
	model.play_note(Model.PHRASES[0][1])
	var close_delta: int = model.score - precise_delta
	_expect(precise_delta == 20 and close_delta == 12 and model.error_count == 0, "actual precise and close note inputs retain the published scoring")
	var session := Session.new()
	session.mode = "melody_memory"
	session.score = model.score
	var summary: Dictionary = session.score_summary()
	var numbers := RegEx.new()
	numbers.compile("\\+(\\d+)")
	var advertised := numbers.search_all(str(summary.rule))
	_expect(advertised.size() == 2, "result advertises exactly the two actual scoring grades without an invented phrase bonus")
	if advertised.size() == 2:
		_expect(int(advertised[0].get_string(1)) == precise_delta and int(advertised[1].get_string(1)) == close_delta and int(summary.total) == model.score, "result explanation and total agree with scores earned by actual note input")
	session.free()

func _test_wrong_note_retry_and_timing_grade() -> void:
	var model = Model.new()
	model.reset()
	_expect(_wait_active(model), "first phrase becomes playable")
	var expected := int(Model.PHRASES[0][0])
	model.play_note((expected + 1) % 4)
	_expect(model.error_count == 1 and model.snapshot().phase == "wrong_pause" and model.completed_phrases == 0, "wrong instrument is explained and cannot complete a phrase")
	model.play_note(expected)
	_expect(model.snapshot().input_index == 0, "notes during the retry pause are ignored")
	_advance(model, 0.8)
	_expect(model.snapshot().phase == "listen", "a mistake causes the whole same phrase to be heard again")
	_expect(_wait_active(model), "the retry phrase returns to active play only after its read pause")
	_play_phrase(model, 0, true)
	for phrase_index in [1, 2]:
		_expect(_wait_active(model), "next authored phrase reaches active play")
		_play_phrase(model, phrase_index, false)
	_expect(model.success and model.error_count >= 2, "correct pitches with a late first note still allow ordinary completion")
	_expect(not model.devil_success and model.precise_notes < model.snapshot().total_notes, "mistakes and late notes disqualify perfect-run status")

func _test_replay_cap_and_assist_policy() -> void:
	var assisted := Model.new()
	assisted.reset(true, "night")
	_expect(_wait_active(assisted), "assisted phrase reaches the same learn-then-play sequence")
	_expect(assisted.snapshot().timing_window > Model.ACCEPT_WINDOW, "assistance broadens the forgiving timing window without changing the phrase")
	for _replay in Model.REPLAY_LIMIT:
		assisted.replay_phrase()
		_expect(assisted.snapshot().phase == "listen" and assisted.snapshot().replay_count <= Model.REPLAY_LIMIT, "each permitted replay restarts the phrase before an attempt")
		_expect(_wait_active(assisted), "manual replay returns to active play after its pause")
	var serial := int(assisted.snapshot().note_start_serial)
	assisted.replay_phrase()
	_expect(assisted.snapshot().phase == "active" and assisted.snapshot().note_start_serial == serial, "replay limit is enforced without emitting a phantom note")
	for phrase_index in range(Model.PHRASES.size()):
		if phrase_index > 0:
			_expect(_wait_active(assisted), "assisted next phrase uses the same phase flow")
		_play_phrase(assisted, phrase_index, false)
	_expect(assisted.success and not assisted.devil_success, "assistance preserves ordinary completion and blocks the perfect-run distinction")
	_expect(assisted.snapshot().replays[0] == Model.REPLAY_LIMIT, "per-phrase replay counters remain available in the final snapshot")

func _test_rapid_chord_is_ignored() -> void:
	var model = Model.new()
	model.reset()
	_expect(_wait_active(model), "chord guard test reaches the first active phrase")
	model.play_note(int(Model.PHRASES[0][0]))
	var serial := int(model.snapshot().note_start_serial)
	model.play_note((int(Model.PHRASES[0][1]) + 1) % 4)
	_expect(model.snapshot().input_index == 1 and model.error_count == 0, "a second same-frame key is ignored instead of becoming a chord or false mistake")
	_expect(model.snapshot().note_start_serial == serial, "ignored chord does not create a second sound event")

func _test_encore_voices_and_qualification() -> void:
	var model = Model.new()
	model.reset()
	_expect(_wait_active(model), "encore witness reaches the first active phrase")
	_play_phrase(model, 0, false)
	_expect(model.snapshot().phase == "encore" and model.completed_phrases == 1, "a completed phrase is first played back as an ensemble encore")
	var serial := int(model.snapshot().note_start_serial)
	var heard: Array = []
	var guard := 0
	while model.snapshot().phase == "encore" and guard < 400:
		model.step(0.025)
		if int(model.snapshot().note_start_serial) > serial:
			serial = int(model.snapshot().note_start_serial)
			heard.append(int(model.snapshot().current_cue))
		guard += 1
	_expect(heard == Model.PHRASES[0] and model.snapshot().phase == "listen" and int(model.snapshot().phrase_index) == 1, "the encore replays exactly the finished phrase, then the next demonstration begins")
	var voices: Array = Voices.voice_streams()
	_expect(voices.size() == 4 and Voices.voice_streams() == voices and voices.all(func(stream: AudioStreamWAV) -> bool: return stream.data.size() > 4000), "four distinct cached instrument voices are synthesized")
	_expect(Model.qualification_text({"success": true, "total_notes": 15, "precise_notes": 12, "error_count": 1}).contains("精準 12 / 15、失誤 1"), "an ordinary result states real precision and error counts")
	_expect(Model.qualification_text({"success": true, "assisted": true}).contains("輔助回合不取得"), "an assisted result explains no devil print")

func _wait_active(model, limit: float = 18.0) -> bool:
	var elapsed := 0.0
	while model.snapshot().phase != "active" and elapsed < limit:
		model.step(0.025)
		elapsed += 0.025
	return model.snapshot().phase == "active"

func _advance(model, duration: float) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var delta := minf(remaining, 0.025)
		model.step(delta)
		remaining -= delta

func _play_phrase(model, phrase_index: int, late_first: bool) -> void:
	var notes: Array = Model.PHRASES[phrase_index]
	var rhythm: Array = Model.RHYTHMS[phrase_index]
	if late_first:
		_advance(model, Model.ACCEPT_WINDOW + 0.2)
		model.play_note(int(notes[0]))
	else:
		model.play_note(int(notes[0]))
	for note_index in range(1, notes.size()):
		_advance(model, float(rhythm[note_index]))
		model.play_note(int(notes[note_index]))
