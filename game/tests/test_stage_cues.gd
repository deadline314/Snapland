extends Node
## Dialogue staging cues through Main: framing, emotes, holds, pantomime, reduced motion and full restore.

const MainScene = preload("res://game/main.tscn")
const Story = preload("res://game/story/story_director.gd")
var main: Node
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Stage cue tests need an absolute isolated save path")
		get_tree().quit(1)
		return
	_check(Story.cue_valid({"cue": {"frame": "imp", "emote": "!", "hold": 1.0}}), "known cue validates")
	_check(not Story.cue_valid({"cue": {"shake": 1}}), "unknown cue key is rejected")
	_check(not Story.cue_valid({"cue": {"emote": "lol"}}), "unknown emote is rejected")
	_check(not Story.cue_valid({"pantomime": true}), "pantomime without a cue is rejected")
	_check(not Story.cue_valid({"cue": {"hold": 9}}), "overlong hold is rejected")

	Progress.reset_progress()
	Progress.prologue_seen = true
	Progress.intro_seen = false
	Progress.settings["reduced_motion"] = false
	main = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(4)
	var world_camera: Camera3D = main.world.camera
	var before := _snapshot()
	_check(main.modal_kind == "dialogue" and main.dialogue == main.story.intro_lines(), "arrival opens with its original lines")
	_check(is_instance_valid(main.stage_cues) and main.stage_cues.active(), "cued arrival line starts the stage")
	_check(get_viewport().get_camera_3d() == main.stage_cues.camera and not world_camera.current, "stage camera takes the view")
	await get_tree().create_timer(0.6).timeout
	_check(main.stage_cues.camera.global_basis.is_equal_approx(main.stage_cues._start.basis), "framing keeps the angle it took over")
	_check(main.stage_cues.camera.size < world_camera.size, "first line punches in on the speaker")
	main.dialogue_panel.reveal_all()
	main._next_dialogue()
	main.dialogue_panel.reveal_all()
	main._next_dialogue()
	await _frames(5)
	_check(main.dialogue_index == 2 and main.cue_hold_left > 0.0 and main.dialogue_label.visible_characters == 0, "held line keeps its text back")
	_check(main.dialogue_panel.visible and main.dialogue_panel.advance_button.is_visible_in_tree(), "a hold keeps the plaque and its advance button clickable")
	_check(main.stage_cues.emote_visible(), "emote pops over the actor")
	main.dialogue_panel.advance_button.pressed.emit()
	_check(main.dialogue_index == 2 and main.cue_hold_left == 0.0 and main.dialogue_panel.visible, "advance during a hold only ends the hold")
	main._cancel_dialogue()
	await _frames(2)
	_check(main.modal_kind == "" and main.stage_cues == null, "cancel frees the stage")
	var ticket := main.region_world().story_actor("ticket") as Sprite3D
	var ticket_material := ticket.material_override as ShaderMaterial if ticket != null else null
	_check(ticket != null and (ticket_material == null or ticket_material.get_shader_parameter("texture_albedo") != main.region_world().story_pose("ticket", "greet")), "a held greeting pose is handed back when the scene ends")
	_check(get_viewport().get_camera_3d() == world_camera, "cancel hands the view back to the world camera")
	_check(main.world.find_child("StageCueCamera", true, false) == null and main.world.find_child("StageEmote", true, false) == null, "no stage nodes remain")
	_check(before == _snapshot(), "staging awards nothing")

	# Pantomime: no subtitle, moves on by itself, and the next line shows normally.
	main._start_dialogue([
		{"speaker": "小角", "text": "", "pantomime": true, "cue": {"frame": "imp", "emote": "?", "hold": 0.3}},
		{"speaker": "小角", "text": "沒事！", "cue": {"frame": "wide"}},
	], Callable())
	_check(main.cue_pantomime and not main.dialogue_panel.visible, "pantomime beat hides the subtitle")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._unhandled_input(click)
	_check(main.dialogue_index == 1 and not main.cue_pantomime and main.dialogue_panel.visible, "a click anywhere moves a pantomime beat on")
	main._start_dialogue([
		{"speaker": "小角", "text": "", "pantomime": true, "cue": {"frame": "imp", "emote": "?", "hold": 0.3}},
		{"speaker": "小角", "text": "沒事！", "cue": {"frame": "wide"}},
	], Callable())
	await get_tree().create_timer(1.3).timeout
	_check(main.dialogue_index == 1 and main.dialogue_panel.visible and not main.cue_pantomime, "pantomime advances by itself")
	main._next_dialogue()
	main._next_dialogue()
	await _frames(2)
	_check(main.modal_kind == "" and get_viewport().get_camera_3d() == world_camera, "finishing restores the view")

	# Reduced motion: the same framing arrives at once, with no glide.
	Progress.settings["reduced_motion"] = true
	main._start_dialogue([{"speaker": "票票", "text": "好。", "cue": {"frame": "ticket", "zoom": 0.6}}], Callable())
	_check(is_equal_approx(main.stage_cues.camera.size, world_camera.size * 0.6), "reduced motion cuts straight to the framing")
	main._cancel_dialogue()
	await _frames(2)
	await _finish()

func _snapshot() -> Dictionary:
	return {"photos": Progress.photos.duplicate(true), "coins": Progress.coins, "quests": Progress.quests.duplicate(true)}

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func _finish() -> void:
	if is_instance_valid(main):
		main.audio.shutdown()
		main.queue_free()
		await _frames(3)
	for failure in failures: push_error("Stage cues: " + failure)
	if failures.is_empty(): print("PASS: dialogue staging cues frame, emote, hold, pantomime, reduced motion and restore")
	get_tree().quit(0 if failures.is_empty() else 1)
