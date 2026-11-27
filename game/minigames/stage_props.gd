extends RefCounted
## Finishes and sculpted props shared by the minigame dioramas (the 3D stages a
## view shows in a SubViewport). They follow the park scenery rules: no large
## single-colour face, props built from recognisable parts, light from one sun.
## Finishes reuse the park surface shaders; props are merged vertex-coloured
## meshes from the scenery kit, so each one costs a single node and draw.

const Scenery := preload("res://game/world/scenery_kit.gd")
const PAINTED := preload("res://game/world/painted_finish.gdshader")
const WOOD := preload("res://game/minigames/stage_wood.gdshader")
const STONE := preload("res://game/minigames/stage_stone.gdshader")
const WATER := preload("res://game/minigames/stage_water.gdshader")
const WATER_GLASS := preload("res://game/minigames/stage_water_glass.gdshader")
const SKY := preload("res://game/minigames/stage_sky.gdshader")
const HEMP := Color("#e3cf9c")
## Sky card colours per time of day: zenith, horizon, cloud, far shore.
const SKY_PHASES := {
	"dawn": ["#8fa9c4", "#f2d2b6", "#fbe6d4", "#7d8c98"],
	"noon": ["#6fb0cf", "#d6ece6", "#fbf8ec", "#73a0a4"],
	"dusk": ["#5d6f9c", "#e9b597", "#f4cdb4", "#6a6a80"],
	"night": ["#12233a", "#2e4a5e", "#3c5770", "#1c3040"],
}

## Finish for a material-table name used by the views; anything unlisted is painted.
const FINISH_BY_NAME := {
	"water": "water", "sea": "water", "shelter": "water", "channel": "water",
	"wood": "wood", "dock": "wood", "deck": "wood", "pontoon": "wood", "plank": "wood", "pier": "wood", "crate": "wood", "raft": "wood", "frame": "wood",
	"wall": "stone", "wall_top": "stone", "stone": "stone", "reef": "stone", "rock": "stone", "quay": "stone", "floor": "stone",
}

static func named(material_name: String, color: Color) -> Material:
	match str(FINISH_BY_NAME.get(material_name, "painted")):
		"water": return water(color)
		"wood": return wood(color)
		"stone": return stone(color)
	return painted(color)

static func _shaded(shader: Shader, parameter: String, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(parameter, color)
	return material

## Painted surface with pixel grain and faint courses, for any broad coloured face.
static func painted(color: Color) -> ShaderMaterial:
	return _shaded(PAINTED, "tint", color)

## Planked timber; boards run along the local X axis unless `across` is set.
static func wood(color: Color, plank_width := 0.22, across := false) -> ShaderMaterial:
	var material := _shaded(WOOD, "base_color", color)
	material.set_shader_parameter("plank_width", plank_width)
	material.set_shader_parameter("across", across)
	return material

## Dressed blocks on every face; `rough` turns them into rock strata, and faces
## below `wet_line` (world height) are darker with a weed line.
static func stone(color: Color, rough := 0.0, wet_line := -100.0) -> ShaderMaterial:
	var material := _shaded(STONE, "base_color", color)
	material.set_shader_parameter("rough", rough)
	material.set_shader_parameter("wet_line", wet_line)
	if rough > 0.0:
		material.set_shader_parameter("block", Vector2(1.1, 0.42))
	return material

## Moving water; pair with set_motion() so reduced motion holds it still.
## `see_through` suits cut-open sections where submerged hulls must show.
static func water(color: Color, see_through := false) -> ShaderMaterial:
	var material := _shaded(WATER_GLASS if see_through else WATER, "water_color", color)
	material.set_shader_parameter("foam_color", color.lerp(Color("#eef7ee"), 0.82))
	return material

static func set_motion(material: Material, reduced_motion: bool) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)

