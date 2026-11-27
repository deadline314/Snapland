extends "res://game/world/field/field_game.gd"
## A clown hides a ball under one of three cups and shuffles them. Keep your
## eye on it, walk up to the right cup and press interact to lift it. Every
## round the clown swaps more and faster, and later a fourth cup joins in.
## Guess wrong and the clown laughs at you from under the cup instead.

enum { REVEAL, COVER, SHUFFLE, PICK, SHOW }

const REVEAL_SECONDS := 1.1
const COVER_SECONDS := 0.45
const SHOW_SECONDS := 1.2
const PICK_SECONDS := 5.0
const PICK_REACH := 0.75
const SLOW_SWAP := 0.62
const FAST_SWAP := 0.32
const LIFT := 0.55
const CUP_HEIGHT := 0.5

var mode := REVEAL
## slot_of[cup] is the layout slot each cup stands over.
var slot_of := PackedInt32Array()
var ball := 0
var cups := 3
var right := 0
var wrong := 0
var picked := -1

var _slots: Array[Vector3] = []
var _cups: Array[Node3D] = []
var _ball: MeshInstance3D
var _sign: Label3D
var _clock := 0.0
var _swaps := 0
var _swap_a := 0
var _swap_b := 0
var _swap_span := 0.5
var _show := 0.0
var _laugh := false


func build() -> void:
	var middle := centre()
	for offset: Vector2 in spec.get("layout", []):
		_slots.append(spot(offset))
	# A low painted table the cups slide on.
	var top_y := 0.55
	var table := middle + Vector3(0, 0, -0.6)
	Kit.box(self, table + Vector3(0, top_y, 0), Vector3(5.2, 0.1, 1.1), world._coastal_surface(Kit.TILE_RED_BOARD, 0.9))
	Kit.box(self, table + Vector3(0, top_y * 0.5, 0.52), Vector3(5.0, top_y - 0.05, 0.06), world._coastal_surface(Kit.TILE_CANVAS, 0.7, Color("#f2c75a")))
	var legs := BoxMesh.new()
	legs.size = Vector3(0.12, top_y, 0.12)
	var feet: Array[Transform3D] = []
	for x: float in [-2.45, 2.45]:
		for z: float in [-0.45, 0.45]:
			feet.append(Transform3D(Basis.IDENTITY, table + Vector3(x, top_y * 0.5, z)))
	Kit.batch(self, legs, feet, world._wood_material(Color("#7a5a3c")))
	for index in range(_slots.size()):
		_slots[index].y = table.y + top_y + 0.05
	var shell := CylinderMesh.new()
	shell.top_radius = 0.16
	shell.bottom_radius = 0.27
	shell.height = CUP_HEIGHT
	shell.radial_segments = 12
	shell.rings = 1
	var paint: Material = world._mat(Color("#d9454e"))
	var band: Material = world._mat(Color("#fff3ec"))
	for index in range(_slots.size()):
		var cup := Node3D.new()
		add_child(cup)
		Kit.mesh(cup, shell, Vector3(0, CUP_HEIGHT * 0.5, 0), paint)
		Kit.cylinder(cup, Vector3(0, CUP_HEIGHT * 0.45, 0), 0.24, 0.07, band, 0.22, 12)
		Kit.ball(cup, Vector3(0, CUP_HEIGHT + 0.03, 0), 0.06, world._mat(Color("#f2c75a")))
		_cups.append(cup)
	_ball = Kit.ball(self, Vector3.ZERO, 0.13, world._mat(Color("#f2c75a"), true))
	# The clown's sign behind the table: who is watching whom.
	var mast: Array[Vector3] = [table + Vector3(0, 0, -0.9)]
	Kit.posts(world, self, mast, 2.0, Color("#da705c"), 0.07)
	_sign = Kit.label(self, "", mast[0] + Vector3(0, 2.7, 0), 56, Color("#fff6de"))
	slot_of.resize(_slots.size())


func reset() -> void:
	cups = 3
	for index in range(slot_of.size()):
		slot_of[index] = index
	mode = REVEAL
	_clock = 0.0
	_laugh = false
	ball = 1
	picked = -1
	_sign.text = ""
	_place()


