extends SceneTree
## Independent alpha-shadow feasibility fixture; does not change park rendering.
## Run on a GPU display with an absolute, fresh SNAPLAND_SAVE_PATH.
## Results and raw captures are stored beside that isolated save.
## The 4096 atlas/24m camera/20m sun range are local test conditions, not
## evidence that the full island has the same shadow quality or frame rate.
var scene: Node3D
var camera: Camera3D
var light: DirectionalLight3D
var point_light: OmniLight3D
var point_mode := false
var caster: MeshInstance3D
var caster_material: StandardMaterial3D
var shadow_source: Sprite3D
var live_image: TextureRect
var live_texture_identity := 0
var folder := ""
var shape: Image
var reports: Array=[]
var pixel_size := 0.08
var feet_row := 28.0
var sample_start := Vector2i(2,6)
var sample_end := Vector2i(29,27)
var sample_step := 3
var boundary_radius := 1
var source_kind := "alpha-L"
func _initialize() -> void:
	var profile := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not profile.is_absolute_path() or DisplayServer.get_name()=="headless":quit(2);return
	folder=profile.get_base_dir();DirAccess.make_dir_recursive_absolute(folder)
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	RenderingServer.directional_shadow_atlas_set_size(256 if OS.get_cmdline_user_args().has("--low-resolution-negative") else 4096, true)
	scene=Node3D.new();root.add_child(scene)
	var world_env:=WorldEnvironment.new();var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("#325362")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=0.3
	world_env.environment=environment;scene.add_child(world_env)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(16,16);ground.mesh=plane;ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new();material.albedo_color=Color("#869481");material.roughness=1.0;ground.material_override=material;scene.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.far=24;scene.add_child(camera)
	camera.look_at_from_position(Vector3(6,8,10),Vector3(0,0,0),Vector3.UP);camera.current=true
	light=DirectionalLight3D.new();scene.add_child(light);light.look_at_from_position(Vector3(-4,8,4),Vector3.ZERO,Vector3.UP)
	light.shadow_enabled=true;light.shadow_blur=0.0;light.shadow_bias=0.0;light.shadow_normal_bias=0.0;light.directional_shadow_max_distance=20.0
	configure_shape()
	if OS.get_cmdline_user_args().has("--candidate"):
		# The hidden visible-pass source retains the same texture/pose API as an
		# island Sprite3D; layer masking, rather than hide(), keeps it observable
		# to the candidate while removing it from the diagnostic camera pass.
		camera.cull_mask=1
		shadow_source=Sprite3D.new()
		shadow_source.layers=2
		shadow_source.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if OS.get_cmdline_user_args().has("--live-texture"):
			var viewport := SubViewport.new()
			viewport.size=shape.get_size()
			viewport.transparent_bg=true
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			scene.add_child(viewport)
			live_image=TextureRect.new()
			live_image.texture=ImageTexture.create_from_image(shape)
			live_image.size=Vector2(shape.get_size())
			viewport.add_child(live_image)
			shadow_source.texture=viewport.get_texture()
			live_texture_identity=shadow_source.texture.get_instance_id()
		else:
			shadow_source.texture=ImageTexture.create_from_image(shape)
		shadow_source.pixel_size=pixel_size
		shadow_source.position.y=(feet_row-float(shape.get_height())*0.5)*pixel_size*camera.global_basis.y.y
		scene.add_child(shadow_source)
		caster=load("res://game/world/actor_shadow_silhouette.gd").new()
		scene.add_child(caster)
		caster.set("upright",OS.get_cmdline_user_args().has("--upright"))
		caster.call("configure",shadow_source,camera)
		caster_material=caster.get("silhouette_material")
		caster.set_process(false) # OFF/ON probes control visibility explicitly.
	else:
		caster=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(shape.get_size())*pixel_size;caster.mesh=quad
		caster_material=StandardMaterial3D.new();caster_material.albedo_texture=ImageTexture.create_from_image(shape)
		caster_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;caster_material.alpha_scissor_threshold=0.5
		caster_material.cull_mode=BaseMaterial3D.CULL_DISABLED;caster_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		caster.material_override=caster_material;caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		scene.add_child(caster);caster.global_basis=camera.global_basis
		caster.position.y=(feet_row-float(shape.get_height())*0.5)*pixel_size*camera.global_basis.y.y
	await frames(5)
	# Hiding disables casting without drawing a visible card in the baseline.
	caster.hide()
	await frames(4);var off:=await shot("off")
	caster.show()
	await frames(4);var on:=await shot("alpha-L")
	var result:=audit(off,on);result["case"]="correct_alpha";reports.append(result)
	var solid:=Image.create(shape.get_width(),shape.get_height(),false,Image.FORMAT_RGBA8);solid.fill(Color.WHITE);set_texture(ImageTexture.create_from_image(solid))
	await frames(4);var wrong:=await shot("opaque-card-negative")
	var negative:=audit(off,wrong);negative["case"]="opaque_card_negative";reports.append(negative)
	set_texture(ImageTexture.create_from_image(shape))
	if is_instance_valid(live_image):
		# Same source texture object, caster and light transform throughout L ->
		# full card -> L. A cached or snapshotted alpha silhouette must fail.
		await frames(4)
		var restored:=audit(off,await shot("live-restored-alpha"))
		restored["case"]="live_texture_restored"
		restored["same_texture_object"]=shadow_source.texture.get_instance_id()==live_texture_identity
		restored["pass"]=bool(restored.pass) and bool(restored.same_texture_object)
		reports.append(restored)
	light.look_at_from_position(Vector3(4,3,-8),Vector3.ZERO,Vector3.UP)
	caster.hide();await frames(4);var back_off:=await shot("back-off")
	caster.show();await frames(4);var back_on:=await shot("back-alpha")
	var back:=audit(back_off,back_on);back["case"]="back_light_alpha";reports.append(back)
	light.light_energy=0.0
	point_light=OmniLight3D.new();point_light.position=Vector3(-1.5,3,3);point_light.light_energy=2.4;point_light.omni_range=12.0
	point_light.shadow_enabled=true;point_light.shadow_blur=0.0;point_light.shadow_bias=0.0;point_light.shadow_normal_bias=0.0;scene.add_child(point_light);point_mode=true
	caster.hide();await frames(4);var point_off:=await shot("point-off")
	caster.show();await frames(4);var point_on:=await shot("point-alpha")
	var point_result:=audit(point_off,point_on);point_result["case"]="point_light_alpha";reports.append(point_result)
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	var live_pass := true
	for row in reports:
		if str(row.get("case",""))=="live_texture_restored":live_pass=bool(row.pass)
	if not bool(result.pass) or bool(negative.pass) or not bool(back.pass) or not bool(point_result.pass) or not live_pass:push_error("Alpha shadow projection or opaque-card negative failed");quit(1);return
	print("PASS: independent projected alpha silhouette shadow, transparent holes preserved and opaque-card negative rejected")
	quit()
