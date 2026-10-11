extends Node3D
## Original modular island scenery. All interactions remain data driven.
signal interaction_requested(id: String, label: String)
signal area_changed(label: String)
const WATER = preload("res://game/world/water.gdshader")
const STONE = preload("res://game/world/stone.gdshader")
const WOOD = preload("res://game/world/wood.gdshader")
const GRASS = preload("res://game/world/grass.gdshader")
const LIVING_SPRITE = preload("res://game/world/living_sprite.gdshader")
const ComponentAnimationScript = preload("res://game/world/component_animation.gd")
const NpcActivityScript = preload("res://game/world/npc_activity.gd")
const OcclusionControllerScript = preload("res://game/world/occlusion_controller.gd")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const TimeOfDayScript = preload("res://game/core/time_of_day.gd")
const IDENTITY_ATLAS_PATH := "res://assets/characters/identities-v3.png"
const IDENTITY_REGIONS := {
	"imp": Rect2i(642,350,295,294),
	"ticket": Rect2i(374,667,188,343),
	"announcer": Rect2i(675,642,207,369),
}
const CREAM = Color("#edddb8")
const TEAL = Color("#246c6c")
const CORAL = Color("#da705c")
const GOLD = Color("#edbb65")
var player: CharacterBody3D
var avatar: Sprite3D
var avatar_renderer: RefCounted
var avatar_appearance: Dictionary = {"skin":"warm","species":"human","gender":"neutral","hair":"windswept","hair_color":"ink","face":"curious"}
var avatar_equipped: Dictionary = {"outfit":"outfit-tide","hat":"hat-none"}
var avatar_action := ""
var avatar_action_remaining := 0.0
var last_avatar_direction := ""
var last_avatar_frame := -1
var last_avatar_action := ""
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var points: Array[Dictionary] = []
var component_motion: Node
var npc_activity: Node
var occlusion_controller: Node
var lamps: Array[OmniLight3D] = []
var sprite_frames: Array[Texture2D] = []
var material_cache: Dictionary = {}
var character_frames: Dictionary = {}
var character_sprites: Array[Dictionary] = []
var sprite_ground_anchors: Array[Dictionary] = []
const SPRITE_FOOT_GUARD_PIXELS := 2.0
var avatar_ground_anchor: Node3D
var avatar_contact_shadow: MeshInstance3D
var avatar_last_shadow_offset_y := INF
var identity_atlas: Texture2D
var identity_textures: Dictionary = {}
var identity_warnings: Dictionary = {}
var bubble_material: StandardMaterial3D
var foliage_textures: Dictionary = {}
var foliage_atlas_loaded := false
var foliage_warnings: Dictionary = {}
var facing := "front"
const WALK_STRIDE_DISTANCE := 2.8
const WALK_DIRECTION_HYSTERESIS := deg_to_rad(5.0)
const WALK_DISTANCE_EPSILON := 0.0005
var walk_distance_phase := 0.0
var avatar_is_walking := false
var mesh_count := 0
var blocked := false
var npc_activity_paused := false
var reduced_motion := false
var night := false
var time := 0.0
var current_area := ""
var nearest: Dictionary = {}
var fountain_water: ShaderMaterial
var sea_material: ShaderMaterial
var active_time_phase := TimeOfDayScript.DEFAULT_PHASE
var contact_shadow_material: StandardMaterial3D
var contact_shadows: Array[Dictionary] = []

func _ready() -> void:
	component_motion=ComponentAnimationScript.new()
	component_motion.name="ComponentAnimation"
	add_child(component_motion)
	occlusion_controller=OcclusionControllerScript.new()
	occlusion_controller.name="OcclusionController"
	add_child(occlusion_controller)
	_load_foliage_atlas()
	_load_identity_atlas()
	_build_lighting()
	_build_land()
	_build_shoreline()
	_build_dock()
	_build_plaza()
	_build_avenue()
	_build_gates()
	_build_player()
	_build_camera()
	_update_sprite_grounding()
	occlusion_controller.configure(player,camera)
	_register_npc_activity()
	component_motion.finish_registration()
	print("[park_world] scenery meshes: %d, nodes: %d" % [mesh_count, find_children("*", "Node", true, false).size()+1])
	set_time_of_day(TimeOfDayScript.DEFAULT_PHASE)


func _exit_tree() -> void:
	if is_instance_valid(npc_activity):
		npc_activity.release()
	if is_instance_valid(occlusion_controller):
		occlusion_controller.release()

func _load_foliage_atlas() -> void:
	const ATLAS_PATH := "res://assets/world/tidal-foliage-v2.png"
	const REGIONS_PATH := "res://assets/world/foliage-regions.json"
	if not ResourceLoader.exists(ATLAS_PATH):
		_warn_foliage_once("atlas", "World foliage resource %s is unavailable; using procedural geometry fallback" % ATLAS_PATH)
		return
	var atlas := load(ATLAS_PATH) as Texture2D
	if atlas == null:
		_warn_foliage_once("atlas", "World foliage resource %s did not load as a Texture2D; using procedural geometry fallback" % ATLAS_PATH)
		return
	if not FileAccess.file_exists(REGIONS_PATH):
		_warn_foliage_once("regions", "World foliage region file %s is missing; using procedural geometry fallback" % REGIONS_PATH)
		return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGIONS_PATH))
	if parsed is not Dictionary:
		_warn_foliage_once("regions", "World foliage region file %s is invalid; using procedural geometry fallback" % REGIONS_PATH)
		return
	foliage_atlas_loaded=true
	for key in parsed:
		var rect: Variant=parsed[key]
		if rect is not Array or rect.size()!=4:
			_warn_foliage_once(str(key), "World foliage item '%s' in %s must contain x, y, width and height" % [key,REGIONS_PATH])
			continue
		var numeric := true
		for value in rect:
			if typeof(value)!=TYPE_INT and typeof(value)!=TYPE_FLOAT:
				numeric=false
				break
		if not numeric:
			_warn_foliage_once(str(key), "World foliage item '%s' in %s has nonnumeric rectangle values" % [key,REGIONS_PATH])
			continue
		var x := float(rect[0])
		var y := float(rect[1])
		var width := float(rect[2])
		var height := float(rect[3])
		if not is_finite(x) or not is_finite(y) or not is_finite(width) or not is_finite(height) or x<0.0 or y<0.0 or width<=0.0 or height<=0.0 or x+width>atlas.get_width() or y+height>atlas.get_height():
			_warn_foliage_once(str(key), "World foliage item '%s' rectangle %s exceeds %s bounds (%d x %d)" % [key,str(rect),ATLAS_PATH,atlas.get_width(),atlas.get_height()])
			continue
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(x,y,width,height)
		foliage_textures[str(key)] = texture
	if foliage_textures.is_empty():
		foliage_atlas_loaded=false
		_warn_foliage_once("regions", "World foliage file %s has no valid atlas regions; using procedural geometry fallback" % REGIONS_PATH)

func _warn_foliage_once(key: String, message: String) -> void:
	if foliage_warnings.has(key): return
	foliage_warnings[key]=true
	push_warning(message)

func _foliage_has(key: String) -> bool:
	if foliage_textures.has(key): return true
	if foliage_atlas_loaded:
		_warn_foliage_once(key, "World foliage item '%s' is absent from %s; using procedural geometry fallback for this item" % [key,"res://assets/world/foliage-regions.json"])
	return false

func _build_lighting() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9bc9d9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff0d2")
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.10
	environment.fog_enabled = true
	environment.fog_density = 0.0007
	environment.fog_light_color = Color("#9bc9d9")
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -145, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_color = Color("#fff1cf")
	sun.light_energy = 1.25
	add_child(sun)
	contact_shadow_material = _make_contact_shadow_material()

func _make_contact_shadow_material() -> StandardMaterial3D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(16.0, 16.0)) / 16.0
			var edge := clampf(1.0 - p.length(), 0.0, 1.0)
			image.set_pixel(x, y, Color(0.12, 0.19, 0.20, edge * edge * 0.34))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material_cache["contact_shadow"] = material
	return material

func _add_contact_shadow(anchor: Node3D, local_ground_offset: Vector3, dimensions: Vector2) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	shadow.mesh = plane
	shadow.material_override = contact_shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = local_ground_offset
	anchor.add_child(shadow)
	contact_shadows.append({"node": shadow, "anchor": anchor, "ground_offset": local_ground_offset})
	mesh_count += 1
	return shadow

static func sprite_ground_anchor_y(
	ground_y: float,
	parent_world_y: float,
	sprite_local_y: float,
	feet_row: float,
	canvas_height: float,
	pixel_size: float,
	camera_up_y: float
) -> float:
	var feet_from_center := (feet_row - canvas_height * 0.5) * pixel_size
	return ground_y - parent_world_y - sprite_local_y + feet_from_center * camera_up_y

static func _ground_surface_y(world_position: Vector3) -> float:
	# Match the tops of the plaza/avenue path and dock meshes; the lawn is the fallback.
	if absf(world_position.x) <= 2.46 and world_position.z >= 14.825 and world_position.z <= 26.975:
		return 0.22
	if absf(world_position.x) <= 12.5 and absf(world_position.z) <= 8.0:
		return 0.18
	if absf(world_position.x) <= 4.5 and world_position.z >= -47.0 and world_position.z <= 17.0:
		return 0.18
	return 0.055

func _register_sprite_ground_anchor(sprite: Sprite3D, anchor: Node3D, parent: Node3D, ground_y: float, feet_row: float, canvas_height: float) -> void:
	# Preserve the bottom pixel's entire area, including the one-pixel variation
	# between authored poses. The guard is less than a centimetre in world space.
	feet_row += SPRITE_FOOT_GUARD_PIXELS
	sprite_ground_anchors.append({
		"sprite": sprite,
		"anchor": anchor,
		"parent": parent,
		"ground_y": ground_y,
		"feet_row": feet_row,
		"canvas_height": canvas_height,
	})

func _update_sprite_grounding() -> void:
	if not is_instance_valid(camera):
		return
	var camera_up_y := camera.global_basis.y.y
	for record in sprite_ground_anchors:
		var sprite := record.get("sprite") as Sprite3D
		var anchor := record.get("anchor") as Node3D
		var parent := record.get("parent") as Node3D
		if not is_instance_valid(sprite) or not is_instance_valid(anchor) or not is_instance_valid(parent):
			continue
		var ground_y := float(record.ground_y)
		if parent == player:
			ground_y = _ground_surface_y(player.global_position)
		var desired_y := sprite_ground_anchor_y(
			ground_y,
			parent.global_position.y,
			sprite.position.y,
			float(record.feet_row),
			float(record.canvas_height),
			sprite.pixel_size,
			camera_up_y
		)
		if absf(anchor.position.y - desired_y) > 0.0005:
			anchor.position.y = desired_y
	if is_instance_valid(player) and is_instance_valid(avatar_contact_shadow):
		var ground_y := _ground_surface_y(player.global_position)
		var shadow_y := ground_y - player.global_position.y + 0.005
		if absf(shadow_y - avatar_last_shadow_offset_y) > 0.0005:
			avatar_contact_shadow.position.y = shadow_y
			avatar_last_shadow_offset_y = shadow_y
			for index in range(contact_shadows.size()):
				var record: Dictionary = contact_shadows[index]
				if record.get("node") == avatar_contact_shadow:
					var ground_offset: Vector3 = record.get("ground_offset", Vector3.ZERO)
					ground_offset.y = shadow_y
					record["ground_offset"] = ground_offset
					contact_shadows[index] = record
					break

