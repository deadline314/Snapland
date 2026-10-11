extends Node
const WorldScene = preload("res://game/world/park_world.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Story = preload("res://game/story/story_director.gd")
const Audio = preload("res://game/audio/audio_director.gd")
const Session = preload("res://game/minigames/session.gd")
const PhotoStage = preload("res://game/ui/photo_stage.gd")
var world: Node3D
var audio: Node
var story: RefCounted
var ui: Control
var hud: Control
var overlay: Control
var modal_body: VBoxContainer
var area_label: Label
var count_label: Label
var hint: Label
var toast: Label
var quest_label: Label
var session: Control
var modal_kind := ""
var dialogue: Array=[]
var dialogue_index := 0
var dialogue_label: Label
var dialogue_done := Callable()
var reveal := 0.0
var definitions: Array=[]
var capture_mode := false
var photo_frames: Array[Image] = []
var next_snapshot := 0.0
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
	if OS.get_cmdline_user_args().has("--smoke-test"):
		_smoke_test.call_deferred()

func _smoke_test() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Smoke test requires isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.5).timeout
	print("PASS: game startup and clean shutdown")
	await _quit_game()

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
	banner.position=Vector2(24,20)
	banner.custom_minimum_size=Vector2(295,92)
	hud.add_child(banner)
	var banner_box := VBoxContainer.new()
	banner.add_child(banner_box)
	banner_box.add_child(Paper.label("SNAPLAND  /  今晚也要拍一張",16,Paper.TEAL))
	area_label=Paper.label("海風碼頭",28)
	banner_box.add_child(area_label)
	count_label=Paper.label("",16)
	banner_box.add_child(count_label)
	var tools := HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tools.position=Vector2(-665,25)
	tools.add_theme_constant_override("separation",8)
	hud.add_child(tools)
	for entry in [["拍貼本",_show_album],["任務",_show_tasks],["成就",_show_achievements],["地圖",_show_map],["設定",_show_settings]]:
		Paper.button(entry[0],entry[1],tools)
	quest_label=Paper.label("",17,Color("#fff3cf"))
	quest_label.position=Vector2(28,155)
	quest_label.size=Vector2(360,140)
	quest_label.add_theme_color_override("font_shadow_color",Color("#274750"))
	quest_label.add_theme_constant_override("shadow_offset_x",1)
	quest_label.add_theme_constant_override("shadow_offset_y",2)
	hud.add_child(quest_label)
	var lower := PanelContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.offset_left=24
	lower.offset_right=-24
	lower.offset_top=-73
	lower.offset_bottom=-20
	hud.add_child(lower)
	var row := HBoxContainer.new()
	lower.add_child(row)
	hint=Paper.label("WASD / 方向鍵 移動   ·   E 互動   ·   Esc 暫停",18)
	hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	var motto := Paper.label("不趕路，也是一種玩法。",17,Paper.TEAL)
	motto.autowrap_mode=TextServer.AUTOWRAP_OFF
	row.add_child(motto)
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

func _open(title: String, subtitle: String, kind: String) -> VBoxContainer:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.show()
	modal_kind=kind
	world.blocked=true
	world.set_process(kind!="pause")
	audio.set_paused(kind=="pause")
	var dim := ColorRect.new()
	dim.color=Color(0.06,0.14,0.19,0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size=Vector2(1020,550)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	panel.add_child(margin)
	modal_body=VBoxContainer.new()
	modal_body.add_theme_constant_override("separation",14)
	margin.add_child(modal_body)
	modal_body.add_child(Paper.label("SNAPLAND   /   "+subtitle,15,Paper.TEAL))
	modal_body.add_child(Paper.label(title,32))
	return modal_body

func _scroll(parent: VBoxContainer, height := 330) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(945,height)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10)
	scroll.add_child(box)
	return box

func _close() -> void:
	if modal_kind=="dialogue":
		_finish_dialogue()
		return
	overlay.hide()
	modal_kind=""
	world.blocked=session!=null
	world.set_process(true)
	audio.set_paused(false)
	if session==null: hud.show()

func _back(parent: Node) -> void:
	var button := Paper.button("返回遊園  ·  Esc",_close,parent)
	button.grab_focus()

func _refresh() -> void:
	if not is_instance_valid(ui): return
	count_label.text="普通拍貼 %d / 18   ·   小惡魔 %d / 12"%[Progress.normal_count(),Progress.devil_count()]
	quest_label.text=""
	for id in ["quest-001","quest-002"]:
		var step := int(Progress.quests.get(id,0))
		if step>0 and step<3:
			var quest: Dictionary=story.quest_data(id)
			quest_label.text+="◇ "+quest.get("title",id)+"  %d / 3\n"%step
	audio.apply_settings(Progress.settings)
	world.apply_settings(Progress.settings)
	world.update_collection(Progress.photos)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if Progress.settings.get("fullscreen",false) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name()!="headless" and not capture_mode:
		DisplayServer.window_set_mode(mode)

