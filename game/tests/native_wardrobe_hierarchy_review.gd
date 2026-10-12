extends "res://game/tests/native_review.gd"

## Same-input before/after native comparison fixture for ART-20. It changes only
## isolated review save data and writes captures under .review/.
const REVIEW_TIMEOUT_MS := 120000
const Paper := preload("res://game/ui/paper_ui.gd")
var _deadline_ms := 0
var _variant := ""
var _standard_only := false

func _ready() -> void:
	_deadline_ms = Time.get_ticks_msec() + REVIEW_TIMEOUT_MS
	_variant = OS.get_environment("SNAPLAND_ART20_VARIANT")
	_standard_only = OS.get_environment("SNAPLAND_ART20_STANDARD_ONLY") == "1"
	if _standard_only:
		Engine.max_fps = 60
	call_deferred("_run")

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
	if _deadline_ms > 0 and Time.get_ticks_msec() >= _deadline_ms:
		push_error("Native wardrobe hierarchy review exceeded its 120-second watchdog")
		_deadline_ms = 0
		if is_instance_valid(main):
			main.audio.shutdown()
		get_tree().quit(1)

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native wardrobe comparison requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	if _variant not in ["baseline", "candidate"]:
		push_error("Set SNAPLAND_ART20_VARIANT to baseline or candidate")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	progress.reset_progress()
	progress.intro_seen = true
	progress.coins = 0
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	if not await _wait_frames(8): return
	if not await _resize_review_window(Vector2i(1280, 720)): return
	_key(KEY_C)
	if not await _wait_frames(5): return
	if main.modal_kind != "wardrobe":
		await _review_fail("C key did not open wardrobe through normal input")
		return
	if _variant == "candidate" and not is_equal_approx(main.wardrobe_panel.preview.custom_minimum_size.y, 265.0):
		await _review_fail("Standard-size wardrobe did not start with its full-height preview")
		return
	if not await _check_active_tab_contrast(): return
	if not await _capture_review("01-appearance-standard"): return
	if not await _hold_standard_page(): return
	if not await _click_named("Tab_closet", "closet page"): return
	if main.wardrobe_panel.current_tab != "closet":
		await _review_fail("Pointer click did not select closet page")
		return
	if not await _capture_review("02-closet-standard"): return
	if not await _hold_standard_page(): return
	if not await _click_named("Tab_shop", "shop page"): return
	if main.wardrobe_panel.current_tab != "shop":
		await _review_fail("Pointer click did not select shop page")
		return
	if not await _click_named("WardrobeItem_outfit-gold", "100-coin shop item and keyboard focus"): return
	if not await _wait_frames(4): return
	if not await _check_selected_shop_state(): return
	if not await _capture_review("03-shop-unaffordable-100-focus"): return
	if not await _hold_standard_page(): return
	# The fixture exercises the setting's static/reduced-motion presentation without
	# changing layout or gameplay state. Both variants use the same setting.
	Progress.set_setting("reduced_motion", true)
	Paper.set_reduced_motion(true)
	if not await _wait_frames(3): return
	if not await _capture_review("04-shop-reduced-motion"): return
	if not await _hold_standard_page(): return
	if _standard_only:
		if _variant == "candidate":
			print("PASS: native wardrobe standard-size four-view review; compact mode not requested")
		else:
			print("BASELINE_CAPTURED: standard-size diagnostic only; compact mode not requested")
		await _finish_review()
		return
	Progress.set_setting("reduced_motion", false)
	Paper.set_reduced_motion(false)
	# Return to appearance before shrinking so the identical 800×600 screenshots
	# do not depend on a potentially clipped tab in the baseline layout.
	if not await _click_named("Tab_appearance", "standard appearance page before compact capture"): return
	if not await _resize_review_window(Vector2i(800, 600)): return
	if not await _capture_review("06-appearance-compact-800x600"): return
	if not await _check_compact_bounds(["Tab_appearance", "Tab_closet", "Tab_shop", "AvatarPreview", "ApplyAppearance", "CancelFitting"]): return
	if not await _resize_review_window(Vector2i(1280, 720)): return
	if _variant == "candidate" and not is_equal_approx(main.wardrobe_panel.preview.custom_minimum_size.y,265.0):
		await _review_fail("Live-resized wardrobe did not restore its full-height standard profile")
		return
	if not await _click_named("Tab_shop", "standard shop page before compact capture"): return
	if not await _click_named("WardrobeItem_outfit-gold", "repeat exact-price item selection for compact capture"): return
	if not await _wait_frames(4): return
	if not await _check_selected_shop_state(): return
	if not await _resize_review_window(Vector2i(800, 600)): return
	if not await _wait_frames(4): return
	if not await _check_selected_shop_state(): return
	if not await _capture_review("05-shop-compact-800x600"): return
	if not await _check_compact_bounds(["Tab_appearance", "Tab_closet", "Tab_shop", "AvatarPreview", "PurchaseSelected", "WearSelected"]): return
	if _variant == "candidate":
		print("PASS: native wardrobe candidate hierarchy, exact-price disabled state, keyboard focus, reduced motion and compact bounds")
	else:
		print("BASELINE_CAPTURED: diagnostic only; no candidate disabled-price or compact-fit acceptance is implied")
	await _finish_review()

