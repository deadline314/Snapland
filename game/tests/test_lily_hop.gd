extends SceneTree
## 睡蓮踏浪 rules: hopping, sinking pads, dunks and the frog, the far bank, pond
## generation, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/lily_hop_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_hops_by_itself()
	_hopping_and_sinking()
	_dunks_bring_up_a_frog()
	_far_bank_starts_a_new_pond()
	_every_pond_can_be_crossed()
	_variants_and_escalation()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: lily hop hops, sinking pads, dunks, frogs, far bank, ponds, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_hops_by_itself() -> void:
	var game := _round("calm", false)
	_check(game.stage == "ready" and game.column == 0 and game.thresholds == [250, 500, 750], "a round opens on the near bank with its medal lines declared")
	var moved := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_RIGHT)
		game.step(STEP)
		moved = moved or game.column > 0
	_check(moved and game.score == 0 and game.hops == 0 and game.dunks == 0, "the countdown hops a few pads by itself; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.column == 0 and game.pond == 1 and game.mode == "stand" and game.pads.all(func(pad: Dictionary) -> bool: return pad.landed < 0.0),
		"play starts on the near bank of a fresh pond")


func _hopping_and_sinking() -> void:
	var game := _playing("calm")
	_tap(game, KEY_LEFT)
	_check(game.mode == "stand" and game.column == 0, "← does nothing")
	var step := game._best_step()
	_hop(game, step)
	_check(game.mode == "hop", "an arrow starts a hop")
	_advance(game, Game.HOP_SECONDS + 0.02)
	_check(game.mode == "stand" and game.column == 1 and game.standing >= 0 and game.score == Game.HOP_POINTS and game.hops == 1,
		"landing on a pad scores ten")
	var pad: Dictionary = game.pads[game.standing]
	_check(pad.landed > 0.0 and game.snapshot().sink_left > 0.97, "the pad starts sinking the moment the visitor lands")
	_advance(game, game.sink_seconds() * 0.5)
	_check(game.snapshot().sink_left < 0.55 and game.mode == "stand", "it goes under bit by bit")
	_advance(game, game.sink_seconds() * 0.5 + 0.05)
	_check(game.mode == "dunk" and game.dunks == 1 and game.mistakes == 0 and game.frogs == 1, "waiting too long dunks the visitor; the first dunk is free")
	# Pressing into the edge of the pond does nothing.
	var edge := _playing("calm")
	edge.lane = 0
	_tap(edge, KEY_UP)
	_check(edge.mode == "stand" and edge.column == 0, "there is no lane above the top one")
	# A quick second press waits for the landing instead of being lost.
	var quick := _playing("calm")
	_hop(quick, quick._best_step())
	_advance(quick, Game.HOP_SECONDS * 0.5)
	var queued := _step_after_landing(quick)
	_hop(quick, queued)
	_advance(quick, Game.HOP_SECONDS * 0.5 + 0.02)
	_check(quick.mode == "hop" and quick.column == 1, "a press during a hop is kept for the landing")
	var helped := _round("calm", true)
	_check(helped.sink_seconds() > Game.SINK_FIRST * 1.4, "assist keeps pads up longer")


func _dunks_bring_up_a_frog() -> void:
	var game := _playing("calm")
	_hop(game, game._best_step())
	_advance(game, Game.HOP_SECONDS + 0.02)
	var wrong := _wrong_step(game)
	_check(wrong != 99, "some lane next to the visitor is open water")
	_hop(game, wrong)
	_advance(game, Game.HOP_SECONDS + 0.02)
	_check(game.mode == "dunk" and game.dunks == 1 and game.frogs == 1 and game.mistakes == 0 and not game.snapshot().word_good, "hopping onto open water is a splash")
	_tap(game, KEY_RIGHT)
	_check(game.mode == "dunk", "nobody hops while under water")
	_advance(game, Game.DUNK_SECONDS + 0.02)
	_check(game.mode == "stand" and game.standing >= 0 and game.column == 2 and game.frogs == 1 and game._best_step() != 99,
		"the visitor comes up on a fresh pad, frog on head, with a way forward")
	var after := game.score
	_advance(game, game.sink_seconds() + 0.05)
	_check(game.dunks == 2 and game.mistakes == 1 and game.frogs == 2 and game.score == after, "later dunks count as mistakes and stack frogs")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	var padded := _playing("calm")
	padded.lane = 1
	padded.handle_input(pad, Vector2.ZERO)
	_check(padded.mode == "hop", "the gamepad's d-pad hops too")


