extends SceneTree
## 追光躲步 rules: hopping and held steps, scoring in the light and the step
## combo, darts, shrinking and splitting lights, the dark ring and blackout,
## escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/spot_dance_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0
const KEYS := {Vector2i(-1, 0): KEY_LEFT, Vector2i(1, 0): KEY_RIGHT, Vector2i(0, -1): KEY_UP, Vector2i(0, 1): KEY_DOWN}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_hops_and_held_steps()
	_the_light_scores_and_steps_combo()
	_the_dark_ring_and_blackout()
	_lights_dart_shrink_and_split()
	_variants_change_the_lights()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: spot dance hops, held steps, light, combo, darts, shrink, split, dark ring, blackout eyes, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("solo", false)
	_check(game.stage == "ready" and game.thresholds == [250, 560, 740] and game.tile == Vector2i(3, 1), "a round opens mid-floor with its medal lines declared")
	_key(game, KEY_LEFT, true)
	_advance(game, Base.READY_SECONDS - 0.1)
	_key(game, KEY_LEFT, false)
	_check(game.hop_at > 0.0 and game.score == 0 and game.blackouts == 0, "the countdown hops after the light by itself; presses do nothing yet")
	_advance(game, 0.2)
	_check(game.stage == "play" and game.tile == Vector2i(3, 1) and game.lights.size() == 1 and game.is_lit(game.tile), "play starts in the middle of the floor, in the light")


func _hops_and_held_steps() -> void:
	var game := _playing("solo")
	_tap(game, KEY_LEFT)
	_check(game.tile == Vector2i(2, 1) and game.hop_from == Vector2i(3, 1), "one press is one step")
	_tap(game, KEY_UP)
	_tap(game, KEY_UP)
	_check(game.tile == Vector2i(2, 0), "the floor's edge stops a step")
	_key(game, KEY_RIGHT, true)
	_advance(game, Game.REPEAT_DELAY + Game.REPEAT_EVERY * 2.0 + 0.02)
	_key(game, KEY_RIGHT, false)
	_check(game.tile == Vector2i(6, 0), "holding a direction keeps stepping (%s)" % game.tile)


func _the_light_scores_and_steps_combo() -> void:
	var game := _playing("solo")
	_pin(game, [Vector2(3, 1)])
	_advance(game, 2.0)
	_check(game.score == 0, "standing still in the light scores nothing: only dancing counts")
	_pin(game, [Vector2(3, 1), Vector2(2, 1)])
	_tap(game, KEY_LEFT)
	var stepped := game.score
	_advance(game, Game.DANCE_GRACE - 0.05)
	_check(game.score - stepped >= 8 and game.score - stepped <= 10, "dancing in the light scores about %d a second (%d)" % [int(Game.LIT_RATE), game.score - stepped])
	_advance(game, 1.0)
	_check(game.score - stepped <= 11, "and stops when the dancing stops")
	_pin(game, [Vector2(3.5, 1)])
	game.tile = Vector2i(3, 1)
	game.combo = 0
	var before := game.score
	_tap(game, KEY_RIGHT)
	_tap(game, KEY_LEFT)
	_tap(game, KEY_RIGHT)
	_check(game.combo == 3 and game.score - before == 3 * Game.STEP_POINTS + 0 + 1 + 2, "each step landing in the light adds points and builds a combo (%d)" % (game.score - before))
	_pin(game, [Vector2(0, 0)])
	_tap(game, KEY_RIGHT)
	_advance(game, STEP * 2.0)
	_check(game.combo == 0 and not game.lit, "stepping into the dark breaks the combo")


func _the_dark_ring_and_blackout() -> void:
	var game := _playing("solo")
	_pin(game, [Vector2(0, 0)])
	game.tile = Vector2i(6, 2)
	var points := game.score
	_advance(game, Game.DARK_EARLY - 0.1)
	_check(game.phase == "dance" and game.snapshot().dark > 0.8 and game.score == points, "in the dark nothing scores and the ring fills")
	_advance(game, 0.15)
	_check(game.phase == "blackout" and game.blackouts == 1 and game.mistakes == 0 and game.fail_at >= 0.0, "too long in the dark: the lights die; the first time is free")
	_tap(game, KEY_LEFT)
	_check(game.tile == Vector2i(6, 2), "nobody dances in the blackout")
	_advance(game, Game.BLACKOUT_SECONDS + 0.05)
	_check(game.phase == "dance" and game.is_lit(game.tile), "the lights come back up on the hero")
	_pin(game, [Vector2(0, 0)])
	_advance(game, Game.DARK_EARLY + 0.2)
	_check(game.blackouts == 2 and game.mistakes == 1, "later blackouts are mistakes")
	var helped := _round("solo", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.dark_limit() > Game.DARK_EARLY * 1.4, "assist allows longer in the dark")


