extends Control

signal command(action: int, pressed: bool, source: String)
signal pointer_cancelled

const Model = preload("res://game/minigames/bubble_lift_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const ICONS := ["less", "more", "confirm", "helper", "down", "down", "up", "wave"]
const BACKDROP := "res://assets/minigames/bubble-lift-shaft.webp"
const SHAFT := Rect2(35, 192, 871, 320)
const CONSOLE := Rect2(927, 192, 317, 320)
const INK := Color("#f0edf9")
const MUTED := Color("#9695b3")
const MINT := Color("#9bf1d5")
const HEAT := Color("#ff9b6f")
const GOLD := Color("#fbd58c")
const FORK := Color("#ceadff")
const BARREL_COLORS := [Color("#deb282"), Color("#e5a4ba"), Color("#a2dae0")]
enum { SINGLE, PAIR, CONFIRM, HELPER, PUMP_LEFT, PUMP_RIGHT, RELEASE, VENT }
const LABELS := ["單桶 · 1", "雙桶 · 2", "確認裝載 · E", "補泵 AI · R", "左泵 · A", "右泵 · D", "放籃 · Space", "排氣 · Q"]
const HINTS := ["一次裝一桶，泡量需求較低", "一次裝兩桶，過熱槽後可分泡", "裝入下一批原料桶", "確認裝載後，踩泵才會補力",
	"按住增加泡量", "按住增加泡量", "將有足夠泡量的乘籃放上輸送道", "按住減少泡量與升速"]

var _pointers: Dictionary = {}
var _buttons: Array[Button] = []
var _state: Dictionary = {}
var _font: Font
var _texture: Texture2D
var _scale := 1.0

static func button_rect(slot: int) -> Rect2:
	if slot < 0 or slot >= LABELS.size():
		return Rect2()
	return Rect2(35 + (slot % 4) * 306, 533 if slot < 4 else 617, 288, 74)

static func hit_slot(point: Vector2) -> int:
	if point.is_finite():
		for index in LABELS.size():
			if button_rect(index).has_point(point):
				return index
	return -1

static func shown(slot: int, state: Dictionary) -> bool:
	match int(state.get("phase", Model.FINISHED)):
		Model.DOCK: return slot >= 0 and slot < LABELS.size()
		Model.TRANSIT: return slot == VENT or (slot == CONFIRM and state.selection == 2 and not state.trip_split and not state.cargo.is_empty())
	return false

static func enabled(slot: int, state: Dictionary) -> bool:
	if not shown(slot, state):
		return false
	if state.phase == Model.TRANSIT:
		return not state.cargo[0].returning or state.cargo.size() > 1
	if slot == PAIR:
		return Model.cargo_count(state.delivered) <= 1
	if slot in [PUMP_LEFT, PUMP_RIGHT, VENT]:
		return state.loaded != 0
	return true

static func pointer_source(event: InputEvent) -> String:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if not shown(slot, _state):
		return ""
	if slot == CONFIRM and _state.phase == Model.TRANSIT:
		return "紫色分流段內，把大泡分成兩個載桶小泡"
	if slot == PUMP_LEFT or slot == PUMP_RIGHT:
		return "確認裝載後可按住踩泵" if _state.loaded == 0 else "按住補氣 %.2f／秒" % (_state.pump_rates.x if slot == PUMP_LEFT else _state.pump_rates.y)
	return HINTS[slot]

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if ResourceLoader.exists(BACKDROP):
		_texture = load(BACKDROP) as Texture2D
	for index in LABELS.size():
		var button := Button.new()
		button.clip_text = true
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.text = LABELS[index]
		Props.skin_key(button, Color("#5b3f66"), ICONS[index])
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_pressed_color", GOLD)
		button.add_theme_color_override("font_disabled_color", MUTED)
		add_child(button)
		button.position = button_rect(index).position
		button.size = button_rect(index).size
		_buttons.append(button)
	_refresh()

func _input(event: InputEvent) -> void:
	var source := pointer_source(event)
	if _pointers.has(source) and (not event.pressed or event.is_canceled()) and handle_pointer(event, Vector2.ZERO):
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and mouse_filter != Control.MOUSE_FILTER_IGNORE:
		if handle_pointer(event, event.position):
			accept_event()

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		if not _pointers.has(source):
			return false
		pointer_cancelled.emit()
		return true
	if not event.pressed:
		if not _pointers.has(source):
			return false
		var slot: int = _pointers[source]
		_pointers.erase(source)
		command.emit(slot, false, source)
		return true
	var slot := hit_slot(point)
	if not enabled(slot, _state) or _pointers.has(source):
		return false
	_pointers[source] = slot
	command.emit(slot, true, source)
	return true

func clear_pointers() -> void:
	_pointers.clear()

func present(state: Dictionary) -> void:
	_state = state
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if _state.is_empty():
		return
	if _scale != Paper.text_scale() or _font != Paper.font():
		_scale = Paper.text_scale()
		_font = Paper.font()
		for button in _buttons:
			button.add_theme_font_override("font", _font)
			button.add_theme_font_size_override("font_size", roundi(19.0 * _scale))
	for index in _buttons.size():
		_buttons[index].visible = shown(index, _state)
		_buttons[index].disabled = not enabled(index, _state)
	var dock: bool = _state.phase == Model.DOCK
	_buttons[CONFIRM].text = LABELS[CONFIRM] if dock else "分泡 · F"
	_buttons[SINGLE].set_pressed_no_signal(_state.selection == 1)
	_buttons[PAIR].set_pressed_no_signal(_state.selection == 2)
	_buttons[CONFIRM].set_pressed_no_signal(_state.loaded != 0 if dock else _state.can_split)
	_buttons[HELPER].set_pressed_no_signal(_state.helper)
	_buttons[PUMP_LEFT].set_pressed_no_signal((_state.pump_mask & Model.LEFT_PUMP) != 0)
	_buttons[PUMP_RIGHT].set_pressed_no_signal((_state.pump_mask & Model.RIGHT_PUMP) != 0)
	_buttons[VENT].set_pressed_no_signal(_state.venting)
	queue_redraw()

func _project(distance: float, height: float, lane: int = 0) -> Vector2:
	var progress: float = clampf(distance / _state.end, 0.0, 1.0)
	var branch := smoothstep(0.0, Model.FORK_LENGTH + 0.8, distance - _state.fork)
	return Vector2(89.0 + progress * 728.0 + lane * branch * 16.0, 478.0 - progress * 100.0 - height * 25.4 - lane * branch * 25.0)

func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(35, 166), _state.feedback, GOLD, 18)
	Props.metal_plate(self, SHAFT.grow(6), Props.BRASS, false)
	draw_rect(SHAFT, Color("#25203c"))
	if _texture != null:
		draw_texture_rect(_texture, SHAFT, false)
	_draw_shaft()
	_draw_console()

