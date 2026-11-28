extends "res://game/world/park_world.gd"
## The underground demon theatre (地底惡魔劇場), the optional final zone. A
## small islet in the west bay carries the entrance: a bridge from the island's
## gate lands on its plaza, a ticket booth stands beside it, and a grand stair
## sinks into a marquee arch in the islet's rock. At the foot of the stair a
## short fade takes the walker down to the theatre, a separate level of the same
## world far below the sea (the follow camera rides 16.5 m above the walker, so
## nothing less deep would keep the island out of view). Down there the stage
## door opens on the backstage corridor; its ramp climbs to the raised stage,
## the curtain-call platform stands at stage right, stairs at both stage-front
## corners drop to the stalls behind the sunken orchestra pit, and the stepped
## tiers of seats rise behind the stalls. Every rise is a slope, so no jump is
## ever needed. This script owns what the walker can do (both levels' floors,
## the passages between them, the interaction points, the eight kept stand
## sites, the theatre's light); theatre_scenery builds the place and
## theatre_life runs the curtains, the spotlight and the rest of the show.

const Kit := preload("res://game/world/scenery_kit.gd")
const Scenery := preload("res://game/world/theatre_scenery.gd")
const Life := preload("res://game/world/theatre_life.gd")
const ArcadeStands := preload("res://game/world/arcade_stands.gd")
const StandSites := preload("res://game/world/stand_sites.gd")
## The islet's plaza on its rock, the bridge's landing below it and the foot
## of the grand stair. Nothing on the islet is lower than the landing: the
## island's walking floor lies under the whole bay at that height.
const ISLET_Y := 1.6
const LANDING_Y := 0.2
const WELL_Y := 0.2
## The grand stair's middle line.
const STAIR_X := -7.5
## Island lawn height, beyond the claim.
const LAWN_Y := 0.055
## The bay round the islet (the island's own sea level).
const WATER_Y := -0.42
## The rock shelf of the islet under its floors.
const ROCK_Y := 0.12
## The theatre's stalls. Far enough under the sea that the camera, riding
## 16.5 m above the walker, stays below everything on the island.
const FLOOR := -40.0
## Spots lower than this are on the theatre's level.
const BELOW := -20.0
## The cavern's rock floor round the theatre.
const CAVERN_Y := FLOOR - 0.75
## On the landing at the bridge's foot, where fast travel and the free return stand.
const ENTRY := Vector3(4.0, LANDING_Y, 0.6)
const BOUNDS := Rect2(-28, -11, 34, 30)
## What the map shows of the islet and its bridge.
const ISLET_PLAN := Rect2(-14, -12, 40, 16)
const AREAS: Array[Dictionary] = [
	{"id": "entrance", "label": "劇場入口"},
	{"id": "backstage", "label": "後台走廊"},
	{"id": "house", "label": "觀眾席"},
	{"id": "pit", "label": "樂池"},
	{"id": "stage", "label": "舞台"},
	{"id": "bow", "label": "謝幕台"},
]
## Walkable floors on both levels: rectangles in district x/z, level at `y`.
## `top` picks the surface in theatre_scenery. Floors at different heights never overlap.
const PADS: Array[Dictionary] = [
	{"id": "landing", "area": "entrance", "rect": Rect2(2.4, -1.6, 2.8, 3.2), "y": LANDING_Y, "top": "paving"},
	{"id": "islet", "area": "entrance", "rect": Rect2(-12.5, -2.0, 9.9, 5.0), "y": ISLET_Y, "top": "paving"},
	{"id": "well", "area": "entrance", "rect": Rect2(STAIR_X - 1.4, -9.0, 2.8, 1.4), "y": WELL_Y, "top": "paving"},
	{"id": "corridor", "area": "backstage", "rect": Rect2(-27.0, -9.5, 4.4, 27.0), "y": FLOOR, "top": "boards"},
	{"id": "stage", "area": "stage", "rect": Rect2(-18.0, -9.5, 17.0, 7.5), "y": FLOOR + 1.2, "top": "stage"},
	{"id": "bow", "area": "bow", "rect": Rect2(1.0, -8.5, 3.6, 5.0), "y": FLOOR + 1.7, "top": "bow"},
	{"id": "pit", "area": "pit", "rect": Rect2(-14.6, 0.2, 10.0, 2.8), "y": FLOOR - 0.4, "top": "pit"},
	{"id": "stalls", "area": "house", "rect": Rect2(-21.0, 4.6, 21.0, 4.1), "y": FLOOR, "top": "carpet"},
	{"id": "tier1", "area": "house", "rect": Rect2(-21.0, 10.3, 21.0, 2.2), "y": FLOOR + 0.45, "top": "carpet"},
	{"id": "tier2", "area": "house", "rect": Rect2(-21.0, 14.1, 21.0, 2.2), "y": FLOOR + 0.9, "top": "carpet"},
]
## Slopes between two floors: straight from `a` (inside `from`) toward `b`
## (inside `to`), trimmed to the floors' edges. `kind`: "climb" (the stone
## stair from the bridge up onto the islet), "descent" (the grand stair down
## into the rock), "ramp", "stair", "tiers" (a full-width rise drawn as steps)
## or "door" (a level doorway).
const LINKS: Array[Dictionary] = [
	{"from": "landing", "to": "islet", "width": 2.6, "kind": "climb", "a": Vector2(3.4, 0.0), "b": Vector2(-4.0, 0.0)},
	{"from": "islet", "to": "well", "width": 2.6, "kind": "descent", "a": Vector2(STAIR_X, -1.0), "b": Vector2(STAIR_X, -8.3)},
	{"from": "corridor", "to": "stage", "width": 2.2, "kind": "ramp", "a": Vector2(-24.8, -6.4), "b": Vector2(-14.0, -6.4)},
	{"from": "corridor", "to": "stalls", "width": 2.4, "kind": "door", "a": Vector2(-24.8, 6.1), "b": Vector2(-19.0, 6.1)},
	{"from": "stage", "to": "bow", "width": 2.0, "kind": "ramp", "a": Vector2(-3.0, -6.0), "b": Vector2(2.8, -6.0)},
	{"from": "stage", "to": "stalls", "width": 2.0, "kind": "stair", "a": Vector2(-16.8, -3.0), "b": Vector2(-16.8, 6.5)},
	{"from": "stage", "to": "stalls", "width": 2.0, "kind": "stair", "a": Vector2(-2.8, -3.0), "b": Vector2(-2.8, 6.5)},
	{"from": "stalls", "to": "pit", "width": 1.8, "kind": "stair", "a": Vector2(-10.5, 5.4), "b": Vector2(-10.5, 1.6)},
	{"from": "stalls", "to": "tier1", "width": 21.0, "kind": "tiers", "a": Vector2(-10.5, 7.1), "b": Vector2(-10.5, 11.4)},
	{"from": "tier1", "to": "tier2", "width": 21.0, "kind": "tiers", "a": Vector2(-10.5, 11.4), "b": Vector2(-10.5, 15.2)},
]
## The passages between the levels: walking north off the foot of the grand
## stair goes down, walking south through the stage door goes back up.
const DESCENT_Z := -8.0
const ASCENT_Z := 16.8
const DOWN_ARRIVAL := Vector3(-24.8, FLOOR, 15.2)
const UP_ARRIVAL := Vector3(STAIR_X, ISLET_Y, -1.0)
const FADE_OUT := 0.3
const FADE_IN := 0.45
## Landmarks and the spots where the walker uses them.
const TICKET_BOOTH := Vector3(-11.2, ISLET_Y, 1.0)
const TICKET_POINT := Vector3(-9.6, ISLET_Y, 1.8)
const MARQUEE := Vector3(STAIR_X, WELL_Y, -9.6)
const COSTUME_RAIL := Vector3(-26.3, FLOOR, 10.0)
const COSTUME_POINT := Vector3(-24.0, FLOOR, 10.2)
const PIT_POINT := Vector3(-8.0, FLOOR - 0.4, 1.9)
const STAGE_CENTRE := Vector3(-9.3, FLOOR + 1.2, -4.6)
const SPOTLIGHT_POINT := Vector3(-9.3, FLOOR + 1.2, -3.6)
const PHOTO_SPOT := Vector3(3.0, FLOOR + 1.7, -6.6)
const BOW_POINT := Vector3(2.8, FLOOR + 1.7, -4.9)
## Where the curtain hangs across the stage, and the opening it closes.
const CURTAIN_Z := -6.9
const CURTAIN_FROM := -14.0
const CURTAIN_TO := -4.6
## The curtains open while the walker is this close to the front of the stage.
const CURTAIN_REACH := 9.0
## Eight stand sites kept for the theatre's short games: four along the
## backstage corridor, four in the stage's wings. `stand` is the centre of the
## booth (ArcadeStands.FOOTPRINT, on its floor's height) and `point` where the
## visitor stands to play. A site shows a covered booth and a "準備中" tag until
## an ArcadeStands row for "theatre" uses the same `stand`.
const STAND_SITES: Array[Dictionary] = [
	{"area": "backstage", "stand": Vector3(-25.9, FLOOR, 12.6), "point": Vector3(-24.95, FLOOR, 13.95)},
	{"area": "backstage", "stand": Vector3(-25.9, FLOOR, 6.8), "point": Vector3(-24.95, FLOOR, 8.15)},
	{"area": "backstage", "stand": Vector3(-25.9, FLOOR, 1.6), "point": Vector3(-24.95, FLOOR, 2.95)},
	{"area": "backstage", "stand": Vector3(-25.9, FLOOR, -3.6), "point": Vector3(-24.95, FLOOR, -2.25)},
	{"area": "stage", "stand": Vector3(-16.9, FLOOR + 1.2, -8.75), "point": Vector3(-15.95, FLOOR + 1.2, -7.4)},
	{"area": "stage", "stand": Vector3(-16.9, FLOOR + 1.2, -3.8), "point": Vector3(-15.95, FLOOR + 1.2, -2.45)},
	{"area": "stage", "stand": Vector3(-3.2, FLOOR + 1.2, -8.75), "point": Vector3(-4.15, FLOOR + 1.2, -7.4)},
	{"area": "stage", "stand": Vector3(-3.2, FLOOR + 1.2, -3.8), "point": Vector3(-4.15, FLOOR + 1.2, -2.45)},
]
## How dark the house is (0 backstage, 1 in the seats) in each area; the light
## eases toward it over HOUSE_FADE seconds.
const HOUSE_DARK := {"backstage": 0.0, "house": 1.0, "pit": 1.0, "stage": 0.7, "bow": 0.6, "entrance": 0.0}
const HOUSE_FADE := 1.6
const LINK_OVERLAP := 0.6
const FOOTPRINT: Array[Vector2] = [Vector2(-0.30, -0.30), Vector2(0.30, -0.30), Vector2(-0.30, 0.30), Vector2(0.30, 0.30)]
const PROGRAMME := "節目單上寫著：「今晚的節目，是你一路收集來的整本相冊。」十區的拍貼排成十幕，最後一頁空著，留給謝幕的合照。"
const COSTUMES := ["迎賓大道的彩帶披肩", "潮汐碼頭的水手領巾", "糖果工廠的糖霜圍裙", "霓虹夜市的燈籠斗篷", "鏡之馬戲團的亮片背心",
	"發條玩具城的發條背包", "苔光溫室的花瓣帽", "幽幽旅館的門僮帽", "雲端遊樂場的雲朵圍巾", "星光影城的導演帽"]

