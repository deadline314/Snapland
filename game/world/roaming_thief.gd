extends Node3D
## A masked thief who turns up every few minutes of free walking, snatches
## something silly just off screen and runs. Get close and press interact to
## catch him; three catches end the arc with a keepsake stamp. If the walker
## falls more than ESCAPE_DISTANCE behind he vanishes in a puff and later waits
## somewhere else on the island (the map shows roughly where).
##
## He belongs to the island world, not a district: he runs across district
## borders on ground the island's walking rules allow and never enters a
## district whose gate is shut. One small set of nodes is made once; while he
## is away they are hidden and only a countdown runs. Talks to main through the
## signals below; tests drive advance() with simulated walker positions.

signal notice_requested(text: String)
signal sfx_requested(kind: String)
signal note_requested(note: int)
## A catch was saved: {"catches", "coins", "rewarded"}.
signal caught(result: Dictionary)
## The third catch's dizzy beat finished: time for the closing scene.
signal arc_finished

const Sprites = preload("res://game/world/thief_sprites.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const ActorShadowSilhouette = preload("res://game/world/actor_shadow_silhouette.gd")
const ProgressScript = preload("res://game/core/progress.gd")

enum State { AWAY, WAITING, CHASE, DODGE, CAUGHT, PUFF }

const SETTING := "roaming_thief"
const POINT_ID := "thief"
const PROMPT := "抓住怪盜"
## About the hero's drawn height (beret included), at the same pixel density.
const HEIGHT := 1.9
## Free (unblocked) seconds before the first and every later appearance.
const FIRST_DELAY := 90.0
const COOLDOWN := 180.0
const RETRY := 6.0
## After an escape he waits this long, then shows up at his hideout.
const RETURN_DELAY := 20.0
const SPAWN_MIN := 19.0
const SPAWN_MAX := 24.0
const HIDEOUT_MIN := 45.0
const NOTICE_RADIUS := 13.0
const CATCH_RADIUS := 2.0
const ESCAPE_DISTANCE := 35.0
## Keeps him off stalls, story points and game stands when he stands still.
const POINT_CLEARANCE := 3.0
const MAP_RADIUS := 12.0
## Speed by gap to the walker (the walker's brisk pace is 1.5 m/s): close he is
## a touch slower, farther he dawdles, far behind he waits and taunts.
const SPEED_CLOSE := 1.3
const SPEED_MID := 1.1
const SPEED_FAR := 0.7
const WAIT_GAP := 16.0
## Every RUN_SPELL seconds of running he stops for PAUSE_SPELL to look back.
const RUN_SPELL := 3.2
const PAUSE_SPELL := 0.9
const REPLAN := 0.25
const DODGE_AFTER := 10.0
const DODGE_RADIUS := 2.6
const DODGE_SPAN := 2.2
const DODGE_SECONDS := 0.35
const STUMBLE_SECONDS := 1.0
const CAUGHT_SECONDS := 1.6
const PUFF_SECONDS := 0.5
const STRIDE_SECONDS := 0.16
const HOP_HEIGHT := 0.12
const TURNS := [0.0, 25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 115.0, -115.0, 150.0, -150.0]
const COMPASS := ["東", "東南", "南", "西南", "西", "西北", "北", "東北"]
const TAUNTS := ["抓不到～", "嘿嘿！", "這邊這邊！", "略略略～", "太慢啦！"]
const LOOT_NAMES := {"balloon": "攤位的氣球", "hat": "假人的帽子", "fish": "碼頭的魚", "lollipop": "棒棒糖招牌"}
const LOOT_SHORT := {"balloon": "氣球", "hat": "帽子", "fish": "魚", "lollipop": "棒棒糖"}
const PLACE_LOOT := {"harbor": "fish", "candy": "lollipop", "circus": "hat", "toy": "hat", "帽子沙灘": "hat", "海風碼頭": "fish"}

var world: Node3D
var state := State.AWAY
var loot := "balloon"
## Free seconds until he next appears (AWAY only).
var countdown := FIRST_DELAY
var catches := 0
var escapes := 0
var dodged := false
## A hideout picked after an escape; INF when he is simply away.
var hideout := Vector3.INF
var hideout_place := ""
var chase_time := 0.0
var sprite: Sprite3D
var shadow: ActorShadowSilhouette
var taunt: Label3D

var _progress: Node
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _beat := 0.0
var _plan := 0.0
var _heading := Vector2.RIGHT
var _dodge_from := Vector3.ZERO
var _dodge_to := Vector3.ZERO
var _last_player := Vector3.INF
var _stride := 0.0
var _taunt_time := 0.0
var _map_jitter := Vector3.ZERO
var _feet_y := 0.0
var _catch_point := {"id": POINT_ID, "label": PROMPT, "position": Vector3.ZERO, "marker": null}


static func attach(owner_world: Node3D) -> Node3D:
	var thief: Node3D = new()
	thief.name = "RoamingThief"
	owner_world.add_child(thief)
	thief.configure(owner_world)
	return thief


func configure(owner_world: Node3D) -> void:
	world = owner_world
	_progress = get_node_or_null("/root/Progress")
	if is_instance_valid(_progress):
		catches = int(_progress.get("thief_catches"))
	_rng.seed = 0x7417 + catches
	var rows := Sprites.visible_rows()
	sprite = Sprite3D.new()
	sprite.name = "ThiefSprite"
	sprite.texture = Sprites.atlas()
	sprite.hframes = Sprites.POSE_COUNT
	sprite.vframes = Sprites.LOOT.size()
	sprite.pixel_size = HEIGHT / float(rows.y - rows.x + 1)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The billboard leans toward the camera: lift its centre so the soles meet the ground.
	var camera_up: float = world.camera.global_basis.y.y if is_instance_valid(world.camera) else 0.84
	_feet_y = (float(rows.y) + 1.0 - Sprites.CELL.y * 0.5) * sprite.pixel_size * camera_up
	sprite.position.y = _feet_y
	add_child(sprite)
	shadow = ActorShadowSilhouette.new()
	shadow.upright = true
	add_child(shadow)
	shadow.configure(sprite, world.camera)
	world._add_contact_shadow(self, Vector3(0, 0.005, 0), Vector2(0.8, 0.45))
	taunt = Label3D.new()
	taunt.name = "ThiefTaunt"
	taunt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	taunt.pixel_size = 0.016
	taunt.font_size = 34
	taunt.outline_size = 10
	taunt.modulate = Color("#fff1d2")
	taunt.outline_modulate = Color("#3b2a44")
	taunt.no_depth_test = true
	taunt.render_priority = 3
	taunt.position.y = HEIGHT + 0.6
	add_child(taunt)
	_go_away()
	countdown = FIRST_DELAY if catches < _goal() else INF


func _goal() -> int:
	return ProgressScript.THIEF_CATCH_GOAL


func _enabled() -> bool:
	if catches >= _goal(): return false
	return not is_instance_valid(_progress) or bool(_progress.settings.get(SETTING, true))


## True while the walker is free to roam: no menu, dialogue, game, ride,
## travel cover, story photo or first-visit prologue.
func is_free() -> bool:
	if not is_instance_valid(world) or world.blocked or not world.is_processing(): return false
	if world.is_riding() or world.staging_photo(): return false
	if is_instance_valid(world.field_games) and world.field_games.is_busy(): return false
	var play: Node = world.get("coastal_play")
	if is_instance_valid(play) and is_instance_valid(play.discoveries) and play.discoveries.controlling: return false
	return not is_instance_valid(_progress) or bool(_progress.intro_seen)


func is_active() -> bool:
	return state != State.AWAY


func _physics_process(delta: float) -> void:
	if not is_instance_valid(world.player): return
	advance(delta, world.player.global_position)
	_offer_catch(world.player.global_position)


## One step of the event; tests call this with a simulated walker position.
func advance(delta: float, player: Vector3) -> void:
	if not is_free(): return
	# Switched off (or the arc is over): he slips away; a catch already under way plays out.
	if not _enabled() and state not in [State.CAUGHT, State.PUFF]:
		hideout = Vector3.INF
		if state == State.AWAY:
			_last_player = player
			return
		_start_puff()
	var velocity := (player - _last_player) / delta if _last_player.is_finite() and delta > 0.0 else Vector3.ZERO
	_last_player = player
	_clock += delta
	match state:
		State.AWAY:
			countdown -= delta
			if countdown <= 0.0:
				if hideout.is_finite(): _appear_at_hideout()
				elif not appear_near(player): countdown = RETRY
		State.WAITING:
			_face(player - position)
			_idle_pose(delta)
			if _gap(player) < NOTICE_RADIUS:
				_begin_chase()
			elif not hideout.is_finite() and _gap(player) > ESCAPE_DISTANCE:
				escape(player)
		State.CHASE:
			_chase(delta, player, velocity)
		State.DODGE:
			_beat += delta
			var t := clampf(_beat / DODGE_SECONDS, 0.0, 1.0)
			_place(_dodge_from.lerp(_dodge_to, t))
			_lift(sin(PI * t) * 0.45)
			if t >= 1.0:
				_lift(0.0)
				state = State.CHASE
				_beat = -STUMBLE_SECONDS
				_say("哇哈！差一點！")
		State.CAUGHT:
			_beat += delta
			if _beat >= CAUGHT_SECONDS:
				if catches >= _goal(): arc_finished.emit()
				_start_puff()
		State.PUFF:
			_beat += delta
			_show_pose(Sprites.PUFF_A if _beat < PUFF_SECONDS * 0.5 else Sprites.PUFF_B)
			if _beat >= PUFF_SECONDS: _go_away()
	if _taunt_time > 0.0:
		_taunt_time -= delta
		if _taunt_time <= 0.0: taunt.visible = false


## Shows up just off screen near the walker with something stolen. False when
## no good spot is found (he tries again a little later).
func appear_near(player: Vector3) -> bool:
	var spot := pick_spawn(player)
	if not spot.is_finite(): return false
	loot = _loot_for(spot)
	dodged = false
	chase_time = 0.0
	hideout = Vector3.INF
	_show_at(spot)
	state = State.WAITING
	sfx_requested.emit("hit")
	note_requested.emit(2)
	notice_requested.emit("怪盜偷走了%s！他在你%s邊，快追！" % [LOOT_NAMES[loot], _compass(spot - player)])
	_say("嘿嘿，到手了！")
	return true


## A walkable spot SPAWN_MIN..SPAWN_MAX from the walker that the camera does
## not show, clear of interaction points and closed districts; INF if none.
func pick_spawn(player: Vector3) -> Vector3:
	for attempt in range(24):
		var angle := _rng.randf() * TAU
		var reach := _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var spot := player + Vector3(cos(angle), 0, sin(angle)) * reach
		if stand_ok(spot) and _clear_of_points(spot) and not on_screen(spot, player):
			return Vector3(spot.x, world.ground_surface_y(spot), spot.z)
	return Vector3.INF


## Ground he may stand or run on: the island's own walking rules, and never a
## district whose sticker gate is still shut.
func stand_ok(spot: Vector3) -> bool:
	var region := DistrictSites.ruling(Vector2(spot.x, spot.z))
	if not region.is_empty() and not (is_instance_valid(world.district_host) and world.district_host.gate_is_open(region)): return false
	return world.is_walkable(spot)


## True when `spot` would be inside the fixed follow camera's view of a walker at `player`.
func on_screen(spot: Vector3, player: Vector3) -> bool:
	var basis: Basis = world.camera.global_basis if is_instance_valid(world.camera) else Basis.looking_at(-world.CAMERA_OFFSET)
	var size: float = world.camera.size if is_instance_valid(world.camera) else 21.0
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var aspect := view.x / maxf(view.y, 1.0)
	var offset := Vector3(spot.x - player.x, 0, spot.z - player.z)
	return absf(offset.dot(basis.x)) < size * 0.5 * aspect + 1.5 and absf(offset.dot(basis.y)) < size * 0.5 + 1.5


## Vanishes in a puff and later waits in another part of the island.
func escape(player: Vector3) -> void:
	escapes += 1
	hideout = pick_hideout(player, place_of(position))
	notice_requested.emit("怪盜溜走了⋯⋯打開地圖看看他躲去哪。" if hideout.is_finite() else "怪盜溜走了⋯⋯")
	sfx_requested.emit("miss")
	_start_puff()


## A spot far from the walker in a different district or named place than
## `leaving`, inside an open district or on island ground; INF if none.
func pick_hideout(player: Vector3, leaving: String) -> Vector3:
	var places: Array[Vector3] = []
	for region: String in DistrictSites.regions():
		if is_instance_valid(world.district_host) and world.district_host.gate_is_open(region):
			places.append(DistrictSites.arrival(region))
	for area: Array in IslandShape.AREAS:
		places.append(Vector3(float(area[1]), 0, float(area[2])))
	var start := _rng.randi() % places.size()
	for index in range(places.size()):
		var centre: Vector3 = places[(start + index) % places.size()]
		if place_of(centre) == leaving or Vector2(centre.x - player.x, centre.z - player.z).length() < HIDEOUT_MIN: continue
		var spot := _settle_near(centre, 8.0)
		if spot.is_finite():
			hideout_place = place_of(spot)
			_map_jitter = Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
			return spot
	return Vector3.INF


## A district id, or the island's named area, for a spot.
static func place_of(spot: Vector3) -> String:
	var at := Vector2(spot.x, spot.z)
	var region := DistrictSites.ruling(at)
	return region if not region.is_empty() else IslandShape.area_at(at)


## Where the map should draw him: {"center", "radius"}, or empty while he is away.
func map_area() -> Dictionary:
	if state in [State.WAITING, State.CHASE, State.DODGE]:
		return {"center": position + _map_jitter, "radius": MAP_RADIUS}
	if hideout.is_finite() and _enabled():
		return {"center": hideout + _map_jitter, "radius": MAP_RADIUS}
	return {}


## The world interaction route. True when the id was his.
func activate(id: String) -> bool:
	if id != POINT_ID: return false
	if is_instance_valid(world.player): try_catch(world.player.global_position)
	return true


func can_catch(player: Vector3) -> bool:
	return state in [State.WAITING, State.CHASE] and _gap(player) <= CATCH_RADIUS


func try_catch(player: Vector3) -> bool:
	if not can_catch(player) or not is_free(): return false
	var result := {"saved": true, "catches": catches + 1, "coins": 0, "rewarded": false}
	if is_instance_valid(_progress):
		result = _progress.record_thief_catch()
	if not bool(result.saved):
		notice_requested.emit("沒有存到，再抓一次試試")
		return false
	catches = int(result.catches)
	state = State.CAUGHT
	_beat = 0.0
	hideout = Vector3.INF
	_lift(0.0)
	_show_pose(Sprites.DIZZY)
	_say("哎呦！被抓到了！")
	sfx_requested.emit("success")
	if is_instance_valid(world): world.play_action("celebrate")
	var line := "抓到怪盜！拿回%s（%d/%d）" % [LOOT_SHORT[loot], catches, _goal()]
	if int(result.coins) > 0: line += " +%d 遊園幣" % int(result.coins)
	notice_requested.emit(line)
	caught.emit(result)
	return true


# --- chase -------------------------------------------------------------------

func _begin_chase() -> void:
	if hideout.is_finite(): notice_requested.emit("找到怪盜了！快抓住他！")
	hideout = Vector3.INF
	state = State.CHASE
	_beat = 0.0
	_plan = 0.0
	_say("來追我呀～")


func _chase(delta: float, player: Vector3, velocity: Vector3) -> void:
	chase_time += delta
	var gap := _gap(player)
	if gap > ESCAPE_DISTANCE:
		escape(player)
		return
	var away := Vector2(position.x - player.x, position.z - player.z)
	if _should_dodge(gap, away, velocity):
		_start_dodge(away)
		return
	_beat += delta
	var resting := _beat < 0.0 or _beat > RUN_SPELL or gap > WAIT_GAP
	if _beat > RUN_SPELL + PAUSE_SPELL: _beat = 0.0
	if resting:
		_face(player - position)
		_show_pose(Sprites.LOOK if gap < WAIT_GAP else Sprites.TAUNT)
		_lift(0.0)
		if _beat > RUN_SPELL and _taunt_time <= 0.0: _say(TAUNTS[_rng.randi() % TAUNTS.size()])
		return
	var speed := SPEED_CLOSE if gap < 4.0 else (SPEED_MID if gap < 10.0 else SPEED_FAR)
	_plan -= delta
	var step := Vector3(_heading.x, 0, _heading.y) * speed * delta
	if _plan <= 0.0 or not stand_ok(position + Vector3(_heading.x, 0, _heading.y) * 1.2):
		_plan = REPLAN
		if not _replan(away):
			# Cornered: he stands his ground and gloats, easy to grab.
			_show_pose(Sprites.TAUNT)
			return
		step = Vector3(_heading.x, 0, _heading.y) * speed * delta
	_place(position + step)
	_face(step)
	_stride += delta
	_show_pose(Sprites.RUN_A if fposmod(_stride, STRIDE_SECONDS * 2.0) < STRIDE_SECONDS else Sprites.RUN_B)
	_lift(0.0 if _reduced() else absf(sin(_stride * PI / STRIDE_SECONDS)) * HOP_HEIGHT)


## Picks the walkable heading closest to straight away from the walker, with a
## little weave so the run reads as cartoonish rather than robotic.
func _replan(away: Vector2) -> bool:
	var base := away.normalized() if away.length_squared() > 0.01 else _heading
	var weave := deg_to_rad(sin(_clock * 1.7) * 15.0)
	for turn: float in TURNS:
		var heading := base.rotated(weave + deg_to_rad(turn))
		var ahead := Vector3(heading.x, 0, heading.y)
		if stand_ok(position + ahead) and stand_ok(position + ahead * 1.8):
			_heading = heading
			return true
	return false


## Once per event, late in the chase, he side-steps a walker charging straight at him.
func _should_dodge(gap: float, away: Vector2, velocity: Vector3) -> bool:
	if dodged or _reduced() or chase_time < DODGE_AFTER or gap > DODGE_RADIUS: return false
	var approach := Vector2(velocity.x, velocity.z)
	return approach.length() > 0.8 and approach.normalized().dot(away.normalized()) > 0.9


func _start_dodge(away: Vector2) -> void:
	var side := away.normalized().orthogonal()
	for sign_value: float in [1.0, -1.0]:
		var target := position + Vector3(side.x, 0, side.y) * DODGE_SPAN * sign_value
		if stand_ok(target):
			dodged = true
			state = State.DODGE
			_beat = 0.0
			_dodge_from = position
			_dodge_to = target
			_show_pose(Sprites.HOP)
			_face(target - position)
			return
	dodged = true


# --- presentation --------------------------------------------------------------

func _appear_at_hideout() -> void:
	var spot := _settle_near(hideout, 8.0)
	if not spot.is_finite(): spot = hideout
	_show_at(spot)
	state = State.WAITING
	dodged = false
	chase_time = 0.0


func _show_at(spot: Vector3) -> void:
	_place(spot)
	_clock = 0.0
	_beat = 0.0
	visible = true
	shadow.set_process(true)
	_show_pose(Sprites.TAUNT)


func _go_away() -> void:
	state = State.AWAY
	visible = false
	taunt.visible = false
	_taunt_time = 0.0
	shadow.set_process(false)
	_lift(0.0)
	if hideout.is_finite(): countdown = RETURN_DELAY
	elif catches >= _goal(): countdown = INF
	else: countdown = COOLDOWN


func _start_puff() -> void:
	state = State.PUFF
	_beat = 0.0
	_lift(0.0)
	taunt.visible = false


func _idle_pose(delta: float) -> void:
	_stride += delta
	var cycle := fposmod(_stride, 2.4)
	_show_pose(Sprites.TAUNT if cycle < 1.2 else Sprites.STAND)
	_lift(0.0 if _reduced() or cycle > 0.5 else sin(cycle / 0.5 * PI) * HOP_HEIGHT * 1.5)


func _show_pose(pose: int) -> void:
	var coords := Vector2i(pose, Sprites.loot_index(loot))
	if sprite.frame_coords != coords: sprite.frame_coords = coords


## Frames face right; flip when `direction` points left on screen.
func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001: return
	var right: Vector3 = world.camera.global_basis.x if is_instance_valid(world.camera) else Vector3.RIGHT
	var flip := direction.dot(right) < 0.0
	if sprite.flip_h != flip: sprite.flip_h = flip


func _place(spot: Vector3) -> void:
	position = Vector3(spot.x, world.ground_surface_y(spot), spot.z)


func _lift(height: float) -> void:
	sprite.position.y = _feet_y + height


func _say(text: String) -> void:
	taunt.text = text
	taunt.visible = true
	_taunt_time = 1.6


func _gap(player: Vector3) -> float:
	return Vector2(position.x - player.x, position.z - player.z).length()


func _reduced() -> bool:
	return bool(world.reduced_motion)


func _clear_of_points(spot: Vector3) -> bool:
	for point: Dictionary in world.points:
		var at: Vector3 = point.position
		if Vector2(at.x - spot.x, at.z - spot.z).length() < POINT_CLEARANCE: return false
	return true


## The nearest spot to `centre` (within `reach`) he may stand on, clear of points.
func _settle_near(centre: Vector3, reach: float) -> Vector3:
	if stand_ok(centre) and _clear_of_points(centre): return Vector3(centre.x, world.ground_surface_y(centre), centre.z)
	for ring in range(1, 5):
		for step in range(8):
			var angle := TAU * step / 8.0 + ring * 0.4
			var spot := centre + Vector3(cos(angle), 0, sin(angle)) * reach * ring / 4.0
			if stand_ok(spot) and _clear_of_points(spot): return Vector3(spot.x, world.ground_surface_y(spot), spot.z)
	return Vector3.INF


func _loot_for(spot: Vector3) -> String:
	var place := place_of(spot)
	if PLACE_LOOT.has(place): return PLACE_LOOT[place]
	return ["balloon", "lollipop", "balloon", "hat"][(catches + escapes) % 4]


## A compass word for an offset on the island map (north is -z).
static func _compass(offset: Vector3) -> String:
	var angle := atan2(offset.z, offset.x)
	return COMPASS[posmod(roundi(angle / (TAU / 8.0)), 8)]


## Offers his catch prompt when he is the closest thing to the walker.
func _offer_catch(player: Vector3) -> void:
	if not can_catch(player) or not is_free(): return
	var gap := _gap(player)
	var current: Dictionary = world.nearest
	if not current.is_empty() and current.get("id", "") != POINT_ID and player.distance_to(current.position) < gap: return
	_catch_point.position = position
	world.nearest = _catch_point
	world._set_interaction_marker(null)
