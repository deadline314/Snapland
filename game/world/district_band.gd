extends RefCounted
## The island side of each district's transition band: the district's own odds
## and ends strewn over the island lawn, thick beside the district and thinning
## out toward the island, plus loose, sunken tiles and grass along every edge
## where the district's paving meets island grass, so no paving ends in a clean
## cut. One BANDS row per district; one placement routine reads it with the band
## falloff DistrictSites defines (DistrictSites.ground_weight); where two bands
## overlap, DistrictSites.holds splits the ground into interleaved patches so the
## two districts' props mix without ever overlapping. Built once into
## the district, so it sleeps and wakes with it: a few merged meshes, no
## per-frame work, every material from the shared cache.
##
## BANDS rows:
## - density: chance of a prop per CELL-sized patch where the band is full strength.
## - props: [kind, weight, min_weight]: how often a kind is picked, and the band
##   strength it needs (big pieces stay close to the district).
## - colors: the district's accent colours, handed to every prop builder.
## - tiles: colours of the crumbled paving along its edges.
## - edges: extra paving edges as Vector4(x1, z1, x2, z2) in district metres; the
##   approach strip's long sides outside the claim are always included.
## - scale: size of the props (default PROP_SCALE); cell: spacing of the
##   candidate spots (default CELL), finer where little ground is free.
## - beach: props may also stand on the sand above the waterline.
## - lamps: lights for the band's lanterns, taken from the shared lamp budget.
## - hang: "tree_lanterns" hangs paper lanterns from island trees in the band.

const DistrictSites = preload("res://game/world/district_sites.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const IslandLayout = preload("res://game/world/island_layout.gd")
const IslandScenery = preload("res://game/world/island_scenery.gd")
const SceneryKit = preload("res://game/world/scenery_kit.gd")
const PAINTED_FINISH = preload("res://game/world/painted_finish.gdshader")

const CELL := 2.2
## Props are modelled at about life size and drawn a little larger, so they read
## from the follow camera next to the district's own oversized scenery.
const PROP_SCALE := 1.4
## Clear ground kept around walkways and interaction points.
const CLEARANCE := 1.2
const GLOW_KEY := "district-band-glow"
const PAINTED_KEY := "district-band-painted"
const WARM := Color("#ffc978")
const WOOD := Color("#7a5638")
const DARK := Color("#3a2c24")
const GRASS := [Color("#5d8a52"), Color("#76985a"), Color("#4f7748")]

const BANDS := {
	"toy": {
		"density": 0.42, "props": [["block_kerb", 3.0, 0.0], ["toy_block", 2.5, 0.0], ["pinwheel", 3.5, 0.0], ["windup_key", 1.2, 0.45]],
		"colors": [Color("#e0504a"), Color("#3b82c4"), Color("#f2c84b"), Color("#5fae5a"), Color("#f4efe2")],
		"tiles": [Color("#d7b06a"), Color("#c99f5a"), Color("#dcb878"), Color("#e0504a"), Color("#3b82c4")],
	},
	"candy": {
		"density": 0.45, "props": [["cane_post", 3.0, 0.0], ["sugar_rock", 2.0, 0.0], ["gumballs", 2.5, 0.0], ["pipe", 1.2, 0.4]],
		"colors": [Color("#e85a7a"), Color("#8fd6c2"), Color("#f6d36b"), Color("#b79be0"), Color("#f7f0e6")],
		"tiles": [Color("#f3e5cf"), Color("#f5c9d6"), Color("#cfe9df"), Color("#efdcc4")],
		"edges": [Vector4(-12, 28, 14, 28)],
	},
	"circus": {
		"density": 0.4, "props": [["light_pole", 3.0, 0.15], ["pennant_stake", 3.0, 0.0], ["ticket_sign", 1.0, 0.35], ["wagon", 0.9, 0.55]],
		"colors": [Color("#c8463c"), Color("#f2c14e"), Color("#2f8f8a"), Color("#f4e6c8"), Color("#7a3d6e")],
		"tiles": [Color("#d9bf86"), Color("#cfae74"), Color("#b8884e"), Color("#e2c996")],
		"lamps": 1,
	},
	"nightmarket": {
		"density": 0.42, "props": [["lantern_post", 3.0, 0.0], ["puddle", 2.5, 0.0], ["slate_patch", 2.5, 0.2], ["vending_cart", 1.0, 0.5]],
		"colors": [Color("#e0533f"), Color("#f29a3a"), Color("#e96a9a"), Color("#2f6f73"), Color("#f1e4c8")],
		"tiles": [Color("#3d4558"), Color("#4a5368"), Color("#353b4b"), Color("#56607a")],
		"edges": [Vector4(-26, 12, 26, 12)],
		"lamps": 1, "hang": "tree_lanterns",
	},
	"garden": {
		"density": 0.45, "props": [["pots", 3.0, 0.0], ["moss_stone", 3.0, 0.0], ["trellis", 1.5, 0.35], ["watering_can", 1.0, 0.25]],
		"colors": [Color("#b8643f"), Color("#5f7f45"), Color("#e48fb0"), Color("#f2efe2"), Color("#5b8a6e")],
		"tiles": [Color("#8d8f80"), Color("#7d8572"), Color("#9a9a88"), Color("#6f7d5e")],
		"edges": [Vector4(-9, 25, 9, 25)],
	},
	"hotel": {
		# Lost luggage and umbrellas wander out of the hotel; room-number posts light the way in.
		"density": 0.6, "props": [["luggage", 3.0, 0.0], ["umbrella_stand", 2.0, 0.0], ["paper_crane", 2.5, 0.0], ["number_post", 1.4, 0.2]],
		"colors": [Color("#7a5a9e"), Color("#e79bb6"), Color("#4f8f99"), Color("#f4ecd8"), Color("#d9b45c")],
		"tiles": [Color("#b9a8d2"), Color("#a796c2"), Color("#cbbfdc"), Color("#e2d6bd")],
		"lamps": 1,
	},
	"sky": {
		# Little clouds have drifted down onto the lawn; windsocks and pinwheels
		# point downwind and small kites fly from stakes toward the park.
		"density": 0.5, "props": [["cloud_puff", 3.0, 0.0], ["pinwheel", 2.5, 0.0], ["windsock", 2.0, 0.15], ["kite_stake", 1.4, 0.3]],
		"colors": [Color("#ff8a6b"), Color("#7cc4ec"), Color("#ffd35c"), Color("#8fe0c4"), Color("#fbfdff")],
		"tiles": [Color("#c9bfa8"), Color("#b8ae98"), Color("#d4cbb5"), Color("#a9bccb")],
	},
	"cinema": {
		# Film cans roll out of the lot onto the lagoon's banks; little
		# clapperboards on stakes and floor spotlights point the way to the pier.
		"density": 0.5, "props": [["film_can", 3.0, 0.0], ["clapper_post", 2.5, 0.0], ["ticket_sign", 1.2, 0.25], ["spot_lamp", 1.6, 0.2]],
		"colors": [Color("#a8243a"), Color("#e8b54f"), Color("#2a2238"), Color("#fff1d6"), Color("#7fc4f2")],
		"tiles": [Color("#d8c39f"), Color("#cdb48a"), Color("#e2cfa8"), Color("#a8243a")],
		"beach": true,
	},
	"harbor": {
		# The bay keeps the harbour off the island: only the headland by its pier is band.
		"density": 8.0, "props": [["crates", 3.0, 0.0], ["rope_coil", 3.0, 0.0], ["net_poles", 1.5, 0.15], ["dinghy", 1.2, 0.25]],
		"colors": [Color("#3d6f9a"), Color("#c8463c"), Color("#efe6d2"), Color("#e48b3a"), Color("#5e7d7a")],
		"tiles": [Color("#9c7650"), Color("#86643f"), Color("#a8845c")],
		"scale": 1.05, "beach": true, "cell": 1.1,
	},
}
## Footprint radius of each kind in metres at scale 1.
const RADIUS := {
	"block_kerb": 1.0, "toy_block": 0.5, "pinwheel": 0.35, "windup_key": 0.5,
	"cane_post": 0.3, "sugar_rock": 0.55, "gumballs": 0.45, "pipe": 0.95,
	"light_pole": 0.4, "pennant_stake": 0.35, "ticket_sign": 0.6, "wagon": 1.55,
	"lantern_post": 0.4, "puddle": 0.85, "slate_patch": 0.8, "vending_cart": 1.05,
	"pots": 0.55, "moss_stone": 0.6, "trellis": 0.8, "watering_can": 0.35,
	"crates": 0.85, "rope_coil": 0.45, "net_poles": 1.2, "dinghy": 1.4,
	"luggage": 0.6, "umbrella_stand": 0.35, "paper_crane": 0.4, "number_post": 0.4,
	"cloud_puff": 0.7, "windsock": 0.4, "kite_stake": 0.5,
	"film_can": 0.45, "clapper_post": 0.4, "spot_lamp": 0.45,
}
## Kinds that face the camera (signs, wheels, lattices) turn only a little.
const FACING := ["pinwheel", "windup_key", "ticket_sign", "wagon", "vending_cart", "trellis", "net_poles", "pennant_stake", "dinghy", "number_post", "paper_crane", "kite_stake", "clapper_post"]
## Kinds that lie flat: no contact shadow, no grass at the foot.
const FLAT := ["puddle", "slate_patch"]
## Kinds big enough to walk into: they get an invisible obstacle.
const SOLID := ["wagon", "vending_cart", "dinghy", "trellis"]
const LIGHT_KINDS := ["light_pole", "lantern_post", "vending_cart", "number_post"]

class Placed:
	var kind: String
	var local: Vector2
	var radius: float
	var weight: float
	var ground: float
	var anchors: Array[Vector3] = []

var world: Node3D
var region: String
var row: Dictionary
var origin: Vector2
var claim: Rect2
var approach: Rect2
var props := SceneryKit.Sculpt.new()
var glow := SceneryKit.Sculpt.new()
var contacts: Array[Transform3D] = []
var placed: Array[Placed] = []
## Obstacles in district metres: x, z, radius.
var obstacles: Array[Vector3] = []
var trees: Array[Vector3] = []

## Dress the island side of an embedded district's band. Does nothing standalone.
func build(district_world: Node3D) -> void:
	if district_world.embedded_in == null or not BANDS.has(district_world.district): return
	_configure(district_world)
	_edges()
	_scatter()
	if row.get("hang", "") == "tree_lanterns": _tree_lanterns()
	_string_lights()
	_commit()

func _configure(district_world: Node3D) -> void:
	world = district_world
	region = world.district
	row = BANDS[region]
	origin = Vector2(world.position.x, world.position.z)
	claim = world._site.claim
	approach = world._site.approach
	var reach := claim.grow(DistrictSites.BAND + DistrictSites.EDGE_WOBBLE + 2.0)
	# Island trees (their painted base sits a little in front of the anchor), the
	# district's own billboards beyond its claim, lamp posts and benches.
	for site: Vector3 in IslandScenery._tree_sites():
		var local := Vector2(site.x, site.y) - origin
		if reach.has_point(local):
			trees.append(Vector3(local.x, local.y, site.z))
			obstacles.append(Vector3(local.x, local.y + 0.4, 1.1))
	for contact: Transform3D in world._foliage_contact_transforms:
		obstacles.append(Vector3(contact.origin.x, contact.origin.z, maxf(contact.basis.get_scale().x * 0.5, 0.4)))
	for lamp: Vector2 in IslandLayout.LAMPPOSTS:
		obstacles.append(Vector3(lamp.x - origin.x, lamp.y - origin.y, 0.6))
	for bench: Vector2 in IslandLayout.BENCHES:
		obstacles.append(Vector3(bench.x - origin.x, bench.y - origin.y, 1.3))

# --- Placement ---------------------------------------------------------------

## Props on a jittered grid over the band, kept where the band is strong.
func _scatter() -> void:
	var area := claim.grow(DistrictSites.BAND + DistrictSites.EDGE_WOBBLE)
	var cell := float(row.get("cell", CELL))
	var columns := int(ceil(area.size.x / cell))
	var rows := int(ceil(area.size.y / cell))
	var salt := region.hash() % 997
	for gz in rows:
		for gx in columns:
			var local := area.position + Vector2(float(gx) + _hash(gx, gz, salt), float(gz) + _hash(gx, gz, salt + 1)) * cell
			if claim.has_point(local): continue
			var spot := local + origin
			var weight := DistrictSites.ground_weight(region, spot)
			if weight <= 0.02 or _hash(gx, gz, salt + 2) > float(row.density) * pow(weight, 1.25) * pow(cell / CELL, 2.0): continue
			var kind := _pick(weight, _hash(gx, gz, salt + 3))
			if kind.is_empty(): continue
			var scale := (0.88 + _hash(gx, gz, salt + 4) * 0.26) * float(row.get("scale", PROP_SCALE))
			var radius: float = RADIUS[kind] * scale
			var ground := _ground(local, radius)
			if is_nan(ground): continue
			var yaw := (_hash(gx, gz, salt + 5) - 0.5) * (1.4 if FACING.has(kind) else TAU)
			_place(kind, local, ground, yaw, scale, radius, weight, [_hash(gx, gz, salt + 6), _hash(gx, gz, salt + 7), _hash(gx, gz, salt + 8), _hash(gx, gz, salt + 9)])

func _pick(weight: float, roll: float) -> String:
	var total := 0.0
	for entry: Array in row.props:
		if weight >= float(entry[2]): total += float(entry[1])
	var running := 0.0
	for entry: Array in row.props:
		if weight < float(entry[2]): continue
		running += float(entry[1])
		if roll * total <= running: return entry[0]
	return ""

## Ground height for a footprint of `radius` at `local`, or NAN unless it stands
## wholly on open island lawn (or, where the row allows, wholly on dry sand),
## clear of walkways, interaction points, the approach and other props, and
## wholly on ground this district holds where its band overlaps a neighbour's.
func _ground(local: Vector2, radius: float) -> float:
	var spot := local + origin
	if approach.grow(CLEARANCE + radius).has_point(local): return NAN
	for other: Placed in placed:
		if local.distance_to(other.local) < other.radius + radius + 0.3: return NAN
	for other: Vector3 in obstacles:
		if local.distance_to(Vector2(other.x, other.y)) < other.z + radius: return NAN
	var lawn := 0
	var sand := 0
	for step in 7:
		var around := Vector2.ZERO if step == 0 else Vector2.from_angle(TAU * float(step) / 6.0)
		var rim := spot + around * radius
		if IslandLayout.on_path(rim, CLEARANCE) or DistrictSites.claims(rim, 0.5) or IslandLayout.in_pond(rim, 1.0): return NAN
		if not DistrictSites.holds(region, spot + around * (radius + 0.3)): return NAN
		if IslandShape.on_lawn(rim, 0.3): lawn += 1
		elif row.get("beach", false) and IslandShape.lawn_inset(rim) < -0.3 and IslandShape.distance_to_coast(rim) > 1.0: sand += 1
	if lawn != 7 and sand != 7: return NAN
	for point: Dictionary in world.embedded_in.points:
		var at: Vector3 = point.position
		if spot.distance_to(Vector2(at.x, at.z)) < CLEARANCE + radius: return NAN
	if IslandLayout.keeps_clear(spot): return NAN
	return IslandLayout.LAWN_Y if lawn == 7 else IslandLayout.BEACH_TOP_Y

func _place(kind: String, local: Vector2, ground: float, yaw: float, scale: float, radius: float, weight: float, seeds: Array) -> void:
	var record := Placed.new()
	record.kind = kind
	record.local = local
	record.radius = radius
	record.weight = weight
	record.ground = ground
	var frame := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale), Vector3(local.x, ground, local.y))
	props.frame = frame
	glow.frame = frame
	for anchor: Vector3 in call("_" + kind, PackedFloat32Array(seeds), row.colors):
		record.anchors.append(frame * anchor)
	if not FLAT.has(kind):
		contacts.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(radius * 1.7, 1.0, radius * 1.2)), Vector3(local.x, ground + 0.012, local.y)))
		# Grass at the foot, so nothing stands on a clean cut.
		for tuft in 2 if ground == IslandLayout.LAWN_Y else 0:
			var around := Vector2.from_angle(float(seeds[tuft]) * TAU) * radius * 0.8
			props.frame = Transform3D(Basis.from_scale(Vector3.ONE * 1.3), Vector3(local.x + around.x, ground, local.y + around.y))
			_tuft(props, Vector3.ZERO, float(seeds[tuft + 1]))
	placed.append(record)

