extends Node3D
## Island wayfinding signposts and the visible results of the two welcome quests.
##
## Everything here reflects saved progress; nothing here grants or changes it.
## Geometry is built through ParkWorld helpers so materials, occlusion and
## component motion stay consistent with the rest of the island.

const Wayfinding = preload("res://game/story/wayfinding.gd")
const SIGN_WOOD := Color("#8a6a48")
const SIGN_PLANK := Color("#d9c49b")
const RIBBON_COLORS: Array[Color] = [Color("#e2795e"), Color("#e2ae4f"), Color("#4f9fa3"), Color("#f2e3c4")]
const ARCH_CENTER := Vector3(0, 0, -11)
const ARCH_HALF_WIDTH := 4.0
const BROADCAST_STAND := Vector3(1.9, 0, -5.7)
const SIGN_READ_DISTANCE := 10.0
const SIGN_SWITCH_MARGIN := 0.5
## The live directions are painted on a board fixed to the post, not floating words.
const BOARD_COLOR := Color("#18383d")
const BOARD_PAD := Vector2(0.34, 0.26)
## Twice the 12 px pixel font, so the glyphs stay on whole pixels.
const SIGN_TEXT_SIZE := 24
## Characters with something for the walker carry a small "!" until it is done.
const REQUEST_ROLES := {"guide": "ticket", "quest-001": "imp", "quest-002": "announcer"}

var wayfinding := Wayfinding.new()
var _status_labels: Dictionary = {}
var _signpost_records: Array[Dictionary] = []
var _ribbon: Node3D
var _entry_sign_before: Node3D
var _entry_sign_after: Node3D
var _outcomes := {"quest-001": false, "quest-002": false}
var _last_signature := ""
var _focused_sign := -1
var _last_sign_position := Vector2.INF
var _world: Node3D
## One board, carried to whichever signpost is being read (the island's node budget is tight).
var _board: MeshInstance3D
## point id -> {"icon": Sprite3D, "wanted": bool}
var _requests: Dictionary = {}

func configure(world: Node3D) -> void:
	name = "StoryLandmarks"
	_world = world
	for signpost: Dictionary in wayfinding.signposts():
		_build_signpost(world, signpost)
	_ribbon = _build_ribbon_garland(world)
	_build_broadcast_stand(world)
	_build_request_icons(world)
	_board = world._box(Vector3.ZERO, Vector3.ONE, BOARD_COLOR)
	_board.name = "SignBoard"
	_board.material_override = world._coastal_surface(6, 0.9, BOARD_COLOR)
	_board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.reparent(self, false)
	_board.hide()
	_apply_outcomes()

## snapshot keys: story_photo, steps, photos (see Wayfinding.entry_status).
func apply_progress(snapshot: Dictionary) -> void:
	var steps: Dictionary = snapshot.get("steps", {})
	var signature := JSON.stringify([snapshot.get("story_photo", false), steps, _game_photo_ids(snapshot.get("photos", {}))])
	if signature == _last_signature:
		return
	_last_signature = signature
	for record in _signpost_records:
		var lines: Array[String] = []
		for entry: Dictionary in record.entries:
			lines.append(Wayfinding.entry_line(entry, snapshot))
		record.lines = lines
		var label := _status_labels.get(record.id) as Label3D
		if is_instance_valid(label):
			label.text = "\n".join(lines)
	if _focused_sign >= 0:
		_seat_board.call_deferred(_status_labels[_signpost_records[_focused_sign].id])
	_outcomes["quest-001"] = int(steps.get("quest-001", 0)) >= Wayfinding.QUEST_STEP_COUNT
	_outcomes["quest-002"] = int(steps.get("quest-002", 0)) >= Wayfinding.QUEST_STEP_COUNT
	_set_request("guide", not bool(snapshot.get("story_photo", false)))
	for quest_id in ["quest-001", "quest-002"]:
		_set_request(quest_id, int(steps.get(quest_id, 0)) <= 0)
	_apply_outcomes()

func outcome_state() -> Dictionary:
	return {
		"ribbon_visible": is_instance_valid(_ribbon) and _ribbon.visible,
		"entry_sign_corrected": is_instance_valid(_entry_sign_after) and _entry_sign_after.visible and not _entry_sign_before.visible,
	}

