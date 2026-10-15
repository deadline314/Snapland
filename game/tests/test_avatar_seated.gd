extends SceneTree

const Library = preload("res://game/world/character_animation_library.gd")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const EXPECTED_REGIONS := [
	[200, 75, 291, 541],
	[723, 80, 291, 536],
	[179, 679, 312, 535],
	[723, 678, 291, 536],
]
const EXPECTED_FEET := [[145,539], [144,534], [165,533], [144,534]]
const EXPECTED_HEAD := [[148,2], [151,2], [175,2], [147,2]]
const SOURCE := "res://assets/characters/traveller-seated-front-v1.png"

func _initialize() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(), "seated avatar checks require an isolated SNAPLAND_SAVE_PATH")
	var library := Library.new()
	var sequence: Dictionary = library.get_sequence("traveller", "sit", "front")
	assert(sequence.available and sequence.frames.size() == 4, "only four authored front seated poses load")
	assert(is_equal_approx(float(sequence.fps), 2.0) and not sequence.loop, "seated breath and wave sequence uses a calm two FPS one-shot cadence")
	assert(library.frame_for_time("traveller", "sit", "front", 0.0) == 0 and library.frame_for_time("traveller", "sit", "front", 0.5) == 1, "neutral and breathing poses have a gentle half-second cadence")
	assert(library.frame_for_time("traveller", "sit", "front", 1.0) == 2 and library.frame_for_time("traveller", "sit", "front", 1.5) == 3 and library.frame_for_time("traveller", "sit", "front", 8.0) == 3, "the authored wave and return play once without a fast carousel")
	var distinct_regions: Dictionary = {}
	var distinct_images: Dictionary = {}
	var occupied := Rect2i(Vector2i.ZERO, Vector2i(280, 360))
	for index in range(sequence.frames.size()):
		var frame: Dictionary = sequence.frames[index]
		assert(frame.source == SOURCE, "pose %d uses the approved seated atlas" % index)
		assert(_number_array_matches(frame.region, EXPECTED_REGIONS[index]), "pose %d uses the measured alpha-trimmed rectangle with two-pixel padding" % index)
		assert(_number_array_matches(frame.source_anchors.feet, EXPECTED_FEET[index]), "pose %d uses its measured two-boot contact midpoint" % index)
		assert(_number_array_matches(frame.source_anchors.head, EXPECTED_HEAD[index]), "pose %d retains the upper hair anchor" % index)
		assert(is_equal_approx(float(frame.source_scale), 0.33), "pose %d uses the shared seated source scale" % index)
		assert(library.has_anchor("traveller", "sit", "front", index, "head"), "pose %d has an explicit head attachment anchor" % index)
		var head: Vector2i = library.normalized_anchor("traveller", "sit", "front", index, "head")
		assert(head.x >= 0 and head.x < 280 and head.y >= 0 and head.y < 300, "pose %d normalized hair anchor stays within the actor card" % index)
		var feet: Vector2i = library.normalized_anchor("traveller", "sit", "front", index, "feet")
		assert(feet == Vector2i(140, 346), "pose %d keeps both boots on the shared 346-pixel feet baseline" % index)
		assert(frame.texture != null and Vector2i(frame.texture.get_width(), frame.texture.get_height()) == Vector2i(280, 360), "pose %d composes to the shared traveller card canvas" % index)
		var body_rect: Rect2i = frame.texture.get_image().get_used_rect()
		assert(body_rect.size.x > 0 and body_rect.size.y > 0 and occupied.encloses(body_rect), "pose %d full body stays inside the actor card" % index)
		assert(body_rect.end.y <= 347 and 360 - body_rect.end.y >= 13, "pose %d keeps the rasterized boots within the 13-pixel minimum card guard" % index)
		distinct_regions[JSON.stringify(frame.region)] = true
		distinct_images[Marshalls.raw_to_base64(frame.texture.get_image().get_data())] = true
	assert(distinct_regions.size() == 4 and distinct_images.size() == 4, "all four recorded poses are distinct authored source frames")
	var coverage: Array = library.coverage_report().traveller.sit
	assert(coverage == ["front"] and not library.has_action("traveller", "sit", "back"), "manifest claims seated coverage only for the authored front direction")
	assert(library.frame_count("traveller", "idle", "front") == 8 and library.frame_count("traveller", "jump", "front") == 8 and library.frame_count("traveller", "catch", "front") == 12, "adding the seated action preserves existing traveller front actions")
	var renderer := AvatarRenderer.new()
	# This portion checks retained source-atlas idle, separately from production walk-hold rest.
	renderer.inspect_authored_idle_sources=true
	var appearance := {"skin":"warm", "species":"human", "gender":"neutral", "hair":"windswept", "hair_color":"ink", "face":"curious"}
	var equipped := {"outfit":"outfit-tide", "hat":"hat-none"}
	for action in ["idle","sit"]:
		var action_frame_count: int=renderer.animation_library.frame_count("traveller",action,"front")
		assert(action_frame_count>0,"%s authored front frames are available for source-vs-render hair checks" % action)
		for index in range(action_frame_count):
			var authored: Texture2D=renderer.animation_library.texture("traveller",action,"front",index,equipped)
			var source_image := authored.get_image().duplicate()
			var source_sha256 := _image_sha256(source_image)
			var rendered: Texture2D=renderer.texture(appearance,equipped,"front",index,action)
			var rendered_image := rendered.get_image()
			assert(_image_sha256(authored.get_image())==source_sha256,"%s/%d renderer leaves the immutable cached source texture unchanged" % [action,index])
			var source_metrics: Dictionary=renderer._build_source_hair_metrics(source_image,"front")
			var hair_differences := _source_hair_difference_count(source_image,rendered_image,source_metrics.source_hair_indices)
			var forehead_gaps := _source_hair_alpha_gap_count(source_image,rendered_image,source_metrics.source_hair_indices)
			var upper_head_gaps := _source_upper_head_alpha_gap_count(source_image,rendered_image)
			var head_anchor: Vector2i=renderer.animation_library.normalized_anchor("traveller",action,"front",index,"head",equipped)
			var measured_head_bounds: Rect2i=source_metrics.source_bounds.merge(source_metrics.target_face)
			var head_alpha_changes := _alpha_difference_count(source_image,rendered_image,measured_head_bounds)
			var face_region := Rect2i(head_anchor.x-65,head_anchor.y,130,96)
			var source_face_pixels := _face_skin_pixel_count(source_image,face_region)
			var transparent_face_pixels := _face_alpha_gap_count(source_image,rendered_image,face_region)
			print("AUTHORED HEAD ALPHA: %s/%d opaque upper-pixel gaps=%d measured-head alpha changes=%d (expected 0)" % [action,index,upper_head_gaps,head_alpha_changes])
			assert(source_face_pixels>20,"%s/%d immutable face source provides enough pixels for the measured forehead check" % [action,index])
			assert(source_metrics.source_hair_indices.size()>20,"%s/%d immutable authored source hair provides enough pixels for the alpha-conservation check" % [action,index])
			assert(hair_differences==0,"default windswept %s/%d preserves all authored hair pixels exactly (%d changed)" % [action,index,hair_differences])
			assert(forehead_gaps==0,"default windswept %s/%d leaves no transparent opening in its authored hair (%d gaps)" % [action,index,forehead_gaps])
			assert(upper_head_gaps==0,"default windswept %s/%d keeps every opaque pixel across the authored upper 75%% of the full card (%d alpha gaps)" % [action,index,upper_head_gaps])
			assert(measured_head_bounds.size.x>0 and measured_head_bounds.size.y>0,"%s/%d source hair and face masks provide a nonempty measured head region" % [action,index])
			assert(head_alpha_changes==0,"default windswept %s/%d preserves source alpha throughout the measured hair-and-face bounds (%d changed pixels)" % [action,index,head_alpha_changes])
			assert(transparent_face_pixels==0,"default windswept %s/%d preserves every authored face-skin pixel over the measured forehead (%d alpha gaps)" % [action,index,transparent_face_pixels])
	for index in range(4):
		var rendered: Texture2D = renderer.texture(appearance, equipped, "front", index, "sit")
		assert(rendered != null, "renderer produces seated pose %d" % index)
		var rendered_rect: Rect2i = rendered.get_image().get_used_rect()
		assert(rendered != null and occupied.encloses(rendered_rect) and rendered_rect.end.y <= 347 and 360 - rendered_rect.end.y >= 13, "renderer keeps seated pose %d inside the avatar card with its boot guard" % index)
	print("PASS: four measured front seated poses, head/feet anchors, card bounds, and preserved action coverage")
	quit(0)

