extends RefCounted
## Everything in the mirror circus that never moves on its own: the meadow and yard,
## the cut-away big top, the ring, the front stalls, the entrance, the mirror
## gallery, the shadow theatre's stage, empty pitches and the camp in the woods.
## Built once through the scenery kit; it keeps the few materials the time of day
## changes and the nodes the welcome photo has to step around.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/circus_props.gd")
const HarborProps := preload("res://game/world/harbor_props.gd")
const CANVAS := preload("res://game/world/circus_canvas.gdshader")
const MIRROR := preload("res://game/world/circus_mirror.gdshader")
const BULBS := preload("res://game/world/marquee_bulbs.gdshader")
const MEADOW_Y := 0.14
const YARD_Y := 0.17
const RING := Vector3(0, 0.2, -8.8)
const RING_RADIUS := 3.0
## The big top is cut open toward the camera: only the back of its wall and roof stand.
const TOP_CENTER := Vector3(0, YARD_Y, -8.0)
const TOP_RADIUS := 10.6
const TOP_WALL := 3.4
const TOP_ROOF := 3.1
const KING_HEIGHT := 8.6
## North pair, then south pair.
const KING_POLES: Array[Vector3] = [Vector3(-4.6, 0.2, -11.6), Vector3(4.6, 0.2, -11.6), Vector3(-5.6, 0.2, -5.9), Vector3(5.6, 0.2, -5.9)]
const ARCH_Z := 10.4
const ARCH_HALF := 4.75
## The name board hangs in the one band of the view that covers neither the host and
## the story point in the foyer nor the interaction point in the aisle behind them.
const ARCH_HEIGHT := 5.5
const ARCH_BOARD := Vector2(6.4, 0.7)
## Front stalls: bench row z and seat height, rising toward the back.
const STALL_ROWS := [[-3.1, 0.44], [-1.32, 0.56], [0.46, 0.68], [2.24, 0.8]]
const STALL_X := 2.41
## Angled funhouse mirrors along the west wall: z, shape, width, height, bend (r wide, g tall, b lens).
const WALL_MIRRORS := [
	[4.4, "arch", 1.25, 2.1, Color(0.2, 0.85, 0.5)], [2.3, "oval", 1.4, 1.9, Color(0.92, 0.22, 0.5)],
	[0.2, "gem", 1.3, 2.0, Color(0.5, 0.55, 0.95)], [-1.9, "arch", 1.4, 1.8, Color(0.85, 0.6, 0.2)],
	[-4.0, "oval", 1.15, 2.15, Color(0.3, 0.95, 0.8)],
]
const WALL_MIRROR_X := -12.95
## Free-standing mirrors that face the hall: x, shape, bend.
const HALL_MIRRORS := [[-8.24, "oval", Color(0.5, 0.5, 0.5)], [-5.76, "gem", Color(0.75, 0.3, 0.7)]]
const HALL_MIRROR_Z := -2.85
const LAMP_POSTS: Array[Vector3] = [
	Vector3(-4.4, 0.2, 5.3), Vector3(4.4, 0.2, 5.3), Vector3(-12.7, MEADOW_Y, 6.5), Vector3(12.8, MEADOW_Y, 6.4),
	Vector3(-8.7, MEADOW_Y, 10.6), Vector3(8.5, MEADOW_Y, 8.8), Vector3(-6.9, MEADOW_Y, 14.8), Vector3(4.4, MEADOW_Y, 17.6),
]
## Small tents of the camp: x, z, radius, wall height, peak height, dye.
const TENTS := [
	[-18.6, -14.2, 3.0, 2.3, 5.2, "#2f8a8c"], [18.4, -13.4, 2.6, 2.1, 4.6, "#6d3f72"], [-11.2, 15.2, 2.4, 2.0, 4.2, "#d9963f"],
	[11.9, 16.4, 2.8, 2.2, 4.9, "#c9483d"], [26.5, 3.0, 2.5, 2.1, 4.4, "#2f8a8c"], [-26.2, 6.2, 2.7, 2.2, 4.7, "#c9483d"],
	[-27.5, -21.5, 2.6, 2.1, 4.5, "#6d3f72"], [25.5, -23.5, 2.9, 2.2, 5.0, "#d9963f"],
]
## Wagons and caravans: x, z, yaw, body colour.
const WAGONS := [
	[-17.5, 3.2, 0.12, "#c9483d"], [-17.1, -4.7, -0.1, "#2f8a8c"], [16.7, 2.4, -0.15, "#6d3f72"],
	[17.3, -5.3, 0.1, "#d9963f"], [6.4, 14.3, 0.2, "#2f8a8c"], [-20.6, 11.8, -0.3, "#6d3f72"],
]
## Banner poles around the yard: x, z, height.
const BANNER_POLES := [[-13.6, 9.0, 5.6], [13.6, 9.0, 5.6], [-7.6, 12.2, 5.0], [7.4, 11.4, 5.0], [-14.6, -7.6, 5.2], [14.8, -7.4, 5.2], [-20.5, -1.0, 4.8], [20.6, -1.6, 4.8]]
## Hero billboards with their own cast shadows: kind, x, z, height.
const PLANTS := [
	["pine", -22.0, 7.0, 5.2], ["oak", 21.4, 7.2, 4.8], ["ginkgo", -21.6, -8.4, 4.8], ["pine", 21.8, -9.0, 5.2],
	["oak", 5.0, 20.5, 4.6], ["ginkgo", -5.6, 19.4, 4.6],
	["planter", -6.1, 10.9, 1.7], ["planter", 8.1, 10.5, 1.7], ["shrub", -14.4, 10.3, 1.3], ["shrub", 14.9, 6.9, 1.25],
	["shrub", -15.2, -0.6, 1.25], ["shrub", 15.4, -8.6, 1.3], ["shrub", -9.2, 12.4, 1.2], ["shrub", 9.8, 12.0, 1.2],
]
const CRATES: Array[Vector3] = [Vector3(-14.8, MEADOW_Y, 7.4), Vector3(14.9, MEADOW_Y, -1.4), Vector3(13.9, MEADOW_Y, 10.4), Vector3(-15.4, MEADOW_Y, -9.6), Vector3(20.2, MEADOW_Y, 5.6)]
## Plush audience on the back bleachers: x, tier, kind, fur.
const PLUSHES := [
	[-2.1, 0, "bear", "#c98d5a"], [-0.4, 0, "bunny", "#f1e7dc"], [1.6, 0, "star", "#8fc8d8"], [-1.3, 1, "bunny", "#e88aa0"],
	[0.6, 1, "bear", "#e9b85c"], [2.2, 1, "bear", "#b7a4d6"], [-2.3, 2, "star", "#f4e6c6"], [-0.2, 2, "bear", "#7fb88a"],
	[1.4, 2, "bunny", "#c98d5a"], [-1.0, 3, "bear", "#e88aa0"], [0.9, 3, "star", "#e9b85c"],
]
const BLEACHERS := Vector3(0, YARD_Y, -13.2)
const BLEACHER_WIDTH := 5.4
const DRUM := Vector3(3.7, YARD_Y, -13.05)
const CANNON := Vector3(-9.85, YARD_Y, -7.1)
const CALLIOPE := Vector3(-6.5, YARD_Y, 8.4)
const TICKET_BOOTH := Vector3(6.0, YARD_Y, 9.5)
const WIRE := Color("#3d3348")

