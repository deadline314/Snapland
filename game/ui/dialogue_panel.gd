extends Control
## A persistent, bottom-anchored subtitle strip for island dialogue.

signal advance_requested
signal finished

const Paper := preload("res://game/ui/paper_ui.gd")

const ADVANCE_REVEAL_TEXT := "顯示整句  ›"
const ADVANCE_NEXT_TEXT := "下一句  ›"
const ADVANCE_LAST_TEXT := "完成  ›"

var speaker_label: Label
var text_label: Label
var advance_button: Button
var cancel_button: Button
var _is_last_line := false

func _ready() -> void:
	name = "IslandDialoguePanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.anchor_top = 0.66
	center.offset_left = 18
	center.offset_right = -18
	center.offset_top = 0
	center.offset_bottom = -16
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var plaque := PanelContainer.new()
	plaque.name = "DialoguePlaque"
	plaque.custom_minimum_size = Vector2(0, 194)
	plaque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plaque.add_theme_stylebox_override("panel", Paper.plaque(Color("#f7efd9")))
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(plaque)
	var margin := MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	plaque.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	margin.add_child(columns)
	var portrait := Paper.portrait("")
	portrait.name = "DialoguePortrait"
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	columns.add_child(copy)
	var heading := HBoxContainer.new()
	copy.add_child(heading)
	speaker_label = Paper.label("", 22, Paper.TEAL)
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(speaker_label)
	cancel_button = Paper.button("結束對話", _request_cancel, heading)
	cancel_button.name = "DialogueCancel"
	text_label = Paper.label("", 22, Paper.INK)
	text_label.name = "DialogueSubtitle"
	text_label.custom_minimum_size = Vector2(0, 80)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(text_label)
	advance_button = Paper.button(ADVANCE_REVEAL_TEXT, _request_advance, copy)
	advance_button.tooltip_text = "E 或空白鍵：先顯示整句，再按一次到下一句。"
	advance_button.name = "DialogueAdvance"
	advance_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	advance_button.custom_minimum_size.y = 42
	advance_button.grab_focus()

func show_line(speaker: String, text: String, _line_index: int = 0, is_last := false) -> void:
	speaker_label.text = speaker
	text_label.text = text
	text_label.visible_characters = 0
	_is_last_line = is_last
	_sync_advance_text()
	var portrait := find_child("DialoguePortrait", true, false) as Control
	if portrait != null:
		portrait.set("speaker", speaker)
		portrait.queue_redraw()
	visible = true

func reveal_all() -> void:
	if is_instance_valid(text_label):
		text_label.visible_characters = -1
	_sync_advance_text()

## True while the typewriter is still revealing the current line.
func is_revealing() -> bool:
	return is_instance_valid(text_label) and text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length()

func _process(_delta: float) -> void:
	if visible:
		_sync_advance_text()

## The one advance control names what it will do next: finish the line,
## go to the next line, or close the conversation.
func _sync_advance_text() -> void:
	if not is_instance_valid(advance_button):
		return
	var wanted := ADVANCE_REVEAL_TEXT if is_revealing() else ADVANCE_LAST_TEXT if _is_last_line else ADVANCE_NEXT_TEXT
	if advance_button.text != wanted:
		advance_button.text = wanted

func _request_advance() -> void:
	advance_requested.emit()

func _request_cancel() -> void:
	hide()
	finished.emit()
