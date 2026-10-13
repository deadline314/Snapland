extends Node

const Paper = preload("res://game/ui/paper_ui.gd")
const MainScene = preload("res://game/main.tscn")
const AlbumScript = preload("res://game/ui/collection_book_panel.gd")
const MapScript = preload("res://game/ui/island_map_panel.gd")
const AchievementScript = preload("res://game/ui/achievement_stamp_book.gd")
const TutorialScript = preload("res://game/ui/tutorial_panel.gd")

class FakeProgress extends Node:
	const ZONES := ["welcome", "harbor", "forest", "desert", "mountain", "snow", "volcano", "sky", "ruins", "moon"]
	var photos: Dictionary = {}
	var achievements: Dictionary = {}
	var quests: Dictionary = {}
	var coins := 120
	func normal_count() -> int:
		var count := 0
		for key in photos:
			if str(key).begins_with("photo-welcome-game-"):
				count += 1
		return count
	func devil_count(zone: String = "welcome") -> int:
		var count := 0
		for key in photos:
			if str(key).begins_with("photo-%s-devil-" % zone):
				count += 1
		return count
	func _read_game_photo_image(_photo_id: String, _path: String, _cache: Dictionary) -> Image:
		var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
		image.fill(Color("#4a9bba"))
		return image
	func _read_game_photo_original_image(_photo_id: String, _path: String) -> Image:
		var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
		image.fill(Color("#80c7d4"))
		return image

