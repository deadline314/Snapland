extends RefCounted
const PaperMotion = preload("res://game/ui/paper_motion.gd")
## Shared seaside-park interface: painted signboards, enamel buttons, paper tickets
## and brass trim, readable with keyboard focus and pointer.
const INK = Color("#fbf3dc")
const PAPER = Color("#fbf3dc")
const TEAL = Color("#80e6c2")
const DEEP_TEAL = Color("#1d4f5b")
const CORAL = Color("#f08f73")
const PRICE_INK = Color("#8d3c33")
const GOLD = Color("#ffc66d")
const FRAME = Color("#18434f")
const DEEP = Color("#102f3a")
const WOOD = Color("#b9743f")
const BRASS = Color("#dfa458")
const TICKET = Color("#f6ecd0")
const TICKET_INK = Color("#12303b")
const OUTLINE = Color("#07171f")
const SHADOW = Color("#04121a", 0.4)
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

## Every panel, button and ticket is one of these: a board drawn from a few flat
## rectangles, with corners cut in 2 px steps, a lit top edge, an underside lip
## and an offset shadow. Property names follow StyleBoxFlat on purpose.
class Board extends StyleBox:
	enum Kind { ENAMEL, FRAMED, WELL, PAPER, RING }
	const STEP := 2.0
	const PLANK := 46
	## Corner insets per 2 px row, counted in steps, for corner sizes 0 to 3.
	const PROFILES := [[], [1], [2, 1], [4, 2, 1, 1]]
	@export var kind := Kind.ENAMEL
	@export var bg_color := Color("#18434f")
	@export var border_color := Color("#07171f")
	@export var border_width_left := 2
	@export var border_width_top := 2
	@export var border_width_right := 2
	## Rim plus lip: whatever exceeds the top width is drawn as the underside.
	@export var border_width_bottom := 5
	@export var shadow_color := Color(0, 0, 0, 0)
	@export var shadow_size := 0
	@export var shadow_offset := Vector2.ZERO
	@export var corner := 2
	## Face travel in pixels: positive is pressed in, negative is lifted.
	@export var sink := 0
	@export var gloss := 0.12
	## Tear line of a ticket, in pixels from the left (negative: from the right).
	@export var perforation := 0.0
	## Optional 8 x 8 pixel icon (a GLYPHS key) at the left of an enamel face,
	## drawn with the face so it costs no texture or extra draw call.
	@export var glyph := ""
	@export var glyph_scale := 0
	## A smaller board mounted on a ticket (its brass plate), in local pixels.
	var plate: Board
	var plate_rect := Rect2()

	## Resize the icon in whole pixel steps; 0 hides it. The label moves over to make room.
	func set_glyph_scale(factor: int) -> void:
		if factor==glyph_scale: return
		content_margin_left+=_glyph_room(factor)-_glyph_room(glyph_scale)
		glyph_scale=factor
		emit_changed()

	static func _glyph_room(factor: int) -> float:
		return 8.0*factor+4.0 if factor>0 else 0.0

	func set_border_width_all(width: int) -> void:
		border_width_left=width; border_width_top=width; border_width_right=width; border_width_bottom=width

	func set_border_width(side: Side, width: int) -> void:
		match side:
			SIDE_LEFT: border_width_left=width
			SIDE_TOP: border_width_top=width
			SIDE_RIGHT: border_width_right=width
			SIDE_BOTTOM: border_width_bottom=width

	func get_border_width(side: Side) -> int:
		return [border_width_left,border_width_top,border_width_right,border_width_bottom][side]

	func _get_draw_rect(rect: Rect2) -> Rect2:
		var reach := float(shadow_size)+2.0
		return rect.grow_individual(reach,reach+absf(minf(float(sink),0.0)),reach,reach+absf(shadow_offset.y))

	func _draw(item: RID, rect: Rect2) -> void:
		var area := Rect2(rect.position.floor(),rect.size.floor())
		if area.size.x<8.0 or area.size.y<8.0: return
		if kind==Kind.RING or bg_color.a<=0.0:
			_ring(item,area.grow(2.0),3,float(maxi(border_width_left,3)),border_color)
			return
		var notch := 0.0
		if perforation!=0.0: notch=area.position.x+(perforation if perforation>0.0 else area.size.x+perforation)
		if shadow_size>0 and shadow_color.a>0.0:
			var cast := Rect2(area.position+shadow_offset,area.size)
			if shadow_size>=3: _fill(item,cast.grow(2.0),mini(corner+1,3),Color(shadow_color,shadow_color.a*0.4))
			_fill(item,cast,corner,shadow_color,notch)
		if kind==Kind.WELL:
			_fill(item,area,corner,bg_color)
			var edge: float=PROFILES[corner][0]*STEP if corner>0 else 0.0
			RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x+edge,area.position.y,area.size.x-edge*2.0,STEP),bg_color.darkened(0.34))
			RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x+edge,area.end.y-STEP,area.size.x-edge*2.0,STEP),bg_color.lightened(0.07))
			return
		var body := Rect2(area.position+Vector2(0,sink),area.size-Vector2(0,sink))
		var lip := maxf(0.0,float(border_width_bottom-border_width_top-sink))
		var upper := Rect2(body.position,body.size-Vector2(0,lip))
		var face := upper.grow_individual(-border_width_left,-border_width_top,-border_width_right,-border_width_top)
		var inner := maxi(corner-1,0)
		match kind:
			Kind.PAPER:
				_fill(item,body,corner,bg_color.darkened(0.3),notch)
				_fill(item,upper,corner,bg_color,notch)
				if notch>0.0:
					for y in range(int(upper.position.y)+8,int(upper.end.y)-8,6):
						RenderingServer.canvas_item_add_rect(item,Rect2(notch-1.0,y,2,3),border_color)
				if plate!=null and plate_rect.size.x>0.0:
					plate._draw(item,Rect2(area.position+plate_rect.position,plate_rect.size))
			Kind.FRAMED:
				_fill(item,body,corner,border_color.darkened(0.45))
				_fill(item,upper,corner,border_color)
				var edge: float=PROFILES[corner][0]*STEP if corner>0 else 0.0
				RenderingServer.canvas_item_add_rect(item,Rect2(upper.position.x+edge,upper.position.y,upper.size.x-edge*2.0,STEP),border_color.lightened(0.3))
				# The frame's inner bevel, then the paint it shades along the top.
				_fill(item,face.grow(STEP),inner,border_color.darkened(0.32))
				_fill(item,face,inner,bg_color)
				RenderingServer.canvas_item_add_rect(item,Rect2(face.position.x+STEP,face.position.y,face.size.x-STEP*2.0,STEP),bg_color.darkened(0.3))
				# Faint seams between the painted planks.
				for y in range(int(face.position.y)+PLANK,int(face.end.y)-12,PLANK):
					RenderingServer.canvas_item_add_rect(item,Rect2(face.position.x,y,face.size.x,STEP),bg_color.darkened(0.1))
			_:
				_fill(item,body,corner,border_color)
				var slab := body.grow_individual(-border_width_left,-border_width_top,-border_width_right,-border_width_top)
				_fill(item,slab,inner,bg_color.darkened(0.4))
				_fill(item,face,inner,bg_color)
				if gloss>0.0:
					var edge: float=PROFILES[inner][0]*STEP if inner>0 else 0.0
					RenderingServer.canvas_item_add_rect(item,Rect2(face.position.x+edge,face.position.y,face.size.x-edge*2.0,STEP),bg_color.lightened(gloss))
					RenderingServer.canvas_item_add_rect(item,Rect2(face.position.x+edge,face.end.y-STEP,face.size.x-edge*2.0,STEP),bg_color.darkened(gloss))
				if glyph_scale>0: _draw_glyph(item,face)

	func _draw_glyph(item: RID, face: Rect2) -> void:
		var rows: Array=GLYPHS.get(glyph,[])
		var cell := float(glyph_scale)
		var origin := Vector2(face.position.x+8.0,floorf(face.position.y+(face.size.y-8.0*cell)*0.5))
		for y in rows.size():
			var row: String=rows[y]
			var x := 0
			while x<row.length():
				var run := x
				while run<row.length() and row[run]=="#": run+=1
				if run>x: RenderingServer.canvas_item_add_rect(item,Rect2(origin+Vector2(x,y)*cell,Vector2(run-x,1)*cell),PAPER)
				x=maxi(run,x+1)

	static func _fill(item: RID, area: Rect2, steps: int, color: Color, notch := 0.0) -> void:
		if area.size.x<=0.0 or area.size.y<=0.0 or color.a<=0.0: return
		var profile: Array=PROFILES[clampi(steps,0,3)]
		var rows := mini(profile.size(),int(area.size.y*0.5/STEP))
		for row in rows:
			var inset: float=minf(profile[row]*STEP,area.size.x*0.5)
			var gap := maxf(0.0,(2.0-row)*STEP) if notch>0.0 else 0.0
			for y in [area.position.y+row*STEP,area.end.y-(row+1)*STEP]:
				if gap>0.0:
					RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x+inset,y,notch-gap-area.position.x-inset,STEP),color)
					RenderingServer.canvas_item_add_rect(item,Rect2(notch+gap,y,area.end.x-inset-notch-gap,STEP),color)
				else:
					RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x+inset,y,area.size.x-inset*2.0,STEP),color)
		RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x,area.position.y+rows*STEP,area.size.x,area.size.y-rows*STEP*2.0),color)

	static func _inset_at(profile: Array, y: float) -> float:
		var row := int(y/STEP)
		return float(profile[row])*STEP if row>=0 and row<profile.size() else 0.0

	static func _ring(item: RID, area: Rect2, steps: int, thickness: float, color: Color) -> void:
		var profile: Array=PROFILES[clampi(steps,0,3)]
		var zone := int(profile.size()*STEP+thickness)
		for y in zone:
			var outer := _inset_at(profile,y)
			for row_y in [area.position.y+y,area.end.y-y-1.0]:
				if y<thickness:
					RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x+outer,row_y,area.size.x-outer*2.0,1),color)
				else:
					var width := thickness+_inset_at(profile,y-thickness)-outer
					RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x+outer,row_y,width,1),color)
					RenderingServer.canvas_item_add_rect(item,Rect2(area.end.x-outer-width,row_y,width,1),color)
		RenderingServer.canvas_item_add_rect(item,Rect2(area.position.x,area.position.y+zone,thickness,area.size.y-zone*2.0),color)
		RenderingServer.canvas_item_add_rect(item,Rect2(area.end.x-thickness,area.position.y+zone,thickness,area.size.y-zone*2.0),color)

