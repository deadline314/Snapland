extends RefCounted
## Signature props of the candy factory. Each builder goes through the scenery kit:
## textured parts batch across the region, trim merges into the shared detail mesh
## and glossy sweets into one `gloss` sculpt.

const Kit := preload("res://game/world/scenery_kit.gd")
const TILE := preload("res://game/world/candy_tile.gdshader")
const CREAM := Color("#fff1dc")
const WHITE := Color("#fffaf2")
const PINK := Color("#f4a3bb")
const ROSE := Color("#dd6a90")
const RED := Color("#e2495f")
const PLUM := Color("#7a4a72")
const MINT := Color("#a3dfc8")
const SKY := Color("#a2d3ee")
const LEMON := Color("#f9da7c")
const LILAC := Color("#c9abe8")
const CHOC := Color("#6e4534")
const CARAMEL := Color("#c9853d")
const WAFER := Color("#e9c68f")
const COPPER := Color("#c98d5e")
const STEEL := Color("#8d8296")
const DARK := Color("#40334a")
const TEMPERATURE_TONES: Array[Color] = [Color("#8fc4e0"), Color("#f4a3bb"), Color("#eea849")]
## Mean linear colour of each tile in the shared material atlas.
const ATLAS_MEAN: Array[Color] = [
	Color(0.171, 0.143, 0.108), Color(0.322, 0.168, 0.059), Color(0.033, 0.113, 0.121), Color(0.395, 0.096, 0.062),
	Color(0.411, 0.289, 0.150), Color(0.127, 0.251, 0.231), Color(0.313, 0.257, 0.181), Color(0.209, 0.132, 0.051),
]
const SWEETS: Array[Color] = [RED, LEMON, MINT, SKY, LILAC, PINK]
## A cane fence or lamp post changes colour every this many metres.
const CANE_BAND := 0.2

## Cached two-tone surface: pattern 0 checker tiles, 1 stripes, 2 bands up a wall.
static func tile(world: Node3D, key: String, pattern: int, tone_a: Color, tone_b: Color, size: float, roughness := 0.55) -> ShaderMaterial:
	var cache_key := "candy-tile:" + key
	if world.material_cache.has(cache_key): return world.material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = TILE
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("tone_a", tone_a)
	material.set_shader_parameter("tone_b", tone_b)
	material.set_shader_parameter("grout", tone_b.darkened(0.3))
	material.set_shader_parameter("tile_size", size)
	material.set_shader_parameter("surface_roughness", roughness)
	world.material_cache[cache_key] = material
	return material

## Shared material atlas tile recoloured so that it averages `target`: 0 cobbles,
## 1 planks, 2 shingles, 3 boards, 4 blocks, 7 riveted plate.
static func toned(world: Node3D, tile_index: int, tile_size: float, target: Color) -> Material:
	if world.coastal_atlas == null: return world._coastal_surface(tile_index, tile_size, target)
	var key := "candy-atlas:%d:%.2f:%s" % [tile_index, tile_size, target.to_html(false)]
	if world.material_cache.has(key): return world.material_cache[key]
	var mean: Color = ATLAS_MEAN[tile_index]
	var wanted := target.srgb_to_linear()
	var material := ShaderMaterial.new()
	material.shader = world.CoastalMaterialShader
	material.set_shader_parameter("atlas_texture", world.coastal_atlas)
	material.set_shader_parameter("tile_index", tile_index)
	material.set_shader_parameter("world_tile_size", tile_size)
	# The shader reads its tint as an sRGB swatch, so hand it the ratio in that encoding.
	material.set_shader_parameter("tint", Color(wanted.r / mean.r, wanted.g / mean.g, wanted.b / mean.b).linear_to_srgb())
	world.material_cache[key] = material
	return material

## Riveted plate in a pastel: tanks, silos and machine housings.
static func plate(world: Node3D, tone: Color) -> Material:
	return toned(world, 7, 1.3, tone)

## Painted boards in a pastel: hall walls and cabinets.
static func boards(world: Node3D, tone: Color) -> Material:
	return toned(world, 3, 1.5, tone)

## Biscuit blocks: kerbs, plinths, banks and the path home.
static func biscuit(world: Node3D) -> Material:
	return toned(world, 4, 1.3, Color("#ecd3a4"))

## Straight tube between two points.
static func pipe(sculpt: Kit.Sculpt, from: Vector3, to: Vector3, radius: float, color: Color, sides := 8) -> void:
	var span := to - from
	var up := span.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK).normalized()
	sculpt.tube((from + to) * 0.5, radius, radius, span.length(), color, sides, Basis(side, up, side.cross(up)))

## Pipe run through several points with a flange at every joint.
static func pipe_run(sculpt: Kit.Sculpt, points: Array[Vector3], radius: float, color: Color) -> void:
	for index in range(points.size() - 1):
		pipe(sculpt, points[index], points[index + 1], radius, color)
		var along := (points[index + 1] - points[index]).normalized()
		pipe(sculpt, points[index] - along * 0.05, points[index] + along * 0.05, radius * 1.45, color.darkened(0.18))
	sculpt.ball(points[-1], radius * 1.15, color.darkened(0.18), Color.TRANSPARENT, 6, 3)

## Hand wheel on a stub, facing the camera side (+Z).
static func valve(sculpt: Kit.Sculpt, at: Vector3) -> void:
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.box(at + Vector3(0, 0, 0.1), Vector3(0.06, 0.06, 0.2), STEEL)
	sculpt.tube(at + Vector3(0, 0, 0.22), 0.17, 0.17, 0.04, RED, 8, face_on)
	sculpt.tube(at + Vector3(0, 0, 0.24), 0.07, 0.07, 0.05, CREAM, 6, face_on)

