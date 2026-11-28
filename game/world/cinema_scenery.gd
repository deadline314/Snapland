extends RefCounted
## Everything in the Starlight Cinema that never moves on its own: the
## sandbars, the floors on them (marble plaza and premiere terrace, the
## screening house's boards and stepped tiers of velvet seats, the backlot's
## dirt street, the plank lane, the black sound stage), the slopes between
## them, the pier from the island gate, the screen's frame, the projector's
## pedestal, the premiere palace and its marquee, the paparazzi, the painted
## flats of the backlot with their braces showing, the stage's backdrop, lamps
## and crane base, the area signs and the covered stand sites. Built once
## through the scenery kit; the film, the beam, the searchlights, the flashes,
## the crane and the rewinding flat are cinema_life.

const Kit := preload("res://game/world/scenery_kit.gd")
const PAINTED := preload("res://game/world/painted_finish.gdshader")
## Floors are drawn a little wider than they can be walked, so feet never hang over water.
const LIP := 0.22
const CREAM := Color("#fff1d6")
const GOLD := Color("#e8b54f")
const BRASS := Color("#c99a45")
const VELVET := Color("#a8243a")
const VELVET_DARK := Color("#6e1626")
const NIGHT := Color("#2a2238")
const INK := Color("#3a2c3e")
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const RAW_WOOD := Color("#c9a273")
const STAGE_BLACK := Color("#35303c")
const MARBLE := Color("#efe4d2")
const SAND_DRY := Color("#dcc596")
const SAND_WET := Color("#a8916a")
const TEAL := Color("#3f8a8c")
const CORAL := Color("#e2795e")
const SKY_PAINT := Color("#8cc6e8")
const TAPES := [Color("#f2c75a"), Color("#e2795e"), Color("#7fc4f2"), Color("#9fd8a4")]
## Lamp posts: x, z on a floor.
const LAMP_POSTS: Array[Vector2] = [Vector2(-0.4, -12.0), Vector2(-15.2, -9.3), Vector2(-4.0, 0.8), Vector2(4.8, 11.2), Vector2(16.8, 10.0), Vector2(4.9, -1.0)]
## Area signposts: area id, x, z.
const SIGNPOSTS := [["carpet", 8.0, -5.9], ["cinema", -0.8, -8.9], ["backlot", 5.0, 7.4], ["stage", 9.4, 4.9]]
## The screen's picture: centre x, bottom height above the floor, width, height.
const SCREEN_WIDTH := 10.0
const SCREEN_HEIGHT := 4.4
const SCREEN_BOTTOM := 1.0
## Where the projector's lens is.
const LENS := Vector3(-9.6, 2.42, 1.86)
## Seat blocks on the tiers, either side of the middle aisle: x from, x to.
const SEAT_BLOCKS := [[-15.2, -10.2], [-8.6, -3.6]]
const SEAT_PITCH := 0.56
## Paparazzi cutouts beside the carpet: x, z, facing yaw.
const PAPARAZZI := [[4.6, -11.5, 0.5], [5.2, -7.3, 2.7], [12.0, -11.0, 0.9], [12.4, -6.6, 2.5]]
## The painted flats along the backlot street: x from, x to, height, look.
const FLATS := [[-12.9, -10.7, 3.0, "saloon"], [-10.6, -8.4, 3.6, "castle"], [-7.4, -3.8, 3.2, "gate"], [-3.6, -1.3, 2.8, "teahouse"], [-1.1, 0.9, 3.1, "shop"]]
const FLAT_Z := 6.55
## Where the stair from the projector deck crosses the line of flats.
const STAIR_X := -5.6

var world: Node3D
var kit: Kit
## Large painted pieces: structures, frames, flats, trim.
var structure := Kit.Sculpt.new()
var painted: ShaderMaterial
var site_tags: Array[Label3D] = []
var floor_body: StaticBody3D
## Where each paparazzo's flash bulb sits (sky-side of their camera).
var flash_spots: Array[Vector3] = []
## The face of every studio lamp; the stage's own start at `stage_lamps_from`.
var lamp_faces: Array[Vector3] = []
var stage_lamps_from := 0

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit

func build() -> void:
	painted = world.material_cache.get("cinema:painted")
	if painted == null:
		painted = ShaderMaterial.new()
		painted.shader = PAINTED
		painted.set_shader_parameter("vertex_tint", true)
		world.material_cache["cinema:painted"] = painted
	floor_body = StaticBody3D.new()
	floor_body.name = "CinemaFloor"
	world.add_child(floor_body)
	_build_water()
	_build_sandbars()
	await world.build_pause()
	_build_floors()
	await world.build_pause()
	_build_links()
	_build_carpet()
	_build_approach()
	await world.build_pause()
	_build_screen()
	_build_seats()
	_build_projector()
	await world.build_pause()
	_build_premiere()
	_build_paparazzi()
	await world.build_pause()
	_build_flats()
	await world.build_pause()
	_build_stage()
	_build_signposts()
	_build_sites()
	await world.build_pause()
	_commit()

## Marquee bulbs, lanterns and lamp bodies glow with the lamps.
func apply_time_of_day(lamp_level: float) -> void:
	kit.set_glow(0.15 + lamp_level * 2.8)

# --- Water and sandbars --------------------------------------------------------

## Standing alone the lot sits in open water past anything the camera shows; on
## the island the lagoon is the island's own sea.
func _build_water() -> void:
	if world.embedded_in != null: return
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 260)
	var empty: Array[Rect2] = []
	var sea: MeshInstance3D = world._mesh(plane, Vector3(0, world.WATER_Y, 0), kit.shore_water(empty, empty))
	sea.name = "CinemaLagoon"
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A sandbar under every floor, plus one for the screen; overlapping banks merge.
func _build_sandbars() -> void:
	var sand: Material = kit.shore_ground("cinema-sand", SAND_DRY, SAND_WET, 1.0)
	var banks: Array[Rect2] = [Rect2(-15.4, -14.0, 12.0, 1.8)]
	for entry: Dictionary in world.PADS:
		banks.append((entry.rect as Rect2).grow(0.55))
	var index := 0
	for bank in banks:
		var mound: MeshInstance3D = kit.mound(bank, world.SAND_Y, 1.0, 1.3, sand, float(index) * 1.37)
		mound.name = "CinemaSandbar%d" % index
		index += 1

# --- Floors ----------------------------------------------------------------------

func _build_floors() -> void:
	var tops := {
		"marble": world._coastal_surface(4, 1.4, MARBLE),
		"boards": world._coastal_surface(1, 1.2, Color("#d9b48a")),
		"tier": world._coastal_surface(4, 1.2, Color("#c9b49a")),
		"street": world._coastal_surface(0, 1.6, Color("#d8b98c")),
		"planks": world._coastal_surface(1, 1.0, Color("#e6c79a")),
		"stage": world._coastal_surface(1, 0.9, Color("#5a5260")),
	}
	for entry: Dictionary in world.PADS:
		var rect: Rect2 = (entry.rect as Rect2).grow(LIP)
		var y: float = entry.y
		var top: Material = tops[entry.top]
		# The walking surface, then a body down to the sand in a matching finish.
		kit.surface(top).add(Vector3(rect.get_center().x, y - 0.05, rect.get_center().y), Vector3(rect.size.x, 0.1, rect.size.y))
		var body_height: float = y - 0.1 - world.SAND_Y + 0.15
		if body_height > 0.12:
			var body: Material = world._coastal_surface(4, 1.3, Color("#b9a184")) if entry.top != "stage" else world._coastal_surface(1, 0.9, Color("#4a3f4c"))
			kit.surface(body).add(Vector3(rect.get_center().x, (y - 0.1 + world.SAND_Y - 0.15) * 0.5, rect.get_center().y), Vector3(rect.size.x - 0.06, body_height, rect.size.y - 0.06))
		_floor_body(entry.rect, y)
		match String(entry.top):
			"marble": _marble_trim(rect, y)
			"stage": _stage_trim(rect, y)
			"tier": _tier_trim(rect, y)

