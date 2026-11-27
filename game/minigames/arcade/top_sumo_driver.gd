extends "res://game/minigames/arcade/arcade_driver.gd"
## 陀螺相撲: steer your spinning top round a tin dish with the arrows and ram the
## rival tops over the rim. Every top slowly loses spin and wobbles; a good ram
## spins yours back up. Pushed out, or spun down to nothing, your top topples
## and rolls off the table until a fresh one is launched. Later the dish shrinks
## and more, bigger rivals join. Rules only: the picture lives in top_sumo_view.gd.
## Lengths are pixels on the flat dish (the view squashes it into perspective).

const View = preload("res://game/minigames/arcade/top_sumo_view.gd")
const RIM_START := 250.0
const RIM_END := 170.0
const HERO_RADIUS := 26.0
const RIVAL_RADIUS := 24.0
const BIG_RADIUS := 36.0
const ACCEL := 1100.0
const RIVAL_ACCEL := 470.0
const BIG_ACCEL := 330.0
const FRICTION := 1.7
const SLIPPERY_FRICTION := 0.5
const BOUNCE := 0.9
## A ram this much faster than the rival also spins your top back up.
const RAM_SPEED := 180.0
const RAM_SPIN := 0.3
const SPIN_DECAY := 0.05
const RIVAL_SPIN_DECAY := 0.035
## Rivals on the dish at heat 0, 0.3 and 0.65 (0..1 through the round).
const CROWD: Array[float] = [0.0, 0.3, 0.65]
const BIG_HEAT := 0.4
const BIG_CHANCE := 0.4
const KO_POINTS := 20
const BIG_POINTS := 35
const COMBO_POINTS := 10
const COMBO_SECONDS := 1.5
## A rival only counts as yours if your top touched it this recently.
const CREDIT_SECONDS := 2.5
## A rival knocked by your top reels this long before it steers again.
const DAZE_SECONDS := 0.6
## A new rival is dropped in this long after one leaves.
const SPAWN_DELAY := 0.8
const DROP_SECONDS := 0.5
## Seconds the toppled top rolls about before a new one is launched.
const RESPAWN_SECONDS := 1.8
const HERO := 0
const TABLE_MARGIN := 70.0

## {id, kind ("hero", "rival", "big"), pos, vel, r, spin, state ("drop", "spin", "out",
## "topple"), at (clock of the last state change), hit (clock of the last ram from the hero)}
var tops: Array[Dictionary] = []
var rim := RIM_START
var knockouts := 0
var falls := 0
var last_ko_at := -99.0
var ram_at := -99.0
var ram_point := Vector2.ZERO

var _next_id := 1
var _arrows: Dictionary = {}
var _spawn_wait := 0.0
var _demo := false


func _init() -> void:
	verb = "用方向鍵推陀螺，把對手撞出圓盤！"
	hint = [["方向鍵", "推自己的陀螺"]]
	round_seconds = 45.0
	thresholds = [120, 300, 500]
	verdicts = [
		"陀螺決定躺著看別人轉。",
		"銅牌！轉是轉了，偶爾自己滾下桌。",
		"銀牌！圓盤上的小霸王。",
		"金牌！玩具城陀螺橫綱誕生。",
	]
	variants = [
		{"id": "standard", "label": "標準土俵", "worth": 1.0, "friction": FRICTION},
		{"id": "slippery", "label": "滑溜鐵盤", "worth": 1.0, "friction": SLIPPERY_FRICTION},
		{"id": "crowd", "label": "大亂鬥", "worth": 0.8, "friction": FRICTION, "extra": 1},
		{"id": "heavy", "label": "重量級", "worth": 1.1, "friction": FRICTION, "heavy": true},
	]
	score_label = "相撲得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	tops.clear()
	_next_id = 1
	knockouts = 0
	falls = 0
	last_ko_at = -99.0
	ram_at = -99.0
	rim = RIM_START
	_arrows.clear()
	_spawn_wait = 0.0
	tops.append(_top(HERO, "hero", Vector2(0, 60), HERO_RADIUS))
	tops[0].state = "spin"
	_add_rival(Vector2(0, -120), false)
	tops[1].state = "spin"
	_demo = true


func _warm_up(delta: float) -> void:
	# The countdown nudges your top toward the rival so the idea shows itself.
	var hero := hero_top()
	var rival := tops[1] if tops.size() > 1 else {}
	if not rival.is_empty():
		var aim: Vector2 = rival.pos - hero.pos
		hero.vel += aim.normalized() * ACCEL * 0.35 * delta
	_physics(delta, false)


