extends RefCounted
## Reviewed fixed-root canvases; no runtime color or anatomy inference.
const MANIFEST := "res://assets/characters/walk-stability-v1/manifest.json"
var manifest: Dictionary = {}
var images: Dictionary = {}
func _init(path: String = MANIFEST) -> void:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if value is Dictionary and int(value.get("schema_version",0))==1:
        manifest=value.get("sequences",{})
    else:push_error("Missing or invalid reviewed walk stability manifest")
func frame(actor: String, view: String, index: int) -> Image:
    var key := actor+"/"+view
    if not manifest.has(key):return null
    var spec: Dictionary = manifest[key]
    var count := int(spec.frames)
    if index<0 or index>=count:push_error("Walk stability frame outside reviewed sequence: "+key);return null
    var path := str(spec.source)
    if not images.has(path):
        var texture := load(path) as Texture2D
        if texture==null:push_error("Missing reviewed walk pixels: "+path);return null
        var source := texture.get_image()
        if source.is_compressed():source.decompress()
        source.convert(Image.FORMAT_RGBA8)
        if source.get_size()!=Vector2i(int(spec.canvas[0])*count,int(spec.canvas[1])):
            push_error("Reviewed walk atlas dimensions disagree: "+path);return null
        images[path]=source
    var source: Image=images[path]
    return source.get_region(Rect2i(index*int(spec.canvas[0]),0,int(spec.canvas[0]),int(spec.canvas[1])))

func head_anchor(actor: String, view: String) -> Vector2i:
    var spec: Dictionary = manifest.get(actor+"/"+view,{})
    var point: Array = spec.get("head_anchor",[])
    return Vector2i(int(point[0]),int(point[1])) if point.size()==2 else Vector2i.ZERO

func root_offset(actor: String, view: String, index: int) -> Vector2i:
    var spec: Dictionary=manifest.get(actor+"/"+view,{})
    var offsets: Array=spec.get("registration_offsets",[])
    if index<0 or index>=offsets.size():return Vector2i.ZERO
    return Vector2i(int(offsets[index][0]),int(offsets[index][1]))
