extends "res://game/minigames/arcade/arcade_view.gd"
## 倒影首映照: the welcome avenue hangs upside down from the top of the picture,
## 倒倒 floats in the inverted sky, the traveller walks the fountain rim with a
## viewfinder, and the pool below shows 倒倒's reflection running ahead in time.
## Everything is drawn from the driver state; 倒倒 and its reflection are the
## shared part rig solved at the body's time and at the reflection's time.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Daodao = preload("res://game/minigames/arcade/daodao_rig.gd")
const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")

## The water line, the walker's feet and 倒倒's root (under its knot).
const MIRROR_Y := 486.0
const RIM_TOP := 474.0
const RIM_BOTTOM := 506.0
const BOSS_Y := 404.0
const FRAME_TOP := 176.0
const FRAME_BOTTOM := 462.0
const HERO_SCALE := 2.5
const REFLECT_SCALE := 0.5
const SKY := Color("#9fd3ee")
const SKY_DEEP := Color("#6fb3dc")
const WATER := Color("#3f8fa6")
const STONE := Color("#c9b48c")
const GRASS := Color("#7fb35e")
const PAVING := Color("#d9c59a")
const CREAM_CARD := Color("#fff6e2")
const CAPE := Color("#8c2f4e")
const CAPE_TRIM := Color("#e3ae4a")
const CONFETTI: Array[Color] = [Color("#ff6f7d"), Color("#ffd166"), Color("#70e1c1"), Color("#7fb8ee"), Color("#c99cf0")]

var rig: Rig
var body_stage: Rig.Stage
var mirror_stage: Rig.Stage


func _init() -> void:
	super._init()
	rig = Daodao.build()
	body_stage = Rig.Stage.new(Daodao.STAGE, rig, Daodao.ROOT)
	mirror_stage = Rig.Stage.new(Daodao.STAGE, rig, Daodao.ROOT)
	add_child(body_stage)
	add_child(mirror_stage)


func present(next_state: Dictionary, reduced: bool) -> void:
	super.present(next_state, reduced)
	if state.is_empty():
		return
	rig.reduced_motion = reduced_motion
	var hidden: Array = state.get("popped", [])
	var body: Dictionary = state.get("boss", {})
	var move := str(body.get("move", "idle"))
	var t := float(body.get("t", 0.0))
	var shy := now - float(state.get("capture_at", -99.0))
	if shy >= 0.0 and shy < 1.3 and str(state.get("phase", "show")) == "show":
		move = "shy"
		t = shy
	var drift := Vector2.ZERO
	var dash: Dictionary = state.get("dash", {})
	if not dash.is_empty() and float(dash.t) >= 0.6:
		drift.x = signf(float(dash.to) - float(dash.from)) * 1400.0 / TEXEL
	body_stage.show_pose(rig.solve(move, t, now, shy, hidden, drift))
	var mirror: Dictionary = state.get("reflection", {})
	mirror_stage.show_pose(rig.solve(str(mirror.get("move", "idle")), float(mirror.get("t", 0.0)), now + float(state.get("lead", 0.0)), INF, hidden))


func _draw() -> void:
	if state.is_empty():
		return
	_font = Paper.font()
	_draw_backdrop()
	_draw_scene()
	draw_set_transform(Vector2.ZERO)
	# The curtain-call and selfie pictures are kept clean for the album.
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
	# The inverted sky: deepest blue up by the hanging avenue, pale at the water.
	stamp(_sky(), Vector2.ZERO)
	_draw_clouds()
	_draw_hanging_avenue()
	_draw_pool()
	_draw_rim()


func _sky() -> Texture2D:
	return Pixels.cached("premiere|sky", func() -> Image:
		var image := Image.create(320, 124, false, Image.FORMAT_RGBA8)
		for y in 124:
			for x in 320:
				var u := float(y) / 123.0 + (Pixels.BAYER[(y % 4) * 4 + x % 4] / 16.0 - 0.5) * 0.08
				var tone := SKY_DEEP.lerp(SKY, floorf(clampf(u, 0.0, 1.0) * 6.0) / 6.0)
				image.set_pixel(x, y, tone)
		return image)


