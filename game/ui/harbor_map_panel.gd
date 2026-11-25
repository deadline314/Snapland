extends VBoxContainer
const Paper = preload("res://game/ui/paper_ui.gd")
var snapshot: Dictionary = {}

class TerrainChart extends Control:
	const MARKET_FRAME := Color("#2b2944")
	const MARKET_LINE := Color("#948baa")
	const MARKET_PAVING := Color("#746988")
	const MARKET_RIM := Color("#39324e")
	const MARKET_ROOF := Color("#aa8cc7")
	const MARKET_CANOPY := Color("#548f8e")
	const MARKET_MINT := Color("#abe6cd")
	const MARKET_LANTERN := Color("#ffd1a0")
	const MARKET_LETTERS := Color("#f0e5fc")
	const CIRCUS_FLOORS := {
		"entry": Color("#705872"), "mirrors": Color("#546d87"),
		"auditorium": Color("#804f65"), "shadow": Color("#645878"), "mats": Color("#4e7976"),
	}
	const ROOM_PLAN_INK := Color("#ffe2ac")
	const TOY_FLOORS := {
		"entry": Color("#776a54"), "blocks": Color("#87705c"),
		"tower": Color("#675b51"), "station": Color("#54766e"), "repair": Color("#8a6855"),
	}
	var data: Dictionary

	func _draw() -> void:
		if data.is_empty(): return
		var bounds: Rect2=data.bounds
		var region: String = data.get("region","harbor")
		if region=="nightmarket":
			_draw_market(bounds)
			return
		if region in ["circus", "toy"]:
			_draw_room_plan(bounds, region == "toy")
			return
		var scale_factor := minf(size.x/bounds.size.x,size.y/bounds.size.y)
		var origin := (size-bounds.size*scale_factor)*0.5
		var background := Color("#543849") if region=="candy" else Color("#246477")
		var walkable := Color("#d8a4a1") if region=="candy" else Color("#d4c4a0")
		draw_rect(Rect2(origin,bounds.size*scale_factor),background)
		for rect: Rect2 in data.land:
			draw_rect(Rect2(origin+(rect.position-bounds.position)*scale_factor,rect.size*scale_factor),walkable)
		if data.has("sandbar"):
			var bar: Rect2=data.sandbar
			draw_rect(Rect2(origin+(bar.position-bounds.position)*scale_factor,bar.size*scale_factor),Color("#3d7c90") if data.high_tide else Color("#eed29a"))
		for index in range(data.points.size()):
			var position: Vector3=data.points[index].position
			var marker := origin+(Vector2(position.x,position.z)-bounds.position)*scale_factor
			draw_circle(marker,5.0,Paper.CORAL)
			draw_string(Paper.font(),marker+Vector2(7,5),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(14.0*Paper.text_scale()/Paper.physical_scale(self)),Paper.INK)
		var player: Vector3=data.player
		draw_circle(origin+(Vector2(player.x,player.z)-bounds.position)*scale_factor,6.0,Paper.GOLD)

	func _draw_room_plan(bounds: Rect2, toy: bool) -> void:
		var unit := minf((size.x - 42.0) / bounds.size.x, (size.y - 18.0) / bounds.size.y)
		if unit <= 0.0:
			return
		var plan_size := bounds.size * unit
		var plan := Rect2((size - plan_size) * 0.5, plan_size)
		var origin := plan.position - bounds.position * unit
		var panel := plan.grow(7.0)
		var backing := Color("#302b31") if toy else Color("#291f36")
		draw_rect(panel, backing)
		draw_rect(panel, Color("#7e6a5c") if toy else Color("#72556b"), false, 1.0)
		var swatches := TOY_FLOORS if toy else CIRCUS_FLOORS
		for room: Dictionary in data.areas:
			var rect: Rect2 = room.rect
			var floor := Rect2(origin + rect.position * unit, rect.size * unit)
			draw_rect(floor, swatches.get(room.id, MARKET_PAVING))
			draw_rect(floor, Color("#bc9c95"), false, 1.0)
			if toy:
				_draw_toy_detail(floor, room.id)
			else:
				_draw_circus_detail(floor, room.id)
		if toy:
			_draw_toy_rails(origin, unit)
		var radius := clampf(unit * 1.07, 4.4, 8.0)
		var font_size := mini(roundi(radius * 2.0), roundi(14.0 * Paper.text_scale() / Paper.physical_scale(self)))
		for index in data.points.size():
			var point: Dictionary = data.points[index]
			var location: Vector3 = point.position
			var pin := origin + Vector2(location.x, location.z) * unit
			draw_circle(pin, radius, Color("#2e243a"), true, -1.0, true)
			draw_circle(pin, radius * 0.38, ROOM_PLAN_INK, true, -1.0, true)
			draw_string(Paper.font(), pin + Vector2(radius + 2.0, font_size * 0.34), str(index + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ROOM_PLAN_INK)
		var player: Vector3 = data.player
		var traveler := origin + Vector2(player.x, player.z) * unit
		draw_circle(traveler, radius * 0.63, backing, true, -1.0, true)
		draw_arc(traveler, radius * 0.74, 0.0, TAU, 14, Paper.GOLD, 1.8, true)
		_draw_market_north(panel.position - Vector2(13.0, -8.0))

	func _draw_toy_detail(floor: Rect2, room: String) -> void:
		var ink := Color(ROOM_PLAN_INK, 0.50)
		match room:
			"blocks":
				for row in 3:
					var at := floor.position + floor.size * Vector2(0.15, 0.15 + float(row) * 0.22)
					draw_rect(Rect2(at, floor.size * Vector2(0.28, 0.105)), ink, false, 1.0)
			"tower":
				var center := floor.position + floor.size * Vector2(0.50, 0.13)
				var radius := clampf(floor.size.x * 0.13, 3.0, 11.0)
				draw_arc(center, radius, 0.0, TAU, 16, ink, 1.2, true)
				draw_polyline(PackedVector2Array([center - Vector2(0, radius * 0.68), center, center + Vector2(radius * 0.53, 0)]), ink, 1.0, true)
			"repair":
				draw_rect(Rect2(floor.position + floor.size * Vector2(0.18, 0.18), floor.size * Vector2(0.58, 0.22)), ink, false, 1.0)

	func _draw_toy_rails(origin: Vector2, unit: float) -> void:
		var table: Rect2 = data.rail_table
		var plate := Rect2(origin + table.position * unit, table.size * unit)
		draw_rect(plate, Color("#333b3d"))
		draw_rect(plate, Color("#9c846c"), false, 1.0)
		var selected: int = data.train.branch
		var pending: PackedVector2Array = data.tracks[1 - selected]
		for index in range(1, pending.size(), 2):
			draw_line(origin + pending[index - 1] * unit, origin + pending[index] * unit, Color("#c4b7a5"), 1.1, true)
		var route: PackedVector2Array = data.tracks[selected]
		var projected := PackedVector2Array()
		for point in route:
			projected.append(origin + point * unit)
		draw_polyline(projected, ROOM_PLAN_INK, 2.0, true)
		var train: Vector3 = data.train.position
		var at := origin + Vector2(train.x, train.z) * unit
		draw_rect(Rect2(at - Vector2(2.2, 2.2), Vector2(4.4, 4.4)), ROOM_PLAN_INK)

	func _draw_circus_detail(floor: Rect2, room: String) -> void:
		var detail := Color(ROOM_PLAN_INK, 0.35)
		var center := floor.get_center()
		match room:
			"mirrors", "shadow":
				var band := Rect2(floor.position + floor.size * Vector2(0.20, 0.19), floor.size * Vector2(0.60, 0.12))
				draw_rect(band, detail, false, 1.0)
				if room == "mirrors":
					for portion in [0.33, 0.66]:
						var x := band.position.x + band.size.x * float(portion)
						draw_line(Vector2(x, band.position.y), Vector2(x, band.end.y), detail, 1.0)
			"auditorium":
				var y := floor.position.y + floor.size.y * 0.20
				for rank in 4:
					draw_line(Vector2(floor.position.x + 2.0, y), Vector2(center.x - 4.0, y), detail, 1.0)
					draw_line(Vector2(center.x + 4.0, y), Vector2(floor.end.x - 2.0, y), detail, 1.0)
					y += floor.size.y * 0.18
			"mats":
				draw_arc(center, floor.size.y * 0.41, 0.0, TAU, 24, detail, 1.0, true)
				draw_arc(center, floor.size.y * 0.29, 0.0, TAU, 20, detail, 1.0, true)

	func _draw_market(bounds: Rect2) -> void:
		# Keep north up while shortening depth, like a small raised street model.
		var footprint := bounds.size*Vector2(1.48,1.0)
		var unit := minf((size.x-36.0)/footprint.x,(size.y-18.0)/footprint.y)
		if unit<=0.0: return
		var scale := Vector2(1.48,1.0)*unit
		var origin := (size-footprint*unit)*0.5-bounds.position*scale
		var plan := Rect2(origin+bounds.position*scale,bounds.size*scale)
		var frame := plan.grow(7.0)
		draw_rect(frame,MARKET_FRAME)
		draw_rect(frame,Color("#534868"),false,1.0)
		for column in range(1,ceili(frame.size.x/15.0)):
			var x := frame.position.x+column*15.0
			draw_line(Vector2(x,frame.position.y+1.0),Vector2(x,frame.end.y-1.0),Color("#37334f"),1.0)
		for row in range(1,ceili(frame.size.y/15.0)):
			var y := frame.position.y+row*15.0
			draw_line(Vector2(frame.position.x+1.0,y),Vector2(frame.end.x-1.0,y),Color("#37334f"),1.0)
		var rise := clampf(unit*0.55,1.6,4.5)
		for tile: Rect2 in data.land:
			var face := _market_rect(tile,origin,scale)
			draw_rect(Rect2(face.position+Vector2(0,rise),face.size),MARKET_RIM)
		for tile: Rect2 in data.land:
			draw_rect(_market_rect(tile,origin,scale),MARKET_PAVING)
		var roof: Rect2 = data.roof
		for tile: Rect2 in data.land:
			if is_equal_approx(tile.position.y,roof.end.y) and tile.size.x<roof.size.x:
				_draw_market_ramp(_market_rect(tile,origin,scale))
				break
		_draw_market_roof(_market_rect(roof,origin,scale))
		_draw_market_canopy(_market_rect(data.awning,origin,scale))
		var radius := clampf(unit*1.03,4.2,8.0)
		for index in data.points.size():
			var point: Dictionary = data.points[index]
			var at: Vector3 = point.position
			var pin := origin+Vector2(at.x,at.z)*scale
			_draw_market_pin(pin,radius,str(point.id))
			var font_size := mini(roundi(2.0*radius),roundi(14.0*Paper.text_scale()/Paper.physical_scale(self)))
			var number := str(index+1)
			var left := pin.x>plan.end.x-3.0*radius
			var number_width := Paper.font().get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			var dx := -radius-number_width-2.0 if left else radius+2.0
			draw_string(Paper.font(),pin+Vector2(dx,font_size*0.34),number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,MARKET_LETTERS)
		var player: Vector3 = data.player
		var player_pin := origin+Vector2(player.x,player.z)*scale
		draw_circle(player_pin,radius*0.48,MARKET_LANTERN)
		draw_arc(player_pin,radius*0.67,0.0,TAU,12,Paper.INK,1.4)
		_draw_market_north(frame.position-Vector2(13.0,-8.0))

	func _market_rect(rect: Rect2,origin: Vector2,scale: Vector2) -> Rect2:
		return Rect2(origin+rect.position*scale,rect.size*scale)

	func _draw_market_ramp(rect: Rect2) -> void:
		draw_rect(rect,Color("#897896"))
		for step in [0.18,0.39,0.60,0.81]:
			var y := rect.position.y+rect.size.y*float(step)
			draw_line(Vector2(rect.position.x+1.0,y),Vector2(rect.end.x-1.0,y),MARKET_LINE,1.0)

	func _draw_market_roof(rect: Rect2) -> void:
		draw_rect(rect,MARKET_ROOF)
		draw_rect(rect.grow(-0.8),Color("#d2b8eb"),false,1.0)
		var table_size := clampf(rect.size.y*0.17,1.4,5.0)
		for offset in [0.23,0.77]:
			var center := Vector2(rect.position.x+rect.size.x*float(offset),rect.get_center().y)
			draw_circle(center+Vector2(0,1.1),table_size,Color("#664a80"))
			draw_circle(center,table_size,Color("#e4c4e6"))

	func _draw_market_canopy(rect: Rect2) -> void:
		draw_rect(rect,MARKET_CANOPY)
		var trim := clampf(rect.size.x*0.11,1.0,4.0)
		for x in [rect.position.x,rect.end.x-trim]:
			draw_rect(Rect2(Vector2(float(x),rect.position.y),Vector2(trim,rect.size.y)),Color("#75b8af"))
		for strip in [0.0,0.25,0.5,0.75,1.0]:
			var y := rect.position.y+rect.size.y*float(strip)
			draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color("#90c8bc"),1.0)

	func _draw_market_pin(center: Vector2,radius: float,id: String) -> void:
		draw_circle(center+Vector2(0,1.1),radius,MARKET_RIM)
		draw_circle(center,radius,Color("#362e49"))
		var ink := MARKET_MINT if id=="nightmarket:shelter" else MARKET_LANTERN
		var u := radius*0.44
		var width := maxf(1.0,u*0.38)
		match id:
			"region:welcome", "nightmarket:reset":
				var tip := center-Vector2(u,0)
				draw_line(tip,center+Vector2(u,0),ink,width)
				draw_polyline(PackedVector2Array([tip+Vector2(u,-u),tip,tip+Vector2(u,u)]),ink,width)
			"nightmarket:shelter":
				draw_polyline(PackedVector2Array([center+Vector2(-u,u*0.25),center-Vector2(0,u),center+Vector2(u,u*0.25)]),ink,width)
				draw_line(center,center+Vector2(0,u),ink,width)
			"nightmarket:trade":
				draw_rect(Rect2(center-Vector2(u,u*0.76),Vector2(u*2.0,u*1.52)),ink,false,width)
				draw_line(center+Vector2(0,u*0.76),center+Vector2(0,u*1.25),ink,width)
			"nightmarket:rooftop":
				draw_line(center-Vector2(u,u*0.55),center+Vector2(u,-u*0.55),ink,width)
				draw_line(center+Vector2(-u*0.65,-u*0.55),center+Vector2(-u*0.65,u),ink,width)
				draw_line(center+Vector2(u*0.65,-u*0.55),center+Vector2(u*0.65,u),ink,width)
			"nightmarket:signs":
				draw_polyline(PackedVector2Array([center+Vector2(u*0.25,-u),center+Vector2(-u*0.55,0),center+Vector2(u*0.55,0),center+Vector2(-u*0.25,u)]),ink,width)
			"game-045":
				draw_line(center + Vector2(-u, -u * 0.29), center + Vector2(u, -u * 0.29), ink, width, true)
				draw_arc(center + Vector2(0, -u * 0.29), u * 0.83, 0, PI, 14, ink, width, true)
			"game-044":
				draw_arc(center, u * 0.91, PI, TAU, 16, ink, width, true)
				draw_line(center + Vector2(-u * 0.91, 0), center + Vector2(u * 0.91, 0), ink, width, true)
				draw_line(center, center + Vector2(0, u * 0.71), ink, width, true)
			"game-043":
				draw_circle(center, u * 0.84, ink, false, width, true)
				draw_line(center + Vector2(0, -u * 0.72), center + Vector2(0, u * 0.72), ink, width, true)
				draw_circle(center + Vector2(u * 0.34, 0), u * 0.13, ink)
			"game-042":
				draw_line(center + Vector2(-u, u * 0.55), center + Vector2(u, u * 0.55), ink, width, true)
				draw_line(center + Vector2(-u * 0.77, u * 0.08), center + Vector2(u * 0.66, -u * 0.62), ink, width, true)
				for side: float in [-1.0, 1.0]:
					draw_circle(center + Vector2(side * u * 0.58, u * 0.91), u * 0.17, ink)
			"game-041":
				draw_arc(center + Vector2(0, u * 0.35), u * 0.78, PI, TAU, 12, ink, width, true)
				draw_arc(center + Vector2(0, u * 0.35), u * 0.38, PI, TAU, 8, ink, width, true)
				draw_circle(center + Vector2(0, u * 0.39), u * 0.11, ink)
			"game-040":
				draw_circle(center, u * 0.94, ink, false, width, true)
				draw_circle(center, u * 0.26, ink, false, width, true)
			"game-039":
				draw_line(center + Vector2(-u, -u), center + Vector2(u, -u * 0.58), ink, width, true)
				draw_line(center + Vector2(0, -u * 0.81), center, ink, width, true)
				draw_circle(center + Vector2(0, u * 0.37), u * 0.58, ink, false, width, true)
			"game-038":
				for offset in [-0.66, 0.0, 0.66]:
					var start := center + Vector2(u * offset - u * 0.27, u)
					var end := center + Vector2(u * offset + u * 0.27, -u)
					draw_line(start, end, ink, width, true)
					draw_circle(start.lerp(end, 0.57), u * 0.26, ink)
			"game-037":
				draw_polyline(PackedVector2Array([center+Vector2(-u,0),center+Vector2(-u*0.55,u),center+Vector2(u*0.55,u),center+Vector2(u,0)]),ink,width)
				draw_line(center+Vector2(-u,0),center+Vector2(u,0),ink,width)
				draw_line(center+Vector2(0,-u),center+Vector2(0,-u*0.35),ink,width)
			_:
				draw_circle(center,u*0.6,ink)

	func _draw_market_north(anchor: Vector2) -> void:
		draw_string(Paper.font(),anchor+Vector2(-3,0),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,10,MARKET_LETTERS)
		draw_colored_polygon(PackedVector2Array([anchor+Vector2(0,3),anchor+Vector2(-3,10),anchor+Vector2(0,8),anchor+Vector2(3,10)]),MARKET_MINT)

