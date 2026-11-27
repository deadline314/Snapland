extends RefCounted
## Everything in the tidal harbor that never moves on its own: sea, ground, quay edges,
## piers, landmarks and dressing. Built once through the scenery kit; it keeps the few
## parts that the tide and the time of day change.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/harbor_props.gd")
## Sand that low water uncovers: the bank under the sandbar, then flats nobody walks on.
const SANDBAR_BANK := Rect2(-9.55, -1.83, 6.1, 3.66)
const SANDBAR_SINK := 0.5
const FLAT_TOP := -0.2
const FLATS: Array[Rect2] = [
	Rect2(-4.7, -5.0, 10.0, 9.6), Rect2(6.0, 5.2, 2.6, 2.4),
	Rect2(-8.6, -7.6, 2.4, 2.0), Rect2(-17.4, 7.6, 2.2, 4.2),
]
## A sandy islet out to sea gives the western horizon something to look at.
const ISLET := Rect2(-27.6, 11.4, 3.6, 2.8)
const LIGHTHOUSE_AT := Vector3(2.4, 0.2, -2.4)
const TIDE_CLOCK_AT := Vector3(-12, 0.2, -2.7)
## Water-facing edges: from (x, z), to (x, z), outward (x, z), 1 for timber or 0 for stone.
const EDGES := [
	[-15, -12, -15, 3.7, -1, 0, 0], [-15, 6.3, -15, 12, -1, 0, 0], [-15, 12, -9, 12, 0, 1, 0],
	[-15, -12, -5.25, -12, 0, -1, 0], [-2.75, -12, -1.25, -12, 0, -1, 0], [1.25, -12, 2.75, -12, 0, -1, 0], [5.25, -12, 9, -12, 0, -1, 0],
	[-9, -8, -9, -1.75, 1, 0, 0], [-9, 1.75, -9, 8, 1, 0, 0], [-9, -8, -1.1, -8, 0, 1, 0], [1.1, -8, 9, -8, 0, 1, 0],
	[-4, -4, -1.1, -4, 0, -1, 0], [1.1, -4, 4, -4, 0, -1, 0], [4, -4, 4, 4, 1, 0, 0], [-4, 4, 4, 4, 0, 1, 0],
	[-4, -4, -4, -1.75, -1, 0, 0], [-4, 1.75, -4, 4, -1, 0, 0],
	[15, -12, 15, 1.9, 1, 0, 1], [15, 3.6, 15, 12, 1, 0, 1], [9, -12, 10.75, -12, 0, -1, 1], [13.25, -12, 15, -12, 0, -1, 1], [-9, 12, 15, 12, 0, 1, 1],
	[9, -8, 9, 8, -1, 0, 1], [-9, 8, -5.25, 8, 0, -1, 1], [-2.75, 8, -1.25, 8, 0, -1, 1], [1.25, 8, 2.75, 8, 0, -1, 1], [5.25, 8, 9, 8, 0, -1, 1],
	[-1, -8, -1, -4, -1, 0, 1], [1, -8, 1, -4, 1, 0, 1],
]
## Six posts, the lighthouse door lamp and the beam make eight lights: all stay lit.
const LAMP_POSTS: Array[Vector3] = [
	Vector3(-14.1, 0.2, 11.0), Vector3(-10.1, 0.2, 3.1), Vector3(2.4, 0.2, -8.75),
	Vector3(10.1, 0.2, -8.6), Vector3(10.1, 0.2, 4.0), Vector3(2.0, 0.2, 8.5),
]
## Billboards: kind, x, ground y, z, height. Plants on the quays keep 1.5 m from the water.
const PLANTS := [
	["palm", -2.4, 0.2, -2.4, 4.15], ["palm", -13.3, 0.2, -6.4, 4.15], ["pine", -13.2, 0.2, -10.2, 4.4],
	["shrub", 2.4, 0.2, 2.4, 1.25], ["shrub", -13.4, 0.2, -8.3, 1.25],
	["planter", 10.6, 0.2, -2.7, 1.7], ["planter", -6.8, 0.2, -10.4, 1.7], ["planter", 6.9, 0.2, -10.4, 1.7], ["planter", 7.2, 0.2, 9.6, 1.7],
	["palm", -25.6, 0.2, 12.9, 4.0], ["shrub", -26.7, 0.2, 13.3, 1.1],
]
const CARGO: Array[Vector3] = [Vector3(-14.1, 0.2, -4.6), Vector3(14.1, 0.2, -7.4), Vector3(14.1, 0.2, 8.0), Vector3(-2.0, 0.2, -11.3), Vector3(8.3, 0.2, 11.2)]
## Lobster pots: x, y, z, yaw.
const POTS := [[16.3, 0.14, 2.3, 0.3], [-12.6, 0.2, 11.3, 0.0], [10.2, 0.2, 11.2, -0.4], [-10.2, 0.2, -6.6, 1.2]]
## Rock clusters: centre x, z, count, spread x, z, largest size. Riprap against the
## outer walls first, then rocks in the lagoon and by the islet, then sea stacks.
const ROCKS := [
	[-10.0, -12.9, 7, 4.2, 0.4, 0.9], [11.5, -12.9, 5, 3.0, 0.4, 0.9], [-15.8, -6.0, 8, 0.4, 5.0, 0.9], [-15.8, 1.2, 3, 0.3, 1.4, 0.8],
	[15.8, -6.5, 5, 0.4, 4.0, 0.9], [8.2, -7.3, 3, 0.5, 0.4, 0.7], [-17.0, 12.2, 4, 1.4, 0.6, 0.9], [-28.4, 12.2, 3, 0.4, 1.3, 0.9],
	[-23.0, -10.0, 5, 1.6, 1.2, 1.7], [21.0, -17.0, 4, 1.4, 1.0, 1.6], [25.0, 6.0, 5, 1.3, 1.5, 1.7], [-20.0, 18.0, 4, 1.5, 1.0, 1.5], [7.0, 21.5, 4, 1.6, 0.9, 1.4], [-4.0, -19.5, 4, 1.8, 1.0, 1.5],
]
const PENNANT_COLORS: Array[Color] = [Props.CORAL, Props.CREAM, Props.GOLD, Color("#5fa7a4")]

