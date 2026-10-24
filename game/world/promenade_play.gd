extends Node3D
## Unscored walk-up toys; scene memory only, with no Progress dependency.
signal note_requested(note: int)
const PADS := [Vector2(-1.4,-16),Vector2(1.4,-23),Vector2(-1.4,-30),Vector2(1.4,-37)]
const COLORS := [Color("#da705c"),Color("#4b9b9c"),Color("#edbb65"),Color("#d5dfc0")]
var world: Node3D
var records: Array[Dictionary] = []
var _blade: ArrayMesh

func configure(owner_world: Node3D) -> void:
	world=owner_world
	_blade=_folded_blade()
	for index in PADS.size(): _build(index)

func _build(index: int) -> void:
	var pad: Vector2=PADS[index]
	var surface: float=world._ground_surface_y(Vector3(pad.x,0,pad.y))
	var center:=Vector3(pad.x,surface,pad.y)
	var side:=signf(pad.x)
	var stand:=center+Vector3(side*1.05,0,0)
	var base: MeshInstance3D=world._box(stand+Vector3(0,0.14,0),Vector3(0.42,0.28,0.42),Color("#8a6a48"))
	base.name="PromenadeWindmillBase%d"%index
	world._box(stand+Vector3(0,0.86,0),Vector3(0.085,1.25,0.085),Color("#ac8956"))
	var rotor:=Node3D.new();rotor.name="PromenadeWindmillRotor%d"%index
	world.add_child(rotor);rotor.position=stand+Vector3(0,1.52,0.10)
	for blade in 4:
		var mesh: MeshInstance3D=world._mesh(_blade,Vector3.ZERO,world._mat(COLORS[(blade+index)%4]))
		mesh.reparent(rotor,false);mesh.position=Vector3.ZERO;mesh.rotation.z=blade*PI*0.5
	var hub: MeshInstance3D=world._cylinder(rotor.position+Vector3(0,0,0.07),0.075,0.13,Color("#e9d4a4"))
	hub.rotation.x=PI*0.5
	world._box(center+Vector3(0,0.002,0),Vector3(1.06,0.004,0.86),Color("#8a6a48"))
	var plate:=Node3D.new();plate.name="PromenadePressurePlate%d"%index
	world.add_child(plate);plate.position=center+Vector3(0,0.006,0)
	var top: MeshInstance3D=world._box(Vector3.ZERO,Vector3(0.92,0.006,0.72),Color("#3b7278"))
	top.reparent(plate,false);top.position=Vector3.ZERO
	for foot in [-1.0,1.0]:
		var print_mesh: MeshInstance3D=world._box(Vector3.ZERO,Vector3(0.10,0.001,0.25),Color("#e9d4a4"))
		print_mesh.reparent(plate,false);print_mesh.position=Vector3(foot*0.15,0.004,foot*0.045);print_mesh.rotation.y=foot*0.16
	var id:="play:wind-%d"%index
	world._point(id,"轉動踏板風車",center,1.05)
	records.append({"id":id,"center":center,"rotor":rotor,"plate":plate,"plate_y":plate.position.y,"inside":false,"turns":0,"target":0.0,"cooldown":0.0})

func _folded_blade() -> ArrayMesh:
	# A folded paper quadrilateral, with explicit front and back faces.
	var points: Array[Vector3]=[Vector3(0.025,0.025,0.025),Vector3(0.46,0.05,0),Vector3(0.39,0.43,0),Vector3(0.075,0.22,0.08)]
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for triangle in [[0,2,1],[0,3,2],[0,1,2],[0,2,3]]:
		var a: Vector3=points[triangle[0]];var b: Vector3=points[triangle[1]];var c: Vector3=points[triangle[2]]
		var normal: Vector3=(c-a).cross(b-a).normalized()
		for point in [a,b,c]:vertices.append(point);normals.append(normal)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func activate(id: String) -> bool:
	for record in records:
		if record.id!=id:continue
		_turn(record)
		return true
	return false

func prompt(id: String) -> String:
	for record in records:
		if record.id==id:return "轉動踏板風車"
	return ""

func advance(delta: float) -> void:
	for record in records:
		record.cooldown=maxf(0.0,float(record.cooldown)-delta)
		var offset: Vector3=world.to_local(world.player.global_position)-record.center
		var inside: bool=absf(offset.x)<=0.49 and absf(offset.z)<=0.39 and absf(offset.y)<=1.1
		if inside and not record.inside:_turn(record)
		record.inside=inside
		var rotor: Node3D=record.rotor
		if world.reduced_motion:rotor.rotation.z=fposmod(float(record.target),TAU)
		else:rotor.rotation.z=lerp_angle(rotor.rotation.z,float(record.target),minf(1.0,delta*10.0))
		var plate: Node3D=record.plate
		plate.position.y=float(record.plate_y)-(0.004 if inside else 0.0)

func _turn(record: Dictionary) -> void:
	if float(record.cooldown)>0.0:return
	record.cooldown=0.3
	record.turns=int(record.turns)+1
	record.target=float(record.target)+PI*0.5
	if world.reduced_motion:record.rotor.rotation.z=fposmod(float(record.target),TAU)
	note_requested.emit([0,2,3,2][records.find(record)])
