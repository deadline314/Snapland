extends SceneTree
## 風箏追風 rules: the demo, pulling the line, climbing in the wind and sinking
## out of it, the arrow running ahead of the wind and turbulence lying about it,
## shifts coming quicker, cloud rings and combos, stalls and being dragged up,
## variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/kite_wind_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_follows_the_wind()
	_pulling_climbing_and_sinking()
	_the_arrow_and_turbulence()
	_rings_and_combos()
	_stalls_drag_the_traveller()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: kite wind demo, pulling, climbing in the wind, sinking out of it, the arrow and turbulence, quicker shifts, rings and combos, stalls, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_follows_the_wind() -> void:
	var game := _round("breeze", false)
	_check(game.stage == "ready" and game.thresholds == [180, 380, 500] and is_equal_approx(game.arrow_x, 0.72) and is_equal_approx(game.kite_x, 0.5),
		"a round opens with the arrow pointing at a new wind")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		if tick % 10 == 0:
			_tap(game, KEY_LEFT)
		game.step(STEP)
	_check(game.kite_x > 0.6 and game.in_wind() and game.score == 0 and game.stalls == 0, "the countdown swings the kite over into the wind by itself; the arrows do nothing yet")
	_advance(game, 0.6)
	_check(game.stage == "play" and game.rings.size() >= 1, "then play starts and cloud rings come drifting down")


func _pulling_climbing_and_sinking() -> void:
	var game := _quiet()
	game.wind_x = 0.5
	game.wind_target = 0.5
	game.arrow_x = 0.5
	game.kite_x = 0.5
	game.kite_h = 0.5
	_advance(game, 0.5)
	_check(game.kite_h > 0.7, "in the wind the kite climbs")
	var start := game.kite_x
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.6)
	_check(game.kite_x > start + 0.3 and game.pulling == 1, "holding → pulls the kite over to the right")
	_advance(game, 0.4)
	_press(game, KEY_RIGHT, false)
	var high := game.kite_h
	_advance(game, 0.5)
	_check(not game.in_wind() and game.kite_h < high, "out of the wind it sinks")
	var pad := _quiet()
	pad.kite_x = 0.5
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_LEFT
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.3)
	_check(pad.kite_x < 0.45, "the gamepad d-pad pulls too")


func _the_arrow_and_turbulence() -> void:
	var game := _quiet()
	game.wind_x = 0.5
	game.wind_target = 0.5
	game._shift_to(0.2, false)
	_check(is_equal_approx(game.arrow_x, 0.2) and is_equal_approx(game.wind_x, 0.5), "the arrow swings at once")
	_advance(game, Game.WARN * 0.8)
	_check(is_equal_approx(game.wind_x, 0.5), "and the wind follows a moment later")
	_advance(game, 1.2)
	_check(absf(game.wind_x - 0.2) < 0.03, "until it blows where the arrow points (%.2f)" % game.wind_x)
	game._shift_to(0.8, true)
	_check(game.arrow_x < 0.2 and game.clock < game.fake_until, "turbulence swings the arrow the wrong way first")
	_advance(game, Game.WARN * 0.9)
	_check(game.wind_x < 0.21, "while the wind stays put")
	_advance(game, 2.0)
	_check(is_equal_approx(game.arrow_x, 0.8) and absf(game.wind_x - 0.8) < 0.03 and game.clock >= game.fake_until, "then it turns to where the wind really goes")
	var whole := _playing("breeze")
	whole.kite_h = 1.0
	var early := 0
	var late := 0
	var early_fakes := 0
	var late_fakes := 0
	var last := whole.arrow_at
	while whole.stage == "play":
		whole.kite_h = 1.0
		whole.step(STEP)
		if whole.arrow_at != last:
			last = whole.arrow_at
			var fake := whole.clock < whole.fake_until
			if whole.heat() < 0.5:
				early += 1
				early_fakes += int(fake and whole.heat() < Game.FAKE_HEAT)
			else:
				late += 1
				late_fakes += int(fake)
	_check(late > early, "the wind shifts more often later (%d then %d)" % [early, late])
	_check(early_fakes == 0 and late_fakes > 0, "turbulence only lies later on (%d late)" % late_fakes)


