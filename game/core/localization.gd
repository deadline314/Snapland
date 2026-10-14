extends Node
## Stable message IDs and guarded locale-pack loading.

signal locale_changed(locale_id: String)

const MANIFEST_PATH := "res://game/data/locales/manifest.json"
const BASE_LOCALE := "zh_TW"
const PACK_ROOT := "res://game/data/locales/"
const SCHEMA_VERSION := 1
const EMBEDDED_BASE_PLURALS := {
	"hud.photo_count": {"singular_id": "photo.count.one", "plural_id": "photo.count.other", "forms": ["{count} 張拍貼"]},
}
const EMBEDDED_BASE_SOURCES := {
	"settings.audio": "聲音",
	"settings.play": "遊玩與畫面",
	"settings.controls": "操作",
	"settings.text": "語言與文字",
	"settings.locale": "介面語言",
	"settings.font_style": "文字風格",
	"settings.audio.title": "音訊與文字速度",
	"settings.master_volume": "總音量",
	"settings.music_volume": "背景音樂",
	"settings.sfx_volume": "互動音效",
	"settings.text_speed": "對話文字速度",
	"settings.play.title": "遊玩方式與畫面",
	"settings.assist": "輔助遊玩：放寬時間與判定，仍可收藏",
	"settings.reduced_motion": "降低動態：停止水波與裝飾擺動",
	"settings.fullscreen": "使用全螢幕",
	"settings.ui_scale": "文字大小",
	"settings.ui_scale.hint": "文字大小會放大介面文字；按鈕仍維持完整操作高度。",
	"settings.controls.title": "鍵盤操作",
	"controls.move": "移動",
	"controls.walk": "慢走",
	"controls.interact": "互動",
	"controls.greet": "招呼",
	"controls.photo": "拍照",
	"controls.wardrobe": "衣櫃",
	"controls.time": "時段",
	"controls.ticket": "旅券",
	"controls.pause": "暫停／返回",
	"controls.move.keys": "W A S D／方向鍵",
	"controls.walk.keys": "按住 Shift",
	"controls.interact.keys": "E",
	"controls.greet.keys": "F",
	"controls.photo.keys": "P",
	"controls.wardrobe.keys": "C",
	"controls.time.keys": "T",
	"controls.ticket.keys": "M",
	"controls.pause.keys": "Esc",
	"button.back": "返回遊園  ·  Esc",
	"font.pixel": "像素字型",
	"font.readable": "易讀字型",
	"locale.zh_TW": "繁體中文",
	"locale.en": "English（QA）",
	"pause.resume": "繼續遊園",
	"pause.album": "拍貼收藏本",
	"pause.settings": "設定與輔助",
	"pause.controls": "操作速查",
	"hud.normal_count": "普通 {count} / 18",
	"hud.devil_count": "小惡魔 {count} / 12",
	"hud.coins": "{count} 幣",
	"dialogue.example.one": "嗨，{name}！",
	"dialogue.example.many": "嗨，{name}！你有 {count} 張照片。",
	"rtl.mixed_numbers": "RTL QA：{name} — 123 / ٤٥٦",
}
var _manifest: Dictionary = {}
var _packs: Dictionary = {}
var _translations: Dictionary = {}
var _warned: Dictionary = {}
var _embedded_source_cache: Dictionary = {}
var _locale := BASE_LOCALE
var _initialized := false

func _ready() -> void:
	_load_manifest()
	set_locale(BASE_LOCALE)

func available_locales() -> Array[String]:
	var result: Array[String] = []
	for locale_id: Variant in _manifest.get("locales", {}).keys():
		var locale_meta: Dictionary = _manifest.locales[locale_id]
		if locale_meta.get("released", false) == true and locale_meta.get("qa_only", false) != true:
			result.append(str(locale_id))
	result.sort()
	return result

func locale() -> String:
	return _locale

func is_rtl() -> bool:
	var locales: Dictionary = _manifest.get("locales", {})
	var locale_meta: Dictionary = locales.get(_locale, {})
	return locale_meta.get("direction", "ltr") == "rtl"