var _failures: Array[String] = []
var _overlay: Control
var _menu_content: VBoxContainer
var _progress: FakeProgress
var _original_record: Dictionary

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated absolute profile before collection UI checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_progress = FakeProgress.new()
	add_child(_progress)
	_progress.achievements["ACH_GAME_001"] = true
	_overlay = Control.new()
	_overlay.name = "CollectionReviewOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var panel := PanelContainer.new()
	panel.name = "AdaptiveMenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay.add_child(panel)
	_menu_content = VBoxContainer.new()
	_menu_content.name = "AdaptiveMenuContent"
	_menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_menu_content)
	var window := get_window()
	window.content_scale_size = Vector2i(1280, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.size = Vector2i(1280, 720)
	await _frames(3)
	_check_paper_depth()
	await _check_album()
	await _check_map()
	await _check_achievements()
	await _check_tutorial()
	await _check_main_album_host()
	await _finish()

func _check_paper_depth() -> void:
	var button := Button.new()
	Paper.set_button_role(button, "primary")
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
	_check(normal != null and normal.corner_radius_top_left == 0 and normal.shadow_size > 0, "paper buttons use square hard pixel edges and a cast shadow")
	_check(hover != null and hover.shadow_size >= normal.shadow_size and pressed != null and pressed.shadow_size == 0, "hover raises paper controls and press collapses their depth")
	button.queue_free()
	var selector := OptionButton.new()
	selector.position = Vector2(1080, 630)
	selector.custom_minimum_size = Vector2(160, 44)
	for index in range(3): selector.add_item("短選項 %d" % (index + 1))
	_overlay.add_child(selector)
	Paper.set_text_scale(1.25)
	Paper.adapt_menu(selector, Paper.physical_scale(selector))
	selector.get_popup().popup()
	await _frames(4)
	var popup := selector.get_popup()
	var bounds := Rect2(Vector2.ZERO, get_window().get_visible_rect().size)
	var popup_rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	_check(bounds.encloses(popup_rect), "short option popup clamps within the viewport")
	_check(Paper._popup_full_height(popup) <= popup.size.y, "short option popup shows every item without a scrollbar")
	popup.hide()
	selector.queue_free()
	await _frames(1)

func _check_album() -> void:
	var games: Array[Dictionary] = []
	for number in range(1, 13):
		games.append({"id": "game-%03d" % number, "name": "第 %02d 站" % number, "goal": "找到目標", "instructions": "使用方向鍵"})
	var album := AlbumScript.new()
	album.custom_minimum_size=Vector2(1000,520)
	album.setup(_progress, games, [{"id": "dawn", "label": "凌晨", "clock": "05:00"}, {"id": "noon", "label": "中午", "clock": "12:00"}, {"id": "dusk", "label": "傍晚", "clock": "18:00"}, {"id": "night", "label": "晚上", "clock": "22:00"}], Callable(self, "_load_fixture_photo"))
	_menu_content.add_child(album)
	await _frames(3)
	var grid := _overlay.find_child("AlbumPhotoGrid", true, false) as GridContainer
	_check(grid != null and grid.get_child_count() == 18, "album keeps all stable ordinary photo entries in its paged collection")
	_check((_overlay.find_child("AlbumCollectionState", true, false) as Label).visible, "a new collection has a clear empty-collection state")
	for physical_size in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size=physical_size
		await _frames(4)
		_check_album_card_geometry(album,"empty",physical_size)
	get_window().size=Vector2i(1280,720)
	await _frames(4)
	_progress.photos["photo-welcome-game-1"] = {"frames": ["fixture-thumbnail"], "original_frames": ["fixture-original"]}
	_progress.photos["photo-welcome-game-2"] = {"game_id": "game-002"}
	_original_record = _progress.photos.duplicate(true)
	album.call("_refresh_book")
	await _frames(2)
	for physical_size in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size=physical_size
		await _frames(4)
		_check_album_card_geometry(album,"filled",physical_size)
	get_window().size=Vector2i(1280,720)
	await _frames(4)
	for name in ["AlbumTab_normal", "AlbumTab_devil", "AlbumTab_time", "AlbumPreviousPage", "AlbumNextPage", "AlbumPageLabel", "AlbumPhotoDetails"]:
		var control := _overlay.find_child(name, true, false) as Control
		_check(control != null and control.is_visible_in_tree(), "album fixed navigation remains visible: " + name)
	var wide_scroll := album.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
	_check(wide_scroll!=null and wide_scroll.get_v_scroll_bar().max_value<=wide_scroll.get_v_scroll_bar().page,"wide album fits its one-row photo page without unnecessary scrolling")
	_check(wide_scroll!=null and wide_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"wide album compatibility viewport is not scrollable")
	var selected := grid.get_child(0) as Button
	selected.grab_focus()
	selected.emit_signal("pressed")
	await _frames(3)
	var viewer := _overlay.find_child("PhotoViewer", true, false) as Control
	var image := viewer.find_child("PhotoViewerImage", true, false) as TextureRect if viewer != null else null
	_check(image != null and image.texture is Texture2D and image.texture.get_width() == 1280 and image.texture.get_height() == 720, "direct Main overlay opens the full 1280×720 original from a valid thumbnail record")
	var close := viewer.find_child("PhotoViewerClose", true, false) as Button if viewer != null else null
	_check(close != null and close.is_visible_in_tree() and close.focus_mode == Control.FOCUS_ALL, "photo viewer keeps its keyboard-operable return action visible")
	if close != null:
		close.emit_signal("pressed")
		await _frames(2)
	_check(_overlay.find_child("PhotoViewer", true, false) == null and selected.has_focus(), "viewer return closes the photo and restores focus to its album entry")
	var next := _overlay.find_child("AlbumNextPage", true, false) as Button
	if next != null:
		next.emit_signal("pressed")
		await _frames(2)
		_check((_overlay.find_child("AlbumPageLabel", true, false) as Label).text == "第 2 / 5 頁", "fixed page controls navigate long photo collections")
	var devil := _overlay.find_child("AlbumTab_devil", true, false) as Button
	if devil != null:
		devil.emit_signal("pressed")
		await _frames(2)
		_check((_overlay.find_child("AlbumPhotoGrid", true, false) as GridContainer).get_child_count() == 12, "devil collection retains its twelve records and stable IDs")
	var time := _overlay.find_child("AlbumTab_time", true, false) as Button
	if time != null:
		time.emit_signal("pressed")
		await _frames(2)
		_check((_overlay.find_child("AlbumPhotoGrid", true, false) as GridContainer).get_child_count() == 4, "time collection retains the four canonical postcard records")
	if album.has_method("_set_category"):
		album.call("_set_category", "normal")
	get_window().size=Vector2i(800,450)
	await _frames(5)
	var album_scroll := album.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
	grid=album.find_child("AlbumPhotoGrid",true,false) as GridContainer
	var compact_page_complete := album_scroll!=null and grid!=null and grid.columns==2 and album_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var seen_ids := {}
	var page_label := album.find_child("AlbumPageLabel",true,false) as Label
	var next_button := album.find_child("AlbumNextPage",true,false) as Button
	for page_index in range(9):
		if grid==null: break
		var visible_cards := 0
		for tile in grid.get_children():
			if tile.visible:
				visible_cards+=1
				if seen_ids.has(tile.name): compact_page_complete=false
				seen_ids[tile.name]=true
		if visible_cards!=2: compact_page_complete=false
		if page_index<8 and next_button!=null:
			next_button.emit_signal("pressed")
			await _frames(2)
	_check(compact_page_complete and seen_ids.size()==18 and page_label!=null and page_label.text=="第 9 / 9 頁", "compact album paginates every stable photo ID in complete two-card pages without scrolling")
	album.call("_set_category","normal")
	await _frames(3)
	var compact_controls_disjoint := true
	var fixed_names := ["AlbumTab_normal","AlbumTab_devil","AlbumTab_time","AlbumPhotoDetails","AlbumPreviousPage","AlbumPageLabel","AlbumNextPage"]
	var fixed_rects: Array[Rect2]=[]
	for name in fixed_names:
		var fixed := album.find_child(name,true,false) as Control
		if fixed==null or not fixed.is_visible_in_tree():
			compact_controls_disjoint=false
		else:
			fixed_rects.append(fixed.get_global_rect())
	for left in range(fixed_rects.size()):
		for right in range(left+1,fixed_rects.size()):
			if fixed_rects[left].intersects(fixed_rects[right]):
				compact_controls_disjoint=false
				print("ALBUM_FIXED_OVERLAP ",fixed_names[left]," ",fixed_rects[left]," / ",fixed_names[right]," ",fixed_rects[right])
	for tile in grid.get_children():
		if not tile.visible: continue
		var frame := tile.find_child("SavedPhotoFrame",true,false) as Control
		var title := tile.find_child("AlbumPhotoTitle",true,false) as Control
		var status := tile.find_child("AlbumPhotoStatus",true,false) as Control
		if frame==null or title==null or status==null or frame.size.x*Paper.physical_scale(frame)<107 or frame.size.y*Paper.physical_scale(frame)<60 or not title.is_visible_in_tree() or not status.is_visible_in_tree():
			compact_controls_disjoint=false
		for rect in fixed_rects:
			if rect.intersects(tile.get_global_rect()):
				compact_controls_disjoint=false
				print("ALBUM_CARD_OVERLAP ",tile.name," ",tile.get_global_rect()," / ",rect)
		_check(compact_controls_disjoint,"compact photo frames, titles, statuses, tabs, summary, and page controls have disjoint hit rectangles")
	await _check_responsive_controls(["AlbumTab_normal", "AlbumTab_devil", "AlbumTab_time", "AlbumPreviousPage", "AlbumNextPage"], true)
	_check(_progress.photos == _original_record, "browsing photos leaves collection progress unchanged")
	album.queue_free()
	await _frames(2)

func _check_album_card_geometry(album: Control, state: String, physical_size: Vector2i) -> void:
	var scroll := album.find_child("AdaptiveMenuScroll",true,false) as ScrollContainer
	var grid := album.find_child("AlbumPhotoGrid",true,false) as GridContainer
	var pager := album.find_child("AlbumPageControls",true,false) as HBoxContainer
	var details := album.find_child("AlbumPhotoDetails",true,false) as Control
	var state_label := album.find_child("AlbumCollectionState",true,false) as Label
	var valid := scroll!=null and grid!=null and pager!=null and details!=null and scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if state_label!=null:
		valid=valid and state_label.visible==(state=="empty")
	var viewport_rect := scroll.get_global_rect() if scroll!=null else Rect2()
	var pager_rect := pager.get_global_rect() if pager!=null else Rect2()
	var detail_rect := details.get_global_rect() if details!=null else Rect2()
	var content_rect := Rect2(viewport_rect.position.x,detail_rect.end.y,viewport_rect.size.x,maxf(0.0,pager_rect.position.y-detail_rect.end.y))
	if state_label!=null and state_label.visible:
		valid=valid and content_rect.encloses(state_label.get_global_rect())
		if not content_rect.encloses(state_label.get_global_rect()): print("ALBUM_STATE_FAIL ",state_label.get_global_rect()," content=",content_rect," min=",state_label.get_combined_minimum_size())
	var visible_count := 0
	if grid!=null:
		for tile_node in grid.get_children():
			var tile := tile_node as Control
			if not tile.visible: continue
			visible_count+=1
			var descendants: Array[Control]=[tile]
			for child_name in ["SavedPhotoFrame","AlbumPhotoTitle","AlbumPhotoStatus"]:
				var child := tile.find_child(child_name,true,false) as Control
				if child==null or not child.is_visible_in_tree():
					valid=false
				else:
					descendants.append(child)
			for label_node in tile.find_children("*","Label",true,false):
				var copy := label_node as Label
				if not copy.is_visible_in_tree(): continue
				descendants.append(copy)
				var safe_copy_rect := tile.get_global_rect().grow(-7.0/Paper.physical_scale(tile))
				valid=valid and safe_copy_rect.encloses(copy.get_global_rect()) and copy.get_theme_font_size("font_size")*Paper.physical_scale(copy)>=16.0 and copy.size.y+1.0>=copy.get_line_count()*copy.get_line_height()
			for control in descendants:
				var rect := control.get_global_rect()
				if rect.size.x<=0.0 or rect.size.y<=0.0 or not viewport_rect.encloses(rect) or not content_rect.encloses(rect) or rect.intersects(pager_rect):
					valid=false
					print("ALBUM_CARD_VIEWPORT_FAIL state=",state," size=",physical_size," control=",control.name," rect=",rect," viewport=",viewport_rect," content=",content_rect," pager=",pager_rect)
					print("ALBUM_CARD_DIAG tile=",tile.get_global_rect()," copy_min=",(tile.get_child(0) as Control).get_combined_minimum_size() if tile.get_child_count()>0 else Vector2.ZERO," frame=",tile.find_child("SavedPhotoFrame",true,false).get_global_rect())
	var expected_count := mini(grid.get_child_count(),int(album.call("_page_capacity"))) if grid!=null else 0
	valid=valid and visible_count==expected_count
	_check(valid,"%s album keeps every full photo card and caption inside its content viewport, clear of the pager at %dx%d and 1.25 text" % [state,physical_size.x,physical_size.y])

func _check_map() -> void:
	var games: Array[Dictionary] = []
	for number in range(1, 13):
		games.append({"id": "game-%03d" % number, "name": "泡泡遊戲 %02d" % number, "goal": "找出泡泡", "instructions": "按下互動"})
	var zones: Array[Dictionary] = []
	for index in range(1, 10):
		zones.append({"id": "zone-%02d" % index, "name": "第 %02d 區" % index, "threshold": index * 6, "theme": "海島主題"})
	var map := MapScript.new()
	map.setup(zones, games, _progress.normal_count())
	_menu_content.add_child(map)
	await _frames(4)
	var canvas := _overlay.find_child("IslandChartCanvas", true, false) as Control
	_check(canvas != null and _named_buttons(canvas, "MapStop_game-").size() == 12 and _named_buttons(canvas, "MapGate_").size() == 9, "map retains all twelve game stations and nine future gates")
	_check(_overlay.find_child("IslandMapWorkspace", true, false) != null, "map uses a full-width chart and separate details workspace")
	var gate := _overlay.find_child("MapGate_zone-01", true, false) as Button
	if gate != null:
		gate.emit_signal("pressed")
		await _frames(1)
		var detail := _overlay.find_child("DestinationDetails", true, false)
		_check(_contains_text(detail, "6 張") and _contains_text(detail, "準備中"), "gate details preserve the original unlock eligibility")
		_check(gate.text!="01" and gate.tooltip_text.contains("第 01 區"),"gate labels name their destination and tooltip retains full zone name and threshold")
		_check((gate.get_theme_stylebox("normal") as StyleBoxFlat).border_color==Color("#f2bd68"),"selected gate is visually distinct on the map")
	var station := _overlay.find_child("MapStop_game-010", true, false) as Button
	if station != null:
		station.emit_signal("pressed")
		await _frames(1)
		_check(_contains_text(_overlay.find_child("DestinationDetails", true, false), "泡泡遊戲 10"), "selecting a station updates its actual destination details")
		_check((station.get_theme_stylebox("normal") as StyleBoxFlat).border_color==Color("#f2bd68"),"selected station is visually distinct on the map")
	_check(_overlay.find_child("MapStop_game-010", true, false) != null, "destination selection stays inside the map and does not invoke a teleport")
	for physical_size in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = physical_size
		await _frames(4)
		var current_canvas := _overlay.find_child("IslandChartCanvas", true, false) as Control
		var chart_buttons: Array[Button] = []
		if current_canvas != null:
			chart_buttons = _named_buttons(current_canvas, "MapStop_game-") + _named_buttons(current_canvas, "MapGate_")
		var chart_targets_fit := current_canvas != null and chart_buttons.size() == 21
		for button in chart_buttons:
			var scale_factor := Paper.physical_scale(button)
			if not current_canvas.get_global_rect().encloses(button.get_global_rect()) or button.size.x * scale_factor < 44.0 or button.size.y * scale_factor < 44.0:
				chart_targets_fit = false
		_check(chart_targets_fit, "all 21 map targets remain visible and at least 44 physical pixels at %dx%d" % [physical_size.x, physical_size.y])
	map.queue_free()
	await _frames(2)

func _check_achievements() -> void:
	var games: Array[Dictionary] = []
	for number in range(1, 13):
		games.append({"id": "game-%03d" % number, "name": "第 %02d 站" % number})
	var book := AchievementScript.new()
	book.setup(_progress, games)
	_menu_content.add_child(book)
	await _frames(4)
	var grid := _overlay.find_child("MinigameStampGrid", true, false) as GridContainer
	var milestones := _overlay.find_child("ParkMilestoneStampSection", true, false) as Control
	_check(grid != null and grid.get_child_count() == 12, "achievement book keeps all twelve minigame stamp records")
	_check(milestones != null and milestones.get_child_count() == 5, "milestone collection retains its four eligibility records")
	_check(_contains_text(_overlay.find_child("AchievementStamp_ACH_WELCOME_DEVILS", true, false), "12 張小惡魔"), "locked achievement still explains its unchanged requirement")
	var content_scroll := _overlay.find_child("AdaptiveMenuScroll", true, false) as ScrollContainer
	_check(content_scroll != null and content_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER, "achievement pages keep the real content viewport but hide manual scroll affordances")
	var tab := _overlay.find_child("AchievementTab_milestones", true, false) as Button
	if tab != null:
		tab.emit_signal("pressed")
		await _frames(2)
		_check(milestones.visible and not grid.is_visible_in_tree(), "achievement tabs switch between games and milestones without hiding navigation")
		_check(tab.is_visible_in_tree(), "achievement category tabs stay outside the content scroll")
	var games_tab := _overlay.find_child("AchievementTab_games",true,false) as Button
	if games_tab!=null: games_tab.emit_signal("pressed")
	get_window().size=Vector2i(800,450)
	await _frames(5)
	var achievement_next := _overlay.find_child("AchievementNextPage",true,false) as Button
	var seen_stamps := {}
	var pages_complete := grid.columns==2 and achievement_next!=null
	for page in range(6):
		var viewport_rect := content_scroll.get_global_rect() if content_scroll!=null else Rect2()
		var page_visible := 0
		for index in range(grid.get_child_count()):
			var tile := grid.get_child(index) as Control
			if tile.visible:
				page_visible+=1
				if index<page*2 or index>=page*2+2 or not viewport_rect.encloses(tile.get_global_rect()): pages_complete=false
		for index in range(page*2,min(page*2+2,grid.get_child_count())):
			var tile := grid.get_child(index) as Control
			if not tile.visible or not viewport_rect.encloses(tile.get_global_rect()) or seen_stamps.has(tile.name): pages_complete=false
			seen_stamps[tile.name]=true
		if page_visible!=2: pages_complete=false
		if not pages_complete: print("ACH_PAGE_DIAG page=",page," scroll=",content_scroll.get_global_rect()," grid=",grid.get_global_rect()," tiles=",[(grid.get_child(page*2) as Control).get_global_rect(),(grid.get_child(page*2+1) as Control).get_global_rect()]," visible=",page_visible)
		if page<5 and achievement_next!=null:
			achievement_next.emit_signal("pressed")
			await _frames(2)
	_check(pages_complete and seen_stamps.size()==12 and (_overlay.find_child("AchievementPageLabel",true,false) as Label).text=="第 6 / 6 頁", "compact two-column achievement pages navigate all twelve stable stamps without omission or duplication")
	await _check_responsive_controls(["AchievementTab_games", "AchievementTab_milestones"], false)
	book.queue_free()
	await _frames(2)

func _check_tutorial() -> void:
	_menu_content.queue_free()
	await _frames(2)
	var tutorial := TutorialScript.new()
	_overlay.add_child(tutorial)
	await _frames(2)
	_check(await tutorial.open_tutorial("game-001"), "tutorial opens a valid lesson")
	_check(tutorial._image.texture is Texture2D, "tutorial uses its actual lesson screenshot")
	tutorial.next_step()
	tutorial.replay()
	_check(tutorial.current_step == 0 and tutorial._image.texture is Texture2D, "tutorial replay returns to the actual first screenshot")
	_check(tutorial._text_scroll.get_parent() == tutorial._text_panel and tutorial._footer.get_parent() == tutorial._column and tutorial._text_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER, "tutorial keeps all sections in a hidden-scroll viewport and fixed actions outside it")
	await _frames(5)
	var all_copy_sections_visible := tutorial._goal_label.visible and tutorial._input_label.visible and tutorial._success_label.visible and tutorial._ordinary_label.visible and tutorial._bonus_label.visible
	_check(all_copy_sections_visible and tutorial._copy_sections.size()==5 and not tutorial._copy_pages.is_empty(), "tutorial retains all five complete guidance sections in real viewport content")
	var copy_pages_fit := true
	var seen_sections: Array[bool]=[false,false,false,false,false]
	for page in range(tutorial._copy_pages.size()):
		tutorial.call("_set_copy_page",page)
		await _frames(4)
		var group := tutorial._copy_pages[page] as Control
		var clip: Rect2=tutorial._text_scroll.get_global_rect()
		if not clip.encloses(group.get_global_rect()):
			copy_pages_fit=false
			print("TUTORIAL_PAGE_DIAG page=",page," scroll=",clip," group=",group.name," rect=",group.get_global_rect())
		var indices: Array=group.get_meta("semantic_indices")
		for semantic_index in indices:
			var section := tutorial._copy_sections[semantic_index] as Control
			var complete := section.is_visible_in_tree() and clip.encloses(section.get_global_rect()) and section.size.y>0
			for label in section.find_children("*","Label",true,false):
				complete=complete and label.is_visible_in_tree() and clip.encloses(label.get_global_rect()) and label.size.y+1>=label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))
			copy_pages_fit=copy_pages_fit and complete
			if complete: seen_sections[semantic_index]=true
		_check(tutorial._copy_page_label.text=="說明 %d / %d" % [page+1,tutorial._copy_pages.size()], "tutorial page caption reflects actual adaptive page count")
	_check(copy_pages_fit and not seen_sections.has(false), "tutorial page controls reveal all five complete guidance sections without manual scrolling")
	tutorial.call("_set_copy_page",0)
	_check(tutorial._replay_button.is_visible_in_tree() and tutorial._close_button.is_visible_in_tree(), "tutorial keeps replay and return actions visible")
	for physical_size in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = physical_size
		await _frames(4)
		var scale_factor := float(physical_size.x) / 1280.0
		tutorial._apply_responsive_layout(scale_factor)
		await _frames(3)
		var viewport := get_window().get_visible_rect()
		var actions_fit := viewport.encloses(tutorial._footer.get_global_rect())
		for button in tutorial._footer_buttons:
			actions_fit = actions_fit and viewport.encloses(button.get_global_rect()) and button.size.y * scale_factor >= 44.0
		_check(actions_fit, "tutorial fixed actions stay in bounds and usable at %dx%d" % [physical_size.x, physical_size.y])
		if not actions_fit:
			for button in tutorial._footer_buttons:
				if not viewport.encloses(button.get_global_rect()) or button.size.y * scale_factor < 44.0:
					print("TUTORIAL_ACTION_FAIL ", physical_size, " viewport=", viewport, " button=", button.name, " rect=", button.get_global_rect(), " scale=", scale_factor)
	tutorial.queue_free()
	await _frames(2)

