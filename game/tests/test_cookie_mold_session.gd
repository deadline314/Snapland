extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

static func key(session: Control, code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	session._unhandled_input(event)

static func tap(session: Control, code: Key) -> void:
	key(session, code)
	key(session, code, false)

static func advance(session: Control, seconds: float) -> void:
	var left := seconds
	while left > 0.000001 and not session.ended:
		var delta := minf(left, 0.25)
		session._process(delta)
		left -= delta

static func pointer(session: Control, design: Vector2, action: String) -> void:
	var scale_factor := minf(session.size.x / Session.DESIGN_SIZE.x, session.size.y / Session.DESIGN_SIZE.y)
	var position: Vector2 = session.presentation.get_global_transform_with_canvas() * design if is_instance_valid(session.presentation) else session.get_global_transform_with_canvas() * ((session.size - Session.DESIGN_SIZE * scale_factor) * 0.5 + design * scale_factor)
	var event: InputEvent
	if action == "move":
		event = InputEventMouseMotion.new()
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = action == "press"
	event.position = position
	session._unhandled_input(event)

static func solve(session: Control, devil: bool = false) -> bool:
	if session == null or session.active_driver == null: return false
	session.set_process(false)
	var view: Script = load("res://game/minigames/cookie_mold_view.gd")
	for slot in 6:
		# Public snapshots choose input locations; every state change uses Session input.
		for knock in 180:
			var state: Dictionary = session.active_driver.snapshot()
			if state.phase != "molded" or state.ended: break
			var edge := 0
			for index in state.edges.size():
				if state.edges[index].adhesion > state.edges[edge].adhesion: edge = index
			if state.edges[edge].adhesion <= 0.15: break
			for change in state.edges.size():
				if session.active_driver.snapshot().selected_edge == edge: break
				tap(session, KEY_TAB)
			key(session, KEY_SPACE)
			advance(session, 0.16)
			key(session, KEY_SPACE, false)
		var state: Dictionary = session.active_driver.snapshot()
		if state.phase != "molded": return false
		if not state.helper: tap(session, KEY_R)
		pointer(session, view.mold_handle_point(state), "press")
		for frame in 1080:
			state = session.active_driver.snapshot()
			if state.phase != "molded" or state.ended: break
			var aim: Dictionary = state.duplicate(true)
			aim.mold_angle = 2.8 if devil and slot == 5 else minf(PI, float(frame + 1) * 0.9 / 120.0)
			pointer(session, view.mold_handle_point(aim), "move")
			advance(session, 1.0 / 120.0)
		pointer(session, view.mold_handle_point(state), "release")
		state = session.active_driver.snapshot()
		if state.phase != "flying": return false
		pointer(session, view.tray_point(state), "press")
		for frame in 600:
			state = session.active_driver.snapshot()
			if state.phase != "flying" or state.ended: break
			var tray_aim: Dictionary = state.duplicate(true)
			tray_aim.tray_x = state.cookie_position.x
			pointer(session, view.tray_point(tray_aim), "move")
			advance(session, 1.0 / 120.0)
		pointer(session, view.tray_point(state), "release")
		state = session.active_driver.snapshot()
		if state.phase != "caught" or state.caught != slot + 1: return false
		if not session.ended: advance(session, 0.46)
	return session.ended and session.won and session.devil_won == devil

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	expect(Catalog.find("game-026").get("mode", "") == "cookie_mold", "game026 must be delivered before Cookie Session integration")
	if failures:
		_finish()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var s = Session.new()
	root.add_child(s)
	s.set_process(false)
	var results: Array[Dictionary] = []
	s.finished.connect(func(result: Dictionary): results.append(result))
	s.start("game-026")
	expect(s.mode == "cookie_mold" and s.active_driver != null and not s.ended, "Session routes026 to the physical cookie driver")
	if s.active_driver == null:
		s.free()
		_finish()
		return
	var driver = s.active_driver
	expect(s.presentation == null if DisplayServer.get_name() == "headless" else s.presentation != null, "headless keeps rules renderer-free; native owns the view")
	s._process(0.1)
	expect(is_equal_approx(s.elapsed, 0.1) and s.elapsed == driver.snapshot().elapsed, "only model time advances")
	key(s, KEY_SPACE)
	s._process(0.1)
	var edges: Array = driver.snapshot().edges
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	expect(not frozen.charging and frozen.charge == 0 and frozen.edges == edges, "pause cancels charge without knocking")
	s._process(100.0)
	expect(driver.snapshot() == frozen, "pause freezes physical cookies and timer")
	s.set_paused(false)
	s._process(100.0)
	expect(driver.snapshot() == frozen, "resume discards suspended delta")
	key(s, KEY_SPACE)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(s.paused and not driver.snapshot().charging and driver.snapshot().edges == edges, "blur pauses and cancels charge without knocking")
	s.set_paused(false)
	var old_view = s.presentation
	s._retry_from_hud()
	expect(s.active_driver == driver and s.presentation == old_view and driver.snapshot().variant == 1 and s.elapsed == 0.0, "retry reuses driver/view and changes actual configuration")
	advance(s, 151.0)
	expect(results.size() == 1 and not results.back().success and not results.back().ordinary_eligible and results.back().score == 0, "idle timeout grants no participation or fabricated points")
	s.start("game-026")
	key(s, KEY_RIGHT)
	advance(s, 0.1)
	key(s, KEY_RIGHT, false)
	advance(s, 151.0)
	expect(results.size() == 2 and not results.back().success and results.back().ordinary_eligible and not results.back().devil, "actual tray movement then timeout qualifies ordinary only")
	expect(results.back().game_id == "game-026" and results.back().score_summary.total == s.score, "fixed result identity and score rows agree")
	s.start("game-026")
	s.set_practice_mode(true)
	expect(solve(s, true), "six real catches with inertial double-layer complete practice")
	expect(results.back().practice and results.back().success and not results.back().ordinary_eligible, "practice suppresses ordinary despite physical success")
	s.set_practice_mode(false)
	s.start("game-026", true)
	expect(solve(s, true), "assisted six real catches include inertial double-layer")
	expect(results.back().success and results.back().devil and results.back().assisted and results.back().score == 800, "assisted actual inertia retains devil and exact800 points")
	s.start("game-026")
	expect(solve(s), "gentle real six-cookie route completes")
	expect(results.back().success and not results.back().devil and results.back().score == 700, "low-inertia route stays ordinary with exact700 points")
	var count := results.size()
	s.start("game-026")
	key(s, KEY_SPACE)
	s._leave_from_hud()
	s._process(99.0)
	expect(s.ended and results.size() == count and not s.active_driver.snapshot().charging, "cancel clears held charge and emits no completion")
	s.start("game-%03d" % (Catalog.all_definitions().size() + 1))
	expect(s.ended and s.game_id.is_empty() and s.active_driver == null, "next undelivered game remains refused")
	s.start("game-026")
	s._process(0.1)
	s._refresh_hud(true)
	expect(s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "shared HUD uses actual cookie time and catches")
	s.queue_free()
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	print("Cookie mold Session: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