## Crumbled tiles and grass along each edge where district paving meets island lawn.
func _edges() -> void:
	var lines: Array[Vector4] = []
	if approach.size.y >= approach.size.x:
		var from := maxf(approach.position.y, claim.end.y) if approach.end.y > claim.end.y else approach.position.y
		var to := approach.end.y if approach.end.y > claim.end.y else minf(approach.end.y, claim.position.y)
		lines.append(Vector4(approach.position.x, from, approach.position.x, to))
		lines.append(Vector4(approach.end.x, from, approach.end.x, to))
	else:
		var from := approach.position.x if approach.position.x < claim.position.x else claim.end.x
		var to := minf(approach.end.x, claim.position.x) if approach.position.x < claim.position.x else approach.end.x
		lines.append(Vector4(from, approach.position.y, to, approach.position.y))
		lines.append(Vector4(from, approach.end.y, to, approach.end.y))
	lines.append_array(row.get("edges", []))
	for index in lines.size():
		var line: Vector4 = lines[index]
		var inner := approach.get_center() if index < 2 else claim.get_center()
		_crumble(Vector2(line.x, line.y), Vector2(line.z, line.w), inner, index)

func _crumble(from: Vector2, to: Vector2, inner: Vector2, salt: int) -> void:
	var length := from.distance_to(to)
	if length < 0.5: return
	var along := (to - from) / length
	var out := along.orthogonal()
	if out.dot((from + to) * 0.5 - inner) < 0.0: out = -out
	var tiles: Array = row.tiles
	const STEP := 0.42
	for index in int(length / STEP):
		var t := (float(index) + 0.5) * STEP
		# How far the loose tiles creep out wanders along the edge.
		var spill := 0.35 + 1.5 * _smooth(t / 2.6 + float(salt) * 3.1)
		for depth in 4:
			var d := 0.2 + float(depth) * 0.44
			if d > spill: break
			if _hash(index, depth, salt * 31 + 5) > 0.92 - 0.45 * d / spill: continue
			var local := from + along * (t + (_hash(index, depth, salt) - 0.5) * 0.14) + out * (d + (_hash(index, depth, salt + 1) - 0.5) * 0.1)
			if not _edge_ground(local): continue
			var size := 0.34 + _hash(index, depth, salt + 2) * 0.12
			var tone: Color = tiles[int(_hash(index, depth, salt + 3) * tiles.size()) % tiles.size()]
			tone = tone.darkened(_hash(index, depth, salt + 4) * 0.12)
			var tilt := Basis(Vector3.UP, atan2(along.x, along.y) + (_hash(index, depth, salt + 6) - 0.5) * (0.15 + d * 0.5))
			# Tiles farther out sink into the turf and tip a little.
			tilt = tilt * Basis(Vector3.RIGHT, (_hash(index, depth, salt + 7) - 0.5) * 0.08 * d)
			var top := IslandLayout.LAWN_Y + 0.024 - d * 0.009
			props.frame = Transform3D.IDENTITY
			props.box(Vector3(local.x, top - 0.03, local.y), Vector3(size, 0.06, size * (0.9 + _hash(index, depth, salt + 8) * 0.2)), tone, tilt)
		# Grass grows through the joints and over the edge.
		if _hash(index, 7, salt) < 0.7:
			var tuft := from + along * t + out * (0.05 + _hash(index, 8, salt) * 0.5)
			if _edge_ground(tuft):
				props.frame = Transform3D.IDENTITY
				_tuft(props, Vector3(tuft.x, IslandLayout.LAWN_Y, tuft.y), _hash(index, 9, salt))

