extends "res://game/minigames/arcade/arcade_driver.gd"
## 折頁走廊: the hotel corridor is a giant open book and the traveller runs
## along its pages. Every crease in the floor claps its two pages shut the
## moment it reaches the traveller's feet; press the button to jump, and be in
## the air when the pages clap. Later creases stop under you and tremble (they
## dip flat just before they slam), twitch early as a feint, or come in quick
## pairs, and the corridor runs faster and faster. On the ground when the pages
## clap and the traveller is pressed flat into a bookmark that floats away. A
## jump that clears nothing ends in a stumble, so jumping all the time loses.
## Rules only: the picture lives in page_corridor_view.gd.
##
## Distances are screen pixels along the corridor; the traveller stays put and
## the corridor scrolls past.

const View = preload("res://game/minigames/arcade/page_corridor_view.gd")
## Scroll speed (pixels a second) at the start and the end of play.
const SPEED_FIRST := 300.0
const SPEED_LAST := 480.0
## Seconds between creases early and late, and between the two of a pair.
const GAP_FIRST := 1.35
const GAP_LAST := 0.78
const PAIR_GAP := 0.62
## Seconds in the air, how close to the top of the jump a clap counts as
## dead on, and how long a wasted jump's stumble lasts.
const JUMP_SECONDS := 0.44
const DEAD_ON := 0.07
const STUMBLE_SECONDS := 0.45
## A trembling crease waits this long under the traveller, and dips flat for
## the last DIP_SECONDS before it slams.
const HOLD_SHORTEST := 0.6
const HOLD_LONGEST := 1.25
const DIP_SECONDS := 0.35
## A feint twitches this many seconds before the crease arrives.
const FEINT_LEAD := 0.85
const SQUASH_SECONDS := 1.6
## When special creases may start (share of the round) and how often.
const PAIR_HEAT := 0.25
const HOLD_HEAT := 0.35
const FEINT_HEAT := 0.3
const CLEAR_POINTS := 10
const DEAD_ON_POINTS := 20
const STREAK_POINTS := 1
const STREAK_CAP := 10
## Planned this far ahead of the traveller, in pixels.
const AHEAD := 1800.0
## How long the first crease of play takes to arrive.
const FIRST_LEAD := 1.6

var distance := 0.0
## Planned creases, nearest first: {at, kind ("plain"/"hold"/"feint"), hold,
## pair (second of a pair), arrived_at, snapped_at, cleared, number (counting
## up from 1 each round, for the room numbers)}.
var creases: Array[Dictionary] = []
var airborne := false
var jump_at := -99.0
var stumble_at := -99.0
var squash_at := -99.0
var cleared := 0
var dead_on := 0
var streak := 0
var squashes := 0
var stumbles := 0
var _demo := false
var _made := 0
var _jump_counted := false


func _init() -> void:
	verb = "書頁闔起來的瞬間跳起來，別被夾成書籤！"
	hint = [["空白鍵", "跳"]]
	round_seconds = 45.0
	thresholds = [300, 750, 1150]
	verdicts = [
		"你成了旅館最受歡迎的書籤。",
		"銅牌！雖然被夾了幾頁，還是跑完走廊。",
		"銀牌！書頁啪啪闔上，你一頁也沒沾到。",
		"金牌！幽靈管理員把你寫進了旅館傳說。",
	]
	variants = [
		{"id": "standard", "label": "午夜走廊"},
		{"id": "pairs", "label": "連摺之夜", "pair": 0.4, "pair_heat": 0.08},
		{"id": "pranks", "label": "頑皮鬼翻頁", "hold": 0.24, "feint": 0.3, "trick_heat": 0.12},
	]
	score_label = "跳頁得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_corridor(1.0)


## The countdown runs the corridor and hops the first crease by itself.
func _warm_up(delta: float) -> void:
	var next := next_crease()
	if not airborne and not next.is_empty() and float(next.at) - distance <= speed() * JUMP_SECONDS * 0.5:
		_jump()
	_run(delta)


func _go() -> void:
	_demo = false
	_reset_corridor(FIRST_LEAD)


func _tick(delta: float) -> void:
	_run(delta)


func _press(button: StringName) -> void:
	if button == &"action" or button == &"up":
		_jump()


## No input, no points: until the player has pressed something this round,
## nothing that happens on its own scores.
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _snapshot(into: Dictionary) -> void:
	into.distance = distance
	into.speed = speed()
	into.creases = creases
	into.airborne = airborne
	into.jump_at = jump_at
	into.jump_seconds = air_time()
	into.stumble_at = stumble_at
	into.stumble_seconds = STUMBLE_SECONDS
	into.squash_at = squash_at
	into.squash_seconds = SQUASH_SECONDS
	into.dip_seconds = DIP_SECONDS
	into.feint_lead = FEINT_LEAD
	into.streak = streak
	into.cleared = cleared


