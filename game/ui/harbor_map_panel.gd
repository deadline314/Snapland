extends VBoxContainer
const Paper = preload("res://game/ui/paper_ui.gd")
var snapshot: Dictionary = {}

class HarborChart extends Control:
	var data: Dictionary
	func _draw() -> void:
		if data.is_empty(): return
		var bounds: Rect2=data.bounds
		var scale_factor := minf(size.x/bounds.size.x,size.y/bounds.size.y)
		var origin := (size-bounds.size*scale_factor)*0.5
		draw_rect(Rect2(origin,bounds.size*scale_factor),Color("#246477"))
		for rect: Rect2 in data.land:
			draw_rect(Rect2(origin+(rect.position-bounds.position)*scale_factor,rect.size*scale_factor),Color("#d4c4a0"))
		var bar: Rect2=data.sandbar
		draw_rect(Rect2(origin+(bar.position-bounds.position)*scale_factor,bar.size*scale_factor),Color("#3d7c90") if data.high_tide else Color("#eed29a"))
		for index in range(data.points.size()):
			var position: Vector3=data.points[index].position
			var marker := origin+(Vector2(position.x,position.z)-bounds.position)*scale_factor
			draw_circle(marker,5.0,Paper.CORAL)
			draw_string(Paper.font(),marker+Vector2(7,5),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(14.0*Paper.text_scale()/Paper.physical_scale(self)),Paper.INK)
		var player: Vector3=data.player
		draw_circle(origin+(Vector2(player.x,player.z)-bounds.position)*scale_factor,6.0,Paper.GOLD)

func setup(value: Dictionary) -> void:
	snapshot=value.duplicate(true)

func _ready() -> void:
	name="HarborMapPanel"
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var tide := Paper.label("漲潮 · 沙洲暫停通行" if snapshot.high_tide else "退潮 · 沙洲可以步行",18,Paper.DEEP_TEAL)
	tide.name="HarborMapTide"
	add_child(tide)
	var chart := HarborChart.new()
	chart.name="HarborMapTerrain"
	chart.data=snapshot
	chart.custom_minimum_size=Vector2(240,150)
	chart.size_flags_vertical=Control.SIZE_EXPAND_FILL
	chart.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chart.resized.connect(chart.queue_redraw)
	add_child(chart)
	var legend := Paper.label("金點：你的位置　珊瑚編號：互動地點\n環岸步道全年可通；兩端免費渡船在漲退潮都可使用。返回迎賓大道永久免費。",16,Paper.INK)
	legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(legend)
	var locations := HFlowContainer.new()
	locations.name="HarborMapLocations"
	add_child(locations)
	for index in range(snapshot.points.size()):
		var point: Dictionary=snapshot.points[index]
		var label := Paper.label("%d %s" % [index+1,str(point.label)],14,Paper.DEEP_TEAL)
		label.tooltip_text=str(point.label)
		locations.add_child(label)