static var _links: Array[Dictionary] = []

var _kit_up: Kit
var _kit_down: Kit
var _scenery: Scenery
var _life: Life
var _surface: Node3D
var _underground: Node3D
var _last_safe := ENTRY
var _recoveries := 0
var _costume := -1
var _below := false
var _passing := false
## How dark the house is now, and the value the light was last worked out for.
var _house := 0.0
var _air_house := -1.0
## The sticker count the playbill last showed.
var _billed := -2


func _build_region_geometry() -> void:
	_surface = Node3D.new()
	_surface.name = "TheatreSurface"
	add_child(_surface)
	_underground = Node3D.new()
	_underground.name = "TheatreUnderground"
	add_child(_underground)
	_kit_up = Kit.new(self)
	_kit_down = Kit.new(self)
	_scenery = Scenery.new(self, _kit_up, _kit_down)
	var first := get_child_count()
	await _scenery.build_surface()
	_kit_up.finish()
	_kit_up.set_water_level(WATER_Y)
	_adopt(_surface, first)
	await build_pause()
	first = get_child_count()
	await _scenery.build_underground()
	ArcadeStands.build(self, "theatre")
	_life = Life.new(self, _scenery)
	_life.build()
	_kit_down.finish()
	_adopt(_underground, first)
	_life.build_fade()
	await build_pause()
	_life.hold_still()
	_point("region:welcome", "返回迎賓大道 · 免費", ENTRY)
	_point("theatre:ticket", "售票亭 · 看今晚的節目單", TICKET_POINT)
	_point("theatre:costumes", "後台 · 翻翻十區的戲服", COSTUME_POINT)
	_point("theatre:pit", "樂池 · 請樂團起個音", PIT_POINT)
	_point("theatre:spotlight", "舞台 · 站上聚光燈", SPOTLIGHT_POINT)
	_point("theatre:bow", "謝幕台 · 練習謝幕", BOW_POINT)
	_show_level(false)
	current_area = _area_at_position(ENTRY)


