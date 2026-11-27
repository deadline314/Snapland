extends Node3D
## Real-GPU cost survey of the island, not a claim of gameplay: eight fixed
## camera spots at noon and night under each picture-quality level, then the
## extra cost of each island event. Writes perf.json (and a few PNGs) into
## SNAPLAND_CAPTURE_DIR and prints one PERF line per sample.

const DistrictSites = preload("res://game/world/district_sites.gd")
const RenderQuality = preload("res://game/world/render_quality.gd")
const IslandEvents = preload("res://game/world/island_events.gd")
const SETTLE_FRAMES := 40
const SAMPLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const SAMPLE_SECONDS := 1.5

var world: Node3D
var events: Node3D
var out := ""
var rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _physics_process(delta: float) -> void:
	if events == null or events.is_physics_processing() or not events.is_active(): return
	events._sync_look()
	if not events.active.step(delta, world.player.global_position): events.finish()


func _spots() -> Array:
	var spots := [["welcome-carousel", Vector3(-9.7, 0.1, 14.0)], ["welcome-glasshouse", Vector3(60.8, 0.1, -1.0)]]
	for region: String in ["harbor", "nightmarket", "toy", "circus", "candy", "garden"]:
		var site: Dictionary = DistrictSites.SITES[region]
		spots.append([region, site.at + site.arrival])
	return spots