## Round dial with a needle; `reading` runs from -1 to 1.
static func gauge(sculpt: Kit.Sculpt, at: Vector3, reading: float, radius := 0.2) -> void:
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(at, radius, radius, 0.08, COPPER, 10, face_on)
	sculpt.tube(at + Vector3(0, 0, 0.03), radius * 0.8, radius * 0.8, 0.04, WHITE, 10, face_on)
	sculpt.box(at + Vector3(0, 0, 0.06) + Basis(Vector3.BACK, -reading) * Vector3(0, radius * 0.35, 0), Vector3(radius * 0.14, radius * 0.7, 0.02), RED, Basis(Vector3.BACK, -reading))

## Upright candy cane: red and white bands, optionally ending in a crook toward `hook`.
static func cane(sculpt: Kit.Sculpt, base: Vector3, height: float, radius := 0.05, hook := Vector3.ZERO, stripe := RED, sides := 6, band_height := CANE_BAND) -> Vector3:
	var bands := maxi(2, roundi(height / band_height))
	var step := height / float(bands)
	for band in range(bands):
		sculpt.tube(base + Vector3(0, (float(band) + 0.5) * step, 0), radius, radius, step, stripe if band % 2 == 0 else WHITE, sides)
	var tip := base + Vector3(0, height, 0)
	if hook != Vector3.ZERO:
		var reach := hook.length()
		var previous := tip
		for bend in range(1, 5):
			var angle := PI * float(bend) / 4.0
			var next := tip + hook * 0.5 * (1.0 - cos(angle)) + Vector3(0, sin(angle) * reach * 0.5, 0)
			pipe(sculpt, previous, next, radius, WHITE if bend % 2 == 0 else stripe, 6)
			previous = next
		tip = previous
	return tip

## Low candy-cane fence between two ground points (x, z): banded posts, two cream rails.
static func cane_fence(kit: Kit, from: Vector2, to: Vector2, ground_y: float, stripe := RED) -> void:
	var length := from.distance_to(to)
	var count := maxi(1, roundi(length / 1.5))
	for index in range(count + 1):
		var at := from.lerp(to, float(index) / float(count))
		cane(kit.detail, Vector3(at.x, ground_y, at.y), 0.81, 0.052, Vector3.ZERO, stripe, 5, 0.27)
		kit.detail.ball(Vector3(at.x, ground_y + 0.84, at.y), 0.085, WHITE, Color.TRANSPARENT, 5, 2, 1.0, true)
	var middle := (from + to) * 0.5
	var along_x := absf(to.x - from.x) > absf(to.y - from.y)
	for rail: float in [0.34, 0.66]:
		kit.detail.box(Vector3(middle.x, ground_y + rail, middle.y), Vector3(length, 0.05, 0.04) if along_x else Vector3(0.04, 0.05, length), CREAM)

## Candy-cane lamp: a crooked cane with a glowing gumdrop lantern and one budgeted light.
static func cane_lamp(kit: Kit, ground: Vector3, side: float) -> void:
	kit.detail.tube(ground + Vector3(0, 0.09, 0), 0.2, 0.15, 0.18, PLUM, 8)
	var tip := cane(kit.detail, ground + Vector3(0, 0.18, 0), 2.35, 0.065, Vector3(side * 0.62, 0, 0))
	kit.detail.box(tip + Vector3(0, -0.07, 0), Vector3(0.03, 0.14, 0.03), DARK)
	kit.detail.tube(tip + Vector3(0, -0.17, 0), 0.07, 0.2, 0.08, PLUM, 8)
	kit.glow.ball(tip + Vector3(0, -0.4, 0), 0.2, Kit.WARM_GLOW, Color.TRANSPARENT, 8, 4, 1.05)
	kit.lamp_light(Vector3(tip.x, ground.y + 2.0, tip.z + 0.25), 7.2)

## Framed board on two cane posts with a flat label, as wide as its text.
static func signboard(world: Node3D, kit: Kit, at: Vector3, text: String, font_size := 24, board_y := 1.45) -> Label3D:
	var glyph := float(font_size) * 0.02
	var width := 0.5
	for index in range(text.length()):
		width += glyph * (1.0 if text.unicode_at(index) > 0x2e7f else 0.55)
	var height := glyph + 0.34
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		cane(detail, at + Vector3(side * (width * 0.5 - 0.12), 0, -0.06), board_y + height * 0.5, 0.045)
	board(detail, at + Vector3(0, board_y, 0), width, height)
	return lettering(world, text, at + Vector3(0, board_y, 0.12), font_size)

## Flat lettering on a physical board; it stays on at any distance.
static func lettering(world: Node3D, text: String, at: Vector3, font_size: int) -> Label3D:
	var label: Label3D = world._local_label(text, at, font_size, CREAM)
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.visible = true
	return label

## Plum sign board with an icing frame and scalloped top; centred on `at`, facing +Z.
static func board(detail: Kit.Sculpt, at: Vector3, width: float, height: float) -> void:
	detail.box(at, Vector3(width, height, 0.08), PLUM)
	for edge: float in [-1.0, 1.0]:
		detail.box(at + Vector3(0, edge * height * 0.5, 0.01), Vector3(width + 0.12, 0.07, 0.12), PINK)
		detail.box(at + Vector3(edge * width * 0.5, 0, 0.01), Vector3(0.07, height, 0.12), PINK)
	var scallops := maxi(3, roundi(width / 0.34))
	for index in range(scallops):
		detail.ball(at + Vector3((float(index) + 0.5) / float(scallops) * width - width * 0.5, height * 0.5 + 0.02, 0), width / float(scallops) * 0.5, CREAM if index % 2 == 0 else PINK, Color.TRANSPARENT, 6, 2, 0.8, true)

