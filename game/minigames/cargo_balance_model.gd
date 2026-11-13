extends RefCounted
class_name CargoBalanceModel

## Cross-section of a small freighter. Columns 0–2 are pier stacks, 3–6 the hold;
## row 0 is the floor, row 1 sits on a crate below. Heel follows the cargo moment.
const ROUND_SECONDS := 220.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const PIER_COLUMNS := 3
const HOLD_COLUMNS := 4
const COLUMNS := PIER_COLUMNS + HOLD_COLUMNS
const ROWS := 2
const HOLD_X := [-2.25, -0.75, 0.75, 2.25]
const HEEL_PER_MOMENT := 1.4
const TOP_FACTOR := 0.6
const HEEL_LAG := 0.5
const SAFE_HEEL := 10.0
const SLIDE_HEEL := 14.0
const CAPSIZE_HEEL := 24.0
const SAIL_SECONDS := 24.0
const WAVE_FORECAST := 5.0
const ASSIST_WAVE_FORECAST := 8.0
const WAVE_DURATION := 3.0
const ASSIST_WAVE_FACTOR := 0.6
const STRAP_DELAY := 0.8
const MAX_STRAPS := 3
const WAVE_POINTS := 100
const CRATE_POINTS := 50
## Two voyages: crate weights, destination labels and port order all change.
const VARIANTS := [
	{"name": "先甲港", "ports": ["A", "B"], "crates": [[3, "A"], [3, "B"], [2, "A"], [2, "B"], [1, "A"], [1, "B"]],
		"waves": [[1, 6.0, 8.0], [-1, 7.0, 18.0], [-1, 6.0, 8.0], [1, 8.0, 18.0]]},
	{"name": "先乙港", "ports": ["B", "A"], "crates": [[3, "B"], [1, "A"], [2, "B"], [3, "A"], [2, "A"], [1, "B"]],
		"waves": [[-1, 7.0, 7.0], [1, 6.0, 17.0], [1, 7.0, 9.0], [-1, 7.0, 19.0]]},
]
const PORT_NAMES := {"A": "甲港", "B": "乙港"}

var _assisted := false
var _variant := 0
var _elapsed := 0.0
var _phase := "loading"
var _phase_time := 0.0
var _segment := 0
var _crates: Array[Dictionary] = []
var _cursor := Vector2i(0, 0)
var _held := -1
var _heel := 0.0
var _waves: Array[Dictionary] = []
var _slides := 0
var _moves_at_sea := 0
var _ended := false
var _success := false
var _capsized := false
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, VARIANTS.size())
	_elapsed = 0.0
	_phase = "loading"
	_phase_time = 0.0
	_segment = 0
	_crates.clear()
	var spec: Dictionary = VARIANTS[_variant]
	for index in spec.crates.size():
		var row: Array = spec.crates[index]
		_crates.append({"id": index, "weight": int(row[0]), "port": str(row[1]), "cell": Vector2i(index % PIER_COLUMNS, index / PIER_COLUMNS),
			"strapped": false, "strap_timer": -1.0, "delivered": false})
	_cursor = Vector2i(0, 0)
	_held = -1
	_heel = 0.0
	_waves.clear()
	for index in spec.waves.size():
		var wave: Array = spec.waves[index]
		_waves.append({"index": index, "segment": index / 2, "direction": int(wave[0]),
			"strength": float(wave[1]) * (ASSIST_WAVE_FACTOR if assisted else 1.0), "hit": float(wave[2]),
			"peak": 0.0, "done": false, "safe": false, "shifted": false, "slid": false})
	_slides = 0
	_moves_at_sea = 0
	_ended = false
	_success = false
	_capsized = false
	_feedback = "把碼頭上的六箱搬進船艙，按 Enter 出航"

func phase() -> String:
	return _phase

func _docked() -> bool:
	return _phase in ["loading", "port"]

func _crate_at(cell: Vector2i) -> int:
	for crate: Dictionary in _crates:
		if crate.cell == cell and not crate.delivered and crate.id != _held:
			return crate.id
	return -1

func _is_hold(cell: Vector2i) -> bool:
	return cell.x >= PIER_COLUMNS

func move_cursor(offset: Vector2i) -> void:
	if _ended:
		return
	var low := 0 if _docked() else PIER_COLUMNS
	_cursor = Vector2i(clampi(_cursor.x + offset.x, low, COLUMNS - 1), clampi(_cursor.y + offset.y, 0, ROWS - 1))