var world: Node3D
var kit: Kit
var canvas := Props.Canvas.new()
var glass := Props.Glass.new()
## Trim that would stand in front of the welcome photo; hidden while it is framed.
var foreground := Kit.Sculpt.new()
var photo_clutter: Array[Node3D] = []
var mirror_material: ShaderMaterial
var chase_bulbs: ShaderMaterial
var shimmer_bulbs: ShaderMaterial
var lamp_plaque: Label3D
var _chase_spots: Array[Transform3D] = []
var _chase_tints: Array[Color] = []
var _shimmer_spots: Array[Transform3D] = []
var _shimmer_tints: Array[Color] = []
var _flags: Kit.Batch

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit

func build() -> void:
	_flags = kit.batch("flags", Kit.cloth_mesh(Vector2(1.0, 0.56), 6, 1, false), kit.cloth_material("flag", 0.18))
	_build_ground()
	_build_big_top()
	_build_ring()
	_build_stalls()
	_build_forecourt()
	_build_mirror_gallery()
	_build_shadow_theatre()
	_build_pitches()
	_build_camp()
	_build_woods()
	_commit()

## Bulbs, lanterns and mirrors follow the region's lamp level; the mirrors also
## borrow the sky colour, so they darken with the evening.
func apply_time_of_day(lamp_level: float, sky: Color) -> void:
	kit.set_glow(lamp_level * 2.6)
	for bulbs: ShaderMaterial in [chase_bulbs, shimmer_bulbs]:
		bulbs.set_shader_parameter("level", 0.45 + lamp_level * 2.4)
	mirror_material.set_shader_parameter("sky_high", sky.lerp(Color("#bfe9f2"), 0.45))
	mirror_material.set_shader_parameter("sky_low", sky.lerp(Color("#f4f0ff"), 0.6))
	mirror_material.set_shader_parameter("glow", lamp_level * 0.5)

func _build_ground() -> void:
	var meadow := ShaderMaterial.new()
	meadow.shader = world.GRASS
	world.material_cache["circus:meadow"] = meadow
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 260)
	var lawn: MeshInstance3D = world._mesh(plane, Vector3(0, MEADOW_Y, 0), meadow)
	lawn.name = "CircusMeadow"
	lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Trodden earth under the whole camp, and the track that leads back to the avenue.
	var earth := kit.shore_ground("circus-earth", Color("#cdae7e"), Color("#9c7d55"), 0.5)
	kit.mound(Rect2(-13.5, -17.8, 27.0, 28.4), YARD_Y, 0.04, 1.6, earth, 0.7).name = "CircusYard"
	kit.mound(Rect2(-2.0, 9.6, 4.0, 32.0), YARD_Y - 0.008, 0.03, 0.9, earth, 2.9).name = "CircusTrack"
	# The welcome photo is taken from eye level south of the arch; this turf face
	# closes the gap its lowest rows would otherwise see under the lawn.
	var turf := QuadMesh.new()
	turf.size = Vector2(60, 8)
	var bank: MeshInstance3D = world._mesh(turf, Vector3(0, MEADOW_Y - 4.0, 13.4), meadow)
	bank.name = "CircusPhotoTurf"
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sawdust := kit.shore_ground("circus-sawdust", Color("#dcbd88"), Color("#a98c62"), 0.3)
	for area: Dictionary in world.AREAS:
		var rect: Rect2 = area.rect
		var center := rect.get_center()
		var floor_mesh: MeshInstance3D = world._box(Vector3(center.x, world.GROUND_Y - 0.15, center.y), Vector3(rect.size.x, 0.30, rect.size.y), area.tint, true)
		floor_mesh.name = "CircusFloor_" + String(area.id)
		world._set_registered_surface(floor_mesh, sawdust if int(area.tile) < 0 else world._coastal_surface(area.tile, 2.6, area.tint))

