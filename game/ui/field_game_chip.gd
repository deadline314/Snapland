extends PanelContainer
## Compact readout for instant map games: time left, score and the three medal
## targets while a round runs, then a short result. It only listens to the
## field layer's signals and never drives the game.

const Paper = preload("res://game/ui/paper_ui.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")

const MEDAL_WORDS := ["銅", "銀", "金"]
const MEDAL_TINTS := [Color("#e0a070"), Color("#dfe6ea"), Color("#ffc66d")]
const DIM := Color("#7f9199")
const RESULT_SECONDS := 4.5

var title_label: Label
var time_label: Label
var score_label: Label
var note_label: Label
var ticks: Array[Label] = []

var _tick_row: HBoxContainer
var _medal := 0
var _hide_in := 0.0


func _init() -> void:
	name = "FieldGameChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 18.0
	add_theme_stylebox_override("panel", Paper.nameplate())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(top)
	title_label = _text(top, 20, Paper.INK)
	time_label = _text(top, 20, Paper.TEAL)
	score_label = _text(top, 22, Paper.GOLD)
	_tick_row = HBoxContainer.new()
	_tick_row.add_theme_constant_override("separation", 14)
	_tick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_tick_row)
	for index in range(MEDAL_WORDS.size()):
		ticks.append(_text(_tick_row, 16, DIM))
	note_label = _text(column, 16, Paper.INK)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false


func _text(parent: Node, size: int, color: Color) -> Label:
	var item := Paper.label("", size, color)
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


## Follow a world's field layer (null when the region has none).
func bind(source: Node) -> void:
	visible = false
	_hide_in = 0.0
	if not is_instance_valid(source):
		return
	source.round_started.connect(_on_started)
	source.round_progress.connect(_on_progress)
	source.round_finished.connect(_on_finished)
	source.round_aborted.connect(_on_aborted)


func _on_started(info: Dictionary) -> void:
	_hide_in = 0.0
	_medal = 0
	title_label.text = str(info.title)
	time_label.text = "%d 秒" % ceili(float(info.seconds))
	score_label.text = "0 分"
	var medals: Array = info.medals
	for index in range(ticks.size()):
		ticks[index].text = "%s %d" % [MEDAL_WORDS[index], int(medals[index])]
		ticks[index].add_theme_color_override("font_color", DIM)
	_tick_row.visible = true
	var best := int(info.get("best", 0))
	note_label.text = "最佳 %d 分" % best
	note_label.visible = best > 0
	_show()


func _on_progress(seconds_left: int, score: int, medal: int) -> void:
	time_label.text = "%d 秒" % seconds_left
	var text := "%d 分" % score
	if score_label.text != text:
		score_label.text = text
		PaperMotion.pop(score_label, 1.25)
	while _medal < medal and _medal < ticks.size():
		ticks[_medal].add_theme_color_override("font_color", MEDAL_TINTS[_medal])
		PaperMotion.pop(ticks[_medal], 1.4)
		_medal += 1


func _on_finished(result: Dictionary) -> void:
	title_label.text = str(result.title)
	time_label.text = str(result.medal_name)
	score_label.text = "%d 分" % int(result.score)
	_tick_row.visible = false
	var notes: Array[String] = []
	if not bool(result.saved):
		notes.append("成績沒有存到")
	elif bool(result.new_best):
		notes.append("新紀錄！")
	else:
		notes.append("最佳 %d 分" % int(result.best))
	if int(result.coins) > 0:
		notes.append("+%d 遊園幣" % int(result.coins))
	note_label.text = "　".join(notes)
	note_label.visible = true
	_show()
	PaperMotion.flash(self, PaperMotion.GAIN_TINT, 0.5)
	_hide_in = RESULT_SECONDS


func _on_aborted(_id: String) -> void:
	visible = false
	_hide_in = 0.0


func _show() -> void:
	var appeared := not visible
	visible = true
	reset_size()
	if appeared:
		PaperMotion.fade_in(self, 0.14)


func _process(delta: float) -> void:
	if _hide_in <= 0.0:
		return
	_hide_in -= delta
	if _hide_in <= 0.0:
		visible = false
