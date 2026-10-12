extends SceneTree

const HudScene: PackedScene = preload("res://game/tests/test_minigame_hud.tscn")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var host := HudScene.instantiate() as Control
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var hud: Control = host.get_node("MinigameHUD")
	await process_frame
	if not hud.has_method("set_state"):
		push_error("FAIL: focused HUD scene did not load MinigameHUD")
		quit(1)
		return
	_test_live_content(hud)
	_test_responsive_targets(hud, Vector2(1280, 720), true)
	await _test_signals_and_overlays(hud)
	root.size = Vector2i(800, 600)
	host.size = Vector2(800, 600)
	host.scale = Vector2.ONE
	await process_frame
	await process_frame
	_test_live_content(hud)
	_test_responsive_targets(hud, Vector2(800, 600), false)
	root.size = Vector2i(1280, 720)
	host.size = Vector2(1280, 720)
	var restored_layout := false
	for _frame in 10:
		await process_frame
		if not bool(hud.get("_layout_refresh_pending")) and is_equal_approx(float(hud.get("_effective_scale")), 1.0) and is_equal_approx((hud.get("_header") as Control).size.y, 84.0) and is_equal_approx((hud.get("_status_rail") as Control).size.y, 84.0):
			restored_layout = true
			break
	_check(restored_layout, "compact-to-standard resize restores both plates to the 84px standard layout without a manual layout call")
	hud.set_paused(true)
	await process_frame
	_check(is_equal_approx((hud.get("_header") as Control).size.y, 84.0) and is_equal_approx((hud.get("_status_rail") as Control).size.y, 84.0), "opening Pause after a compact-to-standard resize does not retain compact plate heights")
	hud.set_paused(false)
	host.scale = Vector2(0.625, 0.625)
	hud.call("_layout")
	var stretched_layout := false
	for _frame in 10:
		await process_frame
		if not bool(hud.get("_layout_refresh_pending")) and is_equal_approx(float(hud.get("_effective_scale")), 0.625):
			stretched_layout = true
			break
	_check(stretched_layout, "parent stretch is incorporated after deferred resize layout completes")
	_check(is_equal_approx(float(hud.get("_effective_scale")), 0.625), "effective scale combines a 1280-logical canvas with 0.625 parent display stretch")
	_test_live_content(hud)
	hud.set_paused(true)
	await process_frame
	_test_responsive_targets(hud, Vector2(800, 450), true)
	hud.set_paused(false)
	host.free()
	await process_frame
	if _failures.is_empty() and _checks > 0:
		print("PASS: minigame HUD hierarchy checks (%d checks)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_live_content(hud: Control) -> void:
	var full_goal := "依照風向和六頂帽子的落點移動，並在帽簷經過手線時接住；連續中心接取可獲得更高成果。"
	var long_title := "沿著海港木棧道追接被海風吹走的六頂旅人帽子"
	hud.set_state({
		"title": long_title,
		"objective": full_goal,
		"progress_text": "已接住 3/6　漏接 0",
		"score": 0,
		"time_text": "00:42",
		"assisted": true,
		"practice": true,
	})
	var title: Label = hud.get("_title")
	var objective: Label = hud.get("_objective")
	var progress: Label = hud.get("_progress")
	var badge: Label = hud.get("_badge")
	var score: Label = hud.get("_score")
	var time: Label = hud.get("_time")
	_check(not objective.visible and objective.text == full_goal, "full goal stays available as exact HUD state without occupying the play area")
	_check(title.tooltip_text == full_goal and title.text == long_title and title.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "title tooltip preserves the complete goal while long titles are safely trimmed")
	_check(progress.text == "已接住 3/6　漏接 0" and progress.tooltip_text == progress.text, "live round progress remains visible and complete on hover")
	_check(badge.visible and badge.text.contains("輔助") and badge.text.contains("練習"), "assist and no-collection practice remain visibly labeled")
	_check(score.text == "0000" and time.text == "00:42", "zero score and changing round time remain readable")
	_check(hud.find_child("ScoreLabel", true, false) != null, "score has an explicit semantic label")

func _test_signals_and_overlays(hud: Control) -> void:
	var events: Array[String] = []
	hud.pause_requested.connect(func(): events.append("pause"))
	hud.help_requested.connect(func(): events.append("help"))
	hud.details_requested.connect(func(): events.append("details"))
	(hud.find_child("PauseButton", true, false) as Button).emit_signal("pressed")
	await _click_button(hud.find_child("HelpButton", true, false) as Button)
	hud.set_score_details({"rule":"依實際接住帽子計分", "rows":[{"label":"中心接住", "amount":120, "count":3}], "total":360})
	(hud.find_child("DetailsButton", true, false) as Button).emit_signal("pressed")
	var details: Control = hud.get("_score_layer")
	var score_rows: VBoxContainer = hud.get("_score_rows")
	_check(events == ["pause", "help", "details"], "pause, tutorial, and details controls emit their existing public signals")
	_check(details.visible and score_rows.get_child_count() == 3, "details opens with the real rule, event row, and total")
	hud.close_score_details()
	_check(not details.visible, "details can return to active play")
	hud.set_paused(true)
	await process_frame
	var resume := hud.find_child("ResumeButton", true, false) as Button
	_check((hud.get("_pause_layer") as Control).visible and resume != null and resume.has_focus(), "pause overlay exposes a focused 44px resume action")
	if resume != null:
		var focused_text := resume.get_theme_color("font_focus_color", "Button")
		_check(focused_text.is_equal_approx(Color.WHITE), "keyboard-focused primary action uses the explicit light-ink color")
		_check(_contrast_ratio(focused_text, Color("#31566a")) >= 4.5 and _contrast_ratio(resume.get_theme_color("font_hover_color", "Button"), Color("#416d7b")) >= 4.5, "focused and hovered action labels retain readable contrast against their button fills")
	_check((hud.get("_pause_title") as Label).text == "暫停", "pause dialog does not duplicate a long game title into the overlay layout")
	hud.set_paused(false)
	hud.set_state({"title":"帽子救援", "objective":"完整目標文字", "progress_text":"6/6 接住", "score":816, "time_text":"00:00", "ended":true, "won":true, "devil":true})
	var result_layer: Control = hud.get("_result_layer")
	var result_status: Label = hud.get("_result_status")
	_check(result_layer.visible and result_status.text.contains("惡魔拍貼達成") and result_status.text.contains("816"), "formal result shows earned outcome and actual total")
	hud.set_state({"title":"練習", "objective":"完整目標文字", "progress_text":"6/6 接住", "score":816, "time_text":"00:00", "ended":true, "won":true, "devil":false, "practice":true})
	_check(result_status.text.contains("練習結果・不會收藏拍貼") and not result_status.text.contains("惡魔拍貼達成"), "practice result states that it does not award a collectible")

func _click_button(button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	await process_frame
	click.pressed = false
	root.push_input(click)
	await process_frame

func _test_responsive_targets(hud: Control, viewport_size: Vector2, check_panel_density: bool) -> void:
	var left := hud.find_child("MinigameHeader", true, false) as Control
	var right := hud.find_child("MinigameStatusRail", true, false) as Control
	var left_rect := _physical_rect(left)
	var right_rect := _physical_rect(right)
	_check(left_rect.position.x >= 0.0 and left_rect.end.x < right_rect.position.x and right_rect.end.x <= viewport_size.x, "split corner plates leave the center open in physical pixels")
	_check(left_rect.position.y >= 0.0 and right_rect.end.y <= viewport_size.y, "HUD corner plates stay within the physical viewport height")
	if check_panel_density and viewport_size.x >= 1000.0:
		_check(left_rect.size.y < 104.0 and right_rect.size.y < 104.0, "standard HUD plates stay below the previous 104px banner height")
	elif check_panel_density:
		var hud_transform_scale := hud.get_global_transform().get_scale()
		var viewport_transform_scale := hud.get_viewport().get_final_transform().get_scale()
		var previous_card_height := 124.0 * absf(hud_transform_scale.y) * absf(viewport_transform_scale.y)
		_check(left_rect.size.y < previous_card_height and right_rect.size.y < previous_card_height, "compact stretched plates stay shorter than their previous 124px-card equivalents")
	for name in ["DetailsButton", "HelpButton", "PauseButton", "ResumeButton"]:
		var button := hud.find_child(name, true, false) as Button
		if button == null or not button.is_visible_in_tree():
			continue
		var rect := _physical_rect(button)
		_check(rect.size.x >= 44.0 and rect.size.y >= 44.0, "%s keeps a physical 44px target at %s (actual=%s)" % [name, viewport_size, rect.size])
		_check(rect.size.y <= 52.0, "%s does not stretch into an oversized full-height action" % name)
		_check(Rect2(Vector2.ZERO, viewport_size).encloses(rect), "%s remains inside the physical viewport" % name)

func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)

func _relative_luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	for index in channels.size():
		var channel := channels[index]
		channels[index] = channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722

func _physical_rect(control: Control) -> Rect2:
	return control.get_viewport().get_final_transform() * control.get_global_rect()
