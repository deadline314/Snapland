extends RefCounted
## Shared layered pixel interface, readable with keyboard focus and pointer.
const INK = Color("#f0f0d8")
const PAPER = Color("#f0f0d8")
const TEAL = Color("#80e6c2")
const DEEP_TEAL = Color("#0c2938")
const CORAL = Color("#f08f73")
const PRICE_INK = Color("#8d3c33")
const GOLD = Color("#ffc66d")
const FRAME = Color("#163d4d")
const DEEP = Color("#071b2b")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
static var FONT: Font = FontProfiles.current_font()
const PIXEL_CHECKED = preload("res://assets/ui/pixel-controls/checked.svg")
const PIXEL_UNCHECKED = preload("res://assets/ui/pixel-controls/unchecked.svg")
const PIXEL_CHECKED_DISABLED = preload("res://assets/ui/pixel-controls/checked-disabled.svg")
const PIXEL_UNCHECKED_DISABLED = preload("res://assets/ui/pixel-controls/unchecked-disabled.svg")
const PIXEL_GRABBER = preload("res://assets/ui/pixel-controls/grabber.svg")
const PIXEL_GRABBER_HIGHLIGHT = preload("res://assets/ui/pixel-controls/grabber-highlight.svg")
const PIXEL_GRABBER_DISABLED = preload("res://assets/ui/pixel-controls/grabber-disabled.svg")
static var _reduced_motion := false
static var _text_scale := 1.0
static var _font_style := "pixel"

static func set_font_style(style: String) -> void:
	_font_style = "readable" if style == "readable" else "pixel"
	FontProfiles.set_style(_font_style)
	FONT = FontProfiles.current_font()

static func font_style() -> String:
	return _font_style

static func font() -> Font:
	FontProfiles.refresh_context()
	FONT = FontProfiles.current_font()
	return FONT

class PrintMark extends Control:
	var motif := "ticket"
	var tint := Color("#80e6c2")
	var ink := Color("#f0f0d8")
	func _draw() -> void:
		var unit := maxf(1.0,floorf(minf(size.x,size.y)/16.0))
		var left := floorf((size.x-16.0*unit)*0.5)
		var top := floorf((size.y-16.0*unit)*0.5)
		var p := func(x: float,y: float,w: float,h: float,color: Color) -> void:
			var gx := floorf(x*0.5); var gy := floorf(y*0.5)
			var gw := maxf(1.0,floorf(w*0.5)); var gh := maxf(1.0,floorf(h*0.5))
			draw_rect(Rect2(left+gx*unit,top+gy*unit,gw*unit,gh*unit),color)
		match motif:
			"album":
				p.call(4,6,24,21,tint); p.call(7,9,18,15,DEEP)
				p.call(9,20,5,4,GOLD); p.call(14,16,5,8,GOLD); p.call(19,12,4,12,GOLD); p.call(9,11,3,3,ink)
			"map":
				p.call(3,6,8,20,tint); p.call(11,4,10,24,tint); p.call(21,6,8,20,tint)
				p.call(5,9,4,14,DEEP); p.call(13,7,6,18,DEEP); p.call(23,9,4,14,DEEP)
				p.call(6,20,3,3,GOLD); p.call(14,16,4,4,GOLD); p.call(23,10,3,4,GOLD)
			"pin":
				p.call(10,3,12,3,tint); p.call(7,6,18,3,tint); p.call(5,9,22,8,tint)
				p.call(8,17,16,3,tint); p.call(12,20,8,3,tint); p.call(15,23,2,7,tint); p.call(13,11,6,5,GOLD)
			"devil":
				p.call(3,4,5,7,CORAL); p.call(6,7,5,4,tint); p.call(23,7,5,4,tint); p.call(25,4,5,7,CORAL)
				p.call(7,10,18,15,tint); p.call(10,14,3,3,ink); p.call(19,14,3,3,ink); p.call(14,20,5,2,ink)
			"hat":
				p.call(7,14,18,7,tint); p.call(10,8,12,6,tint); p.call(4,23,24,4,GOLD)
			"gear":
				p.call(12,3,8,6,tint); p.call(12,23,8,6,tint); p.call(3,12,6,8,tint); p.call(23,12,6,8,tint)
				p.call(8,8,16,16,tint); p.call(12,12,8,8,DEEP); p.call(14,14,4,4,GOLD)
			"shell":
				p.call(14,3,4,4,tint); p.call(10,7,12,4,tint); p.call(7,11,18,4,tint); p.call(5,15,22,4,tint)
				p.call(8,19,16,4,tint); p.call(12,23,8,3,tint); p.call(14,26,4,3,tint); p.call(15,12,2,8,GOLD)
			_:
				p.call(3,7,26,18,tint); p.call(6,10,20,12,DEEP); p.call(10,9,2,14,tint)
				p.call(17,13,7,7,GOLD); p.call(19,11,3,11,GOLD)

