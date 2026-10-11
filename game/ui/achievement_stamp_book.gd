extends VBoxContainer
## Read-only stamp catalogue backed by the stable Progress achievement and photo IDs.

const Paper = preload("res://game/ui/paper_ui.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")

class StampMark extends Control:
	var number := "01"
	var unlocked := false
	func _draw() -> void:
		var center := size*0.5
		var radius := minf(size.x,size.y)*0.42
		var tint := Color("#337b7b") if unlocked else Color("#918a79")
		draw_circle(center, radius, Color("#e4c98e") if unlocked else Color("#ddd7ca"))
		draw_arc(center,radius,0.0,TAU,40,tint,2.5)
		draw_arc(center,radius-5,0.0,TAU,36,tint,1.0)
		draw_string(ThemeDB.fallback_font,center+Vector2(-13,6),number,HORIZONTAL_ALIGNMENT_CENTER,-1,15,tint)
		if unlocked:
			draw_line(center+Vector2(10,-15),center+Vector2(14,-10),Color("#d97966"),2.0)
			draw_line(center+Vector2(14,-10),center+Vector2(22,-19),Color("#d97966"),2.0)

var _progress: Node
var _games: Array = []

func setup(progress: Node, games: Array) -> void:
	_progress=progress
	_games=games.duplicate(true)

func _ready() -> void:
	add_theme_constant_override("separation",9)
	var intro := Paper.label("每段遊園回憶都能留下一枚印章。看看灰色印章的條件，挑選下一個想完成的挑戰。",17,Paper.DEEP_TEAL)
	add_child(intro)
	var game_card := Paper.card(self,Color("#fffaf0"),8)
	game_card.name="MinigameStampSection"
	game_card.add_child(Paper.section_title("迎賓設施｜初次完成 · 12 枚"))
	var columns := GridContainer.new()
	columns.name="MinigameStampGrid"
	columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.resized.connect(_fit_stamp_columns.bind(columns))
	_fit_stamp_columns.call_deferred(columns)
	var viewport_width := get_viewport().get_visible_rect().size.x
	columns.columns=clampi(floori(viewport_width/245.0),2,4)
	columns.add_theme_constant_override("h_separation",8)
	columns.add_theme_constant_override("v_separation",8)
	game_card.add_child(columns)
	for index in range(mini(12,_games.size())):
		var game: Dictionary=_games[index]
		var id := "ACH_GAME_%03d" % (index+1)
		var unlocked: bool=_progress.achievements.has(id)
		var tile := PanelContainer.new()
		tile.name="AchievementStamp_"+id
		tile.custom_minimum_size=Vector2(200.0/Paper.physical_scale(self),106)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel",Paper.plaque(Color("#fff9e9") if unlocked else Color("#ece6d8")))
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
		copy.add_child(Paper.label("已蓋章" if unlocked else "待完成",15,Paper.TEAL if unlocked else Color("#8c694a")))
		var condition := Paper.label("條件：完成正式回合",16,Paper.DEEP_TEAL)
		condition.name="StampCondition"
		copy.add_child(condition)
		row.add_child(copy)
		columns.add_child(tile)

	var milestone_card := Paper.card(self,Color("#f1e8d3"),8)
	milestone_card.name="ParkMilestoneStampSection"
	milestone_card.add_child(Paper.section_title("島嶼里程碑｜收藏與探索"))
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
		tile.add_theme_stylebox_override("panel",Paper.plaque(Color("#fff9e9") if unlocked else Color("#ece6d8")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		tile.add_child(row)
		row.add_child(_stamp(str(item.number),unlocked))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		copy.add_child(Paper.label(str(item.title),19))
		copy.add_child(Paper.label(str(item.condition),16,Paper.DEEP_TEAL))
		copy.add_child(Paper.label("已蓋章" if unlocked else "%d / %d" % [int(item.current),int(item.target)],15,Paper.TEAL if unlocked else Color("#8c694a")))
		row.add_child(copy)
		milestone_card.add_child(tile)
	add_child(Paper.label("成就保存在遊戲內；Steam 同步接點尚未連線。",16,Paper.DEEP_TEAL))

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
	var physical_width := grid.size.x*Paper.physical_scale(grid)
	grid.columns=clampi(floori(physical_width/225.0),2,4)
