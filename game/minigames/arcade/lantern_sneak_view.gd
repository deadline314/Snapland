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

## Back to front: night sky and a far skyline hung with paper lanterns, the
## lit stall fronts along the back of the street, then the wet cobbles.
func _draw_backdrop() -> void:
	stamp(_street(), Vector2(0, 0))
	stamp(_skyline(), Vector2(0, 96))
	_draw_far_lanterns()
	_draw_stall_fronts()
	_draw_reflections()


## Rounded cobbles, each lit on its upper left and shaded below, with dark
## grout and rain pooled between them.
func _street() -> Texture2D:
	return Pixels.cached("sneak|street", func() -> Image:
		var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
		for y in 180:
			for x in 320:
				var row := y / 6
				var shift := (row % 2) * 4
				var cell := Vector2(float((x + shift) % 8) - 3.5, float(y % 6) - 2.5)
				var stone := Vector2(cell.x / 3.6, cell.y / 2.7)
				var tone := STONE.lerp(STONE_LIGHT, Pixels.noise((x + shift) / 8, row, 31) * 0.7)
				if stone.length_squared() > 1.0:
					tone = Color("#17142a")
				else:
					tone = Pixels.rounded(tone, stone * 0.8)
				var puddle := sin(x * 0.05 + y * 0.11) + sin(x * 0.021 - y * 0.07) * 1.3
				if puddle > 1.5:
					tone = tone.lerp(PUDDLE, 0.7).lerp(Color("#4a5a90"), 0.25 * float(cell.y < -1.0))
				# Warmer near the stalls at the back of the street.
				tone = tone.lerp(Color("#5a3a48"), clampf((60.0 - y) / 60.0, 0.0, 1.0) * 0.35)
				image.set_pixel(x, y, tone)
		return image)


## Tiered roofs and towers against a deep sky, windows lit here and there.
func _skyline() -> Texture2D:
	return Pixels.cached("sneak|skyline", func() -> Image:
		var image := Image.create(320, 18, false, Image.FORMAT_RGBA8)
		for x in 320:
			var block := x / 11
			var top := 3.0 + 9.0 * Pixels.noise(block, 2, 41)
			if x % 11 < 2:
				top += 2.0
			if block % 5 == 2:
				top = maxf(0.0, top - 6.0 + absf(float(x % 11) - 5.0))
			for y in 18:
				var tone := Color("#120f24").lerp(Color("#2a1f40"), float(y) / 17.0 * 0.6)
				if float(y) >= top:
					tone = Color("#231b38")
					if Pixels.noise(x / 2, y / 2, 43) > 0.84 and y > top + 2.0:
						tone = Color("#ffcf7a").darkened(0.2 * Pixels.noise(x, y, 44))
				elif Pixels.noise(x, y, 45) > 0.985:
					tone = Color("#fff4d6")
				image.set_pixel(x, y, tone)
		return image)


## Strings of paper lanterns across the far roofs, swaying and glowing.
func _draw_far_lanterns() -> void:
	for string in 3:
		var left := string * 430.0 - 40.0
		for i in 11:
			var x := left + i * 44.0
			var sag := 10.0 * sin(PI * float(i) / 10.0)
			var sway := 0.0 if reduced_motion else sin(now * 1.3 + i * 0.7 + string) * 2.0
			var at := Vector2(x + sway, 122.0 + sag)
			var glow := 0.75 + 0.25 * (0.0 if reduced_motion else sin(now * 2.0 + i * 1.7))
			draw_circle(at, 9.0, Color(Dengdeng.LANTERN_GLOW, 0.18 * glow))
			draw_rect(Rect2(at - Vector2(4, 5), Vector2(8, 10)), Color(NEON[(i + string) % NEON.size()].lerp(Dengdeng.LANTERN, 0.5), glow))


## A lit stall front: shaded striped awning with a scalloped lip, a warm
## counter, a neon sign, and goods hanging from the awning.
func _stall_front(colour: Color) -> Texture2D:
	return Pixels.bake("sneak|front|%s" % colour.to_html(), Vector2i(44, 26), func(x: int, y: int) -> Color:
		if y < 10:
			# The awning: lit along its top, shading toward the lip.
			var stripe := colour if (x / 4) % 2 == 0 else Color("#fff0cd")
			var tone := stripe.lightened(0.15) if y < 2 else stripe.darkened(0.04 * y)
			if y == 9 and x % 4 == 1:
				return Pixels.CLEAR
			return tone
		if y < 12:
			return Color("#2a1f30")
		if y >= 22:
			return Pixels.wood(Color("#8a5a3c"), x, y, 6, false)
		# The lit stall interior, warmest in the middle.
		var warm := Color("#ffcf7a").lerp(Color("#c46a3a"), absf(x - 22.0) / 22.0)
		if (x == 1 or x == 42):
			return Color("#3a2a30")
		return warm.darkened(0.05 * float((x + y) % 3 == 0)))


