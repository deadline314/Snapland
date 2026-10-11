extends RefCounted
## Phase picker and optional, location-gated time-postcard collection panel.

const Paper = preload("res://game/ui/paper_ui.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")

var host: Node
var body: VBoxContainer
var current_phase := TimeOfDay.DEFAULT_PHASE
var collected: Array[String] = []
var frame_paths: Dictionary = {}
var can_collect_here := false
var collecting := false
var on_select_phase: Callable
var on_collect_postcard: Callable
var phase_summary: Label
var collection_summary: Label
var status: Label
var postcard_grid: GridContainer
var phase_buttons: Dictionary = {}
var collect_button: Button


func open(
	main: Node,
	modal_body: VBoxContainer,
	phase_id: Variant,
	postcards: Dictionary,
	allow_collection: bool,
	select_callback: Callable,
	collect_callback: Callable
) -> void:
	host = main
	body = modal_body
	current_phase = TimeOfDay.normalize(phase_id)
	collected.clear()
	frame_paths.clear()
	collecting = false
	for phase: Dictionary in TimeOfDay.PHASES:
		var phase_key := str(phase.id)
		var card_id := TimeOfDay.postcard_id(phase_key)
		if not postcards.has(card_id):
			continue
		var record: Variant = postcards.get(card_id, {})
		if typeof(record) != TYPE_DICTIONARY:
			continue
		collected.append(card_id)
		var frames: Variant = record.get("frames", [])
		if frames is Array and not frames.is_empty() and typeof(frames[0]) == TYPE_STRING:
			frame_paths[phase_key] = str(frames[0])
	can_collect_here = allow_collection
	on_select_phase = select_callback
	on_collect_postcard = collect_callback
	_build()
	_refresh()


func _build() -> void:
	body.add_child(Paper.label("隨時換個時段看看海島。只改光線與景色，不推進遊園進度。", 19, Paper.TEAL))
	phase_summary = Paper.label("", 25)
	body.add_child(phase_summary)
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 8)
	body.add_child(choices)
	phase_buttons.clear()
	for phase: Dictionary in TimeOfDay.PHASES:
		var phase_id := str(phase.id)
		var button := Paper.button("%s  ·  %s" % [str(phase.label), str(phase.clock)], func(): _choose_phase(phase_id), choices)
		button.name = "TimePhase_%s" % phase_id
		button.toggle_mode = true
		phase_buttons[phase_id] = button
	collection_summary = Paper.label("", 18, Paper.TEAL)
	body.add_child(collection_summary)
	var postcard_scroll := ScrollContainer.new()
	postcard_scroll.custom_minimum_size = Vector2(0, 154)
	postcard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	postcard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(postcard_scroll)
	postcard_grid = GridContainer.new()
	postcard_grid.columns = 4
	postcard_grid.add_theme_constant_override("h_separation", 8)
	postcard_grid.add_theme_constant_override("v_separation", 8)
	postcard_scroll.add_child(postcard_grid)
	_refresh_postcard_cards()
	if can_collect_here:
		collect_button = Paper.button("", _collect_current, body)
		collect_button.name = "CollectTimePostcard"
	else:
		collect_button = null
		body.add_child(Paper.label("到中央廣場的導覽合照點，可收集目前時段的紀念拍貼。", 16, Paper.GOLD))
	status = Paper.label("", 16, Paper.TEAL)
	body.add_child(status)

func _refresh_postcard_cards() -> void:
	for child in postcard_grid.get_children():
		postcard_grid.remove_child(child)
		child.queue_free()
	for phase: Dictionary in TimeOfDay.PHASES:
		var phase_id := str(phase.id)
		var earned := collected.has(TimeOfDay.postcard_id(phase_id))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(210, 126)
		card.add_theme_stylebox_override("panel", Paper.plaque(Color("#fff9e9") if earned else Color("#e9e3d4")))
		var card_body := VBoxContainer.new()
		card_body.add_theme_constant_override("separation", 3)
		card.add_child(card_body)
		var image := _load_frame(str(frame_paths.get(phase_id, "")))
		if image != null:
			var thumbnail := TextureRect.new()
			thumbnail.texture = image
			thumbnail.custom_minimum_size = Vector2(178, 72)
			thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card_body.add_child(thumbnail)
		else:
			card_body.add_child(Paper.icon("album" if earned else "ticket", 30, Paper.TEAL if earned else Color("#978e7a")))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(copy)
		copy.add_child(Paper.label("%s · %s" % [str(phase.label), str(phase.clock)], 18, Paper.TEAL))
		copy.add_child(Paper.label("已收進紀念拍貼" if earned else "尚未收藏", 15))
		postcard_grid.add_child(card)


func _choose_phase(phase_id: String) -> void:
	if phase_id == current_phase:
		return
	if not on_select_phase.is_valid() or on_select_phase.call(phase_id) != true:
		status.text = "時段沒有套用，請稍後再試。"
		return
	current_phase = phase_id
	status.text = "已切換到%s。" % TimeOfDay.phase_for_id(current_phase).label
	_refresh()


func _collect_current() -> void:
	var phase_id := current_phase
	var card_id := TimeOfDay.postcard_id(phase_id)
	if collecting or not can_collect_here or collected.has(card_id):
		return
	if not on_collect_postcard.is_valid():
		status.text = "拍貼沒有收進收藏，請確認目前位置。"
		return
	collecting = true
	_refresh()
	var frame_path: Variant = await on_collect_postcard.call(phase_id)
	if not is_instance_valid(status):
		return
	collecting = false
	if typeof(frame_path) != TYPE_STRING or str(frame_path).is_empty():
		status.text = "拍貼沒有收進收藏；請重試，這次不會扣幣。"
		_refresh()
		return
	collected.append(card_id)
	frame_paths[phase_id] = str(frame_path)
	_refresh_postcard_cards()
	status.text = "已收藏%s時段拍貼，獲得 20 枚海島幣。" % TimeOfDay.phase_for_id(phase_id).label
	_refresh()


func _refresh() -> void:
	var phase: Dictionary = TimeOfDay.phase_for_id(current_phase)
	phase_summary.text = "目前時段：%s　%s" % [str(phase.label), str(phase.clock)]
	collection_summary.text = "時段拍貼：%d / %d" % [collected.size(), TimeOfDay.PHASES.size()]
	for phase_id in phase_buttons:
		var button: Button = phase_buttons[phase_id]
		button.button_pressed = phase_id == current_phase
		button.disabled = phase_id == current_phase
	if collect_button == null:
		return
	var card_id := TimeOfDay.postcard_id(current_phase)
	var already_collected := collected.has(card_id)
	collect_button.text = "目前時段拍貼已收藏" if already_collected else "收集目前時段拍貼　+20 幣"
	collect_button.disabled = already_collected or collecting

func _load_frame(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.get_width() != 320 or image.get_height() != 180:
		return null
	return ImageTexture.create_from_image(image)
