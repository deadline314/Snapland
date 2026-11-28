extends SceneTree
## 繩橋共振 rules: the demo steps, beats that alternate sides, perfect and good
## steps, the wrong foot and off-beat presses, streaks, stretches with their own
## paces, broken planks to stride over, flipping over, variants, assist and full
## simulated rounds.

const Game = preload("res://game/minigames/arcade/rope_bridge_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const KEYS := {&"left": KEY_LEFT, &"right": KEY_RIGHT, &"up": KEY_UP}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_walks_two_planks()
	_stepping_on_the_beat()
	_wrong_steps_wobble_and_flip()
	_stretches_and_broken_planks()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: rope bridge demo, beats, alternating steps, perfect and good, wrong foot, off-beat, streaks, stretches and their paces, broken planks, flips, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_walks_two_planks() -> void:
	var game := _round("fair", false)
	_check(game.stage == "ready" and game.thresholds == [400, 1000, 1800] and game.pos == 0 and game.gaps.is_empty(), "a round opens at the near end of the bridge")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		if tick % 15 == 0:
			_tap(game, KEY_LEFT)
		game.step(STEP)
	_check(game.pos == 2 and game.score == 0 and game.wrongs == 0 and game.wobble == 0.0, "the countdown walks two planks on the beat by itself; the arrows do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play", "then play starts")


func _stepping_on_the_beat() -> void:
	var game := _playing("fair")
	var sides: Array[int] = []
	for step in 4:
		_to_beat(game, 0.0)
		var beat := game.next_beat()
		sides.append(game.side(beat))
		_tap(game, KEYS[game.wanted_button(beat)])
	_check(game.pos == 6 and game.perfects == 4 and game.streak == 4 and sides == [sides[0], -sides[0], sides[0], -sides[0]],
		"stepping with the swing walks a plank a beat, left and right in turn (%s)" % [sides])
	_check(game.score == Game.PERFECT_POINTS * 4 + 1, "perfect steps pay, and a streak adds a little (%d)" % game.score)
	var before := game.score
	_to_beat(game, 0.1)
	_tap(game, KEYS[game.wanted_button(game.next_beat())])
	_check(game.goods == 1 and game.pos == 7 and game.score - before == Game.GOOD_POINTS + 1, "a little early is still a step, for less")
	var pad := _playing("fair")
	_to_beat(pad, 0.0)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_RIGHT if pad.wanted_button(pad.next_beat()) == &"right" else JOY_BUTTON_DPAD_LEFT
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.pos == 3, "the gamepad d-pad steps too")
	var skipping := _playing("fair")
	for step in 2:
		_to_beat(skipping, 0.0)
		_tap(skipping, KEYS[skipping.wanted_button(skipping.next_beat())])
	_advance(skipping, skipping.period())
	_check(skipping.streak == 0 and skipping.pos == 4, "letting beats go by breaks the streak but costs nothing else")


func _wrong_steps_wobble_and_flip() -> void:
	var game := _playing("fair")
	_to_beat(game, 0.0)
	var wanted: StringName = game.wanted_button(game.next_beat())
	_tap(game, KEY_LEFT if wanted == &"right" else KEY_RIGHT)
	_check(game.pos == 2 and game.wrongs == 1 and is_equal_approx(game.wobble, Game.WOBBLE_WRONG) and not game.snapshot().word_good,
		"the wrong foot doesn't step and sets the bridge swinging")
	var calm := absf(game.roll())
	_advance(game, game.period() * 0.25)
	_tap(game, KEY_LEFT)
	_check(game.wrongs == 2 and game.pos == 2, "so does a step between beats")
	var wild := 0.0
	for tick in int(game.period() / STEP):
		game.step(STEP)
		wild = maxf(wild, absf(game.roll()))
	_check(wild > Game.ROLL_STEADY * 2.0 and calm >= 0.0, "a wobbling bridge rolls further (%.2f)" % wild)
	_to_beat(game, 0.0)
	_tap(game, KEYS[game.wanted_button(game.next_beat())])
	_check(game.wobble < Game.WOBBLE_WRONG * 2.0, "a good step steadies it again")
	game.wobble = 0.9
	_to_beat(game, 0.0)
	wanted = game.wanted_button(game.next_beat())
	_tap(game, KEY_LEFT if wanted == &"right" else KEY_RIGHT)
	_check(game.hanging() and game.flips == 1 and game.mistakes == 0 and game.fail_at > 0.0, "swung too far it rolls right over; the first time is a free look")
	_advance(game, Game.FLIP_SECONDS + 0.2)
	_check(absf(game.roll()) > 2.6, "and the traveller hangs underneath (%.2f)" % game.roll())
	var held := game.pos
	_to_beat(game, 0.0)
	_tap(game, KEYS[game.wanted_button(game.next_beat())])
	_check(game.pos == held and game.wrongs == 3, "no steps while hanging")
	_advance(game, Game.HANG_SECONDS)
	_check(not game.hanging() and absf(game.roll()) < 1.0, "then the bridge rights itself")
	game.wobble = 0.95
	_advance(game, game.period() * 0.25)
	_tap(game, KEY_UP)
	_check(game.flips == 2 and game.mistakes == 1, "a second flip counts as a mistake")


