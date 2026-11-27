extends RefCounted
## Props of the moss-light greenhouse. Fixed furniture is sculpted into the scenery
## kit's merged trim; anything repeated or moving is returned as a mesh for a batch.

const Kit := preload("res://game/world/scenery_kit.gd")
const IRON := Color("#2f4a45")
const IRON_LIGHT := Color("#4d6f66")
const BRASS := Color("#b89a5a")
const STONE := Color("#a9ab98")
const STONE_DARK := Color("#7d8474")
const TERRACOTTA := Color("#c8703f")
const TERRACOTTA_DARK := Color("#9a4f2c")
const SOIL := Color("#4a3b2c")
const WOOD := Color("#9a7648")
const WOOD_DARK := Color("#5e4630")
const ZINC := Color("#9fb0ad")
const LEAF := Color("#4f8a4a")
const LEAF_LIGHT := Color("#86b85a")
const LEAF_DARK := Color("#2f5d3a")
const MOSS := Color("#6f9c3a")
const BLOOMS: Array[Color] = [Color("#f2a7b8"), Color("#f6e27a"), Color("#f4f1e4"), Color("#b79be0"), Color("#f08a5a")]

## Repeatable 0..1 value, so every visit finds the same garden.
static func scatter(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)

static func _yaw(angle: float) -> Basis:
	return Basis(Vector3.UP, angle)

## A flat leaf from `base` to `tip`, visible from both sides.
static func leaf(sculpt: Kit.Sculpt, base: Vector3, tip: Vector3, width: float, color: Color) -> void:
	var side := (tip - base).cross(Vector3.UP)
	if side.length_squared() < 0.0001: side = Vector3.RIGHT
	side = side.normalized() * width * 0.5
	var middle := base.lerp(tip, 0.45) + Vector3(0, width * 0.15, 0)
	sculpt.sheet(base, middle + side, tip, color)
	sculpt.sheet(base, tip, middle - side, color.darkened(0.14))

## Terracotta pot with one of five plants; `size` is the rim width.
static func pot(sculpt: Kit.Sculpt, at: Vector3, size: float, style: int, bloom := Color.WHITE) -> void:
	sculpt.tube(at + Vector3(0, size * 0.4, 0), size * 0.32, size * 0.48, size * 0.8, TERRACOTTA, 7)
	sculpt.tube(at + Vector3(0, size * 0.84, 0), size * 0.55, size * 0.55, size * 0.14, TERRACOTTA.lightened(0.14), 7)
	sculpt.tube(at + Vector3(0, size * 0.9, 0), size * 0.43, size * 0.43, size * 0.05, SOIL, 7)
	var top := at + Vector3(0, size * 0.9, 0)
	match style % 5:
		0:
			sculpt.tube(top + Vector3(0, size * 0.42, 0), size * 0.62, size * 0.4, size * 0.84, LEAF, 6)
			sculpt.tube(top + Vector3(0, size * 0.98, 0), size * 0.4, size * 0.05, size * 0.3, LEAF_LIGHT, 6)
		1:
			for blade in range(4):
				var lean := _yaw(1.7 * float(blade)) * Basis(Vector3.RIGHT, 0.22)
				sculpt.box(top + lean * Vector3(0, size * 0.75, 0), Vector3(size * 0.2, size * 1.5, size * 0.07), LEAF_DARK if blade % 2 == 0 else LEAF, lean)
		2:
			sculpt.tube(top + Vector3(0, size * 0.36, 0), size * 0.6, size * 0.45, size * 0.72, LEAF, 6)
			for head in range(5):
				var out := _yaw(1.26 * float(head)) * Vector3(size * 0.34, size * (0.78 + 0.1 * float(head % 2)), 0)
				sculpt.box(top + out, Vector3.ONE * size * 0.26, bloom, _yaw(float(head)))
			sculpt.box(top + Vector3(0, size * 0.92, 0), Vector3.ONE * size * 0.26, bloom.lightened(0.25))
		3:
			for sprout in range(3):
				var where := top + _yaw(2.1 * float(sprout)) * Vector3(size * 0.18, 0, 0)
				leaf(sculpt, where, where + Vector3(size * 0.2, size * 0.45, 0), size * 0.3, LEAF_LIGHT)
				leaf(sculpt, where, where + Vector3(-size * 0.2, size * 0.4, 0), size * 0.3, LEAF_LIGHT)
		_:
			sculpt.tube(top + Vector3(0, size * 0.22, 0), size * 0.66, size * 0.4, size * 0.44, LEAF, 6)
			for strand in range(5):
				var over := _yaw(1.26 * float(strand) + 0.4) * Vector3(size * 0.58, 0, 0)
				sculpt.box(top + over + Vector3(0, -size * 0.3, 0), Vector3(size * 0.16, size * 0.8, size * 0.16), LEAF_LIGHT if strand % 2 == 0 else LEAF)

