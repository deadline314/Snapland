extends Node3D
## Small unscored things to poke on the map. Each answers with a visible
## reaction and keeps scene memory only: no score, reward or save data.
## A toy is one registry row; its `kind` picks the builder and reaction below,
## or a script toys/<kind>.gd (see field_toy.gd) for kinds the districts use.

const Kit = preload("res://game/world/field/field_kit.gd")
const Registry = preload("res://game/world/field/field_registry.gd")

const COOLDOWN := 0.35
const GRAVITY := 9.8
const STONE_REST := Color("#9a927e")
const STONE_LIT := Color("#f2c75a")
const DOVE_SIZE := 1.8
const PALM_REACH := 2.0
const TOY_SCRIPTS := "res://game/world/field/toys/%s.gd"

var world: Node3D
var field: Node3D
## One entry per toy; fields beyond id/kind/ground/t belong to the kind.
var items: Array[Dictionary] = []


## `owner` lists the interaction points in its own coordinates: the island,
## or the district these toys belong to.
func configure(owner_world: Node3D, owner_field: Node3D, rows: Array, owner: Node3D = null) -> void:
	world = owner_world
	field = owner_field
	if owner == null:
		owner = world
	for row: Dictionary in rows:
		var at: Vector3 = row.at
		var ground := Vector3(at.x, world.ground_surface_y(at), at.z)
		# `t` counts seconds since the last poke; large means "at rest".
		var item := {"id": Registry.point_id(row, true), "kind": String(row.kind), "row": row, "ground": ground, "t": 99.0, "pokes": 0}
		match item.kind:
			"palm": _build_palm(item)
			"swing": _build_swing(item)
			"chime": _build_chime(item)
			"geyser": _build_geyser(item)
			"stones": _build_stones(item)
			"bench": _build_bench(item)
			_:
				if not _build_scripted(item):
					push_warning("Field toy kind '%s' is not defined; the row was skipped." % item.kind)
					continue
		owner._point(item.id, String(row.prompt), owner.to_local(item.ground), float(item.get("marker", 2.2)))
		items.append(item)


func _build_scripted(item: Dictionary) -> bool:
	var path := TOY_SCRIPTS % item.kind
	if not ResourceLoader.exists(path):
		return false
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return false
	var toy: Node3D = script.new()
	toy.name = String(item.kind).to_pascal_case()
	add_child(toy)
	toy.setup(world, field, item)
	item["toy"] = toy
	return true


func item_for(id: String) -> Dictionary:
	for item in items:
		if item.id == id:
			return item
	return {}


func activate(id: String) -> bool:
	var item := item_for(id)
	if item.is_empty():
		return false
	_poke(item)
	return true


func _poke(item: Dictionary) -> void:
	if float(item.t) < COOLDOWN:
		return
	item.t = 0.0
	item.pokes = int(item.pokes) + 1
	match item.kind:
		"palm":
			item.fallen = true
			field.note_requested.emit(1)
		"swing":
			item.swing = minf(0.95, float(item.swing) + 0.42)
			field.note_requested.emit(3 if float(item.swing) > 0.9 else 2)
		"chime":
			item.rung = 0
		"geyser":
			field.note_requested.emit(2)
			field.feedback_requested.emit("hit")
			if Vector2(world.player.global_position.x - item.ground.x, world.player.global_position.z - item.ground.z).length() < 0.8:
				field.hop(1.1, 1.0)
		"stones":
			item.demo = 0
		"bench":
			item.resting = true
			field.note_requested.emit(0)
		_:
			item.toy.poke()


func advance(delta: float, player: Vector3) -> void:
	var still: bool = world.reduced_motion
	for item in items:
		item.t = minf(99.0, float(item.t) + delta)
		match item.kind:
			"palm": _advance_palm(item, delta, still)
			"swing": _advance_swing(item, delta, still)
			"chime": _advance_chime(item, still)
			"geyser": _advance_geyser(item, player, still)
			"stones": _advance_stones(item, delta, player, still)
			"bench": _advance_bench(item, delta, player, still)
			_: item.toy.advance(delta, player, still)


# --- Palm: shake it and coconuts drop while sparrows scatter. ---

