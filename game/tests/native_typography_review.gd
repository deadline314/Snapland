extends Node
## Native, non-interactive typography presentation fixture for visual review.

const TestSaveGuard = preload("res://game/core/test_save_guard.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const MainScene = preload("res://game/main.tscn")

var main: Node
var report: Dictionary = {"fixture": "native typography and locale presentation", "labels": [], "captures": [], "qa_locale": true, "translation_qa_only": true, "english_coverage": "partial; missing entries use source/zh_TW fallback"}
var output_dir := ""
var review_locale := "zh_TW"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var guard_error := TestSaveGuard.validate_save_path(save_path, OS.get_user_data_dir())
	if not guard_error.is_empty():
		await _abort("TestSaveGuard rejected isolated save path: " + guard_error)
		return
	var args := _user_args()
	output_dir = str(args.get("type-review-output", ""))
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		await _abort("--type-review-output must be an absolute output directory")
		return
	var width := int(args.get("width", 1280))
	var height := int(args.get("height", 720))
	if Vector2i(width, height) not in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _abort("Use --width/--height pairs 800/450, 1280/720, or 1920/1080")
		return
	var font_style := str(args.get("font-style", "pixel"))
	var ui_scale := float(args.get("ui-scale", "1"))
	var locale_id := str(args.get("locale", "zh_TW"))
	if font_style not in ["pixel", "readable"] or ui_scale not in [1.0, 1.25] or locale_id not in ["zh_TW", "en", "qa_rtl"]:
		await _abort("Invalid typography review option")
		return
	review_locale = locale_id
	DirAccess.make_dir_recursive_absolute(output_dir)
	get_window().size = Vector2i(width, height)
	Paper.set_font_style(font_style)
	Paper.set_text_scale(ui_scale)
	Progress.reset_progress()
	Progress.intro_seen = true
	Progress.settings["font_style"] = font_style
	Progress.settings["ui_scale"] = ui_scale
	Progress.settings["locale"] = locale_id
	if not Localization.set_locale(locale_id, true) or Localization.locale() != locale_id:
		await _abort("Localization rejected requested QA locale after clean progress reset")
		return
	report["font_style"] = font_style
	report["ui_scale"] = ui_scale
	report["locale"] = locale_id
	main = MainScene.instantiate()
	add_child(main)
	await _frames(3)
	if not await _capture_main_views(): return
	if not await _capture_gallery(width): return
	if not await _write_report(): return
	print("PASS: native typography and locale presentation; translation QA only")
	print("Evidence is a technical presentation fixture; English coverage is partial and no human playtest is claimed.")
	await _shutdown(0)

func _capture_main_views() -> bool:
	main._show_settings()
	await _frames(3)
	var settings_panel = main.find_child("SettingsContent", true, false)
	var text_tab := main.find_child("SettingsTab_text", true, false) as Button
	if settings_panel == null or text_tab == null:
		await _abort("Main settings text category controls were not created")
		return false
	text_tab.grab_focus()
	text_tab.pressed.emit()
	await _frames(3)
	var category_focus := get_viewport().gui_get_focus_owner()
	var locale_choice := main.find_child("Value_locale", true, false) as OptionButton
	var font_choice := main.find_child("Value_font_style", true, false) as OptionButton
	if locale_choice != null and locale_choice.selected < 0 and locale_choice.item_count > 0:
		locale_choice.select(0)
	if category_focus != text_tab or main.find_child("Setting_locale", true, false) == null or main.find_child("Setting_font_style", true, false) == null or locale_choice == null or font_choice == null or locale_choice.disabled or font_choice.disabled or locale_choice.item_count < 1 or locale_choice.selected < 0 or font_choice.item_count != 2:
		await _abort("Settings category change did not retain keyboard focus")
		return false
	report["settings_category"] = "text"
	report["settings_focus"] = str(category_focus.name)
	report["setting_controls"] = {"locale_items":locale_choice.item_count, "selected_locale_option":locale_choice.get_item_metadata(locale_choice.selected), "qa_locale_unreleased":not Localization.available_locales().has(review_locale), "font_style_items":font_choice.item_count, "selected_font_style":font_choice.get_item_metadata(font_choice.selected)}
	if not await _save_capture("settings-text-category.png"): return false
	main._show_pause()
	await _frames(3)
	var pause_focus := get_viewport().gui_get_focus_owner()
	if pause_focus == null or not pause_focus.name.begins_with("Pause"):
		await _abort("Pause menu did not retain a meaningful focused action")
		return false
	if not await _save_capture("pause-menu.png"): return false
	var lines: Array = main.story.intro_lines()
	if lines.is_empty():
		await _abort("Story service returned no real dialogue lines")
		return false
	main._start_dialogue(lines, Callable(self, "_dialogue_callback"), Callable(self, "_dialogue_callback"))
	await _frames(3)
	var line_before := int(main.dialogue_index)
	if is_instance_valid(main.dialogue_label): main.dialogue_label.visible_characters = mini(5, main.dialogue_label.text.length())
	var reveal_before: int = main.dialogue_label.visible_characters if is_instance_valid(main.dialogue_label) else -1
	var reveal_progress_before := float(main.reveal)
	var done_callback_before: Callable = main.dialogue_done
	var cancel_callback_before: Callable = main.dialogue_cancelled
	Localization.set_locale(review_locale, true)
	var reveal_after: int = main.dialogue_label.visible_characters if is_instance_valid(main.dialogue_label) else -2
	if Localization.locale() != review_locale or main.dialogue_index != line_before or reveal_after != reveal_before or not is_equal_approx(float(main.reveal), reveal_progress_before) or main.dialogue_done != done_callback_before or main.dialogue_cancelled != cancel_callback_before:
		await _abort("Changing locale reset dialogue index or visible-character callback state")
		return false
	report["dialogue_locale_change"] = {"locale":Localization.locale(), "index_before": line_before, "index_after": main.dialogue_index, "visible_characters_before": reveal_before, "visible_characters_after": reveal_after, "reveal_before":reveal_progress_before, "reveal_after":main.reveal, "callbacks_preserved":true}
	main.set_process(false)
	report["dialogue_capture_freeze"] = "fixture process freeze after synchronous locale-state assertion"
	if not await _save_capture("dialogue-in-progress.png"): return false
	main.set_process(true)
	return true

func _capture_gallery(width: int) -> bool:
	var overlay := PanelContainer.new()
	overlay.name = "TypographyGalleryOverlay"
	overlay.z_index = 1000
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", Paper.plaque(Paper.DEEP))
	main.ui.add_child(overlay)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	overlay.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var locales := [
		{"id":"zh_TW", "name":"繁體中文", "sample":"海風裡的島嶼，把每張相遇留成紀念。"},
		{"id":"en", "name":"English", "sample":"A keepsake remembers every small island moment."},
		{"id":"ja", "name":"日本語", "sample":"島の風と小さな出会いを、思い出に残そう。"},
		{"id":"ko", "name":"한국어", "sample":"섬의 바람과 작은 만남을 추억으로 남겨요."},
		{"id":"qa_rtl", "name":"العربية · RTL QA", "sample":"الجزيرة تحفظ كل لحظة جميلة من رحلتك."},
		{"id":"en-long", "name":"Variable + long text", "sample":"Welcome, {player}! Keep every little memory safe while you explore the long winding paths around the island."},
	]
	var pages := 2 if width <= 800 else 1
	for page in range(pages):
		for child in stack.get_children(): child.queue_free()
		var title := Paper.label("FONT GALLERY  ·  %s  ·  page %d/%d" % [Paper.font_style(), page + 1, pages], 22, Paper.GOLD)
		stack.add_child(title)
		var start := page * 3 if pages == 2 else 0
		var count := 3 if pages == 2 else locales.size()
		var page_labels: Array[RichTextLabel] = []
		for index in range(start, mini(start + count, locales.size())):
			var entry: Dictionary = locales[index]
			var sample := str(entry.sample).format({"player": "小旅人"})
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			stack.add_child(row)
			row.add_child(Paper.label(str(entry.name), 15, Paper.TEAL))
			var label := RichTextLabel.new()
			label.name = "Gallery_" + str(entry.id)
			label.text = sample
			label.custom_minimum_size.y = 60
			label.clip_contents = false
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.fit_content = true
			label.scroll_active = false
			label.add_theme_font_size_override("normal_font_size", 19)
			label.add_theme_color_override("default_color", Paper.PAPER)
			var font: Font = FontProfiles.font_for_locale(str(entry.id), Paper.font_style())
			label.add_theme_font_override("normal_font", font)
			if str(entry.id) == "qa_rtl":
				label.text_direction = Control.TEXT_DIRECTION_RTL
				label.layout_direction = Control.LAYOUT_DIRECTION_RTL
			row.add_child(label)
			page_labels.append(label)
		await _frames(2)
		var title_rect := title.get_global_rect()
		var viewport_rect := get_viewport().get_visible_rect()
		if title_rect.position.x < 0.0 or title_rect.end.x > viewport_rect.size.x or title_rect.position.y < 0.0 or title_rect.end.y > viewport_rect.size.y:
			await _abort("Gallery page title is clipped by the requested viewport")
			return false
		for label in page_labels:
			var font: Font = label.get_theme_font("normal_font")
			var font_name := font.get_font_name() if font is FontFile else "theme fallback"
			var font_path := str(font.resource_path)
			var entry_id := label.name.trim_prefix("Gallery_")
			var key_characters := "島Aあ한ال" if entry_id != "qa_rtl" else "الجزيرة"
			var primary_glyphs := {}
			var fallback_glyphs := {}
			for character in key_characters:
				var codepoint := character.unicode_at(0)
				primary_glyphs[character] = font.has_char(codepoint)
				var fallback_has := false
				if font is FontFile:
					for fallback in font.fallbacks:
						if fallback.has_char(codepoint):
							fallback_has = true
				fallback_glyphs[character] = fallback_has
			var line_count := label.get_line_count()
			var visible_line_count := label.get_visible_line_count()
			if visible_line_count != line_count:
				await _abort("Gallery text is clipped or not fully laid out: " + label.name)
				return false
			report.labels.append({"locale":entry_id, "text":label.text, "font_name":font_name, "font_path":font_path, "paragraph_count":label.get_paragraph_count(), "line_count":line_count, "visible_line_count":visible_line_count, "rtl_direction":label.text_direction == Control.TEXT_DIRECTION_RTL, "primary_glyphs":primary_glyphs, "fallback_glyphs":fallback_glyphs, "autowrap":label.autowrap_mode, "clip_contents":label.clip_contents})
		if not await _save_capture("font-gallery-page-%d.png" % (page + 1)): return false
		report["gallery_pages"] = pages
	return true

func _save_capture(filename: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output_dir.path_join(filename)
	if image.is_empty() or image.save_png(path) != OK:
		await _abort("Could not save capture: " + path)
		return false
	report.captures.append(path)
	return true

func _write_report() -> bool:
	var file := FileAccess.open(output_dir.path_join("native-typography-report.json"), FileAccess.WRITE)
	if file == null:
		await _abort("Could not create metadata report")
		return false
	file.store_string(JSON.stringify(report, "  "))
	return true

func _user_args() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if not value.begins_with("--") or not value.contains("="): continue
		var pair := value.trim_prefix("--").split("=", false, 1)
		if pair.size() == 2: result[pair[0]] = pair[1]
	return result

func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame

func _dialogue_callback() -> void:
	pass

func _abort(reason: String) -> void:
	push_error("Native typography review failed: " + reason)
	await _shutdown(1)

func _shutdown(exit_code: int) -> void:
	if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(exit_code)
