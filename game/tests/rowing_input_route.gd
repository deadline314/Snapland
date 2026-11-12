extends RefCounted
## Fixed test-only digital navigator; never writes model state.
const Model = preload("res://game/minigames/rowing_cargo_model.gd")

class SessionCommands extends RefCounted:
	var session: Control
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func key(code: Key, pressed: bool) -> void:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		session._unhandled_input(event)
	func tap(code: Key) -> void:
		key(code, true)
		key(code, false)
	func paddle(direction: float) -> void: tap(KEY_W if direction > 0.0 else KEY_S)
	func sideslip(direction: float) -> void: tap(KEY_E if direction > 0.0 else KEY_Q)
	func interact() -> void: tap(KEY_SPACE)
	func set_rudder(direction: float) -> void:
		key(KEY_A, direction < 0.0)
		key(KEY_D, direction > 0.0)
	func clear_input() -> void: set_rudder(0.0)
	func step(delta: float) -> void: session._process(delta)

class RecordingCommands extends RefCounted:
	var model = Model.new()
	var events: Array = []
	var step_delta := 0.025
	func _init(assisted: bool, delta: float = 0.025) -> void:
		model.reset(assisted)
		step_delta = delta
	func snapshot() -> Dictionary: return model.snapshot()
	func paddle(direction: float) -> void:
		events.append(["paddle", direction])
		model.paddle(direction)
	func sideslip(direction: float) -> void:
		events.append(["sideslip", direction])
		model.sideslip(direction)
	func interact() -> void:
		events.append(["interact", 0.0])
		model.interact()
	func set_rudder(direction: float) -> void:
		events.append(["set_rudder", direction])
		model.set_rudder(direction)
	func clear_input() -> void:
		events.append(["clear_input", 0.0])
		model.clear_input()
	func step(_delta: float) -> void:
		events.append(["step", step_delta])
		model.step(step_delta)

static func solve(model, stroke_shift: float = 0.0) -> void:
	for i in 3:
		var state: Dictionary = model.snapshot()
		if i > 0:
			navigate(model, Vector2(5.0, Model.LONG_ROUTE_Y), false, stroke_shift)
			navigate(model, Vector2(-4.0, Model.LONG_ROUTE_Y), false, stroke_shift)
			navigate(model, Model.CARGO_STARTS[i], false, stroke_shift)
		model.interact()
		navigate(model, Vector2(-4.0, Model.LONG_ROUTE_Y), false, stroke_shift)
		navigate(model, Vector2(4.0, Model.LONG_ROUTE_Y), false, stroke_shift)
		var dock: Vector2 = Model.DOCKS[Model.DESTINATIONS[i] - 1].position
		navigate(model, dock - Vector2(2.0, 0.0), false, stroke_shift)
		navigate(model, dock, true, stroke_shift)
		state = model.snapshot()
		var guard := 0
		while not state.ended and not state.crest and guard < 260:
			steer(model, 0.0)
			model.step(0.025)
			state = model.snapshot()
			guard += 1
		model.sideslip(-1.0 if state.position.y > dock.y else 1.0)
		for frame in 16:
			steer(model, 0.0)
			model.step(0.025)
		model.interact()
		if model.snapshot().delivery_ledger.size() != i + 1:
			print("SOLVER delivery failure i=%d state=%s" % [i, model.snapshot()])
			return

static func steer(model, heading: float) -> void:
	var state: Dictionary = model.snapshot()
	var correction: float = angle_difference(state.heading, heading) * 4.0 - state.angular_velocity * 2.0
	model.set_rudder(signf(correction) if absf(correction) > 0.1 else 0.0)

static func navigate(model, target: Vector2, dock_align: bool = false, stroke_shift: float = 0.0) -> void:
	for frame in 2000:
		var state: Dictionary = model.snapshot()
		if state.ended:
			return
		var offset: Vector2 = target - state.position
		var distance := offset.length()
		var heading: float = offset.angle()
		if dock_align:
			heading = 0.0
		if distance < 0.45 and state.speed < 0.6 and (not dock_align or absf(angle_difference(state.heading, 0.0)) < 0.15):
			model.clear_input()
			return
		steer(model, heading)
		var error := absf(angle_difference(state.heading, heading))
		var desired_speed := minf(2.5, distance * 0.9) if error < 0.5 else 0.0
		if dock_align:
			desired_speed = clampf(offset.x, -1.0, 1.0) if error < 0.2 else 0.0
			if error < 0.2 and state.sideslip_ready and absf(offset.y) > 0.2:
				model.sideslip(signf(offset.y * 0.8 - state.velocity.y))
		if state.paddle_ready and fposmod(state.elapsed, 0.5) >= stroke_shift:
			if state.forward_speed < desired_speed - 0.35:
				model.paddle(1.0)
			elif state.forward_speed > desired_speed + 0.35:
				model.paddle(-1.0)
		model.step(0.025)
	print("SOLVER waypoint timeout target=%s state=%s" % [target, model.snapshot()])
