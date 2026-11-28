extends VBoxContainer
## Selection reveals destinations and requirements without moving the player.

const Paper = preload("res://game/ui/paper_ui.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")
const GameCatalog = preload("res://game/core/game_catalog.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const IslandLayout = preload("res://game/world/island_layout.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const Collage = preload("res://game/ui/collage_kit.gd")
const Props = preload("res://game/ui/pixel_props.gd")

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
	const WATER := Color("#347078")
	const SHORE := Color("#e7d6ae")
	const LAWN := Color("#cfdcab")
	const LANE := Color("#b79a6b")
	const COAST := Color("#438878")
	const AVENUE := Color("#cf7965")
	const PLAZA := Color("#946745")
	const YOU := Color("#63dbed")
	const TARGET := Color("#ffcb65")
	const CHART_PAPER := Color("#f1e4c3")
	const SEA_WASH := Color("#a5d5cc")
	const STATION_PAPER := Color("#2f7470")
	const OVERVIEW_PAPER := Color("#6a5068")
	const STICKER := Color("#fffaf0")
	const INK := Color("#3a2f24")

	var player := Vector3.INF
	var dock := Vector3.INF
	var destination := Vector3.INF
	## The roaming thief's rough whereabouts: {"center", "radius"}, empty when away.
	var thief_area: Dictionary = {}
	var errand_marks: Array = []
	## Where an island event happens (the fireworks lookout): {"center", "radius"}.
	var event_area: Dictionary = {}
	var walk_chart := Rect2()
	var station_index := Rect2()
	var region_overview := Rect2()
	var _origin := Vector2.ZERO
	var _scale := 0.0
	var _unit := 1.0

	func arrange(menu_scale: float, minimum_station_width: float, minimum_overview_width: float) -> void:
		_unit = 1.0 / menu_scale
		var inset := 8.0 * _unit
		var gap := 8.0 * _unit
		var area := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
		var station_width := maxf(minimum_station_width, area.size.x * 0.30)
		var overview_width := maxf(minimum_overview_width, area.size.x * 0.25)
		var chart_width := maxf(0.0, area.size.x - station_width - overview_width - gap * 2.0)
		walk_chart = Rect2(area.position, Vector2(chart_width, area.size.y))
		station_index = Rect2(Vector2(walk_chart.end.x + gap, area.position.y), Vector2(station_width, area.size.y))
		region_overview = Rect2(Vector2(station_index.end.x + gap, area.position.y), Vector2(overview_width, area.size.y))

		var bounds := IslandShape.bounds()
		if dock.is_finite():
			bounds = bounds.expand(Vector2(dock.x, dock.z + 3.5))
		var plot := walk_chart.grow(-10.0 * _unit)
		plot.position.y += 24.0 * _unit
		plot.size.y -= 24.0 * _unit
		_scale = maxf(0.0, minf(plot.size.x / bounds.size.x, plot.size.y / bounds.size.y))
		_origin = plot.get_center() - bounds.get_center() * _scale
		queue_redraw()

	func project(point: Vector3) -> Vector2:
		return _project_xz(Vector2(point.x, point.z))

	func select(point: Vector3) -> void:
		destination = point
		queue_redraw()

	func _project_xz(point: Vector2) -> Vector2:
		return _origin + point * _scale

	func _draw() -> void:
		if _scale <= 0.0:
			return
		# A folded guide map and two index cards, cut from different stock and
		# taped onto the journal page; nothing below them is painted.
		_paper(walk_chart, CHART_PAPER, 3)
		var sea := walk_chart.grow(-7.0 * _unit)
		draw_rect(sea, SEA_WASH)
		Collage.fill(self, _corners(sea), Collage.halftone(1), Color(WATER, 0.35))
		for fold in [0.34, 0.67]:
			var x := roundf(sea.position.x + sea.size.x * fold)
			draw_rect(Rect2(x, sea.position.y, 2.0, sea.size.y), Color(1, 1, 1, 0.16))
			draw_rect(Rect2(x + 2.0, sea.position.y, 2.0, sea.size.y), Color(0, 0, 0, 0.08))
		_paper(station_index, STATION_PAPER, 5)
		_paper(region_overview, OVERVIEW_PAPER, 7)
		_draw_terrain()
		_draw_markers()
		_draw_headings()

	## One taped piece of paper with a hard shadow and a torn edge.
	func _paper(rect: Rect2, tone: Color, salt: int) -> void:
		var points: PackedVector2Array = Collage.torn(rect, salt, 2.0, 9.0)
		draw_set_transform(Vector2(5, 6) * _unit)
		draw_colored_polygon(points, Color(0.02, 0.07, 0.1, 0.5))
		draw_set_transform(Vector2.ZERO)
		Collage.fill(self, points, Props.material_tile("paper", tone), Color.WHITE)
		Collage.outline(self, points, Props.deepen(tone, 0.55), 2.0)
		Collage.tape(self, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 2.0), minf(72.0, rect.size.x * 0.35), deg_to_rad(-4.0 + salt))

	static func _corners(rect: Rect2) -> PackedVector2Array:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

	## A sticker backing: cream die-cut disc with a hard shadow.
	func _sticker(point: Vector2, radius: float) -> void:
		draw_circle(point + Vector2(2, 3) * _unit, radius, Color(0.02, 0.07, 0.1, 0.45), true, -1.0, true)
		draw_circle(point, radius, STICKER, true, -1.0, true)
		draw_arc(point, radius, 0.0, TAU, 24, INK, 1.2 * _unit, true)

	## The island's coastline in chart pixels: the shape the chart fills.
	func terrain_outline() -> PackedVector2Array:
		return _projected(IslandShape.coast())

	func _projected(points: PackedVector2Array) -> PackedVector2Array:
		var projected := PackedVector2Array()
		for point in points:
			projected.append(_project_xz(point))
		return projected

	func _draw_terrain() -> void:
		var coast := terrain_outline()
		draw_set_transform(Vector2(0.0, 3.0 * _unit))
		draw_colored_polygon(coast, Color("#254e52"))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(coast, SHORE)
		for lawn in IslandShape.lawns():
			draw_colored_polygon(_projected(lawn), LAWN)
		coast.append(coast[0])
		# Hand-inked coast with an off-register second pass, like a cheap print.
		draw_set_transform(Vector2(2.0, 1.0) * _unit)
		draw_polyline(coast, Color(WATER, 0.6), _unit, true)
		draw_set_transform(Vector2.ZERO)
		draw_polyline(coast, INK, 1.6 * _unit, true)
		for region: String in DistrictSites.regions():
			var plot := district_plot(region)
			draw_rect(plot, (DistrictSites.SITES[region].ground as Color).lerp(SHORE, 0.25))
			Collage.fill(self, _corners(plot), Collage.halftone(0), Color(INK, 0.12))
			draw_rect(plot, INK, false, 1.4 * _unit)
		for pond: Vector3 in IslandLayout.PONDS:
			draw_circle(_project_xz(Vector2(pond.x, pond.y)), pond.z * _scale, WATER, true, -1.0, true)
		# Lanes first, then the coastal loop, then the promenade on top.
		for path in IslandLayout.paths():
			if path.id in ["spine", IslandLayout.COAST_ROUTE_ID]: continue
			# Footpaths are pencilled dashes; the routes are inked over.
			var lane := _projected(path.line)
			for index in range(1, lane.size()):
				draw_dashed_line(lane[index - 1], lane[index], LANE, 1.6 * _unit, 5.0 * _unit)
		draw_polyline(_projected(IslandLayout.coast_route()), COAST, 2.4 * _unit, true)
		for path in IslandLayout.paths():
			if path.id == "spine":
				draw_polyline(_projected(path.line), INK, 5.5 * _unit, true)
				draw_polyline(_projected(path.line), AVENUE, 3.5 * _unit, true)
		var plaza := _project_xz(Vector2.ZERO)
		draw_circle(plaza, 5.0 * _scale, PLAZA, false, 1.4 * _unit, true)
		draw_circle(plaza, 2.4 * _scale, WATER, true, -1.0, true)
		if dock.is_finite():
			draw_line(_project_xz(Vector2(0, 5)), _project_xz(Vector2(0, 15)), PLAZA, 3.5 * _unit, true)
			var pier_top := _project_xz(Vector2(dock.x - 2.5, dock.z - 9.5))
			draw_rect(Rect2(pier_top, Vector2(5, 13) * _scale), PLAZA)
		var font := Paper.font()
		draw_string(font, plaza + Vector2(8, 4) * _unit, "廣場", HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(12.0 * _unit), INK)
		for region: String in DistrictSites.regions():
			var plot := district_plot(region)
			draw_string(font, plot.position + Vector2(3, 13) * _unit, RegionRoutes.title(region), HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(11.0 * _unit), Color("#2b2620"))

	## A district's own ground in chart pixels.
	func district_plot(region: String) -> Rect2:
		var claim := DistrictSites.world_rect(region, "claim")
		return Rect2(_project_xz(claim.position), claim.size * _scale)

	func _draw_markers() -> void:
		if not event_area.is_empty():
			_draw_event(project(event_area.center), float(event_area.radius) * _scale)
		if not thief_area.is_empty():
			_draw_thief(project(thief_area.center), float(thief_area.radius) * _scale)
		for mark: Vector3 in errand_marks:
			_draw_errand(project(mark))
		if destination.is_finite():
			var point := project(destination)
			var radius := 9.0 * _unit
			_sticker(point, radius + 3.0 * _unit)
			var diamond := PackedVector2Array([point - Vector2(0, radius), point + Vector2(radius, 0), point + Vector2(0, radius), point - Vector2(radius, 0)])
			draw_colored_polygon(diamond, TARGET)
			diamond.append(diamond[0])
			draw_polyline(diamond, Color("#453c30"), 1.8 * _unit, true)
		if player.is_finite():
			var point := project(player)
			_sticker(point, 8.0 * _unit)
			draw_circle(point, 5.5 * _unit, Color("#18475b"), true, -1.0, true)
			draw_circle(point, 3.7 * _unit, YOU, true, -1.0, true)

	## A resident errand's next stop: a soft ring (it is only roughly there) and a coral flag.
	func _draw_errand(point: Vector2) -> void:
		draw_circle(point, 11.0 * _unit, Color(0.91, 0.45, 0.38, 0.22), true, -1.0, true)
		_sticker(point + Vector2(1, -2) * _unit, 7.5 * _unit)
		draw_line(point + Vector2(-2, 6) * _unit, point + Vector2(-2, -8) * _unit, Color("#453c30"), 1.6 * _unit, true)
		draw_colored_polygon(PackedVector2Array([point + Vector2(-2, -8) * _unit, point + Vector2(7, -5) * _unit, point + Vector2(-2, -2) * _unit]), Paper.CORAL)
	## A warm ring and a small eight-point star where an island event happens.
	func _draw_event(point: Vector2, radius: float) -> void:
		radius = maxf(radius, 10.0 * _unit)
		draw_circle(point, radius, Color(1.0, 0.80, 0.40, 0.16), true, -1.0, true)
		draw_arc(point, radius, 0.0, TAU, 32, Color(1.0, 0.80, 0.40, 0.7), 1.4 * _unit, true)
		_sticker(point, 9.0 * _unit)
		var star := PackedVector2Array()
		for index in range(16):
			var reach := (8.0 if index % 2 == 0 else 3.4) * _unit
			var angle := TAU * index / 16.0 - PI * 0.5
			star.append(point + Vector2(cos(angle), sin(angle)) * reach)
		draw_colored_polygon(star, TARGET)
		star.append(star[0])
		draw_polyline(star, Color("#453c30"), 1.2 * _unit, true)

	## A soft ring where the thief is roughly, and a small domino mask in it.
	func _draw_thief(point: Vector2, radius: float) -> void:
		radius = maxf(radius, 10.0 * _unit)
		for ring in range(3):
			draw_circle(point, radius * (1.0 - ring * 0.22), Color(0.62, 0.23, 0.35, 0.13), true, -1.0, true)
		draw_arc(point, radius, 0.0, TAU, 32, Color(0.62, 0.23, 0.35, 0.55), 1.2 * _unit, true)
		var u := _unit
		draw_set_transform(point + Vector2(2, 3) * u, 0.0, Vector2(1.25, 0.75))
		draw_circle(Vector2.ZERO, 9.0 * u, Color(0.02, 0.07, 0.1, 0.45), true, -1.0, true)
		draw_set_transform(point, 0.0, Vector2(1.25, 0.75))
		draw_circle(Vector2.ZERO, 9.0 * u, STICKER, true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		var mask := PackedVector2Array([point + Vector2(-9, -2) * u, point + Vector2(-4, -4.5) * u, point + Vector2(0, -2.5) * u,
			point + Vector2(4, -4.5) * u, point + Vector2(9, -2) * u, point + Vector2(7, 3.5) * u, point + Vector2(2, 3) * u,
			point + Vector2(0, 1) * u, point + Vector2(-2, 3) * u, point + Vector2(-7, 3.5) * u])
		draw_colored_polygon(mask, Color("#2c2a45"))
		mask.append(mask[0])
		draw_polyline(mask, Color("#fff0d5"), 1.2 * u, true)
		draw_circle(point + Vector2(-4, -0.5) * u, 1.6 * u, Color("#fff7e8"), true, -1.0, true)
		draw_circle(point + Vector2(4, -0.5) * u, 1.6 * u, Color("#fff7e8"), true, -1.0, true)

	## Each card's name on a stuck-on label strip; a compass inked on the chart.
	func _draw_headings() -> void:
		var at := Vector2(12.0, 8.0) * _unit
		_label_strip(walk_chart.position + at, "迎賓步行圖", Collage.SWATCHES[1], -2.0)
		_label_strip(station_index.position + at, "迎賓站點", Collage.CREAM, 1.5)
		_label_strip(region_overview.position + at, "園區總覽", Collage.CREAM, -1.5)
		var north := Vector2(walk_chart.end.x - 23.0 * _unit, walk_chart.position.y + 16.0 * _unit)
		draw_arc(north + Vector2(0, 6) * _unit, 9.0 * _unit, 0.0, TAU, 20, INK, 1.2 * _unit, true)
		draw_colored_polygon(PackedVector2Array([north, north + Vector2(-4, 8) * _unit, north + Vector2(4, 8) * _unit]), Paper.CORAL)
		draw_colored_polygon(PackedVector2Array([north + Vector2(0, 12) * _unit, north + Vector2(-4, 8) * _unit, north + Vector2(4, 8) * _unit]), INK)
		draw_string(Paper.font(), north + Vector2(-6, 30) * _unit, "北", HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(13.0 * _unit), INK)

	func _label_strip(at: Vector2, words: String, tone: Color, angle: float) -> void:
		var font := Paper.font()
		var font_size := ceili(16.0 * Paper.text_scale() * _unit)
		var extent := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var strip := Rect2(Vector2.ZERO, Vector2(extent.x + 16.0 * _unit, font.get_height(font_size) + 8.0 * _unit))
		draw_set_transform(at, deg_to_rad(angle))
		draw_rect(Rect2(strip.position + Vector2(3, 3) * _unit, strip.size), Color(0.02, 0.07, 0.1, 0.45))
		draw_rect(strip, tone)
		draw_rect(strip, INK, false, 1.4 * _unit)
		draw_string(font, Vector2(8.0 * _unit, 4.0 * _unit + font.get_ascent(font_size)), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Collage.INK)
		draw_set_transform(Vector2.ZERO)


## Today's recommended booths; their station buttons wear a star.
var daily_picks: Array = []
## The roaming thief's rough whereabouts (see RoamingThief.map_area); empty hides it.
var thief_area: Dictionary = {}
## Island positions of resident errands' next stops.
var errand_marks: Array = []
## The running island event's spot (see IslandEvents.map_area); empty hides it.
var event_area: Dictionary = {}
var _zones: Array = []
var _games: Array = []
var _normal_count := 0
var _positions: Dictionary = {}
var _player_position := Vector3.INF
var _canvas: MapSurface
var _workspace: GridContainer
var _detail_body: BoxContainer
var _detail_title: Label
var _detail_text: Label
var _selected: Button
var _stations: Array[Button] = []
var _gates: Array[Button] = []
var _hub: Button
var _normal_style: StyleBox
var _selected_style: StyleBox
var _station_style: StyleBox
var _selected_station_style: StyleBox

func setup(zones: Array, games: Array, normal_count: int, park_points: Array = [], player_position := Vector3.INF) -> void:
	_zones = zones.duplicate(true)
	_games = games.duplicate(true)
	_normal_count = normal_count
	_player_position = player_position
	_positions.clear()
	for point in park_points:
		if point is Dictionary and point.get("position") is Vector3:
			var position: Vector3 = point.position
			if position.is_finite():
				_positions[str(point.get("id", ""))] = position

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_map_buttons)
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var clip := ScrollContainer.new()
	clip.name = "AdaptiveMenuScroll"
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	clip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(clip)
	_workspace = GridContainer.new()
	_workspace.name = "IslandMapWorkspace"
	_workspace.columns = 2
	_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace.add_theme_constant_override("h_separation", 10)
	_workspace.add_theme_constant_override("v_separation", 10)
	clip.add_child(_workspace)
	var frame := PanelContainer.new()
	frame.name = "IslandChartFrame"
	frame.add_theme_stylebox_override("panel", Paper.plaque())
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 2.4
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace.add_child(frame)
	_canvas = MapSurface.new()
	_canvas.name = "IslandChartCanvas"
	_canvas.custom_minimum_size = Vector2(600, 0)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_canvas.player = _player_position
	_canvas.dock = _position("arrival")
	_canvas.thief_area = thief_area
	_canvas.errand_marks = errand_marks
	_canvas.event_area = event_area
	_canvas.resized.connect(_layout_map_buttons)
	frame.add_child(_canvas)
	_normal_style = _map_button_style(false, false)
	_selected_style = _map_button_style(true, false)
	_station_style = _map_button_style(false, true)
	_selected_station_style = _map_button_style(true, true)
	_add_destination_buttons()

	var detail := PanelContainer.new()
	detail.name = "DestinationDetails"
	detail.add_theme_stylebox_override("panel", Paper.plaque(Paper.FRAME))
	detail.custom_minimum_size.x = 280
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 1.0
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace.add_child(detail)
	_detail_body = BoxContainer.new()
	_detail_body.vertical = true
	_detail_body.add_theme_constant_override("separation", 8)
	detail.add_child(_detail_body)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_child(title_stack)
	title_stack.add_child(Paper.label("目的地情報", 14, Paper.GOLD))
	_detail_title = Paper.section_title("")
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text = Paper.label("", 17, Paper.INK)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_detail_title)
	_detail_body.add_child(_detail_text)

	var legend := Paper.label("藍點：你的位置　金菱：目的地　珊瑚線：迎賓大道　青綠線：海岸環線" + ("　面具：怪盜出沒" if not thief_area.is_empty() else "") + ("　小旗：委託目標" if not errand_marks.is_empty() else "") + ("　星星：島上活動" if not event_area.is_empty() else ""), 15, Paper.INK)
	legend.name = "IslandMapLegend"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_color_override("font_color", Collage.INK)
	# Drawn above the focused back stub's rim, which reaches up past the footer.
	legend.z_index = 2
	add_child(legend)
	Collage.backing(legend, "chip", 2, Collage.CREAM, 4.0)
	_select_hub()
	_layout_map_buttons()

