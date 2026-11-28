extends "res://game/minigames/arcade/arcade_driver.gd"
## 葉舟搬家: the traveller sits in a curled leaf boat on a greenhouse stream,
## seen from above, with the stream running up the screen. ← and → are paddle
## strokes: each one veers the leaf that way and gives it a push, so
## alternating strokes run straight and fast. Ants stranded on floating petals
## climb aboard when the leaf brushes them. Mossy rocks and, later, whirlpools
## stand in the way; now and then the stream forks round an island, and the
## narrow branch is crowded with ants. Hit a rock or get sucked into a
## whirlpool's eye and the leaf flips: a column of ants carries the soaked
## traveller off to the bank on their heads.
## Rules only: the picture lives in leaf_boat_view.gd.
##
## x runs 0..1 across the screen; y is distance along the stream in screen
## heights, growing upstream; `travel` is how far the leaf has come.

const View = preload("res://game/minigames/arcade/leaf_boat_view.gd")
## Screen height fraction from the top where the leaf sits.
const BOAT_SCREEN := 0.74
## Screen widths per screen height, for round hit tests.
const ASPECT := 1280.0 / 720.0
const CURRENT_FIRST := 0.2
const CURRENT_LAST := 0.42
const STROKE := 0.32
const STROKE_PUSH := 0.12
const PUSH_MAX := 0.26
const SIDE_DAMP := 2.6
const PUSH_DAMP := 1.4
## Hit sizes in screen heights.
const BOAT_REACH := 0.06
const ROCK_REACH := 0.05
const ANT_REACH := 0.07
const WHIRL_PULL := 3.0
const WHIRL_REACH := 0.22
const WHIRL_EYE := 0.05
## The leaf's half width across, in screen widths, for the banks.
const HULL := BOAT_REACH / ASPECT
const WHIRL_HEAT := 0.3
const ANT_POINTS := 10
const STREAK_POINTS := 5
const STREAK_CAP := 4
const STREAK_GAP := 1.6
const FLIP_SECONDS := 2.0
## Screens between planned rows of things, early and late.
const GAP_FIRST := 0.42
const GAP_LAST := 0.28
const FORK_EVERY := 3.2
const FORK_LENGTH := 1.1
## How far ahead of the leaf things are planned, in screen heights.
const AHEAD := 1.4

var x := 0.5
var vx := 0.0
var push := 0.0
var travel := 0.0
## Planned things: {kind ("rock", "ants", "whirl"), x, y, count, taken_at}.
var things: Array[Dictionary] = []
## Forks: {y0, y1, island_left, island_right} (island spans x between).
var forks: Array[Dictionary] = []
## The last capsize: {at, x, why}.
var flip: Dictionary = {}
var ants := 0
var flips := 0
var streak := 0
var last_stroke := 0.0
## -1 left, 1 right, 0 none: the side of the latest stroke (for the paddle).
var stroke_side := 0

var _next_y := 0.0
var _next_fork := 0.0
var _last_ants := -99.0
var _demo := false


func _init() -> void:
	verb = "← → 交替划槳，載螞蟻順著溪流走！"
	hint = [["← →", "划槳"]]
	round_seconds = 45.0
	thresholds = [250, 550, 800]
	verdicts = [
		"螞蟻們決定自己游回家。",
		"銅牌！有幾隻螞蟻搭上便船。",
		"銀牌！整片葉子擠滿了開心的螞蟻。",
		"金牌！螞蟻王國封你為葉舟船長。",
	]
	variants = [
		{"id": "standard", "label": "晴天溪流"},
		{"id": "rapids", "label": "雨後急流", "current": 1.2, "ants": 1.3},
		{"id": "whirl", "label": "漩渦日", "whirl": true},
	]
	score_label = "載螞蟻得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_stream()
	# The countdown demo: one petal of ants a little ahead and to the left.
	things.append(_thing("ants", 0.36, travel + 0.55, 2))
	_next_y = 99.0
	_next_fork = 99.0


## The countdown paddles over to the demo ants by itself.
func _warm_up(delta: float) -> void:
	if clock > 0.5 and clock - last_stroke > 0.32:
		var target := 0.36 if things.any(func(thing: Dictionary) -> bool: return thing.taken_at < 0.0) else 0.5
		_stroke(-1 if x > target + 0.02 else (1 if x < target - 0.02 else (-stroke_side if stroke_side != 0 else 1)))
	_flow(delta * 0.8)


