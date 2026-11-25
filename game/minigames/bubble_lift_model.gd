extends RefCounted

enum { DOCK, TRANSIT, FINISHED }
const LEFT_PUMP := 1
const RIGHT_PUMP := 2
const BOTH_PUMPS := LEFT_PUMP | RIGHT_PUMP
const ALL_CARGO := 7
const TICK := 1.0 / 60.0
const ROUND_SECONDS := 82.0
const MAX_GAS := 2.65
const VENT_RATE := 1.15
const BASKET_HEIGHT := 1.32
const FORK_LENGTH := 3.2
const SPLIT_COST := 0.12
const DELIVERY_POINTS := 130
const SPLIT_POINTS := 100
const MISS_PENALTY := 20
const COURSES := [
	{"name": "琥珀熱槽", "masses": [0.74, 1.06, 0.90], "pumps": Vector2(1.00, 0.82),
		"heat": Vector2(5.7, 13.2), "heat_height": 2.50, "period": 3.30, "cool": 1.58,
		"offset": 0.0, "fork": 16.6, "end": 26.0},
	{"name": "蜜糖高井", "masses": [1.12, 0.78, 0.98], "pumps": Vector2(0.76, 1.05),
		"heat": Vector2(7.2, 15.5), "heat_height": 2.75, "period": 3.75, "cool": 1.51,
		"offset": 0.60, "fork": 18.9, "end": 28.5},
]

class Parcel:
	var cargo: int
	var mass: float
	var gas: float
	var shell := 1.0
	var distance := 0.0
	var height := BASKET_HEIGHT
	var rise := 0.0
	var lane := 0
	var returning := false
	var return_dock := 0.0

	func _init(mask: int, load_mass: float, pressure: float) -> void:
		cargo = mask
		mass = load_mass
		gas = pressure

	func advance(venting: bool, heated: bool) -> void:
		var decay := 0.025 + (0.17 if heated else 0.0) + (VENT_RATE if venting else 0.0)
		gas = maxf(0.0, gas - decay * TICK)
		shell = maxf(0.0, shell - (0.93 if heated else 0.0) * TICK)
		var target_rise := 1.35 * (gas - mass - 0.12) + lane * 0.39
		rise = move_toward(rise, clampf(target_rise, -1.7, 1.65), 3.50 * TICK)
		height += rise * TICK
		distance += (5.55 + 0.20 * gas + lane * 0.18) * TICK

	func descend() -> bool:
		height = move_toward(height, 0.46, 1.85 * TICK)
		distance = move_toward(distance, return_dock, 9.0 * TICK)
		return height <= 0.46 and is_equal_approx(distance, return_dock)

	func export_state() -> Dictionary:
		return {"cargo": cargo, "mass": mass, "gas": gas, "shell": shell, "distance": distance,
			"height": height, "rise": rise, "lane": lane, "returning": returning}

var _layout := 0
var _course: Dictionary = COURSES[0]
var _assisted := false
var _helper := false
var _phase := DOCK
var _selection := 1
var _loaded := 0
var _gas := 0.0
var _pump_mask := 0
var _venting := false
var _parcels: Array[Parcel] = []
var _elapsed := 0.0
var _unprocessed := 0.0
var _delivered := 0
var _trip_delivered := 0
var _trip_split := false
var _paired_success := false
var _mistakes := 0
var _worked := false
var _feedback := ""
var _notes: Array[int] = []

func reset(assisted: bool, layout: int) -> void:
	_layout = posmod(layout, COURSES.size())
	_course = COURSES[_layout]
	_assisted = assisted
	_helper = false
	_phase = DOCK
	_selection = 1
	_parcels.clear()
	_elapsed = 0.0
	_unprocessed = 0.0
	_delivered = 0
	_paired_success = false
	_mistakes = 0
	_worked = false
	_notes.clear()
	_open_dock("選載重，確認裝桶後踩泵。")

func phase() -> int:
	return _phase

func choose_count(count: int) -> void:
	if _phase != DOCK or count == _selection or count < 1 or count > 2:
		return
	if count > 3 - cargo_count(_delivered):
		_feedback = "只剩一桶，使用單桶籃。"
		return
	_selection = count
	_loaded = 0
	_gas = 0.0
	clear_input()
	_feedback = "已更換乘籃，請重新確認載重。"

func toggle_helper() -> void:
	if _phase != DOCK:
		return
	_helper = not _helper
	_feedback = "確認裝載後，踩任一泵即可得到 AI 補泵。" if _helper else "兩座泵由你操作。"

