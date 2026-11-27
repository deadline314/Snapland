extends RefCounted
## Everything in the neon night market that stays put: the paved quarter and the
## valley floor around it, kerbs, the dining terraces and their carts, the covered
## alley, the roof terrace, the shop-houses on three sides, the southern approach
## and all the dressing. Built once through the scenery kit; it keeps only what the
## time of day and the market's opening hours change.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/nightmarket_props.gd")
const STREET_Y := 0.2
const QUARTER_Y := 0.18
const VALLEY_Y := 0.08
const TERRACE_Y := 0.36
const CLOSED_GLOW := 0.24
## The paved quarter (x, z); beyond it the valley floor is bare ground and trees.
const QUARTER := Rect2(-23.0, -27.0, 46.0, 37.1)
## Shop-houses: x, z, width, depth, wall height, street side, style. The northern
## row is only a house-front deep: the painted town rises straight behind it.
const HOUSES := [
	[-11.9, -10.4, 6.0, 4.1, 5.0, "S", 0], [6.5, -10.4, 5.4, 4.1, 5.0, "S", 1],
	[-21.5, -16.5, 6.6, 1.2, 4.6, "S", 3], [-14.5, -16.5, 6.0, 1.2, 5.2, "S", 4], [-8.1, -16.5, 7.6, 1.2, 4.2, "S", 0],
	[0.0, -16.5, 6.4, 1.2, 5.0, "S", 1], [6.9, -16.5, 6.8, 1.2, 4.4, "S", 3], [14.2, -16.5, 7.2, 1.2, 5.2, "S", 0],
	[-18.4, -12.4, 5.7, 6.0, 5.4, "E", 2], [-18.0, -2.3, 5.3, 3.2, 4.6, "E", 0], [-18.6, 1.2, 5.9, 3.2, 5.6, "E", 3],
	[12.7, -12.4, 5.7, 6.0, 5.0, "W", 5], [12.7, -2.3, 5.5, 3.2, 5.4, "W", 4], [12.7, 1.2, 5.2, 3.2, 4.4, "W", 1],
	[-26.5, -7.2, 3.4, 5.4, 4.2, "E", 4], [23.1, -7.2, 3.4, 5.4, 4.2, "W", 0],
]
## Carts on the dining terraces: side (-1 west, 1 east), z, counter, awning stripe.
const TERRACE_CARTS := [
	[-1.0, -1.6, "steamer", Color(0.55, 1.15, 1.0)], [-1.0, 0.85, "pot", Color(1.25, 0.5, 0.42)], [-1.0, 3.3, "urn", Color(1.3, 0.95, 0.45)],
	[1.0, -1.6, "grill", Color(1.25, 0.5, 0.42)], [1.0, 0.85, "spit", Color(0.95, 0.6, 1.3)], [1.0, 3.3, "wok", Color(0.55, 1.15, 1.0)],
]
## Covered alley posts keep their old footprint, so the walkway is unchanged.
const CANOPY_POSTS_Z := [-2.75, 0.97, 4.69]
## Lamps in the world's lamp budget: lantern position, colour, pole side (-1 west).
const LAMPS := [
	[Vector3(0.0, 2.95, 1.0), Color("#ffd9a0"), 0.0], [Vector3(-10.2, 3.0, -4.4), Color("#a8f0dd"), -1.0],
	[Vector3(10.2, 3.0, -4.4), Color("#ffa48f"), 1.0], [Vector3(-10.2, 3.0, 6.6), Color("#ffc67a"), -1.0],
	[Vector3(10.2, 3.0, 8.5), Color("#ffb0c8"), 1.0],
]
## Billboards: kind, x, z, height. Tall trees keep clear of the view of the street.
const PLANTS := [
	["oak", -25.6, -14.6, 8.6], ["pine", -28.5, -19.0, 8.8], ["oak", 25.6, -14.8, 8.4], ["ginkgo", 28.5, -18.5, 8.6],
	["oak", -24.5, -11.5, 8.8], ["ginkgo", -22.5, -0.6, 7.6], ["pine", -25.5, 5.2, 8.4], ["oak", -21.5, 12.6, 7.2],
	["oak", 24.0, -12.0, 8.6], ["pine", 22.5, 0.4, 8.0], ["oak", 25.5, 6.0, 8.6], ["ginkgo", 21.5, 12.8, 7.0],
	["oak", -14.5, 21.5, 6.4], ["ginkgo", -7.0, 23.0, 6.0], ["oak", 8.2, 23.0, 6.2], ["pine", 15.5, 21.5, 6.4],
	["pine", -22.5, 20.5, 6.8], ["oak", 23.0, 19.5, 6.8], ["oak", -31.0, 7.5, 8.2], ["pine", 31.0, 9.0, 8.2],
	["shrub", -10.4, 10.9, 1.1], ["shrub", -5.6, 11.1, 1.2], ["shrub", 11.2, 11.0, 1.15], ["shrub", -15.6, 10.7, 1.2], ["shrub", 15.2, 10.8, 1.1],
	["shrub", -3.9, -7.6, 1.2], ["shrub", 3.9, -7.6, 1.2], ["shrub", -9.4, 15.6, 1.3], ["shrub", 5.6, 14.6, 1.2], ["shrub", 12.4, 17.2, 1.3],
]
const PENNANTS: Array[Color] = [Props.CORAL, Props.PAPER, Props.MINT, Props.AMBER, Props.ROSE]

