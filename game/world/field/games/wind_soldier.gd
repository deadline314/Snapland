extends "res://game/world/field/field_game.gd"
## Red light, green light with a clockwork soldier. Creep up while his back
## is turned and touch him; he then springs to the other end of the lane and
## you go again. A drum roll warns that he is about to turn round: anyone he
## sees moving makes him boing away to the far end. His back-turned spells
## get shorter, and later he fakes a turn now and then. Getting caught costs
## you a touch.

enum { BACK, WARN, LOOK, HOP }

const TOUCH_REACH := 0.85
const STILL_SPEED := 0.25
const WARN_SECONDS := 0.55
const LOOK_SECONDS := 1.5
## How long a visitor may still be stopping after he turns.
const GRACE_SECONDS := 0.2
const HOP_SECONDS := 0.7
const LONG_BACK := 2.6
const SHORT_BACK := 1.2

var mode := BACK
## 0 or 1: which end of the lane he stands at.
var post := 1
var touches := 0
var caught := 0
var fakes := 0

var _ends: Array[Vector3] = []
var _soldier: Node3D
var _key: Node3D
var _shout: Label3D
var _clock := 0.0
var _span := 0.0
var _fake := false
var _last := Vector3(INF, 0, INF)
var _hop_from := Vector3.ZERO
var _show := 0.0
var _salute := false


