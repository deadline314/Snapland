extends "res://game/tests/native_layout_review.gd"
## Park menus only: actual native inputs and presentation evidence; no minigame completion claim.

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false,0.0)

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native park UI review requires GPU and an isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress=get_tree().root.get_node_or_null("Progress")
	if progress==null:
		push_error("Progress autoload missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen=true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	main=_instantiate_main()
	if main==null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	for size in [Vector2i(1280,720),Vector2i(800,600)]:
		if not await _resize_window(size): return
		if not await _review_main_menus(size.x): return
		if not await _review_phases(size.x): return
		if not await _review_reduced_motion(size.x): return
	print("PASS: ART20 park menus, four phase variants, and saved reduced-motion on/off verified with native inputs at both widths; presentation fixture only")
	await main._quit_game()

func _open_ticket_menu(kind: String, text: String) -> bool:
	_key(KEY_M)
	await _frames(4)
	if main.modal_kind!="ticket":
		await _fail("M did not open ticket for "+kind)
		return false
	var button := _find_text_button(main.overlay,text)
	if button==null:
		await _fail("Required ticket entry missing: "+text)
		return false
	await _click_control(button)
	await _frames(5)
	if main.modal_kind!=kind:
		await _fail("Actual ticket input did not open "+kind)
		return false
	return true

func _review_phases(width: int) -> bool:
	for phase_id in ["dawn","noon","dusk","night"]:
		_key(KEY_T)
		await _frames(5)
		if main.modal_kind!="time":
			await _fail("T did not open time picker")
			return false
		var button := main.overlay.find_child("TimePhase_"+phase_id,true,false) as Button
		if button==null or button.disabled:
			await _fail("Expected selectable phase button: "+phase_id)
			return false
		await _click_control(button)
		await _frames(12)
		if str(progress.settings.get("time_phase",""))!=phase_id or not button.button_pressed:
			await _fail("Native phase selection did not persist: "+phase_id)
			return false
		if not await _capture_menu("time","%s-%d" % [phase_id,width]): return false
		_key(KEY_ESCAPE)
		await _frames(8)
		if not _physical_menu_readable(main.hud) or not await _inspect_controls(main.hud,main.get_viewport().get_visible_rect()):
			await _fail("Phase HUD is unreadable or out of bounds: "+phase_id)
			return false
		await RenderingServer.frame_post_draw
		if not main._capture("pm/Snapland-art/images/ART-20-main-%s-%d.png" % [phase_id,width]):
			await _fail("Phase HUD capture failed")
			return false
		_key(KEY_M)
		await _frames(5)
		if main.modal_kind!="ticket":
			await _fail("M did not open phase ticket")
			return false
		if not await _capture_menu("ticket","%s-%d" % [phase_id,width]): return false
		_key(KEY_ESCAPE)
		await _frames(4)
	return true

func _review_reduced_motion(width: int) -> bool:
	if not await _open_ticket_menu("settings","設定與輔助"): return false
	var toggle := _find_text_button(main.overlay,"降低動態") as CheckButton
	if toggle==null:
		await _fail("Reduced-motion setting toggle missing")
		return false
	for enabled in [true,false]:
		if toggle.button_pressed==enabled:
			await _fail("Reduced-motion fixture expected a real toggle transition")
			return false
		await _click_control(toggle)
		await _frames(5)
		var save_file := FileAccess.open(OS.get_environment("SNAPLAND_SAVE_PATH"),FileAccess.READ)
		var saved: Variant=JSON.parse_string(save_file.get_as_text()) if save_file!=null else null
		if save_file!=null:
			save_file.close()
		if bool(progress.settings.get("reduced_motion",false))!=enabled or not saved is Dictionary or bool(saved.get("settings",{}).get("reduced_motion",false))!=enabled:
			await _fail("Native reduced-motion toggle did not persist to isolated save")
			return false
		if not await _capture_menu("settings","motion-%s-%d" % ["on" if enabled else "off",width]): return false
	_key(KEY_ESCAPE)
	await _frames(4)
	return true

func _review_main_menus(width: int) -> bool:
	var suffix := "%d" % width
	await _frames(6)
	if not _physical_menu_readable(main.hud):
		await _fail("Main HUD physical controls/fonts fail readability at "+suffix)
		return false
	if not await _inspect_controls(main.hud, main.get_viewport().get_visible_rect()):
		await _fail("Main HUD controls extend or clip at " + suffix)
		return false
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-20-main-%s.png" % suffix):
		await _fail("Could not save main menu at width " + suffix)
		return false
	var arrival: Dictionary = {}
	for point in main.world.points:
		if str(point.get("id", "")) == "arrival":
			arrival = point
			break
	if arrival.is_empty():
		await _fail("Missing arrival interaction for ART20 dialogue capture")
		return false
	main.world.player.position = Vector3(arrival.position) + Vector3(0, 0.3, 0)
	var nearest_deadline := Time.get_ticks_msec()+3000
	while str(main.world.nearest.get("id",""))!="arrival" and Time.get_ticks_msec()<nearest_deadline:
		await get_tree().physics_frame
	if str(main.world.nearest.get("id",""))!="arrival":
		await _fail("Arrival nearest interaction did not settle")
		return false
	_key(KEY_E)
	await _frames(6)
	if main.modal_kind != "dialogue":
		await _fail("Native E input did not open arrival dialogue at width " + suffix)
		return false
	if not await _capture_menu("dialogue", suffix): return false
	_key(KEY_ESCAPE)
	await _frames(3)
	for menu_item in [
		["map", "島嶼地圖"], ["tasks", "今日任務"], ["album", "拍貼收藏本"],
		["achievements", "遊園成就"], ["wardrobe", "衣櫃與服飾店"],
		["time", "切換時段"], ["settings", "設定與輔助"]
	]:
		_key(KEY_M)
		await _frames(4)
		if main.modal_kind != "ticket":
			await _fail("M did not open voyage pass at width " + suffix)
			return false
		var button := _find_text_button(main.overlay, menu_item[1])
		if button!=null: await _reveal_control(button)
		if button == null or not _control_fits_viewport(button) or not _text_fits(button):
			await _fail("Ticket menu entry is missing/clipped: " + str(menu_item[1]) + " at " + suffix + "; " + _control_diagnostics(button))
			return false
		if width == 1280 and menu_item[0] == "map":
			await RenderingServer.frame_post_draw
			main._capture(".review/ticket-before-map-click.png")
		var observed_press := {"value":false}
		button.pressed.connect(func(): observed_press.value=true, CONNECT_ONE_SHOT)
		await _click_control(button)
		await _frames(6)
		if main.modal_kind != menu_item[0]:
			var hovered := main.get_viewport().gui_get_hovered_control()
			var hover_path := str(hovered.get_path()) if is_instance_valid(hovered) else "none"
			if width == 1280 and menu_item[0] == "map":
				await RenderingServer.frame_post_draw
				main._capture(".review/ticket-after-map-click.png")
			await _fail("Actual ticket click did not open " + str(menu_item[0]) + " at " + suffix + "; modal_kind=" + main.modal_kind + "; target_pressed=" + str(observed_press.value) + "; hovered=" + hover_path + "; " + _control_diagnostics(button))
			return false
		if not await _capture_menu(str(menu_item[0]), suffix): return false
		_key(KEY_ESCAPE)
		await _frames(4)
		if main.modal_kind != "":
			await _fail("Escape did not close " + str(menu_item[0]) + " at " + suffix)
			return false
	print("CAPTURED: ART20 main, dialogue and ticket menus at " + suffix + "px")
	return true

func _capture_menu(kind: String, suffix: String) -> bool:
	if kind=="dialogue" and is_instance_valid(main.dialogue_label):
		var reveal_deadline := Time.get_ticks_msec()+12000
		while main.dialogue_label.visible_characters>=0 and main.dialogue_label.visible_characters<main.dialogue_label.text.length() and Time.get_ticks_msec()<reveal_deadline:
			await get_tree().process_frame
		if main.dialogue_label.visible_characters>=0 and main.dialogue_label.visible_characters<main.dialogue_label.text.length():
			await _fail("Dialogue typewriter did not finish before capture")
			return false
	var required := {"map":"IslandChartCanvas","album":"AlbumPhotoGrid","achievements":"MinigameStampGrid"}
	if required.has(kind):
		var panel := main.overlay.find_child(str(required[kind]),true,false) as Control
		if panel==null or not panel.is_visible_in_tree() or panel.get_child_count()==0 or panel.size.x<=0 or panel.size.y<=0:
			await _fail("Required visible menu content failed to load: " + kind + " / " + suffix)
			return false
		if kind=="map":
			var station_count := 0
			var gate_count := 0
			for child in panel.get_children():
				if child is Button and child.name.begins_with("MapStop_"): station_count+=1
				if child is Button and child.name.begins_with("MapGate_"): gate_count+=1
			if station_count!=12 or gate_count!=9:
				await _fail("Map must contain twelve stations and nine future entrances")
				return false
	var review_surface: Node = main.dialogue_panel if kind=="dialogue" else main.overlay
	if not _physical_menu_readable(review_surface):
		await _fail("Menu physical hit targets or font sizes fall below the readability baseline: " + kind + " / " + suffix)
		return false
	if not await _inspect_controls(review_surface, main.get_viewport().get_visible_rect()):
		await _fail("ART20 controls extend or clip at " + kind + " / " + suffix)
		return false
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-20-%s-%s.png" % [kind, suffix]):
		await _fail("Could not save ART20 menu evidence: " + kind + " / " + suffix)
		return false
	return true

func _physical_menu_readable(node: Node) -> bool:
	if node is Control and node.is_visible_in_tree():
		var control := node as Control
		var transform: Transform2D=control.get_viewport().get_final_transform()*control.get_global_transform_with_canvas()
		var scale_factor := minf(transform.x.length(),transform.y.length())
		if control is Button:
			if control.size.x*scale_factor<43.9 or control.size.y*scale_factor<43.9:
				print("PHYSICAL HIT FAIL: ",control.get_path()," size=",control.size*scale_factor)
				return false
		if control is Label or control is Button:
			var base_font := int(control.get_meta("menu_base_font",control.get_theme_font_size("font_size")))
			var required := 20.0 if base_font>=20 else 16.0
			if control.get_theme_font_size("font_size")*scale_factor<required-0.1:
				print("PHYSICAL FONT FAIL: ",control.get_path())
				return false
	for child in node.get_children():
		if not _physical_menu_readable(child): return false
	return true

func _reveal_control(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await _frames(3)

func _click_control(control: Control) -> bool:
	await _reveal_control(control)
	return await super._click_control(control)

func _control_diagnostics(control: Control) -> String:
	if control == null:
		return "button=null"
	var details := "button=%s text=%s visible=%s rect=%s" % [str(control.get_path()), control.text, str(control.is_visible_in_tree()), str(control.get_global_rect())]
	var cursor: Node = control
	while cursor != null and cursor is Control:
		var item := cursor as Control
		details += " parent[%s filter=%d visible=%s rect=%s]" % [str(item.name), item.mouse_filter, str(item.is_visible_in_tree()), str(item.get_global_rect())]
		cursor = item.get_parent()
	return details
