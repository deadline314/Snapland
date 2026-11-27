extends SceneTree
## 螢火蟲對暗號 rules: showing the code, answering it, growing codes, double
## notes, the moth, the blackout, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/firefly_code_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0
const ARROWS: Array[int] = [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_shows_and_answers()
	_showing_the_code()
	_answering_and_growing()
	_wrong_answers_black_out()
	_doubles_and_the_moth()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: firefly code showing, answering, growing codes, doubles, moth, blackout, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_shows_and_answers() -> void:
	var game := _round("starry", false)
	_check(game.stage == "ready" and game.code.size() == Game.FIRST_LENGTH and game.thresholds == [120, 280, 440], "a round opens on a two-note code with its medal lines declared")
	var notes: Array[int] = []
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_DOWN)
		game.step(STEP)
		notes.append_array(game.consume_notes())
	_check(game.phase == "pause" and game.score == 0 and game.wrongs == 0, "the countdown shows a code and answers it by itself; presses do nothing yet")
	_check(notes.slice(0, 2) == [Game.TONES[int(game.code[0].dir)], Game.TONES[int(game.code[1].dir)]], "each direction sounds its own tone")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.phase == "show" and game.code.size() == Game.FIRST_LENGTH and game.answered == 0, "play starts by showing a fresh code")


func _showing_the_code() -> void:
	var game := _playing("starry")
	_tap(game, ARROWS[int(game.code[0].dir)])
	_check(game.phase == "show" and game.answered == 0, "pressing while the code is shown does nothing")
	game.consume_notes()
	_advance(game, game.note_time(game.code.size()) + 0.02)
	_check(game.phase == "answer", "after the last note it is the player's turn")
	_check(Game.TONES.size() == 4 and Game.TONES.duplicate().all(func(tone: int) -> bool: return Game.TONES.count(tone) == 1), "four different tones")
	_advance(game, game.answer_wait() + 0.05)
	_check(game.phase == "dark" and game.wrongs == 1 and game.mistakes == 0, "waiting too long counts as a wrong answer; the first one is free")
	var helped := _round("starry", true)
	_advance(helped, Base.READY_SECONDS + 0.02)
	_check(helped.answer_wait() > Game.ANSWER_WAIT * 1.4 and helped.beat > Game.BEAT_FIRST * 1.4, "assist shows the code slower and waits longer")


func _answering_and_growing() -> void:
	var game := _playing("starry")
	var first: Array = game.code.duplicate(true)
	_answer_all(game)
	_check(game.phase == "pause" and game.score == (Game.NOTE_POINTS + Game.CODE_POINTS) * first.size() and game.codes_solved == 1,
		"answering the code note by note scores ten each, five more per note for the whole code")
	_advance(game, Game.PAUSE_SECONDS + 0.02)
	_check(game.phase == "show" and game.code.size() == first.size() + 1 and game.code.slice(0, first.size()) == first,
		"the next code is the same one with one more note")
	var early_beat := game.beat
	_advance(game, game.round_seconds * 0.8)
	game._new_code(4)
	_check(game.beat < early_beat * 0.7, "later codes are shown faster (%.2f then %.2f s a note)" % [early_beat, game.beat])


func _wrong_answers_black_out() -> void:
	var game := _playing("starry")
	_advance(game, game.note_time(game.code.size()) + 0.02)
	var wrong := (int(game.code[0].dir) + 1) % 4
	_tap(game, ARROWS[wrong])
	_check(game.phase == "dark" and game.wrongs == 1 and game.mistakes == 0 and not game.snapshot().word_good, "a wrong arrow blacks out the pond")
	_tap(game, ARROWS[0])
	_check(game.phase == "dark", "no answers in the dark")
	_advance(game, Game.DARK_SECONDS + 0.02)
	_check(game.phase == "show" and game.code.size() == Game.FIRST_LENGTH, "then a fresh code is shown, never shorter than two")
	_advance(game, game.note_time(game.code.size()) + 0.02)
	_tap(game, ARROWS[(int(game.code[0].dir) + 2) % 4])
	_check(game.wrongs == 2 and game.mistakes == 1, "later wrong answers are mistakes")


