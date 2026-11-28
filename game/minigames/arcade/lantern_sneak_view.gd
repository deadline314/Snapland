extends "res://game/minigames/arcade/arcade_view.gd"
## 燈籠捉迷藏: a midnight street seen from above, wet stone shining with neon.
## 燈燈's lantern throws a warm fan of light across it, and the stall carts cast
## real shadows through that light: the dark behind a cart is where to hide.
## Drawn from the driver state; 燈燈 is the shared part rig.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Dengdeng = preload("res://game/minigames/arcade/dengdeng_rig.gd")
const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
## Mirrors of the driver's geometry (the driver preloads this view, so no preload back).
const BEAM_HALF := 0.384
const BEAM_RANGE := 360.0
const CART := Vector2(118, 62)
const FLOAT_RADIUS := 80.0

const STONE := Color("#2c2a45")
const STONE_LIGHT := Color("#3b3858")
const PUDDLE := Color("#1c2440")
const BEAM := Color("#ffcf7a")
const NEON: Array[Color] = [Color("#ff6f91"), Color("#7df0db"), Color("#ffc46b"), Color("#b79cff")]
const AWNINGS: Array[Color] = [Color("#e2604f"), Color("#3f9a8c"), Color("#e0a23a"), Color("#8a6ac8")]

var rig: Rig
var keeper_stage: Rig.Stage


func _init() -> void:
	super._init()
	rig = Dengdeng.build()
	keeper_stage = Rig.Stage.new(Dengdeng.STAGE, rig, Dengdeng.ROOT)
	add_child(keeper_stage)


func present(next_state: Dictionary, reduced: bool) -> void:
	super.present(next_state, reduced)
	if state.is_empty():
		return
	rig.reduced_motion = reduced_motion
	var move := "idle"
	var t := now
	var tapped := now - float(state.get("tapped_at", -99.0))
	var phase := str(state.get("phase", "sneak"))
	if phase == "finale":
		move = "bow"
		t = now - float(state.get("phase_at", now))
	elif tapped >= 0.0 and tapped < 0.9:
		move = "startled"
		t = tapped
	elif tapped >= 0.9 and tapped < 1.75:
		move = "hop"
		t = tapped - 0.9
	elif bool(state.get("alert", false)):
		move = "alert"
		t = fposmod(now, 0.8)
	keeper_stage.show_pose(rig.solve(move, t, now, tapped))


func _draw() -> void:
	if state.is_empty():
		return
	_font = Paper.font()
	_draw_backdrop()
	_draw_scene()
	draw_set_transform(Vector2.ZERO)
	if not bool(state.get("photo_ready", false)):
		_draw_medal_strip()
		_draw_hint()
		_draw_word()
	var stage := str(state.get("stage", "play"))
	if stage == "ready":
		_draw_ready_banner()
	elif stage != "play":
		_draw_closing_card()


# --- Backdrop ---------------------------------------------------------------

func _draw_backdrop() -> void:
	stamp(_street(), Vector2(0, 0))
	_draw_shopfronts()
	_draw_puddle_glints()


## Rain-wet paving stones in staggered rows, with puddles that will hold the neon.
func _street() -> Texture2D:
	return Pixels.cached("sneak|street", func() -> Image:
		var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
		for y in 180:
			for x in 320:
				var row := y / 7
				var shift := (row % 2) * 6
				var tone := STONE.lerp(STONE_LIGHT, Pixels.noise((x + shift) / 12, row, 31) * 0.6)
				if y % 7 == 6 or (x + shift) % 12 == 0:
					tone = STONE.darkened(0.35)
				var puddle := sin(x * 0.05 + y * 0.11) + sin(x * 0.021 - y * 0.07) * 1.3
				if puddle > 1.6:
					tone = PUDDLE.lerp(Color("#3b4a78"), 0.3 * float((x + y) % 5 == 0))
				image.set_pixel(x, y, tone)
		return image)


## Shopfronts along the top of the street: awnings, neon signs and a string of bulbs.
func _draw_shopfronts() -> void:
	for i in 7:
		var x := i * 190.0 - 20.0
		var tone: Color = AWNINGS[i % AWNINGS.size()]
		panel(Rect2(x, 120, 180, 50), "planks", Color("#4a3a52"))
		for stripe in 6:
			draw_rect(Rect2(x + stripe * 30.0, 160, 30, 16), tone if stripe % 2 == 0 else Color("#fff0cd"))
		var glow: Color = NEON[i % NEON.size()]
		var buzz := 1.0 if reduced_motion else 0.75 + 0.25 * float(sin(now * (3.0 + i) + i * 2.0) > -0.8)
		draw_rect(Rect2(x + 40.0, 132, 100, 18), Color(glow, 0.25 * buzz))
		draw_rect(Rect2(x + 46.0, 138, 88, 6), Color(glow, 0.9 * buzz))
	for bulb in 26:
		var x := bulb * 50.0 + 10.0
		var y := 184.0 + 8.0 * sin(PI * fposmod(x, 250.0) / 250.0)
		draw_rect(Rect2(x - 4.0, y, 8, 8), Color(NEON[bulb % NEON.size()], 0.85))


