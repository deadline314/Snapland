extends SceneTree
## Shared arcade flow: countdown, clock, medals, assist, seeded variants, input and summary.

const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Medal = preload("res://game/ui/arcade_medal.gd")

class Probe extends "res://game/minigames/arcade/arcade_driver.gd":
	var log: Array[String] = []
	var ticked := 0.0
	var warmed := 0.0
	var rounds_over := 0

	func _init() -> void:
		verb = "按一下"
		hint = [["空白鍵", "按"]]
		round_seconds = 10.0
		thresholds = [10, 20, 30]
		verdicts = ["零", "銅", "銀", "金"]
		variants = [{"id": "a", "label": "甲"}, {"id": "b", "label": "乙"}, {"id": "c", "label": "丙"}]

	func _begin_round(chosen: Dictionary) -> void:
		log.append("begin:" + str(chosen.id))

	func _warm_up(delta: float) -> void:
		warmed += delta

	func _tick(delta: float) -> void:
		ticked += delta

	func _press(button: StringName) -> void:
		log.append("press:" + str(button))

	func _release(button: StringName) -> void:
		log.append("release:" + str(button))

	func _round_over() -> void:
		rounds_over += 1

	func _snapshot(into: Dictionary) -> void:
		into.probe = true

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_and_clock()
	_medals_and_assist()
	_variants_are_seeded()
	_input_routes_to_hooks()
	_session_finds_arcade_games()
	_untouched_rounds_earn_nothing()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: arcade countdown, clock, medal lines, assist, seeded variants, input and one-row summary")
	quit(0 if failures.is_empty() else 1)


func _countdown_and_clock() -> void:
	var game := Probe.new()
	game.round_seed = 3
	game.reset(false, "noon")
	var state: Dictionary = game.snapshot()
	_check(state.stage == "ready" and state.time_text == "預備" and not state.ended and state.probe
		and state.thresholds == [10, 20, 30] and state.progress_text == "銅 10　銀 20　金 30" and state.verb == "按一下",
		"a round opens on the countdown with its prompt and medal lines already visible")
	_tap(game, KEY_SPACE)
	_check(not game.log.has("press:action"), "the countdown does not deliver input to the game")
	_advance(game, Base.READY_SECONDS - 0.05)
	_check(game.stage == "ready" and game.ticked == 0.0 and game.warmed > 2.0, "the scene warms up but play has not started")
	_advance(game, 0.1)
	_check(game.stage == "play" and Base.READY_SECONDS < 5.0, "play starts within five seconds of entering")
	_tap(game, KEY_SPACE)
	_check(game.log.has("press:action") and game.log.has("release:action"), "play delivers presses and releases")
	_advance(game, 9.0)
	_check(game.stage == "play" and is_equal_approx(game.snapshot().remaining, 10.0 - game.play_time) and game.snapshot().time_text.ends_with("秒"),
		"the round clock counts down during play")
	_advance(game, 2.0)
	_check(game.stage == "closing" and game.rounds_over == 1 and is_equal_approx(game.play_time, 10.0) and is_equal_approx(game.ticked, 10.0)
		and not game.snapshot().ended, "time up settles the round once and holds a closing beat")
	game.log.clear()
	_tap(game, KEY_SPACE)
	_check(game.log.is_empty(), "the closing beat ignores input")
	_advance(game, Base.CLOSING_SECONDS + 0.1)
	_check(game.stage == "done" and game.snapshot().ended and game.rounds_over == 1, "the round ends after the closing beat")
	_check(is_equal_approx(game.snapshot().elapsed, Base.READY_SECONDS + 10.0) and game.snapshot().clock > game.snapshot().elapsed + 1.0,
		"the reported play time stops at time up while the picture clock runs on")
	var frozen: float = game.clock
	game.step(1.0)
	_check(game.clock == frozen, "a finished round no longer advances")
	var long := Probe.new()
	long.round_seconds = 240.0
	long.reset(false, "noon")
	_check(long.round_seconds == Base.MAX_ROUND_SECONDS and Base.MAX_ROUND_SECONDS <= 60.0, "no arcade round runs past sixty seconds")
	long.step(NAN)
	long.step(-1.0)
	_check(long.clock == 0.0, "invalid frame times are ignored")


