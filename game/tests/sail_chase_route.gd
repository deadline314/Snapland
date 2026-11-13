extends RefCounted
## Test-only helmsman: steers toward the lightship, beats upwind in the no-go zone and
## trims to the visible wind with the same held rudder/sheet inputs. Never writes state.
const Model = preload("res://game/minigames/sail_chase_model.gd")

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
	func set_rudder(value: float) -> void:
		key(KEY_A, value < -0.3)
		key(KEY_D, value > 0.3)
	func set_trim_input(value: float) -> void:
		key(KEY_Q, value < -0.3)
		key(KEY_E, value > 0.3)
	func clear_input() -> void:
		for code in _held.keys(): key(code, false)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func set_rudder(value: float) -> void: model.set_rudder(value)
	func set_trim_input(value: float) -> void: model.set_trim_input(value)
	func clear_input() -> void: model.clear_input()
	func step(delta: float) -> void: model.step(delta)

## One decision per frame; keeps the tack side and the gybe bookkeeping between calls.
class Helmsman extends RefCounted:
	var tack := 1.0
	var gybes_at_catch := 0
	var catches := 0
	var probe = Model.new()

	func act(commands, devil: bool, delta: float, digital: bool) -> bool:
		var state: Dictionary = commands.snapshot()
		if state.ended:
			return false
		if state.catches != catches:
			catches = state.catches
			gybes_at_catch = state.gybes
		var wind: float = state.wind
		var target: Vector2 = probe.lightship_position(float(state.lightship_distance) + Model.LIGHTSHIP_SPEED * minf(4.0, state.position.distance_to(state.lightship) / maxf(1.0, state.speed)))
		if state.spurt > 0.0:
			target = state.lightship
		var desired: float = (target - state.position).angle()
		var upwind: float = wind + PI
		if absf(angle_difference(desired, upwind)) < Model.NO_GO + deg_to_rad(6.0):
			var port: float = upwind + Model.NO_GO + deg_to_rad(10.0)
			var starboard: float = upwind - Model.NO_GO - deg_to_rad(10.0)
			var current: float = port if tack > 0.0 else starboard
			var other: float = starboard if tack > 0.0 else port
			if absf(angle_difference(desired, other)) + deg_to_rad(25.0) < absf(angle_difference(desired, current)):
				tack = -tack
				current = other
			desired = current
		elif devil and not state.gybe_catch and state.gybes == gybes_at_catch and state.spurt <= 0.0 and absf(angle_difference(state.lightship_heading, wind)) < 0.35 and state.position.distance_to(state.lightship) < 4.5:
			# The lightship is running downwind: swing the stern across the wind once, then close in.
			desired = wind + signf(angle_difference(state.heading, wind) + 0.001) * deg_to_rad(28.0)
		var error := angle_difference(state.heading, desired)
		var rudder := clampf(error * 2.0, -1.0, 1.0)
		var trim_error: float = state.optimal_trim - state.trim
		var sheet := clampf(trim_error * 4.0, -1.0, 1.0)
		if digital:
			rudder = signf(rudder) if absf(error) > 0.06 else 0.0
			sheet = signf(sheet) if absf(trim_error) > deg_to_rad(4.0) else 0.0
		commands.set_rudder(rudder)
		commands.set_trim_input(sheet)
		commands.step(delta)
		return true

static func solve(commands, devil: bool = false, delta: float = 1.0 / 60.0, digital: bool = false) -> bool:
	var helm := Helmsman.new()
	for frame in roundi((Model.ROUND_SECONDS + 1.0) / delta):
		if not helm.act(commands, devil, delta, digital):
			break
	commands.clear_input()
	return commands.snapshot().success
