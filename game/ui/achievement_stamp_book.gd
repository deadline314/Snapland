extends VBoxContainer
## Read-only stamp catalogue backed by the stable Progress achievement and photo IDs.

const Paper = preload("res://game/ui/paper_ui.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")

class StampMark extends Control:
	var number := "01"
	var unlocked := false
	func _draw() -> void:
		var inset := 4.0
		var bounds := Rect2(Vector2(inset,inset),size-Vector2(inset*2.0,inset*2.0))
		var tint := Paper.GOLD if unlocked else Paper.TEAL.darkened(0.52)
		draw_rect(Rect2(bounds.position+Vector2(0,3),bounds.size),Paper.DEEP)
		draw_rect(bounds,Paper.FRAME)
		draw_rect(bounds.grow(-3),tint,false,2.0)
		# Tiny square notches give the seal a printed pixel edge at every scale.
		for x in range(8, maxi(8, int(size.x)-8), 7):
			draw_rect(Rect2(Vector2(x,1),Vector2(2,2)),tint)
			draw_rect(Rect2(Vector2(x,size.y-3),Vector2(2,2)),tint)
		var center := size*0.5
		draw_string(ThemeDB.fallback_font,center+Vector2(-13,6),number,HORIZONTAL_ALIGNMENT_CENTER,-1,15,Paper.INK)
		if unlocked:
			draw_rect(Rect2(center+Vector2(10,-15),Vector2(4,4)),Paper.GOLD)
			draw_rect(Rect2(center+Vector2(14,-11),Vector2(4,4)),Paper.GOLD)
			draw_rect(Rect2(center+Vector2(18,-19),Vector2(4,8)),Paper.GOLD)

var _progress: Node
var _games: Array = []
var _game_section: VBoxContainer
var _milestone_section: HFlowContainer
var _milestone_heading: Label
var _game_tab: Button
var _milestone_tab: Button
var _page := 0
var _page_controls: HBoxContainer
var _page_label: Label
var _content_scroll: ScrollContainer
var _game_body: BoxContainer
var _game_summary: BoxContainer
var _summary_title: Label
var _summary_copy: Label
var _game_grid: GridContainer

func setup(progress: Node, games: Array) -> void:
	_progress=progress
	_games=games.duplicate(true)

