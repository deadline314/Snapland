extends "res://game/minigames/arcade/arcade_driver.gd"
## 紙盒變車: the traveller sits in a cardboard-box car racing down a course of
## toy-block ramps. Off every kicker the box flies; hold ← to lift its nose or
## → to dip it, and land it flat against the ramp below. A clean landing keeps
## the speed and a perfect one adds to it; a crooked one folds the whole box up
## with the traveller inside, a hand poking out of the crease waving a white
## flag. Ramps get steeper, little hops come in a row and seesaws tip while the
## box is still in the air.
## Rules only: the picture lives in box_kart_view.gd.
##
## Pitch is in radians, positive with the nose down; a landing slope's angle
## is the pitch that sits flat on it.

const View = preload("res://game/minigames/arcade/box_kart_view.gd")
## Radians per second the box turns while ← or → is held.
const TURN := 1.9
## The box keeps tipping nose-down on its own in the air, more late on: left
## alone it lands on its nose.
const DRIFT_FIRST := 0.85
const DRIFT_LAST := 1.3
const PERFECT := 0.12
const GOOD := 0.32
const SPEED_START := 1.0
const SPEED_MAX := 2.0
const PERFECT_GAIN := 0.15
const CRASH_SPEED := 0.8
const FOLD_SECONDS := 1.6
## Seconds of rolling between one landing and the next kicker, at speed 1.
const ROLL_SECONDS := 1.1
const PERFECT_POINTS := 30
const GOOD_POINTS := 15
const STREAK_POINTS := 3
const STREAK_CAP := 5
const HOPS_HEAT := 0.3
const SEESAW_HEAT := 0.5

## "roll" between jumps, "air" while flying, "fold" after a crooked landing.
var phase := "roll"
var phase_at := 0.0
var pitch := 0.0
## The jump in progress: {kind ("ramp", "hop", "seesaw"), launch, land, flip
## (the seesaw's slope after it tips), air (seconds), at}.
var jump: Dictionary = {}
var speed := SPEED_START
## Distance travelled, for the scrolling scenery.
var travelled := 0.0
var landings := 0
var perfects := 0
var folds := 0
var streak := 0
var best_streak := 0
## The last landing: {grade ("perfect", "good", "fold"), off, at}.
var landed: Dictionary = {}
## How many hops are left in a row of little hops.
var hops_left := 0

var _roll_left := 0.0
var _drift := 0.0
var _demo := false


func _init() -> void:
	verb = "在空中調整紙箱車，平平地落在坡道上！"
	hint = [["← →", "抬頭／壓頭"]]
	round_seconds = 45.0
	thresholds = [300, 1000, 1900]
	verdicts = [
		"紙箱決定回去當紙箱。",
		"銅牌！車頂有點凹，人還在裡面。",
		"銀牌！紙箱車看起來比真車還帥。",
		"金牌！快遞公司想請你送貨。",
	]
	variants = [
		{"id": "blocks", "label": "積木坡道"},
		{"id": "steep", "label": "陡坡大會", "steep": 1.3},
		{"id": "seesaw", "label": "蹺蹺板日", "seesaw": true},
	]
	score_label = "落地得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	phase = "roll"
	phase_at = clock
	pitch = 0.0
	jump = {}
	speed = SPEED_START
	travelled = 0.0
	landings = 0
	perfects = 0
	folds = 0
	streak = 0
	best_streak = 0
	landed = {}
	hops_left = 0
	_roll_left = 0.5
	_demo = true


func _warm_up(delta: float) -> void:
	# The countdown flies one jump and steers it down flat by itself.
	var turn := 0.0
	if phase == "air":
		var error := _target() - (pitch + _drift * 0.15)
		turn = signf(error) if absf(error) > 0.04 else 0.0
	_advance(delta, turn)


func _go() -> void:
	_demo = false
	phase = "roll"
	phase_at = clock
	pitch = 0.0
	jump = {}
	speed = SPEED_START
	streak = 0
	_roll_left = 0.4


