extends RefCounted
## Source-bound foreground ownership; no runtime color/shape inference.
const PATH := "res://assets/characters/avatar-prop-foreground-v1.json"
const CANVAS := Vector2i(280,360)
const CACHE_LIMIT := 16
const MAX_FILE_BYTES := 2 * 1024 * 1024
var _owners: Dictionary = {}
var _cache: Dictionary = {}
var _order: Array[String] = []
var diagnostics: Array[String] = []

func _init(path: String = PATH) -> void:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>MAX_FILE_BYTES:
		_reject("Missing or oversized prop foreground ownership")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema_version",0)!=1 or parsed.get("canvas",[])!=[280.0,360.0] or not parsed.get("owners") is Dictionary or parsed.owners.size()>256:
		_reject("Invalid prop foreground ownership")
		return
	for signature in parsed.owners:
		var row: Variant = parsed.owners[signature]
		if not signature is String or signature.length()!=64 or not signature.is_valid_hex_number(false) or not row is Dictionary or not row.get("spans") is Array or row.spans.is_empty() or row.spans.size()>4096:
			_reject("Invalid prop foreground source")
			return
		var last_y := -1
		var last_end := -1
		for span in row.spans:
			if not span is Array or span.size()!=3:
				_reject("Invalid prop foreground span")
				return
			for value in span:
				if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)):
					_reject("Invalid prop foreground coordinate")
					return
			var y := int(span[0])
			var start := int(span[1])
			var end := int(span[2])
			if y<0 or y>=CANVAS.y or start<0 or end>CANVAS.x or start>=end or y<last_y or (y==last_y and start<=last_end):
				_reject("Unordered or out-of-bounds prop foreground span")
				return
			last_end=end
			last_y=y
	_owners=parsed.owners

func indices(source: Image) -> PackedInt32Array:
	if source==null or source.get_size()!=CANVAS or _owners.is_empty(): return PackedInt32Array()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(source.get_data())
	var signature := context.finish().hex_encode()
	if not _owners.has(signature): return PackedInt32Array()
	if _cache.has(signature):
		_order.erase(signature)
		_order.append(signature)
		return _cache[signature]
	var result := PackedInt32Array()
	for span in _owners[signature].spans:
		for x in range(int(span[1]),int(span[2])): result.append(int(span[0])*CANVAS.x+x)
	_cache[signature]=result
	_order.append(signature)
	while _order.size()>CACHE_LIMIT: _cache.erase(_order.pop_front())
	return result

func restore(target: Image, source: Image, selected: PackedInt32Array) -> void:
	if target==null or source==null or target.get_size()!=CANVAS or source.get_size()!=CANVAS: return
	for index in selected:
		var point := Vector2i(index%CANVAS.x,index/CANVAS.x)
		target.set_pixelv(point,source.get_pixelv(point))

func _reject(message: String) -> void:
	diagnostics.append(message)
	push_warning("Avatar: "+message+"; preserving complete original hair where ownership is required.")
