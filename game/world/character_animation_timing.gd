extends RefCounted
## Shared timing for authored clips. Callers validate before sampling and own
## playback clocks, breathing tempo, pause and transitions out of finite clips.

static func is_valid(sequence: Dictionary) -> bool:
	var frames: Variant = sequence.get("frames", [])
	var fps: Variant = sequence.get("fps", 1.0)
	if not frames is Array or frames.size() > 256:
		return false
	if not (fps is int or fps is float) or not is_finite(float(fps)) or float(fps) <= 0.0 or float(fps) > 60.0:
		return false
	if not sequence.get("loop", true) is bool:
		return false
	if sequence.has("frame_durations"):
		var holds: Variant = sequence.frame_durations
		if not holds is Array or holds.is_empty() or holds.size() != frames.size():
			return false
		for hold in holds:
			if not (hold is int or hold is float) or not is_finite(float(hold)) or float(hold) <= 0.0 or float(hold) > 30.0:
				return false
	return true


static func duration(sequence: Dictionary) -> float:
	var holds: Array = sequence.get("frame_durations", [])
	if holds.is_empty():
		return float(sequence.get("frames", []).size()) / clampf(float(sequence.get("fps", 1.0)), 0.01, 60.0)
	var total := 0.0
	for hold in holds:
		total += float(hold)
	return total


static func frame_at_time(sequence: Dictionary, elapsed: float, reduced_motion: bool = false) -> int:
	var frames: Array = sequence.get("frames", [])
	if frames.is_empty() or reduced_motion or not is_finite(elapsed):
		return 0
	var looping: bool = sequence.get("loop", true)
	var holds: Array = sequence.get("frame_durations", [])
	if not holds.is_empty():
		var total := duration(sequence)
		var remaining := fposmod(maxf(0.0, elapsed), total) if looping else minf(maxf(0.0, elapsed), total)
		for index in range(holds.size()):
			if remaining < float(holds[index]):
				return index
			remaining -= float(holds[index])
		return holds.size() - 1
	# Reduce elapsed before conversion to an integer so long-running loops do
	# not overflow a frame counter. Finite clips keep the complete final cel.
	var total := duration(sequence)
	var sampled := fposmod(maxf(0.0, elapsed), total) if looping else minf(maxf(0.0, elapsed), total)
	return mini(floori(sampled * clampf(float(sequence.get("fps", 1.0)), 0.01, 60.0)), frames.size() - 1)
