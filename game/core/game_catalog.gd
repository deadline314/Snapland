extends RefCounted

const DATA_PATHS := {"welcome": "res://game/data/welcome_games.json", "harbor": "res://game/data/harbor_games.json"}
const ZONE_STARTS := {"welcome": 1, "harbor": 13}
const ZONE_COUNTS := {"welcome": 12, "harbor": 9}
const TEXT_FIELDS := ["id", "mode", "name", "goal", "instructions", "devil_hint", "devil", "ordinary", "attraction_tag", "island_invitation"]
static var _cache: Dictionary = {}

static func definitions(zone: String = "welcome") -> Array:
	_load_catalog()
	return _cache.get(zone, []).duplicate(true)

static func all_definitions() -> Array:
	return definitions() + definitions("harbor")

static func find(id_or_mode: String) -> Dictionary:
	for definition: Dictionary in all_definitions():
		if definition.id == id_or_mode or definition.mode == id_or_mode:
			return definition
	return {}

static func identity(id_or_mode: String) -> Dictionary:
	_load_catalog()
	for zone: String in DATA_PATHS:
		var rows: Array = _cache.get(zone, [])
		for index in range(rows.size()):
			var row: Dictionary = rows[index]
			if row.id != id_or_mode and row.mode != id_or_mode:
				continue
			return {"id": row.id, "mode": row.mode, "zone": zone, "local_index": index + 1,
				"photo_id": "photo-%s-game-%d" % [zone, index + 1],
				"devil_photo_id": "photo-%s-devil-%d" % [zone, index + 1],
				"achievement_id": "ACH_GAME_%03d" % (int(ZONE_STARTS[zone]) + index)}
	return {}

static func _load_catalog() -> void:
	if not _cache.is_empty():
		return
	var sources: Dictionary = {}
	for zone: String in DATA_PATHS:
		sources[zone] = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATHS[zone]))
	_cache = _validated_catalog(sources)
	if _cache.is_empty():
		push_error("Delivered game catalog has invalid runtime data.")

static func _validated_catalog(sources: Dictionary) -> Dictionary:
	if sources.size() != DATA_PATHS.size():
		return {}
	var seen_ids: Dictionary = {}
	var seen_modes: Dictionary = {}
	for zone: String in DATA_PATHS:
		var rows: Variant = sources.get(zone)
		if not rows is Array or rows.size() != ZONE_COUNTS[zone]:
			return {}
		for index in range(rows.size()):
			var row: Variant = rows[index]
			if not row is Dictionary:
				return {}
			for field: String in TEXT_FIELDS:
				if not row.get(field) is String or row[field].strip_edges().is_empty():
					return {}
			if row.id != "game-%03d" % (int(ZONE_STARTS[zone]) + index) or not row.mode.is_valid_identifier():
				return {}
			if seen_ids.has(row.id) or seen_modes.has(row.mode):
				return {}
			if row.has("zone") and row.zone != zone:
				return {}
			if row.has("local_index") and (typeof(row.local_index) not in [TYPE_INT, TYPE_FLOAT] or row.local_index != index + 1):
				return {}
			seen_ids[row.id] = true
			seen_modes[row.mode] = true
	return sources.duplicate(true)
