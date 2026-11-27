extends "res://game/world/field/field_toy.gd"
## A tall gumball machine: turn the knob and one gumball rattles down the
## chute, bounces across the grass and rolls to a stop, then is tidied away.

const HEIGHT := 1.35
const BALL := 0.13
const OUT_SECONDS := 4.0
const BALL_COLORS := [Color("#ef7fa8"), Color("#7fd0c4"), Color("#f2c75a"), Color("#9fb8ef")]

var _knob: MeshInstance3D
var _ball: MeshInstance3D
var _colour := 0


func build() -> void:
	Kit.cylinder(self, ground + Vector3(0, 0.08, 0), 0.36, 0.16, world._wood_material(Color("#7a5a3c")), 0.32, 12)
	Kit.cylinder(self, ground + Vector3(0, 0.55, 0), 0.26, 0.78, Kit.finish(world, Color("#d9525e"), Vector3(0.5, 0.78, 0.5)), 0.22, 12)
	Kit.ball(self, ground + Vector3(0, HEIGHT, 0), 0.4, Kit.clear_material(world, Color(0.9, 0.97, 1.0, 0.35)))
	Kit.cylinder(self, ground + Vector3(0, HEIGHT + 0.42, 0), 0.12, 0.1, world._coastal_surface(Kit.TILE_BRASS, 0.4), 0.06, 10)
	# The gumballs inside, one batch.
	var gum := SphereMesh.new()
	gum.radius = 0.1
	gum.height = 0.2
	gum.radial_segments = 8
	gum.rings = 4
	var heap: Array[Transform3D] = []
	for index in range(14):
		var angle := index * 2.4
		var ring := 0.12 + fposmod(index * 0.37, 0.18)
		heap.append(Transform3D(Basis.IDENTITY, ground + Vector3(cos(angle) * ring, HEIGHT - 0.22 + (index / 5) * 0.16, sin(angle) * ring)))
	var colors: Array[Color] = []
	colors.assign(BALL_COLORS)
	Kit.batch(self, gum, heap, world._vertex_color_material("field-gumballs", 0.4), colors)
	_knob = Kit.cylinder(self, ground + Vector3(0, 0.62, 0.27), 0.09, 0.08, world._coastal_surface(Kit.TILE_BRASS, 0.4), -1.0, 8)
	_knob.rotation.x = PI * 0.5
	Kit.box(_knob, Vector3(0, 0.05, 0), Vector3(0.2, 0.04, 0.05), world._mat(Color("#fff3ec")))
	for tone: Color in BALL_COLORS:
		# Made now, so a poke only swaps between cached materials.
		world._mat(tone)
	_ball = Kit.ball(self, Vector3.ZERO, BALL, world._mat(BALL_COLORS[0]))
	item["marker"] = 2.2


func poke() -> void:
	_colour = (_colour + 1) % BALL_COLORS.size()
	_ball.material_override = world._mat(BALL_COLORS[_colour])
	note(_colour)


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	_knob.rotation.y = 0.0 if still else -minf(t, 0.5) * TAU * 2.0 * (1.0 if t < 0.5 else 0.0)
	_ball.visible = t < OUT_SECONDS
	if not _ball.visible:
		return
	var rest := ground + Vector3(0.9, BALL, 0.75)
	if still:
		_ball.position = rest
		return
	var mouth := ground + Vector3(0, 0.3, 0.3)
	var roll := clampf((t - 0.35) / 1.4, 0.0, 1.0)
	# Three shrinking bounces on the way out.
	var bounce := absf(sin(roll * PI * 3.0)) * 0.45 * (1.0 - roll)
	_ball.position = mouth.lerp(rest, roll) + Vector3(0, bounce, 0)
	if roll <= 0.0:
		_ball.position = mouth
	_ball.scale = Vector3.ONE * (1.0 - smoothstep(OUT_SECONDS - 0.4, OUT_SECONDS, t))
