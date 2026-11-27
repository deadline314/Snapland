extends SceneTree
## 藤蔓編路 rules: the countdown demo, steering, threading gaps and scoring,
## breathing gaps, butterflies, skylights, the tangle, escalation, variants,
## assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/vine_weave_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_gap()
	_steering_and_threading()
	_hitting_a_bar_ties_a_bow()
	_butterflies_and_skylights()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: vine weave demo, steering, gaps, breathing gaps, butterflies, skylights, tangles, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_gap() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [240, 600, 950] and game.bars.size() >= 6, "a round opens with the trellis planned above the vine")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_LEFT)
		game.step(STEP)
	_check(game.tip_y > 1.0 and game.tangle.is_empty() and game.score == 0, "the countdown grows the vine through the first gap by itself and scores nothing")
	_advance(game, 0.1)
	var first: Dictionary = game.bars[0]
	_check(game.stage == "play" and game.tip_y < 0.2 and absf(game.tip_x - float(first.x)) < 0.02 and float(first.height) == 1.0,
		"play starts at the bottom lined up under the first gap, a full bar below it")


func _steering_and_threading() -> void:
	var game := _playing("standard")
	var x := game.tip_x
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_press(game, KEY_RIGHT, false)
	_check(game.tip_x > x + 0.08, "holding → steers the tip right")
	x = game.tip_x
	_press(game, KEY_A, true)
	_advance(game, 0.3)
	_press(game, KEY_A, false)
	_check(game.tip_x < x - 0.08, "A steers it left")
	var straight := _playing("standard")
	var bar: Dictionary = straight.bars[0]
	_advance(straight, 1.0 / straight.growth() + 0.05)
	_check(straight.passed == 1 and straight.score >= Game.PASS_POINTS + Game.CENTRE_POINTS and straight.tangle.is_empty() and straight.tip_y > float(bar.height),
		"growing straight up through the middle of a gap threads it for points and a centre bonus")
	var pad := _playing("standard")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	pad.handle_input(stick, Vector2.ZERO)
	_advance(pad, 0.3)
	var dpad := _playing("standard")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	dpad.handle_input(right, Vector2.ZERO)
	_advance(dpad, 0.3)
	_check(pad.tip_x < Game.LEFT_EDGE + 0.9 and pad.drift < -0.3 and dpad.drift > 0.3, "the gamepad stick and D-pad steer too")


func _hitting_a_bar_ties_a_bow() -> void:
	var game := _playing("standard")
	var bar: Dictionary = game.bars[0]
	bar.x = 0.8
	game.tip_x = 0.2
	_advance(game, 1.0 / game.growth() + 0.05)
	_check(game.crashes == 1 and game.mistakes == 0 and game.fail_at > 0.0 and not game.tangle.is_empty() and not game.snapshot().word_good,
		"growing into the bar ties a bow; the first time is a free look")
	_check(game.busy() and game.tip_y < float(bar.height) - 0.5 and is_equal_approx(game.tip_x, 0.2), "the vine restarts a little below that bar, where it hit")
	var height := game.tip_y
	_advance(game, 0.5)
	_check(is_equal_approx(game.tip_y, height), "nothing grows while the traveller is tied up")
	_advance(game, Game.TANGLE_SECONDS)
	_check(game.tip_y > height, "then it grows again")
	var again := _playing("standard")
	for crash in 2:
		var next: Dictionary = again._bar_after(again.tip_y)
		next.x = 0.8 if again.tip_x < 0.5 else 0.2
		next.breathe = false
		_advance(again, (float(next.height) - again.tip_y) / again.growth() + 0.05)
		_advance(again, Game.TANGLE_SECONDS)
	_check(again.crashes == 2 and again.mistakes == 1, "a second tangle counts as a mistake")


