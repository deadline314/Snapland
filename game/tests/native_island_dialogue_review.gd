extends Node

const MainScene := preload("res://game/main.tscn")

var _main: Node
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native island dialogue review requires a GPU-backed display")
		get_tree().quit(1)
		return
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Native island dialogue review requires an isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = false
	Progress.save_progress()
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(3)
	_check(_main.modal_kind == "dialogue", "new arrival opens the anchored subtitle panel")
	_check(_main.dialogue_panel != null and _main.dialogue_panel.visible, "arrival uses the reusable dialogue panel")
	_check(_main.world.blocked, "world controls pause while dialogue is open")
	await _click_control(_main.dialogue_panel.advance_button)
	_check(_main.dialogue_label.visible_characters == -1, "mouse/touch advance reveals the current line")
	_press_key(KEY_E)
	_check(_main.dialogue_index == 1, "E advances after the current line is fully revealed")
	await _click_control(_main.dialogue_panel.advance_button)
	_press_key(KEY_E)
	_check(_main.dialogue_index == 2, "mouse and keyboard can advance separate dialogue lines")
	_press_key(KEY_ESCAPE)
	_check(_main.modal_kind == "" and not _main.world.blocked, "cancel safely closes dialogue and resumes the world")
	_check(Progress.intro_seen, "cancelling arrival preserves the existing intro progress")

	_main._interact("quest-001", "小角")
	_check(_main.dialogue_panel.speaker_label.text == "小角", "the mascot receives regular actor dialogue")
	_press_key(KEY_ESCAPE)
	_check(_main.modal_kind == "" and int(Progress.quests.get("quest-001", 0)) == 1 and not Progress.photos.has("photo-welcome-quest-1"), "cancel records the encounter without opening a quest or granting its reward")
	_main._interact("quest-001", "小角")
	await _complete_current_dialogue()
	_check(_main.modal_kind == "quest" and int(Progress.quests.get("quest-001", 0)) == 1, "natural actor conversation opens the existing quest after recording its interaction")
	_main._close()
	_main._interact("quest-002", "阿浪")
	_check(_main.dialogue_panel.speaker_label.text == "阿浪", "the announcer receives regular actor dialogue")
	await _complete_current_dialogue()
	_check(_main.modal_kind == "quest" and int(Progress.quests.get("quest-002", 0)) == 1, "natural announcer conversation opens its existing quest")
	await RenderingServer.frame_post_draw
	_report()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _click_control(control: Control) -> void:
	await _frames(2)
	var point := control.get_viewport().get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion)
	await _frames(1)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(1)


func _complete_current_dialogue() -> void:
	var safety: int = _main.dialogue.size() * 3 + 2
	while _main.modal_kind == "dialogue" and safety > 0:
		safety -= 1
		var needs_reveal: bool = _main.dialogue_label != null and _main.dialogue_label.visible_characters >= 0
		_press_key(KEY_E)
		if needs_reveal:
			_press_key(KEY_E)
	_check(_main.modal_kind != "dialogue", "dialogue finishes naturally through keyboard input")


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	if _failures.is_empty():
		print("PASS: native island dialogue interaction review")
	else:
		push_error("Native island dialogue review failed: " + "; ".join(_failures))
