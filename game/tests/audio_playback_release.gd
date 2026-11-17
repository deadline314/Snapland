extends RefCounted


static func capture(audio: Node) -> Array[WeakRef]:
	var playbacks: Array[WeakRef] = []
	for player in audio.get_children():
		if player is AudioStreamPlayer and player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	return playbacks


static func wait_for_release(tree: SceneTree, playbacks: Array[WeakRef]) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while playbacks.any(func(playback: WeakRef): return playback.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			return false
		await tree.process_frame
	return true
