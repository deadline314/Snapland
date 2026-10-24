extends SceneTree
## Explicit garment-only authoring bake. Run via build_garment_layers.py.
## Does not enable an outfit or modify the immutable source wearer.
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Ownership = preload("res://tools/island_avatar/garment_ownership.gd")
var output: Image
var garment_layer: Image
var target_root: Vector2
var width_scale := 0.55
var torso_scale := Vector2(0.55,0.55)
var arm_radius := 25.0
var draw_clip: Rect2i
var mesh_regions: Array[Rect2i] = []
var owner_bounds: Array = []

func _initialize() -> void:
	var guide_path := OS.get_environment("SNAPLAND_GARMENT_GUIDE")
	var profile := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not profile.is_absolute_path() or not guide_path.is_absolute_path() or OS.get_environment("SNAPLAND_GARMENT_GUIDE_SHA256").is_empty() or FileAccess.get_sha256(guide_path)!=OS.get_environment("SNAPLAND_GARMENT_GUIDE_SHA256"):
		_reject("Missing isolated profile or validated immutable artist guide");return
	var config: Variant=JSON.parse_string(FileAccess.get_file_as_string(guide_path))
	if not config is Dictionary or config.get("status","")!="inspection_only":_reject("Authoring guide must remain inspection-only");return
	var atlas_path := ProjectSettings.globalize_path("res://"+str(config.atlas))
	if FileAccess.get_sha256(atlas_path)!=str(config.atlas_sha256):_reject("Garment source changed after validation");return
	var sheet := Image.load_from_file(atlas_path)
	if sheet==null or sheet.get_size()!=Vector2i(int(config.atlas_size[0]),int(config.atlas_size[1])):_reject("Garment atlas size differs");return
	sheet.convert(Image.FORMAT_RGBA8)
	var body_sheet: Image = sheet
	var separate_body: bool = config.has("body_atlas")
	var sleeveless: bool = config.get("construction","coat")=="sleeveless_overlay"
	if separate_body:
		var body_path := ProjectSettings.globalize_path("res://"+str(config.body_atlas))
		if FileAccess.get_sha256(body_path)!=str(config.body_atlas_sha256):_reject("Torso fabric changed after validation");return
		body_sheet=Image.load_from_file(body_path)
		if body_sheet==null or body_sheet.get_size()!=Vector2i(int(config.body_atlas_size[0]),int(config.body_atlas_size[1])):_reject("Torso fabric size differs");return
		body_sheet.convert(Image.FORMAT_RGBA8)
	var final_folder := profile.get_base_dir().path_join("compiled")
	var folder := profile.get_base_dir().path_join(".pending-compiled")
	if DirAccess.dir_exists_absolute(folder) or DirAccess.dir_exists_absolute(final_folder):_reject("Authoring output already exists; use a fresh profile parent");return
	DirAccess.make_dir_recursive_absolute(folder)
	width_scale=float(config.width_scale);arm_radius=float(config.source_arm_radius)
	var default_torso_scale := _point(config.get("torso_scale",[width_scale,width_scale]))
	var avatar=Avatar.new()
	var records: Array = []
	var source_rows: Array=config.frames.duplicate()
	source_rows.append_array(config.get("runtime_fallback_frames",[]))
	for row in source_rows:
		# Only fabric follows the authored pose; never transform the wearer.
		torso_scale=_point(row.get("torso_scale",[default_torso_scale.x,default_torso_scale.y]))
		if not torso_scale.is_finite() or torso_scale.x<0.05 or torso_scale.y<0.05 or torso_scale.x>4.0 or torso_scale.y>4.0:
			_reject("Garment cel torso scale is outside finite authoring bounds");return
		var original: Image
		var action:=str(row.action);var direction:=str(row.direction);var index:=int(row.frame)
		if row.get("source_kind","")=="runtime_fallback":
			var pose_direction: String=direction if avatar.DIRECTIONS.has(direction) else avatar._closest_cardinal(direction)
			original=avatar._atlas_pose_image(avatar._pose_index(pose_direction,index,action))
		elif action=="walk":original=avatar._walk_pose_image(direction,index)
		elif action=="idle":original=avatar._stable_idle_pixels.frame("hero-idle",direction,index)
		else:
			var texture: Texture2D=avatar.animation_library.texture("traveller",action,direction,index)
			if texture!=null:original=texture.get_image()
		if original==null or original.get_size()!=Vector2i(280,360):_reject("Missing fixed original wearer "+action+"/"+direction);return
		original.convert(Image.FORMAT_RGBA8)
		var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(original.get_data())
		if context.finish().hex_encode()!=str(row.source_pixel_sha256):_reject("Original wearer changed; re-author guides before baking "+action+"/"+direction+"/"+str(index));return
		output=original.duplicate();garment_layer=Image.create(280,360,false,Image.FORMAT_RGBA8)
		var cel:=sheet.get_region(_rect(row.atlas_region))
		var body_cel: Image = body_sheet.get_region(_rect(row.body_atlas_region)) if separate_body else cel
		target_root=_point(row.target_root);draw_clip=_rect(row.draw_clip);owner_bounds=row.get("arm_owner_bounds",[])
		mesh_regions.clear()
		for region in row.get("arm_mesh_regions",[]):mesh_regions.append(_rect(region))
		var source_root:=_point(row.source_root)
		var torso:=PackedVector2Array()
		for p in row.body_polygon:torso.append(_point(p))
		var source_arms: Array = [];var target_arms: Array = []
		if not sleeveless:
			for side in 2:
				var src: Array[Vector2] = [];var dst: Array[Vector2] = []
				for p in row.source_arms[side]:src.append(_point(p))
				for p in row.target_arms[side]:dst.append(_point(p))
				source_arms.append(src);target_arms.append(dst)
		for part in row.part_order:
			if part=="body":_draw_torso(body_cel,torso,source_root,source_arms,separate_body)
			else:
				var side:=0 if part=="arm_0" else 1
				_draw_arm(cel,source_arms[side],target_arms[side],side)
		if sleeveless:
			for arm in row.original_arm_spans:
				_restore_spans(original,arm)
		var protected_count := 0
		for raw in row.protection.values():
			var region:=_rect(raw)
			for y in range(region.position.y,region.end.y):
				for x in range(region.position.x,region.end.x):
					var color:=original.get_pixel(x,y)
					if color.a>0.05:
						output.set_pixel(x,y,color);garment_layer.set_pixel(x,y,Color.TRANSPARENT);protected_count+=1
		# Reuse only reviewed original head ownership, with exact source-pixel proof.
		var original_signature:=avatar.head_source_signature(original)
		var ownership: Dictionary=Ownership.resolve(avatar,original,direction,action)
		if ownership.is_empty():_reject("Original cel has no pixel-verified reviewed head ownership");return
		for span in row.protection_spans:
			for x in range(int(span[1]),int(span[2])+1):
				var point:=Vector2i(x,int(span[0]))
				output.set_pixelv(point,original.get_pixelv(point));garment_layer.set_pixelv(point,Color.TRANSPARENT)
		if ownership.has("head_foreground_rect"):
			if not _upper_foreground_unchanged(original,_rect(ownership.head_foreground_rect)):
				_reject("Garment touched the reviewed original legacy head/upper foreground");return
		else:
			for span in ownership.owner.hair_owner_spans:
				for x in range(int(span[1]),int(span[2])):
					var point:=Vector2i(x,int(span[0]))
					output.set_pixelv(point,original.get_pixelv(point));garment_layer.set_pixelv(point,Color.TRANSPARENT)
		var changed_pixels := 0
		for y in 360:
			for x in 280:
				if output.get_pixel(x,y)!=original.get_pixel(x,y):changed_pixels+=1
		if changed_pixels==0:_reject("No visible garment output; check source and target guides");return
		for raw in row.unchanged_regions:
			var region:=_rect(raw)
			if output.get_region(region).get_data()!=original.get_region(region).get_data():_reject("Garment changed an immutable original region "+action+"/"+direction+"/"+str(index));return
		var name:="%s-%s-%02d"%[action,direction,index]
		if original.save_png(folder.path_join(name+"-original.png"))!=OK or output.save_png(folder.path_join(name+".png"))!=OK or garment_layer.save_png(folder.path_join(name+"-garment.png"))!=OK:_reject("Could not save baked authoring frame");return
		records.append({"action":action,"direction":direction,"frame":index,"source_kind":row.get("source_kind","authored"),"protected_pixel_visits":protected_count,"immutable_regions_equal":true,"head_owner_preserved":true,"changed_garment_pixels":changed_pixels,"original_head_owner_signature":original_signature,"head_owner_reference_signature":ownership.reference_signature,"head_owner_method":ownership.method,"baked_pixel_sha256":avatar.head_source_signature(output),"source_pixel_sha256":row.source_pixel_sha256,"status":"inspection_only"})
	if DirAccess.rename_absolute(folder,final_folder)!=OK:_reject("Could not atomically accept the complete authoring bake");return
	FileAccess.open(profile.get_base_dir().path_join("bake-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"inspection_only","baked":records.size(),"authored_cels":config.frames.size(),"runtime_fallback_requests":config.get("runtime_fallback_frames",[]).size(),"frames":records,"wardrobe_registered":false},"  "))
	print("PASS: garment-only authoring bake ",config.frames.size()," authored cels + ",config.get("runtime_fallback_frames",[]).size()," existing runtime requests; no wardrobe registration")
	quit()

func _upper_foreground_unchanged(original: Image, region: Rect2i) -> bool:
	if not Rect2i(Vector2i.ZERO,original.get_size()).encloses(region) or region.size.x<=0 or region.size.y<=0:
		return false
	if output.get_region(region).get_data()!=original.get_region(region).get_data():return false
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if garment_layer.get_pixel(x,y).a>0.0:return false
	return true

func _point(raw: Array) -> Vector2:return Vector2(float(raw[0]),float(raw[1]))
func _rect(raw: Array) -> Rect2i:return Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
func _reject(message:String) -> void:
	printerr("REJECTED: "+message);quit(2)

func _restore_spans(original:Image, spans:Array) -> void:
	for span in spans:
		for x in range(int(span[1]),int(span[2])+1):
			var point:=Vector2i(x,int(span[0]))
			output.set_pixelv(point,original.get_pixelv(point));garment_layer.set_pixelv(point,Color.TRANSPARENT)

func _draw_torso(cel: Image, polygon: PackedVector2Array, source_root: Vector2, arms: Array, separate_body: bool = false) -> void:
	for y in range(draw_clip.position.y,draw_clip.end.y):
		for x in range(draw_clip.position.x,draw_clip.end.x):
			var uv := (Vector2(x+0.5,y+0.5)-target_root)/torso_scale+source_root
			if not Geometry2D.is_point_in_polygon(uv,polygon): continue
			var owned_by_arm := false
			if not separate_body:
				for side in 2:
					if uv.y>Vector2(arms[side][0]).y+10.0 and _arm_owns(uv,arms[side],side): owned_by_arm=true
			if not owned_by_arm:_sample(cel,uv,Vector2i(x,y))

func _bone_point(p:Vector2,a:Vector2,b:Vector2,c:Vector2,d:Vector2) -> Vector2:
	var axis:Vector2=(b-a).normalized();var normal:=Vector2(-axis.y,axis.x)
	var target_axis:Vector2=(d-c).normalized();var target_normal:=Vector2(-target_axis.y,target_axis.x)
	return c+target_axis*((p-a).dot(axis)*c.distance_to(d)/maxf(a.distance_to(b),0.001))+target_normal*((p-a).dot(normal)*width_scale)

func _skin(p:Vector2,src:Array,dst:Array) -> Vector2:
	var du:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,src[0],src[1]))
	var dl:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,src[1],src[2]))
	var weight:=clampf(0.5+(du-dl)/maxf(du+dl,1.0)*0.5,0.0,1.0)
	return _bone_point(p,src[0],src[1],dst[0],dst[1]).lerp(_bone_point(p,src[1],src[2],dst[1],dst[2]),weight)

