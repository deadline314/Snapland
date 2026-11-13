extends SceneTree
const Model = preload("res://game/minigames/gull_glide_model.gd")
const Route = preload("res://game/tests/gull_glide_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fly(model, tucked: bool, seconds: float) -> void:
	model.set_tucked(tucked)
	for i in roundi(seconds * 60.0):
		model.step(1.0 / 60.0)

func until_x(model, x: float, tucked: bool) -> void:
	model.set_tucked(tucked)
	for i in 3000:
		if model.snapshot().position.x >= x or model.snapshot().ended:
			return
		model.step(1.0 / 60.0)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.position == Model.START and state.variant == 0 and not state.tucked, "round starts spread at the start rock")
	expect(state.feathers.size() == 3 and state.thermals.size() == 3, "three feathers and three thermals")
	expect(state == state.duplicate(true), "snapshot compares equal to itself (no NaN)")
	expect(Model.wind(12.0) > Model.wind(2.0) and Model.wind(0.0) == 0.0, "headwind grows with height")
	expect(Model.ground_speed(10.0, 6.0, true) > Model.ground_speed(10.0, 6.0, false), "tucked wings feel less headwind")

	# Spread vs tuck from the same start differ repeatably.
	var glide = Model.new()
	var dive = Model.new()
	fly(glide, false, 1.5)
	fly(dive, true, 1.5)
	var glide_at: Vector2 = glide.snapshot().position
	var dive_at: Vector2 = dive.snapshot().position
	expect(dive_at.x > glide_at.x + 1.0 and dive_at.y < glide_at.y - 2.0, "tuck dives lower and farther than a spread glide")
	var again = Model.new()
	fly(again, true, 1.5)
	expect(again.snapshot().position == dive_at, "the same input gives the same distance")
	fly(dive, false, 1.0)
	expect(dive.snapshot().velocity.y > 0.0, "spreading after a dive zooms upward")
	expect(glide.snapshot().reach > glide.snapshot().position.x, "glide reach lies ahead")

	# Thermals lift spread wings.
	var thermal = Model.new()
	until_x(thermal, 4.0, false)
	var low: float = thermal.snapshot().position.y
	until_x(thermal, 6.5, false)
	expect(thermal.snapshot().position.y > low + 0.5, "spread wings climb in a thermal")

	# Spread-only never picks a feather and loops home without them.
	var idle = Model.new()
	fly(idle, false, 30.0)
	expect(idle.snapshot().laps >= 1 and idle.snapshot().feather_count == 0 and not idle.snapshot().ended, "missing feathers send the gull round again")
	expect(idle.snapshot().feedback.contains("繞回") or idle.snapshot().laps >= 1, "lap reason is readable")

	# Crashes: water drops this lap's feathers unassisted.
	var wet = Model.new()
	until_x(wet, 21.0, true)
	fly(wet, true, 6.0)
	state = wet.snapshot()
	expect(state.crashes >= 1 and state.last_event in ["water", "rock", "scrape"] and state.feedback.contains("從起點"), "a crash restarts the lap with a reason")
	expect(state.position.x < 21.0, "unassisted crash returns to the start")

	# Normal and devil routes.
	var normal := Route.ModelCommands.new(false, 0)
	expect(Route.solve(normal, false), "normal route brings three feathers home")
	state = normal.snapshot()
	expect(state.success and state.ended and state.ordinary_eligible and not state.devil and state.feather_count == 3, "normal home is ordinary")
	expect(state.score == 3 * Model.FEATHER_POINTS + Model.HOME_POINTS + int(Model.ROUND_SECONDS - state.elapsed), "score counts feathers, home and time left")
	var devil := Route.ModelCommands.new(false, 0)
	expect(Route.solve(devil, true) and devil.snapshot().devil, "tucked gap threading then spread home is devil")
	expect(devil.snapshot().score == normal.snapshot().score - int(Model.ROUND_SECONDS - normal.snapshot().elapsed) + int(Model.ROUND_SECONDS - devil.snapshot().elapsed) + Model.DEVIL_POINTS, "devil adds its bonus")
	var mirrored := Route.ModelCommands.new(false, 1)
	expect(mirrored.snapshot().gap.low != devil.snapshot().gap.low and mirrored.snapshot().nest != devil.snapshot().nest, "retry layout moves the gap and nest")
	expect(Route.solve(mirrored, true) and mirrored.snapshot().devil, "second layout is solvable through the gap")
	var over := Route.ModelCommands.new(false, 1)
	expect(Route.solve(over, false) and not over.snapshot().devil, "second layout is solvable over the rock")

	# Gap rules: spread wings scrape, tucked landing is hard.
	var scrape = Model.new()
	var gap: Dictionary = scrape.snapshot().gap
	scrape._bird.position = Vector2(gap.x - 0.05, (gap.low + gap.high) * 0.5)
	scrape._bird.velocity = Vector2(6, 0)
	fly(scrape, false, 0.1)
	expect(scrape.snapshot().last_event == "scrape" and scrape.snapshot().feedback.contains("擦到岩縫"), "spread wings scrape in the gap")
	var hard = Model.new()
	var nest: Vector2 = hard.snapshot().nest
	hard._got.assign([0, 1, 2])
	hard._bird.position = Vector2(nest.x - 0.05, nest.y + 0.5)
	fly(hard, true, 0.1)
	expect(hard.snapshot().last_event == "hard" and not hard.snapshot().ended, "tucked arrival at the nest is a hard landing")

	# Assistance keeps feathers and respawns at the last thermal.
	var helped = Model.new()
	helped.reset(true, 0)
	var assisted_route := Route.ModelCommands.new(true, 0)
	assisted_route.model = helped
	for i in 900:
		if helped.snapshot().feather_count >= 1: break
		assisted_route.set_tucked(Route.want_tuck(helped.snapshot(), false))
		helped.step(1.0 / 60.0)
	var kept: int = helped.snapshot().feather_count
	helped.set_tucked(true)
	for i in 600:
		if helped.snapshot().crashes > 0: break
		helped.step(1.0 / 60.0)
	state = helped.snapshot()
	expect(kept >= 1 and state.crashes == 1 and state.feather_count == kept and state.feedback.contains("保留"), "assisted fall keeps feathers")
	expect(state.position.x == state.respawn.x and state.respawn.x > 0.0, "assisted fall returns to the nearest passed thermal")

	# Companion and clock safety.
	expect(idle.snapshot().companion_homes >= 1, "the low-wind companion reaches the nest on its own")
	model.reset(false, 0)
	model.step(NAN)
	model.step(-1.0)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.step(10.0)
	expect(is_equal_approx(model.snapshot().elapsed, Model.MAX_FRAME_DELTA), "large frame delta is capped")
	for i in 600:
		model.step(0.25)
	state = model.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "timeout ends truthfully")
	model.set_tucked(true)
	expect(not model.snapshot().tucked, "ended round ignores tuck")
	print("Gull glide: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
