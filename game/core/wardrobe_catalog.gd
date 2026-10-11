extends RefCounted

const ITEMS := [
	{"id": "outfit-tide", "name": "海港外套・潮汐藍", "slot": "outfit", "price": 0, "color": "#4B9BB0", "itemdefid": 51001, "tradable": false, "marketable": false},
	{"id": "outfit-coral", "name": "海港外套・珊瑚紅", "slot": "outfit", "price": 80, "color": "#E87968", "itemdefid": 51002, "tradable": false, "marketable": false},
	{"id": "outfit-gold", "name": "海港外套・暖金黃", "slot": "outfit", "price": 100, "color": "#D8AB47", "itemdefid": 51003, "tradable": false, "marketable": false},
	{"id": "outfit-navy", "name": "海港外套・深海藍", "slot": "outfit", "price": 90, "color": "#364D78", "itemdefid": 51004, "tradable": false, "marketable": false},
	{"id": "hat-none", "name": "不戴帽子", "slot": "hat", "price": 0, "color": "#FFFFFF", "itemdefid": 51005, "tradable": false, "marketable": false},
	{"id": "hat-straw", "name": "草編遮陽帽", "slot": "hat", "price": 60, "color": "#D8BB77", "itemdefid": 51006, "tradable": false, "marketable": false},
	{"id": "hat-sailor", "name": "水手帽", "slot": "hat", "price": 70, "color": "#F2F1E8", "itemdefid": 51007, "tradable": false, "marketable": false},
	{"id": "hat-flower", "name": "海風花冠", "slot": "hat", "price": 50, "color": "#D8789B", "itemdefid": 51008, "tradable": false, "marketable": false},
]

const APPEARANCE_OPTIONS := {
	"skin": [
		{"id": "warm", "name": "暖淺色"}, {"id": "deep", "name": "深棕色"},
		{"id": "bronze", "name": "古銅色"}, {"id": "cool", "name": "冷白色"}, {"id": "olive", "name": "橄欖色"},
	],
	"species": [{"id": "human", "name": "人類"}, {"id": "elf", "name": "精靈"}, {"id": "imp", "name": "小惡魔"}],
	"gender": [{"id": "neutral", "name": "中性"}, {"id": "female", "name": "女性"}, {"id": "male", "name": "男性"}],
	"hair": [{"id": "windswept", "name": "海風吹拂"}, {"id": "bob", "name": "俐落短髮"}, {"id": "curly", "name": "自然捲髮"}],
	"hair_color": [{"id": "ink", "name": "墨黑"}, {"id": "chestnut", "name": "栗棕"}, {"id": "silver", "name": "銀灰"}],
	"face": [{"id": "curious", "name": "好奇"}, {"id": "confident", "name": "自信"}, {"id": "smiling", "name": "微笑"}],
}

static func item(id: String) -> Dictionary:
	for entry: Dictionary in ITEMS:
		if entry.id == id:
			return entry.duplicate(true)
	return {}

static func options() -> Dictionary:
	return APPEARANCE_OPTIONS.duplicate(true)
