extends Node3D
## World-space gait for validated directional wardrobe composites.
const Avatar = preload("res://game/world/avatar_renderer.gd")
const METADATA_PATH := "res://assets/characters/motion-rig-anchors.json"
const DIRECTIONS: Array[String] = ["front","front_right","right","back_right","back","back_left","left","front_left"]
const PIXEL_SIZE := 2.4/360.0
const LEG_OUTLINE_INK := Color("#20212b")
const HIP_HEIGHT := 0.50
const HIP_HALF_WIDTH := 0.060
const UPPER_LENGTH := 0.225
const LOWER_LENGTH := 0.225
const FOOT_STROKE := 0.28
const HERO_WALK_STROKE := 0.36
const HERO_WALK_LIFT := 0.035
const HERO_RUN_LIFT := 0.065
const ANKLE_HEIGHT := 20.0*PIXEL_SIZE
const NPC_WALK_LIFT_M := {"ticket":0.018,"imp":0.020,"announcer":0.024}
const NPC_ROUTE_SPEED_MPS := {"ticket":0.25,"imp":0.35,"announcer":0.60}
const NPC_LIFT_CHANGE_MPS := 0.06
const RING := 8
const ROWS := [-0.012,0.0,0.05625,0.1125,0.16875,0.225,0.28125,0.3375,0.39375,0.45,0.462]

var direction := "right"
var running := false
var speed := 0.0
var travel := 0.0
var blend := 0.0
var idle_time := 0.0
var _motion_heading_local := Vector3.RIGHT
var _last_global_position := Vector3.ZERO
var source_records: Dictionary = {}
var diagnostics: Array[String] = []
var first_reach_failure: Dictionary = {}
var role := "hero"
var metadata_path := METADATA_PATH
var required_directions: Array[String] = DIRECTIONS.duplicate()
var leg_length_scale := 1.0
var _hero_fixed_chain := 0.0
var _hero_source_fallback := false
var upper_bone_length: float:
	get: return _hero_fixed_chain*0.5 if _hero_fixed_chain>0.0 else UPPER_LENGTH*leg_length_scale
var lower_bone_length: float:
	get: return _hero_fixed_chain*0.5 if _hero_fixed_chain>0.0 else LOWER_LENGTH*leg_length_scale
# Full upper billboard projection; hip anchors share this exact basis.
var projection_basis := Basis.IDENTITY
var boot_yaw := 0.0
var source_provider: Callable
var appearance := {"skin":"warm","species":"human","hair":"windswept","hair_color":"ink","face":"curious"}
var equipment := {"outfit":"outfit-tide","hat":"hat-none"}
var _renderer
var _metadata: Dictionary = {}
var _upper_pivot: Node3D
var _upper: Sprite3D
var _upper_body_mesh: MeshInstance3D
var _upper_body_material: StandardMaterial3D
var _upper_rows := PackedFloat32Array()
var _upper_bind := PackedVector3Array()
var _upper_positions := PackedVector3Array()
var _upper_normals := PackedVector3Array()
var _upper_vertex_bytes := PackedByteArray()
var _legs: Array = []
var _boots: Array[Sprite3D] = []
var _materials: Array[StandardMaterial3D] = []
var _leg_outline: StandardMaterial3D
var _warned: Dictionary = {}
var _closed := false
var _contact_valid: Array[bool] = [false,false]
var _contact_world: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _contact_epoch: Array[int] = [-1,-1]
var _settling := false
var _settle_world: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var ground_height_provider: Callable
var foot_world: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var boot_contact_world: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _boot_contact_offset: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _boot_rotations: Array[Basis] = [Basis.IDENTITY,Basis.IDENTITY]
var _boot_roll: Array[float] = [0.0,0.0]
var _boot_anchor_epoch: Array[int] = [-1,-1]
var _boot_anchor_offset: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _boot_anchor_world: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _pose_flat_contact: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _bind_vertices: PackedVector3Array = bind_vertices()
var _pose_offsets: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _pose_soles: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _pose_ankles: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _pose_support_ground: Array[float] = [0.0,0.0]
var support_drop := 0.0
var _walk_lift_amplitude := 0.0

class VertexBuffer:
	extends RefCounted
	var bytes := PackedByteArray()
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	func _init(count: int) -> void:
		positions.resize(count)
		normals.resize(count)
		# Uncompressed Godot surface: positions then octahedral normal/tangent.
		bytes.resize(count*20)
	func write(index: int, value: Vector3) -> void:
		positions[index] = value
		bytes.encode_float(index*12,value.x)
		bytes.encode_float(index*12+4,value.y)
		bytes.encode_float(index*12+8,value.z)
	func upload(mesh: RID) -> void:
		for index in range(positions.size()):
			var row := index/RING
			var ring := index%RING
			var around := positions[row*RING+(ring+1)%RING]-positions[row*RING+(ring+RING-1)%RING]
			var along := positions[mini(row+1,ROWS.size()-1)*RING+ring]-positions[maxi(row-1,0)*RING+ring]
			var normal := around.cross(along).normalized()
			normals[index] = normal
			var encoded := normal.octahedron_encode()
			var tangent := Vector3(normal.z,-normal.x,normal.y).cross(normal).normalized().octahedron_encode()
			tangent.y = maxf(tangent.y,1.0/32767.0)*0.5+0.5
			var offset := positions.size()*12+index*8
			bytes.encode_u16(offset,int(clampf(encoded.x*65535,0,65535)))
			bytes.encode_u16(offset+2,int(clampf(encoded.y*65535,0,65535)))
			bytes.encode_u16(offset+4,int(clampf(tangent.x*65535,0,65535)))
			bytes.encode_u16(offset+6,int(clampf(tangent.y*65535,0,65535)))
		RenderingServer.mesh_surface_update_vertex_region(mesh,0,0,bytes)

static func idle_body_sample(seconds: float, view: String, actor_role: String = "hero") -> Vector3:
	# Y displacement, source-plane roll and a small forward waist inclination.
	# Hero is the only authored idle profile; no NPC animation is implied.
	if actor_role!="hero": return Vector3.ZERO
	var check := 0.0
	if seconds>=7.0:
		var phase := fposmod(seconds-7.0,12.0)
		if phase<2.4: check = pow(sin(PI*phase/2.4),2)
	var toward_camera := -1.0 if view.contains("right") else 1.0
	if view=="front" or view=="back": toward_camera *= 0.5
	return Vector3(sin(seconds*TAU*0.30)*0.024-check*0.014,toward_camera*deg_to_rad(1.5)*check,deg_to_rad(0.6)*check)

static func forward_for(view: String) -> Vector3:
	var angle := DIRECTIONS.find(view)*TAU/8.0
	return Vector3(sin(angle),0,cos(angle))

static func stance(run: bool) -> float:
	return 0.20 if run else 0.60

static func stride(run: bool, foot_stroke: float = FOOT_STROKE) -> float:
	return foot_stroke/stance(run)

static func foot_offset(distance: float, leg: int, run: bool, foot_stroke: float = FOOT_STROKE, height_scale: float = 1.0) -> Vector2:
	var phase := fposmod(distance/stride(run,foot_stroke)+leg*0.5,1.0)
	if phase<stance(run): return Vector2(foot_stroke*0.5-distance_in_stance(phase,run,foot_stroke),0)
	var swing := (phase-stance(run))/(1.0-stance(run))
	var x := lerpf(-foot_stroke*0.5,foot_stroke*0.5,swing*swing*(3.0-2.0*swing))
	return Vector2(x,sin(swing*PI)*(0.13 if run else 0.065)*height_scale)

static func distance_in_stance(phase: float, run: bool, foot_stroke: float = FOOT_STROKE) -> float:
	return phase*stride(run,foot_stroke)

static func measured_walk_lift(actor_role: String, actual_speed: float) -> float:
	if not NPC_WALK_LIFT_M.has(actor_role): return 0.0
	# At a cautious pace retain toe clearance; at the authored route speed the
	# full role lift is reached. Faster callers cannot enlarge this walk arc.
	var pace := smoothstep(0.0,float(NPC_ROUTE_SPEED_MPS[actor_role]),maxf(0.0,actual_speed))
	return float(NPC_WALK_LIFT_M[actor_role])*lerpf(0.6,1.0,pace)

static func pelvis_bob(distance: float, run: bool, foot_stroke: float = FOOT_STROKE, height_scale: float = 1.0) -> float:
	var phase := fposmod(distance/stride(run,foot_stroke),0.5)
	if not run: return -cos(phase*TAU*2.0)*0.012*height_scale
	if phase<0.2: return -sin(phase/0.2*PI)*0.025*height_scale
	return sin((phase-0.2)/0.3*PI)*0.065*height_scale