var world: Node3D
var kit: Kit
var props: Props
var cat_arm: MeshInstance3D
var spit: MeshInstance3D
var fans: Array[MeshInstance3D] = []
var parasol_spinner: MeshInstance3D
var _open := true
var _neon_level := 1.0
var _lantern_level := 1.0

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit
	props = Props.new(owner, scenery_kit)

func build() -> void:
	_build_ground()
	_build_street_edges()
	_build_terraces()
	_build_covered_alley()
	_build_roof_terrace()
	for index in range(HOUSES.size()):
		var house: Array = HOUSES[index]
		# The first two stand right behind the north-street game stands.
		props.shophouse(Rect2(float(house[0]), float(house[1]), float(house[2]), float(house[3])), QUARTER_Y, float(house[4]), str(house[5]), int(house[6]), index >= 2)
	_build_approach()
	_build_poles_and_strings()
	_build_corner_shrine()
	_build_dressing()
	_build_lamps()

## Commits the glowing mesh; the world then finishes the kit.
func finish() -> void:
	props.finish()

## Neon, lanterns and windows follow the district's own dusk-to-night grade.
func apply_time_of_day(phase: String) -> void:
	_neon_level = float({"dawn": 1.15, "noon": 1.0, "dusk": 1.45, "night": 1.7}.get(phase, 1.0))
	_lantern_level = float({"dawn": 1.05, "noon": 0.95, "dusk": 1.3, "night": 1.5}.get(phase, 1.0))
	kit.set_glow(float({"dawn": 0.5, "noon": 0.4, "dusk": 0.75, "night": 0.9}.get(phase, 0.6)))
	_sync_glow()

## A closed market dims its signs and lanterns; the houses stay lit.
func set_open(value: bool) -> void:
	_open = value
	_sync_glow()

func _sync_glow() -> void:
	var share := 1.0 if _open else CLOSED_GLOW
	props.neon_material.set_shader_parameter("energy", _neon_level * share)
	props.lantern_material.set_shader_parameter("energy", _lantern_level * share)

