extends "res://game/minigames/arcade/arcade_driver.gd"
## 磁鐵搬家: moving day in the toy workshop. Toys slide down a chute onto a
## conveyor belt and ride off to the recycling bin at the far end. Run the crane
## left and right along its girder and drop the big horseshoe magnet: every tin
## toy under it clanks up and sticks, wooden ones just get bonked. Carry the
## catch back to the new toy box and drop it in; three at once is a full load.
## A magnet that comes down on no iron at all finds the nearest iron there is,
## the traveller's tin helmet, and hauls the traveller up to dangle from it.
## The odd cast-iron weight is worth a lot but drags the crane down and slows it.
## Rules only: the picture lives in magnet_move_view.gd.
##
## Positions run along the girder from 0 (left wall) to 1 (right wall).

const View = preload("res://game/minigames/arcade/magnet_move_view.gd")
const BOX_X := 0.07
const BOX_REACH := 0.06
const BELT_START := 0.2
const BELT_END := 0.95
const RAIL_MIN := 0.04
const RAIL_MAX := 0.96
const SPEED := 0.9
## A crane carrying a cast-iron weight crawls.
const HEAVY_SPEED := 0.4
const GRAB_REACH := 0.05
## The magnet's trip down, its pause at the bottom and its climb back up.
const DOWN_SECONDS := 0.16
const HOLD_SECONDS := 0.06
const UP_SECONDS := 0.2
const CAPACITY := 3
const YANK_SECONDS := 1.5
## Belt speed in girder widths per second, at the start and at the end of play.
const BELT_FIRST := 0.07
const BELT_LAST := 0.14
## Seconds between toys at the start and at the end of play.
const GAP_FIRST := 1.25
const GAP_LAST := 0.6
## A toy has to be this far along before the next one drops out of the hopper.
const CHUTE_ROOM := 0.04
const TOY_POINTS := 10
## Extra points for a delivery of one, two or three toys.
const LOAD_BONUS: Array[int] = [0, 0, 10, 30]
const HEAVY_POINTS := 50
const HEAVY_HEAT := 0.15
const HEAVY_CHANCE := 0.12
## Wooden robots painted to look like tin ones join the belt from here on.
const DECOY_HEAT := 0.45
const IRON_KINDS: Array[String] = ["robot", "car", "drum", "mouse"]
const WOOD_KINDS: Array[String] = ["block", "duck"]

## The crane's place on the girder, 0..1.
var crane_x := 0.5
## Driver clock when the magnet last started down; negative when it is up.
var drop_at := -99.0
## Whether that drop is into the toy box.
var drop_box := false
## Toys stuck to the magnet, top one first.
var held: Array[Dictionary] = []
## Toys in the scene: {id, kind, iron, heavy, x, state, at, bonk_at}; state is
## "belt", "held", "boxed" (falling into the box) or "lost" (off the far end).
var toys: Array[Dictionary] = []
## Driver clock when the magnet took the traveller's helmet; negative otherwise.
var yank_at := -99.0
var full_at := -99.0
var boxed_at := -99.0
## How far the belt has run, for the tread.
var belt_run := 0.0
var boxed := 0
var trips := 0
var full_loads := 0
var heavies := 0
var yanks := 0
var lost := 0
var bonks := 0

var _resolved := true
var _next_toy := 0.0
var _serial := 0
var _demo := false


func _init() -> void:
	verb = "放下磁鐵，把鐵皮玩具搬進新家！"
	hint = [["← →", "移動吊車"], ["空白鍵", "放下磁鐵"]]
	round_seconds = 45.0
	thresholds = [150, 330, 500]
	verdicts = [
		"玩具們決定留在舊家，連箱子都不想看。",
		"銅牌！搬是搬了，頭盔也搬了一次。",
		"銀牌！吊車師傅都想跟你拜師。",
		"金牌！搬家公司明天就來挖角。",
	]
	variants = [
		{"id": "moving", "label": "搬家日"},
		{"id": "rush", "label": "趕時間", "belt": 1.3, "gap": 0.85},
		{"id": "decoy", "label": "木頭假貨", "decoy": true},
	]
	score_label = "搬家得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	crane_x = 0.5
	drop_at = -99.0
	drop_box = false
	held.clear()
	toys.clear()
	yank_at = -99.0
	full_at = -99.0
	boxed_at = -99.0
	belt_run = 0.0
	boxed = 0
	trips = 0
	full_loads = 0
	heavies = 0
	yanks = 0
	lost = 0
	bonks = 0
	_resolved = true
	_serial = 0
	_demo = true
	# The countdown fetches one tin robot past a wooden block and boxes it.
	_place("robot", 0.36)
	_place("block", 0.58)


