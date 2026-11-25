extends RefCounted

const ORDER := ["welcome", "harbor", "candy", "nightmarket", "circus", "toy", "garden"]
const ROUTES := {
	"welcome": {"title": "迎賓大道", "map": "今天想去哪一邊？", "threshold": 0, "travel_button": ""},
	"harbor": {"title": "潮汐碼頭", "map": "潮汐碼頭 · 燈塔與環岸步道", "threshold": 6, "travel_button": "TravelHarborButton"},
	"candy": {"title": "糖果工廠", "map": "糖果工廠 · 材料與輸送廊", "threshold": 6, "travel_button": "TravelCandyButton"},
	"nightmarket": {"title": "霓虹夜市", "map": "霓虹夜市 · 攤街與雨棚", "threshold": 6, "travel_button": "TravelNightmarketButton"},
	"circus": {"title": "鏡之馬戲團", "map": "鏡之馬戲團 · 帳篷步道", "threshold": 30, "travel_button": "TravelCircusButton"},
	"toy": {"title": "發條玩具城", "map": "發條玩具城 · 工坊街區", "threshold": 30, "travel_button": "TravelToyButton"},
	"garden": {"title": "苔光溫室", "map": "苔光溫室 · 木棧道與葉臺", "threshold": 30, "travel_button": "TravelGardenButton"},
}

static func supports(region: String) -> bool:
	return ROUTES.has(region)

static func title(region: String) -> String:
	return ROUTES.get(region, ROUTES.welcome).title

static func map_title(region: String) -> String:
	return ROUTES.get(region, ROUTES.welcome).map

static func threshold(region: String) -> int:
	return ROUTES.get(region, ROUTES.welcome).threshold

static func travel_button(region: String) -> String:
	return ROUTES.get(region, ROUTES.welcome).travel_button
