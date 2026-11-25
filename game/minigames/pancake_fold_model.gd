extends RefCounted

const TILT := 0
const LADLE := 1
const PAN_SIZE := 25
const PAN_RADIUS := 11.85
const CENTER := 12
const CURSOR_SPEED := 12.0
const TICK := 1.0 / 30.0
const STOCK_MASS := 154.0
const POUR_MASS := 22.0
const DISH_POINTS := 450
const EAR_POINTS := 100
const ROUND_SECONDS := 105.0
const ASSISTED_SECONDS := 145.0
const MIN_THICKNESS := 0.25
const SET_LEVEL := 0.80
const CHAR_LEVEL := 2.70

const _CELLS := PAN_SIZE * PAN_SIZE
const _RIM_START := 9.5
const _MAX_CURSOR := PAN_RADIUS - 0.15
const _TILT_RATE := 3.6
const _POUR_RADIUS := 3.12
const _LAY_RADIUS := 1.58
const _SCOOP_RADIUS := 2.45
const _CUP_LIMIT := 10.0
const _MIN_SCOOP := 0.85
const _FACE_YIELD := 0.037
const _FACE_RATE := 0.044
const _GRAVITY_SLOPE := 0.33
const _FLOW_LIMIT := 0.23
const _HEAT_RATE := 0.080
const _FIRST_SKIN := 0.16
const _FIRM_SKIN := 0.92
const _ASSIST_COOK_CAP := 1.55
const _SCOOP_COOK_LIMIT := 0.95
const _EAR_TRACE := 0.20
const _EAR_SET := 0.69
const _SHEET_MIN_THICKNESS := 0.12
const _SHEET_MIN_SET := 0.60
const _FOLD_TICKS := 24
const _MIRROR_TICK := 12
const _EPS := 0.000001
const _NEIGHBORS := [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const _EDGE_NEIGHBORS := [-1, 1, -PAN_SIZE, PAN_SIZE]

var _mass := PackedFloat32Array()
var _thermal := PackedFloat32Array()
var _rim := PackedFloat32Array()
var _recovered := PackedFloat32Array()
var _delta_mass := PackedFloat32Array()
var _delta_thermal := PackedFloat32Array()
var _delta_rim := PackedFloat32Array()
var _delta_recovered := PackedFloat32Array()
var _cook := PackedFloat32Array()
var _heat := PackedFloat32Array()
var _mobility := PackedFloat32Array()
var _points := PackedVector2Array()
var _active := PackedInt32Array()
var _rim_cells := PackedInt32Array()
var _east_edges := PackedInt32Array()
var _south_edges := PackedInt32Array()
var _required := PackedInt32Array()
var _filling := PackedInt32Array()
var _ear := PackedInt32Array()
var _rim_mask := PackedByteArray()
var _required_mask := PackedByteArray()
var _filling_mask := PackedByteArray()
var _ear_mask := PackedByteArray()
var _thin_mask := PackedByteArray()
var _connected_sheet := PackedByteArray()
var _fold_source_mask := PackedByteArray()
var _fold_queue := PackedInt32Array()
var _static_paint: Dictionary = {}
var _paint: Dictionary = {}
var _paint_revision := -1
var _revision := 0

var _layout := 0
var _assisted := false
var _tool := TILT
var _axis := Vector2.ZERO
var _tilt := Vector2.ZERO
var _cursor := Vector2.ZERO
var _fold_axis := Vector2.RIGHT
var _ear_target := Vector2(-5.7, 0.0)
var _stock := STOCK_MASS
var _cup := 0.0
var _cup_thermal := 0.0
var _poured := 0
var _flowed_to_rim := 0.0
var _reclaimed_mass := 0.0
var _rim_available := 0.0
var _coverage := 0.0
var _seam := 0.0
var _filled := 0.0
var _cooked := 0.0
var _burned := 0.0
var _ear_coverage := 0
var _ear_overlap := 0
var _ear_attached := 0
var _ear_proven := false
var _fill_is_set := false
var _folding := false
var _fold_ticks := 0
var _folded := false
var _ended := false
var _ticks := 0
var _accumulator := 0.0
var _feedback := ""
var _mistakes := 0
var _notes: Array[int] = []


func _init() -> void:
	_build_pan()
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, 2)
	_fold_axis = Vector2.RIGHT if _layout == 0 else Vector2.DOWN
	_ear_target = Vector2(-5.7, 0.0) if _layout == 0 else Vector2(1.0, -5.7)
	_build_layout()
	_mass.fill(0.0)
	_thermal.fill(0.0)
	_rim.fill(0.0)
	_recovered.fill(0.0)
	_cook.fill(0.0)
	_connected_sheet.fill(0)
	_fold_source_mask.fill(0)
	_tool = TILT
	_cursor = Vector2.ZERO
	clear_input()
	_stock = STOCK_MASS
	_cup = 0.0
	_cup_thermal = 0.0
	_poured = 0
	_flowed_to_rim = 0.0
	_reclaimed_mass = 0.0
	_folding = false
	_fold_ticks = 0
	_folded = false
	_ended = false
	_ticks = 0
	_accumulator = 0.0
	_mistakes = 0
	_notes.clear()
	_feedback = "倒一勺麵糊，傾鍋讓它流過配料兩側。"
	_measure_pan()