## Wooden tray of seedlings.
static func seed_tray(sculpt: Kit.Sculpt, at: Vector3, yaw: float) -> void:
	var turn := _yaw(yaw)
	sculpt.box(at + Vector3(0, 0.05, 0), Vector3(0.62, 0.1, 0.42), WOOD_DARK, turn)
	sculpt.box(at + Vector3(0, 0.09, 0), Vector3(0.54, 0.04, 0.34), SOIL, turn)
	for row in range(3):
		for column in range(4):
			var sprout := turn * Vector3(-0.2 + 0.133 * float(column), 0.14, -0.11 + 0.11 * float(row))
			sculpt.box(at + sprout, Vector3(0.06, 0.08, 0.06), LEAF_LIGHT if (row + column) % 2 == 0 else LEAF)

## Slatted staging bench carrying pots and seed trays; `along` is its length.
static func staging(kit: Kit, at: Vector3, yaw: float, along: float, seed_value: float) -> void:
	var sculpt := kit.detail
	sculpt.frame = Transform3D(_yaw(yaw), at)
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			sculpt.box(Vector3(end * (along * 0.5 - 0.08), 0.33, side * 0.24), Vector3(0.08, 0.66, 0.08), WOOD_DARK)
		sculpt.box(Vector3(0, 0.3, side * 0.24), Vector3(along - 0.1, 0.05, 0.05), WOOD_DARK)
	for slat in range(4):
		sculpt.box(Vector3(0, 0.69, -0.22 + 0.147 * float(slat)), Vector3(along, 0.05, 0.12), WOOD if slat % 2 == 0 else WOOD.darkened(0.1))
	var slots := int(along / 0.6)
	for slot in range(slots):
		var x := -along * 0.5 + 0.34 + float(slot) * (along - 0.68) / maxf(1.0, float(slots - 1))
		var pick := scatter(seed_value + float(slot) * 3.7)
		if pick < 0.3:
			seed_tray(sculpt, Vector3(x, 0.715, 0.0), 0.0)
		else:
			var style := int(pick * 23.0)
			pot(sculpt, Vector3(x, 0.715, 0.03 * sin(float(slot))), 0.26 + 0.14 * scatter(seed_value + float(slot)), style, BLOOMS[style % BLOOMS.size()])
	# Spare pots are stacked underneath.
	for spare in range(3):
		sculpt.tube(Vector3(-along * 0.3 + 0.07 * float(spare), 0.1 + 0.1 * float(spare), 0.0), 0.11, 0.16, 0.2, TERRACOTTA_DARK if spare % 2 == 0 else TERRACOTTA, 7)
	sculpt.frame = Transform3D.IDENTITY

