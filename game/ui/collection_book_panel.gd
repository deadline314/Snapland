extends VBoxContainer
## A paged paper book over the existing photo and achievement records.

const Paper = preload("res://game/ui/paper_ui.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")
const PhotoViewer = preload("res://game/ui/photo_viewer.gd")
const PAGE_SIZE := 4
const MAX_PHOTO_FRAME_CANDIDATES := 12
const MAX_LEGACY_UI_PHOTO_BYTES := 16 * 1024 * 1024

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
var _spread_surface: Control
var _page_label: Label
var _empty_message: Label
var _collection_state: Label
var _photo_details: Label
var _normal_button: Button
var _devil_button: Button
var _time_button: Button
var _game_photo_texture_cache: Dictionary = {}
var _thumbnail_decode_count := 0
var _original_decode_count := 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_spread_columns()

func setup(progress: Node, definitions: Array, phases: Array, photo_loader: Callable) -> void:
	_progress=progress
	_definitions=definitions.duplicate(true)
	_time_phases=phases.duplicate(true)
	_photo_loader=photo_loader
	_game_photo_texture_cache.clear()
	_thumbnail_decode_count=0
	_original_decode_count=0

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
	var cover_style := Paper.plaque(Color("#c8a477"))
	var menu_scale := Paper.physical_scale(self)
	cover_style.content_margin_left=4.0/menu_scale
	cover_style.content_margin_right=4.0/menu_scale
	cover_style.content_margin_top=4.0/menu_scale
	cover_style.content_margin_bottom=4.0/menu_scale
	cover.add_theme_stylebox_override("panel",cover_style)
	cover.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(cover)
	var cover_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		cover_margin.add_theme_constant_override("margin_"+side,8.0/menu_scale)
	cover.add_child(cover_margin)
	var book_body := VBoxContainer.new()
	book_body.add_theme_constant_override("separation",4)
	cover_margin.add_child(book_body)
	_spread_surface=BookSpread.new()
	_spread_surface.name="AlbumBookSpread"
	_spread_surface.custom_minimum_size=Vector2(0,432.0/menu_scale)
	_spread_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL
	book_body.add_child(_spread_surface)
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
	_spread_surface.add_child(_spread)
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
	_page_label=Paper.label("第 1 / 1 頁",16,Color("#fff4db"))
	_page_label.name="AlbumPageLabel"
	_page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_page_label)
	nav.move_child(_page_label,1)
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
	_photo_details.text = _category_prompt()
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
	_apply_responsive_spread_columns()
	for entry_index in range(entries.size()):
		var tile := _photo_tile(entries[entry_index])
		tile.name="AlbumPhoto_"+str(entries[entry_index].id)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.visible=entry_index>=_page*PAGE_SIZE and entry_index<(_page+1)*PAGE_SIZE
		_spread.add_child(tile)
	Paper.adapt_menu(self,Paper.physical_scale(self))
	_apply_responsive_spread_columns()

func _apply_responsive_spread_columns() -> void:
	if not is_instance_valid(_spread):
		return
	var physical_width := get_viewport_rect().size.x * Paper.physical_scale(self)
	var wide_layout := physical_width >= 1200.0
	_spread.columns=4 if wide_layout else 2
	if is_instance_valid(_spread_surface):
		_spread_surface.custom_minimum_size.y=(224.0 if wide_layout else 432.0)/Paper.physical_scale(self)
	_spread.add_theme_constant_override("h_separation",8.0/Paper.physical_scale(self))
	_spread.add_theme_constant_override("v_separation",8.0/Paper.physical_scale(self))

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
	var collected: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for entry in entries:
		if _progress != null and _progress.photos.has(entry.id):
			collected.append(entry)
		else:
			waiting.append(entry)
	# Partitioning preserves catalog order within both groups and never changes IDs.
	collected.append_array(waiting)
	return collected

func _category_prompt() -> String:
	match _category:
		"devil": return "小惡魔拍貼｜完成設施的特別條件，收藏的畫格會先出現。"
		"time": return "四時明信片｜切換園區時段，留下那一刻的實際照片。"
		_: return "普通拍貼｜完成遊戲、探索或委託，照片就會收進本子。"

func _entry(photo_id: String, title: String, instructions: String) -> Dictionary:
	return {"id":photo_id,"title":title,"instructions":instructions}