## Move everything built since child `first` under `group`, so a level can be
## shown and hidden as one (lamps in a hidden level take no place in the budget).
func _adopt(group: Node3D, first: int) -> void:
	var built: Array[Node] = []
	for index in range(first, get_child_count()):
		var child := get_child(index)
		if child != _surface and child != _underground: built.append(child)
	for child in built:
		child.reparent(group)


## Sites still waiting for a game: no ArcadeStands row stands on them yet.
static func open_sites() -> Array[Dictionary]:
	return StandSites.open("theatre", STAND_SITES)


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


## True for a floor (or a height) on the theatre's level, under the sea.
static func is_below(y: float) -> bool:
	return y < BELOW


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


## Floor or link height at a district spot on one level, or NAN off its plan.
static func floor_height(point: Vector2, below: bool) -> float:
	for entry: Dictionary in PADS:
		if is_below(entry.y) == below and in_pad(entry, point): return entry.y
	for link: Dictionary in links():
		if is_below(link.ya) != below: continue
		var t := link_along(link, point)
		if t >= 0.0: return lerpf(link.ya, link.yb, t)
	return NAN


func _area_at_position(position: Vector3) -> String:
	var point := Vector2(position.x, position.z)
	var below := is_below(position.y)
	for entry: Dictionary in PADS:
		if is_below(entry.y) == below and in_pad(entry, point): return _area_label(entry.area)
	for link: Dictionary in links():
		if is_below(link.ya) == below and link_along(link, point) >= 0.0: return _area_label(link.area)
	return _area_label("backstage" if below else "entrance")


