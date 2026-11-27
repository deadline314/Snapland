extends SceneTree
## 磁鐵搬家 rules: the demo delivery, the crane, tin sticks and wood bonks, loads
## and the full magnet, the cast-iron weight, the helmet yank, escalation,
## variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/magnet_move_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_delivery()
	_the_crane_and_the_magnet()
	_loads_score_more()
	_the_heavy_weight_drags()
	_no_iron_takes_the_helmet()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: magnet move crane, tin and wood, loads, full magnet, heavy weight, helmet yank, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_delivery() -> void:
	var game := _round("moving", false)
	_check(game.stage == "ready" and game.thresholds == [150, 330, 500] and game.toys.size() == 2, "a round opens with a tin robot and a wooden block on the belt")
	var grabbed := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		grabbed = grabbed or not game.held.is_empty()
	_check(grabbed and game.held.is_empty() and game.toys.all(func(toy: Dictionary) -> bool: return toy.kind == "block" or toy.state == "boxed"),
		"the countdown fetches the robot past the block and boxes it by itself")
	_check(game.score == 0 and game.yanks == 0, "the demo scores nothing and the space bar does nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.held.is_empty() and game.toys.size() <= 1 and absf(game.crane_x - 0.5) < 0.01,
		"play starts with an empty magnet back over the middle of a fresh belt")


func _the_crane_and_the_magnet() -> void:
	var game := _playing("moving")
	_hold_off(game)
	game.crane_x = 0.5
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.2)
	_press(game, KEY_RIGHT, false)
	_check(absf(game.crane_x - (0.5 + Game.SPEED * 0.2)) < 0.02, "the right arrow runs the crane along the girder")
	_press(game, KEY_A, true)
	_advance(game, 3.0)
	_press(game, KEY_A, false)
	_check(is_equal_approx(game.crane_x, Game.RAIL_MIN), "A runs it left and the girder ends stop it")
	game.crane_x = 0.5
	game._place("car", 0.51)
	game._place("block", 0.49)
	_tap(game, KEY_SPACE)
	_press(game, KEY_LEFT, true)
	_advance(game, 0.1)
	_check(is_equal_approx(game.crane_x, 0.5), "the crane holds still while the magnet is down")
	_press(game, KEY_LEFT, false)
	_advance(game, 0.4)
	_check(game.held.size() == 1 and game.held[0].kind == "car" and game.bonks == 1 and game.yanks == 0,
		"the tin car clanks up to the magnet; the wooden block only gets bonked")
	_check(game.toys.any(func(toy: Dictionary) -> bool: return toy.kind == "block" and toy.state == "belt"), "the block rides on")
	var pad := _playing("moving")
	_hold_off(pad)
	pad.crane_x = 0.6
	pad._place("drum", 0.6)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.4)
	_check(pad.held.size() == 1, "the gamepad A button drops the magnet too")
	var arrow := _playing("moving")
	_hold_off(arrow)
	arrow.crane_x = 0.6
	arrow._place("mouse", 0.6)
	_tap(arrow, KEY_DOWN)
	_advance(arrow, 0.4)
	_check(arrow.held.size() == 1, "and so does the down arrow")


