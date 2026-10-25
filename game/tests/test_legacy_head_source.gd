extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Heads = preload("res://game/world/legacy_head_source.gd")
# Independently captured from a26a65d before reviewed legacy ownership existed.
const ORIGINAL_RENDER_SHA := "ac5ae00803018d473727c82512bc3bd61c6c353787e7a73484b4e0c391315c2f"
const FACE_HAND := [Vector2i(111,114),Vector2i(162,114),Vector2i(115,99),Vector2i(158,99),Vector2i(140,135),Vector2i(170,139),Vector2i(43,86),Vector2i(233,83)]
class MissingOpening:
	extends "res://game/world/avatar_renderer.gd"
	func _cached_hair_cut(style: String, direction: String, color: Color) -> Dictionary:
		var cut: Dictionary=super._cached_hair_cut(style,direction,color)
		if style=="bob":cut["face_opening_valid"]=false
		return cut
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:push_error(message);failures+=1
func write_json(path: String, data: Variant) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
func _initialize() -> void:
	var save:=OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save.is_absolute_path():quit(2);return
	var folder:=save.get_base_dir();DirAccess.make_dir_recursive_absolute(folder)
	var avatar:=Avatar.new()
	check(avatar.legacy_heads.cache_snapshot().compiled_portraits==0,"Head masks compiled before any portrait used them")
	var source: Image=avatar._atlas_pose_image(15)
	var body:=PackedInt32Array()
	for y in 360:
		for x in 280:
			var c:=source.get_pixel(x,y)
			if c.a>0.05 and (y>=140 or (c.h>0.40 and c.h<0.57 and c.s>0.35 and c.v>0.15)):body.append(y*280+x)
	var equipment: Dictionary={"outfit":"outfit-tide","hat":"hat-none"}
	var requests:=0
	for direction in Avatar.WALK_DIRECTIONS:
		check(not avatar.has_authored_action("celebrate",direction),"Static fallback falsely became authored directional animation")
		for frame in range(3):
			var image: Image=avatar.texture(Avatar.DEFAULT_APPEARANCE,equipment,direction,frame,"celebrate").get_image()
			check(avatar.head_source_signature(image)==ORIGINAL_RENDER_SHA,"Approved default portrait changed: "+direction)
			requests+=1
	# Each reviewed hat follows the actual front portrait, independent of the
	# requested navigation heading and of prior cache warming.
	for hat in ["hat-straw","hat-sailor","hat-flower"]:
		var equipped: Dictionary={"outfit":"outfit-tide","hat":hat}
		var front: Image=avatar.texture(Avatar.DEFAULT_APPEARANCE,equipped,"front",0,"celebrate").get_image()
		for direction in Avatar.WALK_DIRECTIONS:
			for frame in range(3):
				var image: Image=avatar.texture(Avatar.DEFAULT_APPEARANCE,equipped,direction,frame,"celebrate").get_image()
				check(image.get_data()==front.get_data(),"Hat used requested heading instead of actual portrait direction")
	var profiles:=0
	var material_changes:=0
	var feature_changes:=0
	for skin in Avatar.SKIN_COLORS:
		for outfit in ["outfit-tide","outfit-rainvest"]:
			for hat in ["hat-none","hat-straw"]:
				var base_look: Dictionary=Avatar.DEFAULT_APPEARANCE.duplicate();base_look.skin=skin
				var equipped: Dictionary={"outfit":outfit,"hat":hat}
				var baseline: Image=avatar.texture(base_look,equipped,"front",0,"celebrate").get_image()
				for style in ["bob","curly"]:
					for color in Avatar.HAIR_COLORS:
						var look:=base_look.duplicate();look.hair=style;look.hair_color=color
						var texture: Texture2D=avatar.texture(look,equipped,"front",0,"celebrate")
						var image: Image=texture.get_image()
						check(image.get_data()!=baseline.get_data(),"Alternate haircut was silently replaced by the default")
						for index in body:
							if image.get_pixel(index%280,index/280)!=baseline.get_pixel(index%280,index/280):material_changes+=1
						for point: Vector2i in FACE_HAND:
							if image.get_pixelv(point)!=baseline.get_pixelv(point):feature_changes+=1
						check(image.get_pixel(170,139).a>0.95,"Old jaw alpha hole returned")
						check(avatar.texture(look,equipped,"front",0,"celebrate")==texture,"Warm portrait cache did not reuse its own request")
						profiles+=1
	check(material_changes==0,"Hair style/dye changed visible original body or coat pixels: "+str(material_changes))
	check(feature_changes==0,"Independent original eyes/brows/mouth/hands changed: "+str(feature_changes))
	check(avatar.legacy_heads.cache_snapshot().compiled_portraits==1,"One source portrait duplicated its masks for every profile")
	check(avatar.cached_texture_count()<=128,"Final portrait cache became unbounded")
	# A damaged opening is rejected before source hair is removed.
	var missing:=MissingOpening.new()
	var bob: Dictionary=Avatar.DEFAULT_APPEARANCE.duplicate();bob.hair="bob"
	var intact: Image=missing.texture(bob,equipment,"front",0,"celebrate").get_image()
	check(missing.head_source_signature(intact)==ORIGINAL_RENDER_SHA,"Missing face opening erased the complete source")
	# A changed source cannot borrow ownership or resurrect a cached haircut.
	var warm: Texture2D=avatar.texture(bob,equipment,"front",0,"celebrate")
	var altered:=source.duplicate();altered.set_pixel(140,100,Color.MAGENTA)
	check(avatar.legacy_heads.metrics_for("celebrate",altered).is_empty(),"One-pixel changed source borrowed ownership")
	var recovered: Image=avatar.texture(bob,equipment,"front",0,"celebrate").get_image()
	check(avatar.head_source_signature(recovered)==ORIGINAL_RENDER_SHA and recovered.get_data()!=warm.get_image().get_data(),"Rejected head source retained stale final haircut texture")
	check(avatar.legacy_heads.cache_snapshot().compiled_portraits==0,"Rejected source kept compiled masks")
	var parsed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Heads.MANIFEST_PATH))
	var faults:=0
	for kind in ["source","bounds","fraction","bool","overlap","underlay","direction","species","duplicate","missing_palette","color","empty"]:
		var bad:=parsed.duplicate(true)
		var row: Dictionary=bad.poses[0]
		match kind:
			"source":row.source_pixel_sha256="0".repeat(64)
			"bounds":row.hair_spans[0][2]=281
			"fraction":row.hair_spans[0][1]=12.5
			"bool":row.body_start_y=true
			"overlap":row.restore_spans=[row.hair_spans[0].duplicate()]
			"underlay":row.underlay_runs=[row.restore_spans[0].duplicate()+[240,180,120,253]]
			"direction":row.source_direction="back"
			"species":row.supported_species=["elf"]
			"duplicate":bad.poses.append(row.duplicate(true))
			"missing_palette":row.erase("palette_compat_spans")
			"color":row.underlay_runs[0][3]=256
			"empty":row.hair_spans=[]
		var path:=folder.path_join("head-"+kind+".json");write_json(path,bad)
		var rejected=Heads.new(path)
		check(not rejected.ready(Avatar.new()),"Unsafe head ownership accepted: "+kind)
		check(rejected.cache_snapshot().validated_portraits==0 and rejected.cache_snapshot().compiled_portraits==0,"Part of a bad head family remained enabled")
		check(not rejected.ready(avatar) and rejected.diagnostics.size()==1,"Rejected head data retried or repeated diagnostics")
		faults+=1
	var malformed:=folder.path_join("head-malformed.json")
	var file:=FileAccess.open(malformed,FileAccess.WRITE);file.store_string("{broken");file.close()
	var corrupt=Heads.new(malformed)
	check(not corrupt.ready(Avatar.new()) and corrupt.diagnostics.size()==1,"Malformed JSON escaped controlled fallback")
	var unavailable:=Avatar.new()
	unavailable.legacy_heads=Heads.new(folder.path_join("missing-ownership.json"))
	for color in ["chestnut","silver"]:
		for style in ["windswept","bob"]:
			var look: Dictionary=Avatar.DEFAULT_APPEARANCE.duplicate();look.hair=style;look.hair_color=color
			var image: Image=unavailable.texture(look,equipment,"front",0,"celebrate").get_image()
			check(unavailable.head_source_signature(image)==ORIGINAL_RENDER_SHA,"Unowned hair dye leaked into the original coat")
	var fresh=Heads.new()
	check(fresh.resolve("celebrate","elf",Avatar.new()).is_empty() and fresh.cache_snapshot().compiled_portraits==0,"Unreviewed species was promoted to a human cut")
	print("LEGACY_HEAD_METRICS: ",JSON.stringify({"default_requests":requests,"appearance_profiles":profiles,"body_material_changes":material_changes,"feature_changes":feature_changes,"rejected_data_cases":faults+1}))
	if failures==0:print("PASS: reviewed legacy human cuts preserve original face body and 24 default requests with bounded masks and fail-closed data")
	quit(1 if failures else 0)
