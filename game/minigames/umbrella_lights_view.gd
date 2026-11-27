extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/umbrella_lights_model.gd")
const ART := "res://assets/minigames/umbrella-lights-night-shop.webp"
const BOARD := Rect2(35, 187, 847, 328)
const READOUT := Rect2(900, 187, 345, 328)
const SCREEN := Rect2(550, 223, 298, 256)
const FLOWER := Vector2(699, 354)
const HUB := Vector2(285, 354)
const RADIUS := 136.0
const FORESHORTEN := 0.74
const GOLD := Color("#ffcf85")
const INK := Color("#fff0da")
const PALE := Color("#c4c7c5")
const DEEP := Color("#211e2c")
const FRAME := Color("#857068")
const UMBER := Color("#5f3e3c")
const RIB_LIGHT := Color("#d7a477")
const MINT := Color("#a4e1cb")
const CORAL := Color("#ffad9b")
const NIGHT_TINTS := {
	"dawn": Color("#e5c7b7"), "noon": Color("#e6e0d4"), "dusk": Color("#ddc3cd"), "night": Color("#d1c5da"),
}
## Lacquered shop wood for the boards, oiled paper for the canopy, a red hem.
const LACQUER := Color("#3f2726")
const OILED_PAPER := Color("#e9c48e")
const HEM := Color("#a8442f")
const PETAL_TONES := [Color("#ffd695"), Color("#ffbc85"), Color("#fdddad"), Color("#f7b991")]

enum { LEFT, RIGHT, BRAKE, DETENT }

