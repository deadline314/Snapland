extends SceneTree
## 蜂巢調音 rules: the countdown demo, walking, bees fleeing, homing and
## streaks, the contrary bee, stings (caught by the contrary bee, surrounded), escalation,
## variants, assist, no points without input and full simulated rounds.

const Game = preload("res://game/minigames/arcade/bee_herd_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const ROUND_STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_bee()
	_untouched_rounds_never_score()
	_walking_and_fleeing()
	_homing_and_streaks()
	_the_contrary_bee()
	_stings()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: bee herd demo, walking, fleeing bees, homing and streaks, contrary bee, stings, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_bee() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [45, 100, 140] and game.bees.size() == 1, "a round opens with one demo bee below the hive")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_UP)
		game.step(STEP)
	_check(game.bees.is_empty() and game.score == 0 and game.swell.is_empty(), "the countdown shoos the demo bee home by itself and scores nothing")
	while game.stage == "ready":
		game.step(STEP)
	var clear := game.bees.all(func(bee: Dictionary) -> bool: return Vector2(bee.pos).distance_to(game.hero) > 0.25 and Vector2(bee.pos).distance_to(Game.HIVE) > 0.15)
	_check(game.stage == "play" and game.hero == Game.HERO_START and game.bees.size() == Game.START_BEES and clear,
		"play starts at the front with every bee well away from the traveller and the hive")


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


func _walking_and_fleeing() -> void:
	var game := _playing("standard")
	_press(game, KEY_UP, true)
	_advance(game, 0.4)
	_press(game, KEY_UP, false)
	_check(game.hero.y < Game.HERO_START.y - 0.1, "↑ walks the traveller toward the hive")
	var pad := _playing("standard")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	pad.handle_input(stick, Vector2.ZERO)
	var dpad := _playing("standard")
	var left := InputEventJoypadButton.new()
	left.button_index = JOY_BUTTON_DPAD_LEFT
	left.pressed = true
	dpad.handle_input(left, Vector2.ZERO)
	_advance(pad, 0.4)
	_advance(dpad, 0.4)
	_check(pad.hero.x > 0.55 and dpad.hero.x < 0.45, "the gamepad stick and D-pad walk too")
	var flee := _playing("standard")
	flee.bees = [flee._bee(Vector2(0.5, 0.5), false)]
	flee.hero = Vector2(0.5, 0.62)
	_advance(flee, 0.5)
	_check(Vector2(flee.bees[0].pos).y < 0.44, "a bee flutters away from the traveller")


func _homing_and_streaks() -> void:
	var game := _playing("standard")
	game.bees = [game._bee(Game.HIVE + Vector2(0, 0.1), false), game._bee(Game.HIVE + Vector2(0.02, 0.12), false), game._bee(Game.HIVE + Vector2(-0.02, 0.14), false)]
	game.hero = Game.HIVE + Vector2(0, 0.22)
	_advance(game, 0.8)
	_check(game.homes == 3 and game.bees.is_empty() and game.score == Game.HOME_POINTS * 3 + Game.STREAK_POINTS * 3 and game.homed.size() == 3,
		"bees shooed into the hive score, faster in a quick streak")


func _the_contrary_bee() -> void:
	var game := _playing("standard")
	game.play_time = game.round_seconds * 0.3
	game._next_spawn = 0.0
	game._spawn()
	var grumpy: Array = game.bees.filter(func(bee: Dictionary) -> bool: return bee.contrary)
	_check(grumpy.size() == 1, "after a while one contrary bee joins in")
	var chaser := _playing("standard")
	chaser.bees = [chaser._bee(Vector2(0.5, 0.4), true)]
	chaser.hero = Vector2(0.5, 0.7)
	var before := Vector2(chaser.bees[0].pos).distance_to(chaser.hero)
	_advance(chaser, 0.8)
	_check(Vector2(chaser.bees[0].pos).distance_to(chaser.hero) < before - 0.08, "the contrary bee flies at the traveller, not away")
	var never := _playing("standard")
	never.bees = [never._bee(Game.HIVE + Vector2(0, 0.02), true)]
	never.hero = Vector2(0.5, 0.9)
	_advance(never, 0.2)
	_check(never.homes == 0, "the contrary bee never goes home")


