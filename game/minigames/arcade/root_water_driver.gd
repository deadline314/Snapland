extends "res://game/minigames/arcade/arcade_driver.gd"
## 根系蓄水: potted seedlings slide one by one along the greenhouse potting
## bench and stop under the traveller's watering can. Each pot has a glass side
## showing its soil and roots and a chalk line; hold to pour and let go when the
## water reaches the line. Small pots fill fast, big ones slowly. Later on some
## pots leak and have to be topped up, and some suddenly grow bigger mid-pour.
## Pour past the brim and the water spills: the traveller slips in the puddle
## and lands bottom-first in the pot.
## Rules only: the picture lives in root_water_view.gd.
##
## Pot x runs in screen widths; level and line run 0 (pot floor) to 1 (brim).

const View = preload("res://game/minigames/arcade/root_water_view.gd")
## Where the can pours, in screen widths.
const STATION := 0.56
const ENTER_X := 1.15
const EXIT_X := -0.25
const SLIDE_FIRST := 0.6
const SLIDE_LAST := 0.4
## Seconds a pot waits under the can, early and late.
const DWELL_FIRST := 3.2
const DWELL_LAST := 2.0
## Fill per second for small, medium and big pots.
const FILL: Array[float] = [0.85, 0.6, 0.45]
const LINE_LOW := 0.45
const LINE_HIGH := 0.82
## Within PERFECT of the line is spot on; within GOOD still counts.
const PERFECT := 0.06
const GOOD := 0.14
const PERFECT_POINTS := 20
const GOOD_POINTS := 8
const STREAK_POINTS := 5
const STREAK_CAP := 6
const LEAK := 0.13
const LEAK_HEAT := 0.25
const GROW_HEAT := 0.4
## A growing pot pops one size up once it is this far to its line; the same
## water then sits lower in the wider pot.
const GROW_AT := 0.6
const GROW_SHRINK := 0.6
const SLIP_SECONDS := 1.8

## Pots on the bench: {size, line, level, kind ("plain", "leaky", "grow"),
## grown_at, x, phase ("in", "under", "out"), since, leave_at, result,
## result_at, spilled}.
var pots: Array[Dictionary] = []
var pouring := false
## The last spill: {at}.
var slip: Dictionary = {}
var streak := 0
var spills := 0
var watered := 0

var _holding := 0
var _demo := false


func _init() -> void:
	verb = "按住澆水，水到刻線就放手！"
	hint = [["空白鍵", "按住澆水"]]
	round_seconds = 45.0
	thresholds = [100, 230, 330]
	verdicts = [
		"幼苗們決定改種仙人掌。",
		"銅牌！根有喝到水，只是喝得不太均勻。",
		"銀牌！一整排幼苗都冒出了新芽。",
		"金牌！溫室園丁封你為澆水大師。",
	]
	variants = [
		{"id": "standard", "label": "晨間澆水"},
		{"id": "big", "label": "大盆日", "big": 0.55},
		{"id": "leaky", "label": "漏水日", "leaky": 0.35},
	]
	score_label = "澆水得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_bench()
	# The countdown demo: one small pot slides in and the can fills it to the line.
	var pot := _pot(0, 0.62, "plain")
	pot.leave_at = 99.0
	pots.append(pot)


## The countdown pours the demo pot up to its line by itself.
func _warm_up(delta: float) -> void:
	var pot := under()
	pouring = not pot.is_empty() and clock > 0.8 and float(pot.level) < float(pot.line) - 0.01
	_run(delta)


func _go() -> void:
	# Play starts with an empty bench and the first pot only just sliding in,
	# so nothing is lost before the player's first press.
	_demo = false
	_reset_bench()
	pots.append(_next_pot())


func _tick(delta: float) -> void:
	pouring = _holding > 0 and not busy()
	_run(delta)


func _press(button: StringName) -> void:
	if button in [&"action", &"up", &"down", &"second"]:
		_holding += 1


func _release(button: StringName) -> void:
	if button in [&"action", &"up", &"down", &"second"]:
		_holding = maxi(0, _holding - 1)


## No input, no points.
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _round_over() -> void:
	_holding = 0
	pouring = false


func _snapshot(into: Dictionary) -> void:
	into.pots = pots
	into.pouring = pouring
	into.slip = slip
	into.slip_seconds = SLIP_SECONDS
	into.station = STATION
	into.streak = streak


func busy() -> bool:
	return not slip.is_empty() and clock - float(slip.at) < SLIP_SECONDS


## The pot standing under the can, or {}.
func under() -> Dictionary:
	for pot in pots:
		if pot.phase == "under":
			return pot
	return {}


func fill_rate(pot: Dictionary) -> float:
	return FILL[int(pot.size)]


