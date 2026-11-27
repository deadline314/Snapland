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
		{"id": "game-062", "title": "整點咕咕", "prompt": "整點咕咕 · 數滴答開門",
			"stand": Vector3(-2.4, 0.2, -5.2), "point": Vector3(-1.3, 0.2, -3.75), "prop": "cuckoo", "paint": Color("#567f77")},
		{"id": "game-063", "title": "磁鐵搬家", "prompt": "磁鐵搬家 · 吸起鐵皮玩具",
			"stand": Vector3(10.5, 0.2, 6.2), "point": Vector3(9.4, 0.2, 7.55), "prop": "magnet", "paint": Color("#b5553c")},
		{"id": "game-064", "title": "積木拱橋", "prompt": "積木拱橋 · 看準了放下積木",
			"stand": Vector3(7.6, 0.2, 6.1), "point": Vector3(6.35, 0.2, 7.5), "prop": "bridge", "paint": Color("#4f8f86")},
		{"id": "game-065", "title": "彈簧青蛙", "prompt": "彈簧青蛙 · 按住上發條跳積木",
			"stand": Vector3(-6.2, 0.2, -2.5), "point": Vector3(-7.15, 0.2, -1.05), "prop": "frog", "paint": Color("#5f7d4a")},
		{"id": "game-066", "title": "軌道換軌", "prompt": "軌道換軌 · 扳道岔送火車回站",
			"stand": Vector3(2.9, 0.2, -6.4), "point": Vector3(1.85, 0.2, -5.0), "prop": "rails", "paint": Color("#4f79a8")},
		{"id": "game-068", "title": "陀螺相撲", "prompt": "陀螺相撲 · 方向鍵撞陀螺",
			"stand": Vector3(-7.3, 0.2, 5.7), "point": Vector3(-6.15, 0.2, 6.85), "prop": "tops", "paint": Color("#8a4a3e")},
		{"id": "game-070", "title": "敲敲玩具兵", "prompt": "敲敲玩具兵 · 方向鍵敲回去",
			"stand": Vector3(-6.0, 0.2, 1.6), "point": Vector3(-4.95, 0.2, 3.0), "prop": "soldier", "paint": Color("#5b6f9a")},
	],
	"garden": [
		{"id": "game-073", "title": "螢火蟲長曝光", "prompt": "螢火蟲長曝光 · 忍住別按",
			"stand": Vector3(-9.6, 0.2, 5.6), "point": Vector3(-8.5, 0.2, 6.9), "prop": "camera", "paint": Color("#38534e")},
		{"id": "game-074", "title": "露珠牽橋", "prompt": "露珠牽橋 · 傾斜葉子滾露珠",
			"stand": Vector3(9.0, 0.2, 6.0), "point": Vector3(10.0, 0.2, 7.4), "prop": "dew", "paint": Color("#4f7f5a")},
		{"id": "game-077", "title": "睡蓮踏浪", "prompt": "睡蓮踏浪 · 踩葉過池",
			"stand": Vector3(-2.6, 0.2, -7.7), "point": Vector3(-1.55, 0.2, -6.35), "prop": "lily", "paint": Color("#3f6f5a")},
		{"id": "game-079", "title": "蘑菇撐傘", "prompt": "蘑菇撐傘 · 替幼苗接雨",
			"stand": Vector3(7.0, 0.2, 6.0), "point": Vector3(5.85, 0.2, 7.35), "prop": "mushroom", "paint": Color("#8a4a3a")},
		{"id": "game-080", "title": "螢火蟲對暗號", "prompt": "螢火蟲對暗號 · 照閃光按回去",
			"stand": Vector3(2.6, 0.2, -7.7), "point": Vector3(1.55, 0.2, -6.35), "prop": "code", "paint": Color("#3a3f5c")},
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
			"cuckoo": _cuckoo_prop(sculpt)
			"frog": _frog_prop(sculpt)
			"tops": _tops_prop(sculpt)
			"soldier": _soldier_prop(sculpt)
			"magnet": _magnet_prop(sculpt)
			"bridge": _bridge_prop(sculpt)
			"rails": _rails_prop(sculpt)
			"camera": _camera_prop(sculpt)
			"lily": _lily_prop(sculpt)
			"mushroom": _mushroom_prop(sculpt)
			"code": _code_prop(sculpt)
			"dew": _dew_prop(sculpt)
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


## A cuckoo clock on the roof with its bird halfway out, and a spare bird on the counter.
static func _cuckoo_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	var wall := Color("#b9704a")
	var roof := Color("#a8473f")
	var bird := Color("#ffd166")
	sculpt.box(Vector3(0, 2.72, -0.3), Vector3(0.62, 0.68, 0.3), wall)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.2, 3.14, -0.3), Vector3(0.54, 0.09, 0.4), roof, Basis(Vector3.BACK, side * -0.6))
	sculpt.tube(Vector3(0, 2.66, -0.13), 0.19, 0.19, 0.04, CREAM, 10, facing)
	sculpt.box(Vector3(0, 2.71, -0.1), Vector3(0.03, 0.13, 0.02), DARK)
	sculpt.box(Vector3(0.05, 2.66, -0.1), Vector3(0.1, 0.03, 0.02), DARK)
	sculpt.box(Vector3(0, 2.96, -0.1), Vector3(0.16, 0.14, 0.14), bird)
	sculpt.box(Vector3(0, 2.94, -0.01), Vector3(0.06, 0.05, 0.06), Color("#e07b39"))
	sculpt.box(Vector3(0, 2.2, -0.2), Vector3(0.03, 0.34, 0.03), BRASS)
	sculpt.tube(Vector3(0, 2.02, -0.2), 0.08, 0.08, 0.04, BRASS, 8, facing)
	sculpt.box(Vector3(0.3, 1.09, 0.1), Vector3(0.24, 0.24, 0.22), bird)
	sculpt.box(Vector3(0.3, 1.08, 0.24), Vector3(0.08, 0.06, 0.08), Color("#e07b39"))
	sculpt.box(Vector3(-0.3, 1.02, 0.1), Vector3(0.36, 0.12, 0.3), wall)


