extends "res://game/tests/native_layout_review.gd"
const Paper = preload("res://game/ui/paper_ui.gd")
## UI presentation and routed keyboard/pointer input, with isolated synthetic collection data.
## Does not establish minigame success, audio listening, real-time performance or human playability.

var report := {"method":"native Main UI presentation; scripted page opening, routed Escape/Tab and pointer controls; synthetic collection/result data in isolated profile", "captures":[], "failures":[]}
var review_size := Vector2i(1280,720)
var review_scale := 1.0
var output_prefix := "pixel-ui-v1"
var review_phase := "noon"
var review_reduced_motion := false

func _run() -> void:
	var review_save := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if not review_save.is_absolute_path() or review_save.contains("://") or DisplayServer.get_name()=="headless":
		push_error("Native pixel UI review requires a GPU and absolute isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-size="):
			var parts := argument.trim_prefix("--ui-size=").split("x")
			if parts.size()==2: review_size=Vector2i(int(parts[0]),int(parts[1]))
		elif argument.begins_with("--ui-scale="): review_scale=float(argument.trim_prefix("--ui-scale="))
		elif argument.begins_with("--ui-prefix="): output_prefix=argument.trim_prefix("--ui-prefix=")
		elif argument.begins_with("--ui-phase="): review_phase=argument.trim_prefix("--ui-phase=")
		elif argument=="--ui-reduced-motion": review_reduced_motion=true
	if not output_prefix.is_valid_filename():
		push_error("Invalid pixel UI evidence prefix")
		get_tree().quit(1)
		return
	progress=get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen=true
	progress.set_setting("ui_scale",review_scale)
	if not progress.set_time_phase(review_phase):
		push_error("Requested UI review phase was rejected: "+review_phase)
		get_tree().quit(1)
		return
	progress.set_setting("reduced_motion",review_reduced_motion)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	main=_instantiate_main()
	if main==null: get_tree().quit(1); return
	get_tree().root.add_child(main)
	await _frames(8)
	if not await _resize_window(review_size): return
	report["requested_window"]=[review_size.x,review_size.y]
	report["physical_window"]=[get_window().size.x,get_window().size.y]
	report["backend_window"]=str(DisplayServer.window_get_size(get_window().get_window_id()))
	report["logical_viewport"]=str(get_viewport().get_visible_rect().size)
	report["physical_scale"]=Paper.physical_scale(main.overlay)
	report["requested_phase"]=review_phase
	report["phase"]=str(progress.settings.get("time_phase",""))
	report["world_phase"]=str(main.world.active_time_phase)
	report["reduced_motion"]=review_reduced_motion
	report["text_scale"]=review_scale
	if not await _shot("hud",23): return
	await _tap_key(KEY_ESCAPE)
	await _frames(4)
	if main.modal_kind!="pause": await _error("Escape did not open the pause menu"); return
	if not await _shot("pause",23): return
	if not await _preview_pause_button_states(): return
	await _tap_key(KEY_TAB)
	if get_viewport().gui_get_focus_owner()==null: await _error("Pause has no keyboard focus"); return
	await _tap_key(KEY_ESCAPE)
	if main.modal_kind!="": await _error("Escape did not restore the park"); return
	await _tap_key(KEY_M)
	await _frames(3)
	if main.modal_kind!="ticket": await _error("M did not open the travel navigation"); return
	if not await _shot("ticket",23): return
	main._close()
	if OS.get_cmdline_user_args().has("--ui-shell-only"):
		report["result"]="PASS"
		_save_report()
		print("PASS: native pixel shell, routed Escape/Tab and fixed controls; UI fixture only")
		main.audio.shutdown()
		get_tree().quit(0)
		return
	main._show_map()
	if not await _shot("map",24): return
	main._close()
	main._show_tasks()
	if not await _shot("tasks",24): return
	main._close()
	main._show_album()
	if not await _shot("album-empty",24): return
	main._close()
	main._show_exploration("explore-1")
	if not await _shot("exploration-photo-stage",26): return
	main._close()
	for index in [2,3]:
		main._show_exploration("explore-%d"%index)
		if not await _shot("exploration-%d"%index,26): return
		if index==3:
			for action_button in main.overlay.find_children("*","Button",true,false):
				if action_button.text.begins_with("借一個小角"):
					if not await _native_click_button(action_button,"preview the actual Xiao Jiao standee"): return
					break
			if not await _shot("exploration-3-standee",26): return
		main._close()
	await RenderingServer.frame_post_draw
	var image_path := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()+"/ui-synthetic-photo.png"
	var original_path := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()+"/ui-synthetic-photo-original.png"
	var original := get_viewport().get_texture().get_image()
	var thumbnail: Image = main._prepare_photo_thumbnail(original)
	if original.save_png(original_path)!=OK or thumbnail.save_png(image_path)!=OK:
		await _error("Cannot save isolated synthetic collection image"); return
	progress.photos["photo-welcome-game-1"]={"frames":[image_path],"original_frames":[original_path],"time_phase":review_phase}
	progress.achievements["ACH_GAME_001"]=true
	main._show_album()
	if not await _shot("album-filled",24): return
	var original_button := main.overlay.find_child("AlbumPhoto_photo-welcome-game-1",true,false) as Button
	if original_button==null or not await _native_click_button(original_button,"synthetic collected photo original viewer"): return
	await _frames(3)
	var original_viewer := main.overlay.find_child("PhotoViewer",true,false) as Control
	var original_image := original_viewer.find_child("PhotoViewerImage",true,false) as TextureRect if original_viewer!=null else null
	if original_image==null or not original_image.texture is Texture2D:
		await _error("Collected photo did not open its synthetic original image"); return
	if not await _shot("photo-original-viewer",24): return
	main._close()
	main._show_achievements()
	if not await _shot("achievements",24): return
	main._close()
	main._open_tutorial("park","ticket")
	if not await _shot("tutorial",24): return
	await _tap_key(KEY_ESCAPE)
	await _frames(3)
	if is_instance_valid(main.tutorial_panel):
		await _error("Escape did not dismiss the tutorial overlay"); return
	main._show_wardrobe()
	if not await _shot("wardrobe-appearance",25): return
	var skin := main.overlay.find_child("Appearance_skin",true,false) as OptionButton
	if skin==null or not await _native_click_button(skin,"open actual skin selection popup"): return
	await _frames(3)
	if not skin.get_popup().visible: await _error("Skin options did not open"); return
	if not await _shot("wardrobe-popup",25): return
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if skin.get_popup().visible or main.modal_kind!="wardrobe": await _error("Escape did not close only the selection popup"); return
	for category in ["closet","shop"]:
		main.wardrobe_panel._show_tab(category)
		if not await _shot("wardrobe-"+category,25): return
	main._close()
	main._show_settings()
	if not await _shot("settings-audio",25): return
	for category in ["play","controls"]:
		var button := main.overlay.find_child("SettingsTab_"+category,true,false) as Button
		if button==null or not await _click_control(button): return
		if not await _shot("settings-"+category,25): return
	main._close()
	main._show_time_panel()
	if not await _shot("time",25): return
	main._close()
	main._start_dialogue([{"speaker":"票票","text":"歡迎來到海風島！先沿著廣場散步，挑一個喜歡的設施，再慢慢收藏今天的回憶。"}],func(): pass)
	await _frames(120)
	if not await _shot("dialogue",26): return
	main._close()
	main._show_game_info("game-001")
	if not await _shot("invitation",26): return
	main._close()
	main._show_game_rules("game-001")
	if not await _shot("rules",26): return
	main._close()
	main._launch_game("game-001",false,true)
	await _frames(20)
	if main.session==null: await _error("Practice session did not start"); return
	if not await _shot("minigame-hud",26): return
	if main.session.minigame_hud==null or not main.session.minigame_hud.has_method("open_score_details"):
		await _error("Minigame session has no score details overlay"); return
	main.session.minigame_hud.open_score_details()
	if not await _shot("minigame-score-details",26): return
	main.session.minigame_hud.close_score_details()
	main.session.set_paused(true)
	if not await _shot("minigame-hud-pause",26): return
	var retry := main.session.minigame_hud.find_child("RetryButton",true,false) as Button
	if retry==null or not await _native_click_button(retry,"open retry confirmation"): return
	if not await _shot("minigame-confirmation",26): return
	var cancel_confirmation := main.session.minigame_hud.find_child("ConfirmOverlay",true,false) as Control
	if cancel_confirmation==null: await _error("Retry confirmation layer missing"); return
	cancel_confirmation.hide()
	main.session.set_paused(false)
	main._show_pause()
	if not await _shot("minigame-pause",26): return
	main._close()
	main._game_finished({"game_id":"game-001","practice":true,"success":true,"score":780,"score_summary":{"rows":[{"label":"準時送達","amount":600},{"label":"順風航行","amount":180}]}})
	if not await _shot("result-practice",26): return
	report["result"]="PASS"
	_save_report()
	print("PASS: native pixel UI presentation, routed input and fixed controls; isolated fixture, not human gameplay")
	main.audio.shutdown()
	main._close()
	# Match Main._quit_game: stop commands must reach the audio thread before scene teardown.
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	main=null
	await _frames(4)
	get_tree().quit(0)