func _resize_review_window(target: Vector2i) -> bool:
	DisplayServer.window_set_size(target)
	var deadline := Time.get_ticks_msec() + 2500
	while DisplayServer.window_get_size() != target and Time.get_ticks_msec() < deadline:
		if not await _wait_frames(1): return false
	if DisplayServer.window_get_size() != target:
		await _review_fail("Window did not reach requested physical size " + str(target))
		return false
	return await _wait_frames(4)

func _click_named(control_name: String, context: String) -> bool:
	var target := main.overlay.find_child(control_name, true, false) as BaseButton
	if not is_instance_valid(target):
		await _review_fail("Missing native control " + control_name)
		return false
	return await _native_click_button(target, context)

func _capture_review(stem: String) -> bool:
	if not await _wait_frames(2): return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/art20-wardrobe-comparison/" + _variant + "/" + stem + ".png"):
		await _review_fail("Could not capture " + stem)
		return false
	return true

func _check_active_tab_contrast() -> bool:
	var tab := main.overlay.find_child("Tab_appearance", true, false) as Button
	if tab == null: return false
	var normal_style := tab.get_theme_stylebox("normal") as StyleBoxFlat
	if normal_style == null:
		await _review_fail("Selected page has no inspectable background style")
		return false
	for pair in [["font_color","normal"],["font_hover_color","hover"],["font_pressed_color","pressed"],["font_focus_color","normal"]]:
		var ink := tab.get_theme_color(pair[0])
		var background := normal_style.bg_color
		var contrast := _contrast_ratio(ink,background)
		print("TAB_CONTRAST[", _variant, "] state=", pair[1], " ink=", ink, " background=", background, " ratio=", contrast)
		if _variant == "candidate" and contrast < 4.5:
			await _review_fail("Selected tab text misses contrast in state " + str(pair[1]))
			return false
	return true

func _hold_standard_page() -> bool:
	if not _standard_only:
		return true
	var hold_until := Time.get_ticks_msec() + 800
	var frame_count := 0
	while frame_count < 48 or Time.get_ticks_msec() < hold_until:
		if Time.get_ticks_msec() >= _deadline_ms:
			await _review_fail("Native standard-only review watchdog expired")
			return false
		await get_tree().process_frame
		frame_count += 1
	return true

func _finish_review() -> void:
	_deadline_ms = 0
	main.world.blocked = true
	main.world.set_process(false)
	main.audio.shutdown()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func _check_compact_bounds(control_names: Array[String]) -> bool:
	var viewport := main.get_viewport().get_visible_rect()
	var panel_rect := (main.overlay.get_child(1).get_child(0) as Control).get_global_rect()
	var modal_fits := viewport.encloses(panel_rect)
	print("COMPACT_BOUNDS[", _variant, "] modal=", panel_rect, " fits=", modal_fits)
	var avatar := main.overlay.find_child("AvatarPreview", true, false) as TextureRect
	if avatar == null or avatar.texture == null or avatar.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		await _review_fail("Compact fitting mirror does not retain the complete aspect-fitted avatar")
		return false
	if _variant == "candidate" and not is_equal_approx(avatar.custom_minimum_size.y, 220.0):
		await _review_fail("Open wardrobe did not recompute its compact preview after resize: " + str(avatar.custom_minimum_size))
		return false
	var all_fit := modal_fits
	for name in control_names:
		var control := main.overlay.find_child(name, true, false) as Control
		var bounds := control.get_global_rect() if control != null else Rect2()
		var fits := control != null and viewport.encloses(bounds) and panel_rect.encloses(bounds)
		print("COMPACT_BOUNDS[", _variant, "] control=", name, " rect=", bounds, " fits=", fits)
		all_fit = all_fit and fits
	if _variant == "candidate" and not all_fit:
		await _review_fail("Candidate compact wardrobe hierarchy has a clipped control")
		return false
	return true