## The row points at a palm that already grows there; the toy only shakes it.
func _build_palm(item: Dictionary) -> void:
	const HEIGHT := 4.15
	var ground: Vector3 = item.ground
	var sprite := _palm_near(ground)
	if sprite != null:
		ground = Vector3(sprite.position.x, ground.y, sprite.position.z)
		item["ground"] = ground
		item["sprite"] = sprite
		item["rest_x"] = sprite.position.x
	else:
		push_warning("Field toy '%s' found no palm at %s; only the coconuts will move." % [item.id, ground])
	var husk: StandardMaterial3D = world._mat(Color("#6b4a34"))
	item["nuts"] = [Kit.ball(self, Vector3.ZERO, 0.15, husk), Kit.ball(self, Vector3.ZERO, 0.13, husk)]
	item["nut_at"] = PackedVector3Array([ground + Vector3(-0.3, HEIGHT * 0.74, 0.25), ground + Vector3(0.34, HEIGHT * 0.7, 0.3)])
	item["nut_speed"] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	item["fallen"] = false
	item["crown"] = ground + Vector3(0, HEIGHT * 0.8, 0)
	var birds := Kit.SpriteBatch.new(world, 3)
	add_child(birds)
	item["birds"] = birds
	item["marker"] = 2.6
	_advance_palm(item, 0.0, true)


func _palm_near(ground: Vector3) -> Sprite3D:
	var art: Texture2D = world.foliage_textures.get("palm")
	var nearest: Sprite3D = null
	var reach := PALM_REACH
	for node in world.get_children():
		var sprite := node as Sprite3D
		if sprite == null or art == null or sprite.texture != art:
			continue
		var gap := Vector2(sprite.position.x - ground.x, sprite.position.z - ground.z).length()
		if gap < reach:
			reach = gap
			nearest = sprite
	return nearest


func _advance_palm(item: Dictionary, delta: float, still: bool) -> void:
	var t := float(item.t)
	var sprite := item.get("sprite") as Sprite3D
	if sprite != null:
		var shake := 0.0 if still or t > 0.9 else sin(t * 38.0) * 0.07 * (1.0 - t / 0.9)
		sprite.position.x = float(item.rest_x) + shake
	var ground: Vector3 = item.ground
	var nuts: Array = item.nuts
	var homes: PackedVector3Array = item.nut_at
	var speeds: PackedVector3Array = item.nut_speed
	if bool(item.fallen) and t > 6.0:
		item.fallen = false
	for index in range(nuts.size()):
		var nut: MeshInstance3D = nuts[index]
		var floor_y := ground.y + 0.14
		var side := -1.0 if index == 0 else 1.0
		if not bool(item.fallen):
			nut.position = homes[index]
			speeds[index] = Vector3(side * 0.7, 0.0, 0.9)
		elif still:
			nut.position = Vector3(homes[index].x + side * 0.6, floor_y, homes[index].z + 0.9)
		elif nut.position.y > floor_y or speeds[index].y > 0.0:
			var speed := speeds[index]
			speed.y -= GRAVITY * delta
			nut.position += speed * delta
			if nut.position.y <= floor_y:
				nut.position.y = floor_y
				# One lively bounce, then it settles.
				speed = Vector3(speed.x * 0.5, 2.4 if speed.y < -4.0 else 0.0, speed.z * 0.5)
			speeds[index] = speed
	item.nut_speed = speeds
	var birds: Kit.SpriteBatch = item.birds
	var crown: Vector3 = item.crown
	for index in range(3):
		var start := index * 0.08
		if still or t < start or t > 1.6:
			birds.hide_item(index)
			continue
		var along := (t - start) / 1.5
		var heading := Vector3(cos(index * 2.1 + 0.4), 0.55, sin(index * 2.1 + 0.4) * 0.6)
		birds.put(index, crown + heading * (along * 9.0), "sparrow", 2 if fmod(t * 7.0 + index * 0.3, 1.0) < 0.5 else 3, heading.x < 0.0, 1.5 * (1.0 - smoothstep(0.7, 1.0, along)))


# --- Swing: every push adds height until it settles again. ---