## Zinc watering can with a long spout.
static func watering_can(sculpt: Kit.Sculpt, at: Vector3, yaw: float, tint := ZINC) -> void:
	var turn := _yaw(yaw)
	sculpt.tube(at + Vector3(0, 0.17, 0), 0.15, 0.13, 0.34, tint, 8)
	sculpt.tube(at + Vector3(0, 0.35, 0), 0.14, 0.14, 0.03, tint.darkened(0.25), 8)
	var spout := turn * Basis(Vector3.BACK, -0.9)
	sculpt.tube(at + turn * Vector3(0.26, 0.24, 0), 0.03, 0.022, 0.42, tint.darkened(0.1), 5, spout)
	sculpt.tube(at + turn * Vector3(0.44, 0.38, 0), 0.03, 0.07, 0.06, BRASS, 6, spout)
	sculpt.box(at + turn * Vector3(-0.2, 0.22, 0), Vector3(0.04, 0.26, 0.05), tint.darkened(0.2), turn)
	sculpt.box(at + turn * Vector3(-0.11, 0.36, 0), Vector3(0.2, 0.04, 0.05), tint.darkened(0.2), turn)

## Potting table: tools, a heap of compost, a stack of pots and one in progress.
static func potting_table(kit: Kit, at: Vector3, yaw: float) -> void:
	var sculpt := kit.detail
	sculpt.frame = Transform3D(_yaw(yaw), at)
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			sculpt.box(Vector3(end * 0.82, 0.39, side * 0.32), Vector3(0.1, 0.78, 0.1), WOOD_DARK)
	sculpt.box(Vector3(0, 0.22, 0), Vector3(1.7, 0.05, 0.6), WOOD_DARK.lightened(0.08))
	for plank in range(4):
		sculpt.box(Vector3(0, 0.81, -0.27 + 0.18 * float(plank)), Vector3(1.9, 0.07, 0.17), WOOD if plank % 2 == 0 else WOOD.lightened(0.08))
	# A raised back board with tools hanging from pegs.
	sculpt.box(Vector3(0, 1.22, -0.36), Vector3(1.9, 0.7, 0.05), WOOD.darkened(0.12))
	sculpt.box(Vector3(0, 1.6, -0.3), Vector3(1.96, 0.06, 0.2), WOOD_DARK)
	sculpt.box(Vector3(-0.6, 1.28, -0.31), Vector3(0.05, 0.3, 0.03), WOOD_DARK)
	sculpt.box(Vector3(-0.6, 1.08, -0.31), Vector3(0.13, 0.2, 0.03), ZINC)
	sculpt.box(Vector3(-0.3, 1.3, -0.31), Vector3(0.05, 0.26, 0.03), WOOD_DARK)
	for tine in range(3):
		sculpt.box(Vector3(-0.35 + 0.05 * float(tine), 1.08, -0.31), Vector3(0.025, 0.2, 0.03), ZINC)
	sculpt.box(Vector3(0.05, 1.22, -0.31), Vector3(0.3, 0.3, 0.03), Color("#e9dfc2"))
	sculpt.box(Vector3(0.05, 1.27, -0.3), Vector3(0.18, 0.1, 0.03), BLOOMS[0])
	sculpt.box(Vector3(0.45, 1.22, -0.31), Vector3(0.3, 0.3, 0.03), Color("#e9dfc2"))
	sculpt.box(Vector3(0.45, 1.27, -0.3), Vector3(0.18, 0.1, 0.03), BLOOMS[1])
	sculpt.tube(Vector3(-0.55, 0.93, 0.02), 0.3, 0.06, 0.2, SOIL, 7)
	sculpt.box(Vector3(-0.2, 0.87, 0.14), Vector3(0.3, 0.03, 0.07), ZINC, _yaw(0.5))
	pot(sculpt, Vector3(0.15, 0.845, 0.02), 0.3, 3)
	for stacked in range(3):
		sculpt.tube(Vector3(0.62, 0.93 + 0.09 * float(stacked), 0.0), 0.1, 0.15, 0.18, TERRACOTTA if stacked % 2 == 0 else TERRACOTTA_DARK, 7)
	pot(sculpt, Vector3(-0.5, 0.245, 0.0), 0.3, 1)
	sculpt.box(Vector3(0.35, 0.37, 0.0), Vector3(0.6, 0.25, 0.4), Color("#b9a67c"))
	sculpt.box(Vector3(0.35, 0.5, 0.0), Vector3(0.5, 0.03, 0.3), SOIL)
	sculpt.frame = Transform3D.IDENTITY

