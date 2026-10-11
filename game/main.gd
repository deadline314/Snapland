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
var world: Node3D
var audio: Node
var story: RefCounted
var ui: Control
var hud: Control
var overlay: Control
var modal_body: VBoxContainer
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
var dialogue_done := Callable()
var reveal := 0.0
var definitions: Array=[]
var capture_mode := false
var photo_frames: Array[Image] = []
var next_snapshot := 0.0
var time_capture_token := 0
var quitting := false

func _ready() -> void:
	get_tree().auto_accept_quit=false
	capture_mode=OS.get_cmdline_user_args().has("--capture")
	world=WorldScene.new()
	add_child(world)
	audio=Audio.new()
	add_child(audio)
	story=Story.new()
	definitions=Session.definitions()
	_build_ui()
	world.interaction_requested.connect(_interact)
	world.area_changed.connect(func(name: String):
		area_label.text=name
		_update_breadcrumb(name)
		if session==null: audio.play_context("harbor" if name=="海風碼頭" else "plaza")
	)
	Progress.changed.connect(_refresh)
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
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		await _smoke_art_abort("--smoke-art requires isolated SNAPLAND_SAVE_PATH")
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
		var drawn_status: Dictionary=session.art_cache_status()
		if not bool(drawn_status.get("backdrop_atlas_loaded",false)) or not bool(drawn_status.get("props_atlas_loaded",false)) or not bool(drawn_status.get("props_regions_loaded",false)):
			await _smoke_art_abort("Art atlases did not load while drawing %s"%id)
			return
		if Session._backdrop_warning_emitted or Session._props_warning_emitted or not world.foliage_warnings.is_empty():
			await _smoke_art_abort("An art resource warning occurred while drawing %s"%id)
			return
		if game_index==12:
			# Resolve entries not reached by any game's draw path, then preserve the
			# final live session's cache snapshot/readiness before cancelling it.
			for key in Session.REQUIRED_PROP_KEYS:
				var prop_texture: Texture2D=session._prop_texture(key)
				if not prop_texture is Texture2D:
					await _smoke_art_abort("Missing prop Texture2D: %s"%key)
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
	banner.custom_minimum_size=Vector2(390,106)
	banner.size=Vector2(390,106)
	var banner_style := Paper.plaque(Color("#f7efd9"))
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
	area_label=Paper.label("海風碼頭",24)
	area_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	island_row.add_child(area_label)
	phase_label=Paper.label("",18,Paper.TEAL)
	phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	phase_label.custom_minimum_size.x=98
	island_row.add_child(phase_label)
	var keepsakes := HBoxContainer.new()
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
	ticket_button.anchor_left=1.0
	ticket_button.anchor_right=1.0
	ticket_button.offset_left=-222.0
	ticket_button.offset_right=-24.0
	ticket_button.offset_top=24.0
	ticket_button.offset_bottom=72.0
	ticket_button.custom_minimum_size=Vector2(198,48)
	quest_label=Paper.label("",18,Color("#fffaf0"))
	quest_label.position=Vector2(28,135)
	quest_label.size=Vector2(376,48)
	quest_label.add_theme_color_override("font_shadow_color",Color("#203e47"))
	quest_label.add_theme_constant_override("shadow_offset_x",1)
	quest_label.add_theme_constant_override("shadow_offset_y",1)
	hud.add_child(quest_label)
	context_bar=PanelContainer.new()
	context_bar.anchor_left=0.5
	context_bar.anchor_right=0.5
	context_bar.anchor_top=1.0
	context_bar.anchor_bottom=1.0
	context_bar.offset_left=-200
	context_bar.offset_right=200
	context_bar.offset_top=-62
	context_bar.offset_bottom=-18
	context_bar.custom_minimum_size=Vector2(400,44)
	var context_style := Paper.plaque(Color("#f7efd9"))
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
	overlay.show()
	modal_kind=kind
	world.blocked=true
	world.set_process(kind!="pause")
	audio.set_paused(kind=="pause" or (kind=="time" and session!=null))
	var dim := ColorRect.new()
	dim.color=Color(0.06,0.14,0.19,0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tall_kinds := ["settings","album","achievements","map","pause","wardrobe","time","ticket"]
	var preferred_height := 600.0 if tall_kinds.has(kind) else 350.0
	panel.name="AdaptiveMenuPanel"
	var menu_scale := Paper.physical_scale(overlay)
	var menu_width := minf(1040.0/menu_scale,viewport_size.x-32.0/menu_scale)
	panel.custom_minimum_size=Vector2(menu_width,minf(preferred_height/menu_scale,viewport_size.y-32.0/menu_scale))
	panel.add_theme_stylebox_override("panel",Paper.plaque(Color("#f7efd9")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,18)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	panel.add_child(margin)
	modal_body=VBoxContainer.new()
	modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation",10)
	margin.add_child(modal_body)
	var ticket_heading := HBoxContainer.new()
	ticket_heading.add_theme_constant_override("separation",10)
	modal_body.add_child(ticket_heading)
	ticket_heading.add_child(Paper.icon("ticket",28,Paper.TEAL))
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation",1)
	ticket_heading.add_child(heading_stack)
	heading_stack.add_child(Paper.label("島郵局   /   "+subtitle,16,Paper.TEAL))
	heading_stack.add_child(Paper.label(title,30))
	var content_scroll := ScrollContainer.new()
	content_scroll.name="AdaptiveMenuScroll"
	content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content_scroll.follow_focus=true
	modal_body.add_child(content_scroll)
	var content := VBoxContainer.new()
	content.name="AdaptiveMenuContent"
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	content_scroll.add_child(content)
	call_deferred("_adapt_open_menu")
	if not get_tree().root.size_changed.is_connected(_adapt_open_menu):
		get_tree().root.size_changed.connect(_adapt_open_menu)
	return content

func _scroll(parent: VBoxContainer, height := 330) -> VBoxContainer:
	# The generic modal already owns the bounded scrolling region.
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10)
	parent.add_child(box)
	return box

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
		if session.has_method("set_paused"):
			session.set_paused(false)
	if session==null: hud.show()
	if celebrate and session==null and world.has_method("play_action"):
		world.play_action("celebrate")

func _back(parent: Node) -> void:
	var button := Paper.button("返回遊園  ·  Esc",_close,modal_body)
	button.grab_focus()

func _refresh() -> void:
	if not is_instance_valid(ui): return
	Paper.set_reduced_motion(bool(Progress.settings.get("reduced_motion",false)))
	normal_count_label.text="普通 %d / 18"%Progress.normal_count()
	devil_count_label.text="小惡魔 %d / 12"%Progress.devil_count()
	coin_count_label.text="%d 幣"%Progress.coins
	var phase := TimeOfDay.phase_for_id(Progress.settings.get("time_phase",TimeOfDay.DEFAULT_PHASE))
	phase_label.text="%s %s"%[str(phase.get("label","中午")),str(phase.get("clock","12:00"))]
	quest_label.text=""
	for id in ["quest-001","quest-002"]:
		var step := int(Progress.quests.get(id,0))
		if step>0 and step<3:
			var quest: Dictionary=story.quest_data(id)
			quest_label.text="任務  ·  "+quest.get("title",id)+"  %d / 3  ·  M 查看旅券"%step
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
		next_snapshot=session.elapsed+15.0
		_sample_photo.call_deferred()
	if is_instance_valid(world) and modal_kind=="" and session==null:
		var has_context: bool = not world.nearest.is_empty()
		context_bar.visible=has_context
		context_action.visible=has_context
		if has_context:
			context_action.text="E   互動：%s"%str(world.nearest.get("label","附近設施"))
	if modal_kind=="dialogue" and is_instance_valid(dialogue_label):
		reveal+=delta*34.0*float(Progress.settings.get("text_speed",1.0))
		dialogue_label.visible_characters=int(reveal)

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
		if modal_kind=="dialogue": _finish_dialogue()
		elif modal_kind!="": _close()
		elif session==null: _show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if modal_kind=="dialogue":
			_next_dialogue()
		elif modal_kind=="" and session==null:
			world.interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_C:
		if modal_kind=="" and session==null:
			_show_wardrobe()
		elif modal_kind=="wardrobe":
			_close()
		get_viewport().set_input_as_handled()

func _apply_time_phase() -> void:
	var phase_id := TimeOfDay.normalize(Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE))
	if world.has_method("set_time_of_day"):
		world.set_time_of_day(phase_id)
	else:
		world.set_night(phase_id == "night")
	if session != null and session.has_method("set_time_of_day"):
		session.set_time_of_day(phase_id)

