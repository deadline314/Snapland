extends "res://game/world/park_world.gd"
## Starlight Cinema (星光影城): a film lot built on sandbars in the lagoon,
## reached from the sand spit by a boardwalk pier. The pier lands on the red
## carpet plaza, whose carpet climbs a ramp to the premiere palace; west of it
## the open-air screening house steps up in tiers of seats to the projector
## deck, whose stair drops to the backlot street of painted flats; the lane
## south from the plaza leads to the raised sound stage and its camera crane,
## and a lighting gantry runs from the stage back to the premiere terrace.
## Every rise is a slope, so no jump is ever needed; a step off a sandbar is
## caught and set back. This script owns what the walker can do (floors and
## their heights, the interaction points, the twelve kept stand sites);
## cinema_scenery builds the place and cinema_life runs the show.

const Kit := preload("res://game/world/scenery_kit.gd")
const Scenery := preload("res://game/world/cinema_scenery.gd")
const Life := preload("res://game/world/cinema_life.gd")
const ArcadeStands := preload("res://game/world/arcade_stands.gd")
const StandSites := preload("res://game/world/stand_sites.gd")
const GROUND_Y := 0.20
## Island lawn height, beyond the claim.
const LAWN_Y := 0.055
## The lagoon between the sandbars (the island's own sea level).
const WATER_Y := -0.42
## The top of the sandbars under the walkways.
const SAND_Y := 0.12
## On the plaza at the foot of the pier, where fast travel and the free return stand.
const ENTRY := Vector3(2.6, GROUND_Y, -11.0)
const BOUNDS := Rect2(-18, -14, 36, 28)
const AREAS: Array[Dictionary] = [
	{"id": "carpet", "label": "紅毯"},
	{"id": "cinema", "label": "放映館"},
	{"id": "backlot", "label": "布景街"},
	{"id": "stage", "label": "攝影台"},
]
## Walkable floors: rectangles in district x/z, level at `y`. `top` picks the
## surface in cinema_scenery. Floors at different heights never overlap.
const PADS: Array[Dictionary] = [
	{"id": "plaza", "area": "carpet", "rect": Rect2(-1.0, -12.6, 9.6, 6.8), "y": GROUND_Y, "top": "marble"},
	{"id": "premiere", "area": "carpet", "rect": Rect2(11.6, -12.6, 5.6, 7.0), "y": 1.00, "top": "marble"},
	{"id": "front", "area": "cinema", "rect": Rect2(-15.6, -12.4, 15.0, 3.6), "y": GROUND_Y, "top": "boards"},
	{"id": "tier1", "area": "cinema", "rect": Rect2(-15.6, -7.2, 12.4, 2.2), "y": 0.50, "top": "tier"},
	{"id": "tier2", "area": "cinema", "rect": Rect2(-15.6, -3.4, 12.4, 2.2), "y": 0.80, "top": "tier"},
	{"id": "booth", "area": "cinema", "rect": Rect2(-14.6, 0.4, 11.0, 2.8), "y": 1.10, "top": "boards"},
	{"id": "street", "area": "backlot", "rect": Rect2(-13.0, 7.0, 18.6, 4.6), "y": GROUND_Y, "top": "street"},
	{"id": "lane", "area": "backlot", "rect": Rect2(1.2, -6.0, 4.2, 13.2), "y": GROUND_Y, "top": "planks"},
	{"id": "stage", "area": "stage", "rect": Rect2(9.0, 0.0, 8.2, 10.4), "y": 1.10, "top": "stage"},
]
## Slopes between two floors: straight from `a` (inside `from`) toward `b`
## (inside `to`), trimmed to the floors' edges. `kind`: "carpet" (the red
## carpet ramp), "tiers" (a full-width rise drawn as steps), "stair",
## "ramp" or "gantry" (the lighting gantry, nearly level).
const LINKS: Array[Dictionary] = [
	{"from": "plaza", "to": "premiere", "width": 2.6, "kind": "carpet", "a": Vector2(4.0, -9.3), "b": Vector2(14.8, -9.3)},
	{"from": "front", "to": "tier1", "width": 12.4, "kind": "tiers", "a": Vector2(-9.4, -10.4), "b": Vector2(-9.4, -6.1)},
	{"from": "tier1", "to": "tier2", "width": 12.4, "kind": "tiers", "a": Vector2(-9.4, -6.1), "b": Vector2(-9.4, -2.3)},
	{"from": "tier2", "to": "booth", "width": 4.0, "kind": "tiers", "a": Vector2(-8.6, -2.3), "b": Vector2(-8.6, 1.8)},
	{"from": "booth", "to": "street", "width": 2.0, "kind": "stair", "a": Vector2(-5.6, 1.8), "b": Vector2(-5.6, 9.3)},
	{"from": "lane", "to": "stage", "width": 2.4, "kind": "ramp", "a": Vector2(3.3, 3.4), "b": Vector2(13.0, 3.4)},
	{"from": "premiere", "to": "stage", "width": 1.6, "kind": "gantry", "a": Vector2(16.2, -9.0), "b": Vector2(16.2, 5.0)},
]
## Landmarks and the spots where the walker uses them.
const SCREEN := Vector3(-9.4, GROUND_Y, -13.1)
const PROJECTOR := Vector3(-9.6, 1.10, 2.3)
const PROJECTOR_POINT := Vector3(-8.0, 1.10, 1.6)
const DOORS := Vector3(14.4, 1.00, -12.6)
const CARPET_POINT := Vector3(14.4, 1.00, -10.8)
const REWIND_FLAT := Vector3(-9.5, GROUND_Y, 6.4)
const FLATS_POINT := Vector3(-9.5, GROUND_Y, 8.4)
const CRANE := Vector3(14.8, 1.10, 2.0)
const CRANE_POINT := Vector3(12.8, 1.10, 3.4)
## Twelve stand sites kept for the cinema's arcade games, three in each area.
## `stand` is the centre of the booth (ArcadeStands.FOOTPRINT, on its floor's
## height) and `point` where the visitor stands to play. A site shows a covered
## booth and a "準備中" tag until an ArcadeStands row for "cinema" uses the same `stand`.
const STAND_SITES: Array[Dictionary] = [
	{"area": "carpet", "stand": Vector3(6.4, GROUND_Y, -11.6), "point": Vector3(7.35, GROUND_Y, -10.25)},
	{"area": "carpet", "stand": Vector3(6.4, GROUND_Y, -7.6), "point": Vector3(7.35, GROUND_Y, -6.25)},
	{"area": "carpet", "stand": Vector3(14.6, 1.00, -8.2), "point": Vector3(15.55, 1.00, -6.85)},
	{"area": "cinema", "stand": Vector3(-14.2, GROUND_Y, -11.2), "point": Vector3(-13.25, GROUND_Y, -9.85)},
	{"area": "cinema", "stand": Vector3(-2.4, GROUND_Y, -11.2), "point": Vector3(-1.45, GROUND_Y, -9.85)},
	{"area": "cinema", "stand": Vector3(-12.6, 1.10, 1.1), "point": Vector3(-11.65, 1.10, 2.45)},
	{"area": "backlot", "stand": Vector3(-12.0, GROUND_Y, 9.6), "point": Vector3(-11.05, GROUND_Y, 10.95)},
	{"area": "backlot", "stand": Vector3(2.0, GROUND_Y, 8.0), "point": Vector3(2.95, GROUND_Y, 9.35)},
	{"area": "backlot", "stand": Vector3(2.6, GROUND_Y, -3.6), "point": Vector3(3.55, GROUND_Y, -2.25)},
	{"area": "stage", "stand": Vector3(10.4, 1.10, 0.9), "point": Vector3(11.35, 1.10, 2.25)},
	{"area": "stage", "stand": Vector3(10.6, 1.10, 6.6), "point": Vector3(11.55, 1.10, 7.95)},
	{"area": "stage", "stand": Vector3(14.6, 1.10, 7.4), "point": Vector3(15.55, 1.10, 8.75)},
]
const LINK_OVERLAP := 0.6
const FOOTPRINT: Array[Vector2] = [Vector2(-0.30, -0.30), Vector2(0.30, -0.30), Vector2(-0.30, 0.30), Vector2(0.30, 0.30)]
const REELS := ["今晚放映：月光下的海鷗大盜", "今晚放映：螃蟹與我的夏天", "今晚放映：迷路的摩天輪", "今晚放映：沙洲上的大冒險"]

