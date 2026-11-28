extends "res://game/minigames/arcade/arcade_driver.gd"
## 蜂巢調音: bees buzz all over the greenhouse flower bed and the hive at the
## back wants them home. Walk the traveller about: bees flutter away from them,
## so you circle round and shoo them toward the hive door. More bees keep
## coming off the flowers. One grumpy contrary bee drifts *toward* the
## traveller instead and has to be dodged while herding. Get stung (the
## contrary bee catches you, or you get surrounded by bees trapped in a
## corner) and the traveller's face swells up into a round pink balloon.
## Rules only: the picture lives in bee_herd_view.gd.
##
## The bed runs 0..1 across (x) and 0 (back, by the hive) .. 1 (front) (y).

const View = preload("res://game/minigames/arcade/bee_herd_view.gd")
const HIVE := Vector2(0.5, 0.08)
const HIVE_DOOR := 0.09
## A bee shooed in the last HUM_SECONDS is hummed in by the hive once it is
## within HUM_RADIUS, so the last stretch forgives a slightly crooked push.
const HUM_RADIUS := 0.26
const HUM := 1.3
const HUM_SECONDS := 1.2
## Only a bee shooed within this long goes in; one just drifting past the
## door keeps buzzing about.
const SHOOED_SECONDS := 3.0
const HERO_START := Vector2(0.5, 0.82)
const WALK := 0.5
const WALK_RESPONSE := 12.0
## Bees within this distance flee; the push is strongest close up.
const FLEE_RADIUS := 0.22
const FLEE := 2.6
const WANDER := 0.35
## Bees shy away from the frame of the bed, so none hides in a corner the
## traveller cannot reach.
const WALL := 0.12
## Along the back wall, away from the hive, bees keep further off so the
## traveller (who cannot walk on the back row) can still get beside them.
const BACK_WALL := 0.24
const HIVE_GAP := 0.2
const WALL_PUSH := 1.6
const BEE_SPEED := 0.32
const BEE_DAMP := 1.6
const CONTRARY_SPEED := 0.17
const STING := 0.045
const CROWD := 0.09
const CROWD_COUNT := 3
## A fleeing bee outruns a walking traveller, so only a trapped crowd closes in.
const FLEE_TOP := 1.5
## After stinging, the contrary bee flies off smugly for a while.
const SULK_SECONDS := 3.0
const START_BEES := 4
const MAX_BEES := 9
const SPAWN_FIRST := 4.5
const SPAWN_LAST := 1.8
const CONTRARY_HEAT := 0.25
const HOME_POINTS := 15
const STREAK_POINTS := 5
const STREAK_SECONDS := 2.5
const STREAK_CAP := 6
const SWELL_SECONDS := 1.9
## Flower clumps bees come off, as positions in the bed.
const FLOWERS: Array[Vector2] = [Vector2(0.1, 0.55), Vector2(0.9, 0.5), Vector2(0.2, 0.92), Vector2(0.82, 0.9), Vector2(0.06, 0.2), Vector2(0.94, 0.22)]

var hero := HERO_START
var hero_v := Vector2.ZERO
## Bees: {pos, vel, contrary, born, wander}.
var bees: Array[Dictionary] = []
## Bees that just went in: {pos, at, contrary}.
var homed: Array[Dictionary] = []
## The last sting: {pos, at}.
var swell: Dictionary = {}
var homes := 0
var streak := 0
var stings := 0

var _move := {&"left": 0, &"right": 0, &"up": 0, &"down": 0}
var _next_spawn := 0.0
var _last_home := -99.0
var _demo := false
var _steered := false
var _contrary_made := false


func _init() -> void:
	verb = "繞到蜜蜂後面，把牠們趕回蜂巢！"
	hint = [["方向鍵", "走過去趕蜂"]]
	round_seconds = 45.0
	thresholds = [45, 100, 140]
	verdicts = [
		"蜜蜂決定今晚睡在花上。",
		"銅牌！蜂巢裡傳出零零落落的嗡嗡聲。",
		"銀牌！蜂巢唱出整齊的和聲。",
		"金牌！女王蜂封你為榮譽牧蜂人。",
	]
	variants = [
		{"id": "standard", "label": "晴天花圃"},
		{"id": "breeze", "label": "微風花圃", "breeze": true},
		{"id": "swarm", "label": "蜂群日", "bees": 6, "spawn": 0.7},
	]
	score_label = "趕蜂得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_steered = false
	_demo = true
	_reset_bed()
	# The countdown demo: one bee just below the hive gets shooed in.
	bees.clear()
	bees.append(_bee(Vector2(0.52, 0.36), false))
	hero = Vector2(0.52, 0.56)


