extends "res://game/minigames/arcade/arcade_view.gd"
## 果凍真身: an upside-down candy factory. Syrup climbs the pipes, sprinkles
## fall up, and 啵啵's jelly copies hang from the ceiling shelf (until act
## three's gravity flip drops them onto the floor belt). The traveller waits
## at the side with a long ladle; three moulds wait for the real one.
## Every jelly is the same rig: copies solved on the beat, the real one late.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Bobo = preload("res://game/minigames/arcade/bobo_rig.gd")
const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")

const SHELF_Y := 196.0
const BELT_Y := 566.0
const SLOT_GAP := 190.0
const HOP := 120.0
const TILE := Color("#f6d9e2")
const TILE_LINE := Color("#e7b9c8")
const PIPE := Color("#c98d5e")
const SYRUP := Color("#e8a23a")
const SHELF := Color("#8d8296")
const BELT := Color("#5c4a66")
const MOULD := Color("#d9d2e0")
const SPRINKLES: Array[Color] = [Color("#e2495f"), Color("#f9da7c"), Color("#a3dfc8"), Color("#a2d3ee"), Color("#c9a7e8")]

var rig: Rig
var stages: Array[Rig.Stage] = []
var cake_stage: Rig.Stage


func _init() -> void:
	super._init()
	rig = Bobo.build()
	for i in 5:
		var stage := Rig.Stage.new(Bobo.STAGE, rig, Bobo.ROOT)
		stages.append(stage)
		add_child(stage)
	cake_stage = Rig.Stage.new(Bobo.STAGE, rig, Bobo.ROOT)
	add_child(cake_stage)


func present(next_state: Dictionary, reduced: bool) -> void:
	super.present(next_state, reduced)
	if state.is_empty():
		return
	rig.reduced_motion = reduced_motion
	var jellies: Array = state.get("jellies", [])
	var holding := str(state.get("round_phase", "")) == "split"
	for i in stages.size():
		if i >= jellies.size():
			continue
		var jelly: Dictionary = jellies[i]
		var hidden: Array = [] if bool(jelly.real) and holding else ["ladle"]
		stages[i].show_pose(rig.solve(str(jelly.move), float(jelly.t), now, INF, hidden))
	var finale := now - float(state.get("phase_at", now))
	cake_stage.show_pose(rig.solve("cheer", finale, now, INF, ["ladle"]))


func slot_x(slot: float) -> float:
	return 640.0 + (slot - (int(state.get("slots", 3)) - 1) * 0.5) * SLOT_GAP


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
	stamp(_wall(), Vector2.ZERO)
	_draw_pipes()
	_draw_sprinkles()
	# The ceiling shelf the jellies hang from, and the floor belt below.
	panel(Rect2(-8, SHELF_Y - 34.0, 1296, 34), "enamel", SHELF, Color("#e9c68f"))
	draw_rect(Rect2(0, SHELF_Y, 1280, 6), Color(0.2, 0.1, 0.2, 0.35))
	stamp(_belt(), Vector2(0, BELT_Y))
	draw_rect(Rect2(0, BELT_Y - 6.0, 1280, 6), Color(0.2, 0.1, 0.2, 0.25))


func _wall() -> Texture2D:
	return Pixels.cached("jelly|wall", func() -> Image:
		var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
		for y in 180:
			for x in 320:
				var tone := TILE.darkened(0.04 * float((x / 10 + y / 10) % 2))
				if x % 10 == 0 or y % 10 == 0:
					tone = TILE_LINE
				elif Pixels.noise(x, y, 91) > 0.97:
					tone = tone.lightened(0.1)
				# Warm light pooling near the floor.
				tone = tone.lerp(Color("#ffe9c8"), clampf((y - 110) / 140.0, 0.0, 0.35))
				image.set_pixel(x, y, tone)
		return image)