func _draw_shaft() -> void:
	var end: float = _state.end
	var heat: Vector2 = _state.heat
	var roof: float = _state.heat_height
	Props.rope(self, _project(0, 0), _project(end, 0), 6.0)
	_draw_zone(heat.x, heat.y, roof, MINT if _state.cool else HEAT)
	_text(_project(heat.x, roof) + Vector2(10, -9), "熱槽", MINT if _state.cool else HEAT, 17)
	var entry := _project(0, 0)
	Props.contact_shadow(self, entry + Vector2(18, 18), 80, 0.45)
	Props.shaded_box(self, Rect2(entry - Vector2(21, 0), Vector2(72, 16)), Props.BISCUIT, 6.0)
	_text(entry + Vector2(-14, 30), "裝載台", INK, 16)
	if _state.selection == 2:
		var start: float = _state.fork
		for distance in [start, start + Model.FORK_LENGTH]:
			draw_dashed_line(_project(distance, 4.8), _project(distance, 0), FORK, 3.0, 8.0)
		_text(_project(start, 4.8) + Vector2(8, -8), "分流段", FORK, 17)
		_draw_receiver(-1, "低台", FORK)
		_draw_receiver(1, "高台", MINT)
	else:
		_draw_receiver(0, "接收台", GOLD)
	if _state.phase == Model.DOCK and _state.loaded != 0:
		_draw_bubble(_project(0, Model.BASKET_HEIGHT), _state.loaded, _state.gas, 1.0, false)
	for parcel: Dictionary in _state.cargo:
		_draw_bubble(_project(parcel.distance, parcel.height, parcel.lane), parcel.cargo, parcel.gas, parcel.shell, parcel.returning)

