extends SceneTree
## 葉舟搬家 rules: the countdown demo, paddling by key and gamepad, alternating
## strokes going faster, banks and islands, boarding ants and streaks, rocks
## and whirlpools capsizing the leaf, forks with a crowded branch, escalation,
## variants, assist, no points without input and full simulated rounds.

const Game = preload("res://game/minigames/arcade/leaf_boat_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const ROUND_STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_boarding()
	_untouched_rounds_never_score()
	_paddling()
	_banks_and_islands()
	_boarding_ants()
	_capsizing()
	_forks()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: leaf boat demo, paddling, banks and islands, boarding ants, capsizing, forks, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_boarding() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [250, 550, 800] and game.things.size() == 1, "a round opens with one demo petal of ants")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_LEFT)
		game.step(STEP)
	_check(float(game.things[0].taken_at) >= 0.0 and game.score == 0 and game.ants == 0, "the countdown paddles to the demo ants by itself and scores nothing")
	while game.stage == "ready":
		game.step(STEP)
	var clear := game.things.all(func(thing: Dictionary) -> bool: return thing.kind == "ants" or float(thing.y) > game.travel + 0.8)
	_check(game.stage == "play" and absf(game.x - 0.5) < 0.01 and clear and game.flip.is_empty(), "play starts mid-stream with no rock or whirlpool close ahead")


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


func _paddling() -> void:
	var game := _empty("standard")
	_tap(game, KEY_LEFT)
	_advance(game, 0.3)
	_check(game.x < 0.45 and game.stroke_side == -1, "← veers the leaf left")
	var pad := _empty("standard")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	pad.handle_input(right, Vector2.ZERO)
	_advance(pad, 0.3)
	_check(pad.x > 0.55, "the gamepad D-pad paddles too")
	var alternate := _empty("standard")
	var same := _empty("standard")
	for stroke in 6:
		_tap(alternate, KEY_LEFT if stroke % 2 == 0 else KEY_RIGHT)
		_tap(same, KEY_LEFT)
		_advance(alternate, 0.25)
		_advance(same, 0.25)
	_check(alternate.travel > same.travel + 0.05 and absf(alternate.x - 0.5) < absf(same.x - 0.5), "alternating strokes run straighter and faster than one side")


func _banks_and_islands() -> void:
	var game := _empty("standard")
	for stroke in 12:
		_tap(game, KEY_LEFT)
		_advance(game, 0.1)
	var edge := Game.banks(game.travel)
	_check(game.x >= edge.x + Game.HULL - 0.001 and game.flip.is_empty(), "the leaf bumps along the bank without capsizing")
	var fork := _empty("standard")
	fork.forks.append({"y0": fork.travel + 0.1, "y1": fork.travel + 1.2, "centre": 0.5})
	_advance(fork, 1.5)
	var middle := fork.island(fork.travel)
	_check(middle != Vector2.ZERO and (fork.x <= middle.x or fork.x >= middle.y) and fork.flip.is_empty(), "an island splits the stream and pushes the leaf to one branch")


func _boarding_ants() -> void:
	var game := _empty("standard")
	for nth in 3:
		game.things.append(game._thing("ants", 0.5, game.travel + 0.15 + nth * 0.12, 1))
	_advance(game, 1.5)
	_check(game.ants == 3 and game.score == Game.ANT_POINTS * 3 + Game.STREAK_POINTS * 3, "ants climb aboard as the leaf brushes them, faster in a streak (score %d)" % game.score)
	var crowd := _empty("standard")
	crowd.things.append(crowd._thing("ants", 0.5, crowd.travel + 0.15, 3))
	_advance(crowd, 1.0)
	_check(crowd.ants == 3 and crowd.score == Game.ANT_POINTS * 3, "a crowded petal brings a whole family aboard")


