extends VBoxContainer
## A paged paper book over the existing photo and achievement records.

const Paper = preload("res://game/ui/paper_ui.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")
const PAGE_SIZE := 6

class BookSpread extends Control:
	func _draw() -> void:
		var page_rect := Rect2(Vector2(4,5),Vector2(maxf(size.x-8,0),maxf(size.y-10,0)))
		draw_rect(Rect2(page_rect.position+Vector2(0,7),page_rect.size),Color("#795d40"))
		var half := page_rect.size.x*0.5
		draw_rect(Rect2(page_rect.position,Vector2(half,page_rect.size.y)),Color("#fffaf0"))
		draw_rect(Rect2(page_rect.position+Vector2(half,0),Vector2(half,page_rect.size.y)),Color("#f5ecd6"))
		draw_rect(Rect2(page_rect.position+Vector2(half-5,0),Vector2(10,page_rect.size.y)),Color("#c5a478"))
		draw_line(Vector2(half,page_rect.position.y+4),Vector2(half,page_rect.end.y-4),Color("#8d704e"),1.5)
		draw_rect(page_rect,Color("#9d805c"),false,2.0)

var _progress: Node
var _definitions: Array = []
var _time_phases: Array = []
var _photo_loader: Callable
var _category := "normal"
var _page := 0
var _spread: GridContainer
var _page_label: Label
var _empty_message: Label
var _collection_state: Label
var _photo_details: Label
var _normal_button: Button
var _devil_button: Button
var _time_button: Button

func setup(progress: Node, definitions: Array, phases: Array, photo_loader: Callable) -> void:
	_progress=progress
	_definitions=definitions.duplicate(true)
	_time_phases=phases.duplicate(true)
	_photo_loader=photo_loader

func _ready() -> void:
	custom_minimum_size.y=420
	add_theme_constant_override("separation",8)
	tooltip_text="收藏不消耗；重拍不重複計數。選取畫格，查看收藏方式。"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	add_child(tabs)
	_normal_button=Paper.button("普通拍貼  0 / 18",func(): _set_category("normal"),tabs)
	_normal_button.name="AlbumTab_normal"
	_devil_button=Paper.button("小惡魔  0 / 12",func(): _set_category("devil"),tabs)
	_devil_button.name="AlbumTab_devil"
	_time_button=Paper.button("四時明信片  0 / 4",func(): _set_category("time"),tabs)
	_time_button.name="AlbumTab_time"
	for button in [_normal_button,_devil_button,_time_button]:
		button.custom_minimum_size=Vector2(0,44)
	var cover := PanelContainer.new()
	cover.name="AlbumBookCover"
	cover.add_theme_stylebox_override("panel",Paper.plaque(Color("#c8a477")))
	cover.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(cover)
	var cover_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		cover_margin.add_theme_constant_override("margin_"+side,8)
	cover.add_child(cover_margin)
	var book_body := VBoxContainer.new()
	book_body.add_theme_constant_override("separation",4)
	cover_margin.add_child(book_body)
	var book_head := HBoxContainer.new()
	book_body.add_child(book_head)
	_page_label=Paper.label("第 1 / 1 頁",16,Color("#fff4db"))
	_page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	book_head.add_child(_page_label)
	var spread_surface := BookSpread.new()
	spread_surface.name="AlbumBookSpread"
	spread_surface.custom_minimum_size=Vector2(0,450.0/Paper.physical_scale(self))
	spread_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL
	book_body.add_child(spread_surface)
	_spread=GridContainer.new()
	_spread.name="AlbumPhotoGrid"
	_spread.columns=2
	_spread.add_theme_constant_override("h_separation",16)
	_spread.add_theme_constant_override("v_separation",8)
	_spread.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spread.offset_left=14
	_spread.offset_top=12
	_spread.offset_right=-14
	_spread.offset_bottom=-12
	_spread.add_theme_constant_override("h_separation",22)
	spread_surface.add_child(_spread)
	_photo_details=Paper.label("選取照片，查看收藏方式。",16,Paper.DEEP_TEAL)
	_photo_details.name="AlbumPhotoDetails"
	book_body.add_child(_photo_details)
	var nav := HBoxContainer.new()
	book_body.add_child(nav)
	var previous := Paper.button("← 上一頁",func(): _change_page(-1),nav)
	previous.name="AlbumPreviousPage"
	previous.custom_minimum_size=Vector2(130,44)
	var next := Paper.button("下一頁 →",func(): _change_page(1),nav)
	next.name="AlbumNextPage"
	next.custom_minimum_size=Vector2(130,44)
	var hint := Paper.label("照片縮圖只在實際存有可讀影格時顯示。",15,Color("#fff4db"))
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	nav.add_child(hint)
	_empty_message=Paper.label("這一類目前尚無收藏。拍照或完成對應挑戰後，照片會出現在本頁。",19,Paper.DEEP_TEAL)
	_empty_message.name="AlbumEmptyState"
	add_child(_empty_message)
	_collection_state=Paper.label("",16,Paper.CORAL)
	_collection_state.name="AlbumCollectionState"
	add_child(_collection_state)
	_refresh_book()

