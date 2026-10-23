extends Node
const WorldScene = preload("res://game/world/park_world.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Story = preload("res://game/story/story_director.gd")
const Audio = preload("res://game/audio/audio_director.gd")
const Session = preload("res://game/minigames/session.gd")
const PhotoStage = preload("res://game/ui/photo_stage.gd")
const WardrobePanel = preload("res://game/ui/wardrobe_panel.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")
const TimePanel = preload("res://game/ui/time_panel.gd")
const SettingsPanel = preload("res://game/ui/settings_panel.gd")
const TutorialPanelScript = preload("res://game/ui/tutorial_panel.gd")
const DialoguePanelScript = preload("res://game/ui/dialogue_panel.gd")
var world: Node3D
var audio: Node
var story: RefCounted
var ui: Control
var hud: Control
var overlay: Control
var modal_body: VBoxContainer
var modal_footer: HBoxContainer
var area_label: Label
var normal_count_label: Label
var devil_count_label: Label
var coin_count_label: Label
var phase_label: Label
var breadcrumbs: Array[Label] = []
var context_action: Button
var context_bar: PanelContainer
var ticket_button: Button
var toast: Label
var quest_label: Label
var session: Control
var modal_kind := ""
var wardrobe_panel: RefCounted
var time_panel: RefCounted
var celebrate_on_close := false
var dialogue: Array=[]
var dialogue_index := 0
var dialogue_label: Label
var dialogue_panel: Control
var dialogue_done := Callable()
var dialogue_cancelled := Callable()
var reveal := 0.0
var definitions: Array=[]
var capture_mode := false
var photo_frames: Array[Image] = []
var photo_original_frames: Array[Image] = []
var next_snapshot := 0.0
var time_capture_token := 0
var quitting := false
var tutorial_panel: Control
var tutorial_target := ""
var tutorial_origin := ""
var tutorial_assist := false

func _ready() -> void:
	get_tree().auto_accept_quit=false
	capture_mode=OS.get_cmdline_user_args().has("--capture")
	world=WorldScene.new()
	add_child(world)
	audio=Audio.new()
	add_child(audio)
	world.coastal_play.note_requested.connect(audio.play_note)
	story=Story.new()
	definitions=Session.definitions()
	_build_ui()
	world.interaction_requested.connect(_interact)
	world.area_changed.connect(func(name: String):
		area_label.text=name
		_update_breadcrumb(name)
		_sync_audio_environment()
		if session==null: audio.play_context("harbor" if name=="海風碼頭" else "plaza")
	)
	Progress.changed.connect(_refresh)
	Localization.locale_changed.connect(_on_locale_changed)
	Progress.achievement_unlocked.connect(_achievement_toast)
	_refresh()
	audio.play_context("harbor")
	if capture_mode:
		world.player.position=Vector3(0,0.4,9)
		_capture_sequence.call_deferred()
	elif not Progress.intro_seen:
		_show_arrival()
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--smoke-test"):
		if user_args.has("--smoke-art"):
			_smoke_art_test.call_deferred()
		else:
			_smoke_test.call_deferred()

func _smoke_test() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Smoke test requires isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.5).timeout
	print("PASS: game startup and clean shutdown")
	await _quit_game()