func _build_ground() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(170, 170)
	# The valley floor is the island's own meadow, so neighbouring districts can meet it.
	var meadow := ShaderMaterial.new()
	meadow.shader = world.GRASS
	meadow.set_shader_parameter("shade", Color("#6a78a0"))
	world.material_cache["nightmarket:meadow"] = meadow
	var valley: MeshInstance3D = world._mesh(floor_mesh, Vector3(0, VALLEY_Y, 0), meadow)
	valley.name = "ValleyFloor"
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lane: Material = world._atmosphere.paving_material(false, true)
	var slabs := kit.surface(lane)
	var center := QUARTER.get_center()
	slabs.add(Vector3(center.x, QUARTER_Y - 0.3, center.y), Vector3(QUARTER.size.x, 0.6, QUARTER.size.y))
	# The way back to the welcome avenue runs south through the gateway.
	slabs.add(Vector3(0, QUARTER_Y - 0.3, 22.0), Vector3(5.0, 0.6, 24.0))
	# Loose flagstones break the quarter's edge up where it meets bare ground.
	var flags := kit.surface(world._coastal_surface(0, 2.2, Color("#59607a")))
	for index in range(64):
		var seed_value := float(index) * 7.31
		var along := Props.scatter(seed_value)
		var out := 0.3 + 2.6 * Props.scatter(seed_value + 1.0)
		var at: Vector3
		match index % 4:
			0: at = Vector3(lerpf(-24.0, 24.0, along), 0, QUARTER.end.y + out)
			1: at = Vector3(QUARTER.position.x - out, 0, lerpf(-26.0, 12.0, along))
			2: at = Vector3(QUARTER.end.x + out, 0, lerpf(-26.0, 12.0, along))
			_: at = Vector3((2.6 + out) * (1.0 if index % 8 < 4 else -1.0), 0, lerpf(10.5, 28.0, along))
		if absf(at.x) < 2.6 and at.z > 10.0: continue
		at.y = VALLEY_Y + 0.02
		flags.add(at, Vector3(0.9 + 0.7 * Props.scatter(seed_value + 2.0), 0.06, 0.7 + 0.5 * Props.scatter(seed_value + 3.0)), Basis(Vector3.UP, seed_value))

func _build_street_edges() -> void:
	var kerb := kit.surface(props.masonry(Color("#a9a4c0")))
	for side: float in [-1.0, 1.0]:
		kerb.add(Vector3(side * 12.14, STREET_Y + 0.03, 1.75), Vector3(0.26, 0.16, 15.6))
		kerb.add(Vector3(side * 7.35, STREET_Y + 0.03, 9.64), Vector3(9.7, 0.16, 0.26))
		kerb.add(Vector3(side * 7.15, STREET_Y + 0.03, -6.14), Vector3(9.9, 0.16, 0.26))
		# A low garden wall closes the south side without hiding the street.
		kit.surface(props.masonry(Color("#8d86a6"))).add(Vector3(side * 12.9, QUARTER_Y + 0.21, 10.05), Vector3(20.0, 0.42, 0.42))
		kit.detail.box(Vector3(side * 12.9, QUARTER_Y + 0.45, 10.05), Vector3(20.1, 0.07, 0.48), Color("#b5aecb"))
		kit.detail.box(Vector3(side * 2.75, QUARTER_Y + 0.26, 10.05), Vector3(0.6, 0.52, 0.6), Color("#7f7a92"))
		props.grate(Vector3(side * 11.5, STREET_Y + 0.012, 1.6), false)
		props.grate(Vector3(side * 6.4, STREET_Y + 0.012, 9.2), true)
		props.grate(Vector3(side * 8.9, STREET_Y + 0.012, -5.7), true)
		# Whatever is parked in an alley mouth marks where the open street ends.
		props.scooter(Vector3(side * 12.85, QUARTER_Y, -5.1), side * 1.2 + 1.4, Color("#c8584f") if side < 0.0 else Color("#4f9fb0"))
		props.scooter(Vector3(side * 13.0, QUARTER_Y, -3.7), side * 1.35 + 1.5, Color("#e0b04f") if side < 0.0 else Color("#8f6fb5"))
		props.crates(Vector3(side * 12.9, QUARTER_Y, 5.6), 0.4 * side, 1 if side < 0.0 else 2)
		props.potted_plant(Vector3(side * 12.75, QUARTER_Y, 7.3), 1.3, 1 if side < 0.0 else 0)
		props.scooter(Vector3(side * 13.6, QUARTER_Y, 8.6), 1.57 - side * 0.3, Color("#5f86a8") if side < 0.0 else Color("#c8584f"))
	props.grate(Vector3(0, STREET_Y + 0.012, 5.4), true)