func _number_array_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size(): return false
	for index in range(actual.size()):
		if int(actual[index]) != int(expected[index]): return false
	return true

func _image_sha256(image: Image) -> String:
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256)==OK,"SHA-256 context initializes for immutable source verification")
	hashing.update(image.get_data())
	return hashing.finish().hex_encode()

func _source_hair_difference_count(source: Image, rendered: Image, hair_indices: PackedInt32Array) -> int:
	var width := source.get_width()
	var differences := 0
	for index in hair_indices:
		var x := index%width
		var y := index/width
		if source.get_pixel(x,y)!=rendered.get_pixel(x,y): differences+=1
	return differences

func _source_hair_alpha_gap_count(source: Image, rendered: Image, hair_indices: PackedInt32Array) -> int:
	var width := source.get_width()
	var gaps := 0
	for index in hair_indices:
		var x := index%width
		var y := index/width
		if source.get_pixel(x,y).a>0.4 and rendered.get_pixel(x,y).a<0.05: gaps+=1
	return gaps

func _source_upper_head_alpha_gap_count(source: Image, rendered: Image) -> int:
	var gaps := 0
	var upper_head_end := int(floor(float(source.get_height())*0.75))
	for y in range(upper_head_end):
		for x in range(source.get_width()):
			if source.get_pixel(x,y).a>0.4 and rendered.get_pixel(x,y).a<0.05: gaps+=1
	return gaps

