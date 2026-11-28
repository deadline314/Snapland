extends "res://game/minigames/arcade/arcade_view.gd"
## 燈塔追潮: a harbour at dusk whose tide runs the wrong way. Four lanes show
## their current as flowing foam streaks and arrows (teal with you, rust
## against you); the raft rides on the left, 錨錨's barrel boat ahead, the
## distance between them on a rope gauge. Drawn from the driver state only.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Anmao = preload("res://game/minigames/arcade/anmao_rig.gd")
const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")

const LANE_TOP := 342.0
const LANE_GAP := 92.0
const RAFT_X := 250.0
const SEA_TOP := 300.0
const WITH := Color("#7fe0d0")
const AGAINST := Color("#e8865e")
const SEA := Color("#2f7f98")
const SEA_DEEP := Color("#235f7a")
const DUSK: Array[Color] = [Color("#3b3f7a"), Color("#8a5f9e"), Color("#f19a7a"), Color("#ffd59a")]
const ROCK := Color("#4b4a63")
const TOWER := Color("#efe4cc")
const TOWER_BAND := Color("#d9604f")

var rig: Rig
var boss_stage: Rig.Stage


func _init() -> void:
	super._init()
	rig = Anmao.build()
	boss_stage = Rig.Stage.new(Anmao.STAGE, rig, Anmao.ROOT)
	add_child(boss_stage)


func present(next_state: Dictionary, reduced: bool) -> void:
	super.present(next_state, reduced)
	if state.is_empty():
		return
	rig.reduced_motion = reduced_motion
	var move := "idle"
	var t := now
	var drift := Vector2.ZERO
	var phase := str(state.get("phase", "chase"))
	var caught := now - float(state.get("caught_at", -99.0))
	var sprint := now - float(state.get("sprint_at", -99.0))
	var throw := float(state.get("throw_age", 99.0))
	if phase == "finale":
		move = "handback"
		t = now - float(state.get("phase_at", now))
	elif caught >= 0.0 and caught < 1.3:
		move = "caught"
		t = caught
	elif sprint >= 0.0 and sprint < 1.7:
		move = "sprint"
		t = sprint
		drift.x = 260.0 / TEXEL
	elif throw >= 0.0 and throw < 1.6:
		move = "throw"
		t = throw
	boss_stage.show_pose(rig.solve(move, t, now, caught, [], drift))


func lane_y(lane: float) -> float:
	return LANE_TOP + lane * LANE_GAP


func boss_x() -> float:
	return minf(1170.0, RAFT_X + 120.0 + float(state.get("gap", 600.0)))


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
	stamp(_sky(), Vector2.ZERO)
	_draw_lighthouse()
	stamp(_town(), Vector2(0, 230))
	stamp(_sea(), Vector2(0, SEA_TOP))


func _sky() -> Texture2D:
	return Pixels.cached("tide|sky", func() -> Image:
		var image := Image.create(320, 76, false, Image.FORMAT_RGBA8)
		for y in 76:
			for x in 320:
				var u := clampf(float(y) / 75.0 + (Pixels.BAYER[(y % 4) * 4 + x % 4] / 16.0 - 0.5) * 0.07, 0.0, 1.0)
				var band := floorf(u * 12.0) / 12.0
				var leg := minf(2.0, floorf(band * 3.0))
				var tone: Color = DUSK[int(leg)].lerp(DUSK[int(leg) + 1], band * 3.0 - leg)
				if Pixels.noise(x, y, 61) > 0.985 and y < 30:
					tone = Color("#fff7dc")
				image.set_pixel(x, y, tone)
		return image)


## The harbour town and breakwater in silhouette against the dusk.
func _town() -> Texture2D:
	return Pixels.cached("tide|town", func() -> Image:
		var image := Image.create(320, 18, false, Image.FORMAT_RGBA8)
		for x in 320:
			var block := x / 14
			var top := 18.0 - (5.0 + 9.0 * Pixels.noise(block, 4, 63))
			if x % 14 < 2:
				top += 3.0
			for y in 18:
				if float(y) >= top:
					var tone := Color("#3a3358")
					if Pixels.noise(x / 2, y / 2, 64) > 0.86 and y > top + 2.0:
						tone = Color("#ffd27a")
					image.set_pixel(x, y, tone)
		return image)


