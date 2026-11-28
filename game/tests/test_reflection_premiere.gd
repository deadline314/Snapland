extends SceneTree
## 倒影首映照 rules (MAIN-66): a player who reads the reflection reaches the
## curtain call; untouched rounds never do and end in 倒倒's selfie; the
## reflection leads the body and mirrors in act three; dashes jam the camera and
## confetti covers the lens until wiggled clean; five photos earn no medal; the
## finale's photos and coins never touch the sticker counts; the view runs
## headless with reduced motion.

const Game = preload("res://game/minigames/arcade/reflection_premiere_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_round_is_long_and_not_a_card()
	_reading_the_reflection_wins()
	_untouched_never_wins()
	_reflection_leads_and_mirrors()
	_dash_jams_the_camera()
	_confetti_covers_the_lens()
	_five_photos_earn_no_medal()
	_rewards_leave_counts_alone()
	await _view_runs_headless_with_reduced_motion()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: reflection premiere reading wins, untouched never wins, reflection lead and mirror, dash jam, confetti wipe, curtain medal, rewards outside counts, headless reduced view")
	quit(0 if failures.is_empty() else 1)


func _round_is_long_and_not_a_card() -> void:
	var game := _round(3)
	_check(is_equal_approx(game.round_seconds, 150.0), "the finale runs 150 s, past the arcade 60 s clamp (%.0f)" % game.round_seconds)
	_check(game.hint.size() == 2, "one line of hint: move and shutter")


## A player who only looks at the reflection to find the next pose, and dodges
## the dash lane and the confetti rings, gets all six photos.
func _reading_the_reflection_wins() -> void:
	for assisted in [false, true]:
		for seed in [3, 11, 29]:
			var game := _round(seed, assisted)
			var finished_at := -1.0
			while game.stage != "done":
				_bot(game)
				game.step(STEP)
				if finished_at < 0.0 and game.phase == "curtain":
					finished_at = game.play_time
			var label := "seed %d%s" % [seed, " assisted" if assisted else ""]
			_check(game.captures == Game.BALLOONS and game.medal() >= 1 and game.snapshot().success, "%s: reading the reflection reaches the curtain call (%d photos)" % [label, game.captures])
			_check(finished_at > 40.0 and finished_at < 140.0, "%s: the show lasts long enough to play three acts (%.0f s)" % [label, finished_at])
			_check(game.fail_at < 0.0, "%s: a curtain call is not a selfie" % label)


func _untouched_never_wins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	for seed in 50:
		var game := _round(seed)
		var guard := 0
		while game.stage != "done" and guard < 40000:
			game.step(STEP * rng.randf_range(0.4, 2.2))
			guard += 1
		var state: Dictionary = game.snapshot()
		if game.captures != 0 or game.score != 0 or state.success or game.medal() != 0:
			_check(false, "seed %d: an untouched round earns nothing" % seed)
			return
		if game.fail_at < 0.0 or game.phase != "selfie":
			_check(false, "seed %d: an untouched round ends in 倒倒's selfie" % seed)
			return


func _reflection_leads_and_mirrors() -> void:
	var game := _round(5)
	_advance(game, 6.0)
	var ahead: Dictionary = game.boss_at(game.clock + game.lead())
	var mirror: Dictionary = game.reflection()
	_check(is_equal_approx(float(mirror.x), float(ahead.x)) and mirror.move == ahead.move and is_equal_approx(game.lead(), 0.8), "act one: the reflection is the body 0.8 s ahead")
	var lit := false
	var opened_late := false
	for i in 600:
		game.step(STEP)
		if game.snapshot().reflection_open and not game.snapshot().pose_open:
			lit = true
		if lit and game.snapshot().pose_open:
			opened_late = true
			break
	_check(opened_late, "the reflection lights the pose before the body opens it")
	game.captures = 4
	_check(game.act() == 3 and game.mirrored(), "four photos bring act three")
	mirror = game.reflection()
	ahead = game.boss_at(game.clock + game.lead())
	_check(is_equal_approx(float(mirror.x), 1280.0 - float(ahead.x)) and is_equal_approx(game.lead(), 0.55), "act three: the reflection is mirrored left-right and leads 0.55 s")


func _dash_jams_the_camera() -> void:
	var game := _round(7)
	var dashed := false
	var guard := 0
	while not dashed and guard < 6000:
		var now: Dictionary = game.boss_at(game.clock)
		if now.kind == "dash" and float(now.t) < 0.5:
			game.frame_x = float(now.beat.x_from)
			# Through the strike (0.6 to 0.8 s into the dash) and a little past it.
			_advance(game, 0.9)
			dashed = true
		else:
			game.step(STEP)
		guard += 1
	_check(dashed and game.bumps == 1 and not game.can_shoot(), "standing in the dash lane jams the camera")
	_check(game.score == 0 and game.stage == "play", "a jam costs no points and ends nothing")
	_advance(game, Game.BUMP_SECONDS)
	_check(game.can_shoot() or game.lens_dirty() or game.clock - game.shutter_at < Game.SHUTTER_COOLDOWN, "the camera works again after the jam")


func _confetti_covers_the_lens() -> void:
	var game := _round(13)
	game.captures = 2
	var covered := false
	var guard := 0
	while not covered and guard < 9000:
		var now: Dictionary = game.boss_at(game.clock)
		if now.kind == "confetti" and float(now.t) > 0.2 and float(now.t) < 1.2 and not (now.beat.spots as Array).is_empty():
			game.frame_x = float(now.beat.spots[0])
		game.step(STEP)
		covered = game.lens_dirty()
		guard += 1
	_check(covered and not game.can_shoot(), "standing under the falling confetti covers the lens")
	_tap(game, KEY_LEFT)
	_tap(game, KEY_RIGHT)
	_tap(game, KEY_LEFT)
	_check(not game.lens_dirty(), "wiggling left and right wipes the lens clean")


func _five_photos_earn_no_medal() -> void:
	var game := _round(17)
	game.captures = 5
	game.score = 1000
	_check(game.medal() == 0, "five photos and 1000 points still earn no medal before the curtain")
	game.captures = 6
	_check(game.medal() == 2, "the curtain call earns its medal by score")


func _rewards_leave_counts_alone() -> void:
	var progress: Node = ProgressScript.new()
	progress.name = "RiftProgressProbe"
	root.add_child(progress)
	progress.reset_progress()
	var before_coins: int = progress.coins
	_check(not bool(progress.record_rift_result("welcome", true, 900, 2).saved), "a closed rift keeps nothing")
	for index in range(1, 13):
		progress.photos["photo-welcome-devil-%d" % index] = {"game_id": "game-%03d" % index, "devil": true}
	var normal: int = progress.normal_count()
	var first: Dictionary = progress.record_rift_result("welcome", true, 900, 2, "", "")
	_check(first.saved and first.first and first.kept and int(first.coins) == ProgressScript.RIFT_FIRST_COINS, "the first curtain call keeps the backstage photo and pays %d" % ProgressScript.RIFT_FIRST_COINS)
	var again: Dictionary = progress.record_rift_result("welcome", true, 1100, 3)
	_check(again.saved and not again.first and not again.kept and int(again.coins) == ProgressScript.RIFT_REPEAT_COINS, "a later curtain call pays %d and keeps no second photo" % ProgressScript.RIFT_REPEAT_COINS)
	_check(int(progress.photos[ProgressScript.rift_photo_id("welcome")].best) == 1100, "the backstage photo remembers the best score")
	var selfie: Dictionary = progress.record_rift_result("welcome", false, 300, 0)
	var selfie_again: Dictionary = progress.record_rift_result("welcome", false, 200, 0)
	_check(selfie.kept and not selfie_again.kept and int(selfie.coins) == 0, "倒倒's selfie is kept once and pays nothing")
	_check(progress.normal_count() == normal and progress.devil_count("welcome") == 12, "the finale's photos change no sticker count")
	_check(progress.coins == before_coins + ProgressScript.RIFT_FIRST_COINS + ProgressScript.RIFT_REPEAT_COINS, "coins add up")
	progress.queue_free()


func _view_runs_headless_with_reduced_motion() -> void:
	var game := _round(19)
	_check(game.create_view() == null, "the driver stays headless")
	var view = Game.VIEW.new()
	root.add_child(view)
	_advance(game, 8.0)
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


## Read the reflection for the next pose and dodge what is coming.
func _bot(game: Game) -> void:
	if game.stage != "play":
		return
	var state: Dictionary = game.snapshot()
	var target := game.frame_x
	var mirror: Dictionary = state.reflection
	var reflected_x := float(mirror.x)
	if bool(state.mirrored):
		reflected_x = 1280.0 - reflected_x
	if str(mirror.kind) == "pose" or str(state.boss.kind) == "pose":
		target = reflected_x if str(mirror.kind) == "pose" else float(state.boss.x)
	var dash: Dictionary = state.dash
	if not dash.is_empty():
		var low := minf(float(dash.from), float(dash.to)) - 110.0
		var high := maxf(float(dash.from), float(dash.to)) + 110.0
		if game.frame_x > low and game.frame_x < high:
			target = low - 40.0 if low - 40.0 > Game.X_MIN else high + 40.0
	for spot: float in state.spots:
		if float(state.get("confetti_t", 9.0)) < 1.35 and absf(target - spot) < 110.0:
			target = spot + (130.0 if spot < 640.0 else -130.0)
	_hold(game, target)
	if game.pose_open() and absf(game.frame_x - float(state.boss.x)) < 50.0 and game.can_shoot():
		_tap(game, KEY_SPACE)
	if game.lens_dirty():
		_tap(game, KEY_LEFT)
		_tap(game, KEY_RIGHT)


func _hold(game: Game, target: float) -> void:
	var want := 0
	if target > game.frame_x + 10.0:
		want = 1
	elif target < game.frame_x - 10.0:
		want = -1
	if want != game._dir:
		_key(game, KEY_LEFT, false)
		_key(game, KEY_RIGHT, false)
		if want != 0:
			_key(game, KEY_RIGHT if want > 0 else KEY_LEFT, true)


func _key(game: Game, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game.handle_input(event, Vector2.ZERO)


func _tap(game: Game, code: Key) -> void:
	_key(game, code, true)
	_key(game, code, false)


func _advance(game: Game, seconds: float) -> void:
	var steps := int(ceilf(seconds / STEP))
	for i in steps:
		game.step(STEP)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
