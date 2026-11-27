extends SceneTree
## 軌道換軌 rules: the demo train, throwing the points, home and wrong stations,
## streaks and cars, keeping distance, the backing train, escalation, the
## shuffled signs, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/track_switch_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const KEYS: Array[int] = [KEY_UP, KEY_RIGHT, KEY_DOWN]
## The bronze player throws only after a train has waited this long, and this often wrongly.
const BRONZE_DELAY := 0.3
const BRONZE_WRONG := 0.3

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_runs_a_train_home()
	_throwing_the_points()
	_home_and_wrong_stations()
	_points_at_stop_hold_the_train()
	_trains_keep_their_distance()
	_the_backing_train()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: track switch points, home and wrong stations, streaks, cars, spacing, backing train, escalation, shuffled signs, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_runs_a_train_home() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [150, 440, 600] and game.trains.size() == 1, "a round opens with one train on the way")
	var home := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_DOWN)
		game.step(STEP)
		home = home or game.trains.any(func(train: Dictionary) -> bool: return train.state == "home")
	_check(home and game.score == 0 and game.crashes == 0, "the countdown throws the points up and runs the red train home by itself")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.trains.is_empty() and game.points == Game.STOP, "play starts with an empty line and the points at stop")


func _throwing_the_points() -> void:
	var game := _playing("standard")
	for branch in 3:
		_tap(game, KEYS[branch])
		_check(game.points == branch, "%s throws the points" % OS.get_keycode_string(KEYS[branch]))
	_tap(game, KEY_SPACE)
	_check(game.points == 0, "space cycles the points round")
	_tap(game, KEY_S)
	_check(game.points == 2, "WASD works like the arrows")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_UP
	button.pressed = true
	game.handle_input(button, Vector2.ZERO)
	_check(game.points == 0, "the gamepad d-pad throws them too")