func _draw_clouds() -> void:
	var cloud := Pixels.bake("premiere|cloud", Vector2i(34, 9), func(x: int, y: int) -> Color:
		var bump := 3.0 + 2.2 * sin(x * 0.55) + (2.0 if x > 10 and x < 24 else 0.0)
		if float(y) < 8.0 - bump or (x < 2 or x > 31) and y < 5:
			return Pixels.CLEAR
		return Pixels.grainy(Color("#f4fbff").darkened(0.06 * float(y > 6)), x, y, 0.04))
	for i in 5:
		var speed := 0.0 if reduced_motion else 9.0 + i * 3.0
		var x := fposmod(i * 290.0 + now * speed, 1500.0) - 180.0
		stamp(cloud, Vector2(x, 250.0 + (i % 3) * 52.0), TEXEL, Color(1, 1, 1, 0.9))


## The avenue turned upside down: paving and lawn along the top, flowerbeds and
## lamp posts hanging into the sky, the welcome arch sign the wrong way up.
func _draw_hanging_avenue() -> void:
	var ceiling := Pixels.bake("premiere|ceiling", Vector2i(320, 40), func(x: int, y: int) -> Color:
		if y < 22:
			# Paving seen from below, joints staggered.
			var row := y / 6
			if y % 6 == 5 or (x + (row % 2) * 5) % 10 == 0:
				return PAVING.darkened(0.32)
			return Pixels.grainy(PAVING.darkened(0.08 * Pixels.noise(x / 10, row, 3)), x, y, 0.06)
		if y < 25:
			return STONE.darkened(0.2)
		var edge := 32.0 + 3.0 * sin(x * 0.4) + 2.0 * sin(x * 1.7)
		if float(y) > edge:
			return Pixels.CLEAR
		var tone := GRASS.darkened(0.1 * float(y > 29))
		if Pixels.noise(x, y, 11) > 0.9:
			tone = [Color("#f6a3b9"), Color("#ffe08a"), Color("#fff1d2")][x % 3]
		return Pixels.grainy(tone, x, y, 0.08))
	stamp(ceiling, Vector2.ZERO)
	var post := Pixels.bake("premiere|lamp", Vector2i(9, 30), func(x: int, y: int) -> Color:
		if y >= 22:
			var glass := Vector2((x + 0.5 - 4.5) / 4.5, (y + 0.5 - 26.0) / 4.0)
			return Pixels.rounded(Color("#fff0b8"), glass) if glass.length_squared() <= 1.0 else Pixels.CLEAR
		if y >= 20:
			return Color("#3b4a5e") if x >= 1 and x <= 7 else Pixels.CLEAR
		return Pixels.metal(Color("#4a5b72"), x, y) if x >= 3 and x <= 5 else Pixels.CLEAR)
	var planter := Pixels.bake("premiere|planter", Vector2i(30, 14), func(x: int, y: int) -> Color:
		if y < 6:
			return Pixels.wood(Color("#9a6a42"), x, y, 7, false)
		var bloom := Pixels.noise(x / 2, y / 2, 21)
		if float(y) > 8.0 + 5.0 * Pixels.noise(x / 3, 2, 22):
			return Pixels.CLEAR
		return [Color("#f6a3b9"), Color("#ffe08a"), Color("#e2604f"), GRASS][int(bloom * 3.99)] if bloom > 0.45 else Pixels.grainy(GRASS, x, y, 0.1))
	for i in 4:
		var x := 120.0 + i * 340.0
		stamp(post, Vector2(x, 140.0))
		cast_shadow(post, Vector2(x, 140.0), Vector2(8, 10))
	for i in 3:
		stamp(planter, Vector2(250.0 + i * 340.0, 150.0))
	# The arch sign, upside down: the 迎賓 lettering reads the wrong way up.
	# Hung on two rods below the medal strip.
	var board := Rect2(530, 178, 220, 52)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(board.get_center().x + side * 80.0 - 2.0, 146, 4, 32), Color("#4a5b72"))
	panel(board, "planks", Color("#7a4e8a"))
	gilt_frame(board, 8.0)
	if _font != null:
		var extent := _font.get_string_size("倒影大道", HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
		var origin := Vector2(-extent.x * 0.5, extent.y * 0.32)
		draw_set_transform(board.get_center(), PI)
		draw_string_outline(_font, origin, "倒影大道", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, INK)
		draw_string(_font, origin, "倒影大道", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, CREAM)
		draw_set_transform(Vector2.ZERO)


func _draw_pool() -> void:
	var water := Pixels.bake("premiere|water", Vector2i(320, 54), func(x: int, y: int) -> Color:
		var tone := WATER.darkened(0.05 * y / 6.0)
		var ripple := sin(x * 0.21 + y * 1.7) + sin(x * 0.07 - y * 0.9)
		if ripple > 1.55:
			tone = tone.lightened(0.22)
		elif ripple < -1.6:
			tone = tone.darkened(0.12)
		return Pixels.grainy(tone, x, y, 0.05))
	stamp(water, Vector2(0, RIM_BOTTOM))
	# The reflected avenue stands the right way up in the water, faint and wavering.
	for i in 3:
		var at := Vector2(250.0 + i * 340.0, 662.0)
		draw_rect(Rect2(at, Vector2(120, 20)), Color("#2f6f80", 0.45))
		draw_rect(Rect2(at + Vector2(8, -14), Vector2(104, 14)), Color("#5f9a6a", 0.35))
	if not reduced_motion:
		for i in 14:
			var y := RIM_BOTTOM + 18.0 + fposmod(i * 37.0 + now * 6.0, 196.0)
			var x := fposmod(i * 163.0 + sin(now * 0.7 + i) * 20.0, 1280.0)
			draw_rect(Rect2(x, roundf(y / TEXEL) * TEXEL, 36.0 + (i % 3) * 16.0, TEXEL), Color("#a9dcef", 0.35))


func _draw_rim() -> void:
	var rim := Pixels.bake("premiere|rim", Vector2i(320, 8), func(x: int, y: int) -> Color:
		if y == 0:
			return STONE.lightened(0.18)
		if (x + (y / 4) * 7) % 14 == 0 or y == 4:
			return STONE.darkened(0.36)
		return Pixels.grainy(STONE.darkened(0.08 * Pixels.noise(x / 14, y / 4, 5) + 0.05 * float(y > 4)), x, y, 0.07))
	stamp(rim, Vector2(0, RIM_TOP))
	draw_rect(Rect2(0, RIM_BOTTOM, 1280, 8), Color(0.08, 0.06, 0.12, 0.3))


# --- Scene ------------------------------------------------------------------

func _draw_scene() -> void:
	var body: Dictionary = state.get("boss", {})
	var mirror: Dictionary = state.get("reflection", {})
	_draw_reflection(mirror)
	_draw_telegraphs()
	_draw_boss(body)
	_draw_confetti()
	_draw_viewfinder()
	_draw_hero()
	_draw_balloon_count()
	_draw_act_banner()
	_draw_curtains()


## The reflection hangs below the water line, flipped (and mirrored left-right
## in act three), drawn in rows that sway like a wavering pool.
func _draw_reflection(mirror: Dictionary) -> void:
	var texture := mirror_stage.get_texture()
	var size := Vector2(Daodao.STAGE) * TEXEL
	# A pool reflection is foreshortened: half height, so the whole of 倒倒 fits.
	var root_y := MIRROR_Y + (MIRROR_Y - BOSS_Y - float(mirror.get("y", 0.0))) * REFLECT_SCALE
	var x := float(mirror.get("x", 640.0))
	var flip_x := bool(state.get("mirrored", false))
	var glow := bool(state.get("reflection_open", false))
	var tint := Color(0.72, 0.9, 1.0, 0.78) if not glow else Color(1.0, 0.92, 0.55, 0.92)
	var rows := int(Daodao.STAGE.y)
	for row in rows:
		var y := root_y + (Daodao.ROOT.y - row - 1) * TEXEL * REFLECT_SCALE
		if y < RIM_BOTTOM or y > 720.0:
			continue
		var sway := 0.0 if reduced_motion else roundf(sin(now * 3.0 + row * 0.45) * 1.5) * TEXEL
		var source := Rect2(0, row, Daodao.STAGE.x, 1)
		var left := x - Daodao.ROOT.x * TEXEL + sway
		var dest := Rect2(left, y, size.x, TEXEL * REFLECT_SCALE)
		if flip_x:
			dest = Rect2(x + Daodao.ROOT.x * TEXEL + sway, y, -size.x, TEXEL * REFLECT_SCALE)
		draw_texture_rect_region(texture, dest, source, tint)
	if glow:
		var sparkle := Vector2(x, root_y + 60.0)
		glint(sparkle, 60.0, 0.6)
		label(sparkle + Vector2(0, -40), "★", 40, GOLD, 0.8 + 0.3 * pulse(3.0))


func _draw_telegraphs() -> void:
	var dash: Dictionary = state.get("dash", {})
	if not dash.is_empty():
		# A dotted streak on the rim marks the lane before the strike.
		var from := float(dash.from)
		var to := float(dash.to)
		var lit := clampf(float(dash.t) / 0.6, 0.0, 1.0)
		var step := 24.0 * signf(to - from)
		var x := from
		while (to - x) * signf(step) > 0.0:
			draw_rect(Rect2(x - 6.0, RIM_TOP - 10.0, 12, 6), Color(ROSE, 0.35 + 0.5 * lit))
			x += step
	for spot: float in state.get("spots", []):
		var t := float(state.get("confetti_t", 0.0))
		if t < 1.4:
			# Rings spread in the pool where the confetti will land, then a shadow on the rim.
			var grow := 0.0 if reduced_motion else fmod(t * 1.6, 1.0)
			Props.oval_shadow(self, Vector2(spot, RIM_TOP + 4.0), Vector2(70, 10), 0.25 + 0.3 * clampf(t / 1.3, 0.0, 1.0), SPRITE_SHADE)
			draw_arc(Vector2(spot, 560.0), 20.0 + 50.0 * grow, 0.0, TAU, 24, Color("#d6f1fb", 0.7 * (1.0 - grow)), TEXEL)


func _draw_boss(body: Dictionary) -> void:
	var at := Vector2(float(body.get("x", 640.0)), BOSS_Y + float(body.get("y", 0.0)))
	ground_shadow(Vector2(at.x, RIM_TOP + 2.0), Vector2(70, 9), 0.22)
	var size := Vector2(Daodao.STAGE) * TEXEL
	draw_texture_rect(body_stage.get_texture(), Rect2(at - Daodao.ROOT * TEXEL, size), false)
	var kind := str(body.get("kind", ""))
	var t := float(body.get("t", 0.0))
	if kind == "pose":
		# Three gold pips count into the 亮相; a sparkle ring while it lasts.
		if t < 0.48:
			for pip in 3:
				var on := t >= pip * 0.16
				var pip_at := at + Vector2(-32 + pip * 26, -262)
				draw_rect(Rect2(pip_at, Vector2(16, 16)), INK)
				draw_rect(Rect2(pip_at + Vector2(4, 4), Vector2(8, 8)), GOLD if on else Color("#6b5a3a"))
		elif bool(state.get("pose_open", false)):
			draw_arc(at + Vector2(0, -110), 120.0 + 6.0 * pulse(4.0), 0.0, TAU, 40, Color(GOLD, 0.8), TEXEL)
	var capture := now - float(state.get("capture_at", -99.0))
	if capture >= 0.0 and capture < 0.8:
		dust_puffs(at + Vector2(-90, -170), capture, 50.0)


func _draw_confetti() -> void:
	var t := float(state.get("confetti_t", -1.0))
	var spots: Array = state.get("spots", [])
	if spots.is_empty() or t < 1.0:
		return
	var boss_x := float(state.get("boss", {}).get("x", 640.0))
	for spot: float in spots:
		for piece in 9:
			var fall := clampf((t - 1.0) / 0.3, 0.0, 1.0)
			var start := Vector2(boss_x + (piece - 4) * 6.0, BOSS_Y - 120.0)
			var end := Vector2(spot + (piece - 4) * 13.0, RIM_TOP - 6.0 - (piece % 3) * 4.0)
			var at := start.lerp(end, fall) + Vector2(0, -60.0 * sin(PI * fall))
			draw_rect(Rect2(at.round(), Vector2(TEXEL * 2.0, TEXEL)), CONFETTI[piece % CONFETTI.size()])


func _draw_viewfinder() -> void:
	var x := float(state.get("frame_x", 640.0))
	var bumped := now - float(state.get("bump_at", -99.0))
	var spin := 0.0
	if bumped >= 0.0 and bumped < 1.5 and not reduced_motion:
		spin = sin(bumped * 14.0) * 0.18 * (1.0 - bumped / 1.5)
	var center := Vector2(x, (FRAME_TOP + FRAME_BOTTOM) * 0.5)
	var half := Vector2(95, (FRAME_BOTTOM - FRAME_TOP) * 0.5)
	var ready := bool(state.get("pose_open", false))
	var colour := GOLD if ready else CREAM
	if bumped >= 0.0 and bumped < 1.5:
		colour = ROSE
	draw_set_transform(center, spin)
	for corner in 4:
		var sx := -1.0 if corner % 2 == 0 else 1.0
		var sy := -1.0 if corner < 2 else 1.0
		var tip := Vector2(sx * half.x, sy * half.y)
		for pass_index in 2:
			var width := 12.0 if pass_index == 0 else 6.0
			var tone := INK if pass_index == 0 else colour
			draw_line(tip, tip - Vector2(sx * 34.0, 0), tone, width)
			draw_line(tip, tip - Vector2(0, sy * 34.0), tone, width)
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color(colour, 0.7), TEXEL)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(colour, 0.7), TEXEL)
	if bool(state.get("lens_dirty", false)):
		# Confetti stuck on the lens; each wiggle shakes some off.
		var left := 1.0 - 0.45 * float(state.get("wipes", 0))
		for blob in int(14 * left):
			var spot := Vector2(Pixels.noise(blob, 1, 7) - 0.5, Pixels.noise(blob, 2, 7) - 0.5) * half * 1.6
			draw_rect(Rect2(spot.round(), Vector2(TEXEL * 4.0, TEXEL * 3.0)), CONFETTI[blob % CONFETTI.size()])
	var flash := now - float(state.get("shutter_at", -99.0))
	if flash >= 0.0 and flash < 0.14:
		draw_rect(Rect2(-half, half * 2.0), Color(1, 1, 1, 0.75 * (1.0 - flash / 0.14)))
	draw_set_transform(Vector2.ZERO)
	var capture := now - float(state.get("capture_at", -99.0))
	if capture >= 0.0 and capture < 1.0:
		label(center + Vector2(0, -half.y - 26.0 - 30.0 * capture), "+%d" % int(state.get("last_quality", 0)), 30, GOLD, 1.0, 1.0 - capture)