## Swirl lollipop on a stick, as tall as a small tree; the disc faces the camera.
static func lollipop_tree(kit: Kit, gloss: Kit.Sculpt, at: Vector3, height: float, tone: Color, swirl: Color) -> void:
	var radius := height * 0.27
	kit.detail.tube(at + Vector3(0, (height - radius) * 0.5, 0), 0.07, 0.055, height - radius, WHITE, 6)
	kit.detail.ball(at + Vector3(0.05, 0.1, 0.08), 0.26, MINT.darkened(0.12), Color.TRANSPARENT, 6, 3, 0.8, true)
	var facing := kit.view_basis * Basis(Vector3.RIGHT, PI * 0.5)
	var centre := at + Vector3(0, height - radius, 0)
	gloss.tube(centre, radius, radius, 0.16, tone, 12, facing)
	for ring in range(1, 4):
		var ring_radius := radius * (1.0 - 0.25 * float(ring))
		gloss.tube(centre + kit.view_basis.z * (0.07 + 0.012 * float(ring)), ring_radius, ring_radius * 0.92, 0.04, swirl if ring % 2 == 1 else tone.lightened(0.25), 12, facing)

## Cotton-candy tree: a bent trunk under a cloud of spun-sugar puffs.
static func cotton_tree(kit: Kit, at: Vector3, height: float, tone: Color, variation: int) -> void:
	var detail := kit.detail
	var lean := 0.12 * sin(float(variation) * 1.7)
	pipe(detail, at, at + Vector3(lean, height * 0.5, 0), 0.13, CHOC, 6)
	pipe(detail, at + Vector3(lean, height * 0.5, 0), at + Vector3(lean * 0.4, height * 0.72, 0), 0.1, CHOC.lightened(0.08), 6)
	detail.ball(at + Vector3(0, 0.08, 0.1), 0.3, MINT.darkened(0.15), Color.TRANSPARENT, 6, 3, 0.7, true)
	var crown := at + Vector3(lean * 0.4, height * 0.74, 0)
	var puff := height * 0.24
	var puffs: Array[Vector3] = [Vector3(0, 0.25, 0), Vector3(-0.9, -0.1, 0.1), Vector3(0.9, -0.05, 0.05), Vector3(-0.35, 0.65, -0.1), Vector3(0.45, 0.6, 0.1), Vector3(0.05, -0.2, 0.55)]
	for index in range(puffs.size()):
		var size := puff * (1.0 - 0.14 * float((index + variation) % 3))
		var shade := tone.lightened(0.16) if puffs[index].y > 0.4 else (tone.darkened(0.1) if puffs[index].y < 0.0 else tone)
		detail.ball(crown + puffs[index] * puff, size, shade, Color.TRANSPARENT, 7, 4, 0.88)

## Sugared gumdrop: path edging, hedges and flower heads.
static func gumdrop(gloss: Kit.Sculpt, at: Vector3, radius: float, tone: Color) -> void:
	gloss.tube(at + Vector3(0, radius * 0.3, 0), radius, radius * 0.92, radius * 0.6, tone.darkened(0.08), 7)
	gloss.ball(at + Vector3(0, radius * 0.6, 0), radius * 0.92, tone, Color.TRANSPARENT, 7, 2, 0.85, true)

## Sugar sacks piled on a pallet with a crate; `variation` reshuffles the stack.
static func sacks(kit: Kit, at: Vector3, variation: int) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, 0.4 * float(variation)), at)
	detail.box(Vector3(0, 0.06, 0), Vector3(1.7, 0.12, 1.3), WAFER.darkened(0.25))
	var spots: Array[Vector3] = [Vector3(-0.42, 0.3, -0.25), Vector3(0.42, 0.3, -0.2), Vector3(0, 0.3, 0.3), Vector3(-0.2, 0.62, -0.1), Vector3(0.3, 0.62, 0.1), Vector3(0.05, 0.92, 0)]
	for index in range(4 + variation % 3):
		var turn := Basis(Vector3.UP, 0.5 * float(index + variation))
		detail.box(spots[index], Vector3(0.78, 0.3, 0.5), CREAM if index % 2 == 0 else CREAM.darkened(0.07), turn)
		detail.box(spots[index] + Vector3(0, 0.005, 0), Vector3(0.16, 0.31, 0.51), SWEETS[(index + variation) % SWEETS.size()], turn)
	detail.box(Vector3(1.15, 0.3, 0.2), Vector3(0.6, 0.6, 0.6), WAFER, Basis(Vector3.UP, 0.3))
	detail.box(Vector3(1.15, 0.61, 0.2), Vector3(0.66, 0.05, 0.66), CHOC, Basis(Vector3.UP, 0.3))
	detail.frame = Transform3D.IDENTITY

## Storage silo on legs: banded plate drum, cone roof, ladder and outlet.
static func silo(world: Node3D, kit: Kit, at: Vector3, radius: float, height: float, tone: Color) -> void:
	var bands := 4
	var band := height / float(bands)
	for index in range(bands):
		kit.rounds(plate(world, tone if index % 2 == 0 else CREAM)).add(at + Vector3(0, 1.0 + band * (float(index) + 0.5), 0), Vector3(radius * 2.0, band, radius * 2.0))
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	for leg in range(4):
		var out := Basis(Vector3.UP, TAU * (float(leg) + 0.5) / 4.0) * Vector3(radius * 0.8, 0, 0)
		detail.box(out + Vector3(0, 0.5, 0), Vector3(0.14, 1.0, 0.14), DARK)
	detail.tube(Vector3(0, 0.78, 0), 0.2, radius * 0.9, 0.5, tone.darkened(0.2), 12)
	for index in range(1, bands):
		detail.tube(Vector3(0, 1.0 + band * float(index), 0), radius + 0.04, radius + 0.04, 0.07, DARK.lightened(0.15), 16)
	detail.tube(Vector3(0, 1.0 + height + radius * 0.3, 0), radius + 0.08, 0.16, radius * 0.6, tone.darkened(0.12), 16)
	detail.ball(Vector3(0, 1.0 + height + radius * 0.66, 0), 0.2, RED, Color.TRANSPARENT, 6, 3)
	for rung in range(int(height / 0.4)):
		detail.box(Vector3(0, 1.2 + 0.4 * float(rung), radius + 0.06), Vector3(0.4, 0.04, 0.04), DARK)
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 0.2, 1.0 + height * 0.5, radius + 0.06), Vector3(0.04, height, 0.04), DARK)
	detail.frame = Transform3D.IDENTITY

