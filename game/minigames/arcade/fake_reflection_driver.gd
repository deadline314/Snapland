extends "res://game/minigames/arcade/arcade_driver.gd"
## 誰是假倒影: every mirror copies the hero's pose at once, except one fake that
## lags, strikes the wrong pose or points the other way. Left and right move the
## spotlight and pose the hero in one go; up poses on the spot; the main button
## accuses. Rules only: the picture lives in fake_reflection_view.gd.

const View = preload("res://game/minigames/arcade/fake_reflection_view.gd")
const IDLE := &"idle"
const TELL_POSES: Array[StringName] = [&"left", &"right", &"up"]
## What the fake does instead when it gets a pose wrong.
const WRONG_POSE := {&"left": &"up", &"right": &"left", &"up": &"right"}
const FLIPPED_POSE := {&"left": &"right", &"right": &"left"}
const CATCH_POINTS := 5
## Each catch in a row is worth this much more, up to MAX_STREAK steps, so
## looking pays and blind guessing does not.
const STREAK_POINTS := 5
const MAX_STREAK := 3
const CAUGHT_SECONDS := 0.7
## A wrong guess costs time: the fake takes its bow on the way out.
const ESCAPE_SECONDS := 2.6
## A tap holds its pose at least this long so every mirror gets to answer.
const POSE_SECONDS := 0.3
## How late the lagging fake answers at the first and the last second of play.
const LAG_SLOW := 0.42
const LAG_FAST := 0.2
## Heat (0..1 through the round) at which a fourth, then a fifth mirror joins.
const MIRROR_HEATS: Array[float] = [0.3, 0.62]
const FIRST_MIRRORS := 3
## The countdown shows the idea: the hero poses by itself as [second, pose].
const DEMO: Array = [[0.5, &"up"], [1.0, &"idle"], [1.4, &"left"], [1.9, &"idle"]]

var mirrors := FIRST_MIRRORS
var fake := 0
var selected := 1
var pose: StringName = IDLE
var pose_at := 0.0
## Poses the fake gets wrong in this case (the "wrong" variant only).
var wrong_poses: Array[StringName] = []
## "" while searching, then "caught" or "escaped" for the closing beat of a case.
var outcome := ""
var outcome_at := -99.0
var accused := -1
## Seconds left on the closing beat of a case.
var pause := 0.0
var cases_done := 0
var catches := 0
var streak := 0
var case_at := 0.0

var _held_pose: StringName = IDLE
var _idle_at := -1.0
## Recent pose changes as [clock, pose], oldest first; the lagging fake reads the past.
var _history: Array = []
var _reflections: Array[StringName] = []


func _init() -> void:
	verb = "找出動作不一樣的假倒影！"
	hint = [["←→", "移燈兼擺姿勢"], ["↑", "原地舉手"], ["空白鍵", "就是它"]]
	round_seconds = 45.0
	thresholds = [60, 130, 200]
	verdicts = [
		"假倒影笑到在鏡子裡打滾。",
		"銅牌！有幾面鏡子開始怕你了。",
		"銀牌！假倒影今晚睡不著。",
		"金牌！連真的倒影都被你看得心虛。",
	]
	variants = [
		{"id": "lag", "label": "慢半拍"},
		{"id": "wrong", "label": "做錯動作"},
		{"id": "flip", "label": "左右相反"},
	]
	score_label = "抓假倒影得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	cases_done = 0
	catches = 0
	streak = 0
	_next_case()


func _warm_up(_delta: float) -> void:
	var shown: StringName = IDLE
	for beat: Array in DEMO:
		if _stage_time >= float(beat[0]):
			shown = beat[1]
	_set_pose(shown)


func _go() -> void:
	_set_pose(IDLE)
	case_at = clock


func _tick(delta: float) -> void:
	if pause > 0.0:
		pause -= delta
		if pause <= 0.0:
			_next_case()
		return
	if _idle_at >= 0.0 and clock >= _idle_at:
		_idle_at = -1.0
		_set_pose(IDLE)


