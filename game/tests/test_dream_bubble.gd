extends SceneTree
## 夢泡搬運 rules: the countdown demo, walking and the bubble's sway, rushing
## versus easing off, deliveries and growing bubbles, drips, chandeliers,
## vents, the sheep, escalation, variants, assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/dream_bubble_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_sway()
	_untouched_rounds_never_score()
	_walking_and_the_sway()
	_deliveries_grow_the_bubble()
	_hazards_pop_the_bubble()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: dream bubble demo, walking, sway, rushing, deliveries, growing bubbles, drips, chandeliers, vents, sheep, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_sway() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [200, 520, 600] and game.hazards.is_empty(), "a round opens at the dream-room door")
	var swayed := 0.0
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_RIGHT)
		game.step(STEP)
		swayed = maxf(swayed, absf(game.lean))
	_check(game.walker > 0.1 and swayed > 0.05 and game.pops == 0 and game.score == 0, "the countdown walks a few steps by itself and the bubble sways")
	_advance(game, 0.1)
	_check(game.stage == "play" and is_zero_approx(game.walker) and is_zero_approx(game.lean) and game.hazards.size() >= 2, "play starts back at the door with hazards along the corridor")
	var eager := _round("standard")
	_press(eager, KEY_RIGHT, true)
	_advance(eager, Base.READY_SECONDS + 0.5)
	_check(eager.walker > 0.03 and eager.touched, "an arrow held through the countdown sets off at the go")


func _walking_and_the_sway() -> void:
	var game := _playing("standard")
	game.hazards.clear()
	_press(game, KEY_RIGHT, true)
	var back := 0.0
	for tick in int(0.6 / STEP):
		game.step(STEP)
		back = minf(back, game.lean)
	_check(game.walker > 0.08 and back < -0.05, "holding → walks right, and the bubble leans back as the walker sets off")
	var rush := _playing("standard")
	rush.hazards.clear()
	rush.level = 4
	_press(rush, KEY_RIGHT, true)
	_advance(rush, 3.3)
	_check(rush.pops == 1 and rush.pop_cause == "tip", "rushing at full speed rocks a big bubble off (lean %.2f)" % rush.worst)
	var calm := _playing("standard")
	calm.hazards.clear()
	calm.level = 4
	for pulse in 12:
		_press(calm, KEY_RIGHT, true)
		_advance(calm, 0.28)
		_press(calm, KEY_RIGHT, false)
		_advance(calm, 0.3)
	_check(calm.pops == 0 and calm.walker > 0.5, "walking and easing off carries the same bubble safely (furthest lean %.2f)" % calm.worst)
	var pad := _playing("standard")
	pad.hazards.clear()
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	pad.handle_input(stick, Vector2.ZERO)
	_advance(pad, 0.4)
	var dpad := _playing("standard")
	dpad.hazards.clear()
	dpad.walker = 0.5
	var left := InputEventJoypadButton.new()
	left.button_index = JOY_BUTTON_DPAD_LEFT
	left.pressed = true
	dpad.handle_input(left, Vector2.ZERO)
	_advance(dpad, 0.4)
	_check(pad.walker > 0.05 and dpad.walker < 0.48, "the gamepad stick and D-pad walk too, either way")


func _deliveries_grow_the_bubble() -> void:
	var game := _playing("standard")
	game.hazards.clear()
	var first := game.radius()
	game.walker = 0.97
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.3)
	_press(game, KEY_RIGHT, false)
	_check(game.delivered == 1 and game.score >= Game.DELIVER_POINTS + Game.STEADY_POINTS and game.radius() > first and is_zero_approx(game.walker) and game.busy(),
		"reaching the delivery door pays, adds a steady bonus and brings a bigger bubble back at the start")
	_check(game.hazards.size() >= 2, "each trip lays out new hazards")