func set_axis(axis: Vector2) -> void:
	if not _interactive() or not axis.is_finite():
		return
	var peak := maxf(absf(axis.x), absf(axis.y))
	_axis = (axis / peak).normalized() if peak > 1.0 else axis.limit_length()


func toggle_tool() -> bool:
	if not _interactive():
		return false
	_tool = LADLE if _tool == TILT else TILT
	_axis = Vector2.ZERO
	_feedback = "移動勺口，在想補的地方倒糊。" if _tool == LADLE else "按住方向傾鍋，放手回平。"
	return true


func clear_input() -> void:
	_axis = Vector2.ZERO
	_tilt = Vector2.ZERO


func pour() -> bool:
	if not _interactive() or _stock < POUR_MASS:
		return false
	_spread(POUR_MASS, 0.0, _POUR_RADIUS, false)
	_stock -= POUR_MASS
	_poured += 1
	_feedback = "已倒一勺。薄處可再補，稀糊會隨鍋流動。"
	_measure_pan()
	_note(3)
	return true


func salvage_or_lay() -> bool:
	if not _interactive():
		return false
	if _cup > _EPS:
		_spread(_cup, _cup_thermal, _LAY_RADIUS, true)
		_reclaimed_mass += _cup
		_cup = 0.0
		_cup_thermal = 0.0
		_feedback = "已補上回收麵糊。摺耳要接在餅身和合折處。"
		_measure_pan()
		_note(8)
		return true
	if _scoop_amount() < _MIN_SCOOP:
		_feedback = "把曾經流到鍋邊的軟糊舀起。直接倒在邊上的糊不算。"
		return false
	for index in _rim_cells:
		if not _scoopable(index):
			continue
		var take := minf(_mass[index], minf(_rim[index], _CUP_LIMIT - _cup))
		var warmth := take * _cook[index]
		_mass[index] -= take
		_thermal[index] = maxf(0.0, _thermal[index] - warmth)
		_rim[index] -= take
		_cup += take
		_cup_thermal += warmth
		if _cup >= _CUP_LIMIT - _EPS:
			break
	_feedback = "已舀起鍋邊餘糊。移到薄處或摺耳，再按一次補上。"
	_measure_pan()
	_note(5)
	return true


func fold() -> bool:
	if not _interactive():
		return false
	var reason := _fold_reason()
	if not reason.is_empty():
		_mistakes += 1
		match reason:
			"empty": _feedback = "先在配料兩側倒糊。"
			"thin": _feedback = "配料或摺線下還有薄孔，先補一點糊。"
			"wet": _feedback = "餅面還沒有凝固。平放鍋子，等濕光退去。"
			"burned": _feedback = "配料周圍焦化太多，這張餅折不起來。"
		_note(-3)
		return false
	_folding = true
	_fold_ticks = 0
	_build_fold_sheet()
	_measure_ear(true)
	_revision += 1
	clear_input()
	_feedback = "沿摺線把餅翻過去，包住配料。"
	_note(10)
	return true


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK and not _ended:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_ticks += 1
		if _folding:
			_step_fold()
			continue
		_step_tools()
		if _poured > 0:
			_flow_and_heat()
		if float(_ticks) * TICK >= _limit():
			_finish("時間到，這張餅還沒有完成。")


