extends RefCounted
## Authored visits register through stable story, interaction and collection IDs.

const NIGHTMARKET := "nightmarket"
const NIGHTMARKET_POINT := "nightmarket:story"
const NIGHTMARKET_PHOTO := "photo-nightmarket-story-1"
const VISITS := {
	NIGHTMARKET: {
		"id": NIGHTMARKET_PHOTO,
		"title": "倒數先吃宵夜",
		"instructions": "到夜市入口找阿浪，在燈牌下合照。",
		"lines": [
			{"speaker": "阿浪", "text": "我把『最後一份宵夜』喊成『最後一場宵夜』，全攤都抬頭等開演。"},
			{"speaker": "主角", "text": "那我先吃完，再鼓掌。"},
			{"speaker": "阿浪", "text": "幕幕倒是真的在籌備首演。他把開場白寫在點心紙上，差點跟著外送走。"},
			{"speaker": "阿浪", "text": "來燈牌下合張照。等他開演，就拿這張當我們的報到照！"},
		],
	},
}

static func photo_id(region: String) -> String:
	return str(VISITS.get(region, {}).get("id", ""))

static func title(region: String) -> String:
	return str(VISITS.get(region, {}).get("title", ""))

static func lines(region: String) -> Array:
	return VISITS.get(region, {}).get("lines", [])

static func entry(region: String) -> Dictionary:
	var visit: Dictionary = VISITS.get(region, {})
	if visit.is_empty():
		return {}
	return {"id": visit.id, "title": visit.title, "instructions": visit.instructions, "story_region": region}
