extends RefCounted
## Test-only stevedore. Plans a stowage with public crate data, then performs it with
## the same cursor/grab/strap/confirm commands a player uses. It never writes model state.
const Model = preload("res://game/minigames/cargo_balance_model.gd")

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
	func move_cursor(offset: Vector2i) -> void:
		for i in absi(offset.x): tap(KEY_D if offset.x > 0 else KEY_A)
		for i in absi(offset.y): tap(KEY_W if offset.y > 0 else KEY_S)
	func grab() -> void: tap(KEY_SPACE)
	func toggle_strap() -> void: tap(KEY_F)
	func confirm() -> void: tap(KEY_ENTER)
	func step(delta: float) -> void: session._process(delta)

class ModelCommands extends RefCounted:
	var model = Model.new()
	func _init(assisted: bool = false, variant: int = 0) -> void: model.reset(assisted, variant)
	func snapshot() -> Dictionary: return model.snapshot()
	func move_cursor(offset: Vector2i) -> void: model.move_cursor(offset)
	func grab() -> void: model.grab()
	func toggle_strap() -> void: model.toggle_strap()
	func confirm() -> void: model.confirm()
	func step(delta: float) -> void: model.step(delta)

static func hold_x(cell: Vector2i) -> float:
	return Model.HOLD_X[cell.x - Model.PIER_COLUMNS]

static func sensitivity_of(crates: Array, cells: Dictionary) -> float:
	var total := 0.0
	var top := 0.0
	for crate: Dictionary in crates:
		if cells.has(crate.id):
			total += crate.weight
			if cells[crate.id].y == 1: top += crate.weight
	return Model.HEEL_PER_MOMENT * (1.0 + Model.TOP_FACTOR * top / maxf(1.0, total))

static func heel_of(crates: Array, cells: Dictionary) -> float:
	var moment := 0.0
	for crate: Dictionary in crates:
		if cells.has(crate.id):
			moment += crate.weight * hold_x(cells[crate.id])
	return moment * sensitivity_of(crates, cells)

