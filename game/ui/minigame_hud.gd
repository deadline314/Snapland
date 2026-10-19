extends Control
class_name MinigameHUD

signal pause_requested
signal resume_requested
signal help_requested
signal details_requested
signal practice_requested
signal retry_requested
signal leave_requested

const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("#f1efdc")
const PAPER := Color("#f1efdc")
const MINT := Color("#91e8c9")
const GOLD := Color("#ffcf72")
const SHADOW_INK := Color("#071923", 0.48)
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Paper := preload("res://game/ui/paper_ui.gd")

var _details: Dictionary = {}
var _header: PanelContainer
var _status_rail: PanelContainer
var _title: Label
var _objective: Label
var _progress: Label
var _score_label: Label
var _score: Label
var _time_label: Label
var _time: Label
var _badge: Label
var _feedback: PanelContainer
var _feedback_label: Label
var _pause_layer: ColorRect
var _pause_panel: PanelContainer
var _pause_title: Label
var _pause_status: Label
var _score_layer: ColorRect
var _score_panel: PanelContainer
var _score_rows: VBoxContainer
var _confirm_layer: ColorRect
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _confirm_kind := ""
var _result_layer: ColorRect
var _result_panel: PanelContainer
var _result_title: Label
var _result_status: Label
var _layout_scale := 1.0
var _effective_scale := 1.0
var _layout_refresh_pending := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_header()
	_build_feedback()
	_build_pause_layer()
	_build_score_layer()
	_build_confirm_layer()
	_build_result_layer()
	resized.connect(_queue_layout_refresh)
	get_viewport().size_changed.connect(_queue_layout_refresh)
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_queue_layout_refresh):
		window.size_changed.connect(_queue_layout_refresh)
	var parent_control := get_parent_control()
	if parent_control != null:
		parent_control.resized.connect(_queue_layout_refresh)
	_layout()
	set_state({})

func set_state(state: Dictionary) -> void:
	if _title == null:
		return
	_title.text = str(state.get("title", "小遊戲"))
	_objective.text = str(state.get("objective", "完成挑戰"))
	_objective.tooltip_text = _objective.text
	_title.tooltip_text = _objective.text
	_progress.text = str(state.get("progress_text", "準備中"))
	_progress.tooltip_text = _progress.text
	_score.text = "%04d" % int(state.get("score", 0))
	_time.text = str(state.get("time_text", "01:00"))
	var badge_text := ""
	if bool(state.get("assisted", false)):
		badge_text = "輔助"
	if bool(state.get("practice", false)):
		badge_text += "　" if not badge_text.is_empty() else ""
		badge_text += "練習・不收藏"
	_badge.text = badge_text
	_badge.visible = not badge_text.is_empty()
	var message := str(state.get("feedback_text", ""))
	_feedback.visible = not message.is_empty()
	_feedback_label.text = message
	var feedback_width := clampf(float(state.get("feedback_width", 540.0)), 230.0, 540.0)
	_feedback_label.custom_minimum_size.x = feedback_width - 30.0
	_feedback.size.x = feedback_width
	var feedback_color: Color = state.get("feedback_color", PAPER)
	if _feedback_label.get_theme_color("font_color") != feedback_color:
		_feedback_label.add_theme_color_override("font_color", feedback_color)
	_pause_status.text = "練習中" if bool(state.get("practice", false)) else "正式挑戰"
	# The game name is already visible in the corner header. Keeping this title
	# short prevents long localized names from forcing the centered dialog wider.
	_pause_title.text = "暫停"
	var ended := bool(state.get("ended", false))
	_result_layer.visible = ended
	if ended:
		var won := bool(state.get("won", false))
		var devil := bool(state.get("devil", false))
		_result_title.text = "挑戰完成" if won else "這次尚未完成"
		if bool(state.get("practice", false)):
			_result_status.text = "練習結果・不會收藏拍貼\n" + str(_details.get("label", "得分")) + "　" + str(state.get("score", 0))
		else:
			_result_status.text = ("惡魔拍貼達成" if devil else "普通拍貼達成" if won else "未達普通拍貼") + "\n" + str(_details.get("label", "得分")) + "　" + str(state.get("score", 0))
		_result_status.add_theme_color_override("font_color", MINT if won else PAPER)
	if bool(state.get("reduced_motion", false)):
		_feedback.modulate.a = 1.0
	else:
		_feedback.modulate.a = 1.0
	_layout()