func _check_main_album_host() -> void:
	var saved_photos: Dictionary=Progress.photos.duplicate(true)
	var saved_settings: Dictionary=Progress.settings.duplicate(true)
	var previous_scale_size := get_window().content_scale_size
	var previous_scale_mode := get_window().content_scale_mode
	var previous_scale_aspect := get_window().content_scale_aspect
	Progress.photos.clear()
	Progress.settings["ui_scale"]=1.25
	get_window().content_scale_size=Vector2i(1280,720)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().size=Vector2i(800,450)
	var main=MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	main._show_album()
	await _frames(8)
	var photo_grid := main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
	var album: Control
	var ancestor: Node=photo_grid
	while ancestor!=null:
		if ancestor.get_script()==AlbumScript:
			album=ancestor as Control
			break
		ancestor=ancestor.get_parent()
	for physical_size in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size=physical_size
		await _frames(8)
		if album!=null:
			_check_album_card_geometry(album,"empty",physical_size)
	Progress.photos["photo-welcome-game-1"]={"frames":["res://assets/ui/tutorials/park-step-01.png"]}
	if album!=null:
		album.call("_refresh_book")
	for physical_size in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size=physical_size
		await _frames(8)
		if album!=null:
			_check_album_card_geometry(album,"filled",physical_size)
	get_window().size=Vector2i(800,450)
	await _frames(8)
	if album!=null:
		await _check_album_catalog_pagination(album)
	photo_grid=main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
	var fixed_names := ["AlbumTab_normal","AlbumTab_devil","AlbumTab_time","AlbumPhotoDetails","AlbumPreviousPage","AlbumPageLabel","AlbumNextPage","MenuBackButton"]
	var fixed_rects: Array[Rect2]=[]
	var controls_disjoint := album!=null
	for name in fixed_names:
		var fixed := main.overlay.find_child(name,true,false) as Control
		if fixed==null or not fixed.is_visible_in_tree():
			controls_disjoint=false
		else:
			fixed_rects.append(fixed.get_global_rect())
	for left in range(fixed_rects.size()):
		for right in range(left+1,fixed_rects.size()):
			if fixed_rects[left].intersects(fixed_rects[right]): controls_disjoint=false
	if photo_grid!=null:
		for tile in photo_grid.get_children():
			if not tile.visible: continue
			var frame := tile.find_child("SavedPhotoFrame",true,false) as Control
			if frame==null or frame.size.x*Paper.physical_scale(frame)<107 or frame.size.y*Paper.physical_scale(frame)<60:
				controls_disjoint=false
			for rect in fixed_rects:
				if rect.intersects(tile.get_global_rect()): controls_disjoint=false
	_check(controls_disjoint,"Main 1280 logical canvas at 800×450 with 1.25 text keeps photos, fixed controls, and return action disjoint")
	if main.has_method("_close"): main._close()
	main.queue_free()
	Progress.photos=saved_photos
	Progress.settings=saved_settings
	get_window().content_scale_size=previous_scale_size
	get_window().content_scale_mode=previous_scale_mode
	get_window().content_scale_aspect=previous_scale_aspect
	get_window().size=Vector2i(1280,720)
	await _frames(4)