func _interactive() -> bool:
	return not _ended and not _folding


func _step_tools() -> void:
	var target := _axis if _tool == TILT else Vector2.ZERO
	_tilt = _tilt.move_toward(target, _TILT_RATE * TICK)
	if _tool == LADLE and _axis != Vector2.ZERO:
		_cursor = (_cursor + _axis * CURSOR_SPEED * TICK).limit_length(_MAX_CURSOR)


func _build_pan() -> void:
	for field in [_mass, _thermal, _rim, _recovered, _delta_mass, _delta_thermal, _delta_rim, _delta_recovered]:
		field.resize(_CELLS)
	_cook.resize(_CELLS)
	_heat.resize(_CELLS)
	_mobility.resize(_CELLS)
	_points.resize(_CELLS)
	_rim_mask.resize(_CELLS)
	_connected_sheet.resize(_CELLS)
	_fold_source_mask.resize(_CELLS)
	var pan_radius_squared := PAN_RADIUS * PAN_RADIUS
	for y in PAN_SIZE:
		for x in PAN_SIZE:
			var index := y * PAN_SIZE + x
			var point := Vector2(x - CENTER, y - CENTER)
			_points[index] = point
			if point.length_squared() > pan_radius_squared:
				continue
			_active.append(index)
			if point.length_squared() >= _RIM_START * _RIM_START:
				_rim_cells.append(index)
				_rim_mask[index] = 1
			if (point + Vector2.RIGHT).length_squared() <= pan_radius_squared:
				_east_edges.append(index)
				_east_edges.append(index + 1)
			if (point + Vector2.DOWN).length_squared() <= pan_radius_squared:
				_south_edges.append(index)
				_south_edges.append(index + PAN_SIZE)


func _build_layout() -> void:
	_required.clear()
	_filling.clear()
	_ear.clear()
	for mask in [_filling_mask, _required_mask, _ear_mask, _thin_mask]:
		mask.resize(_CELLS)
		mask.fill(0)
	var hot := Vector2(-4, 2) if _layout == 0 else Vector2(3, -3)
	var second := Vector2(4, -4) if _layout == 0 else Vector2(-4, 3)
	for index in _active:
		var point := _points[index]
		_heat[index] = 0.74 + 0.47 * exp(-point.distance_squared_to(hot) / 17.0) \
			+ 0.28 * exp(-point.distance_squared_to(second) / 22.0) \
			- 0.31 * smoothstep(8.4, 11.45, point.length())
		var main := int(point.x) if _layout == 0 else int(point.y)
		var cross := int(point.y) if _layout == 0 else int(point.x)
		if _ingredient(main, cross):
			_filling.append(index)
			_filling_mask[index] = 1
		for offset in _NEIGHBORS:
			if _ingredient(absi(main + offset.x), cross + offset.y):
				_required.append(index)
				_required_mask[index] = 1
				break
		var ear_cross := 0 if _layout == 0 else 1
		if main in [-7, -6, -5] and absi(cross - ear_cross) <= 1:
			_ear.append(index)
			_ear_mask[index] = 1
	_static_paint = {
		"heat": _heat.duplicate(), "filling_mask": _filling_mask.duplicate(),
		"required_mask": _required_mask.duplicate(), "ear_mask": _ear_mask.duplicate(),
		"rim_mask": _rim_mask.duplicate(),
	}


func _ingredient(forward: int, cross: int) -> bool:
	if forward < 1 or forward > 4:
		return false
	if _layout == 0:
		return absi(cross) <= (3 if forward == 4 else 4)
	return (forward <= 3 and cross >= -4 and cross <= 1) or (forward >= 2 and cross >= 0 and cross <= 4)


