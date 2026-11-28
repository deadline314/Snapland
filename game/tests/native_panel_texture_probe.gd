extends Node
## Real-GPU check of texture memory across repeated panel rounds (MAIN-64):
## opens and closes the island map, a district map, settings, wardrobe, time
## and achievements ROUNDS times and prints texture memory after each panel.
## Numbers only, not a gameplay claim.

const ROUNDS := 10
## Idle seconds before the rounds, so growth that comes with time alone shows apart.
const IDLE_SECONDS := 120
## Each panel stays open this long, like a player reading it, then closes for CLOSED_SECONDS.
const OPEN_SECONDS := 1.5
const CLOSED_SECONDS := 0.5
const PANELS := ["island_map", "district_map", "settings", "wardrobe", "time", "achievements"]

var _main: Node


func _ready() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for frame in count: await get_tree().process_frame


func _mb(monitor: int) -> float:
	return snappedf(Performance.get_monitor(monitor) / 1048576.0, 0.01)


func _open(panel: String) -> void:
	match panel:
		"island_map": _main._show_island_map()
		"district_map":
			_main.world.district_host.ensure("toy")
			_main._on_district_changed("toy")
			_main._show_map()
		"settings": _main._show_settings()
		"wardrobe": _main._show_wardrobe()
		"time": _main._show_time_panel()
		"achievements": _main._show_achievements()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Panel texture probe needs a GPU and an isolated save")
		get_tree().quit(1)
		return
	var progress := get_node("/root/Progress")
	progress.intro_seen = true
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await _frames(90)
	print("PANELTEX boot font sizes %d" % _size_count())
	print("PANELTEX start texture %.2f MB, static %.2f MB, nodes %d" % [_mb(Performance.RENDER_TEXTURE_MEM_USED), _mb(Performance.MEMORY_STATIC), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < IDLE_SECONDS * 1000:
		await get_tree().create_timer(15.0).timeout
		print("PANELTEX idle %3ds texture %.2f MB, font sizes %d" % [(Time.get_ticks_msec() - started) / 1000, _mb(Performance.RENDER_TEXTURE_MEM_USED), _size_count()])
	for round in ROUNDS:
		for panel: String in PANELS:
			var before := _mb(Performance.RENDER_TEXTURE_MEM_USED)
			_open(panel)
			await get_tree().create_timer(OPEN_SECONDS).timeout
			var opened := _mb(Performance.RENDER_TEXTURE_MEM_USED)
			_main._close()
			if panel == "district_map": _main._on_district_changed("welcome")
			await get_tree().create_timer(CLOSED_SECONDS).timeout
			var closed := _mb(Performance.RENDER_TEXTURE_MEM_USED)
			print("PANELTEX round %d %-13s open %+.2f close %+.2f MB, font sizes %d" % [round, panel, opened - before, closed - before, _size_count()])
		await _frames(10)
		print("PANELTEX after round %d at %ds texture %.2f MB, static %.2f MB, nodes %d, objects %d" % [round, (Time.get_ticks_msec() - started) / 1000, _mb(Performance.RENDER_TEXTURE_MEM_USED), _mb(Performance.MEMORY_STATIC),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
		print("PANELTEX font pages %s" % _font_pages())
		print("PANELTEX pixel cache %d entries" % (load("res://game/minigames/arcade/arcade_pixels.gd") as GDScript).get("_cache").size())
	get_tree().quit(0)


## Glyph atlas pages of every font file the UI font draws from: count, MB, sizes.
func _font_pages() -> String:
	var files := []
	var queue: Array = [load("res://game/ui/paper_ui.gd").FONT]
	while not queue.is_empty():
		var font: Font = queue.pop_back()
		if font == null or files.has(font): continue
		files.append(font)
		if font is FontVariation: queue.append((font as FontVariation).base_font)
		queue.append_array(font.fallbacks)
	var pages := 0
	var bytes := 0
	var sizes := 0
	var per_file := []
	for font: Font in files:
		if not font is FontFile: continue
		var file := font as FontFile
		var file_pages := 0
		var file_bytes := 0
		var rendered := {}
		for cache in file.get_cache_count():
			for size: Vector2i in file.get_size_cache_list(cache):
				var count := file.get_texture_count(cache, size)
				file_pages += count
				if count > 0: rendered[size.x] = count
				for page in count:
					var page_image := file.get_texture_image(cache, size, page)
					if page_image != null: file_bytes += page_image.get_data_size()
		per_file.append("%s: %d pages %.1f MB sizes %s sub %d aa %d" % [file.resource_path.get_file() if not file.resource_path.is_empty() else file.font_name, file_pages, file_bytes / 1048576.0, str(rendered), file.subpixel_positioning, file.antialiasing])
	print("PANELTEX per file ", per_file)
	for font: Font in files:
		if not font is FontFile: continue
		var file := font as FontFile
		for cache in file.get_cache_count():
			for size: Vector2i in file.get_size_cache_list(cache):
				sizes += 1
				for page in file.get_texture_count(cache, size):
					pages += 1
					var image := file.get_texture_image(cache, size, page)
					if image != null: bytes += image.get_data_size()
	var listed := {}
	for font: Font in files:
		if font is FontFile:
			for size: Vector2i in (font as FontFile).get_size_cache_list(0): listed[size.x] = int(listed.get(size.x, 0)) + 1
	var keys := listed.keys()
	keys.sort()
	return "%d pages, %.2f MB, %d sizes over %d files; size values %s" % [pages, bytes / 1048576.0, sizes, files.size(), str(keys.slice(0, 80))]


func _size_count() -> int:
	var count := 0
	var queue: Array = [load("res://game/ui/paper_ui.gd").FONT]
	var seen := []
	while not queue.is_empty():
		var font: Font = queue.pop_back()
		if font == null or seen.has(font): continue
		seen.append(font)
		if font is FontVariation: queue.append((font as FontVariation).base_font)
		queue.append_array(font.fallbacks)
		if font is FontFile: count += (font as FontFile).get_size_cache_list(0).size()
	return count
