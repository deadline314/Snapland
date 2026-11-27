extends RefCounted
## The island's occasional events: one row each. The director (IslandEvents)
## picks among the rows whose phases match the island's time of day; the
## album and the save read the souvenir sticker ids and captions from here.
##
## phases: time-of-day ids it may start in. seconds: how long it runs.
## cooldown: free walking after it ends before any event may start again.
## weight: relative chance among the events allowed at that moment.

const SETTING := "island_events"
## Free walking before the first event of a visit.
const FIRST_DELAY := 150.0

const EVENTS := [
	{"id": "shower", "sticker": "event-shower", "title": "午後陣雨", "how": "陣雨時踩出三朵水花，雨停後拍下彩虹。",
		"phases": ["dawn", "noon"], "seconds": 100.0, "cooldown": 300.0, "weight": 1.0},
	{"id": "wind", "sticker": "event-wind", "title": "追風氣球", "how": "起風時追上被吹走的氣球。",
		"phases": ["noon", "dusk"], "seconds": 70.0, "cooldown": 300.0, "weight": 1.0},
	{"id": "fireworks", "sticker": "event-fireworks", "title": "海灣煙火", "how": "傍晚到海風觀景台，在煙火開到最大時按下快門。",
		"phases": ["dusk", "night"], "seconds": 90.0, "cooldown": 360.0, "weight": 1.0},
]


static func find(id: String) -> Dictionary:
	for row: Dictionary in EVENTS:
		if row.id == id: return row
	return {}


static func sticker_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in EVENTS:
		ids.append(str(row.sticker))
	return ids


static func for_sticker(sticker: String) -> Dictionary:
	for row: Dictionary in EVENTS:
		if row.sticker == sticker: return row
	return {}