func _spread(amount: float, heat: float, radius: float, recovered: bool) -> void:
	var weight := 0.0
	for index in _active:
		weight += _deposit_weight(index, radius)
	var mass_unit := amount / weight
	var heat_unit := heat / weight
	for index in _active:
		var local := _deposit_weight(index, radius)
		if local <= 0.0:
			continue
		var added := local * mass_unit
		_mass[index] += added
		_thermal[index] += local * heat_unit
		if recovered:
			_recovered[index] += added
		_cook[index] = _thermal[index] / _mass[index]


func _deposit_weight(index: int, radius: float) -> float:
	var distance_sq := _points[index].distance_squared_to(_cursor)
	return 0.0 if distance_sq >= radius * radius else 1.0 - sqrt(distance_sq) / radius


func _scoopable(index: int) -> bool:
	return _rim[index] > _EPS and _cook[index] <= _SCOOP_COOK_LIMIT \
		and _points[index].distance_squared_to(_cursor) <= _SCOOP_RADIUS * _SCOOP_RADIUS


func _scoop_amount() -> float:
	if _rim_available < _MIN_SCOOP or _cursor.length_squared() < (_RIM_START - _SCOOP_RADIUS) ** 2:
		return 0.0
	var amount := 0.0
	for index in _rim_cells:
		if _scoopable(index):
			amount += _rim[index]
			if amount >= _CUP_LIMIT:
				return _CUP_LIMIT
	return amount


func _flow_and_heat() -> void:
	_delta_mass.fill(0.0)
	_delta_thermal.fill(0.0)
	_delta_rim.fill(0.0)
	_delta_recovered.fill(0.0)
	for index in _active:
		_mobility[index] = 1.0 - smoothstep(_FIRST_SKIN, _FIRM_SKIN, _cook[index]) if _mass[index] > _EPS else 0.0
	for index in range(0, _east_edges.size(), 2):
		_flow_face(_east_edges[index], _east_edges[index + 1], _tilt.x * _GRAVITY_SLOPE)
	for index in range(0, _south_edges.size(), 2):
		_flow_face(_south_edges[index], _south_edges[index + 1], _tilt.y * _GRAVITY_SLOPE)
	for index in _active:
		var mass := maxf(0.0, _mass[index] + _delta_mass[index])
		var energy := maxf(0.0, _thermal[index] + _delta_thermal[index])
		_mass[index] = mass
		_rim[index] = maxf(0.0, _rim[index] + _delta_rim[index])
		_recovered[index] = maxf(0.0, _recovered[index] + _delta_recovered[index])
		if mass <= _EPS:
			_thermal[index] = energy
			_cook[index] = 0.0
			continue
		var heating := _HEAT_RATE * TICK * _heat[index] / (0.76 + 0.28 * sqrt(mass))
		var cap := _ASSIST_COOK_CAP if _assisted else CHAR_LEVEL + 0.80
		_thermal[index] = minf(energy + mass * heating, mass * cap)
		_cook[index] = _thermal[index] / mass
	_measure_pan()


## Exchange a face once. A source can lose no more than 4 * _FLOW_LIMIT of its
## current mass even if all four of its neighbors draw from it this tick.
func _flow_face(a: int, b: int, slope: float) -> void:
	var pressure := _mass[a] - _mass[b] + slope
	if absf(pressure) <= _FACE_YIELD:
		return
	var source := a if pressure > 0.0 else b
	var target := b if pressure > 0.0 else a
	if _mobility[source] <= 0.0:
		return
	var source_mass := _mass[source]
	var weight := minf(source_mass * _FLOW_LIMIT, (absf(pressure) - _FACE_YIELD) * _FACE_RATE * _mobility[source])
	if weight <= _EPS:
		return
	var share := weight / source_mass
	var warmth := _thermal[source] * share
	var provenance := _rim[source] * share
	var traced := _recovered[source] * share
	_delta_mass[source] -= weight
	_delta_thermal[source] -= warmth
	_delta_rim[source] -= provenance
	_delta_recovered[source] -= traced
	_delta_mass[target] += weight
	_delta_thermal[target] += warmth
	_delta_recovered[target] += traced
	# Only a real outward edge exchange driven by the player's slope tags fresh mass.
	# Recovered mass remains in its own channel and cannot earn a second tag.
	if _rim_mask[source] == 0 and _rim_mask[target] != 0 and signf(pressure) * slope > 0.35 * _GRAVITY_SLOPE:
		var new_trace := maxf(0.0, weight - provenance - traced)
		_flowed_to_rim += new_trace
		provenance += new_trace
	_delta_rim[target] += provenance


