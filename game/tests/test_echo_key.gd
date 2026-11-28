extends SceneTree
## 回聲鑰匙 rules: the countdown demo, opening rings, the dead-on bonus, doors,
## the broom cupboard, reversing and wobbling rings, escalation, variants,
## assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/echo_key_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_ring()
	_untouched_rounds_never_score()
	_opening_rings_and_doors()
	_a_wrong_turn_opens_the_broom_cupboard()
	_reversing_and_wobbling_rings()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: echo key demo, rings, dead-on bonus, doors, broom cupboard, reversing and wobbling rings, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_ring() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [180, 500, 680] and game.rings.size() == Game.RINGS_FIRST, "a round opens on a door with three rings")
	var opened := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		opened = opened or game.current > 0
	_check(opened and game.score == 0 and game.brooms == 0, "the countdown opens the first ring by itself and scores nothing")
	_advance(game, 0.1)
	var fair := true
	for ring: Dictionary in game.rings:
		fair = fair and not bool(ring.open) and absf(wrapf(float(ring.angle), -180.0, 180.0)) >= 100.0
	_check(game.stage == "play" and game.current == 0 and fair, "play starts on a fresh lock with every notch well away from the key")


func _opening_rings_and_doors() -> void:
	var game := _playing("standard")
	var ring: Dictionary = game.rings[0]
	_press_at(game, 0.0)
	_check(bool(ring.open) and game.current == 1 and game.dead_on == 1 and game.score >= Game.RING_POINTS + Game.DEAD_ON_POINTS, "pressing as the notch passes under the key opens the ring with the dead-on bonus")
	var loose := _playing("standard")
	_press_at(loose, Game.HIT_SECONDS * 0.8)
	_check(loose.current == 1 and loose.dead_on == 0 and loose.score == Game.RING_POINTS + Game.STREAK_POINTS, "a press a little early still opens it, without the bonus")
	var late := _playing("standard")
	_press_at(late, -Game.HIT_SECONDS * 0.8)
	_check(late.current == 1 and late.brooms == 0, "and a little late too")
	var door := _playing("standard")
	for index in door.rings.size():
		_press_at(door, 0.0)
	_check(door.doors_opened == 1 and door.busy() and door.score >= Game.RINGS_FIRST * (Game.RING_POINTS + Game.DEAD_ON_POINTS) + Game.DOOR_POINTS, "opening every ring swings the door open for a bonus")
	_advance(door, Game.OPEN_SECONDS + 0.05)
	_check(door.door == 2 and door.current == 0 and door.rings.all(func(ring: Dictionary) -> bool: return not bool(ring.open)), "then the next door comes with a fresh lock")
	var pad := _playing("standard")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.brooms == 1, "the gamepad A button turns the key too (here too early, into the cupboard)")


func _a_wrong_turn_opens_the_broom_cupboard() -> void:
	var game := _playing("standard")
	_press_at(game, 0.0)
	var notch := float(game.rings[1].angle)
	_tap(game, KEY_SPACE)
	_check(game.brooms == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.busy() and not game.snapshot().word_good,
		"pressing while the notch is elsewhere bursts the broom cupboard open; the first time is a free look")
	_check(game.current == 0 and game.rings.all(func(ring: Dictionary) -> bool: return not bool(ring.open)) and game.streak == 0, "and the lock jams shut to start over")
	var angle := float(game.rings[0].angle)
	_tap(game, KEY_SPACE)
	_advance(game, 0.6)
	_check(game.brooms == 1 and float(game.rings[0].angle) == angle, "nothing turns, and no press counts, while the brooms are swept up")
	_advance(game, Game.BROOM_SECONDS)
	_tap(game, KEY_SPACE)
	_check(game.brooms == 2 and game.mistakes == 1, "a second broom cupboard counts as a mistake")
	var mash := _playing("standard")
	for tick in int(10.0 / STEP):
		if tick % 8 == 0:
			_tap(mash, KEY_SPACE)
		mash.step(STEP)
	_check(mash.brooms >= 3 and mash.score < 100, "jamming the key at random buries the traveller (brooms %d, score %d)" % [mash.brooms, mash.score])
	_check(notch != 0.0, "the next ring still had its notch away from the key")


func _reversing_and_wobbling_rings() -> void:
	var game := _playing("reverse")
	game.play_time = game.round_seconds * 0.5
	game._fresh_rings()
	var turning := game.rings.filter(func(ring: Dictionary) -> bool: return float(ring.reverse_at) > 0.0)
	_check(not turning.is_empty(), "on the reversing locks some rings will turn about")
	var ring: Dictionary = turning[0]
	var before := int(ring.direction)
	_advance(game, float(ring.reverse_at) - game.clock + 0.02)
	_check(int(ring.direction) == -before, "a ring turns about at its time")
	var early := _playing("standard")
	early._fresh_rings()
	_check(early.rings.all(func(ring: Dictionary) -> bool: return float(ring.reverse_at) < 0.0) and is_equal_approx(early.ring_speed(early.rings[0]), early.spin_speed()),
		"early standard locks neither reverse nor wobble")
	var wobble := _playing("wobble")
	wobble.play_time = wobble.round_seconds * 0.3
	var speeds: Array[float] = []
	for sample in 30:
		wobble.clock += 0.1
		speeds.append(wobble.ring_speed(wobble.rings[0]))
	_check(speeds.max() > speeds.min() * 2.0, "a tipsy lock speeds up and slows down")
	var late := _playing("standard")
	var first := late.spin_speed()
	late.play_time = late.round_seconds * 0.95
	late._fresh_rings()
	_check(late.spin_speed() > first * 2.2 and late.rings.size() == Game.RINGS_LAST, "late doors spin much faster and have five rings")
	var spread := _playing("standard")
	spread.play_time = spread.round_seconds * 0.7
	var reversing := 0
	for door in 40:
		spread._fresh_rings()
		reversing += spread.rings.filter(func(ring: Dictionary) -> bool: return float(ring.reverse_at) > 0.0).size()
	_check(reversing > 20, "late standard locks reverse now and then too")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "reverse", "wobble"], "three variants are declared")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.spin_speed() < standard.spin_speed() * 0.8 and helped.window(Game.HIT_SECONDS) > Game.HIT_SECONDS * 1.3, "assist slows the rings and widens the window")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "reverse", "wobble"]:
		var gold := _play(session, variant_id, false, 0.012)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady hand earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.075)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a shaky hand still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0)
	_check(not idle.success and idle.score == 0, "never turning the key earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.012)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("echo key scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses: for each ring the player
## presses when the notch is `error` seconds from the key, with `error` drawn
## within ±`wobble`; a negative `wobble` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, wobble: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-087", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 9
	var aimed := ""
	var error := 0.0
	while not session.ended and game.stage == "play":
		if wobble >= 0.0 and not game.busy() and game.current < game.rings.size():
			var key := "%d:%d" % [game.door, game.current]
			if key != aimed:
				aimed = key
				error = aim.randf_range(-wobble, wobble)
			var until: float = game.time_to_top(game.rings[game.current])
			if until <= error and until > -0.5:
				_session_key(session, KEY_SPACE, true)
				_session_key(session, KEY_SPACE, false)
				aimed = ""
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


## Step until the working ring's notch is `before` seconds from the key, press.
func _press_at(game: Game, before: float) -> void:
	for tick in 2400:
		if not game.busy() and game.time_to_top(game.rings[game.current]) <= before + STEP * 0.5 and game.time_to_top(game.rings[game.current]) > -0.5:
			break
		game.step(STEP)
	_tap(game, KEY_SPACE)


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