func _preview_pause_button_states() -> bool:
	var button:=main.overlay.find_child("PauseResumeButton",true,false) as Button
	if button==null: await _error("Pause resume button is missing"); return false
	var point: Vector2=get_viewport().get_final_transform()*button.get_global_rect().get_center()
	_motion(point)
	Input.flush_buffered_events()
	if not button.is_hovered(): await _error("Pause hover state was not reached by pointer input"); return false
	if not await _shot("pause-hover",23): return false
	var press:=InputEventMouseButton.new()
	press.position=point
	press.global_position=point
	press.window_id=get_window().get_window_id()
	press.button_index=MOUSE_BUTTON_LEFT
	press.button_mask=MOUSE_BUTTON_MASK_LEFT
	press.pressed=true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	if not button.is_pressed(): await _error("Pause press state was not reached by pointer input"); return false
	if not await _shot("pause-pressed",23): return false
	press=InputEventMouseButton.new()
	press.position=point
	press.global_position=point
	press.window_id=get_window().get_window_id()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await _frames(3)
	if main.modal_kind!="": await _error("Pause release did not resume the park"); return false
	await _tap_key(KEY_ESCAPE)
	await _frames(3)
	return main.modal_kind=="pause"

func _shot(label: String, ticket: int) -> bool:
	await _frames(5)
	if str(progress.settings.get("time_phase",""))!=review_phase or str(main.world.active_time_phase)!=review_phase or bool(main.world.reduced_motion)!=review_reduced_motion:
		await _error("Actual world time/motion does not match requested review state on "+label)
		return false
	await RenderingServer.frame_post_draw
	var root_control: Control=main.overlay if main.overlay.visible else main.ui
	var path := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()+"/ART-%d-%s-%s-%dx%d-scale%.2f.png"%[ticket,output_prefix,label,review_size.x,review_size.y,review_scale]
	if get_viewport().get_texture().get_image().save_png(path)!=OK:
		await _error("Screenshot could not be saved: "+path)
		return false
	var image_size := get_viewport().get_texture().get_size()
	report.captures.append({"page":label,"path":path,"frame":Engine.get_process_frames(),"rendered_size":str(image_size),"window_size":str(get_window().size),"physical_scale":Paper.physical_scale(root_control)})
	if label=="settings-controls" and not _settings_control_rows_fit():
		await _error("All eighteen settings action/key labels must be readable in the actual content area")
		return false
	if label in ["album-empty","album-filled"] and not _album_cards_fit():
		await _error("Album cards must remain fully visible above the fixed page controls")
		return false
	if not _fixed_controls_fit(root_control):
		await _error("Fixed control bounds failed on "+label)
		return false
	if not _visible_copy_fits(root_control):
		await _error("Visible text geometry failed on "+label)
		return false
	if label=="wardrobe-popup":
		var skin: OptionButton=main.overlay.find_child("Appearance_skin",true,false)
		var popup: PopupMenu=skin.get_popup() if skin!=null else null
		if popup==null or not get_viewport().get_visible_rect().encloses(Rect2(Vector2(popup.position),Vector2(popup.size))):
			await _error("Actual wardrobe popup window exceeds viewport")
			return false
	return true

