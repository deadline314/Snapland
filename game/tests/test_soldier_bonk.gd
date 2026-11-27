extends SceneTree
## 敲敲玩具兵 rules: the demo bonk, doors and arrows, scoring, escapes, whiffs, the
## cat and the snatched mallet, pairs, feints, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/soldier_bonk_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const KEYS: Array[int] = [KEY_UP, KEY_LEFT, KEY_RIGHT, KEY_DOWN]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_bonk()
	_bonking_soldiers()
	_misses_escapes_and_whiffs()
	_the_cat_takes_the_mallet()
	_the_round_escalates()
	_variants_change_the_drill()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: soldier bonk doors, arrows, scoring, escapes, whiffs, cat snatch, pairs, feints, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_bonk() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.doors.size() == 4 and game.thresholds == [350, 750, 1100], "a round opens with four shut doors and its medal lines declared")
	var popped := false
	var bonked := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_LEFT)
		game.step(STEP)
		popped = popped or game.doors[0].kind == "soldier"
		bonked = bonked or game.doors[0].kind == "bonked"
	_check(popped and bonked and game.swing_door == 0 and game.score == 0 and game.whiffs == 0,
		"the countdown pops a soldier at the top door and bonks it by itself; arrows do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.doors.all(func(door: Dictionary) -> bool: return door.kind == "shut"), "play starts with every door shut")


func _bonking_soldiers() -> void:
	var game := _playing("standard")
	_hold_off(game)
	for index in 4:
		game._open(index, "soldier", 1.0)
		_advance(game, 0.1)
		_tap(game, KEYS[index])
		_check(game.doors[index].kind == "bonked" and game.swing_door == index, "the %s arrow bonks the soldier in its own door" % Game.DOORS[index])
	_check(game.bonks == 4 and game.score == 15 + 17 + 19 + 21 and game.streak == 4, "quick bonks score ten, five for speed and two more per bonk in a row (%d)" % game.score)
	game._open(1, "soldier", 1.0)
	_advance(game, 0.5)
	var before := game.score
	_tap(game, KEY_A)
	_check(game.score - before == Game.BONK_POINTS + Game.STREAK_POINTS * 4, "a slower bonk has no speed bonus; WASD works like the arrows")
	_advance(game, Game.BONK_SECONDS + 0.02)
	_check(game.doors[1].kind == "shut", "a bonked soldier goes back in and the door shuts")
	var pad := _playing("standard")
	_hold_off(pad)
	pad._open(3, "soldier", 1.0)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_DOWN
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.doors[3].kind == "bonked", "the gamepad d-pad bonks too")


func _misses_escapes_and_whiffs() -> void:
	var game := _playing("standard")
	_hold_off(game)
	game.streak = 3
	game._open(2, "soldier", 0.5)
	_advance(game, 0.52)
	_check(game.doors[2].kind == "escaped" and game.escapes == 1 and game.streak == 0 and game.mistakes == 0 and not game.snapshot().word_good,
		"a soldier left out too long escapes with a raspberry and ends the streak")
	_tap(game, KEY_RIGHT)
	_check(game.whiffs == 1 and game.score == 0, "bonking an empty door is a whiff, and the score never goes below zero")
	game.score = 20
	_advance(game, Game.RECOIL_SECONDS + 0.02)
	_tap(game, KEY_RIGHT)
	_check(game.whiffs == 2 and game.score == 20 - Game.WHIFF_POINTS, "a whiff costs a few points")
	game.score = 0
	game._open(0, "soldier", 1.0)
	_tap(game, KEY_UP)
	_check(game.doors[0].kind == "soldier", "right after a whiff the mallet is still bouncing")
	_advance(game, Game.RECOIL_SECONDS + 0.02)
	_tap(game, KEY_UP)
	_check(game.doors[0].kind == "bonked", "then it swings again")
	game._open(1, "feint", Game.FEINT_SECONDS)
	_advance(game, Game.RECOIL_SECONDS + 0.02)
	game._open(1, "feint", Game.FEINT_SECONDS)
	_tap(game, KEY_LEFT)
	_check(game.whiffs == 3 and game.doors[1].kind == "feint", "a feinting soldier ducks the mallet")