func _go() -> void:
	_demo = false
	# The demo shove scores nothing and never leaves a top teetering on the rope.
	for top in tops:
		top.spin = 1.0
		top.hit = -99.0
		top.vel *= 0.3
		if top.pos.length() > RIM_START * 0.7:
			top.pos = top.pos.normalized() * RIM_START * 0.7


func _tick(delta: float) -> void:
	rim = lerpf(RIM_START, RIM_END, heat())
	var hero := hero_top()
	if hero.state == "spin":
		var push := steer()
		if push != Vector2.ZERO:
			hero.vel += push.normalized() * ACCEL * (0.55 + 0.45 * float(hero.spin)) * delta
	_rivals_chase(delta)
	_physics(delta, true)
	_settle(delta)


func _press(button: StringName) -> void:
	if button in [&"up", &"down", &"left", &"right"]:
		_arrows[button] = true


func _release(button: StringName) -> void:
	_arrows.erase(button)


func _snapshot(into: Dictionary) -> void:
	into.tops = tops
	into.rim = rim
	into.rim_start = RIM_START
	into.ram_at = ram_at
	into.ram_point = ram_point
	into.last_ko_at = last_ko_at
	into.steer = steer()


## The direction the arrows point, on the flat dish (up is away from the viewer).
func steer() -> Vector2:
	var push := Vector2.ZERO
	if _arrows.has(&"left"):
		push.x -= 1.0
	if _arrows.has(&"right"):
		push.x += 1.0
	if _arrows.has(&"up"):
		push.y -= 1.0
	if _arrows.has(&"down"):
		push.y += 1.0
	return push


func hero_top() -> Dictionary:
	return tops[0]


func rivals_spinning() -> int:
	var count := 0
	for top in tops:
		if top.kind != "hero" and (top.state == "spin" or top.state == "drop"):
			count += 1
	return count


func _top(id: int, kind: String, at: Vector2, radius: float) -> Dictionary:
	return {"id": id, "kind": kind, "pos": at, "vel": Vector2.ZERO, "r": radius, "spin": 1.0, "state": "drop", "at": clock,
		"hit": -99.0, "tint": rng.randi() % 3, "phase": rng.randf()}


func _mass(top: Dictionary) -> float:
	var base := 2.4 if top.kind == "big" else 1.3 if top.kind == "hero" else 1.0
	return base * (0.6 + 0.4 * float(top.spin))


func _add_rival(at: Vector2, big: bool) -> void:
	tops.append(_top(_next_id, "big" if big else "rival", at, BIG_RADIUS if big else RIVAL_RADIUS))
	_next_id += 1
	sound(62)


func _wanted_rivals() -> int:
	var count := int(variant.get("extra", 0))
	for line in CROWD:
		if heat() >= line:
			count += 1
	return count


## Rivals steer at your top, a little off-line so they circle in rather than queue.
func _rivals_chase(delta: float) -> void:
	var hero := hero_top()
	for top in tops:
		if top.kind == "hero" or top.state != "spin" or clock - float(top.hit) < DAZE_SECONDS:
			continue
		var goal: Vector2 = hero.pos if hero.state == "spin" else Vector2.ZERO
		var aim: Vector2 = goal - top.pos
		var swirl := aim.orthogonal() * (0.35 if int(top.id) % 2 == 0 else -0.35)
		var accel := pace(BIG_ACCEL if top.kind == "big" else RIVAL_ACCEL)
		top.vel += (aim + swirl).normalized() * accel * (0.6 + 0.4 * heat()) * delta
		# Rivals are wary of the edge.
		var out_dist: float = top.pos.length()
		if out_dist > rim * 0.75:
			top.vel -= top.pos.normalized() * accel * 0.5 * delta


func _physics(delta: float, live: bool) -> void:
	var drag := exp(-float(variant.get("friction", FRICTION)) * delta)
	for top in tops:
		if top.state == "spin":
			top.vel *= drag
			top.pos += top.vel * delta
			if live:
				top.spin = maxf(0.0, float(top.spin) - (pace(SPIN_DECAY) if top.kind == "hero" else RIVAL_SPIN_DECAY) * delta)
		elif top.state == "out" or top.state == "topple":
			top.pos += top.vel * delta
			top.vel *= exp(-0.8 * delta)
			# Fallen tops come to rest on the bench just past the dish.
			if top.pos.length() > RIM_START + TABLE_MARGIN:
				top.pos = top.pos.normalized() * (RIM_START + TABLE_MARGIN)
				top.vel = Vector2.ZERO
		elif top.state == "drop" and clock - float(top.at) >= DROP_SECONDS:
			top.state = "spin"
			top.at = clock
	for a in tops.size():
		for b in range(a + 1, tops.size()):
			_collide(tops[a], tops[b])


