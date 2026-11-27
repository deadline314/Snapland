extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 螢火蟲對暗號: dusk at the greenhouse lily pond, a stone lantern on
## a mossy islet and four little lantern cradles around it, one per arrow. Each
## cradle has its own carved shape (▲ up, ● right, ■ down, ◆ left) so the code
## never depends on colour; a firefly settles in the cradle and its shape glows
## softly in and out. Double notes blink twice with a ×2 tag, the moth decoy is
## a grey moth with no shape, and a wrong answer blacks the pond out but for one
## embarrassed firefly. Everything is baked pixel art (arcade_pixels.gd).

const CENTER := Vector2(640, 404)
## Where the stone lantern stands: the middle of the islet in the baked scene.
const LANTERN_FEET := Vector2(640, 498)
const SPOTS: Array[Vector2] = [Vector2(640, 214), Vector2(884, 404), Vector2(640, 590), Vector2(396, 404)]
## The code readout sits top left, clear of the cradles.
const READOUT := Vector2(150, 190)
const KEYS: Array[String] = ["↑", "→", "↓", "←"]
const SKY_TOP := Color("#3a2f5c")
const SKY_LOW := Color("#d9866a")
const WATER := Color("#24384f")
const STONE := Color("#8f9488")
const MOSS := Color("#4f7a3e")
const PAD := Color("#3f6f4a")
const GLOW := Color("#f4ff9a")
const WARM := Color("#ffe7a0")
const PAPER := Color("#f1e2bc")
const WOOD := Color("#6b4a32")

var _scene: ImageTexture
var _lantern: ImageTexture
var _cradles: Array[ImageTexture] = []
var _lit: Array[ImageTexture] = []
var _fly: ImageTexture
var _moth: ImageTexture
var _shy: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 306)


func _ready() -> void:
	_scene = Pixels.bake("code-scene", Vector2i(320, 180), _paint_scene)
	_lantern = Pixels.bake("code-lantern", Vector2i(22, 34), _paint_lantern)
	for dir in 4:
		_cradles.append(Pixels.bake("code-cradle|%d" % dir, Vector2i(22, 24), _paint_cradle.bind(dir, false)))
		_lit.append(Pixels.bake("code-cradle-lit|%d" % dir, Vector2i(22, 24), _paint_cradle.bind(dir, true)))
	_fly = Pixels.bake("code-fly", Vector2i(7, 6), _paint_fly)
	_moth = Pixels.bake("code-moth", Vector2i(13, 9), _paint_moth)
	_shy = Pixels.bake("code-shy", Vector2i(16, 15), _paint_shy)


func _draw_backdrop() -> void:
	stamp(_scene, Vector2.ZERO)
	# A few idle fireflies wander over the far bank.
	for wander in 9:
		var drift := Vector2.ZERO if reduced_motion else Vector2(sin(now * 0.4 + wander * 2.1) * 40.0, cos(now * 0.55 + wander) * 16.0)
		var at := Vector2(120.0 + wander * 128.0, 196.0 + (wander % 3) * 18.0) + drift
		var blink := 0.6 if reduced_motion else 0.35 + 0.35 * sin(now * 1.3 + wander * 1.7)
		draw_rect(Rect2(at.round(), Vector2(4, 4)), Color(GLOW, blink))


func _draw_scene() -> void:
	var phase := str(state.get("phase", "show"))
	var since := age(float(state.get("phase_at", 0.0)))
	ground_shadow(LANTERN_FEET + Vector2(10, 0), Vector2(60, 12), 0.4)
	stamp(_lantern, LANTERN_FEET - Vector2(44 - TEXEL, 136 - TEXEL))
	# The lantern's own window glows warm, steady, never flashing.
	draw_rect(Rect2(LANTERN_FEET + Vector2(-12, -100), Vector2(24, 20)), Color(WARM, 0.45 if phase != "dark" else 0.05))
	for dir in 4:
		_draw_cradle(dir, phase, since)
	_draw_decoy(phase, since)
	_draw_progress(phase)
	if phase == "dark":
		_draw_blackout(since)
	elif phase == "show":
		label(READOUT + Vector2(0, 76), "看暗號…", 24, PAPER, 1.0, 0.9)
	elif phase == "answer":
		label(READOUT + Vector2(0, 76), "換你了！", 28, GLOW, pop_in(since, 0.2))
	vignette(0.55)