func _add_destination_buttons() -> void:
	_hub = _make_button("海風碼頭", "MapHub")
	_hub.tooltip_text = "查看下船起點"
	_connect_selection(_hub, _select_hub)
	for index in range(mini(12, _games.size())):
		var game: Dictionary = _games[index]
		var game_id := str(game.get("id", "game-%03d" % (index + 1)))
		var button := _make_button("%02d" % (index + 1), "MapStop_" + game_id, true)
		button.tooltip_text = str(game.get("name", "迎賓站點"))
		if daily_picks.has(game_id):
			_mark_pick(button)
		var icon := StationIcon.new()
		icon.name = "StationIcon"
		icon.station = index
		icon.size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		_stations.append(button)
		_connect_selection(button, _select_game.bind(button, game_id, index + 1, game))
	for zone in _zones:
		if not zone is Dictionary or str(zone.get("id", "")) == "welcome":
			continue
		var zone_id := str(zone.id)
		var gate := _make_button(_gate_short_name(zone_id, _gates.size() + 1), "MapGate_" + zone_id)
		var zone_name := str(zone.get("name", zone_id))
		var playable := RegionRoutes.supports(zone_id)
		var threshold := RegionRoutes.threshold(zone_id) if playable else int(zone.get("threshold", 0))
		gate.tooltip_text = "%s｜%d 張普通拍貼 · %s" % [zone_name, threshold, "不消耗" if playable else "準備中"]
		for pick in daily_picks:
			if str(GameCatalog.identity(str(pick)).get("zone", "")) == zone_id:
				_mark_pick(gate)
				break
		_gates.append(gate)
		_connect_selection(gate, _select_zone.bind(gate, zone))