## Trim for a menu signboard: a striped stall awning draped over the top rail
## and brass nails pinning the timber frame at its lower corners.
class PixelFrame extends Control:
	const STRIPE := 16.0
	var frame_color := Color("#d9654f")
	var accent_color := Color("#ffc66d")
	func _draw() -> void:
		var w := floorf(size.x)
		var h := floorf(size.y)
		var stripes := int((w-20.0)/STRIPE)
		var left := floorf((w-stripes*STRIPE)*0.5)
		for index in stripes:
			var cloth := frame_color if index%2==0 else TICKET
			var x := left+index*STRIPE
			draw_rect(Rect2(x,0,STRIPE,6),cloth)
			draw_rect(Rect2(x+2,6,STRIPE-4,2),cloth)
			draw_rect(Rect2(x+4,8,STRIPE-8,2),cloth.darkened(0.16))
		for nail in [Vector2(14,h-8),Vector2(w-18,h-8)]:
			draw_rect(Rect2(nail,Vector2(4,4)),accent_color.darkened(0.5))
			draw_rect(Rect2(nail,Vector2(4,2)),accent_color)
			draw_rect(Rect2(nail,Vector2(2,2)),accent_color.lightened(0.5))

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

## Enamel glint drawn over a button face; it follows the button's live state.
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
		if button==null or size.x<24.0 or size.y<24.0 or current_state=="disabled": return
		var style := button.get_theme_stylebox(current_state) as Board
		if style==null or style.kind!=Board.Kind.ENAMEL: return
		var corner := Vector2(style.border_width_left,style.border_width_top+style.sink)
		if current_state=="pressed":
			# A pushed-in face is shaded by its own rim instead of catching light.
			draw_rect(Rect2(corner,Vector2(size.x-style.border_width_left-style.border_width_right,2)),Color(0,0,0,0.2))
			return
		var glint := Color(1,1,1,0.38 if current_state=="hover" else 0.24)
		draw_rect(Rect2(corner+Vector2(6,4),Vector2(8,2)),glint)
		draw_rect(Rect2(corner+Vector2(16,4),Vector2(2,2)),glint)