## The countdown walks up behind the demo bee and shoos it home.
func _warm_up(delta: float) -> void:
	var push := Vector2.ZERO
	if not bees.is_empty() and clock > 0.6:
		var behind: Vector2 = bees[0].pos + (bees[0].pos - HIVE).normalized() * 0.12
		push = (behind - hero).normalized() * 0.9
	_walk(delta, push)
	_buzz(delta)


func _go() -> void:
	# Play starts with the traveller at the front and every bee well away from
	# them and the hive: the first move is always the player's.
	_demo = false
	_reset_bed()


func _tick(delta: float) -> void:
	var push := Vector2(_move[&"right"] - _move[&"left"], _move[&"down"] - _move[&"up"])
	_walk(delta, push.limit_length(1.0))
	_spawn()
	_buzz(delta)


func _press(button: StringName) -> void:
	if _move.has(button):
		_move[button] += 1
		_steered = true


func _release(button: StringName) -> void:
	if _move.has(button):
		_move[button] = maxi(0, _move[button] - 1)


## No input, no points: a bee wandering home on its own scores nothing.
func add_score(points: int, word := "") -> void:
	if _steered:
		super(points, word)


func _round_over() -> void:
	for button in _move:
		_move[button] = 0


func _snapshot(into: Dictionary) -> void:
	into.hero = hero
	into.hero_v = hero_v
	into.bees = bees
	into.homed = homed
	into.swell = swell
	into.swell_seconds = SWELL_SECONDS
	into.hive = HIVE
	into.hive_door = HIVE_DOOR
	into.flee_radius = FLEE_RADIUS
	into.streak = streak
	into.flowers = FLOWERS


func busy() -> bool:
	return not swell.is_empty() and clock - float(swell.at) < SWELL_SECONDS


## The breeze day pushes every bee slowly one way, then the other.
func breeze_push() -> Vector2:
	return Vector2(0.18 * sin(clock * 0.45), 0.0) if bool(variant.get("breeze", false)) else Vector2.ZERO


func flee_radius() -> float:
	return FLEE_RADIUS


func hum_radius() -> float:
	# Assist lets the hive hum shooed bees in from further away.
	return HUM_RADIUS * (1.4 if assisted else 1.0)


func bee_speed() -> float:
	return pace(BEE_SPEED * lerpf(1.0, 1.35, heat()))


func _walk(delta: float, push: Vector2) -> void:
	if busy():
		hero_v = Vector2.ZERO
		return
	hero_v = hero_v.lerp(push * WALK, 1.0 - exp(-WALK_RESPONSE * delta))
	hero = (hero + hero_v * delta).clamp(Vector2(0.06, 0.16), Vector2(0.94, 0.93))


