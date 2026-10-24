extends SceneTree
const Silhouette = preload("res://game/world/actor_shadow_silhouette.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): quit(2);return
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.rotation = Vector3(-0.6,0.3,0.0)
	var source := Sprite3D.new()
	var pixels := Image.create(8,4,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var original := pixels.get_data()
	var texture := ImageTexture.create_from_image(pixels)
	source.texture=texture
	source.position=Vector3(2,3,4)
	source.scale=Vector3(2,1.5,1)
	source.pixel_size=0.25
	source.hframes=2
	source.frame=1
	source.centered=false
	source.offset=Vector2(2,3)
	scene.add_child(source)
	var shadow := Silhouette.new()
	scene.add_child(shadow)
	var fallback := MeshInstance3D.new()
	fallback.mesh=BoxMesh.new()
	fallback.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	scene.add_child(fallback)
	var fallback_list: Array[GeometryInstance3D] = [fallback]
	shadow.configure(source,camera,fallback_list)
	check(not fallback.visible,"Supported alpha silhouette must disable coarse fallback")
	check(shadow.sync_pose(),"Valid sprite pose was rejected")
	check(shadow.silhouette_quad.size.is_equal_approx(Vector2(1,1)),"Frame subdivision must define world quad size")
	check(shadow.silhouette_material.uv1_scale.is_equal_approx(Vector3(0.5,1,1)),"Shadow sampled the complete sheet instead of its frame")
	check(shadow.silhouette_material.uv1_offset.is_equal_approx(Vector3(0.5,0,0)),"Shadow sampled the wrong frame")
	var expected_basis := camera.global_basis.orthonormalized().scaled(Vector3(2,1.5,1))
	var expected_center := Vector3(2,3,4) + expected_basis * Vector3(1,-1.25,0)
	check(shadow.global_position.is_equal_approx(expected_center),"Camera basis, source scale, offset or uncentered frame moved the caster")
	check(shadow.global_basis.is_equal_approx(expected_basis),"Shadow must face the scene camera, not a light camera")
	source.flip_h=true;source.flip_v=true;shadow.sync_pose()
	check(shadow.silhouette_material.uv1_scale.is_equal_approx(Vector3(-0.5,-1,1)) and shadow.silhouette_material.uv1_offset.is_equal_approx(Vector3(1,1,0)),"Flipping must stay inside the selected frame")
	shadow.upright=true
	check(shadow.sync_pose(),"Upright source was rejected")
	var upright_up := Vector3.UP * 1.5 * camera.global_basis.y.normalized().y
	check(shadow.global_basis.y.is_equal_approx(upright_up),"Upright cast plane must preserve visible world Y extent without camera-depth foot drift")
	check(is_zero_approx(shadow.global_basis.x.y) and is_zero_approx(shadow.global_basis.z.y),"Upright shadow must keep horizontal axes on the ground plane")
	shadow.upright=false
	var atlas := AtlasTexture.new()
	atlas.atlas=texture;atlas.region=Rect2(2,1,4,2)
	source.texture=atlas;source.hframes=1;source.frame=0;source.flip_h=false;source.flip_v=false
	source.centered=true;source.offset=Vector2.ZERO
	check(shadow.sync_pose(),"A valid atlas region was rejected")
	check(shadow.silhouette_material.albedo_texture==texture,"3D material must sample the underlying atlas texture")
	check(shadow.silhouette_material.uv1_offset.is_equal_approx(Vector3(0.25,0.25,0)) and shadow.silhouette_material.uv1_scale.is_equal_approx(Vector3(0.5,0.5,1)),"Atlas shadow sampled neighboring cells")
	source.region_enabled=true;source.region_rect=Rect2(1,0,2,2)
	check(shadow.sync_pose(),"Valid source region was rejected")
	check(shadow.silhouette_material.uv1_offset.is_equal_approx(Vector3(0.375,0.25,0)) and shadow.silhouette_quad.size.is_equal_approx(Vector2(0.5,0.5)),"Source region must resolve inside the atlas region")
	atlas.margin=Rect2(1,1,1,1)
	check(not shadow.refresh() and not shadow.visible and fallback.visible,"An unsupported padded atlas must select only the coarse fallback")
	atlas.margin=Rect2();source.region_enabled=false
	var viewport := SubViewport.new()
	viewport.size=Vector2i(32,32);scene.add_child(viewport)
	var live_texture := viewport.get_texture()
	source.texture=live_texture
	check(shadow.refresh() and not fallback.visible and shadow.silhouette_material.albedo_texture==live_texture,"Live hair texture must retain its identity without pixel readback or a stale snapshot")
	source.hide();shadow.refresh()
	check(not shadow.visible and not fallback.visible,"Hidden source must not leave a cast silhouette")
	source.show();shadow.refresh()
	check(shadow.visible,"Visible source must restore its silhouette")
	check(shadow.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and shadow.get_child_count()==0,"Caster must be camera-invisible and introduce no child collision geometry")
	check(source.position==Vector3(2,3,4) and source.texture==live_texture and texture.get_image().get_data()==original,"Shadow synchronization must not mutate the source pose or pixels")
	scene.remove_child(source)
	check(not shadow.refresh() and not shadow.visible and not fallback.visible,"Detached actor must not query an invalid world transform or leave a stale caster")
	scene.add_child(source)
	check(shadow.refresh() and shadow.visible,"Reattached actor must restore its silhouette")
	scene.remove_child(camera)
	check(not shadow.refresh() and fallback.visible,"Detached camera must select the safe fallback without querying its world transform")
	scene.add_child(camera)
	check(shadow.refresh() and not fallback.visible,"Reattached camera must restore the composed silhouette")
	source.free()
	check(not shadow.refresh() and not shadow.visible and not fallback.visible,"Released actor must not leave a visible stale caster")
	scene.queue_free()
	for index in 4:await process_frame
	if failures==0:print("PASS: actor alpha caster preserves pose, frame, atlas, flips and live texture identity without source mutation")
	quit(1 if failures else 0)