func confirm_or_split() -> void:
	if _phase == DOCK:
		_load()
	elif _phase == TRANSIT:
		_split()

func set_holds(pump_mask: int, venting: bool) -> void:
	_pump_mask = (pump_mask & BOTH_PUMPS) if _phase == DOCK and _loaded != 0 else 0
	_venting = venting and (_phase == TRANSIT or (_phase == DOCK and _loaded != 0))

func clear_input() -> void:
	_pump_mask = 0
	_venting = false

func release_basket() -> void:
	if _phase != DOCK:
		return
	if _loaded == 0:
		_feedback = "先確認裝載，再踩泵。"
		return
	if _gas < 0.42:
		_feedback = "泡量不足，先踩泵。"
		return
	_parcels.append(Parcel.new(_loaded, _mass_of(_loaded), _gas))
	_trip_delivered = 0
	_trip_split = false
	_phase = TRANSIT
	clear_input()
	_feedback = "盯住泡壁與橘色熱槽。升太高時可排氣。"

func step(delta: float) -> void:
	if _phase == FINISHED or not is_finite(delta) or delta <= 0.0:
		return
	_unprocessed += minf(delta, 0.25)
	while _unprocessed + 0.0000001 >= TICK and _phase != FINISHED:
		_unprocessed -= TICK
		_elapsed = minf(ROUND_SECONDS, _elapsed + TICK)
		if _phase == DOCK:
			_step_pump()
		else:
			_step_transit()
		if _elapsed >= ROUND_SECONDS - 0.000001 and _phase != FINISHED:
			_elapsed = ROUND_SECONDS
			_finish("時間到。")

func _load() -> void:
	if _loaded != 0:
		return
	for index in 3:
		var bit := 1 << index
		if (_delivered & bit) == 0:
			_loaded |= bit
			if cargo_count(_loaded) == _selection:
				break
	_feedback = "已裝載。踩泵至綠帶，參考熱槽預告再放籃。"

func _step_pump() -> void:
	if _loaded == 0:
		return
	var pumps := _effective_pumps()
	var rates: Vector2 = _course.pumps
	var charge := float((pumps & LEFT_PUMP) != 0) * rates.x + float((pumps & RIGHT_PUMP) != 0) * rates.y
	_gas = clampf(_gas + (charge - (VENT_RATE if _venting else 0.0)) * TICK, 0.0, MAX_GAS)

func _effective_pumps() -> int:
	return BOTH_PUMPS if _helper and _pump_mask != 0 else _pump_mask

func _step_transit() -> void:
	var heat: Vector2 = _course.heat
	var hotter := not _is_cool(_elapsed)
	for index in range(_parcels.size() - 1, -1, -1):
		var bubble := _parcels[index]
		if bubble.returning:
			if bubble.descend():
				_parcels.remove_at(index)
			continue
		var in_heat: bool = bubble.distance >= heat.x and bubble.distance <= heat.y and bubble.height < _course.heat_height
		bubble.advance(_venting, hotter and in_heat)
		_worked = _worked or bubble.distance >= 2.0
		if bubble.shell <= 0.0:
			_lose(index, "高熱耗盡泡壁。")
		elif bubble.height < 0.42:
			_lose(index, "載重過高，泡量撐不住乘籃。")
		elif bubble.height > 5.60:
			_lose(index, "升得太高，碰到井頂。")
		elif bubble.distance >= _course.end:
			_receive(index)
	if _parcels.is_empty():
		if _trip_split and cargo_count(_trip_delivered) == 2:
			_paired_success = true
		if _delivered == ALL_CARGO:
			_finish("雙泡分送完成，三桶全數到站！" if _paired_success else "三桶全數到站！")
		else:
			var message := "已緩降回收，重新裝入未送達的桶。" if _assisted and _trip_delivered == 0 else _feedback
			_open_dock(message)

func _split() -> void:
	if _parcels.size() != 1 or _selection != 2 or _trip_split:
		return
	var parent := _parcels[0]
	if parent.returning:
		return
	if not _can_split():
		_feedback = "等大泡進入紫色分流段再分泡。"
		return
	var available := parent.gas - SPLIT_COST
	if available <= 0.0:
		_feedback = "泡量太少，無法分成雙泡。"
		return
	_parcels.clear()
	var lane := -1
	for index in 3:
		var mask := 1 << index
		if (parent.cargo & mask) == 0:
			continue
		var mass := _mass_of(mask)
		var child := Parcel.new(mask, mass, available * mass / parent.mass)
		child.distance = parent.distance
		child.height = parent.height
		child.rise = parent.rise
		child.shell = parent.shell
		child.lane = lane
		lane += 2
		_parcels.append(child)
	_trip_split = true
	_feedback = "分成雙泡，各自帶一桶前往接收台。"

