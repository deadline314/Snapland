extends RefCounted
## Shared tidal paper-theatre interface, readable with keyboard focus and pointer.
const INK = Color("#203e47")
const PAPER = Color("#f7efd9")
const TEAL = Color("#337b7b")
const DEEP_TEAL = Color("#24585d")
const CORAL = Color("#d97966")
const GOLD = Color("#dfa458")
const FONT = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")

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
	const CHARACTER_ATLAS = preload("res://assets/minigames/props/tidal-props-v2.png")
	var speaker := ""
	func _draw() -> void:
		# Use the actual mascot and playable character art where their sprite exists.
		var paper := Color("#f3e6c9")
		var ink := Color("#294951")
		var hair := Color("#5c5147")
		var face := Color("#e8b990")
		draw_arc(Vector2(48, 48), 39, 0, TAU, 48, Color("#dfa458"), 2.2)
		draw_arc(Vector2(48, 48), 34, 0.1, TAU - 0.1, 40, Color("#b97759"), 0.8)
		if speaker=="小角":
			# Runtime crop from the mascot region; source artwork stays untouched.
			draw_texture_rect_region(CHARACTER_ATLAS, Rect2(8, 21, 80, 47), Rect2(661, 365, 268, 148))
			return
		if speaker=="主角":
			# Dark-haired teal-coated camera visitor, matching the in-world character.
			draw_texture_rect_region(CHARACTER_ATLAS, Rect2(17, 17, 62, 64), Rect2(386, 324, 160, 159))
			return
		if speaker=="票票": hair=Color("#503d34")
		elif speaker=="阿浪": hair=Color("#354c64")
		elif speaker=="露露": hair=Color("#66534b")
		# Shoulder line and sailor collar.
		var uniform := Color("#dca94f") if speaker=="票票" else Color("#337b7b")
		draw_colored_polygon(PackedVector2Array([Vector2(17, 79), Vector2(22, 67), Vector2(34, 61), Vector2(48, 66), Vector2(62, 61), Vector2(75, 68), Vector2(80, 81)]), uniform)
		draw_line(Vector2(40, 65), Vector2(48, 76), paper, 2)
		draw_line(Vector2(56, 65), Vector2(48, 76), paper, 2)
		# Neck, ear, face and distinct fringe strokes.
		draw_rect(Rect2(42, 56, 12, 12), face)
		draw_colored_polygon(PackedVector2Array([Vector2(32, 36), Vector2(35, 22), Vector2(48, 17), Vector2(62, 23), Vector2(65, 40), Vector2(61, 57), Vector2(54, 64), Vector2(40, 62), Vector2(33, 52)]), face)
		draw_arc(Vector2(31, 44), 4, PI * 1.5, PI * 2.5, 12, face, 2)
		draw_arc(Vector2(65, 44), 4, PI * 0.5, PI * 1.5, 12, face, 2)
		draw_colored_polygon(PackedVector2Array([Vector2(31, 42), Vector2(30, 29), Vector2(35, 20), Vector2(44, 15), Vector2(57, 17), Vector2(65, 25), Vector2(66, 39), Vector2(60, 34), Vector2(54, 28), Vector2(47, 32), Vector2(38, 30)]), hair)
		if speaker=="票票":
			# Code-native park guide cap and tiny ticket badge.
			draw_colored_polygon(PackedVector2Array([Vector2(33, 29), Vector2(36, 18), Vector2(46, 13), Vector2(58, 17), Vector2(64, 27), Vector2(48, 24)]), Color("#e0ad55"))
			draw_line(Vector2(31, 30), Vector2(66, 30), ink, 2)
			draw_line(Vector2(46, 20), Vector2(50, 20), Color("#f7efd9"), 2)
		draw_line(Vector2(39, 43), Vector2(43, 43), ink, 1.8)
		draw_line(Vector2(53, 43), Vector2(57, 43), ink, 1.8)
		draw_line(Vector2(48, 44), Vector2(46, 50), ink, 1.1)
		draw_arc(Vector2(48, 51), 5, 0.25, PI - 0.25, 10, Color("#9f5c50"), 1.2)

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
	result.set_stylebox("normal", "Button", button_box(Color("#eee4cd"), Color("#c1a97d")))
	result.set_stylebox("hover", "Button", button_box(TEAL, Color("#dfa458")))
	result.set_stylebox("pressed", "Button", button_box(DEEP_TEAL, Color("#dfa458")))
	var focus := button_box(Color(0, 0, 0, 0), GOLD)
	focus.set_border_width_all(3)
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
	style.border_color=Color("#d3c29e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=10
	style.content_margin_bottom=10
	style.shadow_color=Color("#172f39", 0.22)
	style.shadow_size=3
	style.shadow_offset=Vector2(1, 2)
	return style

static func button_box(color: Color, edge: Color) -> StyleBoxFlat:
	var style := box(color, 9)
	style.border_color=edge
	style.set_border_width_all(1)
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=7
	style.content_margin_bottom=7
	return style

static func plaque(color := PAPER) -> StyleBoxFlat:
	var style := box(color, 8)
	style.border_color=Color("#bba77e")
	style.set_border_width_all(1)
	style.shadow_size=4
	style.shadow_color=Color("#122a32", 0.3)
	return style

static func label(text: String, size := 20, color := INK) -> Label:
	var result := Label.new()
	result.text=text
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
	result.custom_minimum_size.y=46
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	parent.add_child(result)
	return result
