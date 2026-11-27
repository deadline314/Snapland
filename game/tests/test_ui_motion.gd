extends SceneTree
## Interface motion contracts that must hold without a display: every effect
## leaves controls in their resting state, and the region cover always releases.

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const RegionTransition = preload("res://game/ui/region_transition.gd")
const Collage = preload("res://game/ui/collage_kit.gd")

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("UI motion: " + message)


## WCAG contrast ratio on linearised sRGB.
func _contrast(a: Color, b: Color) -> float:
	var light := maxf(_luminance(a), _luminance(b))
	var dark := minf(_luminance(a), _luminance(b))
	return (light + 0.05) / (dark + 0.05)


func _luminance(color: Color) -> float:
	var linear := []
	for value: float in [color.r, color.g, color.b]:
		linear.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


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

	var probe := Control.new()
	host.add_child(probe)
	PaperMotion.ease_property(probe, &"modulate:a", 0.5, 0.3, 0.1)
	_check(is_equal_approx(probe.modulate.a, 0.5), "eased properties land at once without motion")
	var counter := Label.new()
	host.add_child(counter)
	PaperMotion.count_up(counter, 340, "%d 分")
	_check(counter.text == "340 分", "count-up shows the final number at once without motion")
	PaperMotion.page_turn(probe)
	_check(probe.scale == Vector2.ONE and is_equal_approx(probe.modulate.a, 1.0), "page turn rests flat and opaque")
	_check(PaperMotion.stagger(40) <= 0.25, "a long stagger still settles inside half a second")

	# Collage keepsakes keep the real button as the hit area and never shrink it.
	var plain := Paper.button("島嶼地圖", func() -> void: pass, host)
	var dressed := Paper.button("島嶼地圖", func() -> void: pass, host)
	var art := Collage.dress(dressed, "tag", 3, "map")
	_check(dressed.get_combined_minimum_size().x >= plain.get_combined_minimum_size().x and dressed.get_combined_minimum_size().y >= plain.get_combined_minimum_size().y, "a dressed keepsake is at least as large a target as the plain button")
	_check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE and is_equal_approx(art.enter, 1.0), "keepsake art ignores the pointer and rests settled")
	dressed.grab_focus()
	_check(is_equal_approx(art.lift, 1.0) and art.z_index == 1, "focus lifts the keepsake above its neighbours at once")
	dressed.release_focus()
	_check(is_equal_approx(art.lift, 0.0) and art.z_index == 0, "losing focus sets it back down")
	dressed.button_down.emit()
	_check(is_equal_approx(art.squash, 0.0) and is_equal_approx(art.ink, 0.0), "a press leaves no lingering squash or ink without motion")
	_check(dressed.text == "島嶼地圖", "the button keeps its own text")

	# Big object cards sit on a board: slots never overlap, every card keeps its
	# own minimum, and the art is baked once and shared.
	var board := Collage.Board.new()
	board.size = Vector2(500, 460)
	host.add_child(board)
	var slots := [Rect2(0.0, 0.15, 0.6, 0.45), Rect2(0.63, 0.0, 0.37, 0.52), Rect2(0.0, 0.62, 0.37, 0.38), Rect2(0.4, 0.6, 0.6, 0.4)]
	var cards: Array[Button] = []
	for index in slots.size():
		var card := Paper.button("卡片%d" % index, func() -> void: pass, board)
		Collage.pin(board, card, slots[index])
		var card_art := Collage.dress(card, ["map", "album", "hanger", "ticket"][index], index, "", Color(0, 0, 0, 0), 8.0)
		_check(card.clip_text and card.has_meta(&"collage_aspect") and is_equal_approx(card_art.enter, 1.0), "a card keeps its slot shape and rests settled")
		cards.append(card)
	board.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for first in cards.size():
		_check(cards[first].size.x >= 44.0 and cards[first].size.y >= 44.0, "card %d keeps a 44 px target" % first)
		for second in range(first + 1, cards.size()):
			_check(not cards[first].get_rect().intersects(cards[second].get_rect()), "card hit areas %d and %d never overlap" % [first, second])
	_check(board.get_combined_minimum_size().x >= cards[0].get_combined_minimum_size().x / 0.6, "the board's minimum leaves every card its own minimum")
	_check(Collage.Objects.sprite("map") == Collage.Objects.sprite("map") and Collage.Objects.silhouette("ticket") == Collage.Objects.silhouette("ticket"), "card art is baked once and reused")
	cards[1].grab_focus()
	var album_art := cards[1].get_node("CollageArt") as Collage.Item
	_check(is_equal_approx(album_art.lift, 1.0), "a focused card lifts and straightens at once")

	# Collage pages re-cut their painted boards as paper and keep text readable.
	var page := VBoxContainer.new()
	page.theme = Paper.theme()
	host.add_child(page)
	Collage.paperize(page)
	var tag := Paper.button("聲音", func() -> void: pass, page)
	var tag_face := tag.get_theme_stylebox("normal") as Paper.Board
	_check(tag_face != null and tag_face.collage and tag_face.bg_color.get_luminance() > 0.45, "a button added to a collage page becomes a light paper tag")
	var disabled_face := tag.get_theme_stylebox("disabled") as Paper.Board
	_check(_contrast(tag.get_theme_color("font_color"), tag_face.bg_color) >= 4.5 and disabled_face != null and _contrast(tag.get_theme_color("font_disabled_color"), disabled_face.bg_color) >= 4.5, "text on a light tag is re-inked dark and stays readable")
	Paper.set_button_role(tag, "tab_selected")
	var chosen := tag.get_theme_stylebox("normal") as Paper.Board
	_check(chosen != null and chosen.collage and chosen.bg_color == Paper.DEEP_TEAL and tag.get_theme_color("font_color") == Paper.PAPER, "a later role change is re-cut and a chosen tab keeps its dark face and light ink")
	Paper.set_button_role(tag, "tab_idle")
	var twin := tag.get_theme_stylebox("normal")
	Paper.set_button_role(tag, "tab_selected")
	Paper.set_button_role(tag, "tab_idle")
	_check(is_same(twin, tag.get_theme_stylebox("normal")), "paper faces are made once per style and reused")
	var scrap := Paper.card(page)
	_check((scrap.get_parent().get_theme_stylebox("panel") as Paper.Board).collage, "a card nested later is cut as paper too")
	var faces := page.get_child_count()
	Collage.turn_leaf(page)
	_check(page.get_child_count() == faces, "a page leaf is skipped without motion")
	page.queue_free()

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