func _smoke_art_test() -> void:
	if DisplayServer.get_name()=="headless":
		await _smoke_art_abort("--smoke-art requires a GPU-backed, non-headless display")
		return
	var review_profile := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not review_profile.is_absolute_path():
		await _smoke_art_abort("--smoke-art requires an absolute isolated SNAPLAND_SAVE_PATH")
		return
	var review_directory := review_profile.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(review_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		await _smoke_art_abort("Could not prepare the private art review directory")
		return
	var final_status: Dictionary={}
	var final_ready := false
	for game_index in range(1,13):
		var id := "game-%03d"%game_index
		_launch_game(id,false)
		if session==null or session.game_id!=id:
			await _smoke_art_abort("Could not start art smoke game %s"%id)
			return
		# Let the CanvasItem draw the real game frame before checking its shared caches.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		if not is_instance_valid(session.presentation) or not session.presentation.is_visible_in_tree() or session.presentation_mode != session.mode:
			await _smoke_art_abort("The actual minigame renderer did not become visible: %s"%id)
			return
		var image := get_viewport().get_texture().get_image()
		var capture := review_directory.path_join("art-smoke-%s.png"%id)
		if image == null or image.is_empty() or FileAccess.file_exists(capture) or image.save_png(capture) != OK:
			await _smoke_art_abort("Could not preserve a fresh rendered frame for %s"%id)
			return
		print("ART SMOKE DRAW: %s renderer=%s capture=%s"%[id,session.presentation.get_script().resource_path,capture])
		if Session._backdrop_warning_emitted or Session._props_warning_emitted or not world.foliage_warnings.is_empty():
			await _smoke_art_abort("An art resource warning occurred while drawing %s"%id)
			return
		if game_index==12:
			# Bespoke 2D/3D renderers need not draw the old common backdrop.
			# Resolve every shared region separately; do not call it gameplay use.
			if not session.resolve_shared_art_resources():
				await _smoke_art_abort("Shared art resource resolution is incomplete")
				return
			final_status=session.art_cache_status()
			final_ready=session.art_assets_ready()
		_cancel_game()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	# Explicit resolution above proves unused prop regions load as Texture2D; it
	# does not claim those props were drawn by a game.
	var expected_scenes: Array[String]=Session.BACKDROP_SCENES.duplicate()
	var loaded_scenes: Array=final_status.get("backdrops_loaded",[])
	var missing_scenes: Array=final_status.get("backdrops_missing",[])
	if not final_ready or not bool(final_status.get("backdrop_atlas_loaded",false)) or not missing_scenes.is_empty() or loaded_scenes.size()!=expected_scenes.size():
		await _smoke_art_abort("Backdrop cache incomplete: %s"%str(final_status))
		return
	if not bool(final_status.get("props_atlas_loaded",false)) or not bool(final_status.get("props_regions_loaded",false)) or not final_status.get("props_missing",[]).is_empty() or final_status.get("props_loaded",[]).size()!=Session.REQUIRED_PROP_KEYS.size():
		await _smoke_art_abort("Prop cache incomplete: %s"%str(final_status))
		return
	var foliage_keys: Array[String]=["oak","ginkgo","palm","pine","shrub","planter","rocks","lamp"]
	var actual_foliage_keys: Array[String]=[]
	for key in world.foliage_textures:
		actual_foliage_keys.append(str(key))
		if not world.foliage_textures[key] is Texture2D:
			await _smoke_art_abort("Foliage '%s' is not a Texture2D"%str(key))
			return
	actual_foliage_keys.sort()
	foliage_keys.sort()
	if not world.foliage_atlas_loaded or actual_foliage_keys!=foliage_keys or not world.foliage_warnings.is_empty():
		await _smoke_art_abort("Foliage cache incomplete or warned: %s"%str(actual_foliage_keys))
		return
	if Session._backdrop_warning_emitted or Session._props_warning_emitted:
		await _smoke_art_abort("A minigame art resource warning was emitted during the smoke test")
		return
	var avatar_source=world.avatar_renderer
	if not avatar_source.is_asset_ready() or not avatar_source.has_hat_atlas() or not avatar_source.has_hair_atlas() or not avatar_source.has_species_atlas() or not avatar_source.has_walk_atlas() or not avatar_source.has_diagonal_parts():
		await _smoke_art_abort("Character, hair, hat or species atlas failed to load from the exported resources")
		return
	if world.identity_textures.size()!=3 or not world.identity_warnings.is_empty():
		await _smoke_art_abort("Named character atlas regions failed to load")
		return
	for actor_role in ["ticket", "imp", "announcer"]:
		if world.npc_activity.load_action_frames(actor_role).size() != 4:
			await _smoke_art_abort("Authored NPC activity assets failed to load: " + actor_role)
			return
	var motion_status:Dictionary=world.component_motion.statistics()
	if not bool(motion_status.get("playing",false)) or int(motion_status.get("registration_count",0))<100:
		await _smoke_art_abort("Scene component animation did not start")
		return
	if int(world.occlusion_controller.statistics().get("registered_buildings",0))<15:
		await _smoke_art_abort("Eligible building cutaways were not registered")
		return
	print("PASS: character source assets, three NPC regions, component animation and building cutaway registration")
	print("PASS: art resources loaded (props=%d, scenes=%d, foliage=%d)"%[Session.REQUIRED_PROP_KEYS.size(),loaded_scenes.size(),actual_foliage_keys.size()])
	_cancel_game()
	world.blocked=true
	world.set_process(false)
	audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _smoke_art_abort(reason: String) -> void:
	push_error("ART SMOKE FAILED: "+reason)
	if session!=null: _cancel_game()
	world.blocked=true
	world.set_process(false)
	audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: _quit_game()

func _quit_game() -> void:
	if quitting: return
	quitting=true
	world.blocked=true
	Progress.save_progress()
	audio.shutdown()
	# Let the audio server consume stop commands before releasing the scene.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _build_ui() -> void:
	Paper.set_text_scale(float(Progress.settings.get("ui_scale",1.0)))
	Paper.set_font_style(str(Progress.settings.get("font_style", "pixel")))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.theme=Paper.theme()
	canvas.add_child(ui)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var banner := PanelContainer.new()
	banner.name="ParkKeepsakeBanner"
	banner.position=Vector2(24,20)
	banner.custom_minimum_size=Vector2(320,48)
	banner.size=Vector2(320,48)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color=Color(0.025,0.09,0.13,0.9)
	banner_style.border_width_left=3
	banner_style.border_color=Paper.TEAL
	banner_style.content_margin_left=12
	banner_style.content_margin_right=12
	banner_style.content_margin_top=8
	banner_style.content_margin_bottom=8
	banner.add_theme_stylebox_override("panel",banner_style)
	hud.add_child(banner)
	var banner_box := VBoxContainer.new()
	banner_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	banner_box.add_theme_constant_override("separation",4)
	banner.add_child(banner_box)
	var island_row := HBoxContainer.new()
	island_row.add_theme_constant_override("separation",8)
	banner_box.add_child(island_row)
	island_row.add_child(Paper.icon("pin",20,Paper.CORAL))
	area_label=Paper.label("海風碼頭",20)
	area_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	island_row.add_child(area_label)
	phase_label=Paper.label("",16,Paper.TEAL)
	phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	phase_label.custom_minimum_size.x=98
	island_row.add_child(phase_label)
	var keepsakes := HBoxContainer.new()
	keepsakes.name="ParkCollectionDetails"
	keepsakes.visible=false
	keepsakes.add_theme_constant_override("separation",6)
	banner_box.add_child(keepsakes)
	var album_mark := Paper.icon("album",18,Paper.TEAL)
	album_mark.tooltip_text="普通拍貼收藏"
	keepsakes.add_child(album_mark)
	normal_count_label=Paper.label("",18)
	normal_count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	normal_count_label.custom_minimum_size.x=88
	normal_count_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	keepsakes.add_child(normal_count_label)
	var devil_mark := Paper.icon("devil",18,Paper.CORAL)
	devil_mark.tooltip_text="小惡魔拍貼收藏"
	keepsakes.add_child(devil_mark)
	devil_count_label=Paper.label("",18,Paper.CORAL)
	devil_count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	devil_count_label.custom_minimum_size.x=102
	devil_count_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	keepsakes.add_child(devil_count_label)
	coin_count_label=Paper.label("",18,Paper.GOLD)
	coin_count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	coin_count_label.custom_minimum_size.x=62
	coin_count_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	keepsakes.add_child(Paper.icon("ticket",18,Paper.GOLD))
	keepsakes.add_child(coin_count_label)
	ticket_button=Paper.button("航海旅券  ·  M",_show_ticket,hud)
	ticket_button.name="VoyageTicket"
	ticket_button.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	ticket_button.anchor_left=1.0
	ticket_button.anchor_right=1.0
	ticket_button.offset_left=-222.0
	ticket_button.offset_right=-24.0
	ticket_button.offset_top=24.0
	ticket_button.offset_bottom=72.0
	ticket_button.custom_minimum_size=Vector2(198,48)
	quest_label=Paper.label("",18,Color("#fffaf0"))
	quest_label.position=Vector2(28,80)
	quest_label.size=Vector2(376,48)
	quest_label.add_theme_color_override("font_shadow_color",Color("#203e47"))
	quest_label.add_theme_constant_override("shadow_offset_x",1)
	quest_label.add_theme_constant_override("shadow_offset_y",1)
	hud.add_child(quest_label)
	context_bar=PanelContainer.new()
	context_bar.grow_horizontal=Control.GROW_DIRECTION_BOTH
	context_bar.grow_vertical=Control.GROW_DIRECTION_BEGIN
	context_bar.anchor_left=0.5
	context_bar.anchor_right=0.5
	context_bar.anchor_top=1.0
	context_bar.anchor_bottom=1.0
	context_bar.offset_left=-200
	context_bar.offset_right=200
	context_bar.offset_top=-62
	context_bar.offset_bottom=-18
	context_bar.custom_minimum_size=Vector2(400,44)
	var context_style := StyleBoxEmpty.new()
	context_style.content_margin_left=8
	context_style.content_margin_right=8
	context_style.content_margin_top=0
	context_style.content_margin_bottom=0
	context_bar.add_theme_stylebox_override("panel",context_style)
	hud.add_child(context_bar)
	var row := HBoxContainer.new()
	context_bar.add_child(row)
	context_action=Paper.button("",_interact_nearest,row)
	context_action.name="ContextAction"
	context_action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	context_action.visible=false
	context_bar.visible=false
	toast=Paper.label("",21,Paper.GOLD)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position=Vector2(-310,130)
	toast.size=Vector2(620,90)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color",Paper.INK)
	toast.add_theme_constant_override("shadow_offset_y",2)
	hud.add_child(toast)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	overlay.hide()
	_update_breadcrumb("海風碼頭")
	get_tree().root.size_changed.connect(_adapt_hud)
	call_deferred("_adapt_hud")

func _update_breadcrumb(current: String) -> void:
	var active := 0 if current=="海風碼頭" else (2 if current=="迎賓大道" else 1)
	for i in range(breadcrumbs.size()):
		if not is_instance_valid(breadcrumbs[i]): continue
		breadcrumbs[i].add_theme_color_override("font_color",Paper.CORAL if i==active else Color("#80918a"))
		breadcrumbs[i].add_theme_font_size_override("font_size",14 if i==active else 12)

func _open(title: String, subtitle: String, kind: String) -> VBoxContainer:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	# Sessions are added later to the same canvas; raise the whole modal,
	# including its ink and panel face, above that active session.
	overlay.move_to_front()
	if is_instance_valid(session):
		session.set_paused(true)
		session.set_process_unhandled_input(false)
	overlay.show()
	modal_kind=kind
	world.blocked=true
	world.sync_activity_pause()
	world.set_process(kind!="pause")
	audio.set_paused(kind=="pause" or (kind=="time" and session!=null))
	var dim := ColorRect.new()
	dim.color=Color(0.06,0.14,0.19,0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	hud.hide()
	var center := CenterContainer.new()
	center.name="AdaptiveMenuCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name="AdaptiveMenuPanel"
	panel.custom_minimum_size=Vector2.ZERO
	panel.add_theme_stylebox_override("panel",Paper.plaque())
	center.add_child(panel)
	_layout_open_panel(panel)
	var margin := MarginContainer.new()
	margin.name="AdaptiveMenuMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,14)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	panel.add_child(margin)
	var shell := VBoxContainer.new()
	shell.name="AdaptiveMenuShell"
	shell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical=Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation",8)
	margin.add_child(shell)
	var frame := Paper.PixelFrame.new()
	frame.name="PixelOrnamentFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var ticket_heading := HBoxContainer.new()
	ticket_heading.name="AdaptiveMenuHeader"
	ticket_heading.add_theme_constant_override("separation",12)
	ticket_heading.custom_minimum_size.y=56
	shell.add_child(ticket_heading)
	ticket_heading.add_child(Paper.icon("shell",24,Paper.TEAL))
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation",1)
	ticket_heading.add_child(heading_stack)
	var eyebrow := Paper.label("SNAPLAND   /   "+subtitle,14,Paper.TEAL)
	eyebrow.name="AdaptiveMenuEyebrow"
	heading_stack.add_child(eyebrow)
	var title_label := Paper.label(title,25)
	title_label.name="AdaptiveMenuTitle"
	heading_stack.add_child(title_label)
	var content := VBoxContainer.new()
	content.name="AdaptiveMenuContent"
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	shell.add_child(content)
	modal_body=shell
	modal_footer=HBoxContainer.new()
	modal_footer.name="AdaptiveMenuFooter"
	modal_footer.alignment=BoxContainer.ALIGNMENT_END
	modal_footer.add_theme_constant_override("separation",10)
	modal_footer.custom_minimum_size.y=0
	shell.add_child(modal_footer)
	call_deferred("_adapt_open_menu")
	if not get_tree().root.size_changed.is_connected(_adapt_open_menu):
		get_tree().root.size_changed.connect(_adapt_open_menu)
	return content

func _content_pager(parent: VBoxContainer, node_name: String, entries: Array, render: Callable, capacity: int, navigation_parent: Node = null) -> VBoxContainer:
	var pager := VBoxContainer.new()
	pager.name=node_name
	pager.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pager.size_flags_vertical=Control.SIZE_EXPAND_FILL
	pager.add_theme_constant_override("separation",8)
	parent.add_child(pager)
	pager.set_meta("page_entries",entries)
	pager.set_meta("page_renderer",render)
	pager.set_meta("page_capacity",capacity)
	var view := VBoxContainer.new()
	view.name="PageContent"
	view.size_flags_vertical=Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation",10)
	if node_name=="TaskPages":
		var viewport := ScrollContainer.new()
		viewport.name="AdaptiveMenuScroll"
		viewport.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		viewport.size_flags_vertical=Control.SIZE_EXPAND_FILL
		viewport.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		viewport.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		pager.add_child(viewport)
		viewport.add_child(view)
	else:
		pager.add_child(view)
	var navigation := HBoxContainer.new()
	navigation.name=node_name+"Navigation"
	navigation.add_theme_constant_override("separation",8)
	navigation.alignment=BoxContainer.ALIGNMENT_END
	(navigation_parent if navigation_parent!=null else pager).add_child(navigation)
	pager.set_meta("page_navigation",navigation)
	var previous := Paper.button("‹",_step_content_page.bind(pager,-1),navigation)
	previous.name=node_name+"Previous"
	previous.tooltip_text="上一頁"
	var counter := Paper.label("",16,Paper.TEAL)
	counter.name="PageCounter"
	counter.autowrap_mode=TextServer.AUTOWRAP_OFF
	counter.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	navigation.add_child(counter)
	var next := Paper.button("›",_step_content_page.bind(pager,1),navigation)
	next.name=node_name+"Next"
	next.tooltip_text="下一頁"
	_render_content_page(pager,0)
	return pager

func _step_content_page(pager: VBoxContainer, amount: int) -> void:
	if not is_instance_valid(pager): return
	_render_content_page(pager,int(pager.get_meta("page_index",0))+amount)
	var navigation: HBoxContainer=pager.get_meta("page_navigation")
	for control in navigation.get_children():
		if control is Button and not control.disabled:
			control.grab_focus()
			break

func _render_content_page(pager: VBoxContainer, requested: int, reset_reserved_height: bool = false) -> void:
	var entries: Array=pager.get_meta("page_entries")
	var capacity: int=pager.get_meta("page_capacity")
	var count := maxi(1,ceili(float(entries.size())/capacity))
	var index := clampi(requested,0,count-1)
	pager.set_meta("page_index",index)
	pager.set_meta("page_count",count)
	var view := pager.find_child("PageContent",true,false) as VBoxContainer
	if pager.name=="ResultScorePages":
		if reset_reserved_height:
			view.custom_minimum_size.y=0.0
		elif view.get_child_count()>0:
			# A short last page must retain the previous score area's height;
			# otherwise the modal and neighboring photo grid shrink mid-navigation.
			view.custom_minimum_size.y=maxf(view.custom_minimum_size.y,view.get_combined_minimum_size().y)
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	var renderer: Callable=pager.get_meta("page_renderer")
	for item in range(index*capacity,mini((index+1)*capacity,entries.size())):
		renderer.call(view,entries[item],item)
	var navigation: HBoxContainer=pager.get_meta("page_navigation")
	(navigation.get_child(0) as Button).disabled=index==0
	(navigation.get_child(1) as Label).text="%d / %d"%[index+1,count]
	(navigation.get_child(2) as Button).disabled=index==count-1
	navigation.visible=count>1
	call_deferred("_adapt_open_menu")

func _adapt_content_pagers(compact: bool) -> void:
	for node in overlay.find_children("*","VBoxContainer",true,false):
		if not node.has_meta("page_entries"): continue
		var capacity := int(node.get_meta("page_capacity"))
		var desired := capacity
		if node.name=="TaskPages": desired=1 if compact else 2
		elif node.name=="ResultScorePages": desired=1 if compact or Paper.text_scale()>1.1 else 5
		if desired!=capacity:
			var first := int(node.get_meta("page_index",0))*capacity
			node.set_meta("page_capacity",desired)
			_render_content_page(node,floori(float(first)/desired),true)

func _close() -> void:
	if modal_kind=="dialogue":
		_finish_dialogue()
		return
	if modal_kind == "time":
		time_capture_token += 1
	var celebrate := celebrate_on_close and modal_kind=="result"
	celebrate_on_close=false
	overlay.hide()
	modal_kind=""
	world.blocked=session!=null
	world.set_process(true)
	audio.set_paused(false)
	if session != null:
		session.process_mode=Node.PROCESS_MODE_INHERIT
		session.set_process_unhandled_input(true)
		if session.has_method("set_paused"):
			session.set_paused(false)
	if session==null: hud.show()
	if celebrate and session==null and world.has_method("play_action"):
		world.play_action("celebrate")

func _back(parent: Node) -> void:
	var button := Paper.button(Localization.text("button.back"),_close,modal_footer)
	button.name="MenuBackButton"
	button.custom_minimum_size=Vector2(190,44)
	button.grab_focus()

func _refresh() -> void:
	if not is_instance_valid(ui): return
	Paper.set_font_style(str(Progress.settings.get("font_style", "pixel")))
	Paper.set_reduced_motion(bool(Progress.settings.get("reduced_motion",false)))
	Paper.set_text_scale(float(Progress.settings.get("ui_scale",1.0)))
	if is_instance_valid(ui): ui.theme=Paper.theme()
	if is_instance_valid(world) and world.has_method("refresh_label_fonts"):
		world.refresh_label_fonts(Paper.font())
	if is_instance_valid(ui): ui.layout_direction=Control.LAYOUT_DIRECTION_RTL if Localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	_adapt_hud()
	_adapt_open_menu()
	normal_count_label.text=Localization.text("hud.normal_count", {"count": Progress.normal_count()})
	devil_count_label.text=Localization.text("hud.devil_count", {"count": Progress.devil_count()})
	coin_count_label.text=Localization.text("hud.coins", {"count": Progress.coins})
	var phase := TimeOfDay.phase_for_id(Progress.settings.get("time_phase",TimeOfDay.DEFAULT_PHASE))
	phase_label.text="%s %s"%[str(phase.get("label","中午")),str(phase.get("clock","12:00"))]
	quest_label.text=""
	for id in ["quest-001","quest-002"]:
		var step := int(Progress.quests.get(id,0))
		if step>0 and step<3:
			var quest: Dictionary=story.quest_data(id)
			quest_label.text=quest.get("title",id)+"  %d / 3"%step
	quest_label.visible=not quest_label.text.is_empty()
	audio.apply_settings(Progress.settings)
	world.apply_settings(Progress.settings)
	_apply_time_phase()
	world.update_collection(Progress.photos)
	if world.has_method("set_avatar_look"):
		world.set_avatar_look(Progress.appearance,Progress.equipped)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if Progress.settings.get("fullscreen",false) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name()!="headless" and not capture_mode:
		DisplayServer.window_set_mode(mode)

func _process(delta: float) -> void:
	if session!=null and DisplayServer.get_name()!="headless" and session.elapsed>=next_snapshot and not session.ended:
		next_snapshot=session.elapsed+0.9
		_sample_photo.call_deferred()
	if is_instance_valid(world) and modal_kind=="" and session==null:
		var has_context: bool = not world.nearest.is_empty() or world.is_riding()
		context_bar.visible=has_context
		context_action.visible=has_context
		if has_context:
			var prompt := _context_prompt()
			if context_action.text!=prompt:
				context_action.text=prompt
				_adapt_hud()
	if modal_kind=="dialogue" and is_instance_valid(dialogue_label) and dialogue_label.visible_characters>=0:
		var previous_count := dialogue_label.visible_characters
		reveal+=delta*34.0*float(Progress.settings.get("text_speed",1.0))
		var next_count := mini(int(reveal), dialogue_label.text.length())
		dialogue_label.visible_characters=next_count
		for char_index in range(previous_count, next_count):
			var current_speaker := str(dialogue[dialogue_index].get("speaker", "")) if dialogue_index < dialogue.size() else ""
			audio.play_dialogue_beep(current_speaker, dialogue_label.text.substr(char_index, 1))

func _context_prompt() -> String:
	if world.is_riding(): return "E   下來走走"
	var id := str(world.nearest.get("id",""))
	var play_prompt: String=world.coastal_play.prompt(id)
	if world.coastal_play.discoveries.controlling: return play_prompt
	if not play_prompt.is_empty(): return "E   "+play_prompt
	if id.begins_with("game-"): return "E   玩"+str(_definition(id).get("name","這個遊戲"))
	var actor_prompts := {"guide":"和票票說話","quest-001":"和小角說話","quest-002":"和阿浪說話","arrival":"重看上島導覽","ride-tide":"搭乘貝殼輪"}
	return "E   "+str(actor_prompts.get(id,world.nearest.get("label","附近設施")))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		if modal_kind == "time":
			_close()
		elif modal_kind == "":
			_show_time_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and modal_kind=="" and session==null:
		_show_ticket()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if modal_kind=="" and session==null and world.coastal_play.discoveries.end_control(): pass
		elif modal_kind=="dialogue": _cancel_dialogue()
		elif modal_kind!="": _close()
		elif session==null: _show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if modal_kind=="dialogue":
			_next_dialogue()
		elif modal_kind=="" and session==null:
			world.interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE and modal_kind=="dialogue":
		_next_dialogue()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_C:
		if modal_kind=="" and session==null:
			_show_wardrobe()
		elif modal_kind=="wardrobe":
			_close()
		get_viewport().set_input_as_handled()

func _apply_time_phase() -> void:
	var phase_id := TimeOfDay.normalize(Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE))
	_sync_audio_environment()
	if world.has_method("set_time_of_day"):
		world.set_time_of_day(phase_id)
	else:
		world.set_night(phase_id == "night")
	if session != null and session.has_method("set_time_of_day"):
		session.set_time_of_day(phase_id)

func _sync_audio_environment() -> void:
	if not is_instance_valid(audio):
		return
	var area := "harbor" if is_instance_valid(world) and world.current_area == "海風碼頭" else "plaza"
	var phase := TimeOfDay.normalize(Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE))
	audio.set_island_state(area, phase)

