extends SceneTree
## 誰是假倒影 rules: instant copies, the three tells, selector, accusations, escalation and full simulated rounds.

const Game = preload("res://game/minigames/arcade/fake_reflection_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_selector_and_poses_share_the_arrows()
	_each_variant_has_its_own_tell()
	_accusations_score_and_resolve()
	_the_round_escalates()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: fake reflection copies, tells, selector, accusations, escalation, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("lag", false)
	_check(game.stage == "ready" and game.mirrors == Game.FIRST_MIRRORS and game.fake >= 0 and game.fake < game.mirrors
		and game.selected == 1 and game.pose == Game.IDLE, "a round opens with three mirrors and the spotlight in the middle")
	var seen: Dictionary = {}
	var fake_was_late := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		seen[game.pose] = true
		fake_was_late = fake_was_late or game.reflection_pose(game.fake) != game.pose
	_check(seen.has(&"up") and seen.has(&"left") and fake_was_late and game.cases_done == 0 and game.score == 0,
		"the hero poses by itself during the countdown, the fake already lags, and presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.pose == Game.IDLE and absf(game.case_at - Base.READY_SECONDS) < 0.05, "play starts from a calm pose and a fresh case clock")


func _selector_and_poses_share_the_arrows() -> void:
	var game := _playing("flip")
	_press(game, KEY_LEFT, true)
	_check(game.selected == 0 and game.pose == &"left" and game.snapshot().selected == 0 and game.snapshot().pose == &"left", "left moves the spotlight and poses left")
	_press(game, KEY_LEFT, false)
	_check(game.pose == &"left", "a quick tap holds its pose for a moment")
	_advance(game, Game.POSE_SECONDS + 0.05)
	_check(game.pose == Game.IDLE, "then the hero relaxes")
	_tap(game, KEY_LEFT)
	_check(game.selected == 0 and game.pose == &"left", "the spotlight stops at the first mirror but the pose still happens")
	for press in 4:
		_tap(game, KEY_RIGHT)
	_check(game.selected == game.mirrors - 1 and game.pose == &"right", "right moves the spotlight to the last mirror and no further")
	var kept := game.selected
	_press(game, KEY_UP, true)
	_advance(game, 1.0)
	_check(game.selected == kept and game.pose == &"up", "up poses on the spot for as long as it is held")
	_press(game, KEY_UP, false)
	_advance(game, 0.05)
	_check(game.pose == Game.IDLE and game.cases_done == 0, "releasing a long hold relaxes at once")


func _each_variant_has_its_own_tell() -> void:
	var lag := _playing("lag")
	for pose_key: int in [KEY_UP, KEY_LEFT, KEY_RIGHT]:
		_press(lag, pose_key, true)
		for index in lag.mirrors:
			_check((lag.reflection_pose(index) == lag.pose) == (index != lag.fake), "real reflections copy at once; the lagging fake is still behind")
		_advance(lag, lag.lag() - 0.03)
		_check(lag.reflection_pose(lag.fake) != lag.pose, "the fake stays behind for its whole lag")
		_advance(lag, 0.06)
		_check(lag.reflection_pose(lag.fake) == lag.pose and lag.snapshot().reflections[lag.fake] == lag.pose, "then it catches up")
		_press(lag, pose_key, false)
		_advance(lag, Game.POSE_SECONDS + lag.lag() + 0.1)
	var helped := _round("lag", true)
	_check(helped.lag() > lag.lag() * 1.3 and lag.lag() <= Game.LAG_SLOW, "assist makes the lag longer and easier to see")
	var wrong := _playing("wrong")
	_check(wrong.wrong_poses.size() == 3, "the wrong-pose fake fumbles every pose at first")
	for pose_key: int in [KEY_UP, KEY_LEFT, KEY_RIGHT]:
		_press(wrong, pose_key, true)
		_advance(wrong, 0.4)
		for index in wrong.mirrors:
			var shown: StringName = wrong.reflection_pose(index)
			_check((shown == wrong.pose) == (index != wrong.fake), "only the fake strikes another pose")
			if index == wrong.fake:
				_check(shown == Game.WRONG_POSE[wrong.pose] and shown != Game.IDLE, "the fake's wrong pose is a real pose")
		_press(wrong, pose_key, false)
		_advance(wrong, Game.POSE_SECONDS + 0.05)
		_check(wrong.reflection_pose(wrong.fake) == Game.IDLE, "at rest the fake looks like everyone else")
	var flip := _playing("flip")
	_press(flip, KEY_LEFT, true)
	_check(flip.reflection_pose(flip.fake) == &"right", "the flipped fake points right when the hero points left")
	_press(flip, KEY_LEFT, false)
	_advance(flip, Game.POSE_SECONDS + 0.05)
	_press(flip, KEY_RIGHT, true)
	_check(flip.reflection_pose(flip.fake) == &"left", "and left when the hero points right")
	_press(flip, KEY_RIGHT, false)
	_advance(flip, Game.POSE_SECONDS + 0.05)
	_press(flip, KEY_UP, true)
	_check(flip.reflection_pose(flip.fake) == &"up", "raising both hands does not give the flipped fake away")
	_press(flip, KEY_UP, false)


func _accusations_score_and_resolve() -> void:
	var game := _playing("flip")
	var expected := [5, 10, 15, 20, 20]
	var total := 0
	for catch_index in expected.size():
		_point_at(game, game.fake)
		_tap(game, KEY_SPACE)
		total += expected[catch_index]
		_check(game.outcome == "caught" and game.accused == game.fake and game.score == total and game.catches == catch_index + 1
			and game.mistakes == 0 and is_equal_approx(game.pause, Game.CAUGHT_SECONDS) and game.pose == Game.IDLE and game.snapshot().word_good,
			"catch %d in a row is worth %d" % [catch_index + 1, expected[catch_index]])
		_check(game.reflection_pose(game.fake) == game.pose, "a caught fake stops pretending")
		var frozen := game.selected
		_tap(game, KEY_LEFT)
		_tap(game, KEY_SPACE)
		_check(game.selected == frozen and game.catches == catch_index + 1, "input waits while a case resolves")
		_advance(game, Game.CAUGHT_SECONDS + 0.05)
		_check(game.outcome == "" and game.pause <= 0.0 and game.accused == -1 and game.selected == floori(game.mirrors * 0.5)
			and game.cases_done == catch_index + 1, "the next case starts by itself with the spotlight back in the middle")
	_point_at(game, (game.fake + 1) % game.mirrors)
	_tap(game, KEY_SPACE)
	_check(game.outcome == "escaped" and game.accused != game.fake and game.score == total and game.mistakes == 1 and game.streak == 0
		and is_equal_approx(game.pause, Game.ESCAPE_SECONDS) and Game.ESCAPE_SECONDS > Game.CAUGHT_SECONDS * 2.0 and not game.snapshot().word_good
		and game.snapshot().fake == game.fake, "a wrong accusation lets the fake escape, costs time and ends the streak")
	_advance(game, Game.ESCAPE_SECONDS + 0.05)
	_point_at(game, game.fake)
	_tap(game, KEY_SPACE)
	_check(game.score == total + 5, "after a miss the next catch starts small again")
	var learner := _playing("flip")
	_point_at(learner, (learner.fake + 1) % learner.mirrors)
	_tap(learner, KEY_SPACE)
	_check(learner.outcome == "escaped" and learner.mistakes == 0, "the very first wrong guess is a free lesson")


func _the_round_escalates() -> void:
	var game := _playing("wrong")
	var early_lag := _playing("lag").lag()
	var mirror_counts: Dictionary = {}
	var fumble_counts: Dictionary = {}
	var last_mirrors := game.mirrors
	while game.stage == "play":
		if game.pause <= 0.0:
			mirror_counts[game.mirrors] = true
			fumble_counts[game.mirrors] = game.wrong_poses.size()
			_check(game.mirrors >= last_mirrors and game.fake < game.mirrors and game.snapshot().reflections.size() == game.mirrors, "mirrors only ever join the row")
			last_mirrors = game.mirrors
			_point_at(game, game.fake)
			_tap(game, KEY_SPACE)
		_advance(game, 0.25)
	_check(mirror_counts.keys() == [3, 4, 5], "the row grows from three to four to five mirrors")
	_check(fumble_counts == {3: 3, 4: 2, 5: 1}, "the wrong-pose fake fumbles fewer poses as mirrors are added")
	var late := _round("lag", false)
	_advance(late, Base.READY_SECONDS + late.round_seconds - 0.5)
	_check(late.lag() < early_lag * 0.6 and late.lag() >= Game.LAG_FAST - 0.01, "the lag shrinks through the round but stays visible")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["lag", "wrong", "flip"]:
		var gold := _play(session, variant_id, false, 0.0, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1 and gold.mistakes == 0, "watching closely earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: a slower player who also picks the wrong mirror every fourth time.
	var bronze := _play(session, "lag", false, 1.5, 4)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a slow round with slips still earns bronze (score %d)" % bronze.score)
	# Guessing: always accuse the middle mirror without looking.
	var guess := _play(session, "lag", false, -1.0, 0)
	_check(not guess.success and not guess.devil and not guess.ordinary_eligible and guess.score < lines[0] and guess.mistakes > 3,
		"blind guessing earns no medal (score %d)" % guess.score)
	var helped := _play(session, "lag", true, 0.0, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("fake reflection scores: gold %s, bronze %d, guess %d, assisted %d" % [gold_scores, bronze.score, guess.score, helped.score])
	session.free()


## Play a whole round through Session input. `think` is extra seconds spent per
## case (negative accuses blindly); every `slip_every`-th case picks a wrong mirror.
func _play(session: Session, variant_id: String, assisted: bool, think: float, slip_every: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-050", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	while not session.ended and game.stage == "play":
		if game.pause > 0.0:
			_run_session(session, STEP)
			continue
		if think < 0.0:
			_session_tap(session, KEY_SPACE)
			continue
		_run_session(session, think)
		var odd := -1
		for probe: int in [KEY_UP, KEY_LEFT, KEY_RIGHT]:
			_session_key(session, probe, true)
			_run_session(session, 0.1)
			var reflections: Array = game.snapshot().reflections
			for index in reflections.size():
				if reflections[index] != game.pose:
					odd = index
			_session_key(session, probe, false)
			_run_session(session, Game.POSE_SECONDS + game.lag() + 0.05)
			if odd >= 0 or game.stage != "play":
				break
		if odd < 0 or game.stage != "play":
			continue
		if slip_every > 0 and (game.cases_done + 1) % slip_every == 0:
			odd = (odd + 1) % game.mirrors
		while game.selected != odd and game.stage == "play":
			_session_tap(session, KEY_RIGHT if game.selected < odd else KEY_LEFT)
		_session_tap(session, KEY_SPACE)
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


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


func _session_key(session: Session, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	session._unhandled_input(key)


func _session_tap(session: Session, code: int) -> void:
	_session_key(session, code, true)
	_run_session(session, 0.05)
	_session_key(session, code, false)
	_run_session(session, 0.05)


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
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


## Move the spotlight onto a mirror with real left and right presses.
func _point_at(game: Game, mirror: int) -> void:
	for press in 8:
		if game.selected == mirror:
			break
		_tap(game, KEY_RIGHT if game.selected < mirror else KEY_LEFT)
	_advance(game, Game.POSE_SECONDS + 0.05)


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
