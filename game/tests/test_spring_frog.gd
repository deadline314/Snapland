extends SceneTree
## 彈簧青蛙 rules: the demo hop, winding, landing and aim, skipping, misses and the
## crane, the toy bin, retracting blocks, springboards, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/spring_frog_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_hop()
	_winding_sets_the_hop()
	_landing_scores_by_aim_and_skips()
	_misses_unwind_and_the_crane_returns()
	_riding_into_the_bin()
	_retracting_blocks_and_springboards()
	_the_round_escalates()
	_variants_change_the_belt()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: spring frog winding, hops, aim, skips, misses, crane, bin, retracting blocks, springboards, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_hop() -> void:
	var game := _round("standard", false)
	var start_block := game.frog_block
	_check(game.stage == "ready" and game.frog_state == "sit" and game.thresholds == [200, 450, 660] and game.blocks.size() >= 6,
		"a round opens with the frog on a block, a filled belt and its medal lines declared")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
	_check(game.frog_state == "sit" and game.frog_block != start_block and game.score == 0 and game.landings == 0 and game.landed_aim > 0.7,
		"the countdown winds the frog and hops it onto the middle of the next block by itself; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.frog_state == "sit" and game.charge == 0.0, "play starts with the frog sitting, unwound")


func _winding_sets_the_hop() -> void:
	var game := _playing("standard")
	var from := game.frog_x
	_press(game, KEY_SPACE, true)
	_check(game.frog_state == "wind", "holding the button winds the frog")
	_advance(game, Game.CHARGE_SECONDS * 0.5)
	_check(absf(game.charge - 0.5) < 0.02 and absf(game.frog_x - from + game.speed * Game.CHARGE_SECONDS * 0.5) < 2.0,
		"the wind grows with the hold while the frog keeps riding its block")
	_advance(game, Game.CHARGE_SECONDS)
	_check(game.charge == 1.0, "the wind stops at full")
	var at := game.frog_x
	_press(game, KEY_SPACE, false)
	_check(game.frog_state == "hop" and is_equal_approx(game.hop_to.x - at, Game.MAX_HOP), "letting go hops ahead as far as the wind")
	var pad := _playing("standard")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_advance(pad, 0.3)
	button = button.duplicate()
	button.pressed = false
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.frog_state == "hop" and pad.hop_to.x - pad.hop_from.x > Game.MIN_HOP + 80.0, "the gamepad A button winds and hops the same way")
	var short := _playing("standard")
	_tap(short, KEY_SPACE)
	_check(short.frog_state == "hop" and is_equal_approx(short.hop_to.x - short.hop_from.x, Game.MIN_HOP), "a tap is a small hop")


func _landing_scores_by_aim_and_skips() -> void:
	var game := _playing("standard")
	_lay(game, [[game.frog_x, 120.0, "plain"], [game.frog_x + 220.0, 120.0, "plain"], [game.frog_x + 440.0, 120.0, "plain"]])
	_hop_to(game, game.blocks[1], 0.0)
	_check(game.frog_state == "sit" and game.frog_block == int(game.blocks[1].id) and game.score == Game.LAND_POINTS + Game.AIM_POINTS
		and game.streak == 1 and game.snapshot().word_good, "a hop onto the middle of the next block scores ten and ten for aim")
	var before := game.score
	_hop_to(game, game.blocks[2], 52.0)
	var expected := roundi(Game.LAND_POINTS + Game.AIM_POINTS * (1.0 - 52.0 / 60.0) + Game.STREAK_POINTS)
	_check(expected < Game.LAND_POINTS + Game.AIM_POINTS, "edge landings are worth less than centred ones")
	_check(game.frog_state == "sit" and game.score - before == expected, "a landing near the edge scores less, plus the streak (%d)" % (game.score - before))
	var skipper := _playing("standard")
	_lay(skipper, [[skipper.frog_x, 120.0, "plain"], [skipper.frog_x + 150.0, 88.0, "plain"], [skipper.frog_x + 330.0, 120.0, "plain"]])
	_hop_to(skipper, skipper.blocks[2], 0.0)
	_check(skipper.frog_block == int(skipper.blocks[2].id) and skipper.score == Game.LAND_POINTS + Game.AIM_POINTS + Game.SKIP_POINTS
		and str(skipper.snapshot().word).begins_with("跳兩格"), "jumping over a block scores a skip bonus")