func speed() -> float:
	return pace(lerpf(SPEED_FIRST, SPEED_LAST, heat()) * float(variant.get("speed", 1.0)))


func air_time() -> float:
	return JUMP_SECONDS * (1.25 if assisted else 1.0)


func next_crease() -> Dictionary:
	for crease in creases:
		if float(crease.snapped_at) < 0.0:
			return crease
	return {}


func squashed() -> bool:
	return clock - squash_at < SQUASH_SECONDS


func stumbling() -> bool:
	return clock - stumble_at < STUMBLE_SECONDS


func _jump() -> void:
	if airborne or squashed() or stumbling():
		return
	airborne = true
	jump_at = clock
	_jump_counted = false
	sound(67)


func _run(delta: float) -> void:
	if airborne and clock - jump_at >= air_time():
		airborne = false
		if not _jump_counted:
			# A jump that cleared nothing lands flat-footed.
			stumble_at = clock
			streak = 0
			if not _demo:
				stumbles += 1
				say("跳空了！", false)
			sound(52)
	if squashed():
		return
	var next := next_crease()
	if next.is_empty():
		distance += speed() * delta
	elif distance + speed() * delta < float(next.at):
		distance += speed() * delta
	else:
		distance = float(next.at)
		if float(next.hold) > 0.0:
			if float(next.arrived_at) < 0.0:
				next.arrived_at = clock
			if clock - float(next.arrived_at) >= float(next.hold):
				_snap(next)
		else:
			next.arrived_at = clock
			_snap(next)
	while creases.size() > 0 and float(creases[0].at) < distance - 900.0:
		creases.pop_front()
	_plan()


func _snap(crease: Dictionary) -> void:
	crease.snapped_at = clock
	sound(45)
	if airborne:
		crease.cleared = true
		_jump_counted = true
		streak += 1
		sound(72 + mini(streak, 12))
		if _demo:
			return
		cleared += 1
		var apex := jump_at + air_time() * 0.5
		var spot_on := absf(clock - apex) <= window(DEAD_ON)
		if spot_on:
			dead_on += 1
		var points := CLEAR_POINTS + (DEAD_ON_POINTS if spot_on else 0) + mini(streak, STREAK_CAP) * STREAK_POINTS
		add_score(points, "剛好！+%d" % points if spot_on else "")
		return
	crease.cleared = false
	streak = 0
	squash_at = clock
	sound(40)
	if _demo:
		return
	squashes += 1
	# The first bookmark of a round is a free look.
	funny_fail("夾成書籤了！", squashes > 1)


func _reset_corridor(lead: float) -> void:
	creases.clear()
	distance = 0.0
	airborne = false
	jump_at = -99.0
	stumble_at = -99.0
	squash_at = -99.0
	cleared = 0
	dead_on = 0
	streak = 0
	squashes = 0
	stumbles = 0
	_jump_counted = false
	_made = 0
	creases.append(_crease(speed() * lead, "plain", 0.0, false))
	_plan()


## Plan creases out to AHEAD: gaps shrink with heat; pairs, trembling holds
## and feints join once the round warms up.
func _plan() -> void:
	while creases.is_empty() or float(creases.back().at) < distance + AHEAD:
		var last: Dictionary = creases.back()
		var gap := lerpf(GAP_FIRST, GAP_LAST, heat()) * rng.randf_range(0.88, 1.18)
		var at := float(last.at) + gap * speed()
		var kind := "plain"
		var hold := 0.0
		var tricks := heat() >= float(variant.get("trick_heat", 1.0)) and not _demo
		if not _demo and heat() >= float(variant.get("pair_heat", PAIR_HEAT)) and not bool(last.pair) and rng.randf() < float(variant.get("pair", 0.18)):
			creases.append(_crease(at, "plain", 0.0, false))
			creases.append(_crease(at + PAIR_GAP * speed(), "plain", 0.0, true))
			continue
		if not _demo and (tricks or heat() >= HOLD_HEAT) and rng.randf() < float(variant.get("hold", 0.12)):
			kind = "hold"
			hold = rng.randf_range(HOLD_SHORTEST, HOLD_LONGEST)
		elif not _demo and (tricks or heat() >= FEINT_HEAT) and rng.randf() < float(variant.get("feint", 0.15)):
			kind = "feint"
		creases.append(_crease(at, kind, hold, false))


func _crease(at: float, kind: String, hold: float, pair: bool) -> Dictionary:
	_made += 1
	return {"number": _made, "at": at, "kind": kind, "hold": hold, "pair": pair, "arrived_at": -99.0, "snapped_at": -99.0, "cleared": false}
