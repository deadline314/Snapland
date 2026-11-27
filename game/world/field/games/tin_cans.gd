extends "res://game/world/field/field_game.gd"
## A pyramid of tin cans waits at the end of a toy-town lane. Line up in
## front of it and press interact to bowl a ball straight up the lane; the
## cans it hits fall and take the ones above with them. Clear a pyramid and a
## new one is stacked, sliding along a moving shelf later on. A ball that
## hits nothing bounces off the back board and bonks you.

enum { READY, ROLLING, RETURNING, RESTACK }

const CANS := 6
const ROLL_SPEED := 5.5
const HIT_REACH := 0.27
const CAN_RADIUS := 0.13
const CAN_HEIGHT := 0.34
const RESTACK_SECONDS := 0.8
const RETURN_SECONDS := 0.7
const SLIDE := 0.8
## Bottom row, middle row, top: x across the lane and which cans hold each up.
const ROWS := [Vector2(-0.3, 0), Vector2(0.0, 0), Vector2(0.3, 0), Vector2(-0.15, 1), Vector2(0.15, 1), Vector2(0.0, 2)]
const HOLDS := [[], [], [], [0, 1], [1, 2], [3, 4]]
const CAN_COLORS := [Color("#d9454e"), Color("#7fc4f2"), Color("#f2c75a"), Color("#7fd0c4"), Color("#f4a6c6"), Color("#d9454e")]

var mode := READY
var down := PackedByteArray()
var fall := PackedFloat32Array()
var shelf_x := 0.0
var rolls := 0
var bonks := 0
var cleared := 0
var ball := Vector3.ZERO

var _line := Vector3.ZERO
var _back := Vector3.ZERO
var _cans: MultiMesh
var _ball: MeshInstance3D
var _clock := 0.0
var _hit_any := false
var _slide_phase := 0.0
var _show := 0.0
var _taunt := false