## Oak rain barrel under a downpipe; the open top holds dark water.
static func rain_barrel(kit: Kit, at: Vector3) -> void:
	var sculpt := kit.detail
	sculpt.tube(at + Vector3(0, 0.3, 0), 0.36, 0.42, 0.6, WOOD, 10)
	sculpt.tube(at + Vector3(0, 0.82, 0), 0.42, 0.37, 0.44, WOOD.lightened(0.06), 10)
	for hoop: float in [0.14, 0.6, 0.98]:
		sculpt.tube(at + Vector3(0, hoop, 0), 0.43, 0.43, 0.06, IRON, 10)
	sculpt.tube(at + Vector3(0, 1.02, 0), 0.33, 0.33, 0.03, Color("#1f4a4a"), 10)
	sculpt.tube(at + Vector3(-0.2, 0.3, 0.4), 0.04, 0.04, 0.1, BRASS, 6, Basis(Vector3.RIGHT, PI * 0.5))

## Mossy stone sundial on a baluster.
static func sundial(kit: Kit, at: Vector3) -> void:
	var sculpt := kit.detail
	sculpt.tube(at + Vector3(0, 0.07, 0), 0.52, 0.46, 0.14, STONE_DARK, 8)
	sculpt.tube(at + Vector3(0, 0.2, 0), 0.36, 0.3, 0.12, STONE, 8)
	sculpt.tube(at + Vector3(0, 0.5, 0), 0.2, 0.13, 0.5, STONE, 8)
	sculpt.tube(at + Vector3(0, 0.82, 0), 0.13, 0.24, 0.16, STONE, 8)
	sculpt.tube(at + Vector3(0, 0.95, 0), 0.4, 0.4, 0.1, STONE.lightened(0.1), 8)
	sculpt.tube(at + Vector3(0, 1.01, 0), 0.33, 0.33, 0.03, BRASS, 12)
	sculpt.sheet(at + Vector3(0, 1.02, -0.22), at + Vector3(0, 1.02, 0.2), at + Vector3(0, 1.3, -0.22), BRASS.darkened(0.2))
	for patch in range(7):
		var around := _yaw(0.9 * float(patch))
		sculpt.box(at + around * Vector3(0.3 + 0.12 * scatter(float(patch)), 0.16 + 0.11 * float(patch % 3), 0), Vector3(0.2, 0.1, 0.16), MOSS if patch % 2 == 0 else MOSS.darkened(0.2), around)
	sculpt.box(at + Vector3(0.22, 1.0, 0.2), Vector3(0.2, 0.06, 0.2), MOSS)

## Stone garden lantern; its window glows with the region's lamps.
static func stone_lantern(kit: Kit, at: Vector3) -> void:
	var sculpt := kit.detail
	sculpt.tube(at + Vector3(0, 0.08, 0), 0.34, 0.28, 0.16, STONE_DARK, 6)
	sculpt.tube(at + Vector3(0, 0.45, 0), 0.12, 0.1, 0.6, STONE, 6)
	sculpt.tube(at + Vector3(0, 0.8, 0), 0.14, 0.3, 0.12, STONE, 6)
	for corner in range(4):
		sculpt.box(at + _yaw(PI * 0.5 * float(corner) + PI * 0.25) * Vector3(0.2, 1.0, 0), Vector3(0.07, 0.3, 0.07), STONE)
	kit.glow.box(at + Vector3(0, 1.0, 0), Vector3(0.24, 0.24, 0.24), Kit.WARM_GLOW)
	sculpt.tube(at + Vector3(0, 1.24, 0), 0.46, 0.12, 0.2, STONE_DARK, 6)
	sculpt.tube(at + Vector3(0, 1.39, 0), 0.07, 0.1, 0.1, STONE, 6)
	sculpt.box(at + Vector3(0.12, 1.3, 0.1), Vector3(0.26, 0.07, 0.22), MOSS)
	sculpt.box(at + Vector3(-0.16, 0.18, 0.12), Vector3(0.22, 0.08, 0.2), MOSS.darkened(0.15))

