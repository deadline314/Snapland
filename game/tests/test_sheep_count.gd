extends SceneTree
## 窗簾星圖 rules: the countdown demo, counting sheep at the top of their leap,
## the dead-on bonus, stars and constellations, missed sheep, ghost sheep and
## empty presses as miscounts, dozing off, escalation, variants, assist and
## full simulated rounds.

const Game = preload("res://game/minigames/arcade/sheep_count_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_count()
	_untouched_rounds_never_score()
	_counting_real_sheep()
	_miscounts_send_the_traveller_to_sleep()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: sheep count demo, counting, dead-on bonus, stars, constellations, missed sheep, ghost sheep, empty presses, dozing, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_count() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [300, 800, 1400] and game.sheep.size() == 1, "a round opens with a sheep on the way")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
	_check(bool(game.sheep[0].counted) if not game.sheep.is_empty() else false, "the countdown counts the first sheep by itself")
	_check(game.score == 0 and game.miscounts == 0, "and scores nothing")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.counted == 0 and game.sheep.is_empty(), "play starts on an empty meadow")


func _counting_real_sheep() -> void:
	var game := _playing("standard")
	var one := _lone(game, false)
	_press_at(game, one, 0.0)
	_check(bool(one.counted) and game.counted == 1 and game.stars == 1 and game.score >= Game.COUNT_POINTS + Game.DEAD_ON_POINTS, "pressing as a sheep tops the fence counts it with the dead-on bonus and stitches a star")
	var near := _playing("standard")
	var two := _lone(near, false)
	_press_at(near, two, Game.WINDOW * 0.8)
	_check(bool(two.counted) and near.score == Game.COUNT_POINTS + Game.STREAK_POINTS, "a press a little early still counts, without the bonus")
	var skip := _playing("standard")
	var three := _lone(skip, false)
	skip.streak = 3
	_advance(skip, skip.top_time(three) - skip.clock + Game.WINDOW + 0.05)
	_check(bool(three.missed) and skip.streak == 0 and skip.miscounts == 0, "a sheep let by uncounted breaks the streak but is no miscount")
	var sky := _playing("standard")
	for sheep in Game.CONSTELLATION:
		var lone := _lone(sky, false)
		_press_at(sky, lone, 0.0)
	_check(sky.constellations == 1 and sky.stars == 0, "eight counted sheep complete a constellation")
	var pad := _playing("standard")
	var four := _lone(pad, false)
	_advance(pad, pad.top_time(four) - pad.clock)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(bool(four.counted), "the gamepad A button counts too")


func _miscounts_send_the_traveller_to_sleep() -> void:
	var game := _playing("standard")
	var ghost := _lone(game, true)
	_press_at(game, ghost, 0.0)
	_check(game.miscounts == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.dozing() and bool(ghost.miscounted) and not game.snapshot().word_good,
		"counting a ghost sheep sends the traveller to sleep; the first time is a free look")
	_tap(game, KEY_SPACE)
	_check(game.miscounts == 1, "presses while asleep count for nothing")
	_advance(game, Game.DOZE_SECONDS + 0.05)
	var empty := _playing("standard")
	_lone(empty, false)
	_tap(empty, KEY_SPACE)
	_check(empty.miscounts == 1, "a press with no sheep over the fence is a miscount too")
	_advance(empty, Game.DOZE_SECONDS + 0.05)
	_tap(empty, KEY_SPACE)
	_check(empty.miscounts == 2 and empty.mistakes == 1, "a second miscount counts as a mistake")
	var mash := _playing("standard")
	for tick in int(10.0 / STEP):
		if tick % 10 == 0:
			_tap(mash, KEY_SPACE)
		mash.step(STEP)
	_check(mash.miscounts >= 3 and mash.score < 150, "pressing all the time keeps dozing off (miscounts %d, score %d)" % [mash.miscounts, mash.score])


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.cross_seconds()
	var early_ghosts := 0
	for spawn in 100:
		game.sheep.clear()
		game._spawn()
		early_ghosts += game.sheep.filter(func(s: Dictionary) -> bool: return bool(s.ghost)).size()
	game.play_time = game.round_seconds * 0.9
	_check(game.cross_seconds() < early * 0.6, "the flock runs much faster by the end")
	var late_ghosts := 0
	var pairs := 0
	var disguise := 0.0
	for spawn in 200:
		game.sheep.clear()
		game._spawn()
		pairs += 1 if game.sheep.size() == 2 else 0
		for one: Dictionary in game.sheep:
			if bool(one.ghost):
				late_ghosts += 1
				disguise = maxf(disguise, float(one.disguise))
	_check(early_ghosts == 0 and late_ghosts > 30 and pairs > 20 and disguise > 0.6, "ghost sheep join later, come in pairs and disguise themselves better")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "herd", "ghostly"], "three variants are declared")
	var ghostly := _playing("ghostly")
	ghostly.play_time = ghostly.round_seconds * 0.1
	var ghosts := 0
	for spawn in 100:
		ghostly.sheep.clear()
		ghostly._spawn()
		ghosts += ghostly.sheep.filter(func(s: Dictionary) -> bool: return bool(s.ghost)).size()
	_check(ghosts > 25, "the ghost party brings ghost sheep early")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.cross_seconds() > standard.cross_seconds() * 1.3 and helped.window(Game.WINDOW) > Game.WINDOW * 1.3, "assist slows the flock and widens the window")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "herd", "ghostly"]:
		var gold := _play(session, variant_id, false, 0.02, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp counter earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.16, 0.25)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a drowsy counter still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0, 0.0)
	_check(not idle.success and idle.score == 0, "never counting earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.02, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("sheep count scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses: the counter presses for
## each sheep it takes for real, off by up to `wobble` seconds, and takes a
## ghost for real `fooled` of the time; a negative `wobble` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, wobble: float, fooled: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-092", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var dice := RandomNumberGenerator.new()
	dice.seed = 17
	var plans := {}
	while not session.ended and game.stage == "play":
		if wobble >= 0.0 and not game.dozing():
			for one: Dictionary in game.sheep:
				var key := str(one.born)
				if not plans.has(key):
					var take := not bool(one.ghost) or dice.randf() < fooled
					plans[key] = game.top_time(one) + dice.randf_range(-wobble, wobble) if take else -1.0
				var at := float(plans[key])
				if at >= 0.0 and game.clock >= at:
					plans[key] = -1.0
					_session_key(session, KEY_SPACE, true)
					_session_key(session, KEY_SPACE, false)
		session._process(STEP)
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


## A single sheep (ghost or real) on an otherwise empty meadow, just setting off.
func _lone(game: Game, ghost: bool) -> Dictionary:
	game._next_sheep = 999.0
	game.sheep.clear()
	var one := game._sheep(game.clock, Game.CROSS_FIRST, ghost)
	game.sheep.append(one)
	return one


## Step until `one` is `before` seconds from topping the fence, then press.
func _press_at(game: Game, one: Dictionary, before: float) -> void:
	_advance(game, maxf(0.0, game.top_time(one) - before - game.clock))
	_tap(game, KEY_SPACE)


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


func _session_key(session: Session, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	session._unhandled_input(key)


func _round(variant_id: String, assisted := false) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String, assisted := false) -> Game:
	var game := _round(variant_id, assisted)
	_advance(game, Base.READY_SECONDS + 0.01)
	# These checks set the scene up directly; count the round as played.
	game.touched = true
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


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
