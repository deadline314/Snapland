extends RefCounted

const WIDE := -1
const TEA := 0
const CHAR := 1
const SWEET := 2
const STALL_COUNT := 3
const STALL_POINTS := 150
const MIX_POINTS := 100
const TICK := 1.0 / 60.0
const WALK_SPEED := 3.0
const HALF_WIDTH := 0.44
const BOUNDS := Rect2(-4.15, -2.65, 8.3, 5.95)
const ROUND_SECONDS := 114.0
const ASSISTED_SECONDS := 142.0
const AROMAS := ["茶香", "炭香", "糖香"]

const FIRST_LAYOUT := 1
const SECOND_LAYOUT := 2
const BOTH_LAYOUTS := FIRST_LAYOUT | SECOND_LAYOUT
const SCAN_RADIUS := 0.72
const ASSIST_SCAN_RADIUS := 1.0
const SCAN_ANGLE := deg_to_rad(38.0)
const ASSIST_SCAN_ANGLE := deg_to_rad(62.0)
const STALL_RADIUS := 0.58
const MARK_RADIUS := 0.55
const MIN_STRENGTH := 0.16
const FAINT_LIMIT := 0.55
const DECAY := 0.09
const CUE_INTERVAL := 5
const HELPER_TICKS := 240
const PAIRS := [3, 5, 6]

enum Landmark {
	TEA_STOVE, CHAR_STOVE, SWEET_STOVE, WEST_TURN, EAST_TURN, CROSSROAD,
	CANOPY, ENTRY, WEST_EXIT, EAST_EXIT, EAST_COUNTER, REAR_COUNTER,
}

const LOCATIONS := [
	Vector2(-3.4, -1.75), Vector2(3.4, -1.75), Vector2(-3.4, 1.6),
	Vector2(-2.25, -0.55), Vector2(2.25, -0.55), Vector2(0, -0.55),
	Vector2(0, 0.95), Vector2(0, 2.65), Vector2(-2.15, 2.65), Vector2(2.15, 2.65),
	Vector2(3.4, 1.6), Vector2(-0.9, -1.68),
]
const STALLS := [
	[Landmark.TEA_STOVE, "煨茶小灶", TEA],
	[Landmark.CHAR_STOVE, "炭火烤攤", CHAR],
	[Landmark.SWEET_STOVE, "糖漿鍋", SWEET],
	[Landmark.EAST_COUNTER, "收攤蒸籠", WIDE],
	[Landmark.REAR_COUNTER, "空湯檯", WIDE],
]
const EMISSIONS := [Vector3(0.98, 0, 0), Vector3(0, 0.80, 0), Vector3(0, 0, 0.74)]
# Starts and ends, walk layouts, wind layouts, and relative flow weight.
const CORRIDORS := [
	[Landmark.TEA_STOVE, Landmark.WEST_TURN, BOTH_LAYOUTS, BOTH_LAYOUTS, 1.0],
	[Landmark.WEST_TURN, Landmark.CROSSROAD, BOTH_LAYOUTS, BOTH_LAYOUTS, 1.0],
	[Landmark.CHAR_STOVE, Landmark.EAST_TURN, FIRST_LAYOUT, FIRST_LAYOUT, 1.0],
	[Landmark.EAST_TURN, Landmark.CROSSROAD, BOTH_LAYOUTS, FIRST_LAYOUT, 1.0],
	[Landmark.CROSSROAD, Landmark.CANOPY, BOTH_LAYOUTS, BOTH_LAYOUTS, 0.8],
	[Landmark.CANOPY, Landmark.ENTRY, BOTH_LAYOUTS, BOTH_LAYOUTS, 1.0],
	[Landmark.SWEET_STOVE, Landmark.WEST_TURN, SECOND_LAYOUT, SECOND_LAYOUT, 1.0],
	[Landmark.SWEET_STOVE, Landmark.WEST_EXIT, BOTH_LAYOUTS, FIRST_LAYOUT, 1.0],
	[Landmark.WEST_EXIT, Landmark.ENTRY, BOTH_LAYOUTS, 0, 0.0],
	[Landmark.CHAR_STOVE, Landmark.EAST_COUNTER, BOTH_LAYOUTS, SECOND_LAYOUT, 1.0],
	[Landmark.EAST_COUNTER, Landmark.EAST_EXIT, BOTH_LAYOUTS, SECOND_LAYOUT, 1.0],
	[Landmark.EAST_EXIT, Landmark.ENTRY, BOTH_LAYOUTS, 0, 0.0],
	[Landmark.CROSSROAD, Landmark.REAR_COUNTER, BOTH_LAYOUTS, BOTH_LAYOUTS, 0.2],
]
const WIND_ORDER := [
	Landmark.TEA_STOVE, Landmark.CHAR_STOVE, Landmark.SWEET_STOVE, Landmark.WEST_TURN,
	Landmark.EAST_TURN, Landmark.EAST_COUNTER, Landmark.CROSSROAD, Landmark.CANOPY,
	Landmark.REAR_COUNTER, Landmark.WEST_EXIT, Landmark.EAST_EXIT, Landmark.ENTRY,
]


