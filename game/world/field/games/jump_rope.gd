extends "res://game/world/field/field_game.gd"
## Two posts turn a long rope across a lane. Stand between them and press
## interact to hop as it sweeps under your feet. It turns faster and faster;
## miss and it wraps you up for a moment before starting again.

const POST_HEIGHT := 1.5
const ROPE_RADIUS := 0.06
const SLOW_TURN := 1.75
const FAST_TURN := 0.82
const HOP_SECONDS := 0.5
const HOP_HEIGHT := 0.62
## The rope clears the feet while this much of the hop remains.
const CLEAR_FROM := 0.06
const CLEAR_UNTIL := 0.46
## Feet must be back on the ground this long before the next hop, so timing
## beats hammering the key.
const LAND_SECONDS := 0.22
const TRIP_SECONDS := 1.3
const LANE_HALF_WIDTH := 0.75
const POST_MARGIN := 0.55

var angle := PI
## Seconds of hop left; negative while the feet settle after landing.
var air := 0.0
var tripped := 0.0
var streak := 0
var best_streak := 0
var trips := 0

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _rope: MeshInstance3D
var _coil: MeshInstance3D
var _turning := false
var _wrapped_at := Vector3.ZERO
var _show_wrapped := false


func build() -> void:
	var layout: Array = spec.get("layout", [])
	_a = spot(layout[0])
	_b = spot(layout[1])
	var ends: Array[Vector3] = [_a, _b]
	Kit.posts(world, self, ends, POST_HEIGHT, spec.color, 0.09)
	var middle := (_a + _b) * 0.5
	# Trodden ground shows where to stand.
	Kit.cylinder(self, middle + Vector3(0, 0.02, 0), 0.78, 0.04, Kit.sand_material(world), -1.0, 16).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var span := _a.distance_to(_b)
	var arc := PackedVector3Array()
	for index in range(17):
		var along := index / 16.0
		# Hangs to just above the ground at the bottom of its turn.
		arc.append(Vector3((along - 0.5) * span, -sin(along * PI) * (POST_HEIGHT + 0.12), 0))
	var cord: StandardMaterial3D = world._mat(Color("#e8674f"))
	_rope = Kit.mesh(self, Kit.tube(arc, ROPE_RADIUS), middle + Vector3(0, POST_HEIGHT + 0.2, 0), cord)
	_rope.rotation.y = -Vector2(_b.x - _a.x, _b.z - _a.z).angle()
	var loops := PackedVector3Array()
	for index in range(49):
		var turn := index / 48.0
		loops.append(Vector3(cos(turn * TAU * 3.0) * 0.5, 0.4 + turn * 1.1, sin(turn * TAU * 3.0) * 0.5))
	_coil = Kit.mesh(self, Kit.tube(loops, ROPE_RADIUS, Vector3.UP), Vector3.ZERO, cord)


func reset() -> void:
	angle = PI
	air = -LAND_SECONDS
	tripped = 0.0
	_turning = false
	_show_wrapped = false
	_draw()


func begin() -> void:
	streak = 0
	best_streak = 0
	trips = 0
	_turning = true


func action_label() -> String:
	return "跳！"


func press() -> void:
	if air > -LAND_SECONDS or tripped > 0.0:
		return
	air = HOP_SECONDS
	hop(HOP_HEIGHT, HOP_SECONDS)


func in_lane(player: Vector3) -> bool:
	var a := Vector2(_a.x, _a.z)
	var b := Vector2(_b.x, _b.z)
	var feet := Vector2(player.x, player.z)
	var nearest := Geometry2D.get_closest_point_to_segment(feet, a, b)
	return feet.distance_to(nearest) <= LANE_HALF_WIDTH and nearest.distance_to(a) >= POST_MARGIN and nearest.distance_to(b) >= POST_MARGIN


func step(delta: float, player: Vector3) -> void:
	air = maxf(-LAND_SECONDS, air - delta)
	if tripped > 0.0:
		tripped -= delta
		_wrapped_at = player
		if tripped <= 0.0:
			angle = PI
		_draw()
		return
	var before := floori(angle / TAU)
	angle += TAU / lerpf(SLOW_TURN, FAST_TURN, pace()) * delta
	if floori(angle / TAU) > before and in_lane(player):
		if air > CLEAR_FROM and air < CLEAR_UNTIL:
			streak += 1
			best_streak = maxi(best_streak, streak)
			add_score(1)
			note(streak - 1)
		else:
			_trip(player)
	_draw()


func _trip(player: Vector3) -> void:
	trips += 1
	streak = 0
	tripped = TRIP_SECONDS
	air = -LAND_SECONDS
	_wrapped_at = player
	feedback("miss")
	hop(0.14, TRIP_SECONDS, 5)
	field.say("纏住了！", 1.0)


func conclude(medal: int) -> void:
	_turning = false
	tripped = 0.0
	angle = PI
	_show_wrapped = medal == 0


func show_step(_delta: float, player: Vector3) -> void:
	_wrapped_at = player
	_draw()


func _draw() -> void:
	var wrapped := tripped > 0.0 or _show_wrapped
	_rope.visible = not wrapped
	_coil.visible = wrapped
	if wrapped:
		_coil.position = Vector3(_wrapped_at.x, world.ground_surface_y(_wrapped_at), _wrapped_at.z)
		_coil.rotation.y = 0.0 if reduced() else tripped * 5.0
	# Angle 0 is the bottom of the turn; the rope rests overhead between rounds.
	_rope.rotation.x = angle if _turning else PI
