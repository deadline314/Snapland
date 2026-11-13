extends SceneTree

const Model = preload("res://game/minigames/cargo_balance_model.gd")
const Route = preload("res://game/tests/cargo_balance_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run(model, seconds: float, delta: float = 1.0 / 60.0) -> void:
	for i in roundi(seconds / delta):
		model.step(delta)

func load_with(commands, targets: Dictionary) -> void:
	Route.load_hold(commands, targets)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.phase == "loading" and not state.ended and not state.ordinary_eligible and state.delivered == 0, "voyage starts loading at the pier")
	for field in ["heel", "static_heel", "moment", "crates", "waves", "upcoming", "cursor", "straps", "port_order"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.confirm()
	expect(model.snapshot().phase == "loading" and model.snapshot().feedback.contains("碼頭"), "cannot sail with cargo ashore")
	model.move_cursor(Vector2i(0, 0))
	model.grab()
	expect(model.snapshot().feedback.contains("壓著"), "a buried pier crate cannot be lifted")

	# Same total weight, different stowage: different heel.
	var level = Route.ModelCommands.new()
	load_with(level, {0: Vector2i(4, 0), 1: Vector2i(5, 0), 2: Vector2i(3, 0), 3: Vector2i(6, 0), 4: Vector2i(4, 1), 5: Vector2i(5, 1)})
	var lopsided = Route.ModelCommands.new()
	load_with(lopsided, {0: Vector2i(5, 0), 1: Vector2i(6, 0), 2: Vector2i(5, 1), 3: Vector2i(6, 1), 4: Vector2i(4, 0), 5: Vector2i(3, 0)})
	var tall = Route.ModelCommands.new()
	load_with(tall, {0: Vector2i(4, 0), 1: Vector2i(5, 0), 2: Vector2i(4, 1), 3: Vector2i(5, 1), 4: Vector2i(3, 0), 5: Vector2i(6, 0)})
	expect(absf(level.snapshot().static_heel) < 0.5 and lopsided.snapshot().static_heel > 8.0, "the same six crates heel differently by arrangement")
	expect(tall.snapshot().sensitivity > level.snapshot().sensitivity, "a high stowage rolls more for the same moment")
	for c in [level, lopsided]:
		var placed := 0
		for crate in c.snapshot().crates:
			if crate.cell.x >= Model.PIER_COLUMNS: placed += 1
		expect(placed == 6, "every crate reached its planned slot")

	# Stacking and strap rules.
	var rules = Route.ModelCommands.new()
	rules.move_cursor(Vector2i(0, 1))
	rules.grab()
	rules.move_cursor(Vector2i(4, 0))
	rules.grab()
	expect(rules.snapshot().feedback.contains("撐住") and rules.snapshot().held >= 0, "a top slot needs a crate below")
	rules.move_cursor(Vector2i(0, -1))
	rules.grab()
	expect(rules.snapshot().held < 0 and rules.snapshot().crates[3].cell == Vector2i(4, 0), "placing on the floor works")
	rules.toggle_strap()
	expect(rules.snapshot().crates[3].strap_timer >= 0.0 and not rules.snapshot().crates[3].strapped, "the deckhand takes a moment to strap")
	run(rules, Model.STRAP_DELAY + 0.05)
	expect(rules.snapshot().crates[3].strapped, "the designated crate is strapped")
	rules.grab()
	expect(rules.snapshot().held < 0 and rules.snapshot().feedback.contains("繫帶"), "strapped crates cannot be lifted")
	rules.toggle_strap()
	expect(not rules.snapshot().crates[3].strapped, "F unties immediately")

	# Waves: a lopsided, unstrapped hold slides; a severe one capsizes.
	lopsided.confirm()
	run(lopsided, Model.SAIL_SECONDS)
	state = lopsided.snapshot()
	expect(state.slides > 0 or state.capsized, "a lopsided unstrapped hold slides or capsizes in the waves")
	expect(not state.success, "a capsized or sliding voyage is not a clean success")

	# Full voyages with real commands.
	var plain = Route.ModelCommands.new()
	expect(Route.solve(plain, false), "loading, sailing and unloading complete without shifts")
	state = plain.snapshot()
	expect(state.success and state.ordinary_eligible and state.delivered == 6 and not state.devil, "a voyage without weight shifts succeeds without devil")
	var unsafe := 0
	for wave in state.waves:
		if not wave.safe: unsafe += 1
	expect(unsafe > 0 and state.score == (4 - unsafe) * Model.WAVE_POINTS + 6 * Model.CRATE_POINTS, "unsafe waves cost their points truthfully")
	var shifted = Route.ModelCommands.new()
	expect(Route.solve(shifted, true), "shifting weight at sea")
	state = shifted.snapshot()
	expect(state.success and state.devil and state.safe_waves == 4 and state.moves_at_sea > 0 and state.score == 700, "every wave safe with an at-sea shift earns devil")
	var second = Route.ModelCommands.new(false, 1)
	expect(Route.solve(second, true) and second.snapshot().devil and second.snapshot().port_order == ["B", "A"], "the second voyage changes the port order and still allows devil")
	var helped = Route.ModelCommands.new(true)
	state = helped.snapshot()
	expect(state.waves[0].strength < Model.VARIANTS[0].waves[0][1], "assist softens side waves")
	expect(Route.solve(helped, true) and helped.snapshot().devil, "assisted devil remains eligible")

	# Unloading needs unburying; ports refuse early departure.
	var port = Route.ModelCommands.new()
	Route.load_hold(port, Route.plan(port.snapshot()))
	port.confirm()
	run(port, Model.SAIL_SECONDS + 0.1)
	expect(port.snapshot().phase == "port", "the ship docks after the first leg")
	port.confirm()
	expect(port.snapshot().phase == "port" and port.snapshot().feedback.contains("卸"), "cannot leave before unloading")

	# Timeout stays truthful.
	var idle = Model.new()
	run(idle, Model.ROUND_SECONDS + 1.0, 0.25)
	state = idle.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "timeout ends truthfully")
	idle.grab()
	expect(idle.snapshot().held < 0, "ended round ignores input")
	var again = Route.ModelCommands.new()
	Route.solve(again, true)
	expect(again.snapshot().waves == shifted.snapshot().waves, "identical inputs reproduce")
	print("Cargo balance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
