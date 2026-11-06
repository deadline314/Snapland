extends Node
## ART-9 native evidence: frames the hero and each named NPC in the real Main scene while
## they idle, saves screenshots, and logs which idle frame each one shows every rendered
## frame so breathing cycles and tempo differences can be measured from the log.
## Scripted fixture camera placement; not a playtest.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const TestSaveGuard := preload("res://game/core/test_save_guard.gd")
const ReviewWallScale := preload("res://game/tests/review_wall_scale.gd")
const WATCH_FRAMES := 300  # ten seconds at the 30 FPS movie clock

var main: Node
var output_dir := ""
var samples: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_error := TestSaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges(), OS.get_user_data_dir())
	if not save_error.is_empty():
		await _fail(save_error)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--idle-review-output="):
			output_dir = argument.trim_prefix("--idle-review-output=").strip_edges()
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		await _fail("Pass --idle-review-output=<absolute directory>")
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var progress := get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for _i in 10: await get_tree().process_frame
	var activity: Node = main.world.npc_activity
	if not is_instance_valid(activity):
		await _fail("NPC activity controller is missing")
		return
	main.hud.hide()
	main.world.camera.size = 6.5  # close fixture framing; the in-game camera is wider
	var subjects := [{"role": "traveller", "node": main.world.avatar}, {"role": "traveller_vest_hat", "node": main.world.avatar, "look": {"outfit": "outfit-rainvest", "hat": "hat-sailor"}}]
	for record: Dictionary in activity._records:
		var target: Sprite3D = record.target.get_ref()
		if is_instance_valid(target):
			subjects.append({"role": str(record.role), "node": target})
	for subject: Dictionary in subjects:
		var node: Node3D = subject.node
		# Stand the hero a few steps in front of the subject so the follow camera frames it.
		if subject.has("look"):
			main.world.set_avatar_look(main.world.avatar_appearance, subject.look)
		elif not str(subject.role).begins_with("traveller"):
			# Stand beside the subject so the follow camera frames it without covering it.
			main.world.player.global_position = node.global_position + Vector3(1.9, 0.0, 0.6)
		for _i in 20: await get_tree().process_frame
		var shots := 0
		for frame in WATCH_FRAMES:
			await get_tree().process_frame
			# The hero renderer redraws one texture in place, so log its pose index instead.
			var shown := "%s/%d" % [main.world.last_avatar_action, main.world.last_avatar_frame] if str(subject.role).begins_with("traveller") else (str(node.texture.get_rid().get_id()) if node.texture != null else "")
			samples.append({"subject": subject.role, "frame": frame, "texture": shown,
				"action": _action_for(activity, node, subject.role)})
			if frame in [0, 45, 90]:
				await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				image.save_png(output_dir.path_join("idle-%s-%d.png" % [subject.role, shots]))
				shots += 1
	var file := FileAccess.open(output_dir.path_join("idle-breath-log.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps_clock": Engine.get_frames_per_second(), "watch_frames": WATCH_FRAMES,
		"breath_cycle_seconds": {"ticket": activity.breath_cycle_seconds("ticket"), "imp": activity.breath_cycle_seconds("imp"), "announcer": activity.breath_cycle_seconds("announcer")},
		"samples": samples}, "\t"))
	file.close()
	main.audio.shutdown()
	main.queue_free()
	for _i in 4: await get_tree().process_frame
	print("PASS: native idle breathing capture for %d characters" % subjects.size())
	get_tree().quit(0)

func _action_for(activity: Node, node: Node, role: String) -> String:
	if role.begins_with("traveller"):
		return str(main.world.last_avatar_action)
	for record: Dictionary in activity._records:
		if record.target.get_ref() == node:
			return str(record.action)
	return ""

func _fail(message: String) -> void:
	push_error("Native idle breath review: " + message)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1)
