extends Control

const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const HAIRSTYLES := ["windswept", "bob", "curly"]
const SKINS := ["warm", "deep", "bronze", "cool", "olive"]
const CYCLE_FPS := 8.0

var _renderers: Array = []
var _cells: Array[TextureRect] = []
var _cards: Array[VBoxContainer] = []
var _labels: Array[Label] = []
var _grid: GridContainer
var _scroller: ScrollContainer
var _status: Label
var _focus: TextureRect
var _focus_status: Label
var _focus_panel: VBoxContainer
var _elapsed := 0.0
var _frame := 0
var _paused := false
var _quarter_speed := false
var _hat_index := 1
var _species_index := 1
var _skin_index := 0
var _focus_direction_index := 0
var _focus_style_index := 0
var _hats := ["hat-none", "hat-straw", "hat-sailor", "hat-flower"]
var _species := ["human", "elf", "imp"]

func _ready() -> void:
	var requested_layout_size := OS.get_environment("SNAPLAND_ATTACHMENT_LAYOUT_SIZE")
	if not requested_layout_size.is_empty():
		var dimensions := requested_layout_size.split("x")
		if dimensions.size() == 2:
			get_viewport().size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	# Keep each style's 8 directions × 8 walk frames in its own bounded renderer
	# cache. A single renderer would churn its 128-entry LRU while this gallery
	# visits 3 × 64 combinations, recompositing the same cells on every refresh.
	for _style in HAIRSTYLES:
		_renderers.append(AvatarRenderer.new())
	_build_review_grid()
	resized.connect(_update_review_layout)
	_update_review_layout()
	_refresh()
	if OS.get_environment("SNAPLAND_ATTACHMENT_LAYOUT_CHECK") == "1":
		call_deferred("_assert_layout_fit")

func _process(delta: float) -> void:
	if _paused:
		return
	_elapsed += delta * (0.25 if _quarter_speed else 1.0)
	var next_frame := int(floor(_elapsed * CYCLE_FPS)) % 8
	if next_frame != _frame:
		_frame = next_frame
		_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_Q:
			_quarter_speed = not _quarter_speed
		KEY_H:
			_hat_index = (_hat_index + 1) % _hats.size()
		KEY_S:
			_species_index = (_species_index + 1) % _species.size()
		KEY_K:
			_skin_index = (_skin_index + 1) % SKINS.size()
		KEY_LEFT:
			_frame = posmod(_frame - 1, 8)
			_elapsed = float(_frame) / CYCLE_FPS
		KEY_RIGHT:
			_frame = posmod(_frame + 1, 8)
			_elapsed = float(_frame) / CYCLE_FPS
		KEY_UP:
			_focus_direction_index = posmod(_focus_direction_index - 1, DIRECTIONS.size())
		KEY_DOWN:
			_focus_direction_index = posmod(_focus_direction_index + 1, DIRECTIONS.size())
		KEY_TAB:
			_focus_style_index = (_focus_style_index + 1) % HAIRSTYLES.size()
		_:
			return
	_refresh()

func _build_review_grid() -> void:
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	outer.add_theme_constant_override("margin_left", 12)
	outer.add_theme_constant_override("margin_right", 12)
	outer.add_theme_constant_override("margin_top", 10)
	outer.add_theme_constant_override("margin_bottom", 10)
	add_child(outer)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 38
	outer.add_child(_status)
	var review_row := HBoxContainer.new()
	review_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(review_row)
	_scroller = ScrollContainer.new()
	_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_row.add_child(_scroller)
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroller.add_child(_grid)
	var corner := Label.new()
	corner.text = "Style / view"
	corner.add_theme_font_size_override("font_size", 10)
	_grid.add_child(corner)
	for direction in DIRECTIONS:
		var heading := Label.new()
		heading.text = direction
		heading.add_theme_font_size_override("font_size", 10)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(heading)
	for style in HAIRSTYLES:
		var row_label := Label.new()
		row_label.text = style
		row_label.add_theme_font_size_override("font_size", 10)
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_grid.add_child(row_label)
		for direction in DIRECTIONS:
			var card := VBoxContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_grid.add_child(card)
			_cards.append(card)
			var cell := TextureRect.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			card.add_child(cell)
			_cells.append(cell)
			var meta := Label.new()
			meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			meta.add_theme_font_size_override("font_size", 9)
			card.add_child(meta)
			_labels.append(meta)
	_focus_panel = VBoxContainer.new()
	_focus_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	review_row.add_child(_focus_panel)
	_focus_status = Label.new()
	_focus_status.add_theme_font_size_override("font_size", 11)
	_focus_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focus_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_panel.add_child(_focus_status)
	_focus = TextureRect.new()
	_focus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_focus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_focus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_focus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_focus_panel.add_child(_focus)