func _tick(delta: float) -> void:
	var turn := 0.0
	if _held.values().has(&"left"):
		turn -= 1.0
	if _held.values().has(&"right"):
		turn += 1.0
	_advance(delta, turn)


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.pitch = pitch
	into.jump = jump
	into.speed = speed
	into.travelled = travelled
	into.landed = landed
	into.streak = streak
	into.target = _target() if phase == "air" else 0.0
	into.fold_seconds = FOLD_SECONDS
	into.perfect = PERFECT
	into.good = GOOD


func drift() -> float:
	return lerpf(DRIFT_FIRST, DRIFT_LAST, heat())


func good_reach() -> float:
	return window(GOOD)


## The slope the box must match right now: a seesaw tips halfway through the flight.
func _target() -> float:
	if jump.is_empty():
		return 0.0
	if str(jump.kind) == "seesaw" and clock - float(jump.at) >= float(jump.air) * 0.5:
		return float(jump.flip)
	return float(jump.land)


func _advance(delta: float, turn: float) -> void:
	travelled += speed * delta
	match phase:
		"roll":
			pitch = move_toward(pitch, 0.0, 3.0 * delta)
			_roll_left -= delta * speed
			if _roll_left <= 0.0:
				_launch()
		"air":
			pitch += (_drift + turn * TURN) * delta
			if clock - float(jump.at) >= float(jump.air):
				_land()
		"fold":
			if clock - phase_at >= FOLD_SECONDS:
				phase = "roll"
				phase_at = clock
				pitch = 0.0
				_roll_left = ROLL_SECONDS * 0.6


func _launch() -> void:
	var steep := float(variant.get("steep", 1.0)) * lerpf(1.0, 1.45, heat())
	var kind := "ramp"
	if hops_left > 0:
		kind = "hop"
		hops_left -= 1
	elif not _demo and (heat() >= SEESAW_HEAT or bool(variant.get("seesaw", false)) and heat() >= 0.15) and rng.randf() < 0.35:
		kind = "seesaw"
	elif not _demo and heat() >= HOPS_HEAT and rng.randf() < 0.3:
		kind = "hop"
		hops_left = 2
	var launch := -rng.randf_range(0.25, 0.45) * steep
	var land := rng.randf_range(0.15, 0.5) * steep
	var air := rng.randf_range(1.1, 1.5)
	var flip := land
	match kind:
		"hop":
			launch = -0.2
			land = rng.randf_range(0.05, 0.2)
			air = 0.6
		"seesaw":
			# The plank is tipped toward you, then flops the other way mid-flight.
			land = -rng.randf_range(0.15, 0.3)
			flip = rng.randf_range(0.3, 0.5) * steep
			air = rng.randf_range(1.2, 1.5)
	if _demo:
		launch = -0.35
		land = 0.3
		air = 1.0
		flip = land
	jump = {"kind": kind, "launch": launch, "land": land, "flip": flip, "air": window(air) if kind != "hop" else air, "at": clock}
	_drift = drift() * rng.randf_range(0.85, 1.2)
	pitch = launch
	phase = "air"
	phase_at = clock
	sound(64)


func _land() -> void:
	var off := absf(pitch - _target())
	var grade := "perfect" if off <= window(PERFECT) else ("good" if off <= good_reach() else "fold")
	landed = {"grade": grade, "off": off, "at": clock}
	phase_at = clock
	if grade == "fold":
		phase = "fold"
		sound(45)
		sound(52)
		if _demo:
			return
		folds += 1
		streak = 0
		speed = CRASH_SPEED
		# The first fold of a round is a free look at the white flag.
		funny_fail("摺起來了！", folds > 1)
		return
	phase = "roll"
	pitch = _target()
	_roll_left = (ROLL_SECONDS * 0.4 if hops_left > 0 else ROLL_SECONDS)
	sound(72 if grade == "perfect" else 67)
	if _demo or not touched:
		return
	landings += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var points := GOOD_POINTS
	if grade == "perfect":
		perfects += 1
		speed = minf(SPEED_MAX, speed + PERFECT_GAIN)
		points = PERFECT_POINTS
	points = roundi((points + STREAK_POINTS * mini(streak, STREAK_CAP)) * speed)
	add_score(points, ("完美落地！+%d" if grade == "perfect" else "穩穩的！+%d") % points)
