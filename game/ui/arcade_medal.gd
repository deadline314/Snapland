extends Control
## Pixel medal drawn in code: 0 none, 1 bronze, 2 silver, 3 gold.
## `paint` is shared by the arcade play view and the result card.

const NAMES: Array[String] = ["未得牌", "銅牌", "銀牌", "金牌"]
const FACES: Array[Color] = [Color("#5d6470"), Color("#d08a52"), Color("#d8dde6"), Color("#ffd166")]
const SHADES: Array[Color] = [Color("#3f4550"), Color("#8f5630"), Color("#8e98a8"), Color("#c98f2b")]
const RIBBON := Color("#e2506a")
const RIBBON_DARK := Color("#9c2f4a")
const OUTLINE := Color("#1b1626")
## The disc as rows of [first column, width] on a 12 x 12 grid.
const DISC: Array[Vector2i] = [Vector2i(4, 4), Vector2i(2, 8), Vector2i(1, 10), Vector2i(1, 10), Vector2i(0, 12), Vector2i(0, 12),
	Vector2i(0, 12), Vector2i(0, 12), Vector2i(1, 10), Vector2i(1, 10), Vector2i(2, 8), Vector2i(4, 4)]

var medal := 0:
	set(value):
		medal = clampi(value, 0, 3)
		queue_redraw()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var unit := maxf(1.0, floorf(minf(size.x / 14.0, size.y / 20.0)))
	paint(self, Vector2(size.x * 0.5, floorf((size.y - 20.0 * unit) * 0.5) + 14.0 * unit), unit, medal)


## Paint a medal whose disc centre is `center`; one art pixel is `unit` screen pixels.
## `lit` false draws the unearned silhouette used on progress strips.
static func paint(canvas: CanvasItem, center: Vector2, unit: float, kind: int, lit := true) -> void:
	kind = clampi(kind, 0, 3)
	# An unearned medal keeps a dim hint of its metal so the goal lines read early.
	var face: Color = FACES[kind] if lit else FACES[kind].darkened(0.5)
	var shade: Color = SHADES[kind] if lit else SHADES[kind].darkened(0.5)
	var origin := (center - Vector2(6, 6) * unit).floor()
	if kind > 0:
		for side: float in [-1.0, 1.0]:
			var x: float = origin.x + (6.0 + side * 2.0 - 1.5) * unit
			canvas.draw_rect(Rect2(x - unit, origin.y - 8.0 * unit, 5.0 * unit, 9.0 * unit), OUTLINE)
			canvas.draw_rect(Rect2(x, origin.y - 7.0 * unit, 3.0 * unit, 8.0 * unit), RIBBON if lit else RIBBON_DARK.darkened(0.45))
			canvas.draw_rect(Rect2(x + (2.0 if side > 0.0 else 0.0) * unit, origin.y - 7.0 * unit, unit, 8.0 * unit), RIBBON_DARK if lit else RIBBON_DARK.darkened(0.6))
	for row in DISC.size():
		var span := DISC[row]
		canvas.draw_rect(Rect2(origin + Vector2(span.x - 1, row) * unit, Vector2(span.y + 2, 1) * unit), OUTLINE)
	canvas.draw_rect(Rect2(origin + Vector2(4, -1) * unit, Vector2(4, 14) * unit), OUTLINE)
	for row in DISC.size():
		var span := DISC[row]
		canvas.draw_rect(Rect2(origin + Vector2(span.x, row) * unit, Vector2(span.y, 1) * unit), shade if row >= 9 else face)
	canvas.draw_rect(Rect2(origin + Vector2(3, 3) * unit, Vector2(6, 6) * unit), shade)
	canvas.draw_rect(Rect2(origin + Vector2(4, 2) * unit, Vector2(4, 8) * unit), shade)
	if kind == 0:
		# An empty slot: a dash instead of a star.
		canvas.draw_rect(Rect2(origin + Vector2(4, 5) * unit, Vector2(4, 2) * unit), face)
		return
	# A small star-like sparkle on the face.
	canvas.draw_rect(Rect2(origin + Vector2(5, 3) * unit, Vector2(2, 6) * unit), face)
	canvas.draw_rect(Rect2(origin + Vector2(3, 5) * unit, Vector2(6, 2) * unit), face)
	if lit:
		canvas.draw_rect(Rect2(origin + Vector2(2, 2) * unit, Vector2(2, 1) * unit), Color(1, 1, 1, 0.85))
		canvas.draw_rect(Rect2(origin + Vector2(2, 3) * unit, Vector2(1, 1) * unit), Color(1, 1, 1, 0.85))
