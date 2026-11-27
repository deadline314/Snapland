extends RefCounted
## The coastal loop's six landmarks, rock ridges and offshore islets. Authored
## profiles create solid 3D silhouettes; the trail itself is an IslandLayout path.

const IslandLayout = preload("res://game/world/island_layout.gd")
## Six landmarks on the coastal loop. Where each plaque and landmark stands is
## IslandLayout.COAST_STOPS; this table holds what the visitor reads.
const STOPS := [
	{"id":"sail-loft", "name":"風帆修繕所", "text":"帆布上每一道補線，都記著晚風號走過的海路。屋架朝海的一邊特意留空，讓剛上岸的帆慢慢吹乾。"},
	{"id":"storm-bell", "name":"聽潮鐘亭", "text":"舊鐘不報時，只在海霧來時替船指路。往北看，燈塔的銅頂正從岩脊後露出來。"},
	{"id":"lighthouse", "name":"回聲燈塔", "text":"燈塔的三道環廊分別記錄低潮、滿潮和最遠的一次浪。沿著石路繞過岩脊，還能從北岸看見園區的另一面。"},
	{"id":"star-court", "name":"北岸觀星庭", "text":"銅環把海風和星軌收在同一個圓裡。這裡遠離大道的熱鬧，坐下來時，只剩潮聲替旅程留白。"},
	{"id":"glass-garden", "name":"海玻璃溫室", "text":"被海水磨圓的玻璃，成了溫室一格格青綠的窗。花匠把耐鹽的植物留在外側，替裡面的小苗擋風。"},
	{"id":"tide-wheel", "name":"潮汐水車", "text":"水車把潮水帶進高處的木槽，再緩緩送回海裡。沿著岸邊的石路再走一段，就會回到碼頭；不必原路折返。"},
]
## Offshore rocks that give the open sea a horizon: x, z.
const ISLETS := [Vector2(-62,-168), Vector2(-34,-171), Vector2(-14,-186), Vector2(34,-178), Vector2(62,-170), Vector2(108,-110), Vector2(-100,-98)]
const RIDGE_VARIANTS := 2
## The faceted meshes are costly to generate; every Welcome world shares them.
static var _ridge_shapes: Array[ArrayMesh] = []

## The stop behind an interaction id, with its plaque "position" filled in.
static func description(id: String) -> Dictionary:
	return stop(id.trim_prefix("coast:")) if id.begins_with("coast:") else {}

static func stop(id: String) -> Dictionary:
	for record: Dictionary in STOPS:
		if id == str(record.id):
			var placed := record.duplicate()
			placed["position"] = IslandLayout.COAST_STOPS[id].position
			return placed
	return {}

## Where a stop's landmark stands: beside its plaque, clear of the trail.
static func landmark(id: String) -> Vector3:
	return IslandLayout.stop_landmark(id)

static func build(world: Node3D) -> void:
	_build_rocks(world)
	for index in STOPS.size():
		var stop_record := stop(str(STOPS[index].id))
		var p: Vector3 = stop_record.position
		var origin := landmark(str(stop_record.id))
		match index:
			0: _sail_loft(world,origin)
			1: _bell(world,origin)
			2: _lighthouse(world,origin)
			3: _star_court(world,origin)
			4: _glasshouse(world,origin)
			5: _waterwheel(world,origin)
		world._point("coast:"+str(stop_record.id),str(stop_record.name),p)
		world._local_label(str(stop_record.name),p+Vector3(0,1.2,-1.9),20)
		world._box(p+Vector3(1.9,0.55,0.3),Vector3(0.1,1.1,0.1),Color("#715842"))
		var plaque: MeshInstance3D = world._box(p+Vector3(1.9,1.05,0.3),Vector3(0.75,0.46,0.1),Color("#366c69"))
		plaque.rotation.x = -0.18
		world._lantern(p+Vector3(-1.9,1.5,0.3))
		world._cylinder(p+Vector3(-1.9,0.7,0.3),0.07,1.4,Color("#715842"))
		# Join the existing nearest-light budget; decorative emissive bulbs alone
		# do not illuminate a newly distant walkable destination.
		var light := OmniLight3D.new()
		light.position = p+Vector3(-1.9,2.2,0.3)
		light.light_color = Color("#ffd9a0")
		light.omni_range = 7.0
		light.light_energy = 0.0
		world.add_child(light)
		world.lamps.append(light)

