extends RefCounted
## Test-only relay hand: predicts drift from public tube data, then charges, reels and
## passes with the same single action key a player uses. It never writes model state.
const Model = preload("res://game/minigames/buoy_relay_model.gd")

class SessionCommands extends RefCounted:
	var session: Control
	var _down := false
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func set_action(pressed: bool) -> void:
		if pressed == _down:
			return
		_down = pressed
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = pressed
		session._unhandled_input(event)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func set_action(pressed: bool) -> void: model.set_action(pressed)
	func step(delta: float) -> void: model.step(delta)

static func power_for(distance: float) -> float:
	return clampf((distance - Model.MIN_THROW) / (Model.MAX_THROW - Model.MIN_THROW), 0.0, 1.0)

## Charges until the planned power, then releases.
static func throw_with(commands, power: float, delta: float) -> void:
	commands.set_action(true)
	for frame in 200:
		if commands.snapshot().power >= power - 0.004:
			break
		commands.step(delta)
	commands.set_action(false)

## Picks the landing that covers two converging tubes when `double` is set and possible.
static func plan_catch(state: Dictionary, double: bool) -> float:
	var drifting: Array = state.tubes.filter(func(tube): return tube.state == "drifting")
	var lead := 0.9
	var best := INF
	var best_gap := INF
	for tube: Dictionary in drifting:
		var target: float = tube.x + tube.drift * lead
		if double:
			for other: Dictionary in drifting:
				if other.id == tube.id:
					continue
				var mid: float = (target + other.x + other.drift * lead) * 0.5
				var gap: float = absf(target - (other.x + other.drift * lead))
				if gap < best_gap:
					best_gap = gap
					best = mid
		elif absf(target - state.station_x) < absf(best - state.station_x):
			best = target
	if double and best_gap > state.catch_radius * 2.0 - 0.15:
		return NAN
	return best

static func solve(commands, devil: bool = false, direct: bool = true, delta: float = 1.0 / 60.0) -> bool:
	for frame in roundi(Model.ROUND_SECONDS / delta):
		var state: Dictionary = commands.snapshot()
		if state.ended:
			break
		match state.phase:
			"aim_catch":
				var double_wanted: bool = devil and not state.double_catch
				var landing := plan_catch(state, double_wanted)
				if is_nan(landing):
					commands.step(delta)
					continue
				var distance: float = landing - state.station_x
				var power := power_for(distance)
				throw_with(commands, power, delta)
			"reeling":
				# Reel only while the bundle stays clear of its crest a few frames ahead.
				var total := 0.0
				for id in state.held:
					for tube: Dictionary in state.tubes:
						if tube.id == id:
							total += sin((state.elapsed + 3.0 * delta) * Model.WOBBLE_RATE + tube.phase)
				var limit: float = (Model.SLIP_WOBBLE if state.held.size() == 1 else Model.BUNDLE_SLIP_WOBBLE) - 0.1
				commands.set_action(absf(total / maxf(1.0, state.held.size())) < limit)
				commands.step(delta)
			"aim_pass":
				var target := 0 if direct or state.station == 1 else 1
				throw_with(commands, power_for(state.station_x - Model.STATIONS[target]), delta)
			_:
				commands.step(delta)
	commands.set_action(false)
	return commands.snapshot().success
