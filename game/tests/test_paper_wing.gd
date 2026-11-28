extends SceneTree
## 紙翼穿峽 rules: banking, gates through the gap and the ring, crashing into
## the rock, gates never opening where the plane is, narrowing and swaying
## gates, side gusts, variants and full simulated rounds (an untouched round
## scores nothing).

const Game = preload("res://game/minigames/arcade/paper_wing_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_banking_and_gates()
	_crashes()
	_gates_open_away_from_the_plane()
	_it_gets_harder()
	_gusts_and_variants()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: paper wing banking, gaps, rings, streak, crashes, gates away from the plane, narrowing and swaying gates, gusts, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [180, 500, 800] and game.gates.size() == 1, "a round opens with one demo gate and its medal lines declared")
	_hold(game, KEY_LEFT, true)
	_advance(game, Base.READY_SECONDS - 0.05)
	_check(game.plane_x > 60.0 and bool(game.last.get("ok", false)), "the countdown banks into the demo gate by itself; the held key does nothing yet")
	_check(game.score == 0 and game.crashes == 0, "and the demo pays nothing")
	_hold(game, KEY_LEFT, false)
	_advance(game, 0.1)
	_check(game.stage == "play" and is_zero_approx(game.plane_x) and game.gates.is_empty(), "play starts level in the middle of the canyon")


func _banking_and_gates() -> void:
	var game := _playing("standard")
	_hold(game, KEY_RIGHT, true)
	_advance(game, 0.15)
	var slow := game.plane_v
	_advance(game, 0.5)
	_check(slow > 0.0 and game.plane_v > slow and game.plane_x > 100.0, "holding → banks the plane and slides it right, gathering speed")
	_hold(game, KEY_RIGHT, false)
	_advance(game, 0.6)
	_check(absf(game.plane_v) < 30.0, "letting go levels the wings")
	var through := _playing("standard")
	through.touched = true
	_gate_at(through, through.plane_x + 2.0)
	_check(through.passed == 1 and through.rings == 1 and through.score == Game.GATE_POINTS + Game.RING_POINTS and through.streak == 1,
		"flying through the ring at a gap's heart pays the gate and the ring (%d)" % through.score)
	_gate_at(through, through.plane_x + through.ring_radius(240.0) + 20.0)
	_check(through.passed == 2 and through.rings == 1 and through.score == 20 + Game.GATE_POINTS + Game.STREAK_POINTS,
		"through the gap off the ring pays the gate and the streak only (%d)" % through.score)
	var untouched := _playing("standard")
	_gate_at(untouched, untouched.plane_x)
	_check(untouched.score == 0 and untouched.phase == "fly", "a gate the player never steered for pays nothing")
	var helped := _round("standard", true)
	_check(helped.clearance(240.0) > _round("standard", false).clearance(240.0) * 1.4, "assist widens the gaps' forgiveness")


func _crashes() -> void:
	var game := _playing("standard")
	game.touched = true
	_gate_at(game, game.plane_x + 300.0)
	_check(game.phase == "crash" and game.crashes == 1 and game.mistakes == 0 and game.fail_at >= 0.0 and game.gates.is_empty(),
		"clipping the rock crumples the plane; the first time is free")
	_advance(game, Game.CRASH_SECONDS + 0.05)
	_check(game.phase == "fly" and is_zero_approx(game.plane_x), "then a fresh plane glides back in mid-canyon")
	_gate_at(game, game.plane_x - 300.0)
	_check(game.crashes == 2 and game.mistakes == 1 and game.streak == 0, "later crashes are mistakes and break the streak")
	var idle := _playing("gusty")
	_advance(idle, idle.round_seconds + 0.1)
	_check(idle.score == 0 and idle.crashes > 5, "an untouched round scores nothing: every gate opens off to the side (%d crashes)" % idle.crashes)


