extends RefCounted
## Where each themed district stands on the continuous island and how it joins
## it. One row per district; edit a row to move or reshape a site. The island's
## ground, planting, gates, walking rules, light blending and the map all read
## this table, so a district cannot drift apart from the land around it.
##
## A district is authored around its own origin and is never rotated (its art
## faces the fixed camera). Rects are in the district's own x/z metres:
## - at: world position of the district's origin.
## - claim: the ground the district dresses and rules. The island plants
##   nothing here and walkers obey the district's own floor plan.
## - approach: the one strip a walker may cross between the island and the
##   district's floors; it must reach island ground beyond the claim.
## - approach_y: height of the approach surface.
## - arrival: where fast travel and old saves put the walker.
## - gate: x, z of the sticker gate at the outer end of the approach, and the
##   yaw in degrees of its front (0 faces south, toward the arriving visitor).
## - cutouts: rects where the island's lawn and beach give way to features the
##   district sinks below ground level (water, channels).
## - ground: tint the island lawn takes on toward the district, and how far.
## - shore (optional): true when the district dresses the coast inside its band
##   itself (shore rocks and trees sleep with it), so the island leaves it bare.

const BAND := 14.0
## The planted and tinted edge wanders this far either side of the smooth one.
const EDGE_WOBBLE := 3.5
const NOISE_CELL := 7.0
## A district is built when the walker first comes this close to its claim,
## shown and animated inside ACTIVE, and put to sleep again beyond DORMANT.
## The fixed camera never shows ground farther than about 40 m from the walker,
## tall roofs included, so all three lie beyond anything on screen.
const BUILD_RADIUS := 44.0
const ACTIVE_RADIUS := 44.0
const DORMANT_RADIUS := 54.0

