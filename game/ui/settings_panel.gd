extends RefCounted
## Compact, single-page settings with fixed category navigation.

const Paper = preload("res://game/ui/paper_ui.gd")
var host: Node
var body: VBoxContainer
var content: VBoxContainer
var tabs: Dictionary = {}
var active_category := "audio"

func open(main: Node, modal_body: VBoxContainer) -> void:
	host=main
	body=modal_body
	var heading := HBoxContainer.new()
	heading.name="SettingsCategories"
	heading.add_theme_constant_override("separation",6)
	body.add_child(heading)
	for entry in [["audio","settings.audio"],["play","settings.play"],["controls","settings.controls"],["text","settings.text"]]:
		var key: String=entry[0]
		var button := Paper.button(_t(str(entry[1])),func(): _show_category(key),heading)
		button.name="SettingsTab_"+key
		button.toggle_mode=true
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tabs[key]=button
	content=VBoxContainer.new()
	content.name="SettingsContent"
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	body.add_child(content)
	Localization.locale_changed.connect(_refresh_locale)
	_show_category("audio")

func _show_category(category: String) -> void:
	active_category=category
	for key in tabs:
		var button: Button=tabs[key]
		button.button_pressed=str(key)==category
		Paper.set_button_role(button,"tab_selected" if button.button_pressed else "tab_idle")
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match category:
		"audio": _fill_audio()
		"play": _fill_play()
		"controls": _fill_controls()
		"text": _fill_text()
	host.call_deferred("_adapt_open_menu")

func _fill_text() -> void:
	content.add_child(Paper.section_title(_t("settings.text"),Paper.TEAL))
	_add_choice("locale", _t("settings.locale"), Localization.available_locales(), _locale_labels())
	_add_choice("font_style", _t("settings.font_style"), ["pixel", "readable"], {"pixel": _t("font.pixel"), "readable": _t("font.readable")})

func _locale_labels() -> Dictionary:
	var result := {"zh_TW": _t("locale.zh_TW"), "en": _t("locale.en")}
	return result