func _capsizing() -> void:
	var game := _empty("standard")
	game.things.append(game._thing("rock", 0.5, game.travel + 0.12, 0))
	_advance(game, 0.8)
	_check(game.flips == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.busy() and game.flip.why == "rock", "a rock capsizes the leaf; the first capsize is a free look")
	var x := game.x
	_tap(game, KEY_LEFT)
	_advance(game, 0.2)
	_check(game.x == x, "no paddling while the ants carry the traveller off")
	_advance(game, Game.FLIP_SECONDS)
	_check(not game.busy() and game.things.all(func(thing: Dictionary) -> bool: return thing.kind == "ants" or float(thing.taken_at) >= 0.0 or float(thing.y) > game.travel + 0.4),
		"after the rescue the stretch ahead is clear")
	game.things.append(game._thing("rock", game.x, game.travel + 0.1, 0))
	_advance(game, 0.8)
	_check(game.flips == 2 and game.mistakes == 1, "a second capsize counts as a mistake")
	var whirl := _empty("standard")
	whirl.things.append(whirl._thing("whirl", 0.56, whirl.travel + 0.3, 0))
	var drift := 0.0
	for tick in 200:
		whirl.step(STEP)
		drift = maxf(drift, whirl.x - 0.5)
	_check(drift > 0.01 and whirl.flips == 1 and whirl.flip.why == "whirl", "a whirlpool drags the leaf in and flips it at its eye")


func _forks() -> void:
	var game := _empty("standard")
	game._fork(game.travel + 0.3)
	var fork: Dictionary = game.forks[0]
	var narrow := 0
	var wide := 0
	for thing in game.things:
		if thing.kind != "ants":
			continue
		if (float(thing.x) < float(fork.centre)) == (float(fork.centre) < 0.5 * (Game.banks(game.travel + 0.85).x + Game.banks(game.travel + 0.85).y)):
			narrow += int(thing.count)
		else:
			wide += int(thing.count)
	_check(narrow >= 6 and wide <= 2, "one branch of a fork is crowded with ants (%d vs %d)" % [narrow, wide])


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.current()
	game.play_time = game.round_seconds * 0.95
	_check(game.current() > early * 1.6, "the stream runs faster later on")
	var calm := _playing("standard")
	var whirls := 0
	for row in 60:
		calm._row(calm.travel + 1.0 + row)
	for thing in calm.things:
		whirls += 1 if thing.kind == "whirl" else 0
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.8
	var late_whirls := 0
	for row in 60:
		late._row(late.travel + 1.0 + row)
	for thing in late.things:
		late_whirls += 1 if thing.kind == "whirl" else 0
	_check(whirls == 0 and late_whirls > 5, "whirlpools only turn up later on")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "rapids", "whirl"], "three variants are declared")
	var rapids := _playing("rapids")
	var plain := _playing("standard")
	_check(rapids.current() > plain.current() * 1.1, "the rapids run faster")
	var whirl := _playing("whirl")
	var whirls := 0
	for row in 60:
		whirl._row(whirl.travel + 1.0 + row)
	for thing in whirl.things:
		whirls += 1 if thing.kind == "whirl" else 0
	_check(whirls > 5, "whirlpool day has whirlpools from the start")
	var helped := _playing("standard", true)
	_check(helped.rock_reach() < plain.rock_reach() * 0.8 and helped.current() < plain.current() * 0.8, "assist shrinks the rocks and slows the stream")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_means: Array[int] = []
	for variant_id: String in ["standard", "rapids", "whirl"]:
		var rounds := _rounds(session, variant_id, false, 0.12)
		lines = rounds[0].score_summary.thresholds
		var best: Dictionary = rounds.reduce(func(a: Dictionary, b: Dictionary) -> Dictionary: return a if a.score >= b.score else b)
		gold_means.append(_mean(rounds))
		_check(_mean(rounds) >= lines[2] and best.success and best.devil and best.ordinary_eligible and best.score_summary.medal == 3
			and best.score_summary.rows.size() == 1, "a nimble paddler earns gold in the %s variant (scores %s)" % [variant_id, _scores(rounds)])
	var slow := _rounds(session, "standard", false, 0.7)
	var bronze_rounds := slow.filter(func(r: Dictionary) -> bool: return r.score_summary.medal == 1 and r.success and not r.devil)
	_check(_mean(slow) >= lines[0] and _mean(slow) < lines[1] and not bronze_rounds.is_empty(),
		"a slow paddler still earns bronze (scores %s)" % _scores(slow))
	var idle := _play(session, "standard", 0, false, -1.0)
	_check(not idle.success and idle.score == 0, "never paddling earns nothing (score %d)" % idle.score)
	var helped := _rounds(session, "standard", true, 0.12)
	_check(_mean(helped) >= lines[2] and helped.all(func(r: Dictionary) -> bool: return r.assisted and not r.devil)
		and helped.any(func(r: Dictionary) -> bool: return r.success and r.score_summary.medal == 3),
		"assisted gold rounds never award the devil sticker (scores %s)" % _scores(helped))
	print("leaf boat scores: gold means %s, bronze %s, idle %d, assisted %s" % [gold_means, _scores(slow), idle.score, _scores(helped)])
	session.free()