## Tall syrup tank standing on the pipe gallery: banded drum, dome, gauge and valve.
static func tank(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3, tone: Color, level: float) -> void:
	for index in range(3):
		kit.rounds(plate(world, tone if index != 1 else CREAM)).add(at + Vector3(0, 0.75 + 0.9 * float(index), 0), Vector3(1.36, 0.9, 1.36))
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.tube(Vector3(0, 0.15, 0), 0.82, 0.76, 0.3, DARK, 16)
	for ring: float in [1.2, 2.1]:
		detail.tube(Vector3(0, ring, 0), 0.71, 0.71, 0.07, COPPER, 16)
	detail.ball(Vector3(0, 3.0, 0), 0.68, tone.darkened(0.1), Color.TRANSPARENT, 12, 3, 0.55, true)
	detail.tube(Vector3(0, 3.42, 0), 0.14, 0.14, 0.2, COPPER, 8)
	# A sight glass shows how full the tank is.
	detail.box(Vector3(0, 1.65, 0.69), Vector3(0.16, 1.5, 0.05), DARK)
	gauge(detail, Vector3(0.38, 2.45, 0.6), level * 1.6 - 0.8)
	valve(detail, Vector3(-0.36, 0.75, 0.62))
	detail.frame = Transform3D.IDENTITY
	gloss.box(at + Vector3(0, 0.95 + 0.7 * level, 0.71), Vector3(0.1, 1.4 * level, 0.04), CARAMEL.lightened(0.15))

## Open copper kettle on a brick hearth; returns the centre of its syrup surface.
static func vat(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3, syrup: Color) -> Vector3:
	kit.surface(biscuit(world)).add(at + Vector3(0, 0.35, 0), Vector3(2.3, 0.7, 2.1))
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 0.72, 0), Vector3(2.4, 0.06, 2.2), CREAM)
	detail.box(Vector3(0, 0.3, 1.06), Vector3(0.6, 0.4, 0.04), DARK)
	detail.tube(Vector3(0, 1.0, 0), 0.72, 1.02, 0.5, COPPER.darkened(0.12), 14)
	detail.tube(Vector3(0, 1.65, 0), 1.02, 1.06, 0.8, COPPER, 14)
	detail.tube(Vector3(0, 2.08, 0), 1.12, 1.12, 0.09, COPPER.lightened(0.2), 14)
	for band: float in [1.4, 1.85]:
		detail.tube(Vector3(0, band, 0), 1.075, 1.075, 0.06, COPPER.darkened(0.25), 14)
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 1.16, 1.75, 0), Vector3(0.14, 0.08, 0.3), DARK)
	gauge(detail, Vector3(0.45, 1.6, 1.07), 0.3 + at.x * 0.07)
	detail.frame = Transform3D.IDENTITY
	var surface := at + Vector3(0, 2.07, 0)
	gloss.tube(surface, 1.0, 1.0, 0.08, syrup, 14)
	gloss.tube(surface + Vector3(0.2, 0.03, 0.1), 0.55, 0.5, 0.04, syrup.lightened(0.18), 10)
	return surface + Vector3(0, 0.05, 0)

## Giant gumball machine. Returns the globe centre and radius for the tumbling gumballs.
static func gumball_machine(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> Dictionary:
	const GLOBE := 1.55
	kit.surface(biscuit(world)).add(at + Vector3(0, 0.2, 0), Vector3(3.4, 0.4, 3.4))
	kit.rounds(plate(world, RED.lightened(0.12))).add(at + Vector3(0, 1.05, 0), Vector3(2.3, 1.3, 2.3))
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 0.42, 0), Vector3(3.5, 0.06, 3.5), CREAM)
	detail.tube(Vector3(0, 0.5, 0), 1.36, 1.26, 0.2, DARK, 16)
	detail.tube(Vector3(0, 1.74, 0), 1.24, 1.0, 0.14, CREAM, 16)
	detail.tube(Vector3(0, 1.92, 0), 0.95, 0.8, 0.26, RED.darkened(0.12), 16)
	# Coin plate, crank and the chute door the gumballs roll out of.
	detail.box(Vector3(0, 1.2, 1.16), Vector3(0.7, 0.7, 0.06), CREAM)
	detail.box(Vector3(0, 1.36, 1.2), Vector3(0.08, 0.26, 0.04), DARK)
	detail.box(Vector3(0, 0.72, 1.2), Vector3(0.6, 0.36, 0.14), DARK)
	detail.box(Vector3(0, 0.56, 1.36), Vector3(0.7, 0.06, 0.4), CREAM, Basis(Vector3.RIGHT, 0.35))
	var centre := Vector3(0, 2.0 + GLOBE * 0.92, 0)
	detail.tube(centre + Vector3(0, GLOBE * 0.9, 0), 0.75, 0.5, 0.3, RED.darkened(0.05), 16)
	detail.tube(centre + Vector3(0, GLOBE * 0.9 + 0.2, 0), 0.82, 0.82, 0.1, CREAM, 16)
	detail.ball(centre + Vector3(0, GLOBE * 0.9 + 0.42, 0), 0.2, LEMON, Color.TRANSPARENT, 8, 3)
	detail.frame = Transform3D.IDENTITY
	for index in range(5):
		gloss.ball(at + Vector3(-0.5 + 0.26 * float(index), 0.63 - 0.03 * absf(float(index) - 2.0), 1.5 + 0.06 * float(index % 2)), 0.12, SWEETS[index], Color.TRANSPARENT, 6, 3)
	var globe: MeshInstance3D = world._sphere(at + centre, GLOBE, CREAM)
	globe.material_override = world._bubble_material()
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	globe.name = "GumballGlobe"
	return {"centre": at + centre, "radius": GLOBE}