## How lit cradle `dir` is right now, 0..1, with soft fades (no hard strobe).
func _glow(dir: int, phase: String, since: float) -> float:
	var code: Array = state.get("code", [])
	var beat := float(state.get("beat", 0.7))
	if phase == "show":
		var into := since - float(state.get("lead_in", 0.6))
		var index := int(floorf(into / beat))
		if into < 0.0 or index >= code.size() or int(code[index].dir) != dir:
			return 0.0
		var t := (into - index * beat) / beat
		if bool(code[index].double):
			# Two soft blinks in one beat.
			return _soft(fmod(t * 2.0, 1.0))
		return _soft(t)
	if phase == "answer" or phase == "pause":
		var pressed := age(float(state.get("press_at", -99.0)))
		if int(state.get("press_dir", -1)) == dir and pressed < 0.35:
			return 1.0 - pressed / 0.35 * 0.6
		if phase == "pause":
			return 0.35 + 0.25 * pulse(1.5, dir * 0.25)
	return 0.0


## Fade in over the first fifth, hold, fade out over the last third.
func _soft(t: float) -> float:
	if reduced_motion:
		return 1.0 if t < 0.8 else 0.0
	return smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.62, 0.92, t))


func _draw_cradle(dir: int, phase: String, since: float) -> void:
	var at: Vector2 = SPOTS[dir]
	var glow := _glow(dir, phase, since)
	ground_shadow(at + Vector2(8, 48), Vector2(44, 10), 0.35)
	var size := Vector2(_cradles[dir].get_size()) * TEXEL
	if glow > 0.0:
		draw_circle(at, 70.0, Color(GLOW, 0.12 * glow))
		draw_circle(at, 46.0, Color(GLOW, 0.16 * glow))
	stamp(_cradles[dir], at - size * 0.5 + Vector2.ONE * TEXEL)
	if glow > 0.0:
		stamp(_lit[dir], at - size * 0.5 + Vector2.ONE * TEXEL, TEXEL, Color(1, 1, 1, glow))
		# The firefly itself settles on top of the cradle.
		var hover := 0.0 if reduced_motion else 4.0 * sin(now * 8.0 + dir)
		stamp(_fly, at + Vector2(-14, -66 + hover), TEXEL, Color(1, 1, 1, maxf(0.4, glow)))
		draw_circle(at + Vector2(0, -56 + hover), 12.0, Color(GLOW, 0.4 * glow))
	if phase == "show":
		_draw_double_tag(dir, since)
	# The arrow key that answers this cradle.
	key_cap(at + Vector2(72, 30), KEYS[dir], glow > 0.6 and phase != "show", 18)


func _draw_double_tag(dir: int, since: float) -> void:
	var code: Array = state.get("code", [])
	var beat := float(state.get("beat", 0.7))
	var into := since - float(state.get("lead_in", 0.6))
	var index := int(floorf(into / beat))
	if into >= 0.0 and index < code.size() and int(code[index].dir) == dir and bool(code[index].double):
		label(SPOTS[dir] + Vector2(56, -40), "×2", 26, GLOW, pop_in(into - index * beat, 0.15))


## The moth: grey, shapeless, flutters onto a cradle without lighting it.
func _draw_decoy(phase: String, since: float) -> void:
	var decoy: Dictionary = state.get("decoy", {})
	if decoy.is_empty() or phase != "show":
		return
	var shown := since - float(decoy.at)
	if shown < -0.6 or shown > 0.9:
		return
	var spot: Vector2 = SPOTS[int(decoy.dir)]
	var flap := 0.0 if reduced_motion else sin(now * 22.0) * 0.35
	var arrive := clampf((shown + 0.6) / 0.6, 0.0, 1.0)
	var at := spot.lerp(spot + Vector2(-160, -120), 1.0 - arrive) + Vector2(30, -50)
	draw_set_transform(at, 0.0, Vector2(1.0, 1.0 - absf(flap)))
	stamp(_moth, Vector2(-26, -18))
	draw_set_transform(Vector2.ZERO)
	if shown > 0.0:
		label(at + Vector2(0, -40), "嗡～", 20, Color("#c8c0b0"), 1.0, 1.0 - clampf(shown / 0.9, 0.0, 1.0))