static func _area_id(position: Vector3) -> String:
	var point := Vector2(position.x, position.z)
	var below := is_below(position.y)
	for entry: Dictionary in PADS:
		if is_below(entry.y) == below and in_pad(entry, point): return entry.area
	for link: Dictionary in links():
		if is_below(link.ya) == below and link_along(link, point) >= 0.0: return link.area
	return "backstage" if below else "entrance"


static func _area_label(id: String) -> String:
	for area: Dictionary in AREAS:
		if area.id == id: return area.label
	return AREAS[0].label


func _stands_on(point: Vector2, below: bool) -> bool:
	return not is_nan(floor_height(point, below)) or (not below and _open_ground(point))


func _safe_footing(position: Vector3) -> bool:
	if not position.is_finite(): return false
	var at := Vector2(position.x, position.z)
	var below := is_below(position.y)
	for offset in FOOTPRINT:
		if not _stands_on(at + offset, below): return false
	return true


func is_walkable(position: Vector3) -> bool:
	return _safe_footing(position)


func ground_surface_y(position: Vector3) -> float:
	var at := Vector2(position.x, position.z)
	var below := is_below(position.y)
	var height := floor_height(at, below)
	if not is_nan(height): return height
	if below: return CAVERN_Y
	return WATER_Y if BOUNDS.has_point(at) else LAWN_Y


