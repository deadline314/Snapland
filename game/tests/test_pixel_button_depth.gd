extends SceneTree

const Paper = preload("res://game/ui/paper_ui.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme=Paper.theme()
	root.add_child(host)
	var clicks := [0]
	var button := Paper.button("繼續遊園",func(): clicks[0]+=1,host)
	button.name="DepthProbeButton"
	button.position=Vector2(200,180)
	button.size=Vector2(280,64)
	Paper.set_button_role(button,"primary")
	await process_frame
	var bevel := button.get_node_or_null("PaperPixelBevel") as Paper.PixelButtonBevel
	_check(bevel!=null,"Paper buttons receive one real pixel-bevel overlay")
	if bevel==null:
		_finish(); return
	_check(bevel.mouse_filter==Control.MOUSE_FILTER_IGNORE and bevel.get_global_rect()==button.get_global_rect(),"bevel matches the button bounds without intercepting clicks or changing layout")
	var later_panel := PanelContainer.new()
	later_panel.position=button.position
	later_panel.size=button.size
	host.add_child(later_panel)
	_check(bevel.z_index+button.z_index<=later_panel.z_index and button.get_index()<later_panel.get_index(),"later opaque panels cover the entire button including its bevel")
	var normal := button.get_theme_stylebox("normal") as Paper.Board
	var hover := button.get_theme_stylebox("hover") as Paper.Board
	var pressed := button.get_theme_stylebox("pressed") as Paper.Board
	var disabled := button.get_theme_stylebox("disabled") as Paper.Board
	_check(normal.bg_color!=Paper.DEEP and normal.get_border_width(SIDE_BOTTOM)>=normal.get_border_width(SIDE_TOP)+3 and normal.shadow_size>=3,"normal face is lifted from the panel by a thick lower edge and cast shadow")
	_check(hover.bg_color!=normal.bg_color and hover.get_border_width(SIDE_BOTTOM)>=hover.get_border_width(SIDE_TOP)+3 and hover.shadow_size>normal.shadow_size,"hover brightens the face, raises its edge and deepens the cast shadow")
	_check(pressed.bg_color!=Paper.DEEP and pressed.bg_color!=normal.bg_color and pressed.shadow_size==0,"pressed state retains a distinct readable face while collapsing its shadow")
	_check(_contrast(Paper.PAPER,normal.bg_color)>=4.5 and _contrast(Paper.PAPER,hover.bg_color)>=4.5 and _contrast(Paper.PAPER,pressed.bg_color)>=4.5 and _contrast(Color("#e0dfc5"),disabled.bg_color)>=4.5,"normal, hover, pressed and disabled faces preserve 4.5:1 text contrast")
	var focus := button.get_theme_stylebox("focus") as Paper.Board
	_check(focus!=null and focus.border_color==Color("#dfa458") and focus.get_border_width(SIDE_LEFT)>=3,"gold keyboard-focus frame remains independent from the inset bevel")
	_check(focus!=null and focus.kind==Paper.Board.Kind.RING and _contrast(focus.border_color,normal.border_color)>=3.0 and _contrast(focus.border_color,Paper.DEEP)>=3.0 and _contrast(focus.border_color,Paper.FRAME)>=3.0,"focus is an open brass ring that stands out from the button's dark rim and from the boards behind it")
	_check(normal.corner>=1 and hover.corner==normal.corner and pressed.corner==normal.corner and disabled.corner==normal.corner,"every state keeps the same stepped pixel corners instead of a square box")
	var normal_lip := normal.get_border_width(SIDE_BOTTOM)-normal.get_border_width(SIDE_TOP)
	_check(normal_lip>=3 and normal_lip<=5 and normal.sink==0,"resting button shows a 3 to 5 px underside lip")
	_check(hover.sink<0 and hover.shadow_offset.y>normal.shadow_offset.y,"hover lifts the face off the board and lengthens its shadow")
	_check(pressed.sink>=2 and pressed.get_border_width(SIDE_BOTTOM)-pressed.get_border_width(SIDE_TOP)-pressed.sink<normal_lip and pressed.content_margin_top-normal.content_margin_top==pressed.sink,"pressing moves the face and its label down while the lip shrinks")
	_check(pressed.get_minimum_size()==normal.get_minimum_size() and hover.get_minimum_size()==normal.get_minimum_size() and disabled.get_minimum_size()==normal.get_minimum_size(),"state changes never resize the button")
	_check(disabled.shadow_size==0 and disabled.gloss==0.0 and disabled.get_border_width(SIDE_BOTTOM)-disabled.get_border_width(SIDE_TOP)<normal_lip and disabled.bg_color.s<normal.bg_color.s,"disabled button lies flat and faded")
	button.mouse_entered.emit()
	_check(bevel.current_state=="hover","pointer entry redraws the bevel as raised")
	button.button_down.emit()
	_check(bevel.current_state=="pressed","pointer press redraws the bevel in the inset state")
	button.button_up.emit()
	_check(bevel.current_state=="hover","pointer release restores the raised hover state")
	button.mouse_exited.emit()
	_check(bevel.current_state=="normal","pointer exit restores the normal paper edge")
	button.disabled=true
	bevel._sync_state()
	_check(bevel.current_state=="disabled","disabled state uses its readable muted edge palette")
	button.disabled=false
	button.pressed.emit()
	_check(clicks[0]==1,"button callback remains connected through the visual overlay")
	_finish()

func _contrast(foreground: Color, background: Color) -> float:
	var a := _luminance(foreground)
	var b := _luminance(background)
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func _luminance(color: Color) -> float:
	var channels := [color.r,color.g,color.b]
	var linear: Array[float]=[]
	for channel in channels:
		linear.append(channel/12.92 if channel<=0.04045 else pow((channel+0.055)/1.055,2.4))
	return 0.2126*linear[0]+0.7152*linear[1]+0.0722*linear[2]

func _check(condition: bool,message: String) -> void:
	if condition: print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: Paper pixel-button depth, state, focus and contrast checks")
		quit(0)
	else:
		push_error("Paper pixel-button failures: "+str(failures))
		quit(1)
