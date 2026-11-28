extends SceneTree
## 電梯借重 rules: the countdown demo, running and braking, sliding further
## with guests aboard, level stops, pick-ups and drop-offs, the dead-level
## bonus, impatient and hurried guests, the pinched cap, escalation, variants,
## assist and full simulated rounds.

const Game = preload("res://game/minigames/arcade/lift_brake_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_a_stop()
	_untouched_rounds_never_score()
	_running_and_braking()
	_level_stops_serve_guests()
	_a_stop_between_floors_pinches_the_cap()
	_guests_wait_and_hurry()
	_the_round_escalates()
	_variants_and_assist()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: lift brake demo, running, braking, weight, level stops, pick-ups, drop-offs, dead level, patience, hurry, pinched cap, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_a_stop() -> void:
	var game := _round("standard")
	_check(game.stage == "ready" and game.thresholds == [200, 520, 780] and game.waiting.size() == 1, "a round opens with a guest waiting")
	var served := false
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
		served = served or (not game.stop.is_empty() and bool(game.stop.level))
	_check(served and game.score == 0 and game.pinches == 0, "the countdown brakes the lift level at the guest's floor by itself and scores nothing")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.car < 0.05 and game.riders.is_empty() and game.waiting.is_empty(), "play starts afresh at the ground floor")


func _running_and_braking() -> void:
	var game := _playing("standard")
	_advance(game, 1.0)
	_check(game.car > 0.3 and game.velocity > 0.5, "the lift sets off up the shaft by itself")
	var game2 := _playing("standard")
	game2.waiting.clear()
	game2._next_call = 999.0
	game2.car = 3.6
	game2.velocity = 1.0
	_advance(game2, 2.0)
	_check(game2.direction == -1 and game2.car < 4.0, "it turns round at the top")
	var empty := _playing("standard")
	empty.velocity = 2.0
	var full := _playing("standard")
	full.velocity = 2.0
	for rider in 4:
		full.riders.append({"to": 4, "rush": false})
	_check(full.stopping_distance() > empty.stopping_distance() * 1.5, "every guest aboard makes the car slide further before it stops")
	var brake := _playing("standard")
	brake.waiting.clear()
	brake._next_call = 999.0
	brake.car = 1.0
	brake.velocity = 1.2
	var slide := brake.stopping_distance()
	_press(brake, KEY_SPACE, true)
	_advance(brake, 1.0)
	_check(absf(brake.car - (1.0 + slide)) < 0.03 and brake.velocity == 0.0, "holding the button brakes to a stop after the slide")
	var pad := _playing("standard")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	pad.handle_input(button, Vector2.ZERO)
	_check(pad.braking, "the gamepad A button brakes too")


func _level_stops_serve_guests() -> void:
	var game := _playing("standard")
	game._next_call = 999.0
	game.waiting.assign([game._guest(2)])
	_brake_onto(game, 2.0)
	_check(not game.stop.is_empty() and bool(game.stop.level) and game.riders.size() == 1 and game.waiting.is_empty() and game.score >= Game.PICK_POINTS,
		"a level stop at a lit floor lets the guest in")
	var to := int(game.riders[0].to)
	_check(to != 2, "the new rider wants another floor")
	_press(game, KEY_SPACE, false)
	var before := game.score
	_brake_onto(game, float(to))
	_check(game.riders.is_empty() and game.delivered == 1 and game.score >= before + Game.DROP_POINTS, "a level stop at their floor lets them out for points")
	var dead := _playing("standard")
	dead._next_call = 999.0
	dead.waiting.assign([dead._guest(2)])
	_brake_onto(dead, 2.0)
	_check(dead.score >= Game.PICK_POINTS + Game.LEVEL_POINTS, "stopping dead level adds a bonus")
	var nobody := _playing("standard")
	nobody._next_call = 999.0
	nobody.waiting.clear()
	_brake_onto(nobody, 1.0)
	_check(nobody.score == 0 and nobody.pinches == 0 and bool(nobody.stop.level), "a level stop with nobody there is harmless")


func _a_stop_between_floors_pinches_the_cap() -> void:
	var game := _playing("standard")
	game._next_call = 999.0
	game.waiting.assign([game._guest(3)])
	_brake_onto(game, 2.5)
	_check(game.pinches == 1 and game.mistakes == 0 and game.fail_at > 0.0 and game.pinched() and not bool(game.stop.level) and not game.snapshot().word_good,
		"stopping between floors pinches the cap; the first time is a free look")
	_press(game, KEY_SPACE, false)
	var car := game.car
	_advance(game, 0.8)
	_check(game.car == car, "the lift stays stuck while the cap is pulled free")
	_advance(game, Game.PINCH_SECONDS)
	_check(game.car != car, "then it runs on")
	_brake_onto(game, floorf(game.car) + 0.5 if game.velocity > 0.0 else ceilf(game.car) - 0.5)
	_check(game.pinches == 2 and game.mistakes == 1, "a second pinched cap counts as a mistake")


