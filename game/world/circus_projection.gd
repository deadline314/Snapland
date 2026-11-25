extends Node3D

const PAPER_SHADER := preload("res://game/world/circus_projection_paper.gdshader")
const SCREEN_Z := -3.86
const PAPER_CENTER := Vector3(0, 1.64, SCREEN_Z)
const CUTOUT_CENTER := Vector3(0, 1.37, -2.76)
const LAMP_LEFT := Vector3(-1.20, 1.42, -1.05)
const LAMP_RIGHT := Vector3(1.20, 1.42, -1.05)
const TRANSITION_SECONDS := 0.32
const STENCIL := [
	Vector2(-0.07, -0.57), Vector2(-0.39, -0.44), Vector2(-0.57, -0.20),
	Vector2(-0.59, 0.10), Vector2(-0.44, 0.40), Vector2(-0.17, 0.57),
	Vector2(0.20, 0.54), Vector2(0.38, 0.40), Vector2(0.10, 0.37),
	Vector2(-0.07, 0.25), Vector2(-0.14, 0.06), Vector2(-0.07, -0.11),
	Vector2(0.11, -0.18), Vector2(0.27, -0.10), Vector2(0.42, -0.02),
	Vector2(0.39, -0.23), Vector2(0.20, -0.44),
]

var side := 0
var _paper: ShaderMaterial
var _lamp: MeshInstance3D
var _shadow: MeshInstance3D
var _from_lamp := LAMP_LEFT
var _elapsed := TRANSITION_SECONDS


func _ready() -> void:
	var screen := QuadMesh.new()
	screen.size = Vector2(4.50, 2.72)
	_paper = ShaderMaterial.new()
	_paper.shader = PAPER_SHADER
	_piece("ProjectionPaper", screen, PAPER_CENTER, _paper)
	var stencil := _stencil_mesh()
	_piece("CutoutStencil", stencil, CUTOUT_CENTER, _solid(Color("#b37c56")))
	_shadow = _piece("ProjectedShadow", stencil, PAPER_CENTER, _solid(Color("#24192b")))
	var bulb := SphereMesh.new()
	bulb.radius = 0.127
	bulb.height = 0.254
	bulb.radial_segments = 12
	bulb.rings = 4
	_lamp = _piece("ProjectionLamp", bulb, LAMP_LEFT, _solid(Color("#ffe1a1")))
	_place_light(LAMP_LEFT)


func toggle(reduced_motion: bool) -> void:
	side = 1 - side
	_from_lamp = _lamp.position
	_elapsed = 0.0
	if reduced_motion:
		finish_transition()


func advance(delta: float) -> void:
	if not is_moving():
		return
	_elapsed = minf(_elapsed + delta, TRANSITION_SECONDS)
	var progress := smoothstep(0.0, TRANSITION_SECONDS, _elapsed)
	_place_light(_from_lamp.lerp(_target_lamp(), progress))


func finish_transition() -> void:
	_elapsed = TRANSITION_SECONDS
	_place_light(_target_lamp())


func is_moving() -> bool:
	return _elapsed < TRANSITION_SECONDS


func shadow_center() -> Vector3:
	return _shadow.global_position


func _target_lamp() -> Vector3:
	return LAMP_LEFT if side == 0 else LAMP_RIGHT


func _place_light(position_on_rail: Vector3) -> void:
	_lamp.position = position_on_rail
	# The light ray through each planar stencil vertex lands at the same scale on the screen.
	var multiplier := (SCREEN_Z - position_on_rail.z) / (CUTOUT_CENTER.z - position_on_rail.z)
	var center := position_on_rail + (CUTOUT_CENTER - position_on_rail) * multiplier
	_shadow.position = Vector3(center.x, center.y, SCREEN_Z + 0.013)
	_shadow.scale = Vector3(multiplier, multiplier, 1.0)
	_paper.set_shader_parameter("lamp_x", position_on_rail.x)


func _stencil_mesh() -> ArrayMesh:
	var outline := PackedVector2Array(STENCIL)
	var points := PackedVector3Array()
	for at in outline:
		points.append(Vector3(at.x, at.y, 0.0))
	var attributes := []
	attributes.resize(Mesh.ARRAY_MAX)
	attributes[Mesh.ARRAY_VERTEX] = points
	attributes[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, attributes)
	return mesh


func _piece(label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	return piece


func _solid(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
