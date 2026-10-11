extends "res://game/tests/native_layout_review.gd"

const Daylight = preload("res://game/core/time_of_day.gd")

## Native panel/input and rendered-background review. Station/hero placement is
## an explicit fixture; these captures do not claim twelve completed playthroughs.
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native daylight review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	main.world.player.position = Vector3(0, 0.4, -6)
	main.world.player.velocity = Vector3.ZERO
	main.world.camera.size = 11.0
	await get_tree().create_timer(0.5).timeout
	if not await _open_time(): return
	if main.time_panel.collect_button != null:
		await _fail("Time postcards became collectible away from the guide station")
		return
	for phase_id in Daylight.phase_ids():
		if not await _choose_phase(phase_id): return
		if not await _save_view("pm/Snapland-main/images/MAIN-9-time-%s.png" % phase_id): return
		await _tap_key(KEY_ESCAPE)
		if not await _save_view("pm/Snapland-art/images/ART-13-world-%s.png" % phase_id): return
		if not await _open_time(): return
	await _tap_key(KEY_ESCAPE)
	if not await _review_postcards(): return
	for game_index in range(1, 13):
		if not await _review_game_phases(game_index): return
	print("PASS: native four-phase panel, location-gated postcards, saved reload, paused session, and 48 rendered game backgrounds. Hero/station positions are fixtures, not walking or completed-game evidence.")
	await main._quit_game()

func _open_time() -> bool:
	await _tap_key(KEY_T)
	var deadline := Time.get_ticks_msec() + 2000
	while main.modal_kind != "time" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.modal_kind != "time":
		await _fail("Actual T input did not open the time panel; modal=%s session=%s" % [main.modal_kind, main.session != null])
		return false
	await _frames(2)
	return true

func _choose_phase(phase_id: String) -> bool:
	var button := main.overlay.find_child("TimePhase_%s" % phase_id, true, false) as Button
	if button == null or not _control_fits_viewport(button):
		await _fail("Time phase button is missing/offscreen: " + phase_id)
		return false
	if str(progress.settings.get("time_phase", "")) != phase_id:
		if button.disabled:
			await _fail("Unselected phase button is disabled: " + phase_id)
			return false
		await _click_control(button)
	await _frames(2)
	var profile: Dictionary = Daylight.phase_for_id(phase_id)
	var light_ray: Vector3 = -main.world.sun.global_basis.z
	if str(progress.settings.get("time_phase", "")) != phase_id or main.world.active_time_phase != phase_id or main.time_panel.current_phase != phase_id or light_ray.y >= 0.0:
		await _fail("Phase button did not apply a downward key light: phase=%s setting=%s world=%s panel=%s ray=%s" % [phase_id, progress.settings.get("time_phase", ""), main.world.active_time_phase, main.time_panel.current_phase, light_ray])
		return false
	if not is_equal_approx(main.world.sun.light_energy, float(profile.key_energy)) or main.world.environment.background_color != profile.sky_color:
		await _fail("World light/sky does not match phase profile: " + phase_id)
		return false
	if main.session != null and main.session.time_phase != phase_id:
		await _fail("Actual phase button did not update the active session: " + phase_id)
		return false
	print("DAYLIGHT PHASE: ", phase_id, " ray=", light_ray, " session=", main.session != null)
	return true

func _place_station(point_id: String) -> bool:
	var found := false
	for point in main.world.points:
		if str(point.id) != point_id: continue
		main.world.player.position = point.position + Vector3(0, 0.3, 0)
		main.world.player.velocity = Vector3.ZERO
		found = true
		break
	if not found:
		await _fail("Native daylight fixture station is missing: " + point_id)
		return false
	var deadline := Time.get_ticks_msec() + 2000
	while str(main.world.nearest.get("id", "")) != point_id and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if str(main.world.nearest.get("id", "")) != point_id:
		await _fail("Placed fixture did not become nearest station: " + point_id)
		return false
	return true