const SITES := {
	"harbor": {
		"script": "res://game/world/harbor_world.gd",
		"at": Vector3(-62, 0, 60),
		"claim": Rect2(-16.6, -13.6, 33.2, 27.2),
		"approach": Rect2(-29.5, 3.8, 14.5, 2.4), "approach_y": 0.14,
		"arrival": Vector3(-12, 0.2, 5),
		"gate": Vector3(-28.4, 5.0, -90),
		"cutouts": [],
		"ground": Color("#b9a878"), "ground_strength": 0.55,
	},
	"candy": {
		"script": "res://game/world/candy_world.gd",
		"at": Vector3(150, 0, -92),
		"claim": Rect2(-38, -26, 65, 54),
		"approach": Rect2(-1.4, 12, 4.0, 16.9), "approach_y": 0.15,
		"arrival": Vector3(0, 0.2, 9),
		"gate": Vector3(0.9, 28.3, 0),
		"cutouts": [Rect2(12.1, -26, 8.3, 54), Rect2(4, 0, 9.3, 5)],
		"ground": Color("#c98fa6"), "ground_strength": 0.6,
	},
	"garden": {
		"script": "res://game/world/garden_world.gd",
		"at": Vector3(124, 0, -6),
		"claim": Rect2(-19, -19, 38, 44),
		"approach": Rect2(-2.6, 9.35, 4.8, 16.3), "approach_y": 0.12,
		"arrival": Vector3(0, 0.2, 7.8),
		"gate": Vector3(-1.0, 25.4, 0),
		"cutouts": [Rect2(-12.5, -12.2, 25.0, 22.05)],
		"ground": Color("#1f3b2c"), "ground_strength": 0.7,
	},
	# The north rim: the market in its valley to the west, the toy town on the
	# hill, the circus clearing to the east. Each road runs up from the plaza.
	"nightmarket": {
		"script": "res://game/world/nightmarket_world.gd",
		"at": Vector3(-80, 0, -160),
		"claim": Rect2(-26, -30, 52, 42),
		"approach": Rect2(-2.5, 9.4, 5.0, 19.6), "approach_y": 0.18,
		"arrival": Vector3(0, 0.2, 7.55),
		"gate": Vector3(0, 28.4, 0),
		"cutouts": [],
		"ground": Color("#4b5675"), "ground_strength": 0.62,
	},
	"toy": {
		"script": "res://game/world/toy_world.gd",
		"at": Vector3(10, 0, -185),
		"claim": Rect2(-31, -28, 62, 53),
		"approach": Rect2(-2.2, 9.3, 4.4, 21.2), "approach_y": 0.2,
		"arrival": Vector3(0, 0.2, 7.65),
		"gate": Vector3(0, 29.9, 0),
		"cutouts": [],
		"ground": Color("#9fb860"), "ground_strength": 0.4,
	},
	"circus": {
		"script": "res://game/world/circus_world.gd",
		"at": Vector3(80, 0, -185),
		"claim": Rect2(-24, -26, 48, 49),
		"approach": Rect2(-2.0, 9.4, 4.0, 20.2), "approach_y": 0.2,
		"arrival": Vector3(0, 0.2, 7.8),
		"gate": Vector3(0, 29.0, 0),
		"cutouts": [],
		"ground": Color("#b39a6a"), "ground_strength": 0.42,
	},
	# The south end of the west breakwater: a causeway runs down from the coastal
	# loop to the hotel's front door; its rooms open south toward the sea.
	"hotel": {
		"script": "res://game/world/hotel_world.gd",
		"at": Vector3(-16, 0, 84),
		"claim": Rect2(-17, -15, 34, 30),
		"approach": Rect2(-11.2, -25.0, 4.4, 11.8), "approach_y": 0.18,
		"arrival": Vector3(-9, 0.2, -11.6),
		"gate": Vector3(-9, -24.6, 180),
		"cutouts": [],
		"ground": Color("#9a8fc0"), "ground_strength": 0.55,
	},
	# The south end of the east breakwater: a cloud bridge runs down from the
	# coastal loop to a plaza of floating walkways over a sea of cloud.
	"sky": {
		"script": "res://game/world/sky_world.gd",
		"at": Vector3(52, 0, 76),
		"claim": Rect2(-22, -18, 44, 36),
		"approach": Rect2(-6.2, -30.4, 4.4, 14.8), "approach_y": 0.18,
		"arrival": Vector3(-4, 0.2, -13.6),
		"gate": Vector3(-4, -30.0, 180),
		"cutouts": [],
		"ground": Color("#b9d3e6"), "ground_strength": 0.5,
		"shore": true,
	},
}

static var _tint: ImageTexture

static func has(region: String) -> bool:
	return SITES.has(region)

static func regions() -> Array:
	return SITES.keys()

static func origin(region: String) -> Vector3:
	return SITES[region].at

static func to_local(region: String, point: Vector2) -> Vector2:
	var at: Vector3 = SITES[region].at
	return point - Vector2(at.x, at.z)

static func to_world(region: String, local: Vector3) -> Vector3:
	return local + (SITES[region].at as Vector3)

## A site rect moved to world coordinates.
static func world_rect(region: String, key: String) -> Rect2:
	var at: Vector3 = SITES[region].at
	var rect: Rect2 = SITES[region][key]
	return Rect2(rect.position + Vector2(at.x, at.z), rect.size)

## The district whose own walking rules apply at `point` (claim or approach), or "".
static func ruling(point: Vector2) -> String:
	for region: String in SITES:
		var local := to_local(region, point)
		if (SITES[region].claim as Rect2).has_point(local) or (SITES[region].approach as Rect2).has_point(local): return region
	return ""

## True inside any claim grown by `margin`: the island keeps its own planting out.
static func claims(point: Vector2, margin := 0.0) -> bool:
	for region: String in SITES:
		if (SITES[region].claim as Rect2).grow(margin).has_point(to_local(region, point)): return true
	return false

## Metres from `point` to a district's claim; 0 inside it.
static func distance(region: String, point: Vector2) -> float:
	var claim: Rect2 = SITES[region].claim
	var local := to_local(region, point)
	return local.distance_to(local.clamp(claim.position, claim.end))

## How much of the district's light and air reaches `point`: 1 in the claim,
## easing to 0 across the band. Smooth, so the light never flickers.
static func weight(region: String, point: Vector2) -> float:
	return 1.0 - smoothstep(0.0, BAND, distance(region, point))

