extends Control
## A persistent, bottom-anchored subtitle strip for island dialogue.

signal advance_requested
signal finished

const Paper := preload("res://game/ui/paper_ui.gd")
const Collage := preload("res://game/ui/collage_kit.gd")
const TypewriterPop := preload("res://game/ui/typewriter_pop.gd")

## Extra seconds the typewriter rests after punctuation, so a line reads in
## breaths: short after a comma, longer after a full stop, longest at an ellipsis.
const PUNCTUATION_PAUSE := {"，": 0.12, "、": 0.1, ",": 0.1, "；": 0.14, "：": 0.12, "。": 0.24, "！": 0.24, "？": 0.24, ".": 0.2, "!": 0.2, "?": 0.2, "…": 0.32, "～": 0.16, "—": 0.16}

const ADVANCE_REVEAL_TEXT := "顯示整句  ›"
const ADVANCE_NEXT_TEXT := "下一句  ›"
const ADVANCE_LAST_TEXT := "完成  ›"

var speaker_label: Label
var text_label: Label
var advance_button: Button
var cancel_button: Button
var _is_last_line := false
## Draws the subtitle with a per-character pop; `text_label` stays the source of
## truth (text, reveal, layout, assistive reading) with its own ink hidden.
var _typewriter: RichTextLabel
var _pop: RichTextEffect
var _shown_text := ""
var _revealed := 0
var _clock := 0.0

## Seconds the typewriter rests after revealing `character` (0 when none).
static func pause_after(character: String) -> float:
	return float(PUNCTUATION_PAUSE.get(character, 0.0))

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
	# A torn note of dialogue taped over the scene; same padding as the old board.
	var face := StyleBoxEmpty.new()
	face.content_margin_left = 14
	face.content_margin_right = 14
	face.content_margin_top = 10
	face.content_margin_bottom = 14
	plaque.add_theme_stylebox_override("panel", face)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(plaque)
	Collage.backing(plaque, "note", 9, Collage.CREAM)
	Collage.paperize(plaque)
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
	Collage.backing(portrait, "snapshot", 4, Color("#fbf7ec"), 6.0)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	columns.add_child(copy)
	var heading := HBoxContainer.new()
	copy.add_child(heading)
	speaker_label = Paper.label("", 22, Paper.TEAL)
	speaker_label.add_theme_color_override("font_color", Collage.INK)
	speaker_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(speaker_label)
	# The speaker's name is a coloured sticker slapped on the note.
	Collage.backing(speaker_label, "chip", 1, Collage.RIM, 4.0)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(gap)
	cancel_button = Paper.button("結束對話", _request_cancel, heading)
	cancel_button.name = "DialogueCancel"
	text_label = Paper.label("", 22, Paper.INK)
	text_label.add_theme_color_override("font_color", Collage.INK)
	text_label.name = "DialogueSubtitle"
	text_label.custom_minimum_size = Vector2(0, 80)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(text_label)
	_pop = TypewriterPop.new()
	_typewriter = RichTextLabel.new()
	_typewriter.name = "DialogueTypewriter"
	_typewriter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_typewriter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_typewriter.scroll_active = false
	_typewriter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_typewriter.custom_effects = [_pop]
	_typewriter.add_theme_color_override("default_color", Collage.INK)
	text_label.add_child(_typewriter)
	text_label.add_theme_color_override("font_color", Color(0, 0, 0, 0))
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
		# A skip shows the rest at once, without popping every character.
		for index in range(_revealed, text_label.text.length()):
			_pop.stamp(index, _clock - 1.0)
		_revealed = text_label.text.length()
		text_label.visible_characters = -1
	_sync_typewriter()
	_sync_advance_text()

## True while the typewriter is still revealing the current line.
func is_revealing() -> bool:
	return is_instance_valid(text_label) and text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length()

func _process(delta: float) -> void:
	if visible:
		_clock += delta
		_sync_typewriter()
		_sync_advance_text()

## Mirror the label's text, font, size and reveal onto the drawn subtitle and
## stamp the moment each new character appears.
func _sync_typewriter() -> void:
	if not is_instance_valid(_typewriter) or not is_instance_valid(text_label):
		return
	var font_size := text_label.get_theme_font_size("font_size")
	if _typewriter.get_theme_font_size("normal_font_size") != font_size:
		_typewriter.add_theme_font_size_override("normal_font_size", font_size)
	var font := text_label.get_theme_font("font")
	if _typewriter.get_theme_font("normal_font") != font:
		_typewriter.add_theme_font_override("normal_font", font)
	_typewriter.add_theme_constant_override("line_separation", text_label.get_theme_constant("line_spacing"))
	if text_label.text != _shown_text:
		_shown_text = text_label.text
		_typewriter.clear()
		_typewriter.push_customfx(_pop, {})
		_typewriter.add_text(_shown_text)
		_typewriter.pop()
		_pop.reset()
		_revealed = 0
	var shown := text_label.visible_characters
	var count := _shown_text.length() if shown < 0 else mini(shown, _shown_text.length())
	for index in range(_revealed, count):
		_pop.stamp(index, _clock)
	_revealed = count
	_pop.now = _clock
	_pop.font_size = font_size
	_typewriter.visible_characters = shown

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
