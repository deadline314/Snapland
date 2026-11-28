extends "res://game/minigames/arcade/arcade_driver.gd"
## 骰塔改道: a numbered die drops into the top of a wooden dice tower. Hold ← or
## → to tip the tower and the die drifts that way as it tumbles down; it shoots
## out of the mouth at the bottom onto a felt tray of five cups marked one to
## five. Land it in the cup with its own number. Springs on the walls kick it
## back across, a spinning flapper swats it, and later two dice fall at once.
## A die that misses bounces out of the tray and bonks the traveller, leaving a
## pip printed on their forehead.
## Rules only: the picture lives in dice_tower_view.gd.
##
## Inside the shaft x runs 0 (left wall) to 1 (right wall) and y 0 (top) to 1
## (the mouth); on the tray x runs 0 to 1 across the five cups.

const View = preload("res://game/minigames/arcade/dice_tower_view.gd")
const CUPS := 5
## Half a die, in shaft widths; it keeps the chunky dice off the walls.
const RADIUS := 0.13
## Tip rate toward a held side and back to upright, per second.
const TILT_RATE := 4.0
## How fast a die slides sideways at full tip, shaft widths per second.
const DRIFT := 0.55
## A spring's or the flapper's kick fades this fast, per second.
const KICK_FADE := 4.0
const WALL_BOUNCE := 0.5
## How far the mouth throws a die across the tray.
const SPREAD := 1.8
## Seconds a die takes to fall through the tower, early and late in the round.
const FALL_FIRST := 1.7
const FALL_LAST := 1.0
const ROLL_SECONDS := 0.35
const NEXT_SECONDS := 0.45
const BONK_SECONDS := 1.2
## Half the width of a cup's mouth, in tray units.
const CUP_REACH := 0.08
const CENTRE_REACH := 0.035
const CUP_POINTS := 20
const CENTRE_POINTS := 10
const STREAK_POINTS := 3
const STREAK_CAP := 5
const SPRING_KICK := 1.4
const SPRING_REACH := 0.28
const FLAPPER_Y := 0.55
const FLAPPER_SPIN := 2.4
const FLAPPER_PUSH := 0.9
const SPRINGS_HEAT := 0.25
const FLAPPER_HEAT := 0.4
const PAIRS_HEAT := 0.6

## How far the tower is tipped, -1 (left) .. 1 (right).
var tilt := 0.0
## Dice in play: {id, pips, x, y, vx (the fading kick), state ("fall", "roll", "cup", "bonk"),
## at, tray_x, cup, centre, kicked (spring ids already used), swatted}.
var dice: Array[Dictionary] = []
## Springs on the walls: {id, y, side}.
var springs: Array[Dictionary] = []
var flapper := false
var flapper_phase := 0.0
var cupped := 0
var bonks := 0
var streak := 0
var best_streak := 0
var bonk_at := -99.0
var bonk_pips := 0

var _next_drop := 0.0
var _serial := 0
var _demo := false


func _init() -> void:
	verb = "傾斜骰塔，把骰子送進同點數的杯子！"
	hint = [["← →", "傾斜骰塔"]]
	round_seconds = 45.0
	thresholds = [400, 850, 1000]
	verdicts = [
		"骰子們決定自己擲自己。",
		"銅牌！大部分骰子都找到家了。",
		"銀牌！賭場想請你去當荷官。",
		"金牌！你根本就是骰子的指揮家。",
	]
	variants = [
		{"id": "standard", "label": "標準骰塔"},
		{"id": "springy", "label": "彈簧骰塔", "springs": true},
		{"id": "twins", "label": "雙骰日", "pairs": true},
	]
	score_label = "進杯得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	tilt = 0.0
	dice.clear()
	springs.clear()
	flapper = false
	flapper_phase = 0.0
	cupped = 0
	bonks = 0
	streak = 0
	best_streak = 0
	bonk_at = -99.0
	bonk_pips = 0
	_serial = 0
	_demo = true
	# The countdown tips the tower to land a die marked four in cup four.
	_drop(4, 0.5)


func _warm_up(delta: float) -> void:
	var lean := 0.0
	for die in dice:
		if str(die.state) == "fall":
			var error := _goal_x(die) - float(die.x) - tilt * DRIFT * 0.12
			lean = signf(error) if absf(error) > 0.008 else 0.0
	_tip(lean, delta)
	_move(delta * 1.3)


func _go() -> void:
	_demo = false
	dice.clear()
	tilt = 0.0
	streak = 0
	if bool(variant.get("springs", false)):
		_add_springs()
	_next_drop = clock + 0.3


func _tick(delta: float) -> void:
	var lean := 0.0
	if _held.values().has(&"left"):
		lean -= 1.0
	if _held.values().has(&"right"):
		lean += 1.0
	_tip(lean, delta)
	if springs.is_empty() and heat() >= SPRINGS_HEAT:
		_add_springs()
	flapper = flapper or heat() >= FLAPPER_HEAT
	if flapper:
		flapper_phase = fposmod(flapper_phase + FLAPPER_SPIN * delta, TAU)
	_move(delta)
	if clock >= _next_drop and not dice.any(func(die: Dictionary) -> bool: return str(die.state) == "fall"):
		_drop_next()


func _snapshot(into: Dictionary) -> void:
	into.tilt = tilt
	into.dice = dice
	into.springs = springs
	into.flapper = flapper
	into.flapper_phase = flapper_phase
	into.flapper_y = FLAPPER_Y
	into.cups = CUPS
	into.radius = RADIUS
	into.streak = streak
	into.bonk_at = bonk_at
	into.bonk_pips = bonk_pips
	into.bonk_seconds = BONK_SECONDS
	into.roll_seconds = ROLL_SECONDS


