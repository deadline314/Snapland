extends RefCounted
## Toys of the clockwork toy town. Buildings are stacked from batched unit blocks
## (one draw per shape for the whole town); bespoke trim merges into the scenery
## kit's detail mesh, and the few parts that move come back as their own meshes.

const Kit := preload("res://game/world/scenery_kit.gd")
const BLOCK := preload("res://game/world/toy_block.gdshader")
const RED := Color("#d8584c")
const ORANGE := Color("#ec9a4c")
const YELLOW := Color("#f2c84f")
const GREEN := Color("#69ad6a")
const BLUE := Color("#4d8fc6")
const TEAL := Color("#4f9c95")
const PURPLE := Color("#9a78c0")
const PINK := Color("#ee9fb0")
const CREAM := Color("#f6ead0")
const WOOD := Color("#dcb682")
const DARK_WOOD := Color("#7a5a44")
const BRASS := Color("#c99b50")
const COPPER := Color("#c0764a")
const STEEL := Color("#aab2b6")
const INK := Color("#343b42")
const LEAF := Color("#4f9a58")
const LEAF_DARK := Color("#3c7f52")
const LEAF_LIGHT := Color("#7cba63")
const WINDOW := Color("#ffe9ae")
const RAINBOW: Array[Color] = [RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE, PINK]
const PRIMARY: Array[Color] = [RED, YELLOW, BLUE, GREEN]
## Pitch radius of a gear is teeth * GEAR_MODULE / 2, so gears of any size mesh.
const GEAR_MODULE := 0.125
## What house() returns for a house without a wind-up key.
const NO_KEY := Transform3D(Basis.IDENTITY, Vector3.INF)
## Five by five pixel faces for the alphabet cubes.
const GLYPHS := {
	"A": [".###.", "#...#", "#####", "#...#", "#...#"],
	"B": ["####.", "#...#", "####.", "#...#", "####."],
	"C": [".####", "#....", "#....", "#....", ".####"],
	"D": ["####.", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "####.", "#....", "#####"],
	"1": ["..#..", ".##..", "..#..", "..#..", ".###."],
	"2": ["####.", "....#", ".###.", "#....", "#####"],
	"3": ["####.", "....#", ".###.", "....#", "####."],
	"star": ["..#..", ".###.", "#####", ".###.", ".#.#."],
	"heart": [".#.#.", "#####", "#####", ".###.", "..#.."],
}

## The batched unit shapes every building is stacked from.
class Blocks:
	var kit: Kit
	var box: Kit.Batch
	var column: Kit.Batch
	var cone: Kit.Batch
	var roof: Kit.Batch
	var arch: Kit.Batch
	var ball: Kit.Batch

static func blocks(world: Node3D, kit: Kit) -> Blocks:
	var shapes := Blocks.new()
	shapes.kit = kit
	var turned := _paint(world, "turned", 0.0, 1.0, 0.0)
	var plain := _paint(world, "plain", 0.0, 0.0, 0.0)
	shapes.box = kit.surface(_paint(world, "box", 1.0, 0.0, 0.0))
	var column := CylinderMesh.new()
	column.top_radius = 0.5
	column.bottom_radius = 0.5
	column.height = 1.0
	column.radial_segments = 14
	column.rings = 1
	shapes.column = kit.batch("toy-columns", column, turned)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 14
	cone.rings = 1
	shapes.cone = kit.batch("toy-cones", cone, turned)
	shapes.roof = kit.batch("toy-roofs", PrismMesh.new(), _paint(world, "roof", 0.0, 0.0, 3.4))
	shapes.arch = kit.batch("toy-arches", arch_mesh(), plain)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 5
	shapes.ball = kit.batch("toy-balls", sphere, plain)
	return shapes

static func _paint(world: Node3D, key: String, chamfer: float, turned: float, courses: float) -> ShaderMaterial:
	var cache_key := "toy-block:" + key
	if world.material_cache.has(cache_key): return world.material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = BLOCK
	material.set_shader_parameter("chamfer", chamfer)
	material.set_shader_parameter("turned", turned)
	material.set_shader_parameter("courses", courses)
	world.material_cache[cache_key] = material
	return material

## Adds a quad whose visible side faces `toward`, whatever order the corners come in.
static func _quad_toward(sculpt: Kit.Sculpt, a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, color: Color) -> void:
	if (c - a).cross(b - a).dot(toward) < 0.0:
		sculpt.quad(d, c, b, a, color)
	else:
		sculpt.quad(a, b, c, d, color)

## Unit block with a round-topped doorway through its depth (local Z).
static func arch_mesh() -> ArrayMesh:
	const OPENING := 0.3
	const SPRING := 0.02
	const STEPS := 8
	var sculpt := Kit.Sculpt.new()
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * (0.5 + OPENING) * 0.5, (SPRING - 0.5) * 0.5, 0), Vector3(0.5 - OPENING, SPRING + 0.5, 1.0), Color.WHITE)
		_quad_toward(sculpt, Vector3(side * 0.5, SPRING, 0.5), Vector3(side * 0.5, 0.5, 0.5), Vector3(side * 0.5, 0.5, -0.5), Vector3(side * 0.5, SPRING, -0.5), Vector3(side, 0, 0), Color.WHITE)
	sculpt.quad(Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Color.WHITE)
	var profile: Array[Vector2] = [Vector2(0.5, SPRING)]
	for step in range(STEPS + 1):
		var angle := PI * float(step) / float(STEPS)
		profile.append(Vector2(cos(angle) * OPENING, SPRING + sin(angle) * OPENING))
	profile.append(Vector2(-0.5, SPRING))
	for index in range(profile.size() - 1):
		var right := profile[index]
		var left := profile[index + 1]
		for face: float in [-0.5, 0.5]:
			_quad_toward(sculpt, Vector3(left.x, 0.5, face), Vector3(right.x, 0.5, face), Vector3(right.x, right.y, face), Vector3(left.x, left.y, face), Vector3(0, 0, face), Color.WHITE)
		if index > 0 and index < profile.size() - 2:
			var middle := (left + right) * 0.5
			_quad_toward(sculpt, Vector3(left.x, left.y, 0.5), Vector3(right.x, right.y, 0.5), Vector3(right.x, right.y, -0.5), Vector3(left.x, left.y, -0.5), Vector3(-middle.x, SPRING - middle.y, 0), Color(0.82, 0.82, 0.82))
	return sculpt.mesh()

