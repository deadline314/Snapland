extends Node

const MAIN_SCENE := preload("res://game/main.tscn")
var failures: Array[String] = []
var main: Node
var done_calls := 0

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before localization checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var parsed_manifest_path := "user://localization-schema-number.json"
	var parsed_manifest_file := FileAccess.open(parsed_manifest_path, FileAccess.WRITE)
	parsed_manifest_file.store_string(JSON.stringify({"schema_version": 1, "locales": {"zh_TW": {"name": "繁體中文", "released": true, "qa_only": false, "direction": "ltr", "pack": "zh_TW.json"}}}))
	parsed_manifest_file.close()
	var parsed_manifest := Localization._read_json(parsed_manifest_path)
	_check(Localization._validate_manifest(parsed_manifest, parsed_manifest_path), "parsed JSON numeric schema version 1 is accepted")
	var parsed_pack_path := "user://localization-schema-pack.json"
	var parsed_pack_file := FileAccess.open(parsed_pack_path, FileAccess.WRITE)
	parsed_pack_file.store_string(JSON.stringify({"schema_version": 1, "locale": "zh_TW", "direction": "ltr", "messages": {"hud.coins": {"source": "{count} 幣", "text": "{count} 幣"}}}))
	parsed_pack_file.close()
	var parsed_pack := Localization._read_json(parsed_pack_path)
	_check(Localization._validate_pack(parsed_pack, "zh_TW", parsed_pack_path), "parsed JSON pack numeric schema version 1 is accepted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(parsed_manifest_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(parsed_pack_path))
	Localization._initialized = false
	Localization.set_locale("zh_TW")
	_check(TranslationServer.get_locale() == "zh_TW" and TranslationServer.translate("普通 {count} / 18") == "普通 {count} / 18", "first base locale initialization installs native aliases and sets engine locale")
	_check(Localization.available_locales() == ["zh_TW"], "only complete released zh_TW is published")
	_check(not Localization.available_locales().has("en") and not Localization.available_locales().has("qa_rtl"), "English and RTL packs stay QA only")
	var bad_manifest: Dictionary = Localization._manifest.duplicate(true)
	bad_manifest.locales.en.pack = "../outside.json"
	_check(not Localization._validate_manifest(bad_manifest, "user://bad-manifest.json"), "manifest rejects pack traversal")
	bad_manifest = Localization._manifest.duplicate(true)
	bad_manifest.schema_version = 99
	_check(not Localization._validate_manifest(bad_manifest, "user://bad-schema.json"), "manifest rejects unsupported schema version")
	bad_manifest = Localization._manifest.duplicate(true)
	bad_manifest.locales.qa_rtl.direction = "vertical"
	_check(not Localization._validate_manifest(bad_manifest, "user://bad-direction.json"), "manifest rejects unsupported text direction")
	_check(not Localization._validate_pack({"schema_version": 1, "locale": "zh_TW", "direction": "ltr", "messages": {}}, "zh_TW", "user://empty-base.json"), "empty base pack requires readable embedded fallback")
	var malformed_messages := {"schema_version": 1, "locale": "en", "direction": "ltr", "messages": {"hud.coins": "not-an-object"}}
	_check(not Localization._validate_pack(malformed_messages, "en", "user://bad-pack.json"), "pack rejects non-dictionary message entry")
	malformed_messages.messages["hud.coins"] = ["unexpected", "array"]
	_check(not Localization._validate_pack(malformed_messages, "en", "user://bad-pack.json"), "pack rejects array message entry")
	malformed_messages.schema_version = 99
	_check(not Localization._validate_pack(malformed_messages, "en", "user://bad-schema-pack.json"), "pack rejects unsupported schema version")
	_check(Localization._load_pack("missing") == false, "missing pack load fails safely")
	Localization.set_locale("missing", true)
	_check(Localization.locale() == "zh_TW", "invalid locale falls back to zh_TW")
	var locale_events := [0]
	Localization.locale_changed.connect(func(_id: String): locale_events[0] += 1)
	Localization.set_locale("zh_TW")
	_check(locale_events[0] == 0, "setting the current locale emits no duplicate change signal")
	_check(Localization.text("hud.coins", {"count": 23}) == "23 幣", "named placeholders format from the base pack")
	_check(Localization.text("hud.coins", {}) == "{count} 幣", "placeholder mismatch returns the zh_TW/source template")
	Localization.set_locale("en", true)
	_check(Localization.locale() == "en" and Localization.text("hud.coins", {"count": 8}) == "8 coins", "QA English pack translates stable message IDs")
	Localization.set_locale("en", true)
	_check(locale_events[0] == 1, "unchanged locale does not emit repeatedly")
	_check(Localization.text("dialogue.example.many", {"name": "Sam", "count": 3}) == "3 photos belong to Sam.", "named placeholders survive translator order changes")
	_check(TranslationServer.translate("普通 {count} / 18") == "Normal {count} / 18", "source alias translation keeps source ID unchanged")
	_check(Localization.text_plural("hud.photo_count", 1) == "1 photo" and Localization.text_plural("hud.photo_count", 2) == "2 photos", "Godot plural rules select English singular and plural forms")
	var good_english: Dictionary = Localization._packs.en.duplicate(true)
	var mismatched_english: Dictionary = good_english.duplicate(true)
	mismatched_english.messages["hud.coins"].text = "{other} coins"
	Localization._packs.en = mismatched_english
	var defensive_translation: Translation = Localization._build_translation("en")
	_check(defensive_translation.get_message("{count} 幣") == "{count} 幣", "native source alias falls back when injected placeholders mismatch")
	Localization._packs.en = good_english
	Localization.set_locale("qa_rtl", true)
	_check(Localization.is_rtl() and Localization.text("rtl.mixed_numbers", {"name": "Sam"}) == "مرحبا Sam — 123 / ٤٥٦", "RTL QA metadata and mixed digit sample load")
	Progress.set_setting("locale", "en")
	_check(Progress.settings.locale == "zh_TW", "unreleased locale cannot be saved as a user setting")
	Progress.set_setting("locale", "zh_TW")
	Progress.set_setting("font_style", "readable")
	Progress.set_setting("font_style", "bogus")
	_check(Progress.settings.font_style == "pixel", "invalid font style safely falls back to pixel")
	Progress.set_setting("font_style", "readable")
	var future_setting := {"enabled": true, "values": [1.0, "future"]}
	Progress.settings["future_setting"] = future_setting.duplicate(true)
	_check(Progress.save_progress(), "locale and font preference save to isolated profile")
	Progress.settings.locale = "zh_TW"
	Progress.settings.font_style = "pixel"
	Progress.load_progress()
	_check(Progress.settings.locale == "zh_TW" and Progress.settings.font_style == "readable", "locale and font preference reload with string validation")
	_check(Progress.settings.get("future_setting") == future_setting, "unknown future settings survive the validated locale/font save roundtrip")
	var legacy_save := Progress._validated_payload({"settings": {"master_volume": 0.25}}, "user://legacy-progress.json")
	Progress._apply_save(legacy_save)
	_check(Progress.settings.locale == "zh_TW" and Progress.settings.font_style == "pixel" and Progress.settings.master_volume == 0.25, "old progress without locale or font keys loads default preferences")

	Progress.intro_seen = true
	Progress.save_progress()
	main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var callback := Callable(self, "_on_dialogue_done")
	main._start_dialogue([{"speaker": "speaker-id", "text_key": "dialogue.example.one", "text_args": {"name": "Sam"}}], callback)
	main.dialogue_index = 0
	main.reveal = 2.0
	main.dialogue_label.visible_characters = 2
	var reveal_before: float = main.reveal
	var callback_before: Callable = main.dialogue_done
	Progress.save_progress()
	var saved_content_before := Localization._read_json(Progress._save_path())
	var content_before := {"photos": Progress.photos.duplicate(true), "achievements": Progress.achievements.duplicate(true), "quests": Progress.quests.duplicate(true), "owned_clothes": Progress.owned_clothes.duplicate(), "equipped": Progress.equipped.duplicate(true), "coins": Progress.coins}
	Localization.set_locale("qa_rtl", true)
	_check(main.dialogue_index == 0 and main.reveal == reveal_before and main.dialogue_done == callback_before and main.dialogue_label.visible_characters == 2, "locale change updates keyed dialogue while preserving index, reveal and callback")
	_check(main.dialogue_label.text == "مرحبًا Sam!", "active dialogue text refreshes from its stable key: " + main.dialogue_label.text)
	_check(main.ui.layout_direction == Control.LAYOUT_DIRECTION_RTL, "RTL locale sets UI layout direction")
	_check(Progress.photos == content_before.photos and Progress.achievements == content_before.achievements and Progress.quests == content_before.quests and Progress.owned_clothes == content_before.owned_clothes and Progress.equipped == content_before.equipped and Progress.coins == content_before.coins, "locale switching preserves photo, achievement, quest, wardrobe and coin identifiers")
	Progress.save_progress()
	_check(Localization._read_json(Progress._save_path()) == saved_content_before, "locale switch leaves the complete serialized Progress state unchanged")
	main._finish_dialogue()
	Localization.set_locale("zh_TW")
	main._show_settings()
	var text_tab := main.overlay.find_child("SettingsTab_text", true, false) as Button
	if text_tab != null:
		text_tab.pressed.emit()
	_check(main.modal_kind == "settings" and text_tab != null and text_tab.button_pressed, "independent text settings category is available and selected")
	Localization.set_locale("qa_rtl", true)
	_check(main.overlay.find_child("SettingsTab_text", true, false) != null and (main.overlay.find_child("SettingsTab_text", true, false) as Button).button_pressed, "locale change keeps current settings category and selection")
	Localization.set_locale("zh_TW")
	Localization.set_locale("en", true)
	main._show_settings()
	var audio_label := main.overlay.find_child("Setting_master_volume", true, false).get_child(0) as Label
	_check(audio_label.text == Localization.text("settings.master_volume"), "settings opened in English uses English row labels")
	var english_text_tab := main.overlay.find_child("SettingsTab_text", true, false) as Button
	english_text_tab.pressed.emit()
	var locale_choice := main.overlay.find_child("Value_locale", true, false) as OptionButton
	locale_choice.grab_focus()
	Localization.set_locale("zh_TW")
	for category in ["audio", "play", "controls", "text"]:
		var tab := main.overlay.find_child("SettingsTab_" + category, true, false) as Button
		_check(tab.text == Localization.text("settings." + category), "settings tab restores Chinese: " + category)
	_check((main.overlay.find_child("SettingsTab_text", true, false) as Button).button_pressed, "English-created settings retains text category")
	_check(main.get_viewport().gui_get_focus_owner().name == "Value_locale", "locale refresh preserves focused option")
	for setting in ["locale", "font_style"]:
		var row: Node = main.overlay.find_child("Setting_" + setting, true, false)
		_check((row.get_child(0) as Label).text == Localization.text("settings." + setting), "English-created settings restores Chinese row: " + setting)
	await _check_tall_rtl_pause()
	var broken_base_path := "user://localization-broken-base.json"
	var broken_base_file := FileAccess.open(broken_base_path, FileAccess.WRITE)
	broken_base_file.store_string(JSON.stringify({"schema_version": 1, "locale": "zh_TW", "direction": "ltr", "messages": {"hud.coins": ["bad"]}}))
	broken_base_file.close()
	Localization._packs.erase("zh_TW")
	_check(Localization._load_pack_from_path("zh_TW", broken_base_path), "corrupt base pack loads embedded fallback")
	_check(Localization.text("hud.coins", {"count": 7}) == "7 幣", "embedded base source fallback keeps player text readable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken_base_path))
	if failures.is_empty():
		print("PASS: locale packs, fallback, preferences and live UI state")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)

func _on_dialogue_done() -> void:
	done_calls += 1

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _check_tall_rtl_pause() -> void:
	main._close()
	Progress.settings["ui_scale"]=1.25
	Progress.settings["font_style"]="pixel"
	Localization.set_locale("qa_rtl",true)
	main._refresh()
	for dimensions in [Vector2i(1280,720),Vector2i(800,450)]:
		get_tree().root.size=dimensions
		main._show_pause()
		for frame in 10: await get_tree().process_frame
		var viewport_rect: Rect2=main.get_viewport().get_visible_rect()
		var buttons: Array[Control]=[]
		for button in main.overlay.find_children("Pause*Button","Button",true,false):
			if not button.is_visible_in_tree(): continue
			var rectangle: Rect2=button.get_global_rect()
			_check(viewport_rect.grow(1).encloses(rectangle),"tall RTL pause keeps %s fully visible at %s: %s in %s" % [button.name,dimensions,rectangle,viewport_rect])
			for other in buttons:
				_check(not rectangle.intersects(other.get_global_rect()),"tall RTL pause actions do not overlap at %s" % dimensions)
			buttons.append(button)
		_check(buttons.size()>=11,"tall RTL pause retains all nine destinations plus resume and quit")
		main._close()
	Localization.set_locale("zh_TW")
	Progress.settings["ui_scale"]=1.0
	get_tree().root.size=Vector2i(1280,720)
