extends RefCounted
## Where every instant map game and small toy stands, per region.
## Adding a game is one row here plus its script; adding a toy is one row
## (plus a script under toys/ for a new kind). All positions live in this
## table. `layout` entries are metres on the ground (x, z) relative to the
## arena, so a row can be moved by changing `at` and `arena` alone.
##
## Welcome rows are in island coordinates. A district's rows are in that
## district's own coordinates (DistrictSites), are built when the district is
## built, sleep with it and go when it goes; placed() turns them into island
## coordinates. District rows may stand on the island ground of the district's
## edge band, but never in another district's claim or on any approach.

const DistrictSites = preload("res://game/world/district_sites.gd")

const HOME := "welcome"
const GAME_SPACING := 14.0
const TOY_SPACING := 6.0
const POINT_CLEARANCE := 4.0
## Games keep this far from any approach strip, toys a little less.
const APPROACH_CLEARANCE := 5.0
const TOY_APPROACH_CLEARANCE := 3.0
const MEDAL_COUNT := 3
## Keys of a row that are positions; everything else is an offset or a setting.
const POSITION_KEYS := ["at", "arena"]

## Game row: id, script, type (the kind of play), title, prompt (one line shown
## on approach), hint (the one thing to do, shown during the countdown), glyph
## and color for its stand, at (the stand), arena (centre of play), radius
## (walking farther away ends the round), seconds (15 to 40), medals (bronze,
## silver, gold scores), lines (one comment per medal, starting with none).
const GAMES := {
	"welcome": [
		{
			"id": "crab-stomp", "script": "res://game/world/field/games/crab_stomp.gd",
			"type": "踩踏", "title": "踩螃蟹", "prompt": "玩踩螃蟹", "hint": "跑過去踩冒出來的螃蟹！", "glyph": "蟹", "color": Color("#e2734d"),
			"at": Vector3(26.0, 0, 8.2), "arena": Vector3(30.0, 0, 10.0), "radius": 7.5, "seconds": 25.0,
			"medals": [5, 9, 13],
			"lines": ["螃蟹們為你跳了一支嘲笑舞", "踩得不錯，螃蟹有點怕你了", "沙灘上都是你的腳印", "螃蟹連夜搬家了"],
			"layout": [Vector2(0, 0), Vector2(1.9, 0.4), Vector2(-1.8, 0.6), Vector2(0.7, 1.9), Vector2(-0.9, -1.8), Vector2(1.5, -1.5), Vector2(-1.9, -1.0), Vector2(-0.6, 2.2), Vector2(2.3, 1.8)],
		},
		{
			"id": "hat-chase", "script": "res://game/world/field/games/hat_chase.gd",
			"type": "追逐", "title": "追帽子", "prompt": "玩追帽子", "hint": "追上海鷗，摸牠三下！", "glyph": "帽", "color": Color("#ecca7e"),
			"at": Vector3(-12.4, 0, -65.4), "arena": Vector3(-14.0, 0, -72.0), "radius": 10.0, "seconds": 30.0,
			"medals": [10, 30, 38],
			"lines": ["海鷗戴著你的帽子去兜風了", "摸到了！可惜帽子還在牠嘴上", "帽子搶回來了，還有點鳥味", "海鷗甘拜下風，帽子雙手奉還"],
			"roam": 4.6,
		},
		{
			"id": "jump-rope", "script": "res://game/world/field/games/jump_rope.gd",
			"type": "時機", "title": "跳大繩", "prompt": "玩跳大繩", "hint": "繩子掃到腳邊時按 E 跳！", "glyph": "繩", "color": Color("#4b9b9c"),
			"at": Vector3(6.4, 0, -10.4), "arena": Vector3(9.8, 0, -12.6), "radius": 6.5, "seconds": 30.0,
			"medals": [6, 13, 20],
			"lines": ["被繩子打包成粽子了", "有跳有保庇，再快一點點", "腳步輕得像海風", "連繩子都甩到沒力了"],
			"layout": [Vector2(-2.6, 0), Vector2(2.6, 0)],
		},
		{
			"id": "flag-run", "script": "res://game/world/field/games/flag_run.gd",
			"type": "收集競速", "title": "彩旗繞行", "prompt": "玩彩旗繞行", "hint": "照號碼穿過旗門！", "glyph": "旗", "color": Color("#da705c"),
			"at": Vector3(56.5, 0, -20.0), "arena": Vector3(60.0, 0, -24.0), "radius": 9.0, "seconds": 35.0,
			"medals": [4, 8, 11],
			"lines": ["旗子都被你繞暈了", "順順地繞完幾面，腳還在", "一路綠燈，旗子直點頭", "風都追不上你"],
			"layout": [Vector2(1.9, 3.1), Vector2(-1.7, 3.2), Vector2(-3.6, 0.2), Vector2(-1.9, -3.1), Vector2(1.7, -3.2), Vector2(3.6, -0.2)],
		},
		{
			"id": "bird-shutter", "script": "res://game/world/field/games/bird_shutter.gd",
			"type": "拍照", "title": "鳥群快門", "prompt": "玩鳥群快門", "hint": "框裡的鳥最多時按 E！", "glyph": "鳥", "color": Color("#7fc4f2"),
			"at": Vector3(9.2, 0, 14.0), "arena": Vector3(10.6, 0, 15.1), "radius": 5.0, "seconds": 28.0,
			"medals": [5, 9, 13],
			"lines": ["三張都只拍到尾巴", "有拍到幾隻，其他都是殘影", "構圖漂亮，鳥也很配合", "這張可以登上島報頭版"],
			"frame": Vector3(4.6, 2.2, 9.6), "frame_size": Vector2(4.6, 2.5), "layout": [Vector2(1.3, -0.5)],
		},
	],
	# Districts: positions in the district's own coordinates (see the header).
	"harbor": [
		{
			"id": "harbor-fish-net", "script": "res://game/world/field/games/fish_net.gd",
			"type": "接住", "title": "接飛魚", "prompt": "玩接飛魚", "hint": "站到圈圈上，接住跳上岸的魚！", "glyph": "魚", "color": Color("#7fc4f2"),
			"at": Vector3(-27.6, 0, -9.4), "arena": Vector3(-29.4, 0, -11.4), "radius": 5.5, "seconds": 30.0,
			"medals": [5, 10, 15],
			"lines": ["魚在沙灘上跳了一整場踢踏舞", "接到幾條，晚餐有著落了", "身手俐落，海鷗都看呆了", "漁夫想請你上船"],
			"layout": [Vector2(-1.6, -1.1), Vector2(0.2, -1.8), Vector2(1.7, -0.6), Vector2(1.2, 1.3), Vector2(-0.6, 1.6), Vector2(-1.8, 0.5), Vector2(0, 0)],
		},
		{
			"id": "harbor-crate-stack", "script": "res://game/world/field/games/crate_stack.gd",
			"type": "疊高", "title": "搖晃疊貨", "prompt": "玩搖晃疊貨", "hint": "吊鉤擺到船上方時按 E 放貨！", "glyph": "箱", "color": Color("#da705c"),
			"at": Vector3(-32.6, 0, 12.4), "arena": Vector3(-30.2, 0, 12.6), "radius": 4.5, "seconds": 35.0,
			"medals": [6, 12, 18],
			"lines": ["貨箱全進了海，螃蟹撿到寶", "疊了幾層，船長勉強點頭", "穩穩一座小貨山", "這艘船可以直接出航了"],
			"boat": Vector2(5.4, 0.0),
		},
	],
	"candy": [
		{
			"id": "candy-gumball", "script": "res://game/world/field/games/gumball_header.gd",
			"type": "頂球", "title": "頂糖球", "prompt": "玩頂糖球", "hint": "跑到影子下，把糖球頂回天上！", "glyph": "球", "color": Color("#e59ab0"),
			"at": Vector3(-43.6, 0, -7.0), "arena": Vector3(-46.0, 0, -4.0), "radius": 6.5, "seconds": 30.0,
			"medals": [6, 12, 18],
			"lines": ["糖球黏在你頭上當帽子", "頂了幾下，脖子有點酸", "糖球在你頭上跳舞", "糖果工廠想請你當吉祥物"],
			"layout": [Vector2(-2.4, 0), Vector2(2.4, 0), Vector2(0, -2.4), Vector2(0, 2.4), Vector2(1.7, 1.7), Vector2(-1.7, -1.7), Vector2(1.7, -1.7), Vector2(-1.7, 1.7)],
		},
		{
			"id": "candy-sort", "script": "res://game/world/field/games/candy_sort.gd",
			"type": "分流", "title": "糖果分流", "prompt": "玩糖果分流", "hint": "踩左右踏板，讓糖滾進同色的桶！", "glyph": "糖", "color": Color("#9fd8c4"),
			"at": Vector3(-43.6, 0, 11.0), "arena": Vector3(-46.0, 0, 14.0), "radius": 6.0, "seconds": 35.0,
			"medals": [7, 13, 19],
			"lines": ["糖果機噴了你一身彩虹", "分得還行，有幾顆走錯桶", "桶桶都是對的顏色", "糖果師傅說你可以接班了"],
			"layout": [Vector2(-0.8, 1.3), Vector2(0.8, 1.3), Vector2(-1.4, -0.7), Vector2(1.4, -0.7), Vector2(0, -2.8)],
		},
	],
	"nightmarket": [
		{
			"id": "night-goldfish", "script": "res://game/world/field/games/goldfish_scoop.gd",
			"type": "撈", "title": "撈金魚", "prompt": "玩撈金魚", "hint": "金魚游到你面前時按 E 撈！", "glyph": "撈", "color": Color("#e8674f"),
			"at": Vector3(-9.8, 0, 17.6), "arena": Vector3(-12.6, 0, 20.4), "radius": 5.5, "seconds": 30.0,
			"medals": [10, 22, 40],
			"lines": ["紙網破光光，金魚對你吐泡泡", "撈到幾隻，夠養一缸了", "老闆開始擔心他的魚", "老闆把紙網藏起來了"],
			"layout": [Vector2(2.3, 0), Vector2(-2.3, 0), Vector2(0, 2.3), Vector2(0, -2.3)],
		},
		{
			"id": "night-order", "script": "res://game/world/field/games/skewer_order.gd",
			"type": "記憶", "title": "夜市點單", "prompt": "玩夜市點單", "hint": "記住客人點的串，照順序踩烤盤！", "glyph": "串", "color": Color("#f2c75a"),
			"at": Vector3(16.6, 0, 17.6), "arena": Vector3(14.0, 0, 20.4), "radius": 5.5, "seconds": 40.0,
			"medals": [4, 9, 14],
			"lines": ["客人收到一串神秘料理", "記得幾串，客人還算滿意", "點什麼來什麼，客人拍手", "整條街都來找你點單"],
			"layout": [Vector2(-1.8, 0.4), Vector2(-0.7, -1.1), Vector2(0.9, -1.1), Vector2(2.0, 0.4)],
		},
	],
	"circus": [
		{
			"id": "circus-spotlight", "script": "res://game/world/field/games/spotlight.gd",
			"type": "跟隨", "title": "追聚光燈", "prompt": "玩追聚光燈", "hint": "一直站在聚光燈裡！", "glyph": "光", "color": Color("#f2c75a"),
			"at": Vector3(-14.2, 0, 27.8), "arena": Vector3(-17.0, 0, 30.6), "radius": 6.5, "seconds": 30.0,
			"medals": [24, 38, 50],
			"lines": ["聚光燈照到了一隻路過的鴿子", "偶爾站上舞台，觀眾有在拍手", "全場的目光都在你身上", "馬戲團長想把你簽下來"],
			"layout": [Vector2(-3.0, 0), Vector2(3.0, 0), Vector2(0, -2.6), Vector2(0, 2.6), Vector2(2.1, 1.8), Vector2(-2.1, -1.8)],
		},
		{
			"id": "circus-cups", "script": "res://game/world/field/games/cup_shuffle.gd",
			"type": "觀察", "title": "猜杯子", "prompt": "玩猜杯子", "hint": "盯住藏球的杯子，走過去按 E！", "glyph": "杯", "color": Color("#da705c"),
			"at": Vector3(11.4, 0, 27.8), "arena": Vector3(14.0, 0, 30.4), "radius": 5.5, "seconds": 40.0,
			"medals": [2, 4, 6],
			"lines": ["小丑笑到滾在地上", "猜中幾次，小丑開始流汗", "眼睛比小丑的手還快", "小丑把杯子收起來不玩了"],
			"layout": [Vector2(-2.1, -0.6), Vector2(-0.7, -0.6), Vector2(0.7, -0.6), Vector2(2.1, -0.6)],
		},
	],
	"toy": [
		{
			"id": "toy-cans", "script": "res://game/world/field/games/tin_cans.gd",
			"type": "瞄準", "title": "滾球打罐", "prompt": "玩滾球打罐", "hint": "走到罐子正前方按 E 滾球！", "glyph": "罐", "color": Color("#7fc4f2"),
			"at": Vector3(-17.6, 0, 33.2), "arena": Vector3(-21.0, 0, 32.0), "radius": 6.0, "seconds": 35.0,
			"medals": [15, 30, 45],
			"lines": ["球滾回來敲了你的腳", "打倒幾罐，罐子不太服氣", "罐子倒成一片", "罐子們集體投降"],
			"layout": [Vector2(-2.4, 2.2), Vector2(2.4, 2.2), Vector2(-2.4, -2.8), Vector2(2.4, -2.8)],
		},
		{
			"id": "toy-statue", "script": "res://game/world/field/games/wind_soldier.gd",
			"type": "定格", "title": "發條木頭人", "prompt": "玩發條木頭人", "hint": "兵兵轉頭時站好別動！", "glyph": "兵", "color": Color("#e8674f"),
			"at": Vector3(17.6, 0, 33.2), "arena": Vector3(21.0, 0, 32.0), "radius": 6.5, "seconds": 35.0,
			"medals": [3, 6, 9],
			"lines": ["兵兵一直抓到你在偷跑", "摸到了，兵兵有點不甘心", "兵兵的發條都轉鬆了", "兵兵對你敬了一個禮"],
			"layout": [Vector2(0, 3.0), Vector2(0, -3.2), Vector2(-1.5, 0), Vector2(1.5, 0)],
		},
	],
	"garden": [
		{
			"id": "garden-water", "script": "res://game/world/field/games/water_flowers.gd",
			"type": "澆灌", "title": "澆花救急", "prompt": "玩澆花救急", "hint": "花垂頭了就走過去按 E 澆水！", "glyph": "花", "color": Color("#e59ab0"),
			"at": Vector3(7.4, 0, 29.0), "arena": Vector3(10.4, 0, 31.4), "radius": 5.5, "seconds": 30.0,
			"medals": [4, 9, 14],
			"lines": ["花全趴下，只剩雜草在笑", "救回幾朵，蜜蜂還是來了", "花圃精神抖擻", "連枯枝都發新芽了"],
			"layout": [Vector2(-2.2, -0.9), Vector2(-0.8, -1.9), Vector2(0.9, -1.9), Vector2(2.3, -0.8), Vector2(1.6, 1.2), Vector2(-1.5, 1.3)],
		},
		{
			"id": "garden-ducks", "script": "res://game/world/field/games/duck_herd.gd",
			"type": "帶路", "title": "帶小鴨回家", "prompt": "玩帶小鴨", "hint": "碰一下小鴨，帶牠們走進池塘！", "glyph": "鴨", "color": Color("#ecca7e"),
			"at": Vector3(24.8, 0, -1.4), "arena": Vector3(27.0, 0, 2.0), "radius": 6.5, "seconds": 35.0,
			"medals": [4, 8, 11],
			"lines": ["小鴨排隊在你後面散步", "趕回幾隻，鴨媽媽點點頭", "小鴨乖乖回家了", "鴨媽媽想認你當乾媽"],
			"layout": [Vector2(0, -1.3), Vector2(-2.7, 0.9), Vector2(2.7, 0.9), Vector2(0, 2.6), Vector2(-2.6, -2.0), Vector2(2.6, -2.0)],
		},
	],
	# The cinema's two outdoor sets stand on the lagoon's banks: west of the lot
	# by the lookout, and south of it by the coastal loop.
	"cinema": [
		{
			"id": "cinema-dolly", "script": "res://game/world/field/games/dolly_track.gd",
			"type": "推", "title": "推軌跟拍", "prompt": "玩推軌跟拍", "hint": "從後面推攝影車，讓主角留在兩面黃旗之間！", "glyph": "拍", "color": Color("#7fc4f2"),
			"at": Vector3(-22.0, 0, 8.2), "arena": Vector3(-26.0, 0, 6.0), "radius": 5.4, "seconds": 30.0,
			"medals": [12, 30, 50],
			"lines": ["主角跑出畫面，只拍到一片空地", "拍到幾段，剪一剪還能用", "鏡頭跟得穩穩的，導演點頭了", "一鏡到底！影帝想跟你合作"],
			"track_radius": 3.2, "layout": [Vector2(2.96, 1.22), Vector2(1.22, 2.96), Vector2(-1.22, 2.96), Vector2(-2.96, 1.22), Vector2(-2.96, -1.22), Vector2(-1.22, -2.96), Vector2(1.22, -2.96), Vector2(2.96, -1.22)],
		},
		{
			"id": "cinema-dodge", "script": "res://game/world/field/games/prop_dodge.gd",
			"type": "閃避", "title": "躲道具", "prompt": "玩躲道具", "hint": "看到影子就閃開，別被掉下來的道具砸到！", "glyph": "躲", "color": Color("#e8b54f"),
			"at": Vector3(5.0, 0, 21.6), "arena": Vector3(8.0, 0, 24.5), "radius": 3.2, "seconds": 30.0,
			"medals": [8, 15, 22],
			"lines": ["被泡棉石頭砸成了大頭照", "躲過幾樣，導演說再來一條", "身手俐落，特技組來挖角了", "連一根羽毛都沒碰到你"],
		},
	],
}

