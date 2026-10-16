extends SceneTree
const Avatar=preload("res://game/world/avatar_renderer.gd")
func _initialize() -> void:
 var folder=OS.get_environment("SNAPLAND_IDLE_OUTPUT")
 if not folder.is_absolute_path():quit(2);return
 var renderer=Avatar.new()
 var output={}
 for view in Avatar.WALK_DIRECTIONS:
  var reference: Image=renderer._walk_pose_image(view,0)
  reference.save_png(folder.path_join(view+"-walk.png"))
  var metrics: Dictionary=renderer._walk_source_hair_metrics(view,0,reference)
  var eyes=renderer._source_eye_regions(reference,metrics.source_bounds)
  var item={"eyes":[],"idle_eyes":[],"count":renderer.animation_library.frame_count("traveller","idle",view),"seam":renderer._stable_walk_pixels.manifest["hero/"+view].head_neck_seam_y}
  for eye in eyes:item.eyes.append([eye.position.x,eye.position.y,eye.size.x,eye.size.y])
  for frame in range(item.count):
   var tex: Texture2D=renderer.animation_library.texture("traveller","idle",view,frame)
   var image=tex.get_image()
   image.save_png(folder.path_join("%s-idle-%d.png" % [view,frame]))
   if frame==0:
    var source_metrics: Dictionary=renderer._authored_source_hair_metrics(image,view,"idle",0)
    for eye in renderer._source_eye_regions(image,source_metrics.source_bounds):item.idle_eyes.append([eye.position.x,eye.position.y,eye.size.x,eye.size.y])
  output[view]=item
 var file=FileAccess.open(folder.path_join("sources.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(output,"  "));file.close()
 print("EXPORTED eight idle sources");quit()
