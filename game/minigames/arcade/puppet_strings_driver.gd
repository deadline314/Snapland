extends "res://game/minigames/arcade/arcade_driver.gd"
## 木偶牽線: a wooden marionette dances to a music-box tune in a little puppet
## theatre. Brass beads slide down its strings in time with the music; pull a
## string (← left hand, → right hand, ↑ head, ↓ feet) just as its bead reaches
## the limb and the puppet dances. Missed beads and wild pulls knot the strings;
## knot them enough and every string snarls at once, the puppet flips upside
## down and hangs there waving at the traveller until the strings come loose.
## The tune speeds up section by section and two-string beats join later.
## Rules only: the picture lives in puppet_strings_view.gd.

const View = preload("res://game/minigames/arcade/puppet_strings_view.gd")
## Strings: 0 head (↑), 1 left hand (←), 2 right hand (→), 3 feet (↓).
const STRINGS := 4
## Seconds a bead takes to slide from the control bar down to its limb.
const LEAD := 1.3
const PERFECT := 0.07
const GOOD := 0.15
const PERFECT_POINTS := 15
const GOOD_POINTS := 10
const COMBO_STEP := 4
const COMBO_CAP := 5
const STRAY_POINTS := 5
## Knots: a miss ties one, a wild pull ties one, a clean pull loosens half.
const KNOT_LIMIT := 4.0
const TANGLE_SECONDS := 1.8
## Tempo of each section of the tune, in beats per minute.
const TEMPOS: Array[float] = [92.0, 108.0, 124.0, 140.0]
const SECTION_SECONDS := 11.25
const DOUBLE_HEAT := 0.35
const OFFBEAT_HEAT := 0.55

## Beads: {id, string, t (when it reaches the limb), state ("coming", "hit",
## "miss", "lost"), grade ("perfect", "good"), at}.
var beads: Array[Dictionary] = []
## When each string was last pulled.
var pulled_at: Array[float] = [-99.0, -99.0, -99.0, -99.0]
var knots := 0.0
var tangled_at := -99.0
var tangles := 0
var combo := 0
var best_combo := 0
var hits := 0
var perfects := 0
var misses := 0
var strays := 0
var doubles := 0
var beat_at := -99.0

var _next_beat := 0.0
var _beat_times: Array[float] = []
var _beat := 0
var _serial := 0
var _last_string := -1
var _demo := false


func _init() -> void:
	verb = "珠子滑到手腳時拉線，讓木偶跟著音樂跳！"
	hint = [["← → ↑ ↓", "拉那條線"]]
	round_seconds = 45.0
	thresholds = [350, 900, 1400]
	verdicts = [
		"木偶決定今天只想躺著。",
		"銅牌！跳得有點像在拍蚊子。",
		"銀牌！觀眾開始跟著打拍子了。",
		"金牌！木偶說它要跟你組團巡演。",
	]
	variants = [
		{"id": "standard", "label": "八音盒小步舞"},
		{"id": "jig", "label": "快步吉格舞", "tempo": 1.15},
		{"id": "duet", "label": "雙線雙人舞", "doubles": true},
	]
	score_label = "跳舞得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	beads.clear()
	pulled_at = [-99.0, -99.0, -99.0, -99.0]
	knots = 0.0
	tangled_at = -99.0
	tangles = 0
	combo = 0
	best_combo = 0
	hits = 0
	perfects = 0
	misses = 0
	strays = 0
	doubles = 0
	beat_at = -99.0
	_serial = 0
	_last_string = -1
	_demo = true
	# The countdown sends two beads down and the puppet pulls them itself.
	_bead(1, 1.1)
	_bead(2, 1.75)


func _warm_up(_delta: float) -> void:
	for bead in beads:
		if str(bead.state) == "coming" and clock >= float(bead.t):
			_pull_bead(bead, "perfect")
	_tidy()


func _go() -> void:
	_demo = false
	beads.clear()
	knots = 0.0
	combo = 0
	_beat = 0
	_beat_times.clear()
	_next_beat = clock + 0.4


func _tick(_delta: float) -> void:
	# Lay the next beads out on the beat, LEAD seconds ahead of the limb.
	while _next_beat <= clock + LEAD:
		_place_beat(_next_beat)
		_beat_times.append(_next_beat)
		_next_beat += 60.0 / tempo_at(_next_beat - clock + play_time)
	# The music box ticks on every beat.
	while not _beat_times.is_empty() and _beat_times[0] <= clock:
		_beat_times.pop_front()
		beat_at = clock
		sound(36)
	for bead in beads:
		if str(bead.state) == "coming" and clock - float(bead.t) > window(GOOD):
			_miss(bead)
	_tidy()