class PixelFrame extends Control:
	var frame_color := Color("#163d4d")
	var accent_color := Color("#ffc66d")
	func _draw() -> void:
		var w := floorf(size.x)
		var h := floorf(size.y)
		var unit := 2.0
		for x in [4.0,w-10.0]:
			draw_rect(Rect2(x,2,6,unit),accent_color)
			draw_rect(Rect2(x,2,unit,6),accent_color)
			draw_rect(Rect2(x, h-4,6,unit),accent_color)
			draw_rect(Rect2(x+4,h-8,unit,4),accent_color)
		draw_rect(Rect2(0,10,unit,h-20),frame_color)
		draw_rect(Rect2(w-unit,10,unit,h-20),frame_color)
		draw_rect(Rect2(10,0,w-20,unit),frame_color)
		draw_rect(Rect2(10,h-unit,w-20,unit),frame_color)
		for x in range(18,int(w)-18,12):
			draw_rect(Rect2(x,0,2,2),accent_color)
			draw_rect(Rect2(x,h-2,2,2),accent_color)

class CharacterPortrait extends Control:
	const CharacterLibraryScript = preload("res://game/world/character_animation_library.gd")
	var speaker := ""
	var animation_library: RefCounted
	func _init() -> void:
		animation_library=CharacterLibraryScript.new()
	func _draw() -> void:
		var ink := INK
		for point in [Vector2(8,8),Vector2(80,8),Vector2(8,80),Vector2(80,80)]:
			draw_rect(Rect2(point.x,point.y,12,4),GOLD)
			draw_rect(Rect2(point.x,point.y,4,12),GOLD)
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
		var center := (size*0.5).floor()
		for offset in [Vector2(-6,-6),Vector2(4,-6),Vector2(-6,4),Vector2(4,4)]:
			draw_rect(Rect2(center+offset*2.0,Vector2(2,2)),GOLD)
		draw_rect(Rect2(center+Vector2(-1,-5),Vector2(2,10)),TEAL)
		draw_rect(Rect2(center+Vector2(-5,-1),Vector2(10,2)),TEAL)

class DeckleBand extends Control:
	func _draw() -> void:
		for x in range(0,int(size.x),8):
			draw_rect(Rect2(x,2,mini(4,int(size.x)-x),2),TEAL if (x/8)%2==0 else FRAME)

