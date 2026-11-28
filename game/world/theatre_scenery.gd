extends RefCounted
## Everything in the underground theatre that never moves on its own.
## Above: the rocky islet, its paved plaza, the ticket booth, the grand stair
## sunk between poster walls, the marquee arch in the rock and the bridge to
## the island's gate. Below: the cavern, the floors (worn backstage boards, the
## black stage, the curtain-call dais, the sunken pit, the carpeted stalls and
## tiers) and the slopes between them, the stage's back cloth, valance and
## footlights, the set built from the ten regions' signature objects (painted
## flats of the lighthouse, the circus tent, the ferris wheel and the welcome
## arch, with the island's own prop builders standing in for the rest), the
## pit's rail, the seats with one lit seat kept for a late guest, the corridor's
## wall, mirror and crates, the photo frame on the dais, the signs and the
## covered stand sites. Built once through two scenery kits, one per level;
## the curtains, the spotlight, the costumes, the band and the petals are theatre_life.

const Kit := preload("res://game/world/scenery_kit.gd")
const DistrictBand := preload("res://game/world/district_band.gd")
const DistrictSites := preload("res://game/world/district_sites.gd")
const PAINTED := preload("res://game/world/painted_finish.gdshader")
## Floors are drawn a little wider than they can be walked.
const LIP := 0.22
const CREAM := Color("#fff0d6")
const GOLD := Color("#e3b450")
const BRASS := Color("#c79a45")
const VELVET := Color("#9e1f35")
const VELVET_DARK := Color("#5e1222")
const PLUM := Color("#3a2245")
const NIGHT := Color("#1f1828")
const INK := Color("#2e2436")
const WOOD := Color("#9a6a44")
const DARK_WOOD := Color("#5e3f2a")
const ROCK := Color("#6f6474")
const ROCK_DARK := Color("#4c4352")
const MOSS := Color("#5f7a4e")
const WARM := Color("#ffd68b")
## Glow of the theatre's own bulbs: they burn whatever the hour above.
const BELOW_GLOW := 2.4
## Lamp heights and reach on the theatre's level: position, reach, colour,
## level, and whether it is a house light that dims with the house.
const LAMPS := [
	[Vector3(-9.3, 1.6, -2.4), 8.5, Color("#ffcf8a"), 2.0, false],
	[Vector3(-9.3, 4.4, -8.4), 9.0, Color("#ffb8c8"), 1.8, false],
	[Vector3(2.8, 4.2, -5.8), 7.5, Color("#ffc4b0"), 1.9, false],
	[Vector3(-24.8, 3.0, -2.0), 9.0, Color("#ffe2b8"), 1.7, false],
	[Vector3(-24.8, 3.0, 10.0), 9.0, Color("#ffe2b8"), 1.7, false],
	[Vector3(-9.6, 0.6, 1.6), 6.0, Color("#ffc070"), 1.4, false],
	[Vector3(-21.4, 2.4, 11.4), 8.0, Color("#ffd2a0"), 1.6, true],
	[Vector3(0.2, 2.4, 11.4), 8.0, Color("#ffd2a0"), 1.6, true],
]
## Area signs on the theatre's level: area id, x, z.
const SIGNS := [["backstage", -23.0, 13.6], ["house", -19.6, 9.4], ["pit", -13.8, 3.6], ["stage", -17.4, -1.6], ["bow", 4.2, -3.9]]
## Seat blocks either side of the middle aisle: x from, x to; and the rows: floor id, z offset from its front.
const SEAT_BLOCKS := [[-19.4, -11.8], [-9.2, -1.6]]
const SEAT_ROWS := [["stalls", 1.7], ["stalls", 2.8], ["tier1", 0.42], ["tier2", 0.42]]
const SEAT_PITCH := 0.56
## The seat kept lit for whoever comes late: row index, block index, seat index.
const LIT_SEAT := [3, 1, 6]
## Prop builders of the island's district bands, standing on the stage as the
## regions' signature objects: kind, region whose colours it takes, x, z, yaw, scale.
const SET_PROPS := [
	["crates", "harbor", -13.4, -7.9, 0.3, 1.5],
	["rope_coil", "harbor", -12.5, -7.6, 0.0, 1.6],
	["cane_post", "candy", -11.7, -8.4, 0.2, 2.0],
	["gumballs", "candy", -11.2, -7.7, 0.0, 1.8],
	["lantern_post", "nightmarket", -9.8, -8.6, 0.0, 1.9],
	["windup_key", "toy", -8.5, -7.8, 0.4, 2.4],
	["cloud_puff", "sky", -7.4, -8.1, 0.0, 1.8],
	["pots", "garden", -6.6, -7.6, 0.5, 1.8],
	["number_post", "hotel", -5.6, -8.2, -0.2, 1.8],
	["luggage", "hotel", -5.1, -7.6, 0.6, 1.4],
	["clapper_post", "cinema", -12.6, -8.9, 0.1, 2.0],
	["pinwheel", "toy", -10.6, -7.5, 0.0, 1.9],
]
## The painted flats behind the props: look, x, z, width, height.
const FLATS := [["lighthouse", -13.0, -9.15, 1.8, 4.4], ["tent", -10.6, -9.25, 3.2, 3.6], ["wheel", -7.6, -9.3, 4.0, 4.6], ["arch", -5.2, -9.15, 1.8, 3.4]]

var world: Node3D
var kit_up: Kit
var kit_down: Kit
var structure_up := Kit.Sculpt.new()
var structure_down := Kit.Sculpt.new()
var painted: ShaderMaterial
var site_tags: Array[Label3D] = []
## The playbill at the island end of the bridge, which counts down the cards still missing.
var playbill: Label3D
var floor_body: StaticBody3D
var footlights: Array[Vector3] = []
## The islet bulbs' glow for the hour; a flash of the marquee rises above it.
var glow_base := 0.35
var _band := DistrictBand.new()

func _init(owner: Node3D, surface_kit: Kit, theatre_kit: Kit) -> void:
	world = owner
	kit_up = surface_kit
	kit_down = theatre_kit
	# The theatre's bulbs keep their own glow; the islet's follow the evening.
	var below: StandardMaterial3D = world._vertex_color_material("theatre:glow", 0.6)
	below.emission_enabled = true
	below.emission = WARM
	below.emission_energy_multiplier = BELOW_GLOW
	kit_down.glow_material = below

## Marquee bulbs and the bridge's rail lights glow with the island's lamps.
func apply_time_of_day(lamp_level: float) -> void:
	glow_base = 0.35 + lamp_level * 2.6
	kit_up.set_glow(glow_base)

func _painted() -> ShaderMaterial:
	if painted == null:
		painted = world.material_cache.get("theatre:painted")
		if painted == null:
			painted = ShaderMaterial.new()
			painted.shader = PAINTED
			painted.set_shader_parameter("vertex_tint", true)
			world.material_cache["theatre:painted"] = painted
	return painted

# =============================================================================
# The islet
# =============================================================================

func build_surface() -> void:
	floor_body = StaticBody3D.new()
	floor_body.name = "TheatreFloor"
	world.add_child(floor_body)
	_build_bay()
	_build_islet()
	_build_floors(false)
	_build_links(false)
	await world.build_pause()
	_build_stairwell()
	_build_marquee()
	await world.build_pause()
	_build_booth()
	_build_bridge()
	_build_playbill()
	_build_islet_dressing()
	world._mesh(structure_up.mesh(), Vector3.ZERO, _painted()).name = "TheatreIsletStructure"