func _set_category(category: String) -> void:
	_category=category
	_page=0
	_refresh_book()

func _change_page(amount: int) -> void:
	var pages := maxi(1,ceili(float(_entries().size())/float(PAGE_SIZE)))
	_page=clampi(_page+amount,0,pages-1)
	_refresh_book()

func _refresh_book() -> void:
	if _progress==null or not is_instance_valid(_spread):
		return
	_normal_button.text="普通拍貼  %d / 18" % int(_progress.normal_count())
	_devil_button.text="小惡魔  %d / 12" % int(_progress.devil_count())
	var time_count := 0
	for phase in _time_phases:
		if phase is Dictionary and _progress.photos.has(TimeOfDay.postcard_id(str(phase.get("id","")))):
			time_count+=1
	_time_button.text="四時明信片  %d / 4" % time_count
	_collection_state.visible=int(_progress.normal_count())+int(_progress.devil_count())+time_count==0
	_collection_state.text="本子還是空白的。到迎賓大道拍照、完成小遊戲，或切換時段拍明信片，就能蓋下第一張記錄。"
	if Paper.physical_scale(self)<0.9:
		_normal_button.text="普通 %d / 18" % int(_progress.normal_count())
		_devil_button.text="小惡魔 %d / 12" % int(_progress.devil_count())
		_time_button.text="四時 %d / 4" % time_count
	var entries := _entries()
	var page_count := maxi(1,ceili(float(entries.size())/float(PAGE_SIZE)))
	_page=clampi(_page,0,page_count-1)
	_page_label.text="第 %d / %d 頁" % [_page+1,page_count]
	_empty_message.visible=entries.is_empty()
	for child in _spread.get_children():
		_spread.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		return
	for entry_index in range(entries.size()):
		var tile := _photo_tile(entries[entry_index],entry_index+1)
		tile.name="AlbumPhoto_"+str(entries[entry_index].id)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.visible=entry_index>=_page*PAGE_SIZE and entry_index<(_page+1)*PAGE_SIZE
		_spread.add_child(tile)
	Paper.adapt_menu(self,Paper.physical_scale(self))

func _entries() -> Array[Dictionary]:
	var entries: Array[Dictionary]=[]
	match _category:
		"normal":
			for game in _definitions:
				var number := int(str(game.get("id","game-000")).trim_prefix("game-"))
				entries.append(_entry("photo-welcome-game-%d" % number,str(game.get("name","遊戲 %02d" % number)),"完成迎賓大道這款小遊戲，拍照收藏普通拍貼。"))
			for exploration in [{"id":"photo-welcome-explore-1","name":"花壇會眨眼","how":"選表情並拍照。"},{"id":"photo-welcome-explore-2","name":"歡迎字樣的影子","how":"把字樣投影對準牆上空框後拍照。"},{"id":"photo-welcome-explore-3","name":"長椅雙人份","how":"借立牌、坐上長椅後按快門。"},{"id":"photo-welcome-story-1","name":"照片多了一條尾巴","how":"完成迎賓主線對話。"},{"id":"photo-welcome-quest-1","name":"吉祥物的尾巴危機","how":"完成小角的三步委託。"},{"id":"photo-welcome-quest-2","name":"廣播即興救場","how":"完成阿浪的三步委託。"}]:
				entries.append(_entry(str(exploration.id),str(exploration.name),str(exploration.how)))
		"devil":
			for game in _definitions:
				var number := int(str(game.get("id","game-000")).trim_prefix("game-"))
				entries.append(_entry("photo-welcome-devil-%d" % number,str(game.get("name","遊戲 %02d" % number))+" · 小惡魔",str(game.get("devil_hint","完成設施的特別條件。"))))
		"time":
			for phase in _time_phases:
				var id := str(phase.get("id",""))
				entries.append(_entry(TimeOfDay.postcard_id(id),str(phase.get("label","時段"))+" · "+str(phase.get("clock","")),"切換到這個時段，為園區拍攝紀念明信片。"))
	return entries

