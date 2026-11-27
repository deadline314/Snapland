extends SceneTree
## 露珠牽橋 rules: the countdown demo, tilting and rolling, drinking droplets,
## heavier drops gliding further, pouring into the bud, wormholes that a small
## drop falls through and a big one bridges, the splash on the traveller,
## escalation, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/dew_bridge_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_sip()
	_untouched_rounds_never_score()
	_tilting_rolls_the_drop()
	_drinking_and_pouring()
	_big_drops_glide_further()
	_wormholes_and_the_splash()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: dew bridge demo, tilt, roll, sips, glide, pours, wormholes, bridging, splash, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_sip() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [200, 420, 540] and game.droplets.size() == 1 and game.holes.size() == 2,
		"a round opens with a seed drop, one droplet dripping beside it and two wormholes")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_LEFT)
		game.step(STEP)
	_check(game.droplets.is_empty() and game.sips == 1 and game.score == 0 and game.splash.is_empty(),
		"the countdown tips the leaf by itself, the drop drinks the droplet and nothing scores; keys do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.sips == 0 and is_equal_approx(game.drop_x, Game.START_X) and game.drop_v == 0.0 and game.tilt == 0.0,
		"play starts from a level leaf and a still seed drop")
	var gap := INF
	for hole in game.holes:
		gap = minf(gap, absf(game.drop_x - float(hole.x)) - game.hole_width() * 0.5)
	_check(gap > 0.05 and game.drop_x > Game.DROOP_ZONE + 0.1, "the start leaves the drop well away from every hole and the edges")


func _tilting_rolls_the_drop() -> void:
	var game := _playing("standard")
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.4)
	_check(game.tilt > 0.3 and game.drop_v > 0.0 and game.drop_x > Game.START_X, "holding → tips the leaf and rolls the drop toward the tip")
	_press(game, KEY_RIGHT, false)
	_advance(game, 2.0)
	_check(is_zero_approx(game.tilt) and absf(game.drop_v) < 0.02, "letting go levels the leaf and the drop rolls to a stop")
	var x := game.drop_x
	_press(game, KEY_A, true)
	_advance(game, 0.3)
	_press(game, KEY_A, false)
	_check(game.drop_x < x and game.tilt < 0.0, "A tips it the other way")
	var pad := _playing("standard")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	pad.handle_input(stick, Vector2.ZERO)
	_advance(pad, 0.3)
	_check(pad.tilt > 0.2, "the gamepad stick tips the leaf too")
	var dpad := _playing("standard")
	var left := InputEventJoypadButton.new()
	left.button_index = JOY_BUTTON_DPAD_LEFT
	left.pressed = true
	dpad.handle_input(left, Vector2.ZERO)
	_advance(dpad, 0.3)
	_check(dpad.tilt < -0.2, "the gamepad D-pad tips it as well")


func _drinking_and_pouring() -> void:
	var game := _playing("standard")
	game.droplets.append({"x": Game.START_X + 0.03, "at": game.clock - 1.0})
	game.drop_v = 0.1
	_advance(game, 0.4)
	_check(game.sips == 1 and game.score == Game.SIP_POINTS and game.size > Game.SEED_SIZE and game.droplets.is_empty(), "rolling over a droplet drinks it and grows the drop")
	var falling := _playing("standard")
	falling.droplets.append({"x": Game.START_X + 0.01, "at": falling.clock})
	_advance(falling, 0.05)
	_check(falling.sips == 0, "a droplet still dripping cannot be drunk")
	var full := _playing("standard")
	full.size = Game.FULL_SIZE
	full.sips = 8
	full.holes.clear()
	full.drop_x = 0.95
	full.drop_v = 0.4
	_advance(full, 0.4)
	_check(full.pours == 1 and full.score == Game.POUR_POINTS * 2 + Game.FULL_BONUS and full.busy() and full.snapshot().word.begins_with("滿開"),
		"a full drop rolled off the tip pours into the bud for a big bonus")
	_advance(full, Game.POUR_SECONDS + 0.05)
	_check(not full.busy() and full.sips == 0 and is_equal_approx(full.size, Game.SEED_SIZE) and full.splash.is_empty(), "then a new seed drop starts")
	var small := _playing("standard")
	small.sips = 2
	small.size = 1.5
	small.holes.clear()
	small.drop_x = 0.97
	small.drop_v = 0.3
	_advance(small, 0.3)
	_check(small.pours == 1 and small.score == Game.POUR_POINTS / 2, "a half-grown drop pays less")


