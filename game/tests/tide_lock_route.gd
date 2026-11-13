extends RefCounted
## Test-only lock keeper: reads the public snapshot each slice and taps the same gate
## and valve keys a player uses. `paired` waits to lift two ships in one fill.
const Model = preload("res://game/minigames/tide_lock_model.gd")
## Which ship starts the two-ship lift in each layout (by arrival order).
const PAIR_START := [0, 1]

class SessionCommands extends RefCounted:
	var session: Control
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func tap(code: Key) -> void:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.pressed = pressed
			session._unhandled_input(event)
	func toggle_gate(upper: bool) -> void: tap(KEY_E if upper else KEY_Q)
	func toggle_valve(direction: int) -> void: tap(KEY_D if direction > 0 else KEY_A)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func toggle_gate(upper: bool) -> void: model.toggle_gate(upper)
	func toggle_valve(direction: int) -> void: model.toggle_valve(direction)
	func step(delta: float) -> void: model.step(delta)

static func _inside(state: Dictionary) -> Array:
	var rows: Array = []
	for ship: Dictionary in state.ships:
		if ship.present and not ship.passed and ship.front > 0.0 and ship.front - ship.length < Model.CHAMBER:
			rows.append(ship)
	return rows

static func _settled(state: Dictionary, gate_x: float) -> bool:
	for ship: Dictionary in state.ships:
		if ship.present and not ship.passed and ship.front - ship.length < gate_x + 0.2 and ship.front > gate_x - 0.2:
			return false
	return true

static func _waiting(state: Dictionary) -> Array:
	var rows: Array = []
	for ship: Dictionary in state.ships:
		if ship.present and not ship.passed and ship.front <= 0.0:
			rows.append(ship)
	return rows

## One decision per call; returns after at most one key action.
static func act(commands, paired: bool) -> void:
	var state: Dictionary = commands.snapshot()
	var inside := _inside(state)
	var waiting := _waiting(state)
	var remaining: int = state.ships.size() - int(state.passed)
	if state.upper_open:
		if inside.is_empty() and _settled(state, Model.CHAMBER):
			commands.toggle_gate(true)
		return
	if state.lower_open:
		var want := 2 if paired and int(state.passed) == PAIR_START[int(state.variant)] else 1
		var shallow := false
		for ship: Dictionary in inside:
			shallow = shallow or float(state.sea) < float(ship.draft) + Model.CLEARANCE + 0.25
		var full := inside.size() >= want or (inside.size() >= 1 and (waiting.is_empty() or shallow))
		var all_in := true
		for ship: Dictionary in inside:
			all_in = all_in and ship.front - ship.length >= 0.2
		if full and all_in and _settled(state, 0.0):
			commands.toggle_gate(false)
		return
	if not inside.is_empty():
		if state.upper_safe:
			commands.toggle_gate(true)
		elif state.valve != 1:
			commands.toggle_valve(1)
		return
	if remaining == 0:
		if state.valve != 0:
			commands.toggle_valve(state.valve)
		return
	if not waiting.is_empty():
		var first: Dictionary = waiting[0]
		# On a falling tide leave room for the water still to drop while ships move in.
		var margin := 0.15 if state.next_high else 0.6
		var deep: bool = float(state.sea) >= float(first.draft) + Model.CLEARANCE + margin
		if state.lower_safe and deep and first.front >= -Model.GATE_MARGIN - 0.6:
			commands.toggle_gate(false)
		elif state.valve != -1:
			commands.toggle_valve(-1)

static func solve(commands, paired: bool = false, delta: float = 1.0 / 60.0) -> bool:
	for i in roundi(Model.ROUND_SECONDS / delta) + 2:
		if commands.snapshot().ended:
			break
		if i % 6 == 0:
			act(commands, paired)
		commands.step(delta)
	return commands.snapshot().success
