extends RefCounted
## The moored ferry 晚風號: a clinker-built hull with a raked stem, plank deck,
## boarded cabin under a gabled roof, funnel, railings, bunting and a stern
## lantern. Everything is created once; the hull's heave, roll and pennants are
## registered ambient components, so they stop under reduced motion.

const CENTER := Vector3(5.5, 0.0, 25.0)
const DECK_Y := 1.0
const BOW_Z := -4.75
const STERN_Z := 4.2
const HALF_BEAM := 2.45
const STEM_RAKE := 0.22
const STATIONS := 14
## The boat prologue stands its traveller on this forward-deck point.
const STAGE_ANCHOR := Vector3(5.5, 1.04, 22.65)
## Hull footprint kept from the former ferry so dockside collision is unchanged.
const COLLISION_SIZE := Vector3(5.0, 0.8, 8.0)

const HULL_BOTTOM := Color("#6f3f37")
const HULL_BOOT := Color("#d2694f")
const HULL_PAINT := Color("#2c6f6d")
const HULL_PAINT_DEEP := Color("#235b5c")
const HULL_SHEER := Color("#ecdcb6")
const TIMBER := Color("#8a6844")
const TRIM := Color("#f1e3c0")
const DECK_WOOD := Color("#9a7149")
const CABIN_BOARD := Color("#e6d2a8")
const ROPE := Color("#ddcba0")
const GLASS := Color("#2f5364")
const WINDOW_GLOW := Color("#ffcf87")
const BRASS := Color("#d2a55c")
const CABIN_SIZE := Vector3(2.9, 1.5, 3.9)
const CABIN_ORIGIN := Vector3(0.0, DECK_Y, 0.5)
const ROOF_RISE := 0.72
const ROOF_OVERHANG := 0.4

static func build(world: Node3D) -> void:
	var anchor := Marker3D.new()
	anchor.name = "FerryDeckStageAnchor"
	anchor.position = STAGE_ANCHOR
	world.add_child(anchor)
	var collision := StaticBody3D.new()
	collision.name = "FerryCollision"
	collision.position = CENTER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = COLLISION_SIZE
	shape.shape = box
	collision.add_child(shape)
	world.add_child(collision)
	# Heave and roll live on separate nodes because each ambient component owns
	# one animated property. Parts are authored relative to CENTER.
	var ferry := Node3D.new()
	ferry.name = "WelcomeFerry"
	ferry.position = CENTER
	world.add_child(ferry)
	var body := Node3D.new()
	body.name = "FerryRoll"
	ferry.add_child(body)
	_build_hull(world, body)
	_build_cabin(world, body)
	_build_funnel(world, body)
	_build_rails(world, body)
	_build_fittings(world, body)
	_build_bunting(world, body)
	_build_lamp(world, body)
	world.component_motion.register_component(ferry, "water", 0.37)
	world.component_motion.register_component(body, "cloth", 0.81)

## Half-beam at the gunwale: a fine entry at the stem, parallel midbody and a
## slightly tucked transom.
static func _beam(t: float) -> float:
	if t < 0.42: return maxf(0.05, HALF_BEAM * (1.0 - pow(1.0 - t / 0.42, 2.4)))
	if t > 0.8: return HALF_BEAM * (1.0 - 0.2 * pow((t - 0.8) / 0.2, 2.0))
	return HALF_BEAM

## Height of the gunwale: the sheer line rises to the bow and lifts at the stern.
static func _sheer(t: float) -> float:
	var forward := pow(maxf(0.0, 1.0 - t / 0.45), 2.0) * 0.42
	var aft := pow(maxf(0.0, (t - 0.7) / 0.3), 2.0) * 0.1
	return 1.3 + forward + aft

## A point of the boat, relative to CENTER: `t` runs bow (0) to stern (1). The
## stem rakes forward with height; that lean fades out along the forebody.
static func _at(t: float, half_breadth: float, y: float, side: float) -> Vector3:
	var fade := clampf(1.0 - t / 0.35, 0.0, 1.0)
	return Vector3(side * half_breadth, y, lerpf(BOW_Z, STERN_Z, t) - STEM_RAKE * (y + 0.8) * fade * fade)