static func solve_knee(hip: Vector3, ankle: Vector3, forward: Vector3, upper_length: float = UPPER_LENGTH, lower_length: float = LOWER_LENGTH) -> Vector3:
	var delta := ankle-hip
	var length := delta.length()
	assert(length>0.0001 and length<upper_length+lower_length,"motion rig target outside fixed bone reach")
	var axis := delta/length
	var bend := (forward-axis*forward.dot(axis)).normalized()
	var along := (upper_length*upper_length-lower_length*lower_length+length*length)/(2.0*length)
	return hip+axis*along+bend*sqrt(maxf(0,upper_length*upper_length-along*along))

static func shin_weight(y: float, upper_length: float = UPPER_LENGTH) -> float:
	var scale := upper_length/UPPER_LENGTH
	var u := clampf((y-(upper_length-0.05625*scale))/(0.1125*scale),0,1)
	return u*u*(3.0-2.0*u)

static func surface_vertex(vertex: Vector3, hip: Vector3, knee: Vector3, ankle: Vector3, collar: Basis = Basis.IDENTITY, hip_radius: float = 0.045, upper_length: float = UPPER_LENGTH, length_scale: float = 1.0, bind_radius: float = 0.0) -> Vector3:
	var upper_axis := (knee-hip).normalized()
	var lower_axis := (ankle-knee).normalized()
	var depth := -vertex.y
	var scale := upper_length/UPPER_LENGTH
	var trim := 0.075*scale
	var center: Vector3
	var tangent: Vector3
	if depth<=upper_length-trim:
		center = hip+upper_axis*depth
		tangent = upper_axis
	elif depth>=upper_length+trim:
		center = knee+lower_axis*(depth-upper_length)
		tangent = lower_axis
	else:
		var t := (depth-(upper_length-trim))/(2.0*trim)
		var before := knee-upper_axis*trim
		var after := knee+lower_axis*trim
		center = before*(1-t)*(1-t)+knee*2*t*(1-t)+after*t*t
		tangent = ((knee-before)*(1-t)+(after-knee)*t).normalized()
	var outer := (upper_axis-lower_axis)
	outer = (outer-tangent*outer.dot(tangent)).normalized()
	var bend_outer := outer
	var side := outer.cross(tangent).normalized()
	if side.dot(collar.x)<0:
		side = -side
		outer = -outer
	var cos_half := sqrt(maxf(0.0001,(1.0+upper_axis.dot(lower_axis))*0.5))
	var sin_half := sqrt(maxf(0.0001,(1.0-upper_axis.dot(lower_axis))*0.5))
	var shin := shin_weight(depth,upper_length)
	var bend_weight := 4.0*shin*(1.0-shin)
	var safe_inner_radius := trim*cos_half*cos_half/sin_half*0.75
	var radius := sqrt(vertex.x*vertex.x+vertex.z*vertex.z)
	var inner_scale := lerpf(1.0,minf(1.0,safe_inner_radius/maxf(radius,0.001)),bend_weight)
	var result := center+side*vertex.x+outer*vertex.z*(inner_scale if vertex.z*outer.dot(bend_outer)<0 else 1.0)
	# An immutable, source-aligned proximal cuff spans the entire shorts hole.
	# Blend to the physical chain below the hem, without a separate cap layer.
	var collar_weight := 1.0-smoothstep(0.0,0.16875*scale,maxf(0,depth))
	var radial_unit := bind_radius if bind_radius>0.0 else 0.045*length_scale
	var cuff := hip+collar*Vector3(vertex.x*hip_radius/radial_unit,vertex.y,vertex.z*hip_radius/radial_unit-hip_radius-0.003*length_scale)
	return result.lerp(cuff,collar_weight)

static func boot_depth(yaw: float, length_scale: float = 1.0) -> Vector3:
	return Basis(Vector3.UP,yaw)*Vector3(0,0,0.045*length_scale)

static func solve_support_pelvis(desired: float, offsets: Array[Vector3], ankles: Array[Vector3], upper_length: float = UPPER_LENGTH, lower_length: float = LOWER_LENGTH) -> float:
	# Intersect the two fixed-length leg spheres along the common waist's Y axis.
	# Feet never move; a high step lowers the whole waist until both legs fit.
	var lower := -INF
	var upper := INF
	var total_length := upper_length+lower_length
	var reach := total_length-0.002*total_length/(UPPER_LENGTH+LOWER_LENGTH)
	for leg in range(2):
		var horizontal := Vector2(offsets[leg].x-ankles[leg].x,offsets[leg].z-ankles[leg].z)
		assert(horizontal.length_squared()<reach*reach,"camera/contact bind is incompatible; explicit projection rebind required")
		var height := sqrt(maxf(0,reach*reach-horizontal.length_squared()))
		lower = maxf(lower,ankles[leg].y-height-offsets[leg].y)
		upper = minf(upper,ankles[leg].y+height-offsets[leg].y)
	assert(lower<upper,"terrain foot separation exceeds fixed body reach")
	var supported := minf(upper,maxf(lower,desired))
	assert(absf(supported-desired)<0.18*total_length/(UPPER_LENGTH+LOWER_LENGTH),"terrain step requires an unsupported waist displacement")
	return supported

