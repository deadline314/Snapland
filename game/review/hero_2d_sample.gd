extends Control
class_name Hero2DSample

signal tour_completed(receipt: Dictionary)

const LibraryScript := preload("res://game/world/hero_2d_library.gd")
const PoseScript := preload("res://game/world/hero_2d_pose.gd")
const DIRECTIONS: Array[String] = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const DIRECTION_KEYS := {
	"front": [KEY_DOWN], "front_right": [KEY_DOWN, KEY_RIGHT], "right": [KEY_RIGHT], "back_right": [KEY_UP, KEY_RIGHT],
	"back": [KEY_UP], "back_left": [KEY_UP, KEY_LEFT], "left": [KEY_LEFT], "front_left": [KEY_DOWN, KEY_LEFT],
}
const HAIR_STYLES: Array[String] = ["windswept", "bob"]
const OUTFITS: Array[String] = ["tide_jacket", "long_coat"]
const MOVE_SPEED := 90.0
const ACCELERATION := 560.0
const COLLISION_MARGIN := 148.0
const MANIFEST_PATH := "res://assets/characters/hero-2d-v1/manifest.json"

var _pose = PoseScript.new()
var _library: Variant
var _actor_root := Vector2(420.0, 620.0)
var _velocity := Vector2.ZERO
var _state: Dictionary = {"action": "idle", "direction": "front", "visual_direction": "front", "frame": 0, "phase": 0.0, "gait_phase": 0.0, "root_locked": false, "events": []}
var _last_actual_displacement: Vector2 = Vector2.ZERO
var _keys_down: Dictionary = {}
var _hair := "windswept"
var _hat := false
var _outfit := "tide_jacket"
var _speed_scale := 1.0
var _photo_queued := false
var _paused := false
var _stage_rect := Rect2(0.0, 0.0, 824.0, 696.0)
var _floor_y := 620.0
var _time_simulated := 0.0
var _last_render_key := ""
var _tour_running := false
var _tour_output_dir := ""
var _tour_receipt: Dictionary = {}
var _tour_failures: Array[String] = []
var _observed_actions: Dictionary = {}
var _shutter_count := 0
var _key_events_sent := 0
var _mouse_events_sent := 0
var _manifest_frame_counts: Dictionary = {}

var hair_button: Button
var hat_button: Button
var outfit_button: Button
var photo_button: Button
var speed_button: Button
var pause_button: Button
var status_label: Label
var clock_label: Label
var appearance_label: Label
var stage: Control
var _library_ok := false


func _ready() -> void:
	_build_interface()
	for direction in DIRECTIONS:
		_pose.set_stride_distance(direction, 100.0)
	_library = LibraryScript.new()
	_library.name = "Hero2DLibrary"
	_library.position = _actor_root
	stage.add_child(_library)
	_library_ok = _library.initialize(MANIFEST_PATH)
	if _library_ok:
		_configure_pose_frame_counts()
	_apply_appearance()
	_render_current(true)
	_set_status("方向鍵／WASD 移動 · 空白鍵拍照" if _library_ok else "素材尚未就緒：\n" + "\n".join(_library.get_diagnostics()))
	_update_clock()