const LABELS := ["逆時針 · A", "順時針 · D", "按住煞車 · 空白", "逐格模式 · F"]
const KEY_ICONS := ["turn_left", "turn_right", "stop", "swap"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
const NAMES := ["UmbrellaLeft", "UmbrellaRight", "UmbrellaBrake", "UmbrellaDetent"]
const HINTS := [
	"按住逆時針轉傘", "按住順時針轉傘", "留白拍要先轉傘，再按住煞停", "輔助可切換每次轉一格",
]

var _state: Dictionary = {}
var _backdrop: Texture2D
var _phase := "night"
var _reduced_motion := false
var _last_paint: Array = []
var _last_controls: Array = []
var _font_style := ""
var _locale := ""
var _flower_leaves: Array[PackedVector2Array] = []


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.get("ended", true):
		return false
	if action == DETENT:
		return state.get("assisted", false)
	return action >= LEFT and action <= BRAKE


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	build_controls(LABELS, Color("#343544"), Color("#644d40"), FRAME, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	use_key_caps(KEY_ICONS, KEY_TONE)
	if ResourceLoader.exists(ART):
		_backdrop = load(ART) as Texture2D
	for index in Model.PETAL_COUNT:
		var ray := Vector2.UP.rotated(TAU * float(index) / float(Model.PETAL_COUNT))
		_flower_leaves.append(_leaf(FLOWER + ray * 15.0, ray, 71.0, 26.0))
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	if READOUT.has_point(point) and not _state.is_empty():
		return _status() + "\n實線是掃燈、虛線是預告；外圈雙短線是煞停位置。"
	var slot := hit_slot(point)
	if slot == DETENT and not _state.get("assisted", false):
		return "開啟本回合輔助後可用逐格"
	return HINTS[slot] if slot >= 0 and slot < HINTS.size() else ""


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	_state = state
	_reduced_motion = reduced_motion
	_phase = phase if NIGHT_TINTS.has(phase) else "night"
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	var typography_changed := _scale != Paper.text_scale() or _font_style != Paper.font_style() or _locale != TranslationServer.get_locale()
	if typography_changed:
		refresh_font()
		_font_style = Paper.font_style()
		_locale = TranslationServer.get_locale()
	_refresh_controls()
	if _state.is_empty():
		if not _last_paint.is_empty():
			_last_paint.clear()
			queue_redraw()
		return
	var paint := [
		_state.layout, _state.phase_index, _state.live, _state.ended, _state.center_proven,
		_state.petal_mask, _state.blank_mask, _state.phase_results, _state.braking, _state.brake_armed,
		_state.brake_slowed, snappedf(_state.angle, 0.003), snappedf(_state.beam_heading, 0.003),
		snappedf(_state.guide_heading, 0.003),
		_state.rib_half_width, _state.petal_half_width, snappedf(_state.phase_progress, 0.01),
		snappedf(_state.open_fraction, 0.025),
		snappedf(_state.target_overlap, 0.025), snappedf(_dose_ratio(), 0.01),
		ceili(float(_state.seconds_to_sweep) * 10.0), _reduced_motion, _phase,
	]
	if _state.kind == Model.BLANK and not _state.live:
		paint.append(_state.brake_ready)
		paint.append(snappedf(_state.stop_heading, 0.003))
	if paint != _last_paint or typography_changed:
		_last_paint = paint
		queue_redraw()


func _refresh_controls() -> void:
	var mask: int = _state.get("control_mask", 0)
	var detent: bool = _state.get("detent_mode", false)
	var controls := [mask, detent, _state.get("assisted", false), _state.get("ended", true)]
	if controls == _last_controls:
		return
	_last_controls = controls
	for index in _buttons.size():
		var button := _buttons[index]
		button.disabled = not action_available(index, _state)
		var pressed := (index == DETENT and detent) or bool(mask & (1 << index))
		button.set_pressed_no_signal(pressed and not button.disabled)
	_buttons[DETENT].text = "已開逐格 · F" if detent else LABELS[DETENT]


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(35, 172), _guide(), GOLD, 22, BOARD.size.x)
	_draw_workbench()
	_draw_timing_arc()
	_draw_umbrella()
	_draw_lantern()
	_draw_projection()
	_draw_readout()
	_draw_sequence()


func _guide() -> String:
	if _state.ended:
		return "光紋結束"
	if _state.kind == Model.PETAL:
		return "跟著燈掃的方向轉傘" if _state.live else "金針對準空心角標，再跟燈轉"
	if _state.brake_armed:
		return "按住煞車，讓雙紋傘骨留住暗面"
	if _state.braking and not _state.live:
		return "鬆開煞車，轉向角標再煞停"
	if _ready_to_stop():
		return "停點已對準角標，現在按住煞車"
	return "留白拍 · 先轉向角標，再按住煞車"


func _draw_workbench() -> void:
	Props.wood_panel(self, BOARD.grow(8.0), LACQUER)
	draw_rect(BOARD, DEEP)
	if _backdrop != null:
		var original := _backdrop.get_size()
		var crop := original
		if original.aspect() < BOARD.size.aspect():
			crop.y = original.x / BOARD.size.aspect()
		else:
			crop.x = original.y * BOARD.size.aspect()
		draw_texture_rect_region(_backdrop, BOARD, Rect2((original - crop) * Vector2(0.5, 0.37), crop), NIGHT_TINTS[_phase])
	draw_rect(BOARD, Color(0.10, 0.08, 0.14, 0.25))
	Props.vignette(self, BOARD, 0.6, Color("#140c14"))


func _draw_timing_arc() -> void:
	if _state.ended:
		return
	var start: float = _state.beam_start
	var end: float = _state.beam_end
	var track := RADIUS + 25.0
	if _state.live:
		_arc(track, start, end, Color(PALE, 0.43), 1.5, 24)
		_arc(track, start, _state.beam_heading, GOLD, 2.1, 24)
	else:
		for index in 9:
			var from := lerpf(start, end, float(index) / 9.0)
			var to := lerpf(start, end, (float(index) + 0.54) / 9.0)
			_arc(track, from, to, Color(PALE, 0.64), 1.7, 3)
	var arrow := _rim(end, track)
	var delta := (_rim(end + 0.036 * float(_state.beam_direction), track) - arrow).normalized()
	draw_polyline(PackedVector2Array([arrow - delta * 8.0 + delta.orthogonal() * 4.6, arrow,
		arrow - delta * 8.0 - delta.orthogonal() * 4.6]), PALE, 1.7, true)
	var target_heading: float = _state.guide_heading
	var tip := _rim(target_heading, RADIUS + 2.0)
	var base := _rim(target_heading, RADIUS + 18.0)
	var lateral := (base - tip).normalized().orthogonal() * 5.5
	var outline := PackedVector2Array([tip, base + lateral, base - lateral, tip])
	draw_colored_polygon(PackedVector2Array([tip, base + lateral, base - lateral]), DEEP)
	draw_polyline(outline, INK, 2.0, true)
	if _state.kind == Model.BLANK and _state.brake_ready:
		var expected := _rim(_state.stop_heading, RADIUS + 25.0)
		var from_center := (expected - HUB).normalized()
		var tangent := from_center.orthogonal()
		var tint := MINT if _ready_to_stop() else PALE
		for shift in [-3.0, 3.0]:
			var at := expected + tangent * float(shift)
			draw_line(at - from_center * 2.6, at + from_center * 2.6, tint, 1.9, true)


func _draw_umbrella() -> void:
	draw_set_transform(HUB + Vector2(13, 31), 0.0, Vector2(1.0, 0.52))
	draw_circle(Vector2.ZERO, 146.0, Color(0.07, 0.055, 0.09, 0.66), true, -1.0, true)
	draw_circle(Vector2.ZERO, 124.0, Color(0.08, 0.05, 0.10, 0.45), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	var ribs: PackedFloat32Array = _state.rib_offsets
	var angle: float = _state.angle
	var fibre := Props.material_tile("paper", OILED_PAPER)
	for index in ribs.size():
		var start := angle + ribs[index]
		var finish := start + TAU / float(ribs.size())
		var paper := PackedVector2Array([HUB + Vector2(0, -7)])
		var seam := PackedVector2Array()
		var hem := PackedVector2Array()
		for step in 9:
			var portion := float(step) / 8.0
			var sag := 3.2 * sin(portion * PI)
			var at := _rim(lerpf(start, finish, portion), RADIUS - sag)
			paper.append(at)
			seam.append(at)
			hem.append(_rim(lerpf(start, finish, portion), RADIUS - 9.0 - sag))
		# Gores facing the top-left lamp are lit; the far ones sink into shade.
		var facing := 0.5 + 0.5 * cos((start + finish) * 0.5 + 2.2)
		var shade := Color(1, 1, 1).lerp(Color("#8a5a55"), 0.85 * (1.0 - facing))
		Props.fill_polygon(self, paper, fibre, shade)
		draw_polyline(hem, HEM * shade, 10.0, true)
		draw_polyline(hem, Color(Props.lighten(HEM, 0.3) * shade, 0.8), 1.6, true)
		_arc(RADIUS * 0.41, start + 0.03, finish - 0.03, Color(HEM * shade, 0.55), 3.0, 8)
		_arc(RADIUS * 0.66, start + 0.05, finish - 0.05, Color(Props.deepen(OILED_PAPER, 0.3), 0.22), 1.0, 8)
		draw_polyline(seam, Props.deepen(HEM, 0.5), 3.0, true)
	for index in ribs.size():
		var azimuth := angle + ribs[index]
		var tip := _rim(azimuth)
		draw_line(HUB + Vector2(0, -7), tip, Props.deepen(UMBER, 0.3), 4.4, true)
		draw_line(HUB + Vector2(0, -7), tip - Vector2(1, 1), RIB_LIGHT, 1.4, true)
		Props.token(self, tip, 4.0, Color("#b88a52"))
		if not _state.ended and _state.kind == Model.BLANK and index == _state.target:
			_draw_rib_mark(azimuth)
	_draw_optic_petals()
	var needle := _rim(angle, RADIUS - 2.0)
	var direction := (needle - HUB).normalized()
	var side := direction.orthogonal() * 4.3
	draw_colored_polygon(PackedVector2Array([needle + direction * 5.0, needle - direction * 10.0 + side, needle - direction * 10.0 - side]), DEEP)
	draw_colored_polygon(PackedVector2Array([needle + direction * 2.0, needle - direction * 7.0 + side * 0.72, needle - direction * 7.0 - side * 0.72]), GOLD)
	var spool := HUB + Vector2(0, -7)
	draw_circle(spool + Vector2(2, 4), 15.0, Color(Props.deepen(UMBER, 0.4), 0.7), true, -1.0, true)
	Props.token(self, spool, 14.0, Color("#a4703f"))
	Props.token(self, spool, 6.0, Color("#d8b46a"))


func _draw_rib_mark(azimuth: float) -> void:
	var half: float = _state.rib_half_width
	_arc(RADIUS - 7.0, azimuth - half, azimuth + half, DEEP, 9.0, 10)
	_arc(RADIUS - 4.0, azimuth - half, azimuth + half, INK, 1.9, 10)
	_arc(RADIUS - 10.0, azimuth - half, azimuth + half, INK, 1.9, 10)


func _draw_optic_petals() -> void:
	var offsets: PackedFloat32Array = _state.petal_offsets
	var half: float = _state.petal_half_width
	var angle: float = _state.angle
	for index in offsets.size():
		var mid := angle + offsets[index]
		var chosen: bool = not _state.ended and _state.kind == Model.PETAL and index == _state.target
		var rim_segments := PackedVector2Array()
		for step in 9:
			rim_segments.append(_rim(lerpf(mid - half, mid + half, float(step) / 8.0), RADIUS * 0.80))
		for step in range(8, -1, -1):
			rim_segments.append(_rim(lerpf(mid - half, mid + half, float(step) / 8.0), RADIUS * 0.66))
		# Cut windows: the dark shop shows through, the chosen one glows.
		draw_colored_polygon(rim_segments, Color("#ffd88cd0") if chosen else Color("#2a1a22c8"))
		rim_segments.append(rim_segments[0])
		draw_polyline(rim_segments, Props.deepen(HEM, 0.4), 3.4, true)
		draw_polyline(rim_segments, INK if chosen else Color("#e6b98a"), 1.6 if chosen else 1.0, true)
		var at := _rim(mid, RADIUS * 0.88)
		_text(at + Vector2(-5, 4.5), str(index + 1), DEEP, 12, 22.0)


func _draw_lantern() -> void:
	if _state.ended:
		return
	var heading: float = _state.beam_heading
	var half: float = _state.beam_half_width
	var outer := RADIUS + 25.0
	var bulb := _rim(heading, outer)
	var shaft := (bulb - HUB).normalized()
	var side := shaft.orthogonal() * 6.0
	var body := PackedVector2Array([bulb - shaft * 8.0 + side, bulb + shaft * 7.0 + side,
		bulb + shaft * 7.0 - side, bulb - shaft * 8.0 - side])
	var live: bool = _state.live
	var light := GOLD if live else PALE
	if live:
		var openness: float = _state.open_fraction
		var reaches := lerpf(RADIUS - 12.0, 37.0, openness)
		var spread := PackedVector2Array([_rim(heading - half, outer), _rim(heading + half, outer),
			_rim(heading + half, reaches), _rim(heading - half, reaches)])
		draw_colored_polygon(spread, Color(GOLD, 0.36 + openness * 0.23))
		_arc(RADIUS + 3.0, heading - half, heading + half, INK, 4.8, 9)
		if not _reduced_motion:
			draw_circle(bulb, 15.0, Color(GOLD, 0.16), true, -1.0, true)
	draw_colored_polygon(body, DEEP)
	body.append(body[0])
	draw_polyline(body, light, 2.5, true)
	draw_circle(bulb - shaft * 2.2, 3.4, light, true, -1.0, true)


func _draw_projection() -> void:
	Props.block_shadow(self, SCREEN.grow(8.0), Vector2(12, 14), 0.5)
	Props.wood_panel(self, SCREEN.grow(8.0), LACQUER)
	Props.surface(self, SCREEN, "photo", Color("#3e3040"))
	for x in [SCREEN.position.x + SCREEN.size.x / 3.0, SCREEN.position.x + SCREEN.size.x * 2.0 / 3.0]:
		draw_line(Vector2(x, SCREEN.position.y), Vector2(x, SCREEN.position.y + 222), Color(Props.deepen(LACQUER, 0.2), 0.45), 2.0)
	Props.wood_panel(self, Rect2(SCREEN.position.x, SCREEN.position.y + 222, SCREEN.size.x, 4), LACQUER)
	_text(Vector2(570, 252), "投影", INK, 18, 106.0)
	var lit_mask: int = _state.petal_mask
	for index in _flower_leaves.size():
		var leaf := _flower_leaves[index]
		var lit := bool(lit_mask & (1 << index))
		var tone: Color = PETAL_TONES[index]
		var center_ray := Vector2.UP.rotated(TAU * float(index) / float(Model.PETAL_COUNT))
		var in_progress: bool = _state.live and _state.kind == Model.PETAL and index == _state.target and _state.open_fraction > 0.0
		if lit:
			draw_colored_polygon(leaf, tone)
			draw_line(FLOWER + center_ray * 27.0, FLOWER + center_ray * 75.0, Color(UMBER, 0.49), 1.4, true)
		elif in_progress:
			draw_colored_polygon(leaf, Color(tone, float(_state.target_overlap) * 0.35))
		var border := leaf.duplicate()
		border.append(leaf[0])
		draw_polyline(border, Color(INK, 0.80) if lit else Color(PALE, 0.48), 1.5, true)
	for index in Model.BLANK_COUNT:
		var at := FLOWER + Vector2(-12.5 + float(index) * 25.0, 0)
		var retained := bool(int(_state.blank_mask) & (1 << index))
		_dark_mark(at, 10.5, MINT if retained else PALE, retained)
	_text(Vector2(570, 471), "%d／4 花瓣　%d／2 留白" % [_state.petals_done, _state.blanks_done], INK, 17, 258)


func _draw_readout() -> void:
	Props.lacquer_board(self, READOUT, LACQUER)
	var blank: bool = _state.kind == Model.BLANK
	var tone := MINT if blank else GOLD
	if blank:
		_dark_mark(Vector2(931, 224), 9.3, MINT, false)
	else:
		_light_mark(Vector2(931, 224), GOLD)
	_text(Vector2(952, 232), "留白拍" if blank else "花瓣 %d" % (int(_state.target) + 1), tone, 23, 264.0)
	var time_label := "掃燈中" if _state.live else "準備 %.1f 秒" % (ceilf(float(_state.seconds_to_sweep) * 10.0) / 10.0)
	if _state.ended:
		time_label = "光紋結束"
	_text(Vector2(920, 261), "第 %d／%d 拍　%s" % [int(_state.phase_index) + 1, _state.phase_count, time_label], PALE, 17, 307.0)
	_bar(Rect2(920, 273, 305, 5), _state.phase_progress, tone)
	_text(Vector2(920, 310), "傘骨擋光" if blank else "對準花瓣", INK, 17, 310.0)
	_bar(Rect2(920, 320, 305, 7), _state.target_overlap, tone)
	_text(Vector2(920, 359), "留白時間" if blank else "受光時間", INK, 17, 310.0)
	_bar(Rect2(920, 370, 305, 7), _dose_ratio(), tone)
	var next: Dictionary = _state.next
	if not next.is_empty() and not _state.ended:
		var following := "留白" if next.kind == Model.BLANK else "花瓣 %d" % (int(next.target) + 1)
		_text(Vector2(920, 480), "下拍 · " + following, MINT if next.kind == Model.BLANK else GOLD, 18, 309.0)
	elif _state.center_proven:
		_text(Vector2(920, 480), "花芯完成", MINT, 18, 309.0)


## The fine print for the readout's hover hint.
func _status() -> String:
	if _state.kind == Model.BLANK:
		if _state.brake_armed and not _state.brake_slowed:
			return "煞車已接合，等傘停穩"
		if _state.brake_ready:
			return "外圈雙短線預告煞停位置"
		return "煞住傘骨才會累計留白"
	if _state.center_proven:
		return "四瓣與雙段留白已成花芯"
	return "跟著燈掃的方向轉傘"


func _draw_sequence() -> void:
	var phases: Array = _state.phases
	var outcomes: PackedByteArray = _state.phase_results
	for index in phases.size():
		var phase: Dictionary = phases[index]
		var blank: bool = phase.kind == Model.BLANK
		var state: int = outcomes[index]
		var active: bool = not _state.ended and index == _state.phase_index
		var tone := MINT if blank else GOLD
		var card := Rect2(35 + float(index) * 203.0, 626, 195, 57)
		Props.shaded_box(self, card, Props.lighten(LACQUER, 0.12) if active else Props.deepen(LACQUER, 0.15), 6.0)
		if active:
			draw_rect(Rect2(card.position + Vector2(4, card.size.y - 10), Vector2(card.size.x - 8, 2)), tone)
		var midpoint := card.position + Vector2(24, 29)
		if blank:
			_dark_mark(midpoint, 8.5, tone, state == 1)
		else:
			_light_mark(midpoint, tone)
		var title := "留白" if blank else "花瓣 %d" % (int(phase.target) + 1)
		_text(midpoint + Vector2(20, 6), title, INK, 18, 123.0)
		var mark := card.position + Vector2(169, 29)
		if state == 1:
			draw_polyline(PackedVector2Array([mark + Vector2(-5, 0), mark + Vector2(-1, 4), mark + Vector2(7, -5)]), MINT, 2.4, true)
		elif state == 2:
			draw_line(mark + Vector2(-5, -5), mark + Vector2(5, 5), CORAL, 2.3, true)
			draw_line(mark + Vector2(5, -5), mark + Vector2(-5, 5), CORAL, 2.3, true)


func _dark_mark(at: Vector2, size_px: float, tone: Color, kept: bool) -> void:
	var points := PackedVector2Array([at + Vector2(-size_px, 0), at + Vector2(0, -size_px * 0.78),
		at + Vector2(size_px, 0), at + Vector2(0, size_px * 0.78)])
	if kept:
		draw_colored_polygon(points, Color("#181924"))
	points.append(points[0])
	draw_polyline(points, tone, 1.6, true)
	for x in [-2.3, 2.3]:
		draw_line(at + Vector2(x, -3.2), at + Vector2(x, 3.2), tone, 1.5, true)


func _light_mark(at: Vector2, tone: Color) -> void:
	draw_arc(at, 8.0, 0.0, TAU, 18, tone, 2.1, true)
	draw_circle(at, 2.1, tone, true, -1.0, true)


func _leaf(at: Vector2, ray: Vector2, length_px: float, breadth: float) -> PackedVector2Array:
	var outline := PackedVector2Array([at])
	for side in [1.0, -1.0]:
		for index in range(1, 9):
			var progress := float(index) / 9.0 if side > 0.0 else 1.0 - float(index) / 9.0
			var span := sin(PI * progress) * (0.72 + 0.31 * progress) * breadth
			outline.append(at + ray * length_px * progress + ray.orthogonal() * span * float(side))
		if side > 0.0:
			outline.append(at + ray * length_px)
	return outline


## A recessed slot in the board, filled like a glass tube.
func _bar(rect: Rect2, amount: float, tone: Color) -> void:
	var slot := rect.grow_individual(0, 1, 0, 1)
	draw_rect(slot.grow(2.0), Props.deepen(LACQUER, 0.4))
	draw_rect(slot, Color("#1d1218"))
	draw_rect(Rect2(slot.position.x, slot.end.y, slot.size.x, 2), Props.lighten(LACQUER, 0.25))
	if amount > 0.0:
		var fill := Rect2(slot.position, Vector2(slot.size.x * clampf(amount, 0.0, 1.0), slot.size.y))
		draw_rect(fill, tone)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), Props.lighten(tone, 0.4))


func _dose_ratio() -> float:
	var dose: float = _state.darkness if _state.kind == Model.BLANK else _state.exposure
	return clampf(dose / maxf(0.001, _state.requirement), 0.0, 1.0)


func _ready_to_stop() -> bool:
	if not _state.brake_ready:
		return false
	var tolerance := maxf(deg_to_rad(2.0), _state.rib_half_width - _state.beam_half_width)
	return absf(angle_difference(_state.stop_heading, _state.guide_heading)) <= tolerance


func _rim(azimuth: float, radius: float = RADIUS) -> Vector2:
	return HUB + Vector2(cos(azimuth), sin(azimuth) * FORESHORTEN) * radius


func _arc(radius: float, from: float, to: float, tint: Color, width: float, divisions: int) -> void:
	if absf(to - from) < 0.001:
		return
	var curve := PackedVector2Array()
	for index in divisions + 1:
		curve.append(_rim(lerpf(from, to, float(index) / float(divisions)), radius))
	draw_polyline(curve, tint, width, true)


func _text(at: Vector2, value: String, tint: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), tint)
