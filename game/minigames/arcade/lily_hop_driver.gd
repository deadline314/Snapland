extends "res://game/minigames/arcade/arcade_driver.gd"
## 睡蓮踏浪: hop across the greenhouse pond on lily pads. Every pad starts to
## sink the moment you land on it, so keep hopping: → straight on, ↑ and ↓ to
## the pad up or down a lane. Later pads sink faster and drift between lanes,
## and a big bouncy pad flings you two columns. Missing a pad, or waiting too
## long, dunks you; you come back up with a frog sitting on your head. Rules
## only: the picture lives in lily_hop_view.gd.

const View = preload("res://game/minigames/arcade/lily_hop_view.gd")
const LANES := 3
## Pad columns between the near bank (column 0) and the far bank (COLUMNS + 1).
const COLUMNS := 7
const HOP_SECONDS := 0.28
const BOUNCE_SECONDS := 0.5
## Seconds a pad holds you up, at the first and at the last second of play.
const SINK_FIRST := 2.6
const SINK_LAST := 1.0
## Under water, then up again with a frog on top.
const DUNK_SECONDS := 1.5
const ASHORE_SECONDS := 0.7
## A drifting pad is under you when its lane is this close to yours.
const CATCH := 0.42
const HOP_POINTS := 10
const ASHORE_POINTS := 50
## Heat from which drifting and bouncy pads join a standard round.
const DRIFT_HEAT := 0.2
const BOUNCE_HEAT := 0.35
const DEMO_GAP := 0.6

## Pads of this pond: {column, lane (where it sits now), home, drift (0 still),
## phase, kind ("pad" or "bounce"), landed (clock, or -1), gone}.
var pads: Array[Dictionary] = []
var pond := 0
var column := 0
var lane := 1
## "stand", "hop", "dunk" or "ashore".
var mode := "stand"
var mode_at := 0.0
## The hop in flight: from column/lane to column/lane, and whether it was a bounce.
var hop_from := Vector2i(0, 1)
var hop_to := Vector2i(0, 1)
var bounced := false
## The pad under the visitor, or -1 on a bank.
var standing := -1
## Frogs riding on the visitor's head; the bank washes them off.
var frogs := 0
var dunks := 0
var hops := 0
var crossings := 0

var _queued := 0
var _queue_set := false
var _demo := false
var _demo_at := 0.0


func _init() -> void:
	verb = "葉子會沉，快跳過池塘！"
	hint = [["→", "往前跳"], ["↑ ↓", "跳到上下的葉子"]]
	round_seconds = 45.0
	thresholds = [250, 500, 750]
	verdicts = [
		"青蛙們一致推舉你當池塘的新石頭。",
		"銅牌！鞋子濕了，但人過去了。",
		"銀牌！葉子還沒反應過來你就走了。",
		"金牌！睡蓮在你腳下像鋼琴鍵。",
	]
	variants = [
		{"id": "calm", "label": "平靜池塘"},
		{"id": "drift", "label": "漂流荷葉", "drift": true},
		{"id": "bouncy", "label": "彈跳大葉", "bouncy": true},
	]
	score_label = "踏浪得分"
	view_script = View


## Seconds the pad under you holds; longer with assist.
func sink_seconds() -> float:
	return window(lerpf(SINK_FIRST, SINK_LAST, heat()))


func _begin_round(_chosen: Dictionary) -> void:
	pond = 0
	frogs = 0
	dunks = 0
	hops = 0
	crossings = 0
	_demo = true
	_demo_at = 0.0
	_new_pond()


func _warm_up(_delta: float) -> void:
	# The countdown hops the first few pads by itself, never scoring.
	_update_pads()
	_settle()
	if mode == "stand" and clock - _demo_at >= DEMO_GAP:
		_demo_at = clock
		var step := _best_step()
		if step != 99:
			_hop(step)


func _go() -> void:
	_demo = false
	pond = 0
	_new_pond()


func _tick(_delta: float) -> void:
	_update_pads()
	_settle()
	if mode == "stand" and standing >= 0 and clock - float(pads[standing].landed) >= sink_seconds():
		_dunk("sank")