## A camera on a tripod above the sign, and a jar of fireflies on the counter.
static func _camera_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	for lean: float in [-1.0, 0.0, 1.0]:
		sculpt.box(Vector3(lean * 0.16, 2.6, -0.3 + absf(lean) * 0.06 - 0.06), Vector3(0.04, 0.5, 0.04), TIMBER, Basis(Vector3.BACK, lean * 0.32))
	sculpt.box(Vector3(0, 3.0, -0.3), Vector3(0.5, 0.32, 0.26), DARK)
	sculpt.box(Vector3(0, 3.19, -0.3), Vector3(0.52, 0.06, 0.28), Color("#8a8494"))
	sculpt.tube(Vector3(0, 3.0, -0.12), 0.13, 0.11, 0.14, BRASS, 8, facing)
	sculpt.tube(Vector3(0, 3.0, -0.04), 0.08, 0.08, 0.02, Color("#16303a"), 8, facing)
	sculpt.box(Vector3(0.17, 3.24, -0.3), Vector3(0.08, 0.05, 0.08), Color("#6fd39a"))
	sculpt.tube(Vector3(-0.28, 1.14, 0.1), 0.15, 0.15, 0.34, Color("#9fc9b4"), 8)
	sculpt.tube(Vector3(-0.28, 1.33, 0.1), 0.12, 0.12, 0.05, TIMBER, 8)
	for fly: Vector3 in [Vector3(-0.31, 1.1, 0.26), Vector3(-0.23, 1.2, 0.26), Vector3(-0.3, 1.24, 0.25)]:
		sculpt.box(fly, Vector3(0.035, 0.035, 0.02), Color("#dcff8a"))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A lily pad with a frog on the roof, and a little pond basin of pads on the counter.
