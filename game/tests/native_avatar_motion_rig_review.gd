extends Node3D
const Rig = preload("res://game/world/avatar_motion_rig.gd")
const TestSaveGuard = preload("res://game/core/test_save_guard.gd")
const CAPTURE_DIR_ENV := "SNAPLAND_NATIVE_CAPTURE_DIR"
const CAPTURE_FLAGS := ["--capture-motion-rig", "--idle-motion-rig", "--capture-idle-frames"]
var rig
var camera: Camera3D
var label: Label
var paused := false
var quarter := false
var run := false
var automatic := true
var elapsed := 0.0
var speed_multiplier := 1.0
var direction_index := 2
var hair_index := 0
var species_index := 0
var review_kind := "interactive"
var world_camera := true
var environment_settings: Environment
var key_light: DirectionalLight3D
var night := false
var occluder: Node3D
var wall_mode := 0
var capture_dir := ""

func _ready() -> void:
	if _native_capture_requested():
		var capture_error := _prepare_capture_directory()
		if not capture_error.is_empty():
			push_error("Native avatar motion review refused: " + capture_error)
			get_tree().quit(1)
			return
	rig = Rig.new()
	add_child(rig)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#41434a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.4
	environment_settings = settings
	environment.environment = settings
	add_child(environment)
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45,-25,0)
	key_light.light_energy = 1.0
	add_child(key_light)
	occluder = Node3D.new()
	add_child(occluder)
	for index in range(3):
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9 if index<2 else 0.7,3.0,0.1)
		block.mesh = box
		block.position = Vector3((-0.8 if index==0 else 0.8) if index<2 else 0,1.5,0)
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_color = Color("#355967")
		block.material_override = wall_material
		occluder.add_child(block)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(200,200)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#727578")
	plane.material_override = material
	add_child(plane)
	camera = Camera3D.new()
	camera.fov = 35
	add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	label = Label.new()
	label.position = Vector2(24,20)
	overlay.add_child(label)
	quarter = OS.get_cmdline_user_args().has("--quarter-motion-rig")
	world_camera = not OS.get_cmdline_user_args().has("--portrait-motion-rig")
	wall_mode = 2 if OS.get_cmdline_user_args().has("--occlusion-motion-rig") else 0
	_update_camera()
	if OS.get_cmdline_user_args().has("--idle-motion-rig"):
		call_deferred("_idle_review")
	elif OS.get_cmdline_user_args().has("--capture-motion-rig"):
		call_deferred("_capture")

func _process(delta: float) -> void:
	if not paused:
		var step: float = delta*(0.25 if quarter else 1)
		elapsed += step
		if automatic: run = int(elapsed/4.0)%2==1
		rig.advance(step,(2.0 if run else 0.55)*speed_multiplier,run)
	_update_camera()
	label.text = "WORLD-SPACE SOURCE RIG CANDIDATE / %s / %s / %.2f units/s\nSpace pause | Q quarter | C camera | L day/night | W wall/opening | arrows direction | M walk/run | +/- speed | 0 stop | H hair | S species\nValid: %d/8; fallback is not full animation coverage\n%s" % [rig.direction,"run" if run else "walk",rig.speed,rig.source_records.values().filter(func(row):return row.valid).size(),review_kind+" / "+("WORLD" if world_camera else "PORTRAIT")+" / "+("NIGHT" if night else "DAY")+" / wall "+str(wall_mode)+" / distance %.3f m / phase %.3f / time x%.2f\n" % [rig.travel,fposmod(rig.travel/rig.gait_cycle_distance(run),1.0),0.25 if quarter else 1.0]+"\n".join(rig.diagnostics)]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: paused = not paused
		KEY_Q: quarter = not quarter
		KEY_C: world_camera = not world_camera; rig.cancel_motion()
		KEY_L: night = not night
		KEY_W: wall_mode = (wall_mode+1)%3
		KEY_LEFT: direction_index = posmod(direction_index-1,8); rig.set_direction(Rig.DIRECTIONS[direction_index])
		KEY_RIGHT: direction_index = (direction_index+1)%8; rig.set_direction(Rig.DIRECTIONS[direction_index])
		KEY_M: automatic = false; run = not run
		KEY_PLUS,KEY_EQUAL: speed_multiplier = minf(1.5,speed_multiplier+0.1)
		KEY_MINUS: speed_multiplier = maxf(0.1,speed_multiplier-0.1)
		KEY_0: automatic = false; speed_multiplier = 0
		KEY_H:
			hair_index = (hair_index+1)%3
			rig.appearance.hair = ["windswept","bob","curly"][hair_index]
			rig.set_appearance(rig.appearance)
		KEY_S:
			species_index = (species_index+1)%3
			rig.appearance.species = ["human","elf","imp"][species_index]
			rig.set_appearance(rig.appearance)

