extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 哈哈鏡大頭貼: the wanted card on its easel, the funhouse mirror
## with three sliding bands, and the sticker machine that prints every face,
## including the wonky ones.

const Faces = preload("res://game/minigames/arcade/funhouse_faces.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
const UNIT := 9.0
const GLASS := Rect2(424, 186, 432, 324)
## Screen distance between neighbouring parts on a band (24 art pixels).
const SPACING := 216.0
const FLOOR_TOP := 548.0
const CARD_CENTER := Vector2(196, 356)
const MACHINE := Rect2(962, 262, 236, 310)
const SLOT_Y := 408.0
const BAND_NAMES: Array[String] = ["髮型", "眼睛", "嘴巴"]
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#e3a53c")
const BRASS_DARK := Color("#a86a24")
const BRASS_LIGHT := Color("#ffe08a")
const STICKER_TINTS: Array[Color] = [Color("#ffc9d2"), Color("#ffc9d2"), Color("#cfeee6"), Color("#ffe9a8")]

var _has_tent := false


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.86, 0.82, 0.95))


func _init() -> void:
	super()
	word_anchor = Vector2(1080, 178)


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)


func _draw_scene() -> void:
	_draw_card()
	_draw_mirror()
	_draw_machine()
	_draw_drapes()


# --- Wanted card ------------------------------------------------------------

func _draw_card() -> void:
	ground_shadow(Vector2(CARD_CENTER.x, 598), Vector2(130, 16))
	for side: float in [-1.0, 1.0]:
		draw_set_transform(Vector2(CARD_CENTER.x + side * 26.0, 410), side * -0.16)
		draw_rect(Rect2(-9, 0, 18, 192), INK)
		draw_rect(Rect2(-6, 0, 12, 189), WOOD)
		draw_rect(Rect2(-6, 0, 4, 189), WOOD.lightened(0.18))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(CARD_CENTER.x - 124.0, 498, 248, 14), INK)
	draw_rect(Rect2(CARD_CENTER.x - 121.0, 501, 242, 8), WOOD.lightened(0.1))
	var flip := age(float(state.get("face_at", 0.0)))
	var hidden := bool(state.get("target_hidden", false))
	# A new wanted face swings in; anticipation before each reveal.
	var swing := 0.0 if reduced_motion else 0.10 * (1.0 - smoothstep(0.0, 0.3, flip)) * cos(flip * 22.0)
	draw_set_transform(CARD_CENTER, -0.045 + swing, Vector2(pop_in(flip, 0.2), 1.0))
	var card := Rect2(-112, -150, 224, 296)
	draw_rect(card.grow(4.0), INK)
	draw_rect(card, CREAM)
	draw_rect(Rect2(card.position, Vector2(card.size.x, 4)), Color.WHITE)
	var photo := Rect2(-96, -134, 192, 216)
	draw_rect(photo, Color("#b8e3dc") if not hidden else Color("#3a2433"))
	if hidden:
		for stripe in 6:
			draw_rect(Rect2(photo.position.x, photo.position.y + 12.0 + stripe * 36.0, photo.size.x, 14), Color("#4a2f44"))
		draw_set_transform(Vector2.ZERO)
		label(CARD_CENTER + Vector2(0, -26), "？", 110, GOLD)
		label(CARD_CENTER + Vector2(0, 112), "靠記憶！", 24, ROSE)
	else:
		Faces.draw_face(self, photo.position, 6.0, state.get("target", []))
		var active := int(state.get("stopped", 0))
		if active < 3 and float(state.get("printing", 0.0)) <= 0.0:
			# Mark the band being stopped right now, on the card and in the mirror.
			var rows := Faces.BAND_ROWS[active]
			var nudge := 5.0 * pulse(2.2)
			var y := photo.position.y + (rows.x + rows.y * 0.5) * 6.0
			_arrow(Vector2(photo.position.x - 16.0 + nudge, y), 1.0, GOLD)
		draw_set_transform(Vector2.ZERO)
		label(CARD_CENTER + Vector2(-4, 112), "拼出這張臉", 24, INK, 1.0, 1.0, false)
	draw_set_transform(CARD_CENTER, -0.045)
	draw_rect(Rect2(-12, -160, 24, 22), INK)
	draw_rect(Rect2(-9, -157, 18, 16), ROSE)
	draw_set_transform(Vector2.ZERO)