## Flat pixel glyph on a face: `right` and `up` span the face, visible from right x up.
static func stamp(sculpt: Kit.Sculpt, glyph: String, center: Vector3, right: Vector3, up: Vector3, size: float, color: Color) -> void:
	var rows: Array = GLYPHS.get(glyph, GLYPHS.star)
	var pixel := size / 5.0
	var half_right := right * pixel * 0.5
	var half_up := up * pixel * 0.5
	for row in range(5):
		for column in range(5):
			if str(rows[row])[column] != "#": continue
			var at := center + right * float(column - 2) * pixel + up * float(2 - row) * pixel
			sculpt.quad(at - half_right + half_up, at + half_right + half_up, at + half_right - half_up, at - half_right - half_up, color)

## A toy block house whose front faces local +Z. Spec keys: w, d, h, body, roof;
## optional yaw, top (second block tone), roof_kind ("gable", "flat", "cone"),
## windows, door (x offset or INF), chimney, key. Returns where its wind-up key
## turns, or NO_KEY.
static func house(shapes: Blocks, at: Vector3, spec: Dictionary) -> Transform3D:
	var kit := shapes.kit
	var width: float = spec.w
	var depth: float = spec.d
	var height: float = spec.h
	var body: Color = spec.body
	var upper: Color = spec.get("top", body.lightened(0.16))
	var roof: Color = spec.roof
	var split := height * 0.52
	var front := depth * 0.5
	var frame := Transform3D(Basis(Vector3.UP, float(spec.get("yaw", 0.0))), at)
	var turn := frame.basis
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	kit.detail.frame = frame
	kit.glow.frame = frame
	shapes.box.add(frame * Vector3(0, 0.11, 0), Vector3(width + 0.14, 0.22, depth + 0.14), turn, body.darkened(0.3))
	shapes.box.add(frame * Vector3(0, (0.22 + split) * 0.5, 0), Vector3(width, split - 0.22, depth), turn, body)
	shapes.box.add(frame * Vector3(0, (split + height) * 0.5, 0), Vector3(width - 0.08, height - split, depth - 0.08), turn, upper)
	var roof_height: float = 0.0
	match str(spec.get("roof_kind", "gable")):
		"gable":
			roof_height = width * 0.42
			shapes.roof.add(frame * Vector3(0, height + roof_height * 0.5, 0), Vector3(width + 0.34, roof_height, depth + 0.26), turn, roof)
			kit.glow.tube(Vector3(0, height + roof_height * 0.36, front + 0.14), 0.15, 0.15, 0.02, WINDOW, 8, facing)
			kit.detail.tube(Vector3(0, height + roof_height * 0.36, front + 0.132), 0.2, 0.2, 0.02, CREAM, 8, facing)
		"cone":
			roof_height = width * 0.75
			shapes.cone.add(frame * Vector3(0, height + roof_height * 0.5, 0), Vector3(width * 1.25, roof_height, width * 1.25), turn, roof)
		_:
			roof_height = 0.2
			shapes.box.add(frame * Vector3(0, height + 0.1, 0), Vector3(width + 0.24, 0.2, depth + 0.24), turn, roof)
			for merlon in range(4):
				shapes.box.add(frame * Vector3((float(merlon) - 1.5) * width / 3.6, height + 0.34, front - 0.06), Vector3(0.26, 0.28, 0.26), turn, roof.lightened(0.1))
	var face := Vector3(0, 0, front)
	var door_x: float = spec.get("door", 0.0)
	if is_finite(door_x):
		kit.detail.box(face + Vector3(door_x, 0.66, 0.012), Vector3(0.52, 0.88, 0.03), body.darkened(0.45))
		kit.detail.tube(face + Vector3(door_x, 1.1, 0.012), 0.26, 0.26, 0.03, body.darkened(0.45), 10, facing)
		kit.detail.box(face + Vector3(door_x, 0.62, 0.03), Vector3(0.4, 0.8, 0.02), roof.darkened(0.1))
		kit.detail.box(face + Vector3(door_x + 0.12, 0.62, 0.045), Vector3(0.06, 0.06, 0.03), BRASS)
		kit.detail.box(face + Vector3(door_x, 0.2, 0.16), Vector3(0.7, 0.1, 0.3), CREAM.darkened(0.1))
	# Windows fill the upper block; a lower pair flanks the door on wide fronts.
	var spots: Array[Vector2] = []
	var count := int(spec.get("windows", 2))
	for index in range(count):
		spots.append(Vector2((float(index) - float(count - 1) * 0.5) * width / float(count + 0.4), (split + height) * 0.5 + 0.02))
	if width > 2.3 and is_finite(door_x):
		for side: float in [-1.0, 1.0]:
			if absf(side * width * 0.3 - door_x) > 0.6:
				spots.append(Vector2(side * width * 0.3, 0.86))
	for spot in spots:
		window(kit, face + Vector3(spot.x, spot.y, 0.0), minf(0.42, (height - split) * 0.5))
	kit.detail.frame = Transform3D.IDENTITY
	kit.glow.frame = Transform3D.IDENTITY
	if spec.get("chimney", false):
		shapes.box.add(frame * Vector3(width * 0.26, height + roof_height * 0.62, -depth * 0.12), Vector3(0.3, 0.7, 0.3), turn, CREAM.darkened(0.12))
		shapes.box.add(frame * Vector3(width * 0.26, height + roof_height * 0.62 + 0.38, -depth * 0.12), Vector3(0.4, 0.1, 0.4), turn, body.darkened(0.3))
	return Transform3D(turn, frame * (face + Vector3(width * 0.5 - 0.34, split - 0.3, 0.0))) if spec.get("key", false) else NO_KEY