## Space: lift the crate under the cursor or set the carried crate down.
func grab() -> void:
	if _ended:
		return
	if _held < 0:
		var target := _crate_at(_cursor)
		if target < 0:
			_feedback = "這格沒有箱子"
			return
		if _crate_at(_cursor + Vector2i(0, 1)) >= 0:
			_feedback = "上面壓著箱子，先移開上層"
			return
		if _crates[target].strapped or _crates[target].strap_timer >= 0.0:
			_feedback = "這箱已繫帶，按 F 解開才能搬"
			return
		_held = target
		_feedback = "吊起 %d 噸（%s）" % [_crates[target].weight, PORT_NAMES[_crates[target].port]]
		return
	if _crate_at(_cursor) >= 0:
		_feedback = "這格已有箱子"
		return
	if _cursor.y == 1 and _crate_at(Vector2i(_cursor.x, 0)) < 0:
		_feedback = "上層需要下層撐住"
		return
	if not _docked() and not _is_hold(_cursor):
		_feedback = "航行中只能在船艙內移動"
		return
	var crate: Dictionary = _crates[_held]
	var from_hold: bool = _is_hold(crate.cell)
	crate.cell = _cursor
	_held = -1
	if _phase == "sailing" and _is_hold(_cursor):
		_moves_at_sea += 1
		for wave: Dictionary in _waves:
			if wave.segment == _segment and not wave.done and _phase_time >= wave.hit - _forecast():
				wave.shifted = true
	_feedback = "放下 %d 噸" % crate.weight
	if _phase == "port" and not _is_hold(_cursor) and from_hold:
		_check_port()

## F: the deckhand straps the crate under the cursor after a short delay, or unties it.
func toggle_strap() -> void:
	if _ended:
		return
	var target := _crate_at(_cursor)
	if target < 0 or not _is_hold(_cursor):
		_feedback = "把游標移到船艙裡的箱子再指定繫帶"
		return
	var crate: Dictionary = _crates[target]
	if crate.strapped or crate.strap_timer >= 0.0:
		crate.strapped = false
		crate.strap_timer = -1.0
		_feedback = "解開繫帶"
		return
	if _strap_count() >= MAX_STRAPS:
		_feedback = "繫帶只有 %d 條" % MAX_STRAPS
		return
	crate.strap_timer = 0.0
	_feedback = "船員去綁這箱"

## Enter: sail when every crate is aboard, or leave a port once its cargo is ashore.
func confirm() -> void:
	if _ended:
		return
	if _held >= 0:
		_feedback = "先把吊著的箱子放下"
		return
	if _phase == "loading":
		for crate: Dictionary in _crates:
			if not _is_hold(crate.cell):
				_feedback = "還有箱子在碼頭上"
				return
		_start_sailing()
	elif _phase == "port":
		if not _port_done():
			_feedback = "先把%s的貨卸到碼頭上" % PORT_NAMES[_current_port()]
			return
		_deliver_port()
		if _segment >= 2:
			return
		_start_sailing()
	else:
		_feedback = "航行中，抵港後再操作"

func _start_sailing() -> void:
	_phase = "sailing"
	_phase_time = 0.0
	if _cursor.x < PIER_COLUMNS:
		_cursor.x = PIER_COLUMNS
	_feedback = "出航！看側浪預告移重抗浪"

func _current_port() -> String:
	return VARIANTS[_variant].ports[mini(_segment - 1, 1)]

func _port_done() -> bool:
	for crate: Dictionary in _crates:
		if crate.port == _current_port() and not crate.delivered and _is_hold(crate.cell):
			return false
	return _held < 0

func _check_port() -> void:
	if _port_done():
		_feedback = "%s的貨卸完了，按 Enter %s" % [PORT_NAMES[_current_port()], "結束航程" if _segment >= 2 else "出航"]
		if _segment >= 2:
			_deliver_port()

func _deliver_port() -> void:
	for crate: Dictionary in _crates:
		if crate.port == _current_port() and not _is_hold(crate.cell):
			crate.delivered = true
	if _segment >= 2:
		_ended = true
		_success = true
		_feedback = "兩港貨物都送達"

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
	_phase_time += dt
	for crate: Dictionary in _crates:
		if crate.strap_timer >= 0.0:
			crate.strap_timer += dt
			if crate.strap_timer >= STRAP_DELAY:
				crate.strap_timer = -1.0
				crate.strapped = true
				_feedback = "船員綁好 %d 噸的箱子" % crate.weight
	var target := static_heel() + _wave_heel()
	_heel += (target - _heel) * clampf(dt / HEEL_LAG, 0.0, 1.0)
	if _phase == "sailing":
		_update_waves()
		if absf(_heel) > CAPSIZE_HEEL:
			_capsized = true
			_finish("船身傾斜過大進水，航程中止")
			return
		if _phase_time >= SAIL_SECONDS:
			_segment += 1
			_phase = "port"
			_phase_time = 0.0
			_feedback = "抵達%s：把標示%s的貨卸到碼頭" % [PORT_NAMES[_current_port()], PORT_NAMES[_current_port()]]
	if not _ended and _elapsed >= ROUND_SECONDS:
		_finish("時間到：送達 %d / 6 箱" % _delivered())

func _finish(message: String) -> void:
	_ended = true
	_feedback = message

func _forecast() -> float:
	return ASSIST_WAVE_FORECAST if _assisted else WAVE_FORECAST

func _wave_heel() -> float:
	if _phase != "sailing":
		return 0.0
	var heel := 0.0
	for wave: Dictionary in _waves:
		if wave.segment != _segment:
			continue
		var t: float = _phase_time - wave.hit
		if t >= 0.0 and t <= WAVE_DURATION:
			heel += wave.direction * wave.strength * _sensitivity() * sin(PI * t / WAVE_DURATION)
	return heel

