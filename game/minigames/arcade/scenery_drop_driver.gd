extends "res://game/minigames/arcade/arcade_driver.gd"
## 舞台換景: an actor hams it up on the little stage while the ringmaster shouts
## the next scene; the player pulls that backdrop down from the flies with its
## direction (↑ moonlit night, ← forest, → castle, ↓ seaside). Calls come faster;
## later he shouts two at once (both come down, half each) or starts on the
## wrong one and corrects himself. A wrong backdrop crashes down on the actor,
## who walks out from behind it flattened into a paper cut-out; too slow and the
## audience boos. Rules only: the picture lives in scenery_drop_view.gd.

const View = preload("res://game/minigames/arcade/scenery_drop_view.gd")
const SCENES := {&"up": "moon", &"left": "forest", &"right": "castle", &"down": "sea"}
const NAMES := {"moon": "月夜", "forest": "森林", "castle": "城堡", "sea": "海邊"}
## Seconds to answer a call, early and late in the round; a double call gets more.
const WINDOW_EARLY := 2.4
const WINDOW_LATE := 1.1
const DOUBLE_WINDOW := 1.6
## Pause after a call is settled before the next one.
const GAP_EARLY := 1.0
const GAP_LATE := 0.3
## How long a slip of the tongue shows before he corrects it.
const SLIP_SECONDS := 0.8
const CRASH_SECONDS := 2.4
const BOO_SECONDS := 1.3
## Every backdrop is worth this, plus up to SPEED_BONUS for a quick pull and
## STREAK_BONUS for each call in a row (up to five).
const POINTS := 10
const SPEED_BONUS := 10
const STREAK_BONUS := 2
const STREAK_CAP := 5
## Each cloth of a double call earns this share; waiting out a slip earns a bonus.
const DOUBLE_SHARE := 0.6
const SLIP_BONUS := 10
const NOTES := {"moon": 72, "forest": 67, "castle": 76, "sea": 64}

## "wait" (between calls), "call" (waiting for the pull), "crash" or "boo".
var phase := "wait"
var phase_at := 0.0
## The call being answered: {scenes (still to pull), shouted (all), slip ("" or
## the scene he says first), fixed_at, at, until}; empty between calls.
var cue: Dictionary = {}
## Backdrops hanging now: {scene, at, slot "full"|"left"|"right"}.
var hanging: Array[Dictionary] = []
## Backdrops flying back up: {scene, at, slot}.
var lifting: Array[Dictionary] = []
var crash_scene := ""
var streak := 0
var drops := 0
var crashes := 0
var boos := 0
var _next_call := 0.0


func _init() -> void:
	verb = "旁白喊哪一景，就按那個方向放下布景！"
	hint = [["↑ ← → ↓", "放下那片布景"]]
	round_seconds = 50.0
	thresholds = [200, 550, 900]
	verdicts = [
		"演員被砸成紙片人，謝幕時還是扁的。",
		"銅牌！布景有掉下來，觀眾很捧場。",
		"銀牌！換景快到演員來不及換台詞。",
		"金牌！旁白喊完布景就到，像變魔術。",
	]
	variants = [
		{"id": "standard", "label": "首演之夜", "doubles": 0.25, "double_from": 0.4, "slips": 0.2, "slip_from": 0.3},
		{"id": "doubles", "label": "雙景連演", "doubles": 0.5, "double_from": 0.12, "slips": 0.1, "slip_from": 0.4},
		{"id": "slips", "label": "口誤旁白", "doubles": 0.12, "double_from": 0.45, "slips": 0.45, "slip_from": 0.12},
	]
	score_label = "換景得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	phase = "wait"
	phase_at = 0.0
	cue = {}
	hanging.clear()
	lifting.clear()
	crash_scene = ""
	streak = 0
	drops = 0
	crashes = 0
	boos = 0


## The countdown shows the idea: he shouts the forest and it comes down by itself.
func _warm_up(_delta: float) -> void:
	if cue.is_empty() and hanging.is_empty() and clock >= 0.4:
		cue = {"scenes": ["forest"], "shouted": ["forest"], "slip": "", "fixed_at": clock, "at": clock, "until": clock + 99.0}
	elif not cue.is_empty() and clock >= 1.4:
		cue = {}
		hanging = [{"scene": "forest", "at": clock, "slot": "full"}]
		sound(NOTES.forest)


func _go() -> void:
	cue = {}
	_phase("wait")
	_next_call = 0.3


