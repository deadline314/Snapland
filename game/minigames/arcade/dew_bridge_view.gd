extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 露珠牽橋: a morning greenhouse. A broad leaf balances on its
## stalk above a clay pot and tips as the player leans it; one glossy dewdrop
## rolls along its midrib. A vine across the glass roof hangs four leaf tips
## that bead up and drip droplets onto the leaf. A caterpillar munches
## wormholes into it; a big drop stretches over a hole like a bridge, a small
## one drops through. Off the leaf tip the drop pours into a flower bud, which
## blooms. Lost drops land on the island traveller (arcade_hero) shuffling
## about below, whose hair goes flat. Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Greenhouse = preload("res://game/minigames/arcade/greenhouse_backdrop.gd")
const LEAF_LEFT := 150.0
const LEAF_RIGHT := 1110.0
const PIVOT := Vector2(630, 404)
## How far the leaf's two ends droop below its middle.
const ARCH := 26.0
const LEAF_TEXELS := Vector2i(240, 34)
const DROPLET_TEXELS := 7
const FLOOR_TOP := 612.0
const VINE_Y := 158.0
const TIP_DROP := 262.0
const HERO_FEET_Y := 660.0
const HERO_SCALE := 3.0
const BUD_ROOT := Vector2(1196, 620)
const BUD_HEAD := Vector2(1170, 500)
const BUD_TEXELS := Vector2i(16, 18)
const BLOOM_TEXELS := Vector2i(26, 22)
const POT := Vector2i(52, 26)
const LEAF := Color("#5f9e4f")
const LEAF_DARK := Color("#3f6f3a")
const RIB := Color("#b9d48a")
const WATER := Color("#a9e2ef")
const IRON := Color("#38534e")
const GLASS := Color("#9cc4bd")
const CLAY := Color("#b8643f")
const SOIL := Color("#4f3f2e")
const WOOD := Color("#8a6640")
const PETAL := Color("#f2a7b8")
const BUD := Color("#7cae5a")
const BUG := Color("#9ccf52")
const DARK := Color("#24302c")
const MORNING := Color(1.0, 0.98, 0.94)

var _leaf: ImageTexture
var _pot: ImageTexture
var _hanging: ImageTexture
var _droplet: ImageTexture
var _bug: ImageTexture
var _bud: ImageTexture
var _bloom: ImageTexture
var _bud_pot: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)


func _ready() -> void:
	_leaf = Pixels.bake("dew-leaf", LEAF_TEXELS, _paint_leaf)
	_pot = Pixels.bake("dew-pot", POT, _paint_pot)
	_hanging = Pixels.bake("dew-hanging", Vector2i(16, 22), _paint_hanging)
	_droplet = _drop_sprite(DROPLET_TEXELS)
	_bug = Pixels.bake("dew-bug", Vector2i(18, 7), _paint_bug)
	_bud = Pixels.bake("dew-bud", BUD_TEXELS, _paint_bud)
	_bloom = Pixels.bake("dew-bloom", BLOOM_TEXELS, _paint_bloom)
	_bud_pot = Pixels.bake("dew-bud-pot", Vector2i(17, 10), _paint_bud_pot)



func _draw_backdrop() -> void:
	Greenhouse.draw(self, now, reduced_motion)
	bench(FLOOR_TOP, WOOD)
	vignette(0.4)


func _draw_scene() -> void:
	if not state.has("drop_x"):
		return
	_draw_vine()
	_draw_pot()
	_draw_bud()
	_draw_gust()
	_draw_leaf()
	_draw_droplets()
	_draw_drop()
	_draw_pour()
	_draw_hero()
	_draw_splash()


# --- Placement ----------------------------------------------------------------

func _tilt() -> float:
	return float(state.get("tilt", 0.0))


## Leaf-local point on the midrib `t` of the way from the stem end (0) to the tip (1).
func _local(t: float) -> Vector2:
	var across := t * 2.0 - 1.0
	return Vector2(lerpf(LEAF_LEFT, LEAF_RIGHT, t) - PIVOT.x, ARCH * across * across * across * across)


func _on_leaf(t: float, lift := 0.0) -> Vector2:
	return PIVOT + (_local(t) + Vector2(0, -lift)).rotated(_tilt())


func _px(width: float) -> float:
	return width * (LEAF_RIGHT - LEAF_LEFT)


func _hero_x() -> float:
	return lerpf(LEAF_LEFT, LEAF_RIGHT, float(state.get("hero_x", 0.4)))