class PixelButtonBevel extends Control:
	var button: Button
	var pointer_inside := false
	var pointer_down := false
	var keyboard_focus := false
	var current_state := "normal"

	func bind(target: Button) -> void:
		button=target
		name="PaperPixelBevel"
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Children already draw above their button; stay below later modal siblings.
		z_index=0
		target.mouse_entered.connect(_on_mouse_entered)
		target.mouse_exited.connect(_on_mouse_exited)
		target.button_down.connect(_on_button_down)
		target.button_up.connect(_on_button_up)
		target.focus_entered.connect(_on_focus_entered)
		target.focus_exited.connect(_on_focus_exited)
		target.resized.connect(queue_redraw)
		_sync_state()

	func _on_mouse_entered() -> void:
		pointer_inside=true
		_sync_state()

	func _on_mouse_exited() -> void:
		pointer_inside=false
		_sync_state()

	func _on_button_down() -> void:
		pointer_down=true
		_sync_state()

	func _on_button_up() -> void:
		pointer_down=false
		_sync_state()

	func _on_focus_entered() -> void:
		keyboard_focus=true
		_sync_state()

	func _on_focus_exited() -> void:
		keyboard_focus=false
		_sync_state()

	func _sync_state() -> void:
		if button==null or button.disabled:
			current_state="disabled"
		elif pointer_down or button.button_pressed:
			current_state="pressed"
		elif pointer_inside:
			current_state="hover"
		else:
			current_state="normal"
		queue_redraw()

	func _draw() -> void:
		if button==null or size.x<12.0 or size.y<12.0: return
		# Keep a clear moat around the separate keyboard-focus outline.
		var transform := get_global_transform_with_canvas()
		var scale_factor := minf(transform.x.length(),transform.y.length())
		if not is_finite(scale_factor) or scale_factor<0.2: scale_factor=1.0
		var inset := maxf(4.0,ceil(3.0/scale_factor))
		var edge := maxf(2.0,ceil(2.0/scale_factor))
		var frame := Rect2(Vector2(inset,inset),size-Vector2(inset*2.0,inset*2.0))
		if frame.size.x<edge*3.0 or frame.size.y<edge*3.0: return
		var style := button.get_theme_stylebox(current_state) as StyleBoxFlat
		var face := style.bg_color if style!=null else Color("#21495a")
		var light := face.lightened(0.30)
		var dark := face.darkened(0.48)
		if current_state=="disabled":
			light=face.lightened(0.20)
			dark=face.darkened(0.28)
		var pushed := current_state=="pressed"
		var upper := dark if pushed else light
		var lower := light.darkened(0.22) if pushed else dark
		# Two stepped upper/left catches and deeper lower/right sides give the
		# small dark control a readable printed-paper thickness at a glance.
		draw_rect(Rect2(frame.position,Vector2(frame.size.x,edge)),upper)
		draw_rect(Rect2(frame.position,Vector2(edge,frame.size.y)),upper.lightened(0.08))
		draw_rect(Rect2(frame.position+Vector2(edge,edge),Vector2(maxf(0,frame.size.x-edge*2.0),maxf(1,edge*0.55))),face.lightened(0.12))
		draw_rect(Rect2(Vector2(frame.end.x-edge*2.0,frame.position.y+edge),Vector2(edge*2.0,frame.size.y-edge)),lower.darkened(0.16))
		draw_rect(Rect2(Vector2(frame.position.x+edge,frame.end.y-edge*2.0),Vector2(frame.size.x-edge,edge*2.0)),lower)
		# A narrow second shade reads as a cast edge without extending the button's bbox.
		if not pushed and current_state!="disabled":
			draw_rect(Rect2(Vector2(frame.end.x-edge,frame.position.y+edge),Vector2(edge,frame.size.y-edge)),Color(dark.r,dark.g,dark.b,0.62))
			draw_rect(Rect2(Vector2(frame.position.x+edge,frame.end.y-edge),Vector2(frame.size.x-edge,edge)),Color(dark.r,dark.g,dark.b,0.62))

