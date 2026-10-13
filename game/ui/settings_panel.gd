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
	for entry in [["audio","聲音"],["play","遊玩與畫面"],["controls","操作"]]:
		var key: String=entry[0]
		var button := Paper.button(entry[1],func(): _show_category(key),heading)
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
	host.call_deferred("_adapt_open_menu")

func _fill_audio() -> void:
	content.add_child(Paper.section_title("音訊與文字速度",Paper.TEAL))
	for entry in [["master_volume","總音量",0.0,1.0],["music_volume","背景音樂",0.0,1.0],["sfx_volume","互動音效",0.0,1.0],["text_speed","對話文字速度",0.5,2.0]]:
		_add_slider(str(entry[0]),str(entry[1]),float(entry[2]),float(entry[3]))

func _fill_play() -> void:
	content.add_child(Paper.section_title("遊玩方式與畫面",Paper.TEAL))
	_add_toggle("assist","輔助遊玩：放寬時間與判定，仍可收藏")
	_add_toggle("reduced_motion","降低動態：停止水波與裝飾擺動")
	_add_toggle("fullscreen","使用全螢幕")
	_add_slider("ui_scale","文字大小",1.0,1.25)
	content.add_child(Paper.label("文字大小會放大介面文字；按鈕仍維持完整操作高度。",16,Paper.TEAL))

func _fill_controls() -> void:
	content.add_child(Paper.section_title("鍵盤操作",Paper.TEAL))
	var rows := [["移動","W A S D／方向鍵"],["慢走","按住 Shift"],["互動","E"],["招呼","F"],["拍照","P"],["衣櫃","C"],["時段","T"],["旅券","M"],["暫停／返回","Esc"]]
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
		var label := Paper.label(str(row[0]),18)
		label.autowrap_mode=TextServer.AUTOWRAP_OFF
		label.size_flags_vertical=Control.SIZE_FILL
		grid.add_child(label)
		var value := Paper.label(str(row[1]),18,Paper.GOLD)
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
