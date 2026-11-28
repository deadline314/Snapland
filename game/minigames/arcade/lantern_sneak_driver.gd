extends "res://game/minigames/arcade/arcade_driver.gd"
## 燈籠捉迷藏, the night market other space's finale (design/01-park/other-space.md §5d).
## Not a catalogue minigame: it earns no stickers and is started by the rift door.
##
## A top-down midnight street. 燈燈 holds out a lantern whose light is a fan
## that sweeps side to side; stall carts block the light. Before it whips the
## light round to the other side it stops and goes "hm?". Arrows walk; the
## action key taps its shoulder, which only counts from behind and out of the
## light. Caught in the light: a flash photo and back toward the start. Three
## taps and the whole street lights up; out of time, you end up a lantern.
##
## Act two: carts slide to new places on a timetable, marked on the ground
## first. Act three: a second lantern floats around with its own pool of light.

const VIEW = preload("res://game/minigames/arcade/lantern_sneak_view.gd")

const TAPS := 3
const ARENA := Rect2(70, 170, 1140, 500)
const START := Vector2(130, 630)
const SPEED := 230.0
const RADIUS := 16.0
const REACH := 74.0
const BEAM_RANGE := 360.0
const BEAM_HALF := 0.384
const SWEEP := 0.663
const SWEEP_PERIOD := 3.4
const ALERT_SECONDS := 0.8
const TURN_EVERY := [6.5, 5.5, 4.8]
const CAUGHT_SECONDS := 1.1
const STARTLE_SECONDS := 1.0
const CART := Vector2(118, 62)
## Act two's timetable: warn, then slide, every this many seconds.
const CART_EVERY := 7.0
const CART_WARN := 1.5
const CART_SLIDE := 1.2
const FLOAT_RADIUS := 80.0
const FINALE_PHOTO := 1.8
const FINALE_END := 3.4
const LANTERNED_SECONDS := 4.0
const LANTERNED_PHOTO := 2.4
## Where 燈燈 stands for each tap, and the carts' places (two sets that act two alternates).
const SPOTS: Array[Vector2] = [Vector2(780, 330), Vector2(420, 300), Vector2(900, 520), Vector2(620, 430)]
const CART_SETS := [
	[Vector2(330, 470), Vector2(600, 560), Vector2(560, 260), Vector2(1000, 360)],
	[Vector2(300, 330), Vector2(720, 560), Vector2(470, 440), Vector2(1040, 250)],
]

var player := START
var taps := 0
var caught := 0
var spot := SPOTS[0]
## Beam centre: the angle the lantern faces; it sweeps around this.
var facing := PI
var sweep_at := 0.0
var alert_at := -99.0
var next_turn := 0.0
var caught_at := -99.0
var tapped_at := -99.0
var carts: Array[Vector2] = []
var cart_from: Array[Vector2] = []
var cart_to: Array[Vector2] = []
var cart_move_at := INF
var cart_set := 0
var phase := "sneak"
var phase_at := -99.0
var _dirs := {}


func _init() -> void:
	verb = "躲開燈光，繞到燈燈背後拍牠的肩！"
	hint = [["方向鍵", "移動"], ["空白鍵", "拍肩"]]
	round_seconds = 110.0
	thresholds = [600, 800, 950]
	verdicts = ["你被掛成燈籠了。", "整條街都亮了！", "腳步真輕，燈燈都沒發現。", "燈燈說你可以去當夜市的貓。"]
	variants = [{"id": "drizzle", "label": "毛毛雨"}, {"id": "clear", "label": "晴夜"}]
	score_label = "拍肩"
	view_script = VIEW


func reset(assisted_mode: bool, clock_text: String) -> void:
	super.reset(assisted_mode, clock_text)
	round_seconds = 110.0 * clampf(round_scale, 0.1, 1.0)
	_refresh()


func score_summary(practice: bool) -> Dictionary:
	var summary := super.score_summary(practice)
	summary.rule = "拍到三次肩才有獎牌：銅 %d、銀 %d、金 %d 分。壓軸不發拍貼。" % thresholds
	summary.qualification_text = "練習回合不保存。" if practice else ""
	return summary


func medal() -> int:
	return super.medal() if taps >= TAPS else 0