func _draw_hero() -> void:
	var x := float(state.get("frame_x", 640.0))
	var bumped := now - float(state.get("bump_at", -99.0))
	var mood := "plain"
	if bumped >= 0.0 and bumped < 1.5:
		mood = "shocked"
	elif bool(state.get("lens_dirty", false)):
		mood = "sorry"
	var texture := Hero.texture(&"up", false, mood)
	var at := Vector2(x, RIM_TOP + 6.0) - Hero.FEET * HERO_SCALE
	ground_shadow(Vector2(x, RIM_TOP + 4.0), Vector2(30, 7), 0.3)
	if bumped >= 0.0 and bumped < 1.5 and not reduced_motion:
		var spin := sin(bumped * 12.0) * 0.4 * (1.0 - bumped / 1.5)
		draw_set_transform(Vector2(x, RIM_TOP), spin)
		stamp(texture, at - Vector2(x, RIM_TOP), HERO_SCALE)
		draw_set_transform(Vector2.ZERO)
	else:
		stamp(texture, at, HERO_SCALE)


func _draw_balloon_count() -> void:
	var captured := int(state.get("captures", 0))
	# The troupe's balloons still to photograph; a taken one is a faded ghost.
	for i in 6:
		var faded := i < captured
		stamp(Daodao._balloon(i), Vector2(36 + i * 34, 136), 2.0, Color(1, 1, 1, 0.28) if faded else Color.WHITE)


