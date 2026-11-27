extends SceneTree
## Instant map games: the shared flow, every game's rules played by simulated
## visitors, the placement table, the toys, and the saved records.

const Registry = preload("res://game/world/field/field_registry.gd")
const FieldGames = preload("res://game/world/field/field_games.gd")
const CoastalCircuit = preload("res://game/world/coastal_circuit.gd")
const STEP := 1.0 / 60.0
const RUN_SPEED := 1.5
const STROLL_SPEED := 0.8
const ROLLBACK_MARKER := "PASS: instant game record rollback"

var failures: Array[String] = []
var main: Node
var world: Node3D
var field: Node3D
var progress: Node
var save_path := ""
var notes: Array[int] = []
var sounds: Array[String] = []
var started: Array[Dictionary] = []
var finished: Array[Dictionary] = []
var aborted: Array[String] = []
var ticks: Array[Vector3i] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	save_path = OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save_path.is_absolute_path():
		quit(2)
		return
	call_deferred("_run_rollback_child" if OS.get_cmdline_user_args().has("--field-rollback-child") else "_run")


func frames(count: int) -> void:
	for index in count:
		await physics_frame


func _run() -> void:
	progress = root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.save_progress()
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	world = main.world
	field = world.field_games
	check(is_instance_valid(field), "the Welcome island carries the field layer")
	if not is_instance_valid(field):
		_finish()
		return
	field.note_requested.connect(func(note: int) -> void: notes.append(note))
	field.feedback_requested.connect(func(kind: String) -> void: sounds.append(kind))
	field.round_started.connect(func(info: Dictionary) -> void: started.append(info))
	field.round_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	field.round_aborted.connect(func(id: String) -> void: aborted.append(id))
	field.round_progress.connect(func(seconds_left: int, score: int, medal: int) -> void: ticks.append(Vector3i(seconds_left, score, medal)))
	_test_registry()
	await _test_prompt_and_start()
	# From here the test steps the layer itself, so a round is fully deterministic.
	field.set_physics_process(false)
	_test_leaving()
	_test_clock_medals_and_coins()
	_test_pause_and_reduced_motion()
	_test_crab_stomp()
	_test_hat_chase()
	_test_jump_rope()
	_test_flag_run()
	_test_bird_shutter()
	_test_every_game_with_reduced_motion()
	_test_toys()
	_test_stable_nodes()
	_test_saved_records()
	_test_rollback_process()
	main.world.set_process(false)
	main.world.set_physics_process(false)
	main.audio.shutdown()
	await create_timer(0.15).timeout
	main.queue_free()
	await frames(5)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS: instant map games flow, five games, toys, placement and saved records")
	quit(0 if failures.is_empty() else 1)


# --- helpers ---

func row(id: String) -> Dictionary:
	return field.record_for("field:" + id).row


func game(id: String) -> Node3D:
	return field.record_for("field:" + id).game


func place(at: Vector3) -> void:
	world.player.global_position = Vector3(at.x, world.ground_surface_y(at) + 0.3, at.z)


func feet() -> Vector3:
	return world.player.global_position


func arena(id: String) -> Vector3:
	var entry := row(id)
	return entry.get("arena", entry.at)


## Walk the player toward a point at a given speed for one step.
func walk(to: Vector3, speed: float) -> void:
	var here := feet()
	var offset := Vector2(to.x - here.x, to.z - here.z).limit_length(speed * STEP)
	place(here + Vector3(offset.x, 0, offset.y))


func advance(seconds: float) -> void:
	for index in range(roundi(seconds / STEP)):
		field.advance(STEP)


## Stand at the stand, press interact through the normal route, wait out the countdown.
func begin(id: String) -> void:
	place(arena(id))
	finished.clear()
	main._interact("field:" + id, "")
	advance(FieldGames.COUNTDOWN_SECONDS + STEP)


## Play a round with `play` called once per step until the result is in.
func play_round(id: String, play: Callable) -> Dictionary:
	begin(id)
	var limit := roundi((float(row(id).seconds) + 2.0) / STEP)
	for index in range(limit):
		if field.phase != FieldGames.Phase.PLAYING:
			break
		play.call()
		field.advance(STEP)
	check(finished.size() == 1, "%s finishes exactly once within its clock" % id)
	if not finished.is_empty():
		print("  %s: %d points, medal %d" % [id, int(finished[0].score), int(finished[0].medal)])
	advance(FieldGames.RESULT_SECONDS + STEP)
	check(field.phase == FieldGames.Phase.IDLE, "%s returns to idle after its result" % id)
	return finished[0] if not finished.is_empty() else {"score": -1, "medal": -1}


func other_points() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for point: Dictionary in world.points:
		var id := String(point.id)
		if not id.begins_with("field:") and not id.begins_with("toy:"):
			spots.append(point.position)
	return spots


# --- placement table ---

