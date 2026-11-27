extends SceneTree
## 積木拱橋 rules: the demo drop, the swing, dead-on drops and sawn-off ends,
## regrowing, finished piers and the arch, shapes and keystones, the topple,
## escalation, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/block_bridge_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_drop()
	_dropping_and_sawing()
	_finishing_a_pier()
	_shapes_and_keystones()
	_a_miss_topples_the_pier()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: block bridge swing, dead-on drops, sawn ends, regrow, arches, shapes, keystones, topple, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_drop() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [300, 700, 1050] and not game.hooked.is_empty() and game.pier.is_empty(),
		"a round opens with a block on the hook over an empty plinth")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
	_check(game.pier.size() == 1 and game.score == 0, "the countdown drops one block on the plinth by itself and scores nothing")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.pier.is_empty() and not game.hooked.is_empty(), "play starts from a bare plinth")


func _dropping_and_sawing() -> void:
	var game := _playing("standard")
	var before := game.hook_x()
	_advance(game, 0.2)
	_check(not is_equal_approx(before, game.hook_x()), "the hook swings")
	_aim(game, Game.PIER_X)
	_tap(game, KEY_SPACE)
	_check(not game.falling.is_empty() and game.hooked.is_empty(), "space lets the block go")
	_tap(game, KEY_SPACE)
	_advance(game, Game.FALL_SECONDS + 0.02)
	_check(game.pier.size() == 1 and game.pier[0].perfect and is_equal_approx(float(game.pier[0].width), game.base_width()) and game.offcuts.is_empty(),
		"a dead-on drop keeps the whole block; a second press while it falls does nothing")
	_check(game.score == Game.BLOCK_POINTS + Game.HEIGHT_POINTS + Game.PERFECT_POINTS and game.streak == 1, "it scores the block, its height and a dead-on bonus")
	_advance(game, Game.REHOOK_SECONDS + 0.02)
	_check(not game.hooked.is_empty(), "a new block is hooked on")
	_aim(game, Game.PIER_X + 0.05)
	_tap(game, KEY_DOWN)
	_advance(game, Game.FALL_SECONDS + 0.02)
	var top: Dictionary = game.pier.back()
	_check(game.pier.size() == 2 and not top.perfect and absf(float(top.width) - (game.base_width() - 0.05)) < 0.004 and game.offcuts.size() == 1 and game.offcuts[0].side == 1 and game.streak == 0,
		"an off-centre drop saws the overhang off and leaves a narrower block (↓ works too)")
	_advance(game, Game.REHOOK_SECONDS + 0.02)
	_check(absf(float(game.hooked.width) - float(top.width)) < 0.001, "the next block is as narrow as the top of the pier")
	var pad := _playing("standard")
	_aim(pad, Game.PIER_X)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(not pad.falling.is_empty(), "the gamepad A button lets go too")
	var regrow := _playing("standard")
	regrow.pier.append({"shape": "block", "width": 0.15, "paint": 0, "x": Game.PIER_X, "at": 0.0, "perfect": false})
	regrow.hooked.width = 0.15
	for drop in 3:
		_aim(regrow, Game.PIER_X)
		_tap(regrow, KEY_SPACE)
		_advance(regrow, Game.FALL_SECONDS + Game.REHOOK_SECONDS + 0.04)
	_check(regrow.streak == 3 and absf(float(regrow.pier.back().width) - (0.15 + Game.REGROW)) < 0.001, "three dead-on drops in a row glue a little width back on")


func _finishing_a_pier() -> void:
	var game := _playing("standard")
	for drop in Game.PIER_BLOCKS:
		_aim(game, Game.PIER_X)
		_tap(game, KEY_SPACE)
		_advance(game, Game.FALL_SECONDS + 0.02)
		if drop < Game.PIER_BLOCKS - 1:
			_advance(game, Game.REHOOK_SECONDS + 0.02)
	_check(game.piers == 1 and game.busy() and game.hooked.is_empty(), "eight blocks finish a pier and the train crosses its arch")
	var score := game.score
	_tap(game, KEY_SPACE)
	_check(game.falling.is_empty() and game.score == score, "nothing drops while the train is crossing")
	_advance(game, Game.ARCH_SECONDS + Game.REHOOK_SECONDS)
	_check(game.pier.is_empty() and not game.hooked.is_empty() and is_equal_approx(float(game.hooked.width), game.base_width()), "then a fresh pier starts with a full-width block")


