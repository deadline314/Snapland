extends RefCounted
## Small building blocks shared by map games and toys: textured props that
## live under the field layer, a rope tube, and a batch of pixel animals drawn
## from the shared ambience atlas.

const Sprites = preload("res://game/world/ambience_sprites.gd")
const CRITTER_SHADER := "res://game/world/ambience_critter.gdshader"
const SAND_PIXELS := 32

## Coastal atlas tiles used for props.
const TILE_COBBLE := 0
const TILE_PLANK := 1
const TILE_RED_BOARD := 3
const TILE_CANVAS := 6
const TILE_BRASS := 7


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material, shadow := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = at
	instance.material_override = material
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, material)


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, top := -1.0, sides := 12) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0.0 else top
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return mesh(parent, shape, at, material)


static func ball(parent: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 10
	shape.rings = 5
	return mesh(parent, shape, at, material)


## Many copies of one small part in a single draw.
static func batch(parent: Node3D, shape: Mesh, transforms: Array[Transform3D], material: Material, colors: Array[Color] = []) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = shape
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
		if multi.use_colors:
			multi.set_instance_color(index, colors[index % colors.size()])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Base, pole and cap for every given ground point: the three-part post field
## props stand on, drawn as three batches however many posts there are.
static func posts(world: Node3D, parent: Node3D, grounds: Array[Vector3], height: float, cap_color: Color, thickness := 0.065) -> void:
	var bases: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	for ground in grounds:
		bases.append(Transform3D(Basis.IDENTITY, ground + Vector3(0, 0.09, 0)))
		poles.append(Transform3D(Basis.IDENTITY, ground + Vector3(0, 0.18 + height * 0.5, 0)))
		caps.append(Transform3D(Basis.IDENTITY, ground + Vector3(0, 0.2 + height, 0)))
	var base := CylinderMesh.new()
	base.bottom_radius = thickness * 4.0
	base.top_radius = thickness * 3.2
	base.height = 0.18
	base.radial_segments = 10
	base.rings = 1
	batch(parent, base, bases, world._coastal_surface(TILE_COBBLE, 1.1))
	var pole := CylinderMesh.new()
	pole.bottom_radius = thickness
	pole.top_radius = thickness * 0.85
	pole.height = height
	pole.radial_segments = 8
	pole.rings = 1
	batch(parent, pole, poles, world._wood_material(Color("#8a6a48")))
	var cap := SphereMesh.new()
	cap.radius = thickness * 1.9
	cap.height = thickness * 3.8
	cap.radial_segments = 10
	cap.rings = 5
	batch(parent, cap, caps, world._mat(cap_color))


## A soft round shadow lying on the ground under a moving prop.
static func blob(world: Node3D, parent: Node3D, size: Vector2) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	return mesh(parent, plane, Vector3.ZERO, blob_material(world), false)


static func blob_material(world: Node3D) -> StandardMaterial3D:
	const KEY := "field:blob"
	if world.material_cache.has(KEY):
		return world.material_cache[KEY]
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_texture = Sprites.shadow_blob()
	world.material_cache[KEY] = shade
	return shade


## The world's painted finish for a large face, its flat colour for a small one.
static func finish(world: Node3D, color: Color, size: Vector3) -> Material:
	return world._finish(color, size)


## A see-through tinted surface (water, light, glass), cached by colour.
static func clear_material(world: Node3D, color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "field:clear:%s:%.2f" % [color.to_html(true), glow]
	if world.material_cache.has(key):
		return world.material_cache[key]
	var clear := StandardMaterial3D.new()
	clear.albedo_color = color
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.3
	if glow > 0.0:
		clear.emission_enabled = true
		clear.emission = Color(color.r, color.g, color.b)
		clear.emission_energy_multiplier = glow
	world.material_cache[key] = clear
	return clear


## Changes a label only when it differs, so a per-frame caller rebuilds nothing.
static func write(item: Label3D, text: String, color: Color) -> void:
	if item.text != text:
		item.text = text
	if item.modulate != color:
		item.modulate = color


static func label(parent: Node3D, text: String, at: Vector3, size: int, color: Color) -> Label3D:
	var item := Label3D.new()
	item.text = text
	item.position = at
	item.font_size = size
	item.pixel_size = 0.015
	item.modulate = color
	item.outline_size = maxi(2, int(size / 6.0))
	item.outline_modulate = Color("#223f47")
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	parent.add_child(item)
	return item


## Fine speckled sand generated once; no flat single-colour patch.
static func sand_material(world: Node3D) -> StandardMaterial3D:
	const KEY := "field:sand"
	if world.material_cache.has(KEY):
		return world.material_cache[KEY]
	var image := Image.create(SAND_PIXELS, SAND_PIXELS, false, Image.FORMAT_RGB8)
	var grains := RandomNumberGenerator.new()
	grains.seed = 5701
	# Matched to the dry sand of the beach.
	var tones := [Color("#cfb685"), Color("#c6ab7a"), Color("#d9c294"), Color("#b99d6c")]
	for y in range(SAND_PIXELS):
		for x in range(SAND_PIXELS):
			var roll := grains.randf()
			image.set_pixel(x, y, tones[0] if roll < 0.62 else (tones[1] if roll < 0.82 else (tones[2] if roll < 0.95 else tones[3])))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * (48.0 / SAND_PIXELS)
	material.roughness = 0.95
	world.material_cache[KEY] = material
	return material


## Round rope through the given points. `reference` must never be parallel to
## the rope: it keeps the cross-section from twisting along the curve.
static func tube(points: PackedVector3Array, radius: float, reference := Vector3.FORWARD, sides := 5) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(points.size()):
		var along := (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var side := along.cross(reference).normalized()
		var up := side.cross(along)
		for corner in range(sides):
			var angle := TAU * float(corner) / float(sides)
			var normal := side * cos(angle) + up * sin(angle)
			vertices.append(points[index] + normal * radius)
			normals.append(normal)
		if index == 0:
			continue
		var base := (index - 1) * sides
		for corner in range(sides):
			var next := (corner + 1) % sides
			indices.append_array([base + corner, base + sides + corner, base + next, base + next, base + sides + corner, base + sides + next])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return shape


## A fixed pool of camera-facing pixel animals in one draw call. The batch stays
## at the world origin, so positions are world positions.
class SpriteBatch:
	extends MultiMeshInstance3D

	## Which items are currently on show (the renderer cannot be asked back).
	var shown := PackedByteArray()
	var _world: Node3D
	var _cell := Vector2.ONE

	func _init(world: Node3D, count: int, pixels_per_metre := 48.0) -> void:
		_world = world
		_cell = Vector2(Sprites.CELL) / pixels_per_metre
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = count
		multimesh.custom_aabb = AABB(Vector3(-160, -8, -160), Vector3(320, 48, 320))
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shown.resize(count)
		if ResourceLoader.exists(CRITTER_SHADER):
			var material := ShaderMaterial.new()
			material.shader = load(CRITTER_SHADER)
			material.set_shader_parameter("atlas", Sprites.critter_atlas())
			material.set_shader_parameter("cell_uv", Sprites.cell_uv())
			material_override = material
		else:
			push_warning("Critter shader is missing; field animals are not shown.")
			visible = false
		for index in range(count):
			multimesh.set_instance_color(index, Color.WHITE)
			shown[index] = 1
			hide_item(index)

	func tint(index: int, color: Color) -> void:
		multimesh.set_instance_color(index, color)

	## `feet` is where the bottom centre of the sprite cell sits.
	func put(index: int, feet: Vector3, kind: String, frame: int, mirrored := false, scale := 1.0) -> void:
		var facing := Basis.IDENTITY
		if is_instance_valid(_world.camera):
			facing = _world.camera.global_basis
		var extent := _cell * scale
		multimesh.set_instance_transform(index, Transform3D(facing.x * extent.x, facing.y * extent.y, facing.z, feet + facing.y * (extent.y * 0.5)))
		multimesh.set_instance_custom_data(index, Color(frame, Sprites.critter_row(kind), 1.0 if mirrored else 0.0, 0.0))
		shown[index] = 1

	func hide_item(index: int) -> void:
		if shown[index] == 0:
			return
		shown[index] = 0
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -50, 0)))

	func shown_count() -> int:
		return shown.count(1)