## Two timber terraces flank the covered alley: carts face the outer streets and
## diners sit on the alley side.
func _build_terraces() -> void:
	var deck := kit.surface(props.wood(Color("#84768f")))
	var edging := kit.surface(props.masonry(Color("#a9a4c0")))
	for side: float in [-1.0, 1.0]:
		var middle := Vector3(side * 4.82, 0, 1.0)
		deck.add(middle + Vector3(0, TERRACE_Y - 0.1, 0), Vector3(5.1, 0.2, 7.5))
		for edge: float in [-1.0, 1.0]:
			edging.add(middle + Vector3(0, TERRACE_Y - 0.09, edge * 3.76), Vector3(5.26, 0.22, 0.16))
			edging.add(middle + Vector3(edge * 2.56, TERRACE_Y - 0.09, 0), Vector3(0.16, 0.22, 7.5))
		for seat in range(3):
			if side > 0.0 and seat == 2:
				props.crates(Vector3(4.4, TERRACE_Y, 4.0), 0.3, 0)
			else:
				props.dining_set(Vector3(side * 3.75, TERRACE_Y, -1.45 + 2.3 * float(seat)), 0.2 * float(seat) - 0.2, seat + int(side > 0.0))
		props.potted_plant(Vector3(side * 2.75, TERRACE_Y, -2.3), 1.1, int(side > 0.0))
		props.potted_plant(Vector3(side * 7.0, TERRACE_Y, 4.45), 0.9, 2)
		props.crates(Vector3(side * 5.3, TERRACE_Y, -2.2), 1.1 * side, int(side > 0.0) + 1)
		# Oil-paper umbrellas hang open along the alley.
		for hung in range(3):
			if side > 0.0 and hung == 2: continue
			props.parasol(Vector3(side * 2.85, 3.1, -1.5 + 2.4 * float(hung)), Props.LANTERN_COLORS[(hung + int(side > 0.0)) % 4].lerp(Props.PAPER, 0.25), 1.0, 0.4 * float(hung))
			kit.detail.box(Vector3(side * 2.4, 3.42, -1.5 + 2.4 * float(hung)), Vector3(1.0, 0.04, 0.04), Props.IRON)
	for index in range(TERRACE_CARTS.size()):
		var cart: Array = TERRACE_CARTS[index]
		var side := float(cart[0])
		var frame := Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * 6.25, TERRACE_Y, float(cart[1])))
		props.cart(frame, cart[3], str(cart[2]), index)
		if str(cart[2]) == "spit":
			spit = world._mesh(Props.spit_mesh(), frame * Vector3(-0.15, 1.45, 0), world._vertex_color_material("scenery-detail"))
			spit.basis = frame.basis * Basis(Vector3.UP, PI * 0.5)
			spit.name = "MarketRotisserie"
	# Standing fans keep the cooks cool.
	for stand: Vector3 in [Vector3(-4.9, TERRACE_Y, 2.15), Vector3(5.2, TERRACE_Y, -0.3)]:
		kit.detail.tube(stand + Vector3(0, 0.05, 0), 0.24, 0.2, 0.1, Props.IRON, 8)
		kit.detail.box(stand + Vector3(0, 0.7, 0), Vector3(0.06, 1.3, 0.06), Props.IRON)
		kit.detail.tube(stand + Vector3(0, 1.45, -0.05), 0.4, 0.4, 0.05, Props.NIGHT, 12, Basis(Vector3.RIGHT, PI * 0.5))
		var fan: MeshInstance3D = world._mesh(Props.fan_mesh(), stand + Vector3(0, 1.45, 0.03), world._vertex_color_material("scenery-detail"))
		fan.name = "MarketFan%d" % fans.size()
		fans.append(fan)