## One box per floor, matching the walkable rectangle.
func _floor_body(rect: Rect2, y: float) -> void:
	var holder := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, 0.3, rect.size.y)
	holder.shape = box
	holder.position = Vector3(rect.get_center().x, y - 0.15, rect.get_center().y)
	floor_body.add_child(holder)

## Gold kerb round the marble, and brass stars set into the plaza.
func _marble_trim(rect: Rect2, y: float) -> void:
	for side: float in [-1.0, 1.0]:
		structure.box(Vector3(rect.get_center().x, y - 0.03, rect.get_center().y + side * rect.size.y * 0.5), Vector3(rect.size.x + 0.08, 0.1, 0.12), GOLD.darkened(0.1))
		structure.box(Vector3(rect.get_center().x + side * rect.size.x * 0.5, y - 0.03, rect.get_center().y), Vector3(0.12, 0.1, rect.size.y + 0.08), GOLD.darkened(0.1))
	if rect.size.x < 9.0: return
	# A walk of brass stars (the plaza is the "walk of fame").
	for index in 5:
		var at := Vector3(rect.position.x + 1.4 + float(index) * 1.6, y + 0.006, rect.end.y - 1.1 - 0.25 * float(index % 2))
		_star_flat(at, 0.3, GOLD)

func _star_flat(at: Vector3, radius: float, color: Color) -> void:
	for point in 5:
		var angle := TAU * float(point) / 5.0 - PI * 0.5
		var tip := at + Vector3(cos(angle), 0, sin(angle)) * radius
		var left := at + Vector3(cos(angle - 0.63), 0, sin(angle - 0.63)) * radius * 0.42
		var right := at + Vector3(cos(angle + 0.63), 0, sin(angle + 0.63)) * radius * 0.42
		_tri_up(at, left, tip, color)
		_tri_up(at, tip, right, color.darkened(0.12))

## The stage's black floor: a pale lip, coloured tape marks and a gaffer-taped cable.
func _stage_trim(rect: Rect2, y: float) -> void:
	for side: float in [-1.0, 1.0]:
		structure.box(Vector3(rect.get_center().x, y - 0.02, rect.get_center().y + side * rect.size.y * 0.5), Vector3(rect.size.x + 0.06, 0.06, 0.1), Color("#d8cfc0"))
	for index in 6:
		var at := Vector3(rect.position.x + 1.6 + fposmod(float(index) * 2.7, rect.size.x - 3.2), y + 0.004, rect.position.y + 2.0 + fposmod(float(index) * 3.3, rect.size.y - 4.0))
		var tone: Color = TAPES[index % TAPES.size()]
		structure.box(at, Vector3(0.5, 0.008, 0.07), tone, Basis(Vector3.UP, 0.78))
		structure.box(at, Vector3(0.5, 0.008, 0.07), tone, Basis(Vector3.UP, -0.78))

## A velvet runner along each tier's walking lane and a brass nosing on its edge.
func _tier_trim(rect: Rect2, y: float) -> void:
	structure.box(Vector3(rect.get_center().x, y - 0.02, rect.end.y - 0.04), Vector3(rect.size.x, 0.07, 0.1), BRASS)

func _tri_up(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	if (c - a).cross(b - a).y > 0.0: structure.tri(a, b, c, color)
	else: structure.tri(a, c, b, color)

# --- Slopes ------------------------------------------------------------------------

func _build_links() -> void:
	for link: Dictionary in world.links():
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		var from := Vector3(a.x, link.ya, a.y)
		var to := Vector3(b.x, link.yb, b.y)
		var along := (to - from).normalized()
		var across := Vector3(along.z, 0, -along.x).normalized()
		var up := along.cross(across)
		var length := from.distance_to(to)
		var width: float = link.width
		# The walker rides a smooth slope; the treads drawn on it read as steps.
		var holder := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 0.3, length)
		holder.shape = box
		holder.transform = Transform3D(Basis(across, up, along), (from + to) * 0.5 - up * 0.15)
		floor_body.add_child(holder)
		match String(link.kind):
			"carpet": _carpet_ramp(from, to, across, width)
			"tiers": _steps(from, to, across, width, 0.4, [Color("#cdb89c"), Color("#c2ac8f")], VELVET_DARK, false)
			"stair":
				_steps(from, to, across, width, 0.42, [RAW_WOOD, RAW_WOOD.darkened(0.08)], DARK_WOOD, true)
				_rails(from, to, across, width, 1.2, DARK_WOOD)
			"gantry": _gantry(from, to, across, width)
			_:
				_steps(from, to, across, width, 0.5, [Color("#e6c79a"), Color("#d9b98a")], DARK_WOOD, true)
				_rails(from, to, across, width, 1.2, DARK_WOOD)

## Steps drawn on a slope: each tread's middle lies on the walking surface.
## `stilts` stands the flight on posts down into the water.
func _steps(from: Vector3, to: Vector3, across: Vector3, width: float, tread: float, tones: Array, riser: Color, stilts: bool) -> void:
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var count := maxi(2, roundi(length / tread))
	var flat := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var yaw := Basis(Vector3.UP, atan2(flat.x, flat.z))
	var step_length := length / float(count)
	var rise := (to.y - from.y) / float(count)
	for index in count:
		var middle := from.lerp(to, (float(index) + 0.5) / float(count))
		structure.box(middle - Vector3(0, 0.1, 0), Vector3(width, 0.2, step_length + 0.02), tones[index % tones.size()], yaw)
		var low_edge := middle - flat * step_length * 0.5 * signf(rise)
		structure.box(low_edge + Vector3(0, -absf(rise) * 0.5 - 0.02, 0), Vector3(width - 0.04, absf(rise) + 0.04, 0.05), riser, yaw)
		if not stilts:
			# Terraces are solid down to the sand.
			var drop: float = middle.y - 0.2 - world.SAND_Y + 0.1
			if drop > 0.05: structure.box(Vector3(middle.x, world.SAND_Y - 0.1 + drop * 0.5, middle.z), Vector3(width, drop, step_length + 0.02), Color("#b9a184"), yaw)
	if not stilts: return
	var span := to - from
	for side: float in [-1.0, 1.0]:
		var edge := across * side * (width * 0.5 + 0.04)
		structure.box((from + to) * 0.5 + edge - Vector3(0, 0.16, 0), Vector3(0.1, 0.26, span.length()), DARK_WOOD, Basis.looking_at(span.normalized(), Vector3.UP))
		for post in maxi(2, int(length / 1.6) + 1):
			var at := from.lerp(to, float(post) / float(maxi(1, int(length / 1.6)))) + edge
			_pile(Vector3(at.x, at.y - 0.25, at.z))

## A timber pile from just under a walkway down into the water.
func _pile(top: Vector3) -> void:
	var bottom: float = world.WATER_Y - 0.5
	var height: float = top.y - bottom
	if height <= 0.1: return
	kit.piles().add(Vector3(top.x, bottom + height * 0.5, top.z), Vector3(0.16, height, 0.16))

## Posts along both sides with a rail between them.
func _rails(from: Vector3, to: Vector3, across: Vector3, width: float, spacing: float, post: Color) -> void:
	var length := from.distance_to(to)
	var count := maxi(1, int(length / spacing))
	var span := to - from
	for side: float in [-1.0, 1.0]:
		var edge := across * side * (width * 0.5 - 0.06)
		for index in count + 1:
			var at := from.lerp(to, float(index) / float(count)) + edge
			kit.posts().add(at + Vector3(0, 0.45, 0), Vector3(0.08, 0.9, 0.08), Basis.IDENTITY, post)
			kit.posts().add(at + Vector3(0, 0.93, 0), Vector3(0.13, 0.07, 0.13), Basis.IDENTITY, BRASS)
		kit.detail.box((from + to) * 0.5 + edge + Vector3(0, 0.86, 0), Vector3(0.06, 0.06, span.length()), post, Basis.looking_at(span.normalized(), Vector3.UP))