func _update_waves() -> void:
	for wave: Dictionary in _waves:
		if wave.segment != _segment or wave.done:
			continue
		var t: float = _phase_time - wave.hit
		if t < 0.0:
			continue
		wave.peak = maxf(wave.peak, absf(_heel))
		if absf(_heel) > SLIDE_HEEL and not wave.slid:
			wave.slid = true
			_slide(signi(roundi(signf(_heel))))
		if t > WAVE_DURATION + HEEL_LAG * 2.0:
			wave.done = true
			wave.safe = wave.peak <= SAFE_HEEL
			_feedback = "側浪過去：最大傾斜 %.1f°%s" % [wave.peak, "，安全" if wave.safe else "，超過安全線"]

## Unstrapped hold crates slide one column toward the low side when space allows.
func _slide(low_side: int) -> void:
	var order: Array = _crates.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cell.x * low_side > b.cell.x * low_side)
	for crate: Dictionary in order:
		if crate.delivered or crate.strapped or crate.id == _held or not _is_hold(crate.cell):
			continue
		var target: Vector2i = crate.cell + Vector2i(low_side, 0)
		if target.x < PIER_COLUMNS or target.x >= COLUMNS or _crate_at(target) >= 0 or _crate_at(crate.cell + Vector2i(0, 1)) >= 0:
			continue
		if target.y == 1 and _crate_at(Vector2i(target.x, 0)) < 0:
			continue
		_crates[crate.id].cell = target
		_slides += 1
		_feedback = "沒繫帶的箱子滑到低側！"

func cell_x(cell: Vector2i) -> float:
	return HOLD_X[cell.x - PIER_COLUMNS] if _is_hold(cell) else -5.6 + cell.x * 1.2 - 2.4

func moment() -> float:
	var total := 0.0
	for crate: Dictionary in _crates:
		if crate.delivered:
			continue
		var cell: Vector2i = _cursor if crate.id == _held else crate.cell
		if _is_hold(cell):
			total += crate.weight * cell_x(cell)
	return total

func _sensitivity() -> float:
	var total := 0.0
	var top := 0.0
	for crate: Dictionary in _crates:
		if crate.delivered or crate.id == _held or not _is_hold(crate.cell):
			continue
		total += crate.weight
		if crate.cell.y == 1:
			top += crate.weight
	return HEEL_PER_MOMENT * (1.0 + TOP_FACTOR * top / maxf(1.0, total))

func static_heel() -> float:
	return moment() * _sensitivity()

func _strap_count() -> int:
	var count := 0
	for crate: Dictionary in _crates:
		if crate.strapped or crate.strap_timer >= 0.0:
			count += 1
	return count

func _delivered() -> int:
	var count := 0
	for crate: Dictionary in _crates:
		if crate.delivered:
			count += 1
	return count

func snapshot() -> Dictionary:
	var safe_waves := 0
	var shifted := false
	var all_safe := true
	for wave: Dictionary in _waves:
		if wave.done and wave.safe:
			safe_waves += 1
		if not (wave.done and wave.safe):
			all_safe = false
		shifted = shifted or (wave.shifted and wave.safe)
	var devil := _success and all_safe and shifted
	var upcoming: Dictionary = {}
	if _phase == "sailing":
		for wave: Dictionary in _waves:
			if wave.segment == _segment and not wave.done:
				upcoming = {"index": wave.index, "direction": wave.direction, "in": maxf(0.0, wave.hit - _phase_time), "strength": wave.strength,
					"visible": _phase_time >= wave.hit - _forecast(), "predicted": static_heel() + wave.direction * wave.strength * _sensitivity()}
				break
	var crates: Array = []
	for crate: Dictionary in _crates:
		var row := crate.duplicate()
		row.held = crate.id == _held
		row.x = cell_x(_cursor if row.held else crate.cell)
		crates.append(row)
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": VARIANTS[_variant].name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil, "devil_success": devil,
		"ordinary_eligible": _ended, "score": safe_waves * WAVE_POINTS + _delivered() * CRATE_POINTS, "mistakes": _slides + (_waves.size() - safe_waves if _ended else 0),
		"phase": _phase, "phase_time": _phase_time, "segment": _segment, "port": _current_port() if _phase == "port" else "", "port_order": VARIANTS[_variant].ports,
		"crates": crates, "cursor": _cursor, "held": _held, "heel": _heel, "static_heel": static_heel(), "moment": moment(), "sensitivity": _sensitivity(),
		"waves": _waves.duplicate(true), "upcoming": upcoming, "safe_waves": safe_waves, "slides": _slides, "moves_at_sea": _moves_at_sea,
		"straps": _strap_count(), "delivered": _delivered(), "capsized": _capsized, "safe_heel": SAFE_HEEL, "slide_heel": SLIDE_HEEL,
		"capsize_heel": CAPSIZE_HEEL, "port_done": _phase == "port" and _port_done(), "feedback": _feedback, "last_event": _feedback,
	}
