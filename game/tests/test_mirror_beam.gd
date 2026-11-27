extends SceneTree
## 折鏡迷箱 rules: tilting the mirror, the beam and pillars, popping balloons
## and gold balloons, balloons keeping to the sides (so an untouched round never
## scores), the face tan, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/mirror_beam_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_untouched_rounds_never_score()
	_tilting_steers_the_beam()
	_balloons_pop_and_gold_needs_two_seconds()
	_too_far_tans_the_face()
	_it_gets_busier()
	_variants_change_the_ring()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: mirror beam tilt, beam, pillars, pops, gold balloons, sides only, face tan, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [130, 360, 600] and game.tilt == 0.0, "a round opens with the mirror level and its medal lines declared")
	_key(game, KEY_LEFT, true)
	_advance(game, Base.READY_SECONDS - 0.1)
	_key(game, KEY_LEFT, false)
	_check(game.tilt > 0.3 and game.score == 0 and game.balloons.size() <= 1, "the countdown tilts the mirror by itself and pops a balloon for show; presses do nothing yet")
	_advance(game, 0.2)
	_check(game.stage == "play" and game.tilt == 0.0 and game.balloons.is_empty() and game.beam_direction().is_equal_approx(Vector2.UP), "play starts level, the beam going straight back up")
	var eager := _round("standard", false)
	_key(eager, KEY_RIGHT, true)
	_advance(eager, Base.READY_SECONDS + 0.3)
	_check(eager.turn == 1 and eager.tilt > 0.2, "an arrow held through the countdown turns the mirror as play begins")


func _untouched_rounds_never_score() -> void:
	for round_seed in 24:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		var closest := 999.0
		while game.stage != "done":
			game.step(0.05)
			for balloon: Dictionary in game.balloons:
				closest = minf(closest, absf(float(balloon.at.x) - Game.MIRROR.x))
		_check(game.score == 0 and game.pops == 0, "an untouched round scores nothing (seed %d, %d)" % [round_seed, game.score])
		_check(closest >= Game.SIDE_GAP - 0.5, "balloons never float into the middle column (seed %d, %.0f px)" % [round_seed, closest])


func _tilting_steers_the_beam() -> void:
	var game := _playing("standard")
	_key(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_check(absf(game.tilt - Game.TURN_SPEED * 0.3) < 0.03 and game.beam_direction().x > 0.5, "holding right tilts the mirror and swings the beam right")
	_key(game, KEY_LEFT, true)
	var held := game.tilt
	_advance(game, 0.2)
	_check(is_equal_approx(game.tilt, held), "both arrows at once hold it still")
	_key(game, KEY_RIGHT, false)
	_key(game, KEY_LEFT, false)
	game.tilt = 0.0
	_aim(game, Vector2(800, 300))
	game._trace()
	_check(game.beam_end.distance_to(Game.MIRROR) > 300.0, "an open line reaches far across the ring")
	_aim(game, Vector2(1000, 420))
	game._trace()
	var stops := false
	for pillar: Rect2 in game.pillars:
		stops = stops or pillar.grow(10.0).has_point(game.beam_end)
	_check(stops and game.beam_end.distance_to(Game.MIRROR) < 360.0, "a pillar stops the beam")


func _balloons_pop_and_gold_needs_two_seconds() -> void:
	var game := _playing("standard")
	game._next_spawn = 999.0
	game.balloons = [_still(game, Vector2(800, 300), false)]
	_aim(game, Vector2(800, 300))
	_advance(game, Game.POP_SECONDS + 0.05)
	_check(game.pops == 1 and game.score == Game.BALLOON_POINTS, "a balloon in the beam pops in a moment")
	game.balloons = [_still(game, Vector2(1000, 420), false)]
	_aim(game, Vector2(1000, 420))
	_advance(game, 0.5)
	_check(game.pops == 1, "a balloon behind a pillar is safe")
	game.balloons = [_still(game, Vector2(470, 260), true)]
	_aim(game, Vector2(470, 260))
	_advance(game, Game.GOLD_SECONDS - 0.3)
	_check(game.pops == 1 and float(game.balloons[0].lit) > 1.0, "a gold balloon takes longer")
	game.tilt = 0.0
	_advance(game, 0.1)
	_check(float(game.balloons[0].lit) == 0.0, "and starts over when the light leaves it")
	_aim(game, Vector2(470, 260))
	_advance(game, Game.GOLD_SECONDS + 0.05)
	_check(game.golds == 1 and game.score == Game.BALLOON_POINTS + Game.GOLD_POINTS, "two seconds in a row pops it for a big score")


func _too_far_tans_the_face() -> void:
	var game := _playing("standard")
	game._next_spawn = 999.0
	game.tilt = Game.FACE_TILT + 0.02
	_advance(game, Game.FACE_SECONDS - 0.1)
	_check(game.phase == "aim" and game.face_lit(), "tilted too far, the light lands on the hero's face")
	_advance(game, 0.15)
	_check(game.phase == "tanned" and game.tans == 1 and game.mistakes == 0 and game.fail_at >= 0.0, "and leaves a sunglasses tan; the first is free")
	_key(game, KEY_RIGHT, true)
	_advance(game, Game.TAN_SECONDS - 0.2)
	_check(game.phase == "tanned" and game.tilt == Game.FACE_TILT + 0.02, "the mirror can't move while the hero rubs their eyes")
	_key(game, KEY_RIGHT, false)
	_advance(game, 0.3)
	_check(game.phase == "aim" and game.tilt == 0.0, "then it comes back level")
	game.tilt = -Game.FACE_TILT - 0.02
	_advance(game, Game.FACE_SECONDS + 0.05)
	_check(game.tans == 2 and game.mistakes == 1, "later tans are mistakes")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	helped.tilt = Game.FACE_TILT + 0.02
	_advance(helped, Game.FACE_SECONDS + 0.05)
	_check(helped.phase == "aim", "assist gives longer before the tan")


func _it_gets_busier() -> void:
	var game := _playing("standard")
	var early := 0
	var late := 0
	var early_speed := 0.0
	var late_speed := 0.0
	var seen := {}
	while game.stage == "play":
		game.step(STEP)
		for balloon: Dictionary in game.balloons:
			if seen.has(balloon.id):
				continue
			seen[balloon.id] = true
			if game.heat() < 0.3:
				early += 1
				early_speed = maxf(early_speed, Vector2(balloon.vel).length())
			elif game.heat() > 0.7:
				late += 1
				late_speed = maxf(late_speed, Vector2(balloon.vel).length())
			# Clear it at once, so only the spawn rate limits how many come.
			balloon.popped_at = game.clock
	_check(late > early * 1.5 and late_speed > early_speed * 1.8, "more balloons come and they drift faster (%d vs %d, %.0f vs %.0f px/s)" % [early, late, early_speed, late_speed])


func _variants_change_the_ring() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "pillars", "golden"], "three variants are declared")
	_check(_playing("pillars").pillars.size() > _playing("standard").pillars.size(), "the pillar maze has more pillars")
	var golds := {}
	for index: int in [0, 2]:
		var count := 0
		for attempt in 6:
			var game := Game.new()
			game.round_seed = 100 + attempt
			game.reset(false, "noon")
			game.variant = game.variants[index]
			var seen := {}
			while game.stage != "done":
				game.step(0.05)
				for balloon: Dictionary in game.balloons:
					if not seen.has(balloon.id):
						seen[balloon.id] = true
						count += int(bool(balloon.gold))
						balloon.popped_at = game.clock
		golds[game_variant_id(index)] = count
	_check(golds.golden > golds.standard * 1.5, "the golden night has far more gold balloons (%s)" % golds)