func _entry(photo_id: String, title: String, instructions: String) -> Dictionary:
	return {"id":photo_id,"title":title,"instructions":instructions}

func _photo_tile(entry: Dictionary, number: int) -> Control:
	var collected: bool=_progress.photos.has(entry.id)
	var tile := PanelContainer.new()
	tile.name="AlbumPhoto_"+str(entry.id)
	var menu_scale := Paper.physical_scale(self)
	tile.custom_minimum_size=Vector2(156.0/menu_scale,140.0/menu_scale)
	tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tile.focus_mode=Control.FOCUS_ALL
	tile.mouse_filter=Control.MOUSE_FILTER_STOP
	tile.tooltip_text=str(entry.instructions)
	var leaf_color := Color("#fffdf5") if (number%2)==1 else Color("#f5ecd6")
	tile.add_theme_stylebox_override("panel",Paper.box(leaf_color if collected else leaf_color.darkened(0.05),6))
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",3)
	tile.add_child(column)
	var photo_frame := PanelContainer.new()
	photo_frame.name="SavedPhotoFrame"
	photo_frame.custom_minimum_size=Vector2(140.0/menu_scale,72.0/menu_scale)
	photo_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	photo_frame.add_theme_stylebox_override("panel",Paper.plaque(Color("#e9dfc5")))
	column.add_child(photo_frame)
	var texture := _saved_texture(str(entry.id)) if collected else null
	if texture!=null:
		var thumbnail := TextureRect.new()
		thumbnail.texture=texture
		thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.custom_minimum_size=Vector2(140.0/menu_scale,60.0/menu_scale)
		thumbnail.mouse_filter=Control.MOUSE_FILTER_IGNORE
		photo_frame.add_child(thumbnail)
	else:
		var fallback_text := "已收藏 · 照片檔未讀取" if collected else "✦ %02d · 空白畫格 ✦" % number
		var blank := Paper.label(fallback_text,16,Paper.TEAL if collected else Color("#827b6b"))
		blank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		blank.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		blank.custom_minimum_size=Vector2(140.0/menu_scale,60.0/menu_scale)
		photo_frame.add_child(blank)
	var title := Paper.label(str(entry.title),17)
	title.name="AlbumPhotoTitle"
	title.custom_minimum_size.x=140.0/menu_scale
	column.add_child(title)
	column.add_child(Paper.label("已收藏" if collected else "尚未收藏",16,Paper.TEAL if collected else Color("#8c694a")))
	var method := Paper.label(str(entry.instructions),16,Paper.DEEP_TEAL)
	method.visible=false
	column.add_child(method)
	var show_details := func(): _photo_details.text=str(entry.title)+"｜"+str(entry.instructions)
	tile.mouse_entered.connect(show_details)
	tile.focus_entered.connect(show_details)
	return tile

func _blank_tile() -> Control:
	var blank := PanelContainer.new()
	blank.custom_minimum_size=Vector2(0,98)
	blank.add_theme_stylebox_override("panel",Paper.box(Color("#f2ead8"),6))
	var label := Paper.label("空白頁 · 留給下一張旅途照片",16,Color("#8c806a"))
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	blank.add_child(label)
	return blank

func _saved_texture(photo_id: String) -> Texture2D:
	var photo: Variant=_progress.photos.get(photo_id,{})
	if not photo is Dictionary:
		return null
	var frames: Variant=photo.get("frames",[])
	if not frames is Array:
		return null
	for path_value in frames:
		if typeof(path_value)==TYPE_STRING and FileAccess.file_exists(str(path_value)) and _photo_loader.is_valid():
			var texture: Variant=_photo_loader.call(str(path_value))
			if texture is Texture2D:
				return texture
	return null
