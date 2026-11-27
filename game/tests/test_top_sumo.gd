extends SceneTree
## 陀螺相撲 rules: the demo nudge, steering, spin loss and wobble, rams and re-spin,
## knockouts and combos, falling off and toppling, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/top_sumo_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 120.0
const ARROWS := {&"up": KEY_UP, &"down": KEY_DOWN, &"left": KEY_LEFT, &"right": KEY_RIGHT}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_push()
	_steering_and_spin()
	_rams_and_knockouts()
	_falling_and_toppling()
	_the_round_escalates()
	_variants_change_the_dish()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: top sumo steering, spin loss, rams, knockouts, combos, falls, topples, shrinking rim, rivals, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_push() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.tops.size() == 2 and game.hero_top().state == "spin" and game.thresholds == [120, 300, 500],
		"a round opens with your top and one rival on the dish and its medal lines declared")
	var start: float = game.hero_top().pos.distance_to(game.tops[1].pos)
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_hold(game, &"down", true)
		game.step(STEP)
	_hold(game, &"down", false)
	_check(game.score == 0 and game.hero_top().spin == 1.0 and float(game.tops[1].hit) > 0.0 and game.knockouts == 0,
		"the countdown nudges your top into the rival by itself; arrows do nothing yet (start gap %.0f)" % start)
	_advance(game, 0.1)
	_check(game.stage == "play" and game.hero_top().spin > 0.99, "play starts at full spin")


func _steering_and_spin() -> void:
	var game := _playing("standard")
	_clear(game)
	var hero := game.hero_top()
	hero.pos = Vector2.ZERO
	hero.vel = Vector2.ZERO
	_hold(game, &"right", true)
	_advance(game, 0.3)
	var pushed: float = hero.vel.x
	_check(pushed > 200.0 and absf(hero.vel.y) < 1.0 and hero.pos.x > 20.0, "holding an arrow pushes your top that way (%.0f)" % pushed)
	_hold(game, &"right", false)
	_hold(game, &"up", true)
	_advance(game, 0.2)
	_hold(game, &"up", false)
	_check(hero.vel.y < -100.0, "up pushes it away from the viewer")
	hero.vel = Vector2(300, 0)
	_advance(game, 0.5)
	_check(hero.vel.length() < 300.0 * 0.5, "it slides to a stop when let go")
	hero.pos = Vector2.ZERO
	hero.vel = Vector2.ZERO
	var before: float = hero.spin
	_advance(game, 2.0)
	_check(absf(before - hero.spin - Game.SPIN_DECAY * 2.0) < 0.01, "every top slowly loses spin")
	hero.spin = 0.2
	hero.pos = Vector2.ZERO
	hero.vel = Vector2.ZERO
	_hold(game, &"right", true)
	_advance(game, 0.3)
	_hold(game, &"right", false)
	_check(hero.vel.x < pushed * 0.8, "a tired top pushes weaker")
	hero.pos = Vector2.ZERO
	hero.vel = Vector2.ZERO
	hero.spin = 1.0
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	game.handle_input(stick, Vector2.ZERO)
	_advance(game, 0.2)
	stick = stick.duplicate()
	stick.axis_value = 0.0
	game.handle_input(stick, Vector2.ZERO)
	_check(hero.vel.x < -150.0 and game.steer() == Vector2.ZERO, "the gamepad stick steers the same way and lets go when centred")
	var helped := _playing("standard", true)
	var spin: float = helped.hero_top().spin
	_advance(helped, 2.0)
	_check(spin - helped.hero_top().spin < Game.SPIN_DECAY * 2.0 * 0.8, "assist slows the spin loss")


