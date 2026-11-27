extends SceneTree
## 骰塔改道 rules: the demo die, tipping the tower, the drift and the walls,
## cups, centre and streak points, the bonk, springs, the flapper, pairs,
## escalation, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/dice_tower_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_lands_a_die()
	_tipping_the_tower()
	_cups_and_bonks()
	_springs_flapper_and_pairs()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: dice tower tipping, drift, walls, cups, centre and streak points, bonks, springs, flapper, pairs, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_lands_a_die() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [400, 850, 1000] and game.dice.size() == 1 and game.dice[0].pips == 4, "a round opens with a die marked four in the tower")
	var cupped := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_LEFT)
		game.step(STEP)
		cupped = cupped or game.dice.any(func(die: Dictionary) -> bool: return die.state == "cup" and die.cup == 4)
	_check(cupped and game.score == 0 and game.bonks == 0, "the countdown tips the tower to land it in cup four by itself")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.dice.is_empty() and is_equal_approx(game.tilt, 0.0), "play starts with an upright tower")


func _tipping_the_tower() -> void:
	var game := _quiet()
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_check(is_equal_approx(game.tilt, 1.0), "holding → tips the tower right")
	_press(game, KEY_RIGHT, false)
	_advance(game, 0.3)
	_check(is_equal_approx(game.tilt, 0.0), "letting go stands it up again")
	game._drop(3, 0.5)
	var die: Dictionary = game.dice[0]
	_press(game, KEY_A, true)
	_advance(game, 0.4)
	_check(float(die.x) < 0.45, "a die slides toward the low side (A works like ←)")
	_advance(game, 0.8)
	_press(game, KEY_A, false)
	_check(float(die.x) >= Game.RADIUS - 0.0001, "the wall stops it")
	var pad := _quiet()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_RIGHT
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.3)
	_check(pad.tilt > 0.9, "the gamepad d-pad tips it too")


func _cups_and_bonks() -> void:
	var game := _quiet()
	for pips in [2, 3]:
		game._drop(pips, game._goal_x({"pips": pips}))
		_run_until_settled(game)
	_check(game.cupped == 2 and game.streak == 2 and game.score == (Game.CUP_POINTS + Game.CENTRE_POINTS) * 2 + Game.STREAK_POINTS * 3,
		"a die that drops straight above its cup lands dead centre: cup, centre and streak points (%d)" % game.score)
	game._drop(5, game._goal_x({"pips": 1}))
	var before := game.score
	_run_until_settled(game)
	_check(game.bonks == 1 and game.streak == 0 and game.score == before and game.mistakes == 0 and game.fail_at > 0.0 and game.bonk_pips == 5 and not game.snapshot().word_good,
		"a five landing in cup one bounces out and bonks the traveller, printing five pips; the first time is a free look")
	game._drop(1, game._goal_x({"pips": 1}) + 0.04)
	_run_until_settled(game)
	_check(game.bonks == 1 and game.cupped == 3, "a little off centre still goes in, for less")
	game._drop(2, 0.5 + (0.4 - 0.5) / Game.SPREAD)
	_run_until_settled(game)
	_check(game.bonks == 2 and game.mistakes == 1, "a die on the rim between cups bonks too, and a second bonk is a mistake")
	var idle := _playing("standard")
	idle._next_drop = 999.0
	idle._drop(3, idle._goal_x({"pips": 3}))
	_run_until_settled(idle)
	_check(idle.score == 0 and idle.cupped == 0, "a die nobody steered can still land in its cup, but pays nothing")


