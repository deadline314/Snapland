extends SceneTree

const BubblePhotoModel = preload("res://game/minigames/bubble_photo_model.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_progressive_full_frame_scoring()
	_test_cut_off_and_early_shutter()
	_test_assist_and_day_night_cues()
	_test_timeouts_and_readonly_reuse()
	_test_composition_cache_reuse()
	_test_appearance_bound_synchronization()
	_test_bubble_is_a_real_qualification_gate()
	_test_large_body_keyboard_fit_window()
	_test_bubble_charge_motion_cache_and_reset()
	if failures.is_empty():
		print("PASS: bubble photo model (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("Bubble photo model: " + failure)
		quit(1)

func _test_progressive_full_frame_scoring() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	var first: Dictionary = _capture_at_good_composition(model, false)
	_expect(first.captured and first.coverage >= 0.99 and first.score >= 90 and first.bubble_enveloped, "a full, centered bubble-enveloped frame at the clear pose earns a high continuous score")
	_expect(first.round == 0 and first.time_of_day == "noon", "the photo records its round and lighting context")
	var second: Dictionary = _capture_at_good_composition(model, false)
	_expect(second.captured and second.score >= 90, "the second complete centered photo earns a high continuous score")
	var third: Dictionary = _capture_at_good_composition(model, true)
	var result: Dictionary = model.snapshot()
	_expect(third.captured and result.finished and result.success and not result.devil, "a slightly off-center third photo still qualifies ordinarily but misses the perfect-set bonus")
	_expect(result.score == first.score + second.score + third.score and result.photos.size() == 3, "the total equals the three recorded photo scores")
	_expect(not model.shutter().accepted, "a finished three-photo run cannot award an extra shutter result")
	var perfect_run = BubblePhotoModel.new()
	perfect_run.reset(false, "noon")
	for _shot in 3:
		_capture_at_good_composition(perfect_run, false)
		while perfect_run.snapshot().phase == "exposure": perfect_run.step(0.25)
	_expect(perfect_run.snapshot().success and perfect_run.snapshot().devil, "three genuinely full, centered clear-pose photos reach the devil threshold")
	var lower = BubblePhotoModel.new()
	lower.reset(false, "noon")
	var offset_shot: Dictionary = _capture_at_good_composition(lower, true)
	_expect(offset_shot.score < first.score and offset_shot.qualified, "an off-center but complete portrait qualifies for less continuous score")

func _test_cut_off_and_early_shutter() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "dusk")
	model.step(0.2)
	var before_round := int(model.snapshot().round)
	var before_misses := int(model.snapshot().misses)
	var early: Dictionary = model.shutter()
	_expect(not early.accepted and str(early.reason) == "not_ready" and not early.captured, "a shutter before the ready cue is ignored with an explicit reason")
	_expect(model.snapshot().round == before_round and model.snapshot().misses == before_misses and model.snapshot().photos.is_empty(), "an early shutter does not consume a photo, miss, or round")
	model.reset(false, "dusk")
	var preview: Dictionary = model.snapshot()
	_advance_to_best_pose(model)
	preview = model.snapshot()
	model.set_frame_center(Vector2(1000.0, preview.target_box.get_center().y))
	var cutoff: Dictionary = model.snapshot()
	_expect(cutoff.coverage < 1.0 and cutoff.target_box.position.x < cutoff.frame_rect.position.x, "preview coverage detects actual full-body clipping at the frame edge")
	var shot: Dictionary = model.shutter()
	_expect(shot.accepted and shot.coverage < 1.0 and not shot.perfect, "a cropped full-body frame is not mistaken for a perfect photo")
	_expect(not model.shutter().accepted, "two shutter presses cannot produce two exposures in one round")
	var exposed_state: Dictionary = model.snapshot()
	model.set_frame_center(Vector2(INF, 0.0))
	_expect(model.snapshot().frame_center == exposed_state.frame_center, "non-finite frame input is ignored safely during exposure")

func _test_assist_and_day_night_cues() -> void:
	var normal = BubblePhotoModel.new()
	var assist = BubblePhotoModel.new()
	normal.reset(false, "noon")
	assist.reset(true, "night")
	var normal_state: Dictionary = normal.snapshot()
	var assist_state: Dictionary = assist.snapshot()
	_expect(normal_state.target_box.size == assist_state.target_box.size, "assist does not resize or replace the real subject")
	_expect(normal_state.light_cue != assist_state.light_cue and assist_state.time_of_day == "night", "time of day changes a visible lighting cue without changing target bounds")
	_expect(assist_state.assisted and assist_state.frame_rect.size == normal_state.frame_rect.size, "assist preserves the camera frame and only increases composition tolerance")
	var assisted_shot: Dictionary = _capture_at_good_composition(assist, true)
	_expect(assisted_shot.accepted and assisted_shot.score > 0, "assistance widens the qualifying framing margin without auto-shooting")
	_expect(assist.snapshot().round == 0 and assist.snapshot().phase == "exposure", "assistance still requires player input and preserves the one-second photo hold")
	assist.step(0.99)
	assist.step(0.25)
	assist.step(0.25)
	assist.step(0.24)
	_expect(assist.snapshot().round == 0, "the next portrait cannot appear before the complete shutter hold")
	assist.step(0.01)
	_expect(assist.snapshot().round == 1, "the next portrait appears after the completed shutter hold")

func _test_timeouts_and_readonly_reuse() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "sunset")
	var first_view: Dictionary = model.snapshot()
	var photos_ref: Array = first_view.photos
	var round_one := int(first_view.round)
	var revision_before_read := int(first_view.revision)
	_expect(model.snapshot() == first_view and int(model.snapshot().revision) == revision_before_read, "reading a cached snapshot does not mutate its revision")
	model.step(100.0)
	_expect(float(model.snapshot().round_elapsed) <= 0.25, "an oversized delta cannot skip a shutter window in one update")
	_expect(int(model.snapshot().revision) > revision_before_read, "simulation changes advance the cached snapshot revision")
	while not model.snapshot().finished:
		model.step(0.25)
	var after: Dictionary = model.snapshot()
	_expect(after.photos == photos_ref and after.round > round_one, "snapshot and photo ledger storage are reused across simulation updates")
	_expect(after.score == 0 and after.misses > 0, "timeouts are recorded as misses rather than fabricated points")
	_expect(after.finished and after.photos.size() == 3 and after.misses == 3, "three unanswered rounds terminate with an explicit result")
	_expect(model.snapshot() == after, "repeated reads keep the same cached state values")
	model.reset(false, "night")
	_expect(model.snapshot().round == 0 and model.snapshot().photos.is_empty() and not model.snapshot().finished, "reset clears timeout results and starts a fresh round")

