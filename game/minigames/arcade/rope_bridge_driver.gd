extends "res://game/minigames/arcade/arcade_driver.gd"
## 繩橋共振: a rope bridge strung between the floating isles sways from side to
## side. Step with the sway: press ← as it swings over to the left and → as it
## swings to the right, and the traveller walks a plank forward and the bridge
## steadies. A step off the beat, or with the wrong foot, sets it swinging
## harder; swing it too far and it rolls right over, leaving the traveller
## hanging upside down underneath like washing on a line. Every stretch between
## two posts swings at its own pace, quicker as the round goes on, and later
## stretches have a broken plank to stride over with ↑ instead.
## Rules only: the picture lives in rope_bridge_view.gd.

const View = preload("res://game/minigames/arcade/rope_bridge_view.gd")
## Planks in each stretch between two posts.
const STRETCH := 8
const PERFECT := 0.07
const GOOD := 0.15
const PERFECT_POINTS := 12
const GOOD_POINTS := 8
const STRIDE_POINTS := 10
const STRETCH_POINTS := 20
const STREAK_STEP := 4
const STREAK_CAP := 5
## Seconds for one full swing (left and back), first stretch and late in play.
const PERIOD_FIRST := 1.3
const PERIOD_LAST := 0.76
## How far the bridge rolls (radians) when steady and just before it flips.
const ROLL_STEADY := 0.1
const ROLL_WILD := 0.55
## Wobble added or taken away (it flips at 1).
const CALM_PERFECT := 0.12
const CALM_GOOD := 0.05
const WOBBLE_WRONG := 0.3
const WOBBLE_SLIP := 0.45
const HANG_SECONDS := 1.8
const FLIP_SECONDS := 0.35
const GAP_HEAT := 0.35
const GAP_FIRST := 0.18
const GAP_LAST := 0.32
const STEP_SECONDS := 0.2

## Planks walked; the traveller stands on plank `pos`.
var pos := 0
var step_at := -99.0
## Planks covered by the last step (2 for a stride over a gap).
var stride := 1
## Swing phase in turns: the bridge leans furthest right at .25 and left at .75.
var phase := 0.0
var wobble := 0.0
var flips := 0
var flip_at := -99.0
## Which way the last flip rolled over (1 right, -1 left).
var flip_side := 1
var streak := 0
var best_streak := 0
var perfects := 0
var goods := 0
var wrongs := 0
var stretches := 0
var grade := ""
var grade_at := -99.0
## Broken planks, by plank number.
var gaps: Dictionary = {}

var _periods: Dictionary = {}
var _used := -1
var _checked := -1
var _planned := -1
var _demo := false


func _init() -> void:
	verb = "跟著吊橋晃動的拍子，左右交替踩步過橋！"
	hint = [["← →", "踩拍子"], ["↑", "跨過斷板"]]
	round_seconds = 45.0
	thresholds = [400, 1000, 1800]
	verdicts = [
		"吊橋決定改當盪鞦韆。",
		"銅牌！橋晃歸晃，人還在上面。",
		"銀牌！浮島上的鳥都在幫你打拍子。",
		"金牌！吊橋說它從沒這麼穩過。",
	]
	variants = [
		{"id": "fair", "label": "晴天吊橋"},
		{"id": "breezy", "label": "強風吊橋", "jitter": 0.28, "steady": 0.16},
		{"id": "worn", "label": "年久失修", "worn": true},
	]
	score_label = "過橋得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	pos = 0
	step_at = -99.0
	stride = 1
	phase = 0.0
	wobble = 0.0
	flips = 0
	flip_at = -99.0
	flip_side = 1
	streak = 0
	best_streak = 0
	perfects = 0
	goods = 0
	wrongs = 0
	stretches = 0
	grade = ""
	grade_at = -99.0
	gaps.clear()
	_periods.clear()
	_used = -1
	_checked = -1
	_planned = -1
	_demo = true
	_plan_ahead()


func _warm_up(delta: float) -> void:
	# The countdown walks two planks on the beat by itself.
	_swing(delta)
	var beat := nearest_beat()
	if pos < 2 and beat > _used and absf(beat_offset(beat)) < delta:
		_used = beat
		_step(beat, "perfect")


func _go() -> void:
	_demo = false
	_used = maxi(_used, nearest_beat())
	_checked = _used


func _tick(delta: float) -> void:
	_swing(delta)
	_plan_ahead()
	# A beat that went by without a step breaks the streak.
	while beat_offset(_checked + 1) > window(GOOD):
		_checked += 1
		if _checked > _used and not hanging():
			streak = 0


func _press(button: StringName) -> void:
	if not button in [&"left", &"right", &"up"] or hanging():
		return
	var beat := next_beat()
	var off := beat_offset(beat)
	if absf(off) > window(GOOD):
		_wobble(WOBBLE_WRONG, "晃！")
		return
	var wanted := wanted_button(beat)
	if button == wanted:
		_used = beat
		_step(beat, "perfect" if absf(off) <= window(PERFECT) else "good")
		return
	_used = beat
	if wanted == &"up":
		# A foot put down where the plank is missing goes straight through.
		_wobble(WOBBLE_SLIP, "踩空！")
	else:
		_wobble(WOBBLE_WRONG, "腳反了！")


