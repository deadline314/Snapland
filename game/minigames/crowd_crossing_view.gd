extends Control
class_name CrowdCrossingView

## Compact, top-down crossing playfield. The first and last screen bands remain
## transparent for the shared HUD; all geometry stays within the local 1280×720.

const FIELD_RECT := Rect2(80.0, 160.0, 1120.0, 455.0)
const CROSSING_CENTER := Vector2(640.0, 410.0)
const PERIOD_SECONDS := 2.2
const HORIZONTAL_SIGNAL := Vector2(520.0, 235.0)
const VERTICAL_SIGNAL := Vector2(760.0, 235.0)
const SIGNAL_HIT_RADIUS := 64.0
const PERSON_COLORS: Array[Color] = [Color("#c66f60"), Color("#437f83"), Color("#bd8a4d"), Color("#657da2"), Color("#8e6d91"), Color("#73865d")]
const PERSON_SKIN: Array[Color] = [Color("#e6ae86"), Color("#bd8266"), Color("#f0c69e"), Color("#d99d78"), Color("#e7c1a0"), Color("#b87961")]
const PERSON_HATS: Array[Color] = [Color("#e4bd71"), Color("#d9e5d4"), Color("#514e55"), Color("#c78372"), Color("#7a9ca0"), Color("#ede0c7")]
const ISLAND_RECTS: Array[Rect2] = [
	Rect2(118.0, 168.0, 410.0, 155.0), Rect2(752.0, 168.0, 410.0, 155.0),
	Rect2(118.0, 497.0, 410.0, 108.0), Rect2(752.0, 497.0, 410.0, 108.0)
]
const CURB_POINTS: Array[Vector2] = [Vector2(550, 386), Vector2(730, 434), Vector2(610, 326), Vector2(668, 484)]
const CROSSFALL_MARKS: Array[Vector2] = [Vector2(218, 304), Vector2(422, 304), Vector2(858, 304), Vector2(1062, 304), Vector2(218, 522), Vector2(422, 522), Vector2(858, 522), Vector2(1062, 522)]

var _selected_lane := 0
var _resolved_count := 0
var _mistakes := 0
var _elapsed := 0.0
var _reduced_motion := false
var _phase_id := "noon"
var _ended := false
var _crossing_lane := 0
var _crossing_progress := 0.0
var _pedestrian_motion := 0.0
var _field_color := Color("#d8c39e")
var _road_color := Color("#647178")
var _island_color := Color("#d4b98c")
var _shadow_alpha := 0.16
var _traffic_snapshot: Dictionary = {}
var _traffic_state_enabled := false
var _traffic_revision := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func present(lane: int, count: int, mistakes: int, elapsed: float, reduced_motion: bool, time_phase: String, ended: bool) -> void:
	_traffic_state_enabled = false
	_selected_lane = clampi(lane, 0, 1)
	_resolved_count = clampi(count, 0, 6)
	_mistakes = clampi(mistakes, 0, _resolved_count)
	_elapsed = maxf(0.0, elapsed)
	_reduced_motion = reduced_motion
	_ended = ended or _resolved_count >= 6
	_crossing_lane = _resolved_count % 2
	_phase_id = _normalize_phase(time_phase)
	_apply_palette()
	if _ended:
		_crossing_progress = 0.0
		_pedestrian_motion = 0.0
	elif not _reduced_motion:
		_crossing_progress = fposmod(_elapsed, PERIOD_SECONDS) / PERIOD_SECONDS
		_pedestrian_motion = _crossing_progress
	queue_redraw()