static var _links: Array[Dictionary] = []

var _kit: Kit
var _scenery: Scenery
var _life: Life
var _last_safe := ENTRY
var _recoveries := 0
var _reel := 0


func _build_region_geometry() -> void:
	_kit = Kit.new(self)
	_scenery = Scenery.new(self, _kit)
	await _scenery.build()
	await build_pause()
	ArcadeStands.build(self, "cinema")
	_life = Life.new(self, _scenery)
	_life.build()
	await build_pause()
	_kit.finish()
	_kit.set_water_level(WATER_Y)
	_life.hold_still()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("cinema:carpet", "紅毯 · 走一回星光大道", CARPET_POINT)
	_point("cinema:projector", "放映館 · 換一卷片", PROJECTOR_POINT)
	_point("cinema:flats", "布景街 · 推倒布景", FLATS_POINT)
	_point("cinema:crane", "攝影台 · 開麥拉", CRANE_POINT)
	current_area = _area_at_position(ENTRY)


## Sites still waiting for a game: no ArcadeStands row stands on them yet.
static func open_sites() -> Array[Dictionary]:
	return StandSites.open("cinema", STAND_SITES)


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


## Inside a floor's rectangle shrunk by `margin` (edges included).
static func in_pad(entry: Dictionary, point: Vector2, margin := 0.0) -> bool:
	var rect: Rect2 = entry.rect
	return point.x >= rect.position.x + margin and point.x <= rect.end.x - margin \
		and point.y >= rect.position.y + margin and point.y <= rect.end.y - margin