## A cross-barred window on a +Z face; its panes glow after dark.
static func window(kit: Kit, at: Vector3, size: float) -> void:
	kit.detail.box(at + Vector3(0, 0, 0.012), Vector3(size + 0.12, size * 1.15 + 0.12, 0.03), CREAM)
	kit.glow.box(at + Vector3(0, 0, 0.024), Vector3(size, size * 1.15, 0.03), WINDOW)
	kit.detail.box(at + Vector3(0, 0, 0.04), Vector3(0.04, size * 1.15, 0.02), CREAM)
	kit.detail.box(at + Vector3(0, 0, 0.04), Vector3(size, 0.04, 0.02), CREAM)
	kit.detail.box(at + Vector3(0, -size * 0.62 - 0.05, 0.06), Vector3(size + 0.2, 0.06, 0.1), CREAM.darkened(0.08))

## Round block tower with a cone roof and a banded top.
static func turret(shapes: Blocks, at: Vector3, radius: float, height: float, body: Color, roof: Color) -> void:
	shapes.column.add(at + Vector3(0, 0.12, 0), Vector3(radius * 2.2, 0.24, radius * 2.2), Basis.IDENTITY, body.darkened(0.28))
	shapes.column.add(at + Vector3(0, height * 0.5 + 0.12, 0), Vector3(radius * 2.0, height - 0.24, radius * 2.0), Basis.IDENTITY, body)
	shapes.column.add(at + Vector3(0, height + 0.1, 0), Vector3(radius * 2.3, 0.2, radius * 2.3), Basis.IDENTITY, body.lightened(0.2))
	shapes.cone.add(at + Vector3(0, height + 0.2 + radius * 0.85, 0), Vector3(radius * 2.5, radius * 1.7, radius * 2.5), Basis.IDENTITY, roof)
	shapes.ball.add(at + Vector3(0, height + 0.2 + radius * 1.7, 0), Vector3.ONE * 0.16, Basis.IDENTITY, YELLOW)
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	shapes.kit.detail.box(at + Vector3(0, height * 0.62, radius + 0.005), Vector3(0.26, 0.5, 0.04), CREAM)
	shapes.kit.glow.box(at + Vector3(0, height * 0.62, radius + 0.02), Vector3(0.16, 0.4, 0.03), WINDOW)
	shapes.kit.detail.tube(at + Vector3(0, height * 0.62 + 0.25, radius + 0.005), 0.13, 0.13, 0.04, CREAM, 8, facing)

## Castle gate across a path that runs along Z: two round towers, an arch block and
## battlements. `at` is the middle of the roadway. Returns the two flag mast tops.
static func castle_gate(shapes: Blocks, at: Vector3) -> Array[Vector3]:
	const HALF := 3.25
	const TOWER_HEIGHT := 3.0
	var masts: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var foot := at + Vector3(side * HALF, 0, 0)
		turret(shapes, foot, 0.85, TOWER_HEIGHT, CREAM.darkened(0.06) if side < 0.0 else CREAM.darkened(0.02), RED if side < 0.0 else BLUE)
		shapes.kit.detail.tube(foot + Vector3(0, TOWER_HEIGHT + 2.1, 0), 0.03, 0.03, 1.0, DARK_WOOD, 6)
		masts.append(foot + Vector3(0.03, TOWER_HEIGHT + 2.55, 0))
	shapes.arch.add(at + Vector3(0, 1.45, 0), Vector3(HALF * 2.0 - 1.5, 2.9, 0.9), Basis.IDENTITY, YELLOW.lerp(CREAM, 0.35))
	shapes.box.add(at + Vector3(0, 3.0, 0), Vector3(HALF * 2.0 - 1.3, 0.2, 1.1), Basis.IDENTITY, ORANGE)
	for merlon in range(5):
		shapes.box.add(at + Vector3((float(merlon) - 2.0) * 1.0, 3.28, 0.3), Vector3(0.5, 0.36, 0.4), Basis.IDENTITY, PRIMARY[merlon % 4])
	stamp(shapes.kit.detail, "star", at + Vector3(0, 2.52, 0.46), Vector3.RIGHT, Vector3.UP, 0.5, RED)
	return masts