## State-driven API for CrowdTrafficModel. Queue actors are stationary behind
## their red stop lines; only the group's authored crossing path advances.
func present_state(snapshot: Dictionary, elapsed: float, reduced_motion: bool, time_phase: String) -> void:
	_traffic_state_enabled = true
	var revision := int(snapshot.get("revision", 0))
	if _traffic_revision != revision:
		# The model owns a stable, read-only snapshot. Keep its reference and its
		# bounded queue arrays; only refresh the reference when a transition occurs.
		_traffic_snapshot = snapshot
		_traffic_revision = revision
	_elapsed = maxf(0.0, elapsed)
	_reduced_motion = reduced_motion
	_phase_id = _normalize_phase(time_phase)
	_apply_palette()
	_resolved_count = clampi(int(snapshot.get("safe_count", 0)) + int(snapshot.get("missed_count", 0)), 0, 6)
	_mistakes = clampi(int(snapshot.get("missed_count", 0)), 0, _resolved_count)
	_ended = bool(snapshot.get("finished", false))
	var indicated_lane := int(snapshot.get("signal_lane", -1))
	if indicated_lane < 0:
		indicated_lane = int(snapshot.get("desired_lane", -1))
	_selected_lane = indicated_lane if indicated_lane == 0 or indicated_lane == 1 else -1
	var active: Dictionary = snapshot.get("active", {})
	_crossing_lane = int(active.get("lane", _selected_lane))
	_crossing_progress = float(snapshot.get("active_progress", 0.0)) if str(snapshot.get("phase", "red")) == "walk" else 0.0
	_pedestrian_motion = _crossing_progress
	queue_redraw()

func pointerSignalAt(point: Vector2) -> int:
	if point.distance_squared_to(HORIZONTAL_SIGNAL) <= SIGNAL_HIT_RADIUS * SIGNAL_HIT_RADIUS:
		return 0
	if point.distance_squared_to(VERTICAL_SIGNAL) <= SIGNAL_HIT_RADIUS * SIGNAL_HIT_RADIUS:
		return 1
	return -1

