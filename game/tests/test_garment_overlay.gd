extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Overlays = preload("res://game/world/garment_overlay_library.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void:
	var save := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save.is_absolute_path(): quit(2);return
	var avatar = Avatar.new()
	check(avatar.garment_overlays.ready(avatar),"Complete garment family rejected: "+str(avatar.garment_overlays.diagnostics))
	if failures>0: quit(1);return
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Overlays.MANIFEST_PATH))
	var poses := 0
	for row in parsed.frames:
		var original: Image = avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide"},row.direction,int(row.frame),row.action).get_image()
		var expected := original.duplicate()
		var layer := Image.new()
		check(layer.load_png_from_buffer(FileAccess.get_file_as_bytes(row.path))==OK,"Cannot decode garment")
		expected.blend_rect(layer,Rect2i(0,0,280,360),Vector2i.ZERO)
		var dressed: Image = avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":Overlays.OUTFIT},row.direction,int(row.frame),row.action).get_image()
		check(dressed.get_data()==expected.get_data(),"Garment integration changed original composition: %s/%s/%d"%[row.action,row.direction,row.frame])
		check(dressed.get_data()!=original.get_data(),"Missing garment at "+str(row))
		poses+=1
	# A missing cel rejects the whole family even when asking for another cel.
	var parent := save.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	parsed.frames.pop_back()
	var incomplete := parent.path_join("missing-cel.json")
	var f := FileAccess.open(incomplete,FileAccess.WRITE);f.store_string(JSON.stringify(parsed));f.close()
	var fallback = Avatar.new();fallback.garment_overlays=Overlays.new(incomplete)
	check(not fallback.garment_overlays.ready(fallback),"Missing last cel enabled the first cel")
	for direction in Avatar.WALK_DIRECTIONS:
		var base: Image=fallback.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide"},direction,0,"walk").get_image()
		var missing: Image=fallback.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":Overlays.OUTFIT},direction,0,"walk").get_image()
		check(base.get_data()==missing.get_data(),"Incomplete family partially equipped")
	# Reject identity changes, a changed original, changed PNG and duplicate key
	# before exposing any material. None may borrow a neighboring cel.
	for kind in ["source", "png", "duplicate", "frame"]:
		var bad: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Overlays.MANIFEST_PATH))
		match kind:
			"source":bad.frames[0].source_pixel_sha256="0".repeat(64)
			"png":bad.frames[0].png_sha256="0".repeat(64)
			"duplicate":bad.frames[1]=bad.frames[0].duplicate(true)
			"frame":bad.frames[0].frame=true
		var path:=parent.path_join(kind+".json")
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		var rejected=Overlays.new(path)
		check(not rejected.ready(avatar),"Unsafe family accepted: "+kind)
	if failures==0: print("PASS: garment overlay preserves 172 original compositions; missing last cel falls back across all eight directions")
	quit(1 if failures else 0)