func _belt() -> Texture2D:
	return Pixels.cached("jelly|belt", func() -> Image:
		var image := Image.create(320, 39, false, Image.FORMAT_RGBA8)
		for y in 39:
			for x in 320:
				var tone := BELT
				if y < 3:
					tone = Color("#8d8296")
				elif y < 9:
					tone = BELT.lightened(0.12) if x % 8 < 6 else BELT.darkened(0.2)
				else:
					tone = Color("#e9c68f").darkened(0.08 * float((x / 16) % 2)) if y > 12 else BELT.darkened(0.3)
				image.set_pixel(x, y, tone)
		return image)


## Copper pipes with syrup bands climbing them: everything here falls up.
func _draw_pipes() -> void:
	for pipe in 4:
		var x := 90.0 + pipe * 360.0
		panel(Rect2(x, SHELF_Y, 36, BELT_Y - SHELF_Y), "pole", PIPE)
		for band in 6:
			var rise := 0.0 if reduced_motion else now * 90.0
			var y := BELT_Y - fposmod(band * 66.0 + rise, BELT_Y - SHELF_Y)
			draw_rect(Rect2(x + 10.0, roundf(y / TEXEL) * TEXEL, 16, 18), Color(SYRUP, 0.85))


func _draw_sprinkles() -> void:
	for i in 26:
		var rise := 0.0 if reduced_motion else now * (30.0 + float(i % 4) * 12.0)
		var y := BELT_Y - fposmod(i * 47.0 + rise, BELT_Y - SHELF_Y)
		var x := fposmod(i * 137.0 + (0.0 if reduced_motion else sin(now + i) * 10.0), 1280.0)
		draw_rect(Rect2((Vector2(x, y) / TEXEL).floor() * TEXEL, Vector2(TEXEL * 2.0, TEXEL)), Color(SPRINKLES[i % SPRINKLES.size()], 0.8))


# --- Scene ------------------------------------------------------------------

func _draw_scene() -> void:
	var phase := str(state.get("phase", "show"))
	_draw_moulds()
	if phase == "finale":
		_draw_cake()
	else:
		_draw_jellies()
		_draw_cursor()
	_draw_hero()
	_draw_flip_banner()
	_draw_jellied()


func _draw_jellies() -> void:
	var flipped := bool(state.get("flipped", false))
	var jellies: Array = state.get("jellies", [])
	var size := Vector2(Bobo.STAGE) * TEXEL
	for i in mini(jellies.size(), stages.size()):
		var jelly: Dictionary = jellies[i]
		var x := slot_x(float(jelly.x))
		var lift := float(jelly.lift) * HOP
		if bool(jelly.popped):
			_splash(Vector2(x, BELT_Y - 40.0 if flipped else SHELF_Y + 60.0), float(jelly.popped_age) - 0.25)
			if float(jelly.popped_age) > 0.35:
				continue
		var texture := stages[i].get_texture()
		if flipped:
			var root := Vector2(x, BELT_Y - lift)
			Props.oval_shadow(self, Vector2(x, BELT_Y + 4.0), Vector2(70, 10), 0.3, SPRITE_SHADE)
			draw_texture_rect(texture, Rect2(root - Bobo.ROOT * TEXEL, size), false)
		else:
			# Hanging from the shelf, upside down: mirror the picture about its root.
			var root := Vector2(x, SHELF_Y + lift)
			draw_set_transform(root, 0.0, Vector2(1, -1))
			draw_texture_rect(texture, Rect2(-Bobo.ROOT * TEXEL, size), false)
			draw_set_transform(Vector2.ZERO)
		if str(state.get("round_phase", "")) == "scoop" and bool(jelly.real):
			_draw_ladle_reach(Vector2(x, BELT_Y - 60.0 if flipped else SHELF_Y + 80.0), now - float(state.get("scoop_at", now)))


