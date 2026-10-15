extends Node2D
## Optional single-style weighted hair rig. All art stays in the original 2D atlases.
const SpringScript := preload("res://game/world/hero_2d_hair_spring.gd")
const PROFILE_PATH := "res://assets/characters/hero-2d-v1/hair-rig-windswept.json"
var skeleton: Skeleton2D
var root_bone: Bone2D
var mesh: Polygon2D
var spring = SpringScript.new()
var motion_enabled := true
var _library: Variant
var _body: Sprite2D
var _foreground: Sprite2D
var _profile: Dictionary = {}
var _bases: Array[Bone2D] = []
var _tips: Array[Bone2D] = []
var _points := PackedVector2Array()
var _weights: Array[PackedFloat32Array] = []
var _rest_globals: Array[Transform2D] = []
var _context := ""
var _pose_key := ""
var _hair_image: Image
var _hat := false
var _view := "front"
var _skip_next_step := true

func initialize(library: Node2D) -> bool:
	_library = library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary or parsed.get("schema_version",0) != 1: return false
	_profile = parsed
	_body = Sprite2D.new()
	_body.centered = false
	_body.position = Vector2(-140,-346)
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)
	skeleton = Skeleton2D.new()
	skeleton.name = "HairSkeleton"
	add_child(skeleton)
	root_bone = _bone("Root",Vector2.ZERO,Vector2.RIGHT)
	skeleton.add_child(root_bone)
	for i in range(3):
		var base := _bone("Strand%d" % i,Vector2.ZERO,Vector2.DOWN*20.0)
		root_bone.add_child(base)
		var tip := _bone("Tip",Vector2.DOWN*20.0,Vector2.DOWN*20.0)
		base.add_child(tip)
		_bases.append(base)
		_tips.append(tip)
	mesh = Polygon2D.new()
	mesh.name = "WeightedHair"
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mesh.antialiased = false
	add_child(mesh)
	mesh.skeleton = NodePath("../HairSkeleton")
	_foreground = Sprite2D.new()
	_foreground.centered = false
	_foreground.position = _body.position
	_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_foreground)
	return true

func _bone(label: String, position_value: Vector2, vector: Vector2) -> Bone2D:
	var value := Bone2D.new()
	value.name = label
	value.set_autocalculate_length_and_angle(false)
	value.position = position_value
	value.set_length(maxf(vector.length(),1.0))
	value.set_bone_angle(vector.angle())
	value.rest = value.transform
	return value

func sync_pose(state: Dictionary) -> bool:
	if _library == null: return false
	var appearance: Dictionary = _library.current_appearance
	var view := String(state.get("visual_direction",state.get("direction","front")))
	var key := "%s|%s|%s|%s" % [view,state.get("action","idle"),str(state.get("frame",0)),JSON.stringify(appearance)]
	if key == _pose_key:
		_apply_visibility()
		return true
	var layers: Dictionary = _library.get_hair_rig_layers(state)
	if layers.is_empty():
		visible = false
		_library.get_node("Hero2DComposite").visible = true
		return false
	_pose_key = key
	_view = view
	_hat = bool(layers.hat_on)
	var context := "%s|%s" % [_view,str(_hat)]
	_body.texture = ImageTexture.create_from_image(layers.body)
	_foreground.texture = ImageTexture.create_from_image(layers.foreground)
	_hair_image = layers.hair
	mesh.texture = ImageTexture.create_from_image(layers.hair)
	mesh.position = layers.head
	skeleton.position = layers.head
	if context != _context:
		_context = context
		_build_geometry(_profile.directions[_view].chains)
		reset_motion()
	_apply_visibility()
	return true