func _sea() -> Texture2D:
	return Pixels.cached("tide|sea", func() -> Image:
		var image := Image.create(320, 105, false, Image.FORMAT_RGBA8)
		for y in 105:
			for x in 320:
				var tone := SEA.lerp(SEA_DEEP, float(y) / 104.0)
				var lane := int((y * TEXEL + SEA_TOP - LANE_TOP + LANE_GAP * 0.5) / LANE_GAP)
				if lane % 2 == 1:
					tone = tone.darkened(0.06)
				if sin(x * 0.3 + y * 1.1) + sin(x * 0.11 - y * 0.7) > 1.6:
					tone = tone.lightened(0.14)
				image.set_pixel(x, y, Pixels.grainy(tone, x, y, 0.04))
		return image)


## The lighthouse on its rock, lamp room dark until the lamp comes home.
func _draw_lighthouse() -> void:
	var tower := Pixels.bake("tide|tower", Vector2i(22, 46), func(x: int, y: int) -> Color:
		var half := 5.0 + y * 0.12
		if y < 10:
			half = 6.5 if y >= 3 else 4.0 - (3 - y)
		if absf(x + 0.5 - 11.0) > half:
			return Pixels.CLEAR
		if y < 3:
			return TOWER_BAND
		if y < 10:
			return Color("#3a3358") if y >= 4 and y <= 8 and absf(x + 0.5 - 11.0) < 5.0 else Pixels.metal(Color("#5b6470"), x, y)
		var tone := TOWER_BAND if (y / 8) % 2 == 1 else TOWER
		return Pixels.rounded(tone, Vector2((x + 0.5 - 11.0) / half, 0.0)))
	var rock := Pixels.bake("tide|rock", Vector2i(60, 14), func(x: int, y: int) -> Color:
		var top := 6.0 * absf(x + 0.5 - 30.0) / 30.0 + 2.0 * Pixels.noise(x / 4, 1, 65)
		if float(y) < top:
			return Pixels.CLEAR
		return Pixels.grainy(ROCK.lightened(0.1 * float(y < top + 2.0)), x, y, 0.1))
	# Small and low enough that the lamp room stays clear of the HUD.
	stamp(rock, Vector2(930, 262))
	stamp(tower, Vector2(1034, 130), 3.0)
	var lit := str(state.get("phase", "")) == "finale"
	if lit:
		var age := now - float(state.get("phase_at", now))
		var sweep := 0.0 if reduced_motion else sin(age * 1.6) * 0.5
		var lamp := Vector2(1068, 148)
		var reach := Vector2(-900, 120).rotated(sweep)
		var cone := PackedVector2Array([lamp, lamp + reach + reach.orthogonal().normalized() * 110.0, lamp + reach - reach.orthogonal().normalized() * 110.0])
		draw_colored_polygon(cone, Color("#fff3c4", 0.28 * smoothstep(0.0, 0.8, age)))
		draw_circle(lamp, 16.0, Color("#fff3c4"))


# --- Scene ------------------------------------------------------------------

func _draw_scene() -> void:
	_draw_currents()
	_draw_flip_line()
	_draw_barrels()
	_draw_boss()
	_draw_raft()
	_draw_rope()
	_draw_fog()
	_draw_gap_gauge()
	_draw_postcard()


