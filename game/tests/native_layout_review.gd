extends "res://game/tests/native_review.gd"

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native layout review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress=get_tree().root.get_node_or_null("Progress")
	if progress==null:
		push_error("Progress autoload is missing")
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
	for size in [Vector2i(800,600),Vector2i(1280,720)]:
		if not await _resize_window(size): return
		if not await _open_wardrobe_and_capture(size.x): return
	if not await _resize_window(Vector2i(800,600)): return
	if not await _open_settings_and_capture(): return
	print("PASS: native layout at 800x600 and 1280x720; wardrobe/settings controls fit and respond to native input")
	main.world.blocked=true
	main.world.set_process(false)
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _resize_window(target: Vector2i) -> bool:
	var window := get_window()
	# Update Godot's Window/Viewport owner, not just the display backend. On
	# X11 a direct DisplayServer request can leave the viewport at the old size.
	window.size = target
	var deadline := Time.get_ticks_msec()+2500
	while (window.size != target or DisplayServer.window_get_size(window.get_window_id()) != target) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	if window.size != target or DisplayServer.window_get_size(window.get_window_id()) != target:
		await _fail("Window/backend rejected native size %s; Window %s, backend %s" % [target, window.size, DisplayServer.window_get_size(window.get_window_id())])
		return false
	await _frames(5)
	await RenderingServer.frame_post_draw
	var viewport := main.get_viewport()
	if not is_equal_approx(viewport.get_visible_rect().size.x,1280.0) or not is_equal_approx(viewport.get_visible_rect().size.y,720.0):
		await _fail("Logical viewport changed from 1280x720 at physical size %s: %s"%[str(target),str(viewport.get_visible_rect().size)])
		return false
	var expected_scale := minf(float(target.x)/1280.0, float(target.y)/720.0)
	var transform := viewport.get_final_transform()
	if not is_equal_approx(transform.x.length(), expected_scale) or not is_equal_approx(transform.y.length(), expected_scale):
		await _fail("Viewport physical scale did not follow actual window %s: %s, expected %.4f" % [target, transform, expected_scale])
		return false
	return true

func _open_wardrobe_and_capture(width: int) -> bool:
	await _tap_key(KEY_C)
	await _frames(3)
	if main.modal_kind!="wardrobe":
		await _fail("C did not open the wardrobe at width %d"%width)
		return false
	if not await _check_modal_layout("wardrobe %d"%width): return false
	if not await _check_wardrobe_controls(): return false
	# Leave the first, useful fitting-room page visible for the layout evidence.
	var appearance_tab := main.overlay.find_child("Tab_appearance",true,false) as Button
	if appearance_tab==null:
		await _fail("Wardrobe appearance tab is missing")
		return false
	if not await _click_control(appearance_tab): return false
	if main.wardrobe_panel.current_tab!="appearance":
		await _fail("Actual mouse click did not activate the wardrobe appearance tab")
		return false
	if not await _check_named_button("ApplyAppearance"): return false
	if not await _check_named_button("CancelFitting"): return false
	await _frames(2)
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-8-layout-%d.png"%width):
		await _fail("Could not save wardrobe layout evidence at width %d"%width)
		return false
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.modal_kind!="":
		await _fail("Escape did not close wardrobe at width %d"%width)
		return false
	return true