func _draw_stall_fronts() -> void:
	for i in 7:
		var x := i * 186.0 - 10.0
		var colour: Color = AWNINGS[i % AWNINGS.size()]
		stamp(_stall_front(colour), Vector2(x, 132))
		# The neon sign on the awning, buzzing now and then.
		var glow: Color = NEON[i % NEON.size()]
		var buzz := 1.0 if reduced_motion else (0.4 if sin(now * (2.3 + i) + i * 5.0) > 0.97 else 1.0)
		draw_rect(Rect2(x + 52.0, 138, 76, 14), Color(glow, 0.22 * buzz))
		draw_rect(Rect2(x + 58.0, 142, 64, 6), Color(glow, 0.95 * buzz))
		# Goods hanging from the awning lip, swinging a little.
		for item in 4:
			var swing := 0.0 if reduced_motion else sin(now * 1.6 + item + i) * 0.12
			var hook := Vector2(x + 28.0 + item * 40.0, 176)
			draw_set_transform(hook, swing)
			draw_line(Vector2.ZERO, Vector2(0, 10), Color("#2a1f30"), 2.0)
			var good: Color = [Color("#e2604f"), Color("#ffc46b"), Color("#7df0db"), Color("#f2e9d4")][(item + i) % 4]
			draw_rect(Rect2(-6, 10, 12, 14), good.darkened(0.15))
			draw_rect(Rect2(-6, 10, 6, 14), good)
			draw_set_transform(Vector2.ZERO)
		# Steam from the food stalls, drifting up past the awning.
		if i % 2 == 0 and not reduced_motion:
			for puff in 4:
				var rise := fposmod(now * 18.0 + puff * 14.0 + i * 7.0, 56.0)
				var at := Vector2(x + 90.0 + sin(now + puff * 2.0) * 8.0, 196.0 - rise)
				draw_circle(at, 6.0 + rise * 0.12, Color("#f4ecff", 0.18 * (1.0 - rise / 56.0)))


## The stall lights and lanterns reflected in the wet cobbles, shimmering.
func _draw_reflections() -> void:
	for i in 7:
		var x := i * 186.0 + 78.0
		for streak in 5:
			var wave := 0.0 if reduced_motion else sin(now * 3.0 + streak * 1.3 + i) * 3.0
			var y := 214.0 + streak * 12.0
			draw_rect(Rect2(x - 14.0 + wave, y, 28.0 - streak * 4.0, TEXEL), Color("#ffcf7a", 0.22 - streak * 0.035))
	if not reduced_motion:
		for i in 22:
			var twinkle := fposmod(now * 0.7 + i * 0.29, 1.0)
			if twinkle < 0.4:
				var at := Vector2(fposmod(i * 157.0, 1280.0), 240.0 + fposmod(i * 89.0, 460.0))
				draw_rect(Rect2((at / TEXEL).floor() * TEXEL, Vector2(TEXEL * 3.0, TEXEL)), Color(NEON[i % NEON.size()], 0.5))


## Warm light spilling from each stall onto the street, drawn over the night.
func _draw_stall_glow() -> void:
	for i in 7:
		var centre := Vector2(i * 186.0 + 78.0, 214.0)
		for ring in 4:
			draw_circle(centre, 110.0 - ring * 22.0, Color("#ffb45e", 0.04))


## Shoppers drifting past in the foreground: the traveller's own pixel build,
## dark against the lights, some under umbrellas.
func _draw_shoppers() -> void:
	for i in 6:
		var speed := 0.0 if reduced_motion else (26.0 + i * 5.0) * (1.0 if i % 2 == 0 else -1.0)
		var x := fposmod(i * 233.0 + now * speed, 1480.0) - 100.0
		var at := Vector2(x, 792.0 + (i % 3) * 6.0)
		var bob := 0.0 if reduced_motion else absf(sin(now * 4.0 + i)) * 3.0
		var tint := Color("#1a1530")
		Props.stamp(self, Hero.texture(&"idle", i % 3 != 0, "plain"), at - Hero.FEET * 3.2 - Vector2(0, bob), 3.2, tint)
		if i % 3 == 1:
			var top := at - Vector2(0, 160 + bob)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-46, 18), top + Vector2(0, -6), top + Vector2(46, 18)]), Color("#2a2140"))
			draw_line(top + Vector2(0, 0), top + Vector2(0, 50), Color("#2a2140"), 3.0)