func _buzz(delta: float) -> void:
	var breeze := breeze_push()
	var crowd := 0
	for bee: Dictionary in bees.duplicate():
		var pos: Vector2 = bee.pos
		var vel: Vector2 = bee.vel
		var away: Vector2 = pos - hero
		var distance := away.length()
		var accel := Vector2.ZERO
		bee.wander = float(bee.wander) + rng.randf_range(-3.0, 3.0) * delta
		var fleeing := not bool(bee.contrary) and distance < flee_radius() and not busy()
		# A fleeing bee flies fairly straight; an idle one meanders.
		accel += Vector2.from_angle(float(bee.wander)) * WANDER * (0.3 if fleeing else 1.0)
		var sulking := clock < float(bee.sulk)
		if bool(bee.contrary):
			if sulking:
				accel = away.normalized() * 1.6
			elif not busy():
				accel = -away.normalized() * 1.6
		elif fleeing:
			accel += away.normalized() * FLEE * (1.0 - distance / flee_radius())
			bee.pushed = clock
		if not bool(bee.contrary) and clock - float(bee.pushed) < HUM_SECONDS and pos.distance_to(HIVE) < hum_radius():
			accel += (HIVE - pos).normalized() * HUM
		var back := 0.0 if absf(pos.x - HIVE.x) < HIVE_GAP else BACK_WALL
		if pos.y < back:
			accel.y += WALL_PUSH * (1.0 - pos.y / back)
		for axis in 2:
			if axis == 0 and pos.x < WALL:
				accel.x += WALL_PUSH * (1.0 - pos.x / WALL)
			elif pos[axis] > 1.0 - WALL:
				accel[axis] -= WALL_PUSH * (1.0 - (1.0 - pos[axis]) / WALL)
		vel = (vel + (accel + breeze) * delta) * exp(-BEE_DAMP * delta)
		# A shooed bee always flies off at full speed; assist only calms the idle ones.
		var top := BEE_SPEED * lerpf(1.0, 1.35, heat()) * FLEE_TOP if fleeing else bee_speed()
		if bool(bee.contrary):
			top = bee_speed() if sulking else pace(CONTRARY_SPEED)
		vel = vel.limit_length(top)
		pos += vel * delta
		# Bees bounce off the edges of the bed.
		for axis in 2:
			if pos[axis] < 0.03:
				pos[axis] = 0.03
				vel[axis] = absf(vel[axis])
			elif pos[axis] > 0.97:
				pos[axis] = 0.97
				vel[axis] = -absf(vel[axis])
		bee.pos = pos
		bee.vel = vel
		if pos.distance_to(HIVE) < HIVE_DOOR and not bool(bee.contrary) and clock - float(bee.pushed) < SHOOED_SECONDS:
			_home(bee)
			continue
		if busy():
			continue
		var near := pos.distance_to(hero)
		if near < STING and bool(bee.contrary) and not sulking:
			bee.sulk = clock + SULK_SECONDS
			_sting(pos, "grump")
			return
		if near < CROWD and not bool(bee.contrary):
			crowd += 1
	if crowd >= CROWD_COUNT and not busy():
		_sting(hero, "crowd")
	var kept: Array[Dictionary] = []
	for bee in homed:
		if clock - float(bee.at) < 1.0:
			kept.append(bee)
	homed.assign(kept)


func _home(bee: Dictionary) -> void:
	bees.erase(bee)
	homed.append({"pos": bee.pos, "at": clock, "contrary": bee.contrary})
	sound(72 + mini(streak, 10))
	if _demo:
		return
	homes += 1
	streak = streak + 1 if clock - _last_home < STREAK_SECONDS else 1
	_last_home = clock
	var points := HOME_POINTS + mini(streak - 1, STREAK_CAP) * STREAK_POINTS
	add_score(points, ("連續回巢！+%d" % points) if streak >= 3 else "")


func _sting(at: Vector2, by: String) -> void:
	swell = {"pos": at, "at": clock, "by": by}
	streak = 0
	sound(50)
	sound(46)
	# The bees scatter in surprise.
	for bee in bees:
		bee.vel = (Vector2(bee.pos) - hero).normalized() * 0.35
	if _demo:
		return
	stings += 1
	# The first sting of a round is a free look at the balloon face.
	funny_fail("被叮了！", stings > 1)


func _spawn() -> void:
	if play_time < _next_spawn:
		return
	_next_spawn = play_time + lerpf(SPAWN_FIRST, SPAWN_LAST, heat()) * float(variant.get("spawn", 1.0))
	if bees.size() >= MAX_BEES:
		return
	var contrary := heat() >= CONTRARY_HEAT and not _contrary_made
	if contrary:
		_contrary_made = true
	bees.append(_bee(_far_flower(), contrary))


func _reset_bed() -> void:
	hero = HERO_START
	hero_v = Vector2.ZERO
	bees.clear()
	homed.clear()
	swell = {}
	homes = 0
	streak = 0
	stings = 0
	_last_home = -99.0
	_contrary_made = false
	_next_spawn = SPAWN_FIRST * 0.6
	for button in _move:
		_move[button] = 0
	for count in int(variant.get("bees", START_BEES)):
		bees.append(_bee(_far_flower(), false))


## A flower clump well away from the traveller and the hive.
func _far_flower() -> Vector2:
	var open: Array[Vector2] = []
	for flower in FLOWERS:
		if flower.distance_to(hero) > 0.3 and flower.distance_to(HIVE) > 0.2:
			open.append(flower)
	var spot: Vector2 = open[rng.randi() % open.size()] if not open.is_empty() else FLOWERS[0]
	return spot + Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))


func _bee(at: Vector2, contrary: bool) -> Dictionary:
	return {"pos": at, "vel": Vector2.ZERO, "contrary": contrary, "born": clock, "pushed": -99.0, "sulk": -99.0, "wander": rng.randf() * TAU}
