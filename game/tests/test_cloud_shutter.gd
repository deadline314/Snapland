extends SceneTree
## 雲影快門 rules: the demo picture, melting shapes and the call, perfect and
## early shots, streaks, wrong shots and the tongue-out face, the shutter
## cooldown, called shapes going by, look-alikes, quicker melts, variants,
## assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/cloud_shutter_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_takes_a_picture()
	_shooting_the_called_shape()
	_wrong_shots_pull_a_face()
	_look_alikes_and_quicker_melts()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: cloud shutter demo, melting shapes, the call, perfect and early shots, streaks, wrong shots and the face, look-alikes, passes, quicker melts, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_takes_a_picture() -> void:
	var game := _round("slow", false)
	_check(game.stage == "ready" and game.thresholds == [140, 290, 380] and game.target == "rabbit" and game.blobs().size() == 9, "a round opens calling for a rabbit")
	var snapped := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		if tick % 10 == 0:
			_tap(game, KEY_SPACE)
		game.step(STEP)
		snapped = snapped or (game.shot_hit and game.shot_at > 0.0)
	_check(snapped and game.score == 0 and game.wrongs == 0, "the countdown melts the cloud into a rabbit and takes its picture by itself; space does nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and Game.TARGETS.has(game.target), "then play calls a shape")


func _shooting_the_called_shape() -> void:
	var game := _playing("slow")
	_to_target(game, 1.0)
	var called := game.target
	_tap(game, KEY_SPACE)
	_check(game.hits == 1 and game.perfects == 1 and game.streak == 1 and game.score == Game.PERFECT_POINTS + 2 and game.target != called,
		"a picture of the called shape scores and a new shape is called (%d)" % game.score)
	_to_target(game, Game.FORMED + 0.03)
	var before := game.score
	_tap(game, KEY_DOWN)
	_check(game.hits == 2 and game.perfects == 1 and game.score - before == Game.GOOD_POINTS + 4, "just before it finishes forming still counts, for less (↓ works too)")
	_tap(game, KEY_SPACE)
	_check(game.hits == 2 and game.wrongs == 0, "the shutter needs a moment between pictures")
	var pad := _playing("slow")
	_to_target(pad, 1.0)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.hits == 1, "the gamepad A button takes pictures too")
	var waiting := _playing("slow")
	waiting.streak = 3
	_to_target(waiting, 1.0)
	var gone := waiting.target
	_advance(waiting, waiting.hold_seconds + 0.05)
	_check(waiting.passes == 1 and waiting.streak == 0 and waiting.target != gone, "a called shape that goes by breaks the streak and another is called")


func _wrong_shots_pull_a_face() -> void:
	var game := _playing("slow")
	game.score = 50
	for tick in 1200:
		if game.to_name == "filler" and game.formed() >= 1.0:
			break
		game.step(STEP)
	_tap(game, KEY_SPACE)
	_check(game.wrongs == 1 and game.to_name == "head" and game.score == 50 - Game.WRONG_POINTS and game.mistakes == 0 and game.fail_at > 0.0
		and not game.snapshot().word_good, "a picture of the wrong cloud turns it into the traveller's head; the first time is a free look")
	var shot := game.shot_at
	_advance(game, 0.6)
	_tap(game, KEY_SPACE)
	_check(game.shot_at == shot, "no pictures while it pulls a face")
	_advance(game, Game.FACE_SECONDS)
	_check(game.to_name != "head", "then it melts into something else")
	for tick in 1200:
		if game.to_name != game.target and game.formed() >= 1.0:
			break
		game.step(STEP)
	_tap(game, KEY_SPACE)
	_check(game.wrongs == 2 and game.mistakes == 1, "a second wrong picture counts as a mistake")


func _look_alikes_and_quicker_melts() -> void:
	var game := _playing("slow")
	var decoys_early := 0
	var decoys_late := 0
	var calls_early := 0
	var calls_late := 0
	var melts_early: Array[float] = []
	var melts_late: Array[float] = []
	var last_morph := game.morph_at
	var last_call := game.called_at
	var decoy_before_target := true
	while game.stage == "play":
		game.step(STEP)
		if game.called_at != last_call:
			last_call = game.called_at
			if game.heat() < 0.5:
				calls_early += 1
			else:
				calls_late += 1
		if game.morph_at != last_morph:
			last_morph = game.morph_at
			if game.heat() < 0.25:
				melts_early.append(game.morph_seconds)
			elif game.heat() > 0.75:
				melts_late.append(game.morph_seconds)
			if Game.DECOYS.values().has(game.to_name):
				decoy_before_target = decoy_before_target and game.to_name == Game.DECOYS[game.target]
				if game.heat() < 0.5:
					decoys_early += 1
				else:
					decoys_late += 1
	_check(decoys_early + decoys_late > 0 and decoy_before_target, "a look-alike of the called shape sometimes forms first (%d)" % (decoys_early + decoys_late))
	_check(float(decoys_late) / maxf(1.0, calls_late) > float(decoys_early) / maxf(1.0, calls_early), "look-alikes come more often later")
	_check(not melts_early.is_empty() and not melts_late.is_empty() and melts_late.max() < melts_early.min(), "the cloud melts faster later")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["slow", "quick", "tricky"], "three variants are declared")
	var quick := _playing("quick")
	var slow := _playing("slow")
	quick._melt_to("filler")
	slow._melt_to("filler")
	_check(quick.morph_seconds < slow.morph_seconds, "the quick clouds melt faster")
	var helped := _playing("slow", true)
	helped._melt_to("rabbit")
	slow._melt_to("rabbit")
	_check(helped.hold_seconds > slow.hold_seconds * 1.3, "assist holds each shape longer")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["slow", "quick", "tricky"]:
		var gold := _play(session, variant_id, false, 1.0, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp eye earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "slow", false, Game.FORMED + 0.02, BRONZE_SKIP, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a hasty eye that misses some still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "slow", false, 1.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "snapping away at everything earns nothing (score %d)" % masher.score)
	var idle := _play(session, "slow", false, 1.0, 1.0, false)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "slow", true, 1.0, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("cloud shutter scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## The share of called shapes the hasty eye lets go by.
const BRONZE_SKIP := 0.4


## Play a whole round through Session input: shoot each called shape once it
## has formed to `ready`, letting a share `skip` go by; `mash` snaps every
## third of a second instead.
func _play(session: Session, variant_id: String, assisted: bool, ready: float, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-107", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 61
	var planned: Dictionary = {}
	var tick := 0
	while not session.ended and game.stage == "play":
		var press := false
		if mash:
			press = tick % 40 == 0
		elif skip < 1.0:
			if not planned.has(game.called_at):
				planned[game.called_at] = decide.randf() >= skip
			if planned[game.called_at] and game.to_name == game.target and game.formed() >= ready:
				press = true
		if press:
			_session_key(session, KEY_SPACE, true)
			session._process(STEP)
			_session_key(session, KEY_SPACE, false)
		session._process(STEP)
		tick += 1
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


## Run on until the called shape has formed to `ready`.
func _to_target(game: Game, ready: float) -> void:
	for tick in 2400:
		if game.to_name == game.target and game.formed() >= ready:
			return
		game.step(STEP)
	failures.append("the called shape never formed")


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
