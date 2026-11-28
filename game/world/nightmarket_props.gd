extends RefCounted
## Building blocks of the neon night market. Everything goes through the scenery
## kit: textured boxes batch per surface and trim merges into the shared detail
## mesh. Self-lit parts (neon tubes, bulbs, pixel emblems) merge into one glowing
## mesh, and hanging lanterns are one swaying batch.

const Kit := preload("res://game/world/scenery_kit.gd")
const NEON_GLOW := preload("res://game/world/neon_glow.gdshader")
const INK := Color("#292943")
const NIGHT := Color("#1b1a30")
const PLUM := Color("#584160")
const CORAL := Color("#ff937a")
const MINT := Color("#7df0db")
const PAPER := Color("#fff0cd")
const AMBER := Color("#ffc46b")
const ROSE := Color("#ff6f91")
const VIOLET := Color("#b79cff")
const EMBER := Color("#ff6a3a")
const IRON := Color("#3a3c52")
const DARK_WOOD := Color("#4f3a44")
const PALE_WOOD := Color("#b98d73")
const STEEL := Color("#9aa3b5")
const BRASS := Color("#c48f5c")
const LEAF := Color("#3f7a5e")
const BAMBOO := Color("#c9a56c")
const NEON_COLORS: Array[Color] = [CORAL, MINT, AMBER, ROSE, VIOLET]
const LANTERN_COLORS: Array[Color] = [Color("#ff7a5c"), Color("#ffb45e"), PAPER, Color("#ff6f91")]
## Signboard glyphs are this tall, so a board fits one line of text.
const SIGN_GLYPH := 0.52
const EMBLEM_CELL := 0.08
## Glyph pitch on a tall sign, top to bottom.
const TALL_LINE := 0.47
## Eight-by-eight pixel emblems, one per game. Letters pick the light colour.
const EMBLEM_COLORS := {"c": CORAL, "m": MINT, "p": PAPER, "y": AMBER, "r": ROSE, "v": VIOLET}
const EMBLEMS := {
	"umbrella": ["..cccc..", ".cccccc.", "cccccccc", "c..p..c.", "...p....", "...p....", "...p.p..", "....pp.."],
	"skewer": ["......p.", ".....rr.", "....rr..", "...yy...", "..rr....", ".yy.....", "p.......", "........"],
	"lantern": ["pppppppp", "...p....", "..rrrr..", ".rryyrr.", ".rryyrr.", "..rrrr..", "...y....", "...y...."],
	"coin": ["..yyyy..", ".yyyyyy.", "yyy..yyy", "yy....yy", "yy....yy", "yyy..yyy", ".yyyyyy.", "..yyyy.."],
	"scent": [".m...m..", "..m...m.", ".m...m..", "..m...m.", "........", "pppppppp", ".pppppp.", "..pppp.."],
	"banner": ["p.......", "pcccccc.", "pccpccc.", "pcccccc.", "pccc....", "p.......", "p.......", "p......."],
	"pancake": ["..yyyy..", ".yyyyyy.", "yyrrrryy", "yyr..ryy", "yyr.rryy", "yyrrryyy", ".yyyyyy.", "..yyyy.."],
	"parasol": ["...cc...", ".ppccpp.", ".ppccpp.", "ccccpccc", "cccpcccc", ".ppccpp.", ".ppccpp.", "...cc..."],
	"soup": ["..p..p..", ".p..p...", "..p..p..", "........", "rrrrrrrr", "ryyyyyyr", ".rrrrrr.", "..rrrr.."],
	"cart": ["........", ".mmmmmm.", ".mmmmmmp", ".mmmmmmp", "pppppppp", ".p....p.", "ppp..ppp", ".p....p."],
	"sugar": ["..yyyy..", ".y....y.", "y..yy..y", "y.y..y.y", "y.yy...y", ".y...yy.", "..yyy...", "...p...."],
	"stack": ["........", "...mm...", "..mmmm..", "..cccc..", ".cccccc.", ".pppppp.", "pppppppp", "pppppppp"],
}

var world: Node3D
var kit: Kit
## Everything that lights itself; committed by finish().
var neon := Kit.Sculpt.new()
var neon_material: ShaderMaterial
var lantern_material: ShaderMaterial
## Every signboard's text, so the boards read from across the market.
var sign_labels: Array[Label3D] = []
var _stacked: Array[Label3D] = []
var _lantern: ArrayMesh
var _parasol: ArrayMesh

func _init(owner: Node3D, scenery_kit: Kit) -> void:
	world = owner
	kit = scenery_kit
	neon_material = _glow_material("neon", 0.3, 0.0)
	lantern_material = _glow_material("lantern", 0.0, 0.1)

func _glow_material(key: String, flicker: float, sway: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = NEON_GLOW
	material.set_shader_parameter("flicker", flicker)
	material.set_shader_parameter("sway", sway)
	world.material_cache["nightmarket:" + key] = material
	world.component_motion.register_shader(material)
	return material

## Commits the glowing mesh. Call once, before the kit's finish().
func finish() -> void:
	if neon.is_empty(): return
	var signs: MeshInstance3D = world._mesh(neon.mesh(), Vector3.ZERO, neon_material)
	signs.name = "MarketNeon"
	signs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func wood(tint: Color) -> Material: return world._coastal_surface(1, 1.5, tint)
func canvas(tint: Color) -> Material: return world._coastal_surface(6, 1.15, tint)
func roof_tiles(tint: Color) -> Material: return world._coastal_surface(2, 1.5, tint)
func metal(tint: Color) -> Material: return world._coastal_surface(7, 1.3, tint)
func siding(tint: Color) -> Material: return world._coastal_surface(3, 1.6, tint)
func mosaic(tint: Color) -> Material: return world._coastal_surface(5, 1.4, tint)
func masonry(tint: Color) -> Material: return world._coastal_surface(4, 1.5, tint)

## Repeatable 0..1 value, so the market is identical on every visit.
static func scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)

## A tube that buzzes with its own rhythm; `seed_value` picks the rhythm.
static func buzzing(color: Color, seed_value: float) -> Color:
	return Color(color.r, color.g, color.b, 0.05 + 0.9 * scatter(seed_value))

## The 午夜移動市 gate: a gate that could roll away at midnight. Each post stands
## on a cart wheel, a clock above the beam sits at twelve, the name glows in
## neon and paper lanterns sway from the beam. `wide` is the clear span.
func rift_gate(at: Vector3, wide: float) -> Label3D:
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		var foot := at + Vector3(side * wide * 0.5, 0, 0)
		# A cart wheel under each post: rim, hub and spokes.
		detail.tube(foot + Vector3(0, 0.42, 0.0), 0.42, 0.42, 0.12, DARK_WOOD, 12, Basis(Vector3.RIGHT, PI * 0.5))
		detail.tube(foot + Vector3(0, 0.42, 0.07), 0.1, 0.1, 0.06, BRASS, 8, Basis(Vector3.RIGHT, PI * 0.5))
		for spoke in 4:
			detail.box(foot + Vector3(0, 0.42, 0.04), Vector3(0.05, 0.74, 0.03), PALE_WOOD, Basis(Vector3.BACK, spoke * PI * 0.25))
		detail.box(foot + Vector3(0, 2.1, -0.14), Vector3(0.22, 3.4, 0.22), DARK_WOOD)
		detail.box(foot + Vector3(0, 0.9, -0.14), Vector3(0.3, 0.1, 0.3), BRASS)
		neon.box(foot + Vector3(0, 2.1, -0.02), Vector3(0.05, 2.6, 0.03), buzzing(MINT if side < 0.0 else CORAL, side + 3.0))
		kit.blocker(foot + Vector3(0, 1.0, -0.14), Vector3(0.36, 2.0, 0.36))
	detail.box(at + Vector3(0, 3.82, -0.14), Vector3(wide + 0.8, 0.3, 0.34), DARK_WOOD.lightened(0.1))
	detail.box(at + Vector3(0, 3.98, -0.14), Vector3(wide + 1.0, 0.06, 0.42), BRASS)
	# The midnight clock on the beam: both hands up.
	detail.tube(at + Vector3(0, 4.42, -0.1), 0.38, 0.38, 0.1, PAPER, 14, Basis(Vector3.RIGHT, PI * 0.5))
	detail.tube(at + Vector3(0, 4.42, -0.12), 0.44, 0.44, 0.06, BRASS, 14, Basis(Vector3.RIGHT, PI * 0.5))
	detail.box(at + Vector3(0, 4.55, -0.03), Vector3(0.05, 0.26, 0.02), INK)
	detail.box(at + Vector3(0.02, 4.52, -0.02), Vector3(0.04, 0.2, 0.02), ROSE)
	# The name board, edged in neon.
	detail.box(at + Vector3(0, 3.36, -0.02), Vector3(wide - 0.3, 0.5, 0.08), NIGHT)
	for edge: float in [-1.0, 1.0]:
		neon.box(at + Vector3(0, 3.36 + edge * 0.27, 0.03), Vector3(wide - 0.2, 0.04, 0.03), buzzing(VIOLET, edge + 7.0))
	for i in 4:
		lantern(at + Vector3(-wide * 0.36 + i * wide * 0.24, 3.66, 0.12), LANTERN_COLORS[i % LANTERN_COLORS.size()], 0.8)
	var label: Label3D = world._local_label("午夜移動市", at + Vector3(0, 3.36, 0.08), 22)
	label.modulate = PAPER
	return label


