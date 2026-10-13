extends Node3D

## Scene-scoped owner for the tidal shell carousel and its short ride lifecycle.
signal ride_changed(active: bool)

const RIDE_SECONDS := 12.0
const RIDE_POINT_ID := "ride-tide"

var _world: Node3D
var _player: CharacterBody3D
var _interaction_position := Vector3(-10.4, 0.28, 12.2)
var _ride_pivot: Node3D
var _seat_marker: Marker3D
var _riding := false
var _reduced_motion := false
var _elapsed := 0.0
var _saved_position := Vector3.ZERO
var _materials: Dictionary = {}
var _geometry_parent: Node3D

func configure(world: Node3D, player: CharacterBody3D, interaction_position: Vector3) -> void:
	_world = world
	_player = player
	_interaction_position = interaction_position
	_build_coastal_boardwalk()
	_build_tide_carousel()
	_register_ride_cutaway()

func _register_ride_cutaway() -> void:
	var controller: Node = _world.get("occlusion_controller")
	if not is_instance_valid(controller):
		return
	controller.begin_building()
	for geometry in _ride_pivot.find_children("*","MeshInstance3D",true,false):
		controller.register_geometry(geometry,geometry.material_override)
	var blocker := StaticBody3D.new()
	blocker.name = "RideVisibilityBlocker"
	blocker.collision_layer = 0
	blocker.collision_mask = 0
	_ride_pivot.add_child(blocker)
	controller.finish_building(blocker)

func _build_coastal_boardwalk() -> void:
	# Low timber deck links the plaza edge to the ride without a stair or a tide gate.
	var main_deck := _box(Vector3(-9.6, 0.16, 10.0), Vector3(7.8, 0.2, 6.8), Color("#8c704c"))
	main_deck.name = "TideBoardwalkDeck"
	main_deck.material_override = _surface(1,1.8,Color("#ead8b4"))
	var body := StaticBody3D.new()
	body.name = "TideBoardwalkWalkSurfaceBody"
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	# One convex top profile keeps the flat deck, fall-through-free ramp and lawn
	# at a single continuous support surface. Its landward face stays below the
	# floor top so the island ground collider meets it without a blocking lip.
	var walk_profile := ConvexPolygonShape3D.new()
	var profile: Array[Vector2] = [
		Vector2(-3.9,0.1), Vector2(3.9,0.1), Vector2(5.4,0.02),
		Vector2(6.4,0.02), Vector2(6.4,-0.12), Vector2(-3.9,-0.12),
	]
	var profile_points := PackedVector3Array()
	for edge_z in [-3.4,3.4]:
		for point in profile:
			profile_points.append(Vector3(point.x,point.y,edge_z))
	walk_profile.points = profile_points
	shape.shape = walk_profile
	body.add_child(shape)
	main_deck.add_child(body)
	# Visible approach is a shallow timber sheet; its continuous top is supplied
	# by TideBoardwalkWalkSurfaceBody rather than a vertical-ended slab collider.
	var ramp_angle := -atan(0.08 / 1.5)
	var ramp_length := sqrt(1.5 * 1.5 + 0.08 * 0.08)
	var ramp_center_y := 0.22 - cos(ramp_angle) * 0.02
	var ramp_size := Vector3(ramp_length,0.04,6.8)
	var connector := _box(Vector3(-4.95,ramp_center_y,10.0),ramp_size,Color("#9a7952"))
	connector.name = "TideBoardwalkApproach"
	connector.material_override = _surface(1,1.2,Color("#e0c79a"))
	connector.rotation.z = ramp_angle
	for index in range(17):
		var x := -13.3 + float(index)*0.46
		var seam_y := 0.26 if x <= -5.7 else lerpf(0.26,0.18,inverse_lerp(-5.7,-4.2,x))
		var seam := _box(Vector3(x,seam_y+0.0175,10.0),Vector3(0.035,0.035,5.2),Color("#d0b68a"))
		seam.material_override = _surface(7,0.6,Color("#b99866"))
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z_offset in [-3.15,3.15]:
		for index in range(6):
			var x := -12.3 + float(index)*1.1
			var post := _cylinder(Vector3(x,0.68,10.0+z_offset),0.07,0.78,Color("#6d5c45"))
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_cylinder_collision(post,0.07,0.78,"TideBoardwalkRailPostCollision")
		for segment in range(5):
			var rail := _box(Vector3(-11.75+segment*1.1,0.92,10.0+z_offset),Vector3(1.1,0.055,0.055),Color("#ddc99f"))
			_add_box_collision(rail,Vector3(1.1,0.055,0.055),"TideBoardwalkHandrailCollision")
	var shell_posts := [-12.1,-7.1]
	for index in range(shell_posts.size()):
		var float_pos := Vector3(shell_posts[index],0.35,7.55)
		var shell := _sphere(float_pos,0.6,Color("#d7c7a3") if index==0 else Color("#d77e64"))
		shell.scale=Vector3(1.35,0.52,0.8)
		var lip := _mesh(TorusMesh.new(),float_pos+Vector3(0,0.23,0),_mat(Color("#f3e5c3")))
		lip.scale=Vector3(0.62,0.62,0.25)
		lip.rotation_degrees.x=90