func _process(delta: float) -> void:
	if session!=null and DisplayServer.get_name()!="headless" and session.elapsed>=next_snapshot and not session.ended:
		next_snapshot=session.elapsed+15.0
		_sample_photo.call_deferred()
	if is_instance_valid(world) and modal_kind=="" and session==null:
		hint.text="E  "+world.nearest.get("label","")+"   ·   WASD 移動   ·   Esc 暫停" if not world.nearest.is_empty() else "WASD / 方向鍵 移動   ·   E 互動   ·   Esc 暫停"
	if modal_kind=="dialogue" and is_instance_valid(dialogue_label):
		reveal+=delta*34.0*float(Progress.settings.get("text_speed",1.0))
		dialogue_label.visible_characters=int(reveal)

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

func _show_pause() -> void:
	var body := _open("留一點時間，給海風。","PAUSE","pause")
	body.add_child(Paper.label("進度會自動保存。今天想玩哪一款，都可以慢慢選。",22))
	Paper.button("繼續遊園",_close,body).grab_focus()
	Paper.button("拍貼收藏",_show_album,body)
	Paper.button("設定與輔助",_show_settings,body)
	Paper.button("儲存並離開",_quit_game,body)

func _show_arrival() -> void:
	var body := _open("今晚也要拍一張","WELCOME TO THE ISLAND","arrival")
	body.add_child(Paper.label("船靠岸了。海風吹亂你的頭髮，也吹來一張沒有人署名的入園券。",24))
	body.add_child(Paper.label("這座遊樂園收藏的不是完美紀錄，是那些差一點就錯過的笑容。\n\n沿著木棧橋走進廣場，再去迎賓大道看看。",22))
	Paper.button("下船，去看看",func(): _start_dialogue(story.intro_lines(),func(): Progress.intro_seen=true; Progress.save_progress()),body).grab_focus()
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
	dialogue_label=Paper.label(str(line.get("text","")),26)
	dialogue_label.custom_minimum_size=Vector2(930,190)
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
	body.add_child(Paper.label(definition.get("instructions","依畫面提示操作。"),24))
	body.add_child(Paper.label("小惡魔："+definition.get("devil_hint","完成特殊互動。"),20,Paper.TEAL))
	body.add_child(Paper.label("普通拍貼在完成目標後取得；輔助模式同樣可以收藏。",18))
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
		Progress.complete_game(id,bool(result.get("devil",false)),bool(result.get("assisted",false)))
		var source := "photo-welcome-game-%d"%int(id.trim_prefix("game-"))
		if not saved_frames.is_empty() and Progress.photos.has(source):
			Progress.photos[source]["frames"]=saved_frames
			Progress.save_progress()
	_cancel_game()
	audio.play_sfx("success" if result.get("success",false) else "miss")
	var definition := _definition(id)
	var body := _open("今天的這一格，值得留下。" if result.get("success",false) else "差一點！再玩一次就好。","PHOTO BOOTH / "+definition.get("name",id),"result")
	body.add_child(Paper.label("成績 %d   ·   %s"%[result.get("score",0),"輔助遊玩" if result.get("assisted",false) else "標準遊玩"],24))
	if result.get("success",false):
		body.add_child(Paper.label("普通拍貼已收藏"+("  ＋  小惡魔也入鏡了！" if result.get("devil",false) else ""),22,Paper.TEAL))
	else:
		body.add_child(Paper.label("沒有扣除任何收藏。也可以開啟輔助，試試別的節奏。",22))
	var frames := HBoxContainer.new()
	frames.add_theme_constant_override("separation",18)
	body.add_child(frames)
	for i in range(4):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",Paper.box(Color("#e8dab7"),4))
		card.custom_minimum_size=Vector2(215,110)
		var content := VBoxContainer.new()
		card.add_child(content)
		if not saved_frames.is_empty():
			var thumbnail := TextureRect.new()
			thumbnail.texture=_photo_texture(saved_frames[mini(i,saved_frames.size()-1)])
			thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.custom_minimum_size=Vector2(190,105)
			content.add_child(thumbnail)
		else:
			content.add_child(Paper.label("◇ 第 %d 格"%(i+1),25,Paper.TEAL))
		content.add_child(Paper.label(definition.get("name",id),18))
		frames.add_child(card)
	var row := HBoxContainer.new()
	body.add_child(row)
	Paper.button("再玩一次",func(): _launch_game(id,bool(result.get("assisted",false))),row).grab_focus()
	Paper.button("輔助重試",func(): _launch_game(id,true),row)
	_back(body)