func _tick(_delta: float) -> void:
	for cloth in lifting.duplicate():
		if clock - float(cloth.at) > 1.0:
			lifting.erase(cloth)
	match phase:
		"wait":
			if play_time >= _next_call:
				_call()
		"call":
			if clock >= float(cue.until):
				_boo()
		"crash":
			if clock - phase_at >= CRASH_SECONDS:
				_rest()
		"boo":
			if clock - phase_at >= BOO_SECONDS:
				_rest()


func _press(button: StringName) -> void:
	if not SCENES.has(button) or phase != "call":
		return
	var scene: String = SCENES[button]
	var waiting: Array = cue.scenes
	if not str(cue.slip).is_empty() and clock < float(cue.fixed_at) and scene == str(cue.slip):
		_crash(scene, "上當了！")
	elif waiting.has(scene):
		_drop(scene)
	elif not (cue.shouted as Array).has(scene):
		_crash(scene, "放錯了！")


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.cue = cue
	into.hanging = hanging
	into.lifting = lifting
	into.crash_scene = crash_scene
	into.streak = streak


func call_window() -> float:
	return window(lerpf(WINDOW_EARLY, WINDOW_LATE, heat()))


func gap() -> float:
	return lerpf(GAP_EARLY, GAP_LATE, heat())


func _call() -> void:
	var pool: Array = NAMES.keys()
	for cloth in hanging:
		if hanging.size() == 1:
			pool.erase(cloth.scene)
	var first: String = pool[rng.randi() % pool.size()]
	var shouted := [first]
	var slip := ""
	var length := call_window()
	var doubles := heat() >= float(variant.double_from) and rng.randf() < float(variant.doubles)
	var slips := not doubles and heat() >= float(variant.slip_from) and rng.randf() < float(variant.slips)
	if doubles:
		var others: Array = NAMES.keys()
		others.erase(first)
		shouted.append(others[rng.randi() % others.size()])
		length *= DOUBLE_WINDOW
	elif slips:
		var others: Array = NAMES.keys()
		others.erase(first)
		slip = others[rng.randi() % others.size()]
		length += SLIP_SECONDS
	cue = {"scenes": shouted.duplicate(), "shouted": shouted, "slip": slip, "fixed_at": clock + (SLIP_SECONDS if slips else 0.0),
		"at": clock, "until": clock + length, "length": length}
	_phase("call")
	sound(NOTES[slip if slips else first])


func _drop(scene: String) -> void:
	var shouted: Array = cue.shouted
	var waiting: Array = cue.scenes
	waiting.erase(scene)
	if waiting.size() == shouted.size() - 1:
		# The first cloth of a call replaces whatever hung before.
		for cloth in hanging:
			lifting.append({"scene": cloth.scene, "at": clock, "slot": cloth.slot})
		hanging.clear()
	var slot := "full"
	if shouted.size() == 2:
		slot = "left" if waiting.size() == 1 else "right"
	hanging.append({"scene": scene, "at": clock, "slot": slot})
	drops += 1
	# Quickness counts from the moment the right name is out.
	var quick := clampf((float(cue.until) - clock) / maxf(0.1, float(cue.until) - float(cue.fixed_at)), 0.0, 1.0)
	var points := POINTS + roundi(SPEED_BONUS * quick) + STREAK_BONUS * mini(streak, STREAK_CAP)
	if shouted.size() == 2:
		points = roundi(points * DOUBLE_SHARE)
	var slipped := not str(cue.slip).is_empty()
	if slipped:
		points += SLIP_BONUS
	sound(NOTES[scene])
	if waiting.is_empty():
		streak += 1
		var word := "沒上當！+%d" % points if slipped else ("好！+%d" % points if quick > 0.5 else "+%d" % points)
		add_score(points, word)
		cue = {}
		_phase("wait")
		_next_call = play_time + gap()
	else:
		add_score(points)


func _crash(scene: String, word: String) -> void:
	crashes += 1
	streak = 0
	crash_scene = scene
	for cloth in hanging:
		lifting.append({"scene": cloth.scene, "at": clock, "slot": cloth.slot})
	hanging.clear()
	cue = {}
	sound(36)
	# The first crash of a round is a free look at the paper actor.
	funny_fail(word, crashes > 1)
	_phase("crash")


func _boo() -> void:
	boos += 1
	streak = 0
	cue = {}
	sound(41)
	add_mistake("噓～")
	_phase("boo")


func _rest() -> void:
	crash_scene = ""
	_phase("wait")
	_next_call = play_time + gap()


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