func _test_registry() -> void:
	var games: Array = Registry.games("welcome")
	var toys: Array = Registry.toys("welcome")
	check(games.size() >= 5 and field.records.size() == games.size(), "at least five instant games are registered and built")
	check(toys.size() >= 6 and field.toys.items.size() == toys.size(), "at least six unscored toys are registered and built")
	var kinds := {}
	for entry: Dictionary in games:
		kinds[String(entry.type)] = true
		check(String(entry.prompt).length() <= 8 and not String(entry.prompt).contains("\n"), "%s has a one-line prompt" % entry.id)
		var point: Dictionary = world._point_by_id(Registry.point_id(entry))
		check(not point.is_empty() and String(point.label) == String(entry.prompt), "%s is reachable as an interaction point" % entry.id)
		check(not String(entry.id).begins_with("game-"), "%s stays outside the 128 attraction numbers" % entry.id)
	check(kinds.size() >= 4, "the games cover at least four kinds of play")
	# Props stand wholly on the lawn, never straddling the beach.
	for entry: Dictionary in games + toys:
		for spot in Registry.footprint(entry):
			check(CoastalCircuit.on_lawn(Vector2(spot.x, spot.z), 0.5), "%s keeps %s on the lawn" % [entry.id, spot])
	var pit: float = game("crab-stomp").PIT_RADIUS + 0.2
	for step in range(8):
		var rim := arena("crab-stomp") + Vector3(cos(step * TAU / 8.0), 0, sin(step * TAU / 8.0)) * pit
		check(CoastalCircuit.on_lawn(Vector2(rim.x, rim.z)), "the sand pit lies wholly on the lawn at %s" % rim)
	var found := Registry.problems("welcome", world.is_walkable, other_points())
	check(found.is_empty(), "placement table is sound: %s" % str(found))
	# The checker itself must notice each kind of bad row.
	var good: Dictionary = games[0]
	var twin := good.duplicate(true)
	check(_has_problem([good, twin], [], "registered twice"), "duplicate ids are rejected")
	var close: Dictionary = games[1].duplicate(true)
	close.at = (good.at as Vector3) + Vector3(9, 0, 0)
	close.arena = close.at
	check(_has_problem([good, close], [], "needs 14 m"), "games nearer than 14 m are rejected")
	var wet := good.duplicate(true)
	wet.at = Vector3(60, 0, 0)
	check(_has_problem([wet], [], "off walkable land"), "a stand in the sea is rejected")
	var stray := good.duplicate(true)
	stray.layout = [Vector2(200, 0)]
	check(_has_problem([stray], [], "off walkable land"), "a layout spot in the sea is rejected")
	var crowded: Array[Vector3] = [good.at]
	check(not Registry.problems_in([good], [], world.is_walkable, crowded).is_empty(), "a stand on top of another interaction is rejected")
	var flat := good.duplicate(true)
	flat.medals = [5, 5, 9]
	check(_has_problem([flat], [], "rising medal"), "medal scores must rise")
	var slow := good.duplicate(true)
	slow.seconds = 55.0
	check(_has_problem([slow], [], "15 to 40"), "rounds outside 15 to 40 seconds are rejected")
	check(not world.is_walkable(Vector3(0, 0, 40)) and not world.is_walkable(Vector3(10, 0, 22)) and world.is_walkable(Vector3(0, 0, 22)) and world.is_walkable(Vector3(0, 0, -6)),
		"the walkable query knows the sea, the water beside the dock, the dock and the plaza")


func _has_problem(games: Array, toys: Array, text: String) -> bool:
	var none: Array[Vector3] = []
	for problem in Registry.problems_in(games, toys, world.is_walkable, none):
		if problem.contains(text):
			return true
	return false


# --- shared flow ---

func _test_prompt_and_start() -> void:
	var entry := row("crab-stomp")
	var camera: Camera3D = world.camera
	place(entry.at)
	await frames(3)
	check(String(world.nearest.get("id", "")) == "field:crab-stomp", "walking up to a stand makes it the nearby interaction")
	check(main._context_prompt() == "E   玩踩螃蟹", "the approach prompt is one line naming the game")
	var saved_before := FileAccess.get_file_as_bytes(save_path)
	world.interact()
	check(field.phase == FieldGames.Phase.COUNTDOWN and started.size() == 1, "interact starts the countdown at once")
	check(started[0].medals == entry.medals and float(started[0].seconds) == float(entry.seconds), "the HUD is told the medal targets before play")
	check(main.session == null and main.modal_kind == "" and main.tutorial_panel == null, "no session, panel or tutorial page opens")
	check(main.field_chip.visible and main.field_chip.title_label.text == "踩螃蟹", "the HUD chip appears with the game's name")
	check(FieldGames.COUNTDOWN_SECONDS <= 3.0, "the countdown is no longer than three seconds")
	check(field._caption.visible and field._caption.text == String(entry.hint) and not String(entry.hint).contains("\n"), "the countdown shows one line saying what to do")
	var waited := 0
	while field.phase == FieldGames.Phase.COUNTDOWN and waited < 400:
		await physics_frame
		waited += 1
	check(field.phase == FieldGames.Phase.PLAYING and waited <= 181, "play begins within three seconds of the key press (%d steps)" % waited)
	check(world.camera == camera and camera.current and world.get_parent() == main, "the same world and camera stay on screen")
	check(world.nearest.is_empty(), "a game that only needs walking shows no button prompt")
	check(field.press() and field.phase == FieldGames.Phase.PLAYING, "the interact key cannot start anything else mid-round")
	# Esc leaves the round instead of opening the pause menu.
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	main._unhandled_input(escape)
	check(field.phase == FieldGames.Phase.IDLE and main.modal_kind == "" and aborted == ["crab-stomp"], "the menu key ends the round first")
	check(not main.field_chip.visible, "the HUD chip closes when a round is abandoned")
	check(saved_before == FileAccess.get_file_as_bytes(save_path), "an abandoned round saves nothing")
	await frames(2)


