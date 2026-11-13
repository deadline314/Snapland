extends SceneTree
const Model = preload("res://game/minigames/tide_lock_model.gd")
const Route = preload("res://game/tests/tide_lock_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run(model, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		model.step(1.0 / 60.0)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.ships.size() == 3 and not state.lower_open and not state.upper_open and state.valve == 0, "three ships, both gates and valves closed")
	expect(is_equal_approx(state.level, state.sea) and state.lower_safe and not state.upper_safe, "chamber starts at sea level with only the lower light green")
	expect(state == state.duplicate(true), "snapshot compares equal to itself (no NaN)")
	var next: Array = model.next_extreme(0.0)
	expect(next[1] and is_equal_approx(model.sea_level(next[0]), 2.7), "first forecast is high water at the tide peak")

	# Interlocks: never both gates; valves respect the open gate.
	model.toggle_gate(true)
	expect(not model.snapshot().upper_open and model.snapshot().feedback.contains("先蓄水"), "upper gate refuses a level difference")
	model.toggle_gate(false)
	expect(model.snapshot().lower_open, "lower gate opens at sea level")
	model.toggle_valve(1)
	expect(model.snapshot().valve == 0 and model.snapshot().feedback.contains("不能蓄水"), "no filling with the lower gate open")
	model.toggle_gate(true)
	expect(not model.snapshot().upper_open and model.snapshot().feedback.contains("兩閘不能同開"), "two gates never open together")
	model.toggle_gate(false)
	model.toggle_valve(1)
	run(model, 1.0)
	expect(model.snapshot().level > model.snapshot().sea + 0.3 and model.snapshot().basin < Model.BASIN_LEVEL, "filling raises the chamber and draws the basin")
	model.toggle_gate(false)
	expect(not model.snapshot().lower_open, "lower gate refuses a raised chamber")
	model.toggle_valve(1)
	expect(model.snapshot().valve == 0, "pressing the same valve again holds the level")

	# A ship cannot close a gate on itself, and shallow water grounds it.
	model.reset(false, 0)
	model.toggle_gate(false)
	for i in 600:
		var ship: Dictionary = model.snapshot().ships[0]
		if ship.front - ship.length < 0.2 and ship.front > -0.2: break
		model.step(1.0 / 60.0)
	model.toggle_gate(false)
	expect(model.snapshot().lower_open and model.snapshot().feedback.contains("卡在下閘口"), "gate will not close on a ship")
	var low = Model.new()
	low.reset(false, 0)
	low.toggle_gate(false)
	run(low, 10.0)
	low.toggle_gate(false)
	expect(not low.snapshot().lower_open and low.snapshot().ships[0].front - low.snapshot().ships[0].length > 0.2, "the first ship is shut inside the chamber")
	low._level = 0.6
	run(low, 0.1)
	expect(low.snapshot().groundings == 1 and low.snapshot().ships[0].grounded and low.snapshot().feedback.contains("擱淺"), "water below the draft grounds a ship")
	low.toggle_valve(1)
	run(low, 3.0)
	expect(not low.snapshot().ships[0].grounded and low.snapshot().groundings == 1, "refilling floats it again; the grounding stays counted")

	# Routes: one ship per lift, and two ships in one fill.
	for variant in 2:
		var single := Route.ModelCommands.new(false, variant)
		expect(Route.solve(single, false), "layout %d frees all ships one by one" % variant)
		state = single.snapshot()
		expect(state.success and state.passed == 3 and not state.devil and state.groundings == 0, "layout %d single lifts are ordinary" % variant)
		var paired := Route.ModelCommands.new(false, variant)
		expect(Route.solve(paired, true) and paired.snapshot().devil, "layout %d lifts two ships in one fill for the devil" % variant)
		expect(paired.snapshot().basin > state.basin, "layout %d pairing saves basin water" % variant)
	expect(Model.LAYOUTS[0].ships[0].length != Model.LAYOUTS[1].ships[0].length and Model.LAYOUTS[0].phase != Model.LAYOUTS[1].phase, "retry changes ships and tide")
	state = Route.ModelCommands.new(false, 0).snapshot()
	expect(state.score == 0 and not state.success, "nothing scored before play")

	# Bell, helper, horn and assist.
	var bell = Model.new()
	run(bell, 7.0)
	expect(bell.snapshot().last_event == "bell" or bell.snapshot().feedback.contains("叮"), "the tide bell rings ahead of high water")
	var helped = Model.new()
	helped.toggle_helper()
	helped.toggle_valve(-1)
	run(helped, 8.0)
	expect(helped.snapshot().lower_open and helped.snapshot().helper, "helper opens the lower gate once the light is green and a ship waits")
	run(helped, 12.0)
	expect(helped.snapshot().lower_open and not helped.snapshot().upper_open and helped.snapshot().valve == 0, "helper never closes gates, fills or opens the upper gate")
	var impatient = Model.new()
	run(impatient, 40.0)
	expect(impatient.snapshot().horns >= 1 and impatient.snapshot().score == 0, "an ignored ship horns after its countdown")
	var calm = Model.new()
	calm.reset(true, 0)
	run(calm, 40.0)
	expect(calm.snapshot().horns == 0 and calm.snapshot().preview.size() == 11, "assist cancels the countdown and previews the tide")

	# Clock safety and truthful timeout.
	model.reset(false, 0)
	model.step(NAN)
	model.step(-1.0)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.step(10.0)
	expect(is_equal_approx(model.snapshot().elapsed, Model.MAX_FRAME_DELTA), "large frame delta is capped")
	for i in 800:
		model.step(0.25)
	state = model.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.passed == 0, "timeout ends truthfully")
	model.toggle_gate(false)
	expect(not model.snapshot().lower_open, "ended round ignores gates")
	print("Tide lock: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
