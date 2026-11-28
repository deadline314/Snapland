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

## Back to front: tiled wall with tall windows onto a sky where sweets fall up,
## a slow far layer of drifting candy, glass syrup tubes running the wrong way,
## gravity bubbles and a near layer of candy, the workers on their catwalks,
## the upside-down conveyor on the ceiling and the floor belt.
func _draw_backdrop() -> void:
	stamp(_wall(), Vector2.ZERO)
	_draw_windows()
	_draw_drift(0)
	_draw_tubes()
	_draw_bubbles()
	_draw_drift(1)
	_draw_workers()
	_draw_ceiling_belt()
	stamp(_belt(), Vector2(0, BELT_Y))
	draw_rect(Rect2(0, BELT_Y - 6.0, 1280, 6), Color(0.2, 0.1, 0.2, 0.25))


## Three tall arched windows; through them a pastel sky with sweets rising.
func _draw_windows() -> void:
	var frame := Pixels.bake("jelly|window", Vector2i(44, 78), func(x: int, y: int) -> Color:
		var arch := Vector2(x + 0.5 - 22.0, y + 0.5 - 22.0)
		var inside := y >= 22 or arch.length() <= 22.0
		if not inside:
			return Pixels.CLEAR
		var inner := (y >= 22 and x >= 3 and x <= 40 and y <= 74) or (y < 22 and arch.length() <= 19.0)
		if not inner:
			return Pixels.wood(Color("#b7798f"), x, y, 4)
		if x == 21 or x == 22 or y == 46:
			return Color("#9a6178")
		return Color("#ffd9c9").lerp(Color("#bfe3f5"), clampf(float(y) / 74.0, 0.0, 1.0)))
	for i in 3:
		var at := Vector2(210.0 + i * 360.0, 230.0)
		stamp(frame, at)
		# Sweets rising past the window, clipped to its glass.
		for k in 4:
			var rise := 0.0 if reduced_motion else now * 22.0
			var y := at.y + 300.0 - fposmod(k * 80.0 + i * 37.0 + rise, 280.0)
			if y > at.y + 20.0 and y < at.y + 296.0:
				var tone: Color = SPRINKLES[(i + k) % SPRINKLES.size()]
				draw_rect(Rect2(at + Vector2(24.0 + (k * 37) % 120, y - at.y), Vector2(12, 8)), Color(tone, 0.7))


## Wrapped sweets, sugar cubes, gumdrops and lollipops, baked once each.
func _sweet(kind: int) -> Texture2D:
	return Pixels.bake("jelly|sweet|%d" % kind, Vector2i(10, 8), func(x: int, y: int) -> Color:
		var tone: Color = SPRINKLES[kind % SPRINKLES.size()]
		match kind % 4:
			0:
				# A wrapped sweet with twisted ends.
				var body := absf(x + 0.5 - 5.0) < 2.6 and y >= 1 and y <= 6
				var tail := (x <= 2 or x >= 7) and absf(y + 0.5 - 4.0) < float(absi(x - 5)) * 0.7 - 0.6
				if body:
					return Pixels.rounded(tone, Vector2((x - 5.0) / 3.0, (y - 3.5) / 3.0))
				return tone.lightened(0.25) if tail else Pixels.CLEAR
			1:
				# A sugar cube with a sparkle.
				if x < 1 or x > 7 or y < 1 or y > 7:
					return Pixels.CLEAR
				return Color("#fffaf2") if x + y < 6 else Color("#e8e2ea")
			2:
				var drop := Vector2((x + 0.5 - 5.0) / 4.0, (y + 0.5 - 5.0) / 3.5)
				return Pixels.rounded(tone, drop) if drop.length_squared() <= 1.0 and y >= 1 else Pixels.CLEAR
		var disc := Vector2(x + 0.5 - 5.0, y + 0.5 - 4.0)
		if disc.length() <= 3.6:
			return tone if int(disc.angle() * 2.0 + disc.length()) % 2 == 0 else Color("#fffaf2")
		return Pixels.CLEAR)


