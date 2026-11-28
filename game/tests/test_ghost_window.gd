extends SceneTree
## 鬼影擦窗 rules: the countdown demo, moving the cloth, wiping and the fog
## creeping back, hellos and the quick bonus, fading ghosts, blinking ghosts,
## the reflection fright, escalation, variants, assist and full rounds.

const Game = preload("res://game/minigames/arcade/ghost_window_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_hello()
	_untouched_rounds_never_score()
	_cloth_wipes_and_fog_returns()
	_hellos_and_fading_ghosts()
	_a_wrong_pane_shows_a_fright()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: ghost window demo, cloth, wiping, fog, hellos, quick bonus, fading and blinking ghosts, reflection fright, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_hello() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [200, 540, 720] and game.fog.size() == game.grid.x * game.grid.y, "a round opens on a fogged window")
	var waved := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_RIGHT)
		game.step(STEP)
		waved = waved or not game.hello.is_empty()
	_check(waved and game.score == 0 and game.scares == 0, "the countdown wipes the first ghost out by itself and scores nothing")
	_advance(game, 0.1)
	var fogged := true
	for pane in 6:
		fogged = fogged and game.clear_share(pane) < 0.05
	_check(game.stage == "play" and fogged and game.ghosts.is_empty(), "play starts on a freshly fogged window")


func _cloth_wipes_and_fog_returns() -> void:
	var game := _playing("standard")
	game._next_ghost = 999.0
	var start := game.cloth
	_press(game, KEY_UP, true)
	_advance(game, 0.25)
	_press(game, KEY_UP, false)
	_check(game.cloth.y < start.y - 60.0, "↑ moves the cloth up")
	_press(game, KEY_LEFT, true)
	_press(game, KEY_DOWN, true)
	_advance(game, 0.2)
	_press(game, KEY_LEFT, false)
	_press(game, KEY_DOWN, false)
	_check(game.cloth.x < start.x - 40.0, "arrows together move it diagonally")
	var pane := _pane_at(game, game.cloth)
	_check(game.clear_share(pane) > 0.08, "a moving cloth wipes the fog it passes over")
	var still := _playing("standard")
	still._next_ghost = 999.0
	_advance(still, 1.0)
	var clear := false
	for index in 6:
		clear = clear or still.clear_share(index) > 0.01
	_check(not clear, "a cloth left still wipes nothing")
	_advance(game, 0.4)
	var share := game.clear_share(pane)
	_advance(game, 1.0)
	_check(game.clear_share(pane) < share - 0.005, "the fog creeps back")
	var pad := _playing("standard")
	pad._next_ghost = 999.0
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	pad.handle_input(stick, Vector2.ZERO)
	_advance(pad, 0.25)
	_check(pad.cloth.y < start.y - 60.0, "the gamepad stick moves the cloth too")
	var tap := _playing("standard")
	tap._next_ghost = 999.0
	var before := tap.cloth
	_tap(tap, KEY_RIGHT)
	_advance(tap, 0.2)
	_check(tap.cloth.x > before.x + 8.0, "a tap of an arrow nudges the cloth")


func _hellos_and_fading_ghosts() -> void:
	var game := _playing("standard")
	game._next_ghost = 999.0
	game.ghosts = [game._ghost(4, 3.0)]
	game._fog_pane(4)
	_scrub(game, 4, 1.2)
	_check(game.greeted == 1 and game.ghosts.is_empty() and game.score >= Game.HELLO_POINTS and int(game.hello.pane) == 4,
		"wiping the ghost's pane clear makes him wave hello for points")
	var quick := _playing("standard")
	quick._next_ghost = 999.0
	quick.ghosts = [quick._ghost(4, 3.0)]
	quick._fog_pane(4)
	quick.cloth = quick.pane_rect(4).get_center()
	_scrub(quick, 4, 1.2)
	var slow := _playing("standard")
	slow._next_ghost = 999.0
	slow.ghosts = [slow._ghost(4, 3.0)]
	slow._fog_pane(4)
	slow.cloth = slow.pane_rect(4).get_center()
	_advance(slow, 1.6)
	_scrub(slow, 4, 1.2)
	_check(quick.score > slow.score and slow.greeted == 1, "a quicker hello scores more")
	var gone := _playing("standard")
	gone._next_ghost = 999.0
	gone.ghosts = [gone._ghost(0, 1.0)]
	_advance(gone, 1.1)
	_check(gone.ghosts.is_empty() and gone.missed == 1 and gone.score == 0, "a ghost left in the fog fades away")
	var hop := _playing("standard")
	hop._next_ghost = 999.0
	var ghost := hop._ghost(5, 3.0)
	ghost.from = 0
	ghost.hop_at = hop.clock + 0.5
	hop.ghosts = [ghost]
	_check(hop.ghost_pane(ghost) == 0, "a blinking ghost starts in one pane")
	_advance(hop, 0.6)
	_check(hop.ghost_pane(ghost) == 5, "and blinks across to another")


