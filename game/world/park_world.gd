extends Node3D
## Original modular island scenery. All interactions remain data driven.
signal interaction_requested(id: String, label: String)
signal area_changed(label: String)
const WATER = preload("res://game/world/water.gdshader")
const STONE = preload("res://game/world/stone.gdshader")
const CREAM = Color("#edddb8")
const TEAL = Color("#246c6c")
const CORAL = Color("#da705c")
const GOLD = Color("#edbb65")
var player: CharacterBody3D
var avatar: Sprite3D
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var points: Array[Dictionary] = []
var animated: Array[Dictionary] = []
var lamps: Array[OmniLight3D] = []
var sprite_frames: Array[Texture2D] = []
var blocked := false
var reduced_motion := false
var night := false
var time := 0.0
var current_area := ""
var nearest: Dictionary = {}
var fountain_water: ShaderMaterial
var sea_material: ShaderMaterial

func _ready() -> void:
	_build_lighting()
	_build_land()
	_build_dock()
	_build_plaza()
	_build_avenue()
	_build_gates()
	_build_player()
	_build_camera()
	set_night(false)

func _build_lighting() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#89bcc8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a9d5da")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.fog_enabled = true
	environment.fog_density = 0.0015
	environment.fog_light_color = Color("#a0c8cc")
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_color = Color("#ffe4b1")
	sun.light_energy = 1.4
	add_child(sun)

func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.1
	return material