## The red-carpet ramp: marble steps under a velvet runner, brass stanchions
## and sagging velvet ropes either side, standing on piles over the water.
func _carpet_ramp(from: Vector3, to: Vector3, across: Vector3, width: float) -> void:
	_steps(from, to, across, width, 0.45, [MARBLE, MARBLE.darkened(0.06)], GOLD.darkened(0.2), true)
	var span := to - from
	var look := Basis.looking_at(span.normalized(), Vector3.UP)
	structure.box((from + to) * 0.5 + Vector3(0, 0.012, 0), Vector3(width * 0.62, 0.025, span.length() + 0.4), VELVET, look)
	_stanchions(from, to, across, width * 0.5 - 0.12)

## Brass posts with velvet ropes between them along both sides of a line.
func _stanchions(from: Vector3, to: Vector3, across: Vector3, half: float) -> void:
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var count := maxi(1, int(length / 1.1))
	for side: float in [-1.0, 1.0]:
		var previous := Vector3.INF
		for index in count + 1:
			var at := from.lerp(to, float(index) / float(count)) + across * side * half
			structure.tube(at + Vector3(0, 0.02, 0), 0.13, 0.15, 0.04, BRASS.darkened(0.2), 8)
			structure.tube(at + Vector3(0, 0.45, 0), 0.035, 0.035, 0.86, BRASS, 6)
			structure.ball(at + Vector3(0, 0.9, 0), 0.07, GOLD, Color.TRANSPARENT, 6, 3)
			if previous.is_finite():
				var middle := (previous + at) * 0.5 + Vector3(0, 0.62, 0)
				for half_rope: Array in [[previous + Vector3(0, 0.82, 0), middle], [middle, at + Vector3(0, 0.82, 0)]]:
					var piece: Vector3 = half_rope[1] - half_rope[0]
					structure.box((half_rope[0] + half_rope[1]) * 0.5, Vector3(0.05, 0.05, piece.length()), VELVET, Basis.looking_at(piece.normalized(), Vector3.UP))
			previous = at

## The lighting gantry: a steel-grey walkway with a lattice of braces under
## it, rails both sides and a row of stage lamps hanging off its west rail.
func _gantry(from: Vector3, to: Vector3, across: Vector3, width: float) -> void:
	var span := to - from
	var look := Basis.looking_at(span.normalized(), Vector3.UP)
	var grey := Color("#6d7380")
	structure.box((from + to) * 0.5 - Vector3(0, 0.05, 0), Vector3(width, 0.1, span.length() + 0.2), Color("#8a8f99"), look)
	var count := int(span.length() / 0.6)
	for index in count:
		var at := from.lerp(to, (float(index) + 0.5) / float(count))
		structure.box(at - Vector3(0, 0.11, 0), Vector3(width + 0.04, 0.04, 0.06), grey, look)
	for side: float in [-1.0, 1.0]:
		var edge := across * side * (width * 0.5)
		structure.box((from + to) * 0.5 + edge - Vector3(0, 0.3, 0), Vector3(0.08, 0.4, span.length()), grey, look)
		structure.box((from + to) * 0.5 + edge + Vector3(0, 0.95, 0), Vector3(0.06, 0.06, span.length()), grey.lightened(0.2), look)
		for post in int(span.length() / 1.0) + 1:
			var at := from.lerp(to, float(post) / floorf(span.length() / 1.0)) + edge
			kit.posts().add(at + Vector3(0, 0.48, 0), Vector3(0.06, 0.95, 0.06), Basis.IDENTITY, grey)
	for leg in int(span.length() / 2.4) + 1:
		var at := from.lerp(to, float(leg) / floorf(span.length() / 2.4))
		for side: float in [-1.0, 1.0]:
			_pile(at + across * side * (width * 0.5 - 0.1) - Vector3(0, 0.15, 0))
	# Little stage lamps clamped to the rail, aimed down at the water.
	for index in 4:
		var at := from.lerp(to, 0.2 + float(index) * 0.2) - across * (width * 0.5 + 0.12) + Vector3(0, 0.7, 0)
		structure.tube(at, 0.11, 0.14, 0.32, Color("#2e2a33"), 8, Basis(Vector3.RIGHT, 0.5))
		kit.glow.ball(at + Vector3(0, -0.12, 0.08), 0.07, Color("#fff2c8"), Color.TRANSPARENT, 6, 3)

## The red carpet itself: from the pier's foot across the plaza to the ramp,
## and from the ramp's top across the terrace to the palace doors, gold-edged.
func _build_carpet() -> void:
	var plaza_y: float = world.GROUND_Y + 0.012
	var terrace_y: float = float(world.pad("premiere").y) + 0.012
	var runs := [
		[Vector3(2.6, plaza_y, -12.5), Vector3(2.6, plaza_y, -9.3)],
		[Vector3(1.8, plaza_y, -9.3), Vector3(8.7, plaza_y, -9.3)],
		[Vector3(11.5, terrace_y, -9.3), Vector3(15.2, terrace_y, -9.3)],
		[Vector3(14.4, terrace_y, -10.1), Vector3(14.4, terrace_y, -12.55)],
	]
	for run: Array in runs:
		var from: Vector3 = run[0]
		var to: Vector3 = run[1]
		var span := to - from
		var look := Basis.looking_at(span.normalized(), Vector3.UP)
		structure.box((from + to) * 0.5, Vector3(1.6, 0.02, span.length()), VELVET, look)
		var across := Vector3(span.z, 0, -span.x).normalized()
		for side: float in [-1.0, 1.0]:
			structure.box((from + to) * 0.5 + across * side * 0.82 + Vector3(0, 0.004, 0), Vector3(0.07, 0.022, span.length()), GOLD, look)

# --- Approach --------------------------------------------------------------------

## The pier from the island gate to the plaza: planks on piles, rope-lit rails
## with a marquee bulb on every post, and a star-studded arch at its foot.
func _build_approach() -> void:
	var path_rect: Rect2 = Rect2(0.6, -22.0, 4.0, 10.2) if world.embedded_in == null else world._site.approach
	var top_y: float = float(world._site.get("approach_y", 0.19)) if world.embedded_in != null else 0.19
	var planks: Material = world._coastal_surface(1, 1.1, Color("#e2c094"))
	var deck := Rect2(path_rect.position + Vector2(0.15, 0.4), path_rect.size - Vector2(0.3, 0.6))
	kit.surface(planks).add(Vector3(deck.get_center().x, top_y - 0.06, deck.get_center().y), Vector3(deck.size.x, 0.12, deck.size.y))
	var count := int(deck.size.y / 1.5)
	for side: float in [-1.0, 1.0]:
		var x := deck.get_center().x + side * (deck.size.x * 0.5 - 0.08)
		for index in count + 1:
			var z := deck.position.y + 0.3 + float(index) * (deck.size.y - 0.6) / float(count)
			_pile(Vector3(x, top_y - 0.1, z))
			kit.posts().add(Vector3(x, top_y + 0.48, z), Vector3(0.1, 0.96, 0.1), Basis.IDENTITY, DARK_WOOD)
			kit.glow.ball(Vector3(x, top_y + 1.04, z), 0.07, Color(1.0, 0.86, 0.5), Color.TRANSPARENT, 6, 3)
		kit.detail.box(Vector3(x, top_y + 0.86, deck.get_center().y), Vector3(0.05, 0.05, deck.size.y - 0.6), Color("#d9c59a"))
	# The arch at the plaza end: two film-reel posts and a strip of film overhead.
	var foot := Vector3(deck.get_center().x, top_y, deck.end.y - 0.4)
	for side: float in [-1.0, 1.0]:
		var post := foot + Vector3(side * (deck.size.x * 0.5 + 0.1), 0, 0)
		structure.box(post + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), NIGHT)
		structure.box(post + Vector3(0, 1.45, 0), Vector3(0.26, 2.3, 0.26), INK)
		_reel(post + Vector3(0, 2.9, 0.0), 0.42)
	var strip_y := top_y + 2.85
	structure.box(foot + Vector3(0, strip_y - top_y, 0), Vector3(deck.size.x + 0.4, 0.5, 0.08), Color("#26222c"))
	for hole in 14:
		var x := -deck.size.x * 0.5 - 0.05 + float(hole) * (deck.size.x + 0.1) / 13.0
		for edge: float in [-0.18, 0.18]:
			kit.glow.box(foot + Vector3(x, strip_y - top_y + edge, 0.05), Vector3(0.1, 0.07, 0.02), Color(1.0, 0.92, 0.7, 1.0))
	var name_sign: Label3D = world._local_label("星光影城", foot + Vector3(0, strip_y - top_y, 0.1), 30, CREAM)
	name_sign.outline_modulate = VELVET_DARK
	name_sign.pixel_size = 0.0105
	name_sign.name = "CinemaPierSign"

