extends Control
## Live viewfinder controls. They are hidden for the captured frame.

signal shutter_requested
signal cancel_requested

const Paper = preload("res://game/ui/paper_ui.gd")
const EDGE := Color("#f2ddab")
var photo_title := ""
var _status: Label
var _shutter: Button
var _bottom: PanelContainer

func _ready() -> void:
	name = "RegionalVisitPhotoPanel"
	mouse_filter = MOUSE_FILTER_IGNORE
	_bottom = PanelContainer.new()
	_bottom.name = "StoryPhotoControls"
	_bottom.add_theme_stylebox_override("panel", Paper.signboard(Color("#233048")))
	add_child(_bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bottom.add_child(row)
	_status = Paper.label(photo_title, 20, Paper.INK)
	_status.name = "StoryPhotoStatus"
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_status)
	var cancel := Paper.button("取消", func(): cancel_requested.emit(), row)
	cancel.name = "StoryPhotoCancel"
	cancel.tooltip_text = "收起相機，回到原地"
	_shutter = Paper.button("快門 · P", func(): shutter_requested.emit(), row)
	_shutter.name = "StoryPhotoShutter"
	_shutter.tooltip_text = "拍下畫框內的合照"
	_shutter.grab_focus()
	get_viewport().size_changed.connect(_fit)
	_bottom.minimum_size_changed.connect(_layout_bar)
	_fit()

func set_busy(value: bool) -> void:
	_shutter.disabled = value
	if not value:
		_shutter.grab_focus()

func show_retry() -> void:
	_status.text = "合照尚未保存，請再拍一次。"
	set_busy(false)

func _fit() -> void:
	if not is_instance_valid(_bottom):
		return
	var scale_factor := Paper.physical_scale(self)
	Paper.adapt_menu(self, scale_factor)
	_layout_bar.call_deferred()

func _layout_bar() -> void:
	if not is_instance_valid(_bottom):
		return
	size = get_viewport_rect().size
	var inset := 16.0 / Paper.physical_scale(self)
	_bottom.size = _bottom.get_combined_minimum_size()
	_bottom.position = Vector2((size.x - _bottom.size.x) * 0.5, size.y - _bottom.size.y - inset)
	queue_redraw()

static func viewfinder_rect(dimensions: Vector2) -> Rect2:
	var width := minf(dimensions.x * 0.88, dimensions.y * 0.70 * 16.0 / 9.0)
	var frame := Vector2(width, width * 9.0 / 16.0)
	return Rect2((Vector2(dimensions.x, dimensions.y * 0.84) - frame) * 0.5, frame)

func _draw() -> void:
	var visible_frame := viewfinder_rect(size)
	if visible_frame.size.x <= 0.0 or visible_frame.size.y <= 0.0:
		return
	var arm := minf(24.0, visible_frame.size.x * 0.08)
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
		var start := visible_frame.position + visible_frame.size * corner
		var direction := Vector2.ONE - corner * 2.0
		draw_line(start, start + Vector2(direction.x * arm, 0.0), EDGE, 2.0)
		draw_line(start, start + Vector2(0.0, direction.y * arm), EDGE, 2.0)
