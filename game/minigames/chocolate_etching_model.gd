extends RefCounted
class_name ChocolateEtchingModel

const Geometry := preload("res://game/minigames/chocolate_etching_geometry.gd")
const ROUND_SECONDS := 240.0
const SUBSTEP := 1.0 / 120.0
const UNDO_LIMIT := 8
const STROKE_LIMIT := 8
const TEETH := [[12, 18, 12, 8], [14, 12, 16, 10]]

var _s: Dictionary
var _strokes: Array = []
var _history: Array = []
var _motion := Vector2.ZERO
var _current := PackedVector2Array()
var _invalid_stroke := false
var _guides: Array = []
var _drive_attempt := false

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	variant = posmod(variant, 2)
	_motion = Vector2.ZERO
	_current = PackedVector2Array()
	_invalid_stroke = false
	_drive_attempt = false
	_history = []
	_strokes = [[], [], [], []]
	var centers := [Vector2(160,190), Vector2(330,190), Vector2(500,190), Vector2(330,318 if variant == 0 else 302)]
	_s = {"elapsed": 0.0, "remaining": ROUND_SECONDS, "score": 0, "mistakes": 0,
		"ended": false, "success": false, "devil": false, "ordinary_eligible": false,
		"participated": false, "assisted": assisted, "variant": variant, "phase": "craft",
		"selected": 0, "depth": 0.5, "cursor": centers[0], "cutting": false, "driving": false,
		"helper": false, "helper_clamp": null, "feedback": "描線切透後折料；淺切可重描保料",
		"output_travel": 0.0, "output_omega": 0.0, "connections": [], "source_board": Geometry.BOARD,
		"source_centers": centers, "pins": [Vector2(200,220), Vector2(440 if variant == 0 else 416,220)], "parts": []}
	for i in 4:
		_s.parts.append({"teeth": TEETH[variant][i], "source_center": centers[i], "freed": false,
			"outline": PackedVector2Array(), "removed_outline": PackedVector2Array(), "pitch_radius": 0.0,
			"module": 0.0, "strength": 0.0, "position": centers[i], "mounted": false, "angle": 0.0})
	_refresh_guides()

func set_motion(direction: Vector2) -> void:
	if Geometry.finite_point(direction):
		# Scaling first avoids overflowing length_squared on finite hostile input.
		var scale := maxf(absf(direction.x), absf(direction.y))
		_motion = (direction / scale).normalized() if scale > 1.0 else direction.limit_length()

func move_cursor_to(point: Vector2) -> void:
	if _s.ended:
		return
	if not Geometry.finite_point(point):
		if _s.cutting:
			_invalid_stroke = true
		return
	var valid := point.x >= 0 and point.x <= 720 and point.y >= 0 and point.y <= 440
	point = point.clamp(Vector2.ZERO, Vector2(720,440))
	if _s.phase == "craft" and _s.assisted:
		var closest := point
		var distance := 10.0
		for guide in _guides:
			for i in guide.size():
				var candidate := Geometry2D.get_closest_point_to_segment(point, guide[i], guide[(i + 1) % guide.size()])
				if point.distance_to(candidate) < distance:
					distance = point.distance_to(candidate)
					closest = candidate
		point = closest
	_s.cursor = point
	if _s.cutting:
		if not valid or not _material_at(point):
			_invalid_stroke = true
		if _current.is_empty() or _current[-1].distance_to(point) > 0.0001:
			if _current.size() >= 2:
				var previous := _current[-1] - _current[-2]
				var next := point - _current[-1]
				# Merge only straight short samples; turns and the live endpoint survive.
				if previous.length() < 3.0 and previous.dot(next) > 0 and absf(previous.cross(next)) <= 0.00001:
					_current.remove_at(_current.size() - 1)
			if _current.size() >= Geometry.MAX_POINTS:
				_invalid_stroke = true
				_s.feedback = "每筆最多512點；請取消或先撤銷"
			else:
				_current.append(point)

func cycle_piece() -> void:
	if _s.ended:
		return
	cancel_tool()
	_s.selected = (_s.selected + 1) % 4
	_refresh_guides()

func adjust_depth(direction: int) -> void:
	if _s.ended:
		return
	cancel_tool()
	_s.depth = clampf(_s.depth + 0.25 * signi(direction), 0.25, 1.0)
	_refresh_guides()