func _home_and_wrong_stations() -> void:
	var game := _quiet()
	game._spawn_train(1, 0, false, Game.JUNCTION - 0.01)
	_tap(game, KEY_RIGHT)
	_run_until_done(game)
	_check(game.delivered == 1 and game.score == Game.TRAIN_POINTS + Game.STREAK_POINTS and game.streak == 1, "a blue train through the straight points runs home to the blue station")
	game._spawn_train(2, 2, false, Game.JUNCTION - 0.01)
	_tap(game, KEY_DOWN)
	_run_until_done(game)
	_check(game.score == Game.TRAIN_POINTS + Game.STREAK_POINTS + Game.TRAIN_POINTS * 3 + Game.STREAK_POINTS * 2, "every car is worth a train, and a streak adds a little")
	game._spawn_train(0, 0, false, Game.JUNCTION - 0.01)
	_tap(game, KEY_DOWN)
	var before := game.score
	_run_until_done(game)
	_check(game.crashes == 1 and game.streak == 0 and game.score == before and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a red train sent to the yellow station tips into the toy box; the first time is a free look")
	game._spawn_train(0, 0, false, Game.JUNCTION - 0.01)
	_tap(game, KEY_RIGHT)
	_run_until_done(game)
	_check(game.crashes == 2 and game.mistakes == 1, "a second wrong station counts as a mistake")
	var late := _quiet()
	late._spawn_train(0, 0, false, Game.JUNCTION - 0.01)
	_tap(late, KEY_UP)
	_advance(late, 0.2)
	_tap(late, KEY_DOWN)
	_run_until_done(late)
	_check(late.delivered == 1, "the points only matter as the engine runs over them")


func _points_at_stop_hold_the_train() -> void:
	var game := _quiet()
	game._spawn_train(1, 1, false, Game.JUNCTION - 0.05)
	_advance(game, 3.0)
	var train: Dictionary = game.trains[0]
	_check(train.state == "run" and float(train.s) < Game.JUNCTION and int(train.branch) == -1 and train.waiting and game.score == 0 and game.crashes == 0,
		"with the points at stop a train waits at the signal, tooting, and nothing scores")
	_tap(game, KEY_RIGHT)
	_advance(game, 0.05)
	_check(int(train.branch) == 1 and game.points == Game.STOP, "throwing the points lets it go, and they spring back to stop behind it")
	_run_until_done(game)
	_check(game.delivered == 1, "and it runs home")


func _trains_keep_their_distance() -> void:
	var game := _quiet()
	game._spawn_train(0, 2, false, 0.3)
	game._spawn_train(1, 0, false, 0.29)
	_advance(game, 0.3)
	var lead: Dictionary = game.trains[0]
	var follow: Dictionary = game.trains[1]
	_check(float(follow.s) <= float(lead.s) - game.train_length(lead) - Game.GAP + 0.001, "a train never runs into the one in front")


func _the_backing_train() -> void:
	var game := _quiet()
	game._spawn_train(1, 0, true, Game.JUNCTION - 0.2)
	game.points = 1
	var stopped := false
	var backed := false
	var lowest := 9.0
	while game.trains.size() > 0 and int(game.trains[0].branch) < 0 and game.stage == "play":
		var was := float(game.trains[0].s)
		game.step(STEP)
		if game.trains.is_empty():
			break
		stopped = stopped or game.trains[0].phase == "stop"
		if float(game.trains[0].s) < was - 0.0001:
			backed = true
		lowest = minf(lowest, float(game.trains[0].s))
	_check(stopped and backed and lowest < Game.JUNCTION - Game.BACKER_STOP - 0.05 and game.backers == 1, "a backing train stops short of the points, toots and backs up before charging on")
	var held := _quiet()
	held._spawn_train(1, 0, true, Game.JUNCTION - 0.2)
	_advance(held, 6.0)
	var charger: Dictionary = held.trains[0]
	_check(charger.phase == "charge" and charger.waiting and int(charger.branch) == -1 and float(charger.s) < Game.JUNCTION,
		"even a charging train stops at the signal when the points are at stop")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var seen: Dictionary = {}
	var early := 0
	var late := 0
	var cars_late := 0
	var first_backer := -1.0
	var speed_early := game.speed()
	while game.stage == "play":
		var next := game.next_to_points()
		if not next.is_empty():
			game._throw(game.stations.find(int(next.colour)))
		game.step(STEP)
		for train: Dictionary in game.trains:
			if seen.has(train.id):
				continue
			seen[train.id] = true
			if game.heat() < 0.3:
				early += 1
			elif game.heat() > 0.6:
				late += 1
				cars_late += int(train.cars)
			if bool(train.backer) and first_backer < 0.0:
				first_backer = game.heat()
	_check(late > early * 1.5, "trains come more often later (%d to %d)" % [early, late])
	_check(game.speed() > speed_early * 1.6 and cars_late > 0, "they run faster and pull more cars")
	_check(first_backer >= Game.BACKER_HEAT, "backing trains only join later (%.2f)" % first_backer)


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "express", "shuffle"], "three variants are declared")
	var standard := _playing("standard")
	var express := _playing("express")
	_check(express.speed() > standard.speed() * 1.2, "the express runs faster")
	var shuffle := _playing("shuffle")
	var signs := shuffle.stations.duplicate()
	_advance(shuffle, Game.SHUFFLE_SECONDS + 0.1)
	_check(shuffle.stations != signs and shuffle.stations.size() == 3 and shuffle.shuffle_at > 0.0, "the station signs swap colours every so often")
	var unfair := _quiet("shuffle")
	unfair._spawn_train(int(unfair.stations[2]), 0, false, Game.JUNCTION - 0.01)
	_tap(unfair, KEY_DOWN)
	_advance(unfair, 0.2)
	unfair._shuffle()
	_run_until_done(unfair)
	_check(unfair.delivered == 1 and unfair.crashes == 0, "a train already past the points still counts as home after the signs swap")
	var helped := _playing("standard", true)
	_check(helped.speed() < standard.speed() * 0.85, "assist slows the trains down")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "express", "shuffle"]:
		var gold := _play(session, variant_id, false, 0.0, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a signalman who sets every train right earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, BRONZE_DELAY, BRONZE_WRONG, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"one who only throws once a train has waited a while, and often wrong, still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "standard", false, 0.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "throwing the points at random earns nothing (score %d)" % masher.score)
	var idle := _play(session, "standard", false, 0.0, 0.0, false, true)
	_check(not idle.success and idle.score == 0 and idle.mistakes == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.0, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("track switch scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: throw the points for the train
## nearest them once it has waited `delay` seconds at the signal, to the wrong
## station a share `wrong` of the time; `mash` throws at random instead and
## `idle` never touches anything.
func _play(session: Session, variant_id: String, assisted: bool, delay: float, wrong: float, mash: bool, idle := false) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-066", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 9
	var waited: Dictionary = {}
	var picks: Dictionary = {}
	var tick := 0
	while not session.ended and game.stage == "play":
		var press := -1
		if idle:
			pass
		elif mash:
			if tick % 30 == 0:
				press = decide.randi() % 3
		else:
			var next := game.next_to_points()
			if not next.is_empty():
				if not picks.has(next.id):
					picks[next.id] = 1 + decide.randi() % 2 if decide.randf() < wrong else 0
				var pick := (game.stations.find(int(next.colour)) + int(picks[next.id])) % 3
				if bool(next.get("waiting", false)):
					waited[next.id] = float(waited.get(next.id, 0.0)) + STEP
				var ready := delay <= 0.0 or float(waited.get(next.id, 0.0)) >= delay
				if ready and pick != game.points:
					press = pick
		if press >= 0:
			_session_key(session, KEYS[press], true)
			session._process(STEP)
			_session_key(session, KEYS[press], false)
		session._process(STEP)
		tick += 1
	for wait in 1200:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


## A round in play with no trains of its own, so a check can send them by hand.
func _quiet(variant_id := "standard") -> Game:
	var game := _playing(variant_id)
	game._next_train = 999.0
	game._next_shuffle = 999.0
	game.trains.clear()
	return game


func _run_until_done(game: Game) -> void:
	for tick in 1200:
		if game.trains.all(func(train: Dictionary) -> bool: return train.state != "run"):
			break
		game.step(STEP)


func _session_key(session: Session, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	session._unhandled_input(key)


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String, assisted := false) -> Game:
	var game := _round(variant_id, assisted)
	_advance(game, Base.READY_SECONDS + 0.01)
	return game


## First seed whose round uses the named variant.
func _seed_for(variant_id: String) -> int:
	for round_seed in 200:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		if game.variant.id == variant_id:
			return round_seed
	failures.append("no seed produced variant " + variant_id)
	return 0


func _advance(game: Base, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game.step(minf(left, STEP))
		left -= STEP


func _press(game: Base, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _tap(game: Base, code: int) -> void:
	_press(game, code, true)
	_press(game, code, false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
