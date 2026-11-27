extends RefCounted
## Where things stand on the Welcome island: walkways, places and props as
## tables. Positions are world x/z in metres unless a field says otherwise.
## Edit a table to move something; builders and checks read the same rows.

const IslandShape = preload("res://game/world/island_shape.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const FieldRegistry = preload("res://game/world/field/field_registry.gd")

const PATH_TOP_Y := 0.18
const LAWN_Y := 0.055
const BEACH_TOP_Y := 0.03
## The straight paved stem from the avenue arch to the dock, and the plaza slab.
const STEM := Rect2(-4.5, -11.5, 9.0, 28.5)
const PLAZA := Rect2(-12.5, -8.0, 25.0, 16.0)
## Planks a walker may stand on beyond the shore.
const DOCK_WALK := Rect2(-2.05, 14.0, 4.1, 12.5)

## Curved walkways. Control points are smoothed into ribbons; "surface" is the look.
const PATHS := [
	{"id": "spine", "width": 5.0, "surface": "paving", "points": [Vector2(0,-10), Vector2(0,-16), Vector2(0,-24), Vector2(-4,-36), Vector2(-6,-48), Vector2(-4,-58), Vector2(0,-66), Vector2(6,-78), Vector2(6,-90), Vector2(3,-100), Vector2(2,-108), Vector2(2,-115.5)]},
	{"id": "toy", "width": 3.6, "surface": "paving", "points": [Vector2(2,-108), Vector2(14,-112), Vector2(22,-122), Vector2(22,-134), Vector2(15,-146), Vector2(11,-151), Vector2(10,-154)]},
	{"id": "nightmarket", "width": 3.6, "surface": "paving", "points": [Vector2(2,-108), Vector2(-12,-110), Vector2(-28,-116), Vector2(-44,-122), Vector2(-58,-124), Vector2(-64,-122.2), Vector2(-69.5,-121.8), Vector2(-75,-124.6), Vector2(-79,-127.5), Vector2(-80,-129.6)]},
	{"id": "circus", "width": 3.6, "surface": "paving", "points": [Vector2(22,-122), Vector2(32,-127), Vector2(42,-131), Vector2(47,-134.5), Vector2(52,-137.5), Vector2(60,-141), Vector2(68,-144.5), Vector2(75,-148), Vector2(79.2,-151.5), Vector2(80,-154)]},
	{"id": "west", "width": 3.6, "surface": "paving", "points": [Vector2(-4,-58), Vector2(-16,-62), Vector2(-30,-66), Vector2(-44,-64), Vector2(-58,-62), Vector2(-72,-64), Vector2(-86,-62)]},
	{"id": "harbor", "width": 3.6, "surface": "paving", "points": [Vector2(-12.5,-1.5), Vector2(-24,-6), Vector2(-38,-10), Vector2(-52,-6), Vector2(-66,0), Vector2(-76,5), Vector2(-82,8.4), Vector2(-84.7,9.5), Vector2(-92,15), Vector2(-97.5,28), Vector2(-98.5,44), Vector2(-97,57), Vector2(-94.5,63.5), Vector2(-92.4,65)]},
	{"id": "east", "width": 3.6, "surface": "paving", "points": [Vector2(0,-66), Vector2(12,-70), Vector2(24,-66), Vector2(31,-59), Vector2(33,-50), Vector2(44,-46), Vector2(53,-46.6), Vector2(58,-47.6)]},
	{"id": "garden", "width": 3.6, "surface": "paving", "points": [Vector2(12.5,-1.5), Vector2(24,-6), Vector2(38,-12), Vector2(52,-14), Vector2(66,-12), Vector2(78,-14), Vector2(84,-15.4), Vector2(86.6,-15.6), Vector2(93,-11), Vector2(97,-3), Vector2(99.5,9), Vector2(102,19.5), Vector2(107,24.8), Vector2(114,26.2), Vector2(121,25.4), Vector2(123,23.5), Vector2(123,21.4)]},
	{"id": "candy", "width": 3.6, "surface": "paving", "points": [Vector2(6,-90), Vector2(20,-88), Vector2(34,-86), Vector2(48,-84), Vector2(62,-84), Vector2(76,-82), Vector2(83,-80.6), Vector2(86.6,-79.6), Vector2(92,-72), Vector2(99,-63), Vector2(112,-58), Vector2(130,-56.5), Vector2(144,-57), Vector2(150,-58.5), Vector2(150.9,-61.7)]},
	{"id": "wind-terrace", "width": 4.0, "surface": "paving", "points": [Vector2(-6,-48), Vector2(-11.5,-48)]},
	{"id": "lookout", "width": 3.0, "surface": "trail", "points": [Vector2(48,-84), Vector2(50.5,-96), Vector2(48,-106), Vector2(46.6,-112)]},
	{"id": "lookout-deck", "width": 3.0, "surface": "trail", "points": [Vector2(46.4,-120.2), Vector2(48.8,-120.2)]},
	{"id": "kite", "width": 3.0, "surface": "trail", "points": [Vector2(-58,-62), Vector2(-60,-54), Vector2(-58,-49)]},
	{"id": "pond-lane", "width": 3.0, "surface": "trail", "points": [Vector2(-38,-10), Vector2(-34,-20), Vector2(-31,-32), Vector2(-30,-48), Vector2(-30,-66)]},
	{"id": "bandstand", "width": 3.0, "surface": "trail", "points": [Vector2(38,-12), Vector2(42,-20), Vector2(40,-27), Vector2(36,-38), Vector2(33,-50)]},
	{"id": "flower", "width": 3.0, "surface": "trail", "points": [Vector2(34,-86), Vector2(34,-93)]},
	{"id": "grove", "width": 3.0, "surface": "trail", "points": [Vector2(22,-122), Vector2(27,-116), Vector2(30,-113)]},
	{"id": "bench-pond", "width": 3.0, "surface": "trail", "points": [Vector2(6,-90), Vector2(-8,-90), Vector2(-20,-92), Vector2(-22,-100), Vector2(-12,-110)]},
	{"id": "spit", "width": 2.6, "surface": "boardwalk", "points": [Vector2(47,-134.5), Vector2(56,-134.2), Vector2(65,-136.5), Vector2(74,-135.5), Vector2(83.6,-134.6)]},
]
## The coastal loop: a trail a few metres inland from the waterline. It leaves
## the dock stem westward and comes back to the stem from the east.
const COAST_ROUTE_ID := "coast"
const COAST_ROUTE_WIDTH := 3.1
const COAST_ROUTE := [
	Vector2(-3,17), Vector2(-10,16.8), Vector2(-20,19), Vector2(-27,25), Vector2(-33,31), Vector2(-39,31.5), Vector2(-47,26), Vector2(-60,20), Vector2(-72,20), Vector2(-80,15), Vector2(-82,5.5), Vector2(-79.5,-3), Vector2(-71,-10), Vector2(-63,-24), Vector2(-66,-41),
	Vector2(-80,-52), Vector2(-91,-55), Vector2(-94,-61), Vector2(-92,-68), Vector2(-80,-72), Vector2(-64,-72), Vector2(-48,-78), Vector2(-42,-92), Vector2(-48,-104), Vector2(-58,-109), Vector2(-65,-114), Vector2(-63.5,-123.5), Vector2(-57,-130),
	Vector2(-50,-133), Vector2(-36,-133), Vector2(-22,-133), Vector2(-10,-138), Vector2(-2,-145), Vector2(3,-150), Vector2(10,-151.5), Vector2(17,-149.5), Vector2(26,-143), Vector2(38,-138), Vector2(47,-131), Vector2(46,-112),
	Vector2(52,-102), Vector2(62,-100), Vector2(72,-95), Vector2(80,-89.5), Vector2(84.5,-85), Vector2(83.5,-78.5), Vector2(76,-75.5), Vector2(66,-70), Vector2(57,-58), Vector2(55,-46), Vector2(66,-32), Vector2(77,-26.5), Vector2(84.5,-21.5), Vector2(84,-14.5),
	Vector2(77,-10), Vector2(68,-5), Vector2(60,6), Vector2(58,18), Vector2(53,25), Vector2(46,26), Vector2(36,19.5), Vector2(25,15), Vector2(14,11.5), Vector2(4.5,11),
]
## Round paved clearings: x, z, radius. Junctions, and one under each game entry.
const JUNCTIONS := [Vector3(-4,-58,5.5), Vector3(6,-90,5.0), Vector3(2,-108,5.0), Vector3(-38,-10,3.6), Vector3(38,-12,3.6), Vector3(22,-122,3.4)]
const ENTRY_PAD_RADIUS := 2.4

## The four authored courts keep their own geometry; each is placed as a whole.
## "offset" moves the court from the coordinates it was authored at.
const DISTRICTS := {
	"wind": {"offset": Vector2(-6,-27.5), "footprint": Rect2(-14.5,-26.5,26.5,12.0)},
	"tide": {"offset": Vector2(29,-28), "footprint": Rect2(3.8,-34.3,10.4,8.4)},
	"lookout": {"offset": Vector2(44,-84), "footprint": Rect2(4.4,-38.8,10.0,5.2)},
	"stage": {"offset": Vector2(2,-78), "footprint": Rect2(-11.8,-46.2,23.6,10.4)},
}
## Twelve Welcome game entries, in game order. Any two stand at least 14 m apart.
const GAME_ENTRIES := [
	{"position": Vector3(-12,0,-44.5), "place": "風帆工坊", "district": "wind"},
	{"position": Vector3(-58,0,-48), "place": "風箏草坡"},
	{"position": Vector3(-32.5,0,-30), "place": "湧泉池"},
	{"position": Vector3(3,0,-60.5), "place": "風向路口"},
	{"position": Vector3(60,0,-48), "place": "帽子沙灘"},
	{"position": Vector3(40,0,-28), "place": "彩帶涼亭"},
	{"position": Vector3(34,0,-95.5), "place": "花壇園圃"},
	{"position": Vector3(35,0,-55), "place": "潮池廣場", "district": "tide"},
	{"position": Vector3(30,0,-112), "place": "林蔭空地"},
	{"position": Vector3(57,0.88,-121.6), "place": "海風觀景台", "district": "lookout"},
	{"position": Vector3(-22.5,0,-95), "place": "長椅池畔"},
	{"position": Vector3(8,0,-118.5), "place": "月影劇台", "district": "stage"},
]
const MIN_ENTRY_SPACING := 14.0
## Gates of the regions that are not on the island yet stand at its edge, at the
## end of the road toward where the master plan puts each district: x, z, yaw in
## degrees (0 faces south). A district that stands on the island keeps its gate
## at its own door instead (see DistrictSites).
const GATES := {
	"hotel": Vector3(-36,34.6,180), "sky": Vector3(49.5,29,-160), "cinema": Vector3(85.5,-135.5,-60),
}
## The coastal loop's six landmarks. "position" is the plaque on the trail and
## "outward" the step from it to the landmark itself, which stands clear of the
## path on its inland or far side so it never hides the walker.
const COAST_STOPS := {
	"sail-loft": {"position": Vector3(-60,0.18,20), "outward": Vector3(0,0,-4.2)},
	"storm-bell": {"position": Vector3(-63.6,0.18,-27), "outward": Vector3(4,0,0)},
	"lighthouse": {"position": Vector3(-94,0.18,-61), "outward": Vector3(-4,0,0)},
	"star-court": {"position": Vector3(-22,0.18,-133), "outward": Vector3(0,0,-4)},
	"glass-garden": {"position": Vector3(66,0.18,-2.6), "outward": Vector3(-5.2,0,-3.4)},
	"tide-wheel": {"position": Vector3(58.6,0.18,12), "outward": Vector3(3.3,0,0)},
}
## Inland water: x, z, radius.
const PONDS := [Vector3(-41,-30,6.0), Vector3(-31,-95,5.5)]
## Tree clusters: x, z, radius, trees.
const GROVES := [
	Vector4(30,-112,11,9), Vector4(-20,-90,7,5), Vector4(-52,-24,9,6), Vector4(-66,-12,8,5), Vector4(-14,-128,9,6), Vector4(-44,-112,8,5),
	Vector4(48,-66,8,5), Vector4(20,-40,8,5), Vector4(58,-2,8,5), Vector4(70,-88,7,4), Vector4(-63,6,8,5), Vector4(20,-104,7,4),
	Vector4(-74,-56,7,4), Vector4(42,2,8,5), Vector4(-22,-22,7,4), Vector4(24,-22,7,4), Vector4(34,-140,6,4), Vector4(-40,-48,7,4),
]
## Flower meadows: x, z, radius.
const MEADOWS := [Vector3(-58,-50,9), Vector3(34,-98,7), Vector3(-14,-70,7), Vector3(26,-50,7), Vector3(-44,-72,6), Vector3(62,-22,7), Vector3(-30,2,7), Vector3(16,-142,5)]
## Rock outcrops with a grass cap: x, z. They break long views; none sits on a path.
const RIDGES := [Vector2(-50,-40), Vector2(8,-134), Vector2(52,-74), Vector2(16,-54), Vector2(48,10), Vector2(-32,-78), Vector2(20,-78), Vector2(-48,10)]
const RIDGE_CLEARANCE := 6.5
## Lamp posts along the walkways: x, z.
const LAMPPOSTS := [
	Vector2(3.4,-30), Vector2(-9.9,-56.2), Vector2(11.6,-86.4), Vector2(-3.4,-105.2), Vector2(-29.2,-27.6), Vector2(-55,-51), Vector2(62,-44), Vector2(43.5,-29),
	Vector2(37.5,-97), Vector2(27,-109.5), Vector2(-24.6,-98.4), Vector2(-41.6,-13.4), Vector2(35.5,-15.8), Vector2(18.4,-125.8), Vector2(-28,-62.4), Vector2(22,-70.2),
	Vector2(-9.4,-42.4), Vector2(6.2,-62.8), Vector2(29.2,-55.6), Vector2(51.2,-123.4), Vector2(10.4,-114.6),
]
## Benches: x, z.
const BENCHES := [Vector2(-41,-21.2), Vector2(-24.5,-88.5), Vector2(-26,-101.5), Vector2(44,-24.5), Vector2(-9,-64.5)]
## Beach parasols on the hat beach, and the planters that ring the flower garden: x, z.
const PARASOLS := [Vector2(64,-41.8), Vector2(62.6,-52.6), Vector2(61.6,-57.6)]
const PLANTERS := [Vector2(29.8,-97.5), Vector2(31.2,-100.6), Vector2(34.5,-101.8), Vector2(37.6,-100.2), Vector2(38.6,-97)]
## Standing structures that planting keeps away from: x, z, radius.
const STRUCTURES := [Vector3(45.2,-31.4,5.0), Vector3(-56.5,22.6,2.5)]
const LANDMARK_CLEARANCE := 4.8
const FIELD_GAME_CLEARANCE := 5.5
const FIELD_TOY_CLEARANCE := 2.6
const DISTRICT_FIELD_MARGIN := 2.2
## Step-on windmills along the first stretch of the promenade: x, z, and the
## side (-1 west, 1 east) its windmill stands on.
const WINDMILL_PADS := [Vector3(-1.4,-16,-1), Vector3(1.4,-23,1), Vector3(-3.3,-30,-1), Vector3(-3.6,-41,1)]

static var _paths: Array[Dictionary] = []
static var _segments: Array[Vector3] = []
static var _segment_ends: PackedVector2Array = PackedVector2Array()
static var _buckets: Dictionary = {}
const BUCKET := 6.0
const MAX_PATH_MARGIN := 2.0

## Every walkway with its smoothed centre line: {id, width, surface, line}.
static func paths() -> Array[Dictionary]:
	if _paths.is_empty():
		for path: Dictionary in PATHS:
			_paths.append({"id": path.id, "width": path.width, "surface": path.surface, "line": IslandShape.smooth(path.points, false)})
		_paths.append({"id": COAST_ROUTE_ID, "width": COAST_ROUTE_WIDTH, "surface": "trail", "line": coast_route()})
	return _paths

static func coast_route() -> PackedVector2Array:
	return IslandShape.smooth(COAST_ROUTE, false)

## Paved clearings as x, z, radius: junctions plus the pad under each game entry.
static func clearings() -> Array[Vector3]:
	var discs: Array[Vector3] = []
	discs.assign(JUNCTIONS)
	for entry: Dictionary in GAME_ENTRIES:
		if not entry.has("district"): discs.append(Vector3(entry.position.x, entry.position.z, ENTRY_PAD_RADIUS))
	return discs

## True on any ribbon or paved clearing, or within `margin` (up to
## MAX_PATH_MARGIN) of one.
static func on_path(point: Vector2, margin := 0.0) -> bool:
	if _buckets.is_empty(): _index_paths()
	var cell: Variant = _buckets.get(Vector2i((point / BUCKET).floor()))
	if cell == null: return false
	for index: int in cell:
		var reach := _segments[index].z + margin
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, Vector2(_segments[index].x, _segments[index].y), _segment_ends[index])) <= reach * reach:
			return true
	return false