func set_locale(locale_id: String, allow_unreleased: bool = false) -> bool:
	var requested_locale := locale_id
	var used_fallback := false
	var locales: Dictionary = _manifest.get("locales", {})
	var locale_meta: Dictionary = locales.get(locale_id, {})
	if locale_meta.is_empty() or (not allow_unreleased and locale_meta.get("released", false) != true):
		_warn_once("locale:" + locale_id, "Unknown or unreleased locale '%s' in %s; falling back to %s." % [locale_id, MANIFEST_PATH, BASE_LOCALE])
		locale_id = BASE_LOCALE
		used_fallback = true
	if not _load_pack(locale_id):
		_warn_once("pack:" + locale_id, "Cannot load locale pack '%s' from %s; falling back to zh_TW." % [locale_id, _pack_path(locale_id)])
		locale_id = BASE_LOCALE
		_load_pack(BASE_LOCALE)
		used_fallback = true
	var changed := _locale != locale_id
	if not changed and _initialized:
		return not used_fallback and requested_locale == locale_id
	_emit_translation(locale_id)
	_locale = locale_id
	TranslationServer.set_locale(locale_id)
	_initialized = true
	if changed:
		locale_changed.emit(locale_id)
	return not used_fallback and requested_locale == locale_id

func text(message_id: String, args: Dictionary = {}) -> String:
	var base: Dictionary = _packs.get(BASE_LOCALE, {})
	var base_entry: Dictionary = base.get("messages", {}).get(message_id, {})
	if base_entry.is_empty():
		_warn_once("key:" + message_id, "Missing localization key '%s' in %s; using embedded source fallback when available." % [message_id, _pack_path(BASE_LOCALE)])
		var fallback := str(_embedded_sources().get(message_id, message_id))
		return fallback.format(args) if _placeholders(fallback) == _argument_names(args) else fallback
	var entry: Dictionary = _packs.get(_locale, {}).get("messages", {}).get(message_id, {})
	var value := str(entry.get("text", ""))
	if value.is_empty():
		value = str(base_entry.get("text", base_entry.get("source", message_id)))
		_warn_once("entry:" + _locale + ":" + message_id, "Missing translation '%s' in %s; using zh_TW/source fallback." % [message_id, _pack_path(_locale)])
	var expected := _placeholders(value)
	if expected != _placeholders(str(base_entry.get("source", ""))):
		_warn_once("placeholder-pack:" + _locale + ":" + message_id, "Placeholder mismatch for '%s' in %s; using zh_TW." % [message_id, _pack_path(_locale)])
		value = str(base_entry.get("text", base_entry.get("source", message_id)))
		expected = _placeholders(value)
	if expected != _argument_names(args):
		_warn_once("placeholder-args:" + message_id, "Placeholder arguments do not match '%s' in %s; using zh_TW/source fallback." % [message_id, _pack_path(_locale)])
		return str(base_entry.get("text", base_entry.get("source", message_id)))
	return value.format(args)

func text_plural(message_id: String, count: int, args: Dictionary = {}) -> String:
	var base_plurals: Dictionary = _packs.get(BASE_LOCALE, {}).get("plurals", EMBEDDED_BASE_PLURALS)
	var base_entry: Dictionary = base_plurals.get(message_id, EMBEDDED_BASE_PLURALS.get(message_id, {}))
	if base_entry.is_empty():
		_warn_once("plural-key:" + message_id, "Missing plural localization key '%s' in %s; returning the count." % [message_id, _pack_path(BASE_LOCALE)])
		return str(count)
	var selected_plurals: Dictionary = _packs.get(_locale, {}).get("plurals", {})
	var selected: Dictionary = selected_plurals.get(message_id, {})
	var phrase := ""
	if selected.is_empty():
		phrase = str(base_entry.forms[0])
		_warn_once("plural-fallback:" + _locale + ":" + message_id, "Missing plural translation '%s' in %s; using zh_TW/source fallback." % [message_id, _pack_path(_locale)])
	else:
		phrase = str(TranslationServer.translate_plural(str(base_entry.singular_id), str(base_entry.plural_id), count))
		if phrase.is_empty() or phrase == str(base_entry.singular_id) or phrase == str(base_entry.plural_id) or _placeholders(phrase) != _placeholders(str(base_entry.forms[0])):
			phrase = str(base_entry.forms[0])
	var actual_args := args.duplicate()
	actual_args["count"] = count
	if _placeholders(phrase) != _argument_names(actual_args):
		_warn_once("plural-args:" + message_id, "Plural placeholder arguments do not match '%s' in %s; using zh_TW/source fallback." % [message_id, _pack_path(BASE_LOCALE)])
		phrase = str(base_entry.forms[0])
	return phrase.format(actual_args)

func _load_manifest() -> void:
	var parsed := _read_json(MANIFEST_PATH)
	if not _validate_manifest(parsed, MANIFEST_PATH):
		_warn_once("manifest", "Invalid locale manifest schema at %s; only embedded zh_TW fallback will be available." % MANIFEST_PATH)
		_manifest = _fallback_manifest()
	else:
		_manifest = parsed

