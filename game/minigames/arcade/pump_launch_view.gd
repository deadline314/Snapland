extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 氣壓彈射: the sky park backdrop (sky_backdrop) behind a wooden
## launch deck on the left, where the hero works a red pump hosed to a brass
## launcher. A big brass gauge shows the needle climbing, its green arc exactly
## the stretch of air over the landing pad floating across the gap (a planked
## pad with a painted bullseye on a cloud). Bundles of cloud tied with pink
## ribbon arc across; a miss drops into the clouds with a puff. Pumping past the
## red bursts the pump in a cloud of smoke and the hero floats up wearing a huge
## frizzed afro. Sprites are baked in arcade_pixels (outline and lit edges).

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
const Game = preload("res://game/minigames/arcade/pump_launch_driver.gd")
const DECK_TOP := 560.0
const HERO_AT := Vector2(176, 560)
const PUMP_AT := Vector2(232, 560)
const LAUNCHER_AT := Vector2(352, 528)
const LAUNCH_ANGLE := -0.62
const MUZZLE := Vector2(440, 466)
const GAUGE_AT := Vector2(318, 318)
const GAUGE_RADIUS := 84.0
const GAUGE_FROM := deg_to_rad(150.0)
const GAUGE_SWEEP := deg_to_rad(240.0)
## The pad's centre runs from NEAR_X (pressure NEAR) to FAR_X (pressure FAR).
const NEAR_X := 560.0
const FAR_X := 1140.0
const PAD_Y := 470.0
const HERO_SCALE := 3.0
const WOOD := Color("#a8774a")
const BRASS := Color("#d6a444")
const PUMP_RED := Color("#d2554a")
const RIBBON := Color("#f08cb0")
const AFRO := Color("#2f3660")
const GREEN := Color("#6fd08a")
const RED_ZONE := Color("#e0675e")

var _deck: ImageTexture
var _pump: ImageTexture
var _launcher: ImageTexture
var _bundle: ImageTexture
var _puff: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(760, 236)


func _ready() -> void:
	_deck = Pixels.bake("pump-deck", Vector2i(116, 40), _paint_deck)
	_pump = Pixels.bake("pump-body", Vector2i(12, 24), _paint_pump)
	_launcher = Pixels.bake("pump-launcher", Vector2i(34, 14), _paint_launcher)
	_bundle = Pixels.bake("pump-bundle", Vector2i(16, 13), _paint_bundle)
	_puff = SkyBackdrop.cloud_puff(Vector2i(40, 16), 4)


func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "aim"))
	var since := age(float(state.get("phase_at", 0.0)))
	var needle := float(state.get("needle", 0.0))
	var target := float(state.get("target", 0.5))
	var zone := float(state.get("zone", 0.08))
	var shot: Dictionary = state.get("shot", {})
	# The pad holds still while a bundle is on its way to it.
	var pad_target := float(shot.get("target", target)) if phase in ["fly", "land"] and not shot.is_empty() else target
	var pad_zone := float(shot.get("zone", zone)) if phase in ["fly", "land"] and not shot.is_empty() else zone
	_draw_pad(pad_target, pad_zone)
	_draw_deck()
	_draw_launcher(phase, since)
	var bursting := phase == "burst"
	_draw_pump(bool(state.get("pumping", false)), float(state.get("pressure", 0.0)), bursting, since)
	if bursting:
		_draw_burst_hero(since)
	else:
		_draw_hero(bool(state.get("pumping", false)), float(state.get("pressure", 0.0)))
	_draw_gauge(needle, target, zone, bursting, since)
	if phase in ["fly", "land"] and not shot.is_empty():
		_draw_bundle_flight(shot, phase, since)
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(180, 200), "連中 ×%d" % streak, 24, GOLD)


func _pad_x(pressure: float) -> float:
	return lerpf(NEAR_X, FAR_X, (pressure - Game.NEAR) / (Game.FAR - Game.NEAR))


func _pad_bob() -> float:
	return 0.0 if reduced_motion else 5.0 * sin(now * 1.7)


