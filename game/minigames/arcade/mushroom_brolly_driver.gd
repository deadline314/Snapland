extends "res://game/minigames/arcade/arcade_driver.gd"
## 蘑菇撐傘: rain leaks through the greenhouse roof onto a bench of seedlings.
## Slide the big mushroom umbrella left and right: rain it catches runs down
## its stem and drips into the pot underneath, so hold it over the thirsty
## seedling (the one with the droplet bubble). Hailstones bonk off the cap and
## leave a dent; one that gets past hits a seedling, which droops with a sniff.
## Rules only: the picture lives in mushroom_brolly_view.gd.
##
## Positions run from 0 (left wall) to 1 (right wall); heights from 0 (the
## leaky roof) to 1 (the soil in the pots).

const View = preload("res://game/minigames/arcade/mushroom_brolly_view.gd")
const POTS: Array[float] = [0.2, 0.4, 0.6, 0.8]
## Half the width of the cap, and of the soil in a pot.
const CAP_HALF := 0.085
const POT_HALF := 0.05
## The stem tip has to be this close to a pot for caught rain to drip in.
const DRIP_REACH := 0.06
const CAP_Y := 0.62
const SPEED := 0.95
const SPAWN_LEFT := 0.08
const SPAWN_RIGHT := 0.92
## Seconds to fall from the roof to the soil.
const RAIN_FALL := 1.2
const HAIL_FALL := 0.85
## Seconds between raindrops and between hailstones, at the start and at the end of play.
const RAIN_GAP_FIRST := 0.26
const RAIN_GAP_LAST := 0.12
const HAIL_GAP_FIRST := 2.4
const HAIL_GAP_LAST := 0.9
const HAIL_HEAT := 0.2
const BURST_HEAT := 0.6
const GULPS_NEEDED := 4
const GULP_POINTS := 10
const BLOOM_POINTS := 30
const BONK_POINTS := 5
## A bruised seedling loses this much, and a thirsty one forgets its gulps.
const BRUISE_POINTS := 20
const DROOP_SECONDS := 2.0
const DENT_SECONDS := 4.0
const MAX_DENTS := 3

## The cap's centre, 0..1.
var cap_x := 0.5
## Falling things: {kind ("rain" or "hail"), x, born, fall, drift, state, at};
## state is "falling", "caught", "splash", "bonk", "ground" or "hit".
var drops: Array[Dictionary] = []
## Per pot: {gulps, blooms, droop_at, thirsty}.
var pots: Array[Dictionary] = []
var thirsty := 0
var thirsty_at := 0.0
var dents: Array[float] = []
var blooms := 0
var gulps := 0
var bonks := 0
var droops := 0

var _rain_due := 0.0
var _hail_due := 0.0
var _burst_left := 0
var _demo := false


func _init() -> void:
	verb = "撐著蘑菇傘，替口渴的幼苗接雨！"
	hint = [["← →", "移動蘑菇傘"]]
	round_seconds = 45.0
	thresholds = [150, 340, 520]
	verdicts = [
		"幼苗們決定集體改種仙人掌。",
		"銅牌！苗是活的，傘有點凹。",
		"銀牌！雨水一滴都捨不得浪費。",
		"金牌！你就是溫室的天氣預報。",
	]
	variants = [
		{"id": "drizzle", "label": "溫室小雨"},
		{"id": "wind", "label": "斜風細雨", "wind": true},
		{"id": "hail", "label": "冰雹陣", "hail": true},
	]
	score_label = "撐傘得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	cap_x = 0.5
	drops.clear()
	pots.clear()
	for index in POTS.size():
		pots.append({"gulps": 0, "blooms": 0, "droop_at": -99.0})
	dents.clear()
	blooms = 0
	gulps = 0
	bonks = 0
	droops = 0
	_rain_due = 0.0
	_hail_due = 1.0
	_burst_left = 0
	_demo = true
	thirsty = 1
	thirsty_at = clock


func _warm_up(delta: float) -> void:
	# The countdown carries the cap over to the thirsty seedling and catches a little rain.
	var target := POTS[thirsty]
	cap_x = move_toward(cap_x, target, SPEED * delta)
	_rain(delta, 0.3)
	_fall()


func _go() -> void:
	_demo = false
	drops.clear()
	for pot in pots:
		pot.gulps = 0
	_rain_due = clock
	_hail_due = clock + (0.8 if bool(variant.get("hail", false)) else 0.0)


func _tick(delta: float) -> void:
	var push := 0.0
	if _held.values().has(&"left"):
		push -= 1.0
	if _held.values().has(&"right"):
		push += 1.0
	cap_x = clampf(cap_x + push * SPEED * delta, CAP_HALF * 0.5, 1.0 - CAP_HALF * 0.5)
	_rain(delta, lerpf(RAIN_GAP_FIRST, RAIN_GAP_LAST, heat()))
	_hail()
	_fall()
	var aged: Array[float] = []
	for dent in dents:
		if clock - dent < DENT_SECONDS:
			aged.append(dent)
	dents = aged