func _misses_unwind_and_the_crane_returns() -> void:
	var game := _playing("standard")
	_lay(game, [[game.frog_x, 120.0, "plain"], [game.frog_x + 400.0, 120.0, "plain"], [game.frog_x + 700.0, 120.0, "plain"]])
	_tap(game, KEY_SPACE)
	_advance(game, Game.HOP_TIME + 0.02)
	_check(game.frog_state == "fall" and game.misses == 1 and game.mistakes == 0 and game.streak == 0 and not game.snapshot().word_good,
		"a hop into a gap drops the frog on the belt; the first miss is a free lesson")
	_advance(game, Game.UNWIND_SECONDS - 0.1)
	_check(game.frog_state == "fall" and game.frog_y == Game.BELT_Y, "the frog spins on the belt while its key unwinds")
	_tap(game, KEY_SPACE)
	_check(game.frog_state == "fall", "presses do nothing while it unwinds")
	_advance(game, 0.15)
	_check(game.frog_state == "claw", "then the crane comes for it")
	_advance(game, Game.CLAW_SECONDS + 0.02)
	var block := game.block_by_id(game.frog_block)
	_check(game.frog_state == "sit" and str(block.kind) == "plain" and is_equal_approx(game.frog_x, float(block.x)) and game.frog_y == Game.BELT_Y - Game.BLOCK_H,
		"and sets it back on a plain block")
	_lay(game, [[game.frog_x, 120.0, "plain"], [game.frog_x + 420.0, 120.0, "plain"]])
	_tap(game, KEY_SPACE)
	_advance(game, Game.HOP_TIME + 0.02)
	_check(game.misses == 2 and game.mistakes == 1, "later misses count as mistakes")


func _riding_into_the_bin() -> void:
	var game := _playing("standard")
	var seconds := (float(game.block_by_id(game.frog_block).x) - Game.DROP_X) / game.speed
	_advance(game, seconds * 0.85)
	_check(game.frog_state == "sit", "the frog rides its block toward the toy bin")
	_advance(game, seconds * 0.3)
	_check(game.frog_state == "fall" and game.fall_into_bin and game.misses == 1, "staying too long tips the frog into the toy bin")


func _retracting_blocks_and_springboards() -> void:
	var game := _playing("standard")
	_lay(game, [[game.frog_x, 120.0, "plain"], [game.frog_x + 220.0, 120.0, "retract"], [game.frog_x + 440.0, 120.0, "plain"]])
	var retract: Dictionary = game.blocks[1]
	retract.phase = game.clock + Game.HOP_TIME - Game.RETRACT_CYCLE[0] - Game.RETRACT_CYCLE[1]
	_check(game.sink(retract) == 0.0, "a retracting block stands up most of the time")
	_hop_to(game, retract, 0.0)
	_check(game.frog_state == "fall" and game.misses == 1, "landing as it sinks into the belt is a miss")
	var rider := _playing("standard")
	_lay(rider, [[rider.frog_x, 120.0, "plain"], [rider.frog_x + 220.0, 120.0, "retract"], [rider.frog_x + 440.0, 120.0, "plain"]])
	rider.blocks[1].phase = rider.clock + Game.HOP_TIME
	_hop_to(rider, rider.blocks[1], 0.0)
	_advance(rider, Game.RETRACT_CYCLE[0] + 0.2)
	_check(rider.frog_state == "sit" and rider.sink(rider.blocks[1]) == 0.0, "a retracting block holds still while the frog stands on it")
	var springy := _playing("standard")
	_lay(springy, [[springy.frog_x, 120.0, "plain"], [springy.frog_x + 220.0, 120.0, "spring"], [springy.frog_x + 420.0, 120.0, "plain"]])
	var landing: Dictionary = springy.blocks[2]
	_hop_to(springy, springy.blocks[1], 0.0)
	_check(springy.frog_state == "hop" and springy.hop_sprung and springy.springs_used == 1 and springy.score == Game.LAND_POINTS + Game.AIM_POINTS, "a springboard throws the frog on at once")
	_advance(springy, Game.HOP_TIME + 0.02)
	_check(springy.frog_block == int(landing.id) and springy.landed_aim > 0.95 and springy.score == 2 * (Game.LAND_POINTS + Game.AIM_POINTS) + Game.STREAK_POINTS + Game.SPRING_POINTS,
		"onto the middle of the block after it, with a spring bonus")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early_speed := game.speed
	var first_retract := -1.0
	var first_spring := -1.0
	var gaps_early: Array[float] = []
	var gaps_late: Array[float] = []
	var seen := 0
	while game.stage == "play":
		game.step(STEP)
		while seen < game._next_id:
			for block in game.blocks:
				if int(block.id) == seen:
					if str(block.kind) == "retract" and first_retract < 0.0:
						first_retract = game.heat()
					if str(block.kind) == "spring" and first_spring < 0.0:
						first_spring = game.heat()
					var index := game.blocks.find(block)
					if index > 0:
						var gap := float(block.x) - float(block.w) * 0.5 - float(game.blocks[index - 1].x) - float(game.blocks[index - 1].w) * 0.5
						if game.heat() < 0.3:
							gaps_early.append(gap)
						elif game.heat() > 0.7:
							gaps_late.append(gap)
			seen += 1
	_check(game.speed > early_speed * 2.0 and is_equal_approx(game.speed, Game.SPEED_END), "the belt speeds up through the round (%.0f to %.0f)" % [early_speed, game.speed])
	_check(_mean(gaps_late) > _mean(gaps_early) + 50.0, "gaps between blocks widen (%.0f to %.0f)" % [_mean(gaps_early), _mean(gaps_late)])
	_check(first_retract >= Game.RETRACT_HEAT and first_spring >= Game.SPRING_HEAT, "retracting blocks and springboards only join later (%.2f, %.2f)" % [first_retract, first_spring])


