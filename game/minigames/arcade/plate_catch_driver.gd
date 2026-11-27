extends "res://game/minigames/arcade/arcade_driver.gd"
## 接飛碟: plates fly in from both wings on arcs toward the clown's hands; press
## as one passes through the gold ring and he stacks it on the tower on his
## head. Plates come faster, in pairs and mixed with custard pies that must be
## let through. A missed plate brings the whole tower down on his head. Rules
## only: the picture lives in plate_catch_view.gd.

const View = preload("res://game/minigames/arcade/plate_catch_view.gd")
## Seconds either side of a plate's arrival that still catch it; perfect is tighter.
const CATCH_WINDOW := 0.11
const PERFECT_WINDOW := 0.045
const FLIGHT_EARLY := 1.7
const FLIGHT_LATE := 0.95
const GAP_EARLY := 1.45
const GAP_LATE := 0.72
## A pair's second plate lands this long after the first, from the other wing.
const PAIR_GAP := 0.42
const PIE_FROM_HEAT := 0.2
const PAIR_FROM_HEAT := 0.3
const CATCH_POINTS := 10
const STACK_BONUS := 2
const STACK_BONUS_CAP := 10
const PERFECT_BONUS := 5
const PIE_DODGE_POINTS := 10
## Hands are busy this long after a grab at nothing.
const FUMBLE_SECONDS := 0.3
const TOPPLE_SECONDS := 1.5
## Flights left after a miss keep going this long before they smash offstage.
const OVERSHOOT_SECONDS := 0.35
const DEMO_ARRIVAL := 1.45

## Every thing in the air: {kind "plate"|"pie", side -1 left|1 right, launched,
## arrival, flight, apex, lane}. Removed once caught, dodged or smashed.
var flying: Array[Dictionary] = []
## Plates stacked on the clown's head.
var tower := 0
var best_tower := 0
var caught := 0
var perfects := 0
var topples := 0
var pies_dodged := 0
var pies_eaten := 0
## "play" or "topple" (the tower is down; nothing is thrown).
var mood := "play"
var mood_at := -99.0
## Why the tower fell: "miss" or "pie".
var fall_reason := ""
## How many plates fell with it, and which wing the missed plate came from.
var fallen := 0
var fall_side := 0
var catch_at := -99.0
var fumble_at := -99.0
var last_points := 0
var last_perfect := false
var _next_launch := 0.0
var _last_was_pie := false


func _init() -> void:
	verb = "飛碟到圈裡就按，派要放過！"
	hint = [["空白鍵", "接飛碟"]]
	round_seconds = 45.0
	thresholds = [250, 600, 950]
	verdicts = [
		"小丑頭上只剩一頭奶油。",
		"銅牌！盤子有接到，碎的不算太多。",
		"銀牌！盤塔晃得觀眾都不敢呼吸。",
		"金牌！小丑頂著一座盤子塔謝幕。",
	]
	variants = [
		{"id": "standard", "label": "標準飛碟", "pies": 0.18, "pairs": 1.0, "arc": 1.0},
		{"id": "pies", "label": "奶油派大放送", "pies": 0.34, "pairs": 1.0, "arc": 1.0},
		{"id": "pairs", "label": "成雙飛碟", "pies": 0.14, "pairs": 2.0, "arc": 1.0},
		{"id": "high", "label": "高拋飛碟", "pies": 0.18, "pairs": 1.0, "arc": 1.7},
	]
	score_label = "接盤得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	flying.clear()
	tower = 0
	best_tower = 0
	caught = 0
	perfects = 0
	topples = 0
	pies_dodged = 0
	pies_eaten = 0
	_set_mood("play")
	catch_at = -99.0
	fumble_at = -99.0
	_last_was_pie = false
	# The countdown throws one plate that the clown catches by himself.
	_launch("plate", 1, 0.0, DEMO_ARRIVAL)


func _warm_up(_delta: float) -> void:
	for thing in flying.duplicate():
		if clock >= float(thing.arrival):
			flying.erase(thing)
			tower = 1
			catch_at = clock
			sound(72)


func _go() -> void:
	flying.clear()
	tower = 0
	catch_at = -99.0
	_next_launch = 0.35