func _build_covered_alley() -> void:
	var detail := kit.detail
	var iron := Color("#4f8580")
	for z: float in CANOPY_POSTS_Z:
		for x: float in [-1.98, 1.98]:
			detail.box(Vector3(x, 1.88, z), Vector3(0.14, 3.35, 0.14), iron)
			detail.box(Vector3(x, 0.4, z), Vector3(0.3, 0.42, 0.3), iron.darkened(0.25))
			detail.box(Vector3(x * 0.9, 3.3, z), Vector3(0.5, 0.06, 0.06), iron, Basis(Vector3.BACK, signf(x) * -0.7))
			kit.blocker(Vector3(x, 1.88, z), Vector3(0.15, 3.35, 0.15))
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 1.88, 3.52, 0.97), Vector3(0.42, 0.17, 7.4), iron, Basis(Vector3.BACK, -side * 0.15))
		for z: float in [-0.9, 2.85]:
			props.lantern(Vector3(side * 1.45, 3.45, z), Props.LANTERN_COLORS[int(z + 2.0 + side) % 4], 0.85)
	for z: float in [-2.70, -0.78, 1.10, 2.99, 4.62]:
		detail.box(Vector3(0, 3.66, z), Vector3(4.18, 0.09, 0.07), iron.lightened(0.1))
	for z: float in [-2.55, 4.51]:
		props.neon.box(Vector3(0, 3.5, z), Vector3(4.2, 0.1, 0.08), Props.buzzing(Props.MINT, z))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.29, 0.49, 0.52, 0.3)
	glass.roughness = 0.5
	world.material_cache["nightmarket:glass"] = glass
	var pane := BoxMesh.new()
	pane.size = Vector3(3.38, 0.08, 7.31)
	var canopy: MeshInstance3D = world._mesh(pane, Vector3(0, 3.59, 0.97), glass)
	canopy.name = "CoveredAlleyAwning"
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_roof_terrace() -> void:
	var detail := kit.detail
	var roof_y: float = world.ROOF_Y
	var rail := Color("#b5aecb")
	var posts := kit.posts()
	# Balustrade: north, both sides and the two stretches beside the ramp.
	var runs := [[Vector3(-5.5, 0, -14.0), Vector3(5.5, 0, -14.0)], [Vector3(-5.5, 0, -14.0), Vector3(-5.5, 0, -9.5)], [Vector3(5.5, 0, -14.0), Vector3(5.5, 0, -9.5)], [Vector3(-5.5, 0, -9.5), Vector3(-2.3, 0, -9.5)], [Vector3(2.3, 0, -9.5), Vector3(5.5, 0, -9.5)]]
	for run: Array in runs:
		var from: Vector3 = run[0]
		var to: Vector3 = run[1]
		var span := to - from
		detail.box((from + to) * 0.5 + Vector3(0, roof_y + 0.7, 0), Vector3(0.09, 0.07, span.length() + 0.1), rail, Basis.looking_at(span.normalized()))
		detail.box((from + to) * 0.5 + Vector3(0, roof_y + 0.38, 0), Vector3(0.05, 0.05, span.length()), rail.darkened(0.2), Basis.looking_at(span.normalized()))
		var count := maxi(1, roundi(span.length() / 1.1))
		for index in range(count + 1):
			posts.add(from.lerp(to, float(index) / float(count)) + Vector3(0, roof_y + 0.36, 0), Vector3(0.11, 0.72, 0.11), Basis.IDENTITY, Color("#7a7494"))
	# Corner masts carry bulb strings and the big lantern over the tables.
	for x: float in [-5.5, 5.5]:
		for z: float in [-14.0, -9.5]:
			kit.piles().add(Vector3(x, roof_y + 1.7, z), Vector3(0.14, 3.4, 0.14))
		props.bulb_string(Vector3(x, roof_y + 3.35, -14.0), Vector3(x, roof_y + 3.35, -9.5), 0.45)
	props.bulb_string(Vector3(-5.5, roof_y + 3.35, -14.0), Vector3(5.5, roof_y + 3.35, -14.0), 0.7)
	props.wire(Vector3(-5.5, roof_y + 3.3, -9.5), Vector3(0, 3.95, -11.7), 0.15)
	props.wire(Vector3(5.5, roof_y + 3.3, -9.5), Vector3(0, 3.95, -11.7), 0.15)
	props.lantern(Vector3(0, 3.95, -11.7), Props.LANTERN_COLORS[1], 1.5)
	for x: float in [-3.2, 3.2]:
		var table := Vector3(x, roof_y, -11.7)
		detail.tube(table + Vector3(0, 0.04, 0), 0.4, 0.34, 0.08, Props.IRON, 8)
		detail.tube(table + Vector3(0, 0.36, 0), 0.08, 0.08, 0.6, Props.IRON, 6)
		detail.tube(table + Vector3(0, 0.7, 0), 0.8, 0.8, 0.07, Color("#7e5572"), 16)
		# An oilcloth in eight wedges covers the top.
		for wedge in range(8):
			var from := Basis(Vector3.UP, TAU * float(wedge) / 8.0) * Vector3(0.76, 0, 0)
			var to := Basis(Vector3.UP, TAU * float(wedge + 1) / 8.0) * Vector3(0.76, 0, 0)
			detail.tri(table + Vector3(0, 0.74, 0), table + Vector3(0, 0.74, 0) + to, table + Vector3(0, 0.74, 0) + from, Color("#d9a08e") if wedge % 2 == 0 else Color("#f0d9c0"))
		props.neon.tube(table + Vector3(0, 0.86, 0), 0.1, 0.12, 0.2, Props.AMBER, 6)
		props.bowl(table + Vector3(0.42, 0.735, 0.18), Props.PAPER)
		props.bowl(table + Vector3(-0.4, 0.735, -0.2), Color("#7cb49b"))
		for seat in range(4):
			props.stool(table + Basis(Vector3.UP, TAU * (float(seat) + 0.5) / 4.0) * Vector3(1.12, 0, 0), [Color("#d0584f"), Color("#4f8fc0")][seat % 2])
		kit.blocker(table + Vector3(0, 0.95, 0), Vector3(0.64, 1.9, 0.64))
	props.sign("屋頂餐桌", Vector3(0, roof_y + 1.82, -13.3), Props.CORAL, "", roof_y)
	# Planted beds fill the corners beside the ramp, behind the north-street stands.
	for side: float in [-1.0, 1.0]:
		kit.surface(props.masonry(Color("#8d86a6"))).add(Vector3(side * 3.95, QUARTER_Y + 0.26, -7.75), Vector3(3.2, 0.52, 2.9))
		kit.surface(world._coastal_surface(0, 1.3, Color("#4a5a4e"))).add(Vector3(side * 3.95, QUARTER_Y + 0.54, -7.75), Vector3(2.9, 0.04, 2.6))
		props.potted_plant(Vector3(side * 5.0, QUARTER_Y + 0.52, -8.4), 1.5, 1)
		props.potted_plant(Vector3(side * 2.95, QUARTER_Y + 0.52, -6.9), 1.1, 0)
		props.stone_lantern(Vector3(side * 2.62, STREET_Y, -5.72))