## The landing pad: planks on a cloud, a bullseye in the middle, a flag at one end.
func _draw_pad(target: float, zone: float) -> void:
	var centre := _pad_x(target)
	var half := (_pad_x(target + zone) - centre)
	var top := PAD_Y + _pad_bob()
	ground_shadow(Vector2(centre, 640.0), Vector2(half + 30.0, 10.0), 0.2)
	var puff_w := (half * 2.0 + 70.0) / TEXEL
	stamp(_puff, Vector2(centre - puff_w * TEXEL * 0.5, top - 14.0), TEXEL * puff_w / 40.0, Color.WHITE)
	var texels := maxi(8, int(round(half * 2.0 / TEXEL / 2.0)) * 2)
	var pad := Pixels.bake("pump-pad|%d" % texels, Vector2i(texels, 5), _paint_pad.bind(texels))
	stamp(pad, Vector2(centre - (texels + 2) * TEXEL * 0.5, top - 4.0))
	# The bullseye painted on the planks: the middle third of the green pays most.
	var bull := half * 0.3
	draw_set_transform(Vector2(centre, top + 2.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, half * 0.78, Color(CREAM, 0.85))
	draw_circle(Vector2.ZERO, half * 0.58, Color(RED_ZONE, 0.9))
	draw_circle(Vector2.ZERO, bull, Color(CREAM, 0.95))
	draw_circle(Vector2.ZERO, bull * 0.5, Color(RED_ZONE, 0.95))
	draw_set_transform(Vector2.ZERO)
	# A little pennant at the far end, flapping.
	var pole := Vector2(centre + half - 6.0, top)
	draw_rect(Rect2(pole + Vector2(-3, -66), Vector2(6, 66)), INK)
	draw_rect(Rect2(pole + Vector2(-1, -64), Vector2(3, 62)), Color("#e9dcc0"))
	var flap := 0.0 if reduced_motion else 5.0 * sin(now * 5.0)
	var flag := PackedVector2Array([pole + Vector2(2, -64), pole + Vector2(40, -54 + flap), pole + Vector2(2, -42)])
	draw_colored_polygon(flag, Color("#7ac0b8"))
	draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), INK, 3.0)


func _draw_deck() -> void:
	stamp(_deck, Vector2(-8, DECK_TOP - 8.0))
	# Railing posts and a sagging bunting along the back.
	for post in 4:
		var x := 24.0 + post * 120.0
		draw_rect(Rect2(x - 5, DECK_TOP - 84, 10, 80), INK)
		draw_rect(Rect2(x - 3, DECK_TOP - 82, 6, 78), WOOD.lightened(0.1))
	draw_rect(Rect2(14, DECK_TOP - 90, 400, 9), INK)
	draw_rect(Rect2(16, DECK_TOP - 88, 396, 5), WOOD.lightened(0.2))
	var sway := 0.0 if reduced_motion else 3.0 * sin(now * 1.3)
	for flag in 9:
		var at := Vector2(30.0 + flag * 44.0, DECK_TOP - 80.0 + 10.0 * sin(flag * PI / 4.0 * 0.5 + 0.3) + sway * (flag % 2))
		var tri := PackedVector2Array([at, at + Vector2(22, 0), at + Vector2(11, 18)])
		draw_colored_polygon(tri, SkyBackdrop.GONDOLAS[flag % 4])
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(INK, 0.8), 2.0)


func _draw_launcher(phase: String, since: float) -> void:
	ground_shadow(LAUNCHER_AT + Vector2(0, 32), Vector2(64, 10), 0.3)
	# The stand: two struts under the barrel.
	for side: float in [-1.0, 1.0]:
		draw_line(LAUNCHER_AT + Vector2(side * 26, 30), LAUNCHER_AT + Vector2(side * 6, -4), INK, 9.0)
		draw_line(LAUNCHER_AT + Vector2(side * 26, 30), LAUNCHER_AT + Vector2(side * 6, -4), WOOD.darkened(0.2), 5.0)
	var kick := 0.0
	if phase == "fly" and since < 0.2 and not reduced_motion:
		kick = -10.0 * (1.0 - since / 0.2)
	draw_set_transform(LAUNCHER_AT + Vector2.from_angle(LAUNCH_ANGLE) * kick, LAUNCH_ANGLE, Vector2.ONE * TEXEL)
	stamp(_launcher, Vector2(-8, -8), 1.0)
	draw_set_transform(Vector2.ZERO)
	# A bundle sits loaded in the muzzle while aiming.
	if phase == "aim":
		stamp(_bundle, MUZZLE - Vector2(9, 12) * 3.0, 3.0)
	# The hose from the pump.
	var hose := PackedVector2Array()
	for step in 9:
		var t := step / 8.0
		hose.append(PUMP_AT.lerp(LAUNCHER_AT + Vector2(-10, 12), t) + Vector2(0, -6 + 26.0 * sin(t * PI)))
	draw_polyline(hose, INK, 9.0)
	draw_polyline(hose, Color("#4a4a6a"), 5.0)


