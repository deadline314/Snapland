extends RefCounted
## The premiere's script, found one page at a time on the backs of the main
## story stickers. Each district's greeting photo also catches something at the
## edge of the frame that does not belong to the shot: a cape corner, a glove,
## a hat brim. Nothing here names who it is (see design/03-story/staging-research.md).

const PAGES := {
	"photo-welcome-story-1": {"page": 1, "clue": "cape", "text": "第一幕　客人上岸。\n燈要亮，船笛要短，讓客人自己走上棧橋。\n（我站在旁邊就好。旁邊的旁邊。）"},
	"photo-nightmarket-story-1": {"page": 2, "clue": "glove", "text": "第二幕　夜市的燈牌借三分鐘當開場燈。\n宵夜的鈴聲＝開演鈴？\n開場白寫在點心紙上了——不要被外送拿走！"},
	"photo-circus-story-1": {"page": 3, "clue": "cape", "text": "第三幕　鏡子會先鞠躬，演員不要搶拍。\n開場白還沒寫完……\n第一句：「歡迎來到——」（後面忘了）"},
	"photo-toy-story-1": {"page": 4, "clue": "hat", "text": "第四幕　借車站的鈴當提示。\n是哪一站？拍下來就記得了。\n帽子要兩面都能戴，緊張的時候才不會戴反。"},
	"photo-garden-story-1": {"page": 5, "clue": "glove", "text": "第五幕　留一個亮著的座位給晚到的人。\n他們不會出現在照片裡，\n但他們會來。"},
}
const CLUES := ["cape", "glove", "hat"]

static func page(photo_id: String) -> Dictionary:
	return (PAGES.get(photo_id, {}) as Dictionary).duplicate()

## The edge clue for a district's greeting photo ("" when it has none).
static func clue_for(photo_id: String) -> String:
	return str(PAGES.get(photo_id, {}).get("clue", ""))

static var _clue_textures: Dictionary = {}

## Small pixel art of the thing at the frame edge, drawn once per kind.
static func clue_texture(kind: String) -> Texture2D:
	if _clue_textures.has(kind): return _clue_textures[kind]
	var size := Vector2i(40, 56)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var ink := Color("#2a1c33")
	var shape := func(x: int, y: int) -> int:
		# 0 empty, 1 main colour, 2 trim.
		var u := float(x) / size.x
		var v := float(y) / size.y
		match kind:
			"cape":
				# A velvet cape corner swinging in from the right with a gold hem.
				if u + v * 0.35 < 0.42 or v < 0.05: return 0
				return 2 if v > 0.88 or u + v * 0.35 < 0.5 else 1
			"glove":
				# A white glove with three fingers curled round the frame edge.
				var palm := Vector2(u - 0.62, v - 0.62).length() < 0.3
				var fingers := u > 0.28 and u < 0.86 and v > 0.12 and v < 0.48 and int(u * 10.0) % 2 == 1
				var cuff := v > 0.84 and u > 0.42
				return 2 if cuff else (1 if palm or fingers else 0)
			"hat":
				# The brim and crown of a two-way conductor's cap.
				var brim := v > 0.62 and v < 0.74 and u > 0.12
				var crown := v > 0.3 and v <= 0.62 and u > 0.3 and u < 0.94
				var band := v > 0.52 and v <= 0.62 and u > 0.3 and u < 0.94
				return 2 if band else (1 if brim or crown else 0)
		return 0
	var fill := {"cape": [Color("#6b2a5e"), Color("#e0b04f")], "glove": [Color("#f7f1e3"), Color("#c9584f")], "hat": [Color("#2f4f86"), Color("#e0b04f")]}
	var tones: Array = fill.get(kind, [Color("#6b2a5e"), Color("#e0b04f")])
	for y in range(size.y):
		for x in range(size.x):
			var at: int = shape.call(x, y)
			if at == 0: continue
			var edge := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y or int(shape.call(nx, ny)) == 0:
					edge = true
			image.set_pixel(x, y, ink if edge else tones[at - 1])
	var texture := ImageTexture.create_from_image(image)
	_clue_textures[kind] = texture
	return texture