static var _style_cache := {}

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
	for state in ["normal","hover","pressed","disabled","focus"]:
		result.set_stylebox(state, "Button", role_style("secondary",state))
	result.set_stylebox("panel", "PanelContainer", plaque())
	result.set_color("font_color", "CheckButton", INK)
	result.set_color("font_hover_color", "CheckButton", TEAL)
	var groove := box(Color("#0b222b"), 0)
	groove.content_margin_top=5
	groove.content_margin_bottom=5
	result.set_stylebox("slider", "HSlider", groove)
	var filled := button_box(Color("#2f9a8d"), Color("#0b222b"), 0, Vector2.ZERO)
	filled.set_border_width_all(2)
	filled.corner=1
	result.set_stylebox("grabber_area", "HSlider", filled)
	result.set_stylebox("grabber_area_highlight", "HSlider", filled)
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
	result.set_stylebox("panel","PopupMenu",plaque(FRAME))
	result.set_stylebox("hover","PopupMenu",button_box(Color("#1f6570"),GOLD,0,Vector2.ZERO))
	for ink_key in ["font_color","font_hover_color","font_accelerator_color"]:
		result.set_color(ink_key,"PopupMenu",PAPER)
	result.set_color("font_disabled_color","PopupMenu",Color("#b6c9c9"))
	result.set_constant("v_separation","PopupMenu",16)
	result.set_stylebox("panel","TooltipPanel",plaque(FRAME))
	result.set_color("font_color","TooltipLabel",PAPER)
	return result