func _draw_pump(pumping: bool, pressure: float, bursting: bool, since: float) -> void:
	ground_shadow(PUMP_AT + Vector2(0, 2), Vector2(32, 8), 0.32)
	if bursting:
		# Burst open: torn halves and a ring of smoke.
		# Split open: the lower half stays, sooty, with a torn jagged rim.
		var base := PUMP_AT - Vector2(7, 26) * TEXEL
		draw_texture_rect_region(_pump, Rect2(base + Vector2(0, 14 * TEXEL), Vector2(14, 12) * TEXEL), Rect2(Vector2(0, 14), Vector2(14, 12)), Color(0.8, 0.62, 0.62))
		var rim := PackedVector2Array()
		for tooth in 8:
			rim.append(base + Vector2(4.0 + tooth * 6.4, 14.0 * TEXEL - (14.0 if tooth % 2 == 0 else 2.0)))
		draw_polyline(rim, INK, 5.0)
		draw_polyline(rim, PUMP_RED.lightened(0.2), 2.0)
		# Shreds of the top half flung up, and a rolling cloud of smoke.
		var spread := 1.0 if reduced_motion else clampf(since / 1.2, 0.0, 1.0)
		for shred in 4:
			var dir := Vector2.from_angle(-PI * 0.5 + (shred - 1.5) * 0.7)
			var at := PUMP_AT + Vector2(0, -70) + dir * 160.0 * spread + Vector2(0, 260.0 * spread * spread)
			draw_set_transform(at, shred + since * 8.0, Vector2.ONE)
			draw_rect(Rect2(-9, -6, 18, 12), INK)
			draw_rect(Rect2(-7, -4, 14, 8), PUMP_RED if shred % 2 == 0 else Color("#c3c8cf"))
			draw_set_transform(Vector2.ZERO)
		for puff in 9:
			var dir := Vector2.from_angle(puff * TAU / 9.0 + 0.3)
			var at := PUMP_AT + Vector2(0, -50) + dir * (24.0 + 80.0 * spread) + Vector2(0, -40.0 * spread)
			var radius := 30.0 * (1.0 - spread * 0.4)
			var fade := 0.9 * (1.0 - spread * 0.8)
			draw_circle(at, radius + 3.0, Color(0.35, 0.3, 0.45, fade * 0.6))
			draw_circle(at, radius, Color(0.78, 0.74, 0.84, fade))
			draw_circle(at + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.45, Color(0.95, 0.93, 0.98, fade))
		return
	stamp(_pump, PUMP_AT - Vector2(7, 26) * TEXEL)
	# The T-handle rides up and down with each stroke.
	var stroke := 0.0
	if pumping and not reduced_motion:
		stroke = absf(sin(pressure * PI * 7.0))
	var handle := PUMP_AT + Vector2(0, -112.0 + 34.0 * stroke)
	draw_rect(Rect2(handle.x - 4, handle.y, 8, PUMP_AT.y - 96.0 - handle.y), INK)
	draw_rect(Rect2(handle.x - 2, handle.y, 4, PUMP_AT.y - 96.0 - handle.y), Color("#c3c8cf"))
	draw_rect(Rect2(handle.x - 34, handle.y - 8, 68, 14), INK)
	draw_rect(Rect2(handle.x - 32, handle.y - 6, 64, 10), WOOD)
	draw_rect(Rect2(handle.x - 32, handle.y - 6, 64, 4), WOOD.lightened(0.25))


