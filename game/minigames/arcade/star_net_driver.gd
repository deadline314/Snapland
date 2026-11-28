extends "res://game/minigames/arcade/arcade_driver.gd"
## 落星接網: at dusk on the cloud-top photo deck, stars come falling out of the
## sky. Run left and right with a big hoop net held overhead: every star that
## drops into it bounces off into the nearest basket. Thundercloud balls fall
## among them; catch one and it zaps the traveller, hair standing on end and
## smoking, the net too frazzled to move for a moment. Stars fall faster as the
## round goes on, later two at a time from either side, and big bouncy stars
## spring back up off the net and have to be caught a second time.
## Rules only: the picture lives in star_net_view.gd.
##
## Across runs 0 (left) to 1 (right); a falling thing's height runs 0 (top of
## the sky) to 1 (the net).

const View = preload("res://game/minigames/arcade/star_net_view.gd")
const NET_HALF := 0.08
const SPEED := 1.1
const STAR_POINTS := 10
const BIG_FIRST := 5
const BIG_POINTS := 40
const ZAP_POINTS := 15
const COMBO_STEP := 4
const COMBO_CAP := 5
## Seconds to fall from the top of the sky to the net, and between drops.
const FALL_FIRST := 2.0
const FALL_LAST := 1.1
const GAP_FIRST := 0.8
const GAP_LAST := 0.38
const THUNDER_FIRST := 0.12
const THUNDER_LAST := 0.26
const PAIR_HEAT := 0.5
const BIG_HEAT := 0.35
const BIG_CHANCE := 0.14
const REBOUND := 1.3
const STUN_SECONDS := 1.2

var hero_x := 0.5
var facing := 0
## Falling things: {id, kind ("star", "big", "thunder"), x, start, target, born,
## fall, bounced, state ("fall", "caught", "missed", "zapped"), at}.
var drops: Array[Dictionary] = []
var zap_at := -99.0
var zaps := 0
var combo := 0
var best_combo := 0
var caught := 0
var bigs := 0
var missed := 0

var _serial := 0
var _drop_due := 0.0
var _demo := false


func _init() -> void:
	verb = "左右跑，用網子接住落下的星星，躲開雷雲球！"
	hint = [["← →", "移動網子"]]
	round_seconds = 45.0
	thresholds = [250, 520, 720]
	verdicts = [
		"星星決定改掉到別的島上。",
		"銅牌！籃子裡有幾顆在發亮。",
		"銀牌！拍照點的星空都靠你了。",
		"金牌！天上的星星排隊等你接。",
	]
	variants = [
		{"id": "shower", "label": "流星雨", "gaps": 0.8},
		{"id": "storm", "label": "雷雨夜", "thunder": 1.6},
		{"id": "bouncy", "label": "彈跳大星", "big": 0.28},
	]
	score_label = "接星得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	hero_x = 0.5
	facing = 0
	drops.clear()
	zap_at = -99.0
	zaps = 0
	combo = 0
	best_combo = 0
	caught = 0
	bigs = 0
	missed = 0
	_serial = 0
	_demo = true
	# The countdown drops one star off to the side and runs over to catch it.
	_drop("star", 0.66, 1.6)


func _warm_up(delta: float) -> void:
	var target := hero_x
	for drop in drops:
		if str(drop.state) == "fall":
			target = float(drop.x)
	_run(delta, signf(target - hero_x) if absf(target - hero_x) > 0.01 else 0.0)
	_fall()


func _go() -> void:
	_demo = false
	drops.clear()
	hero_x = 0.5
	_drop_due = clock + 0.3


func _tick(delta: float) -> void:
	var push := 0.0
	if not stunned():
		if _held.values().has(&"left"):
			push -= 1.0
		if _held.values().has(&"right"):
			push += 1.0
	_run(delta, push)
	if clock >= _drop_due:
		_drop_due = clock + lerpf(GAP_FIRST, GAP_LAST, heat()) * float(variant.get("gaps", 1.0)) * rng.randf_range(0.8, 1.2)
		_spawn()
	_fall()


func _snapshot(into: Dictionary) -> void:
	into.hero_x = hero_x
	into.facing = facing
	into.net_half = net_half()
	into.drops = drops
	into.zap_at = zap_at
	into.stun_seconds = STUN_SECONDS
	into.combo = combo
	into.rebound = REBOUND


## The net is a little wider with assist.
func net_half() -> float:
	return NET_HALF * (1.3 if assisted else 1.0)


func stunned() -> bool:
	return clock - zap_at < STUN_SECONDS


