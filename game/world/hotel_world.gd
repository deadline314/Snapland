extends "res://game/world/park_world.gd"
## Yoyo Hotel (幽幽旅館): a cut-away seaside hotel at the south end of the west
## breakwater. Its front door faces the coastal loop to the north; inside, four
## rooms stand side by side and open south onto a long veranda: the lobby with
## its reception bell, the folding-page corridor, the lost-property room and the
## dream guest room. This script owns what the player can do here (the floors,
## every interaction point, the twelve kept stand sites); hotel_scenery builds
## the place and hotel_life moves the friendly ghosts and everything that floats.

const Kit := preload("res://game/world/scenery_kit.gd")
const Scenery := preload("res://game/world/hotel_scenery.gd")
const Life := preload("res://game/world/hotel_life.gd")
const ArcadeStands := preload("res://game/world/arcade_stands.gd")
const GROUND_Y := 0.20
## Island lawn height; outside its floors the hotel stands on lawn.
const LAWN_Y := 0.055
## Just inside the front door, where fast travel and the free return stand.
const ENTRY := Vector3(-9.0, GROUND_Y, -11.6)
const BOUNDS := Rect2(-17, -15, 34, 30)
## Each area is a room under the back wall and the stretch of veranda in front
## of it. `number` is the room plate on its signpost; `tile` and `tint` pick the
## floor from the shared material atlas, `paper` the back-wall finish.
const AREAS: Array[Dictionary] = [
	{"id": "lobby", "label": "櫃檯大廳", "number": "101", "room": Rect2(-16.6, -13.4, 11.4, 10.4), "terrace": Rect2(-16.6, -3.0, 11.4, 11.0),
		"tile": 1, "tint": Color("#d9a982"), "paper": [6, Color("#f6cfb4")]},
	{"id": "corridor", "label": "折頁走廊", "number": "102", "room": Rect2(-5.2, -13.4, 7.2, 11.6), "terrace": Rect2(-5.2, -1.8, 7.2, 12.4),
		"tile": 4, "tint": Color("#ebe2f4"), "paper": [4, Color("#f4ead2")]},
	{"id": "lost", "label": "失物室", "number": "103", "room": Rect2(2.0, -13.4, 7.0, 10.0), "terrace": Rect2(2.0, -3.4, 7.0, 12.4),
		"tile": 1, "tint": Color("#b99470"), "paper": [1, Color("#c7a27e")]},
	{"id": "dream", "label": "夢境客房", "number": "104", "room": Rect2(9.0, -13.4, 7.6, 11.0), "terrace": Rect2(9.0, -2.4, 7.6, 12.0),
		"tile": 5, "tint": Color("#c2b0ee"), "paper": [6, Color("#b9a6ea")]},
]
## Where each room's landmark is, for the interaction points and the ghosts.
const DESK := Vector3(-13.2, GROUND_Y, -10.0)
const BELL_POINT := Vector3(-13.2, GROUND_Y, -8.2)
const CORRIDOR_POINT := Vector3(-1.6, GROUND_Y, -8.4)
const LOST_TOWER := Vector3(6.0, GROUND_Y, -10.2)
const LOST_POINT := Vector3(5.2, GROUND_Y, -6.6)
const BED := Vector3(12.8, GROUND_Y, -11.8)
const DREAM_POINT := Vector3(12.8, GROUND_Y, -6.2)
## Room-number signposts at each room's front corner: fixed landmarks to find your way by.
const SIGNPOSTS: Array[Vector3] = [Vector3(-6.0, GROUND_Y, -2.4), Vector3(1.3, GROUND_Y, -1.2), Vector3(8.3, GROUND_Y, -2.8), Vector3(15.9, GROUND_Y, -1.8)]
## Twelve stand sites kept for the hotel's arcade games, three on each stretch
## of veranda. `stand` is the centre of the booth (ArcadeStands.FOOTPRINT) and
## `point` where the visitor stands to play. A site shows a sheet-covered booth
## and a "準備中" tag until an ArcadeStands row for "hotel" uses the same `stand`.
const STAND_SITES: Array[Dictionary] = [
	{"area": "lobby", "stand": Vector3(-14.6, GROUND_Y, 4.4), "point": Vector3(-13.65, GROUND_Y, 5.75)},
	{"area": "lobby", "stand": Vector3(-11.0, GROUND_Y, 5.6), "point": Vector3(-10.05, GROUND_Y, 6.95)},
	{"area": "lobby", "stand": Vector3(-7.4, GROUND_Y, 4.4), "point": Vector3(-6.45, GROUND_Y, 5.75)},
	{"area": "corridor", "stand": Vector3(-3.6, GROUND_Y, 4.6), "point": Vector3(-2.65, GROUND_Y, 5.95)},
	{"area": "corridor", "stand": Vector3(0.4, GROUND_Y, 4.6), "point": Vector3(1.35, GROUND_Y, 5.95)},
	{"area": "corridor", "stand": Vector3(-1.6, GROUND_Y, 8.2), "point": Vector3(-0.65, GROUND_Y, 9.55)},
	{"area": "lost", "stand": Vector3(3.6, GROUND_Y, 3.4), "point": Vector3(4.55, GROUND_Y, 4.75)},
	{"area": "lost", "stand": Vector3(7.4, GROUND_Y, 3.4), "point": Vector3(8.35, GROUND_Y, 4.75)},
	{"area": "lost", "stand": Vector3(5.5, GROUND_Y, 6.8), "point": Vector3(6.45, GROUND_Y, 8.15)},
	{"area": "dream", "stand": Vector3(10.8, GROUND_Y, 3.6), "point": Vector3(11.75, GROUND_Y, 4.95)},
	{"area": "dream", "stand": Vector3(14.8, GROUND_Y, 3.6), "point": Vector3(15.75, GROUND_Y, 4.95)},
	{"area": "dream", "stand": Vector3(12.8, GROUND_Y, 7.0), "point": Vector3(13.75, GROUND_Y, 8.35)},
]
const LOST_ITEMS := ["一隻會哼歌的襪子", "寫著明天日期的日記", "還在滴答的懷錶", "一把只在晴天打開的傘", "裝著海浪聲的玻璃瓶", "誰的夢裡掉下來的星星"]

