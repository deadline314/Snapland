extends Node
## Native review of 倒倒 on the part rig (ART-65): one still per move and a
## contact sheet of the dash at 30 frames a second, drawn at the arcade texel
## size over a reflected-avenue backdrop.
## python tools/run_native_capture.py res://game/tests/native_daodao_review.tscn --out build/daodao

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Daodao = preload("res://game/minigames/arcade/daodao_rig.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const TEXEL := 4.0
const STILLS := {"idle": 1.0, "dash": 0.62, "confetti": 0.5, "pose": 0.62, "shy": 0.4}
const SHEET_FRAMES := 36
const SHEET_COLUMNS := 9
const CELL := Vector2i(300, 256)

var rig: Rig
var stage: Rig.Stage
var preview: Preview


class Preview extends Control:
	var stage: SubViewport
	var drift := 0.0

	func _draw() -> void:
		# The reflected avenue: grass and flowerbeds above, a pale path, sky below.
		draw_rect(Rect2(0, 0, 1280, 300), Color("#a9dcf2"))
		for i in 7:
			draw_rect(Rect2(i * 190 - 30, 40 + (i % 3) * 22, 150, 26), Color("#e6f4fb"))
		draw_rect(Rect2(0, 300, 1280, 26), Color("#efe0b8"))
		draw_texture_rect(Pixels.surface("planks", Vector2i(80, 30), Color("#a8744a")), Rect2(0, 326, 1280, 120), false)
		draw_rect(Rect2(0, 446, 1280, 274), Color("#6fa9c9"))
		for i in 12:
			draw_rect(Rect2((i * 113) % 1280, 470 + (i * 37) % 230, 60, 4), Color("#a6d3ea"))
		draw_set_transform(Vector2(640, 600), 0.0, Vector2(1, 0.32))
		draw_circle(Vector2.ZERO, 110.0, Color(0.16, 0.08, 0.22, 0.3))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var size := Vector2(Daodao.STAGE) * TEXEL
		draw_texture_rect(stage.get_texture(), Rect2(Vector2(640 + drift, 600) - Daodao.ROOT * TEXEL, size), false)


func _ready() -> void:
	var out := OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("native_daodao_review needs a GPU window and SNAPLAND_CAPTURE_DIR")
		get_tree().quit(1)
		return
	rig = Daodao.build()
	stage = Rig.Stage.new(Daodao.STAGE, rig, Daodao.ROOT)
	preview = Preview.new()
	preview.size = Vector2(1280, 720)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.stage = stage
	preview.add_child(stage)
	add_child(preview)
	await _frames(4)
	for move: String in STILLS:
		var image := await _snap(move, STILLS[move], 7.0)
		image.save_png(out.path_join("daodao-%s.png" % move))
	await _sheet(out)


func _sheet(out: String) -> void:
	var sheet := Image.create(CELL.x * SHEET_COLUMNS, CELL.y * ceili(SHEET_FRAMES / float(SHEET_COLUMNS)), false, Image.FORMAT_RGB8)
	for i in SHEET_FRAMES:
		var t := 0.4 + i / 30.0
		var shot := await _snap("dash", t, 3.0 + t)
		var crop := shot.get_region(Rect2i(340, 200, 600, 512))
		crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % SHEET_COLUMNS) * CELL.x, (i / SHEET_COLUMNS) * CELL.y))
	sheet.save_png(out.path_join("daodao-dash-sheet.png"))
	print("PASS: daodao review saved %d stills and a %d-frame dash sheet" % [STILLS.size(), SHEET_FRAMES])
	get_tree().quit(0)


func _snap(move: String, t: float, clock: float) -> Image:
	stage.show_pose(rig.solve(move, t, clock))
	preview.queue_redraw()
	await _frames(2)
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
