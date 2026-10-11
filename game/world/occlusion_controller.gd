extends Node
## Screen-space building cutaway driven by a low-frequency physics visibility ray.

const OccluderShader := preload("res://game/world/occluder.gdshader")
const RAY_COLLISION_LAYER := 1 << 5
const SAMPLE_INTERVAL := 0.08
const FADE_SECONDS := 0.15

var player: Node3D
var camera: Camera3D
var reduced_motion := false
var _shader_material: ShaderMaterial
var _ray_query: PhysicsRayQueryParameters3D
var _ray_exclusions: Array[RID] = []
var _building_groups: Array[Dictionary] = []
var _collider_to_group: Dictionary = {}
var _capture_active := false
var _capture_geometry: Array[GeometryInstance3D] = []
var _capture_originals: Dictionary = {}
var _capture_labels: Array[Label3D] = []
var _capture_label_originals: Dictionary = {}
var _active_group_ids: Dictionary = {}
var _active_group_id := 0
var _next_group_id := 1
var _fade_weight := 0.0
var _sample_elapsed := 0.0
var _ray_samples := 0
var _last_center_px := Vector2.ZERO
var _last_radius_px := 0.0
var _last_viewport_size := Vector2.ONE


func _ready() -> void:
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = OccluderShader
	_shader_material.set_shader_parameter("cutaway_weight", 0.0)


func _exit_tree() -> void:
	release()


func configure(target_player: Node3D, target_camera: Camera3D) -> void:
	player = target_player
	camera = target_camera
	var from := Vector3.ZERO
	var to := Vector3(0.0, 0.0, -1.0)
	_ray_query = PhysicsRayQueryParameters3D.create(from, to, RAY_COLLISION_LAYER)
	_ray_query.collide_with_areas = false
	_ray_query.collide_with_bodies = true
	_ray_query.exclude = [player.get_rid()] if player is CollisionObject3D else []


func begin_building() -> void:
	if _capture_active:
		push_warning("OcclusionController: nested building registration ignored")
		return
	_capture_active = true
	_capture_geometry.clear()
	_capture_labels.clear()
	_capture_label_originals.clear()


func register_geometry(target: GeometryInstance3D, source_material: Material) -> void:
	if not _capture_active or not is_instance_valid(target):
		return
	if not source_material is StandardMaterial3D:
		push_warning("OcclusionController: unsupported building material on %s; preserving it without cutaway" % target.get_path())
		return
	var standard := source_material as StandardMaterial3D
	_capture_originals[target.get_instance_id()] = target.material_override if target.material_override != null else source_material
	target.material_override = _shader_material
	target.set_instance_shader_parameter("occluder_tint", Color.WHITE if standard.vertex_color_use_as_albedo else standard.albedo_color)
	target.set_instance_shader_parameter("occluder_roughness", standard.roughness)
	_capture_geometry.append(target)


func register_visibility_label(target: Label3D) -> void:
	if not _capture_active or not is_instance_valid(target):
		return
	var label_id := target.get_instance_id()
	_capture_label_originals[label_id] = {"visible": target.visible, "modulate": target.modulate}
	_capture_labels.append(target)


func finish_building(blocker: CollisionObject3D) -> bool:
	if not _capture_active:
		return false
	_capture_active = false
	if not is_instance_valid(blocker) or _capture_geometry.is_empty():
		_restore_capture()
		return false
	var group_id := _next_group_id
	_next_group_id += 1
	var original_layer := blocker.collision_layer
	blocker.collision_layer |= RAY_COLLISION_LAYER
	var ray_body := _create_ray_geometry(blocker, _capture_geometry)
	var group := {"id": group_id, "blocker": blocker, "ray_body": ray_body, "geometry": _capture_geometry.duplicate(), "originals": _capture_originals.duplicate(), "labels": _capture_labels.duplicate(), "label_originals": _capture_label_originals.duplicate(), "original_layer": original_layer}
	_building_groups.append(group)
	_collider_to_group[blocker.get_instance_id()] = group_id
	blocker.tree_exiting.connect(_on_group_tree_exiting.bind(group_id), CONNECT_ONE_SHOT)
	if is_instance_valid(ray_body):
		_collider_to_group[ray_body.get_instance_id()] = group_id
	for geometry in group.geometry:
		if is_instance_valid(geometry):
			geometry.tree_exiting.connect(_on_geometry_tree_exiting.bind(group_id, geometry.get_instance_id()), CONNECT_ONE_SHOT)
	for label in group.labels:
		if is_instance_valid(label):
			label.tree_exiting.connect(_on_label_tree_exiting.bind(group_id, label.get_instance_id()), CONNECT_ONE_SHOT)
	_capture_geometry.clear()
	_capture_originals.clear()
	_capture_labels.clear()
	_capture_label_originals.clear()
	return true


