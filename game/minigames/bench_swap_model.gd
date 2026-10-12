extends RefCounted
class_name BenchSwapModel

## Small finite seating-order puzzle. Snapshot dictionaries are retained and read-only.
const LEVELS := [
	{"name":"窗邊重逢", "initial":[0,1,2,3,4,5], "rules":[{"kind":"together","a":1,"b":2},{"kind":"seat","guest":0,"seat":5}], "budget":3},
	{"name":"海風與留白", "initial":[0,1,2,3,5,4], "rules":[{"kind":"together","a":1,"b":2},{"kind":"seat","guest":0,"seat":5},{"kind":"apart","a":1,"b":4}], "budget":4},
	{"name":"長椅邀約", "initial":[0,1,2,3,4,5], "rules":[{"kind":"together","a":1,"b":2},{"kind":"seat","guest":0,"seat":5},{"kind":"apart","a":1,"b":4},{"kind":"seat","guest":3,"seat":2}], "budget":5},
]
const GUESTS := ["小燈","海星","貝殼","小帆","螃蟹","水母"]
const SEATS := 6
const MAX_FRAME_DELTA := 0.25
const SWAP_SECONDS := 0.28

var assisted := false
var time_phase := "noon"
var level := 0
var seats: Array[int] = []
var selected_seat := -1
var moves := 0
var score := 0
var optimal_moves := 0
var elapsed := 0.0
var finished := false
var success := false
var devil := false
var timed_out := false
var _had_retry := false
var last_event := ""
var _ledger: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _snapshot_revision := 0
var _swap_from := -1
var _swap_to := -1
var _swap_elapsed := 0.0
var _moving_guest_from := -1
var _moving_guest_to := -1
var _pending_swap_solved := false
var _pending_swap_retry := false
var _hint_pair: Array[int] = []

func _init() -> void:
	reset()

func reset(p_assisted: bool = false, p_time_phase: String = "noon") -> void:
	assisted = p_assisted
	time_phase = p_time_phase if ["dawn", "noon", "dusk", "night"].has(p_time_phase) else "noon"
	level = 0
	moves = 0
	score = 0
	elapsed = 0.0
	finished = false
	success = false
	devil = false
	timed_out = false
	_had_retry = false
	selected_seat = -1
	_swap_from = -1
	_swap_to = -1
	_swap_elapsed = 0.0
	_moving_guest_from = -1
	_moving_guest_to = -1
	_pending_swap_solved = false
	_pending_swap_retry = false
	_ledger.clear()
	_start_level()
	_snapshot_revision += 1
	_refresh_snapshot()

func select_seat(index: int) -> bool:
	if finished or _swap_from >= 0 or index < 0 or index >= SEATS:
		return false
	if selected_seat < 0:
		selected_seat = index
		last_event = "已選第 %d 席，選另一席交換" % (index + 1)
		_refresh_snapshot()
		return false
	if selected_seat == index:
		selected_seat = -1
		last_event = "取消選席"
		_refresh_snapshot()
		return false
	_swap_seats(selected_seat, index)
	return true

func step(delta: float) -> Dictionary:
	if (finished and _swap_from < 0) or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var dt := minf(delta, MAX_FRAME_DELTA)
	elapsed += dt
	if _swap_from >= 0:
		_swap_elapsed = minf(SWAP_SECONDS, _swap_elapsed + dt)
		if _swap_elapsed >= SWAP_SECONDS:
			_swap_from = -1
			_swap_to = -1
			_resolve_animated_swap()
	_snapshot_revision += 1
	_refresh_snapshot()
	return snapshot()

func snapshot() -> Dictionary:
	return _snapshot

func _start_level() -> void:
	var data: Dictionary = LEVELS[level]
	seats.clear()
	for guest in data.initial:
		seats.append(int(guest))
	optimal_moves = _shortest_solution(seats)
	moves = 0
	selected_seat = -1
	_swap_from = -1
	_swap_to = -1
	_swap_elapsed = 0.0
	_moving_guest_from = -1
	_moving_guest_to = -1
	_pending_swap_solved = false
	_pending_swap_retry = false
	_hint_pair.clear()
	last_event = "依圖示安排座位；選兩席交換"

func _swap_seats(a: int, b: int) -> void:
	_hint_pair.clear()
	_moving_guest_from = seats[a]
	_moving_guest_to = seats[b]
	var hold := seats[a]
	seats[a] = seats[b]
	seats[b] = hold
	moves += 1
	selected_seat = -1
	_swap_from = a
	_swap_to = b
	_swap_elapsed = 0.0
	var solved := rules_satisfied(seats)
	_ledger.append({"level":level,"from":a,"to":b,"moves":moves,"optimal_moves":optimal_moves,"valid":true,"solved":solved,"order":seats.duplicate()})
	_pending_swap_solved = solved
	_pending_swap_retry = not solved and moves >= int(LEVELS[level].budget)
	last_event = "朋友正在換位…"
	if assisted and not solved:
		_hint_pair = _next_optimal_swap()
	_snapshot_revision += 1
	_refresh_snapshot()

func _resolve_animated_swap() -> void:
	if _pending_swap_solved:
		var points := maxi(0, 300 - moves * 25)
		score += points
		_ledger.back()["points"] = points
		_pending_swap_solved = false
		if level < LEVELS.size() - 1:
			level += 1
			_start_level()
			last_event = "這桌完成，安排下一桌"
		else:
			_finish()
	elif _pending_swap_retry:
		_pending_swap_retry = false
		_had_retry = true
		_start_level()
		last_event = "次數用完，這桌重新排座"
	else:
		last_event = "座位已交換"