func begin_tool() -> void:
	if _s.ended:
		return
	if _s.phase == "assembly":
		if not _s.driving:
			_s.driving = true
			_drive_attempt = false
	elif not _s.cutting and not _s.parts[_s.selected].freed and _material_at(_s.cursor):
		if _strokes[_s.selected].size() >= STROKE_LIMIT:
			_s.feedback = "每片最多8筆；請先撤銷"
			return
		_current = PackedVector2Array([_s.cursor])
		_invalid_stroke = false
		_s.cutting = true

func release_tool() -> void:
	if _s.phase == "assembly":
		_s.driving = false
		_s.output_omega = 0.0
		_drive_attempt = false
		return
	if not _s.cutting:
		return
	_s.cutting = false
	if not _invalid_stroke and _current.size() >= 2:
		var length := 0.0
		for i in range(_current.size() - 1):
			length += _current[i].distance_to(_current[i + 1])
		if length >= 8.0:
			if _current.size() >= 3 and _current[0].distance_to(_current[-1]) <= (7.0 if _s.assisted else 4.0):
				if _current[-1].distance_to(_current[0]) < 0.0001:
					_current[-1] = _current[0]
				elif _current.size() < Geometry.MAX_POINTS:
					_current.append(_current[0])
				else:
					_s.feedback = "封口需額外一點；請先撤銷"
					_current = PackedVector2Array()
					return
			_remember()
			_strokes[_s.selected].append({"points": _current.duplicate(), "depth": _s.depth, "width": 2.0 + 6.0 * _s.depth * _s.depth})
			_s.participated = true
			_structure_changed()
			_s.feedback = "熱線已提交；切透整圈才可折料"
	_current = PackedVector2Array()
	_refresh_clamp()

func cancel_tool() -> void:
	_current = PackedVector2Array()
	_invalid_stroke = false
	_s.cutting = false
	_s.driving = false
	_s.output_omega = 0.0
	_drive_attempt = false

func clear_input() -> void:
	cancel_tool()
	_motion = Vector2.ZERO

func fold_or_mount() -> void:
	if _s.ended:
		return
	if _s.phase == "assembly":
		place_selected(_s.cursor)
		return
	cancel_tool()
	var part: Dictionary = _s.parts[_s.selected]
	if part.freed:
		return
	var candidate := _candidate()
	if candidate.is_empty() or not Geometry.simple(candidate) or not Geometry2D.is_point_in_polygon(part.source_center, candidate):
		_fail("輪廓須簡單閉合且包住輪心")
		return
	if _s.selected == 3 and not (_s.parts[0].freed and _s.parts[1].freed and _s.parts[2].freed):
		_fail("先折出三個主輪，再從剩料折惰輪")
		return
	_refresh_clamp()
	var coverage := Geometry.coverage(candidate, _all_strokes())
	var threshold := (0.65 if _s.helper_clamp != null else 0.75) if _s.assisted else (0.75 if _s.helper_clamp != null else 0.85)
	if coverage.depth < threshold:
		_fail("仍有未切透連接；沿原線再描一次")
		return
	var outline := Geometry.offset(candidate, -coverage.half_width, part.source_center)
	var removed := Geometry.offset(candidate, coverage.half_width, part.source_center)
	if outline.is_empty() or removed.is_empty():
		_fail("切縫產生碎片、孔洞或超出原板")
		return
	for other in _s.parts:
		if Geometry.overlaps(removed, other.removed_outline):
			_fail("完整耗料範圍侵入已移除材料")
			return
	for stroke in _all_strokes():
		if Geometry.kerf_intrudes(stroke.points, stroke.width * 0.5, outline):
			_fail("舊熱線切壞成品內部")
			return
	if _s.selected == 3:
		for i in 3:
			for stroke in _strokes[i]:
				if Geometry.kerf_intrudes(stroke.points, stroke.width * 0.5, removed):
					_fail("惰輪耗料範圍碰到其他片的舊切縫")
					return
	var measurements := Geometry.measure(outline, part.source_center, part.teeth, _s.assisted)
	if measurements.is_empty():
		_fail("實際齒形、軸孔周圍厚度不合格")
		return
	_remember()
	part.merge(measurements, true)
	part.freed = true
	part.outline = outline
	part.removed_outline = removed
	_structure_changed()
	_refresh_clamp()
	_s.feedback = "已折出實際齒輪；切換試裝後自行放置"
	_score()