func _build_tide_carousel() -> void:
	_ride_pivot = Node3D.new()
	_ride_pivot.name = "TidalCarouselTurntable"
	_ride_pivot.position = Vector3(-9.7,0.28,10.0)
	add_child(_ride_pivot)
	_geometry_parent = _ride_pivot
	var foundation := _cylinder(Vector3.ZERO,2.6,0.18,Color("#a89167"),2.6)
	foundation.name = "CarouselFoundation"
	foundation.material_override = _surface(4,1.7,Color("#d3bd91"))
	_add_cylinder_collision(foundation,2.6,0.18,"CarouselFoundationCollision")
	var inlay := _cylinder(Vector3(0,0.13,0),2.25,0.09,Color("#477d7b"),2.25)
	inlay.material_override = _surface(5,1.0,Color("#d8ece1"))
	_cylinder(Vector3(0,0.21,0),1.18,0.16,Color("#ead8b0"),1.18)
	var spindle := _cylinder(Vector3(0,1.52,0),0.19,2.6,Color("#765c42"),0.27)
	spindle.name = "ShellCarouselSpindle"
	spindle.material_override = _surface(1,1.2,Color("#d4b27a"))
	_add_cylinder_collision(spindle,0.19,2.6,"CarouselSpindleCollision")
	for height in [0.52,1.54,2.3]:
		var collar := _cylinder(Vector3(0,height,0),0.42 if height<2.0 else 0.30,0.12,Color("#d89d62") if height<2.0 else Color("#eee0c1"))
		collar.material_override = _surface(7,0.8,Color("#ccb179"))
		collar.rotation.y=height*0.15
	var orbit := Node3D.new()
	orbit.name = "ShellGondolas"
	_ride_pivot.add_child(orbit)
	var ring := _mesh(TorusMesh.new(),Vector3(0,2.25,0),_mat(Color("#d1b878")))
	ring.name = "OverheadGondolaRing"
	ring.material_override = _surface(7,0.8,Color("#c4a56f"))
	ring.scale=Vector3(2.05,0.06,2.05)
	for index in range(4):
		var angle := TAU*float(index)/4.0
		var center := Vector3(cos(angle)*1.55,0.0,sin(angle)*1.55)
		# Two rear corner posts leave the seat and rider's head unobstructed.
		var seat_basis := Basis(Vector3.UP,-angle)
		for side in [-1.0,1.0]:
			var support := _box(center+seat_basis*Vector3(side*0.52,1.2,-0.58),Vector3(0.10,2.4,0.1),Color("#d5bf8e"))
			support.name = "GondolaRearSupport%d_%s" % [index+1,"Left" if side<0.0 else "Right"]
			support.material_override = _surface(1,0.8,Color("#d1b27e"))
			support.rotation.y=-angle
		var shell_color: Color = [Color("#de8369"),Color("#76aaa1"),Color("#e4c278"),Color("#81758d")][index]
		var gondola := Node3D.new()
		gondola.name = "ShellSeat%d" % (index+1)
		# Feet stay near the deck; the authored bent-knee pose places the hips
		# above this cushion. Seat geometry shares the moving gondola transform.
		gondola.position = center+Vector3(0,-0.08,0)
		gondola.rotation.y=-angle
		orbit.add_child(gondola)
		_geometry_parent = gondola
		var cushion := _box(Vector3(0,0.48,0),Vector3(0.82,0.12,0.66),Color("#efe0bf"))
		cushion.name = "OpenSeatCushion"
		cushion.material_override = _surface(6,0.55,Color("#eee0bf"))
		var back := _mesh(SphereMesh.new(),Vector3(0,0.95,-0.22),_mat(shell_color))
		back.material_override = _surface(3,0.8,shell_color)
		back.scale=Vector3(0.48,0.45,0.19)
		for side in [-1.0,1.0]:
			var arm := _box(Vector3(side*0.42,0.76,0),Vector3(0.09,0.42,0.52),shell_color)
			arm.rotation.z=side*-0.12
		if index==0:
			_seat_marker = Marker3D.new()
			_seat_marker.name = "RiderSeatMarker"
			_seat_marker.position = Vector3(0,0.08,0.02)
			gondola.add_child(_seat_marker)
		_geometry_parent = _ride_pivot
	for index in range(8):
		var angle := TAU*float(index)/8.0
		var glint := _sphere(Vector3(cos(angle)*2.22,0.24,sin(angle)*2.22),0.085,Color("#f3d18a"))
		glint.material_override=_mat(Color("#f3d18a"),true)
	var canopy := _mesh(TorusMesh.new(),Vector3(0,2.82,0),_mat(Color("#658e88")))
	canopy.material_override = _surface(2,1.2,Color("#91aaa0"))
	canopy.scale=Vector3(1.35,0.1,1.35)
	for index in range(8):
		var angle := TAU*float(index)/8.0
		var panel := _box(Vector3(cos(angle)*0.9,2.82,sin(angle)*0.9),Vector3(0.06,0.05,1.5),Color("#e6cf9f"))
		panel.material_override = _surface(6,1.0,Color("#ead9b7"))
		panel.rotation.y=-angle
	var title := Label3D.new()
	title.text = "潮汐貝殼輪"
	title.font_size = 22
	title.pixel_size = 0.015
	title.position = Vector3(-0.1,3.55,-2.8)
	title.modulate = Color("#f2dfb5")
	title.outline_size = 4
	title.outline_modulate = Color("#29444b")
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ride_pivot.add_child(title)
	_geometry_parent = null