func act() -> int:
	return 1 + mini(2, taps)


## The lantern's beam angle right now: sweeping about `facing`, frozen while alert.
func beam_angle() -> float:
	if clock - alert_at < ALERT_SECONDS:
		return facing + SWEEP * sin(TAU * (alert_at - sweep_at) / _sweep_period())
	return facing + SWEEP * sin(TAU * (clock - sweep_at) / _sweep_period())


func _sweep_period() -> float:
	return SWEEP_PERIOD * (1.4 if assisted else 1.0)


## Where the lantern hangs: out in front of 燈燈 at arm's length.
func lamp() -> Vector2:
	return spot + Vector2(cos(facing) * 28.0, -46.0)


func alerting() -> bool:
	return clock - alert_at < ALERT_SECONDS


## The floating lantern of act three: a pool of light circling the street.
func float_lamp() -> Vector2:
	if act() < 3:
		return Vector2(-999, -999)
	var u := TAU * clock / (16.0 if assisted else 11.0)
	return Vector2(640, 420) + Vector2(cos(u) * 380.0, sin(u * 2.0) * 170.0)


## Whether a point is lit: inside the lantern's fan with nothing in the way, or
## inside the floating lantern's pool.
func lit(at: Vector2) -> bool:
	if at.distance_to(float_lamp()) < FLOAT_RADIUS:
		return true
	var from := lamp()
	var to := at - from
	if to.length() > BEAM_RANGE:
		return false
	if absf(angle_difference(beam_angle(), to.angle())) > BEAM_HALF:
		return false
	for cart in carts:
		if _blocks(Rect2(cart - CART * 0.5, CART), from, at):
			return false
	return true


## Behind 燈燈: on the far side from where its lantern faces.
func behind(at: Vector2) -> bool:
	return Vector2.from_angle(facing).dot(at - spot) < 0.0


func can_tap() -> bool:
	return phase == "sneak" and clock - caught_at >= CAUGHT_SECONDS and clock - tapped_at >= STARTLE_SECONDS


# --- Round ------------------------------------------------------------------

func _begin_round(_variant: Dictionary) -> void:
	player = START
	taps = 0
	caught = 0
	_dirs.clear()
	caught_at = -99.0
	tapped_at = -99.0
	alert_at = -99.0
	phase = "sneak"
	phase_at = -99.0
	cart_set = 0
	carts.clear()
	for at: Vector2 in CART_SETS[0]:
		carts.append(at)
	cart_move_at = INF
	_place(0)


func _place(index: int) -> void:
	spot = SPOTS[index % SPOTS.size()]
	# First time it faces the traveller (who starts far off); after a tap it faces away.
	facing = (player - spot).angle() + (PI if taps > 0 else 0.0) if player.distance_to(spot) > 1.0 else PI
	sweep_at = clock
	next_turn = clock + float(TURN_EVERY[mini(2, taps)]) * (1.3 if assisted else 1.0) + rng.randf_range(-0.6, 0.6)


func _go() -> void:
	player = START
	_place(0)


func _tick(delta: float) -> void:
	match phase:
		"sneak":
			_sneak(delta)
			if round_seconds - play_time <= LANTERNED_SECONDS and taps < TAPS:
				phase = "lanterned"
				phase_at = clock
		"lanterned":
			if clock - phase_at >= 1.4 and fail_at < 0.0:
				funny_fail("咻——被掛起來了", false)
				sound(45)
		"finale":
			if clock - phase_at >= FINALE_END:
				play_time = round_seconds


func _sneak(delta: float) -> void:
	# The snap turn: stop and go "hm?", then whip the light round.
	if clock >= next_turn - ALERT_SECONDS and not alerting() and clock < next_turn:
		alert_at = clock
		sound(58)
	if clock >= next_turn:
		facing = facing + PI
		sweep_at = clock
		next_turn = clock + float(TURN_EVERY[mini(2, taps)]) * (1.3 if assisted else 1.0) + rng.randf_range(-0.6, 0.6)
		sound(60)
	_carts()
	if clock - caught_at >= CAUGHT_SECONDS:
		var dir := Vector2(float(_dirs.get("right", 0)) - float(_dirs.get("left", 0)), float(_dirs.get("down", 0)) - float(_dirs.get("up", 0)))
		if dir != Vector2.ZERO:
			_walk(dir.normalized() * SPEED * delta)
		if lit(player) and clock - tapped_at >= STARTLE_SECONDS:
			caught += 1
			caught_at = clock
			say("喀嚓！被燈燈拍到了", false)
			sound(40)
			var home := START if not assisted else player.lerp(START, 0.4)
			player = home


