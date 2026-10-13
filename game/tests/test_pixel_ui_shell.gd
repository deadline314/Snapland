extends Node

const MainScene = preload("res://game/main.tscn")
const Paper = preload("res://game/ui/paper_ui.gd")
const PAUSE_BUTTONS := [
	"PauseResumeButton", "PauseMapButton", "PauseTasksButton", "PauseAlbumButton",
	"PauseAchievementsButton", "PauseWardrobeButton", "PauseTimeButton",
	"PauseSettingsButton", "PauseTicketButton", "PauseControlsButton", "PauseQuitButton"
]
var _failures: Array[String] = []
var _main: Node

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set isolated SNAPLAND_SAVE_PATH before pixel shell test.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_check_paper_contrast()
	Progress.reset_progress()
	Progress.intro_seen=true
	Progress.settings["ui_scale"]=1.25
	_main=MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(3)
	var window := get_window()
	window.content_scale_size=Vector2i(1280,720)
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.size=Vector2i(1280,720)
	Progress.settings["ui_scale"]=1.0
	_main._refresh()
	await _frames(3)
	_main._show_settings()
	await _frames(3)
	var settings_weak: WeakRef=_settings_owner_weakref()
	_main._show_controls()
	await _frames(5)
	_check(settings_weak.get_ref()==null,"replacing Main Settings releases its RefCounted callback owner")
	_main._close()
	_main._show_wardrobe()
	await _frames(5)
	var wardrobe = _main.wardrobe_panel
	_check(not wardrobe.status_label.visible,"empty wardrobe status reserves no content row")
	for key in ["skin","species","gender","hair","hair_color","face"]:
		var selector := wardrobe.body.find_child("Appearance_"+key,true,false) as OptionButton
		_check(selector!=null and wardrobe.item_scroll.get_global_rect().encloses(selector.get_global_rect()),"normal1280 wardrobe selector %s fully fits its actual scroll viewport"%key)
	var scrollbar = wardrobe.item_scroll.get_v_scroll_bar()
	_check(scrollbar.max_value<=scrollbar.page,"six normal1280 appearance fields need no vertical scrolling")
	_main._close()
	wardrobe=null
	Progress.settings["ui_scale"]=1.25
	_main._refresh()
	for dimensions in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		window.size=dimensions
		await _frames(3)
		Progress.settings["ui_scale"]=1.0
		_main._refresh()
		var hud_base: int=_main.coin_count_label.get_theme_font_size("font_size")
		Progress.settings["ui_scale"]=1.25
		_main._refresh()
		_check(_main.coin_count_label.get_theme_font_size("font_size")>hud_base,"changing text scale immediately adapts HUD at %s"%str(dimensions))
		_main._show_wardrobe()
		await _frames(5)
		_check(is_equal_approx(get_viewport().get_visible_rect().size.x,1280.0) and is_equal_approx(get_viewport().get_visible_rect().size.y,720.0),"large-text wardrobe uses native-matching logical1280x720")
		_check(is_equal_approx(Paper.physical_scale(_main.overlay),float(dimensions.x)/1280.0),"large-text wardrobe matches actual canvas scale at %s"%str(dimensions))
		var wardrobe_panel := _main.overlay.find_child("AdaptiveMenuPanel",true,false) as Control
		_check(get_viewport().get_visible_rect().encloses(wardrobe_panel.get_global_rect()),"large-text wardrobe full frame fits %s: %s"%[str(dimensions),str(wardrobe_panel.get_global_rect())])
		for key in ["Tab_appearance","Tab_closet","Tab_shop","ApplyAppearance","CancelFitting"]:
			var action := _main.overlay.find_child(key,true,false) as Control
			_check(action!=null and get_viewport().get_visible_rect().encloses(action.get_global_rect()),"large-text wardrobe %s fits %s: %s"%[key,str(dimensions),str(action.get_global_rect()) if action!=null else "missing"])
			if action!=null: _check(action.size.y*Paper.physical_scale(action)>=43.9,"large-text wardrobe %s retains44physical target"%key)
		var selector := _main.wardrobe_panel.body.find_child("Appearance_skin",true,false) as OptionButton
		var popup := selector.get_popup()
		_check(popup.item_count==selector.item_count and popup.get_item_text(0)==selector.get_item_text(0),"styled dropdown retains real catalog items")
		_check(popup.get_theme_font_size("font_size")==selector.get_theme_font_size("font_size"),"dropdown text matches adapted selector once at %s"%str(dimensions))
		var row_height := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))+popup.get_theme_constant("v_separation")
		_check(row_height*Paper.physical_scale(selector)>=43.9,"dropdown text and row padding retain44physical height")
		popup.position=Vector2i(1200,650)
		popup.popup()
		await _frames(4)
		var popup_rect := Rect2(Vector2(popup.position),Vector2(popup.size))
		_check(get_viewport().get_visible_rect().encloses(popup_rect),"opened embedded popup actualposition/size stays inside owner viewport at %s: %s"%[str(dimensions),str(popup_rect)])
		_check(popup.max_size.y<=720,"long dropdown lists use bounded built-in scrolling")
		popup.hide()
		var popup_panel := popup.get_theme_stylebox("panel") as StyleBoxFlat
		var popup_hover := popup.get_theme_stylebox("hover") as StyleBoxFlat
		_check(popup_panel!=null and popup_hover!=null and popup_panel.get_corner_radius(CORNER_TOP_LEFT)==0 and popup_hover.border_color==Paper.GOLD,"dropdown uses square navy panel and gold highlight")
		_check(_contrast(popup.get_theme_color("font_color"),popup_panel.bg_color)>=4.5 and _contrast(popup.get_theme_color("font_hover_color"),popup_hover.bg_color)>=4.5 and _contrast(popup.get_theme_color("font_disabled_color"),popup_panel.bg_color)>=4.5,"dropdown normal hover disabled ink contrasts actual faces")
		_main._close()
		_main._show_pause()
		await _frames(3)
		_check(_main.overlay.get_child(1) is CenterContainer and _main.overlay.get_child(1).get_child(0).name=="AdaptiveMenuPanel","modal preserves real CenterContainer and panel contract")
		var check_button := CheckButton.new()
		_main.modal_body.add_child(check_button)
		Paper.adapt_menu(check_button,Paper.physical_scale(check_button))
		_check(check_button.get_theme_font_size("font_size")==ceili(20.0*1.25/Paper.physical_scale(check_button)),"fresh CheckButton text scales exactly once")
		_main.modal_body.remove_child(check_button)
		check_button.queue_free()
		_check_pause_layout(dimensions)
		var resume := _main.overlay.find_child("PauseResumeButton",true,false) as Button
		if resume != null:
			resume.grab_focus()
			_check(get_viewport().gui_get_focus_owner()==resume,"pause keyboard focus reaches resume at %s"%str(dimensions))
			var seen_focus: Array[String]=[]
			var tab := InputEventKey.new()
			tab.keycode=KEY_TAB
			tab.physical_keycode=KEY_TAB
			tab.pressed=true
			for _step in range(PAUSE_BUTTONS.size()+2):
				get_viewport().push_input(tab)
				await _frames(1)
				var owner := get_viewport().gui_get_focus_owner()
				if owner is Button and PAUSE_BUTTONS.has(owner.name): seen_focus.append(owner.name)
			for button_name in PAUSE_BUTTONS:
				_check(seen_focus.has(button_name),"real Tab navigation reaches %s at %s: %s"%[button_name,str(dimensions),str(seen_focus)])
		_main._close()
		_check(_main.modal_kind=="" and _main.hud.visible,"pause return restores the park HUD at %s"%str(dimensions))
		_main._show_pause()
		await _frames(2)
		var escape := InputEventAction.new()
		escape.action="pause"
		escape.pressed=true
		_main._unhandled_input(escape)
		_check(_main.modal_kind=="","Escape closes the pause shell at %s"%str(dimensions))
		var previous_nearest: Dictionary=_main.world.nearest.duplicate(true)
		_main.world.nearest={"id":"guide"}
		_main._show_time_panel()
		_main.world.nearest=previous_nearest
		await _frames(5)
		var postcards := _main.overlay.find_child("TimePostcardScroll",true,false) as ScrollContainer
		_check(postcards!=null and postcards.size.y*Paper.physical_scale(postcards)>80.0,"time postcard viewport has real usable height above80physical pixels at %s: %s"%[str(dimensions),str(postcards.size) if postcards!=null else "missing"])
		var summary := _main.time_panel.collection_summary as Label
		_check(summary.is_visible_in_tree() and not summary.text.is_empty() and postcards.get_global_rect().encloses(summary.get_global_rect()),"time postcard collection summary is actually visible inside content viewport")
		var collect := _main.overlay.find_child("CollectTimePostcard",true,false) as Button
		_check(collect!=null and collect.get_parent()==_main.modal_footer,"time collection action belongs to fixed modal footer")
		_check_active_layout("time",dimensions)
		await _click_return(dimensions)
		_main._show_game_rules("game-001")
		await _frames(5)
		_check_active_layout("rules",dimensions)
		await _check_page_sequence("GameRulesExtraDetails",["RulesNote0","RulesNote1","RulesNote2"],dimensions)
		for button_text in ["圖解教學","練習操作","開始遊玩","輔助挑戰"]:
			var found := false
			for action in _main.modal_footer.get_children():
				if action is Button and action.text==button_text:
					found=true
					_check(get_viewport().get_visible_rect().encloses(action.get_global_rect()),"rules fixed %s fits %s"%[button_text,str(dimensions)])
			_check(found,"rules preserves %s in fixed footer"%button_text)
		await _click_return(dimensions)
		_main._show_tasks()
		await _frames(5)
		await _check_page_sequence("TaskPages",["Task_quest-001","Task_quest-002"],dimensions)
		_check_active_layout("tasks",dimensions)
		await _click_return(dimensions)
		for page in ["_show_ticket","_show_controls"]:
			_main.call(page)
			await _frames(4)
			_check_active_layout(page,dimensions)
			await _click_return(dimensions)
		for discovery in ["explore-1","explore-2","explore-3"]:
			_main._show_exploration(discovery)
			await _frames(4)
			_check_active_layout(discovery,dimensions)
			await _click_return(dimensions)
		_main._game_finished({"game_id":"game-001","practice":false,"success":false,"score":120,"score_summary":{"rows":[{"label":"命中","amount":100},{"label":"連續加分","amount":20},{"label":"回合節奏","amount":30},{"label":"完成獎勵","amount":40},{"label":"準確操作","amount":50}]}})
		await _frames(4)
		_check_active_layout("result",dimensions)
		await _check_page_sequence("ResultScorePages",["ResultScoreRow0","ResultScoreRow1","ResultScoreRow2","ResultScoreRow3","ResultScoreRow4"],dimensions)
		await _click_return(dimensions)
		_main._launch_game("game-001",false,true)
		await _frames(5)
		_main._show_pause()
		await _frames(5)
		_check_pause_layout(dimensions)
		var lesson := _main.overlay.find_child("PauseTutorialButton",true,false) as Button
		_check(lesson!=null and get_viewport().get_visible_rect().encloses(lesson.get_global_rect()),"active-session tutorial pause action fits %s"%dimensions)
		_check(_main.overlay.get_index()>_main.session.get_index() and _main.overlay.modulate.a==1.0 and _main.overlay.self_modulate.a==1.0,"whole Main pause is drawn above active session with opaque ink")
		for label in _main.overlay.find_children("*","Label",true,false):
			if not label.is_visible_in_tree(): continue
			_check(get_viewport().get_visible_rect().encloses(label.get_global_rect()) and label.size.y+1>=label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")),"active-session pause label has full in-bounds line: %s"%label.text)
		var session_escape := InputEventKey.new()
		session_escape.keycode=KEY_ESCAPE
		session_escape.physical_keycode=KEY_ESCAPE
		session_escape.pressed=true
		get_viewport().push_input(session_escape)
		await _frames(2)
		_check(_main.modal_kind=="" and not _main.overlay.visible and _main.session!=null,"routed Escape closes only the Main session pause")
		for page_name in ["settings","map","wardrobe","ticket","tasks","album","achievements","time","controls","explore"]:
			if page_name=="album": Progress.photos["photo-welcome-game-1"]={"frames":["res://assets/ui/tutorials/park-step-01.png"]}
			if page_name=="explore": _main._show_exploration("explore-1")
			elif page_name=="time": _main._show_time_panel()
			else: _main.call("_show_"+page_name)
			await _frames(5)
			_check(_main.modal_kind==page_name,"active session opens real %s"%page_name)
			var modal_escape := InputEventKey.new()
			modal_escape.keycode=KEY_ESCAPE
			modal_escape.physical_keycode=KEY_ESCAPE
			modal_escape.pressed=true
			if page_name=="wardrobe":
				var session_selector := _main.wardrobe_panel.body.find_child("Appearance_skin",true,false) as OptionButton
				var session_popup := session_selector.get_popup()
				session_popup.popup()
				await _frames(3)
				_check(session_popup.visible,"Main detects actual open session wardrobe popup")
				Input.parse_input_event(modal_escape)
				await _frames(3)
				_check(not session_popup.visible and _main.modal_kind=="wardrobe" and _main.overlay.visible,"first Escape closes only actual wardrobe popup in active session: popup=%s modal=%s"%[session_popup.visible,_main.modal_kind])
			_check(not _main.session.is_processing_unhandled_input() and _main.session.paused,"Main modal suspends only active session unhandled input and releases held input")
			if page_name=="album":
				var photo_tile := _main.overlay.find_child("AlbumPhoto_photo-welcome-game-1",true,false) as Button
				_check(photo_tile!=null,"active-session album retains real saved-photo tile")
				if photo_tile!=null: photo_tile.pressed.emit()
				await _frames(3)
				_check(_main.overlay.find_child("PhotoViewer",true,false)!=null,"real album tile opens nested photo viewer")
				Input.parse_input_event(modal_escape)
				await _frames(3)
				_check(_main.overlay.find_child("PhotoViewer",true,false)==null and _main.modal_kind=="album","first Escape closes only actual nested photo viewer")
			get_viewport().push_input(modal_escape)
			await _frames(3)
			_check(_main.modal_kind=="" and not _main.overlay.visible and _main.session!=null and _main.session.is_processing_unhandled_input() and not _main.session.paused,"active-session %s routed Escape returns to same session at %s"%[page_name,dimensions])
			if _main.modal_kind!="": _main._close()
		_main._cancel_game()
		await _frames(2)
		_main._start_dialogue([{"speaker":"小角","text":"海風吹來了。先逛逛迎賓大道，再一起看看今天的拍貼。"}],Callable())
		await _frames(4)
		_main._dialogue_panel_resized()
		await _frames(3)
		for node_name in ["DialoguePlaque","DialogueCancel","DialogueAdvance","DialogueSubtitle"]:
			var node := _main.dialogue_panel.find_child(node_name,true,false) as Control
			_check(node!=null and get_viewport().get_visible_rect().encloses(node.get_global_rect()),"Main dialogue %s fits %s"%[node_name,str(dimensions)])
		_main._cancel_dialogue()
		await _frames(2)
		_check(_main.modal_kind=="" and not _main.world.blocked,"dialogue cancellation restores world input")
	var theme := Paper.theme()
	var disabled := theme.get_stylebox("disabled","Button") as StyleBoxFlat
	_check(_contrast(theme.get_color("font_disabled_color","Button"),disabled.bg_color)>=4.5,"default disabled button meets 4.5 contrast")
	_check(Paper.PRICE_INK==Color("#8d3c33"),"price ink keeps its light-plate contract")
	_check(Paper.text_scale()>=1.0 and Paper.text_scale()<=1.25,"text scale remains within its persisted accessible range")
	_main.audio.shutdown()
	_main.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("PASS: pixel shell pause, ticket, controls, three explorations, synthetic result and Main dialogue; geometry, Tab and pointer return at 800/1280/1920")
		get_tree().quit(0)
	else:
		for failure in _failures: push_error(failure)
		get_tree().quit(1)

func _check_pause_layout(dimensions: Vector2i) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var panel := _main.overlay.find_child("AdaptiveMenuPanel",true,false) as Control
	var actions := _main.overlay.find_child("PauseActions",true,false) as Control
	var status := _main.overlay.find_child("PauseIslandStatus",true,false) as Control
	_check(panel!=null and viewport_rect.encloses(panel.get_global_rect()),"pause frame stays inside the viewport at %s: %s"%[str(dimensions),str(panel.get_global_rect())])
	_check(viewport_rect.encloses(_main.modal_body.get_global_rect()),"pause content stays inside the viewport at %s"%str(dimensions))
	_check(viewport_rect.encloses(_main.modal_footer.get_global_rect()),"pause footer stays inside the viewport at %s"%str(dimensions))
	for button_name in PAUSE_BUTTONS:
		var button := _main.overlay.find_child(button_name,true,false) as Button
		_check(button!=null and button.visible,"%s remains visible at %s"%[button_name,str(dimensions)])
		if button==null: continue
		var rect := button.get_global_rect()
		_check(viewport_rect.encloses(rect),"%s stays inside the viewport at %s: %s"%[button_name,str(dimensions),str(rect)])
		var physical_size := button.custom_minimum_size*Paper.physical_scale(button)
		_check(physical_size.x>=44.0 and physical_size.y>=44.0,"%s retains 44px physical target at %s"%[button_name,str(dimensions)])
	var scroll: Node = _main.overlay.find_child("AdaptiveMenuScroll",true,false)
	var content_scroll: Node = _main.overlay.find_child("ContentScroll",true,false)
	_check(scroll==null and content_scroll==null,"pause shell has no scroll container at %s"%str(dimensions))
	var first := _main.overlay.find_child("PauseActions",true,false) as GridContainer
	_check(first!=null and first.columns==2,"pause menu keeps two readable action columns at %s"%str(dimensions))
	var portrait := _main.overlay.find_child("PausePlayerPortrait",true,false) as TextureRect
	_check(portrait!=null and portrait.texture!=null,"pause uses the current cached player portrait at %s"%str(dimensions))
	for status_name in ["PauseCurrentArea","PauseCurrentPhase","PauseCollectionStatus","PauseSavedStatus"]:
		_check(_main.overlay.find_child(status_name,true,false)!=null,"pause keeps %s visible at %s"%[status_name,str(dimensions)])

func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _check_active_layout(page: String, dimensions: Vector2i) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	for control in [_main.modal_body,_main.modal_footer]:
		_check(viewport_rect.encloses(control.get_global_rect()),"%s content/footer fits %s: %s"%[page,str(dimensions),str(control.get_global_rect())])
	for button in _main.overlay.find_children("*","Button",true,false):
		if not button.is_visible_in_tree(): continue
		_check(viewport_rect.encloses(button.get_global_rect()),"%s button %s fits %s: %s"%[page,button.text,str(dimensions),str(button.get_global_rect())])
		_check(button.size.y*Paper.physical_scale(button)>=43.9,"%s button retains actual 44px target"%page)
		button.grab_focus()
		var tab := InputEventKey.new()
		tab.keycode=KEY_TAB
		tab.pressed=true
		get_viewport().push_input(tab)
		_check(get_viewport().gui_get_focus_owner()!=null,"%s Tab keeps active focus"%page)
	var content_viewport := _main.overlay.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
	_check(content_viewport==null or (content_viewport.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and content_viewport.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED),"%s has no manual outer/content scroll"%page)

func _click_return(dimensions: Vector2i) -> void:
	var button := _main.overlay.find_child("MenuBackButton",true,false) as Button
	if button==null:
		_check(false,"page has fixed return action")
		return
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		get_viewport().push_input(event,true)
		await _frames(1)
	_check(_main.modal_kind=="" and _main.hud.visible,"actual return click restores HUD at %s"%str(dimensions))


func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func _luminance(color: Color) -> float:
	var channels := Vector3(color.r,color.g,color.b)
	for index in range(3):
		channels[index]=channels[index]/12.92 if channels[index]<=0.04045 else pow((channels[index]+0.055)/1.055,2.4)
	return channels.dot(Vector3(0.2126,0.7152,0.0722))

func _check_paper_contrast() -> void:
	var pixel_theme := Paper.theme()
	for icon_key in ["checked","unchecked","checked_disabled","unchecked_disabled","checked_mirrored","unchecked_mirrored","checked_disabled_mirrored","unchecked_disabled_mirrored"]:
		_check(pixel_theme.get_icon(icon_key,"CheckButton").get_size()==Vector2(24,24),"pixel toggle %s has authored24px icon"%icon_key)
	for icon_key in ["grabber","grabber_highlight","grabber_disabled"]:
		_check(pixel_theme.get_icon(icon_key,"HSlider").get_size()==Vector2(24,24),"pixel slider %s has authored24px icon"%icon_key)
	for role in ["primary","secondary","tab_selected","tab_idle"]:
		var button := Button.new()
		button.theme=Paper.theme()
		Paper.set_button_role(button,role)
		for state in ["normal","hover","pressed","disabled"]:
			var face := button.get_theme_stylebox(state) as StyleBoxFlat
			var ink_key := "font_color" if state=="normal" else "font_%s_color"%state
			_check(face!=null and _contrast(button.get_theme_color(ink_key),face.bg_color)>=4.5,"%s %s actual foreground/background contrast meets4.5"%[role,state])
		button.free()
	for old_ink in [Paper.DEEP_TEAL,Color("#52605d")]:
		var label := Paper.label("提示",18,old_ink)
		_check(_contrast(label.get_theme_color("font_color"),Paper.DEEP)>=4.5,"legacy dark hint uses readable ink on navy")
		label.free()
	var price := Paper.label("120 幣",18,Paper.PRICE_INK)
	_check(price.get_theme_color("font_color")==Paper.PRICE_INK,"price keeps deep ink for its light plate")
	price.free()

func _check_page_sequence(pager_name: String, expected: Array, dimensions: Vector2i) -> void:
	var pager := _main.overlay.find_child(pager_name,true,false) as VBoxContainer
	_check(pager!=null,"%s provides real paged content"%pager_name)
	if pager==null: return
	var seen: Array[String]=[]
	for index in range(int(pager.get_meta("page_count"))):
		var view := pager.find_child("PageContent",true,false) as Control
		var labels: Array[Label]=[]
		for label in view.find_children("*","Label",true,false):
			if not label.is_visible_in_tree(): continue
			labels.append(label)
			_check(view.get_global_rect().encloses(label.get_global_rect()),"%s page%s label fits real content viewport at%s: %s"%[pager_name,index,dimensions,label.get_global_rect()])
			_check(label.size.y+0.1>=label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")),"%s preserves readable full text line height"%pager_name)
		for first in range(labels.size()):
			for second in range(first+1,labels.size()):
				_check(not labels[first].get_global_rect().intersects(labels[second].get_global_rect()),"%s paged text lines never overlap"%pager_name)
		for name in expected:
			var item := view.find_child(name,true,false) as Control
			if item!=null and item.is_visible_in_tree(): seen.append(str(name))
		var next := _main.overlay.find_child(pager_name+"Next",true,false) as Button
		if index<int(pager.get_meta("page_count"))-1:
			_check(next!=null and not next.disabled and next.is_visible_in_tree(),"%s next page remains operable"%pager_name)
			await _click_control(next)
			await _frames(4)
			_check(int(pager.get_meta("page_index"))==index+1,"actual pointer flips %s content page"%pager_name)
	for name in expected: _check(seen.has(str(name)),"%s retains readable item%s across all pages"%[pager_name,name])
	for scroll in _main.overlay.find_children("*","ScrollContainer",true,false):
		_check(scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"%s has no active scroll navigation"%pager_name)

func _click_control(control: Control) -> void:
	if control==null: return
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=control.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		get_viewport().push_input(event,true)
		await _frames(1)

# Keep callback inspection out of the coroutine frame: only the weak reference
# may survive while queued controls and their signal connections are freed.
func _settings_owner_weakref() -> WeakRef:
	var tab := _main.overlay.find_child("SettingsTab_audio",true,false) as Button
	var connections := tab.get_signal_connection_list("pressed")
	var callback: Callable=connections[0]["callable"]
	var owner := callback.get_object() as RefCounted
	_check(owner!=null,"Main Settings callbacks have a real panel owner")
	var result: WeakRef=weakref(owner)
	owner=null
	callback=Callable()
	connections.clear()
	tab=null
	return result