func _finish() -> void:
	finished = true
	success = true
	devil = not assisted and _all_optimal()
	last_event = "三桌都以最少步數排好" if devil else "三桌朋友都重逢了"

func _all_optimal() -> bool:
	var solved_levels := 0
	for entry in _ledger:
		if bool(entry.solved):
			solved_levels += 1
			if int(entry.moves) != int(entry.optimal_moves):
				return false
	return solved_levels == LEVELS.size() and not _had_retry

func rules_satisfied(order: Array, level_index: int = -1) -> bool:
	var selected_level := level if level_index < 0 else clampi(level_index, 0, LEVELS.size() - 1)
	return _rules_satisfied(order, LEVELS[selected_level].rules)

func _rules_satisfied(order: Array, rules: Array) -> bool:
	if order.size() != SEATS:
		return false
	var sorted_order := order.duplicate()
	sorted_order.sort()
	if sorted_order != [0, 1, 2, 3, 4, 5]:
		return false
	for rule in rules:
		var kind := str(rule.kind)
		var pa := order.find(int(rule.get("a", -1)))
		var pb := order.find(int(rule.get("b", -1)))
		if kind == "seat" and order.find(int(rule.guest)) != int(rule.seat): return false
		if kind == "together" and absi(pa - pb) != 1: return false
		if kind == "apart" and absi(pa - pb) < 2: return false
	return true

func _shortest_solution(start: Array) -> int:
	var queue: Array = [start.duplicate()]
	var distance := { _key(start): 0 }
	var cursor := 0
	while cursor < queue.size():
		var order: Array = queue[cursor]
		cursor += 1
		var depth: int = distance[_key(order)]
		if _rules_satisfied(order, LEVELS[level].rules): return depth
		for a in SEATS:
			for b in range(a + 1, SEATS):
				var next: Array = order.duplicate()
				var hold: Variant = next[a]
				next[a] = next[b]
				next[b] = hold
				var key := _key(next)
				if not distance.has(key):
					distance[key] = depth + 1
					queue.append(next)
	return 999

func _next_optimal_swap() -> Array[int]:
	for a in SEATS:
		for b in range(a + 1, SEATS):
			var next: Array = seats.duplicate()
			var hold: Variant = next[a]
			next[a] = next[b]
			next[b] = hold
			if _shortest_solution(next) == _shortest_solution(seats) - 1:
				return [a,b]
	return []

func _key(order: Array) -> String:
	return ",".join(order.map(func(value: Variant) -> String: return str(value)))

func _refresh_snapshot() -> void:
	if _snapshot.is_empty():
		_snapshot = {"revision":0,"level":0,"level_name":"","levels":LEVELS.size(),"seats":[],"guests":GUESTS,"rules":[],"rule_text":"","move_budget":0,"optimal_moves":0,"moves":0,"score":0,"total_score":0,"elapsed":0.0,"assisted":false,"time_phase":"noon","selected_seat":-1,"swap_from":-1,"swap_to":-1,"moving_guest_from":-1,"moving_guest_to":-1,"swap_progress":1.0,"hint_pair":[],"finished":false,"success":false,"devil":false,"timed_out":false,"last_event":"","ledger":[]}
	_snapshot["revision"] = _snapshot_revision
	_snapshot["level"] = level
	_snapshot["level_name"] = LEVELS[mini(level, LEVELS.size() - 1)].name
	_snapshot["levels"] = LEVELS.size()
	_snapshot["seats"] = seats
	_snapshot["rules"] = LEVELS[level].rules if not finished else []
	_snapshot["rule_text"] = _rule_text(LEVELS[level].rules) if not finished else "三桌完成"
	_snapshot["move_budget"] = LEVELS[level].budget if not finished else 0
	_snapshot["optimal_moves"] = optimal_moves
	_snapshot["moves"] = moves
	_snapshot["score"] = score
	_snapshot["total_score"] = score
	_snapshot["elapsed"] = elapsed
	_snapshot["assisted"] = assisted
	_snapshot["time_phase"] = time_phase
	_snapshot["selected_seat"] = selected_seat
	_snapshot["swap_from"] = _swap_from
	_snapshot["swap_to"] = _swap_to
	_snapshot["moving_guest_from"] = _moving_guest_from
	_snapshot["moving_guest_to"] = _moving_guest_to
	_snapshot["swap_progress"] = clampf(_swap_elapsed / SWAP_SECONDS, 0.0, 1.0) if _swap_from >= 0 else 1.0
	_snapshot["hint_pair"] = _hint_pair
	_snapshot["finished"] = finished
	_snapshot["success"] = success
	_snapshot["devil"] = devil
	_snapshot["timed_out"] = timed_out
	_snapshot["last_event"] = last_event
	_snapshot["ledger"] = _ledger

func _rule_text(rules: Array) -> String:
	var labels: Array[String] = []
	for rule in rules:
		match str(rule.kind):
			"together": labels.append("● 海星與貝殼並坐")
			"apart": labels.append("◇ 海星與螃蟹至少隔一席")
			"seat": labels.append("⌂ %s靠窗" % GUESTS[int(rule.guest)] if int(rule.seat) == 5 else "№ %s坐%d號" % [GUESTS[int(rule.guest)], int(rule.seat) + 1])
	return "　".join(labels)