var world: Node3D
var kit: Kit
var sea: MeshInstance3D
var sandbar_bank: MeshInstance3D
var sandbar_body: StaticBody3D
var tide_label: Label3D
var tide_hand: MeshInstance3D
var tide_bell: MeshInstance3D
var lantern_glass: MeshInstance3D
var beam_rotor: Node3D
var beam_material: ShaderMaterial
var _ground_y: float
var _low_water: float
var _lighthouse_top := 0.0

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit
	_ground_y = owner.GROUND_Y
	_low_water = owner.LOW_WATER

func build() -> void:
	_build_water_and_ground()
	_build_edges()
	_build_piers_and_docks()
	_build_landmarks()
	_build_dressing()

## Everything the tide level drives: sea height, wet sand, the sandbar bank and the clock.
func apply_tide(eased: float, water_y: float) -> void:
	sea.position.y = water_y
	sandbar_bank.position.y = _ground_y - 0.02 - SANDBAR_SINK * eased
	world.sea_material.set_shader_parameter("tide", eased)
	kit.set_water_level(water_y)
	tide_hand.rotation.z = lerpf(0.95, -0.95, eased)

## Lanterns, the lantern room and the beam follow the region's lamp level; the sea
## borrows a little of the sky colour.
func apply_time_of_day(lamp_level: float, sky: Color) -> void:
	kit.set_glow(lamp_level * 2.6)
	Kit.set_emission(lantern_glass, lamp_level * 3.2)
	beam_material.set_shader_parameter("intensity", lamp_level * 0.42)
	beam_rotor.visible = lamp_level > 0.0
	world.sea_material.set_shader_parameter("sky_color", sky)

