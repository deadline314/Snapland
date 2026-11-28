extends Node
## Opening and closing the six everyday panels (island map, a district map,
## settings, wardrobe, time, achievements) leaves nothing behind (MAIN-64):
## after the first rounds, which may fill shared caches, later rounds keep the
## node count and the shared pixel cache flat and the object count within a
## small slack. A texture baked per opening and kept is one more live object
## each time, so a panel baking several a round fails here. Headless runs have
## no texture memory to read; native_panel_texture_probe.tscn measures that on
## a GPU.

const ROUNDS := 6
## Rounds 0 and 1 may still fill caches; later rounds compare against round 1.
const REFERENCE_ROUND := 1
const PANELS := ["island_map", "district_map", "settings", "wardrobe", "time", "achievements"]
## Objects the later rounds may add in all (the paused world adds none).
const OBJECT_SLACK := 2
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Panel rounds require an absolute isolated save")
		get_tree().quit(1)
		return
	get_tree().create_timer(120.0).timeout.connect(func(): push_error("Panel rounds watchdog"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 4) -> void:
	for frame in count: await get_tree().process_frame


func _open(panel: String) -> void:
	match panel:
		"island_map": main._show_island_map()
		"district_map":
			main.world.district_host.ensure("toy")
			main._on_district_changed("toy")
			main._show_map()
		"settings": main._show_settings()
		"wardrobe": main._show_wardrobe()
		"time": main._show_time_panel()
		"achievements": main._show_achievements()


func _counts() -> Dictionary:
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "pixels": Pixels._cache.size()}


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(30)
	# The island keeps living on timers (critters, events, the thief); hold it
	# still so only the panels can change the counts.
	main.world.process_mode = Node.PROCESS_MODE_DISABLED
	var first := {}
	for round in ROUNDS:
		for panel: String in PANELS:
			_open(panel)
			await _frames()
			if round == 0 and main.modal_kind == "": failures.append("%s did not open" % panel)
			main._close()
			if panel == "district_map": main._on_district_changed("welcome")
			await _frames()
		await _frames(10)
		var now := _counts()
		print("[panel rounds] round %d %s orphans %d" % [round, now, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
		if round <= REFERENCE_ROUND:
			first = now
			continue
		if now.nodes != first.nodes: failures.append("round %d keeps %d nodes, round 1 left %d" % [round, now.nodes, first.nodes])
		if now.pixels != first.pixels: failures.append("round %d grew the pixel cache to %d (round 1: %d)" % [round, now.pixels, first.pixels])
		if now.objects > first.objects + OBJECT_SLACK: failures.append("round %d holds %d objects, round 1 left %d" % [round, now.objects, first.objects])
	if failures.is_empty():
		print("PASS: six panels open and close %d rounds with flat nodes, objects and caches" % ROUNDS)
	for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)