var _kit: Kit
var _scenery: Scenery
var _life: Life
var _lost_pick := 0


func _build_region_geometry() -> void:
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	await _scenery.build()
	await build_pause()
	ArcadeStands.build(self, "hotel")
	_life = Life.new(self, _scenery)
	_life.build()
	await build_pause()
	_kit.finish()
	_life.hold_still()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("hotel:bell", "櫃檯服務鈴 · 叮一下", BELL_POINT)
	_point("hotel:corridor", "折頁走廊 · 摸摸紙牆", CORRIDOR_POINT)
	_point("hotel:lost", "失物室 · 翻翻失物", LOST_POINT)
	_point("hotel:dream", "夢境客房 · 拍拍枕頭", DREAM_POINT)
	current_area = _area_at_position(ENTRY)


## Sites still waiting for a game: no ArcadeStands row stands on them yet.
static func open_sites() -> Array[Dictionary]:
	var free: Array[Dictionary] = []
	for site: Dictionary in STAND_SITES:
		var taken := ArcadeStands.rows("hotel").any(func(row: Dictionary) -> bool: return (row.stand as Vector3).distance_to(site.stand) < 0.3)
		if not taken: free.append(site)
	return free


func _build_region_activities() -> void:
	pass


func _register_npc_activity() -> void:
	pass


func _build_player_floor() -> void:
	pass


func update_collection(_photos: Dictionary) -> void:
	pass


func _player_spawn_position() -> Vector3:
	return ENTRY


static func floors() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for area: Dictionary in AREAS:
		rects.append(area.room)
		rects.append(area.terrace)
	return rects