class Link:
	var id := -1
	var from_node := -1
	var to_node := -1
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var axis := Vector2.ZERO
	var length := 0.0
	var open := false
	var flow_weight := 0.0
	var entry_strengths := Vector3.ZERO
	var source_mask := 0
	var sampled_mask := 0
	var focused_mask := 0

	func closest(point: Vector2) -> Vector2:
		var along := clampf((point - a).dot(axis), 0.0, length)
		return a + axis * along


var _assisted := false
var _layout := 0
var _links: Array[Link] = []
var _walk_links: Array[Link] = []
var _wind_links: Array[Link] = []
var _walk_degree := PackedInt32Array()
var _visible_links: Array[Dictionary] = []
var _visible_stalls: Array[Dictionary] = []
var _nodes := PackedVector2Array(LOCATIONS)
var _player: Vector2 = LOCATIONS[Landmark.ENTRY]
var _walk_axis := Vector2.ZERO
var _velocity := Vector2.ZERO
var _facing := Vector2.UP
var _sampler_turn := 0
var _sampler_dir := Vector2.UP
var _filter := WIDE
var _cue: Dictionary = {}
var _cue_position := Vector2.INF
var _sampled_mask := 0
var _found_mask := 0
var _found := 0
var _mixed_mask := 0
var _mix_mark := -1
var _mix_proven := false
var _learned_edges := PackedInt32Array()
var _focused_edges := PackedInt32Array()
var _focused_strengths := Vector3.ZERO
var _helper_point := Vector2.ZERO
var _helper_scent := WIDE
var _helper_until := 0
var _ticks := 0
var _accumulator := 0.0
var _ended := false
var _feedback := ""
var _notes: Array[int] = []


func _init() -> void:
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, 2)
	_build_layout()
	_player = LOCATIONS[Landmark.ENTRY]
	_walk_axis = Vector2.ZERO
	_velocity = Vector2.ZERO
	_facing = Vector2.UP
	_sampler_turn = 0
	_sampler_dir = Vector2.UP
	_filter = WIDE
	_sampled_mask = 0
	_found_mask = 0
	_found = 0
	_mixed_mask = 0
	_mix_mark = -1
	_mix_proven = false
	_learned_edges = PackedInt32Array([-1, -1, -1])
	_focused_edges = PackedInt32Array([-1, -1, -1])
	_focused_strengths = Vector3.ZERO
	_helper_point = Vector2.ZERO
	_helper_scent = WIDE
	_helper_until = 0
	_ticks = 0
	_accumulator = 0.0
	_ended = false
	_notes.clear()
	_rebuild_stalls()
	_refresh_cue()
	_feedback = "風箭指向下風。把聞香筒轉向來風，再按取樣。"


func set_walk_axis(axis: Vector2) -> void:
	if not _ended and axis.is_finite():
		_walk_axis = axis.limit_length(1.0)


func turn_sampler(direction: int) -> bool:
	if _ended or direction not in [-1, 1]:
		return false
	_sampler_turn = posmod(_sampler_turn + direction, 8)
	_sampler_dir = Vector2.from_angle(-PI * 0.5 + float(_sampler_turn) * TAU / 8.0)
	_refresh_cue()
	return true


func set_filter(id: int) -> bool:
	if _ended or id < WIDE or id > SWEET or id == _filter:
		return false
	_filter = id
	_helper_until = 0
	_helper_scent = WIDE
	_refresh_cue()
	return true


func cycle_filter(direction: int = 1) -> bool:
	if direction not in [-1, 1]:
		return false
	return set_filter(posmod(_filter + 1 + direction, STALL_COUNT + 1) - 1)


func interact() -> bool:
	if _ended:
		return false
	_refresh_cue()
	var hot_stove := _confirmable_stall()
	if hot_stove >= 0:
		_confirm_stall(hot_stove)
		return true
	if _can_mark():
		_mix_proven = true
		_feedback = "已標記兩股香真正匯合的上游。"
		_note(12)
		return true
	if _cue.mask != 0:
		_commit_sample()
		return true
	if _helper_node() >= 0:
		return request_helper()
	if _near_cold_stall():
		_feedback = "這裡沒有開火。沿來風找其他攤。"
	elif _cue.edge >= 0 and not _cue.aligned:
		_feedback = "先把聞香筒轉向風來的方向。"
	elif _cue.edge >= 0:
		_feedback = "這段聞不到選中的香紋。可換一種香紋。"
	else:
		_feedback = "這裡的香流太淡，沿著巷道找風箭。"
	return false