func _photo_tile(entry: Dictionary) -> Control:
	var collected: bool=_progress.photos.has(entry.id)
	var tile := Button.new()
	tile.name="AlbumPhoto_"+str(entry.id)
	var menu_scale := Paper.physical_scale(self)
	tile.custom_minimum_size=Vector2(232.0/menu_scale,200.0/menu_scale)
	tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tile.focus_mode=Control.FOCUS_ALL
	tile.mouse_filter=Control.MOUSE_FILTER_STOP
	tile.text=""
	tile.tooltip_text=str(entry.instructions)
	var leaf_color := Color("#fffdf5") if collected else Color("#f5ecd6")
	var tile_style := Paper.box(leaf_color if collected else leaf_color.darkened(0.05),6)
	tile.add_theme_stylebox_override("normal",tile_style)
	tile.add_theme_stylebox_override("hover",Paper.box(leaf_color.lightened(0.03),6))
	tile.add_theme_stylebox_override("pressed",Paper.box(leaf_color.darkened(0.04),6))
	tile.add_theme_stylebox_override("disabled",tile_style)
	tile.add_theme_stylebox_override("focus",Paper.box(Color(0,0,0,0),6))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",3)
	tile.add_child(column)
	var photo_frame := PanelContainer.new()
	photo_frame.name="SavedPhotoFrame"
	photo_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	photo_frame.custom_minimum_size=Vector2(220.0/menu_scale,124.0/menu_scale)
	photo_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var frame_style := Paper.plaque(Color("#e9dfc5"))
	frame_style.content_margin_left=4.0/menu_scale
	frame_style.content_margin_right=4.0/menu_scale
	frame_style.content_margin_top=4.0/menu_scale
	frame_style.content_margin_bottom=4.0/menu_scale
	photo_frame.add_theme_stylebox_override("panel",frame_style)
	column.add_child(photo_frame)
	var texture := _saved_texture(str(entry.id)) if collected else null
	if texture!=null:
		var thumbnail := TextureRect.new()
		thumbnail.texture=texture
		thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.custom_minimum_size=Vector2(220.0/menu_scale,124.0/menu_scale)
		thumbnail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		thumbnail.size_flags_vertical=Control.SIZE_EXPAND_FILL
		thumbnail.mouse_filter=Control.MOUSE_FILTER_IGNORE
		photo_frame.add_child(thumbnail)
	else:
		var fallback_text := "已收藏 · 暫時看不清楚" if collected else "等待一張照片"
		var blank := Paper.label(fallback_text,16,Paper.TEAL if collected else Color("#827b6b"))
		blank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		blank.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		blank.custom_minimum_size=Vector2(220.0/menu_scale,124.0/menu_scale)
		blank.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		blank.size_flags_vertical=Control.SIZE_EXPAND_FILL
		photo_frame.add_child(blank)
	var title := Paper.label(str(entry.title),17)
	title.name="AlbumPhotoTitle"
	title.custom_minimum_size.x=0
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var status := Paper.label("已收藏" if collected else "尚未收藏",16,Paper.TEAL if collected else Color("#8c694a"))
	status.name="AlbumPhotoStatus"
	column.add_child(status)
	var method := Paper.label(str(entry.instructions),16,Paper.DEEP_TEAL)
	method.visible=false
	column.add_child(method)
	var show_details := func(): _photo_details.text=str(entry.title)+"｜"+str(entry.instructions)
	tile.mouse_entered.connect(show_details)
	tile.focus_entered.connect(show_details)
	tile.pressed.connect(func(): _open_collected_photo(entry,tile))
	_set_children_mouse_ignored(tile)
	return tile