static func _lily_prop(sculpt: Kit.Sculpt) -> void:
	var leaf := Color("#5c9c62")
	sculpt.tube(Vector3(0, 2.44, -0.3), 0.46, 0.46, 0.05, leaf, 12)
	sculpt.box(Vector3(0.3, 2.47, -0.12), Vector3(0.22, 0.02, 0.1), Color("#3f7f52"), Basis(Vector3.UP, -0.5))
	var frog := Color("#7cb85a")
	sculpt.box(Vector3(-0.08, 2.6, -0.3), Vector3(0.26, 0.2, 0.22), frog)
	for eye: float in [-0.16, 0.0]:
		sculpt.box(Vector3(eye, 2.73, -0.2), Vector3(0.08, 0.08, 0.06), CREAM)
		sculpt.box(Vector3(eye, 2.73, -0.16), Vector3(0.04, 0.04, 0.02), DARK)
	sculpt.tube(Vector3(-0.15, 1.0, 0.1), 0.42, 0.4, 0.12, Color("#9aa59a"), 10)
	sculpt.tube(Vector3(-0.15, 1.05, 0.1), 0.36, 0.36, 0.04, Color("#2c6a66"), 10)
	for pad: Vector3 in [Vector3(-0.3, 1.08, 0.05), Vector3(-0.02, 1.08, 0.2), Vector3(-0.2, 1.08, 0.28)]:
		sculpt.tube(pad, 0.1, 0.1, 0.02, leaf, 8)
	sculpt.box(Vector3(-0.02, 1.11, 0.2), Vector3(0.06, 0.05, 0.06), Color("#f2a7b8"))
	sculpt.box(Vector3(0.38, 1.0, 0.1), Vector3(0.3, 0.06, 0.26), CREAM)


## A spotted mushroom umbrella over the sign, and a seedling in a clay pot on the counter.
static func _mushroom_prop(sculpt: Kit.Sculpt) -> void:
	var cap := Color("#c8483e")
	var spot := Color("#fff2dc")
	sculpt.box(Vector3(0, 2.62, -0.3), Vector3(0.08, 0.36, 0.08), Color("#efe2c4"))
	sculpt.tube(Vector3(0, 2.84, -0.3), 0.62, 0.5, 0.14, cap, 12)
	sculpt.tube(Vector3(0, 3.02, -0.3), 0.48, 0.18, 0.22, cap, 12)
	for dot: Vector3 in [Vector3(-0.3, 2.98, -0.06), Vector3(0.18, 3.06, -0.12), Vector3(0.42, 2.92, -0.14), Vector3(-0.08, 3.14, -0.2)]:
		sculpt.box(dot, Vector3(0.1, 0.06, 0.06), spot)
	sculpt.tube(Vector3(-0.3, 1.06, 0.1), 0.14, 0.11, 0.22, Color("#b8643f"), 8)
	sculpt.tube(Vector3(-0.3, 1.18, 0.1), 0.12, 0.12, 0.02, Color("#4f3f2e"), 8)
	sculpt.box(Vector3(-0.3, 1.3, 0.1), Vector3(0.03, 0.22, 0.03), Color("#5c9c62"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.3 + side * 0.07, 1.4, 0.1), Vector3(0.12, 0.03, 0.07), Color("#6fae5c"), Basis(Vector3.BACK, side * 0.3))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## Four little paper lanterns hung under the sign, each with a firefly glow