## Paper lantern hanging from `hook`; it sways and dims when the market closes.
func lantern(hook: Vector3, color: Color, size := 1.0) -> void:
	var batch := kit.batch("lanterns", _lantern_mesh(), lantern_material)
	batch.add(hook, Vector3.ONE * size, Basis.IDENTITY, color)

func _lantern_mesh() -> Mesh:
	if _lantern != null: return _lantern
	var sculpt := Kit.Sculpt.new()
	var cap := Color(0.16, 0.14, 0.16)
	sculpt.box(Vector3(0, -0.07, 0), Vector3(0.025, 0.14, 0.025), cap)
	sculpt.tube(Vector3(0, -0.16, 0), 0.13, 0.11, 0.05, cap, 8)
	sculpt.tube(Vector3(0, -0.25, 0), 0.24, 0.15, 0.14, Color(0.92, 0.92, 0.92), 8)
	sculpt.tube(Vector3(0, -0.39, 0), 0.24, 0.24, 0.14, Color.WHITE, 8)
	sculpt.tube(Vector3(0, -0.53, 0), 0.15, 0.24, 0.14, Color(0.86, 0.86, 0.86), 8)
	sculpt.tube(Vector3(0, -0.62, 0), 0.11, 0.13, 0.05, cap, 8)
	sculpt.box(Vector3(0, -0.74, 0), Vector3(0.05, 0.2, 0.05), Color(0.75, 0.55, 0.3))
	_lantern = sculpt.mesh()
	return _lantern

## Oil-paper umbrella hanging open, seen mostly from above.
func parasol(top: Vector3, color: Color, size := 1.0, yaw := 0.0) -> void:
	if _parasol == null: _parasol = parasol_mesh(Color.WHITE, Color(0.78, 0.78, 0.8))
	kit.batch("parasols", _parasol, world._vertex_color_material("scenery-detail")).add(top, Vector3.ONE * size, Basis(Vector3.UP, yaw), color)

## Eight paper panels in two alternating tones, apex at the origin.
static func parasol_mesh(first: Color, second: Color) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for panel in range(8):
		var from := Basis(Vector3.UP, TAU * float(panel) / 8.0) * Vector3(0.62, -0.2, 0)
		var to := Basis(Vector3.UP, TAU * float(panel + 1) / 8.0) * Vector3(0.62, -0.2, 0)
		var shade := first if panel % 2 == 0 else second
		sculpt.sheet(Vector3.ZERO, to, from, shade)
		sculpt.box((from + to) * 0.5 + Vector3(0, -0.03, 0), Vector3(0.05, 0.05, 0.05), Color(0.3, 0.26, 0.26))
	sculpt.tube(Vector3(0, 0.03, 0), 0.05, 0.02, 0.1, Color(0.3, 0.26, 0.26), 6)
	sculpt.box(Vector3(0, -0.4, 0), Vector3(0.03, 0.8, 0.03), Color(0.4, 0.32, 0.28))
	return sculpt.mesh()

## Lights the eight-by-eight emblem `kind` on a board; `center` is its middle.
func emblem(kind: String, center: Vector3, cell := EMBLEM_CELL) -> void:
	var rows: Array = EMBLEMS.get(kind, [])
	for row in range(rows.size()):
		var line: String = rows[row]
		var column := 0
		while column < line.length():
			var letter := line[column]
			var run := 1
			while column + run < line.length() and line[column + run] == letter: run += 1
			if EMBLEM_COLORS.has(letter):
				neon.box(center + Vector3((float(column) + float(run) * 0.5 - 4.0) * cell, (3.5 - float(row)) * cell, 0), Vector3(float(run) * cell, cell, 0.03), EMBLEM_COLORS[letter])
			column += run

## Hanging signboard with a neon rim, an optional emblem and the label's text.
## `center` is the middle of the board; posts reach down to `ground_y` unless it
## is mounted on something (`ground_y` at or above the board).
func sign(text: String, center: Vector3, accent: Color, emblem_kind := "", ground_y := 0.2) -> Label3D:
	var icon := 0.74 if emblem_kind != "" else 0.0
	var width := maxf(1.5, float(text.length()) * SIGN_GLYPH + 0.5) + icon
	var detail := kit.detail
	detail.box(center, Vector3(width, 0.72, 0.1), NIGHT)
	var seed_value := center.x * 3.7 + center.z * 1.3
	for edge: float in [-1.0, 1.0]:
		neon.box(center + Vector3(0, edge * 0.38, 0.03), Vector3(width + 0.08, 0.05, 0.06), buzzing(accent, seed_value + edge))
		neon.box(center + Vector3(edge * (width * 0.5 + 0.02), 0, 0.03), Vector3(0.05, 0.76, 0.06), buzzing(accent, seed_value + edge))
	if ground_y < center.y - 0.4:
		for side: float in [-1.0, 1.0]:
			var post_top := center.y + 0.62
			detail.box(Vector3(center.x + side * (width * 0.5 - 0.12), (post_top + ground_y) * 0.5, center.z - 0.09), Vector3(0.07, post_top - ground_y, 0.07), IRON)
			detail.box(center + Vector3(side * (width * 0.5 - 0.12), 0.48, -0.03), Vector3(0.03, 0.24, 0.03), BRASS)
		detail.box(center + Vector3(0, 0.62, -0.09), Vector3(width + 0.1, 0.07, 0.09), IRON)
	if emblem_kind != "":
		emblem(emblem_kind, center + Vector3(-width * 0.5 + 0.4, 0, 0.06))
	var label: Label3D = world._label(text, center + Vector3(icon * 0.5, 0.02, 0.09), 29, PAPER)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.pixel_size = 0.018
	label.visibility_range_end = 0.0
	sign_labels.append(label)
	return label