func refresh_visibility() -> void:
	_ray_samples += 1
	_active_group_id = 0
	_active_group_ids.clear()
	if not is_instance_valid(player) or not is_instance_valid(camera) or _ray_query == null:
		return
	var body_point := player.global_position + Vector3.UP * 1.0
	var screen_point := camera.unproject_position(body_point)
	var ray_from := camera.project_ray_origin(screen_point)
	var ray_direction := camera.project_ray_normal(screen_point).normalized()
	var ray_length := ray_direction.dot(body_point - ray_from)
	if ray_length <= 0.05:
		return
	_ray_query.from = ray_from
	_ray_query.to = ray_from + ray_direction * (ray_length - 0.025)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	_ray_exclusions.clear()
	if player is CollisionObject3D:
		_ray_exclusions.append(player.get_rid())
	for hit_index in range(4):
		_ray_query.exclude = _ray_exclusions
		var hit: Dictionary = space.intersect_ray(_ray_query)
		if hit.is_empty():
			break
		var collider := hit.get("collider") as CollisionObject3D
		if not is_instance_valid(collider):
			break
		var group_id := int(_collider_to_group.get(collider.get_instance_id(), 0))
		if group_id != 0:
			_active_group_ids[group_id] = true
			if _active_group_id == 0:
				_active_group_id = group_id
		_ray_exclusions.append(collider.get_rid())


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if reduced_motion:
		_fade_weight = 1.0 if not _active_group_ids.is_empty() else 0.0
		var player_depth := 0.0
		if is_instance_valid(player) and is_instance_valid(camera):
			player_depth = maxf(0.0, -camera.to_local(player.global_position + Vector3.UP).z)
		_update_shader_uniforms(player_depth)
		_refresh_registered_labels()
		return
	_sample_elapsed = SAMPLE_INTERVAL


func statistics() -> Dictionary:
	return {
		"registered_buildings": _building_groups.size(),
		"registered_geometry": _count_geometry(),
		"active": not _active_group_ids.is_empty(),
		"active_group_id": _active_group_id,
		"active_groups": _active_group_ids.size(),
		"fade_weight": _fade_weight,
		"ray_samples": _ray_samples,
		"ray_mask": RAY_COLLISION_LAYER,
		"center_px": _last_center_px,
		"radius_px": _last_radius_px,
		"viewport_size": _last_viewport_size,
	}


func release() -> void:
	for group in _building_groups:
		_restore_group(group)
	_capture_active = false
	_capture_geometry.clear()
	_capture_originals.clear()
	_restore_capture_labels()
	_building_groups.clear()
	_collider_to_group.clear()
	_active_group_ids.clear()
	_active_group_id = 0
	_fade_weight = 0.0
	player = null
	camera = null
	_ray_query = null
	_ray_exclusions.clear()


