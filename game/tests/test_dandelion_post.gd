extends SceneTree
## 蒲公英落郵 rules: the countdown demo, rising and sinking, posting letters
## with centre and streak bonuses, vents and sprinklers, sneezes, escalation,
## variants, assist, no points without input and full simulated rounds.

const Game = preload("res://game/minigames/arcade/dandelion_post_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_letter()
	_untouched_rounds_never_score()
	_rising_and_sinking()
	_posting_letters()
	_air_currents()
	_sneezes()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: dandelion post demo, lift and sink, posting, centre and streak, vents, sprinklers, sneezes, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_letter() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [200, 500, 650], "a round opens with the medal lines")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
	var demo_posted := game.things.any(func(thing: Dictionary) -> bool: return thing.kind == "mailbox" and not thing.flag)
	_check(demo_posted and game.score == 0 and game.sneeze.is_empty(), "the countdown floats up and posts a letter by itself and scores nothing")
	while game.stage == "ready":
		game.step(STEP)
	var nearest := INF
	for thing in game.things:
		nearest = minf(nearest, float(thing.x) - game.hero_at())
	_check(game.stage == "play" and is_equal_approx(game.y, Game.START_Y) and game.vy == 0.0 and nearest > 0.9,
		"play starts mid-air, still, with nothing within a screen")


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


func _rising_and_sinking() -> void:
	var game := _playing("standard")
	_press(game, KEY_SPACE, true)
	_advance(game, 0.3)
	_check(game.vy > 0.2 and game.y > Game.START_Y, "holding space lifts the puff")
	_press(game, KEY_SPACE, false)
	_advance(game, 0.6)
	_check(game.vy < -0.2, "letting go sinks it")
	var up := _playing("standard")
	_press(up, KEY_UP, true)
	_advance(up, 0.3)
	var pad := _playing("standard")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.3)
	_check(up.vy > 0.2 and pad.vy > 0.2, "↑ and the gamepad A button lift it too")
	var idle := _playing("standard")
	_advance(idle, 2.5)
	_check(idle.sneezes == 1 and idle.sneeze.why == "floor", "left alone the puff sinks to the floor and sneezes")


func _posting_letters() -> void:
	var game := _playing("standard")
	game.things = [{"kind": "mailbox", "x": game.hero_at() + 0.01, "y": game.y, "hang": false, "flag": true, "posted_at": -99.0}]
	_advance(game, 0.1)
	_check(game.posted == 1 and not game.things[0].flag and game.score == Game.POST_POINTS + Game.CENTRE_POINTS and game.streak == 1,
		"brushing a waving mailbox posts a letter, dead centre for a bonus")
	game.things.append({"kind": "mailbox", "x": game.hero_at() + 0.01, "y": game.y + 0.05, "hang": true, "flag": true, "posted_at": -99.0})
	var before := game.score
	_advance(game, 0.1)
	_check(game.posted == 2 and game.score - before == Game.POST_POINTS + Game.STREAK_POINTS, "a second letter in a row adds a streak bonus")
	game.things.append({"kind": "mailbox", "x": game.hero_at() + 0.01, "y": game.y, "hang": false, "flag": false, "posted_at": 0.0})
	before = game.score
	_advance(game, 0.1)
	_check(game.score == before, "a mailbox with its flag down takes no letter")
	var far := _playing("standard")
	far.things = [{"kind": "mailbox", "x": far.hero_at() + 0.01, "y": far.y + 0.2, "hang": false, "flag": true, "posted_at": -99.0}]
	_advance(far, 0.1)
	_check(far.posted == 0, "a mailbox far above is missed")


func _air_currents() -> void:
	var still := _playing("standard")
	var vent := _playing("standard")
	var spray := _playing("standard")
	vent.things = [{"kind": "vent", "x": vent.hero_at(), "width": 0.5}]
	spray.things = [{"kind": "sprinkler", "x": spray.hero_at(), "width": 0.5}]
	for game: Game in [still, vent, spray]:
		_advance(game, 0.25)
	_check(vent.vy > still.vy + 0.15 and spray.vy < still.vy - 0.1, "a warm vent pushes the puff up and a sprinkler pushes it down")


