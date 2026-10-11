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
		draw_rect(Rect2(Vector2.ZERO,size),Color("#a9d0ca"))
		# Low waterline shadow separates the cut-paper islands from the sea.
		var main := _scaled_points([
			Vector2(12,96),Vector2(40,42),Vector2(119,17),Vector2(206,29),Vector2(284,11),
			Vector2(374,34),Vector2(447,23),Vector2(481,67),Vector2(463,137),Vector2(485,201),
			Vector2(439,276),Vector2(350,331),Vector2(239,343),Vector2(132,326),Vector2(48,287),Vector2(14,221)
		],sx,sy)
		var offset := Vector2(0,12*sy)
		draw_colored_polygon(_translate(main,offset),Color("#547b78"))
		draw_colored_polygon(main,Color("#f0dfb7"))
		draw_polyline(_closed_points(main),Color("#9e805a"),3.0,true)
		# A pale green rise and a coral route make the main island read as a map, not a list.
		var hill := _scaled_points([Vector2(36,87),Vector2(82,48),Vector2(151,42),Vector2(194,64),Vector2(178,93),Vector2(101,107),Vector2(49,119)],sx,sy)
		draw_colored_polygon(hill,Color("#9eb58a"))
		var route := _scaled_points([Vector2(86,282),Vector2(125,243),Vector2(197,229),Vector2(262,248),Vector2(322,220),Vector2(388,231),Vector2(414,184),Vector2(379,141),Vector2(328,105),Vector2(244,112),Vector2(170,120),Vector2(105,144)],sx,sy)
		draw_polyline(route,Color("#fff5d8"),8.0,true)
		draw_polyline(route,Color("#d97966"),2.0,true)
		# Satellite islands share the same lower-right light direction as the main landmass.
		for row in range(3):
			for column in range(3):
				var center := Vector2((535.0+column*83.0)*sx,(68.0+row*112.0)*sy)
				draw_circle(center+Vector2(0,5*sy),25*minf(sx,sy),Color("#688985"))
				draw_circle(center,25*minf(sx,sy),Color("#e5d2a7"))
				draw_arc(center,24*minf(sx,sy),0.0,TAU,28,Color("#a68d64"),2.0)
		# Piers and a north mark anchor the island's orientation.
		draw_colored_polygon(_scaled_points([Vector2(56,279),Vector2(84,282),Vector2(67,322),Vector2(41,315)],sx,sy),Color("#8c694a"))
		draw_line(Vector2(463*sx,34*sy),Vector2(463*sx,61*sy),Color("#24585d"),2.0)
		draw_colored_polygon(_scaled_points([Vector2(463,21),Vector2(456,37),Vector2(470,37)],sx,sy),Color("#d97966"))
		for leader in leaders:
			draw_line(leader[0],leader[1],Color("#8c694a"),1.5,true)
		draw_string(ThemeDB.fallback_font,Vector2(455*sx,17*sy),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#203e47"))

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

func setup(zones: Array, games: Array, normal_count: int, park_points: Array = []) -> void:
	_zones=zones.duplicate(true)
	_games=games.duplicate(true)
	_normal_count=normal_count
	_station_positions.clear()
	for point_value in park_points:
		if point_value is Dictionary and str(point_value.get("id","")).begins_with("game-") and point_value.get("position") is Vector3:
			_station_positions[str(point_value.id)]=point_value.position

func _ready() -> void:
	add_theme_constant_override("separation",8)
	var frame := PanelContainer.new()
	frame.name="IslandChartFrame"
	frame.add_theme_stylebox_override("panel",Paper.plaque(Color("#dfd2ad")))
	add_child(frame)
	_canvas=MapSurface.new()
	_canvas.name="IslandChartCanvas"
	_canvas.custom_minimum_size=Vector2(0,290)
	_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_canvas.clip_contents=true
	_canvas.resized.connect(_layout_map_buttons)
	frame.add_child(_canvas)
	_add_destination_buttons()
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation",12)
	add_child(legend)
	legend.add_child(Paper.label("珊瑚路線：迎賓大道　·　右側九島：其他園區入口（準備中）",16,Paper.DEEP_TEAL))
	var detail := PanelContainer.new()
	detail.name="DestinationDetails"
	detail.add_theme_stylebox_override("panel",Paper.plaque(Color("#fffaf0")))
	add_child(detail)
	var detail_body := VBoxContainer.new()
	detail_body.add_theme_constant_override("separation",3)
	detail.add_child(detail_body)
	_detail_title=Paper.section_title("海風碼頭｜下船起點")
	_detail_text=Paper.label("由碼頭沿著珊瑚色路線進入迎賓大道。選取地圖標記，查看站點目標與園區門檻。",17)
	detail_body.add_child(_detail_title)
	detail_body.add_child(_detail_text)
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
		var gate := _make_button("%02d" % (zone_index+1),"MapGate_"+zone_id)
		gate.add_theme_font_size_override("font_size",13)
		gate.custom_minimum_size=Vector2(44,44)
		gate.tooltip_text="%s｜%d 張不同普通拍貼即可取得資格；園區仍在準備中。" % [zone_name,int(zone_value.get("threshold",0))]
		var select_gate := _select_zone.bind(zone_value)
		gate.pressed.connect(select_gate)
		gate.mouse_entered.connect(select_gate)
		gate.focus_entered.connect(select_gate)
		zone_index+=1

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
	_detail_title.text="海風碼頭｜下船起點"
	_detail_text.text="沿木棧橋前往中央廣場，再進入迎賓大道。沿珊瑚色路線尋找迎賓設施。"

func _select_game(game_id: String, number: int, game: Dictionary) -> void:
	_detail_title.text="迎賓大道｜第 %02d 站 · %s" % [number,str(game.get("name",game_id))]
	_detail_text.text="目標：%s\n操作：%s\n依地圖路線走到設施旁，開始互動。" % [str(game.get("goal","完成設施挑戰。")),str(game.get("instructions","依遊戲畫面操作。"))]

func _select_zone(zone: Dictionary) -> void:
	var threshold := int(zone.get("threshold",0))
	var remaining := maxi(threshold-_normal_count,0)
	_detail_title.text="%s｜園區入口 · 準備中" % str(zone.get("name","未命名園區"))
	var qualification := "已達入園資格" if remaining==0 else "還差 %d 張不同普通拍貼" % remaining
	_detail_text.text="主題：%s\n門檻：%d 張（目前 %d 張；%s）。收藏不消耗。園區內容仍在準備中，先收藏拍貼、累積入園資格。" % [str(zone.get("theme","主題資料準備中。")),threshold,_normal_count,qualification]