## One hull section from keel to gunwale: x is the half-breadth, y the height.
static func _section(t: float) -> Array[Vector2]:
	var beam := _beam(t)
	var sheer := _sheer(t)
	return [
		Vector2(0.02, -0.8),
		Vector2(beam * 0.68, -0.64),
		Vector2(beam * 0.88, -0.3),
		Vector2(beam * 0.93, 0.02),
		Vector2(beam * 0.96, lerpf(0.02, sheer, 0.36)),
		Vector2(beam * 0.985, lerpf(0.02, sheer, 0.7)),
		Vector2(beam, sheer - 0.15),
		Vector2(beam + 0.05, sheer),
	]

static func _build_hull(world: Node3D, body: Node3D) -> void:
	var strake_colors: Array[Color] = [HULL_BOTTOM, HULL_BOTTOM, HULL_BOOT, HULL_PAINT_DEEP, HULL_PAINT, HULL_PAINT_DEEP, HULL_SHEER]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for station in range(STATIONS):
		var t0 := float(station) / STATIONS
		var t1 := float(station + 1) / STATIONS
		var fore := _section(t0)
		var aft := _section(t1)
		var top := fore.size() - 1
		for side: float in [-1.0, 1.0]:
			for strake in range(strake_colors.size()):
				# Clinker planking: each painted strake's lower edge laps the one below.
				var lap := 0.035 if strake >= 3 else 0.0
				var outward := Vector3(side * 0.6, -1.0, 0.0) if strake < 2 else Vector3(side, 0.1, 0.0)
				var grain := sin(float(station * 37 + strake * 91) + side * 1.7) * 0.03
				_quad(tool,
					_at(t0, fore[strake].x + lap, fore[strake].y, side),
					_at(t1, aft[strake].x + lap, aft[strake].y, side),
					_at(t1, aft[strake + 1].x, aft[strake + 1].y, side),
					_at(t0, fore[strake + 1].x, fore[strake + 1].y, side),
					outward, strake_colors[strake] * (1.0 + grain))
			# A timber cap and the bulwark's inner face close the hull above the deck.
			var inner_fore := maxf(0.0, fore[top].x - 0.19)
			var inner_aft := maxf(0.0, aft[top].x - 0.19)
			_quad(tool, _at(t0, fore[top].x, fore[top].y, side), _at(t1, aft[top].x, aft[top].y, side),
				_at(t1, inner_aft, aft[top].y, side), _at(t0, inner_fore, fore[top].y, side), Vector3.UP, TIMBER)
			_quad(tool, _at(t0, inner_fore, fore[top].y, side), _at(t1, inner_aft, aft[top].y, side),
				_at(t1, maxf(0.0, inner_aft - 0.05), DECK_Y - 0.02, side), _at(t0, maxf(0.0, inner_fore - 0.05), DECK_Y - 0.02, side),
				Vector3(-side, 0.2, 0.0), HULL_SHEER * 0.9)
	# Transom: a flat stern painted like the topsides under a pale top board.
	var stern := _section(1.0)
	for row in range(stern.size() - 1):
		var color := HULL_SHEER if row == stern.size() - 2 else (HULL_PAINT if row >= 2 else HULL_BOTTOM)
		_quad(tool, _at(1.0, stern[row].x, stern[row].y, -1.0), _at(1.0, stern[row].x, stern[row].y, 1.0),
			_at(1.0, stern[row + 1].x, stern[row + 1].y, 1.0), _at(1.0, stern[row + 1].x, stern[row + 1].y, -1.0), Vector3.BACK, color)
	tool.generate_normals()
	var hull: MeshInstance3D = world._mesh(tool.commit(), CENTER, world._vertex_color_material("ferry-hull"))
	hull.name = "FerryHull"
	hull.reparent(body)
	# Deck planks run fore and aft: the plank shader lays its seams along local x,
	# so the deck is modelled lengthwise on x and turned into place.
	var deck_tool := SurfaceTool.new()
	deck_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for station in range(STATIONS):
		var corners: Array[Vector3] = []
		for corner: Array in [[0, 1.0], [1, 1.0], [1, -1.0], [0, -1.0]]:
			var t := float(station + int(corner[0])) / STATIONS
			var edge := _at(t, maxf(0.0, _beam(t) - 0.16), DECK_Y, float(corner[1]))
			corners.append(Vector3(edge.z, 0.0, -edge.x))
		_quad(deck_tool, corners[0], corners[1], corners[2], corners[3], Vector3.UP, Color.WHITE)
	deck_tool.generate_normals()
	var deck: MeshInstance3D = world._mesh(deck_tool.commit(), CENTER + Vector3(0, DECK_Y, 0), world._wood_material(DECK_WOOD))
	deck.name = "FerryDeck"
	deck.rotation.y = -PI * 0.5
	deck.reparent(body)
	# The stem post carries the planking and continues up as the jackstaff.
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for post: Array in [[-0.7, _sheer(0.0) + 0.28, 0.2], [_sheer(0.0) + 0.28, 3.5, 0.07]]:
		var timber: MeshInstance3D = world._mesh(cube, CENTER, world._wood_material(TIMBER))
		var placed := _beam_between(_at(0.0, 0.0, float(post[0]), 1.0), _at(0.0, 0.0, float(post[1]), 1.0), float(post[2]))
		timber.transform = Transform3D(placed.basis, CENTER + placed.origin)
		timber.reparent(body)