func _select_time_phase(phase_id: String) -> bool:
	if not Progress.set_time_phase(phase_id):
		return false
	_apply_time_phase()
	return true

func _collect_time_postcard(phase_id: String) -> String:
	if not _can_capture_time_postcard(phase_id, time_capture_token):
		return ""
	var token := time_capture_token
	var frame_path := await _capture_time_postcard_frame(phase_id, token)
	if frame_path.is_empty() or not _can_capture_time_postcard(phase_id, token):
		if not frame_path.is_empty() and FileAccess.file_exists(frame_path):
			DirAccess.remove_absolute(frame_path)
		return ""
	if not Progress.collect_time_postcard(phase_id, frame_path):
		DirAccess.remove_absolute(frame_path)
		return ""
	return frame_path

func _can_capture_time_postcard(phase_id: String, token: int) -> bool:
	return token == time_capture_token and modal_kind == "time" and session == null and is_instance_valid(world) and str(world.nearest.get("id", "")) == "guide" and str(Progress.settings.get("time_phase", "")) == phase_id and TimeOfDay.phase_ids().has(phase_id) and not Progress.photos.has(TimeOfDay.postcard_id(phase_id))

func _capture_time_postcard_frame(phase_id: String, token: int) -> String:
	if not _can_capture_time_postcard(phase_id, token):
		return ""
	var overlay_was_visible := overlay.visible
	var hud_was_visible := hud.visible
	overlay.hide()
	hud.hide()
	await get_tree().process_frame
	if not _can_capture_time_postcard(phase_id, token):
		_restore_time_capture_ui(token, overlay_was_visible, hud_was_visible)
		return ""
	await RenderingServer.frame_post_draw
	if not _can_capture_time_postcard(phase_id, token):
		_restore_time_capture_ui(token, overlay_was_visible, hud_was_visible)
		return ""
	var viewport := get_viewport()
	var snapshot := viewport.get_texture().get_image() if is_instance_valid(viewport) else null
	_restore_time_capture_ui(token, overlay_was_visible, hud_was_visible)
	if snapshot == null or snapshot.is_empty() or not _can_capture_time_postcard(phase_id, token):
		return ""
	snapshot.resize(320, 180, Image.INTERPOLATE_LANCZOS)
	snapshot.convert(Image.FORMAT_RGBA8)
	var directory := _photo_directory()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning("Cannot create time postcard directory: " + directory)
		return ""
	var path := directory + "/" + TimeOfDay.postcard_id(phase_id) + ".png"
	if snapshot.save_png(path) != OK:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		push_warning("Cannot save time postcard image: " + path)
		return ""
	return path

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
	time_panel.open(self, time_card, Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE), Progress.photos, at_photo_station, _select_time_phase, _collect_time_postcard)
	if session != null:
		session.process_mode = Node.PROCESS_MODE_DISABLED
		body.add_child(Paper.label("已暫停本局；關閉面板後會從同一局面繼續。", 18, Paper.TEAL))
	_back(body)