static func theme() -> Theme:
	var result := Theme.new()
	FontProfiles.refresh_context()
	FONT=FontProfiles.current_font()
	result.default_font=FONT
	result.default_font_size=20
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", PAPER)
	result.set_color("font_pressed_color", "Button", PAPER)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("#e0dfc5"))
	result.set_stylebox("disabled", "Button", button_box(Color("#30434a"), Color("#71858a"), 0, Vector2.ZERO))
	result.set_stylebox("normal", "Button", button_box(Color("#21495a"), Color("#80b9a9"), 3, Vector2(2,3)))
	result.set_stylebox("hover", "Button", button_box(Color("#2a6471"), GOLD, 4, Vector2(2,5)))
	result.set_stylebox("pressed", "Button", button_box(Color("#184356"), Color("#d9a858"), 0, Vector2.ZERO))
	var focus := button_box(Color(0, 0, 0, 0), GOLD)
	focus.set_border_width_all(3)
	focus.shadow_size=0
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", plaque())
	result.set_color("font_color", "CheckButton", INK)
	result.set_color("font_hover_color", "CheckButton", TEAL)
	result.set_stylebox("slider", "HSlider", box(Color("#385461"), 0))
	result.set_stylebox("grabber_area", "HSlider", box(TEAL, 4))
	for icon_key in ["checked","unchecked","checked_disabled","unchecked_disabled"]:
		var texture: Texture2D={"checked":PIXEL_CHECKED,"unchecked":PIXEL_UNCHECKED,"checked_disabled":PIXEL_CHECKED_DISABLED,"unchecked_disabled":PIXEL_UNCHECKED_DISABLED}[icon_key]
		result.set_icon(icon_key,"CheckButton",texture)
		result.set_icon(icon_key+"_mirrored","CheckButton",texture)
	for marker in ["checked","radio_checked"]:
		result.set_icon(marker,"PopupMenu",PIXEL_CHECKED)
		result.set_icon(marker+"_disabled","PopupMenu",PIXEL_CHECKED_DISABLED)
	for marker in ["unchecked","radio_unchecked"]:
		result.set_icon(marker,"PopupMenu",PIXEL_UNCHECKED)
		result.set_icon(marker+"_disabled","PopupMenu",PIXEL_UNCHECKED_DISABLED)
	result.set_icon("grabber","HSlider",PIXEL_GRABBER)
	result.set_icon("grabber_highlight","HSlider",PIXEL_GRABBER_HIGHLIGHT)
	result.set_icon("grabber_disabled","HSlider",PIXEL_GRABBER_DISABLED)
	result.set_stylebox("panel","PopupMenu",plaque(DEEP))
	result.set_stylebox("hover","PopupMenu",button_box(Color("#1e5360"),GOLD,0,Vector2.ZERO))
	for ink_key in ["font_color","font_hover_color","font_accelerator_color"]:
		result.set_color(ink_key,"PopupMenu",PAPER)
	result.set_color("font_disabled_color","PopupMenu",Color("#b6c9c9"))
	result.set_constant("v_separation","PopupMenu",16)
	result.set_stylebox("panel","TooltipPanel",plaque(DEEP))
	result.set_color("font_color","TooltipLabel",PAPER)
	return result

static func box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=DEEP if color.get_luminance()>0.68 else color
	style.border_color=FRAME
	style.set_border_width_all(1)
	style.set_border_width(SIDE_BOTTOM, 2)
	style.set_corner_radius_all(0)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=9
	style.content_margin_bottom=9
	style.shadow_size=0
	return style

static func button_box(color: Color, edge: Color, shadow_size := 2, shadow_offset := Vector2(1, 2)) -> StyleBoxFlat:
	var style := box(color, 0)
	style.border_color=edge
	style.set_border_width_all(1)
	var depth := maxi(0, shadow_size)
	style.set_border_width(SIDE_RIGHT, depth + 2)
	style.set_border_width(SIDE_BOTTOM, depth + 3)
	style.border_blend=false
	style.shadow_color=Color("#041521cc") if depth > 0 else Color(0,0,0,0)
	style.shadow_size=depth
	style.shadow_offset=shadow_offset if depth > 0 else Vector2.ZERO
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=9
	style.content_margin_bottom=11
	return style

static func fitting_frame(color := Color("#163d4d")) -> StyleBoxFlat:
	var style := box(color, 4)
	style.border_color=Color("#6e7770")
	style.set_border_width_all(2)
	style.set_border_width(SIDE_RIGHT, 5)
	style.set_border_width(SIDE_BOTTOM, 8)
	style.shadow_color=Color("#071b2baa")
	style.shadow_size=6
	style.shadow_offset=Vector2.ZERO
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=10
	style.content_margin_bottom=12
	return style

static func focus_outline() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0, 0, 0, 0)
	style.border_color=Color("#dfa458")
	style.set_border_width_all(3)
	style.set_corner_radius_all(0)
	style.shadow_size=0
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=7
	style.content_margin_bottom=7
	return style