## (kept below the greenhouse ribs so they stay in view), and a stone lantern
## on the counter.
static func _code_prop(sculpt: Kit.Sculpt) -> void:
	var paper := Color("#f1e2bc")
	var glow := Color("#dcff8a")
	for lantern: Vector3 in [Vector3(-0.42, 1.62, -0.12), Vector3(-0.14, 1.56, -0.12), Vector3(0.14, 1.62, -0.12), Vector3(0.42, 1.56, -0.12)]:
		sculpt.box(lantern + Vector3(0, (1.9 - lantern.y) * 0.5 + 0.06, 0), Vector3(0.02, 1.9 - lantern.y - 0.12, 0.02), DARK)
		sculpt.tube(lantern, 0.1, 0.1, 0.2, paper, 8)
		sculpt.tube(lantern + Vector3(0, 0.12, 0), 0.06, 0.1, 0.04, TIMBER, 8)
		sculpt.box(lantern + Vector3(0, 0, 0.1), Vector3(0.07, 0.07, 0.02), glow)
	var stone := Color("#8f9488")
	sculpt.box(Vector3(-0.3, 1.0, 0.1), Vector3(0.22, 0.06, 0.22), stone)
	sculpt.box(Vector3(-0.3, 1.12, 0.1), Vector3(0.08, 0.18, 0.08), stone)
	sculpt.box(Vector3(-0.3, 1.27, 0.1), Vector3(0.18, 0.12, 0.18), stone.darkened(0.1))
	sculpt.box(Vector3(-0.3, 1.27, 0.2), Vector3(0.08, 0.06, 0.02), Color("#ffe7a0"))
	sculpt.tube(Vector3(-0.3, 1.37, 0.1), 0.16, 0.02, 0.1, stone, 6)
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A tin frog crouched on a little belt of letter blocks, with its butterfly key, and a big key on the roof.
static func _frog_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	var tin := Color("#7fa25a")
	sculpt.box(Vector3(0, 0.99, 0.08), Vector3(1.24, 0.06, 0.36), Color("#3b3135"))
	for roller: float in [-0.56, 0.56]:
		sculpt.tube(Vector3(roller, 0.99, 0.08), 0.05, 0.05, 0.38, DARK, 8, Basis(Vector3.BACK, PI * 0.5))
	for block: Array in [[-0.36, Color("#ad573f")], [0.02, Color("#c4904a")], [0.38, Color("#5b8f80")]]:
		sculpt.box(Vector3(block[0], 1.12, 0.08), Vector3(0.22, 0.2, 0.22), block[1])
		sculpt.box(Vector3(block[0], 1.12, 0.195), Vector3(0.12, 0.12, 0.01), CREAM)
	sculpt.box(Vector3(0.02, 1.32, 0.08), Vector3(0.3, 0.17, 0.22), tin)
	sculpt.box(Vector3(0.16, 1.41, 0.08), Vector3(0.14, 0.12, 0.18), tin)
	for eye: float in [-0.06, 0.06]:
		sculpt.box(Vector3(0.18, 1.49, 0.08 + eye), Vector3(0.06, 0.06, 0.05), CREAM)
	sculpt.box(Vector3(-0.15, 1.45, 0.08), Vector3(0.03, 0.12, 0.03), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(-0.15, 1.53, 0.08 + side * 0.06), 0.05, 0.05, 0.02, BRASS, 6, facing)
	sculpt.box(Vector3(0, 2.52, -0.3), Vector3(0.1, 0.3, 0.1), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(side * 0.2, 2.8, -0.3), 0.2, 0.2, 0.09, tin, 8, facing)


## A tin dish ringed with straw rope and two tops squaring up on the counter, and a big top on the roof.
static func _tops_prop(sculpt: Kit.Sculpt) -> void:
	sculpt.tube(Vector3(0, 0.98, 0.08), 0.5, 0.52, 0.05, Color("#8c7f74"), 16)
	sculpt.tube(Vector3(0, 1.02, 0.08), 0.46, 0.46, 0.04, Color("#c9a35c"), 16)
	sculpt.tube(Vector3(0, 1.0, 0.08), 0.4, 0.4, 0.03, Color("#7d7068"), 16)
	for top: Array in [[-0.17, Color("#b8483a")], [0.19, Color("#4f8a7e")]]:
		var at := Vector3(top[0], 1.0, 0.08)
		sculpt.tube(at + Vector3(0, 0.06, 0), 0.02, 0.09, 0.12, Color("#8f8a86"), 8)
		sculpt.tube(at + Vector3(0, 0.17, 0), 0.13, 0.13, 0.1, top[1], 10)
		sculpt.tube(at + Vector3(0, 0.23, 0), 0.1, 0.06, 0.04, BRASS, 8)
		sculpt.tube(at + Vector3(0, 0.29, 0), 0.025, 0.025, 0.08, TIMBER, 6)
	sculpt.tube(Vector3(0, 2.5, -0.3), 0.03, 0.12, 0.2, Color("#8f8a86"), 8)
	sculpt.tube(Vector3(0, 2.72, -0.3), 0.3, 0.3, 0.22, Color("#b8483a"), 12)
	sculpt.tube(Vector3(0, 2.72, -0.3), 0.31, 0.31, 0.06, CREAM, 12)
	sculpt.tube(Vector3(0, 2.9, -0.3), 0.2, 0.08, 0.1, BRASS, 10)
	sculpt.tube(Vector3(0, 3.02, -0.3), 0.04, 0.04, 0.14, TIMBER, 6)


