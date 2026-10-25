extends SceneTree
## Real family traversal, eviction/reload and actual filesystem faults.
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Overlays = preload("res://game/world/garment_overlay_library.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: push_error(message);failures+=1
func _initialize() -> void:
	var save := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save.is_absolute_path():quit(2);return
	var parent := save.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var avatar = Avatar.new()
	var family = Overlays.new()
	check(family.ready(avatar),"Valid family rejected")
	check(family.cache_snapshot().decoded_images==0,"Preflight retained decoded canvases")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Overlays.MANIFEST_PATH))
	var rows: Array=manifest.frames
	var initial_source: Image=avatar.original_garment_pose(rows[0].action,rows[0].direction,int(rows[0].frame))
	var original_hash := avatar.head_source_signature(initial_source)
	for reverse in [false,true]:
		var traversal:=rows.duplicate()
		if reverse:traversal.reverse()
		for row in traversal:
			var target:=initial_source.duplicate()
			check(family.apply(avatar,target,row.action,row.direction,int(row.frame)),"Evicted cel could not reload")
			var layer:=Image.new()
			check(layer.load_png_from_buffer(FileAccess.get_file_as_bytes(row.path))==OK,"Reference PNG did not decode")
			var expected:=initial_source.duplicate()
			expected.blend_rect(layer,Rect2i(0,0,280,360),Vector2i.ZERO)
			check(target.get_data()==expected.get_data(),"Reload changed actual fabric pixels")
			var stats: Dictionary=family.cache_snapshot()
			check(stats.decoded_images<=12 and stats.decoded_bytes<=4838400,"Decoded family cache exceeded 4.62 MiB")
	var first: Dictionary=rows[0]
	var before: Dictionary=family.cache_snapshot()
	for index in 512:
		check(family.apply(avatar,initial_source.duplicate(),first.action,first.direction,int(first.frame)),"Warm cel vanished")
	var after: Dictionary=family.cache_snapshot()
	check(after.verified_decodes==before.verified_decodes and after.cache_hits-before.cache_hits==512,"Warm animation decoded resources again")
	check(avatar.head_source_signature(initial_source)==original_hash,"Compositing mutated immutable source")
	var wrong_canvas:=Image.create(20,20,false,Image.FORMAT_RGBA8)
	wrong_canvas.fill(Color.MAGENTA)
	check(not family.apply(avatar,wrong_canvas,first.action,first.direction,int(first.frame)) and wrong_canvas.get_pixel(0,0)==Color.MAGENTA,"Wrong target canvas was modified")
	check(family.ready(avatar),"Caller canvas error invalidated valid resources")
	family.clear_cache()
	check(family.cache_snapshot().decoded_images==0 and family.ready(avatar),"Releasing decoded canvases lost validation")
	# Each fault uses a unique real raw asset; never mutate shipping originals.
	var transient := Overlays.MANIFEST_PATH.get_base_dir().path_join(".cache-reload-%d.pngdata" % OS.get_process_id())
	check(not FileAccess.file_exists(transient),"Refusing to overwrite an existing cache fixture")
	if FileAccess.file_exists(transient):quit(1);return
	for fault in ["missing","changed"]:
		var bytes:=FileAccess.get_file_as_bytes(first.path)
		var asset:=FileAccess.open(transient,FileAccess.WRITE)
		check(asset!=null,"Cannot create isolated resource fault")
		if asset==null:quit(1);return
		asset.store_buffer(bytes);asset.close()
		var fault_manifest:=manifest.duplicate(true)
		fault_manifest.frames[0].path=transient
		var path:=parent.path_join(fault+"-after-preflight.json")
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(fault_manifest));file.close()
		var damaged=Overlays.new(path)
		check(damaged.ready(avatar),"Fault fixture was not initially a valid complete family")
		var wearer=Avatar.new()
		wearer.garment_overlays=damaged
		var neighboring: Dictionary=rows[1]
		var undressed: Image=wearer.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide"},neighboring.direction,int(neighboring.frame),neighboring.action).get_image()
		var dressed: Image=wearer.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":Overlays.OUTFIT},neighboring.direction,int(neighboring.frame),neighboring.action).get_image()
		check(dressed.get_data()!=undressed.get_data(),"Renderer fault fixture never wore fabric")
		# Populate and then evict the exact resource which will be damaged.
		for row in rows.slice(0,14):
			check(damaged.apply(avatar,initial_source.duplicate(),row.action,row.direction,int(row.frame)),"Could not warm eviction fixture")
		if fault=="missing":
			check(DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))==OK,"Cannot remove isolated asset")
		else:
			bytes[bytes.size()-1]=bytes[bytes.size()-1]^1
			asset=FileAccess.open(transient,FileAccess.WRITE);asset.store_buffer(bytes);asset.close()
		var target:=initial_source.duplicate()
		check(not damaged.apply(avatar,target,first.action,first.direction,int(first.frame)),"Damaged evicted cel rendered fabric")
		check(target.get_data()==initial_source.get_data(),"Reload failure partially painted target")
		check(not damaged.ready(avatar) and damaged.cache_snapshot().decoded_images==0 and damaged.cache_snapshot().validated_cels==0,"Reload failure retained a partially usable family")
		check(damaged.diagnostics.size()==1 and "/" in damaged.diagnostics[0],"Reload failure lost precise cel diagnostic")
		var other: Dictionary=rows[1]
		check(not damaged.apply(avatar,target,other.action,other.direction,int(other.frame)),"A neighboring cel survived a rejected family")
		check(damaged.diagnostics.size()==1,"Rejected family repeated diagnostics")
		var recovered: Image=wearer.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":Overlays.OUTFIT},neighboring.direction,int(neighboring.frame),neighboring.action).get_image()
		check(recovered.get_data()==undressed.get_data(),"Renderer retained stale dressed texture after whole-family rejection")
		if FileAccess.file_exists(transient):DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))
	# Even a matching manifest hash must not permit an oversized PNG allocation.
	var huge:=FileAccess.get_file_as_bytes(first.path)
	huge[16]=127;huge[17]=255;huge[18]=255;huge[19]=255
	var forged:=FileAccess.open(transient,FileAccess.WRITE)
	forged.store_buffer(huge);forged.close()
	var forged_manifest:=manifest.duplicate(true)
	forged_manifest.frames[0].path=transient
	forged_manifest.frames[0].png_sha256=FileAccess.get_sha256(transient)
	var forged_path:=parent.path_join("oversized-header.json")
	var record:=FileAccess.open(forged_path,FileAccess.WRITE)
	record.store_string(JSON.stringify(forged_manifest));record.close()
	var oversized=Overlays.new(forged_path)
	check(not oversized.ready(avatar) and oversized.diagnostics[0].begins_with("Invalid garment canvas header:"),"Huge PNG reached the decoder")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))==OK,"Could not clean owned malformed PNG")
	print("CACHE_METRICS: ",JSON.stringify(after))
	if failures==0:print("PASS: garment cache bounds 344 exact blends, 512 warm hits and atomic missing or changed reload recovery")
	quit(1 if failures else 0)
