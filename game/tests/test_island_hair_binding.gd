extends SceneTree
## Compare real rendering to independent original RGBA, as Sprite3D samples it.
const Renderer := preload("res://game/world/avatar_renderer.gd")
const Rig := preload("res://game/world/avatar_hair_rig.gd")
var failures: Array[String] = []
var cases: Array = []
var output := ""
var last_original: Image
var rig: SubViewport

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("SNAPLAND_ISLAND_HAIR_DIR")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path():
		printerr("FAIL island hair pixel test requires native rendering and absolute isolated output")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var renderer := Renderer.new()
	rig = Rig.new()
	root.add_child(rig)
	if rig.root_bone == null:
		printerr("FAIL island hair did not initialize")
		quit(1)
		return
	await process_frame
	for view in Renderer.WALK_DIRECTIONS:
		for hat in ["hat-none", "hat-straw", "hat-sailor", "hat-flower"]:
			var look := Renderer.DEFAULT_APPEARANCE.duplicate()
			var clothes := {"outfit": "outfit-tide", "hat": hat}
			var source: Texture2D = renderer.texture(look, clothes, view, 0, "walk")
			last_original = source.get_image()
			var used: Texture2D = rig.sync_pose(source, renderer, look, clothes, view, 0, "walk")
			_check(rig.active and used == rig.get_texture(), "island rig must be active: " + view + "/" + hat)
			await _draw()
			var before := rig.get_texture().get_image()
			var expected := last_original
			var rest_error := _difference(before, expected)
			_check(rest_error == 0, "rest pixels differ from independent original: %s/%s/%d" % [view, hat, rest_error])
			for i in range(18): rig.advance(1.0 / 60.0, Vector2(200, 95))
			await _draw()
			var moving := rig.get_texture().get_image()
			var protected_error := _difference(moving, expected, _allowed(view))
			var moved := _difference(moving, before)
			_check(protected_error == 0, "face/body/hat drift outside authored tuft envelope: %s/%s/%d" % [view, hat, protected_error])
			if hat == "hat-none": _check(moved > 0, "bones must actually change visible hair pixels: " + view)
			_check(rig.root_bone.transform == Transform2D.IDENTITY, "head root moved: " + view)
			var snapshot: Dictionary = rig.receipt()
			rig.advance(0.2, Vector2.ZERO, true)
			_check(rig.receipt() == snapshot, "pause changed hair state")
			for i in range(180): rig.advance(1.0 / 60.0, Vector2.ZERO)
			await _draw()
			var settled := _difference(rig.get_texture().get_image(), expected)
			_check(settled == 0, "stopped hair must settle to exact original: %s/%s/%d" % [view, hat, settled])
			cases.append({"direction": view, "hat": hat, "rest_error": rest_error, "protected_error": protected_error, "moving_pixels": moved, "settled_error": settled})
			before.save_png(output.path_join(view + "-" + hat + "-rest.png"))
			moving.save_png(output.path_join(view + "-" + hat + "-moving.png"))
	# A deliberate one-pixel body shift must be caught by the same pixel check.
	rig._body.position.x = 1.0
	await _draw()
	_check(_difference(rig.get_texture().get_image(), last_original, _allowed("front_left")) > 50, "one-pixel drift negative control did not fail")
	rig._body.position.x = 0.0
	var look := Renderer.DEFAULT_APPEARANCE.duplicate()
	var clothes := {"outfit": "outfit-tide", "hat": "hat-none"}
	var source: Texture2D = renderer.texture(look, clothes, "front", 0, "idle")
	rig.set_motion_enabled(false)
	_check(rig.sync_pose(source, renderer, look, clothes, "front", 0, "idle") == source and not rig.active, "off mode must return untouched original")
	rig.set_motion_enabled(true)
	look.hair = "bob"
	_check(rig.sync_pose(source, renderer, look, clothes, "front", 0, "idle") == source and not rig.active, "uncovered styles must remain whole original actors")
	look.hair = "windswept"
	_check(rig.sync_pose(source, renderer, look, clothes, "front", 0, "photograph") == source and not rig.active, "photograph must keep its authored hand/camera occlusion")
	rig._source_valid.clear()
	rig._profile.directions.front.source_pixels_sha256 = "deliberately invalid"
	_check(rig.sync_pose(source, renderer, look, clothes, "front", 0, "idle") == source and not rig.active, "changed source must safely retain complete original")
	var result := {"result": "PASS_NATIVE_ISLAND_HAIR_PIXELS" if failures.is_empty() else "FAIL", "cases": cases, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(), "negative_control": "one-pixel static-body shift detected", "scope": "Native 2D viewport pixels, 8 directions x all 4 hat states; not a game playthrough."}
	var file := FileAccess.open(output.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	if failures.is_empty(): print("PASS: native island hair pixels 32 direction/hat cases; original rest, protected pixels, moving tips, settle, pause and negative controls")
	else: printerr("FAIL: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)

func _draw() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

func _allowed(view: String) -> Image:
	var mask := Image.create(280, 360, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for strand: Dictionary in rig._profile.directions[view].strands:
		for span: Array in strand.cut_spans:
			for y in range(maxi(0, int(span[0]) - 6), mini(360, int(span[0]) + 7)):
				for x in range(maxi(0, int(span[1]) - 6), mini(280, int(span[2]) + 7)): mask.set_pixel(x, y, Color.WHITE)
	return mask

func _difference(a: Image, b: Image, allowed: Image = null) -> int:
	if a.get_size() != b.get_size(): return 100000
	var changed := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if allowed != null and allowed.get_pixel(x, y).a > 0.0: continue
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if p.a == 0.0 and q.a == 0.0: continue
			if p != q: changed += 1
	return changed

func _check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
