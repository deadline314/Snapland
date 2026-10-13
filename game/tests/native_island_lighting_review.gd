extends Node3D
## Controlled rendering inspection, not a claim of human gameplay.
var world
var report := {"scripted_fixture":true,"human_played":false,"audio":"Dummy","phases":[]}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if DisplayServer.get_name()=="headless" or not save_path.is_absolute_path():
		push_error("Native lighting inspection requires GPU and an isolated absolute save path")
		get_tree().quit(1)
		return
	world=load("res://game/world/park_world.gd").new()
	add_child(world)
	get_window().size=Vector2i(1280,720)
	world.player.position=Vector3(0,0.1,3)
	for phase in ["dawn","noon","dusk","night"]:
		world.set_time_of_day(phase)
		for frame in range(90): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://pm/Snapland-art/images/ART-1-island-final-"+phase+".png")
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		assert(get_viewport().get_texture().get_image().save_png(output)==OK,"native phase image is saved")
		var lights := 0
		var shadows := 0
		for lamp in world.lamps:
			if lamp.light_energy>0: lights+=1
			if lamp.shadow_enabled: shadows+=1
		report.phases.append({"phase":phase,"image":output,"light_ray":str(-world.sun.global_basis.z),"active_lamps":lights,"shadow_lamps":shadows,"exposure":world.environment.tonemap_exposure})
	var result := FileAccess.open(ProjectSettings.globalize_path("res://pm/Snapland-art/images/ART-1-island-final-report.json"),FileAccess.WRITE)
	assert(result!=null)
	result.store_string(JSON.stringify(report,"\t"))
	result.close()
	print("CAPTURED: four native island lighting phases; visual acceptance requires image inspection")
	get_tree().quit(0)
