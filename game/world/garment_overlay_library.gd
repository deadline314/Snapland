extends RefCounted
## Pure fabric overlays. Originals remain the source of body/head attachment.
## The entire family is validated before any one cel may be displayed.
const MANIFEST_PATH := "res://assets/characters/rainvest-v1/manifest.json"
const OUTFIT := "outfit-rainvest"
## .pngdata stores PNG bytes as raw data, preventing export-time remapping.
const DECODED_CACHE_LIMIT := 12
const MAX_LAYER_FILE_BYTES := 2 * 1024 * 1024
const CANVAS := Vector2i(280,360)
var _checked := false
var _ready := false
var _records: Dictionary = {}
var _layers: Dictionary = {}
var _layer_order: Array[String] = []
var _verified_decodes := 0
var _cache_hits := 0
var diagnostics: Array[String] = []
var manifest_path := MANIFEST_PATH

func _init(path: String = MANIFEST_PATH) -> void:
	manifest_path = path

func _key(action: String, direction: String, frame: int) -> String:
	return "%s/%s/%d" % [action,direction,frame]

func ready(avatar: RefCounted) -> bool:
	if _checked: return _ready
	_checked = true
	if avatar == null: return _reject("Missing garment wearer")
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
		if not path.begins_with("res://assets/characters/rainvest-v1/") or not path.ends_with(".pngdata") or ".." in path:
			return _reject("Invalid garment image path: "+key)
		var record := {"path":path,"sha256":str(row.get("png_sha256",""))}
		# Validate every cel before exposing any fabric. Keep only its identity;
		# holding every decoded canvas made a single family consume 66 MiB.
		if _verified_layer(record,key) == null: return false
		pending[key] = record
	_records = pending
	_ready = true
	return true

func apply(avatar: RefCounted, target: Image, action: String, direction: String, frame: int) -> bool:
	if not ready(avatar) or target == null or target.get_size() != CANVAS: return false
	var key := _key(action,direction,frame)
	if not _records.has(key): return false
	var layer: Image = _layers.get(key)
	if layer == null:
		# Recheck on an eviction/reload too. A resource which changed after
		# preflight invalidates the complete family before touching the target.
		layer = _verified_layer(_records[key],key)
		if layer == null: return false
		_layers[key] = layer
	else:
		_cache_hits += 1
	_layer_order.erase(key)
	_layer_order.append(key)
	while _layer_order.size() > DECODED_CACHE_LIMIT:
		_layers.erase(_layer_order.pop_front())
	target.blend_rect(layer,Rect2i(Vector2i.ZERO,CANVAS),Vector2i.ZERO)
	return true

func _verified_layer(record: Dictionary, key: String) -> Image:
	var file := FileAccess.open(record.path,FileAccess.READ)
	if file == null:
		_reject("Cannot read garment image: %s (%s)" % [key,error_string(FileAccess.get_open_error())])
		return null
	var length := file.get_length()
	if length <= 0 or length > MAX_LAYER_FILE_BYTES:
		_reject("Invalid garment image size: "+key)
		return null
	var bytes := file.get_buffer(length)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	if bytes.size() != length or digest.finish().hex_encode() != record.sha256:
		_reject("Changed garment image: "+key)
		return null
	# Reject a forged huge canvas before the PNG decoder can allocate it.
	if bytes.size() < 33 or bytes.slice(0,8) != PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(8,16) != PackedByteArray([0,0,0,13,73,72,68,82]) or _png_dimension(bytes,16) != CANVAS.x or _png_dimension(bytes,20) != CANVAS.y:
		_reject("Invalid garment canvas header: "+key)
		return null
	# Decode PNG bytes directly: preserve alpha RGB in imports and PCKs.
	var layer := Image.new()
	if layer.load_png_from_buffer(bytes) != OK or layer.get_size() != CANVAS:
		_reject("Invalid garment canvas: "+key)
		return null
	layer.convert(Image.FORMAT_RGBA8)
	_verified_decodes += 1
	return layer

func _png_dimension(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset+1]) << 16) | (int(bytes[offset+2]) << 8) | int(bytes[offset+3])

func clear_cache() -> void:
	_layers.clear()
	_layer_order.clear()

func cache_snapshot() -> Dictionary:
	return {"validated_cels":_records.size(),"decoded_images":_layers.size(),
		"decoded_bytes":_layers.size()*CANVAS.x*CANVAS.y*4,
		"verified_decodes":_verified_decodes,"cache_hits":_cache_hits,
		"decoded_image_limit":DECODED_CACHE_LIMIT}

func _reject(message: String) -> bool:
	diagnostics.append(message)
	_records.clear()
	clear_cache()
	_ready = false
	return false
