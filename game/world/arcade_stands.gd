extends RefCounted
## Entry stands of the arcade minigames in regions whose world files change
## often. A region world calls `ArcadeStands.build(self, "<region>")` once from
## its geometry build; everything else about a stand lives here, so moving one
## is a single edit in the table below. Each stand is one merged mesh, one
## collision box, one name label and one interaction point.

const Kit := preload("res://game/world/scenery_kit.gd")
## Where each stand is and where the visitor stands to play: region -> rows.
## `stand` is the centre of the booth on the ground; `point` must be walkable and
## sits to one side, so the visitor does not hide the counter.
const STANDS := {
	"toy": [
		{"id": "game-061", "title": "發條衝刺", "prompt": "發條衝刺 · 連打上發條",
			"stand": Vector3(-2.9, 0.2, 1.0), "point": Vector3(-1.95, 0.2, 2.45), "prop": "windup", "paint": Color("#ad6356")},
	],
}
const FOOTPRINT := Vector3(1.5, 2.0, 1.0)
const DARK := Color("#343b42")
const BRASS := Color("#d9a64e")
const CREAM := Color("#ffe9c2")
const TIMBER := Color("#6b5137")


static func rows(region: String) -> Array:
	return STANDS.get(region, [])


static func build(world: Node3D, region: String) -> void:
	for row: Dictionary in rows(region):
		var at: Vector3 = row.stand
		var sculpt := Kit.Sculpt.new()
		sculpt.frame = Transform3D(Basis.IDENTITY, at)
		_booth(sculpt, row.paint)
		match str(row.prop):
			"windup": _windup_prop(sculpt)
		var stand: MeshInstance3D = world._mesh(sculpt.mesh(), Vector3.ZERO, world._vertex_color_material("arcade-stand"))
		stand.name = "ArcadeStand_" + str(row.id)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = FOOTPRINT
		shape.shape = box
		body.position = at + Vector3(0, FOOTPRINT.y * 0.5, 0)
		body.add_child(shape)
		stand.add_child(body)
		world._local_label(str(row.title), at + Vector3(0, 2.16, -0.2), 26, CREAM).pixel_size = 0.0125
		world._point(str(row.id), str(row.prompt), row.point)


## The booth every arcade stand shares: plinth, striped counter, two posts and a sign board.
static func _booth(sculpt: Kit.Sculpt, paint: Color) -> void:
	sculpt.box(Vector3(0, 0.09, 0), Vector3(1.5, 0.18, 1.0), DARK)
	sculpt.box(Vector3(0, 0.53, 0), Vector3(1.3, 0.7, 0.8), paint)
	for stripe in 3:
		sculpt.box(Vector3(-0.42 + stripe * 0.42, 0.53, 0.405), Vector3(0.2, 0.62, 0.02), CREAM)
	sculpt.box(Vector3(0, 0.92, 0), Vector3(1.42, 0.08, 0.92), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.62, 1.5, -0.34), Vector3(0.1, 1.1, 0.1), TIMBER)
	sculpt.box(Vector3(0, 2.16, -0.3), Vector3(1.9, 0.44, 0.1), DARK)
	sculpt.box(Vector3(0, 1.92, -0.25), Vector3(1.9, 0.05, 0.05), BRASS)


## A butterfly key on the roof and a tin cat waiting on its race mat.
static func _windup_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.box(Vector3(0, 2.52, -0.3), Vector3(0.1, 0.3, 0.1), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(side * 0.2, 2.8, -0.3), 0.2, 0.2, 0.09, BRASS, 8, facing)
		sculpt.tube(Vector3(side * 0.2, 2.8, -0.25), 0.09, 0.09, 0.03, DARK, 6, facing)
	sculpt.box(Vector3(0, 0.97, 0.08), Vector3(1.2, 0.02, 0.5), Color("#2f5d62"))
	var coral := Color("#ff7f6a")
	sculpt.box(Vector3(-0.28, 1.15, 0.08), Vector3(0.4, 0.24, 0.24), coral)
	sculpt.box(Vector3(-0.1, 1.36, 0.08), Vector3(0.26, 0.22, 0.24), coral)
	for ear: float in [-0.07, 0.07]:
		sculpt.box(Vector3(-0.1 + ear, 1.5, 0.08), Vector3(0.07, 0.08, 0.2), coral)
	for wheel: float in [-0.4, -0.16]:
		sculpt.tube(Vector3(wheel, 1.04, 0.2), 0.07, 0.07, 0.04, DARK, 6, facing)
	sculpt.box(Vector3(-0.52, 1.2, 0.08), Vector3(0.08, 0.04, 0.04), BRASS)
	sculpt.box(Vector3(-0.58, 1.2, 0.08), Vector3(0.04, 0.2, 0.06), BRASS)