## Stacked alphabet cubes; `faces` names the glyph on each cube from the bottom up.
static func cube_stack(shapes: Blocks, at: Vector3, faces: Array, size: float, variation: int) -> void:
	var y := 0.0
	for index in range(faces.size()):
		var edge := size * (1.0 - 0.12 * float(index))
		var paint: Color = PRIMARY[(index + variation) % 4]
		var basis := Basis(Vector3.UP, 0.22 * sin(float(index * 3 + variation) * 1.7))
		var center := at + Vector3(0.06 * size * sin(float(index + variation) * 2.3), y + edge * 0.5, 0.0)
		shapes.box.add(center, Vector3.ONE * edge, basis, paint)
		var ink := CREAM if paint != YELLOW else RED
		var glyph := str(faces[index])
		stamp(shapes.kit.detail, glyph, center + basis * Vector3(0, 0, edge * 0.5 + 0.006), basis.x, Vector3.UP, edge * 0.62, ink)
		stamp(shapes.kit.detail, glyph, center + basis * Vector3(edge * 0.5 + 0.006, 0, 0), -basis.z, Vector3.UP, edge * 0.62, ink)
		if index == faces.size() - 1:
			stamp(shapes.kit.detail, glyph, center + Vector3(0, edge * 0.5 + 0.006, 0), basis.x, -basis.z, edge * 0.62, ink)
		y += edge

## Giant crayon (or pencil) standing as a fence post.
static func crayon(shapes: Blocks, foot: Vector3, height: float, paint: Color, lean := Basis.IDENTITY, pencil := false) -> void:
	const RADIUS := 0.12
	var body := height * 0.8
	shapes.column.add(foot + lean * Vector3(0, body * 0.5, 0), Vector3(RADIUS * 2.0, body, RADIUS * 2.0), lean, YELLOW if pencil else paint)
	if pencil:
		shapes.column.add(foot + lean * Vector3(0, 0.07, 0), Vector3(RADIUS * 2.1, 0.14, RADIUS * 2.1), lean, PINK)
		shapes.cone.add(foot + lean * Vector3(0, body + (height - body) * 0.5, 0), Vector3(RADIUS * 2.0, height - body, RADIUS * 2.0), lean, WOOD)
		shapes.cone.add(foot + lean * Vector3(0, height - 0.04, 0), Vector3(RADIUS * 0.7, (height - body) * 0.36, RADIUS * 0.7), lean, INK)
	else:
		shapes.column.add(foot + lean * Vector3(0, body * 0.48, 0), Vector3(RADIUS * 2.12, body * 0.4, RADIUS * 2.12), lean, paint.lerp(CREAM, 0.72))
		shapes.cone.add(foot + lean * Vector3(0, body + (height - body) * 0.5, 0), Vector3(RADIUS * 1.7, height - body, RADIUS * 1.7), lean, paint.darkened(0.12))

## Wooden toy tree on a round base: "cone" stacks three tiers, "ball" is a lollipop.
static func toy_tree(shapes: Blocks, foot: Vector3, height: float, kind: String, tint: Color) -> void:
	shapes.column.add(foot + Vector3(0, 0.04, 0), Vector3(height * 0.3, 0.08, height * 0.3), Basis.IDENTITY, WOOD.darkened(0.08))
	shapes.column.add(foot + Vector3(0, height * 0.22, 0), Vector3(height * 0.075, height * 0.44, height * 0.075), Basis.IDENTITY, DARK_WOOD.lightened(0.12))
	if kind == "ball":
		shapes.ball.add(foot + Vector3(0, height * 0.68, 0), Vector3(height * 0.62, height * 0.64, height * 0.62), Basis.IDENTITY, tint)
		return
	for tier in range(3):
		var share := float(tier) / 2.0
		shapes.cone.add(foot + Vector3(0, height * (0.46 + 0.2 * share), 0), Vector3.ONE * height * lerpf(0.56, 0.3, share) * Vector3(1, 0.72, 1), Basis.IDENTITY, tint.lightened(0.07 * float(tier)))

## Gear lying in its local XY plane, facing +Z. Near-white, so the instance colour is the metal.
static func gear_mesh(teeth: int) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var pitch := float(teeth) * GEAR_MODULE * 0.5
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(Vector3.ZERO, pitch - 0.07, pitch - 0.07, 0.1, Color(0.95, 0.95, 0.95), teeth * 2, facing)
	for tooth in range(teeth):
		var turn := Basis(Vector3.BACK, TAU * float(tooth) / float(teeth))
		sculpt.box(turn * Vector3(pitch, 0, 0), Vector3(0.2, 0.17, 0.1), Color(0.84, 0.84, 0.84), turn)
	var holes := 4 if teeth < 12 else 6
	for hole in range(holes):
		var turn := Basis(Vector3.BACK, TAU * (float(hole) + 0.5) / float(holes))
		sculpt.tube(turn * Vector3(pitch * 0.56, 0, 0.051), pitch * 0.15, pitch * 0.15, 0.006, Color(0.32, 0.3, 0.3), 8, facing)
	sculpt.tube(Vector3(0, 0, 0.065), pitch * 0.26, pitch * 0.22, 0.05, Color(0.72, 0.72, 0.72), 10, facing)
	sculpt.tube(Vector3(0, 0, 0.1), 0.05, 0.05, 0.04, Color(0.4, 0.4, 0.42), 6, facing)
	return sculpt.mesh()

## Butterfly wind-up key that turns around local Z; the shaft enters the wall behind it.
static func key_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(Vector3(0, 0, 0.1), 0.045, 0.045, 0.24, BRASS.darkened(0.15), 6, facing)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(side * 0.2, 0, 0.2), 0.17, 0.17, 0.05, BRASS, 10, facing)
		sculpt.tube(Vector3(side * 0.2, 0, 0.228), 0.08, 0.08, 0.006, BRASS.darkened(0.45), 8, facing)
	sculpt.box(Vector3(0, 0, 0.2), Vector3(0.14, 0.1, 0.05), BRASS.lightened(0.1))
	return sculpt.mesh()