static func bind_vertices(upper_length: float = UPPER_LENGTH, lower_length: float = LOWER_LENGTH, length_scale: float = 1.0, source_radius: float = 0.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(ROWS.size()*RING)
	var total_length := upper_length+lower_length
	for row in range(ROWS.size()):
		var y: float = ROWS[row]*length_scale
		var radius := lerpf(0.045,0.034,clampf(y/maxf(total_length,0.0001),0,1))*length_scale
		if source_radius>0.0: radius = source_radius*lerpf(1.0,0.034/0.045,clampf(y/maxf(total_length,0.0001),0,1))
		for point in range(RING):
			var angle := point*TAU/RING
			result[row*RING+point] = Vector3(cos(angle)*radius,-y,sin(angle)*radius)
	return result

func _ready() -> void:
	assert(leg_length_scale>=0.35 and leg_length_scale<=1.2,"role leg length scale must stay in the supported 0.35..1.2 range")
	assert(not required_directions.is_empty(),"motion rig requires at least one supported direction")
	for view in required_directions: assert(DIRECTIONS.has(view),"unsupported motion rig direction: "+view)
	if role=="hero" and not source_provider.is_valid(): _renderer = Avatar.new()
	if FileAccess.file_exists(metadata_path):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if value is Dictionary: _metadata = value
	rebuild_sources()
	# Also validate overrides that complete their source table after super.
	_calibrate_hero_sources()
	if not required_directions.has(direction): direction = required_directions[0]
	_upper_pivot = Node3D.new()
	add_child(_upper_pivot)
	_upper = _new_sprite()
	_upper_pivot.add_child(_upper)
	if _hero_fixed_chain>0.0: _build_upper_body()
	for leg in range(2):
		_build_leg()
		var boot := _new_sprite()
		boot.no_depth_test = false
		boot.alpha_scissor_threshold = 0.63
		add_child(boot)
		_boots.append(boot)
	set_direction(direction)
	_last_global_position = global_position
	_pose()

func _new_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.pixel_size = PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.4
	sprite.shaded = true
	sprite.no_depth_test = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Camera yaw is fixed/follows the actor in the review; planes stay vertical.
	return sprite

func _build_upper_body() -> void:
	# Fixed source-pixel rows include every waist/hip anchor, so those exact
	# vertices cannot inherit interpolation from a deforming torso row.
	var rows: Array[float] = []
	for pixel in range(0,361,8): rows.append(float(pixel))
	for record: Dictionary in source_records.values():
		for pixel in [record.pelvis.y,float(record.hips[0][1]),float(record.hips[1][1])]:
			if not rows.has(pixel): rows.append(pixel)
	rows.sort()
	_upper_rows = PackedFloat32Array(rows)
	_upper_bind.resize(rows.size()*2)
	var uv := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	uv.resize(_upper_bind.size())
	normals.resize(_upper_bind.size())
	for row in range(rows.size()):
		for side in range(2):
			var index := row*2+side
			_upper_bind[index] = Vector3((float(side)*280.0-140.0)*PIXEL_SIZE,(180.0-rows[row])*PIXEL_SIZE,0)
			uv[index] = Vector2(float(side),rows[row]/360.0)
			normals[index] = Vector3.BACK
		if row+1<rows.size(): indices.append_array(PackedInt32Array([row*2,row*2+1,(row+1)*2,row*2+1,(row+1)*2+1,(row+1)*2]))
	_upper_positions = _upper_bind.duplicate()
	_upper_normals.resize(_upper_bind.size())
	_upper_vertex_bytes.resize(_upper_bind.size()*20)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _upper_bind
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh.custom_aabb = AABB(Vector3(-1,-1.3,-0.05),Vector3(2,2.6,0.10))
	_upper_body_mesh = MeshInstance3D.new()
	_upper_body_mesh.mesh = mesh
	_upper_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_upper_body_material = StandardMaterial3D.new()
	_upper_body_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_upper_body_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_upper_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_upper_body_material.alpha_scissor_threshold = 0.4
	_upper_body_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_upper_body_mesh.material_override = _upper_body_material
	_upper_pivot.add_child(_upper_body_mesh)
	_upper.visible = false
	for record: Dictionary in source_records.values(): _cache_upper_weights(record)

func _cache_upper_weights(record: Dictionary) -> void:
	var waist := minf(record.pelvis.y,minf(float(record.hips[0][1]),float(record.hips[1][1])))
	var rigid_head_end: float = ceilf(float(record.rigid_head_end)/8.0)*8.0
	assert(rigid_head_end<=waist-8.0,"measured head must leave a bounded torso transition above the pinned waist")
	var weights := PackedFloat32Array()
	weights.resize(_upper_bind.size())
	for row in range(_upper_rows.size()):
		var weight := 1.0-smoothstep(rigid_head_end,waist,_upper_rows[row])
		weights[row*2] = weight
		weights[row*2+1] = weight
	record["upper_body_weights"] = weights

func _pose_upper_body(record: Dictionary, idle: Vector3) -> void:
	if _upper_body_mesh==null: return
	_upper_body_mesh.position = _upper.position
	var weights: PackedFloat32Array = record.upper_body_weights
	var waist := Vector3((record.pelvis.x-140.0)*PIXEL_SIZE,(180.0-record.pelvis.y)*PIXEL_SIZE,0)
	# Contralateral shoulder rotation and a small loading pulse live above the
	# same pinned waist. All head/hair vertices still share one rigid transform.
	var cycle := travel/_stride(running)*TAU
	var gait_roll := -sin(cycle)*deg_to_rad(0.6)*blend
	var gait_yaw := sin(cycle)*deg_to_rad(1.2)*blend
	var loading := -sin(cycle*2.0)*0.004*blend
	var rigid := Basis(Quaternion(Vector3.BACK,idle.y+gait_roll))*Basis(Quaternion(Vector3.UP,gait_yaw))*Basis(Quaternion(Vector3.RIGHT,idle.z))
	for index in range(_upper_bind.size()):
		var transformed := waist+rigid*(_upper_bind[index]-waist)+Vector3(0,idle.x+loading,0)
		var point := _upper_bind[index].lerp(transformed,weights[index])
		_upper_positions[index] = point
		_upper_vertex_bytes.encode_float(index*12,point.x)
		_upper_vertex_bytes.encode_float(index*12+4,point.y)
		_upper_vertex_bytes.encode_float(index*12+8,point.z)
	for index in range(_upper_bind.size()):
		var row := index/2
		var side := index%2
		var across := _upper_positions[row*2+1]-_upper_positions[row*2]
		var along := _upper_positions[mini(row+1,_upper_rows.size()-1)*2+side]-_upper_positions[maxi(row-1,0)*2+side]
		var normal := along.cross(across).normalized()
		_upper_normals[index] = normal
		var encoded := normal.octahedron_encode()
		var tangent := Vector3(normal.z,-normal.x,normal.y).cross(normal).normalized().octahedron_encode()
		tangent.y = maxf(tangent.y,1.0/32767.0)*0.5+0.5
		var offset := _upper_bind.size()*12+index*8
		_upper_vertex_bytes.encode_u16(offset,int(clampf(encoded.x*65535,0,65535)))
		_upper_vertex_bytes.encode_u16(offset+2,int(clampf(encoded.y*65535,0,65535)))
		_upper_vertex_bytes.encode_u16(offset+4,int(clampf(tangent.x*65535,0,65535)))
		_upper_vertex_bytes.encode_u16(offset+6,int(clampf(tangent.y*65535,0,65535)))
	RenderingServer.mesh_surface_update_vertex_region(_upper_body_mesh.mesh.get_rid(),0,0,_upper_vertex_bytes)

func upper_display_point(source_pixel: Vector2) -> Vector3:
	# Read the actual uploaded row positions, including interpolation through
	# the displayed torso triangles; this is not a hip-pivot motion proxy.
	if _upper_body_mesh==null:
		return _upper.global_transform*Vector3((source_pixel.x-140.0)*PIXEL_SIZE,(180.0-source_pixel.y)*PIXEL_SIZE,0)
	for row in range(_upper_rows.size()-1):
		if source_pixel.y<=_upper_rows[row+1]:
			var t := (source_pixel.y-_upper_rows[row])/(_upper_rows[row+1]-_upper_rows[row])
			var left := _upper_positions[row*2].lerp(_upper_positions[(row+1)*2],t)
			var right := _upper_positions[row*2+1].lerp(_upper_positions[(row+1)*2+1],t)
			return _upper_body_mesh.global_transform*left.lerp(right,source_pixel.x/280.0)
	return _upper_body_mesh.global_transform*Vector3((source_pixel.x-140.0)*PIXEL_SIZE,_upper_positions[-1].y,0)

func _measure_upper_head(record: Dictionary, view: String, raw: Image) -> void:
	var frame: int = _renderer.walk_idle_frame(view)
	var metrics: Dictionary = _renderer._walk_source_hair_metrics(view,frame,raw)
	var bounds: Rect2i = metrics.source_bounds.merge(metrics.target_face)
	if str(appearance.get("hair","windswept"))!="windswept":
		# Measure actual visible registration against a cached source-hairstyle
		# reference. Cut bounding boxes also enclose transparent face openings,
		# so their entire rectangle is not the hanging-lock silhouette.
		var reference_look := appearance.duplicate()
		reference_look.hair = "windswept"
		var reference: Image = _renderer.texture(reference_look,equipment,view,frame,"walk").get_image()
		for y in range(record.source.get_height()):
			for x in range(record.source.get_width()):
				var pixel: Color = record.source.get_pixel(x,y)
				var original: Color = reference.get_pixel(x,y)
				if pixel!=original and (pixel.a>0.05 or original.a>0.05):
					bounds = bounds.merge(Rect2i(x,y,1,1))
	# Authored ears join near the measured eye line; horns join the crown.
	# Their source-side construction keeps both inside this full head guard.
	record["source_head_bounds"] = bounds
	record["rigid_head_end"] = float(bounds.end.y+2)
	var axis_row := bounds.position.y+bounds.size.y/2
	var axis_left := 280
	var axis_right := -1
	for x in range(280):
		if record.source.get_pixel(x,axis_row).a>0.63:
			axis_left = mini(axis_left,x)
			axis_right = maxi(axis_right,x)
	assert(axis_right-axis_left>20,"displayed head axis requires two actual opaque source landmarks")
	record["head_roll_points"] = [Vector2(axis_left,axis_row),Vector2(axis_right,axis_row)]

func _build_leg() -> void:
	if _leg_outline==null:
		_leg_outline = StandardMaterial3D.new()
		_leg_outline.albedo_color = LEG_OUTLINE_INK
		_leg_outline.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_leg_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_leg_outline.set_grow_enabled(true)
		# The proximal cuff already sits behind the immutable garment plane.
		# Keep even its grown, current-normal hull inside that clearance.
		_leg_outline.grow_amount = minf(PIXEL_SIZE*0.35,0.003*leg_length_scale*0.75)
	var mount := Node3D.new()
	add_child(mount)
	var skeleton := Skeleton3D.new()
	mount.add_child(skeleton)
	skeleton.add_bone("thigh")
	skeleton.add_bone("shin")
	skeleton.set_bone_parent(1,0)
	skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	skeleton.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3(0,-upper_bone_length,0)))
	skeleton.set_bone_pose_position(1,Vector3(0,-upper_bone_length,0))
	var vertices := _bind_vertices
	var uv := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	uv.resize(vertices.size())
	bones.resize(vertices.size()*4)
	weights.resize(vertices.size()*4)
	for row in range(ROWS.size()):
		var y: float = ROWS[row]
		for point in range(RING):
			var vertex := row*RING+point
			uv[vertex] = Vector2(float(point)/RING,(y-ROWS[0])/(ROWS[-1]-ROWS[0]))
			if row+1<ROWS.size():
				var next := (point+1)%RING
				indices.append_array(PackedInt32Array([row*RING+point,(row+1)*RING+point,row*RING+next,row*RING+next,(row+1)*RING+point,(row+1)*RING+next]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for index in range(vertices.size()): normals[index] = Vector3(vertices[index].x,0,vertices[index].z).normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh.custom_aabb = AABB(Vector3(-0.6,-0.8,-0.6),Vector3(1.2,1.2,1.2))
	var instance := MeshInstance3D.new()
	mount.add_child(instance)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.4
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.next_pass = _leg_outline
	instance.material_override = material
	_materials.append(material)
	_legs.append([mount,skeleton,instance,VertexBuffer.new(vertices.size())])

static func rectangle(values: Array) -> Rect2i:
	return Rect2i(values[0],values[1],values[2],values[3])

func rebuild_sources() -> void:
	source_records.clear()
	diagnostics.clear()
	var roles: Dictionary = _metadata.get("roles",{})
	var views: Dictionary = roles.get(role,{}).get("directions",{})
	for view in required_directions:
		var source_data := _source_for(view)
		if source_data.is_empty():
			diagnostics.append("%s/roles/%s/directions/%s: original source provider missing" % [metadata_path,role,view])
			continue
		var source: Image = source_data.source
		var raw: Image = source_data.raw
		var entry: Dictionary = views.get(view,{})
		var palette_source: Image
		if entry.has("boot_palette_reference"):
			palette_source = _source_for(entry.boot_palette_reference.direction).raw
		var record := prepare_source(source,raw,entry,"%s/roles/%s/directions/%s" % [metadata_path,role,view],palette_source)
		if bool(record.get("measured_source_geometry",false)):
			record.hip_width_scale = 1.0
			var measured_vertices: Array[PackedVector3Array] = []
			for leg in range(2): measured_vertices.append(bind_vertices(upper_bone_length,lower_bone_length,leg_length_scale,float(record.hip_widths[leg])*PIXEL_SIZE))
			record["bind_vertices"] = measured_vertices
		else:
			record.ankle_height = float(record.get("ankle_height",ANKLE_HEIGHT))*leg_length_scale
			record.boot_scale = float(record.get("boot_scale",1.0))*leg_length_scale
			record.hip_height = HIP_HEIGHT*leg_length_scale
			record.hip_width_scale = leg_length_scale
		if _renderer!=null and metadata_path==METADATA_PATH and record.valid:
			var hip_row: float = (float(record.hips[0][1])+float(record.hips[1][1]))*0.5
			var source_ankle_row: float = float(record.source_sole)-float(record.ankle_height)/PIXEL_SIZE
			var boot_pivot_row: float = float(record.sole)-float(record.ankle_height)/(float(record.boot_scale)*PIXEL_SIZE)
			assert(record.boot_image.get_pixel(roundi(record.boot_center),roundi(boot_pivot_row)).a>0.63,"hero inherited foot pivot must enter the complete opaque boot")
			record["hero_pivot_geometry"] = true
			record["source_ankle_row"] = source_ankle_row
			record["source_pivot_chain"] = (source_ankle_row-hip_row)*PIXEL_SIZE
			record.hip_height = (float(record.source_sole)-record.pelvis.y)*PIXEL_SIZE
			_measure_boot_roll(record,view)
			_measure_upper_head(record,view,raw)
			if not _upper_bind.is_empty(): _cache_upper_weights(record)
		source_records[view] = record
		if not record.valid:
			var message: String = record.reason
			diagnostics.append(message)
			if not _warned.has(message):
				_warned[message] = true
				push_warning(message)
	assert(source_records.size()<=8,"direction resource table remains bounded")
	_calibrate_hero_sources()

func _calibrate_hero_sources() -> void:
	if _renderer==null or metadata_path!=METADATA_PATH:
		_bind_vertices = bind_vertices(upper_bone_length,lower_bone_length,leg_length_scale)
		return
	var was_fallback := _hero_source_fallback
	var chains: Array[float] = []
	var complete := required_directions.size()==8 and source_records.size()==8
	for view in DIRECTIONS:
		var record: Dictionary = source_records.get(view,{})
		var path := "%s/roles/hero/directions/%s" % [metadata_path,view]
		var reason := ""
		if record.is_empty(): reason = path+": original source provider missing"
		elif not bool(record.get("valid",false)):
			reason = str(record.get("reason","prepared source invalid"))
			if not reason.begins_with(path+":"): reason = path+": "+reason
		elif not record.has("source_pivot_chain") or not is_finite(float(record.source_pivot_chain)) or float(record.source_pivot_chain)<=0.30 or float(record.source_pivot_chain)>=0.45:
			reason = path+": source-pivot chain "+str(record.get("source_pivot_chain","missing"))+" is outside the measured supported range (0.30,0.45)"
		if not reason.is_empty():
			complete = false
			if not diagnostics.has(reason): diagnostics.append(reason)
		else: chains.append(float(record.source_pivot_chain))
	_hero_fixed_chain = 0.0
	_hero_source_fallback = not complete
	if complete:
		assert(chains.size()==8,"calibration requires all eight validated source-pivot measurements")
		chains.sort()
		_hero_fixed_chain = (chains[3]+chains[4])*0.5
		assert(_hero_fixed_chain>0.30 and _hero_fixed_chain<0.45,"hero source-pivot median is outside its measured supported range")
		_bind_vertices = bind_vertices(upper_bone_length,lower_bone_length,_hero_fixed_chain/(UPPER_LENGTH+LOWER_LENGTH),0.045)
	else:
		# Seven prepared views cannot be posed against the nominal fallback chain.
		# Retain their validity data, but display the complete original sources
		# for the whole set until a rebuild restores all eight measurements.
		_bind_vertices = bind_vertices(upper_bone_length,lower_bone_length,leg_length_scale)
		for record: Dictionary in source_records.values():
			if not record.has("fallback_texture"): record["fallback_texture"] = ImageTexture.create_from_image(record.source)
	if _upper==null: return
	if was_fallback!=_hero_source_fallback:
		# A full-source period has no articulated world plants to carry into a
		# recovered chain. Reset only this mode transition; valid rebuilds retain
		# their existing motion and unchanged source geometry.
		travel = 0.0
		speed = 0.0
		blend = 0.0
		_walk_lift_amplitude = 0.0
		_settling = false
		_contact_valid.fill(false)
		_boot_anchor_epoch.fill(-1)
		_last_global_position = global_position
	if complete and _upper_body_mesh==null: _build_upper_body()
	for chain: Array in _legs:
		var skeleton: Skeleton3D = chain[1]
		skeleton.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3(0,-upper_bone_length,0)))
		skeleton.set_bone_pose_position(1,Vector3(0,-upper_bone_length,0))
	_apply_record()