func _album_cards_fit() -> bool:
	var grid := main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
	var nav := main.overlay.find_child("AlbumPageControls",true,false) as Control
	if grid==null or nav==null: return false
	var page_bounds := nav.get_global_rect()
	for child in grid.get_children():
		var tile := child as Control
		if tile==null or not tile.is_visible_in_tree(): continue
		var bounds := tile.get_global_rect()
		if bounds.end.y>page_bounds.position.y or bounds.intersects(page_bounds):
			push_warning("Album tile overlaps navigation: %s tile=%s nav=%s"%[tile.name,bounds,page_bounds])
			return false
		var readable_inset := bounds.grow(-6.0/Paper.physical_scale(tile))
		for item in tile.find_children("*","Label",true,false):
			var copy := item as Label
			if copy.is_visible_in_tree() and not copy.text.is_empty() and not readable_inset.encloses(copy.get_global_rect()):
				push_warning("Album copy touches bevel: %s copy=%s safe=%s"%[copy.text,copy.get_global_rect(),readable_inset])
				return false
		var ancestor := tile.get_parent() as Control
		while ancestor!=null:
			if ancestor.clip_contents and not ancestor.get_global_rect().encloses(bounds): return false
			ancestor=ancestor.get_parent() as Control
	return true

func _settings_control_rows_fit() -> bool:
	var grid := main.overlay.find_child("SettingsControlRows",true,false) as GridContainer
	if grid==null or grid.get_child_count()!=18: return false
	var diagnostics: Array=[]
	for child in grid.get_children():
		var copy := child as Label
		if copy==null: continue
		diagnostics.append({"text":copy.text,"rect":str(copy.get_global_rect()),"minimum":str(copy.get_combined_minimum_size()),"visible":copy.is_visible_in_tree(),"characters":copy.visible_characters,"ratio":copy.visible_ratio,"modulate":str(copy.modulate),"self_modulate":str(copy.self_modulate),"font_color":str(copy.get_theme_color("font_color"))})
	report["settings_control_geometry"]={"grid":str(grid.get_global_rect()),"minimum":str(grid.get_combined_minimum_size()),"labels":diagnostics}
	_save_report()
	var viewport := get_viewport().get_visible_rect()
	for child in grid.get_children():
		var copy := child as Label
		if copy==null or not copy.is_visible_in_tree() or copy.text.is_empty(): return false
		var bounds := copy.get_global_rect()
		var font := copy.get_theme_font("font")
		var font_size := copy.get_theme_font_size("font_size")
		var required := font.get_string_size(copy.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		if bounds.size.x+1.0<required.x or bounds.size.y<copy.get_line_height() or copy.get_visible_line_count()<1 or not viewport.encloses(bounds):
			push_warning("Unreadable settings key: %s rect=%s required=%s grid=%s"%[copy.text,bounds,required,grid.get_global_rect()])
			return false
		var ancestor := copy.get_parent() as Control
		while ancestor!=null:
			if ancestor.clip_contents and not ancestor.get_global_rect().encloses(bounds):
				push_warning("Settings key clipped: %s rect=%s parent=%s rect=%s"%[copy.text,bounds,ancestor.name,ancestor.get_global_rect()])
				return false
			ancestor=ancestor.get_parent() as Control
	return true

func _visible_copy_fits(node: Node) -> bool:
	if node is Control and not node.is_visible_in_tree(): return true
	if node is Label and not node.text.is_empty():
		var rect: Rect2=node.get_global_rect()
		var ancestor:=node.get_parent()
		while ancestor!=null:
			if ancestor is Control and ancestor.clip_contents:
				var clip_rect: Rect2=ancestor.get_global_rect()
				if not clip_rect.intersects(rect): return true
				if not clip_rect.grow(2.0).encloses(rect):
					push_warning("Visible label clipped: %s %s clip=%s"%[node.get_path(),rect,clip_rect])
					return false
			ancestor=ancestor.get_parent()
		var line_height: float=node.get_line_height()
		if rect.size.x<2.0 or rect.size.y<line_height or node.get_visible_line_count()<node.get_line_count() or not get_viewport().get_visible_rect().grow(2.0).encloses(rect):
			push_warning("Visible label has unusable geometry: %s %s line_height=%s"%[node.get_path(),rect,line_height])
			return false
	for child in node.get_children():
		if not _visible_copy_fits(child): return false
	return true

func _fixed_controls_fit(node: Node) -> bool:
	if node is Control and not node.is_visible_in_tree(): return true
	if node is BaseButton:
		var ancestor := node.get_parent()
		var inside_scroll := false
		while ancestor!=null:
			if ancestor is ScrollContainer and ancestor.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: inside_scroll=true
			ancestor=ancestor.get_parent()
		if not inside_scroll and not get_viewport().get_visible_rect().encloses(node.get_global_rect()):
			push_warning("Fixed control outside viewport: %s %s"%[node.get_path(),node.get_global_rect()])
			return false
	for child in node.get_children():
		if not _fixed_controls_fit(child): return false
	return true

func _error(message: String) -> void:
	report.failures.append(message)
	report["result"]="FAIL"
	_save_report()
	await _fail(message)

func _save_report() -> void:
	var destination := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()+"/pixel-ui-native-report.json"
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
