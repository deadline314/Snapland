extends Node

const MAIN_SCENE = preload("res://game/main.tscn")
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
	_press_button(main.overlay,"珊瑚紅")
	await _frames(2)
	var focused_item := get_viewport().gui_get_focus_owner()
	_check(focused_item!=null and focused_item.name=="WardrobeItem_outfit-coral","keyboard selection restores focus to the selected clothing row")
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
	_press_button(main.overlay,"購買所選")
	await _frames(1)
	_check(not progress.owned_clothes.has("hat-flower") and progress.coins==0,"insufficient balance leaves ownership and coins unchanged")
	_check(main.wardrobe_panel.status_label.text.contains("不足"),"insufficient balance explains why purchase failed")
	main.wardrobe_panel._cancel()
	await _frames(1)
	get_tree().root.size=Vector2i(800,600)
	await _frames(2)
	main._show_wardrobe()
	await _frames(2)
	var center := main.overlay.get_child(1) as CenterContainer
	var modal_panel := center.get_child(0) as Control
	_check(get_viewport().get_visible_rect().encloses(modal_panel.get_global_rect()),"wardrobe modal fits an 800×600 viewport")
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