func _draw_zone(start: float, finish: float, height: float, color: Color) -> void:
	# A glass heat chamber in a copper frame, ribbed with heater rods.
	var corners := PackedVector2Array([_project(start, 0), _project(start, height), _project(finish, height), _project(finish, 0)])
	draw_colored_polygon(corners, Color(color, 0.22))
	var glow := PackedVector2Array([corners[0], corners[0].lerp(corners[1], 0.35), corners[3].lerp(corners[2], 0.35), corners[3]])
	draw_colored_polygon(glow, Color(color, 0.18))
	for fraction in [0.16, 0.4, 0.64, 0.88]:
		var distance := lerpf(start, finish, fraction)
		draw_line(_project(distance, 0.08), _project(distance, height - 0.1), Color(Props.deepen(color, 0.3), 0.7), 4.0)
		draw_line(_project(distance, 0.08) + Vector2(-1, 0), _project(distance, height - 0.1) + Vector2(-1, 0), Color(Props.lighten(color, 0.3), 0.7), 1.0)
	var ring := corners.duplicate()
	ring.append(corners[0])
	draw_polyline(ring, Props.deepen(Color("#b4704f"), 0.4), 9.0)
	draw_polyline(ring, Color("#b4704f"), 5.0)
	draw_line(corners[0], corners[1], Props.lighten(Color("#b4704f"), 0.4), 2.0)
	draw_line(corners[1], corners[2], Props.lighten(Color("#b4704f"), 0.4), 2.0)
	draw_line(corners[0].lerp(corners[2], 0.15), corners[0].lerp(corners[2], 0.35), Color(1, 1, 1, 0.25), 4.0)

func _draw_receiver(lane: int, title: String, color: Color) -> void:
	var bounds := Model.reception_range(lane, _state.assisted)
	var top := _project(_state.end, bounds.y, lane)
	var bottom := _project(_state.end, bounds.x, lane)
	var bracket := PackedVector2Array([top - Vector2(12, 0), top, bottom, bottom - Vector2(24, 0)])
	draw_polyline(bracket, Props.deepen(color, 0.45), 8.0)
	draw_polyline(bracket, color, 4.0)
	Props.contact_shadow(self, bottom + Vector2(-4, 16), 56, 0.4)
	Props.shaded_box(self, Rect2(bottom - Vector2(28, 0), Vector2(44, 12)), Props.BISCUIT, 4.0)
	_text(bottom + Vector2(4, 27), title, color, 16)

func _draw_bubble(at: Vector2, mask: int, gas: float, shell: float, returning: bool) -> void:
	var radius := 13.0 + sqrt(gas) * 11.0
	var center := at - Vector2(0, 13)
	var tint := HEAT.lerp(MINT, shell)
	if returning:
		tint = FORK
	# A blown-sugar bubble: tinted film, a deeper rim, a window glint top left.
	draw_circle(center, radius, Color(tint, 0.22), true, -1.0, true)
	draw_circle(center + Vector2(radius * 0.18, radius * 0.22), radius * 0.62, Color(Props.deepen(tint, 0.2), 0.12), true, -1.0, true)
	draw_arc(center, radius, 0, TAU, 36, Props.deepen(tint, 0.35), 2.0 + shell * 2.0 + 2.0, true)
	draw_arc(center, radius - 1.0, 0, TAU, 36, tint, 1.0 + shell * 2.0, true)
	draw_arc(center, radius - 5.0, PI * 1.1, PI * 1.6, 8, INK, 2.5, true)
	draw_rect(Rect2(center + Vector2(-radius * 0.42, -radius * 0.58), Vector2(4, 4)), INK)
	var count := Model.cargo_count(mask)
	var shown_count := 0
	for index in 3:
		if (mask & (1 << index)) != 0:
			var x := at.x + (shown_count - (count - 1) * 0.5) * 20.0
			_barrel(Vector2(x, at.y), index, 0.63)
			shown_count += 1
	if returning:
		draw_line(at + Vector2(0, 14), at + Vector2(0, 30), FORK, 2)
		draw_polyline(PackedVector2Array([at + Vector2(-5, 24), at + Vector2(0, 30), at + Vector2(5, 24)]), FORK, 2)

