extends Node

const MAIN_SCENE = preload("res://game/main.tscn")
const Paper = preload("res://game/ui/paper_ui.gd")
var _failures: Array[String] = []
var _main: Node
var _progress: Node
var _thumbnail_path := ""

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running travel/book UI checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_progress=get_tree().root.get_node_or_null("Progress")
	_check(_progress!=null,"Progress autoload exists")
	if _progress==null:
		_finish(); return
	_progress.reset_progress()
	_progress.intro_seen=true
	_thumbnail_path=OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()+"/album-test-frame.png"
	var image := Image.create(32,18,false,Image.FORMAT_RGBA8)
	image.fill(Color("#d97966"))
	image.save_png(_thumbnail_path)
	_progress.photos["photo-welcome-game-1"]={"frames":[_thumbnail_path]}
	_progress.photos["photo-welcome-game-2"]={"frames":[_thumbnail_path+".missing"]}
	_progress.photos["postcard-time-dawn"]={"time_phase":"dawn","frames":[_thumbnail_path]}
	_progress.achievements["ACH_GAME_001"]=true
	_main=MAIN_SCENE.instantiate()
	get_tree().root.add_child(_main)
	await _frames(3)
	await _test_empty_album()
	await _test_map()
	await _test_album()
	await _test_achievements()
	_test_motion_hook()
	await _test_small_physical_menus()
	_finish()

func _test_empty_album() -> void:
	var original_photos: Dictionary=_progress.photos.duplicate(true)
	_progress.photos.clear()
	_main._show_album()
	await _frames(2)
	var empty_state := _main.overlay.find_child("AlbumCollectionState",true,false) as Label
	_check(empty_state!=null and empty_state.visible and empty_state.text.contains("還是空白"),"a new collection shows an explicit first-photo state")
	_main._close()
	_progress.photos=original_photos
	_main._refresh()