func _test_leaving() -> void:
	var coins: int = progress.coins
	aborted.clear()
	begin("crab-stomp")
	check(field.phase == FieldGames.Phase.PLAYING, "a round is running before the walk-away check")
	var entry := row("crab-stomp")
	place(arena("crab-stomp") + Vector3(float(entry.radius) - 0.3, 0, 0))
	advance(0.5)
	check(field.phase == FieldGames.Phase.PLAYING, "staying inside the play radius keeps the round going")
	place(arena("crab-stomp") + Vector3(float(entry.radius) + 0.4, 0, 0))
	advance(0.1)
	check(field.phase == FieldGames.Phase.IDLE and aborted == ["crab-stomp"], "walking out of the radius ends the round")
	check(finished.is_empty() and progress.coins == coins and progress.field_records.is_empty(), "walking away records no result and pays nothing")
	check(game("crab-stomp").state.count(0) == game("crab-stomp").state.size(), "walking away puts the crabs back")
	# Leaving during the countdown is allowed too.
	place(arena("crab-stomp"))
	main._interact("field:crab-stomp", "")
	place(arena("crab-stomp") + Vector3(0, 0, -float(entry.radius) - 1.0))
	advance(0.1)
	check(field.phase == FieldGames.Phase.IDLE, "walking off during the countdown cancels it")
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)


## Finish a crab round at a chosen score by standing aside until the clock ends.
func _crab_round_scoring(score: int) -> Dictionary:
	begin("crab-stomp")
	var crab := game("crab-stomp")
	# Far from every hole, and pacing so the red crab is never called.
	var spot_a := arena("crab-stomp") + Vector3(0, 0, 3.9)
	var spot_b := spot_a + Vector3(1.0, 0, 0)
	place(spot_a)
	var limit := roundi((crab.seconds + 1.0) / STEP)
	for index in range(limit):
		if field.phase != FieldGames.Phase.PLAYING:
			break
		walk(spot_b if (index / 60) % 2 == 0 else spot_a, RUN_SPEED)
		crab.score = score
		field.advance(STEP)
	advance(FieldGames.RESULT_SECONDS + STEP)
	return finished[0] if not finished.is_empty() else {}


func _test_clock_medals_and_coins() -> void:
	var entry := row("crab-stomp")
	var medals: Array = entry.medals
	check(FieldGames.medal_for(entry, 0) == 0 and FieldGames.medal_for(entry, medals[0] - 1) == 0, "below bronze is no medal")
	check(FieldGames.medal_for(entry, medals[0]) == 1 and FieldGames.medal_for(entry, medals[1] - 1) == 1, "bronze from its score up to silver")
	check(FieldGames.medal_for(entry, medals[1]) == 2 and FieldGames.medal_for(entry, medals[2] - 1) == 2, "silver from its score up to gold")
	check(FieldGames.medal_for(entry, medals[2]) == 3 and FieldGames.medal_for(entry, 999) == 3, "gold from its score upward")
	var coins: int = progress.coins
	var normal: int = progress.normal_count()
	ticks.clear()
	sounds.clear()
	var none := _crab_round_scoring(0)
	check(int(none.get("medal", -1)) == 0 and progress.coins == coins and int(none.coins) == 0, "a round without a medal pays nothing")
	check(sounds.has("miss") and String(none.line) == String(entry.lines[0]), "no medal gets the funny consolation line")
	check(ticks.size() >= int(entry.seconds) and ticks[0].x == int(entry.seconds) and ticks[-1].x <= 1, "the clock counts the whole round down for the HUD")
	check(not progress.field_records.has("crab-stomp"), "a zero score leaves no record")
	var bronze := _crab_round_scoring(medals[0])
	check(int(bronze.medal) == 1 and int(bronze.coins) == 10 and progress.coins == coins + 10, "the first bronze pays 10 coins")
	check(bool(bronze.new_best) and int(bronze.best) == medals[0] and String(bronze.medal_name) == "銅牌", "the result carries score, medal and best")
	check(main.field_chip.visible and main.field_chip.time_label.text == "銅牌" and main.field_chip.note_label.text.contains("+10"), "the HUD shows the result and the coins")
	var again := _crab_round_scoring(medals[0])
	check(int(again.coins) == 0 and progress.coins == coins + 10 and not bool(again.new_best), "bronze a second time pays nothing")
	var gold := _crab_round_scoring(medals[2] + 2)
	check(int(gold.medal) == 3 and int(gold.coins) == 60 and progress.coins == coins + 70, "jumping to gold pays silver and gold once each")
	var lower := _crab_round_scoring(medals[1])
	check(int(lower.medal) == 2 and int(lower.coins) == 0 and int(lower.best) == medals[2] + 2, "a weaker later round keeps the best score and pays nothing")
	check(progress.field_records["crab-stomp"] == {"best": medals[2] + 2, "medal": 3}, "best score and best medal are kept")
	check(int(field.record_for("field:crab-stomp").medal) == 3, "the stand shows the gold medal")
	check(progress.normal_count() == normal and progress.photos.is_empty(), "instant games grant no stickers")


