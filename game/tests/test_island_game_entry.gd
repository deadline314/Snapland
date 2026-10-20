extends Node
var failures: Array[String] = []
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(): get_tree().quit(1); return
	Progress.reset_progress(); Progress.intro_seen = true
	var main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 3: await get_tree().process_frame
	for definition in main.definitions:
		main._show_game_info(definition.id)
		for i in 2: await get_tree().process_frame
		var entry = main.overlay.find_child("IslandGameInvite",true,false)
		if entry == null: failures.append("Compact invite missing: "+definition.id); break
		if main.hud.visible: failures.append("Invite must hide unrelated park counters and the stale nearby action: "+definition.id)
		if main.overlay.find_child("GameRulesDetails",true,false) != null: failures.append("Rules shown before request: "+definition.id)
		var buttons = entry.find_children("*","Button",true,false)
		if buttons.size() != 3: failures.append("Invite requires start/rules/return only: "+definition.id)
		var invite_title := entry.find_child("InviteTitle",true,false) as Label
		var invite_line := entry.find_child("InviteLine",true,false) as Label
		var expected_title := str(definition.get("name", "")).strip_edges()
		var expected_invitation := str(definition.get("island_invitation", "")).strip_edges()
		if expected_title.is_empty() or invite_title == null or invite_title.text != expected_title:
			failures.append("Invite must show this game's actual nonempty unique title: "+definition.id)
		if expected_invitation.is_empty() or invite_line == null or invite_line.text != expected_invitation:
			failures.append("Invite must show this game's actual nonempty invitation: "+definition.id)
		var tag := str(definition.get("attraction_tag", "")).strip_edges()
		if tag.is_empty() or not _contains_label_text(entry, tag):
			failures.append("Invite must show its source attraction tag: "+definition.id)
		var start := entry.find_child("InviteStart",true,false) as Button
		if start == null or start.get_theme_color("font_focus_color").get_luminance() < 0.7:
			failures.append("Focused primary action must retain light readable text: "+definition.id)
		if not expected_title.is_empty():
			for prior_definition in main.definitions:
				if prior_definition == definition: break
				if str(prior_definition.get("name", "")).strip_edges() == expected_title:
					failures.append("Invite title must be unique across the usable game catalog: "+definition.id)
					break
		main._close()
		if not main.hud.visible or main.world.blocked: failures.append("Closing the invitation must restore the park HUD and movement: "+definition.id)
	if failures.is_empty():
		main._show_game_info("game-002")
		main.overlay.find_child("InviteStart",true,false).pressed.emit()
		for i in 3: await get_tree().process_frame
		if not is_instance_valid(main.tutorial_panel) or not main.tutorial_panel.visible or main.tutorial_target != "game-002" or main.tutorial_origin != "first_entry": failures.append("First entry must retain the visible tutorial for this game")
		if is_instance_valid(main.tutorial_panel):
			var tutorial: Control = main.tutorial_panel
			var screenshot_button := tutorial.find_child("ScreenshotZoom",true,false) as Button
			var screenshot := tutorial.get("_image") as TextureRect
			if screenshot_button == null or screenshot_button.disabled or screenshot == null or screenshot.texture == null:
				failures.append("First-entry tutorial must retain its loaded instructional screenshot and zoom action")
			else:
				screenshot_button.pressed.emit()
				for i in 2: await get_tree().process_frame
				var zoom := tutorial.find_child("ScreenshotZoomOverlay",true,false) as Control
				var zoom_image := tutorial.find_child("ZoomedScreenshot",true,false) as TextureRect
				if zoom == null or not zoom.visible or zoom_image == null or zoom_image.texture != screenshot.texture:
					failures.append("Screenshot zoom must show the current tutorial PNG")
				else:
					var zoom_back := tutorial.find_child("ScreenshotZoomBack",true,false) as Button
					if zoom_back == null: failures.append("Screenshot zoom must provide its real return button")
					else: zoom_back.pressed.emit()
					for i in 2: await get_tree().process_frame
					if zoom.visible: failures.append("Screenshot return button must close only the zoom overlay")
			var next_step := _find_button_text(tutorial, "下一步")
			if next_step == null: failures.append("Tutorial replay check requires the real next-step button")
			else:
				next_step.pressed.emit()
				for i in 2: await get_tree().process_frame
				if tutorial.current_step != 1: failures.append("Tutorial next button must advance to the next screenshot step")
				var replay := _find_button_text(tutorial, "重看本課")
				if replay == null: failures.append("Tutorial replay action is missing")
				else:
					replay.pressed.emit()
					for i in 2: await get_tree().process_frame
					if tutorial.current_step != 0 or (tutorial.get("_image") as TextureRect).texture == null:
						failures.append("Tutorial replay must restore its first illustrated step")
			var close_tutorial := _find_button_text(tutorial, "關閉")
			if close_tutorial == null: failures.append("Tutorial cancel button is missing")
			else: close_tutorial.pressed.emit()
			for i in 3: await get_tree().process_frame
			if is_instance_valid(main.session) or is_instance_valid(main.tutorial_panel) or main.modal_kind != "game_info":
				failures.append("Closing first-entry tutorial must cancel cleanly and return to the compact invite")
		if Progress.has_seen_tutorial("game-002"):
			failures.append("Closing or replaying a tutorial must not mark it complete")
		_check_no_awards("tutorial cancel")
		if failures.is_empty():
			var invite_start := main.overlay.find_child("InviteStart",true,false) as Button
			if invite_start != null: invite_start.pressed.emit()
			for i in 3: await get_tree().process_frame
			var practice_button := _find_button_text(main.tutorial_panel, "練習操作") if is_instance_valid(main.tutorial_panel) else null
			if practice_button == null: failures.append("First-entry tutorial must offer its practice route")
			else: practice_button.pressed.emit()
			for i in 4: await get_tree().process_frame
			if not is_instance_valid(main.session) or not bool(main.session.practice_mode) or bool(main.session.assisted):
				failures.append("Tutorial practice button must start a standard-controls practice session")
			else:
				if not await _cancel_live_session(main, "practice"):
					failures.append("Practice session must be leaveable through its pause and confirmation controls")
			if Progress.has_seen_tutorial("game-002"): failures.append("Practice must not complete the tutorial")
			_check_no_awards("practice cancel")
		if failures.is_empty():
			main._show_game_info("game-002")
			main.overlay.find_child("InviteRules",true,false).pressed.emit()
			for i in 2: await get_tree().process_frame
			if main.modal_kind != "game_rules" or main.overlay.find_child("GameRulesDetails",true,false) == null: failures.append("Optional rules unavailable")
			var assist_button := _find_button_text(main.overlay, "輔助挑戰")
			if assist_button == null: failures.append("Optional rules must preserve the assisted challenge action")
			else: assist_button.pressed.emit()
			for i in 4: await get_tree().process_frame
			if not is_instance_valid(main.tutorial_panel) or is_instance_valid(main.session) or not main.tutorial_assist:
				failures.append("First assisted entry must offer the same tutorial before the round starts")
			else:
				var cancel_assist := _find_button_text(main.tutorial_panel, "關閉")
				if cancel_assist != null: cancel_assist.pressed.emit()
				for i in 3: await get_tree().process_frame
				if Progress.has_seen_tutorial("game-002") or main.modal_kind != "game_rules":
					failures.append("Cancelling assisted onboarding must keep the lesson unseen and restore optional rules")
				_check_no_awards("assisted tutorial cancel")
				assist_button.pressed.emit()
				for i in 3: await get_tree().process_frame
				var skip_assist := _find_button_text(main.tutorial_panel, "略過")
				if skip_assist == null: failures.append("Assisted onboarding must remain skippable")
				else: skip_assist.pressed.emit()
				for i in 4: await get_tree().process_frame
			if not is_instance_valid(main.session) or not bool(main.session.assisted) or bool(main.session.practice_mode):
				failures.append("Rules assisted challenge must start an assisted, non-practice session")
			else:
				if not await _cancel_live_session(main, "assist"):
					failures.append("Assisted session must be leaveable through its pause and confirmation controls")
			_check_no_awards("assisted cancel")
	main.world.set_process(false)
	main.world.set_physics_process(false)
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	# Let the main scene, tutorial textures, and both cancelled HUD overlays finish
	# their deferred frees before this isolated fixture asks Godot to tear down.
	for i in 12: await get_tree().process_frame
	if is_instance_valid(main): failures.append("Main scene must finish deferred teardown before the fixture exits")
	for problem in failures: push_error(problem)
	print("PASS: 12 compact invites and first-entry/optional-rule flow; distinct copy, screenshot/replay, practice/assist leave, and no-award rules" if failures.is_empty() else "FAIL: island entry "+str(failures.size()))
	get_tree().quit(0 if failures.is_empty() else 1)