func _test_map() -> void:
	_main._show_map()
	await _frames(2)
	_check(_main.modal_kind=="map","map opens through the existing ticket callback")
	var hub := _main.overlay.find_child("MapHub",true,false) as Button
	var stations := _find_named_buttons(_main.overlay,"MapStop_game-")
	var gates := _find_named_buttons(_main.overlay,"MapGate_")
	_check(hub!=null,"map labels the sea-wind harbor hub")
	_check(stations.size()==12,"map exposes all twelve real welcome-game stations")
	_check(gates.size()==9,"map exposes the other nine park entrances")
	var map_detail: Node=_main.overlay.find_child("DestinationDetails",true,false)
	_check(map_detail!=null,"map has a readable destination details panel")
	var original_position: Vector3=_main.world.avatar.global_position
	var harbor := _main.overlay.find_child("MapGate_harbor",true,false) as Button
	if harbor!=null:
		await _activate(harbor)
		_check(_has_label(map_detail,"6 張") and _has_label(map_detail,"準備中"),"harbor detail explains its actual threshold and unavailable state")
		_check(_main.world.avatar.global_position==original_position,"selecting a map destination does not teleport the avatar")
	var station := _main.overlay.find_child("MapStop_game-010",true,false) as Button
	if station!=null:
		await _activate(station)
		_check(_has_label(map_detail,"泡泡"),"station detail shows the real game goal and instructions")
	_main._close()
	for review_case in [[Vector2i(800,600),1.0],[Vector2i(1280,720),1.0],[Vector2i(800,600),1.25]]:
		var viewport_size: Vector2i=review_case[0]
		_progress.set_setting("ui_scale",review_case[1])
		get_tree().root.size=viewport_size
		await _frames(2)
		_main._show_map()
		await _frames(2)
		var canvas := _main.overlay.find_child("IslandChartCanvas",true,false) as Control
		var all_stops := _find_named_buttons(_main.overlay,"MapStop_game-")
		var all_gates := _find_named_buttons(_main.overlay,"MapGate_")
		var contained := canvas!=null and all_stops.size()==12 and all_gates.size()==9
		if canvas!=null:
			for button in all_stops+all_gates:
				if not button.is_visible_in_tree() or button.size.x<44.0 or button.size.y<44.0 or button.focus_mode!=Control.FOCUS_ALL or not canvas.get_global_rect().encloses(button.get_global_rect()):
					contained=false
					break
		var separated := true
		for first in range(all_stops.size()):
			for second in range(first+1,all_stops.size()):
				if all_stops[first].get_global_rect().intersects(all_stops[second].get_global_rect()): separated=false
		var map_hub := _main.overlay.find_child("MapHub",true,false) as Button
		var harbor_clear := map_hub!=null
		for stop in all_stops:
			if map_hub!=null and stop.get_global_rect().intersects(map_hub.get_global_rect()): harbor_clear=false
		_check(harbor_clear,"map harbor and station hit targets stay disjoint at %dx%d" % [viewport_size.x,viewport_size.y])
		var gate_padding := canvas!=null
		for gate in all_gates:
			if canvas!=null and not canvas.get_global_rect().grow(-8.0).encloses(gate.get_global_rect()): gate_padding=false
		_check(gate_padding,"map future gates retain eight pixels of shadow padding at %dx%d" % [viewport_size.x,viewport_size.y])
		var gates_separated := true
		for first in range(all_gates.size()):
			for second in range(first+1,all_gates.size()):
				if all_gates[first].get_global_rect().intersects(all_gates[second].get_global_rect()): gates_separated=false
		_check(gates_separated,"all nine future gate targets remain distinct at %dx%d, text scale %.2f" % [viewport_size.x,viewport_size.y,float(review_case[1])])
		var gate_copy_fits := true
		var selection_fits := true
		for gate in all_gates:
			var ink_width := gate.get_theme_font("font").get_string_size(gate.text,HORIZONTAL_ALIGNMENT_LEFT,-1,gate.get_theme_font_size("font_size")).x
			if ink_width+gate.get_theme_stylebox("normal").get_minimum_size().x>gate.size.x: gate_copy_fits=false
			await _activate(gate)
			await _frames(3)
			if not _all_visible_rects_fit(_main.overlay,get_tree().root.get_visible_rect()): selection_fits=false
			for target in all_gates:
				if not canvas.get_global_rect().grow(-8.0).encloses(target.get_global_rect()): selection_fits=false
				for other in all_gates:
					if other!=target and target.get_global_rect().intersects(other.get_global_rect()): selection_fits=false
		_check(gate_copy_fits,"future gate labels fit their actual font and target at %dx%d" % [viewport_size.x,viewport_size.y])
		_check(selection_fits,"selecting every future gate keeps map details and return visible at %dx%d" % [viewport_size.x,viewport_size.y])
		var station_details_fit := true
		for station_button in all_stops:
			await _activate(station_button)
			await _frames(3)
			if not _all_visible_rects_fit(_main.overlay,get_tree().root.get_visible_rect()): station_details_fit=false
		_check(station_details_fit,"all twelve station descriptions preserve the map and return control at %dx%d" % [viewport_size.x,viewport_size.y])
		_check(separated,"map station hit targets never overlap at %dx%d" % [viewport_size.x,viewport_size.y])
		_check(contained,"map stations and entrances stay visible, keyboard focusable, at least 44px and inside the island chart at %dx%d" % [viewport_size.x,viewport_size.y])
		_main._close()
	_progress.set_setting("ui_scale",1.0)
	get_tree().root.size=Vector2i(1280,720)
	_main._refresh()
	await _frames(3)