func _mesh(mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	return instance

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
	label.outline_size = 6
	label.outline_modulate = Color("#223f47")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	return label

func _point(id: String, title: String, pos: Vector3) -> void:
	points.append({"id":id,"label":title,"position":pos})
	var marker := _label("◇", pos + Vector3(0,2.1,0), 38, GOLD)
	points[-1]["marker"]=marker
	animated.append({"node":marker,"base":marker.position,"phase":points.size()*0.7,"kind":"float"})

func _build_land() -> void:
	sea_material = ShaderMaterial.new()
	sea_material.shader = WATER
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(240,240)
	_mesh(sea_mesh,Vector3(0,-0.42,0),sea_material)
	_box(Vector3(0,-0.75,-14),Vector3(41,1.4,67),Color("#b0a47c"))
	_box(Vector3(0,-0.03,-14),Vector3(40,0.16,66),Color("#91a16b"))
	# Paths lead without dead ends from dock to welcome's four clusters.
	var stone_material := ShaderMaterial.new()
	stone_material.shader = STONE
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(9,0.12,64)
	_mesh(path_mesh,Vector3(0,0.12,-15),stone_material)
	var square_mesh := BoxMesh.new()
	square_mesh.size = Vector3(31,0.12,20)
	_mesh(square_mesh,Vector3(0,0.12,0),stone_material)
	for side in [-1,1]:
		for i in range(14):
			var z := -44.0 + i*4.5
			_tree(Vector3(side*(15.7+sin(i*1.2)*1.7),0,z),i)
			_box(Vector3(side*19.5,0.22,z),Vector3(0.3,0.5,3.8),Color("#d2bc8e"))
		for i in range(8):
			_flowerbed(Vector3(side*5.6,0,-14-i*4.0),i)
	for i in range(26):
		var a := float(i)/26.0*TAU
		_box(Vector3(cos(a)*7.7,0.22,sin(a)*7.7),Vector3(0.55,0.22,0.55),CREAM)

func _tree(pos: Vector3, seed_value: int) -> void:
	_cylinder(pos+Vector3(0,1.1,0),0.23,2.2,Color("#856742"))
	_sphere(pos+Vector3(0,2.6,0),1.2,Color("#416b55"))
	_sphere(pos+Vector3(-0.55,2.7,0.25),0.85,Color("#56855d"))
	_sphere(pos+Vector3(0.4,3.25,0),0.8,Color("#699160"))
	if seed_value % 3 == 0:
		_lantern(pos+Vector3(0.4,2,0.7))

func _flowerbed(pos: Vector3, seed_value: int) -> void:
	_box(pos+Vector3(0,0.3,0),Vector3(1.7,0.5,1.3),Color("#ccba92"),true)
	_box(pos+Vector3(0,0.58,0),Vector3(1.5,0.12,1.1),Color("#425c42"))
	for j in range(5):
		var offset := Vector3(sin(j*2.4)*0.55,0.8,cos(j*3.1)*0.37)
		var flower := _sphere(pos+offset,0.19,CORAL if (j+seed_value)%2==0 else GOLD)
		animated.append({"node":flower,"base":flower.position,"phase":j+seed_value,"kind":"flower"})

func _lantern(pos: Vector3) -> void:
	_cylinder(pos,0.22,0.48,GOLD)
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color("#ffc276")
	light.omni_range = 5
	light.light_energy = 0.0
	add_child(light)
	lamps.append(light)

func _arch(pos: Vector3, title: String, color: Color, wide := 5.0) -> void:
	for side in [-1,1]:
		_box(pos+Vector3(side*wide*0.5,1.65,0),Vector3(0.5,3.3,0.6),CREAM,true)
		_lantern(pos+Vector3(side*(wide*0.5-0.4),2.3,0))
	_box(pos+Vector3(0,3.4,0),Vector3(wide+0.8,0.7,0.7),color)
	_label(title,pos+Vector3(0,3.5,0.43),30)
	for i in range(7):
		var flag := _box(pos+Vector3(-wide*0.45+i*wide*0.15,2.85,0),Vector3(0.4,0.35,0.04),CORAL if i%2==0 else GOLD)
		animated.append({"node":flag,"base":flag.position,"phase":i*0.6,"kind":"flag"})

func _build_dock() -> void:
	_box(Vector3(0,0.0,21),Vector3(5,0.3,13),Color("#a17b52"))
	for i in range(27):
		_box(Vector3(0,0.18,15+i*0.45),Vector3(5,0.08,0.06),Color("#6e5c42"))
	for side in [-1,1]:
		for i in range(5):
			var z := 16.0+i*2.7
			_cylinder(Vector3(side*2.5,0.6,z),0.12,1.4,Color("#665d45"))
			if i<4:
				_box(Vector3(side*2.5,1.1,z+1.35),Vector3(0.09,0.12,2.7),CREAM)
	_arch(Vector3(0,0,13.8),"SNAPLAND",TEAL,5.5)
	# Original ferry silhouette, with portholes, lifebuoy, chimney and pennants.
	_box(Vector3(5.5,0,25),Vector3(5,0.8,8),Color("#e4d7b6"),true)
	_box(Vector3(5.5,0.7,25),Vector3(4,0.6,6.5),TEAL)
	_box(Vector3(5.5,1.8,25.4),Vector3(3,1.6,4),CREAM)
	_box(Vector3(5.5,2.7,25.4),Vector3(3.7,0.3,4.6),CORAL)
	_cylinder(Vector3(5.5,3.35,25.5),0.45,1.2,TEAL)
	for i in range(3):
		_sphere(Vector3(3.95,1.85,24+i*1.2),0.3,Color("#335b6e"))
	_label("晚風號",Vector3(5.5,1.2,28.5),24)
	_point("arrival","重播上島導覽",Vector3(0,0,24))
	_label("碼頭  /  海風從這裡開始",Vector3(-4,1,19),24)

func _build_plaza() -> void:
	# Tiered fountain anchors the main area's visual silhouette.
	_cylinder(Vector3(0,0.45,0),2.8,0.6,CREAM)
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
	for i in range(12):
		var a := i*TAU/12.0
		var bead := _sphere(Vector3(cos(a)*1.2,1.8,sin(a)*1.2),0.08,Color("#b3e4df"))
		animated.append({"node":bead,"base":bead.position,"phase":i*0.5,"kind":"water"})
	var collision := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius=2.8
	cylinder.height=1.5
	shape.shape=cylinder
	collision.add_child(shape)
	add_child(collision)
	_kiosk(Vector3(-6,0,5),"導覽亭",TEAL)
	_npc(Vector3(-5,0,7),CORAL,"票票")
	_point("guide","與票票合照",Vector3(-5,0,7))
	_kiosk(Vector3(6,0,5),"拍貼本",CORAL)
	_point("album","翻閱拍貼收藏",Vector3(6,0,7))
	_kiosk(Vector3(-7,0,-5),"借用道具",GOLD)
	_point("settings","設定與輔助",Vector3(-7,0,-3))
	_cylinder(Vector3(7,1.1,-5),0.45,2.2,TEAL)
	_sphere(Vector3(7,2.4,-5),0.7,CREAM)
	_label("日夜鐘",Vector3(7,3.5,-5),26)
	_point("clock","切換日夜",Vector3(7,0,-3))
	_arch(Vector3(0,0,-11),"迎賓大道",CORAL,8)
	_label("中央廣場",Vector3(0,4.7,1),36)

func _kiosk(pos: Vector3, title: String, color: Color) -> void:
	_box(pos+Vector3(0,0.7,0),Vector3(3.8,1.3,2.5),CREAM,true)
	_box(pos+Vector3(0,1.7,0),Vector3(4.2,0.3,3),color)
	for side in [-1,1]:
		_box(pos+Vector3(side*1.65,1.85,0),Vector3(0.18,1.4,0.18),TEAL)
	var roof := _box(pos+Vector3(0,2.7,0),Vector3(4.5,0.35,3.3),color)
	roof.rotation.z=0.02
	for i in range(9):
		_box(pos+Vector3(-1.8+i*0.45,2.48,1.6),Vector3(0.45,0.5,0.13),CREAM if i%2==0 else color)
	_label(title,pos+Vector3(0,2.05,1.65),24)

func _build_avenue() -> void:
	var names := ["氣球快遞","風箏穿環","噴泉跳拍","人潮指揮","帽子救援","彩帶節拍","花壇拼圖","招牌平衡","影子捉迷藏","泡泡合照","長椅換位","迎賓大合奏"]
	for i in range(12):
		var side := -1 if i%2==0 else 1
		var pos := Vector3(side*8.3,0,-17-float(i/2)*4.8)
		var color := [CORAL,TEAL,GOLD][i%3] as Color
		_kiosk(pos,names[i],color)
		_point("game-%03d"%(i+1),names[i],pos+Vector3(-side*2.3,0,1))
		_cylinder(pos+Vector3(-side*2.3,0.28,1),0.75,0.16,color)
		# Every station has a distinct miniature sign, following its actual mechanic.
		match i:
			0,1:
				for j in range(3):
					var balloon := _sphere(pos+Vector3(-0.8+j*0.8,3.8+j*0.2,0),0.38,[CORAL,GOLD,Color("#77c7ce")][j])
					animated.append({"node":balloon,"base":balloon.position,"phase":j,"kind":"float"})
			2:
				_cylinder(pos+Vector3(0,3,0),0.9,0.3,Color("#6ac2d0"))
			3:
				for j in range(3):
					_sphere(pos+Vector3(j*0.5-0.5,3.4,0),0.2,[CORAL,GOLD,TEAL][j])
			4:
				_cylinder(pos+Vector3(0,3.1,0),0.8,0.12,GOLD)
				_cylinder(pos+Vector3(0,3.35,0),0.45,0.4,GOLD)
			5:
				_box(pos+Vector3(0,3.25,0),Vector3(2,0.3,0.3),CORAL)
			6:
				_sphere(pos+Vector3(0,3.2,0),0.6,CORAL)
			7:
				_box(pos+Vector3(0,3.3,0),Vector3(2,0.8,0.2),TEAL).rotation.z=0.15
			8:
				_sphere(pos+Vector3(0,3.3,0),0.4,Color("#473c66"))
			9:
				_sphere(pos+Vector3(0,3.2,0),0.75,Color("#99d3da"))
			10:
				_box(pos+Vector3(0,3.1,0),Vector3(2,0.3,0.6),GOLD)
			11:
				_label("♫",pos+Vector3(0,3.6,0),55,GOLD)
	_npc(Vector3(-3,0,-15),CORAL,"小角")
	_point("quest-001","吉祥物的尾巴危機",Vector3(-3,0,-15))
	_npc(Vector3(3,0,-15),TEAL,"阿浪")
	_point("quest-002","廣播即興救場",Vector3(3,0,-15))
	_point("explore-001","花壇會眨眼",Vector3(-3,0,-25))
	_point("explore-002","歡迎字樣的影子",Vector3(3,0,-31))
	_box(Vector3(-3,0.7,-37),Vector3(2,0.3,0.7),GOLD,true)
	_point("explore-003","長椅雙人份",Vector3(-3,0,-35.7))
	_arch(Vector3(0,0,-45),"倒影大道",Color("#655178"),5)
	_point("rift","查看倒影大道",Vector3(0,0,-43))

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
		_box(pos+Vector3(0,1,0),Vector3(2.8,2,0.4),TEAL if side==1 else CORAL)
		_label(zone["name"],pos+Vector3(0,2.3,0),24)
		_box(pos+Vector3(0,0.55,1),Vector3(2.8,0.2,0.2),GOLD)
		_point("gate:"+zone["id"],zone["name"],pos+Vector3(0,0,2))
		_label("%d 張 · 準備中"%zone["threshold"],pos+Vector3(0,1.1,0.3),20)

func _npc(pos: Vector3, color: Color, title: String) -> void:
	var sprite := Sprite3D.new()
	sprite.texture=_pixel_character(color,0,false)
	sprite.pixel_size=0.10
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position=pos+Vector3(0,1.2,0)
	sprite.shaded=true
	add_child(sprite)
	_label(title,pos+Vector3(0,2.65,0),22)

func _pixel_character(color: Color, frame: int, back: bool) -> Texture2D:
	var pattern := [
		"      hhhh      ","    hhhhhhhh    ","   hhhhhhhhhh   ","   hhhhhhhhhh   ",
		"   hsssss shh   ","   ssessessss   ","    ssssssss    ","     ssmmss     ",
		"      ssss      ","    cccccccc    ","   cccccccccc   ","  sccccccccccs  ",
		"  sccwccccwccs  ","  sccccccccccs  ","   cccccccccc   ","    cccccccc    ",
		"    bbbbbbbb    ","    bbb  bbb    ","    bbb  bbb    ","    bbb  bbb    ",
		"   dddd  dddd   ","   dddd  dddd   ","                ","                "]
	var image := Image.create(16,24,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette := {"h":Color("#423b40"),"s":Color("#f1c7a0"),"e":Color("#263f42"),"m":Color("#ba806b"),"c":color,"w":CREAM,"b":Color("#385164"),"d":Color("#273f47")}
	for y in range(24):
		for x in range(16):
			var key: String = pattern[y].substr(x,1)
			if key!=" ":
				var pixel_color: Color=palette[key]
				if back and y<9: pixel_color=palette.h
				var yy := y
				if frame%2==1 and y>=17: yy=mini(23,y+(1 if x<8 else -1))
				image.set_pixel(x,yy,pixel_color)
	return ImageTexture.create_from_image(image)

func _build_player() -> void:
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
	avatar.pixel_size=0.10
	avatar.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	avatar.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	avatar.position.y=1.15
	avatar.shaded=true
	for back in [false,true]:
		for frame in range(2):
			sprite_frames.append(_pixel_character(Color("#4fa9b0"),frame,back))
	avatar.texture=sprite_frames[0]
	player.add_child(avatar)
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
	camera.size=23.0
	camera.far=200
	camera.position=player.position+Vector3(0,20,25)
	add_child(camera)
	camera.look_at(player.position+Vector3(0,0,-3))
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
	var back := movement.y < -0.1
	var frame := int(time*8.0)%2 if movement.length()>0.1 else 0
	avatar.texture=sprite_frames[(2 if back else 0)+frame]
	if absf(movement.x)>0.1: avatar.flip_h=movement.x<0
	camera.position=camera.position.lerp(player.position+Vector3(0,20,25),minf(1,delta*7))
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
	if reduced_motion: return
	for item in animated:
		var node: Node3D=item.node
		var amount := 0.16 if item.kind=="float" else 0.04
		if item.kind=="water": amount=0.32
		node.position.y=item.base.y+sin(time*1.5+item.phase)*amount
		if item.kind=="flag": node.rotation.z=sin(time*2+item.phase)*0.08

func interact() -> void:
	if not blocked and not nearest.is_empty():
		interaction_requested.emit(nearest.id,nearest.label)

func set_night(value: bool) -> void:
	night=value
	sun.light_energy=0.3 if value else 1.4
	sun.light_color=Color("#b6c4ef") if value else Color("#ffe4b1")
	environment.background_color=Color("#172e4b") if value else Color("#89bcc8")
	environment.ambient_light_color=Color("#6b83ad") if value else Color("#a9d5da")
	environment.ambient_light_energy=0.5 if value else 0.65
	for lamp in lamps: lamp.light_energy=1.6 if value else 0.0

func apply_settings(settings: Dictionary) -> void:
	reduced_motion=bool(settings.get("reduced_motion",false))
	sea_material.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)
	fountain_water.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)

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