func _ready() -> void:
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var tabs := HBoxContainer.new()
	tabs.name="AchievementCategoryTabs"
	add_child(tabs)
	_game_tab=Paper.button("遊園印章",func(): _set_section("games"),tabs)
	_game_tab.name="AchievementTab_games"
	_milestone_tab=Paper.button("島嶼里程碑",func(): _set_section("milestones"),tabs)
	_milestone_tab.name="AchievementTab_milestones"
	for tab in [_game_tab,_milestone_tab]:
		tab.custom_minimum_size=Vector2(0,44)
		tab.toggle_mode=true
	var scroll := ScrollContainer.new()
	_content_scroll=scroll
	scroll.name="AdaptiveMenuScroll"
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.gui_input.connect(_on_scroll_gui_input)
	add_child(scroll)
	var content := VBoxContainer.new()
	content.name="AchievementContent"
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	var game_card := PanelContainer.new()
	_game_section=VBoxContainer.new()
	_game_section.name="MinigameStampSection"
	_game_section.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_game_section.add_child(game_card)
	var surface := Paper.plaque()
	# The compact spread already has framed cards. A thin outer margin leaves
	# enough vertical room for their real two-line captions at 125% text.
	surface.content_margin_left=8
	surface.content_margin_right=8
	surface.content_margin_top=4
	surface.content_margin_bottom=4
	game_card.add_theme_stylebox_override("panel",surface)
	game_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_game_body=BoxContainer.new()
	_game_body.vertical=true
	_game_body.add_theme_constant_override("separation",8)
	game_card.add_child(_game_body)
	_game_summary=BoxContainer.new()
	_game_summary.vertical=true
	_game_summary.add_theme_constant_override("separation",6)
	_summary_title=Paper.section_title("迎賓設施｜初次完成 · 12 枚")
	_summary_copy=Paper.label("每段遊園回憶都能留下一枚印章。灰色印章會列出下一個可完成的挑戰。",16,Paper.INK)
	_game_summary.add_child(_summary_title)
	_game_summary.add_child(_summary_copy)
	_game_body.add_child(_game_summary)
	var columns := GridContainer.new()
	_game_grid=columns
	columns.name="MinigameStampGrid"
	columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.resized.connect(_fit_stamp_columns.bind(columns))
	_fit_stamp_columns.call_deferred(columns)
	var viewport_width := get_viewport().get_visible_rect().size.x
	columns.columns=clampi(floori(viewport_width/245.0),2,4)
	columns.add_theme_constant_override("h_separation",8)
	columns.add_theme_constant_override("v_separation",8)
	_game_body.add_child(columns)
	for index in range(mini(12,_games.size())):
		var game: Dictionary=_games[index]
		var id := "ACH_GAME_%03d" % (index+1)
		var unlocked: bool=_progress.achievements.has(id)
		var tile := PanelContainer.new()
		tile.name="AchievementStamp_"+id
		tile.custom_minimum_size=Vector2(200.0/Paper.physical_scale(self),106)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel",Paper.plaque(Paper.FRAME if unlocked else Paper.DEEP))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",7)
		tile.add_child(row)
		row.add_child(_stamp("%02d" % (index+1),unlocked))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var title := Paper.label(str(game.get("name","設施 %02d" % (index+1))),17)
		title.name="StampCaption"
		title.custom_minimum_size.x=140.0/Paper.physical_scale(self)
		copy.add_child(title)
		copy.add_child(Paper.label("已蓋章" if unlocked else "待完成",15,Paper.TEAL if unlocked else Paper.INK))
		var condition := Paper.label("條件：完成正式回合",16,Paper.INK)
		condition.name="StampCondition"
		copy.add_child(condition)
		row.add_child(copy)
		columns.add_child(tile)

	var milestone_card := PanelContainer.new()
	milestone_card.name="ParkMilestoneStampFrame"
	milestone_card.add_theme_stylebox_override("panel",surface.duplicate())
	milestone_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_milestone_section=HFlowContainer.new()
	_milestone_section.add_theme_constant_override("h_separation",8)
	_milestone_section.add_theme_constant_override("v_separation",8)
	_milestone_section.resized.connect(_fit_milestone_spread)
	_milestone_section.name="ParkMilestoneStampSection"
	_milestone_section.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_milestone_heading=Paper.label("島嶼里程碑｜收藏與探索",20,Paper.GOLD)
	_milestone_section.add_child(_milestone_heading)
	milestone_card.add_child(_milestone_section)
	var normal_games := _photo_count("photo-welcome-game-%d",12)
	var welcome_devils := int(_progress.devil_count("welcome"))
	var total_devils := 0
	for zone in _progress.ZONES:
		total_devils+=int(_progress.devil_count(str(zone)))
	var time_count := 0
	for photo_id in TimeOfDay.all_postcard_ids():
		if _progress.photos.has(photo_id):
			time_count+=1
	var milestones := [
		{"id":"ACH_WELCOME_CLEAR","number":"N","title":"迎賓全通關","condition":"集齊迎賓大道 12 張普通遊戲拍貼","current":normal_games,"target":12},
		{"id":"ACH_WELCOME_DEVILS","number":"D","title":"尾巴藏不住","condition":"集齊迎賓大道 12 張小惡魔拍貼","current":welcome_devils,"target":12},
		{"id":"ACH_ALL_DEVILS","number":"120","title":"每個小惡魔都入鏡","condition":"集齊十區共 120 張小惡魔拍貼","current":total_devils,"target":120},
		{"id":TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS,"number":"4","title":"四時留影","condition":"收藏凌晨、中午、傍晚與晚上明信片","current":time_count,"target":4},
	]
	for item in milestones:
		var unlocked: bool=_progress.achievements.has(item.id)
		var tile := PanelContainer.new()
		tile.name="AchievementStamp_"+str(item.id)
		tile.add_theme_stylebox_override("panel",Paper.plaque(Paper.FRAME if unlocked else Paper.DEEP))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		tile.add_child(row)
		row.add_child(_stamp(str(item.number),unlocked))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		copy.add_child(Paper.label(str(item.title),19))
		copy.add_child(Paper.label(str(item.condition),16,Paper.INK))
		copy.add_child(Paper.label("已蓋章" if unlocked else "%d / %d" % [int(item.current),int(item.target)],15,Paper.TEAL if unlocked else Paper.INK))
		row.add_child(copy)
		_milestone_section.add_child(tile)
	milestone_card.tooltip_text="成就保存在遊戲內；Steam 同步接點尚未連線。"
	content.add_child(_game_section)
	content.add_child(milestone_card)
	_page_controls=HBoxContainer.new()
	_page_controls.name="AchievementPageControls"
	_page_controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_page_controls.alignment=BoxContainer.ALIGNMENT_CENTER
	add_child(_page_controls)
	var previous := Paper.button("← 上一頁",func(): _change_page(-1),_page_controls)
	previous.name="AchievementPreviousPage"
	var next := Paper.button("下一頁 →",func(): _change_page(1),_page_controls)
	next.name="AchievementNextPage"
	_page_label=Paper.label("",16,Paper.INK)
	_page_label.name="AchievementPageLabel"
	_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_page_controls.add_child(_page_label)
	_page_controls.move_child(_page_label,1)
	_set_section("games")