## Side-on dioramas: a sky card standing behind the scene, with clouds and a far
## shore, instead of one flat background colour. The sea horizon sits at `horizon`.
static func sky_card(parent: Node3D, center: Vector3, size: Vector2, horizon: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = SKY
	material.set_shader_parameter("horizon_height", horizon)
	material.set_shader_parameter("span", maxf(2.0, center.y + size.y * 0.5 - horizon))
	var node := add(parent, "SkyCard", quad, material, center)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_sky_phase(node, "noon", false)
	return node

static func set_sky_phase(card: MeshInstance3D, phase: String, reduced_motion: bool) -> void:
	var material := card.material_override as ShaderMaterial
	var tones: Array = SKY_PHASES.get(phase, SKY_PHASES.noon)
	for index in 4:
		material.set_shader_parameter(["zenith", "horizon", "cloud", "shore"][index], Color(tones[index]))
	set_motion(material, reduced_motion)

## Small trim that is too thin to need a texture; may be translucent or glowing.
static func solid(color: Color, alpha := 1.0, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.86
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

## Material for every sculpted prop below.
static func sculpt_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	return material

## Ambient shadow where parts meet, and softer sun shadows.
static func dress_lighting(environment: Environment, sun: DirectionalLight3D) -> void:
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.4
	sun.shadow_blur = 1.6
	sun.shadow_opacity = 0.62

static func add(parent: Node3D, node_name: String, mesh: Mesh, material: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

## Pale lapping ring that sits a floating hull or crate into the water.
static func foam_ring_mesh(half_length: float, half_beam: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 14:
		var from := TAU * index / 14.0
		var to := TAU * (index + 1) / 14.0
		var inner_from := Vector3(cos(from) * half_length, 0, sin(from) * half_beam)
		var inner_to := Vector3(cos(to) * half_length, 0, sin(to) * half_beam)
		var grow := 1.0 + 0.16 * (1.0 + 0.5 * sin(index * 2.4))
		for vertex: Vector3 in [inner_from, inner_to * grow, inner_from * grow, inner_from, inner_to, inner_to * grow]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)
	return tool.commit()

static func foam_material() -> StandardMaterial3D:
	var material := solid(Color("#e6f4ec"), 0.62)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func _tones(tone: Color) -> Array[Color]:
	return [tone.lightened(0.16), tone, tone.darkened(0.14), tone.darkened(0.38)]

## Slatted cargo crate standing on y = `floor_y`: corner posts, three slats a
## side, a planked lid, a painted band in `band` and rope handles on two ends.
static func crate_mesh(size: Vector3, tone: Color, band := Color.TRANSPARENT, floor_y := 0.0) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	var shades := _tones(tone)
	var half := size * 0.5
	var lift := Vector3(0, floor_y, 0)
	var post := minf(size.x, size.z) * 0.13
	sculpt.box(lift + Vector3(0, half.y, 0), size - Vector3(post, post, post) * 1.2, shades[3])
	for index in 3:
		var slat: Color = band if band.a > 0.0 and index == 1 else shades[index % 2 + 1]
		sculpt.box(lift + Vector3(0, size.y * (0.2 + index * 0.3), 0), Vector3(size.x - post * 0.5, size.y * 0.24, size.z - post * 0.5), slat)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			sculpt.box(lift + Vector3(x * (half.x - post * 0.5), half.y, z * (half.z - post * 0.5)), Vector3(post, size.y, post), shades[0])
		for index in 3:
			sculpt.box(lift + Vector3(x * half.x, size.y * 0.62 - absf(index - 1.0) * size.y * 0.1, (index - 1.0) * size.z * 0.14), Vector3(post * 0.5, post * 0.5, size.z * 0.16), HEMP)
	for index in 3:
		sculpt.box(lift + Vector3((index - 1.0) * size.x * 0.32, size.y + post * 0.2, 0), Vector3(size.x * 0.29, post * 0.4, size.z), shades[0] if index != 1 else shades[1])
	return sculpt.mesh()

## Clinker boat hull, bow towards +X, floating with its keel just under y = 0:
## three overlapping strakes, a gunwale, a dark well, a stem post and, for an
## open boat, thwarts.
static func boat_mesh(length: float, beam: float, tone: Color, trim: Color, depth := 0.3, thwarts := true) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	var shades := _tones(tone)
	var plan := Basis.from_scale(Vector3(length * 0.5, 1.0, beam * 0.5))
	for strake in 3:
		var low := 0.62 + strake * 0.13
		sculpt.tube(Vector3(0, depth * (strake + 0.5) / 3.0, 0), low, low + 0.16, depth / 3.0 + 0.012, shades[2 - strake], 6, plan)
	sculpt.tube(Vector3(0, depth + 0.02, 0), 1.06, 1.06, 0.045, trim, 6, plan)
	sculpt.tube(Vector3(0, depth + 0.03, 0), 0.9, 0.9, 0.04, shades[3], 6, plan)
	for seat: float in ([-0.42, 0.0, 0.4] if thwarts else []):
		sculpt.box(Vector3(seat * length * 0.5, depth + 0.06, 0), Vector3(length * 0.07, 0.035, beam * (0.78 - absf(seat) * 0.5)), trim.darkened(0.12))
	sculpt.box(Vector3(length * 0.5, depth * 0.75, 0), Vector3(length * 0.05, depth * 1.1, beam * 0.07), trim)
	sculpt.box(Vector3(-length * 0.47, depth * 0.7, 0), Vector3(length * 0.04, depth * 0.9, beam * 0.3), shades[2])
	return sculpt.mesh()

## Channel buoy floating at y = 0: float collar, tapered striped body, cage and lamp.
static func buoy_mesh(radius: float, height: float, body: Color, band := Color("#f1ead6"), lamp := Color("#ffe08a")) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3(0, height * 0.06, 0), radius * 1.15, radius * 1.25, height * 0.16, body.darkened(0.3), 10)
	sculpt.tube(Vector3(0, height * 0.24, 0), radius * 1.1, radius * 0.86, height * 0.2, body, 10)
	sculpt.tube(Vector3(0, height * 0.42, 0), radius * 0.86, radius * 0.7, height * 0.16, band, 10)
	sculpt.tube(Vector3(0, height * 0.58, 0), radius * 0.7, radius * 0.52, height * 0.16, body.lightened(0.08), 10)
	for leg in 3:
		var around := TAU * leg / 3.0
		sculpt.box(Vector3(cos(around), 0, sin(around)) * radius * 0.36 + Vector3(0, height * 0.76, 0), Vector3(radius * 0.12, height * 0.24, radius * 0.12), body.darkened(0.4))
	sculpt.ball(Vector3(0, height * 0.93, 0), radius * 0.3, lamp, Color.TRANSPARENT, 6, 3)
	return sculpt.mesh()

## Triangular sail in the XY plane: luff up the mast at x = 0, foot running to
## -X. Sewn panels alternate two tones so the cloth never reads as one flat sheet.
static func sail_mesh(foot: float, height: float, tone: Color, stripe: Color) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	var panels := 5
	for panel in panels:
		var low := float(panel) / panels
		var high := float(panel + 1) / panels
		var color := tone if panel % 2 == 0 else stripe
		sculpt.sheet(Vector3(0, low * height, 0), Vector3(-foot * (1.0 - low), low * height, 0), Vector3(0, high * height, 0), color)
		if panel < panels - 1:
			sculpt.sheet(Vector3(-foot * (1.0 - low), low * height, 0), Vector3(-foot * (1.0 - high), high * height, 0), Vector3(0, high * height, 0), color)
	return sculpt.mesh()

## Drifting log along the X axis, half sunk at y = 0: bark, pale sawn ends, a stub.
static func log_mesh(length: float, radius: float, bark := Color("#6f5237")) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	var lying := Basis(Vector3.FORWARD, PI * 0.5)
	sculpt.tube(Vector3(0, radius * 0.3, 0), radius, radius * 0.9, length, bark, 7, lying)
	sculpt.tube(Vector3(-length * 0.5, radius * 0.3, 0), radius * 0.8, radius * 0.8, 0.03, Color("#d9b98a"), 7, lying)
	sculpt.tube(Vector3(length * 0.5, radius * 0.3, 0), radius * 0.72, radius * 0.72, 0.03, Color("#d9b98a"), 7, lying)
	sculpt.box(Vector3(length * 0.18, radius * 1.1, radius * 0.3), Vector3(radius * 0.5, radius * 0.9, radius * 0.5), bark.darkened(0.2), Basis(Vector3.RIGHT, 0.5))
	return sculpt.mesh()

## Weathered boulder sitting in water at y = 0, with a dark wet foot.
static func rock_mesh(radius: float, height: float, tone: Color) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3(0, height * 0.12, 0), radius * 1.08, radius, height * 0.24, tone.darkened(0.34), 7)
	sculpt.tube(Vector3(0.04 * radius, height * 0.46, 0), radius, radius * 0.78, height * 0.46, tone, 7)
	sculpt.tube(Vector3(0.12 * radius, height * 0.82, -0.08 * radius), radius * 0.74, radius * 0.4, height * 0.3, tone.lightened(0.14), 6)
	return sculpt.mesh()

## Mooring pile standing on y = 0: wet foot, timber shaft, rope turns and a pale cap.
static func pile_mesh(radius: float, height: float, tone := Color("#7a5c3c")) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3(0, height * 0.1, 0), radius * 1.05, radius, height * 0.2, tone.darkened(0.4), 7)
	sculpt.tube(Vector3(0, height * 0.52, 0), radius, radius * 0.92, height * 0.66, tone, 7)
	sculpt.tube(Vector3(0, height * 0.7, 0), radius * 1.18, radius * 1.18, height * 0.1, HEMP, 7)
	sculpt.tube(Vector3(0, height * 0.92, 0), radius * 1.1, radius * 0.8, height * 0.16, Color("#eadfbe"), 7)
	return sculpt.mesh()

