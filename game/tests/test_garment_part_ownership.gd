extends "res://tools/island_avatar/build_garment_layers.gd"
## A sleeve raster tile must never pull neighboring body pixels across its edge.
func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): quit(2);return
	var cel := Image.create(20,20,false,Image.FORMAT_RGBA8)
	cel.fill(Color.MAGENTA)
	var assigned := Rect2i(2,2,11,11)
	for y in range(assigned.position.y,assigned.end.y):
		for x in range(assigned.position.x,assigned.end.x):cel.set_pixel(x,y,Color.GREEN)
	output=Image.create(20,20,false,Image.FORMAT_RGBA8)
	garment_layer=Image.create(20,20,false,Image.FORMAT_RGBA8)
	width_scale=1.0;torso_scale=Vector2.ONE;arm_radius=25.0;draw_clip=Rect2i(0,0,20,20)
	mesh_regions=[assigned,Rect2i(18,18,1,1)];owner_bounds=[[0,20],[18,20]]
	var bones: Array=[Vector2(6,6),Vector2(6,12),Vector2(12,12)]
	_draw_arm(cel,bones,bones,0)
	var green:=0;var neighbor:=0
	for y in 20:
		for x in 20:
			var color:=output.get_pixel(x,y)
			if color==Color.GREEN:green+=1
			if color==Color.MAGENTA:neighbor+=1
	if green!=121 or neighbor!=0:
		push_error("Sleeve pulled neighboring body pixels: owned=%d/121 neighbor=%d"%[green,neighbor]);quit(1);return
	# A source point beyond the sleeve region is still available to the torso,
	# even when it is near the continuation of the arm's bone corridor.
	output.fill(Color.TRANSPARENT);target_root=Vector2.ZERO
	var polygon:=PackedVector2Array([Vector2.ZERO,Vector2(20,0),Vector2(20,20),Vector2(0,20)])
	_draw_torso(cel,polygon,Vector2.ZERO,[bones,bones])
	if output.get_pixel(10,18)!=Color.MAGENTA:
		push_error("Sleeve ownership removed an unassigned torso pixel");quit(1);return
	# A complete separate fabric underlay must remain behind a moving sleeve.
	# The camera-pose sleeve mask must not cut a hole in that independent image.
	mesh_regions=[Rect2i(2,2,11,18),Rect2i(18,18,1,1)]
	var held_arm: Array=[Vector2(6,2),Vector2(6,10),Vector2(6,18)]
	output.fill(Color.TRANSPARENT)
	_draw_torso(cel,polygon,Vector2.ZERO,[held_arm,held_arm])
	if output.get_pixel(6,16).a!=0.0:
		push_error("Shared-source sleeve exclusion counterexample was not exercised");quit(1);return
	output.fill(Color.TRANSPARENT)
	_draw_torso(cel,polygon,Vector2.ZERO,[held_arm,held_arm],true)
	if output.get_pixel(6,16)!=cel.get_pixel(6,16):
		push_error("Independent torso fabric retained a camera-pose sleeve hole");quit(1);return
	output.fill(Color.GREEN);garment_layer.fill(Color.GREEN)
	_restore_spans(cel,[[16,5,7]])
	for x in range(5,8):
		if output.get_pixel(x,16)!=cel.get_pixel(x,16) or garment_layer.get_pixel(x,16).a!=0.0:
			push_error("Sleeveless layer changed an owned original arm pixel");quit(1);return
	if output.get_pixel(8,16)!=Color.GREEN or garment_layer.get_pixel(8,16)!=Color.GREEN:
		push_error("Original arm restoration erased adjacent vest fabric");quit(1);return
	print("PASS: garment sleeves retain 121 owned source pixels, reject adjacent raster tiles and preserve unassigned torso pixels")
	quit()
