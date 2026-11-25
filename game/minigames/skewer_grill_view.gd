extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/skewer_grill_model.gd")
const Stage = preload("res://game/minigames/skewer_grill_stage.gd")
const ART := "res://assets/minigames/skewer-grill-counter.webp"
const BOARD := Rect2(35, 188, 802, 326)
const GRILL := Rect2(57, 211, 758, 290)
const READOUT := Rect2(856, 188, 389, 326)
const INK := Color("#fff0df")
const PALE := Color("#e9c6a5")
const PANEL := Color("#232a2d")
const DEEP := Color("#171d23")
const EDGE := Color("#785b4b")
const MINT := Color("#a7dcc3")
const GOLD := Color("#ffd087")
const RED := Color("#ffb19e")
const CUE_LABELS := {"raw": "生", "warming": "暖", "ready": "熟", "danger": "焦前", "charred": "焦"}
const CUE_COLORS := {"raw": Color("#e9b4ad"), "warming": GOLD, "ready": MINT, "danger": RED, "charred": Color("#ab9a9d")}
const ZONE_LABELS := {Model.BENCH: "備料", Model.NEAR: "近炭", Model.FAR: "餘溫", Model.SERVED: "上桌"}
enum { PREVIOUS, NEXT, NEAR, FAR, TURN, SERVE, COAL, HELPER }

const LABELS := ["上一串 · A", "下一串 · D", "移近炭 · W", "移餘溫 · S", "轉 ¼ 圈 · 空白", "上桌 · E", "添炭 · Q", "指定翻面幫手 · R"]
const NAMES := ["SkewerPrevious", "SkewerNext", "SkewerNear", "SkewerFar", "SkewerTurn", "SkewerServe", "SkewerCoal", "SkewerHelper"]
const HINTS := [
	"切換到上一串", "切換到下一串",
	"火力強，熟得快也更容易焦", "用遠炭餘溫慢慢收火",
	"順轉四分之一圈，下一面朝炭", "四面都熟後上桌",
	"補火會加速，也會取消這局的餘溫挑戰", "幫手只翻這一串，移位與上桌仍由你操作",
]

var _state: Dictionary = {}
var _texture: Texture2D
var _stage: SubViewport
var _last_locale := ""
var _last_font_style := ""
var _paint_stamp: Array = []


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.ended or action < PREVIOUS or action > HELPER:
		return false
	var skewer: Dictionary = state.skewers[state.selected]
	match action:
		PREVIOUS, NEXT, COAL:
			return true
		NEAR, FAR:
			var target := Model.NEAR if action == NEAR else Model.FAR
			return not skewer.ruined and skewer.zone != Model.SERVED and skewer.zone != target
		TURN:
			return not skewer.ruined and skewer.zone != Model.SERVED
		HELPER:
			return state.assisted and not skewer.ruined and skewer.zone != Model.SERVED
		SERVE:
			return skewer.serve_ready or skewer.ruined
	return false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#3a3432"), Color("#65513e"), EDGE, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	if ResourceLoader.exists(ART):
		_texture = load(ART) as Texture2D
	_stage = Stage.new()
	add_child(_stage)
	_refresh(false)


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == SERVE and not _state.is_empty() and _state.skewers[_state.selected].ruined:
		return "換一串重烤，其他串保留"
	return HINTS[slot] if slot >= 0 else ""


func present(state: Dictionary, reduced_motion: bool = false) -> void:
	_state = state
	if is_node_ready():
		_refresh(reduced_motion)