func _doubles_and_the_moth() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["starry", "double", "moth"], "three variants are declared")
	var starry := _playing("starry")
	_check(starry.code.all(func(note: Dictionary) -> bool: return not note.double) and starry.decoy.is_empty(), "early codes have no double notes and no moth")
	starry.play_time = starry.round_seconds * 0.8
	var doubles := 0
	var moths := 0
	for attempt in 30:
		starry._new_code(5)
		doubles += starry.code.filter(func(note: Dictionary) -> bool: return note.double).size()
		moths += 0 if starry.decoy.is_empty() else 1
	_check(doubles > 0 and moths == 30, "late codes add double notes and a moth")
	var twice := _playing("double")
	var guard := 0
	while not twice.code.any(func(note: Dictionary) -> bool: return note.double) and guard < 50:
		guard += 1
		twice._new_code(3)
	var index := -1
	for at in twice.code.size():
		if twice.code[at].double:
			index = at
			break
	twice.code[0] = twice.code[index]
	_advance(twice, twice.note_time(twice.code.size()) + 0.02)
	var arrow := ARROWS[int(twice.code[0].dir)]
	_tap(twice, arrow)
	_check(twice.answered == 0 and twice.half_pressed and twice.score == 0, "a double note needs a second press")
	_tap(twice, arrow)
	_check(twice.answered == 1 and twice.score == Game.NOTE_POINTS, "the second press completes it")
	var moth := _playing("moth")
	_check(not moth.decoy.is_empty() and float(moth.decoy.at) >= Game.LEAD_IN, "the moth variant sends a moth from the start")
	moth.consume_notes()
	_advance(moth, moth.note_time(moth.code.size()) + 0.02)
	var heard := moth.consume_notes()
	_check(heard.count(50) == 1 and heard.size() == moth.code.size() + 1 and moth.phase == "answer", "the moth only buzzes; it is never part of the code")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["starry", "double", "moth"]:
		var gold := _play(session, variant_id, false, 0.25, 0)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1 and gold.mistakes == 0, "a sharp memory earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	var bronze := _play(session, "starry", false, 0.8, 3)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a slow player who slips every third code still earns bronze (score %d)" % bronze.score)
	var idle := _play(session, "starry", false, -1.0, 0)
	_check(not idle.success and idle.score == 0, "never answering earns nothing")
	var helped := _play(session, "starry", true, 0.25, 0)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("firefly code scores: gold %s, bronze %d, assisted %d" % [gold_scores, bronze.score, helped.score])
	session.free()


## Play a whole round through Session input: answer each press `reaction`
## seconds after the last (negative: never); with `slip` N, press a wrong arrow
## on the first note of every Nth code.
func _play(session: Session, variant_id: String, assisted: bool, reaction: float, slip: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-080", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	while not session.ended and game.stage == "ready":
		session._process(STEP)
	var codes := 0
	var last_phase := ""
	while not session.ended and game.stage == "play":
		if game.phase == "show" and last_phase != "show":
			codes += 1
		last_phase = game.phase
		if reaction >= 0.0 and game.phase == "answer" and game.clock - maxf(game.phase_at, game.press_at) >= reaction:
			var dir := int(game.code[game.answered].dir)
			if slip > 0 and codes % slip == 0 and game.answered == 0 and not game.half_pressed:
				dir = (dir + 1) % 4
			_session_key(session, ARROWS[dir], true)
			session._process(STEP)
			_session_key(session, ARROWS[dir], false)
		session._process(STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


func _answer_all(game: Game) -> void:
	_advance(game, game.note_time(game.code.size()) + 0.02)
	for note: Dictionary in game.code.duplicate():
		_tap(game, ARROWS[int(note.dir)])
		if note.double:
			_tap(game, ARROWS[int(note.dir)])


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


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.02)
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
