extends RefCounted
## Everything in the Cloud Park that never moves on its own: the cloud sea and
## the cloud bank round its edge, the decks (a stone plaza, grassy floating
## islands with rock roots, the timber kite terrace, the cloud-top photo deck),
## the ramps, rope bridge and long cloud stair between them, the ferris wheel's
## legs, the balloon's tether, the kite mast and wind rose, the giant photo
## frame, the area signposts, lamps, planting and the covered stand sites.
## Built once through the scenery kit; the wheel, kites, balloon and drifting
## clouds are sky_life.

const Kit := preload("res://game/world/scenery_kit.gd")
const PAINTED := preload("res://game/world/painted_finish.gdshader")
const GRASS := preload("res://game/world/grass.gdshader")
const CLOUD_SEA := preload("res://game/world/sky_cloud_sea.gdshader")
const FLAG := preload("res://game/world/sky_flag.gdshader")
const IslandShape := preload("res://game/world/island_shape.gd")
## The island shares one wind (see wind.gdshaderinc): flags and kites fly downwind.
const WIND := Vector2(0.86, 0.51)
## Decks are drawn a little wider than they can be walked, so feet never hang over air.
const DECK_LIP := 0.22
const SEGMENTS := 40
const WHITE := Color("#fbfdff")
const CREAM := Color("#fff4de")
const SKY := Color("#7cc4ec")
const DEEP := Color("#3d6fb0")
const NAVY := Color("#2f4a7a")
const SUN := Color("#ffd35c")
const CORAL := Color("#ff8a6b")
const MINT := Color("#8fe0c4")
const LILAC := Color("#b9a9f0")
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const EARTH := Color("#80573a")
const ROCK := Color("#8c7563")
const ROCK_DARK := Color("#5f4f47")
const CLOUD_SHADE := Color("#d5e3f6")
const FLAGS := [CORAL, SUN, SKY, MINT, LILAC, DEEP]
## Lamp posts: x, z on a deck.
const LAMP_POSTS: Array[Vector2] = [Vector2(-0.6, -14.2), Vector2(11.8, -7.0), Vector2(-15.0, -4.6), Vector2(-5.4, 3.0), Vector2(-17.6, 13.8), Vector2(8.4, 14.4)]
## Area signposts: area id, x, z.
const SIGNPOSTS := [["wheel", 0.8, -10.6], ["isles", -9.8, -4.4], ["kites", -14.6, 9.8], ["photo", 16.2, 11.0]]
## Planting on the decks: kind, x, z, height.
const PLANTS := [["pine", -18.2, 3.0, 3.2], ["shrub", -18.6, 0.8, 1.1], ["shrub", -14.4, -7.0, 1.2]]
## The ferris wheel's hub above its ground, and the radius the cabins hang from.
const HUB_HEIGHT := 6.2
const WHEEL_RADIUS := 5.0
## Kite reels along the terrace's south rail: x.
const REELS := [-17.0, -14.6, -9.6, -7.2]

var world: Node3D
var kit: Kit
## Large painted pieces: rock roots, rails, treads, legs, the frame.
var structure := Kit.Sculpt.new()
## Soft cloud puffs that never move: the bank round the sea, the skirts under decks.
var puffs := Kit.Sculpt.new()
var painted: ShaderMaterial
var cloud_sea: ShaderMaterial
var cloud_puff: StandardMaterial3D
var flag_material: ShaderMaterial
var site_tags: Array[Label3D] = []
var floor_body: StaticBody3D
## Where the life layer hangs the kites' strings: one reel per kite.
var kite_reels: Array[Vector3] = []

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit

func build() -> void:
	painted = world.material_cache.get("sky:painted")
	if painted == null:
		painted = ShaderMaterial.new()
		painted.shader = PAINTED
		painted.set_shader_parameter("vertex_tint", true)
		world.material_cache["sky:painted"] = painted
	cloud_puff = puff_material(world)
	flag_material = world.material_cache.get("sky:flag")
	if flag_material == null:
		flag_material = ShaderMaterial.new()
		flag_material.shader = FLAG
		world.material_cache["sky:flag"] = flag_material
		world.component_motion.register_shader(flag_material)
	floor_body = StaticBody3D.new()
	floor_body.name = "SkyFloor"
	world.add_child(floor_body)
	_build_cloud_sea()
	await world.build_pause()
	_build_decks()
	await world.build_pause()
	_build_links()
	await world.build_pause()
	_build_approach()
	_build_wheel_base()
	await world.build_pause()
	_build_balloon_tether()
	_build_kite_terrace()
	await world.build_pause()
	_build_photo_point()
	_build_signposts()
	_build_sites()
	_build_planting()
	_build_shore()
	await world.build_pause()
	_commit()

## Lanterns, the frame's bulbs and the marquee light up with the lamps.
func apply_time_of_day(lamp_level: float) -> void:
	kit.set_glow(0.1 + lamp_level * 2.6)

## Soft white puffs, lit from above with a cool underside; shared with sky_life.
static func puff_material(owner: Node3D) -> StandardMaterial3D:
	var material: StandardMaterial3D = owner.material_cache.get("sky:cloud-puff")
	if material != null: return material
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.rim_enabled = true
	material.rim = 0.45
	material.rim_tint = 0.2
	material.backlight_enabled = true
	material.backlight = Color(0.32, 0.34, 0.4)
	owner.material_cache["sky:cloud-puff"] = material
	return material

## One cloud: a cluster of squashed balls, white on top and blue-grey below.
static func cloud(s: Kit.Sculpt, at: Vector3, size: float, seed_value: float) -> void:
	var lobes := 4 + int(fposmod(seed_value * 7.3, 1.0) * 3.0)
	for lobe in lobes:
		var t := float(lobe) / float(lobes - 1) - 0.5
		var lift := (1.0 - absf(t) * 2.0) * 0.35 + fposmod(seed_value * 3.1 + float(lobe) * 0.37, 1.0) * 0.18
		var radius := size * (0.42 + (1.0 - absf(t) * 2.0) * 0.28 + fposmod(seed_value * 5.7 + float(lobe) * 0.61, 1.0) * 0.12)
		var spot := at + Vector3(t * size * 1.8, size * lift, (fposmod(seed_value + float(lobe) * 0.29, 1.0) - 0.5) * size * 0.5)
		s.ball(spot, radius, WHITE, Color.TRANSPARENT, 9, 4, 0.72)
		# A flat, shaded belly so the cloud reads lit from above.
		s.ball(spot - Vector3(0, radius * 0.38, 0), radius * 0.92, CLOUD_SHADE, Color.TRANSPARENT, 9, 2, 0.32)