func _mark_pick(button: Button) -> void:
	button.tooltip_text += "｜今日推薦"
	var star := Paper.label("★", 13, Paper.GOLD)
	star.name = "DailyPickStar"
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_child(star)
	# Pinned inside the button's top-right corner so it never widens the map.
	star.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	star.offset_left = -16
	star.offset_top = 1

func _connect_selection(button: Button, select: Callable) -> void:
	button.pressed.connect(select)
	button.mouse_entered.connect(select)
	button.focus_entered.connect(select)

func _gate_short_name(zone_id: String, ordinal: int) -> String:
	var names := {"harbor":"潮汐","forest":"森林","desert":"沙丘","mountain":"山脈","snow":"雪原","volcano":"火山","sky":"天空","ruins":"遺跡","moon":"月灣","candy":"糖廠","nightmarket":"夜市","circus":"馬戲","toy":"玩具","garden":"花園","hotel":"旅店","cinema":"影城","theatre":"劇場"}
	return str(names.get(zone_id, "島%02d" % ordinal))

func _make_button(text: String, node_name: String, station := false) -> Button:
	var button := Paper.button(text, func(): pass, _canvas)
	button.name = node_name
	button.set_meta("map_station", station)
	button.set_meta("menu_base_font", 16)
	button.focus_mode = Control.FOCUS_ALL
	_style_button(button, false)
	return button