func _build_big_top() -> void:
	const SEGMENTS := 48
	var from := deg_to_rad(-6.0)
	var to := deg_to_rad(186.0)
	var foot := Props.arc(TOP_CENTER, TOP_RADIUS, from, to, SEGMENTS)
	var eave := Props.lifted(foot, TOP_WALL)
	var cut := Props.lifted(Props.arc(TOP_CENTER, TOP_RADIUS - 2.5, from, to, SEGMENTS), TOP_WALL + TOP_ROOF)
	var stripe := TOP_RADIUS * (to - from) / float(SEGMENTS)
	canvas.strip(eave, foot, Props.RED, stripe)
	canvas.strip(cut, eave, Props.RED, stripe)
	var brim := Props.lifted(Props.arc(TOP_CENTER, TOP_RADIUS - 0.14, from, to, SEGMENTS), TOP_WALL + 0.04)
	canvas.strip(brim, Props.lifted(brim, -0.66), Props.PLUM, stripe, 1.0, 0.03)
	var detail := kit.detail
	for index in range(0, SEGMENTS + 1, 6):
		var inside := foot[index].move_toward(TOP_CENTER, 0.16)
		detail.tube(inside + Vector3(0, TOP_WALL * 0.5, 0), 0.07, 0.06, TOP_WALL, Props.WOOD, 6)
		detail.tube(inside + Vector3(0, TOP_WALL + 0.05, 0), 0.11, 0.11, 0.1, Props.GOLD, 6)
		Props.line(detail, eave[index], cut[index], Props.ROPE, 0.05)
		detail.tube(cut[index] + Vector3(0, 0.12, 0), 0.09, 0.02, 0.24, Props.GOLD, 6)
		if index + 6 <= SEGMENTS:
			kit.bunting(cut[index], cut[index + 6], Props.PARTY, 0.5)
	# Guy ropes pin the two open ends of the wall.
	for end: int in [0, SEGMENTS]:
		var outward := (foot[end] - TOP_CENTER).normalized()
		for spread: float in [-0.5, 0.6]:
			var stake := foot[end] + outward.rotated(Vector3.UP, spread) * 2.6
			stake.y = MEADOW_Y
			Props.line(detail, eave[end], stake)
			detail.box(stake + Vector3(0, 0.12, 0), Vector3(0.09, 0.3, 0.09), Props.WOOD, Basis(Vector3.BACK, 0.3))
	_build_rigging()
	Props.bleachers(world, kit, BLEACHERS, BLEACHER_WIDTH, 4)
	for seat: Array in PLUSHES:
		var tier := int(seat[1])
		Props.plush(detail, BLEACHERS + Vector3(float(seat[0]), 0.45 + 0.4 * float(tier), -0.9 * float(tier) - 0.08), 0.3 * sin(float(seat[0]) * 3.0), seat[2], Color(str(seat[3])), 1.15)
	Props.drum(detail, DRUM, -1.0)
	Props.trunk(detail, Vector3(-3.5, YARD_Y, -12.9), 0.25, Props.TEAL, 0)
	Props.trunk(detail, Vector3(-4.3, YARD_Y, -14.3), -0.5, Props.PLUM, 1)
	Props.juggling(detail, Vector3(-3.5, YARD_Y, -14.0))
	Props.unicycle(detail, Vector3(-4.7, YARD_Y, -13.3), 0.5)
	Props.cannon(detail, CANNON, 0.25)
	world._local_label("人體大砲", CANNON + Vector3(0.2, 2.5, 0.2), 22)

## Four king poles carry the ropes, the string lights and everything that hangs over the ring.
func _build_rigging() -> void:
	var detail := kit.detail
	var tops: Array[Vector3] = []
	for index in range(KING_POLES.size()):
		var top := Props.pole(detail, KING_POLES[index], KING_HEIGHT, 0.14)
		tops.append(top)
		_flags.add(top + Vector3(0.05, 0.5, 0), Vector3.ONE, Basis.IDENTITY, Props.PARTY[index])
		detail.box(top + Vector3(0, 0.26, 0), Vector3(0.04, 0.6, 0.04), Props.WOOD)
		kit.blocker(KING_POLES[index] + Vector3(0, 1.0, 0), Vector3(0.5, 2.0, 0.5))
	for pair: Array in [[0, 1], [2, 3], [0, 2], [1, 3]]:
		_string_lights(tops[pair[0]], tops[pair[1]], 0.55)
	_string_lights((tops[0] + tops[1]) * 0.5 - Vector3(0, 0.55, 0), (tops[2] + tops[3]) * 0.5 - Vector3(0, 0.55, 0), 0.25)
	# Seam ropes run from the north poles out to the cut edge of the roof.
	for side: float in [-1.0, 1.0]:
		var top := tops[0 if side < 0.0 else 1]
		for degrees: float in [38.0, 68.0]:
			var angle := deg_to_rad(90.0 + side * (90.0 - degrees))
			var edge := TOP_CENTER + Vector3(cos(angle) * (TOP_RADIUS - 2.5), TOP_WALL + TOP_ROOF, -sin(angle) * (TOP_RADIUS - 2.5))
			_string_lights(top, edge, 0.5)
	# Lines of lights reach from the entrance arch up to the south poles.
	for side: float in [-1.0, 1.0]:
		_string_lights(Vector3(side * ARCH_HALF, MEADOW_Y + ARCH_HEIGHT + 0.3, ARCH_Z), tops[2 if side < 0.0 else 3], 1.6)

func _build_ring() -> void:
	var detail := kit.detail
	var ring: MeshInstance3D = world._cylinder(RING + Vector3(0, 0.012, 0), RING_RADIUS, 0.024, Props.CREAM)
	ring.name = "CircusRing"
	ring.material_override = kit.shore_ground("circus-ring", Color("#f0dcae"), Color("#b3956a"), 0.25)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in range(28):
		var turn := Basis(Vector3.UP, TAU * float(index) / 28.0)
		detail.box(RING + turn * Vector3(0, 0.11, RING_RADIUS + 0.15), Vector3(0.74, 0.22, 0.3), Props.RED if index % 2 == 0 else Props.CREAM, turn)
		detail.box(RING + turn * Vector3(0, 0.235, RING_RADIUS + 0.15), Vector3(0.74, 0.03, 0.2), Props.GOLD, turn)
		if index % 4 == 1:
			kit.glow.box(RING + turn * Vector3(0, 0.1, RING_RADIUS + 0.46), Vector3(0.2, 0.14, 0.12), Kit.WARM_GLOW, turn)
			detail.box(RING + turn * Vector3(0, 0.04, RING_RADIUS + 0.5), Vector3(0.28, 0.08, 0.2), Props.IRON, turn)
	# The cannon's landing mat lies in the middle of the ring.
	var mat: MeshInstance3D = world._cylinder(RING + Vector3(0, 0.05, 0), 1.42, 0.05, Props.TEAL)
	mat.name = "CircusPaddedLanding"
	mat.material_override = world._coastal_surface(6, 1.3, Color("#f2e6f4"))
	detail.tube(RING + Vector3(0, 0.035, 0), 1.5, 1.52, 0.03, Props.GOLD, 20)
	for point in range(5):
		var turn := Basis(Vector3.UP, TAU * float(point) / 5.0)
		detail.tri(RING + turn * Vector3(0, 0.08, 0.62), RING + turn * Vector3(-0.2, 0.08, 0.2), RING + turn * Vector3(0.2, 0.08, 0.2), Props.GOLD)
	detail.tube(RING + Vector3(0, 0.078, 0), 0.28, 0.28, 0.006, Props.GOLD, 10)
	# Confetti from the last show still lies around the ring and the entrance.
	for speck in range(90):
		var seed_value := 4.7 * float(speck)
		var home := RING if speck < 60 else Vector3(0, YARD_Y, ARCH_Z - 2.0)
		var spread := 7.5 if speck < 60 else 4.0
		var at := home + Vector3((_scatter(seed_value) - 0.5) * 2.0 * spread, 0, (_scatter(seed_value + 1.3) - 0.5) * spread)
		at.y = world.ground_surface_y(at) + (0.032 if world._on_floor_plan(Vector2(at.x, at.z)) else 0.035)
		detail.box(at, Vector3(0.09, 0.012, 0.06), Props.PARTY[speck % Props.PARTY.size()], Basis(Vector3.UP, seed_value))

