extends VBoxContainer
## A compact island chart: one playable welcome island, twelve numbered stops, and
## nine clearly unfinished destinations. Selection reveals facts; it never teleports.

const Paper = preload("res://game/ui/paper_ui.gd")

class StationIcon extends Control:
	var station := 0
	func _draw() -> void:
		var center := size * 0.5
		var teal := Color("#337b7b")
		var coral := Color("#d97966")
		var gold := Color("#dfa458")
		var ink := Color("#24585d") if station % 3 != 0 else coral
		match station:
			0: # balloon
				draw_circle(center+Vector2(0,-2),4,coral)
				draw_line(center+Vector2(0,2),center+Vector2(2,8),ink,1.5)
			1: # kite
				draw_colored_polygon(PackedVector2Array([center+Vector2(0,-7),center+Vector2(5,-2),center+Vector2(0,3),center+Vector2(-5,-2)]),gold)
				draw_line(center+Vector2(0,3),center+Vector2(2,8),ink,1.5)
			2: # fountain
				draw_arc(center+Vector2(0,4),6,PI,TAU,12,ink,1.5)
				draw_line(center+Vector2(-3,-1),center+Vector2(-4,-5),teal,1.5)
				draw_line(center,center+Vector2(0,-7),teal,1.5)
				draw_line(center+Vector2(3,-1),center+Vector2(4,-5),teal,1.5)
			3: # crowd
				draw_circle(center+Vector2(-4,-3),2,gold)
				draw_circle(center+Vector2(0,-5),2,coral)
				draw_circle(center+Vector2(4,-3),2,teal)
				draw_line(center+Vector2(-6,3),center+Vector2(6,3),ink,1.5)
			4: # cap
				draw_arc(center+Vector2(0,2),5,PI,TAU,12,ink,1.5)
				draw_line(center+Vector2(-6,2),center+Vector2(6,2),gold,2)
			5: # ribbon
				draw_polyline(PackedVector2Array([center+Vector2(-6,-3),center+Vector2(-2,-3),center+Vector2(-2,3),center+Vector2(2,3),center+Vector2(2,-3),center+Vector2(6,-3)]),coral,1.8)
			6: # flower
				for petal in range(5): draw_circle(center+Vector2.UP.rotated(TAU*petal/5.0)*4,2,coral)
				draw_circle(center,1.6,gold)
			7: # signpost
				draw_line(center+Vector2(0,-6),center+Vector2(0,7),ink,1.5)
				draw_line(center+Vector2(-6,-4),center+Vector2(5,-4),coral,2)
				draw_line(center+Vector2(-5,-4),center+Vector2(-5,0),gold,1)
			8: # shadow
				draw_arc(center,6,0.3,PI*1.75,16,teal,2)
				draw_circle(center+Vector2(2,-1),2,gold)
			9: # bubbles
				draw_arc(center+Vector2(-3,1),3,0,TAU,12,teal,1.5)
				draw_arc(center+Vector2(3,-3),2,0,TAU,12,coral,1.5)
				draw_circle(center+Vector2(4,4),1.5,gold)
			10: # bench
				draw_line(center+Vector2(-6,-2),center+Vector2(6,-2),gold,2)
				draw_line(center+Vector2(-6,1),center+Vector2(6,1),ink,1.5)
				draw_line(center+Vector2(-4,1),center+Vector2(-4,6),ink,1.5)
				draw_line(center+Vector2(4,1),center+Vector2(4,6),ink,1.5)
			_: # harmony
				draw_circle(center+Vector2(-4,-3),2,coral)
				draw_circle(center+Vector2(2,-5),2,teal)
				draw_line(center+Vector2(-2,-3),center+Vector2(-2,5),ink,1.5)
				draw_line(center+Vector2(4,-5),center+Vector2(4,3),ink,1.5)

