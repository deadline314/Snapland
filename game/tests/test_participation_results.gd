extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const SugarLanternView = preload("res://game/minigames/sugar_lantern_view.gd")
const Umbrella = preload("res://game/minigames/umbrella_lights_model.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Chocolate = preload("res://game/tests/test_chocolate_etching_session.gd")
const Cotton = preload("res://game/tests/test_cotton_wind_session.gd")
const Seesaw = preload("res://game/tests/test_bean_seesaw.gd")
const Ice = preload("res://game/tests/test_ice_slide.gd")
const Filling = preload("res://game/tests/test_filling_press.gd")
const Glide = preload("res://game/tests/test_paper_glide.gd")
const Lift = preload("res://game/tests/test_bubble_lift.gd")
const Draw = preload("res://game/tests/test_sugar_draw.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var session = Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	var cancelled: Array[int] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.cancelled.connect(func(): cancelled.append(1))
	for definition: Dictionary in Catalog.all_definitions():
		var before_formal := results.size()
		session.start(definition.id)
		if definition.mode == "jelly_trampoline":
			preload("res://game/tests/test_jelly_trampoline_session.gd").launch(session, 0.15)
		if definition.mode == "chocolate_etching": Chocolate.cut_line(session)
		if definition.mode == "cotton_wind": Cotton.participate(session)
		if definition.mode == "bean_seesaw": Seesaw.participate_without_pair(session)
		if definition.mode == "ice_slide": Ice.participate(session)
		if definition.mode == "filling_press": Filling.participate(session)
		if definition.mode == "paper_glide": Glide.participate(session)
		if definition.mode == "bubble_lift": Lift.participate(session)
		if definition.mode == "sugar_draw": Draw.participate(session)
		if definition.mode == "sugar_bridge":
			var load_ball := InputEventKey.new()
			load_ball.keycode = KEY_ENTER
			load_ball.pressed = true
			session._unhandled_input(load_ball)
			load_ball.pressed = false
			session._unhandled_input(load_ball)
		if definition.mode == "syrup_flood":
			var valve := InputEventKey.new()
			valve.keycode = KEY_SPACE
			for pressed in [true,false,true,false]:
				valve.pressed = pressed
				session._unhandled_input(valve)
		if definition.mode == "cookie_mold":
			var move_tray := InputEventKey.new()
			move_tray.keycode = KEY_RIGHT
			move_tray.pressed = true
			session._unhandled_input(move_tray)
			session._process(0.1)
			move_tray.pressed = false
			session._unhandled_input(move_tray)
		if definition.mode == "sugar_lantern": _join_initial_sugar_strand(session)
		if definition.mode == "cart_passing": _push_initial_cart(session)
		if definition.mode == "soup_tray": _carry_initial_soup(session)
		if definition.mode == "umbrella_lights": _expose_first_umbrella_petal(session)
		if definition.mode == "pancake_fold": _place_pancake_batter(session)
		if definition.mode == "banner_cart": _push_banner_cart(session)
		if definition.mode == "scent_trail": _sample_initial_wake(session)
		if definition.mode == "coin_bank_shot": _launch_coin(session)
		if definition.mode == "lantern_crossing": _start_lantern_move(session)
		if definition.mode == "skewer_grill": _start_skewer_heat(session)
		if definition.mode == "rain_courier": _walk_with_courier(session)
		if session.active_driver != null:
			_advance_driver_to_result(session)
		else:
			session._finish(false, true)
		_check(results.size() == before_formal + 1 and results.back().get("ordinary_eligible", false)
			and not results.back().success and not results.back().devil, definition.id + " natural false stays honest and ordinary eligible")
		var result_count := results.size()
		if definition.mode in ["cotton_wind", "bean_seesaw", "ice_slide", "filling_press", "paper_glide", "bubble_lift", "sugar_draw"]: session._process(0.25)
		else: session._finish(true, true)
		_check(results.size() == result_count, "natural finish emits once")
		var before_practice := results.size()
		session.start(definition.id)
		session.set_practice_mode(true)
		if definition.mode == "jelly_trampoline":
			preload("res://game/tests/test_jelly_trampoline_session.gd").launch(session, 0.15)
			preload("res://game/tests/test_jelly_trampoline_session.gd").advance(session, 61.0)
		elif definition.mode == "chocolate_etching":
			Chocolate.cut_line(session)
			Chocolate.advance(session, 241.0)
		elif definition.mode == "cotton_wind":
			Cotton.participate(session)
			Cotton.advance(session, 121.0)
		elif definition.mode == "bean_seesaw":
			Seesaw.participate_without_pair(session)
			Seesaw.advance(session, 76.0)
		elif definition.mode == "ice_slide":
			Ice.participate(session)
			for tick in 362:
				session._process(0.25)
		elif definition.mode == "filling_press":
			Filling.participate(session)
			for tick in 310:
				session._process(0.25)
		elif definition.mode == "paper_glide":
			Glide.participate(session)
			for tick in 310:
				session._process(0.25)
		elif definition.mode == "bubble_lift":
			Lift.participate(session)
			for tick in 340:
				session._process(0.25)
		elif definition.mode == "sugar_draw":
			Draw.participate(session)
			for tick in 360:
				session._process(0.25)
		elif definition.mode == "syrup_flood":
			var practice_valve := InputEventKey.new()
			practice_valve.keycode = KEY_SPACE
			for pressed in [true,false,true,false]:
				practice_valve.pressed = pressed
				session._unhandled_input(practice_valve)
			for tick in 310:
				if session.ended: break
				session._process(0.25)
		elif definition.mode == "sugar_lantern":
			_join_initial_sugar_strand(session)
			_advance_driver_to_result(session)
		elif definition.mode == "cart_passing":
			_push_initial_cart(session)
			_advance_driver_to_result(session)
		elif definition.mode == "soup_tray":
			_carry_initial_soup(session)
			_advance_driver_to_result(session)
		elif definition.mode == "umbrella_lights":
			_expose_first_umbrella_petal(session)
			_advance_driver_to_result(session)
		elif definition.mode == "pancake_fold":
			_place_pancake_batter(session)
			_advance_driver_to_result(session)
		elif definition.mode == "banner_cart":
			_push_banner_cart(session)
			_advance_driver_to_result(session)
		elif definition.mode == "scent_trail":
			_sample_initial_wake(session)
			_advance_driver_to_result(session)
		elif definition.mode == "coin_bank_shot":
			_launch_coin(session)
			_advance_driver_to_result(session)
		elif definition.mode == "lantern_crossing":
			_start_lantern_move(session)
			_advance_driver_to_result(session)
		elif definition.mode == "skewer_grill":
			_start_skewer_heat(session)
			_advance_driver_to_result(session)
		elif definition.mode == "rain_courier":
			_walk_with_courier(session)
			_advance_driver_to_result(session)
		elif session.active_driver != null: session._driver_state["ordinary_eligible"] = true
		if definition.mode not in ["cotton_wind", "bean_seesaw", "ice_slide", "filling_press", "paper_glide", "bubble_lift", "sugar_draw", "rain_courier", "skewer_grill", "lantern_crossing", "coin_bank_shot", "scent_trail", "banner_cart", "pancake_fold", "umbrella_lights", "soup_tray", "cart_passing", "sugar_lantern"]: session._finish(false)
		_check(results.size() == before_practice + 1 and results.back().has("ordinary_eligible")
			and not results.back().ordinary_eligible and results.back().practice, definition.id + " practice excluded explicitly")
		session.set_practice_mode(false)
		session.start(definition.id)
		result_count = results.size()
		var cancel_count := cancelled.size()
		session._leave_from_hud()
		if definition.mode == "cotton_wind": Cotton.advance(session, 121.0)
		elif definition.mode == "bean_seesaw": Seesaw.advance(session, 76.0)
		else: session._finish(false)
		_check(results.size() == result_count and cancelled.size() == cancel_count + 1, definition.id + " cancellation is separate")
	session.start("game-013")
	session._driver_state["ordinary_eligible"] = false
	session._finish(false)
	_check(not results.back().ordinary_eligible, "driver natural ineligibility is retained")
	var before_idle := results.size()
	session.start("game-037")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and results.back().has("ordinary_eligible")
		and not results.back().ordinary_eligible and not results.back().success and not results.back().practice,
		"inactive formal courier expires without ordinary eligibility")
	before_idle = results.size()
	session.start("game-038")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"inactive grill does not count as actual cooking")
	before_idle = results.size()
	session.start("game-039")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"inactive trolley does not count as loaded travel")
	before_idle = results.size()
	session.start("game-040")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting at the coin table does not count as a shot")
	before_idle = results.size()
	session.start("game-041")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting in the scent court does not count as taking a sample")
	before_idle = results.size()
	session.start("game-042")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting by the banner cart does not count as movement")
	before_idle = results.size()
	session.start("game-043")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting by the griddle does not count as pouring batter")
	before_idle = results.size()
	session.start("game-044")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting under the moving lamp does not count as deliberate exposure")
	before_idle = results.size()
	session.start("game-045")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting with a full bowl does not count as serving")
	before_idle = results.size()
	session.start("game-046")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting by the cars does not count as legal movement")
	before_idle = results.size()
	session.start("game-047")
	_advance_driver_to_result(session)
	_check(results.size() == before_idle + 1 and not results.back().ordinary_eligible and not results.back().success,
		"waiting at an empty copper plate does not count as joining sugar")
	session.free()
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: every delivered participation result, practice, cancellation and driver eligibility")
	quit(0 if failures.is_empty() else 1)

