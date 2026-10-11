extends "res://game/tests/native_layout_review.gd"

const Daylight := preload("res://game/core/time_of_day.gd")
const SessionScript := preload("res://game/minigames/session.gd")
const IMAGE_DIR := "pm/Snapland-art/images"
const GAME_ART := [
	{"scene": "harbor", "prop": "balloon"},
	{"scene": "harbor", "prop": "kite"},
	{"scene": "garden", "prop": "visitor"},
	{"scene": "stage", "prop": "tourist_coral"},
	{"scene": "stage", "prop": "tourist_coral"},
	{"scene": "stage", "prop": "tourist_green"},
	{"scene": "garden", "prop": "pipes"},
	{"scene": "harbor", "prop": "sign"},
	{"scene": "night", "prop": "mascot"},
	{"scene": "night", "prop": "camera"},
	{"scene": "garden", "prop": "bench"},
	{"scene": "night", "prop": "flower_horn"},
]

var _phase_capture_count := 0
var _noon_capture_count := 0

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native background revision review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Background review has no Progress autoload")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["reduced_motion"] = false
	# Begin on dusk so the actual phase buttons must exercise all four transitions.
	progress.set_time_phase("dusk")
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	if main.world == null or main.world.points.is_empty():
		await _fail("Live park/station setup is unavailable")
		return
	var definitions := SessionScript.definitions()
	if definitions.size() != 12:
		await _fail("Expected twelve canonical mini-game definitions, got %d" % definitions.size())
		return
	for game_index in range(1, 13):
		if not await _review_game(game_index): return
	if not await _review_reduced_motion(): return
	if _phase_capture_count != 48 or _noon_capture_count != 12:
		await _fail("Background capture matrix incomplete: phases=%d noon=%d" % [_phase_capture_count, _noon_capture_count])
		return
	print("PASS: 12 live mini-games × 4 actual time-panel phases; 48 ART-19 captures including 12 noon views; representative per-game prop/fixture and reduced-motion toggle checked. This is not a gameplay-completion or subjective art-quality verdict.")
	await main._quit_game()

func _review_game(game_index: int) -> bool:
	var game_id := "game-%03d" % game_index
	if not await _place_station(game_id): return false
	await _tap_key(KEY_E)
	if not await _wait_for_modal("game_info", game_id): return false
	await _frames(4)
	var start_button := _find_text_button(main.overlay, "開始遊玩")
	if start_button == null or not _control_fits_viewport(start_button):
		await _fail("Game Start button is missing/offscreen: " + game_id)
		return false
	start_button.grab_focus()
	await _frames(2)
	var start_presses: Array[bool] = []
	start_button.pressed.connect(func(): start_presses.append(true), CONNECT_ONE_SHOT)
	await _click_control(start_button)
	var deadline := Time.get_ticks_msec() + 2500
	while main.session == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.session == null or main.session.game_id != game_id:
		await _fail("Actual station Start click did not launch %s: pressed=%s rect=%s mouse=%s transform=%s modal=%s focus=%s" % [game_id, not start_presses.is_empty(), start_button.get_global_rect(), main.get_viewport().get_mouse_position(), main.get_viewport().get_final_transform(), main.modal_kind, main.get_viewport().gui_get_focus_owner()])
		return false
	await _frames(3)
	await RenderingServer.frame_post_draw
	var art: Dictionary = GAME_ART[game_index - 1]
	var cache: Dictionary = main.session.art_cache_status()
	if not bool(cache.get("backdrop_atlas_loaded", false)) or not (cache.get("backdrops_loaded", []) as Array).has(str(art.scene)):
		await _fail("Live session did not render its expected %s background for %s: %s" % [art.scene, game_id, str(cache)])
		return false
	if str(art.prop) == "pipes":
		if main.session.flower_cells.size() != 16:
			await _fail("Flower-pipe mini-game did not initialize its visible 4×4 object field")
			return false
	else:
		if not (cache.get("props_loaded", []) as Array).has(str(art.prop)):
			await _fail("Live session lacks expected representative rendered prop '%s' for %s: %s" % [art.prop, game_id, str(cache)])
			return false
	for phase_id in Daylight.phase_ids():
		if not await _open_time_panel(): return false
		if not await _select_phase(phase_id): return false
		await _tap_key(KEY_ESCAPE)
		if main.modal_kind != "" or main.session == null or main.session.time_phase != phase_id:
			await _fail("Time-panel selection did not resume %s at %s" % [game_id, phase_id])
			return false
		if not await _capture_game(game_index, phase_id): return false
	if not await _exit_session(game_id): return false
	return true