static func _build_cabin(world: Node3D, body: Node3D) -> void:
	var size := CABIN_SIZE
	var origin := CENTER + CABIN_ORIGIN
	var boards: Material = world._wood_material(CABIN_BOARD)
	# Four boarded walls; the end walls are turned so their seams stay upright.
	for side: float in [-1.0, 1.0]:
		var wall: MeshInstance3D = world._box(origin + Vector3(side * (size.x * 0.5 - 0.05), size.y * 0.5, 0), Vector3(0.1, size.y, size.z), CABIN_BOARD)
		wall.material_override = boards
		wall.reparent(body)
		var end_wall: MeshInstance3D = world._box(origin + Vector3(0, size.y * 0.5, side * (size.z * 0.5 - 0.05)), Vector3(0.1, size.y, size.x - 0.2), CABIN_BOARD)
		end_wall.rotation.y = PI * 0.5
		end_wall.material_override = boards
		end_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		end_wall.reparent(body)
	var roof_span := size.x + ROOF_OVERHANG * 2.0
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(roof_span, ROOF_RISE, size.z + ROOF_OVERHANG * 2.0)
	var roof: MeshInstance3D = world._mesh(roof_mesh, origin + Vector3(0, size.y + ROOF_RISE * 0.5, 0), world._coastal_surface(3, 1.5))
	roof.name = "FerryRoof"
	roof.reparent(body)
	# Trim: sills, eaves, barge boards, ridge, corner posts, frames and the aft door.
	var trim: Array[Transform3D] = []
	var trim_colors: Array[Color] = []
	var slope := atan2(ROOF_RISE, roof_span * 0.5)
	for side: float in [-1.0, 1.0]:
		_part(trim, trim_colors, Vector3(side * roof_span * 0.5, size.y + 0.03, 0), Vector3(0.1, 0.12, size.z + ROOF_OVERHANG * 2.0 + 0.06), TRIM)
		_part(trim, trim_colors, Vector3(side * size.x * 0.5, 0.09, 0), Vector3(0.08, 0.18, size.z + 0.06), HULL_PAINT)
		_part(trim, trim_colors, Vector3(0, 0.09, side * size.z * 0.5), Vector3(size.x + 0.06, 0.18, 0.08), HULL_PAINT)
		for end: float in [-1.0, 1.0]:
			_part(trim, trim_colors, Vector3(side * size.x * 0.5, size.y * 0.5, end * size.z * 0.5), Vector3(0.14, size.y, 0.14), TRIM)
			_part(trim, trim_colors, Vector3(side * roof_span * 0.25, size.y + ROOF_RISE * 0.5 + 0.04, end * (size.z * 0.5 + ROOF_OVERHANG)), Vector3(roof_span * 0.53, 0.1, 0.07), TRIM, Vector3(0, 0, -side * slope))
		for window in range(3):
			_part(trim, trim_colors, Vector3(side * (size.x * 0.5 + 0.02), 0.92, -1.2 + window * 1.2), Vector3(0.06, 0.74, 0.86), HULL_PAINT)
	_part(trim, trim_colors, Vector3(0, size.y + ROOF_RISE + 0.02, 0), Vector3(0.16, 0.1, size.z + ROOF_OVERHANG * 2.0 + 0.1), TIMBER)
	_part(trim, trim_colors, Vector3(-0.55, 0.78, size.z * 0.5 + 0.02), Vector3(0.82, 1.42, 0.06), HULL_PAINT)
	_part(trim, trim_colors, Vector3(-0.55, 0.62, size.z * 0.5 + 0.05), Vector3(0.6, 0.86, 0.04), HULL_PAINT_DEEP)
	_part(trim, trim_colors, Vector3(-0.27, 0.78, size.z * 0.5 + 0.08), Vector3(0.06, 0.06, 0.06), BRASS)
	for window in range(2):
		_part(trim, trim_colors, Vector3(-0.62 + window * 1.24, 0.95, -size.z * 0.5 - 0.02), Vector3(0.86, 0.7, 0.06), HULL_PAINT)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var trim_batch: MultiMeshInstance3D = world._multi_mesh(cube, origin, trim, trim_colors, world._vertex_color_material("ferry-trim"))
	trim_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trim_batch.reparent(body)
	# The panes share one material; the world raises its glow with the lamp level.
	var panes: Array[Transform3D] = []
	var pane_colors: Array[Color] = []
	for side: float in [-1.0, 1.0]:
		for window in range(3):
			_part(panes, pane_colors, Vector3(side * (size.x * 0.5 + 0.04), 0.92, -1.2 + window * 1.2), Vector3(0.05, 0.58, 0.7), Color.WHITE)
	for window in range(2):
		_part(panes, pane_colors, Vector3(-0.62 + window * 1.24, 0.95, -size.z * 0.5 - 0.04), Vector3(0.7, 0.54, 0.05), Color.WHITE)
	_part(panes, pane_colors, Vector3(-0.55, 1.2, size.z * 0.5 + 0.06), Vector3(0.42, 0.34, 0.04), Color.WHITE)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = GLASS
	glow.roughness = 0.35
	glow.emission_enabled = true
	glow.emission = WINDOW_GLOW
	glow.emission_energy_multiplier = 0.0
	world.material_cache["ferry-window-glow"] = glow
	world.ferry_window_glow = glow
	var pane_batch: MultiMeshInstance3D = world._multi_mesh(cube, origin, panes, pane_colors, glow)
	pane_batch.name = "FerryWindows"
	pane_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pane_batch.reparent(body)

