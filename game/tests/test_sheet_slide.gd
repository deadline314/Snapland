extends SceneTree
## 被單滑梯 rules: the countdown demo, leaning, pillows and the streak, cats,
## rolling cats, blanket forts, the spring roll, escalation, variants, assist
## and full simulated rounds.

const Game = preload("res://game/minigames/arcade/sheet_slide_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_dodge()
	_untouched_rounds_never_score()
	_leaning_and_pillows()
	_a_cat_wraps_a_spring_roll()
	_rolling_cats_and_forts()
	_the_slide_steepens()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: sheet slide demo, leaning, pillows, streaks, cats, rolling cats, forts, spring roll, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_dodge() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [600, 1500, 2400] and game.things.size() >= 4, "a round opens with the slide planned ahead")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_LEFT)
		game.step(STEP)
	_check(game.distance > 3.0 and game.wrap_at < 0.0 and game.score == 0, "the countdown slides round the first cat by itself and scores nothing")
	_advance(game, 0.1)
	var first: Dictionary = game.things[0]
	_check(game.stage == "play" and game.distance < 1.0 and is_zero_approx(game.hero_x) and str(first.kind) == "cat" and is_zero_approx(float(first.x)),
		"play starts afresh in the middle with a cat straight ahead")


func _leaning_and_pillows() -> void:
	var game := _playing("standard")
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_press(game, KEY_RIGHT, false)
	_check(game.hero_x > 0.3, "holding → leans right across the slide")
	var x := game.hero_x
	_press(game, KEY_A, true)
	_advance(game, 0.3)
	_press(game, KEY_A, false)
	_check(game.hero_x < x - 0.15, "A leans left")
	_press(game, KEY_RIGHT, true)
	_advance(game, 3.0)
	_press(game, KEY_RIGHT, false)
	_check(game.hero_x <= Game.EDGE + 0.0001, "the hem keeps the traveller on the slide")
	var pad := _playing("standard")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	pad.handle_input(stick, Vector2.ZERO)
	_advance(pad, 0.3)
	var dpad := _playing("standard")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	dpad.handle_input(right, Vector2.ZERO)
	_advance(dpad, 0.3)
	_check(pad.hero_x < -0.3 and dpad.hero_x > 0.3, "the gamepad stick and D-pad lean too")
	var scoop := _playing("standard")
	scoop.things.clear()
	for index in 4:
		scoop.things.append(scoop._thing("pillow", scoop.distance + 1.0 + index, 0.0))
	scoop._steered = true
	_advance(scoop, 5.0 / scoop.speed() + 0.05)
	_check(scoop.pillows == 4 and scoop.streak == 4 and scoop.score == 4 * Game.PILLOW_POINTS + (1 + 2 + 3 + 4) * Game.STREAK_POINTS, "riding through a line of pillows scoops each, with a growing streak")


func _a_cat_wraps_a_spring_roll() -> void:
	var game := _playing("standard")
	var cat: Dictionary = game.things[0]
	_advance(game, (float(cat.at) - game.distance) / game.speed() + 0.02)
	_check(bool(cat.hit) and game.crashes == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.wrapped() and not game.snapshot().word_good,
		"sliding into a cat wraps the traveller into a spring roll; the first one is a free look")
	var parked := game.distance
	_press(game, KEY_RIGHT, true)
	_advance(game, 1.0)
	_press(game, KEY_RIGHT, false)
	_check(game.distance == parked and is_zero_approx(game.hero_x), "the slide waits and no leaning happens while the roll tumbles away")
	_advance(game, Game.WRAP_SECONDS)
	_check(game.distance > parked, "then the traveller slides on from the middle")
	var clear := true
	for thing: Dictionary in game.things:
		if float(thing.at) > parked and float(thing.at) < parked + game.speed() * 1.1 and str(thing.kind) != "pillow":
			clear = clear and bool(thing.taken)
	_check(clear, "the slide just past a spring roll is cleared")
	var again := _playing("standard")
	for crash in 2:
		var next: Dictionary = {}
		for thing: Dictionary in again.things:
			if str(thing.kind) in ["cat", "roller"] and not bool(thing.taken) and not bool(thing.hit) and float(thing.at) > again.distance:
				next = thing
				break
		next.x = again.hero_x
		next.kind = "cat"
		_advance(again, (float(next.at) - again.distance) / again.speed() + 0.02)
		_advance(again, Game.WRAP_SECONDS)
	_check(again.crashes == 2 and again.mistakes == 1, "a second spring roll counts as a mistake")


