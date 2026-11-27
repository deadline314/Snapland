extends RefCounted
## Props of the mirror circus. Builders are static and draw into a sculpt (merged
## painted trim), the scenery kit (textured batches) or a Canvas (striped cloth),
## so a prop never costs a node of its own.

const Kit := preload("res://game/world/scenery_kit.gd")
const RED := Color("#c9483d")
const CREAM := Color("#f4e6c6")
const GOLD := Color("#e9b85c")
const TEAL := Color("#2f8a8c")
const PLUM := Color("#6d3f72")
const NIGHT := Color("#2f2c4d")
const ROSE := Color("#e88aa0")
const SKY := Color("#8fc8d8")
const WOOD := Color("#6a4a34")
const PALE_WOOD := Color("#d8b888")
const IRON := Color("#3a3f4c")
const ROPE := Color("#cdb98c")
const PARTY: Array[Color] = [RED, GOLD, TEAL, ROSE, CREAM, PLUM]

## Striped cloth for the whole district, merged into one mesh (see circus_canvas.gdshader).
class Canvas:
	var _tool := SurfaceTool.new()

	func _init() -> void:
		_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Cloth between a pinned edge and a hem with the same number of points.
	## `stripe` is the stripe width in metres; `scallops` cuts the hem per stripe.
	func strip(pinned: PackedVector3Array, hem: PackedVector3Array, dye: Color, stripe := 0.8, scallops := 0.0, billow := 0.0) -> void:
		var colour := dye.srgb_to_linear()
		var along := 0.0
		for index in range(pinned.size() - 1):
			var span := maxf(pinned[index].distance_to(pinned[index + 1]), hem[index].distance_to(hem[index + 1]))
			var next := along + span / stripe
			# A cone roof pins every point at its tip, so take the direction from the hem.
			var normal := (hem[index + 1] - hem[index]).cross(hem[index] - pinned[index]).normalized()
			var corners := [[pinned[index], along, 0.0], [pinned[index + 1], next, 0.0], [hem[index + 1], next, 1.0], [pinned[index], along, 0.0], [hem[index + 1], next, 1.0], [hem[index], along, 1.0]]
			for corner: Array in corners:
				_tool.set_color(colour)
				_tool.set_normal(normal)
				_tool.set_uv(Vector2(corner[1], corner[2]))
				_tool.set_uv2(Vector2(scallops, billow))
				_tool.add_vertex(corner[0])
			along = next

	func mesh() -> ArrayMesh:
		return _tool.commit()

## Mirror glass for the whole district, merged into one mesh (see circus_mirror.gdshader).
class Glass:
	var count := 0
	var _tool := SurfaceTool.new()

	func _init() -> void:
		_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	func pane(frame: Transform3D, outline: PackedVector2Array, size: Vector2, bend: Color) -> void:
		count += 1
		for index in range(outline.size()):
			for point: Vector2 in [Vector2(0, size.y * 0.5), outline[index], outline[(index + 1) % outline.size()]]:
				_tool.set_color(bend)
				_tool.set_normal(frame.basis.z)
				_tool.set_uv(Vector2(point.x / size.x + 0.5, point.y / size.y))
				_tool.add_vertex(frame * Vector3(point.x, point.y, 0.0))

	func mesh() -> ArrayMesh:
		return _tool.commit()

