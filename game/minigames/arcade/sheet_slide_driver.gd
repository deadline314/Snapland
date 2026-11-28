extends "res://game/minigames/arcade/arcade_driver.gd"
## 被單滑梯: the traveller rides a sheet corner down a long bedsheet slide that
## runs from the hotel hall down into the night. Hold ← or → to lean across
## it: scoop up the pillows lying on it and miss the sleeping cats. Later cats
## roll over into your line (a tail flick first), blanket forts split the
## slide into two lanes, and the slide gets steeper and faster. Hit a cat or a
## fort and the sheet wraps the traveller into a spring roll that rolls all
## the way down to the bottom. Rules only: the picture lives in sheet_slide_view.gd.
##
## `x` runs across the slide from -1 (left hem) to 1 (right hem); distances run
## down the slide in slide units.

const View = preload("res://game/minigames/arcade/sheet_slide_view.gd")
## Slide speed (units a second) at the start and the end of play.
const SPEED_FIRST := 4.6
const SPEED_LAST := 9.2
## Sideways leaning: top speed (units a second) and how fast it answers.
const STEER := 1.9
const STEER_RESPONSE := 10.0
const EDGE := 0.84
const HERO := 0.1
const CAT := 0.13
const PILLOW := 0.07
## A fort's half-width and length.
const FORT := 0.3
const FORT_LENGTH := 3.0
## Seconds between things on the slide early and late.
const GAP_FIRST := 1.15
const GAP_LAST := 0.62
## A rolling cat flicks its tail, then rolls this far over this long once the
## traveller is this many seconds away.
const ROLL_LEAD := 0.95
const ROLL_SECONDS := 0.38
const ROLL_SHIFT := 0.45
const ROLL_HEAT := 0.25
const FORT_HEAT := 0.3
const WRAP_SECONDS := 1.8
## Planned this far ahead, in slide units.
const AHEAD := 16.0
const PILLOW_POINTS := 15
const STREAK_POINTS := 2
const STREAK_CAP := 10
## How far into the slide play starts the first thing.
const FIRST_LEAD := 1.5

var distance := 0.0
var hero_x := 0.0
var drift := 0.0
## Things on the slide, nearest first: {kind ("cat"/"roller"/"pillow"/"fort"),
## at, x, to (a roller's x after rolling), roll_at, hit, taken, missed (a pillow
## ridden past)}.
var things: Array[Dictionary] = []
var wrap_at := -99.0
var wrap_x := 0.0
var pillows := 0
var streak := 0
var crashes := 0
var _left := 0
var _right := 0
var _demo := false
var _steered := false
var _side := 1.0


func _init() -> void:
	verb = "左右傾身撿枕頭，閃過睡著的貓！"
	hint = [["← →", "左右傾身"]]
	round_seconds = 45.0
	thresholds = [600, 1500, 2400]
	verdicts = [
		"你是今晚最大條的春捲。",
		"銅牌！滑得歪歪扭扭，總算抱到幾個枕頭。",
		"銀牌！枕頭堆得比貓還高。",
		"金牌！連貓都沒被你吵醒。",
	]
	variants = [
		{"id": "standard", "label": "長長被單"},
		{"id": "cats", "label": "貓咪午睡會", "cats": 0.62, "roll_heat": 0.1},
		{"id": "forts", "label": "棉被堡迷宮", "forts": 0.3, "fort_heat": 0.12},
	]
	score_label = "枕頭得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_steered = false
	_demo = true
	_reset_slide()


## The countdown slides on and leans round the first cat by itself.
func _warm_up(delta: float) -> void:
	var aim := 0.0
	for thing in things:
		if float(thing.at) > distance and str(thing.kind) in ["cat", "roller"]:
			aim = -0.5 if float(thing.x) >= 0.0 else 0.5
			break
	_steer(delta, signi(roundi((aim - hero_x) * 10.0)))
	_slide(delta)


func _go() -> void:
	_demo = false
	_reset_slide()


func _tick(delta: float) -> void:
	_steer(delta, _right - _left if _right != _left else 0)
	_slide(delta)


func _press(button: StringName) -> void:
	if button == &"left" or button == &"right":
		_steered = true
	if button == &"left":
		_left += 1
	elif button == &"right":
		_right += 1


func _release(button: StringName) -> void:
	if button == &"left":
		_left = maxi(0, _left - 1)
	elif button == &"right":
		_right = maxi(0, _right - 1)


## No input, no points: a pillow that happens to lie in the way of a
## traveller nobody steers scores nothing.
func add_score(points: int, word := "") -> void:
	if _steered:
		super(points, word)


func _round_over() -> void:
	_left = 0
	_right = 0


func _snapshot(into: Dictionary) -> void:
	into.distance = distance
	into.speed = speed()
	into.hero_x = hero_x
	into.drift = drift
	into.things = things
	into.wrap_at = wrap_at
	into.wrap_x = wrap_x
	into.wrap_seconds = WRAP_SECONDS
	into.roll_seconds = ROLL_SECONDS
	into.roll_lead = ROLL_LEAD
	into.fort = FORT
	into.fort_length = FORT_LENGTH
	into.streak = streak
	into.edge = EDGE


func speed() -> float:
	return pace(lerpf(SPEED_FIRST, SPEED_LAST, heat()))


func wrapped() -> bool:
	return clock - wrap_at < WRAP_SECONDS


## Where a thing stands across the slide right now (rolling cats move).
func thing_x(thing: Dictionary) -> float:
	if str(thing.kind) != "roller" or float(thing.roll_at) < 0.0:
		return float(thing.x)
	var t := clampf((clock - float(thing.roll_at)) / ROLL_SECONDS, 0.0, 1.0)
	return lerpf(float(thing.x), float(thing.to), t * t * (3.0 - 2.0 * t))


