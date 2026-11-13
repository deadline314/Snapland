extends Control
class_name ShellTideView

## 2D tide-pool close-up drawn in place. Ripple width encodes note length, a calm
## swirl marks silences, and the background beat dots belong to the helper.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const Model = preload("res://game/minigames/shell_tide_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const POOL := Rect2(24, 208, 1232, 364)
const COMMANDS := ["shell_0", "shell_1", "shell_2", "shell_3", "wait", "earlier", "later"]
const BUTTON_LABELS := ["1／A 珍珠貝", "2／S 扇貝", "3／D 海螺", "4／F 寶螺", "W 等長浪", "Q 校準提早", "E 校準延後"]
const SHELL_NAMES := ["珍珠貝", "扇貝", "海螺", "寶螺"]
const SHELL_COLORS := [Color("#f3c9b6"), Color("#f2d27a"), Color("#9fd7c8"), Color("#c9a6e8")]
const SHELL_CENTERS := [Vector2(250, 440), Vector2(500, 470), Vector2(750, 470), Vector2(1000, 440)]
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _pointer_owners: Dictionary = {}

static func button_rect(command: String) -> Rect2:
	var index := COMMANDS.find(command)
	return Rect2(28 + index * 176, 590, 168, 56) if index >= 0 else Rect2()

static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	# Shells themselves are also tap targets.
	for shell in 4:
		if point.distance_to(SHELL_CENTERS[shell]) <= 60.0:
			return "shell_%d" % shell
	return ""

