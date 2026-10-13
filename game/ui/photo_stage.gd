extends Control
## Small reversible photo sets, used by quests and discoveries.
## Scene geometry follows the allocated control size; avatar frames are cached once.

var kind := "tail"
var offset := 0.0
var pose := 0
var borrowed := false
var flower_face := 0
var clock := 0.0
var reduced_motion := false
var background: StyleBoxFlat

const INK = Color("#f0f0d8")
const GOLD = Color("#ffc66d")
const CORAL = Color("#f08f73")
const IVORY = Color("#f0f0d8")
const NAVY = Color("#0c2938")
const DEEP = Color("#071b2b")
const FRAME = Color("#31596a")
const MINT = Color("#80e6c2")
const FIELD = Color("#163d4d")
const FLOWER_COLORS := [Color("#f08f73"), Color("#ffc66d"), Color("#80e6c2")]
const FONT = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const CharacterAnimationLibrary = preload("res://game/world/character_animation_library.gd")

var avatar_renderer := AvatarRenderer.new()
var character_animation_library: RefCounted
var avatar_textures: Dictionary = {}
var borrowed_standee_texture: Texture2D
var _last_kind := ""
var _last_offset := 0.0
var _last_pose := -1
var _last_borrowed := false
var _last_flower_face := -1

func _ready() -> void:
	custom_minimum_size=Vector2(0,142)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	background=_background()
	_cache_avatar_textures()
	_cache_draw_state()
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not reduced_motion:
		clock+=delta
		queue_redraw()
	else:
		if _draw_state_changed():
			queue_redraw()

func _draw_state_changed() -> bool:
	if kind==_last_kind and is_equal_approx(offset,_last_offset) and pose==_last_pose and borrowed==_last_borrowed and flower_face==_last_flower_face:
		return false
	_cache_draw_state()
	return true

func _cache_draw_state() -> void:
	_last_kind=kind
	_last_offset=offset
	_last_pose=pose
	_last_borrowed=borrowed
	_last_flower_face=flower_face

func _cache_avatar_textures() -> void:
	avatar_textures.clear()
	for action in ["idle","wave","photograph","interact"]:
		avatar_textures[action]=avatar_renderer.texture(Progress.appearance,Progress.equipped,"front",0,action)
	character_animation_library=CharacterAnimationLibrary.new()
	borrowed_standee_texture=character_animation_library.texture("imp","idle","front",0,{})
	if borrowed_standee_texture==null:
		push_error("PhotoStage: missing borrowed standee texture at actor=imp action=idle direction=front frame=0 (res://assets/characters/complete-animation-regions.json). Drawing the built-in pixel silhouette fallback.")

func _draw() -> void:
	var width := floorf(size.x)
	var height := floorf(size.y)
	if width<80.0 or height<80.0: return
	var pixel := maxf(2.0,floorf(minf(width/96.0,height/32.0)))
	draw_style_box(background,Rect2(0,0,width,height))
	_draw_frame(width,height,pixel)
	_draw_sky(width,height,pixel)
	var floor_y := _snap(height*0.82,pixel)
	_draw_ground(width,height,floor_y,pixel)
	match kind:
		"flower": _draw_flower_scene(width,height,floor_y,pixel)
		"shadow": _draw_shadow_scene(width,height,floor_y,pixel)
		"bench": _draw_bench_scene(width,height,floor_y,pixel)
		"broadcast": _draw_broadcast_scene(width,height,floor_y,pixel)
		_: _draw_tail_scene(width,height,floor_y,pixel)
	var character_action := "photograph" if kind=="tail" else ("interact" if kind=="shadow" else ("wave" if pose==1 else "idle"))
	var hero_height := minf(height*0.68,float(AvatarRenderer.CANVAS_SIZE.y)*0.72)
	var hero_width := hero_height*float(AvatarRenderer.CANVAS_SIZE.x)/float(AvatarRenderer.CANVAS_SIZE.y)
	var hero_x := width*(0.29 if kind!="broadcast" else 0.34)
	var hero_rect := Rect2(hero_x-hero_width*0.5,floor_y-hero_height+pixel,hero_width,hero_height)
	_draw_avatar(character_action,hero_rect)
	if kind=="bench" and borrowed:
		_draw_borrowed_standee(width,floor_y,hero_height,height,pixel)

