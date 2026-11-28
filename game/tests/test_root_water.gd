extends SceneTree
## 根系蓄水 rules: the countdown demo, pouring by key and gamepad, filling
## speed by pot size, judging at the line, streaks, leaky and growing pots, the
## spill and slip, escalation, variants, assist, no points without input and
## full simulated rounds.

const Game = preload("res://game/minigames/arcade/root_water_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const ROUND_STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_pour()
	_untouched_rounds_never_score()
	_pouring_and_pot_sizes()
	_judging_at_the_line()
	_leaky_and_growing_pots()
	_the_spill()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: root water demo, pouring, pot sizes, judging and streaks, leaky and growing pots, spill and slip, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_pour() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [100, 230, 330] and game.pots.size() == 1, "a round opens with one demo pot")
	var demo: Dictionary = game.pots[0]
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
	_check(absf(float(demo.level) - float(demo.line)) < 0.05 and game.score == 0, "the countdown fills the demo pot to its line by itself and scores nothing")
	while game.stage == "ready":
		game.step(STEP)
	_check(game.stage == "play" and game.pots.size() == 1 and game.pots[0].phase == "in" and float(game.pots[0].level) == 0.0 and not game.pouring,
		"play starts with an empty pot only just sliding in")


func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		for round_seed in 40:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 30.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 80 seeded rounds: %s" % [scored])


func _pouring_and_pot_sizes() -> void:
	var game := _parked("standard", 0, 0.6, "plain")
	_press(game, KEY_SPACE, true)
	_advance(game, 0.5)
	_press(game, KEY_SPACE, false)
	_advance(game, 0.05)
	var small := float(game.under().level)
	_check(absf(small - Game.FILL[0] * 0.5) < 0.03 and not game.pouring, "holding the button pours, letting go stops")
	var big := _parked("standard", 2, 0.6, "plain")
	_press(big, KEY_SPACE, true)
	_advance(big, 0.5)
	_check(float(big.under().level) < small * 0.7, "a big pot fills more slowly than a small one")
	var pad := _parked("standard", 1, 0.6, "plain")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.3)
	_check(float(pad.under().level) > 0.1, "the gamepad A button pours too")
	var empty := _playing("standard")
	_press(empty, KEY_SPACE, true)
	_advance(empty, 0.2)
	_check(empty.under().is_empty() and float(empty.pots[0].level) == 0.0, "pouring with no pot under the can waters nothing")


func _judging_at_the_line() -> void:
	var results: Array = []
	for offset: float in [0.0, 0.1, -0.3, 0.25]:
		var game := _parked("standard", 1, 0.6, "plain")
		game.under().level = 0.6 + offset
		game.under().leave_at = game.clock
		_advance(game, 0.02)
		results.append([game.pots[0].result, game.score])
	_check(results == [["perfect", Game.PERFECT_POINTS], ["good", Game.GOOD_POINTS], ["dry", 0], ["soggy", 0]],
		"a pot is judged when it leaves: spot on, close, too dry or too wet: %s" % [results])
	var streak := _parked("standard", 1, 0.6, "plain")
	for pot in 3:
		var at := streak.under()
		at.level = at.line
		at.leave_at = streak.clock
		_advance(streak, 0.02)
		while streak.under().is_empty():
			_advance(streak, 0.05)
	_check(streak.streak == 3 and streak.score == Game.PERFECT_POINTS * 3 + Game.STREAK_POINTS * 3, "spot-on pots in a row build a streak")


func _leaky_and_growing_pots() -> void:
	var leaky := _parked("standard", 1, 0.6, "leaky")
	leaky.under().level = 0.6
	_advance(leaky, 1.0)
	_check(float(leaky.under().level) < 0.6 - Game.LEAK * 0.9, "a leaky pot loses water while it waits")
	var grow := _parked("standard", 0, 0.7, "grow")
	_press(grow, KEY_SPACE, true)
	while float(grow.under().grown_at) < 0.0 and grow.clock < 20.0:
		grow.step(STEP)
	_press(grow, KEY_SPACE, false)
	var pot := grow.under()
	_check(int(pot.size) == 1 and float(pot.level) < 0.7 * Game.GROW_AT * 0.75, "a growing pot pops a size bigger mid-pour and its water drops")
	var later := _playing("standard")
	later.play_time = later.round_seconds * 0.9
	var kinds := {}
	for tries in 200:
		kinds[later._next_pot().kind] = true
	var early := _playing("standard")
	var early_kinds := {}
	for tries in 200:
		early_kinds[early._next_pot().kind] = true
	_check(kinds.has("leaky") and kinds.has("grow") and early_kinds.keys() == ["plain"], "leaky and growing pots only turn up later on")


