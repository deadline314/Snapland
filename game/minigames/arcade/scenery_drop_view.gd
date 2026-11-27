extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 舞台換景: the tent's gilt arch is a little theatre. Painted
## backdrop cloths (moonlit night, forest, castle, seaside) drop from the flies
## into the arch behind a velvet valance; the actor struts in front, the
## ringmaster shouts the next scene from the left wing with a picture of it in
## his speech bubble, and the stagehand's fly rail on the right shows which
## direction lowers which cloth. A wrong cloth crashes down on the actor, who
## walks out from behind it as a flat paper cut-out; a slow one gets booed and
## a tomato. Every object is baked pixel art (arcade_pixels.gd) or a shared
## material, tinted to the tent's dusk.

const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 552.0
## Where a hanging cloth fills the arch; its top runs up behind the valance.
const OPENING := Rect2(452, 256, 448, 296)
const VALANCE := Rect2(436, 222, 480, 54)
const CLOTH_TEXELS := Vector2i(110, 72)
const FEET_Y := 646.0
const BUBBLE := Rect2(126, 286, 336, 150)
const RAIL := Rect2(986, 300, 284, 262)
## Where each scene sits on the fly rail, as the arrow that lowers it.
const RAIL_SLOTS := {"moon": Vector2(1128, 338), "forest": Vector2(1042, 422), "castle": Vector2(1214, 422), "sea": Vector2(1128, 504)}
const ARROWS := {"moon": "↑", "forest": "←", "castle": "→", "sea": "↓"}
const NAMES := {"moon": "月夜", "forest": "森林", "castle": "城堡", "sea": "海邊"}
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const TIMBER := Color("#8a5a3c")
const BRASS := Color("#b0803a")
const VALANCE_RED := Color("#8a2f3f")
const LAMP := Color(0.94, 0.89, 0.96)
## Painted cloths sit a little deeper in the tent's dusk than the figures.
const CLOTH_LIGHT := Color(0.86, 0.8, 0.9)
const PAPER := Color("#f3e8cf")
const DROP_SECONDS := 0.32
const LIFT_SECONDS := 0.55
const ACTOR_SIZE := Vector2i(26, 44)
const ACTOR_ORIGIN := Vector2i(13, 43)
const HOST_SIZE := Vector2i(30, 46)
const HOST_ORIGIN := Vector2i(12, 45)
const HOST_X := 214.0

var _has_tent := false
var _cloths: Dictionary = {}
var _actors: Dictionary = {}
var _hosts: Dictionary = {}
var _crowd: ImageTexture
var _tomato: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(676, 330)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.7, 0.64, 0.78))
	for scene: String in NAMES:
		_cloths[scene] = Pixels.bake("scenery-cloth|" + scene, CLOTH_TEXELS, func(x: int, y: int) -> Color: return _paint_cloth(scene, x, y))
	for look: String in ["proud", "tada", "shock", "sorry", "paper"]:
		_actors[look] = Pixels.bake_blocks("scenery-actor|" + look, ACTOR_SIZE, ACTOR_ORIGIN, _actor_blocks(look))
	for look: String in ["quiet", "talk", "sweat"]:
		_hosts[look] = Pixels.bake_blocks("scenery-host|" + look, HOST_SIZE, HOST_ORIGIN, _host_blocks(look))
	_crowd = Pixels.bake("scenery-crowd", Vector2i(320, 22), Pixels.crowd)
	_tomato = Pixels.bake("scenery-tomato", Vector2i(7, 7), func(x: int, y: int) -> Color:
		var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(3.5, 3.8)) / 3.4
		if y == 0 and x == 3:
			return Color("#4f7a3a")
		return Pixels.rounded(Color("#c9342f"), offset) if offset.length() <= 1.0 else Pixels.CLEAR)


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.5)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "wait"))
	var since := age(float(state.get("phase_at", 0.0)))
	for cloth: Dictionary in state.get("lifting", []):
		_draw_cloth(str(cloth.scene), str(cloth.slot), 1.0 - _ease(age(float(cloth.at)) / LIFT_SECONDS))
	for cloth: Dictionary in state.get("hanging", []):
		_draw_cloth(str(cloth.scene), str(cloth.slot), _ease(age(float(cloth.at)) / DROP_SECONDS), age(float(cloth.at)))
	_draw_valance()
	_draw_rail()
	_draw_host()
	if phase == "crash":
		_draw_crash(since)
	else:
		_draw_actor(phase, since)
	_draw_crowd(phase, since)
	_draw_bubble()


func _ease(t: float) -> float:
	if reduced_motion:
		return 1.0 if t > 0.0 else 0.0
	var clamped := clampf(t, 0.0, 1.0)
	return clamped * clamped


# --- Cloths -------------------------------------------------------------------

