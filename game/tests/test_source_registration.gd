extends SceneTree
const Rig = preload("res://game/world/avatar_motion_rig.gd")

func _initialize() -> void:
	# A nonzero horizontal shift and an independently shifted palette expose
	# coordinate-space mistakes that today's vertical-only hero shifts cannot.
	var authored := {
		"pelvis":[140,270], "hip_points":[[126,273],[157,278]],
		"boot":[140,300,40,47], "skin_rect":[120,285,5,5],
		"lower":[[120,280,20,15]], "limb_envelopes":[[100,270,80,77]],
		"garment_guards":[[130,270,20,10]], "boot_exclusions":[[140,296,8,21]],
		"hand_guards":[[[100,240],[120,250],[110,260]]],
		"limb_corridors":[[[120,280],[140,300],[130,320]]],
		"opening_spans":[[125,140,273]], "boot_pivot_x":154,
		"limb_garment_max_y":283, "hip_half_width_px":[10,12], "frame":0,
		"boot_asset":"separate-atlas.png", "boot_asset_region":[424,474,391,517],
		"boot_asset_pivot":[619,735], "boot_asset_sole":989, "boot_asset_scale":0.08771929824561403,
		"boot_palette_reference":{"direction":"right","rect":[158,311,66,36]}
	}
	var original := JSON.stringify(authored)
	var shifted := Rig.registered_hero_metadata(authored,Vector2i(7,-3),Vector2i(-4,2))
	assert(shifted.pelvis==[147,267] and shifted.hip_points==[[133,270],[164,275]])
	assert(shifted.boot==[147,297,40,47] and shifted.skin_rect==[127,282,5,5])
	assert(shifted.lower==[[127,277,20,15]] and shifted.limb_envelopes==[[107,267,80,77]])
	assert(shifted.garment_guards==[[137,267,20,10]] and shifted.boot_exclusions==[[147,293,8,21]])
	assert(shifted.hand_guards==[[[107,237],[127,247],[117,257]]])
	assert(shifted.limb_corridors==[[[127,277],[147,297],[137,317]]])
	assert(shifted.opening_spans==[[132,147,270]])
	assert(shifted.boot_pivot_x==161 and shifted.limb_garment_max_y==280)
	assert(shifted.boot_palette_reference.rect==[154,313,66,36],"palette sampling follows its own source")
	for key in ["boot_asset", "boot_asset_region", "boot_asset_pivot", "boot_asset_sole", "boot_asset_scale", "hip_half_width_px", "frame"]:
		assert(shifted[key]==authored[key],"separate-atlas coordinates and dimensions remain unchanged")
	assert(JSON.stringify(authored)==original,"translation cannot mutate the authored metadata")
	assert(JSON.stringify(Rig.registered_hero_metadata(authored,Vector2i(7,-3),Vector2i(-4,2)))==JSON.stringify(shifted),"rebuild uses original coordinates without accumulation")
	assert(JSON.stringify(Rig.registered_hero_metadata(authored,Vector2i.ZERO,Vector2i.ZERO))==original)
	assert(Rig.registered_hero_metadata({},Vector2i(7,-3),Vector2i.ZERO).is_empty())
	print("PASS: body registration, independent palette/boot coordinates and immutable rebuild")
	quit()