func _process(delta: float) -> void:
	if _paused or not _library_ok:
		return
	var real_delta := maxf(delta, 0.0)
	var simulation_delta := real_delta * _speed_scale
	_time_simulated += simulation_delta
	var intent := _read_intent()
	var moving_backwards: bool = _state.get("action", "") == "walk" and not intent.is_zero_approx() and _heading_vector(String(_state.get("direction", "front"))).dot(intent.normalized()) < -0.5
	if moving_backwards or bool(_state.get("root_locked", false)):
		_velocity = Vector2.ZERO
	else:
		_velocity = _velocity.move_toward(intent * MOVE_SPEED, ACCELERATION * simulation_delta)
	var proposed_delta := _velocity * simulation_delta
	var previous_root := _actor_root
	var proposed_root := _actor_root + proposed_delta
	proposed_root.x = clampf(proposed_root.x, _stage_rect.position.x + COLLISION_MARGIN, _stage_rect.end.x - COLLISION_MARGIN)
	proposed_root.y = clampf(proposed_root.y, _stage_rect.position.y + 390.0, _floor_y)
	_actor_root = proposed_root
	var actual_displacement := _actor_root - previous_root
	_last_actual_displacement = actual_displacement
	if not proposed_delta.is_zero_approx() and actual_displacement.distance_squared_to(proposed_delta) > 0.0001:
		_velocity = Vector2.ZERO
	_library.position = _actor_root
	_state = _pose.advance(simulation_delta, actual_displacement, intent, _photo_queued)
	_photo_queued = false
	_observe_state()
	_render_current()
	_update_clock()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var key := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		if key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
			_keys_down[key] = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and key == KEY_SPACE:
			_photo_queued = true
			get_viewport().set_input_as_handled()
		elif event.pressed and key == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func start_tour(output_dir: String, quarter_speed: bool) -> void:
	if _tour_running:
		return
	_tour_running = true
	_tour_output_dir = output_dir
	_speed_scale = 0.25 if quarter_speed else 1.0
	if is_instance_valid(speed_button):
		speed_button.text = "速度：四分之一 ¼×" if quarter_speed else "速度：正常 1×"
	_tour_receipt = {
		"review": "ART-29 independent 2D hero sample native-control tour",
		"time_scale": _speed_scale,
		"method": "Main sample scene driven by Input.parse_input_event keyboard and mouse events; state receipts and captures are not visual approval",
		"checks": {},
		"captures": [],
		"observations": {"directions": [], "appearances": [], "actions": [], "special_pose_captures": [], "shutter_events": 0},
		"native_input_events": {"keys": 0, "mouse_buttons": 0},
		"manifest_frame_counts": _manifest_frame_counts.duplicate(true),
		"diagnostics": [],
	}
	DirAccess.make_dir_recursive_absolute(output_dir)
	if not _library_ok:
		_tour_failures.append("hero 2D manifest could not initialize")
		_tour_receipt["diagnostics"] = _library.get_diagnostics()
		_finish_tour.call_deferred()
		return
	_run_tour.call_deferred()


func _run_tour() -> void:
	await _wait_frames(2)
	_check(_state.action == "idle" and _state.direction == "front", "canonical idle pose is active")
	await _capture_fullbody("00-idle-front.png")
	await _exercise_appearances()
	await _exercise_all_directions()
	await _exercise_halfstep_and_reverse()
	await _exercise_wall()
	await _exercise_photo_and_appearance()
	await _exercise_pause_resume()
	await _capture_fullbody("99-final-fullbody.png")
	var all_actions_seen := true
	for action in ["idle", "start", "walk", "stop", "turn", "photo"]:
		var observed := _observed_actions.has(action)
		all_actions_seen = all_actions_seen and observed
		_check(observed, "native tour observes %s action" % action)
	_tour_receipt["checks"]["all_required_actions"] = all_actions_seen
	_tour_receipt["observations"]["shutter_events"] = _shutter_count
	_tour_receipt["native_input_events"] = {"keys": _key_events_sent, "mouse_buttons": _mouse_events_sent}
	_tour_receipt["diagnostics"] = _library.get_diagnostics()
	_tour_receipt["checks"]["renderer_initialized"] = _library_ok
	_tour_receipt["checks"]["no_composition_diagnostics"] = _library.get_diagnostics().is_empty()
	_finish_tour()


func _exercise_appearances() -> void:
	var seen: Dictionary = {}
	for hair_index in range(2):
		for hat_index in range(2):
			for outfit_index in range(2):
				if _hair != HAIR_STYLES[hair_index]: await _click_button(hair_button)
				if _hat != bool(hat_index): await _click_button(hat_button)
				if _outfit != OUTFITS[outfit_index]: await _click_button(outfit_button)
				await _wait_frames(3)
				var key := "%s|%s|%s" % [_hair, str(_hat), _outfit]
				seen[key] = true
				_tour_receipt["observations"]["appearances"].append({"hair": _hair, "hat": _hat, "outfit": _outfit, "pose_kept": _state.duplicate(true)})
				_check(_library.current_appearance == {"hair_style": _hair, "hat_on": _hat, "outfit": _outfit}, "appearance updates through native controls")
				if hair_index == 1 and hat_index == 1:
					await _capture_fullbody("look-%s-%s-%s.png" % [hair_index, hat_index, outfit_index])
	_check(seen.size() == 8, "all eight hair/hat/outfit combinations were selected")
	_tour_receipt["checks"]["all_eight_appearances"] = seen.size() == 8


