extends SceneTree
## 走鋼索 rules: walking, steering the lean, falling and hanging, pushes, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/tightrope_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_he_walks_and_the_pole_steers()
	_leaning_too_far_flips_him()
	_pushes_arrive_with_a_warning()
	_it_gets_harder_and_the_wire_bounces()
	_variants_change_the_pushes()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: tightrope walking, steering, falls, gusts, pigeons, hats, bounce, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.walk_x == Game.WIRE_FROM and game.thresholds == [350, 650, 950], "a round opens on the left platform with its medal lines declared")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_press(game, KEY_LEFT, true)
		game.step(STEP)
	_press(game, KEY_LEFT, false)
	_check(game.walk_x > Game.WIRE_FROM + 100.0 and game.score == 0 and game.falls == 0, "the countdown walks a few swaying steps by itself; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.walk_x < Game.WIRE_FROM + 10.0 and absf(game.lean) < 0.05 and game.events.is_empty(), "play starts back on the platform, upright")


func _he_walks_and_the_pole_steers() -> void:
	var game := _playing("standard")
	var start := game.walk_x
	_advance(game, 1.0)
	_check(game.walk_x > start + Game.WALK_EARLY * 0.9 and game.score > 0, "he walks by himself and every step earns points")
	game.lean = 0.3
	game.spin = 0.0
	_press(game, KEY_LEFT, true)
	_check(game.steer == -1, "holding left swings the pole left")
	_advance(game, 0.4)
	_check(game.lean < 0.3 and game.spin < 0.0, "which pulls a right lean back")
	_press(game, KEY_RIGHT, true)
	_check(game.steer == 0, "both sides at once cancel out")
	_press(game, KEY_LEFT, false)
	_press(game, KEY_RIGHT, false)
	var drifting := _playing("standard")
	drifting.lean = 0.1
	_advance(drifting, 1.2)
	_check(absf(drifting.lean) > 0.3, "left alone, a small lean keeps growing")
	var steady := _playing("standard")
	var shaky := _playing("standard")
	for tick in 30:
		steady.lean = 0.0
		shaky.lean = 0.3
		steady.spin = 0.0
		shaky.spin = 0.0
		steady.step(STEP)
		shaky.step(STEP)
	_check(steady.score >= shaky.score * 2 - 1 and shaky.score > 0, "steady steps pay double (%d against %d)" % [steady.score, shaky.score])
	var walker := _playing("standard")
	walker.walk_x = Game.WIRE_TO - 2.0
	var before := walker.score
	_advance(walker, 0.1)
	_check(walker.phase == "turn" and walker.crossings == 1 and walker.heading == -1.0 and walker.score >= before + Game.CROSSING_BONUS,
		"reaching the far platform pays the crossing bonus and he turns back")


func _leaning_too_far_flips_him() -> void:
	var game := _playing("standard")
	game.lean = Game.FALL_LEAN - 0.02
	game.spin = 1.0
	_advance(game, 0.1)
	var at := game.walk_x
	_check(game.phase == "fall" and game.falls == 1 and game.mistakes == 0 and not game.snapshot().word_good, "past the limit he flips; the first fall is free")
	_press(game, KEY_LEFT, true)
	_advance(game, Game.FALL_SECONDS - 0.1)
	_check(game.phase == "fall" and game.walk_x == at, "he hangs there without walking or scoring while he climbs back")
	_press(game, KEY_LEFT, false)
	_advance(game, 0.2)
	_check(game.phase == "walk" and absf(game.lean) < 0.1 and absf(game.walk_x - at) < 30.0, "then carries on upright from the same spot")
	game.lean = -Game.FALL_LEAN - 0.01
	game.spin = 0.0
	_advance(game, STEP)
	_check(game.falls == 2 and game.mistakes == 1, "later falls are mistakes")


func _pushes_arrive_with_a_warning() -> void:
	var game := _playing("standard")
	var seen := {}
	while game.stage == "play":
		for event: Dictionary in game.events:
			if not seen.has(event.at):
				seen[event.at] = event.kind
				_check(float(event.at) - game.clock > Game.WARNING - 0.05, "every push shows up %.1f s before it acts" % Game.WARNING)
		game.lean = 0.0
		game.spin = 0.0
		game.step(STEP)
	var kinds := {}
	for moment: float in seen:
		kinds[seen[moment]] = true
	_check(kinds.has("gust") and kinds.has("pigeon") and kinds.has("hat"), "gusts, pigeons and hats all turn up in a round")
	var gusty := _playing("standard")
	gusty.walk_x = 0.0
	gusty.events = [{"kind": "gust", "side": 1.0, "at": gusty.clock, "until": gusty.clock + 1.0, "hit": false}]
	_check(gusty.push() > 1.0, "a gust pushes toward its side")
	gusty.events = [{"kind": "pigeon", "side": -1.0, "at": gusty.clock, "until": gusty.clock + 1.0, "hit": false}]
	_check(gusty.push() < -1.0 and gusty.push() > -Game.CONTROL, "a pigeon weighs its end down, never more than the pole can answer")
	var knocked := _playing("standard")
	knocked._next_event = 999.0
	knocked.events = [{"kind": "hat", "side": 1.0, "at": knocked.clock + 0.05, "until": knocked.clock + 0.5, "hit": false}]
	_advance(knocked, 0.1)
	_check(knocked.spin > 0.5, "a hat lands with one sharp knock")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.tip() < Game.TIP_EARLY, "assist makes him tip over more slowly")


