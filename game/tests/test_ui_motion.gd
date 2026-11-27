extends SceneTree
## Interface motion contracts that must hold without a display: every effect
## leaves controls in their resting state, and the region cover always releases.

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const RegionTransition = preload("res://game/ui/region_transition.gd")

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("UI motion: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	await process_frame

	_check(not PaperMotion.has_display(), "this suite expects a headless run")
	_check(not PaperMotion.enabled(), "motion is off without a display")

	var panel := Control.new()
	panel.position = Vector2(40, 60)
	host.add_child(panel)
	PaperMotion.enter(panel)
	_check(panel.position == Vector2(40, 60) and is_equal_approx(panel.modulate.a, 1.0), "enter rests in place")
	PaperMotion.fade_in(panel)
	_check(is_equal_approx(panel.modulate.a, 1.0), "fade_in rests opaque")
	PaperMotion.flash(panel)
	_check(panel.self_modulate == Color.WHITE, "flash rests untinted")
	PaperMotion.pop(panel)
	_check(panel.scale == Vector2.ONE, "pop rests at full size")

	Paper.set_reduced_motion(true)
	_check(not PaperMotion.enabled(), "reduced motion disables transitions")
	Paper.set_reduced_motion(false)

	var button := Paper.button("測試", func() -> void: pass, host)
	_check(button.has_meta(&"paper_motion_bound"), "paper buttons get feedback")
	var connections := button.mouse_entered.get_connections().size()
	PaperMotion.attach_button(button)
	_check(button.mouse_entered.get_connections().size() == connections, "feedback binds once")
	button.disabled = true
	button.mouse_entered.emit()
	_check(button.self_modulate == Color.WHITE, "disabled buttons stay untinted")

	var note := Label.new()
	host.add_child(note)
	PaperMotion.rise_and_free(note)
	await process_frame
	_check(not is_instance_valid(note), "notes are freed at once without a display")

	var transition := RegionTransition.new()
	host.add_child(transition)
	_check(not transition.busy() and not transition.visible, "transition starts idle and hidden")
	var covered := [false]
	var revealed := [false]
	transition.covered.connect(func() -> void: covered[0] = true)
	transition.revealed.connect(func() -> void: revealed[0] = true)
	transition.cover("潮汐碼頭", "前往", Color("#08202b"), Color("#6fc7b7"))
	_check(transition.busy() and transition.visible, "cover holds input at once")
	_check(transition.mouse_filter == Control.MOUSE_FILTER_STOP, "cover blocks the pointer")
	for frame in 120:
		if covered[0]:
			break
		await process_frame
	_check(covered[0], "cover reports when the screen is hidden")
	_check(transition.busy(), "cover stays busy until revealed")
	transition.reveal()
	for frame in 120:
		if revealed[0]:
			break
		await process_frame
	_check(revealed[0] and not transition.busy() and not transition.visible, "reveal releases and hides")
	_check(transition.mouse_filter == Control.MOUSE_FILTER_IGNORE, "reveal frees the pointer")

	transition.cover("糖果工廠", "前往", Color("#08202b"), Color("#6fc7b7"))
	transition.cancel()
	_check(not transition.busy() and not transition.visible, "cancel releases immediately")

	host.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: interface motion rests, button feedback and region cover release (%d checks)" % checks)
	quit(1 if failures > 0 else 0)