func _map_button_style(selected: bool, station: bool) -> StyleBox:
	# Map pins are small enamel tiles: cream until chosen, then teal with a gold rim.
	var style := Paper.button_box(Color("#276c70") if selected else Color("#f0dfb7"), Color("#f2bd68") if selected else Color("#8e7954"), 0)
	style.set_border_width(SIDE_BOTTOM, 4)
	style.corner = 1
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 14 if station else 2
	style.content_margin_bottom = 4
	return style

func _style_button(button: Button, selected: bool) -> void:
	var station: bool = button.get_meta("map_station")
	var normal := _selected_style if selected else _normal_style
	if station:
		normal = _selected_station_style if selected else _station_style
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, normal)
	var ink := Color("#fff4d7") if selected else Color("#24474c")
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)

func _layout_map_buttons() -> void:
	if not is_instance_valid(_canvas) or not is_instance_valid(_detail_body) or not is_instance_valid(_hub):
		return
	var menu_scale := Paper.physical_scale(_canvas)
	var compact := get_viewport().get_visible_rect().size.x * menu_scale < 1100.0
	_workspace.columns = 1 if compact else 2
	_detail_body.vertical = not compact
	var unit := 1.0 / menu_scale
	var hub_size := Vector2(99.0, 44.0) * unit
	var minimum_hit := ceili(44.0 * unit) * Vector2.ONE
	var font_size := ceili(16.0 * Paper.text_scale() * unit)
	_hub.add_theme_font_size_override("font_size", font_size)
	hub_size = hub_size.max(_hub.get_minimum_size())
	var station_hit := _measure_buttons(_stations, minimum_hit, font_size)
	var overview_hit := _measure_buttons(_gates, minimum_hit, font_size)
	var station_header := hub_size.y + 11.0 * unit
	var overview_header := 34.0 * unit
	var station_width := maxf(218.0 * unit, maxf(hub_size.x + 107.0 * unit, 4.0 * station_hit.x + 30.0 * unit))
	var overview_width := maxf(164.0 * unit, 3.0 * overview_hit.x + 26.0 * unit)
	var content_height := maxf(station_header + 3.0 * station_hit.y, overview_header + ceilf(float(_gates.size()) / 3.0) * overview_hit.y)
	_canvas.custom_minimum_size = Vector2(maxf(600.0 * unit, station_width + overview_width + 165.0 * unit),
		maxf(220.0 * unit if compact else 0.0, content_height + 24.0 * unit))
	_canvas.arrange(menu_scale, station_width, overview_width)
	var stations := _canvas.station_index
	_hub.position = Vector2(stations.end.x - hub_size.x - 8.0 * unit, stations.position.y + 5.0 * unit)
	_hub.custom_minimum_size = hub_size
	_hub.size = hub_size
	_place_buttons(_stations, stations, 4, station_hit, station_header, 8.0 * unit)
	_place_buttons(_gates, _canvas.region_overview, 3, overview_hit, overview_header, 8.0 * unit)
	for button in _stations:
		var icon := button.get_node("StationIcon") as StationIcon
		icon.scale = Vector2.ONE * unit
		icon.position = Vector2((button.size.x - 16.0 * unit) * 0.5, 2.0 * unit)

