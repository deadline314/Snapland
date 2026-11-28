extends Control
## Island dialogue as a collage: the speaker's bust photo and a torn note with
## their name tag, docked to the speaker's side along the bottom of the screen.

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

## Name tag colours: soft papers that keep the ink name readable.
const TAG_TONES := {"票票": Color("#bfe3d6"), "小角": Color("#f6b7a5"), "阿浪": Color("#ffd98a"), "主角": Color("#bcd8ef")}
const BUST_SIZE := Vector2(150, 176)
const NOTE_WIDTH := 880.0
const NOTE_SHARE := 0.64

var speaker_label: Label
var text_label: Label
var advance_button: Button
var cancel_button: Button
## Bobs the bust while a line is being spoken; off for reduced motion.
var reduced_motion := false
## "left" or "right": which side of the screen the note docks to.
var side := "left"
var _is_last_line := false
var _dock: Control
var _row: HBoxContainer
var _plaque: PanelContainer
var _bust: Bust
var _name_tag: Control
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
	# A taped bust photo and a torn note, docked on the speaker's side of the screen.
	_dock = Control.new()
	_dock.name = "DialogueDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock)
	_row = HBoxContainer.new()
	_row.name = "DialogueRow"
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", -10)
	_dock.add_child(_row)
	_bust = Bust.new()
	_bust.name = "DialoguePortrait"
	_bust.size_flags_vertical = Control.SIZE_SHRINK_END
	_row.add_child(_bust)
	Collage.backing(_bust, "snapshot", 4, Color("#fbf7ec"), 6.0)
	var plaque := PanelContainer.new()
	plaque.name = "DialoguePlaque"
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plaque.size_flags_vertical = Control.SIZE_SHRINK_END
	_plaque = plaque
	var face := StyleBoxEmpty.new()
	face.content_margin_left = 14
	face.content_margin_right = 14
	face.content_margin_top = 10
	face.content_margin_bottom = 14
	plaque.add_theme_stylebox_override("panel", face)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_child(plaque)
	Collage.backing(plaque, "note", 9, Collage.CREAM)
	Collage.paperize(plaque)
	var margin := MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	plaque.add_child(margin)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	margin.add_child(copy)
	var heading := HBoxContainer.new()
	copy.add_child(heading)
	speaker_label = Paper.label("", 24, Paper.TEAL)
	speaker_label.name = "DialogueNameTag"
	speaker_label.add_theme_color_override("font_color", Collage.INK)
	speaker_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(speaker_label)
	# The speaker's name is a tilted collage tag in that speaker's colour.
	_name_tag = Collage.backing(speaker_label, "chip", 1, Collage.RIM, 6.0)
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
	_set_side("left")
	# A host that never calls fit() still gets a docked note at its own size.
	fit.call_deferred(get_viewport_rect().size, 1.0)

## `dock_side` ("left"/"right", empty = by speaker) puts the note beside the
## speaker; `pose` is the bust's expression (an authored action, "idle" by default).
func show_line(speaker: String, text: String, _line_index: int = 0, is_last := false, dock_side := "", pose := "idle") -> void:
	speaker_label.text = speaker
	text_label.text = text
	text_label.visible_characters = 0
	_is_last_line = is_last
	_sync_advance_text()
	if is_instance_valid(_name_tag):
		_name_tag.set("swatch", TAG_TONES.get(speaker, Collage.RIM))
		_name_tag.queue_redraw()
	_bust.show_speaker(speaker, pose)
	_set_side(dock_side if dock_side in ["left", "right"] else ("right" if speaker == "主角" else "left"))
	visible = true

func _set_side(wanted: String) -> void:
	side = wanted
	_bust.mirrored = side == "right"
	_row.alignment = BoxContainer.ALIGNMENT_END if side == "right" else BoxContainer.ALIGNMENT_BEGIN
	_row.move_child(_bust, _row.get_child_count() - 1 if side == "right" else 0)