## Standing alone the islet sits in open water past anything the camera shows;
## on the island the bay is the island's own sea.
func _build_bay() -> void:
	if world.embedded_in != null: return
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 260)
	var land: Array[Rect2] = [Rect2(-13.6, -11.2, 19.2, 14.8)]
	var none: Array[Rect2] = []
	var sea: MeshInstance3D = world._mesh(plane, Vector3(0, world.WATER_Y, 0), kit_up.shore_water(land, none))
	sea.name = "TheatreBay"
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The islet: a rock rising out of the bay in high shelves round the sunken
## stair, cliffs at the water, a low shelf for the bridge's landing, boulders
## at the cliffs' feet and a knoll behind the marquee.
func _build_islet() -> void:
	var rock: Material = kit_up.shore_ground("theatre-rock", Color("#a89a8a"), Color("#6c6058"), 1.4)
	var x: float = world.STAIR_X
	var high: float = world.ISLET_Y - 0.08
	var shelves := [
		[Rect2(-13.6, -11.2, x - 1.7 + 13.6, 14.8), high, 2.2, 0.4],
		[Rect2(x + 1.7, -11.2, -2.6 - x - 1.7, 14.8), high, 2.2, 0.4],
		[Rect2(x - 1.7, -2.4, 3.4, 6.0), high, 2.2, 0.35],
		[Rect2(-2.0, -2.6, 7.6, 5.4), world.ROCK_Y, 0.9, 1.2],
	]
	for index in shelves.size():
		var spec: Array = shelves[index]
		kit_up.mound(spec[0], spec[1], spec[2], spec[3], rock, float(index) * 1.9).name = "TheatreIslet%d" % index
	# Boulders where the cliffs meet the water.
	var stones := kit_up.batch("theatre-stones", kit_up.unit_boulder, world._stone_finish(Color("#7d7280")))
	for index in 26:
		var angle := TAU * float(index) / 26.0 + sin(float(index) * 2.1) * 0.1
		var at := Vector3(-4.6 + cos(angle) * 10.2, world.WATER_Y + 0.05, -3.8 + sin(angle) * 8.2)
		var size := 0.6 + fposmod(float(index) * 0.618, 1.0) * 0.8
		# Leave the bridge's landing clear.
		if at.x > 2.0 and absf(at.z) < 2.8: continue
		stones.add(at, Vector3(size * 1.2, size * 0.8, size), Basis(Vector3.UP, float(index) * 1.3))
	# The knoll the marquee is cut into, and a few crags on the shelves.
	for spec: Vector4 in [Vector4(x - 2.2, -10.4, 2.4, 2.6), Vector4(x - 4.2, -10.6, 2.0, 1.8), Vector4(x + 3.6, -10.6, 2.2, 2.4), Vector4(x + 5.6, -9.8, 1.6, 1.6),
			Vector4(-12.4, -6.4, 1.2, 1.2), Vector4(-3.2, -6.8, 1.3, 1.2), Vector4(x, -12.0, 2.2, 3.4)]:
		var base := Vector3(spec.x, high, spec.y)
		structure_up.tube(base + Vector3(0, spec.w * 0.5, 0), spec.z, spec.z * 0.55, spec.w, ROCK, 7, Basis(Vector3.UP, spec.x))
		structure_up.tube(base + Vector3(0.2, spec.w * 0.9, 0.1), spec.z * 0.6, spec.z * 0.2, spec.w * 0.4, ROCK_DARK, 6, Basis(Vector3.UP, spec.y))
		structure_up.ball(base + Vector3(-0.3, spec.w * 0.98, 0.4), spec.z * 0.32, MOSS, Color.TRANSPARENT, 7, 3, 0.45)

# =============================================================================
# Floors and slopes (both levels)
# =============================================================================

func _sculpt(below: bool) -> Kit.Sculpt:
	return structure_down if below else structure_up

func _kit(below: bool) -> Kit:
	return kit_down if below else kit_up

func _build_floors(below: bool) -> void:
	var tops := {
		"paving": world._coastal_surface(0, 1.3, Color("#d9c9b0")),
		"boards": world._coastal_surface(1, 1.1, Color("#a98663")),
		"stage": world._coastal_surface(1, 0.9, Color("#4a3a36")),
		"bow": world._coastal_surface(4, 1.2, Color("#f0dcc0")),
		"pit": world._coastal_surface(1, 1.0, Color("#6a4b3a")),
		"carpet": world._coastal_surface(6, 0.9, Color("#a8303f")),
	}
	var sides: Material = world._coastal_surface(4, 1.3, Color("#8a7a8c")) if below else world._coastal_surface(4, 1.2, Color("#b8a890"))
	for entry: Dictionary in world.PADS:
		if world.is_below(entry.y) != below: continue
		var rect: Rect2 = (entry.rect as Rect2).grow(LIP)
		var y: float = entry.y
		var foot: float = world.CAVERN_Y if below else y - 0.4
		_kit(below).surface(tops[entry.top]).add(Vector3(rect.get_center().x, y - 0.05, rect.get_center().y), Vector3(rect.size.x, 0.1, rect.size.y))
		var body_height: float = y - 0.1 - foot
		if body_height > 0.12:
			var body: Material = world._coastal_surface(6, 0.9, VELVET_DARK) if entry.top == "stage" else sides
			_kit(below).surface(body).add(Vector3(rect.get_center().x, (y - 0.1 + foot) * 0.5, rect.get_center().y), Vector3(rect.size.x - 0.06, body_height, rect.size.y - 0.06))
		_floor_body(entry.rect, y)
		if entry.top == "carpet":
			# A brass nosing along the step down at each tier's edge.
			structure_down.box(Vector3(rect.get_center().x, y - 0.02, rect.end.y - 0.04), Vector3(rect.size.x, 0.07, 0.1), BRASS)

func _floor_body(rect: Rect2, y: float) -> void:
	var holder := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, 0.3, rect.size.y)
	holder.shape = box
	holder.position = Vector3(rect.get_center().x, y - 0.15, rect.get_center().y)
	floor_body.add_child(holder)

func _build_links(below: bool) -> void:
	for link: Dictionary in world.links():
		if world.is_below(link.ya) != below: continue
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		var from := Vector3(a.x, link.ya, a.y)
		var to := Vector3(b.x, link.yb, b.y)
		var along := (to - from).normalized()
		var across := Vector3(along.z, 0, -along.x).normalized()
		var up := along.cross(across)
		var width: float = link.width
		var holder := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 0.3, from.distance_to(to))
		holder.shape = box
		holder.transform = Transform3D(Basis(across, up, along), (from + to) * 0.5 - up * 0.15)
		floor_body.add_child(holder)
		match String(link.kind):
			"descent": _steps(structure_up, from, to, width, 0.36, [Color("#d9c9b0"), Color("#cbb99e")], Color("#8d7d68"), to.y - 0.3)
			"climb":
				_steps(structure_up, from, to, width, 0.34, [Color("#d2c2a8"), Color("#c4b296")], Color("#8d7d68"), from.y - 0.4)
				_rails(structure_up, from, to, across, width, 1.1, Color("#8d7d68"))
			"tiers": _steps(structure_down, from, to, width, 0.4, [Color("#8a2a36"), Color("#7a2430")], BRASS.darkened(0.3), world.CAVERN_Y)
			"door":
				_kit(true).surface(world._coastal_surface(1, 1.1, Color("#a98663"))).add((from + to) * 0.5 - Vector3(0, 0.05, 0), Vector3(width, 0.1, from.distance_to(to) + 0.1), Basis.looking_at(along))
			_:
				_steps(structure_down, from, to, width, 0.36, [Color("#a98663"), Color("#9a7a58")], DARK_WOOD, world.CAVERN_Y)
				_rails(structure_down, from, to, across, width, 1.1, DARK_WOOD)

## Steps drawn on a slope: each tread's middle lies on the walking surface; the
## flight is solid down to `foot`.
func _steps(sculpt: Kit.Sculpt, from: Vector3, to: Vector3, width: float, tread: float, tones: Array, riser: Color, foot: float) -> void:
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var count := maxi(2, roundi(length / tread))
	var flat := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var yaw := Basis(Vector3.UP, atan2(flat.x, flat.z))
	var step_length := length / float(count)
	var rise := (to.y - from.y) / float(count)
	for index in count:
		var middle := from.lerp(to, (float(index) + 0.5) / float(count))
		sculpt.box(middle - Vector3(0, 0.1, 0), Vector3(width, 0.2, step_length + 0.02), tones[index % tones.size()], yaw)
		var low_edge := middle - flat * step_length * 0.5 * signf(rise)
		sculpt.box(low_edge + Vector3(0, -absf(rise) * 0.5 - 0.02, 0), Vector3(width - 0.04, absf(rise) + 0.04, 0.05), riser, yaw)
		var drop: float = middle.y - 0.2 - foot
		if drop > 0.05: sculpt.box(Vector3(middle.x, foot + drop * 0.5, middle.z), Vector3(width - 0.02, drop, step_length + 0.02), riser.darkened(0.25), yaw)

## Posts along both sides of a flight with a rail between them.
func _rails(sculpt: Kit.Sculpt, from: Vector3, to: Vector3, across: Vector3, width: float, spacing: float, post: Color) -> void:
	var count := maxi(1, int(from.distance_to(to) / spacing))
	var span := to - from
	for side: float in [-1.0, 1.0]:
		var edge := across * side * (width * 0.5 - 0.06)
		for index in count + 1:
			var at := from.lerp(to, float(index) / float(count)) + edge
			sculpt.box(at + Vector3(0, 0.45, 0), Vector3(0.08, 0.9, 0.08), post)
			sculpt.ball(at + Vector3(0, 0.93, 0), 0.06, BRASS, Color.TRANSPARENT, 6, 3)
		sculpt.box((from + to) * 0.5 + edge + Vector3(0, 0.86, 0), Vector3(0.06, 0.06, span.length()), post, Basis.looking_at(span.normalized(), Vector3.UP))

func _star_flat(sculpt: Kit.Sculpt, at: Vector3, radius: float, color: Color) -> void:
	for point in 5:
		var angle := TAU * float(point) / 5.0 - PI * 0.5
		var tip := at + Vector3(cos(angle), 0, sin(angle)) * radius
		var left := at + Vector3(cos(angle - 0.63), 0, sin(angle - 0.63)) * radius * 0.42
		var right := at + Vector3(cos(angle + 0.63), 0, sin(angle + 0.63)) * radius * 0.42
		DistrictBand._face(sculpt, at, left, tip, Vector3.UP, color)
		DistrictBand._face(sculpt, at, tip, right, Vector3.UP, color.darkened(0.12))

# =============================================================================
# Entrance
# =============================================================================