static func _build_funnel(world: Node3D, body: Node3D) -> void:
	# A short raked stack: collar, painted body, pale band, sooty top, rolled rim.
	var funnel := Node3D.new()
	funnel.name = "FerryFunnel"
	body.add_child(funnel)
	funnel.position = CABIN_ORIGIN + Vector3(0, CABIN_SIZE.y + ROOF_RISE - 0.17, 0.6)
	funnel.rotation.x = 0.1
	var parts := [
		{"y": 0.42, "radius": 0.44, "top": 0.4, "height": 0.84, "color": HULL_BOOT},
		{"y": 0.94, "radius": 0.42, "top": 0.41, "height": 0.2, "color": TRIM},
		{"y": 1.2, "radius": 0.4, "top": 0.38, "height": 0.32, "color": Color("#3d4a4c")},
		{"y": 1.4, "radius": 0.45, "top": 0.45, "height": 0.09, "color": BRASS},
		{"y": 1.45, "radius": 0.35, "top": 0.35, "height": 0.02, "color": Color("#1f2a2c")},
		{"y": 0.03, "radius": 0.5, "top": 0.46, "height": 0.1, "color": TIMBER},
	]
	for part: Dictionary in parts:
		var piece: MeshInstance3D = world._cylinder(Vector3.ZERO, float(part.radius), float(part.height), part.color, float(part.top))
		piece.reparent(funnel, false)
		piece.position = Vector3(0, float(part.y), 0)
	# Riveted plate, tinted to the boot-stripe red.
	(funnel.get_child(0) as MeshInstance3D).material_override = world._coastal_surface(7, 0.9, Color(1.5, 0.82, 0.62))

