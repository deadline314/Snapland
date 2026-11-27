extends RefCounted
## Per-game Main tests count coins exactly, but today's recommended booths
## (MAIN-58) pay a medal bonus that depends on the calendar date. Marking
## today's bonus as already paid for every booth keeps those counts the same
## on every day.

const GameCatalog = preload("res://game/core/game_catalog.gd")
const ParkVariety = preload("res://game/core/park_variety.gd")

static func settle(progress: Node) -> void:
	var paid := {}
	for definition: Dictionary in GameCatalog.all_definitions():
		paid[str(definition.id)] = progress.FIELD_MEDAL_COINS.size()
	progress.daily_bonus = {"day": ParkVariety.today(), "paid": paid}
