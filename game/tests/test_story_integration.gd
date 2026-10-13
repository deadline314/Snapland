extends Node

const MAIN_SCENE := preload("res://game/main.tscn")
var main: Node
var progress: Node
var failures: Array[String] = []
var finishing := false
var crowd_finish_evidence: Dictionary = {}

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before story integration.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	progress = get_tree().root.get_node_or_null("Progress")
	_check(progress != null, "Progress autoload exists")
	if progress == null:
		_finish()
		return
	progress.reset_progress()
	progress.intro_seen = false
	progress.save_progress()
	get_window().size = Vector2i(1280, 720)
	await _frames(2)
	main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)
	_check(main.modal_kind == "dialogue" and main.dialogue_panel.visible, "fresh profile reaches anchored arrival dialogue")
	_check(main.dialogue_label.visible_characters >= 0 and main.dialogue_label.visible_characters < main.dialogue_label.text.length(), "arrival opens with its first subtitle in typewriter reveal")
	await _complete_dialogue()
	await _frames(2)
	_check(main.modal_kind == "" and progress.intro_seen, "natural arrival dialogue completion opens the park and preserves intro progress")

	await _interact_at("quest-001")
	_check(int(progress.quests.get("quest-001", 0)) == 1, "real Xiao Jiao interaction starts mission 1")
	_check(main.modal_kind == "quest", "quest ticket opens at the current objective")
	_check_quest_card("小角的尾巴彩帶試拍", "旅券 · 第2步 / 3", "看看長椅的合照構圖", "quest-001 current step")
	_press_button(main.modal_body, "返回遊園")
	await _frames(2)
	await _interact_at("quest-001")
	_check(int(progress.quests.get("quest-001", 0)) == 1, "reopening the ticket preserves its current step")
	_check_quest_card("小角的尾巴彩帶試拍", "旅券 · 第2步 / 3", "看看長椅的合照構圖", "reopened quest-001 current step")
	_press_button(main.modal_body, "返回遊園")
	await _frames(2)
	await _complete_exploration(3)
	_check(int(progress.quests.get("quest-001", 0)) == 2, "real bench photo advances framing step")
	await _interact_at("quest-001")
	_check_quest_card("小角的尾巴彩帶試拍", "旅券 · 第3步 / 3", "替新構圖試一次泡泡快門", "quest-001 current step after bench photo")
	_press_button(main.modal_body, "返回遊園")
	await _frames(2)
	_check(not progress.photos.has("photo-welcome-quest-1"), "unfinished mission has no completion reward")

	await _interact_at("quest-002")
	_check(int(progress.quests.get("quest-002", 0)) == 1, "real 阿浪 interaction starts mission 2")
	_check_quest_card("廣播即興救場", "旅券 · 第2步 / 3", "核對歡迎字樣與入口方向", "quest-002 current step")
	_press_button(main.modal_body, "返回遊園")
	await _frames(2)
	await _complete_exploration(2)
	_check(int(progress.quests.get("quest-002", 0)) == 2, "real aligned welcome-wall photo proves observation step")
	await _interact_at("quest-002")
	_check_quest_card("廣播即興救場", "旅券 · 第3步 / 3", "試播人潮號誌", "quest-002 current step after wall photo")
	_press_button(main.modal_body, "返回遊園")
	await _frames(2)
	_check(not progress.photos.has("photo-welcome-quest-2"), "unfinished mission 2 has no completion reward")

	await _test_first_entry_session_lifecycle()
	_press_button(main.modal_body, "返回遊園")
	await _frames(2)
	await _interact_at("quest-002")
	_check_quest_card("廣播即興救場", "旅券 · 已完成", "今天的小麻煩，已經變成了拍貼裡的笑話。", "completed quest-002")

	if failures.is_empty():
		print("PASS: real Main story interactions and exploration evidence")
		print("PASS: Main first-entry tutorials create fresh sessions; natural crowd finish is latched before deletion")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	_finish()