func _test_album() -> void:
	_main._show_album()
	await _frames(2)
	var grid: Node = _main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
	_check(grid!=null and grid.get_child_count()==18,"book keeps all eighteen ordinary photo IDs in its actual paged grid")
	if grid!=null:
		var visible_count := 0
		for child in grid.get_children():
			if child.visible: visible_count+=1
		var readable_cards := true
		for card in grid.get_children():
			if not card.visible: continue
			var title := card.find_child("AlbumPhotoTitle",true,false) as Label
			var status := card.find_child("AlbumPhotoStatus",true,false) as Label
			var frame := card.find_child("SavedPhotoFrame",true,false) as Control
			var physical_scale := Paper.physical_scale(card)
			if title==null or title.size.x*physical_scale<180 or status==null or not status.visible or frame==null or card.size.x*physical_scale<232 or frame.size.x*physical_scale<219 or frame.size.y*physical_scale<123 or card.size.y*physical_scale>205 or card.size.y*physical_scale<200: readable_cards=false
			if title!=null and not card.get_global_rect().encloses(title.get_global_rect()): readable_cards=false
			if status!=null and not card.get_global_rect().encloses(status.get_global_rect()): readable_cards=false
		_check(readable_cards,"four album cards keep at least 232×200px, 16:9 photos, and readable captions")
		_check(visible_count==4,"the ordinary collection shows one four-photo row at wide physical widths")
		var album_scroll := _main.overlay.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
		var viewport_rect := get_tree().root.get_visible_rect()
		var album_clip := album_scroll.get_global_rect().intersection(viewport_rect) if album_scroll!=null else Rect2()
		var spread_fits: bool = album_scroll!=null and grid.columns==4
		var spread_surface := _main.overlay.find_child("AlbumBookSpread",true,false) as Control
		for element_name in ["AlbumTab_normal","AlbumTab_devil","AlbumTab_time","AlbumPreviousPage","AlbumNextPage","AlbumPhotoDetails","AlbumPageLabel"]:
			var element := _main.overlay.find_child(element_name,true,false) as Control
			if element==null or not viewport_rect.encloses(element.get_global_rect()) or not album_clip.encloses(element.get_global_rect()):
				spread_fits=false
				if element!=null: print("ALBUM_1280_CONTROL_OUTSIDE_SCROLL ",element.name," ",element.get_global_rect()," clip=",album_clip)
		for card_index in range(4):
			if card_index>=grid.get_child_count():
				spread_fits=false
				continue
			var card := grid.get_child(card_index) as Control
			var title := card.find_child("AlbumPhotoTitle",true,false) as Control
			var status := card.find_child("AlbumPhotoStatus",true,false) as Control
			if not album_clip.encloses(card.get_global_rect()) or spread_surface==null or not spread_surface.get_global_rect().encloses(card.get_global_rect()) or title==null or status==null or not card.get_global_rect().encloses(title.get_global_rect()) or not card.get_global_rect().encloses(status.get_global_rect()) or not album_clip.encloses(title.get_global_rect()) or not album_clip.encloses(status.get_global_rect()):
				spread_fits=false
				print("ALBUM_1280_CARD_CONTENT_CLIPPED ",card_index," card=",card.get_global_rect()," title=",title.get_global_rect() if title!=null else Rect2()," status=",status.get_global_rect() if status!=null else Rect2()," scroll_clip=",album_clip)
			if card_index>0 and not is_equal_approx(card.position.y,(grid.get_child(0) as Control).position.y): spread_fits=false
		_check(spread_fits,"wide album keeps four complete cards, category/detail/page controls inside the book paper and actual Scroll clip")
		var measured_frame := grid.get_child(0).find_child("SavedPhotoFrame",true,false) as Control
		print("ALBUM_FRAME_PHYSICAL ",measured_frame.size*Paper.physical_scale(measured_frame))
		_check(grid.get_child(0).name=="AlbumPhoto_photo-welcome-game-1","earned ordinary photos rise first without changing their stable catalog IDs")
		var earned := grid.find_child("AlbumPhoto_photo-welcome-game-1",true,false)
		var saved_frame := earned.find_child("SavedPhotoFrame",true,false) if earned!=null else null
		_check(saved_frame!=null and saved_frame.get_child_count()==1 and saved_frame.get_child(0) is TextureRect,"a saved readable photo appears as its real thumbnail")
		var saved_texture_rect := saved_frame.get_child(0) as TextureRect if saved_frame!=null and saved_frame.get_child_count()==1 else null
		_check(saved_texture_rect!=null and saved_texture_rect.size_flags_horizontal==Control.SIZE_EXPAND_FILL and saved_texture_rect.size_flags_vertical==Control.SIZE_EXPAND_FILL,"real photos expand into the full saved-photo frame while preserving aspect ratio")
		if saved_texture_rect!=null and saved_texture_rect.texture is Texture2D:
			var texture_aspect := saved_texture_rect.texture.get_width()/float(saved_texture_rect.texture.get_height())
			var texture_area := saved_texture_rect.size*Paper.physical_scale(saved_texture_rect)
			var fitted_width := minf(texture_area.x,texture_area.y*texture_aspect)
			var fitted_height := fitted_width/texture_aspect
			print("ALBUM_SAVED_IMAGE_PHYSICAL ",Vector2(fitted_width,fitted_height))
			_check(saved_texture_rect.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and is_equal_approx(texture_aspect,16.0/9.0) and fitted_width>=219 and fitted_height>=123,"album texture uses a complete centered 16:9 image at 220×124 minimum without crop or distortion")
		else:
			_check(false,"album texture uses a complete centered 16:9 image at 220×124 minimum without crop or distortion")
		var corrupt := grid.find_child("AlbumPhoto_photo-welcome-game-2",true,false)
		_check(corrupt!=null and _has_label(corrupt,"暫時看不清楚"),"an unreadable saved image falls back to an honest labeled print frame")
		var normal_next := _main.overlay.find_child("AlbumNextPage",true,false) as Button
		if normal_next!=null:
			await _activate(normal_next)
			_check(_has_label(_main.overlay,"第 2 / 5 頁") and grid.get_child_count()==18,"all ordinary IDs remain browsable across five four-slot pages")
			var normal_previous := _main.overlay.find_child("AlbumPreviousPage",true,false) as Button
			if normal_previous!=null: await _activate(normal_previous)
	var devil_tab := _main.overlay.find_child("AlbumTab_devil",true,false) as Button
	if devil_tab!=null:
		await _activate(devil_tab)
		grid=_main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
		_check(grid!=null and grid.get_child_count()==12,"devil album page uses the twelve existing devil photo IDs")
		var devil_detail := _main.overlay.find_child("AlbumPhotoDetails",true,false) as Label
		_check(devil_detail!=null and devil_detail.text.contains("小惡魔拍貼"),"changing to the devil category clears the previous ordinary-photo detail")
		_check(_has_label(grid,_first_devil_hint()),"locked devil print explains its real special condition")
		var next := _main.overlay.find_child("AlbumNextPage",true,false) as Button
		if next!=null:
			await _activate(next)
			_check(_has_label(_main.overlay,"第 2 / 3 頁"),"book page control advances to the next four devil prints")
	var time_tab := _main.overlay.find_child("AlbumTab_time",true,false) as Button
	if time_tab!=null:
		await _activate(time_tab)
		grid=_main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
		_check(grid!=null and grid.get_child_count()==4,"time book shows four canonical TimeOfDay postcard IDs")
		_check(grid!=null and grid.find_child("AlbumPhoto_postcard-time-dawn",true,false)!=null,"time postcard retains the canonical dawn photo ID")
		var time_detail := _main.overlay.find_child("AlbumPhotoDetails",true,false) as Label
		_check(time_detail!=null and time_detail.text.contains("四時明信片"),"changing to the time category clears the previous devil-photo detail")
	_main._close()

