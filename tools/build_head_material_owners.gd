extends SceneTree
## Capture immutable-cel material boundaries for subsequent visual approval.
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")

func _initialize() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(output.is_absolute_path(), "head-owner output must be an explicit absolute path")
	var renderer := AvatarRenderer.new()
	# This table owns the original legacy source cels. Registered-canvas owners
	# are derived separately by tools/walk_stability/build_owners.py.
	renderer._stable_walk_pixels.manifest.clear()
	renderer.animation_library._stable_walk_pixels.manifest.clear()
	var existing_owners: Dictionary=renderer._head_material_owners.duplicate(true)
	var preserve_existing := OS.get_cmdline_user_args().has("--preserve-existing-hair-masks")
	renderer._head_material_owners.clear()
	# Manually traced lower hair/garment boundaries on the eight reference
	# walk cels. They produce review candidates; they are not acceptance.
	var boundaries := {
		"front":[[0,181],[90,181],[96,185],[108,182],[121,178],[172,178],[181,185],[188,188],[188,180],[280,180]],
		"front_right":[[0,162],[89,168],[108,176],[125,181],[157,177],[185,165],[215,160],[280,160]],
		"right":[[0,170],[108,177],[132,174],[145,168],[171,174],[210,175],[280,175]],
		"back_right":[[0,175],[100,176],[156,175],[172,170],[190,168],[280,168]],
		"back":[[0,176],[85,176],[105,171],[146,170],[181,173],[204,177],[280,177]],
		"back_left":[[0,168],[88,168],[109,172],[128,175],[181,176],[280,176]],
		"left":[[0,175],[90,175],[117,174],[141,168],[160,174],[184,177],[280,170]],
		"front_left":[[0,160],[80,160],[105,165],[135,177],[166,181],[183,176],[204,168],[280,162]],
	}
	var references := {}
	for direction in AvatarRenderer.WALK_DIRECTIONS:
		var raw: Image=renderer._walk_pose_image(direction,0)
		references[direction]=renderer._walk_source_hair_metrics(direction,0,raw).source_bounds
	var poses: Array = []
	for direction in AvatarRenderer.WALK_DIRECTIONS:
		for action in ["idle","walk"]:
			var count: int = renderer.walk_frame_count(direction) if action == "walk" else renderer.authored_frame_count(action,direction)
			for frame in range(count): poses.append([action,direction,frame])
	for action in ["wave","photograph","interact","jump","sit","catch","celebrate"]:
		for frame in range(renderer.authored_frame_count(action,"front")): poses.append([action,"front",frame])
	var owners := {}
	for pose in poses:
		var source: Image = renderer._walk_pose_image(pose[1],pose[2]) if pose[0] == "walk" else renderer.animation_library.texture("traveller",pose[0],pose[1],pose[2]).get_image()
		var metrics: Dictionary = renderer._walk_source_hair_metrics(pose[1],pose[2],source) if pose[0] == "walk" else renderer._authored_source_hair_metrics(source,pose[1],pose[0],pose[2])
		var signature := renderer.head_source_signature(source)
		var boundary := int(metrics.body_start_y)
		if owners.has(signature):
			assert(int(owners[signature].body_start_y) == boundary, "identical body source cannot have conflicting material owners")
		else:
			var reference: Rect2i=references[pose[1]]
			var actual: Rect2i=metrics.source_bounds
			var candidate := _candidate_ink_boundary(renderer,source,metrics)
			if preserve_existing and existing_owners.get(signature,{}).has("hair_owner_spans"):
				candidate.fill(0)
				for span: Array in existing_owners[signature].hair_owner_spans:
					for x in range(int(span[1]),int(span[2])): candidate[int(span[0])*source.get_width()+x]=1
			# Separately authored cream forelocks are hair, not exposed skin.
			# Add their actual opaque boundary only to authoring candidates.
			for index in metrics.old_forelock_indices:
				var point := Vector2i(index%source.get_width(),index/source.get_width())
				for dy in range(-2,3):
					for dx in range(-2,3):
						var neighbor := point+Vector2i(dx,dy)
						if neighbor.x<0 or neighbor.x>=source.get_width() or neighbor.y<0 or neighbor.y>=source.get_height(): continue
						var next := neighbor.y*source.get_width()+neighbor.x
						if metrics.face_mask[next]==0 and source.get_pixelv(neighbor).a>0.05: candidate[next]=1
			var scale := float(actual.size.x)/float(reference.size.x)
			var contour := PackedVector2Array([Vector2(-100,-100),Vector2(380,-100)])
			var line: Array=boundaries[pose[1]]
			for index in range(line.size()-1,-1,-1):
				var point := Vector2(float(line[index][0]),float(line[index][1]))
				contour.append(Vector2(actual.get_center().x+(point.x-reference.get_center().x)*scale,actual.position.y+(point.y-reference.position.y)*scale))
			var spans: Array=[]
			for y in range(source.get_height()):
				var start := -1
				for x in range(source.get_width()+1):
					var inside: bool=x<source.get_width() and candidate[y*source.get_width()+mini(x,source.get_width()-1)]!=0 and Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),contour)
					if inside and start<0: start=x
					if not inside and start>=0:
						spans.append([y,start,x]);start=-1
			owners[signature] = {"body_start_y":boundary,"hair_owner_spans":spans,"poses":[],"review":"candidate; source-cel boundary and rendered cuts must be reviewed"}
		owners[signature].poses.append("%s/%s/%d" % [pose[0],pose[1],pose[2]])
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"schema_version":2,"canvas_size":[280,360],"signature":"SHA256 of normalized immutable source RGBA bytes","description":"Source-cel head/body material ownership. Hair registration guides do not change coat ownership. A changed source requires regenerating and visually reviewing its boundary.","owners":owners},"\t"));file.close()
	print("WROTE: %d head/body material owner candidates; visual approval is separate" % poses.size())
	quit()

func _candidate_ink_boundary(renderer,source: Image,metrics: Dictionary) -> PackedByteArray:
	var mask: PackedByteArray=metrics.source_hair_mask.duplicate()
	var width := source.get_width()
	for pass_index in range(4):
		var expanded := mask.duplicate()
		for index in renderer._mask_indices(mask):
			var point := Vector2i(index%width,index/width)
			for dy in range(-1,2):
				for dx in range(-1,2):
					var neighbor := point+Vector2i(dx,dy)
					if neighbor.x<0 or neighbor.x>=width or neighbor.y<0 or neighbor.y>=source.get_height(): continue
					var color := source.get_pixelv(neighbor)
					if color.a>0.05 and color.v<0.30: expanded[neighbor.y*width+neighbor.x]=1
		mask=expanded
	for index in range(mask.size()):
		if metrics.face_mask[index]!=0 or index/width>=int(metrics.body_start_y): mask[index]=0
	return mask
