extends "res://game/minigames/arcade/arcade_driver.gd"
## 花粉拓印: a big wooden flower stamp hangs on a cord from a beam over the
## greenhouse craft table and swings left and right like a pendulum above a
## long sheet of paper. A dashed frame is printed on the paper; press to drop
## the stamp, and the pink flower lands wherever the stamp is. Inside the
## frame scores, dead centre scores most. After each print the paper slides on
## to a fresh frame. Later the frames get smaller, the swing gets quicker and
## the paper itself starts drifting. Miss the frame and the stamp bounces up
## and thumps the traveller (leaning in to watch) right on the forehead,
## leaving a big pink flower print there for the rest of the round.
## Rules only: the picture lives in pollen_print_view.gd.
##
## Positions are design pixels across the 1280-wide screen.

const View = preload("res://game/minigames/arcade/pollen_print_view.gd")
const PIVOT := Vector2(640, 150)
const CORD := 190.0
## How far either side of the middle the stamp swings, and its swing speed
## (radians of the swing cycle per second), early and late.
const REACH := 340.0
const SPEED_FIRST := 1.7
const SPEED_LAST := 2.9
const DROP_SECONDS := 0.22
const LIFT_SECONDS := 0.28
const SLIDE_SECONDS := 0.45
const FRAME_FIRST := 170.0
const FRAME_LAST := 92.0
const FRAME_LEFT := 380.0
const FRAME_RIGHT := 900.0
## Within this share of the frame's half width of its centre is dead on.
const CENTRE := 0.22
const CENTRE_POINTS := 30
const INSIDE_LOW := 10
const INSIDE_HIGH := 22
const STREAK_POINTS := 5
const STREAK_CAP := 6
const DRIFT := 110.0
const DRIFT_HEAT := 0.4
const BONK_SECONDS := 1.6

var phase := 0.0
## The stamp's swing angle right now, for drawing the cord.
var angle := 0.0
## The frame waiting for a print: {x, w, centre (its x without drift), at}.
var frame: Dictionary = {}
## The sheet that just got printed, sliding away: {frame, print, at}.
var leaving: Dictionary = {}
## The stamp coming down: {at, x, result} until it is lifted again.
var press: Dictionary = {}
## The last miss: {at}.
var bonk: Dictionary = {}
## Flower prints on the traveller's forehead.
var forehead := 0
var streak := 0
var prints := 0
## Sheets the paper has rolled on by.
var sheets := 0

var _demo := false


func _init() -> void:
	verb = "印章擺到框框正上方時按下，把花印在框裡！"
	hint = [["空白鍵", "蓋印章"]]
	round_seconds = 45.0
	thresholds = [70, 200, 320]
	verdicts = [
		"紙上一片花，就是沒有一朵在框裡。",
		"銅牌！花印得歪歪的，但很有精神。",
		"銀牌！一整排花端端正正。",
		"金牌！溫室花藝社請你去當印花師傅。",
	]
	variants = [
		{"id": "standard", "label": "晴天印花"},
		{"id": "quick", "label": "急性子印章", "speed": 1.25},
		{"id": "drift", "label": "紙飄日", "drift": true},
	]
	score_label = "印花得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_table()
	frame = _frame(640.0)


## The countdown drops the stamp by itself just as it crosses the frame.
func _warm_up(delta: float) -> void:
	var before := stamp_x()
	_swing(delta)
	var after := stamp_x()
	if press.is_empty() and prints == 0 and clock > 0.6 and (before - float(frame.x)) * (after - float(frame.x)) <= 0.0:
		_drop()
	_settle()


func _go() -> void:
	# Play starts with a fresh frame and the stamp at the far end of its swing,
	# so nothing happens before the player's first press.
	_demo = false
	_reset_table()
	phase = PI * 0.5
	frame = _frame(_frame_spot())


func _tick(delta: float) -> void:
	_swing(delta)
	_settle()


func _press(button: StringName) -> void:
	if button in [&"action", &"down", &"up", &"second"] and ready_to_drop():
		_drop()


