extends SceneTree

const View := preload("res://game/minigames/bench_swap_view.gd")
const Model := preload("res://game/minigames/bench_swap_model.gd")
const AvatarRendererScript := preload("res://game/world/avatar_renderer.gd")
var checks := 0
var failures := 0
var view: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = View.new()
	root.add_child(view)
	view.size = Vector2(1280, 720)
	await process_frame
	view.configure_avatar(AvatarRendererScript.DEFAULT_APPEARANCE, {"outfit":"outfit-tide","hat":"hat-none"})
	_test_safe_geometry_and_full_avatars()
	_test_live_swap_avatar_geometry()
	_test_text_and_tabletop_layout()
	_test_mouse_keyboard_and_reduced_motion()
	if failures == 0:
		print("Bench swap view: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Bench swap view: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_safe_geometry_and_full_avatars() -> void:
	var playfield: Rect2 = view.playfield_rect()
	var safe := Rect2(Vector2(0, 130), Vector2(1280, 510))
	_expect(safe.encloses(playfield) and playfield.size.y > 450, "diorama occupies a stable 1280×720 safe playfield between reserved HUD bands")
	_expect(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(view.geometry_bounds()), "table silhouette stays within design frame")
	_expect(view.uses_authored_avatar(), "all six seated guests use cached existing AvatarRenderer textures")
	var sizes: Array[Vector2i] = []
	for guest in 6:
		var texture: Texture2D = view.avatar_texture_for_guest(guest)
		_expect(texture != null and texture.get_size() == Vector2(AvatarRendererScript.CANVAS_SIZE), "guest %d draws the complete uncropped authored body canvas" % guest)
		sizes.append(Vector2i(texture.get_size()) if texture != null else Vector2i.ZERO)
		_expect(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(view.seat_geometry_bounds(guest)), "seat %d marker fits the canvas" % guest)
	_expect(View.AVATAR_RENDER_BOUNDS.size == View.AVATAR_SIZE and sizes.all(func(size: Vector2i) -> bool: return size == AvatarRendererScript.CANVAS_SIZE), "rendered character bounds preserve the source whole-body proportions")
	for guest in View.GUEST_NAMES.size():
		var label := "%s %s" % [View.GUEST_MARKS[guest], View.GUEST_NAMES[guest]]
		var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_expect(label_width <= 92.0, "guest label %s fits its measured seat-name box" % label)
	_expect(view.screen_to_design(Vector2(640, 360)).is_equal_approx(Vector2(640, 360)), "center point maps to stable design coordinates")
	var viewport_center := view.size * 0.5
	_expect(view.screen_to_design(viewport_center).is_equal_approx(Vector2(640, 360)), "viewport center maps to the tabletop design center")

func _test_live_swap_avatar_geometry() -> void:
	var model = Model.new()
	model.select_seat(0)
	model.select_seat(4)
	view.update_frame(model.snapshot())
	_assert_six_avatar_layouts("swap frame 0", 0, 4)
	var start_layout: Array[Dictionary] = view.guest_visual_layout()
	var start_from: Dictionary = _layout_for_guest(start_layout, 0)
	var start_to: Dictionary = _layout_for_guest(start_layout, 4)
	_expect(_feet_position(start_from).is_equal_approx(view.seat_avatar_baseline_design(0)), "from guest feet begin on the original idle seat baseline")
	_expect(_feet_position(start_to).is_equal_approx(view.seat_avatar_baseline_design(4)), "to guest feet begin on the original idle seat baseline")
	model.step(0.14)
	view.update_frame(model.snapshot())
	_assert_six_avatar_layouts("swap midpoint", 0, 4)
	var middle_layout: Array[Dictionary] = view.guest_visual_layout()
	var middle_from: Dictionary = _layout_for_guest(middle_layout, 0)
	var middle_to: Dictionary = _layout_for_guest(middle_layout, 4)
	_expect(not _feet_position(middle_from).is_equal_approx(_feet_position(start_from)) and not _feet_position(middle_to).is_equal_approx(_feet_position(start_to)), "both real moving guests advance along the model's midpoint")
	_expect(absf(middle_from.baseline.y - (start_from.baseline.y + view.seat_avatar_baseline_local(4).y) * 0.5 + 66.0) < 0.01, "moving trajectory uses the expected local parabolic arc at frame 0.5")
	model.step(0.1372)
	view.update_frame(model.snapshot())
	_assert_six_avatar_layouts("swap frame 0.99", 0, 4)
	var near_end_layout: Array[Dictionary] = view.guest_visual_layout()
	var near_end_from: Dictionary = _layout_for_guest(near_end_layout, 0)
	var near_end_to: Dictionary = _layout_for_guest(near_end_layout, 4)
	_expect(_feet_position(near_end_from).distance_to(view.seat_avatar_baseline_design(4)) < 9.0 and _feet_position(near_end_to).distance_to(view.seat_avatar_baseline_design(0)) < 9.0, "both visible movers approach their destination feet continuously")
	model.step(0.004)
	view.update_frame(model.snapshot())
	var settled_layout: Array[Dictionary] = view.guest_visual_layout()
	var settled_from: Dictionary = _layout_for_guest(settled_layout, 0)
	var settled_to: Dictionary = _layout_for_guest(settled_layout, 4)
	_expect(_feet_position(settled_from).is_equal_approx(view.seat_avatar_baseline_design(4)) and _feet_position(settled_to).is_equal_approx(view.seat_avatar_baseline_design(0)), "frame 1 settles the same two figures exactly on their swapped idle baselines")

func _assert_six_avatar_layouts(label: String, from_seat: int, to_seat: int) -> void:
	var layout: Array[Dictionary] = view.guest_visual_layout()
	_expect(layout.size() == 6, "%s keeps exactly six visible guest figures" % label)
	var guests: Array[int] = []
	var moving_count := 0
	for entry in layout:
		var guest := int(entry.guest)
		guests.append(guest)
		if bool(entry.moving): moving_count += 1
		_expect(View.SAFE_PLAYFIELD.encloses(entry.bounds), "%s guest %d full-body avatar stays inside the safe playfield" % [label, guest])
	guests.sort()
	_expect(guests == [0, 1, 2, 3, 4, 5], "%s shows every distinct guest exactly once" % label)
	_expect(moving_count == 2, "%s marks only the two swapped guests as moving" % label)
	_expect(int(_layout_for_guest(layout, int(view._snapshot.moving_guest_from)).seat) == to_seat and int(_layout_for_guest(layout, int(view._snapshot.moving_guest_to)).seat) == from_seat, "%s associates each moving figure with its authored destination seat" % label)

func _feet_position(entry: Dictionary) -> Vector2:
	var bounds: Rect2 = entry.bounds
	return Vector2(bounds.get_center().x, bounds.end.y)

func _layout_for_guest(layout: Array[Dictionary], guest: int) -> Dictionary:
	for entry in layout:
		if int(entry.guest) == guest: return entry
	return {}

func _test_text_and_tabletop_layout() -> void:
	var safe := Rect2(70, 130, 1140, 510)
	for bounds in view.text_layout_bounds():
		_expect(safe.encloses(bounds), "every text region remains below shared HUD and above bottom HUD")
	for width in view.rule_text_widths():
		_expect(width <= 444.0, "each visible rule symbol and label fits its column without clipping")
	for contract in view.footer_text_contracts():
		var measured := ThemeDB.fallback_font.get_string_size(contract.text, HORIZONTAL_ALIGNMENT_LEFT, -1, contract.font_size).x
		var line_rect := Rect2(contract.origin.x, contract.origin.y - contract.font_size, contract.width, contract.font_size)
		_expect(contract.origin.x == safe.position.x and contract.width == safe.size.x, "footer draw_string starts at safe left edge and uses the full measured text box")
		_expect(is_equal_approx(contract.origin.x + contract.width * 0.5, 640.0), "center-aligned footer text box is actually centered in the viewport")
		_expect(measured <= contract.width and safe.encloses(line_rect), "current footer label fits its measured width and vertical safe band")
	_expect(view.text_layout_bounds().size() == 5, "title, controls, rules, status and help each have measured safe regions")
	_expect(view.geometry_bounds().position.y >= 130.0 and view.geometry_bounds().end.y <= 640.0, "miniature table remains fully within the playable vertical band")

func _test_mouse_keyboard_and_reduced_motion() -> void:
	var requests: Array[int] = []
	view.seat_requested.connect(func(index: int) -> void: requests.append(index))
	view.input(_mouse_event(Vector2(247, 379)))
	_expect(requests == [0], "pointer click on the first tabletop seat routes through the public signal")
	requests.clear()
	view.grab_focus()
	view.input(_key_event(KEY_RIGHT))
	view.input(_key_event(KEY_ENTER))
	_expect(requests == [1], "keyboard moves the visible seat cursor and confirms its active seat")
	var model = Model.new()
	model.select_seat(0)
	model.select_seat(2)
	view.update_frame(model.snapshot(), "night", true)
	_expect(view.playfield_rect().position.y == 130.0 and view.playfield_rect().end.y <= 640.0, "reduced-motion presentation keeps interaction targets in readable reserved bounds")
	_expect(view.seat_highlight_kind(0) == "moving" and view.seat_highlight_kind(2) == "moving", "both seats in the live exchange remain visually identified")
	_expect(view.seat_highlight_kind(1) == "idle", "unrelated seats remain visually distinct from the exchange")

func _mouse_event(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event

func _key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	return event
