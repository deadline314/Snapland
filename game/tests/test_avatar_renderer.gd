extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const VIEWS := ["front","front_right","right","back_right","back","back_left","left","front_left"]
# Independently inspected authored cel0 features; never selected by face_indices.
const FEATURES := {
	"front":[Vector2i(128,150),Vector2i(166,148),Vector2i(130,165),Vector2i(163,165),Vector2i(147,179)],
	"front_right":[Vector2i(151,143),Vector2i(180,140),Vector2i(146,154),Vector2i(180,153),Vector2i(166,171)],
	"right":[Vector2i(175,139),Vector2i(175,151),Vector2i(182,173)],
	"left":[Vector2i(115,138),Vector2i(118,149),Vector2i(113,171)],
	"front_left":[Vector2i(119,142),Vector2i(154,142),Vector2i(116,153),Vector2i(151,155),Vector2i(136,176)],
}
# Direct pixel witnesses measured from rejected front-bob PNG, independent of
# renderer face/underlay masks. These nose/eye gaps were alpha=0 before this fix.
const OPEN_HEAD_WITNESSES := {
	"front":[Vector2i(117,164),Vector2i(140,164),Vector2i(145,169),Vector2i(154,169)],
	"front_left":[Vector2i(136,158),Vector2i(139,164)],
}
func _initialize() -> void:
	var save_path:=OS.get_environment("SNAPLAND_SAVE_PATH")
	assert(save_path.is_absolute_path(),"CPU checks require isolated absolute save")
	var directory:=save_path.get_base_dir().path_join("evidence/renderer")
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK,"renderer evidence directory must be created: "+directory)
	var renderer := Avatar.new()
	var equipped := {"outfit":"outfit-tide","hat":"hat-none"}
	var look: Dictionary = Avatar.DEFAULT_APPEARANCE.duplicate()
	var raw: Image = renderer._walk_pose_image("front_right",0).duplicate()
	var metrics: Dictionary = renderer._walk_source_hair_metrics("front_right",0,raw)
	# Native rejection traced to brown fringe and cream fringe, not true brows.
	for point in [Vector2i(155,131),Vector2i(161,146),Vector2i(188,117)]:
		assert(metrics.face_mask[point.y*280+point.x]==0,"old fringe cannot be a protected facial feature at "+str(point))
	look.hair="bob"
	var bob_witness: Image = renderer.texture(look,equipped,"front",0,"walk").get_image()
	assert(bob_witness.save_png(directory.path_join("front-bob-underlay-witness.png"))==OK,"bob witness PNG must be written")
	for point: Vector2i in OPEN_HEAD_WITNESSES.front:
		assert(bob_witness.get_pixelv(point).a>0.95,"independently measured bob nose/eye band must be opaque: "+str(point))
	look.hair="curly"
	var candidate: Image=renderer.texture(look,equipped,"front_right",0,"walk").get_image()
	for point in [Vector2i(155,131),Vector2i(161,146),Vector2i(188,117),Vector2i(134,125),Vector2i(129,144),Vector2i(143,142)]:
		var color := candidate.get_pixelv(point)
		assert(color.a>0.95 and renderer._is_color_family(color,Avatar.SKIN_COLORS.warm,0.06,0.1),"exposed head is skin, not restored fringe/transparent crack at "+str(point))
	assert(candidate.save_png(directory.path_join("front_right-curly-frame0.png"))==OK,"curly witness PNG must be written")
	for view in VIEWS:
		for frame in range(8):
			var source: Image=renderer._walk_pose_image(view,frame).duplicate()
			var immutable := source.get_data()
			var record: Dictionary=renderer._walk_source_hair_metrics(view,frame,source)
			if frame==0: assert(source.save_png(directory.path_join(view+"-source-frame0.png"))==OK,"source PNG must be written: "+view)
			var eye_count := 0
			for label: String in record.face_features_named:
				if label.begins_with("eye_"): eye_count+=1
			var expected_eyes := 0 if view.begins_with("back") else (1 if view=="right" or view=="left" else 2)
			assert(eye_count==expected_eyes,"64 authored cels keep their actual visible eye count, not forehead highlights mislabeled as eyes")
			look.hair="windswept"
			var base: Image=renderer.texture(look,equipped,view,frame,"walk").get_image()
			if frame==0: assert(base.save_png(directory.path_join(view+"-default-frame0.png"))==OK,"default PNG must be written: "+view)
			for style in ["bob","curly"]:
				look.hair=style
				var image: Image=renderer.texture(look,equipped,view,frame,"walk").get_image()
				if frame==0 and FEATURES.has(view):
					for point: Vector2i in FEATURES[view]: assert(image.get_pixelv(point)==base.get_pixelv(point),"independent original feature RGBA: %s/%s %s" % [view,style,point])
				for label in record.face_features_named:
					for index in record.face_features_named[label]:
						var point := Vector2i(index%280,index/280)
						assert(image.get_pixelv(point)==base.get_pixelv(point),"64-cel named feature RGBA: %s/%d/%s/%s" % [view,frame,style,label])
				assert(_assert_open_head_surface(renderer,source,image,view,frame,style),"64-cel source face surface keeps opaque alpha")
				assert(_paint_layers(renderer,source,record,image,look,equipped,view,frame),"hair/body paint guards completed")
				if frame==0: assert(image.save_png(directory.path_join(view+"-"+style+"-frame0.png"))==OK,"haircut PNG must be written: "+view+"/"+style)
				look.hair_color="chestnut"
				var chestnut: Image=renderer.texture(look,equipped,view,frame,"walk").get_image()
				assert(_paint_layers(renderer,source,record,chestnut,look,equipped,view,frame),"second hair color preserves cut RGB and body palette")
				assert(_assert_open_head_surface(renderer,source,chestnut,view,frame,style),"second hair color keeps head opaque")
				look.hair_color="ink"
			assert(source.get_data()==immutable,"original source cel RGBA remains immutable")
	var builds := [renderer._walk_source_image_build_count,renderer._source_metrics_build_count,renderer._hair_cut_build_count]
	for view in VIEWS:
		for frame in range(8):
			var source: Image=renderer._walk_pose_image(view,frame)
			var record: Dictionary=renderer._walk_source_hair_metrics(view,frame,source)
			for skin in Avatar.SKIN_COLORS:
				for species in ["human","elf","imp"]:
					look.skin=skin
					look.species=species
					look.hair="windswept"
					var base: Image=renderer.texture(look,equipped,view,frame,"walk").get_image()
					for style in ["bob","curly"]:
						look.hair=style
						var image: Image=renderer.texture(look,equipped,view,frame,"walk").get_image()
						assert(_assert_open_head_surface(renderer,source,image,view,frame,style),"all 64 cels/skins/species keep source skin opaque")
						for label in record.face_features_named:
							for index in record.face_features_named[label]:
								var point:=Vector2i(index%280,index/280)
								assert(image.get_pixelv(point)==base.get_pixelv(point),"all 64 cels/skins/species keep exact authored feature RGBA")
						if frame==0 and FEATURES.has(view):
							for point: Vector2i in FEATURES[view]: assert(image.get_pixelv(point)==base.get_pixelv(point),"all skins/species retain independent facial witnesses")
						if frame==0 and species=="elf" and skin=="warm": assert(image.save_png(directory.path_join(view+"-elf-"+style+"-frame0.png"))==OK,"species PNG must be written: "+view+"/"+style)
	assert(builds==[renderer._walk_source_image_build_count,renderer._source_metrics_build_count,renderer._hair_cut_build_count],"skins/species reuse source/semantic/cut caches")
	assert(renderer._walk_source_metrics_cache.size()==64 and renderer._hair_cut_cache.size()<=24 and renderer.cached_texture_count()<=128)
	print("PASS: independent bob nose/eye alpha, 64-cel bob/curly face RGBA and opening alpha across all skins/species, two-color original body/palette and haircut RGB, bounded caches; native quality pending")
	quit()