static func _index_paths() -> void:
	for path in paths():
		var line: PackedVector2Array = path.line
		for index in line.size() - 1:
			_add_segment(line[index], line[index + 1], float(path.width) * 0.5)
	for disc in clearings():
		_add_segment(Vector2(disc.x, disc.y), Vector2(disc.x, disc.y), disc.z)

static func _add_segment(from: Vector2, to: Vector2, reach: float) -> void:
	var index := _segments.size()
	_segments.append(Vector3(from.x, from.y, reach))
	_segment_ends.append(to)
	var spread := Vector2.ONE * (reach + MAX_PATH_MARGIN)
	var low := ((Vector2(minf(from.x, to.x), minf(from.y, to.y)) - spread) / BUCKET).floor()
	var high := ((Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + spread) / BUCKET).floor()
	for bx in range(int(low.x), int(high.x) + 1):
		for bz in range(int(low.y), int(high.y) + 1):
			var key := Vector2i(bx, bz)
			if not _buckets.has(key): _buckets[key] = PackedInt32Array()
			_buckets[key].append(index)

## A court's authored coordinates moved to where the court now stands.
static func district_point(district: String, authored: Vector3) -> Vector3:
	var offset: Vector2 = DISTRICTS[district].offset
	return authored + Vector3(offset.x, 0, offset.y)