## A cloth `down` of the way into the arch (1 = landed), clipped where it runs
## up behind the valance; a "left" or "right" slot shows that half of it.
func _draw_cloth(scene: String, slot: String, down: float, landed_for := 9.0) -> void:
	if down <= 0.0 or not _cloths.has(scene):
		return
	var texture: Texture2D = _cloths[scene]
	var rect := OPENING
	rect.position.y -= (1.0 - down) * (OPENING.size.y + 20.0)
	if down >= 1.0 and landed_for < 0.3 and not reduced_motion:
		# A little bounce on the batten as it lands.
		rect.position.y -= 7.0 * sin(landed_for / 0.3 * PI) * (1.0 - landed_for / 0.3)
	_paint_cloth_rect(texture, rect, slot, OPENING.position.y)
	if down >= 1.0:
		ground_shadow(Vector2(_slot_span(rect, slot).get_center().x, FLOOR_TOP + 6.0), Vector2(_slot_span(rect, slot).size.x * 0.48, 7), 0.4)
		if landed_for < 0.5:
			dust_puffs(Vector2(_slot_span(rect, slot).get_center().x, FLOOR_TOP + 4.0), landed_for, 120.0)


func _slot_span(rect: Rect2, slot: String) -> Rect2:
	match slot:
		"left":
			return Rect2(rect.position, Vector2(rect.size.x * 0.5, rect.size.y))
		"right":
			return Rect2(rect.position + Vector2(rect.size.x * 0.5, 0), Vector2(rect.size.x * 0.5, rect.size.y))
	return rect


func _paint_cloth_rect(texture: Texture2D, rect: Rect2, slot: String, clip_top: float, tint := CLOTH_LIGHT) -> void:
	var span := _slot_span(rect, slot)
	var top := maxf(span.position.y, clip_top)
	if top >= span.end.y - 2.0:
		return
	var stretch := rect.size / Vector2(texture.get_size())
	# A half shows the middle of its picture, where the moon, castle or sun is.
	var from_x := 0.0 if slot == "full" else texture.get_width() * 0.25
	var from_y := (top - rect.position.y) / stretch.y
	draw_texture_rect_region(texture, Rect2(span.position.x, top, span.size.x, span.end.y - top),
		Rect2(from_x, from_y, span.size.x / stretch.x, texture.get_height() - from_y), tint)
	# Stage light falls off toward the cloth's sides.
	for band in 3:
		var shade := Color(0.05, 0.02, 0.08, 0.16 - band * 0.05)
		draw_rect(Rect2(span.position.x + band * 8.0, top, 8, span.end.y - top), shade)
		draw_rect(Rect2(span.end.x - 8.0 - band * 8.0, top, 8, span.end.y - top), shade)
	# A timber batten weighs the hem down.
	panel(Rect2(span.position.x - 6.0, span.end.y - 8.0, span.size.x + 12.0, 14), "planks", TIMBER, Pixels.CLEAR, 2.0, tint)


## A velvet valance with a gold fringe hides the flies and the cloths' tops.
func _draw_valance() -> void:
	for band in 3:
		draw_rect(Rect2(OPENING.position.x, VALANCE.end.y + band * 10.0, OPENING.size.x, 10), Color(0.05, 0.02, 0.08, 0.32 - band * 0.1))
	panel(VALANCE, "velvet", VALANCE_RED, GOLD.darkened(0.15), TEXEL, LAMP)
	gilt_frame(Rect2(VALANCE.position.x - 6.0, VALANCE.position.y - 8.0, VALANCE.size.x + 12.0, 16), 8.0, GILT, 2.0, LAMP)


# --- Actor --------------------------------------------------------------------

func _actor_x() -> float:
	return 676.0 + (0.0 if reduced_motion else 120.0 * sin(now * 0.55))


func _draw_actor(phase: String, since: float) -> void:
	var x := _actor_x()
	var facing := 1.0 if reduced_motion or cos(now * 0.55) >= 0.0 else -1.0
	var look := "proud"
	var newest := 99.0
	for cloth: Dictionary in state.get("hanging", []):
		newest = minf(newest, age(float(cloth.at)))
	if phase == "boo":
		look = "sorry"
	elif newest < 0.9:
		look = "tada"
	var feet := Vector2(x, FEET_Y)
	if look == "proud" and not reduced_motion:
		feet.y -= absf(sin(now * 5.0)) * 4.0
	var stretch := squash(newest - DROP_SECONDS, 0.18) if look == "tada" else Vector2.ONE
	ground_shadow(Vector2(x, FEET_Y + 4.0), Vector2(46, 9), 0.42)
	draw_set_transform(feet, 0.0, Vector2(facing, 1.0) * stretch * TEXEL)
	stamp(_actors[look], -Vector2(ACTOR_ORIGIN), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if look == "tada" and not reduced_motion:
		for spark in 4:
			var turn := now * 3.0 + spark * TAU / 4.0
			var at := feet + Vector2(0, -46.0 * TEXEL * 0.5) + Vector2.from_angle(turn) * Vector2(110, 60)
			draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color(GOLD, 0.8 - newest * 0.8))
	if phase == "boo":
		_draw_tomato(feet + Vector2(4.0 * facing, -36.0 * TEXEL), since)


