extends "res://game/world/field/field_game.gd"
## A hungry customer calls an order of skewers one by one, then waits. Step
## on the grill plates in the same order to cook it. Every order served makes
## the next one longer and the calling quicker; a wrong plate sends up a puff
## of black smoke and a very confused customer.

enum { CALL, COOK, SERVED }

const FOODS := ["肉", "菇", "蝦", "玉"]
const FOOD_COLORS := [Color("#c9644a"), Color("#b08a5a"), Color("#ef8f6a"), Color("#f2c75a")]
const PLATE_REACH := 0.5
const SLOW_CALL := 0.85
const FAST_CALL := 0.5
const FIRST_ORDER := 3
const LONGEST_ORDER := 6
const SERVED_SECONDS := 1.1
const SMOKE_SECONDS := 1.0

var mode := CALL
var order := PackedInt32Array()
var done := 0
var length := FIRST_ORDER
var served := 0
var botched := 0

var _plates: Array[Vector3] = []
var _plate_tops: Array[MeshInstance3D] = []
var _inside := PackedByteArray()
var _sizzle := PackedFloat32Array()
var _bubble: Label3D
var _face: Label3D
var _smoke: MultiMesh
var _smoke_at := Vector3.ZERO
var _smoke_time := 0.0
var _clock := 0.0
var _show := 0.0
var _sulk := false


func build() -> void:
	var middle := centre()
	var plate := CylinderMesh.new()
	plate.top_radius = 0.42
	plate.bottom_radius = 0.48
	plate.height = 0.12
	plate.radial_segments = 12
	plate.rings = 1
	var iron: Material = world._stone_finish(Color("#3a3434"))
	var ember: Material = world._mat(Color("#ff8a4a"), true)
	world._mat(Color("#fff2b0"), true)
	for index in range(FOODS.size()):
		var at := spot(spec.layout[index])
		_plates.append(at)
		Kit.mesh(self, plate, at + Vector3(0, 0.06, 0), iron).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var top := Kit.cylinder(self, at + Vector3(0, 0.13, 0), 0.3, 0.02, ember, -1.0, 12)
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_plate_tops.append(top)
		Kit.label(self, FOODS[index], at + Vector3(0, 0.75, 0), 44, FOOD_COLORS[index].lightened(0.35))
	# The customer's stall: a counter on posts with a lantern and a talking sign.
	var stall := middle + Vector3(0, 0, -2.4)
	var legs: Array[Vector3] = [stall + Vector3(-1.0, 0, 0), stall + Vector3(1.0, 0, 0)]
	Kit.posts(world, self, legs, 2.1, Color("#f2c75a"), 0.08)
	Kit.box(self, stall + Vector3(0, 0.95, 0.05), Vector3(2.3, 0.12, 0.6), world._coastal_surface(Kit.TILE_PLANK, 0.7, Color("#c9a06a")))
	Kit.box(self, stall + Vector3(0, 0.5, 0.1), Vector3(2.1, 0.8, 0.06), world._coastal_surface(Kit.TILE_RED_BOARD, 0.8))
	var awning := Kit.box(self, stall + Vector3(0, 2.4, 0.25), Vector3(2.5, 0.08, 0.9), world._coastal_surface(Kit.TILE_CANVAS, 0.8, Color("#e8674f")))
	awning.rotation.x = 0.25
	Kit.ball(self, stall + Vector3(-0.85, 2.0, 0.5), 0.18, world._mat(Color("#f2a85a"), true))
	_face = Kit.label(self, "^o^", stall + Vector3(0, 1.45, 0.2), 56, Color("#fff6de"))
	_bubble = Kit.label(self, "", stall + Vector3(0, 3.1, 0.3), 64, Color("#fff6de"))
	_bubble.no_depth_test = true
	var puff := SphereMesh.new()
	puff.radius = 0.22
	puff.height = 0.44
	puff.radial_segments = 6
	puff.rings = 3
	var hidden: Array[Transform3D] = []
	for index in range(5):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ZERO), middle))
	var smoke := Kit.batch(self, puff, hidden, Kit.clear_material(world, Color(0.2, 0.2, 0.22, 0.7)))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke = smoke.multimesh
	_inside.resize(FOODS.size())
	_sizzle.resize(FOODS.size())


