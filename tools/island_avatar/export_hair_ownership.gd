extends SceneTree
## Offline authoring only: use the compositor's registered layer and occluders.
const Renderer := preload("res://game/world/avatar_renderer.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var output := OS.get_environment("SNAPLAND_HAIR_AUTHOR_DIR")
	if not output.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var renderer := Renderer.new()
	for style in ["bob", "curly"]:
		for view in Renderer.WALK_DIRECTIONS:
			var raw: Image = renderer._walk_pose_image(view, 0)
			var metrics: Dictionary = renderer._walk_source_hair_metrics(view, 0, raw)
			var cut: Dictionary = renderer._cached_hair_cut(style, view, Renderer.HAIR_COLORS.ink)
			var placement: Dictionary = renderer._registered_hair_placement(raw.get_size(), view, cut.image, 0, 0, 190.0, raw, metrics, cut)
			var mask := Image.create(280, 360, false, Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)
			mask.blit_rect(placement.image, Rect2i(Vector2i.ZERO, placement.image.get_size()), placement.position)
			# Face and foreground features are restored after hair in production.
			for index in metrics.face_indices: mask.set_pixel(index % 280, index / 280, Color.TRANSPARENT)
			for index in metrics.foreground_indices: mask.set_pixel(index % 280, index / 280, Color.TRANSPARENT)
			mask.save_png(output.path_join(style + "-" + view + "-ownership.png"))
			var look := Renderer.DEFAULT_APPEARANCE.duplicate()
			look.hair = style
			renderer.texture(look, {"outfit": "outfit-tide", "hat": "hat-none"}, view, 0, "walk").get_image().save_png(output.path_join(style + "-" + view + "-source.png"))
			# Moving shoulders/hands must never become a removable silhouette edge.
			var union_alpha := Image.create(280,360,false,Image.FORMAT_RGBA8)
			union_alpha.fill(Color.TRANSPARENT)
			for action in ["walk","idle"]:
				var count: int = renderer.walk_frame_count(view) if action == "walk" else int(renderer._stable_idle_pixels.manifest["hero-idle/"+view].frames)
				for frame in range(count):
					var source: Image = renderer.texture(look, {"outfit":"outfit-tide","hat":"hat-none"}, view, frame, action).get_image()
					for y in range(360):
						for x in range(280):
							if source.get_pixel(x,y).a > 0.0: union_alpha.set_pixel(x,y,Color.WHITE)
			union_alpha.save_png(output.path_join(style+"-"+view+"-union-alpha.png"))
	print("PASS: exported registered hair ownership for two styles and eight views")
	quit()
