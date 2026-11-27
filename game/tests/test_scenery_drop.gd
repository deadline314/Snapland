extends SceneTree
## 舞台換景 rules: calls, pulls, quick-pull points, wrong cloths and boos, double
## calls, slips of the tongue, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/scenery_drop_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0
const KEY_FOR := {"moon": KEY_UP, "forest": KEY_LEFT, "castle": KEY_RIGHT, "sea": KEY_DOWN}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_the_called_cloth_comes_down()
	_wrong_cloths_crash_and_slow_ones_get_booed()
	_doubles_and_slips()
	_it_gets_faster()
	_variants_change_the_calls()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: scenery drop calls, pulls, quick points, crashes, paper actor, boos, doubles, slips, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [200, 550, 900] and game.hanging.is_empty(), "a round opens on a bare stage with its medal lines declared")
	_advance(game, 0.6)
	_check(not game.cue.is_empty() and game.cue.shouted == ["forest"], "during the countdown the ringmaster shouts the forest")
	_pull(game, "moon")
	_advance(game, 1.0)
	_check(game.cue.is_empty() and game.hanging.size() == 1 and game.hanging[0].scene == "forest" and game.score == 0 and game.crashes == 0,
		"and it comes down by itself; presses do nothing yet")
	_advance(game, Base.READY_SECONDS)
	_check(game.stage == "play" and game.phase == "call" and game.cue.shouted[0] != "forest", "play opens with a call for a different scene")


func _the_called_cloth_comes_down() -> void:
	var game := _calling("standard")
	var scene: String = game.cue.shouted[0]
	_pull(game, scene)
	_check(game.phase == "wait" and game.hanging.size() == 1 and game.hanging[0].scene == scene and game.hanging[0].slot == "full"
		and game.score >= Game.POINTS + Game.SPEED_BONUS - 1 and game.streak == 1, "pulling the called cloth at once lowers it for nearly full points (%d)" % game.score)
	_check(game.lifting.size() == 1 and game.lifting[0].scene == "forest", "the cloth that hung before flies back up")
	var slow := _calling("standard")
	_advance(slow, float(slow.cue.length) * 0.85)
	_pull(slow, str(slow.cue.shouted[0]))
	_check(slow.score > 0 and slow.score < game.score - 5, "a late pull is worth less (%d against %d)" % [slow.score, game.score])
	_advance(game, Game.GAP_EARLY + 0.05)
	_check(game.phase == "call" and game.cue.shouted[0] != scene, "the next call follows after a short pause and asks for another scene")
	var before := game.score
	_pull(game, str(game.cue.shouted[0]))
	_check(game.score - before >= Game.POINTS + Game.STREAK_BONUS, "calls in a row add a streak bonus")


func _wrong_cloths_crash_and_slow_ones_get_booed() -> void:
	var game := _calling("standard")
	var wrong := _other(game.cue.shouted)
	_pull(game, wrong)
	_check(game.phase == "crash" and game.crash_scene == wrong and game.crashes == 1 and game.mistakes == 0 and game.fail_at >= 0.0
		and game.hanging.is_empty() and game.streak == 0, "a wrong cloth crashes on the actor; the first crash is free")
	_pull(game, "moon")
	_check(game.crashes == 1, "nothing can be pulled while he peels himself off the floor")
	_advance(game, Game.CRASH_SECONDS + Game.GAP_EARLY + 0.1)
	_check(game.phase == "call", "then the show goes on with a new call")
	_pull(game, _other(game.cue.shouted))
	_check(game.crashes == 2 and game.mistakes == 1, "later crashes are mistakes")
	var idle := _calling("standard")
	_advance(idle, float(idle.cue.length) + 0.05)
	_check(idle.phase == "boo" and idle.boos == 1 and idle.mistakes == 1 and idle.score == 0, "waiting too long gets booed")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.4)
	_check(helped.call_window() > Game.WINDOW_EARLY * 1.4, "assist gives longer to answer")


func _doubles_and_slips() -> void:
	var game := _calling("standard")
	game.cue = {"scenes": ["moon", "sea"], "shouted": ["moon", "sea"], "slip": "", "fixed_at": game.clock, "at": game.clock, "until": game.clock + 3.0, "length": 3.0}
	_pull(game, "sea")
	_check(game.phase == "call" and game.hanging.size() == 1 and game.hanging[0].slot == "left" and game.score > 0, "the first of two called cloths takes the left half")
	_pull(game, "sea")
	_check(game.phase == "call" and game.crashes == 0, "pulling it again does nothing")
	_pull(game, "moon")
	_check(game.phase == "wait" and game.hanging.size() == 2 and game.hanging[1].slot == "right" and game.streak == 1, "the second takes the right half and settles the call")
	var fooled := _calling("standard")
	fooled.cue = {"scenes": ["castle"], "shouted": ["castle"], "slip": "forest", "fixed_at": fooled.clock + Game.SLIP_SECONDS, "at": fooled.clock, "until": fooled.clock + 3.0, "length": 3.0}
	_pull(fooled, "forest")
	_check(fooled.phase == "crash" and fooled.crash_scene == "forest", "pulling the slip before he corrects himself drops it on the actor")
	var patient := _calling("standard")
	patient.cue = {"scenes": ["castle"], "shouted": ["castle"], "slip": "forest", "fixed_at": patient.clock + Game.SLIP_SECONDS, "at": patient.clock, "until": patient.clock + 3.0, "length": 3.0}
	_advance(patient, Game.SLIP_SECONDS + 0.05)
	_pull(patient, "castle")
	_check(patient.phase == "wait" and patient.hanging[0].scene == "castle", "waiting for the correction and pulling the right one works")