## Tall signboard on a pole, read top to bottom: an optional emblem, then one glyph
## per line. It hides far less of the street behind it than a wide board. `foot`
## is where the pole stands and `clearance` how high the board's lower edge hangs.
func tall_sign(text: String, foot: Vector3, accent: Color, emblem_kind := "", clearance := 1.3) -> Label3D:
	var icon := 0.7 if emblem_kind != "" else 0.0
	var height := float(text.length()) * TALL_LINE + 0.22 + icon
	var center := foot + Vector3(0, clearance + height * 0.5, 0)
	var detail := kit.detail
	detail.box(center, Vector3(0.78, height, 0.1), NIGHT)
	detail.box(foot + Vector3(0, (clearance + height) * 0.5 + 0.08, -0.1), Vector3(0.09, clearance + height + 0.16, 0.09), IRON)
	detail.tube(foot + Vector3(0, 0.06, -0.1), 0.2, 0.14, 0.12, IRON.lightened(0.1), 6)
	var seed_value := foot.x * 3.7 + foot.z * 1.3
	for edge: float in [-1.0, 1.0]:
		neon.box(center + Vector3(edge * 0.41, 0, 0.03), Vector3(0.05, height + 0.08, 0.06), buzzing(accent, seed_value + edge))
		neon.box(center + Vector3(0, edge * (height * 0.5 + 0.02), 0.03), Vector3(0.86, 0.05, 0.06), buzzing(accent, seed_value + edge))
	if emblem_kind != "":
		emblem(emblem_kind, center + Vector3(0, height * 0.5 - 0.4, 0.06), 0.075)
	var label: Label3D = world._label(stacked(text), center + Vector3(0, -icon * 0.5, 0.09), 26, PAPER)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.pixel_size = 0.018
	label.visibility_range_end = 0.0
	sign_labels.append(label)
	_stacked.append(label)
	return label

## One glyph per line, for a tall sign.
static func stacked(text: String) -> String:
	return "\n".join(text.split(""))

## Tall signs keep an even glyph pitch whatever font the labels are given.
func fit_stacked_labels() -> void:
	for label in _stacked:
		var font := label.font if label.font != null else ThemeDB.fallback_font
		label.line_spacing = TALL_LINE / label.pixel_size - font.get_height(label.font_size)

## Strokes that read as a lit character from afar, inside a square of `size`.
func glyph(center: Vector3, size: float, color: Color, seed_value: float, basis := Basis.IDENTITY) -> void:
	var lit := buzzing(color, seed_value)
	var bar := size * 0.15
	for stroke in range(3 + int(scatter(seed_value + 5.0) * 2.0)):
		var pick := seed_value + float(stroke) * 3.3
		var length := size * (0.45 + 0.55 * scatter(pick + 1.0))
		var across := (scatter(pick + 2.0) - 0.5) * size * 0.8
		var along := (scatter(pick + 3.0) - 0.5) * (size - length)
		if scatter(pick) > 0.45:
			neon.box(center + basis * Vector3(along, across, 0), Vector3(length, bar, 0.04), lit, basis)
		else:
			neon.box(center + basis * Vector3(across, along, 0), Vector3(bar, length, 0.04), lit, basis)