func _alpha_difference_count(source: Image, rendered: Image, region: Rect2i) -> int:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO,Vector2i(source.get_width(),source.get_height())))
	var count := 0
	for y in range(clipped.position.y,clipped.end.y):
		for x in range(clipped.position.x,clipped.end.x):
			if (source.get_pixel(x,y).a>0.05)!=(rendered.get_pixel(x,y).a>0.05): count+=1
	return count

func _face_skin_pixel_count(source: Image, region: Rect2i) -> int:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO,Vector2i(source.get_width(),source.get_height())))
	var count := 0
	for y in range(clipped.position.y,clipped.end.y):
		for x in range(clipped.position.x,clipped.end.x):
			if _is_authored_warm_skin(source.get_pixel(x,y)): count+=1
	return count

func _face_alpha_gap_count(source: Image, rendered: Image, region: Rect2i) -> int:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO,Vector2i(source.get_width(),source.get_height())))
	var gaps := 0
	for y in range(clipped.position.y,clipped.end.y):
		for x in range(clipped.position.x,clipped.end.x):
			if _is_authored_warm_skin(source.get_pixel(x,y)) and rendered.get_pixel(x,y).a<0.05: gaps+=1
	return gaps

func _is_authored_warm_skin(color: Color) -> bool:
	var reference := Color("#e8b991")
	var hue_distance := absf(color.h-reference.h)
	return color.a>0.4 and minf(hue_distance,1.0-hue_distance)<0.055 and color.s>0.2 and color.v>0.25
