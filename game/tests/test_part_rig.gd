extends SceneTree
## Part rig (ART-65) on 倒倒: the same moment solves the same way, moves have
## many smooth in-betweens with anticipation, overshoot and late-settling parts,
## squash keeps area, fast parts smear, hits flinch and flash, the idle never
## stops, and reduced motion stills the idle, smears and shakes.

const Daodao = preload("res://game/minigames/arcade/daodao_rig.gd")
const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const FRAME := 1.0 / 60.0
## Most a part's corner may travel between two 60 fps frames, in texels.
const MAX_STEP := 16.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig: Rig = Daodao.build()
	_check(rig.parts.size() == 19 and Daodao.MOVES.all(func(move: String) -> bool: return rig.moves.has(move)), "倒倒 has nineteen parts and every move")
	_same_moment_same_pose(rig)
	_moves_are_smooth_and_varied(rig)
	_dash_winds_up_and_overshoots(rig)
	_strings_settle_late(rig)
	_squash_keeps_area(rig)
	_fast_arms_smear(rig)
	_hits_flinch_and_flash(rig)
	_idle_never_stops(rig)
	_reduced_motion_stills_the_idle(Daodao.build())
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: part rig determinism, smooth in-betweens, anticipation and overshoot, follow-through, squash area, smears, flinch, idle life, reduced motion")
	quit(0 if failures.is_empty() else 1)


func _same_moment_same_pose(rig: Rig) -> void:
	var a: Array[Dictionary] = rig.solve("dash", 0.81, 12.3, 0.2, [], Vector2(40, 0))
	var b: Array[Dictionary] = rig.solve("dash", 0.81, 12.3, 0.2, [], Vector2(40, 0))
	var same := a.size() == b.size()
	for i in mini(a.size(), b.size()):
		same = same and a[i].part == b[i].part and a[i].xform.is_equal_approx(b[i].xform) and a[i].texture == b[i].texture
	_check(same, "solving the same moment twice gives the same picture")
	_check(rig.solve("idle", 0.0, 0.0, INF, ["balloon_3"]).size() == 18, "a hidden part is left out")


func _moves_are_smooth_and_varied(rig: Rig) -> void:
	for move: String in Daodao.MOVES:
		var length: float = 2.4 if move == "idle" else rig.duration(move) + 0.2
		var previous: Dictionary = {}
		var distinct: Dictionary = {}
		var worst := 0.0
		var worst_part := ""
		var frame := 0
		while frame * FRAME <= length:
			var t := frame * FRAME
			var corners := _corners(rig.solve(move, t, 5.0 + t))
			var signature := ""
			for part: String in corners:
				signature += "%s%s" % [part, (corners[part][0] as Vector2).round()]
				if previous.has(part):
					for c in 2:
						var step: float = (corners[part][c] as Vector2).distance_to(previous[part][c])
						if step > worst:
							worst = step
							worst_part = part
			distinct[signature] = true
			previous = corners
			frame += 1
		_check(worst <= MAX_STEP, "%s moves at most %.0f texels a frame (worst %.1f, %s)" % [move, MAX_STEP, worst, worst_part])
		_check(distinct.size() >= int(length * 60.0 * 0.6), "%s draws %d distinct frames in %.1f s, not two or three diffs" % [move, distinct.size(), length])


func _dash_winds_up_and_overshoots(rig: Rig) -> void:
	var lean_back := _body_angle(rig, "dash", 0.58)
	var lunge := _body_angle(rig, "dash", 0.9)
	var swing := 999.0
	for frame in range(int(1.05 / FRAME), int(1.9 / FRAME)):
		swing = minf(swing, _body_angle(rig, "dash", frame * FRAME))
	_check(lean_back < -6.0, "the dash leans back before it goes (%.1f°)" % lean_back)
	_check(lunge > 15.0, "the dash lunges forward (%.1f°)" % lunge)
	_check(swing < -7.5, "the dash swings back past its recovery key before settling (%.1f°)" % swing)
	_check(absf(_body_angle(rig, "dash", rig.duration("dash"))) < 4.0, "the dash ends upright")
	var breathe_in := _body_scale(rig, "dash", 0.6)
	_check(breathe_in.x > breathe_in.y * 1.3, "the wind-up squashes the balloon wide")


func _strings_settle_late(rig: Rig) -> void:
	# After the dash's last key the body is home, but the tail is still swinging.
	var end: float = rig.duration("dash")
	var body_swing := absf(_body_angle(rig, "dash", end - 0.05) - _body_angle(rig, "dash", end))
	var tail_swing := absf(_angle(rig, "dash", end - 0.25, "tail_3") - _angle(rig, "idle", 0.0, "tail_3"))
	_check(tail_swing > body_swing + 2.0, "the tail trails the body (tail %.1f°, body %.1f°)" % [tail_swing, body_swing])
	var still: float = _angle(rig, "dash", 0.3, "tail_3", Vector2.ZERO)
	var carried: float = _angle(rig, "dash", 0.3, "tail_3", Vector2(120, 0))
	_check(absf(carried - still) > 5.0, "being carried sideways swings the tail back")


