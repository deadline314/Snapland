extends RefCounted
class_name SyrupFloodModel

const ROUND_SECONDS := 75.0
const SUBSTEP := 1.0 / 60.0
const PLUG_REQUIRED := 12.0

var _s: Dictionary

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	variant = posmod(variant, 2)
	_s = {"elapsed": 0.0, "remaining": ROUND_SECONDS, "score": 0, "mistakes": 0,
		"ended": false, "success": false, "devil": false, "ordinary_eligible": false,
		"participated": false, "assisted": assisted, "variant": variant,
		"selected": 0, "heater": -1, "helper": -1, "configuration_paused": false,
		"diversion": false, "cold_plugged": false, "plug_amount": 0.0,
		"plug_required": PLUG_REQUIRED, "filled_tanks": 0, "branches": [],
		"feedback": "熱糖快，保留中管冷糖可堵裂口；達刻線後關閥"}
	var lengths: Array = [1.0, 1.35, 0.85] if variant == 0 else [1.3, 0.85, 1.1]
	var heats: Array = [1.0, 1.4, 0.8] if variant == 0 else [1.6, 0.75, 1.2]
	var capacities := [100.0, 110.0, 90.0]
	for i in 3:
		_s.branches.append({"length": lengths[i], "heat_capacity": heats[i],
			"capacity": capacities[i], "target": 0.9 * capacities[i],
			"temperature": 0.18, "viscosity": _viscosity(0.18), "flow": 0.0,
			"fill": 0.0, "valve": false, "spoiled": false, "leaked": 0.0})

func select_branch(index: int) -> void:
	if not _s.ended and index >= 0 and index < 3:
		_s.selected = index

func select_next(direction: int = 1) -> void:
	if not _s.ended and direction != 0:
		_s.selected = posmod(int(_s.selected) + signi(direction), 3)

func toggle_valve() -> void:
	if _s.ended:
		return
	var branch: Dictionary = _s.branches[_s.selected]
	if branch.spoiled:
		_s.feedback = "溢出缸先排空，再開閥；時間不回復"
		return
	branch.valve = not branch.valve
	if not branch.valve:
		branch.flow = 0.0
	_s.participated = true
	_s.feedback = "已開閥" if branch.valve else "已關閥"
	if not _s.configuration_paused:
		_check_result()

func toggle_heater() -> void:
	if not _s.ended:
		_s.heater = -1 if _s.heater == _s.selected else _s.selected
		_s.participated = true
		_s.feedback = "共用熱源已切換；其他管仍會保留餘熱"

func toggle_diversion() -> void:
	if not _s.ended and _s.selected == 1 and not _s.cold_plugged:
		_s.diversion = not _s.diversion
		_s.participated = true
		_s.feedback = "中管改道裂口：冷糖累積糖塞，熱糖會消融" if _s.diversion else "中管恢復入缸"

func toggle_helper() -> void:
	if not _s.ended:
		_s.helper = -1 if _s.helper == _s.selected else _s.selected

func drain_selected() -> void:
	if _s.ended:
		return
	var branch: Dictionary = _s.branches[_s.selected]
	if branch.fill > 0:
		_s.participated = true
	branch.fill = 0.0
	branch.spoiled = false
	_s.feedback = "已免費排空；剩餘時間不回復"
	_refresh_score()

func toggle_configuration() -> void:
	if not _s.ended:
		_s.configuration_paused = not _s.configuration_paused

func clear_input() -> void:
	pass

func step(delta: float) -> void:
	if _s.ended or _s.configuration_paused or not is_finite(delta) or delta <= 0:
		return
	var bounded := minf(delta, 0.25)
	var count := ceili(bounded / SUBSTEP)
	for i in count:
		if _s.ended:
			break
		_substep(minf(bounded / count, float(_s.remaining)))

func _substep(h: float) -> void:
	_s.elapsed = minf(ROUND_SECONDS, float(_s.elapsed) + h)
	if ROUND_SECONDS - float(_s.elapsed) < 0.000000001:
		_s.elapsed = ROUND_SECONDS
	_s.remaining = maxf(0.0, ROUND_SECONDS - float(_s.elapsed))
	for i in 3:
		var branch: Dictionary = _s.branches[i]
		var temperature: float = branch.temperature
		var heating := 0.4 * (1.0 - temperature) / float(branch.heat_capacity) if _s.heater == i else 0.0
		branch.temperature = clampf(temperature + (heating - 0.04 * temperature) * h, 0.0, 1.0)
		branch.viscosity = _viscosity(branch.temperature)
		branch.flow = (1.6 + 8.4 * branch.temperature * branch.temperature) / branch.length * (0.75 if _s.assisted else 1.0) if branch.valve and not branch.spoiled else 0.0
		var volume: float = branch.flow * h
		if i == 1 and _s.diversion:
			branch.leaked += volume
			if branch.temperature <= 0.30:
				_s.plug_amount = minf(PLUG_REQUIRED, float(_s.plug_amount) + volume)
			else:
				_s.plug_amount = maxf(0.0, float(_s.plug_amount) - 0.6 * volume)
			if _s.plug_amount >= PLUG_REQUIRED:
				_s.cold_plugged = true
				_s.diversion = false
				_s.feedback = "實體冷糖塞完成；中管恢復入缸，不再旁漏"
		else:
			var leaked := volume * 0.35 if i == 1 and not _s.cold_plugged else 0.0
			branch.leaked += leaked
			branch.fill += volume - leaked
			if branch.fill > branch.capacity and not branch.spoiled:
				branch.spoiled = true
				branch.valve = false
				branch.flow = 0.0
				_s.mistakes += 1
				_s.feedback = "糖漿溢出！排空該缸可免費重來，時間不回復"
	if _s.helper >= 0:
		var branch: Dictionary = _s.branches[_s.helper]
		if not (_s.helper == 1 and _s.diversion) and branch.valve and branch.fill >= branch.capacity * 0.92:
			branch.valve = false
			branch.flow = 0.0
	_check_result()

func _viscosity(temperature: float) -> float:
	return 1.0 / (1.6 + 8.4 * temperature * temperature)

func _refresh_score() -> void:
	_s.filled_tanks = 0
	for branch in _s.branches:
		if not branch.spoiled and branch.fill >= branch.target and branch.fill <= branch.capacity:
			_s.filled_tanks += 1
	_s.score = maxi(0, 100 * int(_s.filled_tanks) + (100 if _s.success else 0) + (100 if _s.devil else 0) - 20 * int(_s.mistakes))

func _check_result() -> void:
	_refresh_score()
	var closed := true
	for branch in _s.branches:
		closed = closed and not branch.valve
	if _s.filled_tanks == 3 and closed:
		_s.success = true
		_s.devil = _s.cold_plugged
		_s.feedback = "三缸達刻線並關閥完成！"
		_s.ended = true
	elif _s.remaining <= 0:
		_s.ended = true
		_s.feedback = "時間到；需三缸達刻線並關閥"
	if _s.ended:
		_s.ordinary_eligible = _s.participated
	_refresh_score()

func snapshot() -> Dictionary:
	return _s.duplicate(true)
