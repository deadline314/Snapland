extends "res://game/world/field/field_toy.gd"
## A giant clapperboard on an easel. Poke it: the striped stick swings open,
## hangs a beat, then snaps shut with a clack that bounces the whole board,
## and the take number on its slate goes up by one.

const OPEN_SECONDS := 0.45
const HOLD_SECONDS := 0.35
const SNAP_SECONDS := 0.07
const OPEN_ANGLE := 0.75

var _board: Node3D
var _stick: Node3D
var _take: Label3D
var _clacked := true
var _takes := 1


func build() -> void:
	var dark: Material = world._mat(Color("#2e2a33"))
	var wood: Material = world._wood_material(Color("#6e4c32"))
	# The easel: two front legs and a back prop.
	for side: float in [-1.0, 1.0]:
		var leg := Kit.box(self, ground + Vector3(side * 0.32, 0.55, 0.05), Vector3(0.06, 1.12, 0.06), wood)
		leg.rotation.z = side * 0.12
	var prop := Kit.box(self, ground + Vector3(0, 0.55, -0.28), Vector3(0.06, 1.15, 0.06), wood)
	prop.rotation.x = -0.45
	_board = Node3D.new()
	_board.position = ground + Vector3(0, 1.0, 0.1)
	add_child(_board)
	Kit.box(_board, Vector3(0, 0, 0), Vector3(0.9, 0.62, 0.06), dark)
	# Chalk lines on the slate.
	for line in 3:
		Kit.box(_board, Vector3(0, 0.16 - float(line) * 0.17, 0.035), Vector3(0.82, 0.02, 0.01), world._mat(Color("#e8e4dc")))
	_take = Kit.label(_board, "TAKE 1", Vector3(0.12, -0.24, 0.05), 22, Color("#f6f1e6"))
	_take.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_take.outline_size = 2
	# The striped clapper stick, hinged at its left end on top of the board.
	Kit.box(_board, Vector3(0, 0.36, 0), Vector3(0.9, 0.1, 0.06), _stripes())
	_stick = Node3D.new()
	_stick.position = Vector3(-0.45, 0.42, 0.0)
	_board.add_child(_stick)
	Kit.box(_stick, Vector3(0.45, 0.05, 0), Vector3(0.9, 0.1, 0.06), _stripes())
	Kit.ball(_stick, Vector3(0, 0, 0.04), 0.035, world._coastal_surface(Kit.TILE_BRASS, 0.3))
	item["marker"] = 2.0


## Black and white diagonal stripes from the shared canvas tile.
func _stripes() -> Material:
	return world._coastal_surface(Kit.TILE_CANVAS, 0.22, Color("#e6e6e6"))


func poke() -> void:
	_clacked = false
	_takes += 1
	_take.text = "TAKE %d" % _takes


func advance(_delta: float, _player: Vector3, still: bool) -> void:
	var t := since()
	if still:
		_stick.rotation.z = 0.0
		_board.position.y = ground.y + 1.0
		return
	var shut_at := OPEN_SECONDS + HOLD_SECONDS
	var angle := 0.0
	if t < OPEN_SECONDS: angle = OPEN_ANGLE * smoothstep(0.0, OPEN_SECONDS, t)
	elif t < shut_at: angle = OPEN_ANGLE
	elif t < shut_at + SNAP_SECONDS: angle = OPEN_ANGLE * (1.0 - (t - shut_at) / SNAP_SECONDS)
	_stick.rotation.z = angle
	if not _clacked and t >= shut_at + SNAP_SECONDS:
		_clacked = true
		note(_takes)
		feedback("success")
	# The clack bounces the board.
	var since_clack := t - shut_at - SNAP_SECONDS
	var jolt := 0.0
	if since_clack > 0.0 and since_clack < 0.5:
		jolt = sin(since_clack * 30.0) * 0.05 * (1.0 - since_clack / 0.5)
	_board.position.y = ground.y + 1.0 + jolt
