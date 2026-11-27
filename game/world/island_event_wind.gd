extends Node3D
## Windy afternoon (an IslandEvents event). A gust sends leaves streaming past
## the camera, sets the lawn and trees swaying harder and tears a balloon loose
## next to the walker. It bobs away on the wind over walkable ground, a little
## slower than a run; touch it before the time runs out to catch it (the
## souvenir sticker the first time). Missed, it sails off into the sky and the
## hero waves it goodbye; one more gust gives a second balloon.

const WorldAmbience = preload("res://game/world/world_ambience.gd")

enum Stage { GUST, CHASE, CAUGHT, LOST, LULL, DONE }

## The island's shared wind blows this way (see wind.gdshaderinc).
const WIND := Vector2(0.86, 0.51)
const GUST_SECONDS := 1.4
const CHASE_SECONDS := 25.0
const CAUGHT_SECONDS := 2.2
const LOST_SECONDS := 3.2
const LULL_SECONDS := 4.0
const TRIES := 2
const CATCH_RADIUS := 1.15
## Average drift a little under the walker's run (1.5 m/s), faster in gusts.
const DRIFT := 1.1
const DRIFT_GUST := 0.55
const FLOAT_HEIGHT := 1.45
const LEAVES := 40
const LEAVES_SAVER := 16
const GUST_SWAY := 1.6
const TURNS := [0.0, 30.0, -30.0, 60.0, -60.0, 95.0, -95.0, 135.0, -135.0, 180.0]
const BALLOON_TONES := [Color("#ef5f57"), Color("#f2b43c")]

var participation := 0
var stage := Stage.GUST
var tries := 0
var balloon: Node3D
var leaves: CPUParticles3D

var _director: Node3D
var _world: Node3D
var _stage_time := 0.0
var _clock := 0.0
var _heading := WIND
var _reduced := false
var _body_material: StandardMaterial3D
var _string: MeshInstance3D
var _shadow: MeshInstance3D
var _float := Vector3.ZERO
var _warned := false


func begin(director: Node3D, player: Vector3) -> void:
	_director = director
	_world = director.world
	_build_balloon()
	if director.can_draw_particles():
		leaves = WorldAmbience.make_emitter("gust_leaf", LEAVES)
		if leaves != null: add_child(leaves)
	_release(player)


func step(delta: float, player: Vector3) -> bool:
	_stage_time += delta
	_clock += delta
	var gust := 0.5 + 0.5 * sin(_clock * 1.3) * sin(_clock * 0.47 + 1.0)
	if is_instance_valid(_world.ambience): _world.ambience.gust = 0.0 if _reduced else GUST_SWAY * (0.6 + gust)
	match stage:
		Stage.GUST:
			_drift(delta, gust * 1.6)
			if _stage_time >= GUST_SECONDS: _next(Stage.CHASE)
		Stage.CHASE:
			_drift(delta, gust)
			if _gap(player) <= CATCH_RADIUS:
				_catch(player)
			elif _stage_time >= CHASE_SECONDS:
				_lose()
			elif not _warned and _stage_time >= CHASE_SECONDS - 8.0:
				_warned = true
				_director.say("快！氣球要飛走了！")
		Stage.CAUGHT:
			# Held up in the hero's hand, swaying.
			_float = player + Vector3(0.25, 1.95, 0)
			if _stage_time >= CAUGHT_SECONDS: _next(Stage.DONE)
		Stage.LOST:
			# Off it sails, up and away, shrinking into the sky.
			var climb := _stage_time / LOST_SECONDS
			_float += Vector3(WIND.x, 0, WIND.y) * delta * 2.0 + Vector3(0, delta * (1.5 + climb * 6.0), 0)
			balloon.scale = Vector3.ONE * maxf(0.05, 1.0 - climb * 0.9)
			if _stage_time >= LOST_SECONDS:
				balloon.visible = false
				_next(Stage.LULL if tries < TRIES else Stage.DONE)
		Stage.LULL:
			if _stage_time >= LULL_SECONDS: _release(player)
	_place_balloon(delta)
	_update_leaves(player)
	return stage != Stage.DONE


func set_look(reduced: bool, saver: bool) -> void:
	_reduced = reduced
	if leaves != null:
		leaves.amount = LEAVES_SAVER if saver else LEAVES
		leaves.visible = not reduced
		leaves.emitting = not reduced and stage in [Stage.GUST, Stage.CHASE]


func resume() -> void:
	pass


func prompt(_player: Vector3) -> String:
	return ""


func shutter(_player: Vector3) -> void:
	pass


func close() -> void:
	if is_instance_valid(_world.ambience): _world.ambience.gust = 0.0


## Where the balloon is (tests steer a walker toward it).
func balloon_position() -> Vector3:
	return Vector3(_float.x, _world.ground_surface_y(_float), _float.z)


func _next(next_stage: Stage) -> void:
	stage = next_stage
	_stage_time = 0.0


func _release(player: Vector3) -> void:
	tries += 1
	_warned = false
	var start: Vector3 = _director.spot_near(player + Vector3(WIND.x, 0, WIND.y) * 2.2, 0.0, 1.5)
	if not start.is_finite(): start = player
	_float = start + Vector3(0, FLOAT_HEIGHT, 0)
	_heading = WIND
	_body_material.albedo_color = BALLOON_TONES[(tries - 1) % BALLOON_TONES.size()]
	balloon.scale = Vector3.ONE
	balloon.visible = true
	_next(Stage.GUST)
	_director.note(5)
	if tries == 1:
		_director.say("起風了！氣球被吹走了，25 秒內追上它！")
	else:
		_director.say("又一陣風！另一顆氣球也飛走了，追！")


