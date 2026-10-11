extends RefCounted
## Shared tidal paper-theatre interface, readable with keyboard focus and pointer.
const INK = Color("#203e47")
const PAPER = Color("#f7efd9")
const TEAL = Color("#337b7b")
const DEEP_TEAL = Color("#24585d")
const CORAL = Color("#d97966")
const GOLD = Color("#dfa458")
const FONT = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
static var _reduced_motion := false

class PrintMark extends Control:
	var motif := "ticket"
	var tint := Color("#337b7b")
	var ink := Color("#203e47")
	func _draw() -> void:
		var scale_factor := minf(size.x, size.y) / 32.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
		match motif:
			"album":
				draw_rect(Rect2(4, 6, 24, 21), tint, false, 2)
				draw_line(Vector2(8, 23), Vector2(14, 16), ink, 2)
				draw_line(Vector2(14, 16), Vector2(19, 21), ink, 2)
				draw_line(Vector2(19, 21), Vector2(24, 15), ink, 2)
				draw_circle(Vector2(11, 11), 1.8, Color("#dfa458"))
			"devil":
				# Original little-devil stamp: curled horns, broad ears, expressive face.
				draw_colored_polygon(PackedVector2Array([Vector2(5, 12), Vector2(2, 4), Vector2(11, 8), Vector2(16, 6), Vector2(22, 8), Vector2(30, 3), Vector2(27, 14), Vector2(25, 23), Vector2(20, 28), Vector2(11, 27), Vector2(6, 22)]), tint)
				draw_arc(Vector2(7, 7), 4, PI * 0.8, PI * 1.85, 12, Color("#d97966"), 2)
				draw_arc(Vector2(25, 7), 4, PI * 1.15, PI * 2.2, 12, Color("#d97966"), 2)
				draw_circle(Vector2(12, 17), 1.2, PAPER)
				draw_circle(Vector2(20, 17), 1.2, PAPER)
				draw_arc(Vector2(16, 20), 4, 0.25, PI - 0.25, 12, PAPER, 1.4)
			"pin":
				draw_arc(Vector2(16, 12), 9, PI, TAU, 18, tint, 2.5)
				draw_line(Vector2(7, 12), Vector2(16, 29), tint, 2.5)
				draw_line(Vector2(25, 12), Vector2(16, 29), tint, 2.5)
				draw_circle(Vector2(16, 12), 3.2, CORAL)
			"map":
				draw_rect(Rect2(3, 5, 26, 22), Color(0, 0, 0, 0), false, 2)
				draw_line(Vector2(11, 6), Vector2(11, 26), tint, 1.5)
				draw_line(Vector2(21, 6), Vector2(21, 26), tint, 1.5)
				draw_polyline(PackedVector2Array([Vector2(5, 21), Vector2(10, 17), Vector2(15, 20), Vector2(23, 11), Vector2(27, 9)]), CORAL, 2)
			_:
				# Perforated entry ticket with a small sunburst seal.
				draw_rect(Rect2(3, 7, 26, 18), tint, false, 2)
				draw_line(Vector2(10, 8), Vector2(10, 24), tint.darkened(0.1), 1, true)
				for y in [11.0, 15.0, 19.0, 23.0]: draw_circle(Vector2(10, y), 1.3, PAPER)
				draw_circle(Vector2(20, 16), 4, Color("#dfa458"))
				draw_line(Vector2(20, 10), Vector2(20, 7), Color("#dfa458"), 1.5)
				draw_line(Vector2(20, 22), Vector2(20, 25), Color("#dfa458"), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class CharacterPortrait extends Control:
	const CharacterLibraryScript = preload("res://game/world/character_animation_library.gd")
	var speaker := ""
	var animation_library: RefCounted
	func _init() -> void:
		animation_library=CharacterLibraryScript.new()
	func _draw() -> void:
		var ink := Color("#294951")
		draw_arc(Vector2(48, 48), 39, 0, TAU, 48, Color("#dfa458"), 2.2)
		draw_arc(Vector2(48, 48), 34, 0.1, TAU - 0.1, 40, Color("#b97759"), 0.8)
		var actor := ""
		match speaker:
			"小角": actor="imp"
			"主角": actor="traveller"
			"票票": actor="ticket"
			"阿浪": actor="announcer"
		if not actor.is_empty():
			var sequence: Dictionary=animation_library.get_sequence(actor,"idle","front")
			var frames: Array=sequence.get("frames",[])
			if not frames.is_empty() and frames[0] is Dictionary and frames[0].get("texture") is Texture2D:
				var texture: Texture2D=frames[0].texture
				var scale_factor := minf(76.0/texture.get_width(),76.0/texture.get_height())
				var draw_size := Vector2(texture.get_size())*scale_factor
				draw_texture_rect(texture,Rect2((size-draw_size)*0.5,draw_size),false)
				return
			# If authored art is unavailable, do not invent a costume for the named character.
			draw_circle(Vector2(48,48),25,Color("#e8b990"))
			draw_string(ThemeDB.fallback_font,Vector2(40,56),speaker.substr(0,1),HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
			return
		draw_circle(Vector2(48,48),25,Color("#e8b990"))
		draw_string(ThemeDB.fallback_font,Vector2(40,56),speaker.substr(0,1),HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)

class Postmark extends Control:
	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center, 9, 0.0, TAU, 32, Color("#b76f57"), 1.5)
		draw_arc(center, 6, 0.0, TAU, 24, Color("#b76f57"), 0.8)
		for index in range(8):
			var direction := Vector2.UP.rotated(TAU * float(index) / 8.0)
			draw_line(center + direction * 11, center + direction * 15, Color("#b76f57"), 1.2)
		draw_line(center + Vector2(-3, 0), center + Vector2(3, 0), Color("#b76f57"), 1)
		draw_line(center + Vector2(0, -3), center + Vector2(0, 3), Color("#b76f57"), 1)

class DeckleBand extends Control:
	func _draw() -> void:
		var previous := Vector2.ZERO
		for index in range(1, int(ceil(size.x / 9.0)) + 1):
			var next := Vector2(minf(float(index) * 9.0, size.x), 1.2 if index % 2 == 0 else 5.4)
			draw_line(previous, next, Color("#bc8a66"), 1.2)
			previous=next

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font=FONT
	result.default_font_size=20
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", PAPER)
	result.set_color("font_pressed_color", "Button", PAPER)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("#7e837b"))
	result.set_stylebox("normal", "Button", button_box(Color("#eee4cd"), Color("#c1a97d"), 3, Vector2(2, 3)))
	result.set_stylebox("hover", "Button", button_box(TEAL, Color("#dfa458"), 5, Vector2(2, 5)))
	result.set_stylebox("pressed", "Button", button_box(DEEP_TEAL, Color("#dfa458"), 0, Vector2.ZERO))
	var focus := button_box(Color(0, 0, 0, 0), GOLD)
	focus.set_border_width_all(3)
	focus.shadow_size=0
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", box(PAPER, 12))
	result.set_color("font_color", "CheckButton", INK)
	result.set_color("font_hover_color", "CheckButton", TEAL)
	result.set_stylebox("slider", "HSlider", box(Color("#ded0b2"), 4))
	result.set_stylebox("grabber_area", "HSlider", box(TEAL, 4))
	return result