## Height of a court's deck, ramp or paving at `point`, or -1 away from them.
static func district_surface_y(point: Vector2) -> float:
	var p := point - (DISTRICTS.lookout.offset as Vector2)
	if absf(p.y + 36.2) <= 1.8:
		if p.x >= 9.0 and p.x <= 13.8: return 0.58
		if p.x >= 6.5 and p.x < 9.0: return lerpf(0.2, 0.60, inverse_lerp(6.5, 9.0, p.x))
		if p.x >= 4.4 and p.x < 6.5: return 0.18
	p = point - (DISTRICTS.wind.offset as Vector2)
	if p.x >= -13.5 and p.x <= -4.5 and p.y >= -25.5 and p.y <= -15.5: return 0.17
	p = point - (DISTRICTS.tide.offset as Vector2)
	if p.x >= 4.3 and p.x <= 13.7 and p.y >= -33.8 and p.y <= -26.4: return 0.15
	p = point - (DISTRICTS.stage.offset as Vector2)
	if absf(p.x) <= 7.0 and p.y >= -43.75 and p.y <= -37.15: return 0.18
	return -1.0

static func has_gate(region: String) -> bool:
	return GATES.has(region) or DistrictSites.has(region)

## Every region with a gate on the island, edge gates first.
static func gate_regions() -> Array:
	return GATES.keys() + DistrictSites.regions()