## Points of a circle or arc in the ground plane; angles run from +X toward -Z.
static func arc(center: Vector3, radius: float, from: float, to: float, steps: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in range(steps + 1):
		var angle := lerpf(from, to, float(index) / float(steps))
		points.append(center + Vector3(cos(angle) * radius, 0, -sin(angle) * radius))
	return points

static func lifted(points: PackedVector3Array, height: float) -> PackedVector3Array:
	var raised := PackedVector3Array()
	for point in points:
		raised.append(point + Vector3(0, height, 0))
	return raised

## A rope or wire between two points.
static func line(sculpt: Kit.Sculpt, from: Vector3, to: Vector3, tint := ROPE, thickness := 0.035) -> void:
	var span := to - from
	if span.length() < 0.01: return
	var up := Vector3.RIGHT if absf(span.normalized().y) > 0.98 else Vector3.UP
	sculpt.box((from + to) * 0.5, Vector3(thickness, thickness, span.length()), tint, Basis.looking_at(span.normalized(), up))

## Points of a line that sags in the middle, ends included.
static func sagging(from: Vector3, to: Vector3, sag: float, steps: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in range(steps + 1):
		var along := float(index) / float(steps)
		points.append(from.lerp(to, along) - Vector3(0, sag * 4.0 * along * (1.0 - along), 0))
	return points

## Banded pole with a plinth and a gilt ball; returns the top of the ball.
static func pole(sculpt: Kit.Sculpt, ground: Vector3, height: float, radius := 0.12, bands: Array[Color] = [RED, CREAM]) -> Vector3:
	sculpt.box(ground + Vector3(0, 0.13, 0), Vector3(radius * 4.4, 0.26, radius * 4.4), NIGHT)
	sculpt.tube(ground + Vector3(0, 0.3, 0), radius * 1.7, radius * 1.4, 0.1, GOLD, 8)
	var count := maxi(2, roundi(height / 0.9))
	var band := (height - 0.35) / float(count)
	for index in range(count):
		sculpt.tube(ground + Vector3(0, 0.35 + band * (float(index) + 0.5), 0), radius, radius * 0.96, band, bands[index % bands.size()], 8)
	sculpt.tube(ground + Vector3(0, height + 0.04, 0), radius * 1.5, radius * 1.5, 0.08, GOLD, 8)
	sculpt.tube(ground + Vector3(0, height + 0.2, 0), radius * 1.3, radius * 0.5, 0.26, GOLD, 8)
	return ground + Vector3(0, height + 0.33, 0)

## Outline of a mirror standing on its bottom edge, counter-clockwise.
static func mirror_outline(shape: String, size: Vector2) -> PackedVector2Array:
	var half := size.x * 0.5
	var points := PackedVector2Array()
	match shape:
		"oval":
			for index in range(18):
				var angle := TAU * float(index) / 18.0
				points.append(Vector2(cos(angle) * half, size.y * 0.5 + sin(angle) * size.y * 0.5))
		"gem":
			var cut := minf(half, size.y * 0.5) * 0.55
			points = PackedVector2Array([Vector2(half - cut, 0), Vector2(half, cut), Vector2(half, size.y - cut), Vector2(half - cut, size.y), Vector2(-half + cut, size.y), Vector2(-half, size.y - cut), Vector2(-half, cut), Vector2(-half + cut, 0)])
		_:
			# An arch: straight sides under a round head.
			points.append(Vector2(half, 0))
			for index in range(11):
				var angle := PI * float(index) / 10.0
				points.append(Vector2(cos(angle) * half, size.y - half + sin(angle) * half))
			points.append(Vector2(-half, 0))
	return points

## Gilded mirror facing local +Z with its bottom edge at the frame origin.
## `bend` reshapes the reflection (see circus_mirror.gdshader). Without `glass` the
## pane is only painted, for mirrors too small to show anyone.
static func mirror(sculpt: Kit.Sculpt, glass: Glass, frame: Transform3D, shape: String, size: Vector2, bend: Color, backing := PLUM) -> void:
	var outline := mirror_outline(shape, size)
	sculpt.frame = frame
	if glass != null:
		glass.pane(frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.03)), outline, size, bend)
	else:
		for index in range(outline.size()):
			var to := outline[(index + 1) % outline.size()]
			sculpt.tri(Vector3(0, size.y * 0.5, 0.03), Vector3(to.x, to.y, 0.03), Vector3(outline[index].x, outline[index].y, 0.03), Color("#b9dfe8") if index % 2 == 0 else Color("#c9e9ee"))
		sculpt.box(Vector3(-size.x * 0.14, size.y * 0.55, 0.035), Vector3(0.07, size.y * 0.6, 0.01), Color("#eefafa"), Basis(Vector3.BACK, -0.25))
	var middle := Vector3(0, size.y * 0.5, -0.04)
	for index in range(outline.size()):
		var from := outline[index]
		var to := outline[(index + 1) % outline.size()]
		var grown_from := Vector3(from.x, from.y, 0) + (Vector3(from.x, from.y, 0) - middle) * 0.12
		var grown_to := Vector3(to.x, to.y, 0) + (Vector3(to.x, to.y, 0) - middle) * 0.12
		sculpt.tri(middle, Vector3(grown_to.x, grown_to.y, -0.04), Vector3(grown_from.x, grown_from.y, -0.04), backing)
		sculpt.tri(middle - Vector3(0, 0, 0.05), Vector3(grown_from.x, grown_from.y, -0.09), Vector3(grown_to.x, grown_to.y, -0.09), backing.darkened(0.25))
		var edge := to - from
		sculpt.box(Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, 0.02), Vector3(edge.length() + 0.07, 0.1, 0.12), GOLD if index % 2 == 0 else GOLD.darkened(0.12), Basis(Vector3.BACK, edge.angle()))
	# A crest with a star on top and a pair of scrolls at the foot.
	sculpt.box(Vector3(0, size.y + 0.13, 0.02), Vector3(0.34, 0.2, 0.1), GOLD)
	sculpt.box(Vector3(0, size.y + 0.3, 0.02), Vector3(0.17, 0.17, 0.1), CREAM, Basis(Vector3.BACK, PI * 0.25))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * (size.x * 0.5 + 0.02), 0.1, 0.02), Vector3(0.2, 0.2, 0.14), GOLD.darkened(0.1), Basis(Vector3.BACK, PI * 0.25))
	sculpt.frame = Transform3D.IDENTITY

## Feet and a back prop for a mirror that stands free on the floor.
static func mirror_stand(sculpt: Kit.Sculpt, frame: Transform3D, width: float, lift: float) -> void:
	sculpt.frame = frame
	sculpt.box(Vector3(0, 0.07, 0), Vector3(width + 0.5, 0.14, 0.62), NIGHT)
	sculpt.box(Vector3(0, 0.17, 0), Vector3(width + 0.3, 0.06, 0.46), GOLD.darkened(0.15))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * (width * 0.5 + 0.02), lift * 0.5 + 0.1, -0.02), Vector3(0.12, lift + 0.1, 0.12), GOLD.darkened(0.2))
		sculpt.tube(Vector3(side * (width * 0.5 + 0.02), lift + 0.22, -0.02), 0.1, 0.03, 0.16, GOLD, 6)
	sculpt.frame = Transform3D.IDENTITY

