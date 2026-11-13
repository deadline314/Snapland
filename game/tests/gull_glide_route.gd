extends RefCounted
## Test-only pilot: decides tuck/spread from the public snapshot each slice and
## drives it through the same held input a player uses. It never writes live state.
const Model = preload("res://game/minigames/gull_glide_model.gd")

class SessionCommands extends RefCounted:
	var session: Control
	var _held := false
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func set_tucked(value: bool) -> void:
		if value == _held:
			return
		_held = value
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = value
		session._unhandled_input(event)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func set_tucked(value: bool) -> void: model.set_tucked(value)
	func step(delta: float) -> void: model.step(delta)

## Aim at the next feather, then the gap (devil) or over the arch, then the nest.
static func want_tuck(state: Dictionary, devil: bool) -> bool:
	var at: Vector2 = state.position
	var velocity: Vector2 = state.velocity
	var gap: Dictionary = state.gap
	var nest: Vector2 = state.nest
	if devil and at.x >= gap.x - 1.0 and at.x <= gap.x + gap.width + 0.05:
		return true
	if at.x > nest.x - 2.5:
		return false
	if not devil and at.x >= gap.x - 4.0 and at.x <= gap.x + gap.width:
		return at.y > gap.top + 2.5
	var target := Vector2(nest.x, nest.y + 0.6)
	var feather_ahead := false
	for feather: Dictionary in state.feathers:
		var spot: Vector2 = feather.position
		if not feather.taken and spot.x > at.x + 0.3:
			target = spot
			feather_ahead = true
			break
	if not feather_ahead and at.x < gap.x + gap.width:
		target = Vector2(gap.x, (gap.low + gap.high) * 0.5 if devil else gap.top + 1.2)
	var ground := maxf(1.0, velocity.x - Model.wind(at.y))
	var eta := maxf(0.05, (target.x - at.x) / ground)
	var predicted := at.y + velocity.y * minf(eta, 1.0) - Model.GLIDE_SINK * maxf(0.0, eta - 1.0)
	return predicted > target.y + 0.3

static func solve(commands, devil: bool = false, delta: float = 1.0 / 60.0) -> bool:
	for i in roundi(Model.ROUND_SECONDS / delta) + 2:
		var state: Dictionary = commands.snapshot()
		if state.ended:
			break
		commands.set_tucked(want_tuck(state, devil))
		commands.step(delta)
	commands.set_tucked(false)
	return commands.snapshot().success