func _edge_ground(local: Vector2) -> bool:
	var spot := local + origin
	return not claim.has_point(local) and not approach.has_point(local) and IslandShape.on_lawn(spot, 0.3) and not IslandLayout.on_path(spot, 0.1) \
		and not DistrictSites.claims(spot) and not IslandLayout.in_pond(spot, 0.5)

## Paper lanterns in the island trees nearest the market, fewer as the band fades.
func _tree_lanterns() -> void:
	var view: Basis = world._view_basis
	for tree: Vector3 in trees:
		var local := Vector2(tree.x, tree.y)
		if claim.has_point(local): continue
		var weight := DistrictSites.ground_weight(region, local + origin)
		if weight < 0.1 or _hash(int(tree.z), 1, 77) > weight * 1.5: continue
		var height := 4.4
		var centre := Vector3(local.x, IslandLayout.LAWN_Y + height * 0.5, local.y) + view.z * 0.45
		var count := 1 + int(weight * 2.6)
		var previous := Vector3.INF
		for index in count:
			var across := lerpf(-0.26, 0.26, (float(index) + 0.5) / float(count)) * height + (_hash(int(tree.z), index, 78) - 0.5) * 0.4
			var at := centre + view.x * across + Vector3(0, -0.05 * height - _hash(int(tree.z), index, 79) * 0.35, 0)
			props.frame = Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), at)
			glow.frame = props.frame
			_lantern(Vector3.ZERO, row.colors[index % 3])
			props.frame = Transform3D.IDENTITY
			glow.frame = Transform3D.IDENTITY
			if previous.is_finite(): _string(previous + Vector3(0, 0.4, 0), at + Vector3(0, 0.4, 0), 0.2, false)
			previous = at

## Circus poles share strings of bulbs with each other or with a tree at the woods' edge.
func _string_lights() -> void:
	var poles: Array = placed.filter(func(item: Placed) -> bool: return item.kind == "light_pole")
	var linked := {}
	props.frame = Transform3D.IDENTITY
	glow.frame = Transform3D.IDENTITY
	for index in poles.size():
		var top: Vector3 = poles[index].anchors[0]
		var best := -1
		var best_gap := 11.0
		for other in poles.size():
			var gap: float = poles[index].local.distance_to(poles[other].local)
			if other == index or linked.has(Vector2i(mini(index, other), maxi(index, other))) or gap < 3.0 or gap > best_gap: continue
			best = other
			best_gap = gap
		if best >= 0:
			linked[Vector2i(mini(index, best), maxi(index, best))] = true
			_string(top, poles[best].anchors[0], 0.5, true)
			continue
		var nearest := Vector3.INF
		for tree: Vector3 in trees:
			var gap: float = poles[index].local.distance_to(Vector2(tree.x, tree.y))
			if gap > 2.5 and gap < 8.0 and (not nearest.is_finite() or gap < poles[index].local.distance_to(Vector2(nearest.x, nearest.z))):
				nearest = Vector3(tree.x, IslandLayout.LAWN_Y + 2.7, tree.y) + world._view_basis.z * 0.45
		if nearest.is_finite(): _string(top, nearest, 0.45, true)

func _string(from: Vector3, to: Vector3, sag: float, bulbs: bool) -> void:
	var count := maxi(3, int(from.distance_to(to) / 0.55))
	var previous := from
	for index in count + 1:
		var along := float(index) / float(count)
		var point := from.lerp(to, along) - Vector3(0, sag * 4.0 * along * (1.0 - along), 0)
		if index > 0: _rod(props, previous, point, 0.012, DARK, 3)
		if bulbs and index > 0 and index < count:
			glow.ball(point - Vector3(0, 0.07, 0), 0.055, WARM if index % 3 != 0 else Color("#ff9fb0"), Color.TRANSPARENT, 6, 3)
		previous = point

func _commit() -> void:
	if not props.is_empty():
		world._mesh(props.mesh(), Vector3.ZERO, _painted()).name = "BandProps"
	if not glow.is_empty():
		var bodies: MeshInstance3D = world._mesh(glow.mesh(), Vector3.ZERO, _glow())
		bodies.name = "BandGlow"
		bodies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not contacts.is_empty():
		var colors: Array[Color] = []
		colors.resize(contacts.size())
		colors.fill(Color.WHITE)
		var blob := PlaneMesh.new()
		blob.size = Vector2.ONE
		var shadows: MultiMeshInstance3D = world._multi_mesh(blob, Vector3.ZERO, contacts, colors, world.contact_shadow_material)
		shadows.name = "BandContacts"
		shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for item: Placed in placed:
		if not SOLID.has(item.kind): continue
		var body := StaticBody3D.new()
		body.name = "BandObstacle"
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = item.radius * 0.7
		cylinder.height = 1.6
		shape.shape = cylinder
		body.add_child(shape)
		body.position = Vector3(item.local.x, 0.8, item.local.y)
		world.add_child(body)
	# The brightest lanterns nearest the district light the ground around them.
	var lights: Array = placed.filter(func(item: Placed) -> bool: return LIGHT_KINDS.has(item.kind) and not item.anchors.is_empty())
	lights.sort_custom(func(a: Placed, b: Placed) -> bool: return a.weight > b.weight)
	for index in mini(int(row.get("lamps", 0)), lights.size()):
		var light := OmniLight3D.new()
		light.name = "BandLamp"
		light.position = lights[index].anchors[0] - Vector3(0, 0.3, 0)
		light.light_color = Color("#ffcf8a")
		light.omni_range = 6.0
		light.light_energy = 0.0
		world.add_child(light)
		world.lamps.append(light)
	world.set_meta(&"band_props", placed.map(func(item: Placed) -> Dictionary:
		return {"kind": item.kind, "at": item.local + origin, "radius": item.radius, "weight": item.weight}))

func _painted() -> ShaderMaterial:
	var cache: Dictionary = world.material_cache
	if cache.has(PAINTED_KEY): return cache[PAINTED_KEY]
	var material := ShaderMaterial.new()
	material.shader = PAINTED_FINISH
	material.set_shader_parameter("vertex_tint", true)
	cache[PAINTED_KEY] = material
	return material

func _glow() -> StandardMaterial3D:
	var cache: Dictionary = world.material_cache
	if cache.has(GLOW_KEY): return cache[GLOW_KEY]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = WARM
	material.emission_energy_multiplier = 0.0
	cache[GLOW_KEY] = material
	return material

# --- Shapes ------------------------------------------------------------------

## A triangle facing `toward`, whatever order its corners come in.
static func _face(s: SceneryKit.Sculpt, a: Vector3, b: Vector3, c: Vector3, toward: Vector3, color: Color) -> void:
	if (c - a).cross(b - a).dot(toward) > 0.0: s.tri(a, b, c, color)
	else: s.tri(a, c, b, color)

static func _rod(s: SceneryKit.Sculpt, from: Vector3, to: Vector3, radius: float, color: Color, sides := 5) -> void:
	var span := to - from
	if span.length() < 0.001: return
	s.tube((from + to) * 0.5, radius, radius, span.length(), color, sides, _along(span))

## A basis whose Y axis runs along `direction` (tubes are symmetric, so either way).
static func _along(direction: Vector3) -> Basis:
	var axis := direction.normalized()
	if axis.y < 0.0: axis = -axis
	return Basis(Quaternion(Vector3.UP, axis))

