extends "res://game/minigames/arcade/arcade_driver.gd"
## 雲梯換層: a course of cloud pads floats over the sky park, each bobbing up and
## down on its own rhythm. Press to hop to the next pad at the moment it is level
## with the one under you; the closer to level, the more it pays. Reach the gate
## at the end of the course for a bonus and a longer, livelier course. Late
## pads shrink away under your feet or get tossed about by gusts. Hop when they
## are not level (or stay on a vanishing pad) and the hero drops into the clouds
## and pops back up with their head coated in cotton candy. Standing still
## scores nothing. Rules only: the picture lives in cloud_hop_view.gd.

const View = preload("res://game/minigames/arcade/cloud_hop_view.gd")
## Pad tops sit around this screen height and bob by up to AMP.
const BASE_Y := 440.0
const AMP_EARLY := 46.0
const AMP_LATE := 72.0
const PERIOD_EARLY := 2.8
const PERIOD_LATE := 1.5
## How close (in pixels) two pads must be to count as level.
const LEVEL_EARLY := 14.0
const LEVEL_LATE := 8.0
const PADS_EARLY := 5
const PADS_LATE := 8
const HOP_SECONDS := 0.32
const FALL_SECONDS := 2.0
const SHRINK_SECONDS := 2.6
const HOP_POINTS := 10
const LEVEL_BONUS := 10
const STREAK_BONUS := 2
const STREAK_CAP := 5
const GATE_BONUS := 30

## "stand", "hop", "fall".
var phase := "stand"
var phase_at := 0.0
## Each pad: {amp, omega, phase, kind "plain"|"shrink"|"windy", stood_at}.
var pads: Array[Dictionary] = []
## Index of the pad under the hero; pads.size() is the gate.
var pad := 0
var hop_from := 0
var courses := 0
var streak := 0
var hops := 0
var falls := 0


func _init() -> void:
	verb = "腳下的雲和下一朵一樣高時，按鍵跳過去！"
	hint = [["空白鍵", "跳"]]
	round_seconds = 45.0
	thresholds = [180, 700, 1400]
	verdicts = [
		"整個人掉進雲裡，頭上頂著一坨棉花糖。",
		"銅牌！有幾朵雲被你踩過了。",
		"銀牌！雲梯一層一層被你爬上去。",
		"金牌！雲還沒對齊，你已經在對面了。",
	]
	variants = [
		{"id": "standard", "label": "雲梯換層", "shrink": 0.25, "windy": 0.2, "from": 0.4},
		{"id": "shrink", "label": "消失雲台", "shrink": 0.6, "windy": 0.1, "from": 0.15},
		{"id": "windy", "label": "大風天", "shrink": 0.1, "windy": 0.6, "from": 0.15},
	]
	score_label = "雲梯得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	courses = 0
	streak = 0
	hops = 0
	falls = 0
	_new_course()


## The countdown shows the idea: the hero waits for two clouds to line up and hops.
func _warm_up(_delta: float) -> void:
	if phase == "hop" and clock - phase_at >= HOP_SECONDS:
		_phase("stand")
	if phase == "stand" and pad == 0 and clock > 0.6 and level_gap() <= LEVEL_EARLY:
		hop_from = pad
		pad += 1
		_phase("hop")


func _go() -> void:
	courses = 0
	_new_course()


func _tick(_delta: float) -> void:
	match phase:
		"hop":
			if clock - phase_at >= HOP_SECONDS:
				_land()
		"fall":
			if clock - phase_at >= FALL_SECONDS:
				# Back on the pad the hero fell from, fresh.
				pads[pad].stood_at = clock
				_phase("stand")
		"stand":
			if _vanished():
				_fall()


func _press(button: StringName) -> void:
	if button != &"action" and button != &"right":
		return
	if phase != "stand":
		return
	var gap := level_gap()
	if gap <= window(level()):
		hop_from = pad
		pad += 1
		var points := HOP_POINTS + roundi(LEVEL_BONUS * (1.0 - gap / window(level()))) + STREAK_BONUS * mini(streak, STREAK_CAP)
		streak += 1
		hops += 1
		add_score(points, "好高度！+%d" % points if gap < level() * 0.35 else "+%d" % points)
		sound(64 + mini(streak, 8) * 2)
		_phase("hop")
	else:
		_fall()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.pad = pad
	into.hop_from = hop_from
	into.count = pads.size()
	var heights: Array[float] = []
	var sizes: Array[float] = []
	var kinds: Array[String] = []
	for index in pads.size():
		heights.append(pad_y(index))
		sizes.append(pad_size(index))
		kinds.append(str(pads[index].kind))
	into.heights = heights
	into.sizes = sizes
	into.kinds = kinds
	into.gap = level_gap()
	into.level = window(level())
	into.streak = streak
	into.courses = courses


## Screen height of a pad's top now; the gate stays level with BASE_Y.
func pad_y(index: int) -> float:
	if index >= pads.size():
		return BASE_Y
	var spec: Dictionary = pads[index]
	var t := clock * float(spec.omega) + float(spec.phase)
	var y := BASE_Y + float(spec.amp) * sin(t)
	if str(spec.kind) == "windy":
		# Gusts toss it about on a second, faster swing.
		y += float(spec.amp) * 0.45 * sin(t * 2.7 + 1.3)
	return y


## 1 for a whole pad, falling to 0 as a shrinking pad vanishes under the hero.
func pad_size(index: int) -> float:
	if index >= pads.size() or str(pads[index].kind) != "shrink" or index != pad or float(pads[index].stood_at) < 0.0:
		return 1.0
	return clampf(1.0 - (clock - float(pads[index].stood_at)) / SHRINK_SECONDS, 0.0, 1.0)


## How far apart (pixels) the pad underfoot and the next one are now.
func level_gap() -> float:
	return absf(pad_y(pad) - pad_y(pad + 1))


func level() -> float:
	return lerpf(LEVEL_EARLY, LEVEL_LATE, heat())


func _vanished() -> bool:
	return pad < pads.size() and str(pads[pad].kind) == "shrink" and pad_size(pad) <= 0.0


func _new_course() -> void:
	courses += 1
	pads.clear()
	var count := roundi(lerpf(PADS_EARLY, PADS_LATE, heat()))
	var odd_from := float(variant.get("from", 0.4))
	for index in count:
		var kind := "plain"
		if index > 0 and heat() >= odd_from:
			var roll := rng.randf()
			if roll < float(variant.shrink):
				kind = "shrink"
			elif roll < float(variant.shrink) + float(variant.windy):
				kind = "windy"
		var period := lerpf(PERIOD_EARLY, PERIOD_LATE, heat()) * rng.randf_range(0.75, 1.3)
		pads.append({"amp": lerpf(AMP_EARLY, AMP_LATE, heat()) * rng.randf_range(0.7, 1.0), "omega": TAU / period,
			"phase": rng.randf() * TAU, "kind": kind, "stood_at": -1.0})
	pad = 0
	hop_from = 0
	pads[0].stood_at = clock
	_phase("stand")


func _land() -> void:
	if pad >= pads.size():
		add_score(GATE_BONUS, "到出口了！+%d" % GATE_BONUS)
		sound(88)
		_new_course()
		return
	pads[pad].stood_at = clock
	_phase("stand")


func _fall() -> void:
	falls += 1
	streak = 0
	sound(40)
	# The first fall of a round is a free look at the cotton-candy head.
	funny_fail("掉進雲裡了！", falls > 1)
	_phase("fall")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
