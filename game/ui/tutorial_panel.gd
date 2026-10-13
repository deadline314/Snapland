extends Control
class_name TutorialPanel
## Reusable, text-first tutorial card. The owner handles pauses and game transitions.

signal step_changed(target_id: String, zero_based_step: int, step_count: int)
signal skip_requested(target_id: String)
signal practice_requested(target_id: String)
signal start_requested(target_id: String)
signal replay_requested(target_id: String)
signal close_requested()

const Paper = preload("res://game/ui/paper_ui.gd")
const CatalogScript = preload("res://game/ui/tutorial_catalog.gd")
const DIM_COLOR := Color(0.04, 0.10, 0.14, 0.74)

# A ScrollContainer normally reports the entire document's height as its own
# minimum, which makes a long lesson force the enclosing card off screen. The
# viewport has an explicit minimum and remains scrollable internally.
class TutorialCopyScroll extends ScrollContainer:
	func _get_minimum_size() -> Vector2:
		return custom_minimum_size
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventPanGesture or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]):
			accept_event()
			return

class TutorialHeader extends HBoxContainer:
	func _get_minimum_size() -> Vector2:
		return custom_minimum_size

var catalog: RefCounted
var target_id := ""
var current_step := 0
var _lesson: Dictionary = {}
var _missing_images: Dictionary = {}
var _step_counter: Label
var _title_label: Label
var _step_title: Label
var _image: TextureRect
var _image_placeholder: Label
var _image_alt: Label
var _text_scroll: ScrollContainer
var _text_panel: VBoxContainer
var _goal_label: Label
var _input_label: Label
var _success_label: Label
var _ordinary_label: Label
var _bonus_label: Label
var _result_heading: Label
var _ordinary_section: VBoxContainer
var _bonus_section: VBoxContainer
var _copy_pages: Array[Control] = []
var _copy_sections: Array[Control] = []
var _copy_pack_queued := false
var _copy_page := 0
var _copy_page_controls: HBoxContainer
var _copy_page_label: Label
var _previous_button: Button
var _next_button: Button
var _replay_button: Button
var _practice_button: Button
var _skip_button: Button
var _start_button: Button
var _close_button: Button
var _card: PanelContainer
var _margin: MarginContainer
var _column: VBoxContainer
var _header: HBoxContainer
var _content: BoxContainer
var _reading_row: HBoxContainer
var _copy_document: VBoxContainer
var _zoom_caption: Label
var _image_column: VBoxContainer
var _aspect: AspectRatioContainer
var _footer: Control
var _desktop_footer: HFlowContainer
var _compact_footer: VBoxContainer
var _compact_navigation: HFlowContainer
var _compact_actions: HFlowContainer
var _footer_buttons: Array[Button] = []
var _previous_focus: WeakRef
var _layout_queued := false
var _layout_scale := 1.0
var _screenshot_zoom_button: Button
var _screenshot_zoom: Control
var _zoom_image: TextureRect
var _zoom_back: Button
var _zoom_previous_focus: WeakRef

func _init() -> void:
	catalog = CatalogScript.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	theme = Paper.theme()
	_build_ui()
	visible = false
	get_viewport().size_changed.connect(_queue_responsive_layout)
	call_deferred("_apply_responsive_layout")

func open_tutorial(id: String) -> bool:
	if not is_node_ready():
		await ready
	var loaded: Dictionary = catalog.get_lesson(id)
	if loaded.is_empty():
		push_warning("TutorialPanel: cannot open unknown or invalid lesson '%s'." % id)
		return false
	if not visible:
		_remember_previous_focus()
	target_id = id
	_lesson = loaded
	current_step = 0
	visible = true
	_render_step()
	_skip_button.grab_focus()
	step_changed.emit(target_id, current_step, _lesson.steps.size())
	return true

func dismiss() -> void:
	_close_screenshot_zoom(false)
	if not visible and _previous_focus == null:
		return
	visible = false
	_restore_previous_focus()

func _remember_previous_focus() -> void:
	_previous_focus = null
	if get_viewport() == null:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or is_ancestor_of(focus_owner) or not focus_owner.is_inside_tree() or not focus_owner.is_visible_in_tree():
		return
	if focus_owner is Control and (focus_owner as Control).focus_mode != Control.FOCUS_NONE:
		_previous_focus = weakref(focus_owner)