func _far_bank_starts_a_new_pond() -> void:
	var game := _playing("calm")
	game.frogs = 2
	var guard := 0
	while game.crossings == 0 and guard < 40:
		guard += 1
		var step := game._best_step()
		if step == 99:
			game.step(STEP)
			continue
		_hop(game, step)
		_advance(game, Game.BOUNCE_SECONDS + 0.02)
	_check(game.crossings == 1 and game.mode == "ashore" and game.frogs == 0 and game.score >= Game.ASHORE_POINTS + Game.HOP_POINTS * Game.COLUMNS,
		"reaching the far bank scores fifty and washes the frogs off (%d crossings, %s, %d frogs, %d points)" % [game.crossings, game.mode, game.frogs, game.score])
	_advance(game, Game.ASHORE_SECONDS + 0.02)
	_check(game.pond == 2 and game.column == 0 and game.mode == "stand", "then a new pond begins")


func _every_pond_can_be_crossed() -> void:
	var broken := 0
	var bounces := 0
	var drifts := 0
	for round_seed in 80:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		_advance(game, Base.READY_SECONDS + 0.05)
		for late: float in [0.0, 0.7]:
			game.play_time = game.round_seconds * late
			for start_lane in Game.LANES:
				game.lane = start_lane
				game._new_pond()
				broken += _dead_ends(game)
				for pad: Dictionary in game.pads:
					if pad.kind == "bounce":
						bounces += 1
						var landing := int(pad.column) + 2
						if landing <= Game.COLUMNS and not game.pads.any(func(other: Dictionary) -> bool: return int(other.column) == landing and int(other.home) == int(pad.home) and other.drift == 0.0):
							broken += 1
					if pad.drift > 0.0:
						drifts += 1
	_check(broken == 0, "every pad has a way on, and every bounce lands on a still pad (%d broken)" % broken)
	_check(bounces > 0 and drifts > 0, "ponds use bouncy and drifting pads")


## Pads (still ones, plus the bank) from which no pad of the next column can ever be reached.
func _dead_ends(game: Game) -> int:
	var count := 0
	var lanes_by_column: Dictionary = {0: [game.lane]}
	for pad: Dictionary in game.pads:
		if pad.kind == "bounce":
			continue
		var column := int(pad.column)
		if not lanes_by_column.has(column):
			lanes_by_column[column] = []
		lanes_by_column[column].append(int(pad.home))
		if pad.drift > 0.0:
			lanes_by_column[column].append(int(pad.home) + 1)
	for column in range(0, Game.COLUMNS):
		for from_lane: int in lanes_by_column.get(column, []):
			var onward := game.pads.any(func(pad: Dictionary) -> bool:
				return int(pad.column) == column + 1 and (pad.drift > 0.0 or absi(int(pad.home) - from_lane) <= 1))
			if not onward:
				count += 1
	return count


