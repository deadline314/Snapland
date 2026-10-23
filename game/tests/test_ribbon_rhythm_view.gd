extends SceneTree

const RibbonModel = preload("res://game/minigames/ribbon_rhythm_model.gd")
const RibbonView = preload("res://game/minigames/ribbon_rhythm_view.gd")
const AnimationLibraryScript = preload("res://game/world/character_animation_library.gd")

var failures := 0
var checks := 0
var pressed_actions: Array[String] = []
var released_actions: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_beat_guides()
	var view = RibbonView.new()
	root.add_child(view)
	view.size = Vector2(1280.0, 720.0)
	view.action_pressed.connect(func(action: String) -> void: pressed_actions.append(action))
	view.action_released.connect(func(action: String) -> void: released_actions.append(action))
	var model = RibbonModel.new()
	model.reset(false, "night")
	view.update_frame(model.snapshot(), "night", false)
	view.configure_avatar(
		{"species": "human", "skin": "warm", "hair": "windswept", "hair_color": "ink", "face": "smiling"},
		{"outfit": "outfit-tide", "hat": "hat-none"}
	)
	await process_frame
	_test_design_bounds_and_letterboxing(view)
	_test_all_authored_pose_bounds(view)
	_test_keyboard_and_pointer_actions(view)
	_test_reduced_motion_keeps_static_cues(view, model)
	_test_stage_lanterns_and_imp_identity(view)
	_test_authored_imp_frames(view)
	_test_imp_dance_requires_eighth_hit_and_retry_resets(view)
	if failures > 0:
		push_error("FAIL: ribbon rhythm view (%d/%d checks failed)" % [failures, checks])
		quit(1)
		return
	print("PASS: ribbon rhythm view (%d checks)" % checks)
	quit(0)

func _test_design_bounds_and_letterboxing(view: Control) -> void:
	var stage: Rect2 = view.playfield_rect()
	var screen_bounds: Rect2 = view.bounds()
	_expect(screen_bounds == Rect2(Vector2.ZERO, Vector2(1280, 720)), "view publishes its 1280x720 design bounds")
	_expect(stage.position.y >= 130.0 and stage.end.y <= 640.0, "stage stays clear of the top 130 and bottom 80 HUD bands")
	_expect(screen_bounds.encloses(stage), "playfield fits inside the design frame")
	_expect(view.screen_to_design(Vector2(320, 180)).is_equal_approx(Vector2(320, 180)), "design coordinates are stable at native 1280x720")
	view.size = Vector2(640, 360)
	_expect(view.screen_to_design(Vector2(320, 180)).is_equal_approx(Vector2(640, 360)), "letterboxed 640x360 screen input maps to design space")
	view.size = Vector2(1280, 720)

func _test_all_authored_pose_bounds(view: Control) -> void:
	var poses: Array = view.available_pose_names()
	_expect(poses.size() >= 5, "step, jump, wave and idle pose paths are available")
	for pose in poses:
		var body: Rect2 = view.avatar_bounds_for_pose(str(pose))
		_expect(view.playfield_rect().encloses(body), "full avatar bounds for %s stay in the stage" % str(pose))
		_expect(body.position.y >= 130.0 and body.end.y <= 640.0, "head and feet for %s stay between HUD bands" % str(pose))
	_expect(view.avatar_assets_ready(), "AvatarRenderer resolves all selected authored poses")

func _test_keyboard_and_pointer_actions(view: Control) -> void:
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	view._gui_input(left)
	left.pressed = false
	view._gui_input(left)
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	view._gui_input(right)
	var jump := InputEventKey.new()
	jump.keycode = KEY_SPACE
	jump.pressed = true
	view._gui_input(jump)
	jump.pressed = false
	view._gui_input(jump)
	_expect(pressed_actions == ["left", "right", "jump"], "arrow keys and Space emit the requested press actions")
	_expect(released_actions == ["left", "jump"], "key release emits the corresponding action release")
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.position = view.design_to_screen(view.control_center("jump"))
	pointer.pressed = true
	view._gui_input(pointer)
	_expect(pressed_actions.back() == "jump", "the on-screen jump control routes through the same signal")
	pointer.pressed = false
	view._gui_input(pointer)
	_expect(released_actions.back() == "jump", "on-screen held controls emit release")

func _test_reduced_motion_keeps_static_cues(view: Control, model: RefCounted) -> void:
	var snapshot: Dictionary = model.snapshot()
	view.update_frame(snapshot, "night", true)
	var reduced: Dictionary = view.visual_cue_state()
	_expect(not bool(reduced.get("motion_enabled", true)), "reduced motion disables decorative movement")
	_expect(int(reduced.get("gesture_index", -1)) == 0, "reduced motion preserves the current required gesture")
	_expect(reduced.get("upcoming", []).size() == 2, "reduced motion preserves both upcoming gesture cues")
	_expect(view.palette_phase() == "night", "night lighting selection is retained")
	view.update_frame(snapshot, "noon", false)
	_expect(view.visual_motion_enabled(), "normal mode enables authored ribbon motion")