func _press(button: StringName) -> void:
	var step := 99
	match button:
		&"right", &"action":
			step = 0
		&"up":
			step = -1
		&"down":
			step = 1
	if step == 99:
		return
	if mode == "hop":
		# One press may wait for the landing, so quick fingers are never eaten.
		_queued = step
		_queue_set = true
		return
	if mode == "stand":
		_hop(step)


func _round_over() -> void:
	_queue_set = false


func _snapshot(into: Dictionary) -> void:
	into.pads = pads
	into.pond = pond
	into.column = column
	into.lane = lane
	into.mode = mode
	into.mode_at = mode_at
	into.hop_from = hop_from
	into.hop_to = hop_to
	into.hop_seconds = BOUNCE_SECONDS if bounced else HOP_SECONDS
	into.bounced = bounced
	into.standing = standing
	into.frogs = frogs
	into.sink_seconds = sink_seconds()
	into.sink_left = 1.0 - clampf((clock - float(pads[standing].landed)) / sink_seconds(), 0.0, 1.0) if standing >= 0 and mode == "stand" else 1.0
	into.columns = COLUMNS
	into.lanes = LANES


## The pad of `at_column` whose lane is within reach of `at_lane`, or -1.
func pad_at(at_column: int, at_lane: int) -> int:
	for index in pads.size():
		var pad: Dictionary = pads[index]
		if int(pad.column) == at_column and not bool(pad.gone) and absf(float(pad.lane) - at_lane) <= CATCH * (1.25 if assisted else 1.0):
			return index
	return -1


func _hop(step: int) -> void:
	var target_lane := lane + step
	if target_lane < 0 or target_lane >= LANES:
		sound(48)
		return
	hop_from = Vector2i(column, lane)
	hop_to = Vector2i(column + 1, target_lane)
	bounced = false
	_leave_pad()
	_mode("hop")
	sound(72 + step * 3)


## A bounce pad flings the visitor two columns down the same lane.
func _bounce() -> void:
	hop_from = Vector2i(column, lane)
	hop_to = Vector2i(mini(column + 2, COLUMNS + 1), lane)
	bounced = true
	_leave_pad()
	_mode("hop")
	sound(84)


func _settle() -> void:
	var waited := clock - mode_at
	match mode:
		"hop":
			if waited >= (BOUNCE_SECONDS if bounced else HOP_SECONDS):
				_land()
		"dunk":
			if waited >= DUNK_SECONDS:
				_resurface()
		"ashore":
			if waited >= ASHORE_SECONDS:
				_new_pond()


func _land() -> void:
	column = hop_to.x
	lane = hop_to.y
	if column > COLUMNS:
		_ashore()
		return
	var under := pad_at(column, lane)
	if under < 0:
		_dunk("missed")
		return
	standing = under
	var pad: Dictionary = pads[under]
	pad.landed = clock
	pad.drift = 0.0
	pad.lane = float(lane)
	var gained := HOP_POINTS * (2 if bounced else 1)
	if not _demo:
		hops += 1
		add_score(gained)
	sound(76 if not bounced else 81)
	if str(pad.kind) == "bounce":
		say("彈！", true)
		_bounce()
		return
	_mode("stand")
	if _queue_set:
		_queue_set = false
		_hop(_queued)


func _ashore() -> void:
	standing = -1
	frogs = 0
	_queue_set = false
	if not _demo:
		crossings += 1
		add_score(ASHORE_POINTS, "上岸！+%d" % ASHORE_POINTS)
	sound(88)
	_mode("ashore")


func _dunk(why: String) -> void:
	_leave_pad()
	_queue_set = false
	dunks += 1
	frogs = mini(frogs + 1, 3)
	sound(43)
	var words := "噗通！" if why == "missed" else "沉下去了！"
	# The first dunk of a round is a free look at the frog.
	if dunks > 1 and not _demo:
		add_mistake(words)
	else:
		say(words, false)
	_mode("dunk")


## Back up through the lily pads: a fresh pad pops up under the visitor.
func _resurface() -> void:
	pads.append(_pad(column, lane, 0.0, "pad"))
	standing = pads.size() - 1
	pads[standing].landed = clock
	_ensure_way()
	sound(65)
	say("呱！", false)
	_mode("stand")