## Each lane is a band of water whose wave crests and foam run with its tide:
## the crests scroll its way, and foam streaks are comets (a bright head, a
## tail fading behind) so even a still picture shows which way it runs. A lane
## carrying you toward 錨錨 runs fast and frothy; one against you is choppier
## and darker. Troughs, not ropes, part the lanes.
func _draw_currents() -> void:
	var currents: Array = state.get("currents", [0, 0, 0, 0])
	for lane in 4:
		var flow := float(currents[lane])
		var y := lane_y(lane)
		var top := y - LANE_GAP * 0.5
		var dir := 1.0 if flow > 0.0 else -1.0
		var shift := 0.0 if reduced_motion else fposmod(now * flow * 0.9, 320.0)
		var water := _lane_water(flow > 0.0)
		for tile in 6:
			stamp(water, Vector2(roundf((shift - 320.0 + tile * 320.0) / TEXEL) * TEXEL, top), TEXEL, Color(1, 1, 1, 0.85))
		# The trough between lanes: a dark wave line with foam caps breaking on it.
		if lane > 0:
			for x in range(0, 1280, int(TEXEL)):
				var dip := roundf(sin(x * 0.045 + lane * 1.3 + (0.0 if reduced_motion else now * 1.2)) * 1.5) * TEXEL
				draw_rect(Rect2(x, top + dip, TEXEL, TEXEL), Color("#1d4f66", 0.55))
				if fposmod(x * 0.37 + lane * 11.0 + (0.0 if reduced_motion else now * flow * 0.3), 53.0) < 4.0:
					draw_rect(Rect2(x, top + dip - TEXEL, TEXEL * 2.0, TEXEL), Color(CREAM, 0.7))
		# Foam comets riding the tide.
		var count := 7 + int(absf(flow) / 12.0)
		for i in count:
			var speed := 0.0 if reduced_motion else flow * 1.7
			var x := fposmod(i * 163.0 + lane * 61.0 + now * speed, 1440.0) - 80.0
			var row := y - 30.0 + float((i * 29) % 60)
			var length := 16.0 + absf(flow) * 0.45
			for piece in 4:
				var reach := length * float(piece) / 4.0
				var at := Vector2(x - dir * reach, row + (TEXEL if piece == 3 else 0.0))
				var alpha := 0.9 - 0.22 * piece
				draw_rect(Rect2((at / TEXEL).floor() * TEXEL, Vector2(length / 4.0 + TEXEL, TEXEL)), Color(Color("#f4fbff") if flow > 0.0 else Color("#e6dcd2"), alpha))
		# Glints of the dusk sky on the crests.
		if not reduced_motion:
			for i in 6:
				var twinkle := fposmod(now * 0.9 + i * 0.41 + lane * 0.17, 1.0)
				if twinkle < 0.35:
					var gx := fposmod(i * 211.0 + lane * 97.0 + now * flow * 0.9, 1280.0)
					draw_rect(Rect2((Vector2(gx, top + 10.0 + float((i * 17) % 70)) / TEXEL).floor() * TEXEL, Vector2(TEXEL * (2.0 if twinkle < 0.15 else 1.0), TEXEL)), Color("#ffe6b8", 0.9))
		if roundi(float(state.get("raft_lane", 1))) == lane:
			label(Vector2(150, y - 30.0), "順流" if flow > 0.0 else "逆流", 20, WITH if flow > 0.0 else AGAINST)


## A tileable strip of lane water: rows of wave crests with light faces and
## dark backs; a lane with you is smooth and bright, one against you choppier.
func _lane_water(with_you: bool) -> Texture2D:
	return Pixels.cached("tide|lane|%s" % with_you, func() -> Image:
		var size := Vector2i(80, int(LANE_GAP / TEXEL))
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var base := SEA.lightened(0.04) if with_you else SEA_DEEP.lightened(0.04)
		var waves := 2.0 if with_you else 3.0
		for y in size.y:
			for x in size.x:
				var phase := TAU * waves * float(x) / size.x + float(y) * 0.85 + sin(TAU * float(x) / size.x + y * 0.3) * 0.8
				var crest := sin(phase)
				var tone := base.darkened(0.04 * float(y) / size.y)
				if crest > 0.86:
					tone = tone.lightened(0.24)
				elif crest > 0.6:
					tone = tone.lightened(0.1)
				elif crest < -0.75:
					tone = tone.darkened(0.12)
				image.set_pixel(x, y, tone)
		return image)