func _a_wrong_pane_shows_a_fright() -> void:
	var game := _playing("standard")
	game._next_ghost = 999.0
	game.ghosts = [game._ghost(5, 9.0)]
	_scrub(game, 0, 2.0)
	_check(game.scares == 1 and game.mistakes == 0 and game.fail_at > 0.0 and int(game.scare.pane) == 0 and not game.snapshot().word_good,
		"wiping a pane with no ghost behind it shows the reflection and a ghost behind you; the first time is a free look")
	_check(game.clear_share(0) < 0.05, "that pane fogs straight back over")
	var cloth := game.cloth
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.5)
	_press(game, KEY_RIGHT, false)
	_check(game.cloth == cloth, "the cloth freezes while the traveller gets over the fright")
	_advance(game, Game.SCARE_SECONDS)
	_scrub(game, 1, 2.0)
	_check(game.scares == 2 and game.mistakes == 1, "a second fright counts as a mistake")
	var linger := _playing("standard")
	linger._next_ghost = 999.0
	linger.ghosts = [linger._ghost(5, 9.0)]
	for jiggle in 40:
		_tap(linger, [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT][jiggle % 4])
		_advance(linger, 0.05)
	_check(linger.scares == 1 and int(linger.scare.pane) == linger.pane_at(linger.cloth), "rubbing away at one empty pane shows the reflection too")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early_fog := game.fog_rate()
	var early_stay := game.stay_seconds()
	game.play_time = game.round_seconds * 0.95
	_check(game.fog_rate() > early_fog * 2.5 and game.stay_seconds() < early_stay * 0.65, "the fog creeps back much faster and ghosts stay for less time by the end")
	var hops := 0
	for spawn in 60:
		game.ghosts.clear()
		game._spawn()
		hops += game.ghosts.filter(func(g: Dictionary) -> bool: return float(g.hop_at) > 0.0).size()
	var calm := _playing("standard")
	var early_hops := 0
	for spawn in 60:
		calm.ghosts.clear()
		calm._spawn()
		early_hops += calm.ghosts.filter(func(g: Dictionary) -> bool: return float(g.hop_at) > 0.0).size()
	_check(hops > 15 and early_hops == 0, "later ghosts blink across panes; early ones do not")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "twins", "mist"], "three variants are declared")
	var twins := _playing("twins")
	twins.play_time = twins.round_seconds * 0.5
	var pairs := 0
	for spawn in 60:
		twins.ghosts.clear()
		twins._spawn()
		pairs += 1 if twins.ghosts.size() == 2 else 0
	_check(pairs > 10, "the twin night sends two ghosts at once")
	var mist := _playing("mist")
	var standard := _playing("standard")
	_check(mist.fog_rate() > standard.fog_rate() * 1.2, "the misty night fogs faster")
	var helped := _playing("standard", true)
	_check(helped.fog_rate() < standard.fog_rate() * 0.8 and helped.stay_seconds() > standard.stay_seconds() * 1.3, "assist slows the fog and lets ghosts stay longer")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "twins", "mist"]:
		var gold := _play(session, variant_id, false, 0.15)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a quick wiper earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.9)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a slow wiper still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0)
	_check(not idle.success and idle.score == 0, "never wiping earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.15)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("ghost window scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session key presses: the wiper notices a ghost
## `react` seconds after it appears, heads for its glowing pane and scrubs
## back and forth inside it; a negative `react` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, react: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-089", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var held := {}
	while not session.ended and game.stage == "play":
		var want := Vector2.ZERO
		if react >= 0.0 and not game.ghosts.is_empty():
			var ghost: Dictionary = game.ghosts[0]
			if game.clock - float(ghost.at) >= react:
				want = _scrub_direction(game, game.ghost_pane(ghost))
		_hold_toward(session, held, want)
		session._process(STEP)
	_hold_toward(session, held, Vector2.ZERO)
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


## Sweep the pane in a zigzag through its corners and edges, the way a person
## wipes a window; the next waypoint is kept on the driver.
func _scrub_direction(game: Game, pane: int) -> Vector2:
	var rect := game.pane_rect(pane).grow(-Game.CLOTH * 0.55)
	var points: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.get_center().y),
		Vector2(rect.end.x, rect.get_center().y), Vector2(rect.position.x, rect.end.y), rect.end]
	if int(game.get_meta("pane", -1)) != pane:
		game.set_meta("pane", pane)
		game.set_meta("waypoint", 0)
	var index := int(game.get_meta("waypoint", 0))
	var to := points[index % points.size()] - game.cloth
	if to.length() < 24.0:
		game.set_meta("waypoint", index + 1)
		to = points[(index + 1) % points.size()] - game.cloth
	return Vector2(signf(to.x) if absf(to.x) > 10.0 else 0.0, signf(to.y) if absf(to.y) > 10.0 else 0.0)


func _hold_toward(session: Session, held: Dictionary, want: Vector2) -> void:
	for pair in [[KEY_LEFT, want.x < 0.0], [KEY_RIGHT, want.x > 0.0], [KEY_UP, want.y < 0.0], [KEY_DOWN, want.y > 0.0]]:
		var code: int = pair[0]
		var down: bool = pair[1]
		if bool(held.get(code, false)) != down:
			_session_key(session, code, down)
			held[code] = down


## Scrub the cloth inside `pane` for `seconds` with direct key presses.
func _scrub(game: Game, pane: int, seconds: float) -> void:
	var held := {}
	var left := seconds
	while left > 0.0:
		var want := _scrub_direction(game, pane)
		for pair in [[KEY_LEFT, want.x < 0.0], [KEY_RIGHT, want.x > 0.0], [KEY_UP, want.y < 0.0], [KEY_DOWN, want.y > 0.0]]:
			if bool(held.get(pair[0], false)) != pair[1]:
				_press(game, pair[0], pair[1])
				held[pair[0]] = pair[1]
		game.step(STEP)
		left -= STEP
	for code in held:
		if held[code]:
			_press(game, code, false)


func _pane_at(game: Game, at: Vector2) -> int:
	for pane in 6:
		if game.pane_rect(pane).has_point(at):
			return pane
	return 0


func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		# The shared arcade driver suite already sweeps every game's untouched seeds;
		# a dozen per assist mode at 30 Hz keeps this game-specific check inside CI's limit.
		for round_seed in 12:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 30.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 24 seeded rounds: %s" % [scored])


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
	# These checks set the scene up directly; count the round as played.
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


func _tap(game: Base, code: int) -> void:
	_press(game, code, true)
	_press(game, code, false)


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
