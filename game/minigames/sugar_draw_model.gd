extends RefCounted

const TICK := 1.0 / 60.0
const ROUND_SECONDS := 88.0
const SLOW := 1
const STEADY := 2
const FAST := 3
const RATES := [0.0, 0.58, 0.96, 1.43]
const THERMAL_MIN := 0.33
const MELT_POINT := 0.90
const FOLD_FACTOR := 1.41421356237
const SECTION_POINTS := 150
const FOLD_POINTS := 100
const LOSS_POINTS := 20
const MATERIALS := [
	{"name": "琥珀麥芽", "initial": 0.59, "cool": 0.033, "feed": 1.19,
		"widths": [1.19, 0.99, 0.80], "lengths": [1.55, 1.90, 1.35]},
	{"name": "紅糖薄片", "initial": 0.63, "cool": 0.061, "feed": 1.18,
		"widths": [0.96, 1.17, 0.79], "lengths": [1.70, 1.65, 1.75]},
]

var _material: Dictionary = MATERIALS[0]
var _layout := 0
var _assisted := false
var _helper := false
var _helper_heating := false
var _manual_heat := false
var _pull := 0
var _temperature := 0.59
var _tension := 0.0
var _damage := 0.0
var _elapsed := 0.0
var _unprocessed := 0.0
var _length := 0.0
var _min_width := INF
var _max_width := 0.0
var _area := 0.0
var _width := 0.0
var _samples := PackedFloat32Array()
var _sections: Array[Dictionary] = []
var _folds := 0
var _mistakes := 0
var _worked_length := 0.0
var _ended := false
var _feedback := ""
var _notes: Array[int] = []
var _revision := 0

func reset(assist: bool, layout: int) -> void:
	_layout = posmod(layout, MATERIALS.size())
	_material = MATERIALS[_layout]
	_assisted = assist
	_helper = false
	_helper_heating = false
	_temperature = _material.initial
	_elapsed = 0.0
	_unprocessed = 0.0
	_sections.clear()
	_notes.clear()
	_folds = 0
	_mistakes = 0
	_worked_length = 0.0
	_ended = false
	_reset_strand()
	_feedback = "看目標絲徑選拉速，滿一倍長度可收段。"

func toggle_helper() -> void:
	if _ended:
		return
	_helper = not _helper
	_helper_heating = _helper and _temperature < 0.51
	_feedback = "AI 協助加熱，拉速和回折由你操作。" if _helper else "切回手動控溫。"

func hold(speed: int, heat: bool) -> void:
	_pull = clampi(speed, 0, FAST) if not _ended else 0
	_manual_heat = heat and not _ended

func clear_input() -> void:
	_pull = 0
	_manual_heat = false

func strand_revision() -> int:
	return _revision

func cut() -> void:
	if _ended:
		return
	if _length < _goal_length() - 0.00001:
		_feedback = "糖絲未滿一倍長度。"
	elif not _in_band(1.0):
		_feedback = "絲徑有偏差。過細可拉到兩倍回折，或退料重拉。"
	else:
		_finish_section(false)

func fold() -> void:
	if _ended:
		return
	if _length < 2.0 * _goal_length() - 0.00001:
		_feedback = "回折需要兩倍原長。"
	elif _max_width >= _band().x or not _in_band(FOLD_FACTOR):
		_feedback = "回折後仍會超出目標絲徑，請退料重拉。"
	else:
		_finish_section(true)

func discard() -> void:
	if _ended or _length <= 0.0:
		return
	_mistakes += 1
	_reset_strand()
	_feedback = "已退回未收的糖絲，可重拉這一段。"

func step(delta: float) -> void:
	if _ended or delta <= 0.0 or not is_finite(delta):
		return
	_unprocessed += minf(delta, 0.25)
	while _unprocessed + 0.0000001 >= TICK and not _ended:
		_unprocessed -= TICK
		_elapsed += TICK
		_advance()
		if _elapsed >= ROUND_SECONDS - 0.000001:
			_elapsed = ROUND_SECONDS
			_ended = true
			clear_input()
			_feedback = "時間到。"