## Raised belt conveyor between two points at ground height: legs, side rails, end rollers.
static func conveyor(kit: Kit, from: Vector3, to: Vector3, belt_y: float, width := 1.0) -> void:
	var detail := kit.detail
	var span := to - from
	var length := span.length()
	var forward := span / length
	var turn := Basis(forward.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, forward)
	var middle := (from + to) * 0.5
	detail.box(Vector3(middle.x, belt_y - 0.05, middle.z), Vector3(width, 0.08, length), DARK, turn)
	detail.box(Vector3(middle.x, belt_y - 0.22, middle.z), Vector3(width + 0.1, 0.22, length - 0.3), PLUM.darkened(0.1), turn)
	for side: float in [-1.0, 1.0]:
		detail.box(middle + turn * Vector3(side * (width * 0.5 + 0.06), belt_y + 0.02 - middle.y, 0), Vector3(0.1, 0.2, length + 0.1), MINT, turn)
		detail.box(middle + turn * Vector3(side * (width * 0.5 + 0.06), belt_y + 0.14 - middle.y, 0), Vector3(0.13, 0.04, length + 0.14), CREAM, turn)
	var legs := maxi(2, roundi(length / 1.7))
	for index in range(legs + 1):
		var at := from.lerp(to, float(index) / float(legs))
		for side: float in [-1.0, 1.0]:
			detail.box(at + turn * Vector3(side * width * 0.42, (belt_y - 0.3 - at.y) * 0.5, 0), Vector3(0.1, belt_y - 0.3 - at.y, 0.1), PLUM, turn)
		detail.box(at + turn * Vector3(0, 0.12, 0), Vector3(width, 0.06, 0.08), PLUM.darkened(0.15), turn)
	for end: Vector3 in [from, to]:
		pipe(detail, Vector3(end.x, belt_y - 0.09, end.z) - turn.x * (width * 0.5 + 0.1), Vector3(end.x, belt_y - 0.09, end.z) + turn.x * (width * 0.5 + 0.1), 0.1, STEEL, 8)

## Hooded tunnel a conveyor runs through; products appear and vanish inside it.
static func hood(world: Node3D, kit: Kit, at: Vector3, size: Vector3, tone: Color) -> void:
	kit.surface(plate(world, tone)).add(at + Vector3(0, size.y * 0.5, 0), size)
	var detail := kit.detail
	detail.box(at + Vector3(0, size.y + 0.04, 0), size * Vector3(1.06, 0, 1.06) + Vector3(0, 0.08, 0), CREAM)
	for face: float in [-1.0, 1.0]:
		# Rubber strips hang over both mouths.
		for strip in range(5):
			detail.box(at + Vector3(-0.4 + 0.2 * float(strip), size.y * 0.52, face * (size.z * 0.5 + 0.02)), Vector3(0.17, size.y * 0.4, 0.03), DARK if strip % 2 == 0 else PLUM)

## Cookie press gantry over a conveyor at `at` (belt centre). The moving head is separate.
static func press_frame(world: Node3D, kit: Kit, at: Vector3) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 0.82, 0.12, 0), Vector3(0.36, 0.24, 0.9), DARK)
		cane(detail, Vector3(side * 0.82, 0.24, 0), 2.2, 0.1)
		gauge(detail, Vector3(side * 0.82, 1.5, 0.14), 0.4 * side, 0.16)
	detail.frame = Transform3D.IDENTITY
	kit.surface(plate(world, PINK)).add(at + Vector3(0, 2.75, 0), Vector3(2.2, 0.7, 1.1))
	detail.box(at + Vector3(0, 3.13, 0), Vector3(2.3, 0.07, 1.2), CREAM)
	detail.box(at + Vector3(0, 2.38, 0), Vector3(2.3, 0.07, 1.2), CREAM)
	board(detail, at + Vector3(0, 2.75, 0.57), 1.5, 0.4)
	for bolt: float in [-0.5, 0.0, 0.5]:
		detail.ball(at + Vector3(bolt, 2.75, 0.63), 0.09, SWEETS[int(bolt * 2.0) + 2], Color.TRANSPARENT, 6, 2, 1.0, true)

## The press head and its piston rod; the origin is the stamping face.
static func press_head_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.75, 0), 0.11, 0.11, 1.3, STEEL, 8)
	sculpt.tube(Vector3(0, 0.2, 0), 0.34, 0.24, 0.24, COPPER, 10)
	sculpt.tube(Vector3(0, 0.04, 0), 0.38, 0.38, 0.08, COPPER.darkened(0.2), 10)
	return sculpt.mesh()

## Wrapping machine straddling a conveyor: plate housing, paper rolls and a chute.
static func wrapping_station(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> void:
	hood(world, kit, at, Vector3(1.6, 1.5, 1.7), MINT)
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	board(detail, Vector3(0, 1.1, 0.87), 1.1, 0.34)
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 0.55, 1.75, -0.3), Vector3(0.06, 0.5, 0.06), DARK)
	gauge(detail, Vector3(0.52, 0.5, 0.87), -0.5, 0.14)
	valve(detail, Vector3(-0.5, 0.5, 0.86))
	detail.frame = Transform3D.IDENTITY
	# Rolls of wrapping paper feed in from the top.
	pipe(gloss, at + Vector3(-0.62, 1.95, -0.3), at + Vector3(0.62, 1.95, -0.3), 0.26, PINK, 10)
	pipe(gloss, at + Vector3(-0.3, 1.95, -0.3), at + Vector3(0.0, 1.95, -0.3), 0.265, WHITE, 10)
	pipe(gloss, at + Vector3(0.3, 1.95, -0.3), at + Vector3(0.6, 1.95, -0.3), 0.265, WHITE, 10)

