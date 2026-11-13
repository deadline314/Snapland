extends RefCounted
class_name TideLockModel

## Lock cross-section along x (metres): sea side x < 0, chamber 0..CHAMBER, basin beyond.
## Ships arrive from the sea and rise into the basin. The chamber level follows an open
## gate's side, or the selected valve; the two gates never open together.
const ROUND_SECONDS := 180.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const CHAMBER := 10.0
const BASIN_LEVEL := 3.5
const BASIN_MIN := 3.0
const BASIN_DRAW := 0.06
const VALVE_RATE := 0.5
const LEVEL_MATCH := 0.15
const CLEARANCE := 0.1
const SHIP_SPEED := 1.5
const SHIP_GAP := 0.8
const GATE_MARGIN := 0.3
const SPAWN_X := -7.0
const PATIENCE := 35.0
const BELL_LEAD := 6.0
const PREVIEW_SECONDS := 20.0
const SHIP_POINTS := 100
const CLOSE_POINTS := 100
const DEVIL_POINTS := 100
const GROUND_PENALTY := 50
const HORN_PENALTY := 20
## Retries change ship lengths, drafts, arrival spacing and the outer tide.
const LAYOUTS := [
	{"name": "東閘 · 午潮", "tide_mid": 1.7, "tide_amp": 1.0, "period": 48.0, "phase": 0.0,
		"ships": [{"name": "藍篷漁船", "length": 4.0, "draft": 1.0, "arrive": 2.0}, {"name": "紅身貨船", "length": 4.5, "draft": 1.3, "arrive": 9.0},
			{"name": "白帆小艇", "length": 3.5, "draft": 0.9, "arrive": 30.0}]},
	{"name": "西閘 · 夜潮", "tide_mid": 1.8, "tide_amp": 1.0, "period": 52.0, "phase": 1.2,
		"ships": [{"name": "長身駁船", "length": 5.0, "draft": 1.2, "arrive": 3.0}, {"name": "黃頂渡輪", "length": 3.5, "draft": 0.9, "arrive": 16.0},
			{"name": "綠旗拖船", "length": 4.0, "draft": 1.1, "arrive": 22.0}]},
]

var _assisted := false
var _variant := 0
var _layout: Dictionary = {}
var _elapsed := 0.0
var _level := 0.0
var _basin := BASIN_LEVEL
var _lower_open := false
var _upper_open := false
var _valve := 0
var _helper := false
var _ships: Array[Dictionary] = []
var _passed := 0
var _groundings := 0
var _horns := 0
var _paired_lift := false
var _rung_extreme := -1
var _ended := false
var _success := false
var _feedback := ""
var _last_event := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, LAYOUTS.size())
	_layout = LAYOUTS[_variant]
	_elapsed = 0.0
	_level = sea_level(0.0)
	_basin = BASIN_LEVEL
	_lower_open = false
	_upper_open = false
	_valve = 0
	_helper = false
	_ships.clear()
	for row: Dictionary in _layout.ships:
		_ships.append({"name": row.name, "length": row.length, "draft": row.draft, "arrive": row.arrive,
			"front": SPAWN_X, "present": false, "passed": false, "grounded": false, "wait": 0.0})
	_passed = 0
	_groundings = 0
	_horns = 0
	_paired_lift = false
	_rung_extreme = -1
	_ended = false
	_success = false
	_last_event = ""
	_feedback = "聽潮鐘預告：水位對齊才能開閘；三船過閘後關閘關閥"

func sea_level(at: float) -> float:
	return float(_layout.tide_mid) + float(_layout.tide_amp) * sin(TAU * at / float(_layout.period) + float(_layout.phase))

## Next high or low water after `at`: [time, is_high].
func next_extreme(at: float) -> Array:
	var omega: float = TAU / float(_layout.period)
	var turns := ceilf((omega * at + float(_layout.phase) - PI / 2.0) / PI + 0.000001)
	var when: float = (turns * PI + PI / 2.0 - float(_layout.phase)) / omega
	return [when, posmod(int(turns), 2) == 0]

func _in_chamber(ship: Dictionary) -> bool:
	return ship.present and not ship.passed and ship.front > 0.0 and ship.front - ship.length < CHAMBER