func _draw_hero(pumping: bool, pressure: float) -> void:
	var pose := &"up" if pumping and fmod(pressure * 7.0, 1.0) < 0.5 else &"idle"
	var mood := "shocked" if pressure > Game.RED else "plain"
	ground_shadow(HERO_AT + Vector2(0, 2), Vector2(42, 9), 0.34)
	draw_set_transform(HERO_AT, 0.0, Vector2.ONE * HERO_SCALE)
	stamp(Hero.texture(pose, true, mood), -Hero.FEET, 1.0)
	draw_set_transform(Vector2.ZERO)
	if pressure > Game.RED and not reduced_motion:
		# Sweat drops fly as the pump strains.
		for drop in 2:
			var at := HERO_AT + Vector2(-40 + drop * 80, -150 - fmod(now * 60.0 + drop * 20.0, 30.0))
			draw_circle(at, 5.0, Color("#9fdcff"))


## Blown off the deck: the hero floats up with a huge frizzed afro, then drifts back.
func _draw_burst_hero(since: float) -> void:
	var t := clampf(since / Game.BURST_SECONDS, 0.0, 1.0)
	var lift := 1.0 if reduced_motion else sin(t * PI)
	var feet := HERO_AT + Vector2(10.0 * sin(since * 3.0), -150.0 * lift)
	ground_shadow(HERO_AT + Vector2(0, 2), Vector2(42.0 * (1.0 - lift * 0.5), 9.0), 0.25)
	# The afro puffs up behind the head; the face stays in front of it.
	var grow := clampf(since / 0.25, 0.0, 1.0)
	var size := 72.0 * grow
	var head := feet + Vector2(4.0, -37.0 * HERO_SCALE - size * 0.18)
	# The baked afro: tight curls lit from the upper left, frizzy edge, outlined.
	var afro := Pixels.bake("pump-afro", Vector2i(36, 30), _paint_afro)
	var texel := size * 2.0 / 38.0
	if texel > 0.05:
		stamp(afro, head - Vector2(19, 16) * texel, texel)
	if not reduced_motion and since < 1.2:
		for spark in 5:
			var at := head + Vector2.from_angle(spark * 1.3 + since * 4.0) * (size + 18.0)
			draw_circle(at, 4.0, Color(GOLD, 1.0 - since / 1.2))
	draw_set_transform(feet, 0.0, Vector2.ONE * HERO_SCALE)
	stamp(Hero.texture(&"up", true, "shocked"), -Hero.FEET, 1.0)
	draw_set_transform(Vector2.ZERO)
	if since > 0.25:
		label(head + Vector2(0, -size - 30.0), "砰！", 30, CREAM)