## Rows of benches either side of the aisle, with the runner that leads to the ring.
func _build_stalls() -> void:
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		for row: Array in STALL_ROWS:
			var at := Vector3(side * STALL_X, world.GROUND_Y, float(row[0]))
			Props.bench(world, kit, at, 2.2, float(row[1]))
			kit.blocker(at + Vector3(0, 0.75, 0), Vector3(2.2, 1.5, 0.66))
		var rail_x := side * 3.68
		for post in range(5):
			var z := -3.5 + 1.525 * float(post)
			detail.box(Vector3(rail_x, world.GROUND_Y + 0.48, z), Vector3(0.08, 0.96, 0.08), Props.GOLD.darkened(0.15))
			detail.tube(Vector3(rail_x, world.GROUND_Y + 1.02, z), 0.08, 0.02, 0.12, Props.GOLD, 6)
		for height: float in [0.5, 0.9]:
			detail.box(Vector3(rail_x, world.GROUND_Y + height, -0.45), Vector3(0.05, 0.05, 6.1), Props.RED if height < 0.7 else Props.GOLD)
		kit.blocker(Vector3(rail_x, world.GROUND_Y + 0.75, -0.45), Vector3(0.12, 1.5, 6.1))
	var floor_y: float = world.GROUND_Y + 0.012
	var middle := PackedVector3Array([Vector3(0, floor_y, 9.4), Vector3(0, floor_y, -5.1)])
	for side: float in [-1.0, 1.0]:
		var edge := PackedVector3Array([Vector3(side * 0.8, floor_y, 9.4), Vector3(side * 0.8, floor_y, -5.1)])
		canvas.strip(middle, edge, Props.RED, 0.725)
		detail.box(Vector3(side * 0.83, floor_y + 0.004, 2.15), Vector3(0.06, 0.02, 14.5), Props.GOLD)

func _build_forecourt() -> void:
	# The arch may cover the player on the way in, so it opens like the Welcome arches.
	world.occlusion_controller.begin_building()
	var board: MeshInstance3D = world._box(Vector3(0, MEADOW_Y + ARCH_HEIGHT + 0.45, ARCH_Z), Vector3(ARCH_BOARD.x, ARCH_BOARD.y, 0.28), Props.PLUM)
	world._set_registered_surface(board, world._coastal_surface(3, 1.4, Color("#b693c9")))
	var trim := Kit.Sculpt.new()
	var crown := MEADOW_Y + ARCH_HEIGHT + 0.3
	for side: float in [-1.0, 1.0]:
		var top := Props.pole(trim, Vector3(side * ARCH_HALF, MEADOW_Y, ARCH_Z), ARCH_HEIGHT, 0.24)
		_flags.add(top + Vector3(0.05, 0.55, 0), Vector3.ONE, Basis.IDENTITY, Props.GOLD if side < 0.0 else Props.ROSE)
		trim.box(top + Vector3(0, 0.3, 0), Vector3(0.04, 0.64, 0.04), Props.WOOD)
	# A bow of painted segments over the name board, each carrying a marquee bulb.
	var bow := PackedVector3Array()
	for index in range(15):
		var across := float(index) / 14.0 * 2.0 - 1.0
		bow.append(Vector3(across * ARCH_HALF, crown + 0.78 * (1.0 - across * across), ARCH_Z))
	for index in range(bow.size() - 1):
		var span := bow[index + 1] - bow[index]
		trim.box((bow[index] + bow[index + 1]) * 0.5, Vector3(span.length() + 0.04, 0.26, 0.3), Props.RED if index % 2 == 0 else Props.CREAM, Basis(Vector3.BACK, atan2(span.y, span.x)))
		_bulb((bow[index] + bow[index + 1]) * 0.5 + Vector3(0, 0, 0.2), Kit.WARM_GLOW, true, 0.17)
	var board_at := board.position
	for edge: float in [-1.0, 1.0]:
		trim.box(board_at + Vector3(0, edge * (ARCH_BOARD.y * 0.5 + 0.03), 0), Vector3(ARCH_BOARD.x + 0.2, 0.09, 0.36), Props.GOLD)
		trim.box(board_at + Vector3(edge * (ARCH_BOARD.x * 0.5 + 0.05), 0, 0), Vector3(0.1, ARCH_BOARD.y + 0.14, 0.36), Props.GOLD)
		trim.box(board_at + Vector3(edge * 2.75, 0, 0.16), Vector3(0.28, 0.28, 0.05), Props.GOLD, Basis(Vector3.BACK, PI * 0.25))
		for bulb in range(11):
			_bulb(board_at + Vector3(-3.0 + 0.6 * float(bulb), edge * (ARCH_BOARD.y * 0.5 + 0.03), 0.22), Kit.WARM_GLOW, true, 0.13)
	var arch: MeshInstance3D = world._mesh(trim.mesh(), Vector3.ZERO, world._vertex_color_material("scenery-detail"))
	arch.name = "CircusEntranceArch"
	# Not a local label: the cutaway restores a title to how it was registered.
	var title: Label3D = world._label("鏡之馬戲團", board_at + kit.view_basis.z * 0.6, 38, Props.CREAM)
	world.occlusion_controller.register_visibility_label(title)
	var footing := kit.blocker(Vector3(ARCH_HALF, MEADOW_Y + 1.2, ARCH_Z), Vector3(0.8, 2.4, 0.8))
	kit.blocker(Vector3(-ARCH_HALF, MEADOW_Y + 1.2, ARCH_Z), Vector3(0.8, 2.4, 0.8))
	world.occlusion_controller.finish_building(footing)
	# The title hangs above the welcome photo and belongs to the cutaway, so it stays out of this list.
	photo_clutter.append_array([board, arch])
	Props.ticket_booth(world, kit, canvas, TICKET_BOOTH)
	Props.calliope(world, kit, CALLIOPE, 0.0)
	world._local_label("蒸汽風琴", CALLIOPE + Vector3(0, 3.5, 0.3), 22)
	HarborProps.signpost(world, kit, Vector3(-7.2, MEADOW_Y, 12.4), "迎賓大道 ↓", 2.2)
	# Game 049 keeps its pitch in the foyer; the cabinet steps out of the welcome photo.
	photo_clutter.append(_cabinet(world.PHOTO_BOOTH, "哈哈鏡大頭貼", Props.RED, "oval", 2.0))

