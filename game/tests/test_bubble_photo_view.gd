extends SceneTree

const BubblePhotoModel = preload("res://game/minigames/bubble_photo_model.gd")
const BubblePhotoView = preload("res://game/minigames/bubble_photo_view.gd")

var checks := 0
var failures: Array[String] = []
var view

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = BubblePhotoView.new()
	root.add_child(view)
	view.initialize()
	view.set_appearance({"skin":"warm", "species":"human", "hair":"windswept", "hair_color":"ink", "face":"curious"}, {"outfit":"outfit-coral", "hat":"hat-none"})
	await process_frame
	_test_camera_and_subject_bounds()
	_test_camera_layout_and_legibility()
	_test_live_feedback_and_lighting()
	_test_three_frozen_polaroids()
	_test_reduced_motion_and_model_bounds()
	_test_optical_depth_layers()
	if failures.is_empty():
		print("PASS: bubble photo view (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("Bubble photo view: " + failure)
		quit(1)

func _test_camera_and_subject_bounds() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	view.present_state(model.snapshot(), "aim", false, "noon")
	_expect(view.playfield_rect() == BubblePhotoModel.PLAY_RECT, "the camera window preserves the model's exact safe play rectangle")
	_expect(view.camera_inset_rect().encloses(BubblePhotoModel.PLAY_RECT) and view.camera_body_rect().encloses(view.camera_inset_rect()), "the carved camera body frames the exact playfield without shrinking its scored window")
	var alpha_bounds: Rect2i = view.avatar_alpha_bounds()
	_expect(alpha_bounds.size == Vector2i(206, 298), "the baseline full-body target size is measured from the cached character alpha, including hair and shoes")
	_expect(alpha_bounds.position.x > 0 and alpha_bounds.position.y > 0 and alpha_bounds.end.x < 280 and alpha_bounds.end.y < 360, "visible alpha bounds retain margins around headwear and feet in the original character canvas")
	_expect(view.cached_avatar_frame_count() >= 1 and view.subject_draw_rect() == model.snapshot().target_box, "one real avatar is drawn within the exact measured model body bounds")
	var frame: Rect2 = view.camera_frame_rect()
	_expect(BubblePhotoModel.PLAY_RECT.encloses(frame), "the complete camera frame remains inside the playfield")
	view.set_appearance({"skin":"bronze", "species":"elf", "hair":"windswept", "hair_color":"chestnut", "face":"curious"}, {"outfit":"outfit-gold", "hat":"hat-none"})
	var changed_bounds: Rect2i = view.avatar_alpha_bounds()
	var changed_subject: Rect2 = view.subject_draw_rect()
	_expect(view.cached_avatar_frame_count() >= 1 and changed_bounds.size.x > 0 and changed_bounds.size.y > 0, "wardrobe and species changes rebuild only the bounded avatar pose cache")
	_expect(model.snapshot().target_box.encloses(changed_subject), "variant headwear and species parts fit proportionally without cropping the full body")
	model.set_subject_size(view.measured_subject_size())
	view.present_state(model.snapshot(), "aim", false, "noon")
	_expect(model.snapshot().target_box.size == view.measured_subject_size() and view.subject_draw_rect() == model.snapshot().target_box, "the model's scored body bounds synchronize to the selected avatar's actual alpha union")
	for index in 3:
		var card: Rect2 = view.photo_card_rect(index)
		_expect(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(card) and card.position.y >= 635.0, "photo card %d stays in the visible lower result rail" % index)
		_expect(card.size.x >= 200.0 and card.size.y >= 70.0, "photo card %d reserves a readable full-body print slot" % index)

func _test_camera_layout_and_legibility() -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	var playfield: Rect2 = view.playfield_rect()
	var body: Rect2 = view.camera_body_rect()
	var inset: Rect2 = view.camera_inset_rect()
	var plaque: Rect2 = view.camera_plaque_rect()
	var shutter: Rect2 = view.shutter_column_rect()
	_expect(screen.encloses(body) and screen.encloses(view.photo_rail_rect()), "camera shell and print rail stay within the 1280×720 view")
	_expect(plaque.position.y >= 130.0 and plaque.end.y <= playfield.position.y and plaque.position.y > 125.0, "camera identity sits below the top HUD and above the photographed image")
	_expect(inset.encloses(playfield) and shutter.position.x >= playfield.end.x and body.encloses(shutter), "the shutter lives in its own wide side column outside the full scored image")
	_expect(not view.preview_label_rect().intersects(view.readout_badge_rect(2)) and view.preview_label_rect().end.x < shutter.position.x, "score preview clears status badges and the shutter column")
	_expect(screen.encloses(view.focus_backplate_rect()) and screen.encloses(view.preview_backplate_rect()), "both new opaque readout plates stay within the 1280×720 screen")
	_expect(not view.focus_backplate_rect().intersects(view.preview_backplate_rect()), "focus and score-preview backplates occupy separate text lanes")
	_expect(view.focus_backplate_rect().encloses(view.focus_text_rect()) and view.preview_backplate_rect().encloses(view.preview_label_rect()), "dark readout plates contain their actual focus and score labels")
	for badge_index in 3:
		var badge: Rect2 = view.readout_badge_rect(badge_index)
		_expect(not view.focus_backplate_rect().intersects(badge) and not view.preview_backplate_rect().intersects(badge), "readout plates clear status badge %d" % badge_index)
	_expect(view.control_label_width() >= 88.0 and view.plaque_title_rect().position.y >= 130.0, "camera labels reserve safe text space below the persistent HUD")
	var font: Font = ThemeDB.fallback_font
	_expect(_text_fits(font, view.plaque_title_text(), 15, view.plaque_title_rect()), "full camera plaque title fits its measured font box")
	_expect(_text_fits(font, "夜燈", 14, view.plaque_light_rect()), "night-light cue fits its plaque field")
	_expect(_text_fits(font, view.focus_label_text(), 14, view.focus_text_rect()), "longest live focus state stays inside the viewfinder")
	_expect(_text_fits(font, view.preview_label_text(), 14, view.preview_label_rect()), "three-digit estimated score fits without touching the right edge")
	for index in 3:
		var badge: Rect2 = view.readout_badge_rect(index)
		_expect(_text_fits(font, view.readout_label_text(index), 15, Rect2(badge.position + Vector2(31.0, 0.0), Vector2(badge.size.x - 36.0, badge.size.y))), "status label %d fits its badge" % index)
	for label in view.shutter_label_texts():
		var label_index: int = view.shutter_label_texts().find(label)
		var rect: Rect2 = view.shutter_primary_rect() if label_index == 0 else (view.shutter_key_rect() if label_index == 1 else view.coverage_text_rect())
		_expect(_text_fits(font, label, 13 if label_index < 2 else 12, rect), "shutter control label '%s' fits its measured side column" % label)
	for index in 3:
		var lines: Array[String] = view.photo_label_text(index)
		var text_rect: Rect2 = view.photo_text_rect(index)
		_expect(text_rect.position.y >= 635.0 and text_rect.end.x <= view.photo_card_rect(index).end.x - 6.0, "photo %d labels remain inside the lower print card" % index)
		for line_index in lines.size():
			_expect(_text_fits(font, lines[line_index], 13 if line_index < 2 else 12, text_rect), "photo %d label line %d fits its card" % [index, line_index])
	var plaque_ink := Color("#f3e1b5")
	var readout_ink := Color("#fff4dc")
	var shell := Color("#10262d")
	var readout_panel := Color("#142b31")
	_expect(_contrast_ratio(plaque_ink, shell) >= 7.0 and _contrast_ratio(readout_ink, readout_panel) >= 7.0, "plaque and night readouts retain high luminance contrast")
	_expect(_contrast_ratio(view.photo_readout_text_color(), view.photo_readout_panel_color()) >= 7.0, "the focus and score labels use the same opaque backplate and ink whose measured contrast exceeds 7:1")
	var maximum_subject := _sampled_subject_motion_bounds()
	_expect(maximum_subject.size.x >= 700.0 and maximum_subject.size.y >= 330.0, "the overlap check samples the broad three-round full-body motion envelope")
	_expect(not view.focus_backplate_rect().intersects(maximum_subject) and not view.preview_backplate_rect().intersects(maximum_subject), "both readout plates clear the sampled union of all three full-body motion paths")
	_expect(_contrast_ratio(Color("#17272b"), Color("#e9d8b2")) >= 7.0 and _contrast_ratio(Color("#263a3d"), Color("#e9d8b2")) >= 4.5, "all photo captions remain readable on warm print paper")
	_expect(screen.encloses(Rect2(view.shutter_primary_rect().position, view.shutter_primary_rect().size)) and screen.encloses(view.exposure_text_rect()), "shutter and exposure copy remain inside the viewport")
	_expect(body.position.y >= 120.0 and body.end.y < view.photo_rail_rect().position.y, "the camera shell clears both HUD and print rail")

func _text_fits(font: Font, text: String, font_size: int, rect: Rect2) -> bool:
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return not text.is_empty() and measured.x <= rect.size.x and rect.position.y >= 130.0 and rect.end.x <= 1280.0 and rect.end.y <= 720.0

func _contrast_ratio(first: Color, second: Color) -> float:
	var first_linear := first.srgb_to_linear()
	var second_linear := second.srgb_to_linear()
	var first_luminance := first_linear.r * 0.2126 + first_linear.g * 0.7152 + first_linear.b * 0.0722
	var second_luminance := second_linear.r * 0.2126 + second_linear.g * 0.7152 + second_linear.b * 0.0722
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)

func _sampled_subject_motion_bounds() -> Rect2:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	model.set_subject_size(view.measured_subject_size())
	var bounds := Rect2()
	for sample_index in 360:
		var target: Rect2 = model.snapshot().target_box
		bounds = target if sample_index == 0 else bounds.merge(target)
		model.step(0.05)
	return bounds

func _test_live_feedback_and_lighting() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	var labels: Dictionary = {}
	for light in ["dawn", "noon", "dusk", "night"]:
		view.present_state(model.snapshot(), "aim", false, light)
		var cue: String = view.light_label()
		labels[light] = cue
		_expect(not cue.is_empty(), "the %s harbor light has a readable text cue" % light)
	_expect(labels.dawn != labels.noon and labels.dusk != labels.night, "four light phases remain distinguishable without relying on hue alone")
	_expect(view.light_tint("dawn") != view.light_tint("night"), "portrait subject appearance reflects actual day/night lighting")
	var start: Dictionary = model.snapshot()
	model.set_frame_center(start.target_box.get_center() + Vector2(82.0, 0.0))
	view.present_state(model.snapshot(), "aim", false, "dusk")
	var feedback: Dictionary = view.semantic_feedback()
	_expect(feedback.coverage_text in ["完整", "入框", "裁切"] and feedback.coverage_shape in ["closed_frame", "partial_frame", "cropped_frame"] and feedback.center_text in ["置中", "偏移"] and feedback.timing_text in ["合焦", "等待姿勢"], "coverage, framing, and pose status use distinct shapes plus explicit words")
	var feedback_ref: Dictionary = feedback
	view.present_state(model.snapshot(), "aim", false, "night")
	_expect(is_same(view.semantic_feedback(), feedback_ref), "live status labels refresh in one cached dictionary")
	_expect(view.shows_reduced_motion() == false, "normal presentation retains live camera state")
	for phase_index in 4:
		var reduced := phase_index % 2 == 1
		view.present_state(model.snapshot(), "aim", reduced, ["dawn", "noon", "dusk", "night"][phase_index])
		_expect(_contrast_ratio(view.photo_readout_text_color(), view.photo_readout_panel_color()) >= 7.0 and view.photo_readout_panel_color().a == 1.0, "focus and score text keep opaque high-contrast ink in %s, reduced=%s" % [["dawn", "noon", "dusk", "night"][phase_index], reduced])
		_expect(not view.focus_backplate_rect().intersects(view.readout_badge_rect(0)) and not view.preview_backplate_rect().intersects(view.readout_badge_rect(2)), "readout-to-badge spacing remains stable in %s, reduced=%s" % [["dawn", "noon", "dusk", "night"][phase_index], reduced])