func _restore_previous_focus() -> void:
	if _previous_focus == null:
		return
	var focus_ref := _previous_focus
	_previous_focus = null
	var previous := focus_ref.get_ref() as Control
	if previous == null or not is_instance_valid(previous) or not previous.is_inside_tree() or not previous.is_visible_in_tree() or previous.focus_mode == Control.FOCUS_NONE:
		return
	if previous is BaseButton and (previous as BaseButton).disabled:
		return
	previous.grab_focus()

func _queue_responsive_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout(scale_override: float = -1.0) -> void:
	_layout_queued = false
	if _card == null or get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := scale_override if scale_override > 0.0 else (1.0 if DisplayServer.get_name() == "headless" else Paper.physical_scale(self))
	_layout_scale = scale_factor
	var physical_width := viewport_size.x * scale_factor
	var compact := physical_width < 960.0 or viewport_size.x < 1120.0
	var card_width := minf(1120.0, maxf(320.0, viewport_size.x - 32.0))
	# Compact controls retain physical type and hit-target sizes, so their
	# logical height grows as the window scale shrinks. Use the available
	# expanded viewport height instead of capping a 600px window at 412px.
	var card_height := maxf(320.0, viewport_size.y - 32.0) if compact else minf(660.0, maxf(320.0, viewport_size.y - 32.0))
	_card.offset_left = -card_width * 0.5
	_card.offset_right = card_width * 0.5
	_card.offset_top = -card_height * 0.5
	_card.offset_bottom = card_height * 0.5
	_card.custom_minimum_size = Vector2(card_width, card_height)
	_margin.add_theme_constant_override("margin_left", 12 if compact else 24)
	_margin.add_theme_constant_override("margin_right", 12 if compact else 24)
	_margin.add_theme_constant_override("margin_top", 10 if compact else 18)
	_margin.add_theme_constant_override("margin_bottom", 10 if compact else 18)
	_column.add_theme_constant_override("separation", 8 if compact else 14)
	_header.custom_minimum_size.y = 44.0 / scale_factor if compact else 44.0
	_content.vertical = compact
	_content.add_theme_constant_override("separation", 0)
	_reading_row.add_theme_constant_override("separation",12 if compact else 24)
	_image_column.size_flags_stretch_ratio=0.8 if compact else 1.2
	_text_panel.size_flags_stretch_ratio=1.2 if compact else 1.0
	_image_column.custom_minimum_size.x = 0.0 if compact else 430.0
	_image_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_scroll.custom_minimum_size = Vector2(0, 80.0/scale_factor) if compact else Vector2(450, 0)
	_text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_panel.add_theme_constant_override("separation",2 if compact else 6)
	_footer = _compact_footer if compact else _desktop_footer
	var focus_owner := get_viewport().gui_get_focus_owner()
	var focused_footer_button := focus_owner as Button if focus_owner is Button and _footer_buttons.has(focus_owner) else null
	_desktop_footer.visible = not compact
	_compact_footer.visible = compact
	_configure_footer(compact, focused_footer_button)
	_aspect.custom_minimum_size = Vector2.ZERO
	_aspect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_aspect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_image_alt.autowrap_mode=TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
	_image_alt.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS if compact else TextServer.OVERRUN_NO_TRIMMING
	Paper.adapt_menu(self, scale_factor)
	_apply_readable_physical_fonts(self, scale_factor)
	# Paper adapts ScrollContainers from their initial desktop minimum (zero).
	# Apply this responsive copy budget afterwards so repeated reflows cannot
	# collapse all tutorial instructions into a zero-height scroll viewport.
	_text_scroll.custom_minimum_size = Vector2(0, 80.0/scale_factor) if compact else Vector2(450, 0)
	_layout_screenshot_zoom(scale_factor)
	call_deferred("_size_copy_pages")
	call_deferred("_fit_reading_image")