func _source_for(view: String) -> Dictionary:
	if source_provider.is_valid(): return source_provider.call(role,view,appearance,equipment)
	if role!="hero": return {}
	var frame: int = _renderer.walk_idle_frame(view)
	return {"source":_renderer.texture(appearance,equipment,view,frame,"walk").get_image(),"raw":_renderer._walk_pose_image(view,frame)}

static func prepare_source(source: Image, raw: Image, metadata: Dictionary, path: String, palette_source: Image = null) -> Dictionary:
	var fallback := {"valid":false,"reason":path+": metadata missing","source":source,"upper":source,"texture":ImageTexture.create_from_image(source),"sole":346,"pelvis":Vector2(140,270)}
	if metadata.is_empty(): return fallback
	if metadata.has("invalid"):
		fallback.reason = path+": "+str(metadata.invalid)
		return fallback
	if source.get_width()!=280 or source.get_height()!=360:
		fallback.reason = path+": canonical source canvas mismatch"
		return fallback
	if not metadata.has("skin_rect") or not metadata.has("boot") or not metadata.has("lower") or not metadata.has("pelvis") or not metadata.has("limb_envelopes"): return fallback
	var skin_rect := rectangle(metadata.skin_rect)
	var boot_rect := rectangle(metadata.boot)
	var canvas := Rect2i(0,0,280,360)
	if not canvas.encloses(skin_rect) or not canvas.encloses(boot_rect) or skin_rect.size.x<3 or skin_rect.size.y<3: return fallback
	var source_dimensions := measured_source_dimensions(metadata)
	if bool(source_dimensions.get("invalid",false)):
		fallback.reason = path+": "+str(source_dimensions.get("reason","invalid source measurements"))
		return fallback
	var measured_dimensions_available := not source_dimensions.is_empty()
	var skin_image := source.get_region(skin_rect)
	for y in range(skin_image.get_height()):
		for x in range(skin_image.get_width()):
			if skin_image.get_pixel(x,y).a<0.63:
				fallback.reason = path+": exposed skin texture contains a hole"
				return fallback
	var lower: Array = metadata.lower
	var upper := source.duplicate()
	var boot := Image.create(280,360,false,Image.FORMAT_RGBA8)
	boot.fill(Color.TRANSPARENT)
	var garment_mask := connected_garment_mask(raw,lower)
	if metadata.has("limb_garment_max_y"):
		var cut_y := int(metadata.limb_garment_max_y)
		for envelope_values: Array in metadata.limb_envelopes:
			var envelope := rectangle(envelope_values).intersection(canvas)
			for y in range(maxi(envelope.position.y,cut_y+1),envelope.end.y):
				for x in range(envelope.position.x,envelope.end.x): garment_mask[y*280+x] = 0
	for guard: Array in metadata.get("garment_guards",[]):
		var protected := rectangle(guard).intersection(canvas)
		for y in range(protected.position.y,protected.end.y):
			for x in range(protected.position.x,protected.end.x): garment_mask[y*280+x] = 1
	# Hands can touch thighs in the ink outline. A boot-connected component
	# therefore does not establish anatomical ownership; measured hand contours
	# explicitly remain in the immutable upper, including every finger/outline.
	for values: Array in metadata.get("hand_guards",[]):
		var polygon := source_polygon(values)
		for y in range(360):
			for x in range(280):
				if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon): garment_mask[y*280+x] = 1
	var skin_mask := PackedByteArray()
	skin_mask.resize(280*360)
	# Skin ownership uses immutable raw source hue, unaffected by appearance.
	for box_index in range(mini(2,lower.size())):
		var box := rectangle(lower[box_index]).intersection(canvas)
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				var color := raw.get_pixel(x,y)
				if color.a>0.4 and color.r>0.70 and color.g/color.r>0.4 and color.g/color.r<0.8 and color.b/color.r<0.62:
					skin_mask[y*280+x] = 1
	for y in range(360):
		for x in range(280):
			var removed := skin_mask[y*280+x]!=0
			if not removed and raw.get_pixel(x,y).v<0.20:
				for dy in range(-1,2):
					for dx in range(-1,2):
						if x+dx>=0 and x+dx<280 and y+dy>=0 and y+dy<360 and skin_mask[(y+dy)*280+x+dx]!=0: removed = true
			for box_index in range(2,lower.size()):
				if rectangle(lower[box_index]).has_point(Vector2i(x,y)): removed = true
			# Only cream connected to the actual shorts survives ownership removal.
			var garment := garment_mask[y*280+x]!=0
			if removed and not garment: upper.set_pixel(x,y,Color.TRANSPARENT)
			if boot_rect.has_point(Vector2i(x,y)) and source.get_pixel(x,y).a>=0.4 and (measured_dimensions_available or skin_mask[y*280+x]==0):
				boot.set_pixel(x,y,source.get_pixel(x,y))
	# Follow complete anatomical opaque components to their actual contours,
	# rather than trusting the original guessed shaft rectangle boundaries.
	var limb_mask := connected_limb_mask(raw,garment_mask,skin_mask,lower,metadata.limb_envelopes,metadata.get("limb_corridors",[]))
	for y in range(360):
		for x in range(280):
			if limb_mask[y*280+x]!=0: upper.set_pixel(x,y,Color.TRANSPARENT)
	# This front-view source crop crosses the other leg's shaft silhouette.
	# Explicit authored ownership excludes it even though source outlines touch.
	for exclusion: Array in metadata.get("boot_exclusions",[]):
		var box := rectangle(exclusion).intersection(canvas)
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x): boot.set_pixel(x,y,Color.TRANSPARENT)
	var sole := 0
	var min_x := 280
	var max_x := -1
	var boot_pixels := 0
	for y in range(boot_rect.position.y,boot_rect.end.y):
		for x in range(boot_rect.position.x,boot_rect.end.x):
			if boot.get_pixel(x,y).a>0.63:
				sole = maxi(sole,y+1)
				min_x = mini(min_x,x)
				max_x = maxi(max_x,x)
				boot_pixels += 1
	if boot_pixels<200 or sole<335:
		fallback.reason = path+": complete grounded boot not established"
		return fallback
	var boot_center: float = metadata.get("boot_pivot_x",(min_x+max_x)*0.5)
	var source_sole := sole
	var boot_scale := 1.0
	var ankle_height := ANKLE_HEIGHT
	if metadata.has("boot_asset"):
		var extra_resource := load(str(metadata.boot_asset)) as Texture2D
		if extra_resource==null:
			fallback.reason = path+": isolated back boot candidate missing"
			return fallback
		var extra := extra_resource.get_image()
		var region := rectangle(metadata.boot_asset_region)
		if not Rect2i(Vector2i.ZERO,extra.get_size()).encloses(region): return fallback
		boot = extra.get_region(region)
		boot_scale = float(metadata.boot_asset_scale)
		sole = int(metadata.boot_asset_sole)-region.position.y
		boot_center = float(metadata.boot_asset_pivot[0])-region.position.x
		ankle_height = (float(metadata.boot_asset_sole)-float(metadata.boot_asset_pivot[1]))*boot_scale*PIXEL_SIZE
		for y in range(boot.get_height()):
			for x in range(boot.get_width()):
				if boot.get_pixel(x,y).a<0.4: boot.set_pixel(x,y,Color.TRANSPARENT)
		if palette_source!=null and metadata.has("boot_palette_reference"):
			match_boot_palette(boot,palette_source.get_region(rectangle(metadata.boot_palette_reference.rect)))
	var pelvis := Vector2(metadata.pelvis[0],metadata.pelvis[1])
	if not metadata.has("hip_points") or metadata.hip_points.size()!=2 or not metadata.has("hip_half_width_px") or not metadata.has("opening_spans"):
		fallback.reason = path+": measured shorts opening anchors missing"
		return fallback
	for point: Array in metadata.hip_points:
		if upper.get_pixel(int(point[0]),int(point[1])).a<=0.63:
			fallback.reason = path+": hip anchor does not enter opaque shorts"
			return fallback
	var boot_attachment := Vector2(boot_center,sole-ankle_height/PIXEL_SIZE)
	if measured_dimensions_available:
		ankle_height = float(source_dimensions.ankle_height)
		boot_attachment = opaque_boot_attachment(boot,boot_rect,maxi(boot_rect.position.y,floori(sole-ankle_height/PIXEL_SIZE)))
		if boot_attachment.x<0:
			fallback.reason = path+": measured boot shaft attachment missing"
			return fallback
		boot_center = boot_attachment.x
	return {"valid":true,"reason":"","source":source,"upper":upper,"boot_image":boot,"texture":ImageTexture.create_from_image(upper),"boot_texture":ImageTexture.create_from_image(boot),"skin_texture":ImageTexture.create_from_image(skin_image),"sole":sole,"source_sole":source_sole,"boot_center":boot_center,"boot_attachment":boot_attachment,"boot_scale":boot_scale,"ankle_height":ankle_height,"hip_height":float(source_dimensions.get("hip_height",HIP_HEIGHT)),"hip_width_scale":1.0,"measured_source_geometry":measured_dimensions_available,"pelvis":pelvis,"hips":metadata.hip_points,"hip_widths":metadata.hip_half_width_px,"opening_spans":metadata.opening_spans,"garment_mask":garment_mask,"limb_mask":limb_mask,"limb_envelopes":metadata.limb_envelopes,"lower":lower,"boot_rect":boot_rect,"boot_exclusions":metadata.get("boot_exclusions",[]),"path":path,"external_boot":metadata.has("boot_asset")}

