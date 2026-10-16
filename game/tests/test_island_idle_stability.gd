extends SceneTree
const Avatar=preload("res://game/world/avatar_renderer.gd")
var failures: Array[String]=[]
func _initialize() -> void:
 var renderer=Avatar.new()
 var count=0
 for style in ["windswept","bob","curly"]:
  for hat in ["hat-none","hat-straw"]:
   for outfit in ["outfit-tide","outfit-coral"]:
    var look=Avatar.DEFAULT_APPEARANCE.duplicate();look.hair=style
    var equipment={"outfit":outfit,"hat":hat}
    for view in Avatar.WALK_DIRECTIONS:
     var spec: Dictionary=renderer._stable_idle_pixels.manifest["hero-idle/"+view]
     var walk: Image=renderer.texture(look,equipment,view,0,"walk").get_image()
     var neutral: Image=renderer.texture(look,equipment,view,0,"idle").get_image()
     var distinct={}
     var blink_changed=0
     for frame in range(int(spec.frames)):
      var image: Image=renderer.texture(look,equipment,view,frame,"idle").get_image()
      distinct[image.get_data().hex_encode().hash()]=true
      for y in range(int(spec.head_neck_seam_y)):
       for x in range(280):
        var eye=false
        for box in spec.eye_regions:
         if Rect2i(box[0],box[1],box[2],box[3]).has_point(Vector2i(x,y)):eye=true
        var a=image.get_pixel(x,y);var b=walk.get_pixel(x,y)
        if a.a==0 and b.a==0:continue
        if a!=b:
         if eye and frame==int(spec.blink_frame):blink_changed+=1
         else:failures.append("head/cap or non-blink eye shifts: %s/%s/%s/%d" % [style,hat,view,frame]);break
      if _visible_bytes(image.get_region(Rect2i(0,270,280,90)))!=_visible_bytes(neutral.get_region(Rect2i(0,270,280,90))):failures.append("idle planted legs shift: "+view)
      count+=1
     if distinct.size()<2:failures.append("idle frozen: "+view)
     if not spec.eye_regions.is_empty() and blink_changed<3:failures.append("blink invisible: "+view+"/"+style)
 if not failures.is_empty():printerr("FAIL "+str(failures.slice(0,8)));quit(1)
 else:print("PASS stable idle: ",count," composed cels; rigid visible head/cap outside five authored eye regions, moving torso and planted legs");quit()

func _visible_bytes(image: Image) -> PackedByteArray:
 var data=image.get_data()
 for i in range(0,data.size(),4):
  # Imported edge RGB below the island alpha-scissor is invisible; alpha itself remains exact.
  if data[i+3]<102:data[i]=0;data[i+1]=0;data[i+2]=0
 return data