func _arm_owns(p:Vector2,src:Array,side:int) -> bool:
	if not mesh_regions[side].has_point(Vector2i(floori(p.x),floori(p.y))):return false
	var du:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,src[0],src[1]))
	var dl:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,src[1],src[2]))
	# Explicit garment-side corridor prevents pulling the opposite torso panel.
	return minf(du,dl)<=arm_radius and p.x>float(owner_bounds[side][0]) and p.x<float(owner_bounds[side][1])

func _draw_arm(cel:Image,src:Array,dst:Array,side:int) -> void:
	var region: Rect2i=mesh_regions[side]
	for y in range(region.position.y,region.end.y,6):
		for x in range(region.position.x,region.end.x,6):
			var a:=Vector2(x,y);var b:=Vector2(x+6,y);var c:=Vector2(x+6,y+6);var d:=Vector2(x,y+6)
			_triangle(cel,[a,b,c],[_skin(a,src,dst),_skin(b,src,dst),_skin(c,src,dst)],src,side)
			_triangle(cel,[a,c,d],[_skin(a,src,dst),_skin(c,src,dst),_skin(d,src,dst)],src,side)

func _triangle(cel:Image,uv:Array,p:Array,src:Array,side:int) -> void:
	var minx:=maxi(draw_clip.position.x,floori(minf(p[0].x,minf(p[1].x,p[2].x))))
	var maxx:=mini(draw_clip.end.x-1,ceili(maxf(p[0].x,maxf(p[1].x,p[2].x))))
	var miny:=maxi(draw_clip.position.y,floori(minf(p[0].y,minf(p[1].y,p[2].y))))
	var maxy:=mini(draw_clip.end.y-1,ceili(maxf(p[0].y,maxf(p[1].y,p[2].y))))
	var v0:Vector2=p[1]-p[0];var v1:Vector2=p[2]-p[0];var den:=v0.cross(v1)
	if absf(den)<0.0001:return
	for y in range(miny,maxy+1):
		for x in range(minx,maxx+1):
			var v2:=Vector2(x+0.5,y+0.5)-Vector2(p[0]);var u:=v2.cross(v1)/den;var v:=v0.cross(v2)/den
			if u < -0.001 or v < -0.001 or u+v>1.001:continue
			var source_uv:Vector2=Vector2(uv[0])+(Vector2(uv[1])-Vector2(uv[0]))*u+(Vector2(uv[2])-Vector2(uv[0]))*v
			if _arm_owns(source_uv,src,side):_sample(cel,source_uv,Vector2i(x,y))

func _sample(cel:Image,uv:Vector2,point:Vector2i) -> void:
	var q:=Vector2i(floori(uv.x),floori(uv.y))
	if q.x<0 or q.y<0 or q.x>=cel.get_width() or q.y>=cel.get_height():return
	var color:=cel.get_pixelv(q)
	if color.a>0.4:
		output.set_pixelv(point,color);garment_layer.set_pixelv(point,color)