func _exercise_all_directions() -> void:
	var seen: Dictionary = {}
	var all_directions_moved := true
	for direction in DIRECTIONS:
		var start_y: float = 390.0 if direction == "front" else (420.0 if direction in ["front_right", "front_left"] else (620.0 if direction == "back" else (600.0 if direction in ["back_right", "back_left"] else 500.0)))
		_place_actor_for_test(Vector2(420.0, start_y))
		var walk_origin := _actor_root
		await _press_keys(DIRECTION_KEYS[direction])
		await _wait_simulated(2.35)
		var actual := String(_state.get("direction", ""))
		var moved_distance := _actor_root.distance_to(walk_origin)
		var walking := String(_state.get("action", "")) == "walk"
		seen[actual] = true
		all_directions_moved = all_directions_moved and actual == direction and moved_distance > 200.0 and walking
		_tour_receipt["observations"]["directions"].append({"requested": direction, "actual": actual, "action": _state.get("action", ""), "position": [_actor_root.x, _actor_root.y], "walk_displacement": moved_distance})
		_check(actual == direction, "native movement reaches %s" % direction)
		_check(moved_distance > 200.0, "native movement advances in %s" % direction)
		_check(walking, "native movement is in the authored walk action for %s" % direction)
		await _capture_fullbody("direction-%s-walk.png" % direction)
		await _release_keys(DIRECTION_KEYS[direction])
		await _wait_simulated(0.48)
		await _capture_fullbody("direction-%s-settled.png" % direction)
	_check(seen.size() == 8 and all_directions_moved, "all eight directions reached through moving keyboard input")
	_tour_receipt["checks"]["all_eight_directions"] = seen.size() == 8 and all_directions_moved


func _exercise_halfstep_and_reverse() -> void:
	var half_start := _actor_root
	await _press_keys([KEY_D])
	await _wait_simulated(0.10)
	await _release_keys([KEY_D])
	await _wait_simulated(0.70)
	var half_distance := _actor_root.distance_to(half_start)
	_check(half_distance > 0.5 and _state.action == "idle", "short key tap moves then settles to idle")
	_tour_receipt["checks"]["halfstep_settles"] = half_distance > 0.5 and _state.action == "idle"
	_place_actor_for_test(Vector2(420.0, 500.0))
	await _press_keys([KEY_D])
	await _wait_simulated(0.48)
	# Release and reverse in the same event batch so no idle process frame erases intent.
	_send_key(KEY_D, false)
	_send_key(KEY_A, true)
	await _wait_frames(1)
	var reversal_observation: Dictionary = await _wait_simulated(0.75, true)
	await _release_keys([KEY_A])
	await _wait_simulated(0.55)
	var saw_turn := bool(reversal_observation.get("saw_turn", false))
	var locked_displacement := float(reversal_observation.get("locked_displacement", 0.0))
	var turn_capture_valid := str(reversal_observation.get("turn_action", "")) == "turn" and int(reversal_observation.get("turn_frame", -1)) >= 0
	_check(saw_turn, "reverse input passes through an authored turn pose")
	_check(locked_displacement < 1.0, "root remains locked while the turn pose is active")
	_check(turn_capture_valid, "reverse turn capture records an active authored turn frame")
	_tour_receipt["checks"]["reverse_turn"] = saw_turn
	_tour_receipt["checks"]["reverse_root_locked"] = locked_displacement < 1.0
	_tour_receipt["checks"]["reverse_turn_capture"] = turn_capture_valid
	if turn_capture_valid:
		_tour_receipt["observations"]["special_pose_captures"].append({"capture": "reverse-turn.png", "action": reversal_observation.get("turn_action", ""), "frame": reversal_observation.get("turn_frame", -1), "visual_direction": reversal_observation.get("turn_visual_direction", ""), "locked_displacement": locked_displacement})