## A striped sentry box with a toy soldier popping out and a mallet on the counter, and a big mallet on the roof.
static func _soldier_prop(sculpt: Kit.Sculpt) -> void:
	var red := Color("#b8483a")
	sculpt.box(Vector3(-0.22, 1.26, 0.0), Vector3(0.44, 0.6, 0.4), CREAM)
	for stripe: float in [-0.36, -0.22, -0.08]:
		sculpt.box(Vector3(stripe, 1.26, 0.205), Vector3(0.06, 0.6, 0.01), red)
	sculpt.box(Vector3(-0.22, 1.62, 0.0), Vector3(0.52, 0.08, 0.48), Color("#5b6f9a"))
	sculpt.box(Vector3(-0.22, 1.28, 0.21), Vector3(0.22, 0.34, 0.01), DARK)
	sculpt.box(Vector3(-0.22, 1.38, 0.26), Vector3(0.14, 0.12, 0.1), Color("#ebb894"))
	sculpt.box(Vector3(-0.22, 1.52, 0.26), Vector3(0.16, 0.2, 0.12), Color("#2f2838"))
	sculpt.box(Vector3(-0.22, 1.18, 0.26), Vector3(0.18, 0.14, 0.1), red)
	sculpt.box(Vector3(0.3, 1.02, 0.12), Vector3(0.4, 0.04, 0.04), TIMBER, Basis(Vector3.UP, 0.4))
	sculpt.tube(Vector3(0.45, 1.06, 0.2), 0.08, 0.08, 0.2, Color("#c8a676"), 8, Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, 0.4))
	sculpt.box(Vector3(0, 2.5, -0.3), Vector3(0.06, 0.4, 0.06), TIMBER, Basis(Vector3.BACK, 0.5))
	sculpt.tube(Vector3(-0.12, 2.72, -0.3), 0.13, 0.13, 0.36, Color("#c8a676"), 10, Basis(Vector3.BACK, PI * 0.5 + 0.5))
	for band: float in [-0.14, 0.14]:
		sculpt.tube(Vector3(-0.12, 2.72, -0.3) + Vector3(band, 0, 0).rotated(Vector3.BACK, 0.5), 0.14, 0.14, 0.05, red, 10, Basis(Vector3.BACK, PI * 0.5 + 0.5))