## One pip per note under the lantern: filled as you answer, two dots on a double.
func _draw_progress(phase: String) -> void:
	var code: Array = state.get("code", [])
	var count := code.size()
	var answered := int(state.get("answered", 0))
	var width := count * 30.0
	var x := READOUT.x - width * 0.5 + 15.0
	var y := READOUT.y + 30.0
	for index in count:
		var done := phase == "pause" or (phase == "answer" and index < answered)
		var half := phase == "answer" and index == answered and bool(state.get("half_pressed", false))
		var rect := Rect2(x + index * 30.0 - 10.0, y - 10.0, 20, 20)
		draw_rect(rect.grow(3.0), INK)
		draw_rect(rect, GLOW if done else (GLOW.darkened(0.4) if half else Color("#3a3f58")))
		if phase != "show" and bool(code[index].double):
			draw_rect(Rect2(rect.position + Vector2(4, 14), Vector2(4, 4)), INK)
			draw_rect(Rect2(rect.position + Vector2(12, 14), Vector2(4, 4)), INK)
	label(Vector2(READOUT.x, y - 30.0), "暗號 %d 碼" % count, 20, PAPER)


## Every light goes out; one firefly is left blinking in the dark, embarrassed.
func _draw_blackout(since: float) -> void:
	var dim := 1.0 if reduced_motion else smoothstep(0.0, 0.25, since)
	draw_rect(Rect2(0, PLAY_TOP, DESIGN.x, DESIGN.y - PLAY_TOP), Color(0.02, 0.02, 0.06, 0.78 * dim))
	var at := CENTER + Vector2(190, -120)
	# Its tail keeps blinking; the rest of it would rather not be seen.
	var on := reduced_motion or fmod(since, 0.8) < 0.55
	var tail := at + Vector2(0, 22)
	draw_circle(tail, 44.0, Color(GLOW, 0.14 if on else 0.05))
	draw_circle(tail, 24.0, Color(GLOW, 0.24 if on else 0.08))
	stamp(_shy, at - Vector2(32, 32), TEXEL, Color(1, 1, 1, 1) if on else Color(0.75, 0.75, 0.7, 1))
	# A sweat drop and a blush: it was the only one who kept its light on.
	draw_rect(Rect2(at + Vector2(36, -34), Vector2(8, 14)), Color("#9fdcff"))
	draw_rect(Rect2(at + Vector2(38, -20), Vector2(4, 4)), Color("#9fdcff"))
	label(at + Vector2(0, -70), "……", 30, PAPER, pop_in(since - 0.3, 0.2))


# --- Texel painters ---------------------------------------------------------

