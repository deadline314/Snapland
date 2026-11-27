extends "res://game/minigames/arcade/arcade_driver.gd"
## 整點咕咕: the clock ticks four times a bar and a card names the tick the
## cuckoo will charge out on. One press opens the door for an instant: open it
## on that tick and the bird sings, open it at any other moment (or not at all)
## and the bird flies into a closed door. Rules only: the picture lives in
## cuckoo_cue_view.gd.

const View = preload("res://game/minigames/arcade/cuckoo_cue_view.gd")
const BEATS := 4
## Seconds between ticks at the first and at the last second of play.
const BEAT_SLOW := 0.62
const BEAT_FAST := 0.4
## Each bar picks a different one of these, so the tempo changes between bars.
const TEMPO_STEPS: Array[float] = [1.0, 0.86, 1.14]
## Seconds either side of the tick that still count, never more than this share of a beat.
const WINDOW := 0.13
const WINDOW_SHARE := 0.42
const PERFECT_SHARE := 0.4
const HIT_POINTS := 10
## Each hit in a row is worth this much more, up to MAX_STREAK steps.
const STREAK_POINTS := 5
const MAX_STREAK := 4
const PERFECT_POINTS := 5
## Heat (0..1 through the round) from which half-beat targets and the decoy bird appear.
const OFFBEAT_HEAT := 0.3
const DECOY_HEAT := 0.45
## A swung pair of ticks: the first takes this share of two beats.
const SWING := 0.66
const DEMO_BEAT := 0.46
const DEMO_TICK := 3

var bar := 0
## Clock at which this bar's one-beat lead-in began.
var bar_at := 0.0
var beat := BEAT_SLOW
## Seconds from `bar_at` to each tick.
var ticks: Array[float] = []
var bar_length := 0.0
## One per cuckoo this bar: {tick, time, door, state, at, perfect}; state is
## "pending", "hit", "jammed" (the door was opened at the wrong moment) or "bonk".
var targets: Array[Dictionary] = []
## Tick on which the decoy bird pops; 0 when it stays home.
var decoy_tick := 0
var decoy_at := -99.0
## No tick sound this bar: only the pendulum shows the beat.
var silent := false
var streak := 0
var hits := 0
var bonks := 0
var ticks_heard := 0
var tick_at := -99.0
var empty_at := -99.0

var _tempo_step := -1
var _demo := false


func _init() -> void:
	verb = "數滴答，在指定那一下開門！"
	hint = [["空白鍵", "開門讓咕咕鳥出來"]]
	round_seconds = 45.0
	thresholds = [100, 220, 360]
	verdicts = [
		"咕咕鳥決定改行當門擋。",
		"銅牌！鳥有出門，只是頭上多了幾個包。",
		"銀牌！整點報時，偶爾慢一拍。",
		"金牌！全城的鐘都想跟你對時。",
	]
	variants = [
		{"id": "standard", "label": "準點報時", "worth": 1.0},
		{"id": "swing", "label": "搖擺滴答", "worth": 1.0, "swing": true},
		{"id": "duet", "label": "雙鳥輪唱", "worth": 0.45, "duet": true},
		{"id": "silent", "label": "靜音小節", "worth": 1.0, "silent": true},
	]
	score_label = "報時得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	bar = 0
	streak = 0
	hits = 0
	bonks = 0
	_tempo_step = -1
	# The countdown plays one bar in which the bird is let out for the player.
	_demo = true
	_set_bar(DEMO_BEAT, [float(DEMO_TICK)], 0, false)


func _warm_up(_delta: float) -> void:
	_run_bar()


func _go() -> void:
	_demo = false
	_next_bar()


func _tick(_delta: float) -> void:
	_run_bar()
	if clock - bar_at >= bar_length:
		_next_bar()


func _press(button: StringName) -> void:
	if button != &"action":
		return
	var target := _pending()
	if target.is_empty():
		return
	var off := clock - bar_at - float(target.time)
	if absf(off) <= hit_window():
		_hit(target, absf(off) <= hit_window() * PERFECT_SHARE)
	else:
		# The door flaps open on nobody and jams until the bird arrives.
		target.state = "jammed"
		empty_at = clock
		say("門後沒鳥！", false)
		sound(55)


func _snapshot(into: Dictionary) -> void:
	into.bar = bar
	into.bar_at = bar_at
	into.beat = beat
	into.beats = BEATS
	into.ticks = ticks
	into.bar_length = bar_length
	into.targets = targets
	into.decoy_tick = decoy_tick
	into.decoy_at = decoy_at
	into.silent = silent
	into.streak = streak
	into.ticks_heard = ticks_heard
	into.tick_at = tick_at
	into.empty_at = empty_at
	into.duet = targets.size() > 1


