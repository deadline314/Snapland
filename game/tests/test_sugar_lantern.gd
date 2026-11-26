extends SceneTree

const Model = preload("res://game/minigames/sugar_lantern_model.gd")
const HOLD := 1.0 / 60.0
const PERIMETER := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7)]
const THIN_BRACES := [Vector2i(0, 4), Vector2i(0, 7)]
const TAIL := [Vector2i(7, 8), Vector2i(8, 9)]

var _checks := 0
var _errors: Array[String] = []


func _initialize() -> void:
	var model := Model.new()
	_test_geometry(model)
	for layout in 2:
		_test_branching(model, layout)
		_test_tail(model, layout, false)
		_test_crack_and_repair(model, layout)
	_test_temperature_and_budget(model)
	_test_tail(model, 1, true)
	_test_step_consistency_and_finish(model)
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: sugar lantern geometry, structural lift, cooling, and articulated tail")
	print("%d checks, %d failures" % [_checks, _errors.size()])
	quit(int(not _errors.is_empty()))


func _test_geometry(model: Model) -> void:
	var fox := model.snapshot()
	model.reset(false, 1)
	var deer := model.snapshot()
	_check(fox.name != deer.name and fox.pegs.size() == 11 and deer.pegs.size() == 11
		and fox.pegs[7].x > fox.pegs[4].x and deer.pegs[7].x < deer.pegs[4].x
		and fox.void_center != deer.void_center and fox.void_radii != deer.void_radii,
		"two authored animals have distinct peg and protected hole geometry")
	var detached: PackedVector2Array = deer.pegs
	detached[0] = Vector2.ZERO
	_check(model.snapshot().pegs[0] != Vector2.ZERO and deer.edges.is_read_only(),
		"published geometry and nested edge snapshots protect internal state")
	_check(not model.place_strand(-1, 3) and not model.place_strand(1, 11) and not model.place_strand(1, 1),
		"invalid and identical pegs are rejected")
	_check(not model.place_strand(0, 6) and model.snapshot().feedback.contains("太長"), "overlong strokes are refused")
	_check(not model.place_strand(4, 7) and model.snapshot().feedback.contains("留空"), "a stroke cannot pass through its real negative space")
	_check(not model.place_strand(2, 8) and model.snapshot().feedback.contains("尾巴"), "an arbitrary tail anchor cannot create articulation")
	_check(model.snapshot().sugar == Model.SUGAR_MAX and not model.snapshot().engaged and model.snapshot().edges.is_empty(),
		"failed edits preserve both stock and activity qualification")
	_check(model.place_strand(2, 4) and not model.place_strand(3, 10) and model.snapshot().feedback.contains("相交"),
		"crossing sticky strands require a real shared peg")
	_check(model.place_strand(4, 2, false) and model.snapshot().edges[0].thickness == 2.0
		and model.snapshot().edges.size() == 1 and model.snapshot().edges[0].is_read_only(),
		"re-tracing an existing strand doubles the same line without cloning a joint")
	var doubled := model.snapshot()
	_check(not model.place_strand(2, 4, true) and model.snapshot().sugar == doubled.sugar,
		"material cannot be wasted on a strand that already reached double gauge")
	model.set_lift(true)
	_check(not model.snapshot().lifting and not model.snapshot().ordinary_eligible and model.snapshot().feedback.contains("吊扣"),
		"a detached edge is real activity without credit for an unlifted object")
	model.clear_input()


func _test_branching(model: Model, layout: int) -> void:
	model.reset(false, layout)
	_place_edges(model, PERIMETER)
	_place_edges(model, THIN_BRACES)
	var wet := model.snapshot()
	_check(wet.joined and wet.wet == 9 and wet.engaged and not wet.ordinary_eligible,
		"both load paths share real joined pegs while surface is still wet (%d)" % layout)
	model.set_lift(true)
	_check(not model.snapshot().lifting and not model.snapshot().ordinary_eligible and model.snapshot().feedback.contains("凝固"),
		"attempting a wet lift neither scores nor breaks the graph (%d)" % layout)
	_advance(model, 2.10)
	_check(model.snapshot().wet == 0 and not model.snapshot().lifting and model.snapshot().edges[0].cure == 1.0,
		"held failed press waits for release and actual cooling completes (%d)" % layout)
	model.clear_input()
	model.set_lift(true)
	_advance(model, 0.45)
	_check(model.snapshot().lift_height > 0.2 and model.snapshot().lift_height < 1.0
		and model.snapshot().ordinary_eligible and _peak_stress(model.snapshot()) > 0.12,
		"actual rise changes the stress and starts valid participation (%d)" % layout)
	model.clear_input()
	_check(model.snapshot().lift_height == 0.0 and model.snapshot().lift_hold == 0.0 and model.snapshot().joined
		and model.snapshot().sugar == wet.sugar and not model.snapshot().ended,
		"released lift keeps workshop strands and leaves the round active (%d)" % layout)
	model.set_lift(true)
	_advance(model, 2.4)
	var result := model.snapshot()
	_check(result.ended and result.success and result.score == Model.BODY_POINTS and result.lift_height == 1.0
		and result.lift_hold > 1.25 and not result.tail_proven and not result.devil and _peak_stress(result) < 1.0,
		"materials-saving three-support network lifts the entire animal (%d)" % layout)
	print("BRANCHED layout=%d spent=%d stress=%.4f" % [layout, Model.SUGAR_MAX - result.sugar, _peak_stress(result)])