func _test_three_frozen_polaroids() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "night")
	for shot_index in 3:
		while model.snapshot().phase == "exposure": model.step(0.25)
		var desired := float(model.snapshot().best_shutter_time) + 0.02
		while float(model.snapshot().round_elapsed) < desired:
			var current: Dictionary = model.snapshot()
			model.set_frame_center(current.target_box.get_center())
			model.step(minf(0.08, desired - float(current.round_elapsed)))
		var current: Dictionary = model.snapshot()
		model.set_frame_center(current.target_box.get_center())
		var pose_before: int = view.pose_frame_for(model.snapshot())
		var photo: Dictionary = model.shutter()
		_expect(photo.captured and photo.score > 0, "shot %d records real model composition" % shot_index)
		view.present_state(model.snapshot(), "exposure", false, "night")
		_expect(view.pose_frame_for(model.snapshot()) == pose_before, "the character freezes on the exact pose used by shot %d" % shot_index)
		_expect(view.exposure_flash_enabled(), "normal exposure gives a brief camera flash cue")
		var print_rect: Rect2 = view.photo_body_rect(shot_index)
		var print_ratio: float = print_rect.size.x / print_rect.size.y
		var subject_ratio: float = view.subject_draw_rect().size.x / view.subject_draw_rect().size.y
		var card_image_rect := Rect2(view.photo_card_rect(shot_index).position + Vector2(8,7), Vector2(48,62))
		_expect(is_equal_approx(print_ratio, subject_ratio) and card_image_rect.encloses(print_rect), "shot %d print keeps full character proportions inside the photo border" % shot_index)
	for _hold in 4: model.step(0.25)
	view.present_state(model.snapshot(), "aim", true, "night")
	view.present_state(model.snapshot(), "exposure", true, "night")
	_expect(not view.exposure_flash_enabled(), "reduced motion removes the flash while keeping exposure state visible")
	view.present_state(model.snapshot(), "aim", true, "night")
	_expect(model.snapshot().photos.size() == 3 and model.snapshot().finished, "three displayed photos follow all three actual shutter events")
	_expect(view.photo_status_text(0) != "" and view.photo_status_text(1) != "" and view.photo_status_text(2) != "", "each print identifies its actual result instead of implying unearned success")
	_expect(view.photo_light_label(0) == "夜燈" and view.photo_light_label(2) == "夜燈", "each captured print retains the night-light cue from its shutter moment")