## Round striped tent with a scalloped valance and an open door flap facing +Z.
## Returns the tip of the roof.
static func tent(canvas: Canvas, sculpt: Kit.Sculpt, ground: Vector3, radius: float, wall: float, peak: float, dye: Color) -> Vector3:
	const SIDES := 16
	var foot := arc(ground, radius, 0.0, TAU, SIDES)
	var eave := lifted(foot, wall)
	var tip := PackedVector3Array()
	var brim := arc(ground + Vector3(0, wall - 0.05, 0), radius + 0.22, 0.0, TAU, SIDES)
	for index in range(SIDES + 1):
		tip.append(ground + Vector3(0, peak, 0))
	var stripe := TAU * radius / float(SIDES)
	canvas.strip(eave, foot, dye, stripe)
	canvas.strip(tip, brim, dye, stripe)
	canvas.strip(brim, lifted(brim, -0.42), dye, stripe, 1.0, 0.02)
	# The doorway: a dark opening with the flaps tied back.
	sculpt.frame = Transform3D(Basis.IDENTITY, ground)
	sculpt.quad(Vector3(-0.5, 0, radius * 0.985), Vector3(-0.5, wall * 0.82, radius * 0.985), Vector3(0.5, wall * 0.82, radius * 0.985), Vector3(0.5, 0, radius * 0.985), Color("#2a2233"))
	for side: float in [-1.0, 1.0]:
		sculpt.sheet(Vector3(side * 0.5, wall * 0.82, radius), Vector3(side * 0.5, 0, radius + 0.02), Vector3(side * 0.95, 0, radius + 0.06), CREAM.darkened(0.08))
		sculpt.box(Vector3(side * 0.7, wall * 0.36, radius + 0.04), Vector3(0.12, 0.07, 0.07), GOLD)
	sculpt.tube(Vector3(0, peak + 0.3, 0), 0.04, 0.03, 0.6, WOOD, 6)
	sculpt.tube(Vector3(0, peak + 0.66, 0), 0.09, 0.03, 0.14, GOLD, 6)
	sculpt.frame = Transform3D.IDENTITY
	return ground + Vector3(0, peak + 0.6, 0)

## Circus wagon facing local +Z (its long painted side). `variation` picks the trim.
static func wagon(world: Node3D, kit: Kit, at: Vector3, yaw: float, body: Color, variation: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	var trim: Color = [GOLD, CREAM, GOLD][variation % 3]
	kit.surface(world._coastal_surface(3, 1.5, body.lightened(0.35))).add(frame * Vector3(0, 1.42, 0), Vector3(3.3, 1.5, 1.7), frame.basis)
	kit.surface(world._coastal_surface(1, 1.6, Color("#b99a78"))).add(frame * Vector3(0, 0.6, 0), Vector3(3.5, 0.16, 1.8), frame.basis)
	var sculpt := kit.detail
	sculpt.frame = frame
	# Barrel roof with a clerestory and a painted fascia.
	sculpt.tube(Vector3(0, 2.2, 0), 0.98, 0.98, 3.6, body.darkened(0.2), 12, Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(0.42, 1.0, 1.0)))
	sculpt.box(Vector3(0, 2.66, 0), Vector3(2.2, 0.16, 0.6), CREAM)
	sculpt.box(Vector3(0, 2.76, 0), Vector3(2.4, 0.06, 0.8), body.darkened(0.3))
	sculpt.box(Vector3(0, 2.2, 0.87), Vector3(3.5, 0.14, 0.06), trim)
	sculpt.box(Vector3(0, 0.7, 0.87), Vector3(3.4, 0.1, 0.06), trim)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 1.63, 1.42, 0.86), Vector3(0.12, 1.5, 0.08), trim)
		# Spoked wheels, the rear pair larger.
		for axle: float in [-1.0, 1.0]:
			var radius := 0.5 if axle > 0.0 else 0.4
			var hub := Vector3(axle * 1.15, radius, side * 0.98)
			var upright := Basis(Vector3.RIGHT, PI * 0.5)
			sculpt.tube(hub, radius, radius, 0.1, RED.darkened(0.1), 12, upright)
			sculpt.tube(hub + Vector3(0, 0, side * 0.03), radius * 0.8, radius * 0.8, 0.1, body.darkened(0.45), 12, upright)
			sculpt.tube(hub + Vector3(0, 0, side * 0.06), radius * 0.24, radius * 0.24, 0.1, GOLD, 8, upright)
			for spoke in range(4):
				sculpt.box(hub + Vector3(0, 0, side * 0.05), Vector3(radius * 1.7, 0.06, 0.05), GOLD.darkened(0.1), Basis(Vector3.BACK, PI * 0.25 * float(spoke)))
	# Painted panel, shuttered window and a door with steps on the long side.
	sculpt.box(Vector3(-0.75, 1.5, 0.87), Vector3(1.2, 0.9, 0.05), CREAM)
	sculpt.box(Vector3(-0.75, 1.5, 0.9), Vector3(0.9, 0.62, 0.04), [SKY, ROSE, TEAL][variation % 3])
	sculpt.box(Vector3(-0.75, 1.5, 0.93), Vector3(0.3, 0.3, 0.03), GOLD, Basis(Vector3.BACK, PI * 0.25))
	sculpt.box(Vector3(0.85, 1.36, 0.87), Vector3(0.7, 1.3, 0.05), body.darkened(0.25))
	sculpt.box(Vector3(0.85, 1.7, 0.9), Vector3(0.4, 0.36, 0.04), Color("#f6dc9a"))
	sculpt.box(Vector3(1.08, 1.3, 0.91), Vector3(0.06, 0.06, 0.06), GOLD)
	for step in range(2):
		sculpt.box(Vector3(0.85, 0.5 - 0.26 * float(step), 1.08 + 0.26 * float(step)), Vector3(0.76, 0.07, 0.26), PALE_WOOD)
	sculpt.box(Vector3(-1.95, 0.62, 0), Vector3(0.6, 0.07, 0.1), WOOD)
	kit.glow.frame = frame
	kit.glow.box(Vector3(1.4, 2.0, 0.95), Vector3(0.14, 0.2, 0.12), Kit.WARM_GLOW)
	kit.glow.frame = Transform3D.IDENTITY
	sculpt.frame = Transform3D.IDENTITY