func _load_pack(locale_id: String) -> bool:
	if _packs.has(locale_id):
		return true
	if locale_id != BASE_LOCALE and not _load_pack(BASE_LOCALE):
		return false
	var path := _pack_path(locale_id)
	return _load_pack_from_path(locale_id, path)

func _load_pack_from_path(locale_id: String, path: String) -> bool:
	var pack := _read_json(path)
	if _load_pack_data(locale_id, pack, path):
		return true
	_warn_once("invalid-pack:" + locale_id + ":" + path, "Invalid locale pack '%s' at %s; expected schema %d and valid messages." % [locale_id, path, SCHEMA_VERSION])
	if locale_id == BASE_LOCALE:
		_install_embedded_base()
		return true
	return false

func _load_pack_data(locale_id: String, pack: Dictionary, path: String) -> bool:
	if not _validate_pack(pack, locale_id, path):
		return false
	_packs[locale_id] = pack
	return true

func _validate_manifest(candidate: Dictionary, path: String) -> bool:
	if not _is_schema_version(candidate.get("schema_version")):
		_warn_once("manifest-schema:" + path, "Invalid schema_version in %s; expected %d." % [path, SCHEMA_VERSION])
		return false
	if typeof(candidate.get("locales")) != TYPE_DICTIONARY or candidate.locales.is_empty():
		_warn_once("manifest-locales:" + path, "Invalid locales object in %s." % path)
		return false
	var candidate_locales: Dictionary = candidate.locales
	for locale_value: Variant in candidate_locales.keys():
		var locale_id := str(locale_value)
		var meta: Variant = candidate_locales[locale_value]
		if typeof(locale_value) != TYPE_STRING or not _valid_locale_id(locale_id) or typeof(meta) != TYPE_DICTIONARY:
			_warn_once("manifest-locale:" + path + ":" + locale_id, "Invalid locale metadata at %s locales.%s." % [path, locale_id])
			return false
		if typeof(meta.get("name")) != TYPE_STRING or str(meta.name).strip_edges().is_empty() or typeof(meta.get("released")) != TYPE_BOOL or typeof(meta.get("qa_only")) != TYPE_BOOL or typeof(meta.get("direction")) != TYPE_STRING or not ["ltr", "rtl"].has(meta.direction) or typeof(meta.get("pack")) != TYPE_STRING or not _valid_pack_filename(meta.pack):
			_warn_once("manifest-meta:" + path + ":" + locale_id, "Invalid locale metadata fields at %s locales.%s." % [path, locale_id])
			return false
		if meta.qa_only and meta.released:
			_warn_once("manifest-release:" + path + ":" + locale_id, "QA locale '%s' cannot be marked released in %s locales.%s." % [locale_id, path, locale_id])
			return false
	if not candidate_locales.has(BASE_LOCALE):
		_warn_once("manifest-base:" + path, "Base locale '%s' is missing from %s." % [BASE_LOCALE, path])
		return false
	var base_meta: Dictionary = candidate_locales[BASE_LOCALE]
	if not base_meta.released or base_meta.qa_only or base_meta.direction != "ltr":
		_warn_once("manifest-base-meta:" + path, "Base locale metadata is invalid at %s locales.%s." % [path, BASE_LOCALE])
		return false
	return true

