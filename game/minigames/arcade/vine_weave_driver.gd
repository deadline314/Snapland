extends "res://game/minigames/arcade/arcade_driver.gd"
## 藤蔓編路: a vine tip keeps growing up a bamboo trellis. Hold ← or → to
## steer it; each crossbar has one gap, and the tip must thread it. Some gaps
## open and shut like a leafy shutter, butterflies rest in the way (brush one
## and the vine stalls while it flutters off), and the vine grows faster and
## faster. Every eighth bar it reaches a skylight and flowers. Hit a bar and
## the vine whips back down and ties the traveller up in a bow.
## Rules only: the picture lives in vine_weave_view.gd.
##
## x runs 0 (left) to 1 (right) across the trellis; heights are in bars
## (bar k sits at height k + 1).

const View = preload("res://game/minigames/arcade/vine_weave_view.gd")
## Bars per second of growth at the start and the end of play.
const GROW_FIRST := 0.6
const GROW_LAST := 1.15
## Sideways steering: top speed (trellis widths per second) and how fast it
## builds up and dies away.
const STEER := 0.75
const STEER_RESPONSE := 9.0
const LEFT_EDGE := 0.06
const RIGHT_EDGE := 0.94
const TIP := 0.018
## Gap widths early and late; a breathing gap swings this much either way.
const GAP_FIRST := 0.26
const GAP_LAST := 0.17
const BREATH := 0.35
const BREATH_HEAT := 0.25
const BUTTERFLY_HEAT := 0.3
const BUTTERFLY_REACH := 0.045
const STALL_SECONDS := 0.6
const PASS_POINTS := 10
const CENTRE_POINTS := 5
const STREAK_POINTS := 2
const STREAK_CAP := 10
const SKYLIGHT_EVERY := 8
const SKYLIGHT_POINTS := 60
const TANGLE_SECONDS := 1.8
const SKYLIGHT_SECONDS := 1.2
## How many bars ahead are planned.
const AHEAD := 6
const START_X := 0.5
## The next gap sits at least this far to the side of the last one.
const MIN_SHIFT := 0.2

## The tip: x across the trellis and height in bars.
var tip_x := 0.5
var tip_y := 0.0
var drift := 0.0
## The vine's path so far, oldest first: Vector2(x, height), one point every
## tenth of a bar, kept for the last four bars.
var path: Array[Vector2] = []
## Planned bars: {height, x, width, breathe, phase, sway, butterflies: [x]}.
var bars: Array[Dictionary] = []
## The last crash: {x, height, at}; the last skylight: {height, at}.
var tangle: Dictionary = {}
var skylight: Dictionary = {}
var stalled_at := -99.0
var passed := 0
var streak := 0
var crashes := 0
var bumps := 0
var skylights := 0

var _left := 0
var _right := 0
var _next_bar := 1
var _demo := false
var _steered := false
var _last_mark := 0.0


func _init() -> void:
	verb = "左右引導藤蔓，穿過棚架的空隙爬上天窗！"
	hint = [["← →", "引導藤蔓"]]
	round_seconds = 45.0
	thresholds = [240, 600, 950]
	verdicts = [
		"藤蔓決定在地上當地毯。",
		"銅牌！藤蔓爬得歪歪扭扭，但有爬上去。",
		"銀牌！棚架上開出一整排綠色隧道。",
		"金牌！天窗外的蝴蝶都來看你編的路。",
	]
	variants = [
		{"id": "standard", "label": "晨間棚架"},
		{"id": "sway", "label": "搖擺棚架", "sway": 0.08},
		{"id": "butterflies", "label": "蝴蝶季", "butterflies": 2},
	]
	score_label = "編路得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_steered = false
	_demo = true
	_reset_vine()


## The countdown grows the vine up through the first gap by itself.
func _warm_up(delta: float) -> void:
	var ahead := _bar_after(tip_y)
	var side := 0
	if not ahead.is_empty():
		side = signi(roundi((gap_x(ahead) - tip_x) * 40.0))
	_steer(delta, side)
	_grow(delta * 0.8)


