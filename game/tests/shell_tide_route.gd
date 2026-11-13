extends RefCounted
## Test-only listener: echoes the demonstrated phrase from the public event list with
## the same shell keys a player uses. It never writes model state.
const Model = preload("res://game/minigames/shell_tide_model.gd")

class SessionCommands extends RefCounted:
	var session: Control
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func key(code: Key, pressed: bool) -> void:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		session._unhandled_input(event)
	func press(shell: int) -> void: key(KEY_1 + shell, true)
	func release(shell: int) -> void: key(KEY_1 + shell, false)
	func wait_long_wave() -> void:
		key(KEY_W, true)
		key(KEY_W, false)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func press(shell: int) -> void: model.press(shell)
	func release(shell: int) -> void: model.release(shell)
	func wait_long_wave() -> void: model.wait_long_wave()
	func step(delta: float) -> void: model.step(delta)

## Plays every phrase. Without `devil` one silence is tapped on purpose; `slow` waits for the long wave.
static func solve(commands, devil: bool = true, slow: bool = false, delta: float = 1.0 / 120.0) -> bool:
	var tap_rest := not devil
	var pressed: Dictionary = {}
	var rest_tapped := false
	var echo_key := ""
	for frame in roundi((Model.ROUND_SECONDS + 1.0) / delta):
		var state: Dictionary = commands.snapshot()
		if state.ended:
			break
		if state.phase == "ready" and slow and not state.slow:
			commands.wait_long_wave()
		if state.phase == "echo":
			var key := "%d-%d" % [state.phrase, state.attempt]
			if key != echo_key:
				echo_key = key
				pressed.clear()
			for index in state.events.size():
				var event: Dictionary = state.events[index]
				var start: float = event.start + state.offset
				if event.shell < 0:
					if tap_rest and not rest_tapped and state.phase_time >= start + event.duration * 0.4:
						rest_tapped = true
						commands.press(0)
						commands.release(0)
					continue
				if not pressed.has(index) and state.phase_time >= start:
					pressed[index] = state.phase_time
					commands.press(event.shell)
				elif pressed.has(index) and pressed[index] >= 0.0 and state.phase_time - pressed[index] >= (event.duration * 0.9 if event.beats > 1 else 0.05):
					pressed[index] = -1.0
					commands.release(event.shell)
		commands.step(delta)
	return commands.snapshot().success
