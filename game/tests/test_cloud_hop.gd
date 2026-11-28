extends SceneTree
## 雲梯換層 rules: bobbing pads, hopping when level, the level bonus and streak,
## the exit gate and new courses, shrinking and gusty pads, falling into the
## clouds, escalation, variants and full simulated rounds (an untouched round
## scores nothing).

const Game = preload("res://game/minigames/arcade/cloud_hop_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_hopping_when_level()
	_falls_and_vanishing_pads()
	_it_gets_harder()
	_variants_change_the_pads()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: cloud hop pads, level hops, gaps, streak, gate, shrinking and gusty pads, falls, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [180, 700, 1400] and game.pad == 0, "a round opens on the first pad with its medal lines declared")
	_tap(game)
	_advance(game, Base.READY_SECONDS - 0.05)
	_check(game.score == 0 and game.falls == 0, "the countdown hops by itself when the pads line up; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.pad == 0 and game.phase == "stand", "play starts back on the first pad of a fresh course")


func _hopping_when_level() -> void:
	var game := _playing("standard")
	_until_level(game, 0.5)
	var gap := game.level_gap()
	_tap(game)
	_check(game.phase == "hop" and game.pad == 1 and game.score >= Game.HOP_POINTS and game.streak == 1,
		"pressing while the pads are level hops across (gap %.1f px, %d points)" % [gap, game.score])
	_advance(game, Game.HOP_SECONDS + 0.02)
	_check(game.phase == "stand" and game.pad == 1, "and lands on the next pad")
	var close := _playing("standard")
	_until_level(close, 0.1)
	_tap(close)
	var loose := _playing("standard")
	_until_level(loose, 0.95)
	_tap(loose)
	_check(close.score > loose.score, "the closer to level, the more it pays (%d vs %d)" % [close.score, loose.score])
	var gate := _playing("standard")
	gate.pad = gate.pads.size() - 1
	_until_level(gate, 0.5)
	var before := gate.score
	_tap(gate)
	_advance(gate, Game.HOP_SECONDS + 0.02)
	_check(gate.courses == 2 and gate.pad == 0 and gate.score - before >= Game.GATE_BONUS, "hopping onto the gate pays a bonus and starts a new course")


func _falls_and_vanishing_pads() -> void:
	var game := _playing("standard")
	_until_apart(game)
	_tap(game)
	_check(game.phase == "fall" and game.falls == 1 and game.mistakes == 0 and game.fail_at >= 0.0 and game.pad == 0,
		"hopping when the pads are not level drops the hero into the clouds; the first time is free")
	_tap(game)
	_check(game.phase == "fall", "nothing happens while the hero climbs out")
	_advance(game, Game.FALL_SECONDS + 0.02)
	_check(game.phase == "stand" and game.pad == 0, "then the hero is back on the same pad")
	_until_apart(game)
	_tap(game)
	_check(game.falls == 2 and game.mistakes == 1, "later falls are mistakes")
	var shrinking := _playing("standard")
	shrinking.pads[0].kind = "shrink"
	shrinking.pads[0].stood_at = shrinking.clock
	_advance(shrinking, Game.SHRINK_SECONDS * 0.5)
	_check(shrinking.pad_size(0) < 0.6 and shrinking.phase == "stand", "a shrinking pad dwindles under the hero")
	_advance(shrinking, Game.SHRINK_SECONDS * 0.5 + 0.05)
	_check(shrinking.falls == 1 and shrinking.phase == "fall", "and drops them when it vanishes")
	var idle := _playing("shrink")
	_advance(idle, idle.round_seconds + 0.1)
	_check(idle.score == 0, "an untouched round scores nothing")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.window(helped.level()) > Game.LEVEL_EARLY * 1.4, "assist widens what counts as level")


func _it_gets_harder() -> void:
	var early := _playing("standard")
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.9
	late._new_course()
	_check(late.pads.size() > early.pads.size(), "later courses are longer (%d vs %d pads)" % [early.pads.size(), late.pads.size()])
	var fast_early := 0.0
	var fast_late := 0.0
	for spec: Dictionary in early.pads:
		fast_early += float(spec.omega)
	for spec: Dictionary in late.pads:
		fast_late += float(spec.omega)
	_check(fast_late / late.pads.size() > fast_early / early.pads.size() * 1.4, "and their pads bob faster")
	_check(late.level() < early.level(), "and need a closer match")
	var odd_early := 0
	for spec: Dictionary in early.pads:
		odd_early += int(str(spec.kind) != "plain")
	var odd_late := 0
	for attempt in 6:
		late._new_course()
		for spec: Dictionary in late.pads:
			odd_late += int(str(spec.kind) != "plain")
	_check(odd_early == 0 and odd_late > 0, "shrinking and gusty pads come late in the standard show (%d)" % odd_late)


func _variants_change_the_pads() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "shrink", "windy"], "three variants are declared")
	var tally := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		game.play_time = game.round_seconds * 0.5
		var counts := {"shrink": 0, "windy": 0}
		for attempt in 12:
			game._new_course()
			for spec: Dictionary in game.pads:
				if counts.has(str(spec.kind)):
					counts[str(spec.kind)] += 1
		tally[variant_id] = counts
	_check(tally.shrink.shrink > tally.standard.shrink * 1.5 and tally.windy.windy > tally.standard.windy * 1.5, "each variant leans on its own kind of pad (%s)" % tally)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "shrink", "windy"]:
		# Gold: hops as soon as the gap is within a third of the level band.
		var gold := _play(session, variant_id, false, 0.33, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp hopper earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: waits for a near-perfect line-up, so it is slow, and now and then jumps too early.
	var bronze := _play(session, "standard", false, 0.15, 0.03)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a hesitant hopper still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 0.33, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("cloud hop scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: hop once the gap is within
## `within` of the level band; with `rash` chance per check jump anyway.
func _play(session: Session, variant_id: String, assisted: bool, within: float, rash: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-097", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var luck := RandomNumberGenerator.new()
	luck.seed = 11
	var checks := 0
	while not session.ended and game.stage == "play":
		if game.phase == "stand":
			checks += 1
			if game.level_gap() <= game.window(game.level()) * within or (rash > 0.0 and checks % 20 == 0 and luck.randf() < rash * 20.0):
				_session_tap(session)
		_run_session(session, STEP)
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


func _until_level(game: Game, within: float) -> void:
	for tick in 4000:
		if game.level_gap() <= game.window(game.level()) * within:
			return
		game.step(STEP / 4.0)
	failures.append("the pads never lined up")


func _until_apart(game: Game) -> void:
	for tick in 4000:
		if game.level_gap() > game.window(game.level()) * 2.0:
			return
		game.step(STEP)
	failures.append("the pads never drifted apart")


func _session_tap(session: Session) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


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


func _tap(game: Base) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