func _physics_process(delta: float) -> void:
	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL:
		_sample_elapsed = fposmod(_sample_elapsed, SAMPLE_INTERVAL)
		refresh_visibility()


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := Vector2(viewport.get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var body_point := player.global_position + Vector3.UP * 1.0
	var center := camera.unproject_position(body_point)
	var feet := camera.unproject_position(player.global_position)
	var head := camera.unproject_position(player.global_position + Vector3.UP * 1.9)
	var projected_height := feet.distance_to(head)
	var radius := clampf(projected_height * 0.48, 24.0, 84.0)
	var camera_space_body := camera.to_local(body_point)
	var player_depth := maxf(0.0, -camera_space_body.z)
	var target_weight := 1.0 if not _active_group_ids.is_empty() else 0.0
	if reduced_motion:
		_fade_weight = target_weight
	else:
		_fade_weight = move_toward(_fade_weight, target_weight, delta / FADE_SECONDS)
	_last_center_px = center
	_last_radius_px = radius
	_last_viewport_size = viewport_size
	_update_shader_uniforms(player_depth)
	_refresh_registered_labels()


func _update_shader_uniforms(player_depth: float) -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("viewport_size_px", _last_viewport_size)
	_shader_material.set_shader_parameter("body_center_px", _last_center_px)
	_shader_material.set_shader_parameter("body_radius_px", _last_radius_px)
	_shader_material.set_shader_parameter("player_view_depth", player_depth)
	_shader_material.set_shader_parameter("cutaway_weight", _fade_weight)


func _count_geometry() -> int:
	var count := 0
	for group in _building_groups:
		for geometry in group.geometry:
			if is_instance_valid(geometry):
				count += 1
	return count


func _restore_capture() -> void:
	for geometry in _capture_geometry:
		if is_instance_valid(geometry) and geometry.material_override == _shader_material:
			geometry.material_override = _capture_originals.get(geometry.get_instance_id())
	_capture_geometry.clear()
	_capture_originals.clear()
	_restore_capture_labels()


func _restore_capture_labels() -> void:
	for label in _capture_labels:
		if is_instance_valid(label):
			var original: Dictionary = _capture_label_originals.get(label.get_instance_id(), {})
			if not original.is_empty():
				label.visible = bool(original.get("visible", true))
				label.modulate = original.get("modulate", Color.WHITE)
	_capture_labels.clear()
	_capture_label_originals.clear()


func _refresh_registered_labels() -> void:
	var has_cutaway := not _active_group_ids.is_empty() and _fade_weight > 0.0001
	for group in _building_groups:
		var labels: Array = group.labels
		var originals: Dictionary = group.label_originals
		for label in labels:
			if not is_instance_valid(label):
				continue
			var original: Dictionary = originals.get(label.get_instance_id(), {})
			if original.is_empty():
				continue
			label.visible = bool(original.get("visible", true)) and not (has_cutaway and _label_overlaps_mask(label))
			label.modulate = original.get("modulate", Color.WHITE)


func _label_overlaps_mask(label: Label3D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(camera) or _last_radius_px <= 0.0:
		return false
	var label_center := label.global_position
	if -camera.to_local(label_center).z >= -camera.to_local(player.global_position + Vector3.UP).z:
		return false
	var bounds := label.get_aabb()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return camera.unproject_position(label_center).distance_to(_last_center_px) <= _last_radius_px
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner_index in range(8):
		var corner := bounds.position + Vector3(
			bounds.size.x if corner_index & 1 else 0.0,
			bounds.size.y if corner_index & 2 else 0.0,
			bounds.size.z if corner_index & 4 else 0.0
		)
		var world_corner: Vector3 = label.global_transform * corner
		var screen_corner := camera.unproject_position(world_corner)
		minimum = minimum.min(screen_corner)
		maximum = maximum.max(screen_corner)
	var closest := Vector2(clampf(_last_center_px.x, minimum.x, maximum.x), clampf(_last_center_px.y, minimum.y, maximum.y))
	return closest.distance_to(_last_center_px) <= _last_radius_px


func _create_ray_geometry(blocker: CollisionObject3D, geometry_list: Array[GeometryInstance3D]) -> StaticBody3D:
	var ray_body := StaticBody3D.new()
	ray_body.name = "BuildingOcclusionRayBody"
	ray_body.collision_layer = RAY_COLLISION_LAYER
	ray_body.collision_mask = 0
	blocker.add_child(ray_body)
	for geometry in geometry_list:
		if not is_instance_valid(geometry):
			continue
		var shape := BoxShape3D.new()
		var local_to_blocker := blocker.global_transform.affine_inverse() * geometry.global_transform
		var box_mesh := geometry as MeshInstance3D
		if box_mesh != null and box_mesh.mesh is BoxMesh:
			shape.size = (box_mesh.mesh as BoxMesh).size
		elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
			var bounds := (geometry as MultiMeshInstance3D).multimesh.get_aabb()
			if bounds.has_volume():
				shape.size = bounds.size
				local_to_blocker *= Transform3D(Basis.IDENTITY, bounds.get_center())
			else:
				continue
		else:
			continue
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = local_to_blocker
		ray_body.add_child(collision)
	return ray_body


func _on_geometry_tree_exiting(group_id: int, geometry_id: int) -> void:
	for group_index in range(_building_groups.size() - 1, -1, -1):
		var group: Dictionary = _building_groups[group_index]
		if int(group.id) != group_id:
			continue
		var geometry: Array = group.geometry
		for index in range(geometry.size() - 1, -1, -1):
			var item: GeometryInstance3D = geometry[index]
			if item == null or item.get_instance_id() == geometry_id:
				geometry.remove_at(index)
		group.geometry = geometry
		if geometry.is_empty():
			_remove_group_at(group_index)
		return


func _on_label_tree_exiting(group_id: int, label_id: int) -> void:
	for group in _building_groups:
		if int(group.id) != group_id:
			continue
		var labels: Array = group.labels
		for index in range(labels.size() - 1, -1, -1):
			var item: Label3D = labels[index]
			if item == null or item.get_instance_id() == label_id:
				labels.remove_at(index)
		group.labels = labels
		group.label_originals.erase(label_id)
		return


func _on_group_tree_exiting(group_id: int) -> void:
	for group_index in range(_building_groups.size() - 1, -1, -1):
		if int(_building_groups[group_index].id) == group_id:
			_remove_group_at(group_index)
			return


func _remove_group_at(group_index: int) -> void:
	var group: Dictionary = _building_groups[group_index]
	var blocker: CollisionObject3D = group.blocker
	if is_instance_valid(blocker):
		_collider_to_group.erase(blocker.get_instance_id())
		blocker.collision_layer = int(group.original_layer)
	var group_id := int(group.id)
	_active_group_ids.erase(group_id)
	if group_id == _active_group_id:
		_active_group_id = int(_active_group_ids.keys()[0]) if not _active_group_ids.is_empty() else 0
	_restore_group(group)
	_building_groups.remove_at(group_index)


func _restore_group(group: Dictionary) -> void:
	var blocker: CollisionObject3D = group.blocker
	if is_instance_valid(blocker):
		blocker.collision_layer = int(group.original_layer)
	var ray_body: CollisionObject3D = group.ray_body
	if is_instance_valid(ray_body):
		ray_body.collision_layer = 0
	for geometry in group.geometry:
		if is_instance_valid(geometry) and geometry.material_override == _shader_material:
			geometry.material_override = group.originals.get(geometry.get_instance_id())
	for label in group.labels:
		if is_instance_valid(label):
			var original: Dictionary = group.label_originals.get(label.get_instance_id(), {})
			if not original.is_empty():
				label.visible = bool(original.get("visible", true))
				label.modulate = original.get("modulate", Color.WHITE)