func _the_spill() -> void:
	var game := _parked("standard", 0, 0.6, "plain")
	_press(game, KEY_SPACE, true)
	_advance(game, 1.4)
	_check(game.spills == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.busy() and game.under().spilled and not game.pouring,
		"pouring past the brim spills; the traveller slips; the first spill is a free look")
	_advance(game, Game.SLIP_SECONDS + 0.1)
	_check(game.pots[0].result == "spilled" and game.score == 0, "a spilled pot scores nothing and moves on")
	_press(game, KEY_SPACE, false)
	var again := _parked("standard", 0, 0.6, "plain")
	again.spills = 1
	again.under().level = 0.99
	_press(again, KEY_SPACE, true)
	_advance(again, 0.1)
	_check(again.spills == 2 and again.mistakes == 1, "a second spill counts as a mistake")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.dwell()
	game.play_time = game.round_seconds * 0.95
	_check(game.dwell() < early * 0.75 and game.slide() < Game.SLIDE_FIRST, "pots wait less and slide faster later on")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "big", "leaky"], "three variants are declared")
	var big := _playing("big")
	var big_count := 0
	for tries in 100:
		big_count += 1 if big._next_pot().size == 2 else 0
	var plain := _playing("standard")
	var plain_count := 0
	for tries in 100:
		plain_count += 1 if plain._next_pot().size == 2 else 0
	_check(big_count > plain_count + 20, "big pot day sends more big pots (%d vs %d)" % [big_count, plain_count])
	var leaky := _playing("leaky")
	var leaks := 0
	for tries in 100:
		leaks += 1 if leaky._next_pot().kind == "leaky" else 0
	_check(leaks > 20, "leaky day has leaky pots from the start")
	var helped := _playing("standard", true)
	_check(helped.perfect_band() > plain.perfect_band() * 1.2 and helped.dwell() > plain.dwell() * 1.2, "assist widens the line and lets pots wait longer")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_means: Array[int] = []
	for variant_id: String in ["standard", "big", "leaky"]:
		var rounds := _rounds(session, variant_id, false, 0.0)
		lines = rounds[0].score_summary.thresholds
		var best: Dictionary = rounds.reduce(func(a: Dictionary, b: Dictionary) -> Dictionary: return a if a.score >= b.score else b)
		gold_means.append(_mean(rounds))
		_check(_mean(rounds) >= lines[2] and best.success and best.devil and best.ordinary_eligible and best.score_summary.medal == 3
			and best.score_summary.rows.size() == 1, "a careful waterer earns gold in the %s variant (scores %s)" % [variant_id, _scores(rounds)])
	var sloppy := _rounds(session, "standard", false, 0.2)
	var bronze_rounds := sloppy.filter(func(r: Dictionary) -> bool: return r.score_summary.medal == 1 and r.success and not r.devil)
	_check(_mean(sloppy) >= lines[0] and _mean(sloppy) < lines[1] and not bronze_rounds.is_empty(),
		"a waterer who lets go late still earns bronze (scores %s)" % _scores(sloppy))
	var idle := _play(session, "standard", 0, false, -1.0)
	_check(not idle.success and idle.score == 0, "never pressing earns nothing (score %d)" % idle.score)
	var helped := _rounds(session, "standard", true, 0.0)
	_check(_mean(helped) >= lines[2] and helped.all(func(r: Dictionary) -> bool: return r.assisted and not r.devil)
		and helped.any(func(r: Dictionary) -> bool: return r.success and r.score_summary.medal == 3),
		"assisted gold rounds never award the devil sticker (scores %s)" % _scores(helped))
	print("root water scores: gold means %s, bronze %s, idle %d, assisted %s" % [gold_means, _scores(sloppy), idle.score, _scores(helped)])
	session.free()


## Four rounds on the first four seeds that roll the named variant.
func _rounds(session: Session, variant_id: String, assisted: bool, late: float) -> Array[Dictionary]:
	var played: Array[Dictionary] = []
	for nth in 4:
		played.append(_play(session, variant_id, nth, assisted, late))
	return played


func _mean(rounds: Array[Dictionary]) -> int:
	var total := 0
	for result in rounds:
		total += int(result.score)
	return total / rounds.size()


func _scores(rounds: Array[Dictionary]) -> String:
	return str(rounds.map(func(r: Dictionary) -> int: return r.score))


## Play a whole round through Session key presses: hold while the pot under the
## can is below its line and let go `late` seconds of pouring after it gets
## there (a negative `late` never presses). Leaky pots get topped up again.
func _play(session: Session, variant_id: String, nth: int, assisted: bool, late: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-081", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id, nth)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(ROUND_STEP)
	var held := false
	while not session.ended and game.stage == "play":
		var pot := game.under()
		var want := false
		if late >= 0.0 and not pot.is_empty() and not bool(pot.spilled):
			var lead := game.fill_rate(pot) * ROUND_STEP
			var stop := float(pot.line) - lead + game.fill_rate(pot) * late
			if pot.kind == "leaky":
				# Top up near the line in the last moment before the pot leaves.
				stop = float(pot.line) + (Game.LEAK * 0.3 if float(pot.leave_at) - game.clock < 0.4 else -0.02)
			want = float(pot.level) < minf(stop, 0.97)
		if want != held:
			_session_key(session, KEY_SPACE, want)
			held = want
		session._process(ROUND_STEP)
	if held:
		_session_key(session, KEY_SPACE, false)
	for tick in 600:
		if session.ended:
			break
		session._process(ROUND_STEP)
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


## A round in play with one pot of the given size, line and kind already
## waiting under the can for a long while.
func _parked(variant_id: String, size: int, line: float, kind: String) -> Game:
	var game := _playing(variant_id)
	game.pots.clear()
	var pot := game._pot(size, line, kind)
	pot.phase = "under"
	pot.x = Game.STATION
	pot.since = game.clock
	pot.leave_at = game.clock + 30.0
	game.pots.append(pot)
	return game


## The nth seed whose round uses the named variant.
func _seed_for(variant_id: String, nth := 0) -> int:
	var found := 0
	for round_seed in 400:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		if game.variant.id == variant_id:
			if found == nth:
				return round_seed
			found += 1
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