func _hero_head() -> Vector2:
	return Vector2(_hero_x(), HERO_FEET_Y - 44.0 * HERO_SCALE)


# --- The leaf -----------------------------------------------------------------

func _draw_leaf() -> void:
	var size := Vector2(LEAF_TEXELS) * TEXEL
	var tilt := _tilt()
	# The stalk from the pot up to the leaf's balance point.
	var joint := PIVOT + Vector2(0, 30).rotated(tilt)
	for width: float in [18.0, 12.0, 4.0]:
		var tone := LEAF_DARK.darkened(0.3) if width > 16.0 else (LEAF_DARK if width > 6.0 else LEAF.lightened(0.1))
		draw_line(Vector2(PIVOT.x - 8.0, FLOOR_TOP - 40.0), joint, tone, width)
	draw_set_transform(PIVOT + Vector2(14, 30), tilt)
	stamp(_leaf, Vector2(LEAF_LEFT - PIVOT.x, -size.y * 0.5), TEXEL, Color(Props.SHADOW, 0.28))
	draw_set_transform(PIVOT, tilt)
	stamp(_leaf, Vector2(LEAF_LEFT - PIVOT.x, -size.y * 0.5), TEXEL, MORNING)
	var holes: Array = state.get("holes", [])
	var munching := -1
	for index in holes.size():
		_draw_hole(holes[index])
		if munching < 0 or float(holes[index].chewed_at) > float(holes[munching].chewed_at):
			munching = index
	if munching >= 0:
		# The caterpillar munches at the rim of the newest hole.
		var hole: Dictionary = holes[munching]
		var chew := 0.0 if reduced_motion else roundf(sin(now * 9.0)) * 2.0
		stamp(_bug, _local(float(hole.x)) + Vector2(_px(float(hole.width)) * 0.5 + 2.0, -18.0 + chew), TEXEL * 0.75, MORNING)
	draw_set_transform(Vector2.ZERO)


## A chewed wormhole: the floor shows through a ragged gap with a brown bitten rim.
func _draw_hole(hole: Dictionary) -> void:
	var middle := _local(float(hole.x))
	var half := _px(float(hole.width)) * 0.5
	var fresh := age(float(hole.chewed_at))
	var grow := pop_in(fresh, 0.5) if fresh >= 0.0 and fresh < 1.0 else 1.0
	half *= grow
	var rows := 5
	for row in rows:
		var y := -10.0 + row * 4.0
		var wobble := 1.0 - absf(row - 2.0) / 3.2
		var bite := 3.0 * Pixels.noise(int(hole.x * 100.0), row)
		var w := maxf(4.0, (half * wobble - bite) * 2.0)
		var at := Vector2(middle.x - w * 0.5, middle.y + y).round()
		draw_rect(Rect2(at - Vector2(4, 0), Vector2(w + 8.0, 4)), Color("#8a6a3a"))
		draw_rect(Rect2(at, Vector2(w, 4)), Color("#3a4a3a"))
		draw_rect(Rect2(at, Vector2(w, 2)), Color("#2a3630"))


# --- Drops ----------------------------------------------------------------------

## A round glossy drop `texels` across; cached per size.
func _drop_sprite(texels: int) -> ImageTexture:
	return Pixels.bake("dew-drop|%d" % texels, Vector2i(texels, texels), _paint_drop.bind(texels))


func _draw_drop() -> void:
	var x := float(state.get("drop_x", -1.0))
	if x < 0.0 or x > 1.0:
		return
	var radius := _px(float(state.get("drop_radius", 0.02)))
	var texels := maxi(5, roundi(radius * 2.0 / TEXEL))
	var sprite := _drop_sprite(texels)
	var speed := float(state.get("drop_v", 0.0))
	# Rolling stretches the drop along the leaf; over a hole it sags into a bridge.
	var stretch := Vector2.ONE if reduced_motion else Vector2(1.0 + minf(0.25, absf(speed) * 0.6), 1.0 - minf(0.18, absf(speed) * 0.4))
	var sag := 0.0
	for hole: Dictionary in state.get("holes", []):
		if absf(x - float(hole.x)) < float(hole.width) * 0.5:
			sag = 6.0
			stretch.x *= 1.12
	var centre := _on_leaf(x, radius * stretch.y - 10.0 - sag)
	var tilt := _tilt()
	draw_set_transform(centre + Vector2(6, 10).rotated(tilt), tilt, stretch)
	draw_circle(Vector2.ZERO, radius * 0.9, Color(Props.SHADOW, 0.18))
	draw_set_transform(centre, tilt, stretch)
	var half := Vector2(texels, texels) * TEXEL * 0.5
	stamp(sprite, -half, TEXEL, Color(1, 1, 1, 0.92))
	draw_set_transform(Vector2.ZERO)
	glint(centre + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.5, 2.6)
	var sips := int(state.get("sips", 0))
	if sips > 0:
		label(centre + Vector2(0, -radius - 22.0), "×%d" % sips, 18, CREAM)


