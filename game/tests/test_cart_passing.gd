extends SceneTree

const Model = preload("res://game/minigames/cart_passing_model.gd")
const WEST := Vector2i.LEFT
const EAST := Vector2i.RIGHT
const NORTH := Vector2i.UP
const SOUTH := Vector2i.DOWN

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_clearance()
	_check_pass_witness()
	_check_undo_and_assist()
	_check_completion()
	_check_time_and_restart()
	if _failures.is_empty():
		print("PASS: cart passing full footprints and one-pocket reciprocal clearance (%d checks)" % _checks)
	else:
		for failure in _failures:
			push_error(failure)
	quit(int(not _failures.is_empty()))


func _check_clearance() -> void:
	var model := Model.new()
	var start := model.snapshot()
	_check(_cart(start, 0).length == 3 and _cart(start, 1).length == 2 and _cart(start, 2).length == 5,
		"three distinct full footprints are part of the board state")
	_check(not model.select(-1) and not model.move(Vector2i(1, 1)) and not model.unload(),
		"invalid selection, diagonal skips and arbitrary unloading leave the board untouched")
	_block(model, EAST, &"blocked_cart")
	_block(model, NORTH, &"blocked_length")
	_move(model, WEST)
	_block(model, NORTH, &"blocked_length")
	_move(model, WEST)
	_check(model.snapshot().move_options[2].allowed, "preview finds the step where the whole short body first fits")
	_move(model, NORTH)
	_block(model, NORTH, &"blocked_edge")
	_block(model, EAST, &"blocked_length")
	_check(model.snapshot().pass_mask == 0 and model.snapshot().pocket_entries == 1, "parking alone records no opposing pass")
	_check(start.carts[0].x == 7 and start.pocket_entries == 0, "an earlier snapshot keeps its own advance and phase")
	model.reset(false, 1)
	_check(model.select(2), "the longest cart can be selected")
	_block(model, WEST, &"blocked_cart")
	_block(model, NORTH, &"blocked_wall")
	_move(model, EAST)
	_check(not model.unload(), "the rear load cannot detach one tile short of the physical pad")
	_move(model, EAST)
	_check(model.snapshot().unload_kind == &"tail", "the rear tile on the pad explicitly enables partial unloading")
	_block(model, SOUTH, &"blocked_length")
	_check(model.unload(), "station unload detaches the rear load")
	var lightened := _cart(model.snapshot(), 2)
	_check(lightened.x == 8 and lightened.length == 4 and lightened.tail_unloaded and model.snapshot().deliveries == 0,
		"the rear load releases occupied cell 12 without shifting the nose or scoring a delivery")
	_check(not model.unload(), "the same cargo cannot be detached twice")
	_move(model, SOUTH)
	_check(_cart(model.snapshot(), 2).rect == Rect2i(8, 2, 4, 1), "the shortened footprint fits the second board's bay")


func _check_pass_witness() -> void:
	var model := Model.new()
	_park_short(model)
	_check(model.select(1), "the opposing two-tile cart can be selected")
	_move(model, WEST, 6)
	_check(_cart(model.snapshot(), 1).x == 4 and model.snapshot().pass_mask == 0,
		"partial longitudinal overlap keeps the pass unproven until the tail clears")
	_check(model.select(0), "the waiting side cart remains selectable")
	_block(model, SOUTH, &"blocked_cart")
	_check(model.select(1), "resume the active approach")
	_move(model, WEST)
	_check(model.snapshot().pass_mask == 1 and model.snapshot().score == 0,
		"an actual first westbound clearance records its pair without an early award")
	_move(model, WEST)
	_move(model, EAST, 2)
	_move(model, WEST, 2)
	_check(model.snapshot().pass_mask == 1, "crossing the same pair again does not invent a second opposition")
	_move(model, WEST)
	_check(model.unload(), "the short opposing cart reaches its real unloading dock")
	_check(not model.select(1) and model.snapshot().selected == 2,
		"a delivered cart vacates occupancy and selection advances to the remaining active cart")