## Toy row: id, kind (see field_toys.gd, or a script toys/<kind>.gd), prompt,
## at, plus that kind's own layout.
## The palm toy shakes a palm that already grows at `at`; it plants nothing.
const TOYS := {
	"welcome": [
		{"id": "palm", "kind": "palm", "prompt": "搖一搖椰子樹", "at": Vector3(17.1, 0, 5.5)},
		{"id": "swing", "kind": "swing", "prompt": "推一下鞦韆", "at": Vector3(-20.5, 0, -14.5)},
		{"id": "chime", "kind": "chime", "prompt": "搖響許願風鈴", "at": Vector3(-22.0, 0, -41.5)},
		{"id": "geyser", "kind": "geyser", "prompt": "踩一下噴水洞", "at": Vector3(30.0, 0, -16.5)},
		{"id": "stones", "kind": "stones", "prompt": "聽踏石唱歌", "at": Vector3(-29.0, 0, -72.5),
			"layout": [Vector2(-2.4, 0.5), Vector2(-1.2, -0.3), Vector2(0, 0.4), Vector2(1.2, -0.3), Vector2(2.4, 0.5)]},
		{"id": "bench", "kind": "bench", "prompt": "坐下來等海鳥", "at": Vector3(57.0, 0, -38.0)},
	],
	"harbor": [
		{"id": "harbor-bell", "kind": "ship_bell", "prompt": "敲一下船鐘", "at": Vector3(-28.0, 0, -1.0)},
		{"id": "harbor-crab-pot", "kind": "crab_pot", "prompt": "掀開蟹簍", "at": Vector3(-28.4, 0, -15.8)},
	],
	"candy": [
		{"id": "candy-gumball-machine", "kind": "gumball_machine", "prompt": "轉一顆糖球", "at": Vector3(-50.0, 0, 5.0)},
		{"id": "candy-jelly", "kind": "jelly_pad", "prompt": "踩一下果凍", "at": Vector3(12.0, 0, 31.0)},
	],
	"nightmarket": [
		{"id": "night-lanterns", "kind": "lantern_string", "prompt": "搖一搖燈籠", "at": Vector3(-25.0, 0, 17.0)},
		{"id": "night-lucky-cat", "kind": "lucky_cat", "prompt": "摸摸招財貓", "at": Vector3(26.0, 0, 19.0)},
	],
	"circus": [
		{"id": "circus-jack-box", "kind": "jack_box", "prompt": "轉轉驚喜盒", "at": Vector3(24.0, 0, 30.0)},
		{"id": "circus-horn", "kind": "horn", "prompt": "按一下喇叭", "at": Vector3(-27.0, 0, 30.0)},
	],
	"toy": [
		{"id": "toy-top", "kind": "spinning_top", "prompt": "轉一下陀螺", "at": Vector3(-35.0, 0, 0.0)},
		{"id": "toy-horse", "kind": "rocking_horse", "prompt": "推推搖搖馬", "at": Vector3(-30.0, 0, 32.0)},
	],
	"garden": [
		{"id": "garden-dandelion", "kind": "dandelion", "prompt": "吹蒲公英", "at": Vector3(19.0, 0, 29.0)},
		{"id": "garden-sunflower", "kind": "sunflower", "prompt": "和向日葵打招呼", "at": Vector3(-11.0, 0, 27.0)},
	],
	"cinema": [
		{"id": "cinema-popcorn", "kind": "popcorn_cart", "prompt": "爆一鍋爆米花", "at": Vector3(0.4, 0, -6.6)},
		{"id": "cinema-clapper", "kind": "clapperboard", "prompt": "打一下場記板", "at": Vector3(12.6, 0, 9.4)},
	],
}


