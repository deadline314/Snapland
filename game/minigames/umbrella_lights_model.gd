extends RefCounted

const PETAL := 0
const BLANK := 1
const PETAL_COUNT := 4
const BLANK_COUNT := 2
const RIB_COUNT := 8
const PETAL_POINTS := 100
const CENTER_POINTS := 100
const TICK := 1.0 / 60.0
const DETENT_ANGLE := deg_to_rad(7.5)
const BRAKE_DECELERATION := deg_to_rad(470.0)
const MIN_BRAKING_SPEED := deg_to_rad(13.0)

const _BEAM_HALF := deg_to_rad(2.6)
const _PETAL_HALF := deg_to_rad(10.8)
const _ASSIST_PETAL_HALF := deg_to_rad(15.3)
const _RIB_HALF := deg_to_rad(6.3)
const _ASSIST_RIB_HALF := deg_to_rad(8.4)
const _TURN_MAX := deg_to_rad(96.0)
const _TURN_ACCELERATION := deg_to_rad(410.0)
const _COAST_DECELERATION := deg_to_rad(156.0)
const _DETENT_MAX := deg_to_rad(49.0)
const _DETENT_ACCELERATION := deg_to_rad(375.0)
const _STILL_SPEED := deg_to_rad(8.5)
const _ARM_HEADING_RANGE := deg_to_rad(28.0)
const _ARM_MIN_LEAD := 0.07
const _MIN_STAGE_ROTATION := deg_to_rad(4.0)
const _MIN_ENGAGED_EXPOSURE := 0.075
const _PHASE_WAITING := 0
const _PHASE_WON := 1
const _PHASE_MISSED := 2

# Kind, optic index, umbrella aim at beam start (petal) or center (blank),
# signed beam sweep, preview seconds, active seconds. Authoring angles are degrees.
const _PROGRAMS := [
	[
		[PETAL, 0, -36.0, 78.0, 1.55, 1.98],
		[PETAL, 1, 65.0, -82.0, 1.57, 1.86],
		[BLANK, 4, -48.0, 7.2, 1.45, 0.90],
		[PETAL, 2, -44.0, 88.0, 1.53, 2.06],
		[BLANK, 6, 74.0, -7.2, 1.28, 0.92],
		[PETAL, 3, 54.0, -76.0, 1.37, 1.86],
	],
	[
		[PETAL, 3, 38.0, 76.0, 1.56, 1.90],
		[BLANK, 1, 151.0, -7.8, 1.34, 0.92],
		[PETAL, 1, 132.0, 82.0, 1.50, 2.05],
		[PETAL, 0, 222.0, -95.0, 1.58, 1.95],
		[BLANK, 5, 91.0, 7.8, 1.34, 0.95],
		[PETAL, 2, 100.0, -77.0, 1.44, 1.85],
	],
]

var _rib_offsets := PackedFloat32Array()
var _petal_offsets := PackedFloat32Array()
var _phases: Array[Dictionary] = []
var _phase_results := PackedByteArray()
var _result_paint := PackedByteArray()
var _last_result: Dictionary = {}
var _layout := 0
var _assisted := false
var _angle := 0.0
var _velocity := 0.0
var _axis := 0.0
var _braking := false
var _brake_armed := false
var _brake_slowed := false
var _detent_active := false
var _detent_remaining := 0.0
var _index := 0
var _phase_ticks := 0
var _total_ticks := 0
var _round_ticks := 0
var _accumulator := 0.0
var _beam_heading := 0.0
var _open_fraction := 0.0
var _shadow_fraction := 0.0
var _target_overlap := 0.0
var _phase_rotation := 0.0
var _exposure := 0.0
var _darkness := 0.0
var _raw_exposure := 0.0
var _raw_darkness := 0.0
var _petal_mask := 0
var _blank_mask := 0
var _petals_done := 0
var _blanks_done := 0
var _engaged := false
var _ended := false
var _mistakes := 0
var _feedback := ""
var _notes: Array[int] = []


func _init() -> void:
	for rib in RIB_COUNT:
		_rib_offsets.append(float(rib) * TAU / float(RIB_COUNT))
	for petal in PETAL_COUNT:
		_petal_offsets.append(PI / 8.0 + float(petal) * TAU / float(PETAL_COUNT))
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, _PROGRAMS.size())
	_build_program()
	_phase_results.resize(_phases.size())
	_phase_results.fill(_PHASE_WAITING)
	_result_paint = _phase_results.duplicate()
	_last_result = {}
	_angle = deg_to_rad(29.0 if _layout == 0 else 99.0)
	clear_input()
	_index = 0
	_total_ticks = 0
	_accumulator = 0.0
	_petal_mask = 0
	_blank_mask = 0
	_petals_done = 0
	_blanks_done = 0
	_engaged = false
	_ended = false
	_mistakes = 0
	_notes.clear()
	_enter_phase()


