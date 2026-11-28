extends SceneTree
## 謝幕回旋 rules: beats, alternating spins and the ribbon's size, tempo
## changes, misses and the tangle, the drum roll and the bow, escalation,
## variants and full simulated rounds (an untouched round scores nothing).

const Game = preload("res://game/minigames/arcade/ribbon_spin_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_spins_on_the_beat()
	_misses_and_the_tangle()
	_the_roll_and_the_bow()
	_tempo_changes_and_escalation()
	_variants_change_the_drummer()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: ribbon spin beats, alternating spins, circle size, tempo changes, misses, tangle, roll and bow, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [300, 1100, 1600], "a round opens with its medal lines declared")
	_tap(game, KEY_LEFT)
	_advance(game, 2.0)
	_check(game.size > 0 and game.score == 0, "the countdown spins on the drum by itself; presses do nothing yet")
	_advance(game, Base.READY_SECONDS)
	_check(game.stage == "play" and game.size == 0 and game.score == 0, "play starts with the ribbon furled and nothing scored")


func _spins_on_the_beat() -> void:
	var game := _dancing("standard")
	_to_beat(game, 0.0)
	_tap(game, KEY_LEFT)
	_check(game.spins == 1 and game.size == 1 and game.expect == &"right" and game.score == Game.SPIN_POINTS + Game.SIZE_POINTS + Game.PERFECT_BONUS,
		"a spin right on the beat widens the ribbon and wants the other side next (%d)" % game.score)
	_to_beat(game, 0.09)
	_tap(game, KEY_RIGHT)
	_check(game.spins == 2 and game.size == 2, "a little late still counts")
	var before := game.score
	_to_beat(game, 0.0)
	_tap(game, KEY_LEFT)
	_check(game.score - before == Game.SPIN_POINTS + Game.SIZE_POINTS * 3 + Game.PERFECT_BONUS, "a bigger circle is worth more")


func _misses_and_the_tangle() -> void:
	var game := _dancing("standard")
	_to_beat(game, 0.0)
	_tap(game, KEY_LEFT)
	_to_beat(game, 0.0)
	_tap(game, KEY_LEFT)
	_check(game.bad_run == 1 and game.size == 0 and game.phase == "dance", "the same side twice is one bad beat and the ribbon droops")
	_to_beat(game, 0.0)
	_tap(game, KEY_RIGHT)
	_check(game.bad_run == 0 and game.spins == 2, "getting back on the beat recovers")
	_to_beat(game, -0.3)
	_tap(game, KEY_LEFT)
	_to_beat(game, -0.3)
	_tap(game, KEY_LEFT)
	_check(game.phase == "tangle" and game.tangles == 1 and game.mistakes == 0 and game.fail_at >= 0.0, "two bad beats in a row tangle the hero up; the first time is free")
	_tap(game, KEY_RIGHT)
	_check(game.spins == 2, "nothing spins while wrapped up")
	_advance(game, Game.TANGLE_SECONDS + 0.8)
	_check(game.phase == "dance", "then a new routine starts")
	_advance(game, game.beat * 3.0)
	_check(game.tangles == 2 and game.mistakes == 1, "missed beats tangle too, and later tangles are mistakes")
	var idle := _playing("standard")
	_advance(idle, idle.round_seconds + 0.1)
	_check(idle.score == 0 and idle.tangles > 3, "an untouched round scores nothing (%d tangles)" % idle.tangles)
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.window(Game.WINDOW) > Game.WINDOW * 1.4, "assist widens the beat window")


func _the_roll_and_the_bow() -> void:
	var game := _rolling("standard")
	_advance(game, game.crash_at - game.clock)
	var before := game.score
	_tap(game, KEY_SPACE)
	_check(game.phase == "bow" and game.score - before >= Game.BOW_PERFECT_POINTS, "stopping right on the crash is a perfect bow (+%d)" % (game.score - before))
	var early := _rolling("standard")
	early.score = 50
	_tap(early, KEY_SPACE)
	_check(early.phase == "bow" and early.score == 50 - Game.BOW_PENALTY, "stopping too early costs points")
	var late := _rolling("standard")
	late.score = 50
	_advance(late, late.crash_at - late.clock + Game.LATE_BOW + 0.05)
	_check(late.phase == "bow" and late.score == 50 - Game.BOW_PENALTY, "not stopping costs points too")
	var arrows := _rolling("standard")
	_tap(arrows, KEY_LEFT)
	_check(arrows.phase == "roll", "arrows do nothing during the drum roll")


