extends SceneTree
func _initialize() -> void:
 var out := OS.get_environment('SNAPLAND_OUTFIT_AUTHOR_DIR')
 if not out.is_absolute_path() or not OS.get_environment('SNAPLAND_SAVE_PATH').is_absolute_path(): quit(2); return
 DirAccess.make_dir_recursive_absolute(out.path_join('sources'))
 var r = preload('res://game/world/avatar_renderer.gd').new()
 var records: Array = []
 for direction in r.WALK_DIRECTIONS:
  for action in ['walk','idle']:
   var count: int = r.walk_frame_count(direction) if action=='walk' else int(r._stable_idle_pixels.manifest['hero-idle/'+direction].frames)
   for frame in range(count):
    var image: Image = r._walk_pose_image(direction,frame) if action=='walk' else r._stable_idle_pixels.frame('hero-idle',direction,frame)
    records.append(_record(r,image,out,action,direction,frame))
 for action in r.animation_library.coverage_report().traveller:
  if action=='idle':continue
  for direction in r.animation_library.coverage_report().traveller[action]:
   for frame in range(r.authored_frame_count(action,direction)):
    var image: Image=r.animation_library.texture('traveller',action,direction,frame).get_image()
    records.append(_record(r,image,out,action,direction,frame))
 FileAccess.open(out.path_join('sources.json'),FileAccess.WRITE).store_string(JSON.stringify(records,'\t'))
 print('PASS export original palette sources ',records.size())
 quit()
func _record(r: RefCounted,image: Image,out: String,action: String,direction: String,frame: int)->Dictionary:
 var name := '%s-%s-%02d.png'%[action,direction,frame]
 image.save_png(out.path_join('sources').path_join(name))
 var owner:Dictionary=r._head_material_owners.get(r.head_source_signature(image),{})
 if owner.is_empty() and action=='idle':
  owner=r._head_material_owners.get(r.head_source_signature(r._walk_pose_image(direction,0)),{})
 return {'source':name,'action':action,'direction':direction,'frame':frame,'hair_owner_spans':owner.get('hair_owner_spans',[]),'head_owner_available':owner.has('hair_owner_spans')}
