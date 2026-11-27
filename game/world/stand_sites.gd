extends RefCounted
## Stand sites a district keeps for arcade games that have not arrived yet (see
## ArcadeStands). A site is a booth centre `stand` plus the visitor's `point`;
## it is open until an ArcadeStands row of the same region stands on it, and an
## open site wears a "準備中" tag and offers no interaction.

const ArcadeStands := preload("res://game/world/arcade_stands.gd")

## Sites no ArcadeStands row of `region` stands on yet.
static func open(region: String, sites: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array = ArcadeStands.rows(region)
	var free: Array[Dictionary] = []
	for site: Dictionary in sites:
		var taken := rows.any(func(row: Dictionary) -> bool: return (row.stand as Vector3).distance_to(site.stand) < 0.3)
		if not taken: free.append(site)
	return free

## The "準備中" tag over an open site.
static func tag(world: Node3D, at: Vector3, ink: Color, outline: Color) -> Label3D:
	var label: Label3D = world._local_label("準備中", at, 20, ink)
	label.outline_modulate = outline
	label.pixel_size = 0.0105
	return label
