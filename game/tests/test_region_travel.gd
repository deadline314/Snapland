extends Node
const MainScene = preload("res://game/main.tscn")
const Catalog = preload("res://game/core/game_catalog.gd")
const Routes = preload("res://game/core/region_routes.gd")
const GATE_STATUSES := {
	"6 張 · 不消耗": ["harbor", "candy", "nightmarket"],
	"30 張 · 不消耗": ["circus", "toy", "garden"],
	"60 張 · 不消耗": ["hotel", "sky", "cinema"],
}
var main: Node
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Region travel needs an absolute isolated save path")
		get_tree().quit(1)
		return
	get_window().size=Vector2i(1280,720)
	if OS.get_cmdline_user_args().has("--region-travel-failure-child"):
		await _failure_child()
		return
	Progress.reset_progress()
	Progress.intro_seen=true
	Progress.prologue_seen=true
	await _spawn()
	_check(main.has_method("_travel_to_region"), "Main has guarded regional travel")
	if not main.has_method("_travel_to_region"):
		await _finish()
		return
	var original: Node=main.world
	_check(main.world_region=="welcome", "fresh profile selects welcome")
	_check_gate_statuses()
	_check(not main._travel_to_region("moon") and not main._travel_to_region("welcome"), "unknown/same destinations do nothing")
	for index in range(1,6): Progress.photos["photo-welcome-game-%d"%index]={}
	_check(not main._travel_to_region("harbor") and not main._travel_to_region("candy") and main.world==original, "five ordinary cards cannot enter either delivered gate")
	main._interact("gate:candy","糖果工廠")
	_check(_labels(main.overlay).contains("還差 1 張") and main.overlay.find_child("TravelCandyButton",true,false)==null, "candy gate explains the exact ordinary-card difference")
	main._close()
	original.interaction_requested.emit("gate:nightmarket", "霓虹夜市")
	_check(_labels(main.overlay).contains("還差 1 張") and main.overlay.find_child("TravelNightmarketButton", true, false) == null,
		"Nightmarket gate shows the missing card and offers no travel")
	main._close()
	Progress.photos["photo-welcome-devil-1"]={}
	Progress.photos["postcard-time-dawn"]={}
	_check(not main._travel_to_region("harbor") and not main._travel_to_region("candy"), "devil cards and postcards do not replace six ordinary cards")
	_check(not main._travel_to_region("nightmarket") and main.world == original and Progress.current_region == "welcome",
		"five ordinary cards plus devil and postcard collections cannot enter Nightmarket")
	# A sixth card from a different region proves admission uses the global count.
	Progress.photos["photo-harbor-game-1"]={}
	_check(Progress.normal_count()==6 and Progress.normal_count_for_zone("welcome")==5, "global threshold fixture is distinct and regional")
	main._refresh()
	main._show_map()
	await _frames(2)
	var welcome_map: Node=main.overlay.find_child("MapGate_harbor",true,false)
	_check(welcome_map!=null, "welcome retains its station map")
	welcome_map.pressed.emit()
	_check(_labels(main.overlay).contains("可前往"), "welcome map truthfully shows open harbor")
	var candy_gate: Button=main.overlay.find_child("MapGate_candy",true,false)
	candy_gate.pressed.emit()
	_check(_labels(main.overlay).contains("糖果工廠｜可前往") and candy_gate.tooltip_text.contains("不消耗"), "welcome map truthfully shows open candy with free-return qualification")
	main._close()
	main._start_dialogue([{ "speaker":"票票", "text":"測試對話" }],Callable())
	_check(not main._travel_to_region("harbor"), "dialogue owns the world")
	main._cancel_dialogue()
	main.capture_mode=true
	_check(not main._travel_to_region("harbor"), "capture owns the world")
	main.capture_mode=false
	main.session=main.Session.new()
	_check(not main._travel_to_region("harbor"), "session owns the world")
	main.session.free()
	main.session=null
	Progress.set_setting("reduced_motion",true)
	main._select_time_phase("night")
	_check(Progress.set_appearance_batch({"skin":"olive","species":"elf","gender":"female","hair":"bob","hair_color":"silver","face":"smiling"}), "nondefault current look saves")
	_check(Progress.equip_clothing("outfit-rainvest"), "current owned outfit saves")
	var before := _snapshot()
	await _nightmarket_trip(before)
	original = main.world
	main._interact("gate:harbor","潮汐碼頭")
	var travel: Button=main.overlay.find_child("TravelHarborButton",true,false)
	_check(travel!=null, "qualified gate has an explicit travel button")
	if travel==null:
		await _finish()
		return
	travel.pressed.emit()
	_check(main.changing_region and main.world==original and Progress.current_region=="harbor", "save precedes the deferred move")
	var old_area: String=main.area_label.text
	original.area_changed.emit("stale old area")
	_check(main.area_label.text==old_area and not main._travel_to_region("welcome"), "transition ignores old events and rejects reentry")
	await _frames(4)
	_check(main.world==original and main.world_region=="harbor" and _world_count()==1, "the island stays one world and the saved harbor is where the walker stands")
	_check(_at(main.world.arrival_point("harbor")) and main.world.standing_region()=="harbor" and main.region_world()!=main.world and main.region_world().embedded_in==main.world, "fast travel sets the walker down at the harbor district built into the island")
	_check(main.audio._active_context=="harbor" and main.region_world().reduced_motion and main.region_world().night, "harbor applies current settings/time/audio")
	_check(main.region_world().avatar_appearance==Progress.appearance and main.region_world().avatar_equipped==Progress.equipped, "harbor reapplies complete current look")
	_check(main.normal_count_label.text.contains("1 / 18") and main.devil_count_label.text.contains("0 / 12"), "harbor HUD uses local numerators")
	main.world.nearest=main.region_world().points[0]
	_check(not main._context_prompt().is_empty(), "optional coastal prompt is safe")
	await _harbor_ui(before)
	for tide in [false,true]:
		var harbor: Node=main.region_world()
		harbor.set_tide(tide)
		main._interact("harbor:ferry:shore","免費渡船")
		_check(_at(harbor.to_global(harbor.LIGHTHOUSE_DOCK)), "free ferry reaches lighthouse in either tide")
		main._interact("harbor:ferry:lighthouse","免費渡船")
		_check(_at(harbor.to_global(harbor.SHORE_DOCK)), "free ferry reaches shore in either tide")
		_check(_snapshot()==before, "tides and ferry grant and consume nothing")
		var island: Node=main.world
		var saved_cards: Dictionary=Progress.photos.duplicate(true)
		Progress.photos.clear()
		# Emit from the real world signal: its stack must survive the deferred move.
		island.interaction_requested.emit("region:welcome","返回迎賓大道")
		await _frames(4)
		_check(main.world==island and main.world_region=="welcome", "free return in either tide keeps the one island world")
		_check(_at(main.world.PLAZA_ARRIVAL) and main.world.standing_region()=="welcome", "return sets the walker down on the plaza")
		_check(Progress.photos.is_empty(), "free return requires no cards and grants none")
		Progress.photos=saved_cards
		main._show_pause()
		_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)!=null, "welcome boat replay remains available after return")
		main._close()
		main.arrival_stamp.dismiss()
		_check(main._travel_to_region("harbor"), "repeat qualified trip starts")
		await _frames(4)
		_check(not main.arrival_stamp.showing() and Progress.arrival_stamps.has("harbor"), "a repeat trip to the harbor shows no second stamp")
	await _candy_trips(before)
	_check(_snapshot()==before, "repeated trips preserve all rewards and appearance")
	_check(_world_count()==1, "steady state has exactly one world")
	_check(Progress.save_progress(), "harbor profile saves for restart")
	await _dispose()
	Progress.load_progress()
	Progress.intro_seen=false
	Progress.prologue_seen=false
	await _spawn()
	_check(main.world_region=="harbor" and main.world.standing_region()=="harbor" and main.boat_stage==null and main.modal_kind=="", "saved harbor restart stands in the harbor and skips welcome boat/arrival")
	_check(Progress.arrival_stamps.has("harbor") and Progress.arrival_stamps.has("nightmarket") and not main.arrival_stamp.showing(), "arrival stamps survive a restart and are not pressed again")
	main._show_map()
	main.overlay.find_child("RegionGamesButton",true,false).pressed.emit()
	Progress.reset_progress()
	await _frames(4)
	_check(main.world_region=="welcome" and Progress.current_region=="welcome" and _world_count()==1 and main.modal_kind=="", "reset from game entries rebuilds actual welcome world and closes the old map")
	for index in range(1,7): Progress.photos["photo-welcome-game-%d"%index]={}
	_check(main._travel_to_region("candy"), "prepare live candy reset")
	await _frames(4)
	Progress.reset_progress()
	await _frames(4)
	_check(main.world_region=="welcome" and Progress.current_region=="welcome" and _world_count()==1 and Progress.photos.is_empty(), "reset from candy rebuilds one welcome world without retained local state")
	await _dispose()
	# Missing and malformed region saves preserve legacy welcome startup.
	for supplied in [null,"moon"]:
		var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Progress._save_path()))
		payload.intro_seen=true
		if supplied==null: payload.erase("current_region")
		else: payload.current_region=supplied
		var file := FileAccess.open(Progress._save_path(),FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
		Progress.load_progress()
		await _spawn()
		_check(main.world_region=="welcome" and main.boat_stage==null, "legacy/invalid saved region starts welcome")
		await _dispose()
	for region in ["circus", "toy", "garden", "hotel", "sky", "cinema"]:
		await _same_batch_trip(region)
	await _failure_process()
	await _finish()

func _check_gate_statuses() -> void:
	for expected: String in GATE_STATUSES:
		for region: String in GATE_STATUSES[expected]:
			var label := main.world.get_node_or_null("GateStatus_" + region) as Label3D
			_check(label != null and label.text == expected, "physical %s gate shows %s" % [region, expected])

func _nightmarket_trip(before: Dictionary) -> void:
	var welcome: Node = main.world
	welcome.interaction_requested.emit("gate:nightmarket", "霓虹夜市")
	var travel := main.overlay.find_child("TravelNightmarketButton", true, false) as Button
	_check(travel != null and travel.tooltip_text.contains("不消耗"), "six-card Nightmarket gate offers free travel")
	if travel == null:
		main._close()
		return
	travel.pressed.emit()
	await _frames(4)
	var reached: bool = main.world_region == "nightmarket" and Progress.current_region == "nightmarket"
	_check(reached and main.world == welcome and _world_count() == 1 and _snapshot() == before and _at(main.world.arrival_point("nightmarket")),
		"Nightmarket gate takes the walker to the saved market without changing collections or rewards")
	if not reached:
		return
	_check(Progress.arrival_stamps.has("nightmarket") and main.arrival_stamp.showing() and main.arrival_stamp.region == "nightmarket",
		"the first trip to Nightmarket presses its arrival stamp and saves it")
	var market: Node = main.world
	market.interaction_requested.emit("region:welcome", "返回迎賓大道")
	await _frames(4)
	_check(main.world_region == "welcome" and Progress.current_region == "welcome" and main.world == market
		and _world_count() == 1 and _snapshot() == before and _at(main.world.PLAZA_ARRIVAL), "Nightmarket returns freely to the plaza and preserves the collection")

func _same_batch_trip(region: String) -> void:
	Progress.reset_progress()
	Progress.intro_seen = true
	Progress.prologue_seen = true
	var title := Routes.title(region)
	var prefix := region.capitalize()
	var gate := "gate:" + region
	# One card short of the region's threshold, from several regions.
	var threshold := Routes.threshold(region)
	var ordinary := {"welcome": 12, "harbor": 12, "candy": 5} if threshold == 30 else {"welcome": 12, "harbor": 12, "candy": 12, "nightmarket": 12, "circus": 11}
	var last_card := "photo-candy-game-6" if threshold == 30 else "photo-circus-game-12"
	for source_region in ordinary:
		var count: int = ordinary[source_region]
		for index in range(1, count + 1):
			Progress.photos["photo-%s-game-%d" % [source_region, index]] = {}
	Progress.photos["photo-welcome-devil-1"] = {}
	Progress.photos["postcard-time-dawn"] = {}
	Progress.coins = 147
	_check(Progress.normal_count() == threshold - 1 and Progress.save_progress(), title + " fixture saves one card short of its threshold plus collectibles")
	await _spawn()
	var welcome: Node = main.world
	welcome.interaction_requested.emit(gate, title)
	_check(_labels(main.overlay).contains("還差 1 張") and main.overlay.find_child(Routes.travel_button(region), true, false) == null
		and not main._travel_to_region(region), "one card short shows the exact shortage for " + title)
	main._close()
	Progress.photos[last_card] = {}
	var before := _snapshot()
	welcome.interaction_requested.emit(gate, title)
	var travel := main.overlay.find_child(Routes.travel_button(region), true, false) as Button
	_check(Progress.normal_count() == threshold and travel != null and travel.tooltip_text.contains("%d 張" % threshold) and travel.tooltip_text.contains("不消耗"),
		"%d different ordinary cards enable the actual entrance for %s" % [threshold, title])
	if travel == null:
		await _dispose()
		return
	travel.pressed.emit()
	await _frames(4)
	var reached: bool = main.world_region == region and Progress.current_region == region
	_check(reached and main.world == welcome and _snapshot() == before and _world_count() == 1 and main.world.standing_region() == region, title + " entrance is saved without spending, inside the one island world")
	if not reached:
		await _dispose()
		return
	await _dispose()
	Progress.load_progress()
	await _spawn()
	_check(main.world_region == region and main.region_world()._point_by_id("region:welcome").position == main.region_world().ENTRY
		and main.world.standing_region() == region and _snapshot() == before and main.boat_stage == null, "new Main restores " + title + " and preserves the existing profile")
	main._show_map()
	await _frames(3)
	var map: Node = main.overlay.find_child(prefix + "MapPanel", true, false)
	var delivered: Array = Catalog.definitions(region)
	var games_button := main.overlay.find_child("RegionGamesButton", true, false) as Button
	_check(map != null and map.snapshot == _with_picks(main.region_world().map_snapshot()) and (games_button != null) == (not delivered.is_empty()),
		title + " map reports actual terrain and offers game entries only for delivered games")
	for definition: Dictionary in delivered:
		_check(not main.region_world()._point_by_id(definition.id).is_empty() and map != null and _labels(map).contains(str(definition.name)),
			title + " map lists the physical stand of " + str(definition.id))
	if map != null:
		await _regional_map_location_flow(map)
	if games_button != null:
		games_button.pressed.emit()
		await _frames(3)
		var entries: Node = main.overlay.find_child("RegionalGameEntriesGrid", true, false)
		_check(entries != null and entries.get_child_count() == delivered.size() and (entries.get_child(0) as Button).text == str(delivered[0].name),
			title + " game entry list names exactly its delivered games")
		main._show_map()
		await _frames(3)
	var leave := main.overlay.find_child(prefix + "ReturnButton", true, false) as Button
	_check(leave != null and _within_viewport(leave) and leave.tooltip_text.contains("免費"), title + " map includes a reachable free return")
	if leave != null:
		leave.pressed.emit()
		await _frames(4)
		_check(main.world_region == "welcome" and Progress.current_region == "welcome" and _snapshot() == before,
			title + " map return persists and retains the entire collection")
		_check(_at(main.world.PLAZA_ARRIVAL), title + " returns to the plaza")
		if region == "garden":
			var reopened: bool = main._travel_to_region(region)
			_check(reopened, "Garden can be reopened from the same Welcome gate")
			if reopened:
				await _frames(5)
				await _physics_frames(2)
				_check(main.world.nearest.get("id") == "region:welcome" and main.world.nearest.get("region") == "garden", "Garden safe entry faces the physical free return")
				main.world.interact()
				await _frames(5)
				_check(main.world_region == "welcome" and Progress.current_region == "welcome" and _snapshot() == before,
					"Garden physical return resumes and writes only the destination")
	await _dispose()

func _candy_trips(before: Dictionary) -> void:
	for trip in range(2):
		var old: Node=main.world
		_check(main._travel_to_region("candy"), "six global ordinary cards admit candy from harbor")
		_check(main.changing_region and main.world==old and Progress.current_region=="candy", "candy saves before the walker moves")
		old.interaction_requested.emit("region:welcome","stale return")
		_check(not main._travel_to_region("welcome"), "candy transition rejects old interaction and reentry")
		await _frames(4)
		_check(main.world==old and main.world_region=="candy" and _world_count()==1 and _at(main.world.arrival_point("candy")), "candy is a walk away in the same island world")
		_check(main.region_world().embedded_in==main.world and main.region_world().reduced_motion and main.region_world().night, "candy district shares the island and reapplies settings/time")
		_check(main.region_world().avatar_appearance==Progress.appearance and main.region_world().avatar_equipped==Progress.equipped and main.audio._active_context=="plaza", "candy reapplies appearance and uses a valid existing music context")
		_check(main.normal_count_label.text.contains("0 / 18") and main.devil_count_label.text.contains("0 / 12") and not main.quest_label.visible, "candy HUD uses planned collection targets and no local tasks")
		var stale := Node3D.new()
		var temperature: int=main.region_world().map_snapshot().temperature
		main._on_world_interaction_requested("candy:temperature","stale temperature",stale)
		main._on_world_interaction_requested("region:welcome","stale return",stale)
		main._on_world_area_changed("stale area",stale)
		_check(main.region_world().map_snapshot().temperature==temperature and not main.changing_region and not main.area_label.text.contains("stale"), "late events from a different world cannot operate the new world")
		stale.free()
		# Welcome's guide and games are a long walk away: the world never offers them here.
		await _physics_frames(2)
		var offered: Dictionary=main.world.nearest
		_check(str(offered.get("region",""))=="candy" and main.world.player.global_position.distance_to(_point("guide").position)>60.0
			and main.world.player.global_position.distance_to(_point("game-001").position)>60.0, "standing in candy offers only candy's own points")
		for state in range(3):
			main.world.interaction_requested.emit("candy:temperature","溫度觀察台")
			_check(main.modal_kind=="" and main.region_world().map_snapshot().temperature==(temperature+state+1)%3 and main.toast.text.contains("不影響進度"), "candy observation cycles in place without a modal")
		main.world.player.global_position=main.region_world().to_global(Vector3(0,1,0))
		main.world.player.velocity=Vector3(4,3,2)
		main._interact("candy:reset","返回入口")
		_check(main.world.player.velocity==Vector3.ZERO and _at(main.region_world().to_global(main.region_world().ENTRY)), "candy reset clears velocity at the factory entry")
		await _candy_ui()
		_check(_snapshot()==before and Progress.photos.keys().all(func(id): return not str(id).begins_with("photo-candy-")), "candy observations and menus grant and consume nothing")
		if trip==0:
			main.region_world().cycle_temperature()
			_check(main.region_world().map_snapshot().temperature!=0, "restart fixture has changed observation state")
			_check(Progress.save_progress(), "candy profile saves for restart")
			await _dispose()
			Progress.load_progress()
			Progress.intro_seen=false
			Progress.prologue_seen=false
			await _spawn()
			_check(main.world_region=="candy" and main.world.standing_region()=="candy" and main.boat_stage==null and main.modal_kind=="" and _world_count()==1, "saved candy restart stands in candy and skips welcome intro")
			_check(main.region_world().map_snapshot().temperature==0, "candy temperature is not persistent progress")
			Progress.intro_seen=true
			Progress.prologue_seen=true
		var saved_cards: Dictionary=Progress.photos.duplicate(true)
		Progress.photos.clear()
		var island: Node=main.world
		island.interaction_requested.emit("region:welcome","返回迎賓大道")
		await _frames(4)
		_check(main.world==island and main.world_region=="welcome" and _world_count()==1, "candy return is permanently free with no cards")
		_check(_at(main.world.PLAZA_ARRIVAL) and Progress.photos.is_empty(), "candy returns safely to the plaza without rewards")
		Progress.photos=saved_cards
		main._interact("gate:candy","糖果工廠")
		var travel: Button=main.overlay.find_child("TravelCandyButton",true,false)
		_check(travel!=null and travel.tooltip_text.contains("不消耗"), "qualified candy gate has a truthful explicit travel action")
		main._close()
		_check(main._travel_to_region("harbor"), "existing harbor remains reachable after candy return")
		await _frames(4)

func _candy_ui() -> void:
	main._show_pause()
	_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)==null and _labels(main.overlay).contains("0 / 18"), "candy pause shows local collection target and no boat replay")
	main._close()
	var expected_map: Dictionary=main.region_world().map_snapshot()
	main._show_map()
	await _frames(3)
	var map: Node=main.overlay.find_child("CandyMapPanel",true,false)
	_check(map!=null and main.overlay.find_child("MapStop_game-001",true,false)==null and main.overlay.find_child("HarborMapTide",true,false)==null, "candy map has factory terrain without welcome stations or harbor tide")
	if map!=null:
		_check(map.snapshot==_with_picks(expected_map) and _labels(map).contains("觀察台") and _labels(map).contains("免費"), "candy map reflects real bounds terrain points position and temperature")
		await _regional_map_location_flow(map)
	main._close()
	main._show_album()
	await _frames(3)
	var selector: OptionButton=main.overlay.find_child("AlbumRegionSelector",true,false)
	var book: Node=selector.get_parent().get_parent()
	_check(selector.item_count==Routes.ORDER.size() and selector.selected==2 and book._region=="candy" and book._entries().size()==Catalog.definitions("candy").size() and _labels(book).contains("拉糖橋") and _labels(book).contains("餅乾翻模") and _labels(book).contains("糖漿分洪") and _labels(book).contains("果凍彈床") and _labels(book).contains("巧克力蝕刻"), "candy album shows all delivered local games")
	var ordinary_slots := [18,12,Catalog.definitions("candy").size(),Catalog.definitions("nightmarket").size()+1,Catalog.definitions("circus").size()+2,Catalog.definitions("toy").size()+2,Catalog.definitions("garden").size()+2,Catalog.definitions("hotel").size(),Catalog.definitions("sky").size(),Catalog.definitions("cinema").size()]
	for index in Routes.ORDER.size():
		selector.select(index)
		selector.item_selected.emit(index)
		_check(book._region==Routes.ORDER[index] and book._entries().size()==ordinary_slots[index], "regional album retains its delivered sources")
		if book._region == "circus":
			var circus_ids: Array = book._entries().map(func(entry: Dictionary) -> String: return entry.id)
			_check(circus_ids == ["photo-circus-game-1", "photo-circus-game-2", "photo-circus-game-3", "photo-circus-game-4", "photo-circus-game-5", "photo-circus-game-6", "photo-circus-game-7", "photo-circus-game-8", "photo-circus-game-9", "photo-circus-game-10", "photo-circus-game-11", "photo-circus-game-12", "photo-circus-story-1", "photo-circus-quest-1"] and book._entries()[12].story_region == "circus" and book._entries()[13].story_errand == "circus"
				and _labels(book).contains("哈哈鏡大頭貼") and _labels(book).contains("誰是假倒影") and _labels(book).contains("接飛碟") and _labels(book).contains("人肉砲彈") and _labels(book).contains("走鋼索") and _labels(book).contains("舞台換景") and _labels(book).contains("帽中套物") and _labels(book).contains("追光躲步") and _labels(book).contains("折鏡迷箱") and _labels(book).contains("觀眾席波浪") and _labels(book).contains("影偶搭梯") and _labels(book).contains("謝幕回旋"),
				"Circus lists its delivered games under their own catalogue slots and its regional story source")
		elif book._region == "toy":
			var toy_ids: Array = book._entries().map(func(entry: Dictionary) -> String: return entry.id)
			_check(toy_ids == ["photo-toy-game-1", "photo-toy-game-2", "photo-toy-game-3", "photo-toy-game-4", "photo-toy-game-5", "photo-toy-game-6", "photo-toy-game-7", "photo-toy-game-8", "photo-toy-game-9", "photo-toy-game-10", "photo-toy-game-11", "photo-toy-game-12", "photo-toy-story-1", "photo-toy-quest-1"] and book._entries()[12].story_region == "toy" and book._entries()[13].story_errand == "toy"
				and _labels(book).contains("阿浪") and _labels(book).contains("發條衝刺") and _labels(book).contains("整點咕咕") and _labels(book).contains("磁鐵搬家") and _labels(book).contains("積木拱橋") and _labels(book).contains("軌道換軌") and _labels(book).contains("木偶牽線") and _labels(book).contains("骰塔改道") and _labels(book).contains("紙盒變車") and _labels(book).contains("音盒補拍") and _labels(book).contains("彈簧青蛙") and _labels(book).contains("陀螺相撲") and _labels(book).contains("敲敲玩具兵"),
				"Toy Town album lists its delivered games and its physical story without fake collectible entries")
		elif book._region == "garden":
			var garden_ids: Array = book._entries().map(func(entry: Dictionary) -> String: return entry.id)
			var garden_games: Array = Catalog.definitions("garden")
			var expected_ids: Array = garden_games.map(func(row: Dictionary) -> String: return Catalog.identity(row.id).photo_id)
			_check(garden_ids == expected_ids + ["photo-garden-story-1", "photo-garden-quest-1"] and expected_ids.has("photo-garden-game-5") and book._entries()[-2].story_region == "garden" and book._entries().back().story_errand == "garden"
				and _labels(book).contains("票票") and garden_games.all(func(row: Dictionary) -> bool: return _labels(book).contains(row.name)),
				"Garden album lists each delivered game under its own slot number and its story without speculative slots")
		elif book._region == "hotel":
			var hotel_ids: Array = book._entries().map(func(entry: Dictionary) -> String: return entry.id)
			_check(hotel_ids.has("photo-hotel-game-1") and _labels(book).contains("折頁走廊"),
				"Hotel album lists its delivered game under its own slot number")
		elif book._region == "sky":
			var sky_ids: Array = book._entries().map(func(entry: Dictionary) -> String: return entry.id)
			_check(sky_ids.has("photo-sky-game-1") and sky_ids.has("photo-sky-game-2") and sky_ids.has("photo-sky-game-7") and sky_ids.has("photo-sky-game-8") and sky_ids.has("photo-sky-game-9") and sky_ids.has("photo-sky-game-10")
				and _labels(book).contains("雲梯換層") and _labels(book).contains("紙翼穿峽") and _labels(book).contains("羽球上升流") and _labels(book).contains("繩橋共振") and _labels(book).contains("風箏追風") and _labels(book).contains("落星接網"),
				"Sky park album lists each delivered game under its own slot number")
	main._close()
	main._show_tasks()
	_check(_labels(main.overlay).contains("糖果工廠目前沒有當地任務") and main.overlay.find_child("Task_quest-001",true,false)==null, "candy tasks name the current region and preserve welcome quest destination")
	main._close()
	main._show_achievements()
	await _frames(3)
	var stamps: GridContainer=main.overlay.find_child("MinigameStampGrid",true,false)
	_check(stamps!=null and stamps.get_child_count()==Catalog.definitions("candy").size() and _labels(main.overlay).contains("糖廠") and _labels(main.overlay).contains("拉糖橋") and _labels(main.overlay).contains("餅乾翻模") and _labels(main.overlay).contains("糖漿分洪") and _labels(main.overlay).contains("果凍彈床") and _labels(main.overlay).contains("巧克力蝕刻"), "candy achievement summary has all real local game stamps")
	main._close()
	main._show_ticket()
	var available := Catalog.definitions("candy").size()
	_check(_labels(main.overlay).contains("%d / 12" % available) and _labels(main.overlay).contains("其餘 %d 款準備中" % (12 - available)), "candy ticket explains its real current content")
	var guide: Button=main.overlay.find_child("TicketAction7",true,false)
	_check(guide.text=="工廠圖解教學", "ticket names the available factory lessons")
	guide.pressed.emit()
	await _frames(3)
	var choices: GridContainer=main.overlay.find_child("CandyTutorialChoices",true,false)
	_check(choices!=null and choices.columns==2 and choices.get_child_count()==Catalog.definitions("candy").size(), "candy guide offers all delivered lessons")
	for game: Dictionary in Catalog.definitions("candy"):
		var game_id: String = game.id
		var action: Button=main.overlay.find_child("CandyTutorial_"+game_id,true,false)
		_check(action!=null, "guide exposes "+game_id)
		if action==null: continue
		action.pressed.emit()
		await _frames(3)
		_check(is_instance_valid(main.tutorial_panel) and main.tutorial_target==game_id, "guide opens selected delivered lesson "+game_id)
		main._tutorial_close()
	main._close()
	main._show_settings()
	main._close()
	_check(main.world.visible and main.region_world().visible and not main.world.blocked and main.audio._active_context=="plaza", "candy settings safely restore world input and valid music")

