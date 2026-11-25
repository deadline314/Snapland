extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/coin_bank_shot_model.gd")
const Stage = preload("res://game/minigames/coin_bank_shot_stage.gd")
const ART := "res://assets/minigames/coin-bank-counter.webp"
const BOARD := Rect2(35, 187, 803, 328)
const READOUT := Rect2(855, 187, 390, 328)
const INK := Color("#fff0dc")
const MUTED := Color("#afc4c5")
const DEEP := Color("#161d27")
const EDGE := Color("#796458")
const GOLD := Color("#ffd98d")
const MINT := Color("#a3e3c2")
const CORAL := Color("#f9a392")
const BOARD_TONES := [Color("#a1e6dd"), Color("#f3a690")]
const SELECTIONS := ["瞄投處", "斜板 A", "斜板 B"]

enum { TURN_LEFT, TURN_RIGHT, POWER_DOWN, POWER_UP, SELECT, BOARD_TOGGLE, SHOOT, HELPER }

const LABELS := ["向左調角 · A", "向右調角 · D", "降力道 · S", "升力道 · W", "切換調整 · F", "收放斜板 · E", "投幣 · 空白", "幫手調板 · R"]
const NAMES := ["CoinLeft", "CoinRight", "CoinLessPower", "CoinMorePower", "CoinSelect", "CoinBoard", "CoinShoot", "CoinHelper"]
const HINTS := [
	"向左轉所選的方向或斜板", "向右轉所選的方向或斜板",
	"力道較小，銅板更容易減速入孔", "增加距離，太快撞孔緣會彈開",
	"依序選瞄投處、斜板 A 或 B", "收起可直投，放下才能借彈",
	"投向金框指定孔。入孔時速度要低", "輔助只調整你選中的斜板",
]

var _state: Dictionary = {}
var _art: Texture2D
var _stage: SubViewport
var _last_style := ""
var _last_locale := ""
var _last_paint: Array = []


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.ended or state.active:
		return false
	match action:
		TURN_LEFT, TURN_RIGHT, SELECT, SHOOT:
			return true
		POWER_DOWN:
			return state.power > Model.MIN_POWER
		POWER_UP:
			return state.power < Model.MAX_POWER
		BOARD_TOGGLE:
			return int(state.selected) != Model.AIM
		HELPER:
			return state.assisted and int(state.selected) != Model.AIM and state.boards[state.selected].placed
	return false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#383b40"), Color("#65523c"), EDGE, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	_stage = Stage.new()
	add_child(_stage)
	_refresh(false)


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == BOARD_TOGGLE and not _state.is_empty() and int(_state.selected) == Model.AIM:
		return "先切換到斜板，再收放"
	return HINTS[slot] if slot >= 0 else ""


func present(state: Dictionary, reduced_motion: bool = false) -> void:
	_state = state
	if is_node_ready():
		_refresh(reduced_motion)


func _refresh(reduced_motion: bool) -> void:
	if _state.is_empty():
		return
	_stage.present(_state, reduced_motion)
	var paint := [_state.layout, _state.selected, _state.aim_degrees, _state.power,
		_state.active, _state.ended, _state.coin, _state.called, _state.sunk, _state.shots_left,
		_state.shot_bounces, _state.contacts_mask, _state.rim_scrapes, _state.last_surface,
		_state.impact, _state.material, roundi(float(_state.speed) * 20.0), reduced_motion]
	for board: Dictionary in _state.boards:
		paint.append(board.angle)
		paint.append(board.placed)
	var typography_changed := _scale != Paper.text_scale() or _last_locale != TranslationServer.get_locale() or _last_style != Paper.font_style()
	if typography_changed:
		refresh_font()
		_last_locale = TranslationServer.get_locale()
		_last_style = Paper.font_style()
	if paint == _last_paint and not typography_changed:
		return
	_last_paint = paint
	for index in _buttons.size():
		var disabled := not action_available(index, _state)
		if _buttons[index].disabled != disabled:
			_buttons[index].disabled = disabled
	var selected: int = _state.selected
	var label: String = LABELS[BOARD_TOGGLE]
	if selected != Model.AIM:
		label = "收起斜板 · E" if _state.boards[selected].placed else "放下斜板 · E"
	if _buttons[BOARD_TOGGLE].text != label:
		_buttons[BOARD_TOGGLE].text = label
	_buttons[SELECT].set_pressed_no_signal(selected != Model.AIM)
	queue_redraw()


func _draw() -> void:
	if _state.is_empty() or _font == null or not is_instance_valid(_stage):
		return
	var hint := "看指定孔，先調角度與力道" if int(_state.selected) == Model.AIM else "轉斜板改變反彈方向"
	if _state.active:
		hint = "布面減速中" if int(_state.material) == Model.FELT else "銅板在漆面滑行"
	_text(Vector2(35, 171), hint, GOLD, 22, BOARD.size.x)
	draw_rect(BOARD.grow(2), EDGE)
	draw_rect(BOARD, DEEP)
	if is_instance_valid(_art):
		var original := _art.get_size()
		var height := original.x * BOARD.size.y / BOARD.size.x
		draw_texture_rect_region(_art, BOARD, Rect2(0, (original.y - height) * 0.48, original.x, height))
	draw_texture_rect(_stage.get_texture(), BOARD, false)
	_draw_routes()
	_draw_pockets_and_boards()
	_draw_readout()