## The same falloff with a wandering edge, for ground colour and planting.
static func ground_weight(region: String, point: Vector2) -> float:
	var reach := distance(region, point)
	if reach <= 0.0: return 1.0
	if reach >= BAND + EDGE_WOBBLE: return 0.0
	return 1.0 - smoothstep(0.0, BAND, reach + (_noise(point) - 0.5) * 2.0 * EDGE_WOBBLE)

## Where two bands overlap, how strongly a district holds `point`: its ground
## weight scaled by its own slow noise, so the two districts' props and planting
## interleave in patches instead of meeting at a straight midline.
static func share(region: String, point: Vector2) -> float:
	return ground_weight(region, point) * (0.5 + _noise(point * 1.4 + Vector2(float(region.hash() % 1000), 0.0)))

## True unless another district holds `point` more strongly.
static func holds(region: String, point: Vector2) -> bool:
	var own := share(region, point)
	for other: String in SITES:
		if other != region and share(other, point) > own: return false
	return true

## Repeatable 0..1 choice for a spot, to thin scattered props by weight.
static func chance(point: Vector2) -> float:
	return _hash(Vector2i(roundi(point.x * 7.0), roundi(point.y * 7.0)))

## True where a district that dresses its own shore holds the ground (its band).
static func dresses_shore(point: Vector2) -> bool:
	for region: String in SITES:
		if SITES[region].get("shore", false) and distance(region, point) <= BAND: return true
	return false

static func gate_position(region: String) -> Vector3:
	var gate: Vector3 = SITES[region].gate
	return to_world(region, Vector3(gate.x, 0, gate.y))

static func gate_yaw(region: String) -> float:
	return deg_to_rad((SITES[region].gate as Vector3).z)

static func arrival(region: String) -> Vector3:
	return to_world(region, SITES[region].arrival)

## Lawn tint for the ground shaders over the grid the island's distance field
## uses: rgb is the blended district colour, alpha how strongly to apply it.
static func tint_texture(grid_origin: Vector2, columns: int, rows: int, cell: float) -> ImageTexture:
	if _tint != null: return _tint
	var image := Image.create(columns, rows, false, Image.FORMAT_RGBA8)
	var reach := BAND + EDGE_WOBBLE
	for region: String in SITES:
		var site: Dictionary = SITES[region]
		var area := world_rect(region, "claim").grow(reach)
		var tone: Color = site.ground
		var low := ((area.position - grid_origin) / cell).floor()
		var high := ((area.end - grid_origin) / cell).ceil()
		for row in range(maxi(int(low.y), 0), mini(int(high.y), rows - 1) + 1):
			for column in range(maxi(int(low.x), 0), mini(int(high.x), columns - 1) + 1):
				var amount := ground_weight(region, grid_origin + Vector2(column, row) * cell) * float(site.ground_strength)
				if amount <= 0.0: continue
				# Overlapping bands blend their colours by strength rather than meeting at a line.
				var under := image.get_pixel(column, row)
				var mixed := Color(under.r, under.g, under.b).lerp(tone, amount / (amount + under.a))
				image.set_pixel(column, row, Color(mixed.r, mixed.g, mixed.b, maxf(amount, under.a)))
	_tint = ImageTexture.create_from_image(image)
	return _tint

static func _noise(point: Vector2) -> float:
	var scaled := point / NOISE_CELL
	var cell := Vector2i(scaled.floor())
	var blend := scaled - scaled.floor()
	blend = blend * blend * (Vector2(3, 3) - 2.0 * blend)
	return lerpf(lerpf(_hash(cell), _hash(cell + Vector2i(1, 0)), blend.x), lerpf(_hash(cell + Vector2i(0, 1)), _hash(cell + Vector2i(1, 1)), blend.x), blend.y)

static func _hash(cell: Vector2i) -> float:
	return fposmod(sin(float(cell.x) * 127.1 + float(cell.y) * 311.7) * 43758.5453, 1.0)