func _stamp(number: String, unlocked: bool) -> Control:
	var stamp := StampMark.new()
	stamp.name="StampMark_"+number
	stamp.number=number
	stamp.unlocked=unlocked
	stamp.custom_minimum_size=Vector2(64,64)
	stamp.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	stamp.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return stamp

func _photo_count(pattern: String, count: int) -> int:
	var result := 0
	for index in range(1,count+1):
		if _progress.photos.has(pattern % index):
			result+=1
	return result

func _fit_stamp_columns(grid: GridContainer) -> void:
	if not is_instance_valid(grid): return
	var scale_factor := Paper.physical_scale(grid)
	var compact := grid.get_viewport_rect().size.x*scale_factor<1200.0
	grid.columns=2 if compact else 4
	_game_body.vertical=true
	_game_summary.vertical=not compact
	_game_summary.custom_minimum_size.x=0.0
	_summary_title.text="迎賓印章 · 12 枚" if compact else "迎賓設施｜初次完成 · 12 枚"
	_summary_copy.text="灰色：完成正式回合後蓋章" if compact else "每段遊園回憶都能留下一枚印章。灰色印章會列出下一個可完成的挑戰。"
	_summary_copy.tooltip_text="每段遊園回憶都能留下一枚印章。灰色印章會列出下一個可完成的挑戰。"
	_summary_title.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
	_summary_title.autowrap_mode=TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
	_summary_copy.autowrap_mode=TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
	grid.size_flags_horizontal=Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size.x=568.0/scale_factor if compact else 0.0
	# Hidden records stay in the catalogue, so update their geometry as well as
	# the current spread when the window changes. Containers do not lay out
	# invisible children and would otherwise leave their old wide-window sizes.
	var width := (568.0/scale_factor-grid.get_theme_constant("h_separation"))/2.0 if compact else 200.0/scale_factor
	for tile in grid.get_children():
		tile.custom_minimum_size.x=width
		if not tile.visible:
			tile.size.x=width
			for label in tile.find_children("*","Label",true,false):
				(label as Label).size.x=maxf(140.0/scale_factor,width-100.0)