func _walk(step: Vector2) -> void:
	var next := player + step
	next = Vector2(clampf(next.x, ARENA.position.x, ARENA.end.x), clampf(next.y, ARENA.position.y, ARENA.end.y))
	for cart in carts:
		var box := Rect2(cart - CART * 0.5, CART).grow(RADIUS)
		if box.has_point(next):
			# Slide along the cart instead of walking through it.
			var x_only := Vector2(next.x, player.y)
			var y_only := Vector2(player.x, next.y)
			next = x_only if not box.has_point(x_only) else (y_only if not box.has_point(y_only) else player)
	if next.distance_to(spot) < 30.0:
		next = spot + (next - spot).normalized() * 30.0
	player = next


## Act two on: every CART_EVERY seconds the carts slide to the other set of
## places, marked on the ground CART_WARN seconds before.
func _carts() -> void:
	if act() < 2:
		return
	if cart_move_at == INF:
		cart_move_at = clock + CART_EVERY
	if clock >= cart_move_at and cart_to.is_empty():
		cart_from = carts.duplicate()
		cart_set = 1 - cart_set
		cart_to.clear()
		for at: Vector2 in CART_SETS[cart_set]:
			cart_to.append(at)
	if not cart_to.is_empty():
		var u := clampf((clock - cart_move_at) / CART_SLIDE, 0.0, 1.0)
		for i in carts.size():
			carts[i] = cart_from[i].lerp(cart_to[i], u * u * (3.0 - 2.0 * u))
		if u >= 1.0:
			cart_to.clear()
			cart_move_at = clock + CART_EVERY


func _press(button: StringName) -> void:
	match button:
		&"up", &"down", &"left", &"right":
			_dirs[String(button)] = 1
		&"action":
			_tap()


func _release(button: StringName) -> void:
	_dirs.erase(String(button))


func _tap() -> void:
	if not can_tap():
		return
	if player.distance_to(spot) > window(REACH) or not behind(player) or lit(player):
		say("拍空了", false)
		return
	taps += 1
	tapped_at = clock
	add_score(200 + roundi(maxf(0.0, 100.0 - caught * 25.0)), "拍到了！")
	sound(84)
	if taps >= TAPS:
		phase = "finale"
		phase_at = clock
		say("整條街都亮了！", true)
	else:
		_place(taps)


func _round_over() -> void:
	if taps >= TAPS:
		add_score(roundi(maxf(0.0, round_seconds - play_time)))


func _blocks(box: Rect2, from: Vector2, to: Vector2) -> bool:
	for i in range(1, 12):
		if box.has_point(from.lerp(to, float(i) / 12.0)):
			return true
	return false


func _snapshot(into: Dictionary) -> void:
	into.player = player
	into.player_lit = lit(player)
	into.spot = spot
	into.lamp = lamp()
	into.facing = facing
	into.beam = beam_angle()
	into.alert = alerting()
	into.float_lamp = float_lamp()
	into.carts = carts.duplicate()
	into.cart_targets = CART_SETS[1 - cart_set] if act() >= 2 and clock >= cart_move_at - CART_WARN and cart_to.is_empty() else []
	into.taps = taps
	into.caught = caught
	into.caught_at = caught_at
	into.tapped_at = tapped_at
	into.act = act()
	into.behind = behind(player)
	into.near = player.distance_to(spot) <= window(REACH)
	into.phase = phase
	into.phase_at = phase_at
	into.photo_ready = (phase == "finale" and clock - phase_at >= FINALE_PHOTO) or (phase == "lanterned" and clock - phase_at >= LANTERNED_PHOTO)
	into.cleared = taps >= TAPS
	into.progress_text = "拍肩 %d / %d" % [taps, TAPS]