func _rams_and_knockouts() -> void:
	var game := _playing("standard")
	_clear(game)
	var hero := game.hero_top()
	hero.state = "spin"
	var rival := _rival(game, Vector2(150, 0), false)
	hero.pos = Vector2(80, 0)
	hero.vel = Vector2(400, 0)
	hero.spin = 0.5
	_advance(game, 0.2)
	_check(rival.vel.x > 150.0 and hero.spin > 0.5 + Game.RAM_SPIN * 0.9 and game.ram_at > 0.0 and game.snapshot().word_good,
		"a hard ram shoves the rival and spins your top back up")
	_advance(game, 1.2)
	_check(rival.state == "out" and game.knockouts == 1 and game.score == Game.KO_POINTS, "a rival pushed over the rope is out: %d points" % Game.KO_POINTS)
	var second := _rival(game, Vector2(game.rim - 5.0, 0), false)
	second.hit = game.clock
	second.vel = Vector2(200, 0)
	_advance(game, 0.1)
	_check(game.knockouts == 2 and game.score == Game.KO_POINTS * 2 + Game.COMBO_POINTS, "two knockouts in quick succession add a combo bonus")
	_advance(game, Game.COMBO_SECONDS + 0.1)
	var big := _rival(game, Vector2(-game.rim + 5.0, 0), true)
	big.hit = game.clock - 2.0
	big.vel = Vector2(-200, 0)
	_advance(game, 0.1)
	_check(game.score == Game.KO_POINTS * 2 + Game.COMBO_POINTS + Game.BIG_POINTS, "a big rival is worth more")
	var stray := _rival(game, Vector2(0, game.rim - 5.0), false)
	stray.vel = Vector2(0, 200)
	var score := game.score
	_advance(game, 0.1)
	_check(stray.state == "out" and game.score == score, "a rival that wanders out untouched scores nothing")
	var light := _playing("standard")
	_clear(light)
	light.hero_top().state = "spin"
	var heavy := _rival(light, Vector2(70, 0), true)
	light.hero_top().pos = Vector2.ZERO
	light.hero_top().vel = Vector2(400, 0)
	_advance(light, 0.05)
	_check(heavy.vel.x < 300.0 and light.hero_top().vel.x < 200.0, "a big rival barely budges and bounces your top back")


func _falling_and_toppling() -> void:
	var game := _playing("standard")
	_clear(game)
	var hero := game.hero_top()
	hero.pos = Vector2(game.rim - 2.0, 0)
	hero.vel = Vector2(100, 0)
	_advance(game, 0.05)
	_check(hero.state == "out" and game.falls == 1 and game.mistakes == 0 and not game.snapshot().word_good,
		"pushed over the rope, your top falls off; the first fall is a free lesson")
	_hold(game, &"left", true)
	_advance(game, 0.5)
	_hold(game, &"left", false)
	_check(hero.state == "out" and hero.pos.length() > game.rim, "it keeps rolling away; the arrows do nothing")
	_advance(game, Game.RESPAWN_SECONDS - 0.5)
	_check(hero.state == "drop" and hero.pos == Vector2.ZERO and hero.spin == 1.0, "a fresh top is launched into the middle")
	_advance(game, Game.DROP_SECONDS + 0.05)
	_check(hero.state == "spin", "and spins again after it lands")
	hero.spin = 0.001
	_advance(game, 0.1)
	_check(hero.state == "topple" and game.falls == 2 and game.mistakes == 1, "a top that runs out of spin topples, and later falls count as mistakes")


func _the_round_escalates() -> void:
	var game := _playing("standard")
	var crowd_early := 0
	var crowd_late := 0
	var first_big := -1.0
	while game.stage == "play":
		# Keep your top safe in the middle so the round shows what the rivals do.
		var hero := game.hero_top()
		hero.pos = Vector2.ZERO
		hero.spin = 1.0
		game.step(STEP)
		if game.heat() < 0.25:
			crowd_early = maxi(crowd_early, game.rivals_spinning())
		elif game.heat() > 0.75:
			crowd_late = maxi(crowd_late, game.rivals_spinning())
		for top in game.tops:
			if top.kind == "big" and first_big < 0.0:
				first_big = game.heat()
	_check(is_equal_approx(game.rim, Game.RIM_END), "the rope closes in through the round (%.0f)" % game.rim)
	_check(crowd_early == 1 and crowd_late == 3, "more rivals join later (%d to %d)" % [crowd_early, crowd_late])
	_check(first_big >= Game.BIG_HEAT, "big rivals only join later (%.2f)" % first_big)


