extends SceneTree
## 羽球上升流 rules: the demo lob, running, lobs and clean hits, rallies, gusts
## shown on the windsock before they blow, the second shuttle, feather hats,
## escalation, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/shuttle_updraft_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_lobs_once()
	_running_and_lobbing()
	_misses_make_a_feather_hat()
	_gusts_and_the_windsock()
	_second_shuttle_and_escalation()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: shuttle updraft demo, running, lobs, clean hits, rallies, gusts and windsock, second shuttle, feather hats, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_lobs_once() -> void:
	var game := _round("breeze", false)
	_check(game.stage == "ready" and game.thresholds == [180, 420, 540] and game.shuttles.size() == 1 and game.hats == 0,
		"a round opens with one shuttle floating down")
	var lobbed := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		if tick % 10 == 0:
			_tap(game, KEY_LEFT)
		game.step(STEP)
		lobbed = lobbed or (not game.shuttles.is_empty() and float(game.shuttles[0].vy) > 0.0)
	_check(lobbed and game.score == 0 and game.hits == 0 and game.hats == 0, "the countdown runs over and lobs it by itself; the arrows do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and is_equal_approx(game.hero_x, 0.5) and game.hats == 0, "play starts back in the middle")
	_advance(game, 0.25)
	_check(game.shuttles.size() == 1 and float(game.shuttles[0].y) > 0.9, "and a new shuttle is served from high up")


func _running_and_lobbing() -> void:
	var game := _quiet()
	var start := game.hero_x
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_press(game, KEY_RIGHT, false)
	_check(absf(game.hero_x - (start + 0.3 * Game.SPEED)) < 0.01, "holding → runs right at a steady speed")
	_press(game, KEY_A, true)
	_advance(game, 3.0)
	_press(game, KEY_A, false)
	_check(game.hero_x <= Game.LEFT_WALL + 0.021, "and the rail stops you")
	var pad := _quiet()
	var motion := InputEventJoypadButton.new()
	motion.button_index = JOY_BUTTON_DPAD_RIGHT
	motion.pressed = true
	pad.handle_input(motion, Vector2.ZERO)
	_advance(pad, 0.2)
	_check(pad.hero_x > 0.6, "the gamepad d-pad runs too")
	# A shuttle dropping onto the middle of the strings is lobbed back up high.
	game.hero_x = 0.5
	var shuttle := _drop(game, 0.5)
	_check(float(shuttle.vy) > 0.0 and game.hits == 1 and game.sweets == 1 and game.rally == 1 and game.score == Game.HIT_POINTS + Game.SWEET_POINTS,
		"a shuttle on the middle of the strings is a clean shot (%d)" % game.score)
	var peak := _peak(game, shuttle)
	_check(peak > Game.APEX - 0.05, "a lob climbs back up high (%.2f)" % peak)
	var before := game.score
	shuttle = _drop(game, 0.5 + Game.RACKET_HALF * 0.85)
	_check(game.hits == 2 and game.sweets == 1 and game.score - before == Game.HIT_POINTS + Game.RALLY_STEP and float(shuttle.vx) > 0.15,
		"off the edge it still goes up, for less, and flies off sideways (%d)" % (game.score - before))
	for hit in 8:
		_drop(game, game.hero_x)
	_check(game.rally == 10 and game.best_rally == 10 and game.score - before > 10 * (Game.HIT_POINTS + Game.SWEET_POINTS), "a long rally pays more and more for each hit")
	var wide := _drop(game, game.hero_x + Game.RACKET_HALF + 0.02)
	_check(float(wide.vy) < 0.0 and game.hits == 10, "a shuttle past the racket keeps falling")


func _misses_make_a_feather_hat() -> void:
	var game := _quiet()
	game.rally = 5
	game._launch(0.2, 0.2, 0.0, -0.5)
	_advance(game, 0.5)
	_check(game.hats == 1 and game.misses == 1 and game.rally == 0 and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a shuttle that reaches the deck sticks in your hair; the first one is a free look")
	_advance(game, Game.SERVE_SECONDS + 0.05)
	_check(game.shuttles.size() == 1 and str(game.shuttles[0].state) == "air", "and a new shuttle is served")
	for miss in 7:
		game.shuttles.clear()
		game._launch(0.2, 0.05, 0.0, -0.5)
		_advance(game, 0.2)
		game._serves.clear()
	_check(game.misses == 8 and game.mistakes == 7 and game.hats == Game.MAX_HAT, "every later miss counts and the hat grows (to %d feathers)" % game.hats)
	# A racket nobody has touched still bounces shuttles, but pays nothing.
	var still := _playing("breeze")
	still._serves.clear()
	still.shuttles.clear()
	still._launch(0.5, 0.6, 0.0, -0.3)
	_advance(still, 1.5)
	_check(still.score == 0 and still.hits == 0 and not still.touched and float(still.shuttles[0].vy) != 0.0, "an untouched racket bounces the shuttle without points")


func _gusts_and_the_windsock() -> void:
	var game := _playing("breeze")
	game._serves.clear()
	var kinds: Dictionary = {}
	var early := 0
	var late := 0
	var warned := true
	var lifted := true
	var pushed := true
	var downed_early := false
	var last_start := -1.0
	while game.stage == "play":
		game.step(STEP)
		if game.gust.is_empty():
			continue
		var gust := game.gust
		if float(gust.start) != last_start:
			last_start = float(gust.start)
			kinds[gust.kind] = true
			warned = warned and is_equal_approx(float(gust.start) - float(gust.warn_at), Game.WARN)
			if game.heat() < 0.5:
				early += 1
			else:
				late += 1
			downed_early = downed_early or (gust.kind == "down" and game.heat() < Game.DOWN_HEAT)
		var blowing: bool = game.clock >= float(gust.start) and game.clock < float(gust.end)
		match str(gust.kind):
			"lift":
				lifted = lifted and (game.lift() > 0.0) == blowing
			"side":
				pushed = pushed and (signf(game.wind()) == float(gust.side)) == blowing
	_check(kinds.has("lift") and kinds.has("side") and kinds.has("down") and not downed_early, "lifts, side gusts and (later) downdrafts all blow (%s)" % [kinds.keys()])
	_check(warned and lifted and pushed, "each gust shows on the windsock first and only pushes while it blows")
	_check(late > early, "gusts come more often later (%d then %d)" % [early, late])
	var blown := _quiet()
	blown.gust = {"kind": "side", "side": 1, "warn_at": blown.clock - 1.0, "start": blown.clock, "end": blown.clock + 2.0}
	var shuttle := {"id": 99, "x": 0.4, "y": 0.9, "vx": 0.0, "vy": 0.0, "state": "air", "at": -99.0, "from": Vector2.ZERO}
	blown.shuttles.append(shuttle)
	_advance(blown, 0.5)
	_check(float(shuttle.x) > 0.45, "a side gust carries a shuttle off")
	var floating := _quiet()
	floating.gust = {"kind": "lift", "side": 1, "warn_at": floating.clock - 1.0, "start": floating.clock, "end": floating.clock + 2.0}
	var calm := _quiet()
	for each: Game in [floating, calm]:
		each._launch(0.2, 0.9, 0.0, 0.0)
		_advance(each, 1.0)
	_check(float(floating.shuttles[0].y) > float(calm.shuttles[0].y) + 0.1, "a lift makes it hang in the air")


func _second_shuttle_and_escalation() -> void:
	var game := _playing("breeze")
	var most_early := 0
	var most_late := 0
	while game.stage == "play":
		game.step(STEP)
		var flying := game.shuttles.filter(func(item: Dictionary) -> bool: return item.state == "air")
		if game.heat() < Game.TWIN_HEAT - 0.02:
			most_early = maxi(most_early, flying.size())
		else:
			most_late = maxi(most_late, flying.size())
	_check(most_early == 1 and most_late == 2, "a second shuttle joins in halfway (%d then %d)" % [most_early, most_late])
	_check(game.gravity() > Game.GRAVITY_FIRST * 1.5 and game.fall_limit() > Game.FALL_FIRST * 1.5, "shuttles fall faster later")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["breeze", "gusty", "twin"], "three variants are declared")
	var gusty := _quiet("gusty")
	gusty.gust = {"kind": "lift", "side": 1, "warn_at": gusty.clock - 1.0, "start": gusty.clock, "end": gusty.clock + 2.0}
	var calm := _quiet()
	calm.gust = gusty.gust.duplicate()
	_check(gusty.lift() > calm.lift() * 1.2, "the gusty variant blows harder")
	var twin := _playing("twin")
	var pair := false
	while twin.stage == "play" and twin.heat() < 0.35:
		twin.step(STEP)
		pair = pair or twin.shuttles.filter(func(item: Dictionary) -> bool: return item.state == "air").size() == 2
	_check(pair, "the twin variant brings the second shuttle in early")
	var helped := _quiet("breeze", true)
	_check(helped.racket_half() > Game.RACKET_HALF * 1.2 and helped.fall_limit() < calm.fall_limit(), "assist widens the racket and slows the fall")
	var shuttle := _drop(helped, helped.hero_x + Game.RACKET_HALF * 1.2)
	_check(float(shuttle.vy) > 0.0, "an assisted racket reaches a little further")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["breeze", "gusty", "twin"]:
		var gold := _play(session, variant_id, false, 0.0, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a quick pair of feet earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "breeze", false, BRONZE_AIM, BRONZE_SKIP, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a sloppy player who lets some drop still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "breeze", false, 0.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "running back and forth without looking earns nothing (score %d)" % masher.score)
	var idle := _play(session, "breeze", false, 0.0, 1.0, false)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "breeze", true, 0.0, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("shuttle updraft scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## The bronze player aims this far off the middle and lets this share of shuttles drop.
const BRONZE_AIM := 0.055
const BRONZE_SKIP := 0.45


## Play a whole round through Session input: run under the shuttle that will
## reach the racket first, aiming `aim` off its middle, and give up on a share
## `skip` of shuttles; `mash` runs back and forth on a timer instead.
func _play(session: Session, variant_id: String, assisted: bool, aim: float, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-103", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 31
	var chosen: Dictionary = {}
	var held := 0
	var tick := 0
	while not session.ended and game.stage == "play":
		var want := 0
		if mash:
			want = 1 if (tick / 40) % 2 == 0 else -1
		else:
			var target := -1.0
			var soonest := INF
			for shuttle: Dictionary in game.shuttles:
				if shuttle.state != "air":
					continue
				if not chosen.has(shuttle.id):
					chosen[shuttle.id] = decide.randf() >= skip
				if not chosen[shuttle.id]:
					continue
				var arrive := _arrival(game, shuttle)
				if arrive < soonest:
					soonest = arrive
					target = float(shuttle.x) + float(shuttle.vx) * arrive + aim
			if target >= 0.0 and absf(target - game.hero_x) > 0.008:
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


## Rough seconds until a shuttle comes down to the racket.
func _arrival(game: Game, shuttle: Dictionary) -> float:
	var y := float(shuttle.y) - Game.RACKET_Y
	var vy := float(shuttle.vy)
	var g := game.gravity()
	var up := maxf(0.0, vy) / g
	var top := y + maxf(0.0, vy) * up * 0.5
	var down := top / maxf(0.05, game.fall_limit() * 0.85)
	return up + maxf(0.0, down)


## Drop a shuttle onto the racket at `x` and return it after it meets the strings.
func _drop(game: Game, x: float) -> Dictionary:
	game._launch(x, Game.RACKET_Y + 0.02, 0.0, -0.4)
	var shuttle: Dictionary = game.shuttles.back()
	_advance(game, 0.08)
	return shuttle


## Highest a shuttle climbs from now on.
func _peak(game: Game, shuttle: Dictionary) -> float:
	var peak := float(shuttle.y)
	for tick in 600:
		game.step(STEP)
		peak = maxf(peak, float(shuttle.y))
		if float(shuttle.vy) < 0.0:
			break
	return peak


## A round in play with nothing served and no wind, so a check can drop shuttles by hand.
func _quiet(variant_id := "breeze", assisted := false) -> Game:
	var game := _playing(variant_id, assisted)
	game._serves.clear()
	game.shuttles.clear()
	game._gust_due = 999.0
	game._twin = true
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
