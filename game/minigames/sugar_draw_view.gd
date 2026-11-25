extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/sugar_draw_model.gd")
const ART := "res://assets/minigames/sugar-draw-workbench.webp"
const BENCH := Rect2(35, 192, 871, 320)
const RECIPE := Rect2(927, 192, 317, 320)
const INK := Color("#fff0dc")
const GOLD := Color("#ffd281")
const GREEN := Color("#a9ebc0")
const RED := Color("#ffa387")
const MUTED := Color("#b49aa7")
enum { SLOW, STEADY, FAST, HEAT, CUT, FOLD, DISCARD, HELPER }
const LABELS := ["慢拉 · A", "穩拉 · S", "快拉 · D", "加熱 · W", "收段 · Space", "回折 · F", "退料 · X", "控溫 AI · R"]
const HINTS := ["按住慢拉，糖絲較粗", "按住以中速抽絲", "按住快拉，糖絲較細", "按住加熱，留意過熱",
	"滿一倍長度且絲徑合格時收段", "過細段滿兩倍長時，可對折成雙股", "退回未收段，已完成段保留", "讓 AI 在安全溫區內加熱"]

var _state: Dictionary = {}
var _texture: Texture2D

func _ready() -> void:
	build_controls(LABELS, Color("#493544"), Color("#654b4c"), MUTED, GOLD)
	if ResourceLoader.exists(ART):
		_texture = load(ART) as Texture2D
	_refresh()

func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	return HINTS[slot] if slot >= 0 else ""

func present(state: Dictionary) -> void:
	_state = state
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if _state.is_empty():
		return
	refresh_font()
	for index in 3:
		_buttons[index].set_pressed_no_signal(_state.pull == index + 1)
	_buttons[HEAT].set_pressed_no_signal(_state.heating)
	_buttons[CUT].set_pressed_no_signal(_state.cut_ready)
	_buttons[FOLD].set_pressed_no_signal(_state.fold_ready)
	_buttons[HELPER].set_pressed_no_signal(_state.helper)
	queue_redraw()

func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(34, 166), _state.feedback, GOLD, 18)
	draw_rect(BENCH.grow(2), MUTED)
	draw_rect(BENCH, Color("#2c2639"))
	if is_instance_valid(_texture):
		draw_texture_rect(_texture, BENCH, false)
	_draw_strand()
	_draw_readouts()
	_draw_recipe()

func _draw_strand() -> void:
	var start := Vector2(113, 343)
	var origin := start
	draw_rect(Rect2(origin - Vector2(40, 46), Vector2(55, 92)), Color("#7b4c46"))
	draw_rect(Rect2(origin - Vector2(33, 38), Vector2(36, 76)), Color("#342636"))
	draw_line(origin - Vector2(22, 25), origin + Vector2(-22, 25), RED if _state.heating else GOLD, 7)
	var line_span := 139.0
	for section: Dictionary in _state.sections:
		var finish := start + Vector2(line_span, 0)
		if section.folded:
			draw_line(start + Vector2(0, -4), finish + Vector2(0, -4), GOLD, section.width * 8.0, true)
			draw_line(start + Vector2(0, 4), finish + Vector2(0, 4), GREEN, section.width * 8.0, true)
		else:
			draw_line(start, finish, GOLD, section.width * 11.0, true)
		draw_line(finish - Vector2(0, 16), finish + Vector2(0, 16), GREEN, 2.0)
		start = finish
	var extent: float = _state.length / (2.0 * _state.goal_length)
	var stretch := 310.0
	var samples: PackedFloat32Array = _state.samples
	for index in samples.size():
		var a := start + Vector2(float(index) * stretch / 24.0, 0)
		var b := start + Vector2(minf(extent, float(index + 1) / 24.0) * stretch, 0)
		var width := samples[index]
		var band: Vector2 = _state.band
		draw_line(a, b, GREEN if width >= band.x and width <= band.y else RED, width * 11.0, true)
	if not _state.ended:
		var grip := start + Vector2(extent * stretch, 0)
		draw_rect(Rect2(grip - Vector2(8, 19), Vector2(19, 38)), Color("#98736b"))
		draw_rect(Rect2(grip + Vector2(10, -5), Vector2(27, 10)), INK)
		_draw_length_meter(start + Vector2(0, 67), stretch, extent)

