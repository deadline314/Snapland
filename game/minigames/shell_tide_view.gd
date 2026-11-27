extends Control
class_name ShellTideView

## 2D tide-pool close-up drawn in place. Ripple width encodes note length, a calm
## swirl marks silences, and the background beat dots belong to the helper.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const Model = preload("res://game/minigames/shell_tide_model.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STATUS_PLATE := Rect2(24, 140, 1232, 62)
const BUTTON_ICONS := ["shell", "shell", "shell", "shell", "wait", "left", "right"]
## Design pixels per texel of the baked pool and shells.
const TEXEL := 4.0
const SAND_HEIGHT := 70.0
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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

## The fine print stays one hover away instead of filling the screen.
func _get_tooltip(at_position: Vector2) -> String:
	if _snapshot.is_empty() or not STATUS_PLATE.has_point(at_position):
		return ""
	return "粗波紋是長音要按住，細波紋是短音；～靜默～那拍不要敲。底拍點是夥伴敲的背景拍。"

func _draw() -> void:
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_TEAL, true)
	var night := _time_phase == "night"
	Props.stamp(self, _pool_texture(night), POOL.position, TEXEL)
	if _snapshot.is_empty():
		return
	_text(Vector2(46, 166), status_text(), 1190, 17)
	_text(Vector2(46, 193), pattern_text(), 1190, 17, Paper.GOLD)
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
		Props.contact_shadow(self, center + Vector2(6, 40), 104.0, 0.55)
		var sprite := _shell_texture(shell, lit)
		var drop := Vector2(0, 4) if held else Vector2.ZERO
		Props.stamp(self, sprite, center - Vector2(sprite.get_size() - Vector2(2, 2)) * TEXEL * 0.5 + drop, TEXEL)
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
		var unavailable: bool = command in ["earlier", "later"] and not _snapshot.assisted
		Props.control_key(self, button_rect(command), _pointer_owners.values().has(command), BUTTON_ICONS[i], BUTTON_LABELS[i] + ("（輔助）" if unavailable else ""), Paper.font(), roundi(15 * Paper.text_scale()), not unavailable)
	_text(Vector2(30, 680), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)

## The tide pool, baked once per light: posterised ripple bands over a pebbly
## floor, sunlit caustic flecks, then a wet sand shelf with grit and weed.
static func _pool_texture(night: bool) -> Texture2D:
	var size := Vector2i(int(POOL.size.x / TEXEL) - 2, int(POOL.size.y / TEXEL) - 2)
	var shelf := size.y - int(SAND_HEIGHT / TEXEL)
	var water := Color("#173a48") if night else Color("#3f8a96")
	var sand := Color("#6f6248") if night else Color("#c9b27f")
	return Pixels.bake("shell-pool|%s" % night, size, func(x: int, y: int) -> Color:
		if y >= shelf:
			var down := y - shelf
			if down == 0:
				return water.lerp(Color("#eef7ee"), 0.55)
			var tone := Pixels.grainy(sand.darkened(0.18 if down < 3 else 0.0), x, y, 0.16)
			if Pixels.noise(x / 3, y / 2, 5) > 0.9:
				return tone.darkened(0.3)
			if down > 4 and Pixels.noise(x, y, 9) > 0.985:
				return Color("#5f8a4a") if not night else Color("#3a5233")
			return tone
		var depth := float(y) / float(shelf)
		var swell := sin(x * 0.11 + sin(y * 0.19) * 2.0 + y * 0.05)
		var band := floorf((swell * 0.5 + 0.5) * 3.0) / 3.0
		var tone := water.darkened(0.12 * depth).lightened(0.06 * band)
		var pebble := Pixels.noise(x / 4, y / 3, 3)
		if pebble > 0.86 and depth > 0.35:
			tone = tone.lerp(Color("#5d6b5f"), 0.35 + 0.2 * Pixels.noise(x / 4, y / 3, 4))
		# Sun flecks gather on the swell crests in short dashes.
		var fleck := Pixels.noise(x / 3, y, 7)
		if fleck > 0.9 and band > 0.6 and not night:
			tone = tone.lerp(Color("#e9f6ef"), 0.32)
		return tone)

