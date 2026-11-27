extends SceneTree
## 人肉砲彈 rules: squeezing, firing, the sliding net, splashes, the canvas, the fan, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/human_cannon_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_squeeze_and_fire()
	_landing_scores_by_the_net_centre()
	_misses_splash_or_tear_the_canvas()
	_the_net_speeds_up_and_shrinks_and_the_fan_blows()
	_variants_change_the_act()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: human cannon squeeze, fire, net, splash, canvas, fan, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.phase == "load" and game.thresholds == [250, 550, 850], "a round opens on a loaded cannon with its medal lines declared")
	var flew := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_press(game, KEY_SPACE, true)
		game.step(STEP)
		flew = flew or game.phase == "flight"
	_press(game, KEY_SPACE, false)
	_check(flew and game.phase == "net" and absf(game.land_offset) < 1.0 and game.score == 0, "the countdown fires one clown into the middle of the net by itself")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.phase == "load" and game.shots == 0 and game.power == 0.0, "play starts on a loaded cannon")


func _squeeze_and_fire() -> void:
	var game := _playing("standard")
	_press(game, KEY_SPACE, true)
	_check(game.phase == "squeeze", "holding the button squeezes the spring")
	_advance(game, Game.SQUEEZE_SECONDS * 0.5)
	_check(absf(game.power - 0.5) < 0.02 and absf(game.snapshot().aim_x - (Game.MUZZLE_X + game.power * Game.RANGE)) < 0.01,
		"power builds steadily and the aim marker shows where it would land")
	_press(game, KEY_SPACE, false)
	_check(game.phase == "flight" and absf(game.shot_power - 0.5) < 0.02 and game.power == 0.0 and game.shots == 1, "letting go fires")
	_press(game, KEY_SPACE, true)
	_check(game.phase == "flight", "a cannon in use cannot be squeezed")
	_press(game, KEY_SPACE, false)
	var greedy := _playing("standard")
	_press(greedy, KEY_SPACE, true)
	_advance(greedy, Game.SQUEEZE_SECONDS * Game.OVERLOAD + 0.05)
	_check(greedy.phase == "flight" and is_equal_approx(greedy.shot_power, Game.OVERLOAD), "holding past the limit fires by itself at full overload")
	_advance(greedy, Game.FLIGHT_SECONDS + 0.02)
	_check(greedy.phase == "canvas", "and that always goes through the canvas: full is never the answer")


func _landing_scores_by_the_net_centre() -> void:
	var game := _playing("standard")
	var before := game.score
	_shoot_at(game, 0.0)
	_check(game.phase == "net" and game.landed == 1 and game.bullseyes == 1 and game.score - before == Game.NET_POINTS + Game.AIM_POINTS + Game.BULLSEYE_BONUS,
		"a clown in the very middle of the net scores the most: %d" % (Game.NET_POINTS + Game.AIM_POINTS + Game.BULLSEYE_BONUS))
	_advance(game, Game.LAND_SECONDS + Game.RELOAD_SECONDS + 0.05)
	_check(game.phase == "load", "the next clown climbs in by itself")
	before = game.score
	_shoot_at(game, game.net_width * 0.5 * 0.9)
	_check(game.phase == "net" and game.bullseyes == 1 and game.score - before == Game.NET_POINTS + roundi(Game.AIM_POINTS * 0.1) + Game.STREAK_BONUS,
		"the edge of the net only just counts; a second net in a row adds a streak bonus")


func _misses_splash_or_tear_the_canvas() -> void:
	var game := _playing("standard")
	_shoot_at(game, -game.net_width)
	_check(game.phase == "splash" and game.misses == 1 and game.mistakes == 0 and game.streak == 0 and not game.snapshot().word_good,
		"short of the net the clown splashes into the trough; the first miss is free")
	_advance(game, Game.FAIL_SECONDS + Game.RELOAD_SECONDS + 0.05)
	_check(game.phase == "load", "then a dripping clown reloads")
	_shoot_at(game, game.net_width)
	_check(game.phase == "splash" and game.mistakes == 1, "later misses are mistakes")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.net_speed() < Game.NET_SPEED_EARLY, "assist slides the net slower")
	_shoot_at(helped, Game.BULLSEYE * 1.3)
	_check(helped.bullseyes == 1, "and widens the bullseye")


