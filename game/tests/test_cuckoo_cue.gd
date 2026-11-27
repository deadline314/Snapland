extends SceneTree
## 整點咕咕 rules: ticks, the hit window, bonks, streaks, tempo, off-beats, the decoy, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/cuckoo_cue_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_opening_the_door_on_the_tick()
	_wrong_moments_end_at_the_door()
	_streaks_score_more()
	_the_round_escalates()
	_variants_change_the_clock()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: cuckoo cue ticks, hit window, bonks, streaks, tempo, off-beats, decoy, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.targets.size() == 1 and game.targets[0].tick == float(Game.DEMO_TICK) and game.thresholds == [100, 220, 360],
		"a round opens on a demonstration bar with its medal lines declared")
	var notes := 0
	var sang_at := -1.0
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		notes += game.consume_notes().size()
		if sang_at < 0.0 and game.targets[0].state == "hit":
			sang_at = game.clock
	_check(absf(sang_at - Game.DEMO_BEAT * Game.DEMO_TICK) < 0.03 and game.score == 0 and game.hits == 0 and game.bonks == 0 and notes >= Game.BEATS + 1,
		"the countdown ticks audibly and lets the bird out on the named tick by itself; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.bar == 1 and game.targets[0].state == "pending" and game.targets[0].tick >= 2.0 and game.ticks.size() == Game.BEATS,
		"play starts on a fresh four-tick bar that leaves a beat to get ready")


func _opening_the_door_on_the_tick() -> void:
	var game := _playing("standard")
	var target: Dictionary = game.targets[0]
	_check(is_equal_approx(target.time, game.beat * target.tick) and is_equal_approx(game.bar_length, game.beat * (Game.BEATS + 1))
		and is_equal_approx(game.hit_window(), Game.WINDOW), "ticks are one beat apart after a one-beat lead-in")
	_advance_to(game, float(target.time) - 0.02)
	_tap(game, KEY_SPACE)
	_check(target.state == "hit" and target.perfect and game.score == Game.HIT_POINTS + Game.PERFECT_POINTS and game.hits == 1 and game.streak == 1
		and game.snapshot().word_good, "opening the door right on the tick lets the bird sing: ten points and five for a perfect")
	_tap(game, KEY_SPACE)
	_check(game.score == 15 and game.mistakes == 0, "the rest of the bar ignores further presses")
	_advance_to(game, game.bar_length + 0.02)
	_check(game.bar == 2 and game.targets[0].state == "pending", "the next bar follows by itself")
	target = game.targets[0]
	_advance_to(game, float(target.time) + game.hit_window() - 0.015)
	_tap(game, KEY_SPACE)
	_check(target.state == "hit" and not target.perfect and game.score == 15 + Game.HIT_POINTS + Game.STREAK_POINTS,
		"a press at the edge of the window still counts, without the perfect bonus")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.hit_window() > Game.WINDOW * 1.4 and helped.hit_window() < helped.beat * 0.5, "assist widens the window but never as far as the next half beat")


func _wrong_moments_end_at_the_door() -> void:
	var game := _playing("standard")
	var target: Dictionary = game.targets[0]
	_advance_to(game, float(target.time) - game.hit_window() - 0.05)
	_tap(game, KEY_SPACE)
	_check(target.state == "jammed" and game.score == 0 and game.bonks == 0 and game.snapshot().empty_at > 0.0 and not game.snapshot().word_good,
		"opening too early finds nobody behind the door, and the door jams")
	_advance_to(game, float(target.time) + 0.02)
	_check(target.state == "bonk" and game.bonks == 1 and game.mistakes == 0 and game.streak == 0, "the bird then flies into the jammed door; the first bump is a free lesson")
	_advance_to(game, game.bar_length + 0.02)
	target = game.targets[0]
	_advance_to(game, float(target.time) + game.hit_window() + 0.03)
	_check(target.state == "bonk" and game.bonks == 2 and game.mistakes == 1, "never opening the door ends the same way, and later bumps count as mistakes")
	_tap(game, KEY_SPACE)
	_check(game.score == 0 and game.bonks == 2, "a door cannot be opened after the bump")


