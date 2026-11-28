extends "res://game/minigames/arcade/arcade_driver.gd"
## 音盒補拍: a music box plays a little tune. Its brass cylinder turns toward
## the viewer and every pin on it rolls down to the steel comb and plays its
## note by itself, but some pins have fallen out. Press just as an empty socket
## reaches the comb to pluck the missing note. Missed notes and wild presses
## build up pressure under the lid; at full pressure the lid bursts open and
## the jack-in-the-box clown inside punches the traveller with a boxing glove.
## The cylinder speeds up and wobbles, and later the empty sockets come in rows.
## Rules only: the picture lives in music_box_view.gd.

const View = preload("res://game/minigames/arcade/music_box_view.gd")
## Teeth on the comb, low to high; each pin sits in one column.
const TEETH := 8
## Seconds a pin takes to roll from the top of the cylinder down to the comb.
const LEAD := 2.4
const PERFECT := 0.06
const GOOD := 0.13
const PERFECT_POINTS := 15
const GOOD_POINTS := 10
const COMBO_STEP := 4
const COMBO_CAP := 5
const STRAY_POINTS := 5
const PRESSURE_LIMIT := 4.0
const POP_SECONDS := 1.8
## Beats per minute, at the start and at the end of play.
const TEMPO_FIRST := 104.0
const TEMPO_LAST := 156.0
const GAP_FIRST := 0.22
const GAP_LAST := 0.42
const ROWS_HEAT := 0.5
## A little tune, as comb columns, played over and over.
const TUNE: Array[int] = [0, 2, 4, 5, 4, 2, 4, 7, 6, 4, 5, 2, 3, 1, 2, 0]
## Note for each tooth.
const NOTES: Array[int] = [72, 74, 76, 77, 79, 81, 83, 84]

## Pins on the cylinder: {id, column, t (when it reaches the comb), gap (no pin:
## the player must pluck it), state ("coming", "played", "plucked", "missed",
## "lost"), grade, at}.
var pins: Array[Dictionary] = []
## When each tooth last sounded.
var plucked_at: Array[float] = []
var pressure := 0.0
var popped_at := -99.0
var pops := 0
var combo := 0
var best_combo := 0
var filled := 0
var perfects := 0
var missed := 0
var strays := 0
var press_at := -99.0
## How far round the cylinder has turned, in beats, for the picture.
var turned := 0.0

var _next_beat := 0.0
var _beat := 0
var _serial := 0
var _rows_left := 0
var _demo := false


func _init() -> void:
	verb = "空的針孔轉到音梳時按下，把曲子補完整！"
	hint = [["空白鍵", "補上音針"]]
	round_seconds = 45.0
	thresholds = [200, 380, 540]
	verdicts = [
		"音盒決定改播收音機。",
		"銅牌！曲子聽得出來是哪一首。",
		"銀牌！小丑在盒子裡跟著搖擺。",
		"金牌！八音盒工廠想跟你簽約。",
	]
	variants = [
		{"id": "lullaby", "label": "八音盒小品"},
		{"id": "wobble", "label": "發條快鬆了", "wobble": true},
		{"id": "holes", "label": "掉針大放送", "gaps": 1.35},
	]
	score_label = "補拍得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	pins.clear()
	plucked_at.clear()
	for tooth in TEETH:
		plucked_at.append(-99.0)
	pressure = 0.0
	popped_at = -99.0
	pops = 0
	combo = 0
	best_combo = 0
	filled = 0
	perfects = 0
	missed = 0
	strays = 0
	press_at = -99.0
	turned = 0.0
	_serial = 0
	_rows_left = 0
	_demo = true
	# The countdown rolls a short phrase down with one empty socket and fills it itself.
	for index in 4:
		_pin(TUNE[index], 0.9 + index * 0.35, index == 2)


func _warm_up(delta: float) -> void:
	turned += delta * 2.0
	for pin in pins:
		if str(pin.state) == "coming" and clock >= float(pin.t):
			if bool(pin.gap):
				_pluck(pin, "perfect")
			else:
				_play(pin)
	_tidy()


func _go() -> void:
	_demo = false
	pins.clear()
	pressure = 0.0
	combo = 0
	_beat = 0
	_next_beat = clock + LEAD * 0.6


func _tick(delta: float) -> void:
	turned += delta * tempo() / 60.0
	# Lay pins out on the beat, LEAD seconds before they reach the comb.
	while _next_beat <= clock + LEAD:
		_place(_next_beat)
		_next_beat += 60.0 / tempo_at(_next_beat - clock + play_time)
	for pin in pins:
		if str(pin.state) != "coming":
			continue
		if bool(pin.gap):
			if clock - float(pin.t) > window(GOOD):
				_miss(pin)
		elif clock >= float(pin.t):
			_play(pin)
	_tidy()