## Ticket booth facing local +Z: a striped kiosk with a counter window and an awning.
static func ticket_booth(world: Node3D, kit: Kit, canvas: Canvas, at: Vector3) -> void:
	kit.surface(world._coastal_surface(3, 1.3, Color("#f6d4cf"))).add(at + Vector3(0, 0.55, 0), Vector3(1.9, 1.1, 1.5))
	kit.surface(world._coastal_surface(1, 1.2, Color("#e2c9a4"))).add(at + Vector3(0, 1.14, 0.12), Vector3(2.1, 0.09, 1.8))
	kit.surface(world._coastal_surface(3, 1.3, Color("#f6d4cf"))).add(at + Vector3(0, 1.95, -0.55), Vector3(1.9, 1.55, 0.4))
	var sculpt := kit.detail
	sculpt.frame = Transform3D(Basis.IDENTITY, at)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.9, 1.9, 0.68), Vector3(0.12, 1.5, 0.12), GOLD)
		sculpt.box(Vector3(side * 0.9, 1.9, -0.05), Vector3(0.1, 1.5, 1.3), PLUM)
	sculpt.box(Vector3(0, 1.75, -0.33), Vector3(1.5, 1.0, 0.05), Color("#2a2233"))
	sculpt.box(Vector3(0, 1.3, 0.72), Vector3(1.7, 0.12, 0.06), GOLD)
	sculpt.box(Vector3(0.5, 1.27, 0.5), Vector3(0.3, 0.14, 0.22), TEAL)
	sculpt.tube(Vector3(-0.5, 1.3, 0.5), 0.1, 0.07, 0.16, GOLD, 8)
	sculpt.box(Vector3(0, 3.42, 0.2), Vector3(1.8, 0.5, 0.1), NIGHT)
	for edge: float in [-1.0, 1.0]:
		sculpt.box(Vector3(0, 3.42 + edge * 0.27, 0.2), Vector3(1.9, 0.06, 0.14), GOLD)
	sculpt.tube(Vector3(0, 3.86, 0.2), 0.16, 0.02, 0.3, GOLD, 4)
	sculpt.frame = Transform3D.IDENTITY
	var ridge := PackedVector3Array([at + Vector3(-1.2, 3.1, -0.75), at + Vector3(1.2, 3.1, -0.75)])
	var eave := PackedVector3Array([at + Vector3(-1.3, 2.68, 1.15), at + Vector3(1.3, 2.68, 1.15)])
	canvas.strip(ridge, eave, RED, 0.4)
	canvas.strip(eave, lifted(eave, -0.36), RED, 0.4, 1.0, 0.015)
	world._local_label("售票亭", at + Vector3(0, 3.42, 0.28), 24)

## Tiered seating facing local +Z; the lowest tread is in front.
static func bleachers(world: Node3D, kit: Kit, at: Vector3, width: float, tiers: int) -> void:
	var sculpt := kit.detail
	var tread := kit.surface(world._coastal_surface(1, 1.5, Color("#fff0d2")))
	var riser := kit.surface(world._coastal_surface(3, 1.2, Color("#f2c8c0")))
	sculpt.frame = Transform3D(Basis.IDENTITY, at)
	for tier in range(tiers):
		var top := 0.45 + 0.4 * float(tier)
		var z := -0.9 * float(tier)
		tread.add(at + Vector3(0, top - 0.04, z), Vector3(width, 0.08, 0.9))
		riser.add(at + Vector3(0, top * 0.5 - 0.04, z + 0.43), Vector3(width, top - 0.08, 0.06))
		for seat in range(int(width / 0.55)):
			if (seat + tier) % 2 == 0:
				sculpt.box(Vector3(-width * 0.5 + 0.3 + 0.55 * float(seat), top + 0.03, z - 0.05), Vector3(0.42, 0.06, 0.5), [RED, TEAL, GOLD][((seat >> 1) + tier) % 3])
	var back := -0.9 * float(tiers) + 0.42
	var height := 0.45 + 0.4 * float(tiers - 1)
	for side: float in [-1.0, 1.0]:
		riser.add(at + Vector3(side * (width * 0.5 + 0.03), height * 0.5, (back + 0.45) * 0.5), Vector3(0.06, height, 0.45 - back))
		for post in range(tiers + 1):
			var z := 0.42 - 0.9 * float(post)
			var foot := 0.45 + 0.4 * float(mini(post, tiers - 1))
			sculpt.box(Vector3(side * (width * 0.5 + 0.03), foot + 0.45, z), Vector3(0.07, 0.9, 0.07), GOLD.darkened(0.15))
			if post < tiers:
				line(sculpt, Vector3(side * (width * 0.5 + 0.03), foot + 0.88, z), Vector3(side * (width * 0.5 + 0.03), 0.45 + 0.4 * float(mini(post + 1, tiers - 1)) + 0.88, z - 0.9), GOLD, 0.05)
	sculpt.box(Vector3(0, height + 0.88, back), Vector3(width + 0.12, 0.06, 0.06), GOLD)
	sculpt.box(Vector3(0, height + 0.5, back), Vector3(width + 0.12, 0.05, 0.05), GOLD.darkened(0.15))
	sculpt.frame = Transform3D.IDENTITY