func _select_time_phase(phase_id: String) -> bool:
	if not Progress.set_time_phase(phase_id):
		return false
	_apply_time_phase()
	return true

func _collect_time_postcard(phase_id: String) -> String:
	if not _can_capture_time_postcard(phase_id, time_capture_token):
		return ""
	var token := time_capture_token
	var saved_paths: Dictionary = await _capture_time_postcard_frame(phase_id, token)
	var frame_path := str(saved_paths.get("thumbnail", ""))
	var original_path := str(saved_paths.get("original", ""))
	if frame_path.is_empty() or not _can_capture_time_postcard(phase_id, token):
		_remove_photo_paths([frame_path, original_path])
		return ""
	if not Progress.collect_time_postcard(phase_id, frame_path, original_path):
		_remove_photo_paths([frame_path, original_path])
		return ""
	return frame_path

func _can_capture_time_postcard(phase_id: String, token: int) -> bool:
	return token == time_capture_token and modal_kind == "time" and session == null and is_instance_valid(world) and str(world.nearest.get("id", "")) == "guide" and str(Progress.settings.get("time_phase", "")) == phase_id and TimeOfDay.phase_ids().has(phase_id) and not Progress.photos.has(TimeOfDay.postcard_id(phase_id))

func _capture_time_postcard_frame(phase_id: String, token: int) -> Dictionary:
	if not _can_capture_time_postcard(phase_id, token):
		return {}
	var overlay_was_visible := overlay.visible
	var hud_was_visible := hud.visible
	overlay.hide()
	hud.hide()
	await get_tree().process_frame
	if not _can_capture_time_postcard(phase_id, token):
		_restore_time_capture_ui(token, overlay_was_visible, hud_was_visible)
		return {}
	await RenderingServer.frame_post_draw
	if not _can_capture_time_postcard(phase_id, token):
		_restore_time_capture_ui(token, overlay_was_visible, hud_was_visible)
		return {}
	var viewport := get_viewport()
	var snapshot := viewport.get_texture().get_image() if is_instance_valid(viewport) else null
	_restore_time_capture_ui(token, overlay_was_visible, hud_was_visible)
	if snapshot == null or snapshot.is_empty() or not _can_capture_time_postcard(phase_id, token):
		return {}
	var original := _prepare_photo_original(snapshot)
	var thumbnail := _prepare_photo_thumbnail(original)
	var directory := _photo_directory()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning("Cannot create time postcard directory: " + directory)
		return {}
	var base_path := directory + "/" + TimeOfDay.postcard_id(phase_id)
	var path := base_path + ".png"
	var original_path := base_path + "-original.png"
	if thumbnail.save_png(path) != OK or not _save_bounded_photo_image(original, original_path):
		_remove_photo_paths([path, original_path])
		push_warning("Cannot save time postcard image: " + path)
		return {}
	return {"thumbnail": path, "original": original_path}

func _restore_time_capture_ui(token: int, overlay_visible: bool, hud_visible: bool) -> void:
	if token != time_capture_token or modal_kind != "time":
		return
	overlay.visible = overlay_visible
	hud.visible = hud_visible

func _show_time_panel() -> void:
	if modal_kind != "" or not is_instance_valid(world):
		return
	var body := _open("晨昏換景，收藏四時。", "ISLAND TIME", "time")
	time_panel = TimePanel.new()
	time_capture_token += 1
	var at_photo_station := session == null and str(world.nearest.get("id", "")) == "guide"
	var time_card := Paper.card(body,Color("#fffaf0"),8)
	time_card.size_flags_vertical=Control.SIZE_EXPAND_FILL
	(time_card.get_parent() as Control).size_flags_vertical=Control.SIZE_EXPAND_FILL
	time_panel.open(self, time_card, Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE), Progress.photos, at_photo_station, _select_time_phase, _collect_time_postcard)
	if session != null:
		session.process_mode = Node.PROCESS_MODE_DISABLED
		body.add_child(Paper.label("已暫停本局；關閉面板後會從同一局面繼續。", 18, Paper.TEAL))
	if is_instance_valid(time_panel.collect_button):
		time_panel.collect_button.reparent(modal_footer)
		time_panel.collect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_back(body)
	else:
		_back(body)

func _open_tutorial(target_id: String, origin: String, assisted_mode: bool = false) -> void:
	if is_instance_valid(tutorial_panel):
		return
	tutorial_target=target_id
	tutorial_origin=origin
	tutorial_assist=assisted_mode
	if origin=="session" and session!=null and session.has_method("set_paused"):
		session.set_paused(true)
		world.set_process(false)
	tutorial_panel=TutorialPanelScript.new()
	tutorial_panel.name="TutorialPanel"
	ui.add_child(tutorial_panel)
	tutorial_panel.close_requested.connect(_tutorial_close)
	tutorial_panel.start_requested.connect(_tutorial_start)
	tutorial_panel.skip_requested.connect(_tutorial_skip)
	tutorial_panel.practice_requested.connect(_tutorial_practice)
	_open_tutorial_lesson(target_id)

func _open_tutorial_lesson(target_id: String) -> void:
	if not is_instance_valid(tutorial_panel):
		return
	var opened: bool = await tutorial_panel.open_tutorial(target_id)
	if not opened:
		_notice("這份教學目前無法開啟，原畫面仍保留。")
		_finish_tutorial_panel()