func timber() -> Material:
	return world._coastal_surface(1, 2.4, Color("#f0e6d8"))

func deck() -> Material:
	return world._coastal_surface(1, 2.4, Color("#d9c2a2"))

func _build_water_and_ground() -> void:
	var shoals: Array[Rect2] = [SANDBAR_BANK]
	shoals.append_array(FLATS)
	shoals.append(ISLET)
	world.sea_material = kit.shore_water(world.LAND, shoals)
	# On the island the bay is the island's own sea; the harbor keeps only its tidal basin.
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240) if world.embedded_in == null else (world.BOUNDS as Rect2).size - Vector2(0.3, 0.3)
	sea = world._mesh(plane, Vector3(0, _low_water, 0), world.sea_material)
	sea.name = "HarborSea"
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# West quay and north quay are stone, the east and south boardwalks and the bridge timber.
	var surfaces: Array[Material] = [world._coastal_surface(0, 2.0, Color("#d4c4a0")), timber(), world._coastal_surface(4, 2.2, Color("#f0e0c0"))]
	for index in range(world.LAND.size()):
		var rect: Rect2 = world.LAND[index]
		var shore: MeshInstance3D = world._box(Vector3(rect.get_center().x, _ground_y - 0.3, rect.get_center().y), Vector3(rect.size.x, 0.6, rect.size.y), Props.CREAM, true)
		world._set_registered_surface(shore, surfaces[[0, 1, 0, 1, 2, 1][index]])
		shore.name = "HarborShore%d" % index
	# The sandbar's footing is a fixed body; only its sand bank sinks with the tide.
	var sandbar: Rect2 = world.SANDBAR
	sandbar_body = kit.blocker(Vector3(sandbar.get_center().x, _ground_y - 0.3, sandbar.get_center().y), Vector3(sandbar.size.x, 0.6, sandbar.size.y))
	sandbar_body.name = "LowTideSandbar"
	var sand := kit.shore_ground("sand", Color("#ecd49c"), Color("#a98c62"))
	sandbar_bank = kit.mound(SANDBAR_BANK, _ground_y - 0.02, 0.85, 1.2, sand, 1.3)
	sandbar_bank.name = "LowTideSandbarBank"
	for index in range(FLATS.size()):
		kit.mound(FLATS[index], FLAT_TOP, 0.55, 1.25, sand, 2.1 * float(index + 1))
	if world.in_dress_reach(ISLET.get_center()): kit.mound(ISLET, _ground_y, 0.9, 1.6, sand, 4.4)

## Stone edges get a pale coping and bollards; timber edges a kerb beam and piles.
## Every wall carries a dark band that only low water uncovers.
func _build_edges() -> void:
	var coping := kit.surface(world._coastal_surface(4, 1.2, Color("#fff4dc")))
	var kerb := kit.surface(world._coastal_surface(1, 1.6, Color("#9c7a5a")))
	var piles := kit.piles()
	var band_y: float = (_low_water + world.HIGH_WATER) * 0.5
	for edge: Array in EDGES:
		var from := Vector2(float(edge[0]), float(edge[1]))
		var to := Vector2(float(edge[2]), float(edge[3]))
		var outward := Vector2(float(edge[4]), float(edge[5]))
		var timber_edge := int(edge[6]) == 1
		var middle := (from + to) * 0.5
		var length := from.distance_to(to)
		var along_x := is_zero_approx(outward.x)
		var band_at := middle + outward * 0.02
		kit.detail.box(Vector3(band_at.x, band_y, band_at.y), _edge_size(length, 0.3, 0.05, along_x), Color("#3f3528") if timber_edge else Color("#4b5846"))
		if timber_edge:
			var kerb_at := middle - outward * 0.07
			kerb.add(Vector3(kerb_at.x, _ground_y + 0.02, kerb_at.y), _edge_size(length, 0.12, 0.18, along_x))
			var count := maxi(1, roundi(length / 2.3))
			for index in range(count):
				var pile_at := from.lerp(to, (float(index) + 0.5) / float(count)) + outward * 0.17
				piles.add(Vector3(pile_at.x, -0.22, pile_at.y), Vector3(0.28, 1.3, 0.28))
		else:
			var coping_at := middle - outward * 0.15
			coping.add(Vector3(coping_at.x, _ground_y - 0.01, coping_at.y), _edge_size(length, 0.09, 0.42, along_x))
			var bollards := int(length / 5.0)
			for index in range(bollards):
				var bollard_at := from.lerp(to, (float(index) + 0.5) / float(bollards)) - outward * 0.2
				kit.detail.tube(Vector3(bollard_at.x, _ground_y + 0.2, bollard_at.y), 0.13, 0.1, 0.32, Props.IRON, 8)
				kit.detail.tube(Vector3(bollard_at.x, _ground_y + 0.38, bollard_at.y), 0.16, 0.16, 0.06, Props.IRON.lightened(0.12), 8)