func _go() -> void:
	# Play starts mid-stream with nothing within the first stretch but one
	# petal of ants straight ahead, so the first stroke is always the player's.
	_demo = false
	_reset_stream()
	things.append(_thing("ants", 0.5, travel + 0.7, 1))


func _tick(delta: float) -> void:
	_flow(delta)


func _press(button: StringName) -> void:
	if busy():
		return
	if button == &"left":
		_stroke(-1)
	elif button == &"right":
		_stroke(1)


## No input, no points.
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _snapshot(into: Dictionary) -> void:
	into.x = x
	into.vx = vx
	into.travel = travel
	into.things = things
	into.forks = forks
	into.flip = flip
	into.flip_seconds = FLIP_SECONDS
	into.ants = ants
	into.boat_screen = BOAT_SCREEN
	into.stroke_side = stroke_side
	into.last_stroke = last_stroke
	into.streak = streak
	into.bank_at = banks
	into.whirl_eye = WHIRL_EYE


func busy() -> bool:
	return not flip.is_empty() and clock - float(flip.at) < FLIP_SECONDS


func current() -> float:
	return pace(lerpf(CURRENT_FIRST, CURRENT_LAST, heat()) * float(variant.get("current", 1.0)))


func rock_reach() -> float:
	return ROCK_REACH / (ASSIST_WINDOW if assisted else 1.0)


## The stream's banks at distance `y`: [left, right] in screen widths.
static func banks(y: float) -> Vector2:
	var sway := 0.08 * sin(y * 2.1) + 0.04 * sin(y * 5.3 + 1.0)
	return Vector2(0.17 + sway, 0.83 + sway)


## The island splitting the stream at distance `y`, or ZERO for none.
func island(y: float) -> Vector2:
	for fork in forks:
		if y >= float(fork.y0) and y <= float(fork.y1):
			var along := (y - float(fork.y0)) / (float(fork.y1) - float(fork.y0))
			var round_off := sin(along * PI)
			var centre := float(fork.centre)
			var half := 0.11 * round_off
			return Vector2(centre - half, centre + half) if half > 0.01 else Vector2.ZERO
	return Vector2.ZERO


func _stroke(side: int) -> void:
	vx += STROKE * side
	# Alternating strokes push hardest; the same side twice mostly turns.
	var alternate := side != stroke_side or clock - last_stroke > 1.0
	push = minf(PUSH_MAX, push + STROKE_PUSH * (1.0 if alternate else 0.35))
	stroke_side = side
	last_stroke = clock
	sound(60 + (2 if side > 0 else 0))


func _flow(delta: float) -> void:
	if busy():
		vx = 0.0
		push = 0.0
		travel += current() * 0.4 * delta
		_plan()
		return
	vx *= exp(-SIDE_DAMP * delta)
	push *= exp(-PUSH_DAMP * delta)
	travel += (current() + push) * delta
	x += vx * delta
	var here := banks(travel)
	if x < here.x + HULL:
		x = here.x + HULL
		vx = absf(vx) * 0.4
	elif x > here.y - HULL:
		x = here.y - HULL
		vx = -absf(vx) * 0.4
	var rock := island(travel)
	if rock != Vector2.ZERO and x > rock.x - HULL and x < rock.y + HULL:
		# Bump off the island to whichever side is nearer.
		if x < (rock.x + rock.y) * 0.5:
			x = rock.x - HULL
			vx = -absf(vx) * 0.4
		else:
			x = rock.y + HULL
			vx = absf(vx) * 0.4
	_meet(delta)
	_plan()


func _meet(delta: float) -> void:
	var boat := Vector2(x * ASPECT, travel)
	for thing in things:
		if float(thing.taken_at) >= 0.0:
			continue
		var at := Vector2(float(thing.x) * ASPECT, float(thing.y))
		var gap := boat.distance_to(at)
		match thing.kind:
			"ants":
				if gap < ANT_REACH + BOAT_REACH:
					_board(thing)
			"rock":
				if gap < rock_reach() + BOAT_REACH:
					_capsize("rock", thing)
					return
			"whirl":
				if gap < WHIRL_REACH:
					# The whirlpool drags the leaf sideways toward its eye.
					var pull := signf(at.x - boat.x) * WHIRL_PULL * (1.0 - gap / WHIRL_REACH)
					vx += pull * delta * (0.6 if assisted else 1.0)
					if gap < WHIRL_EYE:
						_capsize("whirl", thing)
						return


