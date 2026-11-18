extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Driver = preload("res://game/minigames/chocolate_etching_driver.gd")
const DriverTest = preload("res://game/tests/test_chocolate_etching_driver.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

static func route(session: Control, source: String = "pointer") -> DriverTest.Route:
	var state: Dictionary = session.active_driver.snapshot()
	return DriverTest.Route.new(source, state.assisted, state.variant, session.active_driver,
		func(event: InputEvent, design: Vector2) -> bool:
			if not event is InputEventKey:
				var extent := session.size
				var scale_factor := minf(extent.x / Session.DESIGN_SIZE.x, extent.y / Session.DESIGN_SIZE.y)
				event.position = session.get_global_transform_with_canvas() * ((extent - Session.DESIGN_SIZE * scale_factor) * 0.5 + design * scale_factor)
			session._unhandled_input(event)
			return true)

static func advance(session: Control, seconds: float) -> void:
	while seconds > 0.000001 and not session.ended:
		var delta := minf(seconds, 0.25)
		session._process(delta)
		seconds -= delta

static func cut_line(session: Control) -> void:
	route(session).trace(PackedVector2Array([Vector2(100, 100), Vector2(130, 100)]), false)

static func solve(session: Control, devil: bool = false, source: String = "pointer") -> bool:
	if session == null or session.active_driver == null:
		return false
	assert(source in ["pointer", "touch"], "These Session recipes use pointer or touch events and advance only the Session clock")
	session.set_process(false)
	var input := route(session, source)
	if session.assisted:
		input.tap("helper")
	if not input.craft(devil):
		print("CHOCOLATE Session rejected cut ", JSON.stringify(input.diagnostic(input.driver.snapshot())))
		return false
	input.arrange(devil)
	input.command("tool", true)
	advance(session, 0.75)
	var turning: Dictionary = input.driver.snapshot()
	input.drive_angles = turning.parts.map(func(part): return part.angle)
	advance(session, 4.25)
	input.command("tool", false)
	var outcome: Dictionary = input.driver.snapshot()
	var proof: Dictionary = input.result(outcome)
	proof["output_omega_at_075"] = turning.output_omega
	proof["output_travel_at_075"] = turning.output_travel
	print("CHOCOLATE Session route ", JSON.stringify(proof))
	var contacts := [Vector2i(0, 1), Vector2i(1, 3), Vector2i(2, 3)] if devil else [Vector2i(0, 1), Vector2i(1, 2)]
	return session.ended and session.won and session.devil_won == devil and outcome.output_travel >= TAU - 1.0e-8 \
		and outcome.connections == contacts and turning.output_travel > 0 and signf(turning.output_omega) == (-1.0 if devil else 1.0)

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	var cancellations: Array[bool] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.cancelled.connect(func(): cancellations.append(true))
	session.start("game-029")
	var driver: Script = session.active_driver.get_script() if session.active_driver != null else null
	var wired := driver == Driver and session.game_id == "game-029" and not session.ended and cancellations.is_empty()
	print("CHOCOLATE Session.start observed: id=%s mode=%s driver=%s ended=%s cancellations=%s" % [session.game_id, session.mode, driver != null, session.ended, cancellations.size()])
	expect(wired, "game-029 must open a live Chocolate Etching Session with its own driver")
	if wired:
		_lifecycle(session, results, cancellations)
		for assisted: bool in [false, true]:
			for devil: bool in [false, true]:
				for variant in 2:
					session.start("game-029", assisted)
					if variant == 1:
						session._retry_from_hud()
					expect(session.active_driver.snapshot().variant == variant, "actual retry selects requested A/B")
					var count := results.size()
					expect(solve(session, devil, "pointer" if variant == 0 else "touch"), "actual A/B ordinary/idler route reaches natural finish")
					var result: Dictionary = results.back() if results.size() == count + 1 else {}
					var score := 500 if devil else 400
					expect(result.get("game_id") == "game-029" and result.get("score") == score and result.get("assisted") == assisted
						and result.get("ordinary_eligible", false) and result.get("score_summary", {}).get("total") == score, "natural result has fixed029 identity, eligibility and computed score")
	session.queue_free()
	await process_frame
	await process_frame
	print("Chocolate etching Session: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))

func _lifecycle(session: Control, results: Array[Dictionary], cancellations: Array[bool]) -> void:
	var input := route(session, "keyboard")
	input.command("tool", true)
	input.command("right", true)
	advance(session, 0.2)
	var live: Dictionary = input.driver.snapshot()
	expect(live.cutting and live.current_stroke.size() >= 2 and not live.participated, "held keys produce an actual uncommitted hot stroke")
	_interrupt(session, false)
	input.command("right", false)
	input.command("tool", false)
	var frozen: Dictionary = input.driver.snapshot()
	expect(not frozen.cutting and frozen.selected_strokes.is_empty() and not frozen.participated, "pause drops held cut without ghost participation")
	input = route(session)
	var start: Vector2 = input.view.board_to_design(Vector2(100, 100))
	var end: Vector2 = input.view.board_to_design(Vector2(130, 100))
	input.pointer(start, true)
	input.motion(end)
	expect(input.driver.snapshot().cutting and input.driver.snapshot().current_stroke.size() >= 2, "pointer cut preview has real motion before blur")
	_interrupt(session, true)
	input.pointer(end, false)
	frozen = input.driver.snapshot()
	expect(not frozen.cutting and frozen.selected_strokes.is_empty() and not frozen.participated, "blur and late release cannot commit a pointer stroke")
	input.tap("select")
	input.tap("shallow")
	input.tap("helper")
	input.tap("phase")
	input.tap("tool")
	advance(session, 241.0)
	expect(results.size() == 1 and not results.back().ordinary_eligible and not results.back().success, "controls, canceled previews and idle timeout are ineligible")
	session.start("game-029")
	cut_line(session)
	advance(session, 241.0)
	expect(results.size() == 2 and results.back().ordinary_eligible and not results.back().success and not results.back().devil, "one actual open hot cut earns ordinary on natural timeout")
	session.start("game-029")
	session.set_practice_mode(true)
	cut_line(session)
	advance(session, 241.0)
	expect(results.size() == 3 and results.back().practice and not results.back().ordinary_eligible, "practice with a real cut excludes award")
	session.set_practice_mode(false)
	session.start("game-029")
	input = route(session)
	expect(input.craft(false), "pause and blur setup extracts three actual gears")
	input.arrange(false)
	for blur in [false, true]:
		var mounted: Dictionary = input.driver.snapshot()
		input.select(0)
		var original: Vector2 = mounted.parts[0].position
		start = input.view.board_to_design(original)
		end = input.view.board_to_design(original + Vector2(48, 36))
		input.pointer(start, true)
		input.motion(end)
		var drag: Dictionary = input.driver.snapshot()
		expect(drag.cursor.distance_to(original) > 20 and drag.parts[0].position == original, "actual mount drag moves preview before pause or blur")
		_interrupt(session, blur)
		input.pointer(end, false)
		var settled: Dictionary = input.driver.snapshot()
		expect(settled.parts[0].position == original and settled.undo_available == mounted.undo_available and settled.connections == mounted.connections, "interrupted drag leaves gear and contacts unchanged")
		input.command("tool", true)
		advance(session, 0.25)
		live = input.driver.snapshot()
		expect(live.driving and live.output_travel > settled.output_travel, "real connected network rotates while held")
		_interrupt(session, blur)
		input.command("tool", false)
		advance(session, 0.25)
		settled = input.driver.snapshot()
		expect(not settled.driving and settled.output_travel == live.output_travel
			and settled.parts.map(func(p): return p.angle) == live.parts.map(func(p): return p.angle), "pause or blur stops real rotation and retains prior progress")
	var previous_driver = session.active_driver
	session._retry_from_hud()
	frozen = session.active_driver.snapshot()
	expect(session.active_driver == previous_driver and frozen.variant == 1 and frozen.elapsed == 0.0 and not frozen.participated
		and frozen.output_travel == 0.0 and frozen.parts.all(func(p): return not p.freed and not p.mounted), "HUD retry alternates A/B and clears runtime state")
	cut_line(session)
	session._leave_from_hud()
	advance(session, 241.0)
	expect(session.ended and cancellations.size() == 1 and results.size() == 3, "leaving after a real cut produces no result")

func _interrupt(session: Control, blur: bool) -> void:
	if blur:
		session._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	else:
		session.set_paused(true)
	var snapshot: Dictionary = session.active_driver.snapshot()
	session._process(20.0)
	expect(session.paused and session.active_driver.snapshot() == snapshot, "pause or blur freezes the live Session clock")
	session.set_paused(false)
	session._process(20.0)
	expect(session.active_driver.snapshot() == snapshot, "resume discards the suspended frame")