func _draw_routes() -> void:
	var path: PackedVector2Array = _state.trail
	if path.size() > 1:
		var previous := _world_point(path[0])
		for index in range(1, path.size()):
			var next := _world_point(path[index])
			var coverage := 0.16 + 0.58 * float(index) / float(path.size())
			draw_line(previous, next, Color(MINT, coverage), 1.8, true)
			previous = next
	if _state.active:
		draw_circle(_world_point(_state.coin), 8.0, Color(GOLD, 0.62), false, 1.3, true)
	else:
		var launch: Vector2 = _state.launcher
		var arrow := _world_point(launch + Vector2(_state.direction) * 0.58)
		draw_line(_world_point(launch), arrow, GOLD, 2.2, true)
		draw_circle(arrow, 3.4, GOLD, true, -1.0, true)
		var preview: PackedVector2Array = _state.preview
		for index in range(1, preview.size(), 2):
			draw_line(_world_point(preview[index - 1]), _world_point(preview[index]), Color("#aacce9"), 2.0, true)
	var impact: Vector2 = _state.impact
	if impact.is_finite() and not str(_state.last_surface).is_empty():
		var impact_tint := CORAL if str(_state.last_surface) == "rim" else MINT
		draw_circle(_world_point(impact), 7.0, Color(impact_tint, 0.85), false, 1.4, true)


func _draw_pockets_and_boards() -> void:
	for index in Model.POCKET_COUNT:
		var pocket: Dictionary = _state.pockets[index]
		var at := _world_point(pocket.center)
		var current := index == int(_state.called)
		var tone := MINT if pocket.filled else (GOLD if current else MUTED)
		_text(at + Vector2(-5, -16), str(index + 1), tone, 16, 25)
	for index in _state.boards.size():
		var board: Dictionary = _state.boards[index]
		var at := _world_point(board.center)
		var selected: bool = index == int(_state.selected)
		var tone: Color = BOARD_TONES[index]
		if not board.placed:
			draw_line(_world_point(board.a), _world_point(board.b), Color(tone, 0.32), 1.5, true)
			draw_circle(at, 5.0, Color(tone, 0.52), false, 1.5, true)
		if selected:
			draw_circle(at, 10.0, GOLD, false, 1.5, true)
		_text(at + Vector2(-6, -13), "A" if index == 0 else "B", tone, 14, 28)


func _draw_readout() -> void:
	draw_rect(READOUT.grow(2), EDGE)
	draw_rect(READOUT, DEEP)
	var p := READOUT.position + Vector2(16, 0)
	var target := "三孔完成" if int(_state.sunk) == Model.POCKET_COUNT else "指定孔  %d" % (int(_state.called) + 1)
	_text(p + Vector2(0, 34), target, GOLD, 23, 199)
	var coins := "可補幣" if int(_state.shots_left) < 0 else "剩 %d 枚" % _state.shots_left
	_text(p + Vector2(220, 34), coins, INK, 18, 136)
	var selected: int = _state.selected
	var control: String = SELECTIONS[selected + 1]
	var angle := int(_state.aim_degrees) if selected == Model.AIM else roundi(rad_to_deg(_state.boards[selected].angle))
	_text(p + Vector2(0, 84), "%s  %d°" % [control, angle], INK, 20, 354)
	_text(p + Vector2(0, 126), "投幣力道  %d" % _state.power, MUTED, 20, 195)
	var rail := Rect2(p + Vector2(182, 112), Vector2(169, 8))
	draw_rect(rail, Color("#41414b"))
	draw_rect(Rect2(rail.position, Vector2(rail.size.x * float(_state.power_fraction), rail.size.y)), GOLD)
	var move := "滑速  %.1f" % _state.speed if _state.active else "靠近孔時要減速"
	_text(p + Vector2(0, 170), move, INK, 19, 346)
	_text(p + Vector2(0, 211), "碰板 %d 次  ·  擦孔緣 %d 次" % [_state.shot_bounces, _state.rim_scrapes], MINT, 17, 352)
	var proof := "同一枚已撞兩板 · 對準落孔" if (int(_state.contacts_mask) & 3) == 3 else "深藍布面會減速"
	_text(p + Vector2(0, 287), proof, GOLD if (int(_state.contacts_mask) & 3) == 3 else MUTED, 17, 354)


func _world_point(point: Vector2) -> Vector2:
	return BOARD.position + _stage.project(point)


func _text(at: Vector2, value: String, color: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), color)