## Spray where a barrel smacks into the water: a crown of droplets thrown up
## and falling back, with a ring of foam spreading under it.
func _spray(at: Vector2, age: float) -> void:
	if age < 0.0 or age > 0.7:
		return
	var u := age / 0.7
	draw_arc(at, 20.0 + 50.0 * u, 0.0, TAU, 20, Color(CREAM, 0.8 * (1.0 - u)), TEXEL)
	if reduced_motion:
		return
	for drop in 12:
		var angle := -PI * (0.12 + 0.76 * float(drop) / 11.0)
		var speed := 180.0 + 60.0 * float(drop % 3)
		var point := at + Vector2(cos(angle), sin(angle)) * speed * age + Vector2(0, 420.0 * age * age)
		draw_rect(Rect2((point / TEXEL).floor() * TEXEL, Vector2(TEXEL, TEXEL * 2.0)), Color("#e9fbff", 1.0 - u))


## Wake behind something moving through the water: a fan of foam dashes.
func _wake(at: Vector2, toward: float, width: float) -> void:
	for i in 6:
		var age := fposmod((0.0 if reduced_motion else now * 1.5) + i / 6.0, 1.0)
		var spread := width * (0.3 + age)
		for side: float in [-1.0, 1.0]:
			var point := at + Vector2(-toward * 120.0 * age, side * spread * 0.25)
			draw_rect(Rect2((point / TEXEL).floor() * TEXEL, Vector2(TEXEL * 3.0, TEXEL)), Color(CREAM, 0.7 * (1.0 - age)))


## Before the lanes trade currents, a wall of foam rolls in from the right.
func _draw_flip_line() -> void:
	var warning := float(state.get("flip_warning", -1.0))
	if warning < 0.0 or str(state.get("phase", "chase")) != "chase":
		return
	var x := lerpf(1280.0, -40.0, warning)
	for row in int((720.0 - SEA_TOP) / TEXEL):
		var jag := roundf(sin(row * 0.7 + now * 6.0) * 2.0) * TEXEL if not reduced_motion else 0.0
		draw_rect(Rect2(x + jag, SEA_TOP + row * TEXEL, TEXEL * 4.0, TEXEL), Color(CREAM, 0.85))
	label(Vector2(clampf(x, 140.0, 1140.0), SEA_TOP + 20.0), "翻潮！", 26, CREAM)


func _barrel() -> Texture2D:
	return Pixels.bake("tide|barrel", Vector2i(14, 12), func(x: int, y: int) -> Color:
		var u := (x + 0.5 - 7.0) / 7.0
		if absf(u) > 1.0 - 0.15 * absf((y - 5.5) / 6.0):
			return Pixels.CLEAR
		if y == 2 or y == 9:
			return Pixels.metal(Color("#5b6470"), x, y)
		return Pixels.rounded(Pixels.wood(Color("#a8744a"), x, y, 3), Vector2(u, 0.0)))


func _draw_barrels() -> void:
	var throw := float(state.get("throw_age", 99.0))
	if throw >= 0.0 and throw < 0.7:
		# Where the barrel will land: a shadow growing on the target lane.
		var at := Vector2(640, lane_y(int(state.get("throw_lane", 0))))
		Props.oval_shadow(self, at, Vector2(36, 10) * (0.5 + throw / 1.4), 0.4, SPRITE_SHADE)
		draw_arc(at, 26.0 + 10.0 * pulse(4.0), 0.0, TAU, 20, Color(AGAINST, 0.8), TEXEL)
	for barrel: Dictionary in state.get("barrels", []):
		var age := float(barrel.age)
		var at := Vector2(float(barrel.x), lane_y(int(barrel.lane)))
		if age < 0.55:
			var u := age / 0.55
			at = Vector2(boss_x(), lane_y(1.5)).lerp(at, u) + Vector2(0, -160.0 * sin(PI * u))
		elif not bool(barrel.seen):
			continue
		var bob := 0.0 if reduced_motion else sin(now * 4.0 + at.x * 0.01) * 3.0
		if age >= 0.55:
			Props.oval_shadow(self, at + Vector2(0, 14), Vector2(30, 7), 0.3, SPRITE_SHADE)
			_spray(at + Vector2(0, 8), age - 0.55)
		stamp(_barrel(), at + Vector2(-28, -26 + bob))