## A tomato arcs up from the audience and splats on his face.
func _draw_tomato(face: Vector2, since: float) -> void:
	var flight := 0.45
	if since < flight and not reduced_motion:
		var t := since / flight
		var start := Vector2(face.x + 260.0, DESIGN.y + 10.0)
		var at := start.lerp(face, t) - Vector2(0, 220.0 * sin(t * PI))
		draw_set_transform(at, now * 8.0, Vector2.ONE * TEXEL)
		stamp(_tomato, Vector2(-3.5, -3.5), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)
		return
	var splat := Color("#b8322c")
	for blob: Vector2 in [Vector2(0, 0), Vector2(-14, 6), Vector2(12, 8), Vector2(-4, 16), Vector2(16, -8)]:
		draw_rect(Rect2(face + blob - Vector2(8, 8), Vector2(16, 16)), splat.darkened(0.35))
		draw_rect(Rect2(face + blob - Vector2(6, 6), Vector2(12, 12)), splat)
	draw_rect(Rect2(face + Vector2(-6, -6), Vector2(4, 4)), Color("#ff8a7a"))
	if since < flight + 0.3:
		label(face + Vector2(0, -60), "啪！", 26, ROSE)


## The wrong cloth slams down in front of him; a beat later he walks out from
## behind it, pressed flat into a paper cut-out that flips edge-on as he turns.
func _draw_crash(since: float) -> void:
	var scene := str(state.get("crash_scene", ""))
	var fall := 1.0 if reduced_motion else clampf(since / 0.22, 0.0, 1.0)
	var lift := 0.0 if reduced_motion else clampf((since - 1.7) / 0.6, 0.0, 1.0)
	var near := Rect2(OPENING.position.x - 24.0, 0, OPENING.size.x + 48.0, FEET_Y + 10.0 - OPENING.position.y - 30.0)
	near.position.y = FEET_Y + 10.0 - near.size.y - (1.0 - fall * fall) * 420.0 - lift * lift * 460.0
	if since >= 0.8:
		_draw_paper_actor(since - 0.8)
	if _cloths.has(scene):
		draw_set_transform(Vector2(near.get_center().x, near.end.y), 0.0 if fall < 1.0 or reduced_motion else 0.04 * sin(clampf(since - 0.22, 0.0, 0.6) * 12.0) * (1.0 - clampf(since - 0.22, 0.0, 0.6) / 0.6))
		var local := Rect2(-near.size.x * 0.5, -near.size.y, near.size.x, near.size.y)
		_paint_cloth_rect(_cloths[scene], local, "full", VALANCE.end.y - 14.0 - near.end.y)
		draw_set_transform(Vector2.ZERO)
		if fall >= 1.0 and lift <= 0.0:
			ground_shadow(Vector2(near.get_center().x, FEET_Y + 10.0), Vector2(near.size.x * 0.5, 10), 0.5)
	if since >= 0.22 and since < 0.7:
		dust_puffs(Vector2(near.get_center().x, FEET_Y + 6.0), since - 0.22, 220.0)
		label(Vector2(near.get_center().x, near.position.y - 4.0 + 120.0), "咚！", 44, ROSE, pop_in(since - 0.22, 0.2))
	if since >= 1.0:
		for laugh in 3:
			var rise := 0.0 if reduced_motion else fmod(since * 0.8 + laugh * 0.33, 1.0) * 30.0
			label(Vector2(560.0 + laugh * 250.0, 652.0 - rise - (laugh % 2) * 16.0), "哈哈哈", 26, GOLD, 1.0, 0.95)