func set_score_details(details: Dictionary) -> void:
	_details = details.duplicate(true)
	if _score_layer != null and _score_layer.visible:
		_render_score_rows()

func set_paused(value: bool) -> void:
	_pause_layer.visible = value
	if value:
		_pause_layer.move_to_front()
		call_deferred("_focus_resume_button")
	else:
		_pause_layer.hide()

func _focus_resume_button() -> void:
	var button := find_child("ResumeButton", true, false) as Button
	if button != null and _pause_layer.visible:
		button.grab_focus()

func open_score_details() -> void:
	_score_layer.visible = true
	_render_score_rows()
	_score_layer.move_to_front()

func close_score_details() -> void:
	_score_layer.hide()

func _build_header() -> void:
	_header = PanelContainer.new()
	_header.name = "MinigameHeader"
	_header.position = Vector2(24, 18)
	_header.size = Vector2(392, 84)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.add_theme_stylebox_override("panel", _ticket_style())
	add_child(_header)
	var title_col := VBoxContainer.new()
	title_col.name = "TitleAndProgress"
	title_col.add_theme_constant_override("separation", 2)
	_header.add_child(title_col)
	_title = _label("小遊戲", 24, INK)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_child(_title)
	# Preserve the full goal for assistive discovery without keeping its full
	# sentence over the active play space.
	_objective = _label("完成挑戰", 18, MINT)
	_objective.visible = false
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(_objective)
	var status_row := HBoxContainer.new()
	status_row.name = "ProgressAndBadges"
	status_row.add_theme_constant_override("separation", 7)
	title_col.add_child(status_row)
	_progress = _label("準備中", 16, GOLD)
	_progress.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_row.add_child(_progress)
	_badge = _label("", 16, MINT)
	_badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_badge.autowrap_mode = TextServer.AUTOWRAP_OFF

	_status_rail = PanelContainer.new()
	_status_rail.name = "MinigameStatusRail"
	_status_rail.position = Vector2(640, 18)
	_status_rail.size = Vector2(616, 84)
	_status_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	var rail_style := _panel_style(Color("#0c2938"), Color("#31596a"), 1.0, 0)
	rail_style.content_margin_top = 2
	rail_style.content_margin_bottom = 2
	rail_style.border_width_top = 1
	rail_style.border_width_bottom = 1
	_status_rail.add_theme_stylebox_override("panel", rail_style)
	add_child(_status_rail)
	var rail_content := VBoxContainer.new()
	rail_content.name = "StatusAndActions"
	rail_content.add_theme_constant_override("separation", 3)
	rail_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_rail.add_child(rail_content)
	var status_line := HBoxContainer.new()
	status_line.name = "ScoreAndTime"
	status_line.add_theme_constant_override("separation", 16)
	status_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_content.add_child(status_line)
	var score_col := HBoxContainer.new()
	score_col.name = "ScoreReadout"
	score_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_col.add_theme_constant_override("separation", 5)
	status_line.add_child(score_col)
	_score_label = _label("得分", 14, MINT)
	_score_label.name = "ScoreLabel"
	score_col.add_child(_score_label)
	_score = _label("0000", 19, GOLD)
	_score.custom_minimum_size.x = 54
	score_col.add_child(_score)
	var time_col := HBoxContainer.new()
	time_col.name = "TimeReadout"
	time_col.add_theme_constant_override("separation", 5)
	status_line.add_child(time_col)
	_time_label = _label("時間", 14, MINT)
	time_col.add_child(_time_label)
	_time = _label("01:00", 17, INK)
	time_col.add_child(_time)
	var actions := HBoxContainer.new()
	actions.name = "HUDActions"
	actions.add_theme_constant_override("separation", 7)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_content.add_child(actions)
	# The practice/assist record shares the actions line instead of competing
	# with progress for left-header width or adding a third header row.
	actions.add_child(_badge)
	var detail_button := _button("分數明細", 16)
	detail_button.name = "DetailsButton"
	detail_button.custom_minimum_size = Vector2(132, 44)
	detail_button.pressed.connect(func(): details_requested.emit(); open_score_details())
	actions.add_child(detail_button)
	var help_button := _button("教學", 15)
	help_button.name = "HelpButton"
	help_button.custom_minimum_size = Vector2(92, 44)
	help_button.tooltip_text = "開啟本遊戲完整教學"
	help_button.pressed.connect(func(): help_requested.emit())
	actions.add_child(help_button)
	var pause_button := _button("暫停", 15)
	pause_button.name = "PauseButton"
	pause_button.custom_minimum_size = Vector2(76, 44)
	pause_button.pressed.connect(func(): pause_requested.emit())
	actions.add_child(pause_button)