## Enamel syrup keg with brass hoops, rounded towards the light.
static func _keg(index: int) -> ImageTexture:
	var tone: Color = BARREL_COLORS[index]
	return Pixels.bake("bubble-keg:%d" % index, Vector2i(12, 14), func(x: int, y: int) -> Color:
		if (y == 0 or y == 13) and (x == 0 or x == 11):
			return Pixels.CLEAR
		if y == 2 or y == 11:
			return Props.BRASS if x > 2 else Props.lighten(Props.BRASS, 0.3)
		return Pixels.rounded(tone, Vector2((x - 5.5) / 6.0, -0.2 + (y - 6.5) / 20.0)))

func _barrel(at: Vector2, index: int, size: float) -> void:
	var box := Rect2(at - Vector2(13, 14) * size, Vector2(26, 28) * size)
	Props.contact_shadow(self, Vector2(at.x + 2, box.end.y + 2), box.size.x * 1.3, 0.35)
	draw_texture_rect(_keg(index), box.grow(2.0 * size), false)

func _draw_console() -> void:
	Props.wood_panel(self, CONSOLE, Props.SIGN_PLUM, true)
	_text(Vector2(947, 225), _state.course_name, INK, 20)
	var cooling: bool = _state.cool
	_text(Vector2(947, 254), "%s · %.1f 秒後%s" % ["降溫" if cooling else "高熱", _state.heat_change, "升溫" if cooling else "降溫"], MINT if cooling else HEAT, 16)
	if _state.phase == Model.DOCK:
		_draw_controls_status()
	else:
		_draw_transit_status()
	_draw_cargo_list()

func _draw_controls_status() -> void:
	_text(Vector2(947, 284), "%.1f 秒後入槽 · %s" % [_state.entry_time, "降溫" if _state.entry_cool else "高熱"], MINT if _state.entry_cool else HEAT, 16)
	_text(Vector2(947, 317), "載重 %.2f   泡量 %.2f" % [_state.load_mass, _state.gas], INK, 16)
	var strip := Rect2(947, 334, 274, 12)
	Props.bar(self, strip, _state.gas / Model.MAX_GAS, GOLD)
	if _state.loaded != 0:
		var recommended: Vector2 = _state.recommend * (strip.size.x / Model.MAX_GAS)
		draw_rect(Rect2(strip.position + Vector2(recommended.x, -4), Vector2(recommended.y - recommended.x, 19)), MINT, false, 2)
		_text(Vector2(947, 374), "綠帶對應這批桶的重量", MINT, 16)
	else:
		_text(Vector2(947, 374), "確認裝載以顯示建議泡量", MUTED, 16)

func _draw_transit_status() -> void:
	for index in _state.cargo.size():
		var parcel: Dictionary = _state.cargo[index]
		var label := "高台" if parcel.lane > 0 else ("低台" if parcel.lane < 0 else "乘籃")
		var detail := "緩降收回" if parcel.returning else "泡壁 %d%% · 泡量 %.2f" % [roundi(parcel.shell * 100.0), parcel.gas]
		_text(Vector2(947, 295 + 35 * index), "%s  %s" % [label, detail], FORK if parcel.returning else MINT.lerp(HEAT, 1.0 - parcel.shell), 16)
	if _state.can_split:
		_text(Vector2(947, 374), "可分泡 · 按 F", FORK, 17)
	elif _state.split_completed:
		_text(Vector2(947, 374), "雙泡分送成功", MINT, 17)

func _draw_cargo_list() -> void:
	_text(Vector2(947, 414), "原料桶", INK, 15)
	for index in 3:
		var x := 981.0 + index * 99.0
		var bit := 1 << index
		var delivered: bool = (_state.delivered & bit) != 0
		_barrel(Vector2(x, 444), index, 0.65)
		_text(Vector2(x - 19, 480), "到站" if delivered else "%.2f" % _state.masses[index], MINT if delivered else MUTED, 15)

func _text(at: Vector2, value: String, color: Color, size: int) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * _scale), color)