## Bench of the front stalls, facing local -Z so the camera sees its painted back.
static func bench(world: Node3D, kit: Kit, at: Vector3, width: float, seat: float) -> void:
	kit.surface(world._coastal_surface(1, 1.3, Color("#e2c9a4"))).add(at + Vector3(0, seat - 0.04, -0.05), Vector3(width, 0.08, 0.56))
	kit.surface(world._coastal_surface(3, 1.1, Color("#f0c4bc"))).add(at + Vector3(0, seat + 0.24, 0.27), Vector3(width, 0.52, 0.08))
	var sculpt := kit.detail
	sculpt.frame = Transform3D(Basis.IDENTITY, at)
	sculpt.box(Vector3(0, seat + 0.53, 0.27), Vector3(width + 0.08, 0.07, 0.12), GOLD)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * (width * 0.5 - 0.06), seat * 0.5, 0), Vector3(0.1, seat, 0.6), NIGHT)
		sculpt.box(Vector3(side * (width * 0.5 - 0.06), seat + 0.2, 0.27), Vector3(0.12, 0.74, 0.12), PLUM)
		sculpt.tube(Vector3(side * (width * 0.5 - 0.06), seat + 0.63, 0.27), 0.08, 0.02, 0.12, GOLD, 6)
	for plate in range(3):
		sculpt.box(Vector3(-0.66 + 0.66 * float(plate), seat + 0.26, 0.32), Vector3(0.16, 0.16, 0.02), CREAM, Basis(Vector3.BACK, PI * 0.25))
	sculpt.frame = Transform3D.IDENTITY

## Human-cannonball cannon; the barrel points along local +X and up.
static func cannon(sculpt: Kit.Sculpt, at: Vector3, yaw: float) -> void:
	sculpt.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	var tilt := Basis(Vector3.BACK, -PI * 0.5 + 0.6)
	sculpt.box(Vector3(-0.1, 0.42, 0), Vector3(1.5, 0.2, 0.7), WOOD)
	sculpt.box(Vector3(-0.75, 0.2, 0), Vector3(0.5, 0.14, 0.4), WOOD.darkened(0.15), Basis(Vector3.BACK, 0.5))
	for side: float in [-1.0, 1.0]:
		var hub := Vector3(0.1, 0.55, side * 0.5)
		var upright := Basis(Vector3.RIGHT, PI * 0.5)
		sculpt.tube(hub, 0.55, 0.55, 0.1, GOLD.darkened(0.1), 12, upright)
		sculpt.tube(hub + Vector3(0, 0, side * 0.03), 0.44, 0.44, 0.1, RED, 12, upright)
		sculpt.tube(hub + Vector3(0, 0, side * 0.06), 0.14, 0.14, 0.1, GOLD, 8, upright)
		for spoke in range(4):
			sculpt.box(hub + Vector3(0, 0, side * 0.05), Vector3(0.9, 0.06, 0.05), GOLD, Basis(Vector3.BACK, PI * 0.25 * float(spoke)))
	var mouth := tilt * Vector3(0, 1.0, 0)
	var breech := Vector3(0.0, 0.95, 0)
	sculpt.tube(breech + mouth * 0.2, 0.36, 0.3, 1.9, TEAL, 10, tilt)
	sculpt.tube(breech - mouth * 0.82, 0.4, 0.22, 0.26, TEAL.darkened(0.2), 10, tilt)
	for ring: float in [-0.5, 0.35, 1.1]:
		sculpt.tube(breech + mouth * ring, 0.38, 0.37, 0.12, GOLD, 10, tilt)
	sculpt.tube(breech + mouth * 1.16, 0.26, 0.26, 0.04, Color("#1f1c2b"), 10, tilt)
	for star in range(3):
		sculpt.box(breech + mouth * (-0.15 + 0.38 * float(star)) + Vector3(0, 0, 0.35), Vector3(0.16, 0.16, 0.03), CREAM, tilt * Basis(Vector3.BACK, PI * 0.25))
	sculpt.frame = Transform3D.IDENTITY

