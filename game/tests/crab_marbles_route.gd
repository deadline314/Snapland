extends RefCounted
## Test-only shooter: searches the public preview, then reaches the aim and power
## with the same held keys a player uses. It never writes model state.
const Model = preload("res://game/minigames/crab_marbles_model.gd")

class SessionCommands extends RefCounted:
	var session: Control
	var _held: Dictionary = {}
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func model(): return session.active_driver._model
	func key(code: Key, pressed: bool) -> void:
		if pressed == _held.has(code):
			return
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		session._unhandled_input(event)
		if pressed: _held[code] = true
		else: _held.erase(code)
	func set_aim_input(value: float) -> void:
		key(KEY_A, value < -0.3)
		key(KEY_D, value > 0.3)
	func set_charging(value: bool) -> void: key(KEY_SPACE, value)
	func clear_input() -> void:
		for code in _held.keys(): key(code, false)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var _model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: _model.reset(assisted, variant)
	func snapshot() -> Dictionary: return _model.snapshot()
	func model(): return _model
	func set_aim_input(value: float) -> void: _model.set_aim_input(value)
	func set_charging(value: bool) -> void: _model.set_charging(value)
	func clear_input() -> void: _model.clear_input()
	func step(delta: float) -> void: _model.step(delta)

## Finds a stable shot whose neighbours also open `want` gates. `double` asks for a bank double.
static func plan(model, want: int, double: bool = false) -> Dictionary:
	for degree in range(-69, 70):
		var aim := deg_to_rad(degree)
		for step in range(20, -1, -1):
			var power := step / 20.0
			var shot: Dictionary = model.simulate(aim, power)
			var ok: bool = shot.double_after_bounce if double else shot.gates.size() >= want
			if not ok:
				continue
			var stable := true
			# Charging overshoots by at most one frame, so only a slightly stronger shot is checked.
			for neighbour in [[aim - deg_to_rad(0.6), power], [aim + deg_to_rad(0.6), power], [aim, minf(1.0, power + 0.015)]]:
				var near: Dictionary = model.simulate(neighbour[0], neighbour[1])
				if not (near.double_after_bounce if double else near.gates.size() >= want):
					stable = false
					break
			if stable:
				return {"aim": aim, "power": power, "gates": shot.gates}
	return {}

## Turns to the aim with held keys, then charges until the planned power and releases.
static func shoot(commands, aim: float, power: float, delta: float = 1.0 / 60.0) -> void:
	for frame in 600:
		var error: float = aim - commands.snapshot().aim
		if absf(error) < deg_to_rad(0.4):
			break
		commands.set_aim_input(clampf(error / (Model.AIM_SPEED * delta), -1.0, 1.0) if not commands is SessionCommands else signf(error))
		commands.step(delta)
	commands.set_aim_input(0.0)
	commands.set_charging(true)
	for frame in 200:
		if commands.snapshot().power >= power - 0.0001:
			break
		commands.step(delta)
	commands.set_charging(false)
	for frame in 1200:
		if not commands.snapshot().ball_active or commands.snapshot().ended:
			break
		commands.step(delta)

## Opens every gate, preferring a bank double first when `devil` is set.
static func solve(commands, devil: bool = false, delta: float = 1.0 / 60.0) -> bool:
	if devil:
		var double := plan(commands.model(), 2, true)
		if double.is_empty():
			return false
		shoot(commands, double.aim, double.power, delta)
	for attempt in 6:
		var state: Dictionary = commands.snapshot()
		if state.ended:
			break
		var shot := plan(commands.model(), 1)
		if shot.is_empty():
			return false
		shoot(commands, shot.aim, shot.power, delta)
	return commands.snapshot().success