## Recessed well: a routed-in area of a board that holds a group of content.
static func box(color: Color, _radius: int) -> Board:
	var style := Board.new()
	style.kind=Board.Kind.WELL
	style.bg_color=DEEP.darkened(0.18) if color.get_luminance()>0.68 else color
	style.set_border_width_all(0)
	style.corner=1
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=9
	style.content_margin_bottom=9
	return style

## Raised enamel button face. `shadow_size` is how far it stands off the board.
static func button_box(color: Color, edge: Color, shadow_size := 2, shadow_offset := Vector2(0, 3)) -> Board:
	var style := Board.new()
	style.bg_color=color
	style.border_color=edge
	var depth := maxi(0, shadow_size)
	style.set_border_width_all(2)
	style.set_border_width(SIDE_BOTTOM, depth + 3)
	style.shadow_color=SHADOW if depth > 0 else Color(0,0,0,0)
	style.shadow_size=depth
	style.shadow_offset=Vector2(0, maxf(shadow_offset.y, 2.0)) if depth > 0 else Vector2.ZERO
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=9
	style.content_margin_bottom=11
	return style

## Fitting-room mirror frame: thick timber, deep lip.
static func fitting_frame(color := FRAME) -> Board:
	var style := signboard(color)
	style.set_border_width_all(6)
	style.set_border_width(SIDE_BOTTOM, 10)
	style.shadow_size=6
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=10
	style.content_margin_bottom=12
	return style

## Brass ring shown around whatever holds keyboard or gamepad focus.
static func focus_outline() -> Board:
	if _style_cache.has("focus"): return _style_cache["focus"]
	var style := Board.new()
	style.kind=Board.Kind.RING
	style.bg_color=Color(0, 0, 0, 0)
	style.border_color=BRASS
	style.set_border_width_all(3)
	style.corner=3
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=7
	style.content_margin_bottom=7
	_style_cache["focus"]=style
	return style

## Page tab: the chosen page's tab is pushed in and trimmed in gold.
static func tab_box(selected: bool) -> Board:
	var style := button_box(DEEP_TEAL if selected else Color("#143944"), GOLD if selected else OUTLINE, 0 if selected else 2)
	style.sink=2 if selected else 0
	style.set_border_width(SIDE_BOTTOM, 4 if selected else 5)
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=10 if selected else 8
	style.content_margin_bottom=7 if selected else 9
	return style

## Shared, read-only button faces for one role and state.
static func role_style(role: String, state: String) -> Board:
	var key := role+"/"+state
	if _style_cache.has(key): return _style_cache[key]
	var style: Board
	if state=="focus":
		style=focus_outline()
	elif state=="disabled":
		style=button_box(Color("#3b4d52"), Color("#22343a"), 0)
		style.gloss=0.0
		style.content_margin_top+=1
		style.content_margin_bottom-=1
	elif role=="tab_selected" or role=="tab_idle":
		style=tab_box(role=="tab_selected")
		if state=="hover": style.bg_color=Color("#226271")
	else:
		var primary := role=="primary"
		var rim := Color("#5a1d15") if primary else OUTLINE
		match state:
			"hover":
				style=button_box(Color("#ba4630") if primary else Color("#267480"), rim, 4, Vector2(0, 5))
				style.sink=-1
				style.content_margin_top-=1
				style.content_margin_bottom+=1
			"pressed":
				style=button_box(Color("#9a3625") if primary else Color("#1a5560"), rim, 0)
				style.set_border_width(SIDE_BOTTOM, 6)
				style.sink=3
				style.content_margin_top+=3
				style.content_margin_bottom-=3
			_:
				style=button_box(Color("#b0402b") if primary else Color("#1f6570"), rim, 3, Vector2(0, 3))
	_style_cache[key]=style
	return style

