extends RefCounted
## Test-only helmsman: pure-pursuit steering with the public thrust/turn/reel/hook
## inputs. It never writes model state.
const Model = preload("res://game/minigames/rope_tug_model.gd")
const MAIN := [Vector2(-6.2, 0.4), Vector2(-5.6, 2.5), Vector2(-1.6, 2.5), Vector2(-0.9, -2.5), Vector2(3.4, -2.5), Vector2(4.4, 2.2), Vector2(8.6, 2.2), Vector2(11.0, 2.2)]
const SIDE := [Vector2(-6.2, 0.4), Vector2(-5.6, 2.5), Vector2(-1.6, 2.5), Vector2(-0.9, -2.5), Vector2(2.4, -3.0), Vector2(3.9, -4.6), Vector2(8.6, -4.6), Vector2(11.0, -4.6)]

class SessionCommands extends RefCounted:
	var session: Control
	var _held: Dictionary = {}
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func key(code: Key, pressed: bool) -> void:
		if pressed == _held.has(code):
			return
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		session._unhandled_input(event)
		if pressed: _held[code] = true
		else: _held.erase(code)
	func set_thrust(value: float) -> void:
		key(KEY_W, value > 0.3)
		key(KEY_S, value < -0.3)
	func set_turn(value: float) -> void:
		key(KEY_A, value < -0.3)
		key(KEY_D, value > 0.3)
	func set_reel(value: float) -> void:
		key(KEY_Q, value < -0.3)
		key(KEY_E, value > 0.3)
	func interact() -> void:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		for pressed in [true, false]:
			event.pressed = pressed
			session._unhandled_input(event)
	func clear_input() -> void:
		for code in _held.keys(): key(code, false)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func set_thrust(value: float) -> void: model.set_thrust(value)
	func set_turn(value: float) -> void: model.set_turn(value)
	func set_reel(value: float) -> void: model.set_reel(value)
	func interact() -> void: model.interact()
	func clear_input() -> void: model.clear_input()
	func step(delta: float) -> void: model.step(delta)

## Reels toward a target rope length using the hold-to-reel input.
static func reel_to(commands, length: float, delta: float = 1.0 / 60.0) -> void:
	for frame in 400:
		var state: Dictionary = commands.snapshot()
		var error: float = length - state.rope_length
		if absf(error) < 0.05 or not state.hooked:
			break
		commands.set_reel(signf(error))
		commands.step(delta)
	commands.set_reel(0.0)

static func steer_to(commands, target: Vector2, cruise: float, delta: float, digital: bool) -> bool:
	for frame in 3000:
		var state: Dictionary = commands.snapshot()
		if state.ended:
			return false
		var offset: Vector2 = target - state.tug
		if offset.length() < 0.35:
			return true
		var error := angle_difference(state.tug_heading, offset.angle())
		var turn := clampf(error * 2.5, -1.0, 1.0)
		var desired := cruise if absf(error) < 0.6 else 0.35
		var thrust := clampf((desired - state.tug_velocity.dot(Vector2.from_angle(state.tug_heading))) * 2.0, -1.0, 1.0)
		if digital:
			turn = signf(turn) if absf(error) > 0.08 else 0.0
			thrust = 1.0 if thrust > 0.2 else (-1.0 if thrust < -0.6 else 0.0)
		commands.set_turn(turn)
		commands.set_thrust(thrust)
		commands.step(delta)
	return false

static func solve(commands, route: Array = MAIN, rope: float = 1.6, cruise: float = 1.1, delta: float = 1.0 / 60.0, digital: bool = false) -> bool:
	commands.interact()
	reel_to(commands, rope, delta)
	for target: Vector2 in route:
		if not steer_to(commands, target, cruise, delta, digital):
			break
	commands.set_thrust(0.0)
	commands.set_turn(0.0)
	# Let the pontoon glide into the dock, then release slowly.
	for frame in 900:
		var state: Dictionary = commands.snapshot()
		if state.ended:
			break
		var reverse: float = -1.0 if state.tug_speed > 0.5 else 0.0
		commands.set_thrust(reverse)
		if state.pontoon.x >= Model.DOCK_X and state.pontoon_speed <= Model.DOCK_SPEED and state.gates_passed.size() == 3:
			commands.set_thrust(0.0)
			commands.interact()
			break
		commands.step(delta)
	commands.clear_input()
	return commands.snapshot().success