## Drifts downwind over ground the walker can reach, weaving a little.
func _drift(delta: float, gust: float) -> void:
	var speed := DRIFT + DRIFT_GUST * (gust * 2.0 - 1.0)
	var wish := WIND.rotated(deg_to_rad(sin(_clock * 0.8) * 35.0))
	_heading = _heading.lerp(wish, minf(1.0, delta * 0.8)).normalized()
	for turn: float in TURNS:
		var heading := _heading.rotated(deg_to_rad(turn))
		var ahead := _float + Vector3(heading.x, 0, heading.y) * 1.6
		if _director.open_ground(ahead):
			_heading = heading
			_float += Vector3(heading.x, 0, heading.y) * speed * delta
			return
	# Boxed in against the shore or a closed gate: it hovers in place.


func _catch(player: Vector3) -> void:
	participation += 1
	_next(Stage.CAUGHT)
	_director.sfx("success")
	_world.play_action("celebrate")
	if leaves != null: leaves.emitting = false
	if is_instance_valid(_world.ambience): _world.ambience.gust = 0.0
	_float = player + Vector3(0.25, 1.95, 0)
	if _director.earn("wind"):
		_director.say("抓到氣球了！獲得紀念拍貼「追風氣球」。")
	else:
		_director.say("抓到氣球了！")


func _lose() -> void:
	_next(Stage.LOST)
	_director.sfx("miss")
	_world.play_action("wave")
	_director.say("氣球飛走了⋯⋯掰掰～" if tries < TRIES else "氣球越飛越高⋯⋯風停了，下次再追吧！")


func _gap(player: Vector3) -> float:
	return Vector2(_float.x - player.x, _float.z - player.z).length()


func _place_balloon(delta: float) -> void:
	if not balloon.visible: return
	var bob := 0.0 if _reduced else sin(_clock * 2.3) * 0.18
	var ground: float = _world.ground_surface_y(_float)
	var lift := _float.y if stage in [Stage.CAUGHT, Stage.LOST] else ground + FLOAT_HEIGHT
	_float.y = lift
	balloon.global_position = Vector3(_float.x, lift + bob, _float.z)
	# The string trails upwind and the balloon leans with the gust.
	var lean := 0.0 if _reduced else sin(_clock * 1.7) * 0.18
	balloon.rotation = Vector3(WIND.y * 0.15 + lean * 0.4, 0, -WIND.x * 0.15 - lean)
	if is_instance_valid(_shadow):
		_shadow.visible = stage != Stage.LOST
		_shadow.global_position = Vector3(_float.x, ground + 0.02, _float.z)
		_shadow.global_rotation = Vector3.ZERO


func _update_leaves(player: Vector3) -> void:
	if leaves == null: return
	var blowing := not _reduced and stage in [Stage.GUST, Stage.CHASE, Stage.LOST]
	if leaves.emitting != blowing: leaves.emitting = blowing
	# Leaves enter from the upwind side of the view and stream across it.
	leaves.global_position = player + Vector3(-WIND.x * 9.0, 2.2, -WIND.y * 4.0)


func _build_balloon() -> void:
	balloon = Node3D.new()
	balloon.name = "WindBalloon"
	add_child(balloon)
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = BALLOON_TONES[0]
	_body_material.roughness = 0.28
	_body_material.clearcoat_enabled = true
	_body_material.clearcoat = 0.8
	_body_material.rim_enabled = true
	_body_material.rim = 0.35
	var shell := SphereMesh.new()
	shell.radius = 0.42
	shell.height = 0.96
	shell.radial_segments = 20
	shell.rings = 10
	var body := MeshInstance3D.new()
	body.name = "BalloonBody"
	body.mesh = shell
	body.material_override = _body_material
	body.position.y = 0.48
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	balloon.add_child(body)
	var knot_mesh := CylinderMesh.new()
	knot_mesh.top_radius = 0.0
	knot_mesh.bottom_radius = 0.07
	knot_mesh.height = 0.09
	var knot := MeshInstance3D.new()
	knot.name = "BalloonKnot"
	knot.mesh = knot_mesh
	knot.material_override = _body_material
	knot.position.y = -0.02
	knot.rotation.x = PI
	knot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	balloon.add_child(knot)
	var cord := CylinderMesh.new()
	cord.top_radius = 0.008
	cord.bottom_radius = 0.008
	cord.height = 1.0
	cord.radial_segments = 4
	cord.rings = 1
	var cord_material := StandardMaterial3D.new()
	cord_material.albedo_color = Color("#f3ead8")
	_string = MeshInstance3D.new()
	_string.name = "BalloonString"
	_string.mesh = cord
	_string.material_override = cord_material
	_string.position.y = -0.55
	_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	balloon.add_child(_string)
	# Its shadow stays on the ground below, so the height reads.
	var blob := PlaneMesh.new()
	blob.size = Vector2(0.62, 0.44)
	_shadow = MeshInstance3D.new()
	_shadow.name = "BalloonShadow"
	_shadow.mesh = blob
	_shadow.material_override = _world.contact_shadow_material
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	balloon.visible = false
