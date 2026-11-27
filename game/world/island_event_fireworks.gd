extends Node3D
## Evening fireworks over the bay (an IslandEvents event). Rockets rise from
## the lagoon east of the 海風觀景台 lookout and burst into shells of glowing sparks;
## each burst lights the water under it and flashes the island's ambient
## light. Standing at the lookout, press the shutter as a shell opens fully:
## the closer to its peak, the higher the score. The best shot is kept, and the
## first good one becomes the souvenir sticker.

const Catalog = preload("res://game/core/island_event_catalog.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const IslandScenery = preload("res://game/world/island_scenery.gd")
const AmbienceSprites = preload("res://game/world/ambience_sprites.gd")
const GLOW_SHADER := "res://game/world/firework_glow.gdshader"

const LOOKOUT_NAME := "海風觀景台"
const VIEW_RADIUS := 13.0
const MAP_RADIUS := 14.0
## Shells in flight at once; each has its sparks, a rocket and a glow on the water.
const SLOTS := 2
const SPARKS := 30
const SPARKS_SAVER := 14
const RISE_SECONDS := 1.0
const SHELL_SECONDS := 2.0
## Seconds after a shell opens when it is fullest: the moment to photograph.
const PEAK := 0.42
const SCORE_SPAN := 0.55
const STICKER_SCORE := 60
const FIRST_LAUNCH := 3.0
const INTERVAL := Vector2(3.6, 5.2)
const QUIET_END := 6.0
const SHUTTER_GAP := 0.5
const SPARK_SIZE := 0.3
const SHELL_RADIUS := 3.1
## At dusk the island dims a little for the show, as if the lights went down.
const DUSK_AIR := {"sky": Color("#5b4a6b"), "ambient": Color("#8a7a9a"), "ambient_scale": 0.72, "sun_scale": 0.4, "saturation_scale": 0.92}
const DIM_SECONDS := 3.0
const PALETTE := [Color("#ff5a3c"), Color("#ffc23d"), Color("#3fe0c4"), Color("#ff5fae"), Color("#9d7bff"), Color("#7fd4ff")]
const KINDS := ["peony", "ring", "willow"]

var participation := 0
var best := 0
var lookout := Vector3.ZERO
## Where the water begins east of the lookout (the lagoon the shells rise from).
var shore_x := 0.0
var sparks: MultiMeshInstance3D
var glows: Array[MeshInstance3D] = []

var _director: Node3D
var _world: Node3D
var _seconds := 90.0
var _clock := 0.0
var _next_launch := FIRST_LAUNCH
var _shutter_wait := 0.0
var _reduced := false
var _spark_count := SPARKS
var _trail := 2
var _batch: MultiMesh
var _glow_material: ShaderMaterial
var _flash := -1.0
var _air: Dictionary = DUSK_AIR.duplicate()
var _dim := -1.0
## One record per slot: {age (INF idle), base, apex, colour, kind, dirs}.
var _shells: Array[Dictionary] = []


func begin(director: Node3D, player: Vector3) -> void:
	_director = director
	_world = director.world
	_seconds = float(Catalog.find("fireworks").seconds)
	lookout = _find_lookout()
	shore_x = _find_shore(lookout)
	_build_sparks()
	_build_glows()
	for slot in range(SLOTS):
		var dirs := PackedVector3Array()
		dirs.resize(SPARKS)
		_shells.append({"age": INF, "base": Vector3.ZERO, "apex": Vector3.ZERO, "colour": Color.WHITE, "kind": "peony", "dirs": dirs})
	var near := Vector2(player.x - lookout.x, player.z - lookout.z).length() < VIEW_RADIUS
	director.say("煙火開始了！在觀景台等煙火開到最大時按 E 或 P。" if near else "傍晚的海灣要放煙火了！到海風觀景台（地圖上的星星）拍下最漂亮的一發。")
	director.note(4)


func step(delta: float, player: Vector3) -> bool:
	_clock += delta
	_shutter_wait = maxf(0.0, _shutter_wait - delta)
	if _clock < _seconds - QUIET_END:
		_next_launch -= delta
		if _next_launch <= 0.0:
			_launch()
			_next_launch = _director.rng().randf_range(INTERVAL.x, INTERVAL.y)
	for shell: Dictionary in _shells:
		if not is_finite(float(shell.age)): continue
		var before := float(shell.age)
		shell.age = before + delta
		if before < RISE_SECONDS and float(shell.age) >= RISE_SECONDS:
			_director.note(_director.rng().randi_range(2, 7))
		if float(shell.age) > RISE_SECONDS + SHELL_SECONDS: shell.age = INF
	_draw()
	return _clock < _seconds or _busy()


func set_look(reduced: bool, saver: bool) -> void:
	_reduced = reduced
	_spark_count = SPARKS_SAVER if saver else SPARKS
	_trail = 1 if saver or reduced else 2
	_batch.visible_instance_count = SLOTS * (_spark_count * _trail + 1)


func resume() -> void:
	_flash = -1.0
	_dim = -1.0


func prompt(player: Vector3) -> String:
	if Vector2(player.x - lookout.x, player.z - lookout.z).length() > VIEW_RADIUS or _shutter_wait > 0.0: return ""
	return "拍下煙火"


func shutter(_player: Vector3) -> void:
	_shutter_wait = SHUTTER_GAP
	var score := shot_score()
	participation += 1
	if score <= 0:
		_director.say("咔嚓⋯⋯煙火還沒開花！")
		return
	var line := "完美的一發！%d 分" % score if score >= 85 else ("拍得不錯！%d 分" % score if score >= STICKER_SCORE else "差一點點⋯⋯ %d 分" % score)
	if score > best:
		best = score
		if participation > 1: line += "（新紀錄）"
	else:
		line += "（最佳 %d 分）" % best
	if score >= STICKER_SCORE and _director.earn("fireworks"):
		line += " 獲得紀念拍貼「海灣煙火」！"
	_director.say(line)


func close() -> void:
	_world.set_event_air({})


## How good a photo taken now would be: 100 at a shell's fullest moment, 0
## when nothing is open.
func shot_score() -> int:
	var score := 0
	for shell: Dictionary in _shells:
		var open := float(shell.age) - RISE_SECONDS
		if not is_finite(open) or open < 0.0: continue
		score = maxi(score, roundi(100.0 * clampf(1.0 - absf(open - PEAK) / SCORE_SPAN, 0.0, 1.0)))
	return score


## Seconds until the next shell is fullest, for tests; INF when none is coming.
func seconds_to_peak() -> float:
	var soonest := INF
	for shell: Dictionary in _shells:
		var wait := RISE_SECONDS + PEAK - float(shell.age)
		if is_finite(wait) and wait >= 0.0: soonest = minf(soonest, wait)
	return soonest


func map_area() -> Dictionary:
	return {"center": lookout, "radius": MAP_RADIUS}


## Launches a shell now (tests use this to skip the wait).
func launch_now() -> void:
	_launch()


func _busy() -> bool:
	for shell: Dictionary in _shells:
		if is_finite(float(shell.age)): return true
	return false


func _launch() -> void:
	for shell: Dictionary in _shells:
		if is_finite(float(shell.age)): continue
		var rng: RandomNumberGenerator = _director.rng()
		var base := Vector3(shore_x + rng.randf_range(1.5, 5.5), IslandScenery.SEA_Y, lookout.z + rng.randf_range(-6.0, -1.0))
		while IslandShape.contains(Vector2(base.x, base.z)) and base.x < shore_x + 40.0: base.x += 2.0
		shell.age = 0.0
		shell.base = base
		shell.apex = base + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(5.0, 6.8), 0)
		shell.colour = PALETTE[rng.randi() % PALETTE.size()]
		shell.kind = KINDS[rng.randi() % KINDS.size()]
		var dirs: PackedVector3Array = shell.dirs
		var facing: Basis = _director.camera_basis()
		for index in range(SPARKS):
			if shell.kind == "ring":
				# A ring faces the camera, so it reads as a circle.
				var angle := TAU * index / SPARKS
				dirs[index] = facing.x * cos(angle) + facing.y * sin(angle)
			else:
				# Even shell directions (golden spiral), so no clumps or holes.
				var y := 1.0 - 2.0 * (index + 0.5) / SPARKS
				var ring := sqrt(1.0 - y * y)
				var turn := index * 2.39996
				dirs[index] = Vector3(cos(turn) * ring, y, sin(turn) * ring)
		return


