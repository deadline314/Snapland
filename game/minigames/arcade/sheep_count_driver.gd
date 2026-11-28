extends "res://game/minigames/arcade/arcade_driver.gd"
## 窗簾星圖: the traveller lies in bed counting the sheep that jump the fence
## outside the window. Press the button as each real sheep sails over the
## fence and it is stitched onto the curtain as a star; eight stars make a
## constellation. Ghost sheep join the flock: counting one, or pressing with no
## sheep over the fence, is a miscount. The flock runs faster and faster, and
## the ghost sheep disguise themselves better (but a ghost never casts a
## shadow). Miscount and the traveller nods off in a stream of Zzz and rolls
## out of bed. Rules only: the picture lives in sheep_count_view.gd.
##
## Sheep run from x = 0 (left edge) to 1 (right edge); the fence is at FENCE.

const View = preload("res://game/minigames/arcade/sheep_count_view.gd")
const FENCE := 0.5
## Seconds a sheep takes to cross the window early and late, and between sheep.
const CROSS_FIRST := 3.0
const CROSS_LAST := 1.6
const GAP_FIRST := 1.3
const GAP_LAST := 0.55
## A press counts within this many seconds of a sheep topping the fence.
const WINDOW := 0.2
const DEAD_ON := 0.07
const GHOST_HEAT := 0.15
const PAIR_HEAT := 0.35
const DOZE_SECONDS := 1.7
const CONSTELLATION := 8
const COUNT_POINTS := 20
const DEAD_ON_POINTS := 10
const STAR_POINTS := 50
const STREAK_POINTS := 2
const STREAK_CAP := 10

## Sheep on the way: {born, cross (seconds), ghost, disguise (0..1), counted,
## miscounted}. A sheep tops the fence at born + cross * FENCE.
var sheep: Array[Dictionary] = []
var counted := 0
var stars := 0
var constellations := 0
var miscounts := 0
var missed := 0
var streak := 0
var doze_at := -99.0
var last_count := -99.0
var _next_sheep := 0.0
var _demo := false


func _init() -> void:
	verb = "真的羊跳過柵欄時按一下數羊，小鬼羊別數！"
	hint = [["空白鍵", "數一隻"]]
	round_seconds = 45.0
	thresholds = [300, 800, 1400]
	verdicts = [
		"你比羊先睡著了。",
		"銅牌！數著數著差點睡著。",
		"銀牌！窗簾上的星星亮成一片。",
		"金牌！小鬼羊一隻也騙不了你。",
	]
	variants = [
		{"id": "standard", "label": "數羊之夜"},
		{"id": "herd", "label": "羊群大遷徙", "pairs": 0.45, "pair_heat": 0.12},
		{"id": "ghostly", "label": "鬼羊派對", "ghosts": 0.45, "ghost_heat": 0.05, "disguise": 0.35},
	]
	score_label = "數羊得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_meadow()
	sheep.append(_sheep(clock - 0.4, CROSS_FIRST, false))


## The countdown counts the first sheep by itself.
func _warm_up(_delta: float) -> void:
	for one in sheep:
		if not bool(one.counted) and absf(clock - top_time(one)) < 0.02:
			_count()
	_drop_gone()


func _go() -> void:
	_demo = false
	_reset_meadow()


func _tick(_delta: float) -> void:
	for one in sheep:
		if not bool(one.ghost) and not bool(one.counted) and not bool(one.missed) and clock > top_time(one) + window(WINDOW):
			one.missed = true
			missed += 1
			streak = 0
	_drop_gone()
	if clock >= _next_sheep and not dozing():
		_spawn()


func _press(button: StringName) -> void:
	if button == &"action" or button == &"up":
		_count()


## No input, no points (a flock nobody counts scores nothing anyway).
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _snapshot(into: Dictionary) -> void:
	into.sheep = sheep
	into.fence = FENCE
	into.stars = stars
	into.constellation = CONSTELLATION
	into.constellations = constellations
	into.counted = counted
	into.doze_at = doze_at
	into.doze_seconds = DOZE_SECONDS
	into.last_count = last_count
	into.streak = streak