## Two-tier stone fountain standing in a pond whose surface is at `at`.
static func fountain(kit: Kit, at: Vector3) -> void:
	var sculpt := kit.detail
	sculpt.tube(at + Vector3(0, 0.25, 0), 0.26, 0.16, 0.6, STONE, 8)
	sculpt.tube(at + Vector3(0, 0.62, 0), 0.2, 0.62, 0.18, STONE, 10)
	sculpt.tube(at + Vector3(0, 0.74, 0), 0.66, 0.66, 0.07, STONE.lightened(0.1), 10)
	sculpt.tube(at + Vector3(0, 0.775, 0), 0.56, 0.56, 0.02, Color("#3f7a78"), 10)
	sculpt.tube(at + Vector3(0, 0.98, 0), 0.1, 0.07, 0.42, STONE, 6)
	sculpt.tube(at + Vector3(0, 1.22, 0), 0.08, 0.3, 0.1, STONE, 8)
	sculpt.tube(at + Vector3(0, 1.3, 0), 0.32, 0.32, 0.05, STONE.lightened(0.1), 8)
	sculpt.tube(at + Vector3(0, 1.42, 0), 0.06, 0.02, 0.2, BRASS, 6)
	for patch in range(6):
		var around := _yaw(1.05 * float(patch) + 0.3)
		sculpt.box(at + around * Vector3(0.62, 0.69 - 0.05 * float(patch % 2), 0), Vector3(0.12, 0.2, 0.26), MOSS if patch % 2 == 0 else MOSS.darkened(0.2), around)

## Wrought-iron garden seat with a slatted timber seat.
static func garden_seat(kit: Kit, at: Vector3, yaw: float) -> void:
	var sculpt := kit.detail
	sculpt.frame = Transform3D(_yaw(yaw), at)
	for end: float in [-1.0, 1.0]:
		sculpt.box(Vector3(end * 0.72, 0.22, 0.18), Vector3(0.06, 0.44, 0.06), IRON)
		sculpt.box(Vector3(end * 0.72, 0.5, -0.2), Vector3(0.06, 1.0, 0.06), IRON)
		sculpt.box(Vector3(end * 0.72, 0.62, 0.02), Vector3(0.06, 0.05, 0.46), IRON_LIGHT)
		sculpt.tube(Vector3(end * 0.72, 1.03, -0.2), 0.06, 0.06, 0.07, BRASS, 6)
	for slat in range(3):
		sculpt.box(Vector3(0, 0.45, -0.1 + 0.15 * float(slat)), Vector3(1.5, 0.05, 0.12), WOOD)
	for rail in range(3):
		sculpt.box(Vector3(0, 0.66 + 0.14 * float(rail), -0.2), Vector3(1.5, 0.07, 0.04), WOOD.darkened(0.08))
	sculpt.frame = Transform3D.IDENTITY

## Wheelbarrow loaded with compost and a few pots.
static func wheelbarrow(kit: Kit, at: Vector3, yaw: float) -> void:
	var sculpt := kit.detail
	sculpt.frame = Transform3D(_yaw(yaw), at)
	sculpt.tube(Vector3(0.62, 0.2, 0), 0.2, 0.2, 0.09, IRON, 8, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0, 0.46, 0), Vector3(1.0, 0.3, 0.62), Color("#5c8f7c"), Basis(Vector3.BACK, 0.08))
	sculpt.tube(Vector3(0, 0.66, 0), 0.4, 0.1, 0.22, SOIL, 6)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.5, 0.42, side * 0.3), Vector3(1.3, 0.05, 0.05), WOOD_DARK, Basis(Vector3.BACK, 0.16))
		sculpt.box(Vector3(-0.45, 0.17, side * 0.26), Vector3(0.05, 0.34, 0.05), IRON)
	pot(sculpt, Vector3(-0.2, 0.6, 0.1), 0.24, 2, BLOOMS[4])
	sculpt.frame = Transform3D.IDENTITY