## Tin soldier facing +Z, 1.55 m tall, without his saluting arm.
static func soldier_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var coat := Color("#d2463e")
	var trousers := Color("#2f4a78")
	var skin := Color("#f2c9a0")
	var black := Color("#2a2a30")
	sculpt.tube(Vector3(0, 0.025, 0), 0.27, 0.27, 0.05, LEAF_DARK, 10)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.09, 0.36, 0), Vector3(0.13, 0.4, 0.15), trousers)
		sculpt.box(Vector3(side * 0.09, 0.11, 0.02), Vector3(0.14, 0.12, 0.2), black)
		sculpt.box(Vector3(side * 0.12, 1.13, 0.125), Vector3(0.04, 0.04, 0.02), black)
		sculpt.box(Vector3(side * 0.1, 1.05, 0.125), Vector3(0.05, 0.035, 0.02), PINK)
	sculpt.box(Vector3(0, 0.77, 0), Vector3(0.4, 0.42, 0.24), coat)
	sculpt.box(Vector3(0, 0.6, 0), Vector3(0.42, 0.07, 0.26), CREAM)
	sculpt.box(Vector3(0, 0.78, 0.125), Vector3(0.05, 0.5, 0.02), CREAM, Basis(Vector3.BACK, 0.62))
	sculpt.box(Vector3(0, 0.78, 0.125), Vector3(0.05, 0.5, 0.02), CREAM, Basis(Vector3.BACK, -0.62))
	sculpt.box(Vector3(0, 0.78, 0.14), Vector3(0.07, 0.07, 0.02), YELLOW)
	sculpt.box(Vector3(0, 0.99, 0), Vector3(0.46, 0.06, 0.26), YELLOW)
	sculpt.box(Vector3(0, 1.1, 0), Vector3(0.26, 0.22, 0.24), skin)
	sculpt.box(Vector3(0, 1.045, 0.125), Vector3(0.14, 0.03, 0.02), black)
	sculpt.tube(Vector3(0, 1.39, 0), 0.15, 0.14, 0.36, black, 10)
	sculpt.tube(Vector3(0, 1.23, 0), 0.165, 0.165, 0.05, YELLOW, 10)
	sculpt.box(Vector3(0, 1.22, 0.14), Vector3(0.22, 0.03, 0.1), black)
	sculpt.box(Vector3(0, 1.62, 0), Vector3(0.07, 0.12, 0.07), coat)
	# Left arm at his side, holding the rifle upright.
	sculpt.box(Vector3(0.26, 0.76, 0), Vector3(0.1, 0.42, 0.12), coat)
	sculpt.box(Vector3(0.26, 0.52, 0.02), Vector3(0.11, 0.1, 0.13), CREAM)
	sculpt.box(Vector3(0.3, 0.95, 0.1), Vector3(0.05, 0.95, 0.05), DARK_WOOD)
	sculpt.box(Vector3(0.3, 1.5, 0.1), Vector3(0.025, 0.2, 0.025), STEEL)
	return sculpt.mesh()

## The soldier's right arm, hanging from its shoulder at the origin.
static func soldier_arm_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, -0.2, 0), Vector3(0.1, 0.42, 0.12), Color("#d2463e"))
	sculpt.box(Vector3(0, -0.44, 0.01), Vector3(0.11, 0.1, 0.13), CREAM)
	return sculpt.mesh()

## Jack-in-the-box parts: the lid hinged at its origin, a unit-high spring and the head.
static func jack_lid_mesh(size: float) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, 0.04, size * 0.5), Vector3(size + 0.06, 0.08, size + 0.06), BLUE)
	stamp(sculpt, "star", Vector3(0, 0.086, size * 0.5), Vector3.RIGHT, Vector3.FORWARD, size * 0.6, YELLOW)
	return sculpt.mesh()

static func jack_spring_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for coil in range(7):
		var lean := Basis(Vector3.BACK, 0.42 if coil % 2 == 0 else -0.42)
		sculpt.box(Vector3(0, (float(coil) + 0.5) / 7.0, 0), Vector3(0.36, 0.035, 0.07), STEEL.darkened(0.12 * float(coil % 2)), lean)
	return sculpt.mesh()

static func jack_head_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var skin := Color("#fbe3c6")
	sculpt.tube(Vector3(0, 0.04, 0), 0.34, 0.3, 0.08, CREAM, 10)
	sculpt.tube(Vector3(0, 0.12, 0), 0.24, 0.3, 0.08, RED, 10)
	sculpt.tube(Vector3(0, 0.24, 0), 0.2, 0.27, 0.16, skin, 10)
	sculpt.tube(Vector3(0, 0.42, 0), 0.27, 0.27, 0.2, skin, 10)
	sculpt.tube(Vector3(0, 0.58, 0), 0.27, 0.17, 0.12, skin, 10)
	sculpt.tube(Vector3(0, 0.84, 0), 0.19, 0.02, 0.44, PURPLE, 10)
	sculpt.tube(Vector3(0, 0.66, 0), 0.21, 0.21, 0.06, YELLOW, 10)
	sculpt.box(Vector3(0, 1.08, 0), Vector3(0.11, 0.11, 0.11), YELLOW)
	sculpt.box(Vector3(0, 0.4, 0.28), Vector3(0.11, 0.11, 0.08), RED)
	sculpt.box(Vector3(0, 0.27, 0.25), Vector3(0.2, 0.04, 0.05), RED.darkened(0.15))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.11, 0.48, 0.27), Vector3(0.05, 0.07, 0.03), INK)
		sculpt.box(Vector3(side * 0.17, 0.36, 0.24), Vector3(0.07, 0.05, 0.03), PINK)
		sculpt.box(Vector3(side * 0.31, 0.45, 0), Vector3(0.12, 0.2, 0.16), ORANGE)
	return sculpt.mesh()

