extends RefCounted
## Locale-aware, bounded font resources shared by Paper UI and custom drawing.

const CJK_PATH := "res://assets/fonts/NotoSansCJKtc-Regular.otf"
const PIXEL_PATHS := {
	"zh_TW": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-zh_tw.otf",
	"en": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-latin.otf",
	"ja": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-ja.otf",
	"ko": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-ko.otf",
}
const ARABIC_PATH := "res://assets/fonts/NotoSansArabic.ttf"
const SYMBOLS_PATH := "res://assets/fonts/NotoSansSymbols2.ttf"
const CACHE_LIMIT := 8
# Covers Paper UI sizes including its maximum accessibility text scale.
const METRIC_CACHE_MAX_SIZE := 128

static var _style := "pixel"
static var _cache: Dictionary = {}
static var _cache_order: Array[String] = []
static var _loaded: Dictionary = {}
static var _fallbacks: Dictionary = {}
static var _missing: Array[String] = []
static var _active_font: Font = ThemeDB.fallback_font
static var _active_locale := "en"

static func set_style(style: String) -> void:
	_style = _normalized_style(style)
	refresh_context()

static func style() -> String:
	return _style

static func current_font() -> Font:
	return _active_font

static func refresh_context(locale: String = "") -> Font:
	var context_locale := locale if not locale.is_empty() else TranslationServer.get_locale()
	_active_locale = _locale_key(context_locale)
	_active_font = _font_for_key(_active_locale, _style)
	return _active_font

static func font_for_locale(locale_id: String, style: String = "") -> Font:
	var normalized_locale := _locale_key(locale_id)
	var normalized_style := _style if style.is_empty() else _normalized_style(style)
	return _font_for_key(normalized_locale, normalized_style)

static func _font_for_key(normalized_locale: String, style: String) -> Font:
	var key := "%s:%s" % [normalized_locale, style]
	if _cache.has(key):
		_touch(key)
		return _cache[key]
	var regional_path := ARABIC_PATH if normalized_locale == "qa_rtl" else str(PIXEL_PATHS.get(normalized_locale, PIXEL_PATHS["en"]))
	var primary_path := regional_path if style == "pixel" else (ARABIC_PATH if normalized_locale == "qa_rtl" else CJK_PATH)
	var primary := _duplicate_profile_font(primary_path, style == "pixel")
	var fallback_paths: Array[String] = []
	if style == "pixel":
		fallback_paths = [CJK_PATH, ARABIC_PATH, SYMBOLS_PATH]
	else:
		fallback_paths = [str(PIXEL_PATHS["en"]) if normalized_locale == "qa_rtl" else regional_path, CJK_PATH if normalized_locale == "qa_rtl" else ARABIC_PATH, SYMBOLS_PATH]
	var profile_fallbacks: Array[Font] = []
	for fallback_path in fallback_paths:
		var fallback := _fallback_font(fallback_path, primary_path, primary)
		if primary is FontFile and fallback != null and fallback != primary and not profile_fallbacks.has(fallback):
			profile_fallbacks.append(fallback)
	primary.fallbacks = profile_fallbacks
	_cache[key] = primary
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return primary

static func _normalized_style(style: String) -> String:
	return "readable" if style == "readable" else "pixel"

static func current_locale_key() -> String:
	return _active_locale

static func missing_paths() -> Array[String]:
	return _missing.duplicate()

static func cached_font_count() -> int:
	return _cache.size()

static func _locale_key(locale: String) -> String:
	var normalized := locale.to_lower().replace("-", "_")
	if normalized == "qa" or normalized.begins_with("qa_rtl") or normalized == "ar" or normalized.begins_with("ar_") or normalized.contains("arab"):
		return "qa_rtl"
	if normalized.begins_with("zh"):
		return "zh_TW"
	if normalized.begins_with("ja"):
		return "ja"
	if normalized.begins_with("ko"):
		return "ko"
	return "en"

static func _duplicate_profile_font(path: String, pixel: bool) -> Font:
	var source := _load_font(path)
	if source == null:
		source = _load_font(CJK_PATH)
	if source == null:
		return ThemeDB.fallback_font
	var configured := source.duplicate() as FontFile
	if configured == null:
		return source
	configured.fallbacks = []
	configured.allow_system_fallback = false
	if pixel:
		configured.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		configured.multichannel_signed_distance_field = false
		configured.oversampling = 1.0
		configured.hinting = TextServer.HINTING_NONE
		configured.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return configured

static func _load_font(path: String) -> FontFile:
	if _loaded.has(path):
		return _loaded[path]
	if not ResourceLoader.exists(path):
		if not _missing.has(path):
			_missing.append(path)
			push_warning("Font resource is missing: %s" % path)
		_loaded[path] = null
		return null
	var loaded := ResourceLoader.load(path) as FontFile
	if loaded == null:
		if not _missing.has(path):
			_missing.append(path)
			push_warning("Font resource could not be loaded: %s" % path)
	_loaded[path] = loaded
	return loaded

static func _fallback_font(path: String, primary_path: String, primary: Font) -> FontFile:
	var key := "%s:%s" % [primary_path, path]
	if _fallbacks.has(key):
		return _fallbacks[key]
	var source := _load_font(path)
	if source == null:
		return null
	var fallback := source.duplicate() as FontFile
	if fallback == null:
		return source
	fallback.fallbacks = []
	fallback.allow_system_fallback = false
	# Font.get_height() includes every fallback even when no glyph uses it.
	# Keep fallback outlines/advances unchanged; bound only their line metrics to
	# this locale's primary face. Arabic locales retain native Arabic metrics.
	# Godot FontFile.set_cache_ascent/descent are runtime raster-cache overrides.
	# https://docs.godotengine.org/en/4.7/classes/class_fontfile.html
	# https://github.com/godotengine/godot/blob/4.7/scene/resources/font.cpp
	for font_size in range(1, METRIC_CACHE_MAX_SIZE + 1):
		fallback.get_height(font_size)
		fallback.set_cache_ascent(0, font_size, minf(fallback.get_cache_ascent(0, font_size), primary.get_ascent(font_size)))
		fallback.set_cache_descent(0, font_size, minf(fallback.get_cache_descent(0, font_size), primary.get_descent(font_size)))
	_fallbacks[key] = fallback
	return fallback

static func _touch(key: String) -> void:
	_cache_order.erase(key)
	_cache_order.append(key)