func _stretches_and_broken_planks() -> void:
	var game := _playing("fair")
	var stretch_bonus := false
	while game.pos < Game.STRETCH + 1:
		_to_beat(game, 0.0)
		var before := game.score
		var stretches := game.stretches
		_tap(game, KEYS[game.wanted_button(game.next_beat())])
		stretch_bonus = stretch_bonus or (game.stretches > stretches and game.score - before >= Game.STRETCH_POINTS + Game.PERFECT_POINTS)
	_check(stretch_bonus, "reaching the next post pays a bonus")
	var periods: Array = []
	for stretch in 4:
		periods.append(game._periods[stretch])
	var different := true
	for index in range(1, periods.size()):
		different = different and absf(periods[index] - periods[index - 1]) >= 0.1
	_check(different, "each stretch swings at its own pace (%s)" % [periods])
	var late := _playing("fair")
	_advance(late, late.round_seconds * 0.8)
	late.pos = Game.STRETCH * 5
	late._plan_ahead()
	_check(late._periods[late._planned] < Game.PERIOD_FIRST * 0.85, "later stretches swing quicker")
	var worn := _playing("worn")
	var gap := -1
	for plank: int in worn.gaps.keys():
		if gap < 0 or plank < gap:
			gap = plank
	_check(gap > 0 and gap < Game.STRETCH * 3, "broken planks show up on the worn bridge (first at %d)" % gap)
	worn.pos = gap - 1
	_to_beat(worn, 0.0)
	_check(worn.wanted_button(worn.next_beat()) == &"up" and worn.snapshot().next_button == "up", "a broken plank ahead calls for ↑")
	var slip := _playing("worn")
	slip.pos = gap - 1
	_to_beat(slip, 0.0)
	_tap(slip, KEY_LEFT)
	_check(slip.pos == gap - 1 and is_equal_approx(slip.wobble, Game.WOBBLE_SLIP), "a foot put down on the hole goes through and the bridge lurches")
	var before := worn.score
	_tap(worn, KEY_UP)
	_check(worn.pos == gap + 1 and worn.stride == 2 and worn.score - before >= Game.PERFECT_POINTS + Game.STRIDE_POINTS, "↑ on the beat strides over it")
	var fair := _playing("fair")
	fair._plan_ahead()
	_check(fair.gaps.is_empty(), "a fair bridge starts with every plank in place")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["fair", "breezy", "worn"], "three variants are declared")
	var breezy := _playing("breezy")
	var fair := _playing("fair")
	var reach_breezy := 0.0
	var reach_fair := 0.0
	for tick in int(fair.period() / STEP):
		breezy.step(STEP)
		fair.step(STEP)
		reach_breezy = maxf(reach_breezy, absf(breezy.roll()))
		reach_fair = maxf(reach_fair, absf(fair.roll()))
	_check(reach_breezy > reach_fair * 1.3, "the breezy bridge swings wider")
	var helped := _playing("fair", true)
	_to_beat(helped, Game.GOOD * 1.3)
	_tap(helped, KEYS[helped.wanted_button(helped.next_beat())])
	_check(helped.pos == 3 and helped.goods == 1, "assist widens the timing")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["fair", "breezy", "worn"]:
		var gold := _play(session, variant_id, false, 0.0, 0.0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "steady feet earn gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "fair", false, BRONZE_EARLY, BRONZE_SKIP, false)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a loose walker who misses beats still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "fair", false, 0.0, 0.0, true)
	_check(not masher.success and masher.score < lines[0], "stamping about earns nothing (score %d)" % masher.score)
	var idle := _play(session, "fair", false, 0.0, 1.0, false)
	_check(not idle.success and idle.score == 0, "a round left alone earns nothing (score %d)" % idle.score)
	var helped := _play(session, "fair", true, 0.0, 0.0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("rope bridge scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## The bronze walker steps this early and lets this share of beats go by.
const BRONZE_EARLY := 0.11
const BRONZE_SKIP := 0.35


## Play a whole round through Session input: step `early` seconds before each
## beat with the foot it wants, letting a share `skip` go by; `mash` presses a
## random arrow every fifth of a second instead.
func _play(session: Session, variant_id: String, assisted: bool, early: float, skip: float, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-104", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var decide := RandomNumberGenerator.new()
	decide.seed = 41
	var planned: Dictionary = {}
	var tick := 0
	while not session.ended and game.stage == "play":
		var key := -1
		if mash:
			if tick % 24 == 0:
				key = [KEY_LEFT, KEY_RIGHT, KEY_UP][decide.randi() % 3]
		else:
			var beat := game.next_beat()
			if not planned.has(beat):
				planned[beat] = decide.randf() >= skip
			if planned[beat] and game.beat_offset(beat) >= -early - STEP * 0.5:
				key = KEYS[game.wanted_button(beat)]
				planned[beat] = false
		if key >= 0:
			_session_key(session, key, true)
			session._process(STEP)
			_session_key(session, key, false)
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


## Run on until the next beat is `early` seconds away (or here).
func _to_beat(game: Game, early: float) -> void:
	for tick in 600:
		if game.beat_offset(game.next_beat()) >= -early - STEP * 0.5:
			return
		game.step(STEP)


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
