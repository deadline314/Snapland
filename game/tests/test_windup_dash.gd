extends SceneTree
## 發條衝刺 rules: winding, the hidden limit, letting go, bursts, rivals, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/windup_dash_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_winding_and_letting_go()
	_the_limit_hides_under_the_cover()
	_greed_bursts_the_spring()
	_rivals_join_later_dashes()
	_variants_change_the_toy()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: windup dash winding, hidden limit, release, bursts, rivals, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.phase == "wind" and game.turns == 0.0 and game.thresholds == [220, 500, 850],
		"a round opens on an unwound toy with its medal lines declared")
	var wound := 0.0
	var ran := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		wound = maxf(wound, game.turns)
		ran = ran or (game.phase == "run" and game.distance > 0.0)
	_check(is_equal_approx(wound, Game.DEMO_TURNS - 1.0) and ran and game.score == 0 and game.dashes_done == 0,
		"the countdown winds and releases the toy by itself, and presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.phase == "wind" and game.dash == 1 and game.turns == 0.0 and game.rival_turns == 0.0,
		"play starts on the first dash with a slack spring and no rival")


func _winding_and_letting_go() -> void:
	var game := _playing("standard")
	for press in 10:
		_tap(game, KEY_SPACE)
	_check(game.turns == 10.0 and is_equal_approx(game.strain(), 10.0 / game.limit) and game.snapshot().turns == 10.0
		and is_equal_approx(game.snapshot().cover_from, Game.COVER_FROM), "every press is one turn and the gauge shows it")
	_tap(game, KEY_X)
	_check(game.phase == "run" and is_equal_approx(game.distance, 5.0) and game.score == 0, "the second button lets go: ten turns run five metres")
	_tap(game, KEY_SPACE)
	_check(game.turns == 10.0, "a running toy cannot be wound")
	_advance(game, game.run_seconds + 0.05)
	_check(game.phase == "rest" and game.score == 50 and game.best == 5.0 and game.dashes_done == 1 and game.snapshot().word_good,
		"the dash is measured when the toy stops: ten points a metre")
	_advance(game, Game.REST_SECONDS + 0.05)
	_check(game.phase == "wind" and game.dash == 2 and game.turns == 0.0, "the next dash starts by itself")
	for press in 4:
		_tap(game, KEY_SPACE)
		_advance(game, 0.2)
	_check(game.phase == "wind" and game.turns == 4.0, "steady pressing keeps hold of the key")
	_advance(game, Game.RELEASE_GAP + 0.05)
	_check(game.phase == "run" and is_equal_approx(game.distance, 2.0), "stopping for a moment lets go too")
	var daring := _playing("standard")
	daring.limit = Game.GAUGE_TURNS
	for press in 20:
		_tap(daring, KEY_SPACE)
	_tap(daring, KEY_DOWN)
	_check(is_equal_approx(daring.distance, 12.0) and daring.metres(16.0) == 8.0,
		"turns wound blind past the cover count double: twenty turns run twelve metres")
	var idle := _playing("standard")
	_tap(idle, KEY_X)
	_advance(idle, 3.0)
	_check(idle.phase == "wind" and idle.dash == 1 and idle.score == 0, "an unwound toy stays put however long nobody presses")


func _the_limit_hides_under_the_cover() -> void:
	var early_low := Game.GAUGE_TURNS
	var late_low := Game.GAUGE_TURNS
	var seen: Dictionary = {}
	for round_seed in 60:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		_advance(game, Base.READY_SECONDS + 0.05)
		early_low = minf(early_low, game.limit)
		seen[snappedf(game.limit, 0.01)] = true
		_check(game.limit >= Game.GAUGE_TURNS * Game.COVER_FROM and game.limit <= Game.GAUGE_TURNS, "the limit always lies in the covered third")
		_advance(game, game.round_seconds - 6.0)
		game._next_dash()
		late_low = minf(late_low, game.limit)
		_check(game.limit >= Game.GAUGE_TURNS * Game.COVER_FROM - 0.001 and game.limit <= Game.GAUGE_TURNS, "late limits stay inside the gauge")
	_check(seen.size() > 40, "the limit changes from dash to dash")
	_check(early_low >= Game.GAUGE_TURNS * Game.LIMIT_LOW_EARLY - 0.001 and late_low < early_low - 1.0,
		"early springs are generous; late ones may give anywhere under the cover (%.1f then %.1f)" % [early_low, late_low])


func _greed_bursts_the_spring() -> void:
	var game := _playing("standard")
	var safe := int(game.limit)
	for press in safe:
		_tap(game, KEY_SPACE)
	_check(game.phase == "wind" and game.strain() > 0.9 and game.strain() <= 1.0, "the spring holds right up to its limit")
	_tap(game, KEY_SPACE)
	_check(game.phase == "burst" and game.bursts == 1 and game.score == 0 and game.mistakes == 0 and game.distance == 0.0
		and not game.snapshot().word_good and Game.BURST_SECONDS > Game.REST_SECONDS * 2.0,
		"one turn too many pops the spring: no distance, and the first pop is a free lesson")
	_tap(game, KEY_SPACE)
	_tap(game, KEY_X)
	_advance(game, Game.BURST_SECONDS - 0.1)
	_check(game.phase == "burst" and game.dashes_done == 0, "the dizzy toy ignores every button while it spins")
	_advance(game, 0.2)
	_check(game.phase == "wind" and game.dash == 2, "then a fresh toy is set down")
	for press in 30:
		_tap(game, KEY_SPACE)
	_check(game.phase == "burst" and game.bursts == 2 and game.mistakes == 1, "later pops count as mistakes")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	for press in int(helped.limit) + 3:
		_tap(helped, KEY_SPACE)
	_check(helped.phase == "wind" and is_equal_approx(helped.burst_turns(), helped.limit + Game.ASSIST_SLACK), "assist forgives three turns past the limit")
	_advance(helped, Game.RELEASE_GAP + 0.1)
	_check(helped.phase == "wind", "assist also waits longer before letting go")
	_advance(helped, Game.RELEASE_GAP * 0.5)
	_check(helped.phase == "run", "and then releases as usual")