func _normalize_phase(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == "day" or normalized == "daytime":
		return "noon"
	return normalized if normalized == "dawn" or normalized == "noon" or normalized == "dusk" or normalized == "night" else "noon"

func _apply_palette() -> void:
	match _phase_id:
		"dawn":
			_field_color = Color("#c8c1ac"); _road_color = Color("#626f79"); _island_color = Color("#d2b28e"); _shadow_alpha = 0.13
		"noon":
			_field_color = Color("#d8c39e"); _road_color = Color("#647178"); _island_color = Color("#d4b98c"); _shadow_alpha = 0.17
		"dusk":
			_field_color = Color("#b39a8a"); _road_color = Color("#555e6b"); _island_color = Color("#c6a080"); _shadow_alpha = 0.2
		"night":
			_field_color = Color("#617081"); _road_color = Color("#394858"); _island_color = Color("#827f82"); _shadow_alpha = 0.28

func _draw() -> void:
	_draw_field_and_islands()
	_draw_roads_and_zebra()
	_draw_signal_targets()
	_draw_completed_pennants()
	if not _ended:
		_draw_queue_and_crossing()

func _draw_completed_pennants() -> void:
	# Six ticks identify resolved walk cycles; green marks the real safe tally and
	# coral marks the current Session mistake tally, including on the final screen.
	for index in _resolved_count:
		var tick_center := Vector2(466.0 + index * 58.0, 523.0)
		var safe := index < _resolved_count - _mistakes
		var pennant_color := Color("#69ad96") if safe else Color("#dc8d79")
		draw_circle(tick_center, 9.0, pennant_color)
		if safe:
			draw_line(tick_center + Vector2(-4.0, 0.0), tick_center + Vector2(-1.0, 3.0), Color("#fff3d5"), 2.5)
			draw_line(tick_center + Vector2(-1.0, 3.0), tick_center + Vector2(5.0, -4.0), Color("#fff3d5"), 2.5)
		else:
			draw_line(tick_center + Vector2(-3.0, -3.0), tick_center + Vector2(3.0, 3.0), Color("#fff3d5"), 2.5)
			draw_line(tick_center + Vector2(3.0, -3.0), tick_center + Vector2(-3.0, 3.0), Color("#fff3d5"), 2.5)

func _draw_field_and_islands() -> void:
	# Salt-worn timber pier, raised stone quay and planted lookout pockets give the
	# crossing a harbor scale instead of a flat test-board grid.
	draw_rect(FIELD_RECT.grow(6.0), Color("#34494d", _shadow_alpha + 0.08), true)
	draw_rect(FIELD_RECT, Color("#9d8b70"), true)
	draw_rect(Rect2(88.0, 166.0, 1104.0, 442.0), _field_color, true)
	draw_rect(Rect2(88.0, 166.0, 1104.0, 8.0), Color("#e0c99f", 0.82), true)
	# A few long, broken plank seams suggest depth without a tiled checker pattern.
	for seam in 6:
		var y := 179.0 + float(seam) * 67.0
		_draw_dashed_line(Vector2(105.0, y), Vector2(1175.0, y), Color("#755f4e", 0.13), 2.0, 126.0, 42.0)
	for point in CROSSFALL_MARKS:
		draw_arc(point, 18.0, 0.12, PI - 0.12, 22, Color("#e7d2ad", 0.32), 2.0)
	for index in ISLAND_RECTS.size():
		var island: Rect2 = ISLAND_RECTS[index]
		_draw_rounded_plaza(island, Color("#8e8b6f", 0.42), 19.0)
		_draw_rounded_plaza(island.grow(-5.0), _island_color, 16.0)
		draw_rect(Rect2(island.position + Vector2(24.0, 13.0), Vector2(island.size.x - 48.0, 3.0)), Color("#f4dfb8", 0.68), true)
		_draw_planter(Vector2(island.position.x + 44.0, island.position.y + 43.0), index)
		_draw_planter(Vector2(island.end.x - 45.0, island.end.y - 39.0), index + 1)
		_draw_lamp(Vector2(island.end.x - 60.0, island.position.y + 39.0))
		_draw_canopy_shadow(Vector2(island.position.x + island.size.x * 0.54, island.position.y + island.size.y * 0.53), index)
	# Mooring bollards and a tide stripe anchor the upper corners as quay edges.
	_draw_bollard(Vector2(103.0, 184.0)); _draw_bollard(Vector2(1177.0, 184.0))
	_draw_bollard(Vector2(103.0, 590.0)); _draw_bollard(Vector2(1177.0, 590.0))

func _draw_rounded_plaza(rect: Rect2, color: Color, radius: float) -> void:
	var inset := Vector2(radius, 0.0)
	draw_rect(Rect2(rect.position + inset, Vector2(rect.size.x - radius * 2.0, rect.size.y)), color, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y - radius * 2.0)), color, true)
	draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)