func _area_at_position(position: Vector3) -> String:
	var point := Vector2(position.x, position.z)
	for area: Dictionary in AREAS:
		if (area.room as Rect2).has_point(point) or (area.terrace as Rect2).has_point(point):
			return area.label
	return "櫃檯大廳"


func _on_floor_plan(point: Vector2) -> bool:
	for rect: Rect2 in floors():
		if rect.has_point(point): return true
	return false


func ground_surface_y(position: Vector3) -> float:
	return GROUND_Y if _on_floor_plan(Vector2(position.x, position.z)) else LAWN_Y


func _stands_on(point: Vector2) -> bool:
	return _on_floor_plan(point) or _open_ground(point)


func _safe_footing(position: Vector3) -> bool:
	var at := Vector2(position.x, position.z)
	return (_stands_on(at + Vector2(-0.30, -0.30)) and _stands_on(at + Vector2(0.30, -0.30))
		and _stands_on(at + Vector2(-0.30, 0.30)) and _stands_on(at + Vector2(0.30, 0.30)))


func is_walkable(position: Vector3) -> bool:
	return _safe_footing(position)


func _constrain_player(previous_position: Vector3) -> bool:
	if player_spot().y < -1.0 or not _safe_footing(previous_position):
		place_player(ENTRY)
		_host().settle_avatar()
		return true
	if not _safe_footing(player_spot()):
		_set_player_spot(previous_position)
		player.velocity = Vector3.ZERO
	return false


# --- What the rooms do -------------------------------------------------------

## The bell on the desk: the receptionist ghost pops up to greet you.
func ring_bell() -> String:
	_life.ring_bell()
	return "叮鈴——櫃檯小鬼探出頭：「歡迎光臨幽幽旅館，慢慢逛喔。」"


func rustle_pages() -> String:
	_life.rustle_pages()
	return "紙牆沙沙翻了一頁。沿著走廊往南，就回到外廊。"


## A different lost thing each time; the luggage tower spins to show it off.
func browse_lost() -> String:
	var item: String = LOST_ITEMS[_lost_pick % LOST_ITEMS.size()]
	_lost_pick += 1
	_life.spin_luggage()
	return "失物室翻到了：%s。等主人來領吧。" % item


func fluff_dream() -> String:
	_life.fluff_dream()
	return "枕頭一拍，床單和枕頭飄得更高了。夢裡見。"


func _process(delta: float) -> void:
	super._process(delta)
	if _life == null: return
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta)


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	if _scenery != null:
		_scenery.apply_time_of_day(lamp_energy_for_phase)
	if _life != null:
		_life.apply_time_of_day(lamp_energy_for_phase)


## Dream air: a lavender haze by day; after dark a deep indigo with more bloom
## from the lanterns, paper walls and stars.
func _air(phase: String, island: Dictionary) -> Dictionary:
	var evening := phase in ["dusk", "night"]
	return {
		"fog": (island.fog as Color).lerp(Color("#2e2652") if evening else Color("#dccff2"), 0.32),
		"ambient": (island.ambient as Color).lerp(Color("#b8a6ff") if evening else Color("#efe2ff"), 0.24),
		"saturation": 1.04,
		"glow": float(island.glow) + (0.06 if evening else 0.015),
	}


func map_snapshot() -> Dictionary:
	var areas: Array[Dictionary] = []
	for area: Dictionary in AREAS:
		areas.append({"id": area.id, "label": area.label, "rect": area.room})
		areas.append({"id": area.id, "label": area.label, "rect": area.terrace})
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var signs: Array[Dictionary] = []
	for index in AREAS.size():
		signs.append({"number": AREAS[index].number, "position": SIGNPOSTS[index]})
	var at: Vector3 = player_spot() if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": floors(), "areas": areas, "points": stops, "signs": signs,
		"sites": STAND_SITES.map(func(site: Dictionary) -> Vector3: return site.stand),
		"player": at, "area": _area_at_position(at), "region": "hotel"}
