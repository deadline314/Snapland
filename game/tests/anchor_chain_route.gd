extends RefCounted
## Test-only rigger: tries wrap plans on scratch models, then performs the winning one
## with the same select/place/reel inputs a player uses. It never writes live state.
const Model = preload("res://game/minigames/anchor_chain_model.gd")

class SessionCommands extends RefCounted:
	var session: Control
	var _reeling := false
	func _init(value: Control) -> void: session = value
	func snapshot() -> Dictionary: return session.active_driver.snapshot()
	func tap(code: Key) -> void:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.pressed = pressed
			session._unhandled_input(event)
	func select_next(step: int) -> void: tap(KEY_E if step > 0 else KEY_Q)
	func place() -> void: tap(KEY_F)
	func recall() -> void: tap(KEY_X)
	func set_reeling(value: bool) -> void:
		if value == _reeling:
			return
		_reeling = value
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = value
		session._unhandled_input(event)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func select_next(step: int) -> void: model.select_next(step)
	func place() -> void: model.place()
	func recall() -> void: model.recall()
	func set_reeling(value: bool) -> void: model.set_reeling(value)
	func step(delta: float) -> void: model.step(delta)

static func choose(commands, target: int) -> void:
	for i in 12:
		if commands.snapshot().selected == target:
			return
		commands.select_next(1)

static func rig(commands, plan: Array) -> void:
	for target in plan:
		choose(commands, target)
		commands.place()

static func reel(commands, seconds: float, delta: float) -> void:
	commands.set_reeling(true)
	for i in roundi(seconds / delta):
		if commands.snapshot().ended or commands.snapshot().anchor < 0:
			break
		commands.step(delta)
	commands.set_reeling(false)

## Scratch search: wrap sequences (posts) then one anchor; `double` wants a repeated post.
static func plan(variant: int, assisted: bool, double: bool) -> Array:
	var posts: int = Model.LAYOUTS[variant].posts.size()
	var anchors: int = Model.LAYOUTS[variant].anchors.size()
	var candidates: Array = []
	for first in posts:
		candidates.append([first])
		for second in posts:
			candidates.append([first, second])
	for wraps: Array in candidates:
		var repeated: bool = wraps.size() == 2 and wraps[0] == wraps[1]
		if double != repeated:
			continue
		for anchor in anchors:
			var scratch := ModelCommands.new(assisted, variant)
			var steps: Array = wraps.duplicate()
			steps.append(posts + anchor)
			rig(scratch, steps)
			reel(scratch, 60.0, 1.0 / 30.0)
			if scratch.snapshot().success:
				return steps
	return []

static func solve(commands, devil: bool = false, delta: float = 1.0 / 60.0) -> bool:
	var state: Dictionary = commands.snapshot()
	var steps := plan(state.variant, state.assisted, devil)
	if steps.is_empty():
		return false
	rig(commands, steps)
	reel(commands, 80.0, delta)
	return commands.snapshot().success