func _fit_reading_image() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_aspect): return
	var captions: float=(_image_column.get_child(0) as Control).get_combined_minimum_size().y+_image_alt.get_combined_minimum_size().y+2.0*_image_column.get_theme_constant("separation")
	var height := maxf(44.0/_layout_scale,_image_column.size.y-captions)
	var width := minf(_image_column.size.x,height*16.0/9.0)
	_aspect.custom_minimum_size=Vector2(width,width*9.0/16.0)

func _size_copy_pages() -> void:
	if not is_instance_valid(_text_scroll) or _text_scroll.size.y<=0.0 or _copy_pack_queued: return
	_copy_pack_queued=true
	call_deferred("_pack_copy_sections")

func _pack_copy_sections() -> void:
	_copy_pack_queued=false
	if not is_instance_valid(_text_scroll) or _copy_sections.is_empty(): return
	var capacity := floorf(_text_scroll.size.y)
	var width := _text_scroll.size.x
	if capacity<=0 or width<=0: return
	var wanted_section := 0
	if _copy_page<_copy_pages.size():
		var old_indices: Array=_copy_pages[_copy_page].get_meta("semantic_indices",[])
		if not old_indices.is_empty(): wanted_section=int(old_indices[0])
	for section in _copy_sections:
		section.custom_minimum_size.y=0
		for label in section.get_children():
			if label is Label:
				var font: Font=label.get_theme_font("font")
				var point_size: int=label.get_theme_font_size("font_size")
				var measured := font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,width,point_size,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE)
				label.custom_minimum_size.y=ceilf(maxf(font.get_height(point_size),measured.y))
				label.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
		section.get_parent().remove_child(section)
	for group in _copy_pages:
		_copy_document.remove_child(group)
		group.queue_free()
	_copy_pages.clear()
	var used := 0.0
	var group: VBoxContainer
	for index in range(_copy_sections.size()):
		var section := _copy_sections[index]
		var height := section.get_combined_minimum_size().y
		if group==null or used+6.0+height>capacity:
			group=VBoxContainer.new()
			group.name="TutorialCopyGroup%d"%_copy_pages.size()
			group.add_theme_constant_override("separation",6)
			group.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			group.custom_minimum_size.y=capacity
			group.set_meta("semantic_indices",[])
			_copy_document.add_child(group)
			_copy_pages.append(group)
			used=0.0
		group.add_child(section)
		var indices: Array=group.get_meta("semantic_indices")
		indices.append(index)
		group.set_meta("semantic_indices",indices)
		used+=height+(6.0 if indices.size()>1 else 0.0)
	for index in range(_copy_pages.size()):
		var indices: Array=_copy_pages[index].get_meta("semantic_indices")
		if indices.has(wanted_section):
			_set_copy_page(index)
			break

func _open_screenshot_zoom() -> bool:
	if _image.texture == null or not visible:
		return false
	if _screenshot_zoom.visible:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	_zoom_previous_focus = weakref(focused) if focused != null else null
	_zoom_image.texture = _image.texture
	_zoom_image.tooltip_text = _image.tooltip_text
	_screenshot_zoom.visible = true
	_zoom_caption.text=_image_alt.text
	_layout_screenshot_zoom(_layout_scale)
	_zoom_back.grab_focus()
	return true

func _close_screenshot_zoom(restore_focus: bool = true) -> void:
	if _screenshot_zoom == null or not _screenshot_zoom.visible:
		return
	_screenshot_zoom.visible = false
	_zoom_image.texture = null
	var previous := _zoom_previous_focus.get_ref() as Control if _zoom_previous_focus != null else null
	_zoom_previous_focus = null
	if restore_focus and previous != null and is_instance_valid(previous) and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE:
		previous.grab_focus()