func _review_postcards() -> bool:
	if not await _place_station("guide"): return false
	if not await _open_time(): return false
	var original_coins: int = progress.coins
	var original_count: int = progress.normal_count()
	for phase_id in Daylight.phase_ids():
		if not await _choose_phase(phase_id): return false
		var collect := main.time_panel.collect_button as Button
		var card_id: String = Daylight.postcard_id(phase_id)
		if collect == null or collect.disabled or not _control_fits_viewport(collect):
			await _fail("Uncollected phase postcard is unavailable at guide: " + phase_id)
			return false
		var before: int = progress.coins
		await _click_control(collect)
		for _frame in range(60):
			if progress.photos.has(card_id) and collect.disabled: break
			await get_tree().process_frame
		if not progress.photos.has(card_id) or progress.coins != before + 20 or progress.normal_count() != original_count or not collect.disabled:
			await _fail("Postcard did not grant exactly +20 once without regular progress: " + phase_id)
			return false
		var metadata: Dictionary = progress.photos.get(card_id, {})
		var frames: Variant = metadata.get("frames", [])
		if metadata.get("time_phase", "") != phase_id or not frames is Array or frames.is_empty():
			await _fail("Actual postcard capture metadata is missing phase/PNG frames: " + str(metadata))
			return false
		for frame_path: Variant in frames:
			if not frame_path is String or not FileAccess.file_exists(frame_path):
				await _fail("Postcard metadata references missing PNG: " + str(frame_path))
				return false
			var image := Image.load_from_file(frame_path)
			var thumbnail: Texture2D = main._photo_texture(frame_path)
			if image == null or image.is_empty() or image.get_width() < 320 or image.get_height() < 180 or image.get_width() * 9 != image.get_height() * 16 or thumbnail == null or thumbnail.get_size() != Vector2(320, 180) or thumbnail.get_image().is_empty():
				await _fail("Actual postcard PNG/thumbnail is unreadable: " + frame_path)
				return false
		await _click_control(collect)
		if progress.coins != before + 20:
			await _fail("Repeated disabled postcard click granted coins: " + phase_id)
			return false
		if not await _save_view("pm/Snapland-main/images/MAIN-9-postcard-%s.png" % phase_id): return false
	if progress.coins != original_coins + 80 or not progress.achievements.has(Daylight.ACHIEVEMENT_ALL_POSTCARDS):
		await _fail("Four postcards did not grant the complete set achievement/+80 total")
		return false
	var saved_photos: Dictionary = progress.photos.duplicate(true)
	var saved_coins: int = progress.coins
	if not progress.save_progress():
		await _fail("Daylight review could not persist isolated progress")
		return false
	progress.load_progress()
	if progress.photos != saved_photos or progress.coins != saved_coins or progress.normal_count() != original_count or not progress.achievements.has(Daylight.ACHIEVEMENT_ALL_POSTCARDS) or progress.settings.get("time_phase", "") != "night":
		await _fail("Postcards/coins/achievement/current phase did not survive actual save reload")
		return false
	await _tap_key(KEY_ESCAPE)
	if not await _review_postcard_album(): return false
	return true

func _review_postcard_album() -> bool:
	var album_button := _find_text_button(main.hud, "拍貼本")
	if album_button == null or not _control_fits_viewport(album_button):
		await _fail("Actual postcard album HUD button is missing/offscreen")
		return false
	await _click_control(album_button)
	await _frames(3)
	if main.modal_kind != "album":
		await _fail("Actual HUD click did not open the postcard album")
		return false
	var time_grid := main.overlay.find_child("TimePostcardGrid", true, false) as GridContainer
	if time_grid == null or not time_grid.get_parent().get_parent() is ScrollContainer:
		await _fail("Postcard album section is not inside the collection scroll")
		return false
	var collection_scroll := time_grid.get_parent().get_parent() as ScrollContainer
	collection_scroll.ensure_control_visible(time_grid)
	await _frames(3)
	if not await _check_modal_layout("postcard album"): return false
	var rendered: Dictionary = {}
	_collect_photo_thumbnail_pixels(main.overlay, rendered)
	for phase_id in Daylight.phase_ids():
		var metadata: Dictionary = progress.photos.get(Daylight.postcard_id(phase_id), {})
		var paths: Array = metadata.get("frames", [])
		var expected: Texture2D = main._photo_texture(str(paths[0])) if not paths.is_empty() else null
		if expected == null or not rendered.has(Marshalls.raw_to_base64(expected.get_image().get_data())):
			await _fail("Actual album does not display the saved postcard thumbnail: " + phase_id)
			return false
	if not await _save_view("pm/Snapland-main/images/MAIN-9-album-postcards.png"): return false
	await _tap_key(KEY_ESCAPE)
	return true