# --- Mirror -----------------------------------------------------------------

func _draw_mirror() -> void:
	var frame := GLASS.grow(26.0)
	ground_shadow(Vector2(640, 600), Vector2(310, 24), 0.4)
	for side: float in [-1.0, 1.0]:
		var x := 640.0 + side * 196.0
		draw_rect(Rect2(x - 17.0, frame.end.y - 6.0, 34, 62), INK)
		draw_rect(Rect2(x - 14.0, frame.end.y - 6.0, 28, 59), BRASS_DARK)
		draw_rect(Rect2(x - 14.0, frame.end.y - 6.0, 8, 59), BRASS)
		draw_rect(Rect2(x - 34.0, frame.end.y + 50.0, 68, 16), INK)
		draw_rect(Rect2(x - 31.0, frame.end.y + 53.0, 62, 10), BRASS)
	draw_rect(frame.grow(4.0), INK)
	draw_rect(frame, BRASS)
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 5)), BRASS_LIGHT)
	draw_rect(Rect2(frame.position, Vector2(5, frame.size.y)), BRASS_LIGHT)
	draw_rect(Rect2(frame.position.x, frame.end.y - 7.0, frame.size.x, 7), BRASS_DARK)
	draw_rect(Rect2(frame.end.x - 6.0, frame.position.y, 6, frame.size.y), BRASS_DARK)
	_draw_bulbs(frame)
	draw_rect(GLASS.grow(5.0), INK)
	draw_rect(GLASS, Color("#a9dbe2"))
	draw_rect(Rect2(GLASS.position, Vector2(GLASS.size.x, 120)), Color("#c2ebee"))
	draw_rect(Rect2(GLASS.position.x, GLASS.end.y - 70.0, GLASS.size.x, 70), Color("#8fc8d6"))
	_draw_reflection()
	for streak: Array in [[36.0, 26.0], [84.0, 10.0]]:
		draw_colored_polygon(PackedVector2Array([
			GLASS.position + Vector2(streak[0], 0), GLASS.position + Vector2(streak[0] + streak[1], 0),
			GLASS.position + Vector2(streak[0] + streak[1] - 96.0, GLASS.size.y), GLASS.position + Vector2(streak[0] - 96.0, GLASS.size.y)]),
			Color(1, 1, 1, 0.13))
	var printing := float(state.get("printing", 0.0)) > 0.0
	var prints: Array = state.get("prints", [])
	if printing and not prints.is_empty():
		var shot := age(float(prints.back().at))
		if shot < 0.16 and not reduced_motion:
			draw_rect(GLASS, Color(1, 1, 1, 0.85 * (1.0 - shot / 0.16)))
	_draw_band_lamps(frame)


func _draw_bulbs(frame: Rect2) -> void:
	var chase := 0 if reduced_motion else int(now * 5.0)
	var index := 0
	for x in range(0, int(frame.size.x) - 20, 48):
		for y: float in [frame.position.y + 6.0, frame.end.y - 18.0]:
			_bulb(Vector2(frame.position.x + 16.0 + x, y), (index + chase) % 3 == 0)
		index += 1
	for y in range(52, int(frame.size.y) - 40, 48):
		for x: float in [frame.position.x + 6.0, frame.end.x - 18.0]:
			_bulb(Vector2(x, frame.position.y + y), (index + chase) % 3 == 0)
		index += 1


func _bulb(at: Vector2, lit: bool) -> void:
	if lit:
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(20, 20)), Color(1.0, 0.93, 0.6, 0.28))
	draw_rect(Rect2(at, Vector2(12, 12)), INK)
	draw_rect(Rect2(at + Vector2(2, 2), Vector2(8, 8)), Color("#fff3b0") if lit else BRASS_DARK)
	if lit:
		draw_rect(Rect2(at + Vector2(3, 3), Vector2(3, 3)), Color.WHITE)


