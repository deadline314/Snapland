extends Node

const Catalog = preload("res://game/core/game_catalog.gd")
var main: Node
var failures: Array[String] = []

class ObservedMain extends "res://game/main.gd":
	var events: Array[Dictionary] = []
	var fail_original := false
	func _save_bounded_photo_image(image: Image,path: String) -> bool:
		if not fail_original or not path.ends_with("-original.png"):
			return super._save_bounded_photo_image(image,path)
		# A real destination directory makes the second PNG replacement fail.
		DirAccess.make_dir_recursive_absolute(path)
		var saved := super._save_bounded_photo_image(image,path)
		DirAccess.remove_absolute(path)
		return saved
	func _record_story_mission_event(event: Dictionary) -> void:
		events.append(event.duplicate(true))
		super._record_story_mission_event(event)

func _ready() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		get_tree().quit(1)
		return
	get_tree().create_timer(85).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	Progress.reset_progress()
	Progress.intro_seen = true
	get_window().size = Vector2i(1280,720)
	main = ObservedMain.new()
	get_tree().root.add_child(main)
	await _frames()
	if OS.get_cmdline_user_args().has("--retake-failure-child"):
		await _failed_saves()
		await _finish()
		return
	for method in ["_request_retake", "_practice_for_retake", "_retake_capture"]:
		check(main.has_method(method), "Main provides " + method)
	if not failures.is_empty():
		_finish()
		return
	main._show_game_info("game-001")
	check(not Progress.has_attempted_game("game-001"), "invitation never records attempt")
	main._show_game_rules("game-001")
	check(not Progress.has_attempted_game("game-001"), "rules never record attempt")
	main._practice_for_retake("game-013",true)
	check(main.session == null and not Progress.has_attempted_game("game-013"), "locked album cannot launch harbor practice")
	main._practice_for_retake("game-001",true)
	check(main.session != null and main.session.practice_mode and Progress.has_attempted_game("game-001"), "actual practice records attempt before cancel")
	main.session._leave_from_hud()
	check(main.modal_kind == "retake" and main.retake_target == {"id":"game-001","devil":true}, "immediate cancel restores same devil target")
	check(not Progress.photos.has("photo-welcome-game-1") and not Progress.photos.has("photo-welcome-devil-1"), "practice cancel grants neither card")
	main._close()
	main._launch_game(str(Catalog.find("game-002").mode),false,true)
	check(main.session != null and main.session.game_id == "game-002" and Progress.has_attempted_game("game-002"), "accepted launch aliases save canonical attempts")
	main._cancel_game()
	await _practice_result_return()
	main._launch_game("game-003",false)
	for wait_index in 150:
		if main.session == null: break
		await get_tree().create_timer(0.1).timeout
	check(main.session == null and main.modal_kind == "result", "no-input fountain round ends naturally as a real failure")
	check(Progress.photos.has("photo-welcome-game-3") and not Progress.photos.has("photo-welcome-devil-3"), "real failed formal round still collects ordinary only")
	check(not main.celebrate_on_close and main.events.is_empty(), "participation never celebrates or notifies story as success")
	main._close()
	_run_failed_save_child()
	# This suite supplies an image directly to the owner; native fixture separately proves shutter rendering.
	var image := Image.create(1280,720,false,Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	for id in ["game-001","game-013"]:
		if id == "game-013":
			# Synthetic old prerequisites only. The target's attempt uses real Session start/cancel.
			for index in range(3,9): Progress.grant_photo("photo-welcome-game-%d" % index)
		for devil in [true,false]:
			main._practice_for_retake(id,devil)
			check(main.session != null, "selected regional practice starts")
			main.session._leave_from_hud()
			var panel: Control = main.retake_panel
			var generation: int = main.retake_generation
			var before := Progress.coins
			var old_photos := Progress.photos.duplicate(true)
			var old_bytes: Dictionary={}
			for record in old_photos.values():
				for path in record.get("frames",[])+record.get("original_frames",[]):
					old_bytes[path]=FileAccess.get_file_as_bytes(str(path))
			panel._awaiting_result = true
			main._retake_capture(image,panel,generation,id,devil)
			var identity := Catalog.identity(id)
			var photo_id: String = identity.devil_photo_id if devil else identity.photo_id
			var record: Dictionary = Progress.photos.get(photo_id,{})
			check(record.get("acquisition_method") == "retake" and not record.get("challenge_earned",true), "selected retake has truthful provenance")
			check(record.get("frames",[]).size() == 1 and record.get("original_frames",[]).size() == 1, "retake persists both valid images")
			if not record.get("frames",[]).is_empty(): check(str(record.frames[0]).get_file().begins_with(photo_id+"-retake-"),"capture namespace belongs only to selected card")
			for old_id in old_photos: check(Progress.photos[old_id] == old_photos[old_id], "other card metadata remains unchanged")
			for path in old_bytes: check(FileAccess.get_file_as_bytes(str(path)) == old_bytes[path],"other card PNG bytes remain unchanged")
			check(Progress.coins == before + (40 if devil else 0), "one global receipt per game")
			var snapshot := Progress.photos.duplicate(true)
			main._retake_capture(image,panel,generation,id,devil)
			check(Progress.photos == snapshot, "double shutter cannot award twice")
			main._close()
			main._retake_capture(image,panel,generation,id,not devil)
			check(Progress.photos == snapshot, "closed stale capture cannot grant")
			await _frames()
	check(main.events.is_empty(), "retake and practice never dispatch story success")
	main._practice_for_retake("game-009",true)
	main.session._leave_from_hud()
	var closing_owner: Control=main.retake_panel
	var closing_generation: int=main.retake_generation
	main.quitting=true
	main._retake_capture(image,closing_owner,closing_generation,"game-009",true)
	check(not Progress.photos.has("photo-welcome-devil-9"),"shutdown cannot accept a pending shutter")
	main.quitting=false
	closing_owner.queue_free()
	main._retake_capture(image,closing_owner,closing_generation,"game-009",true)
	check(not Progress.photos.has("photo-welcome-devil-9"),"queued panel cannot accept a pending shutter")
	main._close()
	# Saved harbor recovery remains legitimate even if a historical profile lacks six cards.
	Progress.current_region = "harbor"
	Progress.photos.clear()
	main._launch_game("game-013",false,true)
	check(main.session != null and main.session.game_id == "game-013", "saved current harbor recovers without new gate")
	main._cancel_game()
	await _frames()
	await _writer_checks(image)
	_finish()

func _writer_checks(image: Image) -> void:
	var directory: String = main._photo_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("protected.png")
	check(main._save_bounded_photo_image(image,path), "write valid bounded PNG")
	var original := FileAccess.get_file_as_bytes(path)
	check(not main._save_bounded_photo_image(Image.create(4097,1,false,Image.FORMAT_RGBA8),path), "dimension limit rejected")
	check(FileAccess.get_file_as_bytes(path) == original, "dimension failure preserves old bytes")
	check(not main._save_bounded_photo_image(null,path), "invalid encode source rejected")
	check(FileAccess.get_file_as_bytes(path) == original, "invalid source preserves old bytes")
	if OS.has_feature("windows"):
		var held := FileAccess.open(path,FileAccess.READ)
		check(not main._save_bounded_photo_image(image,path), "Windows real held-file replacement failure rejected")
		held.close()
		check(FileAccess.get_file_as_bytes(path) == original, "held destination failure preserves old valid PNG bytes")
	var noise := PackedByteArray()
	noise.resize(2048*2048*4)
	var rng := RandomNumberGenerator.new()
	rng.seed=48251
	for index in range(0,noise.size(),4): noise.encode_u32(index,rng.randi())
	var oversized := Image.create_from_data(2048,2048,false,Image.FORMAT_RGBA8,noise)
	check(not main._save_bounded_photo_image(oversized,path), "real encoded PNG over byte cap rejected")
	check(FileAccess.get_file_as_bytes(path) == original, "oversized encoding preserves old valid PNG bytes")
	var block := directory.path_join("replacement-block.png")
	DirAccess.make_dir_recursive_absolute(block)
	var marker := FileAccess.open(block.path_join("keep"),FileAccess.WRITE)
	marker.store_string("protected directory")
	marker.close()
	check(not main._save_bounded_photo_image(image,block), "real replacement failure rejected")
	check(FileAccess.get_file_as_string(block.path_join("keep")) == "protected directory", "replacement failure preserves destination")
	var as_file := FileAccess.open(directory.path_join("parent-file"),FileAccess.WRITE)
	as_file.store_string("old parent")
	as_file.close()
	check(not main._save_bounded_photo_image(image,directory.path_join("parent-file/cannot.png")), "real encode destination failure rejected")
	var files := DirAccess.get_files_at(directory)
	for file in files: check(not file.contains(".staging-"), "failed writer leaves no staged files")
	check(FileAccess.get_file_as_bytes(path) == original, "all writer failures preserve prior valid file")

func _practice_result_return() -> void:
	main._practice_for_retake("game-011",true)
	for swap_index in 8:
		if main.session == null: break
		# Read the house puzzle solver; deliver only normal seat key presses.
		var pair: Array=main.session.bench_model._next_optimal_swap()
		for seat in pair:
			var event := InputEventKey.new()
			event.keycode=KEY_1+int(seat)
			event.pressed=true
			Input.parse_input_event(event)
			await _frames()
			event=InputEventKey.new()
			event.keycode=KEY_1+int(seat)
			event.pressed=false
			Input.parse_input_event(event)
			await _frames()
		await get_tree().create_timer(0.4).timeout
	check(main.modal_kind == "result" and main.session == null,"practice returns a natural result through actual bench inputs")
	check(not Progress.photos.has("photo-welcome-game-11") and not Progress.photos.has("photo-welcome-devil-11"),"natural practice result grants neither card")
	main._close()
	check(main.modal_kind == "retake" and main.retake_target == {"id":"game-011","devil":true},"practice result back restores selected devil entrance")
	main._close()

func _failed_saves() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	# Old welcome prerequisites are synthetic; every tested target launch is real.
	for index in range(7,13): Progress.grant_photo("photo-welcome-game-%d" % index)
	var before_bytes := FileAccess.get_file_as_bytes(save_path)
	DirAccess.make_dir_recursive_absolute(save_path+".tmp")
	print("EXPECT_PROGRESS_WRITE_FAILURE: "+save_path+".tmp")
	main._practice_for_retake("game-004",true)
	check(main.session == null and not Progress.has_attempted_game("game-004"), "atomic attempt failure disposes started Session and rolls back attempt")
	check(main.world.visible and main.world.is_processing() and not main.world.blocked and main.hud.visible, "failed attempt restores playable world")
	check(FileAccess.get_file_as_bytes(save_path) == before_bytes, "failed attempt preserves saved profile")
	main._launch_game("game-006",false,true)
	check(main.session != null and main.session.practice_mode and not main.session.ended and not Progress.has_attempted_game("game-006"), "generic practice stays playable without false persisted retake eligibility")
	await get_tree().create_timer(0.5).timeout
	check(main.session != null and main.session.minigame_hud._feedback.visible and main.session.minigame_hud._feedback_label.text.contains("本局可繼續"), "legacy generic practice retains visible unsaved notice after half a second")
	main._cancel_game(false)
	main._launch_game("game-013",false,true)
	check(main.session != null and main.session.active_driver != null and not Progress.has_attempted_game("game-013"), "generic driver launch stays playable without false attempt")
	await get_tree().create_timer(0.5).timeout
	check(main.session != null and main.session.minigame_hud._feedback.visible and main.session.minigame_hud._feedback_label.text.contains("本局可繼續"), "driver HUD retains visible unsaved notice after half a second")
	main._cancel_game(false)
	DirAccess.remove_absolute(save_path+".tmp")
	main._practice_for_retake("game-004",true)
	check(main.session != null and Progress.has_attempted_game("game-004"), "attempt retry launches and really saves")
	main.session._leave_from_hud()
	var owner: Control=main.retake_panel
	var generation: int=main.retake_generation
	var image := Image.create(1280,720,false,Image.FORMAT_RGBA8)
	image.fill(Color.GOLD)
	var directory: String=main._photo_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var files_before := DirAccess.get_files_at(directory)
	var photos_before := Progress.photos.duplicate(true)
	var coins_before := Progress.coins
	before_bytes=FileAccess.get_file_as_bytes(save_path)
	DirAccess.make_dir_recursive_absolute(save_path+".tmp")
	owner._awaiting_result=true
	print("EXPECT_PROGRESS_WRITE_FAILURE: "+save_path+".tmp")
	main._retake_capture(image,owner,generation,"game-004",true)
	check(Progress.photos == photos_before and Progress.coins == coins_before, "failed award preserves metadata and receipt")
	check(FileAccess.get_file_as_bytes(save_path) == before_bytes, "failed award preserves profile bytes")
	check(DirAccess.get_files_at(directory) == files_before, "failed award removes only newly owned capture files")
	check(not owner._saved and not owner._awaiting_result, "failed save acknowledges retry without collection success")
	DirAccess.remove_absolute(save_path+".tmp")
	main.fail_original=true
	owner._awaiting_result=true
	main._retake_capture(image,owner,generation,"game-004",true)
	check(Progress.photos == photos_before and Progress.coins == coins_before, "partial original write failure cannot grant card metadata")
	check(DirAccess.get_files_at(directory) == files_before, "partial original failure cleans this capture thumbnail")
	main.fail_original=false
	owner._awaiting_result=true
	main._retake_capture(image,owner,generation,"game-004",true)
	check(owner._saved and Progress.photos.has("photo-welcome-devil-4") and Progress.coins == coins_before+40, "failed capture retry really saves and awards once")
	main._close()
	await _frames()

func _run_failed_save_child() -> void:
	var original := OS.get_environment("SNAPLAND_SAVE_PATH")
	var isolated := original.get_base_dir().path_join("failure-profile.json")
	OS.set_environment("SNAPLAND_SAVE_PATH",isolated)
	var output: Array=[]
	var code := OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",ProjectSettings.globalize_path("res://"),"res://game/tests/test_photo_retake_main.tscn","--","--retake-failure-child"],output,true)
	OS.set_environment("SNAPLAND_SAVE_PATH",original)
	check(code == 0,"isolated real save-failure child passes")
	var expected := "ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % isolated
	var diagnostic_count := 0
	for line in str(output[0]).split("\n"):
		if line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:"):
			check(line.strip_edges() == expected,"exact save-failure diagnostic: "+line)
			diagnostic_count+=1
	check(diagnostic_count == 4,"exactly four intended Progress file failures, no other errors")

func _frames() -> void:
	for index in 3: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish() -> void:
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	await _frames()
	if failures.is_empty(): print("PASS: Main selected retakes, actual attempts, truthful awards and safe PNG replacement")
	get_tree().quit(0 if failures.is_empty() else 1)
