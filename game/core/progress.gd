extends Node

signal changed
signal achievement_unlocked(id: String)

const SAVE_FILE := "user://progress.json"
const SAVE_VERSION := 1
const DEFAULT_SETTINGS := {
	"master_volume": 0.7,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"reduced_motion": false,
	"text_speed": 1.0,
	"assist": false,
	"fullscreen": false,
}
const WELCOME_GAME_IDS := [
	"game-001", "game-002", "game-003", "game-004", "game-005", "game-006",
	"game-007", "game-008", "game-009", "game-010", "game-011", "game-012",
]
const ZONES := ["welcome", "harbor", "candy", "nightmarket", "circus", "toy", "garden", "hotel", "sky", "cinema"]

var photos: Dictionary = {}
var achievements: Dictionary = {}
var quests: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var visited: Dictionary = {}
var intro_seen := false
var platform_pending_achievements: Array[String] = []
var _extra_fields: Dictionary = {}
var _loading := false

func _ready() -> void:
	changed.connect(_on_changed)
	load_progress()

func grant_photo(source_id: String, metadata: Dictionary = {}) -> bool:
	if source_id.is_empty():
		return false
	if photos.has(source_id):
		return false
	photos[source_id] = metadata.duplicate(true)
	changed.emit()
	return true

func complete_game(game_id: String, devil: bool, assisted: bool = false) -> void:
	var game_number := _welcome_game_number(game_id)
	if game_number == 0:
		return
	grant_photo("photo-welcome-game-%d" % game_number, {"game_id": game_id, "assisted": assisted, "devil": false})
	if devil:
		grant_photo("photo-welcome-devil-%d" % game_number, {"game_id": game_id, "assisted": assisted, "devil": true})
	_unlock("ACH_GAME_%03d" % game_number)
	if _has_complete_game_set("welcome", false):
		_unlock("ACH_WELCOME_CLEAR")
	if _has_complete_game_set("welcome", true):
		_unlock("ACH_WELCOME_DEVILS")
	var all_devils := true
	for zone in ZONES:
		if devil_count(zone) < 12:
			all_devils = false
			break
	if all_devils:
		_unlock("ACH_ALL_DEVILS")
	changed.emit()

func advance_quest(id: String, step: int) -> void:
	if id.is_empty() or step < 0:
		return
	quests[id] = maxi(int(quests.get(id, 0)), mini(step, 3))
	changed.emit()

func save_progress() -> bool:
	var path := _save_path()
	var directory := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			push_error("Cannot create progress directory '%s': %s" % [directory, error_string(mkdir_error)])
			return false
	var payload := _extra_fields.duplicate(true)
	payload.merge({
		"version": SAVE_VERSION,
		"photos": photos,
		"achievements": achievements,
		"quests": quests,
		"settings": settings,
		"visited": visited,
		"intro_seen": intro_seen,
		"platform_pending_achievements": platform_pending_achievements,
	}, true)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write progress temporary file '%s': %s" % [temporary, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Cannot flush progress temporary file '%s': %s" % [temporary, error_string(write_error)])
		return false
	var backup := path + ".bak"
	if FileAccess.file_exists(backup):
		var remove_backup_error := DirAccess.remove_absolute(backup)
		if remove_backup_error != OK:
			push_error("Cannot replace progress backup '%s': %s" % [backup, error_string(remove_backup_error)])
			return false
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(path, backup)
		if backup_error != OK:
			push_error("Cannot preserve previous progress at '%s': %s" % [backup, error_string(backup_error)])
			return false
	var commit_error := DirAccess.rename_absolute(temporary, path)
	if commit_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		push_error("Cannot atomically replace progress file '%s': %s" % [path, error_string(commit_error)])
		return false
	return true

func load_progress() -> void:
	var path := _save_path()
	var parsed := _read_save(path)
	var backup := path + ".bak"
	if parsed.is_empty() and (FileAccess.file_exists(path) or FileAccess.file_exists(backup)):
		if FileAccess.file_exists(path):
			push_error("Invalid progress data at '%s'; attempting backup." % path)
		else:
			push_warning("Progress file '%s' is missing; attempting backup '%s'." % [path, backup])
		parsed = _read_save(backup)
		if not parsed.is_empty():
			push_warning("Recovered progress from backup '%s'." % backup)
	if parsed.is_empty():
		_reset_memory()
		return
	_apply_save(parsed)
	changed.emit()

