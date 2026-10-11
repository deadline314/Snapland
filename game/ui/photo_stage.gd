extends Control
## Small reversible photo sets, used by quests and discoveries.
var kind := "tail"
var offset := 0.0
var pose := 0
var borrowed := false
var flower_face := 0
var clock := 0.0
var reduced_motion := false
var background: StyleBoxFlat
const INK = Color("#294951")
const GOLD = Color("#e9b762")
const CORAL = Color("#d97966")
const CREAM = Color("#f5e7c4")
const FONT = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
func _ready() -> void:
	custom_minimum_size=Vector2(900,155)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	background=_background()
func _process(delta: float) -> void:
	if not reduced_motion: clock+=delta
	queue_redraw()
func _draw() -> void:
	var width := size.x
	draw_style_box(background,Rect2(0,0,width,155))
	match kind:
		"tail":
			draw_rect(Rect2(width*0.55+offset,20,135,108),GOLD)
			draw_circle(Vector2(width*0.55+offset+45,74),25,INK)
			_person(Vector2(width*0.53,100),CORAL,pose)
			draw_arc(Vector2(width*0.53+38,93),30,-PI*0.5,PI*0.4,18,CORAL,7)
			draw_line(Vector2(width*0.55+45,120),Vector2(width*0.55+45,137),INK,2)
		"broadcast":
			draw_circle(Vector2(width*0.43,72),48,INK)
			var direction := Vector2.UP.rotated(offset*PI/2)
			draw_line(Vector2(width*0.43,72)-direction*24,Vector2(width*0.43,72)+direction*25,GOLD,7)
			var tip := Vector2(width*0.43,72)+direction*25
			draw_line(tip,tip-direction.rotated(0.7)*18,GOLD,7)
			draw_line(tip,tip-direction.rotated(-0.7)*18,GOLD,7)
			_person(Vector2(width*0.65,103),CORAL,0)
		"flower":
			for i in range(6):
				var pos := Vector2(width*0.28+i*64,90)
				for j in range(5):
					draw_circle(pos+Vector2.from_angle(j*TAU/5)*17,12,CORAL if i%2==0 else GOLD)
				draw_circle(pos,13,CREAM)
				var blink := sin(clock*2.2)>0.85 and flower_face>0
				if blink:
					draw_line(pos+Vector2(-8,-2),pos+Vector2(-3,-2),INK,2)
					draw_line(pos+Vector2(3,-2),pos+Vector2(8,-2),INK,2)
				else:
					draw_circle(pos+Vector2(-5,-2),2,INK)
					draw_circle(pos+Vector2(5,-2),2,INK)
		"shadow":
			draw_rect(Rect2(width*0.55,20,200,110),INK,false,3)
			draw_rect(Rect2(width*0.55+8+offset,30,184,92),Color("#61857d"))
			draw_string(FONT,Vector2(width*0.55+20+offset,87),"歡迎",HORIZONTAL_ALIGNMENT_LEFT,-1,28,CREAM)
			draw_circle(Vector2(width*0.25,105),18,GOLD)
			draw_line(Vector2(width*0.25,105),Vector2(width*0.55+offset,40),GOLD,2)
		"bench":
			draw_rect(Rect2(width*0.35,98,230,12),GOLD)
			draw_line(Vector2(width*0.37,108),Vector2(width*0.37,142),INK,5)
			draw_line(Vector2(width*0.35+210,108),Vector2(width*0.35+210,142),INK,5)
			_person(Vector2(width*0.40,88),Color("#60aeb3"),pose)
			if borrowed: _person(Vector2(width*0.53,88),CORAL,1)
func _person(pos: Vector2, color: Color, posture: int) -> void:
	draw_circle(pos+Vector2(0,-36),17,CREAM)
	draw_rect(Rect2(pos.x-14,pos.y-20,28,34),color)
	draw_line(pos+Vector2(-10,14),pos+Vector2(-12,28),INK,5)
	draw_line(pos+Vector2(10,14),pos+Vector2(12,28),INK,5)
	draw_line(pos+Vector2(-14,-12),pos+Vector2(-28,-24 if posture==1 else 8),color,6)
	draw_line(pos+Vector2(14,-12),pos+Vector2(28,-24 if posture==1 else 8),color,6)
	draw_circle(pos+Vector2(-6,-39),2,INK)
	draw_circle(pos+Vector2(6,-39),2,INK)
func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color=Color("#e3dcc4")
	box.set_corner_radius_all(10)
	return box