func _warm_up(delta: float) -> void:
	_settle()
	if dropping():
		return
	var robot := toys.filter(func(toy: Dictionary) -> bool: return toy.state == "belt" and bool(toy.iron))
	# Once the robot is boxed the crane heads back to the middle of the belt.
	var target := 0.5
	if not held.is_empty():
		target = BOX_X
	elif not robot.is_empty():
		target = float(robot[0].x)
	if absf(crane_x - target) > 0.005:
		crane_x = move_toward(crane_x, target, SPEED * delta)
	elif not held.is_empty() or not robot.is_empty():
		_drop()


func _go() -> void:
	_demo = false
	toys.clear()
	held.clear()
	drop_at = -99.0
	_resolved = true
	boxed = 0
	trips = 0
	_next_toy = clock


func _tick(delta: float) -> void:
	if not dropping() and not yanked():
		var push := 0.0
		if _held.values().has(&"left"):
			push -= 1.0
		if _held.values().has(&"right"):
			push += 1.0
		crane_x = clampf(crane_x + push * crane_speed() * delta, RAIL_MIN, RAIL_MAX)
	var speed := belt_speed()
	belt_run += speed * delta
	for toy in toys:
		if toy.state == "belt":
			toy.x = float(toy.x) + speed * delta
			if float(toy.x) >= BELT_END:
				toy.state = "lost"
				toy.at = clock
				if bool(toy.iron):
					lost += 1
				sound(48)
	while clock >= _next_toy:
		if _spawn():
			_next_toy += lerpf(GAP_FIRST, GAP_LAST, heat()) * float(variant.get("gap", 1.0)) * rng.randf_range(0.75, 1.25)
		else:
			_next_toy = clock + 0.1
	_settle()


func _press(button: StringName) -> void:
	if button == &"action" or button == &"down" or button == &"second":
		_drop()


func _round_over() -> void:
	drop_at = -99.0
	_resolved = true


func _snapshot(into: Dictionary) -> void:
	into.crane_x = crane_x
	into.drop_at = drop_at
	into.drop_box = drop_box
	into.drop_seconds = [DOWN_SECONDS, HOLD_SECONDS, UP_SECONDS]
	into.held = held
	into.toys = toys
	into.yank_at = yank_at
	into.yank_seconds = YANK_SECONDS
	into.full_at = full_at
	into.boxed_at = boxed_at
	into.box_x = BOX_X
	into.belt_start = BELT_START
	into.belt_end = BELT_END
	into.belt_run = belt_run
	into.heavy = carrying_heavy()
	into.grab_reach = grab_reach()
	into.held_full = held.size() >= CAPACITY
	var push := 0.0
	if stage == "play" and not dropping() and not yanked():
		push = float(_held.values().has(&"right")) - float(_held.values().has(&"left"))
	into.push = push


func dropping() -> bool:
	return clock - drop_at < DOWN_SECONDS + HOLD_SECONDS + UP_SECONDS


func yanked() -> bool:
	return clock - yank_at < YANK_SECONDS


func carrying_heavy() -> bool:
	return held.any(func(toy: Dictionary) -> bool: return bool(toy.heavy))


func crane_speed() -> float:
	return HEAVY_SPEED if carrying_heavy() else SPEED


func belt_speed() -> float:
	return pace(lerpf(BELT_FIRST, BELT_LAST, heat()) * float(variant.get("belt", 1.0)))


## The magnet's pull is a little wider with assist.
func grab_reach() -> float:
	return GRAB_REACH * (1.4 if assisted else 1.0)


