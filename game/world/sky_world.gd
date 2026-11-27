extends "res://game/world/park_world.gd"
## Cloud Park (雲端遊樂場): floating walkways over a sea of cloud at the south
## end of the east breakwater. A cloud bridge from the coastal loop lands on the
## gate plaza; the ferris wheel turns behind it; grassy floating islands climb
## west and south to the kite terrace and on to the cloud-top photo point, whose
## long cloud stair runs back down to the wheel. Every rise is a ramp, so no
## jump is ever needed; a step off an edge is caught and set back on the deck.
## This script owns what the walker can do (the floor plan and its heights,
## every interaction point, the twelve kept stand sites); sky_scenery builds
## the place and sky_life turns, flies and drifts everything that moves.

const Kit := preload("res://game/world/scenery_kit.gd")
const Scenery := preload("res://game/world/sky_scenery.gd")
const Life := preload("res://game/world/sky_life.gd")
const ArcadeStands := preload("res://game/world/arcade_stands.gd")
const StandSites := preload("res://game/world/stand_sites.gd")
const GROUND_Y := 0.20
## Island lawn height, beyond the claim.
const LAWN_Y := 0.055
## The cloud sea the walkways float over.
const CLOUD_Y := 0.11
## Inside the gate plaza, where fast travel and the free return stand.
const ENTRY := Vector3(-4.0, GROUND_Y, -13.6)
const BOUNDS := Rect2(-22, -18, 44, 36)
const AREAS: Array[Dictionary] = [
	{"id": "wheel", "label": "摩天輪"},
	{"id": "isles", "label": "浮島步道"},
	{"id": "kites", "label": "風箏台"},
	{"id": "photo", "label": "雲霄攝影點"},
]
## Walkable decks: ellipses of `radius` around `centre`, level at `y`. `top`
## picks the deck surface in sky_scenery. Decks at different heights never overlap.
const PADS: Array[Dictionary] = [
	{"id": "plaza", "area": "wheel", "centre": Vector2(-4.0, -12.6), "radius": Vector2(5.6, 4.2), "y": GROUND_Y, "top": "plaza"},
	{"id": "wheel", "area": "wheel", "centre": Vector2(8.4, -11.0), "radius": Vector2(8.6, 5.8), "y": GROUND_Y, "top": "plaza"},
	{"id": "isle1", "area": "isles", "centre": Vector2(-12.2, -5.4), "radius": Vector2(3.8, 3.0), "y": 0.75, "top": "isle"},
	{"id": "isle2", "area": "isles", "centre": Vector2(-16.6, 2.2), "radius": Vector2(3.6, 3.0), "y": 1.30, "top": "isle"},
	{"id": "isle3", "area": "isles", "centre": Vector2(-7.4, 3.4), "radius": Vector2(3.8, 3.0), "y": 1.30, "top": "isle"},
	{"id": "isle4", "area": "isles", "centre": Vector2(0.8, 6.6), "radius": Vector2(3.2, 2.6), "y": 1.80, "top": "isle"},
	{"id": "kite", "area": "kites", "centre": Vector2(-12.0, 12.6), "radius": Vector2(7.4, 4.6), "y": 1.85, "top": "deck"},
	{"id": "photo", "area": "photo", "centre": Vector2(11.2, 11.4), "radius": Vector2(6.0, 4.4), "y": 2.35, "top": "cloud"},
]
## Ramps, bridges and stairs between two decks: straight from `from` to `to`
## (pad centres unless `a`/`b` aim the line), trimmed to the decks' edges.
## `kind`: "ramp" (stepped treads), "bridge" (rope bridge) or "stair" (the long cloud stair).
const LINKS: Array[Dictionary] = [
	{"from": "plaza", "to": "isle1", "width": 2.2, "kind": "ramp"},
	{"from": "isle1", "to": "isle2", "width": 2.0, "kind": "ramp"},
	{"from": "isle2", "to": "isle3", "width": 1.8, "kind": "bridge"},
	{"from": "isle3", "to": "kite", "width": 2.2, "kind": "ramp"},
	{"from": "isle3", "to": "isle4", "width": 2.0, "kind": "ramp"},
	{"from": "isle4", "to": "photo", "width": 2.0, "kind": "ramp"},
	{"from": "photo", "to": "wheel", "width": 2.4, "kind": "stair", "a": Vector2(15.0, 11.0), "b": Vector2(14.6, -9.0)},
]
## Landmarks and the spots where the walker uses them.
const WHEEL := Vector3(9.0, GROUND_Y, -14.6)
const WHEEL_POINT := Vector3(9.0, GROUND_Y, -11.0)
const BALLOON := Vector3(-16.8, 1.30, 1.6)
const BALLOON_POINT := Vector3(-16.0, 1.30, 3.8)
const MAST := Vector3(-12.6, 1.85, 9.0)
const KITE_POINT := Vector3(-11.4, 1.85, 10.6)
const FRAME := Vector3(10.8, 2.35, 7.9)
const PHOTO_POINT := Vector3(10.8, 2.35, 9.6)
## Twelve stand sites kept for the park's arcade games, three in each area.
## `stand` is the centre of the booth (ArcadeStands.FOOTPRINT, on its deck's
## height) and `point` where the visitor stands to play. A site shows a covered
## booth and a "準備中" tag until an ArcadeStands row for "sky" uses the same `stand`.
const STAND_SITES: Array[Dictionary] = [
	{"area": "wheel", "stand": Vector3(3.0, GROUND_Y, -8.4), "point": Vector3(3.95, GROUND_Y, -7.05)},
	{"area": "wheel", "stand": Vector3(15.0, GROUND_Y, -11.6), "point": Vector3(15.95, GROUND_Y, -10.25)},
	{"area": "wheel", "stand": Vector3(-7.6, GROUND_Y, -12.8), "point": Vector3(-6.65, GROUND_Y, -11.45)},
	{"area": "isles", "stand": Vector3(-12.6, 0.75, -6.0), "point": Vector3(-11.65, 0.75, -4.65)},
	{"area": "isles", "stand": Vector3(-7.6, 1.30, 2.4), "point": Vector3(-6.65, 1.30, 3.75)},
	{"area": "isles", "stand": Vector3(0.6, 1.80, 5.8), "point": Vector3(1.55, 1.80, 7.15)},
	{"area": "kites", "stand": Vector3(-16.4, 1.85, 11.4), "point": Vector3(-15.45, 1.85, 12.75)},
	{"area": "kites", "stand": Vector3(-12.4, 1.85, 14.4), "point": Vector3(-11.45, 1.85, 15.75)},
	{"area": "kites", "stand": Vector3(-7.6, 1.85, 12.0), "point": Vector3(-6.65, 1.85, 13.35)},
	{"area": "photo", "stand": Vector3(7.0, 2.35, 11.4), "point": Vector3(7.95, 2.35, 12.75)},
	{"area": "photo", "stand": Vector3(14.0, 2.35, 11.6), "point": Vector3(14.95, 2.35, 12.95)},
	{"area": "photo", "stand": Vector3(10.6, 2.35, 13.4), "point": Vector3(11.55, 2.35, 14.75)},
]
const LINK_OVERLAP := 0.6
const FOOTPRINT: Array[Vector2] = [Vector2(-0.30, -0.30), Vector2(0.30, -0.30), Vector2(-0.30, 0.30), Vector2(0.30, 0.30)]
const SNAPS := ["雲在腳下，風在耳邊——喀嚓！", "摩天輪剛好轉到最高——喀嚓！", "風箏跑進了畫面——喀嚓！", "一朵雲飄過鏡頭——喀嚓！"]