func _exercise_wall() -> void:
	var wall_start := _actor_root
	await _press_keys([KEY_D])
	await _wait_simulated(4.0)
	var at_wall := _actor_root.x >= _stage_rect.end.x - COLLISION_MARGIN - 0.01
	var before := _actor_root
	await _wait_simulated(0.25)
	await _release_keys([KEY_D])
	var reached_from_inside := wall_start.distance_to(before) > 100.0
	var clamped := reached_from_inside and at_wall and is_equal_approx(before.x, _actor_root.x)
	_check(reached_from_inside, "wall test approaches the boundary through live movement")
	_check(clamped, "wall clamp prevents root motion beyond stage boundary")
	_tour_receipt["checks"]["wall_approach"] = reached_from_inside
	_tour_receipt["checks"]["wall_clamp"] = clamped
	await _capture_fullbody("wall-stop.png")
	_place_actor_for_test(Vector2(420.0, 500.0))


func _exercise_photo_and_appearance() -> void:
	_send_key(KEY_SPACE, true)
	_send_key(KEY_SPACE, false)
	await _wait_frames(2)
	var keyboard_photo_started: bool = _state.get("action", "") == "photo"
	var phase_before := float(_state.get("phase", 0.0))
	await _click_button(hair_button)
	await _click_button(outfit_button)
	var photo_kept: bool = _state.get("action", "") == "photo" and float(_state.get("phase", 0.0)) >= phase_before and String(_library.current_pose.get("action", "")) == "photo"
	_check(keyboard_photo_started, "Space triggers the authored photo pose")
	_check(photo_kept, "hair and outfit can change without resetting the held photo pose")
	await _wait_photo_midpoint("photo-mid-appearance.png", "keyboard")
	await _wait_simulated(1.35)
	_check(_shutter_count == 1, "photo pose emits one shutter event")
	var keyboard_shutter_once := _shutter_count == 1
	await _click_button(photo_button)
	await _wait_frames(2)
	var button_photo_started: bool = _state.get("action", "") == "photo"
	await _wait_photo_midpoint("photo-button-mid.png", "button")
	await _wait_simulated(1.35)
	var button_shutter_once := _shutter_count == 2
	_check(button_photo_started, "camera button triggers authored photo pose")
	_check(button_shutter_once, "camera button fires exactly one additional shutter event")
	_tour_receipt["checks"]["photo_action"] = keyboard_photo_started and button_photo_started
	_tour_receipt["checks"]["photo_appearance_sync"] = photo_kept
	_tour_receipt["checks"]["one_shutter_per_trigger"] = keyboard_shutter_once and button_shutter_once


func _exercise_pause_resume() -> void:
	await _press_keys([KEY_S])
	await _wait_simulated(0.35)
	await _click_button(pause_button)
	var paused_state := _state.duplicate(true)
	var paused_position := _actor_root
	await _wait_real(0.35)
	var stable := _state == paused_state and _actor_root.is_equal_approx(paused_position)
	_check(_paused and stable, "pause button freezes pose and root")
	await _click_button(pause_button)
	await _release_keys([KEY_S])
	await _wait_simulated(0.45)
	_check(not _paused and _state.action in ["stop", "idle"], "resume returns to a resting action")
	_tour_receipt["checks"]["pause_freezes"] = stable
	_tour_receipt["checks"]["resume"] = not _paused
	await _capture_fullbody("pause-resume.png")


func _read_intent() -> Vector2:
	var x := float(_is_key_down(KEY_D) or _is_key_down(KEY_RIGHT)) - float(_is_key_down(KEY_A) or _is_key_down(KEY_LEFT))
	var y := float(_is_key_down(KEY_S) or _is_key_down(KEY_DOWN)) - float(_is_key_down(KEY_W) or _is_key_down(KEY_UP))
	var value := Vector2(x, y)
	return value.normalized() if not value.is_zero_approx() else Vector2.ZERO