func set_turn_axis(axis: float) -> void:
	if _ended or not is_finite(axis):
		return
	_axis = clampf(axis, -1.0, 1.0)
	if _axis != 0.0:
		_detent_active = false
		_detent_remaining = 0.0


func set_brake(pressed: bool) -> void:
	if _ended or pressed == _braking:
		return
	_braking = pressed
	if not pressed:
		_brake_armed = false
		_brake_slowed = false
		return
	_detent_active = false
	_detent_remaining = 0.0
	var phase := _phase()
	if phase.kind != BLANK:
		_feedback = "煞車正在減速。"
		return
	var lead := float(int(phase.prep_ticks) - _phase_ticks) * TICK
	_brake_armed = _can_arm_brake(phase)
	_brake_slowed = false
	if _brake_armed:
		_feedback = "已煞車，短停讓標記傘骨遮光。"
	elif lead < _ARM_MIN_LEAD:
		_feedback = "這段已來不及。留白要在掃光前煞住。"
	else:
		_feedback = "轉近標記傘骨，再趁傘還在轉時煞停。"


func nudge(direction: int) -> bool:
	if not _assisted or _ended or _braking or _detent_active or direction not in [-1, 1]:
		return false
	_axis = 0.0
	_detent_active = true
	_detent_remaining = float(direction) * DETENT_ANGLE
	return true


func clear_input() -> void:
	_axis = 0.0
	_velocity = 0.0
	_braking = false
	_brake_armed = false
	_brake_slowed = false
	_detent_active = false
	_detent_remaining = 0.0


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK and not _ended:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_step_tick()


func _build_program() -> void:
	var program: Array[Dictionary] = []
	var blanks := 0
	_round_ticks = 0
	for row in _PROGRAMS[_layout]:
		var kind: int = row[0]
		var target: int = row[1]
		var guide := wrapf(deg_to_rad(row[2]), -PI, PI)
		var sweep := deg_to_rad(row[3])
		var offset := _petal_offsets[target] if kind == PETAL else _rib_offsets[target]
		var start := wrapf(guide + offset - (sweep * 0.5 if kind == BLANK else 0.0), -PI, PI)
		var prep_ticks := roundi(float(row[4]) / TICK)
		var sweep_ticks := roundi(float(row[5]) / TICK)
		var fraction := 0.74 if kind == BLANK else (0.43 if _assisted else 0.38)
		var record := {
			"kind": kind, "target": target, "guide_heading": guide,
			"beam_start": start, "beam_end": start + sweep, "beam_direction": int(signf(sweep)),
			"prep_ticks": prep_ticks, "sweep_ticks": sweep_ticks,
			"prep_seconds": float(prep_ticks) * TICK, "sweep_seconds": float(sweep_ticks) * TICK,
			"requirement": float(sweep_ticks) * TICK * fraction,
			"blank_index": blanks if kind == BLANK else -1,
		}
		if kind == BLANK:
			blanks += 1
		record.make_read_only()
		program.append(record)
		_round_ticks += prep_ticks + sweep_ticks
	program.make_read_only()
	_phases = program


func _phase() -> Dictionary:
	return _phases[_index]


func _enter_phase() -> void:
	_phase_ticks = 0
	_phase_rotation = 0.0
	_exposure = 0.0
	_darkness = 0.0
	_raw_exposure = 0.0
	_raw_darkness = 0.0
	_brake_armed = false
	_brake_slowed = false
	var phase := _phase()
	if phase.kind == BLANK:
		_feedback = "下一段留白。先轉近標記傘骨，掃光前煞停。"
		_note(-5)
	else:
		_feedback = "跟上掃角，讓光穿過標記的花瓣開口。"
		_note(int(phase.target) * 2)
	_sample_optics(phase, 0.0)


