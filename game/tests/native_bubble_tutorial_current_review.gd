extends "res://game/tests/native_fountain_review.gd"

## Opens game-010 through the real park station and records its first-visit lesson.
const TARGET_GAME_ID := "game-010"
const EXPECTED_IMAGES: Array[String] = [
	"res://assets/ui/tutorials/game-010-step-01.png",
	"res://assets/ui/tutorials/game-010-step-02.png",
	"res://assets/ui/tutorials/game-010-step-03.png",
]
const REVIEW_IMAGES: Array[String] = [
	".review/bubble-current-tutorial/step-01.png",
	".review/bubble-current-tutorial/step-02.png",
	".review/bubble-current-tutorial/step-03.png",
]
const WALL_TIMEOUT_MSEC := 30000

var _started_msec := 0
var _finishing := false
var _watchdog_triggered := false

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
	if _started_msec > 0 and not _finishing and not _watchdog_triggered and Time.get_ticks_msec() - _started_msec > WALL_TIMEOUT_MSEC:
		_watchdog_triggered = true
		call_deferred("_review_fail", "Native game-010 tutorial exceeded the 30-second wall-clock limit")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		await _review_fail("Native game-010 tutorial review requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		return
	_started_msec = Time.get_ticks_msec()
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _review_fail("Progress autoload is missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main(false)
	if main == null:
		await _review_fail("Could not instantiate the real Main scene")
		return
	get_tree().root.add_child(main)
	await _frames(6)
	if not await _open_first_bubble_tutorial():
		return
	for step_index in range(3):
		if not await _capture_step(step_index):
			return
		if step_index < 2:
			var next_button := main.tutorial_panel.get("_next_button") as Button
			if next_button == null:
				await _review_fail("Game-010 tutorial page %d has no real next-page button" % (step_index + 1))
				return
			if not await _native_click_button(next_button, "advance game-010 tutorial to page %d" % (step_index + 2)):
				return
			if not await _wait_tutorial_step(step_index + 1):
				return
	if is_instance_valid(main.session) or progress.has_seen_tutorial(TARGET_GAME_ID):
		await _review_fail("Reading the lesson unexpectedly launched a session or marked the first-visit tutorial seen")
		return
	var elapsed_msec := Time.get_ticks_msec() - _started_msec
	_finishing = true
	print("PASS: real Main/E/Start first-visit game-010 tutorial, three native page-button clicks, 1280x720 mapped textures and captures; no session started; elapsed_ms=%d" % elapsed_msec)
	await main._quit_game()

func _open_first_bubble_tutorial() -> bool:
	if progress.has_seen_tutorial(TARGET_GAME_ID):
		await _review_fail("Isolated profile unexpectedly already saw game-010 tutorial")
		return false
	var station_found := false
	for point in main.world.points:
		if str(point.id) == TARGET_GAME_ID:
			main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
			station_found = true
			break
	if not station_found:
		await _review_fail("The real Main world is missing the game-010 station")
		return false
	var nearest_deadline := Time.get_ticks_msec() + 5000
	while str(main.world.nearest.get("id", "")) != TARGET_GAME_ID and Time.get_ticks_msec() < nearest_deadline:
		await get_tree().physics_frame
	if str(main.world.nearest.get("id", "")) != TARGET_GAME_ID:
		await _review_fail("Game-010 was not the active nearby station")
		return false
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "native E opening game-010 station details"):
		return false
	if not await _activate_main_button("開始遊玩", "open the first-visit game-010 tutorial"):
		return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel) and main.tutorial_panel.visible, "first-visit game-010 tutorial"):
		return false
	if is_instance_valid(main.session) or main.tutorial_panel.target_id != TARGET_GAME_ID or main.tutorial_panel.current_step != 0 or progress.has_seen_tutorial(TARGET_GAME_ID):
		await _review_fail("Main did not show the unseen game-010 first page before creating a session")
		return false
	return true

func _wait_tutorial_step(step_index: int) -> bool:
	return await _wait_until(
		func() -> bool:
			return is_instance_valid(main.tutorial_panel) and main.tutorial_panel.visible and main.tutorial_panel.target_id == TARGET_GAME_ID and main.tutorial_panel.current_step == step_index,
		"native game-010 tutorial page %d" % (step_index + 1)
	)

func _capture_step(step_index: int) -> bool:
	var panel: Control = main.tutorial_panel
	if not is_instance_valid(panel) or not panel.visible or panel.target_id != TARGET_GAME_ID or panel.current_step != step_index:
		await _review_fail("Main tutorial did not display game-010 page %d" % (step_index + 1))
		return false
	if panel.get_viewport().get_visible_rect().size != Vector2(1280.0, 720.0):
		await _review_fail("Tutorial review viewport must be 1280x720; got %s" % str(panel.get_viewport().get_visible_rect().size))
		return false
	var data: Dictionary = panel.current_step_data()
	var expected_path := EXPECTED_IMAGES[step_index]
	if str(data.get("image", "")) != expected_path:
		await _review_fail("Game-010 page %d points to unexpected tutorial image: %s" % [step_index + 1, str(data.get("image", ""))])
		return false
	var texture_rect := panel.get("_image") as TextureRect
	if texture_rect == null or not texture_rect.visible or texture_rect.texture == null or texture_rect.texture.resource_path != expected_path:
		await _review_fail("Game-010 page %d does not display its mapped lesson Texture" % (step_index + 1))
		return false
	if texture_rect.texture.get_width() != 1280 or texture_rect.texture.get_height() != 720:
		await _review_fail("Game-010 lesson page %d Texture is not 1280x720" % (step_index + 1))
		return false
	var source_image := Image.load_from_file(ProjectSettings.globalize_path(expected_path))
	if source_image.is_empty() or source_image.get_width() != 1280 or source_image.get_height() != 720:
		await _review_fail("Game-010 lesson image file is missing or not 1280x720: " + expected_path)
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(REVIEW_IMAGES[step_index]):
		await _review_fail("Could not capture native game-010 tutorial page %d" % (step_index + 1))
		return false
	var captured_image := Image.load_from_file(ProjectSettings.globalize_path("res://" + REVIEW_IMAGES[step_index]))
	if captured_image.is_empty() or captured_image.get_width() != 1280 or captured_image.get_height() != 720:
		await _review_fail("Native game-010 lesson evidence page %d is not 1280x720" % (step_index + 1))
		return false
	return true

func _review_fail(message: String) -> void:
	if _finishing:
		return
	_finishing = true
	push_error(message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
