extends RefCounted

const DATA_PATHS := {"welcome": "res://game/data/welcome_games.json", "harbor": "res://game/data/harbor_games.json", "candy": "res://game/data/candy_games.json", "nightmarket": "res://game/data/nightmarket_games.json", "circus": "res://game/data/circus_games.json", "toy": "res://game/data/toy_games.json", "garden": "res://game/data/garden_games.json", "hotel": "res://game/data/hotel_games.json"}
const ZONE_STARTS := {"welcome": 1, "harbor": 13, "candy": 25, "nightmarket": 37, "circus": 49, "toy": 61, "garden": 73, "hotel": 85}
const ZONE_COUNTS := {"welcome": 12, "harbor": 12, "candy": 12, "nightmarket": 12, "circus": 9, "toy": 10, "garden": 7, "hotel": 1}
## A zone holds twelve numbered slots; a delivered game keeps its slot's number,
## so later zones may leave gaps (game-077 is the garden's fifth slot).
const ZONE_SLOTS := 12
const TEXT_FIELDS := ["id", "mode", "name", "goal", "instructions", "devil_hint", "devil", "ordinary", "attraction_tag", "island_invitation"]
static var _cache: Dictionary = {}

static func definitions(zone: String = "welcome") -> Array:
	_load_catalog()
	return _cache.get(zone, []).duplicate(true)

static func all_definitions() -> Array:
	var delivered: Array = []
	for zone: String in DATA_PATHS:
		delivered.append_array(definitions(zone))
	return delivered

static func find(id_or_mode: String) -> Dictionary:
	for definition: Dictionary in all_definitions():
		if definition.id == id_or_mode or definition.mode == id_or_mode:
			return definition
	return {}

static func identity(id_or_mode: String) -> Dictionary:
	_load_catalog()
	for zone: String in DATA_PATHS:
		var rows: Array = _cache.get(zone, [])
		for row: Dictionary in rows:
			if row.id != id_or_mode and row.mode != id_or_mode:
				continue
			var slot := _slot(zone, str(row.id))
			return {"id": row.id, "mode": row.mode, "zone": zone, "local_index": slot,
				"photo_id": "photo-%s-game-%d" % [zone, slot],
				"devil_photo_id": "photo-%s-devil-%d" % [zone, slot],
				"achievement_id": "ACH_GAME_%03d" % (int(ZONE_STARTS[zone]) + slot - 1)}
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
	var last_slot := 0
	var seen_modes: Dictionary = {}
	for zone: String in DATA_PATHS:
		var rows: Variant = sources.get(zone)
		if not rows is Array or rows.size() != ZONE_COUNTS[zone]:
			return {}
		last_slot = 0
		for index in range(rows.size()):
			var row: Variant = rows[index]
			if not row is Dictionary:
				return {}
			for field: String in TEXT_FIELDS:
				if not row.get(field) is String or row[field].strip_edges().is_empty():
					return {}
			# Slots rise in order inside the zone's twelve; gaps are slots still in design.
			var slot := _slot(zone, row.id)
			if slot <= last_slot or slot > ZONE_SLOTS or row.id != "game-%03d" % (int(ZONE_STARTS[zone]) + slot - 1) or not row.mode.is_valid_identifier():
				return {}
			last_slot = slot
			if seen_ids.has(row.id) or seen_modes.has(row.mode):
				return {}
			if row.has("zone") and row.zone != zone:
				return {}
			if row.has("local_index") and (typeof(row.local_index) not in [TYPE_INT, TYPE_FLOAT] or row.local_index != slot):
				return {}
			seen_ids[row.id] = true
			seen_modes[row.mode] = true
	return sources.duplicate(true)


## 1..12 inside the zone for a well-formed id, else 0.
static func _slot(zone: String, id: String) -> int:
	if not id.begins_with("game-") or not id.trim_prefix("game-").is_valid_int():
		return 0
	return id.trim_prefix("game-").to_int() - int(ZONE_STARTS[zone]) + 1
