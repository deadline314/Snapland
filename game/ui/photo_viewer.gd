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
	var viewport_size := get_viewport_rect().size
	panel.custom_minimum_size=Vector2(minf(980.0,viewport_size.x-48.0),minf(650.0,viewport_size.y-48.0))
	panel.add_theme_stylebox_override("panel",Paper.plaque(Color("#f7efd9")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,18)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	margin.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := Paper.label(_photo_title,24)
	title.name="PhotoViewerTitle"
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var image_rect := TextureRect.new()
	image_rect.name="PhotoViewerImage"
	image_rect.texture=_texture
	image_rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	image_rect.size_flags_vertical=Control.SIZE_EXPAND_FILL
	image_rect.custom_minimum_size=Vector2(minf(940.0,viewport_size.x-96.0),minf(530.0,viewport_size.y-160.0))
	image_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.add_child(image_rect)
	var controls := HBoxContainer.new()
	controls.alignment=BoxContainer.ALIGNMENT_END
	body.add_child(controls)
	var close_button := Paper.button("返回相簿",_close,controls)
	close_button.name="PhotoViewerClose"
	close_button.custom_minimum_size=Vector2(156,48)
	close_button.grab_focus()
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var scale_factor := Paper.physical_scale(self)
	Paper.adapt_menu(self,scale_factor)
	var view_size := get_viewport_rect().size
	var panel := find_child("PhotoViewerPanel",true,false) as Control
	if panel != null: panel.custom_minimum_size=Vector2(minf(980/scale_factor,view_size.x-48/scale_factor),minf(650/scale_factor,view_size.y-48/scale_factor))
	var picture := find_child("PhotoViewerImage",true,false) as Control
	if picture != null: picture.custom_minimum_size=Vector2(minf(940/scale_factor,view_size.x-96/scale_factor),maxf(100,minf(530/scale_factor,view_size.y-200/scale_factor)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.is_action_pressed("ui_cancel")):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if is_instance_valid(_focus_origin) and _focus_origin.is_visible_in_tree() and _focus_origin.focus_mode!=Control.FOCUS_NONE:
		_focus_origin.call_deferred("grab_focus")
	queue_free()