func _test_tail(model: Model, layout: int, assisted: bool) -> void:
	model.reset(assisted, layout)
	for pair: Vector2i in PERIMETER:
		_check(model.place_strand(pair.x, pair.y, pair == Vector2i(0, 1)), "body strand %s survives layout geometry" % pair)
	_check(model.place_strand(0, 7, true), "double tail-side support makes a second distinct load path")
	var remaining: int = model.snapshot().sugar
	_check(remaining > 0 and not model.snapshot().tail_ready and model.snapshot().joined, "body uses a real partial budget before tail construction")
	_check(model.place_strand(7, 8) and not model.snapshot().tail_ready and not model.snapshot().tail_proven,
		"one attached stub is not a completed articulated tail")
	_check(model.place_strand(8, 9) and model.snapshot().sugar < remaining and model.snapshot().tail_ready,
		"leftover material extends the body through the actual hinge to the tip")
	_advance(model, 2.05)
	model.set_lift(true)
	_advance(model, 1.0)
	var swing := model.snapshot()
	_check(swing.lifting and swing.tail_ready and absf(swing.tail_angle) > 0.20 and swing.tail_swing > 0.20
		and not swing.tail_proven and swing.score == 0 and _peak_stress(swing) < 1.0,
		"lift creates real bounded tail motion, with reward waiting for stable hold")
	_check(swing.tail_angle > 0.0 if layout == 0 else swing.tail_angle < 0.0,
		"gravity turns opposing animal tails toward the board's downward direction")
	_advance(model, 1.3)
	var result := model.snapshot()
	_check(result.ended and result.success and result.devil and result.tail_proven
		and result.score == Model.BODY_POINTS + Model.TAIL_POINTS and result.tail_swing > 0.27
		and _peak_stress(result) < 1.0 and result.ordinary_eligible,
		"alternate doubled circuit holds the complete moving-tail challenge (%d, assisted %s)" % [layout, assisted])
	print("ARTICULATED layout=%d assisted=%s spent=%d stress=%.4f swing=%.4f" % [layout, assisted,
		Model.SUGAR_MAX - result.sugar, _peak_stress(result), result.tail_swing])


func _test_crack_and_repair(model: Model, layout: int) -> void:
	model.reset(false, layout)
	_place_edges(model, PERIMETER)
	_advance(model, 2.05)
	model.set_lift(true)
	_advance(model, 2.3)
	var failed := model.snapshot()
	_check(not failed.ended and not failed.success and failed.failed_edge >= 0 and not failed.joined
		and failed.lift_height == 0.0 and failed.feedback.contains("裂開"),
		"a cured, fully connected but under-braced chain structurally cracks (%d)" % layout)
	if failed.failed_edge < 0:
		return
	var crack: Dictionary = failed.edges[failed.failed_edge]
	_check(crack.cracked and crack.stress >= 1.0 and failed.ordinary_eligible and failed.mistakes == 1,
		"highlighted failed strand is the actual overload, not a fictitious timer")
	model.clear_input()
	_check(model.rewarm(), "warm repair can be requested after an overload")
	_check(not model.place_strand(crack.a, crack.b), "hot work is unavailable during rewarming")
	_advance(model, 1.0)
	_check(model.place_strand(crack.a, crack.b, false) and model.snapshot().failed_edge < 0
		and not model.snapshot().edges[failed.failed_edge].cracked and model.snapshot().edges[failed.failed_edge].cure == 0.0,
		"real repair replaces the failed connection and must cure again")
	_place_edges(model, THIN_BRACES)
	_advance(model, 2.1)
	model.set_lift(true)
	_advance(model, 2.3)
	_check(model.snapshot().success and model.snapshot().score == Model.BODY_POINTS and model.snapshot().mistakes == 1,
		"reinforced graph can be lifted after a real failure without resetting the round")