func _draw_boss() -> void:
	var lane_mid := lane_y(clampf(float(state.get("raft_lane", 1.5)), 0.0, 3.0))
	var y := lerpf(lane_y(1.5), lane_mid, 0.6)
	if str(state.get("phase", "")) == "postcard":
		# Sailing off over the horizon.
		var away := now - float(state.get("phase_at", now))
		y -= 40.0 * away
	var at := Vector2(boss_x(), y + 20.0)
	var bob := 0.0 if reduced_motion else sin(now * 2.2) * 4.0
	Props.oval_shadow(self, at + Vector2(0, 6), Vector2(110, 16), 0.3, SPRITE_SHADE)
	_wake(at + Vector2(-70, 4), 1.0, 60.0)
	var size := Vector2(Anmao.STAGE) * TEXEL
	draw_texture_rect(boss_stage.get_texture(), Rect2(at + Vector2(0, bob) - Anmao.ROOT * TEXEL, size), false)
	if bool(state.get("in_reach", false)):
		draw_arc(at + Vector2(0, -200), 26.0 + 6.0 * pulse(3.0), 0.0, TAU, 20, GOLD, TEXEL)
		label(at + Vector2(0, -200), "拋繩！", 22, GOLD)


func _raft() -> Texture2D:
	return Pixels.bake("tide|raft", Vector2i(30, 8), func(x: int, y: int) -> Color:
		if y < 2 and (x < 2 or x > 27):
			return Pixels.CLEAR
		if y >= 6:
			return Color("#6b4b2f") if x % 7 < 5 else Pixels.CLEAR
		return Pixels.wood(Color("#b58554"), x, y, 5, true))


func _draw_raft() -> void:
	var y := lane_y(float(state.get("raft_lane", 1.0)))
	var bumped := now - float(state.get("bump_at", -99.0))
	var spin := 0.0
	if bumped >= 0.0 and bumped < 1.2 and not reduced_motion:
		spin = sin(bumped * 10.0) * 0.35 * (1.0 - bumped / 1.2)
	var bob := 0.0 if reduced_motion else sin(now * 3.0) * 3.0
	var at := Vector2(RAFT_X, y + 14.0 + bob)
	Props.oval_shadow(self, at + Vector2(0, 10), Vector2(70, 12), 0.3, SPRITE_SHADE)
	_wake(at + Vector2(-60, 8), 1.0, 40.0)
	draw_set_transform(at, spin)
	Props.stamp(self, _raft(), Vector2(-60, -12), TEXEL)
	var mood := "shocked" if bumped >= 0.0 and bumped < 1.2 else "plain"
	var pose := &"right" if float(state.get("rope_at", -99.0)) > now - 0.5 else &"idle"
	var hero := Hero.texture(pose, true, mood)
	Props.stamp(self, hero, Vector2(-4, -12) - Hero.FEET * 2.5, 2.5)
	draw_set_transform(Vector2.ZERO)


## The thrown rope: a looping arc that hooks the anchor or falls short with a splash.
func _draw_rope() -> void:
	var age := now - float(state.get("rope_at", -99.0))
	if age < 0.0 or age > 0.6:
		return
	var from := Vector2(RAFT_X + 30.0, lane_y(float(state.get("raft_lane", 1.0))) - 60.0)
	var hooked := float(state.get("caught_at", -99.0)) >= float(state.get("rope_at", 0.0))
	var to := Vector2(boss_x() - 40.0, from.y + 40.0) if hooked else from + Vector2(220, 60)
	var u := clampf(age / 0.25, 0.0, 1.0)
	var points := PackedVector2Array()
	for i in 13:
		var s := float(i) / 12.0 * u
		points.append(from.lerp(to, s) + Vector2(0, -90.0 * sin(PI * s)))
	draw_polyline(points, Color("#e9d7a6"), TEXEL)
	if not hooked and u >= 1.0:
		dust_puffs(to, age - 0.25, 40.0)