## The pressure gauge: brass bezel, cream dial, a green arc over the pad, red at the end.
func _draw_gauge(needle: float, target: float, zone: float, bursting: bool, since: float) -> void:
	var at := GAUGE_AT
	if bursting and since < 0.4 and not reduced_motion:
		at += Vector2(sin(since * 80.0), cos(since * 70.0)) * 6.0
	ground_shadow(at + Vector2(10, GAUGE_RADIUS + 18.0), Vector2(60, 8), 0.0)
	draw_circle(at + Vector2(6, 8), GAUGE_RADIUS + 14.0, Color(0.1, 0.06, 0.18, 0.3))
	draw_circle(at, GAUGE_RADIUS + 14.0, INK)
	draw_circle(at, GAUGE_RADIUS + 11.0, BRASS.darkened(0.25))
	draw_arc(at, GAUGE_RADIUS + 7.0, PI * 0.9, PI * 1.6, 24, BRASS.lightened(0.35), 6.0)
	draw_circle(at, GAUGE_RADIUS + 1.0, INK)
	draw_circle(at, GAUGE_RADIUS, Color("#f6ecd4"))
	draw_circle(at + Vector2(-14, -16), GAUGE_RADIUS * 0.7, Color(1, 1, 1, 0.25))
	# Red at the end, green over the pad.
	draw_arc(at, GAUGE_RADIUS - 14.0, _angle(Game.RED), _angle(Game.BURST), 16, RED_ZONE, 18.0)
	draw_arc(at, GAUGE_RADIUS - 14.0, _angle(target - zone), _angle(target + zone), 16, GREEN.darkened(0.15), 22.0)
	draw_arc(at, GAUGE_RADIUS - 14.0, _angle(target - zone * 0.3), _angle(target + zone * 0.3), 8, GREEN.lightened(0.35), 22.0)
	for tick in 11:
		var dir := Vector2.from_angle(_angle(tick / 10.0))
		draw_line(at + dir * (GAUGE_RADIUS - 6.0), at + dir * (GAUGE_RADIUS - (18.0 if tick % 5 == 0 else 12.0)), INK, 3.0)
	label(at + Vector2(0, 40), "氣壓", 18, INK, 1.0, 1.0, false)
	# The needle, with a hub cap.
	var tip := at + Vector2.from_angle(_angle(minf(needle, 1.04))) * (GAUGE_RADIUS - 10.0)
	draw_line(at, tip, INK, 8.0)
	draw_line(at, tip, Color("#c0485e"), 4.0)
	draw_circle(at, 11.0, INK)
	draw_circle(at, 8.0, BRASS)
	draw_circle(at + Vector2(-2, -2), 3.0, BRASS.lightened(0.4))
	if needle >= target - zone and needle <= target + zone and bool(state.get("pumping", false)):
		label(at + Vector2(0, -GAUGE_RADIUS - 34.0), "放開！", 28, GOLD, 0.95 + 0.08 * pulse(6.0))


func _angle(pressure: float) -> float:
	return GAUGE_FROM + clampf(pressure, 0.0, 1.05) * GAUGE_SWEEP


## A bundle arcs from the muzzle; a hit lands on the pad, a miss drops into the clouds.
func _draw_bundle_flight(shot: Dictionary, phase: String, since: float) -> void:
	var land_x := _pad_x(float(shot.pressure))
	var top := PAD_Y + _pad_bob() - 30.0
	var result := str(shot.result)
	if phase == "fly":
		var t := 1.0 if reduced_motion else clampf(since / Game.FLIGHT_SECONDS, 0.0, 1.0)
		var at := MUZZLE.lerp(Vector2(land_x, top), t) - Vector2(0, 260.0 * sin(t * PI) * (0.4 + float(shot.pressure)))
		ground_shadow(Vector2(at.x, 640.0), Vector2(26, 6), 0.15)
		draw_set_transform(at, (0.0 if reduced_motion else since * 7.0), Vector2.ONE * 3.0)
		stamp(_bundle, -Vector2(9, 8), 1.0)
		draw_set_transform(Vector2.ZERO)
		return
	if result == "hit":
		var squash_v := squash(since, 0.3)
		draw_set_transform(Vector2(land_x, top + 22.0), 0.0, Vector2(3.0 * squash_v.x, 3.0 * squash_v.y))
		stamp(_bundle, -Vector2(9, 14), 1.0)
		draw_set_transform(Vector2.ZERO)
		if bool(shot.bull):
			dust_puffs(Vector2(land_x, top + 24.0), since, 70.0)
		return
	# A miss tumbles down into the cloud floor and goes 噗.
	var fall := 1.0 if reduced_motion else clampf(since / Game.LAND_SECONDS, 0.0, 1.0)
	var at := Vector2(land_x + (30.0 if result == "long" else -10.0) * fall, top + 220.0 * fall * fall)
	draw_set_transform(at, fall * 3.0, Vector2.ONE * 3.0)
	stamp(_bundle, -Vector2(9, 8), 1.0, Color(1, 1, 1, 1.0 - fall * 0.6))
	draw_set_transform(Vector2.ZERO)
	if fall > 0.6:
		label(Vector2(clampf(land_x, 120.0, 1160.0), 600.0), "噗", 26, CREAM)


