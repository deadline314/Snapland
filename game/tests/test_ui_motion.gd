extends SceneTree
## Interface motion contracts that must hold without a display: every effect
## leaves controls in their resting state, and the region cover always releases.

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const RegionTransition = preload("res://game/ui/region_transition.gd")
const ArrivalStamp = preload("res://game/ui/arrival_stamp.gd")
const Collage = preload("res://game/ui/collage_kit.gd")
const CollageLife = preload("res://game/ui/collage_life.gd")
const ArcadeMedal = preload("res://game/ui/arcade_medal.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

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
	transition.cover(Color("#08202b"), Color("#6fc7b7"))
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

	transition.cover(Color("#08202b"), Color("#6fc7b7"))
	transition.cancel()
	_check(not transition.busy() and not transition.visible, "cancel releases immediately")
	_check(transition.find_children("*", "Label", true, false).is_empty(), "the travel cover carries no words")

	var stamp := ArrivalStamp.new()
	host.add_child(stamp)
	_check(not stamp.showing() and stamp.mouse_filter == Control.MOUSE_FILTER_IGNORE, "arrival stamp starts hidden and never takes the pointer")
	stamp.show_region("harbor")
	_check(stamp.showing() and stamp.region == "harbor", "arrival stamp shows the district it was pressed for")
	var deadline := Time.get_ticks_msec() + 6000
	while stamp.showing() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not stamp.showing() and stamp.region.is_empty(), "arrival stamp lifts away by itself")
	stamp.show_region("candy", 0.3)
	stamp.dismiss()
	_check(not stamp.showing(), "arrival stamp can be dismissed at once")

	await _check_life(host)

	host.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: interface motion rests, button feedback and region cover release (%d checks)" % checks)
	quit(1 if failures > 0 else 0)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## A collage page as the menus build it: sheet, headline, tags and object cards.
func _collage_page(host: Control) -> PanelContainer:
	var page := PanelContainer.new()
	page.size = Vector2(700, 460)
	host.add_child(page)
	Collage.sheet(page)
	var column := VBoxContainer.new()
	page.add_child(column)
	var eyebrow := Paper.label("SNAPLAND", 14)
	column.add_child(eyebrow)
	var title := Paper.label("遊園選單", 25)
	column.add_child(title)
	Collage.headline(title, eyebrow)
	for index in 4:
		Collage.dress(Paper.button("吊牌%d" % index, func() -> void: pass, column), "tag", index)
	var board := Collage.Board.new()
	board.custom_minimum_size = Vector2(400, 200)
	column.add_child(board)
	for index in 2:
		var card := Paper.button("卡片%d" % index, func() -> void: pass, board)
		Collage.pin(board, card, Rect2(index * 0.5, 0.0, 0.48, 1.0))
		Collage.dress(card, ["map", "album"][index], index)
	return page