func _harbor_ui(before: Dictionary) -> void:
	main._show_pause()
	_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)==null, "harbor pause has no boat replay")
	main._close()
	main._show_boat_prologue()
	_check(main.boat_stage==null, "harbor refuses boat replay directly")
	main._show_map()
	await _frames(3)
	var map: Node=main.overlay.find_child("HarborMapPanel",true,false)
	_check(map!=null and main.overlay.find_child("MapStop_game-001",true,false)==null, "harbor map uses real terrain without welcome stations")
	_check(map.snapshot.bounds==main.region_world().BOUNDS and map.snapshot.player==main.region_world().player_spot(), "map snapshot reflects actual world")
	await _regional_map_location_flow(map)
	main._close()
	main._show_album()
	await _frames(3)
	var selector: OptionButton=main.overlay.find_child("AlbumRegionSelector",true,false)
	var book: Node=selector.get_parent().get_parent()
	_check(book._region=="harbor" and book._entries().size()==preload("res://game/core/game_catalog.gd").definitions("harbor").size() and book._entries()[0].id=="photo-harbor-game-1" and book._entries()[1].id=="photo-harbor-game-2", "harbor collection shows every delivered local game in order")
	selector.select(0)
	selector.item_selected.emit(0)
	_check(book._region=="welcome" and book._entries().size()==18, "switching back retains welcome's original eighteen sources")
	main._close()
	main._show_tasks()
	_check(_labels(main.overlay).contains("沒有當地任務") and main.overlay.find_child("Task_quest-001",true,false)==null, "harbor tasks explain welcome destination")
	main._close()
	main._show_settings()
	Progress.set_setting("ui_scale",1.25)
	main._close()
	_check(main.audio._active_context=="harbor" and main.world.visible and not main.world.blocked, "settings returns to harbor audio and input")
	main._launch_game("game-001",false)
	_check(main.session!=null, "existing welcome game guide remains usable")
	main._cancel_game()
	_check(main.session==null and main.world_region=="harbor" and main.audio._active_context=="harbor", "cancel welcome minigame restores harbor audio")
	_check(_snapshot()==before, "menus, settings and game cancellation grant nothing")