func _check_wardrobe_controls() -> bool:
	for tab_name in ["Tab_appearance","Tab_closet","Tab_shop"]:
		if not await _check_named_button(tab_name): return false
	var scroll := main.wardrobe_panel.item_scroll as ScrollContainer
	if scroll==null:
		await _fail("Wardrobe scroll container is missing")
		return false
	if not await _check_named_button("ApplyAppearance"): return false
	if not await _check_named_button("CancelFitting"): return false
	var appearance_list := scroll.get_child(0) as VBoxContainer
	for row in appearance_list.get_children():
		if row is HBoxContainer and not await _check_scroll_entry(scroll,row,"wardrobe appearance row"):
			return false
	var closet_tab := main.overlay.find_child("Tab_closet",true,false) as Button
	if not await _click_control(closet_tab): return false
	if main.wardrobe_panel.current_tab!="closet":
		await _fail("Actual mouse click did not activate the wardrobe closet tab")
		return false
	if not await _check_named_button("WearSelected"): return false
	if not await _check_named_button("CancelFitting"): return false
	scroll=main.wardrobe_panel.item_scroll as ScrollContainer
	var closet_list := scroll.get_child(0) as VBoxContainer
	for row in closet_list.get_children():
		if row is HBoxContainer and not await _check_scroll_entry(scroll,row,"wardrobe closet row"):
			return false
	var shop_tab := main.overlay.find_child("Tab_shop",true,false) as Button
	if not await _click_control(shop_tab): return false
	if main.wardrobe_panel.current_tab!="shop":
		await _fail("Actual mouse click did not activate the wardrobe shop tab")
		return false
	scroll=main.wardrobe_panel.item_scroll as ScrollContainer
	if scroll==null:
		await _fail("Shop tab did not rebuild its scroll container")
		return false
	if not await _check_named_button("PurchaseSelected"): return false
	if not await _check_named_button("WearSelected"): return false
	if not await _check_named_button("CancelWardrobe"): return false
	var list := scroll.get_child(0) as VBoxContainer
	var priced_rows := 0
	for row in list.get_children():
		if not row is HBoxContainer: continue
		var item_button: Button=null
		var price_label: Label=null
		for child in row.get_children():
			if child is Button and str(child.name).begins_with("WardrobeItem_"): item_button=child
			elif child is Label: price_label=child
		if item_button==null or price_label==null: continue
		if str(price_label.text).contains("幣"): priced_rows+=1
		if not await _check_scroll_entry(scroll,row,str(item_button.name)): return false
		if not _text_fits(item_button) or not _text_fits(price_label):
			await _fail("Wardrobe item or price text is clipped: "+str(item_button.name))
			return false
	if priced_rows==0:
		await _fail("Shop has no visible item price labels to review")
		return false
	scroll.scroll_vertical=0
	await _frames(2)
	for tab_name in ["Tab_appearance","Tab_closet","Tab_shop"]:
		var tab := main.overlay.find_child(tab_name,true,false) as Button
		if not _control_fits_viewport(tab):
			await _fail("Wardrobe tab clipped: "+tab_name)
			return false
	return true

func _check_modal_layout(label: String) -> bool:
	var viewport_rect: Rect2=main.get_viewport().get_visible_rect()
	if main.overlay.get_child_count()<2:
		await _fail("Modal tree missing center container: "+label)
		return false
	var center := main.overlay.get_child(1) as CenterContainer
	if center==null or center.get_child_count()==0:
		await _fail("Modal center/panel missing: "+label)
		return false
	var panel := center.get_child(0) as Control
	if not viewport_rect.encloses(panel.get_global_rect()):
		await _fail("Modal extends outside logical viewport at "+label+": "+str(panel.get_global_rect()))
		return false
	return await _inspect_controls(main.overlay,viewport_rect)

func _check_scroll_entry(scroll: ScrollContainer, entry: Control, label: String) -> bool:
	scroll.ensure_control_visible(entry)
	await _frames(2)
	var viewport_rect: Rect2=main.get_viewport().get_visible_rect()
	var clip_rect: Rect2=scroll.get_global_rect()
	var entry_rect: Rect2=entry.get_global_rect()
	if not clip_rect.encloses(entry_rect) or not viewport_rect.encloses(entry_rect):
		await _fail("Scroll entry is clipped or offscreen (%s): %s"%[label,str(entry_rect)])
		return false
	if entry is Button or entry is Label:
		if not _text_fits(entry):
			await _fail("Scroll entry text clipped (%s)"%label)
			return false
	for child in entry.get_children():
		if child is Control and child.is_visible_in_tree():
			if not clip_rect.encloses(child.get_global_rect()) or not viewport_rect.encloses(child.get_global_rect()):
				await _fail("Scroll entry child clipped (%s / %s)"%[label,str(child.name)])
				return false
			if (child is Button or child is Label or child is OptionButton or child is CheckButton or child is HSlider) and not _text_fits(child):
				await _fail("Scroll entry child text clipped (%s / %s)"%[label,str(child.name)])
				return false
	return true