func _draw_droplets() -> void:
	var fall := float(state.get("drip_fall", 0.45))
	var size := Vector2(DROPLET_TEXELS, DROPLET_TEXELS) * TEXEL
	for droplet: Dictionary in state.get("droplets", []):
		var since := age(float(droplet.at))
		var t := clampf(since / fall, 0.0, 1.0)
		var land := _on_leaf(float(droplet.x), size.y * 0.5 - 8.0)
		var from := Vector2(land.x, TIP_DROP)
		var at := from.lerp(land, t * t)
		if t >= 1.0:
			at += Vector2(0, 0.0 if reduced_motion else 2.0 * sin(now * 3.0 + float(droplet.x) * 9.0))
		stamp(_droplet, at - size * 0.5, TEXEL, Color(1, 1, 1, 0.9))
		if t >= 1.0 and since < fall + 0.25:
			dust_puffs(land + Vector2(0, 8), since - fall, 22.0)


func _draw_vine() -> void:
	# A vine along the roof glass with four leaf tips hanging over the drip spots.
	for segment in 33:
		var x := segment * 40.0
		var y := VINE_Y + 6.0 * sin(segment * 0.9)
		draw_line(Vector2(x, y), Vector2(x + 40.0, VINE_Y + 6.0 * sin((segment + 1) * 0.9)), LEAF_DARK.darkened(0.3), 7.0)
		draw_line(Vector2(x, y - 2.0), Vector2(x + 40.0, VINE_Y - 2.0 + 6.0 * sin((segment + 1) * 0.9)), LEAF_DARK, 3.0)
	for tip: float in state.get("drip_tips", []):
		var x := lerpf(LEAF_LEFT, LEAF_RIGHT, tip)
		var sway := 0.0 if reduced_motion else roundf(3.0 * sin(now * 1.3 + tip * 7.0))
		stamp(_hanging, Vector2(x - 32.0 + sway, VINE_Y - 4.0), TEXEL, MORNING)
		# A bead of water swells at the very tip.
		var bead := 3.0 + 3.0 * pulse(0.7, tip)
		draw_circle(Vector2(x + sway, TIP_DROP - 6.0), bead + 1.0, Color("#5a8a96"))
		draw_circle(Vector2(x + sway, TIP_DROP - 6.0), bead, WATER)


func _draw_pot() -> void:
	var at := Vector2(PIVOT.x - POT.x * TEXEL * 0.5 - 8.0, FLOOR_TOP - POT.y * TEXEL + 22.0)
	ground_shadow(Vector2(PIVOT.x, FLOOR_TOP + 22.0), Vector2(POT.x * 2.4, 12), 0.4)
	stamp(_pot, at, TEXEL, MORNING)


# --- The bud and the pour -------------------------------------------------------

func _draw_bud() -> void:
	# The bud grows from its own little clay pot on the bench.
	var pot := Vector2(BUD_ROOT.x - 34.0, BUD_ROOT.y - 34.0)
	ground_shadow(BUD_ROOT + Vector2(8, 4), Vector2(54, 9), 0.42)
	draw_line(BUD_ROOT, BUD_HEAD + Vector2(0, 30), LEAF_DARK.darkened(0.25), 9.0)
	draw_line(BUD_ROOT, BUD_HEAD + Vector2(0, 30), LEAF_DARK, 5.0)
	draw_line(BUD_ROOT + Vector2(-2, 0), BUD_HEAD + Vector2(-2, 30), LEAF.lightened(0.1), 1.0)
	for side: float in [-1.0, 1.0]:
		var leaf := BUD_ROOT + Vector2(side * 4.0 - 6.0, -40.0)
		draw_line(leaf, leaf + Vector2(side * 26.0, -16.0), LEAF_DARK, 7.0)
		draw_line(leaf, leaf + Vector2(side * 24.0, -15.0), LEAF, 3.0)
	stamp(_bud_pot, pot, TEXEL, MORNING)
	var pour: Dictionary = state.get("pour", {})
	var since := age(float(pour.get("at", -99.0))) if not pour.is_empty() else 99.0
	var total := float(state.get("pour_seconds", 1.1))
	var open := 0.0
	if since >= 0.25 and since < total + 1.6:
		open = pop_in(since - 0.25, 0.3) * (1.0 - smoothstep(total + 1.0, total + 1.6, since))
	# A shut bud; poured into, it bursts into a pink bloom sized by the drop.
	var bloom := 1.0 + 0.4 * clampf((float(pour.get("size", 1.0)) - 1.0) / 2.0, 0.0, 1.0)
	if open > 0.05:
		var texel := TEXEL * open * bloom
		var size := Vector2(BLOOM_TEXELS) * texel
		stamp(_bloom, BUD_HEAD - Vector2(size.x * 0.5, size.y * 0.62), texel, MORNING)
		glint(BUD_HEAD, 30.0, 1.8)
	else:
		var size := Vector2(BUD_TEXELS) * TEXEL
		var nod := 0.0 if reduced_motion else roundf(2.0 * sin(now * 1.1))
		stamp(_bud, BUD_HEAD - Vector2(size.x * 0.5 + nod, size.y * 0.5), TEXEL, MORNING)


