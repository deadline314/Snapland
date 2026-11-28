extends SceneTree
## 氣壓彈射 rules: pumping raises the pressure, letting go fires, the green zone
## is the pad, short and long misses, the bullseye, streaks, bursting past the
## red, new pads each shot, escalation, variants and full simulated rounds (an
## untouched round scores nothing).

const Game = preload("res://game/minigames/arcade/pump_launch_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_pumping_and_firing()
	_bursting()
	_it_gets_harder()
	_variants()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: pump launch pumping, green zone hits, short and long misses, bullseye, streak, bursts, new pads, narrowing and shivering, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [150, 380, 560], "a round opens with its medal lines declared")
	_hold(game, true)
	_advance(game, Base.READY_SECONDS - 0.05)
	_check(not game.shot.is_empty() and str(game.shot.result) == "hit" and game.score == 0, "the countdown pumps and lands a bundle by itself, paying nothing")
	_hold(game, false)
	_advance(game, 0.1)
	_check(game.stage == "play" and game.phase == "aim" and is_zero_approx(game.pressure) and game.shot.is_empty(), "play starts with an empty pump and a fresh pad")


func _pumping_and_firing() -> void:
	var game := _playing("standard")
	_hold(game, true)
	_advance(game, 0.5)
	_check(game.pumping and game.pressure > 0.25 and game.pressure < 0.4, "holding pumps the pressure up (%.2f)" % game.pressure)
	_hold(game, false)
	_check(game.phase == "fly" and not game.pumping and not game.shot.is_empty(), "letting go fires the bundle")
	var hit := _playing("standard")
	_pump_to(hit, hit.target)
	_check(str(hit.shot.result) == "hit" and bool(hit.shot.bull) and hit.score >= Game.SHOT_POINTS + Game.BULL_POINTS - 1 and hit.streak == 1,
		"letting go right over the pad's middle lands a bullseye (%d)" % hit.score)
	_advance(hit, Game.FLIGHT_SECONDS + Game.LAND_SECONDS + 0.05)
	_check(hit.phase == "aim" and is_zero_approx(hit.pressure), "then the next shot is ready")
	var edge := _playing("standard")
	_pump_to(edge, edge.target + edge.zone() * 0.8)
	_check(str(edge.shot.result) == "hit" and not bool(edge.shot.bull) and edge.score > 0 and edge.score < hit.score,
		"near the green's edge still lands, for less (%d)" % edge.score)
	var short := _playing("standard")
	_pump_to(short, short.target - short.zone() * 1.6)
	var long := _playing("standard")
	_pump_to(long, long.target + long.zone() * 1.6)
	_check(str(short.shot.result) == "short" and str(long.shot.result) == "long" and short.score == 0 and long.score == 0 and short.mistakes == 0,
		"under the green falls short, over it flies long; neither pays")
	var helped := _round("standard", true)
	_check(helped.zone() > _round("standard", false).zone() * 1.4, "assist widens the green zone")
	var places := {}
	var spot := _playing("standard")
	for shot in 8:
		var before := spot.target
		_pump_to(spot, spot.target)
		_advance(spot, Game.FLIGHT_SECONDS + Game.LAND_SECONDS + 0.05)
		_check(absf(spot.target - before) >= 0.1, "each shot gets a pad somewhere new")
		places[snappedf(spot.target, 0.05)] = true
	_check(places.size() >= 4, "and the pads spread out (%d places)" % places.size())


func _bursting() -> void:
	var game := _playing("standard")
	_hold(game, true)
	_advance(game, 2.5)
	_check(game.phase == "burst" and game.bursts == 1 and game.mistakes == 0 and game.fail_at >= 0.0 and game.streak == 0,
		"pumping past the red bursts the pump; the first time is free")
	_hold(game, false)
	_check(game.phase == "burst", "letting go mid-burst fires nothing")
	_advance(game, Game.BURST_SECONDS + 0.05)
	_check(game.phase == "aim" and is_zero_approx(game.pressure), "then a fresh pump is ready")
	_hold(game, true)
	_advance(game, 2.5)
	_check(game.bursts == 2 and game.mistakes == 1, "later bursts are mistakes")
	var idle := _playing("quick")
	_advance(idle, idle.round_seconds + 0.1)
	_check(idle.score == 0 and idle.bursts == 0, "an untouched round scores nothing")


func _it_gets_harder() -> void:
	var early := _playing("standard")
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.9
	_check(late.zone() < early.zone() * 0.65 and late.rise() > early.rise() * 1.4, "later the green narrows and the pump fills faster")
	late.pressure = 0.5
	var spread := 0.0
	for tick in 60:
		late.clock += 0.01
		spread = maxf(spread, absf(late.needle() - 0.5))
	early.pressure = 0.5
	_check(spread > 0.015 and is_equal_approx(early.needle(), 0.5), "and the needle shivers (%.3f)" % spread)


func _variants() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "shaky", "quick"], "three variants are declared")
	var shaky := _playing("shaky")
	shaky.play_time = shaky.round_seconds * 0.1
	shaky.pressure = 0.5
	var moved := false
	for tick in 30:
		shaky.clock += 0.01
		moved = moved or absf(shaky.needle() - 0.5) > 0.005
	var quick := _playing("quick")
	var standard := _playing("standard")
	_check(moved and quick.rise() > standard.rise() * 1.3 and quick.zone() > standard.zone(), "the shaky needle shivers early; the quick pump fills fast with a wider green")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "shaky", "quick"]:
		# Gold: lets go once the needle is in the middle third of the green.
		var gold := _play(session, variant_id, false, 0.25, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady pumper earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: lets go late in the green, and every so often lets go far too early.
	var bronze := _play(session, "standard", false, 0.9, 0.35)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a sloppy pumper still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 0.25, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("pump launch scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: pump, and let go once the needle
## is within `within` green half-widths short of the pad's middle; with `rash`
## chance per shot let go far too early instead.
func _play(session: Session, variant_id: String, assisted: bool, within: float, rash: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-099", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var luck := RandomNumberGenerator.new()
	luck.seed = 7
	var holding := false
	var early := false
	while not session.ended and game.stage == "play":
		if game.phase == "aim":
			if not holding:
				early = luck.randf() < rash
				_session_key(session, true)
				holding = true
			else:
				var aim := game.target - game.zone() * (1.6 if early else within)
				if game.needle() >= aim:
					_session_key(session, false)
					holding = false
		elif holding:
			_session_key(session, false)
			holding = false
		_run_session(session, STEP)
	if holding:
		_session_key(session, false)
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


## Pump until the needle reaches `level`, then let go.
func _pump_to(game: Game, level: float) -> void:
	_hold(game, true)
	for tick in 2000:
		if game.needle() >= level or game.phase != "aim":
			break
		game.step(STEP / 8.0)
	_hold(game, false)


func _session_key(session: Session, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


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


func _hold(game: Base, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