func _test_achievements() -> void:
	_main._show_achievements()
	await _frames(2)
	var grid := _main.overlay.find_child("MinigameStampGrid",true,false) as GridContainer
	_check(grid!=null and grid.get_child_count()==12,"achievement page contains twelve stable minigame stamp IDs")
	if grid!=null:
		var readable := true
		var first := grid.get_child(0) as Control
		var last := grid.get_child(grid.columns-1) as Control
		var coverage := (last.get_global_rect().end.x-first.get_global_rect().position.x)/grid.size.x
		for card in grid.get_children():
			var caption := card.find_child("StampCaption",true,false) as Label
			var condition := card.find_child("StampCondition",true,false) as Label
			var physical_width: float=card.size.x*Paper.physical_scale(card)
			if physical_width<199.9 or physical_width>300.1 or caption.size.x*Paper.physical_scale(caption)<139.9 or caption.get_line_count()>2 or condition.get_line_count()>2: readable=false
		_check(readable and coverage>0.95,"full-size stamp rows fill available width with 200–300px cards and readable two-line captions")
	var unlocked: Node=_main.overlay.find_child("AchievementStamp_ACH_GAME_001",true,false)
	_check(unlocked!=null and _has_label(unlocked,"已蓋章"),"earned achievement is shown as a stamped record")
	var milestones: Node=_main.overlay.find_child("ParkMilestoneStampSection",true,false)
	_check(milestones!=null and milestones.get_child_count()==5,"achievement page groups four island milestones after game stamps")
	_check(_has_label(milestones,"十區共 120 張小惡魔拍貼"),"all-devil milestone states its unchanged 120-card requirement")
	_main._close()

