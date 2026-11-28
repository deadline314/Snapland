extends RefCounted
## How an instant map game station looks: a chunky themed sign with the game's
## name, an emblem and three medal pips; in a district also a themed play floor
## with a soft edge and a few props around it. One theme row per region; every
## shape is built once when the station is built, repeated props in batches.

const Kit = preload("res://game/world/field/field_kit.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const CANDY_TILE := "res://game/world/candy_tile.gdshader"
const GARDEN_PAVING := "res://game/world/garden_paving.gdshader"

## The sign turns a little toward the camera, which sits off to the +x side.
const SIGN_YAW := 0.14
const POST_HEIGHT := 2.0
const BOARD_Y := 1.45
const BOARD_HEIGHT := 0.86
const CHAR_WIDTH := 0.58
const TITLE_SIZE := 38
const EMBLEM_RADIUS := 0.4
## The floor's top sits this far above the ground; game markers sit higher.
const PAD_LIFT := 0.03
const RIM_WIDTH := 0.24
const PAD_SIDES := 44
const PROPS_PER_STATION := 3
const PIP_OFF := Color("#56626a")

## Surface specs (see surface()): coastal atlas tile, wood, stone, painted,
## candy tile pattern, or greenhouse paving.
const THEMES := {
	"welcome": {
		"board": {"coastal": 1, "size": 0.9, "tint": Color("#f3e3c2")},
		"roof": {"coastal": 3, "size": 0.8, "tint": Color("#f0b49a")},
		"ink": Color("#fff6de"), "cap": Color("#f2c75a"), "bulb": Color("#ffd98a"),
	},
	"harbor": {
		"board": {"coastal": 1, "size": 0.9, "tint": Color("#e8d2aa")},
		"roof": {"coastal": 2, "size": 0.8, "tint": Color("#9cc4c0")},
		"ink": Color("#fff6de"), "cap": Color("#4b9b9c"), "bulb": Color("#ffe3a0"),
		"floor": {"coastal": 1, "size": 2.2, "tint": Color("#ead6b0")},
		"rim": {"wood": Color("#6e5238")},
		"props": ["crates", "barrel", "rope", "buoy"],
	},
	"candy": {
		"board": {"tile": [Color("#d9607e"), Color("#e2728e"), Color("#a8445e")], "pattern": 2, "size": 0.18},
		"roof": {"tile": [Color("#e0525a"), Color("#fff3ec"), Color("#b84650")], "pattern": 1, "size": 0.22},
		"ink": Color("#fff6de"), "cap": Color("#f49ab4"), "bulb": Color("#ffd1e0"),
		"floor": {"tile": [Color("#fff1e6"), Color("#f6b8c8"), Color("#c98c9a")], "pattern": 0, "size": 0.7},
		"rim": {"tile": [Color("#e0525a"), Color("#fff3ec"), Color("#b84650")], "pattern": 2, "size": 0.12},
		"props": ["jar", "lollipop", "gumdrops", "canes"],
	},
	"nightmarket": {
		"board": {"wood": Color("#7a3e32")},
		"roof": {"tile": [Color("#c9423a"), Color("#f2c75a"), Color("#7a2c26")], "pattern": 1, "size": 0.25},
		"ink": Color("#ffe39a"), "cap": Color("#e8674f"), "bulb": Color("#ff9a5a"),
		# A boarded stall floor framed by a raised timber edge, not a rug on the street (ART-82).
		"floor": {"coastal": 1, "size": 0.8, "tint": Color("#e0b07a")},
		"rim": {"wood": Color("#5e3a26")},
		"kerb": 0.16,
		"props": ["lanterns", "stools", "fruit"],
	},
	"circus": {
		"board": {"paint": Color("#9e2f3a")},
		"roof": {"tile": [Color("#f0dcc0"), Color("#d9454e"), Color("#8e2a34")], "pattern": 1, "size": 0.3},
		"ink": Color("#ffe39a"), "cap": Color("#f2c75a"), "bulb": Color("#ffe8a8"),
		"floor": {"tile": [Color("#a8343f"), Color("#9a2f3a"), Color("#6e2229")], "pattern": 0, "size": 0.5},
		"rim": {"coastal": 7, "size": 0.5, "tint": Color("#ffe0a0")},
		"props": ["stanchions", "drum", "ball"],
	},
	"toy": {
		"board": {"tile": [Color("#3f6fae"), Color("#4a7cbc"), Color("#2c4f80")], "pattern": 2, "size": 0.2},
		"roof": {"tile": [Color("#6fa3d8"), Color("#e8674f"), Color("#3a5a8a")], "pattern": 1, "size": 0.3},
		"ink": Color("#fff2b0"), "cap": Color("#e8674f"), "bulb": Color("#fff2b0"),
		"floor": {"tile": [Color("#86aed2"), Color("#e8cf86"), Color("#4c6f9a")], "pattern": 0, "size": 0.8},
		"rim": {"tile": [Color("#e8674f"), Color("#fff3ec"), Color("#a8443a")], "pattern": 2, "size": 0.2},
		"props": ["blocks", "tower", "ball"],
	},
	"garden": {
		"board": {"wood": Color("#8a6a48")},
		"roof": {"garden": 4, "tone": Color("#5f8f4e"), "moss": 0.1},
		"ink": Color("#fff6de"), "cap": Color("#9fd8c4"), "bulb": Color("#e8ffd0"),
		"floor": {"garden": 0, "tone": Color("#948f78"), "moss": 0.6},
		"rim": {"garden": 5, "tone": Color("#8c8572"), "moss": 0.4},
		"props": ["pot", "can", "pot", "stones"],
	},
	"cinema": {
		"board": {"paint": Color("#2a2238")},
		"roof": {"tile": [Color("#a8243a"), Color("#f2d6a0"), Color("#6e1626")], "pattern": 1, "size": 0.25},
		"ink": Color("#ffe39a"), "cap": Color("#e8b54f"), "bulb": Color("#ffe3a0"),
		"floor": {"coastal": 1, "size": 0.9, "tint": Color("#6a6070")},
		"rim": {"coastal": 7, "size": 0.5, "tint": Color("#ffe0a0")},
		"props": ["reels", "spot", "chair", "sandbags"],
	},
}

## Prop parts: [shape, surface, position, scale, colour]. "paint" takes the
## colour per instance; "glow" is the same but unlit (lanterns, bulbs).
const PROPS := {
	"crates": [
		["box", {"coastal": 1, "size": 0.7, "tint": Color("#d9c09a")}, Vector3(0, 0.3, 0), Vector3(0.62, 0.6, 0.62), Color.WHITE],
		["box", {"coastal": 1, "size": 0.7, "tint": Color("#c8ab84")}, Vector3(0.1, 0.82, 0.04), Vector3(0.46, 0.44, 0.46), Color.WHITE],
		["box", {"coastal": 1, "size": 0.7, "tint": Color("#d9c09a")}, Vector3(0.62, 0.22, 0.2), Vector3(0.44, 0.44, 0.44), Color.WHITE],
	],
	"barrel": [
		["cyl", {"wood": Color("#8a6a48")}, Vector3(0, 0.38, 0), Vector3(0.58, 0.76, 0.58), Color.WHITE],
		["cyl", "paint", Vector3(0, 0.17, 0), Vector3(0.61, 0.06, 0.61), Color("#4b3b2c")],
		["cyl", "paint", Vector3(0, 0.6, 0), Vector3(0.61, 0.06, 0.61), Color("#4b3b2c")],
	],
	"rope": [
		["torus", "paint", Vector3(0, 0.08, 0), Vector3(1.0, 1.1, 1.0), Color("#cdb48a")],
		["torus", "paint", Vector3(0.03, 0.22, 0), Vector3(0.82, 1.1, 0.82), Color("#bfa47a")],
	],
	"buoy": [
		["cyl", {"wood": Color("#7a5a3c")}, Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), Color.WHITE],
		["ring", "paint", Vector3(0, 0.72, 0.1), Vector3(0.9, 1.4, 0.9), Color("#e0525a")],
	],
	"jar": [
		["cyl", "glass", Vector3(0, 0.4, 0), Vector3(0.62, 0.8, 0.62), Color.WHITE],
		["ball", "paint", Vector3(-0.1, 0.16, 0.05), Vector3(0.26, 0.26, 0.26), Color("#f2c75a")],
		["ball", "paint", Vector3(0.12, 0.17, -0.06), Vector3(0.26, 0.26, 0.26), Color("#7fc4f2")],
		["ball", "paint", Vector3(0.02, 0.38, 0.0), Vector3(0.26, 0.26, 0.26), Color("#e0525a")],
		["cyl", "paint", Vector3(0, 0.84, 0), Vector3(0.66, 0.1, 0.66), Color("#f49ab4")],
		["ball", "paint", Vector3(0, 0.93, 0), Vector3(0.14, 0.14, 0.14), Color("#fff3ec")],
	],
	"lollipop": [
		["cyl", "paint", Vector3(0, 0.6, 0), Vector3(0.07, 1.2, 0.07), Color("#fff6ec")],
		["disc", "paint", Vector3(0, 1.4, 0), Vector3(0.84, 0.12, 0.84), Color("#ff8fb0")],
		["ring", "paint", Vector3(0, 1.4, 0.04), Vector3(0.52, 0.9, 0.52), Color("#fff3ec")],
	],
	"gumdrops": [
		["ball", "paint", Vector3(0, 0.12, 0), Vector3(0.5, 0.42, 0.5), Color("#9fd8c4")],
		["ball", "paint", Vector3(0.48, 0.1, 0.18), Vector3(0.42, 0.36, 0.42), Color("#f2c75a")],
		["ball", "paint", Vector3(0.2, 0.1, -0.4), Vector3(0.4, 0.34, 0.4), Color("#e59ab0")],
	],
	"canes": [
		["cyl", {"tile": [Color("#e0525a"), Color("#fff3ec"), Color("#b84650")], "pattern": 2, "size": 0.12}, Vector3(0, 0.55, 0), Vector3(0.16, 1.1, 0.16), Color.WHITE],
		["cyl", {"tile": [Color("#e0525a"), Color("#fff3ec"), Color("#b84650")], "pattern": 2, "size": 0.12}, Vector3(0.42, 0.4, 0.1), Vector3(0.14, 0.8, 0.14), Color.WHITE],
		["ball", "paint", Vector3(0, 1.12, 0), Vector3(0.2, 0.2, 0.2), Color("#fff3ec")],
	],
	"lanterns": [
		["cyl", {"wood": Color("#5a3e2c")}, Vector3(0, 1.0, 0), Vector3(0.12, 2.0, 0.12), Color.WHITE],
		["box", {"wood": Color("#5a3e2c")}, Vector3(0.34, 1.9, 0), Vector3(0.78, 0.08, 0.08), Color.WHITE],
		["ball", "glow", Vector3(0.6, 1.62, 0), Vector3(0.36, 0.44, 0.36), Color("#ff6a4a")],
		["ball", "glow", Vector3(0, 2.12, 0), Vector3(0.3, 0.36, 0.3), Color("#ffc25a")],
		["cyl", "paint", Vector3(0.6, 1.86, 0), Vector3(0.2, 0.05, 0.2), Color("#3a2a24")],
	],
	"stools": [
		["cyl", "paint", Vector3(0, 0.42, 0), Vector3(0.44, 0.08, 0.44), Color("#d9525e")],
		["cyl", {"wood": Color("#5a3e2c")}, Vector3(0, 0.2, 0), Vector3(0.12, 0.4, 0.12), Color.WHITE],
		["cyl", "paint", Vector3(0.62, 0.42, 0.2), Vector3(0.44, 0.08, 0.44), Color("#4b9b9c")],
		["cyl", {"wood": Color("#5a3e2c")}, Vector3(0.62, 0.2, 0.2), Vector3(0.12, 0.4, 0.12), Color.WHITE],
	],
	"fruit": [
		["box", {"coastal": 1, "size": 0.6, "tint": Color("#c8a074")}, Vector3(0, 0.18, 0), Vector3(0.72, 0.36, 0.5), Color.WHITE],
		["ball", "paint", Vector3(-0.18, 0.42, 0.05), Vector3(0.22, 0.22, 0.22), Color("#f29a3a")],
		["ball", "paint", Vector3(0.05, 0.43, -0.06), Vector3(0.22, 0.22, 0.22), Color("#f2b03a")],
		["ball", "paint", Vector3(0.2, 0.42, 0.08), Vector3(0.22, 0.22, 0.22), Color("#e0525a")],
	],
	"stanchions": [
		["cyl", "paint", Vector3(-0.7, 0.03, 0), Vector3(0.32, 0.06, 0.32), Color("#3a2a24")],
		["cyl", "paint", Vector3(0.7, 0.03, 0), Vector3(0.32, 0.06, 0.32), Color("#3a2a24")],
		["cyl", {"coastal": 7, "size": 0.4}, Vector3(-0.7, 0.48, 0), Vector3(0.1, 0.9, 0.1), Color.WHITE],
		["cyl", {"coastal": 7, "size": 0.4}, Vector3(0.7, 0.48, 0), Vector3(0.1, 0.9, 0.1), Color.WHITE],
		["ball", {"coastal": 7, "size": 0.4}, Vector3(-0.7, 0.96, 0), Vector3(0.16, 0.16, 0.16), Color.WHITE],
		["ball", {"coastal": 7, "size": 0.4}, Vector3(0.7, 0.96, 0), Vector3(0.16, 0.16, 0.16), Color.WHITE],
		["rope", "paint", Vector3(0, 0.84, 0), Vector3(1.4, 0.07, 0.07), Color("#9e2f3a")],
	],
	"drum": [
		["cyl", {"tile": [Color("#f0dcc0"), Color("#d9454e"), Color("#8e2a34")], "pattern": 1, "size": 0.18}, Vector3(0, 0.34, 0), Vector3(0.84, 0.68, 0.84), Color.WHITE],
		["cyl", {"coastal": 7, "size": 0.4}, Vector3(0, 0.7, 0), Vector3(0.9, 0.06, 0.9), Color.WHITE],
		["ball", "paint", Vector3(0, 0.86, 0), Vector3(0.3, 0.3, 0.3), Color("#7fc4f2")],
	],
	"ball": [
		["ball", {"tile": [Color("#f2c75a"), Color("#e8674f"), Color("#a8443a")], "pattern": 1, "size": 0.16}, Vector3(0, 0.34, 0), Vector3(0.68, 0.68, 0.68), Color.WHITE],
	],
	"blocks": [
		["box", "paint", Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color("#e8674f")],
		["box", "paint", Vector3(0.52, 0.22, 0.12), Vector3(0.44, 0.44, 0.44), Color("#6fa3d8")],
		["box", "paint", Vector3(0.24, 0.7, 0.04), Vector3(0.42, 0.42, 0.42), Color("#f2c75a")],
		["cone", "paint", Vector3(0.24, 1.08, 0.04), Vector3(0.44, 0.34, 0.44), Color("#7fbf6a")],
	],
	"tower": [
		["cyl", "paint", Vector3(0, 0.3, 0), Vector3(0.44, 0.6, 0.44), Color("#6fa3d8")],
		["box", "paint", Vector3(0, 0.75, 0), Vector3(0.5, 0.3, 0.5), Color("#f2c75a")],
		["cone", "paint", Vector3(0, 1.1, 0), Vector3(0.56, 0.4, 0.56), Color("#e8674f")],
	],
	"reels": [
		["cyl", "paint", Vector3(0, 0.05, 0), Vector3(0.66, 0.1, 0.66), Color("#9aa1ab")],
		["cyl", "paint", Vector3(0.04, 0.15, 0.02), Vector3(0.62, 0.1, 0.62), Color("#b8bec6")],
		["cyl", "paint", Vector3(0.02, 0.25, -0.02), Vector3(0.58, 0.1, 0.58), Color("#8d939d")],
		["disc", "paint", Vector3(0.62, 0.28, 0.1), Vector3(0.56, 0.08, 0.56), Color("#9aa1ab")],
		["cyl", "paint", Vector3(0.02, 0.31, -0.02), Vector3(0.16, 0.03, 0.16), Color("#e8b54f")],
	],
	"spot": [
		["cyl", "paint", Vector3(0, 0.04, 0), Vector3(0.5, 0.08, 0.5), Color("#3a3640")],
		["cyl", "paint", Vector3(0, 0.55, 0), Vector3(0.06, 1.0, 0.06), Color("#6d7380")],
		["cyl", "paint", Vector3(0, 1.12, 0.04), Vector3(0.36, 0.4, 0.36), Color("#2e2a33")],
		["ball", "glow", Vector3(0, 1.12, 0.22), Vector3(0.26, 0.26, 0.1), Color("#fff2c8")],
	],
	"chair": [
		["box", {"wood": Color("#6e4c32")}, Vector3(-0.22, 0.3, 0), Vector3(0.05, 0.6, 0.4), Color.WHITE],
		["box", {"wood": Color("#6e4c32")}, Vector3(0.22, 0.3, 0), Vector3(0.05, 0.6, 0.4), Color.WHITE],
		["box", "paint", Vector3(0, 0.46, 0), Vector3(0.46, 0.04, 0.36), Color("#2a2238")],
		["box", "paint", Vector3(0, 0.8, -0.17), Vector3(0.48, 0.26, 0.03), Color("#2a2238")],
		["box", "paint", Vector3(0, 0.8, -0.15), Vector3(0.34, 0.06, 0.01), Color("#fff1d6")],
	],
	"sandbags": [
		["ball", "paint", Vector3(0, 0.12, 0), Vector3(0.5, 0.26, 0.36), Color("#c9a873")],
		["ball", "paint", Vector3(0.44, 0.12, 0.06), Vector3(0.48, 0.26, 0.34), Color("#b8955e")],
		["ball", "paint", Vector3(0.22, 0.32, 0.02), Vector3(0.46, 0.24, 0.34), Color("#c9a873")],
	],
	"pot": [
		["pot", "paint", Vector3(0, 0.24, 0), Vector3(0.6, 0.48, 0.6), Color("#b8674a")],
		["ball", "paint", Vector3(0, 0.62, 0), Vector3(0.76, 0.56, 0.76), Color("#5f8f4e")],
		["ball", "paint", Vector3(0.18, 0.84, 0.12), Vector3(0.16, 0.16, 0.16), Color("#f49ab4")],
		["ball", "paint", Vector3(-0.16, 0.8, 0.18), Vector3(0.16, 0.16, 0.16), Color("#f2e27a")],
	],
	"can": [
		["cyl", "paint", Vector3(0, 0.2, 0), Vector3(0.36, 0.4, 0.36), Color("#6fa3a0")],
		["spout", "paint", Vector3(0.26, 0.34, 0), Vector3(0.06, 0.42, 0.06), Color("#6fa3a0")],
		["ring", "paint", Vector3(-0.04, 0.46, 0), Vector3(0.3, 0.5, 0.3), Color("#4c7a78")],
	],
	"stones": [
		["cyl", {"stone": Color("#a49c86")}, Vector3(0, 0.04, 0), Vector3(0.56, 0.08, 0.44), Color.WHITE],
		["cyl", {"stone": Color("#968e7a")}, Vector3(0.6, 0.04, 0.3), Vector3(0.46, 0.08, 0.38), Color.WHITE],
		["cyl", {"stone": Color("#a49c86")}, Vector3(0.1, 0.04, 0.66), Vector3(0.42, 0.08, 0.36), Color.WHITE],
	],
}