## South of the kerb the quarter gives way to the valley: a lantern-lit path runs
## out through the gateway toward the welcome avenue.
func _build_approach() -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in [11.6, 14.3, 17.0, 21.5]:
			props.stone_lantern(Vector3(side * 2.9, VALLEY_Y, z))
	var board := props.gateway(Vector3(0, QUARTER_Y, 18.6), 5.6)
	var title: Label3D = world._label("霓虹夜市", board + Vector3(0, 0.02, 0.1), 30, Props.PAPER)
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.pixel_size = 0.018
	title.visibility_range_end = 0.0
	# The way-back board stands low beside the path, clear of the street's view.
	props.sign("免費返回", Vector3(-5.7, VALLEY_Y + 0.95, 12.0), Props.PAPER, "", VALLEY_Y)

func _build_poles_and_strings() -> void:
	# Utility poles line both outer streets; their wires cross and tangle overhead.
	for side: float in [-1.0, 1.0]:
		var tops: Array[Vector3] = []
		for z: float in [-6.6, 4.62, 10.5]:
			tops.append(props.utility_pole(Vector3(side * 12.42, QUARTER_Y, z), 6.2 if z < 10.0 else 5.6, z < 0.0))
		for index in range(tops.size() - 1):
			for strand: float in [-0.65, 0.0, 0.65]:
				props.wire(tops[index] + Vector3(strand, 0.08, 0), tops[index + 1] + Vector3(strand, 0.08, 0), 0.45 + 0.2 * absf(strand) + 0.1 * float(index))
			props.wire(tops[index] + Vector3(-0.3, -0.6, 0), tops[index + 1] + Vector3(0.4, -0.6, 0), 1.05)
		props.wire(tops[0], Vector3(side * 12.2, 5.3, -15.4), 0.7)
		props.wire(tops[0] + Vector3(0, -0.6, 0), Vector3(side * 9.0, 4.35, -6.5), 0.35)
		props.wire(tops[1] + Vector3(0, -0.6, 0), Vector3(side * 12.9, 4.6, 2.2), 0.3)
		props.wire(tops[1] + Vector3(0, -0.6, 0), Vector3(side * 7.2, 2.6, 3.6), 0.8)
		# Bulbs run from the house fronts to the carts across each outer street.
		props.bulb_string(Vector3(side * 12.6, 3.7, -1.0), Vector3(side * 7.25, 2.55, -0.45), 0.5)
		props.bulb_string(Vector3(side * 12.6, 3.7, 2.9), Vector3(side * 7.25, 2.55, 2.05), 0.5)
		# Pennants cross the north and south streets from the covered alley.
		kit.bunting(Vector3(side * 7.4, 4.0, -6.2), Vector3(side * 1.98, 3.62, -2.75), PENNANTS, 0.45)
		kit.bunting(Vector3(side * 1.98, 3.62, 4.69), Vector3(side * 11.75, 3.75, 6.6 if side < 0.0 else 8.5), PENNANTS, 0.7)
	props.bulb_string(Vector3(-11.75, 3.75, 6.6), Vector3(-3.2, 3.2, 9.5), 0.5)