static func _build_rails(world: Node3D, body: Node3D) -> void:
	# Stanchions and a top rail follow the sheer around the bow and the quarters.
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var post_colors: Array[Color] = []
	var rail_colors: Array[Color] = []
	for side: float in [-1.0, 1.0]:
		for run: Array in [[0.03, 0.3, 5], [0.86, 1.0, 3]]:
			var previous := Vector3.INF
			for index in range(int(run[2]) + 1):
				var t := lerpf(float(run[0]), float(run[1]), float(index) / float(run[2]))
				var foot := _at(t, maxf(0.0, _beam(t) - 0.07), _sheer(t), side)
				_part(posts, post_colors, foot + Vector3(0, 0.25, 0), Vector3(0.05, 0.5, 0.05), TRIM)
				var top := foot + Vector3(0, 0.5, 0)
				if previous != Vector3.INF:
					rails.append(_beam_between(previous, top, 0.06))
					rail_colors.append(TIMBER)
				previous = top
	# The stern rail closes across the transom.
	var corner := _at(1.0, _beam(1.0) - 0.07, _sheer(1.0) + 0.5, 1.0)
	rails.append(_beam_between(Vector3(-corner.x, corner.y, corner.z), corner, 0.06))
	rail_colors.append(TIMBER)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for batch: Array in [[posts, post_colors, "ferry-rail-posts"], [rails, rail_colors, "ferry-rails"]]:
		var instance: MultiMeshInstance3D = world._multi_mesh(cube, CENTER, batch[0], batch[1], world._vertex_color_material(str(batch[2])))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.reparent(body)

static func _build_fittings(world: Node3D, body: Node3D) -> void:
	var aft_wall := CABIN_ORIGIN.z + CABIN_SIZE.z * 0.5
	# Life ring on the aft cabin wall, beside the door.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.2
	ring_mesh.outer_radius = 0.36
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 8
	var ring_spot := Vector3(0.75, DECK_Y + 0.85, aft_wall + 0.08)
	var ring: MeshInstance3D = world._mesh(ring_mesh, CENTER + ring_spot, world._mat(HULL_BOOT))
	ring.name = "FerryLifeRing"
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.reparent(body)
	var details: Array[Transform3D] = []
	var colors: Array[Color] = []
	for band in range(4):
		var angle := PI * 0.25 + band * PI * 0.5
		_part(details, colors, ring_spot + Vector3(cos(angle), sin(angle), 0) * 0.28, Vector3(0.2, 0.1, 0.19), TRIM, Vector3(0, 0, angle))
	# Rope fenders hang down the dock side; mooring cleats sit on the gunwale.
	for index in range(3):
		var t := 0.36 + index * 0.2
		_part(details, colors, _at(t, _beam(t) + 0.14, 0.35, -1.0), Vector3(0.24, 0.62, 0.24), Color("#c9a56a"))
		_part(details, colors, _at(t, _beam(t) + 0.1, 0.95, -1.0), Vector3(0.04, 0.7, 0.04), ROPE)
	for t: float in [0.18, 0.93]:
		_part(details, colors, _at(t, _beam(t) - 0.05, _sheer(t) + 0.07, -1.0), Vector3(0.12, 0.14, 0.4), BRASS)
	# Name board across the transom.
	_part(details, colors, Vector3(0, 0.78, STERN_Z + 0.03), Vector3(2.5, 0.46, 0.06), TIMBER)
	_part(details, colors, Vector3(0, 0.78, STERN_Z + 0.05), Vector3(2.34, 0.34, 0.05), HULL_PAINT_DEEP)
	# A bench on the after deck.
	_part(details, colors, Vector3(1.0, DECK_Y + 0.3, 3.3), Vector3(1.5, 0.08, 0.42), DECK_WOOD)
	for leg: float in [-0.6, 0.6]:
		_part(details, colors, Vector3(1.0 + leg, DECK_Y + 0.14, 3.3), Vector3(0.08, 0.28, 0.36), TIMBER)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var batch: MultiMeshInstance3D = world._multi_mesh(cube, CENTER, details, colors, world._vertex_color_material("ferry-fittings"))
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.reparent(body)
	# Mooring lines run from the cleats to the dock posts.
	for line: Array in [[0.18, Vector3(-3.0, 1.25, -3.6)], [0.93, Vector3(-3.0, 1.25, 1.8)]]:
		var t := float(line[0])
		var placed := _beam_between(_at(t, _beam(t) - 0.05, _sheer(t) + 0.1, -1.0), line[1], 0.05)
		var rope: MeshInstance3D = world._mesh(cube, CENTER, world._mat(ROPE))
		rope.transform = Transform3D(placed.basis, CENTER + placed.origin)
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rope.reparent(body)
	# The name is lettered flat on the board instead of floating toward the camera.
	var label: Label3D = world._local_label("晚風號", CENTER + Vector3(0, 0.78, STERN_Z + 0.085), 24)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.reparent(body)