func _finish_tutorial_panel() -> void:
	if is_instance_valid(tutorial_panel):
		tutorial_panel.dismiss()
		tutorial_panel.queue_free()
	tutorial_panel=null

func _tutorial_close() -> void:
	_finish_tutorial_panel()
	if tutorial_origin=="session" and session!=null and session.has_method("set_paused"):
		world.set_process(true)
		# Closing the lesson returns to the paused session HUD; the player chooses when to resume.
		session.set_paused(true)

func _tutorial_skip(_target_id: String) -> void:
	_tutorial_start(tutorial_target)

func _tutorial_start(_target_id: String) -> void:
	var target := tutorial_target
	var origin := tutorial_origin
	var assisted_mode := tutorial_assist
	_finish_tutorial_panel()
	if target=="park":
		if origin=="session" and session!=null:
			world.set_process(true)
			session.set_paused(false)
		return
	if origin=="session" and session!=null:
		world.set_process(true)
		session.set_paused(false)
		return
	if target.begins_with("game-"):
		if origin in ["first_entry", "game_info"] and not Progress.mark_game_tutorial_seen(target):
			_notice("教學已看過，但暫時無法保存；下次仍會教學。")
		_launch_game(target,assisted_mode,false)

func _tutorial_practice(_target_id: String) -> void:
	var target := tutorial_target
	var origin := tutorial_origin
	var assisted_mode := tutorial_assist
	_finish_tutorial_panel()
	if not target.begins_with("game-"):
		if origin=="session" and session!=null:
			world.set_process(true)
			session.set_paused(false)
		return
	if origin=="session" and session!=null:
		if session.has_method("set_practice_mode"):
			world.set_process(true)
			session.set_practice_mode(true)
		return
	_launch_game(target,assisted_mode,true)

func _show_pause() -> void:
	var body := _open("海風島 · 遊園選單","PAUSE","pause")
	var columns := HBoxContainer.new()
	columns.name="PauseNavigation"
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",24)
	body.add_child(columns)
	var island_panel := PanelContainer.new()
	island_panel.name="PauseIslandStatus"
	island_panel.custom_minimum_size.x=270
	island_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	island_panel.add_theme_stylebox_override("panel",Paper.plaque(Paper.FRAME))
	columns.add_child(island_panel)
	var island := VBoxContainer.new()
	island.add_theme_constant_override("separation",9)
	island_panel.add_child(island)
	var island_heading := HBoxContainer.new()
	island_heading.add_theme_constant_override("separation",8)
	island.add_child(island_heading)
	island_heading.add_child(Paper.icon("shell",24,Paper.GOLD))
	var status_heading := Paper.section_title("島嶼狀態",Paper.TEAL)
	status_heading.name="PauseIslandHeading"
	island_heading.add_child(status_heading)
	var portrait := TextureRect.new()
	portrait.name="PausePlayerPortrait"
	portrait.custom_minimum_size=Vector2(176,202)
	portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if world.avatar_renderer!=null:
		portrait.texture=world.avatar_renderer.texture(Progress.appearance,Progress.equipped,"front",0,"idle")
	island.add_child(portrait)
	Paper.divider(island,Paper.FRAME)
	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation",7)
	island.add_child(place_row)
	place_row.add_child(Paper.icon("pin",20,Paper.GOLD))
	var place := Paper.label(str(world.current_area if not world.current_area.is_empty() else area_label.text),20,Paper.PAPER)
	place.name="PauseCurrentArea"
	place_row.add_child(place)
	var phase_data := TimeOfDay.phase_for_id(Progress.settings.get("time_phase",TimeOfDay.DEFAULT_PHASE))
	var phase := Paper.label("時間  "+str(phase_data.get("label","中午"))+"  "+str(phase_data.get("clock","12:00")),16,Paper.TEAL)
	phase.name="PauseCurrentPhase"
	island.add_child(phase)
	var collection := VBoxContainer.new()
	collection.name="PauseCollectionStatus"
	collection.add_theme_constant_override("separation",2)
	island.add_child(collection)
	for stat in [["拍貼","%d / 18"%Progress.normal_count(),Paper.GOLD],["小惡魔","%d / 12"%Progress.devil_count(),Paper.CORAL],["遊園幣","%d"%Progress.coins,Paper.GOLD]]:
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation",8)
		collection.add_child(stat_row)
		var stat_label := Paper.label(str(stat[0]),14,Paper.PAPER)
		stat_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		stat_row.add_child(stat_label)
		var stat_value := Paper.label(str(stat[1]),14,stat[2])
		stat_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		stat_value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		stat_row.add_child(stat_value)
	var nav_panel := PanelContainer.new()
	nav_panel.name="PauseMenuPanel"
	nav_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	nav_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	nav_panel.add_theme_stylebox_override("panel",Paper.plaque(Paper.DEEP))
	columns.add_child(nav_panel)
	var actions := GridContainer.new()
	actions.name="PauseActions"
	actions.columns=2
	actions.size_flags_vertical=Control.SIZE_EXPAND_FILL
	actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation",18)
	actions.add_theme_constant_override("v_separation",6)
	nav_panel.add_child(actions)
	var island_actions := _pause_action_column(actions,"探索與旅券","map")
	var keepsake_actions := _pause_action_column(actions,"紀念與整裝","album")
	var links := [
		["島嶼地圖",_show_map,"PauseMapButton","map","explore"],
		["今日任務",_show_tasks,"PauseTasksButton","ticket","explore"],
		["更多旅券",_show_ticket,"PauseTicketButton","ticket","explore"],
		["操作速查",_show_controls,"PauseControlsButton","gear","explore"],
		["拍貼收藏",_show_album,"PauseAlbumButton","album","keepsake"],
		["遊園成就",_show_achievements,"PauseAchievementsButton","gear","keepsake"],
		["衣櫃換裝",_show_wardrobe,"PauseWardrobeButton","hat","keepsake"],
		["切換時段",_show_time_panel,"PauseTimeButton","shell","keepsake"],
		["設定與輔助",_show_settings,"PauseSettingsButton","gear","keepsake"],
	]
	for entry in links:
		var column: VBoxContainer=island_actions if str(entry[4])=="explore" else keepsake_actions
		var button := _pause_action(column,str(entry[0]),entry[1],str(entry[2]),str(entry[3]))
		button.name=str(entry[2])
		button.tooltip_text=str(entry[0])
	if session!=null:
		var tutorial := _pause_action(island_actions,"本局圖解教學",func(): _open_tutorial(session.game_id,"session",session.assisted),"PauseTutorialButton","map")
		tutorial.tooltip_text="本局圖解教學"
	modal_footer.alignment=BoxContainer.ALIGNMENT_BEGIN
	modal_footer.add_child(Paper.icon("gear",18,Paper.GOLD))
	var saved := Paper.label("進度會自動保存",16,Paper.TEAL)
	saved.name="PauseSavedStatus"
	modal_footer.add_child(saved)
	var spacer := Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	modal_footer.add_child(spacer)
	var resume := Paper.button("繼續遊園  ·  Esc",_close,modal_footer)
	resume.name="PauseResumeButton"
	resume.custom_minimum_size=Vector2(210,0)
	Paper.set_button_role(resume,"primary")
	var leave := Paper.button("儲存並離開",_quit_game,modal_footer)
	leave.name="PauseQuitButton"
	leave.custom_minimum_size=Vector2(180,0)
	resume.grab_focus()