## Act three's fog over the far water; the stolen lamp's beam cuts a lane of
## clear water that sweeps up and down.
func _draw_fog() -> void:
	if not bool(state.get("foggy", false)) or str(state.get("phase", "chase")) != "chase":
		return
	var beam := float(state.get("beam", 0.5))
	var beam_y := lane_y(beam * 4.0 - 0.5)
	for row in int((720.0 - SEA_TOP) / (TEXEL * 2.0)):
		var y := SEA_TOP + row * TEXEL * 2.0
		var clear := 1.0 - clampf(absf(y - beam_y) / 70.0, 0.0, 1.0)
		var drift := 0.0 if reduced_motion else sin(now * 0.8 + row * 0.5) * 30.0
		draw_rect(Rect2(380.0 + drift, y, 900.0, TEXEL * 2.0), Color("#dfe6ee", 0.62 * (1.0 - clear)))
	var lamp := Vector2(boss_x() - 40.0, lane_y(1.5) - 60.0)
	draw_colored_polygon(PackedVector2Array([lamp, Vector2(380, beam_y - 46.0), Vector2(380, beam_y + 46.0)]), Color("#fff3c4", 0.18))


## A rope gauge across the top: the raft on the left, 錨錨 on the right.
func _draw_gap_gauge() -> void:
	var gap := float(state.get("gap", 600.0))
	var rect := Rect2(380, 172, 520, 18)
	panel(rect.grow(4.0), "groove", Color("#3a2433"))
	var fill := 1.0 - clampf(gap / 760.0, 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), WITH if bool(state.get("in_reach", false)) else Color("#e9d7a6"))
	label(Vector2(rect.position.x - 40.0, rect.get_center().y), "木筏", 18, CREAM)
	label(Vector2(rect.end.x + 40.0, rect.get_center().y), "錨錨", 18, CREAM)
	label(Vector2(rect.get_center().x, rect.end.y + 18.0), "還差 %d 公尺" % roundi(gap / 20.0), 18, CREAM)


## Out of time: 錨錨 sails off, a wave flips the raft, and a postcard arrives.
func _draw_postcard() -> void:
	if str(state.get("phase", "")) != "postcard":
		return
	var age := now - float(state.get("phase_at", now))
	if age >= 1.4 and age < 1.8:
		draw_rect(Rect2(0, SEA_TOP, 1280, 720 - SEA_TOP), Color(1, 1, 1, 0.6 * (1.0 - (age - 1.4) / 0.4)))
	if age < 2.4:
		label(Vector2(640, 260), "錨錨開船跑了……", 32, CREAM)
		return
	var drop := pop_in(age - 2.4, 0.3)
	var centre := Vector2(640, 420 + 60.0 * (1.0 - drop))
	draw_set_transform(centre, 0.06)
	draw_rect(Rect2(-190, -180, 380, 300), Color(0.05, 0.02, 0.08, 0.4))
	draw_rect(Rect2(-200, -190, 380, 300), Color("#fff6e2"))
	draw_rect(Rect2(-185, -175, 200, 230), SEA)
	Props.stamp(self, Hero.texture(&"idle", true, "soaked"), Vector2(-85, 40) - Hero.FEET * 4.0, 4.0)
	for drop_i in 10:
		draw_rect(Rect2(Vector2(-170 + drop_i * 18.0, -150 + (drop_i * 37) % 120), Vector2(4, 10)), Color("#a9dcef"))
	draw_set_transform(Vector2.ZERO)
	_card_text(centre, 0.06, Vector2(80, -100), "錨錨寄來的", 22, INK, 1.0, false)
	_card_text(centre, 0.06, Vector2(80, -64), "明信片", 22, INK, 1.0, false)
	_card_text(centre, 0.06, Vector2(80, 0), "「下次再來追！」", 20, Color("#b7443b"), 1.0, false)