## Push cart facing local +Z: wheels and a push handle, a plank body, a counter and
## a sloped striped awning with a patch. `top` picks what is on the counter.
func cart(frame: Transform3D, stripe: Color, top: String, variation := 0, roofed := true) -> void:
	var detail := kit.detail
	var bodies: Array[Color] = [Color("#9a7a86"), Color("#7f8fa8"), Color("#a88672")]
	kit.surface(wood(bodies[variation % 3])).add(frame * Vector3(0, 0.62, 0), Vector3(1.7, 0.56, 0.84), frame.basis)
	kit.surface(wood(Color("#d9b9a6"))).add(frame * Vector3(0, 0.93, 0.02), Vector3(1.86, 0.07, 0.98), frame.basis)
	detail.frame = frame
	detail.box(Vector3(0, 0.36, 0), Vector3(1.76, 0.06, 0.9), DARK_WOOD)
	var wheel_turn := Basis(Vector3.RIGHT, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		detail.tube(Vector3(-0.45, 0.3, side * 0.48), 0.3, 0.3, 0.07, IRON, 10, wheel_turn)
		detail.tube(Vector3(-0.45, 0.3, side * 0.5), 0.1, 0.1, 0.09, BRASS, 6, wheel_turn)
		detail.box(Vector3(0.7, 0.17, side * 0.34), Vector3(0.07, 0.34, 0.07), DARK_WOOD)
		detail.box(Vector3(1.05, 0.84, side * 0.34), Vector3(0.4, 0.05, 0.05), DARK_WOOD)
	detail.box(Vector3(1.24, 0.84, 0), Vector3(0.05, 0.05, 0.74), BRASS)
	if roofed:
		var tilt := Basis(Vector3.RIGHT, 0.3)
		for x: float in [-0.88, 0.88]:
			detail.box(Vector3(x, 1.56, -0.4), Vector3(0.06, 1.2, 0.06), DARK_WOOD)
			detail.box(Vector3(x, 1.44, 0.42), Vector3(0.06, 0.97, 0.06), DARK_WOOD)
		var cloth := Vector3(0, 2.02, 0.22)
		kit.surface(canvas(stripe)).add(frame * cloth, Vector3(2.3, 0.05, 1.7), frame.basis * tilt)
		# A mended corner and a scalloped front edge.
		detail.box(cloth + tilt * Vector3(0.55 - 1.1 * float(variation % 2), 0.035, 0.25), Vector3(0.42, 0.02, 0.34), stripe.lerp(PAPER, 0.5), tilt)
		for scallop in range(8):
			detail.box(cloth + tilt * Vector3(-1.01 + 0.29 * float(scallop), -0.1, 0.86), Vector3(0.27, 0.2 if scallop % 2 == 0 else 0.14, 0.03), PAPER if scallop % 2 == 0 else stripe.darkened(0.25))
	_cart_top(top, variation)
	detail.frame = Transform3D.IDENTITY
	if roofed:
		lantern(frame * Vector3(-1.02, 1.74, 0.98), LANTERN_COLORS[variation % LANTERN_COLORS.size()], 0.8)
	# The loading-lane cart stands in the walkway between two streets, where
	# visitors have always been able to pass.
	if top != "cargo":
		kit.blocker(frame * Vector3(0, 0.95, 0), Vector3(1.8, 1.9, 0.9), frame.basis.get_euler().y)

## Wares on a cart counter (its top is 0.965 m up); `kit.detail.frame` is the cart.
func _cart_top(top: String, variation: int) -> void:
	var detail := kit.detail
	var frame := detail.frame
	neon.frame = frame
	match top:
		"pot":
			detail.tube(Vector3(-0.42, 1.15, 0), 0.27, 0.31, 0.36, STEEL, 10)
			detail.tube(Vector3(-0.42, 1.32, 0), 0.26, 0.26, 0.03, Color("#d9a15c"), 10)
			detail.box(Vector3(-0.2, 1.42, 0.05), Vector3(0.05, 0.3, 0.05), BRASS, Basis(Vector3.BACK, -0.5))
			for bowl in range(3):
				bowl(Vector3(0.22 + 0.27 * float(bowl), 0.965, 0.1 - 0.12 * float(bowl % 2)), [Color("#d4c4a8"), Color("#7cb49b"), Color("#c97057")][bowl])
		"steamer":
			for stack in range(2):
				for tier in range(4 - stack * 2):
					var at := Vector3(-0.42 + 0.72 * float(stack), 1.04 + 0.15 * float(tier), 0.02)
					detail.tube(at, 0.3, 0.3, 0.13, BAMBOO if tier % 2 == 0 else BAMBOO.darkened(0.12), 10)
					detail.tube(at + Vector3(0, 0.075, 0), 0.31, 0.31, 0.03, Color("#7d5a3c"), 10)
			detail.tube(Vector3(0.3, 1.38, 0.02), 0.3, 0.08, 0.1, BAMBOO.lightened(0.1), 10)
			bowl(Vector3(0.75, 0.965, -0.2), PAPER)
		"grill", "spit":
			detail.box(Vector3(-0.15, 1.04, 0), Vector3(1.2, 0.16, 0.6), IRON)
			for coal in range(6):
				neon.box(Vector3(-0.65 + 0.2 * float(coal), 1.125, 0.02 * float(coal % 2)), Vector3(0.15, 0.03, 0.44), buzzing(EMBER if coal % 2 == 0 else AMBER.darkened(0.1), float(coal) + frame.origin.z))
			if top == "grill":
				for skewer in range(5):
					detail.box(Vector3(-0.6 + 0.22 * float(skewer), 1.17, 0.04), Vector3(0.035, 0.03, 0.8), BAMBOO)
					detail.box(Vector3(-0.6 + 0.22 * float(skewer), 1.19, -0.02), Vector3(0.08, 0.05, 0.36), Color("#a8553c") if skewer % 2 == 0 else Color("#c98a4a"))
			else:
				for side: float in [-1.0, 1.0]:
					detail.box(Vector3(-0.15 + side * 0.56, 1.34, 0), Vector3(0.06, 0.46, 0.06), IRON)
			detail.tube(Vector3(0.72, 1.03, 0.2), 0.1, 0.08, 0.14, Color("#8a3b3b"), 8)
			detail.tube(Vector3(0.72, 1.03, -0.15), 0.1, 0.08, 0.14, Color("#3b6a5a"), 8)
		"griddle":
			detail.tube(Vector3(-0.3, 1.01, 0.02), 0.4, 0.36, 0.09, IRON, 12)
			detail.tube(Vector3(-0.3, 1.065, 0.02), 0.29, 0.29, 0.025, Color("#e2b266"), 12)
			neon.tube(Vector3(-0.3, 0.955, 0.02), 0.42, 0.42, 0.02, buzzing(EMBER, frame.origin.x), 12)
			for jar in range(3):
				detail.tube(Vector3(0.36 + 0.24 * float(jar), 1.06, -0.2 + 0.2 * float(jar % 2)), 0.09, 0.09, 0.2, [MINT, PAPER, CORAL][jar].darkened(0.25), 8)
			detail.box(Vector3(0.2, 1.1, 0.25), Vector3(0.44, 0.03, 0.05), BRASS, Basis(Vector3.UP, 0.5))
		"jars":
			for jar in range(5):
				var at := Vector3(-0.62 + 0.31 * float(jar), 1.07, -0.08 + 0.12 * float(jar % 2))
				detail.tube(at, 0.11, 0.09, 0.22, [Color("#5a8f7f"), Color("#b58a5c"), Color("#8a6aa8"), Color("#b5645c"), Color("#5c7fa8")][jar], 8)
				detail.tube(at + Vector3(0, 0.13, 0), 0.08, 0.1, 0.05, PAPER.darkened(0.2), 8)
			neon.box(Vector3(0, 1.0, 0.36), Vector3(0.08, 0.06, 0.08), buzzing(EMBER, frame.origin.x))
		"parcels":
			for parcel in range(4):
				var column := float(parcel % 3)
				detail.box(Vector3(-0.5 + 0.48 * column, 1.12 + 0.3 * float(parcel / 3), 0.02), Vector3(0.4, 0.3, 0.5), [Color("#cb976b"), Color("#5aa899"), Color("#c87372")][parcel % 3])
				detail.box(Vector3(-0.5 + 0.48 * column, 1.275 + 0.3 * float(parcel / 3), 0.02), Vector3(0.42, 0.03, 0.12), PAPER.darkened(0.15))
		"wok":
			detail.tube(Vector3(-0.3, 1.08, 0), 0.2, 0.42, 0.2, IRON, 12)
			detail.tube(Vector3(-0.3, 1.165, 0), 0.34, 0.34, 0.02, Color("#d8a24e"), 12)
			neon.tube(Vector3(-0.3, 0.99, 0), 0.26, 0.2, 0.05, buzzing(EMBER, frame.origin.z), 8)
			detail.box(Vector3(0.1, 1.2, 0.1), Vector3(0.5, 0.04, 0.05), BRASS, Basis(Vector3.UP, -0.4))
			for plate in range(2):
				detail.tube(Vector3(0.5 + 0.3 * float(plate), 1.0, 0.12), 0.1, 0.14, 0.05, PAPER, 8)
		"urn":
			detail.tube(Vector3(-0.5, 1.22, 0), 0.24, 0.26, 0.5, BRASS, 10)
			detail.tube(Vector3(-0.5, 1.53, 0), 0.25, 0.05, 0.14, BRASS.darkened(0.2), 10)
			for bottle in range(5):
				var at := Vector3(-0.05 + 0.2 * float(bottle), 1.1, -0.12)
				detail.tube(at, 0.06, 0.06, 0.26, [Color("#6fae8a"), Color("#c8804a"), Color("#8f6fb5")][bottle % 3], 6)
				detail.tube(at + Vector3(0, 0.17, 0), 0.05, 0.025, 0.1, PAPER.darkened(0.3), 6)
			for cup in range(3):
				detail.tube(Vector3(0.1 + 0.25 * float(cup), 1.02, 0.25), 0.055, 0.07, 0.11, PAPER, 6)
		"sugar":
			detail.box(Vector3(-0.2, 0.98, 0.05), Vector3(1.1, 0.03, 0.6), BRASS)
			for stick in range(4):
				detail.box(Vector3(-0.6 + 0.3 * float(stick), 1.2, -0.28), Vector3(0.025, 0.46, 0.025), BAMBOO)
				neon.tube(Vector3(-0.6 + 0.3 * float(stick), 1.46, -0.28), 0.1, 0.1, 0.03, AMBER, 6, Basis(Vector3.RIGHT, PI * 0.5))
			detail.tube(Vector3(0.66, 1.05, 0.05), 0.13, 0.11, 0.16, BRASS.darkened(0.25), 8)
		"coins":
			detail.box(Vector3(0, 0.975, 0), Vector3(1.6, 0.03, 0.8), Color("#425e67"))
			for dish in range(3):
				detail.tube(Vector3(-0.5 + 0.5 * float(dish), 1.01, -0.18), 0.15, 0.13, 0.05, BRASS, 8)
				detail.tube(Vector3(-0.5 + 0.5 * float(dish), 1.04, -0.18), 0.1, 0.1, 0.012, NIGHT, 8)
			for rail: float in [-1.0, 1.0]:
				neon.box(Vector3(rail * 0.36, 1.03, 0.22), Vector3(0.5, 0.06, 0.05), MINT if rail < 0.0 else CORAL, Basis(Vector3.UP, rail * -0.5))
		"cargo":
			for crate in range(4):
				var layer := float(crate / 2)
				detail.box(Vector3(-0.42 + 0.84 * float(crate % 2) * (1.0 - 0.5 * layer), 1.2 + 0.46 * layer, 0.04 * float(crate)), Vector3(0.74 - 0.1 * layer, 0.44, 0.7), [Color("#a5805c"), Color("#6d7f8f"), Color("#8d6a5c"), Color("#5aa899")][crate], Basis(Vector3.UP, 0.08 * float(crate)))
				detail.box(Vector3(-0.42 + 0.84 * float(crate % 2) * (1.0 - 0.5 * layer), 1.2 + 0.46 * layer, 0.04 * float(crate)), Vector3(0.78 - 0.1 * layer, 0.06, 0.74), DARK_WOOD, Basis(Vector3.UP, 0.08 * float(crate)))
		"nest":
			for shell in range(4):
				detail.box(Vector3(-0.35, 1.06 + 0.17 * float(shell), 0), Vector3(0.9 - 0.16 * float(shell), 0.16, 0.7 - 0.12 * float(shell)), [Color("#9c7258"), Color("#577f77"), Color("#b98d73"), Color("#8a6aa8")][shell])
			detail.tube(Vector3(0.52, 1.1, 0.02), 0.2, 0.26, 0.26, Color("#c39273"), 10)
			detail.tube(Vector3(0.52, 1.28, 0.02), 0.17, 0.22, 0.12, STEEL, 10)
			detail.tube(Vector3(-0.2, 1.8, 0.2), 0.09, 0.09, 1.5, Color("#c8584f"), 8, Basis(Vector3.BACK, PI * 0.5))
	neon.frame = Transform3D.IDENTITY

func bowl(at: Vector3, glaze: Color) -> void:
	kit.detail.tube(at + Vector3(0, 0.05, 0), 0.1, 0.16, 0.1, glaze, 8)
	kit.detail.tube(at + Vector3(0, 0.1, 0), 0.13, 0.13, 0.012, Color("#d9a15c"), 8)

## Plastic stool, the kind every stall keeps a stack of.
func stool(at: Vector3, color: Color) -> void:
	kit.detail.tube(at + Vector3(0, 0.2, 0), 0.2, 0.15, 0.4, color.darkened(0.2), 6)
	kit.detail.tube(at + Vector3(0, 0.42, 0), 0.19, 0.19, 0.05, color, 6)

## Folding table with bowls, ringed by stools.
func dining_set(at: Vector3, yaw: float, variation: int) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.surface(metal(Color("#b9c2d6"))).add(detail.frame * Vector3(0, 0.58, 0), Vector3(1.1, 0.05, 0.7), detail.frame.basis)
	for x: float in [-0.46, 0.46]:
		for z: float in [-0.28, 0.28]:
			detail.box(Vector3(x, 0.29, z), Vector3(0.04, 0.58, 0.04), IRON)
	bowl(Vector3(-0.25, 0.605, 0.08), PAPER)
	bowl(Vector3(0.28, 0.605, -0.1), Color("#7cb49b"))
	detail.tube(Vector3(0.02, 0.67, 0.2), 0.05, 0.05, 0.13, Color("#c8553c"), 6)
	var seats: Array[Color] = [Color("#d0584f"), Color("#4f8fc0"), Color("#d0584f"), Color("#e0b04f")]
	for seat in range(3 + variation % 2):
		var around := Vector3([-0.4, 0.4, -0.35, 0.45][seat], 0, [0.62, 0.6, -0.62, -0.58][seat])
		detail.tube(around + Vector3(0, 0.2, 0), 0.2, 0.15, 0.4, seats[(seat + variation) % 4].darkened(0.2), 6)
		detail.tube(around + Vector3(0, 0.42, 0), 0.19, 0.19, 0.05, seats[(seat + variation) % 4], 6)
	detail.frame = Transform3D.IDENTITY

## Stacked crates with a sack or a gas bottle beside them.
func crates(at: Vector3, yaw: float, variation: int) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	var woods: Array[Color] = [Color("#8d6a5c"), Color("#6d7f8f"), Color("#a5805c")]
	for crate in range(2 + variation % 2):
		var corner := Vector3(-0.28 + 0.58 * float(crate % 2), 0.24 + 0.48 * float(crate >> 1), 0.06 * float(crate))
		var turn := Basis(Vector3.UP, 0.18 * float(crate))
		detail.box(corner, Vector3(0.5, 0.46, 0.5), woods[(crate + variation) % 3], turn)
		detail.box(corner + Vector3(0, 0.24, 0), Vector3(0.54, 0.04, 0.54), DARK_WOOD, turn)
		detail.box(corner, Vector3(0.53, 0.06, 0.53), DARK_WOOD, turn)
	if variation % 2 == 0:
		detail.tube(Vector3(0.1, 0.3, 0.62), 0.17, 0.17, 0.6, Color("#5f86a8"), 8)
		detail.tube(Vector3(0.1, 0.65, 0.62), 0.12, 0.07, 0.1, STEEL, 8)
	else:
		detail.tube(Vector3(0.0, 0.2, 0.6), 0.26, 0.2, 0.4, Color("#b9a58a"), 7)
	detail.frame = Transform3D.IDENTITY

## Glazed pot with a leafy plant; `size` scales the whole thing.
func potted_plant(at: Vector3, size: float, variation: int) -> void:
	var detail := kit.detail
	var glaze: Color = [Color("#7a4f5c"), Color("#4f6f8a"), Color("#8a6a4a")][variation % 3]
	detail.tube(at + Vector3(0, 0.16 * size, 0), 0.16 * size, 0.22 * size, 0.32 * size, glaze, 8)
	detail.tube(at + Vector3(0, 0.33 * size, 0), 0.24 * size, 0.24 * size, 0.04 * size, glaze.lightened(0.15), 8)
	for leaf in range(5):
		var turn := Basis(Vector3.UP, TAU * float(leaf) / 5.0 + float(variation))
		var lean := turn * Basis(Vector3.BACK, 0.45 + 0.2 * float(leaf % 2))
		detail.box(at + Vector3(0, 0.36 * size, 0) + lean * Vector3(0, 0.3 * size, 0), Vector3(0.16 * size, 0.6 * size, 0.04), LEAF if leaf % 2 == 0 else LEAF.lightened(0.14), lean)
	detail.box(at + Vector3(0, 0.66 * size, 0), Vector3(0.14 * size, 0.6 * size, 0.14 * size), LEAF.darkened(0.1))

## Parked scooter; local +X is forward.
func scooter(at: Vector3, yaw: float, paint: Color) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	var wheel_turn := Basis(Vector3.RIGHT, PI * 0.5)
	for wheel: float in [-0.55, 0.55]:
		detail.tube(Vector3(wheel, 0.2, 0), 0.2, 0.2, 0.1, NIGHT, 8, wheel_turn)
	detail.box(Vector3(-0.2, 0.42, 0), Vector3(0.8, 0.26, 0.3), paint)
	detail.box(Vector3(-0.3, 0.6, 0), Vector3(0.62, 0.1, 0.28), NIGHT)
	detail.box(Vector3(0.42, 0.62, 0), Vector3(0.1, 0.72, 0.34), paint.lightened(0.1), Basis(Vector3.BACK, -0.25))
	detail.box(Vector3(0.52, 1.0, 0), Vector3(0.06, 0.06, 0.6), IRON)
	detail.box(Vector3(-0.66, 0.68, 0), Vector3(0.3, 0.26, 0.3), Color("#3b5a6a"))
	neon.box(detail.frame * Vector3(0.6, 0.86, 0), Vector3(0.05, 0.12, 0.14), PAPER, detail.frame.basis)
	neon.box(detail.frame * Vector3(-0.83, 0.5, 0), Vector3(0.04, 0.07, 0.16), ROSE, detail.frame.basis)
	detail.frame = Transform3D.IDENTITY

## Cast-iron drain grate set into the paving.
func grate(at: Vector3, along_x: bool) -> void:
	var turn := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
	kit.detail.box(at, Vector3(1.0, 0.012, 0.42), Color("#14131f"), turn)
	for bar in range(6):
		kit.detail.box(at + turn * Vector3(-0.42 + 0.168 * float(bar), 0.006, 0), Vector3(0.05, 0.02, 0.42), IRON.lightened(0.12), turn)
	for edge: float in [-1.0, 1.0]:
		kit.detail.box(at + turn * Vector3(0, 0.006, edge * 0.21), Vector3(1.04, 0.022, 0.05), IRON.lightened(0.12), turn)

## Wire sagging between two points.
func wire(from: Vector3, to: Vector3, sag: float, color := Color("#17161f"), thickness := 0.035) -> void:
	const SPANS := 6
	var previous := from
	for index in range(1, SPANS + 1):
		var along := float(index) / float(SPANS)
		var point := from.lerp(to, along) - Vector3(0, sag * 4.0 * along * (1.0 - along), 0)
		var span := point - previous
		kit.detail.box((previous + point) * 0.5, Vector3(thickness, thickness, span.length()), color, Basis.looking_at(span.normalized()))
		previous = point

## A string of coloured bulbs.
func bulb_string(from: Vector3, to: Vector3, sag := 0.4, colors: Array[Color] = [PAPER, CORAL, AMBER, MINT]) -> void:
	wire(from, to, sag, Color("#2b2836"), 0.025)
	var count := maxi(3, int(from.distance_to(to) / 0.55))
	for index in range(count):
		var along := (float(index) + 0.5) / float(count)
		var point := from.lerp(to, along) - Vector3(0, sag * 4.0 * along * (1.0 - along) + 0.07, 0)
		var color := colors[index % colors.size()]
		# One bulb in three twinkles.
		neon.box(point, Vector3(0.11, 0.13, 0.11), buzzing(color, point.x * 5.1 + point.z) if index % 3 == 1 else color)

## Timber utility pole with a crossarm, insulators and a drum transformer.
func utility_pole(ground: Vector3, height := 6.2, transformer := true) -> Vector3:
	var detail := kit.detail
	kit.piles().add(ground + Vector3(0, height * 0.5, 0), Vector3(0.22, height, 0.22))
	detail.box(ground + Vector3(0, height - 0.5, 0), Vector3(1.5, 0.09, 0.09), DARK_WOOD.darkened(0.2))
	detail.box(ground + Vector3(0, height - 1.1, 0), Vector3(1.0, 0.08, 0.08), DARK_WOOD.darkened(0.2))
	for insulator: float in [-0.65, 0.0, 0.65]:
		detail.tube(ground + Vector3(insulator, height - 0.4, 0), 0.05, 0.05, 0.12, Color("#c9d2d9"), 6)
	if transformer:
		detail.tube(ground + Vector3(0.32, height - 1.8, 0), 0.24, 0.24, 0.7, Color("#5c6577"), 8)
		detail.tube(ground + Vector3(0.32, height - 1.42, 0), 0.26, 0.26, 0.06, Color("#3f4656"), 8)
	return ground + Vector3(0, height - 0.4, 0)

## Shop-house filling `rect` (x, z). `front` is the street side: "S", "E" or "W".
## Gabled houses turn their ridge along the street; flat roofs carry a water tank.
func shophouse(rect: Rect2, ground_y: float, height: float, front: String, style: int, dressed := true) -> void:
	var detail := kit.detail
	var center := rect.get_center()
	var seed_value := center.x * 1.7 + center.y * 2.9
	var walls: Array[Material] = [siding(Color("#8f7aa6")), mosaic(Color("#8aa0b8")), masonry(Color("#8a7f9c")), siding(Color("#6f93a0")), masonry(Color("#a08a94"))]
	var wall := kit.surface(walls[style % walls.size()])
	wall.add(Vector3(center.x, ground_y + height * 0.5, center.y), Vector3(rect.size.x, height, rect.size.y))
	detail.box(Vector3(center.x, ground_y + 0.15, center.y), Vector3(rect.size.x + 0.14, 0.3, rect.size.y + 0.14), Color("#3b3550"))
	var top := ground_y + height
	if style % 3 == 2:
		_flat_roof(rect, top, seed_value)
	else:
		_gable_roof(rect, top, front == "S", style, wall)
	# Lit windows on the wall the camera faces.
	var south := Vector3(center.x, ground_y, rect.end.y)
	var floors := maxi(1, int((height - 0.5) / 2.2))
	var columns := maxi(1, int(rect.size.x / 1.9))
	for floor_index in range(1 if front == "S" else 0, floors):
		for column in range(columns):
			var at := south + Vector3((float(column) + 0.5) / float(columns) * rect.size.x - rect.size.x * 0.5, 1.5 + 2.2 * float(floor_index), 0.02)
			_window(at, seed_value + float(floor_index) * 7.0 + float(column) * 3.0)
	match front:
		"S": _shop_front(south, rect.size.x, seed_value, style, dressed)
		"E": _street_side(Vector3(rect.end.x, ground_y, center.y), rect.size.y, 1.0, seed_value, style)
		"W": _street_side(Vector3(rect.position.x, ground_y, center.y), rect.size.y, -1.0, seed_value, style)

func _window(at: Vector3, seed_value: float) -> void:
	var detail := kit.detail
	var mood := scatter(seed_value)
	if mood < 0.28:
		detail.box(at, Vector3(0.74, 0.96, 0.05), Color("#1d2238"))
	elif mood < 0.4:
		neon.box(at, Vector3(0.74, 0.96, 0.05), buzzing(Color("#3f7fe0"), seed_value))
	else:
		kit.glow.box(at, Vector3(0.74, 0.96, 0.05), [Color("#ffb054"), Color("#ff9a4a"), Color("#ffc87a")][int(mood * 30.0) % 3])
	detail.box(at + Vector3(0, 0, 0.03), Vector3(0.05, 0.96, 0.03), Color("#3b3550"))
	detail.box(at + Vector3(0, 0.08, 0.03), Vector3(0.74, 0.05, 0.03), Color("#3b3550"))
	detail.box(at + Vector3(0, -0.52, 0.06), Vector3(0.92, 0.07, 0.16), Color("#b9a8c4"))
	detail.box(at + Vector3(0, 0.53, 0.04), Vector3(0.86, 0.07, 0.1), Color("#4a4263"))
	if mood > 0.7:
		for side: float in [-1.0, 1.0]:
			detail.box(at + Vector3(side * 0.53, 0, 0.03), Vector3(0.28, 0.96, 0.05), Color("#4f7f7a") if mood > 0.85 else Color("#8a5a6a"))

## Open shop front under an awning: lit interior, a half-lowered shutter and a
## neon fascia. `at` is the foot of the wall's middle; the wall faces +Z.
func _shop_front(at: Vector3, width: float, seed_value: float, style: int, dressed: bool) -> void:
	var detail := kit.detail
	var opening := width - 1.3
	detail.box(at + Vector3(0, 1.15, 0.02), Vector3(opening, 2.1, 0.05), NIGHT)
	kit.glow.box(at + Vector3(0, 0.95, 0.04), Vector3(opening - 0.5, 1.5, 0.04), Color("#ffb054"))
	for shelf in range(3):
		detail.box(at + Vector3(0, 0.6 + 0.45 * float(shelf), 0.07), Vector3(opening - 0.6, 0.06, 0.06), Color("#5a4050"))
		for ware in range(int(opening / 0.5)):
			detail.box(at + Vector3(-opening * 0.5 + 0.55 + 0.5 * float(ware), 0.74 + 0.45 * float(shelf), 0.07), Vector3(0.22, 0.2, 0.05), [Color("#8a4f5c"), Color("#4f7a8a"), Color("#a8805c")][(ware + shelf) % 3])
	kit.surface(metal(Color("#7f8aa6"))).add(at + Vector3(0, 1.95, 0.06), Vector3(opening, 0.6, 0.08))
	if not dressed:
		detail.box(at + Vector3(0, 2.42, 0.08), Vector3(width + 0.1, 0.12, 0.2), Color("#4a4263"))
		return
	var stripes: Array[Color] = [Color(1.25, 0.5, 0.42), Color(0.55, 1.15, 1.0), Color(1.3, 0.95, 0.45), Color(0.95, 0.6, 1.3)]
	kit.surface(canvas(stripes[style % stripes.size()])).add(at + Vector3(0, 2.52, 0.62), Vector3(width - 0.5, 0.05, 1.35), Basis(Vector3.RIGHT, 0.36))
	var board := at + Vector3(0, 3.22, 0.1)
	var accent := NEON_COLORS[int(seed_value * 3.0 + 40.0) % NEON_COLORS.size()]
	detail.box(board, Vector3(width - 1.2, 0.6, 0.1), NIGHT)
	for edge: float in [-1.0, 1.0]:
		neon.box(board + Vector3(0, edge * 0.32, 0.04), Vector3(width - 1.1, 0.05, 0.06), buzzing(accent, seed_value + edge))
	var letters := maxi(2, int((width - 1.8) / 0.62))
	for letter in range(letters):
		glyph(board + Vector3((float(letter) - float(letters - 1) * 0.5) * 0.62, 0, 0.06), 0.36, NEON_COLORS[(int(seed_value) + 77 + letter / 2) % NEON_COLORS.size()], seed_value + float(letter) * 1.7)

## Awning and a tall sign hung over the street; `at` is the foot of the street
## wall's middle and `outward` its direction along X.
func _street_side(at: Vector3, length: float, outward: float, seed_value: float, style: int) -> void:
	var stripes: Array[Color] = [Color(1.25, 0.5, 0.42), Color(0.55, 1.15, 1.0), Color(1.3, 0.95, 0.45), Color(0.95, 0.6, 1.3)]
	kit.surface(canvas(stripes[(style + 1) % stripes.size()])).add(at + Vector3(outward * 0.62, 2.55, 0), Vector3(1.35, 0.05, length - 0.9), Basis(Vector3.BACK, -outward * 0.36))
	kit.glow.box(at + Vector3(outward * 0.03, 1.2, 0), Vector3(0.05, 1.7, length - 1.6), Color("#ffb054"))
	kit.detail.box(at + Vector3(outward * 0.05, 1.2, 0), Vector3(0.07, 1.8, 0.1), Color("#3b3550"))
	# The tall sign hangs square to the wall, so the camera reads it face on.
	var accent := NEON_COLORS[int(absf(seed_value) * 3.0) % NEON_COLORS.size()]
	var board := at + Vector3(outward * 0.62, 3.75, length * 0.5 - 0.35)
	kit.detail.box(board, Vector3(0.74, 2.0, 0.1), NIGHT)
	kit.detail.box(board + Vector3(-outward * 0.47, 0.8, 0), Vector3(0.24, 0.06, 0.06), IRON)
	kit.detail.box(board + Vector3(-outward * 0.47, -0.8, 0), Vector3(0.24, 0.06, 0.06), IRON)
	for edge: float in [-1.0, 1.0]:
		neon.box(board + Vector3(edge * 0.37, 0, 0.05), Vector3(0.05, 2.04, 0.05), buzzing(accent, seed_value + edge))
	for letter in range(3):
		glyph(board + Vector3(0, 0.62 - 0.62 * float(letter), 0.06), 0.4, NEON_COLORS[(int(absf(seed_value)) + letter / 2 + 1) % NEON_COLORS.size()], seed_value + float(letter) * 2.3)

func _gable_roof(rect: Rect2, top: float, ridge_along_x: bool, style: int, wall: Kit.Batch) -> void:
	const PITCH := 0.44
	const EAVE := 0.4
	var center := rect.get_center()
	var tints: Array[Color] = [Color("#7a86b8"), Color("#8f6f9c"), Color("#5f8f9a")]
	var tiles := kit.surface(roof_tiles(tints[style % tints.size()]))
	var run := (rect.size.y if ridge_along_x else rect.size.x) * 0.5
	var along := (rect.size.x if ridge_along_x else rect.size.y) + 0.5
	var rise := tan(PITCH) * run
	var slope := (run + EAVE) / cos(PITCH)
	var wall_tone := Color("#3a3452")
	for side: float in [-1.0, 1.0]:
		var middle_y := top + rise - tan(PITCH) * (run + EAVE) * 0.5 + 0.05
		var offset := side * (run + EAVE) * 0.5
		if ridge_along_x:
			tiles.add(Vector3(center.x, middle_y, center.y + offset), Vector3(along, 0.14, slope), Basis(Vector3.RIGHT, side * PITCH))
			var gable_x := center.x + side * rect.size.x * 0.5
			kit.detail.sheet(Vector3(gable_x, top, rect.position.y), Vector3(gable_x, top + rise, center.y), Vector3(gable_x, top, rect.end.y), wall_tone)
		else:
			tiles.add(Vector3(center.x + offset, middle_y, center.y), Vector3(slope, 0.14, along), Basis(Vector3.BACK, -side * PITCH))
			var gable_z := center.y + side * rect.size.y * 0.5
			kit.detail.sheet(Vector3(rect.position.x, top, gable_z - side * 0.05), Vector3(center.x, top + rise, gable_z - side * 0.05), Vector3(rect.end.x, top, gable_z - side * 0.05), wall_tone)
			if side > 0.0:
				# The camera faces this gable: the wall steps up under the tiles, with
				# a vent and a bargeboard.
				for step in range(4):
					var half := run * (1.0 - float(step + 1) / 4.0)
					if half > 0.05:
						wall.add(Vector3(center.x, top + rise * (float(step) + 0.5) / 4.0, gable_z - 0.14), Vector3(half * 2.0, rise / 4.0, 0.3))
				kit.glow.box(Vector3(center.x, top + rise * 0.42, gable_z + 0.03), Vector3(0.5, 0.4, 0.04), Color("#ffb054"))
				kit.detail.box(Vector3(center.x, top + 0.02, gable_z + 0.05), Vector3(rect.size.x + 0.3, 0.1, 0.1), Color("#4a4263"))
	var ridge := Vector3(along + 0.1, 0.12, 0.2) if ridge_along_x else Vector3(0.2, 0.12, along + 0.1)
	kit.detail.box(Vector3(center.x, top + rise + 0.11, center.y), ridge, Color("#3b3550"))

func _flat_roof(rect: Rect2, top: float, seed_value: float) -> void:
	var detail := kit.detail
	var center := rect.get_center()
	kit.surface(metal(Color("#a3aed0"))).add(Vector3(center.x, top + 0.04, center.y), Vector3(rect.size.x - 0.3, 0.08, rect.size.y - 0.3))
	var parapet := Color("#5a5273")
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(center.x, top + 0.2, center.y + side * (rect.size.y * 0.5 - 0.08)), Vector3(rect.size.x + 0.1, 0.44, 0.2), parapet)
		detail.box(Vector3(center.x + side * (rect.size.x * 0.5 - 0.08), top + 0.2, center.y), Vector3(0.2, 0.44, rect.size.y + 0.1), parapet)
	# Water tank on a stand, with its feed pipe.
	var tank := Vector3(center.x + (scatter(seed_value) - 0.5) * (rect.size.x - 2.4), top, center.y - rect.size.y * 0.12)
	for leg_x: float in [-0.4, 0.4]:
		for leg_z: float in [-0.4, 0.4]:
			detail.box(tank + Vector3(leg_x, 0.35, leg_z), Vector3(0.07, 0.7, 0.07), IRON)
	kit.rounds(metal(Color("#c5cfe6"))).add(tank + Vector3(0, 1.25, 0), Vector3(1.24, 1.1, 1.24))
	detail.tube(tank + Vector3(0, 1.95, 0), 0.64, 0.08, 0.3, Color("#8d97ad"), 10)
	for band: float in [0.95, 1.55]:
		detail.tube(tank + Vector3(0, band, 0), 0.64, 0.64, 0.05, Color("#6c7488"), 10)
	detail.box(tank + Vector3(0.75, 0.6, 0), Vector3(0.07, 1.2, 0.07), Color("#6c7488"))
	# A cooler and an aerial keep the roofline busy.
	var cooler := Vector3(center.x - rect.size.x * 0.28, top + 0.3, center.y + rect.size.y * 0.2)
	detail.box(cooler, Vector3(0.8, 0.5, 0.5), Color("#8d97ad"))
	detail.box(cooler + Vector3(0, 0, 0.26), Vector3(0.5, 0.34, 0.02), NIGHT)
	detail.box(Vector3(center.x + rect.size.x * 0.34, top + 1.1, center.y + rect.size.y * 0.3), Vector3(0.04, 2.2, 0.04), IRON)
	detail.box(Vector3(center.x + rect.size.x * 0.34, top + 2.0, center.y + rect.size.y * 0.3), Vector3(0.7, 0.03, 0.03), IRON)

