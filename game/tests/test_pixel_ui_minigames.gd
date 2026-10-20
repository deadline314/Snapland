extends Node

const HudScript = preload("res://game/ui/minigame_hud.gd")
const InviteScript = preload("res://game/ui/island_game_invite.gd")
const PhotoStageScript = preload("res://game/ui/photo_stage.gd")
const DialogueScript = preload("res://game/ui/dialogue_panel.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const MainScript = preload("res://game/main.gd")

var failures: Array[String]=[]

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running minigame UI checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	get_viewport().size=Vector2i(1280,720)
	host.size=Vector2(1280,720)
	add_child(host)
	var hud := HudScript.new()
	host.add_child(hud)
	var events: Array[String]=[]
	hud.pause_requested.connect(func(): events.append("pause"))
	hud.resume_requested.connect(func(): events.append("resume"))
	hud.help_requested.connect(func(): events.append("help"))
	hud.details_requested.connect(func(): events.append("details"))
	hud.practice_requested.connect(func(): events.append("practice"))
	hud.retry_requested.connect(func(): events.append("retry"))
	hud.leave_requested.connect(func(): events.append("leave"))
	await _frames(3)
	hud.set_state({"title":"沿著海港木棧道追接旅人的六頂帽子","objective":"依照風向和帽子落點移動，並在帽簷經過手線時接住；連續中心接取可獲得更高成果。","progress_text":"已接住 3/6　漏接 0","score":816,"time_text":"00:42","assisted":true})
	_check((hud.get("_title") as Label).text.begins_with("沿著海港"),"long minigame title remains available in the HUD")
	_check(hud.get("_score").text=="0816" and hud.get("_time").text=="00:42" and hud.get("_progress").text.contains("3/6"),"score, time, and round progress remain visible")
	var header_style := (hud.get("_header") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	_check(header_style!=null and header_style.bg_color==Color("#0c2938") and header_style.corner_radius_top_left==0,"HUD uses a crisp navy pixel frame")
	(hud.find_child("PauseButton",true,false) as Button).pressed.emit()
	_check(events==["pause"],"pause action preserves its signal")
	hud.set_paused(true)
	await _frames(2)
	_check(_visible_inside(hud.find_child("PauseOverlay",true,false),Vector2(get_viewport().size)),"pause actions fit in the physical viewport")
	(hud.find_child("HelpFromPauseButton",true,false) as Button).pressed.emit()
	(hud.find_child("PracticeButton",true,false) as Button).pressed.emit()
	(hud.find_child("RetryButton",true,false) as Button).pressed.emit()
	_check((hud.find_child("ConfirmOverlay",true,false) as Control).visible,"retry keeps its confirmation step")
	(hud.find_child("ConfirmAction",true,false) as Button).pressed.emit()
	(hud.find_child("LeaveButton",true,false) as Button).pressed.emit()
	(hud.find_child("ConfirmAction",true,false) as Button).pressed.emit()
	hud.set_score_details({"rule":"依實際事件計分","rows":[{"label":"接住","amount":80,"count":3}],"total":816})
	(hud.find_child("DetailsButton",true,false) as Button).pressed.emit()
	_check((hud.get("_score_layer") as Control).visible and hud.find_child("ScoreDetailsBackButton",true,false) is Button,"score detail remains returnable without a scroll layer")
	hud.close_score_details()
	hud.set_state({"title":"海風接帽","objective":"完成六次接取","progress_text":"6/6 接住","score":816,"time_text":"00:00","ended":true,"won":true,"devil":true})
	_check((hud.get("_result_layer") as Control).visible and hud.get("_result_status").text.contains("816"),"result preserves earned outcome and total score")
	_check(events==["pause","help","practice","retry","leave","details"],"help, practice, retry, leave, and details preserve their public signals")
	for size in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		host.size=Vector2(size)
		await _frames(6)
		hud.set_paused(true)
		await _frames(1)
		_check(_visible_inside(hud.find_child("PauseOverlay",true,false),Vector2(size)),"pause actions stay within viewport %dx%d"%[size.x,size.y])
		hud.set_paused(false)
		_check(_visible_inside(hud.find_child("MinigameHeader",true,false),Vector2(size)) and _visible_inside(hud.find_child("MinigameStatusRail",true,false),Vector2(size)),"HUD corner groups fit viewport %dx%d"%[size.x,size.y])
	host.size=Vector2(800,450)
	Paper.set_text_scale(1.25)
	hud.call("_layout")
	await _frames(4)
	hud.set_paused(true)
	_check((hud.get("_title") as Label).get_theme_font_size("font_size")>=48 and _visible_inside(hud.find_child("PauseOverlay",true,false),Vector2(800,450)),"HUD remains readable and bounded with enlarged text at compact size")
	hud.set_paused(false)
	Paper.set_text_scale(1.0)
	host.size=Vector2(1280,720)
	hud.call("_layout")
	await _frames(4)

	var invite := InviteScript.new()
	invite.definition={"attraction_tag":"海港挑戰","name":"海風接帽","island_invitation":"追上被海風吹走的帽子，接得越準分數越高。"}
	var invite_events: Array[String]=[]
	invite.start_requested=func(): invite_events.append("start")
	invite.rules_requested=func(): invite_events.append("rules")
	invite.close_requested=func(): invite_events.append("close")
	host.size=Vector2(800,450)
	host.add_child(invite)
	await _frames(2)
	var invite_card := invite.find_child("InviteCard",true,false) as Control
	_check(invite_card!=null and _visible_inside(invite_card,Vector2(get_viewport().size)),"compact invitation stays centered and in bounds")
	var start := invite.find_child("InviteStart",true,false) as Button
	_check(start!=null and start.has_focus(),"invitation focuses its primary start action")
	start.pressed.emit()
	(invite.find_child("InviteRules",true,false) as Button).pressed.emit()
	(invite.find_child("InviteBack",true,false) as Button).pressed.emit()
	_check(invite_events==["start","rules","close"],"invitation preserves start, optional rules, and close callbacks")

	var dialogue := DialogueScript.new()
	host.size=Vector2(1280,720)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dialogue)
	await _frames(2)
	var dialogue_events: Array[String]=[]
	dialogue.advance_requested.connect(func(): dialogue_events.append("advance"))
	dialogue.finished.connect(func(): dialogue_events.append("finish"))
	dialogue.show_line("阿浪","海風吹過港口，旅人們把帽子交給風；追上帽子，就能發現每條巷子藏著不同故事。",1)
	_check(dialogue.speaker_label.text=="阿浪" and dialogue.text_label.text.contains("港口") and dialogue.visible,"dialogue keeps speaker portrait, complete subtitle, and panel visible")
	dialogue.advance_button.pressed.emit()
	dialogue.cancel_button.pressed.emit()
	_check(dialogue_events==["advance","finish"],"dialogue keeps advance and end lifecycle signals")
	var plaque := dialogue.find_child("DialoguePlaque",true,false) as Control
	_check(_inside_parent(plaque,dialogue) and _inside_parent(dialogue.advance_button,dialogue) and _inside_parent(dialogue.cancel_button,dialogue),"dialogue panel and both fixed actions fit its bottom anchored layout")

	var photo := PhotoStageScript.new()
	photo.custom_minimum_size=Vector2(0,142)
	host.add_child(photo)
	await _frames(2)
	var photo_style := photo.background
	_check(photo_style!=null and photo_style.bg_color==Color("#0c2938") and photo_style.corner_radius_top_left==0,"photo stage uses a crisp frame and leaves scene art intact")
	_check(photo.custom_minimum_size.y>=142.0,"photo stage retains a complete illustration viewport")

	# Reproduce Session._finish: a final HUD update arrives after detaching while
	# a resize pass is still awaiting its next frame.
	hud.call("_queue_layout_refresh")
	host.remove_child(hud)
	hud.set_state({"title":"離場後的結算","progress_text":"完成","score":816,"ended":true,"won":true})
	await _frames(5)
	_check((hud.get("_title") as Label).text=="離場後的結算" and not bool(hud.get("_layout_refresh_pending")),"detached HUD retains final state and cancels pending viewport layout without engine errors")
	hud.free()
	host.queue_free()
	await _frames(1)

	# Exercise the same HUD through Main._launch_game, including its live practice hint.
	get_tree().root.content_scale_size=Vector2i(1280,720)
	get_tree().root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.size=Vector2i(800,450)
	Progress.settings["ui_scale"]=1.25
	var main := MainScript.new()
	get_tree().root.add_child(main)
	await _frames(3)
	var breakdown := VBoxContainer.new()
	main._render_score_row(breakdown,{"label":"操作步數（不計分）","amount":0,"count":23,"progress_only":true},0)
	main._render_score_row(breakdown,{"label":"扣分","amount":-20,"count":1},1)
	_check(breakdown.get_child(0).text.contains("23 次") and not breakdown.get_child(0).text.contains("0 分"),"result shows the actual non-scoring operation count rather than zero points")
	_check(breakdown.get_child(1).text.contains("-20 分"),"point-bearing rows retain their signed score")
	breakdown.free()
	main._launch_game("game-001",false,true)
	await _frames(6)
	var live_hud := main.session.minigame_hud as Control if main.session != null else null
	_check(live_hud != null,"Main starts a real practice session with its shared HUD")
	if live_hud != null:
		Paper.set_text_scale(1.25)
		var session_control := main.session as Control
		_check(session_control.size==Vector2(1280,720) and is_equal_approx(Paper.physical_scale(live_hud),0.625),"live Main uses the native1280 logical canvas at800physical")
		await _frames(5)
		var progress_label := live_hud.get("_progress") as Label
		var badge_label := live_hud.get("_badge") as Label
		var header := live_hud.find_child("MinigameHeader",true,false) as Control
		var hint := live_hud.find_child("ContextFeedback",true,false) as Control
		_check(progress_label != null and _label_fits_full_text(progress_label),"live progress label has enough width for its complete text")
		_check(badge_label != null and badge_label.visible and _label_fits_full_text(badge_label),"live practice badge remains visible without truncation")
		_check(hint != null and hint.visible and header != null and not header.get_global_rect().intersects(hint.get_global_rect()),"live practice hint does not overlap the HUD header")
		var rail := live_hud.find_child("MinigameStatusRail",true,false) as Control
		_check(header.get_global_rect().encloses(progress_label.get_global_rect()) and (header.get_global_rect().encloses(badge_label.get_global_rect()) or rail.get_global_rect().encloses(badge_label.get_global_rect())),"live progress and practice glyphs are fully enclosed by their corner plates")
		_check(header.get_global_rect().end.x<rail.get_global_rect().position.x,"live native-scale corner plates preserve an open center gap")
		_check(_live_visible_labels_fit(live_hud),"every visible live HUD label has drawable shaped lines and fits its actual ancestors")
		Paper.set_text_scale(1.0)
		main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		await get_tree().process_frame
	if failures.is_empty():
		print("PASS: minigame HUD, pause/results, invite, dialogue, photo frame, and 3 viewport sizes")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _visible_inside(control: Control, viewport_size: Vector2) -> bool:
	if control==null or not control.is_visible_in_tree(): return false
	var rect := control.get_global_rect()
	var result := Rect2(Vector2.ZERO,viewport_size).encloses(rect)
	if not result: print("BOUNDS ",control.name," rect=",rect," viewport=",viewport_size," actual=",get_viewport().size)
	return result


func _label_fits_full_text(label: Label) -> bool:
	if label.text.is_empty() or not label.is_visible_in_tree(): return false
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var required := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var visible_lines := label.get_visible_line_count()
	return visible_lines>=1 and visible_lines==label.get_line_count() and label.visible_ratio>=1.0 and label.size.x>=required.x and label.size.y>=label.get_line_height(-1)

func _live_visible_labels_fit(node: Node) -> bool:
	if node is Control and not node.is_visible_in_tree(): return true
	if node is Label and not node.text.is_empty():
		var rect: Rect2=node.get_global_rect()
		if node.get_visible_line_count()<1 or node.get_visible_line_count()!=node.get_line_count() or node.size.y<node.get_line_height(-1):
			print("LIVE_HUD_LINE_CLIPPED ",node.get_path()," local=",node.size," shaped=",node.get_line_height(-1)," lines=",node.get_visible_line_count(),"/",node.get_line_count())
			return false
		var ancestor := node.get_parent()
		while ancestor!=null:
			if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().encloses(rect): return false
			ancestor=ancestor.get_parent()
		if not get_viewport().get_visible_rect().encloses(rect): return false
	for child in node.get_children():
		if not _live_visible_labels_fit(child): return false
	return true

func _inside_parent(control: Control, parent: Control) -> bool:
	return control!=null and Rect2(Vector2.ZERO,parent.size).encloses(control.get_global_rect())

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame
