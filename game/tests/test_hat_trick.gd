extends SceneTree
## 帽中套物 rules: holding to pull, banking the line, the skunk and its warning,
## bluffing hats, the empty hat, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/hat_trick_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_holding_pulls_and_letting_go_banks()
	_the_skunk_and_its_warning()
	_bluffs_and_the_empty_hat()
	_it_gets_riskier()
	_variants_change_the_hats()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: hat trick pulls, line, bank, pot, warnings real and bluffed, skunk cloud, empty hat, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.thresholds == [400, 750, 1200] and game.line.is_empty(), "a round opens on an empty line with its medal lines declared")
	_key(game, true)
	_advance(game, 1.7)
	_check(game.line.size() == 3 and game.line[2].kind == "rabbit" and game.score == 0, "the countdown pulls two scarves and a rabbit by itself; presses do nothing yet")
	_key(game, false)
	_advance(game, Base.READY_SECONDS)
	_check(game.stage == "play" and game.phase == "idle" and game.line.is_empty() and game.score == 0, "play starts with a fresh hat and an empty line")
	var eager := _round("standard", false)
	_key(eager, true)
	_advance(eager, Base.READY_SECONDS + Game.FIRST_PULL + 0.1)
	_check(eager.phase == "pull" and eager.line.size() == 1, "holding through the countdown starts pulling as play begins")


func _holding_pulls_and_letting_go_banks() -> void:
	var game := _playing("standard")
	_safe_hat(game, ["scarf", "rabbit", "bouquet", "dove", "scarf", "scarf", "scarf", "scarf"])
	_key(game, true)
	_advance(game, Game.FIRST_PULL - 0.05)
	_check(game.phase == "pull" and game.line.is_empty(), "holding starts the pull; the first trick takes a moment")
	_advance(game, 0.1 + game.gap * 2.0)
	_check(game.line.size() == 3 and game.line[1].kind == "rabbit", "items keep coming out while held, one per beat")
	_check(game.pot() == 40, "three tricks are worth their face value (%d)" % game.pot())
	_advance(game, game.gap * 3.0)
	var expected := (5 + 25 + 10 + 15 + 5 + 5) * 2
	_check(game.line.size() == 6 and game.pot() == expected, "six tricks are worth double: the pot grows faster than the line (%d)" % game.pot())
	_key(game, false)
	_check(game.phase == "bow" and game.score == expected and game.last_bank == expected, "letting go banks the whole line")
	_advance(game, Game.BOW_SECONDS + 0.05)
	_check(game.phase == "idle" and game.line.is_empty() and game.hats == 3, "after the bow a new hat is ready")
	var tap := _playing("standard")
	_key(tap, true)
	_advance(tap, 0.1)
	_key(tap, false)
	_check(tap.phase == "idle" and tap.score == 0, "a tap that pulls nothing just leaves the hat as it is")
	var keen := _playing("standard")
	_safe_hat(keen, ["scarf", "scarf", "scarf", "scarf"])
	_key(keen, true)
	_advance(keen, Game.FIRST_PULL + 0.05)
	_key(keen, false)
	_key(keen, true)
	_advance(keen, Game.BOW_SECONDS + Game.FIRST_PULL + 0.1)
	_check(keen.phase == "pull" and keen.line.size() == 1, "pressing again during the bow starts the next hat straight after it")


func _the_skunk_and_its_warning() -> void:
	var game := _playing("standard")
	_rig(game, ["scarf", "scarf", "rabbit", "skunk"], {3: "both"})
	_key(game, true)
	_advance(game, Game.FIRST_PULL + 0.05)
	_check(game.line.size() == 1 and game.warning_now() == "", "no warning while the skunk is still a way off")
	_advance(game, game.gap * 3.0 - game.warn)
	_check(game.warning_now() == "both", "just before the skunk the hat both shakes and smokes")
	var risky := game.score
	_advance(game, game.warn)
	_check(game.phase == "stink" and game.score == risky and game.stinks == 1 and game.mistakes == 0 and game.fail_at >= 0.0,
		"held too long: the skunk comes out, the line is lost and the first time is free")
	_key(game, false)
	_advance(game, Game.STINK_SECONDS + 0.05)
	_check(game.phase == "idle" and game.line.is_empty(), "the cloud clears and a new hat is ready")
	_rig(game, ["scarf", "scarf", "scarf", "skunk"], {3: "both"})
	_key(game, true)
	_advance(game, Game.FIRST_PULL + game.gap * 3.0 + 0.05)
	_check(game.stinks == 2 and game.mistakes == 1, "later skunks are mistakes")
	_key(game, false)
	var saved := _playing("standard")
	_rig(saved, ["scarf", "scarf", "rabbit", "skunk"], {3: "both"})
	_key(saved, true)
	_advance(saved, Game.FIRST_PULL + saved.gap * 3.0 - saved.warn * 0.5)
	_key(saved, false)
	_check(saved.phase == "bow" and saved.score == 35 + Game.CLOSE_CALL, "letting go during the real warning banks the line plus a close-call bonus (%d)" % saved.score)
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	_check(helped.warn > Game.WARN_EARLY * 1.4 and helped.gap == Game.GAP_EARLY, "assist warns longer without slowing the tricks")