func _streaks_score_more() -> void:
	var game := _playing("standard")
	var expected := [15, 20, 25, 30, 35, 35]
	var total := 0
	for index in expected.size():
		var target: Dictionary = game.targets[0]
		_advance_to(game, float(target.time))
		_tap(game, KEY_SPACE)
		total += expected[index]
		_check(game.score == total and game.streak == index + 1, "perfect hit %d in a row is worth %d" % [index + 1, expected[index]])
		_advance_to(game, game.bar_length + 0.02)
	_advance_to(game, float(game.targets[0].time) + 0.3)
	_check(game.streak == 0, "a bump ends the streak")
	_advance_to(game, game.bar_length + 0.02)
	_advance_to(game, float(game.targets[0].time))
	_tap(game, KEY_SPACE)
	_check(game.score == total + 15, "and the next hit starts small again")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var beats: Array[float] = []
	var first_offbeat := -1.0
	var first_decoy := -1.0
	var decoy_seen := false
	var last_bar := 0
	var same_tempo := 0
	while game.stage == "play":
		if game.bar != last_bar:
			last_bar = game.bar
			if not beats.is_empty() and is_equal_approx(beats[-1], game.beat):
				same_tempo += 1
			beats.append(game.beat)
			var tick := float(game.targets[0].tick)
			if tick > floorf(tick) and first_offbeat < 0.0:
				first_offbeat = game.heat()
				_check(is_equal_approx(game.targets[0].time, (game.ticks[int(tick) - 1] + game.ticks[int(tick)]) * 0.5), "a half-beat target sits midway between two ticks")
			if game.decoy_tick > 0:
				if first_decoy < 0.0:
					first_decoy = game.heat()
				_check(game.decoy_tick != int(tick), "the decoy never pops on the cuckoo's own tick")
		decoy_seen = decoy_seen or game.snapshot().decoy_at > 0.0
		game.step(STEP)
	_check(beats.size() >= 16 and same_tempo == 0, "the tempo changes with every bar (%d bars)" % beats.size())
	_check(beats.slice(0, 4).min() > beats.slice(-4).max() * 0.99 and beats.slice(-4).min() < Game.BEAT_FAST * 1.2 and beats.min() >= Game.BEAT_FAST * 0.85,
		"late bars tick clearly faster than early ones")
	_check(first_offbeat >= Game.OFFBEAT_HEAT and first_decoy >= Game.DECOY_HEAT and decoy_seen, "half-beat targets and the decoy bird only join later in the round")


func _variants_change_the_clock() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "swing", "duet", "silent"], "four variants are declared")
	var swing := _playing("swing")
	_check(is_equal_approx(swing.ticks[1] - swing.ticks[0], swing.beat * Game.SWING * 2.0) and is_equal_approx(swing.ticks[2] - swing.ticks[0], swing.beat * 2.0),
		"the swing clock ticks long-short")
	var duet := _playing("duet")
	var first: Dictionary = duet.targets[0]
	var second: Dictionary = duet.targets[1]
	_check(duet.targets.size() == 2 and first.tick < second.tick and first.door != second.door and duet.snapshot().duet, "the duet names two ticks, one for each bird")
	_advance_to(duet, float(first.time))
	_tap(duet, KEY_SPACE)
	_advance_to(duet, float(second.time))
	_tap(duet, KEY_SPACE)
	_check(first.state == "hit" and second.state == "hit" and duet.score == roundi(15 * 0.45) + roundi(20 * 0.45) and duet.streak == 2, "each bird is let out with its own press")
	var first_door := int(first.door)
	_advance_to(duet, duet.bar_length + 0.02)
	_check(int(duet.targets[0].door) != first_door, "the birds take turns going first")
	var quiet := _playing("silent")
	var loud_notes := 0
	var quiet_notes := 0
	var quiet_ticks := 0
	quiet.consume_notes()
	while quiet.bar <= 2:
		var was_silent := quiet.silent
		var heard := quiet.ticks_heard
		quiet.step(STEP)
		var count := quiet.consume_notes().size()
		if quiet.bar > 2:
			break
		if was_silent:
			quiet_notes += count
			quiet_ticks += quiet.ticks_heard - heard if quiet.ticks_heard > heard else 0
		else:
			loud_notes += count
	_check(loud_notes >= Game.BEATS and quiet_notes <= 2 and quiet_ticks == Game.BEATS and quiet.snapshot().has("silent"),
		"every other bar of the silent variant keeps ticking for the pendulum but makes no tick sound")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "swing", "duet", "silent"]:
		# Gold: on the tick nearly every time, a touch early or late, with one bar in nine missed.
		var gold := _play(session, variant_id, false, 0.05, 9, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "counting the ticks earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: sloppy timing and every third bird left to hit the door.
	var bronze := _play(session, "standard", false, 0.11, 3, false)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "loose timing with many bumps still earns bronze (score %d)" % bronze.score)
	# Mashing: open the door on every single tick.
	var masher := _play(session, "standard", false, 0.0, 0, true)
	_check(not masher.success and masher.score < lines[0] and masher.mistakes > 5, "opening the door on every tick earns nothing (score %d)" % masher.score)
	var helped := _play(session, "standard", true, 0.05, 9, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("cuckoo cue scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: press `late` seconds off every
## target (alternately early and late), skipping every `skip_every`-th bar;
## `mash` presses on every tick instead.
func _play(session: Session, variant_id: String, assisted: bool, late: float, skip_every: int, mash: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-062", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var mashed := -1
	var presses := 0
	while not session.ended and game.stage == "play":
		var since := game.clock - game.bar_at
		var due := false
		if mash:
			var stamp := game.bar * 10 + game.ticks_heard
			due = game.ticks_heard > 0 and stamp != mashed
			if due:
				mashed = stamp
		elif skip_every == 0 or game.bar % skip_every != 0:
			for target: Dictionary in game.targets:
				if target.state == "pending":
					due = since >= float(target.time) + (late if presses % 2 == 0 else -late)
					break
		if due:
			presses += 1
			_session_key(session, KEY_SPACE, true)
			session._process(STEP)
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


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
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


## Step until `seconds` have passed since the current bar began.
func _advance_to(game: Game, seconds: float) -> void:
	var bar := game.bar
	while game.bar == bar and game.clock - game.bar_at < seconds and game.stage == "play":
		game.step(minf(STEP, maxf(seconds - (game.clock - game.bar_at), 0.0005)))


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