func _edge_size(length: float, height: float, width: float, along_x: bool) -> Vector3:
	return Vector3(length, height, width) if along_x else Vector3(width, height, length)

func _build_piers_and_docks() -> void:
	# The causeway is the way back to the welcome avenue; the jetties are roped off.
	_pier(Rect2(-47, 3.8, 32, 2.4) if world.embedded_in == null else world._site.approach, false)
	_pier(Rect2(-8.6, 12, 1.9, 5.6), true)
	_pier(Rect2(15, 1.9, 5.2, 1.7), true)
	for dock: Vector3 in [world.SHORE_DOCK, world.LIGHTHOUSE_DOCK]:
		kit.surface(world._coastal_surface(1, 1.4)).add(dock + Vector3(0, 0.015, 0), Vector3(3.6, 0.03, 3.6))
		for side: float in [-1.0, 1.0]:
			kit.detail.box(dock + Vector3(side * 1.8, 0.035, 0), Vector3(0.12, 0.07, 3.72), Props.DARK_WOOD)
			kit.detail.box(dock + Vector3(0, 0.035, side * 1.8), Vector3(3.72, 0.07, 0.12), Props.DARK_WOOD)
			kit.posts().add(dock + Vector3(side * 1.7, 0.32, 1.5), Vector3(0.24, 0.64, 0.24), Basis.IDENTITY, Props.TEAL)
			kit.posts().add(dock + Vector3(side * 1.7, 0.67, 1.5), Vector3(0.3, 0.07, 0.3), Basis.IDENTITY, Props.GOLD)
	# Stone steps run down into the lagoon beside the tide clock.
	for step in range(4):
		kit.surface(world._coastal_surface(4, 1.2, Color("#fff4dc"))).add(Vector3(-8.8 + 0.4 * float(step), 0.06 - 0.14 * float(step), -4.6), Vector3(0.4, 0.14, 1.5))

## Timber deck on piles with rope rails along its long sides.
func _pier(rect: Rect2, roped_off: bool) -> void:
	var center := rect.get_center()
	kit.surface(deck()).add(Vector3(center.x, -0.01, center.y), Vector3(rect.size.x, 0.3, rect.size.y))
	var along_x := rect.size.x > rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var half_width := (rect.size.y if along_x else rect.size.x) * 0.5
	var direction := Vector3.RIGHT if along_x else Vector3.BACK
	var across := Vector3.BACK if along_x else Vector3.RIGHT
	var start := Vector3(center.x, 0, center.y) - direction * length * 0.5
	var count := maxi(2, roundi(length / 2.8))
	for side: float in [-1.0, 1.0]:
		for index in range(count + 1):
			var post_at := start + direction * (length * float(index) / float(count)) + across * side * (half_width - 0.08)
			kit.piles().add(post_at + Vector3(0, 0.05, 0), Vector3(0.22, 2.0, 0.22))
			if index % 3 == 1:
				kit.glow.box(post_at + Vector3(0, 1.2, 0), Vector3(0.14, 0.18, 0.14), Kit.WARM_GLOW)
		var rope_at := start + direction * length * 0.5 + across * side * (half_width - 0.08) + Vector3(0, 0.86, 0)
		kit.detail.box(rope_at, Vector3(length, 0.04, 0.04) if along_x else Vector3(0.04, 0.04, length), Props.ROPE)
	if roped_off:
		kit.detail.box(start + Vector3(0, 0.8, 0) + direction * 0.05, Vector3(0.04, 0.04, half_width * 2.0) if along_x else Vector3(half_width * 2.0, 0.04, 0.04), Props.CORAL)