func request_helper() -> bool:
	var point := _helper_node()
	if point < 0:
		return false
	_helper_point = _nodes[point]
	_helper_scent = _filter
	_helper_until = _ticks + HELPER_TICKS
	_feedback = "幫手標出了這股弱香的下一個上游路口。"
	_note(8)
	return true


func clear_input() -> void:
	_walk_axis = Vector2.ZERO
	_velocity = Vector2.ZERO


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_ticks += 1
		_walk()
		if _ticks % CUE_INTERVAL == 0 and not _player.is_equal_approx(_cue_position):
			_refresh_cue()
		if float(_ticks) * TICK >= _seconds_limit():
			_finish("時間到，已確認 %d / %d 個開火攤。" % [_found, STALL_COUNT])
			return


func _walk() -> void:
	var start := _player
	if _walk_axis != Vector2.ZERO:
		var motion := _walk_axis * WALK_SPEED * TICK
		if _standable(start + motion):
			_player += motion
		else:
			var side := _player + Vector2(motion.x, 0)
			if motion.x != 0.0 and _standable(side):
				_player = side
			var forward := _player + Vector2(0, motion.y)
			if motion.y != 0.0 and _standable(forward):
				_player = forward
	_velocity = (_player - start) / TICK
	if _velocity.length_squared() > 0.000001:
		_facing = _velocity.normalized()


func _standable(point: Vector2) -> bool:
	if not BOUNDS.has_point(point):
		return false
	for link in _walk_links:
		if point.distance_squared_to(link.closest(point)) <= HALF_WIDTH * HALF_WIDTH:
			return true
	return false


func _build_layout() -> void:
	_links.clear()
	_walk_links.clear()
	_wind_links.clear()
	_walk_degree = PackedInt32Array()
	_walk_degree.resize(_nodes.size())
	var layout_bit := 1 << _layout
	for index in CORRIDORS.size():
		var row: Array = CORRIDORS[index]
		var link := Link.new()
		link.id = index
		link.from_node = row[0]
		link.to_node = row[1]
		link.a = _nodes[link.from_node]
		link.b = _nodes[link.to_node]
		var span := link.b - link.a
		link.length = span.length()
		link.axis = span / link.length
		link.open = bool(int(row[2]) & layout_bit)
		_links.append(link)
		if link.open:
			_walk_links.append(link)
			_walk_degree[link.from_node] += 1
			_walk_degree[link.to_node] += 1
			if int(row[3]) & layout_bit:
				link.flow_weight = row[4]
				_wind_links.append(link)

	# Each outgoing segment receives its share of local air. Per-channel amounts
	# add at joins, so two unrelated source traces never replace each other.
	var fields := PackedVector3Array()
	fields.resize(_nodes.size())
	for stall in STALL_COUNT:
		fields[int(STALLS[stall][0])] = EMISSIONS[stall]
	for node in WIND_ORDER:
		var total := 0.0
		for link in _wind_links:
			if link.from_node == node:
				total += link.flow_weight
		if total <= 0.0:
			continue
		for link in _wind_links:
			if link.from_node == node:
				link.entry_strengths = fields[node] * (link.flow_weight / total)
				for scent in STALL_COUNT:
					if link.entry_strengths[scent] > 0.0:
						link.source_mask |= 1 << scent
				fields[link.to_node] += _along_strength(link, link.length)
	_rebuild_visible_links()


func _along_strength(link: Link, distance: float) -> Vector3:
	return link.entry_strengths * exp(-DECAY * distance)


func _threshold_mask(strengths: Vector3) -> int:
	var mask := 0
	for scent in STALL_COUNT:
		if strengths[scent] >= MIN_STRENGTH:
			mask |= 1 << scent
	return mask