func _build_mirror_gallery() -> void:
	var detail := kit.detail
	# A dais along the west wall carries the angled funhouse mirrors.
	kit.surface(world._coastal_surface(0, 1.6, Color("#d9cfe6"))).add(Vector3(WALL_MIRROR_X - 0.1, world.GROUND_Y + 0.02, 0.2), Vector3(1.5, 0.36, 10.6))
	var angled := Basis(Vector3.UP, PI * 0.25)
	for index in range(WALL_MIRRORS.size()):
		var spec: Array = WALL_MIRRORS[index]
		var foot := Vector3(WALL_MIRROR_X, world.GROUND_Y + 0.2, float(spec[0]))
		detail.box(foot + Vector3(0, 0.12, 0), Vector3(float(spec[2]) + 0.4, 0.24, 0.4), Props.NIGHT, angled)
		Props.mirror(detail, glass, Transform3D(angled, foot + Vector3(0, 0.26, 0)), spec[1], Vector2(float(spec[2]), float(spec[3])), spec[4])
		# A candy-striped post with a lamp stands between neighbours.
		var post := Vector3(WALL_MIRROR_X - 0.2, world.GROUND_Y + 0.2, float(spec[0]) - 1.05)
		var top := Props.pole(detail, post, 2.5, 0.07, [Props.PLUM, Props.CREAM])
		kit.glow.tube(top + Vector3(0, 0.06, 0), 0.11, 0.07, 0.18, Kit.WARM_GLOW, 6)
		if index > 0:
			_string_lights(top + Vector3(0, -0.2, 2.1), top + Vector3(0, -0.2, 0), 0.3)
	for index in range(HALL_MIRRORS.size()):
		var spec: Array = HALL_MIRRORS[index]
		var frame := Transform3D(Basis.IDENTITY, Vector3(float(spec[0]), world.GROUND_Y, HALL_MIRROR_Z))
		Props.mirror_stand(detail, frame, 1.5, 0.28)
		Props.mirror(detail, glass, frame * Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0.06)), spec[1], Vector2(1.5, 1.72), spec[2])
		kit.blocker(frame.origin + Vector3(0, 1.0, 0), Vector3(1.7, 2.0, 0.6))
	_plaque("鏡廊 · 走近看看自己", Vector3(-7.0, world.GROUND_Y, -3.3), 2.9)
	_floor_star(world.MIRRORS, Props.SKY)
	# Game 050 keeps its pitch at the west end of the hall.
	_cabinet(world.REFLECTION_STAND, "誰是假倒影", Props.PLUM, "arch", 1.9)

