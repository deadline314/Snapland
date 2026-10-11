extends "res://game/tests/native_review.gd"

var _normal_result: Dictionary = {}
var _normal_grades: Array = []
var _normal_mistakes := -1

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

## Human-facing GPU review fixture. Inputs are native key/click events; the
## fixture never assigns score, grade, attempt, or completion fields directly.
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native fountain review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _launch_fountain(false): return
	var active_session: Control = main.session
	active_session.finished.connect(_capture_normal_result.bind(active_session), CONNECT_ONE_SHOT)
	if not await _capture_standard_timing_review(): return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result"): return
	if int(_normal_result.get("score", -1)) != 500 or _normal_grades != ["準確", "完美", "錯過"] or _normal_mistakes != 1:
		await _fail("Native timing evidence differs from actual two-hit/one-miss play: score=%s grades=%s mistakes=%d" % [str(_normal_result.get("score", -1)), str(_normal_grades), _normal_mistakes])
		return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-result-500.png"):
		await _fail("Could not capture naturally reached fountain score summary")
		return
	if progress.photos.has("photo-welcome-game-3") or progress.photos.has("photo-welcome-devil-3"):
		await _fail("Incomplete native review unexpectedly awarded a collection photo")
		return
	if not await _activate_main_button("返回遊園", "return to park from the 500-point result"):
		return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "500-point result returns to park"):
		return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _launch_fountain(true): return
	if not await _capture_assist_reduced_review(): return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result"): return
	if progress.normal_count() != 0 or progress.devil_count("welcome") != 0:
		await _fail("Incomplete assisted review unexpectedly awarded fountain photos")
		return
	if not await _activate_main_button("返回遊園", "return to park from the assisted result"):
		return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == ""): return
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	if not await _launch_fountain(false): return
	_normal_result.clear()
	_normal_grades.clear()
	_normal_mistakes = -1
	active_session = main.session
	active_session.finished.connect(_capture_normal_result.bind(active_session), CONNECT_ONE_SHOT)
	if not await _play_clean_devil_round(): return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result"): return
	if int(_normal_result.get("score", -1)) != 900 or _normal_grades != ["完美", "完美", "完美"] or _normal_mistakes != 0:
		await _fail("Three real perfect inputs did not produce the expected 900-point result: score=%s grades=%s mistakes=%d" % [str(_normal_result.get("score", -1)), str(_normal_grades), _normal_mistakes])
		return
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has("photo-welcome-game-3") or not progress.photos.has("photo-welcome-devil-3") or not progress.achievements.has("ACH_GAME_003"):
		await _fail("Three perfect actual inputs did not persist exactly one ordinary/devil result and ACH_GAME_003")
		return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-earned-result-900.png"):
		await _fail("Could not capture the naturally earned 900-point result")
		return
	if not await _capture_earned_album_and_achievement(): return
	print("PASS: real Space/click timing, misses, assist/reduced-motion and a separate three-perfect 900-point devil clear; photos and achievement verified in live album UI")
	await main._quit_game()

func _launch_fountain(assisted_run: bool) -> bool:
	var found := false
	for point in main.world.points:
		if point.id != "game-003": continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		await _fail("Fountain station game-003 is missing from the real park")
		return false
	var deadline := _wall_deadline_ms(3000)
	while main.world.nearest.get("id", "") != "game-003" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if main.world.nearest.get("id", "") != "game-003":
		await _fail("Fountain station did not become the nearest interaction")
		return false
	_key(KEY_E)
	deadline = _wall_deadline_ms(2500)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.modal_kind != "game_info":
		await _fail("Native E input did not open fountain station details")
		return false
	if not await _activate_main_button("開始遊玩", "start fountain timing"):
		return false
	deadline = _wall_deadline_ms(2500)
	while main.session == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.session == null or main.session.game_id != "game-003":
		await _fail("Native Start click did not launch fountain timing")
		return false
	var session: Control = main.session
	if session.assisted != assisted_run or session.reduced_motion != assisted_run:
		await _fail("Fountain fixture settings mismatch: assist=%s reduced=%s" % [session.assisted, session.reduced_motion])
		return false
	return true