func _advance() -> void:
	var max_length := 2.0 * _goal_length()
	var rate: float = RATES[_pull] if _length < max_length - 0.00001 else 0.0
	if _helper:
		if _temperature < 0.51: _helper_heating = true
		elif _temperature >= 0.63: _helper_heating = false
	var cooling: float = _material.cool + rate * 0.020
	_temperature = clampf(_temperature + (0.28 * float(_manual_heat or _helper_heating) - cooling) * TICK, 0.10, 1.08)
	if rate == 0.0:
		_tension = 0.0
		_damage = maxf(0.0, _damage - 0.55 * TICK)
		return
	_tension = rate * (1.04 - _temperature * 0.76)
	if _temperature >= MELT_POINT:
		_damage += 3.2 * TICK
	elif _temperature < THERMAL_MIN:
		_damage += (0.55 + _tension) * TICK
	else:
		_damage = clampf(_damage + (maxf(0.0, _tension - 0.91) * 1.8 - 0.32) * TICK, 0.0, 1.0)
	if _damage >= 1.0:
		_break_strand(_temperature >= MELT_POINT)
		return
	_width = (_material.feed - _temperature * 0.40) / sqrt(rate)
	var length_added := minf(rate * TICK, max_length - _length)
	_length += length_added
	_worked_length += length_added
	_area += _width * _width * length_added
	_min_width = minf(_min_width, _width)
	_max_width = maxf(_max_width, _width)
	if _samples.size() < 24 and (_samples.is_empty() or _length >= _samples.size() * max_length / 24.0):
		_samples.append(_width)

func _break_strand(melted: bool) -> void:
	_mistakes += 1
	if not _assisted:
		_sections.clear()
		_folds = 0
	_reset_strand()
	_temperature = _material.initial
	var cause := "過熱，糖絲滴落。" if melted else "糖料太冷，拉力使糖絲斷開。"
	_feedback = cause + ("已接回完成的段落。" if _assisted else "從第一段重新抽絲。")

func _finish_section(folded: bool) -> void:
	var factor := FOLD_FACTOR if folded else 1.0
	_sections.append({"width": _actual_width() * factor, "length": _goal_length(),
		"raw_length": _length, "folded": folded})
	_folds += int(folded)
	if _notes.size() < 4:
		_notes.append(_sections.size())
	_reset_strand()
	_ended = _sections.size() == 3
	if _ended:
		_feedback = "三段完成，合格雙股已接入！" if _folds > 0 else "三段糖絲都已完成！"
	else:
		_feedback = "雙股回折完成，依下一段絲徑繼續。" if folded else "已收一段，依下一段絲徑繼續。"

func _reset_strand() -> void:
	_revision += 1
	clear_input()
	_tension = 0.0
	_damage = 0.0
	_length = 0.0
	_min_width = INF
	_max_width = 0.0
	_area = 0.0
	_width = 0.0
	_samples.clear()

func _section_index() -> int:
	return mini(_sections.size(), 2)

func _goal_length() -> float:
	return _material.lengths[_section_index()]

func _band() -> Vector2:
	var aim: float = _material.widths[_section_index()]
	var tolerance := 0.16 if _assisted else 0.125
	return Vector2(aim - tolerance, aim + tolerance)

func _in_band(factor: float) -> bool:
	var limits := _band()
	return _length > 0.0 and _min_width * factor >= limits.x and _max_width * factor <= limits.y

func _actual_width() -> float:
	return sqrt(_area / _length) if _length > 0.0 else 0.0

func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes

func snapshot() -> Dictionary:
	var success := _sections.size() == 3
	var devil := success and _folds > 0
	var totals := _sections.size() * SECTION_POINTS + int(devil) * FOLD_POINTS
	return {"layout": _layout, "name": _material.name, "assisted": _assisted, "helper": _helper,
		"heating": _manual_heat or _helper_heating, "pull": _pull, "temperature": _temperature, "tension": _tension,
		"damage": _damage, "length": _length, "goal_length": _goal_length(), "band": _band(),
		"target_widths": _material.widths.duplicate(), "target_lengths": _material.lengths.duplicate(),
		"width": _width, "avg_width": _actual_width(), "samples": _samples, "sections": _sections.duplicate(true),
		"cut_ready": _length >= _goal_length() - 0.00001 and _in_band(1.0),
		"fold_ready": _length >= 2.0 * _goal_length() - 0.00001 and _max_width < _band().x and _in_band(FOLD_FACTOR),
		"elapsed": _elapsed, "remaining": ROUND_SECONDS - _elapsed, "feedback": _feedback, "folds": _folds,
		"mistakes": _mistakes, "score": maxi(0, totals - _mistakes * LOSS_POINTS), "ended": _ended,
		"success": success, "devil": devil, "ordinary_eligible": _ended and _worked_length >= 0.25}