## The stage, proscenium and lamp rail around the projection the world owns.
func _build_shadow_theatre() -> void:
	var detail := kit.detail
	var origin := Vector3(world.SHADOW_STAGE.x, world.GROUND_Y, 0)
	kit.surface(world._coastal_surface(1, 1.7, Color("#e2c9a4"))).add(origin + Vector3(0, 0.108, -2.85), Vector3(5.6, 0.21, 2.64))
	kit.surface(world._coastal_surface(3, 1.5, Color("#9c7fb0"))).add(origin + Vector3(0, 1.52, -4.02), Vector3(4.9, 2.95, 0.2))
	kit.blocker(origin + Vector3(0, 1.52, -3.98), Vector3(5.2, 3.0, 0.4))
	detail.frame = Transform3D(Basis.IDENTITY, origin)
	for index in range(14):
		detail.box(Vector3(-2.6 + 0.4 * float(index), 0.11, -1.52), Vector3(0.4, 0.2, 0.04), Props.RED if index % 2 == 0 else Props.CREAM)
	detail.box(Vector3(0, 0.215, -1.53), Vector3(5.66, 0.04, 0.1), Props.GOLD)
	for side: float in [-1.0, 1.0]:
		# Proscenium column with a gilt capital and a finial.
		for band in range(6):
			detail.box(Vector3(side * 2.45, 0.46 + 0.5 * float(band), -3.84), Vector3(0.34, 0.5, 0.34), Props.PLUM if band % 2 == 0 else Props.PLUM.lightened(0.16))
		detail.box(Vector3(side * 2.45, 3.26, -3.84), Vector3(0.46, 0.12, 0.46), Props.GOLD)
		detail.tube(Vector3(side * 2.45, 3.46, -3.84), 0.16, 0.03, 0.28, Props.GOLD, 6)
		detail.box(Vector3(side * 2.27, 1.66, -3.7), Vector3(0.07, 2.84, 0.08), Props.GOLD)
		# The lamp housing at each end of the rail.
		detail.box(Vector3(side * 2.42, 0.4, -1.4), Vector3(0.42, 0.16, 0.35), Props.IRON)
		detail.box(Vector3(side * 2.42, 0.65, -1.4), Vector3(0.38, 0.1, 0.31), Props.GOLD)
	for edge: float in [0.2, 3.08]:
		detail.box(Vector3(0, edge, -3.7), Vector3(4.64, 0.07, 0.08), Props.GOLD)
	detail.box(Vector3(0, 0.32, -1.05), Vector3(2.96, 0.07, 0.07), Props.GOLD)
	for post in range(5):
		detail.box(Vector3(-1.44 + 0.72 * float(post), 0.2, -1.05), Vector3(0.06, 0.3, 0.06), Props.GOLD.darkened(0.2))
	detail.box(Vector3(0, 0.76, -0.9), Vector3(2.5, 0.42, 0.08), Props.NIGHT)
	detail.box(Vector3(0, 0.53, -0.88), Vector3(2.5, 0.05, 0.1), Props.GOLD)
	detail.frame = Transform3D.IDENTITY
	kit.glow.frame = Transform3D(Basis.IDENTITY, origin)
	for side: float in [-1.0, 1.0]:
		kit.glow.box(Vector3(side * 2.42, 0.53, -1.4), Vector3(0.27, 0.16, 0.22), Kit.WARM_GLOW)
	for foot in range(5):
		kit.glow.box(Vector3(-2.0 + float(foot), 0.27, -1.66), Vector3(0.24, 0.1, 0.14), Kit.WARM_GLOW)
	kit.glow.frame = Transform3D.IDENTITY
	# A scalloped pelmet names the theatre.
	var pelmet := PackedVector3Array([origin + Vector3(-2.7, 3.72, -3.62), origin + Vector3(2.7, 3.72, -3.62)])
	canvas.strip(pelmet, Props.lifted(pelmet, -0.78), Props.RED, 0.45, 1.0, 0.012)
	photo_clutter.append(world._local_label("影子台", origin + Vector3(0, 3.42, -3.5), 28, Props.CREAM))
	lamp_plaque = world._local_label("", origin + Vector3(0, 0.78, -0.82), 22, Props.CREAM)
	photo_clutter.append(lamp_plaque)
	_floor_star(world.SHADOW_STAGE, Props.GOLD)
	# Backstage is roped off: the screen would hide anyone who walked behind it.
	for run: Array in [[Vector3(4.75, 0, -7.7), Vector3(4.75, 0, -3.95)], [Vector3(4.75, 0, -7.7), Vector3(8.8, 0, -7.7)]]:
		_rope_fence(run[0] + Vector3(0, world.GROUND_Y, 0), run[1] + Vector3(0, world.GROUND_Y, 0))
	Props.trunk(detail, Vector3(10.75, world.GROUND_Y, -4.75), -PI * 0.5, Props.RED, 2)
	detail.box(Vector3(10.7, world.GROUND_Y + 0.3, -4.2), Vector3(0.6, 0.6, 0.5), Props.PALE_WOOD.darkened(0.1), Basis(Vector3.UP, 0.2))
	kit.blocker(Vector3(10.7, world.GROUND_Y + 1.0, -4.6), Vector3(0.5, 2.0, 1.3))

func _build_pitches() -> void:
	var taken: Dictionary = {}
	for stand: Dictionary in world.PITCH_GAMES:
		taken[stand.pitch] = stand
	for index in range(world.PITCHES.size()):
		var at: Vector3 = world.PITCHES[index]
		# The foyer pitch stands in the welcome photo's view.
		var in_photo := at.z > 5.0
		if not taken.has(index):
			Props.pitch(foreground if in_photo else kit.detail, at, Props.PARTY[index % 4])
			continue
		var stand: Dictionary = taken[index]
		var cabinet := _cabinet(at, stand.title, stand.body, stand.shape, 0.5 + 0.36 * stand.title.length(), stand.topper)
		if in_photo:
			photo_clutter.append(cabinet)

## Wagons, small tents, canvas sidewalls, banner poles and crates around the yard.
func _build_camp() -> void:
	var detail := kit.detail
	for post in LAMP_POSTS:
		kit.lamp_post(post)
	for spec: Array in TENTS:
		var ground := Vector3(float(spec[0]), MEADOW_Y, float(spec[1]))
		var tip := Props.tent(canvas, detail, ground, float(spec[2]), float(spec[3]), float(spec[4]), Color(str(spec[5])))
		_flags.add(tip + Vector3(0.03, 0.0, 0), Vector3(0.7, 0.7, 1.0), Basis.IDENTITY, Props.GOLD)
		for guy in range(5):
			var outward := Vector3(cos(TAU * float(guy) / 5.0 + 0.4), 0, sin(TAU * float(guy) / 5.0 + 0.4))
			Props.line(detail, ground + outward * (float(spec[2]) + 0.2) + Vector3(0, float(spec[3]), 0), ground + outward * (float(spec[2]) + 1.5))
	for index in range(WAGONS.size()):
		var spec: Array = WAGONS[index]
		Props.wagon(world, kit, Vector3(float(spec[0]), MEADOW_Y, float(spec[1])), float(spec[2]), Color(str(spec[3])), index)
	# Canvas sidewalls close the back of the yard either side of the big top.
	for side: float in [-1.0, 1.0]:
		var run := PackedVector3Array()
		for corner: Vector2 in [Vector2(10.95, -8.7), Vector2(15.2, -9.8), Vector2(22.0, -9.3), Vector2(30.5, -10.8)]:
			run.append(Vector3(side * corner.x, MEADOW_Y, corner.y))
		canvas.strip(Props.lifted(run, 2.3), run, Props.TEAL, 0.7)
		for index in range(run.size()):
			var top := Props.pole(detail, run[index], 2.5, 0.06, [Props.CREAM, Props.GOLD])
			if index > 0:
				_flags.add(top + Vector3(0.03, 0.0, 0), Vector3(0.6, 0.6, 1.0), Basis.IDENTITY, Props.PARTY[index])
	var tops: Array[Vector3] = []
	for index in range(BANNER_POLES.size()):
		var spec: Array = BANNER_POLES[index]
		var top := Props.pole(detail, Vector3(float(spec[0]), MEADOW_Y, float(spec[1])), float(spec[2]), 0.08, [Props.CREAM, Props.GOLD])
		_flags.add(top + Vector3(0.04, 0.02, 0), Vector3.ONE, Basis.IDENTITY, Props.PARTY[index % Props.PARTY.size()])
		tops.append(top)
	# Bunting reaches from the arch out to the banner poles and on into the trees.
	for side in range(2):
		var pylon := Vector3((-1.0 if side == 0 else 1.0) * ARCH_HALF, MEADOW_Y + ARCH_HEIGHT + 0.2, ARCH_Z)
		kit.bunting(pylon, tops[side] - Vector3(0, 0.4, 0), Props.PARTY, 0.9)
		kit.bunting(pylon, tops[2 + side] - Vector3(0, 0.4, 0), Props.PARTY, 0.5)
		kit.bunting(tops[side] - Vector3(0, 0.4, 0), tops[4 + side] - Vector3(0, 0.4, 0), Props.PARTY, 1.3)
		kit.bunting(tops[4 + side] - Vector3(0, 0.4, 0), tops[6 + side] - Vector3(0, 0.3, 0), Props.PARTY, 0.8)
	for index in range(CRATES.size()):
		HarborProps.cargo(kit, CRATES[index], index)
	HarborProps.bench(kit, Vector3(5.6, MEADOW_Y, 12.2), -0.5)
	for plant: Array in PLANTS:
		kit.billboard(str(plant[0]), Vector3(float(plant[1]), MEADOW_Y, float(plant[2])), float(plant[3]))