func _build_geometry(chains: Array) -> void:
	_points.clear()
	_weights.clear()
	_rest_globals.clear()
	var uv := PackedVector2Array()
	var coordinates: Array[int] = []
	for n in range(0,257,8): coordinates.append(n)
	# Put a row precisely on the protected cap boundary; no triangle straddles it.
	coordinates.append(140)
	coordinates.append(152)
	coordinates.sort()
	var unique: Array[int] = []
	for n in coordinates:
		if unique.is_empty() or unique[-1] != n: unique.append(n)
	coordinates = unique
	for y in coordinates:
		for x in coordinates:
			uv.append(Vector2(x,y))
			_points.append(Vector2(x-128,y-128))
	for i in range(7):
		var values := PackedFloat32Array()
		values.resize(_points.size())
		_weights.append(values)
	root_bone.transform = Transform2D.IDENTITY
	root_bone.rest = Transform2D.IDENTITY
	_rest_globals.append(Transform2D.IDENTITY)
	for i in range(3):
		var chain: Dictionary = chains[i]
		var a := Vector2(chain.root[0],chain.root[1])-Vector2(128,128)
		var vector := Vector2(chain.tip[0],chain.tip[1])-Vector2(chain.root[0],chain.root[1])
		_bases[i].transform = Transform2D(0.0,a)
		_bases[i].rest = _bases[i].transform
		_bases[i].set_length(vector.length()*0.55)
		_bases[i].set_bone_angle(vector.angle())
		_tips[i].transform = Transform2D(0.0,vector*0.55)
		_tips[i].rest = _tips[i].transform
		_tips[i].set_length(vector.length()*0.45)
		_tips[i].set_bone_angle(vector.angle())
		_rest_globals.append(_bases[i].transform)
		_rest_globals.append(_bases[i].transform*_tips[i].transform)
	for index in range(uv.size()):
		var point := uv[index]
		var strongest := 0.0
		var selected := 0
		var selected_t := 0.0
		if not _protected(point):
			for i in range(3):
				var chain: Dictionary = chains[i]
				var a := Vector2(chain.root[0],chain.root[1])
				var vector := Vector2(chain.tip[0],chain.tip[1])-a
				var t := clampf((point-a).dot(vector)/vector.length_squared(),0.0,1.0)
				var lateral := absf((point-a).cross(vector.normalized()))
				var envelope := maxf(0.0,1.0-lateral/float(chain.radius))
				var weight := smoothstep(0.10,0.90,t)*envelope*envelope
				if weight > strongest:
					strongest = weight
					selected = i
					selected_t = t
		_weights[0][index] = 1.0-strongest
		_weights[1+selected*2][index] = strongest*(1.0-selected_t)
		_weights[2+selected*2][index] = strongest*selected_t
	var faces: Array[PackedInt32Array] = []
	var width := coordinates.size()
	for y in range(width-1):
		for x in range(width-1):
			var i := y*width+x
			faces.append(PackedInt32Array([i,i+1,i+width+1,i+width]))
	mesh.polygon = _points
	mesh.uv = uv
	mesh.polygons = faces
	mesh.clear_bones()
	mesh.add_bone(NodePath("Root"),_weights[0])
	for i in range(3):
		mesh.add_bone(NodePath("Root/Strand%d" % i),_weights[1+i*2])
		mesh.add_bone(NodePath("Root/Strand%d/Tip" % i),_weights[2+i*2])

func _protected(point: Vector2) -> bool:
	var core: Array = _profile.protected_core
	var in_core: bool = point.x>=core[0] and point.x<=core[0]+core[2] and point.y>=core[1] and point.y<=core[1]+core[3]
	return in_core or (_hat and point.y<=float(_profile.hat_protected_y))

func advance(dt: float, velocity: Vector2, state: Dictionary, paused := false) -> void:
	if paused: return
	if not sync_pose(state): return
	if _skip_next_step:
		spring.reset(_view,_hat,velocity)
		_skip_next_step = false
	else:
		spring.advance(dt,velocity,_view,_hat)
	_apply_angles()

func reset_motion(velocity := Vector2.ZERO) -> void:
	spring.reset(_view,_hat,velocity)
	_skip_next_step = true
	_apply_angles()

func set_motion_enabled(value: bool) -> void:
	motion_enabled = value
	spring.set_enabled(value)
	_skip_next_step = true
	_apply_angles()
	_apply_visibility()

func _apply_visibility() -> void:
	visible = motion_enabled
	_library.get_node("Hero2DComposite").visible = not motion_enabled

func _apply_angles() -> void:
	if root_bone == null: return
	root_bone.transform = Transform2D.IDENTITY
	for i in range(3):
		var side := 1.0 if i==0 else (-1.0 if i==1 else 0.0)
		_bases[i].rotation = spring.angles.x+spring.angles.y*side
		_tips[i].rotation = spring.tip_angles.x+spring.tip_angles.y*side

func geometry_receipt() -> Dictionary:
	var protected_error := 0.0
	var sum_error := 0.0
	var mobile := 0
	for i in range(_points.size()):
		var sum := 0.0
		for weights in _weights: sum += weights[i]
		sum_error = maxf(sum_error,absf(sum-1.0))
		if _protected(_points[i]+Vector2(128,128)):
			protected_error = maxf(protected_error,absf(1.0-_weights[0][i]))
		elif _weights[0][i]<0.99: mobile += 1
	return {"protected_weight_error":protected_error,"weight_sum_error":sum_error,"mobile_vertices":mobile,"vertices":_points.size(),"bones":mesh.get_bone_count()}

func motion_receipt() -> Dictionary:
	var rotations: Array[float] = []
	for i in range(3): rotations.append(_bases[i].rotation); rotations.append(_tips[i].rotation)
	return {"spring":spring.snapshot(),"rotations":rotations,"root":root_bone.transform,"head":skeleton.position,"context":_context,"enabled":motion_enabled}

func maximum_tip_displacement() -> float:
	var transforms: Array[Transform2D] = [Transform2D.IDENTITY]
	for i in range(3):
		transforms.append(_bases[i].transform*_rest_globals[1+i*2].affine_inverse())
		transforms.append((_bases[i].transform*_tips[i].transform)*_rest_globals[2+i*2].affine_inverse())
	var maximum := 0.0
	for i in range(_points.size()):
		var pixel := Vector2i(_points[i]+Vector2(128,128))
		if pixel.x>=256 or pixel.y>=256 or _hair_image.get_pixelv(pixel).a<0.25: continue
		var deformed := Vector2.ZERO
		for bone in range(7): deformed += (transforms[bone]*_points[i])*_weights[bone][i]
		maximum = maxf(maximum,deformed.distance_to(_points[i]))
	return maximum