static func games(region: String) -> Array:
	return GAMES.get(region, [])


static func toys(region: String) -> Array:
	return TOYS.get(region, [])


static func has_region(region: String) -> bool:
	return GAMES.has(region) or TOYS.has(region)


static func point_id(row: Dictionary, toy := false) -> String:
	return ("toy:" if toy else "field:") + String(row.id)


## Every region with rows, the island first.
static func regions() -> Array:
	var found: Array = [HOME]
	for region: String in GAMES.keys() + TOYS.keys():
		if not found.has(region):
			found.append(region)
	return found


## A row in island coordinates (district rows are authored in their own).
static func placed(row: Dictionary, region: String) -> Dictionary:
	if region == HOME or not DistrictSites.has(region):
		return row
	var moved := row.duplicate()
	for key: String in POSITION_KEYS:
		if moved.has(key):
			moved[key] = DistrictSites.to_world(region, moved[key])
	moved["region"] = region
	return moved


static var _placed_games: Array = []
static var _placed_toys: Array = []

## Every game row of every region in island coordinates, built once.
static func placed_games() -> Array:
	if _placed_games.is_empty():
		for region: String in regions():
			for row: Dictionary in games(region):
				_placed_games.append(placed(row, region))
	return _placed_games


static func placed_toys() -> Array:
	if _placed_toys.is_empty():
		for region: String in regions():
			for row: Dictionary in toys(region):
				_placed_toys.append(placed(row, region))
	return _placed_toys