func _test_first_entry_session_lifecycle() -> void:
	var photo := await _start_first_entry_game("game-010", 0)
	if not is_instance_valid(photo): return
	var photo_id := photo.get_instance_id()
	# Leave through the actual HUD handlers, then let queue_free complete.
	_press_named_button(photo.minigame_hud, "PauseButton")
	await _frames(2)
	_press_named_button(photo.minigame_hud, "LeaveButton")
	await _frames(2)
	_press_named_button(photo.minigame_hud, "ConfirmAction")
	await _frames(2)
	_check(not is_instance_valid(main.session) and not is_instance_id_valid(photo_id), "leaving game-010 clears Main and frees its Session")
	var crowd := await _start_first_entry_game("game-004", photo_id)
	if not is_instance_valid(crowd): return
	var crowd_id := crowd.get_instance_id()
	crowd_finish_evidence.clear()
	crowd.finished.connect(_latch_natural_crowd_finish.bind(crowd_id), CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 60000
	while crowd_finish_evidence.is_empty() and Time.get_ticks_msec() < deadline:
		if not is_instance_id_valid(crowd_id): break
		var live := instance_from_id(crowd_id) as Control
		if not is_instance_valid(live) or live.is_queued_for_deletion() or main.session != live: break
		var chosen := -1
		var earliest_deadline := INF
		for lane in 2:
			var queue: Array = live.crowd_model.queues[lane]
			if queue.is_empty(): continue
			var head: Dictionary = queue[0]
			var patience_deadline := float(head.arrived_at) + float(head.patience)
			if patience_deadline < earliest_deadline:
				earliest_deadline = patience_deadline
				chosen = lane
		if chosen >= 0 and live.crowd_model.desired_lane != chosen:
			_key(KEY_Q if chosen == 0 else KEY_E, true)
			_key(KEY_Q if chosen == 0 else KEY_E, false)
			Input.flush_buffered_events()
		await get_tree().physics_frame
	_check(not crowd_finish_evidence.is_empty(), "natural game-004 completion emits its bounded synchronous finished latch")
	_check(bool(crowd_finish_evidence.get("success", false)) and int(crowd_finish_evidence.get("safe_count", -1)) == 6, "actual Q/E input naturally routes all six groups")
	_check(int(crowd_finish_evidence.get("score", -1)) == int(crowd_finish_evidence.get("model_score", -2)), "synchronous crowd result and model scores match")
	await _frames(2)
	_check(not is_instance_valid(main.session) and not is_instance_id_valid(crowd_id) and main.modal_kind == "result", "Main frees natural completed Session and preserves its result UI")
	_check(int(progress.quests.get("quest-002", 0)) == 3 and progress.photos.has("photo-welcome-quest-2") and progress.photos.has("photo-welcome-game-4"), "natural crowd lifecycle preserves quest and ordinary photo awards")

func _start_first_entry_game(game_id: String, previous_id: int) -> Control:
	await _interact_at(game_id)
	_press_named_button(main.overlay, "InviteStart")
	await _frames(2)
	_check(not is_instance_valid(main.session), game_id + " first-entry tutorial precedes Session creation")
	_check(is_instance_valid(main.tutorial_panel), game_id + " first-entry opens the actual tutorial")
	if not is_instance_valid(main.tutorial_panel): return null
	_check(main.tutorial_panel.target_id == game_id and main.tutorial_panel.visible, "actual tutorial is ready for " + game_id)
	main.tutorial_panel._start_button.emit_signal("pressed")
	await _frames(2)
	_check(not is_instance_valid(main.tutorial_panel), "tutorial Start dismisses its panel for " + game_id)
	_check(is_instance_valid(main.session), "tutorial Start creates a valid " + game_id + " Session")
	if not is_instance_valid(main.session): return null
	var fresh: Control = main.session
	_check(not fresh.is_queued_for_deletion() and fresh.is_inside_tree() and fresh.game_id == game_id and fresh.get_instance_id() != previous_id, "tutorial Start creates a fresh live matching " + game_id + " instance")
	return fresh

func _press_named_button(node: Node, button_name: String) -> void:
	var button := node.find_child(button_name, true, false) as Button
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "actual HUD button is available: " + button_name)
	if is_instance_valid(button): button.emit_signal("pressed")

func _latch_natural_crowd_finish(result: Dictionary, session_id: int) -> void:
	_check(is_instance_id_valid(session_id), "finished listener can inspect queued Session synchronously")
	if not is_instance_id_valid(session_id): return
	var completed := instance_from_id(session_id) as Control
	crowd_finish_evidence = result.duplicate(true)
	crowd_finish_evidence["safe_count"] = int(completed.crowd_model.safe_count)
	crowd_finish_evidence["model_score"] = int(completed.crowd_model.score)
	_check(not is_instance_valid(main.session) and completed.is_queued_for_deletion(), "Main's earlier finished listener clears and queues Session before our latch")

