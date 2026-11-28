extends SceneTree
## 枕頭靜步 rules: the countdown demo, creeping, snoring and quiet spells, the
## heartbeat to freeze, fake sleepers peeking, beds and rows passed, the
## pillow, escalation, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/quiet_steps_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_creeping()
	_untouched_rounds_never_score()
	_creeping_while_they_snore()
	_moving_when_they_wake_brings_a_pillow()
	_fake_sleepers_peek()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: quiet steps demo, creeping, snoring, quiet spells, freezing, fake sleepers, beds and rows, pillow, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_creeping() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [200, 520, 620] and game.guests.size() == Game.BEDS, "a round opens on a row of four sleeping guests")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_RIGHT)
		game.step(STEP)
	_check(game.walker > 0.03 and game.score == 0 and game.caught == 0, "the countdown creeps forward by itself and scores nothing")
	_advance(game, 0.05)
	_check(game.stage == "play" and game.walker < 0.02 and game.guests.all(func(g: Dictionary) -> bool: return not bool(g.fake)), "play starts back at the door with honest sleepers")


func _creeping_while_they_snore() -> void:
	var game := _playing("standard")
	_snoring_always(game)
	_press(game, KEY_RIGHT, true)
	_advance(game, 1.0)
	_check(game.walker > 0.09 and game.caught == 0, "holding → creeps along while everyone snores")
	_advance(game, 6.0)
	_press(game, KEY_RIGHT, false)
	_check(game.beds_passed == 4 and game.rows == 1 and game.row == 2 and game.walker < 0.2 and game.score >= 4 * Game.BED_POINTS + Game.ROW_POINTS,
		"passing every bed and reaching the far door scores, then a new row begins")
	var pad := _playing("standard")
	_snoring_always(pad)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	pad.handle_input(stick, Vector2.ZERO)
	_advance(pad, 0.5)
	_check(pad.walker > 0.03, "the gamepad stick creeps too")


func _moving_when_they_wake_brings_a_pillow() -> void:
	var game := _playing("standard")
	_quiet_at(game, 0, game.clock + 0.5)
	game.walker = float(game.guests[0].x)
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.5 + Game.REACT * 0.5)
	_press(game, KEY_RIGHT, false)
	_check(game.caught == 0, "a heartbeat after the snoring stops is still safe to freeze in")
	var late := _playing("standard")
	_quiet_at(late, 0, late.clock + 0.5)
	late.walker = float(late.guests[0].x) - 0.05
	_press(late, KEY_RIGHT, true)
	_advance(late, 0.5 + Game.REACT + 0.1)
	_check(late.caught == 1 and late.mistakes == 0 and late.fail_at > 0.0 and late.pillowed() and late.thrower == 0 and not late.snapshot().word_good,
		"still moving after the heartbeat brings a pillow in the face; the first one is a free look")
	var x := late.walker
	_advance(late, 0.8)
	_check(late.walker == x, "the traveller stands dazed while the feathers settle")
	var still := _playing("standard")
	_quiet_at(still, 0, still.clock + 0.2)
	still.walker = float(still.guests[0].x)
	_advance(still, 1.5)
	_check(still.caught == 0, "standing still while they are awake is safe")
	var again := _playing("standard")
	for pillow in 2:
		_quiet_at(again, 1, again.clock + 0.1)
		again.walker = float(again.guests[1].x)
		_press(again, KEY_RIGHT, true)
		_advance(again, 0.8)
		_press(again, KEY_RIGHT, false)
		_advance(again, Game.PILLOW_SECONDS)
	_check(again.caught == 2 and again.mistakes == 1, "a second pillow counts as a mistake")


func _fake_sleepers_peek() -> void:
	var game := _playing("standard")
	_snoring_always(game)
	game.guests[2].peeks = [game.clock + 0.2]
	game.walker = float(game.guests[2].x) - 0.1
	_check(game.guest_state(2) == "snore", "a faker snores like the rest")
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.2 + Game.REACT + 0.1)
	_check(game.caught == 1 and game.thrower == 2, "moving while a faker peeks brings a pillow too")
	var plan := _playing("peekers")
	plan.play_time = plan.round_seconds * 0.5
	var fakes := 0
	for row in 20:
		plan._plan_row()
		fakes += plan.guests.filter(func(g: Dictionary) -> bool: return bool(g.fake)).size()
	_check(fakes > 20, "the peeking party brings many fake sleepers")


func _the_round_escalates() -> void:
	var early := _playing("standard")
	var early_snores := _average_snore(early)
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.9
	var late_snores := _average_snore(late)
	_check(late_snores < early_snores * 0.7, "snoring spells get shorter and less even later (%.2f -> %.2f)" % [early_snores, late_snores])
	var fakes := 0
	for row in 20:
		early._plan_row()
		fakes += early.guests.filter(func(g: Dictionary) -> bool: return bool(g.fake)).size()
	_check(fakes == 0, "nobody fakes sleep early on")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "light", "peekers"], "three variants are declared")
	var light := _playing("light")
	var standard := _playing("standard")
	_check(_average_snore(light) < _average_snore(standard) * 0.85, "light sleepers snore in shorter spells")
	var helped := _playing("standard", true)
	_check(helped.window(Game.REACT) > Game.REACT * 1.3, "assist gives a longer heartbeat to freeze")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "light", "peekers"]:
		var gold := _play(session, variant_id, false, 0.1)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a quick sneak earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.45)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow sneak still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0)
	_check(not idle.success and idle.score == 0, "never moving earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.1)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("quiet steps scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses: the sneak creeps while the
## guest they are near (or about to reach) is snoring and freezes `react`
## seconds after that guest stirs; a negative `react` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, react: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-091", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var held := false
	var stirred_at := -1.0
	while not session.ended and game.stage == "play":
		if react >= 0.0:
			var near := game.guest_at(game.walker)
			var ahead := game.guest_at(game.walker + 0.03)
			var calm := true
			for index: int in [near, ahead]:
				if index >= 0 and game.guest_state(index) != "snore":
					calm = false
			if calm:
				stirred_at = -1.0
			elif stirred_at < 0.0:
				stirred_at = game.clock
			var want := not game.pillowed() and (calm or game.clock - stirred_at < react)
			if want != held:
				_session_key(session, KEY_RIGHT, want)
				held = want
		session._process(STEP)
	if held:
		_session_key(session, KEY_RIGHT, false)
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


func _snoring_always(game: Game) -> void:
	for guest: Dictionary in game.guests:
		guest.cycle = [[game.clock - 1.0, game.clock + 999.0, "snore"]]
		guest.peeks = []


func _quiet_at(game: Game, index: int, at: float) -> void:
	_snoring_always(game)
	game.guests[index].cycle = [[game.clock - 1.0, at, "snore"], [at, at + 3.0, "quiet"], [at + 3.0, at + 999.0, "snore"]]


func _average_snore(game: Game) -> float:
	var total := 0.0
	var count := 0
	for row in 10:
		for spell: Array in game._cycle(game.clock, true):
			if str(spell[2]) == "snore" and float(spell[0]) < game.clock + 10.0:
				total += float(spell[1]) - float(spell[0])
				count += 1
	return total / maxf(1.0, count)


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
