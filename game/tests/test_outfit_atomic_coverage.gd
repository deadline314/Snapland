extends SceneTree
## A broken cel in another action must reject the whole clothing silhouette.
const Library = preload("res://game/world/character_animation_library.gd")
var failures: Array[String] = []
var output: String
var source: String
var replacement: String
var manifest_path: String
var checked := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save_path.is_absolute_path(): quit(2); return
	output = save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(output)
	source = output.path_join("base.png")
	replacement = output.path_join("coat.png")
	manifest_path = output.path_join("outfits.json")
	for entry in [[source, Color.RED], [replacement, Color.GREEN]]:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(entry[1])
		_check(image.save_png(entry[0]) == OK, "fixture image saved")
	var valid := _fixture()
	var library = Library.new(_write(valid))
	_check_all(library, true, "complete outfit")
	var mutations := ["missing", "outside", "anchor", "source", "container", "nonfinite", "scale", "entire_action", "entire_direction", "missing_anchor"]
	for mutation in mutations:
		var broken: Dictionary = valid.duplicate(true)
		var target: Dictionary = broken.actors.traveller.wave.left.frames[1]
		match mutation:
			"missing": target.erase("variants")
			"outside": target.variants.coat.region = [3, 3, 4, 4]
			"anchor": target.variants.coat.anchors.head = [-1, 0]
			"missing_anchor": target.variants.coat.anchors.erase("head")
			"source": target.variants.coat.source = output.path_join("missing.png")
			"container": target.variants = []
			"nonfinite": target.variants.coat.anchors.head = [INF, 0]
			"scale": target.source_scale = "invalid"
			"entire_action": broken.actors.traveller.erase("wave")
			"entire_direction": broken.actors.traveller.wave.erase("left")
		# JSON cannot retain infinity: inject only that mutation after loading.
		if mutation == "nonfinite":
			library.load_manifest(_write(valid))
			library.manifest.actors.traveller.wave.left.frames[1].variants.coat.anchors.head = [INF, 0]
		else: library.load_manifest(_write(broken))
		if mutation in ["entire_action", "entire_direction"]:
			var actual: Texture2D = library.texture("traveller", "idle", "front", 0, {"outfit":"coat"})
			_check(actual.get_image().get_pixel(8,4) == Color.RED, mutation + " rejects the whole silhouette")
		else: _check_all(library, false, mutation)
		_check(library.diagnostics.any(func(item: String) -> bool: return item.contains("traveller/wave/left/frame") and item.contains("coat")), mutation + " identifies the exact missing/broken cel")
	# Reloading an artist's repaired package clears rejection and texture caches.
	library.load_manifest(_write(valid))
	_check_all(library, true, "repaired outfit")
	var palette: Dictionary = valid.duplicate(true)
	palette.outfit_modes.coat = "palette"
	library.load_manifest(_write(palette))
	_check_all(library, false, "explicit palette keeps original body")
	var live_before: Texture2D = library.texture("traveller", "idle", "front", 0, {"outfit":"coat"})
	var anchor_before: Vector2i = library.normalized_anchor("traveller", "idle", "front", 0, "head", {"outfit":"coat"})
	var inspected: Texture2D = library.inspect_variant_texture("traveller", "idle", "front", 0, "coat")
	_check(inspected!=null and inspected.get_image().get_pixel(8,4)==Color.GREEN, "explicit inspection reads a palette outfit's retained candidate")
	_check(library.texture("traveller", "idle", "front", 0, {"outfit":"coat"})==live_before and live_before.get_image().get_pixel(8,4)==Color.RED, "inspection cannot pollute live texture selection or cache")
	_check(library.texture("traveller", "idle", "front", 0, {"outfit":"coat", "inspection":true}).get_image().get_pixel(8,4)==Color.RED, "save equipment keys cannot collide with the inspection cache namespace")
	_check(library.normalized_anchor("traveller", "idle", "front", 0, "head", {"outfit":"coat"})==anchor_before, "inspection cannot pollute live anchor layout")
	_check(library.inspect_variant_texture("traveller", "idle", "front", -1, "coat")==null and library.inspect_variant_texture("traveller", "idle", "front", 2, "coat")==null, "inspection rejects out-of-range frames instead of wrapping")
	var broken_candidate: Dictionary = valid.duplicate(true)
	broken_candidate.actors.traveller.wave.left.frames[1].variants.coat.region = [3,3,4,4]
	library.load_manifest(_write(broken_candidate))
	_check(library.inspect_variant_texture("traveller", "idle", "front", 0, "coat")!=null, "valid candidate can be inspected while another pose is broken")
	_check(library.inspect_variant_texture("traveller", "wave", "left", 1, "coat")==null, "inspection still rejects invalid source bounds")
	_check_all(library, false, "inspection never enables incomplete outfit")
	# Production coral is a palette of the jacket, never the old vest prototype.
	library = Library.new()
	_check(not library.outfit_variant_ready("traveller", "unreleased-coat"), "island obligations reject a silhouette without eight-direction walking")
	_check(library.diagnostics.any(func(item: String) -> bool: return item.contains("traveller/walk/") and item.contains("unreleased-coat")), "external walking gap is diagnosed explicitly")
	for action in ["idle", "wave", "photograph", "interact", "jump", "sit", "catch"]:
		for direction in library.coverage_report().traveller.get(action, []):
			var base: Dictionary = library.get_sequence("traveller", action, direction)
			var coral: Dictionary = library.get_sequence("traveller", action, direction, {"outfit": "outfit-coral"})
			for index in range(base.frames.size()):
				_check(coral.frames[index].texture != null and base.frames[index].texture != null, "production cel is available")
				if coral.frames[index].texture != null and base.frames[index].texture != null:
					_check(coral.frames[index].texture.get_image().get_data() == base.frames[index].texture.get_image().get_data(), "coral uses complete original jacket for %s/%s/%d" % [action,direction,index])
	var report := {"checks": checked, "failures": failures, "engine": Engine.get_version_info().string, "scope": "headless rendered pixels and outfit source selection; not native animation acceptance"}
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	if failures.is_empty(): print("PASS: atomic outfit coverage (%d checks)" % checked)
	else: printerr("FAIL: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	var frame := {"source": source, "region": [0,0,4,4], "anchors": {"feet": [1,3], "head": [2,0]}, "layers": [], "variants": {"coat": {"source": replacement, "region": [0,0,4,4], "anchors": {"feet": [2,2], "head": [0,1]}}}}
	return {"schema_version": 1, "outfit_modes": {"base": "palette"}, "outfit_required_poses": {"traveller": {"idle": {"front": 2}, "wave": {"left": 2}}}, "actors": {"traveller": {"canvas_size": [12,8], "reference_size": [4,4], "feet_baseline": 6, "idle": {"front": {"fps": 2, "loop": true, "frames": [frame.duplicate(true), frame.duplicate(true)]}}, "wave": {"left": {"fps": 2, "loop": false, "frames": [frame.duplicate(true), frame.duplicate(true)]}}}}}

func _write(value: Dictionary) -> String:
	FileAccess.open(manifest_path, FileAccess.WRITE).store_string(JSON.stringify(value))
	return manifest_path

func _check_all(library: RefCounted, enabled: bool, label: String) -> void:
	for pair in [["idle", "front"], ["wave", "left"]]:
		for index in range(2):
			var actual: Texture2D = library.texture("traveller", pair[0], pair[1], index, {"outfit": "coat"})
			var expected: Texture2D = library.texture("traveller", pair[0], pair[1], index, {"outfit": "base"})
			# A malformed shared scale invalidates the base cel too; never show a partial replacement.
			if expected == null:
				_check(actual == null, label + " safely rejects broken shared metadata")
				continue
			_check(actual != null, label + " supplies complete body")
			if actual == null: continue
			if enabled:
				_check(actual.get_image().get_pixel(8,4) == Color.GREEN, label + " selects coat in every action/direction")
				_check(library.normalized_anchor("traveller", pair[0], pair[1], index, "head", {"outfit":"coat"}) == Vector2i(2,4), label + " selects matching coat anchor")
			else:
				_check(actual.get_image().get_data() == expected.get_image().get_data(), label + " retains original body in every action/direction")
				_check(library.normalized_anchor("traveller", pair[0], pair[1], index, "head", {"outfit":"coat"}) == Vector2i(8,0), label + " retains original anchor")

func _check(ok: bool, label: String) -> void:
	checked += 1
	if not ok: failures.append(label)