func _layout_screenshot_zoom(scale_factor: float) -> void:
	if _screenshot_zoom == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var inset := 12.0 / scale_factor
	var back_height := maxf(_zoom_back.get_combined_minimum_size().y, 44.0 / scale_factor)
	_zoom_caption.size=Vector2(viewport_size.x-2.0*inset,1)
	var caption_font := _zoom_caption.get_theme_font("font")
	var caption_size := _zoom_caption.get_theme_font_size("font_size")
	var caption_lines := maxi(1,ceili(float(_zoom_caption.text.length())*caption_size/maxf(1.0,_zoom_caption.size.x)))
	var caption_height := caption_font.get_height(caption_size)*caption_lines
	_zoom_caption.position=Vector2(inset,viewport_size.y-2.0*inset-back_height-caption_height)
	_zoom_caption.size.y=caption_height
	var available_height := viewport_size.y - 4.0 * inset - back_height-caption_height
	var image_width := minf(viewport_size.x - 2.0 * inset, available_height * 16.0 / 9.0)
	_zoom_image.position = Vector2((viewport_size.x - image_width) * 0.5, inset)
	_zoom_image.size = Vector2(image_width, image_width * 9.0 / 16.0)
	var back_width := maxf(180.0 / scale_factor, _zoom_back.get_combined_minimum_size().x)
	_zoom_back.position = Vector2((viewport_size.x - back_width) * 0.5, viewport_size.y - inset - back_height)
	_zoom_back.size = Vector2(back_width, back_height)

func _configure_footer(compact: bool, focused_footer_button: Button = null) -> void:
	for index in range(_footer_buttons.size()):
		var button := _footer_buttons[index]
		var destination: Node = _compact_navigation if index < 3 else _compact_actions if compact else _desktop_footer
		if compact:
			destination = _compact_navigation if index < 3 else _compact_actions
		else:
			destination = _desktop_footer
		if button.get_parent() == destination:
			continue
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
		destination.add_child(button)
	# Reparenting a focused Control clears GUI focus. Responsive layout can run
	# immediately after open_tutorial() has focused Skip, so restore it after all
	# footer children have reached their new containers.
	if focused_footer_button != null and is_instance_valid(focused_footer_button) and focused_footer_button.is_visible_in_tree() and not focused_footer_button.disabled:
		focused_footer_button.grab_focus()

func _apply_readable_physical_fonts(node: Node, scale_factor: float) -> void:
	if node is Label or node is Button:
		var control := node as Control
		if not control.has_meta("tutorial_base_font"):
			control.set_meta("tutorial_base_font", control.get_theme_font_size("font_size"))
		var base_font: int = control.get_meta("tutorial_base_font")
		control.add_theme_font_size_override("font_size", maxi(control.get_theme_font_size("font_size"), ceili(18.0*Paper.text_scale() / scale_factor)))
	for child in node.get_children():
		_apply_readable_physical_fonts(child, scale_factor)

func current_step_data() -> Dictionary:
	var steps: Array = _lesson.get("steps", [])
	if steps.is_empty() or current_step < 0 or current_step >= steps.size(): return {}
	return (steps[current_step] as Dictionary).duplicate(true)

func previous_step() -> void:
	_set_step(current_step - 1)

func next_step() -> void:
	_set_step(current_step + 1)

func replay() -> void:
	if _lesson.is_empty(): return
	current_step = 0
	_render_step()
	replay_requested.emit(target_id)
	step_changed.emit(target_id, current_step, _lesson.steps.size())

func request_skip() -> void:
	if not _lesson.is_empty(): skip_requested.emit(target_id)

func request_practice() -> void:
	if not _lesson.is_empty(): practice_requested.emit(target_id)

func request_start() -> void:
	if not _lesson.is_empty(): start_requested.emit(target_id)

