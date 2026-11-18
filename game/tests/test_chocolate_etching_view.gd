extends SceneTree

const VIEW_PATH := "res://game/minigames/chocolate_etching_view.gd"
const Model = preload("res://game/minigames/chocolate_etching_model.gd")
var checks := 0
var failures := 0
const Route = preload("res://game/tests/test_chocolate_etching_driver.gd").Route

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(VIEW_PATH):
		print("FAIL: missing Chocolate Etching View at ", VIEW_PATH)
		quit(1)
		return
	var script: Script = load(VIEW_PATH)
	var view: Control = script.new()
	var model := Model.new()
	var state := model.snapshot()
	var unchanged := state.duplicate(true)
	view.present(state, "noon", false)
	root.add_child(view)
	await process_frame
	check(state == unchanged, "presentation does not write to supplied state")
	check(view.focus_mode == Control.FOCUS_ALL, "workbench can hold keyboard focus")
	check(script.COMMANDS == ["left", "right", "up", "down", "select", "shallow", "deep", "tool", "fold", "phase", "undo", "helper"], "all 12 commands in design order")
	check(script.KEYS.size() == 16 and script.KEYS[KEY_W] == script.KEYS[KEY_UP] and script.KEYS[KEY_A] == script.KEYS[KEY_LEFT], "physical direction aliases and 8 specialist commands")
	var controls := view.find_children("*", "Button", false, false)
	check(controls.size() == 12, "12 fixed controls")
	for command in script.COMMANDS:
		var button: Button = view.get_node(command.capitalize())
		var rect: Rect2 = script.button_rect(command)
		check(button.get_rect().is_equal_approx(rect) and script.COMMAND_PANEL.encloses(rect) and script.command_at(script.command_center(command)) == command,
			"model input and retained hit geometry agree at " + command)
	for point: Vector2 in [Vector2.ZERO, Vector2(720, 440), Vector2(160, 190), Vector2(330, 318)]:
		var design_point: Vector2 = script.board_to_design(point)
		check(point.distance_to(script.design_to_board(design_point)) < 0.0001, "aspect-fit forward/reverse round trip")
	check(script.BOARD_PANEL.encloses(script.WORKSPACE) and is_equal_approx(script.WORKSPACE.size.aspect(), 720.0 / 440.0), "720 by 440 workspace remains aspect-fitted to the board")
	var clip: Control = view.get_node("ClippedWorkspace")
	check(clip.clip_contents and clip.get_rect().is_equal_approx(script.WORKSPACE)
		and clip.get_node("BoardCanvas").scale.is_equal_approx(Vector2.ONE * script.BOARD_SCALE), "board preview and drawing remain clipped to the same workspace as input")
	check(script.command_at(script.WORKSPACE.get_center()).is_empty() and script.button_rect("unknown") == Rect2(), "drawing area cannot select a command")
	check(view.get_node("Feedback").text == state.feedback and view.get_node("Scoring").text.contains("最近 8 次"), "persistent feedback and actual undo boundary")
	check(layout_errors(view, Rect2(Vector2.ZERO, script.DESIGN_SIZE)).is_empty(), "all initial labels and controls fit")
	var baseline := retained_ids(view)
	for i in 120:
		if i % 12 == 0:
			model.reset(bool(i % 24), i % 2)
			model.toggle_phase()
		model.step(1.0 / 60.0)
		view.present(model.snapshot(), "night", true)
	check(retained_ids(view) == baseline, "120 presentations and ten model retries preserve node/style/font identities")
	check(view.get_node("Mode").text.contains("試裝板") and view.get_node("Progress").text.contains("出口"),
		"reduced motion retains assembly mode and output state")
	check(view.get_node("Instruction").text.contains("原位按 F 取下"), "assembly describes keyboard placement and take-off")
	check(layout_errors(view, Rect2(Vector2.ZERO, script.DESIGN_SIZE)).is_empty(), "all assembly labels and controls fit")
	var route := Route.new("pointer", false, 0)
	check(route.craft(false), "progress fixture extracts three wheels")
	route.arrange(false)
	route.command("tool", true)
	route.advance(0.995 * TAU / 2.0)
	var almost: Dictionary = route.driver.snapshot()
	view.present(almost, "noon", false)
	check(not almost.success and almost.output_percent == 99 and almost.progress_text.ends_with("99%") and view.get_node("Progress").text.contains("99%"),
		"HUD and workbench both show 99% at 99.5% of a real turn")
	route.advance(0.1)
	var done: Dictionary = route.driver.snapshot()
	view.present(done, "noon", false)
	check(done.success and done.output_percent == 100 and done.progress_text.ends_with("100%") and view.get_node("Progress").text.contains("100%"),
		"both readouts reach 100% with real transmission completion")
	print("RETAINED ", JSON.stringify({"node_ids": baseline.nodes, "font_ids": baseline.fonts, "style_ids": baseline.styles, "presentations": 120, "retries": 10}))
	view.queue_free()
	await process_frame
	print("Chocolate etching view: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

static func retained_ids(view: Control) -> Dictionary:
	var ids := {"nodes": [view.get_instance_id()], "fonts": [], "styles": []}
	for child in view.find_children("*", "", true, false):
		ids.nodes.append(child.get_instance_id())
		if child is Label or child is Button:
			var font: Font = child.get_theme_font("font")
			if font.get_instance_id() not in ids.fonts:
				ids.fonts.append(font.get_instance_id())
		if child is Button:
			for name in ["normal", "pressed"]:
				var style: StyleBox = child.get_theme_stylebox(name)
				if style.get_instance_id() not in ids.styles:
					ids.styles.append(style.get_instance_id())
	return ids

static func _screen_rect(control: Control) -> Rect2:
	var transformed := control.get_global_transform_with_canvas()
	return Rect2(transformed * Vector2.ZERO, transformed * control.size - transformed * Vector2.ZERO)

static func layout_errors(view: Control, viewport_rect: Rect2) -> Array[String]:
	var errors: Array[String] = []
	for item: Control in view.find_children("*", "Control", true, false):
		if not item.is_visible_in_tree():
			continue
		var screen := _screen_rect(item)
		var room := viewport_rect.intersection(_screen_rect(view))
		var ancestor := item.get_parent()
		while ancestor is Control:
			if ancestor.clip_contents:
				room = room.intersection(_screen_rect(ancestor))
			ancestor = ancestor.get_parent()
		if not room.grow(0.01).encloses(screen):
			errors.append("%s outside visible ancestor bounds %s in %s" % [item.name, screen, room])
		if not (item is Label or item is Button):
			continue
		var font := item.get_theme_font("font")
		var size_pt := item.get_theme_font_size("font_size")
		var content := item.size
		if item is Button:
			content -= item.get_theme_stylebox("normal").get_minimum_size()
		var lines: PackedStringArray = item.text.split("\n")
		var height := font.get_height(size_pt) * lines.size()
		for line in lines:
			var measured := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_pt)
			if measured.x > content.x + 0.01:
				errors.append("%s text width %.1f > %.1f (%s)" % [item.name, measured.x, content.x, line])
		if height > content.y + 0.01:
			errors.append("%s text height %.1f > %.1f" % [item.name, height, content.y])
	return errors
