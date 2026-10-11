extends RefCounted
## Shared parchment interface, readable with keyboard focus and pointer.
const INK = Color("#233f49")
const PAPER = Color("#f7efd9")
const TEAL = Color("#337b7b")
const GOLD = Color("#dfa458")
const FONT = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font=FONT
	result.default_font_size=20
	result.set_color("font_color","Label",INK)
	result.set_color("font_color","Button",INK)
	result.set_color("font_hover_color","Button",PAPER)
	result.set_color("font_pressed_color","Button",PAPER)
	result.set_color("font_focus_color","Button",INK)
	result.set_stylebox("normal","Button",box(Color("#e8ddc1"),10))
	result.set_stylebox("hover","Button",box(TEAL,10))
	result.set_stylebox("pressed","Button",box(Color("#24585d"),10))
	var focus := box(Color.TRANSPARENT,10)
	focus.border_color=GOLD
	focus.set_border_width_all(3)
	result.set_stylebox("focus","Button",focus)
	result.set_stylebox("panel","PanelContainer",box(PAPER,18))
	result.set_color("font_color","CheckButton",INK)
	return result

static func box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style

static func label(text: String, size := 20, color := INK) -> Label:
	var result := Label.new()
	result.text=text
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return result

static func button(text: String, callback: Callable, parent: Node) -> Button:
	var result := Button.new()
	result.text=text
	result.custom_minimum_size.y=44
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	parent.add_child(result)
	return result
