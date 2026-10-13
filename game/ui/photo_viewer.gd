extends Control

const Paper = preload("res://game/ui/paper_ui.gd")

var _texture: Texture2D
var _photo_title := ""
var _focus_origin: Control

func setup(texture: Texture2D, photo_title: String, focus_origin: Control) -> void:
	_texture=texture
	_photo_title=photo_title
	_focus_origin=focus_origin

func _ready() -> void:
	name="PhotoViewer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=1000
	focus_mode=Control.FOCUS_ALL
	mouse_filter=Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color=Color(0.035,0.07,0.085,0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name="PhotoViewerPanel"
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",Paper.plaque())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,12)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	margin.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := Paper.label(_photo_title,24)
	title.name="PhotoViewerTitle"
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(Paper.label("原始照片",14,Paper.GOLD))
	var picture_frame := PanelContainer.new()
	picture_frame.name="PhotoViewerPictureFrame"
	picture_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	picture_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	picture_frame.add_theme_stylebox_override("panel",Paper.plaque(Paper.DEEP))
	body.add_child(picture_frame)
	var image_rect := TextureRect.new()
	image_rect.name="PhotoViewerImage"
	image_rect.texture=_texture
	image_rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	image_rect.size_flags_vertical=Control.SIZE_EXPAND_FILL
	image_rect.custom_minimum_size=Vector2(0,0)
	image_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture_frame.add_child(image_rect)
	var controls := HBoxContainer.new()
	controls.alignment=BoxContainer.ALIGNMENT_END
	body.add_child(controls)
	var close_button := Paper.button("返回相簿",_close,controls)
	close_button.name="PhotoViewerClose"
	close_button.custom_minimum_size=Vector2(156,48)
	close_button.grab_focus()
	get_viewport().size_changed.connect(_fit)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var scale_factor := Paper.physical_scale(self)
	Paper.adapt_menu(self,scale_factor)
	var view_size := get_viewport_rect().size
	var inset := 20.0/scale_factor
	var panel := find_child("PhotoViewerPanel",true,false) as Control
	if panel != null:
		panel.custom_minimum_size=Vector2(maxf(280,view_size.x-inset*2),maxf(220,view_size.y-inset*2))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.is_action_pressed("ui_cancel")):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if is_instance_valid(_focus_origin) and _focus_origin.is_visible_in_tree() and _focus_origin.focus_mode!=Control.FOCUS_NONE:
		_focus_origin.call_deferred("grab_focus")
	queue_free()
