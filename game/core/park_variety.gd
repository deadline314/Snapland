extends RefCounted
## Park-level reasons to replay booths you already know: today's three
## recommended booths and the five-game arcade marathon. Pure rules only;
## Main owns the screens and Progress owns every coin.

const GameCatalog = preload("res://game/core/game_catalog.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")

const DAILY_PICKS := 3
const MARATHON_GAMES := 5
## Marathon rounds run at this share of each game's own clock and medal lines.
const MARATHON_ROUND_SCALE := 0.5
## The marathon's best total and medal live with the other medal records.
const MARATHON_RECORD := "arcade-marathon"
## Marathon medals pay this multiple of the shared medal coins, once per tier.
const MARATHON_COIN_SCALE := 3


## Today's key from the local calendar; the park has no in-game day count.
static func today() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]


## Every booth whose zone the player can already enter.
static func opened_games(normal_count: int, arcade_only := false) -> Array[String]:
	var ids: Array[String] = []
	for definition: Dictionary in GameCatalog.all_definitions():
		if arcade_only and not bool(definition.get("arcade", false)):
			continue
		var zone := str(GameCatalog.identity(str(definition.id)).get("zone", ""))
		if RegionRoutes.supports(zone) and normal_count >= RegionRoutes.threshold(zone):
			ids.append(str(definition.id))
	return ids


## Three booths for `day`: the same on every load of that day, from three
## different zones whenever three zones are open.
static func daily_picks(day: String, opened: Array) -> Array[String]:
	var pool := _shuffled(opened, hash("daily-picks|" + day))
	var picks: Array[String] = []
	var zones := {}
	for id: String in pool:
		var zone := str(GameCatalog.identity(id).get("zone", ""))
		if picks.size() < DAILY_PICKS and not zones.has(zone):
			zones[zone] = true
			picks.append(id)
	for id: String in pool:
		if picks.size() < DAILY_PICKS and not picks.has(id):
			picks.append(id)
	return picks


## One medal scale for every booth: arcade games report theirs; other games
## count a clear as bronze and a devil clear as gold.
static func medal_of(result: Dictionary) -> int:
	var summary: Variant = result.get("score_summary", {})
	if summary is Dictionary and bool(summary.get("arcade", false)):
		return clampi(int(summary.get("medal", 0)), 0, 3)
	if not bool(result.get("success", false)):
		return 0
	return 3 if bool(result.get("devil", false)) else 1


## Five arcade games in random order; a short list repeats without playing the
## same game twice in a row when it can avoid it.
static func marathon_games(opened_arcade: Array, seed_value: int) -> Array[String]:
	var order := _shuffled(opened_arcade, seed_value)
	var games: Array[String] = []
	if order.is_empty():
		return games
	while games.size() < MARATHON_GAMES:
		games.append(order[games.size() % order.size()])
	return games


## Bronze, silver and gold totals: the sum of each game's shortened medal lines.
static func marathon_lines(games: Array) -> Array[int]:
	var lines: Array[int] = [0, 0, 0]
	for id: String in games:
		var driver := marathon_driver(id)
		if driver == null:
			continue
		driver.round_seed = 0
		driver.reset(false, "noon")
		for tier in 3:
			lines[tier] += int(driver.thresholds[tier])
	return lines


static func marathon_driver(id: String) -> RefCounted:
	var definition := GameCatalog.find(id)
	var path := "res://game/minigames/arcade/%s_driver.gd" % str(definition.get("mode", ""))
	if not bool(definition.get("arcade", false)) or not ResourceLoader.exists(path):
		return null
	var driver: RefCounted = (load(path) as Script).new()
	driver.round_scale = MARATHON_ROUND_SCALE
	return driver


static func marathon_medal(total: int, lines: Array) -> int:
	var earned := 0
	for line in lines:
		if total >= int(line) and int(line) > 0:
			earned += 1
	return earned


static func _shuffled(ids: Array, seed_value: int) -> Array[String]:
	var pool: Array[String] = []
	for id in ids:
		pool.append(str(id))
	pool.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(pool.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := pool[index]
		pool[index] = pool[other]
		pool[other] = held
	return pool