func _straddles(ship: Dictionary, gate_x: float) -> bool:
	return ship.present and not ship.passed and ship.front - ship.length < gate_x + 0.2 and ship.front > gate_x - 0.2

func lower_safe() -> bool:
	return not _upper_open and _valve != 1 and absf(_level - sea_level(_elapsed)) <= LEVEL_MATCH

func upper_safe() -> bool:
	return not _lower_open and _valve != -1 and absf(_level - _basin) <= LEVEL_MATCH

## Q / E: lower (sea) and upper (basin) gates.
func toggle_gate(upper: bool) -> void:
	if _ended:
		return
	var gate_x := CHAMBER if upper else 0.0
	var open: bool = _upper_open if upper else _lower_open
	var label := "上閘" if upper else "下閘"
	if open:
		for ship in _ships:
			if _straddles(ship, gate_x):
				_feedback = "%s卡在%s口，等船身過去再關" % [ship.name, label]
				return
		_set_gate(upper, false)
		_feedback = "%s關上" % label
		return
	if (_lower_open if upper else _upper_open):
		_feedback = "另一道閘還開著；兩閘不能同開"
		return
	if not (upper_safe() if upper else lower_safe()):
		var target: float = _basin if upper else sea_level(_elapsed)
		_feedback = "%s兩側差 %.2f m，先%s對齊水位" % [label, absf(_level - target), "蓄水" if _level < target else "放水"]
		return
	_set_gate(upper, true)
	_valve = 0
	_feedback = "%s打開" % label

func _set_gate(upper: bool, value: bool) -> void:
	if upper:
		_upper_open = value
	else:
		_lower_open = value

## A / D: drain toward the sea or fill from the basin; pressing again holds.
func toggle_valve(direction: int) -> void:
	if _ended or direction == 0:
		return
	if _valve == direction:
		_valve = 0
		_feedback = "閥門關上，水位保持"
		return
	if direction > 0 and _lower_open:
		_feedback = "下閘開著不能蓄水"
		return
	if direction < 0 and _upper_open:
		_feedback = "上閘開著不能放水"
		return
	_valve = direction
	_feedback = "開閥蓄水（用港池的水）" if direction > 0 else "開閥放水到外海"

## R: the simple AI only opens the lower gate while its safety light is on.
func toggle_helper() -> void:
	if _ended:
		return
	_helper = not _helper
	_feedback = "閘工%s：只在下閘安全燈亮時開下閘" % ("上崗" if _helper else "休息")

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, SUBSTEP)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	var sea := sea_level(_elapsed)
	_ring_bell()
	if _lower_open:
		_level = sea
	elif _upper_open:
		_level = _basin
	elif _valve != 0:
		var target: float = _basin if _valve > 0 else sea
		var change := clampf(target - _level, -VALVE_RATE * dt, VALVE_RATE * dt)
		if _valve > 0 and change > 0.0:
			_basin = maxf(0.0, _basin - change * BASIN_DRAW)
		_level += change
	if _helper and not _lower_open and lower_safe() and _ship_waiting():
		toggle_gate(false)
		_feedback = "閘工見安全燈亮，開下閘放船"
	_move_ships(dt)
	_check_grounding()
	_check_finish()
	if not _ended and _elapsed >= ROUND_SECONDS:
		_ended = true
		_feedback = "時間到：%d 船過閘%s" % [_passed, "，閘門或閥門還開著" if _passed == _ships.size() else ""]

func _ring_bell() -> void:
	var next := next_extreme(_elapsed)
	var index := roundi(float(next[0]) * 1000.0)
	if float(next[0]) - _elapsed <= BELL_LEAD and index != _rung_extreme:
		_rung_extreme = index
		_last_event = "bell"
		_feedback = "叮！%d 秒後%s（外海 %.1f m）" % [ceili(float(next[0]) - _elapsed), "滿潮" if next[1] else "乾潮", sea_level(float(next[0]))]

func _ship_waiting() -> bool:
	for ship in _ships:
		if ship.present and not ship.passed and ship.front <= 0.0 and ship.front >= -GATE_MARGIN - 0.6:
			return true
	return false