## A film reel standing on edge, facing the camera: rim, spokes and hub.
func _reel(at: Vector3, radius: float) -> void:
	structure.tube(at, radius, radius, 0.08, Color("#8d939d"), 16, Basis(Vector3.RIGHT, PI * 0.5))
	for hole in 5:
		var angle := TAU * float(hole) / 5.0
		structure.tube(at + Vector3(cos(angle), sin(angle), 0) * radius * 0.52 + Vector3(0, 0, 0.045), radius * 0.22, radius * 0.22, 0.01, Color("#3a3640"), 10, Basis(Vector3.RIGHT, PI * 0.5))
	structure.tube(at + Vector3(0, 0, 0.05), radius * 0.16, radius * 0.16, 0.04, GOLD, 8, Basis(Vector3.RIGHT, PI * 0.5))

# --- Screening house ---------------------------------------------------------------

## The big screen's frame: two lattice towers, a black masking border, a
## scalloped velvet pelmet with bulbs, and a sandbagged base. The picture
## itself is cinema_life.
func _build_screen() -> void:
	var base: Vector3 = world.SCREEN
	var half := SCREEN_WIDTH * 0.5
	var top := base.y + SCREEN_BOTTOM + SCREEN_HEIGHT
	for side: float in [-1.0, 1.0]:
		var tower := base + Vector3(side * (half + 0.45), 0, 0)
		structure.box(tower + Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.9), NIGHT)
		for leg: float in [-0.3, 0.3]:
			structure.box(tower + Vector3(leg, (top + 0.6 - base.y) * 0.5, 0), Vector3(0.1, top + 0.6 - base.y, 0.1), Color("#4b4552"))
		for rung in 7:
			var y := 0.6 + float(rung) * (top - base.y) / 7.0
			structure.box(tower + Vector3(0, y, 0), Vector3(0.62, 0.06, 0.06), Color("#5a5462"), Basis(Vector3.BACK, 0.55 if rung % 2 == 0 else -0.55))
		structure.ball(tower + Vector3(0, top + 0.7 - base.y, 0), 0.18, GOLD, Color.TRANSPARENT, 8, 4)
	# The black masking round the picture.
	var middle := base + Vector3(0, SCREEN_BOTTOM + SCREEN_HEIGHT * 0.5, -0.06)
	structure.box(middle + Vector3(0, -SCREEN_HEIGHT * 0.5 - 0.18, 0), Vector3(SCREEN_WIDTH + 0.5, 0.36, 0.12), NIGHT)
	structure.box(middle + Vector3(0, SCREEN_HEIGHT * 0.5 + 0.18, 0), Vector3(SCREEN_WIDTH + 0.5, 0.36, 0.12), NIGHT)
	for side: float in [-1.0, 1.0]:
		structure.box(middle + Vector3(side * (half + 0.12), 0, 0), Vector3(0.26, SCREEN_HEIGHT, 0.12), NIGHT)
	# Back of the screen: a timber frame on the bank.
	structure.box(middle + Vector3(0, 0, -0.16), Vector3(SCREEN_WIDTH, SCREEN_HEIGHT, 0.06), Color("#5d5448"))
	for brace in 4:
		var x := -half + 1.2 + float(brace) * (SCREEN_WIDTH - 2.4) / 3.0
		structure.box(base + Vector3(x, (SCREEN_BOTTOM + SCREEN_HEIGHT * 0.5) * 0.5, -0.5), Vector3(0.12, SCREEN_BOTTOM + SCREEN_HEIGHT * 0.5, 0.12), DARK_WOOD, Basis(Vector3.RIGHT, -0.45))
	# A scalloped velvet pelmet across the top with a row of bulbs.
	var pelmet_y := top + 0.36
	structure.box(base + Vector3(0, pelmet_y, 0.02), Vector3(SCREEN_WIDTH + 1.6, 0.5, 0.18), VELVET)
	for swag in 9:
		var x := -half - 0.4 + float(swag) * (SCREEN_WIDTH + 0.8) / 8.0
		structure.ball(base + Vector3(x, pelmet_y - 0.28, 0.08), 0.32, VELVET_DARK, Color.TRANSPARENT, 8, 3, 0.45)
		kit.glow.ball(base + Vector3(x, pelmet_y + 0.12, 0.13), 0.07, Color(1.0, 0.86, 0.5), Color.TRANSPARENT, 6, 3)
	structure.box(base + Vector3(0, pelmet_y + 0.3, 0.02), Vector3(SCREEN_WIDTH + 1.7, 0.1, 0.22), GOLD)
	# Sandbags hold the towers down.
	for side: float in [-1.0, 1.0]:
		for bag in 3:
			var at := base + Vector3(side * (half + 0.45) + (float(bag) - 1.0) * 0.38, 0.12 + 0.18 * float(bag == 1), 0.62)
			structure.ball(at, 0.22, Color("#b59a6e"), Color.TRANSPARENT, 8, 3, 0.55)
	kit.blocker(base + Vector3(0, 1.0, -0.2), Vector3(SCREEN_WIDTH + 2.2, 2.0, 0.6))
	for side: float in [-1.0, 1.0]:
		kit.blocker(base + Vector3(side * (half + 0.45), 1.0, 0.3), Vector3(1.2, 2.0, 1.2))

## Rows of red velvet seats on both tiers, facing the screen, with the aisle
## between the blocks left open; the front of the house has beanbags.
func _build_seats() -> void:
	var seat := Kit.Sculpt.new()
	seat.box(Vector3(0, 0.22, 0), Vector3(0.46, 0.12, 0.44), Color.WHITE)
	seat.box(Vector3(0, 0.5, 0.2), Vector3(0.46, 0.5, 0.1), Color.WHITE)
	seat.ball(Vector3(0, 0.74, 0.2), 0.23, Color.WHITE, Color.TRANSPARENT, 8, 3, 0.35, true)
	for side: float in [-1.0, 1.0]:
		seat.box(Vector3(side * 0.26, 0.3, 0.02), Vector3(0.05, 0.16, 0.46), Color(0.55, 0.45, 0.3))
	seat.box(Vector3(0, 0.08, 0.05), Vector3(0.12, 0.16, 0.12), Color(0.35, 0.3, 0.32))
	var seats := kit.batch("cinema-seats", seat.mesh(), world._vertex_color_material("cinema-seats"))
	for tier_id: String in ["tier1", "tier2"]:
		var tier: Dictionary = world.pad(tier_id)
		var rect: Rect2 = tier.rect
		var z := rect.position.y + 0.42
		for block: Array in SEAT_BLOCKS:
			var from: float = block[0]
			var to: float = block[1]
			var count := int((to - from) / SEAT_PITCH)
			for index in count:
				var x := from + (float(index) + 0.5) * (to - from) / float(count)
				var tone := VELVET.lightened(0.06 * float((index + int(tier.y * 10.0)) % 3))
				seats.add(Vector3(x, tier.y, z), Vector3.ONE, Basis.IDENTITY, tone)
			kit.blocker(Vector3((from + to) * 0.5, tier.y + 1.0, z + 0.02), Vector3(to - from + 0.1, 2.0, 1.0))
	# Beanbags in front of the screen, for the ones who sit right up close.
	var bag_colors: Array[Color] = [CORAL, TEAL, GOLD, Color("#9f7fd0")]
	for index in 4:
		var at := Vector3(-13.0 + float(index) * 2.6, world.GROUND_Y, -11.7 + 0.25 * float(index % 2))
		if index == 0: continue
		structure.ball(at + Vector3(0, 0.2, 0), 0.42, bag_colors[index], Color.TRANSPARENT, 10, 4, 0.55)
		structure.ball(at + Vector3(0.05, 0.34, 0.12), 0.26, bag_colors[index].lightened(0.12), Color.TRANSPARENT, 8, 3, 0.6)
		kit.blocker(at + Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.8))

