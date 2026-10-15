extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _run() -> void:
	if not FileAccess.file_exists("res://game/world/hero_2d_hair_rig.gd"):
		printerr("FAIL missing 2D hair rig: root weights and native mesh are not available")
		quit(1)
		return
	var library = load("res://game/world/hero_2d_library.gd").new()
	root.add_child(library)
	var rig = load("res://game/world/hero_2d_hair_rig.gd").new()
	library.add_child(rig)
	check(rig.initialize(library), "rig must initialize using the existing 2D library")
	for direction in library.DIRECTIONS:
		for hat in [false,true]:
			for outfit in ["tide_jacket","long_coat"]:
				library.set_appearance("windswept",hat,outfit)
				for action in ["idle","start","walk","stop","turn","photo"]:
					var frames: Array = library.manifest.poses[direction][action]
					for index in range(frames.size()):
						var state := {"action":action,"direction":direction,"visual_direction":direction,"frame":index}
						var original: Image = library.compose_frame(state)
						var layers: Dictionary = library.get_hair_rig_layers(state)
						var composite: Image = layers.body.duplicate()
						var position: Vector2 = layers.head + Vector2(140,346) - layers.anchor
						composite.blend_rect(layers.hair,Rect2i(Vector2i.ZERO,layers.hair.get_size()),Vector2i(position))
						composite.blend_rect(layers.foreground,Rect2i(Vector2i.ZERO,composite.get_size()),Vector2i.ZERO)
						check(original.get_data()==composite.get_data(), "rig layers preserve exact original pixels in %s/%s/%s/%s" % [direction,str(hat),outfit,action])
				var state := {"action":"idle","direction":direction,"visual_direction":direction,"frame":0}
				rig.sync_pose(state)
				check(rig.skeleton is Skeleton2D and rig.root_bone is Bone2D and rig.mesh is Polygon2D,"use actual Godot 2D bones and weighted mesh")
				var receipt: Dictionary = rig.geometry_receipt()
				check(receipt.protected_weight_error < 0.00001 and receipt.weight_sum_error < 0.00001,"all roots and protected hat vertices are rigid with normalized weights")
				check(receipt.mobile_vertices > 5,"hair tips must actually have moving weights")
				var head: Vector2 = rig.skeleton.position
				for i in range(20): rig.advance(1.0/60.0,Vector2.RIGHT*90.0,state)
				check(rig.skeleton.position==head and rig.root_bone.transform==Transform2D.IDENTITY,"hair root transform must never inherit tip motion")
				var before: Dictionary = rig.motion_receipt()
				rig.advance(0.2,Vector2.ZERO,state,true)
				check(rig.motion_receipt()==before,"rig pause freezes bone transforms and spring history")
				rig.set_motion_enabled(false)
				check(library.get_node("Hero2DComposite").visible and not rig.visible,"off mode restores untouched original compositor")
				rig.set_motion_enabled(true)
	library.set_appearance("windswept",false,"tide_jacket")
	var walking := {"action":"walk","direction":"left","visual_direction":"left","frame":0}
	rig.sync_pose(walking)
	var reference: Vector2 = rig.skeleton.position
	walking.frame = 1
	rig.sync_pose(walking)
	check(rig.skeleton.position==reference,"a rigid authored head must not inherit the discarded source cel jitter")
	check(rig.mesh.position==rig.skeleton.position,"weighted mesh and root share the same per-cel head attachment")
	library.free()
	if failures.is_empty(): print("PASS 2D hair rig: 640 exact rest composites, protected roots/hats, weighted native bones, pause and original fallback")
	else: printerr("FAIL "+"; ".join(failures.slice(0,10)))
	quit(0 if failures.is_empty() else 1)