func _test_composition_cache_reuse() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	var composition: Dictionary = model._compose_current()
	var measured_size: Vector2 = composition.target_box.size
	model.step(0.25)
	var updated: Dictionary = model._compose_current()
	_expect(is_same(updated, composition), "composition and snapshot updates reuse the same dictionary")
	_expect(updated.target_box.size == measured_size and measured_size == Vector2(206.0, 298.0), "the measured full-body target bounds match the union alpha size used by the view")
	_expect(updated.target_box.position != Vector2.ZERO, "the reused composition is refreshed in place after simulation advances")

func _test_appearance_bound_synchronization() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	model.set_subject_size(Vector2(218.0, 314.0))
	_expect(model.snapshot().target_box.size == Vector2(218.0, 314.0), "the view can set the judged silhouette to its measured wardrobe alpha union")
	model.set_subject_size(Vector2(INF, 0.0))
	_expect(model.snapshot().target_box.size == Vector2(218.0, 314.0), "invalid measured silhouette dimensions are ignored")

func _test_bubble_is_a_real_qualification_gate() -> void:
	var no_bubble := BubblePhotoModel.new()
	no_bubble.reset(false, "noon")
	var no_bubble_shot := _capture_without_bubble(no_bubble)
	_expect(no_bubble_shot.captured and no_bubble_shot.score >= 90, "a well-composed photo still records its original composition score without bubble points")
	_expect(not no_bubble_shot.qualified and not no_bubble_shot.perfect and not no_bubble_shot.bubble_enveloped, "a missing bubble prevents ordinary and perfect qualification")

	var small_bubble := BubblePhotoModel.new()
	small_bubble.reset(false, "noon")
	small_bubble.set_subject_size(Vector2(280.0, 360.0))
	var small_state: Dictionary = small_bubble.snapshot()
	var target_center: Vector2 = small_state.target_box.get_center()
	small_bubble.set_frame_center(target_center)
	_advance_to_best_pose(small_bubble)
	small_state = small_bubble.snapshot()
	small_bubble.set_frame_center(small_state.target_box.get_center())
	_expect(small_bubble.start_bubble_charge(), "a real one-shot bubble charge starts at the framed position")
	_expect(small_bubble.release_bubble_charge(), "a short release launches a visible minimum-size bubble")
	var underfit: Dictionary = small_bubble.shutter()
	_expect(underfit.captured and underfit.score > 0 and not underfit.bubble_enveloped and not underfit.qualified, "an undersized bubble fails the full-body corner test without removing composition score")

	var large_silhouette := BubblePhotoModel.new()
	large_silhouette.reset(false, "noon")
	large_silhouette.set_subject_size(Vector2(300.0, 400.0))
	_advance_to_charge_start(large_silhouette)
	var large_state: Dictionary = large_silhouette.snapshot()
	large_silhouette.set_frame_center(large_state.target_box.get_center())
	large_silhouette.start_bubble_charge()
	for _charge_step in 4: large_silhouette.step(0.18)
	_expect(large_silhouette.snapshot().bubble.radius >= large_silhouette.subject_size.length() * 0.5 + 14.0, "full charge adapts to larger measured avatar silhouettes rather than making wardrobe size impossible")
	large_state = large_silhouette.snapshot()
	large_silhouette.set_frame_center(large_state.target_box.get_center())
	large_silhouette.release_bubble_charge()
	var large_photo: Dictionary = large_silhouette.shutter()
	_expect(large_photo.bubble_enveloped and large_photo.qualified, "the model can honestly qualify the largest tested centered full-body silhouette")

	var off_bubble := BubblePhotoModel.new()
	off_bubble.reset(false, "noon")
	_advance_to_best_pose(off_bubble)
	var off_state: Dictionary = off_bubble.snapshot()
	var subject_center: Vector2 = off_state.target_box.get_center()
	var launch_far := subject_center + Vector2(240.0, 0.0)
	off_bubble.set_frame_center(launch_far)
	_expect(off_bubble.start_bubble_charge() and off_bubble.release_bubble_charge(), "the player can launch from an intentionally offset viewfinder point")
	off_bubble.set_frame_center(subject_center)
	var off_shot: Dictionary = off_bubble.shutter()
	_expect(off_shot.captured and not off_shot.bubble_enveloped and not off_shot.qualified, "camera framing cannot conceal that the live bubble missed the subject")

	var camera_cropped := BubblePhotoModel.new()
	camera_cropped.reset(false, "noon")
	_advance_to_best_pose(camera_cropped)
	var cropped_state: Dictionary = camera_cropped.snapshot()
	camera_cropped.set_frame_center(cropped_state.target_box.get_center())
	camera_cropped.start_bubble_charge()
	camera_cropped.step(0.20)
	camera_cropped.release_bubble_charge()
	camera_cropped.set_frame_center(cropped_state.target_box.get_center() + Vector2(280.0, 0.0))
	var cropped_shot: Dictionary = camera_cropped.shutter()
	_expect(cropped_shot.bubble_enveloped and not cropped_shot.qualified, "a bubble-wrapped body still cannot qualify when the camera frame crops it")
	_expect(not cropped_shot.frame_enclosed, "the recorded qualification explains that the whole subject missed the frame")

	for crop_case in [{"offset": -1.0, "label": "feet"}, {"offset": 1.0, "label": "head"}]:
		var crop_direction: float = float(crop_case.offset)
		var crop_label: String = str(crop_case.label)
		var edge_crop := BubblePhotoModel.new()
		edge_crop.reset(false, "noon")
		edge_crop.set_subject_size(Vector2(220.0, 440.0))
		_advance_to_charge_start(edge_crop)
		var edge_state: Dictionary = edge_crop.snapshot()
		var edge_center: Vector2 = edge_state.target_box.get_center()
		edge_crop.set_frame_center(edge_center)
		edge_crop.start_bubble_charge()
		for _charge in 4:
			edge_crop.step(0.18)
			edge_crop.set_frame_center(edge_crop.snapshot().target_box.get_center())
		edge_crop.release_bubble_charge()
		edge_crop.set_frame_center(edge_center + Vector2(0.0, crop_direction * 4.0))
		var edge_photo: Dictionary = edge_crop.shutter()
		_expect(edge_photo.bubble_enveloped and edge_photo.coverage > 0.98, "%s crop keeps the bubble and most frame coverage" % crop_label)
		_expect(not edge_photo.frame_enclosed and not edge_photo.qualified and not edge_photo.perfect, "%s crop cannot qualify by clipping the full-body bounds" % crop_label)
		_expect(edge_photo.coverage > 0.98 and edge_photo.score >= 90, "%s crop keeps its honest continuous composition score" % crop_label)

	var assisted_crop := BubblePhotoModel.new()
	assisted_crop.reset(true, "noon")
	assisted_crop.set_subject_size(Vector2(220.0, 440.0))
	_advance_to_charge_start(assisted_crop)
	var assisted_state: Dictionary = assisted_crop.snapshot()
	assisted_crop.set_frame_center(assisted_state.target_box.get_center())
	assisted_crop.start_bubble_charge()
	for _charge in 4:
		assisted_crop.step(0.18)
		assisted_crop.set_frame_center(assisted_crop.snapshot().target_box.get_center())
	assisted_crop.release_bubble_charge()
	assisted_state = assisted_crop.snapshot()
	assisted_crop.set_frame_center(assisted_state.target_box.get_center() + Vector2(0.0, 4.0))
	var assisted_crop_photo: Dictionary = assisted_crop.shutter()
	_expect(assisted_crop_photo.bubble_enveloped and not assisted_crop_photo.frame_enclosed and not assisted_crop_photo.qualified, "assist keeps its wider bubble/time margins but never qualifies a cropped full body")