func reset_progress() -> void:
	_reset_memory()
	changed.emit()

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	var default_value: Variant = DEFAULT_SETTINGS[key]
	if typeof(default_value) == TYPE_BOOL:
		if typeof(value) != TYPE_BOOL:
			return
		settings[key] = value
	else:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return
		if key.ends_with("_volume"):
			settings[key] = clampf(float(value), 0.0, 1.0)
		else:
			settings[key] = clampf(float(value), 0.5, 2.0)
	_apply_setting(key)
	changed.emit()

func normal_count() -> int:
	var count := 0
	for source_id in photos:
		if _is_canonical_normal_photo(str(source_id)):
			count += 1
	return count

func normal_count_for_zone(zone: String) -> int:
	var count := 0
	for source_id in photos:
		if _is_canonical_normal_photo(str(source_id), zone):
			count += 1
	return count

func devil_count(zone: String = "welcome") -> int:
	if not ZONES.has(zone):
		return 0
	var count := 0
	for index in range(1, 13):
		if photos.has("photo-%s-devil-%d" % [zone, index]):
			count += 1
	return count

func _unlock(id: String) -> void:
	if achievements.has(id):
		return
	achievements[id] = true
	achievement_unlocked.emit(id)
	changed.emit()

func _welcome_game_number(game_id: String) -> int:
	var index := WELCOME_GAME_IDS.find(game_id)
	return index + 1 if index >= 0 else 0

func _has_complete_game_set(zone: String, devil: bool) -> bool:
	for index in range(1, 13):
		var card_id := "photo-%s-game-%d" % [zone, index]
		if devil:
			card_id = "photo-%s-devil-%d" % [zone, index]
		if not photos.has(card_id):
			return false
	return true

func _is_canonical_normal_photo(source_id: String, only_zone := "") -> bool:
	for zone in ZONES:
		if not only_zone.is_empty() and zone != only_zone:
			continue
		for index in range(1, 13):
			if source_id == "photo-%s-game-%d" % [zone, index]:
				return true
		if zone == "welcome":
			for index in range(1, 4):
				if source_id == "photo-welcome-explore-%d" % index:
					return true
			if source_id in ["photo-welcome-story-1", "photo-welcome-quest-1", "photo-welcome-quest-2"]:
				return true
	return false

func _save_path() -> String:
	var override_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	return override_path if not override_path.is_empty() else ProjectSettings.globalize_path(SAVE_FILE)

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read progress file '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Corrupt progress file '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return _validated_payload(json.data, path)

func _validated_payload(payload: Dictionary, path: String) -> Dictionary:
	var result := payload.duplicate(true)
	for key in ["photos", "achievements", "quests", "settings", "visited"]:
		if result.has(key) and typeof(result[key]) != TYPE_DICTIONARY:
			push_error("Invalid '%s' field in progress file '%s'; using defaults for that field." % [key, path])
			result.erase(key)
	if result.has("quests") and typeof(result["quests"]) == TYPE_DICTIONARY:
		var safe_quests: Dictionary = result["quests"]
		for quest_id: Variant in safe_quests.keys():
			if not _valid_quest_step(safe_quests[quest_id]):
				push_error("Invalid quest step for '%s' in progress file '%s'; using default." % [str(quest_id), path])
				safe_quests.erase(quest_id)
	if result.has("settings") and typeof(result["settings"]) == TYPE_DICTIONARY:
		var safe_settings: Dictionary = result["settings"]
		for key: Variant in DEFAULT_SETTINGS.keys():
			if not safe_settings.has(key):
				continue
			var value: Variant = safe_settings[key]
			var default_value: Variant = DEFAULT_SETTINGS[key]
			var valid := typeof(default_value) == TYPE_BOOL and typeof(value) == TYPE_BOOL
			if typeof(default_value) in [TYPE_INT, TYPE_FLOAT]:
				valid = typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
				if valid:
					var low := 0.0 if str(key).ends_with("_volume") else 0.5
					var high := 1.0 if str(key).ends_with("_volume") else 2.0
					valid = float(value) >= low and float(value) <= high
			if not valid:
				push_error("Invalid setting '%s' in progress file '%s'; using default." % [str(key), path])
				safe_settings.erase(key)
	if result.has("platform_pending_achievements") and typeof(result["platform_pending_achievements"]) != TYPE_ARRAY:
		push_error("Invalid 'platform_pending_achievements' field in progress file '%s'; using defaults." % path)
		result.erase("platform_pending_achievements")
	for key in ["intro_seen"]:
		if result.has(key) and typeof(result[key]) != TYPE_BOOL:
			push_error("Invalid '%s' field in progress file '%s'; using default." % [key, path])
			result.erase(key)
	return result