## Problems with one district's rows on the island: the usual checks, run
## against every other region's rows too (ids, spacing), plus the district
## rules: no spot in another district's claim or near any approach strip.
## `extra_games` (rows already in island coordinates) are checked as if they
## were this district's too.
static func district_problems(region: String, walkable: Callable, other_points: Array[Vector3], extra_games: Array = []) -> Array[String]:
	var own_games: Array = games(region).map(func(row: Dictionary) -> Dictionary: return placed(row, region)) + extra_games
	var own_toys: Array = toys(region).map(func(row: Dictionary) -> Dictionary: return placed(row, region))
	var others := func(row: Dictionary) -> bool: return String(row.get("region", HOME)) != region
	var found: Array[String] = []
	var own: Array = own_games + own_toys
	for problem in problems_in(placed_games().filter(others) + own_games, placed_toys().filter(others) + own_toys, walkable, other_points):
		for index in range(own.size()):
			var row: Dictionary = own[index]
			if problem.begins_with(point_id(row, index >= own_games.size()) + " ") or problem.contains(" from %s (" % row.id):
				found.append(problem)
				break
	for index in range(own.size()):
		var is_toy := index >= own_games.size()
		var row: Dictionary = own[index]
		var id := point_id(row, is_toy)
		for spot in footprint(row):
			var flat := Vector2(spot.x, spot.z)
			var owner := DistrictSites.ruling(flat)
			if not owner.is_empty() and owner != region:
				found.append("%s has a spot in the %s district at %s" % [id, owner, spot])
			for other: String in DistrictSites.regions():
				var strip := DistrictSites.world_rect(other, "approach")
				var gap := flat.distance_to(flat.clamp(strip.position, strip.end))
				if gap < (TOY_APPROACH_CLEARANCE if is_toy else APPROACH_CLEARANCE):
					found.append("%s is %.1f m from the %s approach at %s" % [id, gap, other, spot])
		if String(row.get("prompt", "")).length() > 8:
			found.append("%s needs a prompt of at most eight characters" % id)
	return found