func _press(button: StringName) -> void:
	if pause > 0.0:
		return
	match button:
		&"left", &"right":
			selected = clampi(selected + (1 if button == &"right" else -1), 0, mirrors - 1)
			_strike(button)
		&"up":
			_strike(button)
		&"action":
			_accuse()


func _release(button: StringName) -> void:
	if button == _held_pose:
		_held_pose = IDLE
		# Let a quick tap finish its pose before relaxing.
		_idle_at = maxf(clock, pose_at + POSE_SECONDS)


func _round_over() -> void:
	_held_pose = IDLE
	_idle_at = -1.0


func _snapshot(into: Dictionary) -> void:
	_reflections.resize(mirrors)
	for index in mirrors:
		_reflections[index] = reflection_pose(index)
	into.mirrors = mirrors
	into.fake = fake
	into.selected = selected
	into.pose = pose
	into.pose_at = pose_at
	into.reflections = _reflections
	into.outcome = outcome
	into.outcome_at = outcome_at
	into.accused = accused
	into.case_at = case_at
	into.streak = streak
	into.catches = catches


## How many mirrors stand in the row at this point of the round.
func mirror_count() -> int:
	var count := FIRST_MIRRORS
	for line in MIRROR_HEATS:
		if heat() >= line:
			count += 1
	return count


## Seconds the lagging fake answers late; shorter as the round heats up.
func lag() -> float:
	return window(lerpf(LAG_SLOW, LAG_FAST, heat()))


## The pose mirror `index` shows right now.
func reflection_pose(index: int) -> StringName:
	if index != fake or not outcome.is_empty():
		return pose
	match str(variant.get("id", "")):
		"lag":
			return _pose_at(clock - lag())
		"wrong":
			return WRONG_POSE[pose] if wrong_poses.has(pose) else pose
		"flip":
			return FLIPPED_POSE.get(pose, pose)
	return pose


func _strike(next_pose: StringName) -> void:
	_held_pose = next_pose
	_idle_at = -1.0
	_set_pose(next_pose)
	sound(67)


func _set_pose(next_pose: StringName) -> void:
	if next_pose == pose:
		return
	pose = next_pose
	pose_at = clock
	_history.append([clock, pose])
	if _history.size() > 12:
		_history.pop_front()


func _pose_at(moment: float) -> StringName:
	for index in range(_history.size() - 1, -1, -1):
		if float(_history[index][0]) <= moment:
			return _history[index][1]
	return IDLE


func _accuse() -> void:
	cases_done += 1
	accused = selected
	outcome_at = clock
	_held_pose = IDLE
	_idle_at = -1.0
	_set_pose(IDLE)
	if selected == fake:
		catches += 1
		var steps := mini(streak, MAX_STREAK)
		var points := CATCH_POINTS + STREAK_POINTS * steps
		add_score(points, "抓到了！+%d" % points if streak == 0 else "連抓 %d 個！+%d" % [streak + 1, points])
		streak += 1
		outcome = "caught"
		pause = CAUGHT_SECONDS
		sound(79 + steps * 2)
	else:
		streak = 0
		outcome = "escaped"
		pause = ESCAPE_SECONDS
		sound(55)
		# The very first wrong guess is a free look at how the fake gloats.
		if cases_done > 1:
			add_mistake("被耍了！")
		else:
			say("被耍了！", false)


func _next_case() -> void:
	mirrors = mirror_count()
	fake = rng.randi() % mirrors
	selected = floori(mirrors * 0.5)
	outcome = ""
	accused = -1
	pause = 0.0
	case_at = clock
	pose = IDLE
	pose_at = clock
	_held_pose = IDLE
	_idle_at = -1.0
	_history.clear()
	_history.append([clock, IDLE])
	# The wrong-pose fake fumbles every pose at first, then only two, then one.
	var fumbles := TELL_POSES.size() - mirror_count() + FIRST_MIRRORS
	var pool: Array[StringName] = TELL_POSES.duplicate()
	wrong_poses.clear()
	for pick in fumbles:
		wrong_poses.append(pool.pop_at(rng.randi() % pool.size()))
