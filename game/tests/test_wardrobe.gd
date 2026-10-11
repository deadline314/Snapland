extends SceneTree

class FailingWriteProgress:
	extends "res://game/core/progress.gd"
	func save_progress() -> bool:
		return false

var failures: Array[String] = []
var progress: Node

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running the wardrobe suite.")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--fault-test"):
		call_deferred("_run_filesystem_fault_test")
		return
	call_deferred("_run")

func _run() -> void:
	progress = load("res://game/core/progress.gd").new()
	get_root().add_child(progress)
	await process_frame
	progress.reset_progress()
	_check(progress.coins == 120, "new profile starts with 120 coins")
	_check(progress.owned_clothes.has("outfit-tide") and progress.equipped.outfit == "outfit-tide", "free harbor jacket is owned and equipped")
	var starting_coins: int = progress.coins
	var options: Dictionary = progress.appearance_options()
	for index in range(100):
		var skin_options: Array = options.skin
		var appearance_value: String = skin_options[index % skin_options.size()].id
		_check(progress.set_appearance("skin", appearance_value), "valid free appearance option is accepted")
	_check(progress.coins == starting_coins, "repeated appearance changes are free")
	var full_appearance := {"skin": "olive", "species": "elf", "gender": "female", "hair": "bob", "hair_color": "silver", "face": "smiling"}
	_check(progress.set_appearance_batch(full_appearance), "all appearance fields can be applied in one validated save")
	_check(progress.appearance == full_appearance, "appearance batch applies every field together")
	var before_invalid_batch: Dictionary = progress.appearance.duplicate(true)
	_check(not progress.set_appearance_batch({"skin": "deep", "face": "invalid"}), "invalid appearance batch is rejected")
	_check(progress.appearance == before_invalid_batch, "invalid batch leaves all appearance fields unchanged")
	_check(progress.set_appearance("gender", "neutral"), "single appearance change saves")
	_check(progress.set_appearance("gender", "neutral"), "setting the same appearance again succeeds for free")
	_check(not progress.set_appearance("unknown", "warm") and not progress.set_appearance("skin", "unknown"), "invalid appearance values are rejected")
	_check(not progress.equip_clothing("hat-straw"), "unowned clothing cannot be equipped")
	_check(progress.buy_clothing("outfit-coral"), "affordable outfit can be purchased")
	_check(progress.coins == 40 and progress.owned_clothes.has("outfit-coral"), "purchase deducts once and adds item to collection")
	_check(not progress.buy_clothing("outfit-coral"), "duplicate purchase is rejected")
	_check(not progress.buy_clothing("outfit-unknown"), "unknown item cannot be purchased")
	_check(progress.coins == 40 and progress.owned_clothes.count("outfit-coral") == 1, "rejected purchases leave balance and collection unchanged")
	_check(progress.equip_clothing("outfit-coral"), "owned outfit can be equipped")
	_check(progress.equip_clothing("outfit-coral"), "equipping the already worn item succeeds")
	progress.complete_game("game-001", false)
	_check(progress.coins == 80, "first game completion awards 40 coins")
	progress.complete_game("game-001", false)
	_check(progress.coins == 80, "repeated game completion does not award coins twice")
	progress.complete_game("game-002", false)
	_check(progress.coins == 120, "first completion of a second supported game awards 40 coins")
	progress.complete_game("game-002", false)
	_check(progress.coins == 120, "second game's reward is also one-time")
	for invalid_game_id in ["game-013", "game-1", "id"]:
		progress.complete_game(invalid_game_id, false)
		progress.complete_game(invalid_game_id, false)
	_check(progress.coins == 120, "unsupported and malformed game IDs never award currency")
	_check(progress.buy_clothing("hat-straw"), "game reward can fund a hat purchase")
	_check(progress.equip_clothing("hat-straw"), "owned hat can be equipped")
	_check(progress.equip_clothing("hat-none"), "free hat removal can be equipped")
	_check(not progress.buy_clothing("outfit-gold"), "insufficient balance rejects purchase")
	_check(progress.coins == 60 and progress.owned_clothes.has("outfit-coral") and progress.owned_clothes.has("hat-straw"), "insufficient balance preserves all existing collection")
	_check(progress.save_progress(), "wardrobe state saves")
	progress._reset_memory()
	progress.load_progress()
	var saved_skin_is_valid := false
	for option: Dictionary in options.skin:
		if option.id == progress.appearance.skin:
			saved_skin_is_valid = true
	_check(saved_skin_is_valid, "appearance option survives reload")
	_check(progress.coins == 60 and progress.owned_clothes.has("outfit-coral") and progress.owned_clothes.has("hat-straw"), "currency and all owned items survive reload")
	_check(progress.equipped.outfit == "outfit-coral" and progress.equipped.hat == "hat-none", "equipped items survive reload")
	progress.complete_game("game-002", false)
	_check(progress.coins == 60, "reward receipt survives reload and prevents repeat payout")
	progress.coins = progress.MAX_COINS - 10
	progress.complete_game("game-003", false)
	_check(progress.coins == progress.MAX_COINS, "game rewards clamp currency at the safe limit")
	_check(progress.wardrobe_item("outfit-tide").itemdefid == 51001 and not progress.wardrobe_item("outfit-tide").tradable and not progress.wardrobe_item("outfit-tide").marketable, "catalog has unique offline item definition")
	_check(progress.wardrobe_items().size() == 8, "wardrobe catalog exposes all clothing and hat choices")

	var save_path: String = progress._save_path()
	var fixture := FileAccess.open(save_path, FileAccess.WRITE)
	_check(fixture != null, "can prepare a legacy save fixture")
	if fixture != null:
		fixture.store_string('{"photos":{"photo-welcome-explore-1":{"source":"old"},"photo-welcome-game-1":{"game_id":"game-001"}},"achievements":{"ACH_GAME_001":true},"settings":{"text_speed":1.5},"future_field":{"kept":true}}')
		fixture.close()
		progress.load_progress()
		_check(progress.appearance == progress.DEFAULT_APPEARANCE and progress.equipped == progress.DEFAULT_EQUIPPED, "old save without wardrobe fields gets safe defaults")
		_check(progress.coins == 120 and progress.owned_clothes.has("outfit-tide"), "old save receives starter wardrobe and currency")
		_check(progress.photos.has("photo-welcome-explore-1") and progress.achievements.has("ACH_GAME_001") and progress.settings.text_speed == 1.5, "old photos achievements and settings remain intact")
		_check(progress._extra_fields.get("future_field", {}).get("kept", false), "unknown save fields remain intact through wardrobe migration")
		progress.complete_game("game-001", false)
		_check(progress.coins == 120 and progress.wardrobe_rewarded_games.has("game-001"), "legacy completion photo is marked paid without a retroactive reward")
		progress.photos.erase("photo-welcome-game-1")
		_check(progress.save_progress(), "legacy reward receipt persists")
		progress._reset_memory()
		progress.load_progress()
		progress.complete_game("game-001", false)
		_check(progress.coins == 120, "legacy completion receipt prevents a later repeat reward")

	fixture = FileAccess.open(save_path, FileAccess.WRITE)
	_check(fixture != null, "can prepare corrupt wardrobe fixture")
	if fixture != null:
		fixture.store_string('{"photos":{"photo-welcome-explore-2":{"source":"preserve"}},"appearance":{"skin":"not-a-skin","unexpected":"value"},"owned_clothes":["outfit-missing",7],"equipped":{"outfit":"outfit-gold","hat":"hat-missing"},"coins":1000001,"wardrobe_rewarded_games":["game-002","game-002"]}')
		fixture.close()
		progress.load_progress()
		_check(progress.appearance.skin == "warm" and not progress.appearance.has("unexpected"), "unknown and invalid appearance fields fall back safely")
		_check(progress.owned_clothes.has("outfit-tide") and not progress.owned_clothes.has("outfit-missing"), "unknown and malformed owned items are skipped")
		_check(progress.equipped.outfit == "outfit-tide" and progress.equipped.hat == "hat-none", "unknown equipped items use safe defaults")
		_check(progress.coins == 120 and progress.photos.has("photo-welcome-explore-2"), "over-limit currency resets while unrelated photo progress survives")
		_check(progress.wardrobe_rewarded_games == ["game-002"], "duplicate game reward receipts are normalized")
	var nan_coins_save: Dictionary = progress._validated_payload({"coins": NAN}, save_path)
	_check(not nan_coins_save.has("coins"), "non-finite currency is rejected")

	var failing_progress = FailingWriteProgress.new()
	get_root().add_child(failing_progress)
	await process_frame
	failing_progress.set("appearance", progress.DEFAULT_APPEARANCE.duplicate(true))
	failing_progress.set("equipped", progress.DEFAULT_EQUIPPED.duplicate(true))
	failing_progress.set("owned_clothes", ["outfit-tide", "outfit-coral"])
	failing_progress.set("coins", 120)
	var previous_appearance: Dictionary = failing_progress.get("appearance").duplicate(true)
	_check(not failing_progress.set_appearance("skin", "deep"), "single appearance save failure returns false")
	_check(failing_progress.get("appearance") == previous_appearance, "single appearance save failure rolls back")
	_check(not failing_progress.set_appearance_batch(full_appearance), "appearance batch save failure returns false")
	_check(failing_progress.get("appearance") == previous_appearance, "batch save failure rolls back all appearance fields")
	_check(not failing_progress.equip_clothing("outfit-coral"), "equipment save failure returns false")
	_check(failing_progress.get("equipped").outfit == "outfit-tide", "equipment save failure rolls back")
	_check(not failing_progress.buy_clothing("hat-straw"), "purchase save failure returns false")
	_check(failing_progress.get("coins") == 120 and not failing_progress.get("owned_clothes").has("hat-straw"), "purchase save failure rolls back currency and ownership")
	failing_progress.queue_free()

	if failures.is_empty():
		print("PASS: wardrobe runtime checks")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run_filesystem_fault_test() -> void:
	var fault_progress: Node = load("res://game/core/progress.gd").new()
	get_root().add_child(fault_progress)
	await process_frame
	fault_progress.reset_progress()
	var save_path: String = fault_progress._save_path()
	var blocked_path := save_path + ".blocked"
	var blocker := FileAccess.open(blocked_path, FileAccess.WRITE)
	if blocker == null:
		push_error("Unable to prepare isolated wardrobe fault fixture.")
		quit(1)
		return
	blocker.store_string("file blocks directory creation")
	blocker.close()
	OS.set_environment("SNAPLAND_SAVE_PATH", blocked_path.path_join("profile.json"))
	print("EXPECTED: isolated wardrobe filesystem save failure")
	var purchase_succeeded: bool = fault_progress.buy_clothing("outfit-coral")
	OS.set_environment("SNAPLAND_SAVE_PATH", save_path)
	DirAccess.remove_absolute(blocked_path)
	if purchase_succeeded or fault_progress.coins != 120 or fault_progress.owned_clothes.has("outfit-coral"):
		push_error("Wardrobe filesystem fault did not roll back the failed purchase.")
		quit(1)
		return
	print("PASS: isolated wardrobe filesystem rollback")
	quit(0)
