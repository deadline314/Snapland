extends RefCounted
## Bounded source-frame decorator for the announcer's two exposed lower legs.
## It preserves input RGBA outside the measured paired skin components.

const CACHE_LIMIT := 48
const WARM_SKIN := Color(0.68,0.30,0.22)
const TEAL_FALLBACK := Color(0.02,0.30,0.38)
const CUFF := Color(0.88,0.80,0.64)
var _cache: Dictionary = {}
var _order: Array[int] = []

func decorate(texture: Texture2D) -> Dictionary:
	if not is_instance_valid(texture): return {"texture":texture,"valid":false,"legs":0,"changed":0}
	var key := texture.get_instance_id()
	if _cache.has(key): return _cache[key]
	var source := texture.get_image()
	if source == null or source.is_empty() or source.get_width()!=320 or source.get_height()!=460:
		return _store(key,{"texture":texture,"valid":false,"legs":0,"changed":0})
	var output := source.duplicate()
	var components := _lower_leg_components(source)
	if components.size()!=2:
		return _store(key,{"texture":texture,"valid":false,"legs":components.size(),"changed":0})
	var fabric := _teal_palette(source,components)
	var changed := 0
	for component: Dictionary in components:
		var pixels: PackedInt32Array = component.pixels
		var top := int(component.bounds.position.y)
		for index in pixels:
			var x := index%source.get_width()
			var y := index/source.get_width()
			var original := source.get_pixel(x,y)
			var sample: Color = output.get_pixel(x,y)
			var color := CUFF if y<top+2 else fabric
			var shade := clampf((original.r+original.g+original.b)/(WARM_SKIN.r+WARM_SKIN.g+WARM_SKIN.b),0.60,1.22)
			color = Color(color.r*shade,color.g*shade,color.b*shade,original.a).clamp()
			output.set_pixel(x,y,color)
			if sample!=color: changed+=1
	if changed<50:
		return _store(key,{"texture":texture,"valid":false,"legs":2,"changed":changed})
	var result := ImageTexture.create_from_image(output)
	return _store(key,{"texture":result,"valid":true,"legs":2,"changed":changed,"source_texture_id":key})

func cache_size() -> int:
	return _cache.size()

func _store(key: int, value: Dictionary) -> Dictionary:
	_cache[key]=value
	_order.append(key)
	while _order.size()>CACHE_LIMIT:
		var expired: int = _order.pop_front()
		_cache.erase(expired)
	return value

func _lower_leg_components(image: Image) -> Array[Dictionary]:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var found: Array[Dictionary]=[]
	var start_y := int(floor(float(height)*0.78))
	var end_y := int(floor(float(height)*0.92))
	var left_bound := int(floor(float(width)*0.30))
	var right_bound := int(ceil(float(width)*0.70))
	for y in range(start_y,end_y):
		for x in range(left_bound,right_bound):
			var start := y*width+x
			if visited[start]!=0 or not _is_warm_skin(image.get_pixel(x,y)): continue
			var queue := PackedInt32Array([start])
			visited[start]=1
			var cursor := 0
			var min_x:=x; var max_x:=x; var min_y:=y; var max_y:=y
			var pixels := PackedInt32Array()
			while cursor<queue.size():
				var index := queue[cursor]; cursor+=1
				var px:=index%width; var py:=index/width
				pixels.append(index)
				min_x=mini(min_x,px); max_x=maxi(max_x,px); min_y=mini(min_y,py); max_y=maxi(max_y,py)
				for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var nx: int=px+offset.x; var ny: int=py+offset.y
					if nx<left_bound or nx>=right_bound or ny<start_y or ny>=end_y: continue
					var neighbor: int=ny*width+nx
					if visited[neighbor]==0 and _is_warm_skin(image.get_pixel(nx,ny)):
						visited[neighbor]=1; queue.append(neighbor)
			var box:=Rect2i(min_x,min_y,max_x-min_x+1,max_y-min_y+1)
			if pixels.size()>=24 and box.size.x>=5 and box.size.x<=32 and box.size.y>=4 and box.size.y<=28:
				found.append({"pixels":pixels,"bounds":box})
	found.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return a.bounds.position.x<b.bounds.position.x)
	return found

func _is_warm_skin(color: Color) -> bool:
	return color.a>0.4 and color.r>0.45 and color.g>0.19 and color.g/color.r>0.35 and color.g/color.r<0.82 and color.b/color.r>0.18 and color.b/color.r<0.72

func _teal_palette(image: Image, components: Array[Dictionary]) -> Color:
	var upper_edge := int(components[0].bounds.position.y)
	var lower := maxi(0,upper_edge-42)
	var center := image.get_width()/2
	var colors: Array[Vector3]=[]
	for y in range(lower,upper_edge-3):
		for x in range(center-28,center+29):
			var color:=image.get_pixel(x,y)
			if color.a>0.4 and color.g>color.r*1.35 and color.g>color.b*0.70 and color.g>0.12:
				colors.append(Vector3(color.r,color.g,color.b))
	if colors.is_empty(): return TEAL_FALLBACK
	colors.sort_custom(func(a:Vector3,b:Vector3)->bool: return a.y<b.y)
	var sample: Vector3=colors[colors.size()/2]
	return Color(sample.x,sample.y,sample.z,1.0)