static func set_button_role(button: Button, role: String) -> void:
	_attach_button_bevel(button)
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state, role_style(role,state))
	for ink_key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(ink_key, PAPER)
	button.add_theme_color_override("font_disabled_color", Color("#e0dfc5"))

## Raised painted tile: the everyday panel that sits on a signboard. Asking for
## the board's own deepest paint gives a slot cut into the board instead.
static func plaque(color := PAPER) -> Board:
	var style := Board.new()
	style.bg_color=FRAME if color.get_luminance()>0.68 else color
	style.border_color=OUTLINE
	style.set_border_width_all(2)
	style.set_border_width(SIDE_BOTTOM, 5)
	style.gloss=0.09
	if color==DEEP:
		style.kind=Board.Kind.WELL
		style.bg_color=DEEP.darkened(0.22)
	else:
		style.shadow_color=SHADOW
		style.shadow_size=3
		style.shadow_offset=Vector2(0,3)
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style

## Timber-framed painted signboard: the outer shell of a menu, dialogue or HUD plate.
static func signboard(color := PAPER, frame := WOOD) -> Board:
	var style := plaque(FRAME)
	style.kind=Board.Kind.FRAMED
	style.bg_color=DEEP if color.get_luminance()>0.68 else color
	style.border_color=frame
	style.set_border_width_all(6)
	style.set_border_width(SIDE_BOTTOM, 10)
	style.corner=3
	style.shadow_size=4
	style.shadow_offset=Vector2(0,5)
	# Same total height as a plaque, shifted down by the lip under the frame.
	style.content_margin_top=10
	style.content_margin_bottom=14
	return style

## Compact signboard for plates that float over the scene (HUD titles, hints).
static func nameplate(color := FRAME, frame := WOOD) -> Board:
	var style := signboard(color, frame)
	style.set_border_width_all(6)
	style.set_border_width(SIDE_BOTTOM, 9)
	style.corner=2
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=10
	style.content_margin_bottom=13
	return style

## 8 x 8 pixel icons a Board can carry on its face.
const GLYPHS := {
	"score": ["........", "##.#####", "........", "##.#####", "........", "##.#####", "........", "........"],
	"help": ["..####..", ".##..##.", ".....##.", "....##..", "...##...", "........", "...##...", "........"],
	"pause": ["........", ".##..##.", ".##..##.", ".##..##.", ".##..##.", ".##..##.", ".##..##.", "........"],
}

## Cream voyage-ticket paper with a tear line; text on it uses TICKET_INK.
static func ticket(perforation := 0.0) -> Board:
	var style := Board.new()
	style.kind=Board.Kind.PAPER
	style.bg_color=TICKET
	style.border_color=Color("#b9a67c")
	style.set_border_width_all(0)
	style.set_border_width(SIDE_BOTTOM, 3)
	style.perforation=perforation
	style.shadow_color=SHADOW
	style.shadow_size=3
	style.shadow_offset=Vector2(0,3)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=6
	style.content_margin_bottom=9
	return style

## Small brass plate behind a value that should catch the eye; mount it on a
## ticket through `plate` and `plate_rect`.
static func badge() -> Board:
	var style := button_box(Color("#e9b65a"), Color("#7a4b1c"), 0)
	style.set_border_width(SIDE_BOTTOM, 4)
	style.gloss=0.3
	return style

## Root calls this when the saved accessibility option changes. Paper depth itself is static;
## callers can consult reduced_motion() before adding any optional transition.
static func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion=enabled
	PaperMotion.set_reduced(enabled)

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
	panel.add_theme_stylebox_override("panel", box(DEEP.darkened(0.18), 0))
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
	PaperMotion.attach_button(button)

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
