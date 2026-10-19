extends Node

const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const ParkWorld = preload("res://game/world/park_world.gd")

const BenchView = preload("res://game/minigames/bench_swap_view.gd")
const BenchModel = preload("res://game/minigames/bench_swap_model.gd")

var checks := 0
var failures := 0

func _ready() -> void:
	var previous_locale := TranslationServer.get_locale()
	Paper.set_font_style("pixel")
	_set_locale("zh_TW")
	var zh_font := Paper.font() as FontFile
	_expect(zh_font != null and zh_font.font_name.contains("Fusion"), "default Traditional Chinese profile uses Fusion Pixel")
	var source_pixel := load(FontProfiles.PIXEL_PATHS["zh_TW"]) as FontFile
	for font_size in [18, 24]:
		_expect(is_equal_approx(zh_font.get_height(font_size), source_pixel.get_height(font_size)), "unused Arabic and symbols fallbacks preserve primary line height at %d px" % font_size)
	var source_arabic := load(FontProfiles.ARABIC_PATH) as FontFile
	var arabic_profile := FontProfiles.font_for_locale("qa_rtl")
	_expect(is_equal_approx(arabic_profile.get_height(24), source_arabic.get_height(24)), "Arabic primary keeps native ascent and descent")
	var gallery_ja := FontProfiles.font_for_locale("ja")
	var gallery_arabic := FontProfiles.font_for_locale("ar_SA", "readable")
	var gallery_readable_zh := FontProfiles.font_for_locale("zh_TW", "readable")
	_expect(gallery_ja.get_font_name().contains("Fusion") and gallery_arabic.get_font_name().contains("Noto Sans Arabic") and gallery_readable_zh.get_font_name().contains("Noto Sans CJK"), "pure locale lookup returns regional pixel and readable fonts")
	_expect(FontProfiles.current_font() == zh_font and FontProfiles.current_locale_key() == "zh_TW" and FontProfiles.style() == "pixel", "gallery font lookups leave the active UI profile untouched")
	_expect(zh_font.antialiasing == TextServer.FONT_ANTIALIASING_NONE and not zh_font.multichannel_signed_distance_field and is_equal_approx(zh_font.oversampling, 1.0), "pixel profile uses unfiltered native outlines")
	_expect(zh_font.has_char("中".unicode_at(0)) and zh_font.has_char("𠮷".unicode_at(0)), "CJK profile and bundled fallback cover common and rare characters")
	_expect(zh_font.has_char("A".unicode_at(0)) and zh_font.has_char("é".unicode_at(0)), "CJK profile falls back for Latin text")
	_expect(zh_font.has_char("‹".unicode_at(0)) and zh_font.has_char("›".unicode_at(0)) and zh_font.has_char("−".unicode_at(0)) and zh_font.has_char("✦".unicode_at(0)), "bundled CJK and symbol fallbacks cover punctuation and decorative glyphs")
	TranslationServer.set_locale("ja")
	_expect(FontProfiles.current_font() == zh_font, "custom draw font getter returns the prepared font without rechecking locale")
	Paper.theme()
	_expect(Paper.font().get_font_name().contains("Fusion"), "Japanese locale selects a Fusion regional profile")
	_expect(Paper.font().has_char("語".unicode_at(0)), "Japanese profile covers Japanese sample text")
	_set_locale("ko")
	_expect(Paper.font().has_char("한".unicode_at(0)), "Korean profile covers Korean sample text")
	_set_locale("qa_rtl")
	var arabic_font := Paper.font()
	_expect(arabic_font.get_font_name().contains("Noto Sans Arabic"), "RTL QA selects the bundled Arabic font")
	_expect(arabic_font.has_char("م".unicode_at(0)) and arabic_font.has_char("A".unicode_at(0)) and arabic_font.has_char("中".unicode_at(0)) and arabic_font.has_char("✦".unicode_at(0)), "Arabic profile covers Arabic, Latin, CJK, and symbols through bundled fonts")
	_set_locale("zh_TW")
	var pixel_font := Paper.font()
	Paper.set_font_style("readable")
	var readable_font := Paper.font() as FontFile
	_expect(readable_font != pixel_font and readable_font.font_name.contains("Noto Sans CJK") and readable_font.antialiasing != TextServer.FONT_ANTIALIASING_NONE, "readable profile uses bundled Noto CJK with normal antialiasing")
	_set_locale("qa_rtl")
	_expect(Paper.font().get_font_name().contains("Noto Sans Arabic"), "readable RTL profile uses the bundled Arabic font")
	_set_locale("ar_SA")
	_expect(Paper.font().get_font_name().contains("Noto Sans Arabic"), "real Arabic locale selects the Arabic font profile")
	_set_locale("zh_TW")
	Paper.set_font_style("pixel")
	_expect(Paper.font() == pixel_font, "switching back reuses the cached pixel font")
	Paper.set_font_style("readable")
	_expect(Paper.font() == readable_font and FontProfiles.cached_font_count() <= FontProfiles.CACHE_LIMIT, "repeated profile switches stay within the bounded cache")
	var ui_theme := Paper.theme()
	_expect(ui_theme.default_font == Paper.font(), "Paper theme uses the active profile")
	_expect(ui_theme.get_font("font", "Button") == Paper.font(), "button inherits the active theme font")
	_expect(ui_theme.get_font("font", "PopupMenu") == Paper.font(), "popup inherits the active theme font")
	_expect(ui_theme.get_font("font", "CheckButton") == Paper.font(), "check button inherits the active theme font")
	var container := Control.new()
	container.theme = ui_theme
	add_child(container)
	var label := Paper.label("標籤")
	container.add_child(label)
	var button := Button.new()
	container.add_child(button)
	var selector := OptionButton.new()
	container.add_child(selector)
	var popup := selector.get_popup()
	_expect(label.get_theme_font("font") == Paper.font(), "Paper label inherits the active theme font")
	_expect(button.get_theme_font("font") == Paper.font(), "button inherits the active theme font")
	_expect(popup.get_theme_font("font") == Paper.font(), "OptionButton popup inherits the active theme font")
	var world := ParkWorld.new()
	var marker := Label3D.new()
	var child_marker := Label3D.new()
	marker.add_child(child_marker)
	world.add_child(marker)
	var refreshed_font := Paper.font()
	world.refresh_label_fonts(refreshed_font)
	_expect(marker.font == refreshed_font and child_marker.font == refreshed_font, "world refresh updates nested Label3D fonts")
	world.refresh_label_fonts(refreshed_font)
	_expect(world._last_label_font == refreshed_font, "repeating the same world font refresh is a no-op")
	_check_production_marks()
	container.queue_free()
	world.free()
	_set_locale(previous_locale)
	Paper.set_font_style("pixel")
	print("%s: %d pixel font checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	Paper.theme()

func _check_production_marks() -> void:
	for style in ["pixel","readable"]:
		for locale in ["zh_TW","en","ja","ko","qa_rtl"]:
			var font: Font = FontProfiles.font_for_locale(locale,style)
			var marks: Array = BenchView.GUEST_MARKS.duplicate()
			marks.append_array(ParkWorld.ZONE_ICONS)
			var window_rule := BenchModel.new()._rule_text([{"kind":"seat","guest":0,"seat":5}])
			marks.append(window_rule)
			var missing: Array[String] = []
			for mark in marks:
				for index in str(mark).length():
					var code := str(mark).unicode_at(index)
					if code>32 and not font.has_char(code): missing.append(String.chr(code))
			_expect(missing.is_empty(), "actual guest marks, window rule and district icons are bundled for %s/%s: %s" % [locale,style,str(missing)])