func _show_album() -> void:
	var body := _open("一張照片，一點小事。","PHOTO COLLECTION","album")
	var grid := GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",8)
	_scroll(body).add_child(grid)
	var sources: Array=[]
	for i in range(12):
		sources.append({"id":"photo-welcome-game-%d"%(i+1),"label":_definition("game-%03d"%(i+1)).get("name","設施 %d"%(i+1))})
	for entry in [["explore-1","花壇會眨眼"],["explore-2","歡迎字樣的影子"],["explore-3","長椅雙人份"],["story-1","照片多了一條尾巴"],["quest-1","吉祥物的尾巴危機"],["quest-2","廣播即興救場"]]:
		sources.append({"id":"photo-welcome-"+entry[0],"label":entry[1]})
	for item in sources:
		var earned := Progress.photos.has(item.id)
		var card := PanelContainer.new()
		card.custom_minimum_size=Vector2(300,76)
		card.add_theme_stylebox_override("panel",Paper.box(Color("#dfebd8") if earned else Color("#e9e0ca"),8))
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(Paper.label(("✓  " if earned else "◇  ")+item.label,19))
		box.add_child(Paper.label("已留下回憶" if earned else "去附近的設施或互動點看看",15,Paper.TEAL))
		if earned:
			var frames: Variant=Progress.photos[item.id].get("frames",[])
			if frames is Array and not frames.is_empty() and frames[0] is String and FileAccess.file_exists(frames[0]):
				var thumbnail := TextureRect.new()
				var photo := _photo_texture(frames[0])
				if photo!=null:
					thumbnail.texture=photo
					thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
					thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					thumbnail.custom_minimum_size=Vector2(250,130)
					box.add_child(thumbnail)
		grid.add_child(card)
	body.add_child(Paper.label("普通 %d / 18  ·  小惡魔 %d / 12  ·  重拍不重複計數"%[Progress.normal_count(),Progress.devil_count()],18))
	_back(body)

func _show_tasks() -> void:
	var body := _open("今天，幫誰一個小忙？","ISLAND QUESTS","tasks")
	for id in ["quest-001","quest-002"]:
		var quest: Dictionary=story.quest_data(id)
		var step := int(Progress.quests.get(id,0))
		Paper.button(quest.get("title",id)+"   %d / 3"%step,func(): _show_quest(id),body)
	body.add_child(Paper.label("小角和阿浪在迎賓大道入口等你。步驟隨時保存，離開後能繼續。",20))
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
		Progress.grant_photo("photo-welcome-explore-%d"%index,{"pose":stage.pose})
		audio.play_sfx("success")
		_close()
		_notice("探索拍貼已收藏："+titles[index-1])
	,body)
	_back(body)

func _show_achievements() -> void:
	var body := _open("那些「我做到了」的小瞬間。","ACHIEVEMENTS","achievements")
	var list := _scroll(body)
	for i in range(12):
		var id := "ACH_GAME_%03d"%(i+1)
		list.add_child(Paper.label(("✓ " if Progress.achievements.has(id) else "◇ ")+"第一次："+_definition("game-%03d"%(i+1)).get("name",id),20))
	for entry in [["ACH_WELCOME_CLEAR","迎賓全通關","完成迎賓十二款"],["ACH_WELCOME_DEVILS","尾巴藏不住","迎賓十二張小惡魔"],["ACH_ALL_DEVILS","每個小惡魔都入鏡","十區120張小惡魔"]]:
		list.add_child(Paper.label(("✓ " if Progress.achievements.has(entry[0]) else "◇ ")+entry[1]+"  ·  "+entry[2],20))
	body.add_child(Paper.label("成就保存在遊戲內。Steam 接點預留，未連線時保留待同步紀錄。",16,Paper.TEAL))
	_back(body)

func _show_map() -> void:
	var body := _open("今天想去哪一邊？","ISLAND MAP","map")
	var list := _scroll(body)
	list.add_child(Paper.label("↓ 海風碼頭   →   中央廣場   →   ↑ 迎賓大道（12 款可玩）",24,Paper.TEAL))
	var data: Dictionary=world.park_data()
	for zone in data.zones:
		if zone.id!="welcome":
			list.add_child(Paper.label("◇ "+zone.name+"  ·  %d 張普通拍貼  ·  路口已開放，園區準備中"%zone.threshold,19))
	_back(body)