func _draw_pour() -> void:
	var pour: Dictionary = state.get("pour", {})
	if pour.is_empty():
		return
	var since := age(float(pour.at))
	if since < 0.0 or since > 0.3:
		return
	var t := since / 0.3
	var from := _on_leaf(1.0, 20.0)
	var at := from.lerp(BUD_HEAD, t) + Vector2(0, -50.0 * sin(t * PI))
	var radius := _px(0.02 * float(pour.size))
	var texels := maxi(5, roundi(radius * 2.0 / TEXEL))
	stamp(_drop_sprite(texels), at - Vector2(texels, texels) * TEXEL * 0.5, TEXEL, Color(1, 1, 1, 0.92))


# --- The traveller and the splash -------------------------------------------------

func _draw_hero() -> void:
	var splash: Dictionary = state.get("splash", {})
	var since := age(float(splash.get("at", -99.0))) if not splash.is_empty() else 99.0
	var soaked := since >= 0.35 and since < float(state.get("splash_seconds", 1.6)) + 1.2
	var x := float(state.get("drop_x", -1.0))
	# The traveller looks worried when the drop is racing toward an edge.
	var worried := x >= 0.0 and (x < 0.12 or absf(float(state.get("drop_v", 0.0))) > 0.5)
	var mood := "soaked" if soaked else ("shocked" if (since >= 0.0 and since < 0.35) or worried else "plain")
	var pose := &"up" if since >= 0.0 and since < 0.35 else &"idle"
	var feet := Vector2(_hero_x(), HERO_FEET_Y)
	var origin := feet - Vector2(20, 46) * HERO_SCALE
	ground_shadow(feet + Vector2(6, 2), Vector2(56, 13), 0.42)
	var stretch := squash(since - 0.35, 0.3, 0.32)
	draw_set_transform(feet, 0.0, stretch)
	stamp(Hero.texture(pose, true, mood), origin - feet, HERO_SCALE, MORNING)
	draw_set_transform(Vector2.ZERO)
	if soaked:
		# A puddle spreads at the traveller's feet and the flat hair shines wet.
		var spread := clampf((since - 0.35) / 0.4, 0.0, 1.0) if not reduced_motion else 1.0
		draw_set_transform(feet + Vector2(0, 4), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 70.0 * spread, Color(WATER, 0.35))
		draw_circle(Vector2(-12, -8), 40.0 * spread, Color(1, 1, 1, 0.25))
		draw_set_transform(Vector2.ZERO)
		var crown := _hero_head() + Vector2(-20, 16)
		for gloss in 3:
			draw_rect(Rect2(crown + Vector2(gloss * 14.0, gloss % 2 * 4.0), Vector2(9, 3)), Color(WATER, 0.85))
	if soaked and not reduced_motion:
		# Drips run off the flattened fringe.
		for drip in 4:
			var run := fposmod(now * 1.6 + drip * 0.27, 1.0)
			var spot := _hero_head() + Vector2(-26.0 + drip * 17.0, 4.0 + run * 46.0)
			draw_rect(Rect2(spot.round(), Vector2(4, 7)), Color(WATER, 1.0 - run))