## Spinning top standing on its tip at the origin.
static func top_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.07, 0), 0.01, 0.12, 0.14, STEEL, 10)
	sculpt.tube(Vector3(0, 0.27, 0), 0.12, 0.5, 0.26, RED, 14)
	sculpt.tube(Vector3(0, 0.46, 0), 0.5, 0.5, 0.12, YELLOW, 14)
	sculpt.tube(Vector3(0, 0.64, 0), 0.5, 0.2, 0.24, BLUE, 14)
	sculpt.tube(Vector3(0, 0.81, 0), 0.2, 0.08, 0.1, CREAM, 10)
	sculpt.tube(Vector3(0, 0.97, 0), 0.05, 0.05, 0.22, DARK_WOOD.lightened(0.2), 8)
	sculpt.tube(Vector3(0, 1.1, 0), 0.09, 0.09, 0.06, RED, 8)
	for mark in range(4):
		var turn := Basis(Vector3.UP, TAU * float(mark) / 4.0)
		sculpt.box(turn * Vector3(0.5, 0.46, 0), Vector3(0.03, 0.13, 0.26), GREEN, turn)
		sculpt.box(turn * Vector3(0.33, 0.66, 0.0), Vector3(0.05, 0.03, 0.16), CREAM, turn * Basis(Vector3.BACK, -0.9))
	return sculpt.mesh()

## The turning part of the music-box carousel: deck, pole, striped canopy and horses.
static func carousel_rotor_mesh() -> ArrayMesh:
	const SEGMENTS := 12
	const RIM := 2.05
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.04, 0), 1.8, 1.8, 0.08, WOOD, 20)
	sculpt.tube(Vector3(0, 0.09, 0), 1.72, 1.72, 0.02, WOOD.darkened(0.15), 20)
	for band in range(6):
		sculpt.tube(Vector3(0, 0.3 + 0.4 * float(band), 0), 0.3, 0.3, 0.4, CREAM if band % 2 == 0 else RED, 10)
	var apex := Vector3(0, 3.5, 0)
	for segment in range(SEGMENTS):
		var from := Vector3(cos(TAU * float(segment) / SEGMENTS), 0, sin(TAU * float(segment) / SEGMENTS))
		var to := Vector3(cos(TAU * float(segment + 1) / SEGMENTS), 0, sin(TAU * float(segment + 1) / SEGMENTS))
		var paint := RED if segment % 2 == 0 else CREAM
		sculpt.sheet(apex, Vector3(0, 2.62, 0) + to * RIM, Vector3(0, 2.62, 0) + from * RIM, paint)
		var middle := (from + to).normalized()
		var turn := Basis(Vector3.UP, atan2(middle.x, middle.z))
		sculpt.box(Vector3(0, 2.5, 0) + middle * RIM * 0.97, Vector3(1.04, 0.24 if segment % 2 == 0 else 0.18, 0.05), YELLOW if segment % 2 == 0 else BLUE, turn)
	sculpt.tube(Vector3(0, 3.56, 0), 0.1, 0.1, 0.12, YELLOW, 8)
	sculpt.tube(Vector3(0, 3.72, 0), 0.02, 0.14, 0.2, YELLOW, 8)
	for horse in range(6):
		var turn := Basis(Vector3.UP, TAU * float(horse) / 6.0)
		var lift := 0.62 if horse % 2 == 0 else 0.92
		var coat: Color = [CREAM, PINK, TEAL.lightened(0.3)][horse % 3]
		sculpt.frame = Transform3D(turn, turn * Vector3(1.32, 0, 0))
		sculpt.tube(Vector3(0, 1.38, 0), 0.03, 0.03, 2.6, BRASS, 6)
		sculpt.box(Vector3(0, lift, 0), Vector3(0.24, 0.26, 0.62), coat)
		sculpt.box(Vector3(0, lift + 0.26, -0.28), Vector3(0.18, 0.34, 0.2), coat, Basis(Vector3.RIGHT, 0.4))
		sculpt.box(Vector3(0, lift + 0.42, -0.42), Vector3(0.16, 0.16, 0.3), coat)
		sculpt.box(Vector3(0, lift + 0.34, -0.2), Vector3(0.06, 0.3, 0.14), PRIMARY[horse % 4], Basis(Vector3.RIGHT, 0.4))
		sculpt.box(Vector3(0, lift + 0.14, 0.02), Vector3(0.27, 0.05, 0.26), PRIMARY[(horse + 1) % 4])
		sculpt.box(Vector3(0, lift + 0.02, 0.36), Vector3(0.06, 0.26, 0.06), PRIMARY[horse % 4], Basis(Vector3.RIGHT, -0.5))
		for leg_z: float in [-0.2, 0.2]:
			for leg_x: float in [-0.08, 0.08]:
				sculpt.box(Vector3(leg_x, lift - 0.26, leg_z), Vector3(0.06, 0.28, 0.07), coat.darkened(0.12), Basis(Vector3.RIGHT, 0.3 * signf(leg_z)))
	sculpt.frame = Transform3D.IDENTITY
	return sculpt.mesh()