## The projector on its pedestal under a striped awning; its reels, lamp and
## beam are cinema_life.
func _build_projector() -> void:
	var at: Vector3 = world.PROJECTOR
	structure.box(at + Vector3(0, 0.1, 0), Vector3(1.1, 0.2, 0.9), NIGHT)
	structure.tube(at + Vector3(0, 0.55, 0), 0.24, 0.3, 0.7, Color("#4b4552"), 10)
	structure.box(at + Vector3(0, 1.12, 0), Vector3(0.9, 0.5, 0.6), Color("#3f5f78"))
	structure.box(at + Vector3(0, 1.39, 0), Vector3(0.94, 0.06, 0.64), GOLD.darkened(0.15))
	structure.tube(LENS + Vector3(0, 0, 0.22), 0.12, 0.15, 0.34, Color("#2e2a33"), 10, Basis(Vector3.RIGHT, PI * 0.5))
	kit.glow.ball(LENS, 0.09, Color(1.0, 0.95, 0.8), Color.TRANSPARENT, 8, 4)
	# The awning on four poles.
	var awning := at + Vector3(0, 2.55, 0.15)
	for corner: Vector2 in [Vector2(-0.9, -0.7), Vector2(0.9, -0.7), Vector2(-0.9, 0.8), Vector2(0.9, 0.8)]:
		kit.posts().add(at + Vector3(corner.x, 1.27, corner.y), Vector3(0.07, 2.54, 0.07), Basis.IDENTITY, DARK_WOOD)
	kit.surface(world._coastal_surface(6, 0.8, Color("#f2d6c8"))).add(awning, Vector3(2.1, 0.08, 1.8), Basis(Vector3.RIGHT, -0.12))
	for scallop in 6:
		structure.ball(awning + Vector3(-0.88 + float(scallop) * 0.35, -0.1, 0.94), 0.17, VELVET if scallop % 2 == 0 else CREAM, Color.TRANSPARENT, 6, 3, 0.5, false)
	kit.blocker(at + Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 1.0))
	# A film can stack and a rewind bench beside it.
	for can in 3:
		structure.tube(at + Vector3(1.0, 0.06 + float(can) * 0.1, 0.25), 0.24, 0.24, 0.09, Color("#9aa1ab").darkened(0.05 * float(can)), 12)

# --- Premiere palace -----------------------------------------------------------

## The premiere palace across the north of the terrace: a stepped art-deco
## facade with fluted columns, a marquee of bulbs carrying the lot's name,
## a sunburst crest, gold double doors (the life layer opens them) and a pair
## of searchlights on its shoulders.
func _build_premiere() -> void:
	var door: Vector3 = world.DOORS
	var face_z := door.z - 0.25
	var y: float = door.y
	var wall: Material = world._coastal_surface(4, 1.1, Color("#f3e0c6"))
	# A plinth carries the facade down to the sandbar.
	kit.surface(world._coastal_surface(4, 1.3, Color("#b9a184"))).add(Vector3(door.x, (y + world.SAND_Y - 0.2) * 0.5, face_z - 0.45), Vector3(6.0, y - world.SAND_Y + 0.2, 1.1))
	kit.surface(wall).add(Vector3(door.x, y + 2.3, face_z - 0.4), Vector3(5.6, 4.6, 0.8))
	kit.surface(wall).add(Vector3(door.x, y + 5.0, face_z - 0.4), Vector3(3.2, 0.9, 0.7))
	structure.box(Vector3(door.x, y + 0.12, face_z), Vector3(6.0, 0.24, 0.5), VELVET_DARK)
	# Fluted columns either side of the doors and at the corners.
	for x: float in [-2.6, -1.3, 1.3, 2.6]:
		var foot := Vector3(door.x + x, y, face_z + 0.12)
		structure.box(foot + Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.5), GOLD.darkened(0.2))
		structure.tube(foot + Vector3(0, 2.0, 0), 0.22, 0.2, 3.2, Color("#f8ecd8"), 10)
		for flute in 3:
			structure.box(foot + Vector3(-0.1 + float(flute) * 0.1, 2.0, 0.2), Vector3(0.025, 3.0, 0.02), Color("#d9c6a8"))
		structure.box(foot + Vector3(0, 3.72, 0), Vector3(0.58, 0.24, 0.5), GOLD)
	# Stepped crown and a sunburst over the marquee.
	structure.box(Vector3(door.x, y + 4.72, face_z + 0.02), Vector3(5.8, 0.2, 0.3), GOLD)
	for ray in 9:
		var angle := PI * (0.12 + 0.76 * float(ray) / 8.0)
		var tip := Vector3(door.x + cos(angle) * 1.5, y + 5.0 + sin(angle) * 1.3, face_z + 0.05)
		structure.sheet(Vector3(door.x - 0.16, y + 5.0, face_z + 0.05), Vector3(door.x + 0.16, y + 5.0, face_z + 0.05), tip, GOLD if ray % 2 == 0 else Color("#f6d27a"))
	structure.ball(Vector3(door.x, y + 5.0, face_z + 0.08), 0.36, GOLD.lightened(0.1), Color.TRANSPARENT, 10, 3, 1.0, true)
	# The marquee: a deep box of bulbs with the name on its face.
	var marquee := Vector3(door.x, y + 3.95, face_z + 0.55)
	structure.box(marquee, Vector3(4.2, 0.9, 0.5), NIGHT)
	structure.box(marquee + Vector3(0, 0.5, 0.04), Vector3(4.4, 0.12, 0.6), GOLD)
	structure.box(marquee + Vector3(0, -0.5, 0.04), Vector3(4.4, 0.12, 0.6), GOLD)
	for index in 24:
		var x := -2.05 + float(index) * 4.1 / 23.0
		for edge: float in [-0.36, 0.36]:
			kit.glow.ball(marquee + Vector3(x, edge, 0.27), 0.05, Color(1.0, 0.9, 0.55), Color.TRANSPARENT, 6, 3)
	var title: Label3D = world._local_label("星光影城", marquee + Vector3(0, 0, 0.3), 46, Color("#ffe39a"))
	title.outline_modulate = VELVET_DARK
	title.pixel_size = 0.011
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.name = "CinemaMarquee"
	kit.lamp_light(marquee + Vector3(0, -0.6, 1.4), 7.0, Color("#ffd9a0"))
	# Door frame; the two leaves are the life layer.
	structure.box(Vector3(door.x, y + 1.35, face_z + 0.05), Vector3(2.3, 2.7, 0.2), GOLD.darkened(0.25))
	structure.box(Vector3(door.x, y + 1.3, face_z + 0.1), Vector3(1.9, 2.5, 0.06), Color("#2a1a20"))
	# Potted palms flank the doors.
	for side: float in [-1.0, 1.0]:
		var pot := Vector3(door.x + side * 1.95, y, face_z + 0.75)
		structure.tube(pot + Vector3(0, 0.25, 0), 0.32, 0.24, 0.5, GOLD.darkened(0.1), 10)
		kit.billboard("palm", pot, 2.6)
	kit.blocker(Vector3(door.x, y + 1.0, face_z - 0.3), Vector3(6.4, 2.0, 1.2))
	for side: float in [-1.0, 1.0]:
		kit.blocker(Vector3(door.x + side * 1.95, y + 1.0, face_z + 0.75), Vector3(0.8, 2.0, 0.8))
	# Searchlight drums on the shoulders (their beams are cinema_life).
	for side: float in [-1.0, 1.0]:
		var drum := Vector3(door.x + side * 2.3, y + 4.85, face_z - 0.4)
		structure.box(drum + Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), INK)
		structure.tube(drum + Vector3(0, 0.3, 0), 0.06, 0.06, 0.4, INK, 6)

