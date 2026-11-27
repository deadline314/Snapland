extends SceneTree
## 螢火蟲長曝光 rules: the exposure, the real lamp, shakes, overexposure, temptations, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/hold_still_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_holding_still_until_the_real_lamp()
	_anything_shakes_the_camera()
	_temptations_never_copy_the_real_lamp()
	_variants_change_the_camera()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: hold still exposure, real lamp, shakes, overexposure, temptations, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.phase == "expose" and game.decoys.is_empty() and game.thresholds == [60, 140, 220],
		"a round opens on a short demonstration exposure with its medal lines declared")
	var notes: Array[int] = []
	var lit_at := -1.0
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		notes.append_array(game.consume_notes())
		if lit_at < 0.0 and game.lit:
			lit_at = game.clock
	_check(absf(lit_at - Game.DEMO_EXPOSURE) < 0.03 and game.result == "crisp" and game.phase == "print" and game.score == 0 and game.crisp_count == 0,
		"the countdown lights the real lamp and takes the picture by itself; presses do nothing yet")
	_check(notes.find(84) >= 0 and notes.find(88) > notes.find(84), "the real lamp rings a double chime")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.phase == "frame" and game.shot == 1 and game.result == "", "play starts by framing the first shot")


func _holding_still_until_the_real_lamp() -> void:
	var game := _playing("standard")
	_tap(game, KEY_SPACE)
	_tap(game, KEY_LEFT)
	_check(game.phase == "frame" and game.result == "", "buttons are harmless while the shot is being framed")
	_advance(game, Game.FRAME_SECONDS + 0.02)
	_check(game.phase == "expose" and is_equal_approx(game.exposure, Game.EXPOSE_FIRST) and game.lamp_times == [game.exposure] and game.lamp_slot == 1
		and game.snapshot().lamp_slots == 1, "the shutter opens for three seconds at first, with one lamp socket")
	_advance(game, game.exposure - 0.1)
	_check(not game.lit and game.phase == "expose" and game.snapshot().exposed > game.exposure - 0.2, "nothing happens for the whole exposure if nobody moves")
	_advance(game, 0.15)
	_check(game.lit and game.snapshot().lit, "then the real lamp lights")
	_advance(game, Game.SHUTTER_WINDOW - 0.2)
	_tap(game, KEY_SPACE)
	_check(game.result == "crisp" and game.phase == "print" and game.score == 30 and game.crisp_count == 1 and game.mistakes == 0 and game.snapshot().word_good,
		"one press while it is lit takes a crisp picture: ten points a second of exposure")
	_tap(game, KEY_SPACE)
	_advance(game, Game.PRINT_SECONDS + 0.02)
	_check(game.phase == "frame" and game.shot == 2 and game.score == 30, "the print is shown, then the next shot is framed")
	_advance(game, Game.FRAME_SECONDS + game.exposure + Game.SHUTTER_WINDOW + 0.1)
	_check(game.result == "over" and game.phase == "print" and game.score == 30 and game.ruined == 1 and game.mistakes == 0 and not game.snapshot().word_good,
		"missing the lamp overexposes the picture; the first ruined photo is a free lesson")


func _anything_shakes_the_camera() -> void:
	var game := _playing("standard")
	var ruined := 0
	for code: int in [KEY_SPACE, KEY_LEFT, KEY_UP, KEY_X, KEY_DOWN]:
		while game.phase != "expose":
			game.step(STEP)
		_advance(game, 0.2)
		_press(game, code, true)
		_press(game, code, false)
		ruined += 1
		_check(game.result == "smear" and game.phase == "print" and game.score == 0 and game.ruined == ruined and game.mistakes == ruined - 1
			and game.snapshot().exposed < 0.5, "key %d shakes the camera and smears the picture at once" % code)
		_advance(game, Game.PRINT_SECONDS + 0.05)
		_check(game.phase == "print", "a ruined print is shown longer than a good one")
		_advance(game, Game.RUINED_SECONDS - Game.PRINT_SECONDS)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	while game.phase != "expose":
		game.step(STEP)
	game.handle_input(pad, Vector2.ZERO)
	_check(game.result == "smear", "a gamepad button shakes it too")