func _go() -> void:
	# Play starts from the bottom in the middle with the first gap off to one
	# side and a full bar of room: the first move is always the player's, and a
	# vine left alone runs into the very first bar.
	_demo = false
	_reset_vine()


func _tick(delta: float) -> void:
	_steer(delta, _right - _left if _right != _left else 0)
	_grow(delta)


func _press(button: StringName) -> void:
	if button == &"left" or button == &"right":
		_steered = true
	if button == &"left":
		_left += 1
	elif button == &"right":
		_right += 1


func _release(button: StringName) -> void:
	if button == &"left":
		_left = maxi(0, _left - 1)
	elif button == &"right":
		_right = maxi(0, _right - 1)


## No input, no points: until the player has steered this round, nothing that
## happens on its own (a gust, a gap sliding over the tip) scores.
func add_score(points: int, word := "") -> void:
	if _steered:
		super(points, word)


func _round_over() -> void:
	_left = 0
	_right = 0


func _snapshot(into: Dictionary) -> void:
	into.tip_x = tip_x
	into.tip_y = tip_y
	into.drift = drift
	into.path = path
	var shown: Array[Dictionary] = []
	for bar in bars:
		shown.append({"height": bar.height, "x": gap_x(bar), "width": gap_width(bar), "breathe": bar.breathe, "butterflies": bar.butterflies, "skylight": int(bar.height) % SKYLIGHT_EVERY == 0})
	into.bars = shown
	into.tangle = tangle
	into.skylight = skylight
	into.tangle_seconds = TANGLE_SECONDS
	into.skylight_seconds = SKYLIGHT_SECONDS
	into.stalled_at = stalled_at
	into.stall_seconds = STALL_SECONDS
	into.streak = streak
	into.tip_radius = TIP
	into.butterfly_reach = BUTTERFLY_REACH
	into.skylight_every = SKYLIGHT_EVERY


func growth() -> float:
	return pace(lerpf(GROW_FIRST, GROW_LAST, heat()))


func gap_x(bar: Dictionary) -> float:
	var sway := float(bar.sway)
	return clampf(float(bar.x) + sway * sin(clock * 1.3 + float(bar.phase)), 0.15, 0.85)


func gap_width(bar: Dictionary) -> float:
	var width := float(bar.width)
	if bool(bar.breathe):
		width *= 1.0 + BREATH * sin(clock * 2.2 + float(bar.phase))
	return width * (ASSIST_WINDOW if assisted else 1.0)


func busy() -> bool:
	return (not tangle.is_empty() and clock - float(tangle.at) < TANGLE_SECONDS) or clock - stalled_at < STALL_SECONDS


func _steer(delta: float, side: int) -> void:
	drift = lerpf(drift, STEER * side, 1.0 - exp(-STEER_RESPONSE * delta))
	tip_x = clampf(tip_x + drift * delta, LEFT_EDGE, RIGHT_EDGE)


func _grow(delta: float) -> void:
	if busy():
		return
	var before := tip_y
	tip_y += growth() * delta
	if tip_y - _last_mark >= 0.1:
		_last_mark = tip_y
		path.append(Vector2(tip_x, tip_y))
		while path.size() > 40:
			path.pop_front()
	for bar: Dictionary in bars.duplicate():
		var height := float(bar.height)
		for butterfly: float in bar.butterflies.duplicate():
			var at := height - 0.5
			if before < at and tip_y >= at and absf(tip_x - butterfly) < BUTTERFLY_REACH:
				bar.butterflies.erase(butterfly)
				_bump()
				return
		if before < height and tip_y >= height:
			var centre := gap_x(bar)
			var off := absf(tip_x - centre)
			if off > gap_width(bar) * 0.5 - TIP:
				_crash(bar)
				return
			_pass(bar, off < gap_width(bar) * 0.25)
	while _next_bar <= ceili(tip_y) + AHEAD:
		_plan_bar(_next_bar)
		_next_bar += 1
	while not bars.is_empty() and float(bars[0].height) < tip_y - 2.0:
		bars.pop_front()