## Every link with its line trimmed to the floors' edges: {from, to, kind, width,
## area (the floor it leads to), a, b (district x/z), ya, yb (floor heights at each end)}.
static func links() -> Array[Dictionary]:
	if _links.is_empty():
		for spec: Dictionary in LINKS:
			var start := pad(spec.from)
			var finish := pad(spec.to)
			_links.append({"from": spec.from, "to": spec.to, "kind": spec.kind, "width": spec.width,
				"area": finish.area,
				"a": _edge(start, spec.a, spec.b), "b": _edge(finish, spec.b, spec.a), "ya": start.y, "yb": finish.y})
	return _links


## Where the line from `inside` toward `outside` leaves a floor.
static func _edge(entry: Dictionary, inside: Vector2, outside: Vector2) -> Vector2:
	var low := 0.0
	var high := 1.0
	for step in 32:
		var middle := (low + high) * 0.5
		if in_pad(entry, inside.lerp(outside, middle)): low = middle
		else: high = middle
	return inside.lerp(outside, low)


## How far along a link (0..1) `point` lies, or -1 off its strip. The strip
## reaches LINK_OVERLAP past each end, so a floor's edge never leaves a gap.
static func link_along(link: Dictionary, point: Vector2) -> float:
	var a: Vector2 = link.a
	var b: Vector2 = link.b
	var span := b - a
	var t := (point - a).dot(span) / span.length_squared()
	var spill := LINK_OVERLAP / span.length()
	if t < -spill or t > 1.0 + spill: return -1.0
	return clampf(t, 0.0, 1.0) if point.distance_to(a + span * t) <= float(link.width) * 0.5 else -1.0


## Floor or link height at a district spot, or NAN off the floor plan.
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
	return WATER_Y if BOUNDS.has_point(at) else LAWN_Y


## At a floor's edge the walker slides along it, and a step over it is caught
## and set back with a splash; a walker that somehow ends up off every floor
## (or below them) goes back to the last spot it stood safely.
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

## The red carpet: every flash along it pops at once.
func walk_carpet() -> String:
	_life.flash_carpet()
	return "紅毯兩旁的閃光燈一起閃！你對著鏡頭揮揮手，明天大概會上頭條。"


## A fresh reel: the film on the big screen changes.
func change_reel() -> String:
	_reel = (_reel + 1) % REELS.size()
	_life.change_reel(_reel)
	return "放映機喀啦喀啦換上新的一卷。" + String(REELS[_reel])


## A painted flat tips over flat on its face, then the film rewinds it back up.
func topple_flat() -> String:
	_life.topple_flat()
	return "布景啪地倒下去……然後像倒帶一樣，咻地站回原位。片場的東西都會倒帶。"


## The crane swoops, the clapper snaps and the lights flare.
func call_action() -> String:
	_life.call_action()
	return "「開麥拉！」場記板喀一聲，攝影機搖臂滑過整個攝影台。"


func reel_index() -> int:
	return _reel


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
	if _life != null: _life.apply_time_of_day(lamp_energy_for_phase, active_time_phase)


## A warm, golden film-lot haze by day; after dark a deep velvet night that
## lets the marquee, the screen and the searchlights glow.
func _air(phase: String, island: Dictionary) -> Dictionary:
	var evening := phase in ["dusk", "night"]
	return {
		"sky": (island.sky as Color).lerp(Color("#1c1636") if phase == "night" else Color("#f4dcb0"), 0.24),
		"fog": (island.fog as Color).lerp(Color("#2a2140") if evening else Color("#f6e6c8"), 0.3),
		"ambient": (island.ambient as Color).lerp(Color("#b8a0d8") if evening else Color("#fff1dc"), 0.22),
		"ambient_energy": float(island.ambient_energy) * (1.0 if evening else 1.06),
		"saturation": 1.06,
		"glow": float(island.glow) + (0.1 if evening else 0.02),
	}


func map_snapshot() -> Dictionary:
	var areas: Array[Dictionary] = []
	var land: Array[Rect2] = []
	for entry: Dictionary in PADS:
		land.append(entry.rect)
		areas.append({"id": entry.area, "label": _area_label(entry.area), "rect": entry.rect, "y": entry.y})
	var paths: Array[Dictionary] = []
	for link: Dictionary in links():
		paths.append({"a": link.a, "b": link.b, "width": link.width, "kind": link.kind})
	var stops: Array[Dictionary] = []
	for point in points:
		stops.append({"id": point.id, "label": point.label, "position": point.position})
	var at: Vector3 = player_spot() if is_instance_valid(player) else ENTRY
	return {"bounds": BOUNDS, "land": land, "areas": areas, "links": paths, "points": stops,
		"sites": STAND_SITES.map(func(site: Dictionary) -> Vector3: return site.stand),
		"player": at, "area": _area_at_position(at), "region": "cinema"}