func _draw_borrowed_standee(width: float,floor_y: float,hero_height: float,height: float,pixel: float) -> void:
	var center_x := width*0.72
	var standee_height := minf(hero_height*0.74,height*0.48)
	if borrowed_standee_texture==null:
		_draw_standee_fallback(center_x,floor_y,standee_height,pixel)
		return
	var source_size: Vector2 = borrowed_standee_texture.get_size()
	if source_size.x<=0.0 or source_size.y<=0.0:
		_draw_standee_fallback(center_x,floor_y,standee_height,pixel)
		return
	var display_width := standee_height*source_size.x/source_size.y
	var destination := Rect2(center_x-display_width*0.5,floor_y-standee_height-pixel*2,display_width,standee_height)
	var frame := Rect2(destination.position.x-pixel*2,destination.position.y-pixel*2,destination.size.x+pixel*4,destination.size.y+pixel*4)
	_block(frame.position.x,frame.position.y,frame.size.x,frame.size.y,FRAME,pixel)
	_block(frame.position.x,frame.position.y,frame.size.x,pixel,GOLD,pixel)
	_block(frame.position.x,frame.position.y,pixel,frame.size.y,GOLD,pixel)
	_block(frame.end.x-pixel,frame.position.y,pixel,frame.size.y,GOLD,pixel)
	_block(frame.position.x,frame.end.y-pixel,frame.size.x,pixel,GOLD,pixel)
	var snapped := Rect2(_snap(destination.position.x,1.0),_snap(destination.position.y,1.0),floorf(destination.size.x),floorf(destination.size.y))
	draw_texture_rect(borrowed_standee_texture,snapped,false)
	_block(center_x-pixel*3,floor_y,pixel*6,pixel*2,DEEP,pixel)
	_block(center_x-pixel*2,floor_y,pixel*4,pixel,GOLD,pixel)

func _draw_standee_fallback(center_x: float,floor_y: float,display_height: float,pixel: float) -> void:
	var unit := maxf(2.0,display_height/18.0)
	var left := center_x-unit*5
	var top := floor_y-display_height-unit*2
	_block(left-unit,top-unit,unit*12,display_height+unit*3,FRAME,pixel)
	_block(left-unit,top-unit,unit*12,unit,GOLD,pixel)
	_block(left-unit,top-unit,unit,display_height+unit*3,GOLD,pixel)
	_block(left+unit*10,top-unit,unit,display_height+unit*3,GOLD,pixel)
	_block(left-unit,floor_y+unit*2,unit*12,unit,GOLD,pixel)
	_block(center_x-unit*2,top+unit*4,unit*4,unit*4,MINT,pixel)
	_block(center_x-unit*3,top+unit*8,unit*6,unit*6,CORAL,pixel)
	_block(center_x-unit*2,top+unit*14,unit*2,unit*2,DEEP,pixel)
	_block(center_x+unit,top+unit*14,unit*2,unit*2,DEEP,pixel)
	_block(center_x-unit,top+unit*5,unit,unit,IVORY,pixel)
	_block(center_x+unit,top+unit*5,unit,unit,IVORY,pixel)
	_block(center_x-unit*2,floor_y+unit*2,unit*4,unit,GOLD,pixel)

func _draw_frame(width: float,height: float,pixel: float) -> void:
	draw_rect(Rect2(pixel,pixel,width-2.0*pixel,height-2.0*pixel),FRAME,false,pixel)
	draw_rect(Rect2(pixel*2.0,pixel*2.0,width-4.0*pixel,height-4.0*pixel),MINT,false,maxf(1.0,pixel*0.5))
	_block(pixel*2,pixel*2,pixel*2,pixel*2,GOLD,pixel)
	_block(width-pixel*4,pixel*2,pixel*2,pixel*2,GOLD,pixel)
	_block(pixel*2,height-pixel*4,pixel*2,pixel*2,GOLD,pixel)
	_block(width-pixel*4,height-pixel*4,pixel*2,pixel*2,GOLD,pixel)

