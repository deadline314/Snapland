extends SceneTree
## 花粉拓印 rules: the countdown demo, stamping by key and gamepad, scoring by
## how close to the frame's centre the print lands, streaks, the miss and the
## forehead print, the paper sliding on, escalation (smaller frames, quicker
## swing, drifting paper), variants, assist, no points without input and full
## simulated rounds.

const Game = preload("res://game/minigames/arcade/pollen_print_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const ROUND_STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_print()
	_untouched_rounds_never_score()
	_stamping()
	_scoring_by_distance()
	_the_miss()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: pollen print demo, stamping, scoring by distance and streaks, forehead miss, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_print() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [70, 200, 320] and not game.frame.is_empty(), "a round opens with a frame under the stamp")
	var results: Array = []
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		if not game.press.is_empty() and str(game.press.result) != "" and not results.has(game.press.result):
			results.append(game.press.result)
	_check(results == ["centre"] and game.score == 0 and game.forehead == 0, "the countdown stamps a centred flower by itself and scores nothing: %s" % [results])
	while game.stage == "ready":
		game.step(STEP)
	_check(game.stage == "play" and game.press.is_empty() and absf(game.stamp_x() - game.frame.x) > 150.0, "play starts with the stamp swung well away from the fresh frame")


func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		for round_seed in 40:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 30.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 80 seeded rounds: %s" % [scored])


func _stamping() -> void:
	var game := _settled("standard")
	var before := game.stamp_x()
	_tap(game, KEY_SPACE)
	_advance(game, 0.1)
	_check(not game.press.is_empty() and absf(float(game.press.x) - before) < 1.0 and absf(game.stamp_x() - before) < 1.0,
		"pressing drops the stamp where it is and holds it still")
	_tap(game, KEY_SPACE)
	_check(game.prints <= 1, "pressing again while it is down does nothing")
	_advance(game, Game.DROP_SECONDS + Game.LIFT_SECONDS)
	_check(game.press.is_empty() and game.sheets == 1 and not game.leaving.is_empty(), "the stamp lifts and the paper rolls on to a fresh frame")
	var pad := _settled("standard")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(not pad.press.is_empty(), "the gamepad A button stamps too")


func _scoring_by_distance() -> void:
	var outcomes: Array = []
	for off: float in [0.0, 0.4, 0.95]:
		var game := _settled("standard")
		game.frame.x = game.stamp_x() + off * float(game.frame.w) * 0.5
		game.frame.centre = game.frame.x
		_tap(game, KEY_SPACE)
		_advance(game, Game.DROP_SECONDS + 0.02)
		outcomes.append([game.press.result, game.score])
	_check(outcomes[0] == ["centre", Game.CENTRE_POINTS] and outcomes[1][0] == "inside" and outcomes[2][0] == "inside"
		and int(outcomes[1][1]) > int(outcomes[2][1]) and int(outcomes[2][1]) >= Game.INSIDE_LOW, "closer to the centre scores more: %s" % [outcomes])
	var streak := _settled("standard")
	for print in 3:
		while not streak.ready_to_drop():
			streak.step(STEP)
		streak.frame.x = streak.stamp_x()
		streak.frame.centre = streak.frame.x
		_tap(streak, KEY_SPACE)
		_advance(streak, Game.DROP_SECONDS + 0.02)
	_check(streak.streak == 3 and streak.score == Game.CENTRE_POINTS * 3 + Game.STREAK_POINTS * 3, "centred prints in a row build a streak")