func _draw_paper_actor(out: float) -> void:
	var walk := clampf(out / 0.9, 0.0, 1.0)
	var x := OPENING.position.x + 30.0 - walk * 120.0
	if reduced_motion:
		x = OPENING.position.x - 90.0
	# Paper is flat: as he turns he narrows to an edge and widens again.
	var turn := -1.0 if reduced_motion else -cos(out * 2.6)
	var wide := maxf(0.08, absf(turn))
	var rock := 0.0 if reduced_motion else 0.12 * sin(out * 9.0)
	var feet := Vector2(x, FEET_Y)
	ground_shadow(Vector2(x, FEET_Y + 4.0), Vector2(40.0 * wide + 6.0, 6), 0.35)
	draw_set_transform(feet, rock, Vector2(wide * signf(turn if turn != 0.0 else 1.0), 1.0) * TEXEL)
	# A white paper margin, then the flattened print of him.
	for offset: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1)]:
		stamp(_actors["paper"], -Vector2(ACTOR_ORIGIN) + offset, 1.0, Color(4, 4, 4))
	stamp(_actors["paper"], -Vector2(ACTOR_ORIGIN), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if wide < 0.2:
		draw_rect(Rect2(x - 2.0, FEET_Y - 44.0 * TEXEL, 4, 44.0 * TEXEL), PAPER.darkened(0.2))
	else:
		# Where he was folded in the crash: a crease across the chest.
		var reach := 40.0 * wide
		draw_set_transform(feet, rock)
		draw_line(Vector2(-reach, -30.0 * TEXEL), Vector2(reach, -24.0 * TEXEL), Color(PAPER.darkened(0.35), 0.8), 3.0)
		draw_line(Vector2(-reach, -30.0 * TEXEL - 3.0), Vector2(reach, -24.0 * TEXEL - 3.0), Color(1, 1, 1, 0.6), 2.0)
		draw_set_transform(Vector2.ZERO)
	label(feet + Vector2(0, -44.0 * TEXEL - 26.0), "扁了…", 22, CREAM)


# --- Ringmaster and his call --------------------------------------------------

func _draw_host() -> void:
	var cue: Dictionary = state.get("cue", {})
	var look := "quiet"
	if not cue.is_empty():
		var since := age(float(cue.at))
		var fixing := age(float(cue.fixed_at))
		var slipping := not str(cue.slip).is_empty() and fixing < 0.0
		look = "sweat" if slipping else ("talk" if since < 0.6 or (fixing >= 0.0 and fixing < 0.6) else "quiet")
	var feet := Vector2(HOST_X, FEET_Y + 6.0)
	if look == "talk" and not reduced_motion:
		feet.y -= absf(sin(now * 14.0)) * 3.0
	ground_shadow(Vector2(feet.x + 6.0, feet.y + 4.0), Vector2(48, 9), 0.42)
	draw_set_transform(feet, 0.0, Vector2.ONE * TEXEL)
	stamp(_hosts[look], -Vector2(HOST_ORIGIN), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)


func _draw_bubble() -> void:
	var cue: Dictionary = state.get("cue", {})
	if cue.is_empty():
		return
	var since := age(float(cue.at))
	var grow := pop_in(since, 0.22)
	var center := BUBBLE.get_center()
	draw_set_transform(center, 0.0, Vector2.ONE * grow)
	var box := Rect2(BUBBLE.position - center, BUBBLE.size)
	# The tail points down at his megaphone.
	var tail := PackedVector2Array([Vector2(box.position.x + 132, box.end.y - 4), Vector2(box.position.x + 186, box.end.y - 4), Vector2(box.position.x + 172, box.end.y + 58)])
	draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(-4, 0), tail[1] + Vector2(4, 0), tail[2] + Vector2(3, 6)]), INK)
	draw_rect(Rect2(box.position + Vector2(5, 8), box.size), Color(0.06, 0.02, 0.08, 0.4))
	panel(box.grow(3.0), "paper", PAPER, Pixels.CLEAR, 3.0)
	draw_colored_polygon(tail, PAPER.darkened(0.06))
	draw_set_transform(Vector2.ZERO)
	if grow < 0.9:
		return
	var shouted: Array = cue.shouted
	var slip := str(cue.slip)
	var fixing := age(float(cue.fixed_at))
	var words := ""
	if not slip.is_empty() and fixing < 0.0:
		_thumb(slip, Vector2(center.x, BUBBLE.position.y + 50.0), 0.9)
		words = NAMES[slip] + "……"
	elif shouted.size() == 2:
		for index in 2:
			_thumb(str(shouted[index]), Vector2(center.x - 80.0 + index * 160.0, BUBBLE.position.y + 50.0), 0.85, not (cue.scenes as Array).has(shouted[index]))
		label(Vector2(center.x, BUBBLE.position.y + 50.0), "＋", 30, INK, 1.0, 1.0, false)
		words = "%s＋%s！" % [NAMES[shouted[0]], NAMES[shouted[1]]]
	else:
		_thumb(str(shouted[0]), Vector2(center.x + (40.0 if not slip.is_empty() else 0.0), BUBBLE.position.y + 50.0), 0.9)
		words = NAMES[shouted[0]] + "！"
		if not slip.is_empty():
			# The slip, crossed out, slides off to the corner.
			var corner := Vector2(BUBBLE.position.x + 60.0, BUBBLE.position.y + 46.0)
			_thumb(slip, corner, 0.45)
			for side: float in [-1.0, 1.0]:
				draw_line(corner + Vector2(-26, -18 * side), corner + Vector2(26, 18 * side), INK, 9.0)
				draw_line(corner + Vector2(-24, -16 * side), corner + Vector2(24, 16 * side), ROSE, 5.0)
			words = "不對，" + words
	label(Vector2(center.x, BUBBLE.end.y - 34.0), words, 26, INK, 1.0, 1.0, false)
	# A fuse along the bottom burns down while he waits.
	var length := maxf(0.1, float(cue.get("length", 1.0)))
	var left := clampf((float(cue.until) - now) / length, 0.0, 1.0)
	var track := Rect2(BUBBLE.position.x + 22.0, BUBBLE.end.y - 14.0, BUBBLE.size.x - 44.0, 6)
	draw_rect(track.grow(2.0), INK.lerp(PAPER, 0.3))
	draw_rect(Rect2(track.position, Vector2(track.size.x * left, track.size.y)), GOLD.lerp(ROSE, 1.0 - left))
	if left > 0.0:
		var spark := Vector2(track.position.x + track.size.x * left, track.get_center().y)
		draw_circle(spark, 5.0 + pulse(6.0) * 2.0, Color(GOLD, 0.8))


