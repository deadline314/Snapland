extends Node
## Opening and closing menus must reuse what the first opening made: no new
## baked textures, styles, fonts or glyph sizes (each glyph size is its own set
## of font pages in video memory) once a panel has been shown once.

const MainScene = preload("res://game/main.tscn")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const PANELS := ["_show_pause", "_show_ticket", "_show_album", "_show_island_map", "_show_settings", "_show_wardrobe"]
const CYCLES := 10

var _failures: Array[String] = []
var _main: Node


func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set isolated SNAPLAND_SAVE_PATH before menu memory test.")
		get_tree().quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	Progress.reset_progress()
	Progress.intro_seen = true
	get_window().size = Vector2i(1280, 720)
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(4)
	for panel: String in PANELS:
		var first := {}
		for cycle in CYCLES:
			_main.call(panel)
			await _frames(3)
			_main._close()
			await _frames(3)
			if cycle == 0:
				first = _census()
		var last := _census()
		for key: String in first:
			_check(last[key] == first[key], "%s: %s grew from %d to %d over %d open/close cycles" % [panel, key, first[key], last[key], CYCLES])
	await _check_headline_sizes()
	if _failures.is_empty():
		print("PASS: menu memory reuse; six panels x%d keep baked textures, styles, fonts, glyph sizes and pages and nodes, and the moving headline prints at few sizes" % CYCLES)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


## While the pause headline drifts with the page (entrance, sway) its fitted
## size changes every frame; it must still print at only a few glyph sizes.
func _check_headline_sizes() -> void:
	_main._show_pause()
	await _frames(3)
	var center := _main.overlay.get_node_or_null("AdaptiveMenuCenter") as Control
	var headline := _main.overlay.find_child("CollageHeadline", true, false) as Control
	_check(center != null and headline != null, "the pause page shows a stamped headline")
	if center == null or headline == null:
		return
	var files := _font_files(headline.get("label").get_theme_font("font"))
	var before := _size_values(files)
	for step in 25:
		center.position.y = float(12 - step) / 3.0
		headline.set("wiggle", float(step % 7) - 3.0)
		headline.queue_redraw()
		await _frames(1)
	var added := _size_values(files).size() - before.size()
	_check(added <= 2, "the drifting pause headline printed %d new glyph sizes (at most 2)" % added)
	_main._close()


func _census() -> Dictionary:
	var sizes := 0
	var pages := 0
	for file: FontFile in _all_font_files():
		for cache in file.get_cache_count():
			for size: Vector2i in file.get_size_cache_list(cache):
				sizes += 1
				pages += file.get_texture_count(cache, size)
	return {
		"baked textures": Pixels._cache.size(),
		"paper styles": Paper._style_cache.size(),
		"profile fonts": FontProfiles._cache.size(),
		"glyph sizes": sizes,
		"glyph pages": pages,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}


func _all_font_files() -> Array[FontFile]:
	var files: Array[FontFile] = []
	for font: Font in FontProfiles._cache.values():
		for file in _font_files(font):
			if not files.has(file):
				files.append(file)
	return files


func _font_files(font: Font, into: Array[FontFile] = []) -> Array[FontFile]:
	if font == null:
		return into
	if font is FontVariation:
		_font_files((font as FontVariation).base_font, into)
	if font is FontFile and not into.has(font):
		into.append(font)
	for fallback: Font in font.fallbacks:
		_font_files(fallback, into)
	return into


## Distinct glyph sizes (size and outline width) across `files`. Imported
## fonts ship empty plain entries for sizes 1-128, so outlined sizes are what
## a drifting stamped headline adds.
func _size_values(files: Array[FontFile]) -> Dictionary:
	var values := {}
	for file in files:
		for cache in file.get_cache_count():
			for size: Vector2i in file.get_size_cache_list(cache):
				values[size] = true
	return values


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