## Dusk through the glasshouse: a violet-to-peach sky behind iron ribs, the far
## bank, the pond with lily pads and the mossy islet in the middle.
func _paint_scene(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y < 50:
		if x % 46 < 2 or y == 30:
			return Color("#2a2f3a") if x % 46 == 0 else Color("#3a4250")
		var mix := float(y) / 50.0 + 0.12 * Pixels.noise(x / 8, y / 4, 2)
		var sky := SKY_TOP.lerp(SKY_LOW, clampf(floorf(mix * 6.0) / 6.0, 0.0, 1.0))
		return Pixels.grainy(sky, x, y, 0.04)
	if y < 58:
		# Far bank: a dark hedge with reeds standing up from it.
		var crown := 50.0 + 4.0 * Pixels.noise(x / 6, 0, 3)
		if at.y < crown:
			return SKY_LOW.darkened(0.1)
		return Color("#263a30").darkened(0.15 * Pixels.noise(x / 2, y, 6))
	# The islet: an oval of moss and stones under the stone lantern.
	var islet := (at - Vector2(160.0, 122.0)) / Vector2(40.0, 13.0)
	if islet.length() < 1.0:
		if islet.y < -0.4:
			return Pixels.grainy(MOSS.lightened(0.08), x, y, 0.15)
		return Pixels.grainy(MOSS if Pixels.noise(x / 3, y / 2, 5) > 0.35 else STONE.darkened(0.25), x, y, 0.15)
	if islet.length() < 1.12:
		return STONE.darkened(0.35)
	for pad: Vector2 in [Vector2(40, 80), Vector2(70, 150), Vector2(262, 76), Vector2(286, 140), Vector2(120, 168), Vector2(214, 166), Vector2(28, 118)]:
		var leaf := (at - pad) / Vector2(11.0, 4.0)
		if leaf.length() < 1.0:
			if leaf.x > 0.2 and absf(leaf.y) < leaf.x * 0.4:
				break
			return Pixels.grainy(PAD.lightened(0.1) if leaf.y < -0.35 else PAD, x, y, 0.12)
	# Water: the sky reflected in bands, darker toward the viewer.
	var depth := float(y - 58) / 122.0
	var water := WATER.lerp(SKY_LOW.darkened(0.45), clampf(0.35 - depth, 0.0, 0.35))
	if (y + x / 11) % 5 == 0 and Pixels.noise(x / 4, y, 7) > 0.5:
		water = water.lightened(0.1)
	return Pixels.grainy(water.darkened(depth * 0.25), x, y, 0.05)


## A stone lantern: base, post, a fire box with a window, and a hat.
func _paint_lantern(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var width := 0.0
	if y < 3:
		width = 2.0 + y * 2.0
	elif y < 6:
		width = 10.5
	elif y < 16:
		width = 6.5
	elif y < 18:
		width = 8.0
	elif y < 28:
		width = 3.0
	else:
		width = 7.5
	if absf(at.x - 11.0) > width:
		return Pixels.CLEAR
	if y >= 8 and y < 14 and absf(at.x - 11.0) < 3.5:
		return Color("#3a2a20")
	var tone := Pixels.rounded(STONE, Vector2((at.x - 11.0) / maxf(width, 1.0), 0.0))
	if Pixels.noise(x, y, 4) > 0.86:
		tone = MOSS
	return Pixels.grainy(tone, x, y, 0.12)


## A cradle on a short post: a paper shade with its carved shape; lit, the shape glows.
func _paint_cradle(x: int, y: int, dir: int, lit: bool) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y >= 17:
		return Pixels.wood(WOOD, x, y, 3) if absf(at.x - 11.0) < 1.6 or (y >= 22 and absf(at.x - 11.0) < 5.0) else Pixels.CLEAR
	var shade := (at - Vector2(11.0, 8.5)) / Vector2(10.5, 8.5)
	if shade.length() > 1.0:
		return Pixels.CLEAR
	var off := at - Vector2(11.0, 8.5)
	var inside := false
	match dir:
		0:
			inside = off.y > -5.0 and off.y < 3.5 and absf(off.x) < (off.y + 5.0) * 0.62
		1:
			inside = off.length() < 4.6
		2:
			inside = absf(off.x) < 3.8 and absf(off.y) < 3.8
		3:
			inside = absf(off.x) + absf(off.y) < 5.2
	if inside:
		return Pixels.rounded(GLOW, off / 5.0) if lit else Color("#4a3a2c")
	if lit:
		return Pixels.CLEAR
	if int(at.y) % 4 == 0:
		return PAPER.darkened(0.2)
	return Pixels.grainy(Pixels.rounded(PAPER.darkened(0.1), shade), x, y, 0.06)


func _paint_fly(x: int, y: int) -> Color:
	if y < 2:
		return Color("#cfd8e6") if x == 1 or x == 5 else Pixels.CLEAR
	if y < 4:
		return Color("#3a2f2c") if x >= 2 and x <= 4 else (Color("#cfd8e6") if x == 1 or x == 5 else Pixels.CLEAR)
	return GLOW if x >= 2 and x <= 4 else Pixels.CLEAR


func _paint_moth(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if absf(at.x - 6.5) < 1.0 and y >= 1:
		return Color("#5a4a40")
	for side: float in [-1.0, 1.0]:
		var wing := (at - Vector2(6.5 + side * 3.6, 4.0)) / Vector2(3.4, 3.8)
		if wing.length() < 1.0:
			return Color("#a89c8c").darkened(0.2 * Pixels.noise(x, y, 3)) if wing.length() > 0.4 else Color("#7a6e62")
	return Pixels.CLEAR


## The last firefly left on: big eyes looking away, blushing, tail still lit.
func _paint_shy(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	for wing: Vector2 in [Vector2(3.5, 4.0), Vector2(12.5, 4.0)]:
		if ((at - wing) / Vector2(3.4, 2.6)).length() < 1.0:
			return Color("#cfd8e6").darkened(0.1 if at.y > wing.y else 0.0)
	var tail := (at - Vector2(8.0, 11.5)) / Vector2(4.0, 3.2)
	if tail.length() < 1.0:
		return Pixels.rounded(GLOW, tail)
	var head := (at - Vector2(8.0, 6.0)) / Vector2(4.6, 4.2)
	if head.length() > 1.0:
		return Pixels.CLEAR
	# Eyes glance off to the side.
	if y >= 5 and y <= 6 and (x == 5 or x == 6 or x == 9 or x == 10):
		return Color("#1b1626") if x == 5 or x == 9 else Color("#fff5dc")
	if y == 8 and (x == 4 or x == 11):
		return Color("#f08c8c")
	return Pixels.grainy(Pixels.rounded(Color("#4a3a32"), head), x, y, 0.08)