func _tick(_delta: float) -> void:
	if mood == "topple":
		if clock - mood_at >= TOPPLE_SECONDS:
			_set_mood("play")
			_next_launch = play_time + 0.25
		return
	for thing in flying.duplicate():
		var late: float = clock - float(thing.arrival)
		if late <= window(CATCH_WINDOW):
			continue
		if thing.kind == "pie":
			flying.erase(thing)
			pies_dodged += 1
			add_score(PIE_DODGE_POINTS, "放過了！+%d" % PIE_DODGE_POINTS)
			sound(64)
		else:
			_topple("miss", int(thing.side))
			return
	if play_time >= _next_launch:
		_throw()


func _press(button: StringName) -> void:
	if button != &"action" or mood != "play":
		return
	if clock - fumble_at < FUMBLE_SECONDS:
		return
	var target := _in_ring()
	if target.is_empty():
		fumble_at = clock
		if tower > 0:
			tower -= 1
			say("手滑！", false)
		sound(50)
		return
	flying.erase(target)
	if target.kind == "pie":
		pies_eaten += 1
		_topple("pie", int(target.side))
		return
	var off := absf(clock - float(target.arrival))
	last_perfect = off <= window(PERFECT_WINDOW)
	last_points = CATCH_POINTS + STACK_BONUS * mini(tower, STACK_BONUS_CAP) + (PERFECT_BONUS if last_perfect else 0)
	tower += 1
	best_tower = maxi(best_tower, tower)
	caught += 1
	perfects += int(last_perfect)
	catch_at = clock
	add_score(last_points, ("漂亮！+%d" if last_perfect else "+%d") % last_points)
	sound(67 + mini(tower, 12))


## The clock ran out: whatever is still in the air is simply put away.
func _round_over() -> void:
	flying.clear()


func _snapshot(into: Dictionary) -> void:
	into.flying = flying
	into.tower = tower
	into.best_tower = best_tower
	into.mood = mood
	into.mood_at = mood_at
	into.fall_reason = fall_reason
	into.fallen = fallen
	into.fall_side = fall_side
	into.catch_at = catch_at
	into.fumble_at = fumble_at
	into.last_perfect = last_perfect
	into.catch_window = window(CATCH_WINDOW)


## The flight whose arrival is closest to now, if it is inside the catch window.
func _in_ring() -> Dictionary:
	var best: Dictionary = {}
	var nearest := window(CATCH_WINDOW)
	for thing in flying:
		var off := absf(clock - float(thing.arrival))
		if off <= nearest:
			nearest = off
			best = thing
	return best


func _throw() -> void:
	var flight := lerpf(FLIGHT_EARLY, FLIGHT_LATE, heat()) / pace(1.0)
	var side := -1 if rng.randf() < 0.5 else 1
	var first := _pick_kind()
	_launch(first, side, clock, clock + flight)
	# Assist slows each flight but keeps the rhythm, so it never costs plates.
	var gap := lerpf(GAP_EARLY, GAP_LATE, heat()) * rng.randf_range(0.85, 1.15)
	var pair_chance := clampf((heat() - PAIR_FROM_HEAT) * 1.3, 0.0, 0.7) * float(variant.pairs)
	if float(variant.pairs) > 1.0:
		pair_chance = maxf(pair_chance, 0.35)
	if rng.randf() < pair_chance:
		var second := _pick_kind()
		_launch(second, -side, clock + 0.1, clock + flight + PAIR_GAP)
		gap += PAIR_GAP
	_next_launch = play_time + gap


func _pick_kind() -> String:
	var pie := not _last_was_pie and heat() >= PIE_FROM_HEAT and rng.randf() < float(variant.pies)
	_last_was_pie = pie
	return "pie" if pie else "plate"


func _launch(kind: String, side: int, launched: float, arrival: float) -> void:
	var arc := float(variant.get("arc", 1.0))
	flying.append({"kind": kind, "side": side, "launched": launched, "arrival": arrival,
		"flight": arrival - launched, "apex": rng.randf_range(60.0, 170.0) * arc, "lane": rng.randf_range(-1.0, 1.0)})


func _topple(reason: String, side: int) -> void:
	fall_reason = reason
	fall_side = side
	fallen = tower
	topples += 1
	tower = 0
	flying.clear()
	sound(45)
	var line := "滿臉奶油！" if reason == "pie" else "盤塔倒了！"
	# A pie in the face is always a mistake; the first dropped plate is a free lesson.
	if reason == "pie" or topples > 1:
		add_mistake(line)
	else:
		say(line, false)
	_set_mood("topple")


func _set_mood(next_mood: String) -> void:
	mood = next_mood
	mood_at = clock
