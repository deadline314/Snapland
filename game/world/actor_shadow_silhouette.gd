extends MeshInstance3D
## Camera-invisible alpha caster. Orient to the scene camera explicitly: a
## billboard shader using INV_VIEW_MATRIX would face the light's shadow camera.
## No pixel readback is needed, including when the final texture is a hair rig's
## live SubViewport output. The original sprite remains the sole pose owner.
## Actors re-pose every frame; painted scenery uses configure_static() and
## face_light(), which never process.
var source: Sprite3D
var upright := false
var scene_camera: Camera3D
var fallback_volumes: Array[GeometryInstance3D] = []
var silhouette_material := StandardMaterial3D.new()
var silhouette_quad := QuadMesh.new()

func _init() -> void:
	name = "ActorAlphaShadow"
	mesh = silhouette_quad
	material_override = silhouette_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	silhouette_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	silhouette_material.alpha_scissor_threshold = 0.5
	silhouette_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	silhouette_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Pose updates happen in the world's physics step and hair's normal process.
	process_priority = 100

func configure(sprite: Sprite3D, camera: Camera3D, fallback: Array[GeometryInstance3D] = []) -> void:
	source = sprite
	scene_camera = camera
	fallback_volumes = fallback
	refresh()

func _process(_delta: float) -> void:
	refresh()

## Static scenery: read the sprite's art once and stand a `height`-metre card
## on `base` (parent space). Kinds that share art may share one material.
func configure_static(sprite: Sprite3D, base: Vector3, height: float, shared_material: StandardMaterial3D = null) -> bool:
	source = sprite
	set_process(false)
	if shared_material != null:
		silhouette_material = shared_material
		material_override = shared_material
	if not _sync_source_art():
		_set_caster_visible(false)
		return false
	silhouette_quad.size = Vector2(silhouette_quad.size.x, height)
	position = base + Vector3.UP * height * 0.5
	return true

## Turn a static card to face the light so the cast shape keeps the painted
## silhouette at every time of day. `keep_right` stops the shadow mirroring.
func face_light(light_travel: Vector3, keep_right: Vector3) -> void:
	var flat := Vector3(light_travel.x, 0.0, light_travel.z)
	if flat.length_squared() < 0.0001: return
	var right := flat.normalized().cross(Vector3.UP)
	if right.dot(keep_right) < 0.0: right = -right
	basis = Basis(right, Vector3.UP, right.cross(Vector3.UP))

func refresh() -> bool:
	var supported := sync_pose()
	var show_fallback := not supported and is_instance_valid(source) and source.is_inside_tree() and source.is_visible_in_tree()
	for volume in fallback_volumes:
		if is_instance_valid(volume) and volume.visible != show_fallback:
			volume.visible = show_fallback
	return supported

func _set_caster_visible(value: bool) -> void:
	if visible != value:
		visible = value

func sync_pose() -> bool:
	if not is_instance_valid(source) or not is_instance_valid(scene_camera) or not is_inside_tree() or not source.is_inside_tree() or not scene_camera.is_inside_tree():
		_set_caster_visible(false)
		return false
	if not _sync_source_art():
		_set_caster_visible(false)
		return false
	var cell := silhouette_quad.size / source.pixel_size
	var center := source.offset
	if not source.centered: center += cell * 0.5
	var camera_basis := scene_camera.global_basis.orthonormalized().scaled(source.global_basis.get_scale())
	if upright:
		# Full billboards tilt toward the scene camera: their foot pixels also
		# move in ground depth. A physical cast silhouette must stand vertically
		# over the actor, retaining the visible sprite's world-space Y extent.
		var camera_right := scene_camera.global_basis.x
		var right := Vector3(camera_right.x, 0.0, camera_right.z).normalized()
		var vertical_scale := scene_camera.global_basis.y.normalized().y
		if right.length_squared() < 0.5 or vertical_scale < 0.05:
			_set_caster_visible(false)
			return false
		camera_basis = Basis(right, Vector3.UP * vertical_scale, right.cross(Vector3.UP)).scaled(source.global_basis.get_scale())
	var target_transform := Transform3D(camera_basis, source.global_position + camera_basis * Vector3(center.x, -center.y, 0.0) * source.pixel_size)
	# Resolve the current global pose because the caster's parent can move independently.
	if not global_transform.is_equal_approx(target_transform):
		global_transform = target_transform
	_set_caster_visible(source.is_visible_in_tree())
	return true

## Point the caster's material and quad at the sprite's current frame. Returns
## false for layouts whose texture coordinates cannot be derived safely.
func _sync_source_art() -> bool:
	if not is_instance_valid(source): return false
	var texture := source.texture
	if texture == null or source.axis != Vector3.AXIS_Z or source.fixed_size or source.pixel_size <= 0.0:
		return false
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		# A margin adds transparent padding; do not guess its texture coordinates.
		if atlas.atlas == null or atlas.atlas is AtlasTexture or atlas.margin != Rect2():
			return false
		region = atlas.region
		if region.size == Vector2.ZERO: region.size = atlas.atlas.get_size()
		texture = atlas.atlas
	if source.region_enabled:
		region = Rect2(region.position + source.region_rect.position, source.region_rect.size)
	var cell := region.size / Vector2(source.hframes, source.vframes)
	region.position += Vector2(source.frame_coords) * cell
	region.size = cell
	var dimensions := texture.get_size()
	if dimensions.x <= 0.0 or dimensions.y <= 0.0 or cell.x <= 0.0 or cell.y <= 0.0 or not Rect2(Vector2.ZERO, dimensions).encloses(region):
		return false
	var uv_scale := cell / dimensions
	var uv_offset := region.position / dimensions
	if source.flip_h:
		uv_offset.x += uv_scale.x
		uv_scale.x = -uv_scale.x
	if source.flip_v:
		uv_offset.y += uv_scale.y
		uv_scale.y = -uv_scale.y
	if silhouette_material.albedo_texture != texture:
		silhouette_material.albedo_texture = texture
	var material_scale := Vector3(uv_scale.x, uv_scale.y, 1.0)
	if silhouette_material.uv1_scale != material_scale:
		silhouette_material.uv1_scale = material_scale
	var material_offset := Vector3(uv_offset.x, uv_offset.y, 0.0)
	if silhouette_material.uv1_offset != material_offset:
		silhouette_material.uv1_offset = material_offset
	var quad_size := cell * source.pixel_size
	if silhouette_quad.size != quad_size:
		silhouette_quad.size = quad_size
	return true
