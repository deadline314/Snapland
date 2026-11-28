extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 觀眾席波浪: three tiers of wooden bleachers fill the tent, packed
## with spectators whose legs hide behind each bench's rail. A wave of them rises
## with arms up as it sweeps across; the hero sits in the front row with a tub of
## popcorn. Stand alone and every head turns to stare while the popcorn spills
## over the bench. Every object is baked pixel art (arcade_pixels.gd,
## arcade_hero.gd) or a shared material.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
## Rows from the back: bench top, figure scale and seat spacing.
const BENCH_Y: Array[float] = [392.0, 516.0, 652.0]
const ROW_SCALE: Array[float] = [3.2, 3.8, 4.4]
const SPACING: Array[float] = [84.0, 100.0, 116.0]
const WAVE_WIDTH := 150.0
const LOOKS := 12
const FIGURE := Vector2i(18, 30)
const ORIGIN := Vector2i(9, 30)
const LAMP := Color(0.92, 0.87, 0.95)
const WOOD := Color("#7a5238")
const SHIRTS: Array[Color] = [Color("#c9483d"), Color("#2f8a8c"), Color("#e9b85c"), Color("#7a4f9a"), Color("#4f7a3a"), Color("#e07a9a")]
const HAIRS: Array[Color] = [Color("#3b2a20"), Color("#8a5a34"), Color("#2b2440"), Color("#c9a46a"), Color("#6a3a2a")]
const SKINS: Array[Color] = [Color("#f0c8a0"), Color("#d9a07a"), Color("#a8704a"), Color("#f4d8b8")]

var _has_tent := false
var _figures: Dictionary = {}
var _tub: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 240)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.62, 0.56, 0.7))
	for look in LOOKS:
		for pose: String in ["sit", "up", "stare"]:
			_figures["%d|%s" % [look, pose]] = Pixels.bake_blocks("wave-fan|%d|%s" % [look, pose], FIGURE, ORIGIN, _fan_blocks(look, pose))
	_tub = Pixels.bake_blocks("wave-tub", Vector2i(12, 14), Vector2i(6, 14), [
		[Rect2(-5, -10, 10, 10), Color("#f3ead9")], [Rect2(-5, -10, 2, 10), Color("#c9483d")], [Rect2(-1, -10, 2, 10), Color("#c9483d")], [Rect2(3, -10, 2, 10), Color("#c9483d")],
		[Rect2(-6, -14, 12, 4), Color("#fff0c0")], [Rect2(-4, -15, 3, 2), Color("#fff6d8")], [Rect2(1, -15, 3, 2), Color("#f4e0a0")]])


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	vignette(0.45)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "gap"))
	var since := age(float(state.get("phase_at", 0.0)))
	for row in 3:
		_draw_row(row, phase)
		if row == 2:
			_draw_hero(phase, since)
		_draw_bench(row)
	if phase == "alone":
		_draw_alone(since)


# --- Bleachers ----------------------------------------------------------------------

func _seats(row: int) -> Array[float]:
	var seats: Array[float] = []
	var step := SPACING[row]
	# Every other row sits half a seat over, like real bleachers.
	var x := 640.0 - step * ceilf(640.0 / step) + (step * 0.5 if row == 1 else 0.0)
	while x <= 1280.0 + step:
		seats.append(x)
		x += step
	return seats


## How far the seat at `x` is standing, 0 seated to 1 up.
func _lift(x: float) -> float:
	var hero_x := float(state.get("hero_x", 640.0))
	var direction := float(state.get("direction", 1.0))
	var best := 0.0
	for crest: Dictionary in state.get("crests", []):
		if bool(crest.broken) and (x - hero_x) * direction > 0.0:
			# The wave broke at the hero: nobody past them gets up.
			continue
		var reach := 1.0 - clampf(absf(x - float(crest.x)) / WAVE_WIDTH, 0.0, 1.0)
		best = maxf(best, smoothstep(0.0, 1.0, reach))
	return best


func _draw_row(row: int, phase: String) -> void:
	var scale_by := ROW_SCALE[row]
	var bench := BENCH_Y[row]
	var hero_x := float(state.get("hero_x", 640.0))
	var feint: Dictionary = state.get("feint", {})
	var tint := LAMP.darkened(0.12 * (2 - row))
	for x in _seats(row):
		if row == 2 and absf(x - hero_x) < 1.0:
			continue
		var seat := int(roundf(x / SPACING[row])) + row * 7
		var look := posmod(seat * 7 + row * 5, LOOKS)
		# Nobody sits exactly on the grid.
		x += (Pixels.noise(seat, row, 3) - 0.5) * 12.0
		var lift := 0.0 if phase == "alone" else _lift(x)
		if row == 2 and not feint.is_empty() and absf(x - (hero_x + float(feint.seat) * SPACING[2])) < 1.0:
			var t := clampf((now - float(feint.at)) / (float(feint.until) - float(feint.at)), 0.0, 1.0)
			lift = maxf(lift, sin(t * PI))
			if t > 0.1 and t < 0.9:
				label(Vector2(x, bench - 112.0), "嘿！", 20, CREAM)
		var pose := "up" if lift > 0.5 else "sit"
		var flip := 1.0
		if phase == "alone":
			pose = "stare"
			flip = -1.0 if x > hero_x else 1.0
		var feet := Vector2(x, bench + lerpf(12.0 + Pixels.noise(seat, row, 5) * 2.0, -3.0, lift) * scale_by)
		if not reduced_motion and pose == "sit":
			feet.y += roundf(sin(now * 1.7 + seat) * 1.0)
		draw_set_transform(feet, 0.0, Vector2(flip, 1.0) * scale_by)
		stamp(_figures["%d|%s" % [look, pose]], -Vector2(ORIGIN), 1.0, tint)
		draw_set_transform(Vector2.ZERO)