func _measure_boot_roll(record: Dictionary, view: String) -> void:
	# A zero-thickness source sprite proves heel/toe only in the side views.
	# Measure the virtual bottom edges of visible pixels once; never invent a
	# front/back shoe depth or extract images while posing.
	if view!="right" and view!="left": return
	var image: Image = record.boot_image
	var points := PackedVector2Array()
	var bottom := -1
	var left := INF
	var right := -INF
	var unit: float = PIXEL_SIZE*record.boot_scale
	for x in range(image.get_width()):
		var y := image.get_height()-1
		while y>=0 and image.get_pixel(x,y).a<=0.63: y-=1
		if y<0: continue
		points.append(Vector2((x+0.5-record.boot_center)*unit,(record.sole-y-1.0)*unit))
		if y>bottom:
			bottom=y
			left=(x+0.5-record.boot_center)*unit
			right=left
		elif y==bottom:
			left=minf(left,(x+0.5-record.boot_center)*unit)
			right=maxf(right,(x+0.5-record.boot_center)*unit)
	assert(absf(record.sole-bottom-1.0)<0.000001,"side roll uses the existing exact source sole plane")
	var sign: float = 1.0 if view=="right" else -1.0
	var toe: float = right if sign>0 else left
	var heel: float = left if sign>0 else right
	var toe_limit := deg_to_rad(8.0)
	var heel_limit := deg_to_rad(4.0)
	for point in points:
		var beyond_toe := sign*(point.x-toe)
		var beyond_heel := -sign*(point.x-heel)
		if beyond_toe>0.000001: toe_limit=minf(toe_limit,atan2(maxf(0,point.y),beyond_toe))
		if beyond_heel>0.000001: heel_limit=minf(heel_limit,atan2(maxf(0,point.y),beyond_heel))
	record["boot_floor_points"] = points
	record["boot_roll_pivots"] = Vector2(toe,heel)
	record["boot_roll_limits"] = Vector2(toe_limit,heel_limit)
	record["boot_roll_sign"] = sign

