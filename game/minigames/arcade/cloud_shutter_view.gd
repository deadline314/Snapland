extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 雲影快門: the cloud-top photo deck under the sky park's shared
## backdrop (sky_backdrop.gd). In the foreground stand the white picket rail,
## swaying bunting and the park's giant wooden photo frame; the island
## traveller stands with their back to us at a camera on a tripod. Up in the
## viewfinder brackets a big puffy cloud (outlined, shaded, with its shadow on
## the cloud sea) melts from shape to shape, and a sign calls the shape to catch
## with its silhouette. Each picture flashes and slides out as a little print;
## a wrong one turns the cloud into the traveller's own head poking its tongue out.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
const Driver = preload("res://game/minigames/arcade/cloud_shutter_driver.gd")
const BOX := Rect2(470, 172, 340, 340)
const DECK_Y := 650.0
const RAIL_Y := 600.0
const HERO_FEET := Vector2(300, 654)
const HERO_SCALE := 3.0
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const WHITE := Color("#fbfdff")
const CLOUD_SHADE := Color("#c9d6ee")
const NAVY := Color("#2f4a7a")
const CORAL := Color("#ff8a6b")
const SUN := Color("#ffd35c")
const MINT_FLAG := Color("#8fe0c4")
const LILAC := Color("#b9a9f0")
const TONGUE := Color("#ff7fa0")
const INK_DARK := Color("#241c34")
const NOON := Color(1.0, 0.99, 0.96)


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)


# --- Backdrop ------------------------------------------------------------------

func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)
	_draw_frame_prop()
	_draw_rail()
	stage_floor(DECK_Y, WOOD, DARK_WOOD)
	vignette(0.3)


## The park's giant photo frame standing on the deck, lit from the upper left.
func _draw_frame_prop() -> void:
	var outer := Rect2(930, 300, 260, 320)
	ground_shadow(Vector2(outer.get_center().x + 20, DECK_Y + 4), Vector2(150, 14), 0.4)
	draw_rect(Rect2(outer.position + Vector2(14, 16), outer.size), Color(SPRITE_SHADE, 0.25))
	gilt_frame(outer, 22.0, WOOD, TEXEL, NOON)
	label(Vector2(outer.get_center().x, outer.end.y - 10), "雲上拍照點", 18, DARK_WOOD.darkened(0.3), 1.0, 1.0, false)
	for leg: float in [outer.position.x + 40, outer.end.x - 40]:
		draw_rect(Rect2(leg - 8, outer.end.y - 4, 16, DECK_Y - outer.end.y + 6), DARK_WOOD)


func _draw_rail() -> void:
	panel(Rect2(-8, RAIL_Y - 8.0, DESIGN.x + 16.0, 12), "planks", Color("#efe6da"), Color(0, 0, 0, 0), TEXEL, NOON)
	for picket in 32:
		var x := 10.0 + picket * 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, RAIL_Y - 22), Vector2(x + 8, RAIL_Y - 30), Vector2(x + 16, RAIL_Y - 22), Vector2(x + 16, DECK_Y), Vector2(x, DECK_Y)]), Color("#d8cfc4"))
		draw_rect(Rect2(x + 2, RAIL_Y - 22, 6, DECK_Y - RAIL_Y + 22), Color("#f4ece2"))
	# Bunting strung along the rail, swaying a little.
	for flag in 30:
		var sway := 0.0 if reduced_motion else sin(now * 2.0 + flag * 0.7) * 3.0
		var a := Vector2(10.0 + flag * 43.0, RAIL_Y - 44.0 + sin(flag * 0.9) * 5.0)
		var tone: Color = [CORAL, SUN, MINT_FLAG, LILAC, WHITE][flag % 5]
		draw_colored_polygon(PackedVector2Array([a, a + Vector2(22, 0), a + Vector2(11 + sway, 20)]), tone.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([a + Vector2(2, 1), a + Vector2(20, 1), a + Vector2(11 + sway, 16)]), tone)
	draw_line(Vector2(0, RAIL_Y - 44), Vector2(DESIGN.x, RAIL_Y - 44), Color(NAVY, 0.4), 2.0)


# --- Play ----------------------------------------------------------------------

func _draw_scene() -> void:
	if not state.has("blobs"):
		return
	_draw_viewfinder()
	_draw_cloud(state.blobs, BOX, 1.0, true)
	_draw_face()
	_draw_call()
	_draw_camera_and_hero()
	_draw_flash_and_print()
	_draw_streak()


func _face_since() -> float:
	var since := age(float(state.get("face_at", -99.0)))
	return since if since >= 0.0 and since < float(state.get("face_seconds", 1.4)) else -1.0