func _pause_action_column(parent: GridContainer,title: String,motif: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",3)
	parent.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",7)
	column.add_child(heading)
	heading.add_child(Paper.icon(motif,20,Paper.GOLD))
	var heading_label := Paper.section_title(title,Paper.TEAL)
	heading_label.custom_minimum_size.y=22
	heading.add_child(heading_label)
	Paper.divider(column,Paper.FRAME)
	var grid := GridContainer.new()
	grid.name="PauseActionGrid"
	grid.columns=1
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",3)
	column.add_child(grid)
	return column

func _pause_action(parent: VBoxContainer,label: String,callback: Callable,node_name: String,motif: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var grid := parent.get_node("PauseActionGrid") as GridContainer
	grid.add_child(row)
	row.add_child(Paper.icon(motif,20,Paper.TEAL))
	var button := Paper.button(label,callback,row)
	button.name=node_name
	button.custom_minimum_size=Vector2(0,0)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return button

func _show_arrival() -> void:
	_start_dialogue(story.intro_lines(),func(): Progress.intro_seen=true; Progress.save_progress(),func(): Progress.intro_seen=true; Progress.save_progress())

func _start_dialogue(lines: Array, done: Callable, cancelled: Callable = Callable()) -> void:
	if lines.is_empty():
		if done.is_valid(): done.call()
		return
	if is_instance_valid(audio):
		audio.set_dialogue_active(true)
	dialogue=lines.duplicate(true)
	dialogue_index=0
	dialogue_done=done
	dialogue_cancelled=cancelled
	if not is_instance_valid(dialogue_panel):
		dialogue_panel=DialoguePanelScript.new()
		dialogue_panel.advance_requested.connect(_next_dialogue)
		dialogue_panel.finished.connect(_cancel_dialogue)
		dialogue_panel.tree_exiting.connect(_dialogue_panel_exiting.bind(dialogue_panel))
		ui.add_child(dialogue_panel)
		dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dialogue_panel_resized()
		if not get_tree().root.size_changed.is_connected(_dialogue_panel_resized):
			get_tree().root.size_changed.connect(_dialogue_panel_resized)
	else:
		dialogue_panel.show()
		dialogue_panel.set_process_unhandled_key_input(true)
	overlay.hide()
	hud.hide()
	world.set_dialogue_hold(true)
	world.blocked=true
	_render_dialogue()

func _render_dialogue() -> void:
	if dialogue_index>=dialogue.size():
		_finish_dialogue()
		return
	var line: Dictionary=dialogue[dialogue_index]
	var speaker := str(line.get("speaker", "旁白"))
	var dialogue_text := str(line.get("text", ""))
	if line.has("text_key"):
		var text_args: Dictionary = line.get("text_args", {})
		dialogue_text=Localization.text(str(line.text_key), text_args)
	dialogue_panel.show_line(speaker,dialogue_text,dialogue_index)
	if line.has("speaker_key"):
		var speaker_args: Dictionary = line.get("speaker_args", {})
		dialogue_panel.speaker_label.text=Localization.text(str(line.speaker_key), speaker_args)
	dialogue_label=dialogue_panel.text_label
	call_deferred("_dialogue_panel_resized")
	reveal=0
	modal_kind="dialogue"

func _next_dialogue() -> void:
	if not is_instance_valid(dialogue_label): return
	if dialogue_label.visible_characters>=0 and dialogue_label.visible_characters<dialogue_label.text.length():
		reveal=dialogue_label.text.length()
		dialogue_panel.reveal_all()
	else:
		dialogue_index+=1
		_render_dialogue()

func _finish_dialogue(cancelled: bool = false) -> void:
	var callback := dialogue_done
	var cancel_callback := dialogue_cancelled
	dialogue_done=Callable()
	dialogue_cancelled=Callable()
	if is_instance_valid(dialogue_panel):
		dialogue_panel.set_process_unhandled_key_input(false)
		dialogue_panel.hide()
		dialogue_panel.queue_free()
	dialogue_panel=null
	dialogue_label=null
	dialogue.clear()
	if is_instance_valid(audio):
		audio.set_dialogue_active(false)
	overlay.hide()
	modal_kind=""
	if is_instance_valid(world):
		world.set_dialogue_hold(false)
		world.blocked=session!=null
	if is_instance_valid(hud): hud.show()
	if cancelled:
		if cancel_callback.is_valid(): cancel_callback.call()
	elif callback.is_valid():
		callback.call()

func _cancel_dialogue() -> void:
	_finish_dialogue(true)

func _dialogue_panel_exiting(panel: Control) -> void:
	if dialogue_panel!=panel: return
	if is_instance_valid(audio):
		audio.set_dialogue_active(false)
	dialogue_panel=null
	dialogue_label=null
	dialogue_done=Callable()
	dialogue_cancelled=Callable()
	dialogue.clear()
	if modal_kind=="dialogue":
		modal_kind=""
		if is_instance_valid(world):
			world.set_dialogue_hold(false)
			world.blocked=session!=null

func _dialogue_panel_resized() -> void:
	if not is_instance_valid(dialogue_panel): return
	var scale_factor := Paper.physical_scale(dialogue_panel)
	Paper.adapt_menu(dialogue_panel, scale_factor)
	if is_instance_valid(dialogue_label): dialogue_label.custom_minimum_size.y=82.0/scale_factor
	var plaque := dialogue_panel.find_child("DialoguePlaque", true, false) as Control
	var height := 210.0/scale_factor
	if plaque != null:
		plaque.custom_minimum_size=Vector2(get_viewport().get_visible_rect().size.x-48.0/scale_factor,0)
		height=maxf(height,plaque.get_combined_minimum_size().y)
		plaque.custom_minimum_size.y=height
	var center := dialogue_panel.get_child(0) as CenterContainer
	center.anchor_top=1.0
	center.anchor_bottom=1.0
	center.offset_left=24.0/scale_factor
	center.offset_right=-24.0/scale_factor
	center.offset_top=-height-20.0/scale_factor
	center.offset_bottom=-20.0/scale_factor

func _interact(id: String, title: String) -> void:
	audio.play_sfx("interact")
	if world.coastal_play.activate(id):
		return
	if id.begins_with("game-"):
		_show_game_info(id)
	elif id=="arrival":
		_start_dialogue(story.intro_lines(),func(): Progress.intro_seen=true; Progress.save_progress(),func(): Progress.intro_seen=true; Progress.save_progress())
	elif id=="guide":
		_start_dialogue(story.main_lines(),func(): Progress.grant_photo("photo-welcome-story-1"); _notice("第一張主線拍貼，收進本子裡了。"))
	elif id=="quest-001" or id=="quest-002":
		var actor_lines := _actor_dialogue_lines(id)
		_start_dialogue(actor_lines,func():
			_record_story_mission_event({"type":"interaction","id":id})
			_show_quest(id)
		,func(): _record_story_mission_event({"type":"interaction","id":id}))
	elif id=="ride-tide":
		if world.is_riding():
			world.end_ride()
		else:
			world.start_ride()
	elif id=="album": _show_album()
	elif id=="settings": _show_settings()
	elif id=="clock":
		world.set_night(not world.night)
		_notice("夜晚亮起來了。" if world.night else "陽光回到島上了。")
	elif id.begins_with("coast:"):
		var discovery: Dictionary = world.coast_description(id)
		if not discovery.is_empty():
			_start_dialogue([{ "speaker":str(discovery.name), "text":str(discovery.text) }],Callable())
	elif id.begins_with("explore-"): _show_exploration(id)
	elif id=="rift":
		var body := _open(title,"LITTLE DEVILS","rift")
		body.add_child(Paper.label("集齊迎賓大道十二張小惡魔拍貼，倒影大道的門就會記住你。\n目前 %d / 12。"%Progress.devil_count(),24))
		body.add_child(Paper.label("倒影大道正在準備新的布景；本版保留入口。",22))
		_back(body)
	elif id.begins_with("gate:"):
		var data: Dictionary=world.park_data()
		for zone in data.zones:
			if zone.id==id.trim_prefix("gate:"):
				var body := _open(zone.name,"NEXT ADVENTURE","gate")
				body.add_child(Paper.label(zone.theme,25))
				body.add_child(Paper.label("入園資格：%d 張不同普通拍貼（不消耗）\n目前：%d 張\n\n這座園區正在準備中。先去迎賓大道留下今天的回憶吧。"%[zone.threshold,Progress.normal_count()],22))
				_back(body)
				break

func _actor_dialogue_lines(quest_id: String) -> Array:
	var mission: Dictionary=story.quest_data(quest_id).get("mission",{})
	var speaker := str(mission.get("speaker", ""))
	var lines: Array=[]
	for line: Dictionary in story.main_lines():
		if str(line.get("speaker", "")) == speaker:
			lines.append(line)
	return lines

func _definition(id: String) -> Dictionary:
	for definition in definitions:
		if definition.get("id","")==id: return definition
	return {}

func _show_game_info(id: String) -> void:
	var definition := _definition(id)
	if definition.is_empty():
		_notice("這個設施暫時休息中，先逛逛其他地方吧。")
		return
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	modal_body=null
	overlay.show()
	modal_kind="game_info"
	hud.hide()
	world.blocked=true
	world.set_process(true)
	audio.set_paused(false)
	var invitation := preload("res://game/ui/island_game_invite.gd").new()
	invitation.definition=definition
	invitation.start_requested=_request_game_start.bind(id,bool(Progress.settings.get("assist",false)))
	invitation.rules_requested=_show_game_rules.bind(id)
	invitation.close_requested=_close
	overlay.add_child(invitation)

func _show_game_rules(id: String) -> void:
	var definition := _definition(id)
	var body := _open(str(definition.get("name",id)),"迎賓大道  /  玩法與選項","game_rules")
	var entry_stamp := HBoxContainer.new()
	entry_stamp.add_theme_constant_override("separation",8)
	body.add_child(entry_stamp)
	entry_stamp.add_child(Paper.icon("ticket",23,Paper.CORAL))
	entry_stamp.add_child(Paper.label("免費重玩   ·   收藏不消耗",18,Paper.TEAL))
	var objective_card := Paper.card(body,Color("#fffaf0"),8)
	objective_card.name="GameRulesDetails"
	objective_card.add_child(Paper.section_title("本局目標"))
	objective_card.add_child(Paper.label(str(definition.get("goal","完成挑戰")),22))
	Paper.divider(objective_card)
	objective_card.add_child(Paper.section_title("操作方式",Paper.DEEP_TEAL))
	objective_card.add_child(Paper.label(str(definition.get("instructions","依畫面提示操作。")),20))
	var notes := [
		{"text":"小惡魔："+str(definition.get("devil_hint","完成特殊互動。")),"color":Paper.TEAL},
		{"text":"完成一般目標可收藏普通拍貼；達成特別條件也會收進小惡魔拍貼。","color":Paper.INK},
		{"text":"輔助遊玩會放寬時間或判定，收藏資格相同。練習不記錄分數與收藏。","color":Paper.TEAL},
	]
	_content_pager(body,"GameRulesExtraDetails",notes,_render_rules_note,1,entry_stamp)
	var row := modal_footer
	row.add_theme_constant_override("separation",8)
	Paper.button("圖解教學",func(): _open_tutorial(id,"game_info",bool(Progress.settings.get("assist",false))),row)
	Paper.button("練習操作",func(): _launch_game(id,bool(Progress.settings.get("assist",false)),true),row)
	Paper.button("開始遊玩",func(): _request_game_start(id,bool(Progress.settings.get("assist",false))),row).grab_focus()
	Paper.button("輔助挑戰",func(): _request_game_start(id,true),row)
	_back(body)

func _request_game_start(id: String, assist: bool) -> void:
	if not Progress.has_seen_tutorial(id):
		_open_tutorial(id,"first_entry",assist)
		return
	_launch_game(id,assist)

func _launch_game(id: String, assist: bool, practice: bool = false) -> void:
	if _definition(id).is_empty():
		_notice("這個設施暫時無法開啟，請先逛逛其他地方。")
		return
	photo_frames.clear()
	photo_original_frames.clear()
	next_snapshot=1.0
	overlay.hide()
	modal_kind=""
	hud.hide()
	world.blocked=true
	world.hide()
	world.set_process(false)
	session=Session.new()
	ui.add_child(session)
	session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session.theme=Paper.theme()
	session.finished.connect(_game_finished)
	session.cancelled.connect(_cancel_game)
	session.help_requested.connect(func(game_id: String): _open_tutorial(game_id,"session",assist))
	session.note_played.connect(audio.play_note)
	session.feedback.connect(audio.play_gameplay_feedback)
	if session.has_method("set_time_of_day"):
		session.set_time_of_day(TimeOfDay.normalize(Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE)))
	session.start(id,assist)
	if practice and session.has_method("set_practice_mode"):
		session.set_practice_mode(true)
	audio.play_context("game", id)

func _cancel_game() -> void:
	if session!=null:
		ui.remove_child(session)
		session.queue_free()
		session=null
	_sync_audio_environment()
	audio.play_context("harbor" if world.current_area=="海風碼頭" else "plaza")
	hud.show()
	world.blocked=false
	world.show()
	world.set_process(true)

func _game_finished(result: Dictionary) -> void:
	var id := str(result.get("game_id",""))
	var practice := bool(result.get("practice",false))
	var saved_frames: Array[String] = []
	var saved_original_frames: Array[String] = []
	if bool(result.get("success",false)) and not practice and DisplayServer.get_name()!="headless":
		# The completed session will draw its end overlay on the next frame. Keep
		# the most recent rendered gameplay image instead of photographing that UI.
		_append_photo_snapshot()
		saved_frames=_save_photo_frames(id)
		saved_original_frames=_save_photo_original_frames(id)
	if bool(result.get("success",false)) and not practice:
		celebrate_on_close=true
		Progress.complete_game(id,bool(result.get("devil",false)),bool(result.get("assisted",false)))
		_record_story_mission_event({"type":"minigame_result","id":id,"success":true,"practice":false})
		if not saved_frames.is_empty():
			_sync_finished_photo_thumbnails(result,saved_frames,saved_original_frames)
	_cancel_game()
	audio.play_sfx("success" if result.get("success",false) else "miss")
	var definition := _definition(id)
	var result_title := "練習完成" if practice else ("今天的這一格，值得留下。" if result.get("success",false) else "差一點！再玩一次就好。")
	var body := _open(result_title,"本局紀錄  /  "+str(definition.get("name",id)),"result")
	var result_summary := HBoxContainer.new()
	result_summary.add_theme_constant_override("separation",8)
	body.add_child(result_summary)
	result_summary.add_child(Paper.icon("album",23,Paper.CORAL if practice else Paper.TEAL))
	var score_line := "練習分數 %d（不保存）"%int(result.get("score",0)) if practice else "本次成績 %d   ·   %s"%[int(result.get("score",0)),"輔助遊玩" if result.get("assisted",false) else "標準遊玩"]
	result_summary.add_child(Paper.label(score_line,20))
	if result.get("success",false) and not practice:
		var award := HBoxContainer.new()
		award.add_theme_constant_override("separation",8)
		body.add_child(award)
		award.add_child(Paper.icon("album",24,Paper.TEAL))
		award.add_child(Paper.label("普通拍貼已收藏",20,Paper.TEAL))
		if result.get("devil",false):
			award.add_child(Paper.icon("devil",24,Paper.CORAL))
			award.add_child(Paper.label("小惡魔也入鏡了",20,Paper.CORAL))
	elif practice:
		body.add_child(Paper.label("這是私人練習回合；分數、拍貼、任務與成就都沒有寫入紀錄。",20,Paper.DEEP_TEAL))
	else:
		body.add_child(Paper.label("沒有扣除任何收藏。也可以開啟輔助，試試別的節奏。",22))
	var qualification_text:=str(result.get("score_summary",{}).get("qualification_text",""))
	if not qualification_text.is_empty():
		var qualification:=Paper.label(qualification_text,17,Paper.TEAL)
		qualification.name="ResultQualification"
		qualification.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		qualification.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		body.add_child(qualification)
	var result_columns := HBoxContainer.new()
	result_columns.name="ResultColumns"
	result_columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	result_columns.add_theme_constant_override("separation",16)
	body.add_child(result_columns)
	var detail := VBoxContainer.new()
	detail.name="ResultScoreDetail"
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio=0.65
	result_columns.add_child(detail)
	detail.add_child(Paper.section_title("得分明細"))
	var score_summary: Dictionary=result.get("score_summary",{})
	var score_rows: Array=score_summary.get("rows",[])
	var rows: Array=[]
	for score_row in score_rows:
		if score_row is Dictionary: rows.append(score_row)
	if rows.is_empty(): rows.append({"label":"本局分數已顯示於上方。","empty":true})
	_content_pager(detail,"ResultScorePages",rows,_render_score_row,1)
	if not practice:
		var frames := GridContainer.new()
		frames.name="ResultPhotoFrames"
		frames.columns=2
		frames.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		frames.size_flags_vertical=Control.SIZE_EXPAND_FILL
		frames.add_theme_constant_override("h_separation",8)
		frames.add_theme_constant_override("v_separation",8)
		result_columns.add_child(frames)
		for i in range(4):
			var content := VBoxContainer.new()
			content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			content.size_flags_vertical=Control.SIZE_EXPAND_FILL
			frames.add_child(content)
			var thumbnail := TextureRect.new()
			thumbnail.name="ResultPhoto%d"%i
			thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.size_flags_vertical=Control.SIZE_EXPAND_FILL
			if not saved_frames.is_empty(): thumbnail.texture=_photo_texture(saved_frames[mini(i,saved_frames.size()-1)])
			content.add_child(thumbnail)
			content.add_child(Paper.label("第 %d 格%s"%[i+1," · 未拍攝" if saved_frames.is_empty() else ""],16,Paper.TEAL))
	Paper.button("再練一次" if practice else "再玩一次",func(): _launch_game(id,bool(result.get("assisted",false)),practice),modal_footer).grab_focus()
	if not practice:
		Paper.button("練習操作",func(): _launch_game(id,bool(result.get("assisted",false)),true),modal_footer)
		Paper.button("輔助重試",func(): _launch_game(id,true),modal_footer)
	_back(body)

func _sync_finished_photo_thumbnails(result: Dictionary, saved_frames: Array[String], saved_original_frames: Array[String] = []) -> bool:
	if not bool(result.get("success",false)) or bool(result.get("practice",false)):
		return false
	return Progress.attach_welcome_game_photo_frames(str(result.get("game_id","")),saved_frames,bool(result.get("devil",false)),saved_original_frames)

func _show_album() -> void:
	var body := _open("一張照片，一點小事。","PHOTO COLLECTION","album")
	var book_script = load("res://game/ui/collection_book_panel.gd")
	var book = book_script.new()
	book.setup(Progress,definitions,TimeOfDay.PHASES,Callable(self,"_photo_texture"))
	book.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	book.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(book)
	_back(body)

func _show_tasks() -> void:
	var body := _open("今天，幫誰一個小忙？","ISLAND QUESTS","tasks")
	body.add_child(Paper.label("委託會自動保存；選一張旅券即可接續目前進度。",18,Paper.DEEP_TEAL))
	_content_pager(body,"TaskPages",["quest-001","quest-002"],_render_task_card,1)
	body.add_child(Paper.label("小角和阿浪在迎賓大道的左右步道等你。",18,Paper.TEAL))
	_back(body)

func _render_task_card(parent: VBoxContainer, id: String, _index: int) -> void:
	var quest: Dictionary=story.quest_data(id)
	var step := int(Progress.quests.get(id,0))
	var card := Paper.card(parent,Color("#fffaf0"),6)
	card.name="Task_"+id
	card.add_child(Paper.section_title(str(quest.get("title",id))))
	card.add_child(Paper.label("%s  ·  進度 %d / 3"%["已完成" if step>=3 else "進行中" if step>0 else "尚未開始",step],18,Paper.DEEP_TEAL))
	Paper.button("%s委託"%["查看" if step>=3 else "接續" if step>0 else "開始"],func(): _show_quest(id),card)

func _render_rules_note(parent: VBoxContainer, note: Dictionary, index: int) -> void:
	var label := Paper.label(str(note.text),18,note.color)
	label.name="RulesNote%d"%index
	parent.add_child(label)

func _render_score_row(parent: VBoxContainer, row: Dictionary, index: int) -> void:
	var text := str(row.get("label","得分"))
	if bool(row.get("progress_only",false)):
		text+="  ·  %d 次"%int(row.get("count",0))
	elif not bool(row.get("empty",false)):
		text+="  ·  %d 分"%int(row.get("amount",0))
	var label := Paper.label(text,18)
	label.name="ResultScoreRow%d"%index
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)

