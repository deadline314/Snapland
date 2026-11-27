extends SceneTree
## 木偶牽線 rules: the demo dance, beads and their strings, perfect and good
## pulls, combos, misses and wild pulls tying knots, the tangle, the tempo
## sections, two-string beats, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/puppet_strings_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
## Keys for the head, left hand, right hand and feet strings.
const KEYS: Array[int] = [KEY_UP, KEY_LEFT, KEY_RIGHT, KEY_DOWN]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_dances_by_itself()
	_pulling_strings()
	_knots_and_the_tangle()
	_the_tune_speeds_up()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: puppet strings beads, perfect and good pulls, combos, misses, wild pulls, knots, tangle, tempo sections, doubles, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_dances_by_itself() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [350, 900, 1400] and game.beads.size() == 2, "a round opens with two beads on their way")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_UP)
		game.step(STEP)
	_check(game.pulled_at[1] > 1.0 and game.pulled_at[2] > 1.0 and game.pulled_at[0] < 0.0 and game.score == 0 and game.strays == 0 and game.knots == 0.0, "the countdown pulls two strings by itself; keys do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.beads.all(func(bead: Dictionary) -> bool: return bead.state == "coming") and game.knots == 0.0 and game.score == 0,
		"play starts from a clean set of strings with the first beads on their way")


func _pulling_strings() -> void:
	var game := _quiet()
	for string in 4:
		game._bead(string, game.clock + 0.5)
	_advance(game, 0.5)
	for string in 4:
		_tap(game, KEYS[string])
	_check(game.perfects == 4 and game.combo == 4 and game.score == Game.PERFECT_POINTS * 4 + 1, "each arrow pulls its own string; on the beat is perfect and four in a row start a combo")
	_check(game.pulled_at.all(func(at: float) -> bool: return is_equal_approx(at, game.clock)), "every pulled limb jerks up")
	game._bead(1, game.clock + 0.3)
	_advance(game, 0.3 - 0.12)
	var before := game.score
	_tap(game, KEY_A)
	_check(game.hits == 5 and game.perfects == 4 and game.score - before == Game.GOOD_POINTS + 1, "a little early is still good (WASD works like the arrows)")
	game._bead(2, game.clock + 0.3)
	game._bead(3, game.clock + 0.3)
	_advance(game, 0.3)
	_tap(game, KEY_RIGHT)
	_tap(game, KEY_DOWN)
	_check(game.hits == 7, "a two-string beat needs both strings")
	var pad := _quiet()
	pad._bead(0, pad.clock + 0.2)
	_advance(pad, 0.2)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_UP
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.hits == 1, "the gamepad d-pad pulls strings too")


func _knots_and_the_tangle() -> void:
	var game := _quiet()
	game.score = 30
	_tap(game, KEY_LEFT)
	_check(game.strays == 1 and is_equal_approx(game.knots, 1.0) and game.score == 30 - Game.STRAY_POINTS and game.combo == 0, "a wild pull with no bead near costs points and ties a knot")
	game._bead(2, game.clock + 0.1)
	_advance(game, 0.1 + Game.GOOD + 0.02)
	_check(game.misses == 1 and is_equal_approx(game.knots, 2.0), "a bead that slides past unpulled ties another")
	game._bead(0, game.clock + 0.1)
	_advance(game, 0.1)
	_tap(game, KEY_UP)
	_check(is_equal_approx(game.knots, 1.5), "a clean pull loosens half a knot")
	for knot in 3:
		_tap(game, KEY_RIGHT)
	_check(game.tangled() and game.tangles == 1 and game.knots == 0.0 and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"enough knots snarl every string and flip the puppet; the first time is a free look")
	game._bead(1, game.clock + 0.5)
	_advance(game, 0.5)
	_tap(game, KEY_LEFT)
	_check(game.hits == 1 and game.beads.all(func(bead: Dictionary) -> bool: return bead.state != "hit" or bead.string != 1), "nothing can be pulled while the strings are snarled")
	_advance(game, Game.TANGLE_SECONDS)
	_check(not game.tangled(), "then the strings come loose")
	for knot in 4:
		_tap(game, KEY_RIGHT)
	_check(game.tangles == 2 and game.mistakes == 1, "a second tangle counts as a mistake")


func _the_tune_speeds_up() -> void:
	var game := _playing("standard")
	var early := 0
	var late := 0
	var first_double := -1.0
	var seen: Dictionary = {}
	while game.stage == "play":
		game.step(STEP)
		var beats: Dictionary = {}
		for bead: Dictionary in game.beads:
			if not seen.has(bead.id):
				seen[bead.id] = true
				var at := float(bead.t) - game.clock + game.play_time
				if at < game.round_seconds * 0.3:
					early += 1
				elif at > game.round_seconds * 0.7:
					late += 1
			var key := "%.3f" % float(bead.t)
			beats[key] = int(beats.get(key, 0)) + 1
			if beats[key] >= 2 and first_double < 0.0:
				first_double = (float(bead.t) - game.clock + game.play_time) / game.round_seconds
	_check(game.tempo_at(game.round_seconds - 1.0) > game.tempo_at(0.0) * 1.4 and game.section() == Game.TEMPOS.size() - 1, "the tune gets faster section by section")
	_check(late > early * 1.4, "beads come thicker later (%d to %d)" % [early, late])
	_check(first_double >= Game.DOUBLE_HEAT - 0.05, "two-string beats only join later (%.2f)" % first_double)


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "jig", "duet"], "three variants are declared")
	var standard := _playing("standard")
	var jig := _playing("jig")
	_check(jig.tempo_at(0.0) > standard.tempo_at(0.0) * 1.1, "the jig is faster")
	var duet := _playing("duet")
	_advance(duet, 10.0)
	_check(duet.doubles > 0, "the duet has two-string beats from the start")
	var helped := _quiet(true)
	helped._bead(1, helped.clock + 0.3)
	_advance(helped, 0.3 - Game.GOOD * 1.3)
	_tap(helped, KEY_LEFT)
	_check(helped.hits == 1, "assist widens the timing")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "jig", "duet"]:
		var gold := _play(session, variant_id, false, 0.01, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a dancer on every beat earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.11, 0.25, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a loose dancer who misses a quarter of the beads still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "standard", false, 0.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "pulling every string at random earns nothing (score %d)" % masher.score)
	var idle := _play(session, "standard", false, 0.0, 1.0, false)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.01, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("puppet strings scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: pull each bead's string `off`
## seconds early, skipping a share `skip`; `mash` pulls strings at random.
func _play(session: Session, variant_id: String, assisted: bool, off: float, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-067", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 13
	var planned: Dictionary = {}
	var tick := 0
	while not session.ended and game.stage == "play":
		var presses: Array[int] = []
		if mash:
			if tick % 12 == 0:
				presses.append(decide.randi() % 4)
		else:
			for bead: Dictionary in game.beads:
				if bead.state != "coming":
					continue
				if not planned.has(bead.id):
					planned[bead.id] = decide.randf() >= skip
				if planned[bead.id] and game.clock >= float(bead.t) - off and not presses.has(int(bead.string)):
					presses.append(int(bead.string))
					planned[bead.id] = false
		for string in presses:
			_session_key(session, KEYS[string], true)
		if not presses.is_empty():
			session._process(STEP)
		for string in presses:
			_session_key(session, KEYS[string], false)
		session._process(STEP)
		tick += 1
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


## A round in play with no beads of its own, so a check can send them by hand.
func _quiet(assisted := false) -> Game:
	var game := _playing("standard", assisted)
	game._next_beat = 999.0
	game.beads.clear()
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