## At a floor's edge the walker slides along it, and a step over it is held
## back; a walker that somehow ends up off every floor (or below them) goes
## back to the last spot it stood safely.
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
	return false


func _restore_footing() -> bool:
	_recoveries += 1
	place_player(_last_safe)
	_host().settle_avatar()
	_show_level(is_below(_last_safe.y))
	return true


func last_safe_position() -> Vector3:
	return _last_safe


func safe_reset_count() -> int:
	return _recoveries


# --- Between the levels -------------------------------------------------------------

## True while the walker is on the theatre's level.
func is_underground() -> bool:
	return _below


func is_passing() -> bool:
	return _passing


## Where the walk down begins: the foot of the grand stair on the islet.
func passage_entrance() -> Vector3:
	var well: Rect2 = pad("well").rect
	return Vector3(well.get_center().x, pad("well").y, well.get_center().y)


## Walk off the foot of the grand stair (down) or out through the stage door
## (up): the screen fades out, the walker is set down on the other level and
## the screen fades back in, under a second in all. Reduced motion cuts at once.
func pass_through(down: bool) -> void:
	if _passing: return
	var target := DOWN_ARRIVAL if down else UP_ARRIVAL
	if reduced_motion or not is_inside_tree():
		_arrive(target)
		return
	_passing = true
	var tween := create_tween()
	tween.tween_method(_life.set_fade, 0.0, 1.0, FADE_OUT)
	tween.tween_callback(_arrive.bind(target))
	tween.tween_method(_life.set_fade, 1.0, 0.0, FADE_IN)
	tween.tween_callback(func() -> void: _passing = false)


func _arrive(target: Vector3) -> void:
	place_player(target)
	_host().settle_avatar()
	_last_safe = target
	_house = HOUSE_DARK[_area_id(target)]
	_show_level(is_below(target.y))


## Show one level and hide the other; the light and the lamps follow.
func _show_level(below: bool) -> void:
	_below = below
	if is_instance_valid(_surface): _surface.visible = not below
	if is_instance_valid(_underground): _underground.visible = below
	_refresh_air()


func _check_passage(spot: Vector3) -> void:
	if _passing or blocked: return
	var at := Vector2(spot.x, spot.z)
	if not is_below(spot.y) and in_pad(pad("well"), at) and at.y < DESCENT_Z:
		pass_through(true)
	elif is_below(spot.y) and in_pad(pad("corridor"), at) and at.y > ASCENT_Z:
		pass_through(false)


# --- What the theatre does ------------------------------------------------------------

func read_programme() -> String:
	_life.flash_marquee()
	return PROGRAMME


## The next region's costume on the rail swings out.
func rummage_costumes() -> String:
	_costume = (_costume + 1) % COSTUMES.size()
	_life.swing_costumes(_costume)
	return "衣架上掛滿十區借來的戲服。你翻到一件%s，上面還留著那天的味道。" % COSTUMES[_costume]


func costume_index() -> int:
	return _costume


func strike_up() -> String:
	_life.strike_up()
	return "樂池裡的樂器自己跳了一下，奏出一聲「噹——」。觀眾席好像有誰在偷偷鼓掌。"


func take_spotlight() -> String:
	_life.flare_spotlight()
	return "聚光燈「啪」地打在你身上。台下一片黑，只聽得到自己的心跳。"


func practise_bow() -> String:
	_life.shower_petals()
	_host().play_action("celebrate")
	return "你對著空空的觀眾席深深一鞠躬，花瓣從頂上灑下來。謝幕合照就站在這顆金星上。"


func _process(delta: float) -> void:
	super._process(delta)
	if _life == null or not is_instance_valid(player): return
	var spot := player_spot()
	if is_below(spot.y) != _below and not _passing: _show_level(is_below(spot.y))
	_check_passage(spot)
	_ease_house(spot, delta)
	_update_playbill()
	if reduced_motion:
		_life.hold_still()
	elif not blocked:
		_life.animate(delta, spot)


## The house lights fade down as the walker goes in among the seats.
func _ease_house(spot: Vector3, delta: float) -> void:
	var target: float = HOUSE_DARK[_area_id(spot)] if _below else 0.0
	_house = move_toward(_house, target, delta / HOUSE_FADE)
	if absf(_house - _air_house) > 0.02 or (_house == target and _air_house != target): _refresh_air()


