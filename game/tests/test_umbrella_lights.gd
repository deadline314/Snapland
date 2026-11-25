extends SceneTree

const Model = preload("res://game/minigames/umbrella_lights_model.gd")

enum { BRAKE, COAST, LATE, RELEASE_EARLY, WRONG_RIB, DETENT }

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_controls_and_geometry()
	_detent_controls()
	_finite_cadence_and_idle()
	_deliberate_partial_round_qualifies()
	for layout in 2:
		for assisted in [false, true]:
			_round(layout, assisted, [COAST, COAST], 0)
			_round(layout, assisted, [BRAKE, BRAKE], 2)
		_round(layout, true, [DETENT, BRAKE], 2)
	_round(0, false, [LATE, BRAKE], 1)
	_round(1, false, [BRAKE, RELEASE_EARLY], 1)
	_round(1, true, [WRONG_RIB, BRAKE], 1)
	print("Umbrella lights model: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("PASS: umbrella lights angular exposure and deliberate darkness")
	quit(int(_failures != 0))


func _controls_and_geometry() -> void:
	var model := Model.new()
	var initial := model.snapshot()
	_expect(initial.phase_count == 6 and initial.kind == Model.PETAL and initial.target == 0
		and not initial.live and initial.next.kind == Model.PETAL and initial.petal_offsets.size() == Model.PETAL_COUNT
		and initial.rib_offsets.size() == Model.RIB_COUNT, "six authored stages and actual eight physical ribs/four windows")
	_expect(is_equal_approx(rad_to_deg(initial.petal_offsets[0]), 22.5)
		and is_equal_approx(rad_to_deg(initial.rib_offsets[1]), 45.0)
		and initial.petal_half_width > initial.beam_half_width and initial.rib_half_width > initial.beam_half_width,
		"petal windows lie between distinct ribs and the ray has a finite angular width")
	model.set_turn_axis(NAN)
	model.step(INF)
	model.step(-1.0)
	model.step(Model.TICK * 0.25)
	var still := model.snapshot()
	_expect(still.angle == initial.angle and still.elapsed == 0.0 and still.velocity == 0.0,
		"invalid movement and elapsed time cannot advance optics or participation")
	model.set_turn_axis(8.0)
	model.step(Model.TICK)
	var one := model.snapshot()
	_expect(one.turn_input == 1.0 and one.velocity > 0.0 and one.velocity < deg_to_rad(20.0)
		and angle_difference(initial.angle, one.angle) > 0.0, "forward input clamps and accelerates smoothly clockwise")
	_ticks(model, 20)
	var moving := model.snapshot()
	model.set_turn_axis(0.0)
	model.step(Model.TICK)
	var coast := model.snapshot()
	_expect(coast.velocity > 0.0 and coast.velocity < moving.velocity and coast.angle != moving.angle,
		"releasing the turn coasts with angular inertia")
	var predicted: float = coast.stop_heading
	model.set_brake(true)
	model.step(Model.TICK)
	var braking := model.snapshot()
	_expect(braking.braking and braking.velocity > 0.0 and braking.velocity < coast.velocity
		and coast.velocity - braking.velocity > moving.velocity - coast.velocity,
		"held brake physically decelerates faster than releasing the turn")
	_ticks(model, 25)
	_expect(model.snapshot().velocity == 0.0 and absf(angle_difference(predicted, model.snapshot().angle)) < 0.00001,
		"stop marker is the integral of the same discrete deceleration used by the actual brake")
	model.clear_input()
	_expect(not model.snapshot().braking and model.snapshot().turn_input == 0.0, "pause release clears all held controls")

	model.reset(true, 1)
	var alternate := model.snapshot()
	_expect(alternate.layout == 1 and alternate.target == 3 and alternate.next.kind == Model.BLANK
		and alternate.next.target == 1 and not alternate.live and alternate.phase_results.count(0) == 6,
		"alternate order and next-blank preview appear from the actual authored timetable")
	_expect(alternate.rib_half_width > initial.rib_half_width and alternate.petal_half_width > initial.petal_half_width
		and alternate.phases[3].beam_direction == -initial.phases[0].beam_direction,
		"assistance widens actual geometry while replay direction changes")
	var start_heading: float = alternate.beam_heading
	_ticks(model, int(alternate.phases[0].prep_ticks))
	var first_live := model.snapshot()
	_expect(first_live.live and first_live.exposure == 0.0 and first_live.raw_exposure == 0.0
		and is_equal_approx(first_live.beam_heading, start_heading), "preview is silent and sweep starts at its announced heading")
	_ticks(model, 17)
	var lit := model.snapshot()
	var center: float = lit.angle + lit.petal_offsets[lit.target]
	var finite_cone := clampf((lit.petal_half_width + lit.beam_half_width - absf(angle_difference(lit.beam_heading, center)))
		/ (2.0 * lit.beam_half_width), 0.0, 1.0)
	_expect(lit.beam_heading > start_heading and is_equal_approx(lit.target_overlap, finite_cone),
		"live ray travels the correct direction and reports finite angular intersection")


func _detent_controls() -> void:
	var model := Model.new()
	_expect(not model.nudge(1), "detent buttons do not change standard mode")
	model.reset(true, 0)
	var before := model.snapshot()
	_expect(not model.nudge(0) and model.nudge(-1) and not model.nudge(-1), "one active detent accepts a meaningful direction only once")
	model.step(Model.TICK)
	var first := model.snapshot()
	_expect(first.detent_active and first.velocity < 0.0 and absf(angle_difference(before.angle, first.angle)) < Model.DETENT_ANGLE,
		"assisted step drives a real gradual rotation")
	_ticks(model, 50)
	var stopped := model.snapshot()
	_expect(not stopped.detent_active and stopped.velocity == 0.0
		and absf(angle_difference(before.angle, stopped.angle) + Model.DETENT_ANGLE) < 0.00001,
		"assisted travel stops exactly one physical 7.5-degree step away")
	_expect(model.nudge(1), "released detent becomes available again")
	_ticks(model, 4)
	model.set_brake(true)
	var canceled := model.snapshot()
	_ticks(model, 25)
	_expect(not canceled.detent_active and model.snapshot().velocity == 0.0
		and absf(angle_difference(canceled.stop_heading, model.snapshot().angle)) < 0.00001,
		"held brake cancels further step motion and only its inertia remains")


func _finite_cadence_and_idle() -> void:
	var normal := Model.new()
	var cut := Model.new()
	normal.set_turn_axis(-0.63)
	cut.set_turn_axis(-0.63)
	for frame in 152:
		normal.step(Model.TICK)
		cut.step(Model.TICK * 0.27)
		cut.step(Model.TICK * 0.73)
	var a := normal.snapshot()
	var b := cut.snapshot()
	_expect(a.angle == b.angle and a.velocity == b.velocity and a.beam_heading == b.beam_heading
		and a.elapsed == b.elapsed and a.exposure == b.exposure, "fixed tick is deterministic under a split control/render cadence")
	for layout in 2:
		var idle := Model.new()
		idle.reset(layout == 1, layout)
		idle.set_brake(true)
		idle.step(500.0)
		_expect(idle.snapshot().elapsed == 0.25, "oversized elapsed frame is bounded")
		var saw_live_beam := false
		var measured_physical := false
		for frame in 1300:
			if idle.snapshot().ended:
				break
			idle.step(Model.TICK)
			var state := idle.snapshot()
			saw_live_beam = saw_live_beam or state.live
			measured_physical = measured_physical or state.raw_exposure > 0.1
		var outcome := idle.snapshot()
		_expect(saw_live_beam and measured_physical and outcome.ended and outcome.remaining == 0.0
			and outcome.score == 0 and outcome.petal_mask == 0 and outcome.blank_mask == 0
			and not outcome.ordinary_eligible and not outcome.brake_armed and not outcome.devil,
			"held brake before the preview and idle beam overlap cannot create collection or darkness proof")


func _deliberate_partial_round_qualifies() -> void:
	var model := Model.new()
	var result := _play_petal(model)
	_expect(result.success and result.dose >= result.required and model.snapshot().engaged,
		"actual rotated open window earns one optical dose")
	model.clear_input()
	for interval in 100:
		model.step(0.25)
	var outcome := model.snapshot()
	_expect(outcome.ended and outcome.petal_mask == 1 and outcome.petal_mask != 15
		and outcome.ordinary_eligible and not outcome.success and not outcome.devil and outcome.score == Model.PETAL_POINTS,
		"partial deliberate exposure can earn an ordinary attempt, while later missed petals cannot claim success")


func _round(layout: int, assisted: bool, blank_modes: Array, wanted_blanks: int) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "layout %d assisted %s blanks %s" % [layout, assisted, blank_modes]
	var seen_blanks := 0
	var prior_blanks := 0
	for phase in model.snapshot().phase_count:
		var state := model.snapshot()
		_expect(state.phase_index == phase and state.phase_time == 0.0 and not state.live,
			"the real next stage announces its own prep before any live scoring")
		if state.kind == Model.PETAL:
			var petal := _play_petal(model)
			_expect(petal.success and petal.dose >= petal.required and petal.physical >= petal.dose
				and model.snapshot().petal_mask & (1 << int(state.target)),
				"physical moving ray reaches petal %d in %s" % [state.target, label])
			continue
		var technique: int = blank_modes[seen_blanks]
		var events := _play_blank(model, technique)
		var blank: Dictionary = events.result
		var qualified := technique in [BRAKE, DETENT]
		_expect(blank.success == qualified and model.snapshot().blanks_done == prior_blanks + int(qualified),
			"blank outcome reflects deliberate timing and tilt in " + label)
		if qualified:
			_expect(events.brake_armed and events.actual_deceleration and events.live_still
				and blank.dose >= blank.required and blank.physical >= blank.dose,
				"proactive braking and enough actual designated rib shadow is required")
			if technique == DETENT:
				_expect(events.detent_started and events.detent_used,
					"assisted deliberate detent travel supplies real angular speed for a qualifying blank")
		elif technique == WRONG_RIB:
			_expect(events.max_wrong_shadow > 0.85 and blank.dose == 0.0 and blank.physical < 0.10 and not events.brake_armed,
				"nearby wrong rib physically shades the beam but cannot count for the chosen rib")
		else:
			_expect(blank.physical >= blank.required and blank.dose < blank.required,
				"geometry alone, late brake or prematurely released brake is not deliberate completed darkness")
		prior_blanks += int(qualified)
		seen_blanks += 1
	var result := model.snapshot()
	var center := wanted_blanks == Model.BLANK_COUNT
	_expect(result.ended and result.success and result.ordinary_eligible and result.devil == center
		and result.center_proven == center and result.petal_mask == 15 and result.blanks_done == wanted_blanks
		and result.score == Model.PETAL_COUNT * Model.PETAL_POINTS + int(center) * Model.CENTER_POINTS,
		"exact ordinary flower or true center completes " + label)


func _play_petal(model: RefCounted) -> Dictionary:
	var phase: int = model.snapshot().phase_index
	model.set_brake(false)
	for tick in 250:
		var state: Dictionary = model.snapshot()
		if state.ended or state.phase_index != phase:
			return state.last_result
		var feed := 0.0
		if state.live or state.seconds_to_sweep <= 4.0 * Model.TICK + 0.00001:
			feed = rad_to_deg(float(state.beam_end - state.beam_start)) / float(state.sweep_seconds)
		model.set_turn_axis(_held_sign(state, state.guide_heading, feed))
		model.step(Model.TICK)
	return {}


func _play_blank(model: RefCounted, technique: int) -> Dictionary:
	var phase: int = model.snapshot().phase_index
	var arm_seen := false
	var decel_seen := false
	var still_seen := false
	var was_braked := false
	var detent_started := false
	var detent_used := false
	var shifted := 0.0
	var max_wrong := 0.0
	var approach: float = signf(angle_difference(model.snapshot().angle, model.snapshot().guide_heading))
	if approach == 0.0:
		approach = 1.0
	model.set_brake(false)
	for tick in 240:
		var state: Dictionary = model.snapshot()
		if state.ended or state.phase_index != phase:
			return {"result": state.last_result, "brake_armed": arm_seen, "actual_deceleration": decel_seen,
				"live_still": still_seen, "detent_started": detent_started, "detent_used": detent_used, "max_wrong_shadow": max_wrong}
		arm_seen = arm_seen or state.brake_armed
		decel_seen = decel_seen or state.brake_slowed
		still_seen = still_seen or (state.live and state.braking and absf(state.velocity) < deg_to_rad(8.5) and state.target_overlap > 0.6)
		detent_used = detent_used or (state.detent_active and absf(state.velocity) >= Model.MIN_BRAKING_SPEED)
		if state.live:
			max_wrong = maxf(max_wrong, float(state.shadow_fraction))
		var target: float = state.guide_heading + shifted
		if technique == WRONG_RIB:
			shifted = PI / 4.0
			target = state.guide_heading + shifted
		var error := angle_difference(state.angle, target)
		var predicted := absf(angle_difference(state.stop_heading, target))
		if state.braking:
			if technique == RELEASE_EARLY and state.live and state.phase_time - state.prep_seconds >= state.sweep_seconds * 0.38:
				model.set_brake(false)
				model.set_turn_axis(0.0)
		elif technique == LATE:
			if state.live and state.phase_time - state.prep_seconds > 0.04:
				model.set_brake(true)
			else:
				model.set_turn_axis(_held_sign(state, target, 0.0))
		elif technique == COAST:
			model.set_turn_axis(_held_sign(state, target, 0.0))
		elif not was_braked and not state.live:
			if technique == DETENT and not detent_started:
				var stage := target - approach * deg_to_rad(6.6)
				var staged := absf(angle_difference(state.angle, stage)) <= deg_to_rad(1.35)
				if staged and absf(state.velocity) <= deg_to_rad(12.0):
					model.set_turn_axis(0.0)
					detent_started = model.nudge(int(approach))
				else:
					model.set_turn_axis(_held_sign(state, stage, 0.0))
			elif absf(state.velocity) >= Model.MIN_BRAKING_SPEED and signf(state.velocity) == signf(error) and predicted <= deg_to_rad(1.8):
				model.set_brake(true)
				was_braked = true
			elif technique != DETENT:
				var direction := signf(error)
				if absf(error) < deg_to_rad(8.0) and absf(state.velocity) < Model.MIN_BRAKING_SPEED:
					direction = -1.0 if direction >= 0.0 else 1.0
				model.set_turn_axis(direction)
		model.step(Model.TICK)
	return {}


func _held_sign(state: Dictionary, target: float, feed_degrees: float) -> float:
	var error := rad_to_deg(angle_difference(state.angle, target))
	var velocity := rad_to_deg(state.velocity)
	var desired := clampf(feed_degrees + 8.0 * error, -96.0, 96.0)
	if absf(desired - velocity) <= 3.8:
		return 0.0
	if absf(feed_degrees) < 4.0 and absf(error) <= 1.3 and absf(velocity) <= 8.0:
		return 0.0
	return signf(desired - velocity)


func _ticks(model: RefCounted, count: int) -> void:
	for tick in count:
		model.step(Model.TICK)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", description)
	return condition