func _rings_and_combos() -> void:
	var game := _quiet()
	game.kite_h = 1.0
	game.wind_x = game.kite_x
	for ring in 4:
		game._spawn_ring()
		game.rings.back().x = game.kite_x
		game.rings.back().y = game.kite_y() - 0.02
		_advance(game, 0.1)
	_check(game.caught == 4 and game.combo == 4 and game.score == Game.RING_POINTS * 4 + 4, "flying through cloud rings scores, and a run of them adds a little (%d)" % game.score)
	game._spawn_ring()
	game.rings.back().x = fposmod(game.kite_x + 0.4, 1.0)
	game.rings.back().y = game.kite_y() - 0.02
	_advance(game, 0.1)
	_check(game.missed == 1 and game.combo == 0, "a ring that goes by breaks the run")
	var still := _playing("breeze")
	still._shift_due = 999.0
	still._ring_due = 999.0
	still.kite_h = 1.0
	still._spawn_ring()
	still.rings.back().x = still.kite_x
	still.rings.back().y = still.kite_y() - 0.02
	_advance(still, 0.1)
	_check(still.score == 0 and still.caught == 0 and not still.touched, "a kite nobody has steered drifts through a ring for nothing")


func _stalls_drag_the_traveller() -> void:
	var game := _quiet()
	game.wind_x = 0.9
	game.kite_x = 0.2
	game.kite_h = 0.2
	_advance(game, 0.8)
	_check(game.stalls == 1 and game.dragging() and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a kite that sinks to the deck stalls and drags the traveller off; the first time is a free look")
	var held := game.kite_x
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.5)
	_press(game, KEY_RIGHT, false)
	_check(absf(game.kite_x - held) < 0.02, "no pulling while being dragged")
	_advance(game, Game.DRAG_SECONDS)
	_check(not game.dragging() and game.kite_h > 0.2, "then the kite is back up in the air")
	game.kite_h = 0.05
	_advance(game, 0.4)
	_check(game.stalls == 2 and game.mistakes == 1, "a second stall counts as a mistake")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["breeze", "gusty", "rings"], "three variants are declared")
	var gusty := _playing("gusty")
	var fooled := false
	while gusty.stage == "play" and gusty.heat() < Game.FAKE_HEAT:
		gusty.kite_h = 1.0
		gusty.step(STEP)
		fooled = fooled or gusty.clock < gusty.fake_until
	_check(fooled, "on a turbulent day the arrow lies from the start")
	var counts: Array[int] = []
	for variant_id: String in ["breeze", "rings"]:
		var game := _playing(variant_id)
		var seen: Dictionary = {}
		while game.stage == "play" and game.play_time < 20.0:
			game.kite_h = 1.0
			game.step(STEP)
			for ring: Dictionary in game.rings:
				seen[ring.id] = true
		counts.append(seen.size())
	_check(counts[1] > counts[0], "the ring festival sends more rings (%s)" % [counts])
	var helped := _quiet(true)
	var plain := _quiet()
	_check(helped.window_half() > plain.window_half() * 1.2, "assist widens the wind")
	for each: Game in [helped, plain]:
		each.wind_x = 0.9
		each.kite_x = 0.2
		each.kite_h = 0.8
		_advance(each, 0.5)
	_check(helped.kite_h > plain.kite_h, "and slows the sinking")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["breeze", "gusty", "rings"]:
		var gold := _play(session, variant_id, false, false, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp flier earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "breeze", false, true, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a flier who just follows the arrow still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "breeze", false, false, true)
	_check(not masher.success and masher.score < lines[0], "yanking back and forth earns nothing (score %d)" % masher.score)
	var idle := _play(session, "breeze", false, false, false, true)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "breeze", true, false, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("kite wind scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input. The sharp flier keeps the kite in
## the wind and dips over for each ring it can reach; `loose` only follows the
## arrow (turbulence fools it) and never chases rings; `mash` swings the line
## back and forth on a timer; `idle` touches nothing.
func _play(session: Session, variant_id: String, assisted: bool, loose: bool, mash: bool, idle := false) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-105", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var held := 0
	var tick := 0
	while not session.ended and game.stage == "play":
		var want := 0
		if mash:
			want = 1 if (tick / 50) % 2 == 0 else -1
		elif not idle:
			var target := game.arrow_x if loose else game.wind_x
			if not loose:
				var best := INF
				for ring: Dictionary in game.rings:
					var above := game.kite_y() - float(ring.y)
					if ring.state == "drift" and above > 0.0 and above < best and absf(float(ring.x) - game.wind_x) < 0.3:
						best = above
						target = float(ring.x)
			if absf(target - game.kite_x) > 0.015:
				want = 1 if target > game.kite_x else -1
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


## A round in play with no wind shifts and no rings, so a check can set things up by hand.
func _quiet(assisted := false) -> Game:
	var game := _playing("breeze", assisted)
	game._shift_due = 999.0
	game._ring_due = 999.0
	game.rings.clear()
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
