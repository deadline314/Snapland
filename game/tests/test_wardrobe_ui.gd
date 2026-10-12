extends Node

const MAIN_SCENE = preload("res://game/main.tscn")
const Paper = preload("res://game/ui/paper_ui.gd")
var failures: Array[String] = []
var main: Node
var progress: Node

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running wardrobe UI checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	progress=get_tree().root.get_node_or_null("Progress")
	_check(progress!=null,"Progress autoload is available")
	if progress==null:
		_finish(); return
	progress.reset_progress()
	progress.intro_seen=true
	progress.save_progress()
	main=MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)
	main._show_wardrobe()
	await _frames(2)
	_check(main.modal_kind=="wardrobe","C opens the native wardrobe modal")
	_check(main.wardrobe_panel.preview.texture is Texture2D,"the fitting mirror renders an avatar preview")
	var appearance_tab := main.overlay.find_child("Tab_appearance",true,false) as Button
	var closet_tab := main.overlay.find_child("Tab_closet",true,false) as Button
	_check(appearance_tab!=null and appearance_tab.button_pressed and closet_tab!=null and not closet_tab.button_pressed,"the current wardrobe category is visibly selected")
	if appearance_tab!=null and closet_tab!=null:
		var active_tab_style := appearance_tab.get_theme_stylebox("pressed") as StyleBoxFlat
		var inactive_tab_style := closet_tab.get_theme_stylebox("normal") as StyleBoxFlat
		_check(active_tab_style!=null and inactive_tab_style!=null and active_tab_style.bg_color==Paper.DEEP_TEAL and active_tab_style.bg_color!=inactive_tab_style.bg_color,"selected tab face reads as the active fitting-room page, not another idle control")
		var active_ink := appearance_tab.get_theme_color("font_pressed_color")
		_check(_contrast(active_ink,active_tab_style.bg_color)>=4.5,"selected tab pressed text keeps readable contrast against its actual dark face")
		_check(appearance_tab.get_theme_color("font_color")==Paper.PAPER and appearance_tab.get_theme_color("font_hover_color")==active_ink and appearance_tab.get_theme_color("font_focus_color")==active_ink,"selected tab text stays light and readable in normal, hovered, pressed and focused states")
		var tab_focus_style := closet_tab.get_theme_stylebox("focus") as StyleBoxFlat
		_check(tab_focus_style!=null and tab_focus_style.border_color==Color("#dfa458") and tab_focus_style.get_border_width(SIDE_LEFT)>=3,"keyboard focus remains a separate gold outline on page tabs")
	var fitting_frame := main.wardrobe_panel.preview.get_parent() as PanelContainer
	var expected_preview_height := 220.0 if Paper.physical_scale(main.wardrobe_panel.body)<0.9 else 265.0
	_check(is_equal_approx(main.wardrobe_panel.preview.custom_minimum_size.y,expected_preview_height),"current profile keeps the fitting mirror at its expected height")
	main.wardrobe_panel._apply_responsive_profile(0.625)
	_check(main.wardrobe_panel.preview.custom_minimum_size.y==220 and main.wardrobe_panel.controls.get_theme_constant("separation")==4,"compact profile reduces the live fitting mirror and column gaps")
	main.wardrobe_panel._apply_responsive_profile(1.0)
	_check(main.wardrobe_panel.preview.custom_minimum_size.y==265 and main.wardrobe_panel.controls.get_theme_constant("separation")==6,"resizing back restores the standard fitting-room profile")
	var fitting_frame_style := fitting_frame.get_theme_stylebox("panel") as StyleBoxFlat
	_check(fitting_frame_style!=null and fitting_frame_style.get_border_width(SIDE_BOTTOM)>=7 and fitting_frame_style.shadow_size>=6,"preview frame has a visible thick lower paper edge and bounded cast shadow")
	var frame_rect_before_motion_toggle := fitting_frame.get_global_rect()
	Paper.set_reduced_motion(true)
	_check(Paper.reduced_motion() and fitting_frame_style.shadow_size>=6 and fitting_frame.get_global_rect()==frame_rect_before_motion_toggle,"static frame depth and preview bounds remain stable when reduced motion is enabled")
	Paper.set_reduced_motion(false)
	var apply_action := main.overlay.find_child("ApplyAppearance",true,false) as Button
	var cancel_action := main.overlay.find_child("CancelFitting",true,false) as Button
	if apply_action!=null and cancel_action!=null:
		var primary_style := apply_action.get_theme_stylebox("normal") as StyleBoxFlat
		var secondary_style := cancel_action.get_theme_stylebox("normal") as StyleBoxFlat
		_check(primary_style!=null and secondary_style!=null and primary_style.bg_color!=secondary_style.bg_color,"the commit action has more visual weight than cancel")
	for direction in ["front","left","right","back"]:
		var direction_button := main.overlay.find_child("Preview_"+direction,true,false) as Button
		_check(direction_button!=null,"preview direction control exists: "+direction)
		if direction_button!=null:
			direction_button.pressed.emit()
			_check(main.wardrobe_panel.preview_direction==direction,"preview changes direction without saving: "+direction)
	var selectors: Array[OptionButton]=[]
	_collect_selectors(main.overlay,selectors)
	_check(selectors.size()==6,"free appearance exposes all six selectors")
	var original_appearance: Dictionary=progress.appearance.duplicate(true)
	if selectors.size()==6:
		selectors[3].select(1)
		selectors[3].item_selected.emit(1)
		_check(main.wardrobe_panel.draft_appearance.hair!=original_appearance.hair,"changing a selector updates the preview draft")
		_check(progress.appearance==original_appearance,"changing a selector does not save progress")
	_press_button(main.overlay,"取消試穿")
	await _frames(1)
	_check(main.modal_kind=="","cancel returns to the park")
	_check(progress.appearance==original_appearance,"cancel keeps the saved appearance")

	var key := InputEventKey.new()
	key.keycode=KEY_C
	key.physical_keycode=KEY_C
	key.pressed=true
	main._unhandled_input(key)
	await _frames(2)
	_check(main.modal_kind=="wardrobe","C opens the wardrobe without using the movement key")
	main.wardrobe_panel._show_tab("shop")
	var shop_tab := main.overlay.find_child("Tab_shop",true,false) as Button
	closet_tab=main.overlay.find_child("Tab_closet",true,false) as Button
	_check(shop_tab!=null and shop_tab.button_pressed and closet_tab!=null and not closet_tab.button_pressed,"shop tab selection follows category changes")
	_press_button(main.overlay,"珊瑚紅")
	await _frames(2)
	var focused_item := get_viewport().gui_get_focus_owner()
	_check(focused_item!=null and focused_item.name=="WardrobeItem_outfit-coral","keyboard selection restores focus to the selected clothing row")
	var selected_button := focused_item as Control
	var selected_scroll := main.wardrobe_panel.item_scroll as ScrollContainer
	await _frames(4)
	focused_item=get_viewport().gui_get_focus_owner()
	selected_button=focused_item as Control
	_check(selected_button!=null and selected_scroll.scroll_vertical>0,"post-rebuild focus scrolls the selected clothing list to its row")
	var enter := InputEventKey.new()
	enter.keycode=KEY_ENTER
	enter.physical_keycode=KEY_ENTER
	enter.pressed=true
	Input.parse_input_event(enter)
	await _frames(2)
	enter.pressed=false
	Input.parse_input_event(enter)
	await _frames(1)
	_check(progress.coins==120 and not progress.owned_clothes.has("outfit-coral"),"Enter on a selected row does not trigger purchase")
	focused_item=get_viewport().gui_get_focus_owner()
	_check(focused_item!=null and focused_item.name=="WardrobeItem_outfit-coral","Enter keeps focus on the selected clothing row")
	_check(main.wardrobe_panel.draft_equipped.outfit=="outfit-coral","shop item selection previews the outfit")
	_check(progress.coins==120 and progress.equipped.outfit=="outfit-tide","preview does not spend coins or equip the item")
	_press_button(main.overlay,"購買所選")
	await _frames(1)
	_check(progress.coins==40 and progress.owned_clothes.has("outfit-coral"),"purchase deducts the price and adds the item to the closet")
	_check(progress.equipped.outfit=="outfit-tide","purchase does not force the item to be worn")
	main.wardrobe_panel._show_tab("closet")
	_press_button(main.overlay,"珊瑚紅")
	await _frames(1)
	_press_button(main.overlay,"穿戴所選")
	await _frames(1)
	_check(progress.equipped.outfit=="outfit-coral","owned clothes can be equipped from the closet")

	progress.coins=0
	main.wardrobe_panel._show_tab("shop")
	_press_button(main.overlay,"海風花冠")
	await _frames(1)
	_check(not progress.owned_clothes.has("hat-flower") and progress.coins==0,"insufficient balance leaves ownership and coins unchanged")
	var flower: Dictionary=progress.wardrobe_item("hat-flower")
	var purchase_action := main.overlay.find_child("PurchaseSelected",true,false) as Button
	var flower_button := main.overlay.find_child("WardrobeItem_hat-flower",true,false) as Button
	var flower_state := flower_button.get_parent().get_child(flower_button.get_index()+1) as Label if flower_button!=null else null
	_check(purchase_action!=null and purchase_action.disabled,"an unaffordable selected item disables purchase")
	_check(flower_state!=null and flower_state.text=="%d 幣"%int(flower.get("price",-1)),"item list keeps the exact catalog price visible while purchase is disabled")
	if flower_state!=null:
		_check(flower_state.get_theme_color("font_color")==Paper.PRICE_INK and _contrast(flower_state.get_theme_color("font_color"),Color("#f7efd9"))>=4.5,"exact price ink contrasts with its actual paper row surface")
	_check(main.wardrobe_panel.status_label.text.contains("不足") and main.wardrobe_panel.status_label.text.contains("需要 %d 枚"%int(flower.get("price",-1))),"disabled purchase explains the actual catalog price")
	_check(_contrast(main.wardrobe_panel.status_label.get_theme_color("font_color"),Color("#f7efd9"))>=4.5,"insufficient-funds readout contrasts with the actual paper surface")
	if purchase_action!=null:
		var disabled_style := purchase_action.get_theme_stylebox("disabled") as StyleBoxFlat
		var disabled_ink := purchase_action.get_theme_color("font_disabled_color")
		_check(disabled_style!=null and _contrast(disabled_ink,disabled_style.bg_color)>=4.5,"disabled purchase label remains readable against its actual disabled surface")
	main.wardrobe_panel._cancel()
	await _frames(1)
	get_tree().root.size=Vector2i(800,600)
	await _frames(2)
	main._show_wardrobe()
	await _frames(2)
	var center := main.overlay.get_child(1) as CenterContainer
	var modal_panel := center.get_child(0) as Control
	var small_viewport := get_viewport().get_visible_rect()
	_check(small_viewport.encloses(modal_panel.get_global_rect()),"wardrobe modal fits an 800×600 viewport")
	var small_frame := main.wardrobe_panel.preview.get_parent() as Control
	_check(modal_panel.get_global_rect().encloses(small_frame.get_global_rect()),"raised fitting frame remains inside the compact wardrobe modal")
	for control_name in ["Tab_appearance","Tab_closet","Tab_shop","ApplyAppearance","CancelFitting"]:
		var key_control := main.overlay.find_child(control_name,true,false) as Control
		_check(key_control!=null and modal_panel.get_global_rect().encloses(key_control.get_global_rect()),"compact wardrobe keeps key hierarchy control inside the modal: %s modal=%s control=%s"%[control_name,str(modal_panel.get_global_rect()),str(key_control.get_global_rect()) if key_control!=null else "missing"])
	main.wardrobe_panel._cancel()
	var hud_buttons: Array[Button]=[]
	_collect_buttons(main.hud,hud_buttons)
	var viewport_rect := get_viewport().get_visible_rect()
	var hud_fits := true
	var hud_offender := ""
	for button in hud_buttons:
		if not viewport_rect.encloses(button.get_global_rect()):
			hud_fits=false
			hud_offender="%s %s viewport=%s"%[button.name,str(button.get_global_rect()),str(viewport_rect)]
			break
	_check(hud_fits,"HUD wardrobe and utility buttons stay on an 800×600 screen "+hud_offender)
	get_tree().root.size=Vector2i(1280,720)
	await _frames(2)
	_finish()