## The lucky cat keeps the shrine in the south-west corner; it beckons at passers-by.
func _build_corner_shrine() -> void:
	var at := Vector3(-11.0, STREET_Y, 8.75)
	props.shrine(at)
	kit.blocker(at + Vector3(0, 0.95, 0), Vector3(1.3, 1.9, 0.8))
	var cat := at + Vector3(1.15, 0, 0.1)
	kit.detail.box(cat + Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.6), Color("#7f7a92"))
	props.lucky_cat(cat + Vector3(0, 0.4, 0))
	cat_arm = world._mesh(Props.lucky_cat_arm_mesh(), cat + Vector3(0.34, 0.98, 0.08), world._vertex_color_material("scenery-detail"))
	cat_arm.name = "LuckyCatArm"
	props.potted_plant(at + Vector3(-0.95, 0, 0.1), 0.9, 2)

func _build_dressing() -> void:
	for plant: Array in PLANTS:
		var at := Vector2(float(plant[1]), float(plant[2]))
		var ground := Vector3(at.x, QUARTER_Y if QUARTER.has_point(at) else VALLEY_Y, at.y)
		# The trees stand out of reach as one batch per kind; shrubs keep their own shadows.
		if str(plant[0]) == "shrub":
			kit.billboard("shrub", ground, float(plant[3]))
		else:
			kit.grove(str(plant[0]), ground, float(plant[3]))
	# Potted plants sit along the garden wall, clear of the group-photo view.
	for index in range(7):
		var x: float = [-12.2, -9.1, -7.2, -4.3, 10.4, 12.3, 14.6][index]
		props.potted_plant(Vector3(x, QUARTER_Y + 0.48, 10.05), 0.7 + 0.2 * float(index % 2), index)
	# Far lights down the side alleys.
	for side: float in [-1.0, 1.0]:
		props.lantern(Vector3(side * 20.4, 3.2, -4.4), Props.LANTERN_COLORS[0], 1.1)
		props.wire(Vector3(side * 18.4, 3.6, -6.3), Vector3(side * 22.0, 3.4, -2.3), 0.2)
		props.lantern(Vector3(side * 19.2, 3.0, 6.2), Props.LANTERN_COLORS[1], 1.0)
		props.wire(Vector3(side * 18.0, 3.4, 4.4), Vector3(side * 20.6, 3.2, 8.4), 0.15)
		props.crates(Vector3(side * 16.5, QUARTER_Y, -5.3), 0.7, 2)
		props.crates(Vector3(side * 15.4, QUARTER_Y, 5.3), -0.5, 1)
		props.potted_plant(Vector3(side * 14.4, QUARTER_Y, -2.9), 1.2, 1)

## Five lamps join the world's lamp budget; each hangs as a large lantern.
func _build_lamps() -> void:
	for spec: Array in LAMPS:
		var at: Vector3 = spec[0]
		var side := float(spec[2])
		if not is_zero_approx(side):
			var pole := Vector3(side * 11.78, STREET_Y, at.z)
			kit.piles().add(pole + Vector3(0, 1.9, 0), Vector3(0.16, 3.8, 0.16))
			kit.detail.box(Vector3((pole.x + at.x) * 0.5, 3.72, at.z), Vector3(absf(pole.x - at.x) + 0.3, 0.07, 0.07), Props.IRON)
			kit.detail.box(pole + Vector3(-side * 0.4, 3.4, 0), Vector3(0.9, 0.05, 0.05), Props.IRON, Basis(Vector3.BACK, side * 0.7))
		props.lantern(at + Vector3(0, 0.7, 0), spec[1], 1.45)
		kit.lamp_light(at, 7.5, spec[1]).omni_attenuation = 1.25