func _loads_score_more() -> void:
	for count in [1, 2, 3]:
		var game := _playing("moving")
		_hold_off(game)
		game.crane_x = 0.5
		for index in count:
			game._place(["robot", "car", "drum"][index], 0.49 + 0.01 * index)
		_tap(game, KEY_SPACE)
		_advance(game, 0.45)
		_check(game.held.size() == count, "one drop picks up every tin toy under it (%d)" % count)
		game.crane_x = Game.BOX_X
		_tap(game, KEY_SPACE)
		_advance(game, 0.45)
		var expected: int = Game.TOY_POINTS * count + Game.LOAD_BONUS[count]
		_check(game.held.is_empty() and game.boxed == count and game.trips == 1 and game.score == expected,
			"a load of %d dropped in the crate scores %d (%d)" % [count, expected, game.score])
	var full := _playing("moving")
	_hold_off(full)
	full.crane_x = 0.5
	for index in 4:
		full._place("robot", 0.48 + 0.01 * index)
	_tap(full, KEY_SPACE)
	_advance(full, 0.45)
	_check(full.held.size() == Game.CAPACITY and full.toys.filter(func(toy: Dictionary) -> bool: return toy.state == "belt").size() == 1,
		"the magnet holds three toys at most")
	_tap(full, KEY_SPACE)
	_check(not full.dropping() and full.yanks == 0 and full.mistakes == 0 and not full.snapshot().word_good, "a full magnet will not go down away from the crate")
	var empty := _playing("moving")
	_hold_off(empty)
	empty.crane_x = Game.BOX_X
	_tap(empty, KEY_SPACE)
	_advance(empty, 0.45)
	_check(empty.yanks == 0 and empty.mistakes == 0 and empty.score == 0, "an empty magnet dipped in the crate is harmless")
	var gone := _playing("moving")
	_hold_off(gone)
	gone._place("robot", Game.BELT_END - 0.01)
	_advance(gone, 0.5)
	_check(gone.lost == 1 and gone.mistakes == 0 and gone.toys.all(func(toy: Dictionary) -> bool: return toy.state != "belt"),
		"a toy that rides off the end drops in the recycling bin")


func _the_heavy_weight_drags() -> void:
	var game := _playing("moving")
	_hold_off(game)
	game.crane_x = 0.5
	game._place("weight", 0.5)
	_tap(game, KEY_SPACE)
	_advance(game, 0.45)
	_check(game.carrying_heavy() and game.snapshot().heavy, "the cast-iron weight sticks and drags the magnet down")
	var from := game.crane_x
	_press(game, KEY_LEFT, true)
	_advance(game, 0.2)
	_press(game, KEY_LEFT, false)
	_check(absf(from - game.crane_x - Game.HEAVY_SPEED * 0.2) < 0.02, "a crane carrying it crawls")
	game.crane_x = Game.BOX_X
	_tap(game, KEY_SPACE)
	_advance(game, 0.45)
	_check(game.score == Game.HEAVY_POINTS and game.heavies == 1 and not game.carrying_heavy(), "boxing it is worth a lot")


func _no_iron_takes_the_helmet() -> void:
	var game := _playing("moving")
	_hold_off(game)
	game.crane_x = 0.5
	game._place("duck", 0.5)
	_tap(game, KEY_SPACE)
	_advance(game, 0.2)
	_check(game.yanks == 1 and game.yanked() and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a magnet that finds only wood takes the traveller's helmet instead; the first time is a free look")
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.5)
	_check(is_equal_approx(game.crane_x, 0.5), "the crane is stuck while the traveller dangles")
	_tap(game, KEY_SPACE)
	_check(game.yanks == 1, "and the magnet cannot drop again")
	_advance(game, Game.YANK_SECONDS)
	_check(not game.yanked() and game.crane_x > 0.5, "after a moment the traveller drops back and the crane runs again")
	_press(game, KEY_RIGHT, false)
	_advance(game, 0.3)
	_tap(game, KEY_SPACE)
	_advance(game, 0.3)
	_check(game.yanks == 2 and game.mistakes == 1, "a second empty drop counts as a mistake")