static func opaque_boot_attachment(boot: Image, crop: Rect2i, first_row: int) -> Vector2:
	# The foot's whole-image centre can lie in transparent space above a toe.
	# Bind to the actual opaque shaft span, retaining its source pixel centres.
	for y in range(first_row,mini(first_row+8,crop.end.y)):
		var run_start := -1
		var best_start := -1
		var best_length := 0
		for x in range(crop.position.x,crop.end.x+1):
			if x<crop.end.x and boot.get_pixel(x,y).a>0.63:
				if run_start<0: run_start = x
			elif run_start>=0:
				if x-run_start>best_length:
					best_start = run_start
					best_length = x-run_start
				run_start = -1
		if best_length>=3: return Vector2(best_start+best_length*0.5,y+0.5)
	return Vector2(-1,-1)

static func measured_source_dimensions(metadata: Dictionary) -> Dictionary:
	var measurements: Variant = metadata.get("measurements",{})
	if typeof(measurements)!=TYPE_DICTIONARY or not measurements.get("boot_or_bare_foot_rect_complete",false):
		return {}
	if not measurements.has("ankle_height_source_m") or not measurements.has("sole_row_px"):
		return {}
	var pelvis: Variant = metadata.get("pelvis",[])
	if typeof(pelvis)!=TYPE_ARRAY or pelvis.size()<2:
		return {"invalid":true,"reason":"measured source pelvis missing"}
	var sole_row := float(measurements.sole_row_px)
	var pelvis_row := float(pelvis[1])
	var ankle_height := float(measurements.ankle_height_source_m)
	var hip_height := (sole_row-pelvis_row)*PIXEL_SIZE
	if not is_finite(sole_row) or not is_finite(pelvis_row) or not is_finite(ankle_height) or hip_height<=0.0 or ankle_height<=0.0:
		return {"invalid":true,"reason":"measured source dimensions are outside the supported range"}
	return {"hip_height":hip_height,"ankle_height":ankle_height}

static func is_cream(color: Color) -> bool:
	return color.a>0.4 and color.r>0.30 and color.g/color.r>0.65 and color.b/color.r>0.58

static func is_garment_color(color: Color) -> bool:
	return is_cream(color) or (color.a>0.4 and color.g>color.r*1.3 and color.g>color.b*0.75 and color.g>0.12)

static func connected_garment_mask(raw: Image, lower: Array) -> PackedByteArray:
	var cream := PackedByteArray()
	var result := PackedByteArray()
	cream.resize(280*360)
	result.resize(280*360)
	var queue := PackedInt32Array()
	var seed_y := mini(int(lower[0][1]),int(lower[1][1]))
	for y in range(360):
		for x in range(280):
			if y<=seed_y and is_garment_color(raw.get_pixel(x,y)):
				cream[y*280+x] = 1
				queue.append(y*280+x)
	var cursor := 0
	while cursor<queue.size():
		var index := queue[cursor]
		cursor += 1
		var x := index%280
		var y := index/280
		for dy in range(-1,2):
			for dx in range(-1,2):
				var xx := x+dx
				var yy := y+dy
				if xx<0 or xx>=280 or yy<0 or yy>=360: continue
				var neighbor := yy*280+xx
				if cream[neighbor]==0 and is_garment_color(raw.get_pixel(xx,yy)):
					cream[neighbor] = 1
					queue.append(neighbor)
	for y in range(360):
		for x in range(280):
			if cream[y*280+x]!=0: result[y*280+x] = 1
			elif raw.get_pixel(x,y).v<0.65:
				for dy in range(-2,3):
					for dx in range(-2,3):
						if x+dx>=0 and x+dx<280 and y+dy>=0 and y+dy<360 and cream[(y+dy)*280+x+dx]!=0: result[y*280+x] = 1
	return result

static func source_polygon(values: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point: Array in values: polygon.append(Vector2(point[0],point[1]))
	return polygon

static func connected_limb_mask(raw: Image, garment: PackedByteArray, skin: PackedByteArray, lower: Array, envelopes: Array, corridors: Array = []) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(280*360)
	for leg in range(2):
		var envelope := rectangle(envelopes[leg]).intersection(Rect2i(0,0,280,360))
		var seed_boot := rectangle(lower[leg+2])
		var corridor := source_polygon(corridors[leg]) if corridors.size()==2 else PackedVector2Array()
		var allowed := PackedByteArray()
		allowed.resize(280*360)
		for y in range(envelope.position.y,envelope.end.y):
			for x in range(envelope.position.x,envelope.end.x):
				allowed[y*280+x] = int(corridor.is_empty() or Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),corridor))
		var queue := PackedInt32Array()
		for y in range(envelope.position.y,envelope.end.y):
			for x in range(envelope.position.x,envelope.end.x):
				var index := y*280+x
				if allowed[index]!=0 and garment[index]==0 and raw.get_pixel(x,y).a>0.1 and (skin[index]!=0 or seed_boot.has_point(Vector2i(x,y))):
					result[index] = 1
					queue.append(index)
		var cursor := 0
		while cursor<queue.size():
			var index := queue[cursor]
			cursor += 1
			var x := index%280
			var y := index/280
			for dy in range(-1,2):
				for dx in range(-1,2):
					var point := Vector2i(x+dx,y+dy)
					if not envelope.has_point(point): continue
					var neighbor := point.y*280+point.x
					if allowed[neighbor]!=0 and result[neighbor]==0 and garment[neighbor]==0 and raw.get_pixelv(point).a>0.1:
						result[neighbor] = 1
						queue.append(neighbor)
	return result

static func boot_color_mean(image: Image) -> Color:
	var total := Vector3.ZERO
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x,y)
			if color.a>0.63 and color.h<0.17 and color.s>0.2 and color.v>0.15:
				total += Vector3(color.r,color.g,color.b)
				count += 1
	assert(count>10,"boot leather palette reference missing")
	return Color(total.x/count,total.y/count,total.z/count,1)

static func match_boot_palette(boot: Image, reference: Image) -> void:
	var source := boot_color_mean(boot)
	var target := boot_color_mean(reference)
	for y in range(boot.get_height()):
		for x in range(boot.get_width()):
			var color := boot.get_pixel(x,y)
			if color.a>0.4 and color.h<0.17 and color.s>0.2 and color.v>0.05:
				var recolored := Color(color.r*target.r/source.r,color.g*target.g/source.g,color.b*target.b/source.b,color.a)
				boot.set_pixel(x,y,recolored.clamp())

static func hip_offset(record: Dictionary, leg: int) -> Vector3:
	var point: Array = record.hips[leg]
	return Vector3((float(point[0])-record.pelvis.x)*PIXEL_SIZE,(record.pelvis.y-float(point[1]))*PIXEL_SIZE,0)

func set_view_projection(value: Basis, yaw: float, discontinuous: bool = false) -> void:
	# Continuous follow preserves physical world plants. A camera cut/orbit reset
	# is an explicit source-projection discontinuity, never an IK target clamp.
	projection_basis = value.orthonormalized()
	boot_yaw = yaw
	if discontinuous:
		cancel_motion()

func set_direction(view: String) -> void:
	assert(required_directions.has(view))
	_motion_heading_local = forward_for(view)
	if direction!=view:
		direction = view
		travel = _stride(running)*(0.1 if running else 0.3)
		blend = 0
		_contact_valid[0] = false
		_contact_valid[1] = false
		_settling = false
	_apply_record()

func set_appearance(value: Dictionary, equipped: Dictionary = {}) -> void:
	appearance = value.duplicate()
	if not equipped.is_empty(): equipment = equipped.duplicate()
	rebuild_sources()
	_calibrate_hero_sources()
	_apply_record()