## Sweets falling upward: layer 0 small, slow and faint (far), layer 1 big and quicker (near).
func _draw_drift(layer: int) -> void:
	var count := 14 if layer == 0 else 8
	var speed := 18.0 if layer == 0 else 46.0
	var size := 2.0 if layer == 0 else TEXEL
	var alpha := 0.55 if layer == 0 else 0.95
	for i in count:
		var rise := 0.0 if reduced_motion else now * speed * (1.0 + 0.15 * float(i % 3))
		var y := 720.0 - fposmod(i * 97.0 + layer * 41.0 + rise, 640.0)
		var sway := 0.0 if reduced_motion else sin(now * 0.8 + i * 1.7) * (10.0 + layer * 14.0)
		var x := fposmod(i * 173.0 + layer * 89.0, 1300.0) - 10.0 + sway
		var spin := 0.0 if reduced_motion else now * (0.6 + 0.2 * (i % 3)) * (1.0 if i % 2 == 0 else -1.0)
		draw_set_transform(Vector2(x, y), spin)
		Props.stamp(self, _sweet(i + layer * 3), Vector2(-5, -4) * size, size, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO)


## Glass tubes standing ceiling to floor, brass collars, syrup and bubbles
## climbing inside them the wrong way.
func _draw_tubes() -> void:
	# Cached, not baked: the baker makes every texel opaque, and this is glass.
	var glass := Pixels.cached("jelly|tube", func() -> Image:
		var image := Image.create(12, 92, false, Image.FORMAT_RGBA8)
		for y in 92:
			for x in 12:
				var tone := Color("#e6f4fa", 0.22)
				if x == 0 or x == 11:
					tone = Color("#7f97ad")
				elif x == 2 or x == 3:
					tone = Color("#ffffff", 0.7)
				elif x == 9:
					tone = Color("#bcd4e2", 0.45)
				if y % 30 < 3:
					tone = Pixels.metal(Color("#c9953e"), x, y)
				image.set_pixel(x, y, tone)
		return image)
	for tube in 4:
		var x := 90.0 + tube * 360.0
		var top := SHELF_Y + 6.0
		# Syrup slugs and bubbles rising inside, drawn first so the glass shines over them.
		for slug in 5:
			var rise := 0.0 if reduced_motion else now * (70.0 + tube * 9.0)
			var y := BELT_Y - fposmod(slug * 76.0 + tube * 23.0 + rise, BELT_Y - top)
			draw_rect(Rect2(x + 8.0, roundf(y / TEXEL) * TEXEL, 32, 28), Color(SYRUP, 0.8))
			draw_rect(Rect2(x + 12.0, roundf(y / TEXEL) * TEXEL + 4.0, 8, 4), Color("#ffd37a"))
		for bubble in 6:
			var rise := 0.0 if reduced_motion else now * 110.0
			var y := BELT_Y - fposmod(bubble * 59.0 + tube * 11.0 + rise, BELT_Y - top)
			draw_rect(Rect2(x + 16.0 + (bubble % 3) * 6.0, roundf(y / TEXEL) * TEXEL, TEXEL, TEXEL), Color("#fff4e2", 0.8))
		draw_texture_rect(glass, Rect2(x, top, 48, BELT_Y - top), false)


## Big gravity bubbles drifting up, each carrying a sweet, wobbling as they go.
func _draw_bubbles() -> void:
	for i in 5:
		var rise := 0.0 if reduced_motion else now * (24.0 + i * 5.0)
		var y := 700.0 - fposmod(i * 131.0 + rise, 560.0)
		var x := 160.0 + fposmod(i * 263.0, 980.0) + (0.0 if reduced_motion else sin(now * 1.1 + i) * 24.0)
		var radius := 30.0 + (i % 3) * 8.0
		var wobble := Vector2(1.0, 1.0) if reduced_motion else Vector2(1.0 + 0.06 * sin(now * 3.0 + i), 1.0 - 0.06 * sin(now * 3.0 + i))
		draw_set_transform(Vector2(x, y), 0.0, wobble)
		draw_circle(Vector2.ZERO, radius, Color("#e6f6ff", 0.16))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color("#ffffff", 0.55), TEXEL * 0.75)
		draw_arc(Vector2.ZERO, radius * 0.7, -2.4, -1.6, 6, Color("#ffffff", 0.8), TEXEL)
		Props.stamp(self, _sweet(i + 1), Vector2(-5, -4) * 3.0, 3.0, Color(1, 1, 1, 0.85))
		draw_set_transform(Vector2.ZERO)