func _draw_reflection() -> void:
	var sheet := Faces.atlas()
	var prints: Array = state.get("prints", [])
	var printing := float(state.get("printing", 0.0)) > 0.0 and not prints.is_empty()
	var stopped := int(state.get("stopped", 0))
	var center := GLASS.get_center()
	var stretch := Vector2.ONE
	if printing:
		var shown := age(float(prints.back().at))
		if int(prints.back().matched) == 3:
			stretch = squash(shown, 0.2, 0.5)
		elif int(prints.back().matched) <= 1:
			# The funhouse glass warps a wrong face wide, then tall.
			var wobble := 0.22 if reduced_motion else 0.3 * sin(shown * 9.0) * maxf(0.0, 1.0 - shown * 0.5)
			stretch = Vector2(1.0 + wobble, 1.0 - wobble * 0.8)
	draw_set_transform(center, 0.0, stretch)
	var origin := Vector2(-16, -18) * UNIT
	draw_texture_rect_region(sheet, Rect2(origin, Vector2(Faces.FACE_SIZE) * UNIT), Faces.head_region())
	draw_set_transform(Vector2.ZERO)
	var positions: Array = state.get("positions", [])
	var bands: Array = state.get("bands", [])
	var picked: Array = state.get("picked", [])
	var stop_at: Array = state.get("stop_at", [])
	for reel in [2, 1, 0]:
		if reel >= bands.size():
			continue
		var rows := Faces.BAND_ROWS[reel]
		var row_rect := Rect2(GLASS.position.x, GLASS.position.y + rows.x * UNIT, GLASS.size.x, rows.y * UNIT)
		if reel < stopped:
			var landed := age(float(stop_at[reel]))
			var band_center := row_rect.get_center()
			draw_set_transform(center + (band_center - center) * stretch, 0.0, squash(landed, 0.3) * stretch)
			draw_texture_rect_region(sheet, Rect2(Vector2(-16, -rows.y * 0.5) * UNIT, Vector2(32, rows.y) * UNIT), Faces.region(reel, int(picked[reel])))
			draw_set_transform(Vector2.ZERO)
			if landed < 0.14 and not reduced_motion:
				draw_rect(row_rect, Color(1, 1, 1, 0.5 * (1.0 - landed / 0.14)))
			continue
		var band: Array = bands[reel]
		var at := float(positions[reel])
		for index in range(floori(at) - 1, floori(at) + 3):
			var part := Rect2(center.x + (index - at) * SPACING - 16.0 * UNIT, row_rect.position.y, 32.0 * UNIT, row_rect.size.y)
			var seen := part.intersection(GLASS)
			if seen.size.x <= 0.0:
				continue
			var source := Faces.region(reel, int(band[posmod(index, band.size())]))
			source.position.x += (seen.position.x - part.position.x) / UNIT
			source.size.x = seen.size.x / UNIT
			draw_texture_rect_region(sheet, seen, source)
		if reel == stopped and not printing:
			draw_rect(row_rect.grow(-2.0), Color(GOLD, 0.55 + 0.35 * pulse(2.2)), false, 4.0)
	if printing and int(prints.back().matched) == 3:
		var shown := age(float(prints.back().at))
		for spark in 6:
			var angle := spark * TAU / 6.0 + shown * (0.0 if reduced_motion else 2.0)
			_sparkle(center + Vector2(cos(angle), sin(angle)) * (150.0 + 40.0 * minf(shown, 0.5)), 5.0 if spark % 2 == 0 else 3.0)


func _draw_band_lamps(frame: Rect2) -> void:
	var stopped := int(state.get("stopped", 0))
	var picked: Array = state.get("picked", [])
	var target: Array = state.get("target", [])
	var printing := float(state.get("printing", 0.0)) > 0.0
	for reel in 3:
		var rows := Faces.BAND_ROWS[reel]
		var y := GLASS.position.y + (rows.x + rows.y * 0.5) * UNIT
		var lamp := Vector2(frame.position.x - 44.0, y)
		draw_rect(Rect2(lamp - Vector2(22, 22), Vector2(44, 44)), INK)
		draw_rect(Rect2(lamp - Vector2(18, 18), Vector2(36, 36)), Color("#3a2433"))
		if reel < stopped and reel < picked.size():
			var hit := int(picked[reel]) == int(target[reel])
			var bump := squash(age(float(state.stop_at[reel])), 0.4)
			draw_set_transform(lamp, 0.0, bump)
			draw_rect(Rect2(-18, -18, 36, 36), MINT if hit else ROSE)
			if hit:
				draw_polyline(PackedVector2Array([Vector2(-10, 0), Vector2(-3, 8), Vector2(11, -8)]), INK, 5.0)
			else:
				draw_line(Vector2(-9, -9), Vector2(9, 9), INK, 5.0)
				draw_line(Vector2(9, -9), Vector2(-9, 9), INK, 5.0)
			draw_set_transform(Vector2.ZERO)
		elif reel == stopped and not printing:
			_arrow(lamp + Vector2(-4.0 + 6.0 * pulse(2.2), 0), 1.0, GOLD)
		else:
			draw_rect(Rect2(lamp - Vector2(5, 5), Vector2(10, 10)), Color("#6b5a70"))
		label(Vector2(frame.end.x + 40.0, y), BAND_NAMES[reel], 18, GOLD if reel == stopped and not printing else Color("#c9bfd6"))