func _validate_pack(candidate: Dictionary, locale_id: String, path: String) -> bool:
	var locale_meta: Dictionary = _manifest.get("locales", {}).get(locale_id, {})
	if candidate.is_empty() or not _is_schema_version(candidate.get("schema_version")) or typeof(candidate.get("locale")) != TYPE_STRING or candidate.locale != locale_id or typeof(candidate.get("direction")) != TYPE_STRING or candidate.direction != locale_meta.get("direction", "") or typeof(candidate.get("messages")) != TYPE_DICTIONARY:
		_warn_once("pack-header:" + locale_id + ":" + path, "Invalid schema_version, locale, direction, or messages header in %s for locale '%s'." % [path, locale_id])
		return false
	var messages: Dictionary = candidate.messages
	if locale_id == BASE_LOCALE and messages.is_empty():
		_warn_once("pack-empty-base:" + path, "Base messages are empty at %s messages; embedded source fallback is required." % path)
		return false
	var base_messages: Dictionary = _packs.get(BASE_LOCALE, {}).get("messages", {})
	for key_value: Variant in messages.keys():
		var message_id := str(key_value)
		var entry: Variant = messages[key_value]
		if typeof(key_value) != TYPE_STRING or not _valid_message_id(message_id) or typeof(entry) != TYPE_DICTIONARY:
			_warn_once("pack-entry:" + locale_id + ":" + path + ":" + message_id, "Invalid message entry at %s messages.%s." % [path, message_id])
			return false
		if typeof(entry.get("source")) != TYPE_STRING or typeof(entry.get("text")) != TYPE_STRING or str(entry.source).is_empty():
			_warn_once("pack-fields:" + locale_id + ":" + message_id, "Message fields source/text must be strings at %s messages.%s." % [path, message_id])
			return false
		if locale_id == BASE_LOCALE and _placeholders(entry.source) != _placeholders(entry.text):
			_warn_once("pack-base-placeholder:" + message_id, "Base source/text placeholders mismatch at %s messages.%s." % [path, message_id])
			return false
		if locale_id != BASE_LOCALE:
			var base_entry: Dictionary = base_messages.get(message_id, {})
			if base_entry.is_empty() or str(entry.source) != str(base_entry.source):
				_warn_once("pack-source:" + locale_id + ":" + message_id, "Message source does not match the base at %s messages.%s." % [path, message_id])
				return false
			if _placeholders(entry.text) != _placeholders(entry.source):
				_warn_once("pack-placeholder:" + locale_id + ":" + message_id, "Translated placeholders mismatch at %s messages.%s." % [path, message_id])
				return false
	if candidate.has("plurals") and typeof(candidate.plurals) != TYPE_DICTIONARY:
		_warn_once("pack-plurals:" + locale_id + ":" + path, "Invalid plurals object at %s plurals." % path)
		return false
	var plurals: Dictionary = candidate.get("plurals", {})
	var base_plurals: Dictionary = _packs.get(BASE_LOCALE, {}).get("plurals", {})
	for plural_value: Variant in plurals.keys():
		var plural_id := str(plural_value)
		var plural_entry: Variant = plurals[plural_value]
		if typeof(plural_value) != TYPE_STRING or not _valid_message_id(plural_id) or typeof(plural_entry) != TYPE_DICTIONARY or typeof(plural_entry.get("singular_id")) != TYPE_STRING or typeof(plural_entry.get("plural_id")) != TYPE_STRING or not _valid_message_id(str(plural_entry.get("singular_id", ""))) or not _valid_message_id(str(plural_entry.get("plural_id", ""))) or typeof(plural_entry.get("forms")) != TYPE_ARRAY or plural_entry.forms.is_empty() or plural_entry.forms.size() > 6:
			_warn_once("pack-plural-entry:" + locale_id + ":" + path + ":" + plural_id, "Invalid plural entry at %s plurals.%s." % [path, plural_id])
			return false
		for form_value: Variant in plural_entry.forms:
			if typeof(form_value) != TYPE_STRING:
				_warn_once("pack-plural-form:" + locale_id + ":" + plural_id, "Plural forms must be strings at %s plurals.%s.forms." % [path, plural_id])
				return false
		if locale_id == BASE_LOCALE:
			var base_form_placeholders := _placeholders(str(plural_entry.forms[0]))
			for form_value: Variant in plural_entry.forms:
				if _placeholders(str(form_value)) != base_form_placeholders:
					_warn_once("pack-plural-base-placeholder:" + plural_id, "Base plural placeholders mismatch at %s plurals.%s.forms." % [path, plural_id])
					return false
		if locale_id != BASE_LOCALE:
			var base_plural: Dictionary = base_plurals.get(plural_id, {})
			if base_plural.is_empty() or plural_entry.singular_id != base_plural.singular_id or plural_entry.plural_id != base_plural.plural_id:
				_warn_once("pack-plural-source:" + locale_id + ":" + plural_id, "Plural source IDs do not match the base at %s plurals.%s." % [path, plural_id])
				return false
			var expected_plural_placeholders := _placeholders(str(base_plural.forms[0]))
			for form_value: Variant in plural_entry.forms:
				if _placeholders(str(form_value)) != expected_plural_placeholders:
					_warn_once("pack-plural-placeholder:" + locale_id + ":" + plural_id, "Plural placeholders mismatch at %s plurals.%s.forms." % [path, plural_id])
					return false
	return true

func _emit_translation(locale_id: String) -> void:
	if _translations.has(locale_id):
		return
	var translation := _build_translation(locale_id)
	TranslationServer.add_translation(translation)
	_translations[locale_id] = translation