func _pass(bar: Dictionary, centred: bool) -> void:
	streak += 1
	sound(70 + mini(streak, 12))
	if _demo:
		return
	passed += 1
	var points := PASS_POINTS + (CENTRE_POINTS if centred else 0) + mini(streak, STREAK_CAP) * STREAK_POINTS
	add_score(points)
	if int(bar.height) % SKYLIGHT_EVERY == 0:
		skylights += 1
		skylight = {"height": bar.height, "at": clock}
		add_score(SKYLIGHT_POINTS, "爬到天窗！+%d" % (points + SKYLIGHT_POINTS))
		sound(84)


func _bump() -> void:
	stalled_at = clock
	streak = 0
	sound(62)
	if _demo:
		return
	bumps += 1
	say("蝴蝶飛走了！", false)


func _crash(bar: Dictionary) -> void:
	tangle = {"x": tip_x, "height": float(bar.height), "at": clock}
	streak = 0
	sound(48)
	sound(43)
	# The vine starts again from where it hit, a little below the bar.
	tip_y = float(bar.height) - 0.6
	drift = 0.0
	_last_mark = tip_y
	path.append(Vector2(tip_x, tip_y))
	if _demo:
		return
	crashes += 1
	# The first tangle of a round is a free look at the bow.
	funny_fail("打結了！", crashes > 1)


func _reset_vine() -> void:
	bars.clear()
	path.clear()
	tangle = {}
	skylight = {}
	stalled_at = -99.0
	passed = 0
	streak = 0
	crashes = 0
	bumps = 0
	skylights = 0
	_left = 0
	_right = 0
	_next_bar = 1
	tip_y = 0.0
	tip_x = START_X
	drift = 0.0
	_last_mark = 0.0
	while _next_bar <= AHEAD:
		_plan_bar(_next_bar)
		_next_bar += 1
	tip_x = START_X
	path.append(Vector2(tip_x, tip_y))


## Plan bar `height`: a gap within reach of the last one, narrower later;
## breathing gaps and butterflies once the round warms up.
func _plan_bar(height: int) -> void:
	var previous := float(bars.back().x) if not bars.is_empty() else START_X
	# The next gap is never further than the vine can steer in one bar's growth.
	var reach := STEER * 0.7 / lerpf(GROW_FIRST, GROW_LAST, heat())
	# ...and never straight above it, so a vine left alone runs into the bar.
	var shift := rng.randf_range(MIN_SHIFT, maxf(MIN_SHIFT, reach))
	var x := previous + shift * (-1.0 if rng.randf() < 0.5 else 1.0)
	if x < 0.2 or x > 0.8:
		x = previous - (x - previous)
	x = clampf(x, 0.2, 0.8)
	var width := lerpf(GAP_FIRST, GAP_LAST, heat())
	var breathe := heat() >= BREATH_HEAT and not _demo and rng.randf() < 0.45
	var butterflies: Array = []
	if heat() >= BUTTERFLY_HEAT and not _demo and height > 2:
		var count := int(variant.get("butterflies", 1))
		for wing in count:
			if rng.randf() < 0.4:
				# Rest off the straight line between the two gaps, so there is
				# always a way round.
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				butterflies.append(clampf((previous + x) * 0.5 + side * rng.randf_range(0.08, 0.2), 0.1, 0.9))
	bars.append({"height": height, "x": x, "width": width, "breathe": breathe, "phase": rng.randf() * TAU,
		"sway": float(variant.get("sway", 0.0)) if not _demo else 0.0, "butterflies": butterflies})


func _bar_after(height: float) -> Dictionary:
	for bar in bars:
		if float(bar.height) > height:
			return bar
	return {}
