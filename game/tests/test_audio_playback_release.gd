extends SceneTree

const Release = preload("res://game/tests/audio_playback_release.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Audio playback release test requires an absolute isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	var empty: Array[WeakRef] = []
	var frame_before := Engine.get_process_frames()
	check(await Release.wait_for_release(self, empty), "empty capture releases immediately")
	check(Engine.get_process_frames() == frame_before, "empty capture does not wait for a frame")
	var owner := Node.new()
	root.add_child(owner)
	check(Release.capture(owner).is_empty(), "an owner without active players captures nothing")
	var player := _playing_player(owner)
	owner.add_child(AudioStreamPlayer.new())
	owner.add_child(Node.new())
	check(player.has_stream_playback(), "fixture owns a real active playback")
	var playbacks: Array[WeakRef] = Release.capture(owner)
	check(playbacks.size() == 1, "capture includes only the active audio player")
	player.stop()
	player.stream = null
	owner.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(owner), "owner is freed before waiting for playback release")
	check(await Release.wait_for_release(self, playbacks), "stopped playback releases after owner free")
	check(playbacks.size() == 1 and playbacks[0].get_ref() == null, "capture does not keep playback alive")
	frame_before = Engine.get_process_frames()
	check(await Release.wait_for_release(self, playbacks), "already dead playback releases immediately")
	check(Engine.get_process_frames() == frame_before, "dead playback does not wait for a frame")

	owner = Node.new()
	root.add_child(owner)
	player = _playing_player(owner)
	# This strong reference deliberately prevents release to exercise the deadline.
	var held_playback: AudioStreamPlayback = player.get_stream_playback()
	playbacks = Release.capture(owner)
	check(held_playback != null and playbacks.size() == 1, "fault fixture holds an actual captured playback")
	player.stop()
	player.stream = null
	owner.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(owner), "held playback outlives its freed owner")
	var started := Time.get_ticks_msec()
	var released: bool = await Release.wait_for_release(self, playbacks)
	var elapsed := Time.get_ticks_msec() - started
	check(not released, "a strong playback reference cannot pass the release condition")
	check(elapsed >= 2000 and elapsed < 5000, "held playback fails within the bounded deadline")
	print("Audio playback release held-reference deadline: %d ms" % elapsed)
	held_playback = null
	check(await Release.wait_for_release(self, playbacks), "release recovers after the injected reference is cleared")
	check(playbacks.size() == 1 and playbacks[0].get_ref() == null, "fault injection leaves no retained playback")
	if failures.is_empty():
		print("PASS: audio playback release weak refs, owner-free wait and bounded timeout")
	quit(0 if failures.is_empty() else 1)


func _playing_player(owner: Node) -> AudioStreamPlayer:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 2205
	var samples := PackedByteArray()
	samples.resize(4410)
	stream.data = samples
	var player := AudioStreamPlayer.new()
	owner.add_child(player)
	player.stream = stream
	player.play()
	return player


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)