## Diamond kite and its string, flown from the origin; the kite sits at `aloft`.
static func kite_mesh(aloft: Vector3) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var string := aloft.length()
	sculpt.box(aloft * 0.5, Vector3(0.025, 0.025, string), CREAM.darkened(0.25), Basis.looking_at(aloft.normalized()))
	var corners: Array[Vector3] = [aloft + Vector3(0, 0.75, 0), aloft + Vector3(0.52, 0.12, 0), aloft + Vector3(0, -0.7, 0), aloft + Vector3(-0.52, 0.12, 0)]
	var middle := aloft + Vector3(0, 0.12, 0)
	var paints: Array[Color] = [RED, YELLOW, BLUE, GREEN]
	for index in range(4):
		sculpt.sheet(middle, corners[index], corners[(index + 1) % 4], paints[index])
	for bow in range(4):
		var hang := corners[2] + Vector3(0.14 * sin(float(bow) * 1.9), -0.34 * float(bow + 1), 0)
		sculpt.sheet(hang + Vector3(-0.16, 0.07, 0), hang + Vector3(0.16, -0.07, 0), hang + Vector3(-0.16, -0.07, 0), paints[bow])
		sculpt.sheet(hang + Vector3(0.16, 0.07, 0), hang + Vector3(-0.16, -0.07, 0), hang + Vector3(0.16, -0.07, 0), paints[bow])
	return sculpt.mesh()

## Paper pinwheel a metre across, spinning around local Z.
static func pinwheel_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for blade in range(4):
		var turn := Basis(Vector3.BACK, TAU * float(blade) / 4.0)
		sculpt.sheet(Vector3.ZERO, turn * Vector3(0.5, 0.0, 0.02), turn * Vector3(0.28, 0.28, 0.07), PRIMARY[blade])
		sculpt.sheet(Vector3.ZERO, turn * Vector3(0.28, 0.28, 0.07), turn * Vector3(0.0, 0.22, 0.02), PRIMARY[blade].lightened(0.35))
	sculpt.tube(Vector3(0, 0, 0.05), 0.06, 0.06, 0.06, YELLOW, 8, Basis(Vector3.RIGHT, PI * 0.5))
	return sculpt.mesh()

## Swinging pendulum hanging from the origin.
static func pendulum_mesh(length: float) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.box(Vector3(0, -length * 0.5, 0), Vector3(0.05, length, 0.03), BRASS.darkened(0.2))
	sculpt.tube(Vector3(0, -length, 0), 0.2, 0.2, 0.06, BRASS, 12, facing)
	sculpt.tube(Vector3(0, -length, 0.034), 0.11, 0.11, 0.01, BRASS.lightened(0.25), 10, facing)
	return sculpt.mesh()

## Clock hand pointing up from the origin, on a +Z face.
static func hand_mesh(length: float, width: float, paint: Color) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, length * 0.42, 0), Vector3(width, length * 1.08, 0.03), paint)
	sculpt.tri(Vector3(-width, length * 0.94, 0.015), Vector3(0, length * 1.12, 0.015), Vector3(width, length * 0.94, 0.015), paint)
	return sculpt.mesh()

## Flat jigsaw piece lying on the ground, with knobs toward +X and +Z.
static func jigsaw(sculpt: Kit.Sculpt, at: Vector3, size: float, paint: Color, yaw := 0.0) -> void:
	var turn := Basis(Vector3.UP, yaw)
	sculpt.box(at, Vector3(size, 0.03, size), paint, turn)
	sculpt.tube(at + turn * Vector3(size * 0.5 + size * 0.1, 0, 0), size * 0.17, size * 0.17, 0.03, paint, 10)
	sculpt.tube(at + turn * Vector3(0, 0, size * 0.5 + size * 0.1), size * 0.17, size * 0.17, 0.03, paint, 10)
	sculpt.tube(at + turn * Vector3(-size * 0.36, 0.004, 0), size * 0.15, size * 0.15, 0.03, paint.darkened(0.22), 10)
	sculpt.tube(at + turn * Vector3(0, 0.004, -size * 0.36), size * 0.15, size * 0.15, 0.03, paint.darkened(0.22), 10)

## Post with a painted block board; returns the label.
static func signpost(world: Node3D, shapes: Blocks, at: Vector3, text: String, width: float, paint: Color) -> Label3D:
	crayon(shapes, at, 2.0, paint)
	shapes.box.add(at + Vector3(0, 1.5, 0.16), Vector3(width, 0.5, 0.12), Basis.IDENTITY, paint.darkened(0.42))
	shapes.kit.detail.box(at + Vector3(0, 1.76, 0.16), Vector3(width + 0.08, 0.05, 0.16), CREAM)
	shapes.kit.detail.box(at + Vector3(0, 1.24, 0.16), Vector3(width + 0.08, 0.05, 0.16), CREAM)
	return world._local_label(text, at + Vector3(0, 1.5, 0.3), 24, CREAM)