func _temptations_never_copy_the_real_lamp() -> void:
	var early_kinds: Dictionary = {}
	var late_kinds: Dictionary = {}
	var early_count := 0
	var late_count := 0
	var early_length := 0.0
	var late_length := 0.0
	var lookalike_early := false
	var lookalike_late := false
	var rounds := 0
	for round_seed in 60:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		# The flash variant replaces every temptation; it has its own check below.
		if game.variant.id == "flash":
			continue
		rounds += 1
		_advance(game, Base.READY_SECONDS + 0.05)
		for late: bool in [false, true]:
			if late:
				_advance(game, game.round_seconds * 0.8)
				game._next_shot()
			for decoy: Dictionary in game.decoys:
				_check(float(decoy.time) >= 0.3 and float(decoy.time) < game.exposure - Game.DECOY_CLEARANCE + 0.001, "temptations end before the real lamp's moment")
				if late:
					late_kinds[decoy.kind] = true
					lookalike_late = lookalike_late or (decoy.kind == "lamp" and int(decoy.look) == 2)
				else:
					early_kinds[decoy.kind] = true
					lookalike_early = lookalike_early or int(decoy.look) == 2
			if late:
				late_count += game.decoys.size()
				late_length = game.exposure
			else:
				early_count += game.decoys.size()
				early_length = game.exposure
	_check(rounds >= 30 and early_count == rounds and late_count == rounds * 3 and late_length > early_length * 1.6, "exposures get longer and more crowded with temptations (%d then %d)" % [early_count, late_count])
	_check(early_kinds.keys().all(func(kind: String) -> bool: return kind in ["prompt", "mosquito"]) and late_kinds.has("lamp") and late_kinds.has("itch"),
		"fake lamps and the itchy nose only join later")
	_check(not lookalike_early and lookalike_late, "a fake lamp in the real colour only appears late, and is still a different shape")
	var game := _playing("standard")
	_advance(game, Game.FRAME_SECONDS + 0.02)
	game.consume_notes()
	var first: Dictionary = game.decoys[0]
	_advance(game, float(first.time) + 0.05)
	var notes := game.consume_notes()
	_check(float(first.at) > 0.0 and game.phase == "expose" and notes.size() == 1 and notes[0] not in [84, 88], "a temptation shows itself with a single low note, never the double chime")


func _variants_change_the_camera() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "flash", "moving", "double"], "four variants are declared")
	var flash := _playing("flash")
	_advance(flash, flash.round_seconds * 0.6)
	flash._next_shot()
	_check(flash.decoys.size() >= 2 and flash.decoys.all(func(decoy: Dictionary) -> bool: return decoy.kind == "flash"), "the flash variant tempts only with a soft flash and a sound")
	var slots: Dictionary = {}
	for round_seed in 60:
		var moving := Game.new()
		moving.round_seed = round_seed
		moving.reset(false, "noon")
		if moving.variant.id != "moving":
			continue
		_advance(moving, Base.READY_SECONDS + moving.round_seconds * 0.7)
		moving._next_shot()
		slots[moving.lamp_slot] = true
		for decoy: Dictionary in moving.decoys:
			_check(decoy.kind != "lamp" or int(decoy.slot) != moving.lamp_slot, "a fake lamp never lights the real lamp's socket")
		_check(moving.snapshot().lamp_slots == Game.LAMP_SLOTS, "the moving variant shows three sockets")
	_check(slots.size() == Game.LAMP_SLOTS, "the real lamp can appear in any socket")
	var twice := _playing("double")
	_advance(twice, Game.FRAME_SECONDS + 0.02)
	_check(twice.lamp_times.size() == 2 and is_equal_approx(twice.lamp_times[0], twice.exposure * 0.5) and twice.snapshot().lamps_needed == 2, "a double exposure lights the real lamp twice")
	_advance(twice, twice.lamp_times[0] + 0.1)
	_tap(twice, KEY_SPACE)
	_check(twice.phase == "expose" and twice.result == "" and twice.lamps_done == 1 and not twice.lit and twice.score == 0, "the first press keeps the shutter open")
	_advance(twice, twice.exposure * 0.5)
	_tap(twice, KEY_SPACE)
	_check(twice.result == "crisp" and twice.score == 30, "the second press finishes the picture")
	var helped := _round("standard", true)
	_check(helped.shutter_window() > Game.SHUTTER_WINDOW * 1.4, "assist keeps the real lamp lit longer")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "flash", "moving", "double"]:
		# Gold: never moves, and answers the real lamp after a quarter of a second.
		var gold := _play(session, variant_id, false, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1 and gold.mistakes == 0, "holding still earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: falls for the first temptation of two shots in every three.
	var bronze := _play(session, "standard", false, 3)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a twitchy round still earns bronze (score %d)" % bronze.score)
	# Fooled: presses at every temptation.
	var fooled := _play(session, "standard", false, 1)
	_check(not fooled.success and fooled.score < lines[0] and fooled.mistakes > 3, "falling for everything earns nothing (score %d)" % fooled.score)
	var helped := _play(session, "standard", true, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("hold still scores: gold %s, bronze %d, fooled %d, assisted %d" % [gold_scores, bronze.score, fooled.score, helped.score])
	session.free()


## Play a whole round through Session input: answer the real lamp after 0.25 s;
## with `gullible` N > 1, also press at the first temptation of every shot
## whose number is not a multiple of N; with 1, of every shot.
func _play(session: Session, variant_id: String, assisted: bool, gullible: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-073", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	while not session.ended and game.stage == "play":
		var press := false
		if game.phase == "expose":
			press = game.lit and game.clock - game.lamp_at >= 0.25
			if gullible > 0 and (gullible == 1 or game.shot % gullible != 0) and not game.decoys.is_empty() and float(game.decoys[0].at) > 0.0:
				press = true
		if press:
			_session_key(session, KEY_SPACE, true)
			session._process(STEP)
			_session_key(session, KEY_SPACE, false)
		session._process(STEP)
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