func _process(delta: float) -> void:
	if not _riding:
		return
	if not is_instance_valid(_world) or bool(_world.get("blocked")):
		end_ride()
		return
	_elapsed = minf(RIDE_SECONDS,_elapsed+delta)
	var progress := _elapsed/RIDE_SECONDS
	_ride_pivot.rotation.y = 0.0 if _reduced_motion else TAU*0.6*progress
	if is_instance_valid(_player) and is_instance_valid(_seat_marker):
		var seat_position := _seat_marker.global_position
		_player.global_position = seat_position
		_player.velocity = Vector3.ZERO
	if _elapsed >= RIDE_SECONDS:
		end_ride()

func start_ride() -> bool:
	if _riding or not is_instance_valid(_world) or not is_instance_valid(_player):
		return false
	if bool(_world.get("blocked")) or _player.global_position.distance_to(_interaction_position)>2.4:
		return false
	_saved_position = _player.position
	_elapsed = 0.0
	_ride_pivot.rotation.y = 0.0
	_riding = true
	_player.velocity=Vector3.ZERO
	_player.global_position=_seat_marker.global_position
	ride_changed.emit(true)
	return true

func end_ride() -> void:
	if not _riding:
		return
	_riding = false
	_elapsed = 0.0
	_ride_pivot.rotation.y = 0.0
	if is_instance_valid(_player):
		_player.velocity=Vector3.ZERO
		# Local coordinates also remain valid from ParkWorld._exit_tree(), when
		# global transforms are no longer available.
		_player.position=_saved_position
	ride_changed.emit(false)

func is_riding() -> bool:
	return _riding

func ride_elapsed() -> float:
	return _elapsed if _riding else 0.0

func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion=enabled
	if enabled and _riding:
		_ride_pivot.rotation.y=0.0

func _box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=_mat(color)
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(_geometry_parent if is_instance_valid(_geometry_parent) else self).add_child(instance)
	return instance

func _add_cylinder_collision(mesh_instance: MeshInstance3D, radius: float, height: float, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	mesh_instance.add_child(body)
	return body

func _add_box_collision(mesh_instance: MeshInstance3D, size: Vector3, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	mesh_instance.add_child(body)
	return body

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, top: float=-1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius if top<0.0 else top
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=20
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=_mat(color)
	(_geometry_parent if is_instance_valid(_geometry_parent) else self).add_child(instance)
	return instance

func _sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*2.0
	mesh.radial_segments=16
	mesh.rings=8
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=_mat(color)
	(_geometry_parent if is_instance_valid(_geometry_parent) else self).add_child(instance)
	return instance

func _mesh(mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=material
	(_geometry_parent if is_instance_valid(_geometry_parent) else self).add_child(instance)
	return instance

func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var key := color.to_html(true)+":"+str(emissive)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.82
	if emissive:
		material.emission_enabled=true
		material.emission=color
		material.emission_energy_multiplier=0.38
	_materials[key]=material
	return material

func _surface(tile_index: int, world_tile_size: float, tint: Color) -> Material:
	if is_instance_valid(_world) and _world.has_method("_coastal_surface"):
		return _world.call("_coastal_surface",tile_index,world_tile_size,tint) as Material
	return _mat(tint)