func _build_swing(item: Dictionary) -> void:
	var frame := Node3D.new()
	frame.position = item.ground
	# Turned so the seat travels across the screen instead of toward the camera.
	frame.rotation.y = 0.95
	add_child(frame)
	var legs: Array[Vector3] = [Vector3(-1.0, 0, 0), Vector3(1.0, 0, 0)]
	Kit.posts(world, frame, legs, 2.3, Color("#da705c"), 0.1)
	var wood: ShaderMaterial = world._wood_material(Color("#9b7a52"))
	Kit.box(frame, Vector3(0, 2.52, 0), Vector3(2.5, 0.16, 0.18), wood)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 2.46, 0)
	frame.add_child(pivot)
	var rope: StandardMaterial3D = world._mat(Color("#d9c9a3"))
	for side: float in [-0.36, 0.36]:
		Kit.cylinder(pivot, Vector3(side, -0.9, 0), 0.03, 1.8, rope, -1.0, 5)
	Kit.box(pivot, Vector3(0, -1.82, 0), Vector3(0.9, 0.07, 0.32), world._coastal_surface(Kit.TILE_RED_BOARD, 0.8))
	item["pivot"] = pivot
	item["swing"] = 0.0
	item["marker"] = 3.1


func _advance_swing(item: Dictionary, delta: float, still: bool) -> void:
	var pivot: Node3D = item.pivot
	if still:
		# A single held tilt shows the push without continuous motion.
		item.swing = 0.0
		pivot.rotation.x = 0.28 if float(item.t) < 0.8 else 0.0
		return
	item.swing = float(item.swing) * exp(-0.3 * delta)
	if float(item.swing) < 0.01:
		item.swing = 0.0
	pivot.rotation.x = float(item.swing) * sin(float(item.t) * 2.5)


# --- Wishing chime: five tubes ring one after another under a star. ---

func _build_chime(item: Dictionary) -> void:
	var ground: Vector3 = item.ground
	var legs: Array[Vector3] = [ground + Vector3(-0.8, 0, 0), ground + Vector3(0.8, 0, 0)]
	Kit.posts(world, self, legs, 2.1, Color("#f2c75a"), 0.085)
	Kit.box(self, ground + Vector3(0, 2.32, 0), Vector3(2.0, 0.14, 0.16), world._wood_material(Color("#9b7a52")))
	var brass: Material = world._coastal_surface(Kit.TILE_BRASS, 0.5, Color("#ffe9b0"))
	var tubes: Array[MeshInstance3D] = []
	var hooks := PackedVector3Array()
	var lengths := PackedFloat32Array()
	for index in range(5):
		var length := 0.55 + 0.11 * index
		hooks.append(ground + Vector3(-0.5 + 0.25 * index, 2.26, 0))
		lengths.append(length)
		tubes.append(Kit.cylinder(self, Vector3.ZERO, 0.065, length, brass, -1.0, 8))
	item["tubes"] = tubes
	item["hooks"] = hooks
	item["lengths"] = lengths
	item["rung"] = 5
	var star := Kit.label(self, "✦", ground + Vector3(0, 2.75, 0), 40, Color("#ffe9b0"))
	star.visible = false
	item["star"] = star
	item["star_at"] = star.position
	item["marker"] = 3.2
	_advance_chime(item, true)


func _advance_chime(item: Dictionary, still: bool) -> void:
	var t := float(item.t)
	var tubes: Array = item.tubes
	var hooks: PackedVector3Array = item.hooks
	var lengths: PackedFloat32Array = item.lengths
	for index in range(tubes.size()):
		var since := t - index * 0.14
		if int(item.rung) == index and since >= 0.0:
			item.rung = index + 1
			field.note_requested.emit(index % 4)
		var angle := 0.0
		if not still and since >= 0.0 and since < 3.0:
			angle = 0.5 * sin(since * 9.0) * exp(-since * 1.8)
		var tube: MeshInstance3D = tubes[index]
		tube.rotation.z = angle
		tube.position = hooks[index] + Vector3(sin(angle), -cos(angle), 0) * (lengths[index] * 0.5)
	var star: Label3D = item.star
	star.visible = t < 1.4
	if star.visible:
		var rise := 0.0 if still else t / 1.4
		star.position = (item.star_at as Vector3) + Vector3(0, rise * 0.9, 0)
		star.modulate.a = 1.0 if still else 1.0 - smoothstep(0.6, 1.0, rise)


# --- Blow-hole: step on it and the tide shoots up, lifting whoever stands there. ---