## Steam calliope on a painted cart, keyboard toward local +Z.
static func calliope(world: Node3D, kit: Kit, at: Vector3, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	kit.surface(world._coastal_surface(3, 1.3, Color("#cfe6e4"))).add(frame * Vector3(0, 0.95, 0), Vector3(2.6, 0.9, 1.2), frame.basis)
	var sculpt := kit.detail
	sculpt.frame = frame
	sculpt.box(Vector3(0, 0.46, 0), Vector3(2.8, 0.1, 1.3), GOLD)
	sculpt.box(Vector3(0, 1.43, 0), Vector3(2.8, 0.08, 1.3), GOLD)
	for side: float in [-1.0, 1.0]:
		var hub := Vector3(side * 0.85, 0.4, 0.68)
		var upright := Basis(Vector3.RIGHT, PI * 0.5)
		sculpt.tube(hub, 0.4, 0.4, 0.1, RED, 12, upright)
		sculpt.tube(hub + Vector3(0, 0, 0.04), 0.3, 0.3, 0.1, CREAM, 12, upright)
		sculpt.tube(hub + Vector3(0, 0, 0.07), 0.1, 0.1, 0.1, GOLD, 8, upright)
		sculpt.box(Vector3(side * 1.32, 0.95, 0.56), Vector3(0.1, 0.9, 0.1), GOLD)
	sculpt.box(Vector3(0, 1.0, 0.62), Vector3(1.6, 0.5, 0.05), PLUM)
	sculpt.box(Vector3(0, 1.0, 0.65), Vector3(0.36, 0.36, 0.03), GOLD, Basis(Vector3.BACK, PI * 0.25))
	sculpt.box(Vector3(0, 1.5, 0.5), Vector3(1.5, 0.06, 0.3), CREAM)
	for key in range(7):
		sculpt.box(Vector3(-0.6 + 0.2 * float(key), 1.54, 0.42), Vector3(0.08, 0.04, 0.14), NIGHT)
	# Brass whistles, tallest in the middle.
	for pipe in range(11):
		var across := float(pipe - 5) / 5.0
		var length := 1.5 - 0.8 * across * across + 0.12 * float(pipe % 2)
		sculpt.tube(Vector3(across * 1.1, 1.47 + length * 0.5, -0.15), 0.075, 0.075, length, GOLD if pipe % 2 == 0 else GOLD.lightened(0.2), 6)
		sculpt.tube(Vector3(across * 1.1, 1.47 + length, -0.15), 0.1, 0.085, 0.08, RED, 6)
	sculpt.frame = Transform3D.IDENTITY

## Costume trunk with its lid thrown back and something spilling out.
static func trunk(sculpt: Kit.Sculpt, at: Vector3, yaw: float, tint: Color, variation: int) -> void:
	sculpt.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	sculpt.box(Vector3(0, 0.26, 0), Vector3(0.95, 0.52, 0.58), tint)
	sculpt.box(Vector3(0, 0.5, 0), Vector3(0.85, 0.05, 0.48), Color("#2a2233"))
	sculpt.box(Vector3(0, 0.76, -0.36), Vector3(0.95, 0.5, 0.1), tint.darkened(0.12), Basis(Vector3.RIGHT, -0.3))
	for strap: float in [-0.3, 0.3]:
		sculpt.box(Vector3(strap, 0.26, 0.3), Vector3(0.08, 0.54, 0.03), GOLD)
	sculpt.box(Vector3(0, 0.3, 0.31), Vector3(0.14, 0.12, 0.03), GOLD.lightened(0.2))
	var cloth := PARTY[variation % PARTY.size()]
	sculpt.box(Vector3(0.2, 0.55, 0.18), Vector3(0.4, 0.1, 0.3), cloth, Basis(Vector3.BACK, 0.25))
	sculpt.box(Vector3(0.44, 0.36, 0.3), Vector3(0.1, 0.36, 0.2), cloth)
	if variation % 2 == 0:
		# A top hat.
		sculpt.tube(Vector3(-0.2, 0.56, 0.02), 0.22, 0.22, 0.04, NIGHT, 10)
		sculpt.tube(Vector3(-0.2, 0.72, 0.02), 0.13, 0.14, 0.3, NIGHT, 10)
		sculpt.tube(Vector3(-0.2, 0.62, 0.02), 0.145, 0.145, 0.06, RED, 10)
	else:
		# A ruff and a jester's cap.
		sculpt.tube(Vector3(-0.2, 0.56, 0.02), 0.22, 0.12, 0.08, CREAM, 10)
		sculpt.tube(Vector3(-0.2, 0.76, 0.02), 0.13, 0.0, 0.34, PARTY[(variation + 2) % PARTY.size()], 6)
		sculpt.tube(Vector3(-0.2, 0.95, 0.02), 0.05, 0.05, 0.06, GOLD, 6)
	sculpt.frame = Transform3D.IDENTITY

## Stuffed mascot sitting at the frame origin: "bear", "bunny" or "star".
static func plush(sculpt: Kit.Sculpt, at: Vector3, yaw: float, kind: String, fur: Color, size := 1.0) -> void:
	sculpt.frame = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * size), at)
	sculpt.tube(Vector3(0, 0.2, 0), 0.24, 0.2, 0.4, fur, 8)
	sculpt.tube(Vector3(0, 0.56, 0), 0.22, 0.2, 0.34, fur.lightened(0.08), 8)
	sculpt.box(Vector3(0, 0.5, 0.2), Vector3(0.16, 0.12, 0.06), CREAM)
	sculpt.box(Vector3(0, 0.53, 0.235), Vector3(0.05, 0.04, 0.02), NIGHT)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.09, 0.62, 0.2), Vector3(0.04, 0.05, 0.02), NIGHT)
		sculpt.box(Vector3(side * 0.28, 0.26, 0.04), Vector3(0.12, 0.26, 0.12), fur.darkened(0.08), Basis(Vector3.BACK, side * 0.5))
		sculpt.box(Vector3(side * 0.14, 0.06, 0.22), Vector3(0.14, 0.12, 0.22), fur.darkened(0.08))
		match kind:
			"bunny": sculpt.box(Vector3(side * 0.1, 0.95, 0), Vector3(0.09, 0.44, 0.06), fur, Basis(Vector3.BACK, -side * 0.15))
			"star": sculpt.tube(Vector3(side * 0.2, 0.72, 0), 0.07, 0.0, 0.22, GOLD, 4, Basis(Vector3.BACK, -side * 1.1))
			_: sculpt.tube(Vector3(side * 0.17, 0.76, 0), 0.08, 0.08, 0.06, fur.darkened(0.1), 8, Basis(Vector3.RIGHT, PI * 0.5))
	if kind == "star":
		sculpt.tube(Vector3(0, 0.86, 0), 0.07, 0.0, 0.22, GOLD, 4)
	sculpt.box(Vector3(0, 0.4, 0.2), Vector3(0.2, 0.08, 0.05), RED if kind != "bear" else TEAL)
	sculpt.frame = Transform3D.IDENTITY

static func unicycle(sculpt: Kit.Sculpt, at: Vector3, yaw: float) -> void:
	sculpt.frame = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.12), at)
	var upright := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(Vector3(0, 0.36, 0), 0.36, 0.36, 0.07, NIGHT, 14, upright)
	sculpt.tube(Vector3(0, 0.36, 0.02), 0.29, 0.29, 0.08, CREAM, 14, upright)
	sculpt.tube(Vector3(0, 0.36, 0.04), 0.07, 0.07, 0.1, GOLD, 8, upright)
	for spoke in range(4):
		sculpt.box(Vector3(0, 0.36, 0.035), Vector3(0.56, 0.035, 0.04), RED, Basis(Vector3.BACK, PI * 0.25 * float(spoke)))
	sculpt.box(Vector3(0, 0.8, 0), Vector3(0.05, 0.9, 0.05), GOLD.darkened(0.15))
	sculpt.box(Vector3(0, 1.27, 0), Vector3(0.34, 0.08, 0.16), RED)
	sculpt.box(Vector3(0.14, 0.36, 0.12), Vector3(0.05, 0.05, 0.16), IRON)
	sculpt.frame = Transform3D.IDENTITY