## Drizzle on the drizzle variant: fine slanted streaks.
func _draw_drizzle() -> void:
	if str(state.get("variant_id", "")) != "drizzle" or reduced_motion:
		return
	for i in 60:
		var fall := fposmod(now * 520.0 + i * 97.0, 640.0)
		var at := Vector2(fposmod(i * 131.0 + fall * 0.2, 1280.0), 120.0 + fall)
		draw_line(at, at + Vector2(-4, 14), Color("#b9c6f0", 0.35), 1.5)


# --- Scene ------------------------------------------------------------------

func _draw_scene() -> void:
	var finale := str(state.get("phase", "")) == "finale"
	# The night: everything dims except what the lanterns light.
	draw_rect(Rect2(0, 196, 1280, 524), Color("#0e0a1c", 0.25 if finale else 0.42))
	_draw_stall_glow()
	_draw_cart_targets()
	if finale:
		_draw_lit_street()
	else:
		_draw_beam()
		_draw_float_lamp()
	_draw_carts()
	_draw_keeper()
	_draw_player()
	_draw_shoppers()
	_draw_drizzle()
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


## A stall cart seen from the front and a little above: a striped awning lit on
## top and shaded toward its scalloped lip, two posts, a counter heaped with
## goods under a warm bulb, a wooden body and two spoked wheels.
func _cart(colour: Color) -> Texture2D:
	return Pixels.bake("sneak|cart|%s" % colour.to_html(), Vector2i(32, 24), func(x: int, y: int) -> Color:
		if y < 8:
			var inset := maxi(0, 2 - y)
			if x < inset or x > 31 - inset:
				return Pixels.CLEAR
			var stripe := colour if (x / 4) % 2 == 0 else Color("#fff0cd")
			if y == 7 and x % 4 == 2:
				return Pixels.CLEAR
			return stripe.lightened(0.18) if y < 2 else stripe.darkened(0.05 * float(y))
		if y < 9:
			return Color("#2a1f30")
		if y < 13:
			if x == 2 or x == 29:
				return Color("#4a3a52")
			# Under the awning: a warm bulb glow over heaped goods.
			if y >= 11 and x >= 4 and x <= 27:
				return [Color("#ffc46b"), Color("#ff6f91"), Color("#7df0db"), Color("#f2e9d4")][(x / 3 + y) % 4].darkened(0.1 * float(y == 12))
			return Color("#ffcf7a").lerp(Color("#a35a2a"), absf(x - 16.0) / 16.0)
		if y < 20:
			return Pixels.wood(Color("#8a5a3c"), x, y, 5, false).darkened(0.04 * float(y - 13))
		var wheel := Vector2(float(x % 16) - 7.5, float(y) - 21.5)
		if absf(wheel.x) < 2.6 and absf(wheel.y) < 2.6:
			return Color("#c48f5c") if wheel.length() < 1.0 else Color("#2a1f30")
		return Pixels.CLEAR)


func _draw_carts() -> void:
	var index := 0
	for cart: Vector2 in state.get("carts", []):
		Props.oval_shadow(self, cart + Vector2(0, 34), Vector2(70, 12), 0.45, SPRITE_SHADE)
		var colour: Color = AWNINGS[index % AWNINGS.size()]
		stamp(_cart(colour), cart - Vector2(64, 50))
		# A small lantern hanging off the awning's corner, swaying.
		var sway := 0.0 if reduced_motion else sin(now * 1.5 + index) * 0.18
		var hook := cart + Vector2(58, -22)
		draw_set_transform(hook, sway)
		draw_line(Vector2.ZERO, Vector2(0, 12), Color("#2a1f30"), 2.0)
		draw_circle(Vector2(0, 22), 16.0, Color(Dengdeng.LANTERN_GLOW, 0.2))
		Props.stamp(self, Dengdeng._lamp(), Vector2(-12, 10), 2.4)
		draw_set_transform(Vector2.ZERO)
		index += 1


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
	var last := Vector2.ZERO
	for i in 18:
		var reveal := clampf(age * 6.0 - i * 0.35, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var at := Vector2(40.0 + i * 70.0, 216.0 + 14.0 * sin(i * 0.9))
		if i > 0 and last != Vector2.ZERO:
			draw_line(last + Vector2(0, -2), at + Vector2(0, -2), Color("#2a1c18", 0.9), TEXEL)
		last = at
		# A warm pool of light on the wet cobbles, brightest under the lantern.
		draw_set_transform(at + Vector2(0, 110), 0.0, Vector2(1.0, 0.42))
		for ring in 4:
			draw_circle(Vector2.ZERO, (78.0 - ring * 17.0) * reveal, Color("#ffb45e", 0.05 + ring * 0.015))
		draw_set_transform(Vector2.ZERO)
		draw_circle(at + Vector2(0, 22), 22.0 * reveal, Color(Dengdeng.LANTERN_GLOW, 0.16))
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