func _receive(index: int) -> void:
	var bubble := _parcels[index]
	if cargo_count(bubble.cargo) != 1:
		_lose(index, "雙桶大泡進不了接收台，需在分流段分泡。")
		return
	var height_range := reception_range(bubble.lane, _assisted)
	if bubble.height < height_range.x or bubble.height > height_range.y:
		_lose(index, "乘籃高度偏離接收台。調整泡量或提早排氣。")
		return
	_delivered |= bubble.cargo
	_trip_delivered |= bubble.cargo
	_notes.append(cargo_count(_delivered) % 4)
	_parcels.remove_at(index)
	_feedback = "接收台收到一桶。"

static func reception_range(lane: int, assisted: bool) -> Vector2:
	var tolerance := 0.22 if assisted else 0.0
	match lane:
		-1: return Vector2(0.85 - tolerance, 3.56 + tolerance)
		1: return Vector2(1.90 - tolerance, 5.14 + tolerance)
	return Vector2(0.93 - tolerance, 4.55 + tolerance)

func _lose(index: int, cause: String) -> void:
	_mistakes += 1
	var bubble := _parcels[index]
	if _assisted:
		bubble.returning = true
		var heat: Vector2 = _course.heat
		bubble.return_dock = 0.0 if bubble.distance < (heat.x + heat.y) * 0.5 else heat.y
		_feedback = cause + "輔助將緩降收回。"
	else:
		_parcels.remove_at(index)
		_feedback = cause + "取回未送達的桶再試。"

func _open_dock(message: String) -> void:
	_phase = DOCK
	_loaded = 0
	_gas = 0.0
	_selection = mini(_selection, 3 - cargo_count(_delivered))
	clear_input()
	_feedback = message

func _finish(message: String) -> void:
	_phase = FINISHED
	clear_input()
	_feedback = message

func _mass_of(mask: int) -> float:
	var total := 0.0
	for index in 3:
		if (mask & (1 << index)) != 0:
			total += _course.masses[index]
	return total

static func cargo_count(mask: int) -> int:
	return int((mask & 1) != 0) + int((mask & 2) != 0) + int((mask & 4) != 0)

func _can_split() -> bool:
	return _selection == 2 and not _trip_split and _parcels.size() == 1 and not _parcels[0].returning \
		and _parcels[0].distance >= _course.fork and _parcels[0].distance <= _course.fork + FORK_LENGTH

func _is_cool(at: float) -> bool:
	return fposmod(at + _course.offset, _course.period) < _course.cool

func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes

func snapshot() -> Dictionary:
	var cargo: Array[Dictionary] = []
	for bubble in _parcels:
		cargo.append(bubble.export_state())
	var heat_clock := fposmod(_elapsed + _course.offset, _course.period)
	var cool: bool = heat_clock < _course.cool
	var entry_time: float = _course.heat.x / (5.55 + 0.20 * _gas)
	var mass := _mass_of(_loaded)
	var recommend := Vector2(mass + 0.50, mass + 0.68) if _selection == 1 else Vector2(mass + 0.47, mass + 0.61)
	var success := _delivered == ALL_CARGO
	var devil := success and _paired_success
	var points := cargo_count(_delivered) * DELIVERY_POINTS + int(devil) * SPLIT_POINTS
	return {"layout": _layout, "course_name": _course.name, "phase": _phase, "assisted": _assisted,
		"helper": _helper, "selection": _selection, "loaded": _loaded, "gas": _gas, "load_mass": mass,
		"pump_mask": _effective_pumps(), "venting": _venting, "recommend": recommend, "pump_rates": _course.pumps,
		"cargo": cargo, "masses": _course.masses.duplicate(), "delivered": _delivered, "can_split": _can_split(),
		"split_completed": _paired_success, "trip_split": _trip_split, "heat": _course.heat, "heat_height": _course.heat_height,
		"cool": cool, "heat_change": (_course.cool if cool else _course.period) - heat_clock,
		"entry_time": entry_time, "entry_cool": _is_cool(_elapsed + entry_time), "fork": _course.fork, "end": _course.end,
		"feedback": _feedback, "elapsed": _elapsed, "remaining": ROUND_SECONDS - _elapsed,
		"mistakes": _mistakes, "score": maxi(0, points - _mistakes * MISS_PENALTY), "ended": _phase == FINISHED,
		"success": success, "devil": devil, "ordinary_eligible": _phase == FINISHED and _worked}