func _inspect_controls(node: Node, viewport_rect: Rect2) -> bool:
	if node is ScrollContainer and node.is_visible_in_tree():
		if not viewport_rect.encloses(node.get_global_rect()):
			await _fail("Scroll viewport extends outside screen: "+str(node.get_global_rect()))
			return false
		return true # Scrolling content is checked after ensure_control_visible().
	if node is Control and node.is_visible_in_tree():
		if not viewport_rect.encloses(node.get_global_rect()):
			await _fail("Visible control outside viewport: %s %s"%[node.name,str(node.get_global_rect())])
			return false
		if (node is Button or node is Label) and not _text_fits(node as Control):
			await _fail("Visible text clipped by control: %s / %s"%[node.name,str(node.get_global_rect())])
			return false
	for child in node.get_children():
		if not await _inspect_controls(child,viewport_rect): return false
	return true

func _check_named_button(name: String) -> bool:
	var button := main.overlay.find_child(name,true,false) as Button
	if button==null:
		await _fail("Missing wardrobe action/tab button: "+name)
		return false
	if not _control_fits_viewport(button) or not _text_fits(button):
		await _fail("Wardrobe action/tab text or bounds clipped: "+name)
		return false
	return true

func _control_fits_viewport(control: Control) -> bool:
	return control!=null and control.is_visible_in_tree() and main.get_viewport().get_visible_rect().encloses(control.get_global_rect())

func _text_fits(control: Control) -> bool:
	if control==null: return false
	var minimum := control.get_combined_minimum_size()
	var rect := control.get_global_rect()
	return rect.size.x+1.0>=minimum.x and rect.size.y+1.0>=minimum.y

func _open_settings_and_capture() -> bool:
	var settings_button := _find_text_button(main.hud,"設定")
	if settings_button==null or not _control_fits_viewport(settings_button):
		await _fail("HUD settings button is missing or outside the viewport")
		return false
	if not await _click_control(settings_button): return false
	await _frames(3)
	if main.modal_kind!="settings":
		await _fail("Actual mouse click did not open settings")
		return false
	if not await _check_modal_layout("settings 800"): return false
	var settings_scroll := _find_scroll_container(main.overlay)
	if settings_scroll==null:
		await _fail("Settings scroll container is missing")
		return false
	var settings_list := settings_scroll.get_child(0) as VBoxContainer
	for entry in settings_list.get_children():
		if entry is Control and not await _check_scroll_entry(settings_scroll,entry,"settings control"):
			return false
	settings_scroll.scroll_vertical=0
	await _frames(2)
	var back_button := _find_text_button(main.overlay,"返回遊園")
	if back_button==null or not _control_fits_viewport(back_button) or not _text_fits(back_button):
		await _fail("Settings return button is clipped or missing")
		return false
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-6-settings-800.png"):
		await _fail("Could not save 800x600 settings evidence")
		return false
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.modal_kind!="":
		await _fail("Escape did not close settings")
		return false
	return true

func _find_scroll_container(root: Node) -> ScrollContainer:
	if root is ScrollContainer: return root as ScrollContainer
	for child in root.get_children():
		var found := _find_scroll_container(child)
		if found != null: return found
	return null

func _find_text_button(root: Node, text: String) -> Button:
	if root is Button and root.text.contains(text): return root
	for child in root.get_children():
		var found := _find_text_button(child,text)
		if found!=null: return found
	return null

func _tap_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	Input.parse_input_event(event)
	await get_tree().process_frame

func _click_control(control: Control) -> bool:
	return await _native_click_button(control as BaseButton, "layout/tutorial button")

func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame
