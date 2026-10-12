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
	_expect(first.captured and first.coverage >= 0.99 and first.score >= 90, "a full, centered frame at the clear pose earns a high continuous score")
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
	var early: Dictionary = model.shutter()
	_expect(early.accepted and not early.captured and early.score == 0, "early shutter consumes one round as a visible miss")
	_expect(model.snapshot().round == before_round + 1, "an early shutter cannot be retried in the same round")
	model.reset(false, "dusk")
	var preview: Dictionary = model.snapshot()
	model.set_frame_center(Vector2(1000.0, preview.target_box.get_center().y))
	for _i in 6: model.step(0.25)
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

func _capture_at_good_composition(model, slightly_off_center: bool) -> Dictionary:
	while model.snapshot().phase == "exposure": model.step(0.25)
	var frame: Dictionary = model.snapshot()
	var best_time := float(frame.best_shutter_time)
	var end_time := best_time + 0.02
	while float(model.snapshot().round_elapsed) < end_time and not model.snapshot().finished:
		var now: Dictionary = model.snapshot()
		var offset := Vector2(18.0, 0.0) if slightly_off_center else Vector2.ZERO
		model.set_frame_center(now.target_box.get_center() + offset)
		model.step(minf(0.08, end_time - float(now.round_elapsed)))
	var final_state: Dictionary = model.snapshot()
	var offset := Vector2(18.0, 0.0) if slightly_off_center else Vector2.ZERO
	model.set_frame_center(final_state.target_box.get_center() + offset)
	var shot: Dictionary = model.shutter()
	if int(shot.get("round", -1)) == 2:
		while model.snapshot().phase == "exposure": model.step(0.25)
	return shot

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
