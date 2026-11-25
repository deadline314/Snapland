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
	var data: Dictionary

	func _draw() -> void:
		if data.is_empty(): return
		var bounds: Rect2=data.bounds
		var region: String = data.get("region","harbor")
		if region=="nightmarket":
			_draw_market(bounds)
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
	var prefix: String = {"candy":"CandyMap","nightmarket":"NightmarketMap"}.get(region,"HarborMap")
	name=prefix+"Panel"
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var status := _status_text(region)
	var tide := Paper.label(status,18,Paper.DEEP_TEAL)
	tide.name=prefix+str({"candy":"Temperature","nightmarket":"Status"}.get(region,"Tide"))
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
	return "漲潮 · 沙洲暫停通行" if snapshot.high_tide else "退潮 · 沙洲可以步行"

func _legend_text(region: String) -> String:
	match region:
		"candy": return "金點：你的位置　珊瑚編號：入口、觀察台與工作台\n主輸送廊連接各工作台；溫度觀察不影響進度。返回迎賓大道永久免費。"
		"nightmarket": return "金點是你。綠色為雨棚巷，淡紫為屋頂。\n攤街可繞行，北邊斜坡通往屋頂。返回迎賓大道免費。"
	return "金點：你的位置　珊瑚編號：互動地點\n環岸步道全年可通；兩端免費渡船在漲退潮都可使用。返回迎賓大道永久免費。"