## Timber gateway with a tiled cap; returns the middle of its name board.
func gateway(at: Vector3, span: float) -> Vector3:
	var detail := kit.detail
	for side: float in [-1.0, 1.0]:
		kit.piles().add(at + Vector3(side * span * 0.5, 2.0, 0), Vector3(0.36, 4.0, 0.36))
		detail.box(at + Vector3(side * span * 0.5, 0.22, 0), Vector3(0.62, 0.44, 0.62), Color("#6f6a80"))
		lantern(at + Vector3(side * (span * 0.5 - 0.55), 3.25, 0.2), LANTERN_COLORS[0], 1.15)
	detail.box(at + Vector3(0, 3.5, 0), Vector3(span + 1.2, 0.2, 0.3), DARK_WOOD)
	detail.box(at + Vector3(0, 4.3, 0), Vector3(span + 0.7, 0.18, 0.28), DARK_WOOD)
	for half: float in [-1.0, 1.0]:
		kit.surface(roof_tiles(Color("#8f6f9c"))).add(at + Vector3(0, 4.68, half * 0.3), Vector3(span + 1.9, 0.12, 0.7), Basis(Vector3.RIGHT, half * 0.4))
	detail.box(at + Vector3(0, 4.85, 0), Vector3(span + 2.0, 0.1, 0.16), Color("#3b3550"))
	var board := at + Vector3(0, 3.88, 0.2)
	detail.box(board, Vector3(span - 0.6, 0.62, 0.08), NIGHT)
	for edge: float in [-1.0, 1.0]:
		neon.box(board + Vector3(0, edge * 0.33, 0.04), Vector3(span - 0.5, 0.05, 0.06), buzzing(ROSE, edge))
	return board

