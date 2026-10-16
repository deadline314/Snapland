extends SceneTree
## Hair geometry stays registered; composited RGBA may vary over moving shoulders.
const Renderer := preload("res://game/world/avatar_renderer.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): quit(2); return
	var renderer := Renderer.new()
	var total := 0
	for style in ["bob", "curly"]:
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/island-hair-%s-v1.json" % style))
		var look := Renderer.DEFAULT_APPEARANCE.duplicate()
		look.hair = style
		for view in Renderer.WALK_DIRECTIONS:
			var clothes := {"outfit": "outfit-tide", "hat": "hat-none"}
			var reference: Image
			var cut: Dictionary = renderer._cached_hair_cut(style, view, Renderer.HAIR_COLORS.ink)
			for action in ["walk", "idle"]:
				var count: int = renderer.walk_frame_count(view) if action == "walk" else int(renderer._stable_idle_pixels.manifest["hero-idle/"+view].frames)
				for frame in range(count):
					var raw: Image = renderer._walk_pose_image(view,frame) if action == "walk" else renderer._stable_idle_pixels.frame("hero-idle",view,frame)
					var metrics: Dictionary = renderer._walk_source_hair_metrics(view,frame,raw)
					var placement: Dictionary = renderer._registered_hair_placement(raw.get_size(),view,cut.image,0,0,190.0,raw,metrics,cut)
					var source := Image.create(280,360,false,Image.FORMAT_RGBA8)
					source.fill(Color.TRANSPARENT)
					source.blit_rect(placement.image,Rect2i(Vector2i.ZERO,placement.image.get_size()),placement.position)
					if reference == null: reference = source.duplicate()
					var differences := 0
					for strand: Dictionary in profile.directions[view].strands:
						for span: Array in strand.spans:
							for x in range(int(span[1]),int(span[2])+1):
								if source.get_pixel(x,int(span[0])) != reference.get_pixel(x,int(span[0])): differences += 1
					if differences > 0: failures.append("%s/%s/%s/%d moving ownership changed %d pixels" % [style,view,action,frame,differences])
					total += 1
	if failures.is_empty(): print("PASS: alternate island hair ownership remains registered across ",total," actual walk and idle/blink cels")
	else: printerr("FAIL: "+"; ".join(failures))
	quit(0 if failures.is_empty() else 1)