## A little picture of a backdrop in a gilt frame, centred on `center`.
func _thumb(scene: String, center: Vector2, scale_factor: float, done := false) -> void:
	var texture: Texture2D = _cloths[scene]
	var size := Vector2(texture.get_size()) * scale_factor
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0.06, 0.02, 0.08, 0.35))
	draw_texture_rect(texture, rect, false, Color(0.55, 0.52, 0.6) if done else Color.WHITE)
	gilt_frame(rect.grow(4.0), 4.0, GILT, 2.0)
	if done:
		# A tick: this one is already down.
		var tick := PackedVector2Array([center + Vector2(-14, 0), center + Vector2(-4, 10), center + Vector2(16, -12)])
		draw_polyline(tick, INK, 10.0)
		draw_polyline(tick, MINT, 5.0)


# --- Fly rail -----------------------------------------------------------------

## The stagehand's rail: one little picture per cloth where its arrow points.
func _draw_rail() -> void:
	ground_shadow(Vector2(RAIL.get_center().x, FEET_Y + 6.0), Vector2(150, 10), 0.4)
	for leg: float in [RAIL.position.x + 30.0, RAIL.end.x - 30.0]:
		panel(Rect2(leg - 8.0, RAIL.end.y - 6.0, 16, FEET_Y - RAIL.end.y + 10.0), "planks_v", TIMBER.darkened(0.1), Pixels.CLEAR, 2.0, LAMP)
	draw_rect(Rect2(RAIL.position + Vector2(6, 10), RAIL.size), Color(0.06, 0.02, 0.08, 0.4))
	panel(RAIL, "planks", TIMBER, Pixels.CLEAR, TEXEL, LAMP)
	gilt_frame(RAIL.grow(6.0), 10.0, BRASS, 2.0, LAMP)
	var pulled := {}
	for cloth: Dictionary in state.get("hanging", []):
		if age(float(cloth.at)) < 0.35:
			pulled[str(cloth.scene)] = true
	if str(state.get("phase", "")) == "crash" and age(float(state.get("phase_at", 0.0))) < 0.35:
		pulled[str(state.get("crash_scene", ""))] = true
	for scene: String in RAIL_SLOTS:
		var at: Vector2 = RAIL_SLOTS[scene] + (Vector2(0, 8) if pulled.has(scene) else Vector2.ZERO)
		# A rope runs up from each picture to its pulley.
		draw_line(at + Vector2(0, -40), at + Vector2(0, -28), INK, 5.0)
		draw_line(at + Vector2(0, -40), at + Vector2(0, -28), Color("#d9c49a"), 2.0)
		draw_circle(at + Vector2(0, -42), 5.0, BRASS.darkened(0.4))
		draw_circle(at + Vector2(-1, -43), 3.0, BRASS.lightened(0.2))
		_thumb(scene, at, 0.7)
		key_cap(at + Vector2(0, 36), ARROWS[scene], pulled.has(scene), 14)


# --- Audience -----------------------------------------------------------------

func _draw_crowd(phase: String, since: float) -> void:
	var bob := 0.0 if reduced_motion else roundf(sin(now * 2.0) * 2.0)
	if phase == "boo" and not reduced_motion:
		bob = roundf(sin(now * 18.0) * 3.0)
	stamp(_crowd, Vector2(0, DESIGN.y - 80.0 + bob), TEXEL, Color(0.55, 0.48, 0.6))
	if phase == "boo":
		for jeer in 4:
			var rise := 0.0 if reduced_motion else clampf(since / 0.5, 0.0, 1.0) * 24.0
			label(Vector2(170.0 + jeer * 300.0, 636.0 - rise - (jeer % 2) * 18.0), "噓～", 26, ROSE, 1.0, 1.0 - clampf((since - 0.9) / 0.4, 0.0, 1.0))


# --- Painted cloths -----------------------------------------------------------

