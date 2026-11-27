extends "res://game/minigames/arcade/arcade_driver.gd"
## 軌道換軌: toy trains in three colours puff in from the left along a wooden
## track to a three-way set of points. Throw the points up, straight on or down
## (↑ → ↓) so each train runs into the station of its own colour. The points
## spring back to "stop" once a train has run over them, and a train that finds
## them at stop waits at the signal, tooting, until they are thrown: every train
## needs its own throw, so a round left alone earns nothing. A train sent
## to the wrong station shoots off the end of the line and tips into the big
## toy box, tooting a trail of little stars. Trains come quicker, longer and
## closer together; some stop short, toot and back up before charging on.
## Rules only: the picture lives in track_switch_view.gd.
##
## A train's place is its distance along the line: 0 at the left edge, JUNCTION
## at the points, JUNCTION + BRANCH at the station doors.

const View = preload("res://game/minigames/arcade/track_switch_view.gd")
const JUNCTION := 0.55
const BRANCH := 0.45
const ENGINE := 0.06
const CAR := 0.045
## Gap kept between one train's last car and the next engine on the main line.
const GAP := 0.05
## Track units per second, at the start and at the end of play.
const SPEED_FIRST := 0.13
const SPEED_LAST := 0.24
## Seconds between trains, at the start and at the end of play.
const SPAWN_FIRST := 3.0
const SPAWN_LAST := 1.25
const CARS_HEAT := 0.25
const BACKER_HEAT := 0.35
const BACKER_CHANCE := 0.3
## A backing train stops this short of the points, then backs up, then charges.
const BACKER_STOP := 0.07
const BACKER_PAUSE := 0.5
const BACKER_REVERSE := 0.7
const BACKER_CHARGE := 1.35
const SHUFFLE_SECONDS := 12.0
const SHUFFLE_WARNING := 1.5
const TRAIN_POINTS := 10
const STREAK_POINTS := 5
const ASSIST_SPEED := 1.25
const STREAK_CAP := 5
const CRASH_SECONDS := 1.2
## Points: 0 up, 1 straight on, 2 down, or STOP.
const BRANCHES := 3
const STOP := -1

## Where the points send the next train; STOP holds it at the signal.
var points := STOP
var points_at := -99.0
## Which colour each station takes, top to bottom.
var stations: Array[int] = [0, 1, 2]
var shuffle_at := -99.0
## Trains: {id, colour, cars, s, speed, branch (-1 until the points), right,
## state ("run", "home", "crash"), at, backer, phase, phase_at}.
var trains: Array[Dictionary] = []
var delivered := 0
var crashes := 0
var streak := 0
var best_streak := 0
var backers := 0

var _next_train := 0.0
var _next_shuffle := 0.0
var _serial := 0
var _demo := false


func _init() -> void:
	verb = "扳道岔，讓火車開進同色的車站！"
	hint = [["↑ → ↓", "扳道岔"]]
	round_seconds = 45.0
	thresholds = [150, 440, 600]
	verdicts = [
		"火車們決定改搭公車。",
		"銅牌！大部分的乘客都到家了。",
		"銀牌！站長想請你喝汽水。",
		"金牌！你就是玩具城的鐵路之神。",
	]
	variants = [
		{"id": "standard", "label": "三站開班"},
		{"id": "express", "label": "特快車", "speed": 1.25, "spawn": 1.2, "cars": 1},
		{"id": "shuffle", "label": "站牌換色", "shuffle": true},
	]
	score_label = "準點得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	points = STOP
	points_at = -99.0
	stations = [0, 1, 2]
	shuffle_at = -99.0
	trains.clear()
	delivered = 0
	crashes = 0
	streak = 0
	best_streak = 0
	backers = 0
	_serial = 0
	_demo = true
	# The countdown runs one red train in with the points thrown up for it.
	_spawn_train(0, 0, false, JUNCTION - 0.12)


func _warm_up(delta: float) -> void:
	for train in trains:
		if str(train.state) == "run" and int(train.branch) < 0:
			var want := stations.find(int(train.colour))
			if want != points:
				points = want
				points_at = clock
	# The demo train runs quickly so it is home before play starts.
	_move(delta * 2.5)


func _go() -> void:
	_demo = false
	trains.clear()
	points = STOP
	streak = 0
	_next_train = clock + 0.3
	_next_shuffle = clock + SHUFFLE_SECONDS


func _tick(delta: float) -> void:
	if clock >= _next_train:
		_spawn()
	if bool(variant.get("shuffle", false)) and clock >= _next_shuffle:
		_next_shuffle = clock + SHUFFLE_SECONDS
		_shuffle()
	_move(delta)


func _press(button: StringName) -> void:
	match button:
		&"up":
			_throw(0)
		&"right":
			_throw(1)
		&"down":
			_throw(2)
		&"action", &"second":
			_throw((points + 1) % BRANCHES if points != STOP else 0)


func _snapshot(into: Dictionary) -> void:
	into.points = points
	into.points_at = points_at
	into.stations = stations
	into.shuffle_at = shuffle_at
	into.shuffle_due = _next_shuffle if bool(variant.get("shuffle", false)) and stage == "play" else -99.0
	into.shuffle_warning = SHUFFLE_WARNING
	into.trains = trains
	into.junction = JUNCTION
	into.branch = BRANCH
	into.engine = ENGINE
	into.car = CAR
	into.streak = streak
	into.crash_seconds = CRASH_SECONDS


