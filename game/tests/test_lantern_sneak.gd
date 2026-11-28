extends SceneTree
## 燈籠捉迷藏 rules (MAIN-72): a player who waits out the light and comes in
## from the side taps 燈燈 three times; untouched rounds never do and end as a
## lantern; the light reaches only its fan and carts block it; a tap counts
## only from behind and out of the light; getting caught only sends you back;
## 燈燈 goes "hm?" before every snap turn; act two slides the carts after
## marking their places and act three adds a floating lantern; two taps earn
## no medal; rewards leave the sticker counts alone; the view runs headless
## with reduced motion.

const Game = preload("res://game/minigames/arcade/lantern_sneak_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []
var _keys := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var game := _round(1)
	_check(is_equal_approx(game.round_seconds, 110.0) and game.hint.size() == 2, "a 110 s show with one hint line")
	_sneaking_wins()
	_untouched_never_wins()
	_light_reaches_its_fan_and_carts_block_it()
	_taps_count_only_from_behind()
	_getting_caught_sends_you_back()
	_hm_comes_before_every_snap_turn()
	_acts_slide_carts_and_float_a_lantern()
	_two_taps_earn_no_medal()
	_rewards_leave_counts_alone()
	await _view_runs_headless_with_reduced_motion()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: lantern sneak sneaking wins, untouched never wins, light fan and cart shadows, taps from behind, caught sends back, hm before snap, sliding carts and floating lantern, tap medal, rewards outside counts, headless reduced view")
	quit(0 if failures.is_empty() else 1)


func _sneaking_wins() -> void:
	for assisted in [false, true]:
		for seed in [2, 13, 31]:
			var game := _round(seed, assisted)
			_keys.clear()
			var won_at := -1.0
			while game.stage != "done":
				_bot(game)
				game.step(STEP)
				if won_at < 0.0 and game.phase == "finale":
					won_at = game.play_time
			var label := "seed %d%s" % [seed, " assisted" if assisted else ""]
			_check(game.taps == Game.TAPS and game.medal() >= 1 and game.snapshot().success, "%s: sneaking round taps 燈燈 three times (%d taps, %d caught)" % [label, game.taps, game.caught])
			# A perfect bot is quick; assist (longer reach, slower light) quicker still.
			_check(won_at > (8.0 if assisted else 15.0) and won_at < 105.0, "%s: the show takes a while (%.0f s)" % [label, won_at])


func _untouched_never_wins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	for seed in 50:
		var game := _round(seed)
		var guard := 0
		while game.stage != "done" and guard < 40000:
			game.step(STEP * rng.randf_range(0.4, 2.2))
			guard += 1
		if game.taps != 0 or game.score != 0 or game.snapshot().success or game.medal() != 0:
			_check(false, "seed %d: an untouched show earns nothing" % seed)
			return
		if game.phase != "lanterned" or game.fail_at < 0.0:
			_check(false, "seed %d: an untouched show ends as a lantern" % seed)
			return


func _light_reaches_its_fan_and_carts_block_it() -> void:
	var game := _round(4)
	_advance(game, Game.READY_SECONDS + 0.1)
	game.carts.clear()
	var lamp := game.lamp()
	var ahead := lamp + Vector2.from_angle(game.beam_angle()) * 200.0
	var aside := lamp + Vector2.from_angle(game.beam_angle() + PI * 0.5) * 200.0
	var far := lamp + Vector2.from_angle(game.beam_angle()) * (Game.BEAM_RANGE + 60.0)
	_check(game.lit(ahead) and not game.lit(aside) and not game.lit(far), "the light reaches its fan and no further")
	game.carts.append(lamp.lerp(ahead, 0.5))
	_check(not game.lit(ahead), "a cart in the way casts a shadow to hide in")


func _taps_count_only_from_behind() -> void:
	var game := _round(6)
	_advance(game, Game.READY_SECONDS + 0.1)
	game.carts.clear()
	game.player = game.spot + Vector2.from_angle(game.facing) * 50.0
	game.caught_at = -99.0
	_tap(game, KEY_SPACE)
	_check(game.taps == 0 and game.score == 0, "a tap from in front does nothing")
	game.player = game.spot - Vector2.from_angle(game.facing) * 50.0
	game.tapped_at = -99.0
	var first_spot := game.spot
	_tap(game, KEY_SPACE)
	_check(game.taps == 1 and game.score > 0 and game.spot != first_spot, "a tap from behind counts, and 燈燈 hops to its next spot")


func _getting_caught_sends_you_back() -> void:
	var game := _round(8)
	_advance(game, Game.READY_SECONDS + 0.1)
	game.carts.clear()
	game.player = game.lamp() + Vector2.from_angle(game.beam_angle()) * 150.0
	game.next_turn = INF
	_advance(game, 0.1)
	_check(game.caught == 1 and game.player.distance_to(Game.START) < 1.0 and game.stage == "play", "the light catches you and sends you back to the start, and the show goes on")


func _hm_comes_before_every_snap_turn() -> void:
	var game := _round(10)
	_advance(game, Game.READY_SECONDS + 0.1)
	var turns := 0
	var warned := 0
	var facing := game.facing
	var alert_seen := false
	for i in 1200:
		game.step(STEP)
		alert_seen = alert_seen or game.alerting()
		if not is_equal_approx(game.facing, facing):
			turns += 1
			if alert_seen:
				warned += 1
			alert_seen = false
			facing = game.facing
	_check(turns >= 2 and warned == turns, "every snap turn comes after a \"hm?\" (%d of %d)" % [warned, turns])


func _acts_slide_carts_and_float_a_lantern() -> void:
	var game := _round(12)
	_advance(game, Game.READY_SECONDS + 0.1)
	game.taps = 1
	var start := game.carts.duplicate()
	var marked := false
	var moved := false
	for i in 1200:
		game.step(STEP)
		if not (game.snapshot().cart_targets as Array).is_empty() and game.carts == start:
			marked = true
		if game.carts != start:
			moved = true
			break
	_check(marked and moved, "act two marks the carts' new places, then slides them")
	game.taps = 2
	_check(game.float_lamp().x > 0.0, "act three floats a second lantern")


func _two_taps_earn_no_medal() -> void:
	var game := _round(14)
	game.taps = 2
	game.score = 950
	_check(game.medal() == 0, "two taps and 950 points still earn no medal")
	game.taps = 3
	_check(game.medal() == 3, "the third tap earns the medal by score")


func _rewards_leave_counts_alone() -> void:
	var progress: Node = ProgressScript.new()
	progress.name = "SneakProgressProbe"
	root.add_child(progress)
	progress.reset_progress()
	_check(not bool(progress.record_rift_result("nightmarket", true, 800, 2).saved), "a closed night market rift keeps nothing")
	for index in range(1, 13):
		progress.photos["photo-nightmarket-devil-%d" % index] = {"devil": true}
	var normal: int = progress.normal_count()
	var first: Dictionary = progress.record_rift_result("nightmarket", true, 800, 2)
	var lantern: Dictionary = progress.record_rift_result("nightmarket", false, 0, 0)
	_check(first.saved and first.first and lantern.kept, "the lit street photo and the lantern photo are kept")
	_check(progress.normal_count() == normal and progress.devil_count("nightmarket") == 12, "no sticker count changes")
	progress.queue_free()


func _view_runs_headless_with_reduced_motion() -> void:
	var game := _round(16)
	_check(game.create_view() == null, "the driver stays headless")
	var view = Game.VIEW.new()
	root.add_child(view)
	_advance(game, 5.0)
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


## Sneak: tap when behind and in reach; otherwise head for 燈燈's side, then its
## back, never stepping into the light; on "hm?" get out from behind.
func _bot(game: Game) -> void:
	if game.stage != "play" or game.phase != "sneak":
		_hold(game, Vector2.ZERO)
		return
	if game.can_tap() and game.behind(game.player) and game.player.distance_to(game.spot) < Game.REACH - 8.0 and not game.lit(game.player):
		_tap(game, KEY_SPACE)
		return
	var face := Vector2.from_angle(game.facing)
	var side := face.orthogonal()
	if side.dot(game.player - game.spot) < 0.0:
		side = -side
	var target := game.spot - face * 50.0
	if face.dot(game.player - game.spot) > -10.0 or game.alerting():
		# In front (or about to be): swing wide round the side first.
		target = game.spot + side * 140.0 - face * 20.0
	var dir := (target - game.player)
	if dir.length() < 4.0:
		_hold(game, Vector2.ZERO)
		return
	dir = dir.normalized()
	var ahead := game.player + dir * Game.SPEED * 0.25
	if game.lit(ahead) and not game.lit(game.player):
		# Wait for the light to sweep past.
		_hold(game, Vector2.ZERO)
		return
	_hold(game, dir)


func _hold(game: Game, dir: Vector2) -> void:
	var want := {KEY_LEFT: dir.x < -0.35, KEY_RIGHT: dir.x > 0.35, KEY_UP: dir.y < -0.35, KEY_DOWN: dir.y > 0.35}
	for code: int in want:
		if bool(want[code]) != bool(_keys.get(code, false)):
			_keys[code] = want[code]
			_key(game, code, want[code])


func _key(game: Game, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game.handle_input(event, Vector2.ZERO)


func _tap(game: Game, code: Key) -> void:
	_key(game, code, true)
	_key(game, code, false)


func _advance(game: Game, seconds: float) -> void:
	for i in int(ceilf(seconds / STEP)):
		game.step(STEP)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
