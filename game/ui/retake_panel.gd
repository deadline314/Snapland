extends Control
## A reversible themed set. The owner alone persists and awards the selected card.
signal capture_requested(image: Image)
signal close_requested()

const Paper = preload("res://game/ui/paper_ui.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Lessons = preload("res://game/ui/tutorial_catalog.gd")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const PHOTO_SIZE := Vector2i(1280,720)
const MAX_PIXELS := 4 * 1024 * 1024
const PROPS := [
	["balloon","mailbox","kite"], ["kite","balloon","lantern"],
	["flower_horn","lantern","camera"], ["sign","visitor","tourist_blue"],
	["hat","visitor","tourist_coral"], ["mascot","visitor","flower_horn"],
	["camera","lantern","sign"], ["flower_horn","lantern","mascot"],
	["bench","visitor","tourist_gold"], ["lantern","sign","camera"],
	["sign","mailbox","lantern"], ["flower_horn","lantern","camera"],
	["lantern","sign","bench"], ["sign","lantern","visitor"], ["lantern","camera","sign"], ["sign","mailbox","visitor"], ["mascot","flower_horn","visitor"], ["bench","sign","tourist_blue"], ["mailbox","lantern","tourist_coral"]]
const PROP_LABELS := {"balloon":"氣球", "mailbox":"郵箱", "kite":"風箏", "lantern":"燈籠", "flower_horn":"花喇叭", "camera":"相機", "sign":"指示牌", "visitor":"旅人", "tourist_blue":"藍衣旅人", "tourist_coral":"珊瑚旅人", "hat":"帽子", "mascot":"吉祥物", "bench":"長椅", "tourist_gold":"金衣旅人"}

class CopyScroll extends ScrollContainer:
	func _get_minimum_size() -> Vector2:
		return custom_minimum_size

class SetPicture extends Control:
	var backdrop: Texture2D
	var hero: Texture2D
	var prop: Texture2D
	var title := ""
	var framing := 1
	var distance := 1
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color("#0c2938"))
		draw_rect(Rect2(32,100,1216,576),Color("#163d4d"))
		draw_rect(Rect2(44,112,1192,480),Color("#31596a"))
		if backdrop != null:
			var extent := backdrop.get_size()*minf(1156.0/backdrop.get_width(),420.0/backdrop.get_height())
			draw_texture_rect(backdrop,Rect2(Vector2(640,340)-extent*0.5,extent),false,Color(0.65,0.72,0.72))
		draw_rect(Rect2(44,550,1192,126),Color("#102f41"))
		draw_line(Vector2(44,550),Vector2(1236,550),Color("#80e6c2"),4)
		var zoom: float = [1.18,1.0,0.8][distance]
		var center: float = [470.0,640.0,810.0][framing]
		if hero != null:
			var height := 410.0*zoom
			var width := height*hero.get_width()/hero.get_height()
			draw_texture_rect(hero,Rect2(center-220*zoom-width/2,620-height,width,height),false)
		if prop != null:
			var height := 270.0*zoom
			var width := height*prop.get_width()/prop.get_height()
			draw_texture_rect(prop,Rect2(center+170*zoom-width/2,620-height,width,height),false)
		draw_string(Paper.font(),Vector2(50,64),title+"｜補拍布景／非挑戰成績",HORIZONTAL_ALIGNMENT_LEFT,1180,30,Color("#f0f0d8"))
		draw_string(Paper.font(),Vector2(80,168),"示範背景",HORIZONTAL_ALIGNMENT_LEFT,400,22,Color("#f0f0d8"))
		draw_rect(Rect2(24,24,1232,672),Color("#ffc66d"),false,4)

var current_step := 0
var _configured := false
var _definition: Dictionary = {}
var _devil := false
var _lesson: Dictionary = {}
var _source: Texture2D
var _valid := false
var _closed := false
var _capturing := false
var _awaiting_result := false
var _saved := false
var _capture_generation := 0
var _framing := 1
var _decoration := 0
var _distance := 1
var _props: Array[Texture2D] = []
var _viewport: SubViewport
var _picture: SetPicture
var _preview: TextureRect
var _title: Label
var _step: Label
var _hint: Label
var _status: Label
var _choices: VBoxContainer
var _choice_buttons: Array[Button] = []
var _back: Button
var _next: Button
var _shutter: Button
var _close: Button
var _column: VBoxContainer
var _scroll: ScrollContainer
var _previous_focus: WeakRef