func _measure_pan() -> void:
	var sound := 0
	var set := 0
	var charred := 0
	var crease := 0
	var crease_sound := 0
	var crease_set := true
	for index in _required:
		var thick := _mass[index] >= MIN_THICKNESS
		_thin_mask[index] = int(not thick)
		sound += int(thick)
		set += int(thick and _cook[index] >= SET_LEVEL)
		charred += int(thick and _cook[index] >= CHAR_LEVEL)
		if _forward(index) == 0:
			crease += 1
			crease_sound += int(thick)
			crease_set = crease_set and _cook[index] >= 0.68
	_coverage = float(sound) / float(_required.size())
	_cooked = float(set) / float(_required.size())
	_burned = float(charred) / float(_required.size())
	_seam = float(crease_sound) / float(crease)
	var filled := 0
	_fill_is_set = crease_set
	for index in _filling:
		var back := _mirror(index)
		filled += int(_mass[index] >= MIN_THICKNESS and _mass[back] >= MIN_THICKNESS)
		_fill_is_set = _fill_is_set and minf(_cook[index], _cook[back]) >= 0.72
	_filled = float(filled) / float(_filling.size())
	_rim_available = 0.0
	for index in _rim_cells:
		if _cook[index] <= _SCOOP_COOK_LIMIT:
			_rim_available += _rim[index]
	_measure_ear()
	_revision += 1


func _measure_ear(require_connected: bool = false) -> void:
	_ear_coverage = 0
	_ear_overlap = 0
	_ear_attached = 0
	var joint := 1 if _layout == 0 else PAN_SIZE
	for index in _ear:
		if require_connected and _connected_sheet[index] == 0:
			continue
		if _recovered[index] < _EAR_TRACE or _mass[index] < MIN_THICKNESS or _cook[index] < _EAR_SET:
			continue
		_ear_coverage += 1
		var back := _mirror(index)
		if _mass[back] >= MIN_THICKNESS and _cook[back] >= 0.76 and (not require_connected or _connected_sheet[back] != 0):
			_ear_overlap += 1
		if _required_mask[index + joint] != 0 and _mass[index + joint] >= MIN_THICKNESS and _cook[index + joint] >= 0.76:
			_ear_attached += 1
	_ear_proven = _ear_coverage >= 3 and _ear_overlap >= 2 and _ear_attached >= 1


func _forward(index: int) -> int:
	return int(_points[index].x) if _layout == 0 else int(_points[index].y)


func _mirror(index: int) -> int:
	var stride := 1 if _layout == 0 else PAN_SIZE
	return index - 2 * _forward(index) * stride


func _fold_reason() -> String:
	if not _interactive():
		return "folding" if _folding and not _ended else "ended"
	if _poured == 0:
		return "empty"
	var needed := 0.88 if _assisted else 0.94
	if _coverage < needed or _seam < 1.0 or _filled < 1.0:
		return "thin"
	if _burned > 0.12:
		return "burned"
	var cooked_needed := 0.82 if _assisted else 0.88
	if _cooked < cooked_needed or not _fill_is_set:
		return "wet"
	return ""


func _step_fold() -> void:
	_fold_ticks += 1
	if _fold_ticks == _MIRROR_TICK:
		_apply_fold()
	if _fold_ticks >= _FOLD_TICKS:
		_finish("摺耳把餅口包住了。" if _ear_proven else "煎餅已合折，配料完整包住了。")