func _draw_act_banner() -> void:
	var body: Dictionary = state.get("boss", {})
	if str(body.get("kind", "")) != "interlude":
		return
	var t := float(body.get("t", 0.0))
	var title := "第二幕・彩紙登場" if int(state.get("act", 2)) <= 2 else "第三幕・倒影顛倒"
	var settle := pop_in(t, 0.3)
	paper_scrap(Rect2(400, 300, 480, 90), -0.03, 7)
	label(Vector2(640, 345), title, 40, INK, settle, 1.0, false)


## Velvet curtains close for the bow and the selfie; a corner of a plum cape
## peeks round the right-hand curtain (someone backstage is watching).
func _draw_curtains() -> void:
	var phase := str(state.get("phase", "show"))
	if phase == "show":
		return
	var age := now - float(state.get("phase_at", now))
	var close := 0.55 if phase == "curtain" else 1.0
	var reach := close * smoothstep(0.0, 0.8, age) if not reduced_motion else close
	var width := 640.0 * reach
	panel(Rect2(-8, PLAY_TOP, width * 0.62 + 8.0, 720 - PLAY_TOP), "velvet", Color("#8e2638"), GOLD)
	panel(Rect2(1280 - width * 0.62, PLAY_TOP, width * 0.62 + 8.0, 720 - PLAY_TOP), "velvet", Color("#8e2638"), GOLD)
	if phase == "curtain":
		# A plum cape swings out from behind the curtain, gold hem, folds catching
		# the light, and a white glove holding the curtain's edge.
		var cape := Pixels.bake("premiere|cape", Vector2i(22, 40), func(x: int, y: int) -> Color:
			var spread := 21.0 - 13.0 * pow(1.0 - float(y) / 39.0, 1.6)
			if float(x) < 21.0 - spread:
				return Pixels.CLEAR
			if y >= 37:
				return CAPE_TRIM.darkened(0.15 * float(x % 4 == 0))
			var fold := sin(float(x) * 0.9 + float(y) * 0.12)
			var tone := CAPE.lightened(0.16) if fold > 0.55 else (CAPE.darkened(0.22) if fold < -0.55 else CAPE)
			return Pixels.grainy(tone, x, y, 0.05))
		var glove := Pixels.bake("premiere|glove", Vector2i(9, 8), func(x: int, y: int) -> Color:
			var finger := y < 4 and x % 2 == 0
			if not finger and (y < 3 or x > 7):
				return Pixels.CLEAR
			return Pixels.rounded(Color("#fbf6ee"), Vector2((x - 4.0) / 4.5, (y - 4.0) / 4.0)))
		var edge := 1280 - width * 0.62
		stamp(cape, Vector2(edge - 22.0 * TEXEL + 8.0, 300.0))
		stamp(glove, Vector2(edge - 20.0, 250.0))
	elif phase == "selfie":
		_draw_selfie(age)


