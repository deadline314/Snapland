extends RefCounted
## Native fitting-room panel. All edits stay in a local draft until the player commits them.

const Paper = preload("res://game/ui/paper_ui.gd")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")

var host: Node
var body: VBoxContainer
var renderer := AvatarRenderer.new()
var preview: TextureRect
var preview_caption: Label
var balance_label: Label
var status_label: Label
var status_price_plate: PanelContainer
var content: VBoxContainer
var action_row: HBoxContainer
var item_scroll: ScrollContainer
var main_row: HBoxContainer
var preview_stack: VBoxContainer
var controls: VBoxContainer
var current_tab := "appearance"
var selected_item_id := ""
var selected_slot := "outfit"
var preview_direction := "front"
var draft_appearance: Dictionary = {}
var draft_equipped: Dictionary = {}
var tab_group := ButtonGroup.new()
var tab_buttons: Dictionary = {}
var appearance_page := 0
var appearance_pages: Array[VBoxContainer] = []
var item_page := 0
var item_page_count := 0
var items_per_page := 1
var item_page_list: VBoxContainer
var item_page_nav: HBoxContainer
var visible_items: Array[Dictionary] = []
var _item_page_extent := 0.0
var _item_row_extent := 0.0
var _item_page_revision := 0
var _item_page_at_origin := false

const CATEGORY_NAMES := {
	"skin": "膚色", "species": "種族", "gender": "性別",
	"hair": "髮型", "hair_color": "髮色", "face": "表情",
}

func open(main: Node, modal_body: VBoxContainer) -> void:
	host=main
	body=modal_body
	draft_appearance=Progress.appearance.duplicate(true)
	draft_equipped=Progress.equipped.duplicate(true)
	_build()
	_show_tab("appearance")
	var root_viewport := host.get_tree().root
	if not root_viewport.size_changed.is_connected(_queue_responsive_profile):
		root_viewport.size_changed.connect(_queue_responsive_profile)
	if not body.tree_exiting.is_connected(_disconnect_responsive_profile):
		body.tree_exiting.connect(_disconnect_responsive_profile)

func _build() -> void:
	main_row=HBoxContainer.new()
	main_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation",14)
	body.add_child(main_row)
	var preview_card := PanelContainer.new()
	preview_card.custom_minimum_size=Vector2(260,0)
	preview_card.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_card.add_theme_stylebox_override("panel",Paper.plaque(Color("#f3e6c9")))
	main_row.add_child(preview_card)
	preview_stack=VBoxContainer.new()
	preview_stack.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var compact_spacing := _is_compact_profile(Paper.physical_scale(body))
	preview_stack.add_theme_constant_override("separation",4 if compact_spacing else 6)
	preview_card.add_child(preview_stack)
	preview_stack.add_child(Paper.section_title("試衣鏡"))
	var frame := PanelContainer.new()
	frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel",Paper.fitting_frame(Color("#d9cfb6")))
	preview_stack.add_child(frame)
	preview=TextureRect.new()
	preview.name="AvatarPreview"
	preview.custom_minimum_size=Vector2(210,265)
	preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(preview)
	var directions := GridContainer.new()
	directions.columns=4
	directions.add_theme_constant_override("h_separation",3)
	directions.add_theme_constant_override("v_separation",3)
	preview_stack.add_child(directions)
	var direction_group := ButtonGroup.new()
	for entry in [["front","前"],["front_left","左前"],["left","左"],["back_left","左後"],["back","後"],["back_right","右後"],["right","右"],["front_right","右前"]]:
		var direction: String=entry[0]
		var direction_button := Paper.button(entry[1],func(): _set_preview_direction(direction),directions)
		direction_button.name="Preview_"+direction
		direction_button.toggle_mode=true
		direction_button.button_group=direction_group
		direction_button.button_pressed=direction==preview_direction
		direction_button.tooltip_text="%s方向預覽" % str(entry[1])
		direction_button.custom_minimum_size.x=0
		# Paper raises the target to 44 physical pixels.
		direction_button.custom_minimum_size.y=26
		direction_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preview_caption=Paper.label("正面預覽",16,Paper.TEAL)
	preview_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	preview_stack.add_child(preview_caption)
	controls=VBoxContainer.new()
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical=Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",4 if compact_spacing else 6)
	main_row.add_child(controls)
	var ledger := PanelContainer.new()
	ledger.add_theme_stylebox_override("panel",Paper.plaque(Color("#fff8e8")))
	controls.add_child(ledger)
	var ledger_row := HBoxContainer.new()
	ledger_row.add_theme_constant_override("separation",5)
	ledger.add_child(ledger_row)
	ledger_row.add_child(Paper.icon("ticket",20,Paper.GOLD))
	balance_label=Paper.label("島幣  %d"%Progress.coins,20,Paper.INK)
	ledger_row.add_child(balance_label)
	ledger_row.add_child(Paper.label("每款遊戲首次完成可得 40 枚",16,Paper.DEEP_TEAL))
	tab_buttons.clear()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",5)
	controls.add_child(tabs)
	for entry in [["appearance","免費外觀"],["closet","衣櫃"],["shop","服飾店"]]:
		var tab_id: String=entry[0]
		var button := Paper.button(entry[1],func(): _show_tab(tab_id),tabs)
		button.name="Tab_"+tab_id
		button.toggle_mode=true
		button.button_group=tab_group
		tab_buttons[tab_id]=button
		button.custom_minimum_size.x=0
		button.custom_minimum_size.y=48
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",7)
	controls.add_child(content)
	status_label=Paper.label("",16,Paper.TEAL)
	status_label.custom_minimum_size.y=0
	status_label.hide()
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_price_plate=_add_price_contrast_plate(status_label,false)
	controls.add_child(status_label)
	action_row=HBoxContainer.new()
	action_row.add_theme_constant_override("separation",6)
	controls.add_child(action_row)
	_refresh_preview()
	_apply_responsive_profile(Paper.physical_scale(body))