func _variants_change_the_belt() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "tiny", "springs", "rush"], "four variants are declared")
	var tiny := _playing("tiny")
	_check(tiny.blocks.slice(1).all(func(block: Dictionary) -> bool: return float(block.w) <= Game.TINY_WIDTHS[-1]), "tiny blocks are narrower")
	var rush := _playing("rush")
	var standard := _playing("standard")
	_check(rush.speed > standard.speed * 1.15, "the rush belt runs faster")
	var springs := _playing("springs")
	var count := 0
	while springs.heat() < 0.3:
		springs.step(STEP)
	for block in springs.blocks:
		count += int(str(block.kind) == "spring")
	_check(count >= 1, "the spring party brings springboards from the start")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "tiny", "springs", "rush"]:
		var gold := _play(session, variant_id, false, 10.0, 0.3)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "aiming for the middle of the next block earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: rough aim and a long dawdle before each hop.
	var bronze := _play(session, "standard", false, 85.0, 2.5)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1 and bronze.mistakes > 0,
		"rough hops with long pauses still earn bronze (score %d)" % bronze.score)
	var masher := _play(session, "standard", false, -1.0, 0.0)
	_check(not masher.success and masher.score < lines[0] and masher.mistakes > 2, "tapping without winding earns nothing (score %d)" % masher.score)
	var helped := _play(session, "standard", true, 10.0, 0.3)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("spring frog scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: wait `pause` seconds on each block,
## then wind for the next block that is not retracting, missing its middle by
## up to `error` pixels; a negative error taps as fast as possible instead.
func _play(session: Session, variant_id: String, assisted: bool, error: float, pause: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-065", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var aim := RandomNumberGenerator.new()
	aim.seed = 7
	var seated_at := -1.0
	var goal := -1.0
	while not session.ended and game.stage == "play":
		if error < 0.0:
			if game.frog_state == "sit":
				_session_key(session, KEY_SPACE, true)
				session._process(STEP)
				_session_key(session, KEY_SPACE, false)
		elif game.frog_state == "sit":
			if seated_at < 0.0:
				seated_at = game.clock
			var target := _next_target(game)
			var urgent := game.frog_x < Game.DROP_X + game.speed * 0.9
			if not target.is_empty() and (game.clock - seated_at >= pause or urgent):
				var distance := float(target.x) - game.frog_x - game.speed * Game.HOP_TIME + aim.randf_range(-error, error)
				goal = clampf((distance - Game.MIN_HOP) / (Game.MAX_HOP - Game.MIN_HOP), 0.0, 1.0)
				_session_key(session, KEY_SPACE, true)
		elif game.frog_state == "wind" and game.charge >= goal - 0.004:
			_session_key(session, KEY_SPACE, false)
			seated_at = -1.0
		elif game.frog_state != "wind":
			seated_at = -1.0
		session._process(STEP)
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


## The next block ahead worth jumping to: not a retracting one, within reach.
func _next_target(game: Game) -> Dictionary:
	var here := game.block_by_id(game.frog_block)
	for block in game.blocks:
		if float(block.x) <= float(here.x):
			continue
		var distance := float(block.x) - game.frog_x - game.speed * Game.HOP_TIME
		if distance > Game.MAX_HOP or game.frog_x + distance > Game.FAR_X:
			return {}
		if str(block.kind) != "retract" and distance >= Game.MIN_HOP:
			return block
	return {}


## Replace the belt with `rows` of [x, width, kind] and seat the frog on the first.
func _lay(game: Game, rows: Array) -> void:
	game.blocks.clear()
	for row: Array in rows:
		game._add_block(float(row[0]), float(row[1]), str(row[2]))
	game._seat(game.blocks[0], 0.0)


## Wind exactly enough to come down `offset` pixels past the middle of `block`.
func _hop_to(game: Game, block: Dictionary, offset: float) -> void:
	var distance := float(block.x) + offset - game.frog_x - game.speed * Game.HOP_TIME
	_press(game, KEY_SPACE, true)
	game.charge = (distance - Game.MIN_HOP) / (Game.MAX_HOP - Game.MIN_HOP)
	_press(game, KEY_SPACE, false)
	_advance(game, Game.HOP_TIME + 0.001)


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(1.0, values.size())


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