## The playbill at the bridge counts down the cards still missing.
func _update_playbill() -> void:
	var count: int = embedded_in.district_host.sticker_count() if embedded_in != null and is_instance_valid(embedded_in.district_host) else -1
	if count == _billed: return
	_billed = count
	_scenery.playbill.text = Scenery.playbill_text(count, RegionRoutes.threshold("theatre"))


func house_darkness() -> float:
	return _house


func _refresh_air() -> void:
	_air_house = _house
	air_target = environment_target(active_time_phase)
	if is_inside_tree():
		_host().blend_air()
		_host()._update_lamp_selection(true)


func set_time_of_day(phase_id: Variant) -> void:
	super.set_time_of_day(phase_id)
	if _scenery != null: _scenery.apply_time_of_day(lamp_energy_for_phase)
	if _life != null: _life.apply_time_of_day(lamp_energy_for_phase)


## Lamps on the theatre's level burn whatever the hour; the house lights dim
## with the house. Lamps on the islet follow the island's evening.
func lamp_level(lamp: Light3D) -> float:
	if not lamp.has_meta(&"level"): return lamp_energy_for_phase
	var level := float(lamp.get_meta(&"level"))
	return level * (1.0 - 0.75 * _house) if lamp.has_meta(&"house") else level


## On the islet a violet hush hangs over the bay before the show. Below, the
## theatre has its own dark: no sun, a deep plum air, and the fill light
## sinking as the house goes dark, so the stage is the brightest thing there.
func _air(_phase: String, island: Dictionary) -> Dictionary:
	if not _below:
		return {
			"sky": (island.sky as Color).lerp(Color("#5b3a73"), 0.16),
			"fog": (island.fog as Color).lerp(Color("#7a5a8e"), 0.14),
			"ambient": (island.ambient as Color).lerp(Color("#f0d2ff"), 0.12),
			"saturation": 1.1,
			"glow": float(island.glow) + 0.02,
		}
	return {
		"sky": Color("#0b0712"),
		"fog": Color("#3a2848").lerp(Color("#1c1426"), _house),
		"ambient": Color("#b8a2d4").lerp(Color("#7a64a0"), _house),
		"ambient_energy": lerpf(0.95, 0.4, _house),
		"sun_energy": 0.0,
		"glow": 0.16,
		"saturation": 1.08,
	}


## The plan of the level the walker is on: the islet, or the theatre below.
func map_snapshot() -> Dictionary:
	var at: Vector3 = player_spot() if is_instance_valid(player) else ENTRY
	var below := is_below(at.y)
	var base := FLOOR if below else LANDING_Y
	var areas: Array[Dictionary] = []
	var land: Array[Rect2] = []
	for entry: Dictionary in PADS:
		if is_below(entry.y) != below: continue
		land.append(entry.rect)
		# Heights are printed from the level's own floor, so raised floors read lighter.
		areas.append({"id": entry.area, "label": _area_label(entry.area), "rect": entry.rect, "y": float(entry.y) - base + 0.2})
	var paths: Array[Dictionary] = []
	for link: Dictionary in links():
		if is_below(link.ya) == below: paths.append({"a": link.a, "b": link.b, "width": link.width, "kind": link.kind})
	var stops: Array[Dictionary] = []
	for point in points:
		if is_below((point.position as Vector3).y) == below: stops.append({"id": point.id, "label": point.label, "position": point.position})
	var sites: Array = STAND_SITES.map(func(site: Dictionary) -> Vector3: return site.stand) if below else []
	if not below:
		# The bridge to the island's gate.
		var strip: Rect2 = DistrictSites.SITES["theatre"].approach
		paths.append({"a": Vector2(strip.position.x, strip.get_center().y), "b": Vector2(strip.end.x, strip.get_center().y), "width": strip.size.y, "kind": "bridge"})
	return {"bounds": BOUNDS if below else ISLET_PLAN, "land": land, "areas": areas, "links": paths, "points": stops, "sites": sites,
		"player": at, "area": _area_at_position(at), "below": below, "region": "theatre"}