static func pointer_source(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if not event.pressed:
		if not _pointer_owners.has(source):
			return false
		var command: String = _pointer_owners[source]
		_pointer_owners.erase(source)
		command_requested.emit(command, false, source)
		queue_redraw()
		return true
	if not point.is_finite():
		return false
	var command := command_at(point)
	if command.is_empty():
		return false
	if not _pointer_owners.has(source):
		_pointer_owners[source] = command
		command_requested.emit(command, true, source)
		queue_redraw()
	return true

func clear_pointer_input(emit_releases: bool = true) -> void:
	if emit_releases:
		for source in _pointer_owners:
			command_requested.emit(_pointer_owners[source], false, source)
	_pointer_owners.clear()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_pointer_input()
		command_requested.emit("clear", false, "lifecycle")

func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		point = event.position
	if handle_pointer(event, point):
		accept_event()

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS

func present(state: Dictionary, time_phase: String, reduced_motion: bool) -> void:
	_snapshot = state
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	queue_redraw()

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var phase: String = {"demo": "聽潮聲示範", "ready": "準備回應", "echo": "回應中"}.get(_snapshot.phase, "")
	return "第 %d / 3 段 · %s%s   |   %s · 每拍 %.2f 秒   |   完成 %d 段   |   延遲校準 %+d 毫秒" % [mini(int(_snapshot.phrase) + 1, 3), phase, "（等長浪）" if _snapshot.slow else "", _snapshot.variant_name, _snapshot.beat, _snapshot.passed_count, roundi(float(_snapshot.offset) * 1000.0)]

func pattern_text() -> String:
	if _snapshot.is_empty():
		return ""
	if not _snapshot.score_visible:
		return "回應時波紋譜收起；照記憶與底拍回應。輔助可保留波紋譜。"
	var parts: Array[String] = []
	for event: Dictionary in _snapshot.events:
		parts.append("靜" if event.shell < 0 else ("%s%s" % [SHELL_NAMES[event.shell], "（長）" if event.beats > 1 else ""]))
	return "波紋譜：" + "　".join(parts)

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _active_event(time: float) -> Dictionary:
	for event: Dictionary in _snapshot.get("events", []):
		if time >= event.start and time < event.start + event.duration:
			return event
	return {}

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	var night := _time_phase == "night"
	draw_rect(POOL, Color("#173a48") if night else Color("#3f8a96"))
	draw_rect(Rect2(POOL.position.x, POOL.end.y - 70, POOL.size.x, 70), Color("#c9b27f") if not night else Color("#6f6248"))
	if _snapshot.is_empty():
		return
	_text(Vector2(40, 164), status_text(), 1200)
	_text(Vector2(40, 191), pattern_text(), 1200, 17)
	_draw_score_strip()
	_draw_beat_dots()
	var time := float(_snapshot.phase_time)
	var event := _active_event(time) if _snapshot.phase in ["demo", "echo"] else {}
	for shell in 4:
		var center: Vector2 = SHELL_CENTERS[shell]
		var held: bool = _snapshot.held.has(shell)
		var lit: bool = (not event.is_empty() and event.shell == shell and _snapshot.phase == "demo") or held
		if lit and not event.is_empty() and event.shell == shell:
			var progress := clampf((time - float(event.start)) / maxf(0.01, float(event.duration)), 0.0, 1.0)
			var width := 14.0 if event.beats > 1 else 4.0
			for ring in 3:
				var radius := 50.0 + (progress * 70.0 if not _reduced_motion else 30.0) + ring * 22.0
				draw_arc(center, radius, 0, TAU, 40, Color(SHELL_COLORS[shell], 0.8 - ring * 0.25), width)
		draw_circle(center, 46.0, SHELL_COLORS[shell].darkened(0.0 if lit else 0.35))
		# Scallop ridges fan from the hinge so each shell reads as a shell, not a button.
		var hinge := center + Vector2(0, 40)
		for ridge in 7:
			var angle := lerpf(-2.5, -0.64, ridge / 6.0)
			draw_line(hinge, hinge + Vector2.from_angle(angle) * 74.0 * 0.62, SHELL_COLORS[shell].darkened(0.45), 2.0)
		draw_circle(center, 46.0, Paper.DEEP, false, 3.0)
		draw_rect(Rect2(hinge - Vector2(12, 6), Vector2(24, 10)), SHELL_COLORS[shell].darkened(0.5))
		_text(center + Vector2(-40, 76), "%d %s" % [shell + 1, SHELL_NAMES[shell]], 120, 17)
	if not event.is_empty() and event.shell < 0:
		var calm := Vector2(640, 330)
		draw_arc(calm, 30, PI * 0.1, PI * 0.9, 16, Paper.PAPER, 3)
		_text(calm + Vector2(-40, 50), "～ 靜默 ～", 120, 18, Paper.GOLD)
	var judgement: Dictionary = _snapshot.judgement
	if not judgement.is_empty():
		var text: String = "誤觸靜默" if judgement.rest else ("拍心" if judgement.perfect else "%+d ms" % judgement.error_ms)
		_text(SHELL_CENTERS[judgement.shell] + Vector2(-40, -70), text, 140, 20, Paper.GOLD)
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held_button := _pointer_owners.values().has(command)
		var unavailable: bool = command in ["earlier", "later"] and not _snapshot.assisted
		draw_rect(rect, Paper.FRAME if held_button else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held_button else (Paper.DEEP if unavailable else Paper.TEAL), false, 2)
		_text(rect.position + Vector2(10, 34), BUTTON_LABELS[i] + ("（輔助）" if unavailable else ""), rect.size.x - 16, 15, Color(Paper.PAPER, 0.55) if unavailable else Paper.PAPER)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "粗波紋是長音要按住，細波紋是短音；～靜默～那拍不要敲。底拍點是夥伴敲的背景拍。", 1210, 17)

## The ripple score: short blocks, long bars and blank rests in phrase order.
func _draw_score_strip() -> void:
	var events: Array = _snapshot.events
	var x := 300.0
	var unit := 52.0
	var show_score: bool = _snapshot.score_visible
	for event: Dictionary in events:
		var width: float = unit * event.beats - 6.0
		var rect := Rect2(x, 228, width, 26)
		if event.shell < 0:
			_text(Vector2(x + width * 0.3, 248), "～", 40, 18, Paper.PAPER)
		elif show_score:
			draw_rect(rect, SHELL_COLORS[event.shell])
			_text(rect.position + Vector2(6, 19), str(event.shell + 1), 30, 15, Paper.DEEP)
		else:
			draw_rect(rect, Color(Paper.PAPER, 0.15))
		x += unit * event.beats

## Helper's background beat: one dot per beat, the current one filled.
func _draw_beat_dots() -> void:
	var beat := float(_snapshot.beat)
	var index := int(float(_snapshot.phase_time) / maxf(0.01, beat))
	for i in 8:
		var center := Vector2(560 + i * 24, 290)
		draw_circle(center, 7.0 if i == index % 8 else 4.0, Paper.PAPER if i == index % 8 else Color(Paper.PAPER, 0.4))
