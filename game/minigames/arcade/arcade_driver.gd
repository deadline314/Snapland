extends RefCounted
## Shared flow for one-verb arcade minigames
## (principles: design/00-principles/simple-fun-minigames.md).
##
## A game extends this script as `game/minigames/arcade/<mode>_driver.gd`, fills
## in the declarations inside `_init()` and implements the hooks at the bottom.
## The base owns the ready-set-go, the round clock, the single score, the medal
## lines, the seeded variant, the closing beat and the result mapping:
## bronze or better succeeds and earns the ordinary sticker; gold without assist
## also earns the devil sticker. Assist only widens timing.

const READY_SECONDS := 2.4
const CLOSING_SECONDS := 1.6
const MAX_ROUND_SECONDS := 60.0
const ASSIST_WINDOW := 1.5
const AXIS_PRESS := 0.55
const AXIS_RELEASE := 0.35
const KEYS := {
	KEY_UP: &"up", KEY_W: &"up", KEY_DOWN: &"down", KEY_S: &"down",
	KEY_LEFT: &"left", KEY_A: &"left", KEY_RIGHT: &"right", KEY_D: &"right",
	KEY_SPACE: &"action", KEY_ENTER: &"action", KEY_KP_ENTER: &"action", KEY_E: &"action", KEY_Z: &"action",
	KEY_X: &"second", KEY_Q: &"second", KEY_SHIFT: &"second",
}
const PAD := {
	JOY_BUTTON_DPAD_UP: &"up", JOY_BUTTON_DPAD_DOWN: &"down", JOY_BUTTON_DPAD_LEFT: &"left", JOY_BUTTON_DPAD_RIGHT: &"right",
	JOY_BUTTON_A: &"action", JOY_BUTTON_X: &"second", JOY_BUTTON_Y: &"second",
}
const AXES := {JOY_AXIS_LEFT_X: [&"left", &"right"], JOY_AXIS_LEFT_Y: [&"up", &"down"]}

# --- Declared by each game in _init() ---------------------------------------
## One line telling the player what to do, shown with the countdown.
var verb := ""
## Control hint as [key label, meaning] pairs, e.g. [["空白鍵", "停輪"]].
var hint: Array = []
var round_seconds := 45.0
## Bronze, silver and gold score lines, visible from the first frame.
var thresholds: Array[int] = [1, 2, 3]
## One funny line per medal: none, bronze, silver, gold.
var verdicts: Array[String] = ["", "", "", ""]
## At least two parameter sets ({"id", "label", ...}); one is picked per round.
var variants: Array[Dictionary] = [{"id": "standard", "label": "標準"}]
var score_label := "得分"
## Control script extending arcade_view.gd (preload it as a constant so it
## stays loaded with the driver); null keeps the game headless.
var view_script: Script

# --- Round state the hooks may read -----------------------------------------
var rng := RandomNumberGenerator.new()
## Tests and capture probes pin this before reset(); negative means random.
var round_seed := -1
var assisted := false
var variant: Dictionary = {}
var score := 0
var mistakes := 0
## "ready" (countdown) -> "play" -> "closing" (time is up) -> "done".
var stage := "ready"
## Seconds of actual play, 0..round_seconds.
var play_time := 0.0
## Seconds since reset, across every stage; the view animates from this alone.
## (The session's "elapsed" stops at time up, so result photos show play.)
var clock := 0.0

var _stage_time := 0.0
var _state: Dictionary = {}
var _held: Dictionary[String, StringName] = {}
var _notes: Array[int] = []
var _view: Control
var _word := ""
var _word_good := true
var _word_at := -99.0


func reset(assisted_mode: bool, _clock: String) -> void:
	clear_input()
	assisted = assisted_mode
	if round_seed >= 0:
		rng.seed = round_seed
	else:
		rng.randomize()
	round_seconds = clampf(round_seconds, 1.0, MAX_ROUND_SECONDS)
	variant = variants[rng.randi() % variants.size()]
	score = 0
	mistakes = 0
	stage = "ready"
	play_time = 0.0
	clock = 0.0
	_stage_time = 0.0
	_word = ""
	_word_at = -99.0
	_notes.clear()
	_begin_round(variant)
	_refresh()


func create_view() -> Control:
	if view_script == null or DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = view_script.new()
		_view.present(_state, false)
	return _view


func handle_input(event: InputEvent, _point: Vector2) -> bool:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not KEYS.has(code):
			return false
		if not event.echo:
			_route(KEYS[code], event.pressed and not event.is_canceled(), "key:%d" % code)
	elif event is InputEventJoypadButton:
		if not PAD.has(event.button_index):
			return false
		_route(PAD[event.button_index], event.pressed, "pad:%d:%d" % [event.device, event.button_index])
	elif event is InputEventJoypadMotion:
		if not AXES.has(event.axis):
			return false
		for side in 2:
			var push: float = event.axis_value * (1.0 if side == 1 else -1.0)
			var source := "axis:%d:%d:%d" % [event.device, event.axis, side]
			if push >= AXIS_PRESS:
				_route(AXES[event.axis][side], true, source)
			elif push <= AXIS_RELEASE:
				_route(AXES[event.axis][side], false, source)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# A click or tap anywhere is the main button.
		_route(&"action", event.pressed, "pointer")
	else:
		return false
	_refresh()
	return true