func reset() -> void:
	mode = CALL
	order.clear()
	done = 0
	_sulk = false
	_smoke_time = 0.0
	_sizzle.fill(0.0)
	_bubble.text = ""
	_face.text = "^o^"
	_draw()


func begin() -> void:
	served = 0
	botched = 0
	length = FIRST_ORDER
	_inside.fill(1)
	_next_order()


func _next_order() -> void:
	order.clear()
	for index in range(length):
		var food := rng.randi_range(0, FOODS.size() - 1)
		if index > 0 and food == order[index - 1] and rng.randf() < 0.6:
			food = (food + 1) % FOODS.size()
		order.append(food)
	done = 0
	mode = CALL
	_clock = 0.0
	_face.text = "^o^"


func call_seconds() -> float:
	return lerpf(SLOW_CALL, FAST_CALL, pace())


## The plate the order needs next, or -1 while the customer is still calling.
func wanted() -> int:
	return order[done] if mode == COOK and done < order.size() else -1


func plate(index: int) -> Vector3:
	return _plates[index]


func step(delta: float, player: Vector3) -> void:
	_clock += delta
	_smoke_time = maxf(0.0, _smoke_time - delta)
	for index in range(FOODS.size()):
		_sizzle[index] = maxf(0.0, _sizzle[index] - delta)
		var inside := flat_distance(player, _plates[index]) < PLATE_REACH
		var entered := inside and _inside[index] == 0
		_inside[index] = int(inside)
		if entered and mode == COOK:
			_cook(index)
	match mode:
		CALL:
			var called := int(_clock / call_seconds())
			if called >= order.size() + 1:
				mode = COOK
				_clock = 0.0
				note(3)
			elif called < order.size() and _clock - called * call_seconds() < delta:
				note(order[called])
		SERVED:
			if _clock >= SERVED_SECONDS:
				_next_order()
	_draw()


func _cook(index: int) -> void:
	if index == order[done]:
		done += 1
		add_score(1)
		_sizzle[index] = 0.5
		note(index)
		feedback("hit")
		if done == order.size():
			served += 1
			length = mini(LONGEST_ORDER, length + 1)
			mode = SERVED
			_clock = 0.0
			_face.text = "^▽^"
			feedback("success")
		return
	botched += 1
	_smoke_at = _plates[index]
	_smoke_time = SMOKE_SECONDS
	_face.text = "@_@"
	feedback("miss")
	field.say("這是什麼串？", 1.0)
	mode = SERVED
	_clock = 0.0


func conclude(medal: int) -> void:
	_sulk = medal == 0
	_show = 0.0
	mode = SERVED
	_face.text = "T_T" if _sulk else "^▽^"
	_bubble.text = "？？？" if _sulk else "謝謝！"


func show_step(delta: float, _player: Vector3) -> void:
	_show += delta
	if _sulk and not reduced():
		_smoke_at = _plates[int(_show * 2.0) % _plates.size()]
		_smoke_time = SMOKE_SECONDS * 0.6
	_draw()


func _draw() -> void:
	for index in range(FOODS.size()):
		var lit := _sizzle[index] > 0.0
		_plate_tops[index].material_override = world._mat(Color("#fff2b0") if lit else Color("#ff8a4a"), true)
	if mode == CALL and not order.is_empty():
		var called := clampi(int(_clock / call_seconds()), 0, order.size())
		Kit.write(_bubble, FOODS[order[called]] if called < order.size() else "", FOOD_COLORS[order[called]].lightened(0.3) if called < order.size() else Color.WHITE)
	elif mode == COOK:
		var shown := ""
		for index in range(order.size()):
			shown += "✓" if index < done else "？"
		Kit.write(_bubble, shown, Color("#fff6de"))
	elif mode == SERVED and not _sulk and _show <= 0.0:
		Kit.write(_bubble, "" if _smoke_time > 0.0 else "好吃！", Color("#f2c75a"))
	elif _show <= 0.0:
		Kit.write(_bubble, "", Color("#f2c75a"))
	for index in range(_smoke.instance_count):
		if _smoke_time <= 0.0:
			_smoke.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), _smoke_at))
			continue
		var age := 1.0 - _smoke_time / SMOKE_SECONDS
		var rise := 0.4 if reduced() else age * 1.8 + index * 0.25
		var grow := 0.8 + age * 1.2
		_smoke.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * grow), _smoke_at + Vector3(sin(index * 2.1) * 0.25, 0.4 + rise, cos(index * 2.1) * 0.2)))