## Sample dispenser: a lidded jar of sweets on a cane pedestal with a cup in front.
## Returns where a sample rests in the cup.
static func dispenser(kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> Vector3:
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.tube(Vector3(0, 0.07, 0), 0.3, 0.24, 0.14, PLUM, 10)
	cane(detail, Vector3(0, 0.14, 0), 0.8, 0.09)
	detail.tube(Vector3(0, 1.0, 0), 0.3, 0.34, 0.12, CREAM, 10)
	detail.tube(Vector3(0, 1.58, 0), 0.3, 0.2, 0.1, RED, 10)
	detail.ball(Vector3(0, 1.68, 0), 0.09, LEMON, Color.TRANSPARENT, 6, 3)
	detail.box(Vector3(0, 0.98, 0.34), Vector3(0.12, 0.06, 0.2), STEEL)
	detail.tube(Vector3(0, 0.9, 0.5), 0.12, 0.17, 0.12, CREAM, 8)
	detail.frame = Transform3D.IDENTITY
	for index in range(7):
		var turn := Basis(Vector3.UP, 2.4 * float(index))
		gloss.ball(at + turn * Vector3(0.14, 1.14 + 0.1 * float(index % 3), 0), 0.1, SWEETS[index % SWEETS.size()], Color.TRANSPARENT, 6, 3)
	return at + Vector3(0, 1.0, 0.5)

## Wrapped sweet lying along Z with the origin at its centre.
static func sweet_mesh(wrapper := Color.WHITE) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.ball(Vector3.ZERO, 0.16, wrapper, wrapper.lerp(Color("#f6efe6"), 0.6), 8, 4, 0.8)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(0, 0, side * 0.22), 0.03, 0.13, 0.14, wrapper, 6, Basis(Vector3.RIGHT, side * PI * 0.5))
	return sculpt.mesh()

## Ball of dough; the press squashes it into a cookie by scaling.
static func dough_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.ball(Vector3(0, 0.15, 0), 0.2, Color.WHITE, Color.TRANSPARENT, 8, 4, 0.8)
	for chip in range(5):
		sculpt.ball(Basis(Vector3.UP, 1.26 * float(chip)) * Vector3(0.1, 0.27, 0), 0.04, CHOC.darkened(0.2), Color.TRANSPARENT, 4, 2)
	return sculpt.mesh()

## Marshmallow drifting down the syrup river; the origin is at the waterline.
static func marshmallow_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.08, 0), 0.3, 0.3, 0.3, Color.WHITE, 10)
	sculpt.tube(Vector3(0, 0.24, 0), 0.27, 0.2, 0.04, Color("#fff4f6"), 10)
	return sculpt.mesh()

static func slat_mesh(width: float) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, 0.015, 0), Vector3(width - 0.06, 0.03, 0.09), PLUM.lightened(0.18))
	return sculpt.mesh()

## Toothed wheel in the XY plane, one metre across; it turns about Z.
static func gear_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(Vector3.ZERO, 0.4, 0.4, 0.1, Color.WHITE, 12, face_on)
	sculpt.tube(Vector3(0, 0, 0.03), 0.16, 0.16, 0.12, Color("#f7e9d3"), 8, face_on)
	for tooth in range(8):
		var turn := Basis(Vector3.BACK, TAU * float(tooth) / 8.0)
		sculpt.box(turn * Vector3(0, 0.44, 0), Vector3(0.15, 0.14, 0.1), Color.WHITE, turn)
		sculpt.box(turn * Vector3(0.26, 0, 0.055), Vector3(0.1, 0.1, 0.02), Color("#d9c7b4"), turn)
	return sculpt.mesh()

## Fizzy soda basin the big bubbles hover over.
static func bubble_basin(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> void:
	kit.rounds(tile(world, "basin", 0, CREAM, LILAC, 0.5)).add(at + Vector3(0, 0.22, 0), Vector3(2.8, 0.44, 2.8))
	var detail := kit.detail
	detail.tube(at + Vector3(0, 0.46, 0), 1.46, 1.46, 0.08, CREAM, 16)
	gloss.tube(at + Vector3(0, 0.47, 0), 1.25, 1.25, 0.08, SKY, 16)
	gloss.tube(at + Vector3(0.15, 0.5, 0.1), 0.8, 0.7, 0.04, SKY.lightened(0.3), 12)
	detail.tube(at + Vector3(0, 0.75, 0), 0.2, 0.26, 0.6, COPPER, 8)
	detail.tube(at + Vector3(0, 1.08, 0), 0.34, 0.2, 0.1, COPPER.lightened(0.15), 8)
	for bollard in range(4):
		var out := Basis(Vector3.UP, TAU * (float(bollard) + 0.5) / 4.0) * Vector3(1.4, 0, 0)
		gumdrop(gloss, at + out + Vector3(0, 0.5, 0), 0.16, SWEETS[bollard + 1])

## Material lab bench: board cabinets, marble top, glassware and the hot plate the
## temperature sample sits on. Returns where the gauge needle pivots.
static func workbench(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> Vector3:
	kit.surface(boards(world, MINT)).add(at + Vector3(0, 0.6, 0), Vector3(2.3, 1.2, 2.9))
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 1.25, 0), Vector3(2.5, 0.1, 3.1), WHITE)
	detail.box(Vector3(0, 0.06, 0), Vector3(2.36, 0.12, 2.96), DARK)
	for drawer in range(3):
		detail.box(Vector3(-0.72 + 0.72 * float(drawer), 0.9, 1.46), Vector3(0.6, 0.34, 0.04), CREAM)
		detail.box(Vector3(-0.72 + 0.72 * float(drawer), 0.9, 1.49), Vector3(0.2, 0.05, 0.04), COPPER)
		detail.box(Vector3(-0.72 + 0.72 * float(drawer), 0.42, 1.46), Vector3(0.6, 0.44, 0.04), CREAM)
	# Hot plate under the sample, with the dial behind it.
	detail.tube(Vector3(0.3, 1.37, 0), 0.82, 0.86, 0.14, STEEL, 14)
	detail.tube(Vector3(0.3, 1.45, 0), 0.7, 0.7, 0.04, DARK, 14)
	detail.box(Vector3(-0.85, 2.0, -0.6), Vector3(0.12, 1.4, 0.12), STEEL)
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	detail.tube(Vector3(-0.85, 2.85, -0.6), 0.52, 0.52, 0.12, COPPER, 14, face_on)
	detail.tube(Vector3(-0.85, 2.85, -0.55), 0.44, 0.44, 0.06, WHITE, 14, face_on)
	for mark in range(3):
		var turn := Basis(Vector3.BACK, 1.0 - float(mark))
		detail.box(Vector3(-0.85, 2.85, -0.51) + turn * Vector3(0, 0.33, 0), Vector3(0.1, 0.12, 0.02), TEMPERATURE_TONES[mark], turn)
	detail.frame = Transform3D.IDENTITY
	# Flasks and jars.
	var glassware: Array[Vector3] = [Vector3(-0.8, 1.3, 1.1), Vector3(-0.45, 1.3, 1.2), Vector3(0.9, 1.3, 1.2), Vector3(-0.85, 1.3, -1.2), Vector3(0.2, 1.3, -1.25)]
	for index in range(glassware.size()):
		var spot: Vector3 = at + glassware[index]
		gloss.tube(spot + Vector3(0, 0.14, 0), 0.13, 0.1, 0.28, SWEETS[(index + 2) % SWEETS.size()], 8)
		gloss.tube(spot + Vector3(0, 0.32, 0), 0.06, 0.06, 0.1, WHITE, 6)
	return at + Vector3(-0.85, 2.85, -0.49)

