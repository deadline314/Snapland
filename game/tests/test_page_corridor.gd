extends SceneTree
## 折頁走廊 rules: the countdown demo, jumping and claps, the dead-on bonus,
## the bookmark, stumbles, trembling holds, feints, pairs, escalation,
## variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/page_corridor_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_jump()
	_untouched_rounds_never_score()
	_jumping_over_a_clap()
	_caught_on_the_ground_makes_a_bookmark()
	_wasted_jumps_stumble()
	_trembling_holds_and_feints()
	_pairs_and_escalation()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: page corridor demo, jumps, claps, dead-on bonus, bookmark, stumbles, trembling holds, feints, pairs, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_jump() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [300, 750, 1150] and game.creases.size() >= 3, "a round opens with the corridor's creases planned ahead")
	var cleared_in_demo := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		for crease: Dictionary in game.creases:
			cleared_in_demo = cleared_in_demo or bool(crease.cleared)
	_check(cleared_in_demo and game.squash_at < 0.0 and game.score == 0 and game.mistakes == 0, "the countdown hops the first crease by itself and scores nothing")
	_advance(game, 0.1)
	var first: Dictionary = game.next_crease()
	_check(game.stage == "play" and game.distance < game.speed() * 0.2 and float(first.at) >= game.speed() * (Game.FIRST_LEAD - 0.2) and str(first.kind) == "plain",
		"play starts afresh with the first crease well ahead")


func _jumping_over_a_clap() -> void:
	var game := _playing("standard")
	var crease: Dictionary = game.next_crease()
	_jump_for(game, crease, 0.0)
	_check(bool(crease.cleared) and game.cleared == 1 and game.dead_on == 1 and game.score >= Game.CLEAR_POINTS + Game.DEAD_ON_POINTS and game.squash_at < 0.0,
		"jumping so the clap comes at the top of the jump clears it with the dead-on bonus")
	var early := _playing("standard")
	var next: Dictionary = early.next_crease()
	_jump_for(early, next, 0.18)
	_check(bool(next.cleared) and early.dead_on == 0 and early.score == Game.CLEAR_POINTS + Game.STREAK_POINTS, "an off-centre jump still clears, without the bonus")
	var streak := _playing("standard")
	for hop in 4:
		_jump_for(streak, streak.next_crease(), 0.0)
	_check(streak.streak == 4 and streak.score > 4 * (Game.CLEAR_POINTS + Game.DEAD_ON_POINTS), "a run of clears builds a streak bonus")
	var pad := _playing("standard")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	var arrow := _playing("standard")
	_press(arrow, KEY_UP, true)
	_check(pad.airborne and arrow.airborne, "the gamepad A button and the up arrow jump too")


func _caught_on_the_ground_makes_a_bookmark() -> void:
	var game := _playing("standard")
	var crease: Dictionary = game.next_crease()
	_advance(game, (float(crease.at) - game.distance) / game.speed() + 0.02)
	_check(not bool(crease.cleared) and float(crease.snapped_at) > 0.0 and game.squashes == 1 and game.mistakes == 0 and game.fail_at > 0.0
		and not game.snapshot().word_good and game.squashed(), "standing on a crease when it claps presses the traveller into a bookmark; the first one is a free look")
	var parked := game.distance
	_tap(game, KEY_SPACE)
	_advance(game, 0.8)
	_check(game.distance == parked and not game.airborne, "the corridor waits, and no jump starts, while the bookmark floats away")
	_advance(game, Game.SQUASH_SECONDS)
	_check(game.distance > parked, "then the corridor runs on")
	_advance(game, (float(game.next_crease().at) - game.distance) / game.speed() + 0.02)
	_check(game.squashes == 2 and game.mistakes == 1, "a second bookmark counts as a mistake")


func _wasted_jumps_stumble() -> void:
	var game := _playing("standard")
	_tap(game, KEY_SPACE)
	_check(game.airborne, "the button jumps")
	_advance(game, Game.JUMP_SECONDS + 0.02)
	_check(not game.airborne and game.stumbling() and game.stumbles == 1 and game.streak == 0, "a jump that clears nothing lands in a stumble")
	_tap(game, KEY_SPACE)
	_check(not game.airborne, "no jump starts mid-stumble")
	var mash := _playing("standard")
	for tick in int(12.0 / STEP):
		if tick % 6 == 0:
			_tap(mash, KEY_SPACE)
		mash.step(STEP)
	_check(mash.squashes >= 2 and mash.stumbles >= 4, "jumping all the time stumbles into the claps (bookmarks %d, stumbles %d)" % [mash.squashes, mash.stumbles])


