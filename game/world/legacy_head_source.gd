extends RefCounted
## Source-bound ownership for existing static human portraits, not new animation.
## Parse and validate once; compile immutable masks only when portrait composition needs them.
const MANIFEST_PATH := "res://assets/characters/legacy-head-ownership-v1.json"
const CANVAS := Vector2i(280,360)
const MAX_MANIFEST_BYTES := 1024 * 1024
const MAX_POSES := 16
const MAX_RUNS := 4096
var diagnostics: Array[String] = []
var _path: String
var _checked := false
var _ready := false
var _records: Dictionary = {}
var _metrics: Dictionary = {}

func _init(path: String = MANIFEST_PATH) -> void:
	_path = path

func resolve(action: String, species: String, avatar: RefCounted) -> Dictionary:
	# Version 1 was reviewed for human cuts. Other species keep their existing
	# complete source route until their attachment geometry is reviewed too.
	if species != "human" or not ready(avatar): return {}
	var record: Dictionary = _records.get(action,{})
	if record.is_empty(): return {}
	return {"direction":record.source_direction,"source_pixel_sha256":record.source_pixel_sha256}

func ready(avatar: RefCounted) -> bool:
	if _checked: return _ready
	_checked = true
	if avatar == null or not avatar.is_asset_ready(): return _reject("Original character atlas unavailable")
	var file := FileAccess.open(_path,FileAccess.READ)
	if file == null: return _reject("Ownership file unavailable")
	var length := file.get_length()
	if length <= 0 or length > MAX_MANIFEST_BYTES: return _reject("Ownership file size outside limits")
	var bytes := file.get_buffer(length)
	if bytes.size()!=length: return _reject("Ownership file could not be read completely")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK: return _reject("Invalid ownership JSON")
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("schema_version",0)!=1 or parsed.get("canvas",[])!=[280.0,360.0]:
		return _reject("Invalid ownership identity")
	var rows: Variant = parsed.get("poses",null)
	if not rows is Array or rows.is_empty() or rows.size()>MAX_POSES: return _reject("Invalid portrait inventory")
	var pending: Dictionary = {}
	for row in rows:
		if not row is Dictionary: return _reject("Invalid portrait record")
		var action := str(row.get("action",""))
		var index: Variant = row.get("pose_index",null)
		if not avatar.ACTIONS.has(action) or pending.has(action) or not _integer(index,12,15) or int(index)!=12+avatar.ACTIONS.find(action):
			return _reject("Unknown, duplicate or mismatched portrait: "+action)
		if row.get("source_direction","")!="front" or row.get("supported_species",[])!=["human"]:
			return _reject("Unreviewed portrait direction or species: "+action)
		var source: Image = avatar._atlas_pose_image(int(index))
		if source == null or source.get_size()!=CANVAS or _signature(source)!=str(row.get("source_pixel_sha256","")):
			return _reject("Original portrait changed: "+action)
		for field in ["source_bounds","skin_bounds","target_face","eyes_bounds"]:
			if not _valid_rect(row.get(field,null)): return _reject("Invalid "+field+": "+action)
		if not _integer(row.get("body_start_y",null),1,CANVAS.y): return _reject("Invalid body boundary: "+action)
		var contour: Variant = row.get("skull_contour",null)
		if not contour is Array or contour.size()<3 or contour.size()>64: return _reject("Invalid head contour: "+action)
		for point in contour:
			if not point is Array or point.size()!=2 or not _integer(point[0],0,CANVAS.x) or not _integer(point[1],0,CANVAS.y):
				return _reject("Invalid head contour point: "+action)
		var hair := _validated_runs(row.get("hair_spans",null),3,source,PackedByteArray(),int(row.body_start_y))
		if hair.is_empty(): return false
		if _validated_runs(row.get("palette_compat_spans",null),3,source,PackedByteArray(),CANVAS.y).is_empty(): return false
		var face := _validated_runs(row.get("restore_spans",null),3,source,hair,CANVAS.y)
		if face.is_empty(): return false
		if _validated_runs(row.get("underlay_runs",null),7,source,face,int(row.body_start_y)).is_empty(): return false
		pending[action] = row
	_records = pending
	_ready = true
	return true

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=minimum and float(value)<=maximum

func _valid_rect(value: Variant) -> bool:
	return value is Array and value.size()==4 and _integer(value[0],0,CANVAS.x-1) and _integer(value[1],0,CANVAS.y-1) and _integer(value[2],1,CANVAS.x) and _integer(value[3],1,CANVAS.y) and value[0]+value[2]<=CANVAS.x and value[1]+value[3]<=CANVAS.y