func _advance_driver_to_result(session: Session) -> void:
	for tick in 4000:
		if session.ended:
			break
		session._process(0.1)

func _walk_with_courier(session: Session) -> void:
	# Real route selection, pickup, and movement establish participation without delivering a box.
	var key := InputEventKey.new()
	for code in [KEY_RIGHT, KEY_E]:
		key.keycode = code
		key.pressed = true
		session._unhandled_input(key)
		key.pressed = false
		session._unhandled_input(key)
	key.keycode = KEY_UP
	key.pressed = true
	session._unhandled_input(key)
	for tick in 22:
		session._process(0.1)
	key.pressed = false
	session._unhandled_input(key)

func _start_skewer_heat(session: Session) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	session._unhandled_input(key)
	key.pressed = false
	session._unhandled_input(key)


func _start_lantern_move(session: Session) -> void:
	var state: Dictionary = session.active_driver.snapshot()
	var left_to_right: bool = state.source.x < state.target.x
	var high_side := KEY_A if left_to_right else KEY_D
	var low_side := KEY_D if left_to_right else KEY_A
	var key := InputEventKey.new()
	for code in [KEY_E, high_side, KEY_W, KEY_W, KEY_W, KEY_W, low_side, KEY_S, KEY_SPACE]:
		key.keycode = code
		key.pressed = true
		session._unhandled_input(key)
		key.pressed = false
		session._unhandled_input(key)