func _shapes_and_keystones() -> void:
	var game := _playing("standard")
	game.play_time = game.round_seconds * 0.7
	var shapes: Dictionary = {}
	for tries in 400:
		game.pier.clear()
		for row in 4:
			game.pier.append({"shape": "block", "width": 0.2, "paint": 0, "x": Game.PIER_X, "at": 0.0, "perfect": true})
		game._hook_next()
		shapes[game.hooked.shape] = true
	_check(shapes.has("cylinder") and shapes.has("keystone") and shapes.has("block"), "late in the round cylinders and keystones swing in too")
	game.hooked = {"shape": "keystone", "width": 0.2, "paint": 1}
	game.pier.resize(3)
	var before := game.score
	_aim(game, Game.PIER_X)
	_tap(game, KEY_SPACE)
	_advance(game, Game.FALL_SECONDS + 0.02)
	_check(game.piers == 1 and game.keystones == 1 and game.score - before == Game.BLOCK_POINTS + Game.HEIGHT_POINTS * 4 + Game.PERFECT_POINTS + Game.PIER_POINTS + Game.KEYSTONE_POINTS,
		"a keystone caps the pier early with a bonus")
	var early := _playing("standard")
	var plain := true
	for tries in 100:
		early._hook_next()
		plain = plain and early.hooked.shape == "block"
	_check(plain, "early on every block is a plain one")


func _a_miss_topples_the_pier() -> void:
	var game := _playing("standard")
	for drop in 3:
		_aim(game, Game.PIER_X)
		_tap(game, KEY_SPACE)
		_advance(game, Game.FALL_SECONDS + Game.REHOOK_SECONDS + 0.04)
	_aim(game, Game.PIER_X + Game.SWING * 0.95)
	_tap(game, KEY_SPACE)
	_advance(game, Game.FALL_SECONDS + 0.02)
	_check(game.pier.is_empty() and game.toppled.blocks.size() == 4 and game.topples == 1 and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a block that misses the pier topples the whole stack; the first time is a free look")
	_check(game.busy(), "nothing drops while the blocks are still tumbling")
	_advance(game, Game.TOPPLE_SECONDS + Game.REHOOK_SECONDS)
	_check(not game.hooked.is_empty() and is_equal_approx(float(game.hooked.width), game.base_width()), "then the pier starts again from the plinth")
	_aim(game, Game.PIER_X + Game.SWING * 0.95)
	_tap(game, KEY_SPACE)
	_advance(game, Game.FALL_SECONDS + 0.02)
	_check(game.topples == 2 and game.mistakes == 1, "a second topple counts as a mistake")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.omega()
	game.play_time = game.round_seconds * 0.95
	_check(game.omega() > early * 1.8, "the swing gets much quicker over the round")
	var bare := game.omega()
	game.pier.append({"shape": "block", "width": 0.2, "paint": 0, "x": Game.PIER_X, "at": 0.0, "perfect": true})
	_check(game.omega() > bare, "a taller pier swings a little faster still")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "wide", "breeze"], "three variants are declared")
	var standard := _playing("standard")
	var wide := _playing("wide")
	_check(wide.base_width() > standard.base_width() * 1.2 and wide.omega() > standard.omega() * 1.1, "big blocks are wider but swing faster")
	var breeze := _playing("breeze")
	var speeds: Array[float] = []
	for sample in 30:
		var phase := breeze.phase
		breeze.step(0.1)
		speeds.append(fposmod(breeze.phase - phase, TAU))
	_check(speeds.max() > speeds.min() * 1.3, "the breeze puffs the swing faster and slower")
	var helped := _playing("standard", true)
	_check(helped.omega() < standard.omega() * 0.85 and helped.perfect_reach() > standard.perfect_reach() * 1.3, "assist slows the swing and widens dead-on")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "wide", "breeze"]:
		var gold := _play(session, variant_id, false, 0.004, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady hand earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.05, 1.6)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a shaky, slow builder still earns bronze (score %d)" % bronze.score)
	var masher := _play(session, "standard", false, -1.0, 0.0)
	_check(not masher.success and masher.score < lines[0], "letting go blindly earns nothing (score %d)" % masher.score)
	var helped := _play(session, "standard", true, 0.004, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("block bridge scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: let go when the hook is within
## `slop` of the top of the pier (a random miss of up to `slop` either way), then
## wait `rest` seconds; a negative `slop` lets go every quarter second regardless.
func _play(session: Session, variant_id: String, assisted: bool, slop: float, rest: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-064", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 5
	var offset := 0.0
	var wait_until := 0.0
	var next_blind := 0.0
	var was := game.hook_x()
	while not session.ended and game.stage == "play":
		var drop := false
		var now_x := game.hook_x()
		if slop < 0.0:
			drop = game.clock >= next_blind
			if drop:
				next_blind = game.clock + 0.25
		elif not game.hooked.is_empty() and game.clock >= wait_until:
			# Let go as the hook crosses the aim point.
			var target := game.top().x + offset
			drop = (was - target) * (now_x - target) <= 0.0
		was = now_x
		if drop:
			_session_key(session, KEY_SPACE, true)
			session._process(STEP)
			_session_key(session, KEY_SPACE, false)
			if slop >= 0.0:
				offset = aim.randf_range(-slop, slop)
				wait_until = game.clock + rest
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


## Swing the hook to just over `x` (phase picked directly, as if waited for).
func _aim(game: Game, x: float) -> void:
	game.phase = asin(clampf((x - Game.PIER_X) / Game.SWING, -1.0, 1.0))


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
