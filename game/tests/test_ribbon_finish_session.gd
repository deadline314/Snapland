extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const RibbonView = preload("res://game/minigames/ribbon_rhythm_view.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Ribbon Session lifecycle test requires isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	_test_success_gate()
	_test_failure_is_immediate()
	_test_retry_cancels_gate()
	_test_pause_freezes_remaining_and_resumes()
	_test_leave_cancels_gate()
	_test_reduced_motion_static_finish()
	if failures > 0:
		push_error("FAIL: Ribbon Session lifecycle (%d checks, %d failures)" % [checks, failures])
		quit(1)
		return
	print("PASS: Ribbon Session lifecycle (%d checks)" % checks)
	quit(0)

func _test_success_gate() -> void:
	var session := _new_session()
	var toast := session.minigame_hud.find_child("ContextFeedback", true, false) as Control
	if toast != null:
		session.minigame_hud.set_feedback_at("節拍狀態", Vector2(640, 230))
		var toast_label := toast.get_child(0) as Control if toast.get_child_count() > 0 else null
		print("HUD feedback diagnostic: rect=%s custom_min=%s combined_min=%s label_size=%s label_custom_min=%s" % [str(toast.get_rect()), str(toast.custom_minimum_size), str(toast.get_combined_minimum_size()), str(toast_label.size if toast_label != null else Vector2.ZERO), str(toast_label.custom_minimum_size if toast_label != null else Vector2.ZERO)])
	var results: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	_drive_success(session)
	var view := session.presentation as RibbonView
	_expect(bool(session.ribbon_model.snapshot().success), "actual eight inputs make the model successful")
	_expect(session.ribbon_finish_pending and not session.ended and results.is_empty(), "success is held for the short stage performance")
	_expect(view != null and view.companion_is_dancing(), "successful model snapshot starts the authored companion dance")
	_expect(session.score == session.ribbon_model.snapshot().score, "the gate does not alter model or awarded score")
	for _frame in range(12):
		session._process(0.1)
	_expect(not session.ended and results.is_empty(), "normal dance remains visible before its bounded duration")
	session._process(0.1)
	_expect(session.ended and results.size() == 1 and bool(results[0].success), "normal finish publishes the genuine result after the dance")
	session._process(0.5)
	_expect(results.size() == 1, "success emits only one result")
	session.queue_free()

func _test_failure_is_immediate() -> void:
	var session := _new_session()
	var results: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	var guard := 0
	while not bool(session.ribbon_model.snapshot().ended) and guard < 2000:
		session._process(0.01)
		guard += 1
	_expect(guard < 2000 and session.ended and results.size() == 1 and not bool(results[0].success), "failed round still settles immediately")
	_expect(not session.ribbon_finish_pending, "failure never opens a success gate")
	session.queue_free()

func _test_retry_cancels_gate() -> void:
	var session := _new_session()
	var results: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	_drive_success(session)
	session.reset_round()
	session.set_paused(false)
	_expect(not session.ribbon_finish_pending and not session.ended, "retry clears the gate")
	_expect(session.ribbon_model.snapshot().gesture_index == 0 and session.score == 0, "retry resets only through the real model/session reset path")
	session._process(0.5)
	_expect(results.is_empty() and not session.ended, "the canceled performance cannot publish a stale result")
	session.queue_free()

func _test_pause_freezes_remaining_and_resumes() -> void:
	var session := _new_session()
	var results: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	_drive_success(session)
	for _frame in range(4):
		session._process(0.1)
	var before_pause: float = float(session.ribbon_finish_elapsed)
	var view := session.presentation as RibbonView
	session.set_paused(true)
	_expect(session.ribbon_finish_pending and view != null and not view.is_processing(), "pause freezes the running dance timer and view")
	session._process(1.0)
	_expect(results.is_empty() and is_equal_approx(session.ribbon_finish_elapsed, before_pause), "paused session preserves the exact remaining gate duration")
	session.set_paused(false)
	_expect(session.ribbon_finish_pending and not session.ended and view.is_processing(), "resume continues the dance from the frozen point")
	var guard := 0
	while session.ribbon_finish_pending and guard < 40:
		session._process(0.1)
		guard += 1
	_expect(guard < 40 and session.ended and results.size() == 1 and bool(results[0].success) and is_equal_approx(session.ribbon_finish_elapsed, session.ribbon_finish_duration), "resume finishes the full remaining duration before publishing once")
	session.queue_free()

func _test_leave_cancels_gate() -> void:
	var session := _new_session()
	var results: Array[Dictionary] = []
	var canceled := [0]
	session.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	session.cancelled.connect(func() -> void: canceled[0] += 1)
	_drive_success(session)
	session._leave_from_hud()
	_expect(not session.ribbon_finish_pending, "leaving clears the performance gate")
	_expect(int(canceled[0]) == 1 and results.is_empty(), "leave emits cancellation without a false finish")
	session.queue_free()

func _test_reduced_motion_static_finish() -> void:
	var session := _new_session()
	session.reduced_motion = true
	var results: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	_drive_success(session)
	var view := session.presentation as RibbonView
	_expect(session.ribbon_finish_pending and is_equal_approx(session.ribbon_finish_duration, Session.RIBBON_REDUCED_FINISH_SECONDS), "reduced motion keeps a shorter static finish gate")
	_expect(view != null and view.companion_is_dancing() and view.companion_frame_index() == view.companion_dance_frame_count() - 1, "reduced motion presents a stable authored final pose")
	session._process(0.1)
	session._process(Session.RIBBON_REDUCED_FINISH_SECONDS - 0.1)
	_expect(results.size() == 1 and bool(results[0].success), "reduced motion still publishes the real successful result")
	session.queue_free()

func _new_session() -> Control:
	var session: Control = Session.new()
	root.add_child(session)
	session.start("game-006")
	return session

func _drive_success(session: Control) -> void:
	var gestures: Array = session.ribbon_model.GESTURES
	for index in gestures.size():
		var cue_time := 1.02 + float(index) * 0.94
		var guard := 0
		while float(session.ribbon_model.snapshot().elapsed) + 0.00001 < cue_time and guard < 1200:
			session._process(minf(0.02, cue_time - float(session.ribbon_model.snapshot().elapsed)))
			guard += 1
		_expect(guard < 1200, "route reaches each authored cue in bounded time")
		var action := str(gestures[index].action)
		session._on_ribbon_action_pressed(action)
		if float(gestures[index].hold) > 0.0:
			var hold_until := cue_time + float(gestures[index].hold)
			while float(session.ribbon_model.snapshot().elapsed) + 0.00001 < hold_until:
				session._process(minf(0.02, hold_until - float(session.ribbon_model.snapshot().elapsed)))
			session._on_ribbon_action_released(action)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + message)