## Painted paparazzi cutouts on little bases, cameras raised toward the carpet.
func _build_paparazzi() -> void:
	var coats: Array[Color] = [Color("#4b5f8a"), Color("#7a4b6e"), Color("#3f6f5f"), Color("#8a6a3f")]
	for index in PAPARAZZI.size():
		var spec: Array = PAPARAZZI[index]
		var at := Vector3(float(spec[0]), 0, float(spec[1]))
		at.y = world.floor_height(Vector2(at.x, at.z))
		var turn := Basis(Vector3.UP, float(spec[2]))
		var s := structure
		s.box(at + Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.4), NIGHT, turn)
		# A flat painted figure: legs, coat, head, hat and a camera with a flash gun.
		var coat: Color = coats[index % coats.size()]
		for leg: float in [-0.1, 0.1]:
			s.box(at + turn * Vector3(leg, 0.42, 0), Vector3(0.12, 0.64, 0.05), Color("#3a3640"), turn)
		s.box(at + turn * Vector3(0, 1.02, 0), Vector3(0.48, 0.62, 0.06), coat, turn)
		s.ball(at + turn * Vector3(0, 1.48, 0), 0.17, Color("#f2c9a0"), Color.TRANSPARENT, 8, 3, 1.0)
		s.box(at + turn * Vector3(0, 1.62, 0), Vector3(0.38, 0.05, 0.3), coat.darkened(0.3), turn)
		s.box(at + turn * Vector3(0, 1.7, 0), Vector3(0.24, 0.14, 0.22), coat.darkened(0.3), turn)
		s.box(at + turn * Vector3(0.05, 1.42, 0.14), Vector3(0.26, 0.18, 0.14), Color("#2e2a33"), turn)
		s.box(at + turn * Vector3(0.12, 1.66, 0.12), Vector3(0.08, 0.22, 0.08), Color("#6d7380"), turn)
		s.box(at + turn * Vector3(0.12, 1.8, 0.14), Vector3(0.2, 0.12, 0.1), Color("#c9ced6"), turn)
		flash_spots.append(at + turn * Vector3(0.12, 1.8, 0.22))
		kit.blocker(at + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.5))

# --- Backlot ------------------------------------------------------------------------

## The painted flats along the backlot street: fronts painted to look like a
## saloon, a castle tower, a city gate the stair comes down through, a tea
## house and a corner shop. Their timber braces and sandbags stand behind,
## and seen through every window, gap and the half-built tea house.
func _build_flats() -> void:
	for spec: Array in FLATS:
		var from: float = spec[0]
		var to: float = spec[1]
		var height: float = spec[2]
		var look: String = spec[3]
		if look == "castle":
			_flat_braces(from, to, height)
			continue
		_flat(from, to, height, look)
		_flat_braces(from, to, height)
	# A spare flat leans sideways at the west end, its bracing in full view.
	var spare := Vector3(-13.6, world.GROUND_Y, 8.4)
	var turn := Basis(Vector3.UP, 1.25)
	structure.box(spare + turn * Vector3(0, 1.4, 0), Vector3(1.8, 2.6, 0.06), SKY_PAINT, turn)
	structure.box(spare + turn * Vector3(0.2, 1.7, 0.04), Vector3(0.8, 0.5, 0.02), Color("#fff6de"), turn)
	for brace: float in [-0.6, 0.6]:
		structure.box(spare + turn * Vector3(brace, 1.0, -0.55), Vector3(0.08, 2.2, 0.08), RAW_WOOD, turn * Basis(Vector3.RIGHT, -0.45))
	kit.blocker(spare + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 1.4))
	# Odds and ends of a film set along the south kerb.
	var props := Vector3(-3.6, world.GROUND_Y, 11.0)
	_directors_chair(props, 0.3)
	_light_stand(Vector3(-7.6, world.GROUND_Y, 11.1), -0.4)
	for bag in 4:
		structure.ball(Vector3(-0.6 + float(bag % 2) * 0.42, world.GROUND_Y + 0.12 + 0.2 * float(bag / 2), 11.2), 0.22, Color("#b59a6e"), Color.TRANSPARENT, 8, 3, 0.55)
	kit.blocker(props + Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.7))
	kit.blocker(Vector3(-7.6, world.GROUND_Y + 1.0, 11.1), Vector3(0.9, 2.0, 0.9))
	kit.blocker(Vector3(-0.4, world.GROUND_Y + 1.0, 11.2), Vector3(1.1, 2.0, 0.7))

## One flat: a timber frame faced with painted canvas, cut out where its
## windows and doors are, so the braces behind show through.
func _flat(from: float, to: float, height: float, look: String) -> void:
	var base := Vector3((from + to) * 0.5, world.GROUND_Y, FLAT_Z)
	var width := to - from
	var palette := {
		"saloon": [Color("#c98d5a"), Color("#8a5a3a"), Color("#f2d6a0")],
		"gate": [Color("#d9cdb4"), Color("#8f8574"), Color("#e2795e")],
		"teahouse": [Color("#c9584a"), Color("#3f6f5f"), Color("#f2c75a")],
		"shop": [Color("#7fb0c8"), Color("#3f5f78"), Color("#fff1d6")],
	}
	var colors: Array = palette.get(look, palette.saloon)
	var face: Color = colors[0]
	var trim: Color = colors[1]
	var accent: Color = colors[2]
	# Holes in the face: Rect2 in metres from the flat's bottom-left corner.
	var holes: Array[Rect2] = []
	match look:
		"saloon": holes = [Rect2(0.35, 1.5, 0.5, 0.6), Rect2(1.35, 1.5, 0.5, 0.6), Rect2(0.85, 0.0, 0.5, 1.0)]
		"gate": holes = [Rect2(width * 0.5 - 1.1, 0.0, 2.2, 2.6)]
		"teahouse": holes = [Rect2(0.3, 0.9, 0.7, 0.8), Rect2(1.4, 0.9, 0.7, 0.8)]
		"shop": holes = [Rect2(0.3, 1.6, 0.55, 0.55), Rect2(1.15, 1.6, 0.55, 0.55)]
	_holed_panel(base + Vector3(-width * 0.5, 0, 0.02), width, height, holes, face)
	# Painted trim: a cornice, frames round each hole, and a shopfront sign.
	structure.box(base + Vector3(0, height - 0.08, 0.06), Vector3(width + 0.12, 0.16, 0.08), trim)
	if look == "saloon":
		# A stepped false front.
		structure.box(base + Vector3(0, height + 0.3, 0.02), Vector3(width * 0.6, 0.6, 0.06), face)
		structure.box(base + Vector3(0, height + 0.62, 0.06), Vector3(width * 0.64, 0.1, 0.08), trim)
		structure.box(base + Vector3(0, 1.0, 0.25), Vector3(width, 0.08, 0.4), trim)
	elif look == "gate":
		# A rounded arch with keystone over the opening.
		for brick in 9:
			var angle := PI * float(brick) / 8.0
			structure.box(base + Vector3(cos(angle) * 1.25, 2.6 + sin(angle) * 0.5, 0.06), Vector3(0.3, 0.22, 0.1), accent if brick == 4 else trim, Basis(Vector3.BACK, angle - PI * 0.5))
		for course in 5:
			structure.box(base + Vector3(-width * 0.5 + 0.35, 0.4 + float(course) * 0.55, 0.05), Vector3(0.5, 0.04, 0.03), trim)
			structure.box(base + Vector3(width * 0.5 - 0.35, 0.4 + float(course) * 0.55, 0.05), Vector3(0.5, 0.04, 0.03), trim)
	elif look == "teahouse":
		# A swept roof with upturned eaves, half shingled: the rest is bare battens.
		for side: float in [-1.0, 1.0]:
			structure.sheet(base + Vector3(0, height + 0.7, 0.1), base + Vector3(side * (width * 0.5 + 0.4), height + 0.1, 0.1), base + Vector3(side * (width * 0.5 + 0.55), height + 0.35, 0.1), accent)
		structure.box(base + Vector3(-width * 0.2, height + 0.38, 0.08), Vector3(width * 0.6, 0.5, 0.05), trim)
		for batten in 4:
			structure.box(base + Vector3(width * 0.22, height + 0.18 + float(batten) * 0.13, 0.08), Vector3(width * 0.45, 0.035, 0.03), RAW_WOOD)
		for lantern: float in [-0.7, 0.7]:
			kit.glow.ball(base + Vector3(lantern, height - 0.45, 0.25), 0.13, Color(1.0, 0.45, 0.3), Color.TRANSPARENT, 8, 4, 1.25)
	elif look == "shop":
		structure.box(base + Vector3(0, 1.1, 0.22), Vector3(width + 0.1, 0.06, 0.5), accent, Basis(Vector3.RIGHT, 0.25))
		for stripe in 5:
			structure.box(base + Vector3(-width * 0.5 + 0.2 + float(stripe) * (width - 0.4) / 4.0, 1.12, 0.24), Vector3(0.18, 0.07, 0.5), CORAL, Basis(Vector3.RIGHT, 0.25))
	for hole in holes:
		var centre := base + Vector3(-width * 0.5 + hole.get_center().x, hole.get_center().y, 0.06)
		if hole.position.y > 0.01:
			structure.box(centre + Vector3(0, -hole.size.y * 0.5 - 0.04, 0.02), Vector3(hole.size.x + 0.14, 0.07, 0.08), trim)
		structure.box(centre + Vector3(0, hole.size.y * 0.5 + 0.04, 0.0), Vector3(hole.size.x + 0.14, 0.07, 0.06), trim)
	# Timber frame edges visible at the sides.
	for side: float in [-1.0, 1.0]:
		structure.box(base + Vector3(side * width * 0.5, height * 0.5, -0.03), Vector3(0.08, height, 0.1), RAW_WOOD)