## A little jib crane on the roof lifting a tin robot with a red horseshoe
## magnet, and a toy crate with a wooden duck waiting on the counter.
static func _magnet_prop(sculpt: Kit.Sculpt) -> void:
	var red := Color("#c8423a")
	var steel := Color("#c3c8cf")
	var tin := Color("#a9b0b8")
	var pine := Color("#d2a46a")
	sculpt.box(Vector3(0.55, 2.8, -0.3), Vector3(0.08, 0.84, 0.08), TIMBER)
	sculpt.box(Vector3(0.18, 3.2, -0.3), Vector3(0.82, 0.07, 0.07), Color("#b5553c"))
	sculpt.box(Vector3(0.36, 3.02, -0.3), Vector3(0.04, 0.4, 0.04), Color("#b5553c"), Basis(Vector3.BACK, -0.8))
	sculpt.box(Vector3(-0.15, 3.1, -0.3), Vector3(0.02, 0.18, 0.02), DARK)
	sculpt.box(Vector3(-0.15, 2.97, -0.3), Vector3(0.34, 0.09, 0.12), red)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.15 + side * 0.12, 2.85, -0.3), Vector3(0.1, 0.16, 0.12), red)
		sculpt.box(Vector3(-0.15 + side * 0.12, 2.74, -0.3), Vector3(0.1, 0.06, 0.12), steel)
	sculpt.box(Vector3(-0.15, 2.62, -0.3), Vector3(0.12, 0.09, 0.1), tin)
	sculpt.box(Vector3(-0.15, 2.5, -0.3), Vector3(0.16, 0.14, 0.11), tin)
	sculpt.box(Vector3(-0.15, 2.51, -0.24), Vector3(0.04, 0.04, 0.01), red)
	for eye: float in [-0.03, 0.03]:
		sculpt.box(Vector3(-0.15 + eye, 2.63, -0.245), Vector3(0.02, 0.02, 0.01), DARK)
	sculpt.box(Vector3(-0.3, 1.1, 0.1), Vector3(0.4, 0.24, 0.3), pine)
	sculpt.box(Vector3(-0.3, 1.22, 0.1), Vector3(0.42, 0.03, 0.32), pine.darkened(0.25))
	sculpt.box(Vector3(-0.3, 1.1, 0.26), Vector3(0.18, 0.1, 0.01), CREAM)
	sculpt.box(Vector3(0.3, 1.05, 0.1), Vector3(0.22, 0.12, 0.14), Color("#e8b84a"))
	sculpt.box(Vector3(0.21, 1.15, 0.1), Vector3(0.09, 0.09, 0.09), Color("#e8b84a"))
	sculpt.box(Vector3(0.15, 1.14, 0.1), Vector3(0.05, 0.03, 0.04), Color("#e0773c"))
	for wheel: float in [0.22, 0.38]:
		sculpt.tube(Vector3(wheel, 0.99, 0.18), 0.03, 0.03, 0.02, DARK, 6, Basis(Vector3.RIGHT, PI * 0.5))


## A stack of painted blocks swinging from a rope on the roof, and a little
## wooden arch bridge with a toy engine on the counter.
static func _bridge_prop(sculpt: Kit.Sculpt) -> void:
	var paints: Array[Color] = [Color("#c0503f"), Color("#e0b04a"), Color("#4f79a8")]
	var pine := Color("#d2a46a")
	sculpt.box(Vector3(0.0, 3.25, -0.3), Vector3(0.9, 0.06, 0.06), TIMBER)
	sculpt.box(Vector3(0.42, 2.82, -0.3), Vector3(0.06, 0.86, 0.06), TIMBER)
	sculpt.box(Vector3(-0.12, 3.05, -0.3), Vector3(0.02, 0.4, 0.02), CREAM, Basis(Vector3.BACK, 0.25))
	sculpt.box(Vector3(-0.17, 2.82, -0.3), Vector3(0.36, 0.14, 0.2), paints[0], Basis(Vector3.BACK, 0.25))
	sculpt.box(Vector3(-0.42, 2.48, -0.3), Vector3(0.28, 0.14, 0.2), paints[1])
	sculpt.box(Vector3(-0.42, 2.62, -0.3), Vector3(0.24, 0.14, 0.2), paints[2])
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.34, 1.06, 0.1), Vector3(0.12, 0.2, 0.2), pine.darkened(0.15))
	for step in 5:
		var t := (step + 0.5) / 5.0
		var x := lerpf(-0.36, 0.36, t)
		sculpt.box(Vector3(x, 1.12 + 0.07 * sin(t * PI), 0.1), Vector3(0.16, 0.05, 0.2), pine, Basis(Vector3.BACK, -0.35 * cos(t * PI)))
	sculpt.box(Vector3(0, 1.22, 0.1), Vector3(0.82, 0.04, 0.22), pine.darkened(0.1))
	sculpt.box(Vector3(-0.08, 1.31, 0.1), Vector3(0.22, 0.12, 0.14), paints[0])
	sculpt.box(Vector3(-0.15, 1.42, 0.1), Vector3(0.06, 0.1, 0.06), Color("#4a4e57"))
	sculpt.box(Vector3(0.12, 1.3, 0.1), Vector3(0.14, 0.1, 0.14), paints[2])