func _set_children_mouse_ignored(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter=Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_ignored(child)

func _open_collected_photo(entry: Dictionary, tile: Button) -> void:
	if not _progress.photos.has(entry.id):
		_photo_details.text="這張照片還在等你，完成遊園後再回來翻看。"
		return
	var photo_id := str(entry.id)
	var has_original := _has_original_photo_path(photo_id)
	var texture := _saved_original_texture(photo_id)
	if texture == null:
		texture = _saved_texture(photo_id)
		if texture != null and not has_original:
			_photo_details.text = str(entry.title) + "｜完整尺寸照片沒有留下來，先看看相簿畫格。"
		elif texture != null:
			_photo_details.text = str(entry.title) + "｜原尺寸照片暫時無法打開，先看看相簿畫格。"
	if texture == null:
		_photo_details.text="這張照片暫時看不清楚，先留在本子裡。"
		return
	var modal_overlay := _find_modal_overlay()
	if modal_overlay == null:
		_photo_details.text="這張照片現在不方便翻開，先留在本子裡。"
		return
	var viewer := PhotoViewer.new()
	viewer.setup(texture,str(entry.title),tile)
	modal_overlay.add_child(viewer)

func _has_original_photo_path(photo_id: String) -> bool:
	var photo: Variant = _progress.photos.get(photo_id, {})
	if not photo is Dictionary:
		return false
	var originals: Variant = photo.get("original_frames", [])
	return originals is Array and not originals.is_empty()

func _saved_original_texture(photo_id: String) -> Texture2D:
	var photo: Variant = _progress.photos.get(photo_id, {})
	if not photo is Dictionary:
		return null
	var original_frames: Variant = photo.get("original_frames", [])
	if not original_frames is Array or original_frames.is_empty():
		return null
	var path_value: Variant = original_frames[0]
	if typeof(path_value) != TYPE_STRING or str(path_value).strip_edges().is_empty():
		return null
	if not _progress.has_method("_read_game_photo_original_image"):
		return null
	_original_decode_count += 1
	var image: Image = _progress.call("_read_game_photo_original_image", photo_id, str(path_value))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _find_modal_overlay() -> Control:
	var ancestor: Node = self
	while ancestor != null:
		if ancestor is PanelContainer and ancestor.name == "AdaptiveMenuPanel":
			var center := ancestor.get_parent()
			if center is CenterContainer and center.get_parent() is Control:
				return center.get_parent() as Control
		ancestor=ancestor.get_parent()
	return null

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
	var is_game_photo := photo_id.begins_with("photo-welcome-game-") or photo_id.begins_with("photo-welcome-devil-")
	for frame_index in range(mini(frames.size(),MAX_PHOTO_FRAME_CANDIDATES)):
		var path_value: Variant=frames[frame_index]
		if typeof(path_value)!=TYPE_STRING or str(path_value).strip_edges().is_empty():
			continue
		var path := str(path_value)
		if is_game_photo:
			if _game_photo_texture_cache.has(path):
				var cached: Variant=_game_photo_texture_cache[path]
				if cached is Texture2D:
					return cached
				continue
			_thumbnail_decode_count+=1
			var image_cache: Dictionary={}
			var image: Image=_progress.call("_read_game_photo_image",photo_id,path,image_cache) if _progress.has_method("_read_game_photo_image") else null
			if image==null:
				var legacy_texture := _legacy_ui_photo_texture(path)
				_game_photo_texture_cache[path]=legacy_texture
				if legacy_texture!=null:
					return legacy_texture
				continue
			var game_texture := ImageTexture.create_from_image(image)
			_game_photo_texture_cache[path]=game_texture
			return game_texture
		if FileAccess.file_exists(path) and _photo_loader.is_valid():
			var texture: Variant=_photo_loader.call(path)
			if texture is Texture2D:
				return texture
	return null

func _legacy_ui_photo_texture(path: String) -> Texture2D:
	# Album records also include older exploration images and postcards that are
	# not minigame captures. Bound the generic UI loader before it decodes them;
	# Progress keeps its stricter 320x180 validation for game-result records.
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		return null
	var length := file.get_length()
	if length<45 or length>MAX_LEGACY_UI_PHOTO_BYTES:
		file.close()
		return null
	var header := file.get_buffer(24)
	file.close()
	var signature := PackedByteArray([137,80,78,71,13,10,26,10])
	if header.size()!=24 or header.slice(0,8)!=signature or header.slice(12,16).get_string_from_ascii()!="IHDR":
		return null
	var width := _album_png_u32(header,16)
	var height := _album_png_u32(header,20)
	if width<=0 or height<=0 or width>4096 or height>4096 or width*height>4*1024*1024:
		return null
	if not _photo_loader.is_valid():
		return null
	var texture: Variant=_photo_loader.call(path)
	return texture as Texture2D if texture is Texture2D else null

func _album_png_u32(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset])<<24) | (int(bytes[offset+1])<<16) | (int(bytes[offset+2])<<8) | int(bytes[offset+3])