func _show_tab(tab_id: String) -> void:
	_item_page_revision+=1
	current_tab=tab_id
	selected_item_id=""
	item_page=0
	item_page_nav=null
	item_page_list=null
	_item_page_extent=0.0
	_item_row_extent=0.0
	_item_page_at_origin=false
	status_label.text=""
	_sync_status_visibility()
	_set_status_price_plate(false)
	for key in tab_buttons:
		var tab: Button=tab_buttons[key]
		var selected := str(key)==tab_id
		tab.button_pressed=selected
		Paper.set_button_role(tab,"tab_selected" if selected else "tab_idle")
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	item_scroll=ScrollContainer.new()
	item_scroll.name="WardrobePageViewport"
	item_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	item_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	# Pagination owns movement. Keep the range available for programmatic page
	# offsets, hide its bar, and consume wheel/pan input so players never need to scroll.
	item_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	item_scroll.gui_input.connect(_block_item_scroll_gesture)
	item_scroll.resized.connect(func():
		if current_tab!="appearance": call_deferred("_measure_item_page_capacity")
	)
	content.add_child(item_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5)
	item_scroll.add_child(list)
	item_page_list=list
	match tab_id:
		"appearance": _fill_appearance(list)
		"closet": _fill_closet(list)
		"shop": _fill_shop(list)
	item_page_nav=HBoxContainer.new()
	item_page_nav.name="WardrobePageNavigation"
	item_page_nav.alignment=BoxContainer.ALIGNMENT_CENTER
	item_page_nav.add_theme_constant_override("separation",8)
	content.add_child(item_page_nav)
	item_page_nav.visible=tab_id!="appearance" and item_page_count>1
	if tab_id!="appearance" and item_page_count>1:
		_add_item_page_navigation()
		_update_item_page_navigation()
	_refresh_ledger()
	if tab_id=="appearance":
		var apply_button := Paper.button("套用外觀",_apply_appearance,action_row)
		apply_button.name="ApplyAppearance"
		apply_button.tooltip_text="選好喜歡的樣子，再按「套用外觀」保存。"
		Paper.set_button_role(apply_button,"primary")
		apply_button.grab_focus()
		var appearance_cancel_button := Paper.button("取消試穿",_cancel,action_row)
		appearance_cancel_button.name="CancelFitting"
		Paper.set_button_role(appearance_cancel_button,"secondary")
	elif tab_id=="closet":
		var closet_wear_button := Paper.button("穿戴所選",_wear_selected,action_row)
		closet_wear_button.name="WearSelected"
		Paper.set_button_role(closet_wear_button,"primary")
		closet_wear_button.grab_focus()
		var closet_cancel_button := Paper.button("取消試穿",_cancel,action_row)
		closet_cancel_button.name="CancelFitting"
		Paper.set_button_role(closet_cancel_button,"secondary")
	else:
		var purchase_button := Paper.button("購買所選",_purchase_selected,action_row)
		purchase_button.name="PurchaseSelected"
		Paper.set_button_role(purchase_button,"primary")
		purchase_button.grab_focus()
		var shop_wear_button := Paper.button("穿戴所選",_wear_selected,action_row)
		shop_wear_button.name="WearSelected"
		Paper.set_button_role(shop_wear_button,"secondary")
		var shop_cancel_button := Paper.button("返回遊園",_cancel,action_row)
		shop_cancel_button.name="CancelWardrobe"
		Paper.set_button_role(shop_cancel_button,"secondary")
	_refresh_preview()
	# Tabs replace their controls after the initial menu layout. Reapply the
	# idempotent physical sizing before the next frame is presented.
	host.call_deferred("_adapt_open_menu")