func _board(thing: Dictionary) -> void:
	thing.taken_at = clock
	sound(76 + mini(streak, 6))
	if _demo:
		return
	var count := int(thing.count)
	ants += count
	streak = streak + 1 if clock - _last_ants < STREAK_GAP else 1
	_last_ants = clock
	var points := count * ANT_POINTS + mini(streak - 1, STREAK_CAP) * STREAK_POINTS
	add_score(points, ("螞蟻上船！+%d" % points) if count >= 3 or streak >= 3 else "")


func _capsize(why: String, thing: Dictionary) -> void:
	flip = {"at": clock, "x": x, "why": why}
	streak = 0
	thing.taken_at = clock
	sound(48)
	sound(43)
	if _demo:
		return
	flips += 1
	# The first capsize of a round is a free look at the ants' rescue.
	funny_fail("翻船了！", flips > 1)
	# Clear the stretch ahead so the leaf is not dropped back onto trouble.
	for other in things:
		if other.kind != "ants" and float(other.y) < travel + 0.5 and float(other.taken_at) < 0.0:
			other.taken_at = clock
	x = clampf(0.5, banks(travel).x + 0.1, banks(travel).y - 0.1)


func _plan() -> void:
	while _next_y < travel + AHEAD:
		if _next_fork <= _next_y:
			_fork(_next_y)
			_next_fork = _next_y + FORK_EVERY
			_next_y += FORK_LENGTH + 0.2
			continue
		_row(_next_y)
		_next_y += lerpf(GAP_FIRST, GAP_LAST, heat())
	var kept: Array[Dictionary] = []
	for thing in things:
		if float(thing.y) > travel - 0.4:
			kept.append(thing)
	things.assign(kept)
	var open_forks: Array[Dictionary] = []
	for fork in forks:
		if float(fork.y1) > travel - 0.4:
			open_forks.append(fork)
	forks.assign(open_forks)


## One row across the stream: a petal of ants and maybe a rock or a whirlpool.
func _row(y: float) -> void:
	var edge := banks(y)
	var lane := func(across: float) -> float: return lerpf(edge.x + 0.07, edge.y - 0.07, across)
	var ant_lane: float = lane.call(rng.randf())
	var count := 1 + int(rng.randf() < 0.35 * float(variant.get("ants", 1.0))) + int(rng.randf() < 0.15)
	things.append(_thing("ants", ant_lane, y, count))
	var hazards := 1 if rng.randf() < lerpf(0.45, 0.85, heat()) else 0
	for count_rock in hazards:
		var at: float = lane.call(rng.randf())
		if absf(at - ant_lane) < 0.12:
			at = lane.call(1.0 - (ant_lane - edge.x) / maxf(0.01, edge.y - edge.x))
		var whirl := (heat() >= WHIRL_HEAT or bool(variant.get("whirl", false))) and rng.randf() < 0.35
		things.append(_thing("whirl" if whirl else "rock", at, y + rng.randf_range(0.1, 0.18), 0))


## The stream splits round a long island: the narrow branch is crowded with
## ants and has a rock to thread past; the wide branch is clear but sparse.
func _fork(y: float) -> void:
	var edge := banks(y + FORK_LENGTH * 0.5)
	var narrow_left := rng.randf() < 0.5
	var centre := lerpf(edge.x, edge.y, 0.36 if narrow_left else 0.64)
	forks.append({"y0": y, "y1": y + FORK_LENGTH, "centre": centre})
	var narrow := (edge.x + centre - 0.11) * 0.5 if narrow_left else (centre + 0.11 + edge.y) * 0.5
	var wide := (centre + 0.11 + edge.y) * 0.5 if narrow_left else (edge.x + centre - 0.11) * 0.5
	for step in 3:
		things.append(_thing("ants", narrow, y + 0.25 + step * 0.27, 2 + int(step == 1)))
	things.append(_thing("rock", narrow + (0.03 if narrow_left else -0.03), y + 0.66, 0))
	things.append(_thing("ants", wide, y + 0.55, 1))


func _thing(kind: String, at_x: float, at_y: float, count: int) -> Dictionary:
	return {"kind": kind, "x": at_x, "y": at_y, "count": count, "taken_at": -99.0}


func _reset_stream() -> void:
	x = 0.5
	vx = 0.0
	push = 0.0
	things.clear()
	forks.clear()
	flip = {}
	ants = 0
	flips = 0
	streak = 0
	stroke_side = 0
	last_stroke = -99.0
	_last_ants = -99.0
	_next_y = travel + 0.9
	_next_fork = travel + 2.2