## Low stone lantern for path edges.
func stone_lantern(at: Vector3) -> void:
	var detail := kit.detail
	var stone := Color("#7f7a92")
	detail.tube(at + Vector3(0, 0.08, 0), 0.24, 0.2, 0.16, stone, 6)
	detail.tube(at + Vector3(0, 0.36, 0), 0.09, 0.09, 0.4, stone.darkened(0.1), 6)
	detail.tube(at + Vector3(0, 0.6, 0), 0.14, 0.22, 0.08, stone, 6)
	neon.box(at + Vector3(0, 0.76, 0), Vector3(0.2, 0.22, 0.2), AMBER)
	detail.tube(at + Vector3(0, 0.95, 0), 0.34, 0.06, 0.18, stone.darkened(0.15), 6)

## Small street shrine: a red cabinet under a tiled roof with offerings and incense.
func shrine(at: Vector3) -> void:
	var detail := kit.detail
	kit.surface(masonry(Color("#8d86a6"))).add(at + Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 0.8))
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 0.63, 0), Vector3(1.4, 0.06, 0.9), Color("#9a94ad"))
	detail.box(Vector3(0, 1.1, -0.1), Vector3(1.0, 0.9, 0.5), Color("#a8404a"))
	detail.box(Vector3(0, 1.1, 0.16), Vector3(0.7, 0.66, 0.02), NIGHT)
	detail.box(Vector3(-0.12, 0.76, 0.3), Vector3(0.14, 0.14, 0.14), Color("#f0a04a"))
	detail.box(Vector3(0.06, 0.76, 0.32), Vector3(0.14, 0.14, 0.14), Color("#f0a04a"))
	detail.tube(Vector3(0.36, 0.76, 0.26), 0.1, 0.08, 0.14, BRASS, 6)
	for stick in range(3):
		detail.box(Vector3(0.32 + 0.04 * float(stick), 0.95, 0.26), Vector3(0.015, 0.26, 0.015), Color("#b06a5a"))
	detail.frame = Transform3D.IDENTITY
	kit.glow.box(at + Vector3(0, 1.1, 0.18), Vector3(0.46, 0.46, 0.02), Color("#ffd27a"))
	neon.box(at + Vector3(0.36, 1.1, 0.26), Vector3(0.1, 0.03, 0.03), buzzing(EMBER, 3.0))
	for half: float in [-1.0, 1.0]:
		kit.surface(roof_tiles(Color("#8f6f9c"))).add(at + Vector3(half * 0.36, 1.72, -0.06), Vector3(0.9, 0.08, 0.86), Basis(Vector3.BACK, -half * 0.42))
		lantern(at + Vector3(half * 0.72, 1.62, 0.3), LANTERN_COLORS[3], 0.55)
	detail.box(at + Vector3(0, 1.9, -0.06), Vector3(0.12, 0.08, 0.92), Color("#3b3550"))

