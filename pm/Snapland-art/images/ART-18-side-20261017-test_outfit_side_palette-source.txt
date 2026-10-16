extends SceneTree
const Renderer := preload("res://game/world/avatar_renderer.gd")
var failures: Array[String] = []
var cases := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var save := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save.is_absolute_path(): quit(2); return
	var out := save.get_base_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var renderer := Renderer.new()
	var look: Dictionary = Renderer.DEFAULT_APPEARANCE.duplicate()
	for direction in ["left","right"]:
		for action in ["walk","idle"]:
			var count := 8 if action=="walk" else 4
			for frame in range(count):
				var source: Image = renderer._walk_pose_image(direction,frame) if action=="walk" else renderer._stable_idle_pixels.frame("hero-idle",direction,frame)
				var mask: PackedByteArray = renderer._side_coat_mask(source)
				_check(not mask.is_empty(), "reviewed side material exists: %s/%s/%d"%[direction,action,frame])
				var base: Image = renderer.texture(look,{"outfit":"outfit-tide","hat":"hat-none"},direction,frame,action).get_image()
				for outfit in ["outfit-coral","outfit-gold","outfit-navy"]:
					var actual: Image = renderer.texture(look,{"outfit":outfit,"hat":"hat-none"},direction,frame,action).get_image()
					var changes := 0
					var outside := 0
					for index in range(280*360):
						var point := Vector2i(index%280,index/280)
						if actual.get_pixelv(point)!=base.get_pixelv(point):
							changes+=1
							if mask.is_empty() or mask[index]==0: outside+=1
					_check(changes>500 and outside==0,"only reviewed cloth changes: %s/%s/%d/%s (%d outside)"%[direction,action,frame,outfit,outside])
					cases+=1
	# Independent observed sleeve witness: before this fix it stayed (4,105,130).
	for style in ["windswept","bob","curly"]:
		look.hair=style
		var image: Image = renderer.texture(look,{"outfit":"outfit-coral","hat":"hat-none"},"right",2,"walk").get_image()
		var sleeve := image.get_pixel(135,210)
		var hem := image.get_pixel(135,245)
		_check(absf(hem.r-182.0/255)<0.012 and absf(hem.g-95.0/255)<0.012 and absf(hem.b-81.0/255)<0.012,"independent exposed coral hem witness for "+style)
		if style=="curly":
			var blue: Image = renderer.texture(look,{"outfit":"outfit-tide","hat":"hat-none"},"right",2,"walk").get_image()
			# The translucent tuft edge naturally blends with cloth behind it.
			# Its opaque core must stay exact, and the edge must retain hair colour.
			_check(image.get_pixel(135,100)==blue.get_pixel(135,100) and image.get_pixel(135,100).a>0.95,"opaque curly hair core retains exact colour")
			_check(sleeve.b>sleeve.r,"curly tuft edge remains blue over coral cloth")
		else:
			_check(absf(sleeve.r-230.0/255)<0.012 and absf(sleeve.g-120.0/255)<0.012 and absf(sleeve.b-103.0/255)<0.012,"independent coral sleeve witness for "+style)
		image.save_png(out.path_join(style+"-coral-right.png"))
	# Changed visible source pixels must not inherit an unrelated ownership mask.
	var changed: Image = renderer._walk_pose_image("right",2).duplicate()
	changed.set_pixel(135,210,Color.WHITE)
	_check(renderer._side_coat_mask(changed).is_empty(),"changed source rejects old material ownership")
	_check(renderer._side_coat_cache.size()<=Renderer.SIDE_COAT_CACHE_LIMIT,"material cache stays bounded")
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"engine":Engine.get_version_info().string,"scope":"24 side walk/idle cels across three alternate palette targets, original hair; independent witness also checked with bob/curly"},"\t"))
	if failures.is_empty(): print("PASS: side jacket palette, 72 source-bound cases, exposed cloth witnesses and curly hair occlusion")
	else: printerr("FAIL: "+"; ".join(failures))
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool,label: String)->void:
	if not ok: failures.append(label)