func _build_translation(locale_id: String) -> Translation:
	var translation := Translation.new()
	translation.locale = locale_id
	var messages: Dictionary = _packs.get(locale_id, {}).get("messages", {})
	var base_messages: Dictionary = _packs.get(BASE_LOCALE, {}).get("messages", {})
	for message_id: Variant in base_messages.keys():
		var base_entry: Dictionary = base_messages[message_id]
		var translated: Variant = messages.get(message_id, base_entry)
		var value := str(base_entry.get("text", base_entry.get("source", message_id)))
		if typeof(translated) == TYPE_DICTIONARY:
			var candidate_value := str(translated.get("text", ""))
			if _placeholders(candidate_value) == _placeholders(str(base_entry.get("source", ""))):
				value = candidate_value
			else:
				_warn_once("alias-placeholder:" + locale_id + ":" + str(message_id), "Skipping native source alias with mismatched placeholders at %s messages.%s." % [_pack_path(locale_id), str(message_id)])
		translation.add_message(str(message_id), value)
		var source := str(base_entry.get("source", ""))
		if not source.is_empty():
			translation.add_message(source, value)
	var base_plurals: Dictionary = _packs.get(BASE_LOCALE, {}).get("plurals", EMBEDDED_BASE_PLURALS)
	var locale_plurals: Dictionary = _packs.get(locale_id, {}).get("plurals", {})
	for plural_id: Variant in base_plurals.keys():
		var base_plural: Dictionary = base_plurals[plural_id]
		var selected: Variant = locale_plurals.get(plural_id, {})
		if typeof(selected) != TYPE_DICTIONARY or typeof(selected.get("forms")) != TYPE_ARRAY or selected.forms.is_empty():
			continue
		var forms: Array = selected.forms
		var valid_forms := true
		for form: Variant in forms:
			if typeof(form) != TYPE_STRING or _placeholders(str(form)) != _placeholders(str(base_plural.forms[0])):
				valid_forms = false
				break
		if not valid_forms or selected.get("singular_id") != base_plural.singular_id or selected.get("plural_id") != base_plural.plural_id:
			_warn_once("alias-plural-placeholder:" + locale_id + ":" + str(plural_id), "Skipping native plural alias with invalid placeholders or source IDs at %s plurals.%s." % [_pack_path(locale_id), str(plural_id)])
			continue
		translation.add_plural_message(str(base_plural.singular_id), PackedStringArray(forms))
	return translation

func _placeholders(value: String) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	for match_value in regex.search_all(value):
		var placeholder := match_value.get_string(1)
		if not seen.has(placeholder):
			seen[placeholder] = true
			result.append(placeholder)
	result.sort()
	return result

func _argument_names(args: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in args.keys():
		result.append(str(key))
	result.sort()
	return result

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var contents := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(contents) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _pack_path(locale_id: String) -> String:
	var locales: Dictionary = _manifest.get("locales", {})
	var meta: Dictionary = locales.get(locale_id, {})
	var filename := str(meta.get("pack", ""))
	if not _valid_pack_filename(filename):
		return PACK_ROOT + "<invalid-pack-name>"
	return PACK_ROOT + filename

func _install_embedded_base() -> void:
	if _translations.has(BASE_LOCALE):
		TranslationServer.remove_translation(_translations[BASE_LOCALE])
		_translations.erase(BASE_LOCALE)
	var messages: Dictionary = {}
	for message_id: Variant in _embedded_sources().keys():
		var source := str(_embedded_sources()[message_id])
		messages[str(message_id)] = {"source": source, "text": source}
	_packs[BASE_LOCALE] = {"schema_version": SCHEMA_VERSION, "locale": BASE_LOCALE, "direction": "ltr", "messages": messages, "plurals": EMBEDDED_BASE_PLURALS}
	_emit_translation(BASE_LOCALE)
	_warn_once("embedded-base", "Using embedded zh_TW source strings because %s is invalid or unavailable." % _pack_path(BASE_LOCALE))

func _embedded_sources() -> Dictionary:
	return EMBEDDED_BASE_SOURCES

func _is_schema_version(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return is_finite(numeric_value) and numeric_value == float(SCHEMA_VERSION)

func _fallback_manifest() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "locales": {BASE_LOCALE: {"name": "繁體中文", "released": true, "qa_only": false, "direction": "ltr", "pack": "zh_TW.json"}}}

func _valid_pack_filename(filename: Variant) -> bool:
	if typeof(filename) != TYPE_STRING or str(filename).is_empty():
		return false
	var value := str(filename)
	return value.get_file() == value and not value.contains("/") and not value.contains("\\") and value.ends_with(".json") and value != ".json" and value != "..json"

func _valid_locale_id(locale_id: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z][A-Za-z0-9_]{1,15}$")
	return regex.search(locale_id) != null

func _valid_message_id(message_id: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*$")
	return regex.search(message_id) != null

func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
