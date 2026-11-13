extends SceneTree

const Model = preload("res://game/minigames/shell_tide_model.gd")
const Route = preload("res://game/tests/shell_tide_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run(model, seconds: float, delta: float = 1.0 / 120.0) -> void:
	for i in roundi(seconds / delta):
		model.step(delta)

func until_phase(model, phase: String) -> void:
	for i in 4000:
		if model.snapshot().phase == phase: return
		model.step(1.0 / 120.0)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.phase == "demo" and state.phrase == 0 and not state.ended and not state.ordinary_eligible, "round opens on the first demo")
	for field in ["events", "window", "offset", "held", "passed", "judgement", "score_visible", "beat"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	var long_notes := 0
	var rests := 0
	for phrase: Array in Model.VARIANTS[0].phrases:
		for row: Array in phrase:
			if row[0] < 0: rests += 1
			elif row[1] > 1: long_notes += 1
	expect(long_notes >= 3 and rests >= 4, "phrases mix short notes, long notes and silences")
	expect(Model.VARIANTS[0].phrases[2].filter(func(row): return row[0] < 0).size() == 2, "the final phrase holds two silences")

	# Demo plays notes without judging; presses during the demo do nothing.
	model.press(0)
	model.release(0)
	run(model, 0.6)
	expect(Array(model.consume_notes()) == [0, 1], "the demo sounds its shells in order")
	expect(model.snapshot().hits == 0 and model.snapshot().wrong == 0, "presses during the demo are not judged")

	# Judgement: timing windows, silences and long-note holds.
	var judge = Model.new()
	until_phase(judge, "echo")
	var events: Array = judge.snapshot().events
	run(judge, events[0].start + 0.03)
	judge.press(events[0].shell)
	judge.release(events[0].shell)
	expect(judge.snapshot().hits == 1 and judge.snapshot().judgement.perfect, "a press on the beat is a perfect hit")
	run(judge, events[1].start - judge.snapshot().phase_time - 0.2)
	judge.press(events[1].shell)
	judge.release(events[1].shell)
	expect(judge.snapshot().hits == 1 and judge.snapshot().wrong == 1, "a press far too early is a miss")
	run(judge, events[2].start - judge.snapshot().phase_time + events[2].duration * 0.5)
	judge.press(3)
	judge.release(3)
	expect(judge.snapshot().rest_presses == 1 and judge.snapshot().judgement.rest, "tapping a silence counts as disturbing it")
	var hold = Model.new()
	hold.reset(false, 0)
	for i in 4000:
		if hold.snapshot().phase == "echo" and hold.snapshot().phrase == 1: break
		var s: Dictionary = hold.snapshot()
		if s.phase == "echo":
			for event: Dictionary in s.events:
				if event.shell >= 0 and not event.judged and s.phase_time >= event.start:
					hold.press(event.shell)
					hold.release(event.shell)
		hold.step(1.0 / 120.0)
	var long_event: Dictionary = hold.snapshot().events[1]
	expect(long_event.beats == 2, "the second phrase opens with a long note second")
	run(hold, long_event.start - hold.snapshot().phase_time)
	hold.press(long_event.shell)
	run(hold, long_event.duration * 0.3)
	hold.release(long_event.shell)
	expect(hold.snapshot().events[1].hit and not hold.snapshot().events[1].complete and hold.snapshot().feedback.contains("太早"), "releasing a long note early leaves it incomplete")

	# Full rounds.
	var clean = Route.ModelCommands.new()
	expect(Route.solve(clean), "all three phrases echoed")
	state = clean.snapshot()
	expect(state.success and state.devil and state.rest_presses == 0 and state.passed_count == 3 and state.ordinary_eligible, "untouched silences earn devil")
	var tapped = Route.ModelCommands.new()
	expect(Route.solve(tapped, false), "echo with one tapped silence")
	state = tapped.snapshot()
	expect(state.success and not state.devil and state.rest_presses == 1, "a disturbed silence keeps success but not devil")
	var slow = Route.ModelCommands.new()
	expect(Route.solve(slow, true, true), "waiting for the long wave")
	expect(slow.snapshot().score < clean.snapshot().score and slow.snapshot().short_passes == 0, "the long-wave choice is safer but scores less")
	var second = Route.ModelCommands.new(false, 1)
	expect(Route.solve(second) and second.snapshot().devil, "the second tempo and silences also work")
	expect(second.snapshot().beat != clean.snapshot().beat, "variants change the beat")

	# Waiting widens the window; assistance adds calibration and keeps the score visible.
	var wait = Model.new()
	until_phase(wait, "ready")
	var narrow: float = wait.snapshot().window
	wait.wait_long_wave()
	expect(wait.snapshot().slow and wait.snapshot().window > narrow and wait.snapshot().beat > narrow, "the long wave slows the beat and widens the window")
	var plain = Model.new()
	plain.calibrate(1)
	expect(plain.snapshot().offset == 0.0 and plain.snapshot().feedback.contains("輔助"), "calibration is assist-only")
	var helped = Model.new()
	helped.reset(true, 0)
	for i in 30: helped.calibrate(1)
	expect(is_equal_approx(helped.snapshot().offset, Model.MAX_OFFSET), "calibration is bounded")
	until_phase(helped, "echo")
	expect(helped.snapshot().score_visible, "assist keeps the ripple score during the echo")
	var hidden = Model.new()
	until_phase(hidden, "echo")
	expect(not hidden.snapshot().score_visible, "the ripple score hides while echoing unassisted")
	var assisted = Route.ModelCommands.new(true)
	expect(Route.solve(assisted) and assisted.snapshot().devil, "assisted devil remains eligible")

	# Failing a phrase twice moves on truthfully.
	var silent = Model.new()
	run(silent, Model.ROUND_SECONDS, 0.25)
	state = silent.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.passed == [false, false, false], "no response fails every phrase and ends truthfully")
	silent.press(0)
	expect(silent.snapshot().hits == 0, "ended round ignores input")
	var again = Route.ModelCommands.new()
	Route.solve(again)
	expect(again.snapshot().score == clean.snapshot().score, "identical inputs reproduce")
	print("Shell tide: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