func _build_feedback() -> void:
	_feedback = PanelContainer.new()
	_feedback.name = "ContextFeedback"
	_feedback.size = Vector2(540, 48)
	_feedback.position = Vector2(34, 130)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.add_theme_stylebox_override("panel", _panel_style(Color("#17354b"), Color("#f3d39c"), 0.98, 1))
	_feedback_label = _label("", 18, PAPER)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.custom_minimum_size.x = 510
	_feedback.add_child(_feedback_label)
	_feedback.hide()
	add_child(_feedback)

func set_feedback_at(message: String, anchor: Vector2) -> void:
	_feedback_label.text = message
	_feedback.visible = not message.is_empty()
	_feedback.position = Vector2(clampf(anchor.x - _feedback.size.x * 0.5, 30, DESIGN_SIZE.x - _feedback.size.x - 30), clampf(anchor.y - 78, _feedback_top(), DESIGN_SIZE.y - _feedback.size.y - 82))

func _build_pause_layer() -> void:
	_pause_layer = _overlay("PauseOverlay")
	_pause_panel = _dialog_panel(_pause_layer, Vector2(420, 165), Vector2(440, 390))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_pause_panel.add_child(body)
	_pause_title = _label("暫停", 27, PAPER)
	body.add_child(_pause_title)
	_pause_status = _label("正式挑戰", 14, MINT)
	body.add_child(_pause_status)
	_add_action_button(body, "繼續遊玩", func(): resume_requested.emit()).name = "ResumeButton"
	_add_action_button(body, "查看教學", func(): help_requested.emit()).name = "HelpFromPauseButton"
	_add_action_button(body, "重新開始練習（不收藏）", func(): practice_requested.emit()).name = "PracticeButton"
	_add_action_button(body, "重新開始本局", _ask_retry).name = "RetryButton"
	_add_action_button(body, "離開小遊戲", _ask_leave).name = "LeaveButton"
	_pause_layer.hide()
	add_child(_pause_layer)

func _build_score_layer() -> void:
	_score_layer = _overlay("ScoreDetailsOverlay")
	_score_panel = _dialog_panel(_score_layer, Vector2(390, 170), Vector2(500, 380))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_score_panel.add_child(body)
	body.add_child(_label("本局分數怎麼來", 24, PAPER))
	_score_rows = VBoxContainer.new()
	_score_rows.add_theme_constant_override("separation", 7)
	body.add_child(_score_rows)
	_add_action_button(body, "返回遊戲", func(): close_score_details()).name = "ScoreDetailsBackButton"
	_score_layer.hide()
	add_child(_score_layer)

func _build_confirm_layer() -> void:
	_confirm_layer = _overlay("ConfirmOverlay")
	_confirm_panel = _dialog_panel(_confirm_layer, Vector2(430, 250), Vector2(420, 210))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_confirm_panel.add_child(body)
	_confirm_label = _label("", 19, PAPER)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_confirm_label)
	var confirm_button := _add_action_button(body, "確定", _confirm_action)
	confirm_button.name = "ConfirmAction"
	_add_action_button(body, "返回暫停選單", func(): _confirm_layer.hide(); _pause_layer.show())
	_confirm_layer.hide()
	add_child(_confirm_layer)

func _build_result_layer() -> void:
	_result_layer = _overlay("MinigameResultOverlay")
	_result_panel = _dialog_panel(_result_layer, Vector2(390, 235), Vector2(500, 250))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_result_panel.add_child(body)
	_result_title = _label("挑戰完成", 29, Color("#ffdb82"))
	body.add_child(_result_title)
	_result_status = _label("", 17, PAPER)
	body.add_child(_result_status)
	_add_action_button(body, "重新開始", _ask_retry)
	_add_action_button(body, "離開小遊戲", _ask_leave)
	_result_layer.hide()
	add_child(_result_layer)