func _test_reduced_motion_and_model_bounds() -> void:
	var model = BubblePhotoModel.new()
	model.reset(true, "dawn")
	model.set_frame_center(Vector2(-10000.0, -10000.0))
	view.present_state(model.snapshot(), "aim", true, "dawn")
	_expect(view.shows_reduced_motion() and view.camera_frame_rect().position.x >= BubblePhotoModel.PLAY_RECT.position.x and view.camera_frame_rect().end.y <= BubblePhotoModel.PLAY_RECT.end.y, "reduced motion keeps static focus and frame inside all safe edges")
	var before_frame: Rect2 = view.camera_frame_rect()
	var before_subject: Rect2 = view.subject_draw_rect()
	model.set_frame_center(Vector2(10000.0, 10000.0))
	view.present_state(model.snapshot(), "aim", true, "dawn")
	_expect(view.camera_frame_rect().end.x <= BubblePhotoModel.PLAY_RECT.end.x and view.camera_frame_rect().position.y >= BubblePhotoModel.PLAY_RECT.position.y, "maximum frame movement stays inside the photographed area")
	_expect(view.camera_frame_rect() != before_frame and view.subject_draw_rect() == before_subject, "camera movement follows the input while the subject remains on its independent track")

func _test_optical_depth_layers() -> void:
	var model = BubblePhotoModel.new()
	model.reset(false, "noon")
	model.set_subject_size(view.measured_subject_size())
	for _frame in 6:
		model.step(0.25)
	view.present_state(model.snapshot(), "aim", false, "noon")
	var center_subject: Rect2 = view.subject_draw_rect()
	var center_far: Vector2 = view.harbor_layer_offset("far")
	var center_mid: Vector2 = view.harbor_layer_offset("mid")
	var center_near: Vector2 = view.harbor_layer_offset("near")
	_expect(center_far == Vector2.ZERO and center_mid == Vector2.ZERO and center_near == Vector2.ZERO, "the three optical planes rest at the model's centered camera framing")
	model.set_frame_center(Vector2(830.0, 425.0))
	view.present_state(model.snapshot(), "aim", false, "noon")
	var far_offset: Vector2 = view.harbor_layer_offset("far")
	var mid_offset: Vector2 = view.harbor_layer_offset("mid")
	var near_offset: Vector2 = view.harbor_layer_offset("near")
	_expect(far_offset.x < 0.0 and mid_offset.x < far_offset.x and near_offset.x < mid_offset.x, "camera pan produces increasing opposite parallax from far shore to near tide line")
	_expect(absf(far_offset.y) < absf(mid_offset.y) and absf(mid_offset.y) < absf(near_offset.y), "vertical framing pan preserves the same ordered depth response")
	var playfield: Rect2 = view.playfield_rect()
	var far_bounds: Rect2 = view.harbor_layer_bounds("far")
	var mid_bounds: Rect2 = view.harbor_layer_bounds("mid")
	var near_bounds: Rect2 = view.harbor_layer_bounds("near")
	_expect(playfield.encloses(far_bounds) and playfield.encloses(mid_bounds) and playfield.encloses(near_bounds), "all measured parallax silhouettes remain inside the camera negative")
	_expect(near_bounds.position.y >= model.snapshot().target_box.end.y + 6.0, "the close shoreline starts below the model's maximum full-body target box")
	_expect(view.subject_draw_rect() == center_subject and view.subject_draw_rect() == model.snapshot().target_box, "optical background pan never moves or rescales the scored full-body subject")
	var saved_far: Vector2 = far_offset
	view.present_state(model.snapshot(), "aim", false, "night")
	_expect(view.harbor_layer_offset("far") == saved_far, "time-of-day changes its palette without inventing background camera motion")
	view.present_state(model.snapshot(), "aim", true, "night")
	_expect(view.shows_reduced_motion() and view.harbor_layer_offset("far") == far_offset and view.harbor_layer_offset("near") == near_offset, "reduced motion retains the same static framing and depth cues")
	model.set_frame_center(Vector2(450.0, 355.0))
	view.present_state(model.snapshot(), "aim", true, "night")
	_expect(view.harbor_layer_offset("far").x > 0.0 and view.harbor_layer_offset("near").x > view.harbor_layer_offset("far").x, "opposite-edge camera movement reverses parallax without leaving the safe window")
	_expect(playfield.encloses(view.harbor_layer_bounds("near")), "the foreground's measured union remains inside the playfield at the opposite vertical edge")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