func _collect_photo_thumbnail_pixels(node: Node, output: Dictionary) -> void:
	if node is TextureRect and node.texture != null and node.texture.get_size() == Vector2(320, 180):
		var image: Image = node.texture.get_image()
		if image != null and not image.is_empty():
			image.convert(Image.FORMAT_RGBA8)
			output[Marshalls.raw_to_base64(image.get_data())] = true
	for child in node.get_children(): _collect_photo_thumbnail_pixels(child, output)

func _review_game_phases(game_index: int) -> bool:
	var game_id := "game-%03d" % game_index
	if not await _place_station(game_id): return false
	await _tap_key(KEY_E)
	var deadline := Time.get_ticks_msec() + 2000
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.modal_kind != "game_info":
		await _fail("Actual E did not open game station: " + game_id)
		return false
	# The modal can be marked open before its queued container layout completes.
	await _frames(4)
	var start_button := _find_text_button(main.overlay, "開始遊玩")
	if start_button == null or not _control_fits_viewport(start_button):
		await _fail("Game Start button missing/offscreen: " + game_id)
		return false
	start_button.grab_focus()
	await _frames(2)
	var start_presses: Array[bool] = []
	start_button.pressed.connect(func(): start_presses.append(true), CONNECT_ONE_SHOT)
	await _click_control(start_button)
	deadline = Time.get_ticks_msec() + 2000
	while main.session == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.session == null or main.session.game_id != game_id:
		await _fail("Actual Start button did not launch requested game: %s pressed=%s rect=%s mouse=%s transform=%s modal=%s focus=%s" % [game_id, not start_presses.is_empty(), start_button.get_global_rect(), main.get_viewport().get_mouse_position(), main.get_viewport().get_final_transform(), main.modal_kind, main.get_viewport().gui_get_focus_owner()])
		return false
	if game_index == 1:
		await _tap_key(KEY_ENTER)
		await get_tree().create_timer(0.1).timeout
		if not main.session.balloon_started or main.session.elapsed <= 0.0:
			await _fail("Actual Enter did not start the balloon delivery clock")
			return false
	for phase_id in Daylight.phase_ids():
		if not await _open_time(): return false
		var frozen_elapsed: float = main.session.elapsed
		var frozen_position: Vector2 = main.session.p
		await get_tree().create_timer(0.12).timeout
		if main.session.elapsed != frozen_elapsed or main.session.p != frozen_position or main.session.process_mode != Node.PROCESS_MODE_DISABLED:
			await _fail("T panel did not freeze the active game: " + game_id)
			return false
		if main.time_panel.collect_button != null:
			await _fail("Time postcards became collectible during a game")
			return false
		if not await _choose_phase(phase_id): return false
		await _tap_key(KEY_ESCAPE)
		if main.modal_kind != "" or main.session == null or main.session.process_mode == Node.PROCESS_MODE_DISABLED:
			await _fail("Escape did not resume the same game session: " + game_id)
			return false
		if not await _save_view("pm/Snapland-art/images/ART-13-game%02d-%s.png" % [game_index, phase_id]): return false
		if game_index == 1:
			await get_tree().create_timer(0.1).timeout
			if main.session.elapsed <= frozen_elapsed:
				await _fail("Balloon delivery timer did not resume after time panel Escape")
				return false
	# Escape follows the real session cancellation path; no completion is asserted.
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.session != null or main.modal_kind != "":
		await _fail("Escape did not return from background fixture to park: " + game_id)
		return false
	return true

func _save_view(path: String) -> bool:
	await _frames(2)
	await RenderingServer.frame_post_draw
	if not main._capture(path):
		await _fail("Could not save daylight evidence: " + path)
		return false
	return true