func _rivals_join_later_dashes() -> void:
	var game := _playing("standard")
	var needs: Array[float] = []
	for dash in 6:
		needs.append(game.rival_turns)
		game.limit = Game.GAUGE_TURNS
		var wind := 16 if dash != 4 else 12
		for press in wind:
			_tap(game, KEY_SPACE)
		_tap(game, KEY_X)
		var before := game.score
		_advance(game, game.run_seconds + 0.05)
		var beaten := game.rival_turns > 0.0 and float(wind) > game.rival_turns
		_check(game.beat_rival == beaten and game.score - before == wind * 5 + (Game.RIVAL_BONUS if beaten else 0)
			and is_equal_approx(game.snapshot().rival_distance, game.metres(game.rival_turns)),
			"dash %d against a rival worth %.0f turns pays %d" % [dash + 1, game.rival_turns, game.score - before])
		_advance(game, Game.REST_SECONDS + 0.05)
	_check(needs == [0.0, 0.0, 14.0, 16.0, 17.0, 18.0] and game.rivals_beaten == 1,
		"rivals line up from the third dash and each one needs more turns")


func _variants_change_the_toy() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "heavy", "slippery", "blind"], "four variants are declared")
	var heavy := _playing("heavy")
	for press in 10:
		_tap(heavy, KEY_SPACE)
	_tap(heavy, KEY_X)
	_advance(heavy, heavy.run_seconds + 0.05)
	_check(is_equal_approx(heavy.turns, 6.0) and heavy.score == 42, "the heavy toy needs more presses a turn and pays more a metre")
	var plain := _playing("standard")
	var waxed := _playing("slippery")
	for game: Game in [plain, waxed]:
		for press in 10:
			_tap(game, KEY_SPACE)
		_tap(game, KEY_X)
	_check(is_equal_approx(waxed.distance, 6.25) and waxed.run_seconds > plain.run_seconds * 1.4 and waxed.snapshot().track_metres > plain.snapshot().track_metres,
		"the waxed floor carries the toy farther and the slide takes longer")
	var blind := _playing("blind")
	_check(blind.snapshot().cover_from == 0.0 and blind.limit >= Game.GAUGE_TURNS * Game.COVER_FROM, "the blind variant covers the whole gauge but keeps the same spring")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "heavy", "slippery", "blind"]:
		# Gold: mash fast, listen to the spring and let go just before it gives.
		var gold := _play(session, variant_id, false, 0.07, 0.9, 99.0, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "reading the spring earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: a slow, careful winder who also over-winds every third toy.
	var bronze := _play(session, "standard", false, 0.125, 9.0, 12.0, 3)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "short careful dashes with a few pops still earn bronze (score %d)" % bronze.score)
	# Playing safe: always stop where the cover begins.
	var safe := _play(session, "standard", false, 0.085, 9.0, 16.0, 0)
	_check(safe.score >= lines[1] and safe.score < lines[2] and not safe.devil, "never winding blind tops out at silver (score %d)" % safe.score)
	# Greed: mash until something happens.
	var greedy := _play(session, "standard", false, 0.07, 9.0, 99.0, 0)
	_check(not greedy.success and greedy.score < lines[0] and greedy.mistakes > 3, "mashing without ever letting go earns nothing (score %d)" % greedy.score)
	var helped := _play(session, "standard", true, 0.07, 0.9, 99.0, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("windup dash scores: gold %s, bronze %d, safe %d, greedy %d, assisted %d" % [gold_scores, bronze.score, safe.score, greedy.score, helped.score])
	session.free()


## Play a whole round through Session input: tap every `beat * 2` seconds and
## let go with the second button at `stop_strain` or `stop_turns`, whichever
## comes first; every `pop_every`-th dash is wound until it bursts.
func _play(session: Session, variant_id: String, assisted: bool, beat: float, stop_strain: float, stop_turns: float, pop_every: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-061", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	while not session.ended and game.stage == "play":
		if game.phase != "wind":
			_run_session(session, STEP)
			continue
		var popping := pop_every > 0 and game.dash % pop_every == 0
		if not popping and game.turns > 0.0 and (game.strain() >= stop_strain or game.turns >= stop_turns):
			_session_key(session, KEY_X, true)
			_run_session(session, 0.05)
			_session_key(session, KEY_X, false)
			continue
		_session_key(session, KEY_SPACE, true)
		_run_session(session, beat)
		_session_key(session, KEY_SPACE, false)
		_run_session(session, beat)
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
	_advance(game, Base.READY_SECONDS + 0.05)
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