func _test_stage_lanterns_and_imp_identity(view: Control) -> void:
	var stage: Rect2 = view.playfield_rect()
	var companion: Rect2 = view.companion_bounds()
	_expect(view.companion_identity() == "imp" and view.companion_display_name() == "小角", "the side-stage partner is the named imp, not a recolored traveller clone")
	_expect(stage.encloses(companion) and not companion.intersects(view.avatar_bounds_for_pose("idle_front")), "the full-body side-stage companion fits beside the central player")
	var seen_centers: Array[Vector2] = []
	for index in range(8):
		var marker: Rect2 = view.beat_marker_rect(index)
		_expect(stage.encloses(marker) and marker.position.y > 128.0 and marker.end.y < 640.0, "beat %d is on the stage rail outside both HUD bands" % (index + 1))
		for prior in seen_centers:
			_expect(not marker.has_point(prior), "stage-rail beat markers have distinct positions")
		seen_centers.append(marker.get_center())
	_expect(view.beat_marker_state(0, {"gesture_index": 0, "ribbon_trail": []}) == "current", "the first footlight identifies the current beat")
	_expect(view.beat_marker_state(1, {"gesture_index": 0, "ribbon_trail": []}) == "future", "unplayed footlights remain upcoming")
	_expect(view.beat_marker_state(0, {"gesture_index": 1, "ribbon_trail": [{"index": 0}]}) == "complete", "a footlight fills only when its real beat appears in the hit trail")
	_expect(view.beat_marker_state(0, {"gesture_index": 1, "ribbon_trail": []}) == "missed", "an advanced but absent hit remains visibly distinct from completion")

func _test_authored_imp_frames(view: Control) -> void:
	var library = AnimationLibraryScript.new()
	var idle: Dictionary = library.get_sequence("imp", "idle", "front")
	var dance: Dictionary = library.get_sequence("imp", "dance", "front")
	_expect(view.companion_assets_ready(), "the accepted authored imp atlas loads a safe static identity")
	_expect(view.companion_idle_frame_count() == 7 and int(idle.get("fps", 0)) == 3 and bool(idle.get("loop", false)), "小角 uses all seven authored idle frames at their declared loop rate")
	_expect(view.companion_dance_frame_count() == 7 and int(dance.get("fps", 0)) == 6 and not bool(dance.get("loop", true)), "小角's finale uses all seven authored one-shot dance frames")
	for action in ["idle", "dance"]:
		var sequence: Dictionary = idle if action == "idle" else dance
		for index in range(7):
			var frames: Array = sequence.get("frames", [])
			var frame: Dictionary = frames[index]
			var texture := frame.get("texture") as Texture2D
			var head: Vector2i = library.normalized_anchor("imp", action, "front", index, "head")
			var feet: Vector2i = library.normalized_anchor("imp", action, "front", index, "feet")
			_expect(texture != null and texture.get_width() == 320 and texture.get_height() == 460, "%s frame %d keeps the complete normalized body canvas" % [action, index])
			_expect(head.x > 0 and head.x < 320 and head.y >= 0 and head.y < feet.y and feet.y == 448, "%s frame %d preserves head and sole anchors" % [action, index])
	var cached_count: int = view.companion_cached_texture_count()
	for repeat in range(12):
		view.update_frame({"gesture_index": 0, "elapsed": float(repeat) * 0.01, "ribbon_trail": [], "upcoming": []})
	_expect(view.companion_cached_texture_count() == cached_count, "repeated frame updates reuse the preloaded authored imp textures")