func _lights_dart_shrink_and_split() -> void:
	var game := _playing("solo")
	var early_speed := game.speed()
	var early_radius := game.radius()
	var headings := 0
	var last: Vector2 = game.lights[0].vel.normalized()
	var split_at := -1.0
	while game.stage == "play":
		_pin_hero_to_light(game)
		game.step(STEP)
		if game.lights.size() == 1:
			var now_heading: Vector2 = game.lights[0].vel.normalized()
			if now_heading.dot(last) < 0.2 and absf(now_heading.dot(last)) < 0.99:
				headings += 1
			last = now_heading
		elif split_at < 0.0:
			split_at = game.heat()
	_check(game.speed() > early_speed * 2.0 and game.radius() < early_radius * 0.6, "the light speeds up and shrinks (%.2f -> %.2f tiles)" % [early_radius, game.radius()])
	_check(headings >= 3, "the light darts off in new directions (%d)" % headings)
	_check(split_at >= 0.45 and split_at < 0.6 and game.lights.size() == 2, "mid-round the light splits in two")
	var crossing := _playing("twins")
	var crossed := false
	while crossing.stage == "play":
		_pin_hero_to_light(crossing)
		crossing.step(STEP)
		if crossing.lights.size() == 2 and crossing.lights[0].pos.distance_to(crossing.lights[1].pos) < 0.5 and crossing.heat() > 0.3:
			crossed = true
	_check(crossed, "the twin lights cross each other")


func _variants_change_the_lights() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["solo", "twins", "jumpy"], "three variants are declared")
	var splits := {}
	var darts := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var turns := 0
		var dart_marks := {}
		while game.stage == "play":
			_pin_hero_to_light(game)
			game.step(STEP)
			if splits.get(variant_id, -1.0) < 0.0 and game.lights.size() == 2:
				splits[variant_id] = game.heat()
			for light: Dictionary in game.lights:
				dart_marks[light.dart_at] = true
		darts[variant_id] = dart_marks.size()
	_check(splits.twins < 0.3 and splits.solo > splits.twins, "twin lights split early (%s)" % splits)
	_check(darts.jumpy > darts.solo * 1.4, "the jumpy light darts far more often (%s)" % darts)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["solo", "twins", "jumpy"]:
		# Gold: steps toward the nearest light every 0.3 s.
		var gold := _play(session, variant_id, false, 0.3)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a quick dancer earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: only reacts every 0.7 s.
	var bronze := _play(session, "solo", false, 0.7)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a slow dancer still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "solo", false, 99.0)
	_check(not idle.success and idle.score == 0 and idle.mistakes > 3, "an untouched round scores nothing and loses the light again and again (score %d)" % idle.score)
	var helped := _play(session, "solo", true, 0.3)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("spot dance scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session input: every `every` seconds, step one
## tile toward the nearest light (columns first).
func _play(session: Session, variant_id: String, assisted: bool, every: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-054", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var last := -99.0
	while not session.ended and game.stage == "play":
		if game.clock - last >= every and game.phase == "dance":
			last = game.clock
			var target := game._nearest_light(game.tile)
			var step := Vector2i(signi(roundi(target.x) - game.tile.x), 0)
			if step.x == 0:
				step = Vector2i(0, signi(roundi(target.y) - game.tile.y))
			if step != Vector2i.ZERO:
				for pressed: bool in [true, false]:
					var key := InputEventKey.new()
					key.physical_keycode = KEYS[step]
					key.pressed = pressed
					session._unhandled_input(key)
		_run_session(session, STEP)
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


## Hold the lights still at these tile positions.
func _pin(game: Game, spots: Array) -> void:
	game.lights.clear()
	for spot: Vector2 in spots:
		game.lights.append({"pos": spot, "vel": Vector2.ZERO, "dart_at": 9999.0})


func _pin_hero_to_light(game: Game) -> void:
	game.tile = Vector2i(roundi(game.lights[0].pos.x), roundi(game.lights[0].pos.y))


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
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
	_key(game, code, true)
	_key(game, code, false)


func _key(game: Base, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