static func gate_position(region: String) -> Vector3:
	if DistrictSites.has(region): return DistrictSites.gate_position(region)
	var gate: Vector3 = GATES[region]
	return Vector3(gate.x, 0, gate.y)

static func gate_yaw(region: String) -> float:
	if DistrictSites.has(region): return DistrictSites.gate_yaw(region)
	return deg_to_rad((GATES[region] as Vector3).z)

## Where a visitor stands to use a gate: two metres out from its front.
static func gate_point(region: String) -> Vector3:
	return gate_position(region) + Vector3(0, 0, 2).rotated(Vector3.UP, gate_yaw(region))

static func stop_landmark(id: String) -> Vector3:
	return (COAST_STOPS[id].position as Vector3) + (COAST_STOPS[id].outward as Vector3)

static func in_pond(point: Vector2, margin := 0.0) -> bool:
	for pond: Vector3 in PONDS:
		if point.distance_to(Vector2(pond.x, pond.y)) <= pond.z + margin: return true
	return false

## Trees keep to open lawn: clear of paths and courts, and far enough inland
## that the trunk stays off the beach and its noon shadow stays out of the bay.
const TREE_SHORE_MARGIN := 1.2
## Clearance between a trunk's painted base and the nearest walkway edge.
const TREE_PATH_MARGIN := 1.3

