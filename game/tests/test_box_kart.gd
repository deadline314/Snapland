extends SceneTree
## 紙盒變車 rules: the demo jump, turning in the air, the drift, perfect, good
## and folded landings, speed, streaks, hops, seesaws, steeper ramps,
## variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/box_kart_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_flies_a_jump()
	_turning_in_the_air()
	_landings()
	_hops_seesaws_and_steeper_ramps()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: box kart turning, drift, perfect, good and folded landings, speed, streaks, hops, seesaws, steeper ramps, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_flies_a_jump() -> void:
	var game := _round("blocks", false)
	_check(game.stage == "ready" and game.thresholds == [300, 1000, 1900] and game.phase == "roll", "a round opens rolling toward the first kicker")
	var flew := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_RIGHT)
		game.step(STEP)
		flew = flew or game.phase == "air"
	_check(flew and game.folds == 0 and game.landed.get("grade", "") in ["perfect", "good"] and game.score == 0, "the countdown flies one jump and lands it by itself")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.phase == "roll" and is_equal_approx(game.speed, Game.SPEED_START), "play starts rolling at the starting speed")


func _turning_in_the_air() -> void:
	var game := _airborne(0.3)
	var start := game.pitch
	_advance(game, 0.2)
	_check(game.pitch > start + 0.1, "left alone in the air the box tips nose-down")
	start = game.pitch
	_press(game, KEY_LEFT, true)
	_advance(game, 0.2)
	_press(game, KEY_LEFT, false)
	_check(game.pitch < start - 0.15, "holding ← lifts the nose")
	start = game.pitch
	_press(game, KEY_D, true)
	_advance(game, 0.1)
	_press(game, KEY_D, false)
	_check(game.pitch > start + 0.2, "holding → (or D) dips it")
	var pad := _airborne(0.3)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_LEFT
	button.pressed = true
	start = pad.pitch
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.2)
	_check(pad.pitch < start, "the gamepad d-pad turns it too")


func _landings() -> void:
	var game := _airborne(0.3)
	_land_at(game, 0.3)
	_check(game.landed.grade == "perfect" and game.perfects == 1 and game.streak == 1 and game.speed > Game.SPEED_START
		and game.score == roundi((Game.PERFECT_POINTS + Game.STREAK_POINTS) * game.speed), "flat on the ramp is a perfect landing: points and more speed (%d)" % game.score)
	var good := _airborne(0.3)
	_land_at(good, 0.3 + 0.2)
	_check(good.landed.grade == "good" and is_equal_approx(good.speed, Game.SPEED_START) and good.score == roundi(Game.GOOD_POINTS + Game.STREAK_POINTS), "a little off is still a good landing")
	var fold := _airborne(0.3)
	_land_at(fold, 0.3 + 0.6)
	_check(fold.landed.grade == "fold" and fold.phase == "fold" and fold.folds == 1 and fold.mistakes == 0 and fold.fail_at > 0.0 and fold.score == 0
		and is_equal_approx(fold.speed, Game.CRASH_SPEED) and not fold.snapshot().word_good, "a crooked landing folds the box; the first time is a free look")
	_advance(fold, Game.FOLD_SECONDS + 0.05)
	_check(fold.phase == "roll", "after a moment the box unfolds and rolls on")
	fold._roll_left = 0.0
	_advance(fold, 0.02)
	_land_at(fold, float(fold.jump.land) + 0.8)
	_check(fold.folds == 2 and fold.mistakes == 1, "a second fold counts as a mistake")
	var idle := _playing("blocks")
	idle.touched = false
	idle._roll_left = 0.0
	_advance(idle, 0.02)
	idle.jump.land = idle.pitch + idle._drift * float(idle.jump.air)
	_advance(idle, float(idle.jump.air) + 0.05)
	_check(idle.score == 0 and idle.landed.grade == "perfect", "a box nobody steered can still land, but pays nothing")