func build() -> void:
	var middle := centre()
	var layout: Array = spec.get("layout", [])
	_line = spot(Vector2(0, (layout[0] as Vector2).y))
	_back = spot(Vector2(0, (layout[2] as Vector2).y))
	var length := _line.distance_to(_back)
	# The lane: a plank floor between two rails, a shelf and a padded back board.
	var lane := Kit.box(self, (_line + _back) * 0.5 + Vector3(0, 0.03, 0), Vector3(3.2, 0.06, length + 0.4), world._coastal_surface(Kit.TILE_PLANK, 0.8, Color("#e6c79a")))
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.65, 1.65]:
		Kit.box(self, (_line + _back) * 0.5 + Vector3(side, 0.1, 0), Vector3(0.1, 0.14, length + 0.4), world._mat(Color("#da705c")))
	Kit.box(self, _back + Vector3(0, 0.12, 0), Vector3(3.2, 0.18, 0.5), world._coastal_surface(Kit.TILE_RED_BOARD, 0.6))
	var board_legs: Array[Vector3] = [_back + Vector3(-1.55, 0, -0.45), _back + Vector3(1.55, 0, -0.45)]
	Kit.posts(world, self, board_legs, 1.3, Color("#f2c75a"), 0.07)
	Kit.box(self, _back + Vector3(0, 0.85, -0.45), Vector3(3.1, 1.2, 0.1), world._coastal_surface(Kit.TILE_CANVAS, 0.9, Color("#4b6f9c")))
	Kit.box(self, _line + Vector3(0, 0.07, 0), Vector3(3.2, 0.04, 0.08), world._mat(Color("#fff3ec"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var can := CylinderMesh.new()
	can.top_radius = CAN_RADIUS
	can.bottom_radius = CAN_RADIUS
	can.height = CAN_HEIGHT
	can.radial_segments = 10
	can.rings = 1
	var hidden: Array[Transform3D] = []
	for index in range(CANS):
		hidden.append(Transform3D(Basis.IDENTITY, _back))
	var colors: Array[Color] = []
	colors.assign(CAN_COLORS)
	var batch := Kit.batch(self, can, hidden, world._vertex_color_material("field-cans", 0.35), colors)
	batch.multimesh.custom_aabb = AABB(middle - Vector3(5, 1, 5), Vector3(10, 5, 10))
	_cans = batch.multimesh
	_ball = Kit.ball(self, Vector3.ZERO, 0.17, world._coastal_surface(Kit.TILE_BRASS, 0.3, Color("#9fb8ef")))
	down.resize(CANS)
	fall.resize(CANS)


func reset() -> void:
	mode = READY
	down.fill(0)
	fall.fill(0.0)
	shelf_x = 0.0
	_taunt = false
	_ball.visible = false
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	rolls = 0
	bonks = 0
	cleared = 0
	shelf_x = 0.0
	_slide_phase = rng.randf() * TAU
	_ball.visible = false


func action_label() -> String:
	return "滾球" if mode == READY else ""


## The x of can `index` on the island right now.
func can_x(index: int) -> float:
	return _back.x + shelf_x + (ROWS[index] as Vector2).x


func slide_speed() -> float:
	return lerpf(0.5, 1.0, pace())


## Where the shelf will be `ahead` seconds from now, for visitors who lead their aim.
func shelf_x_at(ahead: float) -> float:
	var reach := clampf((pace() - 0.35) * 3.0, 0.0, 1.0)
	return sin(_slide_phase + (slide_speed() * ahead if pace() > 0.35 else 0.0)) * SLIDE * reach


func travel_seconds() -> float:
	return absf(_line.z - _back.z) / ROLL_SPEED


func standing_cans() -> PackedInt32Array:
	var up := PackedInt32Array()
	for index in range(CANS):
		if down[index] == 0:
			up.append(index)
	return up


func step(delta: float, player: Vector3) -> void:
	_clock += delta
	if pace() > 0.35:
		_slide_phase += delta * slide_speed()
	shelf_x = shelf_x_at(0.0)
	for index in range(CANS):
		if down[index] == 1:
			fall[index] = minf(1.0, fall[index] + delta * 3.0)
	match mode:
		ROLLING:
			ball.z -= ROLL_SPEED * delta
			if ball.z <= _back.z + 0.15:
				_strike()
		RETURNING:
			var along := clampf(_clock / RETURN_SECONDS, 0.0, 1.0)
			ball = Vector3(ball.x, 0, lerpf(_back.z, player.z, along))
			if along >= 1.0:
				if not _hit_any:
					bonks += 1
					hop(0.4, 0.5)
					feedback("miss")
					field.say("咚！", 0.6)
				mode = READY
		RESTACK:
			if _clock >= RESTACK_SECONDS:
				down.fill(0)
				fall.fill(0.0)
				mode = READY
	_draw(player)


func press() -> void:
	if mode != READY:
		return
	var player: Vector3 = world.player.global_position
	rolls += 1
	mode = ROLLING
	ball = Vector3(clampf(player.x, _line.x - 1.45, _line.x + 1.45), 0, _line.z)
	_ball.visible = true


func _strike() -> void:
	_hit_any = false
	var knocked := 0
	for index in range(CANS):
		if down[index] == 0 and absf(can_x(index) - ball.x) < HIT_REACH and (ROWS[index] as Vector2).y < 1.0:
			down[index] = 1
			knocked += 1
	# Anything left standing on a fallen can comes down too.
	for index in range(CANS):
		if down[index] == 1:
			continue
		for holder: int in HOLDS[index]:
			if down[holder] == 1:
				down[index] = 1
				knocked += 1
				break
	_clock = 0.0
	if knocked > 0:
		_hit_any = true
		add_score(knocked)
		note(knocked)
		feedback("hit")
	if standing_cans().is_empty():
		cleared += 1
		feedback("success")
		mode = RESTACK
		_ball.visible = false
		return
	mode = RETURNING


func conclude(medal: int) -> void:
	_taunt = medal == 0
	_show = 0.0
	_ball.visible = false


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(_player: Vector3) -> void:
	for index in range(CANS):
		var row: Vector2 = ROWS[index]
		var home := Vector3(can_x(index), _back.y + 0.21 + CAN_HEIGHT * (row.y + 0.5), _back.z)
		var basis := Basis.IDENTITY
		if down[index] == 1:
			# Tipped over backwards and rolled off the shelf.
			var tip := fall[index] if not reduced() else 1.0
			home = home.lerp(Vector3(home.x + (index - 2.5) * 0.12, _back.y + 0.1, _back.z - 0.35), tip)
			basis = Basis(Vector3.RIGHT, -tip * PI * 0.5)
		elif _taunt and not reduced():
			# The cans hop about, cheering their own survival.
			home.y += absf(sin(_show * 8.0 + index)) * 0.15
		_cans.set_instance_transform(index, Transform3D(basis, home))
	if _ball.visible:
		_ball.position = ball + Vector3(0, _line.y + 0.2, 0)
		_ball.rotation.x = 0.0 if reduced() else -ball.z / 0.17