## Ground positions a row occupies: its stand, its arena and every layout spot.
static func footprint(row: Dictionary) -> Array[Vector3]:
	var spots: Array[Vector3] = [row.at]
	var centre: Vector3 = row.get("arena", row.at)
	if row.has("arena"):
		spots.append(centre)
	for offset: Vector2 in row.get("layout", []):
		spots.append(centre + Vector3(offset.x, 0, offset.y))
	return spots


## Problems with one region's rows; empty when the table is sound.
## `walkable` answers "can the player stand here"; `other_points` are the
## interaction points that already exist in the world.
static func problems(region: String, walkable: Callable, other_points: Array[Vector3]) -> Array[String]:
	return problems_in(games(region), toys(region), walkable, other_points)


static func problems_in(game_rows: Array, toy_rows: Array, walkable: Callable, other_points: Array[Vector3]) -> Array[String]:
	var found: Array[String] = []
	var seen := {}
	var rows: Array = game_rows + toy_rows
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var is_game := index < game_rows.size()
		var id := point_id(row, not is_game)
		if seen.has(id):
			found.append("%s is registered twice" % id)
		seen[id] = true
		for spot in footprint(row):
			if not walkable.call(spot):
				found.append("%s has a spot off walkable land at %s" % [id, spot])
		for point in other_points:
			if _flat(point, row.at) < POINT_CLEARANCE:
				found.append("%s crowds an existing interaction point at %s" % [id, point])
		for earlier in range(index):
			var other: Dictionary = rows[earlier]
			var both_games := is_game and earlier < game_rows.size()
			var needed := GAME_SPACING if both_games else TOY_SPACING
			var gap := _flat(row.at, other.at)
			if both_games:
				gap = minf(gap, _flat(row.get("arena", row.at), other.get("arena", other.at)))
			if gap < needed:
				found.append("%s is %.1f m from %s (needs %.0f m)" % [id, gap, String(other.id), needed])
		if not is_game:
			continue
		var medals: Array = row.get("medals", [])
		if medals.size() != MEDAL_COUNT or int(medals[0]) < 1 or int(medals[0]) >= int(medals[1]) or int(medals[1]) >= int(medals[2]):
			found.append("%s needs three rising medal scores" % id)
		var seconds := float(row.get("seconds", 0.0))
		if seconds < 15.0 or seconds > 40.0:
			found.append("%s must last 15 to 40 seconds" % id)
		if (row.get("lines", []) as Array).size() != MEDAL_COUNT + 1:
			found.append("%s needs one comment per medal" % id)
		if String(row.get("prompt", "")).is_empty() or String(row.get("hint", "")).is_empty() or not ResourceLoader.exists(String(row.get("script", ""))):
			found.append("%s needs a prompt, a hint and a script" % id)
	return found


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
