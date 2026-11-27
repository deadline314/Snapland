extends "res://game/minigames/arcade/arcade_driver.gd"
## 敲敲玩具兵: four sentry boxes, one per arrow, pop out toy soldiers; press
## that arrow to bonk one back in. A sleepy cat sometimes lounges in a doorway
## and must be left alone: bonk it and it snatches your mallet and stalks off
## with it. Later the soldiers come faster, two at once, and some only feint.
## Rules only: the picture lives in soldier_bonk_view.gd.

const View = preload("res://game/minigames/arcade/soldier_bonk_view.gd")
const DOORS: Array[StringName] = [&"up", &"left", &"right", &"down"]
## Seconds between pops at the first and the last second of play.
const GAP_START := 1.05
const GAP_END := 0.5
## Seconds a soldier stays out before it escapes.
const UP_START := 1.2
const UP_END := 0.62
## A feint ducks back in after this long; a cat dozes this long.
const FEINT_SECONDS := 0.32
const CAT_SECONDS := 1.6
const BONK_SECONDS := 0.45
const ESCAPE_SECONDS := 0.5
## Seconds the cat keeps your mallet, and the mallet's recoil after a miss.
const SNATCH_SECONDS := 2.2
const RECOIL_SECONDS := 0.4
## Heat (0..1 through the round) from which pairs, feints and more cats join.
const PAIR_HEAT := 0.35
const PAIR_CHANCE := 0.45
const FEINT_HEAT := 0.5
const FEINT_CHANCE := 0.25
const CAT_START := 0.08
const CAT_END := 0.2
const BONK_POINTS := 10
const STREAK_POINTS := 2
const MAX_STREAK := 5
const QUICK_POINTS := 5
const QUICK_SECONDS := 0.35
## Hammering empty doors costs a little, so mashing every arrow does not pay.
const WHIFF_POINTS := 5
const DEMO_POP := 0.5
const DEMO_BONK := 1.25

## One per door, in DOORS order: {kind ("shut", "soldier", "feint", "cat", "bonked",
## "escaped", "snatch"), at (clock when it began), until (clock when it ends)}
var doors: Array[Dictionary] = []
var streak := 0
var bonks := 0
var escapes := 0
var cat_hits := 0
var whiffs := 0
## The mallet: the door it last swung at, when, and when the cat gives it back.
var swing_door := -1
var swing_at := -99.0
var mallet_back_at := -99.0
var recoil_until := -99.0
var snatch_door := -1

var _next_pop := 0.0
var _demo := false


func _init() -> void:
	verb = "玩具兵冒出來就按那個方向敲回去！貓咪別敲！"
	hint = [["方向鍵", "敲那一扇門"]]
	round_seconds = 45.0
	thresholds = [350, 750, 1100]
	verdicts = [
		"玩具兵佔領了整座城堡。",
		"銅牌！敲是敲到了，貓咪有點不爽。",
		"銀牌！哨兵們開始怕你了。",
		"金牌！玩具城最快的槌子。",
	]
	variants = [
		{"id": "standard", "label": "整隊出操", "worth": 1.0, "pace": 1.0},
		{"id": "double", "label": "雙門齊開", "worth": 0.8, "pace": 1.0, "pairs": true},
		{"id": "catnap", "label": "貓咪巡邏", "worth": 1.25, "pace": 1.0, "cats": 2.0},
		{"id": "drill", "label": "快步操練", "worth": 1.0, "pace": 0.82},
	]
	score_label = "敲敲得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	doors.clear()
	for index in DOORS.size():
		doors.append({"kind": "shut", "at": -99.0, "until": -99.0})
	streak = 0
	bonks = 0
	escapes = 0
	cat_hits = 0
	whiffs = 0
	swing_door = -1
	swing_at = -99.0
	mallet_back_at = -99.0
	recoil_until = -99.0
	snatch_door = -1
	_next_pop = 0.4
	# The countdown pops one soldier from the top door and bonks it by itself.
	_demo = true


func _warm_up(_delta: float) -> void:
	_expire()
	if clock >= DEMO_POP and doors[0].kind == "shut" and swing_at < 0.0:
		_open(0, "soldier", 2.0)
	if clock >= DEMO_BONK and doors[0].kind == "soldier":
		_swing(0)
		_bonk(0)


func _go() -> void:
	_demo = false
	for door in doors:
		door.kind = "shut"
	_next_pop = clock + 0.35


