extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Script = load("res://game/core/game_catalog.gd")
	_check(catalog != null, "lightweight delivered catalog exists")
	if catalog == null:
		_finish()
		return
	var welcome: Array = catalog.definitions()
	var harbor: Array = catalog.definitions("harbor")
	var all_games: Array = catalog.all_definitions()
	_check(welcome == JSON.parse_string(FileAccess.get_file_as_string("res://game/data/welcome_games.json")), "default definitions preserve the original welcome row shape and order")
	_check(welcome.size() == 12 and harbor.size() == 6 and all_games.size() == 18, "only the eighteen delivered games are exposed")
	for index in range(welcome.size()):
		_check(welcome[index].id == "game-%03d" % (index + 1), "welcome numbering stays ordered")
	_check(all_games == welcome + harbor and catalog.definitions("candy").is_empty(), "global order is welcome then harbor; planned regions remain unavailable")
	_check(harbor[0].name == "浪間小艇" and harbor[0].instructions == "划槳、轉舵並側滑靠岸" and harbor[0].ordinary == "載三箱到兩座浮碼頭" and harbor[0].devil == "用浪峰側滑靠岸不撞箱", "harbor row uses the approved concise copy")
	var expected := {"id": "game-013", "mode": "rowing_cargo", "zone": "harbor", "local_index": 1, "photo_id": "photo-harbor-game-1", "devil_photo_id": "photo-harbor-devil-1", "achievement_id": "ACH_GAME_013"}
	_check(catalog.identity("game-013") == expected and catalog.identity("rowing_cargo") == expected, "global and mode lookup produce the same regional identity")
	var sandbar := {"id": "game-014", "mode": "tide_sandbar", "zone": "harbor", "local_index": 2, "photo_id": "photo-harbor-game-2", "devil_photo_id": "photo-harbor-devil-2", "achievement_id": "ACH_GAME_014"}
	_check(catalog.identity("game-014") == sandbar and catalog.identity("tide_sandbar") == sandbar and harbor[1].name == "潮汐沙路", "second harbor game keeps local two and global fourteen")
	var prism := {"id": "game-015", "mode": "lighthouse_prism", "zone": "harbor", "local_index": 3, "photo_id": "photo-harbor-game-3", "devil_photo_id": "photo-harbor-devil-3", "achievement_id": "ACH_GAME_015"}
	_check(catalog.identity("game-015") == prism and catalog.identity("lighthouse_prism") == prism and harbor[2].name == "燈塔折光", "third harbor game keeps local three and global fifteen")
	var tug := {"id": "game-016", "mode": "rope_tug", "zone": "harbor", "local_index": 4, "photo_id": "photo-harbor-game-4", "devil_photo_id": "photo-harbor-devil-4", "achievement_id": "ACH_GAME_016"}
	_check(catalog.identity("game-016") == tug and catalog.identity("rope_tug") == tug and harbor[3].name == "繩結拖船", "fourth harbor game keeps local four and global sixteen")
	_check(catalog.identity("game-017") == {"id": "game-017", "mode": "crab_marbles", "zone": "harbor", "local_index": 5, "photo_id": "photo-harbor-game-5", "devil_photo_id": "photo-harbor-devil-5", "achievement_id": "ACH_GAME_017"} and harbor[4].name == "蟹洞彈珠", "harbor game 5 keeps its regional identity")
	_check(catalog.identity("game-018") == {"id": "game-018", "mode": "cargo_balance", "zone": "harbor", "local_index": 6, "photo_id": "photo-harbor-game-6", "devil_photo_id": "photo-harbor-devil-6", "achievement_id": "ACH_GAME_018"} and harbor[5].name == "船艙配重", "harbor game 6 keeps its regional identity")
	_check(catalog.identity("game-012").photo_id == "photo-welcome-game-12", "welcome identity retains local numbering")
	_check(catalog.find("rowing_cargo") == harbor[0], "mode lookup returns a runtime definition")
	for invalid in ["game-%03d" % (all_games.size() + 1), "game-120", "game-14", "game-001 ", "", "res://game/minigames/session.gd"]:
		_check(catalog.find(invalid).is_empty() and catalog.identity(invalid).is_empty(), "unknown or malformed catalog key is rejected: " + invalid)
	welcome[0].name = "mutated"
	harbor[0].name = "mutated"
	all_games[0].name = "mutated"
	var found: Dictionary = catalog.find("rowing_cargo")
	found.zone = "mutated"
	var identity: Dictionary = catalog.identity("game-013")
	identity.zone = "mutated"
	_check(catalog.definitions()[0].name == "氣球快遞" and catalog.definitions("harbor")[0].name == "浪間小艇" and catalog.identity("game-013").zone == "harbor", "all catalog APIs return deep copies")
	var sources := {"welcome": catalog.definitions(), "harbor": catalog.definitions("harbor")}
	_check(catalog._validated_catalog(sources) == sources, "explicit parser boundary accepts delivered data")
	var invalid_sources: Array = []
	var bad: Dictionary = sources.duplicate(true)
	bad.welcome = {}
	invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.harbor.append(bad.harbor[0].duplicate(true))
	invalid_sources.append(bad)
	for field in ["name", "goal", "instructions", "ordinary", "devil", "devil_hint", "attraction_tag", "island_invitation"]:
		bad = sources.duplicate(true)
		bad.harbor[0][field] = "  "
		invalid_sources.append(bad)
	for field_value in [["id", "game-019"], ["id", "game-014"], ["id", "game-001"], ["mode", "balloon_delivery"], ["mode", "res://evil.gd"], ["zone", "welcome"], ["local_index", 13], ["local_index", true]]:
		bad = sources.duplicate(true)
		bad.harbor[0][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.welcome.reverse()
	invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.candy = []
	invalid_sources.append(bad)
	for invalid in invalid_sources:
		_check(catalog._validated_catalog(invalid).is_empty(), "malformed, duplicate or mismatched catalog data fails closed")
	_check(not ResourceLoader.has_cached("res://game/minigames/session.gd") and not ResourceLoader.has_cached("res://game/ui/tutorial_panel.gd"), "Progress and Catalog do not load Session or tutorial UI")
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: delivered game catalog, copies, regional identity and malformed data")
	quit(0 if failures.is_empty() else 1)