## Diamond lattice on posts from `from` to `to`.
static func trellis(sculpt: Kit.Sculpt, from: Vector3, to: Vector3, height: float, tint: Color) -> void:
	var span := to - from
	var length := span.length()
	var turn := Basis(Vector3.UP, atan2(-span.z, span.x))
	sculpt.frame = Transform3D(turn, from)
	for post in range(int(length / 1.6) + 2):
		var x := minf(length, 1.6 * float(post))
		sculpt.box(Vector3(x, height * 0.5, 0), Vector3(0.07, height, 0.07), tint)
		sculpt.tube(Vector3(x, height + 0.05, 0), 0.06, 0.02, 0.12, tint.lightened(0.2), 4)
	sculpt.box(Vector3(length * 0.5, height - 0.05, 0), Vector3(length, 0.05, 0.05), tint)
	sculpt.box(Vector3(length * 0.5, 0.25, 0), Vector3(length, 0.05, 0.05), tint)
	var diagonal := (height - 0.3) * 1.414
	for strip in range(int(length / 0.4) + 1):
		for lean: float in [-1.0, 1.0]:
			var x := clampf(0.4 * float(strip) + 0.2, 0.3, length - 0.3)
			sculpt.box(Vector3(x, height * 0.5 + 0.1, 0), Vector3(0.03, diagonal * 0.72, 0.03), tint.lightened(0.12), Basis(Vector3.BACK, lean * PI * 0.25))
	sculpt.frame = Transform3D.IDENTITY

## Hanging basket; the origin is the hook, so the batch shader swings it.
static func basket_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for chain in range(3):
		var out := _yaw(TAU / 3.0 * float(chain)) * Vector3(0.16, -0.3, 0)
		sculpt.box(out, Vector3(0.025, 0.66, 0.025), IRON, _yaw(TAU / 3.0 * float(chain)) * Basis(Vector3.BACK, 0.5))
	sculpt.tube(Vector3(0, -0.72, 0), 0.12, 0.34, 0.26, WOOD_DARK, 8)
	sculpt.tube(Vector3(0, -0.55, 0), 0.4, 0.3, 0.2, LEAF, 7)
	sculpt.tube(Vector3(0, -0.4, 0), 0.26, 0.06, 0.16, LEAF_LIGHT, 6)
	for strand in range(7):
		var around := _yaw(0.9 * float(strand))
		var drop := 0.45 + 0.35 * scatter(float(strand) * 2.3)
		sculpt.box(around * Vector3(0.36, -0.62 - drop * 0.5, 0), Vector3(0.1, drop, 0.1), LEAF if strand % 2 == 0 else LEAF_DARK)
		sculpt.box(around * Vector3(0.36, -0.64 - drop, 0), Vector3(0.13, 0.13, 0.13), Color(1, 1, 1, 0.9))
	for head in range(4):
		sculpt.box(_yaw(1.57 * float(head) + 0.5) * Vector3(0.22, -0.4, 0), Vector3(0.14, 0.14, 0.14), Color(1, 1, 1, 0.9))
	return sculpt.mesh()

## A strand of climbing vine that hangs from its origin.
static func vine_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for link in range(6):
		var y := -0.22 * float(link)
		var wander := 0.07 * sin(float(link) * 1.9)
		sculpt.box(Vector3(wander, y - 0.11, 0), Vector3(0.04, 0.24, 0.04), LEAF_DARK)
		for side: float in [-1.0, 1.0]:
			var base := Vector3(wander, y - 0.08 - 0.05 * side, 0)
			leaf(sculpt, base, base + Vector3(side * 0.2, -0.1, 0.07 * side), 0.17, LEAF if (link + int(side)) % 2 == 0 else LEAF_LIGHT)
	return sculpt.mesh()

