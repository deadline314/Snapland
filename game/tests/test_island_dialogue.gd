extends Node

const DIALOGUE_PANEL_PATH := "res://game/ui/dialogue_panel.gd"
const AudioDirectorScript := preload("res://game/audio/audio_director.gd")
const MainScene := preload("res://game/main.tscn")

var _panel: Variant
var _audio: Node
var _main: Node
var _finished := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before island dialogue tests.")
		get_tree().quit(1)
		return
	var dialogue_panel_script := load(DIALOGUE_PANEL_PATH) as Script
	if dialogue_panel_script == null:
		push_error("FAIL: the reusable island dialogue panel is missing")
		get_tree().quit(1)
		return
	_panel = dialogue_panel_script.new()
	_audio = AudioDirectorScript.new()
	add_child(_panel)
	add_child(_audio)
	await get_tree().process_frame
	_panel.finished.connect(func(): _finished = true)
	_panel.advance_requested.connect(_advance_test_line)
	_panel.show_line("票票", "船已靠岸。沿木棧橋進廣場。", 0)
	assert(_panel.visible and _panel.speaker_label.text == "票票", "the dialogue panel shows the current speaker")
	assert(_panel.text_label.text == "船已靠岸。沿木棧橋進廣場。", "the dialogue panel keeps the complete subtitle visible to assistive readers")
	assert(_panel.text_label.visible_characters == 0, "the dialogue line starts with typewriter reveal")
	assert(_panel.advance_button.text == _panel.ADVANCE_REVEAL_TEXT and _panel.is_revealing(), "while text is revealing the one advance control offers to show the whole line")
	_panel.reveal_all()
	assert(_panel.text_label.visible_characters == -1, "the first advance reveals the full line")
	assert(_panel.advance_button.text == _panel.ADVANCE_NEXT_TEXT and not _panel.is_revealing(), "a fully shown line offers the next line")
	_panel.show_line("票票", "最後一句。", 2, true)
	_panel.text_label.visible_characters = _panel.text_label.text.length()
	await get_tree().process_frame
	assert(_panel.advance_button.text == _panel.ADVANCE_LAST_TEXT, "a naturally finished last line offers to finish the conversation")
	_panel.show_line("票票", "船已靠岸。沿木棧橋進廣場。", 0)
	_panel.reveal_all()
	_panel.advance_button.pressed.emit()
	assert(_panel.speaker_label.text == "小角", "the advance button proceeds to the next speaker")
	_panel.cancel_button.pressed.emit()
	assert(_finished and not _panel.visible, "the cancel button safely finishes and hides dialogue")

	_audio.apply_settings({"master_volume": 1.0, "sfx_volume": 0.0})
	assert(not _audio.play_dialogue_beep("票票", "你"), "dialogue beeps respect zero SFX volume")
	_audio.apply_settings({"master_volume": 1.0, "sfx_volume": 1.0})
	assert(not _audio.play_dialogue_beep("票票", "，"), "punctuation never triggers a dialogue beep")
	for quiet_glyph in ["「", "」", "（", "…", "—", "　", " ", "!", "・"]:
		assert(not _audio.play_dialogue_beep("票票", quiet_glyph), "quotes, brackets, spaces and marks stay silent: %s" % quiet_glyph)
	assert(_audio.play_dialogue_beep("票票", "你"), "a spoken character triggers the synthesized dialogue beep")
	assert(not _audio.play_dialogue_beep("小角", "好"), "rapid reveal characters are bounded by the shared beep interval")
	await get_tree().create_timer(0.1).timeout
	assert(_audio._dialogue_beep_streams["票票"].data != _audio._dialogue_beep_streams["小角"].data, "each actor uses a distinct synthesized pitch")
	assert(_audio.DIALOGUE_BEEP_INTERVAL_MSEC["票票"] != _audio.DIALOGUE_BEEP_INTERVAL_MSEC["小角"], "each actor has a distinct but bounded beep cadence")
	await get_tree().create_timer(0.1).timeout
	_audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	_panel.queue_free()
	_audio.queue_free()
	await get_tree().process_frame
	Progress.reset_progress()
	Progress.intro_seen = false
	Progress.save_progress()
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(3)
	assert(_main.modal_kind == "dialogue" and _main.world.blocked, "first arrival starts a world-pausing dialogue")
	_main._next_dialogue()
	assert(_main.dialogue_label.visible_characters == -1, "first advance reveals the current line without skipping it")
	_main._next_dialogue()
	assert(_main.dialogue_index == 1, "second advance moves to the next subtitle")
	_main._finish_dialogue()
	assert(_main.modal_kind == "" and not _main.world.blocked and Progress.intro_seen, "cancel completes arrival progress and unblocks the park")
	_main._interact("quest-001", "小角")
	assert(_main.dialogue_panel.speaker_label.text == "小角", "mascot interaction routes through regular dialogue")
	_main._finish_dialogue()
	assert(_main.modal_kind == "quest" and int(Progress.quests.get("quest-001", 0)) == 1, "mascot dialogue preserves the existing mission interaction event")
	_main._close()
	_main._interact("quest-001", "小角")
	_main._cancel_dialogue()
	assert(_main.modal_kind == "" and int(Progress.quests.get("quest-001", 0)) == 1 and not Progress.photos.has("photo-welcome-quest-1"), "cancelling an actor conversation records the encounter without opening a quest or awarding a photo")
	_main._interact("quest-001", "小角")
	_main._finish_dialogue()
	assert(_main.modal_kind == "quest", "natural actor conversation completion still opens the existing quest")
	_main._close()
	_main._interact("quest-002", "阿浪")
	assert(_main.dialogue_panel.speaker_label.text == "阿浪", "announcer interaction routes through regular dialogue")
	_main._finish_dialogue()
	assert(_main.modal_kind == "quest" and int(Progress.quests.get("quest-002", 0)) == 1, "announcer dialogue preserves the existing mission interaction event")
	_main._close()
	_main._interact("guide","票票")
	for window_size in [Vector2i(1280,720),Vector2i(800,450)]:
		get_tree().root.content_scale_size=Vector2i(1280,720)
		get_tree().root.size=window_size
		await _frames(4)
		var bounds := get_tree().root.get_visible_rect()
		var plaque := _main.dialogue_panel.find_child("DialoguePlaque",true,false) as Control
		assert(bounds.encloses(plaque.get_global_rect()),"whole dialogue card stays within the viewport")
		assert(bounds.encloses(_main.dialogue_label.get_global_rect()),"subtitle is not clipped below the screen")
		assert(bounds.encloses(_main.dialogue_panel.advance_button.get_global_rect()),"dialogue next button remains visible")
	_main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	_main.queue_free()
	await get_tree().process_frame
	print("PASS: island dialogue panel and bounded, speaker-pitched beep")
	get_tree().quit(0)


func _advance_test_line() -> void:
	if _panel.text_label.visible_characters != -1 and _panel.text_label.visible_characters < _panel.text_label.text.length():
		_panel.reveal_all()
	else:
		_panel.show_line("小角", "尾巴彩帶也能當構圖靈感。", 1)


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