## The chosen jelly: a pointing spoon and a ring, dimmed while gummed up.
func _draw_cursor() -> void:
	if str(state.get("round_phase", "")) != "pick" or str(state.get("stage", "")) != "play":
		return
	var flipped := bool(state.get("flipped", false))
	var x := slot_x(float(state.get("cursor", 1)))
	var y := BELT_Y - 70.0 if flipped else SHELF_Y + 70.0
	var ready := bool(state.get("can_pick", false))
	var tone := GOLD if ready else Color("#b9a9c8")
	draw_arc(Vector2(x, y), 74.0 + (4.0 * pulse(2.5) if ready else 0.0), 0.0, TAU, 32, tone, TEXEL)
	var tip := Vector2(x, y + (110.0 if not flipped else -110.0))
	var dir := -1.0 if not flipped else 1.0
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-16, -dir * 26.0), tip + Vector2(16, -dir * 26.0)]), tone)


func _draw_ladle_reach(target: Vector2, age: float) -> void:
	var hand := Vector2(150, 600)
	var u := clampf(age / 0.3, 0.0, 1.0)
	var tip := hand.lerp(target, u)
	draw_line(hand, tip, Color("#b9b4c8"), TEXEL * 2.0)
	draw_circle(tip, 18.0, Color("#b9b4c8"))


func _mould() -> Texture2D:
	return Pixels.bake("jelly|mould", Vector2i(26, 14), func(x: int, y: int) -> Color:
		var u := (x + 0.5 - 13.0) / 13.0
		if absf(u) > 1.0 - float(y) * 0.02:
			return Pixels.CLEAR
		if y < 2:
			return MOULD.lightened(0.15)
		var flute := (x / 3) % 2 == 0
		return Pixels.metal(MOULD.darkened(0.12 if flute else 0.0), x, y))


func _draw_moulds() -> void:
	var filled := int(state.get("moulds", 0))
	for i in 6:
		var at := Vector2(870.0 + (i % 3) * 120.0, 612.0 + (i / 3) * 56.0)
		stamp(_mould(), at - Vector2(52, 0))
		if i < filled:
			draw_rect(Rect2(at + Vector2(-40, -18), Vector2(80, 22)), Bobo.JELLY if i % 2 == 0 else Color("#9ee0b8"))
			draw_rect(Rect2(at + Vector2(-32, -16), Vector2(18, 6)), Color("#ffd0da"))


func _draw_hero() -> void:
	var goo := now - float(state.get("goo_at", -99.0))
	var gummed := goo >= 0.0 and goo < 1.6
	var texture := Hero.texture(&"up", true, "sorry" if gummed else "plain")
	var at := Vector2(110, 660) - Hero.FEET * 3.0
	ground_shadow(Vector2(110, 664), Vector2(40, 8), 0.3)
	stamp(texture, at, 3.0)
	# The long ladle propped on the shoulder.
	draw_line(Vector2(140, 600), Vector2(220, 470), Color("#b9b4c8"), TEXEL * 1.5)
	draw_circle(Vector2(224, 462), 14.0, Color("#b9b4c8"))
	if gummed:
		for drip in 7:
			var fall := 0.0 if reduced_motion else fposmod(goo * 40.0 + drip * 9.0, 40.0)
			draw_rect(Rect2(Vector2(80 + drip * 9.0, 520 + fall), Vector2(TEXEL * 2.0, TEXEL * 3.0)), Color(Bobo.JELLY, 0.85))
		label(Vector2(110, 490), "黏住了！", 22, ROSE)


## A copy bursting: pink droplets flung out and a puddle left behind.
func _splash(at: Vector2, age: float) -> void:
	if age < 0.0 or age > 0.8:
		return
	var u := age / 0.8
	draw_arc(at, 30.0 + 70.0 * u, 0.0, TAU, 24, Color(Bobo.JELLY_LIGHT, 1.0 - u), TEXEL * 2.0)
	if reduced_motion:
		return
	for drop in 14:
		var angle := TAU * float(drop) / 14.0
		var point := at + Vector2(cos(angle), sin(angle)) * 220.0 * age + Vector2(0, 260.0 * age * age)
		draw_rect(Rect2((point / TEXEL).floor() * TEXEL, Vector2(TEXEL * 2.0, TEXEL * 2.0)), Color(Bobo.JELLY, 1.0 - u))