## A backdrop painted on hanging canvas: soft vertical folds over the picture.
func _paint_cloth(scene: String, x: int, y: int) -> Color:
	var paint: Array
	match scene:
		"moon":
			paint = _paint_moon(x, y)
		"forest":
			paint = _paint_forest(x, y)
		"castle":
			paint = _paint_castle(x, y)
		_:
			paint = _paint_sea(x, y)
	var fold := 0.3 * sin(x * TAU / 13.0 + 0.6) + 0.12 * (Pixels.noise(x, y, 5) - 0.5)
	if x == 0 or x == CLOTH_TEXELS.x - 1:
		fold -= 0.8
	return Pixels.lit(paint[0], float(paint[1]) + fold, x, y)


static func _paint_moon(x: int, y: int) -> Array:
	var moon := Vector2(x - 60, y - 18)
	var near := 58.0 + 4.0 * sin(x * 0.11 + 1.0)
	var far := 50.0 + 6.0 * sin(x * 0.07)
	if y >= near:
		if x >= 18 and x <= 30 and y < near + 8.0 and y > near - 9.0:
			if y < near - 3.0 and (x == 22 or x == 26) and y > near - 7.0:
				return [Color("#ffd27a"), 0.8]
			return [Color("#3a3150"), 0.0]
		return [Color("#1e2a40"), -0.2 + 0.4 * (Pixels.noise(x / 2, y / 2, 3) - 0.5)]
	if y >= far:
		return [Color("#2c3a5c"), 0.1]
	if moon.length() < 11.0:
		var crater := Vector2(x - 56, y - 15).length() < 2.6 or Vector2(x - 64, y - 22).length() < 1.8
		return [Color("#f4e4b0").darkened(0.12 if crater else 0.0), 0.9 - moon.length() / 11.0 * 0.8 - (moon.x + moon.y) * 0.03]
	if Pixels.noise(x, y, 7) > 0.992:
		return [Color("#fff3c4"), 1.0]
	var sky := Color("#1d2450").lerp(Color("#4a3a78"), clampf(y / 56.0, 0.0, 1.0))
	return [sky.lightened(0.18 if moon.length() < 15.0 else 0.0), 0.0]


static func _paint_forest(x: int, y: int) -> Array:
	if y >= 62:
		if Pixels.noise(x, y, 11) > 0.93:
			return [Color("#e8d070") if Pixels.noise(x, y, 12) > 0.5 else Color("#e07a8a"), 0.6]
		return [Color("#5f8a3c"), 0.3 - (y - 62) * 0.12]
	for tree in 6:
		var trunk_x := tree * 20 + 9 + int(Pixels.noise(tree, 1, 4) * 5.0)
		var crown := Vector2((x - trunk_x) / 1.0, (y - 22.0 - (tree % 2) * 6.0) / 0.85)
		if crown.length() < 12.0 + Pixels.noise(tree, 2, 4) * 3.0 and not (crown.length() > 9.0 and Pixels.noise(x, y, 13) > 0.7):
			return [Color("#3f6a3e") if tree % 2 == 0 else Color("#4c7a40"), 0.8 - (crown.x + crown.y) / 12.0 * 0.7]
		if x >= trunk_x - 2 and x <= trunk_x + 1 and y > 28:
			return [Color("#6b4a32"), 0.4 if x == trunk_x - 2 else -0.1]
	var canopy := 30.0 + 5.0 * absf(sin(x * 0.23))
	if y >= canopy:
		return [Color("#4f6a58"), -0.2 + 0.3 * (Pixels.noise(x / 3, y / 3, 9) - 0.5)]
	return [Color("#9fc9a8").lerp(Color("#ead9a0"), clampf(y / 30.0, 0.0, 1.0)), 0.3]


static func _paint_castle(x: int, y: int) -> Array:
	var hill := 54.0 + 3.0 * sin(x * 0.05)
	var path := absf(x - 55.0 - (y - 56.0) * 0.6) < 2.0 + (y - 56.0) * 0.4
	if y >= hill:
		if y >= 56 and path:
			return [Color("#d8c08a"), 0.2]
		return [Color("#6fa860"), 0.4 - (y - hill) * 0.06 + 0.3 * (Pixels.noise(x / 2, y, 6) - 0.5)]
	for tower_x: int in [35, 75]:
		var roof_tip := 6
		if y >= roof_tip and y < 18 and absf(x - tower_x) <= (y - roof_tip) * 0.55 + 0.5:
			return [Color("#c0483e"), 0.8 - (x - tower_x) * 0.15]
		if y >= 18 and absf(x - tower_x) <= 5:
			if absf(x - tower_x) <= 0 and y > 24 and y < 30:
				return [Color("#2e2638"), 0.0]
			return [Color("#c8c4d4"), _bricks(x, y) + 0.6 - (x - tower_x + 5) * 0.14]
		if tower_x == 75 and x == 75 and y >= 1 and y < 6:
			return [Color("#5a4a3a"), 0.0]
		if tower_x == 75 and x > 75 and x <= 80 and y >= 1 and y < 4:
			return [Color("#e9b85c"), 0.6]
	if x >= 40 and x <= 70 and y >= 26:
		if y < 30 and posmod(x, 4) >= 2:
			return _castle_sky(x, y)
		if absf(x - 55) <= 4 and y >= 42 and (y >= 46 or absf(x - 55) <= 3):
			return [Color("#3a2a30"), -0.4]
		if (x == 46 or x == 64) and y >= 33 and y < 38:
			return [Color("#2e2638"), 0.0]
		return [Color("#a49fb4"), _bricks(x, y) + 0.1]
	return _castle_sky(x, y)