func _configure_pose_frame_counts() -> void:
	_manifest_frame_counts.clear()
	var poses: Variant = _library.manifest.get("poses", {})
	if not poses is Dictionary:
		_tour_failures.append("validated library has no pose direction map")
		return
	for direction in DIRECTIONS:
		var direction_poses: Variant = poses.get(direction, {})
		if not direction_poses is Dictionary:
			_tour_failures.append("validated manifest has no poses for %s" % direction)
			continue
		var direction_counts: Dictionary = {}
		for action in ["idle", "start", "walk", "stop", "turn", "photo"]:
			var frames: Variant = direction_poses.get(action, [])
			if not frames is Array or frames.is_empty():
				_tour_failures.append("validated manifest has no %s frames for %s" % [action, direction])
				continue
			var count: int = int(frames.size())
			if not _pose.set_frame_count(action, direction, count):
				_tour_failures.append("pose player rejected %s/%s frame count %d" % [direction, action, count])
			direction_counts[action] = count
		_manifest_frame_counts[direction] = direction_counts


func _is_key_down(key: int) -> bool:
	return bool(_keys_down.get(key, false))


func _heading_vector(direction: String) -> Vector2:
	var index := DIRECTIONS.find(direction)
	if index < 0: return Vector2.DOWN
	var angle := float(index) * PI / 4.0
	return Vector2(sin(angle), cos(angle))


func _apply_appearance() -> void:
	if _library == null: return
	var ok: bool = bool(_library.set_appearance(_hair, _hat, _outfit))
	if not ok:
		_set_status("外觀無法載入：素材或八方向覆蓋不完整")
	_update_appearance_labels()
	_last_render_key = ""


func _render_current(force := false) -> void:
	if not _library_ok or _library == null: return
	var key := "%s|%s|%s|%s|%s|%s" % [_state.get("action", ""), _state.get("visual_direction", _state.get("direction", "front")), _state.get("frame", 0), _hair, str(_hat), _outfit]
	if not force and key == _last_render_key: return
	_library.render_pose(_state)
	_last_render_key = key
	_update_status_state()


