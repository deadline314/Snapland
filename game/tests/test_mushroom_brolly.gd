extends SceneTree
## 蘑菇撐傘 rules: moving the cap, catching rain for the thirsty seedling,
## blooms and turns, hail bonks and dents, bruised seedlings, escalation,
## variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/mushroom_brolly_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_carries_the_cap()
	_sliding_the_cap()
	_catching_rain()
	_blooms_hand_the_thirst_on()
	_hail_bonks_and_bruises()
	_variants_and_escalation()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: mushroom brolly sliding, rain, gulps, blooms, turns, hail, dents, droops, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_carries_the_cap() -> void:
	var game := _round("drizzle", false)
	_check(game.stage == "ready" and game.thirsty == 1 and game.thresholds == [150, 340, 520], "a round opens with the second seedling thirsty and its medal lines declared")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_press(game, KEY_RIGHT, true)
		game.step(STEP)
	_check(absf(game.cap_x - Game.POTS[1]) < 0.01 and game.score == 0 and game.gulps == 0, "the countdown carries the cap over the thirsty seedling by itself; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.pots.all(func(pot: Dictionary) -> bool: return pot.gulps == 0), "play starts with every pot dry")


func _sliding_the_cap() -> void:
	var game := _playing("drizzle")
	var start := game.cap_x
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.5)
	_check(absf(game.cap_x - (start + Game.SPEED * 0.5)) < 0.03, "holding → slides the cap right")
	_press(game, KEY_RIGHT, false)
	var stopped := game.cap_x
	_advance(game, 0.3)
	_check(is_equal_approx(game.cap_x, stopped), "letting go stops it")
	_press(game, KEY_LEFT, true)
	_advance(game, 3.0)
	_press(game, KEY_LEFT, false)
	_check(game.cap_x >= Game.CAP_HALF * 0.5 - 0.001 and game.cap_x < 0.06, "the wall stops it")
	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_LEFT_X
	pad.axis_value = 1.0
	var before := game.cap_x
	game.handle_input(pad, Vector2.ZERO)
	_advance(game, 0.3)
	_check(game.cap_x > before + 0.2, "the gamepad stick slides it too")
	var helped := _round("drizzle", true)
	_check(helped.cap_half() > Game.CAP_HALF * 1.2, "assist widens the cap")


func _catching_rain() -> void:
	var game := _quiet("drizzle")
	var thirsty := game.thirsty
	game.cap_x = Game.POTS[thirsty]
	game._spawn("rain", game.cap_x + 0.05, Game.RAIN_FALL, 0.0)
	_advance(game, Game.RAIN_FALL * Game.CAP_Y + 0.05)
	var drop: Dictionary = game.drops.back()
	_check(drop.state == "caught" and game.score == Game.GULP_POINTS and game.pots[thirsty].gulps == 1, "rain the cap catches over the thirsty seedling drips into its pot: ten points")
	game.cap_x = Game.POTS[(thirsty + 1) % Game.POTS.size()]
	game._spawn("rain", game.cap_x, Game.RAIN_FALL, 0.0)
	_advance(game, Game.RAIN_FALL * Game.CAP_Y + 0.05)
	_check(game.drops.back().state == "splash" and game.score == Game.GULP_POINTS, "rain caught over a seedling that is not thirsty just splashes")
	game._spawn("rain", 0.95, Game.RAIN_FALL, 0.0)
	_advance(game, Game.RAIN_FALL + 0.05)
	_check(game.drops.back().state == "ground" and game.score == Game.GULP_POINTS, "rain the cap misses falls to the bench")


func _blooms_hand_the_thirst_on() -> void:
	var game := _quiet("drizzle")
	var first := game.thirsty
	game.cap_x = Game.POTS[first]
	for gulp in Game.GULPS_NEEDED:
		game._spawn("rain", game.cap_x, Game.RAIN_FALL, 0.0)
		_advance(game, Game.RAIN_FALL * Game.CAP_Y + 0.05)
	_check(game.blooms == 1 and game.pots[first].blooms == 1 and game.pots[first].gulps == 0
		and game.score == Game.GULP_POINTS * Game.GULPS_NEEDED + Game.BLOOM_POINTS, "four gulps make the seedling bloom: thirty more")
	_check(game.thirsty != first, "then another seedling gets thirsty")
	var turns: Dictionary = {}
	for bloom in 30:
		var was := game.thirsty
		game._bloom(was)
		_check(game.thirsty != was, "the thirst always moves to a different seedling")
		turns[game.thirsty] = true
	_check(turns.size() == Game.POTS.size(), "every seedling takes a turn")