func _the_round_escalates() -> void:
	var game := _playing("moving")
	var seen: Dictionary = {}
	var early := 0
	var late := 0
	var first_heavy := -1.0
	var first_decoy := -1.0
	var speed_early := game.belt_speed()
	while game.stage == "play":
		game.step(STEP)
		for toy: Dictionary in game.toys:
			if seen.has(toy.id):
				continue
			seen[toy.id] = true
			if game.heat() < 0.3:
				early += 1
			elif game.heat() > 0.7:
				late += 1
			if toy.kind == "weight" and first_heavy < 0.0:
				first_heavy = game.heat()
			if toy.kind == "woodbot" and first_decoy < 0.0:
				first_decoy = game.heat()
	_check(late > early * 1.4, "toys come faster later in the round (%d to %d)" % [early, late])
	_check(game.belt_speed() > speed_early * 1.8, "the belt speeds up")
	_check(first_heavy >= Game.HEAVY_HEAT and first_decoy >= Game.DECOY_HEAT, "weights and wooden lookalikes only join later (%.2f, %.2f)" % [first_heavy, first_decoy])


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["moving", "rush", "decoy"], "three variants are declared")
	var standard := _playing("moving")
	var rush := _playing("rush")
	_check(rush.belt_speed() > standard.belt_speed() * 1.2, "the rush belt runs faster")
	var decoy := _playing("decoy")
	var lookalike := false
	while decoy.heat() < 0.3:
		decoy.step(STEP)
		lookalike = lookalike or decoy.toys.any(func(toy: Dictionary) -> bool: return toy.kind == "woodbot")
	_check(lookalike, "the lookalike day sends wooden robots from the start")
	var helped := _playing("moving", true)
	_check(helped.grab_reach() > standard.grab_reach() * 1.3 and helped.belt_speed() < standard.belt_speed() * 0.8, "assist widens the magnet's pull and slows the belt")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["moving", "rush", "decoy"]:
		var gold := _play(session, variant_id, false, 3, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a crane hand who brings full loads earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "moving", false, 1, 1.4)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow hand who boxes one toy at a time still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "moving", false, 0, 0.0)
	_check(not masher.success and masher.score < lines[0], "dropping the magnet anywhere earns nothing (score %d)" % masher.score)
	var helped := _play(session, "moving", true, 3, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("magnet move scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input. The hand fetches the tin toy it
## can reach soonest and heads for the crate once it carries `load` toys (or
## nothing else is in reach), then rests `rest` seconds; `load` 0 just drops the
## magnet wherever it is, as often as it can.
func _play(session: Session, variant_id: String, assisted: bool, load: int, rest: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-063", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var steering := 0
	var idle_until := 0.0
	while not session.ended and game.stage == "play":
		var want := 0
		var drop := false
		if not game.dropping() and not game.yanked() and game.clock >= idle_until:
			if load == 0:
				drop = true
			else:
				var target := Game.BOX_X
				if game.held.size() < load:
					var aim := _aim(game)
					if aim >= 0.0:
						target = aim
					elif game.held.is_empty():
						target = -1.0
				if target >= 0.0:
					var gap := target - game.crane_x
					if absf(gap) <= (0.012 if target != Game.BOX_X else 0.03):
						drop = true
						if target == Game.BOX_X:
							idle_until = game.clock + rest
					else:
						want = 1 if gap > 0.0 else -1
		if want != steering:
			if steering != 0:
				_session_key(session, KEY_RIGHT if steering > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			steering = want
		if drop:
			_session_key(session, KEY_SPACE, true)
			session._process(STEP)
			_session_key(session, KEY_SPACE, false)
		session._process(STEP)
	if steering != 0:
		_session_key(session, KEY_RIGHT if steering > 0 else KEY_LEFT, false)
	for tick in 1200:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


## Where to meet the nearest tin toy still on the belt, leading it by the belt's
## travel while the crane gets there; -1 when there is none worth chasing.
func _aim(game: Game) -> float:
	var best := -1.0
	var best_time := 99.0
	for toy: Dictionary in game.toys:
		if toy.state != "belt" or not bool(toy.iron):
			continue
		if bool(toy.heavy) and not game.held.is_empty():
			continue
		var x := float(toy.x)
		var meet := x
		for pass_index in 3:
			meet = x + game.belt_speed() * (absf(meet - game.crane_x) / game.crane_speed() + Game.DOWN_SECONDS)
		if meet >= Game.BELT_END - 0.01:
			continue
		var time := absf(meet - game.crane_x) / game.crane_speed()
		if time < best_time:
			best_time = time
			best = meet
	return best


## Stop the round's own toys so a check can place them by hand.
func _hold_off(game: Game) -> void:
	game._next_toy = 999.0
	game.toys.clear()
	game.held.clear()


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