func build() -> void:
	var layout: Array = spec.get("layout", [])
	_ends = [spot(layout[0]), spot(layout[1])]
	# A painted lane with a start line at each end.
	var middle := (_ends[0] + _ends[1]) * 0.5
	var lane := Kit.box(self, middle + Vector3(0, 0.02, 0), Vector3(2.0, 0.04, _ends[0].distance_to(_ends[1]) + 1.2), world._coastal_surface(Kit.TILE_CANVAS, 1.0, Color("#b7cf8a")))
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for end in _ends:
		Kit.box(self, end + Vector3(0, 0.05, 0), Vector3(2.0, 0.03, 0.12), world._mat(Color("#fff3ec"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_soldier = Node3D.new()
	add_child(_soldier)
	var coat: Material = world._mat(Color("#d9454e"))
	Kit.cylinder(_soldier, Vector3(0, 0.06, 0), 0.32, 0.12, world._wood_material(Color("#7a5a3c")), 0.28, 12)
	Kit.cylinder(_soldier, Vector3(0, 0.38, 0), 0.13, 0.52, world._mat(Color("#2f3a5c")), 0.15, 10)
	Kit.cylinder(_soldier, Vector3(0, 0.88, 0), 0.22, 0.5, coat, 0.18, 12)
	Kit.box(_soldier, Vector3(0, 0.9, 0.0), Vector3(0.46, 0.06, 0.42), world._mat(Color("#f2c75a")))
	Kit.ball(_soldier, Vector3(0, 1.32, 0), 0.19, world._mat(Color("#f5d2b0")))
	Kit.cylinder(_soldier, Vector3(0, 1.66, 0), 0.17, 0.42, world._mat(Color("#2a2730")), 0.19, 12)
	Kit.ball(_soldier, Vector3(0, 1.9, 0), 0.07, world._mat(Color("#f2c75a")))
	# Eyes and rosy cheeks on his front, so you can tell which way he faces.
	for side: float in [-1.0, 1.0]:
		Kit.ball(_soldier, Vector3(side * 0.07, 1.36, 0.17), 0.028, world._mat(Color("#2a2730")))
		Kit.ball(_soldier, Vector3(side * 0.11, 1.27, 0.15), 0.035, world._mat(Color("#ef8f8f")))
	_key = Node3D.new()
	_key.position = Vector3(0, 0.95, -0.26)
	_soldier.add_child(_key)
	Kit.cylinder(_key, Vector3(0, 0, -0.06), 0.03, 0.14, world._coastal_surface(Kit.TILE_BRASS, 0.3), -1.0, 6).rotation.x = PI * 0.5
	Kit.box(_key, Vector3(0, 0, -0.14), Vector3(0.28, 0.12, 0.03), world._coastal_surface(Kit.TILE_BRASS, 0.3))
	_shout = Kit.label(self, "", Vector3.ZERO, 52, Color("#fff6de"))
	_shout.no_depth_test = true


func reset() -> void:
	mode = BACK
	post = 1
	_salute = false
	_shout.text = ""
	_draw(Vector3(INF, 0, INF))


func begin() -> void:
	touches = 0
	caught = 0
	fakes = 0
	post = 1
	_turn_back()
	_last = Vector3(INF, 0, INF)


func soldier_at() -> Vector3:
	return _ends[post]


## True while he is watching (moving now gets you caught).
func watching() -> bool:
	return mode == LOOK and _clock >= GRACE_SECONDS


func _turn_back() -> void:
	mode = BACK
	_clock = 0.0
	_span = lerpf(LONG_BACK, SHORT_BACK, pace()) * (0.75 + rng.randf() * 0.5)


func step(delta: float, player: Vector3) -> void:
	var speed := 0.0 if _last.x == INF else flat_distance(player, _last) / maxf(delta, 0.0001)
	_last = player
	_clock += delta
	match mode:
		BACK:
			if flat_distance(player, soldier_at()) < TOUCH_REACH:
				_touched()
			elif _clock >= _span:
				mode = WARN
				_clock = 0.0
				_fake = pace() > 0.4 and rng.randf() < 0.3
				note(0)
		WARN:
			if flat_distance(player, soldier_at()) < TOUCH_REACH:
				_touched()
			elif _clock >= WARN_SECONDS:
				if _fake:
					fakes += 1
					_turn_back()
				else:
					mode = LOOK
					_clock = 0.0
					note(2)
		LOOK:
			if watching() and speed > STILL_SPEED:
				_caught()
			elif _clock >= LOOK_SECONDS:
				_turn_back()
		HOP:
			if _clock >= HOP_SECONDS:
				_turn_back()
	_draw(player)


func _touched() -> void:
	touches += 1
	add_score(1)
	note(touches)
	feedback("success")
	_spring_to(1 - post)


func _caught() -> void:
	caught += 1
	score = maxi(0, score - 1)
	feedback("miss")
	field.say("看到你動了！", 1.0)
	hop(0.35, 0.4)
	# He springs off to whichever end is farther from you.
	var far := 0 if flat_distance(_last, _ends[0]) > flat_distance(_last, _ends[1]) else 1
	_spring_to(far)


func _spring_to(end: int) -> void:
	_hop_from = soldier_at()
	post = end
	mode = HOP
	_clock = 0.0


func conclude(medal: int) -> void:
	_salute = medal > 0
	_show = 0.0
	mode = LOOK
	_clock = 0.0


func show_step(delta: float, player: Vector3) -> void:
	_show += delta
	_draw(player)


func _draw(player: Vector3) -> void:
	var at := soldier_at()
	var lift := 0.0
	if mode == HOP:
		var along := clampf(_clock / HOP_SECONDS, 0.0, 1.0)
		at = _hop_from.lerp(soldier_at(), along)
		lift = 0.0 if reduced() else sin(along * PI) * 1.2
	_soldier.position = at + Vector3(0, lift, 0)
	# Facing the visitor when he looks, the far end when his back is turned.
	var toward := (player if player.is_finite() else _ends[1 - post]) - at
	var away := _ends[1 - post] - at
	var face := toward if mode == LOOK else -away
	if mode == WARN and not reduced():
		face = -away.rotated(Vector3.UP, sin(_clock * 30.0) * 0.15)
	_soldier.rotation.y = atan2(face.x, face.z)
	_key.rotation.z = 0.0 if reduced() else world.time * (2.0 if mode == BACK else 8.0)
	_shout.position = at + Vector3(0, 2.5 + lift, 0)
	var line := ""
	match mode:
		WARN: line = "咚咚咚…"
		LOOK: line = "不許動！"
		HOP: line = "啵嚶～"
	if _show > 0.0 or (mode == LOOK and _salute):
		line = "敬禮！" if _salute else "又抓到了！"
	Kit.write(_shout, line, Color("#f2c75a") if mode == LOOK else Color("#fff6de"))