func _refresh_cue() -> void:
	_cue_position = _player
	var reach := ASSIST_SCAN_RADIUS if _assisted else SCAN_RADIUS
	var alignment := cos(ASSIST_SCAN_ANGLE if _assisted else SCAN_ANGLE)
	var best := -INF
	var best_edge := -1
	var best_point := _player
	var best_wind := Vector2.ZERO
	var best_strengths := Vector3.ZERO
	var best_mask := 0
	var best_aligned := false
	for link in _wind_links:
		var center := link.closest(_player)
		var sideways := _player.distance_to(center)
		if sideways > reach:
			continue
		var strengths := _along_strength(link, link.a.distance_to(center)) * lerpf(1.0, 0.62, sideways / reach)
		var aligned := _sampler_dir.dot(-link.axis) >= alignment
		var mask := _threshold_mask(strengths) if aligned else 0
		if _filter >= 0:
			mask &= 1 << _filter
		var score := float(mask != 0) * 3.0 + float(aligned) - sideways / reach
		if score <= best:
			continue
		best = score
		best_edge = link.id
		best_point = center
		best_wind = link.axis
		best_strengths = strengths
		best_mask = mask
		best_aligned = aligned

	for scent in STALL_COUNT:
		if (best_mask & (1 << scent)) == 0:
			best_strengths[scent] = 0.0
	_cue = {
		"edge": best_edge, "position": best_point, "wind": best_wind,
		"strengths": best_strengths, "mask": best_mask, "aligned": best_aligned,
	}
	_cue.make_read_only()


func _commit_sample() -> void:
	var mask: int = _cue.mask
	var link := _links[int(_cue.edge)]
	_sampled_mask |= mask
	for scent in STALL_COUNT:
		if mask & (1 << scent):
			_learned_edges[scent] = link.id
	if (link.sampled_mask & mask) != mask:
		link.sampled_mask |= mask
		_rebuild_visible_links()
	if _filter == WIDE:
		_feedback = "已記下這段香流。逐種香紋取樣可分開混香。"
	else:
		link.focused_mask |= mask
		_focused_edges[_filter] = link.id
		_focused_strengths[_filter] = _cue.strengths[_filter]
		_feedback = "已取到%s。沿風箭的反方向找上游。" % AROMAS[_filter]
		_learn_mix(link)
	_note(10)


func _learn_mix(link: Link) -> void:
	if _mix_proven or _mix_mark >= 0:
		return
	for pair in PAIRS:
		if (link.focused_mask & pair) != pair:
			continue
		var merge := _first_shared_merge(link, pair)
		if merge >= 0:
			_mixed_mask = pair
			_mix_mark = merge
			_feedback = "分開了同段的兩股香。逆風找到匯合路口再標記。"
			return


func _first_shared_merge(link: Link, pair: int) -> int:
	var pending: Array[int] = [link.from_node]
	var visited := PackedByteArray()
	visited.resize(_nodes.size())
	while not pending.is_empty():
		var node: int = pending.pop_back()
		if visited[node]:
			continue
		visited[node] = 1
		var inherited_mix := false
		var separate_channels := 0
		for previous in _wind_links:
			if previous.to_node != node:
				continue
			var channels := previous.source_mask & pair
			if channels == pair:
				inherited_mix = true
				pending.append(previous.from_node)
			else:
				separate_channels |= channels
		# A junction proves the first combination only if each scent arrives on a separate link.
		if not inherited_mix and separate_channels == pair:
			return node
	return -1


func _can_mark() -> bool:
	return _mix_mark >= 0 and not _mix_proven and _player.distance_squared_to(_nodes[_mix_mark]) <= MARK_RADIUS * MARK_RADIUS


func _confirmable_stall() -> int:
	for scent in STALL_COUNT:
		if (_found_mask & (1 << scent)) or (_filter != WIDE and _filter != scent):
			continue
		var difference := _nodes[int(STALLS[scent][0])] - _player
		var distance := difference.length_squared()
		if distance <= STALL_RADIUS * STALL_RADIUS:
			if distance <= 0.10 * 0.10 or difference.normalized().dot(_sampler_dir) >= cos(ASSIST_SCAN_ANGLE if _assisted else SCAN_ANGLE):
				return scent
	return -1


func _near_cold_stall() -> bool:
	for index in range(STALL_COUNT, STALLS.size()):
		if _player.distance_squared_to(_nodes[int(STALLS[index][0])]) <= STALL_RADIUS * STALL_RADIUS:
			return true
	return false


func _confirm_stall(scent: int) -> void:
	_found_mask |= 1 << scent
	_sampled_mask |= 1 << scent
	_found += 1
	if _helper_scent == scent:
		_helper_until = 0
	_rebuild_stalls()
	_note(14)
	if _found == STALL_COUNT:
		_finish("三個正在烹煮的攤都確認了。")
	else:
		_feedback = "確認%s正在烹煮。還有 %d 攤。" % [STALLS[scent][1], STALL_COUNT - _found]