static func theme(region: String) -> Dictionary:
	return THEMES.get(region, THEMES.welcome)


## A material for a surface spec, cached in the world's material cache.
static func surface(world: Node3D, spec: Variant) -> Material:
	if spec is String:
		match spec:
			"glow": return _unlit(world)
			"glass": return Kit.clear_material(world, Color(0.86, 0.95, 1.0, 0.4), 0.05)
			_: return world._vertex_color_material("field-dress")
	var row: Dictionary = spec
	if row.has("coastal"):
		return world._coastal_surface(int(row.coastal), float(row.size), row.get("tint", Color.WHITE))
	if row.has("wood"):
		return world._wood_material(row.wood)
	if row.has("stone"):
		return world._stone_finish(row.stone)
	if row.has("paint"):
		return world._finish(row.paint, Vector3(4, 0.1, 4))
	var key := "field-dress:" + str(row)
	if world.material_cache.has(key):
		return world.material_cache[key]
	var path := CANDY_TILE if row.has("tile") else GARDEN_PAVING
	if not ResourceLoader.exists(path):
		push_warning("Field dressing shader %s is missing; using a painted surface." % path)
		return world._finish(Color("#c9b48a"), Vector3(4, 0.1, 4))
	var material := ShaderMaterial.new()
	material.shader = load(path)
	if row.has("tile"):
		material.set_shader_parameter("tone_a", row.tile[0])
		material.set_shader_parameter("tone_b", row.tile[1])
		material.set_shader_parameter("grout", row.tile[2])
		material.set_shader_parameter("pattern", int(row.pattern))
		material.set_shader_parameter("tile_size", float(row.size))
	else:
		material.set_shader_parameter("finish_style", int(row.garden))
		material.set_shader_parameter("finish_tone", row.tone)
		material.set_shader_parameter("moss", float(row.moss))
	world.material_cache[key] = material
	return material