func _test_pause_and_reduced_motion() -> void:
	begin("jump-rope")
	var rope := game("jump-rope")
	advance(1.0)
	var left: float = field.time_left
	var angle: float = rope.angle
	world.blocked = true
	advance(5.0)
	check(is_equal_approx(field.time_left, left) and is_equal_approx(rope.angle, angle), "an open panel freezes the clock and the rope")
	check(field.press() and rope.air <= 0.0, "the key is swallowed but does nothing while paused")
	world.blocked = false
	advance(0.5)
	check(field.time_left < left and field.phase == FieldGames.Phase.PLAYING, "closing the panel resumes the same round")
	field._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	left = field.time_left
	advance(2.0)
	check(is_equal_approx(field.time_left, left), "losing window focus pauses the round")
	field._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(world.nearest.get("label", "") == "跳！" and main._context_prompt() == "E   跳！", "a timing game shows its one key")
	# Hop beside the lane, where the rope cannot interfere.
	place(arena("jump-rope") + Vector3(0, 0, 2.2))
	advance(rope.TRIP_SECONDS + rope.LAND_SECONDS)
	field.press()
	advance(0.2)
	check(world.avatar_visual_lift > 0.2, "a hop lifts the avatar's picture")
	check(is_equal_approx(feet().y, world.ground_surface_y(feet()) + 0.3) and world.player.velocity == Vector3.ZERO, "the body itself is untouched by the hop")
	field.abort()
	check(world.avatar_visual_lift == 0.0, "leaving a round puts the avatar back on the ground")
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	# Through the saved setting, the way the settings panel changes it.
	progress.set_setting("reduced_motion", true)
	check(world.reduced_motion, "the saved setting reaches the world")
	var steady := play_round("jump-rope", _rope_jumper.bind(1))
	check(int(steady.medal) == 3, "reduced motion keeps the rope game fully playable (scored %d)" % int(steady.score))
	check(_max_lift == 0.0, "reduced motion never lifts the avatar")
	field.advance(STEP)
	var still := true
	for record in field.records:
		still = still and is_zero_approx((record.pennant as Node3D).rotation.y)
	check(still, "reduced motion stops the pennants")
	progress.set_setting("reduced_motion", false)
	_max_lift = 0.0


# --- the five games, played by simulated visitors ---

func _nearest_crab(crab: Node3D) -> int:
	var best := -1
	var best_gap := INF
	for index in range(crab.holes.size()):
		if crab.state[index] != 2:
			continue
		var gap := Vector2(crab.holes[index].x - feet().x, crab.holes[index].z - feet().z).length()
		if gap < best_gap:
			best_gap = gap
			best = index
	return best


func _crab_chaser(speed: float) -> void:
	var crab := game("crab-stomp")
	var index := _nearest_crab(crab)
	# With nothing up, keep circling the pit rather than standing about.
	var orbit: float = crab.elapsed * 1.1
	var target: Vector3 = crab.holes[index] if index >= 0 else arena("crab-stomp") + Vector3(cos(orbit), 0, sin(orbit)) * 1.2
	walk(target, speed)


func _test_crab_stomp() -> void:
	var entry := row("crab-stomp")
	var keen := play_round("crab-stomp", _crab_chaser.bind(RUN_SPEED))
	check(int(keen.medal) == 3, "a visitor who runs at every crab earns gold (scored %d)" % int(keen.score))
	check(game("crab-stomp").pinches == 0, "a visitor who keeps moving is never pinched")
	var easy := play_round("crab-stomp", _crab_chaser.bind(STROLL_SPEED))
	check(int(easy.medal) >= 1 and int(easy.medal) < 3, "a strolling visitor earns a lower medal (scored %d)" % int(easy.score))
	# Standing on a hole calls the red crab up underneath.
	begin("crab-stomp")
	var crab := game("crab-stomp")
	place(crab.holes[0])
	var score_before: int = crab.score
	advance(crab.CAMP_SECONDS + crab.RUMBLE_SECONDS + 0.2)
	check(crab.pinches == 1 and crab.stunned > 0.0 and crab.red == 0, "standing still on a hole gets pinched by the red crab")
	check(world.avatar_visual_lift > 0.0 and sounds.has("miss"), "the pinch makes the avatar hop on the spot")
	check(crab.score == score_before, "a pinch costs no points")
	# The same crab can be bonked for revenge once the sting wears off.
	advance(crab.STUN_SECONDS)
	check(crab.score == score_before + 1, "the red crab can be bonked afterwards")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	# Later crabs hide sooner than early ones.
	check(lerpf(2.6, 1.4, 1.0) < lerpf(2.6, 1.4, 0.0) and int(entry.medals[2]) > int(entry.medals[0]), "the pace rises through the round")
	var lazy := _crab_round_scoring(0)
	check(int(lazy.medal) == 0, "ignoring the crabs earns nothing")