func _the_net_speeds_up_and_shrinks_and_the_fan_blows() -> void:
	var game := _playing("standard")
	var early_speed := game.net_speed()
	var early_width := game.net_width
	var low := 9999.0
	var high := 0.0
	var fans_early := 0
	var fans_late := 0
	while game.stage == "play":
		low = minf(low, game.net_x)
		high = maxf(high, game.net_x)
		if game.phase == "load":
			if not is_zero_approx(game.fan):
				if game.heat() < Game.FAN_FROM_HEAT:
					fans_early += 1
				else:
					fans_late += 1
			_press(game, KEY_SPACE, true)
			_press(game, KEY_SPACE, false)
		game.step(STEP)
	_check(game.net_speed() > early_speed * 2.4 and game.net_width < early_width * 0.6, "the net slides faster and shrinks as the round goes on")
	_check(low >= Game.NET_LEFT - 0.01 and high <= Game.NET_RIGHT + 0.01 and high - low > 400.0, "it slides back and forth between its two stops")
	_check(fans_early == 0 and fans_late > 0, "the fan only joins in the second half")
	var windy := _playing("windy")
	windy.net_dir = 0.0
	_check(absf(windy.fan) >= 50.0, "the windy variant blows from the first shot")
	var plain_x := Game.MUZZLE_X + 0.5 * Game.RANGE
	windy.net_x = plain_x
	_press(windy, KEY_SPACE, true)
	_advance(windy, Game.SQUEEZE_SECONDS * 0.5)
	_press(windy, KEY_SPACE, false)
	_advance(windy, Game.FLIGHT_SECONDS + 0.02)
	_check(absf(windy.land_x - (Game.MUZZLE_X + windy.shot_power * Game.RANGE + windy.fan)) < 0.01 and absf(windy.land_x - plain_x) > 40.0,
		"the fan bends the shot by its own push")


func _variants_change_the_act() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "tiny", "windy", "blind"], "four variants are declared")
	var tiny := _playing("tiny")
	var plain := _playing("standard")
	_check(tiny.net_width < plain.net_width * 0.75, "the tiny net is much narrower")
	var blind := _playing("blind")
	_advance(blind, blind.round_seconds * 0.5)
	_check(blind.snapshot().blind and not plain.snapshot().blind, "the blind variant hides the aim marker in the second half")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "tiny", "windy", "blind"]:
		# Gold: lead the net and let go so the clown lands in its middle.
		var gold := _play(session, variant_id, false, 0.0, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "reading the net earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: leads the net only half as far as it should, so it often lands off-centre or short.
	var bronze := _play(session, "standard", false, 0.5, 0)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "leading the net only halfway still earns bronze (score %d)" % bronze.score)
	var holder := _play(session, "standard", false, 0.0, 1)
	_check(not holder.success and holder.score < lines[0] and holder.mistakes > 3, "holding until the spring gives earns nothing (score %d)" % holder.score)
	var helped := _play(session, "standard", true, 0.0, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("human cannon scores: gold %s, bronze %d, holder %d, assisted %d" % [gold_scores, bronze.score, holder.score, helped.score])
	session.free()


## Play a whole round through Session input. The bot predicts where the net will
## be when the clown lands (`lag` 1 means it aims at where the net is now) and
## lets go once the aim reaches it; `overhold` 1 never lets go at all.
func _play(session: Session, variant_id: String, assisted: bool, lag: float, overhold: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-055", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	while not session.ended and game.stage == "play":
		if game.phase == "load":
			_session_key(session, KEY_SPACE, true)
		elif game.phase != "squeeze":
			_session_key(session, KEY_SPACE, false)
		elif overhold == 0:
			var target := _predict_net(game, lag)
			if game.aim_x(game.power + STEP / Game.SQUEEZE_SECONDS * 0.5) >= target:
				_session_key(session, KEY_SPACE, false)
		_run_session(session, STEP)
	_session_key(session, KEY_SPACE, false)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


## Net position one flight from now (or now, with `lag` 1), following its bounces.
func _predict_net(game: Game, lag: float) -> float:
	var x := game.net_x
	var direction := game.net_dir
	var left := Game.FLIGHT_SECONDS * (1.0 - lag)
	while left > 0.0:
		var slice := minf(STEP, left)
		x += direction * game.net_speed() * slice
		if x > Game.NET_RIGHT:
			x = Game.NET_RIGHT - (x - Game.NET_RIGHT)
			direction = -1.0
		elif x < Game.NET_LEFT:
			x = Game.NET_LEFT + (Game.NET_LEFT - x)
			direction = 1.0
		left -= slice
	return x


## Freeze the net and fire so the clown lands `offset` pixels from its middle.
func _shoot_at(game: Game, offset: float) -> void:
	game.net_dir = 0.0
	game.fan = 0.0
	var target := game.net_x + offset
	_press(game, KEY_SPACE, true)
	game.power = (target - Game.MUZZLE_X) / Game.RANGE
	_press(game, KEY_SPACE, false)
	_advance(game, Game.FLIGHT_SECONDS + 0.02)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


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


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