static func _unlit(world: Node3D) -> StandardMaterial3D:
	const KEY := "field-dress:glow"
	if world.material_cache.has(KEY):
		return world.material_cache[KEY]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	world.material_cache[KEY] = material
	return material


# --- Sign ---

## The station sign at the stand: two posts (returned as ground points for one
## shared batch), a board with the game's name, a roof, an emblem with the
## game's glyph, three medal pips and a pennant. Fills record.pennant/pips.
static func build_sign(world: Node3D, parent: Node3D, record: Dictionary, region: String, pennant_mesh: Mesh, bulbs: Array[Transform3D]) -> Array[Vector3]:
	var row: Dictionary = record.row
	var look := theme(region)
	var ground: Vector3 = record.ground
	var title := String(row.title)
	var width := title.length() * CHAR_WIDTH + 0.6
	var sign := Node3D.new()
	sign.name = "Sign"
	sign.position = ground
	sign.rotation.y = SIGN_YAW
	parent.add_child(sign)
	var posts: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var foot := sign.transform * Vector3(side * (width * 0.5 - 0.16), 0, -0.1)
		posts.append(Vector3(foot.x, world.ground_surface_y(foot), foot.z))
	Kit.box(sign, Vector3(0, BOARD_Y, 0), Vector3(width, BOARD_HEIGHT, 0.12), surface(world, look.board))
	var roof := PrismMesh.new()
	roof.size = Vector3(width + 0.34, 0.32, 0.3)
	Kit.mesh(sign, roof, Vector3(0, BOARD_Y + BOARD_HEIGHT * 0.5 + 0.16, -0.02), surface(world, look.roof))
	var name_label := Kit.label(sign, title, Vector3(0, BOARD_Y + 0.08, 0.075), TITLE_SIZE, look.ink)
	_pin(name_label, look.ink)
	# The emblem: the game's colour and glyph on a round plaque above the roof.
	var emblem := Kit.cylinder(sign, Vector3(0, BOARD_Y + BOARD_HEIGHT * 0.5 + 0.42, 0.12), EMBLEM_RADIUS, 0.08, world._mat(row.color), -1.0, 18)
	emblem.rotation.x = PI * 0.5
	var rim := Kit.cylinder(sign, Vector3(0, BOARD_Y + BOARD_HEIGHT * 0.5 + 0.42, 0.1), EMBLEM_RADIUS + 0.06, 0.06, world._coastal_surface(Kit.TILE_BRASS, 0.4), -1.0, 18)
	rim.rotation.x = PI * 0.5
	var glyph := Kit.label(sign, String(row.glyph), Vector3(0, BOARD_Y + BOARD_HEIGHT * 0.5 + 0.42, 0.17), 40, Color("#fff6de"))
	_pin(glyph, Color("#fff6de"))
	var pip := SphereMesh.new()
	pip.radius = 0.075
	pip.height = 0.15
	pip.radial_segments = 8
	pip.rings = 4
	var spots: Array[Transform3D] = []
	for index in range(3):
		spots.append(Transform3D(Basis.IDENTITY, Vector3(-0.27 + index * 0.27, BOARD_Y - 0.3, 0.07)))
	var pips := Kit.batch(sign, pip, spots, world._vertex_color_material("field-pips"), [PIP_OFF])
	pips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	record["pips"] = pips.multimesh
	record["sign"] = sign
	record["sign_labels"] = [name_label, glyph]
	# Marquee bulbs along the roof edge keep the sign easy to find at night.
	var count := int(width / 0.36)
	for index in range(count + 1):
		var x := -width * 0.5 + width * index / float(count)
		bulbs.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.13), sign.transform * Vector3(x, BOARD_Y + BOARD_HEIGHT * 0.5 - 0.02, 0.1)))
	var flag_at: Vector3 = posts[1] + Vector3(0, POST_HEIGHT - 0.14, 0)
	record["pennant"] = Kit.mesh(parent, pennant_mesh, flag_at, world._coastal_surface(Kit.TILE_CANVAS, 0.6, row.color), false)
	return posts