func _show_pause() -> void:
	var body := _open("留一點時間，給海風。","PAUSE","pause")
	var resume_card := Paper.card(body)
	resume_card.add_child(Paper.section_title("回到旅程"))
	resume_card.add_child(Paper.label("進度會自動保存。今天想玩哪一款，都可以慢慢選。",20))
	Paper.button("繼續遊園",_close,resume_card).grab_focus()
	var links := HBoxContainer.new()
	body.add_child(links)
	Paper.button("打開航海旅券",_show_ticket,links)
	Paper.button("儲存並離開",_quit_game,links)

func _show_arrival() -> void:
	var body := _open("今晚也要拍一張","WELCOME TO THE ISLAND","arrival")
	var arrival_card := Paper.card(body,Color("#fffaf0"),10)
	arrival_card.add_child(Paper.section_title("你的入園票已經備好。"))
	arrival_card.add_child(Paper.label("船靠岸了。海風吹亂你的頭髮，也吹來一張沒有人署名的入園券。",20))
	arrival_card.add_child(Paper.label("沿著木棧橋走進廣場，再到迎賓大道看看。收藏的是差一點錯過的笑容。",20))
	Paper.button("下船，去看看",func(): _start_dialogue(story.intro_lines(),func(): Progress.intro_seen=true; Progress.save_progress()),arrival_card).grab_focus()
	Paper.button("略過導覽，直接遊園",func(): Progress.intro_seen=true; Progress.save_progress(); _close(),body)