func _leave_pad() -> void:
	if standing >= 0:
		pads[standing].gone = true
		pads[standing].left = clock
	standing = -1


func _mode(next: String) -> void:
	mode = next
	mode_at = clock


## Drifting pads slide between two neighbouring lanes.
func _update_pads() -> void:
	for pad: Dictionary in pads:
		var drift := float(pad.drift)
		if drift > 0.0:
			pad.lane = float(pad.home) + 0.5 - 0.5 * cos(float(pad.phase) + clock * pace(drift))


## A new pond: a path every visitor can take, with drifting and bouncy pads as the round heats up.
func _new_pond() -> void:
	pond += 1
	column = 0
	standing = -1
	mode = "stand"
	mode_at = clock
	_queue_set = false
	pads.clear()
	var drift_share := 0.45 if bool(variant.get("drift", false)) else clampf((heat() - DRIFT_HEAT) * 1.1, 0.0, 0.55)
	var bounce_share := 0.28 if bool(variant.get("bouncy", false)) else (0.14 if heat() >= BOUNCE_HEAT else 0.0)
	var drift_speed := 1.6 + 1.8 * heat() + (1.2 if bool(variant.get("drift", false)) else 0.0)
	var reachable: Array[int] = [lane]
	## Columns where a bounce will land: column -> lanes that must hold a fixed pad.
	var landings: Dictionary = {}
	var path := lane
	for c in range(1, COLUMNS + 1):
		path = clampi(path + rng.randi_range(-1, 1), 0, LANES - 1)
		var lanes_here: Array[int] = [path]
		for forced: int in landings.get(c, []):
			if not lanes_here.has(forced):
				lanes_here.append(forced)
		if rng.randf() < 0.45:
			var extra := rng.randi() % LANES
			if not lanes_here.has(extra):
				lanes_here.append(extra)
		# Every lane the visitor could be standing in keeps a way forward.
		for from_lane in reachable:
			if not lanes_here.any(func(l: int) -> bool: return absi(l - from_lane) <= 1):
				lanes_here.append(clampi(from_lane + (1 if path > from_lane else -1), 0, LANES - 1))
		var next_reachable: Array[int] = []
		for l in lanes_here:
			var kind := "pad"
			var fixed: bool = l in landings.get(c, [])
			if not _demo and not fixed and c < COLUMNS and l == path and rng.randf() < bounce_share:
				kind = "bounce"
				if c + 2 <= COLUMNS:
					if not landings.has(c + 2):
						landings[c + 2] = []
					landings[c + 2].append(l)
			if not _demo and not fixed and kind == "pad" and lanes_here.size() == 1 and l < LANES - 1 and rng.randf() < drift_share:
				# The only pad of a column drifts between this lane and the one below: always reachable at some moment.
				pads.append(_pad(c, l, drift_speed, "pad"))
				next_reachable.append_array([l, l + 1])
				continue
			pads.append(_pad(c, l, 0.0, kind))
			next_reachable.append(l)
		reachable = next_reachable


## After a dunk the visitor must still be able to go on from where they came up.
func _ensure_way() -> void:
	if column + 1 > COLUMNS:
		return
	for step: int in [0, -1, 1]:
		for index in pads.size():
			var pad: Dictionary = pads[index]
			if int(pad.column) == column + 1 and not bool(pad.gone) and (float(pad.drift) > 0.0 or int(pad.home) == lane + step):
				return
	pads.append(_pad(column + 1, lane, 0.0, "pad"))


func _pad(at_column: int, at_lane: int, drift: float, kind: String) -> Dictionary:
	return {"column": at_column, "lane": float(at_lane), "home": at_lane, "drift": drift, "phase": rng.randf() * TAU,
		"kind": kind, "landed": -1.0, "gone": false, "left": -1.0, "born": clock}


## The step (-1, 0, 1) toward a pad that is under that lane right now, else 99.
func _best_step() -> int:
	for step: int in [0, -1, 1]:
		var target := lane + step
		if target < 0 or target >= LANES:
			continue
		if column + 1 > COLUMNS or pad_at(column + 1, target) >= 0:
			return step
	return 99