func _draw_roads_and_zebra() -> void:
	# Layered asphalt, pale curb caps, drainage seams, and recessed crossings.
	draw_rect(Rect2(128.0, 336.0, 1104.0, 145.0), Color("#3b4549", _shadow_alpha + 0.12), true)
	draw_rect(Rect2(126.0, 334.0, 1108.0, 139.0), Color("#d8c9aa"), true)
	draw_rect(Rect2(128.0, 338.0, 1104.0, 129.0), _road_color, true)
	draw_rect(Rect2(564.0, 184.0, 148.0, 424.0), Color("#3b4549", _shadow_alpha + 0.12), true)
	draw_rect(Rect2(560.0, 182.0, 156.0, 428.0), Color("#d8c9aa"), true)
	draw_rect(Rect2(564.0, 184.0, 148.0, 424.0), _road_color, true)
	# Soft quay-edge highlights and drain cuts add height cues at the sidewalk.
	draw_rect(Rect2(128.0, 334.0, 1104.0, 4.0), Color("#f0dfba", 0.92), true)
	draw_rect(Rect2(128.0, 467.0, 1104.0, 5.0), Color("#39464a", 0.72), true)
	draw_rect(Rect2(560.0, 182.0, 156.0, 4.0), Color("#f0dfba", 0.92), true)
	draw_rect(Rect2(560.0, 606.0, 156.0, 4.0), Color("#39464a", 0.72), true)
	# Lane guides are broken and offset, not a dense graph-paper grid.
	_draw_dashed_line(Vector2(160.0, 353.0), Vector2(560.0, 353.0), Color("#eee1c5", 0.54), 2.0, 38.0, 31.0)
	_draw_dashed_line(Vector2(716.0, 353.0), Vector2(1200.0, 353.0), Color("#eee1c5", 0.54), 2.0, 38.0, 31.0)
	_draw_dashed_line(Vector2(160.0, 452.0), Vector2(560.0, 452.0), Color("#eee1c5", 0.43), 2.0, 38.0, 31.0)
	_draw_dashed_line(Vector2(716.0, 452.0), Vector2(1200.0, 452.0), Color("#eee1c5", 0.43), 2.0, 38.0, 31.0)
	var horizontal_alpha := 0.9 if _selected_lane == 0 else 0.28
	var vertical_alpha := 0.9 if _selected_lane == 1 else 0.28
	# Only the selected walkway receives crisp white paint; inactive stripes recede.
	for stripe in 7:
		var x := 584.0 + stripe * 18.0
		draw_rect(Rect2(x + 2.0, 349.0, 12.0, 111.0), Color("#f8edda", horizontal_alpha), true)
		draw_rect(Rect2(x + 2.0, 349.0, 12.0, 111.0), Color("#fff9e8", 0.16), false, 1.0)
	for stripe in 6:
		var y := 360.0 + stripe * 18.0
		draw_rect(Rect2(570.0, y + 2.0, 136.0, 12.0), Color("#f8edda", vertical_alpha), true)
		draw_rect(Rect2(570.0, y + 2.0, 136.0, 12.0), Color("#fff9e8", 0.16), false, 1.0)
	# Raised tactile curb pads and ramp cheeks locate the four safe approaches.
	for point in CURB_POINTS:
		draw_rect(Rect2(point - Vector2(19.0, 9.0) + Vector2(2.0, 3.0), Vector2(38.0, 18.0)), Color("#584f47", 0.3), true)
		draw_rect(Rect2(point - Vector2(19.0, 9.0), Vector2(38.0, 18.0)), Color("#d5a966"), true)
		draw_rect(Rect2(point - Vector2(15.0, 5.0), Vector2(30.0, 10.0)), Color("#f5d9a3"), true)
		for dot in 4:
			draw_circle(point + Vector2(-9.0 + dot * 6.0, 0.0), 1.8, Color("#826b55"))
	_draw_direction_chevron(Vector2(450.0, 406.0), Vector2.RIGHT, Color("#f4e2bc", 0.8))
	_draw_direction_chevron(Vector2(830.0, 414.0), Vector2.LEFT, Color("#f4e2bc", 0.8))
	_draw_direction_chevron(Vector2(626.0, 274.0), Vector2.DOWN, Color("#f4e2bc", 0.8))
	_draw_direction_chevron(Vector2(682.0, 530.0), Vector2.UP, Color("#f4e2bc", 0.8))

func _draw_signal_targets() -> void:
	var needed := _crossing_lane
	var current := int(_traffic_snapshot.get("signal_lane", -1)) if _traffic_state_enabled else _selected_lane
	var walk_open := str(_traffic_snapshot.get("phase", "red")) == "walk" if _traffic_state_enabled else false
	_draw_signal(HORIZONTAL_SIGNAL, 0, needed == 0, current == 0 and walk_open)
	_draw_signal(VERTICAL_SIGNAL, 1, needed == 1, current == 1 and walk_open)