func _helper_node() -> int:
	if not _assisted or _ended or _filter < 0 or (_found_mask & (1 << _filter)):
		return -1
	var observed := _focused_edges[_filter]
	if observed < 0 or _focused_strengths[_filter] > FAINT_LIMIT:
		return -1
	var node := _links[observed].from_node
	for _step in _wind_links.size():
		if node < STALL_COUNT:
			return -1
		if _walk_degree[node] != 2:
			return node
		var previous := _previous_for_scent(node, _filter)
		if previous == null:
			return node
		node = previous.from_node
	return -1


func _previous_for_scent(node: int, scent: int) -> Link:
	for previous in _wind_links:
		if previous.to_node == node and _along_strength(previous, previous.length)[scent] >= MIN_STRENGTH:
			return previous
	return null


func _assist_direction() -> Vector2:
	if not _assisted or _ended or _filter < 0 or (_found_mask & (1 << _filter)):
		return Vector2.ZERO
	var learned := _learned_edges[_filter]
	if learned < 0:
		return Vector2.ZERO
	var closest: Link = _links[learned]
	var best := ASSIST_SCAN_RADIUS * ASSIST_SCAN_RADIUS
	for link in _wind_links:
		if link.entry_strengths[_filter] < MIN_STRENGTH:
			continue
		var distance := _player.distance_squared_to(link.closest(_player))
		if distance < best:
			best = distance
			closest = link
	var upstream := _nodes[closest.from_node] - _player
	if upstream.length_squared() <= 0.14 * 0.14:
		var previous := _previous_for_scent(closest.from_node, _filter)
		return (_nodes[previous.from_node] - _player).normalized() if previous != null else -closest.axis
	return upstream.normalized()


func _rebuild_visible_links() -> void:
	var records: Array[Dictionary] = []
	for link in _links:
		var row := {
			"id": link.id, "from": link.from_node, "to": link.to_node, "a": link.a, "b": link.b,
			"open": link.open, "half_width": HALF_WIDTH, "wind": link.axis if link.flow_weight > 0.0 else Vector2.ZERO,
			"sampled_mask": link.sampled_mask,
		}
		row.make_read_only()
		records.append(row)
	records.make_read_only()
	_visible_links = records


func _rebuild_stalls() -> void:
	var records: Array[Dictionary] = []
	for index in STALLS.size():
		var row: Array = STALLS[index]
		var scent: int = row[2]
		var state := {
			"id": index, "node": row[0], "position": _nodes[int(row[0])], "name": row[1], "scent": scent,
			"cooking": scent >= 0, "found": scent >= 0 and bool(_found_mask & (1 << maxi(0, scent))),
		}
		state.make_read_only()
		records.append(state)
	records.make_read_only()
	_visible_stalls = records


func _finish(message: String) -> void:
	_ended = true
	clear_input()
	_helper_until = 0
	_accumulator = 0.0
	_feedback = message


func _seconds_limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _note(pitch: int) -> void:
	if _notes.size() < 8:
		_notes.append(pitch)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func snapshot() -> Dictionary:
	var elapsed := minf(float(_ticks) * TICK, _seconds_limit())
	var success := _found == STALL_COUNT
	var devil := success and _mix_proven
	var helper_ready := _helper_node() >= 0
	var action := "sample"
	var ready := false
	if not _ended:
		if _confirmable_stall() >= 0:
			action = "confirm"
			ready = true
		elif _can_mark():
			action = "mark"
			ready = true
		elif _cue.mask != 0:
			ready = true
		elif helper_ready:
			action = "helper"
			ready = true
	return {
		"assisted": _assisted, "layout": _layout, "bounds": BOUNDS,
		"player": _player, "velocity": _velocity, "facing": _facing,
		"sampler_dir": _sampler_dir, "sampler_turn": _sampler_turn, "filter": _filter,
		"links": _visible_links, "nodes": _nodes.duplicate(), "stalls": _visible_stalls, "cue": _cue,
		"action": action, "action_ready": ready, "sampled_mask": _sampled_mask,
		"found_mask": _found_mask, "found": _found, "mixed_mask": _mixed_mask, "mix_proven": _mix_proven,
		"assist_direction": _assist_direction(), "assist_half_angle": ASSIST_SCAN_ANGLE,
		"helper_ready": helper_ready, "helper_visible": _ticks < _helper_until and not _ended,
		"helper_point": _helper_point, "helper_scent": _helper_scent,
		"elapsed": elapsed, "remaining": _seconds_limit() - elapsed, "ended": _ended,
		"success": success, "devil": devil, "ordinary_eligible": _ended and _sampled_mask != 0,
		"score": _found * STALL_POINTS + int(devil) * MIX_POINTS, "feedback": _feedback,
	}