func _check_album_catalog_pagination(album: Control) -> void:
	for category in ["normal","devil","time"]:
		album.call("_set_category",category)
		await _frames(4)
		var entries: Array=album.call("_entries")
		var expected := 18 if category=="normal" else (12 if category=="devil" else 4)
		var seen := {}
		var complete := entries.size()==expected
		var capacity := int(album.call("_page_capacity"))
		for page in range(ceili(float(expected)/capacity)):
			var grid := album.find_child("AlbumPhotoGrid",true,false) as GridContainer
			var on_page := 0
			for tile in grid.get_children():
				if not tile.visible: continue
				on_page+=1
				complete=complete and not seen.has(tile.name)
				seen[tile.name]=true
			complete=complete and on_page==mini(capacity,expected-page*capacity)
			_check_album_card_geometry(album,"filled",Vector2i(800,450))
			album.call("_change_page",1)
			await _frames(4)
		_check(complete and seen.size()==expected,"real Main %s pagination reaches every stable catalog ID exactly once" % category)
	album.call("_set_category","normal")
	await _frames(4)

func _load_fixture_photo(_path: String) -> Texture2D:
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color("#4a9bba"))
	return ImageTexture.create_from_image(image)

func _named_buttons(node: Node, prefix: String) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button and str(node.name).begins_with(prefix):
		result.append(node)
	for child in node.get_children():
		result.append_array(_named_buttons(child, prefix))
	return result