func _apply_record() -> void:
	if _upper==null: return
	if not source_records.has(direction):
		_upper.texture = null
		if _upper_body_mesh!=null:
			_upper_body_mesh.visible = false
			_upper_body_material.albedo_texture = null
		for leg in range(2):
			_legs[leg][0].visible = false
			_boots[leg].visible = false
		return
	var record: Dictionary = source_records[direction]
	_upper.texture = record.fallback_texture if _hero_source_fallback else record.texture
	_upper.visible = _hero_source_fallback or _upper_body_mesh==null
	if _upper_body_material!=null:
		_upper_body_material.albedo_texture = _upper.texture
		_upper_body_mesh.visible = not _hero_source_fallback
	for leg in range(2):
		_legs[leg][0].visible = record.valid and not _hero_source_fallback
		_boots[leg].visible = record.valid and not _hero_source_fallback
		if record.valid and not _hero_source_fallback:
			_boots[leg].texture = record.boot_texture
			_boots[leg].pixel_size = PIXEL_SIZE*record.boot_scale
			_materials[leg].albedo_texture = record.skin_texture
	_pose()

func advance(delta: float, requested_speed: float, run: bool) -> void:
	if _closed or delta<=0: return
	# Standalone preview owns its translation and retains bounded acceleration.
	if global_position.distance_to(_last_global_position)>0.01: cancel_motion()
	_motion_heading_local = forward_for(direction)
	var next_speed := move_toward(speed,maxf(0,requested_speed),delta*2.5)
	var before := global_position
	position += forward_for(direction)*(next_speed*delta)
	var displacement := global_position-before
	var moved := Vector3(displacement.x,0,displacement.z).length()
	_advance_gait(delta,moved,moved/delta,run)
	_last_global_position = global_position

func advance_from_motion(delta: float, actual_world_delta: Vector3, run: bool) -> void:
	if _closed: return
	# The caller has already moved its parent. This API never translates nodes.
	var residual := global_position-_last_global_position-actual_world_delta
	var teleported := residual.length()>0.01 or actual_world_delta.length()>maxf(1.0,maxf(delta,0.0)*8.0)
	if teleported:
		cancel_motion()
		return
	if delta<=0:
		if actual_world_delta.length_squared()>0.000000000001: cancel_motion()
		_last_global_position = global_position
		return
	var horizontal := Vector3(actual_world_delta.x,0,actual_world_delta.z)
	var moved := horizontal.length()
	if moved>0.000001:
		_motion_heading_local = (global_basis.inverse()*horizontal.normalized()).normalized()
	_advance_gait(delta,moved,moved/delta,run)
	_last_global_position = global_position

func _advance_gait(delta: float, moved: float, actual_speed: float, run: bool) -> void:
	if run!=running:
		running = run
		travel = _stride(running)*(0.1 if running else 0.3)
		blend = 0
		_contact_valid[0] = false
		_contact_valid[1] = false
		_settling = false
	if actual_speed>0.03 and speed<=0.03:
		travel = _stride(running)*(0.1 if running else 0.3)
		_settling = false
		_contact_valid[0] = false
		_contact_valid[1] = false
	speed = actual_speed
	if NPC_WALK_LIFT_M.has(role):
		var target_lift := measured_walk_lift(role,actual_speed) if actual_speed>0.03 else 0.0
		_walk_lift_amplitude = move_toward(_walk_lift_amplitude,target_lift,delta*NPC_LIFT_CHANGE_MPS)
	travel += moved
	if speed<=0.03 and not _settling:
		_settling = true
		_settle_world[0] = foot_world[0]
		_settle_world[1] = foot_world[1]
	blend = move_toward(blend,1.0 if speed>0.03 else 0.0,delta*5)
	idle_time = 0.0 if speed>0.03 else idle_time+delta
	_pose()

func cancel_motion() -> void:
	idle_time = 0
	speed = 0
	travel = 0
	blend = 0
	_walk_lift_amplitude = 0.0
	_settling = false
	_contact_valid[0] = false
	_contact_valid[1] = false
	_last_global_position = global_position
	_pose()