func _rolling_cats_and_forts() -> void:
	var game := _playing("standard")
	game.things.clear()
	game.things.append(game._thing("roller", game.distance + game.speed() * 2.0, 0.4))
	game.hero_x = -0.1
	var cat: Dictionary = game.things[0]
	_advance(game, 2.0 - Game.ROLL_LEAD + 0.05)
	_check(float(cat.roll_at) > 0.0 and float(cat.to) < 0.4, "a rolling cat rolls over toward the traveller once they are close")
	_advance(game, Game.ROLL_SECONDS + 0.02)
	_check(absf(game.thing_x(cat) - float(cat.to)) < 0.001, "and lands in its new spot")
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.4)
	_press(game, KEY_RIGHT, false)
	_advance(game, 0.4)
	_check(not bool(cat.hit) and game.crashes == 0, "there is time to lean round it after the tail flick")
	var fort := _playing("standard")
	fort.things.clear()
	fort.things.append(fort._thing("fort", fort.distance + 3.0, 0.0))
	fort.hero_x = 0.6
	_advance(fort, (3.0 + Game.FORT_LENGTH) / fort.speed() + 0.1)
	_check(fort.crashes == 0, "leaning to one lane passes a blanket fort")
	var bump := _playing("standard")
	bump.things.clear()
	bump.things.append(bump._thing("fort", bump.distance + 2.0, 0.0))
	bump.hero_x = 0.6
	_advance(bump, 2.5 / bump.speed())
	_press(bump, KEY_LEFT, true)
	_advance(bump, 0.5)
	_press(bump, KEY_LEFT, false)
	_check(bump.crashes == 1, "leaning into a fort's side wraps the traveller too")


func _the_slide_steepens() -> void:
	var game := _playing("standard")
	var early := game.speed()
	game.play_time = game.round_seconds * 0.95
	_check(game.speed() > early * 1.8, "the slide runs much faster by the end")
	var plain := _playing("standard")
	for planned in 40:
		plain.distance = float(plain.things.back().at)
		plain._plan()
	_check(plain.things.all(func(thing: Dictionary) -> bool: return str(thing.kind) in ["cat", "pillow"]), "the opening stretch has only sleeping cats and pillows")
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.6
	var kinds := {}
	for planned in 200:
		late.distance = float(late.things.back().at)
		late._plan()
	for thing: Dictionary in late.things:
		kinds[thing.kind] = int(kinds.get(thing.kind, 0)) + 1
	_check(int(kinds.get("roller", 0)) > 10 and int(kinds.get("fort", 0)) > 10, "later the cats roll over and forts split the slide: %s" % [kinds])


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "cats", "forts"], "three variants are declared")
	var counts := {}
	for variant_id: String in ["standard", "cats", "forts"]:
		var game := _playing(variant_id)
		game.play_time = game.round_seconds * 0.5
		var tally := {}
		for planned in 200:
			game.distance = float(game.things.back().at)
			game._plan()
		for thing: Dictionary in game.things:
			tally[thing.kind] = int(tally.get(thing.kind, 0)) + 1
		counts[variant_id] = tally
	_check(int(counts.cats.get("cat", 0)) + int(counts.cats.get("roller", 0)) > int(counts.standard.get("cat", 0)) + int(counts.standard.get("roller", 0))
		and int(counts.forts.get("fort", 0)) > int(counts.standard.get("fort", 0)), "the cat nap brings more cats and the fort maze more forts: %s" % [counts])
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.speed() < standard.speed() * 0.8, "assist slows the slide")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "cats", "forts"]:
		var gold := _play(session, variant_id, false, 0.05, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp rider earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.4, 0.25)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow, wobbly rider still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0, 0.0)
	_check(not idle.success and idle.score == 0, "never leaning earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.05, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("sheet slide scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Where a rider who sees `look` seconds ahead wants to be: away from the
## nearest cat or fort in that window, else on the nearest pillow.
func _aim(game: Game, look: float) -> float:
	var reach := game.distance + game.speed() * look
	for thing: Dictionary in game.things:
		var at := float(thing.at)
		if bool(thing.taken) or bool(thing.hit) or at + (Game.FORT_LENGTH if str(thing.kind) == "fort" else 0.0) < game.distance or at > reach:
			continue
		match str(thing.kind):
			"cat", "roller":
				var x := game.thing_x(thing)
				if absf(game.hero_x - x) < Game.HERO + Game.CAT + 0.12:
					return clampf(x + (0.42 if game.hero_x >= x else -0.42), -0.8, 0.8) if absf(x) < 0.38 or signf(game.hero_x - x) * x <= 0.0 else clampf(x - signf(x) * 0.42, -0.8, 0.8)
			"fort":
				return 0.6 if game.hero_x >= 0.0 else -0.6
	for thing: Dictionary in game.things:
		if str(thing.kind) == "pillow" and not bool(thing.taken) and float(thing.at) > game.distance and float(thing.at) < reach + game.speed() * 0.6:
			return float(thing.x)
	return game.hero_x


## Play a whole round through Session key presses: every `react` seconds the
## rider picks a spot (missing by up to `wobble`) and leans toward it; a
## negative `react` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, react: float, wobble: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-086", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 5
	var held := 0
	var next_think := 0.0
	var target := 0.0
	while not session.ended and game.stage == "play":
		if react >= 0.0 and game.clock >= next_think:
			next_think = game.clock + react
			target = _aim(game, 0.75 + react) + aim.randf_range(-wobble, wobble)
		var want := 0
		if react >= 0.0:
			var error := target - game.hero_x - game.drift * 0.1
			want = 1 if error > 0.04 else (-1 if error < -0.04 else 0)
		if want != held:
			if held != 0:
				_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			held = want
		session._process(STEP)
	if held != 0:
		_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
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


func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		for round_seed in 40:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 60.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 80 seeded rounds: %s" % [scored])


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


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