func _test_bubble_charge_motion_cache_and_reset() -> void:
	var model := BubblePhotoModel.new()
	model.reset(false, "noon")
	var stable_state: Dictionary = model.snapshot()
	var bubble_cache: Dictionary = stable_state.bubble
	_expect(model.snapshot().bubble == bubble_cache, "bubble state uses one cached dictionary across reads")
	model.set_frame_center(Vector2(520.0, 380.0))
	var origin: Vector2 = model.snapshot().frame_center
	_expect(model.start_bubble_charge(), "bubble charging requires an explicit player action")
	model.step(0.25)
	_expect(model.snapshot().bubble.center == origin and model.snapshot().bubble.charge > 0.0, "charging changes size state without moving the bubble launch point")
	model.set_frame_center(origin + Vector2(20.0, 0.0))
	_expect(model.snapshot().bubble.center == origin + Vector2(20.0, 0.0), "the live bubble stays attached to the reticle while the player aims during charge")
	_expect(model.release_bubble_charge(), "release is the explicit launch action")
	var initial_center: Vector2 = model.snapshot().bubble.center
	var first_radius: float = model.snapshot().bubble.radius
	_expect(first_radius > BubblePhotoModel.BUBBLE_RADIUS_MIN, "a held charge visibly grows the real bubble from its tap size")
	model.step(0.25)
	_expect(model.snapshot().bubble.center != initial_center and model.snapshot().bubble.radius == first_radius, "the bubble follows model drift while retaining its charged radius")
	_expect(stable_state.bubble == bubble_cache, "previous snapshots retain the same read-only bubble-state view")
	var next_model := BubblePhotoModel.new()
	next_model.reset(false, "noon")
	_expect(next_model.start_bubble_charge(), "retry scenario starts a real charge")
	next_model.step(0.20)
	_expect(next_model.snapshot().bubble.charging, "the charge is visible before release")
	next_model.reset(true, "night")
	_expect(next_model.snapshot().bubble.phase == "idle" and next_model.snapshot().bubble.radius == 0.0 and next_model.snapshot().assisted and next_model.snapshot().time_of_day == "night", "reset clears bubble state while retaining the explicitly requested assist and lighting options")