## Stone walls either side of the grand stair, hung with a poster for each of
## the ten regions, and a balustrade along their tops.
func _build_stairwell() -> void:
	var wall: Material = world._coastal_surface(4, 1.1, Color("#b6a48c"))
	var low: float = world.WELL_Y - 0.25
	var high: float = world.ISLET_Y + 0.12
	var middle: float = world.STAIR_X
	for side: float in [-1.0, 1.0]:
		var x := middle + side * 1.55
		kit_up.surface(wall).add(Vector3(x, (low + high) * 0.5, -5.6), Vector3(0.3, high - low, 7.4))
		structure_up.box(Vector3(x, high + 0.06, -5.6), Vector3(0.42, 0.12, 7.5), Color("#e2d2b6"))
		for index in 6:
			var z := -2.4 - float(index) * 1.32
			structure_up.box(Vector3(x, high + 0.42, z), Vector3(0.12, 0.6, 0.12), Color("#e2d2b6"))
			structure_up.ball(Vector3(x, high + 0.76, z), 0.09, GOLD, Color.TRANSPARENT, 6, 3)
		structure_up.box(Vector3(x, high + 0.7, -5.6), Vector3(0.08, 0.08, 6.6), Color("#e2d2b6"))
	# Ten posters down the inner faces, one per region in its own colours.
	var regions := ["welcome", "harbor", "candy", "nightmarket", "circus", "toy", "garden", "hotel", "sky", "cinema"]
	for index in regions.size():
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := -2.7 - floorf(float(index) * 0.5) * 1.25
		var step_y: float = lerpf(world.ISLET_Y, world.WELL_Y, clampf((-z - 2.0) / 5.6, 0.0, 1.0))
		var palette: Array = _palette(regions[index])
		var face := Vector3(middle + side * 1.385, step_y + 0.95, z)
		var turn := Basis(Vector3.UP, -side * PI * 0.5)
		structure_up.box(face, Vector3(0.82, 1.06, 0.03), palette[3], turn)
		structure_up.box(face + Vector3(-side * 0.012, 0.08, 0), Vector3(0.7, 0.62, 0.02), palette[0], turn)
		structure_up.box(face + Vector3(-side * 0.016, -0.36, 0), Vector3(0.66, 0.08, 0.02), palette[1], turn)
		structure_up.ball(face + Vector3(-side * 0.02, 0.12, 0), 0.16, palette[1], palette[2], 8, 3, 1.0)

## The marquee arch cut into the knoll at the foot of the stair: two pillars,
## a gilded arch over a doorway of darkness and velvet, a bulb-lit board with
## the theatre's name and a devil mask with little horns on top.
func _build_marquee() -> void:
	var at := Vector3(world.STAIR_X, world.WELL_Y, -9.4)
	var stone: Material = world._coastal_surface(4, 1.0, Color("#c9b79c"))
	for side: float in [-1.0, 1.0]:
		kit_up.surface(stone).add(at + Vector3(side * 1.95, 1.7, 0.05), Vector3(0.62, 3.4, 0.62))
		structure_up.box(at + Vector3(side * 1.95, 0.12, 0.05), Vector3(0.8, 0.24, 0.8), Color("#8d7d68"))
		structure_up.box(at + Vector3(side * 1.95, 3.45, 0.05), Vector3(0.8, 0.14, 0.8), GOLD.darkened(0.15))
	# The doorway: darkness, then velvet drapes tied back to either side.
	structure_up.box(at + Vector3(0, 1.45, -0.18), Vector3(3.3, 2.9, 0.1), Color("#0d0810"))
	for side: float in [-1.0, 1.0]:
		for fold in 3:
			structure_up.box(at + Vector3(side * (1.45 - float(fold) * 0.16), 1.35, -0.05 + float(fold) * 0.02), Vector3(0.18, 2.7 - float(fold) * 0.25, 0.08), VELVET.darkened(0.1 * float(fold)))
		structure_up.ball(at + Vector3(side * 1.3, 1.2, 0.04), 0.07, GOLD, Color.TRANSPARENT, 6, 3)
	# Gilded half ring over the doorway.
	var arch := Basis(Vector3.RIGHT, PI * 0.5)
	for segment in 9:
		var angle := PI * float(segment) / 8.0
		var spot := at + Vector3(cos(angle) * 1.7, 2.75 + sin(angle) * 0.75, 0.12)
		structure_up.box(spot, Vector3(0.42, 0.18, 0.22), GOLD, Basis(Vector3.BACK, angle - PI * 0.5))
		kit_up.glow.ball(spot + Vector3(0, 0, 0.13), 0.06, Color(1.0, 0.88, 0.55), Color.TRANSPARENT, 6, 3)
	# The marquee board with a frame of bulbs.
	var board := at + Vector3(0, 4.0, 0.1)
	structure_up.box(board, Vector3(4.4, 1.0, 0.24), PLUM)
	structure_up.box(board + Vector3(0, -0.58, 0.04), Vector3(4.6, 0.14, 0.3), GOLD.darkened(0.1))
	structure_up.box(board + Vector3(0, 0.58, 0.04), Vector3(4.6, 0.14, 0.3), GOLD.darkened(0.1))
	for bulb in 15:
		var x := -2.1 + float(bulb) * 0.3
		for edge: float in [-0.42, 0.42]:
			kit_up.glow.ball(board + Vector3(x, edge, 0.14), 0.055, Color(1.0, 0.9, 0.6), Color.TRANSPARENT, 6, 3)
	var title: Label3D = world._local_label("地底惡魔劇場", board + Vector3(0, 0.02, 0.16), 30, CREAM)
	title.outline_modulate = VELVET_DARK
	title.pixel_size = 0.0105
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.name = "TheatreMarquee"
	title.set_meta(world.SIGN_TITLE, true)
	var hint: Label3D = world._local_label("首演 · 往下走", at + Vector3(0, 2.25, 0.2), 20, GOLD)
	hint.outline_modulate = NIGHT
	hint.pixel_size = 0.0105
	hint.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# A devil mask crowns the board: a grin, two eyes and two little horns.
	var mask := board + Vector3(0, 1.0, 0.0)
	structure_up.ball(mask, 0.5, VELVET, VELVET.lightened(0.1), 12, 5, 0.8)
	for side: float in [-1.0, 1.0]:
		structure_up.tube(mask + Vector3(side * 0.36, 0.42, 0), 0.13, 0.0, 0.5, CREAM, 7, Basis(Vector3.BACK, side * 0.45))
		structure_up.ball(mask + Vector3(side * 0.18, 0.08, 0.38), 0.08, GOLD, Color.TRANSPARENT, 6, 3)
	structure_up.box(mask + Vector3(0, -0.16, 0.38), Vector3(0.34, 0.06, 0.04), NIGHT)
	var light: OmniLight3D = kit_up.lamp_light(at + Vector3(0, 2.6, 1.8), 7.0, Color("#ffcf96"))
	light.name = "TheatreMarqueeLamp"
	kit_up.blocker(at + Vector3(0, 1.0, -0.4), Vector3(4.6, 2.0, 0.6))

## A round ticket booth with a domed roof, a brass grille window and a playbill board.
func _build_booth() -> void:
	var at: Vector3 = world.TICKET_BOOTH
	structure_up.tube(at + Vector3(0, 0.1, 0), 0.82, 0.86, 0.2, Color("#8d7d68"), 12)
	structure_up.tube(at + Vector3(0, 1.05, 0), 0.7, 0.7, 1.7, VELVET, 12)
	for rib in 8:
		var angle := TAU * float(rib) / 8.0
		structure_up.box(at + Vector3(cos(angle) * 0.71, 1.05, sin(angle) * 0.71), Vector3(0.06, 1.7, 0.06), GOLD.darkened(0.1))
	structure_up.box(at + Vector3(0.2, 1.25, 0.6), Vector3(0.66, 0.52, 0.1), Color("#2b2030"))
	for bar in 4:
		structure_up.box(at + Vector3(0.0 + float(bar) * 0.13, 1.25, 0.66), Vector3(0.025, 0.5, 0.025), BRASS)
	structure_up.box(at + Vector3(0.2, 0.96, 0.7), Vector3(0.74, 0.06, 0.24), GOLD)
	structure_up.tube(at + Vector3(0, 1.98, 0), 0.86, 0.86, 0.16, GOLD.darkened(0.1), 12)
	structure_up.ball(at + Vector3(0, 2.06, 0), 0.82, PLUM, VELVET_DARK, 12, 4, 0.8, true)
	structure_up.tube(at + Vector3(0, 2.85, 0), 0.06, 0.02, 0.4, GOLD, 6)
	structure_up.ball(at + Vector3(0, 3.08, 0), 0.1, GOLD, Color.TRANSPARENT, 6, 3)
	kit_up.glow.ball(at + Vector3(0.2, 1.45, 0.62), 0.07, WARM, Color.TRANSPARENT, 6, 3)
	kit_up.blocker(at + Vector3(0, 1.0, 0), Vector3(1.5, 2.0, 1.5))
	var sign: Label3D = world._local_label("售票亭", at + Vector3(0, 2.5, 0.9), 22, CREAM)
	sign.outline_modulate = VELVET_DARK
	sign.pixel_size = 0.0105