static func _paint_afro(x: int, y: int) -> Color:
	var offset := (Vector2(x, y) - Vector2(17.5, 15.0)) / Vector2(17.5, 15.0)
	var angle := offset.angle()
	# A lumpy outline of round curls.
	var edge := 1.0 - 0.09 * absf(sin(angle * 6.0)) - 0.04 * absf(sin(angle * 13.0 + 1.0))
	if offset.length() > edge:
		return Pixels.CLEAR
	# Little curl rings across the whole mop.
	var cell := Vector2(fposmod(x + (y / 4) * 2, 4.0) - 1.5, fposmod(y, 4.0) - 1.5)
	var ring := absf(cell.length() - 1.4) < 0.6
	var light := 0.2 - (offset.x + offset.y) * 0.45 - offset.length() * 0.25
	return Pixels.lit(AFRO.lightened(0.08) if ring else AFRO.darkened(0.1), light + (0.15 if ring else -0.2), x, y)


static func _paint_deck(x: int, y: int) -> Color:
	if y < 4:
		return Pixels.wood(WOOD.lightened(0.12), x, y, 4, false)
	if y < 30:
		var plank := Pixels.wood(WOOD, x, y - 4, 6, false)
		return Pixels.lit(plank, 0.3 - (y - 4) * 0.03, x, y)
	# The deck's underside beams in shade.
	if x % 28 < 6:
		return Pixels.lit(WOOD.darkened(0.35), -0.2, x, y)
	if y < 33:
		return Pixels.lit(WOOD.darkened(0.25), -0.3, x, y)
	return Pixels.CLEAR


static func _paint_pump(x: int, y: int) -> Color:
	# A red cylinder with steel bands, round and lit from the left.
	var across := (x - 5.5) / 6.0
	if y < 2:
		return Pixels.metal(Color("#a8adb8"), x, y)
	if y >= 21:
		return Pixels.lit(Color("#4a4a6a"), 0.2 - absf(across), x, y) if absf(across) < 1.0 else Pixels.CLEAR
	var tone := Color("#c3c8cf") if y in [2, 3, 12, 19, 20] else PUMP_RED
	return Pixels.lit(tone, 0.45 - across * 0.7 - y * 0.01, x, y)


static func _paint_launcher(x: int, y: int) -> Color:
	# A brass barrel flaring at the muzzle, with two bands and a dark bore.
	var flare := 1.0 if x > 28 else 0.0
	var half := 4.0 + flare + x * 0.04
	var across := (y - 6.5) / half
	if absf(across) > 1.0:
		return Pixels.CLEAR
	if x > 31 and absf(across) < 0.55:
		return Color("#2b2440")
	var tone := Color("#9a6a2a") if x in [8, 9, 20, 21] else BRASS
	return Pixels.lit(tone, 0.55 - across * 0.8, x, y)


static func _paint_bundle(x: int, y: int) -> Color:
	# A plump cloud bundle tied with a pink ribbon and a bow on top.
	var centre := Vector2(7.5, 7.5)
	var body := (Vector2(x, y) - centre) / Vector2(7.5, 5.2)
	if y < 3:
		var bow := absf(x - 7.5)
		if bow < 4.0 and y >= int(bow * 0.5):
			return Pixels.lit(RIBBON, 0.4 - (y - 1) * 0.2, x, y)
		return Pixels.CLEAR
	if body.length() > 1.0:
		return Pixels.CLEAR
	if absf(x - 7.5) < 1.0 or absf(y - 8.0) < 0.6:
		return Pixels.lit(RIBBON, 0.3 - body.y * 0.4, x, y)
	return Pixels.lit(SkyBackdrop.CLOUD.lerp(SkyBackdrop.CLOUD_SHADE, clampf(body.y + 0.3, 0.0, 1.0) * 0.6), 0.5 - (body.x + body.y) * 0.5, x, y)


static func _paint_pad(x: int, y: int, width: int) -> Color:
	if y == 0:
		return Pixels.lit(WOOD.lightened(0.2), 0.4, x, y)
	if y < 4:
		return Pixels.lit(Pixels.wood(WOOD, x, y, 3, false), 0.2 - y * 0.1, x, y)
	return Pixels.lit(WOOD.darkened(0.3), -0.3, x, y) if x > 1 and x < width - 2 else Pixels.CLEAR
