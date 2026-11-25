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
	var candy: Array = catalog.definitions("candy")
	var all_games: Array = catalog.all_definitions()
	_check(welcome == JSON.parse_string(FileAccess.get_file_as_string("res://game/data/welcome_games.json")), "default definitions preserve the original welcome row shape and order")
	_check(welcome.size() == 12 and harbor.size() == 12 and candy.size() == 12 and all_games.size() == 36, "only the 36 delivered games are exposed")
	for index in range(welcome.size()):
		_check(welcome[index].id == "game-%03d" % (index + 1), "welcome numbering stays ordered")
	_check(all_games == welcome + harbor + candy and catalog.definitions("nightmarket").is_empty(), "global order is welcome then harbor then delivered candy; upcoming regions remain unavailable")
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
	_check(catalog.identity("game-019") == {"id": "game-019", "mode": "buoy_relay", "zone": "harbor", "local_index": 7, "photo_id": "photo-harbor-game-7", "devil_photo_id": "photo-harbor-devil-7", "achievement_id": "ACH_GAME_019"} and harbor[6].name == "浮標接力", "harbor game 7 keeps its regional identity")
	_check(catalog.identity("game-020") == {"id": "game-020", "mode": "sail_chase", "zone": "harbor", "local_index": 8, "photo_id": "photo-harbor-game-8", "devil_photo_id": "photo-harbor-devil-8", "achievement_id": "ACH_GAME_020"} and harbor[7].name == "帆影追逐", "harbor game 8 keeps its regional identity")
	_check(catalog.identity("game-021") == {"id": "game-021", "mode": "shell_tide", "zone": "harbor", "local_index": 9, "photo_id": "photo-harbor-game-9", "devil_photo_id": "photo-harbor-devil-9", "achievement_id": "ACH_GAME_021"} and harbor[8].name == "貝殼聽潮", "harbor game 9 keeps its regional identity")
	_check(catalog.identity("game-022") == {"id": "game-022", "mode": "anchor_chain", "zone": "harbor", "local_index": 10, "photo_id": "photo-harbor-game-10", "devil_photo_id": "photo-harbor-devil-10", "achievement_id": "ACH_GAME_022"} and harbor[9].name == "錨鏈穿礁", "harbor game 10 keeps its regional identity")
	_check(catalog.identity("game-023") == {"id": "game-023", "mode": "gull_glide", "zone": "harbor", "local_index": 11, "photo_id": "photo-harbor-game-11", "devil_photo_id": "photo-harbor-devil-11", "achievement_id": "ACH_GAME_023"} and harbor[10].name == "海鳥借風", "harbor game 11 keeps its regional identity")
	_check(catalog.identity("game-024") == {"id": "game-024", "mode": "tide_lock", "zone": "harbor", "local_index": 12, "photo_id": "photo-harbor-game-12", "devil_photo_id": "photo-harbor-devil-12", "achievement_id": "ACH_GAME_024"} and harbor[11].name == "潮鐘合閘", "harbor game 12 keeps its regional identity")
	_check(catalog.identity("game-025") == {"id":"game-025", "mode":"sugar_bridge", "zone":"candy", "local_index":1, "photo_id":"photo-candy-game-1", "devil_photo_id":"photo-candy-devil-1", "achievement_id":"ACH_GAME_025"} and candy[0].name == "拉糖橋", "first candy game keeps local one and global twenty-five")
	var cookie := {"id":"game-026", "mode":"cookie_mold", "zone":"candy", "local_index":2, "photo_id":"photo-candy-game-2", "devil_photo_id":"photo-candy-devil-2", "achievement_id":"ACH_GAME_026"}
	_check(catalog.identity("game-026") == cookie and catalog.identity("cookie_mold") == cookie and candy[1].name == "餅乾翻模", "second candy game keeps local two and global twenty-six")
	var syrup := {"id":"game-027", "mode":"syrup_flood", "zone":"candy", "local_index":3, "photo_id":"photo-candy-game-3", "devil_photo_id":"photo-candy-devil-3", "achievement_id":"ACH_GAME_027"}
	_check(catalog.identity("game-027") == syrup and catalog.identity("syrup_flood") == syrup and candy[2].name == "糖漿分洪", "third candy game keeps local3/global027")
	var jelly := {"id":"game-028", "mode":"jelly_trampoline", "zone":"candy", "local_index":4, "photo_id":"photo-candy-game-4", "devil_photo_id":"photo-candy-devil-4", "achievement_id":"ACH_GAME_028"}
	_check(catalog.identity("game-028") == jelly and catalog.identity("jelly_trampoline") == jelly and candy[3].name == "果凍彈床", "fourth candy game keeps local4/global028")
	var chocolate := {"id":"game-029", "mode":"chocolate_etching", "zone":"candy", "local_index":5, "photo_id":"photo-candy-game-5", "devil_photo_id":"photo-candy-devil-5", "achievement_id":"ACH_GAME_029"}
	_check(catalog.identity("game-029") == chocolate and catalog.identity("chocolate_etching") == chocolate and candy[4].name == "巧克力蝕刻", "fifth candy game keeps local5/global029")
	var cotton := {"id":"game-030", "mode":"cotton_wind", "zone":"candy", "local_index":6, "photo_id":"photo-candy-game-6", "devil_photo_id":"photo-candy-devil-6", "achievement_id":"ACH_GAME_030"}
	_check(catalog.identity("game-030") == cotton and catalog.identity("cotton_wind") == cotton and candy[5].name == "棉糖捲風", "sixth candy game keeps local6/global030")
	var seesaw := {"id":"game-031", "mode":"bean_seesaw", "zone":"candy", "local_index":7, "photo_id":"photo-candy-game-7", "devil_photo_id":"photo-candy-devil-7", "achievement_id":"ACH_GAME_031"}
	_check(catalog.identity("game-031") == seesaw and catalog.identity("bean_seesaw") == seesaw and candy[6].name == "糖豆蹺蹺板", "seventh candy game keeps local7/global031")
	var ice := {"id":"game-032", "mode":"ice_slide", "zone":"candy", "local_index":8, "photo_id":"photo-candy-game-8", "devil_photo_id":"photo-candy-devil-8", "achievement_id":"ACH_GAME_032"}
	_check(catalog.identity("game-032") == ice and catalog.identity("ice_slide") == ice and candy[7].name == "冰糖滑塊", "eighth candy game keeps local8/global032")
	var filling := {"id":"game-033", "mode":"filling_press", "zone":"candy", "local_index":9, "photo_id":"photo-candy-game-9", "devil_photo_id":"photo-candy-devil-9", "achievement_id":"ACH_GAME_033"}
	_check(catalog.identity("game-033") == filling and catalog.identity("filling_press") == filling and candy[8].name == "夾心壓奏", "ninth candy game keeps local9/global033")
	var glider := {"id":"game-034", "mode":"paper_glide", "zone":"candy", "local_index":10, "photo_id":"photo-candy-game-10", "devil_photo_id":"photo-candy-devil-10", "achievement_id":"ACH_GAME_034"}
	_check(catalog.identity("game-034") == glider and catalog.identity("paper_glide") == glider and candy[9].name == "糖紙滑翔", "tenth candy game keeps local10/global034")
	var lift := {"id":"game-035", "mode":"bubble_lift", "zone":"candy", "local_index":11, "photo_id":"photo-candy-game-11", "devil_photo_id":"photo-candy-devil-11", "achievement_id":"ACH_GAME_035"}
	_check(catalog.identity("game-035") == lift and catalog.identity("bubble_lift") == lift and candy[10].name == "汽泡升降梯", "eleventh candy game keeps local11/global035")
	var draw := {"id":"game-036", "mode":"sugar_draw", "zone":"candy", "local_index":12, "photo_id":"photo-candy-game-12", "devil_photo_id":"photo-candy-devil-12", "achievement_id":"ACH_GAME_036"}
	_check(catalog.identity("game-036") == draw and catalog.identity("sugar_draw") == draw and candy[11].name == "熔糖抽絲", "twelfth candy game keeps local12/global036")
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
	var sources := {"welcome": catalog.definitions(), "harbor": catalog.definitions("harbor"), "candy": catalog.definitions("candy")}
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
	for field_value in [["id", "game-025"], ["id", "game-014"], ["id", "game-001"], ["mode", "balloon_delivery"], ["mode", "res://evil.gd"], ["zone", "welcome"], ["local_index", 13], ["local_index", true]]:
		bad = sources.duplicate(true)
		bad.harbor[0][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.welcome.reverse()
	invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.candy = []
	invalid_sources.append(bad)
	for field_value in [["id","game-025"],["id","game-027"],["mode","sugar_bridge"],["zone","harbor"],["local_index",1],["local_index",true]]:
		bad = sources.duplicate(true)
		bad.candy[1][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.candy.pop_back()
	invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.candy.append(bad.candy[1].duplicate(true))
	invalid_sources.append(bad)
	for field_value in [["id","game-026"],["id","game-028"],["mode","cookie_mold"],["zone","harbor"],["local_index",2],["local_index",true]]:
		bad = sources.duplicate(true)
		bad.candy[2][field_value[0]] = field_value[1]
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