## The bridge from the island's gate to the plaza: planks on piles, rails lit
## with a bulb on every post, and an arch with horns at the islet end.
func _build_bridge() -> void:
	var site: Dictionary = DistrictSites.SITES["theatre"]
	var strip: Rect2 = site.approach
	var top_y: float = float(site.approach_y)
	var deck := Rect2(strip.position + Vector2(0.2, 0.1), strip.size - Vector2(0.4, 0.2))
	kit_up.surface(world._coastal_surface(1, 1.1, Color("#c9a273"))).add(Vector3(deck.get_center().x, top_y - 0.06, deck.get_center().y), Vector3(deck.size.x, 0.12, deck.size.y))
	var count := int(deck.size.x / 1.6)
	var piles := kit_up.batch("theatre-piles", kit_up.unit_post, world._wood_material(Color("#5e4632")))
	for side: float in [-1.0, 1.0]:
		var z := deck.get_center().y + side * (deck.size.y * 0.5 - 0.08)
		for index in count + 1:
			var x := deck.position.x + 0.3 + float(index) * (deck.size.x - 0.6) / float(count)
			var bottom: float = world.WATER_Y - 0.6
			piles.add(Vector3(x, (top_y - 0.1 + bottom) * 0.5, z), Vector3(0.18, top_y - 0.1 - bottom, 0.18))
			structure_up.box(Vector3(x, top_y + 0.48, z), Vector3(0.1, 0.96, 0.1), DARK_WOOD)
			kit_up.glow.ball(Vector3(x, top_y + 1.02, z), 0.07, Color(1.0, 0.82, 0.62), Color.TRANSPARENT, 6, 3)
		structure_up.box(Vector3(deck.get_center().x, top_y + 0.86, z), Vector3(deck.size.x - 0.6, 0.05, 0.05), Color("#d9c59a"))
	# The arch where the bridge lands.
	var foot := Vector3(deck.position.x + 0.5, top_y, deck.get_center().y)
	for side: float in [-1.0, 1.0]:
		var post := foot + Vector3(0, 0, side * (deck.size.y * 0.5 + 0.12))
		structure_up.box(post + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), NIGHT)
		structure_up.box(post + Vector3(0, 1.45, 0), Vector3(0.26, 2.3, 0.26), INK)
		structure_up.tube(post + Vector3(0, 2.75, 0), 0.2, 0.0, 0.5, VELVET, 6, Basis(Vector3.RIGHT, side * 0.4))
	structure_up.box(foot + Vector3(0, 2.6, 0), Vector3(0.14, 0.5, deck.size.y + 0.5), VELVET_DARK)
	for bulb in 7:
		kit_up.glow.ball(foot + Vector3(0.09, 2.6, -deck.size.y * 0.5 - 0.1 + float(bulb) * (deck.size.y + 0.2) / 6.0), 0.06, Color(1.0, 0.86, 0.6), Color.TRANSPARENT, 6, 3)

## A playbill on an easel at the island end of the bridge, facing the path:
## the theatre's name and, while the gate is shut, how many cards are missing.
func _build_playbill() -> void:
	var strip: Rect2 = DistrictSites.SITES["theatre"].approach
	var at := Vector3(strip.end.x - 4.8, float(DistrictSites.SITES["theatre"].approach_y), strip.end.y - 0.1)
	for side: float in [-1.0, 1.0]:
		structure_up.box(at + Vector3(side * 1.0, 1.0, -0.12), Vector3(0.08, 2.0, 0.08), DARK_WOOD, Basis(Vector3.RIGHT, -0.12))
	structure_up.box(at + Vector3(0, 1.5, 0), Vector3(2.3, 1.3, 0.06), GOLD.darkened(0.15))
	structure_up.box(at + Vector3(0, 1.5, 0.035), Vector3(2.14, 1.14, 0.02), PLUM)
	structure_up.ball(at + Vector3(0, 2.24, 0.02), 0.22, VELVET, Color.TRANSPARENT, 8, 3, 0.8)
	for side: float in [-1.0, 1.0]:
		structure_up.tube(at + Vector3(side * 0.14, 2.44, 0.02), 0.06, 0.0, 0.2, CREAM, 5, Basis(Vector3.BACK, side * 0.4))
	playbill = world._local_label("地底惡魔劇場", at + Vector3(0, 1.5, 0.06), 30, CREAM)
	playbill.outline_modulate = VELVET_DARK
	playbill.pixel_size = 0.0095
	playbill.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	playbill.name = "TheatrePlaybill"
	kit_up.blocker(at + Vector3(0, 1.0, -0.1), Vector3(2.2, 2.0, 0.3))

## The playbill's words for a sticker count (-1 when the count is not known).
static func playbill_text(count: int, needed: int) -> String:
	if count >= needed: return "地底惡魔劇場
今晚首演 · 請進"
	if count < 0: return "地底惡魔劇場
%d 張普通拍貼開演" % needed
	return "地底惡魔劇場
還差 %d 張普通拍貼" % (needed - count)

## Planters, touring trunks and a lamp post on the plaza, and a lamp on the landing.
func _build_islet_dressing() -> void:
	var y: float = world.ISLET_Y
	for spec: Array in [["pots", "garden", Vector3(-12.0, y, -1.5), 0.4, 1.4], ["pots", "garden", Vector3(-4.0, y, -1.6), 1.2, 1.3], ["luggage", "hotel", Vector3(-3.4, y, 2.4), 0.5, 1.3]]:
		_prop(structure_up, kit_up, spec[0], spec[1], spec[2], spec[3], spec[4])
		kit_up.blocker((spec[2] as Vector3) + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
	for post: Vector3 in [Vector3(world.STAIR_X + 2.2, y, -1.5), Vector3(2.6, world.LANDING_Y, 1.5)]:
		structure_up.box(post + Vector3(0, 0.1, 0), Vector3(0.36, 0.2, 0.36), NIGHT)
		structure_up.tube(post + Vector3(0, 1.4, 0), 0.06, 0.05, 2.6, INK, 6)
		structure_up.box(post + Vector3(0, 2.72, 0), Vector3(0.5, 0.05, 0.05), GOLD)
		kit_up.glow.box(post + Vector3(0, 2.5, 0), Vector3(0.22, 0.3, 0.22), WARM, kit_up.view_basis)
		kit_up.lamp_light(post + Vector3(0, 2.3, 0.3), 6.5)
		kit_up.blocker(post + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4))

## One of the island's district-band props, built with that district's colours.
func _prop(sculpt: Kit.Sculpt, kit: Kit, kind: String, region: String, at: Vector3, yaw: float, scale: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale), at)
	_band.props = sculpt
	_band.glow = kit.glow
	sculpt.frame = frame
	kit.glow.frame = frame
	var seeds := PackedFloat32Array([fposmod(at.x * 0.37, 1.0), fposmod(at.z * 0.53, 1.0), fposmod((at.x + at.z) * 0.29, 1.0), 0.6, 0.4, 0.7])
	_band.call("_" + kind, seeds, _palette(region))
	sculpt.frame = Transform3D.IDENTITY
	kit.glow.frame = Transform3D.IDENTITY

static func _palette(region: String) -> Array:
	if region == "welcome": return [Color("#e2795e"), Color("#edbb65"), Color("#246c6c"), Color("#fff0d6"), Color("#7fb8d8")]
	return DistrictBand.BANDS[region].colors

# =============================================================================
# The theatre
# =============================================================================

func build_underground() -> void:
	_build_cavern()
	_build_floors(true)
	_build_links(true)
	await world.build_pause()
	_build_stage()
	_build_flats()
	await world.build_pause()
	_build_set_props()
	_build_pit()
	_build_seats()
	await world.build_pause()
	_build_corridor()
	_build_walls()
	_build_bow()
	_build_signs()
	_build_sites()
	_build_lamps()
	world._mesh(structure_down.mesh(), Vector3.ZERO, _painted()).name = "TheatreStructure"

