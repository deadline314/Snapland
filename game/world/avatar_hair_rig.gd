extends SubViewport
## Pixel-preserving island cutouts. Only authored outer tufts are weighted.
const Spring := preload("res://game/world/hero_2d_hair_spring.gd")
const PROFILE := "res://assets/characters/island-hair-windswept-v1.json"
const CANVAS := Vector2i(280, 360)
const CACHE_LIMIT := 32
var skeleton: Skeleton2D
var root_bone: Bone2D
var spring = Spring.new()
var motion_enabled := true
var active := false
var pose_key := ""
var fallback_reason := "not initialized"
var _profile: Dictionary = {}
var _body: Sprite2D
var _bones: Array[Bone2D] = []
var _meshes: Array[Polygon2D] = []
var _cache: Dictionary = {}
var _order: Array[String] = []
var _context := ""
var _view := "front"
var _hat := false
var _skip_step := true
var _source_valid: Dictionary = {}

func _ready() -> void:
	size = CANVAS
	disable_3d = true
	transparent_bg = true
	world_2d = World2D.new()
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1: return
	var canvas: Array = parsed.get("canvas", [])
	if canvas.size() != 2 or Vector2i(int(canvas[0]), int(canvas[1])) != CANVAS: return
	_profile = parsed
	skeleton = Skeleton2D.new()
	skeleton.name = "HairSkeleton"
	add_child(skeleton)
	root_bone = _bone("Root", Vector2.ZERO)
	skeleton.add_child(root_bone)
	for i in range(3):
		var bone := _bone("Strand%d" % i, Vector2.ZERO)
		root_bone.add_child(bone)
		_bones.append(bone)
		var mesh := Polygon2D.new()
		mesh.name = "HairTuft%d" % i
		mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(mesh)
		mesh.skeleton = NodePath("../HairSkeleton")
		_meshes.append(mesh)
	_body = Sprite2D.new()
	_body.name = "OriginalBodyAndRigidAttachments"
	_body.centered = false
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Store straight RGBA for Sprite3D, which samples this as a normal atlas.
	# Source interiors have alpha ~0.98: alpha-over on overlapping cutouts would
	# alter both colour and alpha. Retained pixels explicitly overwrite the tuft.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode blend_disabled; void fragment() { vec4 p = texture(TEXTURE, UV); if (p.a == 0.0) { discard; } COLOR = p; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	_body.material = material
	for mesh: Polygon2D in _meshes: mesh.material = material
	add_child(_body)

func _bone(label: String, point: Vector2) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = label
	bone.set_autocalculate_length_and_angle(false)
	bone.position = point
	bone.rest = bone.transform
	bone.set_length(20.0)
	return bone

func sync_pose(source: Texture2D, renderer: RefCounted, appearance: Dictionary, equipped: Dictionary, view: String, frame: int, action: String) -> Texture2D:
	active = false
	if not motion_enabled: return _fallback(source, "reduced motion or disabled")
	if str(appearance.get("hair", "windswept")) != "windswept": return _fallback(source, "other styles remain original until ART-34")
	if str(appearance.get("species", "human")) != "human": return _fallback(source, "species attachment coverage remains original")
	if action not in ["walk", "idle"]: return _fallback(source, "one-shot/ride retains its complete authored pose")
	if not _valid_view(view) or _body == null: return _fallback(source, "unverified or changed source art")
	var key := "%s|%s|%d|%s|%s" % [view, action, frame, JSON.stringify(appearance), JSON.stringify(equipped)]
	var context := "%s|%s|%s" % [view, JSON.stringify(appearance), JSON.stringify(equipped)]
	_view = view
	_hat = str(equipped.get("hat", "hat-none")) != "hat-none"
	if context != _context:
		_context = context
		_build_geometry(_profile.directions[view].strands)
		reset_motion()
	if key != pose_key:
		if not _cache.has(key):
			var layers := _split_layers(source.get_image(), renderer.hair_motion_attachment_guard(view, frame, action, equipped))
			if layers.is_empty(): return _fallback(source, "invalid fixed canvas")
			_cache[key] = layers
		_order.erase(key)
		_order.append(key)
		while _order.size() > CACHE_LIMIT: _cache.erase(_order.pop_front())
		var layers: Dictionary = _cache[key]
		_body.texture = layers.body
		for i in range(3): _meshes[i].texture = layers.hair[i]
		pose_key = key
	active = true
	fallback_reason = ""
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return get_texture()

func _fallback(source: Texture2D, reason: String) -> Texture2D:
	fallback_reason = reason
	pose_key = ""
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	reset_motion()
	return source

func _valid_view(view: String) -> bool:
	if _source_valid.has(view): return _source_valid[view]
	var spec: Dictionary = _profile.get("directions", {}).get(view, {})
	var valid: bool = spec.get("strands", []).size() == 3 and _source_pixels_match(spec)
	if valid:
		for strand: Dictionary in spec.strands:
			if strand.get("root", []).size() != 2 or strand.get("tip", []).size() != 2 or strand.get("spans", []).is_empty() or strand.get("cut_spans", []).is_empty():
				valid = false
				break
			for span: Array in strand.spans + strand.cut_spans:
				if span.size() != 3 or int(span[0]) < 0 or int(span[0]) >= CANVAS.y or int(span[1]) < 0 or int(span[2]) >= CANVAS.x or int(span[1]) > int(span[2]):
					valid = false
					break
	_source_valid[view] = valid
	return valid