## Upright canister centred on its middle (a mail tube, a float drum, a bell
## housing): rolled rims, two painted bands and a seam down the shady side.
static func canister_mesh(radius: float, height: float, body: Color, band: Color) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3.ZERO, radius, radius, height * 0.9, body, 8)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(0, side * height * 0.46, 0), radius * 1.1, radius * 1.1, height * 0.08, body.darkened(0.25), 8)
		sculpt.tube(Vector3(0, side * height * 0.22, 0), radius * 1.03, radius * 1.03, height * 0.12, band, 8)
	sculpt.box(Vector3(radius * 0.7, 0, radius * 0.7), Vector3(radius * 0.12, height * 0.8, radius * 0.12), body.darkened(0.35))
	return sculpt.mesh()

## Life ring lying flat on y = 0, in alternating painted segments with grab lines.
static func life_ring_mesh(radius: float, thickness: float, tone := Color("#ff6a3d"), stripe := Color("#f6efe0")) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	var segments := 12
	var chord := TAU * radius / segments * 1.12
	for index in segments:
		var around := TAU * (index + 0.5) / segments
		var basis := Basis(Vector3.UP, -around)
		sculpt.box(Vector3(cos(around), 0, sin(around)) * radius, Vector3(thickness, thickness * 0.8, chord), tone if (index / 3) % 2 == 0 else stripe, basis)
		if index % 3 == 1:
			sculpt.box(Vector3(cos(around), 0, sin(around)) * (radius + thickness * 0.5), Vector3(thickness * 0.2, thickness * 0.9, chord * 0.5), HEMP, basis)
	return sculpt.mesh()