func _regional_map_location_flow(map: Node) -> void:
	var window := get_window()
	var previous_size := window.size
	var previous_scale_size := window.content_scale_size
	var previous_aspect := window.content_scale_aspect
	var previous_text_scale: float=Progress.settings.ui_scale
	window.content_scale_size=Vector2i(800,600)
	window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	window.size=Vector2i(800,600)
	Progress.set_setting("ui_scale",1.25)
	await _frames(6)
	var locations: HFlowContainer=map.find_child("*MapLocations",true,false)
	var readable: bool=locations!=null and locations.get_child_count()==map.snapshot.points.size()
	if locations!=null:
		for entry: Label in locations.get_children():
			if entry.get_line_count()!=1 or not locations.get_global_rect().grow(0.5).encloses(entry.get_global_rect()): readable=false
			if not window.get_visible_rect().grow(0.5).encloses(entry.get_global_rect()): readable=false
	_check(readable,"%s map flows complete numbered locations on one line within flow and viewport bounds at 800x600 / 1.25" % main.world_region)
	_check(_within_viewport(map) and _within_viewport(main.modal_footer), "%s real map and fixed footer fit 800x600 / 1.25" % main.world_region)
	if main.world_region=="harbor":
		# Twelve games, the tide clock, two ferry piers, the lighthouse note, the way home and the 逆潮港 gate.
		_check(map.snapshot.points.size()==18, "harbor regression uses all eighteen real locations")
		var entrance: Button=main.overlay.find_child("RegionGamesButton",true,false)
		_check(entrance!=null and main.modal_footer.get_child_count()==2, "regional map has one game entrance and fixed back action")
		if entrance!=null:
			entrance.pressed.emit()
			await _frames(6)
			var grid: GridContainer=main.overlay.find_child("RegionalGameEntriesGrid",true,false)
			var delivered: Array=preload("res://game/core/game_catalog.gd").definitions("harbor")
			_check(main.modal_kind=="region_games" and grid!=null, "game entrance opens its separate page")
			if grid!=null:
				_check(grid.columns==2 and grid.get_child_count()==12 and delivered.size()==12, "entry grid contains all twelve delivered games in two columns")
				_check(_within_viewport(grid) and _within_viewport(main.modal_footer) and main.overlay.find_children("*","ScrollContainer",true,false).is_empty(), "complete entry page and fixed back fit without scrolling")
				for definition: Dictionary in delivered:
					var action: Button=grid.get_node_or_null("HarborGame"+str(definition.id))
					_check(action!=null, "entry page preserves stable button for "+str(definition.id))
					if action==null: continue
					var font := action.get_theme_font("font")
					var font_size := action.get_theme_font_size("font_size")
					var text_size := font.get_string_size(action.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
					text_size.y=maxf(text_size.y,font.get_height(font_size))
					_check(_within_viewport(action) and action.size.y>=44 and action.size.x>=text_size.x+action.get_theme_stylebox("normal").get_minimum_size().x and action.size.y>=text_size.y+action.get_theme_stylebox("normal").get_minimum_size().y, "readable complete entry and 44px target for "+str(definition.id))
					# Reopen the page between invitations so every callback is exercised.
					main.overlay.find_child("HarborGame"+str(definition.id),true,false).pressed.emit()
					_check(main.modal_kind=="game_info" and main.overlay.get_child(0).definition.id==definition.id, "entry opens its exact game invitation: "+str(definition.id))
					main._show_region_games()
					await _frames(3)
					grid=main.overlay.find_child("RegionalGameEntriesGrid",true,false)
			var back: Button=main.overlay.find_child("MenuBackButton",true,false)
			_check(back!=null and back.text.contains("地圖"), "entry back explicitly names its map destination")
			if back!=null: back.pressed.emit()
			await _frames(3)
			_check(main.modal_kind=="map" and main.overlay.find_child("HarborMapPanel",true,false)!=null, "entry back returns to the real regional map")
			main.overlay.find_child("RegionGamesButton",true,false).pressed.emit()
			main._close()
			await _frames(3)
			_check(main.modal_kind=="map", "entry Escape close follows the same map return")
	window.content_scale_size=previous_scale_size
	window.content_scale_aspect=previous_aspect
	window.size=previous_size
	Progress.set_setting("ui_scale",previous_text_scale)
	await _frames(4)

func _within_viewport(control: Control) -> bool:
	return control.is_visible_in_tree() and get_viewport().get_visible_rect().grow(0.5).encloses(control.get_global_rect())

func _failure_process() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var child_path := save_path.get_base_dir().path_join("travel-failure-child/progress.json")
	OS.set_environment("SNAPLAND_SAVE_PATH",child_path)
	var output: Array=[]
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--audio-driver","Dummy","--rendering-method","gl_compatibility","--max-fps","120","--quit-after","3600","res://game/tests/test_region_travel.tscn","--","--region-travel-failure-child"],output,true)
	OS.set_environment("SNAPLAND_SAVE_PATH",save_path)
	var expected := "ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path
	var errors: Array[String]=[]
	var passed := false
	var child_output := str(output[0] if not output.is_empty() else "")
	for line in child_output.split("\n"):
		var clean := line.strip_edges()
		if clean.contains("ERROR:"): errors.append(clean)
		if clean=="PASS: region travel failed save retains live world and permits retry": passed=true
	_check(code==0 and passed and errors==[expected,expected,expected], "isolated travel IO failure: exit=%d passed=%s expected=%s errors=%s output_tail=%s" % [code,passed,expected.left(500),JSON.stringify(errors).left(1000),child_output.right(3000)])

func _failure_child() -> void:
	Progress.reset_progress()
	Progress.intro_seen=true
	for index in range(1,7): Progress.photos["photo-welcome-game-%d"%index]={}
	_check(Progress.save_progress(), "failure fixture saves")
	await _spawn()
	for destination in ["harbor","candy","welcome"]:
		var origin: String=main.world_region
		main._show_map()
		var old: Node=main.world
		var player: Transform3D=old.player.transform
		var camera: Transform3D=old.camera.transform
		var flags := [old.blocked,old.is_processing(),old.is_physics_processing(),main.modal_kind]
		var before := _snapshot()
		var path := Progress._save_path()
		var saved := FileAccess.get_file_as_string(path)
		_check(DirAccess.make_dir_absolute(path+".tmp")==OK, "block temporary write")
		_check(not main._travel_to_region(destination), "failed durable write rejects travel")
		_check(main.world==old and Progress.current_region==origin and main.world_region==origin and not main.changing_region, "failure retains world identity and region flags")
		_check(old.player.transform==player and old.camera.transform==camera and flags==[old.blocked,old.is_processing(),old.is_physics_processing(),main.modal_kind], "failure retains player camera and input/modal state")
		_check(_snapshot()==before and FileAccess.get_file_as_string(path)==saved and main.toast.text.contains("再試"), "failure leaves save/rewards intact with retry message")
		DirAccess.remove_absolute(path+".tmp")
		_check(main._travel_to_region(destination), "same gate supports retry")
		await _frames(4)
		_check(main.world_region==destination and main.world==old and main.world.standing_region()==destination, "retry reaches saved destination in the same world")
	await _dispose()
	for failure in failures: push_error("FAIL: "+failure)
	if failures.is_empty(): print("PASS: region travel failed save retains live world and permits retry")
	get_tree().quit(0 if failures.is_empty() else 1)

func _spawn() -> void:
	main=MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)

