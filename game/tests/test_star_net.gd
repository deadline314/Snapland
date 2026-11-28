extends SceneTree
## 落星接網 rules: the demo catch, running, catching stars into the baskets,
## combos and misses, thunderclouds and the zap, big stars caught twice, pairs
## from both sides, quicker falls, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/star_net_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_catches_one()
	_running_and_catching()
	_thunderclouds_zap()
	_big_stars_bounce()
	_the_sky_gets_busier()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: star net demo, running, catching, baskets, combos, misses, thunderclouds and the zap, big stars caught twice, pairs from both sides, quicker falls, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_catches_one() -> void:
	var game := _round("shower", false)
	_check(game.stage == "ready" and game.thresholds == [250, 520, 720] and game.drops.size() == 1, "a round opens with one star falling")
	var caught := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		if tick % 10 == 0:
			_tap(game, KEY_LEFT)
		game.step(STEP)
		caught = caught or game.drops.any(func(drop: Dictionary) -> bool: return drop.state == "caught")
	_check(caught and game.score == 0 and game.caught == 0, "the countdown runs over and nets it by itself; the arrows do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and is_equal_approx(game.hero_x, 0.5), "play starts back in the middle")
	_advance(game, 0.3)
	_check(game.drops.size() >= 1, "and the first star is on its way")


func _running_and_catching() -> void:
	var game := _quiet()
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_press(game, KEY_RIGHT, false)
	_check(absf(game.hero_x - (0.5 + 0.3 * Game.SPEED)) < 0.01, "holding → runs right")
	for star in 4:
		game._drop("star", game.hero_x, 0.2)
		_advance(game, 0.25)
	_check(game.caught == 4 and game.combo == 4 and game.score == Game.STAR_POINTS * 4 + 2, "stars dropping into the net are caught, and a run of them adds a little (%d)" % game.score)
	game._drop("star", fposmod(game.hero_x + 0.4, 1.0), 0.2)
	_advance(game, 0.25)
	_check(game.missed == 1 and game.combo == 0, "a star that falls past breaks the run")
	var pad := _quiet()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_LEFT
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.2)
	_check(pad.hero_x < 0.35, "the gamepad d-pad runs too")
	var still := _playing("shower")
	still._drop_due = 999.0
	still.drops.clear()
	still._drop("star", 0.5, 0.2)
	_advance(still, 0.25)
	_check(still.score == 0 and still.caught == 0 and not still.touched, "a net nobody has moved catches for nothing")


func _thunderclouds_zap() -> void:
	var game := _quiet()
	game.score = 50
	game.combo = 3
	game._drop("thunder", game.hero_x, 0.2)
	_advance(game, 0.25)
	_check(game.stunned() and game.zaps == 1 and game.score == 50 - Game.ZAP_POINTS and game.combo == 0 and game.mistakes == 0 and game.fail_at > 0.0
		and not game.snapshot().word_good, "catching a thundercloud zaps the traveller; the first time is a free look")
	var held := game.hero_x
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_press(game, KEY_RIGHT, false)
	game._drop("star", game.hero_x, 0.1)
	_advance(game, 0.15)
	_check(absf(game.hero_x - held) < 0.001 and game.caught == 0, "a frazzled net can't move or catch")
	_advance(game, Game.STUN_SECONDS)
	game.combo = 2
	game._drop("thunder", fposmod(game.hero_x + 0.4, 1.0), 0.1)
	_advance(game, 0.15)
	_check(not game.stunned() and game.combo == 2 and game.missed == 1, "a thundercloud let past costs nothing")
	game._drop("thunder", game.hero_x, 0.1)
	_advance(game, 0.15)
	_check(game.zaps == 2 and game.mistakes == 1, "a second zap counts as a mistake")


func _big_stars_bounce() -> void:
	var game := _quiet()
	game._drop("big", game.hero_x, 0.2)
	var big: Dictionary = game.drops.back()
	_advance(game, 0.25)
	_check(big.bounced and big.state == "fall" and game.score == Game.BIG_FIRST and absf(float(big.target) - float(big.start)) >= 0.17,
		"a big star springs back up off the net towards somewhere else")
	var peak := 1.0
	for tick in int(Game.REBOUND * 0.5 / STEP):
		game.step(STEP)
		peak = minf(peak, game.height(big))
	_check(peak < 0.5, "it climbs high before coming down again (%.2f)" % peak)
	game.hero_x = float(big.target)
	_advance(game, Game.REBOUND * 0.5 + 0.05)
	_check(big.state == "caught" and game.bigs == 1 and game.score == Game.BIG_FIRST + Game.BIG_POINTS, "caught a second time it goes in the basket for a big bonus")