## Seabird body facing +X, centred on its middle: a plump white body with a grey
## mantle, round head, dark eye, yellow beak and a forked tail.
static func gull_body_mesh(white := Color("#f4f1e8"), mantle := Color("#9aa7ab")) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.box(Vector3.ZERO, Vector3(0.8, 0.26, 0.28), white)
	sculpt.box(Vector3(-0.05, 0.11, 0), Vector3(0.62, 0.08, 0.3), mantle)
	sculpt.box(Vector3(0.0, -0.1, 0), Vector3(0.6, 0.08, 0.24), white.darkened(0.12))
	sculpt.ball(Vector3(0.46, 0.1, 0), 0.15, white, Color.TRANSPARENT, 8, 4)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(0.52, 0.14, side * 0.12), Vector3(0.05, 0.05, 0.03), Color("#22303a"))
	sculpt.box(Vector3(0.66, 0.07, 0), Vector3(0.2, 0.06, 0.07), Color("#f0b443"))
	sculpt.box(Vector3(0.74, 0.04, 0), Vector3(0.05, 0.05, 0.06), Color("#d9543f"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.52, 0.03, side * 0.07), Vector3(0.3, 0.05, 0.1), mantle.darkened(0.2), Basis(Vector3.UP, side * 0.35))
	return sculpt.mesh()

## Feather lying in the XY plane along +X: a pale shaft and a vane that tapers
## to the tip, darker on its lower barbs.
static func feather_mesh(length: float, tone := Color("#fff6d8")) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.box(Vector3.ZERO, Vector3(length, length * 0.04, length * 0.05), tone.darkened(0.25))
	for step in 5:
		var along := (step - 2.0) * length * 0.17
		var width := length * (0.3 - absf(step - 1.5) * 0.05)
		sculpt.box(Vector3(along, width * 0.25, 0), Vector3(length * 0.18, width * 0.5, length * 0.03), tone)
		sculpt.box(Vector3(along, -width * 0.2, 0), Vector3(length * 0.18, width * 0.4, length * 0.03), tone.darkened(0.12))
	return sculpt.mesh()

## Twig nest standing on y = 0 with two speckled eggs.
static func nest_mesh(radius: float) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3(0, radius * 0.12, 0), radius * 0.7, radius, radius * 0.24, Color("#8a6a3f"), 9)
	sculpt.tube(Vector3(0, radius * 0.33, 0), radius, radius * 0.95, radius * 0.18, Color("#b48a52"), 9)
	for twig in 6:
		var around := TAU * twig / 6.0 + 0.3
		sculpt.box(Vector3(cos(around), 0, sin(around)) * radius * 0.92 + Vector3(0, radius * 0.4, 0), Vector3(radius * 0.7, radius * 0.06, radius * 0.06), Color("#6f5237"), Basis(Vector3.UP, -around + 1.2))
	sculpt.tube(Vector3(0, radius * 0.34, 0), radius * 0.72, radius * 0.72, radius * 0.06, Color("#5c4630"), 9)
	sculpt.ball(Vector3(-radius * 0.22, radius * 0.48, 0), radius * 0.2, Color("#eef0e4"), Color("#d8dccb"), 6, 3, 1.25)
	sculpt.ball(Vector3(radius * 0.2, radius * 0.46, radius * 0.1), radius * 0.18, Color("#e8ecdf"), Color("#d2d8c6"), 6, 3, 1.25)
	return sculpt.mesh()