func _snapshot(into: Dictionary) -> void:
	into.pos = pos
	into.step_at = step_at
	into.step_seconds = STEP_SECONDS
	into.stride = stride
	into.phase = phase
	into.wobble = wobble
	into.roll = roll()
	into.flip_at = flip_at
	into.hang_seconds = HANG_SECONDS
	into.streak = streak
	into.grade = grade
	into.grade_at = grade_at
	into.gaps = gaps
	into.stretch = STRETCH
	var next := next_beat()
	into.next_side = side(next)
	into.next_button = str(wanted_button(next))
	into.next_in = -beat_offset(next)
	into.beat_seconds = period() * 0.5


## Seconds for one full swing on the stretch the traveller is on.
func period() -> float:
	return float(_periods.get(pos / STRETCH, PERIOD_FIRST))


## The beat whose lean is nearest now (beat n leans right when n is even).
func nearest_beat() -> int:
	return roundi(phase * 2.0 - 0.5)


## Seconds from beat `beat` to now: positive once it has gone by.
func beat_offset(beat: int) -> float:
	return (phase - (beat + 0.5) * 0.5) * period()


## The next beat still to be stepped on.
func next_beat() -> int:
	var beat := nearest_beat()
	if beat <= _used or beat_offset(beat) > window(GOOD):
		beat += 1
	return maxi(beat, _used + 1)


## 1 when beat `beat` leans right, -1 left.
func side(beat: int) -> int:
	return 1 if posmod(beat, 2) == 0 else -1


func wanted_button(beat: int) -> StringName:
	if gaps.has(pos + 1):
		return &"up"
	return &"right" if side(beat) > 0 else &"left"


func hanging() -> bool:
	return clock - flip_at < HANG_SECONDS


## The bridge's roll now (radians, positive leans right); upside down while hanging.
func roll() -> float:
	var reach := lerpf(float(variant.get("steady", ROLL_STEADY)), ROLL_WILD, clampf(wobble, 0.0, 1.0))
	var sway := reach * sin(TAU * phase)
	if not hanging():
		return sway
	var since := clock - flip_at
	var over := smoothstep(0.0, FLIP_SECONDS, since) * (1.0 - smoothstep(HANG_SECONDS - FLIP_SECONDS, HANG_SECONDS, since))
	return lerpf(sway, PI * flip_side + 0.12 * sin(since * 5.0), over)


func _swing(delta: float) -> void:
	phase += delta / period()


func _step(beat: int, quality: String) -> void:
	var over := gaps.has(pos + 1)
	stride = 2 if over else 1
	var before := pos / STRETCH
	pos += stride
	step_at = clock
	grade = quality
	grade_at = clock
	sound(60 + posmod(pos, 5) * 2 + (12 if quality == "perfect" else 0))
	if _demo:
		return
	_used = beat
	streak += 1
	best_streak = maxi(best_streak, streak)
	var points := (PERFECT_POINTS if quality == "perfect" else GOOD_POINTS) + mini(streak / STREAK_STEP, STREAK_CAP)
	if quality == "perfect":
		perfects += 1
		wobble = maxf(0.0, wobble - CALM_PERFECT)
	else:
		goods += 1
		wobble = maxf(0.0, wobble - CALM_GOOD)
	var word := ""
	if over:
		points += STRIDE_POINTS
		word = "跨過去！"
	if pos / STRETCH > before:
		stretches += 1
		points += STRETCH_POINTS
		word = "過了一段！"
		sound(84)
	add_score(points, word)


func _wobble(amount: float, word: String) -> void:
	wrongs += 1
	streak = 0
	wobble += amount
	sound(40)
	if wobble < 1.0:
		say(word, false)
		return
	# Too much: the bridge rolls over and the traveller hangs underneath.
	wobble = 0.3
	flips += 1
	flip_at = clock
	flip_side = 1 if sin(TAU * phase) >= 0.0 else -1
	sound(36)
	# The first time is a free look at the washing on the line.
	funny_fail("晾起來了！", flips > 1)


## Choose each stretch's pace and its broken planks a little ahead of the traveller.
func _plan_ahead() -> void:
	while _planned < pos / STRETCH + 2:
		_planned += 1
		var stretch := _planned
		var period_now := PERIOD_FIRST
		if stretch > 0:
			var jitter := float(variant.get("jitter", 0.15))
			var previous := float(_periods.get(stretch - 1, PERIOD_FIRST))
			var base := lerpf(PERIOD_FIRST, PERIOD_LAST, clampf(heat() + 0.08 * stretch, 0.0, 1.0))
			period_now = base * rng.randf_range(1.0 - jitter, 1.0 + jitter)
			# Each stretch swings at a pace you can feel is different.
			if absf(period_now - previous) < 0.12:
				period_now = previous + (0.14 if period_now >= previous and previous < PERIOD_FIRST else -0.14)
			period_now = clampf(period_now, PERIOD_LAST * 0.85, PERIOD_FIRST * 1.1)
		_periods[stretch] = period_now
		var worn := bool(variant.get("worn", false))
		if stretch == 0 or (not worn and heat() < GAP_HEAT):
			continue
		var chance := lerpf(GAP_FIRST, GAP_LAST, heat()) * (1.5 if worn else 1.0)
		var last_gap := -9
		for slot in range(2, STRETCH - 1):
			var plank := stretch * STRETCH + slot
			if slot - last_gap >= 3 and rng.randf() < chance:
				gaps[plank] = true
				last_gap = slot