## A railway signal with three coloured lamps on the roof, and a wooden toy
## track splitting three ways on the counter with a little engine at the points.
static func _rails_prop(sculpt: Kit.Sculpt) -> void:
	var lamps: Array[Color] = [Color("#c0503f"), Color("#4f79a8"), Color("#e0b04a")]
	var pine := Color("#d2a46a")
	sculpt.box(Vector3(0.0, 2.72, -0.3), Vector3(0.08, 0.68, 0.08), DARK)
	sculpt.box(Vector3(0.0, 3.0, -0.25), Vector3(0.26, 0.6, 0.1), DARK.lightened(0.15))
	for lamp in 3:
		sculpt.tube(Vector3(0.0, 3.2 - lamp * 0.19, -0.19), 0.07, 0.07, 0.03, lamps[lamp], 8, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0.24, 2.92, -0.3), Vector3(0.36, 0.06, 0.04), CREAM, Basis(Vector3.BACK, 0.5))
	sculpt.box(Vector3(-0.3, 0.98, 0.1), Vector3(0.5, 0.03, 0.12), pine)
	for branch in 3:
		var turn := (branch - 1) * 0.45
		sculpt.box(Vector3(0.15 + 0.1 * cos(turn), 0.98, 0.1 + 0.18 * sin(turn)), Vector3(0.36, 0.03, 0.12), pine.darkened(0.08), Basis(Vector3.UP, -turn))
	sculpt.box(Vector3(-0.32, 1.06, 0.1), Vector3(0.2, 0.12, 0.1), lamps[0])
	sculpt.box(Vector3(-0.25, 1.15, 0.1), Vector3(0.04, 0.08, 0.04), Color("#4a4e57"))
	sculpt.box(Vector3(-0.42, 1.09, 0.1), Vector3(0.08, 0.16, 0.1), lamps[0].darkened(0.2))


## A broad leaf tipped over the sign with a big dewdrop rolling on it and a
## caterpillar on its edge, and a potted flower bud on the counter.
static func _dew_prop(sculpt: Kit.Sculpt) -> void:
	var leaf := Color("#5f9e4f")
	var tilt := Basis(Vector3.BACK, -0.18)
	sculpt.box(Vector3(0.05, 2.55, -0.3), Vector3(0.05, 0.5, 0.05), Color("#3f6f3a"))
	sculpt.box(Vector3(0, 2.84, -0.3), Vector3(1.5, 0.05, 0.5), leaf, tilt)
	sculpt.box(Vector3(0, 2.875, -0.3), Vector3(1.4, 0.02, 0.05), Color("#b9d48a"), tilt)
	for tip: float in [-1.0, 1.0]:
		sculpt.box(Vector3(tip * 0.8, 2.84 - tip * 0.15, -0.3), Vector3(0.18, 0.05, 0.26), leaf.darkened(0.1), tilt)
	sculpt.ball(Vector3(-0.3, 3.02, -0.3), 0.15, Color("#a9e2ef"), Color("#e8fbff"), 8, 4, 0.9)
	sculpt.box(Vector3(0.45, 2.85, -0.07), Vector3(0.22, 0.06, 0.06), Color("#9ccf52"), tilt)
	sculpt.tube(Vector3(-0.3, 1.06, 0.1), 0.14, 0.11, 0.22, Color("#b8643f"), 8)
	sculpt.tube(Vector3(-0.3, 1.18, 0.1), 0.12, 0.12, 0.02, Color("#4f3f2e"), 8)
	sculpt.box(Vector3(-0.3, 1.32, 0.1), Vector3(0.03, 0.26, 0.03), Color("#3f6f3a"))
	sculpt.ball(Vector3(-0.3, 1.5, 0.1), 0.07, Color("#f2a7b8"), Color("#7cae5a"), 6, 3, 1.3)
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)