func _update_camera() -> void:
	if world_camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.6
		camera.position = rig.position+Vector3(3.5,16.5,25)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = rig.position+Vector3(0,1.75,4.8)
	camera.look_at(rig.position+Vector3(0,1.0,0))
	rig.projection_basis = camera.global_basis
	rig.boot_yaw = atan2(camera.global_basis.z.x,camera.global_basis.z.z)
	key_light.light_energy = 0.2 if night else 1.0
	key_light.light_color = Color("#a8bbff") if night else Color("#fff2da")
	environment_settings.ambient_light_energy = 0.14 if night else 0.4
	occluder.position = rig.position+Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()*0.8
	occluder.rotation.y = rig.boot_yaw
	occluder.visible = wall_mode!=0
	occluder.get_child(2).visible = wall_mode==1

func _capture() -> void:
	if DisplayServer.get_name()=="headless": get_tree().quit(1); return
	automatic = false
	var args := OS.get_cmdline_user_args()
	if not args.has("--continuous-only"):
		paused = true
		review_kind = "STATIC PHASE SAMPLE (speed held zero)"
		for view in Rig.DIRECTIONS:
			rig.set_direction(view)
			for sprint in [false,true]:
				night = sprint and args.has("--lighting-motion-rig")
				run = sprint
				rig.cancel_motion()
				rig.running = sprint
				rig.blend = 1
				for frame in range(8):
					rig.travel = frame/8.0*rig.gait_cycle_distance(sprint)
					rig._pose()
					for wait in range(3): await get_tree().process_frame
					if not await _save_review_png("ART-17-motion3d-candidate8-static-%s-%s-%d.png" % [view,"run" if sprint else "walk",frame]): return
	if not args.has("--capture-static-only"):
		paused = false
		review_kind = "CONTINUOUS ADVANCE / record this viewport externally"
		for view in Rig.DIRECTIONS:
			rig.set_direction(view)
			for sprint in [false,true]:
				night = sprint and args.has("--lighting-motion-rig")
				run = sprint
				speed_multiplier = 1
				rig.cancel_motion()
				var start_distance: float = rig.travel
				while rig.travel-start_distance<2.0*rig.gait_cycle_distance(sprint): await get_tree().process_frame
				# Decelerate and settle a planted stance before changing mode.
				speed_multiplier = 0
				while rig.speed>0.001 or rig.blend>0.001: await get_tree().process_frame
		for look in [{"hair":"bob","species":"elf"},{"hair":"curly","species":"imp"}]:
			rig.set_appearance(look)
			rig.set_direction("front_right")
			run = false
			speed_multiplier = 1
			var start_distance: float = rig.travel
			while rig.travel-start_distance<2.0*rig.gait_cycle_distance(false): await get_tree().process_frame
			speed_multiplier = 0
			while rig.speed>0.001 or rig.blend>0.001: await get_tree().process_frame
		print("Continuous advance review completed: eight directions, walk/run, stops and appearance changes; visual acceptance pending")
	get_tree().quit()