func _butterflies_and_skylights() -> void:
	var game := _playing("standard")
	var bar: Dictionary = game.bars[0]
	bar.butterflies = [game.tip_x]
	var score := game.score
	_advance(game, 0.5 / game.growth() + 0.05)
	_check(game.bumps == 1 and game.busy() and bar.butterflies.is_empty() and game.mistakes == 0 and game.score == score,
		"brushing a resting butterfly stalls the vine while it flutters off, without a mistake")
	var sky := _playing("standard")
	for height in range(sky.bars.size() + 1, 12):
		sky._plan_bar(height)
	for skip in 7:
		sky.bars.pop_front()
	sky.tip_y = float(sky.bars[0].height) - 0.2
	sky.tip_x = sky.gap_x(sky.bars[0])
	var before := sky.score
	_advance(sky, 0.2 / sky.growth() + 0.05)
	_check(sky.skylights == 1 and sky.score - before >= Game.SKYLIGHT_POINTS + Game.PASS_POINTS and not sky.skylight.is_empty(),
		"every eighth bar is a skylight worth a bonus")
	var plan := _playing("standard")
	plan.play_time = plan.round_seconds * 0.8
	var reachable := true
	var with_butterflies := 0
	for height in range(10, 200):
		plan._plan_bar(height)
		var newest: Dictionary = plan.bars.back()
		var previous: Dictionary = plan.bars[plan.bars.size() - 2]
		var shift := absf(float(newest.x) - float(previous.x))
		reachable = reachable and shift <= maxf(Game.MIN_SHIFT, Game.STEER * 0.7 / plan.growth()) + 0.001 and (shift >= Game.MIN_SHIFT - 0.001 or float(newest.x) in [0.2, 0.8])
		with_butterflies += 1 if not newest.butterflies.is_empty() else 0
		for butterfly: float in newest.butterflies:
			reachable = reachable and absf(butterfly - (float(newest.x) + float(previous.x)) * 0.5) >= 0.079
	_check(reachable and with_butterflies > 20, "late gaps stay within steering reach but never straight above the last, and butterflies rest beside the straight line")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.growth()
	game.play_time = game.round_seconds * 0.95
	_check(game.growth() > early * 1.7, "the vine grows much faster by the end")
	var plain := true
	var early_plan := _playing("standard")
	for height in range(10, 60):
		early_plan._plan_bar(height)
		plain = plain and not early_plan.bars.back().breathe and early_plan.bars.back().butterflies.is_empty()
	game._plan_bar(300)
	_check(plain and float(game.bars.back().width) < Game.GAP_FIRST * 0.75, "early gaps are wide and still; late ones are narrow")
	var breathing := false
	for height in range(301, 340):
		game._plan_bar(height)
		breathing = breathing or game.bars.back().breathe
	var bar: Dictionary = game.bars.back()
	bar.breathe = true
	var widths: Array[float] = []
	for sample in 20:
		game.step(0.1)
		widths.append(game.gap_width(bar))
	_check(breathing and widths.max() > widths.min() * 1.6, "later some gaps open and shut")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "sway", "butterflies"], "three variants are declared")
	var sway := _playing("sway")
	var bar: Dictionary = sway.bars[2]
	var spots: Array[float] = []
	for sample in 20:
		sway.clock += 0.15
		spots.append(sway.gap_x(bar))
	_check(spots.max() - spots.min() > 0.1, "in the swaying trellis the gaps slide sideways")
	var flock := _playing("butterflies")
	flock.play_time = flock.round_seconds * 0.8
	var count := 0
	for height in range(10, 110):
		flock._plan_bar(height)
		count += flock.bars.back().butterflies.size()
	_check(count > 50, "butterfly season brings more butterflies")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.growth() < standard.growth() * 0.8 and helped.gap_width(helped.bars[0]) > standard.gap_width(standard.bars[0]) * 1.3, "assist grows the vine slower and widens the gaps")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "sway", "butterflies"]:
		var gold := _play(session, variant_id, false, 0.1, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady gardener earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.5, 0.1)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow, wobbly gardener still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0, 0.0)
	_check(not idle.success and idle.score < lines[0], "leaving the vine alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.1, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("vine weave scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses: every `react` seconds the
## gardener aims the tip at the next gap (missing by up to `wobble`) and holds
## the arrow toward it; a negative `react` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, react: float, wobble: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-075", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 7
	var held := 0
	var next_think := 0.0
	var miss := 0.0
	var target_height := -1.0
	while not session.ended and game.stage == "play":
		if react >= 0.0 and game.clock >= next_think:
			next_think = game.clock + react
			var bar: Dictionary = game._bar_after(game.tip_y)
			var want := 0
			if not bar.is_empty():
				if float(bar.height) != target_height:
					target_height = float(bar.height)
					miss = aim.randf_range(-wobble, wobble)
				var target := game.gap_x(bar) + miss
				# Ease off as the tip lines up, so it does not overshoot.
				var error := target - game.tip_x - game.drift * 0.12
				want = 1 if error > 0.015 else (-1 if error < -0.015 else 0)
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
