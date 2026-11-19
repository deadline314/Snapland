extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Foreground = preload("res://game/world/avatar_prop_foreground.gd")
const CAMERA_CENTERS := {"front":Vector2i(145,235),"front_left":Vector2i(127,225),"front_right":Vector2i(166,224),"left":Vector2i(110,225),"right":Vector2i(193,225)}
## The source hand brings the side camera inward during the stride. These
## lens witnesses are inspected on the eight original cels, not mask output.
const RIGHT_WALK_CAMERA_X := [198,189,182,174,179,174,170,170]
const PHOTO_WITNESSES := {
	"left": [
		[Vector2i(83,201),Vector2i(112,201),Vector2i(100,185)],
		[Vector2i(81,173),Vector2i(104,174),Vector2i(90,159)],
		[Vector2i(86,215),Vector2i(116,220),Vector2i(102,203)],
	],
	"right": [
		[Vector2i(212,198),Vector2i(192,196),Vector2i(201,182)],
		[Vector2i(216,164),Vector2i(193,166),Vector2i(206,149)],
		[Vector2i(204,223),Vector2i(181,223),Vector2i(197,208)],
	],
}
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
	_check_profile_photographs(avatar)
	_check_footwork(avatar)
	_check_celebration(avatar)
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

func _check_profile_photographs(avatar: Avatar) -> void:
	var equipment := {"outfit":"outfit-rainvest","hat":"hat-straw"}
	for side in PHOTO_WITNESSES:
		for frame in range(PHOTO_WITNESSES[side].size()):
			var source := avatar.original_garment_pose("photograph", side, frame)
			if source == null:
				_check(false, "Missing side photo: %s/%d" % [side, frame])
				continue
			var stats := avatar._authored_source_hair_metrics(source, side, "photograph", frame)
			_check(stats.hair_owner_valid and stats.replacement_geometry_valid, "Incomplete side photo hair ownership: %s/%d" % [side, frame])
			for point: Vector2i in PHOTO_WITNESSES[side][frame]:
				_check(source.get_pixelv(point).a > 0.9 and stats.foreground_indices.has(point.y * 280 + point.x),
					"Missing independent lens or hand witness: %s/%d/%s" % [side, frame, point])
			for skin in ["warm", "deep"]:
				var look := Avatar.DEFAULT_APPEARANCE.duplicate()
				look.skin = skin
				var plain := avatar.texture(look, {"outfit":"outfit-tide","hat":"hat-straw"}, side, frame, "photograph").get_image()
				var expected := avatar.texture(look, equipment, side, frame, "photograph").get_image()
				for point: Vector2i in PHOTO_WITNESSES[side][frame]:
					_check(expected.get_pixelv(point) == plain.get_pixelv(point),
						"Side photo rainvest covered the lens or hand: %s/%d/%s" % [side, frame, point])
				for style in ["bob", "curly"]:
					look.hair = style
					var actual := avatar.texture(look, equipment, side, frame, "photograph").get_image()
					for point: Vector2i in PHOTO_WITNESSES[side][frame]:
						_check(actual.get_pixelv(point) == expected.get_pixelv(point),
							"Side photo lens or hand changed: %s/%d/%s/%s/%s" % [side, frame, skin, style, point])

func _check_footwork(avatar: Avatar) -> void:
	var cases := [
		[{"face":"smiling"}, {"outfit":"outfit-tide","hat":"hat-none"}],
		[{"hair":"bob","skin":"deep","face":"confident"}, {"outfit":"outfit-rainvest","hat":"hat-straw"}],
		[{"hair":"curly","species":"elf","skin":"olive"}, {"outfit":"outfit-coral","hat":"hat-none"}],
	]
	for direction: String in Avatar.WALK_DIRECTIONS:
		for config in cases:
			var look := Avatar.DEFAULT_APPEARANCE.merged(config[0], true)
			var idle := avatar.texture(look, config[1], direction, 0, "idle").get_image()
			var idle_pixels := idle.get_data()
			var upper_size := 280 * 270 * 4
			for action: String in ["settle", "depart", "pivot"]:
				if not avatar.has_authored_action(action, direction): continue
				var pose := avatar.texture(look, config[1], direction, 0, action).get_image()
				var pixels := pose.get_data()
				var upper_consistent := true
				for index in range(0, upper_size, 4):
					if maxi(idle_pixels[index + 3], pixels[index + 3]) < 128: continue
					for channel in range(4):
						if absi(idle_pixels[index + channel] - pixels[index + channel]) > 2:
							upper_consistent = false
							break
					if not upper_consistent: break
				_check(upper_consistent and idle_pixels.slice(upper_size) != pixels.slice(upper_size),
					"the %s %s preserves dressed upper-body pixels and presents different feet: %s" % [direction, action, config])

func _check_celebration(avatar: Avatar) -> void:
	var base := Avatar.DEFAULT_APPEARANCE.duplicate()
	var camera_points := [Vector2i(145, 233), Vector2i(143, 242), Vector2i(151, 231), Vector2i(167, 239)]
	for frame in range(5):
		var witnesses := camera_points.duplicate()
		if frame == 2: witnesses.append(Vector2i(91, 172))
		var original := avatar.texture(base, {"outfit":"outfit-tide","hat":"hat-none"}, "front", frame, "celebrate").get_image()
		var distinct_hair := {}
		var gear := {"outfit":"outfit-rainvest","hat":"hat-none"}
		for style in ["windswept", "bob", "curly"]:
			var look := base.merged({"hair":style}, true)
			var posed := avatar.texture(look, gear, "front", frame, "celebrate").get_image()
			distinct_hair[posed.get_region(Rect2i(40, 75, 200, 78)).get_data()] = true
		_check(distinct_hair.size() == 3, "each selected haircut remains distinct throughout celebration cel %d" % frame)
		for style in ["bob", "curly"]:
			var look := base.merged({"hair":style, "face":"smiling"}, true)
			var equipment := {"outfit":"outfit-rainvest","hat":"hat-straw"}
			var dressed := avatar.texture(look, equipment, "front", frame, "celebrate").get_image()
			for point: Vector2i in witnesses:
				_check(dressed.get_pixelv(point) == original.get_pixelv(point),
					"celebration preserves the camera and raised hand under the %s outfit at %d/%s" % [style, frame, point])
			if frame != 4: continue
			var neutral := avatar.texture(look, equipment, "front", 0, "idle").get_image()
			var actual := dressed.get_data()
			var expected := neutral.get_data()
			var consistent := true
			for index in range(0, actual.size(), 4):
				if maxi(actual[index + 3], expected[index + 3]) < 128: continue
				for channel in range(4):
					if absi(actual[index + channel] - expected[index + channel]) <= 2: continue
					consistent = false
					break
				if not consistent: break
			_check(consistent, "the last celebration cel restores the exact %s dressed idle and expression" % style)

func _check(ok: bool,message: String) -> void:
	if not ok: failures.append(message)