func _sneezes() -> void:
	var game := _playing("standard")
	game.things = [{"kind": "cactus", "x": game.hero_at() + 0.01, "top": game.y}]
	_advance(game, 0.1)
	_check(game.sneezes == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.busy() and not game.snapshot().word_good,
		"bumping a cactus sets off a sneeze; the first one is a free look")
	var travel := game.travel
	_advance(game, 0.5)
	_check(is_equal_approx(game.travel, travel), "nothing moves while the traveller falls with the bare stem")
	_advance(game, Game.SNEEZE_SECONDS)
	var clear := game.things.all(func(thing: Dictionary) -> bool: return float(thing.x) > game.hero_at() + 0.45 or float(thing.x) < game.hero_at() - 0.15)
	_check(not game.busy() and game.y > 0.0 and clear, "then a fresh dandelion carries on with a clear stretch ahead")
	game.things = [{"kind": "basket", "x": game.hero_at() + 0.01, "bottom": game.y}]
	_advance(game, 0.1)
	_check(game.sneezes == 2 and game.mistakes == 1, "a second sneeze (into a basket) counts as a mistake")
	var roof := _playing("standard")
	roof.y = 0.98
	_press(roof, KEY_SPACE, true)
	_advance(roof, 0.3)
	_check(roof.sneeze.get("why", "") == "roof", "flying into the roof glass sneezes too")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.drift()
	game.play_time = game.round_seconds * 0.95
	_check(game.drift() > early * 1.6, "the greenhouse drifts by much faster at the end")
	var calm := _playing("standard")
	var hazards_early := 0
	for count in 60:
		calm._next_x = calm.hero_at() + 0.5
		calm.things.clear()
		calm._plan()
		hazards_early += calm.things.filter(func(thing: Dictionary) -> bool: return thing.kind in ["cactus", "basket"]).size()
	var spread_early := 0.0
	var spread_late := 0.0
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.9
	var hazards_late := 0
	for count in 60:
		late._next_x = late.hero_at() + 0.5
		late.things.clear()
		late._plan()
		hazards_late += late.things.filter(func(thing: Dictionary) -> bool: return thing.kind in ["cactus", "basket"]).size()
		for thing in late.things:
			if thing.kind == "mailbox":
				spread_late = maxf(spread_late, absf(float(thing.y) - 0.5))
	for thing in calm.things:
		if thing.kind == "mailbox":
			spread_early = maxf(spread_early, absf(float(thing.y) - 0.5))
	_check(hazards_late > hazards_early and spread_late > 0.3 and spread_early <= 0.21, "later on mailboxes sit higher and lower and more hazards hang about")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "vents", "sprinklers"], "three variants are declared")
	var counts := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		game.play_time = game.round_seconds * 0.5
		var tally := {"vent": 0, "sprinkler": 0}
		for count in 80:
			game._next_x = game.hero_at() + 0.5
			game.things.clear()
			game._plan()
			for thing in game.things:
				if tally.has(thing.kind):
					tally[thing.kind] += 1
		counts[variant_id] = tally
	_check(counts.vents.vent > counts.standard.vent * 1.4 and counts.sprinklers.sprinkler > counts.standard.sprinkler * 1.4,
		"heater day brings more warm vents and watering day more sprinklers")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.body() < standard.body() * 0.7 and helped.window(Game.MAILBOX_REACH) > Game.MAILBOX_REACH * 1.3, "assist trims the bump zone and widens the letter slot")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "vents", "sprinklers"]:
		var gold := _play(session, variant_id, false, 0.05, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady flier earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.4, 0.08)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow, wobbly flier still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0, 0.0)
	_check(not idle.success and idle.score == 0, "never pressing anything earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.05, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("dandelion post scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses: every `react` seconds the
## flier picks a height (the next waving mailbox, missed by up to `wobble`,
## lifted over a cactus or kept under a basket on the way) and holds space while
## below it; a negative `react` never presses anything.
func _play(session: Session, variant_id: String, assisted: bool, react: float, wobble: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-076", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 11
	var held := false
	var next_think := 0.0
	var miss := 0.0
	var aimed_at := -1.0
	while not session.ended and game.stage == "play":
		if react >= 0.0 and game.clock >= next_think:
			next_think = game.clock + react
			var target := _target(game)
			if target.x != aimed_at:
				aimed_at = target.x
				miss = aim.randf_range(-wobble, wobble)
			var want := game.y + game.vy * 0.3 < target.y + miss
			if want != held:
				_session_key(session, KEY_SPACE, want)
				held = want
		session._process(STEP)
	if held:
		_session_key(session, KEY_SPACE, false)
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


## The height to fly at now and the x of what it is aimed at.
func _target(game: Game) -> Vector2:
	var at := game.hero_at()
	var ahead: Array = game.things.filter(func(thing: Dictionary) -> bool: return float(thing.x) > at - 0.03 and thing.kind in ["mailbox", "cactus", "basket"] and (thing.kind != "mailbox" or thing.flag))
	ahead.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
	if ahead.is_empty():
		return Vector2(-1.0, 0.5)
	var next: Dictionary = ahead[0]
	match str(next.kind):
		"cactus":
			return Vector2(float(next.x), maxf(float(next.top) + Game.REACH_Y + 0.12, 0.35))
		"basket":
			return Vector2(float(next.x), minf(float(next.bottom) - Game.REACH_Y - 0.12, 0.65))
	return Vector2(float(next.x), float(next.y))


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
	# These checks set the scene up directly; count the round as steered.
	game._steered = true
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