static func box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=Color("#c8b78f")
	style.set_border_width_all(1)
	style.set_border_width(SIDE_BOTTOM, 3)
	style.set_corner_radius_all(radius)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=14
	style.content_margin_bottom=14
	style.shadow_color=Color("#172f39", 0.18)
	style.shadow_size=2
	style.shadow_offset=Vector2(2, 3)
	return style

static func button_box(color: Color, edge: Color, shadow_size := 2, shadow_offset := Vector2(1, 2)) -> StyleBoxFlat:
	var style := box(color, 9)
	style.border_color=edge
	style.set_border_width_all(1)
	style.set_border_width(SIDE_BOTTOM, 2 if shadow_size == 0 else 4)
	style.shadow_size=shadow_size
	style.shadow_offset=shadow_offset
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=7
	style.content_margin_bottom=7
	return style

static func plaque(color := PAPER) -> StyleBoxFlat:
	var style := box(color, 8)
	style.border_color=Color("#aa956d")
	style.set_border_width_all(1)
	style.set_border_width(SIDE_BOTTOM, 5)
	style.shadow_size=4
	style.shadow_offset=Vector2(2, 5)
	style.shadow_color=Color("#122a32", 0.20)
	return style

## Root calls this when the saved accessibility option changes. Paper depth itself is static;
## callers can consult reduced_motion() before adding any optional transition.
static func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion=enabled