func _draw_sky(width: float,height: float,pixel: float) -> void:
	var top := pixel*3.0
	var bottom := floorf(height*0.78)
	draw_rect(Rect2(top,top,width-top*2.0,bottom-top),Color("#102f41"))
	_block(width*0.16,height*0.24,pixel,pixel,GOLD,pixel)
	_block(width*0.42,height*0.17,pixel,pixel,GOLD,pixel)
	_block(width*0.82,height*0.27,pixel,pixel,GOLD,pixel)
	_block(width*0.67,height*0.39,pixel,pixel,GOLD,pixel)
	_block(width*0.77,height*0.13,pixel*3,pixel*2,MINT,pixel)
	_block(width*0.79,height*0.16,pixel*2,pixel,Color("#102f41"),pixel)
	_block(width*0.13,height*0.35,pixel*4,pixel,FRAME,pixel)
	_block(width*0.16,height*0.32,pixel*2,pixel,MINT,pixel)

func _draw_ground(width: float,height: float,floor_y: float,pixel: float) -> void:
	draw_rect(Rect2(pixel*3.0,floor_y,width-pixel*6.0,height-floor_y-pixel*3.0),FIELD)
	_block(pixel*3.0,floor_y,width-pixel*6.0,pixel*2,MINT,pixel)
	for x in range(int(pixel*4),int(width-pixel*4),int(pixel*5)):
		_block(float(x),floor_y+pixel*3.0,pixel*2,pixel,FRAME,pixel)
	_block(width*0.12,floor_y+pixel*7,width*0.76,pixel*2,DEEP,pixel)
	_block(width*0.14,floor_y+pixel*7,width*0.72,pixel,MINT,pixel)

func _draw_flower_scene(width: float,height: float,floor_y: float,pixel: float) -> void:
	var planter_x := width*0.55
	var planter_width := width*0.37
	var planter_top := floor_y-height*0.18
	_block(planter_x,planter_top,planter_width,pixel*2,GOLD,pixel)
	_block(planter_x+pixel,planter_top+pixel*2,planter_width-pixel*2,height*0.14,Color("#31596a"),pixel)
	_block(planter_x+pixel*2,planter_top+height*0.14+pixel*2,planter_width-pixel*4,pixel*2,FRAME,pixel)
	for index in range(3):
		var center_x := width*(0.62+float(index)*0.13)
		var bloom_y := floor_y-height*(0.37+float(index%2)*0.08)
		var petal: Color = FLOWER_COLORS[index]
		var cell := maxf(2.0,pixel*0.52)
		var outline := petal.darkened(0.34)
		var shade := petal.darkened(0.16)
		var light := petal.lightened(0.20)
		_draw_bloom(center_x,bloom_y,cell,outline,shade,petal,light,flower_face>0 and sin(clock*2.2)>0.85,flower_face==2)
		var stem_top := bloom_y+cell*8.0
		var soil_line := planter_top+height*0.13
		_block(center_x-cell*0.5,stem_top,cell,soil_line-stem_top,MINT,pixel)
		_block(center_x-cell*3.0,stem_top+cell*2.0,cell*2.0,cell*1.2,FRAME,pixel)
		_block(center_x-cell*3.0,stem_top+cell*2.0,cell*1.4,cell*0.7,MINT,pixel)
		_block(center_x+cell,stem_top+cell*3.0,cell*2.0,cell*1.2,FRAME,pixel)
		_block(center_x+cell*1.6,stem_top+cell*3.0,cell*1.4,cell*0.7,MINT,pixel)
	_block(planter_x+pixel*4,planter_top+height*0.07,planter_width-pixel*8,pixel*0.65,GOLD,pixel)
	_block(planter_x+pixel*5,planter_top+height*0.10,pixel*2,pixel*2,MINT,pixel)
	_block(planter_x+planter_width-pixel*7,planter_top+height*0.10,pixel*2,pixel*2,MINT,pixel)