## Seconds either side of the target that count as on time; wider with assist.
func hit_window() -> float:
	return minf(window(WINDOW), beat * WINDOW_SHARE * (1.15 if assisted else 1.0))


## Seconds from the start of the bar to a tick; "2.5" is halfway between ticks 2 and 3.
func tick_time(tick: float) -> float:
	var whole := int(tick)
	var at := ticks[whole - 1]
	if tick > float(whole):
		at = (at + (ticks[whole] if whole < BEATS else bar_length)) * 0.5
	return at


func _pending() -> Dictionary:
	for target in targets:
		if target.state == "pending":
			return target
	return {}


func _next_bar() -> void:
	bar += 1
	var step := rng.randi() % TEMPO_STEPS.size()
	if step == _tempo_step:
		step = (step + 1) % TEMPO_STEPS.size()
	_tempo_step = step
	var next_beat := lerpf(BEAT_SLOW, BEAT_FAST, heat()) * TEMPO_STEPS[step]
	var wanted: Array[float] = []
	# The very first bar never asks for the first tick: there is a beat to get ready.
	var first := 1 + rng.randi() % BEATS if bar > 1 else 2 + rng.randi() % (BEATS - 1)
	wanted.append(float(first))
	if bool(variant.get("duet", false)):
		var second := 1 + (first - 1 + 1 + rng.randi() % (BEATS - 1)) % BEATS
		wanted.append(float(second))
		wanted.sort()
	elif heat() >= OFFBEAT_HEAT and first < BEATS and rng.randf() < 0.4:
		wanted[0] += 0.5
	var decoy := 0
	if heat() >= DECOY_HEAT and rng.randf() < 0.6:
		decoy = 1 + rng.randi() % BEATS
		for tick in wanted:
			if int(tick) == decoy:
				decoy = 0
	_set_bar(next_beat, wanted, decoy, bool(variant.get("silent", false)) and bar % 2 == 0)


func _set_bar(next_beat: float, wanted: Array[float], decoy: int, quiet: bool) -> void:
	bar_at = clock
	beat = next_beat
	bar_length = beat * (BEATS + 1)
	ticks.clear()
	for index in BEATS:
		var at := beat * (index + 1)
		if bool(variant.get("swing", false)) and index % 2 == 1:
			at += beat * (SWING * 2.0 - 1.0)
		ticks.append(at)
	targets.clear()
	for index in wanted.size():
		# In a duet the two birds take turns going first.
		targets.append({"tick": wanted[index], "time": tick_time(wanted[index]), "door": (index + bar) % 2 if wanted.size() > 1 else 0,
			"state": "pending", "at": -99.0, "perfect": false})
	decoy_tick = decoy
	decoy_at = -99.0
	silent = quiet
	ticks_heard = 0
	empty_at = -99.0


## Sound the ticks that are due and send out every bird whose moment has come.
func _run_bar() -> void:
	var since := clock - bar_at
	while ticks_heard < BEATS and since >= ticks[ticks_heard]:
		ticks_heard += 1
		tick_at = bar_at + ticks[ticks_heard - 1]
		if not silent:
			sound(74 if ticks_heard % 2 == 1 else 69)
		if ticks_heard == decoy_tick:
			decoy_at = clock
			sound(60)
	for target in targets:
		var due := float(target.time)
		if _demo and target.state == "pending" and since >= due:
			target.state = "hit"
			target.at = clock
			sound(86)
		elif (target.state == "pending" and since > due + hit_window()) or (target.state == "jammed" and since >= due):
			_bonk(target)


func _hit(target: Dictionary, perfect: bool) -> void:
	var points := roundi((HIT_POINTS + STREAK_POINTS * mini(streak, MAX_STREAK) + (PERFECT_POINTS if perfect else 0)) * float(variant.get("worth", 1.0)))
	streak += 1
	hits += 1
	target.state = "hit"
	target.at = clock
	target.perfect = perfect
	add_score(points, ("完美！+%d" if perfect else "咕咕！+%d") % points)
	sound(86 if perfect else 84)


func _bonk(target: Dictionary) -> void:
	target.state = "bonk"
	target.at = clock
	streak = 0
	bonks += 1
	sound(46)
	# The first bump of a round is a free look at what a closed door does.
	funny_fail("撞門了！", bonks > 1)
