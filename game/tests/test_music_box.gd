extends SceneTree
## 音盒補拍 rules: the demo phrase, pins playing themselves, plucking empty
## sockets on time, combos, misses and wild presses building pressure, the
## lid popping, the speed-up, rows of empty sockets, variants, assist and full
## simulated rounds.

const Game = preload("res://game/minigames/arcade/music_box_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_plays_a_phrase()
	_plucking_empty_sockets()
	_pressure_and_the_lid()
	_the_tune_speeds_up()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: music box pins, plucked sockets, perfect and good, combos, misses, wild presses, pressure, lid pop, speed-up, socket rows, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_plays_a_phrase() -> void:
	var game := _round("lullaby", false)
	_check(game.stage == "ready" and game.thresholds == [200, 380, 540] and game.pins.size() == 4 and game.pins.filter(func(pin: Dictionary) -> bool: return pin.gap).size() == 1,
		"a round opens with a short phrase and one empty socket on the cylinder")
	var plucked := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		plucked = plucked or game.pins.any(func(pin: Dictionary) -> bool: return pin.state == "plucked")
	_check(plucked and game.score == 0 and game.strays == 0 and game.pressure == 0.0, "the countdown plucks its empty socket by itself; space does nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.pins.all(func(pin: Dictionary) -> bool: return pin.state == "coming"), "play starts with the first pins on their way")


func _plucking_empty_sockets() -> void:
	var game := _quiet()
	game._pin(3, game.clock + 0.3, false)
	_advance(game, 0.32)
	_check(game.pins[0].state == "played" and game.plucked_at[3] > 0.0 and game.score == 0, "a pin plays its note by itself")
	for index in 4:
		game._pin(index, game.clock + 0.2, true)
		_advance(game, 0.2)
		_tap(game, KEY_SPACE)
	_check(game.filled == 4 and game.perfects == 4 and game.combo == 4 and game.score == Game.PERFECT_POINTS * 4 + 1, "pressing as an empty socket reaches the comb plucks its note; four in a row start a combo (%d)" % game.score)
	game._pin(5, game.clock + 0.2, true)
	_advance(game, 0.2 - 0.1)
	var before := game.score
	_tap(game, KEY_DOWN)
	_check(game.filled == 5 and game.score - before == Game.GOOD_POINTS + 1, "a little early still plucks it, for less (↓ works too)")
	var pad := _quiet()
	pad._pin(2, pad.clock + 0.2, true)
	_advance(pad, 0.2)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.filled == 1, "the gamepad A button plucks too")


func _pressure_and_the_lid() -> void:
	var game := _quiet()
	game.score = 30
	_tap(game, KEY_SPACE)
	_check(game.strays == 1 and is_equal_approx(game.pressure, 1.0) and game.score == 30 - Game.STRAY_POINTS and game.combo == 0, "a press with no empty socket at the comb clunks and builds pressure")
	game._pin(1, game.clock + 0.1, true)
	_advance(game, 0.1 + Game.GOOD + 0.02)
	_check(game.missed == 1 and is_equal_approx(game.pressure, 2.0), "an empty socket that rolls past builds pressure too")
	game._pin(1, game.clock + 0.1, true)
	_advance(game, 0.1)
	_tap(game, KEY_SPACE)
	_check(is_equal_approx(game.pressure, 1.5), "a plucked note lets a little pressure out")
	for press in 3:
		_tap(game, KEY_SPACE)
	_check(game.popped() and game.pops == 1 and game.pressure == 0.0 and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"at full pressure the lid pops and the clown punches out; the first time is a free look")
	game._pin(2, game.clock + 0.4, true)
	_advance(game, 0.4)
	_tap(game, KEY_SPACE)
	_check(game.filled == 1, "nothing can be plucked while the clown is out")
	_advance(game, Game.POP_SECONDS)
	_check(not game.popped(), "then the clown springs back in")
	for press in 4:
		_tap(game, KEY_SPACE)
	_check(game.pops == 2 and game.mistakes == 1, "a second pop counts as a mistake")


func _the_tune_speeds_up() -> void:
	var game := _playing("lullaby")
	var seen: Dictionary = {}
	var gaps_early := 0
	var gaps_late := 0
	var notes_early := 0
	var notes_late := 0
	var longest_row := 0
	var row := 0
	var last_t := -1.0
	while game.stage == "play":
		game.step(STEP)
		for pin: Dictionary in game.pins:
			if seen.has(pin.id):
				continue
			seen[pin.id] = true
			var at := (float(pin.t) - game.clock + game.play_time) / game.round_seconds
			if at < 0.3:
				notes_early += 1
				gaps_early += int(pin.gap)
			elif at > 0.7:
				notes_late += 1
				gaps_late += int(pin.gap)
			if float(pin.t) > last_t:
				last_t = float(pin.t)
				row = row + 1 if pin.gap else 0
				longest_row = maxi(longest_row, row)
	_check(game.tempo_at(game.round_seconds) > game.tempo_at(0.0) * 1.4 and notes_late > notes_early, "the cylinder turns faster later (%d to %d notes)" % [notes_early, notes_late])
	_check(float(gaps_late) / notes_late > float(gaps_early) / notes_early, "empty sockets grow more common")
	_check(longest_row >= 2, "later the empty sockets come in rows (%d)" % longest_row)


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["lullaby", "wobble", "holes"], "three variants are declared")
	var wobble := _playing("wobble")
	var speeds: Array[float] = []
	for second in 10:
		speeds.append(wobble.tempo_at(float(second)))
	_check(speeds.max() > speeds.min() * 1.2, "the loose spring makes the tempo wobble")
	var helped := _quiet(true)
	helped._pin(1, helped.clock + 0.3, true)
	_advance(helped, 0.3 - Game.GOOD * 1.3)
	_tap(helped, KEY_SPACE)
	_check(helped.filled == 1, "assist widens the timing")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["lullaby", "wobble", "holes"]:
		var gold := _play(session, variant_id, false, 0.01, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady ear earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "lullaby", false, 0.1, BRONZE_SKIP, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a loose ear who misses some sockets still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "lullaby", false, 0.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "pressing over and over earns nothing (score %d)" % masher.score)
	var idle := _play(session, "lullaby", false, 0.0, 1.0, false)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "lullaby", true, 0.01, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("music box scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## The share of empty sockets the bronze ear lets roll past.
const BRONZE_SKIP := 0.3


## Play a whole round through Session input: press `off` seconds before each
## empty socket reaches the comb, letting a share `skip` roll past; `mash`
## presses every tenth of a second instead.
func _play(session: Session, variant_id: String, assisted: bool, off: float, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-072", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 23
	var planned: Dictionary = {}
	var tick := 0
	while not session.ended and game.stage == "play":
		var press := false
		if mash:
			press = tick % 12 == 0
		else:
			for pin: Dictionary in game.pins:
				if pin.state != "coming" or not pin.gap:
					continue
				if not planned.has(pin.id):
					planned[pin.id] = decide.randf() >= skip
				if planned[pin.id] and game.clock >= float(pin.t) - off:
					press = true
					planned[pin.id] = false
					break
		if press:
			_session_key(session, KEY_SPACE, true)
			session._process(STEP)
			_session_key(session, KEY_SPACE, false)
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


## A round in play with no pins of its own, so a check can send them by hand.
func _quiet(assisted := false) -> Game:
	var game := _playing("lullaby", assisted)
	game._next_beat = 999.0
	game.pins.clear()
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
