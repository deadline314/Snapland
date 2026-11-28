extends SceneTree
## 燈塔追潮 rules (MAIN-69): a player who picks the lane flowing its way and
## dodges barrels catches 錨錨 three times; untouched rounds never do and end
## in the postcard; lanes decide who gains; barrels are wound up and marked
## before they fly and only knock the raft back; act two flips the currents
## after a foam warning; act three's fog hides barrels outside the lamp beam;
## two catches earn no medal; rewards leave the sticker counts alone; the view
## runs headless with reduced motion.

const Game = preload("res://game/minigames/arcade/tide_chase_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var game := _round(1)
	_check(is_equal_approx(game.round_seconds, 120.0) and game.hint.size() == 2, "a 120 s chase with one hint line")
	_riding_the_right_lanes_wins()
	_untouched_never_wins()
	_lanes_decide_the_gap()
	_barrels_are_telegraphed_and_only_knock_back()
	_act_two_flips_after_a_warning()
	_act_three_fog_hides_barrels()
	_two_catches_earn_no_medal()
	_rewards_leave_counts_alone()
	await _view_runs_headless_with_reduced_motion()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: tide chase lane riding wins, untouched never wins, lane currents, barrel telegraph and knock-back, current flip warning, fog and beam, catch medal, rewards outside counts, headless reduced view")
	quit(0 if failures.is_empty() else 1)


func _riding_the_right_lanes_wins() -> void:
	for assisted in [false, true]:
		for seed in [2, 9, 23]:
			var game := _round(seed, assisted)
			var won_at := -1.0
			while game.stage != "done":
				_bot(game)
				game.step(STEP)
				if won_at < 0.0 and game.phase == "finale":
					won_at = game.play_time
			var label := "seed %d%s" % [seed, " assisted" if assisted else ""]
			_check(game.catches == Game.CATCHES and game.medal() >= 1 and game.snapshot().success, "%s: riding the right lanes catches 錨錨 three times (%d)" % [label, game.catches])
			_check(won_at > 20.0 and won_at < 110.0, "%s: the chase takes a while (%.0f s)" % [label, won_at])


func _untouched_never_wins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 69
	for seed in 50:
		var game := _round(seed)
		var guard := 0
		while game.stage != "done" and guard < 40000:
			game.step(STEP * rng.randf_range(0.4, 2.2))
			guard += 1
		if game.catches != 0 or game.score != 0 or game.snapshot().success or game.medal() != 0:
			_check(false, "seed %d: an untouched chase earns nothing" % seed)
			return
		if game.phase != "postcard" or game.fail_at < 0.0:
			_check(false, "seed %d: an untouched chase ends with the postcard" % seed)
			return


func _lanes_decide_the_gap() -> void:
	var best := _round(4)
	var worst := _round(4)
	_advance(best, Game.READY_SECONDS + 0.1)
	_advance(worst, Game.READY_SECONDS + 0.1)
	_ride(best, _best_lane(best))
	_ride(worst, _worst_lane(worst))
	var before_best := best.gap
	var before_worst := worst.gap
	best.next_throw = INF
	worst.next_throw = INF
	_advance(best, 2.0)
	_advance(worst, 2.0)
	_check(best.gap < before_best - 100.0, "a lane flowing your way closes the gap (%.0f → %.0f)" % [before_best, best.gap])
	_check(worst.gap > before_worst + 100.0 or worst.gap >= Game.MAX_GAP, "a lane against you opens it (%.0f → %.0f)" % [before_worst, worst.gap])


func _barrels_are_telegraphed_and_only_knock_back() -> void:
	var game := _round(6)
	_advance(game, Game.READY_SECONDS + 0.1)
	var guard := 0
	while game.throw_at < 0.0 and guard < 2000:
		game.step(STEP)
		guard += 1
	_check(game.throw_at >= 0.0 and game.barrels.is_empty(), "錨錨 winds up before a barrel exists")
	var marked: int = game.snapshot().throw_lane
	_advance(game, Game.THROW_WIND + 0.05)
	_check(game.barrels.size() == 1 and int(game.barrels[0].lane) == marked, "the barrel lands in the marked lane")
	# Sit in its lane and let it drift into the raft.
	_ride(game, marked)
	# Room behind for the knock-back to show.
	game.gap = 300.0
	var gap_before := game.gap
	var steps := 0
	while game.bumps == 0 and steps < 200:
		gap_before = game.gap
		game.step(STEP)
		steps += 1
	_check(game.bumps == 1 and game.gap >= gap_before + Game.BUMP_PUSH - 5.0 and game.stage == "play", "a barrel knocks the raft back and ends nothing")


func _act_two_flips_after_a_warning() -> void:
	var game := _round(8)
	_advance(game, Game.READY_SECONDS + 0.1)
	game.catches = 1
	var warned := false
	var flipped_after_warning := false
	for i in 900:
		game.step(STEP)
		if game.snapshot().flip_warning > 0.0 and not game.flipped:
			warned = true
		if game.flipped:
			flipped_after_warning = warned
			break
	_check(flipped_after_warning, "act two flips the currents only after the foam warning")
	_check(game.current(0) == float(Game.CURRENTS[1][0]), "after the flip each lane runs the other way")


func _act_three_fog_hides_barrels() -> void:
	var game := _round(10)
	game.catches = 2
	var hidden := false
	var shown := false
	for i in 40:
		game.barrels.clear()
		game.barrels.append({"lane": i % 4, "x": 500.0, "thrown_at": 0.0, "hit": false, "id": -1.0})
		game.clock += 0.13
		hidden = hidden or not game.barrel_seen(game.barrels[0])
		shown = shown or game.barrel_seen(game.barrels[0])
	_check(game.foggy() and hidden and shown, "in the fog a barrel shows only while the lamp's beam is on it")


func _two_catches_earn_no_medal() -> void:
	var game := _round(12)
	game.catches = 2
	game.score = 900
	_check(game.medal() == 0, "two catches and 900 points still earn no medal")
	game.catches = 3
	_check(game.medal() == 3, "the third catch earns the medal by score")


func _rewards_leave_counts_alone() -> void:
	var progress: Node = ProgressScript.new()
	progress.name = "TideProgressProbe"
	root.add_child(progress)
	progress.reset_progress()
	_check(not bool(progress.record_rift_result("harbor", true, 700, 2).saved), "a closed harbour rift keeps nothing")
	for index in range(1, 13):
		progress.photos["photo-harbor-devil-%d" % index] = {"game_id": "game-%03d" % (12 + index), "devil": true}
	var normal: int = progress.normal_count()
	var first: Dictionary = progress.record_rift_result("harbor", true, 700, 2)
	var postcard: Dictionary = progress.record_rift_result("harbor", false, 200, 0)
	_check(first.saved and first.first and int(first.coins) == ProgressScript.RIFT_FIRST_COINS, "the first lamp returned keeps its photo and pays")
	_check(postcard.kept and progress.photos.has(ProgressScript.rift_photo_id("harbor", true)), "the postcard is kept")
	_check(progress.normal_count() == normal and progress.devil_count("harbor") == 12 and not progress.rift_open("welcome"), "no sticker count changes and only the harbour rift is open")
	progress.queue_free()


func _view_runs_headless_with_reduced_motion() -> void:
	var game := _round(14)
	_check(game.create_view() == null, "the driver stays headless")
	var view = Game.VIEW.new()
	root.add_child(view)
	_advance(game, 6.0)
	view.present(game.snapshot(), true)
	await process_frame
	_check(view.rig.reduced_motion, "reduced motion reaches the rig")
	view.queue_free()
	await process_frame


# --- Helpers ----------------------------------------------------------------

func _round(seed: int, assisted := false) -> Game:
	var game := Game.new()
	game.round_seed = seed
	game.reset(assisted, "day")
	return game


func _best_lane(game: Game) -> int:
	var best := 0
	for lane in Game.LANES:
		if game.current(lane) > game.current(best):
			best = lane
	return best


func _worst_lane(game: Game) -> int:
	var worst := 0
	for lane in Game.LANES:
		if game.current(lane) < game.current(worst):
			worst = lane
	return worst


## Pick the fastest lane that no barrel (seen or marked) is coming down.
func _bot(game: Game) -> void:
	if game.stage != "play" or game.phase != "chase":
		return
	var danger := {}
	for barrel in game.barrels:
		if game.barrel_seen(barrel) and float(barrel.x) > 150.0 and float(barrel.x) < 560.0:
			danger[int(barrel.lane)] = true
	if game.clock - game.throw_at < Game.THROW_WIND + 0.4:
		danger[game.throw_lane] = true
	var target := game.lane
	var best_flow := -INF
	for lane in Game.LANES:
		var flow := game.current(lane) - absf(lane - game.lane) * 8.0
		if danger.has(lane):
			flow -= 500.0
		if flow > best_flow:
			best_flow = flow
			target = lane
	if absf(game.raft_lane() - game.lane) < 0.05 and target != game.lane:
		_tap(game, KEY_UP if target < game.lane else KEY_DOWN)
	if game.in_reach() and game.can_throw():
		_tap(game, KEY_SPACE)


func _ride(game: Game, lane: int) -> void:
	var guard := 0
	while game.lane != lane and guard < 10:
		_tap(game, KEY_UP if lane < game.lane else KEY_DOWN)
		_advance(game, Game.LANE_SECONDS + 0.02)
		guard += 1


func _tap(game: Game, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		game.handle_input(event, Vector2.ZERO)


func _advance(game: Game, seconds: float) -> void:
	for i in int(ceilf(seconds / STEP)):
		game.step(STEP)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