## A panel of `width` x `height` facing +Z with rectangular holes, built from strips.
func _holed_panel(corner: Vector3, width: float, height: float, holes: Array[Rect2], color: Color) -> void:
	var xs := [0.0, width]
	var ys := [0.0, height]
	for hole in holes:
		xs.append_array([hole.position.x, hole.end.x])
		ys.append_array([hole.position.y, hole.end.y])
	xs.sort()
	ys.sort()
	for column in xs.size() - 1:
		for row in ys.size() - 1:
			var cell := Rect2(float(xs[column]), float(ys[row]), float(xs[column + 1]) - float(xs[column]), float(ys[row + 1]) - float(ys[row]))
			if cell.size.x < 0.005 or cell.size.y < 0.005: continue
			var open := holes.any(func(hole: Rect2) -> bool: return hole.grow(-0.001).encloses(cell) or hole.has_point(cell.get_center()))
			if open: continue
			var a := corner + Vector3(cell.position.x, cell.position.y, 0)
			var b := corner + Vector3(cell.end.x, cell.position.y, 0)
			var c := corner + Vector3(cell.end.x, cell.end.y, 0)
			var d := corner + Vector3(cell.position.x, cell.end.y, 0)
			structure.quad(a, b, c, d, color)
			structure.quad(a, d, c, b, color.darkened(0.25))

## Raking braces and sandbags behind a flat.
func _flat_braces(from: float, to: float, height: float) -> void:
	var count := maxi(2, int((to - from) / 1.1) + 1)
	for index in count:
		var x := from + 0.15 + float(index) * (to - from - 0.3) / float(count - 1)
		# The projector deck's stair comes down through the gate: keep it clear.
		if absf(x - STAIR_X) < 1.25: continue
		var top := Vector3(x, world.GROUND_Y + height * 0.72, FLAT_Z - 0.05)
		var foot := Vector3(x, world.GROUND_Y, FLAT_Z - 1.05)
		var span := top - foot
		structure.box((top + foot) * 0.5, Vector3(0.07, 0.07, span.length()), RAW_WOOD, Basis.looking_at(span.normalized(), Vector3.UP))
		structure.box(Vector3(x, world.GROUND_Y + 0.5, FLAT_Z - 0.5), Vector3(0.05, 0.05, 0.95), RAW_WOOD.darkened(0.1))
		structure.ball(foot + Vector3(0, 0.12, 0.05), 0.2, Color("#b59a6e"), Color.TRANSPARENT, 8, 3, 0.55)
	if absf((from + to) * 0.5 - STAIR_X) > 1.0:
		structure.box(Vector3((from + to) * 0.5, world.GROUND_Y + height * 0.72, FLAT_Z - 0.06), Vector3(to - from, 0.08, 0.05), RAW_WOOD)

func _directors_chair(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		for depth: float in [-0.18, 0.18]:
			structure.box(at + turn * Vector3(side * 0.24, 0.3, depth), Vector3(0.05, 0.6, 0.05), DARK_WOOD, turn * Basis(Vector3.RIGHT, depth * 1.2))
		structure.box(at + turn * Vector3(side * 0.26, 0.62, 0), Vector3(0.05, 0.05, 0.42), DARK_WOOD, turn)
	structure.box(at + turn * Vector3(0, 0.46, 0), Vector3(0.48, 0.04, 0.38), NIGHT, turn)
	structure.box(at + turn * Vector3(0, 0.82, -0.2), Vector3(0.5, 0.26, 0.03), NIGHT, turn)
	structure.box(at + turn * Vector3(0, 0.82, -0.18), Vector3(0.36, 0.06, 0.01), CREAM, turn)

## A studio lamp on a tripod, aimed along `yaw`; `size` scales the whole stand.
func _light_stand(at: Vector3, yaw: float, size := 1.0) -> void:
	var place := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), at)
	structure.frame = place
	kit.glow.frame = place
	for leg in 3:
		var angle := TAU * float(leg) / 3.0
		var foot := Vector3(cos(angle) * 0.4, 0, sin(angle) * 0.4)
		var head := Vector3(0, 0.9, 0)
		var span := head - foot
		structure.box((foot + head) * 0.5, Vector3(0.04, 0.04, span.length()), Color("#3a3640"), Basis.looking_at(span.normalized(), Vector3.UP))
	structure.tube(Vector3(0, 1.3, 0), 0.03, 0.03, 0.8, Color("#6d7380"), 6)
	structure.tube(Vector3(0, 1.78, 0), 0.22, 0.26, 0.42, Color("#2e2a33"), 10, Basis(Vector3.RIGHT, PI * 0.5 + 0.3))
	kit.glow.ball(Vector3(0, 1.72, 0.22), 0.16, Color(1.0, 0.96, 0.84), Color.TRANSPARENT, 8, 4, 0.4)
	for flap: float in [-1.0, 1.0]:
		structure.box(Vector3(flap * 0.3, 1.8, 0.2), Vector3(0.04, 0.34, 0.24), Color("#2e2a33"), Basis(Vector3.UP, flap * 0.5))
	lamp_faces.append(place * Vector3(0, 1.72, 0.3))
	structure.frame = Transform3D.IDENTITY
	kit.glow.frame = Transform3D.IDENTITY

# --- Sound stage -----------------------------------------------------------------