func _idle_review() -> void:
	if DisplayServer.get_name()=="headless": get_tree().quit(1); return
	automatic = false
	paused = false
	run = false
	speed_multiplier = 0
	review_kind = "CONTINUOUS HERO IDLE / breathe then restrained waist check"
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-idle-frames"):
		if args.has("--idle-focus-only"):
			_capture_failure("--capture-idle-frames requires all looks and directions; remove --idle-focus-only.")
			return
		var looks := [
			{"name":"human-windswept", "appearance":{"skin":"warm", "species":"human", "hair":"windswept", "hair_color":"ink", "face":"curious"}},
			{"name":"elf-bob", "appearance":{"skin":"warm", "species":"elf", "hair":"bob", "hair_color":"ink", "face":"curious"}},
			{"name":"imp-curly", "appearance":{"skin":"warm", "species":"imp", "hair":"curly", "hair_color":"ink", "face":"curious"}},
		]
		for look in looks:
			rig.set_appearance(look.appearance)
			for view in Rig.DIRECTIONS:
				rig.set_direction(view)
				rig.cancel_motion()
				while rig.idle_time < 2.0: await get_tree().process_frame
				if not await _save_review_png("ART-17-motion3d-candidate8-idle-%s-%s-breath.png" % [look.name, view]): return
				while rig.idle_time < 5.0: await get_tree().process_frame
				if not await _save_review_png("ART-17-motion3d-candidate8-idle-%s-%s-steady.png" % [look.name, view]): return
				while rig.idle_time < 8.2: await get_tree().process_frame
				if not await _save_review_png("ART-17-motion3d-candidate8-idle-%s-%s-camera-check.png" % [look.name, view]): return
		print("Idle capture completed: 3 looks x 8 directions x breath/steady/camera-check; visual acceptance pending")
		get_tree().quit()
		return
	if not args.has("--idle-focus-only"):
		for view in Rig.DIRECTIONS:
			rig.set_direction(view)
			rig.cancel_motion()
			while rig.idle_time<2.0: await get_tree().process_frame
	rig.set_direction("right")
	rig.cancel_motion()
	while rig.idle_time<8.2: await get_tree().process_frame
	while rig.idle_time<10.0: await get_tree().process_frame
	print("Hero idle continuous review completed; source/plant tests are separate and native visual acceptance pending")
	get_tree().quit()

func _native_capture_requested() -> bool:
	var args := OS.get_cmdline_user_args()
	for flag in CAPTURE_FLAGS:
		if args.has(flag): return true
	return false

func _prepare_capture_directory() -> String:
	if DisplayServer.get_name() == "headless": return "Native capture requires a GPU-backed display."
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty(): return "SNAPLAND_SAVE_PATH must point to an isolated absolute save file."
	var save_error := TestSaveGuard.validate_save_path(save_path, OS.get_user_data_dir())
	if not save_error.is_empty(): return save_error
	capture_dir = OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if capture_dir.is_empty() or not capture_dir.is_absolute_path(): return "%s must be an isolated absolute output directory." % CAPTURE_DIR_ENV
	var mkdir_error := DirAccess.make_dir_recursive_absolute(capture_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS: return "Cannot create capture output directory: %s" % capture_dir
	var normalized_capture := _normalized_path(capture_dir)
	var project_dir := _normalized_path(ProjectSettings.globalize_path("res://"))
	if _path_is_inside(normalized_capture, project_dir):
		return "%s must be outside the project tree; choose an isolated review output directory." % CAPTURE_DIR_ENV
	if _contains_png(capture_dir): return "Capture directory already contains PNG evidence; choose a fresh directory: %s" % capture_dir
	return ""

func _contains_png(directory_path: String) -> bool:
	var directory := DirAccess.open(directory_path)
	if directory == null: return false
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var entry_path := directory_path.path_join(entry)
			if directory.current_is_dir():
				if _contains_png(entry_path):
					directory.list_dir_end()
					return true
			elif entry.get_extension().to_lower() == "png":
				directory.list_dir_end()
				return true
		entry = directory.get_next()
	directory.list_dir_end()
	return false

func _save_review_png(file_name: String) -> bool:
	if capture_dir.is_empty() or file_name.get_file() != file_name or file_name.get_extension().to_lower() != "png":
		return _capture_failure("Invalid isolated capture path: " + file_name)
	var output_path := capture_dir.path_join(file_name)
	if FileAccess.file_exists(output_path):
		return _capture_failure("Refusing to overwrite review PNG: " + output_path)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		return _capture_failure("Rendered review capture must be 1280x720: " + file_name)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		return _capture_failure("Could not save review PNG (%d): %s" % [save_error, output_path])
	print("Native motion capture saved: " + output_path)
	return true

func _capture_failure(message: String) -> bool:
	push_error("Native avatar motion review failed: " + message)
	get_tree().quit(1)
	return false

func _normalized_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()

func _path_is_inside(candidate: String, directory: String) -> bool:
	return candidate == directory or candidate.begins_with(directory + "/")