func _paint_layers(renderer,source: Image,record: Dictionary,result: Image,look: Dictionary,equipped: Dictionary,view: String,frame: int) -> bool:
	var overlay := Image.create(280,360,false,Image.FORMAT_RGBA8)
	var overlay_record: Dictionary=record.duplicate()
	overlay_record.erase("skull_underlay_indices")
	var anchor: Vector2i=renderer.walk_head_anchor(view,frame)
	if Avatar.DIRECTIONS.has(view): renderer._apply_hair_atlas(overlay,look.hair,view,Avatar.HAIR_COLORS[look.hair_color],anchor.y,anchor.x-140,renderer.walk_head_width(view,frame)*1.05,source,overlay_record)
	else: renderer._apply_diagonal_hair(overlay,look.hair,view,Avatar.HAIR_COLORS[look.hair_color],anchor.y,anchor.x-140,renderer.walk_head_width(view,frame)*1.05,source,overlay_record)
	var body := source.duplicate()
	renderer._apply_palette(body,look,equipped.outfit,renderer._closest_cardinal(view),true)
	for y in range(360):
		for x in range(280):
			var index := y*280+x
			var hair_color := overlay.get_pixel(x,y)
			if hair_color.a==1.0 and record.face_mask[index]==0: assert(result.get_pixel(x,y)==hair_color,"opaque haircut RGB cannot receive jacket/skin palette")
			if hair_color.a==0.0 and record.replacement_source_mask[index]==0: assert(result.get_pixel(x,y)==body.get_pixel(x,y),"outside head/cut original body RGBA remains exact")
	return true


func _assert_open_head_surface(renderer,source: Image,result: Image,view: String,frame: int,style: String) -> bool:
	# The fixed native witnesses remain independent of the semantic metrics.
	# Per-cel authored eyes bound the real face core, avoiding old brown fringe
	# outside the face and assuming no rigid translation between authored cels.
	var record: Dictionary=renderer._walk_source_hair_metrics(view,frame,source)
	var region:=Rect2i()
	for label: String in record.face_features_named:
		if not label.begins_with("eye_"): continue
		for index in record.face_features_named[label]:
			var sample:=Rect2i(index%source.get_width(),index/source.get_width(),1,1)
			region=sample if region.size==Vector2i.ZERO else region.merge(sample)
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if source.get_pixel(x,y).a<0.95: continue
			assert(result.get_pixel(x,y).a>0.95,"authored eye/nose face core cannot become transparent: %s/%d/%s at %s" % [view,frame,style,Vector2i(x,y)])
	# Final alpha for every bounded head sample also catches semi-transparent
	# hair edges lacking a head behind them, independent of the cut opening gate.
	for index in record.skull_underlay_indices:
		var point:=Vector2i(index%source.get_width(),index/source.get_width())
		assert(result.get_pixelv(point).a>0.95,"bounded original head cannot contain a hair-opening crack: %s/%d/%s %s" % [view,frame,style,point])
	if frame==0 and OPEN_HEAD_WITNESSES.has(view):
		for point: Vector2i in OPEN_HEAD_WITNESSES[view]: assert(result.get_pixelv(point).a>0.95,"independently measured exposed head alpha: %s/%s %s" % [view,style,point])
	return true