# --- Sticker machine --------------------------------------------------------

func _draw_machine() -> void:
	var prints: Array = state.get("prints", [])
	var newest: Dictionary = prints.back() if not prints.is_empty() else {}
	var since := age(float(newest.get("at", -99.0)))
	var wonky := int(newest.get("matched", 3)) <= 1
	# The cabinet shudders just before a sticker appears.
	var shudder := Vector2.ZERO
	if not reduced_motion and since >= 0.0 and since < (0.5 if wonky else 0.16):
		shudder = Vector2(sin(since * 90.0) * 3.0, 0)
	var body := Rect2(MACHINE.position + shudder, MACHINE.size)
	ground_shadow(Vector2(MACHINE.get_center().x, 600), Vector2(160, 18), 0.4)
	for x: float in [body.position.x + 16.0, body.end.x - 40.0]:
		draw_rect(Rect2(x, body.end.y - 4.0, 24, 30), INK)
	draw_rect(body.grow(4.0), INK)
	draw_rect(body, Color("#b8405c"))
	draw_rect(Rect2(body.position.x, SLOT_Y + 8.0, body.size.x, body.end.y - SLOT_Y - 8.0), Color("#8f2f49"))
	# Older stickers pile up in the tray.
	for index in range(maxi(0, prints.size() - 4), prints.size() - 1):
		var slot := index - maxi(0, prints.size() - 4)
		var tilt := -0.3 + fmod(float(prints[index].at) * 7.3, 0.6)
		_draw_sticker(Vector2(1010.0 + slot * 58.0, 628.0 + fmod(float(prints[index].at) * 3.1, 14.0)), 1.6, tilt, prints[index], false)
	if not newest.is_empty():
		# A clean print glides out; a wonky one judders out a notch at a time.
		var travel := clampf((since - 0.12) / 0.4, 0.0, 1.0)
		if wonky:
			travel = clampf((since - 0.45) / 0.9, 0.0, 1.0)
			if not reduced_motion:
				travel = floorf(travel * 6.0) / 6.0 + 0.02 * sin(since * 40.0)
		if reduced_motion:
			travel = 1.0
		var hang := 0.0 if reduced_motion or wonky else 0.05 * sin(since * 5.0) * maxf(0.0, 1.0 - since)
		_draw_sticker(Vector2(MACHINE.get_center().x, SLOT_Y - 84.0 + 172.0 * travel), 3.0, (0.12 if wonky else 0.0) + hang, newest, true)
	# Upper cabinet goes on last so the sticker slides out from behind it.
	var upper := Rect2(body.position, Vector2(body.size.x, SLOT_Y - body.position.y))
	draw_rect(upper, Color("#d9566f"))
	draw_rect(Rect2(upper.position, Vector2(upper.size.x, 5)), Color("#f28ba0"))
	draw_rect(Rect2(upper.position, Vector2(6, upper.size.y)), Color("#f28ba0"))
	draw_rect(Rect2(upper.end.x - 8.0, upper.position.y, 8, upper.size.y), Color("#a83a56"))
	draw_rect(Rect2(body.position.x + 42.0, SLOT_Y - 8.0, body.size.x - 84.0, 16), INK)
	var lens := upper.get_center() + Vector2(-34, 8)
	draw_circle(lens, 44.0, INK)
	draw_circle(lens, 39.0, BRASS)
	draw_circle(lens, 30.0, Color("#241b33"))
	draw_circle(lens, 20.0, Color("#3d6ea8"))
	draw_circle(lens + Vector2(-8, -8), 6.0, Color("#bfe4ff"))
	var bulb := upper.get_center() + Vector2(64, -6)
	var flash := since >= 0.0 and since < 0.14 and not reduced_motion
	draw_rect(Rect2(bulb - Vector2(22, 22), Vector2(44, 44)), INK)
	draw_rect(Rect2(bulb - Vector2(18, 18), Vector2(36, 36)), Color.WHITE if flash else Color("#ffe9a8"))
	if flash:
		draw_circle(bulb, 70.0, Color(1, 1, 1, 0.35))
	var sign_plate := Rect2(body.position.x + 28.0, body.position.y - 40.0, body.size.x - 56.0, 44)
	plate(sign_plate, Color("#3a2433"), Color("#241726"))
	label(sign_plate.get_center() + Vector2(0, -3), "大頭貼機", 22, GOLD)