func _validated_runs(value: Variant, columns: int, source: Image, excluded: PackedByteArray, bottom: int) -> PackedByteArray:
	if not value is Array or value.is_empty() or value.size()>MAX_RUNS:
		_reject("Missing or excessive ownership runs");return PackedByteArray()
	var mask := PackedByteArray()
	mask.resize(CANVAS.x*CANVAS.y)
	var previous_end := -1
	for run in value:
		if not run is Array or run.size()!=columns or not _integer(run[0],0,bottom-1) or not _integer(run[1],0,CANVAS.x-1) or not _integer(run[2],1,CANVAS.x) or run[2]<=run[1]:
			_reject("Invalid ownership run bounds");return PackedByteArray()
		var start := int(run[0])*CANVAS.x+int(run[1])
		if start<previous_end:
			_reject("Overlapping or unordered ownership runs");return PackedByteArray()
		previous_end = int(run[0])*CANVAS.x+int(run[2])
		for column in range(3,columns):
			if not _integer(run[column],0,255):
				_reject("Invalid source skin color");return PackedByteArray()
		if columns==7 and run[6]==0:
			_reject("Transparent anatomical underlay");return PackedByteArray()
		for x in range(int(run[1]),int(run[2])):
			var index := int(run[0])*CANVAS.x+x
			if source.get_pixel(x,int(run[0])).a<=0.05 or (not excluded.is_empty() and excluded[index]!=0):
				_reject("Ownership crosses original transparency or protected foreground");return PackedByteArray()
			mask[index] = 1
	return mask

func metrics_for(action: String, source: Image) -> Dictionary:
	if not _ready or not _records.has(action): return {}
	var record: Dictionary = _records[action]
	if source == null or source.get_size()!=CANVAS or _signature(source)!=record.source_pixel_sha256:
		_reject("Portrait changed before composition: "+action);return {}
	if _metrics.has(action): return _metrics[action].duplicate()
	var hair := _mask(record.hair_spans)
	var face := _mask(record.restore_spans)
	var removal := hair.duplicate()
	var skull := PackedInt32Array()
	var colors := PackedColorArray()
	for run: Array in record.underlay_runs:
		for x in range(int(run[1]),int(run[2])):
			var index := int(run[0])*CANVAS.x+x
			skull.append(index);colors.append(Color8(int(run[3]),int(run[4]),int(run[5]),int(run[6])))
			removal[index] = 1
	var contour := PackedVector2Array()
	for point: Array in record.skull_contour: contour.append(Vector2(point[0],point[1]))
	var hair_indices := _indices(hair)
	var result := {"source_hair_mask":hair,"face_mask":face,"source_hair_indices":hair_indices,
		# These preserve the existing coat palette, never authorize hair removal.
		"palette_hair_indices":_indices(_mask(record.palette_compat_spans)),"hair_owner_valid":true,"foreground_indices":PackedInt32Array(),
		"replacement_source_mask":removal,"replacement_source_indices":_indices(removal),"face_indices":_indices(face),
		"source_bounds":_rect(record.source_bounds),"skin_bounds":_rect(record.skin_bounds),
		"skull_underlay_indices":skull,"skull_underlay_colors":colors,"skull_contour":contour,
		"face_features_named":{},"eyes_bounds":_rect(record.eyes_bounds),"body_start_y":int(record.body_start_y),
		"old_forelock_indices":PackedInt32Array(),"side_open_head":false,"target_face":_rect(record.target_face),
		"replacement_geometry_valid":true,"constrain_crown":false}
	_metrics[action] = result
	return result.duplicate()

func _mask(runs: Array) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(CANVAS.x*CANVAS.y)
	for run: Array in runs:
		for x in range(int(run[1]),int(run[2])): result[int(run[0])*CANVAS.x+x] = 1
	return result

func _indices(mask: PackedByteArray) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in mask.size():
		if mask[index]!=0: result.append(index)
	return result

func _rect(value: Array) -> Rect2i:
	return Rect2i(int(value[0]),int(value[1]),int(value[2]),int(value[3]))

func _signature(source: Image) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256);digest.update(source.get_data())
	return digest.finish().hex_encode()

func cache_snapshot() -> Dictionary:
	return {"validated_portraits":_records.size(),"compiled_portraits":_metrics.size(),"ready":_ready}

func _reject(message: String) -> bool:
	diagnostics.append(message)
	_records.clear();_metrics.clear();_ready = false
	push_warning("Legacy head source: "+message+"; preserving complete original character.")
	return false