func _test_large_body_keyboard_fit_window() -> void:
	var model := BubblePhotoModel.new()
	model.reset(false, "noon")
	model.set_subject_size(Vector2(300.0, 400.0))
	_expect(model.snapshot().frame_rect.size.x - model.subject_size.x == 60.0, "the viewfinder gives a 300px avatar 30px of horizontal room on each side")
	for round_index in 3:
		var target_time: float = float(model.snapshot().best_shutter_time)
		var charge_start := target_time - BubblePhotoModel.BUBBLE_CHARGE_MAX
		var guard := 0
		while float(model.snapshot().round_elapsed) < charge_start and guard < 240:
			model.step(1.0 / 60.0)
			_keyboard_track_frame(model)
			guard += 1
		_expect(guard < 240 and model.start_bubble_charge(), "large-avatar order %d reaches a real timed keyboard bubble charge" % (round_index + 1))
		var fitting_window := 0
		var released := false
		var shot: Dictionary = {}
		guard = 0
		while str(model.snapshot().phase) == "aim" and float(model.snapshot().round_elapsed) <= target_time + 0.55 and guard < 180:
			model.step(1.0 / 60.0)
			_keyboard_track_frame(model)
			var live: Dictionary = model.snapshot()
			if not released and float(live.bubble.charge) >= 0.99:
				released = model.release_bubble_charge()
				live = model.snapshot()
			if released and bool(live.focus_available) and bool(live.frame_enclosed) and bool(live.bubble.enveloped) and int(live.score_preview) >= BubblePhotoModel.MIN_QUALIFYING_SCORE:
				fitting_window += 1
			else:
				fitting_window = 0
			if fitting_window >= 6:
				shot = model.shutter()
				break
			guard += 1
		var final_state: Dictionary = model.snapshot()
		_expect(released and fitting_window >= 6 and bool(shot.get("captured", false)) and bool(shot.get("qualified", false)), "large-avatar order %d exposes a visible >=0.1s full-fit keyboard qualification window (t=%.3f frame=%s body=%s enclosed=%s bubble=%s score=%d window=%d)" % [round_index + 1, float(final_state.round_elapsed), str(final_state.frame_center), str(final_state.target_center), str(final_state.frame_enclosed), str(final_state.bubble.enveloped), int(final_state.score_preview), fitting_window])
		while str(model.snapshot().phase) == "exposure": model.step(0.25)
	_expect(model.snapshot().finished and model.snapshot().success, "real 14px discrete keyboard tracking can qualify all three 300×400 full-body orders")

