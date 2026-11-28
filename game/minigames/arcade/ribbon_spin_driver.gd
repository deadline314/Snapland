extends "res://game/minigames/arcade/arcade_driver.gd"
## 謝幕回旋: a drummer keeps the beat at the side of the ring while the hero
## twirls a ribbon on a stick. Press left and right in turn on the beat and the
## hero spins; every steady spin widens the ribbon's circle and its points. The
## drummer changes tempo now and then (raising the sticks one beat before), and
## each routine ends in a drum roll: press the action button on the final crash
## to stop and bow. Lose the rhythm (two bad beats in a row: wrong side, off the
## beat or missed) and the ribbon wraps the hero up like a mummy who hops off
## stage and back. No presses, no spins, no points. Rules only: the picture lives
## in ribbon_spin_view.gd.

const View = preload("res://game/minigames/arcade/ribbon_spin_view.gd")
## Seconds either side of a beat that still count, and the perfect band.
const WINDOW := 0.13
const PERFECT := 0.05
## Seconds per beat, early and late.
const BEAT_EARLY := 0.62
const BEAT_LATE := 0.38
const ROUTINE_EARLY := 8
const ROUTINE_LATE := 12
const ROLL_SECONDS := 1.3
const BOW_WINDOW := 0.15
const BOW_PERFECT := 0.06
const LATE_BOW := 0.4
const BOW_SECONDS := 1.0
const TANGLE_SECONDS := 2.4
const MAX_SIZE := 8
const SPIN_POINTS := 5
const SIZE_POINTS := 2
const PERFECT_BONUS := 3
const BOW_POINTS := 30
const BOW_PERFECT_POINTS := 50
const BOW_PENALTY := 10

## "dance", "roll" (waiting for the crash), "bow" or "tangle".
var phase := "rest"
var phase_at := 0.0
var beat := BEAT_EARLY
var next_beat := 0.0
var answered := false
var beats_left := 0
## Which arrow the next spin needs: &"" (either), &"left" or &"right".
var expect: StringName = &""
## How wide the ribbon's circle is, 0..MAX_SIZE.
var size := 0
var bad_run := 0
var spins := 0
var tangles := 0
var bows := 0
var routines := 0
## A tempo change: the beat it starts on (clock) and its new length, or empty.
var tempo_change: Dictionary = {}
var crash_at := -99.0
var fake_crash_at := -99.0
var last_press: Dictionary = {}
var _rest_until := 0.0


func _init() -> void:
	verb = "跟著鼓聲左右交替轉圈，收尾那一下按空白鍵鞠躬！"
	hint = [["← →", "跟拍子轉"], ["空白鍵", "收尾鞠躬"]]
	round_seconds = 50.0
	thresholds = [300, 1100, 1600]
	verdicts = [
		"絲帶把你包成了木乃伊，蹦蹦跳跳下台去。",
		"銅牌！轉了幾圈，鞠躬也有點到。",
		"銀牌！絲帶畫的圓大到最後排都看得到。",
		"金牌！鼓手都跟著你的節奏打了。",
	]
	variants = [
		{"id": "standard", "label": "謝幕回旋", "tempo": 0.35, "fake": 0.0},
		{"id": "swing", "label": "搖擺鼓手", "tempo": 0.8, "fake": 0.0},
		{"id": "fake", "label": "假收尾", "tempo": 0.3, "fake": 0.7},
	]
	score_label = "回旋得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	size = 0
	bad_run = 0
	spins = 0
	tangles = 0
	bows = 0
	routines = 0
	last_press = {}
	tempo_change = {}
	beat = BEAT_EARLY
	_phase("rest")
	_rest_until = 0.0


## The countdown shows the idea: the drum beats and the hero spins on it.
func _warm_up(_delta: float) -> void:
	if clock >= next_beat:
		next_beat = clock + BEAT_EARLY
		size = mini(size + 1, 3)
		last_press = {"at": clock, "good": true, "side": &"left" if size % 2 == 0 else &"right", "perfect": true}


func _go() -> void:
	size = 0
	last_press = {}
	_phase("rest")
	_rest_until = play_time + 0.2