static func tab_box(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=DEEP_TEAL if selected else Color("#173a4b")
	style.border_color=GOLD if selected else Color("#477080")
	style.set_border_width_all(2 if selected else 1)
	style.set_border_width(SIDE_BOTTOM, 0 if selected else 4)
	style.set_corner_radius_all(0)
	style.shadow_color=Color(0,0,0,0)
	style.shadow_size=0
	style.shadow_offset=Vector2.ZERO
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=8
	style.content_margin_bottom=7
	return style

static func set_button_role(button: Button, role: String) -> void:
	_attach_button_bevel(button)
	var primary := role == "primary"
	if role == "tab_selected" or role == "tab_idle":
		var selected := role == "tab_selected"
		var tab_style := tab_box(selected)
		button.add_theme_stylebox_override("normal", tab_style)
		var hover_style := tab_style.duplicate() as StyleBoxFlat
		hover_style.bg_color=Color("#1e5360")
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", tab_style)
		button.add_theme_stylebox_override("focus", focus_outline())
		var tab_ink := PAPER
		button.add_theme_color_override("font_color", tab_ink)
		button.add_theme_color_override("font_hover_color", tab_ink)
		button.add_theme_color_override("font_pressed_color", tab_ink)
		button.add_theme_color_override("font_focus_color", tab_ink)
		return
	var normal_color := Color("#164c5e") if primary else Color("#21495a")
	var hover_color := Color("#2a6471") if primary else Color("#2a596a")
	var pressed_color := Color("#174253") if primary else Color("#184356")
	var edge := GOLD if primary else Color("#80b9a9")
	button.add_theme_stylebox_override("normal", button_box(normal_color, edge, 4 if primary else 3, Vector2(2, 4) if primary else Vector2(2, 3)))
	button.add_theme_stylebox_override("hover", button_box(hover_color, GOLD if primary else TEAL, 5 if primary else 4, Vector2(2, 5) if primary else Vector2(2, 4)))
	button.add_theme_stylebox_override("pressed", button_box(pressed_color, edge, 0, Vector2.ZERO))
	var disabled := button_box(Color("#30434a"), Color("#71858a"), 0, Vector2.ZERO)
	disabled.bg_color=Color("#30434a")
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus_outline())
	var text_color := PAPER
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color("#e0dfc5"))

static func plaque(color := PAPER) -> StyleBoxFlat:
	var style := box(color, 0)
	style.border_color=FRAME
	style.set_border_width_all(2)
	style.set_border_width(SIDE_RIGHT, 3)
	style.set_border_width(SIDE_BOTTOM, 4)
	style.border_blend=false
	style.shadow_color=Color("#041521bb")
	style.shadow_size=3
	style.shadow_offset=Vector2(1,2)
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style

## Root calls this when the saved accessibility option changes. Paper depth itself is static;
## callers can consult reduced_motion() before adding any optional transition.
static func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion=enabled

static func set_text_scale(value: float) -> void:
	_text_scale=clampf(value,1.0,1.25)

static func text_scale() -> float:
	return _text_scale

static func reduced_motion() -> bool:
	return _reduced_motion

static func motion_duration_seconds(requested_duration: float) -> float:
	return 0.0 if _reduced_motion else maxf(requested_duration, 0.0)

static func label(text: String, size := 20, color := INK) -> Label:
	var result := Label.new()
	result.text=text
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", size)
	var readable := color
	if color!=PRICE_INK and color.get_luminance()<0.55:
		readable=TEAL if color==DEEP_TEAL else Color("#b6c9c9")
	result.add_theme_color_override("font_color", readable)
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
	panel.add_theme_stylebox_override("panel", box(Color("#102b3a"), 0))
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
	_attach_button_bevel(result)
	parent.add_child(result)
	return result

static func _attach_button_bevel(button: Button) -> void:
	if button==null or button.has_node("PaperPixelBevel"): return
	var bevel := PixelButtonBevel.new()
	button.add_child(bevel)
	bevel.bind(button)

static func physical_scale(control: CanvasItem) -> float:
	var transform := control.get_viewport().get_final_transform()
	return maxf(0.01,minf(transform.x.length(),transform.y.length()))