func _start_dialogue(lines: Array, done: Callable) -> void:
	dialogue=lines
	dialogue_index=0
	dialogue_done=done
	_render_dialogue()

func _render_dialogue() -> void:
	if dialogue_index>=dialogue.size():
		_finish_dialogue()
		return
	var line: Dictionary=dialogue[dialogue_index]
	var body := _open(str(line.get("speaker","旁白")),"ISLAND STORIES  ·  %d / %d"%[dialogue_index+1,dialogue.size()],"dialogue")
	var identity := PanelContainer.new()
	identity.custom_minimum_size=Vector2(240,112)
	identity.add_theme_stylebox_override("panel",Paper.box(Color("#e9dfc5"),8))
	body.add_child(identity)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation",10)
	identity.add_child(identity_row)
	identity_row.add_child(Paper.portrait(str(line.get("speaker","旁白"))))
	var identity_copy := VBoxContainer.new()
	identity_copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	identity_copy.add_theme_constant_override("separation",3)
	identity_row.add_child(identity_copy)
	identity_copy.add_child(Paper.label("本段說話者",14,Paper.TEAL))
	identity_copy.add_child(Paper.label(str(line.get("speaker","旁白")),22))
	dialogue_label=Paper.label(str(line.get("text","")),26)
	dialogue_label.custom_minimum_size=Vector2(830,142)
	dialogue_label.visible_characters=0
	body.add_child(dialogue_label)
	reveal=0
	Paper.button("繼續  ·  E / Space",_next_dialogue,body).grab_focus()
	Paper.button("略過這段對話",_finish_dialogue,body)

func _next_dialogue() -> void:
	if not is_instance_valid(dialogue_label): return
	if dialogue_label.visible_characters<dialogue_label.text.length():
		reveal=dialogue_label.text.length()
		dialogue_label.visible_characters=-1
	else:
		dialogue_index+=1
		_render_dialogue()

func _finish_dialogue() -> void:
	var callback := dialogue_done
	dialogue_done=Callable()
	overlay.hide()
	modal_kind=""
	world.blocked=false
	if callback.is_valid(): callback.call()

func _interact(id: String, title: String) -> void:
	audio.play_sfx("interact")
	if id.begins_with("game-"):
		_show_game_info(id)
	elif id=="arrival":
		_start_dialogue(story.intro_lines(),func(): Progress.intro_seen=true; Progress.save_progress())
	elif id=="guide":
		_start_dialogue(story.main_lines(),func(): Progress.grant_photo("photo-welcome-story-1"); _notice("第一張主線拍貼，收進本子裡了。"))
	elif id=="album": _show_album()
	elif id=="settings": _show_settings()
	elif id=="clock":
		world.set_night(not world.night)
		_notice("夜晚亮起來了。" if world.night else "陽光回到島上了。")
	elif id.begins_with("quest-"): _show_quest(id)
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

func _definition(id: String) -> Dictionary:
	for definition in definitions:
		if definition.get("id","")==id: return definition
	return {}

func _show_game_info(id: String) -> void:
	var definition := _definition(id)
	var body := _open(definition.get("name",id),"FREE PLAY  /  免費重試","game_info")
	var entry_stamp := HBoxContainer.new()
	entry_stamp.add_theme_constant_override("separation",8)
	body.add_child(entry_stamp)
	entry_stamp.add_child(Paper.icon("ticket",23,Paper.CORAL))
	entry_stamp.add_child(Paper.label("迎賓大道遊園票   ·   自由重玩",17,Paper.TEAL))
	body.add_child(Paper.label(definition.get("instructions","依畫面提示操作。"),24))
	var reward_note := HBoxContainer.new()
	reward_note.add_theme_constant_override("separation",7)
	body.add_child(reward_note)
	reward_note.add_child(Paper.icon("devil",24,Paper.CORAL))
	reward_note.add_child(Paper.label("小惡魔："+definition.get("devil_hint","完成特殊互動。"),19,Paper.TEAL))
	body.add_child(Paper.label("完成目標可收藏普通拍貼；輔助遊玩同樣可以收藏。",17))
	body.add_child(Paper.label("遊玩節奏：標準挑戰；輔助會放寬時間與判定，收藏相同。",15,Color("#65746f")))
	var row := HBoxContainer.new()
	body.add_child(row)
	Paper.button("開始遊玩",func(): _launch_game(id,bool(Progress.settings.get("assist",false))),row).grab_focus()
	Paper.button("開啟輔助遊玩",func(): _launch_game(id,true),row)
	_back(body)