func _observe_state() -> void:
	var action := String(_state.get("action", ""))
	_observed_actions[action] = true
	if _tour_running:
		_tour_receipt["observations"]["actions"].append(action)
	for event in _state.get("events", []):
		if String(event) == "shutter":
			_shutter_count += 1


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#dceeea")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	stage = Control.new()
	stage.name = "Stage"
	stage.position = Vector2(24.0, 48.0)
	stage.size = Vector2(824.0, 696.0)
	add_child(stage)
	var stage_bg := ColorRect.new()
	stage_bg.color = Color("#f5f1df")
	stage_bg.size = stage.size
	stage.add_child(stage_bg)
	var sky := ColorRect.new()
	sky.color = Color("#c8e7e3")
	sky.position = Vector2(12.0, 12.0)
	sky.size = Vector2(800.0, 530.0)
	stage.add_child(sky)
	var horizon := ColorRect.new()
	horizon.color = Color("#a9d4c9")
	horizon.position = Vector2(12.0, 500.0)
	horizon.size = Vector2(800.0, 42.0)
	stage.add_child(horizon)
	var floor := ColorRect.new()
	floor.color = Color("#dfd4b9")
	floor.position = Vector2(12.0, 542.0)
	floor.size = Vector2(800.0, 142.0)
	stage.add_child(floor)
	var title := _label("主角 2D 動作樣本", 28, Color("#224f55"))
	title.position = Vector2(30.0, 22.0)
	stage.add_child(title)
	var hint := _label("八方向 · 換髮戴帽 · 換裝與拍照", 16, Color("#426a6a"))
	hint.position = Vector2(32.0, 57.0)
	stage.add_child(hint)
	var home := ColorRect.new()
	home.color = Color("#9bbab0")
	home.position = Vector2(130.0, 620.0)
	home.size = Vector2(585.0, 4.0)
	stage.add_child(home)
	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.position = Vector2(874.0, 48.0)
	panel.size = Vector2(372.0, 696.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#f5f1df")
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 16.0
	panel_style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := _label("造型與操作", 24, Color("#224f55"))
	column.add_child(heading)
	appearance_label = _label("", 16, Color("#36585a"))
	appearance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(appearance_label)
	hair_button = _button("髮型：微風短髮", _cycle_hair)
	column.add_child(hair_button)
	hat_button = _button("帽子：未戴", _toggle_hat)
	column.add_child(hat_button)
	outfit_button = _button("外套：潮汐夾克", _cycle_outfit)
	column.add_child(outfit_button)
	photo_button = _button("拍照　Space", func(): _photo_queued = true)
	column.add_child(photo_button)
	speed_button = _button("速度：正常 1×", _toggle_speed)
	column.add_child(speed_button)
	pause_button = _button("暫停", _toggle_pause)
	column.add_child(pause_button)
	clock_label = _label("", 16, Color("#426a6a"))
	column.add_child(clock_label)
	status_label = _label("", 16, Color("#224f55"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 65.0
	column.add_child(status_label)
	var help := _label("移動：W A S D／方向鍵\n髮型／帽子／外套可在動作中切換", 16, Color("#536d6a"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)


func _label(text: String, size: int, color: Color) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	return value


func _button(text: String, callback: Callable) -> Button:
	var value := Button.new()
	value.text = text
	value.custom_minimum_size = Vector2(328.0, 44.0)
	value.focus_mode = Control.FOCUS_NONE
	value.pressed.connect(callback)
	return value


func _cycle_hair() -> void:
	_hair = "bob" if _hair == "windswept" else "windswept"
	_apply_appearance()


func _toggle_hat() -> void:
	_hat = not _hat
	_apply_appearance()


func _cycle_outfit() -> void:
	_outfit = "long_coat" if _outfit == "tide_jacket" else "tide_jacket"
	_apply_appearance()


func _toggle_speed() -> void:
	_speed_scale = 0.25 if _speed_scale == 1.0 else 1.0
	speed_button.text = "速度：四分之一 ¼×" if _speed_scale == 0.25 else "速度：正常 1×"


func _toggle_pause() -> void:
	_paused = not _paused
	_pose.set_paused(_paused)
	pause_button.text = "繼續" if _paused else "暫停"
	_set_status("已暫停" if _paused else "已恢復")


func _update_appearance_labels() -> void:
	if not is_instance_valid(appearance_label): return
	hair_button.text = "髮型：" + ("微風短髮" if _hair == "windswept" else "波波短髮")
	hat_button.text = "帽子：" + ("已戴" if _hat else "未戴")
	outfit_button.text = "外套：" + ("潮汐夾克" if _outfit == "tide_jacket" else "長版外套")
	appearance_label.text = "目前外觀：%s · %s · %s" % ["微風短髮" if _hair == "windswept" else "波波短髮", "戴帽" if _hat else "無帽", "潮汐夾克" if _outfit == "tide_jacket" else "長版外套"]


func _update_status_state() -> void:
	if not is_instance_valid(status_label): return
	var action_names := {"idle":"休息", "start":"起步", "walk":"走路", "stop":"停步", "turn":"轉身", "photo":"拍照"}
	var direction_names := {"front":"前", "front_right":"右前", "right":"右", "back_right":"右後", "back":"後", "back_left":"左後", "left":"左", "front_left":"左前"}
	status_label.text = "%s · 朝向%s" % [action_names.get(_state.get("action", "idle"), "休息"), direction_names.get(_state.get("visual_direction", "front"), "前")]


func _update_clock() -> void:
	if is_instance_valid(clock_label):
		clock_label.text = "模擬時間 %.1f 秒　·　%s" % [_time_simulated, "¼×" if _speed_scale == 0.25 else "1×"]


func _set_status(value: String) -> void:
	if is_instance_valid(status_label): status_label.text = value


func _press_keys(keys: Array) -> void:
	for key in keys:
		_send_key(int(key), true)
	await _wait_frames(1)


func _release_keys(keys: Array) -> void:
	for key in keys:
		_send_key(int(key), false)
	await _wait_frames(1)


func _send_key(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	_key_events_sent += 1


func _click_button(button: BaseButton) -> void:
	if not is_instance_valid(button): return
	await _wait_frames(2)
	var position := get_viewport().get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion)
	await _wait_frames(1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.window_id = get_window().get_window_id()
		Input.parse_input_event(event)
		_mouse_events_sent += 1
		await _wait_frames(1)


func _wait_frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame


func _wait_real(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var delta := maxf(get_process_delta_time(), 0.001)
		await get_tree().process_frame
		elapsed += delta


func _wait_simulated(seconds: float, track_root_lock: bool = false) -> Dictionary:
	var elapsed := 0.0
	var observation := {"saw_turn": false, "locked_displacement": 0.0}
	while elapsed < seconds:
		await get_tree().process_frame
		var delta := maxf(get_process_delta_time(), 0.001) * _speed_scale
		elapsed += delta
		if track_root_lock and String(_state.get("action", "")) == "turn":
			if not bool(observation["saw_turn"]):
				observation["turn_action"] = String(_state.get("action", ""))
				observation["turn_frame"] = int(_state.get("frame", -1))
				observation["turn_visual_direction"] = String(_state.get("visual_direction", ""))
				await _capture_fullbody("reverse-turn.png")
			observation["saw_turn"] = true
		if track_root_lock and bool(_state.get("root_locked", false)):
			observation["locked_displacement"] = float(observation["locked_displacement"]) + _last_actual_displacement.length()
	return observation


func _place_actor_for_test(position: Vector2) -> void:
	_actor_root = position
	_velocity = Vector2.ZERO
	_library.position = _actor_root
	_state = _pose.advance(0.0, Vector2.ZERO, Vector2.ZERO)
	_render_current(true)


func _wait_photo_midpoint(filename: String, trigger: String) -> void:
	if String(_state.get("action", "")) != "photo":
		_check(false, "%s photo remains active before mid-pose capture" % trigger)
		return
	var current_phase := float(_state.get("phase", 0.0))
	var wait_seconds := maxf(0.60 - current_phase * 1.20, 0.0)
	if wait_seconds > 0.0:
		await _wait_simulated(wait_seconds)
	var action := String(_state.get("action", ""))
	var phase := float(_state.get("phase", 0.0))
	var frame := int(_state.get("frame", -1))
	var is_mid_photo := action == "photo" and phase >= 0.45 and phase <= 0.80 and frame >= 0
	_check(is_mid_photo, "%s photo is captured during the raised-camera pose" % trigger)
	if is_mid_photo:
		await _capture_fullbody(filename)
		_tour_receipt["observations"]["special_pose_captures"].append({"capture": filename, "trigger": trigger, "action": action, "frame": frame, "phase": phase})


func _capture_fullbody(filename: String) -> void:
	if not _library_ok: return
	var image: Image = _library.compose_frame(_state)
	if image == null:
		_tour_failures.append("compose_frame returned null for %s" % filename)
		return
	var path := _tour_output_dir.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		_tour_failures.append("could not save full-body capture %s (%s)" % [path, error_string(error)])
	else:
		_tour_receipt["captures"].append(path)


func _check(condition: bool, description: String) -> void:
	if condition: return
	_tour_failures.append(description)
	push_error("FAIL hero 2D native sample: " + description)


func _finish_tour() -> void:
	_tour_receipt["failures"] = _tour_failures.duplicate()
	_tour_receipt["result"] = "PASS_STATE_CHECKS" if _tour_failures.is_empty() else "FAIL"
	_tour_receipt["visual_review"] = "not performed by this script; inspect PNG and MP4 captures manually"
	if not _tour_output_dir.is_empty():
		var audit := FileAccess.open(_tour_output_dir.path_join("audit.json"), FileAccess.WRITE)
		if audit != null:
			audit.store_string(JSON.stringify(_tour_receipt, "  "))
			audit.close()
	tour_completed.emit(_tour_receipt.duplicate(true))