func _render_score_rows() -> void:
	if _score_rows == null:
		return
	for child in _score_rows.get_children():
		child.queue_free()
	var rule_label := _label("計分規則：" + str(_details.get("rule", "依實際事件記分")), 15, MINT)
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_rows.add_child(rule_label)
	var rows: Array = _details.get("rows", [])
	for entry in rows:
		if not entry is Dictionary:
			continue
		var amount := int(entry.get("amount", 0))
		var count := int(entry.get("count", 0))
		var count_text := "　×%d" % count if count > 0 else ""
		var value := "　" + (("%+d" % amount) if amount < 0 else str(amount)) if not bool(entry.get("progress_only", false)) else "　不計分"
		_score_rows.add_child(_label(str(entry.get("label", "分數")) + count_text + value, 16, PAPER))
	if rows.is_empty():
		_score_rows.add_child(_label("尚無得分事件", 16, PAPER))
	_score_rows.add_child(_label("目前總分　%d" % int(_details.get("total", 0)), 20, GOLD))

func _overlay(node_name: String) -> ColorRect:
	var layer := ColorRect.new()
	layer.name = node_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.color = Color("#071521", 0.72)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	return layer

func _dialog_panel(parent: Control, at: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0c2938"), GOLD, 1.0, 0))
	parent.add_child(panel)
	return panel

func _add_action_button(parent: Control, text: String, action: Callable) -> Button:
	var button := _button(text, 18)
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font", FontProfiles.current_font())
	button.add_theme_font_size_override("font_size", font_size)
	button.set_meta("hud_base_font_size", font_size)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#b7c3c0"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#163d4d"), Color("#31596a"), 2, 0, Vector2.ZERO))
	button.add_theme_stylebox_override("hover", _button_style(Color("#205266"), MINT, 2, 0, Vector2.ZERO))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#102f40"), GOLD, 2, 0, Vector2.ZERO))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.add_theme_stylebox_override("disabled", _button_style(Color("#384b55"), Color("#697a7d"), 2, 0, Vector2.ZERO))
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FontProfiles.current_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("hud_base_font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _panel_style(background: Color, border: Color, alpha: float, elevation: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background, alpha)
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_bottom = 2
	style.set_corner_radius_all(0)
	style.shadow_color = SHADOW_INK
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _ticket_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c2938")
	style.border_color = Color("#31596a")
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(0)
	style.shadow_color = SHADOW_INK
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _button_style(background: Color, border: Color, bottom_edge: int, shadow_size: int, shadow_offset: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(0)
	style.shadow_color = SHADOW_INK
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(0)
	style.shadow_size = 0
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _ask_retry() -> void:
	_confirm_kind = "retry"
	_confirm_label.text = "重新開始會清除此局進度。要重新開始嗎？"
	_confirm_layer.show()
	_confirm_layer.move_to_front()

func _ask_leave() -> void:
	_confirm_kind = "leave"
	_confirm_label.text = "離開後會返回園區。確定離開嗎？"
	_confirm_layer.show()
	_confirm_layer.move_to_front()

func _confirm_action() -> void:
	_confirm_layer.hide()
	if _confirm_kind == "retry":
		retry_requested.emit()
	elif _confirm_kind == "leave":
		leave_requested.emit()
	_confirm_kind = ""

func _layout() -> void:
	# Session completion can detach this HUD before its final state update.
	# Keep the text/result state, but defer all viewport layout until mounted.
	if not is_inside_tree(): return
	var canvas_size := size
	var parent_control := get_parent_control()
	if parent_control != null:
		canvas_size = parent_control.size
	var fitted := minf(canvas_size.x / DESIGN_SIZE.x, canvas_size.y / DESIGN_SIZE.y)
	if fitted <= 0.0:
		return
	_layout_scale = fitted
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	scale = Vector2.ONE * fitted
	position = (canvas_size - DESIGN_SIZE * fitted) * 0.5
	size = DESIGN_SIZE
	_effective_scale = _effective_layout_scale(fitted)
	_fit_semantic_text_and_targets(_effective_scale)
	# Measure the font's actual shaped line after applying physical text scaling.
	# The compact two-line plates must remain shorter than a three-row catalogue.
	for label in [_title,_progress,_badge,_score_label,_score,_time_label,_time]:
		label.custom_minimum_size.y=ceilf(label.get_line_height(-1))
	for label in [_progress,_badge]:
		var font: Font = label.get_theme_font("font")
		label.custom_minimum_size.x=ceilf(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x)
	var header_minimum := _header.get_combined_minimum_size()
	var rail_minimum := _status_rail.get_combined_minimum_size()
	var panel_height := maxf(84.0,ceilf(maxf(header_minimum.y,rail_minimum.y)))
	_header.size=Vector2(maxf(392.0,ceilf(header_minimum.x)),panel_height)
	_status_rail.size=Vector2(maxf(616.0,ceilf(rail_minimum.x)),panel_height)
	_status_rail.position.x=DESIGN_SIZE.x-24.0-_status_rail.size.x
	_feedback.position.y=_feedback_top()

func _feedback_top() -> float:
	return maxf(130.0, _header.position.y + _header.size.y + 18.0)

func _queue_layout_refresh() -> void:
	if not is_inside_tree(): return
	if _layout_refresh_pending:
		return
	_layout_refresh_pending = true
	_refresh_layout_after_resize()

func _refresh_layout_after_resize() -> void:
	# A window resize signal can arrive before the viewport's final transform is
	# updated. Re-read it after two process-frame boundaries so a restored window
	# does not retain compact-scale text and plate heights.
	var tree := get_tree()
	if tree==null:
		_layout_refresh_pending=false
		return
	await tree.process_frame
	await tree.process_frame
	if is_inside_tree():
		_layout()
		# Cache the tree across awaits: detaching clears Node.get_tree().
		await tree.process_frame
		if is_inside_tree():
			_layout()
			await tree.process_frame
			if is_inside_tree():
				_layout()
	_layout_refresh_pending = false

func _effective_layout_scale(fitted: float) -> float:
	var layout_scale := maxf(fitted, 0.01)
	var parent_control := get_parent_control()
	if parent_control != null:
		var parent_scale := parent_control.get_global_transform().get_scale()
		layout_scale *= minf(absf(parent_scale.x), absf(parent_scale.y))
	var viewport := get_viewport()
	if viewport==null: return maxf(layout_scale,0.01)
	var viewport_scale := viewport.get_final_transform().get_scale()
	# Headless SceneTree tests may use Godot's 64×64 default root even when the
	# HUD's logical canvas is 1280×720. That tiny synthetic transform is not a
	# display scale; treating it as one makes every semantic font enormous.
	if minf(absf(viewport_scale.x), absf(viewport_scale.y)) < 0.1:
		viewport_scale = Vector2.ONE
	layout_scale *= minf(absf(viewport_scale.x), absf(viewport_scale.y))
	return maxf(layout_scale, 0.01)

func _fit_semantic_text_and_targets(fitted: float) -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if child is Button:
				var button := child as Button
				if not button.has_meta("hud_design_minimum_size"):
					button.set_meta("hud_design_minimum_size", button.custom_minimum_size)
				var base_size: Vector2 = button.get_meta("hud_design_minimum_size")
				button.custom_minimum_size = Vector2(maxf(base_size.x, 44.0 / fitted), maxf(base_size.y, 44.0 / fitted))
				var desired_size := maxi(int(button.get_meta("hud_base_font_size", 18)), ceili(float(button.get_meta("hud_base_font_size", 18)) * Paper.text_scale() / fitted))
				if button.get_theme_font_size("font_size") != desired_size:
					button.add_theme_font_size_override("font_size", desired_size)
			elif child is Label and child.has_meta("hud_base_font_size"):
				var base_font_size := int(child.get_meta("hud_base_font_size"))
				var desired_size := maxi(base_font_size, ceili(float(base_font_size) * Paper.text_scale() / fitted))
				if (child as Label).get_theme_font_size("font_size") != desired_size:
					(child as Label).add_theme_font_size_override("font_size", desired_size)
