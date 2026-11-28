extends "res://game/minigames/arcade/arcade_driver.gd"
## 觀眾席波浪: the hero sits in the front row of the circus bleachers while a
## wave of standing spectators sweeps across the stands, lap after lap. Press
## to stand up just as it reaches the hero's seat and the wave carries on round
## the tent. Laps come faster or slower without warning and later a lap holds
## two waves or runs the other way; now and then a spectator next to the hero
## jumps up early as a feint. Stand up with no wave near and the whole tent sits
## still, turns to stare at the one person standing, and the popcorn goes
## everywhere. Rules only: the picture lives in crowd_wave_view.gd.

const View = preload("res://game/minigames/arcade/crowd_wave_view.gd")
## Screen x of the hero's seat and where a wave enters and leaves.
const HERO_X := 640.0
const ENTER_X := -120.0
const LEAVE_X := 1400.0
## Seconds either side of the crest that still count; a perfect stand is tighter.
const WINDOW := 0.16
const PERFECT := 0.06
## Crest speed in pixels per second, early and late, and how much a lap varies.
const SPEED_EARLY := 400.0
const SPEED_LATE := 950.0
const LAP_SPREAD := 0.28
const WOBBLE_LATE := 0.3
const GAP_EARLY := 0.7
const GAP_LATE := 0.25
## A second crest in a double lap trails the first by this many seconds.
const DOUBLE_SPACING := 0.7
const FEINT_EARLY := 0.15
const FEINT_LATE := 0.5
const ALONE_SECONDS := 2.2
const STAND_SECONDS := 0.35
const POINTS := 10
const PERFECT_BONUS := 10
const STREAK_BONUS := 2
const STREAK_CAP := 5

## "lap" (a wave on its way), "gap" (going round the back) or "alone".
var phase := "gap"
var phase_at := 0.0
var direction := 1.0
## Crests this lap: {x, hit, broken}.
var crests: Array[Dictionary] = []
var speed := SPEED_EARLY
var base_speed := SPEED_EARLY
## A spectator jumping up early: {seat_offset, at, until}, or empty.
var feint: Dictionary = {}
var stood_at := -99.0
var streak := 0
var catches := 0
var misses := 0
var alones := 0
var laps := 0
var _next_lap := 0.0
var _feint_due := false


func _init() -> void:
	verb = "人浪到你這格就按鍵起立！"
	hint = [["空白鍵", "起立"]]
	round_seconds = 45.0
	thresholds = [90, 250, 400]
	verdicts = [
		"全場只有你一個人站著，爆米花也全撒了。",
		"銅牌！人浪有經過你，你也有站起來。",
		"銀牌！整座看台跟著你一起轉。",
		"金牌！人浪繞了好幾圈都沒斷，像在看體育賽事。",
	]
	variants = [
		{"id": "standard", "label": "週末人浪", "doubles": 0.0, "reverse": 0.0},
		{"id": "double", "label": "雙重人浪", "doubles": 0.5, "reverse": 0.0},
		{"id": "reverse", "label": "反向人浪", "doubles": 0.0, "reverse": 0.5},
	]
	score_label = "人浪得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	crests.clear()
	feint = {}
	streak = 0
	catches = 0
	misses = 0
	alones = 0
	laps = 0
	stood_at = -99.0
	direction = 1.0
	_phase("gap")


## The countdown shows the idea: a wave sweeps past and the hero stands with it.
func _warm_up(delta: float) -> void:
	if crests.is_empty() and clock < 0.2:
		crests = [{"x": ENTER_X, "hit": false, "broken": false}]
		speed = 900.0
		_phase("lap")
	for crest in crests:
		crest.x = float(crest.x) + speed * delta
		if not bool(crest.hit) and float(crest.x) >= HERO_X:
			crest.hit = true
			stood_at = clock


func _go() -> void:
	crests.clear()
	feint = {}
	stood_at = -99.0
	_phase("gap")
	_next_lap = 0.5