func _press(button: StringName) -> void:
	if not button in [&"action", &"down", &"second", &"up"] or popped():
		return
	press_at = clock
	var best: Dictionary = {}
	for pin in pins:
		if str(pin.state) == "coming" and bool(pin.gap) and absf(float(pin.t) - clock) <= window(GOOD):
			if best.is_empty() or absf(float(pin.t) - clock) < absf(float(best.t) - clock):
				best = pin
	if best.is_empty():
		# A press with no empty socket at the comb clunks a tooth.
		strays += 1
		combo = 0
		add_score(-STRAY_POINTS)
		sound(40)
		_press_on(1.0)
		return
	_pluck(best, "perfect" if absf(float(best.t) - clock) <= window(PERFECT) else "good")


func _snapshot(into: Dictionary) -> void:
	into.pins = pins
	into.plucked_at = plucked_at
	into.lead = LEAD
	into.teeth = TEETH
	into.pressure = pressure
	into.pressure_limit = PRESSURE_LIMIT
	into.popped_at = popped_at
	into.pop_seconds = POP_SECONDS
	into.combo = combo
	into.press_at = press_at
	into.turned = turned


func tempo() -> float:
	return tempo_at(play_time)


## Beats per minute `seconds` into play; the loose spring makes it wobble.
func tempo_at(seconds: float) -> float:
	var progress := clampf(seconds / round_seconds, 0.0, 1.0)
	var bpm := lerpf(TEMPO_FIRST, TEMPO_LAST, progress)
	if bool(variant.get("wobble", false)):
		bpm *= 1.0 + 0.18 * sin(seconds * 0.9)
	return bpm


func popped() -> bool:
	return clock - popped_at < POP_SECONDS


func _place(at: float) -> void:
	_beat += 1
	var progress := clampf((at - clock + play_time) / round_seconds, 0.0, 1.0)
	if at > clock + (round_seconds - play_time) - 0.1:
		return
	var column := TUNE[_beat % TUNE.size()]
	var chance := lerpf(GAP_FIRST, GAP_LAST, progress) * float(variant.get("gaps", 1.0))
	var gap := false
	if _rows_left > 0:
		gap = true
		_rows_left -= 1
	elif rng.randf() < chance:
		gap = true
		# Later on the empty sockets come two or three in a row.
		if progress >= ROWS_HEAT and rng.randf() < 0.4:
			_rows_left = rng.randi_range(1, 2)
	_pin(column, at, gap)
	# Most beats also carry a harmony pin a few teeth away; those are never missing.
	if rng.randf() < 0.7:
		_pin((column + 3 + rng.randi() % 2) % TEETH, at, false)


func _pin(column: int, at: float, gap: bool) -> void:
	_serial += 1
	pins.append({"id": _serial, "column": column, "t": at, "gap": gap, "state": "coming", "grade": "", "at": -99.0})


func _play(pin: Dictionary) -> void:
	pin.state = "played"
	pin.at = clock
	plucked_at[int(pin.column)] = clock
	sound(NOTES[int(pin.column)])


func _pluck(pin: Dictionary, grade: String) -> void:
	pin.state = "plucked"
	pin.grade = grade
	pin.at = clock
	plucked_at[int(pin.column)] = clock
	sound(NOTES[int(pin.column)])
	if _demo:
		return
	filled += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	pressure = maxf(0.0, pressure - 0.5)
	var points := (PERFECT_POINTS if grade == "perfect" else GOOD_POINTS) + mini(combo / COMBO_STEP, COMBO_CAP)
	if grade == "perfect":
		perfects += 1
		add_score(points, "叮！" if combo % 8 != 0 else "連拍 × %d！" % combo)
	else:
		add_score(points, "補上了！")


func _miss(pin: Dictionary) -> void:
	pin.state = "missed"
	pin.at = clock
	sound(43)
	if _demo:
		return
	missed += 1
	combo = 0
	_press_on(1.0)


## Pressure builds under the lid; at the limit it bursts open.
func _press_on(amount: float) -> void:
	if _demo or popped():
		return
	pressure += amount
	if pressure < PRESSURE_LIMIT:
		return
	pressure = 0.0
	pops += 1
	popped_at = clock
	sound(36)
	sound(88)
	for pin in pins:
		if str(pin.state) == "coming" and float(pin.t) < clock + POP_SECONDS + 0.2:
			pin.state = "lost"
			pin.at = clock
	# The first time the lid pops is a free look at the punch.
	funny_fail("砰！", pops > 1)


func _tidy() -> void:
	var kept: Array[Dictionary] = []
	for pin in pins:
		if str(pin.state) == "coming" or clock - float(pin.at) < 0.6:
			kept.append(pin)
	pins.assign(kept)