func over_box() -> bool:
	return absf(crane_x - BOX_X) <= BOX_REACH


func _drop() -> void:
	if dropping() or yanked():
		return
	var into_box := over_box()
	if not into_box and held.size() >= CAPACITY:
		full_at = clock
		sound(50)
		say("滿了！", false)
		return
	drop_at = clock
	drop_box = into_box
	_resolved = false
	sound(57)


## Resolve the magnet once it reaches the bottom; tidy toys that are done animating.
func _settle() -> void:
	if not _resolved and clock - drop_at >= DOWN_SECONDS:
		_resolved = true
		if drop_box:
			_deliver()
		else:
			_grab()
	var kept: Array[Dictionary] = []
	for toy in toys:
		if toy.state == "belt" or toy.state == "held" or clock - float(toy.at) < 0.7:
			kept.append(toy)
	toys.assign(kept)


func _grab() -> void:
	var under: Array[Dictionary] = []
	for toy in toys:
		if toy.state == "belt" and absf(float(toy.x) - crane_x) <= grab_reach():
			if bool(toy.iron):
				under.append(toy)
			else:
				toy.bonk_at = clock
				bonks += 1
	under.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a.x) - crane_x) < absf(float(b.x) - crane_x))
	var caught := 0
	for toy in under:
		if held.size() >= CAPACITY:
			break
		toy.state = "held"
		toy.at = clock
		held.append(toy)
		caught += 1
	if caught > 0:
		sound(64 + held.size() * 3)
		if carrying_heavy():
			sound(40)
		return
	if _demo:
		return
	# No iron under the magnet: it finds the traveller's helmet instead.
	yanks += 1
	yank_at = clock
	sound(76)
	sound(45)
	# The first helmet of a round is a free look.
	funny_fail("我的頭盔！", yanks > 1)


func _deliver() -> void:
	if held.is_empty():
		say("空的～", false)
		sound(50)
		return
	var count := held.size()
	var points := LOAD_BONUS[count]
	for toy in held:
		toy.state = "boxed"
		toy.at = clock
		toy.x = BOX_X
		points += HEAVY_POINTS if bool(toy.heavy) else TOY_POINTS
		heavies += int(bool(toy.heavy))
	held.clear()
	boxed_at = clock
	sound(72 + count * 2)
	if _demo:
		return
	boxed += count
	trips += 1
	if count >= CAPACITY:
		full_loads += 1
		add_score(points, "滿載！+%d" % points)
	else:
		add_score(points, "+%d" % points)


## Drop the next toy out of the hopper; false while the last one still blocks it.
func _spawn() -> bool:
	var on_belt := toys.filter(func(toy: Dictionary) -> bool: return toy.state == "belt")
	# Toys come down the chute one at a time and never land on top of each other.
	if on_belt.any(func(toy: Dictionary) -> bool: return float(toy.x) < BELT_START + CHUTE_ROOM):
		return false
	var heavy_chance := HEAVY_CHANCE if heat() >= HEAVY_HEAT else 0.0
	if heavy_chance > 0.0 and not toys.any(func(toy: Dictionary) -> bool: return bool(toy.heavy) and toy.state != "boxed") and rng.randf() < heavy_chance:
		_place("weight", BELT_START)
		return true
	if rng.randf() < lerpf(0.68, 0.56, heat()):
		_place(IRON_KINDS[rng.randi() % IRON_KINDS.size()], BELT_START)
		return true
	var decoys := bool(variant.get("decoy", false)) or heat() >= DECOY_HEAT
	if decoys and rng.randf() < 0.45:
		_place("woodbot", BELT_START)
	else:
		_place(WOOD_KINDS[rng.randi() % WOOD_KINDS.size()], BELT_START)
	return true


func _place(kind: String, x: float) -> void:
	_serial += 1
	var iron := kind in IRON_KINDS or kind == "weight"
	toys.append({"id": _serial, "kind": kind, "iron": iron, "heavy": kind == "weight", "x": x, "state": "belt", "at": clock, "bonk_at": -99.0})