## Juggling clubs, rings and balls laid out on a starred tub.
static func juggling(sculpt: Kit.Sculpt, at: Vector3) -> void:
	sculpt.frame = Transform3D(Basis.IDENTITY, at)
	sculpt.tube(Vector3(0, 0.28, 0), 0.34, 0.46, 0.56, RED, 10)
	sculpt.tube(Vector3(0, 0.57, 0), 0.5, 0.5, 0.05, GOLD, 10)
	sculpt.tube(Vector3(0, 0.05, 0), 0.5, 0.5, 0.06, GOLD, 10)
	for star in range(5):
		var facing := Basis(Vector3.UP, TAU * float(star) / 5.0)
		sculpt.box(facing * Vector3(0, 0.3, 0.41), Vector3(0.16, 0.16, 0.03), CREAM, facing * Basis(Vector3.BACK, PI * 0.25))
	for club in range(3):
		var lean := Basis(Vector3.UP, 2.1 * float(club)) * Basis(Vector3.BACK, 0.35)
		var foot := Vector3(0.12, 0.6, 0.0).rotated(Vector3.UP, 2.1 * float(club))
		sculpt.tube(foot + lean * Vector3(0, 0.3, 0), 0.03, 0.09, 0.42, PARTY[club], 6, lean)
		sculpt.tube(foot + lean * Vector3(0, 0.56, 0), 0.09, 0.04, 0.12, CREAM, 6, lean)
	for ball in range(4):
		var spot := Vector3(0.62 + 0.2 * float(ball % 2), 0.1, -0.2 + 0.22 * float(ball))
		sculpt.tube(spot, 0.1, 0.07, 0.1, PARTY[(ball + 2) % PARTY.size()], 6)
		sculpt.tube(spot + Vector3(0, 0.08, 0), 0.07, 0.02, 0.06, PARTY[(ball + 2) % PARTY.size()].lightened(0.2), 6)
	for hoop in range(2):
		var lying := Vector3(-0.72, 0.03 + 0.03 * float(hoop), 0.2 + 0.1 * float(hoop))
		ring(sculpt, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), lying), 0.26, PARTY[hoop + 1], 0.05)
	sculpt.frame = Transform3D.IDENTITY

## Hoop in the local XY plane around the frame origin (the sculpt frame is kept).
static func ring(sculpt: Kit.Sculpt, frame: Transform3D, radius: float, tint: Color, thickness := 0.06, sides := 12) -> void:
	for index in range(sides):
		var middle := TAU * (float(index) + 0.5) / float(sides)
		var chord := 2.0 * radius * sin(PI / float(sides)) + thickness * 0.5
		sculpt.box(frame * Vector3(cos(middle) * radius, sin(middle) * radius, 0), Vector3(chord, thickness, thickness), tint if index % 2 == 0 else tint.lightened(0.18), frame.basis * Basis(Vector3.BACK, middle + PI * 0.5))

## Bass drum and cymbal on a small riser; the cymbal stands on `side` (+1 east,
## -1 west). The sticks are animated by the world.
static func drum(sculpt: Kit.Sculpt, at: Vector3, side := 1.0) -> void:
	sculpt.frame = Transform3D(Basis.IDENTITY, at)
	sculpt.tube(Vector3(0, 0.08, 0), 0.9, 0.95, 0.16, PLUM, 10)
	sculpt.tube(Vector3(0, 0.17, 0), 0.9, 0.9, 0.03, GOLD, 10)
	var upright := Basis(Vector3.RIGHT, PI * 0.5)
	var shell := Vector3(-0.1 * side, 0.72, 0)
	sculpt.tube(shell, 0.5, 0.5, 0.44, RED, 12, upright)
	sculpt.tube(shell + Vector3(0, 0, 0.23), 0.46, 0.46, 0.03, CREAM, 12, upright)
	sculpt.box(shell + Vector3(0, 0, 0.255), Vector3(0.3, 0.3, 0.02), GOLD, Basis(Vector3.BACK, PI * 0.25))
	for hoop: float in [-0.2, 0.2]:
		sculpt.tube(shell + Vector3(0, 0, hoop), 0.53, 0.53, 0.06, GOLD, 12, upright)
	for foot: float in [-1.0, 1.0]:
		sculpt.box(Vector3(shell.x + foot * 0.32, 0.25, 0), Vector3(0.07, 0.2, 0.5), IRON)
	sculpt.box(Vector3(0.62 * side, 0.72, -0.05), Vector3(0.04, 1.1, 0.04), IRON)
	sculpt.tube(Vector3(0.62 * side, 1.29, -0.05), 0.3, 0.05, 0.05, GOLD.lightened(0.15), 10)
	sculpt.frame = Transform3D.IDENTITY

