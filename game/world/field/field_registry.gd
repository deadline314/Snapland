extends RefCounted
## Where every instant map game and small toy stands, per region.
## Adding a game is one row here plus its script; adding a toy is one row.
## All positions live in this table. `layout` entries are metres on the ground
## (x, z) relative to `at`, so a row can be moved by changing `at` alone.

const GAME_SPACING := 14.0
const TOY_SPACING := 6.0
const POINT_CLEARANCE := 4.0
const MEDAL_COUNT := 3

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
			"at": Vector3(24.6, 0, 9.4), "arena": Vector3(28.2, 0, 11.6), "radius": 7.5, "seconds": 25.0,
			"medals": [5, 9, 13],
			"lines": ["螃蟹們為你跳了一支嘲笑舞", "踩得不錯，螃蟹有點怕你了", "沙灘上都是你的腳印", "螃蟹連夜搬家了"],
			"layout": [Vector2(0, 0), Vector2(1.9, 0.4), Vector2(-1.8, 0.6), Vector2(0.7, 1.9), Vector2(-0.9, -1.8), Vector2(1.5, -1.5), Vector2(-1.9, -1.0), Vector2(-0.6, 2.2), Vector2(2.3, 1.8)],
		},
		{
			"id": "hat-chase", "script": "res://game/world/field/games/hat_chase.gd",
			"type": "追逐", "title": "追帽子", "prompt": "玩追帽子", "hint": "追上海鷗，摸牠三下！", "glyph": "帽", "color": Color("#ecca7e"),
			"at": Vector3(-1.5, 0, -50.6), "arena": Vector3(-1.5, 0, -56.2), "radius": 10.0, "seconds": 30.0,
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
			"at": Vector3(26.2, 0, -61.6), "arena": Vector3(29.4, 0, -66.4), "radius": 9.0, "seconds": 35.0,
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
}

## Toy row: id, kind (see field_toys.gd), prompt, at, plus that kind's own layout.
## The palm toy shakes a palm that already grows at `at`; it plants nothing.
const TOYS := {
	"welcome": [
		{"id": "palm", "kind": "palm", "prompt": "搖一搖椰子樹", "at": Vector3(16.3, 0, 14.5)},
		{"id": "swing", "kind": "swing", "prompt": "推一下鞦韆", "at": Vector3(-22.4, 0, -21.8)},
		{"id": "chime", "kind": "chime", "prompt": "搖響許願風鈴", "at": Vector3(-9.2, 0, -49.2)},
		{"id": "geyser", "kind": "geyser", "prompt": "踩一下噴水洞", "at": Vector3(31.4, 0, -9.0)},
		{"id": "stones", "kind": "stones", "prompt": "聽踏石唱歌", "at": Vector3(-29.0, 0, -68.6),
			"layout": [Vector2(-2.4, 0.5), Vector2(-1.2, -0.3), Vector2(0, 0.4), Vector2(1.2, -0.3), Vector2(2.4, 0.5)]},
		{"id": "bench", "kind": "bench", "prompt": "坐下來等海鳥", "at": Vector3(11.0, 0, -72.2)},
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
