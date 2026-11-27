extends "res://game/minigames/arcade/arcade_driver.gd"
## 發條衝刺: mash the main button to wind a tin toy, then let go and watch it
## run. More turns run farther, but past a limit that changes every dash the
## spring bursts. The gauge hides its last third, so the only honest tells are
## the rising pitch and the toy shaking. Rules only: the picture lives in
## windup_dash_view.gd.

const View = preload("res://game/minigames/arcade/windup_dash_view.gd")
## Full length of the gauge in turns; no spring ever holds more.
const GAUGE_TURNS := 24.0
## The gauge is readable up to here; the limit always hides beyond it.
const COVER_FROM := 2.0 / 3.0
## The limit is drawn between this share of the gauge and its full length:
## generous early, anywhere in the hidden third by the end of the round.
const LIMIT_LOW_EARLY := 0.84
const LIMIT_LOW_LATE := COVER_FROM
const METRES_PER_TURN := 0.5
const POINTS_PER_METRE := 10.0
## Not pressing for this long lets the toy go.
const RELEASE_GAP := 0.5
const RUN_SECONDS := 1.0
const RUN_SECONDS_PER_METRE := 0.06
const REST_SECONDS := 0.85
const BURST_SECONDS := 2.1
## Extra turns the spring forgives with assist.
const ASSIST_SLACK := 3.0
## Rivals line up from this dash on; each needs more turns to beat.
const RIVAL_FROM_DASH := 3
const RIVAL_TURNS: Array[float] = [14.0, 16.0, 17.0, 18.0, 19.0, 20.0]
const RIVAL_BONUS := 30
const DEMO_TURNS := 9.0
const DEMO_WIND_SECONDS := 1.25

## "wind" -> "run" -> "rest", or "wind" -> "burst"; then the next dash.
var phase := "wind"
var phase_at := 0.0
var dash := 0
var turns := 0.0
var limit := GAUGE_TURNS
var press_at := -99.0
## Metres of the dash now running or just finished.
var distance := 0.0
var run_seconds := 1.0
var best := 0.0
var bursts := 0
var dashes_done := 0
## Turns the rival of this dash is worth; 0 while there is none.
var rival_turns := 0.0
var rivals_beaten := 0
var beat_rival := false
var last_points := 0


func _init() -> void:
	verb = "連打上發條，放手就衝！"
	hint = [["空白鍵", "連打上發條"], ["X", "放手（停手也會放）"]]
	round_seconds = 45.0
	thresholds = [220, 500, 850]
	verdicts = [
		"玩具走了兩步就打瞌睡了。",
		"銅牌！發條鬆鬆的，跑得很養生。",
		"銀牌！彈簧說牠還撐得住。",
		"金牌！整條街的玩具都追不上你。",
	]
	variants = [
		{"id": "standard", "label": "標準發條", "gain": 1.0, "worth": 1.0, "coast": 1.0, "blind": false},
		{"id": "heavy", "label": "鐵皮重玩具", "gain": 0.6, "worth": 1.4, "coast": 1.0, "blind": false},
		{"id": "slippery", "label": "打蠟地板", "gain": 1.0, "worth": 1.0, "coast": 1.25, "blind": false},
		{"id": "blind", "label": "蓋住的發條表", "gain": 1.0, "worth": 1.1, "coast": 1.0, "blind": true},
	]
	score_label = "衝刺得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	dash = 0
	best = 0.0
	bursts = 0
	dashes_done = 0
	rivals_beaten = 0
	_next_dash()


## The countdown shows one short wind and run with nobody pressing.
func _warm_up(_delta: float) -> void:
	if _stage_time < DEMO_WIND_SECONDS:
		var shown := floorf(DEMO_TURNS * _stage_time / DEMO_WIND_SECONDS)
		if shown != turns:
			turns = shown
			press_at = clock
	elif phase == "wind":
		_launch()


func _go() -> void:
	dash = 0
	_next_dash()


func _tick(_delta: float) -> void:
	var waited := clock - phase_at
	match phase:
		"wind":
			if turns > 0.0 and clock - press_at >= window(RELEASE_GAP):
				_launch()
		"run":
			if waited >= run_seconds:
				_land()
		"rest":
			if waited >= REST_SECONDS:
				_next_dash()
		"burst":
			if waited >= BURST_SECONDS:
				_next_dash()


func _press(button: StringName) -> void:
	if phase != "wind":
		return
	if button == &"action":
		turns += float(variant.gain)
		press_at = clock
		sound(55 + int(minf(strain(), 1.0) * 26.0))
		if turns > burst_turns():
			_burst()
	elif turns > 0.0 and (button == &"second" or button == &"down"):
		_launch()


## A dash still winding or running when the clock stops is measured as it stands.
func _round_over() -> void:
	if phase == "wind" and turns > 0.0:
		_launch()
	if phase == "run":
		_land()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.dash = dash
	into.turns = turns
	into.gauge = GAUGE_TURNS
	into.cover_from = 0.0 if bool(variant.get("blind", false)) else COVER_FROM
	into.strain = strain()
	into.press_at = press_at
	into.distance = distance
	into.run_seconds = run_seconds
	into.best = best
	into.rival_turns = rival_turns
	into.rival_distance = metres(rival_turns)
	into.beat_rival = beat_rival
	into.last_points = last_points
	into.track_metres = metres(GAUGE_TURNS)


## 0 slack, 1 at the limit: what the pitch, the shake and the stiff key follow.
func strain() -> float:
	return turns / limit


## Turns at which the spring really gives; assist forgives a few more.
func burst_turns() -> float:
	return limit + (ASSIST_SLACK if assisted else 0.0)


## Every turn is worth half a metre; turns wound blind past the cover count double.
func metres(wound: float) -> float:
	var daring := maxf(0.0, wound - GAUGE_TURNS * COVER_FROM)
	return (wound + daring) * METRES_PER_TURN * float(variant.get("coast", 1.0))


func _next_dash() -> void:
	dash += 1
	turns = 0.0
	distance = 0.0
	beat_rival = false
	press_at = -99.0
	limit = GAUGE_TURNS * rng.randf_range(lerpf(LIMIT_LOW_EARLY, LIMIT_LOW_LATE, heat()), 1.0)
	rival_turns = 0.0
	if dash >= RIVAL_FROM_DASH:
		rival_turns = RIVAL_TURNS[mini(dash - RIVAL_FROM_DASH, RIVAL_TURNS.size() - 1)]
	_phase("wind")


func _launch() -> void:
	distance = metres(turns)
	# A waxed floor carries the toy farther, and the long slide costs time.
	var coast := float(variant.get("coast", 1.0))
	run_seconds = (RUN_SECONDS + metres(turns) / coast * RUN_SECONDS_PER_METRE) * coast * coast
	_phase("run")
	sound(76)


func _land() -> void:
	dashes_done += 1
	best = maxf(best, distance)
	last_points = roundi(distance * POINTS_PER_METRE * float(variant.get("worth", 1.0)))
	beat_rival = rival_turns > 0.0 and turns > rival_turns
	if beat_rival:
		rivals_beaten += 1
		last_points += RIVAL_BONUS
		add_score(last_points, "贏過對手！+%d" % last_points)
		sound(88)
	else:
		add_score(last_points, "%.1f 公尺 +%d" % [distance, last_points])
		sound(81)
	_phase("rest")


func _burst() -> void:
	bursts += 1
	distance = 0.0
	last_points = 0
	sound(48)
	# The first pop of a round is a free look at where greed leads.
	if bursts > 1:
		add_mistake("彈簧爆了！")
	else:
		say("彈簧爆了！", false)
	_phase("burst")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
