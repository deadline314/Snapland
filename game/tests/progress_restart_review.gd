extends Node
## Optional two-process persistence evidence; never uses a player's profile.
var failures: Array[String] = []
const FIELDS := ["photos","achievements","quests","visited","settings","appearance","equipped","owned_clothes","coins","wardrobe_rewarded_games","platform_pending_achievements","intro_seen","tutorial_seen_games","_extra_fields"]
func _ready() -> void:
	call_deferred("_run")
func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)
func _snapshot() -> Dictionary:
	var result := {}
	for field in FIELDS: result[field] = Progress.get(field)
	# Match the serialized numeric domain on both sides, including nested metadata.
	return JSON.parse_string(JSON.stringify(result))
func _digest(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
func _run() -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not path.is_absolute_path():
		push_error("Persistence review requires an isolated absolute SNAPLAND_SAVE_PATH")
		get_tree().quit(2)
		return
	var expected_path := path.get_base_dir().path_join("expected.json")
	if OS.get_cmdline_user_args().has("--write-review"):
		Progress.reset_progress()
		Progress.complete_game("game-001",true)
		_check(Progress.grant_photo("photo-welcome-explore-1",{"source":"two-process review"}),"writer grants one unique exploration photo")
		Progress.advance_quest("quest-001",2)
		Progress.set_setting("master_volume",0.35)
		_check(Progress.settings.master_volume==0.35,"writer saves master volume")
		Progress.set_setting("text_speed",1.5)
		_check(Progress.settings.text_speed==1.5,"writer saves text speed")
		Progress.set_setting("reduced_motion",true)
		_check(Progress.settings.reduced_motion==true,"writer saves reduced motion")
		Progress.set_setting("assist",true)
		_check(Progress.settings.assist==true,"writer saves assist")
		_check(Progress.set_appearance_batch({"skin":"bronze","species":"elf","gender":"neutral","hair":"curly","hair_color":"silver","face":"curious"}),"writer changes appearance")
		_check(Progress.buy_clothing("outfit-coral"),"writer purchases one outfit")
		_check(Progress.equip_clothing("outfit-coral"),"writer equips owned outfit")
		Progress._extra_fields["restart_review_future"] = {"preserved":true}
		_check(Progress.save_progress(),"writer saves complete progress")
		var file := FileAccess.open(expected_path,FileAccess.WRITE)
		_check(file!=null,"writer creates independent expected snapshot")
		if file!=null:
			file.store_string(JSON.stringify({"pid":OS.get_process_id(),"sha256":_digest(path),"snapshot":_snapshot()},"  "))
			file.close()
	else:
		var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		_check(expected is Dictionary,"reader loads writer's expected snapshot")
		if expected is Dictionary:
			_check(int(expected.pid)!=OS.get_process_id(),"reader is a genuinely new operating-system process")
			_check(expected.sha256==_digest(path),"startup preserves the exact saved file bytes")
			_check(expected.snapshot==_snapshot(),"all progress fields survive new-process startup")
		_check(Progress.photos.has("photo-welcome-game-1") and Progress.photos.has("photo-welcome-devil-1"),"ordinary and devil photos remain distinct")
		_check(Progress.achievements.has("ACH_GAME_001") and not Progress.platform_pending_achievements.is_empty(),"offline achievement and pending platform receipt survive")
		_check(Progress.quests.get("quest-001",0)==2,"unfinished quest resumes at the same step")
		_check(Progress.equipped.outfit=="outfit-coral" and Progress.owned_clothes.has("outfit-coral"),"ownership and selected outfit survive")
	for failure in failures: push_error("Persistence review: "+failure)
	if failures.is_empty(): print("PASS: two-process persistence ","writer" if OS.get_cmdline_user_args().has("--write-review") else "reader"," pid=",OS.get_process_id())
	get_tree().quit(0 if failures.is_empty() else 1)