func _collide(one: Dictionary, two: Dictionary) -> void:
	if one.state != "spin" or two.state != "spin":
		return
	var gap: Vector2 = two.pos - one.pos
	var reach: float = float(one.r) + float(two.r)
	var distance := gap.length()
	if distance >= reach or distance <= 0.001:
		return
	var normal := gap / distance
	var m1 := _mass(one)
	var m2 := _mass(two)
	var overlap := reach - distance
	one.pos -= normal * overlap * m2 / (m1 + m2)
	two.pos += normal * overlap * m1 / (m1 + m2)
	var closing: float = (one.vel - two.vel).dot(normal)
	if closing <= 0.0:
		return
	# Who was driving into whom, before the bounce.
	var drives := [one.vel.dot(normal), -two.vel.dot(normal)]
	var impulse := (1.0 + BOUNCE) * closing / (1.0 / m1 + 1.0 / m2)
	one.vel -= normal * impulse / m1
	two.vel += normal * impulse / m2
	sound(70 if closing > RAM_SPEED else 66)
	for side in 2:
		var hero: Dictionary = one if side == 0 else two
		if hero.kind != "hero":
			continue
		var other: Dictionary = two if side == 0 else one
		# Only a push from your top makes the rival yours.
		if float(drives[side]) > 20.0:
			other.hit = clock
		ram_point = (one.pos + two.pos) * 0.5
		if closing > RAM_SPEED and float(drives[side]) > 0.0:
			ram_at = clock
			hero.spin = minf(1.0, float(hero.spin) + RAM_SPIN)
			if not _demo:
				say("撞！", true)


## Tops past the rim fall off; spun-down tops topple; launch replacements.
func _settle(delta: float) -> void:
	for top in tops:
		if top.state == "spin":
			if top.pos.length() > rim:
				_fall(top, "out")
			elif float(top.spin) <= 0.0:
				_fall(top, "topple")
	var hero := hero_top()
	if (hero.state == "out" or hero.state == "topple") and clock - float(hero.at) >= RESPAWN_SECONDS:
		hero.pos = Vector2.ZERO
		hero.vel = Vector2.ZERO
		hero.spin = 1.0
		hero.state = "drop"
		hero.at = clock
		sound(64)
	# Rivals that have rolled away for good leave the list.
	for index in range(tops.size() - 1, 0, -1):
		if tops[index].state != "spin" and tops[index].state != "drop" and clock - float(tops[index].at) > RESPAWN_SECONDS:
			tops.remove_at(index)
	if rivals_spinning() < _wanted_rivals():
		_spawn_wait += delta
		if _spawn_wait >= SPAWN_DELAY:
			_spawn_wait = 0.0
			var away: Vector2 = -hero.pos.normalized() if hero.pos.length() > 10.0 else Vector2.from_angle(rng.randf() * TAU)
			var at := away.rotated(rng.randf_range(-0.9, 0.9)) * rim * 0.55
			var big := bool(variant.get("heavy", false)) and rng.randf() < 0.5 or heat() >= BIG_HEAT and rng.randf() < BIG_CHANCE
			_add_rival(at, big)
	else:
		_spawn_wait = 0.0


func _fall(top: Dictionary, how: String) -> void:
	top.state = how
	top.at = clock
	# Rolling off: keep going outward; toppling: roll a little toward the near rim.
	var outward: Vector2 = top.pos.normalized() if top.pos.length() > 1.0 else Vector2.DOWN
	top.vel = outward * maxf(160.0, top.vel.length() * 0.8) if how == "out" else outward * 120.0
	if top.kind == "hero":
		falls += 1
		sound(43)
		var word := "滾下桌了！" if how == "out" else "轉不動了！"
		# The first fall of a round is a free look at what happens.
		funny_fail(word, falls > 1)
		return
	sound(76)
	if how != "out" or clock - float(top.hit) > CREDIT_SECONDS:
		return
	knockouts += 1
	var worth := float(variant.get("worth", 1.0))
	var points := roundi((BIG_POINTS if top.kind == "big" else KO_POINTS) * worth)
	var word := ("大個子出場！+%d" if top.kind == "big" else "出場！+%d")
	if clock - last_ko_at <= COMBO_SECONDS:
		points += roundi(COMBO_POINTS * worth)
		word = "連撞！+%d"
	last_ko_at = clock
	add_score(points, word % points)
