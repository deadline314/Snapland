extends SceneTree
## 影偶搭梯 rules: making and turning hand shapes, puppets arriving, passing,
## pairs and mirrored puppets, the barking dog, escalation, variants and full
## simulated rounds (an untouched round scores nothing).

const Game = preload("res://game/minigames/arcade/shadow_puppet_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0
const KEYS := {"bird": KEY_UP, "rabbit": KEY_LEFT, "dog": KEY_RIGHT, "goose": KEY_DOWN}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_shapes_and_turning()
	_puppets_pass_or_bark()
	_it_gets_faster_with_pairs_and_mirrors()
	_variants_change_the_show()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: shadow puppet shapes, turning, puppets, passes, pairs, mirrored, barking dog, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [120, 320, 420] and game.shape == "fist", "a round opens with a plain fist and its medal lines declared")
	_tap(game, KEY_UP)
	_advance(game, 2.2)
	_check(game.shape == "rabbit" and game.score == 0 and game.barks == 0, "the countdown makes a rabbit for the rabbit puppet by itself; presses do nothing yet")
	_advance(game, Base.READY_SECONDS)
	_check(game.stage == "play" and game.shape == "fist" and game.score == 0, "play starts with a fist and nothing scored")


func _shapes_and_turning() -> void:
	var game := _playing("standard")
	_tap(game, KEY_LEFT)
	_check(game.shape == "rabbit" and game.facing == 1, "an arrow makes its shape, facing right")
	_tap(game, KEY_LEFT)
	_check(game.shape == "rabbit" and game.facing == -1, "the same arrow again turns it round")
	_tap(game, KEY_UP)
	_check(game.shape == "bird" and game.facing == 1, "another arrow makes another shape, facing right again")


func _puppets_pass_or_bark() -> void:
	var game := _quiet("standard")
	game.puppets.assign([game._puppet("dog", 1, 0.5)])
	_tap(game, KEY_RIGHT)
	_advance(game, 0.55)
	_check(game.passes == 1 and game.score == Game.POINTS and game.streak == 1, "a matching shadow lets the puppet through")
	game.puppets.assign([game._puppet("goose", -1, 0.5)])
	_tap(game, KEY_DOWN)
	_tap(game, KEY_DOWN)
	_advance(game, 0.55)
	_check(game.passes == 2 and game.score == Game.POINTS * 2 + Game.MIRROR_BONUS + Game.STREAK_BONUS, "a mirrored puppet needs the turned shape and pays a bonus (%d)" % game.score)
	var wrong := _quiet("standard")
	wrong.puppets.assign([wrong._puppet("bird", 1, 0.5)])
	_tap(wrong, KEY_LEFT)
	_advance(wrong, 0.55)
	_check(wrong.phase == "bark" and wrong.shape == "dog" and wrong.facing == -1 and wrong.barks == 1 and wrong.mistakes == 0 and wrong.fail_at >= 0.0,
		"a wrong shape turns into a dog that faces the hero; the first time is free")
	_tap(wrong, KEY_UP)
	_check(wrong.shape == "dog", "the hands can't change while the dog barks")
	_advance(wrong, Game.BARK_SECONDS + 0.05)
	_check(wrong.phase == "show" and wrong.shape == "fist", "then the hands go back to a fist")
	var turned := _quiet("standard")
	turned.puppets.assign([turned._puppet("rabbit", -1, 0.5)])
	_tap(turned, KEY_LEFT)
	_advance(turned, 0.55)
	_check(turned.barks == 1, "the right shape facing the wrong way still barks")
	turned.puppets.assign([turned._puppet("rabbit", 1, Game.BARK_SECONDS + 0.5)])
	_advance(turned, Game.BARK_SECONDS + 0.6)
	_check(turned.barks == 2 and turned.mistakes == 1, "later barks are mistakes")
	var idle := _playing("standard")
	_advance(idle, idle.round_seconds + 0.1)
	_check(idle.score == 0 and idle.barks > 3, "an untouched round scores nothing (%d barks)" % idle.barks)
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	helped.puppets.clear()
	helped._next_puppet = 999.0
	helped.puppets.assign([helped._puppet("bird", 1, 0.3)])
	_advance(helped, 0.35)
	_check(helped.phase == "show" and helped.barks == 0, "with assist a wrong shape gets a moment's grace at the hands")
	_tap(helped, KEY_UP)
	_advance(helped, Game.GRACE_SECONDS)
	_check(helped.passes == 1 and helped.barks == 0, "and fixing it in time still lets the puppet through")