func _interact_at(id: String) -> void:
	for point in main.world.points:
		if str(point.id) != id:
			continue
		main.world.player.position = point.position + Vector3(0, 0.3, 0)
		var deadline := Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < deadline and str(main.world.nearest.get("id", "")) != id:
			await get_tree().physics_frame
		_check(str(main.world.nearest.get("id", "")) == id, "park interaction point is reachable: " + id)
		if str(main.world.nearest.get("id", "")) != id:
			return
		_key(KEY_E, true)
		var expected := "dialogue" if id.begins_with("quest-") else "explore" if id.begins_with("explore-") else "game_info"
		deadline = Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < deadline and main.modal_kind != expected:
			await get_tree().process_frame
		_key(KEY_E, false)
		_check(main.modal_kind == expected, "E opens actual " + expected + " UI at " + id)
		if id.begins_with("quest-") and main.modal_kind == "dialogue":
			await _complete_dialogue()
			_check(main.modal_kind == "quest", "natural actor dialogue completion opens the existing quest at " + id)
		return
	_check(false, "world has interaction point " + id)

func _complete_exploration(index: int) -> void:
	await _interact_at("explore-%03d" % index)
	if index == 2:
		var slider := _find_slider(main.modal_body)
		_check(slider != null, "wall observation exposes alignment control")
		if slider != null:
			slider.value = 0
	elif index == 3:
		_press_button(main.modal_body, "借一個小角立牌")
	_press_button(main.modal_body, "按下快門")
	await _frames(2)

func _complete_dialogue() -> void:
	var remaining: int = main.dialogue.size() * 3 + 2
	while main.modal_kind == "dialogue" and remaining > 0:
		remaining -= 1
		var needs_reveal: bool = main.dialogue_label != null and main.dialogue_label.visible_characters >= 0
		_key(KEY_E, true)
		_key(KEY_E, false)
		await _frames(1)
		if needs_reveal and main.modal_kind == "dialogue":
			_key(KEY_E, true)
			_key(KEY_E, false)
			await _frames(1)
	_check(main.modal_kind != "dialogue", "all dialogue lines complete through E reveal/advance input")

func _press_button(node: Node, needle: String) -> void:
	var button := _find_button(node, needle)
	_check(button != null, "actual visible button exists: " + needle)
	if button != null:
		button.emit_signal("pressed")

func _find_button(node: Node, needle: String) -> Button:
	if node is Button and str((node as Button).text).contains(needle):
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, needle)
		if found != null:
			return found
	return null

func _find_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node as HSlider
	for child in node.get_children():
		var found := _find_slider(child)
		if found != null:
			return found
	return null

func _check_quest_card(quest_title: String, subtitle: String, step_title: String, context: String) -> void:
	var labels: Array[String] = []
	_collect_label_texts(main.modal_body, labels)
	_check(main.modal_kind == "quest", context + " opens the quest card")
	_check(labels.has(quest_title), context + " shows the player-facing quest title")
	_check(_label_text_contains(labels, subtitle), context + " shows clear ticket progress")
	_check(_label_text_contains(labels, step_title), context + " shows the human-readable objective or completion message")
	for internal_id in ["meet_imp", "frame_the_tail", "test_bubble_camera", "meet_announcer", "inspect_welcome_sign", "guide_the_crowd"]:
		_check(not _label_text_contains(labels, internal_id), context + " does not expose internal step ID " + internal_id)

func _collect_label_texts(node: Node, output: Array[String]) -> void:
	if node is Label:
		output.append((node as Label).text)
	for child in node.get_children():
		_collect_label_texts(child, output)

func _label_text_contains(labels: Array[String], needle: String) -> bool:
	for label_text in labels:
		if label_text.contains(needle): return true
	return false

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _finish() -> void:
	if finishing:
		return
	finishing = true
	call_deferred("_finish_shutdown")

func _finish_shutdown() -> void:
	if is_instance_valid(main):
		if is_instance_valid(main.audio):
			main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		await _frames(2)
	get_tree().quit(1 if not failures.is_empty() else 0)