static func tree_site_clear(spot: Vector2) -> bool:
	# The painted base meets the ground about 0.64 m in front of the anchor.
	return IslandShape.on_lawn(spot, TREE_SHORE_MARGIN) and not on_path(spot + Vector2(0, 0.64), TREE_PATH_MARGIN) and not keeps_clear(spot)

## True where planting would crowd a court, a pond, a gate or a game entry.
static func keeps_clear(point: Vector2, margin := 0.0) -> bool:
	if PLAZA.grow(4.0 + margin).has_point(point) or STEM.grow(1.5 + margin).has_point(point): return true
	if Rect2(-14.5, 5.6, 10.5, 8.8).grow(margin).has_point(point): return true
	if in_pond(point, 1.6 + margin): return true
	for district: Dictionary in DISTRICTS.values():
		if (district.footprint as Rect2).grow(1.5 + margin).has_point(point - (district.offset as Vector2)): return true
	for entry: Dictionary in GAME_ENTRIES:
		if point.distance_to(Vector2(entry.position.x, entry.position.z)) < 4.2 + margin: return true
	if DistrictSites.claims(point, 2.0 + margin): return true
	for region: String in gate_regions():
		var gate := gate_position(region)
		if point.distance_to(Vector2(gate.x, gate.z)) < 5.0 + margin: return true
	for site: Vector3 in STRUCTURES + JUNCTIONS:
		if point.distance_to(Vector2(site.x, site.y)) < site.z + margin: return true
	for ridge: Vector2 in RIDGES:
		if point.distance_to(ridge) < RIDGE_CLEARANCE + margin: return true
	for id: String in COAST_STOPS:
		var landmark := stop_landmark(id)
		if point.distance_to(Vector2(landmark.x, landmark.z)) < LANDMARK_CLEARANCE + margin: return true
	# Instant map games need open ground to play on; small toys a little room.
	# The palm toy shakes a palm that grows at its own spot, so it clears nothing.
	# District rows sit in the woods of the edge bands, so trees keep further off.
	for game: Dictionary in FieldRegistry.placed_games():
		var arena: Vector3 = game.get("arena", game.at)
		var extra := DISTRICT_FIELD_MARGIN if game.has("region") else 0.0
		if point.distance_to(Vector2(arena.x, arena.z)) < FIELD_GAME_CLEARANCE + extra + margin or point.distance_to(Vector2(game.at.x, game.at.z)) < FIELD_TOY_CLEARANCE + extra + margin: return true
	for toy: Dictionary in FieldRegistry.placed_toys():
		var extra := DISTRICT_FIELD_MARGIN if toy.has("region") else 0.0
		if toy.kind != "palm" and point.distance_to(Vector2(toy.at.x, toy.at.z)) < FIELD_TOY_CLEARANCE + extra + margin: return true
	return false