func _medals_and_assist() -> void:
	var game := Probe.new()
	game.reset(false, "noon")
	_advance(game, Base.READY_SECONDS + 0.1)
	var expected := [[0, 0], [9, 0], [10, 1], [19, 1], [20, 2], [29, 2], [30, 3], [999, 3]]
	for pair: Array in expected:
		game.score = pair[0]
		game.step(0.01)
		var state: Dictionary = game.snapshot()
		_check(game.medal() == pair[1] and state.medal == pair[1] and state.success == (pair[1] >= 1)
			and state.ordinary_eligible == (pair[1] >= 1) and state.devil == (pair[1] == 3),
			"score %d maps to medal %d and its stickers" % pair)
		var summary: Dictionary = game.score_summary(false)
		_check(summary.rows.size() == 1 and summary.rows[0].amount == pair[0] and summary.total == pair[0] and summary.arcade
			and summary.medal == pair[1] and summary.verdict == game.verdicts[pair[1]] and summary.thresholds == [10, 20, 30],
			"the summary is one row, one medal and one verdict at score %d" % pair[0])
	game.add_score(-5000)
	_check(game.score == 0, "the score never drops below zero")
	game.add_mistake("哎呀")
	game.step(0.01)
	_check(game.mistakes == 1 and game.snapshot().mistakes == 1 and game.snapshot().word == "哎呀" and not game.snapshot().word_good,
		"mistakes and feedback words reach the state")
	_check(game.score_summary(true).qualification_text.contains("練習"), "practice is called out in the summary")
	var assisted := Probe.new()
	assisted.reset(true, "noon")
	_advance(assisted, Base.READY_SECONDS + 0.1)
	assisted.score = 500
	assisted.step(0.01)
	var helped: Dictionary = assisted.snapshot()
	_check(helped.medal == 3 and helped.success and helped.ordinary_eligible and not helped.devil and helped.assisted,
		"assisted gold keeps the ordinary sticker but never the devil sticker")
	_check(assisted.score_summary(false).qualification_text.contains("輔助"), "assisted gold explains the missing devil sticker")
	_check(assisted.window(1.0) > game.window(1.0) and game.window(1.0) == 1.0 and assisted.pace(3.0) < game.pace(3.0),
		"assist widens windows and slows the pace")
	_check(Medal.NAMES.size() == 4 and Medal.FACES.size() == 4, "every medal has a name and a colour")


func _variants_are_seeded() -> void:
	var seen: Dictionary = {}
	for round_seed in 40:
		var first := Probe.new()
		first.round_seed = round_seed
		first.reset(false, "noon")
		var second := Probe.new()
		second.round_seed = round_seed
		second.reset(false, "noon")
		_check(first.variant == second.variant and first.rng.randi() == second.rng.randi(), "seed %d repeats its variant and its dice" % round_seed)
		_check(first.log == ["begin:" + str(first.variant.id)] and first.snapshot().variant_id == first.variant.id
			and first.snapshot().variant_label == first.variant.label, "the round begins with the chosen variant")
		seen[first.variant.id] = true
	_check(seen.size() == 3, "every declared variant turns up across seeds")
	var free := Probe.new()
	free.reset(false, "noon")
	_check(free.variants.has(free.variant), "an unpinned round still picks a declared variant")


func _input_routes_to_hooks() -> void:
	var game := Probe.new()
	game.reset(false, "noon")
	_advance(game, Base.READY_SECONDS + 0.1)
	var keys := {KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right",
		KEY_SPACE: "action", KEY_ENTER: "action", KEY_E: "action", KEY_X: "second"}
	for code: int in keys:
		game.log.clear()
		_check(_tap(game, code) and game.log == ["press:" + keys[code], "release:" + keys[code]], "key %d is %s" % [code, keys[code]])
	game.log.clear()
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_SPACE
	echo.pressed = true
	game.handle_input(echo, Vector2.ZERO)
	echo.echo = true
	game.handle_input(echo, Vector2.ZERO)
	game.handle_input(echo, Vector2.ZERO)
	_check(game.log == ["press:action"], "key repeat does not press again")
	game.clear_input()
	_check(game.log == ["press:action", "release:action"], "clearing input releases what is held")
	var other := InputEventKey.new()
	other.physical_keycode = KEY_F9
	other.pressed = true
	_check(not game.handle_input(other, Vector2.ZERO), "unrelated keys are left for the rest of the game")
	var pad := {JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right", JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down",
		JOY_BUTTON_A: "action", JOY_BUTTON_X: "second"}
	for button: int in pad:
		game.log.clear()
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = true
		var handled: bool = game.handle_input(event, Vector2.ZERO)
		event.pressed = false
		game.handle_input(event, Vector2.ZERO)
		_check(handled and game.log == ["press:" + pad[button], "release:" + pad[button]], "pad button %d is %s" % [button, pad[button]])
	game.log.clear()
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	for value in [0.2, 0.9, 0.95, 0.1, -0.8, 0.0]:
		stick.axis_value = value
		game.handle_input(stick, Vector2.ZERO)
	_check(game.log == ["press:right", "release:right", "press:left", "release:left"], "the left stick presses each direction once per push")
	game.log.clear()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game.handle_input(click, Vector2(640, 360))
	click.pressed = false
	game.handle_input(click, Vector2(640, 360))
	_check(game.log == ["press:action", "release:action"], "a click or tap is the main button")
	_check(game.create_view() == null, "headless rounds allocate no picture")


