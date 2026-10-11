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
var content: VBoxContainer
var action_row: HBoxContainer
var item_scroll: ScrollContainer
var current_tab := "appearance"
var selected_item_id := ""
var selected_slot := "outfit"
var preview_direction := "front"
var draft_appearance: Dictionary = {}
var draft_equipped: Dictionary = {}

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

func _build() -> void:
	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation",14)
	body.add_child(main_row)
	var preview_card := PanelContainer.new()
	preview_card.custom_minimum_size=Vector2(260,0)
	preview_card.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_card.add_theme_stylebox_override("panel",Paper.plaque(Color("#f3e6c9")))
	main_row.add_child(preview_card)
	var preview_stack := VBoxContainer.new()
	preview_stack.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_stack.add_theme_constant_override("separation",6)
	preview_card.add_child(preview_stack)
	preview_stack.add_child(Paper.section_title("試衣鏡  ·  即時預覽"))
	var frame := PanelContainer.new()
	frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel",Paper.box(Color("#e6d7b8"),5))
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
	var directions := HBoxContainer.new()
	directions.add_theme_constant_override("separation",4)
	preview_stack.add_child(directions)
	var direction_group := ButtonGroup.new()
	for entry in [["front","前"],["left","左"],["right","右"],["back","後"]]:
		var direction: String=entry[0]
		var direction_button := Paper.button(entry[1],func(): _set_preview_direction(direction),directions)
		direction_button.name="Preview_"+direction
		direction_button.toggle_mode=true
		direction_button.button_group=direction_group
		direction_button.button_pressed=direction==preview_direction
		direction_button.tooltip_text={"front":"正面預覽","left":"左側預覽","right":"右側預覽","back":"背面預覽"}[direction]
		direction_button.custom_minimum_size.x=0
		direction_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preview_caption=Paper.label("正面預覽",16,Paper.TEAL)
	preview_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	preview_stack.add_child(preview_caption)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical=Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",6)
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
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",5)
	controls.add_child(tabs)
	for entry in [["appearance","免費外觀"],["closet","衣櫃"],["shop","服飾店"]]:
		var tab_id: String=entry[0]
		var button := Paper.button(entry[1],func(): _show_tab(tab_id),tabs)
		button.name="Tab_"+tab_id
		button.custom_minimum_size.x=0
		button.custom_minimum_size.y=48
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",7)
	controls.add_child(content)
	status_label=Paper.label("",16,Paper.TEAL)
	status_label.custom_minimum_size.y=22
	controls.add_child(status_label)
	action_row=HBoxContainer.new()
	action_row.add_theme_constant_override("separation",6)
	controls.add_child(action_row)
	_refresh_preview()

func _show_tab(tab_id: String) -> void:
	current_tab=tab_id
	selected_item_id=""
	status_label.text=""
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	item_scroll=ScrollContainer.new()
	item_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	item_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(item_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5)
	item_scroll.add_child(list)
	match tab_id:
		"appearance": _fill_appearance(list)
		"closet": _fill_closet(list)
		"shop": _fill_shop(list)
	_refresh_ledger()
	if tab_id=="appearance":
		var apply_button := Paper.button("套用外觀",_apply_appearance,action_row)
		apply_button.name="ApplyAppearance"
		apply_button.grab_focus()
		var appearance_cancel_button := Paper.button("取消試穿",_cancel,action_row)
		appearance_cancel_button.name="CancelFitting"
	elif tab_id=="closet":
		var closet_wear_button := Paper.button("穿戴所選",_wear_selected,action_row)
		closet_wear_button.name="WearSelected"
		closet_wear_button.grab_focus()
		var closet_cancel_button := Paper.button("取消試穿",_cancel,action_row)
		closet_cancel_button.name="CancelFitting"
	else:
		var purchase_button := Paper.button("購買所選",_purchase_selected,action_row)
		purchase_button.name="PurchaseSelected"
		purchase_button.grab_focus()
		var shop_wear_button := Paper.button("穿戴所選",_wear_selected,action_row)
		shop_wear_button.name="WearSelected"
		var shop_cancel_button := Paper.button("返回遊園",_cancel,action_row)
		shop_cancel_button.name="CancelWardrobe"
	_refresh_preview()
	# Tabs replace their controls after the initial menu layout. Reapply the
	# idempotent physical sizing before the next frame is presented.
	host.call_deferred("_adapt_open_menu")

func _fill_appearance(list: VBoxContainer) -> void:
	list.add_child(Paper.label("選好喜歡的樣子，再按「套用外觀」保存。",18,Paper.DEEP_TEAL))
	var options: Dictionary=Progress.appearance_options()
	for key in ["skin","species","gender","hair","hair_color","face"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		list.add_child(row)
		var label := Paper.label(CATEGORY_NAMES[key],18)
		label.custom_minimum_size.x=72
		row.add_child(label)
		var selector := OptionButton.new()
		selector.name="Appearance_"+key
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

func _fill_closet(list: VBoxContainer) -> void:
	list.add_child(Paper.section_title("已收藏穿搭"))
	list.add_child(Paper.label("選取物件可先預覽，再按「穿戴所選」。",18,Paper.DEEP_TEAL))
	for item: Dictionary in Progress.wardrobe_items():
		if item.id!="hat-none" and not Progress.owned_clothes.has(item.id): continue
		_add_item_row(list,item)

func _fill_shop(list: VBoxContainer) -> void:
	list.add_child(Paper.section_title("服飾目錄"))
	list.add_child(Paper.label("選取商品可試穿；購買後會收進衣櫃。",18,Paper.DEEP_TEAL))
	for item: Dictionary in Progress.wardrobe_items():
		_add_item_row(list,item)

func _add_item_row(list: VBoxContainer, item: Dictionary) -> void:
	var row := HBoxContainer.new()
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
	var state_color: Color=Paper.TEAL if state_text in ["穿著中","已收藏"] else Paper.CORAL
	var state := Paper.label(state_text,16,state_color)
	state.custom_minimum_size.x=88
	state.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(state)

func _select_item(item: Dictionary) -> void:
	var picked_id := str(item.id)
	selected_slot=str(item.slot)
	draft_equipped[selected_slot]=picked_id
	_show_tab(current_tab)
	selected_item_id=picked_id
	status_label.text="已預覽 · %s"%str(item.name)
	var item_button := content.find_child("WardrobeItem_"+picked_id,true,false) as Button
	if item_button!=null:
		item_button.grab_focus()
		item_scroll.ensure_control_visible(item_button)
		item_scroll.call_deferred("ensure_control_visible",item_button)

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
		_show_status("海島幣不足，還差 %d 枚。"%[int(item.price)-Progress.coins],Paper.CORAL)
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
	status_label.add_theme_color_override("font_color",tint)
	if host.has_method("_notice"): host._notice(message)

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
	if direction not in ["front","left","right","back"]: return
	preview_direction=direction
	_refresh_preview()
