extends SceneTree

const SCRIPT_PATH := "res://game/world/hero_2d_pose.gd"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script := load(SCRIPT_PATH)
	assert(script != null, "hero_2d_pose.gd must load as a standalone pose state player")
	var pose = script.new()
	var state: Dictionary

	# A blocked intent is not movement and must not start or advance gait.
	state = pose.advance(0.2, Vector2.ZERO, Vector2.RIGHT)
	assert(state.action == "idle" and state.direction == "front", "zero resolved displacement must remain idle and retain facing")
	assert(state.gait_phase == 0.0 and state.frame == 0, "blocked input must not advance the walk cycle")

	# Actual distance starts movement and partitions equally regardless of tick size.
	state = pose.advance(0.1, Vector2(0.12, 0.0), Vector2.RIGHT)
	assert(state.action == "start" and state.direction == "right", "actual movement should start in its resolved direction")
	assert(state.gait_phase > 0.0, "start pose should retain the distance-driven gait phase")
	var phase_after_step: float = state.gait_phase
	state = pose.advance(0.1, Vector2(0.12, 0.0), Vector2.RIGHT)
	assert(state.action == "walk" and state.gait_phase > phase_after_step, "start should resolve into distance-driven walk")
	var original_phase: float = state.gait_phase
	var partitioned = script.new()
	partitioned.advance(0.1, Vector2(0.12, 0.0), Vector2.RIGHT)
	state = partitioned.advance(0.1, Vector2(0.12, 0.0), Vector2.RIGHT)
	var expected_partitioned_phase := fposmod(0.24 / pose.stride_distance("right"), 1.0)
	assert(is_equal_approx(state.gait_phase, expected_partitioned_phase) and is_equal_approx(original_phase, expected_partitioned_phase), "equal distance must keep equal gait phase")
	var phase_to_continue: float = state.gait_phase

	var jitter = script.new()
	var near_boundary := Vector2(sin(deg_to_rad(23.0)), cos(deg_to_rad(23.0)))
	state = jitter.advance(0.1, near_boundary * 0.1, near_boundary)
	assert(state.direction == "front", "heading should hold inside the five-degree hysteresis band")
	var across_boundary := Vector2(sin(deg_to_rad(28.0)), cos(deg_to_rad(28.0)))
	state = jitter.advance(0.1, across_boundary * 0.1, across_boundary)
	assert(state.direction == "front_right", "heading should change after crossing the hysteresis band")

	# Direction changes retain phase and hold octants inside the hysteresis band.
	var held_phase: float = phase_to_continue
	state = pose.advance(0.1, Vector2(0.12, 0.12), Vector2(1.0, 1.0))
	var changed_expected := fposmod(held_phase + Vector2(0.12, 0.12).length() / pose.stride_distance("front_right"), 1.0)
	assert(state.direction == "front_right" and is_equal_approx(state.gait_phase, changed_expected), "direction changes must preserve distance continuity; got %s phase %s expected %s" % [state.direction, str(state.gait_phase), str(changed_expected)])

	# A reverse request brakes in the old direction, holds root through pivot, then restarts.
	var reversal = script.new()
	reversal.advance(0.2, Vector2(0.2, 0.0), Vector2.RIGHT)
	state = reversal.advance(0.01, Vector2(0.01, 0.0), Vector2.LEFT)
	assert(state.action == "stop" and state.direction == "right" and state.root_locked, "reversal should settle in a root-locked old-facing stop")
	state = reversal.advance(0.2, Vector2.ZERO, Vector2(-1.0, -1.0))
	assert(state.action == "turn" and state.direction == "back_left" and state.root_locked, "stop should pivot toward the current reverse intent")
	assert(state.turn_from == "right" and state.visual_direction == "right", "turn should expose its source pose before changing the authored octant")
	state = reversal.advance(0.08, Vector2.ZERO, Vector2(-1.0, -1.0))
	assert(state.turn_from == "right" and state.visual_direction == "back_right", "turn should select an intermediate authored octant as it pivots")
	state = reversal.advance(0.25, Vector2.ZERO, Vector2(-1.0, -1.0))
	assert(state.action == "start" and state.direction == "back_left", "completed pivot should restart toward intent")

	# Large physics deltas carry across stop, turn, and start boundaries instead of dropping elapsed time.
	var catchup = script.new()
	catchup.advance(0.2, Vector2(0.2, 0.0), Vector2.RIGHT)
	catchup.advance(0.01, Vector2(0.01, 0.0), Vector2.LEFT)
	state = catchup.advance(0.5, Vector2.ZERO, Vector2.LEFT)
	assert(state.action == "start" and is_equal_approx(state.phase, 0.35), "overshoot should carry through stop and turn into the start phase")
	var partitioned_turn = script.new()
	partitioned_turn.advance(0.2, Vector2(0.2, 0.0), Vector2.RIGHT)
	partitioned_turn.advance(0.01, Vector2(0.01, 0.0), Vector2.LEFT)
	partitioned_turn.advance(0.19, Vector2.ZERO, Vector2.LEFT)
	partitioned_turn.advance(0.24, Vector2.ZERO, Vector2.LEFT)
	state = partitioned_turn.advance(0.07, Vector2.ZERO, Vector2.LEFT)
	assert(state.action == "start" and is_equal_approx(state.phase, 0.35), "partitioned stop and turn time should match a single overshooting delta; got %s phase %s" % [state.action, str(state.phase)])

	# Releasing reversal or photographing during the pending stop cancels queued pivot.
	var cancel = script.new()
	cancel.advance(0.2, Vector2(0.2, 0.0), Vector2.RIGHT)
	cancel.advance(0.01, Vector2(0.01, 0.0), Vector2.LEFT)
	state = cancel.advance(0.2, Vector2.ZERO, Vector2.ZERO)
	assert(state.action == "idle" and not state.root_locked, "released reverse intent must not trigger a surprise pivot")
	var photo_cancel = script.new()
	photo_cancel.advance(0.2, Vector2(0.2, 0.0), Vector2.RIGHT)
	photo_cancel.advance(0.01, Vector2(0.01, 0.0), Vector2.LEFT)
	state = photo_cancel.advance(0.01, Vector2.ZERO, Vector2.LEFT, true)
	assert(state.action == "photo" and not state.root_locked, "photo request should cancel pending pivot")
	state = photo_cancel.advance(1.21, Vector2.ZERO, Vector2.LEFT)
	assert(state.action == "idle", "completed photo must not resume the canceled pivot")

	# One shutter crossing, motion cancels a photo, and pause freezes state and events.
	var camera = script.new()
	state = camera.advance(0.1, Vector2.ZERO, Vector2.ZERO, true)
	assert(state.action == "photo", "photo flag should enter photo action")
	state = camera.advance(0.5, Vector2.ZERO, Vector2.ZERO)
	assert(state.events.count("shutter") == 1, "shutter should fire once at its crossing")
	camera.set_paused(true)
	var frozen: Dictionary = camera.advance(1.0, Vector2.RIGHT, Vector2.RIGHT, true)
	assert(frozen.action == state.action and frozen.direction == state.direction and frozen.frame == state.frame and is_equal_approx(frozen.phase, state.phase), "paused advance must preserve complete pose state")
	assert(frozen.events.is_empty(), "paused advance must not emit photo or movement events")
	camera.set_paused(false)
	state = camera.advance(0.1, Vector2.ZERO, Vector2.ZERO)
	assert(state.events.count("shutter") == 0, "pause and resume must not repeat the shutter")
	state = camera.advance(0.1, Vector2.RIGHT * 0.1, Vector2.RIGHT)
	assert(state.action == "start" and state.events.has("photo_cancelled"), "movement should cancel photo and emit one cancellation")

	# Direction-specific stride and frame counts are configuration, not authored-image assumptions.
	var configured = script.new()
	assert(configured.set_stride_distance("front", 2.0), "valid stride configuration should be accepted")
	assert(configured.set_frame_count("walk", "front", 6), "valid direction/action frame count should be accepted")
	assert(not configured.set_stride_distance("front", 1e-30), "unsafe near-zero stride should be rejected")
	assert(not configured.set_frame_count("walk", "front", 1000000), "unbounded frame count should be rejected")
	state = configured.advance(0.1, Vector2(0.5, 0.0), Vector2.RIGHT)
	assert(is_equal_approx(state.gait_phase, 0.5 / configured.stride_distance("right")), "front stride configuration must not leak into right direction")
	assert(configured.frame_count("walk", "front") == 6, "per-direction frame-count configuration must be observable")
	configured.set_paused(true)
	assert(not configured.set_stride_distance("right", 3.0), "pause must guard configuration mutators")
	assert(not configured.set_direction("left"), "pause must guard direction mutators")

	# Non-finite time and vectors cannot poison phase, direction, or action state.
	var safe = script.new()
	state = safe.advance(NAN, Vector2.ZERO, Vector2.ZERO)
	assert(state.action == "idle" and is_finite(state.phase), "NaN delta must be ignored safely")
	state = safe.advance(INF, Vector2.ZERO, Vector2.ZERO)
	assert(state.action == "idle" and is_finite(state.phase), "infinite delta must be bounded safely")
	state = safe.advance(0.1, Vector2(INF, 0.0), Vector2.RIGHT)
	assert(state.action == "idle" and state.gait_phase == 0.0 and state.direction == "front", "infinite displacement must not corrupt movement state")
	state = safe.advance(0.1, Vector2.ZERO, Vector2(NAN, 0.0))
	assert(state.action == "idle" and state.direction == "front", "NaN intent must not rotate or start the pose")
	print("PASS hero 2D pose: resolved travel, octants, reversal, pause, photo, and configuration")
	quit()