## No input, no points.
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _snapshot(into: Dictionary) -> void:
	into.pivot = PIVOT
	into.cord = CORD
	into.angle = angle
	into.stamp_x = stamp_x()
	into.frame = frame
	into.leaving = leaving
	into.press = press
	into.bonk = bonk
	into.bonk_seconds = BONK_SECONDS
	into.forehead = forehead
	into.prints = prints
	into.sheets = sheets
	into.streak = streak
	into.drop_seconds = DROP_SECONDS
	into.lift_seconds = LIFT_SECONDS
	into.slide_seconds = SLIDE_SECONDS


func stamp_x() -> float:
	return PIVOT.x + REACH * sin(phase)


func speed() -> float:
	return pace(lerpf(SPEED_FIRST, SPEED_LAST, heat()) * float(variant.get("speed", 1.0)))


func frame_width() -> float:
	return lerpf(FRAME_FIRST, FRAME_LAST, heat())


func centre_band() -> float:
	return CENTRE * (ASSIST_WINDOW if assisted else 1.0)


func busy() -> bool:
	return not bonk.is_empty() and clock - float(bonk.at) < BONK_SECONDS


func ready_to_drop() -> bool:
	return press.is_empty() and not busy() and clock - float(frame.get("at", -99.0)) >= SLIDE_SECONDS


func _swing(delta: float) -> void:
	if press.is_empty():
		phase += speed() * delta
	angle = atan2(stamp_x() - PIVOT.x, CORD * 1.6)
	# Later on (or on a drifting day) the paper wanders under the stamp.
	if not frame.is_empty() and (heat() >= DRIFT_HEAT or bool(variant.get("drift", false))) and not _demo:
		frame.x = clampf(float(frame.centre) + DRIFT * sin(clock * 0.9 + float(frame.centre)), FRAME_LEFT, FRAME_RIGHT)


func _drop() -> void:
	press = {"at": clock, "x": stamp_x(), "result": ""}
	sound(55)


func _settle() -> void:
	if press.is_empty():
		return
	var since := clock - float(press.at)
	if press.result == "" and since >= DROP_SECONDS:
		_print()
	if since >= DROP_SECONDS + LIFT_SECONDS:
		_next_sheet()
		press = {}


func _print() -> void:
	var off := absf(float(press.x) - float(frame.x))
	var half := float(frame.w) * 0.5
	prints += 1
	if off <= half * centre_band():
		press.result = "centre"
		sound(79 + mini(streak, 6))
		if _demo:
			return
		streak += 1
		var points := CENTRE_POINTS + mini(streak - 1, STREAK_CAP) * STREAK_POINTS
		add_score(points, ("正中！×%d" % streak) if streak >= 3 else "正中！")
	elif off <= half:
		press.result = "inside"
		streak = 0
		sound(72)
		add_score(int(round(lerpf(INSIDE_HIGH, INSIDE_LOW, (off - half * centre_band()) / maxf(1.0, half * (1.0 - centre_band()))))), "印到了")
	else:
		press.result = "miss"
		streak = 0
		sound(50)
		bonk = {"at": clock}
		if _demo:
			return
		forehead += 1
		# The first miss of a round is a free look at the flower forehead.
		funny_fail("印到額頭了！", forehead > 1)


func _next_sheet() -> void:
	sheets += 1
	leaving = {"frame": frame.duplicate(), "print": press.duplicate(), "at": clock}
	frame = _frame(_frame_spot())


func _frame(at: float) -> Dictionary:
	return {"x": at, "centre": at, "w": frame_width(), "at": clock}


func _frame_spot() -> float:
	return rng.randf_range(FRAME_LEFT, FRAME_RIGHT)


func _reset_table() -> void:
	phase = 0.0
	angle = 0.0
	frame = {}
	leaving = {}
	press = {}
	bonk = {}
	forehead = 0
	streak = 0
	prints = 0
	sheets = 0
