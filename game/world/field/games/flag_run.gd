extends "res://game/world/field/field_game.gd"
## Run through numbered flag gates in order before time runs out. The first
## lap follows the ring; every later lap deals the numbers out again, so the
## route keeps crossing over itself. A wrong gate honks and sulks.

const GATE_REACH := 0.95
const GATE_HALF_WIDTH := 0.95
const GATE_HEIGHT := 2.1
const WRONG_SECONDS := 0.5
const BANNER_COLORS := [Color("#da705c"), Color("#edbb65"), Color("#4b9b9c"), Color("#d5dfc0"), Color("#e59ab0"), Color("#7fc4f2")]

var gates := PackedVector3Array()
## order[n] is the gate that carries number n + 1 this lap.
var order := PackedInt32Array()
var target := 0
var laps := 0
var wrong := 0

var _numbers: Array[Label3D] = []
var _digits: Array[String] = []
var _arrow: Label3D
var _inside := PackedByteArray()
var _wrong_time := PackedFloat32Array()
var _clock := 0.0
var _running := false
var _lost := false


func build() -> void:
	var posts: Array[Vector3] = []
	var banners: Array[Transform3D] = []
	var middle := centre()
	for offset: Vector2 in spec.get("layout", []):
		var gate := spot(offset)
		gates.append(gate)
		# Each gate faces the middle of the course.
		var across := Vector3(gate.z - middle.z, 0, middle.x - gate.x).normalized()
		posts.append(gate - across * GATE_HALF_WIDTH)
		posts.append(gate + across * GATE_HALF_WIDTH)
		banners.append(Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP)), gate + Vector3(0, GATE_HEIGHT - 0.06, 0)))
		var number := Kit.label(self, "", gate + Vector3(0, GATE_HEIGHT + 0.75, 0), 64, Color("#fff6de"))
		number.no_depth_test = true
		_numbers.append(number)
		_digits.append(str(_numbers.size()))
	Kit.posts(world, self, posts, GATE_HEIGHT, Color("#f2c75a"), 0.07)
	var cloth := BoxMesh.new()
	cloth.size = Vector3(GATE_HALF_WIDTH * 2.0, 0.5, 0.04)
	var colors: Array[Color] = []
	colors.assign(BANNER_COLORS)
	Kit.batch(self, cloth, banners, world._vertex_color_material("field-banners"), colors)
	_arrow = Kit.label(self, "▼", Vector3.ZERO, 72, Color("#f2c75a"))
	_arrow.no_depth_test = true
	order.resize(gates.size())
	_inside.resize(gates.size())
	_wrong_time.resize(gates.size())


func reset() -> void:
	_running = false
	_lost = false
	_deal(false)
	_draw()


func begin() -> void:
	target = 0
	laps = 0
	wrong = 0
	_clock = 0.0
	_inside.fill(0)
	_wrong_time.fill(0.0)
	_deal(false)
	_running = true
	_draw()


## Gate numbers for the next lap: the ring first, then shuffled.
func _deal(shuffled: bool) -> void:
	var last := order[order.size() - 1] if shuffled else -1
	for index in range(order.size()):
		order[index] = index
	if not shuffled:
		return
	for index in range(order.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := order[index]
		order[index] = order[other]
		order[other] = held
	if order[0] == last:
		# The gate just passed never opens the next lap.
		order[0] = order[order.size() - 1]
		order[order.size() - 1] = last


func step(delta: float, player: Vector3) -> void:
	_clock += delta
	for index in range(gates.size()):
		_wrong_time[index] = maxf(0.0, _wrong_time[index] - delta)
		var inside := flat_distance(player, gates[index]) < GATE_REACH
		var entered := inside and _inside[index] == 0
		_inside[index] = int(inside)
		if not entered:
			continue
		if index == order[target]:
			add_score(1)
			note(target)
			target += 1
			if target == gates.size():
				target = 0
				laps += 1
				feedback("success")
				_deal(true)
		else:
			wrong += 1
			_wrong_time[index] = WRONG_SECONDS
			feedback("miss")
	_draw()


func conclude(medal: int) -> void:
	_running = false
	_lost = medal == 0
	_draw()


func _draw() -> void:
	for number in range(order.size()):
		var gate := order[number]
		var label := _numbers[gate]
		var is_wrong := _wrong_time[gate] > 0.0
		var is_next := _running and number == target
		Kit.write(label, "？" if _lost else ("✗" if is_wrong else _digits[number]), Color("#da705c") if is_wrong else (Color("#f2c75a") if is_next else Color("#fff6de")))
		label.visible = _running or _lost
	_arrow.visible = _running
	if _running:
		var bounce := 0.0 if reduced() else absf(sin(_clock * 5.0)) * 0.22
		_arrow.position = gates[order[target]] + Vector3(0, GATE_HEIGHT + 1.6 + bounce, 0)