func _capture_standard_timing_review() -> bool:
	var session: Control = main.session
	if not await _wait_until(func() -> bool: return session.phase >= 0.15): return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-initial-count-in.png"):
		await _fail("Could not capture fountain count-in")
		return false
	if not await _wait_until(func() -> bool: return session.phase >= session.FOUNTAIN_FIRST_BEAT - 0.30): return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-pre-cue.png"):
		await _fail("Could not capture fountain pre-cue")
		return false
	if not await _wait_until(func() -> bool: return session.phase >= session._fountain_beat_time(0) + 0.12): return false
	_key(KEY_SPACE)
	await _frames(2)
	if session.fountain_grades.size() != 1 or session.fountain_grades[0] != "準確" or session.score != 200:
		await _fail("Actual Space input did not land in the accurate band: grades=%s score=%d phase=%.3f" % [str(session.fountain_grades), session.score, session.phase])
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-space-accurate.png"):
		await _fail("Could not capture the real Space timing feedback")
		return false
	if not await _wait_until(func() -> bool: return session.phase >= session._fountain_beat_time(1)): return false
	_click(Vector2(640.0, 650.0))
	await _frames(2)
	if session.fountain_grades.size() != 2 or session.fountain_grades[1] != "完美" or session.score != 500:
		await _fail("Actual mouse click did not land the perfect second jump: grades=%s score=%d phase=%.3f" % [str(session.fountain_grades), session.score, session.phase])
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-click-perfect.png"):
		await _fail("Could not capture the real click timing feedback")
		return false
	# Leave the third opportunity untouched so the runtime deadline records the
	# miss. This exposes the true zero-point result, not a forced fixture grade.
	return await _wait_until(func() -> bool: return not _normal_result.is_empty())

func _capture_normal_result(result: Dictionary, completed_session: Control) -> void:
	# Capture value snapshots during the emitted signal, before the real main
	# scene defers freeing its completed session node.
	_normal_result = result.duplicate(true)
	_normal_grades = completed_session.fountain_grades.duplicate()
	_normal_mistakes = completed_session.mistakes

func _capture_assist_reduced_review() -> bool:
	var session: Control = main.session
	if not await _wait_until(func() -> bool: return session.phase >= 0.15): return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-assist-reduced-initial.png"):
		await _fail("Could not capture assisted/reduced-motion initial state")
		return false
	if not await _wait_until(func() -> bool: return session.phase >= session.FOUNTAIN_FIRST_BEAT + 0.20): return false
	_key(KEY_SPACE)
	await _frames(2)
	if session.fountain_grades.size() != 1 or session.fountain_grades[0] != "準確" or session.score != 200:
		await _fail("Assisted actual Space input did not use the widened accurate band: grades=%s score=%d" % [str(session.fountain_grades), session.score])
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-assist-reduced-space.png"):
		await _fail("Could not capture assisted/reduced-motion input feedback")
		return false
	return true

func _play_clean_devil_round() -> bool:
	var session: Control = main.session
	for index in 3:
		var target_time: float = session._fountain_beat_time(index)
		if not await _wait_until(func() -> bool: return session.phase >= target_time): return false
		if index == 1:
			_click(Vector2(640.0, 650.0))
		else:
			_key(KEY_SPACE)
		if index < 2:
			await _frames(2)
			if session.fountain_grades.size() != index + 1 or session.fountain_grades[index] != "完美" or session.score != (index + 1) * 300:
				await _fail("Actual clean-round input %d was not perfect: grades=%s score=%d phase=%.3f" % [index + 1, str(session.fountain_grades), session.score, session.phase])
				return false
	# Third perfect input synchronously emits the real completion. Do not read the
	# completed session; the signal callback already took immutable snapshots.
	return await _wait_until(func() -> bool: return not _normal_result.is_empty())