func _steer(delta: float, side: int) -> void:
	if wrapped():
		drift = 0.0
		return
	drift = lerpf(drift, STEER * side, 1.0 - exp(-STEER_RESPONSE * delta))
	hero_x = clampf(hero_x + drift * delta, -EDGE, EDGE)


func _slide(delta: float) -> void:
	if wrapped():
		return
	var before := distance
	distance += speed() * delta
	for thing in things:
		var at := float(thing.at)
		if str(thing.kind) == "roller" and float(thing.roll_at) < 0.0 and (at - distance) / speed() <= ROLL_LEAD:
			# Roll toward the traveller's side of the cat.
			thing.roll_at = clock
			var toward := signf(hero_x - float(thing.x)) if absf(hero_x - float(thing.x)) > 0.02 else _side
			thing.to = clampf(float(thing.x) + toward * ROLL_SHIFT, -0.7, 0.7)
			sound(58)
		if bool(thing.taken) or bool(thing.hit):
			continue
		match str(thing.kind):
			"pillow":
				if before < at and distance >= at:
					if absf(hero_x - float(thing.x)) < HERO + PILLOW:
						_take(thing)
					else:
						# A pillow left behind ends the run of pillows.
						thing.taken = true
						thing.missed = true
						streak = 0
			"cat", "roller":
				if before < at and distance >= at and absf(hero_x - thing_x(thing)) < HERO + CAT:
					_crash(thing)
					return
			"fort":
				if distance >= at and before < at + FORT_LENGTH and absf(hero_x - float(thing.x)) < HERO + FORT:
					_crash(thing)
					return
	while not things.is_empty() and float(things[0].at) + (FORT_LENGTH if str(things[0].kind) == "fort" else 0.0) < distance - 2.0:
		things.pop_front()
	_plan()


func _take(thing: Dictionary) -> void:
	thing.taken = true
	streak += 1
	sound(76 + mini(streak, 12))
	if _demo:
		return
	pillows += 1
	add_score(PILLOW_POINTS + mini(streak, STREAK_CAP) * STREAK_POINTS)


func _crash(thing: Dictionary) -> void:
	thing.hit = true
	wrap_at = clock
	wrap_x = hero_x
	streak = 0
	drift = 0.0
	sound(48)
	sound(41)
	# The traveller comes back in the middle; clear the slide just ahead.
	var landing := distance
	for other in things:
		var at := float(other.at)
		if at > landing and at < landing + speed() * 1.2:
			other.taken = true
	hero_x = 0.0
	if _demo:
		return
	crashes += 1
	# The first spring roll of a round is a free look.
	funny_fail("捲成春捲了！", crashes > 1)


func _reset_slide() -> void:
	things.clear()
	distance = 0.0
	hero_x = 0.0
	drift = 0.0
	wrap_at = -99.0
	pillows = 0
	streak = 0
	crashes = 0
	_left = 0
	_right = 0
	_side = -1.0 if rng.randf() < 0.5 else 1.0
	# A cat right down the middle first: a traveller left alone runs into it,
	# with pillows round one side to show the way.
	var at := speed() * FIRST_LEAD
	things.append(_thing("cat", at, 0.0))
	for index in 3:
		things.append(_thing("pillow", at - 0.6 + index * 0.6, _side * 0.5))
	_plan()


## Plan things out to AHEAD: gaps shrink with heat; rolling cats and forts
## join once the round warms up. Every group leaves a way through.
func _plan() -> void:
	var last := 0.0
	for thing in things:
		last = maxf(last, float(thing.at) + (FORT_LENGTH if str(thing.kind) == "fort" else 0.0))
	while last < distance + AHEAD:
		var gap := lerpf(GAP_FIRST, GAP_LAST, heat()) * rng.randf_range(0.85, 1.2) * speed()
		var at := last + gap
		var roll := not _demo and heat() >= float(variant.get("roll_heat", ROLL_HEAT))
		var fort := not _demo and heat() >= float(variant.get("fort_heat", FORT_HEAT))
		var pick := rng.randf()
		if fort and pick < float(variant.get("forts", 0.16)):
			# A blanket fort down the middle with pillows down one lane.
			things.append(_thing("fort", at, 0.0))
			var lane := -1.0 if rng.randf() < 0.5 else 1.0
			for index in 4:
				things.append(_thing("pillow", at + 0.4 + index * 0.7, lane * 0.58))
			last = at + FORT_LENGTH
			continue
		var x := rng.randf_range(-0.6, 0.6)
		if pick < float(variant.get("cats", 0.45)) + (0.16 if fort else 0.0):
			var kind := "roller" if roll and rng.randf() < 0.45 else "cat"
			things.append(_thing(kind, at, x))
			# Pillows curve round the open side of the cat.
			var side := -1.0 if x > 0.0 else 1.0
			for index in 3:
				things.append(_thing("pillow", at - 0.7 + index * 0.7, clampf(x + side * (0.42 + 0.06 * (1 - absi(index - 1))), -0.75, 0.75)))
		else:
			# A gentle line of pillows across the slide.
			var to := clampf(x + rng.randf_range(-0.5, 0.5), -0.7, 0.7)
			for index in 4:
				things.append(_thing("pillow", at + index * 0.6, lerpf(x, to, index / 3.0)))
			at += 1.8
		last = at


func _thing(kind: String, at: float, x: float) -> Dictionary:
	return {"kind": kind, "at": at, "x": x, "to": x, "roll_at": -99.0, "hit": false, "taken": false, "missed": false}