## The lucky cat's seated body on its cushion; the beckoning arm is separate.
func lucky_cat(at: Vector3) -> void:
	var detail := kit.detail
	var fur := Color("#f6efe2")
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 0.05, 0), Vector3(0.62, 0.1, 0.5), Color("#b23b4a"))
	detail.tube(Vector3(0, 0.34, 0), 0.26, 0.2, 0.5, fur, 10)
	detail.tube(Vector3(0, 0.75, 0.02), 0.25, 0.25, 0.34, fur, 10)
	for ear: float in [-1.0, 1.0]:
		detail.tube(Vector3(ear * 0.16, 0.98, 0), 0.09, 0.0, 0.16, fur, 4)
		detail.tube(Vector3(ear * 0.16, 0.96, 0.03), 0.05, 0.0, 0.1, Color("#ff9aa8"), 4)
		detail.box(Vector3(ear * 0.1, 0.8, 0.25), Vector3(0.05, 0.06, 0.02), NIGHT)
		detail.box(Vector3(ear * 0.15, 0.7, 0.25), Vector3(0.1, 0.02, 0.02), Color("#c9bfae"))
	detail.box(Vector3(0, 0.72, 0.26), Vector3(0.05, 0.04, 0.02), Color("#ff7a8a"))
	detail.box(Vector3(0, 0.56, 0.05), Vector3(0.44, 0.07, 0.42), Color("#d0404f"))
	detail.box(Vector3(-0.2, 0.34, 0.2), Vector3(0.12, 0.34, 0.12), fur)
	detail.box(Vector3(-0.02, 0.3, 0.24), Vector3(0.26, 0.34, 0.04), Color("#e8b84a"))
	detail.frame = Transform3D.IDENTITY
	neon.tube(at + Vector3(0, 0.5, 0.25), 0.06, 0.06, 0.06, AMBER, 6)