func _stings() -> void:
	var game := _playing("standard")
	game.bees = [game._bee(game.hero + Vector2(0, -0.03), true)]
	_advance(game, 0.05)
	_check(game.stings == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.busy() and not game.snapshot().word_good,
		"the contrary bee catching the traveller stings; the first sting is a free look")
	var hero := game.hero
	_press(game, KEY_LEFT, true)
	_advance(game, 0.5)
	_press(game, KEY_LEFT, false)
	_check(game.hero == hero, "nobody walks while the face is swollen")
	_advance(game, Game.SWELL_SECONDS)
	game.bees = [game._bee(game.hero + Vector2(0, 0.02), true)]
	_advance(game, 0.05)
	_check(game.stings == 2 and game.mistakes == 1, "a second sting counts as a mistake")
	var smug := _playing("standard")
	smug.bees = [smug._bee(smug.hero + Vector2(0, -0.03), true)]
	_advance(smug, 0.05)
	var culprit: Dictionary = smug.bees[0]
	_advance(smug, Game.SWELL_SECONDS + 0.2)
	_check(smug.stings == 1 and Vector2(culprit.pos).distance_to(smug.hero) > 0.15 and smug.swell.by == "grump",
		"after stinging, the contrary bee flies off smugly instead of stinging again")
	var crowd := _playing("standard")
	crowd.hero = Vector2(0.5, 0.5)
	crowd.bees = [crowd._bee(Vector2(0.44, 0.5), false), crowd._bee(Vector2(0.56, 0.5), false), crowd._bee(Vector2(0.5, 0.44), false)]
	for bee in crowd.bees:
		bee.vel = (crowd.hero - Vector2(bee.pos)) * 3.0
	_advance(crowd, 0.05)
	_check(crowd.stings == 1 and crowd.swell.by == "crowd", "three bees crowding round sting too")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.bee_speed()
	game.play_time = game.round_seconds * 0.95
	_check(game.bee_speed() > early * 1.25, "bees fly faster later on")
	var spawner := _playing("standard")
	spawner.play_time = spawner.round_seconds * 0.9
	var before := spawner.bees.size()
	spawner._next_spawn = 0.0
	spawner._spawn()
	_check(spawner.bees.size() == before + 1 and spawner._next_spawn - spawner.play_time < Game.SPAWN_FIRST * 0.6, "new bees keep coming off the flowers, faster later")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "breeze", "swarm"], "three variants are declared")
	var swarm := _playing("swarm")
	_check(swarm.bees.size() > Game.START_BEES, "swarm day starts with more bees")
	var breeze := _playing("breeze")
	var calm := _playing("standard")
	var gusts: Array[float] = []
	for at: float in [1.0, 8.0]:
		breeze.clock = at
		calm.clock = at
		gusts.append(breeze.breeze_push().x)
		_check(calm.breeze_push() == Vector2.ZERO, "a calm day has no breeze")
	_check(absf(gusts[0]) > 0.05 and gusts[0] * gusts[1] < 0.0, "the breeze nudges bees one way, then the other: %s" % [gusts])
	var helped := _playing("standard", true)
	var plain := _playing("standard")
	_check(helped.hum_radius() > plain.hum_radius() * 1.2 and helped.bee_speed() < plain.bee_speed() * 0.8, "assist lets the hive hum bees in from further and slows them")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	# Herding scores swing from round to round with where the bees fly, so each
	# case is judged on the average of four seeded rounds.
	var lines: Array = []
	var gold_means: Array[int] = []
	for variant_id: String in ["standard", "breeze", "swarm"]:
		var rounds := _rounds(session, variant_id, false, 1.0)
		lines = rounds[0].score_summary.thresholds
		var best: Dictionary = rounds.reduce(func(a: Dictionary, b: Dictionary) -> Dictionary: return a if a.score >= b.score else b)
		gold_means.append(_mean(rounds))
		_check(_mean(rounds) >= lines[2] and best.success and best.devil and best.ordinary_eligible and best.score_summary.medal == 3
			and best.score_summary.rows.size() == 1, "a patient herder earns gold in the %s variant (scores %s)" % [variant_id, _scores(rounds)])
	var quitter := _rounds(session, "standard", false, 0.25)
	var bronze_rounds := quitter.filter(func(r: Dictionary) -> bool: return r.score_summary.medal == 1 and r.success and not r.devil)
	_check(_mean(quitter) >= lines[0] and _mean(quitter) < lines[1] and not bronze_rounds.is_empty(),
		"a herder who gives up early still earns bronze (scores %s)" % _scores(quitter))
	var idle := _play(session, "standard", 0, false, 0.0)
	_check(not idle.success and idle.score == 0, "never moving earns nothing (score %d)" % idle.score)
	var helped := _rounds(session, "standard", true, 1.0)
	_check(_mean(helped) >= lines[2] and helped.all(func(r: Dictionary) -> bool: return r.assisted and not r.devil)
		and helped.any(func(r: Dictionary) -> bool: return r.success and r.score_summary.medal == 3),
		"assisted gold rounds never award the devil sticker (scores %s)" % _scores(helped))
	print("bee herd scores: gold means %s, bronze %s, idle %d, assisted %s" % [gold_means, _scores(quitter), idle.score, _scores(helped)])
	session.free()