static var _links: Array[Dictionary] = []

var _kit: Kit
var _scenery: Scenery
var _life: Life
var _last_safe := ENTRY
var _recoveries := 0
var _snap := 0


func _build_region_geometry() -> void:
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	await _scenery.build()
	await build_pause()
	ArcadeStands.build(self, "sky")
	_life = Life.new(self, _scenery)
	_life.build()
	await build_pause()
	_kit.finish()
	_life.hold_still()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("sky:wheel", "摩天輪 · 推它轉快一點", WHEEL_POINT)
	_point("sky:balloon", "浮島步道 · 拉拉熱氣球的繩", BALLOON_POINT)
	_point("sky:kites", "風箏台 · 把風箏放高", KITE_POINT)
	_point("sky:photo", "雲霄攝影點 · 喀嚓一張", PHOTO_POINT)
	current_area = _area_at_position(ENTRY)


## Sites still waiting for a game: no ArcadeStands row stands on them yet.
static func open_sites() -> Array[Dictionary]:
	return StandSites.open("sky", STAND_SITES)


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


# --- Floor plan ------------------------------------------------------------------

static func pad(id: String) -> Dictionary:
	for entry: Dictionary in PADS:
		if entry.id == id: return entry
	return {}


static func in_pad(entry: Dictionary, point: Vector2, margin := 0.0) -> bool:
	var reach: Vector2 = (entry.radius as Vector2) - Vector2(margin, margin)
	var d := (point - (entry.centre as Vector2)) / reach
	return d.length_squared() <= 1.0


