extends "res://game/world/field/field_game.gd"
## A giant gumball bounces about a candy-striped mat. Its shadow shows where
## it will come down: be under it and you head it back up, miss and it lands
## with a sticky splat. It flies faster and faster as the round goes on.

const BALLS := 1
const HEAD_REACH := 0.75
const SLOW_FLIGHT := 2.0
const FAST_FLIGHT := 1.05
## Each landing is a short dash from the last: never on the spot, never across the mat.
const NEAREST_HOP := 1.3
const FARTHEST_HOP := 3.1
const FLIGHT_HEIGHT := 3.2
## Head height: the ball turns round here instead of at the feet.
const HEAD := 1.9
const SPLAT_SECONDS := 0.5
const BALL_RADIUS := 0.32
const BALL_COLORS := [Color("#ef7fa8"), Color("#7fd0c4")]

var spots := PackedVector3Array()
var from := PackedInt32Array()
var to := PackedInt32Array()
var clock := PackedFloat32Array()
var span := PackedFloat32Array()
var live := PackedByteArray()
var splat := PackedFloat32Array()
## 1 while a ball rises from the floor after a splat instead of from a head.
var low := PackedByteArray()
var headers := 0
var splats := 0

var _balls: Array[MeshInstance3D] = []
var _shadows: Array[MeshInstance3D] = []
var _stuck := false
var _show := 0.0


func build() -> void:
	var middle := centre()
	# Candy-cane posts ring the play floor (see field_dressing.gd), red and white by turns.
	var cane := CylinderMesh.new()
	cane.top_radius = 0.07
	cane.bottom_radius = 0.07
	cane.height = 0.5
	cane.radial_segments = 6
	cane.rings = 1
	var canes: Array[Transform3D] = []
	for index in range(16):
		var angle := TAU * index / 16.0
		canes.append(Transform3D(Basis.IDENTITY, middle + Vector3(cos(angle) * 3.05, 0.25, sin(angle) * 3.05)))
	Kit.batch(self, cane, canes, world._vertex_color_material("field-canes"), [Color("#e0525a"), Color("#fff3ec")])
	for offset: Vector2 in spec.get("layout", []):
		spots.append(spot(offset))
	for index in range(BALLS):
		_shadows.append(Kit.blob(world, self, Vector2(1.0, 1.0)))
		var ball := Kit.ball(self, Vector3.ZERO, BALL_RADIUS, world._mat(BALL_COLORS[index]))
		Kit.ball(ball, Vector3(-0.1, 0.12, 0.2), 0.08, world._mat(Color("#fff6f0")))
		_balls.append(ball)
	from.resize(BALLS)
	to.resize(BALLS)
	clock.resize(BALLS)
	span.resize(BALLS)
	live.resize(BALLS)
	splat.resize(BALLS)
	low.resize(BALLS)


func reset() -> void:
	live.fill(0)
	splat.fill(0.0)
	_stuck = false
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	headers = 0
	splats = 0
	_launch(0, spots.size() - 1)


## Where ball `index` will come down.
func landing(index: int) -> Vector3:
	return spots[to[index]]


func time_left(index: int) -> float:
	return span[index] - clock[index] if live[index] == 1 else INF


func step(delta: float, player: Vector3) -> void:
	for index in range(BALLS):
		if live[index] == 0:
			continue
		if splat[index] > 0.0:
			# Stuck to the mat for a moment, then it bounces up again.
			splat[index] -= delta
			if splat[index] <= 0.0:
				_launch(index, to[index])
				low[index] = 1
			continue
		clock[index] += delta
		if clock[index] < span[index]:
			continue
		if flat_distance(player, spots[to[index]]) < HEAD_REACH:
			headers += 1
			add_score(1)
			note(headers)
			feedback("hit")
			hop(0.25, 0.25)
			_launch(index, to[index])
		else:
			splats += 1
			splat[index] = SPLAT_SECONDS
			feedback("miss")
			field.say("啪嗒！", 0.6)
	_draw(player)


## Sends ball `index` up from spot `start` towards a spot well away from it.
func _launch(index: int, start: int) -> void:
	var choice := rng.randi_range(0, spots.size() - 1)
	for tries in range(spots.size()):
		var hop_length := spots[choice].distance_to(spots[start])
		if hop_length >= NEAREST_HOP and hop_length <= FARTHEST_HOP:
			break
		choice = (choice + 1) % spots.size()
	live[index] = 1
	low[index] = 0
	splat[index] = 0.0
	from[index] = start
	to[index] = choice
	clock[index] = 0.0
	span[index] = lerpf(SLOW_FLIGHT, FAST_FLIGHT, pace())


func conclude(medal: int) -> void:
	# No medal: the gumball comes down on your head and stays there.
	_stuck = medal == 0
	_show = 0.0
	live.fill(0)


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(player: Vector3) -> void:
	for index in range(BALLS):
		var ball := _balls[index]
		var shade := _shadows[index]
		if _stuck and index == 0 and player.is_finite():
			ball.visible = true
			var wobble := 0.0 if reduced() else sin(_show * 9.0) * 0.06
			ball.position = player + Vector3(wobble, 2.35, 0.05)
			ball.scale = Vector3(1.15, 0.85, 1.15)
			shade.visible = false
			continue
		ball.visible = live[index] == 1
		shade.visible = ball.visible
		if not ball.visible:
			continue
		var along := clampf(clock[index] / span[index], 0.0, 1.0)
		var start := spots[from[index]]
		var end := spots[to[index]]
		var rise := lerpf(BALL_RADIUS if low[index] == 1 else HEAD, HEAD, along)
		ball.position = start.lerp(end, along) + Vector3(0, rise + sin(along * PI) * (FLIGHT_HEIGHT - HEAD), 0)
		ball.scale = Vector3.ONE
		if splat[index] > 0.0:
			var fallen := clampf((SPLAT_SECONDS - splat[index]) / 0.15, 0.0, 1.0)
			ball.position = end + Vector3(0, lerpf(HEAD, BALL_RADIUS * 0.7, fallen), 0)
			var squash := 0.0 if reduced() else fallen * 0.35
			ball.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
		# The shadow waits at the landing spot and darkens as the ball drops.
		var grow := 0.5 + 0.6 * along
		shade.position = end + Vector3(0, 0.08, 0)
		shade.scale = Vector3(grow, 1.0, grow)