## Shelf of ingredient jars against a fence.
static func shelf(world: Node3D, kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> void:
	kit.surface(boards(world, PINK)).add(at + Vector3(0, 0.55, -0.12), Vector3(2.2, 1.1, 0.5))
	var detail := kit.detail
	detail.box(at + Vector3(0, 1.13, -0.12), Vector3(2.3, 0.07, 0.6), WHITE)
	detail.box(at + Vector3(0, 1.62, -0.32), Vector3(2.3, 0.06, 0.3), WAFER)
	for side: float in [-1.0, 1.0]:
		detail.box(at + Vector3(side * 1.1, 1.4, -0.32), Vector3(0.06, 0.5, 0.3), WAFER.darkened(0.15))
	for jar in range(6):
		var spot := at + Vector3(-0.9 + 0.36 * float(jar), 1.17 if jar % 2 == 0 else 1.65, -0.1 if jar % 2 == 0 else -0.32)
		gloss.tube(spot + Vector3(0, 0.16, 0), 0.13, 0.13, 0.3, SWEETS[jar], 8)
		detail.tube(spot + Vector3(0, 0.34, 0), 0.14, 0.14, 0.06, CREAM, 8)

## Tilting mould table for the cookie flipping game.
static func mold_table(kit: Kit, gloss: Kit.Sculpt, at: Vector3) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	for corner_x: float in [-0.5, 0.5]:
		for corner_z: float in [-0.3, 0.3]:
			detail.box(Vector3(corner_x, 0.36, corner_z), Vector3(0.08, 0.72, 0.08), PLUM)
	detail.box(Vector3(0, 0.72, 0), Vector3(1.24, 0.06, 0.8), WAFER)
	var tilt := Basis(Vector3.RIGHT, 0.32)
	detail.box(Vector3(0, 0.92, 0), Vector3(1.0, 0.07, 0.66), STEEL, tilt)
	detail.box(Vector3(0, 0.82, -0.26), Vector3(0.1, 0.2, 0.1), DARK)
	detail.frame = Transform3D.IDENTITY
	for slot in range(6):
		var local := Vector3(-0.3 + 0.3 * float(slot % 3), 0.045, -0.16 + 0.32 * floorf(float(slot) / 3.0))
		gloss.tube(at + Vector3(0, 0.92, 0) + tilt * local, 0.11, 0.11, 0.04, WAFER.darkened(0.12) if slot % 2 == 0 else CHOC, 6, tilt)

## Banded cooling tower with a pinched waist; returns the height of its mouth.
static func cooling_tower(kit: Kit, at: Vector3) -> float:
	var detail := kit.detail
	var radii: Array[float] = [2.5, 2.15, 1.85, 1.7, 1.75, 1.95, 2.2]
	const BAND := 1.05
	for band in range(radii.size() - 1):
		detail.tube(at + Vector3(0, BAND * (float(band) + 0.5), 0), radii[band], radii[band + 1], BAND, PINK.lightened(0.1) if band % 2 == 0 else CREAM, 16)
		detail.tube(at + Vector3(0, BAND * float(band + 1), 0), radii[band + 1] + 0.04, radii[band + 1] + 0.04, 0.07, ROSE, 16)
		# Rivets ring every band.
		for rivet in range(8):
			var out := Basis(Vector3.UP, TAU * (float(rivet) + 0.5 * float(band % 2)) / 8.0) * Vector3(0, 0, (radii[band] + radii[band + 1]) * 0.5 + 0.02)
			detail.box(at + out + Vector3(0, BAND * (float(band) + 0.5), 0), Vector3(0.12, 0.12, 0.06), ROSE.lightened(0.2), Basis(Vector3.UP, TAU * (float(rivet) + 0.5 * float(band % 2)) / 8.0))
	var top := BAND * float(radii.size() - 1)
	detail.tube(at + Vector3(0, top + 0.08, 0), 2.3, 2.3, 0.16, ROSE, 16)
	detail.tube(at + Vector3(0, top + 0.1, 0), 1.9, 1.9, 0.14, DARK, 16)
	detail.box(at + Vector3(0, 0.6, 2.42), Vector3(0.7, 1.2, 0.1), PLUM)
	return top

## Entrance arch over the path home: two tall canes, the name board and a smaller
## board hanging under it.
static func gate_arch(world: Node3D, kit: Kit, at: Vector3, text: String, note: String) -> void:
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		detail.tube(at + Vector3(side * 2.6, 0.2, 0), 0.34, 0.28, 0.4, PLUM, 10)
		cane(detail, at + Vector3(side * 2.6, 0.4, 0), 3.0, 0.13, Vector3(-side * 0.9, 0, 0))
		lollipop_disc(kit, detail, at + Vector3(side * 2.6, 3.95, 0), 0.42, RED if side < 0.0 else MINT)
		detail.box(at + Vector3(side * 0.9, 2.52, 0), Vector3(0.04, 0.3, 0.04), DARK)
	board(detail, at + Vector3(0, 3.1, 0), 3.2, 0.9)
	lettering(world, text, at + Vector3(0, 3.1, 0.12), 32)
	board(detail, at + Vector3(0, 2.05, 0), 2.4, 0.74)
	lettering(world, note, at + Vector3(0, 2.05, 0.12), 24)

## The 反重力糖廠 gate, where sweets fall up: two candy canes standing on their
## hooks, syrup dripping upward off the name board, and gumdrops and jelly
## cubes floating in a rising column above it. `wide` is the clear span.
static func rift_gate(world: Node3D, kit: Kit, at: Vector3, wide: float) -> Label3D:
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		var foot := at + Vector3(side * wide * 0.5, 0, 0)
		detail.tube(foot + Vector3(0, 0.12, 0), 0.4, 0.34, 0.24, PLUM, 10)
		# Upside down: the hook curls on the ground, the straight end points up.
		detail.tube(foot + Vector3(0, 0.3, 0), 0.22, 0.22, 0.12, WHITE, 10)
		cane(detail, foot + Vector3(0, 0.36, 0), 3.2, 0.13, Vector3.ZERO, RED if side < 0.0 else MINT.darkened(0.25))
		detail.tube(foot + Vector3(-side * 0.32, 0.36, 0), 0.16, 0.16, 0.3, RED if side < 0.0 else MINT.darkened(0.25), 8, Basis(Vector3.BACK, PI * 0.5))
		lollipop_disc(kit, detail, foot + Vector3(0, 3.78, 0), 0.38, LEMON if side < 0.0 else PINK)
		kit.blocker(foot + Vector3(0, 1.0, 0), Vector3(0.36, 2.0, 0.36))
	board(detail, at + Vector3(0, 3.05, 0), wide - 0.4, 0.86)
	# Syrup running up off the board's top edge, thinning as it rises.
	for drip in 6:
		var x := -wide * 0.36 + float(drip) * wide * 0.144
		var rise := 0.28 + 0.22 * float((drip * 3) % 4)
		detail.tube(at + Vector3(x, 3.48 + rise * 0.5, 0.02), 0.07, 0.03, rise, CARAMEL, 6)
		detail.ball(at + Vector3(x, 3.5 + rise + 0.06, 0.02), 0.08, CARAMEL.lightened(0.15), Color.TRANSPARENT, 6, 3)
	# A column of sweets falling upward, smallest highest.
	for floating in 5:
		var lift := 4.1 + float(floating) * 0.42
		var drift := sin(float(floating) * 1.9) * 0.6
		var tone: Color = SWEETS[floating % SWEETS.size()]
		if floating % 2 == 0:
			detail.ball(at + Vector3(drift, lift, 0), 0.22 - 0.025 * floating, tone, tone.lightened(0.3), 8, 4, 0.8, true)
		else:
			detail.box(at + Vector3(drift, lift, 0), Vector3.ONE * (0.3 - 0.03 * floating), tone.lightened(0.1), Basis(Vector3(1, 1, 0).normalized(), 0.6 * floating))
	return lettering(world, "反重力糖廠", at + Vector3(0, 3.05, 0.12), 22)


## Crates and a syrup drum; `variation` reshuffles them.
static func crates(kit: Kit, at: Vector3, variation: int) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, 0.5 * float(variation)), at)
	var tones: Array[Color] = [WAFER, PINK.lerp(WAFER, 0.4), MINT.lerp(WAFER, 0.4), WAFER.darkened(0.12)]
	for crate in range(3 + variation % 2):
		var corner := Vector3(-0.38 + 0.74 * float(crate % 2), 0.32 + 0.64 * floorf(float(crate) / 2.0), 0.08 * float(crate))
		var turn := Basis(Vector3.UP, 0.18 * float(crate))
		detail.box(corner, Vector3(0.64, 0.64, 0.64), tones[(crate + variation) % tones.size()], turn)
		detail.box(corner + Vector3(0, 0.33, 0), Vector3(0.7, 0.05, 0.7), CHOC, turn)
		detail.box(corner + turn * Vector3(0, 0, 0.325), Vector3(0.3, 0.2, 0.02), CREAM, turn)
	detail.tube(Vector3(0.2, 0.42, 0.9), 0.3, 0.3, 0.84, SWEETS[variation % SWEETS.size()].lerp(STEEL, 0.25), 10)
	for hoop: float in [0.2, 0.64]:
		detail.tube(Vector3(0.2, hoop, 0.9), 0.32, 0.32, 0.06, DARK, 10)
	detail.tube(Vector3(0.2, 0.86, 0.9), 0.24, 0.24, 0.04, CARAMEL, 8)
	detail.frame = Transform3D.IDENTITY

## Flat swirl disc facing the camera: lollipop heads on gates and flowers.
static func lollipop_disc(kit: Kit, sculpt: Kit.Sculpt, centre: Vector3, radius: float, tone: Color) -> void:
	var facing := kit.view_basis * Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(centre, radius, radius, 0.08, tone, 10, facing)
	sculpt.tube(centre + kit.view_basis.z * 0.05, radius * 0.62, radius * 0.56, 0.03, WHITE, 10, facing)
	sculpt.tube(centre + kit.view_basis.z * 0.065, radius * 0.3, radius * 0.26, 0.03, tone, 8, facing)
