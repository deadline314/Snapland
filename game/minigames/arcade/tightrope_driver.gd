extends "res://game/minigames/arcade/arcade_driver.gd"
## 走鋼索: the clown walks the high wire by himself; the player only keeps him
## upright, holding left or right to swing the balance pole that way. Gusts, a
## pigeon landing on one end of the pole and hats thrown from the audience push
## him over, more often as the round goes on, and late on the wire starts to
## bounce. Lean too far and he flips and hangs upside down from the wire. Rules
## only: the picture lives in tightrope_view.gd.

const View = preload("res://game/minigames/arcade/tightrope_view.gd")
## Screen x of the two platforms the wire runs between.
const WIRE_FROM := 150.0
const WIRE_TO := 1130.0
## Lean in radians: steady below this, falls past that.
const STEADY := 0.14
const FALL_LEAN := 0.85
## How hard a lean pulls further over (per radian), early and late.
const TIP_EARLY := 3.0
const TIP_LATE := 5.0
## What the pole can push back with, and how fast motion dies away.
const CONTROL := 7.0
const DAMPING := 0.8
const WALK_EARLY := 70.0
const WALK_LATE := 115.0
const GAP_EARLY := 3.2
const GAP_LATE := 1.2
const WARNING := 0.8
const GUST_SECONDS := 1.4
const PIGEON_SECONDS := 2.6
const BOUNCE_FROM_HEAT := 0.6
## How hard each step rocks him from side to side.
const SWAY := 0.9
## The spin a thrown hat gives the clown when it hits.
const HAT_KNOCK := 0.9
const FALL_SECONDS := 2.2
const TURN_SECONDS := 0.8
## Ten steady pixels walked are worth two points, wobbly ones a third of one; each crossing pays a bonus.
const PIXELS_PER_POINT := 10.0
const CROSSING_BONUS := 60
const DEMO_STEPS := 140.0

## "walk", "turn" (at a platform, bowing) or "fall" (hanging upside down).
var phase := "walk"
var phase_at := 0.0
var lean := 0.0
var spin := 0.0
## -1, 0 or 1: which way the player is swinging the pole.
var steer := 0
## Position along the wire in screen x and which way he walks.
var walk_x := WIRE_FROM
var heading := 1.0
var crossings := 0
var falls := 0
var steady_time := 0.0
## Upcoming and running pushes: {kind "gust"|"pigeon"|"hat", side -1|1, at, until}.
var events: Array[Dictionary] = []
var bounce := 0.0
var _next_event := 0.0
var _walked := 0.0
var _held_left := false
var _held_right := false


func _init() -> void:
	verb = "按左右撐住平衡桿，讓小丑走過鋼索！"
	hint = [["← →", "往那邊撐住平衡"]]
	round_seconds = 50.0
	thresholds = [350, 650, 950]
	verdicts = [
		"小丑倒吊著看完了整場表演。",
		"銅牌！腳有離開平台，觀眾很捧場。",
		"銀牌！風吹鴿子停都晃不倒你。",
		"金牌！走鋼索像在逛大街。",
	]
	variants = [
		{"id": "standard", "label": "標準鋼索", "gusts": 1.0, "pigeons": 1.0, "hats": 1.0, "bounce": false},
		{"id": "windy", "label": "穿堂風", "gusts": 2.2, "pigeons": 0.5, "hats": 0.6, "bounce": false},
		{"id": "pigeons", "label": "鴿子大會", "gusts": 0.5, "pigeons": 2.5, "hats": 0.6, "bounce": false},
		{"id": "bouncy", "label": "彈簧鋼索", "gusts": 1.0, "pigeons": 1.0, "hats": 1.0, "bounce": true},
	]
	score_label = "鋼索得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	crossings = 0
	falls = 0
	steady_time = 0.0
	_reset_walk()


## The countdown walks a few steps with the pole swaying by itself.
func _warm_up(delta: float) -> void:
	walk_x = minf(WIRE_FROM + DEMO_STEPS, walk_x + WALK_EARLY * delta)
	lean = 0.12 * sin(clock * 2.6)


func _go() -> void:
	_reset_walk()
	_next_event = 2.0


func _tick(delta: float) -> void:
	_update_events()
	bounce = 0.0
	if bool(variant.get("bounce", false)) or heat() >= BOUNCE_FROM_HEAT:
		bounce = sin(clock * 7.0) * (0.5 + 0.7 * heat())
	match phase:
		"walk":
			_balance(delta)
			if phase == "walk":
				_walk(delta)
		"turn":
			if clock - phase_at >= TURN_SECONDS:
				_phase("walk")
		"fall":
			if clock - phase_at >= FALL_SECONDS:
				lean = 0.0
				spin = 0.0
				_phase("walk")