func _tick(delta: float) -> void:
	match phase:
		"gap":
			if play_time >= _next_lap:
				_start_lap()
		"alone":
			if clock - phase_at >= ALONE_SECONDS:
				_phase("gap")
				_next_lap = play_time + gap()
		"lap":
			var wobble := WOBBLE_LATE * heat() * sin(clock * 3.1)
			speed = base_speed * (1.0 + wobble)
			for crest in crests:
				crest.x = float(crest.x) + direction * speed * delta
				var past := (float(crest.x) - HERO_X) * direction
				if not bool(crest.hit) and not bool(crest.broken) and past > speed * window(WINDOW):
					_miss(crest)
			if _feint_due and feint.is_empty():
				var lead := _nearest_gap()
				if lead > 0.0 and lead < speed * 1.0:
					feint = {"seat": (1 if rng.randf() < 0.5 else -1) * (1 + rng.randi() % 2), "at": clock, "until": clock + 0.5}
					_feint_due = false
			if not feint.is_empty() and clock > float(feint.until):
				feint = {}
			var gone := true
			for crest in crests:
				var x := float(crest.x)
				gone = gone and (x > LEAVE_X if direction > 0.0 else x < ENTER_X)
			if gone:
				_phase("gap")
				_next_lap = play_time + gap()


func _press(button: StringName) -> void:
	if button != &"action" and button != &"up":
		return
	if phase == "alone" or clock - stood_at < STAND_SECONDS:
		return
	stood_at = clock
	var best: Dictionary = {}
	var nearest := INF
	for crest in crests:
		if bool(crest.hit) or bool(crest.broken):
			continue
		var off := absf(float(crest.x) - HERO_X)
		if off < nearest:
			nearest = off
			best = crest
	if phase == "lap" and not best.is_empty() and nearest <= speed * window(WINDOW):
		_catch(best, nearest <= speed * PERFECT)
	else:
		_alone()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.crests = crests
	into.direction = direction
	into.speed = speed
	into.feint = feint
	into.stood_at = stood_at
	into.streak = streak
	into.hero_x = HERO_X
	into.next_in = maxf(0.0, _next_lap - play_time) if phase == "gap" else 0.0
	into.next_direction = direction


func gap() -> float:
	return lerpf(GAP_EARLY, GAP_LATE, heat())


func _start_lap() -> void:
	laps += 1
	base_speed = lerpf(SPEED_EARLY, SPEED_LATE, heat()) * rng.randf_range(1.0 - LAP_SPREAD, 1.0 + LAP_SPREAD)
	speed = base_speed
	direction = -1.0 if rng.randf() < float(variant.reverse) * minf(1.0, heat() * 3.0) else 1.0
	var start := ENTER_X if direction > 0.0 else LEAVE_X
	crests = [{"x": start, "hit": false, "broken": false}]
	if rng.randf() < float(variant.doubles) * minf(1.0, heat() * 3.0):
		crests.append({"x": start - direction * DOUBLE_SPACING * base_speed, "hit": false, "broken": false})
	_feint_due = rng.randf() < lerpf(FEINT_EARLY, FEINT_LATE, heat())
	feint = {}
	_phase("lap")


## Pixels until the nearest crest still to come reaches the hero, or -1.
func _nearest_gap() -> float:
	var best := -1.0
	for crest in crests:
		var ahead := (HERO_X - float(crest.x)) * direction
		if ahead > 0.0 and (best < 0.0 or ahead < best):
			best = ahead
	return best


func _catch(crest: Dictionary, perfect: bool) -> void:
	crest.hit = true
	catches += 1
	var points := POINTS + (PERFECT_BONUS if perfect else 0) + STREAK_BONUS * mini(streak, STREAK_CAP)
	streak += 1
	add_score(points, ("完美！+%d" if perfect else "+%d") % points)
	sound(72 + mini(streak, 6) * 2)


func _miss(crest: Dictionary) -> void:
	crest.broken = true
	misses += 1
	streak = 0
	sound(45)
	add_mistake("人浪斷了…")


func _alone() -> void:
	alones += 1
	streak = 0
	crests.clear()
	feint = {}
	sound(38)
	# The first lonely stand of a round is a free look at the staring crowd.
	funny_fail("只有你站著…", alones > 1)
	_phase("alone")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
