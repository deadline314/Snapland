extends Control
## A persistent, bottom-anchored subtitle strip for island dialogue.

signal advance_requested
signal finished

const Paper := preload("res://game/ui/paper_ui.gd")

var speaker_label: Label
var text_label: Label
var advance_button: Button
var cancel_button: Button

func _ready() -> void:
	name = "IslandDialoguePanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.anchor_top = 0.70
	center.offset_left = 24
	center.offset_right = -24
	center.offset_top = 0
	center.offset_bottom = -20
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var plaque := PanelContainer.new()
	plaque.name = "DialoguePlaque"
	plaque.custom_minimum_size = Vector2(0, 190)
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
	speaker_label = Paper.label("", 22, Paper.DEEP_TEAL)
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(speaker_label)
	cancel_button = Paper.button("結束對話", _request_cancel, heading)
	cancel_button.name = "DialogueCancel"
	text_label = Paper.label("", 24)
	text_label.name = "DialogueSubtitle"
	text_label.custom_minimum_size = Vector2(0, 82)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.clip_contents = true
	copy.add_child(text_label)
	advance_button = Paper.button("繼續  ›", _request_advance, copy)
	advance_button.tooltip_text = "E 或空白鍵：顯示完整內容，再按下一句。"
	advance_button.name = "DialogueAdvance"
	advance_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	advance_button.custom_minimum_size.y = 42
	advance_button.grab_focus()

func show_line(speaker: String, text: String, _line_index: int = 0) -> void:
	speaker_label.text = speaker
	text_label.text = text
	text_label.visible_characters = 0
	var portrait := find_child("DialoguePortrait", true, false) as Control
	if portrait != null:
		portrait.set("speaker", speaker)
		portrait.queue_redraw()
	visible = true

func reveal_all() -> void:
	if is_instance_valid(text_label):
		text_label.visible_characters = -1

func _request_advance() -> void:
	advance_requested.emit()

func _request_cancel() -> void:
	hide()
	finished.emit()