## True when the walker stands where `spot` is (world space, height aside).
func _at(spot: Vector3) -> bool:
	var feet: Vector3 = main.world.player.global_position
	return Vector2(feet.x - spot.x, feet.z - spot.z).length() < 0.1

func _physics_frames(count: int) -> void:
	for index in range(count): await get_tree().physics_frame

func _point(id: String) -> Dictionary:
	for point in main.world.points:
		if point.id==id: return point
	return {}

func _world_count() -> int:
	var count := 0
	for child in main.get_children():
		if child is Node3D: count+=1
	return count

func _labels(node: Node) -> String:
	var text := str(node.text) if node is Label else ""
	for child in node.get_children(): text+=_labels(child)
	return text

func _snapshot() -> Dictionary:
	var result := {}
	for field in ["coins","photos","achievements","quests","visited","appearance","equipped","owned_clothes","_extra_fields"]:
		var value = Progress.get(field)
		result[field]=value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func _dispose() -> void:
	if not is_instance_valid(main): return
	main.quitting=true
	main.audio.shutdown()
	main.world.area_changed.emit("海風碼頭")
	await get_tree().create_timer(0.2).timeout
	_check(main.audio._active_context.is_empty(), "pending area events respect quitting")
	main.free()
	main=null
	await _frames(3)

func _finish() -> void:
	await _dispose()
	for failure in failures: push_error("FAIL: "+failure)
	if failures.is_empty(): print("PASS: region travel admission, lifecycle, scoped UI, restart, and unchanged rewards")
	get_tree().quit(0 if failures.is_empty() else 1)


## The map also carries today's recommended booths (MAIN-58); everything else must equal the world's own snapshot.
func _with_picks(world_snapshot: Dictionary) -> Dictionary:
	var expected := world_snapshot.duplicate(true)
	expected["daily_picks"] = main._daily_picks()
	return expected