func _refresh(reduced_motion: bool) -> void:
	if _state.is_empty():
		return
	_stage.present(_state, reduced_motion)
	var heat := roundi(float(_state.near_heat) * 20.0)
	var residual := roundi(float(_state.residual_heat) * 20.0)
	var stamp := [_state.selected, _state.helper, heat, residual, _state.refuels, _state.warning, _state.layout, _state.ended]
	for skewer: Dictionary in _state.skewers:
		stamp.append_array([skewer.zone, skewer.down_face, skewer.serve_ready, skewer.ruined])
		stamp.append_array(skewer.face_states)
	var typography := _scale != Paper.text_scale() or _last_locale != TranslationServer.get_locale() or _last_font_style != Paper.font_style()
	if typography:
		refresh_font()
		_last_locale = TranslationServer.get_locale()
		_last_font_style = Paper.font_style()
	if stamp == _paint_stamp and not typography:
		return
	_paint_stamp = stamp
	for index in _buttons.size():
		var disabled := not action_available(index, _state)
		if _buttons[index].disabled != disabled:
			_buttons[index].disabled = disabled
	var selected: Dictionary = _state.skewers[_state.selected]
	_buttons[NEAR].set_pressed_no_signal(selected.zone == Model.NEAR)
	_buttons[FAR].set_pressed_no_signal(selected.zone == Model.FAR)
	_buttons[SERVE].set_pressed_no_signal(selected.serve_ready)
	_buttons[HELPER].set_pressed_no_signal(_state.helper == _state.selected)
	_buttons[SERVE].text = "換串 · E" if selected.ruined else LABELS[SERVE]
	_buttons[HELPER].text = "取消幫手 · R" if _state.helper == _state.selected else LABELS[HELPER]
	queue_redraw()


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	var plan := "近炭旺 · 先熟再移遠" if int(_state.layout) == 0 else "餘溫厚 · 留一面慢收火"
	_text(Vector2(35, 172), plan, GOLD, 22, BOARD.size.x)
	draw_rect(BOARD.grow(2), EDGE)
	draw_rect(BOARD, DEEP)
	if _texture != null:
		var art_size := _texture.get_size()
		var source_height := art_size.x * BOARD.size.y / BOARD.size.x
		draw_texture_rect_region(_texture, BOARD, Rect2(0, (art_size.y - source_height) * 0.38, art_size.x, source_height))
		draw_rect(BOARD, Color(0.15, 0.09, 0.09, 0.12))
	if is_instance_valid(_stage):
		draw_texture_rect(_stage.get_texture(), GRILL, false)
	_draw_fire_meter(Vector2(49, 200), "近炭", float(_state.near_heat), GOLD)
	_draw_fire_meter(Vector2(653, 200), "餘溫", float(_state.residual_heat), MINT)
	_draw_readout()


func _draw_fire_meter(at: Vector2, title: String, value: float, tone: Color) -> void:
	var plate := Rect2(at, Vector2(170, 44))
	draw_rect(plate, Color(0.09, 0.10, 0.12, 0.92))
	_text(at + Vector2(12, 30), title, tone, 17, 63)
	var bar := Rect2(at + Vector2(69, 20), Vector2(87, 5))
	draw_rect(bar, Color("#514846"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0, 1), bar.size.y)), tone)


func _draw_readout() -> void:
	draw_rect(READOUT.grow(2), EDGE)
	draw_rect(READOUT, DEEP)
	_text(READOUT.position + Vector2(16, 30), "四面熟度", INK, 22, 168)
	var fire := "未添炭" if int(_state.refuels) == 0 else "添炭 %d 次" % _state.refuels
	_text(READOUT.position + Vector2(218, 30), fire, GOLD if int(_state.refuels) == 0 else PALE, 17, 150)
	for index in Model.SKEWER_COUNT:
		_draw_skewer_status(index, READOUT.position + Vector2(12, 50 + index * 79))
	_text(READOUT.position + Vector2(16, 312), "金框標示朝炭面", PALE, 17, 345)


func _draw_skewer_status(index: int, at: Vector2) -> void:
	var entry: Dictionary = _state.skewers[index]
	var selected := index == int(_state.selected)
	var row := Rect2(at, Vector2(365, 73))
	draw_rect(row, PANEL if selected else Color("#20252a"))
	if selected:
		draw_rect(Rect2(at, Vector2(4, row.size.y)), GOLD)
	var ingredient: String = entry.ingredient
	var tag: String = ZONE_LABELS.get(entry.zone, "")
	if index == _state.helper:
		tag += " · 幫手"
	if index == _state.warning:
		tag = "先移遠"
	if entry.ruined:
		tag = "焦了，可換串"
	_text(at + Vector2(14, 27), "%d  %s" % [index + 1, ingredient], INK, 19, 156)
	_text(at + Vector2(205, 27), tag, RED if index == _state.warning or entry.ruined else MINT, 17, 145)
	for face in Model.FACE_COUNT:
		var cue: String = entry.face_states[face]
		var chip := Rect2(at + Vector2(14 + face * 85, 36), Vector2(79, 29))
		draw_rect(chip, DEEP)
		if face == int(entry.down_face) and entry.zone in [Model.NEAR, Model.FAR]:
			draw_rect(chip, GOLD, false, 2.0)
		var color: Color = CUE_COLORS.get(cue, PALE)
		var mark: String = CUE_LABELS.get(cue, "")
		_text(chip.position + Vector2(8, 22), "%d %s" % [face + 1, mark], color, 16, 65)


func _text(at: Vector2, value: String, tone: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), tone)