func _it_gets_faster_with_pairs_and_mirrors() -> void:
	var game := _playing("standard")
	var early := game.travel()
	var seen := {}
	var pairs_early := 0
	var pairs_late := 0
	var mirrors := 0
	var mirrors_early := 0
	while game.stage == "play":
		_match(game)
		game.step(STEP)
		var fresh: Array = []
		for puppet: Dictionary in game.puppets:
			if not seen.has(puppet.id):
				seen[puppet.id] = true
				fresh.append(puppet)
				if int(puppet.facing) < 0:
					mirrors += 1
					mirrors_early += int(game.heat() < 0.1)
		if fresh.size() == 2:
			if game.heat() < 0.15:
				pairs_early += 1
			else:
				pairs_late += 1
	_check(game.travel() < early * 0.5, "puppets cross the screen faster and faster")
	_check(pairs_late >= 2 and pairs_early == 0, "pairs come later in the round (%d early, %d late)" % [pairs_early, pairs_late])
	_check(mirrors >= 2 and mirrors_early == 0, "mirrored puppets turn up after the opening (%d)" % mirrors)


func _variants_change_the_show() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "mirror", "rush"], "three variants are declared")
	var tally := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var seen := {}
		var mirrors := 0
		var pairs := 0
		while game.stage == "play":
			_match(game)
			game.step(STEP)
			var fresh := 0
			for puppet: Dictionary in game.puppets:
				if not seen.has(puppet.id):
					seen[puppet.id] = true
					fresh += 1
					mirrors += int(int(puppet.facing) < 0)
			pairs += int(fresh == 2)
		tally[variant_id] = [mirrors, pairs]
	_check(tally.mirror[0] > tally.standard[0], "the mirror night has more mirrored puppets (%s)" % tally)
	_check(tally.rush[1] > tally.standard[1], "the rush sends more pairs (%s)" % tally)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "mirror", "rush"]:
		# Gold: reads each puppet 0.4 s after it appears and sets shape and facing.
		var gold := _play(session, variant_id, false, 0.4, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a quick reader earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: slow to read and forgets to turn the hands for mirrored puppets.
	var bronze := _play(session, "standard", false, 1.2, 1)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a slow reader still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 0.4, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("shadow puppet scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: `read` seconds after the next puppet
## appears, make its shape (and turn it, unless `forgetful` is 1).
func _play(session: Session, variant_id: String, assisted: bool, read: float, forgetful: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-059", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var handled := {}
	while not session.ended and game.stage == "play":
		var next := _next_puppet(game)
		if not next.is_empty() and game.phase == "show" and not handled.has(next.id) and game.clock - float(next.at) >= read:
			var previous := _previous_arrival(game, next)
			if previous < 0.0 or game.clock >= previous:
				handled[next.id] = true
				var want := int(next.facing) if forgetful == 0 else 1
				if game.shape != str(next.shape):
					_session_tap(session, KEYS[str(next.shape)])
				if game.facing != want:
					_session_tap(session, KEYS[str(next.shape)])
		_run_session(session, STEP)
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


## The waiting puppet that arrives first.
func _next_puppet(game: Game) -> Dictionary:
	var best: Dictionary = {}
	for puppet: Dictionary in game.puppets:
		if float(puppet.passed_at) >= 0.0:
			continue
		if best.is_empty() or float(puppet.arrive) < float(best.arrive):
			best = puppet
	return best


## When the puppet ahead of `puppet` (if any) arrives, or -1.
func _previous_arrival(game: Game, puppet: Dictionary) -> float:
	var latest := -1.0
	for other: Dictionary in game.puppets:
		if other != puppet and float(other.passed_at) < 0.0 and float(other.arrive) < float(puppet.arrive):
			latest = maxf(latest, float(other.arrive))
	return latest


## Make the shape of whatever arrives next, directly.
func _match(game: Game) -> void:
	var next := _next_puppet(game)
	if not next.is_empty():
		game.shape = str(next.shape)
		game.facing = int(next.facing)


func _session_tap(session: Session, code: int) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = pressed
		session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
	return game


## A round in play with no puppets of its own coming for a while.
func _quiet(variant_id: String) -> Game:
	var game := _playing(variant_id)
	game.puppets.clear()
	game._next_puppet = 999.0
	return game


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


func _tap(game: Base, code: int) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = pressed
		game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