func _the_miss() -> void:
	var game := _settled("standard")
	game.frame.x = game.stamp_x() + float(game.frame.w)
	game.frame.centre = game.frame.x
	_tap(game, KEY_SPACE)
	_advance(game, Game.DROP_SECONDS + 0.02)
	_check(game.press.result == "miss" and game.forehead == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.busy() and game.score == 0,
		"missing the frame thumps the stamp on the forehead; the first miss is a free look")
	_tap(game, KEY_SPACE)
	_check(game.prints == 1, "no stamping while the traveller is seeing stars")
	_advance(game, Game.BONK_SECONDS)
	while not game.ready_to_drop():
		game.step(STEP)
	game.frame.x = game.stamp_x() + float(game.frame.w)
	_tap(game, KEY_SPACE)
	_advance(game, Game.DROP_SECONDS + 0.02)
	_check(game.forehead == 2 and game.mistakes == 1, "a second miss counts as a mistake and adds another flower")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early_speed := game.speed()
	var early_width := game.frame_width()
	game.play_time = game.round_seconds * 0.95
	_check(game.speed() > early_speed * 1.5 and game.frame_width() < early_width * 0.6, "the swing quickens and the frames shrink")
	var still := _settled("standard")
	var x := float(still.frame.x)
	_advance(still, 1.0)
	var drifting := _settled("standard")
	drifting.play_time = drifting.round_seconds * 0.6
	var start := float(drifting.frame.x)
	var moved := 0.0
	for tick in 120:
		drifting.step(STEP)
		moved = maxf(moved, absf(float(drifting.frame.x) - start))
	_check(float(still.frame.x) == x and moved > 20.0, "the paper starts drifting later on")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "quick", "drift"], "three variants are declared")
	var quick := _playing("quick")
	var plain := _playing("standard")
	_check(quick.speed() > plain.speed() * 1.2, "the quick stamp swings faster")
	var drift := _settled("drift")
	var start := float(drift.frame.x)
	var wander := 0.0
	for tick in 360:
		drift.step(STEP)
		wander = maxf(wander, absf(float(drift.frame.x) - start))
	_check(wander > 20.0, "on a drifting day the paper moves from the start")
	var helped := _playing("standard", true)
	_check(helped.centre_band() > plain.centre_band() * 1.2 and helped.speed() < plain.speed() * 0.8, "assist widens the centre and slows the swing")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_means: Array[int] = []
	for variant_id: String in ["standard", "quick", "drift"]:
		var rounds := _rounds(session, variant_id, false, 0.02)
		lines = rounds[0].score_summary.thresholds
		var best: Dictionary = rounds.reduce(func(a: Dictionary, b: Dictionary) -> Dictionary: return a if a.score >= b.score else b)
		gold_means.append(_mean(rounds))
		_check(_mean(rounds) >= lines[2] and best.success and best.devil and best.ordinary_eligible and best.score_summary.medal == 3
			and best.score_summary.rows.size() == 1, "a sharp stamper earns gold in the %s variant (scores %s)" % [variant_id, _scores(rounds)])
	var late := _rounds(session, "standard", false, 0.09)
	var bronze_rounds := late.filter(func(r: Dictionary) -> bool: return r.score_summary.medal == 1 and r.success and not r.devil)
	_check(_mean(late) >= lines[0] and _mean(late) < lines[1] and not bronze_rounds.is_empty(),
		"a stamper who presses a little late still earns bronze (scores %s)" % _scores(late))
	var idle := _play(session, "standard", 0, false, -1.0)
	_check(not idle.success and idle.score == 0, "never stamping earns nothing (score %d)" % idle.score)
	var helped := _rounds(session, "standard", true, 0.02)
	_check(_mean(helped) >= lines[2] and helped.all(func(r: Dictionary) -> bool: return r.assisted and not r.devil)
		and helped.any(func(r: Dictionary) -> bool: return r.success and r.score_summary.medal == 3),
		"assisted gold rounds never award the devil sticker (scores %s)" % _scores(helped))
	print("pollen print scores: gold means %s, bronze %s, idle %d, assisted %s" % [gold_means, _scores(late), idle.score, _scores(helped)])
	session.free()


func _rounds(session: Session, variant_id: String, assisted: bool, lag: float) -> Array[Dictionary]:
	var played: Array[Dictionary] = []
	for nth in 4:
		played.append(_play(session, variant_id, nth, assisted, lag))
	return played


func _mean(rounds: Array[Dictionary]) -> int:
	var total := 0
	for result in rounds:
		total += int(result.score)
	return total / rounds.size()


func _scores(rounds: Array[Dictionary]) -> String:
	return str(rounds.map(func(r: Dictionary) -> int: return r.score))


## Play a whole round through Session key presses: press `lag` seconds after
## seeing the stamp cross the frame's centre (a negative `lag` never presses).
func _play(session: Session, variant_id: String, nth: int, assisted: bool, lag: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-083", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id, nth)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(ROUND_STEP)
	var due := -1.0
	var before := game.stamp_x() - float(game.frame.x)
	while not session.ended and game.stage == "play":
		var now := game.stamp_x() - float(game.frame.x)
		if lag >= 0.0 and due < 0.0 and game.ready_to_drop() and before * now <= 0.0:
			due = game.clock + lag
		if due >= 0.0 and game.clock >= due:
			due = -1.0
			_session_key(session, KEY_SPACE, true)
			_session_key(session, KEY_SPACE, false)
		before = now
		session._process(ROUND_STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(ROUND_STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


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
	game.touched = true
	return game


## In play with the fresh frame settled and the stamp free to drop.
func _settled(variant_id: String) -> Game:
	var game := _playing(variant_id)
	while not game.ready_to_drop():
		game.step(STEP)
	return game


func _seed_for(variant_id: String, nth := 0) -> int:
	var found := 0
	for round_seed in 400:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		if game.variant.id == variant_id:
			if found == nth:
				return round_seed
			found += 1
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
