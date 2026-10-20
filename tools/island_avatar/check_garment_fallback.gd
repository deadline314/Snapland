extends SceneTree
## Default human authored cels plus legacy runtime requests: an unregistered partial preview never leaks live.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var profile:=OS.get_environment("SNAPLAND_SAVE_PATH")
	if not profile.is_absolute_path():quit(2);return
	var guide_path:=OS.get_environment("SNAPLAND_GARMENT_GUIDE")
	if not guide_path.is_absolute_path() or FileAccess.get_sha256(guide_path)!=OS.get_environment("SNAPLAND_GARMENT_GUIDE_SHA256"):quit(2);return
	var guide: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(guide_path))
	var expected:=OS.get_environment("SNAPLAND_GARMENT_REQUIRED_COUNT").to_int()
	if expected<=0:quit(2);return
	var progress:=root.get_node_or_null("Progress")
	if progress==null or not progress.wardrobe_item(str(guide.outfit)).is_empty():
		push_error("An inspection-only garment is exposed in the real wardrobe catalog");quit(1);return
	var avatar=preload("res://game/world/avatar_renderer.gd").new()
	var required: Dictionary=avatar.animation_library.manifest.outfit_required_poses.traveller
	var records: Array = []
	if avatar.animation_library.outfit_variant_ready("traveller",str(guide.outfit)):
		push_error("An incomplete garment preview was incorrectly enabled");quit(1);return
	for action in required:
		for direction in required[action]:
			for frame in int(required[action][direction]):
				var base: Texture2D=avatar.texture({}, {"outfit":"outfit-tide"},str(direction),frame,str(action))
				var candidate: Texture2D=avatar.texture({}, {"outfit":str(guide.outfit)},str(direction),frame,str(action))
				if base==null or candidate==null or base.get_image().get_data()!=candidate.get_image().get_data():
					push_error("Partial garment changed a live original cel: %s/%s/%d"%[action,direction,frame]);quit(1);return
				records.append({"action":action,"direction":direction,"frame":frame,"live_original_equal":true})
				if records.size()%24==0:print("GARMENT FALLBACK: ",records.size()," original cels retained")
	if records.size()!=expected:push_error("Required coverage changed; review the authoring baseline");quit(1);return
	var fallback_records: Array = []
	for action in avatar.ACTIONS:
		if required.has(action) and not required[action].is_empty(): continue
		for direction in avatar.WALK_DIRECTIONS:
			for frame in range(3):
				var base: Texture2D=avatar.texture({}, {"outfit":"outfit-tide"},direction,frame,action)
				var candidate: Texture2D=avatar.texture({}, {"outfit":str(guide.outfit)},direction,frame,action)
				if base==null or candidate==null or base.get_image().get_data()!=candidate.get_image().get_data():
					push_error("Partial garment changed a legacy runtime request: %s/%s/%d"%[action,direction,frame]);quit(1);return
				fallback_records.append({"action":action,"direction":direction,"frame":frame,"live_original_equal":true})
	if fallback_records.size()!=OS.get_environment("SNAPLAND_GARMENT_FALLBACK_COUNT").to_int():
		push_error("Runtime fallback inventory changed; review coverage");quit(1);return
	var folder:=profile.get_base_dir();DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder.path_join("fallback-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"count":records.size(),"records":records,"runtime_fallback_request_count":fallback_records.size(),"runtime_fallback_requests":fallback_records,"total_renderer_requests":records.size()+fallback_records.size(),"fallback_requests_are_authored_art":false,"outfit_registered":false,"appearance_scope":"default human / original windswept hair"},"  "))
	print("PASS: live garment fallback ",records.size()," original cels + ",fallback_records.size()," legacy requests; no partial outfit, altered body or wardrobe catalog item")
	quit()