func setup(definition: Dictionary, devil: bool, lesson: Dictionary) -> void:
	if _configured: return
	_configured = true
	var id := str(definition.get("id",""))
	var canonical := Catalog.find(id)
	if canonical.is_empty() or canonical.id != id or definition != canonical: return
	var expected := Lessons.new().get_lesson(id)
	if expected.is_empty() or lesson != expected: return
	_definition = canonical.duplicate(true)
	_devil = devil
	_lesson = expected

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Paper.theme()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: _previous_focus = weakref(focus)
	_build_ui()
	_valid = _load_set()
	_refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()
	(_next if _valid else _close).grab_focus()

static func _valid_texture(texture: Texture2D) -> bool:
	if texture == null: return false
	var width := texture.get_width()
	var height := texture.get_height()
	return width > 0 and height > 0 and width <= MAX_PIXELS and height <= MAX_PIXELS and width*height <= MAX_PIXELS

func _load_set() -> bool:
	if _definition.is_empty():
		_status.text = "補拍資料不符，請關閉後重新選擇。"
		return false
	var path: String = _lesson.steps[0].image
	if not path.begins_with(Lessons.SCREENSHOT_ROOT) or path.contains("..") or not path.ends_with(".png") or not ResourceLoader.exists(path):
		return _source_error()
	_source = ResourceLoader.load(path) as Texture2D
	if not _valid_texture(_source): return _source_error()
	var image := _source.get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(_source.get_size()): return _source_error()
	var atlas := load("res://assets/minigames/props/tidal-props-v2.png") as Texture2D
	var regions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/minigames/props/regions.json"))
	if atlas == null or not regions is Dictionary: return _source_error()
	var prop_index := int(_definition.id.trim_prefix("game-"))-1
	# A delivered game without a themed prop row fails closed instead of indexing past the table.
	if prop_index < 0 or prop_index >= PROPS.size(): return _source_error()
	for key in PROPS[prop_index]:
		var region: Variant = regions.get(key)
		if not region is Array or region.size() != 4: return _source_error()
		var rect := Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
		if rect.size.x <= 0 or rect.size.y <= 0 or not Rect2(Vector2.ZERO,atlas.get_size()).encloses(rect): return _source_error()
		var prop := AtlasTexture.new()
		prop.atlas = atlas
		prop.region = rect
		prop.filter_clip = true
		_props.append(prop)
	var renderer := AvatarRenderer.new()
	_picture.hero = renderer.texture(Progress.appearance,Progress.equipped,"front",0,"photograph")
	if not _valid_texture(_picture.hero): return _source_error()
	_picture.backdrop = _source
	_picture.title = _definition.name
	_update_picture()
	return true

func _source_error() -> bool:
	_source = null
	_status.text = "示範圖片或布景暫時無法載入，請關閉後重試。未拍攝或發放拍貼。"
	return false

func _build_ui() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel",Paper.box(Color("#102b3a"),0))
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation",8)
	margin.add_child(_column)
	_title = Paper.label("免費補拍",24)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_column.add_child(_title)
	_step = Paper.label("",20)
	_column.add_child(_step)
	_hint = Paper.label("",18)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_hint)
	_viewport = SubViewport.new()
	_viewport.name = "RetakePhotoViewport"
	_viewport.size = PHOTO_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_picture = SetPicture.new()
	_picture.size = Vector2(PHOTO_SIZE)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport.add_child(_picture)
	_preview = TextureRect.new()
	_preview.name = "PhotographPreview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_preview)
	_scroll = CopyScroll.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 0.45
	_column.add_child(_scroll)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(copy)
	_status = Paper.label("",18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_status)
	_choices = VBoxContainer.new()
	copy.add_child(_choices)
	for index in range(3):
		var button := Paper.button("",_cycle_choice.bind(index),_choices)
		button.name = ["FramingChoice","DecorationChoice","DistanceChoice"][index]
		button.focus_entered.connect(func(): _scroll.ensure_control_visible(button))
		_choice_buttons.append(button)
	var navigation := HBoxContainer.new()
	_column.add_child(navigation)
	_back = Paper.button("上一步",_previous_step,navigation)
	_back.name = "RetakeBack"
	_next = Paper.button("下一步",_next_step,navigation)
	_next.name = "RetakeNext"
	_shutter = Paper.button("拍攝",_request_capture,navigation)
	_shutter.name = "RetakeShutter"
	_close = Paper.button("關閉",_request_close,navigation)
	_close.name = "RetakeClose"
	for button in [_back,_next,_shutter,_close]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _layout() -> void:
	if _preview == null: return
	var factor := 1.0 if DisplayServer.get_name() == "headless" else Paper.physical_scale(self)
	Paper.adapt_menu(_column,factor)
	_preview.custom_minimum_size.y = 100.0/factor
	_scroll.custom_minimum_size.y = 64.0/factor