func _draw_signal(center: Vector2, lane_id: int, requested: bool, open: bool = false) -> void:
	var selected := lane_id == _selected_lane
	var signal_color := Color("#78c5aa") if open else Color("#dc8a70") if selected else Color("#817665")
	# The brass post grows out of the quay; the lens remains large enough to tap.
	draw_circle(center + Vector2(5.0, 77.0), 18.0, Color("#38474a", _shadow_alpha + 0.08))
	draw_circle(center + Vector2(0.0, 72.0), 15.0, Color("#87775f"))
	draw_circle(center + Vector2(0.0, 70.0), 10.0, Color("#d5be92"))
	draw_line(center + Vector2(0.0, 50.0), center + Vector2(0.0, 70.0), Color("#554d47"), 7.0, true)
	draw_line(center + Vector2(-2.0, 53.0), center + Vector2(-2.0, 68.0), Color("#e5cf9f", 0.7), 2.0, true)
	# Cast shadow, inset lens and arrow pair distinguish direction by shape as well as color.
	draw_circle(center + Vector2(4.0, 6.0), 61.0, Color("#332f32", _shadow_alpha + 0.1))
	draw_circle(center, 59.0, Color("#f2e2c0"))
	draw_circle(center, 52.0, Color("#444d52"))
	draw_circle(center, 42.0, signal_color)
	draw_arc(center, 48.0, 0.0, TAU, 48, Color("#fff0cf", 0.9) if requested or open else Color("#bba98d", 0.8), 4.0)
	if lane_id == 0:
		_draw_bold_arrow(center + Vector2(-13.0, 0.0), Vector2.LEFT, Color("#fff8e6"))
		_draw_bold_arrow(center + Vector2(13.0, 0.0), Vector2.RIGHT, Color("#fff8e6"))
	else:
		_draw_bold_arrow(center + Vector2(0.0, -13.0), Vector2.UP, Color("#fff8e6"))
		_draw_bold_arrow(center + Vector2(0.0, 13.0), Vector2.DOWN, Color("#fff8e6"))
	if selected:
		draw_arc(center, 65.0, 0.0, TAU, 48, Color("#f8d78f"), 5.0)

func _draw_queue_and_crossing() -> void:
	if _traffic_state_enabled:
		_draw_traffic_state()
		return
	var progress := _crossing_progress
	var moving := smoothstep(0.66, 0.96, progress)
	var bob := 0.0 if _reduced_motion else sin(_elapsed * 6.0) * 2.2
	for person_index in 3:
		var center: Vector2
		var heading: Vector2
		if _crossing_lane == 0:
			var start := Vector2(555.0 + person_index * 27.0, 384.0 + bob + person_index * 22.0)
			var end := Vector2(725.0 + person_index * 27.0, 384.0 + bob + person_index * 22.0)
			center = start.lerp(end, moving)
			heading = Vector2.RIGHT
		else:
			var start := Vector2(600.0 + person_index * 30.0, 326.0 + bob + person_index * 12.0)
			var end := Vector2(600.0 + person_index * 30.0, 494.0 + bob + person_index * 12.0)
			center = start.lerp(end, moving)
			heading = Vector2.DOWN
		_draw_person(center, heading, person_index)
	if not _ended:
		_draw_waiting_markers()

