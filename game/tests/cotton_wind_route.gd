extends RefCounted

# World-space targets shared by Model, input and Session tests.
const DT := 1.0 / 30.0
const NEAR_Z := 56.0

static func target(state: Dictionary, rejoin: bool) -> Vector2:
	if rejoin and state.rejoins == 0:
		if state.tail.is_empty():
			return Vector2(60, 146)
		var tip: Vector3 = state.tail.free_end
		var opposite_offset := 60.0 if state.tail.anchor_band == 0 else -60.0
		return Vector2(tip.x - opposite_offset, tip.z)
	var lane := floori(state.elapsed / 3.0) % 3
	return Vector2((lane - 1) * 60.0, NEAR_Z)

static func solve(model, rejoin: bool) -> Dictionary:
	model.set_spin(1)
	for i in 3602:
		var state: Dictionary = model.snapshot()
		if state.ended:
			return state
		if state.uniform and (not rejoin or state.rejoins > 0):
			model.finish()
		else:
			model.move_stick_to(target(state, rejoin))
			model.step(DT)
	return model.snapshot()