func _contains_text(node: Node, target: String) -> bool:
	if node == null:
		return false
	if node is Label and (node as Label).text.contains(target):
		return true
	if node is Button and (node as Button).text.contains(target):
		return true
	for child in node.get_children():
		if _contains_text(child, target):
			return true
	return false

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _check_responsive_controls(names: Array[String], check_target_size: bool) -> void:
	for physical_size in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = physical_size
		await _frames(4)
		var viewport := get_window().get_visible_rect()
		var fits := true
		for name in names:
			var control := _overlay.find_child(name, true, false) as Control
			if control == null or not control.is_visible_in_tree() or not viewport.encloses(control.get_global_rect()):
				fits = false
			elif check_target_size and control is Button and control.size.y * Paper.physical_scale(control) < 44.0:
				fits = false
		_check(fits, "fixed collection controls remain visible at %dx%d" % [physical_size.x, physical_size.y])
		if not fits:
			for name in names:
				var control := _overlay.find_child(name, true, false) as Control
				if control == null or not control.is_visible_in_tree() or not viewport.encloses(control.get_global_rect()):
					print("FIXED_BOUNDS_FAIL ", physical_size, " viewport=", viewport, " control=", name, " rect=", control.get_global_rect() if control != null else "missing")
				elif check_target_size and control is Button and control.size.y * Paper.physical_scale(control) < 44.0:
					print("FIXED_SIZE_FAIL ", physical_size, " control=", name, " size=", control.size, " scale=", Paper.physical_scale(control))

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)

func _finish() -> void:
	for failure in _failures:
		push_error("FAIL: " + failure)
	_overlay.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("PASS: pixel UI collection, map, achievement, and tutorial checks")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