## Neon colours shimmering in the puddles.
func _draw_puddle_glints() -> void:
	if reduced_motion:
		return
	for i in 24:
		var twinkle := fposmod(now * 0.7 + i * 0.29, 1.0)
		if twinkle < 0.4:
			var at := Vector2(fposmod(i * 157.0, 1280.0), 210.0 + fposmod(i * 89.0, 500.0))
			draw_rect(Rect2((at / TEXEL).floor() * TEXEL, Vector2(TEXEL * 3.0, TEXEL)), Color(NEON[i % NEON.size()], 0.55))


# --- Scene ------------------------------------------------------------------

func _draw_scene() -> void:
	var finale := str(state.get("phase", "")) == "finale"
	# The night: everything dims except what the lanterns light.
	draw_rect(Rect2(0, 196, 1280, 524), Color("#0e0a1c", 0.25 if finale else 0.45))
	_draw_cart_targets()
	if finale:
		_draw_lit_street()
	else:
		_draw_beam()
		_draw_float_lamp()
	_draw_carts()
	_draw_keeper()
	_draw_player()
	_draw_lanterned()


## The lantern's fan of light, and the shadows the carts throw through it.
func _draw_beam() -> void:
	var from: Vector2 = state.get("lamp", Vector2.ZERO)
	var angle := float(state.get("beam", 0.0))
	var fan := PackedVector2Array([from])
	for step in 13:
		var a := angle - BEAM_HALF + BEAM_HALF * 2.0 * float(step) / 12.0
		fan.append(from + Vector2.from_angle(a) * BEAM_RANGE)
	draw_colored_polygon(fan, Color(BEAM, 0.3))
	# Shadows: from each cart's outline away from the lamp, out past the light.
	for cart: Vector2 in state.get("carts", []):
		var corners := [cart + Vector2(-1, -1) * CART * 0.5, cart + Vector2(1, -1) * CART * 0.5, cart + Vector2(1, 1) * CART * 0.5, cart + Vector2(-1, 1) * CART * 0.5]
		var lowest := INF
		var highest := -INF
		var left := Vector2.ZERO
		var right := Vector2.ZERO
		for corner: Vector2 in corners:
			var a := angle_difference(angle, (corner - from).angle())
			if a < lowest:
				lowest = a
				left = corner
			if a > highest:
				highest = a
				right = corner
		if from.distance_to(cart) > BEAM_RANGE + 80.0:
			continue
		if Rect2(cart - CART * 0.5, CART).grow(4.0).has_point(from) or highest - lowest < 0.01:
			continue
		var reach := BEAM_RANGE * 1.3
		var far_left := from + (left - from).normalized() * reach
		var far_right := from + (right - from).normalized() * reach
		# Two triangles, each checked, so a near-degenerate shadow never upsets the triangulator.
		for tri: PackedVector2Array in [PackedVector2Array([left, right, far_right]), PackedVector2Array([left, far_right, far_left])]:
			var area := (tri[1] - tri[0]).cross(tri[2] - tri[0])
			if absf(area) > 1.0:
				draw_colored_polygon(tri, Color("#0e0a1c", 0.4))
	draw_circle(from, 18.0, Color(BEAM, 0.6))


func _draw_float_lamp() -> void:
	var at: Vector2 = state.get("float_lamp", Vector2(-999, -999))
	if at.x < -900.0:
		return
	draw_circle(at, FLOAT_RADIUS, Color(BEAM, 0.22))
	draw_arc(at, FLOAT_RADIUS, 0.0, TAU, 32, Color(BEAM, 0.5), TEXEL * 0.5)
	var bob := 0.0 if reduced_motion else sin(now * 2.0) * 6.0
	stamp(Dengdeng._lamp(), at + Vector2(-20, -70 + bob), TEXEL)


## Where the carts are about to slide: dashed outlines on the ground.
func _draw_cart_targets() -> void:
	for target: Vector2 in state.get("cart_targets", []):
		var box := Rect2(target - CART * 0.5, CART)
		var flash := 0.5 + 0.5 * pulse(3.0)
		for edge in 4:
			var a: Vector2 = [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)][edge]
			var b: Vector2 = [Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position][edge]
			for dash in 6:
				var u := float(dash) / 6.0
				draw_line(a.lerp(b, u), a.lerp(b, u + 0.09), Color(GOLD, 0.5 + 0.4 * flash), TEXEL * 0.75)


func _cart() -> Texture2D:
	return Pixels.bake("sneak|cart", Vector2i(30, 18), func(x: int, y: int) -> Color:
		if y < 6:
			return AWNINGS[0] if (x / 4) % 2 == 0 else Color("#fff0cd")
		if y < 7:
			return Color("#4a3a52")
		if y >= 15:
			return Color("#1b1a30") if x % 9 < 4 else Pixels.CLEAR
		var goods := y >= 8 and y <= 10 and x >= 3 and x <= 26
		if goods:
			return [Color("#ffc46b"), Color("#ff6f91"), Color("#7df0db")][(x / 3) % 3]
		return Pixels.wood(Color("#8a5a3c"), x, y, 5, false))