## A bleacher step: a plank seat with a lit lip whose rail hides the seated
## spectators' legs, and a riser of upright boards down to the row in front.
func _draw_bench(row: int) -> void:
	var height := 12.0 * ROW_SCALE[row]
	var top := BENCH_Y[row]
	var riser_bottom := BENCH_Y[row + 1] if row < 2 else DESIGN.y
	var tone := WOOD.darkened(0.1 * (2 - row))
	panel(Rect2(-8, top + height, DESIGN.x + 16.0, maxf(0.0, riser_bottom - top - height)), "planks_v", tone.darkened(0.35), Pixels.CLEAR, 3.0, LAMP)
	for band in 3:
		draw_rect(Rect2(0, top + height + band * 8.0, DESIGN.x, 8), Color(0.05, 0.02, 0.08, 0.3 - band * 0.09))
	panel(Rect2(-8, top, DESIGN.x + 16.0, height), "planks", tone, Pixels.CLEAR, 2.0 + row * 0.5, LAMP)
	draw_rect(Rect2(0, top, DESIGN.x, 3), Color(1, 0.9, 0.75, 0.3))
	# Iron brackets every few seats.
	var x := 40.0
	while x < DESIGN.x:
		draw_rect(Rect2(x - 4.0, top + 4.0, 8, height - 6.0), Color("#3a3446"))
		draw_rect(Rect2(x - 3.0, top + 5.0, 3, height - 8.0), Color("#5a5466"))
		x += SPACING[row] * 3.0


# --- Hero ---------------------------------------------------------------------------

func _hero_feet(standing: float) -> Vector2:
	return Vector2(float(state.get("hero_x", 640.0)), BENCH_Y[2] + lerpf(13.0, -2.0, standing) * ROW_SCALE[2])