## A photo sticker centred on `center`; one art pixel is `unit` screen pixels.
func _draw_sticker(center: Vector2, unit: float, tilt: float, print_data: Dictionary, stamped: bool) -> void:
	var matched := int(print_data.get("matched", 0))
	var paper := Vector2(40, 46) * unit
	draw_set_transform(center + Vector2(4, 5), tilt)
	draw_rect(Rect2(-paper * 0.5, paper), Color(0, 0, 0, 0.28))
	draw_set_transform(center, tilt)
	draw_rect(Rect2(-paper * 0.5 - Vector2(2, 2), paper + Vector2(4, 4)), INK)
	draw_rect(Rect2(-paper * 0.5, paper), Color.WHITE)
	var photo := Rect2(Vector2(-18, -21) * unit, Vector2(36, 36) * unit)
	draw_rect(photo, STICKER_TINTS[matched])
	if matched <= 1:
		# Funhouse stretch: the wrong face comes out wide and squat.
		draw_set_transform_matrix(Transform2D(tilt, center) * Transform2D(0.0, Vector2(1.14, 0.8), 0.0, Vector2(0, 2.6 * unit)))
	Faces.draw_face(self, Vector2(-16, -21) * unit, unit, print_data.get("parts", []))
	draw_set_transform(center, tilt)
	if matched == 3:
		_sparkle(Vector2(13, -17) * unit, unit * 1.4)
	draw_set_transform(Vector2.ZERO)
	if stamped and age(float(print_data.get("at", 0.0))) > 0.3:
		var stamp := "完美" if matched == 3 else ("差一格" if matched == 2 else "怪臉")
		var ink: Color = Color("#b8791c") if matched == 3 else (Color("#1f8a72") if matched == 2 else Color("#c7334a"))
		label(center + Vector2(0, 19.0 * unit).rotated(tilt), stamp, 20, ink, 1.0, 1.0, false)


# --- Foreground and small shapes --------------------------------------------

func _draw_drapes() -> void:
	for side in [0, 1]:
		var left := 0.0 if side == 0 else 1280.0 - 54.0
		for fold in 3:
			draw_rect(Rect2(left + fold * 18.0, PLAY_TOP - 4.0, 18, 720.0 - PLAY_TOP), Color("#5a2038") if fold % 2 == 0 else Color("#7a2c48"))
		var inner := left + 54.0 if side == 0 else left - 5.0
		draw_rect(Rect2(inner, PLAY_TOP - 4.0, 5, 720.0 - PLAY_TOP), Color(0.05, 0.02, 0.09, 0.45))
		draw_rect(Rect2(left, 470, 54, 16), BRASS)
		draw_rect(Rect2(left, 482, 54, 4), BRASS_DARK)


func _arrow(tip: Vector2, facing: float, color: Color) -> void:
	for column in 5:
		var half := 10.0 - column * 2.0
		draw_rect(Rect2(tip.x - facing * (14.0 - column * 4.0) - 2.0, tip.y - half - 2.0, 8, half * 2.0 + 4.0), INK)
	for column in 5:
		var half := 10.0 - column * 2.0
		draw_rect(Rect2(tip.x - facing * (14.0 - column * 4.0), tip.y - half, 4, half * 2.0), color)


func _sparkle(at: Vector2, arm: float) -> void:
	draw_rect(Rect2(at - Vector2(arm * 0.4, arm * 2.0), Vector2(arm * 0.8, arm * 4.0)), GOLD)
	draw_rect(Rect2(at - Vector2(arm * 2.0, arm * 0.4), Vector2(arm * 4.0, arm * 0.8)), GOLD)
	draw_rect(Rect2(at - Vector2(arm * 0.4, arm * 0.4), Vector2(arm * 0.8, arm * 0.8)), Color.WHITE)