func game_variant_id(index: int) -> String:
	return str(Game.new().variants[index].id)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "pillars", "golden"]:
		# Gold: follows its balloon and picks the next one 0.15 s after a pop.
		var gold := _play(session, variant_id, false, 0.15, 0.02)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady hand earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: takes 1.3 s to pick each next balloon and is happy with a rough line.
	var bronze := _play(session, "standard", false, 1.3, 0.08)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a slow aimer still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 0.15, 0.02)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("mirror beam scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: every `every` seconds pick the
## open balloon closest to where the mirror points, then turn toward it until
## within `tolerance`.
func _play(session: Session, variant_id: String, assisted: bool, every: float, tolerance: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-056", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var goal := 0.0
	var chosen := -1
	var lost_at := -99.0
	var held := 0
	while not session.ended and game.stage == "play":
		var target := _find(game, chosen)
		if target.is_empty():
			if chosen >= 0:
				chosen = -1
				lost_at = game.clock
			if game.clock - lost_at >= every:
				chosen = _best_id(game)
				target = _find(game, chosen)
		if not target.is_empty():
			var offset: Vector2 = target.at - Game.MIRROR
			goal = clampf(atan2(offset.x, -offset.y) * 0.5, -Game.FACE_TILT + 0.03, Game.FACE_TILT - 0.03)
		var want := 0
		if game.phase == "aim" and absf(goal - game.tilt) > tolerance:
			want = 1 if goal > game.tilt else -1
		if want != held:
			if held != 0:
				_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			held = want
		_run_session(session, STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	if held != 0:
		_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


## A live, open balloon by id, or an empty dictionary.
func _find(game: Game, id: int) -> Dictionary:
	for balloon: Dictionary in game.balloons:
		if int(balloon.id) == id and float(balloon.popped_at) < 0.0 and not _blocked(game, balloon.at):
			var offset: Vector2 = balloon.at - Game.MIRROR
			if absf(atan2(offset.x, -offset.y) * 0.5) < Game.FACE_TILT - 0.03:
				return balloon
	return {}


## The open balloon nearest the current aim.
func _best_id(game: Game) -> int:
	var best := -1
	var gap := 99.0
	for balloon: Dictionary in game.balloons:
		if float(balloon.popped_at) >= 0.0:
			continue
		var offset: Vector2 = balloon.at - Game.MIRROR
		var want := atan2(offset.x, -offset.y) * 0.5
		if absf(want) >= Game.FACE_TILT - 0.03 or _blocked(game, balloon.at):
			continue
		if absf(want - game.tilt) < gap:
			gap = absf(want - game.tilt)
			best = int(balloon.id)
	return best


func _blocked(game: Game, target: Vector2) -> bool:
	for step in 40:
		var at := Game.MIRROR.lerp(target, step / 40.0)
		for pillar: Rect2 in game.pillars:
			if pillar.has_point(at):
				return true
	return false


func _session_key(session: Session, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


func _aim(game: Game, target: Vector2) -> void:
	var offset := target - Game.MIRROR
	game.tilt = atan2(offset.x, -offset.y) * 0.5


func _still(game: Game, at: Vector2, gold: bool) -> Dictionary:
	var balloon := game._balloon(at, -1 if at.x < 640.0 else 1, gold)
	balloon.vel = Vector2.ZERO
	return balloon


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


func _key(game: Base, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
