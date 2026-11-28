extends SceneTree
## 觀眾席波浪 rules: laps, catching the wave, perfect timing and streaks,
## missing it, feints, standing alone, escalation, variants and full simulated
## rounds (an untouched round scores nothing).

const Game = preload("res://game/minigames/arcade/crowd_wave_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_catching_the_wave()
	_missing_and_standing_alone()
	_feints_and_escalation()
	_variants_change_the_laps()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: crowd wave laps, catches, perfect, streak, misses, feints, standing alone, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [90, 250, 400], "a round opens with its medal lines declared")
	_tap(game)
	_advance(game, 1.2)
	_check(game.stood_at > 0.0 and game.score == 0 and game.alones == 0, "the countdown sends a wave past and the hero stands with it; presses do nothing yet")
	_advance(game, Base.READY_SECONDS)
	_check(game.stage == "play" and game.score == 0, "play starts with nothing scored")


func _catching_the_wave() -> void:
	var game := _lap_near("standard", 0.0)
	_tap(game)
	_check(game.catches == 1 and game.streak == 1 and game.score == Game.POINTS + Game.PERFECT_BONUS, "standing as the crest reaches the seat is a perfect catch (%d)" % game.score)
	var late := _lap_near("standard", 0.12)
	_tap(late)
	_check(late.catches == 1 and late.score == Game.POINTS, "a little late still catches it, without the bonus (%d)" % late.score)
	var streaky := _lap_near("standard", 0.0)
	streaky.streak = 3
	_tap(streaky)
	_check(streaky.score == Game.POINTS + Game.PERFECT_BONUS + 3 * Game.STREAK_BONUS and streaky.streak == 4, "laps in a row add a streak bonus")
	_tap(streaky)
	_check(streaky.alones == 0, "pressing again while still standing does nothing")


func _missing_and_standing_alone() -> void:
	var game := _lap_near("standard", -0.5)
	_advance(game, 0.8)
	_check(game.misses == 1 and game.mistakes == 1 and game.streak == 0 and bool(game.crests[0].broken), "letting the wave pass breaks it at the hero's seat")
	var lonely := _playing("standard")
	_advance(lonely, 0.1)
	_tap(lonely)
	_check(lonely.phase == "alone" and lonely.alones == 1 and lonely.mistakes == 0 and lonely.fail_at >= 0.0, "standing with no wave near: alone, and the first time is free")
	_advance(lonely, Game.STAND_SECONDS + 0.1)
	_tap(lonely)
	_check(lonely.alones == 1, "nothing more happens while the tent stares")
	_advance(lonely, Game.ALONE_SECONDS)
	_check(lonely.phase == "gap" or lonely.phase == "lap", "then the waves start again")
	var early := _lap_near("standard", -0.6)
	early.alones = 1
	_tap(early)
	_check(early.alones == 2 and early.mistakes == 1, "standing too early is standing alone, and later ones are mistakes")
	var idle := _playing("standard")
	_advance(idle, idle.round_seconds + 0.1)
	_check(idle.score == 0 and idle.misses > 3, "an untouched round scores nothing (%d misses)" % idle.misses)
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.window(Game.WINDOW) > Game.WINDOW * 1.4, "assist widens the window")


func _feints_and_escalation() -> void:
	var game := _playing("standard")
	var feints_early := 0
	var feints_late := 0
	var speeds_early: Array[float] = []
	var speeds_late: Array[float] = []
	var seen_lap := 0
	var seen_feint := -1.0
	while game.stage == "play":
		game.step(STEP)
		if game.laps != seen_lap:
			seen_lap = game.laps
			if game.heat() < 0.3:
				speeds_early.append(game.base_speed)
			elif game.heat() > 0.7:
				speeds_late.append(game.base_speed)
		if not game.feint.is_empty() and float(game.feint.at) != seen_feint:
			seen_feint = float(game.feint.at)
			if game.heat() < 0.4:
				feints_early += 1
			else:
				feints_late += 1
			_check(game._nearest_gap() > 0.0, "a feint comes before the wave reaches the hero")
	var mean := func(values: Array[float]) -> float:
		var total := 0.0
		for value in values:
			total += value
		return total / maxf(1.0, values.size())
	_check(mean.call(speeds_late) > mean.call(speeds_early) * 1.5, "laps get faster (%.0f vs %.0f px/s)" % [mean.call(speeds_early), mean.call(speeds_late)])
	var spread := 0.0
	for value in speeds_early:
		spread = maxf(spread, absf(value - mean.call(speeds_early)))
	_check(spread > 40.0, "lap speeds jump around (%.0f px/s)" % spread)
	_check(feints_late > feints_early, "feints turn up more and more (%d vs %d)" % [feints_early, feints_late])


func _variants_change_the_laps() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "double", "reverse"], "three variants are declared")
	var tally := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var doubles := 0
		var reversed := 0
		var seen := 0
		while game.stage == "play":
			game.step(STEP)
			if game.laps != seen:
				seen = game.laps
				doubles += int(game.crests.size() == 2)
				reversed += int(game.direction < 0.0)
		tally[variant_id] = [doubles, reversed]
	_check(tally.double[0] >= 3 and tally.standard[0] == 0, "the double wave sends two crests in many laps (%s)" % tally)
	_check(tally.reverse[1] >= 3 and tally.standard[1] == 0, "the reverse wave sometimes comes the other way (%s)" % tally)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "double", "reverse"]:
		# Gold: stands within 0.03 s of the crest and ignores every feint.
		var gold := _play(session, variant_id, false, 0.03, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp fan earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: stands 0.12 s late and falls for every feint.
	var bronze := _play(session, "standard", false, 0.12, true)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a jumpy, late fan still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 0.03, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("crowd wave scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: stand `late` seconds after the
## crest reaches the seat; a `fooled` fan also stands for every feint.
func _play(session: Session, variant_id: String, assisted: bool, late: float, fooled: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-058", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var answered := {}
	var feinted := -1.0
	while not session.ended and game.stage == "play":
		if fooled and not game.feint.is_empty() and float(game.feint.at) != feinted:
			feinted = float(game.feint.at)
			_session_tap(session)
		for crest: Dictionary in game.crests:
			var key := "%d|%d" % [game.laps, game.crests.find(crest)]
			if answered.has(key) or bool(crest.hit) or bool(crest.broken):
				continue
			var past := (float(crest.x) - Game.HERO_X) * game.direction
			if past >= game.speed * late:
				answered[key] = true
				_session_tap(session)
		_run_session(session, STEP)
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


func _session_tap(session: Session) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


## A round with a lap running and its crest `offset` seconds past the seat.
func _lap_near(variant_id: String, offset: float) -> Game:
	var game := _playing(variant_id)
	game._start_lap()
	game.direction = 1.0
	game.base_speed = 600.0
	game.speed = 600.0
	game.crests = [{"x": Game.HERO_X + offset * 600.0, "hit": false, "broken": false}]
	game._feint_due = false
	game.stood_at = -99.0
	return game


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
	return game


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


func _tap(game: Base) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
