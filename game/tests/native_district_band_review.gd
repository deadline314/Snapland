extends Node3D
## Controlled rendering inspection of the district transition bands and the
## repainted welcome props, not a claim of human gameplay. Writes one PNG per
## view into SNAPLAND_CAPTURE_DIR.

const DistrictSites = preload("res://game/world/district_sites.gd")
const VIEWS := [
	["toy-circus", Vector3(48.5, 0.1, -182.0), "noon"],
	["candy-south", Vector3(146.0, 0.1, -56.0), "noon"],
	["nightmarket-south", Vector3(-72.0, 0.1, -140.0), "night"],
	["circus-west", Vector3(52.0, 0.1, -170.0), "night"],
	["garden-south", Vector3(118.0, 0.1, 26.0), "dusk"],
	["harbor-headland", Vector3(-86.0, 0.1, 66.0), "noon"],
	["welcome-carousel", Vector3(-9.7, 0.1, 14.0), "noon"],
	["welcome-gates", Vector3(82.0, 0.1, -140.0), "noon"],
	["welcome-glasshouse", Vector3(60.8, 0.1, -1.0), "noon"],
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or out.is_empty():
		push_error("Band review needs a GPU, an isolated save and SNAPLAND_CAPTURE_DIR")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1280, 720)
	var world: Node3D = load("res://game/world/park_world.gd").new()
	add_child(world)
	await get_tree().process_frame
	world.set_sticker_count(30)
	for region: String in DistrictSites.regions(): world.district_host.ensure(region)
	DirAccess.make_dir_recursive_absolute(out)
	for view: Array in VIEWS:
		world.place_player(view[1])
		world.settle_avatar()
		world.district_host.track(view[1], 1.0)
		world.set_time_of_day(view[2])
		for frame in 45: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = out.path_join("band-%s-%s.png" % [view[0], view[2]])
		if get_viewport().get_texture().get_image().save_png(path) != OK: push_error("could not save " + path)
	print("CAPTURED: district band views; visual acceptance requires image inspection")
	get_tree().quit(0)