func _show_quest(id: String) -> void:
	var quest: Dictionary=story.quest_data(id)
	var step := int(Progress.quests.get(id,0))
	var quest_title := str(quest.get("title","")).strip_edges()
	if quest_title.is_empty(): quest_title="任務目標"
	var subtitle := "旅券 · 已完成" if step>=3 else "旅券 · 第%d步 / 3"%(step+1)
	var body := _open(quest_title,subtitle,"quest")
	if step>=3:
		body.add_child(Paper.label("今天的小麻煩，已經變成了拍貼裡的笑話。",24))
		_back(body)
		return
	var mission: Dictionary=story.quest_mission_data(id)
	var steps: Array=mission.get("steps",[])
	if step < 0 or step >= steps.size():
		push_error("Story mission '%s' has no step at saved cursor %d." % [id, step])
		body.add_child(Paper.label("這張旅券的進度資料無法讀取。請先返回遊園。",20,Paper.CORAL))
		_back(body)
		return
	var data: Dictionary=steps[step]
	var prompt_card := Paper.card(body,Color("#fffaf0"),8)
	var step_title := str(data.get("title","")).strip_edges()
	if step_title.is_empty(): step_title="任務目標"
	prompt_card.add_child(Paper.section_title("第 %d 步  ·  %s"%[step+1,step_title]))
	prompt_card.add_child(Paper.label(str(data.get("goal","請依旅券提示完成園區目標。")),22))
	match str(data.get("kind","")):
		"photo": prompt_card.add_child(Paper.label("完成指定園區合照後，這一步會自動蓋章。",18,Paper.TEAL))
		"observation": prompt_card.add_child(Paper.label("到展示燈旁觀察方向，或拍下正確對準的歡迎牆合照。",18,Paper.TEAL))
		"minigame_result": prompt_card.add_child(Paper.label("正式成功完成指定設施即可；練習回合不會推進旅券。",18,Paper.TEAL))
		_: prompt_card.add_child(Paper.label("走到角色身旁按 E 互動即可接續。",18,Paper.TEAL))
	_back(body)

func _advance_quest(id: String, step: int, quest: Dictionary) -> void:
	Progress.advance_quest(id,step+1)
	if step+1==3:
		Progress.grant_photo(quest.get("photo_id","photo-welcome-quest-%d"%(1 if id=="quest-001" else 2)))
		audio.play_sfx("success")
	_show_quest(id)

func _record_story_mission_event(evidence: Dictionary) -> void:
	for quest_id in ["quest-001", "quest-002"]:
		var cursor := int(Progress.quests.get(quest_id, 0))
		var event := evidence.duplicate(true)
		for _attempt in range(3):
			var result: Dictionary = story.mission_event_result(quest_id, cursor, event)
			if not bool(result.get("accepted", false)):
				# Saved source photos are durable proof of earlier real actions/results.
				# Practice games never persist their source photo, so cannot satisfy this path.
				var stored_evidence := _stored_mission_evidence(quest_id, cursor)
				if stored_evidence.is_empty():
					break
				event = stored_evidence
				result = story.mission_event_result(quest_id, cursor, event)
				if not bool(result.get("accepted", false)):
					break
			Progress.advance_quest(quest_id, int(result.get("next_step", cursor)))
			cursor = int(result.get("next_step", cursor))
			if bool(result.get("complete", false)):
				var reward_id := str(result.get("reward_photo_id", ""))
				if not reward_id.is_empty() and not Progress.photos.has(reward_id):
					Progress.grant_photo(reward_id)
				audio.play_sfx("success")
				break
			event = _stored_mission_evidence(quest_id, cursor)
			if event.is_empty():
				break

func _stored_mission_evidence(quest_id: String, cursor: int) -> Dictionary:
	var mission: Dictionary = story.quest_mission_data(quest_id)
	var steps: Array = mission.get("steps", [])
	if cursor < 0 or cursor >= steps.size():
		return {}
	var step: Dictionary = steps[cursor]
	var kind := str(step.get("kind", ""))
	var target_id := str(step.get("target_id", ""))
	if kind == "photo" and Progress.photos.has(target_id):
		return {"type":"photo_collected", "id":target_id}
	if kind == "observation":
		var proof_id := str(step.get("proof_photo_id", ""))
		if not proof_id.is_empty() and Progress.photos.has(proof_id):
			return {"type":"photo_collected", "id":proof_id}
	if kind == "minigame_result":
		var game_number := int(target_id.trim_prefix("game-"))
		var source_id := "photo-welcome-game-%d" % game_number
		if Progress.photos.has(source_id):
			return {"type":"minigame_result", "id":target_id, "success":true, "practice":false}
	return {}

