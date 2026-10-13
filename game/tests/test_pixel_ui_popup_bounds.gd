extends SceneTree
const Paper = preload("res://game/ui/paper_ui.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Paper.set_text_scale(1.25)
	var selector := OptionButton.new()
	selector.theme=Paper.theme()
	root.add_child(selector)
	for index in range(20): selector.add_item("選項 %d"%index,index)
	for dimensions in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dimensions
		await process_frame
		Paper.adapt_menu(selector,Paper.physical_scale(selector))
		var popup := selector.get_popup()
		popup.position=Vector2i(1200,650)
		popup.popup()
		for frame in range(4): await process_frame
		var rect := Rect2(Vector2(popup.position),Vector2(popup.size))
		if not root.get_visible_rect().encloses(rect):
			push_error("Popup actual bounds fail at %s: %s"%[dimensions,rect]); quit(1); return
		var row := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))+popup.get_theme_constant("v_separation")
		if row*Paper.physical_scale(selector)<44.0:
			push_error("Popup row falls below44physical pixels"); quit(1); return
		print("POPUP_BOUNDS physical=%s actual=%s max=%s"%[dimensions,rect,popup.max_size])
		popup.hide()
	selector.queue_free()
	await process_frame
	print("PASS: actual popup window bounds and44physical rows at800/1280/1920, 1.25 text")
	quit(0)
