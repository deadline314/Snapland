extends "res://game/world/field/field_game.gd"
## A gull has snatched a hat and zig-zags over the lawn. Touch it three
## times to get the hat back; each touch makes it faster. Stand still and
## it cannot resist circling you to gloat, which is the moment to pounce.

enum { FLEE, TAUNT, DASH, GONE }

const TOUCHES_TO_WIN := 3
const TOUCH_POINTS := 10
const TOUCH_REACH := 0.9
const BASE_SPEED := 1.3
const SPEED_PER_TOUCH := 0.15
const HEAD_START := 3.0
const DASH_SECONDS := 0.8
const ZIG_SECONDS := 0.85
const ZIG_ANGLE := 0.8
const TAUNT_AFTER := 1.6
const TAUNT_RADIUS := 1.9
## How long the gull keeps gloating after the player starts to move.
const STARTLE_SECONDS := 0.15
const STILL_SPEED := 0.3
const TAUNT_TURN := 1.5
const FLY_HEIGHT := 1.25
const GULL_SIZE := 1.5
const HAT_SIZE := 2.0

var gull := Vector2.ZERO
var touches := 0
var mode := GONE

var _batch: Kit.SpriteBatch
var _shadow: MeshInstance3D
var _zig := 1.0
var _zig_in := 0.0
var _dash := 0.0
var _dash_from := Vector2.ZERO
var _dash_to := Vector2.ZERO
var _still := 0.0
var _startle := 0.0
var _orbit := 0.0
var _last_player := Vector2(INF, INF)
var _heading := Vector2.RIGHT
var _wing := 0.0
var _won := false
var _show_clock := 0.0


func build() -> void:
	_batch = Kit.SpriteBatch.new(world, 2, 40.0)
	add_child(_batch)
	_batch.tint(0, Color(1.5, 1.5, 1.46))
	_batch.tint(1, Color(1.15, 1.15, 1.15))
	var blob := PlaneMesh.new()
	blob.size = Vector2(1.3, 0.8)
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_texture = Kit.Sprites.shadow_blob()
	_shadow = Kit.mesh(self, blob, Vector3.ZERO, shade, false)


func reset() -> void:
	mode = GONE
	_won = false
	_draw(Vector3.ZERO)


func begin() -> void:
	var middle := centre()
	# Starts out of reach, on the far side of the lawn from the player.
	var feet: Vector3 = world.player.global_position
	var away := Vector2(middle.x - feet.x, middle.z - feet.z)
	gull = Vector2(middle.x, middle.z) + (away.normalized() if away.length() > 0.5 else Vector2.RIGHT.rotated(rng.randf() * TAU)) * HEAD_START
	touches = 0
	mode = FLEE
	_zig = 1.0
	_zig_in = ZIG_SECONDS
	_still = 0.0
	_startle = 0.0
	_dash = 0.0
	_last_player = Vector2(INF, INF)
	_draw(middle)