## Test/review view of every signpost: position and the exact visible lines.
func signpost_report() -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for record in _signpost_records:
		var label := _status_labels.get(record.id) as Label3D
		report.append({"id": record.id, "position": record.position, "lines": (record.lines as Array).duplicate(), "label_text": label.text if is_instance_valid(label) else ""})
	return report

## Physical posts stay visible and solid. Only the nearby sign's status text follows the walker.
func update_signpost_visibility(player_position: Vector3) -> void:
	var at := Vector2(player_position.x, player_position.z)
	if at == _last_sign_position:
		return
	_last_sign_position = at
	_update_request_icons()
	var closest := -1
	var closest_distance := SIGN_READ_DISTANCE
	var focused_distance := INF
	for index in _signpost_records.size():
		var distance := at.distance_to(_signpost_records[index].read_position)
		if index == _focused_sign:
			focused_distance = distance
		if distance <= closest_distance:
			closest = index
			closest_distance = distance
	if closest == _focused_sign:
		return
	if focused_distance <= SIGN_READ_DISTANCE and closest_distance + SIGN_SWITCH_MARGIN >= focused_distance:
		return
	if _focused_sign >= 0:
		var former: Label3D = _status_labels[_signpost_records[_focused_sign].id]
		former.hide()
	_focused_sign = closest
	if closest >= 0:
		var focused: Label3D = _status_labels[_signpost_records[closest].id]
		focused.show()
		# The label lays its text out on the next idle step; measure after it.
		_seat_board.call_deferred(focused)
	else:
		_board.hide()


func _apply_outcomes() -> void:
	if is_instance_valid(_ribbon):
		_ribbon.visible = bool(_outcomes["quest-001"])
	if is_instance_valid(_entry_sign_before) and is_instance_valid(_entry_sign_after):
		_entry_sign_before.visible = not bool(_outcomes["quest-002"])
		_entry_sign_after.visible = bool(_outcomes["quest-002"])

static func _game_photo_ids(photos: Dictionary) -> Array:
	var ids: Array = []
	for photo_id in photos:
		if str(photo_id).begins_with("photo-welcome-game-"):
			ids.append(str(photo_id))
	ids.sort()
	return ids

func _adopt(node: Node3D, parent: Node3D) -> Node3D:
	node.reparent(parent)
	return node

func _group(group_name: String, parent: Node3D = self) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	parent.add_child(group)
	return group

func _build_signpost(world: Node3D, signpost: Dictionary) -> void:
	var id := str(signpost.id)
	var base := Vector3(float(signpost.position[0]), 0, float(signpost.position[1]))
	var root := _group("Signpost_%s" % id)
	var entries: Array = signpost.entries
	# Each physical plank remains in place when the readable status moves to the next post.
	var top := 1.1 + 0.26 * entries.size()
	var post: MeshInstance3D = _adopt(world._cylinder(base + Vector3(0, top * 0.5, 0), 0.09, top, SIGN_WOOD, -1.0, true), root)
	post.material_override = world._coastal_surface(1, 1.2, SIGN_WOOD.lightened(0.1))
	_adopt(world._cylinder(base + Vector3(0, 0.08, 0), 0.32, 0.16, Color("#7c6a52")), root)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var direction := _arrow_vector(str(entry.arrow))
		var plank: MeshInstance3D = _adopt(world._box(base + Vector3(direction.x * 0.38, top - 0.16 - 0.26 * index, direction.y * 0.38), Vector3(0.9, 0.18, 0.06), SIGN_PLANK if index % 2 == 0 else SIGN_PLANK.darkened(0.12)), root)
		plank.material_override = world._coastal_surface(6, 0.9, SIGN_PLANK if index % 2 == 0 else SIGN_PLANK.darkened(0.12))
		plank.rotation.y = -atan2(direction.y, direction.x)
	var board: Label3D = _adopt(world._label("", base + Vector3(0, top + 1.3, 0.1), SIGN_TEXT_SIZE, Color("#fff4d6")), root)
	board.name = "SignText"
	board.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	board.outline_size = 4
	board.line_spacing = 2.0
	board.visibility_range_end = 0.0
	board.set_meta(&"post_top", board.position.y - 1.3)
	board.hide()
	_status_labels[id] = board
	_signpost_records.append({"id": id, "title": str(signpost.get("title", "")), "position": base,
		"read_position": Vector2(base.x, base.z), "entries": entries, "lines": []})

