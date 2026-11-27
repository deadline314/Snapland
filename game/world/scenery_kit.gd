extends RefCounted
## Shared building blocks for a region's scenery (first used by the tidal harbor).
## A world creates one kit in _build_region_geometry(), builds through it and calls
## finish(). Everything is created once and every material goes through the world's
## material cache, so node and material counts never change after the build.

const SHORE_WATER := preload("res://game/world/shore_water.gdshader")
const SHORE_GROUND := preload("res://game/world/shore_ground.gdshader")
const CLOTH := preload("res://game/world/cloth_flutter.gdshader")
const WARM_GLOW := Color("#ffd68b")
const LAMP_HEIGHT := 2.85

## Merges many small vertex-coloured shapes into one flat-shaded mesh, so trim and
## bespoke props cost a single node and draw call.
class Sculpt:
	const FACES := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	## Shapes added after setting this are placed in that local frame.
	var frame := Transform3D.IDENTITY
	var _tool := SurfaceTool.new()
	var _triangles := 0

	func _init() -> void:
		_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	func is_empty() -> bool:
		return _triangles == 0

	func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		# Vertex colours reach the shader as linear values; convert so they match swatches.
		var linear := color.srgb_to_linear()
		_tool.set_color(linear)
		_tool.add_vertex(frame * a)
		_tool.set_color(linear)
		_tool.add_vertex(frame * b)
		_tool.set_color(linear)
		_tool.add_vertex(frame * c)
		_triangles += 1

	## Corners run clockwise when seen from the visible side.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
		tri(a, b, c, color)
		tri(a, c, d, color)

	## A thin panel visible from both sides (sails, signs cut to shape).
	func sheet(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		tri(a, b, c, color)
		tri(a, c, b, color)

	func box(center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
		var half := size * 0.5
		for face: Array in FACES:
			var along_normal: Vector3 = center + basis * (face[0] * half)
			var along_u: Vector3 = basis * (face[1] * half)
			var along_v: Vector3 = basis * (face[2] * half)
			quad(along_normal - along_u + along_v, along_normal + along_u + along_v, along_normal + along_u - along_v, along_normal - along_u - along_v, color)

	## Capped cylinder, cone or frustum around the local Y axis.
	func tube(center: Vector3, bottom_radius: float, top_radius: float, height: float, color: Color, sides := 8, basis := Basis.IDENTITY) -> void:
		var up := Vector3(0, height * 0.5, 0)
		var top_center := center + basis * up
		var bottom_center := center - basis * up
		for index in range(sides):
			var from := Vector3(cos(TAU * float(index) / float(sides)), 0, sin(TAU * float(index) / float(sides)))
			var to := Vector3(cos(TAU * float(index + 1) / float(sides)), 0, sin(TAU * float(index + 1) / float(sides)))
			var bottom_from := bottom_center + basis * (from * bottom_radius)
			var bottom_to := bottom_center + basis * (to * bottom_radius)
			var top_from := top_center + basis * (from * top_radius)
			var top_to := top_center + basis * (to * top_radius)
			if top_radius > 0.001 and bottom_radius > 0.001:
				quad(bottom_to, top_to, top_from, bottom_from, color)
			elif bottom_radius > 0.001:
				tri(bottom_to, top_center, bottom_from, color)
			else:
				tri(bottom_center, top_to, top_from, color)
			if top_radius > 0.001:
				tri(top_center, top_from, top_to, color)
			if bottom_radius > 0.001:
				tri(bottom_center, bottom_to, bottom_from, color)

	func mesh() -> ArrayMesh:
		_tool.generate_normals()
		return _tool.commit()

## Instances of one mesh drawn as a single multimesh.
class Batch:
	var mesh: Mesh
	var material: Material
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	func add(center: Vector3, size := Vector3.ONE, basis := Basis.IDENTITY, color := Color.WHITE) -> void:
		transforms.append(Transform3D(basis * Basis.from_scale(size), center))
		colors.append(color.srgb_to_linear())

var world: Node3D
## Static trim for the whole region; committed by finish().
var detail := Sculpt.new()
## Lantern bodies; they glow by time of day through set_glow().
var glow := Sculpt.new()
var glow_material: StandardMaterial3D
## Basis of the fixed follow camera, for placing parts against billboards.
var view_basis: Basis
var unit_box := BoxMesh.new()
var unit_post := CylinderMesh.new()
var unit_boulder: Mesh
var _batches: Dictionary = {}
var _ground_materials: Array[ShaderMaterial] = []

func _init(owner: Node3D) -> void:
	world = owner
	view_basis = owner._view_basis
	unit_post.top_radius = 0.5
	unit_post.bottom_radius = 0.5
	unit_post.height = 1.0
	unit_post.radial_segments = 8
	unit_post.rings = 1
	var rock := Sculpt.new()
	rock.tube(Vector3(0, -0.2, 0), 0.5, 0.45, 0.6, Color.WHITE, 6)
	rock.tube(Vector3(0.05, 0.27, -0.03), 0.45, 0.24, 0.34, Color.WHITE, 5)
	unit_boulder = rock.mesh()
	glow_material = world._vertex_color_material("scenery-glow", 0.6)
	glow_material.emission_enabled = true
	glow_material.emission = WARM_GLOW
	glow_material.emission_energy_multiplier = 0.0

## One multimesh per key. Add instances any time before finish().
func batch(key: String, mesh: Mesh, material: Material) -> Batch:
	if not _batches.has(key):
		var created := Batch.new()
		created.mesh = mesh
		created.material = material
		_batches[key] = created
	return _batches[key]

## Unit boxes sharing one textured surface, such as decks, copings and counters.
func surface(material: Material) -> Batch:
	return batch("box:%d" % material.get_instance_id(), unit_box, material)

## Short painted posts and caps; each instance takes its own colour.
func posts() -> Batch:
	return batch("posts", unit_post, world._vertex_color_material("scenery-detail"))

## Timber piles and rail posts, which are tall enough to need a wood grain.
func piles() -> Batch:
	return batch("piles", unit_post, world._wood_material(Color("#6b5137")))

## Commits the merged trim, the lantern bodies, every batch and the billboards'
## contact shadows. Call once.
func finish() -> void:
	world._build_foliage_contact_shadows()
	if not detail.is_empty():
		world._mesh(detail.mesh(), Vector3.ZERO, world._vertex_color_material("scenery-detail")).name = "SceneryDetail"
	if not glow.is_empty():
		var lanterns: MeshInstance3D = world._mesh(glow.mesh(), Vector3.ZERO, glow_material)
		lanterns.name = "SceneryLanterns"
		lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for key: String in _batches:
		var entry: Batch = _batches[key]
		world._multi_mesh(entry.mesh, Vector3.ZERO, entry.transforms, entry.colors, entry.material).name = "Scenery_" + key.get_slice(":", 0)

## Lantern bodies stay unlit by day and brighten with the region's lamp level.
func set_glow(energy: float) -> void:
	glow_material.emission_energy_multiplier = energy

## Emission for one mesh, whether or not the occlusion controller manages its surface.
static func set_emission(target: GeometryInstance3D, energy: float) -> void:
	var material := target.material_override
	if material is ShaderMaterial:
		material.set_shader_parameter("occluder_emission_energy", energy)
	elif material is StandardMaterial3D:
		material.emission_energy_multiplier = energy

## Invisible obstacle. Keep it taller than 1.2 m so floor probes that start inside it ignore it.
func blocker(center: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.rotation.y = yaw
	world.add_child(body)
	return body

## Flat-topped bank with a sloping, slightly irregular skirt: sandbars, beaches, rock
## aprons. `rect` bounds the flat top; the node origin sits on the top so it can sink.
func mound(rect: Rect2, top_y: float, drop: float, skirt: float, material: Material, wobble_seed := 0.0) -> MeshInstance3D:
	const SIDES := 32
	var half := rect.size * 0.5
	var loops: Array[PackedVector3Array] = []
	for ring: Vector2 in [Vector2(0.0, 0.0), Vector2(skirt * 0.45, -drop * 0.3), Vector2(skirt, -drop)]:
		var loop := PackedVector3Array()
		for index in range(SIDES):
			var angle := TAU * float(index) / float(SIDES)
			# A squircle keeps the corners of a walkable rectangle inside the flat top.
			var direction := Vector2(signf(cos(angle)) * sqrt(absf(cos(angle))), signf(sin(angle)) * sqrt(absf(sin(angle))))
			var wobble := 1.0 + 0.12 * sin(angle * 3.0 + wobble_seed) + 0.07 * sin(angle * 7.0 + wobble_seed * 2.3)
			var point := direction * half + direction.normalized() * ring.x * wobble
			loop.append(Vector3(point.x, ring.y, point.y))
		loops.append(loop)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(SIDES):
		var next := (index + 1) % SIDES
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(loops[0][index])
		tool.add_vertex(loops[0][next])
		for ring_index in range(2):
			var upper := loops[ring_index]
			var lower := loops[ring_index + 1]
			for corner: Vector3 in [lower[next], upper[next], upper[index], lower[next], upper[index], lower[index]]:
				tool.add_vertex(corner)
	tool.index()
	tool.generate_normals()
	var center := rect.get_center()
	var bank: MeshInstance3D = world._mesh(tool.commit(), Vector3(center.x, top_y, center.y), material)
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bank

## Sand or rock surface that darkens and foams at the waterline. Follows set_water_level().
func shore_ground(key: String, dry: Color, wet: Color, speckle := 1.0) -> ShaderMaterial:
	var cache_key := "shore-ground:" + key
	if world.material_cache.has(cache_key): return world.material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = SHORE_GROUND
	material.set_shader_parameter("dry_color", dry)
	material.set_shader_parameter("wet_color", wet)
	material.set_shader_parameter("speckle", speckle)
	world.material_cache[cache_key] = material
	world.component_motion.register_shader(material)
	_ground_materials.append(material)
	return material

func set_water_level(level: float) -> void:
	for material in _ground_materials:
		material.set_shader_parameter("water_level", level)

## Sea whose shelf colour and foam follow the given land rectangles; `shoals` are
## banks the tide covers. At most eight of each.
func shore_water(land: Array[Rect2], shoals: Array[Rect2]) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHORE_WATER
	material.set_shader_parameter("land_rects", _pack_rects(land))
	material.set_shader_parameter("land_count", mini(land.size(), 8))
	material.set_shader_parameter("shoal_rects", _pack_rects(shoals))
	material.set_shader_parameter("shoal_count", mini(shoals.size(), 8))
	world.material_cache["shore-water"] = material
	return material

func _pack_rects(rects: Array[Rect2]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	packed.resize(32)
	for index in range(mini(rects.size(), 8)):
		var center := rects[index].get_center()
		packed[index * 4] = center.x
		packed[index * 4 + 1] = center.y
		packed[index * 4 + 2] = rects[index].size.x * 0.5
		packed[index * 4 + 3] = rects[index].size.y * 0.5
	return packed

## Painted billboard from the foliage atlas; the world casts its silhouette and
## grounds it. Returns null when the atlas lacks `kind`, so callers can place a fallback.
func billboard(kind: String, ground: Vector3, height: float) -> Sprite3D:
	if not world._foliage_has(kind): return null
	var sprite: Sprite3D = world._foliage_sprite(kind, ground, height)
	# The shared grounding measures the Welcome island's terrain; a region stands its
	# props on its own ground, so lay the contact shadow there.
	var contacts: Array[Transform3D] = world._foliage_contact_transforms
	var contact := contacts[-1]
	contact.origin.y = ground.y + 0.012
	contacts[-1] = contact
	return sprite

## Where a point of an upright billboard really is: `across`/`up` are metres from its centre.
func billboard_point(ground: Vector3, height: float, across: float, up: float) -> Vector3:
	return ground + Vector3(0, height * 0.5, 0) + view_basis.x * across + view_basis.y * up + view_basis.z * 0.08

## Painted lamp post with a glowing lantern body and one light in the region's lamp budget.
func lamp_post(ground: Vector3, reach := 6.5) -> void:
	var lantern := billboard_point(ground, LAMP_HEIGHT, -0.105 * LAMP_HEIGHT, 0.2 * LAMP_HEIGHT)
	if billboard("lamp", ground, LAMP_HEIGHT) == null:
		detail.tube(ground + Vector3(0, 1.2, 0), 0.08, 0.06, 2.4, Color("#3d3a36"))
		lantern = ground + Vector3(0, 2.5, 0)
	glow.box(lantern, Vector3(0.2, 0.27, 0.06), WARM_GLOW, view_basis)
	var light := OmniLight3D.new()
	light.position = ground + Vector3(0, 2.15, 0.2)
	light.light_color = Color("#ffd79a")
	light.omni_range = reach
	light.light_energy = 0.0
	world.add_child(light)
	world.lamps.append(light)

func cloth_material(key: String, strength: float, net_cells := 0.0) -> ShaderMaterial:
	var cache_key := "cloth:" + key
	if world.material_cache.has(cache_key): return world.material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = CLOTH
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("net_cells", net_cells)
	world.material_cache[cache_key] = material
	world.component_motion.register_shader(material)
	return material

## Cloth panel hanging from its origin corner: +X across, -Y down. Pinned along the
## left edge (flags) or the top edge (nets, banners).
static func cloth_mesh(size: Vector2, columns: int, rows: int, pin_top: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		for column in range(columns):
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var uv := Vector2(float(column + corner.x) / float(columns), float(row + corner.y) / float(rows))
				tool.set_normal(Vector3.BACK)
				tool.set_uv(uv)
				tool.set_uv2(Vector2(uv.y if pin_top else uv.x, 0.0))
				tool.add_vertex(Vector3(uv.x * size.x, -uv.y * size.y, 0.0))
	return tool.commit()

## A sagging line of pennants between two points.
func bunting(from: Vector3, to: Vector3, colors: Array[Color], sag := 0.35) -> void:
	if not _batches.has("pennants"):
		var pennant := SurfaceTool.new()
		pennant.begin(Mesh.PRIMITIVE_TRIANGLES)
		for corner: Vector3 in [Vector3(-0.17, 0, 0), Vector3(0.17, 0, 0), Vector3(0, -0.42, 0)]:
			pennant.set_normal(Vector3.BACK)
			pennant.set_uv(Vector2(corner.x + 0.5, -corner.y))
			pennant.set_uv2(Vector2(-corner.y / 0.42, 0.0))
			pennant.add_vertex(corner)
		batch("pennants", pennant.commit(), cloth_material("pennant", 0.12))
	var pennants: Batch = _batches["pennants"]
	var count := maxi(3, int(from.distance_to(to) / 0.62))
	var previous := from
	for index in range(count):
		var along := (float(index) + 0.5) / float(count)
		var point := from.lerp(to, along) - Vector3(0, sag * 4.0 * along * (1.0 - along), 0)
		pennants.add(point, Vector3.ONE, Basis.IDENTITY, colors[index % colors.size()])
		_line(previous, point)
		previous = point
	_line(previous, to)

func _line(from: Vector3, to: Vector3) -> void:
	var span := to - from
	detail.box((from + to) * 0.5, Vector3(0.03, 0.03, span.length()), Color("#6b5a45"), Basis.looking_at(span.normalized()))