## A fixed sign label: drawn on the board's face instead of facing the camera.
static func _pin(item: Label3D, color: Color) -> void:
	item.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	item.outline_modulate = color.darkened(0.82)
	item.outline_size = 9


static func build_bulbs(world: Node3D, parent: Node3D, bulbs: Array[Transform3D], region: String) -> void:
	if bulbs.is_empty():
		return
	var ball := SphereMesh.new()
	ball.radial_segments = 8
	ball.rings = 4
	ball.radius = 0.5
	ball.height = 1.0
	var lit := Kit.batch(parent, ball, bulbs, _unlit(world), [theme(region).bulb])
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- District floor and props ---

## A themed floor under each district station's play area, and props around it.
## `walkable` answers whether a ground point can be stood on.
static func build_grounds(world: Node3D, parent: Node3D, records: Array[Dictionary], region: String, walkable: Callable, avoid: Array[Vector3]) -> void:
	var look := theme(region)
	if not look.has("floor"):
		return
	var parts := {}
	for record: Dictionary in records:
		var row: Dictionary = record.row
		var centre: Vector3 = row.get("arena", row.at)
		var reach := 0.0
		for offset: Vector2 in row.get("layout", []):
			reach = maxf(reach, offset.length())
		var radius := clampf(reach + 1.2, 3.2, 4.4)
		var seed_value := hash(String(row.id))
		var radii := _outline(centre, radius, seed_value, walkable)
		var pad := MeshInstance3D.new()
		pad.name = "Floor"
		pad.mesh = _floor_mesh(world, centre, radii, surface(world, look.floor), surface(world, look.rim), float(look.get("kerb", 0.05)))
		pad.position = Vector3(centre.x, world.ground_surface_y(centre), centre.z)
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(pad)
		record["floor"] = pad
		# A soft darker ring where the floor meets the grass.
		var halo := Kit.blob(world, parent, Vector2.ONE * (radius + RIM_WIDTH) * 2.5)
		halo.name = "FloorHalo"
		halo.position = Vector3(centre.x, world.ground_surface_y(centre) + 0.012, centre.z)
		_place_props(world, parts, record, centre, radii, seed_value, look.props, walkable, avoid)
	for key: String in parts:
		var part: Dictionary = parts[key]
		Kit.batch(parent, part.mesh, part.transforms, part.material, part.colors)