func _hops_seesaws_and_steeper_ramps() -> void:
	var game := _playing("blocks")
	game.play_time = game.round_seconds * 0.7
	var kinds: Dictionary = {}
	var steepest := 0.0
	for tries in 200:
		game.phase = "roll"
		game._launch()
		kinds[game.jump.kind] = true
		steepest = maxf(steepest, float(game.jump.land))
	_check(kinds.has("hop") and kinds.has("seesaw") and kinds.has("ramp"), "late in the round little hops and seesaws join the ramps")
	var early := _playing("blocks")
	var early_steepest := 0.0
	var early_kinds: Dictionary = {}
	for tries in 200:
		early.phase = "roll"
		early.hops_left = 0
		early._launch()
		early_kinds[early.jump.kind] = true
		early_steepest = maxf(early_steepest, float(early.jump.land))
	_check(early_kinds.keys() == ["ramp"] and steepest > early_steepest * 1.25, "early on every jump is a plain ramp, and later ones are steeper")
	var saw := _quiet()
	saw.jump = {"kind": "seesaw", "launch": -0.3, "land": -0.2, "flip": 0.4, "air": 1.2, "at": saw.clock}
	saw.phase = "air"
	_check(is_equal_approx(saw._target(), -0.2), "a seesaw starts tipped toward the box")
	_advance(saw, 0.7)
	_check(is_equal_approx(saw._target(), 0.4), "and flops the other way halfway through the flight")
	_check(game.drift() > early.drift() * 1.3, "the box tips forward faster later in the round")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["blocks", "steep", "seesaw"], "three variants are declared")
	var steep := _playing("steep")
	var plain := _playing("blocks")
	var steep_max := 0.0
	var plain_max := 0.0
	for tries in 100:
		steep.phase = "roll"
		steep._launch()
		plain.phase = "roll"
		plain._launch()
		steep_max = maxf(steep_max, float(steep.jump.land))
		plain_max = maxf(plain_max, float(plain.jump.land))
	_check(steep_max > plain_max * 1.15, "the steep day has steeper ramps")
	var saws := _playing("seesaw")
	saws.play_time = saws.round_seconds * 0.2
	var found := false
	for tries in 60:
		saws.phase = "roll"
		saws.hops_left = 0
		saws._launch()
		found = found or saws.jump.kind == "seesaw"
	_check(found, "the seesaw day brings seesaws early")
	var helped := _playing("blocks", true)
	_check(helped.good_reach() > plain.good_reach() * 1.3, "assist widens a good landing")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["blocks", "steep", "seesaw"]:
		var gold := _play(session, variant_id, false, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady pilot earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "blocks", false, BRONZE_AIM, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a rough pilot still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "blocks", false, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "rocking the box at random earns nothing (score %d)" % masher.score)
	var helped := _play(session, "blocks", true, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("box kart scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## How far off the slope the rough pilot aims, either way.
const BRONZE_AIM := 0.22


## Play a whole round through Session input: in the air, steer so the box would
## meet the slope `aim` off (alternately high and low); `mash` rocks at random.
func _play(session: Session, variant_id: String, assisted: bool, aim: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-071", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 17
	var holding := 0
	var tick := 0
	var jumps := 0
	var last_at := -1.0
	while not session.ended and game.stage == "play":
		var want := 0
		if mash:
			want = [-1, 0, 1][(tick / 20 + decide.randi() % 2) % 3]
		elif game.phase == "air":
			if float(game.jump.at) != last_at:
				last_at = float(game.jump.at)
				jumps += 1
			var left := maxf(0.0, float(game.jump.air) - (game.clock - float(game.jump.at)))
			var bias := aim * (1.0 if jumps % 2 == 0 else -1.0)
			var predicted := game.pitch + game._drift * left
			var error := game._target() + bias - predicted
			var needed := error / maxf(0.05, left) / Game.TURN
			if absf(needed) > 0.25 or (left < 0.08 and absf(error) > 0.04):
				want = 1 if needed > 0.0 else -1
		if want != holding:
			if holding != 0:
				_session_key(session, KEY_RIGHT if holding > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			holding = want
		session._process(STEP)
		tick += 1
	if holding != 0:
		_session_key(session, KEY_RIGHT if holding > 0 else KEY_LEFT, false)
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


## A round in play, mid-flight over a ramp landing at `land`, as if already steered.
func _airborne(land: float) -> Game:
	var game := _quiet()
	game.jump = {"kind": "ramp", "launch": -0.3, "land": land, "flip": land, "air": 1.0, "at": game.clock}
	game.phase = "air"
	game.pitch = -0.3
	game._drift = 0.9
	return game


## Set the box's pitch so that it lands at `pitch` when the flight ends.
func _land_at(game: Game, pitch: float) -> void:
	var left := float(game.jump.air) - (game.clock - float(game.jump.at))
	game.pitch = pitch - game._drift * left
	_advance(game, left + 0.02)


func _quiet() -> Game:
	var game := _playing("blocks")
	game.touched = true
	game.phase = "roll"
	game._roll_left = 999.0
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
