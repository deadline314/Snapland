extends RefCounted
## Test-only operator: reaches target orientations with the public select/rotate
## inputs only, pressing again when the helper lock asks for confirmation.
const Model = preload("res://game/minigames/lighthouse_prism_model.gd")
## Chain: no split, the full beam passes all three beacons in series.
const CHAIN := {"p1": 0, "m1": 1, "m2": 3, "m3": 1, "m4": 3, "m5": 0, "g1": 1, "g2": 1}
## Split: one prism split reaches the far pair directly; the south shutter stays shut.
const SPLIT := {"p1": 3, "m1": 1, "m2": 3, "m3": 0, "m4": 0, "m5": 3, "g1": 0, "g2": 0}
## Devil: the same single split, plus the south shutter open to the hidden side beacon.
const DEVIL := {"p1": 3, "m1": 1, "m2": 3, "m3": 0, "m4": 0, "m5": 3, "g1": 0, "g2": 1}

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
	func select(index: int) -> void: tap(KEY_1 + index)
	func rotate() -> void: tap(KEY_E)
	func settle() -> void: tap(KEY_ENTER)
	func undo() -> void: tap(KEY_Z)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func select(index: int) -> void: model.select_element(Model.ELEMENTS[index].id)
	func rotate() -> void: model.operate(1)
	func settle() -> void: model.settle()
	func undo() -> void: model.undo()
	func step(delta: float) -> void: model.step(delta)

static func state_of(snapshot: Dictionary, id: String) -> int:
	for element: Dictionary in snapshot.elements:
		if element.id == id:
			return element.state
	return -1

## Applies `targets` element by element; returns the number of key presses used.
static func arrange(commands, targets: Dictionary, delta: float = 0.2) -> int:
	var presses := 0
	var ids: Array = Model.element_ids()
	for index in ids.size():
		var id: String = ids[index]
		if not targets.has(id):
			continue
		commands.select(index)
		for attempt in 12:
			if state_of(commands.snapshot(), id) == targets[id] or commands.snapshot().ended:
				break
			commands.rotate()
			presses += 1
			commands.step(delta)
	return presses

static func matches(snapshot: Dictionary, targets: Dictionary) -> bool:
	for id in targets:
		if state_of(snapshot, id) != targets[id]:
			return false
	return true