func _it_gets_harder_and_the_wire_bounces() -> void:
	var game := _playing("standard")
	var early_tip := game.tip()
	var early_walk := game.walk_speed()
	var gaps_early: Array[float] = []
	var gaps_late: Array[float] = []
	var last := -1.0
	var bounced_early := false
	var bounced_late := false
	while game.stage == "play":
		var before := game.events.size()
		game.lean = 0.0
		game.spin = 0.0
		game.step(STEP)
		if game.events.size() > before:
			if last >= 0.0:
				(gaps_early if game.heat() < 0.3 else gaps_late).append(game.play_time - last)
			last = game.play_time
		if absf(game.bounce) > 0.01:
			if game.heat() < Game.BOUNCE_FROM_HEAT:
				bounced_early = true
			else:
				bounced_late = true
	_check(game.tip() > early_tip * 1.6 and game.walk_speed() > early_walk * 1.5, "he tips faster and walks faster as the round goes on")
	var mean := func(values: Array[float]) -> float:
		var total := 0.0
		for value in values:
			total += value
		return total / maxf(1.0, values.size())
	_check(gaps_late.size() > gaps_early.size() and mean.call(gaps_late) < mean.call(gaps_early) * 0.75, "pushes come more and more often")
	_check(not bounced_early and bounced_late, "the wire starts bouncing late in the round")


func _variants_change_the_pushes() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "windy", "pigeons", "bouncy"], "four variants are declared")
	var counts := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var tally := {"gust": 0, "pigeon": 0, "hat": 0}
		var seen := {}
		var bounced_early := false
		while game.stage == "play":
			for event: Dictionary in game.events:
				if not seen.has(event.at):
					seen[event.at] = true
					tally[event.kind] += 1
			bounced_early = bounced_early or (game.heat() < 0.3 and absf(game.bounce) > 0.01)
			game.lean = 0.0
			game.spin = 0.0
			game.step(STEP)
		tally["bounce"] = bounced_early
		counts[variant_id] = tally
	_check(counts.windy.gust > counts.standard.gust and counts.windy.gust > counts.windy.pigeon * 2, "the windy variant is mostly gusts")
	_check(counts.pigeons.pigeon > counts.standard.pigeon and counts.pigeons.pigeon > counts.pigeons.gust * 2, "the pigeon variant is mostly pigeons")
	_check(counts.bouncy.bounce and not counts.standard.bounce, "the bouncy wire bounces from the start")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "windy", "pigeons", "bouncy"]:
		# Gold: reads the lean and how fast it is changing, and pushes back early.
		var gold := _play(session, variant_id, false, 0.04, 0.35, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a steady hand earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: only reacts once the lean is large, ignores how fast it is falling and overcorrects.
	var bronze := _play(session, "standard", false, 0.55, 0.0, 0.35)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a late, jerky balancer still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, 99.0, 0.0, 0.0)
	_check(not idle.success and idle.score < lines[0] and idle.mistakes > 3, "never touching the pole earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.04, 0.35, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("tightrope scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session input: push against `lean + look * spin`
## once it passes `deadband`, and keep pushing for at least `hold` seconds.
func _play(session: Session, variant_id: String, assisted: bool, deadband: float, look: float, hold: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-057", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var pushing := 0
	var since := 0.0
	while not session.ended and game.stage == "play":
		var reading := game.lean + look * game.spin
		var want := 0
		if reading > deadband:
			want = -1
		elif reading < -deadband:
			want = 1
		since += STEP
		if want != pushing and (want != 0 or since >= hold):
			if pushing != 0:
				_session_key(session, KEY_LEFT if pushing < 0 else KEY_RIGHT, false)
			if want != 0:
				_session_key(session, KEY_LEFT if want < 0 else KEY_RIGHT, true)
			pushing = want
			since = 0.0
		_run_session(session, STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	if pushing != 0:
		_session_key(session, KEY_LEFT if pushing < 0 else KEY_RIGHT, false)
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
	# Checks below place things by hand, as if the player had already pressed a key.
	game.touched = true
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