func _springs_flapper_and_pairs() -> void:
	var game := _quiet()
	game._add_springs()
	var spring: Dictionary = game.springs[0]
	var wall := Game.RADIUS if int(spring.side) < 0 else 1.0 - Game.RADIUS
	game._drop(3, wall)
	game.dice[0].y = float(spring.y) - 0.01
	_advance(game, 0.05)
	_check(signf(float(game.dice[0].vx)) == -float(spring.side) and absf(float(game.dice[0].vx)) > 1.0, "a die falling past a spring is kicked back across the shaft")
	var swat := _quiet()
	swat.flapper = true
	swat.flapper_phase = PI * 0.5
	swat._drop(3, 0.5)
	swat.dice[0].y = Game.FLAPPER_Y - 0.01
	_advance(swat, 0.03)
	_check(float(swat.dice[0].vx) > 0.5 and swat.dice[0].swatted, "the spinning flapper swats a die sideways")
	var pairs := _playing("twins")
	pairs.play_time = pairs.round_seconds * 0.5
	var seen_pair := false
	for tries in 60:
		pairs.dice.clear()
		pairs._drop_next()
		if pairs.dice.size() == 2:
			seen_pair = true
			_check(int(pairs.dice[1].pips) - int(pairs.dice[0].pips) >= 3, "a pair is always far enough apart for one tip to carry both")
	_check(seen_pair, "two dice fall at once")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.fall_seconds()
	var springs_at := -1.0
	var flapper_at := -1.0
	var pair_at := -1.0
	while game.stage == "play":
		game.step(STEP)
		if springs_at < 0.0 and not game.springs.is_empty():
			springs_at = game.heat()
		if flapper_at < 0.0 and game.flapper:
			flapper_at = game.heat()
		if pair_at < 0.0 and game.dice.filter(func(die: Dictionary) -> bool: return die.state == "fall").size() >= 2:
			pair_at = game.heat()
	_check(game.fall_seconds() < early * 0.7, "dice fall faster later")
	_check(springs_at >= Game.SPRINGS_HEAT - 0.01 and flapper_at >= Game.FLAPPER_HEAT - 0.01 and pair_at >= Game.PAIRS_HEAT - 0.01,
		"springs, the flapper and pairs join in that order (%.2f, %.2f, %.2f)" % [springs_at, flapper_at, pair_at])


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "springy", "twins"], "three variants are declared")
	var springy := _playing("springy")
	_check(not springy.springs.is_empty(), "the springy tower has springs from the start")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.fall_seconds() > standard.fall_seconds() * 1.1 and helped.cup_reach() > standard.cup_reach(), "assist slows the fall and widens the cups")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "springy", "twins"]:
		var gold := _play(session, variant_id, false, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady hand earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, BRONZE_SLACK, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a lazy hand who only steers some dice still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "standard", false, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "rocking the tower at random earns nothing (score %d)" % masher.score)
	var helped := _play(session, "standard", true, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("dice tower scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## The share of dice the bronze hand does not bother to steer.
const BRONZE_SLACK := 0.65


## Play a whole round through Session input: steer each falling die toward its
## cup, leaving a share `slack` of dice alone; `mash` rocks the tower at random.
func _play(session: Session, variant_id: String, assisted: bool, slack: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-069", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 21
	var lazy: Dictionary = {}
	var holding := 0
	var tick := 0
	while not session.ended and game.stage == "play":
		var want := 0
		if mash:
			want = [-1, 0, 1][(tick / 25 + decide.randi() % 2) % 3]
		else:
			var falling := game.dice.filter(func(die: Dictionary) -> bool: return die.state == "fall")
			if not falling.is_empty():
				var error := 0.0
				for die: Dictionary in falling:
					if not lazy.has(die.id):
						lazy[die.id] = decide.randf() < slack
					error += game._goal_x(die) - float(die.x) - float(die.vx) * 0.25 - game.tilt * Game.DRIFT * 0.12
				error /= falling.size()
				if not lazy[falling[0].id] and absf(error) > 0.008:
					want = 1 if error > 0.0 else -1
		if want != holding:
			if holding != 0:
				_session_key(session, KEY_RIGHT if holding > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			holding = want
		session._process(STEP)
		tick += 1
	if holding != 0:
		_session_key(session, KEY_RIGHT if holding > 0 else KEY_LEFT, false)
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


## A round in play with nothing falling, as if the player had pressed already.
func _quiet() -> Game:
	var game := _playing("standard")
	game._next_drop = 999.0
	game.dice.clear()
	game.touched = true
	return game


func _run_until_settled(game: Game) -> void:
	for tick in 1200:
		if game.dice.all(func(die: Dictionary) -> bool: return die.state in ["cup", "bonk"]):
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