func setup(value: Dictionary) -> void:
	snapshot=value.duplicate(true)

func _ready() -> void:
	var region: String = snapshot.get("region","harbor")
	var prefix: String = {"candy":"CandyMap","nightmarket":"NightmarketMap","circus":"CircusMap","toy":"ToyMap"}.get(region,"HarborMap")
	name=prefix+"Panel"
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var status := _status_text(region)
	var tide := Paper.label(status,18,Paper.DEEP_TEAL)
	tide.name=prefix+str({"candy":"Temperature","nightmarket":"Status","circus":"Status","toy":"Status"}.get(region,"Tide"))
	add_child(tide)
	var chart := TerrainChart.new()
	chart.name=prefix+"Terrain"
	chart.data=snapshot
	# Let the chart yield to an extra row of location names at large text sizes.
	chart.custom_minimum_size=Vector2(240,104)
	chart.size_flags_vertical=Control.SIZE_EXPAND_FILL
	chart.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chart.resized.connect(chart.queue_redraw)
	add_child(chart)
	var legend := Paper.label(_legend_text(region),16,Paper.INK)
	legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(legend)
	var locations := HFlowContainer.new()
	locations.name=prefix+"Locations"
	add_child(locations)
	for index in range(snapshot.points.size()):
		var point: Dictionary=snapshot.points[index]
		var label := Paper.label("%d %s" % [index+1,str(point.label)],14,Paper.DEEP_TEAL)
		label.autowrap_mode=TextServer.AUTOWRAP_OFF
		label.tooltip_text=str(point.label)
		locations.add_child(label)