static func _build_rocks(world: Node3D) -> void:
	# Separate ridges interrupt long views across the lawns without sealing a path.
	# A few shared shapes, turned and stretched per site, stand in for unique meshes.
	var heights: Array[float] = []
	for variant in RIDGE_VARIANTS:
		var height := 3.2 + float(variant) * 1.5
		heights.append(height)
		if _ridge_shapes.size() > variant: continue
		var profile: Array[Vector2] = [Vector2(0,0),Vector2(3.1,0),Vector2(3.4,0.35),Vector2(2.8,height*0.45),Vector2(3.1,height*0.57),Vector2(1.7,height),Vector2(0,height+0.12)]
		_ridge_shapes.append(_profile_mesh(profile,7,variant,true))
	var shapes := _ridge_shapes
	var cap_mesh := _profile_mesh([Vector2(0,0),Vector2(1.75,0),Vector2(1.6,0.22),Vector2(0,0.22)],7,0)
	for index in IslandLayout.RIDGES.size():
		var site: Vector2 = IslandLayout.RIDGES[index]
		var p := Vector3(site.x,0,site.y)
		var variant := index % RIDGE_VARIANTS
		world.occlusion_controller.begin_building()
		var rock: MeshInstance3D = world._mesh(shapes[variant],p,world._vertex_color_material("coastal-mineral"))
		rock.scale = Vector3(1.0,1.0,1.2+fposmod(float(index)*0.33,0.6))
		rock.rotation.y = float(index)*0.9
		rock.name = "CoastalRidge%02d" % index
		rock.create_convex_collision()
		# A low grass cap catches the sunlight; the faceted side remains stone.
		var cap: MeshInstance3D = world._mesh(cap_mesh,p+Vector3(0,heights[variant],0),world._mat(Color("#385b37")))
		cap.scale = rock.scale
		cap.rotation.y = rock.rotation.y
		cap.name = "RidgeGrass%02d" % index
		world.occlusion_controller.finish_building(rock.get_child(0) as StaticBody3D)
	# Far islets create a horizon beyond the playable shoreline.
	for index in ISLETS.size():
		var p := Vector3(ISLETS[index].x, -0.3, ISLETS[index].y)
		var profile: Array[Vector2] = [Vector2(0,0),Vector2(5.0,0),Vector2(4.0,1.4),Vector2(1.8,3.6),Vector2(0,3.9)]
		world._mesh(_profile_mesh(profile,7,index+31),p,world._mat(Color("#6f8b83")))

static func _profile_mesh(profile: Array[Vector2], sides: int, seed_value := 0, mineral := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for side in sides:
			var points: Array[Vector3] = []
			for pair in [Vector2i(row,side),Vector2i(row,side+1),Vector2i(row+1,side),Vector2i(row+1,side+1)]:
				var angle := TAU*float(pair.y)/float(sides)
				var shape := 1.0 + sin(float(pair.y%sides)*2.7+float(seed_value))*0.055
				points.append(Vector3(cos(angle)*profile[pair.x].x*shape,profile[pair.x].y,sin(angle)*profile[pair.x].x*shape))
			var divisions := 8 if mineral else 1
			for x in divisions:
				for y in divisions:
					var patch: Array[Vector3] = []
					for uv in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y+1)]:
						var across: float = float(uv.x)/float(divisions)
						patch.append(points[0].lerp(points[1],across).lerp(points[2].lerp(points[3],across),uv.y/float(divisions)))
					var center := (patch[0]+patch[3])*0.5
					var pigment := Color.WHITE
					if mineral:
						var grain := sin(float(x*73+y*179+side*31+seed_value*17))*0.035
						var stratum := sin(center.y*8.5+sin(center.x*1.9)*0.6)*0.045
						pigment = Color("#617564")*(0.86+grain+stratum)
					for triangle in [Vector3i(0,1,2),Vector3i(1,3,2)]:
						for vertex in [triangle.x,triangle.y,triangle.z]:
							tool.set_color(pigment)
							tool.set_uv(Vector2(atan2(patch[vertex].z,patch[vertex].x)/TAU,patch[vertex].y*0.35))
							tool.add_vertex(patch[vertex])
	tool.generate_normals()
	return tool.commit()

static func _lathe(world: Node3D, p: Vector3, profile: Array[Vector2], color: Color, sides := 12) -> MeshInstance3D:
	return world._mesh(_profile_mesh(profile,sides),p,world._mat(color))