func _show_exploration(id: String) -> void:
	var index := int(id.trim_prefix("explore-"))
	var titles := ["花壇會眨眼","歡迎字樣的影子","長椅雙人份"]
	var prompts := ["花朵的眼睛跟著你轉。站在笑臉腳印上，要做什麼表情？","展示燈的影子還沒進框。試著把燈轉向歡迎牆。","長椅空著一個座位。免費借用架上有小角的立牌。"]
	var choices := [["微笑，等花朵一起眨眼","扮鬼臉，逗花朵笑"],["向左轉  ·  對準空框","向右轉  ·  看看影子"],["借一個小角立牌，拍合照","讓立牌戴帽子，再拍一張"]]
	var body := _open(titles[index-1],"DISCOVERY / 自由探索","explore")
	var zones := HBoxContainer.new()
	zones.name="ExplorationZones"
	zones.size_flags_vertical=Control.SIZE_EXPAND_FILL
	zones.add_theme_constant_override("separation",18)
	body.add_child(zones)
	var controls := VBoxContainer.new()
	controls.name="ExplorationControls"
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.size_flags_stretch_ratio=0.85
	controls.add_theme_constant_override("separation",8)
	controls.add_child(Paper.label(prompts[index-1],20))
	var stage := PhotoStage.new()
	stage.kind=["flower","shadow","bench"][index-1]
	stage.reduced_motion=bool(Progress.settings.get("reduced_motion",false))
	stage.name="ExplorationPhotoStage"
	stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	zones.add_child(stage)
	zones.add_child(controls)
	if index==2:
		stage.offset=-90
		var slider := HSlider.new()
		slider.min_value=-120
		slider.max_value=120
		slider.value=-90
		slider.step=1
		slider.value_changed.connect(func(value: float): stage.offset=value)
		slider.name="ExplorationLightSlider"
		slider.custom_minimum_size.y=44
		controls.add_child(slider)
	else:
		for i in range(choices[index-1].size()):
			var choice_index := i
			Paper.button(choices[index-1][i],func():
				if index==1: stage.flower_face=choice_index+1
				else: stage.borrowed=true; stage.pose=choice_index
			,controls)
	Paper.button("按下快門",func():
		if index==1 and stage.flower_face==0:
			_notice("先選個表情，花朵正看著你。")
			return
		if index==2 and absf(stage.offset)>15:
			_notice("影子還沒進框，慢慢調整燈的位置。")
			return
		if index==3 and not stage.borrowed:
			_notice("先從免費借用架拿一個小角立牌。")
			return
		if world.has_method("play_action"): world.play_action("photo")
		var photo_id := "photo-welcome-explore-%d" % index
		Progress.grant_photo(photo_id,{"pose":stage.pose})
		_record_story_mission_event({"type":"photo_collected","id":photo_id})
		audio.play_sfx("success")
		_close()
		_notice("探索拍貼已收藏："+titles[index-1])
	,controls)
	_back(body)

func _show_achievements() -> void:
	var body := _open("那些「我做到了」的小瞬間。","ACHIEVEMENTS","achievements")
	var stamp_script = load("res://game/ui/achievement_stamp_book.gd")
	var stamp_book = stamp_script.new()
	stamp_book.setup(Progress,definitions)
	stamp_book.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stamp_book.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(stamp_book)
	_back(body)

func _show_map() -> void:
	var body := _open("今天想去哪一邊？","ISLAND MAP","map")
	var map_script = load("res://game/ui/island_map_panel.gd")
	var map_panel = map_script.new()
	var park_data: Dictionary=world.park_data()
	map_panel.setup(park_data.get("zones",[]),definitions,Progress.normal_count(),world.points)
	map_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(map_panel)
	_back(body)

func _show_settings() -> void:
	var body := _open("把這趟遊園，調成你的步調。","SETTINGS","settings")
	var settings := SettingsPanel.new()
	settings.open(self,body)
	_back(body)

func _on_locale_changed(_locale_id: String) -> void:
	_refresh()
	if is_instance_valid(dialogue_panel) and dialogue_index < dialogue.size():
		var line: Dictionary = dialogue[dialogue_index]
		if line.has("speaker_key"):
			var speaker_args: Dictionary = line.get("speaker_args", {})
			dialogue_panel.speaker_label.text = Localization.text(str(line.speaker_key), speaker_args)
		if line.has("text_key") and is_instance_valid(dialogue_label):
			var text_args: Dictionary = line.get("text_args", {})
			var shown_characters := dialogue_label.visible_characters
			dialogue_label.text = Localization.text(str(line.text_key), text_args)
			dialogue_label.visible_characters = shown_characters

func _show_wardrobe() -> void:
	var body := _open("把海風穿在身上。","WARDROBE  /  裁縫店","wardrobe")
	wardrobe_panel=WardrobePanel.new()
	wardrobe_panel.open(self,body)

func _notice(message: String) -> void:
	toast.text=message
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func(): if is_instance_valid(toast) and toast.text==message: toast.text="")

func _achievement_toast(id: String) -> void:
	var label := ""
	if id.begins_with("ACH_GAME_"):
		label=str(_definition("game-%03d"%int(id.trim_prefix("ACH_GAME_"))).get("name","小遊戲"))+"的第一張照片"
	else:
		label={"ACH_WELCOME_CLEAR":"迎賓大道通關","ACH_WELCOME_DEVILS":"迎賓小惡魔全收藏","ACH_ALL_DEVILS":"全島小惡魔全收藏",TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS:"四時留影"}.get(id,"新的旅途紀念")
	_notice("成就解鎖  ✦  "+label)

func _capture_sequence() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		await _abort_capture("Capture requires isolated SNAPLAND_SAVE_PATH")
		return
	await get_tree().create_timer(2).timeout
	world.player.position=Vector3(0,0.4,-6)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-3-day.png"): return
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-hud.png"): return
	world.set_night(true)
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-3-night.png"): return
	world.set_night(false)
	world.player.position=Vector3(0,0.4,18)
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-3-dock.png"): return
	world.player.position=Vector3(0,0.4,-22)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-3-avenue.png"): return
	_start_dialogue([story.intro_lines()[0]],Callable())
	reveal=1000
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-4-ticket-portrait.png"): return
	_start_dialogue([story.intro_lines()[2]],Callable())
	reveal=1000
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-4-kaku-portrait.png"): return
	_show_album()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-album.png"): return
	_show_settings()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-settings.png"): return
	_show_achievements()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-achievements.png"): return
	_start_dialogue(story.intro_lines(),Callable())
	reveal=1000
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-dialogue.png"): return
	_show_quest("quest-001")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-quest.png"): return
	_show_game_info("game-001")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-game-info.png"): return
	_close()
	_launch_game("game-011",false)
	await get_tree().create_timer(1.2).timeout
	for key in [KEY_1,KEY_2,KEY_2,KEY_3,KEY_2,KEY_4]:
		var pressed := InputEventKey.new()
		pressed.keycode=key
		pressed.pressed=true
		Input.parse_input_event(pressed)
		await get_tree().process_frame
		pressed=InputEventKey.new()
		pressed.keycode=key
		pressed.pressed=false
		Input.parse_input_event(pressed)
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	if modal_kind!="result" or not Progress.photos.has("photo-welcome-game-11"):
		await _abort_capture("Native photo result verification failed")
		return
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-result.png"): return
	_show_album()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	if not await _capture_or_abort("pm/Snapland-art/images/ART-6-album-earned.png"): return
	_close()
	print("CAPTURE PASS: native GPU views saved")
	await _quit_game()


func _sample_photo() -> void:
	if DisplayServer.get_name()=="headless": return
	var source_session := session
	await RenderingServer.frame_post_draw
	if not is_instance_valid(source_session) or session!=source_session or session.ended or session.paused or is_instance_valid(tutorial_panel): return
	_append_photo_snapshot()

func _photo_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		push_warning("Missing photo at "+path)
		return null
	var photo := Image.load_from_file(path)
	if photo==null:
		push_warning("Unreadable photo at "+path)
		return null
	photo.resize(320,180,Image.INTERPOLATE_LANCZOS)
	photo.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(photo)

func _save_photo_frames(id: String) -> Array[String]:
	var paths: Array[String]=[]
	var directory := _photo_directory()
	var err := DirAccess.make_dir_recursive_absolute(directory)
	if err!=OK:
		push_warning("Cannot create photo directory: "+directory)
		return paths
	for i in range(photo_frames.size()):
		var path := directory+"/"+id+"-%d.png"%i
		if photo_frames[i].save_png(path)==OK: paths.append(path)
		else: push_warning("Cannot save photo frame: "+path)
	return paths

