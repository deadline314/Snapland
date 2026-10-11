extends Node
const RENDERER=preload('res://game/world/avatar_renderer.gd')
const FONT=preload('res://assets/fonts/NotoSansCJKtc-Regular.otf')
var renderer=RENDERER.new()
var layout:Control
func _ready() -> void:
 call_deferred('_run')
func _run() -> void:
 if DisplayServer.get_name()=='headless' or OS.get_environment('SNAPLAND_SAVE_PATH').is_empty():
  push_error('Gallery requires GPU and isolated profile');get_tree().quit(1);return
 get_window().size=Vector2i(1600,1000)
 for kind in ['hair','hat','face','species']:
  layout=Control.new();add_child(layout)
  var backgrounds=ColorRect.new();backgrounds.color=Color('#eddfb6');backgrounds.size=Vector2(1280,720);layout.add_child(backgrounds)
  var values={'hair':['windswept','bob','curly'],'hat':['hat-straw','hat-sailor','hat-flower'],'face':['curious','confident','smiling'],'species':['human','elf','imp']}[kind]
  for row in range(3):
   for col in range(4):
    var appearance=RENDERER.DEFAULT_APPEARANCE.duplicate()
    var equipment={'outfit':'outfit-tide','hat':'hat-none'}
    if kind=='hat': equipment.hat=values[row]
    else: appearance[kind]=values[row]
    var rect=TextureRect.new();rect.position=Vector2(320*col+65,240*row+26);rect.size=Vector2(190,214);rect.texture=renderer.texture(appearance,equipment,RENDERER.DIRECTIONS[col]);rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;rect.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;layout.add_child(rect)
    var label=Label.new();label.position=Vector2(320*col+15,240*row+4);label.text=str(values[row])+' / '+RENDERER.DIRECTIONS[col];label.add_theme_font_override('font',FONT);label.add_theme_font_size_override('font_size',18);label.add_theme_color_override('font_color',Color('#243b50'));layout.add_child(label)
  await get_tree().create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  var path='res://pm/Snapland-art/images/ART-7-gallery-'+kind+'.png'
  if get_viewport().get_texture().get_image().save_png(path)!=OK: push_error('Gallery capture failed '+path);get_tree().quit(1);return
  remove_child(layout);layout.queue_free()
 if not renderer.is_asset_ready() or not renderer.has_hat_atlas() or not renderer.has_hair_atlas(): push_error('Gallery source fallback used');get_tree().quit(1);return
 print('PASS: native avatar appearance gallery source assets')
 get_tree().quit()