## Lays the dock out for the visible screen: the note takes about two thirds of
## the width (never the whole of it) and the bust stands beside it.
func fit(viewport: Vector2, scale_factor: float) -> void:
	var gutter := 24.0 / scale_factor
	_bust.custom_minimum_size = BUST_SIZE / scale_factor
	var width := minf(viewport.x * NOTE_SHARE, NOTE_WIDTH / scale_factor)
	width = minf(width, viewport.x - _bust.custom_minimum_size.x - gutter * 2.0)
	_plaque.custom_minimum_size = Vector2(width, 0)
	var height := maxf(_plaque.get_combined_minimum_size().y, 150.0 / scale_factor)
	_plaque.custom_minimum_size.y = height
	_dock.anchor_left = 0.0
	_dock.anchor_right = 1.0
	_dock.anchor_top = 1.0
	_dock.anchor_bottom = 1.0
	_dock.offset_left = gutter
	_dock.offset_right = -gutter
	_dock.offset_top = -maxf(height, _bust.custom_minimum_size.y) - 18.0 / scale_factor
	_dock.offset_bottom = -18.0 / scale_factor

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
		# The bust bobs while its line is still being spoken.
		var bob := 0.0 if reduced_motion or not is_revealing() else -absf(sin(_clock * 13.0)) * 4.0
		if _bust.bob != bob:
			_bust.bob = bob
			_bust.queue_redraw()

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

## The speaker's upper body cut from their authored front frame, like a photo
## taped beside the note. The pose picks the expression; mirrored on the right.
class Bust extends Control:
	const Library = preload("res://game/world/character_animation_library.gd")
	const ACTORS := {"小角": "imp", "主角": "traveller", "票票": "ticket", "阿浪": "announcer"}
	## Share of the figure's height kept: head and shoulders down to the waist.
	const CROP := 0.56
	static var _library: RefCounted
	static var _used: Dictionary = {}
	var speaker := ""
	var texture: Texture2D
	var mirrored := false
	var bob := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _library == null: _library = Library.new()

	func show_speaker(who: String, pose: String) -> void:
		speaker = who
		texture = _frame(ACTORS.get(who, ""), pose)
		if texture == null and pose != "idle": texture = _frame(ACTORS.get(who, ""), "idle")
		queue_redraw()

	## The middle frame of an action holds its clearest expression.
	static func _frame(actor: String, pose: String) -> Texture2D:
		if actor.is_empty(): return null
		var frames: Array = _library.get_sequence(actor, pose, "front").get("frames", [])
		if frames.is_empty(): return null
		var frame: Variant = frames[int(frames.size() * 0.5) if pose != "idle" else 0]
		return frame.get("texture") if frame is Dictionary and frame.get("texture") is Texture2D else null

	static func _figure(texture: Texture2D) -> Rect2:
		if not _used.has(texture):
			var image := texture.get_image()
			_used[texture] = Rect2(image.get_used_rect()) if image != null and not image.is_empty() else Rect2(Vector2.ZERO, texture.get_size())
		return _used[texture]

	func _draw() -> void:
		var inner := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		if texture == null:
			draw_circle(inner.get_center(), minf(inner.size.x, inner.size.y) * 0.32, Color("#e8b990"))
			draw_string(ThemeDB.fallback_font, inner.get_center() + Vector2(-11, 8), speaker.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#12303b"))
			return
		var figure := _figure(texture)
		var source := Rect2(figure.position, Vector2(figure.size.x, figure.size.y * CROP))
		var scale_factor := minf(inner.size.x / source.size.x, inner.size.y / source.size.y) * 1.08
		var drawn := source.size * scale_factor
		# Waist sits on the photo's bottom edge; the head peeks a little above it.
		var at := Vector2(inner.get_center().x - drawn.x * 0.5, inner.end.y - drawn.y + bob)
		if mirrored:
			draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(texture, Rect2(at, drawn), source)
		draw_set_transform(Vector2.ZERO)
