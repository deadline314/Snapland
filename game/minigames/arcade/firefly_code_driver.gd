extends "res://game/minigames/arcade/arcade_driver.gd"
## 螢火蟲對暗號: at dusk by the lily pond, fireflies blink a code on the four
## lantern cradles around the stone lantern (up, right, down, left; each with
## its own shape and tone). Repeat it with the arrows; every code you return
## grows by one. Later the code plays faster, some notes blink twice (press
## twice) and a moth flutters past pretending to be a firefly. A wrong answer
## blacks out every light but one embarrassed firefly. Rules only: the picture
## lives in firefly_code_view.gd.

const View = preload("res://game/minigames/arcade/firefly_code_view.gd")
const DIRS: Array[StringName] = [&"up", &"right", &"down", &"left"]
## One tone per direction, so the code can be followed by ear as well.
const TONES: Array[int] = [84, 79, 72, 76]
const FIRST_LENGTH := 2
## Seconds per note while showing, at the first and at the last second of play.
const BEAT_FIRST := 0.78
const BEAT_LAST := 0.44
const LEAD_IN := 0.6
const PAUSE_SECONDS := 0.7
const DARK_SECONDS := 1.7
## Seconds the fireflies wait for each answer before giving up on you.
const ANSWER_WAIT := 4.0
const NOTE_POINTS := 10
const CODE_POINTS := 5
const DOUBLE_HEAT := 0.35
const DECOY_HEAT := 0.55
const DEMO_GAP := 0.25
const DEMO_BEAT := 0.45

## The code: {dir (0..3), double}.
var code: Array[Dictionary] = []
## "show" -> "answer" -> "pause" (solved) or "dark" (wrong), then the next code.
var phase := "show"
var phase_at := 0.0
var beat := BEAT_FIRST
## Notes of the code answered so far, and presses into a double note.
var answered := 0
var half_pressed := false
## Clock of the player's last press and which cradle it lit.
var press_at := -99.0
var press_dir := -1
## The moth that pretends during this showing: {dir, at} with `at` the second into the showing, or empty.
var decoy: Dictionary = {}
var codes_solved := 0
var longest := 0
var wrongs := 0

var _shown := -1
var _demo := false
var _demo_at := 0.0


func _init() -> void:
	verb = "看螢火蟲閃的暗號，照順序按回去！"
	hint = [["↑ → ↓ ←", "照螢火蟲閃的順序按"]]
	round_seconds = 50.0
	thresholds = [120, 280, 440]
	verdicts = [
		"螢火蟲們決定改用手機傳訊息。",
		"銅牌！暗號對上了，口音有點重。",
		"銀牌！池塘邊的青蛙都在幫你打拍子。",
		"金牌！你是螢火蟲界的摩斯密碼大師。",
	]
	variants = [
		{"id": "starry", "label": "星夜暗號"},
		{"id": "double", "label": "雙閃之夜", "double": true},
		{"id": "moth", "label": "飛蛾搗蛋", "moth": true},
	]
	score_label = "暗號得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	codes_solved = 0
	longest = 0
	wrongs = 0
	_demo = true
	_demo_at = 0.0
	code.clear()
	_new_code(FIRST_LENGTH)


func _warm_up(_delta: float) -> void:
	# The countdown shows a short code and answers it by itself.
	_run_show()
	if phase == "answer" and clock - _demo_at >= DEMO_GAP:
		_demo_at = clock
		_answer(int(code[answered].dir))


func _go() -> void:
	_demo = false
	_new_code(FIRST_LENGTH)


func _tick(_delta: float) -> void:
	var waited := clock - phase_at
	match phase:
		"show":
			_run_show()
		"answer":
			if clock - maxf(phase_at, press_at) >= answer_wait():
				_wrong()
		"pause":
			if waited >= PAUSE_SECONDS:
				_new_code(code.size() + 1, true)
		"dark":
			if waited >= DARK_SECONDS:
				_new_code(maxi(FIRST_LENGTH, code.size() - 1))


func _press(button: StringName) -> void:
	var dir := DIRS.find(button)
	if dir < 0 or phase != "answer":
		return
	_answer(dir)


func _snapshot(into: Dictionary) -> void:
	into.code = code
	into.phase = phase
	into.phase_at = phase_at
	into.beat = beat
	into.lead_in = LEAD_IN
	into.answered = answered
	into.half_pressed = half_pressed
	into.press_at = press_at
	into.press_dir = press_dir
	into.decoy = decoy
	into.codes_solved = codes_solved
	into.dark_seconds = DARK_SECONDS


func answer_wait() -> float:
	return window(ANSWER_WAIT)


## Seconds into the showing at which note `index` starts.
func note_time(index: int) -> float:
	return LEAD_IN + index * beat


## A solved code `grow`s by one note on the end, so it can be learned; otherwise a fresh code.
func _new_code(length: int, grow := false) -> void:
	var notes: Array[Dictionary] = []
	if grow:
		notes.assign(code.slice(0, mini(code.size(), length - 1)))
	var doubles := 0.3 if bool(variant.get("double", false)) else (0.25 if heat() >= DOUBLE_HEAT else 0.0)
	while notes.size() < length:
		var dir := rng.randi() % DIRS.size()
		notes.append({"dir": dir, "double": not _demo and rng.randf() < doubles})
	code = notes
	longest = maxi(longest, length)
	beat = DEMO_BEAT if _demo else window(lerpf(BEAT_FIRST, BEAT_LAST, heat()))
	answered = 0
	half_pressed = false
	_shown = -1
	decoy = {}
	if not _demo and (bool(variant.get("moth", false)) or heat() >= DECOY_HEAT):
		decoy = {"dir": rng.randi() % DIRS.size(), "at": LEAD_IN + rng.randf_range(0.3, maxf(0.4, length * beat - 0.2)), "sounded": false}
	_phase("show")


## Blink each note at its moment; hand over to the player after the last one.
func _run_show() -> void:
	if phase != "show":
		return
	var into := clock - phase_at
	var index := int(floorf((into - LEAD_IN) / beat)) if into >= LEAD_IN else -1
	if index > _shown and index < code.size():
		_shown = index
		sound(TONES[int(code[index].dir)])
	if not decoy.is_empty() and not bool(decoy.sounded) and into >= float(decoy.at):
		decoy.sounded = true
		# A dull buzz, never one of the four tones.
		sound(50)
	if into >= note_time(code.size()):
		_phase("answer")


func _answer(dir: int) -> void:
	press_at = clock
	press_dir = dir
	var note: Dictionary = code[answered]
	if dir != int(note.dir):
		_wrong()
		return
	sound(TONES[dir])
	if bool(note.double) and not half_pressed:
		half_pressed = true
		return
	half_pressed = false
	answered += 1
	if not _demo:
		add_score(NOTE_POINTS)
	if answered >= code.size():
		if not _demo:
			codes_solved += 1
			add_score(CODE_POINTS * code.size(), "對上了！+%d" % (NOTE_POINTS * code.size() + CODE_POINTS * code.size()))
		sound(88)
		_phase("pause")


func _wrong() -> void:
	sound(45)
	wrongs += 1
	# The first wrong answer of a round is a free look at the blackout.
	if wrongs > 1 and not _demo:
		add_mistake("熄燈！")
	else:
		say("熄燈！", false)
	_phase("dark")


func _phase(next: String) -> void:
	phase = next
	phase_at = clock