func _draw_length_meter(at: Vector2, span: float, extent: float) -> void:
	var strip := Rect2(at, Vector2(span, 9))
	draw_rect(strip.grow(4), Color("#302b3c"))
	draw_rect(strip, Color("#705768"))
	draw_rect(Rect2(at, Vector2(span * extent, 9)), GOLD)
	draw_line(at + Vector2(span * 0.5, -5), at + Vector2(span * 0.5, 16), GREEN, 3)
	draw_line(at + Vector2(span, -5), at + Vector2(span, 16), GOLD, 3)
	_text(at + Vector2(0, 41), "%.2f / %.2f m" % [_state.length, _state.goal_length], INK, 16)
	_text(at + Vector2(span * 0.5 - 18, 41), "收段長", GREEN, 15)
	_text(at + Vector2(span - 38, 41), "回折長", GOLD, 15)

func _draw_readouts() -> void:
	draw_rect(Rect2(58, 210, 755, 65), Color("#211d2d", 0.88))
	var thermal: float = _state.temperature
	var temperature_color := RED if thermal >= Model.MELT_POINT or thermal < Model.THERMAL_MIN else GREEN
	var at := Vector2(72, 237)
	_gauge(at, thermal / 1.08, temperature_color, "溫度 %d%%" % roundi(thermal * 100.0))
	var tension: float = _state.tension
	_gauge(Vector2(307, 237), tension / 1.43, RED if tension > 0.91 else GOLD, "拉力 %.2f" % tension)
	var width_text := "絲徑 %.2f  ·  回折 %.2f" % [_state.avg_width, _state.avg_width * Model.FOLD_FACTOR]
	_text(Vector2(558, 236), width_text, GREEN if _state.fold_ready else INK, 16)
	if _state.damage > 0.0:
		_text(Vector2(558, 264), "滴落風險" if thermal >= Model.MELT_POINT else "斷絲風險", RED, 16)

func _gauge(at: Vector2, fraction: float, tint: Color, label: String) -> void:
	_text(at, label, tint, 16)
	var strip := Rect2(at + Vector2(0, 13), Vector2(158, 9))
	draw_rect(strip, Color("#735c6b"))
	draw_rect(Rect2(strip.position, Vector2(158 * clampf(fraction, 0.0, 1.0), 9)), tint)

func _draw_recipe() -> void:
	draw_rect(RECIPE, Color("#352836"))
	draw_rect(RECIPE, MUTED, false, 2)
	_text(Vector2(946, 227), _state.name, INK, 20)
	for index in 3:
		var y := 249.0 + index * 63.0
		var color := GREEN if index < _state.sections.size() else (GOLD if index == _state.sections.size() else MUTED)
		var box := Rect2(944, y, 283, 49)
		draw_rect(box, Color("#473645"))
		draw_rect(box, color, false, 2)
		_text(box.position + Vector2(12, 31), "第 %d 段   %.2f  ·  %.2f m" % [index + 1, _state.target_widths[index], _state.target_lengths[index]], color, 16)
	var limits: Vector2 = _state.band
	_text(Vector2(946, 459), "允許絲徑 %.2f–%.2f" % [limits.x, limits.y], INK, 16)
	_text(Vector2(946, 491), "可回折為雙股" if _state.fold_ready else ("可以收段" if _state.cut_ready else "收段前看長度與絲徑"), GREEN if _state.fold_ready or _state.cut_ready else MUTED, 16)

func _text(at: Vector2, value: String, color: Color, size: int) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * _scale), color)