## A ring lying in its basis' XZ plane.
static func _ring(s: SceneryKit.Sculpt, center: Vector3, major: float, minor: float, color: Color, basis := Basis.IDENTITY, segments := 14, sides := 5) -> void:
	for i in segments:
		for j in sides:
			var corners: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := TAU * float(i + corner.x) / float(segments)
				var v := TAU * float(j + corner.y) / float(sides)
				corners.append(center + basis * (Vector3(cos(u), 0, sin(u)) * (major + minor * cos(v)) + Vector3(0, minor * sin(v), 0)))
			var u_mid := TAU * (float(i) + 0.5) / float(segments)
			var middle := center + basis * (Vector3(cos(u_mid), 0, sin(u_mid)) * major)
			var outward := (corners[0] + corners[2]) * 0.5 - middle
			_face(s, corners[0], corners[1], corners[2], outward, color)
			_face(s, corners[0], corners[2], corners[3], outward, color)

func _tuft(s: SceneryKit.Sculpt, base: Vector3, seed_value: float) -> void:
	for blade in 3:
		var lean := (float(blade) - 1.0) * 0.32 + (seed_value - 0.5) * 0.3
		var height := 0.22 + fposmod(seed_value * 7.3 + float(blade) * 0.37, 1.0) * 0.18
		var tilt := Basis(Vector3.UP, seed_value * TAU + float(blade) * 1.9) * Basis(Vector3.FORWARD, lean)
		s.box(base + tilt * Vector3(0, height * 0.5, 0), Vector3(0.05, height, 0.035), GRASS[(blade + int(seed_value * 3.0)) % 3], tilt)

func _lantern(at: Vector3, color: Color) -> void:
	props.box(at + Vector3(0, 0.27, 0), Vector3(0.015, 0.22, 0.015), DARK)
	props.tube(at + Vector3(0, 0.15, 0), 0.06, 0.075, 0.045, DARK, 8)
	props.tube(at - Vector3(0, 0.15, 0), 0.075, 0.06, 0.045, DARK, 8)
	props.box(at - Vector3(0, 0.22, 0), Vector3(0.025, 0.1, 0.025), color.darkened(0.35))
	glow.ball(at, 0.14, color, color.lightened(0.18), 8, 4, 1.05)

# --- Props (each returns anchors for strings and lamps, in prop metres) ------