func _tick(_delta: float) -> void:
	match phase:
		"rest":
			if play_time >= _rest_until:
				_start_routine()
		"dance":
			if not tempo_change.is_empty() and clock >= float(tempo_change.at) - beat * 0.5 and float(tempo_change.at) <= next_beat + 0.001:
				beat = float(tempo_change.length)
			if clock > next_beat + window(WINDOW):
				if not answered:
					_bad("漏拍了！", true)
					if phase != "dance":
						return
				_advance_beat()
		"roll":
			if clock > crash_at + LATE_BOW:
				add_score(-BOW_PENALTY, "停太晚了！")
				_bow_now()
		"bow":
			if clock - phase_at >= BOW_SECONDS:
				_phase("rest")
				_rest_until = play_time + 0.4
		"tangle":
			if clock - phase_at >= TANGLE_SECONDS:
				_phase("rest")
				_rest_until = play_time + 0.3


func _press(button: StringName) -> void:
	match phase:
		"dance":
			if button == &"left" or button == &"right":
				_spin(button)
		"roll":
			if button == &"action":
				_bow()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.beat = beat
	into.next_beat = next_beat
	into.beats_left = beats_left
	into.expect = expect
	into.size = size
	into.max_size = MAX_SIZE
	into.last_press = last_press
	into.tempo_change = tempo_change
	into.crash_at = crash_at
	into.fake_crash_at = fake_crash_at
	into.spins = spins


func _start_routine() -> void:
	routines += 1
	beat = lerpf(BEAT_EARLY, BEAT_LATE, heat())
	beats_left = roundi(lerpf(ROUTINE_EARLY, ROUTINE_LATE, heat()))
	next_beat = clock + beat
	answered = false
	expect = &""
	bad_run = 0
	tempo_change = {}
	if rng.randf() < float(variant.tempo) * (0.5 + heat()):
		var at_beat := 3 + rng.randi() % maxi(1, beats_left - 5)
		var faster := rng.randf() < 0.5 + heat() * 0.3
		tempo_change = {"at": next_beat + beat * at_beat, "length": beat * (0.75 if faster else 1.3), "faster": faster}
	_phase("dance")


func _advance_beat() -> void:
	next_beat += beat
	answered = false
	beats_left -= 1
	if beats_left <= 0:
		_roll()


func _spin(side: StringName) -> void:
	var off := clock - next_beat
	if answered or absf(off) > window(WINDOW) or (expect != &"" and side != expect):
		var why := "反了！" if expect != &"" and side != expect and absf(off) <= window(WINDOW) else "亂了拍！"
		last_press = {"at": clock, "good": false, "side": side, "perfect": false}
		_bad(why, false)
		return
	answered = true
	bad_run = 0
	var perfect := absf(off) <= PERFECT
	size = mini(size + 1, MAX_SIZE)
	spins += 1
	expect = &"right" if side == &"left" else &"left"
	last_press = {"at": clock, "good": true, "side": side, "perfect": perfect}
	add_score(SPIN_POINTS + SIZE_POINTS * size + (PERFECT_BONUS if perfect else 0))
	sound(60 + size * 2)


func _bad(word: String, missed: bool) -> void:
	bad_run += 1
	size = maxi(0, size - 2)
	if not missed:
		answered = true
	if bad_run >= 2:
		_tangle()
	else:
		say(word, false)
		sound(46)


func _roll() -> void:
	crash_at = clock + ROLL_SECONDS
	fake_crash_at = crash_at - 0.6 if rng.randf() < float(variant.fake) else -99.0
	_phase("roll")
	sound(70)


func _bow() -> void:
	var off := clock - crash_at
	if off < -BOW_WINDOW:
		add_score(-BOW_PENALTY, "停太早了！")
	elif absf(off) <= BOW_PERFECT:
		add_score(BOW_PERFECT_POINTS + size * 2, "完美謝幕！")
	elif off <= BOW_WINDOW:
		add_score(BOW_POINTS + size * 2, "謝幕！")
	else:
		add_score(-BOW_PENALTY, "停太晚了！")
	_bow_now()


func _bow_now() -> void:
	bows += 1
	sound(84)
	_phase("bow")


func _tangle() -> void:
	tangles += 1
	size = 0
	bad_run = 0
	tempo_change = {}
	sound(38)
	# The first tangle of a round is a free look at the ribbon mummy.
	funny_fail("纏住了！", tangles > 1)
	_phase("tangle")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