func _refresh() -> void:
	_title.text = "免費補拍｜%s · %s卡" % [_definition.get("name","資料待確認"),"小惡魔" if _devil else "普通"]
	_step.text = ["1／3 觀察示範","2／3 調整布景","3／3 拍攝布景"][current_step]
	_hint.text = ["這是教學示範，並非本次遊玩。下一步可自在佈置，沒有計時。", "補拍布景／非挑戰成績。Tab 選項、Enter 輪選；可隨時返回。", "預覽就是快門影像。補拍只收藏所選卡，不代表完成挑戰。"][current_step]
	_choices.visible = current_step == 1 and _valid
	_preview.texture = _source if current_step == 0 else _viewport.get_texture()
	if _valid:
		if current_step == 0: _status.text = "示範重點："+str(_lesson.steps[0].goal)
		_choice_buttons[0].text = "取景："+["左側","置中","右側"][_framing]
		_choice_buttons[1].text = "道具："+PROP_LABELS[PROPS[int(_definition.id.trim_prefix("game-"))-1][_decoration]]
		_choice_buttons[2].text = "景別："+["近景","標準","廣角"][_distance]
	var locked := _capturing or _awaiting_result or _saved or _closed
	_back.disabled = not _valid or current_step == 0 or locked
	_next.disabled = not _valid or current_step == 2 or locked
	_shutter.disabled = not _valid or current_step != 2 or locked
	for button in _choice_buttons: button.disabled = locked

func _cycle_choice(index: int) -> void:
	if not _valid or current_step != 1 or _capturing or _awaiting_result or _saved or _closed: return
	match index:
		0: _framing = (_framing+1)%3
		1: _decoration = (_decoration+1)%3
		2: _distance = (_distance+1)%3
	_update_picture()
	_refresh()

func _update_picture() -> void:
	_picture.framing = _framing
	_picture.distance = _distance
	_picture.prop = _props[_decoration]
	_picture.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _next_step() -> void:
	if _next.disabled: return
	current_step += 1
	_status.text = ""
	_refresh()
	(_shutter if current_step == 2 else _choice_buttons[0]).grab_focus()

func _previous_step() -> void:
	if _back.disabled: return
	current_step -= 1
	_status.text = ""
	_refresh()
	_next.grab_focus()

func _request_capture() -> void:
	if _shutter.disabled: return
	if DisplayServer.get_name() == "headless":
		_status.text = "目前無法讀取攝影畫面，請在遊戲視窗中重試。"
		return
	_capturing = true
	_capture_generation += 1
	var generation := _capture_generation
	_status.text = "正在拍攝…"
	_refresh()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or _closed or generation != _capture_generation: return
	var image := _viewport.get_texture().get_image()
	_capturing = false
	if image == null or image.is_empty() or image.get_size() != PHOTO_SIZE:
		_status.text = "拍攝失敗，請重試。"
		_refresh()
		return
	_awaiting_result = true
	_status.text = "正在保存…"
	_refresh()
	capture_requested.emit(image)

func set_capture_result(saved: bool, message: String) -> void:
	if not _awaiting_result or _closed: return
	_awaiting_result = false
	_saved = saved
	_status.text = message if not message.is_empty() else ("補拍已保存。" if saved else "保存失敗，請重試。")
	_refresh()
	(_close if saved else _shutter).grab_focus()

func _request_close() -> void:
	if _closed: return
	_closed = true
	_capture_generation += 1
	_refresh()
	close_requested.emit()

func _exit_tree() -> void:
	_closed = true
	_capture_generation += 1
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible or _closed or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		_request_close()
		get_viewport().set_input_as_handled()