func place_selected(point: Vector2) -> void:
	if _s.ended or _s.phase != "assembly" or not Geometry.finite_point(point):
		return
	var part: Dictionary = _s.parts[_s.selected]
	if not part.freed:
		return
	if part.mounted and part.position.distance_to(point) <= 3.0:
		_remember()
		part.mounted = false
	else:
		for vertex in part.outline:
			var placed: Vector2 = vertex - part.source_center + point
			if placed.x < 0 or placed.x > 720 or placed.y < 0 or placed.y > 440:
				_s.feedback = "成品邊界須在畫布內"
				return
		_remember()
		part.position = point
		part.mounted = true
	_structure_changed()

func toggle_phase() -> void:
	if not _s.ended:
		clear_input()
		_s.phase = "assembly" if _s.phase == "craft" else "craft"

func toggle_helper() -> void:
	if not _s.ended:
		_s.helper = not _s.helper
		_refresh_clamp()

func undo() -> void:
	if _s.ended or _history.is_empty():
		return
	clear_input()
	var previous: Dictionary = _history.pop_back()
	_s.parts = previous.parts
	_strokes = previous.strokes
	if not _s.assisted:
		_mistake()
	_structure_changed()
	_refresh_clamp()
	_score()
	_s.feedback = "已撤銷；時間與參與歷史不倒退，傳動重新計算"

func step(delta: float) -> void:
	if _s.ended or not is_finite(delta) or delta <= 0:
		return
	var bounded := minf(delta, 0.25)
	var count := ceili(bounded / SUBSTEP)
	var network := _network()
	_s.output_omega = 0.0
	if _s.driving and not _drive_attempt:
		_drive_attempt = true
		if not network.valid:
			_fail(network.reason)
	for i in count:
		if _s.ended:
			break
		var h := minf(bounded / count, _s.remaining)
		if _motion != Vector2.ZERO:
			move_cursor_to(_s.cursor + _motion * 120.0 * h)
		if _s.driving and network.valid:
			_s.output_omega = network.omega[2]
			var needed: float = (TAU - _s.output_travel) / absf(_s.output_omega)
			h = minf(h, needed)
			for id in network.nodes:
				_s.parts[id].angle = wrapf(_s.parts[id].angle + network.omega[id] * h, -PI, PI)
			_s.output_travel = minf(TAU, _s.output_travel + absf(_s.output_omega) * h)
			if _s.output_travel >= TAU - 1.0e-9:
				_s.success = true
				_s.devil = 3 in network.path
				_s.ended = true
		_s.elapsed = minf(ROUND_SECONDS, _s.elapsed + h)
		if ROUND_SECONDS - _s.elapsed < 1.0e-9:
			_s.elapsed = ROUND_SECONDS
		_s.remaining = maxf(0.0, ROUND_SECONDS - _s.elapsed)
		if _s.remaining <= 0:
			_s.ended = true
	if _s.ended:
		_s.ordinary_eligible = _s.participated
		clear_input()
	_score()

func snapshot() -> Dictionary:
	var result := _s.duplicate(true)
	result.selected_guides = _guides.duplicate(true)
	result.selected_strokes = _strokes[_s.selected].duplicate(true)
	result.current_stroke = _current.duplicate()
	result.undo_available = _history.size()
	result.undo_limit = UNDO_LIMIT
	return result

func _material_at(point: Vector2) -> bool:
	if not Geometry.in_board(point):
		return false
	for part in _s.parts:
		if not part.removed_outline.is_empty() and Geometry2D.is_point_in_polygon(point, part.removed_outline):
			return false
	return true

func _candidate() -> PackedVector2Array:
	var strokes: Array = _strokes[_s.selected]
	for i in range(strokes.size() - 1, -1, -1):
		var points: PackedVector2Array = strokes[i].points
		if points.size() >= 4 and points[0] == points[-1]:
			var poly := points.slice(0, points.size() - 1)
			if Geometry.simple(poly):
				return poly
	return PackedVector2Array()

func _all_strokes() -> Array:
	var result: Array = []
	for strokes in _strokes:
		result.append_array(strokes)
	return result

func _refresh_guides() -> void:
	var part: Dictionary = _s.parts[_s.selected]
	var ideal := Geometry.template(part.source_center, part.teeth)
	var half_width: float = 1.0 + 3.0 * _s.depth * _s.depth
	_guides = [Geometry.offset(ideal, half_width, part.source_center), Geometry.offset(ideal, half_width + 2.0, part.source_center)]
	_refresh_clamp()