func _draw_splash() -> void:
	var splash: Dictionary = state.get("splash", {})
	if splash.is_empty():
		return
	var since := age(float(splash.at))
	if since < 0.0 or since > 0.9:
		return
	var head := _hero_head()
	var radius := _px(0.02 * float(splash.size))
	if since < 0.35:
		# The drop falls off the leaf and lands right on the traveller's head.
		var t := since / 0.35
		var from := _on_leaf(float(splash.x), 10.0)
		var at := from.lerp(head, t * t) + Vector2(0, -30.0 * sin(t * PI))
		var texels := maxi(5, roundi(radius * 2.0 / TEXEL))
		stamp(_drop_sprite(texels), at - Vector2(texels, texels) * TEXEL * 0.5, TEXEL, Color(1, 1, 1, 0.92))
		return
	# Splash: a ring of pixel droplets bursts off the head and falls.
	var burst := since - 0.35
	for spray in 10:
		var angle := -PI + spray * PI / 9.0
		var spot := head + Vector2.from_angle(angle) * (30.0 + 160.0 * burst) + Vector2(0, 260.0 * burst * burst)
		var dot := 8.0 if spray % 2 == 0 else 5.0
		draw_rect(Rect2(spot.round() - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), Color(WATER, 1.0 - burst / 0.55))


func _draw_gust() -> void:
	if not bool(state.get("gusting", false)) or reduced_motion:
		return
	for streak in 7:
		var run := fposmod(now * 1.3 + streak * 0.37, 1.0)
		var x := lerpf(1240.0, 40.0, run)
		var y := 260.0 + streak * 46.0
		draw_rect(Rect2(x, y, 70, 3), Color(CREAM, 0.35 * sin(run * PI)))
	label(Vector2(1080, 220), "穿堂風 ←", 20, CREAM)


# --- Texel painters ---------------------------------------------------------------

## The broad leaf seen from just above its edge: pointed tip on the right, a
## rounded base on the left, a pale midrib, paired veins and a glossy top.
func _paint_leaf(x: int, y: int) -> Color:
	var t := (x + 0.5) / LEAF_TEXELS.x
	var across := t * 2.0 - 1.0
	var mid := LEAF_TEXELS.y * 0.5 + ARCH / TEXEL * across * across * across * across
	var half := 7.5 * pow(sin(PI * clampf(t * 0.94 + 0.03, 0.0, 1.0)), 0.6) * (1.0 - 0.55 * maxf(0.0, t - 0.7) / 0.3)
	var off := (y + 0.5 - mid) / maxf(half, 0.5)
	if absf(off) > 1.0:
		return Pixels.CLEAR
	if absf(y + 0.5 - mid) < 0.8:
		return RIB
	# Veins run out from the midrib toward the tip.
	var vein := posmod(int(x - absf(y - mid) * 1.6), 16)
	if vein == 0 and absf(off) < 0.92:
		return RIB.darkened(0.15)
	var tone := LEAF if off < 0.0 else LEAF.darkened(0.12)
	if absf(off) > 0.82:
		tone = tone.lerp(Color("#c2b15a"), 0.35)
	if off < -0.4 and Pixels.noise(x / 5, y, 4) > 0.7:
		tone = tone.lightened(0.12)
	return Pixels.lit(tone, -off * 0.6, x, y)


func _paint_pot(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# A thick rolled rim with soil showing on top, then the tapering body.
	if y < 5:
		if y == 0 and at.x > 4.0 and at.x < POT.x - 4.0:
			return Pixels.grainy(SOIL, x, y, 0.2)
		return Pixels.grainy(CLAY.lightened(0.16) if y < 2 else CLAY.darkened(0.12 if y == 4 else 0.0), x, y, 0.08)
	if y == 5:
		return CLAY.darkened(0.35)
	var inset := (y - 5) * 0.2
	if at.x < 2.0 + inset or at.x > POT.x - 2.0 - inset:
		return Pixels.CLEAR
	var round := (at.x - POT.x * 0.5) / (POT.x * 0.5 - inset)
	var tone := Pixels.lit(CLAY, -round * 0.9, x, y)
	# Two thrown rings, a damp tide mark low down and a patch of moss.
	if y == 11 or y == 17:
		tone = tone.darkened(0.14)
	if y > 20:
		tone = tone.darkened(0.12)
	if round < -0.35 and y > 14 and Pixels.noise(x / 2, y / 2, 9) > 0.55:
		tone = tone.lerp(Color("#6f9a4a"), 0.6)
	return Pixels.grainy(tone, x, y, 0.07)


func _paint_hanging(x: int, y: int) -> Color:
	# A leaf hanging tip-down from the vine.
	var t := (y + 0.5) / 22.0
	var half := 7.0 * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.7) * (1.0 - 0.6 * maxf(0.0, t - 0.6) / 0.4)
	var off := (x + 0.5 - 8.0) / maxf(half, 0.5)
	if absf(off) > 1.0:
		return Pixels.CLEAR
	if absf(x + 0.5 - 8.0) < 0.6:
		return RIB.darkened(0.1)
	return Pixels.lit(LEAF_DARK.lightened(0.1), -off * 0.5, x, y)