func _hail_bonks_and_bruises() -> void:
	var game := _quiet("drizzle")
	game.cap_x = Game.POTS[0]
	game._spawn("hail", Game.POTS[0], Game.HAIL_FALL, 0.0)
	_advance(game, Game.HAIL_FALL * Game.CAP_Y + 0.05)
	_check(game.drops.back().state == "bonk" and game.score == Game.BONK_POINTS and game.snapshot().dents == 1 and game.droops == 0,
		"hail on the cap bonks off for five and dents it")
	_advance(game, Game.DENT_SECONDS)
	_check(game.snapshot().dents == 0, "dents pop back out after a while")
	game.cap_x = Game.POTS[0]
	for target in [2, 3]:
		game._spawn("hail", Game.POTS[target], Game.HAIL_FALL, 0.0)
		_advance(game, Game.HAIL_FALL + 0.05)
	_check(game.droops == 2 and game.mistakes == 1 and game.pots[2].droop_at > 0.0 and game.pots[3].droop_at > 0.0
		and game.score == maxi(0, Game.BONK_POINTS - Game.BRUISE_POINTS * 2), "hail that gets past bruises a seedling and costs twenty; the first one is not a mistake")
	game._spawn("hail", 0.5, Game.HAIL_FALL, 0.0)
	_advance(game, Game.HAIL_FALL + 0.05)
	_check(game.drops.back().state == "ground" and game.droops == 2, "hail between the pots just bounces on the bench")


func _variants_and_escalation() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["drizzle", "wind", "hail"], "three variants are declared")
	var drizzle := _playing("drizzle")
	var early_rain := _spawned(drizzle, "rain", 3.0)
	_check(_count(drizzle, "hail") == 0, "a drizzle round has no hail at first")
	_advance(drizzle, drizzle.round_seconds * 0.7)
	var late_rain := _spawned(drizzle, "rain", 3.0)
	_check(late_rain > early_rain * 1.5, "rain gets heavier later (%d then %d drops in three seconds)" % [early_rain, late_rain])
	var hail_late := 0
	var burst := false
	for round_seed in 12:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		_advance(game, Base.READY_SECONDS + game.round_seconds * 0.7)
		var times: Array[float] = []
		var seen: Dictionary = {}
		for tick in int(8.0 / STEP):
			game.step(STEP)
			for drop: Dictionary in game.drops:
				if drop.kind == "hail" and not seen.has(drop.born):
					seen[drop.born] = true
					times.append(drop.born)
		hail_late += times.size()
		for index in range(2, times.size()):
			burst = burst or times[index] - times[index - 2] < 0.7
	_check(hail_late >= 12 * 5 and burst, "late in a round hail comes often, sometimes in bursts")
	var wind := _playing("wind")
	_advance(wind, 1.0)
	_check(wind.drops.any(func(drop: Dictionary) -> bool: return drop.kind == "rain" and absf(drop.drift) > 0.1), "the windy variant slants the rain")
	var storm := _playing("hail")
	_advance(storm, 3.0)
	_check(storm.drops.any(func(drop: Dictionary) -> bool: return drop.kind == "hail") or storm.bonks + storm.droops > 0, "the hailstorm variant hails from the start")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["drizzle", "wind", "hail"]:
		var gold := _play(session, variant_id, false, true)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "watering and guarding earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "drizzle", false, false)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "only chasing the thirsty seedling, ignoring hail, still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "drizzle", false, false, true)
	_check(not idle.success and idle.score < lines[0], "never moving earns nothing (score %d)" % idle.score)
	var helped := _play(session, "drizzle", true, true)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("mushroom brolly scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session input. The player holds ← or → toward a
## target: the thirsty seedling, or (when `guard`) a hailstone about to hit a
## seedling that the cap can still reach. `idle` never touches anything.
func _play(session: Session, variant_id: String, assisted: bool, guard: bool, idle := false) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-079", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var holding := 0
	while not session.ended and game.stage == "play":
		var target := Game.POTS[game.thirsty]
		if guard:
			var soonest := 99.0
			for drop: Dictionary in game.drops:
				if drop.kind != "hail" or drop.state != "falling" or game._pot_under(float(drop.start), Game.POT_HALF + 0.015) < 0:
					continue
				var left: float = (Game.CAP_Y - game.drop_y(drop)) * float(drop.fall)
				var travel := absf(float(drop.start) - game.cap_x) / Game.SPEED
				if left > 0.0 and travel < left and left < soonest:
					soonest = left
					target = float(drop.start)
		var want := 0
		if not idle and absf(target - game.cap_x) > 0.02:
			want = 1 if target > game.cap_x else -1
		if want != holding:
			if holding != 0:
				_session_key(session, KEY_RIGHT if holding > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			holding = want
		session._process(STEP)
	if holding != 0:
		_session_key(session, KEY_RIGHT if holding > 0 else KEY_LEFT, false)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


## Drops of `kind` that start falling during the next `seconds`.
func _spawned(game: Game, kind: String, seconds: float) -> int:
	var seen: Dictionary = {}
	for tick in int(seconds / STEP):
		game.step(STEP)
		for drop: Dictionary in game.drops:
			if drop.kind == kind:
				seen[str(drop.born) + ":" + str(drop.start)] = true
	return seen.size()


func _count(game: Game, kind: String) -> int:
	return game.drops.filter(func(drop: Dictionary) -> bool: return drop.kind == kind).size()


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
	_advance(game, Base.READY_SECONDS + 0.02)
	# Checks below place things by hand, as if the player had already pressed a key.
	game.touched = true
	return game


## A playing round with the weather turned off, for hand-placed drops.
func _quiet(variant_id: String) -> Game:
	var game := _playing(variant_id)
	game.drops.clear()
	game._rain_due = 1e9
	game._hail_due = 1e9
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