func _measure_buttons(buttons: Array[Button], hit: Vector2, font_size: int) -> Vector2:
	for button in buttons:
		button.add_theme_font_size_override("font_size", font_size)
		hit = hit.max(button.get_minimum_size())
	return hit

func _place_buttons(buttons: Array[Button], area: Rect2, columns: int, hit: Vector2, header: float, inset: float) -> void:
	var rows := ceili(float(buttons.size()) / float(columns))
	if rows == 0:
		return
	var outer := area.grow(-inset)
	outer.position.y = area.position.y + header
	outer.size.y = maxf(hit.y * rows, area.end.y - outer.position.y - inset)
	var step_x := (outer.size.x - hit.x) / float(columns - 1)
	var step_y := (outer.size.y - hit.y) / float(maxi(1, rows - 1))
	for index in buttons.size():
		var button := buttons[index]
		button.custom_minimum_size = hit
		button.size = hit
		button.position = outer.position + Vector2((index % columns) * step_x, floorf(float(index) / columns) * step_y)

func _position(point_id: String) -> Vector3:
	return _positions.get(point_id, Vector3.INF)

## Which side of the island `point` is on, as a compass word.
func _bearing(point: Vector3) -> String:
	const BEARINGS := ["東", "東南", "南", "西南", "西", "西北", "北", "東北"]
	return BEARINGS[posmod(roundi((Vector2(point.x, point.z) - IslandShape.CENTER).angle() / (TAU / 8.0)), 8)]