## Every link with its line trimmed to the decks' edges: {from, to, kind, width,
## area, a, b (district x/z), ya, yb (deck heights at each end)}.
static func links() -> Array[Dictionary]:
	if _links.is_empty():
		for spec: Dictionary in LINKS:
			var start := pad(spec.from)
			var finish := pad(spec.to)
			var a: Vector2 = spec.get("a", start.centre)
			var b: Vector2 = spec.get("b", finish.centre)
			_links.append({"from": spec.from, "to": spec.to, "kind": spec.kind, "width": spec.width,
				"area": start.area if spec.kind == "stair" else finish.area,
				"a": _edge(start, a, b), "b": _edge(finish, b, a), "ya": start.y, "yb": finish.y})
	return _links


## Where the line from `inside` toward `outside` leaves a deck.
static func _edge(entry: Dictionary, inside: Vector2, outside: Vector2) -> Vector2:
	var low := 0.0
	var high := 1.0
	for step in 32:
		var middle := (low + high) * 0.5
		if in_pad(entry, inside.lerp(outside, middle)): low = middle
		else: high = middle
	return inside.lerp(outside, low)


## How far along a link (0..1) `point` lies, or -1 off its strip. The strip
## reaches LINK_OVERLAP past each end, so where a deck's curved edge meets the
## square end of a ramp there is no gap to trip over.
static func link_along(link: Dictionary, point: Vector2) -> float:
	var a: Vector2 = link.a
	var b: Vector2 = link.b
	var span := b - a
	var t := (point - a).dot(span) / span.length_squared()
	var spill := LINK_OVERLAP / span.length()
	if t < -spill or t > 1.0 + spill: return -1.0
	return clampf(t, 0.0, 1.0) if point.distance_to(a + span * t) <= float(link.width) * 0.5 else -1.0


## Deck or link height at a district spot, or NAN off the floor plan.
static func floor_height(point: Vector2) -> float:
	for entry: Dictionary in PADS:
		if in_pad(entry, point): return entry.y
	for link: Dictionary in links():
		var t := link_along(link, point)
		if t >= 0.0: return lerpf(link.ya, link.yb, t)
	return NAN


func _area_at_position(position: Vector3) -> String:
	var point := Vector2(position.x, position.z)
	for entry: Dictionary in PADS:
		if in_pad(entry, point): return _area_label(entry.area)
	for link: Dictionary in links():
		if link_along(link, point) >= 0.0: return _area_label(link.area)
	return AREAS[0].label


static func _area_label(id: String) -> String:
	for area: Dictionary in AREAS:
		if area.id == id: return area.label
	return AREAS[0].label


func _stands_on(point: Vector2) -> bool:
	return not is_nan(floor_height(point)) or _open_ground(point)


func _safe_footing(position: Vector3) -> bool:
	if not position.is_finite(): return false
	var at := Vector2(position.x, position.z)
	for offset in FOOTPRINT:
		if not _stands_on(at + offset): return false
	return true


func is_walkable(position: Vector3) -> bool:
	return _safe_footing(position)


func ground_surface_y(position: Vector3) -> float:
	var at := Vector2(position.x, position.z)
	var height := floor_height(at)
	if not is_nan(height): return height
	return CLOUD_Y if BOUNDS.has_point(at) else LAWN_Y