func _add_choice(key: String, title: String, values: Array, labels: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Setting_" + key
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var label := Paper.label(title, 18)
	label.custom_minimum_size.x = 170
	row.add_child(label)
	var choice := OptionButton.new()
	choice.name = "Value_" + key
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := str(Progress.settings.get(key, "zh_TW" if key == "locale" else "pixel"))
	for value in values:
		choice.add_item(str(labels.get(value, value)))
		choice.set_item_metadata(choice.item_count - 1, value)
		if value == current:
			choice.select(choice.item_count - 1)
	row.add_child(choice)
	choice.item_selected.connect(func(index: int):
		var selected: Variant = choice.get_item_metadata(index)
		Progress.set_setting(key, selected)
	)

func _t(key: String) -> String:
	return Localization.text(key)

func _fill_audio() -> void:
	content.add_child(Paper.section_title(_t("settings.audio.title"),Paper.TEAL))
	for entry in [["master_volume",0.0,1.0],["music_volume",0.0,1.0],["sfx_volume",0.0,1.0],["text_speed",0.5,2.0]]:
		_add_slider(str(entry[0]),_t("settings." + str(entry[0])),float(entry[1]),float(entry[2]))

func _fill_play() -> void:
	content.add_child(Paper.section_title(_t("settings.play.title"),Paper.TEAL))
	_add_toggle("assist",_t("settings.assist"))
	_add_toggle("reduced_motion",_t("settings.reduced_motion"))
	_add_toggle("fullscreen",_t("settings.fullscreen"))
	_add_slider("ui_scale",_t("settings.ui_scale"),1.0,1.25)
	content.add_child(Paper.label(_t("settings.ui_scale.hint"),16,Paper.TEAL))

func _fill_controls() -> void:
	content.add_child(Paper.section_title(_t("settings.controls.title"),Paper.TEAL))
	var rows := [["move"],["walk"],["interact"],["greet"],["photo"],["wardrobe"],["time"],["ticket"],["pause"]]
	var grid := GridContainer.new()
	# Two action/key pairs share each row; every cell keeps one complete line.
	grid.name="SettingsControlRows"
	grid.columns=4
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	grid.resized.connect(_fit_control_rows.bind(grid))
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",4)
	content.add_child(grid)
	for row: Array in rows:
		var row_key := str(row[0])
		var label := Paper.label(_t("controls." + row_key),18)
		label.autowrap_mode=TextServer.AUTOWRAP_OFF
		label.size_flags_vertical=Control.SIZE_FILL
		grid.add_child(label)
		var value := Paper.label(_t("controls." + row_key + ".keys"),18,Paper.GOLD)
		value.autowrap_mode=TextServer.AUTOWRAP_OFF
		value.size_flags_vertical=Control.SIZE_FILL
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	_fit_control_rows(grid)

func _fit_control_rows(grid: GridContainer) -> void:
	if not is_instance_valid(grid) or active_category!="controls" or grid.get_child_count()!=18: return
	var scale_factor := maxf(Paper.physical_scale(body),0.01)
	# These labels now inherit the real menu font. Adapt first, then measure its
	# final size: a pre-adaptation minimum can be shorter than one rendered line
	# at 125%, which makes Label report zero drawable lines despite a nonzero rect.
	Paper.adapt_menu(grid,scale_factor)
	var row_extent := 32.0/scale_factor
	for child in grid.get_children():
		var label := child as Label
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var shaped_height := maxf(font.get_height(font_size),label.get_line_height(-1))
		row_extent=maxf(row_extent,ceilf(shaped_height)+4.0)
		label.custom_minimum_size.x=ceilf(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+2.0
	row_extent=ceilf(row_extent)
	for child in grid.get_children(): (child as Label).custom_minimum_size.y=row_extent
	var row_count := ceili(float(grid.get_child_count())/float(grid.columns))
	grid.custom_minimum_size.y=float(row_count)*row_extent+float(row_count-1)*grid.get_theme_constant("v_separation")

func _add_slider(key: String, title: String, low: float, high: float) -> void:
	var row := HBoxContainer.new()
	row.name="Setting_"+key
	row.add_theme_constant_override("separation",10)
	content.add_child(row)
	var label := Paper.label(title,18)
	label.custom_minimum_size.x=170
	row.add_child(label)
	var slider := HSlider.new()
	slider.name="Value_"+key
	slider.custom_minimum_size=Vector2(180,44)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.min_value=low
	slider.max_value=high
	slider.step=0.05
	slider.value=float(Progress.settings.get(key,1.0))
	row.add_child(slider)
	var value := Paper.label("",16,Paper.GOLD)
	value.name="Readout_"+key
	value.custom_minimum_size.x=48
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var update_readout := func(number: float) -> void:
		value.text="%d%%" % roundi(number*100.0) if key.ends_with("_volume") else ("%.2f" % number)
	var update_setting := func(number: float) -> void:
		Progress.set_setting(key,number)
		update_readout.call(number)
		if key=="ui_scale":
			Paper.set_text_scale(float(Progress.settings.get("ui_scale",1.0)))
			host.call_deferred("_adapt_open_menu")
	slider.value_changed.connect(update_setting)
	update_readout.call(slider.value)

func _add_toggle(key: String, title: String) -> void:
	var toggle := CheckButton.new()
	toggle.name="Value_"+key
	toggle.text=title
	toggle.custom_minimum_size.y=44
	toggle.button_pressed=bool(Progress.settings.get(key,false))
	toggle.toggled.connect(func(value: bool): Progress.set_setting(key,value))
	content.add_child(toggle)

func _refresh_locale(_locale_id: String) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		Localization.locale_changed.disconnect(_refresh_locale)
		return
	var focus := body.get_viewport().gui_get_focus_owner()
	var focus_name := str(focus.name) if is_instance_valid(focus) else ""
	for key in tabs:
		tabs[key].text = _t("settings." + str(key))
	_show_category(active_category)
	if not focus_name.is_empty():
		var replacement := body.find_child(focus_name, true, false) as Control
		if replacement != null:
			replacement.grab_focus()