func top_time(one: Dictionary) -> float:
	return float(one.born) + float(one.cross) * FENCE


func cross_seconds() -> float:
	return lerpf(CROSS_FIRST, CROSS_LAST, heat()) * (ASSIST_WINDOW if assisted else 1.0)


func dozing() -> bool:
	return clock - doze_at < DOZE_SECONDS


## Where a sheep is across the window, 0..1.
func sheep_x(one: Dictionary) -> float:
	return (clock - float(one.born)) / float(one.cross)


func _count() -> void:
	if dozing():
		return
	# The sheep nearest the top of its jump within the window, if any.
	var best: Dictionary = {}
	var best_gap := INF
	for one in sheep:
		if bool(one.counted) or bool(one.miscounted):
			continue
		var gap := absf(clock - top_time(one))
		if gap <= window(WINDOW) and gap < best_gap:
			best_gap = gap
			best = one
	if best.is_empty() or bool(best.ghost):
		if not best.is_empty():
			best.miscounted = true
		_doze()
		return
	best.counted = true
	last_count = clock
	streak += 1
	sound(72 + mini(streak, 12))
	if _demo:
		return
	counted += 1
	stars += 1
	var dead_on := best_gap <= window(DEAD_ON)
	var points := COUNT_POINTS + (DEAD_ON_POINTS if dead_on else 0) + mini(streak, STREAK_CAP) * STREAK_POINTS
	add_score(points, ("剛好！%d 隻" if dead_on else "%d 隻") % counted)
	if stars >= CONSTELLATION:
		stars = 0
		constellations += 1
		add_score(STAR_POINTS, "星座完成！+%d" % STAR_POINTS)
		sound(86)


func _doze() -> void:
	doze_at = clock
	streak = 0
	sound(50)
	sound(45)
	if _demo:
		return
	miscounts += 1
	# The first miscount of a round is a free look.
	funny_fail("數錯，先睡著了！", miscounts > 1)
	# The sheep in flight carry on; new ones wait until the traveller is back.
	_next_sheep = clock + DOZE_SECONDS


func _spawn() -> void:
	var ghost := heat() >= float(variant.get("ghost_heat", GHOST_HEAT)) and rng.randf() < float(variant.get("ghosts", 0.3))
	sheep.append(_sheep(clock, cross_seconds() * rng.randf_range(0.92, 1.08), ghost))
	# Later, sheep sometimes come in close pairs, real and ghost mixed.
	if heat() >= float(variant.get("pair_heat", PAIR_HEAT)) and rng.randf() < float(variant.get("pairs", 0.25)):
		sheep.append(_sheep(clock + window(WINDOW) * 2.2, cross_seconds(), not ghost if rng.randf() < 0.6 else ghost))
	_next_sheep = clock + lerpf(GAP_FIRST, GAP_LAST, heat()) * rng.randf_range(0.85, 1.25) * (ASSIST_WINDOW if assisted else 1.0)
	sound(60)


func _drop_gone() -> void:
	while not sheep.is_empty() and sheep_x(sheep[0]) > 1.15:
		sheep.pop_front()


func _reset_meadow() -> void:
	sheep.clear()
	counted = 0
	stars = 0
	constellations = 0
	miscounts = 0
	missed = 0
	streak = 0
	doze_at = -99.0
	last_count = -99.0
	_next_sheep = clock + 0.4


func _sheep(born: float, cross: float, ghost: bool) -> Dictionary:
	var disguise := clampf(heat() * 0.8 + float(variant.get("disguise", 0.0)), 0.0, 1.0) if ghost else 0.0
	return {"born": born, "cross": cross, "ghost": ghost, "disguise": disguise, "counted": false, "miscounted": false, "missed": false}