func request_close() -> void:
	if not _lesson.is_empty(): close_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	var key := (event as InputEventKey).keycode
	if _screenshot_zoom.visible:
		if key == KEY_ESCAPE:
			_close_screenshot_zoom()
			get_viewport().set_input_as_handled()
		elif key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_TAB]:
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_ESCAPE: request_close()
		KEY_LEFT: previous_step()
		KEY_RIGHT: next_step()
		KEY_UP: return
		KEY_DOWN: return
		_: return
	if get_viewport() != null:
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_card = PanelContainer.new()
	var card := _card
	card.name = "TutorialCard"
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -560
	card.offset_top = -330
	card.offset_right = 560
	card.offset_bottom = 330
	card.custom_minimum_size = Vector2(900, 560)
	card.add_theme_stylebox_override("panel", Paper.plaque())
	add_child(card)
	_margin = MarginContainer.new()
	var margin := _margin
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	_column = VBoxContainer.new()
	var column := _column
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := TutorialHeader.new()
	_header=header
	_header.custom_minimum_size = Vector2(0, 44)
	column.add_child(header)
	_title_label = Paper.label("教程", 24, Paper.INK)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(_title_label)
	_step_counter = Paper.label("", 18, Paper.TEAL)
	_step_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_step_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_step_counter)
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Paper.GOLD)
	column.add_child(separator)
	_content = BoxContainer.new()
	_content.vertical = false
	var content := _content
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	column.add_child(content)
	_reading_row=HBoxContainer.new()
	_reading_row.name="TutorialReadingRow"
	_reading_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_reading_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(_reading_row)
	_image_column = VBoxContainer.new()
	var image_column := _image_column
	image_column.custom_minimum_size.x = 430
	image_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reading_row.add_child(image_column)
	image_column.add_child(Paper.label("遊戲畫面", 18, Paper.GOLD))
	_aspect = AspectRatioContainer.new()
	var aspect := _aspect
	aspect.ratio = 16.0 / 9.0
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_column.add_child(aspect)
	_image_placeholder = Paper.label("正式遊戲截圖尚未提供", 18, Paper.INK)
	_image_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_image_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_image_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_image_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image_placeholder.add_theme_stylebox_override("normal", Paper.plaque(Paper.DEEP))
	aspect.add_child(_image_placeholder)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(_image)
	_screenshot_zoom_button = Button.new()
	_screenshot_zoom_button.name = "ScreenshotZoom"
	_screenshot_zoom_button.tooltip_text = "放大遊戲畫面"
	_screenshot_zoom_button.focus_mode = Control.FOCUS_ALL
	_screenshot_zoom_button.custom_minimum_size = Vector2(44, 44)
	for state in ["normal", "hover", "pressed", "disabled"]:
		_screenshot_zoom_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var preview_focus := StyleBoxFlat.new()
	preview_focus.bg_color = Color.TRANSPARENT
	preview_focus.border_color = Paper.GOLD
	preview_focus.set_border_width_all(3)
	_screenshot_zoom_button.add_theme_stylebox_override("focus", preview_focus)
	_screenshot_zoom_button.pressed.connect(_open_screenshot_zoom)
	aspect.add_child(_screenshot_zoom_button)
	_image_alt = Paper.label("", 16, Paper.TEAL)
	image_column.add_child(_image_alt)
	_text_scroll = TutorialCopyScroll.new()
	_text_scroll.custom_minimum_size.x = 450
	_text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_text_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_text_scroll.focus_mode = Control.FOCUS_ALL
	_text_scroll.gui_input.connect(_on_text_scroll_gui_input)
	_text_panel=VBoxContainer.new()
	_text_panel.name="TutorialTextPanel"
	_text_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_text_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_text_panel.add_theme_constant_override("separation",6)
	_reading_row.add_child(_text_panel)
	_text_panel.add_child(_text_scroll)
	_copy_document=VBoxContainer.new()
	var text_column := _copy_document
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 0)
	_text_scroll.add_child(text_column)
	_text_scroll.resized.connect(_size_copy_pages)
	_step_title = Paper.label("", 22, Paper.INK)
	_text_panel.add_child(_step_title)
	_text_panel.move_child(_step_title,0)
	_goal_label = _section_label(text_column, "本步目標", Paper.INK)
	_input_label = _section_label(text_column, "操作", Paper.TEAL)
	_success_label = _section_label(text_column, "成功條件", Paper.GOLD.darkened(0.25))
	_ordinary_section=VBoxContainer.new()
	_ordinary_section.name="TutorialOrdinarySection"
	_ordinary_section.add_theme_constant_override("separation",3)
	_result_heading = Paper.label("本局結果", 18, Paper.GOLD)
	_ordinary_section.add_child(_result_heading)
	_ordinary_label = Paper.label("", 16, Paper.INK)
	_ordinary_section.add_child(_ordinary_label)
	text_column.add_child(_ordinary_section)
	_bonus_section=VBoxContainer.new()
	_bonus_section.name="TutorialBonusSection"
	_bonus_section.add_theme_constant_override("separation",3)
	var bonus_heading := Paper.label("額外挑戰",18,Paper.GOLD)
	_bonus_section.add_child(bonus_heading)
	_bonus_label = Paper.label("", 16, Paper.TEAL)
	_bonus_section.add_child(_bonus_label)
	text_column.add_child(_bonus_section)
	_copy_sections=[_goal_label.get_parent() as Control,_input_label.get_parent() as Control,_success_label.get_parent() as Control,_ordinary_section,_bonus_section]
	_copy_page_controls=HBoxContainer.new()
	_copy_page_controls.name="TutorialCopyPageControls"
	_copy_page_controls.alignment=BoxContainer.ALIGNMENT_CENTER
	var copy_previous := Paper.button("‹",func(): _set_copy_page(_copy_page-1),_copy_page_controls)
	copy_previous.name="TutorialCopyPrevious"
	var copy_next := Paper.button("›",func(): _set_copy_page(_copy_page+1),_copy_page_controls)
	copy_next.name="TutorialCopyNext"
	_copy_page_label=Paper.label("說明 1 / 2",15,Paper.INK)
	_copy_page_label.name="TutorialCopyPageLabel"
	_copy_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_copy_page_controls.add_child(_copy_page_label)
	_copy_page_controls.move_child(_copy_page_label,1)
	_title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_step_counter.size_flags_horizontal=Control.SIZE_SHRINK_END
	_text_panel.add_child(_copy_page_controls)
	_text_panel.move_child(_copy_page_controls, 1)
	var footer_rule := HSeparator.new()
	footer_rule.add_theme_color_override("separator", Paper.GOLD)
	column.add_child(footer_rule)
	_desktop_footer = HFlowContainer.new()
	_desktop_footer.alignment = FlowContainer.ALIGNMENT_CENTER
	_desktop_footer.add_theme_constant_override("h_separation", 10)
	_desktop_footer.add_theme_constant_override("v_separation", 8)
	column.add_child(_desktop_footer)
	_compact_footer = VBoxContainer.new()
	_compact_footer.add_theme_constant_override("separation", 6)
	_compact_footer.visible = false
	_compact_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_compact_footer)
	_compact_navigation = HFlowContainer.new()
	_compact_navigation.alignment = FlowContainer.ALIGNMENT_CENTER
	_compact_navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_navigation.add_theme_constant_override("h_separation", 8)
	_compact_footer.add_child(_compact_navigation)
	_compact_actions = HFlowContainer.new()
	_compact_actions.alignment = FlowContainer.ALIGNMENT_CENTER
	_compact_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_actions.add_theme_constant_override("h_separation", 8)
	_compact_footer.add_child(_compact_actions)
	_previous_button = _button("上一步", previous_step, _desktop_footer, 92)
	_next_button = _button("下一步", next_step, _desktop_footer, 92)
	_replay_button = _button("重看本課", replay, _desktop_footer, 112)
	_practice_button = _button("練習操作", request_practice, _desktop_footer, 112)
	_skip_button = _button("略過", request_skip, _desktop_footer, 80)
	_start_button = _button("開始挑戰", request_start, _desktop_footer, 112)
	_close_button = _button("關閉", request_close, _desktop_footer, 80)
	_footer_buttons = [_previous_button,_next_button,_replay_button,_practice_button,_skip_button,_start_button,_close_button]
	_footer = _desktop_footer
	_screenshot_zoom = Control.new()
	_screenshot_zoom.name = "ScreenshotZoomOverlay"
	_screenshot_zoom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screenshot_zoom.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screenshot_zoom)
	var zoom_dim := ColorRect.new()
	zoom_dim.color = Color(0.04, 0.10, 0.14, 0.96)
	zoom_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zoom_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_screenshot_zoom.add_child(zoom_dim)
	_zoom_image = TextureRect.new()
	_zoom_image.name = "ZoomedScreenshot"
	_zoom_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zoom_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_zoom_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screenshot_zoom.add_child(_zoom_image)
	_zoom_caption=Paper.label("",16,Paper.TEAL)
	_zoom_caption.name="ZoomScreenshotCaption"
	_screenshot_zoom.add_child(_zoom_caption)
	_zoom_back = Paper.button("返回教學", _close_screenshot_zoom, _screenshot_zoom)
	_zoom_back.name = "ScreenshotZoomBack"
	_zoom_back.custom_minimum_size = Vector2(180, 44)
	_zoom_back.focus_mode = Control.FOCUS_ALL
	_zoom_back.focus_next = _zoom_back.get_path()
	_zoom_back.focus_previous = _zoom_back.get_path()
	_screenshot_zoom.visible = false