static func _castle_sky(x: int, y: int) -> Array:
	var cloud := Vector2((x - 18.0) / 2.2, y - 14.0).length() < 4.0 or Vector2((x - 24.0) / 2.0, y - 12.0).length() < 3.5 \
		or Vector2((x - 92.0) / 2.4, y - 20.0).length() < 3.2
	if cloud:
		return [Color("#f4f0ea"), 0.6 - (y - 12) * 0.12]
	return [Color("#8fc8e8").lerp(Color("#d8ecf0"), clampf(y / 54.0, 0.0, 1.0)), 0.2]


static func _bricks(x: int, y: int) -> float:
	var row := y / 3
	if y % 3 == 0 or posmod(x + (row % 2) * 3, 6) == 0:
		return -0.6
	return 0.2 * (Pixels.noise(x / 6, row, 8) - 0.5)


static func _paint_sea(x: int, y: int) -> Array:
	if y >= 62:
		return [Color("#e8c890"), 0.5 - (y - 62) * 0.1 + 0.3 * (Pixels.noise(x, y, 14) - 0.5)]
	var sun := Vector2(x - 56, y - 40)
	if y < 40:
		if sun.length() < 9.0:
			return [Color("#ffe0a0"), 1.0 - sun.length() / 9.0 * 0.6]
		# A little boat on the horizon line.
		if y >= 35 and y < 39 and x >= 18 and x <= 28 and absf(x - 23) <= (y - 34) + 1:
			return [Color("#f4ead8"), 0.6 - (x - 18) * 0.05]
		return [Color("#7fa8d8").lerp(Color("#f2b880"), clampf(y / 40.0, 0.0, 1.0)), 0.2]
	if y < 42 and x >= 16 and x <= 30:
		return [Color("#7a4a34"), 0.2]
	var crest := sin(x * 0.5 + y * 1.3) > 0.85
	# The sun's path on the water: short warm dashes along the wave crests.
	var glitter := absf(x - 56) < 3 + (y - 40) * 0.35 and (y % 3 == 0) and Pixels.noise(x, y, 15) > 0.55
	var water := Color("#3f7fa8").darkened(clampf((y - 40) / 40.0, 0.0, 0.3))
	if glitter:
		return [water.lerp(Color("#f2c88a"), 0.6), 0.5]
	return [water, 0.8 if crest else -0.1]


# --- Figures ------------------------------------------------------------------

