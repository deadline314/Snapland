extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 積木拱橋: in the toy workshop a long rope swings a painted wooden
## block over a brick plinth on the bench. Blocks stack into a railway pier;
## sawn-off ends tumble away, a finished pier gets a wooden arch and a toy
## train puffs across it, and a missed block dominoes the whole stack over onto
## the island traveller (arcade_hero), who is left wearing the top block. Every
## object is baked pixel art in the backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const STAGE_LEFT := 240.0
const STAGE_RIGHT := 1040.0
const BENCH_TOP := 560.0
const PIER_FOOT := 604.0
const ROW := 40.0
const PIVOT := Vector2(640, -300)
const ROPE := 520.0
const HANG := 16.0
const HERO_FEET := Vector2(1130, 694)
const HERO_SCALE := 3.0
const PLINTH := Vector2i(60, 12)
const HOOK := Vector2i(10, 12)
const TRAIN := Vector2i(54, 16)
const PAINTS: Array[Color] = [Color("#c0503f"), Color("#4f8f86"), Color("#e0b04a"), Color("#4f79a8")]
const WOOD := Color("#7a5238")
const PINE := Color("#d2a46a")
const BRICK := Color("#a5573f")
const IRON := Color("#4a4e57")
const STEEL := Color("#c3c8cf")
const ROPE_TONE := Color("#d9c08a")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _plinth: ImageTexture
var _hook: ImageTexture
var _train: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(380, 300)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(120, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	_plinth = Pixels.bake("bridge-plinth", PLINTH, _paint_plinth)
	_hook = Pixels.bake("bridge-hook", HOOK, _paint_hook)
	_train = Pixels.bake("bridge-train", TRAIN, _paint_train)


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(BENCH_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	if not state.has("pier"):
		return
	_draw_plinth()
	_draw_arch()
	_draw_pier()
	_draw_offcuts()
	_draw_hero()
	_draw_toppled()
	_draw_falling()
	_draw_hook()
	_draw_streak()


# --- Placement ----------------------------------------------------------------

func _sx(x: float) -> float:
	return lerpf(STAGE_LEFT, STAGE_RIGHT, x)


func _px(width: float) -> float:
	return width * (STAGE_RIGHT - STAGE_LEFT)


## Bottom of pier row `row` on screen.
func _row_bottom(row: int) -> float:
	return PIER_FOOT - row * ROW


func _hook_point() -> Vector2:
	var x := _sx(float(state.get("hook_x", 0.5)))
	var reach := clampf((x - PIVOT.x) / ROPE, -0.95, 0.95)
	return PIVOT + Vector2(x - PIVOT.x, ROPE * cos(asin(reach)))


## A baked block of `shape`, `paint` and screen width.
func _block(shape: String, paint: int, width_px: float) -> ImageTexture:
	var texels := maxi(2, roundi(width_px / TEXEL))
	var size := Vector2i(texels, int(ROW / TEXEL))
	return Pixels.bake("bridge-%s|%d|%d" % [shape, paint, texels], size, _paint_block.bind(shape, PAINTS[posmod(paint, PAINTS.size())], size))


## Draw a block turned by `angle` and scaled by `stretch` about `origin`; the
## block's bottom middle sits `foot` (in its own turned frame) from the origin.
func _stamp_block(block: Dictionary, origin: Vector2, angle := 0.0, foot := Vector2.ZERO, stretch := Vector2.ONE, tint := DUSK) -> void:
	var width := _px(float(block.width))
	var sprite := _block(str(block.shape), int(block.paint), width)
	var size := (sprite.get_size() - Vector2(2, 2)) * TEXEL
	draw_set_transform(origin, angle, stretch)
	stamp(sprite, foot + Vector2(-size.x * 0.5, -size.y), TEXEL, tint)
	draw_set_transform(Vector2.ZERO)


# --- Pier ---------------------------------------------------------------------

func _draw_plinth() -> void:
	var at := Vector2(_sx(float(state.get("pier_x", 0.5))) - PLINTH.x * TEXEL * 0.5, PIER_FOOT)
	ground_shadow(Vector2(at.x + PLINTH.x * TEXEL * 0.5 + 10.0, PIER_FOOT + PLINTH.y * TEXEL), Vector2(PLINTH.x * 2.4, 14), 0.42)
	stamp(_plinth, at, TEXEL, DUSK)


func _draw_pier() -> void:
	var pier: Array = state.get("pier", [])
	for row in pier.size():
		var block: Dictionary = pier[row]
		var foot := Vector2(_sx(float(block.x)), _row_bottom(row))
		var landed := age(float(block.at))
		# A block settles with a little squash; a dead-on one flashes.
		_stamp_block(block, foot, 0.0, Vector2.ZERO, squash(landed, 0.16, 0.24))
		if row > 0:
			draw_rect(Rect2(foot.x - _px(float(block.width)) * 0.5, foot.y - 2.0, _px(float(block.width)), 4), Color(SPRITE_SHADE, 0.25))
		if bool(block.perfect) and landed < 0.5:
			glint(foot + Vector2(-_px(float(block.width)) * 0.3, -ROW * 0.6), 18.0, 99.0, -landed)
			if landed < 0.3:
				dust_puffs(foot, landed, _px(float(block.width)) * 0.6)


func _draw_arch() -> void:
	var since := age(float(state.get("arch_at", -99.0)))
	var total := float(state.get("arch_seconds", 1.6))
	if since < 0.0 or since > total:
		return
	var pier: Array = state.get("pier", [])
	if pier.is_empty():
		return
	var top := _row_bottom(pier.size()) + 2.0
	var middle := _sx(float(pier.back().x))
	var drop := pop_in(since, 0.25)
	# Two wooden arches spring from the pier top out to its unseen neighbours.
	var deck_y := top - 18.0 - 40.0 * (1.0 - drop)
	var tint := Color(DUSK, drop)
	for side: float in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for step in 17:
			var t := step / 16.0
			points.append(Vector2(middle + side * t * 640.0, _arch_y(deck_y, t)))
		# Posts from the arch up to the deck, then the laminated arch rib itself.
		for post in range(1, 8):
			var t := post / 8.0
			var x := middle + side * t * 640.0
			var foot := _arch_y(deck_y, t)
			if foot - deck_y > 14.0:
				draw_rect(Rect2(x - 7.0, deck_y, 14, foot - deck_y), Color(PINE.darkened(0.6), drop))
				draw_rect(Rect2(x - 5.0, deck_y, 10, foot - deck_y), Color(PINE.darkened(0.05), drop))
				draw_rect(Rect2(x - 5.0, deck_y, 3, foot - deck_y), Color(PINE.lightened(0.25), drop))
		draw_polyline(points, Color(SPRITE_SHADE, 0.35 * drop), 30.0)
		draw_polyline(points, Color(PINE.darkened(0.4), drop), 26.0)
		draw_polyline(points, Color(PINE.darkened(0.1), drop), 20.0)
		draw_polyline(points.duplicate(), Color(PINE.lightened(0.2), drop), 6.0)
	panel(Rect2(0, deck_y - 12.0, DESIGN.x, 20), "planks", PINE.darkened(0.1), Color(0, 0, 0, 0), TEXEL, tint)
	draw_rect(Rect2(0, deck_y - 18.0, DESIGN.x, 4), STEEL.darkened(0.3))
	# The train puffs across once the deck is down.
	var run := clampf((since - 0.2) / (total - 0.3), 0.0, 1.0)
	var train_x := lerpf(-TRAIN.x * TEXEL, DESIGN.x, run)
	stamp(_train, Vector2(train_x, deck_y - 18.0 - TRAIN.y * TEXEL), TEXEL, DUSK)
	if not reduced_motion and run > 0.0 and run < 1.0:
		for puff in 3:
			var rise := fposmod(now * 2.0 + puff / 3.0, 1.0)
			var at := Vector2(train_x + TRAIN.x * TEXEL - 40.0 - rise * 60.0, deck_y - 18.0 - TRAIN.y * TEXEL - 10.0 - rise * 40.0)
			draw_circle(at, 8.0 + rise * 10.0, Color(LABEL, 0.5 * (1.0 - rise)))
	if since < 0.8:
		label(Vector2(middle, deck_y - 110.0), "嘟嘟～", 26, LABEL, pop_in(since - 0.3, 0.2))


## The arch rib's height `t` (0 at the pier, 1 at the next pier) of the way along a span.
func _arch_y(deck_y: float, t: float) -> float:
	return deck_y + 10.0 + 96.0 * (1.0 - sin(t * PI))


func _draw_offcuts() -> void:
	for cut: Dictionary in state.get("offcuts", []):
		var since := age(float(cut.at))
		var side := float(cut.side)
		var foot := Vector2(_sx(float(cut.x)), _row_bottom(int(cut.row)))
		foot += Vector2(side * 140.0 * since, 900.0 * since * since - 60.0 * since)
		var spin := 0.0 if reduced_motion else side * since * 7.0
		_stamp_block(cut, foot + Vector2(0, -ROW * 0.5), spin, Vector2(0, ROW * 0.5))


# --- Hook and falling block ----------------------------------------------------

func _draw_hook() -> void:
	var hook := _hook_point()
	draw_line(PIVOT, hook, Color(SPRITE_SHADE, 0.4), 6.0)
	draw_line(PIVOT, hook, ROPE_TONE.darkened(0.2), 4.0)
	draw_line(PIVOT + Vector2(-1, 0), hook + Vector2(-1, 0), ROPE_TONE.lightened(0.15), 1.0)
	var angle := -asin(clampf((hook.x - PIVOT.x) / ROPE, -0.95, 0.95))
	var hooked: Dictionary = state.get("hooked", {})
	if not hooked.is_empty():
		var width := _px(float(hooked.width))
		var top := HOOK.y * TEXEL - 4.0 + HANG
		for side: float in [-1.0, 1.0]:
			draw_line(hook + Vector2(0, HOOK.y * TEXEL - 8.0).rotated(angle), hook + Vector2(side * width * 0.4, top + 2.0).rotated(angle), ROPE_TONE.darkened(0.25), 3.0)
		_stamp_block(hooked, hook, angle, Vector2(0, top + ROW))
	draw_set_transform(hook, angle, Vector2.ONE)
	stamp(_hook, Vector2(-HOOK.x * TEXEL * 0.5, -4.0), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	if not hooked.is_empty() and str(state.get("stage", "")) != "closing":
		# A faint plumb line from the block to the pier top.
		var pier: Array = state.get("pier", [])
		var bottom := hook + Vector2(0, HOOK.y * TEXEL - 4.0 + HANG + ROW)
		var target := _row_bottom(pier.size()) - 4.0
		var y := bottom.y + 6.0
		while y < target:
			draw_rect(Rect2(hook.x - 1.0, y, 3, 6), Color(LABEL, 0.32))
			y += 14.0


func _draw_falling() -> void:
	var falling: Dictionary = state.get("falling", {})
	if falling.is_empty():
		return
	var pier: Array = state.get("pier", [])
	var since := age(float(falling.at))
	var t := clampf(since / float(state.get("fall_seconds", 0.22)), 0.0, 1.0)
	var start := _hook_point().y + HOOK.y * TEXEL - 4.0 + HANG + ROW
	var land := _row_bottom(pier.size())
	_stamp_block(falling, Vector2(_sx(float(falling.x)), lerpf(start, land, t * t)))


# --- Topple and the traveller -------------------------------------------------

## The stack falls over to the right like dominoes; the top block lands on the traveller.
func _draw_toppled() -> void:
	var toppled: Dictionary = state.get("toppled", {})
	if toppled.is_empty():
		return
	var since := age(float(toppled.at))
	var total := float(state.get("topple_seconds", 1.6))
	if since > total + 0.6:
		return
	var blocks: Array = toppled.blocks
	var fade := 1.0 - smoothstep(total, total + 0.6, since)
	var base_x := _sx(float(state.get("pier_x", 0.5)))
	for row in blocks.size():
		var block: Dictionary = blocks[row]
		if row == blocks.size() - 1 and blocks.size() > 1:
			continue
		# Each slab tips off to the right, the higher ones later and further,
		# and lands flat in a sliding heap between the pier and the traveller.
		var delay := row * 0.05
		var t := clampf((since - delay) / 0.5, 0.0, 1.0) if not reduced_motion else 1.0
		var from := Vector2(_sx(float(block.x)), _row_bottom(row))
		var lie := 0.12 if row % 2 == 0 else -0.08
		var rest := Vector2(base_x + 40.0 + row * 34.0, PIER_FOOT + 20.0 + (row % 3) * 9.0 - row * 3.0)
		var foot := from.lerp(rest, t) + Vector2(0, -40.0 * sin(t * PI))
		var tip := lerpf(0.9, lie, t * t) if t > 0.0 else 0.0
		_stamp_block(block, foot, tip, Vector2.ZERO, Vector2.ONE, Color(DUSK, fade))
		if t >= 1.0 and since - delay < 0.9:
			dust_puffs(rest, since - delay - 0.5, 50.0)


func _draw_hero() -> void:
	var toppled: Dictionary = state.get("toppled", {})
	var since := age(float(toppled.get("at", -99.0))) if not toppled.is_empty() else 99.0
	var bonked := since >= 0.55 and since < 3.6
	var mood := "shocked" if since >= 0.2 and since < 1.4 else ("sorry" if bonked else "plain")
	var pose := &"up" if since >= 0.2 and since < 0.6 else &"idle"
	var origin := HERO_FEET - Vector2(20, 46) * HERO_SCALE
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	var stretch := squash(since - 0.55, 0.3, 0.32)
	draw_set_transform(HERO_FEET, 0.0, stretch)
	stamp(Hero.texture(pose, true, mood), origin - HERO_FEET, HERO_SCALE, DUSK)
	draw_set_transform(Vector2.ZERO)
	if toppled.is_empty():
		return
	var blocks: Array = toppled.blocks
	var top: Dictionary = blocks.back()
	var head := HERO_FEET + Vector2(0, -46 * HERO_SCALE * stretch.y + 6.0)
	# The top block arcs over and lands square on the traveller's head.
	var t := clampf((since - 0.1) / 0.45, 0.0, 1.0) if not reduced_motion else 1.0
	if since > 3.6 + 0.4:
		return
	var from := Vector2(_sx(float(top.x)), _row_bottom(blocks.size() - 1))
	var arc := from.lerp(head, t) + Vector2(0, -160.0 * sin(t * PI))
	var shrink := 0.6
	var spin := 0.0 if t >= 1.0 or reduced_motion else (1.0 - t) * 6.0
	var block := top.duplicate()
	block.width = minf(float(top.width), 0.12)
	_stamp_block(block, arc, spin, Vector2.ZERO, Vector2.ONE * lerpf(1.0, shrink, t))
	if bonked:
		_draw_stars(head + Vector2(0, -ROW * shrink - 6.0), since - 0.55)


func _draw_stars(at: Vector2, since: float) -> void:
	for star in 3:
		var angle := star * TAU / 3.0 + (0.0 if reduced_motion else since * 6.0)
		var spot := at + Vector2(cos(angle) * 40.0, sin(angle) * 10.0)
		draw_rect(Rect2(spot - Vector2(7, 3), Vector2(14, 6)), DARK)
		draw_rect(Rect2(spot - Vector2(3, 7), Vector2(6, 14)), DARK)
		draw_rect(Rect2(spot - Vector2(5, 1), Vector2(10, 2)), GOLD)
		draw_rect(Rect2(spot - Vector2(1, 5), Vector2(2, 10)), GOLD)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(1110, 250), "剛好 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))
	var pier: Array = state.get("pier", [])
	var blocks := int(state.get("pier_blocks", 8))
	# A wooden gauge post beside the plinth counts the pier up to its arch.
	var post_x := _sx(float(state.get("pier_x", 0.5))) + PLINTH.x * TEXEL * 0.5 + 22.0
	var post := Rect2(post_x - 8.0, _row_bottom(blocks) - 26.0, 16, PIER_FOOT - _row_bottom(blocks) + 26.0 + PLINTH.y * TEXEL)
	ground_shadow(Vector2(post_x + 6.0, post.end.y), Vector2(18, 5), 0.4)
	panel(post, "planks_v", WOOD.lightened(0.1), Color(0, 0, 0, 0), TEXEL, DUSK)
	draw_circle(Vector2(post_x, post.position.y + 4.0), 11.0, DARK)
	draw_circle(Vector2(post_x, post.position.y + 4.0), 9.0, GOLD if pier.size() >= blocks else WOOD.lightened(0.25))
	label(Vector2(post_x, post.position.y + 4.0), "橋", 14, DARK, 1.0, 1.0, false)
	for row in blocks:
		var at := Vector2(post_x, _row_bottom(row) - ROW * 0.5)
		var lit := row < pier.size()
		draw_rect(Rect2(at - Vector2(12, 5), Vector2(24, 10)), DARK)
		draw_rect(Rect2(at - Vector2(10, 3), Vector2(20, 6)), GOLD if lit else WOOD.darkened(0.3))
		if lit:
			draw_rect(Rect2(at - Vector2(10, 3), Vector2(6, 2)), GOLD.lightened(0.45))


# --- Texel painters -------------------------------------------------------------

func _paint_block(x: int, y: int, shape: String, paint: Color, size: Vector2i) -> Color:
	var across := (x + 0.5) / size.x * 2.0 - 1.0
	match shape:
		"keystone":
			# A wedge: wide at the bottom, a flat little top.
			var half := lerpf(0.25, 1.0, float(y) / (size.y - 1))
			if absf(across) > half:
				return Pixels.CLEAR
			if y == size.y - 1:
				return PINE.darkened(0.3)
			return Pixels.wood(PINE.lerp(paint, 0.45), x, y, 3, false, 7)
		"cylinder":
			# A painted log lying on its side: round top to bottom, end grain at both ends.
			var round := (y + 0.5 - size.y * 0.5) / (size.y * 0.5)
			if x < 2 or x >= size.x - 2:
				var ring := int(absf(round) * 3.0) % 2 == 0
				return PINE.lightened(0.1) if ring else PINE.darkened(0.15)
			if (x - 2) % 6 == 0:
				return paint.darkened(0.3)
			return Pixels.grainy(Pixels.rounded(paint, Vector2(-0.2, round)), x, y, 0.08)
	# A painted wooden block: grain through the paint, a natural-wood rim, and a star.
	if y == 0:
		return PINE.lightened(0.15)
	if x == 0 or x == size.x - 1 or y == size.y - 1:
		return PINE.darkened(0.22)
	if size.x >= 9:
		var star := Vector2(x + 0.5 - size.x * 0.5, y + 0.5 - size.y * 0.5)
		if absf(star.x) + absf(star.y) < 2.2 or (absf(star.x) < 0.6 and absf(star.y) < 3.2) or (absf(star.y) < 0.6 and absf(star.x) < 3.2):
			return LABEL.darkened(0.08)
	return Pixels.wood(paint.lerp(PINE, 0.18), x, y, 5, false, 3)


func _paint_plinth(x: int, y: int) -> Color:
	# Bricks on a stone cap.
	if y < 2:
		return Pixels.grainy(Color("#b8ab98").lightened(0.1 if y == 0 else 0.0), x, y, 0.1)
	var row := (y - 2) / 3
	var shifted := x + (3 if row % 2 == 1 else 0)
	if (y - 2) % 3 == 2 or shifted % 6 == 0:
		return Color("#5a4038")
	return Pixels.grainy(BRICK.darkened(0.12 * Pixels.noise(shifted / 6, row)), x, y, 0.1)


func _paint_hook(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# A pulley block on top, then a curled iron hook.
	if y < 4:
		return Pixels.rounded(STEEL.darkened(0.2), (at - Vector2(5, 2)) / Vector2(4, 2)) if x >= 1 and x < 9 else Pixels.CLEAR
	if y < 8:
		return IRON.lightened(0.2) if x >= 4 and x < 6 else Pixels.CLEAR
	var ring := (at - Vector2(5, 9.5)).length()
	if ring <= 2.6 and ring >= 1.2 and not (at.x > 5.5 and at.y < 9.5):
		return Pixels.rounded(IRON.lightened(0.15), (at - Vector2(5, 9.5)) / 2.6)
	return Pixels.CLEAR


func _paint_train(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	for wheel: float in [5.0, 13.0, 25.0, 31.0, 43.0, 49.0]:
		var spoke := (at - Vector2(wheel, 13.5)) / 2.4
		if spoke.length() <= 1.0:
			return STEEL if spoke.length() < 0.35 else Pixels.rounded(DARK.lightened(0.15), spoke)
	if x >= 36:
		# The locomotive: boiler, cab and a funnel.
		if y < 4:
			return IRON.lightened(0.2) if x >= 47 and x < 50 else Pixels.CLEAR
		if y < 7 and x < 42:
			return PAINTS[0] if y > 4 else PAINTS[0].lightened(0.3)
		if y < 12:
			if x < 42 and y < 9 and x >= 38 and x < 41:
				return Color("#ffe7a0")
			return Pixels.rounded(PAINTS[0] if x < 42 else PAINTS[3], Vector2(0, (at.y - 9.0) / 3.0))
		return Pixels.CLEAR
	if x % 18 >= 16:
		return IRON if y == 10 else Pixels.CLEAR
	if y >= 5 and y < 12:
		return Pixels.wood(PAINTS[1 + (x / 18) % 2], x, y, 4)
	return Pixels.CLEAR