func _build_landmarks() -> void:
	var lighthouse := Props.lighthouse(world, kit, LIGHTHOUSE_AT)
	lantern_glass = lighthouse.glass
	beam_rotor = lighthouse.rotor
	beam_material = lighthouse.beam_material
	_lighthouse_top = lighthouse.top
	var clock := Props.tide_clock(world, kit, TIDE_CLOCK_AT)
	tide_hand = clock.hand
	tide_bell = clock.bell
	tide_label = world._local_label("退潮 · 沙洲可通行", TIDE_CLOCK_AT + Vector3(0, 0.62, 0.4), 20)
	# Flag masts mark the causeway home; the board hangs clear of the path.
	var flags := kit.batch("flags", Kit.cloth_mesh(Vector2(1.1, 0.6), 6, 1, false), kit.cloth_material("flag", 0.2))
	for side: float in [-1.0, 1.0]:
		var mast := Vector3(-14.45, _ground_y, 5.0 + side * 1.5)
		kit.detail.box(mast + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Props.STONE)
		kit.detail.tube(mast + Vector3(0, 2.0, 0), 0.07, 0.05, 3.0, Props.WHITEWASH, 8)
		kit.detail.tube(mast + Vector3(0, 3.56, 0), 0.09, 0.09, 0.12, Props.GOLD, 6)
		flags.add(mast + Vector3(0.06, 3.45, 0), Vector3.ONE, Basis.IDENTITY, Props.CORAL if side < 0.0 else Props.GOLD)
	flags.add(LIGHTHOUSE_AT + Vector3(0.04, _lighthouse_top + 2.24, 0), Vector3(0.6, 0.55, 1.0), Basis.IDENTITY, Props.CORAL)
	var board := Vector3(-13.15, _ground_y + 2.3, 3.5)
	kit.detail.box(board + Vector3(-0.1, 0.42, 0), Vector3(2.5, 0.06, 0.06), Props.IRON)
	kit.detail.box(board, Vector3(2.5, 0.5, 0.07), Props.TEAL.darkened(0.1))
	for edge: float in [-1.0, 1.0]:
		kit.detail.box(board + Vector3(0, edge * 0.27, 0), Vector3(2.6, 0.05, 0.11), Props.CREAM)
		kit.detail.box(board + Vector3(edge * 0.9, 0.34, 0), Vector3(0.03, 0.18, 0.03), Props.IRON)
	world._local_label("返回迎賓大道", board + Vector3(0, 0, 0.2), 24)
	Props.signpost(world, kit, Vector3(-13.4, _ground_y, 7.0), "渡船 → 燈塔", 2.5)
	Props.signpost(world, kit, Vector3(0.6, _ground_y, 3.4), "渡船 → 岸邊", 2.5)
	Props.signpost(world, kit, Vector3(-10.3, _ground_y, -9.4), "燈塔 →", 1.5)
	# The prism game borrows the lighthouse beam: a brass prism on a plinth marks it.
	var prism := Vector3(3.5, _ground_y, -0.9)
	kit.detail.tube(prism + Vector3(0, 0.35, 0), 0.3, 0.24, 0.7, Props.STONE, 8)
	kit.detail.tube(prism + Vector3(0, 0.74, 0), 0.34, 0.34, 0.08, Props.STONE.lightened(0.15), 8)
	kit.detail.tube(prism + Vector3(0, 1.02, 0), 0.24, 0.02, 0.48, Color("#9fe0dc"), 3)
	kit.glow.tube(prism + Vector3(0, 0.82, 0), 0.1, 0.1, 0.06, Kit.WARM_GLOW, 6)
	world._local_label("燈塔折光", prism + Vector3(0.7, 1.5, 0.2), 24)