func _hat_chaser(speed: float) -> void:
	var hat := game("hat-chase")
	walk(Vector3(hat.gull.x, 0, hat.gull.y), speed)


var _lunging := false

func _hat_lurer() -> void:
	# Stand still until the gull comes to gloat, then lunge; give up if it gets away.
	var hat := game("hat-chase")
	var gap := Vector2(feet().x, feet().z).distance_to(hat.gull)
	_lunging = gap < (3.0 if _lunging else 2.0)
	if _lunging:
		walk(Vector3(hat.gull.x, 0, hat.gull.y), RUN_SPEED)


func _hat_quitter() -> void:
	# Chases until the first touch, then just watches.
	if game("hat-chase").touches < 1:
		_hat_chaser(RUN_SPEED)


func _test_hat_chase() -> void:
	var hat := game("hat-chase")
	var keen := play_round("hat-chase", _hat_chaser.bind(RUN_SPEED))
	check(int(keen.medal) == 3 and hat.touches == 3, "a determined chase gets the hat back for gold (scored %d)" % int(keen.score))
	check(hat.elapsed < hat.seconds, "three touches end the round early")
	var easy := play_round("hat-chase", _hat_chaser.bind(STROLL_SPEED))
	check(int(easy.medal) < 3, "a slow chase does not earn gold (scored %d, %d touches)" % [int(easy.score), hat.touches])
	var patient := play_round("hat-chase", _hat_lurer)
	check(hat.touches >= 1, "standing still lures the gull into reach (scored %d, %d touches)" % [int(patient.score), hat.touches])
	var quitter := play_round("hat-chase", _hat_quitter)
	check(int(quitter.medal) == 1 and int(quitter.score) == 10 and hat.touches == 1, "one touch is worth ten and earns bronze (scored %d)" % int(quitter.score))
	check(String(quitter.line) == String(row("hat-chase").lines[1]), "a gull that keeps the hat gets the last word")
	begin("hat-chase")
	var roam := float(row("hat-chase").roam)
	var inside := true
	for index in range(900):
		_hat_chaser(RUN_SPEED)
		field.advance(STEP)
		if field.phase != FieldGames.Phase.PLAYING:
			break
		inside = inside and Vector2(hat.gull.x - arena("hat-chase").x, hat.gull.y - arena("hat-chase").z).length() <= roam + 0.01
	check(inside, "the gull never leaves its lawn")
	field.abort()
	advance(FieldGames.RESULT_SECONDS + FieldGames.LEAVE_NOTE_SECONDS)


var _max_lift := 0.0
var _passes := 0
var _counted_turn := -1

## Hop just before the rope arrives; `miss_every` > 1 skips some turns.
func _rope_jumper(miss_every: int) -> void:
	var rope := game("jump-rope")
	_max_lift = maxf(_max_lift, world.avatar_visual_lift)
	if rope.tripped > 0.0:
		return
	var turn := lerpf(rope.SLOW_TURN, rope.FAST_TURN, rope.pace())
	var until_pass := (TAU - fposmod(rope.angle, TAU)) / TAU * turn
	var this_turn := floori(rope.angle / TAU)
	if until_pass < 0.26 and until_pass > 0.2 and rope.air <= -rope.LAND_SECONDS and this_turn != _counted_turn:
		_counted_turn = this_turn
		_passes += 1
		if miss_every <= 1 or _passes % miss_every != 0:
			field.press()


func _rope_masher() -> void:
	field.press()


func _test_jump_rope() -> void:
	var rope := game("jump-rope")
	check(rope.in_lane(arena("jump-rope")) and not rope.in_lane(arena("jump-rope") + Vector3(0, 0, 2.0)), "the lane is the strip between the posts")
	_passes = 0
	var keen := play_round("jump-rope", _rope_jumper.bind(1))
	check(int(keen.medal) == 3 and rope.trips == 0, "well-timed hops earn gold (scored %d)" % int(keen.score))
	check(_max_lift > 0.4, "each hop is visible")
	_passes = 0
	var sloppy := play_round("jump-rope", _rope_jumper.bind(3))
	check(int(sloppy.medal) >= 1 and int(sloppy.medal) < 3 and rope.trips > 0, "missing every third turn earns a lower medal (scored %d, tripped %d)" % [int(sloppy.score), rope.trips])
	var mashed := play_round("jump-rope", _rope_masher)
	check(int(mashed.medal) < 3, "hammering the key does not earn gold (scored %d)" % int(mashed.score))
	# Standing outside the lane is safe and scores nothing.
	begin("jump-rope")
	place(arena("jump-rope") + Vector3(0, 0, 2.2))
	advance(6.0)
	check(rope.trips == 0 and rope.score == 0, "watching from beside the lane neither trips nor scores")
	place(arena("jump-rope"))
	var fast_turn := TAU / lerpf(rope.SLOW_TURN, rope.FAST_TURN, 1.0)
	check(fast_turn > TAU / rope.SLOW_TURN * 1.5, "the rope ends at least half again as fast as it starts")
	advance(3.0)
	check(rope.trips >= 1 and rope._coil.visible == (rope.tripped > 0.0), "standing in the lane without hopping wraps you in the rope")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)