## How far down a falling thing is now, 0 top of the sky to 1 the net; a big
## star bouncing back up off the net climbs and falls again.
func height(drop: Dictionary) -> float:
	var t := clampf((clock - float(drop.born)) / float(drop.fall), 0.0, 1.0)
	if bool(drop.bounced):
		return 1.0 - 0.6 * sin(PI * t)
	return t


func position_x(drop: Dictionary) -> float:
	var t := clampf((clock - float(drop.born)) / float(drop.fall), 0.0, 1.0)
	return lerpf(float(drop.start), float(drop.target), t)


func _run(delta: float, push: float) -> void:
	facing = int(push)
	hero_x = clampf(hero_x + push * SPEED * delta, 0.06, 0.94)


func _spawn() -> void:
	var fall := window(lerpf(FALL_FIRST, FALL_LAST, heat()))
	var thunder := lerpf(THUNDER_FIRST, THUNDER_LAST, heat()) * float(variant.get("thunder", 1.0))
	var big := float(variant.get("big", BIG_CHANCE if heat() >= BIG_HEAT else 0.0))
	if heat() >= PAIR_HEAT and rng.randf() < 0.5:
		# Two at once, one from each side; at most one of them is a thundercloud.
		var stormy := rng.randf() < thunder * 2.0
		var which := rng.randi() % 2
		_drop("thunder" if stormy and which == 0 else "star", rng.randf_range(0.08, 0.42), fall)
		_drop("thunder" if stormy and which == 1 else "star", rng.randf_range(0.58, 0.92), fall)
		return
	var kind := "star"
	var roll := rng.randf()
	if roll < thunder:
		# No thunderclouds in the first moments of play.
		kind = "thunder" if play_time > 2.5 else "star"
	elif roll < thunder + big:
		kind = "big"
	_drop(kind, rng.randf_range(0.08, 0.92), fall)


func _drop(kind: String, x: float, fall: float) -> void:
	_serial += 1
	drops.append({"id": _serial, "kind": kind, "x": x, "start": x, "target": x, "born": clock, "fall": fall,
		"bounced": false, "state": "fall", "at": -99.0})


func _fall() -> void:
	var kept: Array[Dictionary] = []
	for drop in drops:
		if str(drop.state) == "fall":
			drop.x = position_x(drop)
			if clock - float(drop.born) >= float(drop.fall):
				if absf(float(drop.x) - hero_x) <= net_half() and not stunned():
					_catch(drop)
				else:
					_miss(drop)
		if str(drop.state) == "fall" or clock - float(drop.at) < 0.8:
			kept.append(drop)
	drops.assign(kept)


func _catch(drop: Dictionary) -> void:
	match str(drop.kind):
		"thunder":
			drop.state = "zapped"
			drop.at = clock
			_zap()
		"big":
			if not bool(drop.bounced):
				# A big star springs back up off the net and comes down somewhere else.
				drop.bounced = true
				drop.born = clock
				drop.fall = REBOUND
				drop.start = float(drop.x)
				drop.target = clampf(float(drop.x) + rng.randf_range(0.18, 0.3) * (1.0 if rng.randf() < 0.5 else -1.0), 0.1, 0.9)
				sound(67)
				if not _demo and touched:
					add_score(BIG_FIRST, "再接一次！")
				return
			drop.state = "caught"
			drop.at = clock
			sound(84)
			if not _demo and touched:
				bigs += 1
				combo += 1
				best_combo = maxi(best_combo, combo)
				add_score(BIG_POINTS, "大星入籃！")
		_:
			drop.state = "caught"
			drop.at = clock
			sound(72 + mini(combo, 10))
			# A net nobody has moved can still catch a star, but that pays nothing.
			if _demo or not touched:
				return
			caught += 1
			combo += 1
			best_combo = maxi(best_combo, combo)
			add_score(STAR_POINTS + mini(combo / COMBO_STEP, COMBO_CAP) * 2, "" if combo % 10 != 0 else "連接 %d 顆！" % combo)


func _miss(drop: Dictionary) -> void:
	drop.state = "missed"
	drop.at = clock
	if str(drop.kind) == "thunder" or _demo:
		return
	missed += 1
	combo = 0


func _zap() -> void:
	zap_at = clock
	combo = 0
	sound(36)
	sound(90)
	if _demo:
		return
	zaps += 1
	add_score(-ZAP_POINTS)
	# The first zap of a round is a free look at the frizz.
	funny_fail("滋滋滋！", zaps > 1)