func _snapshot(into: Dictionary) -> void:
	into.cap_x = cap_x
	into.cap_y = CAP_Y
	into.cap_half = cap_half()
	into.drops = drops
	into.pots = pots
	into.pot_xs = POTS
	into.thirsty = thirsty
	into.thirsty_at = thirsty_at
	into.gulps_needed = GULPS_NEEDED
	into.dents = dents.size()
	into.dent_at = dents.back() if not dents.is_empty() else -99.0
	into.droop_seconds = DROOP_SECONDS


## The cap is a little wider with assist.
func cap_half() -> float:
	return CAP_HALF * (1.3 if assisted else 1.0)


## Height (0 roof .. 1 soil) of a falling drop now.
func drop_y(drop: Dictionary) -> float:
	return clampf((clock - float(drop.born)) / float(drop.fall), 0.0, 1.0)


func _rain(_delta: float, gap: float) -> void:
	while clock >= _rain_due:
		_rain_due += gap * rng.randf_range(0.6, 1.4)
		var drift := 0.0
		if bool(variant.get("wind", false)):
			drift = 0.18 * (1.0 if sin(clock * 0.4) >= 0.0 else -1.0)
		_spawn("rain", rng.randf_range(SPAWN_LEFT, SPAWN_RIGHT), RAIN_FALL, drift)


func _hail() -> void:
	var storm := bool(variant.get("hail", false))
	if not storm and heat() < HAIL_HEAT:
		_hail_due = maxf(_hail_due, clock + 0.5)
		return
	if clock < _hail_due:
		return
	var gap := lerpf(HAIL_GAP_FIRST, HAIL_GAP_LAST, heat()) * (0.75 if storm else 1.0)
	if _burst_left > 0:
		_burst_left -= 1
		_hail_due = clock + 0.28
	else:
		_hail_due = clock + gap * rng.randf_range(0.8, 1.2)
		if heat() >= BURST_HEAT and rng.randf() < 0.35:
			_burst_left = 2
	# Most hail aims at a seedling; it is the seedlings it is a danger to.
	var aim := rng.randf_range(SPAWN_LEFT, SPAWN_RIGHT)
	if rng.randf() < 0.75:
		aim = POTS[rng.randi() % POTS.size()] + rng.randf_range(-0.02, 0.02)
	_spawn("hail", aim, window(HAIL_FALL), 0.0)


func _spawn(kind: String, x: float, fall: float, drift: float) -> void:
	# Wind carries a drop sideways; aim it so it still lands inside the room.
	var start := clampf(x - drift, 0.03, 0.97)
	drops.append({"kind": kind, "x": start, "start": start, "born": clock, "fall": fall, "drift": drift, "state": "falling", "at": -99.0})


## Move every drop; settle the ones that reach the cap or the soil.
func _fall() -> void:
	var kept: Array[Dictionary] = []
	for drop in drops:
		var y := drop_y(drop)
		if str(drop.state) == "falling":
			drop.x = float(drop.start) + float(drop.drift) * y
			var crossed := y >= CAP_Y and float(drop.get("checked", 0.0)) < 1.0
			if crossed:
				drop.checked = 1.0
				if absf(float(drop.x) - cap_x) <= cap_half():
					_on_cap(drop)
			if str(drop.state) == "falling" and y >= 1.0:
				_on_soil(drop)
		# Settled drops stay a moment for their splash, then go.
		if str(drop.state) == "falling" or clock - float(drop.at) < 0.6:
			kept.append(drop)
	drops.assign(kept)


func _on_cap(drop: Dictionary) -> void:
	drop.at = clock
	if str(drop.kind) == "hail":
		drop.state = "bonk"
		bonks += 1
		dents.append(clock)
		if dents.size() > MAX_DENTS:
			dents.pop_front()
		sound(52)
		if not _demo:
			add_score(BONK_POINTS, "咚！")
		return
	var over := _pot_under(cap_x, DRIP_REACH)
	if over == thirsty:
		drop.state = "caught"
		sound(79 + pots[over].gulps * 2)
		if _demo:
			return
		gulps += 1
		pots[over].gulps += 1
		add_score(GULP_POINTS)
		if int(pots[over].gulps) >= GULPS_NEEDED:
			_bloom(over)
	else:
		drop.state = "splash"


func _on_soil(drop: Dictionary) -> void:
	drop.at = clock
	drop.state = "ground"
	if str(drop.kind) != "hail":
		return
	var struck := _pot_under(float(drop.x), POT_HALF + 0.015)
	if struck < 0:
		sound(55)
		return
	drop.state = "hit"
	pots[struck].droop_at = clock
	sound(45)
	if _demo:
		return
	droops += 1
	pots[struck].gulps = 0
	add_score(-BRUISE_POINTS)
	# The first bruised seedling of a round is a free look at the sulk.
	funny_fail("嗚…", droops > 1)


func _bloom(index: int) -> void:
	blooms += 1
	pots[index].blooms += 1
	pots[index].gulps = 0
	add_score(BLOOM_POINTS, "咕嚕！+%d" % BLOOM_POINTS)
	sound(88)
	# The next thirsty seedling is always a different one.
	var next := (index + 1 + rng.randi() % (POTS.size() - 1)) % POTS.size()
	thirsty = next
	thirsty_at = clock


## The pot whose centre is within `reach` of `x`, or -1.
func _pot_under(x: float, reach: float) -> int:
	for index in POTS.size():
		if absf(x - POTS[index]) <= reach:
			return index
	return -1