func _big_drops_glide_further() -> void:
	var seed := _playing("standard")
	var big := _playing("standard")
	big.size = Game.FULL_SIZE
	for game: Game in [seed, big]:
		game.holes.clear()
		game.drop_v = 0.3
	_advance(seed, 0.8)
	_advance(big, 0.8)
	_check(big.drop_x - Game.START_X > (seed.drop_x - Game.START_X) * 1.6, "a big drop slides much further on a level leaf than a seed drop")


func _wormholes_and_the_splash() -> void:
	var game := _playing("standard")
	game.holes = [{"x": 0.55, "chewed_at": -99.0}]
	game.play_time = game.round_seconds * 0.6
	game.drop_x = 0.5
	game.drop_v = 0.25
	_advance(game, 0.4)
	_check(game.splash.get("through", "") == "hole" and game.splashes == 1 and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a small drop drops through a wide wormhole; the first splash is a free look")
	_check(game.busy() and game.drop_x < 0.0, "the drop is gone while it splashes on the traveller")
	var hero_at := game.hero_x
	_advance(game, 0.5)
	_check(is_equal_approx(game.hero_x, hero_at), "the traveller stands still under the splash")
	_advance(game, Game.SPLASH_SECONDS)
	_check(not game.busy() and is_equal_approx(game.size, Game.SEED_SIZE), "a new seed drop drips after the splash")
	var big := _playing("standard")
	big.holes = [{"x": 0.55, "chewed_at": -99.0}]
	big.play_time = big.round_seconds * 0.6
	big.size = Game.FULL_SIZE
	big.drop_x = 0.5
	big.drop_v = 0.25
	_advance(big, 0.5)
	_check(big.splash.is_empty() and big.drop_x > 0.6, "a big drop stretches across the same wormhole like a bridge")
	var stem := _playing("standard")
	stem.drop_x = 0.08
	stem.drop_v = -0.2
	_advance(stem, 0.6)
	_check(stem.splash.get("through", "") == "stem" and stem.splashes == 1, "rolling off the stem end splashes too")
	_advance(stem, Game.SPLASH_SECONDS + 0.05)
	stem.drop_x = 0.05
	stem.drop_v = -0.3
	_advance(stem, 0.5)
	_check(stem.splashes == 2 and stem.mistakes == 1, "a second splash counts as a mistake")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.hole_width()
	_check(early < Game.RADIUS * Game.SEED_SIZE * 2.0, "at first even the seed drop bridges the wormholes")
	game.play_time = game.round_seconds * 0.55
	game.step(STEP)
	_check(game.holes.size() == 3 and game.hole_width() > early * 1.8, "halfway the caterpillar has chewed a third hole and the holes have widened")
	_check(float(game.holes.back().x) < 0.2, "a busy gardener's third hole appears by the stem")
	var dawdler := _playing("standard")
	dawdler.holes.resize(2)
	_advance(dawdler, 2.0)
	dawdler.play_time = dawdler.round_seconds * 0.55
	var resting := dawdler.drop_x
	dawdler.step(STEP)
	_check(dawdler.holes.size() == 3 and absf(float(dawdler.holes.back().x) - resting) < 0.01 and dawdler.splash.get("through", "") == "hole",
		"a drop left sitting still gets a hole chewed right under it and drops through")
	game.play_time = game.round_seconds * 0.95
	_check(game.hole_width() > Game.RADIUS * 2.0 * 2.2 and game.hole_width() < Game.RADIUS * 2.0 * Game.FULL_SIZE, "late on only a well-fed drop can cross, and a full one always can")
	var drips := _playing("standard")
	drips.holes.clear()
	var count := 0
	for second in 40:
		drips.droplets.clear()
		var before := drips.droplets.size()
		drips._next_drip = 0.0
		drips._drip()
		count += drips.droplets.size() - before
	_check(count > 30, "droplets keep dripping from the leaf tips")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "breeze", "heavy"], "three variants are declared")
	var breeze := _playing("breeze")
	breeze.holes.clear()
	breeze.play_time = 3.5
	_check(breeze.gust() < 0.0, "the breeze pushes the drop toward the stem now and then")
	breeze.play_time = 1.0
	_check(breeze.gust() == 0.0, "and calms in between")
	var heavy := _playing("heavy")
	heavy.droplets.append({"x": Game.START_X + 0.03, "at": heavy.clock - 1.0})
	heavy.drop_v = 0.1
	_advance(heavy, 0.4)
	_check(is_equal_approx(heavy.size, Game.SEED_SIZE + Game.SIP * 2.0), "big drips grow the drop twice as fast")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.damping() > standard.damping() * 1.2 and helped.reach() > standard.reach() * 1.3 and helped.span() > standard.span() * 1.25, "assist gives the leaf more grip, drinks from further away and bridges wider holes")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "breeze", "heavy"]:
		var gold := _play(session, variant_id, false, 0.12, 8)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a careful gardener earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.6, 2)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a hasty gardener who pours early still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0, 0)
	_check(not idle.success and idle.score < lines[0], "leaving the leaf alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.12, 8)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("dew bridge scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses. The gardener rolls toward the
## nearest droplet it can reach without falling through a hole and pours once
## the drop has drunk `pour_at` droplets (or is full). It rethinks every
## `react` seconds; a negative `react` never touches the leaf.
func _play(session: Session, variant_id: String, assisted: bool, react: float, pour_at: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-074", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var held := 0
	var next_think := 0.0
	while not session.ended and game.stage == "play":
		if react >= 0.0 and game.clock >= next_think:
			next_think = game.clock + react
			var want := _steer(game, _target(game, pour_at))
			if want != held:
				if held != 0:
					_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
				if want != 0:
					_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
				held = want
		session._process(STEP)
	if held != 0:
		_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
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


## Where the gardener wants the drop: off the tip once it has drunk enough,
## otherwise the nearest landed droplet it can reach without dropping through a
## hole, otherwise stay put between the holes.
func _target(game: Game, pour_at: int) -> float:
	if game.drop_x < 0.0:
		return Game.START_X
	var width := game.hole_width()
	var bridges := game.span() >= width
	if (game.sips >= pour_at or game.size >= Game.FULL_SIZE) and (bridges or _clear(game, game.drop_x, 1.0)):
		return 1.3
	var best := game.drop_x
	var gap := INF
	for droplet in game.droplets:
		var x := float(droplet.x)
		if absf(x - game.drop_x) < gap and (bridges or _clear(game, game.drop_x, x)):
			gap = absf(x - game.drop_x)
			best = x
	return best


func _clear(game: Game, from: float, to: float) -> bool:
	for hole in game.holes:
		var x := float(hole.x)
		if (x - from) * (x - to) <= 0.0 or absf(x - to) < game.hole_width() * 0.5 + game.radius():
			return false
	return true


## Hold toward the side that brings the drop's speed to what reaching `target` needs.
func _steer(game: Game, target: float) -> int:
	if game.drop_x < 0.0:
		return 0
	var wanted := clampf((target - game.drop_x) * 3.0, -0.5, 0.5)
	if target > 1.0:
		wanted = 0.6
	var error := wanted - game.drop_v
	if error > 0.04:
		return 1
	if error < -0.04:
		return -1
	return 0


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
	# These checks set the scene up directly; count the round as steered.
	game._steered = true
	return game

func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		for round_seed in 40:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 60.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 80 seeded rounds: %s" % [scored])



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
