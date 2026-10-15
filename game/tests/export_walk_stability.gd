extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Parts = preload("res://game/world/hero_2d_library.gd")
const Library = preload("res://game/world/character_animation_library.gd")
var records: Array = []
var output := ""
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    output = OS.get_environment("SNAPLAND_WALK_AUDIT_DIR")
    if not output.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
        push_error("Walk pixel export requires isolated absolute paths");quit(2);return
    var avatar = Avatar.new()
    var raw_sources := OS.get_environment("SNAPLAND_WALK_AUDIT_RAW")=="1"
    if raw_sources:
        avatar._stable_walk_pixels.manifest.clear()
        avatar.animation_library._stable_walk_pixels.manifest.clear()
    for view in Avatar.WALK_DIRECTIONS:
        if not raw_sources:
            for idle_frame in range(3):
                _save(avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide","hat":"hat-none"},view,idle_frame,"idle").get_image(),"island-idle",view,idle_frame)
        for frame in range(avatar.walk_frame_count(view)):
            _save(avatar._walk_pose_image(view,frame),"island-raw",view,frame)
            _save(avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide","hat":"hat-none"},view,frame,"walk").get_image(),"island-hero",view,frame)
    var parts = Parts.new()
    for outfit in ["tide_jacket","long_coat"]:
        for hair in ["windswept","bob"]:
            for hat in [false,true]:
                for view in Parts.DIRECTIONS:
                    for frame in range(8):
                        _save(parts.compose_frame({"direction":view,"visual_direction":view,"action":"walk","frame":frame},{"outfit":outfit,"hair_style":hair,"hat_on":hat}),"sample-%s-%s-hat%d" % [outfit,hair,int(hat)],view,frame)
    var library = Library.new()
    if raw_sources:library._stable_walk_pixels.manifest.clear()
    for actor in ["ticket","announcer"]:
        for action in ["walk","walk_candidate"]:
            for view in Parts.DIRECTIONS:
                for frame in range(library.frame_count(actor,action,view)):
                    var texture: Texture2D = library.texture(actor,action,view,frame)
                    if texture!=null:_save(texture.get_image(),"%s-%s" % [actor,action],view,frame)
    var file := FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"scope":"Actual runtime CPU compositor output at a fixed actor root; no camera tracking or positional motion","frames":records},"  "));file.close()
    parts.free()
    print("EXPORTED actual 2D walk compositor frames: ",records.size())
    quit()
func _save(image: Image, family: String, view: String, frame: int) -> void:
    if image==null:push_error("Missing walk image: "+family);quit(1);return
    var name := "%s--%s--%02d.png" % [family,view,frame]
    if image.save_png(output.path_join(name))!=OK:push_error("Could not save "+name);quit(1);return
    records.append({"family":family,"view":view,"frame":frame,"file":name,"size":[image.get_width(),image.get_height()]})