func _paint_drop(x: int, y: int, texels: int) -> Color:
	var r := texels * 0.5
	var at := Vector2(x + 0.5 - r, y + 0.5 - r) / r
	if at.length() > 1.0:
		return Pixels.CLEAR
	# Clear water: the leaf shows through as a cool green, a bright highlight up
	# left and a lit crescent along the lower rim where light focuses.
	if (at - Vector2(-0.38, -0.4)).length() < 0.22:
		return Color("#ffffff")
	if at.y > 0.55 and at.length() > 0.72:
		return Color("#e8fbff")
	return Pixels.lit(WATER.lerp(LEAF, 0.18), -at.y * 0.7 - at.x * 0.3, x, y)


func _paint_bug(x: int, y: int) -> Color:
	# A plump green caterpillar: five body segments and a round head with an eye.
	var at := Vector2(x + 0.5, y + 0.5)
	if (at - Vector2(15.5, 3.5)).length() < 2.6:
		return DARK if (at - Vector2(16.3, 2.8)).length() < 0.8 else Pixels.rounded(BUG.lightened(0.1), (at - Vector2(15.5, 3.5)) / 2.6)
	for segment in 5:
		var centre := Vector2(2.5 + segment * 2.6, 4.0 - (1.0 if segment % 2 == 0 else 0.0))
		if (at - centre).length() < 2.2:
			return Pixels.rounded(BUG if segment % 2 == 0 else BUG.darkened(0.12), (at - centre) / 2.2)
	return Pixels.CLEAR


func _paint_bud(x: int, y: int) -> Color:
	# A closed bud: green sepals cupping a pink tip.
	var at := Vector2(x + 0.5 - 8.0, y + 0.5)
	var half := 6.5 * sin(PI * clampf(at.y / 18.0, 0.0, 1.0)) * (1.0 - 0.4 * maxf(0.0, 0.5 - at.y / 18.0))
	if absf(at.x) > half:
		return Pixels.CLEAR
	var off := at.x / maxf(half, 0.5)
	if at.y < 7.0:
		return Pixels.lit(PETAL, -off * 0.6, x, y)
	if absf(off) < 0.18 and at.y < 14.0:
		return BUD.darkened(0.25)
	return Pixels.lit(BUD, -off * 0.6, x, y)


func _paint_bloom(x: int, y: int) -> Color:
	# An open flower seen from the side: a fan of six rounded petals around a gold heart.
	var at := Vector2(x + 0.5 - 13.0, y + 0.5 - 14.0)
	if at.length() < 3.2:
		return Pixels.rounded(Color("#ffd166"), at / 3.2)
	for petal in 6:
		var angle := -PI + (petal + 0.5) * PI / 6.0
		var axis := Vector2.from_angle(angle)
		var along := at.dot(axis)
		var across := at.dot(axis.orthogonal())
		if along > 1.5 and along < 12.5 and absf(across) < 3.6 * sin(PI * (along - 1.5) / 11.0) + 0.6:
			var tone := PETAL if petal % 2 == 0 else PETAL.lightened(0.12)
			return Pixels.lit(tone, (1.0 - along / 12.5) * 0.4 - absf(across) * 0.08, x, y)
	if at.y > 2.0 and absf(at.x) < 6.0 - (at.y - 2.0) * 0.8:
		return Pixels.lit(BUD, -at.x / 6.0, x, y)
	return Pixels.CLEAR


func _paint_bud_pot(x: int, y: int) -> Color:
	# A small clay pot with a rolled rim and dark soil around the stalk.
	var middle := 8.5
	if y < 2:
		if y == 0 and absf(x + 0.5 - middle) < 6.0:
			return Pixels.grainy(SOIL, x, y, 0.2)
		return CLAY.lightened(0.15) if y == 0 else CLAY.darkened(0.1)
	var half := 8.0 - (y - 2) * 0.45
	if absf(x + 0.5 - middle) > half:
		return Pixels.CLEAR
	return Pixels.grainy(Pixels.lit(CLAY, -(x + 0.5 - middle) / half * 0.8, x, y), x, y, 0.07)