func _squash_keeps_area(rig: Rig) -> void:
	var worst := 0.0
	for move: String in ["dash", "pose", "confetti"]:
		var frame := 0
		while frame * FRAME <= rig.duration(move):
			var body := _part(rig.solve(move, frame * FRAME, 3.0 + frame * FRAME), "body")
			worst = maxf(worst, absf(absf(body.xform.determinant()) - 1.0))
			frame += 1
	_check(worst < 0.03, "squash and stretch keep the balloon's area (worst %.3f)" % worst)


func _fast_arms_smear(rig: Rig) -> void:
	var smeared := false
	var frame := 0
	while frame * FRAME <= rig.duration("dash"):
		smeared = smeared or _smear(rig, frame * FRAME) > 0.06
		frame += 1
	_check(smeared, "a flung arm stretches along its motion")


func _hits_flinch_and_flash(rig: Rig) -> void:
	var calm := _part(rig.solve("shy", 0.2, 4.0), "body")
	var hit := _part(rig.solve("shy", 0.2, 4.0, 0.05), "body")
	var later := _part(rig.solve("shy", 0.2, 4.0, 0.9), "body")
	_check(hit.flash > 0.4 and later.flash == 0.0, "a hit flashes briefly")
	_check(not hit.xform.is_equal_approx(calm.xform) and later.xform.is_equal_approx(calm.xform), "a hit flinches and then settles")


func _idle_never_stops(rig: Rig) -> void:
	var still_seconds := 0
	var blinked := false
	for second in 12:
		var start := _corners(rig.solve("idle", second, second))
		var moved := 0.0
		for tick in range(1, 60):
			var t := second + tick * FRAME
			var now := _corners(rig.solve("idle", t, t))
			for part: String in now:
				moved = maxf(moved, (now[part][1] as Vector2).distance_to(start[part][1]))
			var eyes := _part(rig.solve("idle", t, t), "eyes")
			blinked = blinked or eyes.xform.y.length() < 0.5
		if moved < 0.75:
			still_seconds += 1
	_check(still_seconds == 0, "every second of idle has visible motion (%d still)" % still_seconds)
	_check(blinked, "倒倒 blinks during idle")


func _reduced_motion_stills_the_idle(rig: Rig) -> void:
	rig.reduced_motion = true
	var first := _corners(rig.solve("idle", 0.0, 0.0))
	var drift := 0.0
	for tick in 600:
		var now := _corners(rig.solve("idle", tick * FRAME, tick * FRAME))
		for part: String in now:
			drift = maxf(drift, (now[part][1] as Vector2).distance_to(first[part][1]))
	_check(drift < 0.001, "reduced motion keeps the idle still (%.3f)" % drift)
	var calm := _part(rig.solve("shy", 0.2, 4.0), "body")
	var hit := _part(rig.solve("shy", 0.2, 4.0, 0.05), "body")
	_check(hit.flash > 0.4 and hit.xform.is_equal_approx(calm.xform), "reduced motion keeps the hit flash but not the shake")
	var smeared := false
	var frame := 0
	while frame * FRAME <= rig.duration("dash"):
		smeared = smeared or _smear(rig, frame * FRAME) > 0.06
		frame += 1
	_check(not smeared, "reduced motion draws no smears")
	_check(_body_angle(rig, "dash", 0.58) < -6.0, "reduced motion still shows the wind-up")


# --- Helpers ----------------------------------------------------------------

## Per part: the pivot and the texture's far corner in rig space.
func _corners(solved: Array[Dictionary]) -> Dictionary:
	var out := {}
	for item in solved:
		var size: Vector2 = item.texture.get_size()
		out[item.part] = [item.xform * Vector2.ZERO, item.xform * (size - item.pivot)]
	return out


## How far the drawn arm differs from its unstretched pose (0 = no smear).
func _smear(rig: Rig, t: float) -> float:
	var drawn: Transform2D = _part(rig.solve("dash", t, 2.0), "arm_r").xform
	var plain: Transform2D = rig._world("dash", t, 2.0, INF)[rig.parts.find_custom(func(p: Dictionary) -> bool: return p.name == "arm_r")]
	return (drawn.x - plain.x).length() + (drawn.y - plain.y).length()


func _part(solved: Array[Dictionary], name: String) -> Dictionary:
	for item in solved:
		if item.part == name:
			return item
	return {}


func _angle(rig: Rig, move: String, t: float, name: String, drift := Vector2.ZERO) -> float:
	return rad_to_deg(_part(rig.solve(move, t, 1.0, INF, [], drift), name).xform.get_rotation())


func _body_angle(rig: Rig, move: String, t: float) -> float:
	# Clock 0 puts the idle sway at its zero crossing.
	var body := _part(rig.solve(move, t, 0.0), "body")
	return rad_to_deg(body.xform.get_rotation())


func _body_scale(rig: Rig, move: String, t: float) -> Vector2:
	return _part(rig.solve(move, t, 0.0), "body").xform.get_scale()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