func _draw_flip_banner() -> void:
	if not bool(state.get("flipped", false)) or str(state.get("round_phase", "")) != "shuffle":
		return
	label(Vector2(640, 380), "重力翻轉！", 34, GOLD)


## The finale: three moulds turned out into a tiered jelly cake, 啵啵 on top.
func _draw_cake() -> void:
	var age := now - float(state.get("phase_at", now))
	var settle := pop_in(age, 0.4)
	var base := Vector2(640, BELT_Y)
	for tier in 3:
		var width := 300.0 - tier * 80.0
		var tone := Bobo.JELLY if tier != 1 else Color("#7fd3a4")
		var at := base + Vector2(-width * 0.5, -(tier + 1) * 64.0 * settle)
		draw_set_transform(at, 0.0, Vector2(1.0, settle))
		Props.stamp(self, _tier(int(width / TEXEL), tone), Vector2.ZERO, TEXEL)
		draw_set_transform(Vector2.ZERO)
	var size := Vector2(Bobo.STAGE) * TEXEL
	draw_texture_rect(cake_stage.get_texture(), Rect2(base + Vector2(0, -192.0 * settle) - Bobo.ROOT * TEXEL, size), false)
	if age > 0.6:
		label(Vector2(640, 220), "果凍蛋糕完成！", 36, GOLD)


## One tier of the turned-out cake: fluted sides from the mould, a cream lip,
## a glossy streak and a few bubbles caught in the jelly.
func _tier(width: int, tone: Color) -> Texture2D:
	return Pixels.bake("jelly|tier|%d|%s" % [width, tone.to_html()], Vector2i(width, 16), func(x: int, y: int) -> Color:
		if y < 2:
			return Color("#fff4e2").darkened(0.06 * float(x % 4 == 0))
		var flute := (x / 4) % 2 == 0
		var c := tone.darkened(0.1 if flute else 0.0)
		if y >= 4 and y <= 5 and x >= 3 and x < width / 3:
			return tone.lightened(0.35)
		if Pixels.noise(x / 2, y / 2, 95) > 0.93:
			return tone.lightened(0.25)
		return Pixels.rounded(c, Vector2((x + 0.5 - width * 0.5) / (width * 0.5), (y - 8.0) / 8.0)))


## Out of time: the copies pile on and wrap the traveller in a block of jelly.
func _draw_jellied() -> void:
	if str(state.get("phase", "")) != "jellied":
		return
	var age := now - float(state.get("phase_at", now))
	if age < 2.4:
		var cover := clampf(age / 1.4, 0.0, 1.0)
		draw_rect(Rect2(40, 660 - 200 * cover, 160, 200 * cover), Color(Bobo.JELLY, 0.6))
		label(Vector2(640, 300), "分身們撲過來了……", 32, CREAM)
		return
	var drop := pop_in(age - 2.4, 0.3)
	var centre := Vector2(640, 420 + 60.0 * (1.0 - drop))
	draw_set_transform(centre, -0.05)
	draw_rect(Rect2(-170, -190, 340, 380), Color(0.05, 0.02, 0.08, 0.4))
	draw_rect(Rect2(-180, -200, 340, 380), Color("#fff6e2"))
	draw_rect(Rect2(-160, -180, 300, 270), TILE)
	Props.stamp(self, Hero.texture(&"up", true, "shocked"), Vector2(-10, 70) - Hero.FEET * 4.0, 4.0)
	draw_rect(Rect2(-120, -150, 220, 230), Color(Bobo.JELLY, 0.55))
	draw_rect(Rect2(-108, -138, 40, 14), Color("#ffd0da", 0.8))
	draw_set_transform(Vector2.ZERO)
	_card_text(centre, -0.05, Vector2(-10, 140), "果凍主角（請勿食用）", 24, INK, 1.0, false)