## A painted moonlit-sea backdrop on its own frame, two big studio lamps on
## stands, the crane's turntable (its arm is cinema_life) and cable reels.
func _build_stage() -> void:
	var stage: Dictionary = world.pad("stage")
	var y: float = stage.y
	var rect: Rect2 = stage.rect
	# Backdrop along the north edge, west of the crane.
	var drop := Vector3(rect.position.x + 2.6, y, rect.position.y - 0.1)
	var night_sky := Color("#2f4a7a")
	structure.box(drop + Vector3(0, 1.6, 0), Vector3(4.4, 3.2, 0.06), night_sky)
	structure.box(drop + Vector3(0, 0.45, 0.04), Vector3(4.4, 0.9, 0.02), Color("#3f6f9a"))
	for wave in 6:
		structure.box(drop + Vector3(-1.9 + float(wave) * 0.76, 0.9, 0.05), Vector3(0.5, 0.05, 0.02), Color("#cfe6f2"))
	structure.tube(drop + Vector3(1.1, 2.4, 0.05), 0.42, 0.42, 0.02, Color("#fff2c8"), 16, Basis(Vector3.RIGHT, PI * 0.5))
	for star in 7:
		structure.ball(drop + Vector3(-1.9 + fposmod(float(star) * 0.83, 3.4), 1.7 + fposmod(float(star) * 0.47, 1.3), 0.05), 0.04, CREAM, Color.TRANSPARENT, 4, 2)
	structure.box(drop + Vector3(0, 3.26, 0), Vector3(4.6, 0.12, 0.14), RAW_WOOD)
	for side: float in [-1.0, 1.0]:
		structure.box(drop + Vector3(side * 2.25, 1.6, -0.06), Vector3(0.1, 3.3, 0.1), RAW_WOOD)
		structure.box(drop + Vector3(side * 1.6, 1.1, -0.7), Vector3(0.07, 0.07, 1.5), RAW_WOOD, Basis(Vector3.RIGHT, 0.95))
	kit.blocker(drop + Vector3(0, 1.0, -0.1), Vector3(4.6, 2.0, 0.4))
	# Studio lamps at the stage's south corners, aimed in at the middle.
	stage_lamps_from = lamp_faces.size()
	_light_stand(Vector3(rect.position.x + 0.7, y, rect.end.y - 0.7), 2.4, 1.6)
	_light_stand(Vector3(rect.end.x - 0.7, y, rect.end.y - 2.2), -2.2, 1.6)
	kit.blocker(Vector3(rect.position.x + 0.7, y + 1.0, rect.end.y - 0.7), Vector3(1.2, 2.0, 1.2))
	kit.blocker(Vector3(rect.end.x - 0.7, y + 1.0, rect.end.y - 2.2), Vector3(1.2, 2.0, 1.2))
	# The studio lamps throw one key light across the stage after dark.
	kit.lamp_light(Vector3(rect.get_center().x - 0.6, y + 2.6, rect.end.y - 3.0), 7.5, Color("#fff0d8"))
	# The crane's turntable and post.
	var crane: Vector3 = world.CRANE
	structure.tube(crane + Vector3(0, 0.1, 0), 0.7, 0.75, 0.2, Color("#3a3640"), 14)
	structure.tube(crane + Vector3(0, 0.24, 0), 0.5, 0.5, 0.08, Color("#e2b54f"), 14)
	structure.tube(crane + Vector3(0, 0.95, 0), 0.14, 0.18, 1.4, Color("#4b4552"), 10)
	kit.blocker(crane + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 1.4))
	# Cable reels and a sandbag by the backdrop.
	structure.tube(Vector3(rect.position.x + 5.4, y + 0.3, rect.position.y + 0.5), 0.3, 0.3, 0.2, Color("#d9a64e"), 12, Basis(Vector3.RIGHT, PI * 0.5))
	structure.tube(Vector3(rect.position.x + 5.4, y + 0.3, rect.position.y + 0.5), 0.12, 0.12, 0.24, Color("#2e2a33"), 8, Basis(Vector3.RIGHT, PI * 0.5))
	kit.blocker(Vector3(rect.position.x + 5.4, y + 1.0, rect.position.y + 0.5), Vector3(0.7, 2.0, 0.4))
	# The skirt round the stage is draped in black cloth with a gold fringe.
	for side: float in [-1.0, 1.0]:
		structure.box(Vector3(rect.get_center().x, y - 0.12, rect.get_center().y + side * (rect.size.y * 0.5 + LIP + 0.02)), Vector3(rect.size.x + 0.4, 0.08, 0.04), GOLD.darkened(0.15))

# --- Signposts, lamps and sites ----------------------------------------------------

## A clapperboard on a post naming each area.
func _build_signposts() -> void:
	for spec: Array in SIGNPOSTS:
		var at := Vector3(float(spec[1]), 0, float(spec[2]))
		at.y = world.floor_height(Vector2(at.x, at.z))
		structure.box(at + Vector3(0, 0.07, 0), Vector3(0.4, 0.14, 0.4), INK)
		structure.tube(at + Vector3(0, 0.95, 0), 0.05, 0.05, 1.7, DARK_WOOD, 6)
		structure.box(at + Vector3(0, 1.95, 0.04), Vector3(1.4, 0.56, 0.06), NIGHT)
		for stripe in 5:
			structure.box(at + Vector3(-0.56 + float(stripe) * 0.28, 2.32, 0.04), Vector3(0.14, 0.16, 0.07), CREAM if stripe % 2 == 0 else NIGHT, Basis(Vector3.BACK, 0.35))
		structure.box(at + Vector3(0, 2.32, 0.0), Vector3(1.44, 0.18, 0.05), INK)
		var title: Label3D = world._local_label(world._area_label(String(spec[0])), at + Vector3(0, 1.95, 0.1), 24, CREAM)
		title.outline_modulate = NIGHT
		title.pixel_size = 0.0115
		title.name = "CinemaSignpost_" + String(spec[0])
		kit.blocker(at + Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45))
	for spot: Vector2 in LAMP_POSTS:
		kit.lamp_post(Vector3(spot.x, world.floor_height(spot), spot.y), 6.5)

## Kept stand sites: a booth under a velvet drape tied with gold rope, a film
## can propped on it and a "準備中" tag.
func _build_sites() -> void:
	var drapes: Array[Color] = [VELVET, Color("#3f3a6e"), Color("#2f5f5a"), Color("#6e3f6e")]
	var index := 0
	for site: Dictionary in world.open_sites():
		var at: Vector3 = site.stand
		var cloth: Color = drapes[index % drapes.size()]
		var turn := Basis(Vector3.UP, (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.3)
		structure.box(at + Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 0.9), NIGHT, turn)
		structure.box(at + Vector3(0, 0.52, 0), Vector3(1.28, 0.8, 0.84), cloth, turn)
		structure.ball(at + Vector3(0, 0.9, 0), 0.66, cloth, cloth.lightened(0.18), 12, 3, 0.3, true)
		# Folds of the drape and a gold rope round its waist.
		for fold in 4:
			structure.box(at + turn * Vector3(-0.48 + float(fold) * 0.32, 0.5, 0.43), Vector3(0.06, 0.76, 0.03), cloth.darkened(0.3), turn)
		structure.box(at + turn * Vector3(0, 0.66, 0), Vector3(1.32, 0.05, 0.88), GOLD, turn)
		structure.ball(at + turn * Vector3(0.66, 0.6, 0.44), 0.07, GOLD, Color.TRANSPARENT, 6, 3)
		# A film can leaning on the corner.
		structure.tube(at + turn * Vector3(0.5, 0.95, -0.2), 0.22, 0.22, 0.08, Color("#9aa1ab"), 12, turn * Basis(Vector3.RIGHT, 1.2))
		var tag := at + turn * Vector3(-0.45, 0, 0.62)
		structure.box(tag + Vector3(0, 0.36, 0), Vector3(0.05, 0.72, 0.05), DARK_WOOD)
		structure.box(tag + Vector3(0, 0.78, 0), Vector3(0.6, 0.3, 0.05), CREAM, turn)
		site_tags.append(world.StandSites.tag(world, tag + Vector3(0, 0.78, 0.08), VELVET_DARK, CREAM))
		kit.blocker(at + Vector3(0, 1.0, 0), world.ArcadeStands.FOOTPRINT)
		index += 1

func _commit() -> void:
	world._mesh(structure.mesh(), Vector3.ZERO, painted).name = "CinemaStructure"