func _draw_carts() -> void:
	for cart: Vector2 in state.get("carts", []):
		Props.oval_shadow(self, cart + Vector2(0, 28), Vector2(64, 10), 0.4, SPRITE_SHADE)
		stamp(_cart(), cart - CART * 0.5 + Vector2(-2, -12))


func _draw_keeper() -> void:
	var spot: Vector2 = state.get("spot", Vector2(640, 400))
	var facing := float(state.get("facing", 0.0))
	var mirror := -1.0 if cos(facing) < 0.0 else 1.0
	Props.oval_shadow(self, spot + Vector2(0, 4), Vector2(36, 9), 0.35, SPRITE_SHADE)
	var size := Vector2(Dengdeng.STAGE) * TEXEL * 0.75
	draw_set_transform(spot, 0.0, Vector2(mirror, 1.0))
	draw_texture_rect(keeper_stage.get_texture(), Rect2(-Dengdeng.ROOT * TEXEL * 0.75, size), false)
	draw_set_transform(Vector2.ZERO)
	if bool(state.get("alert", false)):
		label(spot + Vector2(0, -110), "嗯？", 28, GOLD, 0.9 + 0.2 * pulse(4.0))
	if bool(state.get("near", false)) and bool(state.get("behind", false)) and not bool(state.get("player_lit", false)) and str(state.get("phase", "")) == "sneak":
		draw_arc(spot + Vector2(0, -60), 40.0 + 4.0 * pulse(3.0), 0.0, TAU, 24, MINT, TEXEL)
		label(spot + Vector2(0, -116), "拍肩！", 24, MINT)


func _draw_player() -> void:
	if str(state.get("phase", "")) == "lanterned" and now - float(state.get("phase_at", now)) > 1.4:
		return
	var at: Vector2 = state.get("player", Vector2(130, 630))
	var caught := now - float(state.get("caught_at", -99.0))
	var mood := "shocked" if caught >= 0.0 and caught < 1.1 else "plain"
	Props.oval_shadow(self, at + Vector2(0, 4), Vector2(24, 7), 0.35, SPRITE_SHADE)
	stamp(Hero.texture(&"idle", true, mood), at - Hero.FEET * 2.5, 2.5)
	if bool(state.get("player_lit", false)):
		draw_arc(at + Vector2(0, -40), 46.0, 0.0, TAU, 20, Color(BEAM, 0.8), TEXEL)
	if caught >= 0.0 and caught < 0.25:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.7 * (1.0 - caught / 0.25)))
	if caught >= 0.0 and caught < 1.1:
		label(at + Vector2(0, -110), "被拍到了！", 24, ROSE)


## The finale: lanterns light up along the whole street.
func _draw_lit_street() -> void:
	var age := now - float(state.get("phase_at", now))
	for i in 18:
		var reveal := clampf(age * 6.0 - i * 0.35, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var at := Vector2(40.0 + i * 70.0, 216.0 + 14.0 * sin(i * 0.9))
		draw_circle(at + Vector2(0, 90), 70.0 * reveal, Color(BEAM, 0.12))
		stamp(Dengdeng._lamp(), at - Vector2(20, 0), 3.0 * reveal)
	if age > 0.8:
		label(Vector2(640, 420), "整條街都亮了！", 36, GOLD)


## Out of time: the traveller hangs under an awning as one more lantern.
func _draw_lanterned() -> void:
	if str(state.get("phase", "")) != "lanterned":
		return
	var age := now - float(state.get("phase_at", now))
	if age < 2.4:
		label(Vector2(640, 300), "燈燈提著燈籠走過來了……", 30, CREAM)
		return
	var drop := pop_in(age - 2.4, 0.3)
	var centre := Vector2(640, 420 + 60.0 * (1.0 - drop))
	draw_set_transform(centre, 0.05)
	draw_rect(Rect2(-170, -190, 340, 380), Color(0.05, 0.02, 0.08, 0.4))
	draw_rect(Rect2(-180, -200, 340, 380), Color("#fff6e2"))
	draw_rect(Rect2(-160, -180, 300, 270), Color("#2c2a45"))
	for stripe in 5:
		draw_rect(Rect2(-160 + stripe * 60, -180, 60, 30), AWNINGS[stripe % AWNINGS.size()])
	draw_line(Vector2(-10, -150), Vector2(-10, -80), Color("#5b5368"), 3.0)
	draw_circle(Vector2(-10, -20), 70.0, Color(Dengdeng.LANTERN, 0.85))
	Props.stamp(self, Hero.texture(&"up", true, "sorry"), Vector2(-10, 30) - Hero.FEET * 3.0, 3.0)
	draw_circle(Vector2(-10, -20), 90.0, Color(BEAM, 0.18))
	draw_set_transform(Vector2.ZERO)
	_card_text(centre, 0.05, Vector2(-10, 140), "燈籠主角（今晚營業中）", 24, INK, 1.0, false)
