extends RefCounted
class_name TimeOfDay

## Canonical park time phases. World lighting reads these profiles; UI and save
## data use only the stable phase IDs.

const DEFAULT_PHASE := "noon"
const ACHIEVEMENT_ALL_POSTCARDS := "ACH_ALL_TIME_POSTCARDS"
const PHASES := [
	{
		"id": "dawn", "label": "凌晨", "clock": "05:30",
		"sky_color": Color("#91a9c3"), "ambient_color": Color("#efb996"), "ambient_energy": 0.72,
		"key_color": Color("#ffd0a1"), "key_energy": 0.82, "key_rotation_degrees": Vector3(-16.0, -112.0, 0.0),
	},
	{
		"id": "noon", "label": "中午", "clock": "12:00",
		"sky_color": Color("#9bc9d9"), "ambient_color": Color("#fff0d2"), "ambient_energy": 1.0,
		"key_color": Color("#fff1cf"), "key_energy": 1.25, "key_rotation_degrees": Vector3(-52.0, -145.0, 0.0),
	},
	{
		"id": "dusk", "label": "傍晚", "clock": "18:15",
		"sky_color": Color("#c57f78"), "ambient_color": Color("#e3a18d"), "ambient_energy": 0.70,
		"key_color": Color("#ffad83"), "key_energy": 0.76, "key_rotation_degrees": Vector3(-12.0, 35.0, 0.0),
	},
	{
		"id": "night", "label": "晚上", "clock": "21:00",
		"sky_color": Color("#34415f"), "ambient_color": Color("#7186ad"), "ambient_energy": 0.46,
		"key_color": Color("#b8ceff"), "key_energy": 0.30, "key_rotation_degrees": Vector3(-26.0, 32.0, 0.0),
	},
]


static func phase_ids() -> Array[String]:
	var ids: Array[String] = []
	for data: Dictionary in PHASES:
		ids.append(str(data.id))
	return ids


static func normalize(value: Variant) -> String:
	if typeof(value) == TYPE_BOOL:
		return "night" if value else "noon"
	if typeof(value) != TYPE_STRING:
		return DEFAULT_PHASE
	var phase_id := str(value).strip_edges().to_lower()
	if phase_id in ["day", "daytime"]:
		return "noon"
	return phase_id if phase_id in phase_ids() else DEFAULT_PHASE


static func phase_for_id(value: Variant) -> Dictionary:
	var phase_id := normalize(value)
	for data: Dictionary in PHASES:
		if data.id == phase_id:
			return data.duplicate(true)
	return {}


static func index_of(value: Variant) -> int:
	return phase_ids().find(normalize(value))


static func next_phase(value: Variant, step: int = 1) -> String:
	var ids := phase_ids()
	return ids[posmod(index_of(value) + step, ids.size())]


static func postcard_id(value: Variant) -> String:
	return "postcard-time-%s" % normalize(value)


static func all_postcard_ids() -> Array[String]:
	var ids: Array[String] = []
	for phase_id in phase_ids():
		ids.append(postcard_id(phase_id))
	return ids
