extends SceneTree
## Every region is audited against the scene-building standards. Known debt is
## written down per region and rule; a region may never get worse, and a rule
## the standards call "clean" must stay at zero.
##
## Run with `-- --scene-audit` to print every violation (the working list for
## clean-up tickets) and `-- --write-baseline` to record the current counts.

const SceneStandards = preload("res://game/world/scene_standards.gd")
const BASELINE_PATH := "res://game/tests/scene_standards_baseline.json"
const REGIONS := {
	"welcome": "res://game/world/park_world.gd",
	"harbor": "res://game/world/harbor_world.gd",
	"candy": "res://game/world/candy_world.gd",
	"nightmarket": "res://game/world/nightmarket_world.gd",
	"circus": "res://game/world/circus_world.gd",
	"toy": "res://game/world/toy_world.gd",
	"garden": "res://game/world/garden_world.gd",
	"hotel": "res://game/world/hotel_world.gd",
}

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Scene standards: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var listing := OS.get_cmdline_user_args().has("--scene-audit")
	var writing := OS.get_cmdline_user_args().has("--write-baseline")
	var baseline: Dictionary = {}
	if FileAccess.file_exists(BASELINE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
		if parsed is Dictionary:
			baseline = parsed
	_check(writing or not baseline.is_empty(), "the debt baseline exists and parses")
	_self_test()
	var measured := {}
	for region: String in REGIONS:
		var world: Node3D = load(REGIONS[region]).new()
		root.add_child(world)
		await physics_frame
		await physics_frame
		var found := SceneStandards.audit(world, region)
		measured[region] = {}
		print("SCENE %s: %s" % [region, SceneStandards.summary(found)])
		for rule: String in SceneStandards.RULES:
			var count: int = (found[rule] as Array).size()
			measured[region][rule] = count
			var allowed := int((baseline.get(region, {}) as Dictionary).get(rule, 0))
			if not writing:
				_check(count <= allowed, "%s has %d '%s' violations, more than the %d on record: %s" % [region, count, rule, allowed, _first(found[rule])])
			if listing:
				for entry: Dictionary in found[rule]:
					print("  %s  %s  %s" % [rule, entry.where, entry.detail])
		world.free()
		await process_frame
	if writing:
		var file := FileAccess.open(ProjectSettings.globalize_path(BASELINE_PATH), FileAccess.WRITE)
		file.store_string(JSON.stringify(measured, "\t") + "\n")
		print("Wrote ", BASELINE_PATH)
	if failures == 0:
		print("PASS: scene standards hold or improve in all %d regions (%d checks)" % [REGIONS.size(), checks])
	quit(1 if failures > 0 else 0)


func _first(entries: Array) -> String:
	return "" if entries.is_empty() else "%s (%s)" % [str(entries[0].where), str(entries[0].detail)]


## The audit must catch a planted violation of each tree-level rule.
func _self_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.5, 1.0)
	block.mesh = box
	var flat := StandardMaterial3D.new()
	flat.albedo_color = Color("#ff00aa")
	block.material_override = flat
	world.add_child(block)
	var rail := MeshInstance3D.new()
	var thin := BoxMesh.new()
	thin.size = Vector3(3.0, 0.1, 0.1)
	rail.mesh = thin
	rail.material_override = flat
	world.add_child(rail)
	var proxy := MeshInstance3D.new()
	proxy.mesh = SphereMesh.new()
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	world.add_child(proxy)
	var found := SceneStandards.audit(world, "self-test")
	_check((found["flat_block"] as Array).size() == 1, "a large single-colour box is reported, a thin rail is not")
	_check(str(found["flat_block"][0].where).begins_with(str(world.get_path_to(block))) and str(found["flat_block"][0].detail).contains("2.0"), "the report names the offending node and its size")
	_check((found["primitive_shadow"] as Array).size() == 1, "a sphere used only to cast a shadow is reported")
	var textured := StandardMaterial3D.new()
	textured.albedo_texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	block.material_override = textured
	_check((SceneStandards.audit(world, "self-test")["flat_block"] as Array).is_empty(), "a textured surface passes")
	for index in SceneStandards.DEFAULT_NODE_BUDGET:
		world.add_child(Node.new())
	_check((SceneStandards.audit(world, "self-test")["node_budget"] as Array).size() == 1, "exceeding the node budget is reported")
	world.free()