func _press(button: StringName) -> void:
	if button == &"left":
		_held_left = true
	elif button == &"right":
		_held_right = true
	_steer()


func _release(button: StringName) -> void:
	if button == &"left":
		_held_left = false
	elif button == &"right":
		_held_right = false
	_steer()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.lean = lean
	into.steer = steer
	into.walk_x = walk_x
	into.heading = heading
	into.events = events
	into.bounce = bounce
	into.crossings = crossings
	into.fall_lean = FALL_LEAN
	into.steady = STEADY
	into.wire_from = WIRE_FROM
	into.wire_to = WIRE_TO


## The sum of every push acting now, in radians per second squared.
func push() -> float:
	var total := 0.0
	for event in events:
		if clock < float(event.at) or clock >= float(event.until):
			continue
		match str(event.kind):
			"gust":
				total += float(event.side) * lerpf(1.3, 2.4, heat())
			"pigeon":
				total += float(event.side) * 1.7
	# Every step rocks him a little, so he never simply stands still.
	total += SWAY * sin(walk_x * 0.09)
	return pace(total + bounce)


func tip() -> float:
	return pace(lerpf(TIP_EARLY, TIP_LATE, heat()))


func walk_speed() -> float:
	return lerpf(WALK_EARLY, WALK_LATE, heat())


func _balance(delta: float) -> void:
	spin += (tip() * lean + push() + float(steer) * CONTROL) * delta
	spin -= spin * minf(1.0, DAMPING * delta)
	lean += spin * delta
	if absf(lean) >= FALL_LEAN:
		_fall()


func _walk(delta: float) -> void:
	var step := walk_speed() * delta
	walk_x += heading * step
	var steady := absf(lean) < STEADY
	if steady:
		steady_time += delta
	_walked += step * (2.0 if steady else 0.3)
	var points := floori(_walked / PIXELS_PER_POINT)
	# He walks by himself, but a walk nobody has steered earns nothing.
	if points > 0 and not touched:
		_walked -= points * PIXELS_PER_POINT
		points = 0
	if points > 0:
		_walked -= points * PIXELS_PER_POINT
		add_score(points)
	if (heading > 0.0 and walk_x >= WIRE_TO) or (heading < 0.0 and walk_x <= WIRE_FROM):
		walk_x = clampf(walk_x, WIRE_FROM, WIRE_TO)
		heading = -heading
		crossings += 1
		if touched:
			add_score(CROSSING_BONUS, "走到了！+%d" % CROSSING_BONUS)
		sound(84)
		spin = 0.0
		lean *= 0.3
		_phase("turn")


func _fall() -> void:
	falls += 1
	sound(41)
	# The first fall of a round is a free look at the upside-down clown.
	funny_fail("倒吊了！", falls > 1)
	lean = signf(lean) * FALL_LEAN
	spin = 0.0
	_walked = 0.0
	_phase("fall")


## Schedule the next push with a warning; drop ones that have run out.
func _update_events() -> void:
	for event in events.duplicate():
		if event.kind == "hat" and not event.hit and clock >= float(event.at):
			event.hit = true
			spin += pace(float(event.side) * HAT_KNOCK)
			sound(48)
		if clock >= float(event.until):
			events.erase(event)
	if play_time < _next_event:
		return
	_next_event = play_time + lerpf(GAP_EARLY, GAP_LATE, heat()) * rng.randf_range(0.8, 1.2)
	var weights: Array[float] = [float(variant.gusts), float(variant.pigeons) * (0.4 if heat() < 0.2 else 1.0), float(variant.hats) * (0.0 if heat() < 0.15 else 1.0)]
	var roll: float = rng.randf() * (weights[0] + weights[1] + weights[2])
	var kind := "gust" if roll < weights[0] else ("pigeon" if roll < weights[0] + weights[1] else "hat")
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var starts := clock + WARNING
	# A hat is one sharp knock when it lands; it stays in the list a moment to be drawn bouncing off.
	var lasts: float = {"gust": GUST_SECONDS, "pigeon": PIGEON_SECONDS, "hat": 0.5}[kind]
	events.append({"kind": kind, "side": side, "at": starts, "until": starts + lasts, "hit": false})


func _reset_walk() -> void:
	phase = "walk"
	phase_at = clock
	lean = 0.0
	spin = 0.0
	walk_x = WIRE_FROM
	heading = 1.0
	events.clear()
	bounce = 0.0
	_walked = 0.0
	_steer()


func _steer() -> void:
	steer = int(_held_right) - int(_held_left)


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
