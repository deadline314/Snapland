extends SceneTree

const RibbonModel = preload("res://game/minigames/ribbon_rhythm_model.gd")
const RibbonView = preload("res://game/minigames/ribbon_rhythm_view.gd")

var failures := 0
var checks := 0
var pressed_actions: Array[String] = []
var released_actions: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