func _fill_appearance(list: VBoxContainer) -> void:
	appearance_page=0
	appearance_pages.clear()
	var intro := Paper.label("選好喜歡的樣子，再按「套用外觀」保存。",18,Paper.DEEP_TEAL)
	intro.name="AppearanceIntro"
	intro.visible=not _is_compact_profile(Paper.physical_scale(body))
	list.add_child(intro)
	var page_nav := HBoxContainer.new()
	page_nav.name="AppearancePageNavigation"
	page_nav.alignment=BoxContainer.ALIGNMENT_CENTER
	page_nav.add_theme_constant_override("separation",8)
	list.add_child(page_nav)
	var page_group := ButtonGroup.new()
	var appearance_page_count := _appearance_page_count()
	for page_index in appearance_page_count:
		var selected_page := page_index
		var page_button := Paper.button("外觀 %d / %d" % [page_index+1,appearance_page_count],func(): _show_appearance_page(selected_page),page_nav)
		page_button.name="AppearancePage_%d" % (page_index+1)
		page_button.toggle_mode=true
		page_button.button_group=page_group
		page_button.custom_minimum_size=Vector2(0,44)
	var options: Dictionary=Progress.appearance_options()
	for _page_index in appearance_page_count:
		var page := VBoxContainer.new()
		page.name="AppearancePageContent_%d" % (_page_index+1)
		page.add_theme_constant_override("separation",4)
		list.add_child(page)
		appearance_pages.append(page)
	var appearance_keys := ["skin","species","gender","hair","hair_color","face"]
	var fields_per_page := 3 if appearance_page_count > 1 else appearance_keys.size()
	for key_index in appearance_keys.size():
		var key: String=appearance_keys[key_index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		appearance_pages[int(key_index/fields_per_page)].add_child(row)
		var label := Paper.label(CATEGORY_NAMES[key],18)
		label.custom_minimum_size.x=72
		row.add_child(label)
		var selector := OptionButton.new()
		selector.name="Appearance_"+key
		# 16px copy becomes 20 physical pixels at 125%, leaving each selector
		# its full 44px target while all three fields fit the compact page.
		selector.add_theme_font_size_override("font_size",16)
		selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(selector)
		var values: Array=options.get(key,[])
		for i in range(values.size()):
			selector.add_item(str(values[i].name),i)
			selector.set_item_metadata(i,str(values[i].id))
			if str(values[i].id)==str(draft_appearance.get(key,"")): selector.select(i)
		selector.item_selected.connect(func(index: int):
			if index>=0 and index<values.size():
				draft_appearance[key]=str(values[index].id)
				_refresh_preview()
		)
	_show_appearance_page(0)
	page_nav.visible=appearance_page_count>1

func _appearance_page_count() -> int:
	var root_size := host.get_tree().root.size
	return 2 if Paper.text_scale()>1.0 or root_size.y<=600 else 1

func _show_appearance_page(page_index: int) -> void:
	appearance_page=clampi(page_index,0,appearance_pages.size()-1)
	for index in appearance_pages.size():
		appearance_pages[index].visible=index==appearance_page
	var page_nav := content.find_child("AppearancePageNavigation",true,false) as HBoxContainer
	if page_nav!=null:
		for index in appearance_pages.size():
			var button := page_nav.find_child("AppearancePage_%d"%(index+1),false,false) as Button
			if button!=null:
				button.button_pressed=index==appearance_page
				Paper.set_button_role(button,"tab_selected" if button.button_pressed else "tab_idle")
	if is_instance_valid(host): host.call_deferred("_adapt_open_menu")

func _fill_closet(list: VBoxContainer) -> void:
	_add_catalog_intro(list,"已收藏穿搭","選取物件可先預覽，再按「穿戴所選」。")
	visible_items.clear()
	for item: Dictionary in Progress.wardrobe_items():
		if item.id!="hat-none" and not Progress.owned_clothes.has(item.id): continue
		visible_items.append(item)
	_render_item_page(list)

func _fill_shop(list: VBoxContainer) -> void:
	_add_catalog_intro(list,"服飾目錄","選取商品可試穿；購買後會收進衣櫃。")
	visible_items.clear()
	for item: Dictionary in Progress.wardrobe_items(): visible_items.append(item)
	_render_item_page(list)

func _add_catalog_intro(list: VBoxContainer, title: String, guidance: String) -> void:
	for label in [Paper.section_title(title),Paper.label(guidance,18,Paper.DEEP_TEAL)]:
		label.set_meta("wardrobe_catalog_intro",true)
		list.add_child(label)
	(tab_buttons[current_tab] as Button).tooltip_text=guidance

func _render_item_page(list: VBoxContainer) -> void:
	item_page_count=maxi(1,ceili(float(visible_items.size())/float(maxi(items_per_page,1))))
	item_page=clampi(item_page,0,item_page_count-1)
	for child in list.get_children():
		if child.has_meta("wardrobe_item_row") or child.has_meta("wardrobe_page_padding"):
			list.remove_child(child)
			child.queue_free()
	for item in visible_items:
		_add_item_row(list,item)
	call_deferred("_measure_item_page_capacity")
	if is_instance_valid(item_page_nav):
		_update_item_page_navigation()

func _add_item_page_navigation() -> void:
	var previous := Paper.button("上一頁",func(): _set_item_page(item_page-1),item_page_nav)
	previous.name="WardrobePreviousPage"
	var page_label := Paper.label("",16,Paper.GOLD)
	page_label.name="WardrobePageNumber"
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	page_label.custom_minimum_size.x=100
	item_page_nav.add_child(page_label)
	var next := Paper.button("下一頁",func(): _set_item_page(item_page+1),item_page_nav)
	next.name="WardrobeNextPage"
	_set_item_page(item_page)

func _set_item_page(page_index: int) -> void:
	_item_page_revision+=1
	item_page=clampi(page_index,0,maxi(item_page_count-1,0))
	_update_item_page_navigation()
	var first_item_index:=item_page*items_per_page
	if first_item_index<visible_items.size():
		var target_id:=str(visible_items[first_item_index].get("id",""))
		call_deferred("_align_item_page_after_layout",target_id,_item_page_revision)
	if is_instance_valid(host): host.call_deferred("_adapt_open_menu")

func _measure_item_page_capacity() -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if current_tab=="appearance" or not is_instance_valid(item_scroll) or not is_instance_valid(item_page_list): return
	var rows: Array[Control]=[]
	var row_extent := 62.0
	for child in item_page_list.get_children():
		# Godot renames repeated sibling names; metadata identifies every retained row.
		if not child.has_meta("wardrobe_item_row"): continue
		rows.append(child)
		for cell in child.get_children():
			if cell is Control:
				row_extent=maxf(row_extent,(cell as Control).get_combined_minimum_size().y)
	if rows.is_empty() or item_scroll.size.y<=0.0: return
	row_extent=ceilf(row_extent)
	var viewport_extent := floorf(item_scroll.size.y)
	var separation := float(item_page_list.get_theme_constant("separation"))
	var capacity := maxi(1,floori((viewport_extent+separation)/(row_extent+separation)))
	var next_page_count:=maxi(1,ceili(float(visible_items.size())/float(capacity)))

	var compact := _is_compact_profile(Paper.physical_scale(body))
	var prefix_extent := 0.0
	var intro_changed := false
	for child in item_page_list.get_children():
		if not child.has_meta("wardrobe_catalog_intro"): continue
		var show_intro := not compact or next_page_count==1
		if child.visible!=show_intro: intro_changed=true
		child.visible=show_intro
		if show_intro: prefix_extent+=(child as Control).get_combined_minimum_size().y+separation
	var navigation_changed := is_instance_valid(item_page_nav) and item_page_nav.visible!=(next_page_count>1)
	if navigation_changed or intro_changed:
		# Removing the pager expands this viewport on the next container sort.
		# Cancel offsets calculated for its previous height before measuring again.
		_item_page_revision+=1
		items_per_page=capacity
		item_page_count=next_page_count
		_item_page_extent=0.0
		_update_item_page_navigation()
		call_deferred("_measure_item_page_capacity")
		return
	_item_page_at_origin=next_page_count==1 and prefix_extent+float(rows.size())*row_extent+float(rows.size()-1)*separation<=viewport_extent
	if items_per_page==capacity and item_page_count==next_page_count and is_equal_approx(_item_page_extent,viewport_extent) and is_equal_approx(_item_row_extent,row_extent): return
	items_per_page=capacity
	item_page_count=next_page_count
	_item_page_extent=viewport_extent
	_item_row_extent=row_extent
	for child in item_page_list.get_children():
		if child.has_meta("wardrobe_page_padding"):
			item_page_list.remove_child(child)
			child.queue_free()
	for row in rows: row.custom_minimum_size.y=row_extent
	# A page occupies a whole viewport, including its unused remainder. Keep
	# subsequent focusable rows below the clip instead of showing a cropped next row.
	# Final-page padding also lets Godot align that page without clamping its offset.
	for page in range(0 if _item_page_at_origin else item_page_count):
		var last_index := mini((page+1)*capacity,rows.size())-1
		var count := last_index-page*capacity+1
		var used_height := float(count)*row_extent+float(count-1)*separation
		var padding := Control.new()
		padding.name="WardrobePagePadding_%d"%page
		padding.set_meta("wardrobe_page_padding",true)
		padding.mouse_filter=Control.MOUSE_FILTER_IGNORE
		padding.custom_minimum_size.y=maxf(0.0,viewport_extent-used_height)
		item_page_list.add_child(padding)
		item_page_list.move_child(padding,rows[last_index].get_index()+1)
	if not selected_item_id.is_empty():
		for index in visible_items.size():
			if str(visible_items[index].get("id",""))==selected_item_id:
				item_page=int(index/capacity)
				break
	item_page=clampi(item_page,0,item_page_count-1)
	_update_item_page_navigation()
	_set_item_page(item_page)

func _align_item_page_after_layout(item_id: String, revision: int) -> void:
	if not _item_alignment_is_current(item_id,revision): return
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if not _item_alignment_is_current(item_id,revision): return
	var item_button := content.find_child("WardrobeItem_"+item_id,true,false) as Button
	if item_button==null: return
	var row := item_button.get_parent() as Control
	if row==null: return
	var offset:=int(round(row.get_global_rect().position.y-item_scroll.get_global_rect().position.y))+item_scroll.scroll_vertical
	item_scroll.scroll_vertical=0 if _item_page_at_origin else maxi(offset,0)
	# The scroll offset sorts its child on the next frame. Ensuring visibility
	# against the previous global rect would apply the same movement a second time.
	await host.get_tree().process_frame
	if _item_alignment_is_current(item_id,revision) and is_instance_valid(item_button) and item_scroll.is_ancestor_of(item_button):
		item_scroll.ensure_control_visible(item_button)

func _item_alignment_is_current(item_id: String, revision: int) -> bool:
	if revision!=_item_page_revision or current_tab=="appearance": return false
	if not is_instance_valid(host) or not is_instance_valid(body) or not body.is_visible_in_tree() or not is_instance_valid(item_scroll): return false
	var first_index := item_page*items_per_page
	return first_index<visible_items.size() and str(visible_items[first_index].get("id",""))==item_id

func _update_item_page_navigation() -> void:
	if not is_instance_valid(item_page_nav): return
	item_page_nav.visible=current_tab!="appearance" and item_page_count>1
	if item_page_nav.get_child_count()<3: return
	var previous := item_page_nav.get_child(0) as Button
	var page_label := item_page_nav.get_child(1) as Label
	var next := item_page_nav.get_child(2) as Button
	previous.disabled=item_page<=0
	var first_item:=item_page*items_per_page+1
	var last_item:=mini((item_page+1)*items_per_page,visible_items.size())
	page_label.text="款式 %d–%d / %d"%[first_item,last_item,visible_items.size()]
	next.disabled=item_page>=item_page_count-1

func _block_item_scroll_gesture(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
		item_scroll.accept_event()
	elif event is InputEventPanGesture:
		item_scroll.accept_event()

func _add_item_row(list: VBoxContainer, item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name="WardrobeItemRow"
	row.set_meta("wardrobe_item_row",true)
	row.set_meta("wardrobe_item_id",str(item.id))
	row.add_theme_constant_override("separation",5)
	row.custom_minimum_size.y=62
	list.add_child(row)
	var slot_name := "外套" if item.slot=="outfit" else "帽子"
	var preview_equipped: Dictionary=draft_equipped.duplicate(true)
	preview_equipped[str(item.slot)]=str(item.id)
	var item_preview := TextureRect.new()
	item_preview.name="ClothingPreview_"+str(item.id)
	item_preview.texture=renderer.texture(draft_appearance,preview_equipped,"front",0,"idle")
	item_preview.custom_minimum_size=Vector2(48,58)
	item_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	item_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	item_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(item_preview)
	var choose := Paper.button("%s  ·  %s"%[slot_name,str(item.name)],func(): _select_item(item),row)
	choose.name="WardrobeItem_"+str(item.id)
	choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choose.custom_minimum_size.x=0
	var state_text := "穿著中" if str(Progress.equipped.get(item.slot,""))==str(item.id) else ("已收藏" if item.id=="hat-none" or Progress.owned_clothes.has(item.id) else "%d 幣"%int(item.price))
	var state_color: Color=Paper.TEAL if state_text in ["穿著中","已收藏"] else Paper.PRICE_INK
	var state := Paper.label(state_text,16,state_color)
	state.custom_minimum_size=Vector2(88,36)
	state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if state_text.contains("幣") else HORIZONTAL_ALIGNMENT_RIGHT
	if state_text.contains("幣"):
		_add_price_contrast_plate(state,true)
	row.add_child(state)

func _add_price_contrast_plate(label: Label, visible: bool) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name="PriceContrastPlate"
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	plate.show_behind_parent=true
	plate.visible=visible
	var raw_surface := StyleBoxFlat.new()
	raw_surface.bg_color=Color("#f7efd9")
	raw_surface.border_color=Color("#bda878")
	raw_surface.set_border_width_all(1)
	raw_surface.set_corner_radius_all(0)
	raw_surface.set_content_margin_all(3)
	plate.add_theme_stylebox_override("panel",raw_surface)
	label.add_child(plate)
	return plate

func _set_status_price_plate(visible: bool) -> void:
	if is_instance_valid(status_price_plate):
		status_price_plate.visible=visible

func _select_item(item: Dictionary) -> void:
	var picked_id := str(item.id)
	selected_slot=str(item.slot)
	draft_equipped[selected_slot]=picked_id
	var picked_page := 0
	for item_index in visible_items.size():
		if str(visible_items[item_index].get("id",""))==picked_id:
			picked_page=int(item_index/maxi(items_per_page,1))
			break
	_show_tab(current_tab)
	if current_tab!="appearance" and picked_page!=item_page:
		_set_item_page(picked_page)
	selected_item_id=picked_id
	status_label.text="已預覽 · %s"%str(item.name)
	_sync_status_visibility()
	_refresh_selected_purchase_state()
	var item_button := content.find_child("WardrobeItem_"+picked_id,true,false) as Button
	if item_button!=null:
		# Preserve immediate keyboard focus while the replacement list is laid out;
		# the deferred pass below then scrolls the focused row into its visible area.
		item_button.grab_focus()
		item_scroll.ensure_control_visible(item_button)
		call_deferred("_focus_selected_item_after_layout",picked_id)

func _focus_selected_item_after_layout(item_id: String) -> void:
	# _select_item rebuilds the list. Wait for those new rows to acquire their final
	# layout before scrolling; otherwise focus may remain on an offscreen row.
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if selected_item_id!=item_id or not is_instance_valid(item_scroll): return
	var item_button := content.find_child("WardrobeItem_"+item_id,true,false) as Button
	if item_button==null: return
	item_scroll.ensure_control_visible(item_button)
	await host.get_tree().process_frame
	if selected_item_id!=item_id or not is_instance_valid(item_scroll) or not is_instance_valid(item_button): return
	item_scroll.ensure_control_visible(item_button)
	item_button.grab_focus()

func _queue_responsive_profile() -> void:
	# Main's size handler adapts font and hit-target sizes first. Defer this geometry
	# pass so it reads the new final viewport transform and stays idempotent.
	call_deferred("_apply_current_responsive_profile")

func _apply_current_responsive_profile() -> void:
	if not is_instance_valid(body): return
	_apply_responsive_profile(Paper.physical_scale(body))
	if current_tab=="shop" and not selected_item_id.is_empty():
		# The selected shop row may move outside the viewport when compact spacing
		# changes. Re-run the same settled-layout visibility pass used on selection.
		call_deferred("_focus_selected_item_after_layout",selected_item_id)

func _disconnect_responsive_profile() -> void:
	if not is_instance_valid(host): return
	var root_viewport := host.get_tree().root
	var callback := Callable(self,"_queue_responsive_profile")
	if root_viewport.size_changed.is_connected(callback):
		root_viewport.size_changed.disconnect(callback)

func _apply_responsive_profile(scale_factor: float) -> void:
	if not is_instance_valid(body) or not is_instance_valid(preview): return
	var compact := _is_compact_profile(scale_factor)
	main_row.add_theme_constant_override("separation",10 if compact else 14)
	preview_stack.add_theme_constant_override("separation",3 if compact else 6)
	controls.add_theme_constant_override("separation",4 if compact else 6)
	content.add_theme_constant_override("separation",5 if compact else 7)
	var intro := content.find_child("AppearanceIntro",true,false) as Label
	if intro!=null: intro.visible=not compact
	preview.custom_minimum_size.y=220 if compact else 265
	for key in tab_buttons:
		var tab: Button=tab_buttons[key]
		Paper.set_button_role(tab,"tab_selected" if tab.button_pressed else "tab_idle")

func _is_compact_profile(scale_factor: float) -> bool:
	# On fixed-resolution windows, Godot's canvas transform can report a scale
	# above 1 while the actual display is small. Use window pixels as a second
	# signal so the preview and spacing shrink before the fixed shell overflows.
	return scale_factor<0.9 or (scale_factor>1.0 and host.get_tree().root.size.y<=600)

func _refresh_selected_purchase_state() -> void:
	if current_tab!="shop" or not is_instance_valid(action_row): return
	var purchase := action_row.find_child("PurchaseSelected",false,false) as Button
	if purchase==null: return
	if selected_item_id.is_empty():
		_set_status_price_plate(false)
		purchase.disabled=false
		return
	var item: Dictionary=Progress.wardrobe_item(selected_item_id)
	if item.is_empty():
		_set_status_price_plate(false)
		purchase.disabled=true
		status_label.text="找不到這件商品。"
		_sync_status_visibility()
		status_label.add_theme_color_override("font_color",Paper.PRICE_INK)
		return
	if selected_item_id=="hat-none" or Progress.owned_clothes.has(selected_item_id):
		_set_status_price_plate(false)
		purchase.disabled=true
		status_label.text="已收藏，請在衣櫃穿戴。"
		_sync_status_visibility()
		status_label.add_theme_color_override("font_color",Paper.TEAL)
		return
	var price := int(item.price)
	if Progress.coins<price:
		_set_status_price_plate(true)
		purchase.disabled=true
		status_label.text="餘額不足：需要 %d 枚，還差 %d 枚。"%[price,price-Progress.coins]
		_sync_status_visibility()
		status_label.add_theme_color_override("font_color",Paper.PRICE_INK)
	else:
		_set_status_price_plate(false)
		purchase.disabled=false
		status_label.text="已預覽 · %s"%str(item.name)
		_sync_status_visibility()
		status_label.add_theme_color_override("font_color",Paper.TEAL)

func _purchase_selected() -> void:
	if selected_item_id.is_empty():
		_show_status("先選一件商品預覽。",Paper.CORAL)
		return
	var item: Dictionary=Progress.wardrobe_item(selected_item_id)
	if item.is_empty():
		_show_status("找不到這件商品。",Paper.CORAL)
		return
	if Progress.owned_clothes.has(selected_item_id) or selected_item_id=="hat-none":
		_show_status("這件已在衣櫃裡，可以直接穿戴。",Paper.TEAL)
		return
	if Progress.coins<int(item.price):
		_show_status("海島幣不足，還差 %d 枚。"%[int(item.price)-Progress.coins],Paper.PRICE_INK)
		return
	var bought_id := selected_item_id
	if not Progress.buy_clothing(bought_id):
		_show_status("購買沒有完成，海島幣未扣款。",Paper.CORAL)
		return
	var bought_name := str(item.name)
	draft_equipped=Progress.equipped.duplicate(true)
	_show_tab("shop")
	_show_status("已收藏「%s」，可到衣櫃穿戴。"%bought_name,Paper.TEAL)

func _wear_selected() -> void:
	if selected_item_id.is_empty():
		_show_status("先選一件衣物。",Paper.CORAL)
		return
	var item: Dictionary=Progress.wardrobe_item(selected_item_id)
	if item.is_empty() or (selected_item_id!="hat-none" and not Progress.owned_clothes.has(selected_item_id)):
		_show_status("這件尚未收藏，先購買後才能穿戴。",Paper.CORAL)
		return
	if str(Progress.equipped.get(item.slot,""))==selected_item_id:
		_show_status("這件已經穿在身上。",Paper.TEAL)
		return
	if not Progress.equip_clothing(selected_item_id):
		draft_equipped=Progress.equipped.duplicate(true)
		_refresh_preview()
		_show_status("穿戴沒有保存，原穿搭仍保留。",Paper.CORAL)
		return
	draft_equipped=Progress.equipped.duplicate(true)
	_show_tab(current_tab)
	_show_status("已穿戴「%s」。"%str(item.name),Paper.TEAL)
	if host.world.has_method("play_action"): host.world.play_action("wave")

func _apply_appearance() -> void:
	var available: Dictionary=Progress.appearance_options()
	for key in CATEGORY_NAMES:
		var value := str(draft_appearance.get(key,""))
		var valid := false
		for option: Dictionary in available.get(key,[]):
			if str(option.id)==value: valid=true; break
		if not valid:
			_show_status("有一項外觀選擇無效，請重新選擇。",Paper.CORAL)
			return
	if not Progress.set_appearance_batch(draft_appearance):
		draft_appearance=Progress.appearance.duplicate(true)
		_refresh_preview()
		_show_status("外觀沒有保存，原設定已還原。",Paper.CORAL)
		return
	_show_status("外觀已套用。",Paper.TEAL)
	if host.world.has_method("play_action"): host.world.play_action("wave")

func _cancel() -> void:
	draft_appearance=Progress.appearance.duplicate(true)
	draft_equipped=Progress.equipped.duplicate(true)
	host._close()

func _show_status(message: String, tint: Color) -> void:
	status_label.text=message
	_sync_status_visibility()
	status_label.add_theme_color_override("font_color",tint)
	_set_status_price_plate(tint==Paper.PRICE_INK)
	# Feedback already lives in this panel; do not repeat it over world wayfinding.

func _refresh_ledger() -> void:
	if is_instance_valid(balance_label): balance_label.text="海島幣：%d"%Progress.coins

func _refresh_preview() -> void:
	if not is_instance_valid(preview): return
	preview.texture=renderer.texture(draft_appearance,draft_equipped,preview_direction,0,"idle")
	preview_caption.text="%s  ·  %s"%[
		str(Progress.wardrobe_item(str(draft_equipped.get("outfit",""))).get("name","海港旅人")),
		str(Progress.wardrobe_item(str(draft_equipped.get("hat",""))).get("name","不戴帽子")),
	]

func _set_preview_direction(direction: String) -> void:
	if direction not in ["front","front_left","left","back_left","back","back_right","right","front_right"]: return
	preview_direction=direction
	_refresh_preview()

func _sync_status_visibility() -> void:
	status_label.visible=not status_label.text.strip_edges().is_empty()
	if is_instance_valid(host): host.call_deferred("_adapt_open_menu")