func _source_pixels_match(spec: Dictionary) -> bool:
	# Exported PNGs are imported resources, not raw files inside the PCK.
	# Compare visible canonical pixels; importers may pad hidden transparent RGB.
	var path := str(spec.get("source", ""))
	if not ResourceLoader.exists(path): return false
	var texture := load(path) as Texture2D
	if texture == null: return false
	var atlas := texture.get_image()
	if atlas.is_compressed(): atlas.decompress()
	if atlas.get_width() < CANVAS.x or atlas.get_height() != CANVAS.y: return false
	var pixels := atlas.get_region(Rect2i(Vector2i.ZERO, CANVAS))
	pixels.convert(Image.FORMAT_RGBA8)
	var data := pixels.get_data()
	for index in range(0, data.size(), 4):
		if data[index + 3] == 0:
			data[index] = 0
			data[index + 1] = 0
			data[index + 2] = 0
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(data)
	return hash.finish().hex_encode() == str(spec.get("source_pixels_sha256", "missing"))

func _split_layers(image: Image, guard: Image) -> Dictionary:
	if image.get_size() != CANVAS or guard.get_size() != CANVAS: return {}
	var body := image.duplicate()
	var hair: Array[Texture2D] = []
	for strand: Dictionary in _profile.directions[_view].strands:
		var tuft := Image.create(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
		tuft.fill(Color.TRANSPARENT)
		for span: Array in strand.spans:
			for x in range(int(span[1]), int(span[2]) + 1):
				# Actual headwear alpha wins even when its colour matches the hair.
				if guard.get_pixel(x, int(span[0])).a == 0.0: tuft.set_pixel(x, int(span[0]), image.get_pixel(x, int(span[0])))
		for span: Array in strand.cut_spans:
			for x in range(int(span[1]), int(span[2]) + 1):
				if guard.get_pixel(x, int(span[0])).a == 0.0: body.set_pixel(x, int(span[0]), Color.TRANSPARENT)
		hair.append(ImageTexture.create_from_image(tuft))
	return {"body": ImageTexture.create_from_image(body), "hair": hair}

func _build_geometry(strands: Array) -> void:
	for i in range(3):
		var spec: Dictionary = strands[i]
		var point := Vector2(spec.root[0], spec.root[1])
		var vector := Vector2(spec.tip[0], spec.tip[1]) - point
		_bones[i].transform = Transform2D(0.0, point)
		_bones[i].rest = _bones[i].transform
		_bones[i].set_length(vector.length())
		_bones[i].set_bone_angle(vector.angle())
		var bounds := Rect2i(Vector2i(spec.spans[0][1], spec.spans[0][0]), Vector2i.ONE)
		for span: Array in spec.spans: bounds = bounds.merge(Rect2i(int(span[1]), int(span[0]), int(span[2]) - int(span[1]) + 1, 1))
		bounds = bounds.grow(4).intersection(Rect2i(Vector2i.ZERO, CANVAS))
		var vertices := PackedVector2Array()
		var rigid_weights := PackedFloat32Array()
		var tip_weights := PackedFloat32Array()
		var xs: Array[int] = []
		var ys: Array[int] = []
		for x in range(bounds.position.x, bounds.end.x, 3): xs.append(x)
		for y in range(bounds.position.y, bounds.end.y, 3): ys.append(y)
		xs.append(bounds.end.x)
		ys.append(bounds.end.y)
		for y in ys:
			for x in xs:
				var vertex := Vector2(x, y)
				var t := clampf((vertex - point).dot(vector) / vector.length_squared(), 0.0, 1.0)
				var weight := smoothstep(0.18, 0.95, t)
				vertices.append(vertex)
				rigid_weights.append(1.0 - weight)
				tip_weights.append(weight)
		var faces: Array[PackedInt32Array] = []
		for y in range(ys.size() - 1):
			for x in range(xs.size() - 1):
				var n := y * xs.size() + x
				faces.append(PackedInt32Array([n, n + 1, n + xs.size() + 1, n + xs.size()]))
		var mesh := _meshes[i]
		mesh.polygon = vertices
		mesh.uv = vertices
		mesh.polygons = faces
		mesh.clear_bones()
		mesh.add_bone(NodePath("Root"), rigid_weights)
		mesh.add_bone(NodePath("Root/Strand%d" % i), tip_weights)

func advance(dt: float, velocity: Vector2, paused := false) -> void:
	if paused or not active: return
	if _skip_step:
		spring.reset(_view, _hat, velocity)
		_skip_step = false
	else: spring.advance(dt, velocity, _view, _hat)
	_apply_angles()

func reset_motion() -> void:
	spring.reset(_view, _hat)
	_skip_step = true
	_apply_angles()

func set_motion_enabled(value: bool) -> void:
	if motion_enabled == value: return
	motion_enabled = value
	spring.set_enabled(value)
	pose_key = ""
	reset_motion()

func _apply_angles() -> void:
	if root_bone == null: return
	root_bone.transform = Transform2D.IDENTITY
	for i in range(_bones.size()):
		var side := 1.0 if i == 0 else (-1.0 if i == 1 else 0.0)
		_bones[i].rotation = spring.angles.x + spring.angles.y * side

func receipt() -> Dictionary:
	return {"active": active, "pose": pose_key, "context": _context, "fallback": fallback_reason,
		"root": root_bone.transform if root_bone != null else Transform2D.IDENTITY,
		"spring": spring.snapshot(), "cache_size": _cache.size()}