func _block_kerb(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var count := 3 + int(h[0] * 2.0)
	for index in count:
		var x := (float(index) - float(count - 1) * 0.5) * 0.47
		var tone: Color = pal[(index + int(h[1] * 5.0)) % 4]
		var top := 0.2 - 0.035 * float((index + int(h[2] * 2.0)) % 2)
		var tilt := Basis(Vector3.FORWARD, (h[3] - 0.5) * 0.16 * (1.0 if index % 2 == 0 else -1.0))
		props.box(Vector3(x, top - 0.14, 0), Vector3(0.45, 0.28, 0.32), tone, tilt)
		for stud in 2:
			props.tube(Vector3(x + (float(stud) - 0.5) * 0.22, top + 0.025, 0), 0.07, 0.07, 0.05, tone.lightened(0.12), 8)
	return []

func _toy_block(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var size := 0.5 + h[0] * 0.16
	var tone: Color = pal[int(h[1] * 4.0) % 4]
	var tilt := Basis(Vector3.RIGHT, 0.12 + h[2] * 0.18)
	var centre := Vector3(0, size * 0.5 - 0.07, 0)
	props.box(centre, Vector3.ONE * size, tone, tilt)
	for stud: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		props.tube(centre + tilt * Vector3(stud.x * size * 0.24, size * 0.5 + 0.03, stud.y * size * 0.24), 0.08, 0.08, 0.06, tone.lightened(0.12), 8, tilt)
	# A painted letter panel on the face toward the path.
	props.box(centre + tilt * Vector3(0, 0, size * 0.5 + 0.006), Vector3(size * 0.66, size * 0.66, 0.012), pal[4], tilt)
	props.box(centre + tilt * Vector3(0, 0, size * 0.5 + 0.014), Vector3(size * 0.14, size * 0.46, 0.012), tone.darkened(0.2), tilt)
	props.box(centre + tilt * Vector3(0, -size * 0.16, size * 0.5 + 0.014), Vector3(size * 0.4, size * 0.13, 0.012), tone.darkened(0.2), tilt)
	return []

func _pinwheel(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.tube(Vector3(0, 0.55, 0), 0.026, 0.022, 1.1, Color("#f4efe2"), 6)
	props.tube(Vector3(0, 0.3, 0), 0.03, 0.03, 0.12, pal[0], 6)
	props.tube(Vector3(0, 0.72, 0), 0.03, 0.03, 0.12, pal[1], 6)
	var hub := Vector3(0, 1.12, 0.04)
	for blade in 4:
		var angle := TAU * float(blade) / 4.0 + h[0] * 1.5
		var tip := hub + Vector3(cos(angle), sin(angle), 0) * 0.28
		var side := hub + Vector3(cos(angle + 1.0), sin(angle + 1.0), 0) * 0.17 + Vector3(0, 0, 0.05)
		var tone: Color = pal[(blade + int(h[1] * 4.0)) % 4]
		props.sheet(hub, tip, side, tone)
		props.sheet(hub, side, hub + Vector3(cos(angle + 0.6), sin(angle + 0.6), 0) * 0.1, tone.darkened(0.25))
	props.ball(hub + Vector3(0, 0, 0.02), 0.045, pal[4])
	return []

func _windup_key(h: PackedFloat32Array, _pal: Array) -> Array[Vector3]:
	var brass := Color("#c99d45")
	var shade := Color("#8c6a2a")
	var lean := Basis(Vector3.FORWARD, (h[0] - 0.5) * 0.4) * Basis(Vector3.RIGHT, (h[1] - 0.5) * 0.3)
	props.tube(lean * Vector3(0, 0.2, 0), 0.05, 0.05, 0.52, brass, 8, lean)
	props.tube(lean * Vector3(0, 0.47, 0), 0.09, 0.09, 0.07, shade, 8, lean)
	props.tube(lean * Vector3(0, 0.55, 0), 0.05, 0.05, 0.12, brass, 8, lean)
	props.box(lean * Vector3(0, 0.74, 0), Vector3(0.16, 0.12, 0.07), brass, lean)
	var upright := lean * Basis(Vector3.RIGHT, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		var lobe := lean * Vector3(side * 0.21, 0.76, 0)
		_ring(props, lobe, 0.14, 0.045, brass, upright, 12, 5)
		props.tube(lobe, 0.1, 0.1, 0.03, shade, 10, upright)
	return []

func _cane_post(h: PackedFloat32Array, _pal: Array) -> Array[Vector3]:
	var red := Color("#d8404a")
	var white := Color("#f6f1ea")
	var lean := Basis(Vector3.FORWARD, (h[0] - 0.5) * 0.24)
	for band in 6:
		props.tube(lean * Vector3(0, 0.09 + float(band) * 0.18, 0), 0.06, 0.06, 0.18, red if band % 2 == 0 else white, 8, lean)
	for step in 5:
		var angle := PI * (float(step) + 0.5) / 5.0
		var at := Vector3(0.13 - 0.13 * cos(angle), 1.08 + 0.13 * sin(angle), 0)
		props.tube(lean * at, 0.058, 0.058, 0.1, red if step % 2 == 0 else white, 8, lean * _along(Vector3(sin(angle), cos(angle), 0)))
	props.ball(Vector3.ZERO, 0.17, Color("#f5c9d6"), Color("#f7f0e6"), 8, 3, 0.45, true)
	return []

func _sugar_rock(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.tube(Vector3(0, 0.07, 0), 0.38, 0.27, 0.2, Color("#e3d5ec"), 6)
	var count := 4 + int(h[0] * 3.0)
	for index in count:
		var angle := TAU * float(index) / float(count) + h[1] * 3.0
		var spread := fposmod(h[2] * 5.3 + float(index) * 0.61, 1.0)
		var axis := Vector3(cos(angle), 0, sin(angle)).cross(Vector3.UP).normalized()
		var tilt := Basis(axis, 0.18 + spread * 0.3)
		var height := 0.3 + fposmod(h[3] * 3.7 + float(index) * 0.43, 1.0) * 0.45
		var width := 0.07 + spread * 0.05
		var foot := Vector3(cos(angle), 0, sin(angle)) * 0.14 * (0.4 + spread) + Vector3(0, 0.1, 0)
		var tone: Color = pal[(index + 1) % pal.size()].lightened(0.25)
		props.tube(foot + tilt * Vector3(0, height * 0.4, 0), width, width * 0.92, height * 0.8, tone, 5, tilt)
		props.tube(foot + tilt * Vector3(0, height * 0.9, 0), width * 0.92, 0.0, height * 0.2, tone.lightened(0.3), 5, tilt)
	return []

func _gumballs(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var count := 3 + int(h[0] * 3.0)
	for index in count:
		var angle := TAU * float(index) / float(count) + h[1] * 2.0
		var radius := 0.09 + fposmod(h[2] * 4.1 + float(index) * 0.37, 1.0) * 0.11
		var at := Vector3(cos(angle), 0, sin(angle)) * (0.12 + fposmod(h[3] * 2.3 + float(index) * 0.53, 1.0) * 0.22)
		var tone: Color = pal[(index + int(h[1] * 5.0)) % 4]
		props.ball(at + Vector3(0, radius * 0.82, 0), radius, tone, Color.TRANSPARENT, 10, 5)
		props.ball(at + Vector3(-radius * 0.35, radius * 1.3, radius * 0.35), radius * 0.22, tone.lightened(0.55), Color.TRANSPARENT, 6, 3)
	return []

func _pipe(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var lying := Basis(Vector3.FORWARD, PI * 0.5)
	var pink: Color = pal[0].lightened(0.25)
	props.tube(Vector3(0, 0.15, 0), 0.16, 0.16, 1.3, pink, 10, lying)
	for x: float in [-0.3, 0.3]:
		props.tube(Vector3(x, 0.15, 0), 0.168, 0.168, 0.08, pal[4], 10, lying)
	for x: float in [-0.66, 0.66]:
		props.tube(Vector3(x, 0.15, 0), 0.22, 0.22, 0.07, pal[1], 10, lying)
		for bolt in 4:
			var angle := TAU * float(bolt) / 4.0 + 0.4
			props.ball(Vector3(x + signf(x) * 0.04, 0.15 + sin(angle) * 0.18, cos(angle) * 0.18), 0.025, Color("#8e8a96"), Color.TRANSPARENT, 4, 2)
	# A few gumballs that rolled out of it.
	for index in 2:
		var tone: Color = pal[(index + 2 + int(h[0] * 3.0)) % 4]
		props.ball(Vector3(0.86 + float(index) * 0.16, 0.08, 0.22 - float(index) * 0.3), 0.09, tone, Color.TRANSPARENT, 8, 4)
	return []

func _light_pole(_h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.box(Vector3(0, 0.1, 0), Vector3(0.24, 0.24, 0.24), DARK)
	props.tube(Vector3(0, 1.3, 0), 0.065, 0.05, 2.4, Color("#7a5236"), 6)
	for band in 3:
		props.tube(Vector3(0, 0.55 + float(band) * 0.5, 0), 0.07, 0.07, 0.16, pal[0] if band % 2 == 0 else pal[3], 6)
	props.box(Vector3(0, 2.42, 0), Vector3(0.56, 0.05, 0.05), WOOD)
	props.ball(Vector3(0, 2.6, 0), 0.08, pal[1], Color.TRANSPARENT, 8, 4)
	for side: float in [-1.0, 1.0]:
		glow.ball(Vector3(side * 0.25, 2.34, 0), 0.06, WARM, Color.TRANSPARENT, 6, 3)
	return [Vector3(0, 2.45, 0)]

func _pennant_stake(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.tube(Vector3(0, 0.72, 0), 0.03, 0.024, 1.44, Color("#6b4a32"), 5)
	props.ball(Vector3(0, 1.46, 0), 0.05, pal[1], Color.TRANSPARENT, 6, 3)
	var first: Color = pal[int(h[0] * 3.0) % 3]
	props.sheet(Vector3(0, 1.4, 0), Vector3(0.48, 1.29 - h[1] * 0.06, 0.03), Vector3(0, 1.14, 0), first)
	props.sheet(Vector3(0, 1.1, 0), Vector3(0.34, 1.02, 0.02), Vector3(0, 0.92, 0), pal[(int(h[0] * 3.0) + 1) % 3])
	return []

func _ticket_sign(_h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	for side: float in [-1.0, 1.0]:
		props.box(Vector3(side * 0.34, 0.5, -0.04), Vector3(0.07, 1.0, 0.07), WOOD)
	var centre := Vector3(0, 0.92, 0)
	_ticket(centre, Vector2(0.52, 0.26), 0.05, pal[3], true)
	_ticket(centre + Vector3(0, 0, 0.029), Vector2(0.45, 0.2), 0.0, pal[0], false)
	_ticket(centre + Vector3(0, 0, 0.033), Vector2(0.39, 0.15), 0.0, pal[3], false)
	_star(centre + Vector3(0, 0, 0.037), 0.1, pal[1])
	props.box(Vector3(0, 1.22, -0.02), Vector3(1.1, 0.045, 0.1), WOOD)
	return []

## A ticket-stub outline (semicircle notches on its short ends), solid or a front face only.
func _ticket(centre: Vector3, half: Vector2, depth: float, color: Color, solid: bool) -> void:
	var notch := half.y * 0.38
	var outline: Array[Vector2] = [Vector2(-half.x, half.y), Vector2(half.x, half.y)]
	for step in 7:
		var angle := PI * 0.5 + PI * float(step) / 6.0
		outline.append(Vector2(half.x, 0) + Vector2(cos(angle), sin(angle)) * notch)
	outline.append_array([Vector2(half.x, -half.y), Vector2(-half.x, -half.y)])
	for step in 7:
		var angle := -PI * 0.5 + PI * float(step) / 6.0
		outline.append(Vector2(-half.x, 0) + Vector2(cos(angle), sin(angle)) * notch)
	var front := Vector3(0, 0, depth * 0.5)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		_face(props, centre + front, centre + front + Vector3(a.x, a.y, 0), centre + front + Vector3(b.x, b.y, 0), Vector3.BACK, color)
		if not solid: continue
		_face(props, centre - front, centre - front + Vector3(a.x, a.y, 0), centre - front + Vector3(b.x, b.y, 0), Vector3.FORWARD, color)
		var edge_out := Vector3((b - a).orthogonal().x, (b - a).orthogonal().y, 0)
		if edge_out.dot(Vector3((a + b).x, (a + b).y, 0)) < 0.0: edge_out = -edge_out
		var corners := [centre + front + Vector3(a.x, a.y, 0), centre + front + Vector3(b.x, b.y, 0), centre - front + Vector3(b.x, b.y, 0), centre - front + Vector3(a.x, a.y, 0)]
		_face(props, corners[0], corners[1], corners[2], edge_out, color.darkened(0.15))
		_face(props, corners[0], corners[2], corners[3], edge_out, color.darkened(0.15))

func _star(centre: Vector3, radius: float, color: Color, toward := Vector3.BACK) -> void:
	for point in 10:
		var a := PI * 0.5 + TAU * float(point) / 10.0
		var b := PI * 0.5 + TAU * float(point + 1) / 10.0
		var ra := radius if point % 2 == 0 else radius * 0.45
		var rb := radius if point % 2 == 1 else radius * 0.45
		_face(props, centre, centre + Vector3(cos(a) * ra, sin(a) * ra, 0), centre + Vector3(cos(b) * rb, sin(b) * rb, 0), toward, color)

func _wagon(_h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var body: Color = pal[0]
	var gold: Color = pal[1]
	var cream: Color = pal[3]
	props.box(Vector3(0, 0.52, 0), Vector3(2.1, 0.1, 1.0), DARK)
	props.box(Vector3(0, 1.05, 0), Vector3(1.9, 0.95, 0.95), body)
	props.box(Vector3(0, 0.6, 0), Vector3(1.96, 0.08, 1.0), gold)
	props.box(Vector3(0, 1.52, 0), Vector3(1.98, 0.07, 1.02), gold)
	for side: float in [-1.0, 1.0]:
		var face := side * 0.48
		props.box(Vector3(-0.38, 1.08, face), Vector3(0.66, 0.5, 0.02), gold)
		props.box(Vector3(-0.38, 1.08, face + side * 0.006), Vector3(0.54, 0.38, 0.02), Color("#2c3550"))
		props.box(Vector3(0.48, 1.08, face), Vector3(0.66, 0.5, 0.02), cream)
		_star(Vector3(0.48, 1.08, face + side * 0.014), 0.17, gold, Vector3(0, 0, side))
	# Striped barrel roof overhanging the body.
	for strip in 7:
		var angle := lerpf(-0.95, 0.95, float(strip) / 6.0)
		var at := Vector3(0, 1.56 + (cos(angle) - cos(0.95)) * 0.6, sin(angle) * 0.6)
		props.box(at, Vector3(2.12, 0.05, 0.19), body if strip % 2 == 0 else cream, Basis(Vector3.RIGHT, angle))
	for corner: Vector2 in [Vector2(-0.68, -1), Vector2(-0.68, 1), Vector2(0.68, -1), Vector2(0.68, 1)]:
		var hub := Vector3(corner.x, 0.33, corner.y * 0.55)
		var axle := Basis(Vector3.RIGHT, PI * 0.5)
		_ring(props, hub, 0.29, 0.04, gold, axle, 14, 4)
		props.tube(hub, 0.07, 0.07, 0.1, DARK, 8, axle)
		for spoke in 4:
			props.box(hub, Vector3(0.54, 0.035, 0.03), WOOD, Basis(Vector3.BACK, float(spoke) * PI * 0.25))
	for side: float in [-1.0, 1.0]:
		_rod(props, Vector3(1.0, 0.5, side * 0.3), Vector3(1.85, 0.06, side * 0.24), 0.035, WOOD, 5)
	props.box(Vector3(-1.12, 0.32, 0), Vector3(0.22, 0.06, 0.5), WOOD)
	return []

func _lantern_post(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.ball(Vector3.ZERO, 0.16, Color("#4a4f5c"), Color("#5b6070"), 6, 2, 0.5, true)
	props.tube(Vector3(0, 0.95, 0), 0.045, 0.04, 1.9, Color("#8a7a4a"), 6)
	for joint in 3:
		props.tube(Vector3(0, 0.5 + float(joint) * 0.5, 0), 0.05, 0.05, 0.03, Color("#6b5e38"), 6)
	props.box(Vector3(0.17, 1.86, 0), Vector3(0.4, 0.035, 0.035), DARK)
	_lantern(Vector3(0.34, 1.52, 0), pal[int(h[0] * 3.0) % 3])
	return [Vector3(0.34, 1.6, 0)]

func _puddle(h: PackedFloat32Array, _pal: Array) -> Array[Vector3]:
	var rim: Array[Vector3] = []
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var reach := 0.42 + fposmod(h[0] * 5.1 + float(index) * 0.77, 1.0) * 0.3
		rim.append(Vector3(cos(angle) * reach * 1.35, 0, sin(angle) * reach))
	for index in rim.size():
		var next := rim[(index + 1) % rim.size()]
		# Dark mud ring, then the water a hair above it.
		_face(props, Vector3(0, 0.004, 0), rim[index] * 1.14 + Vector3(0, 0.004, 0), next * 1.14 + Vector3(0, 0.004, 0), Vector3.UP, Color("#3b3d38"))
		_face(props, Vector3(0, 0.009, 0), rim[index] + Vector3(0, 0.009, 0), next + Vector3(0, 0.009, 0), Vector3.UP, Color("#5a6f8c"))
	return []

func _slate_patch(h: PackedFloat32Array, _pal: Array) -> Array[Vector3]:
	var count := 3 + int(h[0] * 4.0)
	for index in count:
		var at := Vector3((fposmod(h[1] * 3.1 + float(index) * 0.47, 1.0) - 0.5) * 1.1, 0, (fposmod(h[2] * 2.7 + float(index) * 0.71, 1.0) - 0.5) * 1.0)
		var size := 0.36 + fposmod(h[3] * 1.9 + float(index) * 0.29, 1.0) * 0.14
		var tone: Color = row.tiles[index % row.tiles.size()]
		props.box(at + Vector3(0, -0.006 - float(index % 2) * 0.006, 0), Vector3(size, 0.05, size * 0.9), tone, Basis(Vector3.UP, (h[1] - 0.5) * 0.5 + float(index) * 0.2))
	_tuft(props, Vector3(0.1, 0, 0.05), h[2])
	return []

func _vending_cart(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var teal: Color = pal[3]
	props.box(Vector3(0.05, 0.7, 0), Vector3(1.3, 0.5, 0.75), teal)
	props.box(Vector3(0.05, 0.97, 0), Vector3(1.42, 0.05, 0.86), WOOD)
	props.box(Vector3(0.05, 0.7, 0.383), Vector3(1.16, 0.1, 0.012), pal[4])
	for side: float in [-1.0, 1.0]:
		var hub := Vector3(-0.42, 0.25, side * 0.43)
		_ring(props, hub, 0.22, 0.035, DARK, Basis(Vector3.RIGHT, PI * 0.5), 12, 4)
		props.tube(hub, 0.05, 0.05, 0.08, DARK, 6, Basis(Vector3.RIGHT, PI * 0.5))
		props.box(Vector3(0.6, 0.23, side * 0.3), Vector3(0.05, 0.46, 0.05), WOOD)
		_rod(props, Vector3(0.68, 0.86, side * 0.3), Vector3(1.05, 0.78, side * 0.3), 0.025, WOOD, 4)
	for x: float in [-0.6, 0.68]:
		props.box(Vector3(x, 1.46, -0.38), Vector3(0.04, 1.0, 0.04), WOOD)
		props.box(Vector3(x, 1.35, 0.5), Vector3(0.04, 0.78, 0.04), WOOD)
	# Striped awning sloping toward the front.
	for stripe in 6:
		var x0 := -0.72 + float(stripe) * 0.25
		var x1 := x0 + 0.25
		var tone: Color = pal[0] if stripe % 2 == 0 else pal[4]
		var back := [Vector3(x0, 1.96, -0.42), Vector3(x1, 1.96, -0.42)]
		var front := [Vector3(x0, 1.74, 0.56), Vector3(x1, 1.74, 0.56)]
		props.sheet(back[0], back[1], front[1], tone)
		props.sheet(back[0], front[1], front[0], tone)
		props.sheet(front[0], front[1], Vector3((x0 + x1) * 0.5, 1.62, 0.58), tone)
	for good in 3:
		props.box(Vector3(-0.35 + float(good) * 0.32, 1.05, -0.1), Vector3(0.16, 0.12 + float(good % 2) * 0.06, 0.16), [pal[4], pal[1], pal[2]][good])
	_lantern(Vector3(0.5, 1.4, 0.48), pal[int(h[0] * 2.0) % 2])
	return [Vector3(0.5, 1.45, 0.48)]

func _pots(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var count := 2 + int(h[0] * 2.0)
	for index in count:
		var size := 0.8 + fposmod(h[1] * 3.3 + float(index) * 0.41, 1.0) * 0.4
		var at := Vector3(cos(float(index) * 2.3 + h[2] * 6.0), 0, sin(float(index) * 2.3 + h[2] * 6.0)) * 0.24 * float(mini(index, 1) + index) * 0.6
		if index == count - 1 and h[3] > 0.55:
			# One pot has tipped over and spilled its soil.
			var side := Basis(Vector3.BACK, PI * 0.47)
			props.tube(at + Vector3(0, 0.17 * size, 0), 0.13 * size, 0.17 * size, 0.3 * size, pal[0], 10, side)
			props.ball(at + Vector3(-0.3 * size, 0.0, 0), 0.2 * size, Color("#4a3426"), Color("#5a4230"), 8, 3, 0.3, true)
			props.ball(at + Vector3(-0.42 * size, 0.08, 0.05), 0.12 * size, pal[1], Color.TRANSPARENT, 8, 3)
			continue
		props.tube(at + Vector3(0, 0.15 * size, 0), 0.13 * size, 0.17 * size, 0.3 * size, pal[0], 10)
		props.tube(at + Vector3(0, 0.31 * size, 0), 0.195 * size, 0.195 * size, 0.05 * size, pal[0].lightened(0.15), 10)
		props.ball(at + Vector3(0, 0.42 * size, 0), 0.19 * size, pal[1], pal[1].lightened(0.15), 8, 4, 0.9)
		props.ball(at + Vector3(0.08, 0.58 * size, 0.06), 0.05, pal[2], Color.TRANSPARENT, 6, 3)
	return []

func _trellis(_h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var timber := Color("#8a6a48")
	props.box(Vector3(0, 0.1, 0), Vector3(1.4, 0.2, 0.32), Color("#6e5a44"))
	props.box(Vector3(0, 0.205, 0), Vector3(1.3, 0.02, 0.24), Color("#4a3426"))
	for side: float in [-1.0, 1.0]:
		props.box(Vector3(side * 0.62, 0.85, 0), Vector3(0.07, 1.5, 0.07), timber)
		props.tube(Vector3(side * 0.62, 1.65, 0), 0.06, 0.0, 0.12, timber.darkened(0.2), 4)
	props.box(Vector3(0, 1.52, 0), Vector3(1.34, 0.06, 0.05), timber)
	for slat in 5:
		props.box(Vector3(-0.4 + float(slat) * 0.2, 0.86, 0), Vector3(0.03, 1.26, 0.025), timber)
	for slat in 4:
		props.box(Vector3(0, 0.45 + float(slat) * 0.3, 0.015), Vector3(1.2, 0.03, 0.025), timber)
	for leaf in 10:
		var at := Vector3(sin(float(leaf) * 1.3) * 0.42, 0.3 + float(leaf) * 0.12, 0.05)
		props.ball(at, 0.09 + fposmod(float(leaf) * 0.37, 1.0) * 0.05, pal[1] if leaf % 3 != 0 else pal[1].lightened(0.15), Color.TRANSPARENT, 6, 3)
		if leaf % 3 == 1: props.ball(at + Vector3(0.06, 0.05, 0.06), 0.04, pal[2], Color.TRANSPARENT, 5, 2)
	return []

func _moss_stone(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var count := 1 + int(h[0] * 2.5)
	for index in count:
		var size := 0.7 + fposmod(h[1] * 2.9 + float(index) * 0.53, 1.0) * 0.5
		var at := Vector3(cos(float(index) * 2.4 + h[2] * 6.0), 0, sin(float(index) * 2.4 + h[2] * 6.0)) * 0.32 * float(index)
		var turn := Basis(Vector3.UP, h[3] * 3.0 + float(index))
		props.tube(at + Vector3(0, 0.12 * size, 0), 0.3 * size, 0.23 * size, 0.32 * size, Color("#8a8d86"), 6, turn)
		props.tube(at + Vector3(0.03, 0.33 * size, -0.02), 0.22 * size, 0.1 * size, 0.12 * size, Color("#9a9c94"), 5, turn)
		props.ball(at + Vector3(0.02, 0.28 * size, 0.0), 0.25 * size, pal[1], pal[1].darkened(0.15), 7, 3, 0.4, true)
	return []

func _watering_can(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var tone: Color = pal[4] if h[0] > 0.4 else Color("#b8763f")
	props.tube(Vector3(0, 0.15, 0), 0.14, 0.13, 0.3, tone, 10)
	props.tube(Vector3(0, 0.32, 0), 0.13, 0.07, 0.04, tone.lightened(0.1), 10)
	_rod(props, Vector3(0.1, 0.12, 0), Vector3(0.38, 0.33, 0), 0.025, tone, 5)
	props.ball(Vector3(0.4, 0.35, 0), 0.045, tone.darkened(0.15), Color.TRANSPARENT, 6, 3)
	_rod(props, Vector3(-0.12, 0.28, 0), Vector3(-0.06, 0.42, 0), 0.018, tone.darkened(0.1), 4)
	_rod(props, Vector3(-0.06, 0.42, 0), Vector3(0.06, 0.42, 0), 0.018, tone.darkened(0.1), 4)
	_rod(props, Vector3(0.06, 0.42, 0), Vector3(0.09, 0.32, 0), 0.018, tone.darkened(0.1), 4)
	return []

func _crates(h: PackedFloat32Array, _pal: Array) -> Array[Vector3]:
	var plank := Color("#9c7650")
	var count := 2 + int(h[0] * 1.8)
	for index in count:
		var size := 0.52 + fposmod(h[1] * 3.1 + float(index) * 0.45, 1.0) * 0.16
		var at := Vector3((float(index) - float(count - 1) * 0.5) * 0.68, 0, (fposmod(h[2] * 2.3 + float(index) * 0.7, 1.0) - 0.5) * 0.3)
		var turn := Basis(Vector3.UP, (fposmod(h[3] * 4.1 + float(index) * 0.3, 1.0) - 0.5) * 0.5)
		_crate(at + Vector3(0, size * 0.5, 0), size, plank.darkened(float(index % 2) * 0.08), turn)
		if index == 0 and h[1] > 0.35:
			_crate(at + Vector3(0.04, size + size * 0.4, 0.02), size * 0.8, plank.lightened(0.06), turn * Basis(Vector3.UP, 0.35))
	return []

func _crate(centre: Vector3, size: float, tone: Color, turn: Basis) -> void:
	props.box(centre, Vector3.ONE * size, tone, turn)
	var trim := tone.darkened(0.3)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		props.box(centre + turn * Vector3(corner.x * size * 0.47, 0, corner.y * size * 0.47), Vector3(0.07, size + 0.01, 0.07), trim, turn)
	props.box(centre, Vector3(size + 0.02, 0.07, size + 0.02), trim, turn)
	props.box(centre + turn * Vector3(0, 0, size * 0.505), Vector3(size * 0.9, 0.06, 0.012), trim, turn * Basis(Vector3.BACK, 0.75))

func _rope_coil(_h: PackedFloat32Array, _pal: Array) -> Array[Vector3]:
	var rope := Color("#c2a46e")
	for turn in 3:
		_ring(props, Vector3(0, 0.05 + float(turn) * 0.075, 0), 0.27 - float(turn) * 0.025, 0.045, rope.darkened(float(turn % 2) * 0.1), Basis.IDENTITY, 14, 5)
	_rod(props, Vector3(0.27, 0.05, 0), Vector3(0.62, 0.04, 0.22), 0.04, rope, 5)
	return []

func _net_poles(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	for side: float in [-1.0, 1.0]:
		props.ball(Vector3(side, 0, 0), 0.16, Color("#7d7f78"), Color.TRANSPARENT, 6, 2, 0.5, true)
		props.tube(Vector3(side, 0.85, 0), 0.05, 0.04, 1.7, WOOD, 6)
		props.ball(Vector3(side, 1.72, 0), 0.06, DARK, Color.TRANSPARENT, 6, 3)
	var cord: Color = pal[4]
	var columns := 9
	var rows := 6
	var grid: Array[Vector3] = []
	for r in rows:
		for c in columns:
			var x := lerpf(-0.94, 0.94, float(c) / float(columns - 1))
			var droop := 1.0 - pow(x / 0.94, 2.0)
			var top := 1.62 - 0.16 * droop
			var bottom := top - 0.95 - 0.18 * droop
			var y := lerpf(top, bottom, float(r) / float(rows - 1))
			grid.append(Vector3(x, y, sin(float(c) * 1.1 + h[0] * 4.0) * 0.04 * float(r) / float(rows - 1)))
	for r in rows:
		for c in columns:
			var here := grid[r * columns + c]
			if c + 1 < columns: _rod(props, here, grid[r * columns + c + 1], 0.017, cord, 3)
			if r + 1 < rows: _rod(props, here, grid[(r + 1) * columns + c], 0.017, cord, 3)
	for c in range(1, columns - 1, 2):
		props.ball(grid[c], 0.05, pal[3], Color.TRANSPARENT, 6, 3)
	return []

func _dinghy(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	# Hauled up and turned keel-up to dry.
	const STATIONS := 9
	var sections: Array = []
	for index in STATIONS:
		var t := lerpf(-1.0, 1.0, float(index) / float(STATIONS - 1))
		var width := 0.6 * (1.0 - pow(maxf(t, 0.0), 2.0)) * (1.0 - 0.22 * pow(maxf(-t, 0.0), 2.0))
		var depth := 0.5 * (1.0 - 0.28 * t * t)
		var x := t * 1.15
		sections.append([Vector3(x, 0.04, -width), Vector3(x, depth * 0.58, -width * 0.84), Vector3(x, depth, 0), Vector3(x, depth * 0.58, width * 0.84), Vector3(x, 0.04, width)])
	var hull_tones: Array[Color] = [pal[0], pal[2], pal[2], pal[0]]
	for index in STATIONS - 1:
		for panel in 4:
			var a: Vector3 = sections[index][panel]
			var b: Vector3 = sections[index][panel + 1]
			var c: Vector3 = sections[index + 1][panel + 1]
			var d: Vector3 = sections[index + 1][panel]
			var middle := (a + b + c + d) * 0.25
			var outward := middle - Vector3(middle.x, 0.1, 0)
			_face(props, a, b, c, outward, hull_tones[panel])
			_face(props, a, c, d, outward, hull_tones[panel])
	var stern: Array = sections[0]
	for panel in 4:
		_face(props, Vector3(-1.15, 0.2, 0), stern[panel], stern[panel + 1], Vector3.LEFT, WOOD)
	for index in STATIONS - 1:
		_rod(props, sections[index][2], sections[index + 1][2], 0.035, WOOD.darkened(0.2), 4)
		for side: int in [0, 4]:
			_rod(props, sections[index][side] + Vector3(0, 0.04, 0), sections[index + 1][side] + Vector3(0, 0.04, 0), 0.03, pal[1], 4)
	_rod(props, Vector3(-0.6, 0.04, 0.85 + h[0] * 0.1), Vector3(0.7, 0.04, 0.95), 0.03, WOOD, 5)
	props.box(Vector3(0.85, 0.04, 0.97), Vector3(0.36, 0.02, 0.13), WOOD, Basis(Vector3.UP, -0.08))
	return []

static func _hash(x: int, z: int, salt: int) -> float:
	return fposmod(sin(float(x) * 127.1 + float(z) * 311.7 + float(salt) * 74.7) * 43758.5453, 1.0)

## One to three suitcases, the top one usually tipped, with straps and a handle.
func _luggage(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var count := 1 + int(h[0] * 2.6)
	var y := 0.0
	for index in count:
		var size := Vector3(0.72 - 0.12 * float(index), 0.24 + 0.05 * fposmod(h[1] * 3.0 + float(index), 1.0), 0.46 - 0.06 * float(index))
		var turn := Basis(Vector3.UP, (fposmod(h[2] * 5.1 + float(index) * 0.7, 1.0) - 0.5) * 0.7)
		if index == count - 1 and count > 1: turn = turn * Basis(Vector3.BACK, (h[3] - 0.5) * 0.3)
		var tone: Color = pal[(index + int(h[1] * 3.0)) % 3]
		var centre := Vector3(0, y + size.y * 0.5, 0)
		props.box(centre, size, tone, turn)
		props.box(centre, size + Vector3(0.02, -0.1, 0.02), tone.darkened(0.18), turn)
		for strap: float in [-0.26, 0.26]:
			props.box(centre + turn * Vector3(strap * size.x, 0, 0), Vector3(0.05, size.y + 0.02, size.z + 0.02), Color("#5a3e2a"), turn)
		props.box(centre + turn * Vector3(0, size.y * 0.5 + 0.04, 0), Vector3(0.2, 0.05, 0.05), pal[4], turn)
		y += size.y
	return []

## A brass bucket of furled umbrellas with crook handles.
func _umbrella_stand(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var brass: Color = pal[4]
	props.tube(Vector3(0, 0.22, 0), 0.16, 0.19, 0.44, brass.darkened(0.15), 10)
	props.tube(Vector3(0, 0.45, 0), 0.2, 0.2, 0.04, brass, 10)
	for index in 2 + int(h[0] * 1.9):
		var lean := Basis(Vector3.BACK, (float(index) - 1.0) * 0.16 + (h[1] - 0.5) * 0.1) * Basis(Vector3.RIGHT, (h[2] - 0.5) * 0.2)
		var tone: Color = pal[(index + int(h[3] * 3.0)) % 3]
		var base := Vector3((float(index) - 1.0) * 0.07, 0.3, 0)
		props.tube(base + lean * Vector3(0, 0.38, 0), 0.07, 0.02, 0.62, tone, 6, lean)
		props.tube(base + lean * Vector3(0, 0.82, 0), 0.012, 0.012, 0.3, DARK, 4, lean)
		var crook := base + lean * Vector3(0, 0.98, 0)
		props.box(crook + lean * Vector3(0.05, 0.02, 0), Vector3(0.12, 0.03, 0.03), WOOD, lean)
		props.box(crook + lean * Vector3(0.1, -0.04, 0), Vector3(0.03, 0.1, 0.03), WOOD, lean)
	return []

## A big folded paper crane resting on a stone.
func _paper_crane(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.ball(Vector3(0, 0.05, 0), 0.24, Color("#8d8a92"), Color("#9c99a2"), 7, 2, 0.45, true)
	var paper: Color = pal[3] if h[0] > 0.35 else pal[1].lightened(0.35)
	var fold := paper.darkened(0.16)
	var c := Vector3(0, 0.2, 0)
	# Body diamond, two raised wings, a neck and a tail.
	props.sheet(c + Vector3(-0.16, 0.0, 0), c + Vector3(0.16, 0.0, 0), c + Vector3(0, 0.12, 0.05), paper)
	props.sheet(c + Vector3(-0.16, 0.0, 0), c + Vector3(0.16, 0.0, 0), c + Vector3(0, 0.1, -0.06), fold)
	props.sheet(c + Vector3(-0.05, 0.08, 0), c + Vector3(0.06, 0.08, 0), c + Vector3(-0.14, 0.38, -0.2), paper)
	props.sheet(c + Vector3(-0.05, 0.08, 0), c + Vector3(0.06, 0.08, 0), c + Vector3(0.12, 0.36, 0.2), fold)
	props.sheet(c + Vector3(0.12, 0.0, 0), c + Vector3(0.16, 0.03, 0), c + Vector3(0.3, 0.3, 0.02), paper)
	props.sheet(c + Vector3(0.3, 0.3, 0.02), c + Vector3(0.27, 0.29, 0), c + Vector3(0.36, 0.24, 0.02), fold)
	props.sheet(c + Vector3(-0.12, 0.0, 0), c + Vector3(-0.16, 0.03, 0), c + Vector3(-0.32, 0.26, 0.0), fold)
	return []

## A short post with a lit oval room-number plaque on top.
func _number_post(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.box(Vector3(0, 0.06, 0), Vector3(0.3, 0.12, 0.3), Color("#6e6478"))
	props.tube(Vector3(0, 0.62, 0), 0.05, 0.045, 1.0, WOOD, 6)
	props.box(Vector3(0, 1.16, 0), Vector3(0.5, 0.06, 0.08), pal[4])
	var plaque := Vector3(0, 1.36, 0.02)
	props.tube(plaque, 0.23, 0.23, 0.05, pal[0], 12, Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.72)))
	glow.tube(plaque + Vector3(0, 0, 0.03), 0.17, 0.17, 0.02, Color("#ffe7b0"), 12, Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.72)))
	# Three painted digits.
	for digit in 3:
		props.box(plaque + Vector3((float(digit) - 1.0) * 0.08, 0, 0.05), Vector3(0.035, 0.1 + 0.02 * float(int(h[0] * 7.0 + digit) % 2), 0.01), pal[0].darkened(0.3))
	return [plaque + Vector3(0, 0, 0.1)]

## A little cloud resting on the grass, as if it drifted down from the park.
func _cloud_puff(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var white: Color = pal[4]
	var shade := Color("#d5e3f6")
	for lobe in 3 + int(h[0] * 2.5):
		var t := float(lobe) - 1.0
		var spot := Vector3(t * 0.26 + (h[1] - 0.5) * 0.1, 0.16 + (0.1 if lobe == 1 else 0.0) + h[2] * 0.06, (h[3] - 0.5) * 0.2 * t)
		props.ball(spot, 0.22 + 0.06 * fposmod(h[0] * 3.0 + float(lobe), 1.0), white, Color.TRANSPARENT, 8, 3, 0.8)
		props.ball(spot - Vector3(0, 0.08, 0), 0.21, shade, Color.TRANSPARENT, 8, 2, 0.35)
	return []

## A striped windsock on a pole, its tail pointing the way the island's wind blows.
func _windsock(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.tube(Vector3(0, 0.75, 0), 0.03, 0.025, 1.5, Color("#f4efe2"), 6)
	props.tube(Vector3(0, 0.06, 0), 0.1, 0.12, 0.12, pal[1], 6)
	# Undo the prop's own turn so every sock agrees on the wind.
	var undo := props.frame.basis.orthonormalized().inverse()
	var down := undo * Vector3(0.86, 0, 0.51)
	var along := Basis(Vector3.UP, -atan2(down.z, down.x)) * Basis(Vector3.BACK, -0.25 - h[0] * 0.2)
	for ring in 4:
		var t := float(ring) / 4.0
		var radius := lerpf(0.12, 0.06, t)
		props.tube(Vector3(0, 1.44, 0) + along * Vector3(0.1 + t * 0.6 + 0.075, 0, 0), radius, radius * 0.88, 0.16, pal[0] if ring % 2 == 0 else pal[4], 8, along * Basis(Vector3.BACK, PI * 0.5))
	return []

## A small diamond kite flying from a stake on a taut string, downwind.
func _kite_stake(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.tube(Vector3(0, 0.15, 0), 0.03, 0.02, 0.3, WOOD, 5)
	var undo := props.frame.basis.orthonormalized().inverse()
	var down := undo * Vector3(0.86, 0, 0.51)
	var kite := Vector3(down.x * 1.1, 1.9 + h[0] * 0.5, down.z * 1.1)
	var span := kite - Vector3(0, 0.3, 0)
	props.box((kite + Vector3(0, 0.3, 0)) * 0.5, Vector3(0.015, 0.015, span.length()), Color("#f2f2f2"), Basis.looking_at(span.normalized(), Vector3.UP))
	var tone: Color = pal[int(h[1] * 4.0) % 4]
	var top := kite + Vector3(0, 0.3, 0)
	var bottom := kite + Vector3(0, -0.42, 0)
	props.sheet(top, kite + Vector3(0.26, 0, 0), bottom, tone)
	props.sheet(top, bottom, kite + Vector3(-0.26, 0, 0), tone.lightened(0.25))
	for bow in 3:
		var at := bottom + Vector3(0.06 * sin(float(bow) * 1.6), -0.18 * float(bow + 1), 0)
		props.sheet(at, at + Vector3(0.08, 0.04, 0), at + Vector3(0.08, -0.04, 0), pal[(bow + 1) % 4])
	return []

## Film cans spilled from the lot: a stack lying flat and one rolled onto its edge.
func _film_can(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	var tin := Color("#9aa1ab")
	for can in 1 + int(h[0] * 2.5):
		props.tube(Vector3(0.04 * float(can), 0.05 + float(can) * 0.1, 0.03 * float(can)), 0.3, 0.3, 0.09, tin.darkened(0.06 * float(can)), 12)
		props.tube(Vector3(0.04 * float(can), 0.1 + float(can) * 0.1, 0.03 * float(can)), 0.08, 0.08, 0.02, pal[1], 8)
	var edge := Vector3(0.5, 0.26, 0.1 + h[1] * 0.2)
	props.tube(edge, 0.25, 0.25, 0.08, tin, 12, Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, h[2]))
	# A curl of film spilling out of the open can.
	for frame in 4:
		props.box(edge + Vector3(-0.1 - float(frame) * 0.14, -0.22 + 0.04 * float(frame % 2), 0.12), Vector3(0.13, 0.015, 0.1), pal[2], Basis(Vector3.UP, 0.3 * float(frame)))
	return []

## A little clapperboard on a stake: slate, striped stick and a chalked take.
func _clapper_post(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	props.tube(Vector3(0, 0.45, 0), 0.03, 0.025, 0.9, WOOD, 5)
	props.box(Vector3(0, 0.95, 0.03), Vector3(0.5, 0.36, 0.04), pal[2])
	for line in 2:
		props.box(Vector3(0, 0.98 - float(line) * 0.12, 0.055), Vector3(0.42, 0.015, 0.01), pal[3])
	var open := 0.15 + h[0] * 0.35
	for stripe in 4:
		var tone: Color = pal[3] if stripe % 2 == 0 else pal[2]
		props.box(Vector3(-0.19 + float(stripe) * 0.125, 1.16 + open * (float(stripe) * 0.12), 0.03), Vector3(0.125, 0.07, 0.045), tone, Basis(Vector3.BACK, open))
	return []

## A floor spotlight on a short tripod, its lens glowing after dark.
func _spot_lamp(h: PackedFloat32Array, pal: Array) -> Array[Vector3]:
	for leg in 3:
		var angle := TAU * float(leg) / 3.0
		_rod(props, Vector3(cos(angle) * 0.3, 0, sin(angle) * 0.3), Vector3(0, 0.55, 0), 0.02, DARK, 4)
	var aim := Basis(Vector3.RIGHT, PI * 0.5 - 0.5 - h[0] * 0.3)
	props.tube(Vector3(0, 0.68, 0), 0.17, 0.2, 0.34, Color("#2e2a33"), 10, aim)
	props.tube(Vector3(0, 0.68, 0) + aim * Vector3(0, 0.18, 0), 0.15, 0.15, 0.02, pal[1], 10, aim)
	glow.ball(Vector3(0, 0.68, 0) + aim * Vector3(0, 0.19, 0), 0.12, WARM, Color.TRANSPARENT, 8, 3, 0.4)
	return []

## Smooth 1D value noise in 0..1.
static func _smooth(t: float) -> float:
	var cell := floorf(t)
	var blend := t - cell
	blend = blend * blend * (3.0 - 2.0 * blend)
	return lerpf(_hash(int(cell), 3, 11), _hash(int(cell) + 1, 3, 11), blend)