## Hang the shared board behind the sign being read, sized to its text, its
## foot resting on the post top so it never floats.
func _seat_board(label: Label3D) -> void:
	if not is_instance_valid(label) or not label.visible: return
	var text := label.get_aabb().size
	var size := Vector2(text.x, text.y) + BOARD_PAD * 2.0
	label.position.y = float(label.get_meta(&"post_top", label.position.y)) + size.y * 0.5 - 0.08
	if _board.get_parent() != label: _board.reparent(label, false)
	_board.scale = Vector3(size.x, size.y, 0.08)
	_board.position = Vector3(0, 0, -0.06)
	_board.show()

func _build_request_icons(world: Node3D) -> void:
	for point_id: String in REQUEST_ROLES:
		var anchor := world._npc_record_for_role(REQUEST_ROLES[point_id]).get("activity_root") as Node3D
		var point: Dictionary = world._point_by_id(point_id)
		if not is_instance_valid(anchor) or point.is_empty(): continue
		# Placed like the point's own marker: world size, then carried by the actor.
		var icon := Sprite3D.new()
		icon.name = "RequestIcon_" + point_id
		icon.texture = _request_bubble()
		icon.pixel_size = 0.05
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		icon.shaded = false
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.position = point.position + Vector3(0, world.DEFAULT_MARKER_HEIGHT + 0.1, 0)
		world.add_child(icon)
		icon.reparent(anchor, true)
		world.component_motion.register_component(icon, "marker", 1.7 + float(_requests.size()))
		icon.hide()
		_requests[point_id] = {"icon": icon, "wanted": false}