func _rounds(session: Session, variant_id: String, assisted: bool, react: float) -> Array[Dictionary]:
	var played: Array[Dictionary] = []
	for nth in 4:
		played.append(_play(session, variant_id, nth, assisted, react))
	return played


func _mean(rounds: Array[Dictionary]) -> int:
	var total := 0
	for result in rounds:
		total += int(result.score)
	return total / rounds.size()


func _scores(rounds: Array[Dictionary]) -> String:
	return str(rounds.map(func(r: Dictionary) -> int: return r.score))


## Play a whole round through Session key presses: every `react` seconds the
## paddler taps the stroke that heads for the best petal ahead while keeping
## clear of rocks and whirlpools; a negative `react` never paddles.
func _play(session: Session, variant_id: String, nth: int, assisted: bool, react: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-082", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id, nth)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(ROUND_STEP)
	var next_think := 0.0
	while not session.ended and game.stage == "play":
		if react >= 0.0 and game.clock >= next_think:
			next_think = game.clock + react
			var side := _steer(game)
			_session_key(session, KEY_LEFT if side < 0 else KEY_RIGHT, true)
			_session_key(session, KEY_LEFT if side < 0 else KEY_RIGHT, false)
		session._process(ROUND_STEP)
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


## -1 for a left stroke, 1 for a right one.
func _steer(game: Game) -> int:
	var target := 0.5 * (Game.banks(game.travel + 0.3).x + Game.banks(game.travel + 0.3).y)
	var best := INF
	for thing: Dictionary in game.things:
		if thing.kind != "ants" or float(thing.taken_at) >= 0.0:
			continue
		var ahead := float(thing.y) - game.travel
		if ahead < 0.02 or ahead > 0.7:
			continue
		var cost := ahead + absf(float(thing.x) - game.x) * 1.5 - int(thing.count) * 0.08
		if cost < best:
			best = cost
			target = float(thing.x)
	var middle := game.island(game.travel + 0.25)
	if middle != Vector2.ZERO and target > middle.x and target < middle.y:
		target = middle.x - 0.05 if game.x < (middle.x + middle.y) * 0.5 else middle.y + 0.05
	for thing: Dictionary in game.things:
		if thing.kind == "ants" or float(thing.taken_at) >= 0.0:
			continue
		var ahead := float(thing.y) - game.travel
		var reach := (0.14 if thing.kind == "rock" else 0.2)
		if ahead > -0.05 and ahead < 0.45 and absf(float(thing.x) - lerpf(game.x, target, 0.5)) < reach:
			target = float(thing.x) + (reach + 0.02) * (1.0 if game.x >= float(thing.x) else -1.0)
	var aim := target - (game.x + game.vx * 0.35)
	if absf(aim) < 0.02:
		return -game.stroke_side if game.stroke_side != 0 else 1
	return 1 if aim > 0.0 else -1


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
	game.touched = true
	return game


## In play with an empty stream ahead (nothing more gets planned for a while).
func _empty(variant_id: String) -> Game:
	var game := _playing(variant_id)
	game.things.clear()
	game.forks.clear()
	game._next_y = game.travel + 50.0
	game._next_fork = game.travel + 50.0
	return game


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