func _find_button_text(root: Node, text: String) -> Button:
	if root == null: return null
	for child in root.get_children():
		if child is Button and (child as Button).text == text: return child as Button
		var match_button := _find_button_text(child, text)
		if match_button != null: return match_button
	return null

func _contains_label_text(root: Node, text: String) -> bool:
	if root == null: return false
	for child in root.get_children():
		if child is Label and (child as Label).text == text: return true
		if _contains_label_text(child, text): return true
	return false

func _cancel_live_session(main: Node, kind: String) -> bool:
	var session: Control = main.session
	var hud: Node = session.minigame_hud
	var pause := hud.find_child("PauseButton", true, false) as Button
	if pause == null: return false
	pause.pressed.emit()
	for i in 2: await get_tree().process_frame
	var pause_layer := hud.find_child("PauseOverlay", true, false) as Control
	var leave := hud.find_child("LeaveButton", true, false) as Button
	if pause_layer == null or not pause_layer.visible or leave == null: return false
	leave.pressed.emit()
	for i in 2: await get_tree().process_frame
	var confirm_layer := hud.find_child("ConfirmOverlay", true, false) as Control
	var confirm := hud.find_child("ConfirmAction", true, false) as Button
	if confirm_layer == null or not confirm_layer.visible or confirm == null: return false
	confirm.pressed.emit()
	for i in 3: await get_tree().process_frame
	return main.session == null and main.modal_kind == ""

func _check_no_awards(stage: String) -> void:
	if not Progress.photos.is_empty() or int(Progress.normal_count()) != 0 or int(Progress.devil_count()) != 0:
		failures.append("%s must not grant photo rewards" % stage)
	if int(Progress.coins) != 120 or not Progress.achievements.is_empty() or not Progress.quests.is_empty():
		failures.append("%s must not change currency, achievements, or quests" % stage)