## The woods close the clearing on every side; they are scattered once from fixed numbers.
func _build_woods() -> void:
	var kinds := ["oak", "pine", "oak", "ginkgo", "oak", "pine", "ginkgo"]
	for column in range(-12, 13):
		for row in range(-14, 12):
			var seed_value := float(column) * 7.31 + float(row) * 3.17
			var at := Vector2(float(column) * 3.1 + (_scatter(seed_value) - 0.5) * 2.2, float(row) * 3.1 + (_scatter(seed_value + 1.7) - 0.5) * 2.2)
			if _in_clearing(at): continue
			kit.grove(kinds[int(_scatter(seed_value + 3.3) * 6.99)], Vector3(at.x, MEADOW_Y, at.y), 4.0 + 1.3 * _scatter(seed_value + 5.1))

func _in_clearing(at: Vector2) -> bool:
	if pow(at.x / 23.0, 4.0) + pow((at.y - 0.5) / 23.5, 4.0) < 1.0: return true
	if absf(at.x) < 3.6 and at.y > 9.0: return true
	for spec: Array in TENTS:
		if at.distance_to(Vector2(float(spec[0]), float(spec[1]))) < float(spec[2]) + 2.2: return true
	return false

## Repeatable 0..1 scatter value, so the woods are identical on every visit.
func _scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)

func _commit() -> void:
	var cloth := ShaderMaterial.new()
	cloth.shader = CANVAS
	world.material_cache["circus:canvas"] = cloth
	world.component_motion.register_shader(cloth)
	world._mesh(canvas.mesh(), Vector3.ZERO, cloth).name = "CircusCanvas"
	mirror_material = ShaderMaterial.new()
	mirror_material.shader = MIRROR
	mirror_material.set_shader_parameter("floor_y", world.GROUND_Y)
	world.material_cache["circus:mirror"] = mirror_material
	world.component_motion.register_shader(mirror_material)
	var panes: MeshInstance3D = world._mesh(glass.mesh(), Vector3.ZERO, mirror_material)
	panes.name = "CircusMirrors"
	panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var near_trim: MeshInstance3D = world._mesh(foreground.mesh(), Vector3.ZERO, world._vertex_color_material("scenery-detail"))
	near_trim.name = "CircusForeground"
	photo_clutter.append(near_trim)
	var bulb := SphereMesh.new()
	bulb.radius = 0.5
	bulb.height = 1.0
	bulb.radial_segments = 6
	bulb.rings = 3
	chase_bulbs = _bulb_batch("CircusMarqueeBulbs", bulb, _chase_spots, _chase_tints, 1.1)
	shimmer_bulbs = _bulb_batch("CircusStringLights", bulb, _shimmer_spots, _shimmer_tints, 0.0)

