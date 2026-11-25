extends RefCounted

const Model = preload("res://game/minigames/sugar_draw_model.gd")
const View = preload("res://game/minigames/sugar_draw_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const KEYS := {KEY_A: View.SLOW, KEY_S: View.STEADY, KEY_D: View.FAST, KEY_W: View.HEAT,
	KEY_SPACE: View.CUT, KEY_F: View.FOLD, KEY_X: View.DISCARD, KEY_R: View.HELPER}
var _model := Model.new()
var _view: Control
var _owners: Dictionary = {}
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout

func reset(assisted: bool, _clock: String) -> void:
	clear_input()
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command.connect(_command)
		_view.pointer_cancelled.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		_view.present(snapshot())
	return _view

func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not KEYS.has(key):
			return false
		if event.is_canceled():
			clear_input()
		elif not event.echo:
			_command(KEYS[key], event.pressed, "key:%d" % key)
		return true
	if is_instance_valid(_view):
		return _view.handle_pointer(event, point)
	var source := Surface.pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		clear_input()
		return true
	if not event.pressed:
		var held := _owners.has(source)
		_command(-1, false, source)
		return held
	var slot := Surface.hit_slot(point)
	if slot < 0:
		return false
	_command(slot, true, source)
	return true

func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		if _owners.erase(source):
			_sync_holds()
		return
	var revision := _model.strand_revision()
	match action:
		View.SLOW, View.STEADY, View.FAST, View.HEAT:
			if not _owners.has(source):
				_owners[source] = action
				_sync_holds()
		View.CUT: _model.cut()
		View.FOLD: _model.fold()
		View.DISCARD: _model.discard()
		View.HELPER: _model.toggle_helper()
	if revision != _model.strand_revision():
		clear_input()

func _sync_holds() -> void:
	var speed := 0
	var heat := false
	for action: int in _owners.values():
		if action == View.HEAT:
			heat = true
		else:
			speed = maxi(speed, action + 1)
	_model.hold(speed, heat)

func clear_input() -> void:
	_owners.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointers()

func step(delta: float) -> Dictionary:
	var revision := _model.strand_revision()
	_model.step(delta)
	if revision != _model.strand_revision():
		clear_input()
	return snapshot()

func snapshot() -> Dictionary:
	var state := _model.snapshot()
	state.progress_text = "完成 %d / 3 段" % state.sections.size() + (" · 已回折" if state.folds > 0 else "")
	state.time_text = "%d 秒" % ceili(state.remaining)
	state.feedback_text = state.feedback
	return state

func consume_notes() -> Array[int]:
	return _model.consume_notes()

func present(_phase: String, _reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(snapshot())

func score_summary(practice: bool) -> Dictionary:
	var state := _model.snapshot()
	var completed: int = state.sections.size() * Model.SECTION_POINTS
	var bonus := int(state.devil) * Model.FOLD_POINTS
	var penalty := mini(completed + bonus, int(state.mistakes) * Model.LOSS_POINTS)
	return {"total": state.score, "label": "抽絲得分", "rule": "每段 150 分。三段完成且有合格雙股另加 100 分，失誤扣 20 分。",
		"rows": [
			{"key": "sections", "label": "合格糖絲", "amount": completed, "count": state.sections.size()},
			{"key": "fold", "label": "合格雙股", "amount": bonus, "count": int(state.devil)},
			{"key": "loss", "label": "退料或斷絲", "amount": -penalty, "count": state.mistakes},
		], "qualification_text": "練習回合不取得拍貼。" if practice else "正式回合拉出可量測的糖絲，自然結算可收藏普通卡。"}