## Writes every spark, rocket and water glow for this frame. No allocations.
func _draw() -> void:
	var facing: Basis = _director.camera_basis()
	var stride := _spark_count * _trail + 1
	var brightest := 0.0
	for slot in range(SLOTS):
		var shell: Dictionary = _shells[slot]
		var first := slot * stride
		var age := float(shell.age)
		var colour: Color = shell.colour
		var glow := glows[slot] if slot < glows.size() else null
		if not is_finite(age):
			for index in range(stride): _batch.set_instance_transform(first + index, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			if glow != null: glow.visible = false
			continue
		var base: Vector3 = shell.base
		var apex: Vector3 = shell.apex
		# The rocket: a bright point climbing with a little wobble (straight up under reduced motion).
		var rocket := first + stride - 1
		if age < RISE_SECONDS and not _reduced:
			var t := age / RISE_SECONDS
			var climb := base.lerp(apex, 1.0 - (1.0 - t) * (1.0 - t)) + facing.x * sin(age * 18.0) * 0.06
			_batch.set_instance_transform(rocket, Transform3D(facing.scaled(Vector3.ONE * SPARK_SIZE * 0.8), climb))
			_batch.set_instance_color(rocket, Color(1.0, 0.9, 0.7, 1.0))
		else:
			_batch.set_instance_transform(rocket, Transform3D(Basis().scaled(Vector3.ZERO), apex))
		var open := age - RISE_SECONDS
		var light := _shell_light(open)
		brightest = maxf(brightest, light)
		var drop := 1.6 if shell.kind == "willow" else 0.7
		var dirs: PackedVector3Array = shell.dirs
		for index in range(_spark_count):
			var direction: Vector3 = dirs[int(index * SPARKS / float(_spark_count))]
			for tail in range(_trail):
				var lag := open - tail * 0.09
				var at := apex + direction * SHELL_RADIUS * _spread(lag) - Vector3(0, 0.5 * drop * maxf(0.0, lag) * maxf(0.0, lag), 0) if not _reduced else apex + direction * SHELL_RADIUS * 0.85
				var size := SPARK_SIZE * (1.0 if tail == 0 else 0.62) * (0.0 if open < 0.0 else 1.0)
				var slot_index := first + index * _trail + tail
				_batch.set_instance_transform(slot_index, Transform3D(facing.scaled(Vector3.ONE * size), at))
				var fade := light * (1.0 if tail == 0 else 0.45)
				_batch.set_instance_color(slot_index, Color(colour.r * fade, colour.g * fade, colour.b * fade, 1.0))
		if glow != null:
			glow.visible = light > 0.01
			glow.global_position = Vector3(apex.x, IslandScenery.SEA_Y + 0.05, base.z + 2.5)
			glow.set_instance_shader_parameter("glow_color", colour)
			glow.set_instance_shader_parameter("strength", light)
	if _glow_material != null: _glow_material.set_shader_parameter("clock", 0.0 if _reduced else _clock)
	var flash := 0.0 if _reduced else brightest * 0.28
	var dim := _dimming()
	if absf(flash - _flash) > 0.01 or (flash == 0.0 and _flash != 0.0) or dim != _dim:
		_flash = flash
		_dim = dim
		_air["flash"] = flash
		_air["amount"] = dim
		_world.set_event_air(_air)


## How far the dusk light is lowered: in over the first seconds, back up at the end.
func _dimming() -> float:
	if str(_world.active_time_phase) != "dusk": return 0.0
	var t := minf(_clock / DIM_SECONDS, (_seconds - _clock) / DIM_SECONDS)
	return snappedf(clampf(t, 0.0, 1.0) * 0.5, 0.01)


## Brightness of an open shell: a quick bloom, held, then a long fade. Under
## reduced motion it simply eases in and out.
func _shell_light(open: float) -> float:
	if open < 0.0: return 0.0
	if _reduced: return sin(clampf(open / SHELL_SECONDS, 0.0, 1.0) * PI)
	return smoothstep(0.0, 0.06, open) * (1.0 - smoothstep(0.55, SHELL_SECONDS, open))


## How far the sparks have flown, 0..1: fast at first, then easing out.
func _spread(open: float) -> float:
	return 0.0 if open <= 0.0 else 1.0 - exp(-open * 5.0)


func _find_lookout() -> Vector3:
	for area: Array in IslandShape.AREAS:
		if area[0] == LOOKOUT_NAME: return Vector3(float(area[1]), 0, float(area[2]))
	push_warning("The fireworks lookout %s is not on the island; using the plaza." % LOOKOUT_NAME)
	return Vector3.ZERO


## The x of the shore east of the lookout (the lagoon lies beyond it).
func _find_shore(from: Vector3) -> float:
	var x := from.x
	while x < from.x + 60.0 and IslandShape.contains(Vector2(x, from.z)):
		x += 1.0
	return x


func _build_sparks() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = AmbienceSprites.mote("glow")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.disable_fog = true
	# Above 1 so open shells pass the bloom threshold.
	material.albedo_color = Color(1.7, 1.7, 1.7, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_batch = MultiMesh.new()
	_batch.transform_format = MultiMesh.TRANSFORM_3D
	_batch.use_colors = true
	_batch.mesh = quad
	_batch.instance_count = SLOTS * (SPARKS * 2 + 1)
	_batch.custom_aabb = AABB(lookout + Vector3(-40, -4, -60), Vector3(80, 40, 80))
	for index in range(_batch.instance_count):
		_batch.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	sparks = MultiMeshInstance3D.new()
	sparks.name = "FireworkSparks"
	sparks.multimesh = _batch
	sparks.material_override = material
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)


func _build_glows() -> void:
	if not ResourceLoader.exists(GLOW_SHADER):
		push_warning("Firework glow shader is missing; the bay stays dark under the fireworks.")
		return
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = load(GLOW_SHADER)
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.6, 8.0)
	for slot in range(SLOTS):
		var glow := MeshInstance3D.new()
		glow.name = "FireworkGlow%d" % slot
		glow.mesh = plane
		glow.material_override = _glow_material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = false
		add_child(glow)
		glows.append(glow)