func _test_motion_hook() -> void:
	_progress.settings["reduced_motion"]=true
	_main._refresh()
	_check(Paper.reduced_motion(),"saved reduce-motion preference reaches the paper UI hook")
	_check(is_zero_approx(Paper.motion_duration_seconds(0.12)),"reduced motion skips optional UI transitions")
	_progress.settings["reduced_motion"]=false
	_main._refresh()
	_check(not Paper.reduced_motion() and is_equal_approx(Paper.motion_duration_seconds(0.12),0.12),"normal motion preference preserves requested short duration")

func _all_visible_rects_fit(node: Node, viewport_rect: Rect2) -> bool:
	if node is Control and node.is_visible_in_tree() and not viewport_rect.encloses(node.get_global_rect()):
		print("HUD RECT FAIL: ",node.get_path()," ",node.get_global_rect())
		return false
	for child in node.get_children():
		if not _all_visible_rects_fit(child,viewport_rect): return false
	return true

func _test_small_physical_menus() -> void:
	var window := get_tree().root
	_check(_all_visible_rects_fit(_main.hud,window.get_visible_rect()),"all visible HUD rectangles including empty toast and quest fit at 1280px")
	var previous_scale_size := window.content_scale_size
	var previous_mode := window.content_scale_mode
	var previous_aspect := window.content_scale_aspect
	window.content_scale_size=Vector2i(1280,720)
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.size=Vector2i(800,450)
	await _frames(3)
	_check(_all_visible_rects_fit(_main.hud,window.get_visible_rect()),"all visible HUD rectangles including empty toast and quest fit at physical800px")
	var banner := _main.hud.get_node("ParkKeepsakeBanner") as Control
	_check(window.get_visible_rect().encloses(banner.get_global_rect()) and not banner.get_global_rect().intersects(_main.ticket_button.get_global_rect()),"small physical HUD keeps stats and voyage ticket inside viewport and apart")
	_check(_main.ticket_button.size.y*Paper.physical_scale(_main.ticket_button)>=43.9 and _main.area_label.get_theme_font_size("font_size")*Paper.physical_scale(_main.area_label)>=20.0,"small physical HUD preserves 44px ticket and readable island heading")
	_check(is_equal_approx(Paper.physical_scale(_main.overlay),0.625),"small-window validation uses actual 0.625 viewport transform")
	for kind in ["tasks","map","album","achievements","game_info"]:
		if kind=="game_info": _main._show_game_info("game-009")
		else: _main.call("_show_"+kind)
		await _frames(6)
		var panel := _main.overlay.find_child("AdaptiveMenuPanel",true,false) as Control
		var scroll := _main.overlay.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
		if kind=="game_info":
			var invitation := _main.overlay.find_child("InviteCard",true,false) as Control
			_check(invitation!=null and window.get_visible_rect().encloses(invitation.get_global_rect()) and _all_visible_rects_fit(invitation,window.get_visible_rect()),"compact invitation and every visible control fit actual 800px window")
		else:
			_check(panel!=null and scroll!=null and window.get_visible_rect().encloses(panel.get_global_rect()) and window.get_visible_rect().encloses(scroll.get_global_rect()),"bounded modal with scrolling content fits actual 800px window: "+kind)
		if kind=="album":
			window.content_scale_size=previous_scale_size
			window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
			window.size=Vector2i(800,600)
			await _frames(4)
			var grid: Node = _main.overlay.find_child("AlbumPhotoGrid",true,false)
			var album_scroll := _main.overlay.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
			var small_spread_surface := _main.overlay.find_child("AlbumBookSpread",true,false) as Control
			var category_tabs_reachable := album_scroll!=null
			for tab_name in ["AlbumTab_normal","AlbumTab_devil","AlbumTab_time"]:
				var tab := _main.overlay.find_child(tab_name,true,false) as Control
				if tab==null or not album_scroll.get_global_rect().encloses(tab.get_global_rect()): category_tabs_reachable=false
			_check(category_tabs_reachable,"small album keeps all three category tabs reachable at the top of its scroll region")
			var first_row_complete := true
			if grid is GridContainer and grid.columns!=2: first_row_complete=false
			for index in range(2):
				var card := grid.get_child(index) as Control
				var frame := card.find_child("SavedPhotoFrame",true,false) as Control
				var title := card.find_child("AlbumPhotoTitle",true,false) as Control
				var status := card.find_child("AlbumPhotoStatus",true,false) as Control
				if not album_scroll.get_global_rect().encloses(card.get_global_rect()) or small_spread_surface==null or not small_spread_surface.get_global_rect().encloses(card.get_global_rect()) or frame==null or frame.size.x*Paper.physical_scale(frame)<219 or frame.size.y*Paper.physical_scale(frame)<123 or title==null or status==null or not card.get_global_rect().encloses(title.get_global_rect()) or not card.get_global_rect().encloses(status.get_global_rect()) or not album_scroll.get_global_rect().encloses(title.get_global_rect()) or not album_scroll.get_global_rect().encloses(status.get_global_rect()): first_row_complete=false
				if index==0 and frame!=null and frame.get_child_count()==1 and frame.get_child(0) is TextureRect:
					var image_rect := frame.get_child(0) as TextureRect
					if image_rect.texture is Texture2D:
						var aspect := image_rect.texture.get_width()/float(image_rect.texture.get_height())
						var image_area := image_rect.size*Paper.physical_scale(image_rect)
						var image_width := minf(image_area.x,image_area.y*aspect)
						if image_width<219 or image_width/aspect<123: first_row_complete=false
					else: first_row_complete=false
			var measured_small_frame := (grid.get_child(0) as Control).find_child("SavedPhotoFrame",true,false) as Control
			print("ALBUM_SMALL_FRAME_PHYSICAL ",measured_small_frame.size*Paper.physical_scale(measured_small_frame))
			_check(first_row_complete,"small album initially shows a complete two-card first row with full-size photos, captions, and status")
			if album_scroll!=null:
				var bar := album_scroll.get_v_scroll_bar()
				album_scroll.scroll_vertical=roundi(bar.max_value)
				await _frames(3)
				var previous_page := _main.overlay.find_child("AlbumPreviousPage",true,false) as Control
				var next_page := _main.overlay.find_child("AlbumNextPage",true,false) as Button
				var page_label := _main.overlay.find_child("AlbumPageLabel",true,false) as Control
				var lower_row_complete: bool = grid is GridContainer and grid.columns==2 and previous_page!=null and next_page!=null and page_label!=null and album_scroll.get_global_rect().encloses(previous_page.get_global_rect()) and album_scroll.get_global_rect().encloses(next_page.get_global_rect()) and album_scroll.get_global_rect().encloses(page_label.get_global_rect())
				for index in [2,3]:
					var card := grid.get_child(index) as Control
					var title := card.find_child("AlbumPhotoTitle",true,false) as Control
					var status := card.find_child("AlbumPhotoStatus",true,false) as Control
					if not album_scroll.get_global_rect().encloses(card.get_global_rect()) or small_spread_surface==null or not small_spread_surface.get_global_rect().encloses(card.get_global_rect()) or title==null or status==null or not card.get_global_rect().encloses(title.get_global_rect()) or not card.get_global_rect().encloses(status.get_global_rect()) or not album_scroll.get_global_rect().encloses(title.get_global_rect()) or not album_scroll.get_global_rect().encloses(status.get_global_rect()): lower_row_complete=false
				_check(bar.max_value>0 and lower_row_complete,"small album scroll reaches a fully visible second row and complete page navigation without hiding category navigation")
				album_scroll.scroll_vertical=0
		if kind=="achievements":
			var grid := _main.overlay.find_child("MinigameStampGrid",true,false) as GridContainer
			var first := grid.get_child(0) as Control
			var last := grid.get_child(grid.columns-1) as Control
			var coverage := (last.get_global_rect().end.x-first.get_global_rect().position.x)/grid.size.x
			var captions_readable := true
			for card in grid.get_children():
				var caption := card.find_child("StampCaption",true,false) as Label
				var condition := card.find_child("StampCondition",true,false) as Label
				if card.size.x*Paper.physical_scale(card)<199.9 or card.size.x*Paper.physical_scale(card)>300.1 or caption.size.x*Paper.physical_scale(caption)<139.9 or caption.get_line_count()>2 or condition.get_line_count()>2: captions_readable=false
			_check(coverage>0.95 and captions_readable,"small stamp rows fill available width with readable captions and at most two lines")
		var all_buttons := _find_named_buttons(_main.overlay,"")
		var physical_targets := true
		for button in all_buttons:
			var scale_factor := Paper.physical_scale(button)
			if button.size.x*scale_factor<43.9 or button.size.y*scale_factor<43.9: physical_targets=false
		_check(physical_targets,"physical menu targets remain at least 44px: "+kind)
		_main._close()
		if kind=="album":
			window.content_scale_aspect=previous_aspect
			window.size=Vector2i(800,450)
			await _frames(3)
	window.content_scale_size=previous_scale_size
	window.content_scale_mode=previous_mode
	window.size=Vector2i(1280,720)
	await _frames(3)