func step(delta: float, player: Vector3) -> void:
	var feet := Vector2(player.x, player.z)
	var speed := 0.0 if _last_player.x == INF else feet.distance_to(_last_player) / maxf(delta, 0.0001)
	_last_player = feet
	_still = _still + delta if speed < STILL_SPEED else 0.0
	_wing += delta
	var middle := centre()
	var home := Vector2(middle.x, middle.z)
	var away := gull - feet
	var gap := away.length()
	away = away / gap if gap > 0.001 else Vector2.RIGHT
	if _dash > 0.0:
		_dash -= delta
		var escape := _dash_from.lerp(_dash_to, smoothstep(0.0, 1.0, 1.0 - _dash / DASH_SECONDS))
		_move(escape - gull, home)
		if _dash <= 0.0:
			mode = FLEE
	else:
		if _still >= TAUNT_AFTER:
			_startle = STARTLE_SECONDS
		else:
			_startle -= delta
		mode = TAUNT if _startle > 0.0 else FLEE
		if mode == TAUNT:
			# Close in from its own side, then loop around the player just out of reach.
			if gap > TAUNT_RADIUS + 0.4:
				_orbit = (gull - feet).angle()
			else:
				_orbit += TAUNT_TURN * delta
			var target := feet + Vector2(cos(_orbit), sin(_orbit)) * TAUNT_RADIUS
			_move((target - gull).limit_length(2.6 * delta), home)
		else:
			_zig_in -= delta
			if _zig_in <= 0.0:
				_zig_in = ZIG_SECONDS * rng.randf_range(0.8, 1.25)
				_zig = -_zig
			_orbit = (gull - feet).angle()
			var heading := away.rotated(_zig * ZIG_ANGLE)
			var from_home := gull - home
			var rim := smoothstep(0.6, 1.0, from_home.length() / float(spec.roam))
			if rim > 0.0:
				# Near the edge of its lawn it slides along the rim, away from the player.
				var outward := from_home.normalized()
				var along := Vector2(-outward.y, outward.x)
				if along.dot(away) < 0.0:
					along = -along
				heading = heading.lerp(along - outward * 0.3, rim).normalized()
			_move(heading * (BASE_SPEED + SPEED_PER_TOUCH * touches) * delta, home)
		# It has to be reached for: a gull brushing past a standing player does not count.
		if speed >= STILL_SPEED and gull.distance_to(feet) < TOUCH_REACH:
			_touch(feet, home)
	_draw(player)


func _move(offset: Vector2, home: Vector2) -> void:
	if offset.length_squared() > 0.000001:
		_heading = offset
	gull = home + (gull + offset - home).limit_length(float(spec.roam))


func _touch(feet: Vector2, home: Vector2) -> void:
	touches += 1
	add_score(TOUCH_POINTS)
	note(touches)
	feedback("hit")
	if touches >= TOUCHES_TO_WIN:
		# Seconds left on the clock are the bonus for a quick catch.
		add_score(int(seconds - elapsed))
		_won = true
		finish()
		return
	field.say("嘎！還差 %d 下" % (TOUCHES_TO_WIN - touches), 1.0)
	# It swoops clean across to the far side of its lawn.
	var across := home - feet
	across = across.normalized() if across.length() > 0.5 else (gull - feet).normalized()
	_dash = DASH_SECONDS
	_dash_from = gull
	_dash_to = home + across.rotated(rng.randf_range(-0.7, 0.7)) * float(spec.roam) * 0.8
	mode = DASH
	_still = 0.0
	_startle = 0.0


func conclude(_medal: int) -> void:
	_show_clock = 0.0
	mode = GONE if _won else TAUNT


func show_step(delta: float, player: Vector3) -> void:
	_show_clock += delta
	_wing += delta
	if not _won and not reduced():
		# It keeps the hat and does a victory lap right over your head.
		_orbit += 3.4 * delta
		gull = Vector2(player.x, player.z) + Vector2(cos(_orbit), sin(_orbit)) * 1.3
		_heading = Vector2(-sin(_orbit), cos(_orbit))
	_draw(player)


func _draw(player: Vector3) -> void:
	_shadow.visible = mode != GONE
	if mode == GONE:
		_batch.hide_item(0)
		if _won:
			# The hat is back where it belongs.
			var toward_camera: Vector3 = world.camera.global_basis.z * 0.2 if is_instance_valid(world.camera) else Vector3.ZERO
			_batch.put(1, player + Vector3(0, 2.0 + world.avatar_visual_lift, 0) + toward_camera, "hat", 0, false, HAT_SIZE)
		else:
			_batch.hide_item(1)
		return
	var ground := world.ground_surface_y(Vector3(gull.x, 0, gull.y)) as float
	var bob := 0.0 if reduced() else sin(_wing * 5.0) * 0.12
	var at := Vector3(gull.x, ground + FLY_HEIGHT + bob, gull.y)
	var flap := 0 if reduced() else (1 if fmod(_wing * 4.5, 1.0) < 0.5 else 2)
	var left := _heading.x < 0.0
	_batch.put(0, at, "gull", flap, left, GULL_SIZE)
	_batch.put(1, at + Vector3(-0.66 if left else 0.66, -0.3, 0.05), "hat", 0, left, HAT_SIZE)
	_shadow.position = Vector3(gull.x, ground + 0.03, gull.y)