func _draw_traffic_state() -> void:
	var queues: Array = _traffic_snapshot.get("queues")
	for lane in 2:
		var lane_queue: Array = queues[lane]
		for queue_index in mini(lane_queue.size(), 3):
			var group: Dictionary = lane_queue[queue_index]
			var people := clampi(int(group.get("people", 1)), 1, 4)
			var rescue := bool(group.get("rescue", false))
			var patience := float(group.get("patience_remaining", 0.0))
			for person_index in people:
				var center := _queue_person_position(lane, queue_index, person_index, people)
				_draw_person(center, Vector2.RIGHT if lane == 0 else Vector2.DOWN, (person_index + int(group.get("id", 0))) % PERSON_COLORS.size(), false, rescue and person_index == 0)
			# Patience is a shrinking, shaped bar, not a color-only indication.
			var patience_center := _queue_person_position(lane, queue_index, 0, people) + Vector2(0.0, 23.0)
			draw_rect(Rect2(patience_center - Vector2(18.0, 2.0), Vector2(36.0, 5.0)), Color("#514b47"), true)
			draw_rect(Rect2(patience_center - Vector2(18.0, 2.0), Vector2(36.0 * clampf(patience / (3.5 if rescue else 5.5), 0.0, 1.0), 5.0)), Color("#e5bd72"), true)
	var active: Dictionary = _traffic_snapshot.get("active")
	var phase := str(_traffic_snapshot.get("phase", "red"))
	if not active.is_empty() and phase == "walk":
		var lane := int(active.get("lane", 0))
		var progress := clampf(_crossing_progress, 0.0, 1.0)
		var people := clampi(int(active.get("people", 1)), 1, 4)
		for person_index in people:
			var center := _active_person_position(lane, person_index, progress)
			if not _reduced_motion:
				center += Vector2(0.0, sin(_elapsed * 7.0 + person_index) * 1.5)
			_draw_person(center, Vector2.RIGHT if lane == 0 else Vector2.DOWN, person_index + int(active.get("id", 0)), true, bool(active.get("rescue", false)) and person_index == 0)
	elif not active.is_empty() and (phase == "clearance" or phase == "all_red"):
		var lane := int(active.get("lane", 0))
		for person_index in clampi(int(active.get("people", 1)), 1, 4):
			var center := Vector2(725.0, 384.0 + person_index * 20.0) if lane == 0 else Vector2(600.0 + person_index * 28.0, 494.0)
			_draw_person(center, Vector2.RIGHT if lane == 0 else Vector2.DOWN, person_index + int(active.get("id", 0)), false, bool(active.get("rescue", false)) and person_index == 0)
	_draw_phase_badge(phase, float(_traffic_snapshot.get("phase_time", 0.0)))

func _queue_person_position(lane: int, queue_index: int, person_index: int, group_size: int) -> Vector2:
	var spread := (float(person_index) - float(group_size - 1) * 0.5) * 23.0
	if lane == 0:
		return Vector2(538.0 - queue_index * 54.0, 405.0 + spread)
	return Vector2(640.0 + spread, 314.0 - queue_index * 45.0)

func _active_person_position(lane: int, person_index: int, progress: float) -> Vector2:
	var center := Vector2(640.0, 410.0)
	if lane == 0:
		center = Vector2(555.0, 384.0 + person_index * 20.0).lerp(Vector2(725.0, 384.0 + person_index * 20.0), clampf(progress, 0.0, 1.0))
	else:
		center = Vector2(600.0 + person_index * 28.0, 326.0).lerp(Vector2(600.0 + person_index * 28.0, 494.0), clampf(progress, 0.0, 1.0))
	return center

func _person_stride(index: int, walking: bool) -> float:
	if _reduced_motion or not walking:
		return 0.0
	return sin(_elapsed * 8.0 + float(posmod(index, PERSON_COLORS.size())) * 1.2) * 4.0

func _stretcher_center(center: Vector2, heading: Vector2) -> Vector2:
	var forward := heading.normalized()
	var perpendicular := Vector2(-forward.y, forward.x)
	return center + perpendicular * -13.0