## A 13 x 15 pixel speech bubble with a coral "!": cream face, dark rim, tail
## at the bottom. Built once and shared by every request icon.
static var _bubble: ImageTexture
static func _request_bubble() -> ImageTexture:
	if _bubble != null: return _bubble
	const ROWS := [
		"...#######...",
		"..#ccccccc#..",
		".#ccccccccc#.",
		"#cccccrrcccc#",
		"#ccccrrrcccc#",
		"#ccccrrrcccc#",
		"#ccccrrccccc#",
		"#ccccrrccccc#",
		"#ccccccccccc#",
		"#ccccrrccccc#",
		".#ccccccccc#.",
		"..#ccccccc#..",
		"...###cc##...",
		".....#c#.....",
		"......#......",
	]
	var colors := {"#": Color("#3a2a26"), "c": Color("#fff4d6"), "r": Color("#e2574a")}
	var image := Image.create(ROWS[0].length(), ROWS.size(), false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		for x in ROWS[y].length():
			image.set_pixel(x, y, colors.get(ROWS[y][x], Color(0, 0, 0, 0)))
	_bubble = ImageTexture.create_from_image(image)
	return _bubble

func _set_request(point_id: String, wanted: bool) -> void:
	if not _requests.has(point_id): return
	_requests[point_id].wanted = wanted
	_update_request_icons()

## The "!" steps aside while the character's own interaction marker is up.
func _update_request_icons() -> void:
	for point_id: String in _requests:
		var icon: Sprite3D = _requests[point_id].icon
		if not is_instance_valid(icon): continue
		var marker: Variant = _world._point_by_id(point_id).get("marker") if is_instance_valid(_world) else null
		var marked: bool = is_instance_valid(marker) and (marker as Node3D).visible
		icon.visible = bool(_requests[point_id].wanted) and not marked

## Test/review view of which characters show a request icon.
func request_icons() -> Dictionary:
	var shown := {}
	for point_id: String in _requests:
		var icon: Sprite3D = _requests[point_id].icon
		shown[point_id] = is_instance_valid(icon) and icon.visible
	return shown

## Screen arrows map to island directions: up-screen is -Z (into the park).
static func _arrow_vector(arrow: String) -> Vector2:
	match arrow:
		"←": return Vector2(-1, 0)
		"→": return Vector2(1, 0)
		"↖": return Vector2(-0.7, -0.7)
		"↗": return Vector2(0.7, -0.7)
		"↓": return Vector2(0, 1)
	return Vector2(0, -1)

func _build_ribbon_garland(world: Node3D) -> Node3D:
	# Xiao Jiao's finished idea: swags across the left half of the avenue arch,
	# where he stands, plus a bow on the pillar and two streamers.
	var root := _group("ImpRibbonGarland")
	var z := ARCH_CENTER.z + 0.62
	var left := ARCH_CENTER.x - ARCH_HALF_WIDTH + 0.3
	var right := ARCH_CENTER.x + 0.4
	var segments := 16
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var x := lerpf(left, right, t)
		var swag := fposmod(t * 2.0, 1.0)
		var sag := 0.6 * sin(PI * swag)
		var piece: MeshInstance3D = _adopt(world._box(Vector3(x, 2.74 - sag, z), Vector3(0.4, 0.17, 0.06), RIBBON_COLORS[index % 3]), root)
		piece.rotation.z = 0.4 * cos(PI * swag)
		world.component_motion.register_component(piece, "flag", 0.4 * float(index))
		# Short streamers fall from the lowest point of each swag.
		if is_equal_approx(swag, 0.5):
			var streamer: MeshInstance3D = _adopt(world._box(Vector3(x, 1.86, z), Vector3(0.12, 0.7, 0.04), RIBBON_COLORS[(index + 1) % 3]), root)
			world.component_motion.register_component(streamer, "flag", 0.9 + float(index))
	var bow_center := Vector3(left - 0.2, 2.25, z + 0.05)
	for side in [-1.0, 1.0]:
		var loop: MeshInstance3D = _adopt(world._box(bow_center + Vector3(side * 0.22, 0.04, 0), Vector3(0.36, 0.24, 0.06), RIBBON_COLORS[0]), root)
		loop.rotation.z = side * 0.45
		var tail: MeshInstance3D = _adopt(world._box(bow_center + Vector3(side * 0.12, -0.42, 0), Vector3(0.1, 0.62, 0.04), RIBBON_COLORS[1 if side < 0 else 2]), root)
		tail.rotation.z = side * 0.18
		world.component_motion.register_component(tail, "flag", 1.3 + side)
	_adopt(world._box(bow_center, Vector3(0.14, 0.16, 0.08), RIBBON_COLORS[3]), root)
	root.visible = false
	return root

func _build_broadcast_stand(world: Node3D) -> void:
	# A small physical broadcast corner for 阿浪: a horn pole and an entry sign
	# whose arrow is wrong until his request is finished.
	var root := _group("BroadcastStand")
	var p := BROADCAST_STAND
	# Thin and non-solid so the walk from the arch to 阿浪 never snags on it.
	_adopt(world._cylinder(p + Vector3(0, 1.3, 0), 0.07, 2.6, Color("#4a5458")), root)
	for side in [-1.0, 1.0]:
		var horn: MeshInstance3D = _adopt(world._cylinder(p + Vector3(side * 0.26, 2.5, 0.05), 0.07, 0.42, Color("#e8dcc0"), 0.2), root)
		horn.rotation.z = side * -1.2
	_adopt(world._box(p + Vector3(0, 0.12, 0), Vector3(0.6, 0.24, 0.6), Color("#7c6a52")), root)
	_entry_sign_before = _entry_sign(world, root, "BeforeArrow", "入口 ↓", Color("#c96a52"), -0.12)
	_entry_sign_after = _entry_sign(world, root, "CorrectedArrow", "入口 ↑", Color("#3f8a7a"), 0.0)

func _entry_sign(world: Node3D, parent: Node3D, sign_name: String, text: String, color: Color, tilt: float) -> Node3D:
	var root := _group(sign_name, parent)
	var p := BROADCAST_STAND + Vector3(0, 1.55, 0.12)
	var board: MeshInstance3D = _adopt(world._box(p, Vector3(1.05, 0.42, 0.06), color), root)
	board.rotation.z = tilt
	var label: Label3D = _adopt(world._local_label(text, p + Vector3(0, 0.02, 0.1), 22), root)
	label.rotation.z = tilt
	return root