func _draw_viewfinder() -> void:
	# White corner brackets and a faint focus cross around the cloud.
	var frame := BOX.grow(26.0)
	var ready := str(state.get("to_name", "")) == str(state.get("target", "")) and float(state.get("formed", 0.0)) >= Driver.FORMED
	var tone := SUN if ready else WHITE
	for corner in 4:
		var at := Vector2(frame.position.x if corner % 2 == 0 else frame.end.x, frame.position.y if corner < 2 else frame.end.y)
		var dir := Vector2(1 if corner % 2 == 0 else -1, 1 if corner < 2 else -1)
		for pass_index in 2:
			var width := 7.0 if pass_index == 0 else 4.0
			var color := Color(NAVY, 0.5) if pass_index == 0 else tone
			draw_line(at, at + Vector2(dir.x * 44, 0), color, width)
			draw_line(at, at + Vector2(0, dir.y * 44), color, width)
	var centre := BOX.get_center()
	draw_line(centre - Vector2(14, 0), centre + Vector2(14, 0), Color(WHITE, 0.35), 2.0)
	draw_line(centre - Vector2(0, 14), centre + Vector2(0, 14), Color(WHITE, 0.35), 2.0)


## A puffy cloud from its blobs inside `box`: outline, shaded underside, lit
## top and, for the big one, its soft shadow on the cloud sea below.
func _draw_cloud(blobs: Array, box: Rect2, scale_factor: float, shadowed: bool) -> void:
	var side := minf(box.size.x, box.size.y)
	var points: Array = []
	for index in blobs.size():
		var blob: Vector3 = blobs[index]
		var wobble := 0.0 if reduced_motion or not shadowed else sin(now * 1.6 + index * 1.3) * 0.006
		points.append(Vector3(box.position.x + blob.x * side, box.position.y + blob.y * side, maxf(2.0, (blob.z + wobble) * side)))
	if shadowed:
		var low := box.end.y + 40.0
		for point: Vector3 in points:
			draw_set_transform(Vector2(point.x + 30.0, low), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, point.z * 1.1, Color(NAVY, 0.07))
			draw_set_transform(Vector2.ZERO)
	var edge := 4.0 * scale_factor
	for point: Vector3 in points:
		draw_circle(Vector2(point.x, point.y), point.z + edge, Color(NAVY, 0.45))
	for point: Vector3 in points:
		draw_circle(Vector2(point.x + 3.0, point.y + 7.0 * scale_factor), point.z, CLOUD_SHADE)
	for point: Vector3 in points:
		draw_circle(Vector2(point.x, point.y), point.z * 0.92, WHITE)
	for point: Vector3 in points:
		draw_circle(Vector2(point.x - point.z * 0.25, point.y - point.z * 0.3), point.z * 0.5, Color(1.0, 1.0, 0.97))


func _draw_face() -> void:
	# The traveller's own head in cloud, eyes squeezed and tongue out.
	var since := _face_since()
	if since < 0.25:
		return
	var side := BOX.size.x
	var centre := BOX.position + Vector2(0.5, 0.56) * side
	for eye: float in [-1.0, 1.0]:
		var at := centre + Vector2(eye * 40.0, -18.0)
		draw_line(at + Vector2(-10, -6), at + Vector2(8, 0), INK_DARK, 5.0)
		draw_line(at + Vector2(-10, 6), at + Vector2(8, 0), INK_DARK, 5.0)
	var wag := 0.0 if reduced_motion else sin(now * 12.0) * 6.0
	draw_circle(centre + Vector2(0, 40), 18.0, INK_DARK)
	draw_circle(centre + Vector2(wag, 64), 18.0, TONGUE.darkened(0.2))
	draw_circle(centre + Vector2(wag, 60), 15.0, TONGUE)
	draw_line(centre + Vector2(wag, 52), centre + Vector2(wag, 70), TONGUE.darkened(0.25), 3.0)
	for cheek: float in [-1.0, 1.0]:
		draw_circle(centre + Vector2(cheek * 70.0, 18.0), 12.0, Color(CORAL, 0.35))