func _tick(_delta: float) -> void:
	_expire()
	if clock >= _next_pop:
		_pop()
		_next_pop = clock + lerpf(GAP_START, GAP_END, heat()) * float(variant.get("pace", 1.0))


func _press(button: StringName) -> void:
	var index := DOORS.find(button)
	if index < 0 or not has_mallet() or clock < recoil_until:
		return
	_swing(index)
	var door: Dictionary = doors[index]
	match str(door.kind):
		"soldier":
			_bonk(index)
		"cat":
			_snatch(index)
		_:
			# Nobody there (or only a feint): the mallet thuds on the roof and bounces.
			whiffs += 1
			streak = 0
			recoil_until = clock + RECOIL_SECONDS
			add_score(-WHIFF_POINTS)
			say("敲空 −%d" % WHIFF_POINTS, false)
			sound(48)


func _snapshot(into: Dictionary) -> void:
	into.doors = doors
	into.streak = streak
	into.swing_door = swing_door
	into.swing_at = swing_at
	into.has_mallet = has_mallet()
	into.mallet_back_at = mallet_back_at
	into.snatch_door = snatch_door
	into.demo = _demo


func has_mallet() -> bool:
	return clock >= mallet_back_at


## Seconds a soldier stays out at this point of the round.
func up_seconds() -> float:
	return window(lerpf(UP_START, UP_END, heat()) * float(variant.get("pace", 1.0)))


func _open(index: int, kind: String, seconds: float) -> void:
	doors[index] = {"kind": kind, "at": clock, "until": clock + seconds}
	sound(64 + index * 2 if kind != "cat" else 58)


## Close finished doors; soldiers that waited too long escape with a raspberry.
func _expire() -> void:
	if snatch_door >= 0 and has_mallet():
		snatch_door = -1
		say("槌子還你", true)
	for index in doors.size():
		var door: Dictionary = doors[index]
		if str(door.kind) == "shut" or clock < float(door.until):
			continue
		if str(door.kind) == "soldier":
			doors[index] = {"kind": "escaped", "at": clock, "until": clock + ESCAPE_SECONDS}
			escapes += 1
			streak = 0
			if not _demo:
				say("溜走了！", false)
			sound(52)
		else:
			doors[index] = {"kind": "shut", "at": clock, "until": -99.0}


func _pop() -> void:
	var free: Array[int] = []
	for index in doors.size():
		if str(doors[index].kind) == "shut":
			free.append(index)
	if free.is_empty():
		return
	var count := 2 if free.size() >= 2 and (bool(variant.get("pairs", false)) or heat() >= PAIR_HEAT and rng.randf() < PAIR_CHANCE) else 1
	for pick in count:
		var index: int = free.pop_at(rng.randi() % free.size())
		var roll := rng.randf()
		var cat_rate := lerpf(CAT_START, CAT_END, heat()) * float(variant.get("cats", 1.0))
		if roll < cat_rate and snatch_door < 0:
			_open(index, "cat", CAT_SECONDS)
		elif heat() >= FEINT_HEAT and roll < cat_rate + FEINT_CHANCE:
			_open(index, "feint", FEINT_SECONDS)
		else:
			_open(index, "soldier", up_seconds())


func _swing(index: int) -> void:
	swing_door = index
	swing_at = clock


func _bonk(index: int) -> void:
	var waited := clock - float(doors[index].at)
	doors[index] = {"kind": "bonked", "at": clock, "until": clock + BONK_SECONDS}
	sound(79)
	if _demo:
		return
	bonks += 1
	var quick := waited <= QUICK_SECONDS
	var points := roundi((BONK_POINTS + STREAK_POINTS * mini(streak, MAX_STREAK) + (QUICK_POINTS if quick else 0)) * float(variant.get("worth", 1.0)))
	streak += 1
	add_score(points, ("快！+%d" if quick else "咚！+%d") % points)


## The cat wakes up cross, takes the mallet and walks off with it.
func _snatch(index: int) -> void:
	doors[index] = {"kind": "snatch", "at": clock, "until": clock + 0.4}
	snatch_door = index
	mallet_back_at = clock + SNATCH_SECONDS
	cat_hits += 1
	streak = 0
	sound(40)
	# The first cat of a round is a free lesson.
	if cat_hits > 1:
		add_mistake("喵！槌子被搶走了！")
	else:
		say("喵！槌子被搶走了！", false)

