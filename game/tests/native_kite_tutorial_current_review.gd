extends "res://game/tests/native_fountain_review.gd"

## First-visit tutorial review for the current SG-17 candidate. This fixture
## uses the real Main, station interaction, tutorial controls, and screenshots.
const TARGET_GAME_ID := "game-002"
const REVIEW_DIR := ".review/kite-current-tutorial"
const EXPECTED_IMAGES := [
	"res://assets/ui/tutorials/game-002-step-01.png",
	"res://assets/ui/tutorials/game-002-step-02.png",
	"res://assets/ui/tutorials/game-002-step-03.png",
]
const REVIEW_IMAGES := [
	REVIEW_DIR + "/tutorial-step-01.png",
	REVIEW_DIR + "/tutorial-step-02.png",
	REVIEW_DIR + "/tutorial-step-03.png",
]

var _started_msec := 0

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		await _review_fail("Native Kite tutorial review requires a GPU window and isolated SNAPLAND_SAVE_PATH")
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
	if not await _open_first_kite_tutorial():
		return
	for step_index in range(3):
		if not await _capture_step(step_index):
			return
		if step_index < 2:
			var next_button := _find(main.tutorial_panel, "下一步") as Button
			if next_button == null:
				await _review_fail("Tutorial page %d has no real next-page button" % (step_index + 1))
				return
			if not await _native_click_button(next_button, "advance to game-002 tutorial page %d" % (step_index + 2)):
				return
			if not await _wait_until(func() -> bool: return main.tutorial_panel.current_step == step_index + 1, "native tutorial page advance"):
				return
	var elapsed_msec := Time.get_ticks_msec() - _started_msec
	if elapsed_msec < 5000:
		await get_tree().create_timer(float(5000 - elapsed_msec) / 1000.0).timeout
		elapsed_msec = Time.get_ticks_msec() - _started_msec
	if elapsed_msec > 20000:
		await _review_fail("Native tutorial review duration was outside 5–20 seconds: %d ms" % elapsed_msec)
		return
	print("PASS: current SG-17 first-visit Main tutorial, native E and page clicks, game-002 Texture mapping and three 1280x720 lesson screenshots; elapsed_ms=%d" % elapsed_msec)
	await main._quit_game()

func _open_first_kite_tutorial() -> bool:
	if progress.has_seen_tutorial(TARGET_GAME_ID):
		await _review_fail("Isolated profile unexpectedly already saw game-002 tutorial")
		return false
	var station_found := false
	for point in main.world.points:
		if str(point.id) == TARGET_GAME_ID:
			main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
			station_found = true
			break
	if not station_found:
		await _review_fail("The real Main world is missing game-002 station")
		return false
	var nearest_deadline := _wall_deadline_ms(3000)
	while str(main.world.nearest.get("id", "")) != TARGET_GAME_ID and Time.get_ticks_msec() < nearest_deadline:
		await get_tree().physics_frame
	if str(main.world.nearest.get("id", "")) != TARGET_GAME_ID:
		await _review_fail("game-002 was not the active nearby station")
		return false
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "native E opening game-002 station details"):
		return false
	if not await _activate_main_button("開始遊玩", "open the first-visit game-002 tutorial"):
		return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel) and main.tutorial_panel.visible, "first-visit game-002 tutorial"):
		return false
	if main.session != null or main.tutorial_panel.target_id != TARGET_GAME_ID or progress.has_seen_tutorial(TARGET_GAME_ID):
		await _review_fail("Main did not show the unseen game-002 lesson before creating a session")
		return false
	return true

func _capture_step(step_index: int) -> bool:
	var panel: Control = main.tutorial_panel
	if not is_instance_valid(panel) or not panel.visible or panel.target_id != TARGET_GAME_ID or panel.current_step != step_index:
		await _review_fail("Main tutorial did not display game-002 page %d" % (step_index + 1))
		return false
	var data: Dictionary = panel.current_step_data()
	var expected_path: String = EXPECTED_IMAGES[step_index]
	if str(data.get("image", "")) != expected_path:
		await _review_fail("game-002 page %d points to unexpected lesson texture: %s" % [step_index + 1, str(data.get("image", ""))])
		return false
	var texture_rect := panel.get("_image") as TextureRect
	if texture_rect == null or not texture_rect.visible or texture_rect.texture == null or texture_rect.texture.resource_path != expected_path:
		await _review_fail("game-002 page %d does not display its mapped lesson Texture" % (step_index + 1))
		return false
	if texture_rect.texture.get_width() != 1280 or texture_rect.texture.get_height() != 720:
		await _review_fail("game-002 lesson page %d texture is not 1280x720" % (step_index + 1))
		return false
	var source_image := Image.load_from_file(ProjectSettings.globalize_path(expected_path))
	if source_image.is_empty() or source_image.get_width() != 1280 or source_image.get_height() != 720:
		await _review_fail("Current game-002 lesson image file is missing or not 1280x720: " + expected_path)
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(REVIEW_IMAGES[step_index]):
		await _review_fail("Could not save native tutorial page %d screenshot" % (step_index + 1))
		return false
	var captured_image := Image.load_from_file(ProjectSettings.globalize_path("res://" + REVIEW_IMAGES[step_index]))
	if captured_image.is_empty() or captured_image.get_width() != 1280 or captured_image.get_height() != 720:
		await _review_fail("Native tutorial evidence page %d is not 1280x720" % (step_index + 1))
		return false
	return true

func _review_fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