func _fit_milestone_spread() -> void:
	if not is_instance_valid(_milestone_section): return
	var scale_factor := Paper.physical_scale(self)
	var compact := get_viewport_rect().size.x*scale_factor<1200.0
	var spread_width := 568.0/scale_factor if compact else maxf(600.0,_content_scroll.size.x-16.0)
	_milestone_section.size_flags_horizontal=Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	_milestone_section.custom_minimum_size.x=spread_width
	# The category tab already names this section in a compact book; reserve
	# its viewport for the two complete eligibility cards instead of a second heading.
	_milestone_heading.visible=not compact
	_milestone_heading.custom_minimum_size.x=spread_width
	var card_width := (spread_width-_milestone_section.get_theme_constant("h_separation"))/2.0
	for tile in _milestone_section.get_children():
		if tile==_milestone_heading: continue
		(tile as Control).custom_minimum_size.x=card_width
		if not tile.visible:
			(tile as Control).size.x=card_width
			for label in tile.find_children("*","Label",true,false):
				(label as Label).size.x=maxf(140.0/scale_factor,card_width-100.0)

func _on_viewport_size_changed() -> void:
	Paper.adapt_menu(self,Paper.physical_scale(self))
	for grid in find_children("MinigameStampGrid", "GridContainer", true, false):
		_fit_stamp_columns(grid)
	_update_pages()

func _set_section(section: String) -> void:
	if not is_instance_valid(_game_section) or not is_instance_valid(_milestone_section):
		return
	var show_games := section != "milestones"
	_game_section.visible=show_games
	_milestone_section.get_parent().visible=not show_games
	_game_tab.button_pressed=show_games
	_milestone_tab.button_pressed=not show_games
	_page=0
	_update_pages()

func _change_page(delta: int) -> void:
	var pages := _page_count()
	_page=clampi(_page+delta,0,pages-1)
	_update_pages()

func _page_count() -> int:
	var scale_factor := Paper.physical_scale(self)
	var physical_width := get_viewport().get_visible_rect().size.x * scale_factor
	var capacity := 12 if physical_width >= 1200.0 else 2
	var count := 12 if _game_section != null and _game_section.visible else 4
	return maxi(1,ceili(float(count)/float(capacity)))

func _update_pages() -> void:
	if _page_controls == null or not is_instance_valid(_page_controls): return
	var scale_factor := Paper.physical_scale(self)
	var physical_width := get_viewport().get_visible_rect().size.x * scale_factor
	var compact := physical_width < 1200.0
	var show_games := _game_section.visible
	var capacity := 12 if not compact else 2
	var total := 12 if show_games else 4
	var pages := maxi(1,ceili(float(total)/float(capacity)))
	_page=clampi(_page,0,pages-1)
	_page_controls.visible=compact
	# This is the panel's sole flexible content region. Keeping it expand-fill is
	# important in the compact Main host: shrink-begin can collapse it to zero
	# after the host removes scroll minimums, clipping the real stamp captions.
	# The page controls stay outside this viewport and retain their own fixed row.
	_content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_content_scroll.custom_minimum_size.y=0.0
	_page_label.text="第 %d / %d 頁" % [_page+1,pages]
	_page_controls.get_node("AchievementPreviousPage").set("disabled",_page<=0)
	_page_controls.get_node("AchievementNextPage").set("disabled",_page>=pages-1)
	var entries := _game_section.find_children("AchievementStamp_ACH_GAME_*","PanelContainer",true,false) if show_games else _milestone_section.find_children("AchievementStamp_*","PanelContainer",true,false)
	# Keep every record as a real node for stable IDs, but put only the current
	# two-card spread in the compact grid. Programmatic scroll positioning alone
	# leaves later rows simultaneously exposed in a tall logical host.
	for index in range(entries.size()):
		(entries[index] as Control).visible=not compact or (index>=_page*capacity and index<(_page+1)*capacity)
	# A page is a complete spread at the viewport origin. Scrolling to a card
	# can move its summary above the clip when card minima change after sorting.
	_content_scroll.scroll_vertical=0
	_content_scroll.scroll_horizontal=0
	_fit_stamp_columns(_game_grid)
	_fit_milestone_spread()
	if _game_section.find_child("MinigameStampGrid",true,false) is GridContainer:
		(_game_section.find_child("MinigameStampGrid",true,false) as GridContainer).columns=4 if not compact else 2

func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_content_scroll.accept_event()
	elif event is InputEventPanGesture:
		_content_scroll.accept_event()