## Radius of the floor at each of PAD_SIDES directions: a wobbly circle that
## pulls in wherever it would reach water or ground nobody can stand on.
static func _outline(centre: Vector3, radius: float, seed_value: int, walkable: Callable) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	var phase := float(seed_value % 1000) * 0.01
	for index in range(PAD_SIDES):
		var angle := TAU * index / PAD_SIDES
		var r := radius * (1.0 + 0.045 * sin(angle * 3.0 + phase) + 0.025 * sin(angle * 5.0 + phase * 2.3))
		var along := Vector3(cos(angle), 0, sin(angle))
		while r > 1.4 and not walkable.call(centre + along * (r + RIM_WIDTH + 0.2)):
			r -= 0.2
		radii.append(r)
	# Smooth once so a pulled-in stretch bends instead of notching.
	var smooth := PackedFloat32Array()
	for index in range(PAD_SIDES):
		smooth.append(minf(radii[index], (radii[posmod(index - 1, PAD_SIDES)] + radii[index] * 2.0 + radii[(index + 1) % PAD_SIDES]) * 0.25))
	return smooth


## Top (surface 0) and kerb (surface 1) of a floor following the ground.
## `kerb_height` is how far the edging stands above the floor; walkers stay on
## the floor itself, so a tall edge frames it without burying anyone's feet.
static func _floor_mesh(world: Node3D, centre: Vector3, radii: PackedFloat32Array, top: Material, kerb: Material, kerb_height := 0.05) -> ArrayMesh:
	var base: float = world.ground_surface_y(centre)
	var height := func(at: Vector3) -> float: return world.ground_surface_y(centre + at) - base
	var shape := ArrayMesh.new()
	var tops := SurfaceTool.new()
	tops.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rims := SurfaceTool.new()
	rims.begin(Mesh.PRIMITIVE_TRIANGLES)
	var middle := Vector3(0, PAD_LIFT, 0)
	# Kerb profile: inner lip, flat top, outer face sinking into the ground.
	var profile := [Vector2(0.0, 0.0), Vector2(0.0, kerb_height), Vector2(RIM_WIDTH, kerb_height), Vector2(RIM_WIDTH + 0.04, -0.08)]
	for index in range(PAD_SIDES):
		var next := (index + 1) % PAD_SIDES
		_triangle(tops, middle, _ring(index, radii[index], 0.0, 0.0, height), _ring(next, radii[next], 0.0, 0.0, height), Vector3.UP)
		var outward := Vector3(cos(TAU * (index + 0.5) / PAD_SIDES), 0, sin(TAU * (index + 0.5) / PAD_SIDES))
		var normals := [-outward, Vector3.UP, (outward + Vector3.UP * 0.3).normalized()]
		for step in range(3):
			var p0 := _ring(index, radii[index], profile[step].x, profile[step].y, height)
			var p1 := _ring(next, radii[next], profile[step].x, profile[step].y, height)
			var q0 := _ring(index, radii[index], profile[step + 1].x, profile[step + 1].y, height)
			var q1 := _ring(next, radii[next], profile[step + 1].x, profile[step + 1].y, height)
			_triangle(rims, p0, p1, q1, normals[step])
			_triangle(rims, p0, q1, q0, normals[step])
	tops.commit(shape)
	rims.commit(shape)
	shape.surface_set_material(0, top)
	shape.surface_set_material(1, kerb)
	return shape