func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func _luminance(color: Color) -> float:
	var channels := [color.r,color.g,color.b]
	var linear: Array[float]=[]
	for value in channels:
		linear.append(value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4))
	return 0.2126*linear[0]+0.7152*linear[1]+0.0722*linear[2]

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _collect_selectors(node: Node, result: Array[OptionButton]) -> void:
	if node is OptionButton:
		result.append(node)
	for child in node.get_children():
		_collect_selectors(child,result)

func _collect_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button:
		result.append(node)
	for child in node.get_children():
		_collect_buttons(child,result)

func _press_button(node: Node, contains: String) -> void:
	var button := _find_button(node,contains)
	_check(button!=null,"button exists: "+contains)
	if button!=null:
		button.grab_focus()
		button.pressed.emit()

func _find_button(node: Node, contains: String) -> Button:
	if node is Button and node.text.contains(contains):
		return node
	for child in node.get_children():
		var found := _find_button(child,contains)
		if found!=null: return found
	return null

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures.append(message)

func _finish() -> void:
	if main!=null and is_instance_valid(main):
		main.audio.shutdown()
		main.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS: wardrobe UI runtime checks")
		get_tree().quit(0)
	else:
		push_error("Wardrobe UI failures: "+str(failures))
		get_tree().quit(1)
