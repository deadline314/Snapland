extends RefCounted
## Pure fabric overlays. Originals remain the source of body/head attachment.
## The entire family is validated before any one cel may be displayed.
const MANIFEST_PATH := "res://assets/characters/rainvest-v1/manifest.json"
const OUTFIT := "outfit-rainvest"
## .pngdata stores PNG bytes as raw data, preventing export-time remapping.
var _checked := false
var _ready := false
var _layers: Dictionary = {}
var diagnostics: Array[String] = []
var manifest_path := MANIFEST_PATH

func _init(path: String = MANIFEST_PATH) -> void:
	manifest_path = path

func _key(action: String, direction: String, frame: int) -> String:
	return "%s/%s/%d" % [action,direction,frame]

func ready(avatar: RefCounted) -> bool:
	if _checked: return _ready
	_checked = true
	if not FileAccess.file_exists(manifest_path): return _reject("Missing garment family")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or parsed.get("schema_version",0)!=1 or parsed.get("outfit","")!=OUTFIT or parsed.get("canvas",[])!=[280.0,360.0] or parsed.get("encoding","")!="png_bytes_without_import_conversion":
		return _reject("Invalid garment family identity")
	var rows: Variant = parsed.get("frames",null)
	if not rows is Array: return _reject("Missing garment cels")
	var required: Dictionary = avatar.animation_library.manifest.get("outfit_required_poses",{}).get("traveller",{}).duplicate(true)
	if required.has("celebrate"): return _reject("Celebration source changed; review garment coverage")
	for action in avatar.ACTIONS:
		if not required.has(action) and action!="celebrate": return _reject("New action needs garment coverage")
	# Existing celebration is one original aliased by these real requests.
	var legacy: Dictionary = {}
	for direction in avatar.WALK_DIRECTIONS: legacy[direction] = 3
	required["celebrate"] = legacy
	var expected: Dictionary = {}
	for action in required:
		for direction in required[action]:
			for frame in int(required[action][direction]): expected[_key(action,direction,frame)] = true
	if expected.size()!=172 or rows.size()!=expected.size(): return _reject("Incomplete garment family")
	var pending: Dictionary = {}
	for row in rows:
		if not row is Dictionary: return _reject("Invalid garment cel")
		var action := str(row.get("action",""))
		var direction := str(row.get("direction",""))
		var index: Variant = row.get("frame",null)
		if not (index is float or index is int) or not is_finite(float(index)) or float(index)!=floor(float(index)): return _reject("Invalid garment frame")
		var key := _key(action,direction,int(index))
		if not expected.has(key) or pending.has(key): return _reject("Unknown or duplicate garment cel")
		if row.get("source_kind","")!=("runtime_fallback" if action=="celebrate" else "authored"): return _reject("Mixed original and legacy coverage")
		var source: Image = avatar.original_garment_pose(action,direction,int(index))
		if source==null or avatar.head_source_signature(source)!=str(row.get("source_pixel_sha256","")): return _reject("Original wearer changed: "+key)
		var path := str(row.get("path",""))
		if not path.begins_with("res://assets/characters/rainvest-v1/") or not path.ends_with(".pngdata") or ".." in path or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(row.get("png_sha256","")): return _reject("Missing or changed garment image: "+key)
		# Decode source PNG bytes directly: no import-time alpha RGB rewriting.
		var layer := Image.new()
		if layer.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK or layer.get_size()!=Vector2i(280,360): return _reject("Invalid garment canvas: "+key)
		layer.convert(Image.FORMAT_RGBA8)
		pending[key] = layer
	_layers = pending
	_ready = true
	return true

func apply(avatar: RefCounted, target: Image, action: String, direction: String, frame: int) -> bool:
	if not ready(avatar): return false
	var layer: Image = _layers.get(_key(action,direction,frame))
	if layer==null: return false
	target.blend_rect(layer,Rect2i(Vector2i.ZERO,layer.get_size()),Vector2i.ZERO)
	return true

func _reject(message: String) -> bool:
	diagnostics.append(message)
	_layers.clear()
	_ready = false
	return false