## The conveyor on the ceiling, running upside down: rollers, a moving belt and
## boxes of sweets riding along under it.
func _draw_ceiling_belt() -> void:
	var travel := 0.0 if reduced_motion else fposmod(now * 50.0, 32.0)
	panel(Rect2(-8, SHELF_Y - 40.0, 1296, 20), "enamel", SHELF, Color("#e9c68f"))
	for x in range(-32, 1312, 32):
		var at := float(x) + travel
		draw_rect(Rect2(at, SHELF_Y - 20.0, 24, 14), BELT.lightened(0.12))
		draw_rect(Rect2(at + 24.0, SHELF_Y - 20.0, 8, 14), BELT.darkened(0.25))
	for roller in 14:
		var c := Vector2(40.0 + roller * 94.0, SHELF_Y - 22.0)
		draw_circle(c, 9.0, Color("#5b5368"))
		draw_circle(c, 4.0, Color("#c9953e"))
	draw_rect(Rect2(0, SHELF_Y - 6.0, 1280, 6), Color(0.2, 0.1, 0.2, 0.35))
	# Sweet boxes hanging under the belt, carried along it.
	for box in 5:
		var x := fposmod(box * 290.0 + (0.0 if reduced_motion else now * 50.0), 1450.0) - 80.0
		var tone: Color = SPRINKLES[box % SPRINKLES.size()]
		panel(Rect2(x, SHELF_Y - 6.0, 56, 40), "paper", tone.lerp(Color("#fff4e2"), 0.4))
		draw_rect(Rect2(x + 6.0, SHELF_Y + 14.0, 44, 6), tone)


## A factory hand in silhouette: rounded shoulders, a head, and a white toque
## catching the light.
func _worker() -> Texture2D:
	return Pixels.bake("jelly|worker", Vector2i(14, 22), func(x: int, y: int) -> Color:
		var dx := x + 0.5 - 7.0
		if y < 7:
			var puff := Vector2(dx / 4.5, (y + 0.5 - 3.5) / 3.5)
			return Pixels.rounded(Color("#f6efe6"), puff * 0.5) if puff.length_squared() <= 1.0 or (y >= 5 and absf(dx) < 3.5) else Pixels.CLEAR
		if y < 12:
			return Color("#4a3a5c") if Vector2(dx / 3.4, (y + 0.5 - 9.5) / 3.0).length_squared() <= 1.0 else Pixels.CLEAR
		var shoulder := absf(dx) < minf(6.5, 3.0 + float(y - 11) * 1.6)
		return (Color("#5a4a6e") if y == 12 else Color("#3a2c4a")) if shoulder else Pixels.CLEAR)


## Factory hands in toques on the side catwalks: they bob while watching, jump
## with their arms up when the real jelly is scooped, slump at a burst copy and
## cheer at the cake.
func _draw_workers() -> void:
	var walk := Pixels.bake("jelly|catwalk", Vector2i(40, 4), func(x: int, y: int) -> Color:
		return Pixels.metal(Color("#7a7088"), x, y) if y < 2 or x % 6 == 0 else Pixels.CLEAR)
	var scooped := now - float(state.get("scoop_at", -99.0))
	var goo := now - float(state.get("goo_at", -99.0))
	var cheer := str(state.get("phase", "")) == "finale"
	for side in 2:
		var base_x := 0.0 if side == 0 else 1120.0
		stamp(walk, Vector2(base_x, 470))
		for worker in 2:
			var x := base_x + 40.0 + worker * 70.0
			var lift := 0.0
			var arms_up := false
			if not reduced_motion:
				lift = 2.0 * sin(now * 1.6 + worker + side)
				if (scooped >= 0.0 and scooped < 0.8) or cheer:
					lift -= 22.0 * absf(sin(PI * fposmod(now * 1.6 + worker * 0.3, 1.0)))
					arms_up = true
				elif goo >= 0.0 and goo < 1.2:
					lift += 6.0
			var foot := Vector2(x, 470.0 + lift).round()
			var ink := Color("#3a2c4a")
			stamp(_worker(), foot - Vector2(7, 22) * TEXEL)
			if arms_up:
				for hand: float in [-1.0, 1.0]:
					draw_rect(Rect2(foot + Vector2(hand * 26.0 - 4.0, -92), Vector2(8, 40)), ink)
					draw_rect(Rect2(foot + Vector2(hand * 26.0 - 6.0, -100), Vector2(12, 10)), Color("#f6efe6"))
			if (scooped >= 0.0 and scooped < 0.9) and worker == side:
				label(foot + Vector2(0, -102.0 - 20.0 * scooped), "好耶！", 20, GOLD, 1.0, 1.0 - scooped)


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
