extends SceneTree
const Tutorial = preload("res://game/ui/tutorial_panel.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Paper.set_text_scale(1.25)
	var panel := Tutorial.new()
	root.add_child(panel)
	await _frames(2)
	for dimensions in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dimensions
		await _frames(2)
		for lesson_id in panel.catalog.lesson_ids():
			await panel.open_tutorial(lesson_id)
			for step in range(panel.catalog.get_lesson(lesson_id).steps.size()):
				panel._apply_responsive_layout(float(dimensions.x)/1280.0)
				await _frames(5)
				_check(root.get_visible_rect().encloses(panel._card.get_global_rect()),"whole tutorial frame fits%s/%s/%s"%[dimensions,lesson_id,step])
				_check(panel._text_scroll.size.y*Paper.physical_scale(panel)>=80.0,"copy viewport retains80physical height")
				for action in panel._footer_buttons:
					_check(root.get_visible_rect().encloses(action.get_global_rect()) and action.size.y*Paper.physical_scale(action)>=43.9,"tutorial footer action fits at44physical pixels")
				var seen: Array[bool]=[false,false,false,false,false]
				_check(panel._copy_sections.size()==5,"all five original semantic fields stay in the real document")
				for group_index in range(panel._copy_pages.size()-1):
					var group := panel._copy_pages[group_index] as VBoxContainer
					var used := 0.0
					for section in group.get_children(): used+=section.get_combined_minimum_size().y
					used+=float(group.get_child_count()-1)*6.0
					var next_section := panel._copy_pages[group_index+1].get_child(0) as Control
					_check(used+6.0+next_section.get_combined_minimum_size().y>panel._text_scroll.size.y,"pagination only adds a page when the next full field cannot fit available height")
				for page in range(panel._copy_pages.size()):
					panel._set_copy_page(page)
					await _frames(4)
					var group := panel._copy_pages[page] as Control
					var indices: Array=group.get_meta("semantic_indices")
					_check(panel._text_scroll.get_global_rect().encloses(group.get_global_rect()),"requested actual page group appears fully in its viewport: %s/%s/%s/page%s group=%s clip=%s"%[dimensions,lesson_id,step,page,group.get_global_rect(),panel._text_scroll.get_global_rect()])
					for semantic_index in indices:
						var section := panel._copy_sections[semantic_index] as Control
						var complete: bool=panel._text_scroll.get_global_rect().encloses(section.get_global_rect())
						_check(complete,"semantic field%s is genuinely readable on page%s"%[semantic_index,page])
						if complete: seen[semantic_index]=true
					var labels := panel._text_scroll.find_children("*","Label",true,false)
					for label in labels:
						var rect: Rect2=label.get_global_rect()
						var clip: Rect2=panel._text_scroll.get_global_rect()
						if not clip.intersects(rect): continue
						_check(clip.grow(1).encloses(rect),"paged visible copy never partially clips: %s/%s/%s/page%s text=%s rect=%s clip=%s"%[dimensions,lesson_id,step,page,label.text,rect,clip])
						_check(rect.size.y+1>=label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")),"paged copy preserves real line height")
					var before := panel._text_scroll.scroll_vertical
					var wheel := InputEventMouseButton.new()
					wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
					wheel.position=panel._text_scroll.get_global_rect().get_center()
					wheel.pressed=true
					root.push_input(wheel,true)
					await _frames(1)
					_check(panel._text_scroll.scroll_vertical==before,"wheel cannot move programmatic lesson pages")
				for semantic_index in range(5): _check(seen[semantic_index],"all original five fields fully appear at least once: %s/%s/%s/field%s"%[dimensions,lesson_id,step,semantic_index])
				panel.next_step()
	panel.queue_free()
	await _frames(2)
	if failures.is_empty():
		print("PASS: native-matching tutorial39steps, all five semantic fields in capacity-driven page groups, three sizes/1.25, visible copy clip/line height and blocked wheel")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _frames(count: int) -> void:
	for index in range(count): await process_frame
func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