func _it_gets_faster() -> void:
	var game := _calling("standard")
	var early := game.call_window()
	var early_gap := game.gap()
	var calls := {"double": 0, "slip": 0, "early_double": 0, "early_slip": 0}
	var seen := {}
	while game.stage == "play":
		if game.phase == "call" and not seen.has(game.cue.at):
			seen[game.cue.at] = true
			if game.cue.shouted.size() == 2:
				calls.double += 1
				calls.early_double += int(game.heat() < 0.25)
			if not str(game.cue.slip).is_empty():
				calls.slip += 1
				calls.early_slip += int(game.heat() < 0.25)
			# Answer instantly so the round runs through as many calls as it can.
			if str(game.cue.slip).is_empty():
				for scene: String in (game.cue.shouted as Array).duplicate():
					_pull(game, scene)
		if game.phase == "call" and not str(game.cue.slip).is_empty() and game.clock >= float(game.cue.fixed_at):
			_pull(game, str(game.cue.shouted[0]))
		game.step(STEP)
	_check(game.call_window() < early * 0.55 and game.gap() < early_gap * 0.5, "calls come faster and must be answered sooner")
	_check(calls.double > 0 and calls.slip > 0 and calls.early_double == 0 and calls.early_slip == 0, "double calls and slips turn up, but not in the opening seconds (%s)" % calls)
	_check(seen.size() >= 18, "a quick player sees plenty of calls in a round (%d)" % seen.size())


func _variants_change_the_calls() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "doubles", "slips"], "three variants are declared")
	var counts := {}
	for variant_id: String in ids:
		var tally := {"double": 0, "slip": 0}
		for attempt in 4:
			var game := _calling(variant_id, attempt * 7)
			var seen := {}
			while game.stage == "play":
				if game.phase == "call" and not seen.has(game.cue.at):
					seen[game.cue.at] = true
					tally.double += int(game.cue.shouted.size() == 2)
					tally.slip += int(not str(game.cue.slip).is_empty())
				game.step(STEP)
		counts[variant_id] = tally
	_check(counts.doubles.double > counts.standard.double and counts.doubles.double > counts.doubles.slip, "the double variant is mostly double calls (%s)" % counts)
	_check(counts.slips.slip > counts.standard.slip and counts.slips.slip > counts.slips.double, "the slip variant is mostly slips (%s)" % counts)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "doubles", "slips"]:
		# Gold: answers a little over half a second after each call and waits out every slip.
		var gold := _play(session, variant_id, false, 0.6, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a quick, careful stagehand earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: slow to react, falls for every slip and pulls a wrong cloth now and then.
	var bronze := _play(session, "standard", false, 1.2, 0.25)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a slow, clumsy stagehand still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, 99.0, 0.0)
	_check(not idle.success and idle.score == 0 and idle.mistakes > 5, "never pulling a rope earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.6, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("scenery drop scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session input: answer each call `delay` seconds
## after it can be answered; with `clumsy` > 0, also pull the slip straight away
## and pull a wrong cloth on that share of calls.
func _play(session: Session, variant_id: String, assisted: bool, delay: float, clumsy: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-051", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var luck := RandomNumberGenerator.new()
	luck.seed = 5
	var handled := {}
	while not session.ended and game.stage == "play":
		if game.phase == "call" and not handled.has(game.cue.at):
			var slip := str(game.cue.slip)
			if clumsy > 0.0 and not slip.is_empty() and game.clock - float(game.cue.at) >= delay * 0.5:
				handled[game.cue.at] = true
				_session_pull(session, slip)
			else:
				var ready_at := float(game.cue.fixed_at) if clumsy <= 0.0 else float(game.cue.at)
				if game.clock - ready_at >= delay:
					handled[game.cue.at] = true
					if clumsy > 0.0 and luck.randf() < clumsy:
						_session_pull(session, _other(game.cue.shouted))
					else:
						for scene: String in game.cue.shouted.duplicate():
							_session_pull(session, scene)
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


func _session_pull(session: Session, scene: String) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_FOR[scene]
		key.pressed = pressed
		session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


func _other(shouted: Array) -> String:
	for scene: String in ["moon", "forest", "castle", "sea"]:
		if not shouted.has(scene):
			return scene
	return ""


func _round(variant_id: String, assisted: bool, salt := 0) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id, salt)
	game.reset(assisted, "noon")
	return game


## A round of the variant in play, with its first call up.
func _calling(variant_id: String, salt := 0) -> Game:
	var game := _round(variant_id, false, salt)
	_advance(game, Base.READY_SECONDS + 0.35)
	return game


## First seed (from `salt` on) whose round uses the named variant.
func _seed_for(variant_id: String, salt := 0) -> int:
	for round_seed in range(salt, salt + 200):
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


func _pull(game: Base, scene: String) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_FOR[scene]
		key.pressed = pressed
		game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