func _pose() -> void:
	if _upper==null or not source_records.has(direction): return
	# Source/camera setters may pose before the external-motion API sees a
	# relocation. World-space plants from another location are invalid here.
	if global_position.distance_to(_last_global_position)>upper_bone_length+lower_bone_length:
		idle_time = 0
		speed = 0
		travel = 0
		blend = 0
		_settling = false
		_contact_valid[0] = false
		_contact_valid[1] = false
		_last_global_position = global_position
	var record: Dictionary = source_records[direction]
	if _hero_source_fallback:
		var source_pelvis: Vector2 = record.pelvis
		_upper_pivot.basis = projection_basis
		_upper_pivot.position = Vector3(0,(float(record.get("source_sole",record.sole))-source_pelvis.y)*PIXEL_SIZE,0)
		_upper.position = Vector3((140.0-source_pelvis.x)*PIXEL_SIZE,(source_pelvis.y-180.0)*PIXEL_SIZE,0)
		for leg in range(2): foot_world[leg] = global_position
		return
	var idle := idle_body_sample(idle_time,direction,role)*(1.0-blend)
	var bob := pelvis_bob(travel,running,_foot_stroke(running),leg_length_scale)*blend+idle.x*leg_length_scale
	if _hero_fixed_chain>0.0: bob = (bob-idle.x*leg_length_scale)*0.5+idle.x*leg_length_scale
	var nominal_hip_height := float(record.get("hip_height",HIP_HEIGHT*leg_length_scale))
	var forward := _motion_heading_local
	var lateral := Vector3(forward.z,0,-forward.x)
	var measured_geometry := bool(record.get("measured_source_geometry",false))
	var hero_body := bool(record.get("hero_pivot_geometry",false))
	if hero_body: bob -= idle.x*leg_length_scale
	var boot_basis := Basis(Vector3.UP,boot_yaw)
	_upper_pivot.position = Vector3(0,nominal_hip_height+bob,0)
	_upper_pivot.basis = projection_basis*Basis(Quaternion(Vector3.BACK,0.0 if hero_body else idle.y))*Basis(Quaternion(Vector3.RIGHT,0.0 if hero_body else idle.z))*Basis(Quaternion(lateral,-0.08 if running and blend>0.8 else 0.0))
	if bool(record.get("hero_pivot_geometry",false)):
		# Compensate the actual mean hip offset after camera/idle projection;
		# the same source-defined hip height must survive camera pitch changes.
		var mean_hip_offset := (hip_offset(record,0)+hip_offset(record,1))*0.5
		nominal_hip_height += mean_hip_offset.y-(_upper_pivot.basis*mean_hip_offset).y
		_upper_pivot.position.y = nominal_hip_height+bob
	var pelvis: Vector2 = record.pelvis
	_upper.position = Vector3((140.0-pelvis.x)*PIXEL_SIZE,(pelvis.y-180.0)*PIXEL_SIZE,0)
	if hero_body: _pose_upper_body(record,idle)
	if not record.valid:
		_upper_pivot.position.y = (record.sole-pelvis.y)*PIXEL_SIZE
		return
	for leg in range(2):
		var offset := _upper_pivot.basis*hip_offset(record,leg)
		var sample := foot_offset(travel,leg,running,_foot_stroke(running),leg_length_scale)*blend
		if hero_body: sample.y *= (HERO_RUN_LIFT if running else HERO_WALK_LIFT)/(0.13 if running else 0.065)
		if measured_geometry and not running and NPC_WALK_LIFT_M.has(role):
			sample.y *= _walk_lift_amplitude/(0.065*leg_length_scale)
		var sole := forward*sample.x+Vector3(offset.x,sample.y,offset.z)
		var contact := global_transform*(sole+boot_depth(boot_yaw,leg_length_scale))
		var ground_y: float = ground_height_provider.call(Vector2(contact.x,contact.z)) if ground_height_provider.is_valid() else global_position.y
		contact.y = ground_y+sample.y
		var phase := fposmod(travel/_stride(running)+leg*0.5,1.0)
		var epoch := floori(travel/_stride(running)+leg*0.5)
		if _settling:
			contact = _settle_world[leg]
			ground_y = ground_height_provider.call(Vector2(contact.x,contact.z)) if ground_height_provider.is_valid() else global_position.y
			contact.y = lerpf(ground_y,_settle_world[leg].y,blend)
		elif phase<stance(running) and speed>0.03:
			if not _contact_valid[leg] or epoch!=_contact_epoch[leg]:
				_boot_anchor_epoch[leg] = -1
				_contact_world[leg] = contact
				_contact_world[leg].y = ground_y
				_contact_valid[leg] = true
				_contact_epoch[leg] = epoch
			contact = _contact_world[leg]
		else:
			_contact_valid[leg] = false
		_pose_flat_contact[leg] = contact
		sole = global_transform.affine_inverse()*contact-boot_depth(boot_yaw,leg_length_scale)
		var ankle := sole+Vector3(0,record.ankle_height,0)
		_boot_contact_offset[leg] = Vector3.ZERO
		_boot_roll[leg] = 0.0
		if hero_body and not running and record.has("boot_roll_limits") and blend>0.0:
			var limits: Vector2 = record.boot_roll_limits
			var pivots: Vector2 = record.boot_roll_pivots
			if phase<0.08:
				_boot_roll[leg] = record.boot_roll_sign*limits.y*(1.0-smoothstep(0,0.08,phase))*blend
				_boot_contact_offset[leg].x = pivots.y
			elif phase>=0.42 and phase<stance(false):
				_boot_roll[leg] = -record.boot_roll_sign*limits.x*smoothstep(0.42,stance(false),phase)*blend
				_boot_contact_offset[leg].x = pivots.x
			elif phase>=stance(false):
				var swing := (phase-stance(false))/(1.0-stance(false))
				_boot_roll[leg] = record.boot_roll_sign*lerpf(-limits.x,limits.y,smoothstep(0,1,swing))*blend
				# Change supporting source endpoints only as the foot passes flat;
				# these follow the lifted foot and never establish a world plant.
				_boot_contact_offset[leg].x = pivots.x if _boot_roll[leg]*record.boot_roll_sign<0.0 else pivots.y
			if _settling: _boot_roll[leg] *= blend
		_boot_rotations[leg] = boot_basis*Basis(Quaternion(Vector3.BACK,_boot_roll[leg]))
		var pivot := _boot_contact_offset[leg]
		boot_contact_world[leg] = global_transform*(sole+boot_depth(boot_yaw,leg_length_scale)+boot_basis*pivot)
		if hero_body:
			# Heel/toe may lie on a different ramp height than the original flat
			# plant reference. Ground and lock the actual active source point.
			if ground_height_provider.is_valid():
				var reference_ground: float = ground_height_provider.call(Vector2(contact.x,contact.z))
				var active_point := boot_contact_world[leg]
				boot_contact_world[leg].y = ground_height_provider.call(Vector2(active_point.x,active_point.z))+(contact.y-reference_ground)
			if _contact_valid[leg]:
				if _boot_anchor_epoch[leg]!=epoch or _boot_anchor_offset[leg]!=pivot:
					_boot_anchor_epoch[leg]=epoch
					_boot_anchor_offset[leg]=pivot
					_boot_anchor_world[leg]=boot_contact_world[leg]
				boot_contact_world[leg]=_boot_anchor_world[leg]
			else: _boot_anchor_epoch[leg]=-1
			sole = global_transform.affine_inverse()*boot_contact_world[leg]-boot_basis*pivot-boot_depth(boot_yaw,leg_length_scale)
			ankle = sole+boot_depth(boot_yaw,leg_length_scale)+boot_basis*pivot+_boot_rotations[leg]*(Vector3(0,record.ankle_height,-0.045*leg_length_scale)-pivot)
		if measured_geometry:
			var shin_radius: float = float(record.hip_widths[leg])*PIXEL_SIZE*0.034/0.045
			ankle += boot_depth(boot_yaw,leg_length_scale)-boot_basis.z*(shin_radius+0.002)
		_pose_offsets[leg] = offset
		_pose_soles[leg] = sole
		_pose_ankles[leg] = ankle
		var support_ground: float = ground_height_provider.call(Vector2(contact.x,contact.z)) if ground_height_provider.is_valid() else global_position.y
		_pose_support_ground[leg] = (global_transform.affine_inverse()*Vector3(contact.x,support_ground,contact.z)).y
	var support_center := (_pose_support_ground[0]+_pose_support_ground[1])*0.5
	var waist_y := solve_support_pelvis(nominal_hip_height+bob+support_center,_pose_offsets,_pose_ankles,upper_bone_length,lower_bone_length)
	support_drop = nominal_hip_height+bob-waist_y
	_upper_pivot.position.y = waist_y
	for leg in range(2):
		var hip := Vector3(0,waist_y,0)+_pose_offsets[leg]
		var ankle := _pose_ankles[leg]
		var sole := _pose_soles[leg]
		if first_reach_failure.is_empty() and (hip.distance_to(ankle)>=upper_bone_length+lower_bone_length or hip.distance_to(ankle)<0.0001):
			first_reach_failure = {"direction":direction,"leg":leg,"distance":hip.distance_to(ankle),"root":str(global_position),"hip_world":str(global_transform*hip),"ankle_world":str(global_transform*ankle),"support_drop":support_drop,"camera_basis":str(projection_basis)}
			push_error("MOTION_RIG_REACH_STATE "+JSON.stringify(first_reach_failure))
		var knee := solve_knee(hip,ankle,forward,upper_bone_length,lower_bone_length)
		var upper_rotation := Quaternion(Vector3.DOWN,(knee-hip).normalized())
		var lower_rotation := Quaternion(Vector3.DOWN,(ankle-knee).normalized())
		var chain: Array = _legs[leg]
		chain[0].position = hip
		chain[1].set_bone_pose_rotation(0,upper_rotation)
		chain[1].set_bone_pose_rotation(1,upper_rotation.inverse()*lower_rotation)
		var vertices: PackedVector3Array = record.bind_vertices[leg] if measured_geometry else _bind_vertices
		var hip_radius: float = record.hip_widths[leg]*PIXEL_SIZE*float(record.get("hip_width_scale",leg_length_scale))
		for index in range(vertices.size()):
			var posed := surface_vertex(vertices[index],hip,knee,ankle,_upper_pivot.basis,hip_radius,upper_bone_length,leg_length_scale,hip_radius if measured_geometry else 0.0)
			if measured_geometry and index>=(ROWS.size()-1)*RING:
				# Continue the mesh into the retained boot shaft if the anatomical
				# ankle precedes the crop. Bones remain fixed; soles never move.
				var shin_radius := hip_radius*0.034/0.045
				var shaft_height: float = (record.sole-record.boot_attachment.y-1.0)*PIXEL_SIZE
				posed = sole+boot_depth(boot_yaw,leg_length_scale)+Vector3(0,shaft_height,0)+boot_basis*Vector3(vertices[index].x,0,vertices[index].z-shin_radius-0.002)
			chain[3].write(index,posed-hip)
		chain[3].upload(chain[2].mesh.get_rid())
		var boot_size: Vector2 = record.boot_image.get_size()
		_boots[leg].basis = _boot_rotations[leg]
		var pivot := _boot_contact_offset[leg]
		_boots[leg].position = sole+boot_depth(boot_yaw,leg_length_scale)+boot_basis*pivot+_boot_rotations[leg]*(Vector3((boot_size.x*0.5-record.boot_center)*PIXEL_SIZE*record.boot_scale,(record.sole-boot_size.y*0.5)*PIXEL_SIZE*record.boot_scale,0)-pivot)
		_boots[leg].modulate = Color(0.94,0.94,0.94,1) if leg==0 else Color.WHITE
		foot_world[leg] = _pose_flat_contact[leg]

func cleanup() -> void:
	if _closed: return
	# Tree teardown can remove this child before the owner's exiting callback.
	# Releasing resources needs no pose or world transform once it has left.
	if is_inside_tree(): cancel_motion()
	_closed = true
	source_records.clear()
	if _upper!=null: _upper.texture = null
	if _upper_body_material!=null: _upper_body_material.albedo_texture = null
	for boot in _boots: boot.texture = null
	for material in _materials:
		material.albedo_texture = null
		material.next_pass = null
	_leg_outline = null
	_renderer = null
	source_provider = Callable()
	ground_height_provider = Callable()
	_warned.clear()
	diagnostics.clear()

func resource_counts() -> Dictionary:
	return {"directions":source_records.size(),"leg_meshes":_legs.size(),"boot_nodes":_boots.size(),"leg_outline_materials":1 if _leg_outline!=null else 0,"avatar_cache":_renderer.cached_texture_count() if _renderer!=null else 0}

func gait_cycle_distance(run: bool) -> float:
	# Review/capture callers need the initialized role's actual distance cycle;
	# static stride() remains the generic legacy model, not Hero source geometry.
	return _stride(run)

func _stride(run: bool) -> float:
	return stride(run,_foot_stroke(run))

func _foot_stroke(run: bool) -> float:
	return (HERO_WALK_STROKE if _hero_fixed_chain>0.0 and not run else FOOT_STROKE)*leg_length_scale