func _place_station(point_id: String) -> bool:
	for point in main.world.points:
		if str(point.id) != point_id: continue
		main.world.player.position = point.position + Vector3(0, 0.3, 0)
		main.world.player.velocity = Vector3.ZERO
		var deadline := Time.get_ticks_msec() + 2500
		while str(main.world.nearest.get("id", "")) != point_id and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		if str(main.world.nearest.get("id", "")) == point_id: return true
		await _fail("Fixture placement did not reach mini-game station: " + point_id)
		return false
	await _fail("Live park is missing expected game station: " + point_id)
	return false

func _open_time_panel() -> bool:
	await _tap_key(KEY_T)
	if not await _wait_for_modal("time", "time phase control"): return false
	if main.time_panel.collect_button != null:
		await _fail("Time postcard collection became available inside a mini-game")
		return false
	return true

func _select_phase(phase_id: String) -> bool:
	var button := main.overlay.find_child("TimePhase_%s" % phase_id, true, false) as Button
	if button == null or not _control_fits_viewport(button):
		await _fail("Time panel phase button missing/offscreen: " + phase_id)
		return false
	if main.time_panel.current_phase != phase_id:
		if button.disabled:
			await _fail("Unselected time phase button is unexpectedly disabled: " + phase_id)
			return false
		await _click_control(button)
	await _frames(2)
	if str(progress.settings.get("time_phase", "")) != phase_id or main.time_panel.current_phase != phase_id or main.world.active_time_phase != phase_id or main.session.time_phase != phase_id:
		await _fail("Actual phase button failed to update park and live session: " + phase_id)
		return false
	return true

func _capture_game(game_index: int, phase_id: String) -> bool:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var path := "%s/ART-19-game-%02d-%s.png" % [IMAGE_DIR, game_index, phase_id]
	if not main._capture(path):
		await _fail("Could not save live background review screenshot: " + path)
		return false
	_phase_capture_count += 1
	if phase_id == "noon": _noon_capture_count += 1
	return true

func _exit_session(game_id: String) -> bool:
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.session != null or main.modal_kind != "":
		await _fail("Escape did not cancel the background fixture session: " + game_id)
		return false
	return true

func _review_reduced_motion() -> bool:
	var settings_button := _find_text_button(main.hud, "設定")
	if settings_button == null or not _control_fits_viewport(settings_button):
		await _fail("Settings HUD button missing/offscreen for reduced-motion control")
		return false
	await _click_control(settings_button)
	await _frames(3)
	if main.modal_kind != "settings":
		await _fail("Actual settings HUD click did not open settings")
		return false
	var toggle: CheckButton
	for node in _find_controls(main.overlay, CheckButton):
		var candidate := node as CheckButton
		if candidate.text.begins_with("降低背景動態"):
			toggle = candidate
			break
	if toggle == null:
		await _fail("Reduced-motion CheckButton is missing")
		return false
	var parent := toggle.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(toggle)
			break
		parent = parent.get_parent()
	await _frames(2)
	if not _control_fits_viewport(toggle):
		await _fail("Reduced-motion CheckButton remains offscreen after scrolling")
		return false
	if toggle.button_pressed:
		await _fail("Reduced-motion fixture expected its initial state to be off")
		return false
	await _click_control(toggle)
	await _frames(2)
	if not toggle.button_pressed or not bool(progress.settings.get("reduced_motion", false)):
		await _fail("Actual reduced-motion toggle did not persist its enabled state")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture("%s/ART-19-reduced-motion-on.png" % IMAGE_DIR):
		await _fail("Could not capture reduced-motion setting state")
		return false
	await _click_control(toggle)
	await _frames(2)
	if toggle.button_pressed or bool(progress.settings.get("reduced_motion", true)):
		await _fail("Actual reduced-motion toggle did not restore its disabled state")
		return false
	await _tap_key(KEY_ESCAPE)
	return true

func _find_controls(root: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	if is_instance_of(root, type): found.append(root)
	for child in root.get_children(): found.append_array(_find_controls(child, type))
	return found

func _wait_for_modal(kind: String, context: String) -> bool:
	var deadline := Time.get_ticks_msec() + 2500
	while main.modal_kind != kind and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.modal_kind == kind: return true
	await _fail("Expected %s modal for %s; got %s" % [kind, context, main.modal_kind])
	return false

func _find_text_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text.contains(text): return root as Button
	for child in root.get_children():
		var found := _find_text_button(child, text)
		if found != null: return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