func _section_label(parent: Control, heading: String, color: Color) -> Label:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 3)
	parent.add_child(section)
	var heading_label := Paper.label(heading, 18, color)
	section.add_child(heading_label)
	var label := Paper.label("", 16, Paper.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Control, width: float) -> Button:
	var button := Paper.button(text, callback, parent)
	button.custom_minimum_size = Vector2(width, 48)
	button.focus_mode = Control.FOCUS_ALL
	return button

func _set_step(index: int) -> void:
	var steps: Array = _lesson.get("steps", [])
	if steps.is_empty(): return
	var next_index := clampi(index, 0, steps.size() - 1)
	if next_index == current_step: return
	current_step = next_index
	_render_step()
	step_changed.emit(target_id, current_step, steps.size())

func _render_step() -> void:
	var steps: Array = _lesson.get("steps", [])
	if steps.is_empty() or current_step >= steps.size(): return
	var step: Dictionary = steps[current_step]
	_title_label.text = str(_lesson.get("title", "教程"))
	_step_counter.text = "步驟 %d / %d" % [current_step + 1, steps.size()]
	_step_title.text = str(step.get("title", ""))
	_goal_label.text = str(step.get("goal", ""))
	_input_label.text = str(step.get("input", ""))
	_success_label.text = str(step.get("success", ""))
	_ordinary_label.text = str(_lesson.get("ordinary", ""))
	_bonus_label.text = str(_lesson.get("bonus", ""))
	_copy_page=0
	_size_copy_pages()
	_image.texture = null
	_image.tooltip_text = str(step.get("alt", ""))
	_image_alt.text = str(step.get("alt", ""))
	_image_alt.tooltip_text=_image_alt.text
	var image_path := str(step.get("image", ""))
	if ResourceLoader.exists(image_path):
		_image.texture = ResourceLoader.load(image_path) as Texture2D
	if _image.texture == null:
		if not _missing_images.has(image_path):
			_missing_images[image_path] = true
			push_warning("TutorialPanel: screenshot missing or unreadable for %s step %d: %s" % [target_id, current_step + 1, image_path])
		_image_placeholder.visible = true
		_image_placeholder.text = "教學圖片暫時無法載入，請參考右側操作說明。"
	else:
		_image_placeholder.visible = false
	_image.visible = _image.texture != null
	_screenshot_zoom_button.disabled = _image.texture == null
	_previous_button.disabled = current_step <= 0
	_next_button.disabled = current_step >= steps.size() - 1
	_text_scroll.scroll_vertical = 0

func _set_copy_page(page: int) -> void:
	if _copy_pages.is_empty(): return
	_copy_page=clampi(page,0,_copy_pages.size()-1)
	# Keep every lesson section in the real viewport content. Pages are a
	# programmatic view onto that content; the scrollbar stays hidden and only
	# page navigation changes its position.
	for section in _copy_sections: section.visible=true
	_copy_page_label.text="說明 %d / %d" % [_copy_page+1,_copy_pages.size()]
	_copy_page_controls.get_node("TutorialCopyPrevious").set("disabled",_copy_page==0)
	_copy_page_controls.get_node("TutorialCopyNext").set("disabled",_copy_page>=_copy_pages.size()-1)
	call_deferred("_ensure_copy_page_visible")

func _ensure_copy_page_visible() -> void:
	# The scroll range and container positions settle after shaping/repacking.
	# Set the actual document offset, rather than adjusting a stale global rect.
	await get_tree().process_frame
	if not is_instance_valid(_text_scroll) or _copy_page<0 or _copy_page>=_copy_pages.size(): return
	_text_scroll.scroll_vertical=roundi(_copy_pages[_copy_page].position.y)

func _on_text_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_text_scroll.accept_event()
	elif event is InputEventPanGesture:
		_text_scroll.accept_event()