func _session_finds_arcade_games() -> void:
	var arcade: Array = Catalog.all_definitions().filter(func(row: Dictionary) -> bool: return bool(row.get("arcade", false)))
	_check(not arcade.is_empty(), "at least one arcade game is delivered")
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary) -> void: results.append(result))
	for definition: Dictionary in arcade:
		session.start(definition.id)
		var driver: RefCounted = session.active_driver
		_check(driver is Base and not Session.DRIVERS.has(definition.mode), definition.id + " is found by its file name without a driver table row")
		if not driver is Base:
			continue
		_check(driver.variants.size() >= 2 and driver.thresholds.size() == 3 and driver.thresholds[0] > 0
			and driver.thresholds[0] < driver.thresholds[1] and driver.thresholds[1] < driver.thresholds[2]
			and driver.round_seconds <= 60.0 and not driver.verb.is_empty() and not driver.hint.is_empty()
			and driver.verdicts.size() == 4 and not driver.verdicts.has(""), definition.id + " declares its prompt, lines, verdicts and variants")
		_check(session._progress_text().contains("金"), definition.id + " shows its medal lines in the HUD")
		for tick in 2000:
			if session.ended:
				break
			session._process(0.05)
		_check(results.size() > 0 and results.back().game_id == definition.id and not results.back().success and not results.back().devil
			and not results.back().ordinary_eligible and results.back().score_summary.rows.size() == 1 and results.back().score_summary.medal == 0,
			definition.id + " left untouched ends without a medal or a sticker")
	session.free()


func _advance(game: Base, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game.step(minf(left, 1.0 / 30.0))
		left -= 1.0 / 30.0


func _tap(game: Base, code: int) -> bool:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	var handled: bool = game.handle_input(key, Vector2.ZERO)
	key.pressed = false
	game.handle_input(key, Vector2.ZERO)
	return handled


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## No input means no points: every delivered arcade game, left completely alone
## for a whole round, ends at zero with no sticker, over many seeds and with
## uneven frame steps (a busy machine delivers frames unevenly). Rules that pay
## on their own when random events happen to land well fail here.
const UNTOUCHED_SEEDS := 50


func _untouched_rounds_earn_nothing() -> void:
	for definition: Dictionary in Catalog.all_definitions():
		if not bool(definition.get("arcade", false)):
			continue
		var script := load("res://game/minigames/arcade/%s_driver.gd" % definition.mode) as Script
		var frames := RandomNumberGenerator.new()
		frames.seed = 7
		var scored: Array[String] = []
		for round_seed in UNTOUCHED_SEEDS:
			var game: Base = script.new()
			game.round_seed = round_seed
			game.reset(false, "noon")
			for frame in 5000:
				if game.snapshot().ended:
					break
				game.step(frames.randf_range(0.008, 0.11))
			var state: Dictionary = game.snapshot()
			if game.score != 0 or game.medal() != 0 or state.success or state.devil or state.ordinary_eligible or not state.ended:
				scored.append("seed %d: %d" % [round_seed, game.score])
		_check(scored.is_empty(), "%s left untouched for %d seeded rounds always ends at zero (%s)" % [definition.id, UNTOUCHED_SEEDS, ", ".join(scored)])