func _step_tick() -> void:
	var phase := _phase()
	var was_controlled := not _braking and (_axis != 0.0 or _detent_active)
	var original_speed := absf(_velocity)
	var advance := _turn_step()
	if was_controlled:
		_phase_rotation += absf(advance)
	if _brake_armed and _braking and absf(_velocity) < original_speed:
		_brake_slowed = true
	_angle = wrapf(_angle + advance, -PI, PI)
	var prep_ticks: int = phase.prep_ticks
	var sweep_ticks: int = phase.sweep_ticks
	if _phase_ticks >= prep_ticks:
		var interval := (float(_phase_ticks - prep_ticks) + 0.5) / float(sweep_ticks)
		_sample_optics(phase, interval)
		_integrate_light(phase)
	_phase_ticks += 1
	_total_ticks += 1
	if _phase_ticks >= prep_ticks + sweep_ticks:
		_resolve_phase(phase)
	else:
		var beam_position := maxf(0.0, float(_phase_ticks - prep_ticks) / float(sweep_ticks))
		_sample_optics(phase, beam_position)


func _turn_step() -> float:
	if _braking:
		_velocity = move_toward(_velocity, 0.0, BRAKE_DECELERATION * TICK)
		return _velocity * TICK
	if _detent_active:
		var direction := signf(_detent_remaining)
		var max_step_speed := minf(_DETENT_MAX, sqrt(2.0 * _DETENT_ACCELERATION * absf(_detent_remaining)))
		_velocity = move_toward(_velocity, direction * max_step_speed, _DETENT_ACCELERATION * TICK)
		var advance := _velocity * TICK
		if advance * direction >= absf(_detent_remaining):
			advance = _detent_remaining
			_detent_remaining = 0.0
			_detent_active = false
			_velocity = 0.0
		else:
			_detent_remaining -= advance
		return advance
	var acceleration := _COAST_DECELERATION if _axis == 0.0 else _TURN_ACCELERATION
	_velocity = move_toward(_velocity, _axis * _TURN_MAX, acceleration * TICK)
	return _velocity * TICK


func _integrate_light(phase: Dictionary) -> void:
	if phase.kind == PETAL:
		_raw_exposure += _target_overlap * TICK
		if _phase_rotation >= _MIN_STAGE_ROTATION:
			_exposure += _target_overlap * TICK
			_engaged = _engaged or _exposure >= _MIN_ENGAGED_EXPOSURE
	else:
		_raw_darkness += _target_overlap * TICK
		if _braking and _brake_armed and _brake_slowed and absf(_velocity) <= _STILL_SPEED:
			_darkness += _target_overlap * TICK


func _sample_optics(phase: Dictionary, amount: float) -> void:
	_beam_heading = lerpf(phase.beam_start, phase.beam_end, amount)
	var petal_half := _petal_half_width()
	var rib_half := _rib_half_width()
	_open_fraction = 0.0
	for offset in _petal_offsets:
		_open_fraction += _overlap_fraction(_angle + offset, petal_half)
	var relative := angle_difference(_angle, _beam_heading)
	var rib_spacing := TAU / float(RIB_COUNT)
	_shadow_fraction = _overlap_fraction(_angle + roundf(relative / rib_spacing) * rib_spacing, rib_half)
	if phase.kind == PETAL:
		_target_overlap = _overlap_fraction(_angle + _petal_offsets[phase.target], petal_half)
	else:
		_target_overlap = _overlap_fraction(_angle + _rib_offsets[phase.target], rib_half)


## Intersection of the finite light cone and one optic, including circle wrap.
func _overlap_fraction(optic: float, optic_half: float) -> float:
	var distance := absf(angle_difference(_beam_heading, optic))
	return clampf((optic_half + _BEAM_HALF - distance) / (2.0 * _BEAM_HALF), 0.0, 1.0)


func _resolve_phase(phase: Dictionary) -> void:
	_sample_optics(phase, 1.0)
	var kind: int = phase.kind
	var dose := _exposure if kind == PETAL else _darkness
	var won: bool = dose >= float(phase.requirement)
	if kind == PETAL:
		if won:
			_petal_mask |= 1 << int(phase.target)
			_petals_done += 1
			_note(8)
		else:
			_mistakes += 1
			_note(-3)
	elif won:
		_blank_mask |= 1 << int(phase.blank_index)
		_blanks_done += 1
		_note(11)
	_phase_results[_index] = _PHASE_WON if won else _PHASE_MISSED
	_result_paint = _phase_results.duplicate()
	_last_result = {
		"index": _index, "kind": kind, "target": phase.target, "success": won,
		"dose": dose, "required": phase.requirement,
		"physical": _raw_exposure if kind == PETAL else _raw_darkness,
	}
	_last_result.make_read_only()
	if _index + 1 >= _phases.size():
		_finish()
		return
	_index += 1
	_enter_phase()


