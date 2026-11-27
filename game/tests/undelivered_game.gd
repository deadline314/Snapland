extends RefCounted
## The lowest game id with no delivered definition. Games are delivered out of
## order, so "catalog size + 1" can name a game that already exists.

const GameCatalog = preload("res://game/core/game_catalog.gd")

static func first_id() -> String:
	var number := 1
	while not GameCatalog.find("game-%03d" % number).is_empty(): number += 1
	return "game-%03d" % number