## Progress lines go to a file too: the runner only shows stdout at the end.
func _note(text: String) -> void:
	var file := FileAccess.open(out.path_join("progress.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(out.path_join("progress.txt")) else FileAccess.WRITE)
	file.seek_end()
	file.store_line("%d %s" % [Time.get_ticks_msec(), text])
	file.close()


func _visit(at: Vector3) -> void:
	_note("visit %s building %s" % [at, world.district_host._building.keys()])
	world.place_player(at)
	world.settle_avatar()
	await _wait(SETTLE_SECONDS)
	# A first approach builds the district over several frames: wait it out.
	while not world.district_host._building.is_empty(): await get_tree().process_frame
	_note("built")
	# Streaming wakes and sleeps districts every 0.4 s: give it time to settle.
	await _wait(SETTLE_SECONDS)


## At least `seconds` and SETTLE_FRAMES frames: an uncapped frame rate would
## otherwise race past the district streaming interval.
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var frames := 0
	while frames < SETTLE_FRAMES or Time.get_ticks_msec() < until:
		await get_tree().process_frame
		frames += 1


func _casters() -> Vector2i:
	var shown := 0
	var casting := 0
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_visible_in_tree(): continue
		shown += 1
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: casting += 1
	return Vector2i(shown, casting)


func _sample(label: Dictionary) -> Dictionary:
	var rid := get_viewport().get_viewport_rid()
	var frame_ms: Array[float] = []
	var gpu_ms: Array[float] = []
	var cpu_ms: Array[float] = []
	var draws := 0
	var objects := 0
	var primitives := 0
	var last := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(SAMPLE_SECONDS * 1000.0)
	while frame_ms.size() < SAMPLE_FRAMES or Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects = maxi(objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitives = maxi(primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var casters := _casters()
	_note("sampled %s" % label)
	var row := label.duplicate()
	row.merge({
		"frame_ms": _median(frame_ms), "frame_p95_ms": _p95(frame_ms),
		"gpu_ms": _median(gpu_ms), "render_cpu_ms": _median(cpu_ms),
		"draw_calls": draws, "objects": objects, "primitives": primitives,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"shown_geometry": casters.x, "shadow_casters": casters.y,
		"vram_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buffer_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"awake": _awake(),
	})
	rows.append(row)
	print("PERF ", JSON.stringify(row))
	return row


func _awake() -> String:
	var names: Array[String] = []
	for region: String in world.district_host.districts:
		if world.district_host.is_awake(region): names.append(region)
	return ",".join(names)


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(sorted[int(sorted.size() * 0.5)], 0.01)


func _p95(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(sorted[int(sorted.size() * 0.95)], 0.01)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _run() -> void:
	out = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or out.is_empty():
		push_error("Perf probe needs a GPU, an isolated save and SNAPLAND_CAPTURE_DIR")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1280, 720)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var start_static := Performance.get_monitor(Performance.MEMORY_STATIC)
	var started := Time.get_ticks_msec()
	world = load("res://game/world/park_world.gd").new()
	add_child(world)
	await get_tree().process_frame
	world.set_sticker_count(180)
	events = IslandEvents.attach(world)
	events.countdown = 1.0e9
	var spots := _spots()
	await _visit(spots[0][1])
	var boot := {"kind": "boot", "boot_ms": Time.get_ticks_msec() - started,
		"static_mb_before_world": snappedf(start_static / 1048576.0, 0.1)}
	await _sample(boot.merged({"spot": spots[0][0], "phase": "noon", "quality": "high"}))
	# Warm-up: walk every spot once so every district is built and every shader compiled.
	for spot: Array in spots: await _visit(spot[1])
	var district_nodes := {}
	for region: String in world.district_host.districts:
		district_nodes[region] = world.district_host.districts[region].find_children("*", "Node", true, false).size() + 1
	print("PERF ", JSON.stringify({"kind": "districts", "nodes": district_nodes}))
	_note("textures")
	_textures()
	_note("textures done")
	rows.append({"kind": "districts", "nodes": district_nodes})
	var levels: Array[String] = RenderQuality.LEVELS.duplicate()
	if OS.get_cmdline_user_args().has("--events-only"): levels.clear()
	for level: String in levels:
		world.apply_settings({"reduced_motion": false, "graphics_quality": level})
		for phase: String in ["noon", "night"]:
			world.set_time_of_day(phase)
			for spot: Array in spots:
				await _visit(spot[1])
				await _sample({"kind": "spot", "spot": spot[0], "phase": phase, "quality": level})
				if level == "high": await _shot("perf-%s-%s" % [spot[0], phase])
	await _events()
	var file := FileAccess.open(out.path_join("perf.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  "))
	file.close()
	print("CAPTURED: island perf survey (%d samples); numbers only, not a gameplay claim" % rows.size())
	get_tree().quit(0)


func _events() -> void:
	# The director pauses events until the first-visit prologue is seen; the
	# probe steps the running event itself, as the director does for a free walker.
	events.set_physics_process(false)
	world.apply_settings({"reduced_motion": false, "graphics_quality": "high"})
	var home: Vector3 = _spots()[0][1]
	for id: String in ["shower", "wind", "fireworks"]:
		var phase := "night" if id == "fireworks" else "noon"
		world.set_time_of_day(phase)
		await _visit(home)
		if id == "fireworks":
			# The show happens off the lookout: measure there before and during.
			_note("start lookout %s" % events.start(id, home))
			var lookout: Vector3 = events.active.lookout
			events.finish()
			await _visit(lookout + Vector3(0, 0.1, 0))
		var spot: Vector3 = world.player.position
		var quiet := await _sample({"kind": "event", "event": id, "stage": "before", "phase": phase, "quality": "high"})
		_note("start %s: %s" % [id, events.start(id, spot)])
		await _wait(6.0)
		var busy := await _sample({"kind": "event", "event": id, "stage": "during", "phase": phase, "quality": "high"})
		await _shot("perf-event-" + id)
		events.finish()
		await _wait(1.0)
		var after := await _sample({"kind": "event", "event": id, "stage": "after", "phase": phase, "quality": "high"})
		print("EVENT %s nodes %d -> %d -> %d, draws %d -> %d" % [id, quiet.nodes, busy.nodes, after.nodes, quiet.draw_calls, busy.draw_calls])


## Where the texture memory goes: every texture the world's materials and
## sprites reference, once each, grouped by file (or by size for textures made
## at runtime) so repeated copies of one picture stand out. Bytes are an
## estimate: 4 per texel, plus a third for mipmaps when the file has them.
func _textures() -> void:
	var seen := {}
	var groups := {}
	for node: Node in world.find_children("*", "Node", true, false):
		for texture: Texture2D in _node_textures(node):
			if texture == null or seen.has(texture.get_rid()): continue
			seen[texture.get_rid()] = true
			var key := texture.resource_path if not texture.resource_path.is_empty() else "(runtime %dx%d %s)" % [texture.get_width(), texture.get_height(), texture.get_class()]
			var group: Dictionary = groups.get(key, {"source": key, "count": 0, "mb": 0.0})
			group.count += 1
			group.mb += float(texture.get_width() * texture.get_height() * 4) * (1.33 if texture.has_method("has_mipmaps") and texture.has_mipmaps() else 1.0) / 1048576.0
			groups[key] = group
	var listed := groups.values()
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.mb > b.mb)
	var total := 0.0
	for group: Dictionary in listed: total += group.mb
	var top := []
	for group: Dictionary in listed.slice(0, 40):
		group.mb = snappedf(group.mb, 0.01)
		top.append(group)
		print("TEXTURE %7.2f MB x%d %s" % [group.mb, group.count, group.source])
	print("TEXTURE total %.1f MB over %d textures" % [total, seen.size()])
	rows.append({"kind": "textures", "total_mb": snappedf(total, 0.1), "count": seen.size(), "top": top})


func _node_textures(node: Node) -> Array:
	var found := []
	var materials := []
	if node is Sprite3D: found.append((node as Sprite3D).texture)
	if node is GeometryInstance3D: materials.append((node as GeometryInstance3D).material_override)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count(): materials.append(mesh.surface_get_material(surface))
	if node is GPUParticles3D: materials.append((node as GPUParticles3D).process_material)
	for material: Material in materials:
		if material is StandardMaterial3D:
			found.append((material as StandardMaterial3D).albedo_texture)
			found.append((material as StandardMaterial3D).normal_texture)
			found.append((material as StandardMaterial3D).emission_texture)
		elif material is ShaderMaterial and (material as ShaderMaterial).shader != null:
			for uniform: Dictionary in (material as ShaderMaterial).shader.get_shader_uniform_list():
				var value: Variant = (material as ShaderMaterial).get_shader_parameter(uniform.name)
				if value is Texture2D: found.append(value)
	return found