## Big toy chest with its lid thrown open and toys peeking out; `at` is the front middle of its foot.
static func toy_chest(shapes: Blocks, at: Vector3, width: float) -> void:
	const DEPTH := 1.7
	const HEIGHT := 1.35
	var kit := shapes.kit
	var center := at + Vector3(0, 0, -DEPTH * 0.5)
	shapes.box.add(center + Vector3(0, HEIGHT * 0.5, 0), Vector3(width, HEIGHT, DEPTH), Basis.IDENTITY, Color("#c88c58"))
	shapes.box.add(center + Vector3(0, 0.09, 0), Vector3(width + 0.12, 0.18, DEPTH + 0.12), Basis.IDENTITY, DARK_WOOD)
	var tilt := Basis(Vector3.RIGHT, -1.05)
	var hinge := center + Vector3(0, HEIGHT, -DEPTH * 0.5)
	shapes.box.add(hinge + tilt * Vector3(0, 0.14, DEPTH * 0.5), Vector3(width + 0.1, 0.28, DEPTH + 0.1), tilt, Color("#b97a4a"))
	for strap in range(3):
		var x := (float(strap) - 1.0) * width * 0.36
		kit.detail.box(center + Vector3(x, HEIGHT * 0.5, DEPTH * 0.5 + 0.012), Vector3(0.16, HEIGHT, 0.03), INK.lightened(0.12))
		kit.detail.box(hinge + tilt * Vector3(x, 0.29, DEPTH * 0.5), Vector3(0.16, 0.03, DEPTH + 0.1), INK.lightened(0.12), tilt)
		for rivet: float in [0.2, HEIGHT - 0.2]:
			kit.detail.box(center + Vector3(x, rivet, DEPTH * 0.5 + 0.03), Vector3(0.06, 0.06, 0.03), BRASS)
	kit.detail.box(center + Vector3(0, HEIGHT - 0.24, DEPTH * 0.5 + 0.035), Vector3(0.34, 0.4, 0.05), BRASS)
	kit.detail.box(center + Vector3(0, HEIGHT - 0.3, DEPTH * 0.5 + 0.065), Vector3(0.08, 0.14, 0.02), INK)
	# The toys that will not fit: a bear, a rocket, a ball and a few blocks.
	var top := center + Vector3(0, HEIGHT, 0)
	var bear := top + Vector3(-width * 0.26, 0.26, 0.1)
	var fur := Color("#b98558")
	shapes.ball.add(bear, Vector3.ONE * 0.86, Basis.IDENTITY, fur)
	shapes.ball.add(bear + Vector3(0, -0.08, 0.36), Vector3(0.4, 0.32, 0.3), Basis.IDENTITY, CREAM.darkened(0.06))
	for side: float in [-1.0, 1.0]:
		shapes.ball.add(bear + Vector3(side * 0.33, 0.34, 0), Vector3.ONE * 0.32, Basis.IDENTITY, fur.darkened(0.12))
		kit.detail.box(bear + Vector3(side * 0.16, 0.1, 0.4), Vector3(0.07, 0.08, 0.04), INK)
	kit.detail.box(bear + Vector3(0, -0.04, 0.51), Vector3(0.1, 0.07, 0.04), INK)
	var rocket := top + Vector3(width * 0.2, 0.3, -0.2)
	var lean := Basis(Vector3.BACK, -0.3)
	shapes.column.add(rocket + lean * Vector3(0, 0.3, 0), Vector3(0.44, 1.1, 0.44), lean, CREAM)
	shapes.cone.add(rocket + lean * Vector3(0, 1.12, 0), Vector3(0.46, 0.56, 0.46), lean, RED)
	shapes.column.add(rocket + lean * Vector3(0, 0.5, 0), Vector3(0.46, 0.14, 0.46), lean, BLUE)
	shapes.ball.add(top + Vector3(width * 0.02, 0.16, 0.42), Vector3.ONE * 0.6, Basis.IDENTITY, YELLOW)
	shapes.box.add(top + Vector3(width * 0.38, 0.14, 0.34), Vector3.ONE * 0.44, Basis(Vector3.UP, 0.5), GREEN)

## Tin robot waiting for repair, facing +Z. Returns where the key in its chest turns.
static func tin_robot(shapes: Blocks, at: Vector3) -> Vector3:
	var kit := shapes.kit
	var tin := Color("#7fa9b8")
	for side: float in [-1.0, 1.0]:
		shapes.box.add(at + Vector3(side * 0.24, 0.3, 0), Vector3(0.3, 0.6, 0.36), Basis.IDENTITY, tin.darkened(0.2))
		shapes.box.add(at + Vector3(side * 0.24, 0.07, 0.06), Vector3(0.36, 0.14, 0.5), Basis.IDENTITY, RED)
	shapes.box.add(at + Vector3(0, 1.05, 0), Vector3(0.96, 0.9, 0.6), Basis.IDENTITY, tin)
	shapes.box.add(at + Vector3(0, 1.82, 0), Vector3(0.62, 0.5, 0.5), Basis.IDENTITY, tin.lightened(0.14))
	shapes.column.add(at + Vector3(0, 1.54, 0), Vector3(0.26, 0.1, 0.26), Basis.IDENTITY, INK)
	shapes.box.add(at + Vector3(-0.6, 1.02, 0.02), Vector3(0.2, 0.74, 0.24), Basis(Vector3.BACK, -0.12), tin.darkened(0.12))
	kit.detail.tube(at + Vector3(0, 2.2, 0), 0.025, 0.025, 0.28, INK, 6)
	shapes.ball.add(at + Vector3(0, 2.38, 0), Vector3.ONE * 0.14, Basis.IDENTITY, RED)
	for side: float in [-1.0, 1.0]:
		kit.glow.box(at + Vector3(side * 0.15, 1.88, 0.256), Vector3(0.14, 0.14, 0.02), WINDOW)
		kit.detail.box(at + Vector3(side * 0.34, 1.82, 0), Vector3(0.08, 0.2, 0.2), RED)
	kit.detail.box(at + Vector3(0, 1.7, 0.256), Vector3(0.3, 0.05, 0.02), INK)
	kit.detail.box(at + Vector3(-0.14, 1.12, 0.306), Vector3(0.44, 0.5, 0.02), CREAM)
	kit.glow.box(at + Vector3(-0.24, 1.22, 0.32), Vector3(0.14, 0.14, 0.02), WINDOW)
	for dial in range(3):
		kit.detail.box(at + Vector3(-0.3 + 0.14 * float(dial), 0.98, 0.32), Vector3(0.08, 0.08, 0.02), PRIMARY[dial])
	# One arm is off on the bench; a socket shows where it goes.
	kit.detail.tube(at + Vector3(0.49, 1.3, 0), 0.1, 0.1, 0.04, INK, 8, Basis(Vector3.BACK, PI * 0.5))
	return at + Vector3(0.26, 1.1, 0.3)