func _test_imp_dance_requires_eighth_hit_and_retry_resets(view: Control) -> void:
	var model = RibbonModel.new()
	model.reset(false, "noon")
	view.update_frame(model.snapshot(), "noon", false)
	for index in range(7):
		var state: Dictionary = model.snapshot()
		_advance_model_to(model, float(state.cue_times[index]))
		var cue: Dictionary = RibbonModel.GESTURES[index]
		model.press_action(str(cue.action))
		if float(cue.hold) > 0.0:
			_advance_model_to(model, float(model.snapshot().elapsed) + float(cue.hold))
			model.release_action(str(cue.action))
		view.update_frame(model.snapshot(), "noon", false)
		_expect(not view.companion_is_dancing(), "小角 does not dance before the real eighth hit (after beat %d)" % (index + 1))
	var before_final: Dictionary = model.snapshot()
	_expect(int(before_final.gesture_index) == 7 and not bool(before_final.ended) and view.beat_marker_state(7) == "current", "the last footlight remains current until beat eight is actually judged")
	var last_cue: Dictionary = RibbonModel.GESTURES[7]
	_advance_model_to(model, float(model.snapshot().cue_times[7]))
	model.press_action(str(last_cue.action))
	var result: Dictionary = model.snapshot()
	view.update_frame(result, "noon", false)
	_expect(bool(result.ended) and bool(result.success) and int(result.correct_count) == 8 and view.companion_is_dancing(), "a real successful eighth input alone starts 小角's dance one-shot")
	_expect(view.beat_marker_state(7) == "complete", "the final stage light fills after the real eighth hit")
	var initial_dance_frame: int = view.companion_frame_index()
	view._process(0.1)
	view._process(0.1)
	_expect(view.companion_is_dancing() and view.companion_frame_index() != initial_dance_frame, "the authored dance advances on its own view clock after model completion")
	model.retry()
	view.update_frame(model.snapshot(), "noon", false)
	_expect(not view.companion_is_dancing() and view.companion_frame_index() == 0 and view.beat_marker_state(0) == "current", "retry during the one-shot immediately clears the dance and restores the first stage light")
	for index in range(8):
		var state: Dictionary = model.snapshot()
		var cue: Dictionary = RibbonModel.GESTURES[index]
		_advance_model_to(model, float(state.cue_times[index]))
		model.press_action(str(cue.action))
		if float(cue.hold) > 0.0:
			_advance_model_to(model, float(model.snapshot().elapsed) + float(cue.hold))
			model.release_action(str(cue.action))
		view.update_frame(model.snapshot(), "noon", false)
	var second_result: Dictionary = model.snapshot()
	_expect(bool(second_result.success) and int(second_result.correct_count) == 8 and view.companion_is_dancing(), "the retried real eight-hit phrase can start a fresh one-shot finale")
	for ignored in 12:
		view._process(0.1)
	_expect(not view.companion_is_dancing(), "the non-looping finale returns to the companion idle identity after all authored frames")
	model.retry()
	view.update_frame(model.snapshot(), "noon", false)
	_advance_model_to(model, float(model.snapshot().cue_times[0]))
	model.press_action(str(RibbonModel.GESTURES[0].action))
	var held_snapshot: Dictionary = model.snapshot()
	view.update_frame(held_snapshot, "noon", true)
	_expect(not view.companion_is_dancing() and view.companion_frame_index() == 0 and view.visual_cue_state().gesture_index == 1, "reduced motion keeps the distinct idle companion and current player cue without starting a finale")
func _advance_model_to(model: RefCounted, target: float) -> void:
	var remaining := target - float(model.snapshot().elapsed)
	var guard := 0
	while remaining > 0.000001 and guard < 100:
		var step := minf(remaining, 0.25)
		model.step(step)
		remaining = target - float(model.snapshot().elapsed)
		guard += 1
	_expect(guard < 100, "bounded model steps reach the requested authored beat")

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _test_beat_guides() -> void:
	var guide = RibbonView.new()
	var current := {"time": 1.02, "strong": true, "action": "left"}
	_expect(guide.approach_radius(RibbonView.APPROACH_SECONDS) == 40.0 and guide.approach_radius(0.0) == 14.0 and guide.approach_radius(RibbonView.APPROACH_SECONDS + 0.1) == -1.0, "the approach ring closes from 40 px to the glyph exactly on the beat")
	_expect(is_equal_approx(guide.time_to_current_beat({"current_gesture": current, "elapsed": 0.0, "count_in_left": 2.82}), 3.84), "time to the first beat includes the music count-in")
	_expect(guide.count_in_number({"count_in_left": 2.82}) == 3 and guide.count_in_number({"count_in_left": 0.5}) == 1 and guide.count_in_number({"count_in_left": 0.0}) == 0, "the count-in shows 3, 2, 1 and disappears when the round runs")
	_expect(guide.judgement_text({"last_grade": "精準", "last_offset": 0.06, "last_judged_at": 1.0, "elapsed": 1.2}) == "精準　晚 60 毫秒", "a judged press shows its grade with a late offset")
	_expect(guide.judgement_text({"last_grade": "合拍", "last_offset": -0.15, "last_judged_at": 1.0, "elapsed": 1.1}) == "合拍　早 150 毫秒", "an early press is labelled early")
	_expect(guide.judgement_text({"last_grade": "精準", "last_offset": 0.06, "last_judged_at": 1.0, "elapsed": 2.0}).is_empty(), "the stamp disappears after its short display time")
	_expect(not RibbonView.JUDGEMENT_RECT.intersects(RibbonView.MAIN_AVATAR_RECT) and not RibbonView.JUDGEMENT_RECT.intersects(RibbonView.PARTNER_AVATAR_RECT) and not RibbonView.JUDGEMENT_RECT.intersects(RibbonView.JUMP_AVATAR_RECT), "the judgement stamp never covers either dancer")
	var medallion := Rect2(RibbonView.COUNT_IN_CENTER - Vector2(46, 46), Vector2(92, 92))
	_expect(not medallion.intersects(RibbonView.MAIN_AVATAR_RECT) and not medallion.intersects(RibbonView.JUMP_AVATAR_RECT), "the count-in medallion stays beside the dancer")
	guide.free()