func _update_review_layout() -> void:
	if _cards.is_empty() or _grid == null or _focus_panel == null:
		return
	var metrics := _layout_metrics(size)
	var focus_width: float = metrics.focus_width
	var cell_width: float = metrics.cell_width
	var image_height: float = metrics.image_height
	_focus_panel.custom_minimum_size.x = focus_width
	_focus.custom_minimum_size = Vector2(focus_width - 16.0, (focus_width - 16.0) * (360.0 / 280.0))
	for index in range(_cards.size()):
		_cards[index].custom_minimum_size = Vector2(cell_width, image_height + 20.0)
		_cells[index].custom_minimum_size = Vector2(cell_width, image_height)

func _layout_metrics(viewport_size: Vector2) -> Dictionary:
	var focus_width := clampf(viewport_size.x * 0.19, 220.0, 260.0)
	var fixed_width := 24.0 + focus_width + 64.0 + 36.0
	var cell_width := maxf(68.0, floorf((viewport_size.x - fixed_width) / float(DIRECTIONS.size())))
	var row_height := maxf(96.0, (viewport_size.y - 100.0) / float(HAIRSTYLES.size()))
	var image_height := minf(cell_width * (360.0 / 280.0), row_height - 20.0)
	return {"focus_width":focus_width, "cell_width":cell_width, "image_height":image_height}

func _assert_layout_fit() -> void:
	await get_tree().process_frame
	var grid_minimum := _grid.get_combined_minimum_size()
	assert(grid_minimum.x <= _scroller.size.x + 1.0, "all eight headings and columns fit the review viewport width")
	assert(grid_minimum.y <= _scroller.size.y + 1.0, "all three complete avatar rows fit without vertical scrolling")
	assert(_grid.get_global_rect().end.x <= _focus_panel.get_global_rect().position.x + 1.0, "last direction column ends before the full-size focus panel")
	assert(_focus.get_global_rect().end.x <= size.x + 1.0 and _focus.get_global_rect().end.y <= size.y + 1.0, "full-size focus avatar remains inside the review viewport")
	var wide_size := Vector2(1600.0, 900.0)
	var wide_metrics := _layout_metrics(wide_size)
	var wide_grid_width: float = 64.0 + float(wide_metrics.cell_width) * float(DIRECTIONS.size()) + 32.0
	var wide_grid_height: float = float(HAIRSTYLES.size()) * (float(wide_metrics.image_height) + 20.0) + 24.0
	assert(wide_grid_width + float(wide_metrics.focus_width) + 28.0 <= wide_size.x, "viewport-derived 1600px layout fits every direction plus the full-size focus panel")
	assert(wide_grid_height <= wide_size.y - 100.0, "viewport-derived 900px layout fits all three full avatar rows")
	print("ATTACHMENT_LAYOUT_FIT: viewport=%s grid_min=%s grid_view=%s focus=%s; 1600x900 projected_grid=(%.0f,%.0f) cell=%.0f focus=%.0f" % [size, grid_minimum, _scroller.size, _focus.size, wide_grid_width, wide_grid_height, wide_metrics.cell_width, wide_metrics.focus_width])

func _refresh() -> void:
	if _renderers.size() != HAIRSTYLES.size():
		return
	var appearance := {"skin":SKINS[_skin_index], "species":_species[_species_index], "gender":"neutral", "hair":"windswept", "hair_color":"ink", "face":"curious"}
	var equipped := {"outfit":"outfit-tide", "hat":_hats[_hat_index]}
	var column := 0
	for style_index in range(HAIRSTYLES.size()):
		var style: String = HAIRSTYLES[style_index]
		var renderer = _renderers[style_index]
		appearance["hair"] = style
		for direction in DIRECTIONS:
			var cell := _cells[column]
			var meta := _labels[column]
			cell.texture = renderer.texture(appearance, equipped, direction, _frame, "walk")
			var anchor: Vector2i = renderer.walk_head_anchor(direction, _frame)
			meta.text = "f%d · h%d,%d" % [_frame, anchor.x, anchor.y]
			column += 1
	var focus_direction: String = DIRECTIONS[_focus_direction_index]
	var focus_style: String = HAIRSTYLES[_focus_style_index]
	var focus_renderer = _renderers[_focus_style_index]
	appearance["hair"] = focus_style
	_focus.texture = focus_renderer.texture(appearance, equipped, focus_direction, _frame, "walk")
	var focus_anchor: Vector2i = focus_renderer.walk_head_anchor(focus_direction, _frame)
	_focus_status.text = "Full size: %s / %s\nframe %d · head %d,%d" % [focus_direction, focus_style, _frame, focus_anchor.x, focus_anchor.y]
	var rate := "quarter speed (0.25×)" if _quarter_speed else "normal speed (1×)"
	var state := "paused" if _paused else "playing"
	_status.text = "Avatar attachment review | %s | %s | frame %d/7 | elapsed %.2fs | hat: %s | species: %s | skin: %s | Space pause, Q speed, ←/→ step, ↑/↓ focus direction, Tab focus hair, H hat, S species, K skin" % [rate, state, _frame, _elapsed, _hats[_hat_index], _species[_species_index], SKINS[_skin_index]]