func _trembling_holds_and_feints() -> void:
	var game := _playing("standard")
	var crease: Dictionary = game.next_crease()
	crease.kind = "hold"
	crease.hold = 0.9
	_advance(game, (float(crease.at) - game.distance) / game.speed() + 0.05)
	var parked := game.distance
	_check(float(crease.arrived_at) > 0.0 and float(crease.snapped_at) < 0.0 and is_equal_approx(parked, float(crease.at)), "a trembling crease stops under the traveller and waits")
	_tap(game, KEY_SPACE)
	_advance(game, Game.JUMP_SECONDS + 0.05)
	_check(not bool(crease.cleared) and game.stumbles == 1 and float(crease.snapped_at) < 0.0 and game.distance == parked, "jumping at the tremble only lands in a stumble before the slam")
	_advance(game, 0.9)
	_check(float(crease.snapped_at) > 0.0 and game.squashes == 1, "and the slam then catches the traveller")
	var patient := _playing("standard")
	var held: Dictionary = patient.next_crease()
	held.kind = "hold"
	held.hold = 1.0
	_advance(patient, (float(held.at) - patient.distance) / patient.speed() + 0.01)
	var arrived := float(held.arrived_at)
	_advance(patient, arrived + 1.0 - Game.DIP_SECONDS + 0.1 - patient.clock)
	_tap(patient, KEY_SPACE)
	_advance(patient, 0.5)
	_check(bool(held.cleared) and patient.squashes == 0, "waiting for the dip and jumping then clears the slam")
	var plan := _playing("pranks")
	plan.play_time = plan.round_seconds * 0.5
	var kinds := {}
	for planned in 300:
		plan.distance = float(plan.creases.back().at)
		plan._plan()
	for row: Dictionary in plan.creases:
		kinds[row.kind] = int(kinds.get(row.kind, 0)) + 1
		if str(row.kind) == "hold":
			_check(float(row.hold) >= Game.HOLD_SHORTEST and float(row.hold) <= Game.HOLD_LONGEST, "a hold lasts a fair, dip-telegraphed while")
	_check(int(kinds.get("hold", 0)) > 20 and int(kinds.get("feint", 0)) > 20, "the prank night brings trembling holds and early-twitching feints: %s" % [kinds])


func _pairs_and_escalation() -> void:
	var early := _playing("standard")
	var plain := true
	for planned in 60:
		early.distance = float(early.creases.back().at)
		early._plan()
	for row: Dictionary in early.creases:
		plain = plain and str(row.kind) == "plain" and not bool(row.pair)
	_check(plain, "the opening stretch is plain creases only")
	var late := _playing("standard")
	var first_speed := late.speed()
	late.play_time = late.round_seconds * 0.95
	_check(late.speed() > first_speed * 1.5, "the corridor runs much faster by the end")
	var pairs := _playing("pairs")
	pairs.play_time = pairs.round_seconds * 0.5
	for planned in 200:
		pairs.distance = float(pairs.creases.back().at)
		pairs._plan()
	var found := 0
	var spaced := true
	for index in range(1, pairs.creases.size()):
		if bool(pairs.creases[index].pair):
			found += 1
			var gap := (float(pairs.creases[index].at) - float(pairs.creases[index - 1].at)) / pairs.speed()
			spaced = spaced and absf(gap - Game.PAIR_GAP) < 0.05 and not bool(pairs.creases[index - 1].pair)
	_check(found > 20 and spaced, "the pairs night claps two creases in quick succession, never three")
	var double := _playing("standard")
	var one: Dictionary = double.next_crease()
	var two := double._crease(float(one.at) + Game.PAIR_GAP * double.speed(), "plain", 0.0, true)
	double.creases.insert(1, two)
	_jump_for(double, one, 0.0)
	_jump_for(double, two, 0.0)
	_check(bool(one.cleared) and bool(two.cleared), "two quick jumps clear a pair")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "pairs", "pranks"], "three variants are declared")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.speed() < standard.speed() * 0.8 and helped.air_time() > standard.air_time() * 1.2, "assist slows the corridor and gives a longer jump")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "pairs", "pranks"]:
		var gold := _play(session, variant_id, false, 0.02)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp jumper earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.3)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a sloppy jumper still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0)
	_check(not idle.success and idle.score == 0, "never jumping earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.02)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("page corridor scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses. The jumper aims to be at
## the top of the jump when each crease claps, off by up to `wobble` seconds:
## a plain crease claps as it reaches the feet, a trembling one only after its
## dip, which the jumper waits for. A negative `wobble` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, wobble: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-085", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 11
	var aimed_at := -1
	var miss := 0.0
	while not session.ended and game.stage == "play":
		var next: Dictionary = game.next_crease()
		if wobble >= 0.0 and not next.is_empty() and not game.airborne:
			if int(next.number) != aimed_at:
				aimed_at = int(next.number)
				miss = aim.randf_range(-wobble, wobble)
			var until := INF
			if float(next.hold) > 0.0:
				if float(next.arrived_at) >= 0.0:
					var left := float(next.hold) - (game.clock - float(next.arrived_at))
					# React to the dip, which starts DIP_SECONDS before the slam.
					if left <= Game.DIP_SECONDS - 0.08:
						until = left
			else:
				until = (float(next.at) - game.distance) / game.speed()
			if until <= game.air_time() * 0.5 + miss:
				_session_key(session, KEY_SPACE, true)
				_session_key(session, KEY_SPACE, false)
		session._process(STEP)
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


## Step until `crease` is `before` seconds from clapping at the top of a jump,
## jump, then step past the clap.
func _jump_for(game: Game, crease: Dictionary, before: float) -> void:
	var lead := game.air_time() * 0.5 + before
	_advance(game, maxf(0.0, (float(crease.at) - game.distance) / game.speed() - lead))
	_tap(game, KEY_SPACE)
	_advance(game, game.air_time() + 0.02)


func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		for round_seed in 40:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 60.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 80 seeded rounds: %s" % [scored])


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
	# These checks set the scene up directly; count the round as played.
	game.touched = true
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


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