## Exhaustive stowage: pier-top crates go to the floor, first-port crates are never
## buried under second-port crates, and both legs start nearly level.
static func plan(state: Dictionary) -> Dictionary:
	var crates: Array = state.crates
	var first: String = state.port_order[0]
	var cells: Array[Vector2i] = []
	for row in 2:
		for column in Model.HOLD_COLUMNS:
			cells.append(Vector2i(Model.PIER_COLUMNS + column, row))
	var best: Dictionary = {}
	var best_cost := INF
	var stack: Array = [[{}, 0]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var assigned: Dictionary = item[0]
		var index: int = item[1]
		if index == crates.size():
			var cost := _cost(crates, assigned, first)
			if cost < best_cost:
				best_cost = cost
				best = assigned.duplicate()
			continue
		var crate: Dictionary = crates[index]
		for cell in cells:
			if assigned.values().has(cell):
				continue
			if crate.cell.y == 1 and cell.y == 1:
				continue
			var next := assigned.duplicate()
			next[crate.id] = cell
			stack.append([next, index + 1])
	return best

static func _cost(crates: Array, cells: Dictionary, first: String) -> float:
	var by_cell: Dictionary = {}
	for id in cells:
		by_cell[cells[id]] = id
	for id in cells:
		var cell: Vector2i = cells[id]
		if cell.y == 1:
			if not by_cell.has(Vector2i(cell.x, 0)):
				return INF
			var below: Dictionary = crates[by_cell[Vector2i(cell.x, 0)]]
			if below.port == first and crates[id].port != first:
				return INF
	var second: Dictionary = {}
	for id in cells:
		if crates[id].port != first:
			second[id] = cells[id]
	var top := 0.0
	for id in cells:
		if cells[id].y == 1: top += crates[id].weight
	return absf(heel_of(crates, cells)) + absf(heel_of(crates, second)) + top * 0.3

static func goto(commands, cell: Vector2i) -> void:
	var cursor: Vector2i = commands.snapshot().cursor
	commands.move_cursor(cell - cursor)

static func carry(commands, from: Vector2i, to: Vector2i) -> void:
	goto(commands, from)
	commands.grab()
	goto(commands, to)
	commands.grab()

static func crate_cell(state: Dictionary, id: int) -> Vector2i:
	for crate: Dictionary in state.crates:
		if crate.id == id:
			return crate.cell
	return Vector2i(-1, -1)

static func occupied(state: Dictionary, cell: Vector2i) -> bool:
	for crate: Dictionary in state.crates:
		if not crate.delivered and crate.cell == cell:
			return true
	return false

static func load_hold(commands, targets: Dictionary) -> void:
	for pass_index in 4:
		for id in targets:
			var state: Dictionary = commands.snapshot()
			var from := crate_cell(state, id)
			var to: Vector2i = targets[id]
			if from == to or occupied(state, from + Vector2i(0, 1)) or occupied(state, to):
				continue
			if to.y == 1 and not occupied(state, Vector2i(to.x, 0)):
				continue
			carry(commands, from, to)

## Unloads the port's crates, first restacking any crate that buries one of them.
static func unload(commands, port: String) -> void:
	for pass_index in 8:
		var state: Dictionary = commands.snapshot()
		var pending := false
		for crate: Dictionary in state.crates:
			if crate.port != port or crate.delivered or crate.cell.x < Model.PIER_COLUMNS:
				continue
			pending = true
			state = commands.snapshot()
			var cell: Vector2i = crate_cell(state, crate.id)
			if occupied(state, cell + Vector2i(0, 1)):
				var spare := Vector2i(-1, -1)
				for column in Model.HOLD_COLUMNS:
					for row in 2:
						var to := Vector2i(Model.PIER_COLUMNS + column, row)
						if spare.x < 0 and to.x != cell.x and not occupied(state, to) and (row == 0 or occupied(state, Vector2i(to.x, 0))):
							spare = to
				carry(commands, cell + Vector2i(0, 1), spare)
				state = commands.snapshot()
				if occupied(state, cell + Vector2i(0, 1)):
					continue
			var free := Vector2i(-1, -1)
			for row in 2:
				for column in Model.PIER_COLUMNS:
					var pier := Vector2i(column, row)
					if free.x < 0 and not occupied(state, pier) and (row == 0 or occupied(state, Vector2i(column, 0))):
						free = pier
			carry(commands, cell, free)
		if not pending:
			return

## During each forecast, moves the single top crate that best levels the coming wave.
static func counter_wave(commands, force_shift: bool) -> void:
	var state: Dictionary = commands.snapshot()
	var wave: Dictionary = state.upcoming
	var best_move: Array = []
	var cells: Dictionary = {}
	for crate: Dictionary in state.crates:
		if not crate.delivered and crate.cell.x >= Model.PIER_COLUMNS:
			cells[crate.id] = crate.cell
	var current := absf(heel_of(state.crates, cells) + wave.direction * wave.strength * sensitivity_of(state.crates, cells))
	var best_value := current if not force_shift else INF
	for crate: Dictionary in state.crates:
		if not cells.has(crate.id) or crate.strapped or occupied(state, crate.cell + Vector2i(0, 1)):
			continue
		for column in Model.HOLD_COLUMNS:
			for row in 2:
				var to := Vector2i(Model.PIER_COLUMNS + column, row)
				if to == crate.cell or occupied(state, to) or (row == 1 and (not occupied(state, Vector2i(to.x, 0)) or Vector2i(to.x, 0) == crate.cell)):
					continue
				var trial := cells.duplicate()
				trial[crate.id] = to
				var value := absf(heel_of(state.crates, trial) + wave.direction * wave.strength * sensitivity_of(state.crates, trial))
				if absf(heel_of(state.crates, trial)) > Model.SAFE_HEEL - 2.0:
					continue
				if value < best_value:
					best_value = value
					best_move = [crate.cell, to]
	if not best_move.is_empty():
		carry(commands, best_move[0], best_move[1])

static func sail(commands, delta: float, shift: bool) -> void:
	var countered: Dictionary = {}
	for frame in roundi((Model.SAIL_SECONDS + 1.0) / delta):
		var state: Dictionary = commands.snapshot()
		if state.ended or state.phase != "sailing":
			return
		var wave: Dictionary = state.upcoming
		if shift and not wave.is_empty() and wave.visible and not countered.has(wave.index):
			countered[wave.index] = true
			counter_wave(commands, countered.size() == 1)
		commands.step(delta)

static func solve(commands, shift: bool = true, delta: float = 1.0 / 60.0) -> bool:
	var targets := plan(commands.snapshot())
	if targets.is_empty():
		return false
	load_hold(commands, targets)
	commands.confirm()
	for leg in 2:
		sail(commands, delta, shift)
		var state: Dictionary = commands.snapshot()
		if state.ended:
			break
		unload(commands, state.port)
		if not commands.snapshot().ended:
			commands.confirm()
	return commands.snapshot().success
