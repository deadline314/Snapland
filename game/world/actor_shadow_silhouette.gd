extends MeshInstance3D
## Camera-invisible alpha caster. Orient to the scene camera explicitly: a
## billboard shader using INV_VIEW_MATRIX would face the light's shadow camera.
## No pixel readback is needed, including when the final texture is a hair rig's
## live SubViewport output. The original sprite remains the sole pose owner.
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

func refresh() -> bool:
	var supported := sync_pose()
	for volume in fallback_volumes:
		if is_instance_valid(volume):
			volume.visible = not supported and is_instance_valid(source) and source.is_inside_tree() and source.is_visible_in_tree()
	return supported

func sync_pose() -> bool:
	if not is_instance_valid(source) or not is_instance_valid(scene_camera) or not is_inside_tree() or not source.is_inside_tree() or not scene_camera.is_inside_tree():
		hide()
		return false
	var texture := source.texture
	if texture == null or source.axis != Vector3.AXIS_Z or source.fixed_size or source.pixel_size <= 0.0:
		hide()
		return false
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		# A margin adds transparent padding; do not guess its texture coordinates.
		if atlas.atlas == null or atlas.atlas is AtlasTexture or atlas.margin != Rect2():
			hide()
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
		hide()
		return false
	var uv_scale := cell / dimensions
	var uv_offset := region.position / dimensions
	if source.flip_h:
		uv_offset.x += uv_scale.x
		uv_scale.x = -uv_scale.x
	if source.flip_v:
		uv_offset.y += uv_scale.y
		uv_scale.y = -uv_scale.y
	silhouette_material.albedo_texture = texture
	silhouette_material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	silhouette_material.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0.0)
	silhouette_quad.size = cell * source.pixel_size
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
			hide()
			return false
		camera_basis = Basis(right, Vector3.UP * vertical_scale, right.cross(Vector3.UP)).scaled(source.global_basis.get_scale())
	global_transform = Transform3D(camera_basis, source.global_position + camera_basis * Vector3(center.x, -center.y, 0.0) * source.pixel_size)
	visible = source.is_visible_in_tree()
	return true