func _bluffs_and_the_empty_hat() -> void:
	var game := _playing("standard")
	_rig(game, ["scarf", "scarf", "dove", "scarf", "scarf", "skunk"], {2: "shake", 5: "both"})
	_key(game, true)
	_advance(game, Game.FIRST_PULL + game.gap * 2.0 - 0.05)
	_check(game.warning_now() == "shake", "a bluffing hat only shakes")
	_advance(game, 0.1)
	_check(game.phase == "pull" and game.line[2].kind == "dove", "and out comes an ordinary trick")
	_key(game, false)
	var full := _playing("standard")
	var tricks: Array[String] = []
	for index in Game.MAX_ITEMS:
		tricks.append("scarf")
	_rig(full, tricks, {})
	_key(full, true)
	_advance(full, Game.FIRST_PULL + full.gap * Game.MAX_ITEMS + 0.1)
	_check(full.phase == "bow" and full.score == Game.EMPTY_BONUS + 5 * Game.MAX_ITEMS * Game.MAX_ITEMS / 3,
		"a hat that runs out of tricks banks itself with a bonus (%d)" % full.score)
	var demo := Game.new()
	demo.round_seed = 3
	demo.reset(false, "noon")
	var kinds := {}
	var shapes := {}
	for hat in 200:
		demo._new_hat()
		_check(demo.hat_items.find("skunk") < 0 or demo.hat_items.find("skunk") >= Game.SAFE_ITEMS, "no skunk among the first tricks of a hat")
		if demo.hat_items.has("skunk"):
			_check(demo.warnings.get(demo.hat_items.size() - 1, "") == "both", "every skunk is warned by both signs")
		for index: int in demo.warnings:
			shapes[demo.warnings[index]] = true
		for kind in demo.hat_items:
			kinds[kind] = true
	_check(kinds.size() == 5 and shapes.size() == 3, "hats hold all four tricks and the skunk, with real and bluffed warnings")


func _it_gets_riskier() -> void:
	var early := _playing("standard")
	var late := _playing("standard")
	late.play_time = late.round_seconds * 0.95
	var early_skunk := 0.0
	var late_skunk := 0.0
	var early_fakes := 0
	var late_fakes := 0
	for hat in 300:
		early._new_hat()
		late._new_hat()
		early_skunk += early.hat_items.size() if early.hat_items.has("skunk") else Game.MAX_ITEMS
		late_skunk += late.hat_items.size() if late.hat_items.has("skunk") else Game.MAX_ITEMS
		early_fakes += early.warnings.size() - int(early.hat_items.has("skunk"))
		late_fakes += late.warnings.size() - int(late.hat_items.has("skunk"))
	_check(late.gap < early.gap * 0.7 and late.warn < early.warn * 0.7, "late hats pull faster and warn later")
	_check(late_skunk < early_skunk * 0.85 and late_fakes > early_fakes, "late hats hide the skunk sooner and bluff more (%.1f vs %.1f items, %d vs %d bluffs)"
		% [early_skunk / 300.0, late_skunk / 300.0, early_fakes, late_fakes])


func _variants_change_the_hats() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "bluff", "bunnies"], "three variants are declared")
	var tally := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var counts := {"fakes": 0, "rabbits": 0, "length": 0}
		for hat in 300:
			game._new_hat()
			counts.fakes += game.warnings.size() - int(game.hat_items.has("skunk"))
			counts.rabbits += game.hat_items.count("rabbit")
			counts.length += game.hat_items.size()
		tally[variant_id] = counts
	_check(tally.bluff.fakes > tally.standard.fakes * 2, "the bluffing hat fakes far more warnings (%s)" % tally)
	_check(tally.bunnies.rabbits > tally.standard.rabbits * 1.6 and tally.bunnies.length < tally.standard.length, "the bunny hat is full of rabbits but hides the skunk sooner (%s)" % tally)


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "bluff", "bunnies"]:
		# Gold: keeps pulling through bluffs and lets go a quarter second after the hat both shakes and smokes.
		var gold := _play(session, variant_id, false, 0.25, false, 99)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1, "a sharp-eyed magician earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: jumpy at every sign, slow to let go and never pulls more than four.
	var bronze := _play(session, "standard", false, 0.55, true, 4)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1, "a nervous magician still earns bronze (score %d)" % bronze.score)
	var greedy := _play(session, "standard", false, 99.0, false, 99)
	_check(not greedy.success and greedy.mistakes > 3, "never letting go meets the skunk every time (score %d)" % greedy.score)
	var idle := _play(session, "standard", false, 99.0, false, 0)
	_check(not idle.success and idle.score == 0, "never pulling earns nothing")
	var helped := _play(session, "standard", true, 0.25, false, 99)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("hat trick scores: gold %s, bronze %d, greedy %d, idle %d, assisted %d" % [gold_scores, bronze.score, greedy.score, idle.score, helped.score])
	session.free()


## Play a whole round through Session input: hold, and let go `delay` seconds
## after the hat warns (any sign if `jumpy`, else only both), or at `cap` items.
func _play(session: Session, variant_id: String, assisted: bool, delay: float, jumpy: bool, cap: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-053", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var holding := false
	var seen_at := -1.0
	while not session.ended and game.stage == "play":
		if cap > 0 and not holding and game.phase == "idle":
			_session_key(session, true)
			holding = true
			seen_at = -1.0
		if holding and game.phase == "pull":
			var cue := game.warning_now()
			if (cue == "both" or (jumpy and cue != "")) and seen_at < 0.0:
				seen_at = game.clock
			if (seen_at >= 0.0 and game.clock - seen_at >= delay) or game.line.size() >= cap:
				_session_key(session, false)
				holding = false
		elif holding and game.phase == "stink":
			_session_key(session, false)
			holding = false
		_run_session(session, STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	if holding:
		_session_key(session, false)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


func _session_key(session: Session, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	session._unhandled_input(key)


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


## Replace the hat about to be pulled.
func _rig(game: Game, items: Array[String], warned: Dictionary) -> void:
	game.hat_items = items
	game.warnings = warned


func _safe_hat(game: Game, items: Array[String]) -> void:
	_rig(game, items, {})


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
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


func _key(game: Base, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