func _draw_call() -> void:
	# A hanging sign calling the shape, with its silhouette; it bobs on its ropes.
	var bob := 0.0 if reduced_motion else sin(now * 1.4) * 3.0
	var board := Rect2(56, 196 + bob, 260, 150)
	draw_line(Vector2(board.position.x + 30, 150), board.position + Vector2(30, 0), DARK_WOOD, 3.0)
	draw_line(Vector2(board.end.x - 30, 150), Vector2(board.end.x - 30, board.position.y), DARK_WOOD, 3.0)
	draw_rect(Rect2(board.position + Vector2(8, 10), board.size), Color(SPRITE_SHADE, 0.3))
	panel(board, "planks", Color("#f4ece2"), CORAL, TEXEL, NOON)
	var fresh := age(float(state.get("called_at", -99.0)))
	var grow := 1.0 + (0.2 * (1.0 - fresh / 0.35) if fresh >= 0.0 and fresh < 0.35 and not reduced_motion else 0.0)
	label(board.position + Vector2(80, 44), "拍！", 26, CORAL)
	label(board.position + Vector2(80, 100), str(state.get("target_label", "")), 32, NAVY, grow)
	var icon := Rect2(board.position + Vector2(146, 22), Vector2(104, 104))
	var silhouette: Array = Driver.SHAPES.get(str(state.get("target", "rabbit")), [])
	for blob: Vector3 in silhouette:
		draw_circle(icon.position + Vector2(blob.x, blob.y) * icon.size.x, blob.z * icon.size.x + 2.5, NAVY)
	for blob: Vector3 in silhouette:
		draw_circle(icon.position + Vector2(blob.x, blob.y) * icon.size.x, blob.z * icon.size.x, Color("#5b7bb0"))


func _draw_camera_and_hero() -> void:
	var shot := age(float(state.get("shot_at", -99.0)))
	var face := _face_since()
	# The tripod and camera, pointed up at the cloud.
	var head := HERO_FEET + Vector2(70, -150)
	ground_shadow(HERO_FEET + Vector2(70, 2), Vector2(48, 10), 0.35)
	for leg: float in [-30.0, 0.0, 30.0]:
		draw_line(head + Vector2(0, 20), HERO_FEET + Vector2(70 + leg, 0), DARK_WOOD.darkened(0.2), 7.0)
		draw_line(head + Vector2(0, 20), HERO_FEET + Vector2(70 + leg, 0), WOOD, 3.0)
	draw_set_transform(head, -0.35, Vector2.ONE)
	draw_rect(Rect2(-40, -26, 80, 52), INK_DARK)
	draw_rect(Rect2(-36, -22, 72, 44), Color("#3d3f52"))
	draw_rect(Rect2(-36, -22, 72, 10), Color("#5a5d78"))
	draw_rect(Rect2(-20, -36, 26, 12), Color("#3d3f52"))
	draw_circle(Vector2(30, 0), 22.0, INK_DARK)
	draw_circle(Vector2(30, 0), 17.0, Color("#6f86b8"))
	draw_circle(Vector2(25, -5), 6.0, Color(WHITE, 0.8))
	if shot >= 0.0 and shot < 0.12:
		draw_circle(Vector2(30, 0), 30.0, Color(WHITE, 0.9))
	draw_set_transform(Vector2.ZERO)
	var mood := "shocked" if face >= 0.0 else ("tongue" if int(state.get("streak", 0)) >= 4 else "plain")
	ground_shadow(HERO_FEET + Vector2(0, 2), Vector2(54, 12), 0.42)
	var bob := 0.0 if reduced_motion else sin(now * 2.0) * 1.5
	stamp(Hero.texture(&"right", false, mood), HERO_FEET + Vector2(0, bob) - Vector2(20, 46) * HERO_SCALE, HERO_SCALE, NOON)


func _draw_flash_and_print() -> void:
	var shot := age(float(state.get("shot_at", -99.0)))
	if shot < 0.0 or shot > 2.2:
		return
	if shot < 0.25 and not reduced_motion:
		draw_rect(Rect2(BOX.grow(30.0)), Color(WHITE, 0.6 * (1.0 - shot / 0.25)))
	# The print slides out of the camera and settles beside it.
	var slide := smoothstep(0.0, 0.5, shot)
	var fade := 1.0 - smoothstep(1.7, 2.2, shot)
	var card := Rect2(Vector2(330, 520).lerp(Vector2(340, 380), slide), Vector2(120, 140))
	draw_rect(Rect2(card.position + Vector2(6, 8), card.size), Color(SPRITE_SHADE, 0.3 * fade))
	draw_rect(card, Color(WHITE, fade))
	draw_rect(Rect2(card.position + Vector2(10, 10), Vector2(100, 96)), Color(Color("#9cc8ec"), fade))
	var shape: Array = Driver.SHAPES.get(str(state.get("shot_shape", "")), [])
	if not shape.is_empty() and fade > 0.5:
		_draw_cloud(shape, Rect2(card.position + Vector2(12, 8), Vector2(96, 96)), 0.3, false)
	var hit := bool(state.get("shot_hit", false))
	label(card.position + Vector2(60, 122), str(state.get("shot_label", "")) if hit else "略～", 18, NAVY if hit else CORAL, 1.0, fade, false)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(1120, 250), "連拍 × %d" % streak, 26, SUN, 1.0 + 0.08 * pulse(2.0))