## Reed clump with two seed heads; it sways from the root.
static func reed_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for blade in range(7):
		var lean := _yaw(0.9 * float(blade)) * Basis(Vector3.RIGHT, 0.1 + 0.16 * scatter(float(blade)))
		var tall := 0.7 + 0.5 * scatter(float(blade) * 3.1)
		sculpt.box(lean * Vector3(0, tall * 0.5, 0), Vector3(0.05, tall, 0.02), LEAF if blade % 2 == 0 else LEAF_LIGHT, lean)
	for head: float in [-1.0, 1.0]:
		sculpt.box(Vector3(head * 0.06, 0.7, 0), Vector3(0.025, 1.4, 0.025), LEAF_DARK)
		sculpt.box(Vector3(head * 0.06, 1.3, 0), Vector3(0.07, 0.26, 0.07), Color("#6b4a2c"))
	return sculpt.mesh()

## Low fern rosette (also the touch-me-not, whose shader folds it).
static func fern_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for frond in range(7):
		var around := _yaw(TAU / 7.0 * float(frond))
		var previous := Vector3.ZERO
		for joint in range(1, 4):
			var reach := 0.2 * float(joint)
			var point := around * Vector3(reach, 0.28 * sin(float(joint) * 0.9), 0)
			var width := 0.24 - 0.05 * float(joint)
			var side := around * Vector3(0, 0, width)
			var tone := LEAF_LIGHT if joint == 3 else (LEAF if frond % 2 == 0 else LEAF.darkened(0.12))
			sculpt.sheet(previous - side, point, previous + side, tone)
			previous = point
	return sculpt.mesh()

## Tuft of leaves with one white head that the instance colour tints.
static func flower_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for blade in range(4):
		var around := _yaw(1.57 * float(blade) + 0.4)
		leaf(sculpt, Vector3.ZERO, around * Vector3(0.16, 0.2, 0), 0.12, Color("#8fc77a"))
	sculpt.box(Vector3(0, 0.14, 0), Vector3(0.025, 0.28, 0.025), Color("#8fc77a"))
	sculpt.box(Vector3(0, 0.31, 0), Vector3(0.15, 0.1, 0.15), Color(1, 1, 1, 0.9))
	sculpt.box(Vector3(0, 0.37, 0), Vector3(0.07, 0.05, 0.07), Color(1.0, 0.95, 0.6, 0.9))
	return sculpt.mesh()

## Lily pad with a notch; white so the instance colour paints it.
static func lily_pad_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for slice in range(1, 10):
		var from := _yaw(TAU / 10.0 * float(slice)) * Vector3(0.5, 0, 0)
		var to := _yaw(TAU / 10.0 * float(slice + 1)) * Vector3(0.5, 0, 0)
		sculpt.tri(Vector3(0, 0.01, 0), to, from, Color.WHITE if slice % 2 == 0 else Color(0.86, 0.9, 0.86))
	return sculpt.mesh()

## Lotus bloom that sits on the water.
static func lotus_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for petal in range(6):
		var around := _yaw(TAU / 6.0 * float(petal))
		leaf(sculpt, Vector3(0, 0.02, 0), around * Vector3(0.2, 0.14, 0), 0.14, Color.WHITE)
	sculpt.tube(Vector3(0, 0.08, 0), 0.06, 0.04, 0.1, Color("#f6e27a"), 5)
	return sculpt.mesh()

## Toadstool, white so the instance colour paints the cap.
static func toadstool_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.1, 0), 0.05, 0.04, 0.2, Color("#f0ead8"), 5)
	sculpt.tube(Vector3(0, 0.24, 0), 0.17, 0.05, 0.12, Color.WHITE, 7)
	return sculpt.mesh()