func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(true), str(emissive)]
	if material_cache.has(key): return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.65
	material_cache[key] = material
	return material

func _wood_material(color: Color) -> ShaderMaterial:
	var key := "wood:" + color.to_html(true)
	if material_cache.has(key): return material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = WOOD
	material.set_shader_parameter("base_color",color)
	material_cache[key]=material
	return material

func _mesh(mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	if is_instance_valid(occlusion_controller):
		occlusion_controller.register_geometry(instance,material)
	mesh_count += 1
	return instance

func _multi_mesh(mesh: Mesh, pos: Vector3, transforms: Array[Transform3D], colors: Array[Color], material: Material) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=mesh
	multi.instance_count=transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_color(i,colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh=multi
	instance.position=pos
	instance.material_override=material
	add_child(instance)
	if is_instance_valid(occlusion_controller):
		occlusion_controller.register_geometry(instance,material)
	mesh_count += 1
	return instance

func _vertex_color_material(cache_key: String, roughness := 0.9) -> StandardMaterial3D:
	if material_cache.has(cache_key): return material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=roughness
	material_cache[cache_key]=material
	return material

func _box(pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, pos, _mat(color))
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		instance.add_child(body)
	return instance

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(mesh, pos, _mat(color))

func _cone(pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=0.0
	mesh.bottom_radius=0.5
	mesh.height=1.0
	mesh.radial_segments=8
	return _mesh(mesh,pos,_mat(color))

func _sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	return _mesh(mesh, pos, _mat(color))

func _label(text: String, pos: Vector3, size := 32, color := CREAM) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.015
	label.modulate = color
	label.outline_size = maxi(2, int(size / 8))
	label.outline_modulate = Color("#223f47")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	return label

func _point(id: String, title: String, pos: Vector3) -> void:
	points.append({"id":id,"label":title,"position":pos})
	var marker := _label("◇", pos + Vector3(0,2.1,0), 38, GOLD)
	points[-1]["marker"]=marker
	component_motion.register_component(marker,"marker",float(points.size())*0.7)

func _register_npc_activity() -> void:
	npc_activity=NpcActivityScript.new()
	npc_activity.name="NpcActivity"
	add_child(npc_activity)
	var point_ids := {"ticket":"guide","imp":"quest-001","announcer":"quest-002"}
	for actor_record in character_sprites:
		var role := String(actor_record.role)
		var interaction_point := _point_by_id(String(point_ids.get(role,"")))
		if interaction_point.is_empty():
			push_warning("ParkWorld: missing interaction point for NPC role '%s'." % role)
			continue
		var sprite := actor_record.sprite as Sprite3D
		var activity_root := actor_record.activity_root as Node3D
		var frames: Array[Texture2D] = NpcActivityScript.load_action_frames(role)
		if not npc_activity.register_actor(sprite,role,frames,activity_root,interaction_point,0.0):
			push_warning("ParkWorld: could not register NPC role '%s' for ambient activity." % role)
	npc_activity.finish_registration()
	npc_activity.set_activity_paused(blocked)
	npc_activity_paused=blocked

func _point_by_id(point_id: String) -> Dictionary:
	for point in points:
		if String(point.get("id",""))==point_id:
			return point
	return {}

func _build_land() -> void:
	sea_material = ShaderMaterial.new()
	sea_material.shader = WATER
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(240,240)
	_mesh(sea_mesh,Vector3(0,-0.42,0),sea_material)
	_box(Vector3(0,-0.75,-14),Vector3(41,1.4,67),Color("#b89b70"))
	var grass_material := ShaderMaterial.new()
	grass_material.shader=GRASS
	_mesh(_island_lawn_mesh(),Vector3(0,0.055,-14),grass_material)
	# Paths lead without dead ends from dock to welcome's four clusters.
	var stone_material := ShaderMaterial.new()
	stone_material.shader = STONE
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(9,0.12,64)
	_mesh(path_mesh,Vector3(0,0.12,-15),stone_material)
	var square_mesh := BoxMesh.new()
	square_mesh.size = Vector3(25,0.12,16)
	_mesh(square_mesh,Vector3(0,0.12,0),stone_material)
	for side in [-1,1]:
		for i in range(14):
			# Open the tree rhythm without shifting any gameplay landmarks.
			if i % 4 == 2:
				continue
			var z := -44.0 + i*4.5
			_tree(Vector3(side*(16.0+sin(i*1.2)*1.8),0,z),i)
			_box(Vector3(side*19.5,0.22,z),Vector3(0.3,0.5,3.8),Color("#d2bc8e"))
		for i in range(5):
			_flowerbed(Vector3(side*5.6,0,-14-i*5.8),i)
	for i in range(26):
		var a := float(i)/26.0*TAU
		_box(Vector3(cos(a)*7.7,0.22,sin(a)*7.7),Vector3(0.55,0.22,0.55),CREAM)
	# Painted stone inlays make the two central paths read as one welcoming route.
	for i in range(16):
		var z := -43.0 + i * 4.0
		for side in [-1.0, 1.0]:
			var shell := _box(Vector3(side * 4.45, 0.205, z), Vector3(0.08, 0.035, 1.15), Color("#d1bc91"))
			shell.rotation.y = side * 0.08
	for side in [-1, 1]:
		for i in range(4):
			var x: float = float(side) * (11.0 + (i % 2) * 2.2)
			_flowerbed(Vector3(x,0,-2.0-float(i/2)*7.4),i+8)

func _island_lawn_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	const SEGMENTS := 48
	for i in range(SEGMENTS):
		var angle := TAU*float(i)/SEGMENTS
		var dx := cos(angle)
		var dz := sin(angle)
		var extent := minf(20.0/maxf(absf(dx),0.0001),33.0/maxf(absf(dz),0.0001))
		var ragged := 1.0 + sin(angle*7.0+0.4)*0.022 + sin(angle*13.0-0.8)*0.013
		vertices.append(Vector3(dx*extent*ragged,0,dz*extent*ragged))
	for i in range(SEGMENTS):
		indices.append(0)
		indices.append((i+1)%SEGMENTS+1)
		indices.append(i+1)
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var normals := PackedVector3Array()
	for i in range(vertices.size()): normals.append(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _build_shoreline() -> void:
	# Layered cut-paper shore ledges and foam stay outside the playable lawn.
	for side in [-1.0, 1.0]:
		for i in range(18):
			var z := -45.0 + i * 3.1
			var wobble := sin(i * 2.17) * 0.5
			var base := Vector3(side * (20.15 + wobble), -0.12, z)
			if _foliage_has("rocks"):
				_foliage_sprite("rocks",base+Vector3(0,-0.12,0),0.95+fmod(float(i)*0.11,0.36))
			else:
				var rock := _sphere(base+Vector3(0,0.02,0),0.72+fmod(float(i)*0.31,0.42),Color("#967e64") if i%3==0 else Color("#b29a77"))
				rock.scale=Vector3(1.35,0.55,1.15)
			var foam := _box(Vector3(side*(20.7+wobble),-0.20,z+0.7),Vector3(0.13,0.035,1.3),Color("#d2e5d8"))
			foam.rotation.y = side * 0.12
			if i % 3 == 0:
				_sea_grass(Vector3(side*19.25,0,z+0.8),i)
	for i in range(13):
		var x := -19.0 + i * 3.15
		var wobble := sin(i * 1.9) * 0.38
		if _foliage_has("rocks"):
			_foliage_sprite("rocks",Vector3(x,-0.12,19.0+wobble),1.1)
		else:
			_sphere(Vector3(x,-0.1,19.0+wobble),0.68,Color("#a58a6b")).scale=Vector3(1.4,0.48,1.0)
		_box(Vector3(x+0.6,-0.2,19.7+wobble),Vector3(1.5,0.035,0.12),Color("#d5e5d8"))

func _sea_grass(pos: Vector3, seed_value: int) -> void:
	var stem_color := Color("#557961")
	for i in range(3):
		var blade := _box(pos+Vector3((i-1)*0.12,0.4,0),Vector3(0.09,0.82,0.07),stem_color)
		blade.rotation.z = (i-1)*0.22
	if seed_value % 2 == 0:
		_sphere(pos+Vector3(0,0.82,0),0.12,CORAL)

func _tree(pos: Vector3, seed_value: int) -> void:
	# Give each avenue band a coherent canopy instead of cycling through a
	# repeated random-looking row of unrelated tree silhouettes.
	var key := "oak"
	var tree_height := 4.35
	if pos.z > -16.0:
		key = "palm"
		tree_height = 4.15
	elif pos.z < -32.0 and pos.x < 0.0:
		key = "pine"
		tree_height = 4.6
	elif pos.z > -30.0 and pos.x > 0.0 and seed_value in [4, 7]:
		key = "ginkgo"
		tree_height = 4.3
	if _foliage_has(key):
		_foliage_sprite(key,pos,tree_height)
		return
	_cylinder(pos+Vector3(0,1.15,0),0.2,2.3,Color("#76583f"))
	for root in [-1,1]:
		var a: float = float(root) * TAU / 4.0 + 0.4
		var buttress := _box(pos+Vector3(cos(a)*0.33,0.25,sin(a)*0.33),Vector3(0.18,0.48,0.18),Color("#8a6948"))
		buttress.rotation.y = a
	for branch in [-1,1]:
		var arm := _box(pos+Vector3(branch*0.42,1.9,0),Vector3(0.13,1.0,0.14),Color("#76583f"))
		arm.rotation.z = branch * -0.58
	# Flat leaf clusters are batched per tree so the foliage stays crisp without
	# creating a separate mesh node for every printed leaf.
	var leaves: Array[Transform3D]=[]
	var leaf_colors: Array[Color]=[]
	var glints: Array[Transform3D]=[]
	var glint_colors: Array[Color]=[]
	for leaf in range(9):
		var a := float(leaf) * TAU / 9.0 + seed_value * 0.17
		var crown := Vector3(cos(a)*0.85,2.55+sin(leaf*2.4)*0.22,sin(a)*0.75)
		var basis := Basis().rotated(Vector3.UP,a).rotated(Vector3.FORWARD,sin(a)*0.18).scaled(Vector3(0.75,0.42,0.32))
		leaves.append(Transform3D(basis,crown))
		leaf_colors.append([Color("#3e7058"),Color("#54845d"),Color("#729365")][leaf%3])
		if leaf % 3 == 0:
			glints.append(Transform3D(Basis().rotated(Vector3.UP,a).scaled(Vector3(0.22,0.035,0.18)),crown+Vector3(0,0.23,0)))
			glint_colors.append(Color("#a1ad72"))
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size=Vector3.ONE
	_multi_mesh(leaf_mesh,pos,leaves,leaf_colors,_vertex_color_material("tree-leaves"))
	var glint_mesh := BoxMesh.new()
	glint_mesh.size=Vector3.ONE
	_multi_mesh(glint_mesh,pos,glints,glint_colors,_vertex_color_material("tree-glints"))
	if seed_value % 3 == 0:
		_lantern(pos+Vector3(0.4,2,0.7))

func _flowerbed(pos: Vector3, seed_value: int) -> void:
	if _foliage_has("planter"):
		_foliage_sprite("planter",pos,1.75+fmod(float(seed_value)*0.07,0.25))
		return
	_box(pos+Vector3(0,0.3,0),Vector3(1.7,0.5,1.3),Color("#ccba92"),true)
	_box(pos+Vector3(0,0.58,0),Vector3(1.5,0.12,1.1),Color("#425c42"))
	var leaves: Array[Transform3D]=[]
	var leaf_colors: Array[Color]=[]
	var petals: Array[Transform3D]=[]
	var petal_colors: Array[Color]=[]
	var centers: Array[Transform3D]=[]
	var center_colors: Array[Color]=[]
	for j in range(7):
		var offset := Vector3(sin(j*2.4)*0.55,0.78,cos(j*3.1)*0.37)
		var leaf_basis := Basis().rotated(Vector3.UP,j*0.8).rotated(Vector3.FORWARD,sin(j*1.7)*0.18).scaled(Vector3(0.16,0.42,0.1))
		leaves.append(Transform3D(leaf_basis,offset*0.72))
		leaf_colors.append(Color("#63865c") if j%2==0 else Color("#779463"))
		petals.append(Transform3D(Basis().rotated(Vector3.UP,j*0.43).scaled(Vector3(0.28,0.08,0.23)),offset))
		petal_colors.append(CORAL if (j+seed_value)%2==0 else GOLD)
		centers.append(Transform3D(Basis().scaled(Vector3(0.07,0.025,0.07)),offset+Vector3(0,0.07,0)))
		center_colors.append(Color("#fff0bd"))
	var blade := BoxMesh.new()
	blade.size=Vector3.ONE
	var petal := BoxMesh.new()
	petal.size=Vector3.ONE
	var center := BoxMesh.new()
	center.size=Vector3.ONE
	_multi_mesh(blade,pos,leaves,leaf_colors,_vertex_color_material("flower-leaves"))
	_multi_mesh(petal,pos,petals,petal_colors,_vertex_color_material("flower-petals"))
	_multi_mesh(center,pos,centers,center_colors,_vertex_color_material("flower-centers"))

func _foliage_sprite(kind: String, ground: Vector3, world_height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture=foliage_textures[kind]
	var region_height: float=foliage_textures[kind].region.size.y
	sprite.pixel_size=world_height/region_height
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded=true
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold=0.45
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position=ground+Vector3(0,world_height*0.5,0)
	var phase := fposmod(ground.x * 0.713 + ground.z * 0.391, TAU)
	_set_living_sprite_material(sprite, 0, phase, 0.72)
	add_child(sprite)
	component_motion.register_component(sprite,"foliage",phase/TAU)
	return sprite


func _set_living_sprite_material(sprite: Sprite3D, kind: int, phase: float, breath_rate: float, idle_role := 0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader=LIVING_SPRITE
	material.set_shader_parameter("motion_kind",kind)
	material.set_shader_parameter("idle_role",idle_role)
	material.set_shader_parameter("phase",phase)
	material.set_shader_parameter("breath_rate",breath_rate)
	material.set_shader_parameter("breath_pixels",0.65)
	material.set_shader_parameter("gesture_pixels",0.65)
	material.set_shader_parameter("tint",Color.WHITE)
	var texture_source: Texture2D=sprite.texture
	var uv_rect := Rect2(0.0,0.0,1.0,1.0)
	if texture_source is AtlasTexture and texture_source.atlas != null:
		var atlas_texture := texture_source as AtlasTexture
		var atlas_size := Vector2(atlas_texture.atlas.get_width(),atlas_texture.atlas.get_height())
		uv_rect=Rect2(atlas_texture.region.position/atlas_size,atlas_texture.region.size/atlas_size)
		texture_source=atlas_texture.atlas
	material.set_shader_parameter("texture_albedo",texture_source)
	material.set_shader_parameter("uv_rect",Vector4(uv_rect.position.x,uv_rect.position.y,uv_rect.size.x,uv_rect.size.y))
	sprite.material_override=material
	component_motion.register_shader(material)
	return material

func _lantern(pos: Vector3) -> void:
	_cylinder(pos,0.14,0.36,Color("#805b39"))
	var shade := _box(pos+Vector3(0,0.05,0),Vector3(0.3,0.3,0.3),Color("#f6ca78"))
	shade.material_override = _mat(Color("#ffd68b"),true)
	component_motion.register_component(shade,"soft_scale",float(lamps.size())*0.23)
	var cap := _cone(pos+Vector3(0,0.24,0),Color("#7d6345"))
	cap.scale=Vector3(0.2,0.12,0.2)
	if lamps.size() < 12:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color("#ffc276")
		light.omni_range = 4.2
		light.light_energy = 0.0
		add_child(light)
		lamps.append(light)
		component_motion.register_light(light,float(lamps.size())*0.17)

func _arch(pos: Vector3, title: String, color: Color, wide := 5.0) -> void:
	# Register the arch's opaque frame and its title's local visibility. Lanterns
	# keep their existing materials; the title hides only when it overlaps the mask.
	occlusion_controller.begin_building()
	var left_pillar := _box(pos+Vector3(-wide*0.5,1.65,0),Vector3(0.5,3.3,0.6),CREAM,true)
	var blocker := left_pillar.get_child(0) as StaticBody3D
	_box(pos+Vector3(wide*0.5,1.65,0),Vector3(0.5,3.3,0.6),CREAM,true)
	_box(pos+Vector3(0,3.4,0),Vector3(wide+0.8,0.7,0.7),color)
	for i in range(7):
		var flag := _box(pos+Vector3(-wide*0.45+i*wide*0.15,2.85,0),Vector3(0.4,0.35,0.04),CORAL if i%2==0 else GOLD)
		component_motion.register_component(flag,"flag",float(i)*0.6)
	var arch_title := _label(title,pos+Vector3(0,3.5,0.43),30)
	occlusion_controller.register_visibility_label(arch_title)
	occlusion_controller.finish_building(blocker)
	for side in [-1,1]:
		_lantern(pos+Vector3(side*(wide*0.5-0.4),2.3,0))

func _build_dock() -> void:
	_box(Vector3(0,0.0,21),Vector3(5,0.3,13),Color("#a17b52"))
	for i in range(27):
		var plank := _box(Vector3(0,0.18,15+i*0.45),Vector3(4.92,0.08,0.35),Color("#9a7149"))
		plank.material_override = _wood_material(Color("#9a7149"))
		for side in [-1,1]:
			_cylinder(Vector3(side*2.18,0.25,15+i*0.45),0.035,0.025,Color("#d2b47d"))
	for side in [-1,1]:
		for i in range(5):
			var z := 16.0+i*2.7
			_cylinder(Vector3(side*2.5,0.6,z),0.12,1.4,Color("#665d45"))
			if i<4:
				var rope := _box(Vector3(side*2.5,1.12,z+1.35),Vector3(0.07,0.08,2.7),Color("#ddcba0"))
				rope.rotation.x = 0.08
				if i % 2 == 0: _lantern(Vector3(side*2.5,1.45,z+1.35))
	_arch(Vector3(0,0,13.8),"SNAPLAND",TEAL,5.5)
	_box(Vector3(0,0.22,14.4),Vector3(6.6,0.18,0.28),Color("#d7bc8d"))
	for side in [-1,1]:
		_cylinder(Vector3(side*3.15,1.5,15.2),0.09,3.0,Color("#755b40"))
		var pennant := _box(Vector3(side*3.15,2.65,15.5),Vector3(0.8,0.65,0.06),CORAL if side<0 else GOLD)
		pennant.rotation.z = -0.15*side
	# A string of tiny warm bulbs frames the arrival arch after dusk.
	for i in range(9):
		var x := -2.8 + i * 0.7
		_box(Vector3(x,3.75,13.65),Vector3(0.035,0.3,0.035),Color("#6e563c"))
		_lantern(Vector3(x,3.55,13.65))
	# Original ferry silhouette, with portholes, lifebuoy, chimney and pennants.
	var hull := _box(Vector3(5.5,0,25),Vector3(5,0.8,8),Color("#e4d7b6"),true)
	var bow := _mesh(CylinderMesh.new(),Vector3(5.5,0,20.8),_mat(Color("#e4d7b6")))
	bow.scale=Vector3(2.5,0.42,1.4)
	_box(Vector3(5.5,0.7,25),Vector3(4,0.6,6.5),TEAL)
	_box(Vector3(5.5,1.8,25.4),Vector3(3,1.6,4),CREAM)
	_box(Vector3(5.5,2.7,25.4),Vector3(3.7,0.3,4.6),CORAL)
	_cylinder(Vector3(5.5,3.35,25.5),0.45,1.2,TEAL)
	for i in range(3):
		_sphere(Vector3(3.95,1.85,24+i*1.2),0.3,Color("#335b6e"))
		_cylinder(Vector3(7.62,1.9,24+i*1.2),0.14,0.06,Color("#d8b277"))
	_cylinder(Vector3(4.25,1.8,24.8),0.5,0.12,CORAL,0.5)
	_box(Vector3(5.5,1.15,21.9),Vector3(3.5,0.12,0.1),Color("#ddc69a"))
	for i in range(5):
		var mast := _box(Vector3(4.1+i*0.7,2.9,22.9),Vector3(0.055,0.9,0.055),Color("#715b42"))
		mast.rotation.z = -0.2
		var pennant_flag := _box(Vector3(4.1+i*0.7,3.3,22.9),Vector3(0.45,0.23,0.05),[CORAL,GOLD,CREAM][i%3])
		pennant_flag.rotation.z = -0.12
	_label("晚風號",Vector3(5.5,1.2,28.5),24)
	_point("arrival","重播上島導覽",Vector3(0,0,24))
	_label("碼頭  /  海風從這裡開始",Vector3(-4,1,19),24)

func _build_plaza() -> void:
	# Tiered fountain anchors the main area's visual silhouette.
	_cylinder(Vector3(0,0.45,0),2.8,0.6,CREAM)
	for i in range(24):
		var a := i*TAU/24.0
		var tile := _box(Vector3(cos(a)*2.57,0.79,sin(a)*2.57),Vector3(0.47,0.07,0.2),[Color("#dfc99e"),Color("#e7d7b8")][i%2])
		tile.rotation.y = -a
	_cylinder(Vector3(0,0.78,0),2.5,0.13,Color("#7ac3c8"))
	fountain_water = ShaderMaterial.new()
	fountain_water.shader = WATER
	var disk := CylinderMesh.new()
	disk.top_radius=2.4
	disk.bottom_radius=2.4
	disk.height=0.07
	_mesh(disk,Vector3(0,0.86,0),fountain_water)
	_cylinder(Vector3(0,1.2,0),0.55,1.0,CREAM)
	_cylinder(Vector3(0,1.8,0),1.5,0.25,CREAM)
	_sphere(Vector3(0,2.2,0),0.42,GOLD)
	for i in range(8):
		var a := i*TAU/8.0
		var stream := _box(Vector3(cos(a)*1.15,1.38,sin(a)*1.15),Vector3(0.07,0.64,0.07),Color("#79cbd0"))
		stream.rotation.z=cos(a)*0.32
		stream.rotation.x=sin(a)*0.32
		_cylinder(Vector3(cos(a)*1.55,0.95,sin(a)*1.55),0.11,0.12,GOLD)
	for i in range(12):
		var a := i*TAU/12.0
		var bead := _sphere(Vector3(cos(a)*1.2,1.8,sin(a)*1.2),0.08,Color("#b3e4df"))
		component_motion.register_component(bead,"water",float(i)*0.5)
	for i in range(8):
		var a := i*TAU/8.0
		var lamp_post := Vector3(cos(a)*9.6,0,sin(a)*8.0)
		_lamppost(lamp_post)
	for i in range(4):
		var fan := _box(Vector3(-4.2+i*2.8,0.205,9.2),Vector3(1.0,0.03,0.16),Color("#c2ad84"))
		fan.rotation.y = (i%2)*0.25
		for j in range(3):
			var star := _box(Vector3(-4.2+i*2.8,0.23,8.8+j*0.3),Vector3(0.12,0.035,0.12),GOLD)
			star.rotation.y = j*0.8
	var collision := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius=2.8
	cylinder.height=1.5
	shape.shape=cylinder
	collision.add_child(shape)
	add_child(collision)
	_kiosk(Vector3(-6,0,5),"導覽亭",TEAL)
	# Keep the whole sprite on one ground level: the raised avenue starts at x=-4.5.
	_npc(Vector3(-5.8,0,10),CORAL,"票票")
	_point("guide","與票票合照",Vector3(-5.8,0,10))
	_kiosk(Vector3(6,0,5),"拍貼本",CORAL)
	_point("album","翻閱拍貼收藏",Vector3(6,0,7))
	_kiosk(Vector3(-7,0,-5),"借用道具",GOLD)
	_point("settings","設定與輔助",Vector3(-7,0,-3))
	_cylinder(Vector3(7,1.1,-5),0.45,2.2,TEAL)
	_sphere(Vector3(7,2.4,-5),0.7,CREAM)
	_label("日夜鐘",Vector3(7,3.5,-5),26)
	_point("clock","切換日夜",Vector3(7,0,-3))
	for side in [-1.0,1.0]:
		_bench(Vector3(side*12.0,0,5.5))
		_bench(Vector3(side*12.0,0,-8.0))
		_shrub_cluster(Vector3(side*14.0,0,2.0),side)
		_shrub_cluster(Vector3(side*14.0,0,-5.8),-side)
	_arch(Vector3(0,0,-11),"迎賓大道",CORAL,8)
	_label("中央廣場",Vector3(0,4.7,1),30)

func _bench(pos: Vector3) -> void:
	var wood := Color("#956d48")
	for board in range(3):
		var seat := _box(pos+Vector3(0,0.72,board*0.16-0.16),Vector3(2.0,0.09,0.13),wood if board%2==0 else Color("#a77b50"))
		seat.material_override=_wood_material(Color("#956d48") if board%2==0 else Color("#a77b50"))
	for side in [-1.0,1.0]:
		_box(pos+Vector3(side*0.78,0.38,0),Vector3(0.11,0.7,0.12),Color("#5f5142"))
		_box(pos+Vector3(side*0.78,1.12,-0.26),Vector3(0.12,1.05,0.12),Color("#5f5142"))
		_cylinder(pos+Vector3(side*0.78,0.87,0.16),0.13,0.12,GOLD)
	var back := _box(pos+Vector3(0,1.17,-0.26),Vector3(1.82,0.16,0.13),wood)
	back.material_override=_wood_material(wood)

func _shrub_cluster(pos: Vector3, seed_value: float) -> void:
	if _foliage_has("shrub"):
		_foliage_sprite("shrub",pos,2.05)
		return
	var branch := _cylinder(pos+Vector3(0,0.34,0),0.07,0.68,Color("#806143"))
	var leaves: Array[Transform3D]=[]
	var colors: Array[Color]=[]
	for i in range(7):
		var a := TAU*float(i)/7.0+seed_value
		var origin := Vector3(cos(a)*0.34,0.78+sin(i*2.1)*0.08,sin(a)*0.34)
		leaves.append(Transform3D(Basis().rotated(Vector3.UP,a).rotated(Vector3.FORWARD,sin(a)*0.32).scaled(Vector3(0.42,0.18,0.24)),origin))
		colors.append([Color("#385e49"),Color("#527952"),Color("#789563")][i%3])
	_multi_mesh(BoxMesh.new(),pos,leaves,colors,_vertex_color_material("shrub-leaves"))
	for side in [-1.0,1.0]:
		var blossom := _box(pos+Vector3(side*0.3,0.26,0.28),Vector3(0.18,0.12,0.15),CORAL if side<0 else GOLD)
		blossom.rotation.y=side*0.35

func _kiosk(pos: Vector3, title: String, color: Color) -> void:
	occlusion_controller.begin_building()
	var opaque_base := _box(pos+Vector3(0,0.7,0),Vector3(3.8,1.3,2.5),CREAM,true)
	var blocker := opaque_base.get_child(0) as StaticBody3D
	_box(pos+Vector3(0,0.48,1.28),Vector3(3.7,0.14,0.11),Color("#876843"))
	_box(pos+Vector3(0,1.25,1.31),Vector3(3.1,0.12,0.13),Color("#876843"))
	var product_transforms: Array[Transform3D]=[]
	var product_colors: Array[Color]=[]
	for i in range(5):
		product_transforms.append(Transform3D(Basis().scaled(Vector3(0.34,0.08,0.65)),Vector3(-1.1+i*0.55,1.45,0.7)))
		product_colors.append([CORAL,GOLD,TEAL,Color("#7abec3"),CORAL][i])
	_multi_mesh(BoxMesh.new(),pos,product_transforms,product_colors,_vertex_color_material("kiosk-products"))
	_box(pos+Vector3(0,1.7,0),Vector3(4.2,0.3,3),color)
	var support_transforms: Array[Transform3D]=[]
	var support_colors: Array[Color]=[]
	for side in [-1.0,1.0]:
		for row in range(2):
			support_transforms.append(Transform3D(Basis().scaled(Vector3(0.16 if row==0 else 0.12,1.4 if row==0 else 1.2,0.16 if row==0 else 0.12)),Vector3(side*(1.65 if row==0 else 1.87),1.85 if row==0 else 1.9,0.0 if row==0 else 0.8)))
			support_colors.append(TEAL if row==0 else Color("#9a7854"))
	_multi_mesh(BoxMesh.new(),pos,support_transforms,support_colors,_vertex_color_material("kiosk-supports"))
	# Two printed-paper roof planes make the stand read as a little harbor pavilion.
	var roof_left := _box(pos+Vector3(-1.08,2.62,0),Vector3(2.35,0.28,3.35),color)
	var roof_right := _box(pos+Vector3(1.08,2.62,0),Vector3(2.35,0.28,3.35),color)
	roof_left.rotation.z=-0.18
	roof_right.rotation.z=0.18
	_box(pos+Vector3(0,2.87,0),Vector3(0.22,0.32,3.45),Color("#866b47"))
	_box(pos+Vector3(0,2.48,1.69),Vector3(4.85,0.14,0.12),Color("#f1d9a9"))
	var scallop_transforms: Array[Transform3D]=[]
	var scallop_colors: Array[Color]=[]
	for i in range(9):
		var tilt := 0.04 if i%2==0 else -0.04
		scallop_transforms.append(Transform3D(Basis().rotated(Vector3.FORWARD,tilt).scaled(Vector3(0.45,0.38,0.13)),Vector3(-1.8+i*0.45,2.25,1.72)))
		scallop_colors.append(CREAM if i%2==0 else Color("#f1d9a9"))
	_multi_mesh(BoxMesh.new(),pos,scallop_transforms,scallop_colors,_vertex_color_material("kiosk-awning-fringe"))
	var plaque := _box(pos+Vector3(0,2.01,1.59),Vector3(2.7,0.54,0.12),Color("#755a3c"))
	_box(pos+Vector3(0,2.01,1.67),Vector3(2.55,0.4,0.06),color)
	_label(title,pos+Vector3(0,1.94,1.73),19)
	# Small brass studs and roof tiles share batched meshes across each stand.
	var tile_transforms: Array[Transform3D]=[]
	var tile_colors: Array[Color]=[]
	for side in [-1.0,1.0]:
		for row in range(3):
			for col in range(5):
				var tile_basis := Basis().rotated(Vector3.FORWARD,side*0.18).scaled(Vector3(0.32,0.035,0.58))
				tile_transforms.append(Transform3D(tile_basis,Vector3(side*(0.32+col*0.43),2.79-row*0.075,-1.0+row*0.8)))
				tile_colors.append(Color("#a96d55") if (col+row)%3==0 else color)
	_multi_mesh(BoxMesh.new(),pos,tile_transforms,tile_colors,_vertex_color_material("kiosk-roof-tiles"))
	var stud_transforms: Array[Transform3D]=[]
	var stud_colors: Array[Color]=[]
	for side in [-1.0,1.0]:
		stud_transforms.append(Transform3D(Basis().scaled(Vector3(0.1,0.1,0.06)),Vector3(side*1.9,1.95,1.73)))
		stud_colors.append(GOLD)
	_multi_mesh(BoxMesh.new(),pos,stud_transforms,stud_colors,_vertex_color_material("kiosk-studs"))
	occlusion_controller.finish_building(blocker)

func _lamppost(pos: Vector3) -> void:
	if _foliage_has("lamp"):
		_foliage_sprite("lamp",pos,2.85)
		var decorative_light := OmniLight3D.new()
		decorative_light.position=pos+Vector3(0,2.18,0)
		decorative_light.light_color=Color("#ffd79a")
		decorative_light.omni_range=5.2
		decorative_light.light_energy=0.0
		add_child(decorative_light)
		lamps.append(decorative_light)
		component_motion.register_light(decorative_light,float(lamps.size())*0.17)
		return
	_cylinder(pos+Vector3(0,1.2,0),0.09,2.4,Color("#554c3f"))
	_cylinder(pos+Vector3(0,2.25,0),0.28,0.12,Color("#92734c"))
	var glow := _box(pos+Vector3(0,2.55,0),Vector3(0.3,0.42,0.3),Color("#f4d292"))
	glow.material_override=_mat(Color("#ffe0a0"),true)
	for side in [-1,1]:
		_box(pos+Vector3(side*0.21,2.76,0),Vector3(0.06,0.48,0.06),Color("#554c3f"))
	_cylinder(pos+Vector3(0,2.98,0),0.19,0.08,Color("#554c3f"))
	var light := OmniLight3D.new()
	light.position=pos+Vector3(0,2.55,0)
	light.light_color=Color("#ffd79a")
	light.omni_range=5.2
	light.light_energy=0.0
	add_child(light)
	lamps.append(light)
	component_motion.register_light(light,float(lamps.size())*0.17)

func _build_avenue() -> void:
	var names := ["氣球快遞","風箏穿環","噴泉跳拍","人潮指揮","帽子救援","彩帶節拍","花壇拼圖","招牌平衡","影子捉迷藏","泡泡合照","長椅換位","迎賓大合奏"]
	for i in range(12):
		var side := -1 if i%2==0 else 1
		var pos := Vector3(side*8.3,0,-17-float(i/2)*4.8)
		var color := [CORAL,TEAL,GOLD][i%3] as Color
		_kiosk(pos,names[i],color)
		_point("game-%03d"%(i+1),names[i],pos+Vector3(-side*2.3,0,1))
		_cylinder(pos+Vector3(-side*2.3,0.28,1),0.75,0.16,color)
		_game_feature(i,pos,color)
	_npc(Vector3(-3.4,0,-19.5),CORAL,"小角")
	_point("quest-001","吉祥物的尾巴危機",Vector3(-3.4,0,-19.5))
	_npc(Vector3(3.4,0,-19.5),TEAL,"阿浪")
	_point("quest-002","廣播即興救場",Vector3(3.4,0,-19.5))
	_point("explore-001","花壇會眨眼",Vector3(-3,0,-25))
	_point("explore-002","歡迎字樣的影子",Vector3(3,0,-31))
	_box(Vector3(-3,0.7,-37),Vector3(2,0.3,0.7),GOLD,true)
	_point("explore-003","長椅雙人份",Vector3(-3,0,-35.7))
	_arch(Vector3(0,0,-45),"倒影大道",Color("#655178"),5)
	_point("rift","查看倒影大道",Vector3(0,0,-43))

func _game_feature(index: int, pos: Vector3, color: Color) -> void:
	# Each booth gets a large, readable silhouette of the activity on offer.
	match index:
		0: # Balloon delivery: cluster, threads and a small parcel basket.
			for j in range(3):
				var balloon := _sphere(pos+Vector3(-0.65+j*0.65,3.7+j*0.18,0),0.36,[CORAL,GOLD,Color("#77c7ce")][j])
				component_motion.register_component(balloon,"balloon",float(j))
				_box(pos+Vector3(-0.65+j*0.65,3.25,0),Vector3(0.025,0.38,0.025),CREAM)
			_box(pos+Vector3(0,3.02,0),Vector3(0.64,0.27,0.46),Color("#9a7149"))
		1: # Kite-ring course: paper kite tails and three target hoops.
			for j in range(3):
				var hoop := _mesh(TorusMesh.new(),pos+Vector3(-0.82+j*0.82,3.5-j*0.14,0),_mat([CORAL,GOLD,TEAL][j]))
				hoop.scale=Vector3(0.34,0.34,0.22)
				hoop.rotation_degrees.x=90
			var kite := _cone(pos+Vector3(0,4.05,-0.12),color)
			kite.rotation_degrees.z=45
			kite.scale=Vector3(0.58,0.7,0.16)
			for j in range(3): _box(pos+Vector3(0,3.25-j*0.2,0.12),Vector3(0.28,0.045,0.04),CORAL if j%2==0 else GOLD)
		2: # Fountain photo: scalloped basin and a crown of paper jets.
			_cylinder(pos+Vector3(0,3.05,0),0.95,0.25,CREAM)
			_cylinder(pos+Vector3(0,3.22,0),0.78,0.13,Color("#62b8c1"))
			_cylinder(pos+Vector3(0,3.48,0),0.18,0.58,Color("#d0b37d"))
			for j in range(6):
				var a := j*TAU/6.0
				var jet := _box(pos+Vector3(cos(a)*0.56,3.57,sin(a)*0.56),Vector3(0.07,0.64,0.07),Color("#7dcbd0"))
				jet.rotation.z=cos(a)*0.32
		3: # Crowd director: three arrow signs and a striped queue post.
			for j in range(3):
				var y := 3.3+j*0.37
				_box(pos+Vector3(0,y,0),Vector3(0.1,0.7,0.1),Color("#745b42"))
				var arrow := _box(pos+Vector3(-0.54+j*0.54,y+0.26,0),Vector3(0.74,0.28,0.13),[CORAL,GOLD,TEAL][j])
				arrow.rotation.z=0.08*(j-1)
				var tip := _cone(pos+Vector3(-0.15+j*0.54,y+0.26,0),[CORAL,GOLD,TEAL][j])
				tip.rotation_degrees.z=-90
				tip.scale=Vector3(0.2,0.3,0.12)
		4: # Hat rescue: oversized top hat above a striped hat stand.
			_cylinder(pos+Vector3(0,3.08,0),0.92,0.15,GOLD)
			_cylinder(pos+Vector3(0,3.48,0),0.52,0.72,Color("#514258"),0.58)
			_box(pos+Vector3(0,3.35,0.51),Vector3(0.58,0.11,0.05),CORAL)
		5: # Ribbon rhythm: three curling strips on a music staff.
			for j in range(3):
				var strip := _box(pos+Vector3(0,3.15+j*0.23,0),Vector3(2.1,0.09,0.16),[CORAL,GOLD,Color("#64b9bd")][j])
				strip.rotation.z=sin(j*2.1)*0.19
				_box(pos+Vector3(-0.8+j*0.8,3.7,0),Vector3(0.13,0.32,0.13),CREAM)
		6: # Flower puzzle: color tiles around a layered rosette.
			for j in range(8):
				var a := j*TAU/8.0
				var petal := _box(pos+Vector3(cos(a)*0.65,3.3,sin(a)*0.65),Vector3(0.42,0.11,0.26),[CORAL,GOLD,Color("#84aa69")][j%3])
				petal.rotation.y=-a
			_sphere(pos+Vector3(0,3.42,0),0.27,Color("#fff0bd"))
		7: # Sign balance: seesaw plank, brass fulcrum and two sign weights.
			var beam := _box(pos+Vector3(0,3.35,0),Vector3(2.3,0.18,0.34),Color("#9a7149"))
			beam.rotation.z=0.16
			var fulcrum := _cone(pos+Vector3(0,3.02,0),CORAL)
			fulcrum.scale=Vector3(0.45,0.42,0.35)
			for side in [-1,1]:
				_box(pos+Vector3(side*0.9,3.67,0),Vector3(0.62,0.45,0.12),TEAL if side<0 else GOLD)
		8: # Shadow hide-and-seek: moon, sun and a hinged shadow screen.
			var screen := _box(pos+Vector3(0,3.38,0),Vector3(1.85,1.25,0.12),Color("#423d58"))
			_box(pos+Vector3(0,2.72,0.08),Vector3(2.15,0.12,0.18),Color("#876843"))
			_sphere(pos+Vector3(-0.48,3.55,0.12),0.28,Color("#f1d48f"))
			_box(pos+Vector3(0.5,3.28,0.14),Vector3(0.6,0.65,0.09),Color("#7e8a96"))
		9: # Bubble portraits: hoop frame, shiny bubbles and a standing photo card.
			var ring := _mesh(TorusMesh.new(),pos+Vector3(0,3.56,0),_mat(Color("#b3e7df")))
			ring.scale=Vector3(0.76,0.92,0.18)
			ring.rotation_degrees.x=90
			for j in range(4):
				var bubble := _sphere(pos+Vector3(-0.58+(j%2)*1.15,3.18+(j/2)*0.64,0.22),0.22,Color("#a6dce0"))
				bubble.material_override=_bubble_material()
				_box(pos+Vector3(-0.44+(j%2)*1.15,3.24+(j/2)*0.64,0.41),Vector3(0.08,0.06,0.035),CREAM)
		10: # Bench swap: paired paper seats with contrasting cushions.
			for side in [-1,1]:
				_box(pos+Vector3(side*0.58,3.0,0),Vector3(0.88,0.15,0.55),GOLD if side<0 else CORAL)
				_box(pos+Vector3(side*0.58,3.48,-0.2),Vector3(0.88,0.76,0.14),Color("#9b7d5c"))
				for leg in [-1,1]: _box(pos+Vector3(side*0.58+leg*0.31,2.76,0),Vector3(0.08,0.46,0.08),Color("#654f3c"))
		11: # Welcome ensemble: little drums, brass chimes and a conductor's baton.
			for j in range(3):
				_cylinder(pos+Vector3(-0.78+j*0.78,3.1,0),0.36,0.5,[CORAL,GOLD,TEAL][j],0.31)
				_box(pos+Vector3(-0.78+j*0.78,3.38,0),Vector3(0.62,0.06,0.62),CREAM)
				_box(pos+Vector3(-0.78+j*0.78,3.85,0),Vector3(0.07,0.78,0.07),Color("#d6bc86"))
			_label("♫",pos+Vector3(0,4.28,0),42,GOLD)

func _bubble_material() -> StandardMaterial3D:
	if bubble_material == null:
		bubble_material=StandardMaterial3D.new()
		bubble_material.albedo_color=Color(0.62,0.85,0.88,0.55)
		bubble_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		bubble_material.roughness=0.12
		bubble_material.metallic=0.18
	return bubble_material

func park_data() -> Dictionary:
	var path := "res://design/01-park/park.json"
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is not Dictionary or value.get("zones") is not Array:
		push_warning("Invalid park data at "+path+"; entrances unavailable")
		return {"zones":[]}
	var zones: Array=[]
	for zone in value.zones:
		if zone is Dictionary and zone.get("id") is String and zone.get("name") is String and zone.get("theme") is String and zone.get("threshold") is float:
			zones.append(zone)
		else: push_warning("Invalid park zone at "+path+"; entry ignored")
	return {"zones":zones}

func _build_gates() -> void:
	var data := park_data()
	var zones: Array = data.get("zones",[])
	for i in range(1,zones.size()):
		var zone: Dictionary=zones[i]
		var side := -1 if i%2==1 else 1
		var pos := Vector3(side*15.5,0,8-float((i-1)/2)*4.5)
		var zone_color: Color = [Color("#28737a"),Color("#e2795e"),Color("#e2ae4f"),Color("#725985"),Color("#47718a"),Color("#678858"),Color("#5295a0"),Color("#42638a"),Color("#865d71")][i-1]
		_box(pos+Vector3(0,0.18,0),Vector3(3.9,0.22,1.5),Color("#d0bc96"))
		for pillar_side in [-1,1]:
			_box(pos+Vector3(pillar_side*1.25,1.35,0),Vector3(0.42,2.7,0.5),CREAM,true)
			_box(pos+Vector3(pillar_side*1.25,0.55,0),Vector3(0.8,0.32,0.75),Color("#a98d68"))
			_box(pos+Vector3(pillar_side*1.25,2.48,0),Vector3(0.76,0.26,0.72),zone_color)
			_lantern(pos+Vector3(pillar_side*1.25,2.08,0.38))
		_box(pos+Vector3(0,2.8,0),Vector3(3.25,0.48,0.66),zone_color)
		_box(pos+Vector3(0,2.49,0),Vector3(2.65,0.12,0.8),Color("#f2d8a5"))
		_zone_crown(i,pos,zone_color)
		_label(zone["name"],pos+Vector3(0,2.76,0.37),20)
		_label(["⚓","✿","☼","✦","⚙","❀","⌬","◉","◇"][i-1],pos+Vector3(0,1.75,0.43),28,GOLD)
		_point("gate:"+zone["id"],zone["name"],pos+Vector3(0,0,2))
		_label("%d 張 · 準備中"%zone["threshold"],pos+Vector3(0,1.1,0.48),19)

func _zone_crown(index: int, pos: Vector3, color: Color) -> void:
	match index:
		1: # Lighthouse beacon, lantern room and cap.
			_cylinder(pos+Vector3(0,3.72,0),0.27,1.45,CREAM)
			_cylinder(pos+Vector3(0,4.52,0),0.4,0.2,GOLD)
			var beacon := _box(pos+Vector3(0,3.98,0),Vector3(0.42,0.45,0.42),Color("#f7d68f"))
			beacon.material_override=_mat(Color("#f7d68f"),true)
			var cap := _cone(pos+Vector3(0,4.68,0),color)
			cap.scale=Vector3(0.48,0.38,0.48)
		2: # Candy spool and wrapped sugar pinwheels.
			for side in [-1,1]:
				_cylinder(pos+Vector3(side*0.62,3.52,0),0.16,1.18,Color("#f1d6a8"))
				for row in range(3): _box(pos+Vector3(side*0.62,3.18+row*0.34,0.2),Vector3(0.34,0.12,0.09),CORAL if row%2==0 else CREAM)
			_cylinder(pos+Vector3(0,3.55,0),0.42,0.46,color)
			_cylinder(pos+Vector3(0,3.82,0),0.5,0.08,GOLD)
		3: # Night market pagoda roof and hanging lanterns.
			for row in range(2):
				var eave := _mesh(CylinderMesh.new(),pos+Vector3(0,3.42+row*0.38,0),_mat(color if row==0 else Color("#8d4f4c")))
				eave.scale=Vector3(1.32-row*0.19,0.14,0.55)
			for side in [-1,1]: _lantern(pos+Vector3(side*0.88,3.45,0.5))
		4: # Circus tent peak and striped paper canopy.
			var tent := _cone(pos+Vector3(0,3.75,0),color)
			tent.scale=Vector3(1.25,1.15,0.62)
			for side in [-1,1]:
				var stripe := _box(pos+Vector3(side*0.38,3.4,0.31),Vector3(0.14,0.72,0.06),CREAM)
				stripe.rotation.z=side*0.24
		5: # Toy city clock tower with two visible hands.
			_box(pos+Vector3(0,3.7,0),Vector3(0.6,1.1,0.55),Color("#98714e"))
			_cylinder(pos+Vector3(0,4.22,0.32),0.34,0.1,CREAM)
			_box(pos+Vector3(0,4.38,0.4),Vector3(0.035,0.24,0.035),Color("#514858"))
			_box(pos+Vector3(0.08,4.29,0.4),Vector3(0.18,0.035,0.035),Color("#514858"))
			var turret := _cone(pos+Vector3(0,4.43,0),color)
			turret.scale=Vector3(0.44,0.36,0.44)
		6: # Greenhouse flower crown, leaf blades and paper blossoms.
			for side in [-1,1]:
				var leaf := _box(pos+Vector3(side*0.52,3.54,0),Vector3(0.65,0.17,0.24),Color("#78945d"))
				leaf.rotation.z=side*0.4
				_sphere(pos+Vector3(side*0.72,3.86,0.12),0.18,CORAL if side<0 else GOLD)
			_sphere(pos+Vector3(0,3.72,0),0.25,CREAM)
		7: # Science flask with a thick glass neck and colored contents.
			_cylinder(pos+Vector3(0,3.55,0),0.43,0.1,Color("#6a9b9c"),0.24)
			_cylinder(pos+Vector3(0,3.88,0),0.27,0.62,Color("#89c7c8"),0.13)
			_box(pos+Vector3(0,4.25,0),Vector3(0.42,0.09,0.42),GOLD)
			_sphere(pos+Vector3(0,3.55,0.18),0.16,Color("#eb9c6c"))
		8: # Planet model with a tilted paper ring.
			_sphere(pos+Vector3(0,3.67,0),0.42,Color("#df9870"))
			var orbit := _mesh(TorusMesh.new(),pos+Vector3(0,3.67,0),_mat(CREAM))
			orbit.scale=Vector3(0.82,0.36,0.3)
			orbit.rotation.z=0.32
			for side in [-1,1]: _box(pos+Vector3(side*0.72,4.0,0),Vector3(0.11,0.11,0.11),GOLD)
		9: # The last gate is a freestanding mirror oval with a key-like crest.
			var portal := _mesh(TorusMesh.new(),pos+Vector3(0,3.83,0),_mat(Color("#b9d9d8")))
			portal.scale=Vector3(0.72,1.05,0.22)
			portal.rotation_degrees.x=90
			var mirror := _box(pos+Vector3(0,3.8,-0.06),Vector3(1.08,1.62,0.06),Color("#6c8790"))
			mirror.material_override=_mat(Color("#90b5b4"),true)
			_cylinder(pos+Vector3(0,4.91,0),0.16,0.4,GOLD)

func _fit_npc_rest_texture(texture: Texture2D) -> Texture2D:
	var source := texture.get_image() if texture != null else null
	if source == null or source.is_empty(): return texture
	var used := source.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0: return texture
	var body := source.get_region(used)
	var scale := minf(float(NpcActivityScript.ACTION_MAX_HEIGHT)/used.size.y, float(NpcActivityScript.ACTION_CANVAS_SIZE.x-4)/used.size.x)
	body.resize(maxi(1,roundi(used.size.x*scale)),maxi(1,roundi(used.size.y*scale)),Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(NpcActivityScript.ACTION_CANVAS_SIZE.x,NpcActivityScript.ACTION_CANVAS_SIZE.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(body,Rect2i(Vector2i.ZERO,body.get_size()),Vector2i((canvas.get_width()-body.get_width())/2,NpcActivityScript.ACTION_FEET_ROW-body.get_height()+1))
	return ImageTexture.create_from_image(canvas)

func _npc(pos: Vector3, color: Color, title: String) -> void:
	var activity_root := Node3D.new()
	activity_root.name = "%sActivityRoot" % title
	activity_root.position = pos
	add_child(activity_root)
	var ground_anchor := Node3D.new()
	ground_anchor.name = "BillboardGroundAnchor"
	activity_root.add_child(ground_anchor)
	var sprite := Sprite3D.new()
	var role := "ticket"
	if title == "小角": role = "imp"
	elif title == "阿浪": role = "announcer"
	var identity_region: Rect2i = IDENTITY_REGIONS[role]
	if identity_textures.has(role):
		sprite.texture=identity_textures[role]
		sprite.pixel_size=2.4 / float(identity_region.size.y)
	else:
		sprite.texture=_character_texture(role,color,"front",0)
		sprite.pixel_size=0.05
	# Reduced motion restores this rest texture. It must use the same canvas and
	# foot row as activity frames, rather than an incompatible cropped identity.
	var rest_frames := NpcActivityScript.load_action_frames(role)
	if rest_frames.size() == 4:
		sprite.texture = rest_frames[0]
	else:
		sprite.texture = _fit_npc_rest_texture(sprite.texture)
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size=2.4/float(NpcActivityScript.ACTION_VISIBLE_HEIGHT)
	var feet_offset := float(NpcActivityScript.ACTION_FEET_ROW)-float(NpcActivityScript.ACTION_CANVAS_SIZE.y)*0.5
	sprite.position=Vector3(0.0,sprite.pixel_size*feet_offset,0.0)
	sprite.shaded=true
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var profile := "character_ticket" if role=="ticket" else ("character_imp" if role=="imp" else "character_announcer")
	var breath_rate := 0.74 if role=="ticket" else (1.23 if role=="imp" else 0.53)
	var phase := 0.45 if role=="ticket" else (1.9 if role=="imp" else 3.2)
	var idle_role := 1 if role=="ticket" else (2 if role=="imp" else 3)
	_set_living_sprite_material(sprite,1,phase,breath_rate,idle_role)
	ground_anchor.add_child(sprite)
	var ground_y := _ground_surface_y(pos)
	_register_sprite_ground_anchor(sprite,ground_anchor,activity_root,ground_y,float(NpcActivityScript.ACTION_FEET_ROW),float(NpcActivityScript.ACTION_CANVAS_SIZE.y))
	_add_contact_shadow(activity_root,Vector3(0,ground_y-activity_root.global_position.y+0.005,0),Vector2(0.78,0.46))
	component_motion.register_component(sprite,profile,phase/TAU)
	character_sprites.append({"sprite":sprite,"activity_root":activity_root,"role":role,"color":color,"base_position":sprite.position,"idle_profile":"mascot" if role=="imp" else ("welcoming" if role=="ticket" else "announcer")})
	var name_label := _label(title,pos+Vector3(0,2.65,0),22)
	name_label.reparent(activity_root,true)

func _load_identity_atlas() -> void:
	if not ResourceLoader.exists(IDENTITY_ATLAS_PATH):
		_warn_identity_once("atlas","Character identity atlas %s is missing; using built-in NPC fallback art." % IDENTITY_ATLAS_PATH)
		return
	identity_atlas=load(IDENTITY_ATLAS_PATH) as Texture2D
	if identity_atlas == null:
		_warn_identity_once("atlas","Character identity atlas %s could not be loaded; using built-in NPC fallback art." % IDENTITY_ATLAS_PATH)
		return
	for role: String in IDENTITY_REGIONS:
		var region: Rect2i=IDENTITY_REGIONS[role]
		if region.position.x<0 or region.position.y<0 or region.size.x<=0 or region.size.y<=0 or region.end.x>identity_atlas.get_width() or region.end.y>identity_atlas.get_height():
			_warn_identity_once(role,"Character identity '%s' region exceeds %s bounds; using built-in fallback art." % [role,IDENTITY_ATLAS_PATH])
			continue
		var texture := AtlasTexture.new()
		texture.atlas=identity_atlas
		texture.region=Rect2(region)
		identity_textures[role]=texture
	if identity_textures.is_empty():
		identity_atlas=null
		_warn_identity_once("regions","Character identity atlas has no valid regions; using built-in NPC fallback art.")

func _warn_identity_once(key: String, message: String) -> void:
	if identity_warnings.has(key): return
	identity_warnings[key]=true
	push_warning(message)

func _pixel_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for py in range(y,maxi(0,y+height)):
		for px in range(x,maxi(0,x+width)):
			if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
				image.set_pixel(px,py,color)

func _pixel_triangle(image: Image, x: int, y: int, width: int, height: int, color: Color, point_up := true) -> void:
	for row in range(height):
		var progress := float(row) / maxi(1,height-1)
		var span := maxi(1,roundi(width*(1.0-progress))) if point_up else maxi(1,roundi(width*progress))
		var left := x + (width-span)/2
		_pixel_rect(image,left,y+row,span,1,color)

func _pixel_line(image: Image, start: Vector2i, finish: Vector2i, color: Color, thickness := 1) -> void:
	var x := start.x
	var y := start.y
	var dx := absi(finish.x-start.x)
	var sx := 1 if start.x < finish.x else -1
	var dy := -absi(finish.y-start.y)
	var sy := 1 if start.y < finish.y else -1
	var error := dx+dy
	while true:
		_pixel_rect(image,x-thickness/2,y-thickness/2,thickness,thickness,color)
		if x == finish.x and y == finish.y: break
		var doubled := 2*error
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy

func _character_texture(role: String, accent: Color, direction: String, frame: int) -> Texture2D:
	var key := "%s|%s|%s|%d" % [role,accent.to_html(true),direction,frame%4]
	if character_frames.has(key): return character_frames[key]
	const INK := Color("#243c50")
	const SKIN := Color("#efc69e")
	const CREAM_PAPER := Color("#f3e4bd")
	const BOOT := Color("#654b3e")
	var img := Image.create(32,48,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var step := frame % 4
	# Four planted-foot poses stay pixel-snapped; frame zero doubles as the idle pose.
	var left_lift: int = [0,1,2,1][step]
	var right_lift: int = [0,-1,-2,-1][step]
	var boot_left := Color("#473e47") if role == "imp" else BOOT
	var boot_right := Color("#473e47") if role == "imp" else BOOT
	_pixel_rect(img,9,34+left_lift,6,9-left_lift,boot_left)
	_pixel_rect(img,18,34+right_lift,6,9-right_lift,boot_right)
	_pixel_rect(img,8,42+left_lift,8,4,Color("#463a39"))
	_pixel_rect(img,18,42+right_lift,8,4,Color("#463a39"))
	if role == "hero":
		# Narrow cream rain shorts with two dark seams.
		_pixel_rect(img,9,34+left_lift,5,6,CREAM_PAPER)
		_pixel_rect(img,19,34+right_lift,5,6,CREAM_PAPER)
		_pixel_line(img,Vector2i(16,35),Vector2i(16,39),Color("#c4ac82"))
	elif role == "imp":
		_pixel_rect(img,10,34+left_lift,4,6,accent.darkened(0.2))
		_pixel_rect(img,19,34+right_lift,4,6,accent.darkened(0.2))
	else:
		_pixel_rect(img,10,34+left_lift,4,6,Color("#315363"))
		_pixel_rect(img,19,34+right_lift,4,6,Color("#315363"))
	# Body silhouette is role-led: raincoat, mascot, guide uniform or announcer's jacket.
	_pixel_rect(img,8,20,16,16,INK)
	_pixel_rect(img,9,21,14,14,accent)
	if role == "hero":
		var raincoat := Color("#267e83")
		_pixel_rect(img,9,21,14,13,raincoat)
		_pixel_rect(img,8,25,3,7,raincoat.darkened(0.16))
		_pixel_rect(img,21,25,3,7,raincoat.darkened(0.16))
		_pixel_rect(img,8,30,4,3,Color("#df765d"))
		_pixel_rect(img,20,31,4,2,CREAM_PAPER)
		_pixel_rect(img,10,21,12,3,Color("#d7ece0"))
		# The ticket lanyard and paper boarding stub are only on the front.
		if direction != "back":
			_pixel_line(img,Vector2i(10,22),Vector2i(20,32),Color("#d9cfaa"),2)
			_pixel_rect(img,18,29,5,5,Color("#f5edcf"))
			_pixel_rect(img,19,30,3,1,Color("#d8ae68"))
			_pixel_rect(img,19,32,2,1,Color("#78a5a0"))
			# Brick-red box camera, worn brass side and pale blue lens.
			_pixel_rect(img,21,32,6,4,Color("#994f45"))
			_pixel_rect(img,22,31,4,2,Color("#bc7157"))
			_pixel_rect(img,26,33,2,2,Color("#e4c57d"))
			_pixel_rect(img,23,33,2,2,Color("#3e747b"))
		_pixel_rect(img,15,22,2,11,Color("#f1f0d8"))
		_pixel_rect(img,13,20,6,2,Color("#e4c27c"))
	elif role == "imp":
		# Soft mascot body, oversized trailing scarf and folded arrow-point tail.
		_pixel_triangle(img,9,22,14,13,accent)
		_pixel_rect(img,9,31,14,3,accent.darkened(0.13))
		_pixel_rect(img,8,23,4,2,accent.lightened(0.16))
		_pixel_rect(img,20,23,4,2,accent.lightened(0.16))
		_pixel_rect(img,10,21,12,4,Color("#2c8b8c"))
		_pixel_rect(img,17,23,5,10,Color("#2c8b8c"))
		_pixel_triangle(img,17,31,6,5,Color("#47a6a2"),false)
		# Tail points back from its turn; direction changes which edge it exits.
		if direction == "left":
			_pixel_line(img,Vector2i(10,29),Vector2i(4,32),Color("#b95051"),3)
			_pixel_triangle(img,2,30,5,5,Color("#b95051"))
			_pixel_rect(img,2,29,3,1,CREAM_PAPER)
		else:
			_pixel_line(img,Vector2i(22,29),Vector2i(28,32),Color("#b95051"),3)
			_pixel_triangle(img,26,30,5,5,Color("#b95051"),false)
			_pixel_rect(img,28,29,3,1,CREAM_PAPER)
	elif role == "ticket":
		_pixel_rect(img,9,21,14,13,Color("#34727a"))
		_pixel_rect(img,9,23,14,3,Color("#e1bd6a"))
		_pixel_rect(img,13,20,6,3,CREAM_PAPER)
		_pixel_rect(img,10,30,5,2,Color("#8f604e"))
		# Tiny brass ticket punch at the guide's hip.
		_pixel_rect(img,22,28,4,5,Color("#c88f4a"))
		_pixel_rect(img,23,29,2,1,Color("#f2dfa8"))
	elif role == "announcer":
		_pixel_rect(img,9,21,14,13,Color("#34566b"))
		_pixel_rect(img,9,22,14,3,Color("#d5ba7b"))
		_pixel_rect(img,15,25,2,9,Color("#283f52"))
		# Handheld loudhailer, held away from his face.
		_pixel_rect(img,22,27,4,3,Color("#d0a452"))
		_pixel_triangle(img,25,26,5,5,Color("#ebd8a8"),false)
	# Face, profile, hair and uniform headwear are drawn independently so the
	# imp never inherits a human silhouette and rear views never show facial gear.
	if role == "imp":
		# Irregular coral head with asymmetrical ears, a chipped short horn and a bent horn.
		_pixel_rect(img,10,9,12,12,Color("#da705c"))
		_pixel_rect(img,8,11,16,8,Color("#da705c"))
		_pixel_triangle(img,3,8,9,8,Color("#c85f58"),false)
		_pixel_triangle(img,21,8,8,9,Color("#e18168"))
		_pixel_triangle(img,10,4,5,6,CREAM_PAPER)
		_pixel_rect(img,10,3,3,2,Color("#d7c69c"))	# chipped horn tip
		_pixel_line(img,Vector2i(19,10),Vector2i(22,5),CREAM_PAPER,3)
		_pixel_line(img,Vector2i(22,5),Vector2i(23,2),CREAM_PAPER,2)
		if direction != "back":
			if direction == "left":
				_pixel_line(img,Vector2i(12,12),Vector2i(15,11),INK,1)
				_pixel_rect(img,12,14,2,2,Color("#ffd884"))
				_pixel_line(img,Vector2i(12,18),Vector2i(17,16),Color("#773f4c"),2)
			elif direction == "right":
				_pixel_line(img,Vector2i(17,11),Vector2i(20,12),INK,1)
				_pixel_rect(img,18,14,2,2,Color("#ffd884"))
				_pixel_line(img,Vector2i(15,16),Vector2i(20,18),Color("#773f4c"),2)
			else:
				_pixel_line(img,Vector2i(11,12),Vector2i(15,11),INK,1)
				_pixel_line(img,Vector2i(18,11),Vector2i(22,12),INK,1)
				_pixel_rect(img,12,14,2,2,Color("#ffd884"))
				_pixel_rect(img,19,14,2,2,Color("#ffd884"))
				_pixel_line(img,Vector2i(15,17),Vector2i(20,18),Color("#773f4c"),2)
				_pixel_rect(img,13,16,1,1,CREAM_PAPER)	# one tooth in the crooked grin
	else:
		if direction == "back":
			# Hair/cap back only; no skin, eyes, ticket or camera face markings.
			_pixel_rect(img,9,6,14,13,INK)
			_pixel_rect(img,7,10,3,6,INK)
			_pixel_rect(img,22,10,3,6,INK)
			if role == "hero":
				_pixel_rect(img,10,8,12,2,Color("#314d62"))
				_pixel_rect(img,9,21,14,12,Color("#24747b"))
				_pixel_line(img,Vector2i(16,23),Vector2i(16,31),Color("#76a8a0"))
			elif role == "ticket":
				_pixel_rect(img,8,7,16,5,Color("#e3bb65"))
				_pixel_rect(img,10,11,12,5,Color("#286776"))
			elif role == "announcer":
				_pixel_rect(img,7,5,18,5,Color("#273f58"))
				_pixel_rect(img,8,9,16,3,Color("#d2ad64"))
				_pixel_rect(img,7,11,4,5,Color("#263e52"))
				_pixel_rect(img,21,11,4,5,Color("#263e52"))
		else:
			_pixel_rect(img,8,7,16,12,INK)
			_pixel_rect(img,10,9,12,9,SKIN)
			if direction == "left":
				_pixel_rect(img,10,11,4,5,SKIN)
				_pixel_rect(img,12,12,2,2,INK)
			else:
				_pixel_rect(img,18,11,4,5,SKIN)
				_pixel_rect(img,18,12,2,2,INK)
			if role == "hero":
				# Short wind-tossed ink-blue hair and one cream forelock.
				_pixel_rect(img,8,6,15,4,Color("#243e55"))
				_pixel_rect(img,7,8,5,4,Color("#243e55"))
				_pixel_rect(img,11,5,5,3,Color("#243e55"))
				_pixel_triangle(img,18,4,5,5,Color("#243e55"),false)
				_pixel_rect(img,14,5,2,3,CREAM_PAPER)
			elif role == "ticket":
				_pixel_rect(img,7,7,18,3,Color("#d8b257"))
				_pixel_rect(img,9,4,14,4,Color("#2e6572"))
				_pixel_rect(img,12,4,8,1,CREAM_PAPER)
			elif role == "announcer":
				_pixel_rect(img,7,6,18,3,Color("#273e55"))
				_pixel_rect(img,9,3,14,4,Color("#263f56"))
				_pixel_rect(img,11,4,10,1,Color("#d6b363"))
				# Ear cups and the thin headset band.
				_pixel_rect(img,6,11,3,6,Color("#263e52"))
				_pixel_rect(img,23,11,3,6,Color("#263e52"))
				_pixel_line(img,Vector2i(24,16),Vector2i(26,18),Color("#e1bd76"))
			# Character-specific expressions.
			if role == "hero":
				_pixel_line(img,Vector2i(11,11),Vector2i(14,10),INK,1)
				_pixel_rect(img,12,13,2,2,INK)
				_pixel_rect(img,19,13,2,2,INK)
				_pixel_line(img,Vector2i(15,17),Vector2i(18,16),Color("#a85d58"))
			elif role == "ticket":
				_pixel_line(img,Vector2i(11,11),Vector2i(14,12),INK)
				_pixel_rect(img,12,14,2,2,INK)
				_pixel_rect(img,19,14,2,2,INK)
				_pixel_rect(img,15,17,3,1,Color("#aa5c53"))
			else:
				# Narrow eyes with worried, asymmetrical brows.
				_pixel_line(img,Vector2i(11,10),Vector2i(14,12),INK)
				_pixel_line(img,Vector2i(18,12),Vector2i(21,10),INK)
				_pixel_rect(img,12,14,3,1,INK)
				_pixel_rect(img,19,14,3,1,INK)
				_pixel_rect(img,15,17,3,2,Color("#984d4f"))
			if role == "hero":
				# Front-strap only: no pale face/camera marks leak onto the raincoat back.
				if direction != "back":
					_pixel_line(img,Vector2i(10,22),Vector2i(20,33),Color("#dfd7bd"),2)
					_pixel_rect(img,18,30,4,4,Color("#f4ecd2"))
					_pixel_rect(img,19,31,2,1,Color("#d3ae68"))
					_pixel_rect(img,21,33,6,3,Color("#934a43"))
					_pixel_rect(img,22,32,4,2,Color("#bb6c55"))
					_pixel_rect(img,23,34,2,1,Color("#91bcc0"))
					_pixel_rect(img,8,30,3,3,Color("#df765d"))
			elif role == "ticket":
				# A neat little waist badge and puncher catch the light.
				_pixel_rect(img,21,29,4,4,Color("#d9b463"))
				_pixel_rect(img,22,30,2,1,Color("#fff0c8"))
			elif role == "announcer":
				_pixel_rect(img,21,28,6,3,Color("#d0a452"))
				_pixel_triangle(img,25,27,5,5,Color("#ebd8a8"),false)
	var texture := ImageTexture.create_from_image(img)
	character_frames[key]=texture
	return texture

func _build_player() -> void:
	avatar_renderer=AvatarRenderer.new()
	player=CharacterBody3D.new()
	player.position=Vector3(0,0.3,23.2)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.3
	capsule.height=1.5
	collision.shape=capsule
	collision.position.y=0.85
	player.add_child(collision)
	avatar=Sprite3D.new()
	avatar.pixel_size=2.4 / float(avatar_renderer.pose_height())
	avatar.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	avatar.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	avatar.position.y=1.15
	avatar.shaded=true
	avatar.position.y=1.2
	avatar.texture=avatar_renderer.texture(avatar_appearance,avatar_equipped,"front",0,"idle")
	_set_living_sprite_material(avatar,1,0.18,0.72)
	avatar_ground_anchor=Node3D.new()
	avatar_ground_anchor.name="BillboardGroundAnchor"
	player.add_child(avatar_ground_anchor)
	avatar_ground_anchor.add_child(avatar)
	avatar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	avatar_contact_shadow=_add_contact_shadow(player,Vector3(0,0,0),Vector2(0.92,0.58))
	_register_sprite_ground_anchor(avatar,avatar_ground_anchor,player,_ground_surface_y(player.position),float(AvatarRenderer.FEET_BASELINE),float(AvatarRenderer.CANVAS_SIZE.y))
	component_motion.register_component(avatar,"character_hero",0.18/TAU)
	add_child(player)
	# Ground collision covers walkable land and dock. Sea never traps the player.
	for geometry in [Vector3(40,0.2,66),Vector3(5,0.2,13)]:
		var floor_body := StaticBody3D.new()
		floor_body.position=Vector3(0,0.1,-14) if geometry.x>6 else Vector3(0,0.12,21)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=geometry
		shape.shape=box
		floor_body.add_child(shape)
		add_child(floor_body)

func _build_camera() -> void:
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=21.0
	camera.far=200
	camera.position=player.position+Vector3(0,15.5,25)
	add_child(camera)
	camera.look_at(player.position+Vector3(0,1,-3))
	camera.current=true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	var movement := Vector2.ZERO if blocked else Input.get_vector("move_left","move_right","move_up","move_down")
	player.velocity=Vector3(movement.x*5.0,-4,movement.y*5.0)
	var previous_position := player.position
	player.move_and_slide()
	player.position.z=clampf(player.position.z,-43.6,26.5)
	player.position.x=clampf(player.position.x,-18.6,18.6)
	# Terrain edge: prevent stepping from the land directly into water.
	if player.position.z>18.0 and absf(player.position.x)>2.05:
		if previous_position.z>18.0:
			player.position.x=clampf(player.position.x,-2.05,2.05)
		else:
			player.position.z=18.0
	if player.position.z>18.6:
		player.position.x=clampf(player.position.x,-2.05,2.05)
	if player.position.y < -1.0:
		player.position=Vector3(0,0.3,10)
		previous_position=player.position
	var actual_delta := player.position - previous_position
	var horizontal_delta := Vector2(actual_delta.x, actual_delta.z)
	var travelled := horizontal_delta.length()
	avatar_is_walking = travelled > WALK_DISTANCE_EPSILON
	if avatar_is_walking:
		facing = quantize_walk_direction(horizontal_delta, facing)
		walk_distance_phase = advance_walk_phase(walk_distance_phase, travelled)
	var walk_frame_count := int(avatar_renderer.walk_frame_count(facing)) if avatar_renderer != null else 8
	var frame := walk_frame_for_phase(walk_distance_phase, walk_frame_count)
	if avatar_action_remaining > 0.0:
		avatar_action_remaining=maxf(0.0,avatar_action_remaining-delta)
		if avatar_action_remaining == 0.0: avatar_action=""
	_refresh_avatar_texture(frame)
	camera.position=camera.position.lerp(player.position+Vector3(0,15.5,25),minf(1,delta*7))
	_update_sprite_grounding()
	var area := "海風碼頭" if player.position.z>12 else ("迎賓大道" if player.position.z < -11 else "中央廣場")
	if area!=current_area:
		current_area=area
		area_changed.emit(area)
	nearest={}
	var best := 2.4
	for point in points:
		var dist := player.position.distance_to(point.position)
		if dist<best:
			best=dist
			nearest=point

func _process(delta: float) -> void:
	time+=delta
	if is_instance_valid(npc_activity) and npc_activity_paused!=blocked:
		npc_activity_paused=blocked
		npc_activity.set_activity_paused(blocked)

static func quantize_walk_direction(world_delta: Vector2, previous_direction: String = "front") -> String:
	const COMPASS := ["back", "back_right", "right", "front_right", "front", "front_left", "left", "back_left"]
	if world_delta.length_squared() < 0.000001: return previous_direction if COMPASS.has(previous_direction) else "front"
	var angle := fposmod(atan2(world_delta.x, -world_delta.y), TAU)
	var sector_width := TAU / float(COMPASS.size())
	var nearest := posmod(roundi(angle / sector_width), COMPASS.size())
	var previous := COMPASS.find(previous_direction)
	if previous >= 0:
		var previous_angle := float(previous) * sector_width
		var difference := absf(wrapf(angle - previous_angle, -PI, PI))
		if difference < sector_width * 0.5 + WALK_DIRECTION_HYSTERESIS:
			return previous_direction
	return COMPASS[nearest]

static func advance_walk_phase(phase: float, travelled: float) -> float:
	return fposmod(phase + maxf(0.0, travelled), WALK_STRIDE_DISTANCE)

static func walk_frame_for_phase(phase: float, frame_count: int = 8) -> int:
	var normalized_phase := fposmod(phase, WALK_STRIDE_DISTANCE) / WALK_STRIDE_DISTANCE
	var safe_frame_count := frame_count if frame_count in [8, 16] else 8
	return clampi(floori(normalized_phase * float(safe_frame_count)), 0, safe_frame_count - 1)

func interact() -> void:
	if not blocked and not nearest.is_empty():
		play_action("interact")
		interaction_requested.emit(nearest.id,nearest.label)

func _unhandled_key_input(event: InputEvent) -> void:
	if blocked or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F:
		play_action("wave")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_P:
		play_action("photograph")
		get_viewport().set_input_as_handled()

func play_action(name: String) -> void:
	var action := "photograph" if name == "photo" else name
	if action not in ["wave", "photograph", "interact", "celebrate"]: return
	avatar_action=action
	avatar_action_remaining=0.8
	_refresh_avatar_texture(0)

func set_avatar_look(appearance: Dictionary, equipped: Dictionary) -> void:
	if avatar_appearance == appearance and avatar_equipped == equipped: return
	avatar_appearance=appearance.duplicate(true)
	avatar_equipped=equipped.duplicate(true)
	last_avatar_frame=-1
	_refresh_avatar_texture(0)

func _refresh_avatar_texture(frame: int) -> void:
	if not is_instance_valid(avatar) or avatar_renderer == null: return
	var action := avatar_action if avatar_action_remaining > 0.0 else ("walk" if avatar_is_walking else "idle")
	if last_avatar_direction == facing and last_avatar_frame == frame and last_avatar_action == action: return
	avatar.texture=avatar_renderer.texture(avatar_appearance,avatar_equipped,facing,frame,action)
	var avatar_material := avatar.material_override as ShaderMaterial
	if avatar_material != null:
		avatar_material.set_shader_parameter("texture_albedo",avatar.texture)
	last_avatar_direction=facing
	last_avatar_frame=frame
	last_avatar_action=action

func set_night(value: bool) -> void:
	set_time_of_day("night" if value else "noon")

func set_time_of_day(phase_id: Variant) -> void:
	active_time_phase = TimeOfDayScript.normalize(phase_id)
	var profile: Dictionary = TimeOfDayScript.phase_for_id(active_time_phase)
	night = active_time_phase == "night"
	sun.rotation_degrees = profile.key_rotation_degrees
	sun.light_color = profile.key_color
	sun.light_energy = float(profile.key_energy)
	environment.background_color = profile.sky_color
	environment.ambient_light_color = profile.ambient_color
	environment.ambient_light_energy = float(profile.ambient_energy)
	environment.fog_light_color = profile.sky_color.lerp(profile.ambient_color, 0.28)
	match active_time_phase:
		"dawn": environment.glow_intensity = 0.09
		"noon": environment.glow_intensity = 0.07
		"dusk": environment.glow_intensity = 0.12
		"night": environment.glow_intensity = 0.18
	var lamp_energy: float = float({"dawn": 0.18, "noon": 0.0, "dusk": 0.48, "night": 0.82}[active_time_phase])
	var active_limit := mini(8, lamps.size())
	var stride := maxi(1, ceili(float(lamps.size()) / float(maxi(1, active_limit))))
	var active_count := 0
	for index in range(lamps.size()):
		var lamp := lamps[index]
		var enabled: bool = lamp_energy > 0.0 and index % stride == 0 and active_count < active_limit
		var energy: float = lamp_energy if enabled else 0.0
		lamp.light_energy = energy
		lamp.shadow_enabled = false
		if enabled: active_count += 1
		if is_instance_valid(component_motion): component_motion.set_light_baseline(lamp,energy)
	var sun_direction := -sun.global_basis.z
	var projected := Vector3(sun_direction.x,0.0,sun_direction.z)
	var shadow_offset := Vector3.ZERO
	if projected.length_squared() > 0.0001:
		shadow_offset = -projected.normalized() * 0.12
	for record in contact_shadows:
		var shadow := record.get("node") as Node3D
		if not is_instance_valid(shadow): continue
		var ground_offset: Vector3 = record.get("ground_offset",Vector3.ZERO)
		shadow.position = ground_offset + shadow_offset

func apply_settings(settings: Dictionary) -> void:
	reduced_motion=bool(settings.get("reduced_motion",false))
	sea_material.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)
	fountain_water.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)
	if is_instance_valid(component_motion): component_motion.set_reduced_motion(reduced_motion)
	if is_instance_valid(npc_activity): npc_activity.set_reduced_motion(reduced_motion)
	if is_instance_valid(occlusion_controller): occlusion_controller.set_reduced_motion(reduced_motion)

func update_collection(photos: Dictionary) -> void:
	for point in points:
		var source := ""
		if point.id.begins_with("game-"):
			source="photo-welcome-game-%d"%int(point.id.trim_prefix("game-"))
		elif point.id.begins_with("explore-"):
			source="photo-welcome-explore-%d"%int(point.id.trim_prefix("explore-"))
		elif point.id.begins_with("quest-"):
			source="photo-welcome-quest-%d"%int(point.id.trim_prefix("quest-"))
		elif point.id=="guide": source="photo-welcome-story-1"
		var marker: Label3D=point.marker
		marker.text="✓" if not source.is_empty() and photos.has(source) else "◇"
		marker.modulate=Color("#83d3ae") if marker.text=="✓" else GOLD