func _launch_game(id: String, assist: bool) -> void:
	if _definition(id).is_empty():
		_notice("這個設施暫時無法開啟，請先逛逛其他地方。")
		return
	photo_frames.clear()
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
	session.note_played.connect(audio.play_note)
	session.feedback.connect(audio.play_sfx)
	if session.has_method("set_time_of_day"):
		session.set_time_of_day(TimeOfDay.normalize(Progress.settings.get("time_phase", TimeOfDay.DEFAULT_PHASE)))
	session.start(id,assist)
	audio.play_context("game")

func _cancel_game() -> void:
	if session!=null:
		ui.remove_child(session)
		session.queue_free()
		session=null
	audio.play_context("harbor" if world.current_area=="海風碼頭" else "plaza")
	hud.show()
	world.blocked=false
	world.show()
	world.set_process(true)

func _game_finished(result: Dictionary) -> void:
	var id := str(result.get("game_id",""))
	var saved_frames: Array[String] = []
	if bool(result.get("success",false)) and DisplayServer.get_name()!="headless":
		await _sample_photo()
		saved_frames=_save_photo_frames(id)
	if bool(result.get("success",false)):
		celebrate_on_close=true
		Progress.complete_game(id,bool(result.get("devil",false)),bool(result.get("assisted",false)))
		var source := "photo-welcome-game-%d"%int(id.trim_prefix("game-"))
		if not saved_frames.is_empty() and Progress.photos.has(source):
			Progress.photos[source]["frames"]=saved_frames
			Progress.save_progress()
	_cancel_game()
	audio.play_sfx("success" if result.get("success",false) else "miss")
	var definition := _definition(id)
	var body := _open("今天的這一格，值得留下。" if result.get("success",false) else "差一點！再玩一次就好。","PHOTO BOOTH / "+definition.get("name",id),"result")
	var result_summary := HBoxContainer.new()
	result_summary.add_theme_constant_override("separation",8)
	body.add_child(result_summary)
	result_summary.add_child(Paper.icon("album",23,Paper.TEAL))
	result_summary.add_child(Paper.label("本次成績 %d   ·   %s"%[result.get("score",0),"輔助遊玩" if result.get("assisted",false) else "標準遊玩"],20))
	if result.get("success",false):
		var award := HBoxContainer.new()
		award.add_theme_constant_override("separation",8)
		body.add_child(award)
		award.add_child(Paper.icon("album",24,Paper.TEAL))
		award.add_child(Paper.label("普通拍貼已收藏",20,Paper.TEAL))
		if result.get("devil",false):
			award.add_child(Paper.icon("devil",24,Paper.CORAL))
			award.add_child(Paper.label("小惡魔也入鏡了",20,Paper.CORAL))
	else:
		body.add_child(Paper.label("沒有扣除任何收藏。也可以開啟輔助，試試別的節奏。",22))
	var frames := HBoxContainer.new()
	frames.add_theme_constant_override("separation",18)
	body.add_child(frames)
	for i in range(4):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",Paper.plaque(Color("#fff9e9")))
		card.custom_minimum_size=Vector2(200,145)
		var content := VBoxContainer.new()
		card.add_child(content)
		if not saved_frames.is_empty():
			var thumbnail := TextureRect.new()
			thumbnail.texture=_photo_texture(saved_frames[mini(i,saved_frames.size()-1)])
			thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.custom_minimum_size=Vector2(164,84)
			content.add_child(thumbnail)
		else:
			content.add_child(Paper.label("◇ 第 %d 格"%(i+1),25,Paper.TEAL))
		content.add_child(Paper.deckle_band())
		var stamp_row := HBoxContainer.new()
		stamp_row.add_theme_constant_override("separation",4)
		content.add_child(stamp_row)
		stamp_row.add_child(Paper.postmark())
		stamp_row.add_child(Paper.label("郵戳 %02d  ·  %s"%[i+1,definition.get("name",id)],15,Paper.TEAL))
		frames.add_child(card)
	var row := HBoxContainer.new()
	body.add_child(row)
	Paper.button("再玩一次",func(): _launch_game(id,bool(result.get("assisted",false))),row).grab_focus()
	Paper.button("輔助重試",func(): _launch_game(id,true),row)
	_back(body)