func fall_seconds() -> float:
	# Assist slows the fall a little; much slower would only mean fewer dice.
	return lerpf(FALL_FIRST, FALL_LAST, heat()) * (1.15 if assisted else 1.0)


## Tray position of cup `pips` (1..5).
func cup_x(pips: int) -> float:
	return (pips - 0.5) / CUPS


## Where a die would land on the tray if it left the mouth now.
func tray_x(die: Dictionary) -> float:
	return clampf(0.5 + (float(die.x) - 0.5) * SPREAD, 0.0, 1.0)


func cup_reach() -> float:
	return CUP_REACH * (1.25 if assisted else 1.0)


func _tip(lean: float, delta: float) -> void:
	tilt = move_toward(tilt, lean, TILT_RATE * delta)


## The shaft position that would carry `die` into its own cup, ignoring momentum.
func _goal_x(die: Dictionary) -> float:
	return 0.5 + (cup_x(int(die.pips)) - 0.5) / SPREAD


func _drop_next() -> void:
	var pairs := bool(variant.get("pairs", false)) and heat() >= SPRINGS_HEAT or heat() >= PAIRS_HEAT
	if pairs and rng.randf() < 0.6:
		# Two dice side by side, far enough apart in number that one tip of the
		# tower can carry both: the left one always wants the lower cup.
		var low := rng.randi_range(1, 2)
		var high := rng.randi_range(low + 3, CUPS)
		_drop(low, 0.3)
		_drop(high, 0.7)
	else:
		_drop(rng.randi_range(1, CUPS), rng.randf_range(0.25, 0.75))
	_next_drop = clock + NEXT_SECONDS


func _drop(pips: int, x: float) -> void:
	_serial += 1
	dice.append({"id": _serial, "pips": pips, "x": x, "y": 0.0, "vx": 0.0, "state": "fall", "at": clock,
		"tray_x": 0.5, "cup": -1, "centre": false, "kicked": [], "swatted": false})
	sound(60)


func _add_springs() -> void:
	springs.clear()
	springs.append({"id": 1, "y": 0.32, "side": -1 if rng.randf() < 0.5 else 1})
	springs.append({"id": 2, "y": 0.78, "side": -int(springs[0].side)})


func _move(delta: float) -> void:
	var fall := fall_seconds()
	for die in dice:
		match str(die.state):
			"fall":
				var was_y := float(die.y)
				die.y = was_y + delta / fall
				# Tipping slides the die steadily; a kick fades away on its own.
				die.x = float(die.x) + (tilt * DRIFT + float(die.vx)) * delta
				die.vx = float(die.vx) * (1.0 - minf(1.0, KICK_FADE * delta))
				if float(die.x) < RADIUS:
					die.x = RADIUS
					die.vx = absf(float(die.vx)) * WALL_BOUNCE
				elif float(die.x) > 1.0 - RADIUS:
					die.x = 1.0 - RADIUS
					die.vx = -absf(float(die.vx)) * WALL_BOUNCE
				_springs_and_flapper(die, was_y)
				if float(die.y) >= 1.0:
					_leave_mouth(die)
			"roll":
				if clock - float(die.at) >= ROLL_SECONDS:
					_land(die)
	var kept: Array[Dictionary] = []
	for die in dice:
		if str(die.state) in ["fall", "roll"] or clock - float(die.at) < BONK_SECONDS:
			kept.append(die)
	dice.assign(kept)


func _springs_and_flapper(die: Dictionary, was_y: float) -> void:
	for spring in springs:
		var y := float(spring.y)
		if was_y < y and float(die.y) >= y:
			var wall := 0.0 if int(spring.side) < 0 else 1.0
			if absf(float(die.x) - wall) <= SPRING_REACH:
				die.vx = -float(spring.side) * SPRING_KICK
				(die.kicked as Array).append(spring.id)
				sound(81)
	if flapper and was_y < FLAPPER_Y and float(die.y) >= FLAPPER_Y and not bool(die.swatted):
		die.swatted = true
		die.vx = float(die.vx) + sin(flapper_phase) * FLAPPER_PUSH
		sound(66)


func _leave_mouth(die: Dictionary) -> void:
	die.y = 1.0
	die.tray_x = tray_x(die)
	die.state = "roll"
	die.at = clock
	sound(55)


func _land(die: Dictionary) -> void:
	var at := float(die.tray_x)
	var cup := clampi(int(at * CUPS) + 1, 1, CUPS)
	var near := absf(at - cup_x(cup)) <= cup_reach()
	die.at = clock
	if near and cup == int(die.pips):
		die.state = "cup"
		die.cup = cup
		die.centre = absf(at - cup_x(cup)) <= CENTRE_REACH
		sound(72 + cup * 2)
		if _demo or not touched:
			return
		cupped += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		var points := CUP_POINTS + (CENTRE_POINTS if bool(die.centre) else 0) + STREAK_POINTS * mini(streak, STREAK_CAP)
		add_score(points, ("正中！+%d" if bool(die.centre) else "進杯！+%d") % points)
		return
	# Wrong cup or the rim: it bounces out and bonks the traveller.
	die.state = "bonk"
	die.cup = cup if near else -1
	sound(48)
	sound(84)
	if _demo:
		return
	bonks += 1
	streak = 0
	bonk_at = clock
	bonk_pips = int(die.pips)
	# The first bonk of a round is a free look at the forehead print.
	funny_fail("咚！", bonks > 1)
