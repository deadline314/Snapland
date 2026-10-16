extends "res://game/tests/native_island_hair_binding.gd"
## Reuse actual input, but also reject the observed blue coral-jacket sleeve.
func _capture(label: String) -> void:
	await super._capture(label)
	if main.world.facing=="right" and main.world.avatar_equipped.get("outfit","")=="outfit-coral":
		var actual: Image = main.world.avatar.texture.get_image()
		if main.world.avatar_is_walking:
			var expected: Image = main.world.avatar_renderer.texture(main.world.avatar_appearance,main.world.avatar_equipped,"right",main.world.last_avatar_frame,"walk").get_image()
			var body := Rect2i(120,207,40,55)
			if actual.get_region(body).get_data()!=expected.get_region(body).get_data():
				await _fail("native hair viewport changed protected jacket/hand pixels during "+label)
				return
			checks.native_coat_body_pixels=true
		else:
			# This fixed point is cloth in every dedicated idle cel. Some walking
			# cels legitimately move a hand/strap over it, so use the full body there.
			var pixel := actual.get_pixel(135,210)
			if pixel.r<=pixel.b+0.2:
				await _fail("native coral jacket kept a blue sleeve during "+label)
				return
			checks.native_coat_exposed_witness=true
		checks.native_side_coat=true