static func _beam(world: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> MeshInstance3D:
	var beam: MeshInstance3D = world._box((a+b)*0.5,Vector3(width,width,a.distance_to(b)),color)
	beam.look_at_from_position((a+b)*0.5,b,Vector3.UP if absf((b-a).normalized().y)<0.99 else Vector3.RIGHT)
	return beam

static func _sail_loft(world: Node3D, p: Vector3) -> void:
	for x in [-1.5,1.5]:
		for z in [-1.5,1.5]:
			world._box(p+Vector3(x,1.5,z),Vector3(0.18,3,0.18),Color("#796247"),true)
		_beam(world,p+Vector3(x,2.7,-1.5),p+Vector3(x,3.65,0),0.16,Color("#92724e"))
		_beam(world,p+Vector3(x,3.65,0),p+Vector3(x,2.7,1.5),0.16,Color("#92724e"))
	for side in [-1,1]:
		var roof: MeshInstance3D = world._box(p+Vector3(0,3.15,float(side)*0.85),Vector3(3.8,0.12,2.0),Color("#d6c39b"))
		roof.rotation.x = float(side)*0.56
		for stripe in 4:
			var seam: MeshInstance3D = world._box(p+Vector3(-1.35+float(stripe)*0.9,3.23,float(side)*0.85),Vector3(0.07,0.05,1.95),Color("#628b85"))
			seam.rotation.x = float(side)*0.56
	world._box(p+Vector3(0,0.72,0.65),Vector3(2.1,0.15,0.8),Color("#94764f"),true)
	for index in 3:
		var roll: MeshInstance3D = world._cylinder(p+Vector3(-0.65+float(index)*0.65,1.05,0.6),0.19,0.7,Color("#6b9a92") if index%2==0 else Color("#d1ba8c"))
		roll.rotation.z = PI*0.5

static func _bell(world: Node3D, p: Vector3) -> void:
	for x in [-1.15,1.15]:
		world._box(p+Vector3(x,1.7,0),Vector3(0.27,3.4,0.35),Color("#705a43"),true)
	_beam(world,p+Vector3(-1.5,3.35,0),p+Vector3(1.5,3.35,0),0.3,Color("#937249"))
	var pivot := Node3D.new()
	pivot.name = "CoastalBellSwing"
	world.add_child(pivot)
	pivot.position = p+Vector3(0,2.85,0)
	var shell := _lathe(world,p+Vector3(0,1.8,0),[Vector2(0,0),Vector2(0.8,0),Vector2(0.86,0.14),Vector2(0.46,0.85),Vector2(0.4,1.0),Vector2(0,1.05)],Color("#a98347"))
	shell.reparent(pivot)
	var clapper: MeshInstance3D = world._sphere(p+Vector3(0,1.68,0),0.14,Color("#70563b"))
	clapper.reparent(pivot)
	var rope := _beam(world,p+Vector3(0,1.65,0),p+Vector3(0,0.6,0),0.04,Color("#d5bf91"))
	rope.reparent(pivot)

static func _lighthouse(world: Node3D, p: Vector3) -> void:
	var tower := _lathe(world,p,[Vector2(0,0),Vector2(1.7,0),Vector2(1.8,0.25),Vector2(1.15,0.5),Vector2(0.88,5.9),Vector2(0,5.9)],Color("#d0c6a4"))
	tower.name = "CoastalLighthouse"
	tower.material_override = world._coastal_surface(4,2.2,Color("#b5bb9f"))
	tower.create_convex_collision()
	for level in [1.4,3.2,5.8]:
		_lathe(world,p+Vector3(0,level,0),[Vector2(0,0),Vector2(1.12,0),Vector2(1.16,0.16),Vector2(0,0.16)],Color("#4b7773"))
		for side in 8:
			var angle := TAU*float(side)/8.0
			world._box(p+Vector3(cos(angle)*1.22,level+0.48,sin(angle)*1.22),Vector3(0.055,0.64,0.055),Color("#836b46"))
		_ring(world,p+Vector3(0,level+0.8,0),1.24,0.035,Color("#806a3f"))
	_lathe(world,p+Vector3(0,5.98,0),[Vector2(0,0),Vector2(0.78,0),Vector2(0.78,1.28),Vector2(0,1.28)],Color("#759d92"))
	for side in 6:
		var angle := TAU*float(side)/6.0
		world._box(p+Vector3(cos(angle)*0.8,6.62,sin(angle)*0.8),Vector3(0.08,1.35,0.08),Color("#806b47"))
	_lathe(world,p+Vector3(0,7.28,0),[Vector2(0,0),Vector2(1.4,0),Vector2(1.45,0.15),Vector2(0.14,1.0),Vector2(0,1.12)],Color("#4c7972"))
	world._lantern(p+Vector3(0,6.65,0))
	world._box(p+Vector3(0,8.6,0),Vector3(0.06,0.6,0.06),Color("#a08752"))
	_beam(world,p+Vector3(-0.6,8.8,0),p+Vector3(0.6,8.8,0),0.06,Color("#a08752"))
	world._box(p+Vector3(0.32,8.8,0),Vector3(0.3,0.28,0.04),Color("#bb7958"))

static func _star_court(world: Node3D, p: Vector3) -> void:
	_lathe(world,p,[Vector2(0,0),Vector2(3.0,0),Vector2(3.0,0.2),Vector2(0,0.2)],Color("#aca88e"))
	var base := _lathe(world,p,[Vector2(0,0.2),Vector2(0.7,0.2),Vector2(0.5,1.8),Vector2(0,1.8)],Color("#b7b69e"))
	base.create_convex_collision()
	for index in 3:
		var ring := _ring(world,p+Vector3(0,2.8,0),1.3,0.045,Color("#927444"))
		ring.rotation=Vector3(0.35+float(index)*0.6,0.4,0.25+float(index)*0.7)
	world._sphere(p+Vector3(0,2.8,0),0.38,Color("#558581"))
	for side in [-1,1]:
		world._box(p+Vector3(float(side)*2.35,0.6,0.6),Vector3(0.6,0.14,1.7),Color("#92764e"),true)
		world._box(p+Vector3(float(side)*2.65,1.0,0.6),Vector3(0.1,0.6,1.7),Color("#92764e"))

static func _glasshouse(world: Node3D, p: Vector3) -> void:
	var base: MeshInstance3D = world._box(p+Vector3(0,0.35,0),Vector3(3.7,0.7,4.4),Color("#9c967e"),true)
	base.name = "CoastalGlasshouse"
	base.material_override = world._coastal_surface(4,1.7,Color("#b7b49b"))
	for x in [-1.7,1.7]:
		for z in [-1.9,0.0,1.9]:
			world._box(p+Vector3(x,1.7,z),Vector3(0.14,2.7,0.14),Color("#506f65"))
		var panel: MeshInstance3D = world._box(p+Vector3(x,1.8,0),Vector3(0.05,2.1,3.8),Color("#80b1a2"))
		panel.material_override=world._mat(Color("#426e65"))
	for side in [-1,1]:
		var roof: MeshInstance3D = world._box(p+Vector3(float(side)*0.95,3.1,0),Vector3(2.2,0.09,4.6),Color("#4c7c72"))
		roof.rotation.z = -float(side)*0.57
		for z in [-2.1,-0.7,0.7,2.1]:
			_beam(world,p+Vector3(float(side)*1.86,2.55,z),p+Vector3(0,3.75,z),0.09,Color("#506f65"))
	for index in 4:
		var pot_p := p+Vector3(-1.2+float(index)*0.8,0.1,2.65)
		_lathe(world,pot_p,[Vector2(0,0),Vector2(0.22,0),Vector2(0.34,0.5),Vector2(0,0.5)],Color("#b27758"),8)
		world._sphere(pot_p+Vector3(0,0.9,0),0.36,Color("#71945b"))

static func _waterwheel(world: Node3D, p: Vector3) -> void:
	var wheel_origin := p+Vector3(0,2.4,0)
	for z in [-0.55,0.55]:
		world._box(p+Vector3(0,1.15,z),Vector3(0.3,2.3,0.22),Color("#756243"),true)
	var pivot := Node3D.new()
	pivot.name = "CoastalWaterwheelRotor"
	world.add_child(pivot)
	pivot.position = wheel_origin
	world.coastal_rotors.append(pivot)
	for side in [-1,1]:
		var ring := _ring(world,wheel_origin+Vector3(0,0,float(side)*0.45),1.9,0.09,Color("#866841"))
		ring.rotation.x=PI*0.5
		ring.reparent(pivot)
	for index in 12:
		var angle := TAU*float(index)/12.0
		var end := wheel_origin+Vector3(cos(angle)*1.9,sin(angle)*1.9,0)
		var spoke := _beam(world,wheel_origin,end,0.11,Color("#9b8055"))
		spoke.reparent(pivot)
		var paddle: MeshInstance3D = world._box(end,Vector3(0.38,0.14,1.3),Color("#627554"))
		paddle.rotation.z = angle
		paddle.reparent(pivot)
	var flow: MeshInstance3D = world._box(p+Vector3(0,0.2,0),Vector3(2.4,0.16,5.4),Color("#285d62"))
	flow.name = "CoastalWaterFlow"
	for side in [-1,1]:
		world._box(p+Vector3(float(side)*1.25,0.32,0),Vector3(0.18,0.38,5.6),Color("#7c8067"),true)

static func _ring(world: Node3D, position: Vector3, radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-thickness
	mesh.outer_radius = radius+thickness
	mesh.rings = 24
	mesh.ring_segments = 6
	return world._mesh(mesh,position,world._mat(color))