func _gates_open_away_from_the_plane() -> void:
	var game := _playing("slalom")
	var close := 0
	for spot: float in [-Game.LIMIT, -300.0, -120.0, 0.0, 80.0, 250.0, Game.LIMIT]:
		for attempt in 30:
			game.play_time = game.round_seconds * (attempt / 30.0)
			game.plane_x = spot
			game.gates.clear()
			game._spawn()
			var gate: Dictionary = game.gates[0]
			var arrival := game._centre(gate, game.clock + float(gate.z))
			if absf(arrival - spot) <= float(gate.width) * 0.5 + Game.PLANE_HALF or absf(arrival) > Game.LIMIT:
				close += 1
	_check(close == 0, "a new gate's gap never arrives over the plane's spot or past the canyon walls (%d)" % close)


func _it_gets_harder() -> void:
	var early := _playing("standard")
	early._spawn()
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.9
	late._spawn()
	_check(float(late.gates[0].width) < float(early.gates[0].width) * 0.75 and float(late.gates[0].travel) < float(early.gates[0].travel) * 0.75,
		"later gaps are narrower and rush in faster")
	_check(is_zero_approx(float(early.gates[0].sway)) and float(late.gates[0].sway) > 40.0, "and late gates sway side to side")


func _gusts_and_variants() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "gusty", "slalom"], "three variants are declared")
	var counts := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var gusts := 0
		var was := false
		while game.play_time < game.round_seconds - 0.1:
			game.step(STEP)
			var now_gust := not game.gust.is_empty()
			if now_gust and not was:
				gusts += 1
			was = now_gust
		counts[variant_id] = gusts
	_check(counts.gusty > counts.standard and counts.standard > 0, "gusts come, most of all in the gusty canyon (%s)" % counts)
	var blown := _playing("standard")
	blown.gust = {"side": 1.0, "warn_at": blown.clock, "start": blown.clock + Game.GUST_WARN, "end": blown.clock + Game.GUST_WARN + Game.GUST_SECONDS}
	_advance(blown, Game.GUST_WARN - 0.05)
	_check(absf(blown.plane_x) < 1.0, "a gust is shown before it blows")
	_advance(blown, 0.5)
	_check(blown.plane_x > 60.0, "then shoves the plane sideways")
	var slalom := _playing("slalom")
	slalom.play_time = slalom.round_seconds * 0.2
	slalom._spawn()
	_check(float(slalom.gates[0].sway) > 0.0, "the slalom canyon sways its gates early")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "gusty", "slalom"]:
		# Gold: watches the next gate from the moment it appears and lines up on the ring.
		var gold := _play(session, variant_id, false, 1.0, 0.35)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp pilot earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: only reacts once a gate is close and settles anywhere in the gap.
	var bronze := _play(session, "standard", false, 0.42, 1.6)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a late pilot still earns bronze (score %d)" % bronze.score)
	var helped := _play(session, "standard", true, 1.0, 0.35)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("paper wing scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: once the nearest gate is within
## `react` of its trip, steer for where its gap will be, settling within
## `loose` ring radii of its heart.
func _play(session: Session, variant_id: String, assisted: bool, react: float, loose: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-098", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var held := 0
	while not session.ended and game.stage == "play":
		var want := 0
		if game.phase == "fly" and not game.gates.is_empty():
			var gate: Dictionary = game.gates[0]
			if float(gate.z) / float(gate.travel) <= react:
				var aim := game._centre(gate, game.clock + float(gate.z))
				# Lead the slide so the plane settles rather than overshooting.
				var gap := aim - (game.plane_x + game.plane_v / Game.BANK)
				if absf(gap) > game.ring_radius(float(gate.width)) * loose:
					want = int(signf(gap))
		if want != held:
			if held != 0:
				_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
			if want != 0:
				_session_key(session, KEY_RIGHT if want > 0 else KEY_LEFT, true)
			held = want
		_run_session(session, STEP)
	if held != 0:
		_session_key(session, KEY_RIGHT if held > 0 else KEY_LEFT, false)
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


## Put a gate right at the plane with its gap centred on `centre` and let it arrive.
func _gate_at(game: Game, centre: float) -> void:
	game.gates.clear()
	game.gates.append({"serial": 99, "z": 0.01, "travel": 2.0, "base": centre, "sway": 0.0, "omega": 1.0, "offset": 0.0, "width": 240.0})
	game._next_gate = game.clock + 10.0
	game.step(0.02)


func _session_key(session: Session, keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
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


func _hold(game: Base, keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