func _build_geyser(item: Dictionary) -> void:
	var ground: Vector3 = item.ground
	Kit.cylinder(self, ground + Vector3(0, 0.02, 0), 1.05, 0.04, Kit.sand_material(world), -1.0, 18).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.cylinder(self, ground + Vector3(0, 0.045, 0), 0.3, 0.012, world._mat(Color("#33464c")), -1.0, 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pebble := SphereMesh.new()
	pebble.radius = 0.5
	pebble.height = 1.0
	pebble.radial_segments = 8
	pebble.rings = 4
	var rim: Array[Transform3D] = []
	for index in range(7):
		var angle := TAU * index / 7.0 + sin(index * 1.9) * 0.2
		var size := 0.2 + fposmod(index * 0.37, 0.14)
		rim.append(Transform3D(Basis.from_euler(Vector3(0, index * 1.3, 0)).scaled(Vector3(size * 1.3, size * 0.6, size)), ground + Vector3(cos(angle) * 0.47, 0.06, sin(angle) * 0.47)))
	Kit.batch(self, pebble, rim, world._vertex_color_material("field-pebbles"), [Color("#8f8774"), Color("#a59d86"), Color("#7c8a80")])
	var water := _water_material()
	var column := Kit.cylinder(self, ground, 0.3, 1.0, water, 0.16, 10)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item["column"] = column
	var drop := SphereMesh.new()
	drop.radius = 0.11
	drop.height = 0.22
	drop.radial_segments = 6
	drop.rings = 3
	var drops: Array[Transform3D] = []
	drops.resize(8)
	var spray := Kit.batch(self, drop, drops, water)
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.multimesh.custom_aabb = AABB(ground + Vector3(-3, 0, -3), Vector3(6, 5, 6))
	item["spray"] = spray.multimesh
	item["inside"] = false
	item["marker"] = 1.5
	_advance_geyser(item, Vector3(INF, 0, INF), true)


func _water_material() -> StandardMaterial3D:
	const KEY := "field:water"
	if world.material_cache.has(KEY):
		return world.material_cache[KEY]
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.86, 0.98, 0.97, 0.85)
	water.emission_enabled = true
	water.emission = Color(0.55, 0.8, 0.8)
	water.emission_energy_multiplier = 0.35
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.25
	world.material_cache[KEY] = water
	return water


func _advance_geyser(item: Dictionary, player: Vector3, still: bool) -> void:
	var ground: Vector3 = item.ground
	var inside := Vector2(player.x - ground.x, player.z - ground.z).length() < 0.5
	if inside and not bool(item.inside) and float(item.t) > 2.2:
		_poke(item)
	item.inside = inside
	var t := float(item.t)
	var column: MeshInstance3D = item.column
	var spray: MultiMesh = item.spray
	var height := 0.0
	if t < 1.2:
		height = 1.8 if still else 3.0 * sin(PI * t / 1.2)
	column.visible = height > 0.02
	if column.visible:
		column.scale.y = height
		column.position.y = ground.y + height * 0.5
	for index in range(spray.instance_count):
		var age := t - index * 0.05
		if still or age < 0.0 or age > 1.1:
			spray.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), ground))
			continue
		var angle := index * 0.785
		var out := Vector3(cos(angle), 0, sin(angle)) * (0.9 * age)
		spray.set_instance_transform(index, Transform3D(Basis.IDENTITY, ground + out + Vector3(0, 4.6 * age - 0.5 * GRAVITY * age * age + 0.3, 0)))


# --- Singing stones: each plays a note; all five in a row earn a flourish. ---

func _build_stones(item: Dictionary) -> void:
	var slab := CylinderMesh.new()
	slab.top_radius = 0.4
	slab.bottom_radius = 0.46
	slab.height = 0.1
	slab.radial_segments = 9
	slab.rings = 1
	var spots := PackedVector3Array()
	var transforms: Array[Transform3D] = []
	for offset: Vector2 in item.row.get("layout", []):
		var at: Vector3 = item.ground + Vector3(offset.x, 0, offset.y)
		at.y = world.ground_surface_y(at) + 0.05
		spots.append(at)
		transforms.append(Transform3D(Basis.IDENTITY, at))
	var stones := Kit.batch(self, slab, transforms, world._vertex_color_material("field-stones"), [STONE_REST])
	item["stones"] = stones.multimesh
	item["spots"] = spots
	var lit := PackedFloat32Array()
	lit.resize(spots.size())
	item["lit"] = lit
	item["on"] = -1
	item["next"] = 0
	item["demo"] = spots.size()
	item["streaks"] = 0
	var star := Kit.label(self, "✦", item.ground + Vector3(0, 1.6, 0), 44, STONE_LIT)
	star.visible = false
	item["star"] = star
	item["marker"] = 1.9
	_advance_stones(item, 0.0, Vector3(INF, 0, INF), true)