func _check_undo_and_assist() -> void:
	var model := Model.new()
	model.reset(true, 0)
	_check(not model.assist_toward_pocket(-1) and not model.undo(), "unmarked assistance and an empty history do nothing")
	_check(model.assist_toward_pocket(0) and _cart(model.snapshot(), 0).x == 6 and model.snapshot().pocket_entries == 0,
		"a named pocket helper performs one actual westward step, never a teleport")
	_check(model.assist_toward_pocket(0) and model.assist_toward_pocket(0), "repeat the same explicit choice to enter the real bay")
	_check(model.snapshot().pocket_entries == 1 and model.undo() and model.snapshot().pocket_entries == 0,
		"undo restores the lane, physical position and pocket count")
	_move(model, NORTH)
	_check(model.select(1), "adjacent opponent can be moved after the undo")
	_move(model, WEST, 7)
	_check(model.snapshot().pass_mask == 1 and model.undo() and model.snapshot().pass_mask == 0 and _cart(model.snapshot(), 1).x == 4,
		"undo of the tail-clearing step restores the real previous witness")
	_move(model, WEST, 3)
	_check(model.unload() and model.snapshot().score == 150, "a finished dock unload gives exactly one delivery")
	_check(model.undo() and model.snapshot().score == 0 and model.snapshot().selected == 1
		and not _cart(model.snapshot(), 1).delivered and model.snapshot().pass_mask == 1,
		"undo the unload restores occupying body, selection and the independently earned pass")
	_check(model.unload(), "the same cart can complete again after undo without duplicate points")
	_finish_short_route(model, true)
	_expect_complete(model, 550, 1, 0)
	model.reset(true, 1)
	_check(model.select(2) and not model.assist_toward_pocket(0) and model.snapshot().feedback == &"blocked_length",
		"the helper cannot shrink a long load or bypass a narrow bay")
	_move(model, EAST, 2)
	_check(model.unload() and model.undo() and _cart(model.snapshot(), 2).length == 5,
		"undo reattaches the cargo and restores its occupied tile")
	_block(model, SOUTH, &"blocked_length")
	model.reset(true, 0)
	for _step in range(Model.UNDO_LIMIT + 6):
		_move(model, WEST if _step % 2 == 0 else EAST)
	_check(model.snapshot().undo_count == Model.UNDO_LIMIT, "assistance history holds only the last sixteen actual steps")
	for _step in Model.UNDO_LIMIT:
		_check(model.undo(), "one stored action is recovered at a time")
	_check(not model.undo() and model.snapshot().moves == 6, "old discarded history cannot create or remove an action")


func _check_completion() -> void:
	var model := Model.new()
	for assisted: bool in [false, true]:
		for layout in range(2):
			model.reset(assisted, layout)
			_complete_layout(model, layout)
			_expect_complete(model, 550, 1, 0)
			_check(not model.move(NORTH) and not model.undo() and not model.restart() and not model.unload(),
				"completed board rejects later inputs and keeps its result stable")
			model.reset(assisted, layout)
			_check(model.select(1), "the alternative route can use the smaller cart as well")
			_move(model, SOUTH if layout == 0 else NORTH)
			_move(model, NORTH if layout == 0 else SOUTH)
			_complete_layout(model, layout)
			_expect_complete(model, 450, 2, 0)


func _check_time_and_restart() -> void:
	var model := Model.new()
	model.step(NAN)
	model.step(INF)
	model.step(-9.0)
	_check(model.snapshot().elapsed == 0.0 and not model.undo() and not model.assist_toward_pocket(0),
		"invalid elapsed updates and non-assisted requests do not advance a normal puzzle")
	_park_short(model)
	_check(model.select(1), "a partial ordinary run can still be inspected on timeout")
	_move(model, WEST, 9)
	_check(model.unload(), "deliver one cart before the timer")
	model.step(Model.TIME_LIMIT - 0.5)
	_check(model.snapshot().status == &"live" and model.snapshot().time_remaining == 0.5,
		"approaching time limit keeps the current board active")
	model.step(0.5)
	_check(model.snapshot().status == &"time_up" and model.snapshot().score == 150 and not model.snapshot().qualified
		and not model.move(WEST) and not model.unload(), "timeout retains real completed work but cannot award the whole puzzle")
	model.reset(true, 1)
	model.step(Model.TIME_LIMIT * 2.0)
	_check(model.snapshot().status == &"live" and model.snapshot().time_limit == 0,
		"assisted board has no movement deadline")
	_move(model, EAST)
	_check(model.restart() and model.snapshot().moves == 0 and model.snapshot().restarts == 1 and not model.undo(),
		"restart clears local progress and undo but retains the challenge-disqualifying reset within the round")
	_complete_layout(model, 1)
	_expect_complete(model, 450, 1, 1)


