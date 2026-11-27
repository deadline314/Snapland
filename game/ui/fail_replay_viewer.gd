extends Control
## Replays a saved fail moment from the album: the game's own arcade picture,
## redrawn from the state frozen at the fail, with its clock running again.
## Falls back to the saved still when the replay or picture is unavailable.

const Paper = preload("res://game/ui/paper_ui.gd")
const DESIGN := Vector2(1280, 720)
const LEAD_IN := 0.35
const PLAY_SECONDS := 2.6

var _title := ""
var _still: Texture2D
var _state: Dictionary = {}
var _view_script: Script
var _focus_origin: Control
var _stage: Control
var _view: Control
var _clock := 0.0


func setup(title: String, still: Texture2D, state: Dictionary, view_script: Script, focus_origin: Control) -> void:
	_title = title
	_still = still
	_state = state
	_view_script = view_script
	_focus_origin = focus_origin


func can_replay() -> bool:
	return not _state.is_empty() and _view_script != null and DisplayServer.get_name() != "headless"


func _ready() -> void:
	name = "FailReplayViewer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.07, 0.085, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "FailReplayPanel"
	panel.add_theme_stylebox_override("panel", Paper.plaque())
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := Paper.label(_title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(Paper.label("失敗拍貼", 14, Paper.CORAL))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Paper.plaque(Paper.DEEP))
	body.add_child(frame)
	_stage = Control.new()
	_stage.name = "FailReplayStage"
	_stage.clip_contents = true
	_stage.custom_minimum_size = Vector2(800, 450)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_stage)
	if can_replay():
		_view = _view_script.new()
		_view.name = "FailReplayPicture"
		_view.scale = Vector2.ONE * (_stage.custom_minimum_size.x / DESIGN.x)
		_stage.add_child(_view)
	elif _still != null:
		var picture := TextureRect.new()
		picture.name = "FailReplayStill"
		picture.texture = _still
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_stage.add_child(picture)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.add_theme_constant_override("separation", 10)
	body.add_child(controls)
	if _view != null:
		var again := Paper.button("重播", restart, controls)
		again.name = "FailReplayAgain"
		again.tooltip_text = "再看一次那個瞬間"
	var close := Paper.button("返回相簿", _close, controls)
	close.name = "FailReplayClose"
	close.custom_minimum_size = Vector2(156, 48)
	close.grab_focus()
	restart()


func restart() -> void:
	_clock = float(_state.get("fail_at", 0.0)) - LEAD_IN
	_present()


func _process(delta: float) -> void:
	if _view == null:
		return
	if _clock < float(_state.get("fail_at", 0.0)) + PLAY_SECONDS:
		_clock += delta
		_present()


func _present() -> void:
	if _view == null:
		return
	var frame := _state.duplicate()
	frame.clock = _clock
	# Replays show the scene only; the key hint belongs to live play.
	frame.hint = []
	_view.present(frame, Paper.reduced_motion())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	var origin := _focus_origin
	if is_instance_valid(origin):
		(func() -> void:
			if is_instance_valid(origin) and origin.is_visible_in_tree():
				origin.grab_focus()).call_deferred()
	queue_free()