func _flag_runner(speed: float) -> void:
	var flags := game("flag-run")
	walk(flags.gates[flags.order[flags.target]], speed)


func _test_flag_run() -> void:
	var flags := game("flag-run")
	var keen := play_round("flag-run", _flag_runner.bind(RUN_SPEED))
	check(int(keen.medal) == 3 and flags.laps >= 1, "running the gates in order earns gold (scored %d)" % int(keen.score))
	var easy := play_round("flag-run", _flag_runner.bind(STROLL_SPEED))
	check(int(easy.medal) >= 1 and int(easy.medal) < 3, "walking the gates earns a lower medal (scored %d)" % int(easy.score))
	begin("flag-run")
	sounds.clear()
	place(flags.gates[2])
	advance(0.1)
	check(flags.wrong == 1 and flags.score == 0 and sounds == ["miss"], "a wrong gate honks and scores nothing")
	advance(0.5)
	check(flags.wrong == 1, "standing in a wrong gate honks once")
	place(flags.gates[0])
	advance(0.1)
	check(flags.score == 1 and flags.target == 1, "the right gate counts and the next one is called")
	var ring: PackedInt32Array = flags.order.duplicate()
	for index in range(1, flags.gates.size()):
		place(flags.gates[flags.order[index]])
		advance(0.1)
	check(flags.laps == 1 and flags.score == flags.gates.size(), "all gates in order complete a lap")
	check(flags.order != ring and flags.order[0] != ring[ring.size() - 1], "the next lap deals the numbers out differently")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)


## Shoot when at least `wanted` birds are framed (or the round is nearly over).
func _photographer(wanted: int) -> void:
	var shutter := game("bird-shutter")
	var hurry: bool = shutter.seconds - shutter.elapsed < 3.0 * shutter.film
	if shutter.birds_in_frame() >= (1 if hurry else wanted):
		field.press()


var _snap_at := 0

func _snapper() -> void:
	# Presses on a fixed beat without looking.
	_snap_at += 1
	if _snap_at % 200 == 150:
		field.press()


func _test_bird_shutter() -> void:
	var shutter := game("bird-shutter")
	var keen := play_round("bird-shutter", _photographer.bind(5))
	check(int(keen.medal) == 3 and shutter.shots.size() == 3, "waiting for full frames earns gold (scored %d from %s)" % [int(keen.score), str(shutter.shots)])
	check(shutter.elapsed < shutter.seconds, "the round ends once the film is used")
	var casual := play_round("bird-shutter", _photographer.bind(3))
	check(int(casual.medal) >= 1 and int(casual.medal) < 3, "settling for small groups earns a lower medal (scored %d from %s)" % [int(casual.score), str(shutter.shots)])
	_snap_at = 0
	var blind := play_round("bird-shutter", _snapper)
	check(int(blind.score) < int(keen.score), "shooting without looking scores less (scored %d)" % int(blind.score))
	# An empty frame is a photo of nothing.
	begin("bird-shutter")
	check(world.nearest.get("label", "") == "按快門" and shutter.birds_in_frame() == 0, "the round opens with the flock still off-frame")
	field.press()
	check(shutter.shots == [0] and shutter.film == 2 and sounds.has("shutter") and field._caption.text == "只拍到尾巴…", "an early press wastes a frame on tails")
	field.press()
	check(shutter.film == 2, "the camera needs a moment between shots")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)


func _test_every_game_with_reduced_motion() -> void:
	progress.set_setting("reduced_motion", true)
	_passes = 0
	_counted_turn = -1
	var rounds := {
		"crab-stomp": _crab_chaser.bind(RUN_SPEED), "hat-chase": _hat_chaser.bind(RUN_SPEED), "jump-rope": _rope_jumper.bind(1),
		"flag-run": _flag_runner.bind(RUN_SPEED), "bird-shutter": _photographer.bind(5),
	}
	for id: String in rounds:
		var result := play_round(id, rounds[id])
		check(world.reduced_motion and int(result.medal) == 3, "%s plays to the same gold with reduced motion (scored %d)" % [id, int(result.score)])
		check(world.avatar_visual_lift == 0.0, "%s leaves the avatar on the ground with reduced motion" % id)
	progress.set_setting("reduced_motion", false)


# --- toys ---