## Four rounds on the first four seeds that roll the named variant.
func _rounds(session: Session, variant_id: String, assisted: bool, quit_at: float) -> Array[Dictionary]:
	var played: Array[Dictionary] = []
	for nth in 4:
		played.append(_play(session, variant_id, nth, assisted, quit_at))
	return played


func _mean(rounds: Array[Dictionary]) -> int:
	var total := 0
	for result in rounds:
		total += int(result.score)
	return total / rounds.size()


func _scores(rounds: Array[Dictionary]) -> String:
	return str(rounds.map(func(r: Dictionary) -> int: return r.score))


## Play a whole round through Session key presses, re-reading the bed every
## 0.05 s with the herding bot below, until `quit_at` of the round has gone
## (0 never presses anything).
func _play(session: Session, variant_id: String, nth: int, assisted: bool, quit_at: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-078", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id, nth)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(ROUND_STEP)
	var held := {KEY_LEFT: false, KEY_RIGHT: false, KEY_UP: false, KEY_DOWN: false}
	var next_think := 0.0
	while not session.ended and game.stage == "play":
		if game.clock >= next_think:
			next_think = game.clock + 0.05
			var want := _herd(game) if game.play_time < game.round_seconds * quit_at else Vector2.ZERO
			var wanted := {KEY_LEFT: want.x < -0.3, KEY_RIGHT: want.x > 0.3, KEY_UP: want.y < -0.3, KEY_DOWN: want.y > 0.3}
			for key: int in held:
				if wanted[key] != held[key]:
					_session_key(session, key, wanted[key])
					held[key] = wanted[key]
		session._process(ROUND_STEP)
	for key: int in held:
		if held[key]:
			_session_key(session, key, false)
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


## Which way to walk now: circle round outside the flee ring to the far side
## of the bee nearest the hive, then walk straight in so it flees home.
func _herd(game: Game) -> Vector2:
	var target: Dictionary = {}
	var best := INF
	for bee: Dictionary in game.bees:
		if bee.contrary:
			continue
		var cost := Vector2(bee.pos).distance_to(Game.HIVE) + 0.5 * Vector2(bee.pos).distance_to(game.hero)
		if cost < best:
			best = cost
			target = bee
	var want := Vector2.ZERO
	if not target.is_empty():
		var bee := Vector2(target.pos)
		var out := (bee - Game.HIVE).normalized()
		var rel := game.hero - bee
		if rel.normalized().dot(out) > 0.9:
			want = (bee - game.hero).normalized()
		else:
			var turn := clampf(wrapf(out.angle() - rel.angle(), -PI, PI), -0.7, 0.7)
			var ring := maxf(game.flee_radius() + 0.05, rel.length() * 0.9)
			want = (bee + Vector2.from_angle(rel.angle() + turn) * ring - game.hero).normalized()
	for bee: Dictionary in game.bees:
		var gap := game.hero - Vector2(bee.pos)
		if bee.contrary and gap.length() < 0.3:
			want += gap.normalized() * 4.0 * (1.0 - gap.length() / 0.3)
	return want.normalized() if want.length() > 0.02 else Vector2.ZERO


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
