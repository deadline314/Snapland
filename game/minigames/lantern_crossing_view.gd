extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/lantern_crossing_model.gd")
const ART := "res://assets/minigames/lantern-crossing-rooftops.webp"
const BOARD := Rect2(35, 187, 847, 328)
const READOUT := Rect2(900, 187, 345, 328)
const ORIGIN := Vector2(209, 201)
const UNIT := 500.0
const PALE := Color("#b4cdd0")
const INK := Color("#fff1dc")
const DEEP := Color("#111c2e")
const FRAME := Color("#506c78")
const COPPER := Color("#c99766")
const GOLD := Color("#ffcd85")
const MINT := Color("#9ce3cc")
const CORAL := Color("#ffa791")
## Lacquered roof-beam wood for boards, weathered posts for the winches.
const LACQUER := Color("#2f2a36")
const POST := Color("#6b4a32")
const PALETTES := [Color("#fba676"), Color("#ffd579"), Color("#a1dfbb"), Color("#dab4f2")]

enum { LEFT, RIGHT, RAISE, LOWER, BRAKE, ACTION, RECOVER, HELPER }

const LABELS := ["左繩端 · A", "右繩端 · D", "升一格 · W", "降一格 · S", "釋放煞車 · 空白", "取燈 · E", "重送 · R", "固定對端 · H"]
const KEY_ICONS := ["left", "right", "up", "down", "stop", "hook", "undo", "anchor"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
const NAMES := ["LanternLeft", "LanternRight", "LanternRaise", "LanternLower", "LanternBrake", "LanternAction", "LanternRecover", "LanternHelper"]
const HINTS := [
	"選左側絞盤。右端會留在原位", "選右側絞盤。左端會留在原位",
	"抬高這端，滑車往較低端滑", "降低這端，可讓滑車滑回來",
	"扣住滑車後可安全調整繩高", "先對準掛鉤，再煞停掛燈",
	"送回當前燈籠，已掛的燈保留", "輔助固定對端高度。選回該端就能接手",
]

var _state: Dictionary = {}
var _backdrop: Texture2D
var _reduced_motion := false
var _font_style := ""
var _locale := ""


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.ended:
		return false
	match action:
		LEFT, RIGHT:
			return not state.stalled
		RAISE, LOWER:
			var height: int = state.height_left if state.selected_endpoint == Model.LEFT else state.height_right
			var limit := Model.MAX_HEIGHT if action == RAISE else Model.MIN_HEIGHT
			return not state.stalled and height != limit
		BRAKE:
			return not state.stalled
		ACTION:
			return not state.stalled and (state.loaded or state.can_load)
		RECOVER:
			return state.loaded or state.stalled
		HELPER:
			return state.assisted and not state.stalled
	return false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#253a49"), Color("#456053"), FRAME, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	use_key_caps(KEY_ICONS, KEY_TONE)
	if ResourceLoader.exists(ART):
		_backdrop = load(ART) as Texture2D
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	if READOUT.has_point(point) and not _state.is_empty():
		return "這盞已擺過，掛好才計入" if _state.swing_proven else "安全過牌：煞停再抬高兩端"
	var slot := hit_slot(point)
	if slot == ACTION and not _state.is_empty() and not _state.loaded:
		return "滑車停在起點時，扣上這盞燈"
	return HINTS[slot] if slot >= 0 else ""


func present(state: Dictionary, reduced_motion: bool = false) -> void:
	var text_current := _scale == Paper.text_scale() and _font_style == Paper.font_style() and _locale == TranslationServer.get_locale()
	if text_current and is_same(state, _state) and reduced_motion == _reduced_motion:
		return
	_state = state
	_reduced_motion = reduced_motion
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _state.is_empty():
		return
	refresh_font()
	_font_style = Paper.font_style()
	_locale = TranslationServer.get_locale()
	for index in _buttons.size():
		var disabled := not action_available(index, _state)
		if _buttons[index].disabled != disabled:
			_buttons[index].disabled = disabled
	_buttons[LEFT].set_pressed_no_signal(_state.selected_endpoint == Model.LEFT)
	_buttons[RIGHT].set_pressed_no_signal(_state.selected_endpoint == Model.RIGHT)
	_buttons[BRAKE].set_pressed_no_signal(_state.braking)
	_buttons[ACTION].set_pressed_no_signal(_state.can_hook)
	_buttons[HELPER].set_pressed_no_signal(int(_state.helper_endpoint) >= 0)
	_set_button_text(BRAKE, "釋放煞車 · 空白" if _state.braking else "煞停 · 空白")
	_set_button_text(ACTION, "掛燈 · E" if _state.loaded else "取燈 · E")
	_set_button_text(HELPER, "解除固定 · H" if int(_state.helper_endpoint) >= 0 else LABELS[HELPER])
	queue_redraw()


func _set_button_text(slot: int, label: String) -> void:
	if _buttons[slot].text != label:
		_buttons[slot].text = label


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	var hint := "先扣燈，再鬆開煞車" if not _state.loaded else "讓滑車滑到掛鉤，再煞停"
	if _state.stalled:
		hint = "碰到招牌 · 重送這盞"
	elif _state.can_hook:
		hint = "已對準 · 掛上燈籠"
	_text(Vector2(35, 172), hint, CORAL if _state.stalled else GOLD, 22, BOARD.size.x)
	_draw_roofs()
	_draw_winches()
	_draw_obstacle()
	_draw_hooks()
	_draw_trolley()
	_draw_readout()


func _draw_roofs() -> void:
	Props.wood_panel(self, BOARD.grow(8), LACQUER)
	draw_rect(BOARD, DEEP)
	if is_instance_valid(_backdrop):
		var natural := _backdrop.get_size()
		var crop_height := natural.x * BOARD.size.y / BOARD.size.x
		draw_texture_rect_region(_backdrop, BOARD, Rect2(0, (natural.y - crop_height) * 0.67, natural.x, crop_height))
		draw_rect(BOARD, Color(0.04, 0.08, 0.16, 0.18))


func _draw_winches() -> void:
	var left := _project(_state.rope_left)
	var right := _project(_state.rope_right)
	draw_line(left + Vector2(3, 6), right + Vector2(3, 6), Color(Props.SHADOW, 0.4), 4.0, true)
	Props.rope(self, left, right, 6.0, Props.HEMP)
	for side in [Model.LEFT, Model.RIGHT]:
		var at := left if side == Model.LEFT else right
		var selected: bool = side == _state.selected_endpoint
		var locked: bool = side == _state.helper_endpoint
		var position_x := at.x - 21.0 if side == Model.LEFT else at.x + 21.0
		var beam := Rect2(position_x - 6.0, BOARD.position.y + 18.0, 12.0, BOARD.size.y - 51.0)
		Props.block_shadow(self, beam, Vector2(5, 0), 0.4)
		Props.wood_panel(self, beam, POST)
		for mark in range(Model.MIN_HEIGHT, Model.MAX_HEIGHT + 1):
			var y := _project(Vector2(0, Model.ROPE_BASE_Y - Model.HEIGHT_STEP * mark)).y
			Props.rivet(self, Vector2(position_x - 7.0, y), Props.BRASS)
			draw_rect(Rect2(position_x - 4.0, y - 1.0, 12.0, 2.0), Color(Props.deepen(POST, 0.4), 0.9))
		var ring := GOLD if selected else (MINT if locked else COPPER)
		Props.rope(self, Vector2(position_x, at.y), at, 4.0, Props.HEMP)
		Props.token(self, at, 10.0, Color("#5f6a72"))
		draw_circle(at, 12.0, ring, false, 2.5, true)
		Props.token(self, at, 4.0, ring)


func _draw_obstacle() -> void:
	var sign: Rect2 = _state.sign
	if not sign.has_area():
		return
	var panel := Rect2(_project(sign.position), sign.size * UNIT)
	Props.block_shadow(self, panel, Vector2(5, 7), 0.45)
	Props.surface(self, panel, "enamel", Color("#8a3b3a"), Props.BRASS)
	if _state.stalled:
		draw_rect(panel, CORAL, false, 2.0)
	# These corner strokes show the collision boundary at smaller viewport sizes.
	for x in [panel.position.x, panel.end.x]:
		draw_line(Vector2(x, panel.position.y - 3), Vector2(x, panel.end.y + 3), CORAL, 1.8, true)
	_text(panel.position + Vector2(-8, -8), "招牌", INK, 15, 54.0)


func _draw_hooks() -> void:
	var hooks: PackedVector2Array = _state.hooks
	for index in hooks.size():
		var at := _project(hooks[index])
		var hung: bool = index < int(_state.hung)
		var active: bool = index == int(_state.job) and not _state.ended
		var color: Color = PALETTES[index]
		var ring := MINT if active and _state.can_hook else (color if active or hung else PALE.darkened(0.36))
		# An iron hook on a riveted bracket: dark under-stroke, then its colour.
		draw_arc(at + Vector2(1, 1), 7.0, -PI * 1.18, PI * 0.55, 13, Color(Props.SHADOW, 0.7), 4.4, true)
		draw_line(at + Vector2(1, -7), at + Vector2(1, -19), Color(Props.SHADOW, 0.7), 4.0, true)
		draw_arc(at, 7.0, -PI * 1.18, PI * 0.55, 13, ring, 2.6 if active else 2.0, true)
		draw_line(at + Vector2(0, -8), at + Vector2(0, -19), ring, 2.1, true)
		Props.rivet(self, at + Vector2(0, -20), Props.IRON)
		if hung:
			_lamp(at + Vector2(0, 22), float(_state.lantern_radius) * UNIT * 0.80, color)
	var source := _project(_state.source)
	if not _state.loaded and not _state.ended:
		draw_circle(source, 12.0, GOLD, false, 2.6, true)
		draw_line(source + Vector2(-19, 0), source - Vector2(10, 0), GOLD, 2.2, true)


func _draw_trolley() -> void:
	var at := _project(_state.trolley)
	var edge := CORAL if _state.stalled else (MINT if _state.braking else GOLD)
	# Two iron sheaves riding the rope under a painted bar.
	Props.token(self, at - Vector2(7, 2), 6.0, Props.IRON)
	Props.token(self, at + Vector2(7, -2), 6.0, Props.IRON)
	Props.shaded_box(self, Rect2(at - Vector2(12, -1), Vector2(24, 8)), edge.darkened(0.15), 3.0)
	if not _state.loaded:
		return
	var hooked := _project(_state.lantern_hook)
	var lamp := _project(_state.lantern)
	draw_line(at + Vector2(0, 4), hooked, COPPER, 2.2, true)
	draw_circle(hooked, 3.8, edge, false, 1.9, true)
	draw_line(hooked, lamp, PALE, 1.2, true)
	var tint: Color = PALETTES[clampi(_state.job, 0, PALETTES.size() - 1)]
	_lamp(lamp, float(_state.lantern_radius) * UNIT, tint)


func _lamp(at: Vector2, radius: float, tone: Color) -> void:
	var luminosity := 0.12
	if not _reduced_motion:
		luminosity += 0.027 * sin(float(_state.elapsed) * 3.4)
	draw_circle(at, radius * 1.59, Color(tone, luminosity), true, -1.0, true)
	draw_circle(at, radius * 1.19, Color(tone, 0.19), true, -1.0, true)
	draw_circle(at, radius, tone.darkened(0.21), true, -1.0, true)
	draw_circle(at - Vector2(radius * 0.08, radius * 0.10), radius * 0.73, tone, true, -1.0, true)
	draw_arc(at, radius * 0.79, -1.08, 1.08, 10, Color("#fff3db"), 1.65, true)
	var clamp_size := Vector2(radius * 1.08, maxf(2.0, radius * 0.26))
	for sign_y in [-1.0, 1.0]:
		draw_rect(Rect2(at + Vector2(-clamp_size.x * 0.5, radius * sign_y * 0.78 - clamp_size.y * 0.5), clamp_size), COPPER)


func _draw_readout() -> void:
	Props.lacquer_board(self, READOUT, LACQUER)
	var base := READOUT.position + Vector2(16, 0)
	_text(base + Vector2(0, 34), "燈籠掛位", INK, 23, 290)
	var hooks: PackedVector2Array = _state.hooks
	for index in hooks.size():
		var plate := Rect2(base + Vector2(index * 77.0, 51), Vector2(68, 36))
		var hung := index < int(_state.hung)
		var active: bool = index == int(_state.job) and not _state.ended
		var tone: Color = PALETTES[index] if hung else PALE
		Props.shaded_box(self, plate.grow_individual(0, 0, 0, 4), Props.lighten(LACQUER, 0.15) if active else Props.deepen(LACQUER, 0.2), 4.0)
		if active:
			draw_rect(Rect2(plate.position + Vector2(4, plate.size.y - 4), Vector2(plate.size.x - 8, 2)), GOLD)
		_text(plate.position + Vector2(8, 25), "已掛" if hung else str(index + 1), tone, 16, 51)
	var left_status := "左繩端  %d 格" % _state.height_left
	var right_status := "右繩端  %d 格" % _state.height_right
	_text(base + Vector2(0, 122), left_status, GOLD if _state.selected_endpoint == Model.LEFT else PALE, 20, 296)
	_text(base + Vector2(0, 159), right_status, GOLD if _state.selected_endpoint == Model.RIGHT else PALE, 20, 296)
	var brake_text := "滑車可沿坡度移動"
	if _state.braking:
		brake_text = "煞車減速中" if absf(_state.velocity) > 0.008 else "滑車已煞停"
	_text(base + Vector2(0, 196), brake_text, MINT if _state.braking else INK, 19, 308)
	var helper: int = _state.helper_endpoint
	if helper >= 0:
		_text(base + Vector2(0, 233), "對端已固定 · 可切回接手", MINT, 17, 313)
	if _state.swing_proven:
		_text(base + Vector2(0, 293), "這盞已擺過，掛好才計入", GOLD, 17, 313)


func _project(point: Vector2) -> Vector2:
	return ORIGIN + point * UNIT


func _text(at: Vector2, value: String, color: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), color)