func _apply_save(payload: Dictionary) -> void:
	_loading = true
	_reset_memory()
	for key in payload:
		if key not in ["version", "photos", "achievements", "quests", "settings", "visited", "intro_seen", "platform_pending_achievements"]:
			_extra_fields[key] = payload[key]
	var loaded_photos: Variant = payload.get("photos", {})
	if typeof(loaded_photos) == TYPE_DICTIONARY:
		for key in loaded_photos:
			if typeof(loaded_photos[key]) == TYPE_DICTIONARY:
				photos[str(key)] = loaded_photos[key]
	var loaded_achievements: Variant = payload.get("achievements", {})
	if typeof(loaded_achievements) == TYPE_DICTIONARY:
		for key in loaded_achievements:
			if loaded_achievements[key] == true:
				achievements[str(key)] = true
	var loaded_quests: Variant = payload.get("quests", {})
	if typeof(loaded_quests) == TYPE_DICTIONARY:
		for key in loaded_quests:
			if _valid_quest_step(loaded_quests[key]):
				quests[str(key)] = int(loaded_quests[key])
	var loaded_settings: Variant = payload.get("settings", {})
	if typeof(loaded_settings) == TYPE_DICTIONARY:
		for setting_key: Variant in loaded_settings.keys():
			if DEFAULT_SETTINGS.has(setting_key):
				_apply_loaded_setting(str(setting_key), loaded_settings[setting_key])
			else:
				settings[str(setting_key)] = loaded_settings[setting_key]
	var loaded_visited: Variant = payload.get("visited", {})
	if typeof(loaded_visited) == TYPE_DICTIONARY:
		for key in loaded_visited:
			if loaded_visited[key] == true:
				visited[str(key)] = true
	intro_seen = payload.get("intro_seen", false) == true
	var loaded_pending: Variant = payload.get("platform_pending_achievements", [])
	if typeof(loaded_pending) == TYPE_ARRAY:
		for achievement_id in loaded_pending:
			if typeof(achievement_id) == TYPE_STRING and not achievement_id.is_empty() and not platform_pending_achievements.has(achievement_id):
				platform_pending_achievements.append(achievement_id)
	_loading = false

func _apply_loaded_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	var default_value: Variant = DEFAULT_SETTINGS[key]
	if typeof(default_value) == TYPE_BOOL:
		if typeof(value) == TYPE_BOOL:
			settings[key] = value
	else:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
			settings[key] = clampf(float(value), 0.0, 1.0) if key.ends_with("_volume") else clampf(float(value), 0.5, 2.0)
	_apply_setting(key)

func _valid_quest_step(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	var numeric := float(value)
	return numeric >= 0.0 and numeric <= 3.0 and floor(numeric) == numeric

func _apply_setting(key: String) -> void:
	# AudioDirector combines master and channel gains on each player. Keep the
	# global Master bus at unity so master_volume is applied exactly once.
	if key == "fullscreen" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_changed() -> void:
	if not _loading:
		save_progress()

func _reset_memory() -> void:
	photos = {}
	achievements = {}
	quests = {}
	settings = DEFAULT_SETTINGS.duplicate(true)
	visited = {}
	intro_seen = false
	platform_pending_achievements = []
	_extra_fields = {}