func _capture_earned_album_and_achievement() -> bool:
	if not await _activate_main_button("返回遊園", "return to park from earned result"):
		return false
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "earned-result return-to-park transition"):
		return false
	_key(KEY_M)
	if not await _wait_until(func() -> bool: return main.modal_kind == "ticket", "M key opens the voyage pass from the park"): return false
	if not await _activate_main_button("拍貼收藏本", "open collection book from the voyage pass"):
		return false
	if not await _wait_until(func() -> bool: return main.modal_kind == "album", "collection-book button opens album"): return false
	var album_entry: Node = main.overlay.find_child("AlbumPhoto_photo-welcome-game-3", true, false)
	if album_entry == null or not album_entry.is_visible_in_tree():
		await _fail("Live album did not create the newly earned game-003 ordinary photo entry")
		return false
	if _scroll_ancestor(album_entry) == null:
		await _fail("Earned game-003 photo is not inside the album's ScrollContainer")
		return false
	if not await _scroll_control_into_view(album_entry as Control, "earned ordinary game-003 album card"):
		return false
	var photo_title: Label = album_entry.find_child("AlbumPhotoTitle", true, false) as Label
	var saved_photo_frame: Control = album_entry.find_child("SavedPhotoFrame", true, false) as Control
	var saved_thumbnail: TextureRect = saved_photo_frame.get_child(0) as TextureRect if saved_photo_frame != null and saved_photo_frame.get_child_count() > 0 else null
	if photo_title == null or photo_title.text != "噴泉跳拍" or saved_thumbnail == null or saved_thumbnail.texture == null:
		await _fail("Earned album card is visible but has no fountain title and saved photo thumbnail")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-earned-album.png"):
		await _fail("Could not capture the live album with the earned ordinary photo")
		return false
	_key(KEY_ESCAPE)
	if not await _wait_until(func() -> bool: return main.modal_kind == "", "Escape closes the album"): return false
	_key(KEY_M)
	if not await _wait_until(func() -> bool: return main.modal_kind == "ticket", "M key reopens the voyage pass from the park"): return false
	if not await _activate_main_button("遊園成就", "open achievement book from the voyage pass"):
		return false
	if not await _wait_until(func() -> bool: return main.modal_kind == "achievements", "achievement-book button opens stamp book"): return false
	var achievement_stamp: Node = main.overlay.find_child("AchievementStamp_ACH_GAME_003", true, false)
	if achievement_stamp == null or not achievement_stamp.is_visible_in_tree():
		await _fail("Live achievement book did not show the newly unlocked ACH_GAME_003 stamp")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-earned-achievement.png"):
		await _fail("Could not capture the live achievement stamp book")
		return false
	return true

func _activate_main_button(needle: String, context: String) -> bool:
	# Newly opened modal controls need layout frames before their hit rectangles
	# are stable for native pointer input.
	await _frames(3)
	var button: Button = _find(main.overlay, needle)
	if button == null:
		await _fail("Native review could not find button '%s' to %s" % [needle, context])
		return false
	if not await _scroll_control_into_view(button, "button '%s' while trying to %s" % [needle, context]):
		return false
	return await _native_click_button(button, context)

func _scroll_ancestor(node: Node) -> ScrollContainer:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null

func _scroll_control_into_view(control: Control, context: String) -> bool:
	var scrolls: Array[ScrollContainer]=[]
	var ancestor := control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: scrolls.append(ancestor as ScrollContainer)
		ancestor=ancestor.get_parent()
	for scroll in scrolls:
		scroll.ensure_control_visible(control)
	await _frames(3)
	var viewport_rect := main.get_viewport().get_visible_rect()
	for scroll in scrolls:
		var visible_rect := scroll.get_global_rect().intersection(viewport_rect)
		if not visible_rect.encloses(control.get_global_rect()):
			await _fail("Scroll reveal did not expose %s; control=%s scroll=%s" % [context,str(control.get_global_rect()),str(visible_rect)])
			return false
	if not viewport_rect.encloses(control.get_global_rect()):
		await _fail("Revealed control remains outside viewport: "+context)
		return false
	return true

func _wait_until(predicate: Callable, context: String = "actual phase/state transition") -> bool:
	var deadline := _wall_deadline_ms(8000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if not predicate.call():
		await _fail("Native fountain review timed out waiting for %s; modal_kind=%s session=%s" % [context, str(main.modal_kind), "live" if main.session != null else "none"])
		return false
	return true

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _wall_deadline_ms(simulated_milliseconds: int) -> int:
	return Time.get_ticks_msec() + ceili(float(simulated_milliseconds) / maxf(Engine.time_scale, 0.01))
