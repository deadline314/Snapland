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

var wayfinding := Wayfinding.new()
var _status_labels: Dictionary = {}
var _signpost_records: Array[Dictionary] = []
var _ribbon: Node3D
var _entry_sign_before: Node3D
var _entry_sign_after: Node3D
var _outcomes := {"quest-001": false, "quest-002": false}
var _last_signature := ""

func configure(world: Node3D) -> void:
	name = "StoryLandmarks"
	for signpost: Dictionary in wayfinding.signposts():
		_build_signpost(world, signpost)
	_ribbon = _build_ribbon_garland(world)
	_build_broadcast_stand(world)
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
	_outcomes["quest-001"] = int(steps.get("quest-001", 0)) >= Wayfinding.QUEST_STEP_COUNT
	_outcomes["quest-002"] = int(steps.get("quest-002", 0)) >= Wayfinding.QUEST_STEP_COUNT
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
	# A post with one pointing plank per direction; the readable text is a
	# single billboard above it, shown only when the player is nearby.
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
	var board: Label3D = _adopt(world._local_label("", base + Vector3(0, top + 1.25, 0.1), 32, Color("#fff4d6")), root)
	board.name = "SignText"
	board.outline_size = 10
	board.line_spacing = 3.0
	_status_labels[id] = board
	_signpost_records.append({"id": id, "title": str(signpost.get("title", "")), "position": base, "entries": entries, "lines": []})

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