func _join_initial_sugar_strand(session: Session) -> void:
	var driver: RefCounted = session.active_driver
	var pegs: PackedVector2Array = driver.snapshot().pegs
	for peg in [0, 1]:
		var finger := InputEventScreenTouch.new()
		finger.index = peg
		finger.pressed = true
		driver.handle_input(finger, SugarLanternView.PEG_AREA.position + pegs[peg] * SugarLanternView.PEG_AREA.size)


func _push_initial_cart(session: Session) -> void:
	var key := InputEventKey.new()
	# At least one direction is legal on the first vehicle in each layout.
	for code in [KEY_LEFT, KEY_RIGHT]:
		key.keycode = code
		key.pressed = true
		session._unhandled_input(key)
		key.pressed = false
		session._unhandled_input(key)
		session._process(0.2)


func _carry_initial_soup(session: Session) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	session._unhandled_input(key)
	for tick in 5:
		session._process(0.1)
	key.pressed = false
	session._unhandled_input(key)


func _expose_first_umbrella_petal(session: Session) -> void:
	# Follow the real moving guide with held inputs for exactly the first phase.
	var held := 0.0
	for tick in 250:
		var state: Dictionary = session.active_driver.snapshot()
		if state.phase_index != 0 or state.ended:
			break
		var feed := 0.0
		if state.live or state.seconds_to_sweep <= 4.0 * Umbrella.TICK + 0.00001:
			feed = rad_to_deg(float(state.beam_end - state.beam_start)) / float(state.sweep_seconds)
		var error := rad_to_deg(angle_difference(state.angle, state.guide_heading))
		var velocity := rad_to_deg(state.velocity)
		var desired := clampf(feed + 8.0 * error, -96.0, 96.0)
		var steering := signf(desired - velocity) if absf(desired - velocity) > 3.8 else 0.0
		if absf(feed) < 4.0 and absf(error) <= 1.3 and absf(velocity) <= 8.0:
			steering = 0.0
		if held != steering:
			if held != 0.0:
				_umbrella_turn_key(session, held, false)
			if steering != 0.0:
				_umbrella_turn_key(session, steering, true)
			held = steering
		session._process(Umbrella.TICK)
	if held != 0.0:
		_umbrella_turn_key(session, held, false)


func _umbrella_turn_key(session: Session, direction: float, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_A if direction < 0.0 else KEY_D
	event.pressed = pressed
	session._unhandled_input(event)


func _place_pancake_batter(session: Session) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	for pressed in [true, false]:
		key.pressed = pressed
		session._unhandled_input(key)


func _push_banner_cart(session: Session) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	session._unhandled_input(key)
	for tick in 10:
		session._process(0.1)
	key.pressed = false
	session._unhandled_input(key)


func _sample_initial_wake(session: Session) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	for pressed in [true, false]:
		key.pressed = pressed
		session._unhandled_input(key)


func _launch_coin(session: Session) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	session._unhandled_input(key)
	key.pressed = false
	session._unhandled_input(key)


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