func _select_hub() -> void:
	if not _set_map_selection(_hub, _position("arrival")):
		return
	_detail_title.text = "海風碼頭｜下船起點"
	_detail_text.text = "在步行圖南端。沿木棧橋向北到中央廣場。"

func _select_game(button: Button, game_id: String, number: int, game: Dictionary) -> void:
	var point := _position(game_id)
	if not _set_map_selection(button, point):
		return
	_detail_title.text = "第 %02d 站｜%s" % [number, str(game.get("name", game_id))]
	var goal := str(game.get("goal", "完成設施挑戰。"))
	_detail_text.text = goal if not point.is_finite() else "%s｜%s\n%s" % [_bearing(point), IslandShape.area_at(Vector2(point.x, point.z)), goal]

func _select_zone(button: Button, zone: Dictionary) -> void:
	var region := str(zone.get("id", ""))
	var playable := RegionRoutes.supports(region)
	var point := _position("gate:" + region) if playable else Vector3.INF
	if not _set_map_selection(button, point):
		return
	var threshold := RegionRoutes.threshold(region) if playable else int(zone.get("threshold", 0))
	var remaining := maxi(threshold - _normal_count, 0)
	var arrival := ("可前往" if remaining == 0 else "尚未達資格") if playable else "準備中"
	_detail_title.text = "%s｜%s" % [str(zone.get("name", "未命名園區")), arrival]
	var qualification := "已達入園資格" if remaining == 0 else "還差 %d 張不同普通拍貼" % remaining
	var progress := "普通拍貼：%d / %d 張\n%s；收藏不消耗。" % [_normal_count, threshold, qualification]
	if playable:
		var location := "島的%s岸，返回免費。" % _bearing(point) if point.is_finite() else "返回免費。"
		_detail_text.text = progress + "\n" + location
	else:
		_detail_text.text = "主題：%s\n%s" % [str(zone.get("theme", "主題資料準備中。")), progress]

func _set_map_selection(button: Button, point: Vector3) -> bool:
	if button == _selected:
		return false
	if is_instance_valid(_selected):
		_style_button(_selected, false)
	_selected = button
	_style_button(button, true)
	_canvas.select(point)
	return true