func audit(off: Image,on: Image) -> Dictionary:
	var opaque:=0;var correct_opaque:=0;var empty:=0;var correct_empty:=0;var missed: Array=[]
	# Source-space alpha is the oracle. Project pixel centers along the actual
	# light ray, independent of the shadow-map image being tested.
	var ray: Vector3=-light.global_basis.z
	for y in range(sample_start.y,sample_end.y,sample_step):
		for x in range(sample_start.x,sample_end.x,sample_step):
			var expected:=shape.get_pixel(x,y).a>0.5
			var boundary:=false
			for dy in range(-boundary_radius,boundary_radius+1):
				for dx in range(-boundary_radius,boundary_radius+1):
					if (shape.get_pixel(x+dx,y+dy).a>0.5)!=expected:boundary=true
			if boundary:continue
			var point: Vector3=caster.global_transform*Vector3((float(x)+0.5-float(shape.get_width())*0.5)*pixel_size,(float(shape.get_height())*0.5-float(y)-0.5)*pixel_size,0)
			var sample_ray: Vector3=(point-point_light.global_position).normalized() if point_mode else ray
			var floor_point: Vector3=point-sample_ray*(point.y/sample_ray.y)
			var screen: Vector2=camera.unproject_position(floor_point)
			# Viewport coordinates describe pixel boundaries; image index i samples
			# center i+0.5. Rounding first shifts the read by up to a whole pixel.
			var pixel:=Vector2i(floori(screen.x),floori(screen.y))
			if not Rect2i(0,0,1280,720).has_point(pixel):continue
			var dark: bool=off.get_pixelv(pixel).get_luminance()-on.get_pixelv(pixel).get_luminance()>0.04
			if expected!=dark:missed.append([x,y,expected,off.get_pixelv(pixel).get_luminance()-on.get_pixelv(pixel).get_luminance()])
			if expected:opaque+=1;correct_opaque+=1 if dark else 0
			else:empty+=1;correct_empty+=0 if dark else 1
	return {"source_kind":source_kind,"missed":missed,"opaque":opaque,"opaque_correct":correct_opaque,"empty":empty,"empty_correct":correct_empty,"pass":opaque>=8 and empty>=8 and correct_opaque>=opaque*0.85 and correct_empty>=empty*0.85}
func frames(count: int) -> void:
	for index in count:await process_frame
func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.save_png(folder.path_join(label+".png"));return image

func configure_shape() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--character"):
		shape=Image.create(32,32,false,Image.FORMAT_RGBA8)
		shape.fill(Color.TRANSPARENT)
		shape.fill_rect(Rect2i(3,4,6,24),Color.WHITE)
		shape.fill_rect(Rect2i(3,22,22,6),Color.WHITE)
		return
	# Final static renderer composition, including original body, garment and
	# rigid hair/hat. This does not exercise the dynamic hair SubViewport.
	var renderer = load("res://game/world/avatar_renderer.gd").new()
	var outfit := "outfit-rainvest" if args.has("--rainvest") else "outfit-tide"
	var hat := "hat-straw" if args.has("--hat") else "hat-none"
	var action := "wave" if args.has("--wave") else "idle"
	shape=renderer.texture(renderer.DEFAULT_APPEARANCE,{"outfit":outfit,"hat":hat},"front",0,action).get_image()
	shape.save_png(folder.path_join("source.png"))
	source_kind="%s/%s/%s/front/0"%[outfit,hat,action]
	pixel_size=2.4/360.0
	feet_row=346.0
	sample_start=Vector2i(12,20)
	sample_end=Vector2i(269,337)
	sample_step=12
	boundary_radius=4

func set_texture(texture: Texture2D) -> void:
	if is_instance_valid(live_image):
		live_image.texture=texture
	elif is_instance_valid(shadow_source):
		shadow_source.texture=texture
		caster.call("sync_pose")
	else:
		caster_material.albedo_texture=texture