# --- Cloud sea -----------------------------------------------------------------

func _build_cloud_sea() -> void:
	cloud_sea = world.material_cache.get("sky:cloud-sea")
	if cloud_sea == null:
		cloud_sea = ShaderMaterial.new()
		cloud_sea.shader = CLOUD_SEA
		world.material_cache["sky:cloud-sea"] = cloud_sea
		world.component_motion.register_shader(cloud_sea)
	var bounds: Rect2 = world.BOUNDS
	var plane := PlaneMesh.new()
	var standalone: bool = world.embedded_in == null
	# Standing alone the park floats in clouds past anything the camera shows.
	plane.size = Vector2(260, 260) if standalone else bounds.size + Vector2(2, 2)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	cloud_sea.set_shader_parameter("bounded", not standalone)
	cloud_sea.set_shader_parameter("bounds", Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
	var sea: MeshInstance3D = world._mesh(plane, Vector3(bounds.get_center().x, world.CLOUD_Y, bounds.get_center().y), cloud_sea)
	sea.name = "SkyCloudSea"
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if standalone: return
	# A bank of fat clouds rolls along the edge, half on the island lawn, so the
	# cloud sea never meets the grass at a line.
	var edge := bounds.grow(-0.6)
	var perimeter := 2.0 * (edge.size.x + edge.size.y)
	var count := int(perimeter / 2.3)
	for index in count:
		var along := float(index) / float(count) * perimeter
		var spot := _on_rect(edge, along)
		var seed_value := fposmod(float(index) * 0.618, 1.0)
		if not _clear_of_approach(Vector2(spot.x, spot.z), 2.2): continue
		cloud(puffs, spot + Vector3(0, world.CLOUD_Y + 0.05, 0), 0.75 + seed_value * 0.5, seed_value)

func _on_rect(rect: Rect2, along: float) -> Vector3:
	var top := rect.size.x
	var right := top + rect.size.y
	var bottom := right + rect.size.x
	if along < top: return Vector3(rect.position.x + along, 0, rect.position.y)
	if along < right: return Vector3(rect.end.x, 0, rect.position.y + along - top)
	if along < bottom: return Vector3(rect.end.x - (along - right), 0, rect.end.y)
	return Vector3(rect.position.x, 0, rect.end.y - (along - bottom))

func _clear_of_approach(spot: Vector2, margin: float) -> bool:
	var approach: Rect2 = world._site.approach if world.embedded_in != null else Rect2(-6.2, -30.4, 4.4, 14.8)
	return not approach.grow(margin).has_point(spot)

# --- Decks ---------------------------------------------------------------------

func _outline(entry: Dictionary, grow: float, seed_value: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	var reach: Vector2 = entry.radius
	for index in SEGMENTS:
		var angle := TAU * float(index) / float(SEGMENTS)
		var wobble := 0.08 * (sin(angle * 3.0 + seed_value) * 0.6 + sin(angle * 5.0 + seed_value * 2.1) * 0.4 + 1.0)
		ring.append((entry.centre as Vector2) + Vector2(cos(angle) * (reach.x + grow + wobble), sin(angle) * (reach.y + grow + wobble)))
	return ring

func _build_decks() -> void:
	var grass: ShaderMaterial = world.material_cache.get("sky:isle-grass")
	if grass == null:
		grass = ShaderMaterial.new()
		grass.shader = GRASS
		grass.set_shader_parameter("shade", Color("#f2fff0"))
		world.material_cache["sky:isle-grass"] = grass
	var tops := {
		"plaza": world._coastal_surface(4, 1.6, Color("#f4dcb6")),
		"isle": grass,
		"deck": world._coastal_surface(1, 1.4, Color("#ecd2a6")),
		"cloud": world._coastal_surface(5, 1.2, Color("#f0f7ff")),
	}
	var tools := {}
	for index in world.PADS.size():
		var entry: Dictionary = world.PADS[index]
		var kind: String = entry.top
		if not tools.has(kind):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[kind] = tool
		var y: float = entry.y
		var ring := _outline(entry, DECK_LIP, float(index) * 1.7)
		var centre: Vector2 = entry.centre
		var surface: SurfaceTool = tools[kind]
		for step in ring.size():
			var next := ring[(step + 1) % ring.size()]
			for corner: Vector2 in [centre, ring[step], next]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(corner.x, y, corner.y))
			# Plaza, decking and cloud tops carry their own surface down the edge.
			if kind != "isle":
				var drop := 0.24
				for corner: Vector3 in [Vector3(ring[step].x, y, ring[step].y), Vector3(next.x, y - drop, next.y), Vector3(next.x, y, next.y),
						Vector3(ring[step].x, y, ring[step].y), Vector3(ring[step].x, y - drop, ring[step].y), Vector3(next.x, y - drop, next.y)]:
					var out := Vector3(corner.x - centre.x, 0, corner.z - centre.y).normalized()
					surface.set_normal(out)
					surface.add_vertex(corner)
		_deck_body(entry)
		match kind:
			"plaza": _kerb(entry, ring, y)
			"isle": _roots(entry, ring, y, 0.9 + y * 0.5, float(index))
			"deck":
				_roots(entry, _outline(entry, DECK_LIP - 0.12, float(index) * 1.7), y - 0.24, 1.5, float(index))
				_deck_trim(ring, y)
			"cloud": _cloud_sides(entry, ring, y)
	for kind: String in tools:
		var deck: MeshInstance3D = world._mesh((tools[kind] as SurfaceTool).commit(), Vector3.ZERO, tops[kind])
		deck.name = "SkyDeck_" + kind

## One convex body per deck, matching the walkable ellipse.
func _deck_body(entry: Dictionary) -> void:
	var points := PackedVector3Array()
	var reach: Vector2 = entry.radius
	for index in 24:
		var angle := TAU * float(index) / 24.0
		var at := (entry.centre as Vector2) + Vector2(cos(angle) * reach.x, sin(angle) * reach.y)
		points.append(Vector3(at.x, entry.y, at.y))
		points.append(Vector3(at.x, float(entry.y) - 0.3, at.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var holder := CollisionShape3D.new()
	holder.shape = shape
	floor_body.add_child(holder)

## A pale stone kerb round the plaza where it meets the cloud sea.
func _kerb(entry: Dictionary, ring: PackedVector2Array, y: float) -> void:
	for index in ring.size():
		var from := ring[index]
		var to := ring[(index + 1) % ring.size()]
		var middle := (from + to) * 0.5
		# Where two plaza decks run into each other the kerb gives way.
		if world.PADS.any(func(other: Dictionary) -> bool: return other.id != entry.id and is_equal_approx(other.y, y) and world.in_pad(other, middle, -0.3)): continue
		var along := to - from
		var turn := Basis(Vector3.UP, -atan2(along.y, along.x))
		structure.box(Vector3(middle.x, y - 0.05, middle.y), Vector3(along.length() + 0.06, 0.16, 0.34), Color("#d8d0bf") if index % 3 else Color("#cfc5b1"), turn)

## A floating island's underside: a soil band, then rock tapering to a point,
## hugged by a skirt of cloud.
func _roots(entry: Dictionary, ring: PackedVector2Array, y: float, depth: float, salt: float) -> void:
	var centre: Vector2 = entry.centre
	var levels := [[0.0, 1.0, EARTH], [0.3, 0.97, EARTH.darkened(0.18)], [0.6, 0.84, ROCK], [0.86, 0.52, ROCK_DARK]]
	var loops: Array[PackedVector3Array] = []
	for level: Array in levels:
		var loop := PackedVector3Array()
		for index in ring.size():
			var point := ring[index]
			var jag := 1.0 + (0.12 * sin(float(index) * 2.3 + salt) if float(level[0]) > 0.3 else 0.0)
			var spot := centre + (point - centre) * float(level[1]) * jag
			loop.append(Vector3(spot.x, y - depth * float(level[0]), spot.y))
		loops.append(loop)
	var tip := Vector3(centre.x + sin(salt) * 0.3, y - depth, centre.y + cos(salt) * 0.2)
	for band in loops.size():
		var upper := loops[band]
		var tone: Color = levels[band][2]
		for index in upper.size():
			var next := (index + 1) % upper.size()
			var shade := tone.darkened(0.06 * float(index % 3))
			if band + 1 < loops.size():
				var lower := loops[band + 1]
				_quad_out(upper[index], upper[next], lower[next], lower[index], Vector3(centre.x, y - depth * 0.5, centre.y), shade)
			else:
				_tri_away(upper[index], upper[next], tip, Vector3(centre.x, y, centre.y), shade)
	# Grass curls over the lip of the island.
	if entry.top == "isle":
		for index in range(0, ring.size(), 2):
			var point := ring[index]
			var out := (point - centre).normalized()
			structure.box(Vector3(point.x, y - 0.03, point.y), Vector3(0.5, 0.08, 0.16), Color("#5f9a52") if index % 4 else Color("#6fae5a"), Basis(Vector3.UP, -atan2(out.y, out.x) + PI * 0.5))
	for index in 5:
		var angle := TAU * float(index) / 5.0 + salt
		var spot := centre + Vector2(cos(angle) * (entry.radius as Vector2).x * 0.55, sin(angle) * (entry.radius as Vector2).y * 0.55)
		var size := 0.55 + 0.2 * fposmod(salt * 0.37 + float(index) * 0.61, 1.0)
		# The skirt hugs the rock below the deck and never shows through it.
		var low := maxf(y - depth * 0.85, world.CLOUD_Y + 0.12)
		if low > y - 0.4 - size * 0.95: continue
		cloud(puffs, Vector3(spot.x, low, spot.y), size, fposmod(salt + float(index) * 0.13, 1.0))

## Timber decking edged with a painted rim board and a rope rail on its posts.
func _deck_trim(ring: PackedVector2Array, y: float) -> void:
	for index in ring.size():
		var from := ring[index]
		var to := ring[(index + 1) % ring.size()]
		var middle := (from + to) * 0.5
		var along := to - from
		structure.box(Vector3(middle.x, y - 0.12, middle.y), Vector3(along.length() + 0.05, 0.22, 0.12), SKY if index % 2 else DEEP, Basis(Vector3.UP, -atan2(along.y, along.x)))

## The photo deck stands on a mound of cloud.
func _cloud_sides(entry: Dictionary, ring: PackedVector2Array, y: float) -> void:
	var centre: Vector2 = entry.centre
	for index in range(0, ring.size(), 2):
		var point := ring[index]
		var out := (point - centre).normalized()
		for tier in 3:
			var spot := point + out * (0.15 - float(tier) * 0.25)
			var size := 0.62 + 0.22 * float(tier) + 0.15 * fposmod(float(index) * 0.618, 1.0)
			puffs.ball(Vector3(spot.x, y - 0.35 - float(tier) * 0.72, spot.y), size, WHITE if tier < 2 else CLOUD_SHADE, Color.TRANSPARENT, 9, 4, 0.78)

func _quad_out(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
	_tri_away(a, b, c, inside, color)
	_tri_away(a, c, d, inside, color)

## A triangle turned to face away from `inside`.
func _tri_away(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
	var middle := (a + b + c) / 3.0
	if (c - a).cross(b - a).dot(middle - inside) > 0.0: structure.tri(a, b, c, color)
	else: structure.tri(a, c, b, color)

# --- Ramps, bridge and stair ---------------------------------------------------

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
		var frame := Basis(across, up, along)
		# The walker rides a smooth slope; the treads drawn on it read as steps.
		var holder := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 0.3, length)
		holder.shape = box
		holder.transform = Transform3D(frame, (from + to) * 0.5 - up * 0.15)
		floor_body.add_child(holder)
		match String(link.kind):
			"bridge": _rope_bridge(from, to, across, width)
			"stair": _cloud_stair(from, to, across, width)
			_: _ramp(from, to, across, width)

## A stone ramp of shallow steps between two decks, with rope rails.
func _ramp(from: Vector3, to: Vector3, across: Vector3, width: float) -> void:
	_steps(from, to, across, width, 0.5, [Color("#efe7d6"), Color("#e2d8c3")], SKY)
	_rails(from, to, across, width, 1.1, WHITE, true)

## Planks on ropes, slung between two islands at the same height.
func _rope_bridge(from: Vector3, to: Vector3, across: Vector3, width: float) -> void:
	var length := from.distance_to(to)
	var count := int(length / 0.32)
	var along := (to - from) / length
	var yaw := Basis(Vector3.UP, atan2(along.x, along.z))
	for index in count + 1:
		var t := (float(index) + 0.5) / float(count + 1)
		var sag := 0.05 * sin(t * PI)
		var at := from.lerp(to, t) - Vector3(0, 0.05 + sag, 0)
		structure.box(at, Vector3(width - 0.1, 0.08, 0.26), WOOD if index % 2 else WOOD.lightened(0.12), yaw * Basis(Vector3.BACK, (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.06))
	for side: float in [-1.0, 1.0]:
		structure.box((from + to) * 0.5 + across * side * (width * 0.5 - 0.08) - Vector3(0, 0.1, 0), Vector3(0.06, 0.06, length), DARK_WOOD, yaw)
	_rails(from, to, across, width, 0.9, CREAM, false)

## The long cloud stair from the photo deck down to the wheel: white treads
## with sky-blue risers, railings strung with pennants, and posts standing in
## the cloud sea below.
func _cloud_stair(from: Vector3, to: Vector3, across: Vector3, width: float) -> void:
	_steps(from, to, across, width, 0.72, [WHITE, Color("#e8f2fa")], DEEP)
	_rails(from, to, across, width, 1.5, WHITE, true)
	var length := from.distance_to(to)
	var count := int(length / 3.0)
	for index in range(1, count):
		var t := float(index) / float(count)
		var at := from.lerp(to, t)
		for side: float in [-1.0, 1.0]:
			var foot := at + across * side * (width * 0.5 - 0.2)
			var height: float = foot.y - world.CLOUD_Y
			structure.tube(Vector3(foot.x, world.CLOUD_Y + height * 0.5 - 0.1, foot.z), 0.11, 0.13, height, DEEP, 8)
		cloud(puffs, Vector3(at.x, world.CLOUD_Y + 0.1, at.z), 0.8, fposmod(float(index) * 0.37, 1.0))
	# Pennants along the high rail.
	for side: float in [-1.0, 1.0]:
		var top := Vector3(0, 1.05, 0) + across * side * (width * 0.5 - 0.06)
		kit.bunting(from + top + Vector3(0, 0.4, 0), from.lerp(to, 0.5) + top + Vector3(0, 0.4, 0), [CORAL, SUN, SKY, MINT], 0.25)
		kit.bunting(from.lerp(to, 0.5) + top + Vector3(0, 0.4, 0), to + top + Vector3(0, 0.4, 0), [LILAC, CORAL, SUN, SKY], 0.25)

## Steps drawn on a slope: each tread's middle lies on the walking surface.
func _steps(from: Vector3, to: Vector3, across: Vector3, width: float, tread: float, tones: Array, riser: Color) -> void:
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var count := maxi(2, roundi(length / tread))
	var flat := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var yaw := Basis(Vector3.UP, atan2(flat.x, flat.z))
	var step_length := length / float(count)
	var rise := (to.y - from.y) / float(count)
	for index in count:
		var middle := from.lerp(to, (float(index) + 0.5) / float(count))
		var tone: Color = tones[index % tones.size()]
		structure.box(middle - Vector3(0, 0.1, 0), Vector3(width, 0.2, step_length + 0.02), tone, yaw)
		# The riser on the downhill edge, as a coloured band.
		var low_edge := middle - flat * step_length * 0.5 * signf(rise) if not is_zero_approx(rise) else middle
		if not is_zero_approx(rise):
			structure.box(low_edge + Vector3(0, -absf(rise) * 0.5 - 0.02, 0), Vector3(width - 0.04, absf(rise) + 0.04, 0.05), riser, yaw)
	# Side stringers carry the treads.
	for side: float in [-1.0, 1.0]:
		var edge := across * side * (width * 0.5 + 0.04)
		var span := to - from
		structure.box((from + to) * 0.5 + edge - Vector3(0, 0.16, 0), Vector3(0.1, 0.26, span.length()), DEEP, Basis.looking_at(span.normalized(), Vector3.UP))

## Posts along both sides with a rope (or painted rail) between them.
func _rails(from: Vector3, to: Vector3, across: Vector3, width: float, spacing: float, post: Color, painted_rail: bool) -> void:
	var length := from.distance_to(to)
	var count := maxi(1, int(length / spacing))
	var span := to - from
	for side: float in [-1.0, 1.0]:
		var edge := across * side * (width * 0.5 - 0.06)
		for index in count + 1:
			var at := from.lerp(to, float(index) / float(count)) + edge
			kit.posts().add(at + Vector3(0, 0.45, 0), Vector3(0.09, 0.9, 0.09), Basis.IDENTITY, post)
			kit.posts().add(at + Vector3(0, 0.93, 0), Vector3(0.16, 0.08, 0.16), Basis.IDENTITY, SUN)
		var rail_from := from + edge + Vector3(0, 0.86, 0)
		var rail_to := to + edge + Vector3(0, 0.86, 0)
		if painted_rail:
			kit.detail.box((rail_from + rail_to) * 0.5, Vector3(0.07, 0.07, span.length()), SKY, Basis.looking_at(span.normalized(), Vector3.UP))
		else:
			var middle := (rail_from + rail_to) * 0.5 - Vector3(0, 0.12, 0)
			for half: Array in [[rail_from, middle], [middle, rail_to]]:
				var piece: Vector3 = half[1] - half[0]
				kit.detail.box((half[0] + half[1]) * 0.5, Vector3(0.04, 0.04, piece.length()), Color("#d9c59a"), Basis.looking_at(piece.normalized(), Vector3.UP))

# --- Approach ------------------------------------------------------------------

## The cloud bridge from the island gate to the plaza: planks on a pale stone
## causeway, rope rails, and little wind flags on every other post.
func _build_approach() -> void:
	var path_rect: Rect2 = Rect2(-6.2, -30.4, 4.4, 14.8) if world.embedded_in == null else world._site.approach
	var stone: Material = world._coastal_surface(1, 1.3, Color("#eadcc0"))
	kit.mound(Rect2(path_rect.position, path_rect.size - Vector2(0, 1.0)), 0.18, 0.06, 0.5, stone, 2.1).name = "SkyCloudBridge"
	var count := int(path_rect.size.y / 1.6)
	for side: float in [-1.0, 1.0]:
		var x := path_rect.get_center().x + side * (path_rect.size.x * 0.5 + 0.05)
		for index in count + 1:
			var z := path_rect.position.y + 0.6 + float(index) * (path_rect.size.y - 1.6) / float(count)
			kit.posts().add(Vector3(x, 0.6, z), Vector3(0.1, 0.9, 0.1), Basis.IDENTITY, WHITE)
			kit.posts().add(Vector3(x, 1.08, z), Vector3(0.17, 0.08, 0.17), Basis.IDENTITY, SUN)
			if index % 2 == 0: _wind_flag(Vector3(x, 1.12, z), 0.55, FLAGS[(index + int(side > 0.0)) % FLAGS.size()])
		var rail_from := Vector3(x, 0.98, path_rect.position.y + 0.6)
		var rail_to := Vector3(x, 0.98, path_rect.end.y - 1.0)
		kit.detail.box((rail_from + rail_to) * 0.5, Vector3(0.05, 0.05, rail_to.z - rail_from.z), Color("#d9c59a"))
	# Puffs of cloud drift in round the bridge where it crosses into the park.
	for index in 6:
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := -18.6 + float(index / 2) * 1.4
		cloud(puffs, Vector3(path_rect.get_center().x + side * (path_rect.size.x * 0.5 + 0.9), world.CLOUD_Y + 0.05, z), 0.7, fposmod(float(index) * 0.41, 1.0))

## A small flag on a staff, flying downwind; its flutter grows in the island's gusts.
func _wind_flag(at: Vector3, size: float, color: Color) -> void:
	kit.posts().add(at + Vector3(0, size * 0.6, 0), Vector3(0.035, size * 1.2, 0.035), Basis.IDENTITY, DARK_WOOD)
	var flags := kit.batch("sky-flags", _flag_mesh(), flag_material)
	flags.add(at + Vector3(0, size * 1.18, 0), Vector3(size, size * 0.62, 1.0), _downwind(), color)

func _flag_mesh() -> ArrayMesh:
	return Kit.cloth_mesh(Vector2(1.0, 1.0), 5, 2, false)

## Turns +X to point the way the wind blows.
static func _downwind() -> Basis:
	return Basis(Vector3.UP, -atan2(WIND.y, WIND.x))

# --- Ferris wheel's frame ------------------------------------------------------

## Two splayed A-frames either side of the wheel, concrete feet, the axle and a
## little boarding stage. The wheel itself turns in sky_life.
func _build_wheel_base() -> void:
	var hub: Vector3 = world.WHEEL + Vector3(0, HUB_HEIGHT, 0)
	for depth: float in [-0.75, 0.75]:
		var braces: Array[Vector3] = []
		for side: float in [-1.0, 1.0]:
			var foot: Vector3 = world.WHEEL + Vector3(side * 3.3, 0, depth * 1.3)
			var top := hub + Vector3(side * 0.25, 0, depth)
			var span := top - foot
			structure.tube((foot + top) * 0.5, 0.2, 0.16, span.length(), WHITE, 8, _lean(span))
			structure.box(foot + Vector3(0, 0.12, 0), Vector3(0.8, 0.3, 0.8), Color("#d7d2c8"))
			braces.append(foot.lerp(top, 0.42))
		# A sky-blue cross brace between each pair of legs.
		structure.box((braces[0] + braces[1]) * 0.5, Vector3(braces[0].distance_to(braces[1]), 0.14, 0.14), SKY)
		structure.tube(hub + Vector3(0, 0, depth), 0.32, 0.32, 0.3, DEEP, 12, Basis(Vector3.RIGHT, PI * 0.5))
	structure.tube(hub, 0.16, 0.16, 1.9, SUN.darkened(0.2), 10, Basis(Vector3.RIGHT, PI * 0.5))
	# The boarding stage: a round step painted with a sun, under the lowest cabin.
	var stage: Vector3 = world.WHEEL + Vector3(0, 0, 1.1)
	structure.tube(stage + Vector3(0, 0.1, 0), 1.6, 1.7, 0.2, Color("#e9e2d2"), 16, Basis.from_scale(Vector3(1.0, 1.0, 0.6)))
	structure.tube(stage + Vector3(0, 0.205, 0), 1.2, 1.2, 0.01, SUN, 16, Basis.from_scale(Vector3(1.0, 1.0, 0.6)))
	kit.blocker(world.WHEEL + Vector3(0, 1.0, 0.0), Vector3(8.0, 2.0, 2.6))
	kit.blocker(stage + Vector3(0, 1.0, 0.1), Vector3(3.2, 2.0, 1.4))
	# A marquee of bulbs round the stage.
	for index in 14:
		var angle := TAU * float(index) / 14.0
		kit.glow.ball(stage + Vector3(cos(angle) * 1.62, 0.24, sin(angle) * 0.98), 0.06, SUN.lightened(0.3), Color.TRANSPARENT, 6, 3)

static func _lean(span: Vector3) -> Basis:
	var up := span.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(side, up, side.cross(up))

# --- Balloon tether --------------------------------------------------------------

func _build_balloon_tether() -> void:
	var stake: Vector3 = world.BALLOON
	structure.tube(stake + Vector3(0, 0.08, 0), 0.5, 0.56, 0.16, ROCK, 10)
	structure.tube(stake + Vector3(0, 0.5, 0), 0.12, 0.1, 0.8, DARK_WOOD, 8)
	structure.ball(stake + Vector3(0, 0.92, 0), 0.14, SUN, Color.TRANSPARENT, 8, 4)
	# A coil of spare rope beside the stake.
	for turn in 3:
		structure.tube(stake + Vector3(0.7, 0.2 + float(turn) * 0.07, 0.3), 0.32 - float(turn) * 0.03, 0.32 - float(turn) * 0.03, 0.06, Color("#d9c59a").darkened(0.05 * float(turn)), 12)
	kit.blocker(stake + Vector3(0.3, 1.0, 0.1), Vector3(1.6, 2.0, 1.3))

# --- Kite terrace ------------------------------------------------------------------

## A tall mast with a windsock and stacked flags, a wind rose laid in the deck
## with its arrow downwind, a south rail with the kites' reels, and a bench.
func _build_kite_terrace() -> void:
	var mast: Vector3 = world.MAST
	structure.tube(mast + Vector3(0, 0.12, 0), 0.42, 0.5, 0.24, DEEP, 10)
	structure.tube(mast + Vector3(0, 2.6, 0), 0.1, 0.07, 5.0, WHITE, 8)
	structure.ball(mast + Vector3(0, 5.15, 0), 0.14, SUN, Color.TRANSPARENT, 8, 4)
	for level in 3:
		var flags := kit.batch("sky-flags", _flag_mesh(), flag_material)
		flags.add(mast + Vector3(0.08, 2.4 + float(level) * 0.9, 0), Vector3(1.0, 0.6, 1.0), _downwind(), [CORAL, SUN, MINT][level])
	_windsock(mast + Vector3(0, 4.95, 0))
	kit.blocker(mast + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
	# The wind rose: eight points, the long one painted gold and pointing downwind.
	var rose := Vector3(-12.0, float(world.pad("kite").y) + 0.012, 12.6)
	var flat := _downwind()
	for point in 8:
		var angle := TAU * float(point) / 8.0
		var reach := 1.5 if point % 2 == 0 else 0.8
		var tone := SUN if point == 0 else (NAVY if point % 2 == 0 else SKY)
		if point == 0: reach = 2.0
		var tip := rose + flat * Vector3(cos(angle), 0, -sin(angle)) * reach
		var left := rose + flat * Vector3(cos(angle + 0.4), 0, -sin(angle + 0.4)) * 0.32
		var right := rose + flat * Vector3(cos(angle - 0.4), 0, -sin(angle - 0.4)) * 0.32
		_tri_up(rose, tip, left, tone)
		_tri_up(rose, right, tip, tone.darkened(0.15))
	structure.tube(rose + Vector3(0, 0.004, 0), 0.32, 0.32, 0.01, CREAM, 12)
	# Reels on the south rail where the kite strings start.
	var deck: Dictionary = world.pad("kite")
	for index in REELS.size():
		var x: float = REELS[index]
		var reach: Vector2 = deck.radius
		var z := float((deck.centre as Vector2).y) + reach.y * sqrt(maxf(0.0, 1.0 - pow((x - float((deck.centre as Vector2).x)) / reach.x, 2.0))) - 0.35
		var reel := Vector3(x, deck.y, z)
		structure.box(reel + Vector3(0, 0.45, 0), Vector3(0.14, 0.9, 0.14), DARK_WOOD)
		structure.tube(reel + Vector3(0, 0.78, 0.1), 0.16, 0.16, 0.12, [CORAL, SUN, SKY, MINT][index], 10, Basis(Vector3.RIGHT, PI * 0.5))
		kite_reels.append(reel + Vector3(0, 0.86, 0.12))
		kit.blocker(reel + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4))
	# Low rail along the south edge, between the reels.
	var rail_y: float = deck.y + 0.8
	var ring := _outline(deck, 0.12, 0.0)
	for index in ring.size():
		var at := ring[index]
		if at.y < float((deck.centre as Vector2).y) + 2.4: continue
		var next := ring[(index + 1) % ring.size()]
		if next.y < float((deck.centre as Vector2).y) + 2.4: continue
		var middle := (at + next) * 0.5
		var along := next - at
		kit.detail.box(Vector3(middle.x, rail_y, middle.y), Vector3(along.length() + 0.04, 0.06, 0.06), SKY, Basis(Vector3.UP, -atan2(along.y, along.x)))
		kit.posts().add(Vector3(at.x, deck.y + 0.4, at.y), Vector3(0.08, 0.8, 0.08), Basis.IDENTITY, WHITE)

## A striped windsock on a swivel, its mouth to the wind and its tail downwind.
func _windsock(at: Vector3) -> void:
	var down := _downwind()
	var flags := kit.batch("sky-socks", _sock_mesh(), flag_material)
	flags.add(at, Vector3.ONE, down, WHITE)
	structure.tube(at, 0.05, 0.05, 0.3, DARK_WOOD, 6)

## A cone of cloth along +X: five stripes, free toward its tail.
func _sock_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 8
	const RINGS := 5
	for ring in RINGS:
		var t0 := float(ring) / float(RINGS)
		var t1 := float(ring + 1) / float(RINGS)
		var tone := (CORAL if ring % 2 == 0 else WHITE).srgb_to_linear()
		for side in SIDES:
			var a0 := TAU * float(side) / float(SIDES)
			var a1 := TAU * float(side + 1) / float(SIDES)
			var corners := [[t0, a0], [t1, a0], [t1, a1], [t0, a0], [t1, a1], [t0, a1]]
			for corner: Array in corners:
				var t: float = corner[0]
				var angle: float = corner[1]
				var radius := lerpf(0.26, 0.12, t)
				var direction := Vector3(0, cos(angle), sin(angle))
				tool.set_color(tone)
				tool.set_normal(direction)
				tool.set_uv(Vector2(t, 0))
				tool.set_uv2(Vector2(t, 0))
				tool.add_vertex(Vector3(t * 1.3, direction.y * radius - t * 0.15, direction.z * radius))
	return tool.commit()

func _tri_up(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	if (c - a).cross(b - a).y > 0.0: structure.tri(a, b, c, color)
	else: structure.tri(a, c, b, color)

# --- Photo point -------------------------------------------------------------------

## A giant gilt picture frame on the cloud-top deck, bulbs round its edge, the
## park's name on a ribbon above it, and a camera on a tripod beside it.
func _build_photo_point() -> void:
	var frame: Vector3 = world.FRAME
	const WIDTH := 3.2
	const HEIGHT := 2.7
	const BAR := 0.24
	var gold := Color("#e2b54f")
	var base := frame + Vector3(0, 0.0, 0)
	for side: float in [-1.0, 1.0]:
		var post := base + Vector3(side * (WIDTH * 0.5), 0, 0)
		structure.box(post + Vector3(0, 0.12, 0), Vector3(0.6, 0.24, 0.6), DEEP)
		structure.box(post + Vector3(0, 0.24 + HEIGHT * 0.5, 0), Vector3(BAR, HEIGHT, BAR), gold)
		structure.ball(post + Vector3(0, 0.24 + HEIGHT + 0.12, 0), 0.2, gold.lightened(0.2), Color.TRANSPARENT, 8, 4)
	for level: float in [0.24 + 0.35, 0.24 + HEIGHT]:
		structure.box(base + Vector3(0, level, 0), Vector3(WIDTH + BAR, BAR, BAR), gold)
	# Scrolled corners and an inner moulding.
	for corner: Vector2 in [Vector2(-1, 0.59), Vector2(1, 0.59), Vector2(-1, 0.24 + HEIGHT), Vector2(1, 0.24 + HEIGHT)]:
		structure.ball(base + Vector3(corner.x * WIDTH * 0.5, corner.y, 0.08), 0.2, gold.darkened(0.12), Color.TRANSPARENT, 8, 3)
	kit.detail.box(base + Vector3(0, 0.24 + HEIGHT - 0.16, 0.13), Vector3(WIDTH - 0.3, 0.05, 0.03), CREAM)
	kit.detail.box(base + Vector3(0, 0.75, 0.13), Vector3(WIDTH - 0.3, 0.05, 0.03), CREAM)
	for side: float in [-1.0, 1.0]:
		kit.detail.box(base + Vector3(side * (WIDTH * 0.5 - 0.16), 0.24 + HEIGHT * 0.5 + 0.2, 0.13), Vector3(0.05, HEIGHT - 0.5, 0.03), CREAM)
	# Bulbs round the frame.
	for index in 22:
		var t := float(index) / 22.0
		var spot := _frame_point(t, WIDTH, HEIGHT - 0.35)
		kit.glow.ball(base + Vector3(spot.x, 0.59 + spot.y, 0.16), 0.06, SUN.lightened(0.35), Color.TRANSPARENT, 6, 3)
	# A ribbon sign above the frame with the park's name.
	var ribbon := base + Vector3(0, 0.24 + HEIGHT + 0.62, 0)
	structure.box(ribbon, Vector3(3.0, 0.52, 0.1), SKY)
	for side: float in [-1.0, 1.0]:
		structure.sheet(ribbon + Vector3(side * 1.5, 0.26, 0), ribbon + Vector3(side * 1.5, -0.26, 0), ribbon + Vector3(side * 1.95, -0.1, 0.02), DEEP)
	var sign: Label3D = world._label("雲霄攝影點", ribbon + Vector3(0, 0.0, 0.12), 34, WHITE)
	sign.outline_modulate = NAVY
	sign.pixel_size = 0.0115
	sign.name = "SkyPhotoSign"
	kit.blocker(base + Vector3(0, 1.0, 0), Vector3(WIDTH + 0.6, 2.0, 0.6))
	kit.lamp_light(base + Vector3(0, 2.2, 1.3), 6.5, Color("#ffe6b0"))
	# The photographer's camera on its tripod, aimed at the frame.
	var tripod := Vector3(8.2, float(world.pad("photo").y), 8.6)
	for leg in 3:
		var angle := TAU * float(leg) / 3.0 + 0.3
		var foot := tripod + Vector3(cos(angle) * 0.38, 0, sin(angle) * 0.38)
		var head := tripod + Vector3(0, 1.3, 0)
		structure.tube((foot + head) * 0.5, 0.03, 0.03, foot.distance_to(head), DARK_WOOD, 5, _lean(head - foot))
	structure.box(tripod + Vector3(0, 1.48, 0), Vector3(0.46, 0.32, 0.34), NAVY, Basis(Vector3.UP, -0.9))
	structure.tube(tripod + Vector3(0.14, 1.48, -0.12), 0.11, 0.09, 0.22, Color("#41455a"), 8, Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, PI * 0.5))
	kit.glow.ball(tripod + Vector3(-0.1, 1.68, 0.05), 0.05, CORAL, Color.TRANSPARENT, 6, 3)
	kit.blocker(tripod + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))

## A point round the frame's opening, t from 0 to 1.
static func _frame_point(t: float, width: float, height: float) -> Vector2:
	var perimeter := 2.0 * (width + height)
	var along := t * perimeter
	if along < width: return Vector2(-width * 0.5 + along, height)
	along -= width
	if along < height: return Vector2(width * 0.5, height - along)
	along -= height
	if along < width: return Vector2(width * 0.5 - along, 0.0)
	return Vector2(-width * 0.5, along - width)

# --- Signposts, lamps, planting, sites -----------------------------------------

## A post with a cloud-shaped plate naming each area, and the park's name on
## a big board at the plaza.
func _build_signposts() -> void:
	for spec: Array in SIGNPOSTS:
		var at := Vector3(float(spec[1]), 0, float(spec[2]))
		at.y = world.floor_height(Vector2(at.x, at.z))
		structure.box(at + Vector3(0, 0.07, 0), Vector3(0.4, 0.14, 0.4), DEEP)
		structure.tube(at + Vector3(0, 0.95, 0), 0.06, 0.05, 1.7, WHITE, 6)
		cloud(structure, at + Vector3(0, 1.85, 0.0), 0.36, fposmod(at.x * 0.37, 1.0))
		var title: Label3D = world._local_label(world._area_label(String(spec[0])), at + Vector3(0, 1.98, 0.36), 22, NAVY)
		title.outline_modulate = WHITE
		title.pixel_size = 0.0115
		title.name = "SkySignpost_" + String(spec[0])
		kit.blocker(at + Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45))
	# The park's name on a cloud board beside the gate plaza.
	var board := Vector3(-8.4, world.GROUND_Y, -15.2)
	for side: float in [-1.0, 1.0]:
		structure.tube(board + Vector3(side * 1.3, 1.2, 0), 0.08, 0.07, 2.4, WHITE, 6)
	cloud(structure, board + Vector3(0, 3.15, -0.3), 0.9, 0.3)
	structure.box(board + Vector3(0, 2.75, 0.32), Vector3(2.9, 0.62, 0.08), SKY)
	var name_sign: Label3D = world._label("雲端遊樂場", board + Vector3(0, 2.75, 0.42), 40, WHITE)
	name_sign.outline_modulate = NAVY
	name_sign.pixel_size = 0.0115
	name_sign.name = "SkyParkSign"
	kit.blocker(board + Vector3(0, 1.0, 0), Vector3(2.8, 2.0, 0.5))
	for spot: Vector2 in LAMP_POSTS:
		kit.lamp_post(Vector3(spot.x, world.floor_height(spot), spot.y), 6.5)

func _build_planting() -> void:
	for spec: Array in PLANTS:
		var at := Vector2(float(spec[1]), float(spec[2]))
		kit.billboard(String(spec[0]), Vector3(at.x, world.floor_height(at), at.y), float(spec[3]))

## On the island the park dresses its own stretch of beach (see DistrictSites
## "shore"): tide-pool rocks in loose pairs on the sand, sleeping with the park.
func _build_shore() -> void:
	if world.embedded_in == null: return
	var origin := Vector2(world.position.x, world.position.z)
	var travelled := 0.0
	var coast := IslandShape.coast()
	var pair := 0
	for index in coast.size():
		var here := coast[index]
		var next := coast[(index + 1) % coast.size()]
		travelled += here.distance_to(next)
		if travelled < 15.0 or IslandShape.DistrictSites.distance(world.district, here) > IslandShape.DistrictSites.BAND: continue
		travelled = 0.0
		var along := (next - here).normalized()
		var inland := IslandShape.inland_direction(here)
		for rock in 1 + pair % 2:
			var spot := here + inland * (1.3 + 0.2 * float(rock)) + along * (float(rock) - 0.5) * 1.1
			if IslandShape.distance_to_coast(spot) < 0.6 or IslandShape.lawn_inset(spot) > -0.3: continue
			var local := spot - origin
			kit.billboard("rocks", Vector3(local.x, world.IslandLayout.BEACH_TOP_Y - 0.03, local.y), 0.75 + 0.25 * fposmod(float(pair) * 0.37, 1.0))
		pair += 1

## Kept stand sites: a booth wrapped in a striped sky-blue tarp and tied down
## with rope, a balloon bobbing on its corner, and a "準備中" tag.
func _build_sites() -> void:
	var tarps: Array[Color] = [SKY, MINT, LILAC, Color("#ffb59e")]
	var index := 0
	for site: Dictionary in world.open_sites():
		var at: Vector3 = site.stand
		var cloth: Color = tarps[index % tarps.size()]
		var turn := Basis(Vector3.UP, (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.3)
		structure.box(at + Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 0.9), Color("#d7d2c8"), turn)
		structure.box(at + Vector3(0, 0.5, 0), Vector3(1.26, 0.76, 0.82), cloth, turn)
		structure.ball(at + Vector3(0, 0.86, 0), 0.66, cloth, cloth.lightened(0.35), 10, 3, 0.34, true)
		for stripe in 3:
			structure.box(at + turn * Vector3(-0.42 + float(stripe) * 0.42, 0.5, 0.42), Vector3(0.16, 0.7, 0.02), WHITE, turn)
		# Two ropes cinch the tarp.
		for rope: float in [-0.3, 0.3]:
			structure.box(at + turn * Vector3(rope, 0.55, 0), Vector3(0.04, 0.84, 0.86), Color("#d9c59a"), turn)
		# A balloon tied to the corner.
		var knot := at + turn * Vector3(0.62, 0.9, 0.4)
		kit.detail.box(knot + Vector3(0, 0.45, 0), Vector3(0.015, 0.9, 0.015), Color("#e6e6e6"))
		structure.ball(knot + Vector3(0, 1.08, 0), 0.22, FLAGS[index % FLAGS.size()], Color.TRANSPARENT, 8, 4, 1.15)
		var tag := at + turn * Vector3(-0.45, 0, 0.62)
		structure.box(tag + Vector3(0, 0.36, 0), Vector3(0.05, 0.72, 0.05), DARK_WOOD)
		structure.box(tag + Vector3(0, 0.78, 0), Vector3(0.6, 0.3, 0.05), CREAM, turn)
		site_tags.append(world.StandSites.tag(world, tag + Vector3(0, 0.78, 0.08), NAVY, WHITE))
		kit.blocker(at + Vector3(0, 1.0, 0), world.ArcadeStands.FOOTPRINT)
		index += 1

func _commit() -> void:
	world._mesh(structure.mesh(), Vector3.ZERO, painted).name = "SkyStructure"
	var bank: MeshInstance3D = world._mesh(puffs.mesh(), Vector3.ZERO, cloud_puff)
	bank.name = "SkyCloudBank"
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