## A wide rock floor past anything the camera shows, a towering rock face
## behind the stage and stalagmites round the edges.
func _build_cavern() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	var ground: MeshInstance3D = world._mesh(plane, Vector3(-11, world.CAVERN_Y, 4), world._coastal_surface(4, 2.6, Color("#7a6a80")))
	ground.name = "TheatreCavern"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var face: Material = world._coastal_surface(4, 2.2, Color("#7a6c84"))
	kit_down.surface(face).add(Vector3(-11, world.FLOOR + 6.0, -11.4), Vector3(60, 13.6, 1.0))
	kit_down.surface(face).add(Vector3(-29.2, world.FLOOR + 3.0, 4.0), Vector3(1.0, 7.6, 31.0))
	kit_down.surface(face).add(Vector3(6.6, world.FLOOR + 2.4, 4.0), Vector3(1.0, 6.4, 31.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7101
	# Rubble and a few stalagmites over the cavern floor, off the theatre's own floors.
	var rubble := kit_down.batch("theatre-rubble", kit_down.unit_boulder, world._stone_finish(Color("#8a7c90")))
	for index in 40:
		var at := Vector3(rng.randf_range(-44.0, 20.0), world.CAVERN_Y, rng.randf_range(-10.6, 34.0))
		if at.x > -29.6 and at.x < 7.0 and at.z < 19.0: at.z = 19.8 + rng.randf() * 12.0
		var size := rng.randf_range(0.5, 1.6)
		rubble.add(at, Vector3(size * 1.3, size * 0.7, size), Basis(Vector3.UP, rng.randf() * TAU))
		if index % 4 == 0:
			var height := rng.randf_range(1.0, 2.4)
			structure_down.tube(at + Vector3(0.4, height * 0.5, 0.2), height * 0.24, 0.05, height, ROCK.lightened(0.1), 6)
	# Rock drapes along the top of the back face.
	for index in 26:
		var x := -40.0 + float(index) * 2.3
		structure_down.tube(Vector3(x, world.FLOOR + 12.4, -10.8), 0.9, 0.2, 1.6 + fposmod(float(index) * 0.61, 1.0) * 1.4, ROCK_DARK, 6)

## The stage: a velvet skirt with a gold fringe, a row of hooded footlights, a
## star cloth at the back, the valance over the curtain line with the theatre's
## mask, and a lighting batten above.
func _build_stage() -> void:
	var stage: Dictionary = world.pad("stage")
	var rect: Rect2 = stage.rect
	var y: float = stage.y
	structure_down.box(Vector3(rect.get_center().x, y - 0.06, rect.end.y + LIP + 0.02), Vector3(rect.size.x + 0.4, 0.12, 0.06), GOLD.darkened(0.1))
	for tassel in 34:
		var x := rect.position.x + 0.2 + float(tassel) * (rect.size.x - 0.4) / 33.0
		structure_down.box(Vector3(x, y - 0.2, rect.end.y + LIP + 0.04), Vector3(0.05, 0.16, 0.03), GOLD)
	# Footlights: hooded lamps along the front edge.
	for lamp in 11:
		var x := rect.position.x + 1.6 + float(lamp) * (rect.size.x - 3.2) / 10.0
		var at := Vector3(x, y, rect.end.y - 0.12)
		structure_down.box(at + Vector3(0, 0.08, 0.02), Vector3(0.44, 0.16, 0.18), NIGHT)
		structure_down.box(at + Vector3(0, 0.17, -0.03), Vector3(0.46, 0.04, 0.24), BRASS)
		kit_down.glow.box(at + Vector3(0, 0.08, -0.08), Vector3(0.36, 0.1, 0.03), Color(1.0, 0.84, 0.52))
		footlights.append(at + Vector3(0, 0.08, -0.1))
	# The star cloth at the back of the stage.
	var back := Vector3(rect.get_center().x, y, rect.position.y - 0.1)
	kit_down.surface(world._coastal_surface(6, 1.4, Color("#2c1f3c"))).add(back + Vector3(0, 3.3, 0), Vector3(rect.size.x + 0.6, 6.6, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7102
	for star in 40:
		kit_down.glow.ball(back + Vector3(rng.randf_range(-8.2, 8.2), rng.randf_range(4.6, 6.4), 0.08), rng.randf_range(0.03, 0.07), Color(1.0, 0.95, 0.8), Color.TRANSPARENT, 4, 2)
	_moon(back + Vector3(5.6, 5.5, 0.09), 0.55)
	# The valance over the curtain line, hung on ropes from the fly loft.
	var valance := Vector3((world.CURTAIN_FROM + world.CURTAIN_TO) * 0.5, y + 6.0, world.CURTAIN_Z)
	var span: float = world.CURTAIN_TO - world.CURTAIN_FROM + 2.2
	structure_down.box(valance + Vector3(0, 0.5, 0), Vector3(span, 1.0, 0.24), VELVET_DARK)
	for scallop in 14:
		var x := -span * 0.5 + 0.4 + float(scallop) * (span - 0.8) / 13.0
		structure_down.ball(valance + Vector3(x, -0.02, 0.06), 0.42, VELVET, Color.TRANSPARENT, 8, 3, 0.6)
		structure_down.box(valance + Vector3(x, -0.32, 0.18), Vector3(0.06, 0.24, 0.03), GOLD)
	structure_down.box(valance + Vector3(0, 1.02, 0.08), Vector3(span + 0.2, 0.12, 0.3), GOLD.darkened(0.1))
	for side: float in [-1.0, 1.0]:
		structure_down.box(valance + Vector3(side * (span * 0.5 - 0.3), 4.0, 0), Vector3(0.05, 6.0, 0.05), Color("#8a7a6a"))
	# The theatre's emblem: comedy and tragedy masks, each with little horns.
	for side: float in [-1.0, 1.0]:
		var mask := valance + Vector3(side * 0.45, 0.62, 0.22)
		structure_down.ball(mask, 0.36, CREAM if side < 0.0 else GOLD, Color.TRANSPARENT, 10, 4, 0.9)
		for horn: float in [-1.0, 1.0]:
			structure_down.tube(mask + Vector3(horn * 0.24, 0.32, 0), 0.08, 0.0, 0.3, VELVET, 6, Basis(Vector3.BACK, horn * 0.4))
		structure_down.box(mask + Vector3(0, -0.12 + side * 0.03, 0.3), Vector3(0.26, 0.05, 0.04), NIGHT, Basis(Vector3.BACK, side * 0.25))
	# Welcome bunting strung across the top of the set.
	var colors: Array[Color] = [Color("#e2795e"), Color("#edbb65"), Color("#246c6c"), Color("#fff0d6"), Color("#7fb8d8")]
	kit_down.bunting(Vector3(world.CURTAIN_FROM + 0.4, y + 4.9, -8.3), Vector3(world.CURTAIN_TO - 0.4, y + 4.9, -8.3), colors, 0.5)
	# A lighting batten over the front of the stage.
	var batten := Vector3(rect.get_center().x, y + 7.4, -3.2)
	structure_down.box(batten, Vector3(rect.size.x - 2.0, 0.1, 0.1), Color("#4a4452"))
	for lamp in 6:
		var x := -6.5 + float(lamp) * 2.6
		structure_down.tube(batten + Vector3(x, -0.3, 0.05), 0.16, 0.2, 0.4, NIGHT, 8, Basis(Vector3.RIGHT, 0.7))
		kit_down.glow.ball(batten + Vector3(x, -0.42, 0.22), 0.11, Color(1.0, 0.92, 0.72), Color.TRANSPARENT, 6, 3)

func _moon(at: Vector3, radius: float) -> void:
	structure_down.tube(at, radius, radius, 0.04, Color("#fff2c8"), 16, Basis(Vector3.RIGHT, PI * 0.5))
	structure_down.tube(at + Vector3(radius * 0.35, radius * 0.2, 0.03), radius * 0.8, radius * 0.8, 0.03, Color("#2c1f3c"), 16, Basis(Vector3.RIGHT, PI * 0.5))

## The painted flats along the back of the set, braced from behind and held
## down with sandbags: the lighthouse, the circus tent, the ferris wheel and
## the welcome arch, each cut out to its shape and painted in its region's colours.
func _build_flats() -> void:
	var y: float = world.pad("stage").y
	for spec: Array in FLATS:
		var at := Vector3(float(spec[1]), y, float(spec[2]))
		var width: float = spec[3]
		var height: float = spec[4]
		match String(spec[0]):
			"lighthouse": _lighthouse_flat(at, width, height)
			"tent": _tent_flat(at, width, height)
			"wheel": _wheel_flat(at, width, height)
			"arch": _arch_flat(at, width, height)
		# Braces and a sandbag behind each flat.
		for side: float in [-0.3, 0.3]:
			structure_down.box(at + Vector3(side * width, height * 0.3, -0.35), Vector3(0.06, height * 0.62, 0.06), Color("#b89a72"), Basis(Vector3.RIGHT, 0.5))
			structure_down.ball(at + Vector3(side * width, 0.1, -0.6), 0.16, Color("#8a7a5a"), Color.TRANSPARENT, 6, 2, 0.6)
	kit_down.blocker(Vector3((world.CURTAIN_FROM + world.CURTAIN_TO) * 0.5, y + 1.0, -8.45), Vector3(world.CURTAIN_TO - world.CURTAIN_FROM + 0.4, 2.0, 2.1))

func _lighthouse_flat(at: Vector3, width: float, height: float) -> void:
	var palette := _palette("harbor")
	var bands := 6
	for band in bands:
		var t0 := float(band) / float(bands)
		var t1 := float(band + 1) / float(bands)
		var w0 := lerpf(width * 0.5, width * 0.28, t0)
		var w1 := lerpf(width * 0.5, width * 0.28, t1)
		var tone: Color = palette[1] if band % 2 == 0 else palette[2]
		var low := at + Vector3(0, height * 0.72 * t0, 0)
		var high := at + Vector3(0, height * 0.72 * t1, 0)
		structure_down.quad(low + Vector3(-w0, 0, 0), high + Vector3(-w1, 0, 0), high + Vector3(w1, 0, 0), low + Vector3(w0, 0, 0), tone)
	var lantern := at + Vector3(0, height * 0.8, 0.02)
	structure_down.box(lantern + Vector3(0, -0.3, 0), Vector3(width * 0.7, 0.12, 0.1), INK)
	kit_down.glow.box(lantern + Vector3(0, 0.05, 0), Vector3(width * 0.4, 0.5, 0.06), Color(1.0, 0.9, 0.6))
	DistrictBand._face(structure_down, lantern + Vector3(-width * 0.32, 0.32, 0), lantern + Vector3(width * 0.32, 0.32, 0), lantern + Vector3(0, 0.95, 0), Vector3.BACK, palette[1])
	# A painted beam of light reaching out from the lamp.
	DistrictBand._face(structure_down, lantern + Vector3(0.2, 0.05, 0.01), lantern + Vector3(1.6, 0.4, 0.01), lantern + Vector3(1.6, -0.25, 0.01), Vector3.BACK, Color("#fff2b8"))

func _tent_flat(at: Vector3, width: float, height: float) -> void:
	var palette := _palette("circus")
	var eave := height * 0.5
	var half := width * 0.5
	for stripe in 6:
		var x0 := -half + float(stripe) * width / 6.0
		var x1 := x0 + width / 6.0
		var tone: Color = palette[0] if stripe % 2 == 0 else palette[3]
		structure_down.quad(at + Vector3(x0, 0, 0), at + Vector3(x0, eave, 0), at + Vector3(x1, eave, 0), at + Vector3(x1, 0, 0), tone)
		var tip := at + Vector3(0, height * 0.92, 0)
		DistrictBand._face(structure_down, at + Vector3(x0 * 1.08, eave, 0.01), tip, at + Vector3(x1 * 1.08, eave, 0.01), Vector3.BACK, tone.darkened(0.08))
	structure_down.box(at + Vector3(0, eave * 0.42, 0.02), Vector3(width * 0.26, eave * 0.84, 0.02), NIGHT)
	for scallop in 6:
		structure_down.ball(at + Vector3(-half + (float(scallop) + 0.5) * width / 6.0, eave, 0.03), width / 13.0, palette[1], Color.TRANSPARENT, 6, 3, 0.5)
	structure_down.box(at + Vector3(0, height * 1.02, 0), Vector3(0.04, height * 0.22, 0.04), INK)
	DistrictBand._face(structure_down, at + Vector3(0, height * 1.12, 0.01), at + Vector3(0.5, height * 1.06, 0.01), at + Vector3(0, height * 1.0, 0.01), Vector3.BACK, palette[1])

func _wheel_flat(at: Vector3, width: float, height: float) -> void:
	var palette := _palette("sky")
	var hub := at + Vector3(0, height * 0.55, 0)
	var radius := width * 0.45
	var upright := Basis(Vector3.RIGHT, PI * 0.5)
	DistrictBand._ring(structure_down, hub, radius, 0.07, CREAM, upright, 24, 5)
	DistrictBand._ring(structure_down, hub, radius * 0.62, 0.04, palette[1], upright, 18, 4)
	for spoke in 8:
		var angle := TAU * float(spoke) / 8.0
		var tip := hub + Vector3(cos(angle), sin(angle), 0) * radius
		structure_down.box((hub + tip) * 0.5, Vector3(0.05, radius, 0.04), CREAM, Basis(Vector3.BACK, angle - PI * 0.5))
		var cabin := tip + Vector3(0, -0.22, 0.04)
		structure_down.box(cabin, Vector3(0.36, 0.3, 0.06), palette[spoke % 4])
		structure_down.box(cabin + Vector3(0, 0.19, 0), Vector3(0.42, 0.06, 0.07), palette[(spoke + 1) % 4].darkened(0.2))
	structure_down.ball(hub, 0.16, GOLD, Color.TRANSPARENT, 8, 3)
	for side: float in [-1.0, 1.0]:
		var foot := at + Vector3(side * radius * 0.7, 0, 0)
		structure_down.box((foot + hub) * 0.5 + Vector3(0, 0, -0.06), Vector3(0.12, foot.distance_to(hub), 0.08), Color("#8aa4c0"), Basis(Vector3.BACK, side * atan2(radius * 0.7, height * 0.55)))
	for puff in 3:
		structure_down.ball(at + Vector3(-1.6 + float(puff) * 1.5, 0.35, 0.1), 0.42, palette[4], Color.TRANSPARENT, 8, 3, 0.6)

func _arch_flat(at: Vector3, width: float, height: float) -> void:
	var palette := _palette("welcome")
	for side: float in [-1.0, 1.0]:
		structure_down.box(at + Vector3(side * width * 0.4, height * 0.38, 0), Vector3(width * 0.18, height * 0.76, 0.08), palette[3])
		structure_down.box(at + Vector3(side * width * 0.4, height * 0.78, 0.02), Vector3(width * 0.24, 0.12, 0.1), palette[1])
	structure_down.box(at + Vector3(0, height * 0.86, 0), Vector3(width * 1.04, height * 0.16, 0.1), palette[2])
	structure_down.box(at + Vector3(0, height * 0.86, 0.06), Vector3(width * 0.8, height * 0.08, 0.02), palette[1])
	structure_down.ball(at + Vector3(0, height * 1.0, 0.02), width * 0.2, palette[0], Color.TRANSPARENT, 8, 3, 0.8, true)
	# A little fountain painted in the gateway.
	structure_down.tube(at + Vector3(0, 0.18, 0.03), width * 0.26, width * 0.3, 0.36, palette[4], 10)
	structure_down.ball(at + Vector3(0, 0.62, 0.05), 0.18, Color("#cfeaf6"), Color.TRANSPARENT, 6, 3, 1.6)

## The regions' own props, borrowed from the island's district bands.
func _build_set_props() -> void:
	var y: float = world.pad("stage").y
	for spec: Array in SET_PROPS:
		_prop(structure_down, kit_down, String(spec[0]), String(spec[1]), Vector3(float(spec[2]), y, float(spec[3])), float(spec[4]), float(spec[5]))

## The pit: a parapet with a brass rail round its open sides, a grand piano,
## a drum kit, a double bass and music stands with little lamps (the band
## itself bounces in theatre_life).
func _build_pit() -> void:
	var pit: Dictionary = world.pad("pit")
	var rect: Rect2 = pit.rect
	var y: float = pit.y
	var parapet: Material = world._coastal_surface(4, 1.0, Color("#6e4e5e"))
	# Front parapet toward the stalls, broken by the pit stair; the stage's front closes the north side.
	var gap := Vector2(-11.4, -9.6)
	for piece: Vector2 in [Vector2(rect.position.x - 0.3, gap.x), Vector2(gap.y, rect.end.x + 0.3)]:
		kit_down.surface(parapet).add(Vector3((piece.x + piece.y) * 0.5, (y + world.FLOOR + 0.35) * 0.5, rect.end.y + 0.45), Vector3(piece.y - piece.x, world.FLOOR + 0.35 - y, 0.5))
		structure_down.box(Vector3((piece.x + piece.y) * 0.5, world.FLOOR + 0.92, rect.end.y + 0.45), Vector3(piece.y - piece.x, 0.06, 0.08), BRASS)
		for post in int((piece.y - piece.x) / 0.9) + 1:
			structure_down.box(Vector3(piece.x + 0.1 + float(post) * 0.9, world.FLOOR + 0.62, rect.end.y + 0.45), Vector3(0.05, 0.55, 0.05), BRASS.darkened(0.2))
	# The ledge between the stage front and the pit, and the pit's ends.
	kit_down.surface(parapet).add(Vector3(rect.get_center().x, (world.CAVERN_Y + world.FLOOR + 0.2) * 0.5, -1.0), Vector3(rect.size.x + 0.6, world.FLOOR + 0.2 - world.CAVERN_Y, 1.6))
	for side: float in [-1.0, 1.0]:
		var x := rect.get_center().x + side * (rect.size.x * 0.5 + 0.3)
		kit_down.surface(parapet).add(Vector3(x, (world.CAVERN_Y + world.FLOOR + 0.35) * 0.5, rect.get_center().y + 0.2), Vector3(0.6, world.FLOOR + 0.35 - world.CAVERN_Y, rect.size.y + 0.6))
	# The voids beside the pit and either side of the stage stairs read as floor-level ledges.
	var drop: Material = world._coastal_surface(4, 1.4, Color("#3c2c40"))
	for piece: Rect2 in [Rect2(-21.2, -1.8, 3.4, 6.4), Rect2(-15.8, -1.8, 0.9, 6.4), Rect2(-4.3, -1.8, 0.5, 6.4), Rect2(-1.8, -1.8, 2.4, 6.4), Rect2(-14.9, 3.7, 10.6, 0.9)]:
		kit_down.surface(drop).add(Vector3(piece.get_center().x, (world.CAVERN_Y + world.FLOOR - 0.4) * 0.5, piece.get_center().y), Vector3(piece.size.x, world.FLOOR - 0.4 - world.CAVERN_Y, piece.size.y))
	# Music stands with little lamps.
	for index in 6:
		var at := Vector3(rect.position.x + 1.0 + float(index) * 1.6, y, rect.position.y + 0.9 + 0.3 * float(index % 2))
		if absf(at.x - world.PIT_POINT.x) < 0.9: continue
		structure_down.box(at + Vector3(0, 0.45, 0), Vector3(0.04, 0.9, 0.04), INK)
		structure_down.box(at + Vector3(0, 0.95, 0.05), Vector3(0.42, 0.3, 0.03), INK, Basis(Vector3.RIGHT, -0.4))
		structure_down.box(at + Vector3(0, 0.96, 0.07), Vector3(0.36, 0.24, 0.01), CREAM, Basis(Vector3.RIGHT, -0.4))
		kit_down.glow.ball(at + Vector3(0, 1.16, 0.0), 0.05, WARM, Color.TRANSPARENT, 6, 3)
	# Conductor's podium facing the stage.
	var podium := Vector3(-12.6, y, 2.3)
	structure_down.box(podium + Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.7), DARK_WOOD)
	structure_down.box(podium + Vector3(0, 0.75, -0.3), Vector3(0.5, 0.06, 0.36), DARK_WOOD, Basis(Vector3.RIGHT, -0.3))
	kit_down.blocker(podium + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.7))

## Velvet seats in rows on the stalls and the tiers, facing the stage, with the
## aisles left open; one seat at the back keeps a little lamp lit.
func _build_seats() -> void:
	var seat := Kit.Sculpt.new()
	seat.box(Vector3(0, 0.24, 0), Vector3(0.48, 0.12, 0.44), Color.WHITE)
	seat.box(Vector3(0, 0.52, 0.2), Vector3(0.48, 0.5, 0.1), Color.WHITE)
	seat.ball(Vector3(0, 0.76, 0.2), 0.24, Color.WHITE, Color.TRANSPARENT, 8, 3, 0.35, true)
	for side: float in [-1.0, 1.0]:
		seat.box(Vector3(side * 0.27, 0.32, 0.02), Vector3(0.05, 0.16, 0.46), Color(0.82, 0.66, 0.36))
	seat.box(Vector3(0, 0.09, 0.05), Vector3(0.12, 0.18, 0.12), Color(0.3, 0.26, 0.3))
	var seats := kit_down.batch("theatre-seats", seat.mesh(), world._vertex_color_material("theatre-seats"))
	for row_index in SEAT_ROWS.size():
		var row: Array = SEAT_ROWS[row_index]
		var floor: Dictionary = world.pad(row[0])
		var z: float = (floor.rect as Rect2).position.y + float(row[1])
		for block_index in SEAT_BLOCKS.size():
			var block: Array = SEAT_BLOCKS[block_index]
			var from: float = block[0]
			var to: float = block[1]
			var count := int((to - from) / SEAT_PITCH)
			for index in count:
				var x := from + (float(index) + 0.5) * (to - from) / float(count)
				var tone := VELVET.lightened(0.05 * float((index + row_index) % 3))
				seats.add(Vector3(x, floor.y, z), Vector3.ONE, Basis.IDENTITY, tone)
				if [row_index, block_index, index] == LIT_SEAT:
					kit_down.glow.ball(Vector3(x + 0.27, floor.y + 0.5, z - 0.05), 0.07, Color(1.0, 0.86, 0.56), Color.TRANSPARENT, 6, 3)
					structure_down.box(Vector3(x, floor.y + 0.34, z - 0.05), Vector3(0.22, 0.02, 0.14), CREAM)
			if row[0] == "stalls" and row[1] > 2.0: continue
			var depth := 2.1 if row[0] == "stalls" else 1.0
			var centre_z := z + (0.55 if row[0] == "stalls" else 0.02)
			kit_down.blocker(Vector3((from + to) * 0.5, floor.y + 1.0, centre_z), Vector3(to - from + 0.1, 2.0, depth))

## The backstage corridor: a panelled wall with pipes, a dressing mirror ringed
## with bulbs, a call board, stacked prop crates, coiled ropes, the costume
## rail's frame, and the stage door at the south end with its glowing exit sign.
func _build_corridor() -> void:
	var corridor: Dictionary = world.pad("corridor")
	var rect: Rect2 = corridor.rect
	var y: float = corridor.y
	var x := rect.position.x - 0.45
	kit_down.surface(world._coastal_surface(1, 1.2, Color("#6e5048"))).add(Vector3(x, y + 2.3, rect.get_center().y), Vector3(0.3, 4.6, rect.size.y + 1.0))
	structure_down.box(Vector3(x + 0.18, y + 0.15, rect.get_center().y), Vector3(0.08, 0.3, rect.size.y + 1.0), DARK_WOOD)
	for pipe in 2:
		structure_down.tube(Vector3(x + 0.24, y + 3.8 + float(pipe) * 0.3, rect.get_center().y), 0.06, 0.06, rect.size.y + 1.0, Color("#8a8f96"), 6, Basis(Vector3.RIGHT, PI * 0.5))
	# The dressing mirror with its ring of bulbs.
	var mirror := Vector3(x + 0.2, y + 1.6, 4.4)
	structure_down.box(mirror, Vector3(0.06, 1.1, 1.4), Color("#c6d6e0"))
	structure_down.box(Vector3(x + 0.5, y + 0.8, 4.4), Vector3(0.6, 0.08, 1.6), DARK_WOOD)
	for bulb in 10:
		var t := float(bulb) / 9.0
		kit_down.glow.ball(mirror + Vector3(0.06, 0.62 * cos(t * TAU), 0.78 * sin(t * TAU)).clamp(Vector3(-1, -0.62, -0.78), Vector3(1, 0.62, 0.78)), 0.06, Color(1.0, 0.9, 0.66), Color.TRANSPARENT, 6, 3)
	kit_down.blocker(Vector3(x + 0.5, y + 1.0, 4.4), Vector3(0.7, 2.0, 1.6))
	# A call board.
	structure_down.box(Vector3(x + 0.2, y + 1.7, -0.6), Vector3(0.05, 0.9, 1.3), Color("#c7a27a"))
	for note in 5:
		structure_down.box(Vector3(x + 0.24, y + 1.5 + fposmod(float(note) * 0.37, 0.5), -1.0 + float(note) * 0.2), Vector3(0.01, 0.2, 0.16), CREAM.darkened(0.05 * float(note)), Basis(Vector3.RIGHT, (float(note) - 2.0) * 0.08))
	# The costume rail's frame (its costumes swing in theatre_life).
	var rail: Vector3 = world.COSTUME_RAIL
	for end: float in [-1.0, 1.0]:
		structure_down.box(rail + Vector3(0, 0.95, end * 1.25), Vector3(0.06, 1.9, 0.06), BRASS.darkened(0.2))
		structure_down.box(rail + Vector3(0, 0.05, end * 1.25), Vector3(0.5, 0.1, 0.1), BRASS.darkened(0.3))
	structure_down.box(rail + Vector3(0, 1.88, 0), Vector3(0.05, 0.05, 2.6), BRASS)
	kit_down.blocker(rail + Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 2.7))
	# Crates and rope coils between the stand sites.
	var crate: Material = world._coastal_surface(1, 0.7, Color("#b08a5e"))
	for spec: Vector3 in [Vector3(-26.4, -6.4, 1.0), Vector3(-26.5, 15.9, 2.0), Vector3(-26.4, -1.0, 0.0)]:
		var stack := int(spec.z) + 1
		for level in stack:
			var size := 0.8 - 0.12 * float(level)
			kit_down.surface(crate).add(Vector3(spec.x + 0.05 * float(level), y + size * 0.5 + float(level) * 0.72, spec.y), Vector3(size, size, size), Basis(Vector3.UP, 0.2 * float(level) + spec.y))
		kit_down.blocker(Vector3(spec.x, y + 1.0, spec.y), Vector3(0.9, 2.0, 0.9))
	_prop(structure_down, kit_down, "rope_coil", "harbor", Vector3(-26.3, y, -8.6), 0.0, 1.4)
	# The stage door at the south end: a few steps up to a door ajar, light
	# spilling out, and a glowing sign.
	# Kept low: it stands between the camera and the walker at the corridor's end.
	var door := Vector3(rect.get_center().x, y, rect.end.y + 0.3)
	for step in 3:
		structure_down.box(door + Vector3(0, 0.08 + float(step) * 0.16, 0.2 + float(step) * 0.28), Vector3(2.6, 0.16, 0.3), Color("#8a6a4a").darkened(0.06 * float(step)))
	kit_down.glow.box(door + Vector3(0, 0.012, -0.5), Vector3(2.2, 0.01, 1.4), Color(1.0, 0.9, 0.66))
	for side: float in [-1.0, 1.0]:
		structure_down.box(door + Vector3(side * 1.5, 0.5, 0.75), Vector3(0.22, 1.0, 0.22), DARK_WOOD)
		kit_down.glow.ball(door + Vector3(side * 1.5, 1.12, 0.75), 0.13, Color(0.75, 1.0, 0.78), Color.TRANSPARENT, 8, 3)
	var exit: Label3D = world._local_label("出口 · 回到地面", door + Vector3(0, 1.5, 0.8), 22, Color("#b8f0c0"))
	exit.outline_modulate = NIGHT
	exit.pixel_size = 0.0105
	kit_down.blocker(door + Vector3(0, 1.0, 1.1), Vector3(3.4, 2.0, 0.5))

## The house's side walls, low enough to see over, with a doorway from the corridor.
func _build_walls() -> void:
	var wall: Material = world._coastal_surface(4, 1.2, Color("#5a3a4a"))
	var y: float = world.FLOOR
	for piece: Vector2 in [Vector2(-1.6, 4.4), Vector2(7.8, 17.6)]:
		kit_down.surface(wall).add(Vector3(-21.75, y + 1.2, (piece.x + piece.y) * 0.5), Vector3(0.3, 2.4 + 1.6, piece.y - piece.x))
		structure_down.box(Vector3(-21.75, y + 3.25, (piece.x + piece.y) * 0.5), Vector3(0.42, 0.12, piece.y - piece.x), GOLD.darkened(0.25))
	kit_down.surface(wall).add(Vector3(0.75, y + 1.2, 10.5), Vector3(0.3, 4.0, 13.0))
	structure_down.box(Vector3(0.75, y + 3.25, 10.5), Vector3(0.42, 0.12, 13.0), GOLD.darkened(0.25))
	# Wall sconces of the house lights.
	for spec: Array in [[-21.55, 11.4, 1.0], [0.55, 11.4, -1.0]]:
		var at := Vector3(float(spec[0]), y + 2.4, float(spec[1]))
		structure_down.box(at, Vector3(0.12, 0.3, 0.3), BRASS)
		kit_down.glow.ball(at + Vector3(float(spec[2]) * 0.12, 0.2, 0), 0.12, Color(1.0, 0.86, 0.6), Color.TRANSPARENT, 8, 3, 1.3)

## The curtain-call dais: a marble platform with a gold rim and a rounded
## apron, a gold star marking the photo spot, and a big gilt frame behind it.
func _build_bow() -> void:
	var bow: Dictionary = world.pad("bow")
	var rect: Rect2 = bow.rect
	var y: float = bow.y
	structure_down.tube(Vector3(rect.get_center().x, y - 0.06, rect.end.y), rect.size.x * 0.5 + LIP, rect.size.x * 0.5 + LIP, 0.1, Color("#f0dcc0"), 16)
	structure_down.tube(Vector3(rect.get_center().x, (y + world.CAVERN_Y) * 0.5, rect.end.y), rect.size.x * 0.5 + LIP - 0.05, rect.size.x * 0.5 + LIP - 0.05, y - world.CAVERN_Y - 0.12, VELVET_DARK, 16)
	for tassel in 16:
		var angle := PI * float(tassel) / 15.0
		structure_down.box(Vector3(rect.get_center().x + cos(angle) * (rect.size.x * 0.5 + LIP), y - 0.16, rect.end.y + sin(angle) * (rect.size.x * 0.5 + LIP)), Vector3(0.05, 0.16, 0.05), GOLD)
	for side: float in [-1.0, 1.0]:
		structure_down.box(Vector3(rect.get_center().x + side * (rect.size.x * 0.5 + LIP), y - 0.03, rect.get_center().y), Vector3(0.1, 0.1, rect.size.y + 0.4), GOLD)
	var spot: Vector3 = world.PHOTO_SPOT
	_star_flat(structure_down, spot + Vector3(0, 0.008, 0), 0.5, GOLD)
	structure_down.tube(spot + Vector3(0, 0.004, 0), 0.66, 0.66, 0.006, Color("#c88a3a"), 20)
	var label: Label3D = world._local_label("合照位置", spot + Vector3(0, 0.2, 0.7), 18, GOLD)
	label.outline_modulate = NIGHT
	label.pixel_size = 0.0105
	label.name = "TheatrePhotoSpot"
	# The gilt frame the final photo will be taken in front of.
	var frame := Vector3(spot.x, y, rect.position.y + 0.3)
	structure_down.box(frame + Vector3(0, 1.7, -0.05), Vector3(2.6, 2.4, 0.06), Color("#4a2440"))
	for edge: Array in [[Vector3(0, 2.95, 0), Vector3(3.0, 0.2, 0.14)], [Vector3(0, 0.45, 0), Vector3(3.0, 0.2, 0.14)], [Vector3(-1.4, 1.7, 0), Vector3(0.2, 2.7, 0.14)], [Vector3(1.4, 1.7, 0), Vector3(0.2, 2.7, 0.14)]]:
		structure_down.box(frame + (edge[0] as Vector3), edge[1], GOLD)
	for corner: Vector2 in [Vector2(-1.4, 0.45), Vector2(1.4, 0.45), Vector2(-1.4, 2.95), Vector2(1.4, 2.95)]:
		structure_down.ball(frame + Vector3(corner.x, corner.y, 0.06), 0.16, GOLD.lightened(0.1), Color.TRANSPARENT, 8, 3)
	structure_down.ball(frame + Vector3(0, 3.2, 0.04), 0.26, VELVET, Color.TRANSPARENT, 8, 3, 0.8)
	kit_down.blocker(frame + Vector3(0, 1.0, -0.05), Vector3(3.0, 2.0, 0.4))
	_prop(structure_down, kit_down, "pots", "garden", Vector3(rect.end.x - 0.4, y, rect.end.y - 0.5), 0.3, 1.2)
	kit_down.blocker(Vector3(rect.end.x - 0.4, y + 1.0, rect.end.y - 0.5), Vector3(0.7, 2.0, 0.7))

func _build_signs() -> void:
	for spec: Array in SIGNS:
		var at := Vector3(float(spec[1]), 0, float(spec[2]))
		at.y = world.floor_height(Vector2(at.x, at.z), true)
		if is_nan(at.y): at.y = world.FLOOR
		structure_down.box(at + Vector3(0, 2.4, 0), Vector3(1.5, 0.5, 0.06), VELVET_DARK)
		structure_down.box(at + Vector3(0, 2.4, -0.02), Vector3(1.6, 0.58, 0.04), GOLD.darkened(0.15))
		structure_down.box(at + Vector3(-0.6, 3.2, 0), Vector3(0.03, 1.1, 0.03), Color("#8a7a6a"))
		structure_down.box(at + Vector3(0.6, 3.2, 0), Vector3(0.03, 1.1, 0.03), Color("#8a7a6a"))
		var title: Label3D = world._local_label(world._area_label(String(spec[0])), at + Vector3(0, 2.4, 0.06), 22, CREAM)
		title.outline_modulate = NIGHT
		title.pixel_size = 0.0105
		title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		title.name = "TheatreSign_" + String(spec[0])

## Kept stand sites: a booth under a velvet cover tied with gold rope, a
## rolled-up playbill on top, and a "準備中" tag.
func _build_sites() -> void:
	var drapes: Array[Color] = [VELVET, Color("#3f3a6e"), Color("#2f5f5a"), Color("#6e3f6e")]
	var index := 0
	for site: Dictionary in world.open_sites():
		var at: Vector3 = site.stand
		var cloth: Color = drapes[index % drapes.size()]
		var turn := Basis(Vector3.UP, (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.3)
		structure_down.box(at + Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 0.9), NIGHT, turn)
		structure_down.box(at + Vector3(0, 0.52, 0), Vector3(1.28, 0.8, 0.84), cloth, turn)
		structure_down.ball(at + Vector3(0, 0.9, 0), 0.66, cloth, cloth.lightened(0.18), 12, 3, 0.3, true)
		for fold in 4:
			structure_down.box(at + turn * Vector3(-0.48 + float(fold) * 0.32, 0.5, 0.43), Vector3(0.06, 0.76, 0.03), cloth.darkened(0.3), turn)
		structure_down.box(at + turn * Vector3(0, 0.66, 0), Vector3(1.32, 0.05, 0.88), GOLD, turn)
		structure_down.tube(at + turn * Vector3(0.3, 1.04, -0.1), 0.07, 0.07, 0.6, CREAM, 8, turn * Basis(Vector3.BACK, PI * 0.5))
		var tag := at + turn * Vector3(-0.45, 0, 0.62)
		structure_down.box(tag + Vector3(0, 0.36, 0), Vector3(0.05, 0.72, 0.05), DARK_WOOD)
		structure_down.box(tag + Vector3(0, 0.78, 0), Vector3(0.6, 0.3, 0.05), CREAM, turn)
		site_tags.append(world.StandSites.tag(world, tag + Vector3(0, 0.78, 0.08), VELVET_DARK, CREAM))
		kit_down.blocker(at + Vector3(0, 1.0, 0), world.ArcadeStands.FOOTPRINT)
		index += 1

## The theatre's lamps: they join the shared lamp budget but burn whatever the
## hour above; the two house lights dim as the house goes dark.
func _build_lamps() -> void:
	for spec: Array in LAMPS:
		var light: OmniLight3D = kit_down.lamp_light((spec[0] as Vector3) + Vector3(0, world.FLOOR, 0), float(spec[1]), spec[2])
		light.set_meta(&"level", float(spec[3]))
		if bool(spec[4]): light.set_meta(&"house", true)
