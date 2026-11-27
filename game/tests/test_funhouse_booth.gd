extends SceneTree
## 哈哈鏡大頭貼 rules: stopping order, scoring, speed-up, decoys, variants and full simulated rounds.

const Booth = preload("res://game/minigames/arcade/funhouse_booth_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Faces = preload("res://game/minigames/arcade/funhouse_faces.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_declares_a_readable_part_set()
	_stops_in_order_and_scores()
	_speeds_up_and_adds_decoys()
	_variants_change_the_round()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: funhouse booth stopping order, scoring, speed-up, decoys, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _declares_a_readable_part_set() -> void:
	_check(Faces.PARTS.size() == Booth.REELS and Faces.OPTIONS >= 6, "three bands with at least six parts each")
	var sheet: Image = Faces._paint_atlas()
	for reel in Booth.REELS:
		var names: Dictionary = {}
		var pictures: Dictionary = {}
		for id in Faces.OPTIONS * 2:
			names[Faces.part_name(reel, id)] = true
			var tile := sheet.get_region(Rect2i(Faces.region(reel, id)))
			_check(not tile.is_invisible(), "part %d of band %d is painted" % [id, reel])
			pictures[tile.get_data()] = true
		_check(names.size() == Faces.OPTIONS * 2 and pictures.size() == Faces.OPTIONS * 2, "every part and decoy of band %d looks different" % reel)
		for id in Faces.OPTIONS:
			_check(Faces.PARTS[reel][id].color != Faces.PARTS[reel][id].decoy, "a decoy is the same shape in another colour")
	_check(not sheet.get_region(Rect2i(Faces.head_region())).is_invisible(), "the head is painted")


func _stops_in_order_and_scores() -> void:
	var game := _round(_seed_for("classic"))
	_check(game.stage == "ready" and game.stopped == 0, "a round opens on the countdown")
	for reel in Booth.REELS:
		_check(game.part_in_frame(reel) != game.target[reel], "bands start away from the wanted part")
	var before: Array = game.positions.duplicate()
	_tap(game)
	_advance(game, 1.0)
	_check(game.stopped == 0 and game.positions != before and game.score == 0, "bands spin through the countdown and a press stops nothing yet")
	_advance(game, Base.READY_SECONDS)
	_check(game.stage == "play", "play begins after the countdown")
	# A perfect face: each press stops the next band, top to bottom.
	var score := game.score
	for reel in Booth.REELS:
		_wait_for(game, reel, true)
		var others: Array = game.positions.duplicate()
		_tap(game)
		_check(game.stopped == reel + 1 and game.picked[reel] == game.target[reel]
			and game.score == score + Booth.PART_POINTS * (reel + 1) + (Booth.PERFECT_BONUS if reel == 2 else 0),
			"press %d stops band %d on the wanted part for points" % [reel + 1, reel])
		_check(is_equal_approx(game.positions[reel], roundf(game.positions[reel])), "a stopped band snaps onto one part")
		for later in range(reel + 1, Booth.REELS):
			_check(game.positions[later] == others[later], "a press only stops the next band in line")
	_check(game.printing > 0.0 and game.faces_done == 1 and game.perfect_faces == 1 and game.prints.back().matched == 3
		and game.prints.back().parts == game.target and game.snapshot().word == "完美！", "a perfect face prints with its bonus")
	var held: Array = game.positions.duplicate()
	_tap(game)
	_advance(game, 0.2)
	_check(game.positions == held and game.faces_done == 1, "bands rest and ignore presses while the sticker prints")
	_advance(game, Booth.PRINT_SECONDS)
	_check(game.printing <= 0.0 and game.stopped == 0 and game.picked == [-1, -1, -1], "the next face starts by itself")
	# Two right, one wrong: partial points, no bonus, no mistake.
	score = game.score
	_wait_for(game, 0, true)
	_tap(game)
	_wait_for(game, 1, true)
	_tap(game)
	_wait_for(game, 2, false)
	_tap(game)
	_check(game.score == score + Booth.PART_POINTS * 2 and game.mistakes == 0 and game.prints.back().matched == 2, "two matching parts score twice without a bonus")
	_advance(game, Booth.PRINT_SECONDS + 0.05)
	# All wrong: a wonky print that takes longer and counts as a mistake.
	score = game.score
	for reel in Booth.REELS:
		_wait_for(game, reel, false)
		_tap(game)
	_check(game.score == score and game.mistakes == 1 and game.prints.back().matched == 0 and game.snapshot().word == "怪臉出爐！"
		and not game.snapshot().word_good and is_equal_approx(game.printing, Booth.WONKY_PRINT_SECONDS) and Booth.WONKY_PRINT_SECONDS > Booth.PRINT_SECONDS,
		"a wrong face is printed as a slow wonky sticker")
	_check(game.prints.size() == 3 and game.prints[0].at < game.prints[2].at, "prints are kept in order for the sticker pile")
	var learner := _round(_seed_for("classic"))
	_advance(learner, Base.READY_SECONDS + 0.05)
	for reel in Booth.REELS:
		_wait_for(learner, reel, false)
		_tap(learner)
	_check(learner.mistakes == 0 and learner.prints.back().matched == 0 and learner.printing > 0.0, "the very first wrong face is a free lesson")
	for face in 8:
		_advance(learner, Booth.WONKY_PRINT_SECONDS + 0.05)
		for reel in Booth.REELS:
			_wait_for(learner, reel, false)
			_tap(learner)
	_check(learner.prints.size() == Booth.PRINT_HISTORY and learner.faces_done == 9 and learner.mistakes == 8, "only the latest prints are kept")


func _speeds_up_and_adds_decoys() -> void:
	var game := _round(_seed_for("classic"))
	_advance(game, Base.READY_SECONDS + 0.05)
	var early := game.speed(0)
	_check(is_equal_approx(early, lerpf(Booth.SLOW, Booth.FAST, game.heat())) and game.decoy_reels() == 0, "the round opens slow and without decoys")
	_check(game.speed(1) != game.speed(0) and game.speed(2) != game.speed(0), "bands drift at different rates")
	var decoy_counts: Dictionary = {}
	var last_speed := early
	while game.stage == "play":
		if game.printing <= 0.0 and game.stopped == 0:
			# A fresh face: check what the round dealt, then burn it quickly.
			var with_decoy := 0
			for reel in Booth.REELS:
				var band: Array = game.bands[reel]
				_check(band.has(game.target[reel]) and band.size() - Faces.OPTIONS in [0, 1], "a band holds every part once, plus at most one decoy")
				if band.size() == Faces.OPTIONS + 1:
					with_decoy += 1
					_check(band.has(game.target[reel] + Faces.OPTIONS), "a decoy is the off-colour twin of the wanted part")
			_check(with_decoy in [0, 1, Booth.REELS], "decoys come on one band or on all of them")
			decoy_counts[with_decoy] = decoy_counts.get(with_decoy, 0) + 1
			if decoy_counts.has(Booth.REELS):
				_check(with_decoy == Booth.REELS, "once every band hides a decoy it stays that way")
			_check(game.speed(0) >= last_speed, "bands never slow down during a round")
			last_speed = game.speed(0)
		if game.printing <= 0.0:
			_tap(game)
		_advance(game, 0.2)
	_check(decoy_counts.has(0) and decoy_counts.has(1) and decoy_counts.has(Booth.REELS), "no decoys, then one band, then every band as the round goes on")
	_check(game.speed(0) > early * 1.6 and is_equal_approx(game.heat(), 1.0), "bands end clearly faster than they began")
	var late := _round(_seed_for("classic"))
	_advance(late, Base.READY_SECONDS + 40.0)
	for reel in Booth.REELS:
		_tap(late)
	_advance(late, Booth.WONKY_PRINT_SECONDS + 0.05)
	_check(late.stopped == 0 and late.printing <= 0.0 and late.decoy_reels() == Booth.REELS, "late faces hide a decoy on every band")
	var score := late.score
	for tick in 4000:
		if late.part_in_frame(0) == late.target[0] + Faces.OPTIONS:
			break
		late.step(STEP)
	_tap(late)
	_check(late.picked[0] == late.target[0] + Faces.OPTIONS and late.score == score, "stopping on the decoy scores nothing")
	var helped := Booth.new()
	helped.round_seed = _seed_for("classic")
	helped.reset(true, "noon")
	var plain := _round(_seed_for("classic"))
	_check(helped.speed(0) < plain.speed(0) / 1.4, "assist slows the bands")


func _variants_change_the_round() -> void:
	var classic := _round(_seed_for("classic"))
	var reverse := _round(_seed_for("reverse"))
	var peek := _round(_seed_for("peek"))
	_check(classic.directions == [1, 1, 1] and reverse.directions == [1, -1, 1] and peek.directions == [1, 1, 1], "only the reverse variant turns the middle band back")
	_advance(reverse, Base.READY_SECONDS + 0.05)
	var before: Array = reverse.positions.duplicate()
	_advance(reverse, 0.5)
	_check(reverse.positions[0] > before[0] and reverse.positions[1] < before[1] and reverse.positions[2] > before[2], "the middle band really runs the other way")
	for reel in Booth.REELS:
		_wait_for(reverse, reel, true)
		_tap(reverse)
	_check(reverse.prints.back().matched == 3, "a reversed band still reaches the wanted part")
	_advance(peek, Base.READY_SECONDS + 0.05)
	_check(not peek.target_hidden() and not peek.snapshot().target_hidden, "the wanted card starts face up")
	_advance(peek, 1.4)
	_check(not peek.target_hidden(), "the card stays up long enough to read")
	_advance(peek, 0.4)
	_check(peek.target_hidden() and peek.snapshot().target_hidden, "then the peek variant hides the wanted face")
	_advance(classic, Base.READY_SECONDS + 5.0)
	_check(not classic.target_hidden(), "other variants never hide the card")
	var helped := Booth.new()
	helped.round_seed = _seed_for("peek")
	helped.reset(true, "noon")
	_advance(helped, Base.READY_SECONDS + 2.0)
	_check(not helped.target_hidden(), "assist shows the peek card longer")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	# Gold: wait for the wanted part on every band.
	var gold := _play(session, false, func(_reel: int) -> bool: return true)
	var lines: Array = gold.score_summary.thresholds
	_check(gold.success and gold.devil and gold.ordinary_eligible and not gold.assisted and gold.score >= lines[2]
		and gold.score_summary.medal == 3 and gold.score_summary.rows.size() == 1 and gold.score_summary.rows[0].amount == gold.score,
		"a careful round earns gold, the ordinary sticker and the devil sticker (score %d)" % gold.score)
	# Bronze: only the hair is aimed; eyes and mouth are stopped wherever they are.
	var bronze := _play(session, false, func(reel: int) -> bool: return reel == 0)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "a sloppy round still earns bronze and the ordinary sticker (score %d)" % bronze.score)
	# Mashing without looking stays under the bronze line.
	var mash := _play(session, false, func(_reel: int) -> bool: return false)
	_check(not mash.success and not mash.devil and not mash.ordinary_eligible and mash.score < lines[0] and mash.score_summary.medal == 0,
		"blind mashing earns no medal and no sticker (score %d)" % mash.score)
	var helped := _play(session, true, func(_reel: int) -> bool: return true)
	_check(helped.success and helped.ordinary_eligible and helped.assisted and not helped.devil and helped.score_summary.medal == 3,
		"an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("funhouse scores: gold %d, bronze %d, mash %d, assisted %d" % [gold.score, bronze.score, mash.score, helped.score])
	session.free()


## Play one whole round through Session input; `aims` says whether a band is stopped on purpose.
func _play(session: Session, assisted: bool, aims: Callable) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-049", assisted)
	var game: Booth = session.active_driver
	game.round_seed = 11
	session.reset_round()
	var blind_wait := 0.0
	for tick in 60 * 70:
		if session.ended:
			break
		if game.stage == "play" and game.printing <= 0.0 and game.stopped < Booth.REELS:
			blind_wait += STEP
			var ready: bool = _centred(game, game.stopped, true) if aims.call(game.stopped) else blind_wait >= 0.18
			if ready:
				blind_wait = 0.0
				_session_tap(session)
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0 and game.round_seconds <= 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


func _session_tap(session: Session) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	session._unhandled_input(key)
	key.pressed = false
	session._unhandled_input(key)


func _round(round_seed: int) -> Booth:
	var game := Booth.new()
	game.round_seed = round_seed
	game.reset(false, "noon")
	return game


## First seed whose round uses the named variant.
func _seed_for(variant_id: String) -> int:
	for round_seed in 200:
		var game := Booth.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		if game.variant.id == variant_id:
			return round_seed
	failures.append("no seed produced variant " + variant_id)
	return 0


func _centred(game: Booth, reel: int, wanted: bool) -> bool:
	var offset := absf(game.positions[reel] - roundf(game.positions[reel]))
	return offset < 0.2 and (game.part_in_frame(reel) == game.target[reel]) == wanted


## Step until the band shows (or does not show) its wanted part near the centre.
func _wait_for(game: Booth, reel: int, wanted: bool) -> void:
	for tick in 4000:
		if _centred(game, reel, wanted):
			return
		game.step(STEP)
	failures.append("band %d never reached a %s part" % [reel, "wanted" if wanted else "wrong"])


func _advance(game: Base, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game.step(minf(left, STEP))
		left -= STEP


func _tap(game: Base) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	game.handle_input(key, Vector2.ZERO)
	key.pressed = false
	game.handle_input(key, Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