func _move_ships(dt: float) -> void:
	var ahead := INF
	for ship in _ships:
		if ship.passed:
			continue
		if not ship.present:
			if _elapsed < float(ship.arrive):
				break
			ship.present = true
			ship.front = minf(SPAWN_X, ahead - SHIP_GAP)
			_feedback = "%s到閘外（吃水 %.1f m）" % [ship.name, ship.draft]
		var limit := ahead - SHIP_GAP
		if ship.front <= 0.0:
			var deep_enough: bool = sea_level(_elapsed) >= ship.draft + CLEARANCE
			if not _lower_open or not deep_enough:
				limit = minf(limit, -GATE_MARGIN)
				if _lower_open and not deep_enough and ship.front >= -GATE_MARGIN - 0.05:
					_feedback = "水太淺：%s吃水 %.1f m，等漲潮" % [ship.name, ship.draft]
			ship.wait = ship.wait + dt if ship.front >= -GATE_MARGIN - 0.6 or not _lower_open else 0.0
			if ship.wait > PATIENCE and not _assisted:
				ship.wait = 0.0
				_horns += 1
				_last_event = "horn"
				_feedback = "%s等太久鳴笛抗議（扣 %d）" % [ship.name, HORN_PENALTY]
		else:
			ship.wait = 0.0
		if ship.front <= CHAMBER and not _upper_open:
			limit = minf(limit, CHAMBER - GATE_MARGIN)
		if not ship.grounded:
			ship.front = maxf(ship.front, minf(ship.front + SHIP_SPEED * dt, limit))
		if ship.front - ship.length > CHAMBER + 1.0:
			ship.passed = true
			_passed += 1
			_last_event = "passed"
			_feedback = "%s進港（%d／%d）" % [ship.name, _passed, _ships.size()]
			continue
		ahead = ship.front - ship.length

## A ship whose keel touches the chamber floor is stuck until the water rises again.
func _check_grounding() -> void:
	var inside := 0
	for ship in _ships:
		if not _in_chamber(ship):
			continue
		inside += 1
		if _level < ship.draft + CLEARANCE * 0.5:
			if not ship.grounded:
				ship.grounded = true
				_groundings += 1
				_last_event = "ground"
				_feedback = "%s擱淺！閘室水位 %.1f m 低於吃水 %.1f m" % [ship.name, _level, ship.draft]
		elif ship.grounded and _level >= ship.draft + CLEARANCE:
			ship.grounded = false
	if _upper_open and inside >= 2 and _groundings == 0:
		_paired_lift = true

func _check_finish() -> void:
	if _passed < _ships.size() or _lower_open or _upper_open or _valve != 0:
		return
	_ended = true
	_success = true
	_last_event = "closed"
	_feedback = "三船過閘，閘門與閥門都關好了" + ("；一次蓄水送了兩艘" if devil() else "")

func devil() -> bool:
	return _success and _paired_lift and _groundings == 0

func score() -> int:
	var total := _passed * SHIP_POINTS - _groundings * GROUND_PENALTY - _horns * HORN_PENALTY
	if _success:
		total += CLOSE_POINTS + roundi(maxf(0.0, _basin - BASIN_MIN) * 100.0)
	if devil():
		total += DEVIL_POINTS
	return maxi(0, total)

func snapshot() -> Dictionary:
	var ships: Array = []
	for ship in _ships:
		ships.append(ship.duplicate())
	var next := next_extreme(_elapsed)
	var preview: Array = []
	for i in roundi(PREVIEW_SECONDS / 2.0) + 1:
		preview.append(sea_level(_elapsed + i * 2.0))
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": _layout.name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil(), "devil_success": devil(),
		"ordinary_eligible": _ended, "score": score(), "mistakes": _groundings + _horns, "groundings": _groundings, "horns": _horns,
		"sea": sea_level(_elapsed), "level": _level, "basin": _basin, "lower_open": _lower_open, "upper_open": _upper_open, "valve": _valve,
		"lower_safe": lower_safe(), "upper_safe": upper_safe(), "helper": _helper, "ships": ships, "passed": _passed,
		"paired_lift": _paired_lift, "next_extreme": next[0], "next_high": next[1], "preview": preview,
		"feedback": _feedback, "last_event": _last_event,
	}