## Stepping stone or flagstone: a low irregular slab, white for the instance colour.
static func flagstone_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var rim: Array[Vector3] = []
	for corner in range(7):
		var reach := 0.42 + 0.1 * scatter(float(corner) * 1.7)
		rim.append(_yaw(TAU / 7.0 * float(corner)) * Vector3(reach, 0, 0))
	for corner in range(7):
		var next: Vector3 = rim[(corner + 1) % 7]
		sculpt.tri(Vector3(0, 0.06, 0), next + Vector3(0, 0.06, 0), rim[corner] + Vector3(0, 0.06, 0), Color.WHITE)
		sculpt.quad(rim[corner] * 1.06, rim[corner] + Vector3(0, 0.06, 0), next + Vector3(0, 0.06, 0), next * 1.06, Color(0.72, 0.74, 0.7))
	return sculpt.mesh()

## Frog sitting at its origin and facing +Z.
static func frog_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var skin := Color("#7fc24a")
	sculpt.box(Vector3(0, 0.08, 0), Vector3(0.2, 0.13, 0.24), skin, Basis(Vector3.RIGHT, -0.3))
	sculpt.box(Vector3(0, 0.15, 0.1), Vector3(0.18, 0.1, 0.14), skin.lightened(0.1))
	sculpt.box(Vector3(0, 0.06, 0.1), Vector3(0.15, 0.05, 0.1), Color("#e8e6b0"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.07, 0.22, 0.12), Vector3(0.06, 0.06, 0.06), Color("#f4f1c8"))
		sculpt.box(Vector3(side * 0.07, 0.23, 0.15), Vector3(0.03, 0.035, 0.02), Color("#1f2a22"))
		sculpt.box(Vector3(side * 0.13, 0.05, -0.06), Vector3(0.08, 0.09, 0.18), skin.darkened(0.15))
		sculpt.box(Vector3(side * 0.1, 0.02, 0.14), Vector3(0.05, 0.04, 0.1), skin.darkened(0.1))
	return sculpt.mesh()

## Weather vane that turns about its origin: arrow, cockerel and compass arms.
static func vane_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, 0.42, 0), Vector3(1.5, 0.05, 0.05), BRASS)
	sculpt.sheet(Vector3(0.75, 0.42, 0), Vector3(0.5, 0.58, 0), Vector3(0.5, 0.26, 0), BRASS.lightened(0.15))
	sculpt.sheet(Vector3(-0.75, 0.6, 0), Vector3(-0.45, 0.42, 0), Vector3(-0.75, 0.24, 0), BRASS.lightened(0.15))
	# The cockerel is a few plates: body, neck, comb and tail.
	sculpt.sheet(Vector3(-0.22, 0.5, 0), Vector3(0.2, 0.5, 0), Vector3(0.02, 0.86, 0), BRASS.darkened(0.1))
	sculpt.sheet(Vector3(0.1, 0.62, 0), Vector3(0.3, 0.98, 0), Vector3(0.02, 0.86, 0), BRASS.darkened(0.1))
	sculpt.sheet(Vector3(0.24, 0.98, 0), Vector3(0.34, 1.08, 0), Vector3(0.2, 1.06, 0), Color("#c85a48"))
	sculpt.sheet(Vector3(-0.2, 0.52, 0), Vector3(-0.44, 0.96, 0), Vector3(-0.08, 0.74, 0), BRASS)
	return sculpt.mesh()

## Garden whirligig: four sails that spin about the local Z axis.
static func whirligig_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for sail in range(4):
		var turn := Basis(Vector3.BACK, PI * 0.5 * float(sail))
		sculpt.sheet(Vector3.ZERO, turn * Vector3(0.42, 0.1, 0.05), turn * Vector3(0.3, 0.34, -0.05), BLOOMS[1] if sail % 2 == 0 else Color("#e8604c"))
	sculpt.tube(Vector3.ZERO, 0.05, 0.05, 0.08, BRASS, 6, Basis(Vector3.RIGHT, PI * 0.5))
	return sculpt.mesh()