func _advance_stones(item: Dictionary, delta: float, player: Vector3, still: bool) -> void:
	var spots: PackedVector3Array = item.spots
	var lit: PackedFloat32Array = item.lit
	var stones: MultiMesh = item.stones
	# Pressing interact plays the scale once, so the tune can be heard first.
	while int(item.demo) < spots.size() and float(item.t) >= int(item.demo) * 0.16:
		lit[int(item.demo)] = 0.5
		field.note_requested.emit(int(item.demo) % 4)
		item.demo = int(item.demo) + 1
	var on := -1
	for index in range(spots.size()):
		if Vector2(player.x - spots[index].x, player.z - spots[index].z).length() < 0.44:
			on = index
	if on >= 0 and on != int(item.on):
		lit[on] = 0.6
		field.note_requested.emit(on % 4)
		item.next = int(item.next) + 1 if on == int(item.next) else (1 if on == 0 else 0)
		if int(item.next) == spots.size():
			item.next = 0
			item.streaks = int(item.streaks) + 1
			item.t = 0.0
			for index in range(lit.size()):
				lit[index] = 1.4
			field.feedback_requested.emit("success")
	item.on = on
	for index in range(spots.size()):
		lit[index] = maxf(0.0, lit[index] - delta)
		var glow := 1.0 if lit[index] > 0.0 and still else clampf(lit[index] / 0.5, 0.0, 1.0)
		var dip := 0.035 if index == on else 0.0
		stones.set_instance_transform(index, Transform3D(Basis.IDENTITY, spots[index] - Vector3(0, dip, 0)))
		stones.set_instance_color(index, STONE_REST.lerp(STONE_LIT, glow))
	item.lit = lit
	var star: Label3D = item.star
	star.visible = int(item.streaks) > 0 and float(item.t) < 1.4 and int(item.demo) >= spots.size()


# --- Bench: stay a moment and the doves come to keep you company. ---

func _build_bench(item: Dictionary) -> void:
	world._bench(item.ground)
	var birds := Kit.SpriteBatch.new(world, 4)
	add_child(birds)
	for index in range(4):
		birds.tint(index, Color(1.32, 1.24, 1.14) if index % 2 == 0 else Color(1.0, 0.96, 0.9))
	item["birds"] = birds
	item["resting"] = false
	# Seconds since the visitor walked off, and how long they had stayed.
	item["gone"] = 99.0
	item["stayed"] = 0.0
	item["marker"] = 2.3
	_advance_bench(item, 0.0, Vector3(INF, 0, INF), true)


func _advance_bench(item: Dictionary, delta: float, player: Vector3, still: bool) -> void:
	var ground: Vector3 = item.ground
	var t := float(item.t)
	if bool(item.resting) and Vector2(player.x - ground.x, player.z - ground.z).length() > 2.8:
		item.resting = false
		item.gone = 0.0
		item.stayed = t
	elif not bool(item.resting):
		item.gone = minf(99.0, float(item.gone) + delta)
	var birds: Kit.SpriteBatch = item.birds
	var left := float(item.gone)
	for index in range(4):
		var landing := ground + Vector3(-1.5 + index * 1.0, 0.0, 1.1 + 0.35 * sin(index * 2.3))
		var away := landing + Vector3(7.0 - index * 1.5, 5.5, -9.0)
		var arrive := 0.5 + index * 0.6
		if bool(item.resting):
			if t < arrive or (still and t < 0.3):
				birds.hide_item(index)
			elif still or t > arrive + 1.3:
				birds.put(index, landing, "pigeon", 1 if not still and fmod(t * 1.3 + index * 0.4, 1.6) < 0.35 else 0, index % 2 == 0, DOVE_SIZE)
			else:
				var glide := smoothstep(0.0, 1.0, (t - arrive) / 1.3)
				birds.put(index, away.lerp(landing, glide), "pigeon", 2 if fmod(t * 6.0, 1.0) < 0.5 else 3, true, DOVE_SIZE)
		elif still or left > 1.2 or float(item.stayed) < arrive + 1.3:
			birds.hide_item(index)
		else:
			var flee := left / 1.2
			birds.put(index, landing.lerp(away, flee * flee), "pigeon", 2 if fmod(left * 7.0, 1.0) < 0.5 else 3, false, DOVE_SIZE * (1.0 - smoothstep(0.7, 1.0, flee)))
