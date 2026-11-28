extends RefCounted
## Locale-aware, bounded font resources shared by Paper UI and custom drawing.
##
## Type roles (design/runtime/type-system.md):
## * body    - Snapland Rounded (jf open huninn 2.1 with the 4:3 line box baked in by
##             tools/fonts/bake_line_box.py), the face every Control inherits (current_font()).
## * display - the same face emboldened, for titles, captions and big feedback words.
## * numeral - Snapland Digits (Fredoka Bold, same line box); CJK units use the body face.
## * pixel   - Fusion Pixel 12px (whose Traditional Chinese comes from Cubic 11), for
##             pixel-art signage drawn at whole-texel sizes.
## The "readable" style swaps body and display to Noto Sans CJK for players who
## find the rounded face harder to read; numerals and pixel stay the same.

const ROUNDED_PATH := "res://assets/fonts/rounded/SnaplandRounded-Regular.ttf"
const NUMERAL_PATH := "res://assets/fonts/rounded/SnaplandDigits-Bold.ttf"
const CJK_PATH := "res://assets/fonts/NotoSansCJKtc-Regular.otf"
const PIXEL_PATHS := {
	"zh_TW": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-zh_tw.otf",
	"en": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-latin.otf",
	"ja": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-ja.otf",
	"ko": "res://assets/fonts/pixel/fusion-pixel-12px-proportional-ko.otf",
}
const ARABIC_PATH := "res://assets/fonts/NotoSansArabic.ttf"
const SYMBOLS_PATH := "res://assets/fonts/NotoSansSymbols2.ttf"
const STYLES := ["rounded", "pixel", "readable"]
const ROLES := ["body", "display", "numeral", "pixel"]
const CACHE_LIMIT := 12
# Covers Paper UI sizes including its maximum accessibility text scale.
const METRIC_CACHE_MAX_SIZE := 128
## Every primary face has the 4:3 line box the interface was laid out for
## (Fusion Pixel's native 1.333 em); the rounded faces carry it in their own metrics.
const LINE_EM := 4.0 / 3.0
## Extra weight of the display role, in em fractions (FontVariation.variation_embolden).
const DISPLAY_EMBOLDEN := 0.55

static var _style := "rounded"
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
	# Anything drawn with the engine default (ThemeDB.fallback_font, or a Control
	# outside the Paper theme) gets the game's face too, never an OS font (ART-74).
	ThemeDB.fallback_font = _active_font
	return _active_font

static func font_for_locale(locale_id: String, style: String = "") -> Font:
	var normalized_locale := _locale_key(locale_id)
	var normalized_style := _style if style.is_empty() else _normalized_style(style)
	return _font_for_key(normalized_locale, normalized_style)

## The font of one type role for the active locale and style (see the header).
static func role_font(role: String) -> Font:
	match role:
		"display":
			return _display_for(_active_locale, _style)
		"numeral":
			return _numeral_for(_active_locale)
		"pixel":
			return _font_for_key(_active_locale, "pixel")
	return _active_font

static func _display_for(locale_key: String, style: String) -> Font:
	var key := "%s:%s:display" % [locale_key, style]
	if _cache.has(key):
		_touch(key)
		return _cache[key]
	var base := _font_for_key(locale_key, style)
	var display := FontVariation.new()
	display.base_font = base
	# Arabic keeps its own weight; emboldening joins its letters badly.
	display.variation_embolden = 0.0 if locale_key == "qa_rtl" else DISPLAY_EMBOLDEN
	display.fallbacks = base.fallbacks
	return _remember(key, display)

static func _numeral_for(locale_key: String) -> Font:
	var key := "%s:numeral" % locale_key
	if _cache.has(key):
		_touch(key)
		return _cache[key]
	var digits := _duplicate_profile_font(NUMERAL_PATH, false)
	if not digits is FontFile:
		return _font_for_key(locale_key, "rounded")
	# Units and labels beside the digits fall back to the rounded body; every
	# fallback is bounded to the digits' line box so RTL keeps the same height.
	var chain: Array[Font] = []
	for path in [ROUNDED_PATH, CJK_PATH, ARABIC_PATH, SYMBOLS_PATH]:
		var fallback := _fallback_font(path, NUMERAL_PATH, digits)
		if fallback != null:
			chain.append(fallback)
	digits.fallbacks = chain
	return _remember(key, digits)

static func _font_for_key(normalized_locale: String, style: String) -> Font:
	var key := "%s:%s" % [normalized_locale, style]
	if _cache.has(key):
		_touch(key)
		return _cache[key]
	var regional_path := str(PIXEL_PATHS.get(normalized_locale, PIXEL_PATHS["en"]))
	var primary_path := ARABIC_PATH if normalized_locale == "qa_rtl" else (regional_path if style == "pixel" else (CJK_PATH if style == "readable" else ROUNDED_PATH))
	var primary := _duplicate_profile_font(primary_path, style == "pixel")
	var fallback_paths: Array[String] = []
	if style == "pixel":
		fallback_paths.assign([CJK_PATH, ARABIC_PATH, SYMBOLS_PATH])
		if normalized_locale == "qa_rtl":
			fallback_paths.append(str(PIXEL_PATHS["en"]))
	elif style == "readable":
		fallback_paths.assign([str(PIXEL_PATHS["en"]) if normalized_locale == "qa_rtl" else regional_path, CJK_PATH if normalized_locale == "qa_rtl" else ARABIC_PATH, SYMBOLS_PATH])
	else:
		# Rounded: huninn has no Hangul and only common kanji; Noto CJK fills those in.
		# Fusion last: it alone carries a few pictographs the park signs use (⚓ ⚙).
		fallback_paths.assign([ROUNDED_PATH, CJK_PATH, SYMBOLS_PATH, regional_path] if normalized_locale == "qa_rtl" else [CJK_PATH, ARABIC_PATH, SYMBOLS_PATH, regional_path])
	var profile_fallbacks: Array[Font] = []
	for fallback_path in fallback_paths:
		var fallback := _fallback_font(fallback_path, primary_path, primary)
		if primary is FontFile and fallback != null and fallback != primary and not profile_fallbacks.has(fallback):
			profile_fallbacks.append(fallback)
	primary.fallbacks = profile_fallbacks
	return _remember(key, primary)

static func _remember(key: String, font: Font) -> Font:
	_cache[key] = font
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return font

static func _normalized_style(style: String) -> String:
	return style if STYLES.has(style) else "rounded"

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