func _the_sky_gets_busier() -> void:
	var game := _playing("shower")
	var seen: Dictionary = {}
	var early_falls: Array[float] = []
	var late_falls: Array[float] = []
	var pairs_early := 0
	var pairs_late := 0
	var bigs_early := 0
	var bigs := 0
	var thunders := 0
	while game.stage == "play":
		game.step(STEP)
		var born: Dictionary = {}
		for drop: Dictionary in game.drops:
			if seen.has(drop.id) or drop.bounced:
				continue
			seen[drop.id] = true
			born[drop.born] = int(born.get(drop.born, 0)) + 1
			if game.heat() < 0.3:
				early_falls.append(float(drop.fall))
			elif game.heat() > 0.7:
				late_falls.append(float(drop.fall))
			if drop.kind == "big":
				bigs += 1
				bigs_early += int(game.heat() < Game.BIG_HEAT - 0.02)
			thunders += int(drop.kind == "thunder")
		for at: float in born.keys():
			if int(born[at]) >= 2:
				if game.heat() < Game.PAIR_HEAT - 0.02:
					pairs_early += 1
				else:
					pairs_late += 1
	_check(not early_falls.is_empty() and not late_falls.is_empty() and late_falls.max() < early_falls.min(), "stars fall faster later")
	_check(pairs_early == 0 and pairs_late > 0, "later they come two at a time from either side (%d pairs)" % pairs_late)
	_check(bigs_early == 0 and bigs > 0 and thunders > 0, "thunderclouds come, and big stars only later (%d big, %d thunder)" % [bigs, thunders])


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["shower", "storm", "bouncy"], "three variants are declared")
	var counts: Array[int] = []
	var early_big := false
	for variant_id: String in ["shower", "storm", "bouncy"]:
		var game := _playing(variant_id)
		var seen: Dictionary = {}
		var thunders := 0
		var drops := 0
		while game.stage == "play":
			game.step(STEP)
			for drop: Dictionary in game.drops:
				if not seen.has(drop.id):
					seen[drop.id] = true
					drops += 1
					thunders += int(drop.kind == "thunder")
					early_big = early_big or (variant_id == "bouncy" and drop.kind == "big" and game.heat() < 0.2)
		counts.append(roundi(100.0 * thunders / maxf(1.0, drops)))
	_check(counts[1] > counts[0], "the stormy night sends more thunderclouds (%s%%)" % [counts])
	_check(early_big, "big bouncy stars come from the start on a bouncy night")
	var helped := _quiet(true)
	var plain := _quiet()
	_check(helped.net_half() > plain.net_half() * 1.2, "assist widens the net")
	helped._drop_due = 0.0
	plain._drop_due = 0.0
	helped.step(STEP)
	plain.step(STEP)
	_check(float(helped.drops.back().fall) > float(plain.drops.back().fall), "and slows the falling")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["shower", "storm", "bouncy"]:
		var gold := _play(session, variant_id, false, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "quick feet earn gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "shower", false, BRONZE_SKIP, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a dawdler who lets plenty drop still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "shower", false, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "running back and forth without looking earns nothing (score %d)" % masher.score)
	var idle := _play(session, "shower", false, 1.0, false)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "shower", true, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("star net scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## The share of stars the bronze player lets drop.
const BRONZE_SKIP := 0.6


## Play a whole round through Session input: run under the star that lands
## next (skipping thunderclouds), giving up on a share `skip` of stars; `mash`
## runs back and forth on a timer instead.
func _play(session: Session, variant_id: String, assisted: bool, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-106", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 53
	var chosen: Dictionary = {}
	var held := 0
	var tick := 0
	while not session.ended and game.stage == "play":
		var want := 0
		if mash:
			want = 1 if (tick / 40) % 2 == 0 else -1
		elif skip < 1.0:
			var target := -1.0
			var soonest := INF
			for drop: Dictionary in game.drops:
				if drop.state != "fall" or drop.kind == "thunder":
					continue
				if not chosen.has(drop.id):
					chosen[drop.id] = decide.randf() >= skip
				if not chosen[drop.id]:
					continue
				var left := float(drop.fall) - (game.clock - float(drop.born))
				if left < soonest:
					soonest = left
					target = float(drop.target)
			# Step aside from a thundercloud about to land in the net.
			for drop: Dictionary in game.drops:
				if drop.state == "fall" and drop.kind == "thunder" and float(drop.fall) - (game.clock - float(drop.born)) < 0.35 \
						and absf(float(drop.x) - game.hero_x) < game.net_half() + 0.04:
					target = float(drop.x) + (0.2 if float(drop.x) < 0.5 else -0.2)
			if target >= 0.0 and absf(target - game.hero_x) > 0.01:
				want = 1 if target > game.hero_x else -1
		if want != held:
			if held != 0:
				_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			held = want
		session._process(STEP)
		tick += 1
	if held != 0:
		_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
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


## A round in play with nothing falling, so a check can drop things by hand.
func _quiet(assisted := false) -> Game:
	var game := _playing("shower", assisted)
	game._drop_due = 999.0
	game.drops.clear()
	_tap(game, KEY_UP)
	return game


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