## One baked sprite per shell kind: pearl oyster, scallop, conch and cowrie,
## each with its own silhouette and ridges, lit from the top left.
static func _shell_texture(shell: int, lit: bool) -> Texture2D:
	var base: Color = SHELL_COLORS[shell] if lit else SHELL_COLORS[shell].darkened(0.3)
	var size := Vector2i(24, 22)
	return Pixels.bake("shell-%d|%s" % [shell, lit], size, func(x: int, y: int) -> Color:
		var u := (x + 0.5) / 24.0 * 2.0 - 1.0
		var v := (y + 0.5) / 22.0 * 2.0 - 1.0
		match shell:
			0:
				# Pearl oyster: a rounded fan with growth rings and a pearly lip.
				var reach := Vector2(u, v * 1.1 + 0.05).length()
				if reach > 0.95 or v > 0.85:
					return Pixels.CLEAR
				var ring := floorf(reach * 5.0)
				var tone := Pixels.rounded(base, Vector2(u, v) * 0.9).darkened(0.08 * fmod(ring, 2.0))
				return tone.lightened(0.35) if reach > 0.82 else tone
			1:
				# Scallop: ribbed fan opening upward from a winged hinge.
				var hinge := Vector2(0, 0.82)
				var from := Vector2(u, v) - hinge
				var reach := from.length()
				if v > 0.7 and absf(u) < 0.4 and v < 0.98:
					return base.darkened(0.25 if absf(u) > 0.2 else 0.1)
				if reach > 1.7 or from.y > -0.05 or absf(from.angle() + PI * 0.5) > 1.15:
					return Pixels.CLEAR
				var rib := sin(from.angle() * 18.0)
				return Pixels.rounded(base, Vector2(u, v) * 0.8).darkened(0.2 if rib < -0.3 else 0.0).lightened(0.12 if rib > 0.7 else 0.0)
			2:
				# Conch: a knobbed crown of whorls over a body that tapers to the
				# siphon, with a pale flared lip on the right.
				if v < -0.55:
					var spire := 0.3 + (v + 1.0) * 1.2
					var knob := absf(fposmod(u * 3.0 + 0.5, 1.0) - 0.5) < 0.22 and v > -0.72
					if absf(u) > spire and not (knob and absf(u) < spire + 0.16):
						return Pixels.CLEAR
					return Pixels.rounded(base.lightened(0.1), Vector2(u, v + 0.6)).darkened(0.25 if fposmod((v + 1.0) * 6.0, 1.0) < 0.25 else 0.0)
				var width := 0.92 - (v + 0.55) * 0.55
				if absf(u + (v + 0.55) * 0.1) > width or v > 0.95:
					return Pixels.CLEAR
				if u > width * 0.35 and v < 0.35:
					return Color("#f6dcc8").lerp(base, 0.3) if u < width * 0.75 else Color("#e9a28a")
				var tone := Pixels.rounded(base, Vector2(u / maxf(0.2, width), v))
				return tone.darkened(0.28) if fposmod((v + 1.0) * 3.4 + u * 0.7, 1.0) < 0.13 else tone
		# Cowrie: a glossy oval with a toothed slit down the middle.
		var oval := Vector2(u, v * 1.25).length()
		if oval > 0.92:
			return Pixels.CLEAR
		if absf(u - v * 0.1) < 0.08:
			return base.darkened(0.55) if (y % 2) == 0 else base.darkened(0.3)
		var tone := Pixels.rounded(base, Vector2(u, v))
		return tone.lightened(0.18) if Pixels.noise(x / 2, y / 2, shell) > 0.82 else tone)

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
			Props.shaded_box(self, rect, SHELL_COLORS[event.shell], 4.0)
			_text(rect.position + Vector2(6, 17), str(event.shell + 1), 30, 15, Paper.DEEP)
		else:
			draw_rect(rect, Color(Paper.PAPER, 0.15))
		x += unit * event.beats

## Helper's background beat: one dot per beat, the current one filled.
func _draw_beat_dots() -> void:
	var beat := float(_snapshot.beat)
	var index := int(float(_snapshot.phase_time) / maxf(0.01, beat))
	for i in 8:
		var center := Vector2(560 + i * 24, 290)
		if i == index % 8:
			Props.token(self, center, 7.0, Paper.PAPER)
		else:
			draw_circle(center, 4.0, Color(Paper.PAPER, 0.4))