func _draw_bloom(center_x: float,top: float,cell: float,outline: Color,shade: Color,petal: Color,light: Color,blink: bool,cheeky: bool) -> void:
	# Five layered lobes form an outlined, scalloped flower at all panel sizes.
	_block(center_x-cell*4,top,cell*4,cell*4,outline,cell)
	_block(center_x-cell*3,top+cell,cell*4,cell*3,petal,cell)
	_block(center_x-cell*2,top+cell,cell*2,cell,light,cell)
	_block(center_x-cell*10,top+cell*3,cell*4,cell*4,outline,cell)
	_block(center_x-cell*9,top+cell*3,cell*4,cell*3,petal,cell)
	_block(center_x-cell*8,top+cell*4,cell,cell*2,light,cell)
	_block(center_x+cell*6,top+cell*3,cell*4,cell*4,outline,cell)
	_block(center_x+cell*5,top+cell*3,cell*4,cell*3,petal,cell)
	_block(center_x+cell*8,top+cell*4,cell,cell*2,light,cell)
	_block(center_x-cell*7,top+cell*6,cell*4,cell*3,outline,cell)
	_block(center_x-cell*6,top+cell*6,cell*4,cell*2,shade,cell)
	_block(center_x+cell*3,top+cell*6,cell*4,cell*3,outline,cell)
	_block(center_x+cell*3,top+cell*6,cell*4,cell*2,petal,cell)
	_block(center_x-cell*4,top+cell*3,cell*8,cell*5,outline,cell)
	_block(center_x-cell*3,top+cell*3,cell*6,cell*4,light,cell)
	_block(center_x-cell*3,top+cell*4,cell,cell*2,GOLD,cell)
	_block(center_x+cell*2,top+cell*4,cell,cell*2,GOLD,cell)
	if blink:
		_block(center_x-cell*2,top+cell*5,cell*1.5,cell*0.55,outline,cell)
		_block(center_x+cell*0.5,top+cell*5,cell*1.5,cell*0.55,outline,cell)
	else:
		_block(center_x-cell*2,top+cell*4,cell,cell*1.4,IVORY,cell)
		_block(center_x+cell,top+cell*4,cell,cell*1.4,IVORY,cell)
		_block(center_x-cell*1.6,top+cell*4.2,cell*0.55,cell,DEEP,cell)
		_block(center_x+cell*1.4,top+cell*4.2,cell*0.55,cell,DEEP,cell)
	if cheeky:
		_block(center_x-cell*0.35,top+cell*6.1,cell*0.7,cell*0.7,CORAL,cell)
	else:
		_block(center_x-cell,top+cell*6.1,cell*2,cell*0.65,DEEP,cell)

func _draw_shadow_scene(width: float,height: float,floor_y: float,pixel: float) -> void:
	var board := Rect2(width*0.58,height*0.20,width*0.31,height*0.43)
	_block(board.position.x-pixel*2,board.position.y-pixel*2,board.size.x+pixel*4,board.size.y+pixel*4,GOLD,pixel)
	_block(board.position.x,board.position.y,board.size.x,board.size.y,FRAME,pixel)
	_block(board.position.x+pixel*2,board.position.y+pixel*2,board.size.x-pixel*4,board.size.y-pixel*4,Color("#31596a"),pixel)
	var beam_x := clampf(board.position.x+board.size.x*0.5+clampf(offset,-width*0.15,width*0.15),board.position.x+pixel*3,board.end.x-pixel*3)
	draw_line(Vector2(width*0.49,floor_y-pixel*2),Vector2(beam_x,board.position.y+pixel*3),GOLD,pixel,false)
	_block(width*0.45,floor_y-pixel*8,pixel*3,pixel*5,GOLD,pixel)
	_block(width*0.42,floor_y-pixel*2,pixel*9,pixel*2,DEEP,pixel)
	var font_size := maxi(12,mini(26,int(height*0.12)))
	draw_string(FONT,Vector2(board.position.x+pixel*4,board.position.y+board.size.y*0.62),"歡迎",HORIZONTAL_ALIGNMENT_LEFT,board.size.x-pixel*8,font_size,IVORY)