class MapSurface extends Control:
	var leaders: Array = []
	func _draw() -> void:
		var sx := size.x / 720.0
		var sy := size.y / 360.0
		draw_rect(Rect2(Vector2.ZERO,size),Color("#80b8bd"))
		# Short two-pixel marks suggest shallow-water bands without competing with the route.
		for row in range(12):
			var y := (18.0+row*29.0)*sy
			var offset := 12.0 if row%2==0 else 30.0
			for column in range(14):
				var x := (offset+column*51.0)*sx
				var length := 12.0 if column%3==0 else 7.0
				draw_rect(Rect2(Vector2(x,y),Vector2(length*sx,2.0*sy)),Color("#a4ced0"))
		# Low waterline shadow separates the cut-paper islands from the sea.
		var coast := _pixel_steps([
			Vector2(12,96),Vector2(40,42),Vector2(119,17),Vector2(206,29),Vector2(284,11),
			Vector2(374,34),Vector2(447,23),Vector2(481,67),Vector2(463,137),Vector2(485,201),
			Vector2(439,276),Vector2(350,331),Vector2(239,343),Vector2(132,326),Vector2(48,287),Vector2(14,221)
		],8.0)
		var main := _scaled_points(coast,sx,sy)
		var offset := Vector2(0,12*sy)
		draw_colored_polygon(_translate(main,offset),Color("#547b78"))
		draw_colored_polygon(main,Color("#f0dfb7"))
		draw_polyline(_closed_points(main),Color("#9e805a"),3.0,false)
		# A pale green rise and a coral route make the main island read as a map, not a list.
		var hill := _scaled_points(_pixel_steps([Vector2(36,87),Vector2(82,48),Vector2(151,42),Vector2(194,64),Vector2(178,93),Vector2(101,107),Vector2(49,119)],6.0),sx,sy)
		draw_colored_polygon(hill,Color("#9eb58a"))
		var route := _scaled_points([Vector2(86,282),Vector2(125,243),Vector2(197,229),Vector2(262,248),Vector2(322,220),Vector2(388,231),Vector2(414,184),Vector2(379,141),Vector2(328,105),Vector2(244,112),Vector2(170,120),Vector2(105,144)],sx,sy)
		var path := _scaled_points(_pixel_steps([Vector2(86,282),Vector2(125,243),Vector2(197,229),Vector2(262,248),Vector2(322,220),Vector2(388,231),Vector2(414,184),Vector2(379,141),Vector2(328,105),Vector2(244,112),Vector2(170,120),Vector2(105,144)],4.0),sx,sy)
		draw_polyline(path,Color("#fff5d8"),8.0,false)
		draw_polyline(path,Color("#d97966"),2.0,false)
		_draw_trees(sx,sy)
		# Satellite islands share the same lower-right light direction as the main landmass.
		for row in range(3):
			for column in range(3):
				var center := Vector2((535.0+column*83.0)*sx,(68.0+row*112.0)*sy)
				var island_radius := 25*minf(sx,sy)
				draw_rect(Rect2(center-Vector2(island_radius,island_radius)+Vector2(0,5*sy),Vector2(island_radius*2,island_radius*2)),Color("#688985"))
				draw_rect(Rect2(center-Vector2(island_radius,island_radius),Vector2(island_radius*2,island_radius*2)),Color("#e5d2a7"))
				for pixel in range(4):
					draw_rect(Rect2(center+Vector2(-14+pixel*8,-17)*minf(sx,sy),Vector2(4*minf(sx,sy),4*minf(sx,sy))),Color("#6f966f"))
				draw_rect(Rect2(center+Vector2(-2,-9)*minf(sx,sy),Vector2(4*minf(sx,sy),10*minf(sx,sy))),Color("#9b7148"))
				draw_rect(Rect2(center+Vector2(-island_radius,-island_radius),Vector2(island_radius*2,island_radius*2)),Color("#a68d64"),false,2.0)
		# Optional coastal loop: scenic stops, not additional minigame rewards.
		var coastal := _scaled_points([Vector2(82,274),Vector2(33,232),Vector2(31,143),Vector2(68,65),Vector2(214,47),Vector2(373,58),Vector2(449,112),Vector2(442,229),Vector2(351,295),Vector2(159,308),Vector2(82,274)],sx,sy)
		draw_polyline(coastal,Color("#4c8b81"),2.5,false)
		# Piers and a north mark anchor the island's orientation.
		draw_colored_polygon(_scaled_points(_pixel_steps([Vector2(56,279),Vector2(84,282),Vector2(67,322),Vector2(41,315)],4.0),sx,sy),Color("#8c694a"))
		for plank in range(4):
			var plank_y := (285.0+plank*7.0)*sy
			draw_rect(Rect2(Vector2((51.0-plank*1.5)*sx,plank_y),Vector2((24.0-plank*1.2)*sx,2.0*sy)),Color("#d3ad75"))
		draw_rect(Rect2(Vector2(456*sx,37*sy),Vector2(14*sx,3*sy)),Color("#24585d"))
		draw_rect(Rect2(Vector2(461*sx,25*sy),Vector2(4*sx,16*sy)),Color("#d97966"))
		draw_colored_polygon(_scaled_points([Vector2(463,17),Vector2(457,29),Vector2(463,26),Vector2(469,29)],sx,sy),Color("#dfa458"))
		draw_colored_polygon(_scaled_points([Vector2(463,17),Vector2(457,29),Vector2(463,26)],sx,sy),Color("#d97966"))
		for leader in leaders:
			draw_line(leader[0],leader[1],Color("#8c694a"),1.0,false)
		draw_string(ThemeDB.fallback_font,Vector2(459*sx,13*sy),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#203e47"))

	func _pixel_steps(points: Array, step: float) -> Array[Vector2]:
		var result: Array[Vector2]=[]
		if points.is_empty():
			return result
		for index in range(points.size()):
			var start: Vector2=points[index]
			var finish: Vector2=points[(index+1)%points.size()]
			var count := maxi(1,ceili(maxf(absf(finish.x-start.x),absf(finish.y-start.y))/step))
			var previous := start
			if index==0:
				result.append(start)
			for segment in range(1,count+1):
				var target := start.lerp(finish,float(segment)/float(count))
				result.append(Vector2(target.x,previous.y))
				result.append(target)
				previous=target
		return result

	func _draw_trees(sx: float, sy: float) -> void:
		for tree in [Vector2(72,79),Vector2(169,56),Vector2(359,61),Vector2(449,93),Vector2(443,259),Vector2(111,211),Vector2(263,307),Vector2(177,286),Vector2(302,73)]:
			var center := Vector2(tree.x*sx,tree.y*sy)
			var unit := minf(sx,sy)
			draw_rect(Rect2(center+Vector2(-2,0)*unit,Vector2(4,8)*unit),Color("#8a6949"))
			draw_rect(Rect2(center+Vector2(-7,-8)*unit,Vector2(14,6)*unit),Color("#547e68"))
			draw_rect(Rect2(center+Vector2(-10,-4)*unit,Vector2(20,6)*unit),Color("#739873"))
			draw_rect(Rect2(center+Vector2(-6,2)*unit,Vector2(12,3)*unit),Color("#9ab485"))
			draw_rect(Rect2(center+Vector2(-10,-8)*unit,Vector2(20,12)*unit),Color("#3f6a61"),false,1.0)

	func _scaled_points(points: Array, sx: float, sy: float) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point: Vector2 in points:
			result.append(Vector2(point.x*sx,point.y*sy))
		return result

	func _translate(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(point+offset)
		return result

	func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
		var result := points.duplicate()
		if not result.is_empty():
			result.append(result[0])
		return result

var _zones: Array = []
var _games: Array = []
var _normal_count := 0
var _station_positions: Dictionary = {}
var _canvas: MapSurface
var _detail_title: Label
var _detail_text: Label
var _selected_map_button := "MapHub"

func setup(zones: Array, games: Array, normal_count: int, park_points: Array = []) -> void:
	_zones=zones.duplicate(true)
	_games=games.duplicate(true)
	_normal_count=normal_count
	_station_positions.clear()
	for point_value in park_points:
		if point_value is Dictionary and str(point_value.get("id","")).begins_with("game-") and point_value.get("position") is Vector3:
			_station_positions[str(point_value.id)]=point_value.position

func _ready() -> void:
	if not get_viewport().size_changed.is_connected(_layout_map_buttons):
		get_viewport().size_changed.connect(_layout_map_buttons)
	add_theme_constant_override("separation",10)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	var clip := ScrollContainer.new()
	clip.name="AdaptiveMenuScroll"
	clip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical=Control.SIZE_EXPAND_FILL
	clip.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	clip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(clip)
	var workspace := HBoxContainer.new()
	workspace.name="IslandMapWorkspace"
	workspace.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical=Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation",10)
	clip.add_child(workspace)
	var frame := PanelContainer.new()
	frame.name="IslandChartFrame"
	frame.add_theme_stylebox_override("panel",Paper.plaque())
	frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio=2.4
	frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	workspace.add_child(frame)
	_canvas=MapSurface.new()
	_canvas.name="IslandChartCanvas"
	_canvas.custom_minimum_size=Vector2(600,0)
	_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_canvas.clip_contents=true
	_canvas.resized.connect(_layout_map_buttons)
	frame.add_child(_canvas)
	_add_destination_buttons()
	_set_map_selection(_selected_map_button)
	var detail := PanelContainer.new()
	detail.name="DestinationDetails"
	detail.add_theme_stylebox_override("panel",Paper.plaque(Paper.FRAME))
	detail.custom_minimum_size.x=280
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio=1.0
	detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	workspace.add_child(detail)
	var detail_body := VBoxContainer.new()
	detail_body.add_theme_constant_override("separation",8)
	detail.add_child(detail_body)
	var heading := Paper.label("目的地情報",14,Paper.GOLD)
	detail_body.add_child(heading)
	_detail_title=Paper.section_title("海風碼頭｜下船起點")
	_detail_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_detail_text=Paper.label("由碼頭沿著珊瑚色路線進入迎賓大道。選取地圖標記，查看站點目標與園區門檻。",17,Paper.INK)
	_detail_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_detail_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	detail_body.add_child(_detail_title)
	detail_body.add_child(_detail_text)
	var legend := HBoxContainer.new()
	legend.name="IslandMapLegend"
	legend.add_theme_constant_override("separation",12)
	add_child(legend)
	legend.add_child(Paper.label("珊瑚線：迎賓大道　·　青綠線：海岸環線　·　右側九島準備中",16,Paper.INK))
	if not _zones.is_empty():
		_canvas.queue_redraw()

func _add_destination_buttons() -> void:
	var hub := _make_button("海風碼頭", "MapHub")
	hub.pressed.connect(func(): _select_hub())
	var games := _games
	for index in range(mini(12,games.size())):
		var game: Dictionary=games[index]
		var game_id := str(game.get("id","game-%03d"%(index+1)))
		var label := "%02d" % [index+1]
		var button := _make_button(label,"MapStop_"+game_id)
		button.add_theme_font_size_override("font_size",13)
		button.tooltip_text="迎賓大道第 %d 站｜%s" % [index+1,str(game.get("goal","設施介紹尚未提供。"))]
		var icon := StationIcon.new()
		icon.station=index
		icon.position=Vector2(14,2)
		icon.size=Vector2(16,16)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var select := _select_game.bind(game_id,index+1,game)
		button.pressed.connect(select)
		button.mouse_entered.connect(select)
		button.focus_entered.connect(select)
	var zone_index := 0
	for zone_value in _zones:
		if not zone_value is Dictionary or str(zone_value.get("id",""))=="welcome":
			continue
		var zone_id := str(zone_value.id)
		var zone_name := str(zone_value.get("name",zone_id))
		var short_name := _gate_short_name(zone_id,zone_index+1)
		var gate := _make_button(short_name,"MapGate_"+zone_id)
		gate.add_theme_font_size_override("font_size",10 if short_name.length()>2 else 11)
		gate.custom_minimum_size=Vector2(44,44)
		gate.tooltip_text="%s｜%d 張不同普通拍貼即可取得資格；園區仍在準備中。" % [zone_name,int(zone_value.get("threshold",0))]
		var gate_style := gate.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if gate_style != null:
			gate_style.content_margin_left=2
			gate_style.content_margin_right=2
			gate.add_theme_stylebox_override("normal",gate_style)
		var select_gate := _select_zone.bind(zone_value)
		gate.pressed.connect(select_gate)
		gate.mouse_entered.connect(select_gate)
		gate.focus_entered.connect(select_gate)
		zone_index+=1

func _gate_short_name(zone_id: String, ordinal: int) -> String:
	var names := {"harbor":"潮汐","forest":"森林","desert":"沙丘","mountain":"山脈","snow":"雪原","volcano":"火山","sky":"天空","ruins":"遺跡","moon":"月灣","candy":"糖廠","nightmarket":"夜市","circus":"馬戲","toy":"玩具","garden":"花園","hotel":"旅店","cinema":"影城"}
	return str(names.get(zone_id,"島%02d" % ordinal))

func _make_button(text: String, node_name: String) -> Button:
	var button := Paper.button(text,func(): pass,_canvas)
	button.name=node_name
	button.custom_minimum_size=Vector2(44,48)
	button.add_theme_font_size_override("font_size",13)
	button.focus_mode=Control.FOCUS_ALL
	return button

func _layout_map_buttons() -> void:
	if not is_instance_valid(_canvas):
		return
	var menu_scale := Paper.physical_scale(_canvas)
	var hit_size := Vector2(44.0/menu_scale,48.0/menu_scale)
	var sx := _canvas.size.x/720.0
	var sy := _canvas.size.y/360.0
	var hub := _canvas.get_node_or_null("MapHub") as Button
	if hub != null:
		hub.position=Vector2(14*sx,310*sy)
		hub.size=Vector2(82*sx,40*sy)
	var station_buttons: Array[Button]=[]
	var anchors: Array[Vector2]=[]
	var index := 0
	var route := [Vector2(86,282),Vector2(197,229),Vector2(322,220),Vector2(414,184),Vector2(328,105),Vector2(105,144)]
	for game in _games:
		if index>=12:
			break
		var button := _canvas.get_node_or_null("MapStop_"+str(game.get("id",""))) as Button
		if button != null:
			var world_pos: Vector3 = _station_positions.get(str(game.get("id","")),Vector3(-1 if index%2==0 else 1,0,-17-float(index/2)*4.8))
			var progress := clampf((-world_pos.z-17.0)/24.0,0.0,1.0)
			var route_position := progress*float(route.size()-1)
			var route_index := clampi(floori(route_position),0,route.size()-1)
			var next_index := mini(route_index+1,route.size()-1)
			var route_point: Vector2 = route[route_index].lerp(route[next_index],route_position-float(route_index))
			var previous: Vector2 = route[maxi(route_index-1,0)]
			var following: Vector2 = route[next_index]
			var normal := (following-previous).normalized().orthogonal()
			var side := -1.0 if world_pos.x < 0.0 else 1.0
			var center := route_point+normal*side*18.0
			button.position=Vector2((center.x-22)*sx,(center.y-24)*sy)
			button.custom_minimum_size=hit_size
			button.size=hit_size
			station_buttons.append(button)
			button.add_theme_font_size_override("font_size",ceili(16.0/menu_scale))
			for icon in button.get_children():
				if icon is StationIcon:
					icon.scale=Vector2.ONE/menu_scale
					icon.position=Vector2((button.size.x-16.0/menu_scale)*0.5,2.0/menu_scale)
			anchors.append(Vector2(route_point.x*sx,route_point.y*sy))
		index+=1
	var zone_index := 0
	for zone in _zones:
		if not zone is Dictionary or str(zone.get("id",""))=="welcome":
			continue
		var button := _canvas.get_node_or_null("MapGate_"+str(zone.get("id",""))) as Button
		if button != null:
			var column := zone_index%3
			var row := floori(float(zone_index)/3.0)
			button.position=Vector2((513+column*83)*sx,(44+row*112)*sy)
			button.custom_minimum_size=hit_size
			button.size=hit_size
		zone_index+=1
	for child in _canvas.get_children():
		if child is Button:
			child.position=Vector2(clampf(child.position.x,8.0,maxf(8.0,_canvas.size.x-child.size.x-8)),clampf(child.position.y,8.0,maxf(8.0,_canvas.size.y-child.size.y-8)))
	# Resolve collision in screen pixels, keeping leader lines to the world-derived route anchors.
	for iteration in range(48):
		var moved := false
		for first in range(station_buttons.size()):
			for second in range(first+1,station_buttons.size()):
				var a := station_buttons[first]
				var b := station_buttons[second]
				var delta := b.position+b.size*0.5-a.position-a.size*0.5
				var overlap := (a.size+b.size)*0.5+Vector2(6,6)-delta.abs()
				if overlap.x>0 and overlap.y>0:
					var shift := Vector2.ZERO
					if overlap.x<overlap.y:
						shift.x=(overlap.x*0.5+0.1)*(1.0 if delta.x>=0 else -1.0)
					else:
						shift.y=(overlap.y*0.5+0.1)*(1.0 if delta.y>=0 else -1.0)
					a.position-=shift
					b.position+=shift
					moved=true
		for button in station_buttons:
			if hub!=null and button.get_rect().intersects(hub.get_rect().grow(8.0)):
				button.position.y=hub.position.y-button.size.y-8.0
				moved=true
			button.position=Vector2(clampf(button.position.x,4.0,maxf(4.0,_canvas.size.x*0.67-button.size.x)),clampf(button.position.y,8.0,maxf(8.0,_canvas.size.y-button.size.y-8)))
		if not moved: break
	_canvas.leaders.clear()
	for station_index in range(station_buttons.size()):
		var button := station_buttons[station_index]
		_canvas.leaders.append([anchors[station_index],button.position+button.size*0.5])
	_canvas.queue_redraw()

func _select_hub() -> void:
	_set_map_selection("MapHub")
	_detail_title.text="海風碼頭｜下船起點"
	_detail_text.text="沿木棧橋前往中央廣場，再進入迎賓大道。沿珊瑚色路線尋找迎賓設施。"

func _select_game(game_id: String, number: int, game: Dictionary) -> void:
	_set_map_selection("MapStop_"+game_id)
	_detail_title.text="迎賓大道｜第 %02d 站 · %s" % [number,str(game.get("name",game_id))]
	_detail_text.text="目標：%s\n操作：%s\n依地圖路線走到設施旁，開始互動。" % [str(game.get("goal","完成設施挑戰。")),str(game.get("instructions","依遊戲畫面操作。"))]

func _select_zone(zone: Dictionary) -> void:
	_set_map_selection("MapGate_"+str(zone.get("id","")))
	var threshold := int(zone.get("threshold",0))
	var remaining := maxi(threshold-_normal_count,0)
	_detail_title.text="%s｜園區入口 · 準備中" % str(zone.get("name","未命名園區"))
	var qualification := "已達入園資格" if remaining==0 else "還差 %d 張不同普通拍貼" % remaining
	_detail_text.text="主題：%s\n門檻：%d 張（目前 %d 張；%s）。收藏不消耗。園區內容仍在準備中，先收藏拍貼、累積入園資格。" % [str(zone.get("theme","主題資料準備中。")),threshold,_normal_count,qualification]

func _set_map_selection(node_name: String) -> void:
	_selected_map_button=node_name
	if not is_instance_valid(_canvas):
		return
	for child in _canvas.get_children():
		if not child is Button:
			continue
		var button := child as Button
		var selected := button.name==node_name
		var style := StyleBoxFlat.new()
		style.bg_color=Color("#276c70") if selected else Color("#f0dfb7")
		style.border_color=Color("#f2bd68") if selected else Color("#8e7954")
		style.set_border_width_all(3 if selected else 1)
		style.set_corner_radius_all(0)
		style.content_margin_left=2
		style.content_margin_right=2
		button.add_theme_stylebox_override("normal",style)
		button.add_theme_color_override("font_color",Color("#fff4d7") if selected else Color("#24474c"))
		button.add_theme_color_override("font_hover_color",Color("#fff4d7") if selected else Color("#24474c"))
		button.add_theme_color_override("font_focus_color",Color("#fff4d7") if selected else Color("#24474c"))
	_canvas.queue_redraw()
