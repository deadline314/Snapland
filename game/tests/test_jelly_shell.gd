extends SceneTree
## 果凍真身 rules (MAIN-70): a player who watches for the jelly that wobbles
## late fills three moulds; untouched rounds never do and end jellied; only
## the real one lags; a copy bursts, gums the traveller up and the round goes
## on; acts add copies and swaps and act three flips gravity mid-shuffle; two
## moulds earn no medal; rewards leave the sticker counts alone; the view runs
## headless with reduced motion.

const Game = preload("res://game/minigames/arcade/jelly_shell_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var game := _round(1)
	_check(is_equal_approx(game.round_seconds, 120.0) and game.hint.size() == 2, "a 120 s show with one hint line")
	_watching_the_late_one_wins()
	_untouched_never_wins()
	_only_the_real_one_lags()
	_a_copy_bursts_and_the_round_goes_on()
	_acts_grow_and_gravity_flips()
	_five_moulds_earn_no_medal()
	_rewards_leave_counts_alone()
	await _view_runs_headless_with_reduced_motion()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: jelly shell late-wobble reading wins, untouched never wins, only the real one lags, copy burst and goo, acts and gravity flip, mould medal, rewards outside counts, headless reduced view")
	quit(0 if failures.is_empty() else 1)


func _watching_the_late_one_wins() -> void:
	for assisted in [false, true]:
		for seed in [3, 11, 27]:
			var game := _round(seed, assisted)
			var won_at := -1.0
			while game.stage != "done":
				_bot(game)
				game.step(STEP)
				if won_at < 0.0 and game.phase == "finale":
					won_at = game.play_time
			var label := "seed %d%s" % [seed, " assisted" if assisted else ""]
			_check(game.moulds == Game.MOULDS and game.medal() >= 1 and game.snapshot().success, "%s: watching the late wobble fills six moulds (%d)" % [label, game.moulds])
			_check(won_at > 25.0 and won_at < 110.0, "%s: the show takes a while (%.0f s)" % [label, won_at])
			_check(game.wrong == 0, "%s: reading the tell never scoops a copy (%d)" % [label, game.wrong])


func _untouched_never_wins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70
	for seed in 50:
		var game := _round(seed)
		var guard := 0
		while game.stage != "done" and guard < 40000:
			game.step(STEP * rng.randf_range(0.4, 2.2))
			guard += 1
		if game.moulds != 0 or game.score != 0 or game.snapshot().success or game.medal() != 0:
			_check(false, "seed %d: an untouched show earns nothing" % seed)
			return
		if game.phase != "jellied" or game.fail_at < 0.0:
			_check(false, "seed %d: an untouched show ends jellied" % seed)
			return


func _only_the_real_one_lags() -> void:
	var game := _round(5)
	_to_pick(game)
	_advance(game, 0.5)
	var lagging := 0
	var on_beat := 0
	for jelly: Dictionary in game.layout():
		if is_equal_approx(float(jelly.t), game.clock - game.lag()):
			lagging += 1
			_check(bool(jelly.real), "the lagging jelly is the real one")
		elif is_equal_approx(float(jelly.t), game.clock):
			on_beat += 1
	_check(lagging == 1 and on_beat == game.slots() - 1, "one jelly lags the beat, the rest keep it (%d late, %d on beat)" % [lagging, on_beat])


func _a_copy_bursts_and_the_round_goes_on() -> void:
	var game := _round(7)
	_to_pick(game)
	var wrong_slot := (game.real_slot() + 1) % game.slots()
	game.cursor = wrong_slot
	_tap(game, KEY_SPACE)
	_check(game.wrong == 1 and game.score == 0 and game.round_phase == "pick", "scooping a copy bursts it, scores nothing and the round goes on")
	_check(not game.can_pick(), "the burst gums the traveller up for a moment")
	_advance(game, Game.GOO_SECONDS + 0.05)
	game.cursor = game.real_slot()
	_tap(game, KEY_SPACE)
	_check(game.moulds == 1 and game.round_phase == "scoop", "then the real one goes into a mould")


func _acts_grow_and_gravity_flips() -> void:
	var game := _round(9)
	_to_pick(game)
	_check(game.slots() == 3 and game.swaps.size() == 3, "act one: three jellies, three swaps")
	game.moulds = 4
	game._start_round()
	_check(game.slots() == 5 and game.swaps.size() == 8 and game.act() == 3, "act three: five jellies, eight swaps")
	var saw_upright := false
	var saw_flipped := false
	while game.round_phase != "pick":
		game.step(STEP)
		if game.round_phase == "shuffle":
			saw_upright = saw_upright or not game.flipped()
			saw_flipped = saw_flipped or game.flipped()
	_check(saw_upright and saw_flipped and game.flipped(), "act three flips gravity partway through the shuffle")


func _five_moulds_earn_no_medal() -> void:
	var game := _round(12)
	game.moulds = 5
	game.score = 1900
	_check(game.medal() == 0, "five moulds and 1900 points still earn no medal")
	game.moulds = 6
	_check(game.medal() == 3, "the sixth mould earns the medal by score")


func _rewards_leave_counts_alone() -> void:
	var progress: Node = ProgressScript.new()
	progress.name = "JellyProgressProbe"
	root.add_child(progress)
	progress.reset_progress()
	_check(not bool(progress.record_rift_result("candy", true, 800, 2).saved), "a closed candy rift keeps nothing")
	for index in range(1, 13):
		progress.photos["photo-candy-devil-%d" % index] = {"devil": true}
	var normal: int = progress.normal_count()
	var first: Dictionary = progress.record_rift_result("candy", true, 800, 2)
	var jellied: Dictionary = progress.record_rift_result("candy", false, 0, 0)
	_check(first.saved and first.first and jellied.kept, "the cake photo and the jellied photo are kept")
	_check(progress.normal_count() == normal and progress.devil_count("candy") == 12, "no sticker count changes")
	progress.queue_free()


func _view_runs_headless_with_reduced_motion() -> void:
	var game := _round(14)
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


func _to_pick(game: Game) -> void:
	var guard := 0
	while (game.stage != "play" or game.round_phase != "pick") and guard < 4000:
		game.step(STEP)
		guard += 1


## Watch the wobble: the jelly whose animation runs behind the others is real.
func _bot(game: Game) -> void:
	if game.stage != "play" or game.round_phase != "pick" or game.phase != "show":
		return
	var layout: Array = game.layout()
	var latest := INF
	var target := game.cursor
	for jelly: Dictionary in layout:
		if bool(jelly.popped):
			continue
		if float(jelly.t) < latest - 0.001:
			latest = float(jelly.t)
			target = roundi(float(jelly.x))
	if target != game.cursor:
		_tap(game, KEY_LEFT if target < game.cursor else KEY_RIGHT)
	elif game.can_pick():
		_tap(game, KEY_SPACE)


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