func _the_cat_takes_the_mallet() -> void:
	var game := _playing("standard")
	_hold_off(game)
	game._open(1, "cat", Game.CAT_SECONDS)
	_advance(game, 0.2)
	_check(game.doors[1].kind == "cat", "a sleepy cat dozes in a doorway")
	_tap(game, KEY_LEFT)
	_check(not game.has_mallet() and game.snatch_door == 1 and game.cat_hits == 1 and game.mistakes == 0 and game.doors[1].kind == "snatch"
		and not game.snapshot().word_good, "bonk the cat and it snatches the mallet; the first time is a free lesson")
	game._open(0, "soldier", 3.0)
	_tap(game, KEY_UP)
	_check(game.doors[0].kind == "soldier" and game.score == 0, "without the mallet nothing can be bonked")
	_advance(game, Game.SNATCH_SECONDS + 0.05)
	_check(game.has_mallet() and game.snatch_door == -1, "the cat brings it back after a while")
	_tap(game, KEY_UP)
	_check(game.doors[0].kind == "bonked", "and bonking resumes")
	game._open(2, "cat", Game.CAT_SECONDS)
	_tap(game, KEY_RIGHT)
	_check(game.cat_hits == 2 and game.mistakes == 1, "later cats count as mistakes")
	var left := _playing("standard")
	_hold_off(left)
	left._open(3, "cat", Game.CAT_SECONDS)
	_advance(left, Game.CAT_SECONDS + 0.02)
	_check(left.doors[3].kind == "shut" and left.mistakes == 0 and left.escapes == 0, "a cat left alone just wanders off")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var pops_early := 0
	var pops_late := 0
	var first_pair := -1.0
	var first_feint := -1.0
	var cats := 0
	var ups_early: Array[float] = []
	var ups_late: Array[float] = []
	var was: Array = ["shut", "shut", "shut", "shut"]
	while game.stage == "play":
		game.step(STEP)
		var fresh := 0
		for index in 4:
			var kind := str(game.doors[index].kind)
			if kind != was[index] and kind in ["soldier", "feint", "cat"]:
				fresh += 1
				if game.heat() < 0.3:
					pops_early += 1
				elif game.heat() > 0.7:
					pops_late += 1
				if kind == "soldier":
					var up := float(game.doors[index].until) - float(game.doors[index].at)
					if game.heat() < 0.3:
						ups_early.append(up)
					else:
						ups_late.append(up)
				if kind == "feint" and first_feint < 0.0:
					first_feint = game.heat()
				cats += int(kind == "cat")
			was[index] = kind
		if fresh >= 2 and first_pair < 0.0:
			first_pair = game.heat()
	_check(pops_late > pops_early * 1.5, "doors pop faster later in the round (%d to %d)" % [pops_early, pops_late])
	_check(ups_late.min() < ups_early.min() * 0.75, "soldiers stay out for less time later")
	_check(first_pair >= Game.PAIR_HEAT and first_feint >= Game.FEINT_HEAT and cats >= 2, "pairs and feints only join later, cats turn up (%.2f, %.2f, %d)" % [first_pair, first_feint, cats])


func _variants_change_the_drill() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "double", "catnap", "drill"], "four variants are declared")
	var pairs := _playing("double")
	var both := false
	for tick in 240:
		pairs.step(STEP)
		var open := pairs.doors.filter(func(door: Dictionary) -> bool: return door.kind in ["soldier", "cat"]).size()
		both = both or open >= 2
	_check(both, "the double drill opens two doors at once from the start")
	var drill := _playing("drill")
	var standard := _playing("standard")
	_check(drill.up_seconds() < standard.up_seconds() * 0.9, "the quick-march drill keeps soldiers out for less time")
	var helped := _playing("standard", true)
	_check(helped.up_seconds() > standard.up_seconds() * 1.4, "assist keeps soldiers out longer")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "double", "catnap", "drill"]:
		var gold := _play(session, variant_id, false, 0.22, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "quick, careful bonking earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.45, 0.3, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow bonker who misses some still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "standard", false, 0.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0] and masher.mistakes > 0, "hammering every arrow earns nothing (score %d)" % masher.score)
	var helped := _play(session, "standard", true, 0.22, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("soldier bonk scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: bonk each soldier `delay` seconds
## after it pops, skip a share `skip` of them, never touch cats or feints;
## `mash` cycles through every arrow as fast as the mallet allows instead.
func _play(session: Session, variant_id: String, assisted: bool, delay: float, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-070", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 11
	var skipped: Dictionary = {}
	var turn := 0
	while not session.ended and game.stage == "play":
		var press := -1
		if mash:
			turn = (turn + 1) % 4
			press = turn
		else:
			for index in 4:
				var door: Dictionary = game.doors[index]
				if door.kind != "soldier" or game.clock - float(door.at) < delay:
					continue
				var key := "%d:%.3f" % [index, float(door.at)]
				if not skipped.has(key):
					skipped[key] = decide.randf() < skip
				if not skipped[key]:
					press = index
					break
		if press >= 0:
			_session_key(session, KEYS[press], true)
			session._process(STEP)
			_session_key(session, KEYS[press], false)
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


## Stop the round's own pops so a check can open doors by hand.
func _hold_off(game: Game) -> void:
	game._next_pop = 999.0
	for door in game.doors:
		door.kind = "shut"


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