func _build_fold_sheet() -> void:
	_connected_sheet.fill(0)
	_fold_source_mask.fill(0)
	_fold_queue.clear()
	for index in _required:
		if _forward(index) == 0 and _mass[index] >= MIN_THICKNESS and _cook[index] >= _SHEET_MIN_SET:
			_connected_sheet[index] = 1
			_fold_queue.append(index)
	var head := 0
	while head < _fold_queue.size():
		var index := _fold_queue[head]
		head += 1
		if _forward(index) < 0:
			_fold_source_mask[index] = 1
		for offset in _EDGE_NEIGHBORS:
			var other := index + int(offset)
			if _connected_sheet[other] != 0 or _mass[other] < _SHEET_MIN_THICKNESS or _cook[other] < _SHEET_MIN_SET:
				continue
			_connected_sheet[other] = 1
			_fold_queue.append(other)


## Transfer the moving half into matching landing cells. The hinge itself stays
## in place and disconnected or wet runoff remains on the pan.
func _apply_fold() -> void:
	for source in _active:
		if _fold_source_mask[source] == 0:
			continue
		var target := _mirror(source)
		_mass[target] += _mass[source]
		_thermal[target] += _thermal[source]
		_rim[target] += _rim[source]
		_recovered[target] += _recovered[source]
		_cook[target] = _thermal[target] / _mass[target] if _mass[target] > _EPS else 0.0
		_mass[source] = 0.0
		_thermal[source] = 0.0
		_rim[source] = 0.0
		_recovered[source] = 0.0
		_cook[source] = 0.0
	_thin_mask.fill(0)
	_folded = true
	_revision += 1


func _finish(message: String) -> void:
	_ended = true
	_folding = false
	_accumulator = 0.0
	clear_input()
	_feedback = message


func _limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _note(pitch: int) -> void:
	if _notes.size() < 8:
		_notes.append(pitch)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func _paint_state() -> Dictionary:
	if _paint_revision != _revision:
		_paint = {
			"mass": _mass.duplicate(), "cook": _cook.duplicate(),
			"rim": _rim.duplicate(), "recovered": _recovered.duplicate(),
			"thin_mask": _thin_mask.duplicate(), "fold_source_mask": _fold_source_mask.duplicate(),
		}
		_paint_revision = _revision
	return _paint


func snapshot() -> Dictionary:
	var reason := _fold_reason()
	var elapsed := minf(float(_ticks) * TICK, _limit())
	var success := _ended and _folded
	var devil := success and _ear_proven
	var paint := _paint_state()
	return {
		"layout": _layout, "assisted": _assisted, "tool": _tool, "tilt": _tilt, "cursor": _cursor,
		"stock": _stock, "cup": _cup, "poured": _poured, "reclaimed_mass": _reclaimed_mass,
		"flowed_to_rim": _flowed_to_rim, "rim_available": _rim_available,
		"coverage": _coverage, "seam": _seam, "filled": _filled, "cooked": _cooked, "burned": _burned,
		"ear_coverage": _ear_coverage, "ear_overlap": _ear_overlap, "ear_attached": _ear_attached, "ear_proven": _ear_proven,
		"can_pour": _interactive() and _stock >= POUR_MASS,
		"can_salvage": _interactive() and (_cup > _EPS or _scoop_amount() >= _MIN_SCOOP),
		"can_fold": reason.is_empty(), "fold_reason": reason, "fold_axis": _fold_axis,
		"ear_target": _ear_target, "fold_progress": float(_fold_ticks) / float(_FOLD_TICKS), "folded": _folded,
		"engaged": _poured > 0, "score": int(success) * DISH_POINTS + int(devil) * EAR_POINTS, "mistakes": _mistakes,
		"elapsed": elapsed, "remaining": _limit() - elapsed, "ended": _ended, "success": success,
		"devil": devil, "ordinary_eligible": _ended and _poured > 0, "feedback": _feedback, "revision": _revision,
		"mass": paint.mass, "cook": paint.cook, "heat": _static_paint.heat, "rim": paint.rim, "recovered": paint.recovered,
		"filling_mask": _static_paint.filling_mask, "required_mask": _static_paint.required_mask,
		"ear_mask": _static_paint.ear_mask, "rim_mask": _static_paint.rim_mask,
		"thin_mask": paint.thin_mask, "fold_source_mask": paint.fold_source_mask,
	}
