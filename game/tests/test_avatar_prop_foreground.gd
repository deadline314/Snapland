extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Foreground = preload("res://game/world/avatar_prop_foreground.gd")
const CAMERA_CENTERS := {"front":Vector2i(145,235),"front_left":Vector2i(127,225),"front_right":Vector2i(166,224),"left":Vector2i(110,225),"right":Vector2i(193,225)}
## The source hand brings the side camera inward during the stride. These
## lens witnesses are inspected on the eight original cels, not mask output.
const RIGHT_WALK_CAMERA_X := [198,189,182,174,179,174,170,170]
var failures: Array[String] = []
func _initialize() -> void:
	var save := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save.is_absolute_path(): quit(2); return
	DirAccess.make_dir_recursive_absolute(save.get_base_dir())
	var avatar := Avatar.new()
	var look: Dictionary = Avatar.DEFAULT_APPEARANCE.duplicate()
	var equipment := {"outfit":"outfit-rainvest","hat":"hat-none"}
	var original: Image = avatar.texture(look,equipment,"front_left",0,"walk").get_image()
	look.hair="curly"
	var actual: Image = avatar.texture(look,equipment,"front_left",0,"walk").get_image()
	# Independent native rejection witnesses: a skin hand, red camera body and
	# white camera highlight. These coordinates are not selected from the mask.
	for point in [Vector2i(100,225),Vector2i(115,225),Vector2i(120,225)]:
		_check(actual.get_pixelv(point)==original.get_pixelv(point),"held hand/camera hidden by curls at "+str(point))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Foreground.PATH))
	_check(manifest.cases.size()==64,"All 64 visible-camera walking/standing poses must be reviewed")
	var cases := 0
	for row in manifest.cases:
		var source: Image=avatar.original_garment_pose(row.action,row.direction,int(row.frame))
		var indices: PackedInt32Array=avatar.prop_foreground.indices(source)
		_check(not indices.is_empty(),"Exact source ownership missing: "+str(row))
		var center: Vector2i=CAMERA_CENTERS[row.direction]
		if row.action=="walk" and row.direction=="right": center=Vector2i(RIGHT_WALK_CAMERA_X[int(row.frame)],225)
		if row.action=="walk" and row.direction=="left": center=Vector2i(105,225)
		_check(indices.has(center.y*280+center.x),"Independent camera center absent: %s/%s/%s" % [row.action,row.direction,row.frame])
		var untouched := source.get_data()
		look.hair="windswept"
		var expected: Image=avatar.texture(look,equipment,row.direction,int(row.frame),row.action).get_image()
		for style in ["bob","curly"]:
			look.hair=style
			var dressed: Image=avatar.texture(look,equipment,row.direction,int(row.frame),row.action).get_image()
			var changed := 0
			for index in indices:
				var point := Vector2i(index%280,index/280)
				if dressed.get_pixelv(point)!=expected.get_pixelv(point): changed+=1
			_check(changed==0,"Held prop differs: %s/%s/%s/%d: %d" % [style,row.action,row.direction,row.frame,changed])
			cases+=1
		var guard: Image=avatar.hair_motion_attachment_guard(row.direction,int(row.frame),row.action,equipment)
		for index in indices:
			_check(guard.get_pixel(index%280,index/280)==Color.WHITE,"Rigid attachment is absent from hair-motion guard")
		_check(source.get_data()==untouched,"Foreground selection mutated original")
		var changed_source := source.duplicate()
		changed_source.set_pixel(0,0,Color.WHITE)
		_check(avatar.prop_foreground.indices(changed_source).is_empty(),"Changed source inherited old ownership")
	_check(avatar.prop_foreground._cache.size()<=Foreground.CACHE_LIMIT,"Decoded prop cache exceeded bound")
	for skin in ["warm","deep","cool"]:
		for outfit in ["outfit-tide","outfit-coral","outfit-rainvest"]:
			look.skin=skin
			look.hair="windswept"
			equipment.outfit=outfit
			var expected: Image=avatar.texture(look,equipment,"front_left",0,"walk").get_image()
			look.hair="curly"
			var dressed: Image=avatar.texture(look,equipment,"front_left",0,"walk").get_image()
			for point in [Vector2i(100,225),Vector2i(115,225),Vector2i(120,225)]:
				_check(dressed.get_pixelv(point)==expected.get_pixelv(point),"Prop restoration lost selected skin or outfit")
	var signature: String=manifest.owners.keys()[0]
	for fault in ["canvas","schema","coordinate","fraction","boolean","bounds","overlap","order","empty","hash"]:
		var broken: Dictionary=manifest.duplicate(true)
		match fault:
			"canvas": broken.canvas=[281,360]
			"schema": broken.schema_version=2
			"coordinate": broken.owners[signature].spans[0]=[0,1]
			"fraction": broken.owners[signature].spans[0][1]=1.5
			"boolean": broken.owners[signature].spans[0][0]=true
			"bounds": broken.owners[signature].spans[0][2]=281
			"overlap": broken.owners[signature].spans.insert(1,broken.owners[signature].spans[0].duplicate())
			"order": broken.owners[signature].spans.reverse()
			"empty": broken.owners[signature].spans=[]
			"hash": broken.owners["bad"]=broken.owners[signature]
		var path := save.get_base_dir().path_join(fault+".json")
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(broken))
		var invalid := Foreground.new(path)
		_check(invalid._owners.is_empty() and not invalid.diagnostics.is_empty(),"Invalid ownership accepted: "+fault)
	# Missing ownership preserves the complete original rather than stripping
	# source hair first. Use a fresh renderer to exclude a previous warm texture.
	var fallback := Avatar.new()
	fallback.prop_foreground=Foreground.new(save.get_base_dir().path_join("absent.json"))
	look=Avatar.DEFAULT_APPEARANCE.duplicate()
	equipment={"outfit":"outfit-tide","hat":"hat-none"}
	var base: Image=fallback.texture(look,equipment,"front_left",0,"walk").get_image()
	look.hair="curly"
	_check(fallback.texture(look,equipment,"front_left",0,"walk").get_image().get_data()==base.get_data(),"Rejected prop ownership stripped original hair")
	if failures.is_empty(): print("PASS: prop foreground 128 complete-pose blends, independent hand/camera witnesses, rigid guards, exact-source rejection, bounded cache and 10 malformed inputs")
	else: printerr("FAIL: "+"; ".join(failures))
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool,message: String) -> void:
	if not ok: failures.append(message)