func _press(button: StringName) -> void:
	var string := {&"up": 0, &"left": 1, &"right": 2, &"down": 3}.get(button, -1) as int
	if string < 0 or tangled():
		return
	pulled_at[string] = clock
	var best: Dictionary = {}
	for bead in beads:
		if str(bead.state) == "coming" and int(bead.string) == string and absf(float(bead.t) - clock) <= window(GOOD):
			if best.is_empty() or absf(float(bead.t) - clock) < absf(float(best.t) - clock):
				best = bead
	if best.is_empty():
		# A wild pull jerks the limb and ties a knot.
		strays += 1
		combo = 0
		add_score(-STRAY_POINTS)
		sound(40)
		_knot(1.0)
		return
	_pull_bead(best, "perfect" if absf(float(best.t) - clock) <= window(PERFECT) else "good")


func _snapshot(into: Dictionary) -> void:
	into.beads = beads
	into.pulled_at = pulled_at
	into.lead = LEAD
	into.knots = knots
	into.knot_limit = KNOT_LIMIT
	into.tangled_at = tangled_at
	into.tangle_seconds = TANGLE_SECONDS
	into.combo = combo
	into.beat_at = beat_at
	into.section = section()


## Beats per minute `seconds` into play.
func tempo_at(seconds: float) -> float:
	var index := clampi(int(seconds / SECTION_SECONDS), 0, TEMPOS.size() - 1)
	return TEMPOS[index] * float(variant.get("tempo", 1.0))


func section() -> int:
	return clampi(int(play_time / SECTION_SECONDS), 0, TEMPOS.size() - 1)


func tangled() -> bool:
	return clock - tangled_at < TANGLE_SECONDS


func _place_beat(at: float) -> void:
	_beat += 1
	var heat_then := clampf((at - clock + play_time) / round_seconds, 0.0, 1.0)
	if at > clock + (round_seconds - play_time) - 0.2:
		return
	# Most beats get a bead; later ones also get an offbeat or a second string.
	if rng.randf() < lerpf(0.65, 0.85, heat_then):
		var string := _pick_string()
		_bead(string, at)
		var duet := bool(variant.get("doubles", false))
		if (heat_then >= DOUBLE_HEAT or duet) and rng.randf() < (0.35 if duet else 0.2):
			var other := (string + 1 + rng.randi() % (STRINGS - 1)) % STRINGS
			_bead(other, at)
			doubles += 1
	if heat_then >= OFFBEAT_HEAT and rng.randf() < 0.25:
		_bead(_pick_string(), at + 30.0 / tempo_at(at - clock + play_time))


func _pick_string() -> int:
	var string := rng.randi() % STRINGS
	if string == _last_string and rng.randf() < 0.5:
		string = (string + 1 + rng.randi() % (STRINGS - 1)) % STRINGS
	_last_string = string
	return string


func _bead(string: int, at: float) -> void:
	_serial += 1
	beads.append({"id": _serial, "string": string, "t": at, "state": "coming", "grade": "", "at": -99.0})


func _pull_bead(bead: Dictionary, grade: String) -> void:
	bead.state = "hit"
	bead.grade = grade
	bead.at = clock
	pulled_at[int(bead.string)] = clock
	sound([72, 67, 76, 60][int(bead.string)] + (0 if grade == "perfect" else -12))
	if _demo:
		return
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	knots = maxf(0.0, knots - 0.5)
	var points := PERFECT_POINTS if grade == "perfect" else GOOD_POINTS
	points += mini(combo / COMBO_STEP, COMBO_CAP)
	if grade == "perfect":
		perfects += 1
		add_score(points, "漂亮！" if combo % 8 != 0 else "連拍 × %d！" % combo)
	else:
		add_score(points, "好！")


func _miss(bead: Dictionary) -> void:
	bead.state = "miss"
	bead.at = clock
	if _demo:
		return
	misses += 1
	combo = 0
	_knot(1.0)


func _knot(amount: float) -> void:
	if _demo or tangled():
		return
	knots += amount
	if knots < KNOT_LIMIT:
		return
	# Every string snarls at once and the puppet flips upside down.
	knots = 0.0
	tangles += 1
	tangled_at = clock
	sound(45)
	sound(52)
	for bead in beads:
		if str(bead.state) == "coming" and float(bead.t) < clock + TANGLE_SECONDS + 0.2:
			bead.state = "lost"
			bead.at = clock
	# The first tangle of a round is a free look at the upside-down wave.
	funny_fail("纏住了！", tangles > 1)


func _tidy() -> void:
	var kept: Array[Dictionary] = []
	for bead in beads:
		if str(bead.state) == "coming" or clock - float(bead.at) < 0.6:
			kept.append(bead)
	beads.assign(kept)