## The actor in texels around his feet (y up is negative), facing right: a ham
## in a paper crown, ruff collar, red doublet and a midnight cape.
static func _actor_blocks(look: String) -> Array:
	var cape := Color("#34406e")
	var doublet := Color("#b8463f")
	var trim := Color("#e9b85c")
	var tights := Color("#5a4a7a")
	var skin := Color("#f0c8a0")
	var ink := Color("#2b2440")
	var ruff := Color("#f3ead9")
	if look == "paper":
		var faded: Array = _actor_blocks("proud")
		for block: Array in faded:
			block[1] = (block[1] as Color).lerp(PAPER, 0.4)
		return faded
	var arms_up := look == "tada"
	var blocks: Array = [
		[Rect2(-8, -30, 16, 22), cape], [Rect2(-9, -12, 18, 4), cape.darkened(0.2)],
		[Rect2(-5, -3, 4, 3), Color("#4a3428")], [Rect2(1, -3, 5, 3), Color("#4a3428")],
		[Rect2(-4, -14, 3, 11), tights], [Rect2(1, -14, 3, 11), tights],
		[Rect2(-6, -28, 12, 15), doublet], [Rect2(-6, -16, 12, 2), trim], [Rect2(-1, -28, 2, 12), trim],
		[Rect2(-7, -31, 14, 3), ruff], [Rect2(-6, -30, 2, 1), ruff.darkened(0.15)], [Rect2(0, -30, 2, 1), ruff.darkened(0.15)],
		[Rect2(-5, -40, 10, 9), skin], [Rect2(-5, -40, 10, 1), skin.lightened(0.2)],
		[Rect2(-6, -42, 12, 3), trim], [Rect2(-6, -44, 2, 2), trim], [Rect2(-1, -45, 2, 3), trim], [Rect2(4, -44, 2, 2), trim],
		[Rect2(-1, -42, 2, 1), Color("#c9344a")],
		[Rect2(-3, -34, 7, 1), Color("#5a3a2a")], [Rect2(-4, -33, 2, 1), Color("#5a3a2a")], [Rect2(3, -33, 2, 1), Color("#5a3a2a")],
	]
	if arms_up:
		blocks.append_array([[Rect2(-10, -40, 3, 12), doublet], [Rect2(7, -40, 3, 12), doublet], [Rect2(-10, -43, 3, 3), skin], [Rect2(7, -43, 3, 3), skin]])
	else:
		blocks.append_array([[Rect2(-9, -28, 3, 11), doublet], [Rect2(6, -28, 3, 11), doublet], [Rect2(-9, -17, 3, 3), skin], [Rect2(6, -17, 3, 3), skin]])
	match look:
		"shock":
			blocks.append_array([[Rect2(-3, -38, 2, 2), ink], [Rect2(2, -38, 2, 2), ink], [Rect2(-1, -33, 3, 2), Color("#7a1f2f")]])
		"sorry":
			blocks.append_array([[Rect2(-3, -37, 2, 1), ink], [Rect2(2, -37, 2, 1), ink], [Rect2(-4, -39, 2, 1), ink], [Rect2(3, -39, 2, 1), ink],
				[Rect2(-1, -32, 3, 1), ink], [Rect2(6, -39, 1, 2), Color("#9fdcff")]])
		_:
			blocks.append_array([[Rect2(-3, -37, 2, 2), ink], [Rect2(2, -37, 2, 2), ink], [Rect2(-2, -32, 5, 1), Color("#c9344a")],
				[Rect2(-4, -35, 2, 1), Color("#f08c8c")], [Rect2(3, -35, 2, 1), Color("#f08c8c")]])
	return blocks


## The ringmaster in texels around his feet, megaphone raised to the right.
static func _host_blocks(look: String) -> Array:
	var coat := Color("#a83a3a")
	var gold := Color("#e9b85c")
	var hat := Color("#2b2440")
	var skin := Color("#f0c8a0")
	var ink := Color("#2b2440")
	var brass := Color("#c9953e")
	var blocks: Array = [
		[Rect2(-5, -3, 4, 3), Color("#2b2440")], [Rect2(1, -3, 4, 3), Color("#2b2440")],
		[Rect2(-4, -15, 3, 12), Color("#f3ead9")], [Rect2(1, -15, 3, 12), Color("#f3ead9")],
		[Rect2(-7, -30, 14, 17), coat], [Rect2(-7, -14, 4, 6), coat], [Rect2(3, -14, 4, 6), coat],
		[Rect2(-2, -30, 4, 10), Color("#f3ead9")], [Rect2(-1, -28, 2, 1), gold], [Rect2(-1, -25, 2, 1), gold],
		[Rect2(-7, -30, 14, 2), gold.darkened(0.2)],
		[Rect2(-5, -39, 10, 9), skin], [Rect2(-5, -39, 10, 1), skin.lightened(0.2)],
		[Rect2(-7, -40, 14, 2), hat], [Rect2(-5, -46, 10, 6), hat], [Rect2(-5, -42, 10, 1), Color("#c9344a")],
		[Rect2(-3, -34, 7, 1), Color("#5a3a2a")], [Rect2(-5, -33, 3, 1), Color("#5a3a2a")], [Rect2(3, -33, 3, 1), Color("#5a3a2a")],
		[Rect2(-9, -29, 3, 11), coat], [Rect2(-9, -18, 3, 3), skin],
		# The arm and brass megaphone toward the stage.
		[Rect2(6, -30, 4, 3), coat], [Rect2(8, -33, 3, 4), skin],
		[Rect2(10, -35, 4, 6), brass], [Rect2(14, -36, 4, 8), brass], [Rect2(18, -38, 4, 12), brass], [Rect2(22, -39, 2, 14), brass.lightened(0.25)],
	]
	match look:
		"talk":
			blocks.append_array([[Rect2(-2, -37, 2, 2), ink], [Rect2(2, -37, 2, 2), ink], [Rect2(0, -32, 3, 2), Color("#7a1f2f")]])
		"sweat":
			blocks.append_array([[Rect2(-2, -37, 2, 1), ink], [Rect2(2, -37, 2, 1), ink], [Rect2(0, -32, 3, 1), ink], [Rect2(-6, -38, 1, 2), Color("#9fdcff")]])
		_:
			blocks.append_array([[Rect2(-2, -37, 2, 2), ink], [Rect2(2, -37, 2, 2), ink], [Rect2(-1, -32, 4, 1), Color("#c9344a")]])
	return blocks