func _hazards_pop_the_bubble() -> void:
	var game := _playing("standard")
	game.hazards = [{"kind": "drip", "x": game.walker_px(), "period": 2.0, "phase": 0.0, "push": 1.0, "passed": false}]
	_advance(game, Game.DRIP_SWELL + Game.DRIP_FALL)
	_check(game.pops == 1 and game.pop_cause == "drip" and game.mistakes == 0 and game.fail_at > 0.0 and not game.snapshot().word_good,
		"a drip landing on the bubble pops it; the first time is a free look")
	var x := game.walker_px()
	_press(game, KEY_RIGHT, true)
	_advance(game, 0.6)
	_check(game.walker_px() == x, "the walker stands still while the sheep sits on their head")
	_press(game, KEY_RIGHT, false)
	while game._restart_pending:
		game.step(STEP)
	_check(is_zero_approx(game.walker) and game.busy() and game.clock - game.pop_at < Game.POP_SECONDS + 0.05, "then walks back in from the dream room with a fresh bubble")
	var lamp := _playing("standard")
	lamp.level = 3
	lamp.hazards = [{"kind": "lamp", "x": lamp.walker_px(), "period": 2.4, "phase": 0.0, "push": 1.0, "passed": false}]
	_advance(lamp, 1.3)
	_check(lamp.pops == 1 and lamp.pop_cause == "lamp", "a chandelier swinging through the bubble pops it")
	var vent := _playing("standard")
	vent.hazards = [{"kind": "vent", "x": vent.walker_px(), "period": 2.4, "phase": 0.0, "push": 1.0, "passed": false}]
	_advance(vent, 0.5)
	_check(vent.lean > 0.1 and vent.pops == 0, "a puffing vent blows the bubble sideways")
	var beyond := _playing("standard")
	beyond.hazards = [{"kind": "drip", "x": beyond.walker_px() + 20.0, "period": 99.0, "phase": 50.0, "push": 1.0, "passed": false}]
	beyond.walker = 0.1
	_advance(beyond, 0.05)
	_check(bool(beyond.hazards[0].passed) and beyond.score == Game.PASS_POINTS, "getting past a hazard scores")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var drips_only := true
	for trip in 30:
		game._plan_trip()
		drips_only = drips_only and game.hazards.all(func(h: Dictionary) -> bool: return str(h.kind) == "drip")
	_check(drips_only, "the first trips have only drips")
	game.play_time = game.round_seconds * 0.8
	var kinds := {}
	var most := 0
	for trip in 60:
		game._plan_trip()
		most = maxi(most, game.hazards.size())
		for hazard: Dictionary in game.hazards:
			kinds[hazard.kind] = int(kinds.get(hazard.kind, 0)) + 1
	_check(int(kinds.get("lamp", 0)) > 10 and int(kinds.get("vent", 0)) > 10 and most == 4, "later trips bring chandeliers, vents and more hazards: %s" % [kinds])
	game.level = 6
	_check(game.radius() >= Game.RADIUS_FIRST * 1.6, "bubbles grow big over a round")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "drafty", "drippy"], "three variants are declared")
	var drafty := _playing("drafty")
	drafty.play_time = drafty.round_seconds * 0.15
	var vents := 0
	for trip in 40:
		drafty._plan_trip()
		vents += drafty.hazards.filter(func(h: Dictionary) -> bool: return str(h.kind) == "vent").size()
	_check(vents > 20, "the drafty corridor brings vents early")
	var standard := _playing("standard")
	var helped := _playing("standard", true)
	_check(helped.wobble_scale() < standard.wobble_scale() * 0.8, "assist calms the bubble's sway")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "drafty", "drippy"]:
		var gold := _play(session, variant_id, false, 0.0, 0.75)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a careful courier earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 1.0, 0.95)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a hasty courier still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0, 0.0)
	_check(not idle.success and idle.score == 0, "standing still earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.0, 0.75)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("dream bubble scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Seconds until a hazard would touch the bubble if the courier walks on (or
## stands still), sampling the driver's own hazards ahead in time and the
## walker's own easing; INF when nothing does within `look` seconds.
func _danger_in(game: Game, look: float, moving: bool) -> float:
	var keep := game.clock
	var r := game.radius()
	var target := game.pace(Game.WALK) if moving else 0.0
	var found := INF
	for sample in 24:
		var dt := look * (sample + 1) / 24.0
		game.clock = keep + dt
		var ahead := (target * dt + (game.speed - target) * (1.0 - exp(-Game.WALK_RESPONSE * dt)) / Game.WALK_RESPONSE) * (Game.END_PX - Game.START_PX)
		# The bubble rides off-centre by its lean, which swings round as it settles.
		var sway := game.lean * cos(sqrt(Game.STIFF) * dt) * r * 0.9
		var at := Vector2(minf(Game.END_PX, game.walker_px() + ahead) + sway, Game.HEAD_Y - r)
		var hit := false
		for hazard: Dictionary in game.hazards:
			match str(hazard.kind):
				"drip":
					var y := game.drop_y(hazard)
					hit = hit or (y >= 0.0 and absf(y - at.y) < r + Game.DROP + 10.0 and absf(float(hazard.x) - at.x) < r + Game.DROP + 10.0)
				"lamp":
					hit = hit or game.lamp_bob(hazard).distance_to(at) < r + Game.LAMP + 12.0
		if hit:
			found = dt
			break
	game.clock = keep
	return found


## Play a whole round through Session key presses. The courier walks right,
## eases off whenever the lean passes `calm` or a hazard is coming, and is
## `rash` likely to ignore the hazard check; a negative `rash` never touches
## the keys.
func _play(session: Session, variant_id: String, assisted: bool, rash: float, calm: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-088", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var dice := RandomNumberGenerator.new()
	dice.seed = 3
	var held := false
	var careless := false
	var next_think := 0.0
	while not session.ended and game.stage == "play":
		if rash >= 0.0 and game.clock >= next_think:
			next_think = game.clock + 0.05
			if dice.randf() < 0.1:
				careless = dice.randf() < rash
			var want := not game.busy() and absf(game.lean) < calm and absf(game.lean_speed) < calm * 4.0
			if not careless and not game.busy():
				var go_in := _danger_in(game, 0.6, true)
				var stay_in := _danger_in(game, 0.6, false)
				if go_in < stay_in:
					want = false
				elif stay_in < INF:
					want = true
			if want != held:
				_session_key(session, KEY_RIGHT, want)
				held = want
		session._process(STEP)
	if held:
		_session_key(session, KEY_RIGHT, false)
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


func _untouched_rounds_never_score() -> void:
	var scored: Array[String] = []
	for assisted: bool in [false, true]:
		for round_seed in 40:
			var game := Game.new()
			game.round_seed = round_seed
			game.reset(assisted, "noon")
			while game.stage != "done":
				game.step(1.0 / 60.0)
			if game.score != 0:
				scored.append("seed %d%s: %d" % [round_seed, " assisted" if assisted else "", game.score])
	_check(scored.is_empty(), "no input means no points across 80 seeded rounds: %s" % [scored])


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
