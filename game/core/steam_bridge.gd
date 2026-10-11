extends Node

signal pending_changed

var pending_achievements: Array[String]:
	get:
		return Progress.platform_pending_achievements
var _achievement_sender: Callable

func _ready() -> void:
	Progress.achievement_unlocked.connect(queue_achievement)

func queue_achievement(id: String) -> void:
	if id.is_empty() or pending_achievements.has(id):
		return
	pending_achievements.append(id)
	pending_changed.emit()
	Progress.changed.emit()

func set_achievement_sender(sender: Callable) -> void:
	_achievement_sender = sender

func sync_pending() -> int:
	if not _achievement_sender.is_valid():
		return 0
	var synced := 0
	for id in pending_achievements.duplicate():
		var result: Variant = _achievement_sender.call(id)
		if result == true:
			pending_achievements.erase(id)
			synced += 1
	if synced > 0:
		pending_changed.emit()
		Progress.changed.emit()
	return synced