func _draw_selfie(age: float) -> void:
	var flash_age := age - 1.6
	if flash_age >= 0.0 and flash_age < 0.25:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.8 * (1.0 - flash_age / 0.25)))
	if age < 2.2:
		label(Vector2(640, 250), "倒倒拿走了相機……", 34, CREAM)
		return
	# The selfie itself: a tilted polaroid of the traveller, dizzy under confetti.
	var drop := pop_in(age - 2.2, 0.3)
	var centre := Vector2(640, 410 + 60.0 * (1.0 - drop))
	draw_set_transform(centre, -0.08)
	draw_rect(Rect2(-170, -190, 340, 380), Color(0.05, 0.02, 0.08, 0.4))
	draw_rect(Rect2(-180, -200, 340, 380), CREAM_CARD)
	draw_rect(Rect2(-160, -180, 300, 270), SKY)
	draw_rect(Rect2(-160, 50, 300, 40), STONE)
	var hero := Hero.texture(&"idle", true, "shocked")
	Props.stamp(self, hero, Vector2(-10, 70) - Hero.FEET * 4.0, 4.0)
	for piece in 22:
		var at := Vector2(Pixels.noise(piece, 4, 9) * 200.0 - 110.0, Pixels.noise(piece, 5, 9) * 120.0 - 150.0)
		draw_rect(Rect2(at.round(), Vector2(10, 6)), CONFETTI[piece % CONFETTI.size()])
	draw_set_transform(Vector2.ZERO)
	_card_text(centre, -0.08, Vector2(-10, 140), "倒倒的自拍（你入鏡了）", 24, INK, 1.0, false)