## Godot draws clockwise faces: wind each triangle so it faces along `normal`.
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	var points := [a, b, c] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b]
	for point: Vector3 in points:
		tool.add_vertex(point)


static func _ring(index: int, radius: float, out: float, lift: float, height: Callable) -> Vector3:
	var angle := TAU * index / PAD_SIDES
	var at := Vector3(cos(angle) * (radius + out), 0, sin(angle) * (radius + out))
	at.y = float(height.call(at)) + PAD_LIFT + lift
	return at


## A few props just outside the floor, away from the sign, the water and
## every interaction point; parts of the same shape and surface share a batch.
static func _place_props(world: Node3D, parts: Dictionary, record: Dictionary, centre: Vector3, radii: PackedFloat32Array, seed_value: int, kinds: Array, walkable: Callable, avoid: Array[Vector3]) -> void:
	var at: Vector3 = record.row.at
	var sign_angle := atan2(at.z - centre.z, at.x - centre.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	var tries := [1.2, -1.3, 2.4, -2.5, 3.1, 0.75, -0.8, 1.8, -1.9]
	var start := rng.randi_range(0, kinds.size() - 1)
	for turn: float in tries:
		if placed >= PROPS_PER_STATION:
			break
		var angle := sign_angle + turn + rng.randf_range(-0.15, 0.15)
		var index := posmod(roundi(angle / TAU * PAD_SIDES), PAD_SIDES)
		var spot := centre + Vector3(cos(angle), 0, sin(angle)) * (radii[index] + RIM_WIDTH + 0.75)
		if not walkable.call(spot) or not walkable.call(spot + Vector3(cos(angle), 0, sin(angle)) * 0.8):
			continue
		var crowded := false
		for point in avoid:
			if Vector2(point.x - spot.x, point.z - spot.z).length() < 1.6:
				crowded = true
		if crowded:
			continue
		spot.y = world.ground_surface_y(spot)
		var kind := String(kinds[(start + placed) % kinds.size()])
		var turn_basis := Basis(Vector3.UP, rng.randf_range(-0.6, 0.6))
		for piece: Array in PROPS[kind]:
			_add_part(world, parts, piece, Transform3D(turn_basis, spot))
		avoid.append(spot)
		placed += 1


static func _add_part(world: Node3D, parts: Dictionary, piece: Array, frame: Transform3D) -> void:
	var shape := String(piece[0])
	var key := shape + "|" + str(piece[1])
	if not parts.has(key):
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		parts[key] = {"mesh": _unit(shape), "material": surface(world, piece[1]), "transforms": transforms, "colors": colors}
	var part: Dictionary = parts[key]
	var size: Vector3 = piece[3]
	var basis := frame.basis * _shape_basis(shape) * Basis.from_scale(size)
	part.transforms.append(Transform3D(basis, frame * (piece[2] as Vector3)))
	part.colors.append(piece[4])


## Shapes lying down get turned here so every table row stays upright-sized.
static func _shape_basis(shape: String) -> Basis:
	match shape:
		"ring", "disc": return Basis(Vector3.RIGHT, PI * 0.5)
		"rope": return Basis(Vector3.BACK, PI * 0.5)
		"spout": return Basis(Vector3.BACK, -0.9)
	return Basis.IDENTITY


static var _units := {}

static func _unit(shape: String) -> Mesh:
	if _units.has(shape):
		return _units[shape]
	var made: Mesh
	match shape:
		"box":
			made = BoxMesh.new()
		"ball":
			var ball := SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			ball.radial_segments = 12
			ball.rings = 6
			made = ball
		"torus", "ring":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.36
			ring.outer_radius = 0.5
			ring.rings = 16
			ring.ring_segments = 6
			made = ring
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 10
			cone.rings = 1
			made = cone
		"pot":
			var pot := CylinderMesh.new()
			pot.top_radius = 0.5
			pot.bottom_radius = 0.36
			pot.height = 1.0
			pot.radial_segments = 12
			pot.rings = 1
			made = pot
		_:
			var tube := CylinderMesh.new()
			tube.top_radius = 0.5
			tube.bottom_radius = 0.5
			tube.height = 1.0
			tube.radial_segments = 12 if shape != "rope" else 6
			tube.rings = 1
			made = tube
	_units[shape] = made
	return made
