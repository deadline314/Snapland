extends Node
## Native source-composition contact sheets, not a gameplay or motion verdict.
const Avatar = preload("res://game/world/avatar_renderer.gd")
const PAGE_CAPACITY := 16
const CELL := Vector2i(280, 384)
const LOOKS := [
	{"name":"tide-original", "outfit":"outfit-tide", "hair":"windswept", "hat":"hat-none"},
	{"name":"rainvest-curly-straw", "outfit":"outfit-rainvest", "hair":"curly", "hat":"hat-straw"},
	{"name":"coral-bob-sailor", "outfit":"outfit-coral", "hair":"bob", "hat":"hat-sailor"},
]
var output := ""
var renderer: RefCounted
var sheet: SubViewport
var cells: Control
var observations: Array = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	output = OS.get_environment("SNAPLAND_WARDROBE_POSE_DIR")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		_fail("Native pose review requires native rendering and isolated absolute paths")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create pose evidence directory")
		return
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func(): _fail("Native pose review watchdog"))
	renderer = Avatar.new()
	if not renderer.garment_overlays.ready(renderer):
		_fail("Incomplete garment family")
		return
	var poses: Array = []
	var required: Dictionary = renderer.animation_library.manifest.outfit_required_poses.traveller.duplicate(true)
	var legacy := {}
	for direction in Avatar.WALK_DIRECTIONS: legacy[direction] = 3
	required["celebrate"] = legacy
	for action in required:
		for direction in required[action]:
			for frame in int(required[action][direction]):
				poses.append({"action":action,"direction":direction,"frame":frame})
	if poses.size() != 172:
		_fail("Unexpected coverage; review the pose matrix")
		return
	sheet = SubViewport.new()
	sheet.size = Vector2i(CELL.x * 4, CELL.y * 4)
	sheet.disable_3d=true
	sheet.world_2d=World2D.new()
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("#354354")
	background.size = Vector2(sheet.size)
	sheet.add_child(background)
	cells = Control.new()
	sheet.add_child(cells)
	var preview := TextureRect.new()
	preview.texture = sheet.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(525, 720)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(preview)
	for look in LOOKS:
		var appearance: Dictionary = Avatar.DEFAULT_APPEARANCE.duplicate()
		appearance.hair = look.hair
		var equipment := {"outfit":look.outfit,"hat":look.hat}
		for start in range(0, poses.size(), PAGE_CAPACITY):
			for child in cells.get_children():
				cells.remove_child(child)
				child.queue_free()
			for index in range(start, mini(start + PAGE_CAPACITY, poses.size())):
				var pose: Dictionary = poses[index]
				var texture: Texture2D = renderer.texture(appearance,equipment,pose.direction,pose.frame,pose.action)
				if texture == null or texture.get_size() != Vector2(Avatar.CANVAS_SIZE):
					_fail("Invalid complete pose: %s %s" % [look.name,pose])
					return
				var position := Vector2((index-start)%4*CELL.x, (index-start)/4*CELL.y)
				var label := Label.new()
				label.text = "%s / %s / %02d" % [pose.action,pose.direction,pose.frame]
				label.position = position
				label.add_theme_font_size_override("font_size",16)
				cells.add_child(label)
				var image := TextureRect.new()
				image.texture = texture
				image.position = position + Vector2(0,24)
				image.size = Vector2(Avatar.CANVAS_SIZE)
				image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				cells.add_child(image)
				observations.append({"look":look.name,"pose":pose,"sheet":"%s-%02d.png" % [look.name,start/PAGE_CAPACITY],"texture_sha256":renderer.head_source_signature(texture.get_image())})
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			# A just-created TextureRect may queue its first redraw after the
			# current viewport submission. Capture a complete subsequent draw.
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := output.path_join("%s-%02d.png" % [look.name,start/PAGE_CAPACITY])
			var pixels := sheet.get_texture().get_image()
			for index in range(mini(PAGE_CAPACITY,poses.size()-start)):
				var visible_samples := 0
				var origin := Vector2i(index%4*CELL.x,index/4*CELL.y+24)
				for y in range(0,360,4):
					for x in range(0,280,4):
						var color := pixels.get_pixelv(origin+Vector2i(x,y))
						var backdrop_color := Color("#354354")
						if absf(color.r-backdrop_color.r)+absf(color.g-backdrop_color.g)+absf(color.b-backdrop_color.b)>0.12: visible_samples+=1
				if visible_samples<200:
					_fail("Native sheet contains an empty or incomplete body cell: %s/%d (%d samples)" % [look.name,start+index,visible_samples])
					return
			if pixels.save_png(path) != OK:
				_fail("Cannot save native sheet")
				return
	var result := {"technical_status":"PASS","scope":"Native 1:1 source-composition sheets; not gameplay, motion quality, listening or human review.","source_poses":poses.size(),"looks":LOOKS,"observations":observations,"canvas":sheet.size,"garment_decoded_cache":renderer.garment_overlays._layers.size(),"avatar_texture_cache":renderer.cached_texture_count()}
	var file := FileAccess.open(output.path_join("audit.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save native audit")
		return
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("PASS: native wardrobe pose sheets ",observations.size()," compositions; visual review pending")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
