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
const INK := Color("#20394d")
const PAPER := Color("#fff4d9")
const MINT := Color("#70e1c1")
const GOLD := Color("#d6ad76")
const SHADOW_INK := Color("#071923", 0.48)

var _state: Dictionary = {}
var _details: Dictionary = {}
var _header: PanelContainer
var _title: Label
var _objective: Label
var _progress: Label
var _score: Label
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_header()
	_build_feedback()
	_build_pause_layer()
	_build_score_layer()
	_build_confirm_layer()
	_build_result_layer()
	resized.connect(_layout)
	var parent_control := get_parent_control()
	if parent_control != null:
		parent_control.resized.connect(_layout)
	_layout()
	set_state({})

func set_state(state: Dictionary) -> void:
	_state = state.duplicate()
	if _title == null:
		return
	_title.text = str(state.get("title", "小遊戲"))
	_objective.text = str(state.get("objective", "完成挑戰"))
	_objective.tooltip_text = _objective.text
	_progress.text = str(state.get("progress_text", "準備中"))
	_score.text = "%04d" % int(state.get("score", 0))
	_time.text = str(state.get("time_text", "01:00"))
	var badges: Array[String] = []
	if bool(state.get("assisted", false)):
		badges.append("輔助")
	if bool(state.get("practice", false)):
		badges.append("練習・不收藏")
	_badge.text = "　".join(badges)
	_badge.visible = not badges.is_empty()
	var message := str(state.get("feedback_text", ""))
	_feedback.visible = not message.is_empty()
	_feedback_label.text = message
	var feedback_width := clampf(float(state.get("feedback_width", 540.0)), 230.0, 540.0)
	_feedback_label.custom_minimum_size.x = feedback_width - 30.0
	_feedback.size.x = feedback_width
	_feedback_label.add_theme_color_override("font_color", state.get("feedback_color", PAPER))
	_pause_status.text = "練習中" if bool(state.get("practice", false)) else "正式挑戰"
	_pause_title.text = str(state.get("title", "小遊戲")) + "　暫停"
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
	_header.position = Vector2(34, 18)
	_header.size = Vector2(1212, 104)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.add_theme_stylebox_override("panel", _ticket_style())
	add_child(_header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_header.add_child(row)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)
	_title = _label("小遊戲", 24, INK)
	text_col.add_child(_title)
	_objective = _label("完成挑戰", 18, Color("#34545b"))
	_objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_objective.tooltip_text = "完整目標請按 ? 查看圖解教學。"
	text_col.add_child(_objective)
	var status_row := HBoxContainer.new()
	text_col.add_child(status_row)
	_progress = _label("準備中", 18, Color("#79562b"))
	status_row.add_child(_progress)
	_badge = _label("", 16, Color("#28675d"))
	status_row.add_child(_badge)
	_score = _label("0000", 29, Color("#765321"))
	_score.custom_minimum_size.x = 106
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_score)
	var time_col := VBoxContainer.new()
	_time = _label("01:00", 19, INK)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_col.add_child(_time)
	var detail_button := _button("分數明細", 16)
	detail_button.name = "DetailsButton"
	detail_button.pressed.connect(func(): details_requested.emit(); open_score_details())
	time_col.add_child(detail_button)
	row.add_child(time_col)
	var help_button := _button("? 教學", 16)
	help_button.name = "HelpButton"
	help_button.pressed.connect(func(): help_requested.emit())
	row.add_child(help_button)
	var pause_button := _button("暫停", 16)
	pause_button.name = "PauseButton"
	pause_button.pressed.connect(func(): pause_requested.emit())
	row.add_child(pause_button)

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
	_feedback.position = Vector2(clampf(anchor.x - _feedback.size.x * 0.5, 30, DESIGN_SIZE.x - _feedback.size.x - 30), clampf(anchor.y - 78, 130, DESIGN_SIZE.y - _feedback.size.y - 82))

func _build_pause_layer() -> void:
	_pause_layer = _overlay("PauseOverlay")
	_pause_panel = _dialog_panel(_pause_layer, Vector2(420, 165), Vector2(440, 390))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_pause_panel.add_child(body)
	_pause_title = _label("暫停", 27, PAPER)
	body.add_child(_pause_title)
	_pause_status = _label("正式挑戰", 14, Color("#d2e3dc"))
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
	var rule_label := _label("計分規則：" + str(_details.get("rule", "依實際事件記分")), 13, Color("#d2e3dc"))
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
		_score_rows.add_child(_label(str(entry.get("label", "分數")) + count_text + value, 14, PAPER))
	if rows.is_empty():
		_score_rows.add_child(_label("尚無得分事件", 15, PAPER))
	_score_rows.add_child(_label("目前總分　%d" % int(_details.get("total", 0)), 19, Color("#ffdb82")))

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
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#18354a"), GOLD, 1.0, 2))
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
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#b7c3c0"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#31566a"), Color("#b39a70"), 4, 2, Vector2(2.0, 3.0)))
	button.add_theme_stylebox_override("hover", _button_style(Color("#416d7b"), MINT, 5, 3, Vector2(2.0, 4.0)))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#23485b"), GOLD, 2, 0, Vector2(0.0, 1.0)))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.add_theme_stylebox_override("disabled", _button_style(Color("#384b55"), Color("#697a7d"), 2, 0, Vector2.ZERO))
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _panel_style(background: Color, border: Color, alpha: float, elevation: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background, alpha)
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_bottom = 4 if elevation == 1 else 5 if elevation >= 2 else 2
	style.set_corner_radius_all(10)
	style.shadow_color = SHADOW_INK
	style.shadow_size = 2 if elevation == 1 else 5 if elevation >= 2 else 0
	style.shadow_offset = Vector2(2.0, 3.0) if elevation == 1 else Vector2(3.0, 5.0) if elevation >= 2 else Vector2.ZERO
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _ticket_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f2e7ca")
	style.border_color = Color("#a77a42")
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_corner_radius_all(9)
	style.shadow_color = SHADOW_INK
	style.shadow_size = 3
	style.shadow_offset = Vector2(2.0, 4.0)
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
	style.border_width_bottom = bottom_edge
	style.set_corner_radius_all(8)
	style.shadow_color = SHADOW_INK
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
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
