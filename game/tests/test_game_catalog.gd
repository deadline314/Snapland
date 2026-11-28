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
	var nightmarket: Array = catalog.definitions("nightmarket")
	var circus: Array = catalog.definitions("circus")
	var toy: Array = catalog.definitions("toy")
	var garden: Array = catalog.definitions("garden")
	var hotel: Array = catalog.definitions("hotel")
	var all_games: Array = catalog.all_definitions()
	_check(welcome == JSON.parse_string(FileAccess.get_file_as_string("res://game/data/welcome_games.json")), "default definitions preserve the original welcome row shape and order")
	_check(welcome.size() == 12 and harbor.size() == 12 and candy.size() == 12 and nightmarket.size() == 12 and circus.size() == 12 and toy.size() == 12 and garden.size() == 7 and hotel.size() == 4 and all_games.size() == 83, "only the 83 delivered games are exposed")
	for index in range(welcome.size()):
		_check(welcome[index].id == "game-%03d" % (index + 1), "welcome numbering stays ordered")
	_check(all_games == welcome + harbor + candy + nightmarket + circus + toy + garden + hotel and catalog.definitions("sky").is_empty(), "games retain global order and future regions remain unavailable")
	var booth := {"id":"game-049", "mode":"funhouse_booth", "zone":"circus", "local_index":1, "photo_id":"photo-circus-game-1", "devil_photo_id":"photo-circus-devil-1", "achievement_id":"ACH_GAME_049"}
	_check(catalog.identity("game-049") == booth and catalog.identity("funhouse_booth") == booth and circus[0].name == "哈哈鏡大頭貼" and circus[0].arcade == true, "first circus game has stable identities and the arcade flow flag")
	var reflection := {"id":"game-050", "mode":"fake_reflection", "zone":"circus", "local_index":2, "photo_id":"photo-circus-game-2", "devil_photo_id":"photo-circus-devil-2", "achievement_id":"ACH_GAME_050"}
	_check(catalog.identity("game-050") == reflection and catalog.identity("fake_reflection") == reflection and circus[1].name == "誰是假倒影" and circus[1].arcade == true, "second circus game has stable identities and the arcade flow flag")
	var dash := {"id":"game-061", "mode":"windup_dash", "zone":"toy", "local_index":1, "photo_id":"photo-toy-game-1", "devil_photo_id":"photo-toy-devil-1", "achievement_id":"ACH_GAME_061"}
	_check(catalog.identity("game-061") == dash and catalog.identity("windup_dash") == dash and toy[0].name == "發條衝刺" and toy[0].arcade == true, "first toy town game keeps its own global number and the arcade flow flag")
	var cuckoo := {"id":"game-062", "mode":"cuckoo_cue", "zone":"toy", "local_index":2, "photo_id":"photo-toy-game-2", "devil_photo_id":"photo-toy-devil-2", "achievement_id":"ACH_GAME_062"}
	_check(catalog.identity("game-062") == cuckoo and catalog.identity("cuckoo_cue") == cuckoo and toy[1].name == "整點咕咕" and toy[1].arcade == true, "second toy town game has stable identities and the arcade flow flag")
	var magnet := {"id":"game-063", "mode":"magnet_move", "zone":"toy", "local_index":3, "photo_id":"photo-toy-game-3", "devil_photo_id":"photo-toy-devil-3", "achievement_id":"ACH_GAME_063"}
	_check(catalog.identity("game-063") == magnet and catalog.identity("magnet_move") == magnet and toy[2].name == "磁鐵搬家" and toy[2].arcade == true,
		"the third toy town slot fills in behind the fifth and keeps its own number")
	var bridge := {"id":"game-064", "mode":"block_bridge", "zone":"toy", "local_index":4, "photo_id":"photo-toy-game-4", "devil_photo_id":"photo-toy-devil-4", "achievement_id":"ACH_GAME_064"}
	_check(catalog.identity("game-064") == bridge and catalog.identity("block_bridge") == bridge and toy[3].name == "積木拱橋" and toy[3].arcade == true,
		"the fourth toy town slot keeps its own number")
	var frog := {"id":"game-065", "mode":"spring_frog", "zone":"toy", "local_index":5, "photo_id":"photo-toy-game-5", "devil_photo_id":"photo-toy-devil-5", "achievement_id":"ACH_GAME_065"}
	_check(catalog.identity("game-065") == frog and catalog.identity("spring_frog") == frog and toy[4].name == "彈簧青蛙" and toy[4].arcade == true,
		"a zone may deliver out of order: the fifth toy town slot kept its own number before slots three and four arrived")
	var rails := {"id":"game-066", "mode":"track_switch", "zone":"toy", "local_index":6, "photo_id":"photo-toy-game-6", "devil_photo_id":"photo-toy-devil-6", "achievement_id":"ACH_GAME_066"}
	_check(catalog.identity("game-066") == rails and catalog.identity("track_switch") == rails and toy[5].name == "軌道換軌" and toy[5].arcade == true,
		"the sixth toy town slot keeps its own number")
	var puppet := {"id":"game-067", "mode":"puppet_strings", "zone":"toy", "local_index":7, "photo_id":"photo-toy-game-7", "devil_photo_id":"photo-toy-devil-7", "achievement_id":"ACH_GAME_067"}
	_check(catalog.identity("game-067") == puppet and catalog.identity("puppet_strings") == puppet and toy[6].name == "木偶牽線" and toy[6].arcade == true,
		"the seventh toy town slot keeps its own number")
	var tops := {"id":"game-068", "mode":"top_sumo", "zone":"toy", "local_index":8, "photo_id":"photo-toy-game-8", "devil_photo_id":"photo-toy-devil-8", "achievement_id":"ACH_GAME_068"}
	_check(catalog.identity("game-068") == tops and catalog.identity("top_sumo") == tops and toy[7].name == "陀螺相撲" and toy[7].arcade == true, "eighth toy town game has stable identities and the arcade flow flag")
	var dice := {"id":"game-069", "mode":"dice_tower", "zone":"toy", "local_index":9, "photo_id":"photo-toy-game-9", "devil_photo_id":"photo-toy-devil-9", "achievement_id":"ACH_GAME_069"}
	_check(catalog.identity("game-069") == dice and catalog.identity("dice_tower") == dice and toy[8].name == "骰塔改道" and toy[8].arcade == true,
		"the ninth toy town slot keeps its own number")
	var bonk := {"id":"game-070", "mode":"soldier_bonk", "zone":"toy", "local_index":10, "photo_id":"photo-toy-game-10", "devil_photo_id":"photo-toy-devil-10", "achievement_id":"ACH_GAME_070"}
	_check(catalog.identity("game-070") == bonk and catalog.identity("soldier_bonk") == bonk and toy[9].name == "敲敲玩具兵" and toy[9].arcade == true, "tenth toy town game has stable identities and the arcade flow flag")
	var kart := {"id":"game-071", "mode":"box_kart", "zone":"toy", "local_index":11, "photo_id":"photo-toy-game-11", "devil_photo_id":"photo-toy-devil-11", "achievement_id":"ACH_GAME_071"}
	_check(catalog.identity("game-071") == kart and catalog.identity("box_kart") == kart and toy[10].name == "紙盒變車" and toy[10].arcade == true,
		"the eleventh toy town slot keeps its own number")
	var music := {"id":"game-072", "mode":"music_box", "zone":"toy", "local_index":12, "photo_id":"photo-toy-game-12", "devil_photo_id":"photo-toy-devil-12", "achievement_id":"ACH_GAME_072"}
	_check(catalog.identity("game-072") == music and catalog.identity("music_box") == music and toy[11].name == "音盒補拍" and toy[11].arcade == true,
		"the twelfth toy town slot keeps its own number")
	var scenery := {"id":"game-051", "mode":"scenery_drop", "zone":"circus", "local_index":3, "photo_id":"photo-circus-game-3", "devil_photo_id":"photo-circus-devil-3", "achievement_id":"ACH_GAME_051"}
	_check(catalog.identity("game-051") == scenery and catalog.identity("scenery_drop") == scenery and circus[2].name == "舞台換景" and circus[2].arcade == true,
		"the scenery drop fills circus slot three between the delivered neighbours")
	var plates := {"id":"game-052", "mode":"plate_catch", "zone":"circus", "local_index":4, "photo_id":"photo-circus-game-4", "devil_photo_id":"photo-circus-devil-4", "achievement_id":"ACH_GAME_052"}
	_check(catalog.identity("game-052") == plates and catalog.identity("plate_catch") == plates and circus[3].name == "接飛碟" and circus[3].arcade == true,
		"a circus game delivered out of order keeps its catalogue slot four, its sticker and its achievement")
	var trick := {"id":"game-053", "mode":"hat_trick", "zone":"circus", "local_index":5, "photo_id":"photo-circus-game-5", "devil_photo_id":"photo-circus-devil-5", "achievement_id":"ACH_GAME_053"}
	_check(catalog.identity("game-053") == trick and catalog.identity("hat_trick") == trick and circus[4].name == "帽中套物" and circus[4].arcade == true,
		"the hat trick takes circus slot five")
	var spot := {"id":"game-054", "mode":"spot_dance", "zone":"circus", "local_index":6, "photo_id":"photo-circus-game-6", "devil_photo_id":"photo-circus-devil-6", "achievement_id":"ACH_GAME_054"}
	_check(catalog.identity("game-054") == spot and catalog.identity("spot_dance") == spot and circus[5].name == "追光躲步" and circus[5].arcade == true,
		"the spot dance takes circus slot six")
	var cannon := {"id":"game-055", "mode":"human_cannon", "zone":"circus", "local_index":7, "photo_id":"photo-circus-game-7", "devil_photo_id":"photo-circus-devil-7", "achievement_id":"ACH_GAME_055"}
	_check(catalog.identity("game-055") == cannon and catalog.identity("human_cannon") == cannon and circus[6].name == "人肉砲彈" and circus[6].arcade == true,
		"the human cannon keeps catalogue slot seven")
	var mirror := {"id":"game-056", "mode":"mirror_beam", "zone":"circus", "local_index":8, "photo_id":"photo-circus-game-8", "devil_photo_id":"photo-circus-devil-8", "achievement_id":"ACH_GAME_056"}
	_check(catalog.identity("game-056") == mirror and catalog.identity("mirror_beam") == mirror and circus[7].name == "折鏡迷箱" and circus[7].arcade == true,
		"the mirror beam takes circus slot eight")
	var wire := {"id":"game-057", "mode":"tightrope", "zone":"circus", "local_index":9, "photo_id":"photo-circus-game-9", "devil_photo_id":"photo-circus-devil-9", "achievement_id":"ACH_GAME_057"}
	_check(catalog.identity("game-057") == wire and catalog.identity("tightrope") == wire and circus[8].name == "走鋼索" and circus[8].arcade == true,
		"the tightrope keeps catalogue slot nine")
	var wave := {"id":"game-058", "mode":"crowd_wave", "zone":"circus", "local_index":10, "photo_id":"photo-circus-game-10", "devil_photo_id":"photo-circus-devil-10", "achievement_id":"ACH_GAME_058"}
	_check(catalog.identity("game-058") == wave and catalog.identity("crowd_wave") == wave and circus[9].name == "觀眾席波浪" and circus[9].arcade == true,
		"the crowd wave takes circus slot ten")
	var shadow := {"id":"game-059", "mode":"shadow_puppet", "zone":"circus", "local_index":11, "photo_id":"photo-circus-game-11", "devil_photo_id":"photo-circus-devil-11", "achievement_id":"ACH_GAME_059"}
	_check(catalog.identity("game-059") == shadow and catalog.identity("shadow_puppet") == shadow and circus[10].name == "影偶搭梯" and circus[10].arcade == true,
		"the shadow puppets take circus slot eleven")
	var ribbon := {"id":"game-060", "mode":"ribbon_spin", "zone":"circus", "local_index":12, "photo_id":"photo-circus-game-12", "devil_photo_id":"photo-circus-devil-12", "achievement_id":"ACH_GAME_060"}
	_check(catalog.identity("game-060") == ribbon and catalog.identity("ribbon_spin") == ribbon and circus[11].name == "謝幕回旋" and circus[11].arcade == true,
		"the ribbon spin fills the last circus slot")
	var still := {"id":"game-073", "mode":"hold_still", "zone":"garden", "local_index":1, "photo_id":"photo-garden-game-1", "devil_photo_id":"photo-garden-devil-1", "achievement_id":"ACH_GAME_073"}
	_check(catalog.identity("game-073") == still and catalog.identity("hold_still") == still and garden[0].name == "螢火蟲長曝光" and garden[0].arcade == true, "first greenhouse game keeps its own global number and the arcade flow flag")
	var dew := {"id":"game-074", "mode":"dew_bridge", "zone":"garden", "local_index":2, "photo_id":"photo-garden-game-2", "devil_photo_id":"photo-garden-devil-2", "achievement_id":"ACH_GAME_074"}
	_check(catalog.identity("game-074") == dew and catalog.identity("dew_bridge") == dew and garden[1].name == "露珠牽橋" and garden[1].arcade == true,
		"the second greenhouse slot fills in between the delivered neighbours and keeps its own number")
	var vine := {"id":"game-075", "mode":"vine_weave", "zone":"garden", "local_index":3, "photo_id":"photo-garden-game-3", "devil_photo_id":"photo-garden-devil-3", "achievement_id":"ACH_GAME_075"}
	_check(catalog.identity("game-075") == vine and catalog.identity("vine_weave") == vine and garden[2].name == "藤蔓編路" and garden[2].arcade == true,
		"the third greenhouse slot keeps its own number")
	var post := {"id":"game-076", "mode":"dandelion_post", "zone":"garden", "local_index":4, "photo_id":"photo-garden-game-4", "devil_photo_id":"photo-garden-devil-4", "achievement_id":"ACH_GAME_076"}
	_check(catalog.identity("game-076") == post and catalog.identity("dandelion_post") == post and garden[3].name == "蒲公英落郵" and garden[3].arcade == true,
		"greenhouse slot 4 keeps its own number")
	var lily := {"id":"game-077", "mode":"lily_hop", "zone":"garden", "local_index":5, "photo_id":"photo-garden-game-5", "devil_photo_id":"photo-garden-devil-5", "achievement_id":"ACH_GAME_077"}
	_check(catalog.identity("game-077") == lily and catalog.identity("lily_hop") == lily and garden[4].name == "睡蓮踏浪" and garden[4].arcade == true,
		"a greenhouse game keeps the number of the slot it fills, leaving slots still in design empty")
	var brolly := {"id":"game-079", "mode":"mushroom_brolly", "zone":"garden", "local_index":7, "photo_id":"photo-garden-game-7", "devil_photo_id":"photo-garden-devil-7", "achievement_id":"ACH_GAME_079"}
	_check(catalog.identity("game-079") == brolly and catalog.identity("mushroom_brolly") == brolly and garden[5].name == "蘑菇撐傘" and garden[5].arcade == true,
		"the next greenhouse game keeps its own slot number too")
	var code := {"id":"game-080", "mode":"firefly_code", "zone":"garden", "local_index":8, "photo_id":"photo-garden-game-8", "devil_photo_id":"photo-garden-devil-8", "achievement_id":"ACH_GAME_080"}
	_check(catalog.identity("game-080") == code and catalog.identity("firefly_code") == code and garden[6].name == "螢火蟲對暗號" and garden[6].arcade == true,
		"neighbouring slots fill without a gap")
	var corridor := {"id":"game-085", "mode":"page_corridor", "zone":"hotel", "local_index":1, "photo_id":"photo-hotel-game-1", "devil_photo_id":"photo-hotel-devil-1", "achievement_id":"ACH_GAME_085"}
	_check(catalog.identity("game-085") == corridor and catalog.identity("page_corridor") == corridor and hotel[0].name == "折頁走廊" and hotel[0].arcade == true,
		"the first hotel game keeps its own global number and the arcade flow flag")
	var sheet_slide := {"id":"game-086", "mode":"sheet_slide", "zone":"hotel", "local_index":2, "photo_id":"photo-hotel-game-2", "devil_photo_id":"photo-hotel-devil-2", "achievement_id":"ACH_GAME_086"}
	_check(catalog.identity("game-086") == sheet_slide and catalog.identity("sheet_slide") == sheet_slide and hotel[1].name == "被單滑梯" and hotel[1].arcade == true,
		"hotel slot 2 keeps its own global number and the arcade flow flag")
	var echo_key := {"id":"game-087", "mode":"echo_key", "zone":"hotel", "local_index":3, "photo_id":"photo-hotel-game-3", "devil_photo_id":"photo-hotel-devil-3", "achievement_id":"ACH_GAME_087"}
	_check(catalog.identity("game-087") == echo_key and catalog.identity("echo_key") == echo_key and hotel[2].name == "回聲鑰匙" and hotel[2].arcade == true,
		"hotel slot 3 keeps its own global number and the arcade flow flag")
	var dream_bubble := {"id":"game-088", "mode":"dream_bubble", "zone":"hotel", "local_index":4, "photo_id":"photo-hotel-game-4", "devil_photo_id":"photo-hotel-devil-4", "achievement_id":"ACH_GAME_088"}
	_check(catalog.identity("game-088") == dream_bubble and catalog.identity("dream_bubble") == dream_bubble and hotel[3].name == "夢泡搬運" and hotel[3].arcade == true,
		"hotel slot 4 keeps its own global number and the arcade flow flag")
	_check(all_games.filter(func(row: Dictionary) -> bool: return row.has("arcade") and row.zone not in ["circus", "toy", "garden", "hotel"]).is_empty(), "earlier games keep their own flow")
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
	var courier := {"id":"game-037", "mode":"rain_courier", "zone":"nightmarket", "local_index":1, "photo_id":"photo-nightmarket-game-1", "devil_photo_id":"photo-nightmarket-devil-1", "achievement_id":"ACH_GAME_037"}
	_check(catalog.identity("game-037") == courier and catalog.identity("rain_courier") == courier and nightmarket[0].name == "雨棚快遞", "night market game has stable local and global identity")
	var grill := {"id":"game-038", "mode":"skewer_grill", "zone":"nightmarket", "local_index":2, "photo_id":"photo-nightmarket-game-2", "devil_photo_id":"photo-nightmarket-devil-2", "achievement_id":"ACH_GAME_038"}
	_check(catalog.identity("game-038") == grill and catalog.identity("skewer_grill") == grill and nightmarket[1].name == "烤串翻面", "grill preserves stable night market identities")
	var lantern := {"id":"game-039", "mode":"lantern_crossing", "zone":"nightmarket", "local_index":3, "photo_id":"photo-nightmarket-game-3", "devil_photo_id":"photo-nightmarket-devil-3", "achievement_id":"ACH_GAME_039"}
	_check(catalog.identity("game-039") == lantern and catalog.identity("lantern_crossing") == lantern and nightmarket[2].name == "燈籠繩渡", "lantern route has stable night market identities")
	var coin := {"id":"game-040", "mode":"coin_bank_shot", "zone":"nightmarket", "local_index":4, "photo_id":"photo-nightmarket-game-4", "devil_photo_id":"photo-nightmarket-devil-4", "achievement_id":"ACH_GAME_040"}
	_check(catalog.identity("game-040") == coin and catalog.identity("coin_bank_shot") == coin and nightmarket[3].name == "銅板借彈", "coin game has stable night market identities")
	var scent := {"id":"game-041", "mode":"scent_trail", "zone":"nightmarket", "local_index":5, "photo_id":"photo-nightmarket-game-5", "devil_photo_id":"photo-nightmarket-devil-5", "achievement_id":"ACH_GAME_041"}
	_check(catalog.identity("game-041") == scent and catalog.identity("scent_trail") == scent and nightmarket[4].name == "香氣尋攤", "scent game has stable night market identities")
	var banner := {"id":"game-042", "mode":"banner_cart", "zone":"nightmarket", "local_index":6, "photo_id":"photo-nightmarket-game-6", "devil_photo_id":"photo-nightmarket-devil-6", "achievement_id":"ACH_GAME_042"}
	_check(catalog.identity("game-042") == banner and catalog.identity("banner_cart") == banner and nightmarket[5].name == "招幌避碰", "banner cart has stable night market identities")
	var pancake := {"id":"game-043", "mode":"pancake_fold", "zone":"nightmarket", "local_index":7, "photo_id":"photo-nightmarket-game-7", "devil_photo_id":"photo-nightmarket-devil-7", "achievement_id":"ACH_GAME_043"}
	_check(catalog.identity("game-043") == pancake and catalog.identity("pancake_fold") == pancake and nightmarket[6].name == "煎餅畫圓", "pancake fold has stable night market identities")
	var umbrella := {"id":"game-044", "mode":"umbrella_lights", "zone":"nightmarket", "local_index":8, "photo_id":"photo-nightmarket-game-8", "devil_photo_id":"photo-nightmarket-devil-8", "achievement_id":"ACH_GAME_044"}
	_check(catalog.identity("game-044") == umbrella and catalog.identity("umbrella_lights") == umbrella and nightmarket[7].name == "紙傘轉燈", "umbrella lights has stable night market identities")
	var soup := {"id":"game-045", "mode":"soup_tray", "zone":"nightmarket", "local_index":9, "photo_id":"photo-nightmarket-game-9", "devil_photo_id":"photo-nightmarket-devil-9", "achievement_id":"ACH_GAME_045"}
	_check(catalog.identity("game-045") == soup and catalog.identity("soup_tray") == soup and nightmarket[8].name == "湯碗擺渡", "soup tray has stable night market identities")
	var carts := {"id":"game-046", "mode":"cart_passing", "zone":"nightmarket", "local_index":10, "photo_id":"photo-nightmarket-game-10", "devil_photo_id":"photo-nightmarket-devil-10", "achievement_id":"ACH_GAME_046"}
	_check(catalog.identity("game-046") == carts and catalog.identity("cart_passing") == carts and nightmarket[9].name == "攤車會車", "cart passing has stable night market identities")
	var lantern_craft := {"id":"game-047", "mode":"sugar_lantern", "zone":"nightmarket", "local_index":11, "photo_id":"photo-nightmarket-game-11", "devil_photo_id":"photo-nightmarket-devil-11", "achievement_id":"ACH_GAME_047"}
	_check(catalog.identity("game-047") == lantern_craft and catalog.identity("sugar_lantern") == lantern_craft and nightmarket[10].name == "糖畫牽線", "sugar lantern craft has stable night market identities")
	var loadout := {"id":"game-048", "mode":"stall_loadout", "zone":"nightmarket", "local_index":12, "photo_id":"photo-nightmarket-game-12", "devil_photo_id":"photo-nightmarket-devil-12", "achievement_id":"ACH_GAME_048"}
	_check(catalog.identity("game-048") == loadout and catalog.identity("stall_loadout") == loadout and nightmarket[11].name == "收攤套疊", "stall loadout has stable night market identities")
	_check(catalog.identity("game-012").photo_id == "photo-welcome-game-12", "welcome identity retains local numbering")
	_check(catalog.find("rowing_cargo") == harbor[0], "mode lookup returns a runtime definition")
	for invalid in ["game-127", "game-120", "game-14", "game-001 ", "", "res://game/minigames/session.gd"]:
		_check(catalog.find(invalid).is_empty() and catalog.identity(invalid).is_empty(), "unknown or malformed catalog key is rejected: " + invalid)
	welcome[0].name = "mutated"
	harbor[0].name = "mutated"
	all_games[0].name = "mutated"
	var found: Dictionary = catalog.find("rowing_cargo")
	found.zone = "mutated"
	var identity: Dictionary = catalog.identity("game-013")
	identity.zone = "mutated"
	_check(catalog.definitions()[0].name == "氣球快遞" and catalog.definitions("harbor")[0].name == "浪間小艇" and catalog.identity("game-013").zone == "harbor", "all catalog APIs return deep copies")
	var sources := {"welcome": catalog.definitions(), "harbor": catalog.definitions("harbor"), "candy": catalog.definitions("candy"), "nightmarket": catalog.definitions("nightmarket"), "circus": catalog.definitions("circus"), "toy": catalog.definitions("toy"), "garden": catalog.definitions("garden"), "hotel": catalog.definitions("hotel")}
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
	for field_value in [["id","game-051"],["mode","rain_courier"],["zone","nightmarket"],["local_index",2],["name"," "]]:
		bad = sources.duplicate(true)
		bad.circus[0][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	for field_value in [["id","game-063"],["mode","fake_reflection"],["zone","circus"],["local_index",2]]:
		bad = sources.duplicate(true)
		bad.toy[0][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	for field_value in [["id","game-063"],["mode","cuckoo_cue"],["zone","toy"],["local_index",2]]:
		bad = sources.duplicate(true)
		bad.garden[0][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	for field_value in [["id","game-085"],["id","game-073"],["id","game-74"],["local_index",5]]:
		bad = sources.duplicate(true)
		bad.garden[1][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	bad = sources.duplicate(true)
	bad.garden.reverse()
	invalid_sources.append(bad)
	for field_value in [["id","game-097"],["mode","vine_weave"],["zone","garden"],["local_index",2]]:
		bad = sources.duplicate(true)
		bad.hotel[0][field_value[0]] = field_value[1]
		invalid_sources.append(bad)
	for zone: String in ["circus", "toy", "garden", "hotel"]:
		bad = sources.duplicate(true)
		bad.erase(zone)
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