func _variants_and_escalation() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["calm", "drift", "bouncy"], "three variants are declared")
	var calm := _playing("calm")
	var early_sink := calm.sink_seconds()
	_check(calm.pads.all(func(pad: Dictionary) -> bool: return pad.drift == 0.0 and pad.kind == "pad"), "a calm pond starts with plain still pads")
	_advance(calm, calm.round_seconds * 0.8)
	_check(calm.sink_seconds() < early_sink * 0.6, "pads sink faster later in the round (%.2f then %.2f s)" % [early_sink, calm.sink_seconds()])
	var late_drift := 0
	var late_bounce := 0
	for attempt in 20:
		calm._new_pond()
		late_drift += calm.pads.filter(func(pad: Dictionary) -> bool: return pad.drift > 0.0).size()
		late_bounce += calm.pads.filter(func(pad: Dictionary) -> bool: return pad.kind == "bounce").size()
	_check(late_drift > 0 and late_bounce > 0, "drifting and bouncy pads join a calm round later on")
	var drift := _playing("drift")
	var early_drift := 0
	for attempt in 10:
		drift._new_pond()
		early_drift += drift.pads.filter(func(pad: Dictionary) -> bool: return pad.drift > 0.0).size()
	_check(early_drift >= 5, "the drifting variant drifts from the start")
	var moving: Dictionary = drift.pads.filter(func(pad: Dictionary) -> bool: return pad.drift > 0.0)[0]
	var seen: Array[float] = []
	for tick in 240:
		drift._update_pads()
		drift.clock += STEP
		seen.append(moving.lane)
	_check(seen.min() < float(moving.home) + 0.1 and seen.max() > float(moving.home) + 0.9, "a drifting pad slides between two lanes")
	var bouncy := _playing("bouncy")
	var guard := 0
	while bouncy.pads.all(func(pad: Dictionary) -> bool: return pad.kind != "bounce" or int(pad.column) != 1) and guard < 60:
		guard += 1
		bouncy._new_pond()
	var spring: Dictionary = bouncy.pads.filter(func(pad: Dictionary) -> bool: return pad.kind == "bounce" and int(pad.column) == 1)[0]
	bouncy.lane = int(spring.home)
	_hop(bouncy, 0)
	_advance(bouncy, Game.HOP_SECONDS + 0.02)
	_check(bouncy.mode == "hop" and bouncy.bounced and bouncy.hop_to == Vector2i(3, int(spring.home)), "the bouncy pad flings the visitor two columns on")
	_advance(bouncy, Game.BOUNCE_SECONDS + 0.02)
	_check(bouncy.column == 3 and bouncy.mode == "stand" and bouncy.score == Game.HOP_POINTS * 3, "and the long hop is worth double")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["calm", "drift", "bouncy"]:
		var gold := _play(session, variant_id, false, 0.2, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "quick, sure hops earn gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: a slow hopper who also jumps into the water now and then.
	var bronze := _play(session, "calm", false, 0.75, 5)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a slow, splashy round still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "calm", false, -1.0, 0)
	_check(not idle.success and idle.score == 0, "standing on the bank earns nothing")
	var helped := _play(session, "calm", true, 0.2, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("lily hop scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input. The hopper waits `reaction` seconds
## after each landing (negative: never hops), then takes a hop that lands; every
## `splash`th hop goes into the water on purpose when it can.
func _play(session: Session, variant_id: String, assisted: bool, reaction: float, splash: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-077", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var tries := 0
	while not session.ended and game.stage == "play":
		if reaction >= 0.0 and game.mode == "stand" and game.clock - game.mode_at >= reaction:
			var step := game._best_step()
			if splash > 0 and (tries + 1) % splash == 0 and _wrong_step(game) != 99:
				step = _wrong_step(game)
			if step != 99:
				tries += 1
				var code: int = {-1: KEY_UP, 0: KEY_RIGHT, 1: KEY_DOWN}[step]
				_session_key(session, code, true)
				session._process(STEP)
				_session_key(session, code, false)
		session._process(STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


## A step from the visitor's lane that lands in open water, or 99.
func _wrong_step(game: Game) -> int:
	if game.column + 1 > Game.COLUMNS:
		return 99
	for step: int in [0, -1, 1]:
		var target: int = game.lane + step
		if target >= 0 and target < Game.LANES and game.pad_at(game.column + 1, target) < 0:
			var drifting := game.pads.any(func(pad: Dictionary) -> bool: return int(pad.column) == game.column + 1 and pad.drift > 0.0)
			if not drifting:
				return step
	return 99


## The step that will be good from the pad the current hop is landing on.
func _step_after_landing(game: Game) -> int:
	var lane: int = game.hop_to.y
	for step: int in [0, -1, 1]:
		var target := lane + step
		if target >= 0 and target < Game.LANES and game.pad_at(game.hop_to.x + 1, target) >= 0:
			return step
	return 0


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
	_advance(game, Base.READY_SECONDS + 0.02)
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


func _hop(game: Game, step: int) -> void:
	_tap(game, {-1: KEY_UP, 0: KEY_RIGHT, 1: KEY_DOWN}.get(step, KEY_RIGHT))


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