static func adapt_menu(node: Node, scale_factor: float) -> void:
	if node is Control:
		var control := node as Control
		if control is Button: _attach_button_bevel(control as Button)
		if not control.has_meta("menu_base_minimum"):
			control.set_meta("menu_base_minimum",control.custom_minimum_size)
		var base: Vector2=control.get_meta("menu_base_minimum")
		if control is Label or control is Button:
			if not control.has_meta("menu_base_font"):
				control.set_meta("menu_base_font",control.get_theme_font_size("font_size"))
			var base_font: int=control.get_meta("menu_base_font")
			var physical_font := maxi(base_font,20 if base_font>=20 else 16)
			control.add_theme_font_size_override("font_size",ceili(float(physical_font)*_text_scale/scale_factor))
		if control is OptionButton:
			var popup: PopupMenu=(control as OptionButton).get_popup()
			var popup_font_size := control.get_theme_font_size("font_size")
			popup.add_theme_font_size_override("font_size",popup_font_size)
			var font_height := control.get_theme_font("font").get_height(popup_font_size)
			popup.add_theme_constant_override("v_separation",ceili(maxf(8.0/scale_factor,44.0/scale_factor-font_height)))
			_prepare_popup_bounds(control as OptionButton)
			if not popup.has_meta("pixel_popup_bounds_connected"):
				popup.set_meta("pixel_popup_bounds_connected",true)
				popup.about_to_popup.connect(_queue_popup_bounds.bind(control))

		if control is Button or control.focus_mode==Control.FOCUS_ALL:
			control.custom_minimum_size=Vector2(maxf(base.x,44.0/scale_factor),maxf(base.y,44.0/scale_factor))
		if control is ScrollContainer:
			control.custom_minimum_size.y=0.0 if control.name=="AdaptiveMenuScroll" else minf(base.y,maxf(120.0,control.get_viewport().get_visible_rect().size.y-250.0/scale_factor))
		if control is GridContainer and control.name=="MinigameStampGrid":
			control.columns=clampi(floori((control.get_viewport().get_visible_rect().size.x*scale_factor-90.0)/245.0),2,4)
	for child in node.get_children(): adapt_menu(child,scale_factor)

static func _prepare_popup_bounds(selector: OptionButton) -> Rect2:
	var bounds := selector.get_viewport().get_visible_rect()
	var inset := 8.0/physical_scale(selector)
	bounds=bounds.grow(-inset)
	selector.get_popup().max_size=Vector2i(bounds.size.floor())
	return bounds

static func _queue_popup_bounds(selector: OptionButton) -> void:
	_prepare_popup_bounds(selector)
	_fit_popup_bounds.call_deferred(selector)

static func _fit_popup_bounds(selector: OptionButton) -> void:
	if not is_instance_valid(selector): return
	var popup := selector.get_popup()
	if not popup.visible: return
	var bounds := _prepare_popup_bounds(selector)
	var target_size := Vector2(popup.size).min(bounds.size)
	var full_height := _popup_full_height(popup)
	# Native popup sizing can already have been truncated by max_size when
	# about_to_popup fires. Restore the complete natural height for short menus;
	# menus taller than the viewport retain Godot's built-in scrolling.
	if full_height <= bounds.size.y:
		target_size.y=full_height
	popup.size=Vector2i(target_size.floor())
	var position := Vector2(popup.position)
	position.x=clampf(position.x,bounds.position.x,bounds.end.x-popup.size.x)
	var below_space := bounds.end.y - position.y
	var above_space := position.y - bounds.position.y
	if full_height <= bounds.size.y and below_space < full_height and above_space >= full_height:
		position.y-=full_height
	position.y=clampf(position.y,bounds.position.y,bounds.end.y-popup.size.y)
	popup.position=Vector2i(position.round())

static func _popup_full_height(popup: PopupMenu) -> float:
	var font := popup.get_theme_font("font")
	var font_size := popup.get_theme_font_size("font_size")
	var row_height := float(font.get_height(font_size)) + float(popup.get_theme_constant("v_separation"))
	var panel := popup.get_theme_stylebox("panel")
	var total := panel.get_minimum_size().y
	for index in range(popup.get_item_count()):
		if popup.is_item_separator(index):
			total += maxf(5.0, float(popup.get_theme_constant("h_separation")))
		else:
			var icon := popup.get_item_icon(index)
			total += maxf(row_height, float(icon.get_height()) + 8.0 if icon != null else row_height)
	return ceilf(total)