func _draw_hero(phase: String, since: float) -> void:
	var stood := age(float(state.get("stood_at", -99.0)))
	var standing := 0.0
	if phase == "alone":
		standing = 1.0
	elif stood < 0.5:
		standing = 1.0 if reduced_motion else sin(clampf(stood / 0.5, 0.0, 1.0) * PI)
	var mood := "plain"
	if phase == "alone":
		mood = "shocked" if since < 1.0 else "sorry"
	elif standing > 0.3:
		mood = "tongue"
	var feet := _hero_feet(standing)
	var scale_by := ROW_SCALE[2] * 0.82
	draw_set_transform(feet, 0.0, Vector2.ONE * scale_by)
	stamp(Hero.texture(&"up" if standing > 0.3 else &"idle", true, mood), -Hero.FEET, 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if phase != "alone":
		# The popcorn tub on the bench beside the hero.
		stamp(_tub, Vector2(feet.x + 50.0, BENCH_Y[2] - 15.0 * ROW_SCALE[2]), ROW_SCALE[2], LAMP)
	var streak := int(state.get("streak", 0))
	if streak >= 2 and phase != "alone":
		label(Vector2(feet.x, BENCH_Y[2] - 170.0), "人浪 ×%d" % streak, 22, GOLD)


## The hero stands alone: every head turns, the popcorn flies and lands on the bench.
func _draw_alone(since: float) -> void:
	var feet := _hero_feet(1.0)
	var spill := 1.0 if reduced_motion else clampf(since / 0.5, 0.0, 1.0)
	var tub_at := Vector2(feet.x + 60.0 + 30.0 * spill, BENCH_Y[2] - 30.0 + 26.0 * spill * spill)
	draw_set_transform(tub_at, spill * 1.7, Vector2.ONE * ROW_SCALE[2])
	stamp(_tub, Vector2(-6, -14), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	for kernel in 14:
		var heading := Vector2(cos(kernel * 1.7) * 0.8, -1.0 + 0.4 * sin(kernel * 2.3))
		var fly := heading * 120.0 * spill + Vector2(0, 260.0 * spill * spill)
		var at := tub_at + fly
		at.y = minf(at.y, BENCH_Y[2] + 8.0 + (kernel % 3) * 6.0)
		draw_rect(Rect2(at - Vector2(5, 4), Vector2(10, 8)), Color("#c8a060"))
		draw_rect(Rect2(at - Vector2(4, 3), Vector2(7, 6)), Color("#fff4d0"))
	if since > 0.6:
		for dots in 4:
			var at := Vector2(180.0 + dots * 300.0, BENCH_Y[dots % 2] - 120.0)
			label(at, "……", 22, CREAM, 1.0, 0.85)
		label(Vector2(feet.x + 210.0, BENCH_Y[2] - 160.0), "唧唧…", 22, CREAM, 1.0, 0.8)


# --- Spectators ---------------------------------------------------------------------

## A seated spectator in texels around their feet: legs, shirt, arms, head,
## with one of several hair styles, hats, glasses and shirt patterns.
static func _fan_blocks(look: int, pose: String) -> Array:
	var shirt: Color = SHIRTS[look % SHIRTS.size()]
	var hair: Color = HAIRS[(look * 3 + 1) % HAIRS.size()]
	var skin: Color = SKINS[(look * 5 + 2) % SKINS.size()]
	var trouser := Color("#3b3550") if look % 2 == 0 else Color("#4a3f30")
	var ink := Color("#2b2440")
	var blocks: Array = [
		[Rect2(-4, -10, 3, 10), trouser], [Rect2(1, -10, 3, 10), trouser],
		[Rect2(-5, -20, 10, 11), shirt], [Rect2(-5, -12, 10, 2), shirt.darkened(0.2)],
	]
	if look % 4 == 1:
		blocks.append_array([[Rect2(-5, -18, 10, 1), shirt.lightened(0.45)], [Rect2(-5, -15, 10, 1), shirt.lightened(0.45)]])
	elif look % 4 == 3:
		blocks.append([Rect2(-1, -20, 2, 8), Color("#f3ead9")])
	blocks.append_array([[Rect2(-4, -28, 8, 8), skin], [Rect2(-4, -28, 8, 1), skin.lightened(0.15)]])
	match look % 4:
		0:
			blocks.append_array([[Rect2(-5, -30, 10, 3), hair], [Rect2(-5, -27, 2, 3), hair]])
		1:
			blocks.append_array([[Rect2(-5, -30, 10, 3), hair], [Rect2(-2, -33, 4, 3), hair], [Rect2(-5, -27, 1, 5), hair], [Rect2(4, -27, 1, 5), hair]])
		2:
			blocks.append_array([[Rect2(-5, -30, 10, 2), hair], [Rect2(-4, -32, 2, 2), hair], [Rect2(0, -32, 2, 2), hair], [Rect2(3, -31, 2, 1), hair]])
		_:
			blocks.append_array([[Rect2(-5, -30, 10, 3), hair], [Rect2(-6, -28, 2, 7), hair], [Rect2(4, -28, 2, 7), hair]])
	match look % 6:
		2:
			blocks.append_array([[Rect2(-6, -31, 12, 2), Color("#c9483d")], [Rect2(-4, -34, 8, 3), Color("#c9483d")], [Rect2(-4, -32, 8, 1), Color("#f3ead9")]])
		5:
			blocks.append_array([[Rect2(-5, -31, 11, 2), Color("#3b3550")], [Rect2(1, -31, 6, 1), Color("#3b3550")]])
	var specs := look % 5 == 4
	match pose:
		"up":
			blocks.append_array([[Rect2(-8, -29, 3, 10), shirt], [Rect2(5, -29, 3, 10), shirt], [Rect2(-8, -31, 3, 2), skin], [Rect2(5, -31, 3, 2), skin],
				[Rect2(-3, -25, 2, 2), ink], [Rect2(1, -25, 2, 2), ink], [Rect2(-2, -22, 4, 2), Color("#7a1f2f")]])
		"stare":
			# Head turned toward the hero: big round eyes looking the same way, mouth flat.
			blocks.append_array([[Rect2(-7, -19, 3, 8), shirt], [Rect2(4, -19, 3, 8), shirt],
				[Rect2(-2, -26, 3, 3), Color.WHITE], [Rect2(2, -26, 3, 3), Color.WHITE], [Rect2(0, -25, 1, 2), ink], [Rect2(4, -25, 1, 2), ink],
				[Rect2(-2, -27, 3, 1), ink], [Rect2(2, -27, 3, 1), ink], [Rect2(0, -22, 3, 1), ink]])
			specs = false
		_:
			blocks.append_array([[Rect2(-7, -19, 3, 8), shirt], [Rect2(4, -19, 3, 8), shirt], [Rect2(-7, -11, 3, 2), skin], [Rect2(4, -11, 3, 2), skin],
				[Rect2(-3, -25, 2, 2), ink], [Rect2(1, -25, 2, 2), ink], [Rect2(-2, -22, 4, 1), Color("#c9344a")]])
	if specs:
		blocks.append_array([[Rect2(-4, -26, 3, 3), Color("#2b2440")], [Rect2(1, -26, 3, 3), Color("#2b2440")], [Rect2(-3, -25, 1, 1), Color("#9fd0e6")], [Rect2(2, -25, 1, 1), Color("#9fd0e6")]])
	return blocks