## The arm that beckons; its origin is the shoulder.
static func lucky_cat_arm_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	# A shade off the body's fur, so the paw reads against the head behind it.
	var fur := Color("#e2d8c6")
	sculpt.box(Vector3(0, 0.2, 0), Vector3(0.13, 0.42, 0.13), fur)
	sculpt.box(Vector3(0, 0.15, 0), Vector3(0.16, 0.06, 0.16), Color("#d0404f"))
	sculpt.box(Vector3(0, 0.47, 0.02), Vector3(0.2, 0.16, 0.18), fur.lightened(0.5))
	sculpt.box(Vector3(0, 0.47, 0.115), Vector3(0.1, 0.08, 0.02), Color("#ff8a9c"))
	return sculpt.mesh()

## Spit with three roasting birds; it turns about the mesh's local Z axis.
static func spit_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3.ZERO, Vector3(0.04, 0.04, 1.16), Color("#9aa3b5"))
	for bird in range(3):
		var at := Vector3(0, 0, -0.36 + 0.36 * float(bird))
		sculpt.tube(at, 0.13, 0.13, 0.24, Color("#c9853f"), 6, Basis(Vector3.RIGHT, PI * 0.5))
		sculpt.box(at + Vector3(0.1, 0.06, 0), Vector3(0.1, 0.06, 0.2), Color("#a8642c"))
	return sculpt.mesh()

## Four-blade fan in a round cage; it turns about the mesh's local Z axis.
static func fan_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for blade in range(4):
		var turn := Basis(Vector3.BACK, TAU * float(blade) / 4.0)
		sculpt.box(turn * Vector3(0.17, 0, 0), Vector3(0.3, 0.12, 0.02), Color("#aab4c8"), turn * Basis(Vector3.RIGHT, 0.4))
	sculpt.tube(Vector3.ZERO, 0.06, 0.06, 0.06, Color("#3a3c52"), 6, Basis(Vector3.RIGHT, PI * 0.5))
	return sculpt.mesh()
