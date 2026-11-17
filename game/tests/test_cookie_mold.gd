extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	expect(ResourceLoader.exists("res://game/minigames/cookie_mold_model.gd"), "physical cookie model must exist for public-operation routes")
	if failures == 0:
		var model = load("res://game/minigames/cookie_mold_model.gd").new()
		var state: Dictionary = model.snapshot()
		expect(state.completed.size() == 6 and state.polygon.size() >= 8 and state.polygon.size() <= 32, "six bounded slots and real edge polygon")
		model.toggle_helper()
		for frame in 600:
			model.step(0.25)
		state = model.snapshot()
		expect(state.ended and state.caught == 0 and not state.ordinary_eligible, "idle and outlet-only helper cannot complete or earn a card")
		_operation_tests(model)
	print("Cookie mold tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

static func advance(model, seconds: float) -> void:
	var left := seconds
	while left > 0.000001:
		var delta := minf(left, 1.0 / 120.0)
		model.step(delta)
		left -= delta

static func loosen(model) -> void:
	# Read only public state: choose the most adhered corner, then charge a light tap.
	for tap in 180:
		var state: Dictionary = model.snapshot()
		if state.phase != "molded" or state.ended:
			return
		var edge := 0
		for i in state.edges.size():
			if state.edges[i].adhesion > state.edges[edge].adhesion:
				edge = i
		if state.edges[edge].adhesion <= 0.15:
			return
		model.select_edge_at(state.edges[edge].point)
		model.begin_tap()
		advance(model, 0.16)
		model.release_tap()

static func release_cookie(model, inertial: bool = false) -> void:
	loosen(model)
	if inertial:
		model.set_mold_target(2.8)
	else:
		for frame in 480:
			if model.snapshot().phase != "molded":
				break
			model.set_mold_target(minf(PI, float(frame + 1) * 0.9 / 120.0))
			model.step(1.0 / 120.0)
	for frame in 600:
		var state: Dictionary = model.snapshot()
		if state.phase != "molded" or state.ended:
			return
		model.set_tray_target(state.outlet.x)
		model.step(1.0 / 120.0)

static func catch_cookie(model) -> void:
	for frame in 600:
		var state: Dictionary = model.snapshot()
		if state.phase != "flying" or state.ended:
			return
		model.set_tray_target(state.cookie_position.x)
		model.step(1.0 / 120.0)

static func solve(model, inertial: bool = false, count: int = 6) -> Dictionary:
	for slot in count:
		release_cookie(model, inertial and slot == 5)
		catch_cookie(model)
		var state: Dictionary = model.snapshot()
		if state.phase != "caught":
			return state
		if not state.ended:
			advance(model, 0.46)
	return model.snapshot()

func _operation_tests(model) -> void:
	var polygons: Array = []
	for variant in 2:
		for assisted in [false, true]:
			for inertial in [false, true]:
				model.reset(assisted, variant)
				for slot in 6:
					var before: Dictionary = model.snapshot()
					expect(before.shape_index == slot and before.polygon.size() >= 8 and before.polygon.size() <= 32, "fixed shape order and bounded edges")
					expect(Geometry2D.triangulate_polygon(PackedVector2Array(before.polygon)).size() == (before.polygon.size() - 2) * 3, "shape triangulates as a real simple polygon")
					for vertex in before.polygon:
						expect(vertex.length() <= 0.62, "polygon stays within frozen maximum radius")
					if variant == 0 and not assisted and not inertial:
						polygons.append(before.polygon)
					release_cookie(model, inertial and slot == 5)
					var released: Dictionary = model.snapshot()
					expect(released.phase == "flying" and released.cookie_velocity.length() > 0, "actual force release enters ballistic flight")
					if slot == 5:
						expect(released.double_layer and released.thickness > 0.35, "double-layer whole thickness")
						expect((absf(released.release_omega) >= 2.0) == inertial, "low and high angular release are physically distinct")
						expect(not released.double_layer_inertial_caught and not released.devil, "inertial release alone never awards caught proof")
					catch_cookie(model)
					var caught: Dictionary = model.snapshot()
					expect(caught.phase == "caught" and caught.caught == slot + 1 and caught.completed[slot], "whole body physically crosses tray to catch")
					if not caught.ended:
						advance(model, 0.46)
				var final: Dictionary = model.snapshot()
				expect(final.success and final.ended and final.caught == 6 and final.ordinary_eligible, "six natural catches finish both configurations and assistance modes")
				expect(final.devil == inertial and final.double_layer_inertial_caught == inertial and final.score == (800 if inertial else 700), "real double-layer inertia determines devil and score")
				print("COOKIE_ROUTE variant=%d assisted=%s inertial=%s caught=%d success=%s devil=%s elapsed=%.3f score=%d omega=%.5f inertial_force=%.5f gravity=%.5f" % [variant, assisted, inertial, final.caught, final.success, final.devil, final.elapsed, final.score, final.release_omega, final.release_inertial, final.release_gravity])
	for first in polygons.size():
		for second in range(first + 1, polygons.size()):
			expect(polygons[first] != polygons[second], "six distinct polygon silhouettes")
	model.reset()
	var original: Dictionary = model.snapshot()
	model.begin_tap()
	advance(model, 0.5)
	model.clear_input()
	model.release_tap()
	expect(model.snapshot().edges == original.edges and not model.snapshot().charging and model.snapshot().charge == 0, "cancel charge never knocks")
	model.begin_tap()
	advance(model, 0.2)
	model.begin_tap()
	model.select_edge(1)
	expect(is_equal_approx(model.snapshot().charge, 0.2) and model.snapshot().selected_edge == 0, "repeat begin and edge selection preserve charging corner")
	model.clear_input()
	model.set_mold_target(2.8)
	advance(model, 0.3)
	var omega: float = model.snapshot().mold_omega
	model.release_mold()
	advance(model, 0.05)
	expect(model.snapshot().mold_omega > 0 and model.snapshot().mold_omega < omega, "released mold coasts with physical damping")
	model.reset()
	model.set_mold_target(PI)
	advance(model, 5)
	expect(model.snapshot().phase == "molded", "unloosened static inversion cannot release cookie")
	model.reset()
	for tap in 12:
		model.begin_tap()
		advance(model, 0.9)
		model.release_tap()
		if model.snapshot().phase == "cracked":
			break
	expect(model.snapshot().phase == "cracked" and model.snapshot().mistakes == 1, "repeated strong upright taps really crack")
	var failed: Dictionary = model.snapshot()
	for edge in failed.edges:
		expect(edge.stress <= failed.crack_limit, "per-edge stress remains bounded by material crack limit")
	model.retry_cookie()
	var retried: Dictionary = model.snapshot()
	expect(retried.phase == "molded" and retried.elapsed == failed.elapsed and retried.mistakes == 1 and retried.caught == 0 and retried.variant == failed.variant, "free current retry retains time, mistakes and configuration")
	model.reset()
	release_cookie(model)
	model.set_tray_target(-3.2)
	advance(model, 2)
	expect(model.snapshot().phase == "missed" and model.snapshot().mistakes == 1 and model.snapshot().caught == 0, "wrong tray position misses actual falling whole cookie")
	advance(model, 1)
	expect(model.snapshot().mistakes == 1, "failed cookie does not repeatedly penalize")
	model.retry_cookie()
	expect(model.snapshot().phase == "molded" and model.snapshot().caught == 0, "miss retry does not create completion")
	model.reset()
	release_cookie(model)
	# Freeze the tray where the center fits but one edge of the upright star protrudes.
	var released: Dictionary = model.snapshot()
	model.set_tray_target(float(released.cookie_position.x) - 0.95)
	var center_was_inside := false
	for frame in 240:
		var state: Dictionary = model.snapshot()
		if state.cookie_position.y < -0.2 and state.cookie_position.y > -0.8:
			center_was_inside = absf(float(state.cookie_position.x) - float(state.tray_x)) < state.tray_half_width
		model.step(1.0 / 120.0)
	expect(center_was_inside and model.snapshot().caught == 0 and model.snapshot().phase == "missed", "center inside alone cannot catch protruding whole cookie")
	model.reset()
	release_cookie(model)
	model.set_tray_target(-3.2)
	for frame in 240:
		if model.snapshot().cookie_position.y < -1.35:
			break
		model.step(1.0 / 120.0)
	model.set_tray_target(model.snapshot().cookie_position.x)
	advance(model, 0.5)
	expect(model.snapshot().caught == 0 and model.snapshot().phase == "missed", "tray moved after descending crossing cannot retroactively catch")
	model.reset()
	model.toggle_helper()
	release_cookie(model, true)
	model.toggle_helper()
	if not model.snapshot().helper:
		model.toggle_helper()
	var flight: Dictionary = model.snapshot()
	advance(model, 0.2)
	var helper: Dictionary = model.snapshot()
	expect(is_equal_approx(helper.tray_target, helper.outlet.x) and helper.cookie_position.distance_to(flight.cookie_position) > 0.05 and absf(helper.tray_target - helper.cookie_position.x) > 0.05, "helper follows mold outlet rather than flying cookie")
	model.reset()
	loosen(model)
	model.begin_tap()
	advance(model, 0.05)
	model.clear_input()
	var canceled: Dictionary = model.snapshot()
	model.release_tap()
	expect(model.snapshot() == canceled, "canceled charged input never performs a deferred shot")
	model.set_tray_target(99)
	model.step(1.0 / 120.0)
	expect(model.snapshot().tray_target == 3.2 and model.snapshot().tray_x <= 4.0 / 120.0 + 0.000001, "tray target clamps and real tray moves at bounded speed")
	model.reset(false, -1)
	expect(model.snapshot().variant == 1 and is_equal_approx(model.snapshot().thickness, 0.21), "negative variants use positive modulo")
	model.set_mold_target(PI - 0.05)
	advance(model, 2)
	model.set_mold_target(-PI + 0.05)
	model.step(1.0 / 120.0)
	expect(absf(model.snapshot().mold_omega) < 0.1, "crossing wrapped angle follows short physical turn")
	model.reset()
	solve(model, false, 2)
	var partial: Dictionary = model.snapshot()
	for tap in 15:
		model.begin_tap()
		advance(model, 0.9)
		model.release_tap()
		if model.snapshot().phase == "cracked":
			break
	model.retry_cookie()
	expect(model.snapshot().caught == 2 and model.snapshot().completed == partial.completed and model.snapshot().shape_index == 2, "retry retains earlier actual catches and current slot")
	model.reset()
	model.set_mold_target(0.3)
	advance(model, 150)
	var ended: Dictionary = model.snapshot()
	expect(ended.ended and not ended.success and ended.ordinary_eligible and ended.score == 0, "participated timeout has ordinary qualification without success")
	model.set_mold_target(2)
	model.release_mold()
	model.select_edge(1)
	model.select_edge_at(Vector2.ZERO)
	model.begin_tap()
	model.release_tap()
	model.set_tray_target(2)
	model.toggle_helper()
	model.retry_cookie()
	model.step(0.2)
	expect(model.snapshot() == ended, "ended model ignores all gameplay inputs")
	model.reset()
	var finite_before: Dictionary = model.snapshot()
	model.set_mold_target(NAN)
	model.set_mold_target(INF)
	model.set_tray_target(INF)
	model.select_edge_at(Vector2(NAN, 0))
	model.step(NAN)
	model.step(INF)
	model.step(-1)
	expect(model.snapshot() == finite_before, "invalid finite inputs leave every field unchanged")
	var detached: Dictionary = model.snapshot()
	detached.edges[0].adhesion = -100
	detached.completed[0] = true
	detached.polygon[0] = Vector2(90, 90)
	expect(model.snapshot() == finite_before, "nested snapshots detached from model")
	model.step(100)
	expect(is_equal_approx(model.snapshot().elapsed, 0.25), "frame clamp bounds substep work")
	model.reset()
	solve(model, false, 5)
	release_cookie(model, true)
	var candidate: Dictionary = model.snapshot()
	model.set_tray_target(-3.2)
	advance(model, 2)
	expect(candidate.release_inertial >= 0.35 * candidate.release_gravity and model.snapshot().phase == "missed" and not model.snapshot().double_layer_inertial_caught, "genuine high inertia miss cannot award devil proof")
	var missed_time: float = model.snapshot().elapsed
	model.retry_cookie()
	expect(model.snapshot().caught == 5 and model.snapshot().release_omega == 0 and not model.snapshot().double_layer_inertial_caught and model.snapshot().elapsed == missed_time, "double retry clears release candidate while retaining five catches")
	release_cookie(model)
	catch_cookie(model)
	expect(model.snapshot().success and not model.snapshot().devil and model.snapshot().score == 680, "low inertia retry cannot inherit earlier missed challenge")
	for retry in 60:
		model.reset(false, retry)
		expect(model.snapshot().edges.size() == model.snapshot().polygon.size() and model.snapshot().completed.size() == 6, "reset keeps bounded pools")