func _show_album() -> void:
	var body := _open("一張照片，一點小事。","PHOTO COLLECTION","album")
	var book_script = load("res://game/ui/collection_book_panel.gd")
	var book = book_script.new()
	book.setup(Progress,definitions,TimeOfDay.PHASES,Callable(self,"_photo_texture"))
	var scroll := _scroll(body,430)
	scroll.add_child(book)
	_back(body)

func _show_tasks() -> void:
	var body := _open("今天，幫誰一個小忙？","ISLAND QUESTS","tasks")
	for id in ["quest-001","quest-002"]:
		var quest: Dictionary=story.quest_data(id)
		var step := int(Progress.quests.get(id,0))
		Paper.button(quest.get("title",id)+"   %d / 3"%step,func(): _show_quest(id),body)
	body.add_child(Paper.label("小角和阿浪在迎賓大道的左右步道等你。步驟隨時保存，離開後能繼續。",20))
	_back(body)

func _show_quest(id: String) -> void:
	var quest: Dictionary=story.quest_data(id)
	var step := int(Progress.quests.get(id,0))
	var body := _open(quest.get("title",id),"STEP %d / 3"%mini(step+1,3),"quest")
	if step>=3:
		body.add_child(Paper.label("今天的小麻煩，已經變成了拍貼裡的笑話。",24))
		_back(body)
		return
	var steps: Array=quest.get("steps",[])
	var data: Dictionary=steps[step]
	body.add_child(Paper.label(data.get("prompt",""),24))
	var stage := PhotoStage.new()
	stage.kind="tail" if id=="quest-001" else "broadcast"
	stage.reduced_motion=bool(Progress.settings.get("reduced_motion",false))
	body.add_child(stage)
	if step==1 and id=="quest-001":
		stage.offset=-90.0
		body.add_child(Paper.label("拖動背景板，把尾巴接到彩帶缺口。",18,Paper.TEAL))
		var slider := HSlider.new()
		slider.min_value=-120
		slider.max_value=120
		slider.value=-90
		slider.step=1
		slider.value_changed.connect(func(value: float): stage.offset=value)
		body.add_child(slider)
		Paper.button("固定背景板",func():
			if absf(stage.offset)<18: _advance_quest(id,step,quest)
			else: _notice("尾巴還沒接上彩帶，往中間移一點。")
		,body)
		_back(body)
		return
	if step==1 and id=="quest-002":
		body.add_child(Paper.label("轉動箭頭，讓它朝大道裡面（↑）。",18,Paper.TEAL))
		stage.offset=2
		var arrows := HBoxContainer.new()
		body.add_child(arrows)
		for i in range(4):
			var direction := i
			Paper.button(["↑ 大道","→ 廣場","↓ 碼頭","← 海邊"][i],func(): stage.offset=direction,arrows)
		Paper.button("試播方向",func():
			if stage.offset==0: _advance_quest(id,step,quest)
			else: _notice("箭頭還沒有朝大道裡面。")
		,body)
		_back(body)
		return
	var options: Array=data.get("options",[])
	for i in range(options.size()):
		var chosen := i
		Paper.button(str(options[i]),func():
			if chosen==int(data.get("correct",0)):
				_advance_quest(id,step,quest)
			else:
				_notice(data.get("feedback","再觀察一下旁邊的提示。"))
				audio.play_sfx("miss")
		,body)
	_back(body)

func _advance_quest(id: String, step: int, quest: Dictionary) -> void:
	Progress.advance_quest(id,step+1)
	if step+1==3:
		Progress.grant_photo(quest.get("photo_id","photo-welcome-quest-%d"%(1 if id=="quest-001" else 2)))
		audio.play_sfx("success")
	_show_quest(id)