func _tempo_changes_and_escalation() -> void:
	var game := _playing("swing")
	var first := -1.0
	var changes := 0
	var beats_early: Array[float] = []
	var beats_late: Array[float] = []
	var seen := 0
	while game.stage == "play":
		if game.phase == "dance" and game.routines != seen:
			seen = game.routines
			if game.heat() < 0.3:
				beats_early.append(game.beat)
			elif game.heat() > 0.6:
				beats_late.append(game.beat)
			if not game.tempo_change.is_empty():
				changes += 1
		if game.phase == "roll":
			game._bow_now()
		game.step(STEP * 4.0)
	_check(changes >= 2, "the swing drummer changes tempo in several routines (%d)" % changes)
	var mean := func(values: Array[float]) -> float:
		var total := 0.0
		for value in values:
			total += value
		return total / maxf(1.0, values.size())
	_check(beats_early.size() > 0 and beats_late.size() > 0 and mean.call(beats_late) < mean.call(beats_early) * 0.8, "the beat gets faster (%s vs %s)" % [beats_early, beats_late])
	var changed := _dancing("standard")
	changed.tempo_change = {"at": changed.next_beat + changed.beat * 2.0, "length": changed.beat * 0.75, "faster": true}
	var old := changed.beat
	for beat in 3:
		_to_beat(changed, 0.0)
		_tap(changed, KEY_LEFT if beat % 2 == 0 else KEY_RIGHT)
	_check(absf(changed.beat - old * 0.75) < 0.001 and changed.bad_run == 0, "after the cue the drummer plays faster and following it keeps the run")


func _variants_change_the_drummer() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "swing", "fake"], "three variants are declared")
	var fakes := {}
	for variant_id: String in ["standard", "fake"]:
		var game := _playing(variant_id)
		var count := 0
		while game.stage == "play":
			if game.phase == "roll" and game.fake_crash_at > 0.0 and game.fake_crash_at > game.clock - 0.01:
				count += 1
				game._bow_now()
			elif game.phase == "roll":
				game._bow_now()
			elif game.phase == "dance" and game.clock >= game.next_beat - 0.001 and not game.answered:
				game._spin(game.expect if game.expect != &"" else &"left")
			game.step(STEP * 2.0)
		fakes[variant_id] = count
	_check(fakes.fake > fakes.standard and fakes.standard == 0, "false endings only come in the fake variant (%s)" % fakes)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "swing", "fake"]:
		# Gold: presses within 0.02 s of every beat and bows right on the crash.
		var gold := _play(session, variant_id, false, 0.02, 0.0, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady dancer earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: 0.1 s late on every beat, slips on one beat in seven and bows late.
	var bronze := _play(session, "standard", false, 0.1, 0.25, 7)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a shaky dancer still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 0.02, 0.0, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("ribbon spin scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: press `late` seconds after each
## beat (alternating), bow `bow_late` seconds after the crash, and every
## `slip`-th beat press the wrong side.
func _play(session: Session, variant_id: String, assisted: bool, late: float, bow_late: float, slip: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-060", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var pressed_for := -1.0
	var count := 0
	var bowed_for := -1.0
	while not session.ended and game.stage == "play":
		if game.phase == "dance" and game.next_beat != pressed_for and game.clock >= game.next_beat + late:
			pressed_for = game.next_beat
			count += 1
			var side := game.expect if game.expect != &"" else &"left"
			if slip > 0 and count % slip == 0:
				side = &"left" if side == &"right" else &"right"
			_session_tap(session, KEY_LEFT if side == &"left" else KEY_RIGHT)
		if game.phase == "roll" and game.crash_at != bowed_for and game.clock >= game.crash_at + bow_late:
			bowed_for = game.crash_at
			_session_tap(session, KEY_SPACE)
		_run_session(session, STEP)
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


## Step the game until `offset` seconds after its next beat.
func _to_beat(game: Game, offset: float) -> void:
	var target := game.next_beat + offset
	if game.answered:
		target = game.next_beat + game.beat + offset
	_advance(game, maxf(0.0, target - game.clock))


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
	return game


## A round in the middle of a routine with no tempo change pending.
func _dancing(variant_id: String) -> Game:
	var game := _playing(variant_id)
	_advance(game, 0.3)
	game.tempo_change = {}
	game.beats_left = 40
	return game


## A round in its drum roll, just after the roll started.
func _rolling(variant_id: String) -> Game:
	var game := _dancing(variant_id)
	game._roll()
	game.fake_crash_at = -99.0
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
