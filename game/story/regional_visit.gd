extends RefCounted
## Authored visits register through stable story, interaction and collection IDs.

const NIGHTMARKET := "nightmarket"
const NIGHTMARKET_POINT := "nightmarket:story"
const NIGHTMARKET_PHOTO := "photo-nightmarket-story-1"
const CIRCUS := "circus"
const CIRCUS_POINT := "circus:story"
const CIRCUS_PHOTO := "photo-circus-story-1"
const VISITS := {
	NIGHTMARKET: {
		"id": NIGHTMARKET_PHOTO,
		"point": NIGHTMARKET_POINT,
		"host": "阿浪",
		"saved_notice": "夜市造訪已登記，合照收進本子裡。",
		"title": "倒數先吃宵夜",
		"instructions": "到夜市入口找阿浪，在燈牌下合照。",
		"lines": [
			{"speaker": "阿浪", "text": "我把『最後一份宵夜』喊成『最後一場宵夜』，全攤都抬頭等開演。"},
			{"speaker": "主角", "text": "那我先吃完，再鼓掌。"},
			{"speaker": "阿浪", "text": "幕幕倒是真的在籌備首演。他把開場白寫在點心紙上，差點跟著外送走。"},
			{"speaker": "阿浪", "text": "來燈牌下合張照。等他開演，就拿這張當我們的報到照！"},
		],
	},
	CIRCUS: {
		"id": CIRCUS_PHOTO,
		"point": CIRCUS_POINT,
		"host": "小角",
		"saved_notice": "馬戲團造訪已登記，合照收進本子裡。",
		"title": "尾巴先報幕",
		"instructions": "到鏡之馬戲團入口找小角，在帳篷裡合照。",
		"lines": [
			{"speaker": "小角", "text": "我剛練習報幕，鏡子裡的小角比我先鞠躬。"},
			{"speaker": "主角", "text": "你們分工真好。誰負責藏尾巴？"},
			{"speaker": "小角", "text": "尾巴才不肯排練。幕幕還在改首演的開場白，先合張照幫他試試燈吧。"},
		],
	},
}

static func point_id(region: String) -> String:
	return str(VISITS.get(region, {}).get("point", ""))

static func host_name(region: String) -> String:
	return str(VISITS.get(region, {}).get("host", ""))

static func saved_notice(region: String) -> String:
	return str(VISITS.get(region, {}).get("saved_notice", ""))

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
