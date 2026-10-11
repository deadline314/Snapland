extends SceneTree

const CrossingView = preload("res://game/minigames/crowd_crossing_view.gd")

var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = CrossingView.new()
	root.add_child(view)
	view.present(0, 0, 0, 0.0, false, "noon", false)
	_expect(view.pointerSignalAt(Vector2(520, 235)) == 0, "horizontal arrow target selects horizontal lane")
	_expect(view.pointerSignalAt(Vector2(760, 235)) == 1, "vertical arrow target selects vertical lane")
	_expect(view.pointerSignalAt(Vector2(520 + 64, 235)) == 0, "64-pixel edge remains inside horizontal target")
	_expect(view.pointerSignalAt(Vector2(520 + 64.01, 235)) == -1, "outside 64-pixel target does not select a lane")
	_expect(view.pointerSignalAt(Vector2(640, 410)) == -1, "crossing roadway is not an input hit target")
	view.present(1, 3, 1, 3.0, false, "dusk", false)
	_expect(view._crossing_lane == 1 and view._resolved_count == 3, "presentation retains the live next direction and completed count")
	_expect(view._phase_id == "dusk", "dusk phase is applied to the existing palette")
	var later_progress: float = view._crossing_progress
	view.present(1, 3, 1, 3.8, false, "dusk", false)
	_expect(view._crossing_progress > later_progress, "pedestrian stage follows the 2.2-second period")
	var moving_stage: float = view._crossing_progress
	view.present(1, 3, 1, 4.4, true, "night", false)
	_expect(view._phase_id == "night" and view._crossing_progress == moving_stage, "reduced motion holds the current pedestrian pose while time-of-day changes")
	var nodes_before := _descendants(view)
	for index in 120:
		view.present(index % 2, index % 7, index % 3, float(index) * 0.037, index % 2 == 0, ["dawn", "noon", "dusk", "night"][index % 4], index > 110)
	_expect(_descendants(view) == nodes_before, "repeated updates do not grow the view tree")
	view.present(0, 6, 2, 13.2, false, "noon", true)
	_expect(view._resolved_count == 6 and view._ended and view._crossing_progress == 0.0, "ended round clears active pedestrians and clamps count")
	_test_drawable_geometry(view)
	view.queue_free()
	await process_frame
	print("PASS: overhead crowd-crossing view (%d checks)" % checks)
	quit()

func _test_drawable_geometry(view: Control) -> void:
	_expect(view.PERSON_COLORS.size() >= 4 and view.PERSON_HATS.size() == view.PERSON_COLORS.size(), "small groups have distinct outfit and hat colors for quick identification")
	for lane in 2:
		for queue_index in 3:
			for person_index in 4:
				var waiting: Vector2 = view._queue_person_position(lane, queue_index, person_index, 4)
				_expect(view.FIELD_RECT.has_point(waiting), "queued traveler remains inside the painted quay field")
				var start: Vector2 = view._active_person_position(lane, person_index, 0.0)
				var finish: Vector2 = view._active_person_position(lane, person_index, 1.0)
				_expect(view.FIELD_RECT.has_point(start) and view.FIELD_RECT.has_point(finish), "full crossing route stays inside the roadway illustration")
	var stride_before: float = view._person_stride(2, true)
	_expect(view._person_stride(2, false) == 0.0, "red-light waiting posture has no walking stride")
	view._reduced_motion = true
	_expect(view._person_stride(2, true) == 0.0, "reduced motion removes limb bob while route position remains driven by progress")
	view._reduced_motion = false
	view._elapsed += 0.13
	var stretcher_center: Vector2 = view._stretcher_center(Vector2(500.0, 400.0), Vector2.RIGHT)
	_expect(is_equal_approx(stretcher_center.y, 387.0) and is_equal_approx(stretcher_center.x, 500.0), "rescue stretcher sits beside the medic, perpendicular to travel")
	_expect(not is_equal_approx(stride_before, view._person_stride(2, true)), "walking stride responds to time when motion is enabled")

func _descendants(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _descendants(child)
	return total

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("Crowd crossing view: " + message)
		quit(1)