func speed() -> float:
	# Assist slows the trains a little; much slower would only mean fewer trains.
	return lerpf(SPEED_FIRST, SPEED_LAST, heat()) * float(variant.get("speed", 1.0)) / (ASSIST_SPEED if assisted else 1.0)


func spawn_gap() -> float:
	return lerpf(SPAWN_FIRST, SPAWN_LAST, heat()) * float(variant.get("spawn", 1.0))


## The length of a train from its engine's nose to its last car's tail.
func train_length(train: Dictionary) -> float:
	return ENGINE + CAR * int(train.cars)


## The train nearest the points that has not reached them yet, or {}.
func next_to_points() -> Dictionary:
	var best: Dictionary = {}
	for train in trains:
		if str(train.state) == "run" and int(train.branch) < 0 and (best.is_empty() or float(train.s) > float(best.s)):
			best = train
	return best


func _throw(branch: int) -> void:
	if branch == points:
		return
	points = branch
	points_at = clock
	sound(62 + branch * 3)


func _spawn() -> void:
	# Wait while the entrance is still blocked.
	for train in trains:
		if str(train.state) == "run" and float(train.s) - train_length(train) < GAP:
			_next_train = clock + 0.2
			return
	var cars := 0
	if heat() >= CARS_HEAT:
		cars = rng.randi_range(0, 2 if heat() > 0.6 else 1)
	cars = mini(2, cars + int(variant.get("cars", 0)))
	var backer := heat() >= BACKER_HEAT and rng.randf() < BACKER_CHANCE and not trains.any(func(train: Dictionary) -> bool: return bool(train.backer) and str(train.state) == "run")
	var colour := rng.randi() % BRANCHES
	_spawn_train(colour, cars, backer, 0.0)
	_next_train = clock + spawn_gap() * rng.randf_range(0.8, 1.2)


func _spawn_train(colour: int, cars: int, backer: bool, at: float) -> void:
	_serial += 1
	trains.append({"id": _serial, "colour": colour, "cars": cars, "s": at, "speed": 1.0, "branch": -1, "right": false,
		"state": "run", "at": clock, "backer": backer, "phase": "come", "phase_at": clock})
	backers += int(backer)
	sound(70)


## Move every train; the ones on the main line keep their distance.
func _move(delta: float) -> void:
	var base := speed()
	# Front trains first, so followers can keep clear of them.
	var order := trains.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) > float(b.s))
	var ahead_tail := INF
	for train: Dictionary in order:
		if str(train.state) != "run":
			continue
		var step := base * delta * _pace(train)
		var s := float(train.s) + step
		if int(train.branch) < 0:
			if s < JUNCTION + 0.001:
				s = minf(s, ahead_tail - GAP)
			# Points at stop hold the train at the signal, however fast it comes.
			if points == STOP and s >= JUNCTION:
				s = JUNCTION - 0.0005
				if not bool(train.get("waiting", false)):
					train.waiting = true
					sound(74)
		train.s = s
		if int(train.branch) < 0:
			ahead_tail = float(train.s) - train_length(train)
			if float(train.s) >= JUNCTION:
				_reach_points(train)
		elif float(train.s) >= JUNCTION + BRANCH:
			_arrive(train)
	var kept: Array[Dictionary] = []
	for train in trains:
		if str(train.state) == "run" or clock - float(train.at) < CRASH_SECONDS:
			kept.append(train)
	trains.assign(kept)


## Speed factor for one train: 1 normally; a backing train stops, backs up and charges.
func _pace(train: Dictionary) -> float:
	if not bool(train.backer) or int(train.branch) >= 0:
		return 1.0
	var since := clock - float(train.phase_at)
	match str(train.phase):
		"come":
			if float(train.s) >= JUNCTION - BACKER_STOP:
				train.phase = "stop"
				train.phase_at = clock
				say("嘟？", true)
				sound(74)
				return 0.0
			return 1.0
		"stop":
			if since >= BACKER_PAUSE:
				train.phase = "back"
				train.phase_at = clock
			return 0.0
		"back":
			if since >= BACKER_REVERSE:
				train.phase = "charge"
				train.phase_at = clock
				sound(76)
			return -0.8
	return BACKER_CHARGE


func _reach_points(train: Dictionary) -> void:
	train.branch = points
	train.right = stations[points] == int(train.colour)
	train.speed = 1.0
	train.waiting = false
	# The points spring back to stop behind it.
	points = STOP
	points_at = clock


func _arrive(train: Dictionary) -> void:
	train.at = clock
	if bool(train.right):
		train.state = "home"
		sound(79)
		sound(84)
		if _demo:
			return
		delivered += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		var gained := TRAIN_POINTS * (1 + int(train.cars)) + STREAK_POINTS * mini(streak, STREAK_CAP)
		add_score(gained, "到站！+%d" % gained)
		return
	train.state = "crash"
	sound(48)
	sound(88)
	if _demo:
		return
	crashes += 1
	streak = 0
	# The first wrong station of a round is a free look at the tumble.
	funny_fail("開錯站啦！", crashes > 1)


func _shuffle() -> void:
	# Turn the colours round one or two stations, so every sign changes.
	var turn := 1 + rng.randi() % 2
	stations = [stations[turn % 3], stations[(turn + 1) % 3], stations[(turn + 2) % 3]]
	shuffle_at = clock
	say("換站牌！", false)
	sound(72)
