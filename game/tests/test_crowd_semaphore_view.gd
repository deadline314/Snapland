extends SceneTree

const TrafficModel = preload("res://game/minigames/crowd_traffic_model.gd")
const SemaphoreView = preload("res://game/minigames/crowd_semaphore_view.gd")

var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = SemaphoreView.new()
	root.add_child(view)
	await process_frame
	var model: RefCounted = TrafficModel.new()
	model.reset(false)
	model.step(0.76)
	model.step(0.80)
	view.present_traffic(model.snapshot(), model.elapsed, false, "noon")
	_expect(view.is_3d_stage_ready(), "presenter builds a real SubViewport 3D miniature")
	_expect(view.signal_lane_at(Vector2(520, 235)) == 0, "horizontal canonical pointer target remains lane zero")
	_expect(view.signal_lane_at(Vector2(760, 235)) == 1, "vertical canonical pointer target remains lane one")
	_expect(view.signal_lane_at(Vector2(640, 235)) == -1, "gap between signal targets is not clickable")
	var gui_requests: Array[int] = []
	view.signal_requested.connect(func(lane: int): gui_requests.append(lane))
	var pointer_click := InputEventMouseButton.new()
	pointer_click.button_index = MOUSE_BUTTON_LEFT
	pointer_click.pressed = true
	pointer_click.position = Vector2(760, 235)
	view._gui_input(pointer_click)
	_expect(gui_requests == [1], "real GUI click path emits one vertical lane request")
	_expect(view.guest_pool_size() == 6, "bounded six group tokens are constructed once")
	_expect(view.gate_open_for_lane(0) == false and view.gate_open_for_lane(1) == false, "red arrival phase holds both physical gate arms")
	var queue0: Array = model.snapshot().queues[0]
	_expect(view.visible_group_count() == queue0.size(), "only model-present groups are visible at the queue bank")
	var waiting_position: Vector3 = view.group_position(0)
	model.request_lane(0)
	view.present_traffic(model.snapshot(), model.elapsed, false, "noon")
	_expect(view.gate_open_for_lane(0) and not view.gate_open_for_lane(1), "walk phase raises only the model-selected lane gate")
	_expect(view.signal_lens_is_lit(0, 2) and view.signal_lens_is_lit(1, 0), "walk shows green only for the selected lane and red for the conflicting lane")
	model.step(0.60)
	view.present_traffic(model.snapshot(), model.elapsed, false, "noon")
	_expect(view.group_position(0).distance_to(waiting_position) > 0.05, "active group advances along the crossing from model progress")
	var queued_position: Vector3 = view.group_position(1)
	_expect(queued_position.distance_to(view.waiting_position(0, 0)) < 0.001, "waiting groups stay fixed behind their stop marker")
	model.step(0.90)
	view.present_traffic(model.snapshot(), model.elapsed, false, "dusk")
	_expect(model.snapshot().phase == "clearance", "test reaches real model clearance boundary")
	_expect(not view.gate_open_for_lane(0) and view.gate_clearance_for_lane(0), "clearance lowers/marks the served physical gate")
	_expect(view.signal_lens_is_lit(0, 1), "clearance phase lights the selected amber lens")
	model.step(0.05)
	view.present_traffic(model.snapshot(), model.elapsed, false, "dusk")
	_expect(view.phase_light_energy("dusk") > 0.0 and view.phase_light_energy("night") > 0.0, "all phase lighting profiles retain visible energy")
	_expect(view.rescue_marker_visible(), "rescue group has a distinct stretcher-and-flag token")
	_expect(view.group_position(1).distance_to(queued_position) < 0.001, "queued group stays anchored while clearance begins")
	var bounds: Rect2 = view.projected_content_bounds()
	print("Projected Crowd Semaphore bounds: %s" % bounds)
	_expect(view.HUD_SAFE_RECT.encloses(bounds), "projected stage geometry remains inside the shared HUD-safe frame")
	_expect(bounds.size.x >= 850.0 and bounds.size.y >= 300.0, "measured harbor miniature fills a readable horizontal stage area")
	var horizontal_card: Rect2 = view.signal_card_rect(0)
	var vertical_card: Rect2 = view.signal_card_rect(1)
	_expect(not horizontal_card.intersects(vertical_card), "Traditional Chinese signal cards have separate measured hit surfaces")
	_expect(view.HUD_SAFE_RECT.encloses(horizontal_card) and view.HUD_SAFE_RECT.encloses(vertical_card), "both signal cards stay inside the HUD-safe playfield")
	_expect(not bounds.intersects(horizontal_card) and not bounds.intersects(vertical_card), "3D harbor image does not cover either signal card")
	_expect((view.signal_card_status(0).contains("紅燈") or view.signal_card_status(0).contains("黃燈") or view.signal_card_status(0).contains("綠燈")) and not view.signal_card_status(0).contains("HORIZONTAL"), "signal status is readable Traditional Chinese")
	_expect(view.PLAYFIELD_RECT.position.y >= 160.0 and view.PLAYFIELD_RECT.end.y <= 615.0, "playfield stays between the HUD-safe bands")
	_expect(view.signal_lane_at(Vector2(520.0 + 64.0, 235.0)) == 0, "canonical hit radius includes its edge")
	_expect(view.signal_lane_at(Vector2(520.0 + 64.1, 235.0)) == -1, "canonical hit radius excludes points beyond its edge")
	var tree_size := _descendants(view)
	for index in 100:
		view.present_traffic(model.snapshot(), model.elapsed, index % 2 == 0, ["dawn", "noon", "dusk", "night"][index % 4])
	_expect(_descendants(view) == tree_size and view.guest_pool_size() == 6, "presentation updates reuse bounded nodes and cached geometry")
	var reduced_model: RefCounted = TrafficModel.new()
	reduced_model.reset(false)
	reduced_model.step(1.56)
	reduced_model.request_lane(0)
	reduced_model.step(0.30)
	view.present_traffic(reduced_model.snapshot(), reduced_model.elapsed, true, "night")
	var reduced_start: Vector3 = view.group_position(0)
	reduced_model.step(0.30)
	view.present_traffic(reduced_model.snapshot(), reduced_model.elapsed, true, "night")
	_expect(view.group_position(0).distance_to(reduced_start) > 0.05 and view.gate_open_for_lane(0), "reduced-motion still presents the real active crossing and its open gate")
	view.present_traffic({}, 0.0, true, "night")
	_expect(view.visible_group_count() == 0 and not view.gate_open_for_lane(0) and not view.gate_open_for_lane(1), "malformed snapshot safely restores empty red default")
	view.queue_free()
	await process_frame
	print("PASS: 3D crowd semaphore view (%d checks)" % checks)
	quit()

func _descendants(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _descendants(child)
	return total

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("Crowd semaphore view: " + message)
		quit(1)