static func reduced_motion() -> bool:
	return _reduced_motion

static func motion_duration_seconds(requested_duration: float) -> float:
	return 0.0 if _reduced_motion else maxf(requested_duration, 0.0)

static func label(text: String, size := 20, color := INK) -> Label:
	var result := Label.new()
	result.text=text
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return result

static func section_title(text: String, color := TEAL) -> Label:
	var result := label(text, 20, color)
	result.add_theme_font_size_override("font_size", 20)
	result.add_theme_constant_override("outline_size", 0)
	result.custom_minimum_size.y=30
	return result

static func card(parent: Node, color := Color("#fffaf0"), separation := 8) -> VBoxContainer:
	var panel := PanelContainer.new()
	# The plaque is only a backdrop. Keeping its frame out of GUI hit testing lets
	# nested buttons receive real mouse clicks even when the plaque shadow overlaps.
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", plaque(color))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", separation)
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	return content

static func divider(parent: Node, color := Color("#c8b78f")) -> HSeparator:
	var result := HSeparator.new()
	result.add_theme_color_override("separator_color", color)
	parent.add_child(result)
	return result

static func icon(motif: String, extent := 28, tint := TEAL) -> Control:
	var result := PrintMark.new()
	result.motif=motif
	result.tint=tint
	result.custom_minimum_size=Vector2(extent, extent)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

static func portrait(speaker: String) -> Control:
	var result := CharacterPortrait.new()
	result.speaker=speaker
	result.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	result.custom_minimum_size=Vector2(96, 96)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

static func postmark() -> Control:
	var result := Postmark.new()
	result.custom_minimum_size=Vector2(32,32)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

static func deckle_band() -> Control:
	var result := DeckleBand.new()
	result.custom_minimum_size=Vector2(0,8)
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

static func button(text: String, callback: Callable, parent: Node) -> Button:
	var result := Button.new()
	result.text=text
	result.custom_minimum_size.y=44
	result.add_theme_font_size_override("font_size",20)
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

static func physical_scale(control: CanvasItem) -> float:
	var transform := control.get_viewport().get_final_transform()
	return maxf(0.01,minf(transform.x.length(),transform.y.length()))

static func adapt_menu(node: Node, scale_factor: float) -> void:
	if node is Control:
		var control := node as Control
		if not control.has_meta("menu_base_minimum"):
			control.set_meta("menu_base_minimum",control.custom_minimum_size)
		var base: Vector2=control.get_meta("menu_base_minimum")
		if control is Label or control is Button:
			if not control.has_meta("menu_base_font"):
				control.set_meta("menu_base_font",control.get_theme_font_size("font_size"))
			var base_font: int=control.get_meta("menu_base_font")
			var physical_font := maxi(base_font,20 if base_font>=20 else 16)
			control.add_theme_font_size_override("font_size",ceili(float(physical_font)/scale_factor))
		if control is Button or control.focus_mode==Control.FOCUS_ALL:
			control.custom_minimum_size=Vector2(maxf(base.x,44.0/scale_factor),maxf(base.y,44.0/scale_factor))
		if control is ScrollContainer:
			control.custom_minimum_size.y=0.0 if control.name=="AdaptiveMenuScroll" else minf(base.y,maxf(120.0,control.get_viewport().get_visible_rect().size.y-250.0/scale_factor))
		if control is GridContainer and control.name=="MinigameStampGrid":
			control.columns=clampi(floori((control.get_viewport().get_visible_rect().size.x*scale_factor-90.0)/245.0),2,4)
	for child in node.get_children(): adapt_menu(child,scale_factor)
