extends RefCounted
## The automated half of design/runtime/scene-building-standards.md.
##
## `audit(world)` inspects a built region and returns every violation it can
## prove from the scene tree alone. It never changes the scene, so tests, review
## tools and future editors can all call it.

## A primitive shows a "flat block" when it has a face at least this large…
const FLAT_FACE_LONG := 1.0
const FLAT_FACE_SHORT := 0.5
## …painted with one untextured colour. Glass-like materials below this alpha are exempt.
const FLAT_MIN_ALPHA := 0.9
## A billboard may sit this far above its ground before it reads as floating
## (sprite art carries a little transparent margin).
const FLOATING_TOLERANCE := 0.3
## Rocks and roots may be bedded into sand, which lies below the lawn height.
const SUNKEN_TOLERANCE := 0.6
const NODE_BUDGETS := {"welcome": 2600}
const DEFAULT_NODE_BUDGET := 900
const RULES: Array[String] = ["flat_block", "primitive_shadow", "floating_sprite", "node_budget"]
const OCCLUDER_SHADER := "res://game/world/occluder.gdshader"
const LIVING_SPRITE_SHADER := "res://game/world/living_sprite.gdshader"
const FOLIAGE_MOTION_KIND := 0


## Returns {rule: Array of {where, detail}} with an entry for every rule.
static func audit(world: Node3D, region: String) -> Dictionary:
	var found := {}
	for rule in RULES:
		found[rule] = []
	var node_count := 1
	for node in world.find_children("*", "Node", true, false):
		node_count += 1
		if node is MeshInstance3D:
			_check_mesh(world, node, found)
		elif node is MultiMeshInstance3D:
			_check_multimesh(world, node, found)
		elif node is Sprite3D:
			_check_sprite(world, node, found)
	var budget := int(NODE_BUDGETS.get(region, DEFAULT_NODE_BUDGET))
	if node_count > budget:
		found["node_budget"].append({"where": region, "detail": "%d nodes, budget %d" % [node_count, budget]})
	return found


## One line per rule, for logs and tickets.
static func summary(found: Dictionary) -> String:
	var parts: PackedStringArray = []
	for rule in RULES:
		parts.append("%s=%d" % [rule, (found.get(rule, []) as Array).size()])
	return ", ".join(parts)


## Scene path plus ground position, so unnamed generated nodes can still be found.
static func _where(world: Node3D, node: Node) -> String:
	var position := (node as Node3D).global_position if node is Node3D else Vector3.ZERO
	return "%s @ (%.1f, %.1f)" % [str(world.get_path_to(node)), position.x, position.z]


static func _is_block_mesh(mesh: Mesh) -> bool:
	return mesh is BoxMesh or mesh is CylinderMesh or mesh is SphereMesh or mesh is CapsuleMesh or mesh is PrismMesh


## True when a primitive of this size has a face big enough to read as a blank block.
static func shows_flat_face(size: Vector3) -> bool:
	var sides := [absf(size.x), absf(size.y), absf(size.z)]
	sides.sort()
	return sides[2] > FLAT_FACE_LONG and sides[1] > FLAT_FACE_SHORT


static func _is_flat_material(material: Material) -> bool:
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return standard.albedo_texture == null and not standard.vertex_color_use_as_albedo and standard.albedo_color.a >= FLAT_MIN_ALPHA
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		# The occlusion cutaway wraps a flat colour without adding any surface detail.
		return shader != null and shader.resource_path == OCCLUDER_SHADER
	# No material at all renders as the engine's flat default.
	return material == null


static func _surface_material(instance: GeometryInstance3D, mesh: Mesh) -> Material:
	if instance.material_override != null:
		return instance.material_override
	if instance is MeshInstance3D and (instance as MeshInstance3D).get_surface_override_material_count() > 0:
		var override := (instance as MeshInstance3D).get_surface_override_material(0)
		if override != null:
			return override
	return mesh.surface_get_material(0) if mesh != null and mesh.get_surface_count() > 0 else null


static func _check_mesh(world: Node3D, instance: MeshInstance3D, found: Dictionary) -> void:
	var mesh := instance.mesh
	if mesh == null or not instance.is_visible_in_tree() or not _is_block_mesh(mesh):
		return
	if instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		found["primitive_shadow"].append({"where": _where(world, instance), "detail": mesh.get_class()})
		return
	var size := mesh.get_aabb().size * instance.global_basis.get_scale()
	if shows_flat_face(size) and _is_flat_material(_surface_material(instance, mesh)):
		found["flat_block"].append({"where": _where(world, instance), "detail": "%s %.1f x %.1f x %.1f m" % [mesh.get_class(), size.x, size.y, size.z]})


static func _check_multimesh(world: Node3D, instance: MultiMeshInstance3D, found: Dictionary) -> void:
	var batch := instance.multimesh
	if batch == null or batch.mesh == null or not instance.is_visible_in_tree() or not _is_block_mesh(batch.mesh):
		return
	if not _is_flat_material(_surface_material(instance, batch.mesh)):
		return
	var base := batch.mesh.get_aabb().size * instance.global_basis.get_scale()
	var flat := 0
	for index in batch.instance_count:
		if shows_flat_face(base * batch.get_instance_transform(index).basis.get_scale()):
			flat += 1
	if flat > 0:
		found["flat_block"].append({"where": _where(world, instance), "detail": "%d batched %s instances" % [flat, batch.mesh.get_class()]})


static func _check_sprite(world: Node3D, sprite: Sprite3D, found: Dictionary) -> void:
	if not sprite.is_visible_in_tree() or not world.has_method("ground_surface_y"):
		return
	var material := sprite.material_override as ShaderMaterial
	if material == null or material.shader == null or material.shader.resource_path != LIVING_SPRITE_SHADER:
		return
	if int(material.get_shader_parameter("motion_kind")) != FOLIAGE_MOTION_KIND:
		return
	var bounds := sprite.get_aabb()
	var bottom := sprite.global_position.y + bounds.position.y * sprite.global_basis.get_scale().y
	var ground: float = world.ground_surface_y(sprite.global_position)
	if bottom - ground > FLOATING_TOLERANCE or ground - bottom > SUNKEN_TOLERANCE:
		found["floating_sprite"].append({"where": _where(world, sprite), "detail": "base %.2f m, ground %.2f m" % [bottom, ground]})
