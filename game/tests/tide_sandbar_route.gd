extends RefCounted
## Test-only walker: drives the public move/run/mark inputs toward anchor centres.
## It never writes model state; arrival relies on the model's own movement.
const Model = preload("res://game/minigames/tide_sandbar_model.gd")
const SECURE_FIRST := [["highland", true], ["dune", true], ["reef_north", true], ["reef_far", true], ["reef_south", true], ["dune", false], ["highland", false], ["camp", false]]
const FAR_FIRST := [["dune", true], ["reef_far", true], ["reef_north", true], ["dune", false], ["reef_south", true], ["dune", false], ["highland", false], ["camp", false]]

class SessionCommands extends RefCounted:
	var session: Control
	var _held: Dictionary = {}
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func key(code: Key, pressed: bool) -> void:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		session._unhandled_input(event)
	## Digital keys: the walker presses the nearest of eight directions.
	func set_move(direction: Vector2) -> void:
		var want := {KEY_D: direction.x > 0.38, KEY_A: direction.x < -0.38, KEY_S: direction.y > 0.38, KEY_W: direction.y < -0.38}
		for code in want:
			if bool(want[code]) != _held.has(code):
				key(code, want[code])
				if want[code]: _held[code] = true
				else: _held.erase(code)
	func set_running(value: bool) -> void:
		if value != _held.has(KEY_SHIFT):
			key(KEY_SHIFT, value)
			if value: _held[KEY_SHIFT] = true
			else: _held.erase(KEY_SHIFT)
	func interact() -> void:
		key(KEY_SPACE, true)
		key(KEY_SPACE, false)
	func clear_input() -> void:
		set_move(Vector2.ZERO)
		set_running(false)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func set_move(direction: Vector2) -> void: model.set_move(direction)
	func set_running(value: bool) -> void: model.set_running(value)
	func interact() -> void: model.interact()
	func clear_input() -> void: model.clear_input()
	func step(delta: float) -> void: model.step(delta)

static func anchor_position(state: Dictionary, anchor_id: String) -> Vector2:
	for anchor: Dictionary in state.anchors:
		if anchor.id == anchor_id:
			return anchor.position
	return Vector2.INF

## Walks straight to the anchor centre. Returns false on timeout or round end.
static func walk_to(commands, anchor_id: String, run: bool = true, delta: float = 1.0 / 60.0, digital: bool = false) -> bool:
	for frame in 6000:
		var state: Dictionary = commands.snapshot()
		if state.ended:
			return false
		var offset: Vector2 = anchor_position(state, anchor_id) - state.position
		var tolerance := 0.3 if digital else 0.02
		if offset.length() <= tolerance and not state.rescuing:
			commands.clear_input()
			return true
		commands.set_running(run)
		if digital:
			commands.set_move(offset.normalized())
		else:
			commands.set_move(offset / ((Model.RUN_SPEED if run else Model.WALK_SPEED) * delta))
		commands.step(delta)
	return false

static func solve(commands, route: Array = SECURE_FIRST, run: bool = true, delta: float = 1.0 / 60.0, digital: bool = false) -> bool:
	for leg: Array in route:
		if not walk_to(commands, leg[0], run, delta, digital):
			return commands.snapshot().ended and commands.snapshot().success
		if leg[1]:
			commands.interact()
	for frame in 30:
		if commands.snapshot().ended:
			break
		commands.step(delta)
	return commands.snapshot().success