func _find_named_buttons(node: Node, prefix: String) -> Array[Button]:
	var result: Array[Button]=[]
	if node is Button and node.name.begins_with(prefix):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_named_buttons(child,prefix))
	return result

## Reads the authored condition so the check follows data edits instead of a stale copy.
func _first_devil_hint() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/welcome_games.json"))
	if not (parsed is Array) or parsed.is_empty() or not (parsed[0] is Dictionary): return "<missing welcome game data>"
	var hint := str(parsed[0].get("devil_hint",""))
	return hint if not hint.is_empty() else "<missing devil hint>"

func _has_label(node: Node, value: String) -> bool:
	if node==null: return false
	if node is Label and node.text.contains(value): return true
	if node is Button and node.text.contains(value): return true
	for child in node.get_children():
		if _has_label(child,value): return true
	return false

func _activate(button: Button) -> void:
	_check(button.is_visible_in_tree() and button.focus_mode==Control.FOCUS_ALL,"tested book/map control is visible and keyboard focusable")
	button.grab_focus()
	await _frames(1)
	var event := InputEventAction.new()
	event.action="ui_accept"
	event.pressed=true
	Input.parse_input_event(event)
	await _frames(1)
	event=InputEventAction.new()
	event.action="ui_accept"
	event.pressed=false
	Input.parse_input_event(event)
	await _frames(2)

func _frames(count: int) -> void:
	for _i in count: await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		_failures.append(message)

func _finish() -> void:
	if _main!=null and is_instance_valid(_main):
		if _main.session!=null and is_instance_valid(_main.session):
			_main.session.queue_free()
			_main.session=null
		_main.audio.shutdown()
		_main.world.set_process(false)
		_main.world.set_physics_process(false)
		# Match normal quit: let the audio server consume stop commands first.
		await get_tree().create_timer(0.15).timeout
		_main.queue_free()
	for _frame in 3:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

	if _failures.is_empty():
		print("PASS: travel map, paged collection book, achievement stamps, and reduce-motion hook")
		get_tree().quit(0)
	else:
		push_error("Travel/book UI failures: "+str(_failures))
		get_tree().quit(1)
