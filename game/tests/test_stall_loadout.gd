extends SceneTree

const Model = preload("res://game/minigames/stall_loadout_model.gd")
const ARRANGEMENTS := [
	[
		[Vector3i(2, 0, 1), 0], [Vector3i(4, 0, 0), 0], [Vector3i(5, 0, 1), 0],
		[Vector3i(0, 0, 3), 0], [Vector3i(0, 1, 3), 0],
	],
	[
		[Vector3i(3, 0, 1), 0], [Vector3i(0, 0, 0), 0], [Vector3i(1, 0, 1), 1],
		[Vector3i(0, 0, 3), 0], [Vector3i(0, 1, 3), 0],
	],
]
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_geometry()
	for layout in ARRANGEMENTS.size():
		_test_round(layout, false)
		_test_round(layout, true)
		_test_blocked(layout)
	_test_timeout()
	if failures == 0:
		print("PASS: stall loadout fit, nesting, strap geometry, and pot extraction")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func _test_geometry() -> void:
	var model := Model.new()
	for layout in ARRANGEMENTS.size():
		model.reset(false, layout)
		for item in Model.PIECE_COUNT:
			for angle in range(-4, 8):
				var offsets := model.shape(item, angle)
				_check(offsets.size() == model.shape(item, 0).size(), "rotation preserves occupied volume")
				var unique := {}
				var minimum := Vector2i(Model.DECK.x, Model.DECK.z)
				for offset in offsets:
					unique[offset] = true
					minimum.x = mini(minimum.x, offset.x)
					minimum.y = mini(minimum.y, offset.z)
				_check(minimum == Vector2i.ZERO and unique.size() == offsets.size(), "every rotation has a normalized distinct footprint")
		_check(model.shape(-1, 0).is_empty() and model.shape(Model.PIECE_COUNT, 0).is_empty(), "invalid selectors cannot index a footprint")
		_check(model.place_reason(0, Vector3i(6, 0, 0), 0) == &"outside", "rim checks the entire pot")
		_check(model.place_reason(0, Vector3i(0, 1, 0), 0) == &"unsupported", "unanchored pot cannot float")
		_check(model.place(0, Vector3i.ZERO, 0), "first legal placement")
		_check(model.place_reason(1, Vector3i.ZERO, 0) == &"collision", "overlap reports real occupied voxels")
		_check(not model.toggle_straps() and model.snapshot().feedback == &"incomplete", "cannot tie an incomplete load")
		_check(model.undo() and model.snapshot().placed == 0, "undo restores empty load")
		_check(not model.undo(), "empty undo refuses")
		for move in 20:
			_check(model.place(0, Vector3i(move % 2, 0, 0), 0), "bounded history can accept sustained placement")
		for _turn in Model.HISTORY_LIMIT:
			_check(model.undo(), "each bounded undo restores prior arrangement")
		_check(not model.undo(), "history is capped")


func _fill(model: Model, layout: int, blocked: bool = false) -> void:
	for item in Model.PIECE_COUNT:
		var anchor: Vector3i = ARRANGEMENTS[layout][item][0]
		var angle: int = ARRANGEMENTS[layout][item][1]
		if blocked and layout == 0 and item in [3, 4]:
			anchor.x = 2
		if blocked and layout == 1 and item == 2:
			anchor.x = 5
		_check(model.place(item, anchor, angle), "layout %d legal item %d" % [layout, item])


func _test_round(layout: int, assisted: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	_fill(model, layout)
	_check(not model.place(3, Vector3i(4, 0, 3), 0) and model.snapshot().feedback == &"unsupported", "can't remove tray's live support")
	_check(model.toggle_straps(), "both bands contact the stable load")
	var tied := model.snapshot()
	_check(tied.placed == 5 and tied.secured and tied.straps.size() == 2, "two actual cross sections carry tied load")
	_check(Array(tied.straps[0]).max() >= 1 and Array(tied.straps[1]).max() >= 2, "strap profiles reflect actual upper and lower surfaces")
	_check(not model.undo() and not model.place(2, Vector3i(6, 0, 4), 0), "tied arrangement is immutable")
	_check(model.toggle_straps() and not model.snapshot().secured and model.toggle_straps(), "releasing and retying is reversible")
	_check(model.extract_pot(), "actual bottom pot can leave")
	var result := model.snapshot()
	_check(result.devil and result.placed == 4 and result.pot_path.size() >= 3, "extraction has a real translated path")
	for index in range(1, result.pot_path.size()):
		_check(result.pot_path[index] - result.pot_path[index - 1] == result.exit_direction, "each pot path step follows the aligned door")
	_check(not model.extract_pot() and not model.toggle_straps(), "extraction cannot repeat or untie")
	_check(model.finish() and model.snapshot().success and model.snapshot().ordinary_eligible and model.snapshot().score == 600, "challenge round returns actual rewards")


func _test_blocked(layout: int) -> void:
	var model := Model.new()
	model.reset(false, layout)
	_fill(model, layout, true)
	_check(model.toggle_straps(), "a blocked exit can still be legal cargo")
	var before := model.snapshot()
	_check(not model.extract_pot(), "remaining silhouette really blocks full extraction sweep")
	_check(model.snapshot().feedback == &"exit_blocked" and model.snapshot().pieces == before.pieces, "failed unloading leaves every item in place")
	_check(model.finish() and model.snapshot().score == 450 and not model.snapshot().devil, "blocked exit grants ordinary clear only")


func _test_timeout() -> void:
	var model := Model.new()
	model.step(INF)
	model.step(NAN)
	model.step(-4.0)
	_check(model.snapshot().elapsed == 0.0, "invalid time progress is ignored")
	model.step(Model.TIME_LIMIT)
	_check(model.snapshot().ended and not model.snapshot().ordinary_eligible, "idle timeout earns nothing")
	model.reset()
	_check(model.place(0, Vector3i.ZERO, 0), "initial active timeout setup")
	model.step(Model.TIME_LIMIT)
	_check(model.snapshot().ended and model.snapshot().ordinary_eligible and not model.snapshot().success, "a valid loaded move permits ordinary participation")
	model.reset(true)
	model.step(Model.TIME_LIMIT * 5.0)
	_check(not model.snapshot().ended and model.snapshot().elapsed == 0.0, "assist has no deadline")
	model.reset()
	_fill(model, 0, true)
	_check(model.toggle_straps(), "timeout can accept a safely secured load")
	model.step(Model.TIME_LIMIT)
	_check(model.snapshot().ended and model.snapshot().success and model.snapshot().score == 450, "secured load settles to ordinary at timeout")