func clear_input() -> void:
	var playing := stage == "play"
	for source: String in _held.keys():
		var button: StringName = _held[source]
		_held.erase(source)
		if playing:
			_release(button)


func step(delta: float) -> Dictionary:
	if stage == "done" or not is_finite(delta) or delta <= 0.0:
		return _state
	clock += delta
	match stage:
		"ready":
			_stage_time += delta
			_warm_up(delta)
			if _stage_time >= READY_SECONDS:
				_enter("play")
				_go()
		"play":
			var slice := minf(delta, round_seconds - play_time)
			play_time += slice
			_tick(slice)
			if play_time >= round_seconds:
				clear_input()
				_enter("closing")
				_round_over()
		"closing":
			_stage_time += delta
			if _stage_time >= CLOSING_SECONDS:
				_enter("done")
	_refresh()
	return _state


func snapshot() -> Dictionary:
	return _state


func present(_phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func score_summary(practice: bool) -> Dictionary:
	var earned := medal()
	var note := ""
	if practice:
		note = "練習回合不取得拍貼。"
	elif assisted and earned == 3:
		note = "輔助回合的金牌不發小惡魔拍貼。"
	return {
		"total": score, "label": score_label,
		"rule": "銅牌 %d 分、銀牌 %d 分、金牌 %d 分。銅牌可收藏普通拍貼，未開輔助的金牌再得小惡魔拍貼。" % thresholds,
		"rows": [{"key": "score", "label": score_label, "amount": score, "count": 0}],
		"qualification_text": note,
		"arcade": true, "medal": earned, "verdict": verdicts[earned], "thresholds": thresholds.duplicate(),
	}


## 0 none, 1 bronze, 2 silver, 3 gold.
func medal() -> int:
	var earned := 0
	for line in thresholds:
		if score >= line:
			earned += 1
	return earned


## 0 at the first second of play, 1 at the last: drive escalation from this.
func heat() -> float:
	return clampf(play_time / round_seconds, 0.0, 1.0)


## A timing window in seconds, wider with assist.
func window(seconds: float) -> float:
	return seconds * ASSIST_WINDOW if assisted else seconds


## A speed, gentler with assist.
func pace(speed: float) -> float:
	return speed / ASSIST_WINDOW if assisted else speed


func add_score(points: int, word := "") -> void:
	score = maxi(0, score + points)
	if not word.is_empty():
		say(word, true)


func add_mistake(word := "") -> void:
	mistakes += 1
	if not word.is_empty():
		say(word, false)


## A short, large feedback word.
func say(word: String, good: bool) -> void:
	_word = word
	_word_good = good
	_word_at = clock


func sound(note: int) -> void:
	_notes.append(note)


func _route(button: StringName, pressed: bool, source: String) -> void:
	if pressed:
		if _held.has(source):
			return
		_held[source] = button
		if stage == "play":
			_press(button)
	elif _held.erase(source) and stage == "play":
		_release(button)


func _enter(next_stage: String) -> void:
	stage = next_stage
	_stage_time = 0.0


func _refresh() -> void:
	var earned := medal()
	var remaining := maxf(0.0, round_seconds - play_time)
	_state.elapsed = clock if stage == "ready" or stage == "play" else READY_SECONDS + round_seconds
	_state.clock = clock
	_state.score = score
	_state.mistakes = mistakes
	_state.ended = stage == "done"
	_state.success = earned >= 1
	_state.devil = earned >= 3 and not assisted
	_state.ordinary_eligible = earned >= 1
	_state.progress_text = "銅 %d　銀 %d　金 %d" % thresholds
	_state.time_text = "預備" if stage == "ready" else "%d 秒" % ceili(remaining)
	_state.feedback_text = ""
	_state.stage = stage
	_state.stage_time = _stage_time
	_state.ready_seconds = READY_SECONDS
	_state.remaining = remaining
	_state.round_seconds = round_seconds
	_state.heat = heat()
	_state.medal = earned
	_state.thresholds = thresholds
	_state.verb = verb
	_state.hint = hint
	_state.variant_id = str(variant.get("id", ""))
	_state.variant_label = str(variant.get("label", ""))
	_state.assisted = assisted
	_state.word = _word
	_state.word_good = _word_good
	_state.word_at = _word_at
	_snapshot(_state)


# --- Hooks ------------------------------------------------------------------

## Start a fresh round with the chosen variant; `rng` is already seeded.
func _begin_round(_variant: Dictionary) -> void:
	pass


## Advance the scene during the countdown (inputs are not delivered yet).
func _warm_up(_delta: float) -> void:
	pass


## The countdown just ended; play starts now.
func _go() -> void:
	pass


## Advance one slice of actual play.
func _tick(_delta: float) -> void:
	pass


## Buttons: &"up", &"down", &"left", &"right", &"action", &"second".
func _press(_button: StringName) -> void:
	pass


func _release(_button: StringName) -> void:
	pass


## The clock just ran out; settle anything still in flight.
func _round_over() -> void:
	pass


## Add the game's own fields to the state the view draws from.
func _snapshot(_into: Dictionary) -> void:
	pass