func _keyboard_track_frame(model) -> void:
	var state: Dictionary = model.snapshot()
	var delta: Vector2 = Vector2(state.target_center) - Vector2(state.frame_center)
	var shift := Vector2.ZERO
	if absf(delta.x) > 7.0:
		shift.x = signf(delta.x) * 14.0
	elif absf(delta.y) > 7.0:
		shift.y = signf(delta.y) * 14.0
	model.set_frame_center(Vector2(state.frame_center) + shift)

func _capture_at_good_composition(model, slightly_off_center: bool) -> Dictionary:
	while model.snapshot().phase == "exposure": model.step(0.25)
	var best_time := float(model.snapshot().best_shutter_time)
	var offset := Vector2(18.0, 0.0) if slightly_off_center else Vector2.ZERO
	while float(model.snapshot().round_elapsed) < best_time - 0.28 and not model.snapshot().finished:
		var before_charge: Dictionary = model.snapshot()
		model.set_frame_center(before_charge.target_box.get_center() + offset)
		model.step(minf(0.08, best_time - 0.28 - float(before_charge.round_elapsed)))
	var charge_state: Dictionary = model.snapshot()
	model.set_frame_center(charge_state.target_box.get_center() + offset)
	model.start_bubble_charge()
	model.step(0.18)
	model.set_frame_center(model.snapshot().target_box.get_center() + offset)
	model.step(0.08)
	model.release_bubble_charge()
	var end_time := best_time + 0.02
	while float(model.snapshot().round_elapsed) < end_time and not model.snapshot().finished:
		var now: Dictionary = model.snapshot()
		model.set_frame_center(now.target_box.get_center() + offset)
		model.step(minf(0.08, end_time - float(now.round_elapsed)))
	var final_state: Dictionary = model.snapshot()
	model.set_frame_center(final_state.target_box.get_center() + offset)
	var shot: Dictionary = model.shutter()
	if int(shot.get("round", -1)) == 2:
		while model.snapshot().phase == "exposure": model.step(0.25)
	return shot

func _capture_without_bubble(model) -> Dictionary:
	_advance_to_best_pose(model)
	var state: Dictionary = model.snapshot()
	model.set_frame_center(state.target_box.get_center())
	return model.shutter()

func _advance_to_best_pose(model) -> void:
	var target_time := float(model.snapshot().best_shutter_time)
	while float(model.snapshot().round_elapsed) < target_time and not model.snapshot().finished:
		var state: Dictionary = model.snapshot()
		model.set_frame_center(state.target_box.get_center())
		model.step(minf(0.08, target_time - float(state.round_elapsed)))
	var final_state: Dictionary = model.snapshot()
	model.set_frame_center(final_state.target_box.get_center())

func _advance_to_charge_start(model) -> void:
	var target_time := float(model.snapshot().best_shutter_time) - BubblePhotoModel.BUBBLE_CHARGE_MAX
	while float(model.snapshot().round_elapsed) < target_time and not model.snapshot().finished:
		model.step(minf(0.08, target_time - float(model.snapshot().round_elapsed)))
	var state: Dictionary = model.snapshot()
	model.set_frame_center(state.target_box.get_center())

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