func _save_photo_original_frames(id: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := _photo_directory()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning("Cannot create original photo directory: " + directory)
		return paths
	for index in range(photo_original_frames.size()):
		var path := "%s/%s-original-%d.png" % [directory, id, index]
		if _save_bounded_photo_image(photo_original_frames[index], path):
			paths.append(path)
	return paths

func _save_bounded_photo_image(image: Image, path: String) -> bool:
	if image == null or image.is_empty() or image.get_width() * image.get_height() > 4 * 1024 * 1024:
		push_warning("Skipping original photo outside the 4-megapixel limit: " + path)
		return false
	var error := image.save_png(path)
	var file_size := -1
	if FileAccess.file_exists(path):
		var saved_file := FileAccess.open(path, FileAccess.READ)
		if saved_file != null:
			file_size = saved_file.get_length()
			saved_file.close()
	if error != OK or file_size < 45 or file_size > 16 * 1024 * 1024:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		push_warning("Cannot save bounded original photo: " + path)
		return false
	return true

func _remove_photo_paths(paths: Array) -> void:
	for path_value in paths:
		var path := str(path_value)
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _photo_directory() -> String:
	# Preview sessions never write into the player's real profile.
	var override := OS.get_environment("SNAPLAND_SAVE_PATH")
	return (override.get_base_dir()+"/photos") if not override.is_empty() else ProjectSettings.globalize_path("user://photos")

func _capture(relative: String) -> bool:
	var path := ProjectSettings.globalize_path("res://"+relative)
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error!=OK and directory_error!=ERR_ALREADY_EXISTS:
		push_error("Screenshot directory creation failed: "+path.get_base_dir()+" "+str(directory_error))
		return false
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error!=OK:
		push_error("Screenshot save failed: "+path+" "+str(error))
		return false
	return true

func _capture_or_abort(relative: String) -> bool:
	if _capture(relative): return true
	await _abort_capture("Capture sequence stopped after screenshot write failure")
	return false

func _abort_capture(reason: String) -> void:
	push_error(reason)
	world.blocked=true
	world.set_process(false)
	audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
func _adapt_hud() -> void:
	if not is_instance_valid(hud): return
	var scale_factor := Paper.physical_scale(hud)
	Paper.adapt_menu(hud,scale_factor)
	var banner := hud.get_node("ParkKeepsakeBanner") as Control
	banner.position=Vector2(24,20)/scale_factor
	banner.custom_minimum_size=Vector2(320,48)/scale_factor
	banner.size=banner.get_combined_minimum_size().max(banner.custom_minimum_size)
	ticket_button.offset_left=-222.0/scale_factor
	ticket_button.offset_right=-24.0/scale_factor
	ticket_button.offset_top=24.0/scale_factor
	ticket_button.offset_bottom=72.0/scale_factor
	ticket_button.custom_minimum_size=Vector2(198,48)/scale_factor
	var ticket_extent := ticket_button.get_combined_minimum_size().max(Vector2(198,48)/scale_factor)
	ticket_button.offset_left=ticket_button.offset_right-ticket_extent.x
	ticket_button.offset_bottom=ticket_button.offset_top+ticket_extent.y
	quest_label.position=Vector2(28,80)/scale_factor
	quest_label.size=Vector2(376,48)/scale_factor
	context_bar.offset_left=-200.0/scale_factor
	context_bar.offset_right=200.0/scale_factor
	context_bar.offset_top=-70.0/scale_factor
	context_bar.offset_bottom=-18.0/scale_factor
	context_bar.custom_minimum_size=Vector2(240,44)/scale_factor
	var context_extent := context_bar.get_combined_minimum_size().max(Vector2(240,44)/scale_factor)
	context_bar.offset_left=-context_extent.x*0.5
	context_bar.offset_right=context_extent.x*0.5
	context_bar.offset_top=context_bar.offset_bottom-context_extent.y
	toast.offset_left=-310.0/scale_factor
	toast.offset_right=310.0/scale_factor
	toast.offset_top=190.0/scale_factor
	toast.offset_bottom=280.0/scale_factor

func _menu_preferred_size(kind: String) -> Vector2:
	if kind=="pause": return Vector2(1040,620)
	if kind=="ticket": return Vector2(1060,560)
	if kind=="album": return Vector2(1200,720)
	if kind=="time": return Vector2(1000,650)
	if kind=="wardrobe": return Vector2(1080,650)
	if kind=="tasks": return Vector2(1040,650)
	var tall_kinds := ["settings","achievements","map","wardrobe"]
	return Vector2(1040,600 if tall_kinds.has(kind) else 520)

func _adapt_open_menu() -> void:
	if not is_instance_valid(overlay) or not overlay.visible: return
	var scale_factor := Paper.physical_scale(overlay)
	_adapt_content_pagers(get_viewport().get_visible_rect().size.y*scale_factor<620.0)
	Paper.adapt_menu(overlay,scale_factor)
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y*scale_factor<620.0
	var tall_text := Paper.font().get_height(ceili(20.0*Paper.text_scale()/scale_factor))*scale_factor>44.0
	var header := overlay.find_child("AdaptiveMenuHeader",true,false) as Control
	var footer := overlay.find_child("AdaptiveMenuFooter",true,false) as Control
	if header!=null: header.custom_minimum_size.y=(40.0 if compact else 56.0)/scale_factor
	if footer!=null: footer.custom_minimum_size.y=0.0 if footer.get_child_count()==0 else (44.0 if compact else 64.0)/scale_factor
	var menu_margin := overlay.find_child("AdaptiveMenuMargin",true,false) as MarginContainer
	if menu_margin!=null:
		for side in ["top","bottom"]: menu_margin.add_theme_constant_override("margin_"+side,4 if compact else 10)
	var menu_shell := overlay.find_child("AdaptiveMenuShell",true,false) as VBoxContainer
	if menu_shell!=null: menu_shell.add_theme_constant_override("separation",4 if compact else 8)
	var eyebrow := overlay.find_child("AdaptiveMenuEyebrow",true,false) as Label
	if eyebrow!=null: eyebrow.visible=not compact
	var title_label := overlay.find_child("AdaptiveMenuTitle",true,false) as Label
	if title_label!=null and compact and modal_kind=="pause":
		title_label.add_theme_font_size_override("font_size",ceili(18.0*Paper.text_scale()/scale_factor))
	var panel := overlay.find_child("AdaptiveMenuPanel",true,false) as Control
	if panel!=null: _layout_open_panel(panel)
	call_deferred("_fit_modal_viewport")
	var pause_actions := overlay.find_child("PauseActions",true,false) as GridContainer
	if pause_actions!=null:
		pause_actions.columns=2
		for grid in pause_actions.find_children("PauseActionGrid","GridContainer",true,false):
			grid.columns=2 if tall_text else 1
		for button in pause_actions.find_children("*","Button",true,false):
			button.custom_minimum_size.y=(44.0 if compact else 64.0)/scale_factor
	var pause_status := overlay.find_child("PauseIslandStatus",true,false) as Control
	if pause_status!=null: pause_status.visible=not (compact and tall_text)
	var portrait := overlay.find_child("PausePlayerPortrait",true,false) as TextureRect
	if portrait!=null:
		var portrait_height := 82.0 if compact or tall_text else 150.0
		portrait.custom_minimum_size=Vector2(portrait_height*0.82,portrait_height)
	var pause_heading := overlay.find_child("PauseIslandHeading",true,false) as Label
	if pause_heading!=null and compact:
		pause_heading.add_theme_font_size_override("font_size",ceili(14.0*Paper.text_scale()/scale_factor))
	var pause_area := overlay.find_child("PauseCurrentArea",true,false) as Label
	if pause_area!=null and compact:
		pause_area.add_theme_font_size_override("font_size",ceili(14.0*Paper.text_scale()/scale_factor))
	var pause_phase := overlay.find_child("PauseCurrentPhase",true,false) as Label
	if pause_phase!=null and compact:
		pause_phase.add_theme_font_size_override("font_size",ceili(14.0*Paper.text_scale()/scale_factor))
	var pause_collection := overlay.find_child("PauseCollectionStatus",true,false) as Control
	if pause_collection!=null: pause_collection.visible=not compact and not tall_text
	var pause_saved := overlay.find_child("PauseSavedStatus",true,false) as Control
	if pause_saved!=null: pause_saved.visible=not (compact and tall_text)
	var chart := overlay.find_child("IslandChartCanvas",true,false)
	if chart!=null and chart.get_parent().get_parent().has_method("_layout_map_buttons"):
		chart.get_parent().get_parent().call_deferred("_layout_map_buttons")

func _layout_open_panel(panel: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := Paper.physical_scale(overlay)
	var preferred := _menu_preferred_size(modal_kind)
	var width := minf(preferred.x/scale_factor,viewport_size.x-36.0/scale_factor)
	var height := minf(preferred.y/scale_factor,viewport_size.y-36.0/scale_factor)
	# Stamp pages need the available logical height, including fixed navigation.
	if modal_kind=="achievements": height=viewport_size.y-36.0/scale_factor
	# CenterContainer owns the panel geometry; its minimum is the desired shell
	# extent, while real content minima remain visible to Godot's layout system.
	panel.custom_minimum_size=Vector2(width,height)

func _show_ticket() -> void:
	var body := _open("航海旅券","ISLAND GUIDE","ticket")
	var groups := GridContainer.new()
	groups.name="TicketNavigation"
	groups.columns=2
	groups.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	groups.size_flags_vertical=Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("h_separation",16)
	groups.add_theme_constant_override("v_separation",8)
	body.add_child(groups)
	var entries := [
		["島嶼地圖",_show_map,"探索島嶼"], ["今日任務",_show_tasks,"探索島嶼"],
		["拍貼收藏本",_show_album,"收藏記錄"], ["遊園成就",_show_achievements,"收藏記錄"],
		["衣櫃與服飾店",_show_wardrobe,"整裝出發"], ["切換時段",_open_time_panel_from_ticket,"遊園安排"],
		["設定與輔助",_show_settings,"遊園安排"], ["園區圖解教學",func(): _open_tutorial("park","ticket"),"操作速查"],
	]
	for index in range(entries.size()):
		var entry: Array=entries[index]
		var button := Paper.button(str(entry[0]),entry[1],groups)
		button.name="TicketAction%d"%index
		button.tooltip_text=str(entry[2])
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var help := Paper.label("WASD 移動　E 互動　P 拍照　Esc 暫停",16,Paper.TEAL)
	help.name="TicketQuickHelp"
	body.add_child(help)
	_back(body)

func _open_time_panel_from_ticket() -> void:
	if modal_kind != "ticket":
		return
	_close()
	_show_time_panel()

func _interact_nearest() -> void:
	if not world.nearest.is_empty():
		world.interact()

func _show_controls() -> void:
	var body := _open("操作速查","PARK CONTROLS","controls")
	body.add_child(Paper.section_title("移動與互動"))
	body.add_child(Paper.label("移動：WASD／方向鍵　·　按住 Shift 慢走　·　互動：E　·　招呼：F　·　拍照：P",20))
	body.add_child(Paper.label("衣櫃：C　·　時段：T　·　旅券：M　·　暫停：Esc",20))
	_back(body)

func _append_photo_snapshot() -> void:
	if DisplayServer.get_name()=="headless" or session==null: return
	var snapshot := get_viewport().get_texture().get_image()
	if snapshot==null or snapshot.is_empty():
		push_warning("Could not capture gameplay photo for "+str(session.game_id))
		return
	_append_photo_image(snapshot)

func _append_photo_image(snapshot: Image) -> void:
	var original := _prepare_photo_original(snapshot)
	if original == null or original.is_empty():
		return
	var thumbnail := _prepare_photo_thumbnail(original)
	if photo_frames.size() >= Progress.MAX_GAME_PHOTO_FRAMES:
		photo_frames.pop_front()
	if photo_original_frames.size() >= Progress.MAX_GAME_PHOTO_FRAMES:
		photo_original_frames.pop_front()
	photo_frames.append(thumbnail)
	photo_original_frames.append(original)

func _prepare_photo_original(snapshot: Image) -> Image:
	if snapshot == null or snapshot.is_empty():
		return null
	var original := snapshot.duplicate()
	var pixels: int = original.get_width() * original.get_height()
	if pixels > 4 * 1024 * 1024:
		var scale := sqrt(float(4 * 1024 * 1024) / float(pixels))
		original.resize(maxi(1, floori(float(original.get_width()) * scale)), maxi(1, floori(float(original.get_height()) * scale)), Image.INTERPOLATE_LANCZOS)
	original.convert(Image.FORMAT_RGBA8)
	return original

func _prepare_photo_thumbnail(original: Image) -> Image:
	if original == null or original.is_empty():
		return null
	var thumbnail := original.duplicate()
	thumbnail.resize(320,180,Image.INTERPOLATE_LANCZOS)
	thumbnail.convert(Image.FORMAT_RGBA8)
	return thumbnail

func _fit_modal_viewport() -> void:
	if not is_instance_valid(overlay) or not overlay.visible: return
	var center := overlay.find_child("AdaptiveMenuCenter",true,false) as CenterContainer
	if center!=null:
		# Control grows when a category briefly has a larger minimum. Refresh its
		# parent-sized extent after text/content adaptation so it can shrink again.
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