## Idle life, sticker flights and result shows, with motion forced on so the
## real tweens run headless; then the same calls with reduced motion.
func _check_life(host: Control) -> void:
	PaperMotion.force_motion(true)
	var page := _collage_page(host)
	var idle := page.get_node("CollageIdle")
	var swaying: Array = page.find_children("CollageArt", "", true, false)
	await _wait(0.6)
	_check(idle.is_processing() and swaying.size() == 6 and swaying.any(func(art: Control) -> bool: return absf(art.rotation) > 0.0001), "one page clock sways the keepsakes and cards")
	_check(swaying.all(func(art: Control) -> bool: return absf(rad_to_deg(art.rotation)) <= 1.61 and absf(art.scale.x - 1.0) <= 0.013), "idle sway stays under about 1.5 degrees and breath under 1.3 percent")
	_check(swaying.all(func(art: Control) -> bool: return art.get_parent().rotation == 0.0 and art.get_parent().scale == Vector2.ONE), "only the art moves; the buttons (hit areas) stay put")
	page.hide()
	await process_frame
	_check(not idle.is_processing() and swaying.all(func(art: Control) -> bool: return art.rotation == 0.0 and art.scale == Vector2.ONE), "the clock stops and the art rests level while the page is hidden")
	page.show()
	await process_frame
	_check(idle.is_processing(), "the clock wakes when the page shows again")
	Collage.sweep_off(page)
	_check(page.mouse_filter == Control.MOUSE_FILTER_IGNORE and (swaying[0] as Control).get_parent().focus_mode == Control.FOCUS_NONE, "a swept page never takes clicks or focus")
	var page_id := page.get_instance_id()
	var swept_after: float = await _settle(func() -> bool: return not is_instance_id_valid(page_id))
	_check(not is_instance_valid(page) and swept_after <= 0.5, "a swept page frees itself within half a second (%.2f s)" % swept_after)

	# Stickers queue a beat apart, land in order and leave nothing behind.
	var album := Control.new()
	album.position = Vector2(1000, 30)
	album.size = Vector2(120, 60)
	host.add_child(album)
	var landed := [0]
	var bump := func() -> void: landed[0] += 1
	for index in 3:
		CollageLife.stick(host, null, Rect2(500, 300, 180, 100), album, bump)
	CollageLife.stick(host, null, Rect2(500, 300, 180, 100), album, bump)
	_check(landed[0] == 1 and _stickers(host).size() == 3, "three stickers fly at once; a fourth lands at once as a bump")
	_check(CollageLife.STICK_SECONDS + CollageLife.STICK_GAP * (CollageLife.STICK_QUEUE - 1) <= 1.2 and CollageLife.STICK_SECONDS <= 1.0, "each sticker flight is under a second")
	await _wait(CollageLife.STICK_SECONDS + CollageLife.STICK_GAP * 2.0 + 0.1)
	for frame in 600:
		if _stickers(host).is_empty():
			break
		await process_frame
	await _settle(func() -> bool: return album.scale.is_equal_approx(Vector2.ONE))
	_check(landed[0] == 4 and _stickers(host).is_empty() and int(host.get_meta(&"collage_stickers")) == 0, "the queue ends with every sticker stuck and freed")
	_check(album.scale.is_equal_approx(Vector2.ONE), "the album bump settles back to size")
	for index in 2:
		CollageLife.stick(host, null, Rect2(500, 300, 180, 100), album, bump)
	_check(PaperMotion.showing() and PaperMotion.skip() and landed[0] == 6, "any key finishes queued stickers in their final state")
	await process_frame
	_check(_stickers(host).is_empty(), "skipped stickers are freed")

	# Celebrations grow with the medal; a missed medal sags instead.
	_check(CollageLife.PIECES[1] < CollageLife.PIECES[2] and CollageLife.PIECES[2] < CollageLife.PIECES[3] and CollageLife.STREAMERS[3] > CollageLife.STREAMERS[2] and CollageLife.PIECES[0] == 0, "confetti grows from bronze to gold")
	_check(CollageLife.SLAM_SECONDS + CollageLife.CONFETTI_SECONDS <= 1.0 and CollageLife.DROOP_SECONDS + 0.2 <= 1.0, "result shows last under a second")
	for tier in 4:
		var medal := ArcadeMedal.new()
		medal.medal = tier
		medal.size = Vector2(112, 160)
		host.add_child(medal)
		CollageLife.celebrate(medal, tier, medal)
		var burst := medal.get_node_or_null("CollageConfetti")
		_check((burst != null) == (tier > 0) and (burst == null or burst.tier == tier), "tier %d throws %s" % [tier, "its confetti" if tier > 0 else "nothing"])
		await _settle(func() -> bool: return medal.get_node_or_null("CollageConfetti") == null and medal.ink < 0.01 and is_equal_approx(medal.thud, 0.0))
		_check(medal.get_node_or_null("CollageConfetti") == null and is_equal_approx(medal.slam, 0.0) and is_equal_approx(medal.thud, 0.0) and medal.ink < 0.01, "tier %d lands stamped flat and its confetti is gone (slam %.2f, thud %.2f, ink %.2f)" % [tier, medal.slam, medal.thud, medal.ink])
		medal.queue_free()
	var again := Paper.button("再玩一次", func() -> void: pass, host)
	var again_art := Collage.dress(again, "stamp", 0, "play")
	var empty := ArcadeMedal.new()
	host.add_child(empty)
	CollageLife.flop(null, again_art, empty)
	await _settle(func() -> bool: return not PaperMotion.showing() and is_equal_approx(again_art.wiggle, 0.0))
	_check(empty.droop > 10.0 and is_equal_approx(again_art.wiggle, 0.0), "no medal: the slot sags on its ribbon and the stamp swings back to rest")

	# Reduced motion: final state at once and nothing added to the tree.
	Paper.set_reduced_motion(true)
	var calm := _collage_page(host)
	await process_frame
	_check(not calm.get_node("CollageIdle").is_processing() and calm.find_children("CollageArt", "", true, false).all(func(art: Control) -> bool: return art.rotation == 0.0), "reduced motion keeps every page still")
	var children := host.get_child_count()
	CollageLife.stick(host, null, Rect2(500, 300, 180, 100), album, bump)
	CollageLife.celebrate(empty, 3, empty)
	CollageLife.flop(null, again_art, empty)
	_check(landed[0] == 7 and host.get_child_count() == children and empty.get_child_count() == 0 and album.scale == Vector2.ONE, "reduced motion lands stickers and results at once without new nodes")
	Collage.sweep_off(calm)
	await process_frame
	_check(not is_instance_valid(calm), "reduced motion removes a replaced page at once")
	Paper.set_reduced_motion(false)

	# Opening and closing the same page again and again leaves no nodes or
	# textures behind.
	await _wait(0.3)
	var counts: Array[int] = [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	var textures := 0
	for cycle in 5:
		var round_page := _collage_page(host)
		await _wait(0.12)
		Collage.sweep_off(round_page)
		for frame in 600:
			if not is_instance_valid(round_page):
				break
			await process_frame
		await process_frame
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if cycle == 0:
			textures = Pixels._cache.size()
	_check(counts.min() == counts.max(), "node count is stable over five open/close cycles %s" % str(counts))
	_check(Pixels._cache.size() == textures, "no textures are made after the first open")
	again.queue_free()
	empty.queue_free()
	album.queue_free()
	PaperMotion.force_motion(false)


func _stickers(layer: Node) -> Array:
	return layer.get_children().filter(func(child: Node) -> bool: return child is CollageLife.Sticker)


## Run frames until `done` holds (a few seconds at most): tweens follow the
## frame clock, which can trail the wall clock on a busy machine.
## Returns the frame-clock seconds it took.
func _settle(done: Callable) -> float:
	var until := Time.get_ticks_msec() + 15000
	var elapsed := 0.0
	while not done.call() and Time.get_ticks_msec() < until:
		await process_frame
		elapsed += root.get_process_delta_time()
	await process_frame
	return elapsed