func _test_toys() -> void:
	var saved := FileAccess.get_file_as_bytes(save_path)
	var coins: int = progress.coins
	var toys: Node3D = field.toys
	for item: Dictionary in toys.items:
		var point: Dictionary = world._point_by_id(item.id)
		check(not point.is_empty() and not String(point.label).contains("\n") and String(point.label).length() <= 8, "%s has a one-line prompt" % item.id)
	notes.clear()
	var palm: Dictionary = toys.item_for("toy:palm")
	place(palm.ground + Vector3(0, 0, 1.2))
	var nut: MeshInstance3D = palm.nuts[0]
	var hung := nut.position.y
	main._interact("toy:palm", "")
	advance(0.2)
	check(palm.has("sprite") and not is_equal_approx((palm.sprite as Sprite3D).position.x, float(palm.rest_x)), "the palm shakes when pushed")
	advance(1.6)
	check(nut.position.y < hung - 2.0 and notes.size() == 1, "coconuts drop to the ground")
	advance(6.0)
	check(is_equal_approx(nut.position.y, hung), "the coconuts are back in the tree a little later")
	var swing: Dictionary = toys.item_for("toy:swing")
	place(swing.ground + Vector3(0, 0, 1.2))
	main._interact("toy:swing", "")
	advance(0.5)
	var arc := absf((swing.pivot as Node3D).rotation.x)
	check(arc > 0.1, "a push sets the swing going")
	main._interact("toy:swing", "")
	advance(0.6)
	check(float(swing.swing) > 0.6, "a second push swings it higher")
	advance(30.0)
	check(is_zero_approx((swing.pivot as Node3D).rotation.x), "left alone, the swing settles")
	var chime: Dictionary = toys.item_for("toy:chime")
	notes.clear()
	main._interact("toy:chime", "")
	advance(1.0)
	check(notes.size() == 5 and (chime.star as Label3D).visible, "five chimes ring one after another under the star")
	check(not is_zero_approx((chime.tubes[4] as Node3D).rotation.z), "the tubes swing as they ring")
	advance(4.0)
	var geyser: Dictionary = toys.item_for("toy:geyser")
	place(geyser.ground + Vector3(2.0, 0, 0))
	advance(0.2)
	check(not (geyser.column as Node3D).visible, "the blow-hole is quiet until stepped on")
	place(geyser.ground)
	advance(0.4)
	check((geyser.column as Node3D).visible and world.avatar_visual_lift > 0.3 and int(geyser.pokes) == 1, "stepping on the blow-hole sprays and lifts the visitor")
	advance(1.5)
	check(int(geyser.pokes) == 1 and not (geyser.column as Node3D).visible and world.avatar_visual_lift == 0.0, "standing on it does not spray again and again")
	var stones: Dictionary = toys.item_for("toy:stones")
	notes.clear()
	sounds.clear()
	var spots: PackedVector3Array = stones.spots
	for index in range(spots.size()):
		place(spots[index])
		advance(0.1)
	check(notes.size() == spots.size() and sounds == ["success"] and int(stones.streaks) == 1, "stepping the stones in order plays the scale and a flourish")
	place(spots[2])
	advance(0.1)
	place(spots[0])
	advance(0.1)
	check(int(stones.streaks) == 1 and int(stones.next) == 1, "out of order starts the tune again from the first stone")
	place(stones.ground + Vector3(0, 0, 2.0))
	advance(0.5)
	notes.clear()
	main._interact("toy:stones", "")
	advance(1.2)
	check(notes.size() == spots.size(), "pressing interact plays the tune as a hint")
	var bench: Dictionary = toys.item_for("toy:bench")
	place(bench.ground + Vector3(0, 0, 1.0))
	main._interact("toy:bench", "")
	advance(5.0)
	check(bool(bench.resting) and bench.birds.shown_count() == 4, "doves gather while the visitor rests at the bench")
	place(bench.ground + Vector3(0, 0, 6.0))
	advance(0.3)
	check(not bool(bench.resting) and bench.birds.shown_count() == 4, "they take off when the visitor leaves")
	advance(1.5)
	check(bench.birds.shown_count() == 0, "and are gone a moment later")
	world.apply_settings({"reduced_motion": true})
	main._interact("toy:swing", "")
	advance(0.3)
	var held := (swing.pivot as Node3D).rotation.x
	advance(0.3)
	check(not is_zero_approx(held) and is_equal_approx(held, (swing.pivot as Node3D).rotation.x), "reduced motion shows a held tilt instead of swinging")
	place(geyser.ground + Vector3(2.0, 0, 0))
	advance(2.5)
	place(geyser.ground)
	advance(0.3)
	check((geyser.column as Node3D).visible and world.avatar_visual_lift == 0.0, "reduced motion shows the spray without lifting the avatar")
	world.apply_settings({"reduced_motion": false})
	advance(3.0)
	world.blocked = true
	field.activate("field:flag-run")
	check(not field.activate("toy:swing") and field.phase == FieldGames.Phase.IDLE and int(swing.pokes) == 3, "nothing starts while a panel is open")
	world.blocked = false
	check(saved == FileAccess.get_file_as_bytes(save_path) and progress.coins == coins, "toys leave the saved progress untouched")


# --- nodes, saving ---

