extends Node
## Art-direction audit capture: walks the real Main through every district at
## noon, dusk and night, records the fast-travel cover mid-way, the menus, the
## island events, the thief and a few minigames. Scripted fixture records are
## setup data, never evidence of earned cards or human play; judging the images
## is a separate, manual step.
##
## User args (after --): --only=<section,...> limits the run to sections
## (districts, travel, welcome, menus, events, games). --phases=noon,dusk,night.
const MainScene = preload("res://game/main.tscn")
const RegionRoutes = preload("res://game/core/region_routes.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const WELCOME_VIEWS := [
	["plaza", Vector3(0, 0.3, 6.5)],
	["carousel", Vector3(-9.7, 0.3, 14.0)],
	["glasshouse", Vector3(60.8, 0.3, -1.0)],
	["gates", Vector3(82.0, 0.3, -140.0)],
	["harbor-headland", Vector3(-86.0, 0.3, 66.0)],
	["toy-circus-band", Vector3(48.5, 0.3, -182.0)],
]
const GAMES := ["game-001", "game-006", "game-014", "game-027", "game-040", "game-052", "game-064", "game-075", "game-085"]

var main: Node
var out := ""
var sections: PackedStringArray = ["districts", "travel", "welcome", "menus", "events", "games"]
var phases: PackedStringArray = ["noon", "dusk", "night"]
var shots := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	out = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or out.is_empty():
		push_error("Art audit needs a GPU, an isolated save and SNAPLAND_CAPTURE_DIR")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): sections = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--phases="): phases = arg.trim_prefix("--phases=").split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	Progress.reset_progress()
	Progress.intro_seen = true
	Progress.prologue_seen = true
	Progress.settings.fullscreen = false
	Progress.settings.time_phase = "noon"
	for zone: String in RegionRoutes.ORDER:
		for index in range(1, 13): Progress.photos["photo-%s-game-%d" % [zone, index]] = {"fixture": "art-audit"}
	Progress.save_progress()
	get_window().size = Vector2i(1280, 720)
	main = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(30)
	_dismiss()
	if "travel" in sections: await _travel_shots()
	if "districts" in sections: await _district_shots()
	if "welcome" in sections: await _welcome_shots()
	if "events" in sections: await _event_shots()
	if "menus" in sections: await _menu_shots()
	if "games" in sections: await _game_shots()
	print("CAPTURED: %d art audit views in %s; visual acceptance requires image inspection" % [shots, out])
	await main._quit_game()


## Fast travel by the map: the cover closing, the moment it opens, and a beat later.
func _travel_shots() -> void:
	for destination: String in ["harbor", "nightmarket", "welcome"]:
		_set_phase("dusk")
		if not main._travel_to_region(destination):
			push_warning("travel to %s refused" % destination)
			continue
		await _wait(0.30)
		await _snap("travel-%s-a-closing" % destination)
		await _until(func() -> bool: return not main.changing_region, 6.0, 0.22)
		await _snap("travel-%s-b-opening" % destination)
		await _until(func() -> bool: return not main._transition_busy(), 6.0)
		await _wait(0.6)
		await _snap("travel-%s-c-arrived" % destination)


func _district_shots() -> void:
	for region: String in DistrictSites.regions():
		var spot: Vector3 = main.world.arrival_point(region)
		if not spot.is_finite(): continue
		await _stand(spot)
		for phase in phases:
			_set_phase(phase)
			await _wait(0.7)
			await _snap("district-%s-%s" % [region, phase])
		# A second look further in: the district centre.
		var centre: Vector3 = DistrictSites.SITES[region].at + Vector3(0, 0.3, 0)
		if main.world.is_walkable(centre):
			await _stand(centre)
			_set_phase("noon")
			await _wait(0.6)
			await _snap("district-%s-centre-noon" % region)


func _welcome_shots() -> void:
	for view: Array in WELCOME_VIEWS:
		await _stand(view[1])
		for phase in phases:
			_set_phase(phase)
			await _wait(0.6)
			await _snap("welcome-%s-%s" % [view[0], phase])
	# The hero in motion, walking east across the plaza.
	await _stand(Vector3(-4, 0.3, 6.5))
	_set_phase("noon")
	Input.action_press("move_right")
	for index in 4:
		await _wait(0.18)
		await _snap("welcome-hero-walk-%d" % index)
	Input.action_release("move_right")


func _event_shots() -> void:
	await _stand(Vector3(0, 0.3, 6.5))
	var events: Node = main.island_events
	for pair: Array in [["shower", "noon"], ["wind", "dusk"], ["fireworks", "night"]]:
		_set_phase(pair[1])
		if is_instance_valid(events):
			if events.is_active(): events.finish()
			events.start(pair[0], main.world.player.position)
		await _wait(2.5)
		await _snap("event-%s-%s" % pair)
		if is_instance_valid(events) and events.is_active(): events.finish()
	_set_phase("noon")
	var thief: Node3D = main.get("thief")
	if is_instance_valid(thief) and thief.appear_near(main.world.player.position):
		thief._show_at(main.world.player.position + Vector3(3.0, 0, -1.0))
		await _wait(0.8)
		await _snap("event-thief-noon")


func _menu_shots() -> void:
	await _stand(Vector3(0, 0.3, 6.5))
	_set_phase("noon")
	for pair: Array in [["map", "_show_map"], ["album", "_show_album"], ["tasks", "_show_tasks"], ["wardrobe", "_show_wardrobe"], ["settings", "_show_settings"], ["pause", "_show_pause"]]:
		main.call(pair[1])
		await _wait(0.8)
		await _snap("menu-%s" % pair[0])
		main._close()
		await _wait(0.2)
	main._interact("gate:circus", "鏡之馬戲團")
	await _wait(0.8)
	await _snap("menu-gate-info")
	main._close()


func _game_shots() -> void:
	_set_phase("noon")
	for id: String in GAMES:
		main._launch_game(id, false)
		if main.session == null: continue
		await _wait(0.8)
		await _snap("game-%s-a-intro" % id)
		Input.action_press("ui_accept")
		await _frames(2)
		Input.action_release("ui_accept")
		await _wait(3.0)
		await _snap("game-%s-b-play" % id)
		main._cancel_game()
		await _wait(0.6)
		_dismiss()


func _stand(spot: Vector3) -> void:
	_dismiss()
	main.world.district_host.ensure(DistrictSites.ruling(Vector2(spot.x, spot.z)))
	main.world.place_player(spot)
	main.world.settle_avatar()
	await _frames(8)


func _set_phase(phase: String) -> void:
	Progress.settings.time_phase = phase
	main._apply_time_phase()


func _dismiss() -> void:
	if main.modal_kind != "": main._close()


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out.path_join(label + ".png")
	if image == null or image.save_png(path) != OK:
		push_error("could not save " + path)
		return
	shots += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(done: Callable, limit: float, after := 0.0) -> void:
	var deadline := Time.get_ticks_msec() + int(limit * 1000.0)
	while not done.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if after > 0.0: await _wait(after)


func _frames(count: int) -> void:
	for index in count: await get_tree().process_frame
