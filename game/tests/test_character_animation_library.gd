extends SceneTree

const Library = preload("res://game/world/character_animation_library.gd")

func _initialize() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(), "animation library checks require an isolated SNAPLAND_SAVE_PATH")
	var source := "user://animation-test-source.png"
	var layer := "user://animation-test-layer.png"
	var base_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	base_image.fill(Color.RED)
	assert(base_image.save_png(source) == OK)
	var variant_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	variant_image.fill(Color.GREEN)
	var variant_source := "user://animation-test-variant.png"
	assert(variant_image.save_png(variant_source) == OK)
	var layer_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	layer_image.fill(Color.BLUE)
	assert(layer_image.save_png(layer) == OK)
	var manifest_path := "user://animation-test-manifest.json"
	var fixture := {
		"schema_version": 1,
		"outfit_modes": {"outfit-tide": "palette"},
		"actors": {"traveller": {"canvas_size": [12,8], "reference_size": [4,4], "feet_baseline": 6, "wave": {"front": {"fps": 2, "loop": true, "frames": [
			{"source": source, "region": [0,0,4,4], "anchors": {"feet": [1,3], "head": [2,0]}, "variants": {"outfit-coral": {"source": variant_source, "region": [0,0,4,4], "anchors": {"feet": [2,2], "head": [0,1]}}}, "layers": [
				{"slot":"shirt", "source":layer, "region":[0,0,2,2], "offset":[1,1], "z":5, "equipped":{"outfit":"outfit-tide"}},
				{"slot":"badge", "source":layer, "region":[0,0,1,1], "offset":[2,0], "z":4},
				{"slot":"hair", "source":layer, "region":[0,0,2,2], "offset":[0,0], "z":-1}]},
			{"source": source, "region": [0,0,4,4], "anchors": {"feet": [1,3]}, "variants": {"outfit-coral": {"source": variant_source, "region": [3,3,4,4], "anchors": {"feet": [2,2]}}}, "layers": []},
			{"source": source, "region": [3,3,4,4], "layers": []},
			{"source": source, "region": [0,0,4,4], "layers": ["malformed"]},
			{"source": source, "region": [0,0,4,4], "anchors": ["malformed"], "layers": []}
		]}},
		"scaled": {"front": {"fps": 1, "loop": true, "frames": [
			{"source":source,"region":[0,0,4,4],"anchors":{"feet":[1,3]},"source_scale":0.5,"layers":[]},
			{"source":source,"region":[0,0,2,4],"anchors":{"feet":[1,3]},"source_scale":0.5,"layers":[]},
			{"source":source,"region":[0,0,4,4],"anchors":{"feet":[1,3]},"source_scale":4.1,"layers":[]},
			{"source":source,"region":[0,0,4,4],"anchors":{"feet":[1,3]},"source_scale":"corrupt","layers":[]}
		]}}
		}
	}
	}
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var library = Library.new(manifest_path)
	assert(library.has_action("traveller", "wave", "front"), "valid action direction is reported as available")
	assert(library.frame_for_time("traveller", "wave", "front", 0.0) == 0, "phase starts at first pose")
	assert(library.frame_for_time("traveller", "wave", "front", 0.5) == 1, "phase advances by authored FPS")
	assert(library.frame_for_time("traveller", "wave", "front", 1.0) == 2 and library.frame_for_time("traveller", "wave", "front", 2.5) == 0, "loop wraps after every authored frame")
	assert(library.frame_for_time("traveller", "wave", "front", 4.0, true) == 0, "reduced motion holds the authored first pose")
	var sequence: Dictionary = library.get_sequence("traveller", "wave", "front", {"outfit":"outfit-tide"})
	assert(sequence.frames.size() == 5 and sequence.frames[0].anchors.feet[0] == 6 and sequence.frames[0].anchors.feet[1] == 6, "sequence retains frame anchors in the shared canvas")
	assert(sequence.frames[0].texture != null, "valid frame and layer regions compose into cached textures")
	var composed: Image = sequence.frames[0].texture.get_image()
	assert(composed.get_pixel(0,0).is_equal_approx(Color.TRANSPARENT) and composed.get_pixel(4,0).is_equal_approx(Color.RED), "feet x anchor keeps the foot center on the shared canvas center")
	assert(composed.get_pixel(6,2).is_equal_approx(Color.BLUE), "equipped clothing layers are selected and draw above the body")
	assert(composed.get_pixel(4,0).is_equal_approx(Color.RED), "negative z hair layer draws behind the body")
	var coral: Texture2D = library.texture("traveller", "wave", "front", 0, {"outfit":"outfit-coral"})
	assert(coral.get_image().get_pixel(8,4).is_equal_approx(Color.RED), "a broken later variant rejects the whole outfit before its first cel")
	var coral_sequence: Dictionary = library.get_sequence("traveller", "wave", "front", {"outfit":"outfit-coral"})
	var source_head: Array = coral_sequence.frames[0].source_anchors.head
	var normalized_head: Array = coral_sequence.frames[0].anchors.head
	assert(is_equal_approx(float(source_head[0]), 2.0) and is_equal_approx(float(source_head[1]), 0.0) and normalized_head == [8,0], "rejected clothing keeps the original body and anchors in every cel")
	assert(coral_sequence.frames[0].texture.get_image().get_pixel(8,0).is_equal_approx(Color.BLUE), "base frame layers remain composed when the outfit is rejected")
	assert(coral_sequence.frames[1].texture.get_image().get_pixel(8,4).is_equal_approx(Color.RED) and library.diagnostics.any(func(item: String) -> bool: return item.contains("traveller/") and item.contains("outfit-coral")), "incomplete coverage diagnoses a specific pose and keeps all valid base bodies")
	assert(sequence.frames[2].texture == null and library.diagnostics.any(func(item: String) -> bool: return item.contains("traveller/wave/front/frame 2")), "out-of-bounds frame reports actor/action/direction/frame context")
	assert(library.texture("traveller", "wave", "front", 3) == null and library.texture("traveller", "wave", "front", 4) == null, "malformed layer and anchor containers fail safely")
	assert(library.normalized_anchor("traveller", "wave", "front", 0, "head", {"outfit":"outfit-tide"}) == Vector2i(8,0), "head anchor uses the layout cached for its selected outfit")
	var scaled_sequence: Dictionary = library.get_sequence("traveller", "scaled", "front")
	var scaled_full_rect: Rect2i = scaled_sequence.frames[0].texture.get_image().get_used_rect()
	var scaled_narrow_rect: Rect2i = scaled_sequence.frames[1].texture.get_image().get_used_rect()
	assert(scaled_sequence.frames[0].texture.get_width() == 12 and scaled_sequence.frames[0].texture.get_height() == 8, "source_scale preserves the actor's canonical output canvas")
	assert(scaled_full_rect.size == Vector2i(4,4) and scaled_narrow_rect.size == Vector2i(2,4), "identical source_scale preserves authored relative frame size without per-frame autozoom")
	assert(library.normalized_anchor("traveller", "scaled", "front", 0, "feet") == Vector2i(6,6), "scaled frame retains the shared canvas feet baseline")
	assert(scaled_sequence.frames[2].texture == null and scaled_sequence.frames[3].texture == null and library.diagnostics.any(func(item: String) -> bool: return item.contains("traveller/scaled/front/frame 2") and item.contains("source_scale")) and library.diagnostics.any(func(item: String) -> bool: return item.contains("traveller/scaled/front/frame 3") and item.contains("source_scale")), "out-of-range and corrupt source_scale values are rejected with frame context")
	assert(library.get_sequence("imp", "dance", "front").frames.is_empty(), "missing direction/action coverage stays explicitly unavailable")
	assert(library.cached_texture_count() <= Library.TEXTURE_CACHE_LIMIT, "composed texture cache has a fixed bound")
	var production_library = Library.new()
	var announcer_right: Dictionary = production_library.get_sequence("announcer", "walk", "right")
	var announcer_left: Dictionary = production_library.get_sequence("announcer", "walk", "left")
	assert(announcer_right.available and announcer_right.frames.size() == 4 and announcer_left.available and announcer_left.frames.size() == 4, "real manifest loads four authored side poses for each profile direction")
	var distinct_right: Dictionary = {}
	var distinct_right_pixels: Dictionary = {}
	for side_frame in announcer_right.frames:
		assert(is_equal_approx(float(side_frame.source_scale), 0.54), "side pose carries the authored uniform source scale")
		assert(production_library.normalized_anchor("announcer", "walk", "right", distinct_right.size(), "feet") == Vector2i(160,448)+production_library._stable_walk_pixels.root_offset("announcer-walk","right",distinct_right.size()), "right-side shoe witness follows root correction without recentering the actor")
		assert(side_frame.texture.get_width() == 320 and side_frame.texture.get_height() == 460, "side pose is normalized to announcer's 320x460 actor canvas")
		distinct_right[JSON.stringify(side_frame.region)] = true
		distinct_right_pixels[Marshalls.raw_to_base64(side_frame.texture.get_image().get_data())] = true
	assert(distinct_right.size() == 4 and distinct_right_pixels.size() == 4, "only four distinct right-side source poses are registered")
	var distinct_left: Dictionary = {}
	var distinct_left_pixels: Dictionary = {}
	for side_frame in announcer_left.frames:
		distinct_left[JSON.stringify(side_frame.region)] = true
		distinct_left_pixels[Marshalls.raw_to_base64(side_frame.texture.get_image().get_data())] = true
	assert(distinct_left.size() == 4 and distinct_left_pixels.size() == 4, "only four distinct left-side source poses are registered")
	var announcer_coverage: Dictionary = production_library.coverage_report().announcer
	assert(announcer_coverage.walk == ["right", "left"] and not production_library.has_action("announcer", "walk", "front"), "manifest coverage reports only right/left; remaining walk directions stay unavailable")
	var jump: Dictionary = production_library.get_sequence("traveller", "jump", "front", {"outfit":"outfit-tide"})
	var coral_jump: Dictionary = production_library.get_sequence("traveller", "jump", "front", {"outfit":"outfit-coral"})
	assert(jump.available and jump.frames.size() == 8 and is_equal_approx(float(jump.fps), 12.0) and not jump.loop, "real jump/front action loads eight authored frames at 12 FPS and does not loop")
	assert(coral_jump.available and coral_jump.frames.size() == 8, "all eight coral jacket jump poses retain the complete base row")
	var jump_regions: Dictionary = {}
	var jump_pixels: Dictionary = {}
	var jump_feet_rows: Dictionary = {}
	var jump_source_scales: Dictionary = {}
	for index in range(jump.frames.size()):
		var jump_frame: Dictionary = jump.frames[index]
		var coral_frame: Dictionary = coral_jump.frames[index]
		assert(Vector2i(jump_frame.texture.get_width(),jump_frame.texture.get_height()) == Vector2i(280,360) and Vector2i(coral_frame.texture.get_width(),coral_frame.texture.get_height()) == Vector2i(280,360), "jump pose %d normalizes to the canonical traveller canvas" % index)
		assert(is_equal_approx(float(jump_frame.source_scale), 0.656), "jump pose %d uses the one documented uniform atlas scale" % index)
		assert(is_equal_approx(float(coral_frame.source_scale), float(jump_frame.source_scale)), "coral jump variant inherits the same scale as its base pose")
		assert(production_library.normalized_anchor("traveller", "jump", "front", index, "feet", {"outfit":"outfit-tide"}) == Vector2i(140,346), "jump pose %d preserves the common atlas-row foot baseline" % index)
		assert(production_library.normalized_anchor("traveller", "jump", "front", index, "feet", {"outfit":"outfit-coral"}) == Vector2i(140,346), "coral jump pose %d preserves the same shared row baseline" % index)
		jump_regions[JSON.stringify(jump_frame.region)] = true
		jump_pixels[Marshalls.raw_to_base64(jump_frame.texture.get_image().get_data())] = true
		jump_feet_rows[JSON.stringify(jump_frame.source_anchors.feet)] = true
		jump_source_scales[JSON.stringify(jump_frame.source_scale)] = true
		assert(jump_frame.source == "res://assets/characters/traveller-jump-front-v1.png" and coral_frame.source == jump_frame.source, "base and coral poses keep the immutable shared jump-atlas source")
		assert(coral_frame.region == jump_frame.region and coral_frame.anchors.head == jump_frame.anchors.head, "palette pose %d keeps the original body source region and anchors" % index)
		assert(coral_frame.texture.get_image().get_data() == jump_frame.texture.get_image().get_data(), "palette pose %d cannot load the historical vest candidate" % index)
	assert(jump_regions.size() == 8 and jump_pixels.size() == 8, "jump action contains eight distinct source regions and composed poses")
	assert(jump_source_scales.size() == 1, "jump action never auto-fits individual frames")
	assert(jump_feet_rows.size() > 1, "authored airborne feet offsets vary while canonical feet placement stays aligned")
	var jump_coverage: Array = production_library.coverage_report().traveller.jump
	assert(jump_coverage == ["front"] and not production_library.has_action("traveller", "jump", "back"), "coverage reports only authored front jump poses")
	print("PASS: character animation library checks")
	quit(0)