func _refresh_clamp() -> void:
	_s.helper_clamp = null
	if not _s.helper:
		return
	var candidate := _candidate()
	if candidate.is_empty():
		candidate = _guides[0]
	var farthest := -1.0
	for corner in [Vector2(61,71), Vector2(649,71), Vector2(61,399), Vector2(649,399)]:
		if not _material_at(corner) or (not candidate.is_empty() and Geometry2D.is_point_in_polygon(corner, candidate)):
			continue
		var cut := false
		for stroke in _all_strokes():
			cut = cut or Geometry.point_distance(corner, stroke.points) <= stroke.width * 0.5
		if not cut and corner.distance_squared_to(Vector2(80,90)) > farthest:
			farthest = corner.distance_squared_to(Vector2(80,90))
			_s.helper_clamp = corner

func _remember() -> void:
	if _history.size() == UNDO_LIMIT:
		_history.pop_front()
	_history.append({"parts": _s.parts.duplicate(true), "strokes": _strokes.duplicate(true)})

func _structure_changed() -> void:
	_s.output_travel = 0.0
	_s.output_omega = 0.0
	_s.driving = false
	_drive_attempt = false
	for part in _s.parts:
		part.angle = 0.0
	var graph := _network()
	if graph.valid:
		for id in graph.nodes:
			if id == 0:
				continue
			var parent: int = graph.parents[id]
			var a: Dictionary = _s.parts[parent]
			var b: Dictionary = _s.parts[id]
			var theta: float = (b.position - a.position).angle()
			var phase_a: float = PI / 2.0 - PI / a.teeth
			var phase_b: float = PI / 2.0 - PI / b.teeth
			b.angle = wrapf(theta + PI + (PI - a.teeth * (a.angle + phase_a - theta)) / b.teeth - phase_b, -PI, PI)

func _network() -> Dictionary:
	var adjacency := [[], [], [], []]
	_s.connections = []
	var interference := false
	for i in 4:
		if not _s.parts[i].mounted:
			continue
		for j in range(i + 1, 4):
			var a: Dictionary = _s.parts[i]
			var b: Dictionary = _s.parts[j]
			if not b.mounted:
				continue
			var gap: float = a.position.distance_to(b.position) - a.pitch_radius - b.pitch_radius
			var tolerance := 6.0 if _s.assisted else 3.0
			interference = interference or gap < -tolerance
			if absf(gap) <= tolerance and absf(a.module - b.module) / maxf(a.module, b.module) <= (0.10 if _s.assisted else 0.06):
				adjacency[i].append(j)
				adjacency[j].append(i)
				_s.connections.append(Vector2i(i,j))
	var result := {"valid": false, "reason": "齒距、中心距或輸出路徑未接通", "nodes": [], "path": [], "parents": [-1,-1,-1,-1], "omega": [0.0,0.0,0.0,0.0]}
	var shaft_tolerance := 6.0 if _s.assisted else 3.0
	if interference or not _s.parts[0].mounted or not _s.parts[2].mounted or _s.parts[0].position.distance_to(_s.pins[0]) > shaft_tolerance or _s.parts[2].position.distance_to(_s.pins[1]) > shaft_tolerance:
		return result
	result.nodes.append(0)
	result.omega[0] = 2.0
	var index := 0
	while index < result.nodes.size():
		var id: int = result.nodes[index]
		index += 1
		for next in adjacency[id]:
			if next == result.parents[id]:
				continue
			if next in result.nodes:
				result.reason = "閉環卡齒；請取下一輪重新配置"
				return result
			result.parents[next] = id
			result.omega[next] = -result.omega[id] * _s.parts[id].teeth / _s.parts[next].teeth
			result.nodes.append(next)
	if not 2 in result.nodes:
		return result
	var current := 2
	while current >= 0:
		result.path.push_front(current)
		current = result.parents[current]
	result.valid = 1 in result.path
	return result

func _mistake() -> void:
	_s.mistakes = mini(1000000000, _s.mistakes + 1)

func _fail(message: String) -> void:
	_mistake()
	_s.feedback = message
	_score()

func _score() -> void:
	var freed := 0
	for i in 3:
		freed += int(_s.parts[i].freed)
	_s.score = maxi(0, freed * 100 + (100 if _s.success else 0) + (100 if _s.devil else 0) - _s.mistakes * 20)