static func _build_bunting(world: Node3D, body: Node3D) -> void:
	# Two pennant lines dress the ferry from the funnel to the jackstaff and stern.
	var funnel_top := CABIN_ORIGIN + Vector3(0, CABIN_SIZE.y + ROOF_RISE + 1.28, 0.74)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var flag_mesh := PrismMesh.new()
	flag_mesh.size = Vector3(0.42, 0.4, 0.03)
	var flag_colors: Array[Color] = [world.CORAL, world.GOLD, world.CREAM, HULL_PAINT]
	var flag_index := 0
	for run: Array in [[_at(0.0, 0.0, 3.5, 1.0), 8], [Vector3(0, _sheer(1.0) + 0.5, STERN_Z), 4]]:
		var far_end: Vector3 = run[0]
		var placed := _beam_between(funnel_top, far_end, 0.025)
		var line: MeshInstance3D = world._mesh(cube, CENTER, world._mat(Color("#6e563c")))
		line.transform = Transform3D(placed.basis, CENTER + placed.origin)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.reparent(body)
		for index in range(int(run[1])):
			var along := (float(index) + 0.75) / (float(run[1]) + 0.5)
			var hang := CENTER + funnel_top.lerp(far_end, along) + Vector3(0, -0.22, 0)
			# Seen from the prologue camera, pennants forward of the traveller would
			# hang across their face; that stretch of the line stays bare.
			if hang.z < STAGE_ANCHOR.z - 0.4: continue
			var flag: MeshInstance3D = world._mesh(flag_mesh, hang, world._mat(flag_colors[flag_index % flag_colors.size()]))
			# Point down, facing along the hull so both cameras see the pennant.
			flag.rotation.z = PI
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flag.reparent(body)
			world.component_motion.register_component(flag, "flag", float(flag_index) * 0.6)
			flag_index += 1

static func _build_lamp(world: Node3D, body: Node3D) -> void:
	# The stern lantern hangs under the aft gable. Its light joins the world's
	# lamp list, so the shared nearest-lamp budget decides when it is lit.
	var spot := CENTER + CABIN_ORIGIN + Vector3(0, CABIN_SIZE.y + 0.12, CABIN_SIZE.z * 0.5 + 0.2)
	var bracket: MeshInstance3D = world._box(spot + Vector3(0, 0.3, -0.1), Vector3(0.05, 0.05, 0.42), TIMBER)
	bracket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bracket.reparent(body)
	var shade: MeshInstance3D = world._box(spot, Vector3(0.24, 0.3, 0.24), WINDOW_GLOW)
	shade.name = "FerryLantern"
	shade.material_override = world._mat(Color("#ffd68b"), true)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.reparent(body)
	var cap: MeshInstance3D = world._cone(spot + Vector3(0, 0.21, 0), TIMBER)
	cap.scale = Vector3(0.36, 0.14, 0.36)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.reparent(body)
	var light := OmniLight3D.new()
	light.name = "FerryLanternLight"
	light.position = spot + Vector3(0, -0.1, 0.25)
	light.light_color = Color("#ffc276")
	light.omni_range = 5.5
	light.light_energy = 0.0
	world.add_child(light)
	world.lamps.append(light)

## Adds a unit-cube instance at `position` (relative to its batch origin).
## Vertex and instance colours are read as linear light, so palette colours are
## converted here and in _quad to keep the authored tones.
static func _part(transforms: Array[Transform3D], colors: Array[Color], position: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	transforms.append(Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), position))
	colors.append(color.srgb_to_linear())

## Transform that stretches a unit cube from `a` to `b` with a square section.
static func _beam_between(a: Vector3, b: Vector3, thickness: float) -> Transform3D:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP if absf(along.y) < 0.99 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(side * thickness, along.cross(side) * thickness, along * a.distance_to(b)), (a + b) * 0.5)

## Emits a quad as two triangles wound so the lit face looks toward `outward`.
static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	for triangle: Array in [[a, b, c], [a, c, d]]:
		var p: Vector3 = triangle[0]
		var q: Vector3 = triangle[1]
		var r: Vector3 = triangle[2]
		# Godot front faces are clockwise: their (q-p)x(r-p) points away from the viewer.
		if (q - p).cross(r - p).dot(outward) > 0.0:
			var swap := q
			q = r
			r = swap
		for vertex: Vector3 in [p, q, r]:
			tool.set_color(color.srgb_to_linear())
			tool.add_vertex(vertex)