func _variants_change_the_dish() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "slippery", "crowd", "heavy"], "four variants are declared")
	var glide := {}
	for variant_id: String in ["standard", "slippery"]:
		var game := _playing(variant_id)
		_clear(game)
		game.hero_top().state = "spin"
		game.hero_top().pos = Vector2.ZERO
		game.hero_top().vel = Vector2(300, 0)
		_advance(game, 0.4)
		glide[variant_id] = game.hero_top().pos.x
	_check(glide.slippery > glide.standard * 1.2, "the slippery dish lets tops glide further")
	var crowd := _playing("crowd")
	_advance(crowd, 2.0)
	_check(crowd.rivals_spinning() == 2, "the brawl starts with two rivals")
	var heavy := _playing("heavy")
	var big := false
	while heavy.heat() < 0.3:
		heavy.step(STEP)
		for top in heavy.tops:
			big = big or top.kind == "big"
		# Clear the dish whenever a rival has landed, so new ones keep dropping in.
		if heavy.rivals_spinning() > 0 and heavy.tops[-1].state == "spin":
			heavy.tops.resize(1)
	_check(big, "the heavyweight dish sends big rivals from the start")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "slippery", "crowd", "heavy"]:
		var gold := _play(session, variant_id, false, 0.0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "herding rivals out from the middle earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "standard", false, 0.7)
	_check(bronze.success and not bronze.devil and bronze.score >= lines[0] and bronze.score < lines[1] and bronze.score_summary.medal == 1,
		"a distracted pusher still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "standard", false, 1.0)
	_check(not idle.success and idle.score < lines[0] and idle.mistakes > 0, "standing still earns nothing (score %d)" % idle.score)
	var helped := _play(session, "standard", true, 0.0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("top sumo scores: gold %s, bronze %d, idle %d, assisted %d" % [gold_scores, bronze.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session input with arrow keys: line up behind the
## nearest rival and drive it outward, back off from the rope; `idle` is the
## share of each two seconds spent not steering at all.
func _play(session: Session, variant_id: String, assisted: bool, idle: float) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-068", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var held: Dictionary = {}
	while not session.ended and game.stage == "play":
		var want := _bot(game) if fmod(game.clock, 2.0) >= idle * 2.0 else Vector2.ZERO
		var keys := {}
		if want.x < -0.38:
			keys[&"left"] = true
		elif want.x > 0.38:
			keys[&"right"] = true
		if want.y < -0.38:
			keys[&"up"] = true
		elif want.y > 0.38:
			keys[&"down"] = true
		for button: StringName in ARROWS:
			if keys.has(button) != held.has(button):
				_session_key(session, ARROWS[button], keys.has(button))
		held = keys
		session._process(STEP)
	for button: StringName in held:
		_session_key(session, ARROWS[button], false)
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


## Unit direction for the bot: hold the middle and charge the nearest rival
## whenever it is further out than your top.
func _bot(game: Game) -> Vector2:
	var hero := game.hero_top()
	if hero.state != "spin":
		return Vector2.ZERO
	var target: Dictionary = {}
	for top in game.tops:
		if top.kind != "hero" and top.state == "spin" and (target.is_empty() or top.pos.distance_to(hero.pos) < target.pos.distance_to(hero.pos)):
			target = top
	if target.is_empty() or target.pos.length() < hero.pos.length() - 10.0 or hero.pos.length() > game.rim * 0.7:
		return -hero.pos.normalized() if hero.pos.length() > 15.0 else Vector2.ZERO
	return (target.pos - hero.pos).normalized()


func _clear(game: Game) -> void:
	game.tops.resize(1)
	game.hero_top().state = "spin"
	game._spawn_wait = -999.0


func _rival(game: Game, at: Vector2, big: bool) -> Dictionary:
	game._add_rival(at, big)
	var rival: Dictionary = game.tops[-1]
	rival.state = "spin"
	return rival


func _hold(game: Base, button: StringName, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = ARROWS[button]
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


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


## Step `seconds`; a dish emptied by _clear() stays without new rivals.
func _advance(game: Base, seconds: float) -> void:
	var frozen: bool = game._spawn_wait < -100.0
	var left := seconds
	while left > 0.0:
		game.step(minf(left, STEP))
		if frozen:
			game._spawn_wait = -999.0
		left -= STEP


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
