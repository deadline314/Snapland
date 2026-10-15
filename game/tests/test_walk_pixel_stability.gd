extends SceneTree
const Avatar = preload("res://game/world/avatar_renderer.gd")
const Library = preload("res://game/world/character_animation_library.gd")
var failures: Array[String] = []
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
    var avatar = Avatar.new()
    for view in Avatar.WALK_DIRECTIONS:
        var reference: PackedByteArray
        var legs := {}
        for frame in range(avatar.walk_frame_count(view)):
            var image: Image = avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide","hat":"hat-none"},view,frame,"walk").get_image()
            var head: PackedByteArray = _visible_region(image,Rect2i(70,85,150,90))
            if frame==0:reference=head
            elif head!=reference:failures.append("island hero actual head pixels shift: %s/%d" % [view,frame])
            legs[_visible_region(image,Rect2i(0,230,280,130)).hex_encode().hash()]=true
        if legs.size()<4:failures.append("hero walk frozen: "+view)
    # Rest/start/stop use the same registered head as every walking cel.
    for view in Avatar.WALK_DIRECTIONS:
        var rest: Image=avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide","hat":"hat-none"},view,0,"idle").get_image()
        var walk: Image=avatar.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide","hat":"hat-none"},view,0,"walk").get_image()
        if _visible_region(rest,Rect2i(60,65,165,110))!=_visible_region(walk,Rect2i(60,65,165,110)):failures.append("rest/walk head pop: "+view)
    for style in ["bob","curly"]:
        var appearance: Dictionary = Avatar.DEFAULT_APPEARANCE.duplicate()
        appearance.hair=style
        for view in Avatar.WALK_DIRECTIONS:
            var reference: PackedByteArray
            for frame in range(avatar.walk_frame_count(view)):
                var image: Image=avatar.texture(appearance,{"outfit":"outfit-tide","hat":"hat-none"},view,frame,"walk").get_image()
                var head: PackedByteArray=_visible_region(image,Rect2i(70,85,150,90))
                if frame==0:reference=head
                elif head!=reference:failures.append("replacement hair pixels shift: %s/%s/%d" % [style,view,frame])
    if not avatar._missing_head_owner_warnings.is_empty():failures.append("replacement hair silently fell back due to stale head ownership")
    var library = Library.new()
    var original_library = Library.new()
    original_library._stable_walk_pixels.manifest.clear()
    for view in ["left","right"]:
        var reference: PackedByteArray
        var reference_anchor := Vector2i.ZERO
        for frame in range(library.frame_count("announcer","walk",view)):
            var image: Image = library.texture("announcer","walk",view,frame).get_image()
            var spec: Dictionary=library._stable_walk_pixels.manifest["announcer-walk/"+view]
            var raw: Image=original_library.texture("announcer","walk",view,frame).get_image()
            var offset: Array=spec.registration_offsets[frame]
            var expected:=Image.create(320,460,false,Image.FORMAT_RGBA8)
            expected.fill(Color.TRANSPARENT)
            expected.blit_rect(raw,Rect2i(0,0,320,460),Vector2i(offset[0],offset[1]))
            for name in ["feet","hand"]:
                if library.has_anchor("announcer","walk",view,frame,name):
                    var actual_point: Vector2i=library.normalized_anchor("announcer","walk",view,frame,name)
                    var original_point: Vector2i=original_library.normalized_anchor("announcer","walk",view,frame,name)
                    if actual_point-original_point!=Vector2i(offset[0],offset[1]):failures.append("NPC lower attachment lost registration: "+name)
            var seam:=int(spec.head_neck_seam_y)
            var bad_lower:=false
            var bottom:=0
            for y in range(seam,460):
                for x in range(320):
                    var p:=expected.get_pixel(x,y)
                    var q:=image.get_pixel(x,y)
                    if q.a>=0.5:bottom=maxi(bottom,y+1)
                    if p.a!=q.a or (p.a>=0.5 and p!=q):bad_lower=true
            if bad_lower:failures.append("NPC limbs shifted/warped beyond root correction: %s/%d" % [view,frame])
            if bottom!=448:failures.append("NPC shoes left shared ground plane: %s/%d/%d" % [view,frame,bottom])
            var head: PackedByteArray = _visible_region(image,Rect2i(70,140,180,140))
            var anchor: Vector2i = library.normalized_anchor("announcer","walk",view,frame,"head")
            if frame==0:
                reference=head
                reference_anchor=anchor
            elif anchor!=reference_anchor:failures.append("NPC attachment still shifts despite stable image: %s/%d" % [view,frame])
            elif head!=reference:failures.append("NPC actual head pixels shift: %s/%d" % [view,frame])
    if failures.is_empty():print("PASS actual runtime walk pixels: eight hero headings, both NPC sides and nonfrozen limbs")
    else:printerr("FAIL "+"; ".join(failures.slice(0,6)))
    quit(0 if failures.is_empty() else 1)

func _visible_region(image: Image, region: Rect2i) -> PackedByteArray:
    var patch:=image.get_region(region)
    for y in range(patch.get_height()):
        for x in range(patch.get_width()):
            if patch.get_pixel(x,y).a==0.0:patch.set_pixel(x,y,Color.TRANSPARENT)
    return patch.get_data()