func _draw_bench_scene(width: float,height: float,floor_y: float,pixel: float) -> void:
	var bench_x := width*0.57
	var bench_width := width*0.32
	var seat_y := floor_y-height*0.18
	_block(bench_x,seat_y,bench_width,pixel*3,GOLD,pixel)
	_block(bench_x+pixel,seat_y-pixel*5,bench_width-pixel*2,pixel*3,FRAME,pixel)
	_block(bench_x+pixel*2,seat_y-pixel*4,bench_width-pixel*4,pixel,MINT,pixel)
	_block(bench_x+pixel*2,seat_y+pixel*3,pixel*2,height*0.12,FRAME,pixel)
	_block(bench_x+bench_width-pixel*4,seat_y+pixel*3,pixel*2,height*0.12,FRAME,pixel)
	_block(bench_x-pixel*2,floor_y+pixel*2,bench_width+pixel*4,pixel*2,DEEP,pixel)

func _draw_broadcast_scene(width: float,height: float,floor_y: float,pixel: float) -> void:
	var tower_x := width*0.68
	var mast_top := height*0.20
	_block(tower_x-pixel*2,mast_top,pixel*4,floor_y-mast_top,FRAME,pixel)
	_block(tower_x-width*0.11,floor_y-pixel*9,width*0.22,pixel*9,GOLD,pixel)
	_block(tower_x-width*0.08,floor_y-pixel*7,width*0.16,pixel*5,DEEP,pixel)
	_block(tower_x-pixel*2,mast_top-pixel*2,pixel*4,pixel*3,MINT,pixel)
	var direction := Vector2.UP.rotated(clampf(offset,-1.0,1.0)*PI*0.5)
	var source := Vector2(tower_x,mast_top+pixel*3)
	for wave in range(1,4):
		var radius := pixel*float(4+wave*4)
		var end := source+direction*radius
		draw_line(source,end,GOLD if wave==1 else MINT,pixel,false)
	_block(tower_x-pixel*5,floor_y+pixel*2,pixel*10,pixel*2,DEEP,pixel)

func _draw_tail_scene(width: float,height: float,floor_y: float,pixel: float) -> void:
	var frame := Rect2(width*0.60,height*0.21,width*0.30,height*0.42)
	_block(frame.position.x-pixel*2,frame.position.y-pixel*2,frame.size.x+pixel*4,frame.size.y+pixel*4,GOLD,pixel)
	_block(frame.position.x,frame.position.y,frame.size.x,frame.size.y,FRAME,pixel)
	_block(frame.position.x+pixel*2,frame.position.y+pixel*2,frame.size.x-pixel*4,frame.size.y-pixel*4,DEEP,pixel)
	var tail_x := clampf(frame.position.x+frame.size.x*0.55+clampf(offset,-width*0.16,width*0.16),frame.position.x+pixel*2,frame.end.x-pixel*11)
	var tail_y := frame.position.y+frame.size.y*0.67
	_block(tail_x,tail_y,pixel*5,pixel*3,CORAL,pixel)
	_block(tail_x+pixel*4,tail_y-pixel*2,pixel*3,pixel*3,CORAL,pixel)
	_block(tail_x+pixel*6,tail_y-pixel*4,pixel*3,pixel*3,GOLD,pixel)
	_block(frame.position.x+pixel*4,frame.position.y+pixel*4,pixel*3,pixel*3,MINT,pixel)
	_block(frame.position.x+pixel*8,frame.position.y+pixel*4,pixel*3,pixel*3,GOLD,pixel)

func _draw_avatar(action: String,destination: Rect2,tint := Color.WHITE) -> void:
	var texture: Texture2D=avatar_textures.get(action,avatar_textures.get("idle"))
	if texture==null: return
	var snapped := Rect2(_snap(destination.position.x,1.0),_snap(destination.position.y,1.0),floorf(destination.size.x),floorf(destination.size.y))
	draw_texture_rect(texture,snapped,false,tint)

func _block(x: float,y: float,width: float,height: float,color: Color,pixel: float) -> void:
	var left := _snap(x,pixel)
	var top := _snap(y,pixel)
	var right := _snap(x+width,pixel)
	var bottom := _snap(y+height,pixel)
	draw_rect(Rect2(left,top,maxf(pixel,right-left),maxf(pixel,bottom-top)),color)

func _snap(value: float,pixel: float) -> float:
	return floorf(value/maxf(pixel,1.0))*maxf(pixel,1.0)

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color=NAVY
	box.border_color=FRAME
	box.set_border_width_all(2)
	box.set_corner_radius_all(0)
	box.shadow_size=0
	return box