func _complete_layout(model: Model, layout: int) -> void:
	if layout == 0:
		_park_short(model)
		_finish_short_route(model)
	else:
		_check(model.select(2), "select the long cart for the second board")
		_move(model, EAST, 2)
		_check(model.unload(), "unload the detachable rear load before moving sideways")
		_move(model, SOUTH)
		_check(model.select(1), "free the lane for the trailing eastbound cart")
		_move(model, EAST, 11)
		_check(model.unload(), "an eastbound short cart unloads at its marked east dock")
		_check(model.select(0), "the trailing cart now has its eastbound path")
		_move(model, EAST, 14)
		_check(model.unload(), "the second eastbound cart unloads at its own dock")
		_check(model.select(2), "the original opposing cart can now leave the bay")
		_move(model, NORTH)
		_move(model, WEST, 8)
		_check(model.unload(), "the shortened opposing cart unloads across the entire lane")


func _park_short(model: Model) -> void:
	_check(model.select(0), "select the three-tile cart")
	_move(model, WEST, 2)
	_move(model, NORTH)


func _finish_short_route(model: Model, short_delivered: bool = false) -> void:
	if not short_delivered:
		_check(model.select(1), "select the nearer westbound cart")
		_move(model, WEST, 9)
		_check(model.unload(), "the nearer cart unloads at its west dock")
	_check(model.select(2), "select the following westbound cart")
	_move(model, WEST, 12)
	_check(model.unload(), "the full long cart clears the pocket to its west dock")
	_check(model.select(0), "select the waiting cart once the full lane is clear")
	_move(model, SOUTH)
	_move(model, EAST, 9)
	_check(model.unload(), "the waiting cart unloads at the east dock")


func _expect_complete(model: Model, score: int, entries: int, restarts: int) -> void:
	var state := model.snapshot()
	_check(state.status == &"won" and state.deliveries == 3 and state.score == score
		and state.qualified == (score == 550) and state.pocket_entries == entries and state.restarts == restarts
		and state.pass_mask == state.required_pass_mask,
		"layout %d assist %s finishes %d deliveries for %d with %d entries and %d resets, observed %s"
		% [state.layout, state.assisted, state.deliveries, score, entries, restarts,
			[state.status, state.score, state.pocket_entries, state.pass_mask, state.required_pass_mask]])


func _move(model: Model, direction: Vector2i, count: int = 1) -> void:
	for _step in count:
		var before := model.snapshot()
		var expected: Rect2i = before.carts[before.selected].rect
		expected.position += direction
		var moved := model.move(direction)
		var actual := model.snapshot()
		_check(moved and actual.carts[before.selected].rect == expected, "legal %s step changes the real footprint by one tile (%s)"
			% [direction, actual.feedback])
		_check(_valid_board(actual), "every accepted step keeps all live footprints inside real floor without overlap")


func _block(model: Model, direction: Vector2i, reason: StringName) -> void:
	var before := model.snapshot()
	var preview: Dictionary = before.move_options[Model.DIRECTIONS.find(direction)]
	_check(not preview.allowed and preview.reason == reason and not model.move(direction),
		"preview and actual %s move agree on %s (observed %s)" % [direction, reason, preview.reason])
	var after := model.snapshot()
	_check(before.carts == after.carts and before.moves == after.moves and before.pass_mask == after.pass_mask
		and before.pocket_entries == after.pocket_entries, "a blocked move never changes occupancy, witness or undo")


func _valid_board(state: Dictionary) -> bool:
	var bounds := Rect2i(Vector2i.ZERO, state.size)
	for cart: Dictionary in state.carts:
		if cart.delivered: continue
		var rect: Rect2i = cart.rect
		if not bounds.encloses(rect): return false
		if rect.position.y != state.lane_y:
			var in_pocket := false
			for pocket: Dictionary in state.pockets:
				var pocket_rect: Rect2i = pocket.rect
				in_pocket = in_pocket or pocket_rect.encloses(rect)
			if not in_pocket: return false
		for other: Dictionary in state.carts:
			if other.id != cart.id and not other.delivered and rect.intersects(other.rect): return false
	return true


func _cart(state: Dictionary, index: int) -> Dictionary:
	return state.carts[index]


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