## At a deck's edge the walker slides along it, and a step over it is caught
## and set back on the deck with a puff of cloud; a walker that somehow ends up
## off every deck (or below them) goes back to the last spot it stood safely.
func _constrain_player(previous_position: Vector3) -> bool:
	var current := player_spot()
	if not _safe_footing(previous_position) or current.y < ground_surface_y(previous_position) - 0.6:
		return _restore_footing()
	if _safe_footing(current):
		if player.is_on_floor() and absf(current.y - ground_surface_y(current)) < 0.15: _last_safe = current
		return false
	for slide: Vector3 in [Vector3(current.x, current.y, previous_position.z), Vector3(previous_position.x, current.y, current.z)]:
		if _safe_footing(slide) and Vector2(slide.x - previous_position.x, slide.z - previous_position.z).length() > 0.002:
			_set_player_spot(slide)
			return false
	_set_player_spot(previous_position)
	player.velocity = Vector3.ZERO
	if _life != null: _life.catch_step(current)
	return false


func _restore_footing() -> bool:
	_recoveries += 1
	place_player(_last_safe)
	_host().settle_avatar()
	if _life != null: _life.catch_step(_last_safe)
	return true


func last_safe_position() -> Vector3:
	return _last_safe


func safe_reset_count() -> int:
	return _recoveries


# --- What the areas do ---------------------------------------------------------

## A push on the wheel: it speeds up for a turn and the cabins swing.
func push_wheel() -> String:
	_life.push_wheel()
	return "摩天輪轉快了一圈，車廂盪呀盪。坐在最高的那格，看得到整座島。"


func tug_balloon() -> String:
	_life.tug_balloon()
	return "熱氣球往下一沉又彈回去。繩子綁得很牢，它哪裡也不去。"


func fly_kites() -> String:
	_life.fly_kites()
	return "風箏順著風往上爬。看風旗，它們永遠朝風吹去的方向飛。"


func take_photo() -> String:
	_life.flash()
	var line: String = SNAPS[_snap % SNAPS.size()]
	_snap += 1
	return "雲霄攝影點：" + line


func _process(delta: float) -> void:
	super._process(delta)
	if _life == null: return
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta)


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	if _scenery != null: _scenery.apply_time_of_day(lamp_energy_for_phase)
	if _life != null: _life.apply_time_of_day(lamp_energy_for_phase)


## High, bright air: a pale blue-white haze and a fuller fill by day; after
## dark a clear deep blue with the wheel lights blooming.
func _air(phase: String, island: Dictionary) -> Dictionary:
	var evening := phase in ["dusk", "night"]
	return {
		"sky": (island.sky as Color).lerp(Color("#1d2c58") if phase == "night" else Color("#bfe3f7"), 0.3),
		"fog": (island.fog as Color).lerp(Color("#243566") if evening else Color("#e6f3fb"), 0.36),
		"ambient": (island.ambient as Color).lerp(Color("#a9b9ff") if evening else Color("#f4fbff"), 0.26),
		"ambient_energy": float(island.ambient_energy) * (1.04 if evening else 1.12),
		"saturation": 1.05,
		"glow": float(island.glow) + (0.07 if evening else 0.02),
	}


func map_snapshot() -> Dictionary:
	var areas: Array[Dictionary] = []
	var land: Array[Rect2] = []
	for entry: Dictionary in PADS:
		var reach: Vector2 = entry.radius
		var rect := Rect2((entry.centre as Vector2) - reach, reach * 2.0)
		land.append(rect)
		areas.append({"id": entry.area, "label": _area_label(entry.area), "rect": rect, "centre": entry.centre, "radius": reach, "y": entry.y})
	var paths: Array[Dictionary] = []
	for link: Dictionary in links():
		paths.append({"a": link.a, "b": link.b, "width": link.width, "kind": link.kind})
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var at: Vector3 = player_spot() if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": land, "areas": areas, "links": paths, "points": stops,
		"sites": STAND_SITES.map(func(site: Dictionary) -> Vector3: return site.stand),
		"player": at, "area": _area_at_position(at), "region": "sky"}