func _bulb_batch(label: String, mesh: Mesh, spots: Array[Transform3D], tints: Array[Color], chase: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BULBS
	material.set_shader_parameter("chase", chase)
	world.material_cache["circus:" + label] = material
	world.component_motion.register_shader(material)
	var bulbs: MultiMeshInstance3D = world._multi_mesh(mesh, Vector3.ZERO, spots, tints, material)
	bulbs.name = label
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return material

func _bulb(at: Vector3, tint: Color, chase := false, size := 0.11) -> void:
	var tints := _chase_tints if chase else _shimmer_tints
	var packed := tint.srgb_to_linear()
	# The alpha is the bulb's place in its run, which the shader turns into a phase.
	packed.a = float(tints.size() % 64) / 64.0
	(_chase_spots if chase else _shimmer_spots).append(Transform3D(Basis.from_scale(Vector3.ONE * size), at))
	tints.append(packed)

## A sagging wire with a coloured bulb every half metre or so.
func _string_lights(from: Vector3, to: Vector3, sag: float) -> void:
	var points := Props.sagging(from, to, sag, maxi(4, int(from.distance_to(to) / 0.6)))
	for index in range(points.size() - 1):
		Props.line(kit.detail, points[index], points[index + 1], WIRE, 0.025)
		if index > 0:
			_bulb(points[index] - Vector3(0, 0.07, 0), [Kit.WARM_GLOW, Props.ROSE, Kit.WARM_GLOW, Props.SKY][index % 4])

## Arcade cabinet of a delivered game with its name board. It can cover whoever
## walks behind it, so it opens like a building. Returns the cabinet's mesh.
func _cabinet(at: Vector3, title: String, body: Color, shape: String, board_width: float, topper := "") -> MeshInstance3D:
	world.occlusion_controller.begin_building()
	var sculpt := Kit.Sculpt.new()
	Props.cabinet(sculpt, Transform3D(Basis.IDENTITY, at), body, shape)
	_topper(sculpt, at + Vector3(0, 2.22, 0.1), topper)
	_plaque(title, at + Vector3(0, 0.9, 0), board_width, sculpt)
	var cabinet: MeshInstance3D = world._mesh(sculpt.mesh(), Vector3.ZERO, world._vertex_color_material("scenery-detail"))
	cabinet.name = "CircusCabinet_" + title
	world.occlusion_controller.finish_building(kit.blocker(at + Vector3(0, 1.0, 0), Vector3(1.1, 2.0, 0.76)))
	return cabinet

## The little act on a cabinet's canopy that says which game it is.
func _topper(sculpt: Kit.Sculpt, top: Vector3, kind: String) -> void:
	match kind:
		"plates":
			# A juggling stick with a leaning stack of plates, and one in mid-flight.
			sculpt.box(top + Vector3(0.0, 0.3, 0), Vector3(0.05, 0.6, 0.05), Props.WOOD)
			for plate in range(4):
				sculpt.tube(top + Vector3(0.02 * plate, 0.62 + 0.07 * plate, 0), 0.2, 0.22, 0.05, Props.CREAM if plate % 2 == 0 else Props.SKY, 10)
			sculpt.tube(top + Vector3(0.42, 0.78, 0.05), 0.16, 0.16, 0.04, Props.CREAM, 10, Basis(Vector3.BACK, 0.7))
		"cannon":
			# A little striped cannon aimed over the canopy with a helmeted clown in its mouth.
			var aim := Basis(Vector3.BACK, -0.75)
			sculpt.box(top + Vector3(0, 0.12, 0), Vector3(0.5, 0.2, 0.36), Props.WOOD)
			for side: float in [-1.0, 1.0]:
				sculpt.tube(top + Vector3(side * 0.18, 0.14, 0.2), 0.14, 0.14, 0.05, Props.IRON, 8, Basis(Vector3.RIGHT, PI * 0.5))
			sculpt.tube(top + Vector3(0.08, 0.5, 0), 0.15, 0.12, 0.8, Props.RED, 8, aim)
			sculpt.tube(top + Vector3(0.16, 0.58, 0), 0.16, 0.16, 0.06, Props.GOLD, 8, aim)
			sculpt.tube(top + Vector3(0.36, 0.82, 0), 0.13, 0.08, 0.14, Props.RED.lightened(0.2), 8, aim)
		"wire":
			# Two striped masts with a wire between them and a tiny walker with his pole.
			for side: float in [-1.0, 1.0]:
				sculpt.box(top + Vector3(side * 0.62, 0.42, 0), Vector3(0.06, 0.84, 0.06), Props.RED if side < 0.0 else Props.CREAM)
				sculpt.box(top + Vector3(side * 0.62, 0.84, 0), Vector3(0.18, 0.04, 0.14), Props.WOOD)
			sculpt.box(top + Vector3(0, 0.86, 0), Vector3(1.24, 0.02, 0.02), Props.IRON)
			sculpt.box(top + Vector3(0.1, 1.04, 0), Vector3(0.1, 0.18, 0.08), Props.TEAL)
			sculpt.box(top + Vector3(0.1, 1.18, 0), Vector3(0.08, 0.08, 0.08), Props.CREAM)
			sculpt.box(top + Vector3(0.1, 1.06, 0.04), Vector3(0.7, 0.02, 0.02), Props.GOLD, Basis(Vector3.BACK, 0.12))

## Name board with its label. On the ground it stands on two legs; with `sculpt`
## set it rides on a cabinet and is drawn into that cabinet's mesh.
func _plaque(title: String, ground: Vector3, width: float, sculpt: Kit.Sculpt = null) -> Label3D:
	var standing := sculpt == null
	if standing: sculpt = kit.detail
	var at := ground + Vector3(0, 1.72, 0)
	sculpt.box(at, Vector3(width, 0.46, 0.1), Props.NIGHT)
	for edge: float in [-1.0, 1.0]:
		sculpt.box(at + Vector3(0, edge * 0.25, 0), Vector3(width + 0.1, 0.06, 0.14), Props.GOLD)
		sculpt.tube(at + Vector3(edge * (width * 0.5 + 0.02), 0.34, 0), 0.07, 0.02, 0.12, Props.GOLD, 6)
		if standing:
			sculpt.box(ground + Vector3(edge * (width * 0.5 - 0.1), 0.74, -0.02), Vector3(0.08, 1.48, 0.08), Props.WOOD)
	var label: Label3D = world._local_label(title, at + Vector3(0, 0.01, 0.12), 24, Props.CREAM)
	photo_clutter.append(label)
	return label

## Brass star set into the floor where a point of interest is.
func _floor_star(at: Vector3, tint: Color) -> void:
	for point in range(8):
		var turn := Basis(Vector3.UP, TAU * float(point) / 8.0)
		kit.detail.tri(at + turn * Vector3(0, 0.014, 0.5), at + turn * Vector3(-0.12, 0.014, 0.16), at + turn * Vector3(0.12, 0.014, 0.16), tint if point % 2 == 0 else Props.GOLD)

## Brass stanchions joined by a red rope, with the collision that goes with them.
func _rope_fence(from: Vector3, to: Vector3) -> void:
	var count := maxi(2, roundi(from.distance_to(to) / 1.3))
	for index in range(count + 1):
		var post := from.lerp(to, float(index) / float(count))
		kit.detail.tube(post + Vector3(0, 0.03, 0), 0.16, 0.14, 0.06, Props.GOLD.darkened(0.2), 8)
		kit.detail.tube(post + Vector3(0, 0.5, 0), 0.04, 0.04, 0.9, Props.GOLD, 6)
		kit.detail.tube(post + Vector3(0, 0.99, 0), 0.08, 0.03, 0.1, Props.GOLD.lightened(0.15), 6)
		if index < count:
			var points := Props.sagging(post + Vector3(0, 0.9, 0), from.lerp(to, float(index + 1) / float(count)) + Vector3(0, 0.9, 0), 0.14, 4)
			for link in range(points.size() - 1):
				Props.line(kit.detail, points[link], points[link + 1], Props.RED, 0.06)
	var middle := (from + to) * 0.5
	var along_x := absf(to.x - from.x) > absf(to.z - from.z)
	kit.blocker(middle + Vector3(0, 1.0, 0), Vector3(from.distance_to(to), 2.0, 0.3) if along_x else Vector3(0.3, 2.0, from.distance_to(to)))