func _draw_phase_badge(phase: String, phase_time: float) -> void:
	var queues: Array = _traffic_snapshot.get("queues")
	var has_waiting: bool = not queues[0].is_empty() or not queues[1].is_empty()
	var label := ("紅燈｜選擇一側放行" if has_waiting else "紅燈｜等待人群到達") if phase == "red" else "行人通行" if phase == "walk" else "清空路口" if phase == "clearance" else "全紅切換" if phase == "all_red" else "本輪完成"
	var center := Vector2(640.0, 568.0)
	draw_rect(Rect2(center - Vector2(118.0, 18.0), Vector2(236.0, 36.0)), Color("#fff0d4", 0.94), true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-label.length() * 7.0, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#35434a"))
	if phase == "clearance" or phase == "all_red":
		var duration := 0.35 if phase == "clearance" else 0.25
		var ratio := clampf(phase_time / duration, 0.0, 1.0)
		draw_rect(Rect2(550.0, 592.0, 180.0, 5.0), Color("#514b47"), true)
		draw_rect(Rect2(550.0, 592.0, 180.0 * ratio, 5.0), Color("#e5bd72"), true)

func _draw_waiting_markers() -> void:
	var remaining := 6 - _resolved_count
	for index in mini(remaining, 3):
		var center := Vector2(470.0 + index * 56.0, 553.0)
		draw_circle(center, 4.0, Color("#f0d7a7", 0.64))

func _draw_person(center: Vector2, heading: Vector2, index: int, walking: bool = true, rescue: bool = false) -> void:
	var person_index := posmod(index, PERSON_COLORS.size())
	var body_color: Color = PERSON_COLORS[person_index]
	var skin: Color = PERSON_SKIN[person_index]
	var hat: Color = PERSON_HATS[person_index]
	var forward := heading.normalized()
	var motion := _person_stride(person_index, walking)
	var body_center := center + forward * (1.0 if walking else 0.0)
	var perp := Vector2(-forward.y, forward.x)
	draw_circle(body_center + Vector2(4.0, 7.0), 13.0, Color("#263a3e", _shadow_alpha + 0.11))
	# A three-quarter figure: jacket, paired legs and shoes, head, brimmed hat,
	# shoulder strap, and a position-responsive stride make each guest legible.
	draw_line(body_center - forward * 1.0 + perp * 3.0, body_center - forward * 9.0 + perp * 4.0 + forward * motion, Color("#4b4240"), 4.0, true)
	draw_line(body_center - forward * 1.0 - perp * 3.0, body_center - forward * 9.0 - perp * 4.0 - forward * motion, Color("#4b4240"), 4.0, true)
	draw_circle(body_center - forward * 9.0 + perp * 4.0 + forward * motion, 2.7, Color("#e4d7bc"))
	draw_circle(body_center - forward * 9.0 - perp * 4.0 - forward * motion, 2.7, Color("#e4d7bc"))
	draw_circle(body_center, 8.5, Color("#4d4744", 0.74))
	draw_circle(body_center, 7.2, body_color)
	draw_line(body_center + perp * 5.0, body_center - forward * 5.0 + perp * 7.0, body_color.lightened(0.16), 2.5, true)
	draw_line(body_center - perp * 5.0, body_center - forward * 4.0 - perp * 7.0, body_color.darkened(0.12), 2.5, true)
	var head := body_center + forward * 8.0
	draw_circle(head, 5.4, Color("#564943"))
	draw_circle(head + forward * 0.7, 4.4, skin)
	draw_circle(head - forward * 1.3, 5.3, hat)
	draw_line(head + forward * 0.7 - perp * 3.2, head + forward * 0.7 + perp * 3.2, hat.darkened(0.2), 2.0, true)
	draw_circle(head + forward * 3.0 + perp * 1.2, 0.8, Color("#51453e"))
	if rescue:
		# The fourth group carries a clearly marked stretcher beside its medic.
		var stretcher_center := _stretcher_center(body_center, forward)
		draw_line(stretcher_center - forward * 10.0, stretcher_center + forward * 10.0, Color("#554b43"), 2.5, true)
		draw_line(stretcher_center - forward * 8.0 + perp * -2.0, stretcher_center + forward * 8.0 + perp * -2.0, Color("#d9e4d9"), 6.0, true)
		draw_line(stretcher_center + forward * 3.0 + perp * -2.0, stretcher_center + forward * 8.0 + perp * -2.0, Color("#bd5650"), 2.0, true)
		draw_line(stretcher_center + forward * 5.5 + perp * -4.5, stretcher_center + forward * 5.5, Color("#bd5650"), 2.0, true)
		draw_line(body_center + perp * 5.0, body_center - forward * 1.0 + perp * 9.0, Color("#f2ddab"), 3.0, true)

func _draw_planter(center: Vector2, variant: int) -> void:
	var pot := Color("#bd8766") if variant % 2 == 0 else Color("#8e9b7c")
	draw_rect(Rect2(center + Vector2(-17.0, -11.0), Vector2(34.0, 25.0)), Color("#453f3d", _shadow_alpha), true)
	draw_rect(Rect2(center + Vector2(-15.0, -13.0), Vector2(30.0, 22.0)), pot, true)
	draw_rect(Rect2(center + Vector2(-18.0, -16.0), Vector2(36.0, 6.0)), Color("#f2d6a6"), true)
	for leaf_index in 5:
		var angle := TAU * float(leaf_index) / 5.0
		var leaf := center + Vector2(cos(angle) * 13.0, sin(angle) * 9.0 - 16.0)
		draw_line(center + Vector2(0.0, -12.0), leaf, Color("#548d77"), 3.0)
		draw_circle(leaf, 4.0, Color("#73a98c") if leaf_index % 2 == 0 else Color("#d78c79"))

func _draw_lamp(center: Vector2) -> void:
	draw_circle(center + Vector2(4.0, 6.0), 20.0, Color("#3d4244", _shadow_alpha))
	draw_circle(center, 13.0, Color("#75654f"))
	draw_circle(center + Vector2(0.0, -1.0), 8.0, Color("#f0cb80", 0.78))
	draw_circle(center, 3.0, Color("#fff0bd"))

func _draw_canopy_shadow(center: Vector2, variant: int) -> void:
	var span := 37.0 + float(variant % 2) * 8.0
	draw_rect(Rect2(center + Vector2(-span, -8.0), Vector2(span * 2.0, 24.0)), Color("#42484a", _shadow_alpha))
	draw_rect(Rect2(center + Vector2(-span, -12.0), Vector2(span * 2.0, 9.0)), Color("#b88368"))
	draw_line(center + Vector2(-span, -9.0), center + Vector2(span, -9.0), Color("#f0d4a5"), 2.5)
	draw_line(center + Vector2(-span, -8.0), center + Vector2(-span, 23.0), Color("#927254"), 3.0)
	draw_line(center + Vector2(span, -8.0), center + Vector2(span, 23.0), Color("#927254"), 3.0)
	for rib in 5:
		var x := center.x - span + 10.0 + float(rib) * (span * 2.0 - 20.0) / 4.0
		draw_line(Vector2(x, center.y - 11.0), Vector2(x, center.y - 4.0), Color("#805d50", 0.42), 1.0)

func _draw_bollard(center: Vector2) -> void:
	draw_circle(center + Vector2(3.0, 4.0), 9.0, Color("#394649", _shadow_alpha + 0.1))
	draw_circle(center, 8.0, Color("#b9a37d"))
	draw_circle(center, 4.4, Color("#766957"))
	draw_circle(center - Vector2(1.0, 1.0), 2.0, Color("#e9d6b0"))

func _draw_direction_chevron(center: Vector2, direction: Vector2, color: Color) -> void:
	_draw_bold_arrow(center, direction, color)

func _draw_bold_arrow(center: Vector2, direction: Vector2, color: Color) -> void:
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	draw_line(center - forward * 12.0, center + forward * 11.0, color, 5.0, true)
	draw_line(center + forward * 3.0 + side * 9.0, center + forward * 12.0, color, 5.0, true)
	draw_line(center + forward * 3.0 - side * 9.0, center + forward * 12.0, color, 5.0, true)

func _draw_dashed_line(start: Vector2, finish: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var vector := finish - start
	var direction := vector.normalized()
	var distance := vector.length()
	var offset := 0.0
	while offset < distance:
		var end_offset := minf(offset + dash, distance)
		draw_line(start + direction * offset, start + direction * end_offset, color, width)
		offset += dash + gap