func _show_exploration(id: String) -> void:
	var index := int(id.trim_prefix("explore-"))
	var titles := ["花壇會眨眼","歡迎字樣的影子","長椅雙人份"]
	var prompts := ["花朵的眼睛跟著你轉。站在笑臉腳印上，要做什麼表情？","展示燈的影子還沒進框。試著把燈轉向歡迎牆。","長椅空著一個座位。免費借用架上有小角的立牌。"]
	var choices := [["微笑，等花朵一起眨眼","扮鬼臉，逗花朵笑"],["向左轉  ·  對準空框","向右轉  ·  看看影子"],["借一個小角立牌，拍合照","讓立牌戴帽子，再拍一張"]]
	var body := _open(titles[index-1],"DISCOVERY / 自由探索","explore")
	body.add_child(Paper.label(prompts[index-1],24))
	var stage := PhotoStage.new()
	stage.kind=["flower","shadow","bench"][index-1]
	stage.reduced_motion=bool(Progress.settings.get("reduced_motion",false))
	body.add_child(stage)
	if index==2:
		stage.offset=-90
		var slider := HSlider.new()
		slider.min_value=-120
		slider.max_value=120
		slider.value=-90
		slider.step=1
		slider.value_changed.connect(func(value: float): stage.offset=value)
		body.add_child(slider)
	else:
		for i in range(choices[index-1].size()):
			var choice_index := i
			Paper.button(choices[index-1][i],func():
				if index==1: stage.flower_face=choice_index+1
				else: stage.borrowed=true; stage.pose=choice_index
			,body)
	Paper.button("按下快門，留下合照",func():
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
		Progress.grant_photo("photo-welcome-explore-%d"%index,{"pose":stage.pose})
		audio.play_sfx("success")
		_close()
		_notice("探索拍貼已收藏："+titles[index-1])
	,body)
	_back(body)

func _show_achievements() -> void:
	var body := _open("那些「我做到了」的小瞬間。","ACHIEVEMENTS","achievements")
	var stamp_script = load("res://game/ui/achievement_stamp_book.gd")
	var stamp_book = stamp_script.new()
	stamp_book.setup(Progress,definitions)
	var scroll := _scroll(body,390)
	scroll.add_child(stamp_book)
	_back(body)

func _show_map() -> void:
	var body := _open("今天想去哪一邊？","ISLAND MAP","map")
	var map_script = load("res://game/ui/island_map_panel.gd")
	var map_panel = map_script.new()
	var park_data: Dictionary=world.park_data()
	map_panel.setup(park_data.get("zones",[]),definitions,Progress.normal_count(),world.points)
	var scroll := _scroll(body,430)
	scroll.add_child(map_panel)
	_back(body)

func _show_settings() -> void:
	var body := _open("把這趟遊園，調成你的步調。","SETTINGS","settings")
	var list := _scroll(body,300)
	var sound_card := Paper.card(list,Color("#fffaf0"),6)
	sound_card.add_child(Paper.section_title("聲音與閱讀"))
	for entry in [["master_volume","總音量"],["music_volume","背景音樂"],["sfx_volume","互動音效"],["text_speed","對話文字速度"]]:
		var row := HBoxContainer.new()
		sound_card.add_child(row)
		var label := Paper.label(entry[1],20)
		label.custom_minimum_size.x=220
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size=Vector2(360,44)
		slider.min_value=0.5 if entry[0]=="text_speed" else 0.0
		slider.max_value=2.0 if entry[0]=="text_speed" else 1.0
		slider.step=0.05
		slider.value=float(Progress.settings.get(entry[0],1.0))
		var key: String=entry[0]
		slider.value_changed.connect(func(value: float): Progress.set_setting(key,value))
		row.add_child(slider)
	var access_card := Paper.card(list,Color("#f1e8d3"),5)
	access_card.add_child(Paper.section_title("遊玩方式與顯示"))
	for entry in [["assist","輔助遊玩：放寬時間與判定，仍可收藏"],["reduced_motion","降低動態：停止水波與裝飾擺動"],["fullscreen","使用全螢幕"]]:
		var toggle := CheckButton.new()
		toggle.text=entry[1]
		toggle.custom_minimum_size.y=44
		toggle.button_pressed=bool(Progress.settings.get(entry[0],false))
		var key: String=entry[0]
		toggle.toggled.connect(func(value: bool): Progress.set_setting(key,value))
		access_card.add_child(toggle)
	access_card.add_child(Paper.label("快捷鍵可在航海旅券「操作速查」重看。",18,Paper.DEEP_TEAL))
	_back(body)

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
	await RenderingServer.frame_post_draw
	if session==null: return
	var snapshot := get_viewport().get_texture().get_image()
	snapshot.resize(320,180,Image.INTERPOLATE_LANCZOS)
	if photo_frames.size()>=4: photo_frames.pop_front()
	photo_frames.append(snapshot)

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
	banner.custom_minimum_size=Vector2(390,106)/scale_factor
	banner.size=banner.custom_minimum_size
	ticket_button.offset_left=-222.0/scale_factor
	ticket_button.offset_right=-24.0/scale_factor
	ticket_button.offset_top=24.0/scale_factor
	ticket_button.offset_bottom=72.0/scale_factor
	ticket_button.custom_minimum_size=Vector2(198,48)/scale_factor
	quest_label.position=Vector2(28,135)/scale_factor
	quest_label.size=Vector2(376,48)/scale_factor
	context_bar.offset_left=-200.0/scale_factor
	context_bar.offset_right=200.0/scale_factor
	context_bar.offset_top=-70.0/scale_factor
	context_bar.offset_bottom=-18.0/scale_factor
	context_bar.custom_minimum_size=Vector2(400,52)/scale_factor
	toast.offset_left=-310.0/scale_factor
	toast.offset_right=310.0/scale_factor
	toast.offset_top=190.0/scale_factor
	toast.offset_bottom=280.0/scale_factor

