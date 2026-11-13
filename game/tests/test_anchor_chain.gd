extends SceneTree
const Model = preload("res://game/minigames/anchor_chain_model.gd")
const Route = preload("res://game/tests/anchor_chain_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func choose(model, target: int) -> void:
	for i in 12:
		if model.snapshot().selected == target:
			return
		model.select_next(1)

func reel(model, seconds: float) -> void:
	model.set_reeling(true)
	for i in roundi(seconds * 60.0):
		if model.snapshot().ended or model.snapshot().anchor < 0:
			break
		model.step(1.0 / 60.0)
	model.set_reeling(false)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.variant == 0 and is_equal_approx(state.theta, deg_to_rad(-90.0)) and state.channel == "東", "first stranding points north, channel east")
	expect(state.targets.size() == 7 and state.targets[0].kind == "post" and state.targets[3].kind == "anchor", "targets list reefs then anchor spots")
	expect(state == state.duplicate(true), "snapshot compares equal to itself (no NaN)")
	model.select_next(-1)
	expect(model.snapshot().selected == 6, "selection wraps backwards")
	model.set_reeling(true)
	expect(not model.snapshot().reeling and model.snapshot().feedback.contains("還沒下錨"), "cannot reel before anchoring")

	# Direct pull: the line runs through the grounded stern, so it never turns.
	choose(model, 3)
	model.place()
	expect(model.snapshot().anchor == 0 and model.snapshot().wraps.is_empty(), "anchor drops at the selected spot")
	expect(absf(model.torque()) < 0.3, "direct pull has almost no torque")
	model.place()
	expect(model.snapshot().feedback.contains("先按 X"), "anchored chain refuses re-rigging")
	reel(model, 5.0)
	state = model.snapshot()
	expect(state.breaks == 1 and state.anchor < 0 and state.feedback.contains("穿過擱淺點"), "direct pull breaks with a readable reason")
	expect(is_equal_approx(state.theta, deg_to_rad(-90.0)), "the ship did not move on a failed pull")

	# Wrapping a reef redirects the pull into torque that turns the bow.
	var steps := Route.plan(0, false, false)
	expect(steps.size() == 2 and steps[0] < 3, "normal plan wraps one reef then anchors")
	var commands := Route.ModelCommands.new()
	commands.model = model
	Route.rig(commands, steps)
	expect(model.snapshot().wraps == [steps[0]] and model.torque() > Model.GROUND_FRICTION, "a wrap turns the pull into torque past friction")
	reel(model, 60.0)
	state = model.snapshot()
	expect(state.success and state.ended and state.ordinary_eligible and not state.devil, "wrapped pull frees the ship")
	expect(state.score == Model.FREE_POINTS - Model.BREAK_PENALTY, "score counts the earlier break")
	expect(absf(state.remaining_turn) <= Model.ALIGN_TOLERANCE, "bow ends aligned with the channel")
	model.select_next(1)
	model.place()
	expect(model.snapshot() == state, "ended model ignores input")

	# Devil: the same reef twice, no breaks.
	var devil_steps := Route.plan(0, false, true)
	expect(devil_steps.size() == 3 and devil_steps[0] == devil_steps[1], "devil plan double-wraps one reef")
	var devil := Route.ModelCommands.new(false, 0)
	Route.rig(devil, devil_steps)
	expect(devil.snapshot().double_wrap and devil.snapshot().feedback.contains("下錨"), "double wrap is visible before reeling")
	Route.reel(devil, 60.0, 1.0 / 60.0)
	state = devil.snapshot()
	expect(state.success and state.devil and state.score == Model.FREE_POINTS + 100, "same-reef double turn frees with devil")

	# Mirrored retry: other bow, channel and reef layout.
	var mirrored := Route.ModelCommands.new(false, 1)
	expect(mirrored.snapshot().channel == "西" and is_equal_approx(mirrored.snapshot().theta, deg_to_rad(90.0)), "retry layout points south toward a west channel")
	expect(Route.solve(mirrored, true, 1.0 / 60.0) and mirrored.snapshot().devil, "mirrored layout is solvable with a double wrap")
	expect(Model.new().snapshot().targets != mirrored.snapshot().targets, "retry moves reefs and anchors")

	# Assistance: no breaks, step-back undo.
	var helped = Model.new()
	helped.reset(true, 0)
	choose(helped, 0)
	helped.place()
	choose(helped, 3)
	helped.place()
	helped.undo()
	expect(helped.snapshot().anchor < 0 and helped.snapshot().wraps == [0], "assisted undo lifts the anchor first")
	helped.undo()
	expect(helped.snapshot().wraps.is_empty() and not helped.snapshot().undo_available, "then steps back the wrap")
	choose(helped, 3)
	helped.place()
	helped.set_reeling(true)
	for i in 360:
		helped.step(1.0 / 60.0)
	expect(helped.snapshot().breaks == 0 and helped.snapshot().anchor == 0 and helped.snapshot().strain == 1.0, "assisted chain strains but never breaks")
	helped.set_reeling(false)
	model.reset(false, 0)
	choose(model, 0)
	model.place()
	model.undo()
	expect(model.snapshot().wraps == [0] and model.snapshot().feedback.contains("輔助"), "undo is assist-only")

	# Limits and the helper rudder.
	model.reset(false, 0)
	for target in [2, 0, 1]:
		choose(model, target)
		model.place()
	choose(model, 0)
	model.place()
	expect(model.snapshot().wraps.size() == Model.MAX_WRAPS and model.snapshot().feedback.contains("最多"), "wrap count is capped")
	choose(model, 5)
	model.place()
	expect(model.snapshot().anchor < 0 and model.snapshot().feedback.contains("不夠長"), "overlong chain is refused")
	model.recall()
	expect(model.snapshot().wraps.is_empty() and model.snapshot().anchor < 0, "X recalls the whole chain")
	var helpers: Array = []
	for i in 3:
		model.cycle_helper()
		helpers.append(model.snapshot().helper)
	expect(helpers == [1, -1, 0], "helper rudder cycles right, left, centre")
	choose(model, 3)
	model.place()
	model.cycle_helper()
	expect(absf(model.torque() - Model.HELPER_TORQUE) < 0.3, "helper adds only a low fixed rudder torque")

	# Some wraps pull the wrong way; the reason says so instead of silently drifting.
	var wrong_way := false
	for post in 3:
		for spot in 4:
			var probe := Route.ModelCommands.new(false, 0)
			Route.rig(probe, [post, 3 + spot])
			probe.set_reeling(true)
			probe.step(0.1)
			wrong_way = wrong_way or str(probe.snapshot().reason).contains("反了")
	expect(wrong_way, "a wrong-way wrap is explained")

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
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "timeout ends truthfully")
	print("Anchor chain: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
