extends SceneTree

const RibbonModel = preload("res://game/minigames/ribbon_rhythm_model.gd")
const Groove = preload("res://game/minigames/ribbon_groove.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_stable_authored_phrase_and_cache()
	_test_early_wrong_and_spam_do_not_advance()
	_test_short_hold_fails_and_retry_is_deterministic()
	_test_perfect_eight_requires_real_inputs_and_earns_devil()
	_test_six_of_eight_is_ordinary_success()
	_test_assist_widens_timing_but_never_plays_for_the_player()
	_test_idle_and_bounded_clock()
	_test_groove_is_built_from_the_same_beat_chart()
	_test_published_rules_and_qualification_text()
	if failures > 0:
		push_error("FAIL: ribbon rhythm model (%d/%d checks failed)" % [failures, checks])
		quit(1)
		return
	print("PASS: ribbon rhythm model (%d checks)" % checks)
	quit(0)

func _test_stable_authored_phrase_and_cache() -> void:
	var model = RibbonModel.new()
	model.reset(false, "dusk")
	var initial: Dictionary = model.snapshot()
	_expect(initial.get("gestures", []).size() == 8, "the authored phrase contains eight distinct gesture entries")
	_expect(initial.get("upcoming", []).size() == 2, "the timeline previews two upcoming gestures")
	_expect(initial.get("time_phase") == "dusk", "valid lighting phase is retained")
	_expect(model.snapshot() == initial, "snapshot returns its stable cached state")
	var cue_times: Array = initial.get("cue_times", [])
	_expect(cue_times.size() == 8 and cue_times[0] < cue_times[1] and cue_times[7] > cue_times[0], "eight authored cues have finite ascending times")
	model.reset(false, "unknown")
	_expect(model.snapshot().get("time_phase") == "noon", "unknown lighting phase uses the safe default")

func _test_early_wrong_and_spam_do_not_advance() -> void:
	var model = RibbonModel.new()
	model.reset()
	var first: Dictionary = model.snapshot().gestures[0]
	var expected := str(first.action)
	var wrong := "jump" if expected != "jump" else "left"
	model.press_action(wrong)
	_expect(int(model.snapshot().get("gesture_index", -1)) == 0, "a wrong action never advances the sequence")
	var errors_after_wrong := int(model.snapshot().get("error_count", 0))
	model.press_action(expected)
	var errors_after_early := int(model.snapshot().get("error_count", 0))
	_expect(errors_after_early > errors_after_wrong, "the correct action before its timing window is recorded as early")
	model.press_action(expected)
	_expect(int(model.snapshot().get("error_count", 0)) == errors_after_early, "repeated held-key spam is ignored")
	_expect(int(model.snapshot().get("score", 0)) == 0, "wrong and premature input cannot award points")

func _test_short_hold_fails_and_retry_is_deterministic() -> void:
	var model = RibbonModel.new()
	model.reset()
	var initial_times: Array = model.snapshot().get("cue_times", []).duplicate()
	var held_index := _first_held_index(model.snapshot())
	_expect(held_index >= 0, "the authored phrase contains sustained ribbon gestures")
	if held_index < 0:
		return
	_advance_to_gesture(model, held_index)
	var cue: Dictionary = model.snapshot().gestures[held_index]
	_advance(model, float(model.snapshot().cue_times[held_index]) - float(model.snapshot().elapsed))
	model.press_action(str(cue.action))
	model.release_action(str(cue.action))
	_expect(int(model.snapshot().get("gesture_index", -1)) == held_index + 1, "releasing a held gesture too soon consumes that beat as a miss")
	_expect(int(model.snapshot().get("error_count", 0)) == 1, "a short ribbon hold is counted as an error")
	model.retry()
	_expect(int(model.snapshot().get("gesture_index", -1)) == 0 and int(model.snapshot().get("error_count", -1)) == 0, "retry resets progress and score state")
	_expect(model.snapshot().get("cue_times") == initial_times, "retry keeps the same authored phrase schedule")

func _test_perfect_eight_requires_real_inputs_and_earns_devil() -> void:
	var model = RibbonModel.new()
	model.reset(false, "night")
	var initial_times: Array = model.snapshot().get("cue_times", []).duplicate()
	for index in range(8):
		var state: Dictionary = model.snapshot()
		var cue: Dictionary = state.gestures[index]
		_advance(model, maxf(0.0, float(state.cue_times[index]) - float(state.elapsed)))
		model.press_action(str(cue.action))
		if float(cue.hold) > 0.0:
			_advance(model, float(cue.hold))
			model.release_action(str(cue.action))
		_expect(int(model.snapshot().get("gesture_index", -1)) == index + 1, "gesture %d advances only after its input" % index)
	var completed: Dictionary = model.snapshot()
	_expect(bool(completed.get("ended", false)) and bool(completed.get("success", false)), "all eight correct timed gestures complete the ordinary round")
	_expect(int(completed.get("correct_count", 0)) == 8 and int(completed.get("precise_count", 0)) == 8, "perfect phrase records eight precise hits")
	_expect(bool(completed.get("devil_success", false)), "eight precise strong-beat hits without assistance qualify for devil success")
	_expect(int(completed.get("score", 0)) > 0, "completed gestures earn score")
	_expect(int(completed.get("note_played_serial", 0)) == 8, "each beat emits one sound-cue serial")
	model.step(1.0)
	_expect(model.snapshot() == completed, "a finished round remains stable")

func _test_assist_widens_timing_but_never_plays_for_the_player() -> void:
	var model = RibbonModel.new()
	model.reset(true)
	_advance(model, 60.0)
	_expect(int(model.snapshot().get("correct_count", 0)) == 0, "assistance never auto-plays gestures")
	_expect(bool(model.snapshot().get("ended", false)) and not bool(model.snapshot().get("success", false)), "idle time can only end as a failed assisted round")
	model.reset(true)
	var first: Dictionary = model.snapshot().gestures[0]
	var delayed := float(model.snapshot().cue_times[0]) + 0.30
	_advance(model, delayed - float(model.snapshot().elapsed))
	model.press_action(str(first.action))
	_expect(int(model.snapshot().get("correct_count", 0)) == 1, "assisted timing accepts a still-active correct input inside its wider window")
	_expect(not bool(model.snapshot().get("devil_success", false)), "assisted success is never devil-qualified")
	for index in range(1, 8):
		var state: Dictionary = model.snapshot()
		var cue: Dictionary = state.gestures[index]
		_advance(model, maxf(0.0, float(state.cue_times[index]) + 0.30 - float(state.elapsed)))
		model.press_action(str(cue.action))
		if float(cue.hold) > 0.0:
			_advance(model, float(cue.hold))
			model.release_action(str(cue.action))
	_expect(bool(model.snapshot().get("success", false)) and int(model.snapshot().get("correct_count", 0)) == 8, "assistance still requires all eight real button actions to succeed")
	_expect(not bool(model.snapshot().get("devil_success", false)), "an assisted perfect round remains ineligible for devil success")

func _test_six_of_eight_is_ordinary_success() -> void:
	var model = RibbonModel.new()
	model.reset()
	for index in range(6):
		var state: Dictionary = model.snapshot()
		var cue: Dictionary = state.gestures[index]
		_advance(model, maxf(0.0, float(state.cue_times[index]) - float(state.elapsed)))
		model.press_action(str(cue.action))
		if float(cue.hold) > 0.0:
			_advance(model, float(cue.hold))
			model.release_action(str(cue.action))
	while not bool(model.snapshot().get("ended", false)):
		_advance(model, 0.20)
	_expect(int(model.snapshot().get("correct_count", 0)) == 6, "ordinary success threshold is exactly six correct gestures")
	_expect(bool(model.snapshot().get("success", false)), "six correct gestures out of eight complete the ordinary round")
	_expect(not bool(model.snapshot().get("devil_success", false)), "ordinary six-hit success does not meet the devil condition")

func _test_idle_and_bounded_clock() -> void:
	var model = RibbonModel.new()
	model.reset()
	model.step(60.0)
	_expect(float(model.snapshot().get("elapsed", 0.0)) <= 0.25, "one frame's clock advance is bounded")
	_expect(int(model.snapshot().get("correct_count", 0)) == 0 and int(model.snapshot().get("score", 0)) == 0, "idle time earns nothing")
	_advance(model, 60.0)
	_expect(not bool(model.snapshot().get("success", false)), "idle time never awards an ordinary win")
	model.step(NAN)
	_expect(is_finite(float(model.snapshot().get("elapsed", NAN))), "invalid clock input never poisons the model")

func _advance_to_gesture(model: RefCounted, target_index: int) -> void:
	for index in range(target_index):
		var state: Dictionary = model.snapshot()
		var cue: Dictionary = state.gestures[index]
		_advance(model, float(state.cue_times[index]) - float(state.elapsed))
		model.press_action(str(cue.action))
		if float(cue.hold) > 0.0:
			_advance(model, float(cue.hold))
			model.release_action(str(cue.action))

func _advance(model: RefCounted, seconds: float) -> void:
	var remaining := maxf(0.0, seconds)
	while remaining > 0.000001:
		var delta := minf(remaining, 0.20)
		model.step(delta)
		remaining -= delta

func _first_held_index(state: Dictionary) -> int:
	for index in range(state.get("gestures", []).size()):
		if float(state.gestures[index].hold) > 0.0:
			return index
	return -1

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _test_groove_is_built_from_the_same_beat_chart() -> void:
	var clicks: Array[float] = Groove.count_in_times()
	var gestures: Array[float] = Groove.gesture_times()
	var model = RibbonModel.new()
	model.reset()
	var cues: Array = model.snapshot().cue_times
	var aligned := gestures.size() == cues.size()
	for index in mini(gestures.size(), cues.size()):
		aligned = aligned and is_equal_approx(gestures[index] - Groove.preroll_seconds(), float(cues[index]))
	_expect(aligned, "every groove gesture sits exactly on its rule cue after the count-in")
	_expect(clicks.size() == 3 and is_equal_approx(clicks[2] + RibbonModel.BEAT_INTERVAL, gestures[0]) and is_equal_approx(clicks[1] - clicks[0], RibbonModel.BEAT_INTERVAL), "three count-in clicks keep the same tempo up to the first gesture")
	var stream: AudioStreamWAV = Groove.groove_stream()
	_expect(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo and stream.mix_rate == Groove.RATE, "the groove is a 16-bit mono stream at the declared rate")
	var samples := stream.data.size() / 2
	_expect(samples >= int(Groove.total_seconds() * Groove.RATE) - 1, "the groove covers the count-in, eight beats and the finale")
	_expect(Groove.groove_stream() == stream, "the synthesized groove is cached instead of re-rendered per round")
	# Onset check: each scheduled hit starts a burst louder than the quiet just before it.
	var onsets_ok := true
	var all_times: Array[float] = []
	all_times.append_array(clicks)
	all_times.append_array(gestures)
	for at in all_times:
		var before := _rms(stream.data, at - 0.06, at - 0.01)
		var after := _rms(stream.data, at, at + 0.05)
		onsets_ok = onsets_ok and after > before * 1.8 and after > 0.02
	_expect(onsets_ok, "the audible attack of every count-in click and gesture note lands on its scheduled time")
	var player_less = Groove.new()
	_expect(player_less.audio_time() == -1.0, "a groove that is not playing reports no audio clock")
	player_less.free()

func _rms(data: PackedByteArray, from_seconds: float, to_seconds: float) -> float:
	var first := clampi(int(from_seconds * Groove.RATE), 0, data.size() / 2)
	var last := clampi(int(to_seconds * Groove.RATE), 0, data.size() / 2)
	if last <= first:
		return 0.0
	var total := 0.0
	for i in range(first, last):
		var value := float(data.decode_s16(i * 2)) / 32768.0
		total += value * value
	return sqrt(total / float(last - first))

func _test_published_rules_and_qualification_text() -> void:
	var rule := RibbonModel.score_rule_text()
	_expect(rule.contains("+%d" % RibbonModel.PERFECT_POINTS) and rule.contains("±%d" % roundi(RibbonModel.PRECISE_WINDOW * 1000.0)) and rule.contains("+%d" % RibbonModel.STRONG_BONUS), "the shown rule text comes from the scoring constants")
	_expect(RibbonModel.qualification_text({"success": false, "correct_count": 4}).contains("本次 4 拍"), "a failed result states its real hit count")
	_expect(RibbonModel.qualification_text({"success": true, "assisted": true, "correct_count": 8}).contains("輔助回合不取得"), "an assisted success explains why no devil print")
	_expect(RibbonModel.qualification_text({"success": true, "correct_count": 7, "precise_count": 6, "missed_count": 1, "error_count": 2}).contains("漏拍 1、錯按 1"), "an ordinary result separates misses from wrong presses")
