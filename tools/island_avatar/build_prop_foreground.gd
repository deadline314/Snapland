extends SceneTree
## Authoring-only camera/hand segmentation. Review the resulting native sheets.
const Avatar = preload("res://game/world/avatar_renderer.gd")
const VIEWS := ["front","front_left","front_right","left","right"]
const OUTPUT := "res://assets/characters/avatar-prop-foreground-v1.json"
## Artist-reviewed camera windows exclude the opposite-side backpack. These
## bounds are authoring guides, not runtime semantic inference.
const CAMERA_WINDOWS := {"front":Vector2i(100,190),"front_left":Vector2i(85,168),"front_right":Vector2i(125,210),"left":Vector2i(70,140),"right":Vector2i(145,225)}
func _initialize() -> void:
	var avatar := Avatar.new()
	var owners := {}
	var cases: Array = []
	for action in ["walk","idle"]:
		for view in VIEWS:
			var count: int = avatar.walk_frame_count(view) if action=="walk" else int(avatar._stable_idle_pixels.manifest["hero-idle/"+view].frames)
			for frame in count:
				var source: Image = avatar.original_garment_pose(action,view,frame)
				var mask := _segment(source,view)
				if mask.is_empty():
					push_error("Cannot identify held camera: %s/%s/%d" % [action,view,frame])
					quit(1)
					return
				var signature: String = avatar.head_source_signature(source)
				var spans: Array = []
				for y in 360:
					var start := -1
					for x in range(281):
						var selected: bool = x<280 and mask[y*280+x]!=0
						if selected and start<0: start=x
						elif not selected and start>=0:
							spans.append([y,start,x])
							start=-1
				owners[signature] = {"spans":spans}
				cases.append({"action":action,"direction":view,"frame":frame,"source_pixel_sha256":signature,"pixels":mask.count(1)})
	var content := JSON.stringify({"schema_version":1,"canvas":[280,360],"scope":"Reviewed held camera and adjacent hands in five visible-camera walk/idle headings; half-open spans bound to complete original source pixels.","owners":owners,"cases":cases},"  ")+"\n"
	if OS.get_cmdline_user_args().has("--write"):
		var file := FileAccess.open(OUTPUT,FileAccess.WRITE)
		if file==null: push_error("Cannot save prop foreground"); quit(1); return
		file.store_string(content)
		file.close()
	elif not FileAccess.file_exists(OUTPUT) or FileAccess.get_file_as_string(OUTPUT).replace("\r\n","\n")!=content:
		push_error("Prop foreground source changed; rebuild and review native poses before accepting")
		quit(1)
		return
	print("PASS: prop foreground authoring ",cases.size()," poses / ",owners.size()," exact sources; visual review required")
	quit()

func _skin(color: Color) -> bool:
	return color.a>0.4 and color.r>0.55 and color.g>0.3 and color.b>0.15 and color.g-color.b>0.065 and color.r-color.g>0.07 and color.r-color.g<0.38

func _segment(source: Image, view: String) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(280*360)
	var largest: Array[Vector2i] = []
	var window: Vector2i=CAMERA_WINDOWS[view]
	for y in range(180,270):
		for x in range(window.x,window.y):
			var point := Vector2i(x,y)
			if seen[y*280+x]!=0: continue
			var color := source.get_pixelv(point)
			if not _red(color): continue
			var component: Array[Vector2i] = [point]
			seen[y*280+x]=1
			var index := 0
			while index<component.size():
				var current := component[index]
				index+=1
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = current+offset
					if next.x<window.x or next.x>=window.y or next.y<180 or next.y>=270 or seen[next.y*280+next.x]!=0: continue
					if not _red(source.get_pixelv(next)): continue
					seen[next.y*280+next.x]=1
					component.append(next)
			if component.size()>largest.size(): largest=component
	if largest.size()<30: return PackedByteArray()
	var bounds := Rect2i(largest[0],Vector2i.ONE)
	for point in largest: bounds=bounds.expand(point)
	if bounds.size.x<8 or bounds.size.y<6 or bounds.size.x>65 or bounds.size.y>55: return PackedByteArray()
	bounds=bounds.grow(2)
	var result := PackedByteArray()
	result.resize(280*360)
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			if source.get_pixel(x,y).a>0.1: result[y*280+x]=1
	# Only source skin connected to the held prop is eligible. Do not classify
	# hair/body colors at runtime or promote the whole torso to foreground.
	var hands: Array[Vector2i] = []
	var search := bounds.grow_individual(25,12,25,12)
	for y in range(search.position.y,search.end.y):
		for x in range(search.position.x,search.end.x):
			if bounds.grow(4).has_point(Vector2i(x,y)) and _skin(source.get_pixel(x,y)):
				hands.append(Vector2i(x,y))
	var visited := PackedByteArray()
	visited.resize(280*360)
	var index := 0
	while index<hands.size():
		var point := hands[index]
		index+=1
		if visited[point.y*280+point.x]!=0: continue
		visited[point.y*280+point.x]=1
		result[point.y*280+point.x]=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = point+offset
			if search.has_point(next) and visited[next.y*280+next.x]==0 and _skin(source.get_pixelv(next)): hands.append(next)
	for i in range(visited.size()):
		if visited[i]==0: continue
		var point := Vector2i(i%280,i/280)
		for dy in range(-2,3):
			for dx in range(-2,3):
				var next := point+Vector2i(dx,dy)
				var color := source.get_pixelv(next)
				if color.a>0.1 and maxf(color.r,maxf(color.g,color.b))<0.26: result[next.y*280+next.x]=1
	return result

func _red(color: Color) -> bool:
	return color.a>0.4 and color.r>0.24 and color.r<0.72 and color.r-color.g>0.12 and absf(color.g-color.b)<0.09
