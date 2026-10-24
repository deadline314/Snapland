extends Node

const MAIN_SCENE = preload("res://game/main.tscn")
const SettingsPanel = preload("res://game/ui/settings_panel.gd")
const TimePanel = preload("res://game/ui/time_panel.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")
const Paper = preload("res://game/ui/paper_ui.gd")

var failures: Array[String]=[]
var main: Node

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running pixel UI customization checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Progress.reset_progress()
	_check(is_equal_approx(float(Progress.DEFAULT_SETTINGS.get("ui_scale",0.0)),1.0),"text scale defaults to readable compatibility size")
	Progress.set_setting("ui_scale",1.25)
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.25),"text scale accepts the accessible upper bound")
	Progress.set_setting("ui_scale",9.0)
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.25),"text scale clamps oversized input")
	Progress.set_setting("ui_scale",-1.0)
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.0),"text scale clamps undersized input")
	Progress.set_setting("ui_scale",NAN)
	Progress.set_setting("ui_scale","large")
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.0),"NaN and string values cannot replace the scale")
	Progress.set_setting("ui_scale",1.25)
	_check(Progress.save_progress(),"text scale saves")
	Progress._reset_memory()
	Progress.load_progress()
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.25),"text scale survives a real save and reload")
	Progress._apply_loaded_setting("ui_scale",NAN)
	Progress._apply_loaded_setting("ui_scale","invalid")
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.25),"invalid persisted scale values are ignored")
	Progress._reset_memory()
	_check(is_equal_approx(float(Progress.settings.ui_scale),1.0),"profiles without a saved scale keep the default")

	Progress.set_setting("ui_scale",1.25)
	Progress.intro_seen=true
	_check(Progress.save_progress(),"the test profile is ready without triggering the arrival dialogue")
	main=MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	get_tree().root.size=Vector2i(800,450)
	await _frames(3)
	# Exercise the same retained Main -> RefCounted-panel path as the player, then
	# record real settled control geometry before asserting visual availability.
	main._show_settings()
	await _frames(5)
	var actual_play_tab := main.overlay.find_child("SettingsTab_play",true,false) as Button
	if actual_play_tab!=null:
		await _settings_pointer_click(actual_play_tab)
		await _frames(5)
	var actual_controls_tab := main.overlay.find_child("SettingsTab_controls",true,false) as Button
	_check(actual_controls_tab!=null,"Main opens the live settings controls category")
	if actual_controls_tab!=null:
		await _settings_pointer_click(actual_controls_tab)
		await _frames(5)
		var actual_content := main.overlay.find_child("SettingsContent",true,false) as VBoxContainer
		var actual_grid := actual_content.get_child(1) as GridContainer if actual_content!=null and actual_content.get_child_count()>1 else null
		_check(actual_grid!=null,"live Controls category creates its action/key grid")
		if actual_grid==null:
			main._close()
			return
		print("SETTINGS_CONTROLS_DIAG viewport=",get_viewport().get_visible_rect()," root=",get_tree().root.size," scale=",Paper.physical_scale(main.overlay)," body=",main.modal_body.get_global_rect()," grid=",actual_grid.get_global_rect()," grid_visible=",actual_grid.is_visible_in_tree()," min=",actual_grid.get_combined_minimum_size())
		_check(actual_grid.get_child_count()==18,"native-routed Controls click retains all eighteen action/key labels")
		_check(actual_content.get_global_rect().encloses(actual_grid.get_global_rect()),"actual SettingsContent allocates a fully visible Controls grid")
		_check(actual_grid.size.y>0.0 and actual_grid.size.x>0.0,"Controls grid receives positive width and height from its actual parent")
		var controls_viewport := get_viewport().get_visible_rect()
		for child_index in actual_grid.get_child_count():
			var diagnostic_control := actual_grid.get_child(child_index) as Control
			var control_label := diagnostic_control as Label
			var font_size := diagnostic_control.get_theme_font_size("font_size")
			var font_height := diagnostic_control.get_theme_font("font").get_height(font_size)
			var control_rect := diagnostic_control.get_global_rect()
			print("SETTINGS_CONTROLS_CHILD index=",child_index," text=",control_label.text," rect=",control_rect," visible=",diagnostic_control.is_visible_in_tree()," font=",font_size)
			_check(not control_label.text.strip_edges().is_empty(),"Controls row %d retains a nonempty action/key label"%child_index)
			_check(diagnostic_control.is_visible_in_tree() and control_rect.size.y>=font_height,"Controls row %d has visible text-height geometry"%child_index)
			var glyph_width := control_label.get_theme_font("font").get_string_size(control_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			_check(font_size>0 and font_height>0.0 and glyph_width>0.0 and control_rect.size.x+1.0>=glyph_width,"Controls row %d retains complete readable glyph width"%child_index)
			_check(control_label.get_line_count()>=1 and control_label.get_visible_line_count()==control_label.get_line_count(),"Controls row %d has every text line actually drawable"%child_index)
			_check(control_label.get_line_height(-1)>0 and control_rect.size.y>=control_label.get_line_height(-1),"Controls row %d fits the actual shaped line height without tolerance"%child_index)
			_check(actual_content.get_global_rect().encloses(control_rect),"Controls row %d fits its real allocated content parent"%child_index)
			var ancestor := diagnostic_control.get_parent()
			while ancestor!=null:
				if ancestor is Control and ancestor.clip_contents:
					_check(ancestor.get_global_rect().encloses(control_rect),"Controls row %d is wholly inside actual ancestor clip"%child_index)
				ancestor=ancestor.get_parent()
			_check(actual_grid.get_global_rect().grow(2.0).encloses(control_rect) and controls_viewport.encloses(control_rect),"Controls row %d is unclipped in the logical viewport"%child_index)
	main._close()
	var modal_body: VBoxContainer=main._open("設定","SETTINGS","settings")
	var settings := SettingsPanel.new()
	var settings_changes: Array[String]=[]
	var count_setting_changes:=func(): settings_changes.append("changed")
	Progress.changed.connect(count_setting_changes)
	settings.open(main,modal_body)
	await _frames(2)
	_check(settings_changes.is_empty(),"opening settings reads existing values without saving or emitting Progress.changed")
	Progress.changed.disconnect(count_setting_changes)
	_check(settings.tabs.size()==4 and settings.tabs.has_all(["audio", "play", "controls", "text"]),"settings expose exactly Audio, Play and Display, Controls, and Language and Text categories")
	_check(settings.content.find_child("Value_master_volume",true,false)!=null and settings.content.find_child("Value_reduced_motion",true,false)==null,"audio category keeps volume and text speed together")
	settings._show_category("text")
	_check(settings.tabs["text"].button_pressed and settings.content.find_child("Value_locale",true,false)!=null and settings.content.find_child("Value_font_style",true,false)!=null,"text category exposes locale and font style choices with its fixed tab selected")
	settings._show_category("play")
	var scale_slider := settings.content.find_child("Value_ui_scale",true,false) as HSlider
	_check(scale_slider!=null and scale_slider.min_value==1.0 and scale_slider.max_value==1.25,"text size uses the supported readable range")
	if scale_slider!=null:
		scale_slider.value=1.25
		_check(is_equal_approx(float(Progress.settings.ui_scale),1.25),"text size control saves the changed value")
	var motion_toggle := settings.content.find_child("Value_reduced_motion",true,false) as CheckButton
	if motion_toggle!=null:
		motion_toggle.button_pressed=true
		_check(bool(Progress.settings.reduced_motion),"reduced-motion control saves its value")
	settings._show_category("controls")
	var controls_grid := settings.content.get_child(1) as GridContainer
	_check(controls_grid!=null and controls_grid.get_child_count()==18,"controls show all nine existing key and action pairs")
	if controls_grid!=null and controls_grid.get_child_count()>=18:
		_check((controls_grid.get_child(0) as Label).text=="移動" and (controls_grid.get_child(1) as Label).text=="W A S D／方向鍵" and (controls_grid.get_child(16) as Label).text=="暫停／返回" and (controls_grid.get_child(17) as Label).text=="Esc","control labels preserve their existing key-to-action mapping")
	await _frames(3)
	_check(main.overlay.get_global_rect().encloses(settings.content.get_global_rect()),"settings content stays inside the modal at the 800x450 viewport size")
	main._close()
	var before_appearance: Dictionary=Progress.appearance.duplicate(true)
	main._show_wardrobe()
	await _frames(2)
	var panel=main.wardrobe_panel
	_check(panel.preview.texture is Texture2D,"wardrobe keeps its character preview visible")
	var appearance_selectors: Array[OptionButton]=[]
	_collect_appearance_selectors(panel.content,appearance_selectors)
	_check(appearance_selectors.size()==6,"both no-scroll appearance pages retain all six selectors")
	var reached_fields := {}
	for page_index in panel.appearance_pages.size():
		panel._show_appearance_page(page_index)
		await _frames(5)
		_check(_wardrobe_visible_copy_fits(panel.body),"appearance page has no partially clipped visible label")
		for selector in appearance_selectors:
			if not selector.is_visible_in_tree(): continue
			_check(not reached_fields.has(selector.name),"appearance field is reached once through its actual page: "+str(selector.name))
			reached_fields[selector.name]=true
			_check(_wardrobe_row_fits(selector.get_parent(),panel.item_scroll.get_global_rect()),"appearance page fully reveals its field and label: "+str(selector.name))
	_check(reached_fields.size()==6,"actual appearance pages reach all six retained fields")
	var appearance_page_two := panel.content.find_child("AppearancePage_2",true,false) as Button
	if appearance_page_two!=null:
		appearance_page_two.pressed.emit()
		await _frames(3)
	var hair_selector := panel.content.find_child("Appearance_hair",true,false) as OptionButton
	_check(hair_selector!=null and hair_selector.is_visible_in_tree(),"appearance page two reveals its selectors without scrolling")
	var appearance_scroll := panel.item_scroll as ScrollContainer
	_check(appearance_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER and not appearance_scroll.get_v_scroll_bar().visible,"appearance category keeps its scrollbar hidden while paging fields")
	for direction in ["front","front_left","left","back_left","back","back_right","right","front_right"]:
		_check(panel.body.find_child("Preview_"+direction,true,false) is Button,"wardrobe exposes preview direction: "+direction)
	var options: Dictionary=Progress.appearance_options()
	var skin_options: Array=options.get("skin",[])
	if skin_options.size()>1:
		panel.draft_appearance.skin=str(skin_options[1].id)
		panel._refresh_preview()
	panel._show_tab("closet")
	await _frames(5)
	_check(_wardrobe_visible_copy_fits(panel.body),"closet heading, guidance, and item labels are complete at the native five-frame capture boundary")
	if panel.item_page_count==1:
		_check(panel.item_scroll.scroll_vertical==0,"a naturally fitting one-page closet retains its complete heading and guidance at the viewport origin")
	Progress.coins=0
	panel._show_tab("shop")
	await _frames(5)
	_check(_wardrobe_visible_copy_fits(panel.body),"shop heading, guidance, and item labels are complete at the native five-frame capture boundary")
	_check(panel.item_page_count>1 and panel.item_page_nav.visible and panel.items_per_page>0,"shop catalog derives full-page capacity from the live viewport")
	_check(panel.item_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER and not panel.item_scroll.get_v_scroll_bar().visible,"shop pagination hides its scrollbar while preserving internal page offsets")
	var next_item_page := panel.item_page_nav.find_child("WardrobeNextPage",false,false) as Button
	var retained_rows: Array[Control]=[]
	for child in panel.item_page_list.get_children():
		if child.has_meta("wardrobe_item_row"): retained_rows.append(child as Control)
	# The independent catalog is the inventory oracle; UI counts alone would
	# accept a lost row duplicated elsewhere or the same stale eight-item list.
	var expected_item_ids := {}
	for item: Dictionary in Progress.wardrobe_items():
		_check(not expected_item_ids.has(str(item.id)),"catalog item identities are unique: "+str(item.id))
		expected_item_ids[str(item.id)]=true
	for required_id in ["outfit-tide","outfit-coral","outfit-gold","outfit-navy","outfit-rainvest","hat-none","hat-straw","hat-sailor","hat-flower"]:
		_check(expected_item_ids.has(required_id),"catalog preserves the existing clothes and free silhouette: "+required_id)
	_check(retained_rows.size()==expected_item_ids.size() and panel.visible_items.size()==expected_item_ids.size(),"catalog retains every real item row independently of Godot sibling names")
	var retained_item_ids := {}
	for row in retained_rows:
		var retained_id := str(row.get_meta("wardrobe_item_id",""))
		_check(expected_item_ids.has(retained_id) and not retained_item_ids.has(retained_id),"each catalog identity has exactly one retained row: "+retained_id)
		retained_item_ids[retained_id]=true
	var reached_items := {}
	for page_index in panel.item_page_count:
		if page_index>0 and next_item_page!=null:
			next_item_page.pressed.emit()
		await _frames(6)
		_check(_wardrobe_visible_copy_fits(panel.body),"every actual shop page retains complete visible labels including leading copy")
		var viewport_rect: Rect2=panel.item_scroll.get_global_rect()
		var displayed := 0
		for row in retained_rows:
			if not viewport_rect.intersects(row.get_global_rect()): continue
			displayed+=1
			var item_id := str(row.get_meta("wardrobe_item_id",""))
			_check(not reached_items.has(item_id),"actual shop pages reveal each stable item once: "+item_id)
			reached_items[item_id]=true
			_check(_wardrobe_row_fits(row,viewport_rect),"actual page completely reveals row, button, preview, and price label: "+item_id)
		_check(displayed==mini(panel.items_per_page,panel.visible_items.size()-page_index*panel.items_per_page),"actual shop page exposes no partial next or previous row")
		var first_index: int=page_index*panel.items_per_page
		var last_index: int=mini((page_index+1)*panel.items_per_page,panel.visible_items.size())
		for item_index in range(first_index,last_index):
			var item_id:=str(panel.visible_items[item_index].get("id",""))
			var item_button:=panel.content.find_child("WardrobeItem_"+item_id,true,false) as Button
			var row_rect: Rect2=item_button.get_parent().get_global_rect() if item_button!=null else Rect2()
			_check(item_button!=null and panel.item_scroll.get_global_rect().encloses(row_rect),"shop page %d fully reveals catalog item %s"%[page_index+1,item_id])
	_check(reached_items.size()==expected_item_ids.size(),"actual shop page navigation reaches the complete catalog")
	for expected_id in expected_item_ids:
		_check(reached_items.has(expected_id),"actual shop page navigation reaches catalog identity: "+str(expected_id))
	_check(Progress.owned_clothes.has("outfit-rainvest") and Progress.coins==0,"zero-coin player already owns the free silhouette while browsing the shop")
	var final_page_item := panel.content.find_child("WardrobeItem_hat-flower",true,false) as Button
	_check(final_page_item!=null and panel.item_scroll.get_global_rect().encloses(final_page_item.get_parent().get_global_rect()),"shop page navigation reveals the final item inside the fixed viewport")
	_check(panel.item_scroll.scroll_vertical>0,"page navigation uses a real internal content offset")
	if panel.item_page_count>2 and next_item_page!=null:
		panel._set_item_page(0)
		next_item_page.pressed.emit()
		next_item_page.pressed.emit()
		(panel.item_page_nav.find_child("WardrobePreviousPage",false,false) as Button).pressed.emit()
		await _frames(8)
		_check(panel.item_page==1,"rapid next/previous navigation keeps the latest requested page")
		var latest_first := str(panel.visible_items[panel.items_per_page].id)
		var latest_button := panel.content.find_child("WardrobeItem_"+latest_first,true,false) as Button
		_check(latest_button!=null and _wardrobe_row_fits(latest_button.get_parent(),panel.item_scroll.get_global_rect()),"older deferred page callbacks cannot move the latest page out of its viewport")
	panel._select_item(Progress.wardrobe_item("outfit-gold"))
	var price_button := panel.content.find_child("WardrobeItem_outfit-gold",true,false) as Button
	var price_label := price_button.get_parent().get_child(price_button.get_index()+1) as Label if price_button!=null else null
	var price_plate := price_label.find_child("PriceContrastPlate",false,false) as PanelContainer if price_label!=null else null
	var price_style := price_plate.get_theme_stylebox("panel") as StyleBoxFlat if price_plate!=null else null
	_check(price_label!=null and price_label.text=="100 幣" and price_label.get_theme_color("font_color")==Paper.PRICE_INK,"price keeps the existing label selector and deep PRICE_INK")
	_check(price_plate!=null and price_plate.visible and price_style!=null and price_style.bg_color==Color("#f7efd9") and _contrast(price_label.get_theme_color("font_color"),price_style.bg_color)>=4.5,"unaffordable item price is legible on its actual square tag surface")
	var status_plate := panel.status_label.find_child("PriceContrastPlate",false,false) as PanelContainer
	var status_style := status_plate.get_theme_stylebox("panel") as StyleBoxFlat if status_plate!=null else null
	_check(panel.status_label.text.contains("餘額不足") and status_plate!=null and status_plate.visible and status_style!=null and status_style.bg_color==Color("#f7efd9") and _contrast(panel.status_label.get_theme_color("font_color"),status_style.bg_color)>=4.5,"insufficient-funds explanation gets a contrasting square tag")
	main._close()
	_check(Progress.appearance==before_appearance,"cancel fitting discards an unsaved appearance draft")
	main.world.nearest={"id":"pixel-ui-time-test"}
	main._show_time_panel()
	await _frames(4)
	_check(Paper.text_scale()==1.25,"small-screen time geometry uses the requested 1.25 text scale")
	var time_bounds := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	var time_panel_rect: Rect2=main.overlay.find_child("AdaptiveMenuPanel",true,false).get_global_rect()
	_check(time_bounds.encloses(time_panel_rect),"time modal shell stays inside the logical 1280x720 viewport")
	_check(not main.time_panel.status.visible,"empty time status does not reserve fixed-page height")
	for phase: Dictionary in TimeOfDay.PHASES:
		var phase_id := str(phase.id)
		var phase_button := main.overlay.find_child("TimePhase_"+phase_id,true,false) as Button
		_check(phase_button!=null and time_bounds.encloses(phase_button.get_global_rect()),"time phase remains visible at 800x450: "+phase_id)
		if phase_button!=null:
			_check(phase_button.get_global_rect().size.y*Paper.physical_scale(phase_button)>=44.0,"time phase keeps a 44px physical hit target: "+phase_id)
			phase_button.pressed.emit()
			await _frames(2)
			_check(main.time_panel.current_phase==phase_id,"time selection applies immediately from its visible phase control: "+phase_id)
	var postcard_detail := main.overlay.find_child("TimePostcardDetail",true,false) as PanelContainer
	_check(postcard_detail!=null and main.time_panel.postcard_grid.get_child_count()==1,"time panel shows one selected postcard detail rather than a clipped four-card strip")
	_check(postcard_detail!=null and main.time_panel.postcard_scroll.get_global_rect().encloses(postcard_detail.get_global_rect()),"selected postcard image and labels fit inside the fixed time-page viewport")
	var time_back := main.modal_footer.find_child("MenuBackButton",true,false) as Button
	_check(time_back!=null and time_bounds.encloses(time_back.get_global_rect()),"time page return action stays inside the fixed footer at 800x450")
	_check(main.time_panel.postcard_scroll.custom_minimum_size.y==0.0 and main.time_panel.postcard_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"time detail stays in its fixed content viewport without scrolling")
	main._close()

	var box := VBoxContainer.new()
	add_child(box)
	var time_panel := TimePanel.new()
	var selected: Array[String]=[]
	var choose := func(phase: String) -> bool:
		selected.append(phase)
		return true
	time_panel.open(self,box,"noon",{},false,choose,func(_phase: String) -> String: return "")
	var target_phase:=str(TimeOfDay.PHASES[2].id)
	time_panel._choose_phase(target_phase)
	_check(selected==[target_phase] and time_panel.current_phase==target_phase,"choosing a valid time phase applies immediately")
	_check(time_panel.phase_buttons.size()==TimeOfDay.PHASES.size() and time_panel.phase_buttons.size()==4,"all four time phases remain directly selectable")

	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	await _frames(2)
	if failures.is_empty():
		print("PASS: pixel UI settings, text-scale persistence, immediate time selection, and fixed category controls")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _settings_pointer_click(button: Button) -> void:
	var observed := {"pressed":0}
	var record := func(): observed.pressed+=1
	button.pressed.connect(record)
	var point := button.get_viewport().get_final_transform()*button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	motion.window_id=get_window().get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for down in [true,false]:
		var click := InputEventMouseButton.new()
		click.position=point
		click.global_position=point
		click.window_id=get_window().get_window_id()
		click.button_index=MOUSE_BUTTON_LEFT
		click.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed=down
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	button.pressed.disconnect(record)
	_check(observed.pressed==1 and button.button_pressed,"actual pointer route activates settings category: "+str(button.name))

func _wardrobe_visible_copy_fits(node: Node) -> bool:
	if node is Control and not node.is_visible_in_tree(): return true
	if node is Label and not node.text.is_empty():
		var rect: Rect2=node.get_global_rect()
		var ancestor := node.get_parent()
		while ancestor!=null:
			if ancestor is Control and ancestor.clip_contents:
				var clip: Rect2=ancestor.get_global_rect()
				if not clip.intersects(rect): return true
				if not clip.grow(2.0).encloses(rect):
					print("WARDROBE_VISIBLE_LABEL_CLIPPED ",node.get_path()," rect=",rect," clip=",clip)
					return false
			ancestor=ancestor.get_parent()
		var line_height: float=node.get_theme_font("font").get_height(node.get_theme_font_size("font_size"))
		if rect.size.x<2.0 or rect.size.y+2.0<line_height or not get_viewport().get_visible_rect().grow(2.0).encloses(rect): return false
	for child in node.get_children():
		if not _wardrobe_visible_copy_fits(child): return false
	return true

func _wardrobe_row_fits(row: Control, viewport_rect: Rect2) -> bool:
	if not viewport_rect.encloses(row.get_global_rect()): return false
	return _wardrobe_children_fit(row,row.get_global_rect(),viewport_rect)

func _wardrobe_children_fit(node: Node, row_rect: Rect2, viewport_rect: Rect2) -> bool:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree(): return true
		if not row_rect.encloses(control.get_global_rect()) or not viewport_rect.encloses(control.get_global_rect()):
			print("WARDROBE_CHILD_CLIPPED ",node.get_path()," rect=",control.get_global_rect()," row=",row_rect," clip=",viewport_rect)
			return false
		if control is Label and control.size.y+2.0<control.get_theme_font("font").get_height(control.get_theme_font_size("font_size")): return false
	for child in node.get_children():
		if not _wardrobe_children_fit(child,row_rect,viewport_rect): return false
	return true

func _collect_appearance_selectors(node: Node, destination: Array[OptionButton]) -> void:
	if node is OptionButton and str(node.name).begins_with("Appearance_"):
		destination.append(node)
	for child in node.get_children(): _collect_appearance_selectors(child,destination)

func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame

func _contrast(first: Color,second: Color) -> float:
	var a:=_relative_luminance(first)
	var b:=_relative_luminance(second)
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func _relative_luminance(color: Color) -> float:
	var channels: Array[float]=[]
	for value in [color.r,color.g,color.b]:
		channels.append(value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4))
	return channels[0]*0.2126+channels[1]*0.7152+channels[2]*0.0722