func dwell() -> float:
	return window(lerpf(DWELL_FIRST, DWELL_LAST, heat()))


func slide() -> float:
	return lerpf(SLIDE_FIRST, SLIDE_LAST, heat())


func perfect_band() -> float:
	return PERFECT * (ASSIST_WINDOW if assisted else 1.0)


func good_band() -> float:
	return GOOD * (ASSIST_WINDOW if assisted else 1.0)


func _run(delta: float) -> void:
	var pot := under()
	if pouring and not pot.is_empty() and not bool(pot.spilled):
		pot.level = float(pot.level) + fill_rate(pot) * delta
		if pot.kind == "grow" and float(pot.grown_at) < 0.0 and float(pot.level) >= float(pot.line) * GROW_AT:
			_grow(pot)
		if float(pot.level) > 1.0:
			_spill(pot)
	for each in pots:
		if each.kind == "leaky" and each.phase != "out" and not bool(each.spilled):
			each.level = maxf(0.0, float(each.level) - LEAK * delta)
	_move()


func _move() -> void:
	var gone: Array[Dictionary] = []
	var arriving := false
	for pot in pots:
		var since := clock - float(pot.since)
		match pot.phase:
			"in":
				pot.x = lerpf(ENTER_X, STATION, ease(clampf(since / slide(), 0.0, 1.0), 0.5))
				if since >= slide():
					pot.phase = "under"
					pot.since = clock
					pot.x = STATION
					pot.leave_at = minf(float(pot.leave_at), clock + dwell())
			"under":
				if clock >= float(pot.leave_at):
					_judge(pot)
					pot.phase = "out"
					pot.since = clock
					arriving = not _demo
			"out":
				pot.x = lerpf(STATION, EXIT_X, ease(clampf(since / slide(), 0.0, 1.0), 2.0))
				if since >= slide() + 0.3:
					gone.append(pot)
	for pot in gone:
		pots.erase(pot)
	if arriving:
		pots.append(_next_pot())


func _judge(pot: Dictionary) -> void:
	pot.result_at = clock
	if bool(pot.spilled):
		pot.result = "spilled"
		return
	var off := float(pot.level) - float(pot.line)
	if absf(off) <= perfect_band():
		pot.result = "perfect"
		sound(76 + mini(streak, 8))
		if _demo:
			return
		watered += 1
		streak += 1
		var points := PERFECT_POINTS + mini(streak - 1, STREAK_CAP) * STREAK_POINTS
		add_score(points, ("剛剛好！×%d" % streak) if streak >= 3 else "剛剛好！")
	elif absf(off) <= good_band():
		pot.result = "good"
		sound(69)
		streak = 0
		watered += 1
		add_score(GOOD_POINTS, "差一點")
	else:
		pot.result = "dry" if off < 0.0 else "soggy"
		streak = 0
		sound(57)
		if touched:
			say("還渴！" if off < 0.0 else "太多了", false)


func _grow(pot: Dictionary) -> void:
	pot.grown_at = clock
	pot.size = mini(int(pot.size) + 1, 2)
	pot.level = float(pot.level) * GROW_SHRINK
	sound(64)
	sound(71)


func _spill(pot: Dictionary) -> void:
	pot.level = 1.0
	pot.spilled = true
	pot.leave_at = clock + SLIP_SECONDS
	slip = {"at": clock}
	streak = 0
	sound(48)
	sound(43)
	if _demo:
		return
	spills += 1
	# The first spill of a round is a free look at the slip.
	funny_fail("水滿出來了！", spills > 1)


func _next_pot() -> Dictionary:
	var big := float(variant.get("big", 0.0))
	var roll := rng.randf()
	var size := 0
	if roll < big:
		size = 2
	else:
		size = rng.randi_range(0, 2 if heat() > 0.15 else 1)
	var kind := "plain"
	var leaky := float(variant.get("leaky", 0.0))
	if heat() >= LEAK_HEAT:
		leaky = maxf(leaky, 0.3)
	var growing := 0.25 if heat() >= GROW_HEAT and size < 2 else 0.0
	var pick := rng.randf()
	if pick < leaky:
		kind = "leaky"
	elif pick < leaky + growing:
		kind = "grow"
	return _pot(size, rng.randf_range(LINE_LOW, LINE_HIGH), kind)


func _pot(size: int, line: float, kind: String) -> Dictionary:
	return {"size": size, "line": line, "level": 0.0, "kind": kind, "grown_at": -99.0, "x": ENTER_X, "phase": "in",
		"since": clock, "leave_at": 99999.0, "result": "", "result_at": -99.0, "spilled": false}


func _reset_bench() -> void:
	pots.clear()
	slip = {}
	streak = 0
	spills = 0
	watered = 0
	pouring = false
	_holding = 0