func _status_text(region: String) -> String:
	match region:
		"candy": return "材料觀察："+str(["冷 · 糖塊挺立","溫 · 糖團柔軟","熱 · 糖漿流動"][int(snapshot.temperature)])
		"nightmarket":
			return "%s · %s" % ["營業中" if snapshot.operating else "已收攤","你在雨棚下" if snapshot.covered else "你在露天區"]
		"circus": return "你在" + String(snapshot.area)
		"toy":
			var train: Dictionary = snapshot.train
			var side := "左線" if train.branch == 0 else "右線"
			var state := "停靠" if train.at_dock else "暫停"
			if train.reduced_motion:
				state = "逐站"
			elif train.running:
				state = "行駛"
			return "你在%s · %s／%s" % [snapshot.area, side, state]
	return "漲潮 · 沙洲暫停通行" if snapshot.high_tide else "退潮 · 沙洲可以步行"

func _legend_text(region: String) -> String:
	match region:
		"candy": return "金點：你的位置　珊瑚編號：入口、觀察台與工作台\n主輸送廊連接各工作台；溫度觀察不影響進度。返回迎賓大道永久免費。"
		"nightmarket": return "金點是你。綠色為雨棚巷，淡紫為屋頂。\n攤街可繞行，北邊斜坡通往屋頂。返回迎賓大道免費。"
		"circus": return "金環是你。中央通道通往北側安全墊。\n兩側步道可繞回入口，返回迎賓大道免費。"
		"toy": return "金環是你；實線為選中岔道，方點是列車。\n積木街連到維修台，返回迎賓大道免費。"
	return "金點：你的位置　珊瑚編號：互動地點\n環岸步道全年可通；兩端免費渡船在漲退潮都可使用。返回迎賓大道永久免費。"
