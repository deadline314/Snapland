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
	for viewport_size in [Vector2i(800,600),Vector2i(1280,720)]:
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
		_check(separated,"map station hit targets never overlap at %dx%d" % [viewport_size.x,viewport_size.y])
		_check(contained,"map stations and entrances stay visible, keyboard focusable, at least 44px and inside the island chart at %dx%d" % [viewport_size.x,viewport_size.y])
		_main._close()
	get_tree().root.size=Vector2i(1280,720)

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
			if title==null or title.size.x<140 or card.size.y>180 or card.size.y<130: readable_cards=false
		_check(readable_cards,"album visible cards have readable 140px captions and bounded 130–180px height")
		_check(visible_count==6,"the ordinary collection shows one six-photo book spread at a time")
		var earned := grid.find_child("AlbumPhoto_photo-welcome-game-1",true,false)
		var saved_frame := earned.find_child("SavedPhotoFrame",true,false) if earned!=null else null
		_check(saved_frame!=null and saved_frame.get_child_count()==1 and saved_frame.get_child(0) is TextureRect,"a saved readable photo appears as its real thumbnail")
		var corrupt := grid.find_child("AlbumPhoto_photo-welcome-game-2",true,false)
		_check(corrupt!=null and _has_label(corrupt,"照片檔未讀取"),"an unreadable saved image falls back to an honest labeled print frame")
	var devil_tab := _main.overlay.find_child("AlbumTab_devil",true,false) as Button
	if devil_tab!=null:
		await _activate(devil_tab)
		grid=_main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
		_check(grid!=null and grid.get_child_count()==12,"devil album page uses the twelve existing devil photo IDs")
		_check(_has_label(grid,"零碰撞"),"locked devil print explains its real special condition")
		var next := _main.overlay.find_child("AlbumNextPage",true,false) as Button
		if next!=null:
			await _activate(next)
			_check(_has_label(_main.overlay,"第 2 / 2 頁"),"book page control advances to the next six devil prints")
	var time_tab := _main.overlay.find_child("AlbumTab_time",true,false) as Button
	if time_tab!=null:
		await _activate(time_tab)
		grid=_main.overlay.find_child("AlbumPhotoGrid",true,false) as GridContainer
		_check(grid!=null and grid.get_child_count()==4,"time book shows four canonical TimeOfDay postcard IDs")
		_check(grid!=null and grid.find_child("AlbumPhoto_postcard-time-dawn",true,false)!=null,"time postcard retains the canonical dawn photo ID")
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
			var grid: Node = _main.overlay.find_child("AlbumPhotoGrid",true,false)
			var first_row_complete := true
			for index in range(2):
				var card := grid.get_child(index) as Control
				if not scroll.get_global_rect().encloses(card.get_global_rect()): first_row_complete=false
			_check(first_row_complete,"small album initially shows two complete photo cards including captions and status")
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
