extends Control
## A short in-world invitation; rules and accessibility choices stay optional.
const Paper = preload("res://game/ui/paper_ui.gd")
var definition: Dictionary = {}
var start_requested := Callable()
var rules_requested := Callable()
var close_requested := Callable()
func _ready() -> void:
	name = "IslandGameInvite"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04,0.12,0.15,0.14)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var dock := MarginContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","bottom"]: dock.add_theme_constant_override("margin_"+side,24)
	dock.add_theme_constant_override("margin_top",180)
	add_child(dock)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_END
	dock.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	var panel := PanelContainer.new()
	panel.name = "InviteCard"
	panel.custom_minimum_size = Vector2(590,0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel",Paper.plaque(Color("#fff4dc")))
	row.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	margin.add_child(body)
	var category := Paper.label(str(definition.get("attraction_tag","迎賓大道")),16,Paper.TEAL)
	body.add_child(category)
	var title := Paper.label(str(definition.get("name","遊樂設施")),28)
	title.name = "InviteTitle"
	body.add_child(title)
	var invitation := Paper.label(str(definition.get("island_invitation",definition.get("goal","一起來玩吧。"))),20)
	invitation.name = "InviteLine"
	invitation.custom_minimum_size.x = 520
	body.add_child(invitation)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	body.add_child(controls)
	var start := Paper.button("開始遊玩",func(): start_requested.call(),controls)
	start.name = "InviteStart"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Paper.set_button_role(start,"primary")
	var rules := Paper.button("玩法與選項",func(): rules_requested.call(),controls)
	rules.name = "InviteRules"
	var back := Paper.button("繼續逛逛",func(): close_requested.call(),controls)
	back.name = "InviteBack"
	start.grab_focus()
	resized.connect(_fit)
	_fit()
func _fit() -> void:
	var scale_factor := Paper.physical_scale(self)
	Paper.adapt_menu(self,scale_factor)
	var card := find_child("InviteCard",true,false) as PanelContainer
	if card != null: card.custom_minimum_size.x = minf(590/scale_factor,maxf(250,size.x-48/scale_factor))
	var line := find_child("InviteLine",true,false) as Label
	if line != null: line.custom_minimum_size.x = minf(520/scale_factor,maxf(200,size.x-88/scale_factor))