func _check_selected_shop_state() -> bool:
	var panel = main.wardrobe_panel
	var purchase := panel.action_row.find_child("PurchaseSelected", false, false) as Button
	var selected := main.overlay.find_child("WardrobeItem_outfit-gold", true, false) as Control
	var focused := main.get_viewport().gui_get_focus_owner() == selected
	var scroll_rect: Rect2 = panel.item_scroll.get_global_rect() if is_instance_valid(panel.item_scroll) else Rect2()
	var selected_visible: bool = selected != null and scroll_rect.intersection(main.get_viewport().get_visible_rect()).encloses(selected.get_global_rect())
	var catalog_price := int(Progress.wardrobe_item("outfit-gold").get("price", -1))
	var price_text := ""
	if selected != null:
		for sibling in selected.get_parent().get_children():
			if sibling is Label and str(sibling.text).contains("幣"):
				price_text = str(sibling.text)
	var diagnostic := "disabled=%s status=%s row_price=%s catalog_price=%d focus=%s selected_rect=%s scroll_rect=%s selected_visible=%s" % [str(purchase.disabled if purchase != null else "missing"), str(panel.status_label.text), price_text, catalog_price, str(focused), str(selected.get_global_rect()) if selected != null else "missing", str(scroll_rect), str(selected_visible)]
	print("SHOP_STATE[", _variant, "] ", diagnostic)
	var price_ink: Color = selected.get_parent().get_child(selected.get_index()+1).get_theme_color("font_color") if selected != null else Color.WHITE
	var status_ink: Color = panel.status_label.get_theme_color("font_color")
	var paper_panel := main.overlay.find_child("AdaptiveMenuPanel", true, false) as PanelContainer
	var paper_style := paper_panel.get_theme_stylebox("panel") as StyleBoxFlat if paper_panel != null else null
	var paper_bg := paper_style.bg_color if paper_style != null else Color.WHITE
	var price_contrast := _contrast_ratio(price_ink, paper_bg)
	var status_contrast := _contrast_ratio(status_ink, paper_bg)
	print("SHOP_CONTRAST[", _variant, "] price=", price_ink, " ratio=", price_contrast, " status=", status_ink, " ratio=", status_contrast, " paper=", paper_bg)
	if panel.selected_item_id != "outfit-gold" or catalog_price != 100 or not focused or selected == null:
		await _review_fail("Actual pointer selection must select the exact catalog item and leave it keyboard-focused: " + diagnostic)
		return false
	if _variant == "candidate" and (not selected_visible or purchase == null or not purchase.disabled or not panel.status_label.text.contains("100 枚") or price_text != "100 幣" or price_contrast < 4.5 or status_contrast < 4.5):
		await _review_fail("Candidate must visibly focus the selected row, state exact price and disable unaffordable purchase: " + diagnostic)
		return false
	return true

func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _luminance(first)
	var second_luminance := _luminance(second)
	return (maxf(first_luminance,second_luminance)+0.05)/(minf(first_luminance,second_luminance)+0.05)

func _luminance(color: Color) -> float:
	var channels := [color.r,color.g,color.b]
	var linear: Array[float]=[]
	for value in channels:
		linear.append(value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4))
	return 0.2126*linear[0]+0.7152*linear[1]+0.0722*linear[2]

func _wait_frames(count: int) -> bool:
	for _i in count:
		if Time.get_ticks_msec() >= _deadline_ms:
			await _review_fail("Native wardrobe review watchdog expired")
			return false
		await get_tree().process_frame
	return true

func _review_fail(message: String) -> void:
	_deadline_ms = 0
	await _fail(message)