func _test_stable_nodes() -> void:
	var nodes := world.find_children("*", "Node", true, false).size()
	var materials: int = world.material_cache.size()
	for phase in ["dawn", "noon", "dusk", "night", "noon"]:
		world.set_time_of_day(phase)
		field.advance(STEP)
	for reduced in [true, false]:
		world.apply_settings({"reduced_motion": reduced})
		field.advance(STEP)
	play_round("flag-run", _flag_runner.bind(RUN_SPEED))
	play_round("bird-shutter", _photographer.bind(4))
	main._interact("toy:chime", "")
	advance(2.0)
	check(world.find_children("*", "Node", true, false).size() == nodes and world.material_cache.size() == materials,
		"time of day, settings, full rounds and toys create no nodes or materials")
	check(nodes + 1 <= 2600, "the Welcome island stays inside its 2600-node budget (%d)" % (nodes + 1))
	var lights := field.find_children("*", "Light3D", true, false).size()
	check(lights == 0, "the field layer adds no lights")


func _test_saved_records() -> void:
	var records: Dictionary = progress.field_records.duplicate(true)
	var coins: int = progress.coins
	check(records.size() >= 5, "every game played has a record (%d)" % records.size())
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(on_disk.get("field_records", {}).size() == records.size() and int(on_disk.coins) == coins, "records and coins are written to the save file")
	progress.field_records = {}
	progress.coins = 0
	progress.load_progress()
	check(progress.field_records == records and progress.coins == coins, "best scores, medals and coins survive a reload")
	check(int(field.record_for("field:crab-stomp").medal) == 3 and int(field.record_for("field:hat-chase").medal) == int(records["hat-chase"].medal), "the stands show reloaded medals")
	# Old saves without the field, damaged entries and unknown games all load safely.
	on_disk["field_records"] = {
		"crab-stomp": {"best": 7, "medal": 1}, "retired-game": {"best": 3, "medal": 0},
		"bad-score": {"best": -4, "medal": 1}, "bad-medal": {"best": 4, "medal": 9}, "bad-shape": 12,
	}
	on_disk["future_field"] = "kept"
	_write(on_disk)
	progress.load_progress()
	check(progress.field_records == {"crab-stomp": {"best": 7, "medal": 1}, "retired-game": {"best": 3, "medal": 0}}, "damaged records are dropped and unknown games are kept")
	check(progress.save_progress() and JSON.parse_string(FileAccess.get_file_as_string(save_path)).get("future_field") == "kept", "fields from a newer version are still preserved")
	var paid: Dictionary = progress.record_field_result("crab-stomp", 9, 2)
	check(int(paid.coins) == 20 and int(paid.best) == 9, "a reloaded bronze pays only the missing silver tier")
	on_disk.erase("field_records")
	_write(on_disk)
	progress.load_progress()
	check(progress.field_records.is_empty(), "a save from before instant games loads with no records")
	progress.reset_progress()
	check(progress.field_records.is_empty(), "a new game starts with no records")


func _write(payload: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


## A failed save must leave coins and records as they were. The blocked write
## logs an engine error, so it runs in a child process whose output is checked.
func _test_rollback_process() -> void:
	var child_path := save_path.get_base_dir().path_join("field-rollback-child/progress.json")
	OS.set_environment("SNAPLAND_SAVE_PATH", child_path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--script", "res://game/tests/test_field_games.gd", "--", "--field-rollback-child"], output, true)
	OS.set_environment("SNAPLAND_SAVE_PATH", save_path)
	var text := str(output[0] if not output.is_empty() else "")
	var errors := 0
	var passed := false
	for line in text.split("\n"):
		var clean := line.strip_edges()
		if clean.contains("ERROR:"):
			errors += 1
			check(clean == "ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path, "unexpected child error: " + clean)
		passed = passed or clean == ROLLBACK_MARKER
	check(code == 0 and passed and errors == 1, "a failed save rolls the record back (exit %d, %d errors): %s" % [code, errors, text.right(1200)])


func _run_rollback_child() -> void:
	progress = root.get_node("Progress")
	progress.reset_progress()
	check(progress.save_progress(), "child profile is writable")
	var first: Dictionary = progress.record_field_result("crab-stomp", 6, 1)
	check(bool(first.saved) and int(first.coins) == 10, "child records a bronze")
	var coins: int = progress.coins
	var bytes := FileAccess.get_file_as_bytes(save_path)
	var changes := [0]
	progress.changed.connect(func() -> void: changes[0] += 1)
	check(DirAccess.make_dir_absolute(save_path + ".tmp") == OK, "block the temporary write")
	var failed: Dictionary = progress.record_field_result("crab-stomp", 20, 3)
	check(not bool(failed.saved) and int(failed.coins) == 0, "the failed save is reported")
	check(progress.coins == coins and progress.field_records == {"crab-stomp": {"best": 6, "medal": 1}} and changes[0] == 0, "memory is rolled back without a change signal")
	check(bytes == FileAccess.get_file_as_bytes(save_path), "the saved file is untouched")
	check(DirAccess.remove_absolute(save_path + ".tmp") == OK, "remove the write blocker")
	var retry: Dictionary = progress.record_field_result("crab-stomp", 20, 3)
	check(bool(retry.saved) and int(retry.coins) == 60, "the same result can be saved once writing works again")
	if failures.is_empty():
		print(ROLLBACK_MARKER)
	quit(0 if failures.is_empty() else 1)