## Empty pitch waiting for a game stand: a starred mat with a pennant stake.
static func pitch(sculpt: Kit.Sculpt, at: Vector3, tint: Color) -> void:
	sculpt.frame = Transform3D(Basis.IDENTITY, at)
	sculpt.tube(Vector3(0, 0.012, 0), 0.86, 0.9, 0.024, GOLD, 16)
	sculpt.tube(Vector3(0, 0.02, 0), 0.76, 0.76, 0.024, tint, 16)
	for point in range(8):
		var turn := Basis(Vector3.UP, TAU * float(point) / 8.0)
		sculpt.tri(turn * Vector3(0, 0.034, 0.7), turn * Vector3(-0.17, 0.034, 0.24), turn * Vector3(0.17, 0.034, 0.24), CREAM if point % 2 == 0 else GOLD)
	sculpt.tube(Vector3(0, 0.036, 0), 0.26, 0.26, 0.02, CREAM, 8)
	sculpt.tube(Vector3(-0.7, 0.6, -0.55), 0.035, 0.03, 1.2, WOOD, 6)
	sculpt.tube(Vector3(-0.7, 1.24, -0.55), 0.06, 0.02, 0.1, GOLD, 6)
	sculpt.sheet(Vector3(-0.7, 1.16, -0.55), Vector3(-0.7, 0.86, -0.55), Vector3(-0.28, 1.01, -0.55), tint.lightened(0.15))
	sculpt.frame = Transform3D.IDENTITY

## Arcade cabinet for a mirror game, facing local +Z: plinth, cabinet with a
## leaning canopy, a small looking glass and a card slot.
static func cabinet(sculpt: Kit.Sculpt, frame: Transform3D, body: Color, shape: String) -> void:
	sculpt.frame = frame
	sculpt.box(Vector3(0, 0.09, 0), Vector3(1.3, 0.18, 0.9), NIGHT)
	for band in range(4):
		sculpt.box(Vector3(0, 0.38 + 0.42 * float(band), 0), Vector3(1.08, 0.42, 0.72), body if band % 2 == 0 else body.lightened(0.14))
	sculpt.box(Vector3(0, 0.2, 0), Vector3(1.16, 0.06, 0.8), GOLD)
	sculpt.box(Vector3(0, 1.88, 0), Vector3(1.16, 0.06, 0.8), GOLD)
	sculpt.box(Vector3(0, 2.04, 0.12), Vector3(1.4, 0.1, 1.06), GOLD.darkened(0.2), Basis(Vector3.RIGHT, 0.18))
	sculpt.box(Vector3(0, 2.12, 0.1), Vector3(1.2, 0.08, 0.86), RED, Basis(Vector3.RIGHT, 0.18))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.54, 1.04, 0.37), Vector3(0.08, 1.7, 0.06), GOLD)
		sculpt.tube(Vector3(side * 0.62, 2.26, 0.12), 0.07, 0.02, 0.2, GOLD, 6)
	sculpt.box(Vector3(0, 0.5, 0.37), Vector3(0.4, 0.26, 0.04), CREAM)
	sculpt.box(Vector3(0, 0.5, 0.39), Vector3(0.28, 0.04, 0.03), NIGHT)
	sculpt.frame = Transform3D.IDENTITY
	mirror(sculpt, null, frame * Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0.4)), shape, Vector2(0.7, 0.95), Color.WHITE, body.darkened(0.3))

## One balloon with its knot at the origin and the string hanging below.
static func balloon_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.05, 0), 0.03, 0.06, 0.06, Color("#d9d9d9"), 6)
	sculpt.tube(Vector3(0, 0.2, 0), 0.07, 0.24, 0.26, Color.WHITE, 8)
	sculpt.tube(Vector3(0, 0.44, 0), 0.24, 0.27, 0.22, Color.WHITE, 8)
	sculpt.tube(Vector3(0, 0.64, 0), 0.27, 0.16, 0.18, Color("#f4f4f4"), 8)
	sculpt.tube(Vector3(0, 0.75, 0), 0.16, 0.0, 0.05, Color("#f4f4f4"), 8)
	sculpt.box(Vector3(0.1, 0.52, 0.2), Vector3(0.05, 0.14, 0.03), Color(1.25, 1.25, 1.25))
	sculpt.box(Vector3(0, -0.6, 0), Vector3(0.012, 1.2, 0.012), Color("#bfbfbf"))
	return sculpt.mesh()

## Trapeze hanging from the origin: two ropes and a bar `drop` metres below.
static func trapeze_mesh(drop: float) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(0, -drop * 0.5, side * 0.55), Vector3(0.035, drop, 0.035), ROPE)
		sculpt.tube(Vector3(0, -drop, side * 0.62), 0.06, 0.06, 0.08, RED, 6, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0, -drop, 0), Vector3(0.07, 0.07, 1.2), GOLD)
	return sculpt.mesh()

## Aerial hoop hanging from the origin on a single rope.
static func hoop_mesh(drop: float, tint: Color) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, -drop * 0.5 + 0.3, 0), Vector3(0.03, drop - 0.6, 0.03), ROPE)
	ring(sculpt, Transform3D(Basis.IDENTITY, Vector3(0, -drop, 0)), 0.6, tint, 0.07, 14)
	for ribbon: float in [-1.0, 1.0]:
		sculpt.sheet(Vector3(ribbon * 0.1, -drop - 0.6, 0), Vector3(ribbon * 0.2, -drop - 1.3, 0), Vector3(ribbon * 0.02, -drop - 1.2, 0), CREAM if ribbon < 0.0 else ROSE)
	return sculpt.mesh()

## A pair of drumsticks crossing over the origin; the world beats them.
static func sticks_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for side: float in [-1.0, 1.0]:
		var lean := Basis(Vector3.BACK, side * 0.5)
		sculpt.box(lean * Vector3(0, 0.3, 0) + Vector3(side * 0.12, 0, 0), Vector3(0.035, 0.6, 0.035), PALE_WOOD, lean)
		sculpt.tube(lean * Vector3(0, 0.02, 0) + Vector3(side * 0.12, 0, 0), 0.06, 0.06, 0.08, CREAM, 6)
	return sculpt.mesh()