func _adapt_open_menu() -> void:
	if not is_instance_valid(overlay) or not overlay.visible: return
	var scale_factor := Paper.physical_scale(overlay)
	var panel := overlay.find_child("AdaptiveMenuPanel",true,false) as Control
	if panel!=null:
		var viewport_size := get_viewport().get_visible_rect().size
		panel.custom_minimum_size.x=minf(1040.0/scale_factor,viewport_size.x-32.0/scale_factor)
		if scale_factor<0.9: panel.custom_minimum_size.y=viewport_size.y-32.0/scale_factor
	Paper.adapt_menu(overlay,scale_factor)
	var chart := overlay.find_child("IslandChartCanvas",true,false)
	if chart!=null and chart.get_parent().get_parent().has_method("_layout_map_buttons"):
		chart.get_parent().get_parent().call_deferred("_layout_map_buttons")

func _show_ticket() -> void:
	var body := _open("島上的事，都收在這本旅券裡。","VOYAGE PASS","ticket")
	var list := _scroll(body,430)
	var groups := GridContainer.new()
	groups.columns=2
	groups.add_theme_constant_override("h_separation",10)
	groups.add_theme_constant_override("v_separation",10)
	list.add_child(groups)
	var column_width := clampf((get_viewport().get_visible_rect().size.x-112.0)/2.0,280.0,440.0)
	var sections := [
		{"title":"探索島嶼","subtitle":"地圖與正在進行的委託","items":[["島嶼地圖",_show_map],["今日任務",_show_tasks]]},
		{"title":"收藏記錄","subtitle":"拍貼與完成紀念","items":[["拍貼收藏本",_show_album],["遊園成就",_show_achievements]]},
		{"title":"整裝出發","subtitle":"外觀、衣櫃與服飾店","items":[["衣櫃與服飾店",_show_wardrobe]]},
		{"title":"遊園安排","subtitle":"光線、聲音與輔助設定","items":[["切換時段",_open_time_panel_from_ticket],["設定與輔助",_show_settings]]},
	]
	for section: Dictionary in sections:
		var card := Paper.card(groups,Color("#fffaf0"),8)
		card.custom_minimum_size=Vector2(column_width,0)
		card.add_child(Paper.section_title(str(section.title)))
		var caption := Paper.label(str(section.subtitle),16,Paper.DEEP_TEAL)
		card.add_child(caption)
		for entry: Array in section.items:
			Paper.button(str(entry[0]),entry[1],card)
	var help_card := Paper.card(list,Color("#f1e8d3"),6)
	help_card.add_child(Paper.section_title("操作速查",Paper.DEEP_TEAL))
	help_card.add_child(Paper.label("移動 WASD／方向鍵　·　互動 E　·　招呼 F　·　拍照 P　·　衣櫃 C　·　時段 T　·　暫停 Esc",18))
	Paper.button("操作速查",_show_controls,help_card)
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
	body.add_child(Paper.label("移動：WASD／方向鍵　·　互動：E　·　招呼：F　·　拍照：P",20))
	body.add_child(Paper.label("衣櫃：C　·　時段：T　·　旅券：M　·　暫停：Esc",20))
	_back(body)