func begin() -> void:
	right = 0
	wrong = 0
	cups = 3
	_new_round()


func _new_round() -> void:
	cups = 4 if right >= 3 and _slots.size() >= 4 else 3
	for index in range(slot_of.size()):
		slot_of[index] = index
	ball = rng.randi_range(0, cups - 1)
	picked = -1
	mode = REVEAL
	_clock = 0.0
	_sign.text = "看好囉！"


func action_label() -> String:
	return "掀杯" if mode == PICK else ""


## The cup nearest the visitor that can be lifted, or -1.
func cup_near(player: Vector3) -> int:
	var best := -1
	var gap := PICK_REACH
	for index in range(cups):
		var reach := flat_distance(player, _slots[slot_of[index]])
		if reach < gap:
			gap = reach
			best = index
	return best


## Where the ball's cup is now (for visitors with sharp eyes, and tests).
func ball_slot() -> Vector3:
	return _slots[slot_of[ball]]


func step(delta: float, _player: Vector3) -> void:
	_clock += delta
	match mode:
		REVEAL:
			if _clock >= REVEAL_SECONDS:
				mode = COVER
				_clock = 0.0
				_sign.text = ""
		COVER:
			if _clock >= COVER_SECONDS:
				mode = SHUFFLE
				_clock = 0.0
				_swaps = 3 + right + int(pace() * 3.0)
				_swap_span = lerpf(SLOW_SWAP, FAST_SWAP, clampf(pace() + right * 0.06, 0.0, 1.0))
				_pick_swap()
		SHUFFLE:
			if _clock >= _swap_span:
				var held := slot_of[_swap_a]
				slot_of[_swap_a] = slot_of[_swap_b]
				slot_of[_swap_b] = held
				_swaps -= 1
				_clock = 0.0
				note(_swaps)
				if _swaps <= 0:
					mode = PICK
					_sign.text = "哪一個？"
				else:
					_pick_swap()
		PICK:
			if _clock >= PICK_SECONDS:
				_lift(-1)
		SHOW:
			if _clock >= SHOW_SECONDS:
				_new_round()
	_place()


func _pick_swap() -> void:
	_swap_a = rng.randi_range(0, cups - 1)
	_swap_b = (_swap_a + rng.randi_range(1, cups - 1)) % cups


func press() -> void:
	if mode != PICK:
		return
	_lift(cup_near(world.player.global_position))


func _lift(cup: int) -> void:
	picked = cup
	mode = SHOW
	_clock = 0.0
	if cup == ball:
		right += 1
		add_score(1)
		note(right)
		feedback("success")
		_sign.text = "猜中了！"
	else:
		wrong += 1
		feedback("miss")
		_sign.text = "哈哈哈！"
		field.say("小丑笑翻了", 0.9)


func conclude(medal: int) -> void:
	_laugh = medal == 0
	_show = 0.0
	mode = SHOW
	picked = ball
	_sign.text = "哈哈哈哈！" if _laugh else "厲害！"


func show_step(delta: float, _player: Vector3) -> void:
	_show += delta
	_place()


func _place() -> void:
	for index in range(_cups.size()):
		var cup := _cups[index]
		cup.visible = index < cups
		var at := _slots[slot_of[index]]
		if mode == SHUFFLE and (index == _swap_a or index == _swap_b):
			var along := clampf(_clock / _swap_span, 0.0, 1.0)
			var other := _swap_b if index == _swap_a else _swap_a
			var to := _slots[slot_of[other]]
			# One cup passes in front, the other behind.
			var side := 0.35 if index == _swap_a else -0.35
			at = at.lerp(to, smoothstep(0.0, 1.0, along)) + Vector3(0, 0, sin(along * PI) * side)
		var lifted := (mode == REVEAL and index == ball) or (mode == SHOW and (index == picked or index == ball))
		var dance := 0.0 if reduced() or not _laugh else absf(sin(_show * 8.0 + index)) * 0.25
		cup.position = at + Vector3(0, (LIFT if lifted else 0.0) + dance, 0)
	var holder := _slots[slot_of[ball]]
	_ball.visible = mode == REVEAL or mode == SHOW
	_ball.position = holder + Vector3(0, 0.13, 0)