func _build_dressing() -> void:
	for post in LAMP_POSTS:
		kit.lamp_post(post)
	for plant: Array in PLANTS:
		if not world.in_dress_reach(Vector2(float(plant[1]), float(plant[3]))): continue
		kit.billboard(str(plant[0]), Vector3(float(plant[1]), float(plant[2]), float(plant[3])), float(plant[4]))
	for index in range(CARGO.size()):
		Props.cargo(kit, CARGO[index], index)
		kit.blocker(CARGO[index] + Vector3(0, 0.9, 0.2), Vector3(1.5, 1.8, 1.6))
	for spot: Array in POTS:
		Props.pots(kit, Vector3(float(spot[0]), float(spot[1]), float(spot[2])), float(spot[3]))
	Props.bench(kit, Vector3(-6.4, _ground_y, -8.75), 0.0)
	Props.bench(kit, Vector3(9.7, _ground_y, 1.0), -PI * 0.5)
	# A net dries on a rack beside the crab stall.
	var rack := Vector3(-7.2, _ground_y, 11.2)
	for side: float in [-1.0, 1.0]:
		kit.detail.box(rack + Vector3(side * 1.1, 0.8, 0), Vector3(0.07, 1.6, 0.07), Props.DARK_WOOD)
	kit.detail.box(rack + Vector3(0, 1.6, 0), Vector3(2.4, 0.06, 0.06), Props.DARK_WOOD)
	kit.batch("net", Kit.cloth_mesh(Vector2(2.1, 1.15), 6, 4, true), kit.cloth_material("net", 0.07, 7.0)).add(rack + Vector3(-1.05, 1.56, 0.02), Vector3.ONE, Basis.IDENTITY, Color("#b9a67c"))
	# Pennants run from the lighthouse gallery down to two masts on the islet.
	var gallery := LIGHTHOUSE_AT + Vector3(0, _lighthouse_top + 0.4, 0)
	for corner: Vector3 in [Vector3(-3.7, _ground_y, 3.7), Vector3(3.7, _ground_y, 3.7)]:
		kit.detail.tube(corner + Vector3(0, 1.4, 0), 0.06, 0.045, 2.8, Props.DARK_WOOD, 6)
		kit.bunting(gallery + (corner - gallery).normalized() * 1.05, corner + Vector3(0, 2.75, 0), PENNANT_COLORS, 0.55)
	var boulders := kit.batch("boulders", kit.unit_boulder, kit.shore_ground("rock", Color("#a59c8a"), Color("#5d5f5a"), 0.4))
	for cluster: Array in ROCKS:
		if not world.in_dress_reach(Vector2(float(cluster[0]), float(cluster[1]))): continue
		for index in range(int(cluster[2])):
			var seed_value := float(cluster[0]) * 3.1 + float(cluster[1]) * 1.7 + float(index) * 5.3
			var size := float(cluster[5]) * (0.55 + 0.45 * _scatter(seed_value))
			var at := Vector3(float(cluster[0]) + (_scatter(seed_value + 1.0) * 2.0 - 1.0) * float(cluster[3]), _low_water + size * 0.1, float(cluster[1]) + (_scatter(seed_value + 2.0) * 2.0 - 1.0) * float(cluster[4]))
			var tone := 0.9 + 0.1 * _scatter(seed_value + 3.0)
			boulders.add(at, Vector3(size * 1.3, size * 0.8, size * 1.05), Basis(Vector3.UP, seed_value), Color(tone, tone, tone * 0.98))

## Repeatable 0..1 scatter value, so the scenery is identical on every visit.
func _scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)