func _show_settings() -> void:
	var body := _open("把這趟遊園，調成你的步調。","SETTINGS","settings")
	var list := _scroll(body,300)
	for entry in [["master_volume","總音量"],["music_volume","音樂"],["sfx_volume","音效"],["text_speed","文字速度"]]:
		var row := HBoxContainer.new()
		list.add_child(row)
		var label := Paper.label(entry[1],20)
		label.custom_minimum_size.x=200
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size=Vector2(550,36)
		slider.min_value=0.5 if entry[0]=="text_speed" else 0.0
		slider.max_value=2.0 if entry[0]=="text_speed" else 1.0
		slider.step=0.05
		slider.value=float(Progress.settings.get(entry[0],1.0))
		var key: String=entry[0]
		slider.value_changed.connect(func(value: float): Progress.set_setting(key,value))
		row.add_child(slider)
	for entry in [["assist","預設輔助  ·  時間與判定更寬鬆，仍可收藏"],["reduced_motion","降低背景動態  ·  停止水波與裝飾擺動"],["fullscreen","全螢幕"]]:
		var toggle := CheckButton.new()
		toggle.text=entry[1]
		toggle.button_pressed=bool(Progress.settings.get(entry[0],false))
		var key: String=entry[0]
		toggle.toggled.connect(func(value: bool): Progress.set_setting(key,value))
		list.add_child(toggle)
	body.add_child(Paper.label("移動：WASD / 方向鍵  ·  互動：E / Space  ·  返回：Esc",18))
	_back(body)

func _notice(message: String) -> void:
	toast.text=message
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func(): if is_instance_valid(toast) and toast.text==message: toast.text="")

func _achievement_toast(id: String) -> void:
	var label := ""
	if id.begins_with("ACH_GAME_"):
		label=str(_definition("game-%03d"%int(id.trim_prefix("ACH_GAME_"))).get("name","小遊戲"))+"的第一張照片"
	else:
		label={"ACH_WELCOME_CLEAR":"迎賓大道通關","ACH_WELCOME_DEVILS":"迎賓小惡魔全收藏","ACH_ALL_DEVILS":"全島小惡魔全收藏"}.get(id,"新的旅途紀念")
	_notice("成就解鎖  ✦  "+label)

func _capture_sequence() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Capture requires isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-main/images/MAIN-4-plaza.png")
	_capture("pm/Snapland-art/images/ART-1-plaza-day.png")
	world.set_night(true)
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-art/images/ART-1-plaza-night.png")
	world.set_night(false)
	world.player.position=Vector3(0,0.4,-22)
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-main/images/MAIN-4-welcome.png")
	_show_album()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-main/images/MAIN-7-album.png")
	_capture("pm/Snapland-art/images/ART-2-album-ui.png")
	_show_settings()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-main/images/MAIN-6-settings.png")
	_show_achievements()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-main/images/MAIN-5-achievements.png")
	_start_dialogue(story.intro_lines(),Callable())
	reveal=1000
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-story/images/ST-2-arrival.png")
	_show_quest("quest-001")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-story/images/ST-3-quest.png")
	for i in range(12):
		_close()
		_launch_game("game-%03d"%(i+1),false)
		await get_tree().create_timer(0.75).timeout
		await RenderingServer.frame_post_draw
		_capture("pm/Snapland-small-game/images/SG-%d-game.png"%(i+2))
		_cancel_game()
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
		push_error("Native photo result verification failed")
		get_tree().quit(1)
		return
	_capture("pm/Snapland-main/images/MAIN-7-result.png")
	_show_album()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_capture("pm/Snapland-main/images/MAIN-7-album-earned.png")
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
	# Preview sessions never write into the player's real profile.
	var override := OS.get_environment("SNAPLAND_SAVE_PATH")
	var directory := (override.get_base_dir()+"/photos") if not override.is_empty() else ProjectSettings.globalize_path("user://photos")
	var err := DirAccess.make_dir_recursive_absolute(directory)
	if err!=OK:
		push_warning("Cannot create photo directory: "+directory)
		return paths
	for i in range(photo_frames.size()):
		var path := directory+"/"+id+"-%d.png"%i
		if photo_frames[i].save_png(path)==OK: paths.append(path)
		else: push_warning("Cannot save photo frame: "+path)
	return paths

func _capture(relative: String) -> void:
	var path := ProjectSettings.globalize_path("res://"+relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error!=OK: push_error("Screenshot save failed: "+path+" "+str(error))