func _guests_wait_and_hurry() -> void:
	var game := _playing("standard")
	game._next_call = 999.0
	game.waiting.assign([game._guest(4)])
	_advance(game, float(game.waiting[0].patience) + 0.1)
	_check(game.waiting.is_empty() and game.gave_up == 1 and game.score == 0, "a guest left waiting too long takes the stairs")
	var rush := _playing("standard")
	rush._next_call = 999.0
	rush.riders.assign([{"to": 2, "rush": true}])
	_brake_onto(rush, 2.0)
	_check(rush.score >= Game.DROP_POINTS * 2, "a hurried guest pays double")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var early := game.top_speed()
	game.play_time = game.round_seconds * 0.95
	_check(game.top_speed() > early * 1.9, "the lift runs much faster by the end")
	var rushes := 0
	for call in 200:
		game.waiting.clear()
		game.car = 0.0
		game._next_call = 0.0
		game._call_guests()
		rushes += game.waiting.filter(func(g: Dictionary) -> bool: return bool(g.rush)).size()
	var calm := _playing("standard")
	var calm_rushes := 0
	for call in 200:
		calm.waiting.clear()
		calm.car = 0.0
		calm._next_call = 0.0
		calm._call_guests()
		calm_rushes += calm.waiting.filter(func(g: Dictionary) -> bool: return bool(g.rush)).size()
	_check(rushes > 20 and calm_rushes == 0, "hurried guests only come later")


func _variants_and_assist() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "rush", "heavy"], "three variants are declared")
	var heavy := _playing("heavy")
	var standard := _playing("standard")
	for lift in [heavy, standard]:
		lift.riders.assign([{"to": 4, "rush": false}, {"to": 4, "rush": false}])
	_check(heavy.brake_force() < standard.brake_force() * 0.9, "the plump ghost party weighs the car down more")
	var helped := _playing("standard", true)
	_check(helped.top_speed() < standard.top_speed() * 0.8 and helped.window(Game.LEVEL) > Game.LEVEL * 1.3, "assist slows the lift and widens what counts as level")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "rush", "heavy"]:
		var gold := _play(session, variant_id, false, 0.01)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp operator earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.09)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a clumsy operator still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, -1.0)
	_check(not idle.success and idle.score == 0, "never braking earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.01)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("lift brake scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## The floor the operator is heading for: the nearest floor ahead where a
## rider wants out or a guest waits; -1 for none.
func _target(game: Game) -> int:
	var best := -1
	var best_gap := INF
	var heading := signf(game.velocity) if absf(game.velocity) > 0.01 else float(game.direction)
	var wanted: Array[int] = []
	for rider: Dictionary in game.riders:
		wanted.append(int(rider.to))
	for guest: Dictionary in game.waiting:
		wanted.append(int(guest.floor))
	for storey in wanted:
		var gap := (storey - game.car) * heading
		if gap > game.stopping_distance() - 0.02 and gap < best_gap:
			best_gap = gap
			best = storey
	return best


## Play a whole round through Session key presses: brake when the slide
## would end on the target floor, misjudging the slide by up to `wobble`
## floors; a negative `wobble` never touches the keys.
func _play(session: Session, variant_id: String, assisted: bool, wobble: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-090", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var dice := RandomNumberGenerator.new()
	dice.seed = 13
	var held := false
	var aimed := -1
	var miss := 0.0
	while not session.ended and game.stage == "play":
		if wobble >= 0.0:
			var want := held
			if game.doors_open() or game.pinched():
				want = false
			elif held:
				want = absf(game.velocity) > 0.0
			else:
				var target := _target(game)
				if target != aimed:
					aimed = target
					miss = dice.randf_range(-wobble, wobble)
				if target >= 0:
					var gap := (target - game.car) * signf(game.velocity)
					want = gap <= game.stopping_distance() + miss and absf(game.velocity) > 0.3
			if want != held:
				_session_key(session, KEY_SPACE, want)
				held = want
		session._process(STEP)
	if held:
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


## Step the lift until braking now would stop it at `height`, then brake.
func _brake_onto(game: Game, height: float) -> void:
	for tick in 4000:
		if game.doors_open() or game.pinched():
			game.step(STEP)
			continue
		var heading := signf(game.velocity)
		if absf(game.velocity) > 0.2 and (height - game.car) * heading >= 0.0 and absf(game.car + heading * game.stopping_distance() - height) < 0.004:
			break
		game.step(STEP)
	_press(game, KEY_SPACE, true)
	_advance(game, 0.7)


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