func _finish() -> void:
	_ended = true
	clear_input()
	_accumulator = 0.0
	if _petals_done == PETAL_COUNT:
		_feedback = "四瓣與雙段留白拼成完整花芯。" if _blanks_done == BLANK_COUNT else "四片受光花瓣已拼成一朵花。"
	else:
		_feedback = "光紋結束，已接到 %d / %d 片花瓣。" % [_petals_done, PETAL_COUNT]


func _petal_half_width() -> float:
	return _ASSIST_PETAL_HALF if _assisted else _PETAL_HALF


func _rib_half_width() -> float:
	return _ASSIST_RIB_HALF if _assisted else _RIB_HALF


func _can_arm_brake(phase: Dictionary) -> bool:
	return phase.kind == BLANK and float(int(phase.prep_ticks) - _phase_ticks) * TICK >= _ARM_MIN_LEAD \
		and absf(angle_difference(_angle, phase.guide_heading)) <= _ARM_HEADING_RANGE \
		and absf(_velocity) >= MIN_BRAKING_SPEED and _phase_rotation >= _MIN_STAGE_ROTATION


func _stop_heading() -> float:
	# This is the sum of the same per-tick velocities a held brake would apply.
	var speed := absf(_velocity)
	var drop := BRAKE_DECELERATION * TICK
	var terms := floorf(speed / drop)
	var advance := (terms * speed - drop * terms * (terms + 1.0) * 0.5) * TICK
	return wrapf(_angle + advance * signf(_velocity), -PI, PI)


func _note(pitch: int) -> void:
	if _notes.size() < 8:
		_notes.append(pitch)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func snapshot() -> Dictionary:
	var phase := _phase()
	var live: bool = not _ended and _phase_ticks >= phase.prep_ticks
	var guide: float = phase.guide_heading
	if live and phase.kind == PETAL:
		guide = wrapf(_beam_heading - _petal_offsets[phase.target], -PI, PI)
	var success := _ended and _petals_done == PETAL_COUNT
	var center_proven := _petals_done == PETAL_COUNT and _blanks_done == BLANK_COUNT
	var devil := success and center_proven
	return {
		"layout": _layout, "assisted": _assisted, "angle": _angle, "velocity": _velocity, "turn_input": _axis,
		"braking": _braking, "detent_active": _detent_active, "brake_armed": _brake_armed, "brake_slowed": _brake_slowed,
		"brake_ready": not _ended and not _braking and _can_arm_brake(phase), "stop_heading": _stop_heading(),
		"phase_index": _index, "phase_count": _phases.size(), "kind": phase.kind, "target": phase.target,
		"phase_time": float(_phase_ticks) * TICK, "prep_seconds": phase.prep_seconds, "sweep_seconds": phase.sweep_seconds,
		"seconds_to_sweep": maxf(0.0, float(int(phase.prep_ticks) - _phase_ticks) * TICK),
		"phase_progress": float(_phase_ticks) / float(int(phase.prep_ticks) + int(phase.sweep_ticks)), "live": live,
		"beam_heading": _beam_heading, "beam_half_width": _BEAM_HALF, "beam_start": phase.beam_start, "beam_end": phase.beam_end,
		"beam_direction": phase.beam_direction, "guide_heading": guide,
		"rib_offsets": _rib_offsets, "rib_half_width": _rib_half_width(),
		"petal_offsets": _petal_offsets, "petal_half_width": _petal_half_width(),
		"open_fraction": _open_fraction, "shadow_fraction": _shadow_fraction, "target_overlap": _target_overlap,
		"exposure": _exposure, "darkness": _darkness, "raw_exposure": _raw_exposure, "raw_darkness": _raw_darkness,
		"requirement": phase.requirement, "phase_rotation": _phase_rotation,
		"petal_mask": _petal_mask, "blank_mask": _blank_mask, "petals_done": _petals_done, "blanks_done": _blanks_done,
		"center_proven": center_proven, "engaged": _engaged, "phase_results": _result_paint, "last_result": _last_result,
		"next": _phases[_index + 1] if _index + 1 < _phases.size() else {}, "phases": _phases,
		"elapsed": float(_total_ticks) * TICK, "remaining": float(_round_ticks - _total_ticks) * TICK,
		"ended": _ended, "success": success, "devil": devil, "ordinary_eligible": _ended and _engaged,
		"score": _petals_done * PETAL_POINTS + int(devil) * CENTER_POINTS, "mistakes": _mistakes,
		"feedback": _feedback,
	}