func _test_temperature_and_budget(model: Model) -> void:
	model.reset(false, 0)
	_check(model.place_strand(0, 1), "hot sugar lays the first real strand")
	_advance(model, 44.0)
	var cold := model.snapshot()
	_check(cold.engaged and cold.heat < Model.POUR_HEAT and cold.edges[0].cure == 1.0
		and not model.place_strand(1, 2) and model.snapshot().sugar == cold.sugar,
		"reservoir cools independently of the finished strand and rejects a cold pour")
	_check(model.rewarm() and not model.rewarm(), "rewarm does not stack or consume sugar")
	_advance(model, 0.40)
	_check(model.snapshot().rewarm_remaining > 0.0 and model.snapshot().heat > cold.heat,
		"rewarming visibly progresses before the bowl is ready")
	_advance(model, 0.64)
	_check(model.snapshot().heat > 0.99 and model.snapshot().sugar == cold.sugar and model.place_strand(1, 2),
		"standard reheat restores actual flow without refilling limited material")
	model.reset(false, 0)
	for edge: Vector2i in PERIMETER:
		model.place_strand(edge.x, edge.y, true)
	var at_limit := model.snapshot()
	_check(not model.place_strand(0, 7, true) and model.snapshot().sugar == at_limit.sugar
		and model.snapshot().feedback.contains("不夠"), "standard stock blocks a real over-budget reinforcement")
	_check(model.rewarm(), "standard exhausted bowl can rewarm")
	_advance(model, 1.1)
	_check(model.snapshot().sugar == at_limit.sugar, "normal rewarm does not erase resource tradeoffs")
	model.reset(true, 0)
	_place_edges(model, PERIMETER)
	_check(model.snapshot().sugar < Model.SUGAR_MAX and model.rewarm(), "assisted play still spends material before refilling")
	_advance(model, 1.03)
	_check(model.snapshot().sugar == Model.SUGAR_MAX and model.snapshot().edges.size() == 7,
		"assistance refills actual stock and preserves placed sugar")


func _test_step_consistency_and_finish(model: Model) -> void:
	model.reset(false, 1)
	var other := Model.new()
	other.reset(false, 1)
	_place_edges(model, PERIMETER)
	_place_edges(other, PERIMETER)
	_place_edges(model, THIN_BRACES)
	_place_edges(other, THIN_BRACES)
	_advance(model, 2.0)
	_advance(other, 2.0, HOLD / 2.0)
	model.set_lift(true)
	other.set_lift(true)
	_advance(model, 2.3)
	_advance(other, 2.3, HOLD / 2.0)
	_check(model.snapshot() == other.snapshot(), "subdividing input time produces the same deterministic graph and result")
	var result := model.snapshot()
	model.step(10.0)
	_check(not model.place_strand(7, 8) and not model.rewarm() and model.snapshot() == result,
		"finished model is immutable until real restart")
	model.reset(false, 0)
	model.step(NAN)
	model.step(-10.0)
	_check(model.snapshot().elapsed == 0.0 and not model.snapshot().engaged, "invalid time and idle input cannot advance or score")
	_advance(model, Model.ROUND_SECONDS + 0.10)
	_check(model.snapshot().ended and not model.snapshot().ordinary_eligible and model.snapshot().score == 0,
		"idle timeout never supplies participation, ordinary clear or a challenge")
	model.reset(false, 0)
	_check(model.place_strand(0, 1), "a real valid join can register participation")
	_advance(model, Model.ROUND_SECONDS + 0.10)
	var partial := model.snapshot()
	_check(partial.ended and partial.ordinary_eligible and not partial.success and not partial.devil and partial.score == 0,
		"a deliberate partial build earns participation at natural timeout without a fabricated lift score")


func _place_edges(model: Model, paths: Array) -> void:
	for path: Vector2i in paths:
		_check(model.place_strand(path.x, path.y), "actual connection %s is legal in this route" % path)


func _advance(model: Model, seconds: float, delta: float = HOLD) -> void:
	for tick in roundi(seconds / delta):
		model.step(delta)


func _peak_stress(state: Dictionary) -> float:
	var strongest := 0.0
	for edge: Dictionary in state.edges:
		strongest = maxf(strongest, edge.stress)
	return strongest


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_errors.append(message)
